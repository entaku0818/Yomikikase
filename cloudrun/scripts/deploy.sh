#!/bin/bash
set -e

# ===========================================
# Cloud Run Deployment Script
# ===========================================
#
# Required gcloud configuration:
#   Project: voiceyourtext
#   Region: asia-northeast1
#   Account: entaku19890818@gmail.com
#
# To check current config:
#   gcloud config list
#
# To set config:
#   gcloud config set project voiceyourtext
#   gcloud config set compute/region asia-northeast1
#
# ===========================================

PROJECT_ID="voiceyourtext"
REGION="asia-northeast1"
SERVICE_NAME="voiceyourtext-tts"
IMAGE_NAME="gcr.io/${PROJECT_ID}/${SERVICE_NAME}"

echo "=== Cloud Run Deployment ==="
echo "Project: ${PROJECT_ID}"
echo "Region: ${REGION}"
echo "Service: ${SERVICE_NAME}"
echo ""

# Verify gcloud config
echo "Checking gcloud configuration..."
CURRENT_PROJECT=$(gcloud config get-value project 2>/dev/null)
if [ "$CURRENT_PROJECT" != "$PROJECT_ID" ]; then
    echo "Warning: Current project is '$CURRENT_PROJECT', expected '$PROJECT_ID'"
    echo "Run: gcloud config set project $PROJECT_ID"
    exit 1
fi

# Build and push image
echo ""
echo "Building and pushing Docker image..."
cd "$(dirname "$0")/.."
gcloud builds submit --tag "${IMAGE_NAME}"

# Deploy to Cloud Run
echo ""
echo "Deploying to Cloud Run..."
gcloud run deploy "${SERVICE_NAME}" \
    --image "${IMAGE_NAME}" \
    --region "${REGION}" \
    --platform managed \
    --allow-unauthenticated \
    --timeout=1800

echo ""
echo "=== Deployment Complete ==="
gcloud run services describe "${SERVICE_NAME}" --region "${REGION}" --format="value(status.url)"
