# network

A VPC (via `terraform-aws-modules/vpc/aws`) with public + private subnets spread across multiple AZs and a single NAT gateway. Public/private subnets are tagged for the AWS Load Balancer Controller's subnet auto-discovery.

## Inputs

| Name | Description | Default |
|---|---|---|
| `k8s_cluster_name` | Used to name the VPC and tag subnets for ALB/NLB auto-discovery | - |
| `vpc_cidr` | CIDR block for the VPC | `10.0.0.0/16` |
| `availability_zone_count` | Number of AZs to spread subnets across | `2` |

## Outputs

| Name | Description |
|---|---|
| `vpc_id` | ID of the VPC |
| `private_subnets` | IDs of the private subnets - where the EKS node groups run |
| `public_subnets` | IDs of the public subnets - where ALBs/NLBs get placed |
