variable "deployment_user_name" {
  description = "Name of the IAM user used to assume the deployment role (CI/CD System)"
  type        = string
  default     = "ai-app-deploy"
}

variable "ecr_repository_arn" {
  description = "ARN of the ECR repository the deployment role may push/pull - scopes the ecr:* permissions"
  type        = string
}

variable "cluster_name" {
  description = "Name of the EKS cluster the deployment role gets edit access to"
  type        = string
}

variable "cluster_arn" {
  description = "ARN of the EKS cluster - scopes the eks:DescribeCluster permission"
  type        = string
}
