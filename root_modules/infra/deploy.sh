#!/bin/bash

set -euo pipefail

# Creating base resources with terraform

echo "Provisioning AWS resources via Terraform..."

terraform plan -out=tf-plan-output

terraform apply tf-plan-output

CLUSTER_NAME="$(terraform output -raw cluster_name)"

echo "Setting up kubecontext via aws command..."

aws eks update-kubeconfig --name "${CLUSTER_NAME}" --region us-east-1

echo "Provisioning k8s platform resources (Ingress controller, observability stack)..."

(cd ../k8s && ./deploy.sh)

echo "Done!"