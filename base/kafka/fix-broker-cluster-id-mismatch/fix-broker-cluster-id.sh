#!/bin/bash
# Fix "Invalid cluster.id in meta.properties" by updating the broker PVC to match
# the cluster ID expected by the current Strimzi Kafka cluster (keeps existing data).
#
# Prereqs: Pause reconciliation and scale StrimziPodSet to 0 so the broker pod
# is gone and the PVC is free. This script does that, runs the edit pod, then
# restores the broker.
#
# Usage: run from base/kafka/
#   ./fix-broker-cluster-id.sh [EXPECTED_CLUSTER_ID]
# If EXPECTED_CLUSTER_ID is omitted, we try to read it from Kafka status, or you
# can set EXPECTED_CLUSTER_ID in the environment.
set -e

NAMESPACE="machine-monitoring"
KAFKA_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PVC_EDIT_YAML="${KAFKA_DIR}/pvc-edit-pod.yaml"
BROKER_PVC="data-kafka-kafka-broker-0"
STRIMZI_PODSET="kafka-kafka-broker"
NODE_POOL="kafka-broker"
KAFKA_CR="kafka"
META_PATH="/var/lib/kafka/data/kafka-log0/meta.properties"

# Expected cluster ID (from Strimzi; get from kubectl get kafka kafka -n machine-monitoring -o jsonpath='{.status.clusterId}')
EXPECTED_CLUSTER_ID="${EXPECTED_CLUSTER_ID:-${1:-}}"

if [[ -z "${EXPECTED_CLUSTER_ID}" ]]; then
  echo "Attempting to read expected cluster ID from Kafka status..."
  if EXPECTED_CLUSTER_ID=$(kubectl get kafka "${KAFKA_CR}" -n "${NAMESPACE}" -o jsonpath='{.status.clusterId}' 2>/dev/null); then
    if [[ -z "${EXPECTED_CLUSTER_ID}" ]]; then
      echo "Kafka status has no clusterId yet. Provide it explicitly:"
      echo "  ./fix-broker-cluster-id.sh DiYGkbUkQZ2YbAg9PZ-zew"
      echo "Or set EXPECTED_CLUSTER_ID=... (get from broker log: 'Expected ...')"
      exit 1
    fi
    echo "Using cluster ID from Kafka status: ${EXPECTED_CLUSTER_ID}"
  else
    echo "Could not read Kafka status. Provide expected cluster ID (from broker log 'Expected <id>'):"
    echo "  ./fix-broker-cluster-id.sh DiYGkbUkQZ2YbAg9PZ-zew"
    exit 1
  fi
fi

echo "--- Fix broker meta.properties cluster ID ---"
echo "Namespace: ${NAMESPACE}"
echo "Expected cluster ID: ${EXPECTED_CLUSTER_ID}"
echo ""

# 1. Pause reconciliation
echo "1. Pausing Kafka reconciliation..."
kubectl annotate kafka "${KAFKA_CR}" -n "${NAMESPACE}" strimzi.io/pause-reconciliation=true --overwrite

# 2. Scale StrimziPodSet to 0
echo "2. Scaling StrimziPodSet to 0..."
kubectl patch strimzipodset "${STRIMZI_PODSET}" -n "${NAMESPACE}" --type=merge -p '{"spec":{"pods":[]}}'

echo "   Waiting for broker pod to terminate..."
for i in {1..30}; do
  if ! kubectl get pod -n "${NAMESPACE}" -l strimzi.io/cluster=kafka --no-headers 2>/dev/null | grep -q .; then
    break
  fi
  sleep 2
done
if kubectl get pod -n "${NAMESPACE}" -l strimzi.io/cluster=kafka --no-headers 2>/dev/null | grep -q .; then
  echo "   WARNING: Broker pod still present. Proceeding anyway; pvc-edit may fail if PVC is in use."
fi

# 3. Create pvc-edit pod
echo "3. Creating pvc-edit pod..."
kubectl apply -f "${PVC_EDIT_YAML}" -n "${NAMESPACE}"
kubectl wait -n "${NAMESPACE}" --for=condition=Ready pod/pvc-edit --timeout=120s

# 4. Edit meta.properties
echo "4. Current meta.properties:"
kubectl exec -n "${NAMESPACE}" pvc-edit -- cat "${META_PATH}" || true
echo ""
echo "   Writing cluster.id=${EXPECTED_CLUSTER_ID} to meta.properties..."
kubectl exec -n "${NAMESPACE}" pvc-edit -- sh -c "echo \"cluster.id=${EXPECTED_CLUSTER_ID}\" > ${META_PATH}"
echo "   Verifying:"
kubectl exec -n "${NAMESPACE}" pvc-edit -- cat "${META_PATH}"

# 5. Delete pvc-edit and restore broker
echo "5. Deleting pvc-edit pod..."
kubectl delete pod pvc-edit -n "${NAMESPACE}" --ignore-not-found

echo "6. Restoring broker (node pool replicas=1, resume reconciliation)..."
kubectl patch kafkanodepool "${NODE_POOL}" -n "${NAMESPACE}" --type=merge -p '{"spec":{"replicas":1}}'
kubectl annotate kafka "${KAFKA_CR}" -n "${NAMESPACE}" strimzi.io/pause-reconciliation- 2>/dev/null || true

echo ""
echo "✓ Done. Watch the broker with:"
echo "  kubectl get pods -n ${NAMESPACE} -l strimzi.io/cluster=kafka -w"
echo "  kubectl logs -n ${NAMESPACE} kafka-kafka-broker-0 -c kafka -f"
echo ""
