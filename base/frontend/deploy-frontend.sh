#!/bin/bash
set -e  # Exit immediately if any command fails

# --- Configuration ---
# The organization and repository name for the container registry
REPO_URL="ghcr.io/codeserengetiorganization/mms-ui"
# Use 'latest' or 'develop' tag as a known entry point for the CI-built image
TARGET_TAG="1.0.0-dev"
NAMESPACE="machine-monitoring"

# The name of the deployment manifest file (in the current directory)
MANIFEST_FILE="frontend-deployment.yaml"
SERVICE_FILE="frontend-service.yaml"

echo "--- Local WSL2 Frontend Deployment ---"

# 1. Pull the latest image from GHCR
# echo "Pulling latest image: ${REPO_URL}:${TARGET_TAG}"
# docker pull ${REPO_URL}:${TARGET_TAG}

# if [ $? -ne 0 ]; then
#     echo "ERROR: Failed to pull the latest image from GHCR. Check permissions."
#     exit 1
# fi

# 2. Get the actual full SHA-based tag (the one that GitHub Action used)
# This is retrieved from the image's manifest, if possible, 
# or we use the TARGET_TAG for simplicity.
# For simplicity, we assume the latest successful build is tagged 'latest'
FULL_IMAGE_NAME="${REPO_URL}:${TARGET_TAG}"
echo "Deploying image: ${FULL_IMAGE_NAME}"

# 3. Create and Patch the Deployment YAML
TEMP_MANIFEST="/tmp/frontend-.$$.yaml"
cp "${MANIFEST_FILE}" "${TEMP_MANIFEST}"

PLACEHOLDER="ghcr.io/your-org/angular-frontend:LATEST_BUILD_TAG" 
echo "Patching image in deployment manifest..."

# Patch the deployment with the latest image name
# Note: For this to work, you MUST update your frontend-manifests.yaml
# to use a simple, reliable placeholder like the one defined in PLACEHOLDER
sed -i -e "s@image: .*@image: ${FULL_IMAGE_NAME}@g" "${TEMP_MANIFEST}"

if [ $? -ne 0 ]; then
    echo "ERROR: Failed to patch the manifest file (${TEMP_MANIFEST})."
    rm "${TEMP_MANIFEST}"
    exit 1
fi

# 4. Apply the patched manifest to the local K8s cluster (WSL2 Ubuntu)
echo "Applying deployment and service to the local cluster..."
kubectl apply -f "${TEMP_MANIFEST}" -n $NAMESPACE

if [ $? -eq 0 ]; then
    echo "Deployment successful!"
    echo "Access your app via NodePort: http://<Your_WSL2_IP>:30080"
else
    echo "Deployment failed. Check kubectl logs for details."
fi

# 5. Apply the Service (This should be added)
echo "Applying Service definition: ${SERVICE_FILE}"
kubectl apply -f "${SERVICE_FILE}" -n $NAMESPACE
if [ $? -ne 0 ]; then
    echo "ERROR: Failed to apply the service definition (${SERVICE_FILE})."
    rm "${TEMP_MANIFEST}"
    exit 1
fi
# 6. Clean up the temporary file
rm "${TEMP_MANIFEST}"