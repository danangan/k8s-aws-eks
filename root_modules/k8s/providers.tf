provider "aws" {
  region = var.aws_region
}

# Reads root_modules/infra's own state (both are local-backend) so this
# module always targets whatever cluster infra actually created, instead of
# duplicating var.k8s_cluster_name here and risking the two drifting apart.
data "terraform_remote_state" "infra" {
  backend = "local"
  config = {
    path = "${path.module}/../infra/terraform.tfstate"
  }
}

data "aws_eks_cluster" "this" {
  name = data.terraform_remote_state.infra.outputs.cluster_name
}

# Both providers below talk to the cluster created by root_modules/infra,
# authenticating via a short-lived `aws eks get-token` exec plugin rather
# than a static token, since apply-time token expiry is otherwise a common
# source of failures.
provider "kubernetes" {
  host                   = data.aws_eks_cluster.this.endpoint
  cluster_ca_certificate = base64decode(data.aws_eks_cluster.this.certificate_authority[0].data)

  exec {
    api_version = "client.authentication.k8s.io/v1"
    command     = "aws"
    args        = ["eks", "get-token", "--cluster-name", data.aws_eks_cluster.this.name, "--region", var.aws_region]
  }
}

provider "helm" {
  kubernetes = {
    host                   = data.aws_eks_cluster.this.endpoint
    cluster_ca_certificate = base64decode(data.aws_eks_cluster.this.certificate_authority[0].data)

    exec = {
      api_version = "client.authentication.k8s.io/v1"
      command     = "aws"
      args        = ["eks", "get-token", "--cluster-name", data.aws_eks_cluster.this.name, "--region", var.aws_region]
    }
  }
}
