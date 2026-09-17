# About

This repository demonstrate setup of k8s cluster using AWS EKS. Feature:

- Graviton based CPU nodes
- NVidia GPU nodes for GPU based workload e.g. LLM workload
- AWS Ingress Controller to enable AWS ALB based ingress
  - Seamless integration with AWS ACM for TLS termination in the Ingress level
  - Seamless integration with AWS Route53 for setting up domain name for your service
- AWS IAM user and role for deploying k8s resources - useful for setting up deployment automation in your CI/CD pipeline

# Project structure

```
root_modules/
  infra/   # VPC, EKS cluster + node groups, ECR repo, deployment IAM role/user.
           # Uses only the `aws` provider - no cluster access needed to apply it.
  k8s/     # Everything that talks to the cluster's own API: the AWS Load
           # Balancer Controller (Ingress). Reads root_modules/infra's
           # state to find the cluster it should target.
demo-app/  # The demo FastAPI app and its Helm chart, plus deploy.sh/teardown.sh
           # to build/push the image and roll it out via Helm.
```

# How to deploy the project

## Prerequisites

- AWS CLI, configured with credentials that can manage the resources below
- Terraform
- kubectl
- Helm

## 1. Provision AWS resources and the Ingress controller

This is split across two Terraform root modules:

- `root_modules/infra` - the VPC, EKS cluster and node groups, ECR repo, and deployment IAM role/user. Uses only the `aws` provider, so it can be applied without cluster access.
- `root_modules/k8s` - everything that talks to the cluster's own API instead of just the AWS API: the AWS Load Balancer Controller (Ingress). It reads `root_modules/infra`'s state (both are local-backend) to find the cluster, so `infra` must be applied first.

Log in with the AWS CLI first, so Terraform has credentials to work with - e.g. `aws sso login --profile <profile>` if you use IAM Identity Center, or `aws configure` for a static access key/secret:

```
aws sso login --profile <profile>
```

Then, from the `root_modules/infra` directory, provision everything:

```
cd root_modules/infra
terraform init
./deploy.sh
```

```
cd root_modules/k8s
terraform init
./deploy.sh
```

`deploy.sh` runs `terraform plan`/`apply` (provisioning the VPC/EKS cluster), points kubectl at the new cluster (`aws eks update-kubeconfig`), then calls `root_modules/k8s/deploy.sh`, which `terraform init`s and applies that module (the Ingress controller) in turn. It's safe to re-run - every step is a no-op once its resources already exist.

This is a conscious design decision to make it easier to debug issues between AWS resources provisioning and the k8s cluster specific setup.

## 2. Build and deploy the demo app

The demo app (`demo-app/`) is a minimal FastAPI "hello world" service, managed with `uv`. Build its image, push it to the ECR repo Terraform just created, and roll it out with Helm:

```
cd demo-app
./deploy.sh
```

This tags the image with a timestamp (the ECR repo is immutable-tagged, so re-running always pushes a new tag) and does a `helm upgrade --install app .` pointed at it. Safe to re-run for every new deploy.

## 3. (Optional) Point DNS at the ALB (manual)

The Ingress provisions the ALB but doesn't touch Route53 - the AWS Load Balancer Controller only manages the ALB/listener/target-group side, not DNS. Point your hosted zone at the ALB by hand.

Get the ALB's hostname and its canonical hosted zone ID (needed for an alias record):

```
ALB_HOSTNAME=$(kubectl get ingress app -o jsonpath='{.status.loadBalancer.ingress[0].hostname}')
ALB_ZONE_ID=$(aws elbv2 describe-load-balancers \
  --query "LoadBalancers[?DNSName=='$ALB_HOSTNAME'].CanonicalHostedZoneId" \
  --output text)
```

Then create an alias record for your hostname (matching whatever you set `ingress.host` to when deploying the app - see `demo-app/values.yaml`) in the Route53 hosted zone for your domain:

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

## Tearing it down

Optionally uninstall the app first, so a clean `helm uninstall` is recorded before the cluster disappears from under it:

```
cd demo-app
./teardown.sh
```

Then tear down the platform:

```
cd root_modules/infra
./teardown.sh
```

```
cd root_modules/k8s
./teardown.sh
```

`teardown.sh` runs `terraform destroy` in `root_modules/k8s` (Ingress controller) before `root_modules/infra` (VPC, EKS cluster, node groups, ECR, IAM) - `k8s`'s resources need the cluster to still be reachable, so it has to go first. It also doesn't remove the manual Route53 alias records from step 3 above - clean those up separately if the domain is no longer in use.
