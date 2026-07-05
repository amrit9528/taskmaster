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
    description     = "Prometheus (via nginx sidecar) from ALB"
    from_port       = 9091
    to_port         = 9091
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

      command = [
        "--config.file=/etc/prometheus/prometheus.yml",
        "--storage.tsdb.path=/prometheus",
        "--web.console.libraries=/usr/share/prometheus/console_libraries",
        "--web.console.templates=/usr/share/prometheus/consoles"
      ]

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
          "awslogs-stream-prefix" = "prometheus"
        }
      }
    },
    {
      name      = "nginx-proxy"
      image     = "nginx:alpine"
      essential = false

      portMappings = [
        {
          containerPort = 9091
          protocol      = "tcp"
        }
      ]

      command = [
        "/bin/sh", "-c",
        "echo 'server { listen 9091; location /prometheus/ { rewrite ^/prometheus/(.*) /$1 break; proxy_pass http://localhost:9090; } location /prometheus { return 301 /prometheus/; } }' > /etc/nginx/conf.d/prometheus.conf && nginx -g 'daemon off;'"
      ]

      dependsOn = [
        {
          containerName = "prometheus"
          condition     = "START"
        }
      ]

      logConfiguration = {
        logDriver = "awslogs"
        options = {
          "awslogs-group"         = aws_cloudwatch_log_group.prometheus.name
          "awslogs-region"        = data.aws_region.current.name
          "awslogs-stream-prefix" = "nginx-proxy"
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
    container_name   = "nginx-proxy"
    container_port   = 9091
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
      image     = "${var.ecr_registry}/taskmaster-grafana:latest"
      essential = true

      portMappings = [
        {
          containerPort = 3000
          protocol      = "tcp"
        }
      ]

      environment = [
        { name = "GF_SECURITY_ADMIN_USER", value = "admin" },
        { name = "GF_SERVER_ROOT_URL", value = "https://amrit-ch.website/grafana/" },
        { name = "GF_SERVER_SERVE_FROM_SUB_PATH", value = "true" },
        { name = "GF_AUTH_ANONYMOUS_ENABLED", value = "false" },
        { name = "GF_PATHS_PROVISIONING", value = "/etc/grafana/provisioning" }
      ]

      secrets = [
        {
          name      = "GF_SECURITY_ADMIN_PASSWORD"
          valueFrom = "arn:aws:secretsmanager:ap-south-1:610269527458:secret:taskmaster/grafana-admin-password"
        }
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
  name_prefix = "prom-"
  port        = 9091
  protocol    = "HTTP"
  vpc_id      = var.vpc_id
  target_type = "ip"

  health_check {
    path                = "/prometheus/-/healthy"
    healthy_threshold   = 2
    unhealthy_threshold = 3
    interval            = 30
    timeout             = 10
    matcher             = "200"
  }

  lifecycle {
    create_before_destroy = true
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
