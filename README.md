# Terraform Module for AWS EKS with AWS ALB Ingress Controller Setup

A reusable Terraform module that provisions:

- A VPC (public + private subnets across multiple AZs, single NAT gateway)
- An EKS cluster with a Graviton (ARM) CPU node group and a GPU node group
- An ECR repository, and a permissions-boundary-scoped IAM deployment role/user for CI/CD
- The AWS Load Balancer Controller, so `Ingress` resources with `ingressClassName: alb` provision an ALB out of the box

This repository's root **is** the module - consume it directly, from another project, with:

```hcl
module "platform" {
  source = "github.com/<you>/<this-repo>"
  # or a local relative path, e.g. source = "../k8s-aws"

  k8s_cluster_name = "my-other-project"
  # ...override any other variable as needed, see variables.tf
}
```

The caller (your own root module) owns the `aws` and `helm` provider configuration - this module only declares `required_providers` in `versions.tf`, it never configures a provider itself, so it stays usable regardless of how the caller authenticates. See `variables.tf`/`outputs.tf` for the full interface.

## The bootstrap catch

The ALB controller's `helm_release` needs the `helm` provider configured with the cluster's own endpoint - which doesn't exist until the cluster this same apply is creating actually exists. In practice: **on a brand new deployment, run `terraform apply` twice.** The first run creates the VPC/EKS cluster and fails once it reaches the ALB controller (the provider config depends on a not-yet-known endpoint); the second run succeeds, since the cluster is already in state by then. Every apply after that is a normal single run.

## Project structure

```
(repo root)/       # The module itself: vpc.tf, eks.tf, deployment.tf,
                    # load-balancer-controller.tf, variables.tf, outputs.tf,
                    # versions.tf.
examples/
  eks-cluster/      # A deployable example: calls this module with
                    # `source = "../.."` and its own provider config.
                    # Use this to actually stand up a cluster.
  demo-app/         # A minimal FastAPI "hello world" service + Helm chart,
                    # deployed onto the example cluster's Ingress.
```

## Trying it out (via the example)

### Prerequisites

- AWS CLI, configured with credentials that can manage the resources below
- Terraform
- kubectl
- Helm

### 1. Provision the cluster and the Ingress controller

Log in with the AWS CLI first, so Terraform has credentials to work with - e.g. `aws sso login --profile <profile>` if you use IAM Identity Center, or `aws configure` for a static access key/secret:

```
aws sso login --profile <profile>
```

Then, from `examples/eks-cluster`:

```
cd examples/eks-cluster
terraform init
./deploy.sh
```

`deploy.sh` runs `terraform plan`/`apply` (provisioning the VPC, EKS cluster, and the ALB Ingress controller in one pass) then points kubectl at the new cluster (`aws eks update-kubeconfig`). It's safe to re-run - every step is a no-op once its resources already exist. Remember: on a brand new cluster, run it twice - see [The bootstrap catch](#the-bootstrap-catch).

### 2. Build and deploy the demo app

The demo app (`examples/demo-app/`) is managed with `uv`. Build its image, push it to the ECR repo Terraform just created, and roll it out with Helm:

```
cd examples/demo-app
./deploy.sh
```

This tags the image with a timestamp (the ECR repo is immutable-tagged, so re-running always pushes a new tag) and does a `helm upgrade --install app .` pointed at it. Safe to re-run for every new deploy.

### 3. (Optional) Point DNS at the ALB (manual)

The Ingress provisions the ALB but doesn't touch Route53 - the AWS Load Balancer Controller only manages the ALB/listener/target-group side, not DNS. Point your hosted zone at the ALB by hand.

Get the ALB's hostname and its canonical hosted zone ID (needed for an alias record):

```
ALB_HOSTNAME=$(kubectl get ingress app -o jsonpath='{.status.loadBalancer.ingress[0].hostname}')
ALB_ZONE_ID=$(aws elbv2 describe-load-balancers \
  --query "LoadBalancers[?DNSName=='$ALB_HOSTNAME'].CanonicalHostedZoneId" \
  --output text)
```

Then create an alias record for your hostname (matching whatever you set `ingress.host` to when deploying the app - see `examples/demo-app/values.yaml`) in the Route53 hosted zone for your domain:

```
HOSTED_ZONE_ID=<your-domain's-route53-hosted-zone-id>
APP_DOMAIN_NAME=<your-app-hostname>

aws route53 change-resource-record-sets \
  --hosted-zone-id "$HOSTED_ZONE_ID" \
  --change-batch '{
    "Changes": [{
      "Action": "UPSERT",
      "ResourceRecordSet": {
        "Name": "'"$APP_DOMAIN_NAME"'",
        "Type": "A",
        "AliasTarget": {
          "HostedZoneId": "'"$ALB_ZONE_ID"'",
          "DNSName": "'"$ALB_HOSTNAME"'",
          "EvaluateTargetHealth": false
        }
      }
    }]
  }'
```

Equivalently, in the Route53 console: Hosted zones -> your domain -> Create record -> toggle "Alias" -> "Alias to Application and Classic Load Balancer" -> pick the region and select the ALB.

This is a manual step for now - repeat it if the ALB is ever recreated (e.g. the Ingress gets deleted and reapplied). If that becomes a hassle, installing [ExternalDNS](https://github.com/kubernetes-sigs/external-dns) to manage these records automatically from the Ingress is the natural next step.

### Tearing it down

Optionally uninstall the app first, so a clean `helm uninstall` is recorded before the cluster disappears from under it:

```
cd examples/demo-app
./teardown.sh
```

Then tear down the cluster:

```
cd examples/eks-cluster
./teardown.sh
```

`teardown.sh` runs `terraform destroy` for everything (Ingress controller, EKS cluster, node groups, VPC, ECR, IAM) in one pass. It doesn't remove the manual Route53 alias records from step 3 above - clean those up separately if the domain is no longer in use.
