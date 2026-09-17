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

data "aws_availability_zones" "available" {
  filter {
    name   = "opt-in-status"
    values = ["opt-in-not-required"]
  }
}

locals {
  azs = slice(data.aws_availability_zones.available.names, 0, var.availability_zone_count)
}

module "vpc" {
  source  = "terraform-aws-modules/vpc/aws"
  version = "6.7.2"

  name = "${var.k8s_cluster_name}-vpc"
  cidr = var.vpc_cidr

  azs = local.azs

  private_subnets = [for i, az in local.azs : cidrsubnet(var.vpc_cidr, 4, i)]
  public_subnets  = [for i, az in local.azs : cidrsubnet(var.vpc_cidr, 4, i + 8)]

  enable_nat_gateway   = true
  single_nat_gateway   = true
  enable_dns_hostnames = true
  enable_dns_support   = true

  # Required by the AWS Load Balancer Controller for subnet auto-discovery:
  # it picks subnets to place ALBs/NLBs into (and manages their security
  # groups) based on these tags, since infra/eks.tf and the Ingress
  # resources don't set the alb.ingress.kubernetes.io/subnets annotation.
  public_subnet_tags = {
    "kubernetes.io/cluster/${var.k8s_cluster_name}" = "shared"
    "kubernetes.io/role/elb"                        = "1"
  }
  private_subnet_tags = {
    "kubernetes.io/cluster/${var.k8s_cluster_name}" = "shared"
    "kubernetes.io/role/internal-elb"               = "1"
  }

  tags = {
    Project = var.k8s_cluster_name
  }
}
