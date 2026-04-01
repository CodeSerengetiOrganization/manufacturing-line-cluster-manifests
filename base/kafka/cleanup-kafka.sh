#!/bin/bash
set -e  # ADDED: fail fast for deterministic behavior

NAMESPACE="machine-monitoring"
STRIMZI_NAMESPACE="strimzi"
STRIMZI_OPERATOR_NAME="strimzi-kafka-operator"

echo "--- Starting Kafka Cleanup ---"

# =========================================================
# 1. Delete Kafka Topics FIRST (critical ordering)
# =========================================================
echo "Deleting Kafka topics (CRs)..."

# CHANGED: explicitly delete ALL topics instead of relying only on kustomize
kubectl delete kafkatopics --all -n "${NAMESPACE}" --ignore-not-found

# OPTIONAL: still delete from kustomize in case of drift
kubectl delete -k topics/ --namespace "${NAMESPACE}" --ignore-not-found || true

# ADDED: wait for topics to fully terminate (prevents finalizer deadlock)
echo "Waiting for KafkaTopics to be fully deleted..."
kubectl wait --for=delete kafkatopics --all \
  -n "${NAMESPACE}" --timeout=180s || {

  echo "WARNING: Some KafkaTopics are stuck (likely finalizers). Forcing cleanup..."

  # ADDED: force remove finalizers if operator cannot complete cleanup
  kubectl get kafkatopics -n "${NAMESPACE}" -o name | \
  xargs -r -I {} kubectl patch {} -n "${NAMESPACE}" \
    --type=json -p='[{"op":"remove","path":"/metadata/finalizers"}]' || true
}

# =========================================================
# 2. Delete Kafka cluster (ONLY after topics are gone)
# =========================================================
echo "Deleting Kafka cluster..."

# CHANGED: keep kustomize deletion but ensure explicit delete as fallback
kubectl delete -k kafka-cluster/ --namespace "${NAMESPACE}" --ignore-not-found || true
kubectl delete kafka kafka -n "${NAMESPACE}" --ignore-not-found

# OPTIONAL: wait for Kafka CR to disappear
echo "Waiting for Kafka cluster to be deleted..."
kubectl wait --for=delete kafka/kafka \
  -n "${NAMESPACE}" --timeout=180s || true

# =========================================================
# 3. Delete PVCs (data cleanup)
# =========================================================
# NOTE: This is destructive but avoids cluster.id issues
echo "Deleting Kafka PVCs..."
kubectl delete pvc -n "${NAMESPACE}" --all --ignore-not-found

# =========================================================
# 4. Uninstall Strimzi Operator (LAST step)
# =========================================================
echo "Uninstalling Strimzi Operator..."

# CHANGED: guard against missing release
if helm list -n "${STRIMZI_NAMESPACE}" | grep -q "${STRIMZI_OPERATOR_NAME}"; then
  helm uninstall "${STRIMZI_OPERATOR_NAME}" -n "${STRIMZI_NAMESPACE}"
else
  echo "Strimzi operator not found, skipping uninstall"
fi

# =========================================================
# 5. Optional namespace cleanup
# =========================================================
# kubectl delete namespace "${NAMESPACE}"
# kubectl delete namespace "${STRIMZI_NAMESPACE}"

echo "✓ Cleanup complete."