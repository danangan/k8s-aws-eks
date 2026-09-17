variable "deployment_user_name" {
  description = "Name of the IAM user used to assume the deployment role (CI/CD System)"
  type        = string
  default     = "ai-app-deploy"
}

data "aws_caller_identity" "current" {}

# These are necessary to avoid cyclic dependencies between IAM role and IAM user
locals {
  deployment_role_name = "${var.k8s_cluster_name}-deployment"
  deployment_role_arn  = "arn:aws:iam::${data.aws_caller_identity.current.account_id}:role/${local.deployment_role_name}"
}

# IAM User used for deployment

data "aws_iam_policy_document" "deployer_boundary" {
  statement {
    effect    = "Allow"
    actions   = ["sts:AssumeRole"]
    resources = [local.deployment_role_arn]
  }
}

resource "aws_iam_policy" "deployer_boundary" {
  name        = "${var.deployment_user_name}-boundary"
  description = "Permissions boundary: caps the deployer user at assuming the deployment role, nothing else"
  policy      = data.aws_iam_policy_document.deployer_boundary.json
}

resource "aws_iam_user" "deployer" {
  name                 = var.deployment_user_name
  permissions_boundary = aws_iam_policy.deployer_boundary.arn
}

# No access keys are created here on purpose - that would put a long-lived
# secret in Terraform state. Create one after apply with:
#   aws iam create-access-key --user-name <deployment_user_name>

data "aws_iam_policy_document" "deployer_assume_role" {
  statement {
    effect    = "Allow"
    actions   = ["sts:AssumeRole"]
    resources = [aws_iam_role.deployment.arn]
  }
}

resource "aws_iam_user_policy" "deployer_assume_role" {
  name   = "assume-deployment-role"
  user   = aws_iam_user.deployer.name
  policy = data.aws_iam_policy_document.deployer_assume_role.json
}


# --- Deployment role -------------------------------------------------------

data "aws_iam_policy_document" "deployment_assume_role" {
  statement {
    effect  = "Allow"
    actions = ["sts:AssumeRole"]

    principals {
      type        = "AWS"
      identifiers = [aws_iam_user.deployer.arn]
    }
  }
}

resource "aws_iam_role" "deployment" {
  name                 = local.deployment_role_name
  assume_role_policy   = data.aws_iam_policy_document.deployment_assume_role.json
  permissions_boundary = aws_iam_policy.deployment_role_boundary.arn
}

# --- ECR --------------------------------------------------------------

resource "aws_ecr_repository" "app" {
  name                 = "${var.k8s_cluster_name}-app"
  image_tag_mutability = "IMMUTABLE"

  image_scanning_configuration {
    scan_on_push = true
  }

  # Demo project: let `terraform destroy` remove the repo even if it still
  # has images in it, rather than failing and requiring a manual cleanup.
  force_delete = true
}

# ECR: push/pull scoped to just the app repository, not account-wide.
data "aws_iam_policy_document" "deployment_ecr" {
  statement {
    sid       = "EcrAuth"
    effect    = "Allow"
    actions   = ["ecr:GetAuthorizationToken"]
    resources = ["*"] # this action does not support resource-level scoping
  }

  statement {
    sid    = "EcrPushPull"
    effect = "Allow"
    actions = [
      "ecr:BatchCheckLayerAvailability",
      "ecr:GetDownloadUrlForLayer",
      "ecr:BatchGetImage",
      "ecr:PutImage",
      "ecr:InitiateLayerUpload",
      "ecr:UploadLayerPart",
      "ecr:CompleteLayerUpload",
    ]
    resources = [aws_ecr_repository.app.arn]
  }
}

resource "aws_iam_role_policy" "deployment_ecr" {
  name   = "ecr-push-pull"
  role   = aws_iam_role.deployment.id
  policy = data.aws_iam_policy_document.deployment_ecr.json
}

# EKS: lets the role fetch cluster connection info (`aws eks update-kubeconfig`)
data "aws_iam_policy_document" "deployment_eks_describe" {
  statement {
    sid       = "EksDescribeCluster"
    effect    = "Allow"
    actions   = ["eks:DescribeCluster"]
    resources = [module.eks.cluster_arn]
  }
}

resource "aws_iam_role_policy" "deployment_eks_describe" {
  name   = "eks-describe-cluster"
  role   = aws_iam_role.deployment.id
  policy = data.aws_iam_policy_document.deployment_eks_describe.json
}

# Permissions boundary for the deployment role: mirrors exactly what its own
# identity policies above grant (ECR push/pull + eks:DescribeCluster), so
# there's no room for a future identity policy to grant it more by mistake.
data "aws_iam_policy_document" "deployment_role_boundary" {
  source_policy_documents = [
    data.aws_iam_policy_document.deployment_ecr.json,
    data.aws_iam_policy_document.deployment_eks_describe.json,
  ]
}

resource "aws_iam_policy" "deployment_role_boundary" {
  name        = "${local.deployment_role_name}-boundary"
  description = "Permissions boundary: caps the deployment role at ECR push/pull and eks:DescribeCluster"
  policy      = data.aws_iam_policy_document.deployment_role_boundary.json
}

# ...and grants it edit access inside the cluster itself (create/update/delete
# workloads) without letting it touch RBAC/access entries or cluster config.
resource "aws_eks_access_entry" "deployment" {
  cluster_name  = module.eks.cluster_name
  principal_arn = aws_iam_role.deployment.arn
  type          = "STANDARD"
}

resource "aws_eks_access_policy_association" "deployment" {
  cluster_name  = module.eks.cluster_name
  principal_arn = aws_iam_role.deployment.arn
  policy_arn    = "arn:aws:eks::aws:cluster-access-policy/AmazonEKSEditPolicy"

  access_scope {
    type = "cluster"
  }
}
