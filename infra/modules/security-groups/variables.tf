variable "vpc_id" {
  description = "VPC ID the security groups belong to"
  type        = string
}

variable "container_port" {
  description = "Port the ECS task container listens on"
  type        = number
}
