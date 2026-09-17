#!/bin/bash

set -euo pipefail

echo "Destroying base AWS resources via Terraform..."

terraform destroy

echo "Done! 🧹"
