#!/bin/bash
NAMESPACE="machine-monitoring"
STRIMZI_NAMESPACE="strimzi"
STRIMZI_OPERATOR_NAME="strimzi-kafka-operator"

echo "--- Starting Kafka Cleanup ---"

# 1. Delete Kafka Topics and Cluster resources first
echo "Deleting Kafka Topics and Cluster..."
kubectl delete -k kafka-cluster/ --namespace "${NAMESPACE}" --ignore-not-found
kubectl delete -k topics/ --namespace "${NAMESPACE}" --ignore-not-found

# 2. Delete the Kafka Custom Resource (if not handled by kustomize)
kubectl delete kafka kafka -n "${NAMESPACE}" --ignore-not-found

# 2b. (Optional) Delete broker PVC(s) to avoid "Invalid cluster.id" on redeploy.
#     Uncomment to start completely fresh; all data on the volume is lost.
#     See base/kafka/PVC-CLUSTER-ID-ISSUE.md for details.
kubectl delete pvc data-kafka-kafka-broker-0 -n "${NAMESPACE}" --ignore-not-found

# 3. Uninstall Strimzi Operator
echo "Uninstalling Strimzi Operator..."
helm uninstall "${STRIMZI_OPERATOR_NAME}" -n "${STRIMZI_NAMESPACE}"

# 4. Cleanup Namespaces (Optional)
# Warning: This deletes everything in the namespace
# kubectl delete namespace "${NAMESPACE}"
# kubectl delete namespace "${STRIMZI_NAMESPACE}"

echo "✓ Cleanup complete."