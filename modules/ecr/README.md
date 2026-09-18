# ecr

A single ECR repository, immutable-tagged with scan-on-push enabled. `force_delete = true` so `terraform destroy` removes it even if it still has images in it - fine for a demo, worth reconsidering for a repo you don't want to lose accidentally.

## Inputs

| Name | Description | Default |
|---|---|---|
| `repository_name` | Name of the ECR repository | - |

## Outputs

| Name | Description |
|---|---|
| `repository_url` | URL of the ECR repository |
| `repository_arn` | ARN of the ECR repository |
