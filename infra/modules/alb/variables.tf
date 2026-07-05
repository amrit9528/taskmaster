variable "vpc_id" {
  description = "VPC ID the ALB and target group belong to"
  type        = string
}

variable "public_subnet_ids" {
  description = "Public subnet IDs the internet-facing ALB is deployed into"
  type        = list(string)
}

variable "alb_security_group_id" {
  description = "Security group ID attached to the ALB"
  type        = string
}

variable "container_port" {
  description = "Port the target group forwards traffic to"
  type        = number
}

variable "health_check_path" {
  description = "Path used for target group health checks"
  type        = string
  default     = "/"
}

variable "name_prefix" {
  description = "Prefix used when naming ALB resources"
  type        = string
  default     = "taskmaster"
}
