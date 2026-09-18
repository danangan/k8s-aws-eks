output "deployment_role_arn" {
  description = "ARN of the IAM role a CI/CD system assumes to push to ECR and describe the cluster"
  value       = aws_iam_role.deployment.arn
}

output "deployment_user_arn" {
  description = "ARN of the IAM user a CI/CD system authenticates as to assume deployment_role_arn"
  value       = aws_iam_user.deployer.arn
}
