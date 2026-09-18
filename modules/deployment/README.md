# deployment

An IAM user + role pair for a CI/CD system to deploy with, instead of handing out long-lived credentials directly:

- An IAM user with a permissions boundary that caps it at *only* assuming the deployment role.
- A deployment role, itself permissions-boundary-capped at exactly what its own identity policies grant: push/pull on one ECR repository, `eks:DescribeCluster`, and edit access inside the cluster (via an EKS access entry, not a Kubernetes RBAC binding).

No access keys are created here on purpose - that would put a long-lived secret in Terraform state. Create one after apply with `aws iam create-access-key --user-name <deployment_user_name>`.

## Inputs

| Name | Description | Default |
|---|---|---|
| `k8s_cluster_name` | Used to name the deployment IAM role | - |
| `deployment_user_name` | Name of the IAM user | `ai-app-deploy` |
| `ecr_repository_arn` | ARN of the ECR repository the role may push/pull | - |
| `cluster_name` | Name of the EKS cluster the role gets edit access to | - |
| `eks_cluster_arn` | ARN of the EKS cluster - scopes `eks:DescribeCluster` | - |

## Outputs

| Name | Description |
|---|---|
| `deployment_role_arn` | ARN of the deployment role |
| `deployment_user_arn` | ARN of the deployer IAM user |
