#!/bin/bash

set -euo pipefail

echo "Destroying k8s platform resources (Ingress controller) via Terraform..."

terraform destroy

echo "Done! 🧹"
