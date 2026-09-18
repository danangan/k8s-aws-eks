module "network" {
  source = "./modules/network"

  k8s_cluster_name        = var.cluster_name
  vpc_cidr                = var.vpc_cidr
  availability_zone_count = var.availability_zone_count
}

module "eks" {
  source = "./modules/eks"

  cluster_name       = var.cluster_name
  kubernetes_version = var.kubernetes_version

  vpc_id     = module.network.vpc_id
  subnet_ids = module.network.private_subnets

  cpu_instance_type           = var.cpu_instance_type
  cpu_node_group_min_size     = var.cpu_node_group_min_size
  cpu_node_group_max_size     = var.cpu_node_group_max_size
  cpu_node_group_desired_size = var.cpu_node_group_desired_size

  gpu_instance_type           = var.gpu_instance_type
  gpu_node_group_min_size     = var.gpu_node_group_min_size
  gpu_node_group_max_size     = var.gpu_node_group_max_size
  gpu_node_group_desired_size = var.gpu_node_group_desired_size
}

module "ecr" {
  source = "./modules/ecr"

  repository_name = "${var.cluster_name}-repo"
}

module "deployment" {
  source = "./modules/deployment"

  cluster_name          = var.cluster_name
  cluster_arn  = module.eks.cluster_arn
  deployment_user_name = var.deployment_user_name
  ecr_repository_arn = module.ecr.repository_arn

}

