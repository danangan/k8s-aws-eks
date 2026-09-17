#!/bin/bash

set -euo pipefail

echo "Destroying k8s platform resources (Ingress controller, observability stack) via Terraform..."

terraform destroy

echo "Done! 🧹"
