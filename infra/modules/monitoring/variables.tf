variable "vpc_id" {
  description = "VPC ID the monitoring resources belong to"
  type        = string
}

variable "private_subnet_ids" {
  description = "Private subnet IDs the monitoring tasks are deployed into"
  type        = list(string)
}

variable "ecs_cluster_id" {
  description = "ECS cluster ID to run the monitoring services in"
  type        = string
}

variable "ecs_cluster_name" {
  description = "ECS cluster name"
  type        = string
}

variable "alb_arn" {
  description = "ARN of the shared ALB"
  type        = string
}

variable "alb_https_listener_arn" {
  description = "ARN of the shared ALB HTTPS listener"
  type        = string
}

variable "alb_security_group_id" {
  description = "Security group ID of the shared ALB"
  type        = string
}

variable "task_execution_role_arn" {
  description = "ECS task execution role ARN, reused from the ecs module"
  type        = string
}

variable "environment" {
  description = "Environment name used for naming/tagging"
  type        = string
}

variable "ecr_registry" {
  description = "ECR registry URL"
  type        = string
}

variable "grafana_admin_password" {
  description = "Admin password for the Grafana instance"
  type        = string
  sensitive   = true
  default     = "Taskmaster@123"
}
