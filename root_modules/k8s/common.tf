# The EKS cluster's name isn't declared here - it's read from root_modules/infra's
# state (see providers.tf) so the two root modules can never drift apart on it
# the way this project's deploy scripts once did.
variable "aws_region" {
  description = "AWS region the EKS cluster (from root_modules/infra) lives in"
  type        = string
  default     = "us-east-1"
}
