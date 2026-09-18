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

output "cluster_arn" {
  description = "ARN of the EKS cluster"
  value       = module.eks.cluster_arn
}
