variable "repository_name" {
  description = "Name of the ECR repository"
  type        = string
  default     = "taskmaster"
}

variable "untagged_image_expiry_days" {
  description = "Number of days after which untagged images are expired"
  type        = number
  default     = 14
}
