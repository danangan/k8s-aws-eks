#!/bin/bash

set -euo pipefail

# Builds the demo app image, pushes it to ECR, then rolls it out via Helm.
# Assumes deploy.sh has already been run (EKS cluster + ECR repo provisioned,
# kubeconfig pointed at the cluster).

ECR_REPO_URL="$(terraform -chdir=../root_modules/infra output -raw ecr_repository_url)"
REGISTRY="${ECR_REPO_URL%%/*}"
TAG="$(date +%Y%m%d%H%M%S)"

echo "Logging in to ECR..."

aws ecr get-login-password --region us-east-1 \
  | docker login --username AWS --password-stdin "${REGISTRY}"

echo "Building and pushing ${ECR_REPO_URL}:${TAG}..."

docker build -t "${ECR_REPO_URL}:${TAG}" .

echo "Deploying via Helm..."

helm upgrade --install app . \
  --set image.repository="${ECR_REPO_URL}" \
  --set image.tag="${TAG}"

echo "Done!"
