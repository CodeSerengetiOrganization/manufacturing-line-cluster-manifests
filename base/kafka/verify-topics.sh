#!/bin/bash
set -e

# --- Configuration ---
NAMESPACE="machine-monitoring"

echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "Kafka Topics Verification"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""

# Level 1: CRD Status Verification
echo "Level 1: CRD Status Verification"
echo "=================================="
echo ""

echo "Checking KafkaTopic CRD resources..."
kubectl get kafkatopic -n "${NAMESPACE}"

echo ""
echo "Detailed topic information:"
echo "---"
kubectl describe kafkatopic eol-raw-data -n "${NAMESPACE}"
echo ""
kubectl describe kafkatopic eol-test-alerts -n "${NAMESPACE}"

echo ""
echo "✓ Level 1 (CRD) Verification Complete"
echo ""

# Level 2: Broker-Level Verification
echo "Level 2: Broker-Level Verification"
echo "===================================="
echo ""

# Get Kafka broker pod name
echo "Finding Kafka broker pod..."
KAFKA_BROKER_POD=$(kubectl get pods -n "${NAMESPACE}" -l strimzi.io/cluster=kafka -o jsonpath='{.items[?(@.metadata.name=~"kafka.*broker.*")].metadata.name}' | awk '{print $1}')

if [ -z "$KAFKA_BROKER_POD" ]; then
    echo "Error: Could not find Kafka broker pod"
    echo "Available pods:"
    kubectl get pods -n "${NAMESPACE}" -l strimzi.io/cluster=kafka
    exit 1
fi

echo "Using broker pod: $KAFKA_BROKER_POD"
echo ""

# List topics in broker
echo "Topics in Kafka broker:"
kubectl exec "$KAFKA_BROKER_POD" -n "${NAMESPACE}" -c kafka -- \
    bin/kafka-topics.sh --bootstrap-server localhost:9092 --list

echo ""
echo "Verifying eol-raw-data retention settings (expected: 172800000 ms = 48 hours):"
echo "---"
kubectl exec "$KAFKA_BROKER_POD" -n "${NAMESPACE}" -c kafka -- \
    bin/kafka-configs.sh --bootstrap-server localhost:9092 \
    --entity-type topics --entity-name eol-raw-data --describe 2>/dev/null | grep -E "(retention|cleanup)" || echo "Warning: Could not retrieve configuration"

echo ""
echo "Verifying eol-test-alerts retention settings (expected: 2592000000 ms = 30 days):"
echo "---"
kubectl exec "$KAFKA_BROKER_POD" -n "${NAMESPACE}" -c kafka -- \
    bin/kafka-configs.sh --bootstrap-server localhost:9092 \
    --entity-type topics --entity-name eol-test-alerts --describe 2>/dev/null | grep -E "(retention|cleanup)" || echo "Warning: Could not retrieve configuration"

echo ""
echo "✓ Level 2 (Broker) Verification Complete"
echo ""

echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "✓ All Verification Complete!"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"

