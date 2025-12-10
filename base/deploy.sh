#!/bin/bash

# --- File Paths (Relative to the 'base' directory) ---
DB_INIT_FILE="db/mysql-init.sql"
SECRET_MANIFEST="db/mysql-secret.yaml"
DB_MANIFEST="db/mysql-deployment.yaml"
SERVICE_MANIFEST="db/mysql-service.yaml"
NAMESPACE_MANIFEST="namespace/namespace-machine-monitoring.yaml" # Assuming the namespace file is in /base/namespace

# Set the namespace for all operations (Adjust this if needed)
TARGET_NAMESPACE="machine-monitoring" 

echo "--- Starting Database Infrastructure Deployment from /base directory ---"

# 1. Apply Namespace (ensure it exists first)
echo "Step 1: Applying Namespace from ${NAMESPACE_MANIFEST}..."
kubectl apply -f "${NAMESPACE_MANIFEST}"

# 2. --- NEW STEP: Apply the Secret from the YAML file ---
echo "Step 2: Applying the required Secret 'mysql-secret' from ${SECRET_MANIFEST}..."
# This command ensures the Secret is created or updated before the Deployment starts.
kubectl apply -f "${SECRET_MANIFEST}" --namespace="${TARGET_NAMESPACE}"

# 3. Create or Update the ConfigMap from the SQL file
# The script finds the SQL file inside the 'db' subdirectory.
echo "Step 3: Creating/Updating ConfigMap 'mysql-initdb-config' from ${DB_INIT_FILE}..."
kubectl create configmap mysql-initdb-config \
    --from-file="${DB_INIT_FILE}" \
    --namespace="${TARGET_NAMESPACE}" \
    -o yaml --dry-run=client | kubectl apply -f -

# 4. Apply the Deployment (which mounts the now-created ConfigMap) and Service manifests
echo "Step 4: Applying MySQL Deployment and Service manifests from ${DB_MANIFEST}..."
kubectl apply -f "${DB_MANIFEST}" --namespace="${TARGET_NAMESPACE}"
kubectl apply -f "${SERVICE_MANIFEST}" --namespace="${TARGET_NAMESPACE}"

# 5. Force Pod Restart
echo "Step 5: Forcing Deployment rollout restart to execute the new init script..."
kubectl rollout restart deployment/mysql --namespace="${TARGET_NAMESPACE}"

echo "--- Deployment Complete! ---"