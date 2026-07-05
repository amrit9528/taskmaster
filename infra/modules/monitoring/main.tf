data "aws_region" "current" {}

# A) CloudWatch log groups

resource "aws_cloudwatch_log_group" "prometheus" {
  name              = "/ecs/prometheus"
  retention_in_days = 7
}

resource "aws_cloudwatch_log_group" "grafana" {
  name              = "/ecs/grafana"
  retention_in_days = 7
}

# B) IAM task role for Grafana with CloudWatch read permissions

resource "aws_iam_role" "grafana_task" {
  name = "grafana-task-role"
  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect    = "Allow"
      Principal = { Service = "ecs-tasks.amazonaws.com" }
      Action    = "sts:AssumeRole"
    }]
  })
}

resource "aws_iam_role_policy" "grafana_cloudwatch" {
  name = "grafana-cloudwatch-read"
  role = aws_iam_role.grafana_task.id
  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect = "Allow"
      Action = [
        "cloudwatch:GetMetricData",
        "cloudwatch:ListMetrics",
        "cloudwatch:DescribeAlarms",
        "cloudwatch:GetMetricStatistics",
        "logs:GetLogEvents",
        "logs:DescribeLogGroups",
        "logs:DescribeLogStreams",
        "ec2:DescribeTags",
        "ecs:ListClusters",
        "ecs:ListServices",
        "ecs:DescribeServices"
      ]
      Resource = "*"
    }]
  })
}

# C) Security group for monitoring tasks

resource "aws_security_group" "monitoring" {
  name   = "taskmaster-monitoring-sg"
  vpc_id = var.vpc_id

  ingress {
    description     = "Prometheus from ALB"
    from_port       = 9090
    to_port         = 9090
    protocol        = "tcp"
    security_groups = [var.alb_security_group_id]
  }

  ingress {
    description     = "Grafana from ALB"
    from_port       = 3000
    to_port         = 3000
    protocol        = "tcp"
    security_groups = [var.alb_security_group_id]
  }

  ingress {
    description = "Prometheus scrape from within VPC"
    from_port   = 8080
    to_port     = 8080
    protocol    = "tcp"
    cidr_blocks = ["10.0.0.0/16"]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}

# D) Prometheus ECS task definition and service

resource "aws_ecs_task_definition" "prometheus" {
  family                   = "taskmaster-prometheus"
  requires_compatibilities = ["FARGATE"]
  network_mode             = "awsvpc"
  cpu                      = "256"
  memory                   = "512"
  execution_role_arn       = var.task_execution_role_arn

  container_definitions = jsonencode([
    {
      name      = "prometheus"
      image     = "${var.ecr_registry}/taskmaster-prometheus:latest"
      essential = true

      portMappings = [
        {
          containerPort = 9090
          protocol      = "tcp"
        }
      ]

      logConfiguration = {
        logDriver = "awslogs"
        options = {
          "awslogs-group"         = aws_cloudwatch_log_group.prometheus.name
          "awslogs-region"        = data.aws_region.current.name
          "awslogs-stream-prefix" = "ecs"
        }
      }
    }
  ])
}

resource "aws_ecs_service" "prometheus" {
  name            = "taskmaster-prometheus-service"
  cluster         = var.ecs_cluster_id
  task_definition = aws_ecs_task_definition.prometheus.arn
  desired_count   = 1
  launch_type     = "FARGATE"

  network_configuration {
    subnets          = var.private_subnet_ids
    security_groups  = [aws_security_group.monitoring.id]
    assign_public_ip = false
  }

  load_balancer {
    target_group_arn = aws_lb_target_group.prometheus.arn
    container_name   = "prometheus"
    container_port   = 9090
  }
}

# E) Grafana ECS task definition and service

resource "aws_ecs_task_definition" "grafana" {
  family                   = "taskmaster-grafana"
  requires_compatibilities = ["FARGATE"]
  network_mode             = "awsvpc"
  cpu                      = "256"
  memory                   = "512"
  execution_role_arn       = var.task_execution_role_arn
  task_role_arn            = aws_iam_role.grafana_task.arn

  container_definitions = jsonencode([
    {
      name      = "grafana"
      image     = "grafana/grafana:10.4.0"
      essential = true

      portMappings = [
        {
          containerPort = 3000
          protocol      = "tcp"
        }
      ]

      environment = [
        { name = "GF_SECURITY_ADMIN_USER", value = "admin" },
        { name = "GF_SECURITY_ADMIN_PASSWORD", value = var.grafana_admin_password },
        { name = "GF_SERVER_ROOT_URL", value = "https://amrit-ch.website/grafana/" },
        { name = "GF_SERVER_SERVE_FROM_SUB_PATH", value = "true" },
        { name = "GF_AUTH_ANONYMOUS_ENABLED", value = "false" },
        { name = "GF_AWS_default_REGION", value = "ap-south-1" },
        { name = "GF_AWS_default_AUTH", value = "ec2_iam_role" }
      ]

      logConfiguration = {
        logDriver = "awslogs"
        options = {
          "awslogs-group"         = aws_cloudwatch_log_group.grafana.name
          "awslogs-region"        = data.aws_region.current.name
          "awslogs-stream-prefix" = "ecs"
        }
      }
    }
  ])
}

resource "aws_ecs_service" "grafana" {
  name            = "taskmaster-grafana-service"
  cluster         = var.ecs_cluster_id
  task_definition = aws_ecs_task_definition.grafana.arn
  desired_count   = 1
  launch_type     = "FARGATE"

  network_configuration {
    subnets          = var.private_subnet_ids
    security_groups  = [aws_security_group.monitoring.id]
    assign_public_ip = false
  }

  load_balancer {
    target_group_arn = aws_lb_target_group.grafana.arn
    container_name   = "grafana"
    container_port   = 3000
  }
}

# F) ALB target groups and listener rules

resource "aws_lb_target_group" "prometheus" {
  name        = "prometheus-tg"
  port        = 9090
  protocol    = "HTTP"
  vpc_id      = var.vpc_id
  target_type = "ip"

  health_check {
    path                = "/-/healthy"
    healthy_threshold   = 2
    unhealthy_threshold = 3
    interval            = 30
    timeout             = 10
    matcher             = "200"
  }
}

resource "aws_lb_target_group" "grafana" {
  name        = "grafana-tg"
  port        = 3000
  protocol    = "HTTP"
  vpc_id      = var.vpc_id
  target_type = "ip"

  health_check {
    path                = "/grafana/api/health"
    healthy_threshold   = 2
    unhealthy_threshold = 3
    interval            = 30
    timeout             = 10
    matcher             = "200"
  }
}

resource "aws_lb_listener_rule" "prometheus" {
  listener_arn = var.alb_https_listener_arn
  priority     = 10

  action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.prometheus.arn
  }

  condition {
    path_pattern { values = ["/prometheus", "/prometheus/*"] }
  }
}

resource "aws_lb_listener_rule" "grafana" {
  listener_arn = var.alb_https_listener_arn
  priority     = 20

  action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.grafana.arn
  }

  condition {
    path_pattern { values = ["/grafana", "/grafana/*"] }
  }
}
