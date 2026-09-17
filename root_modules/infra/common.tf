variable "aws_region" {
  description = "AWS region to deploy into"
  type        = string
  default     = "us-east-1"
}

variable "k8s_cluster_name" {
  description = "Name of the EKS cluster"
  type        = string
  default     = "platform-cluster"
}