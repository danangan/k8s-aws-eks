output "vpc_id" {
  description = "ID of the VPC"
  value       = module.vpc.vpc_id
}

output "private_subnets" {
  description = "IDs of the private subnets - where the EKS node groups run"
  value       = module.vpc.private_subnets
}

output "public_subnets" {
  description = "IDs of the public subnets - where ALBs/NLBs get placed"
  value       = module.vpc.public_subnets
}
