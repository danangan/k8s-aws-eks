resource "aws_ecr_repository" "app" {
  name                 = var.repository_name
  image_tag_mutability = "IMMUTABLE"

  image_scanning_configuration {
    scan_on_push = true
  }

  # Demo project: let `terraform destroy` remove the repo even if it still
  # has images in it, rather than failing and requiring a manual cleanup.
  force_delete = true
}
