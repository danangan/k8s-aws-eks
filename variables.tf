variable "aws_region" {
  description = "AWS region the cluster lives in - not used to configure the aws provider (the caller owns that), only passed to the ALB controller's helm values and the aws eks get-token exec args."
  type        = string
  default     = "us-east-1"
}

variable "cluster_name" {
  description = "Name of the EKS cluster"
  type        = string
}

variable "vpc_cidr" {
  description = "CIDR block for the VPC"
  type        = string
  default     = "10.0.0.0/16"
}

variable "availability_zone_count" {
  description = "Number of availability zones to spread subnets across"
  type        = number
  default     = 2
}

variable "kubernetes_version" {
  description = "Kubernetes version for the EKS cluster"
  type        = string
  default     = "1.33"
}

variable "cpu_instance_type" {
  description = "Instance type for the CPU-only node group"
  type        = string
  # Using the cheapest compute available to save some cost
  default = "t4g.small"
}

variable "cpu_node_group_min_size" {
  description = "Minimum CPU nodes; kept at 1+ since these nodes host cluster add-ons (coredns, kube-proxy, the EFS CSI driver)"
  type        = number
  default     = 0
}

variable "cpu_node_group_max_size" {
  type    = number
  default = 2
}

variable "cpu_node_group_desired_size" {
  type    = number
  default = 2
}

variable "gpu_instance_type" {
  description = "Instance type for the GPU-enabled node group"
  type        = string
  default     = "g4dn.xlarge"
}

variable "gpu_node_group_min_size" {
  description = "Minimum GPU nodes; 0 lets the group scale to zero when idle, since the CPU node group covers cluster add-ons"
  type        = number
  default     = 0
}

variable "gpu_node_group_max_size" {
  type    = number
  default = 1
}

variable "gpu_node_group_desired_size" {
  type    = number
  default = 1
}

variable "deployment_user_name" {
  description = "Name of the IAM user used to assume the deployment role (CI/CD System)"
  type        = string
  default     = "eks-deployer"
}

variable "alb_controller_chart_version" {
  description = "Version of the aws-load-balancer-controller Helm chart to install"
  type        = string
  default     = "3.5.0"
}
