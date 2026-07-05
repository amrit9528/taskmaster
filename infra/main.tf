module "vpc" {
  source = "./modules/vpc"

  environment = var.environment
}

module "security_groups" {
  source = "./modules/security-groups"

  vpc_id         = module.vpc.vpc_id
  container_port = var.container_port
}

module "ecr" {
  source = "./modules/ecr"
}

module "alb" {
  source = "./modules/alb"

  vpc_id                 = module.vpc.vpc_id
  public_subnet_ids      = module.vpc.public_subnet_ids
  alb_security_group_id  = module.security_groups.alb_security_group_id
  container_port         = var.container_port
  health_check_path      = var.health_check_path
}

module "ecs" {
  source = "./modules/ecs"

  environment                = var.environment
  vpc_id                     = module.vpc.vpc_id
  private_subnet_ids         = module.vpc.private_subnet_ids
  ecs_task_security_group_id = module.security_groups.ecs_task_security_group_id
  ecr_repository_url         = module.ecr.repository_url
  container_port             = var.container_port
  task_cpu                   = var.task_cpu
  task_memory                = var.task_memory
  target_group_arn           = module.alb.target_group_arn
}
