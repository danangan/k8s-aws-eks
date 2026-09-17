#!/bin/bash

set -euo pipefail

echo "Provisioning k8s platform resources (Ingress controller) via Terraform..."

terraform init -input=false

terraform plan -out=tf-plan-output

terraform apply tf-plan-output

echo "Done!"