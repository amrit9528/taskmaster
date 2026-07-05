variable "environment" {
  description = "Environment name used for naming/tagging"
  type        = string
}

variable "vpc_id" {
  description = "VPC ID the ECS service is deployed into"
  type        = string
}

variable "private_subnet_ids" {
  description = "Private subnet IDs the ECS tasks are deployed into"
  type        = list(string)
}

variable "ecs_task_security_group_id" {
  description = "Security group ID attached to the ECS tasks"
  type        = string
}

variable "ecr_repository_url" {
  description = "ECR repository URL the task definition pulls its image from"
  type        = string
}

variable "container_port" {
  description = "Port the application container listens on"
  type        = number
}

variable "task_cpu" {
  description = "Fargate task CPU units"
  type        = number
  default     = 512
}

variable "task_memory" {
  description = "Fargate task memory in MiB"
  type        = number
  default     = 1024
}

variable "target_group_arn" {
  description = "ALB target group ARN the ECS service registers tasks with"
  type        = string
}

variable "desired_count" {
  description = "Desired number of ECS service tasks"
  type        = number
  default     = 2
}

variable "name_prefix" {
  description = "Prefix used when naming ECS resources"
  type        = string
  default     = "taskmaster"
}
