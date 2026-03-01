#!/bin/bash
set -e

IMAGE_TAR="mms-backend-1.0.0-SNAPSHOT.tar"
NAMESPACE="machine-monitoring"

# ------------------------------------------------------------
# STEP 1 — Apply GHCR Pull Secret
# This allows k3s/containerd to authenticate and pull the image
# ------------------------------------------------------------
echo "=== Step 1: Apply GHCR image pull secret ==="
kubectl apply -f mms-backend-ghcr-secret.yaml -n $NAMESPACE

# ------------------------------------------------------------
# STEP 2 — Apply Email Configurations
# These include:
#   - Secret: sensitive email credentials
#   - ConfigMap: non-sensitive email settings such as host/port
# ------------------------------------------------------------
echo "=== Step 2: Apply email ConfigMap and Secret ==="
kubectl apply -f mms-backend-email-secret.yaml -n $NAMESPACE
kubectl apply -f mms-backend-email-config.yaml -n $NAMESPACE

# ------------------------------------------------------------
# STEP 3 — Apply Database Configurations
# These include:
#   - Secret: DB username/password
#   - ConfigMap: DB URL or non-sensitive values
# ------------------------------------------------------------
echo "=== Step 3: Apply database ConfigMap and Secret ==="
kubectl apply -f mms-backend-db-config.yaml -n $NAMESPACE
kubectl apply -f mms-backend-db-secret.yaml -n $NAMESPACE

# ------------------------------------------------------------
# STEP 4 — Apply Kubernetes Base Manifests (Deployment + Service)
# Using kustomize to process overlays in this folder
# ------------------------------------------------------------
echo "=== Step 4: Apply Kubernetes manifests via kustomize ==="
kubectl apply -k . -n $NAMESPACE

# ------------------------------------------------------------
# STEP 5 — Wait for the backend pod to become ready
# Ensures deployment becomes fully available
# ------------------------------------------------------------
echo "=== Step 5: Waiting for backend deployment to become available ==="
kubectl wait --for=condition=available deployment/mms-backend \
  -n $NAMESPACE --timeout=70s

# ------------------------------------------------------------
# STEP 6 — Display deployment status
# Shows pod status and the service with its assigned NodePort
# ------------------------------------------------------------
echo "=== Step 6: Displaying pods and service status ==="
kubectl get pods -n $NAMESPACE
kubectl get svc -n $NAMESPACE

# ------------------------------------------------------------
# STEP 7 — (Optional) Port forward for local access
# This exposes the service directly to localhost:8080
# ------------------------------------------------------------
echo "=== Step 7: Starting port-forward on localhost:8080 ==="
echo "Visit: http://localhost:8080"
kubectl port-forward svc/mms-backend-service -n $NAMESPACE 8080:8080

echo "=== Deployment completed successfully ==="
