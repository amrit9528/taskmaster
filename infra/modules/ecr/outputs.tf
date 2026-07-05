output "repository_url" {
  value = aws_ecr_repository.this.repository_url
}

output "repository_name" {
  value = aws_ecr_repository.this.name
}

output "repository_arn" {
  value = aws_ecr_repository.this.arn
}

output "registry_url" {
  value = "610269527458.dkr.ecr.ap-south-1.amazonaws.com"
}
