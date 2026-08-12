#!/bin/bash
# Build both app images and push to the ECR repos this config created.
# Run this AFTER `terraform apply` (repos must exist first), and again any
# time you change app code. Run from the terraform-ec2-part3 directory.
#
# Requires: docker, aws cli (configured), terraform (to read outputs), git.

set -euo pipefail

APP_REPO_URL="${APP_REPO_URL:-https://github.com/Aswin-Shine/tutedude-flask-app.git}"
AWS_REGION="$(terraform output -raw ecr_backend_repository_url | cut -d. -f4)"
BACKEND_REPO_URL="$(terraform output -raw ecr_backend_repository_url)"
FRONTEND_REPO_URL="$(terraform output -raw ecr_frontend_repository_url)"
IMAGE_TAG="${IMAGE_TAG:-latest}"

WORKDIR="$(mktemp -d)"
trap 'rm -rf "$WORKDIR"' EXIT

echo "Cloning $APP_REPO_URL ..."
git clone --depth 1 "$APP_REPO_URL" "$WORKDIR/app"

echo "Logging in to ECR ($AWS_REGION) ..."
aws ecr get-login-password --region "$AWS_REGION" \
  | docker login --username AWS --password-stdin "$(echo "$BACKEND_REPO_URL" | cut -d/ -f1)"

echo "Building + pushing backend ($BACKEND_REPO_URL:$IMAGE_TAG) ..."
docker build -t "$BACKEND_REPO_URL:$IMAGE_TAG" "$WORKDIR/app/backend"
docker push "$BACKEND_REPO_URL:$IMAGE_TAG"

echo "Building + pushing frontend ($FRONTEND_REPO_URL:$IMAGE_TAG) ..."
docker build -t "$FRONTEND_REPO_URL:$IMAGE_TAG" "$WORKDIR/app/frontend"
docker push "$FRONTEND_REPO_URL:$IMAGE_TAG"

echo ""
echo "Pushed. ECS services won't pick up a ':latest' tag change on their own --"
echo "force a new deployment for both:"
echo ""
echo "  aws ecs update-service --cluster $(terraform output -raw ecs_cluster_name) --service ${project_name:-tutedude-assignment6}-backend-svc --force-new-deployment --region $AWS_REGION"
echo "  aws ecs update-service --cluster $(terraform output -raw ecs_cluster_name) --service ${project_name:-tutedude-assignment6}-frontend-svc --force-new-deployment --region $AWS_REGION"
