# eks

An EKS cluster (via `terraform-aws-modules/eks/aws`) with a Graviton (ARM) CPU node group and a GPU node group (tainted `gpu-workload=true:NoSchedule`, so only pods that tolerate it land there). AMI architecture for the CPU group is picked automatically from the instance type.

## Inputs

| Name | Description | Default |
|---|---|---|
| `k8s_cluster_name` | Name of the EKS cluster | - |
| `kubernetes_version` | Kubernetes version | `1.33` |
| `vpc_id` | ID of the VPC to create the cluster in | - |
| `subnet_ids` | IDs of the (private) subnets for the cluster and its node groups | - |
| `cpu_instance_type` | Instance type for the CPU-only node group | `t4g.small` |
| `cpu_node_group_min_size` / `max_size` / `desired_size` | CPU node group sizing | `0` / `2` / `2` |
| `gpu_instance_type` | Instance type for the GPU-enabled node group | `g4dn.xlarge` |
| `gpu_node_group_min_size` / `max_size` / `desired_size` | GPU node group sizing | `0` / `1` / `1` |

## Outputs

| Name | Description |
|---|---|
| `cluster_name` | Name of the EKS cluster |
| `cluster_arn` | ARN of the EKS cluster |
| `cluster_endpoint` | Endpoint of the cluster's Kubernetes API - needed to configure the kubernetes/helm providers |
| `cluster_certificate_authority_data` | Base64-encoded CA certificate - needed to configure the kubernetes/helm providers |
