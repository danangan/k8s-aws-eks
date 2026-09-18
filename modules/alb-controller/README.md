# alb-controller

Installs the AWS Load Balancer Controller (the modern replacement for the legacy "ALB Ingress Controller") via Helm, so `Ingress` resources with `ingressClassName: alb` provision a real ALB. Grants it access via EKS Pod Identity: an IAM policy (copied verbatim from the [controller's own repo](https://raw.githubusercontent.com/kubernetes-sigs/aws-load-balancer-controller/main/docs/install/iam_policy.json)), a role, and a pod identity association bound to its `aws-load-balancer-controller` service account.

Needs the `helm` provider configured - see the root module's README for the bootstrap catch this implies on a brand new cluster.

## Inputs

| Name | Description | Default |
|---|---|---|
| `aws_region` | AWS region the cluster lives in - passed to the helm chart values and the `aws eks get-token` exec args | `us-east-1` |
| `cluster_name` | Name of the EKS cluster to install the controller into | - |
| `vpc_id` | ID of the VPC the cluster runs in - passed to the helm chart for subnet discovery | - |
| `alb_controller_chart_version` | Version of the `aws-load-balancer-controller` Helm chart | `3.5.0` |

## Outputs

None.
