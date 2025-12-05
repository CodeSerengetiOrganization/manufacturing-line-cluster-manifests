#!/bin/bash
set -e

IMAGE_TAR="mms-backend-1.0.0-SNAPSHOT.tar"
NAMESPACE="machine-monitoring"

# echo "=== Step 1: Import Docker image into k3s containerd ==="
# sudo k3s ctr images import $IMAGE_TAR

echo "=== Step 1: Apply GitHub registry secret ==="
# Apply the secret (classic PAT stored inside secret.yaml)
kubectl apply -f mms-backend-ghcr-secret.yaml -n $NAMESPACE
kubectl apply -f mms-backend-email-secret.yaml -n $NAMESPACE

echo "=== Step 1.5: Apply Email related configmap ==="
kubectl apply -f mms-backend-email-config.yaml -n $NAMESPACE

echo "=== Step 1.6: Apply DataSource related configmap ==="
kubectl apply -f mms-backend-db-config.yaml -n $NAMESPACE

echo "=== Step 1.7: Apply DataSource related secret ==="
kubectl apply -f mms-backend-db-secret.yaml -n $NAMESPACE

echo "=== Step 2: Apply Kubernetes manifests (kustomize) ==="
kubectl apply -k . -n $NAMESPACE

# echo "=== Step 2.1: Apply Kubernetes secret if exists ==="
# if [ -f "./secret.yaml" ]; then
#   echo "Applying secret.yaml..."
#   kubectl apply -f ./secret.yaml -n $NAMESPACE
# else
#   echo "No secret.yaml found. Skipping secret apply."
# fi

echo "=== Step 3: Wait for backend deployment to be ready ==="
kubectl wait --for=condition=available deployment/mms-backend \
  -n $NAMESPACE --timeout=60s

echo "=== Step 4: Check pod and service status ==="
kubectl get pods -n $NAMESPACE
kubectl get svc -n $NAMESPACE

echo "=== Step 5: Port-forward to localhost:8080 ==="
echo "Go to: http://localhost:8080"
kubectl port-forward svc/mms-backend-service -n $NAMESPACE 8080:8080



# #!/bin/bash
# set -e

# echo "Building Spring Boot JAR..."
# mvn clean package -DskipTests

# echo "Building container image into containerd..."
# sudo nerdctl build -t mms-backend:1.0.0 .

# echo "Applying K3s manifests..."
# kubectl apply -f deployment.yaml
# kubectl apply -f service.yaml


## the following code is build & deploy script for k3s cluster together
# #!/bin/bash

# set -e

# IMAGE_NAME="mms-backend:1.0.0"
# IMAGE_FILE="mms-backend.tar"
# NAMESPACE="machine-monitoring"

# echo "=== Step 1: Build Docker image ==="
# docker build -t $IMAGE_NAME .

# echo "=== Step 2: Save image to file ==="
# docker save -o $IMAGE_FILE $IMAGE_NAME

# echo "=== Step 3: Import image into k3s containerd ==="
# sudo k3s ctr images import $IMAGE_FILE

# echo "=== Step 4: Apply Kubernetes manifests ==="
# kubectl apply -k . -n $NAMESPACE

# echo "=== Step 5: Wait for deployment to become ready ==="
# kubectl wait --for=condition=available deployment/mms-backend \
#   -n $NAMESPACE --timeout=60s

# echo "=== Step 6: Check pod and service status ==="
# kubectl get pods -n $NAMESPACE
# kubectl get svc -n $NAMESPACE

# echo "=== Step 7: Start port-forward on localhost:8080 ==="
# echo "Backend available at http://localhost:8080"
# kubectl port-forward svc/mms-backend-service -n $NAMESPACE 8080:8080
