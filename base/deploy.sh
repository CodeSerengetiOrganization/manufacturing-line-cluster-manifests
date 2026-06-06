#!/bin/bash

# --- File Paths (Relative to the repo root) ---
REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
DB_INIT_FILE="${REPO_ROOT}/base/db/mysql-init.sql"
SECRET_MANIFEST="${REPO_ROOT}/base/db/mysql-secret.yaml"
DB_MANIFEST="${REPO_ROOT}/base/db/mysql-deployment.yaml"
SERVICE_MANIFEST="${REPO_ROOT}/base/db/mysql-service.yaml"
NAMESPACE_MANIFEST="${REPO_ROOT}/namespaces/namespace-machine-monitoring.yaml"

TARGET_NAMESPACE="machine-monitoring"

echo "--- Starting Database Infrastructure Deployment from /base directory ---"

# 1. Apply Namespace (ensure it exists first)
echo "Step 1: Applying Namespace from ${NAMESPACE_MANIFEST}..."
kubectl apply -f "${NAMESPACE_MANIFEST}"

# 2. Apply the Secret from the YAML file
echo "Step 2: Applying the required Secret 'mysql-secret' from ${SECRET_MANIFEST}..."
kubectl apply -f "${SECRET_MANIFEST}" --namespace="${TARGET_NAMESPACE}"

# 3. Create or Update the ConfigMap from the SQL file
echo "Step 3: Creating/Updating ConfigMap 'mysql-initdb-config' from ${DB_INIT_FILE}..."
kubectl create configmap mysql-initdb-config \
    --from-file="${DB_INIT_FILE}" \
    --namespace="${TARGET_NAMESPACE}" \
    -o yaml --dry-run=client | kubectl apply -f -

# 4. Apply the Deployment and Service manifests
echo "Step 4: Applying MySQL Deployment and Service manifests from ${DB_MANIFEST}..."
kubectl apply -f "${DB_MANIFEST}" --namespace="${TARGET_NAMESPACE}"
kubectl apply -f "${SERVICE_MANIFEST}" --namespace="${TARGET_NAMESPACE}"

# 5. Force Pod Restart
echo "Step 5: Forcing Deployment rollout restart to execute the new init script..."
kubectl rollout restart deployment/mysql --namespace="${TARGET_NAMESPACE}"

echo "--- Deployment Complete! ---"
