output "cluster_name" {
  description = "Name of the EKS cluster"
  value       = module.eks.cluster_name
}

output "cluster_endpoint" {
  description = "Endpoint of the EKS cluster's Kubernetes API - needed by the caller to configure the kubernetes/helm providers"
  value       = module.eks.cluster_endpoint
}

output "cluster_certificate_authority_data" {
  description = "Base64-encoded CA certificate of the EKS cluster - needed by the caller to configure the kubernetes/helm providers"
  value       = module.eks.cluster_certificate_authority_data
}

output "vpc_id" {
  description = "ID of the VPC the cluster runs in"
  value       = module.network.vpc_id
}

output "ecr_repository_url" {
  description = "URL of the app's ECR repository"
  value       = module.ecr.repository_url
}

output "deployment_role_arn" {
  description = "ARN of the IAM role a CI/CD system assumes to push to ECR and describe the cluster"
  value       = module.deployment.deployment_role_arn
}

output "deployment_user_arn" {
  description = "ARN of the IAM user a CI/CD system authenticates as to assume deployment_role_arn"
  value       = module.deployment.deployment_user_arn
}
