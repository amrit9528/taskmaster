output "ecr_repository_url" {
  description = "URL of the ECR repository"
  value       = module.ecr.repository_url
}

output "ecs_cluster_name" {
  description = "Name of the ECS cluster"
  value       = module.ecs.cluster_name
}

output "ecs_service_name" {
  description = "Name of the ECS service"
  value       = module.ecs.service_name
}

output "alb_dns_name" {
  value       = module.alb.alb_dns_name
  description = "Point amrit-ch.website CNAME at this value in Namecheap"
}

output "grafana_url" {
  value = module.monitoring.grafana_url
}

output "prometheus_url" {
  value = module.monitoring.prometheus_url
}
