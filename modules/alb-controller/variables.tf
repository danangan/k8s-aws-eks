variable "aws_region" {
  description = "AWS region the cluster lives in - passed to the helm chart values and the aws eks get-token exec args"
  type        = string
  default     = "us-east-1"
}

variable "cluster_name" {
  description = "Name of the EKS cluster to install the controller into"
  type        = string
}

variable "vpc_id" {
  description = "ID of the VPC the cluster runs in - passed to the helm chart so the controller can discover subnets"
  type        = string
}

variable "alb_controller_chart_version" {
  description = "Version of the aws-load-balancer-controller Helm chart to install"
  type        = string
  default     = "3.5.0"
}
