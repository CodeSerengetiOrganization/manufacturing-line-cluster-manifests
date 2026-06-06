#!/bin/bash
set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "${SCRIPT_DIR}/../.." && pwd)"
NAMESPACE="mes-prod"
NAMESPACE_MANIFEST="${REPO_ROOT}/namespaces/namespace-mes-prod.yaml"
DB_INIT_FILE="${SCRIPT_DIR}/mysql-init.sql"
SECRET_MANIFEST="${SCRIPT_DIR}/mes-mysql-secret.yaml"

echo "=== mes-db (mes-mysql) deployment in namespace ${NAMESPACE} ==="

if [[ ! -f "${SECRET_MANIFEST}" ]]; then
  echo "ERROR: Create ${SECRET_MANIFEST} locally (gitignored) before deploy."
  echo "       Copy from mes-mysql-secret.yaml.example"
  exit 1
fi

if ! grep -qE '^[[:space:]]*name:[[:space:]]*mes-mysql-secret[[:space:]]*$' "${SECRET_MANIFEST}"; then
  echo "ERROR: ${SECRET_MANIFEST} must set metadata.name to mes-mysql-secret (see mes-mysql-secret.yaml.example)."
  exit 1
fi

echo "Applying namespace from ${NAMESPACE_MANIFEST}..."
kubectl apply -f "${NAMESPACE_MANIFEST}"

echo "Applying mes-mysql secret..."
kubectl apply -f "${SECRET_MANIFEST}" -n "${NAMESPACE}"

echo "Creating/updating ConfigMap mes-mysql-initdb-config from mysql-init.sql..."
kubectl create configmap mes-mysql-initdb-config \
  --from-file=mysql-init.sql="${DB_INIT_FILE}" \
  -n "${NAMESPACE}" \
  -o yaml --dry-run=client | kubectl apply -f -

echo "Applying Deployment and Service via kustomize..."
kubectl apply -k "${SCRIPT_DIR}"

echo "Waiting for mes-mysql rollout..."
kubectl rollout status deployment/mes-mysql -n "${NAMESPACE}" --timeout=120s

kubectl get pods,svc -n "${NAMESPACE}" -l app=mes-mysql

echo "=== mes-db deploy complete ==="
echo "JDBC (in-cluster): jdbc:mysql://mes-mysql.${NAMESPACE}.svc.cluster.local:3306/mes_db"
