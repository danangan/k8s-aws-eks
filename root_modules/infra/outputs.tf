output "cluster_name" {
  description = "Name of the EKS cluster, consumed by deploy.sh/cleanup.sh so they never drift from var.k8s_cluster_name"
  value       = module.eks.cluster_name
}

output "ecr_repository_url" {
  description = "URL of the app's ECR repository, consumed by deploy-app.sh to build/push/deploy the demo app"
  value       = aws_ecr_repository.app.repository_url
}

output "vpc_id" {
  description = "ID of the VPC, consumed by root_modules/k8s for the AWS Load Balancer Controller"
  value       = module.vpc.vpc_id
}
