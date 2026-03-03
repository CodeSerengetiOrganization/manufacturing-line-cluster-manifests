#!/bin/bash
set -e  # Exit immediately if any command fails

# --- Configuration (React frontend) ---
# Set to your React app container registry; override in CI if needed
REPO_URL="ghcr.io/codeserengetiorganization/mms-ui-react"
TARGET_TAG="1.0.0-dev"
NAMESPACE="machine-monitoring"

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
MANIFEST_FILE="${SCRIPT_DIR}/deployment.yaml"
SERVICE_FILE="${SCRIPT_DIR}/service.yaml"

echo "--- K3s React Frontend Deployment ---"

FULL_IMAGE_NAME="${REPO_URL}:${TARGET_TAG}"
echo "Deploying image: ${FULL_IMAGE_NAME}"

TEMP_MANIFEST="/tmp/react-frontend-deployment.$$.yaml"
cp "${MANIFEST_FILE}" "${TEMP_MANIFEST}"

echo "Patching image in deployment manifest..."
sed -i -e "s@image: .*@image: ${FULL_IMAGE_NAME}@g" "${TEMP_MANIFEST}"

if [ $? -ne 0 ]; then
    echo "ERROR: Failed to patch the manifest file (${TEMP_MANIFEST})."
    rm -f "${TEMP_MANIFEST}"
    exit 1
fi

echo "Applying deployment to K3s cluster..."
kubectl apply -f "${TEMP_MANIFEST}" -n $NAMESPACE

if [ $? -eq 0 ]; then
    echo "Deployment successful!"
else
    echo "Deployment failed. Check kubectl logs for details."
    rm -f "${TEMP_MANIFEST}"
    exit 1
fi

echo "Applying Service definition: ${SERVICE_FILE}"
kubectl apply -f "${SERVICE_FILE}" -n $NAMESPACE
if [ $? -ne 0 ]; then
    echo "ERROR: Failed to apply the service definition (${SERVICE_FILE})."
    rm -f "${TEMP_MANIFEST}"
    exit 1
fi

rm -f "${TEMP_MANIFEST}"

echo "React frontend deployed successfully!"
echo "Access React app via NodePort 30082: http://<node-ip>:30082"
