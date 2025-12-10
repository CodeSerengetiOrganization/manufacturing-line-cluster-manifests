#!/bin/bash

# --- Configuration ---
TARGET_NAMESPACE="machine-monitoring"

echo "--- Starting Cleanup of Kubernetes Resources in Namespace: ${TARGET_NAMESPACE} ---"

# 1. Delete the Deployment
# Deleting the Deployment will automatically terminate the running Pods.
echo "1. Deleting Deployment 'mysql'..."
kubectl delete deployment mysql --namespace="${TARGET_NAMESPACE}" 
# The command continues even if the resource is already gone, making the script robust.

# 2. Delete the Service
# This removes the stable network entry (ClusterIP) for the database.
echo "2. Deleting Service 'mysql'..."
kubectl delete service mysql --namespace="${TARGET_NAMESPACE}"

# 3. Delete the ConfigMap
# This removes the initialization script content (mysql-init.sql) from the cluster.
echo "3. Deleting ConfigMap 'mysql-initdb-config'..."
kubectl delete configmap mysql-initdb-config --namespace="${TARGET_NAMESPACE}"

# 4. Delete the Secret
# This removes the sensitive credentials (mysql-secret).
echo "4. Deleting Secret 'mysql-secret'..."
kubectl delete secret mysql-secret --namespace="${TARGET_NAMESPACE}"

# 5. Delete the PVC (Optional, uncomment if you use Persistent Volumes)
# If you were using a PersistentVolumeClaim (PVC) instead of emptyDir, you would delete it here.
# echo "5. Deleting PersistentVolumeClaim 'mysql-pvc'..."
# kubectl delete pvc mysql-pvc --namespace="${TARGET_NAMESPACE}" 

echo "--- Cleanup Complete! ---"
echo "All application resources (Deployment, Service, ConfigMap, Secret) deleted from ${TARGET_NAMESPACE}."
echo "You can now run './deploy.sh' to start fresh."