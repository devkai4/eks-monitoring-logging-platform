provider "aws" {
  region = var.region
}

locals {
  prefix = "${var.environment}-${var.project}"
  tags = {
    Environment = var.environment
    Project     = var.project
    ManagedBy   = "terraform"
    Owner       = var.owner
  }
}

module "vpc" {
  source = "../../modules/vpc"

  vpc_cidr          = var.vpc_cidr
  availability_zones = var.availability_zones
  prefix            = local.prefix
  cluster_name      = var.cluster_name
  tags              = local.tags
}

module "eks" {
  source = "../../modules/eks"

  prefix                  = local.prefix
  cluster_name            = var.cluster_name
  kubernetes_version      = var.kubernetes_version
  vpc_id                  = module.vpc.vpc_id
  public_subnet_ids       = module.vpc.public_subnet_ids
  private_subnet_ids      = module.vpc.private_subnet_ids
  cluster_security_group_id = module.vpc.cluster_security_group_id
  node_security_group_id    = module.vpc.node_security_group_id
  node_instance_types     = var.node_instance_types
  desired_nodes           = var.desired_nodes
  min_nodes               = var.min_nodes
  max_nodes               = var.max_nodes
  tags                    = local.tags
}