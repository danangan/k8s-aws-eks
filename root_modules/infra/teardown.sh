#!/bin/bash

set -euo pipefail

echo "Destroying k8s platform resources (Ingress controller, observability stack) via Terraform..."

(cd ../k8s && ./teardown.sh)

echo "Destroying base AWS resources via Terraform..."

terraform destroy

echo "Done! 🧹"
