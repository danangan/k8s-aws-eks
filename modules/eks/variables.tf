variable "cluster_name" {
  description = "Name of the EKS cluster"
  type        = string
}

variable "kubernetes_version" {
  description = "Kubernetes version for the EKS cluster"
  type        = string
  default     = "1.33"
}

variable "vpc_id" {
  description = "ID of the VPC to create the cluster in"
  type        = string
}

variable "subnet_ids" {
  description = "IDs of the (private) subnets for the cluster and its node groups"
  type        = list(string)
}

variable "cpu_instance_type" {
  description = "Instance type for the CPU-only node group"
  type        = string
  default     = "t4g.small"
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
