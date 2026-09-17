#!/bin/bash

set -euo pipefail

# Creating base resources with terraform

echo "Provisioning AWS resources via Terraform..."

terraform init -input=false

terraform plan -out=tf-plan-output

terraform apply tf-plan-output

echo "Done!"