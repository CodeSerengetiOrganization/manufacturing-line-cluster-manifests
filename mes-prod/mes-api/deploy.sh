#!/bin/bash
set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "${SCRIPT_DIR}/../.." && pwd)"
NAMESPACE="mes-prod"
NAMESPACE_MANIFEST="${REPO_ROOT}/namespaces/namespace-mes-prod.yaml"
DB_SECRET_MANIFEST="${SCRIPT_DIR}/mes-api-db-secret.yaml"
GHCR_SECRET_MANIFEST="${SCRIPT_DIR}/mes-api-ghcr-secret.yaml"

echo "=== mes-api deployment in namespace ${NAMESPACE} ==="

for manifest in "${DB_SECRET_MANIFEST}" "${GHCR_SECRET_MANIFEST}"; do
  if [[ ! -f "${manifest}" ]]; then
    echo "ERROR: Create ${manifest} locally (gitignored) before deploy."
    echo "       Copy from the matching *.example file in this directory."
    exit 1
  fi
done

if ! grep -qE '^[[:space:]]*name:[[:space:]]*mes-api-db-secret[[:space:]]*$' "${DB_SECRET_MANIFEST}"; then
  echo "ERROR: ${DB_SECRET_MANIFEST} must set metadata.name to mes-api-db-secret."
  exit 1
fi

if ! grep -qE '^[[:space:]]*name:[[:space:]]*mes-api-ghcr-secret[[:space:]]*$' "${GHCR_SECRET_MANIFEST}"; then
  echo "ERROR: ${GHCR_SECRET_MANIFEST} must set metadata.name to mes-api-ghcr-secret."
  exit 1
fi

echo "Applying namespace from ${NAMESPACE_MANIFEST}..."
kubectl apply -f "${NAMESPACE_MANIFEST}"

echo "Applying mes-api secrets..."
kubectl apply -f "${GHCR_SECRET_MANIFEST}" -n "${NAMESPACE}"
kubectl apply -f "${DB_SECRET_MANIFEST}" -n "${NAMESPACE}"

echo "Applying Deployment, Service, and ConfigMap via kustomize..."
kubectl apply -k "${SCRIPT_DIR}"

echo "Waiting for mes-api rollout..."
kubectl rollout status deployment/mes-api -n "${NAMESPACE}" --timeout=180s

kubectl get pods,svc -n "${NAMESPACE}" -l app=mes-api

echo "=== mes-api deploy complete ==="
echo "In-cluster HTTP: http://mes-api-service.${NAMESPACE}.svc.cluster.local:8080"
echo "NodePort (if k3s): http://<node-ip>:30082"
echo ""
echo "Prerequisites:"
echo "  - mes-db deployed (mes-mysql in ${NAMESPACE})"
echo "  - Kafka running in machine-monitoring (topic: manufacturing-results-topic)"
