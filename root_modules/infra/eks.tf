
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

variable "observability_instance_type" {
  description = "Instance type for the observability node group"
  type        = string
  default     = "t4g.small"
}

variable "observability_node_group_min_size" {
  description = "Minimum GPU nodes; 0 lets the group scale to zero when idle, since the CPU node group covers cluster add-ons"
  type        = number
  default     = 0
}

variable "observability_node_group_max_size" {
  type    = number
  default = 1
}

variable "observability_node_group_desired_size" {
  type    = number
  default = 1
}

locals {
  # AWS Graviton (ARM) instance families follow a "<letters><digits>g<letters>.<size>"
  # naming convention (t4g, m6g, m6gd, c7g, r7gn, ...) - match on that "g" marker
  # to pick the matching EKS-optimized AMI, so a future instance-type change
  # doesn't silently mismatch the AMI arch again.
  cpu_node_ami_type           = can(regex("^[a-z][0-9]+g[a-z]*\\.", var.cpu_instance_type)) ? "AL2023_ARM_64_STANDARD" : "AL2023_x86_64_STANDARD"
  observability_node_ami_type = can(regex("^[a-z][0-9]+g[a-z]*\\.", var.observability_instance_type)) ? "AL2023_ARM_64_STANDARD" : "AL2023_x86_64_STANDARD"
}

# IAM role for the EBS CSI driver addon, granted to it via EKS Pod Identity
# (eks-pod-identity-agent is already enabled below) rather than IRSA/OIDC, so
# there's a single access-granting mechanism for cluster addons in this repo.
data "aws_iam_policy_document" "ebs_csi_driver_assume_role" {
  statement {
    effect  = "Allow"
    actions = ["sts:AssumeRole", "sts:TagSession"]

    principals {
      type        = "Service"
      identifiers = ["pods.eks.amazonaws.com"]
    }
  }
}

resource "aws_iam_role" "ebs_csi_driver" {
  name               = "${var.k8s_cluster_name}-ebs-csi-driver"
  assume_role_policy = data.aws_iam_policy_document.ebs_csi_driver_assume_role.json
}

resource "aws_iam_role_policy_attachment" "ebs_csi_driver" {
  role       = aws_iam_role.ebs_csi_driver.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AmazonEBSCSIDriverPolicy"
}

module "eks" {
  source  = "terraform-aws-modules/eks/aws"
  version = "~> 21.0"

  name               = var.k8s_cluster_name
  kubernetes_version = var.kubernetes_version

  authentication_mode = "API_AND_CONFIG_MAP"

  endpoint_public_access                   = true
  enable_cluster_creator_admin_permissions = true
  enable_irsa                              = true

  vpc_id     = module.vpc.vpc_id
  subnet_ids = module.vpc.private_subnets

  addons = {
    coredns                = {}
    kube-proxy             = {}
    vpc-cni                = { before_compute = true }
    eks-pod-identity-agent = { before_compute = true }
    # Needed for dynamically-provisioned EBS-backed PersistentVolumes, e.g.
    # the observability stack's Prometheus/Grafana/Loki/Tempo storage.
    aws-ebs-csi-driver = {
      pod_identity_association = [{
        role_arn        = aws_iam_role.ebs_csi_driver.arn
        service_account = "ebs-csi-controller-sa"
      }]
    }
  }

  compute_config = {
    enabled = false
  }

  # This is deliberate so that the cluster use AWS-managed encryption key
  # rather than customer managed key
  # This is to save some cost associated with the key creation
  # create_kms_key = false

  eks_managed_node_groups = {
    cpu = {
      ami_type       = local.cpu_node_ami_type
      instance_types = [var.cpu_instance_type]

      min_size     = var.cpu_node_group_min_size
      max_size     = var.cpu_node_group_max_size
      desired_size = var.cpu_node_group_desired_size
    },
    gpu = {
      # EKS-optimized AMI with NVIDIA drivers/container runtime preinstalled.
      ami_type       = "AL2023_x86_64_NVIDIA"
      instance_types = [var.gpu_instance_type]

      min_size     = var.gpu_node_group_min_size
      max_size     = var.gpu_node_group_max_size
      desired_size = var.gpu_node_group_desired_size

      # Keep non-GPU workloads off these (more expensive) nodes; pods that
      # need a GPU must add a matching toleration.
      taints = {
        gpu = {
          key    = "gpu-workload"
          value  = "true"
          effect = "NO_SCHEDULE"
        }
      }
    },
    # We have a separate node group for observability tools because they need persistence and they need to be managed separately
    observability = {
      ami_type       = local.observability_node_ami_type
      instance_types = [var.observability_instance_type]

      # These are hardcoded because we just need 1 node for now
      min_size     = 0
      max_size     = 1
      desired_size = 1

      # Lets the observability stack's Helm releases (root_modules/k8s)
      # target this node group with a nodeSelector.
      labels = {
        role = "observability"
      }

      # Root/container volume for the node itself - not where the
      # observability stack's data lives, that's on dynamically-provisioned
      # EBS volumes via the aws-ebs-csi-driver addon (see the gp3
      # kubernetes_storage_class in root_modules/k8s/storage.tf).
      block_device_mappings = {
        xvda = {
          device_name = "/dev/xvda"
          ebs = {
            volume_size = 20
            volume_type = "gp3"
            encrypted   = true
            # Ideally this would be false, but for demo purposes it's set up
            # to auto-delete so cleanup doesn't leave orphaned volumes.
            delete_on_termination = true
          }
        }
      }

      # Keep non-observability workloads off these nodes;
      taints = {
        observability = {
          key    = "observability-workload"
          value  = "true"
          effect = "NO_SCHEDULE"
        }
      }
    }
  }

  tags = {
    Project = var.k8s_cluster_name
  }
}
