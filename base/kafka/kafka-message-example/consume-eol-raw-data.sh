#!/usr/bin/env bash
# Consume messages from eol-raw-data topic in k3s Kafka (for checking/debugging).
# Usage:
#   ./consume-eol-raw-data.sh           # consume from latest (new messages only)
#   ./consume-eol-raw-data.sh --from-beginning   # consume all messages from start

set -euo pipefail

NAMESPACE="${KAFKA_NAMESPACE:-machine-monitoring}"
TOPIC="${KAFKA_TOPIC:-eol-raw-data}"

# Find first Kafka broker pod (Strimzi KRaft: kafka-kafka-broker-0; exclude entity-operator)
KAFKA_POD=$(kubectl get pods -n "$NAMESPACE" -l strimzi.io/cluster=kafka,strimzi.io/controller-name=kafka-kafka-broker -o jsonpath='{.items[0].metadata.name}' 2>/dev/null || true)
if [[ -z "$KAFKA_POD" ]]; then
  # Fallback: any pod whose name looks like a Strimzi broker (e.g. kafka-kafka-broker-0)
  KAFKA_POD=$(kubectl get pods -n "$NAMESPACE" -l strimzi.io/cluster=kafka -o jsonpath='{.items[*].metadata.name}' 2>/dev/null | tr ' ' '\n' | grep -E '^kafka-.*-broker-[0-9]+$' | head -1)
fi
if [[ -z "$KAFKA_POD" ]]; then
  echo "Error: No Kafka broker pod found in namespace $NAMESPACE. Is the Kafka cluster running?" >&2
  exit 1
fi

FROM_BEGINNING=""
if [[ "${1:-}" == "--from-beginning" ]]; then
  FROM_BEGINNING="--from-beginning"
fi

echo "Consuming from topic $TOPIC (pod $KAFKA_POD). Ctrl+C to stop."
kubectl exec -it -n "$NAMESPACE" "$KAFKA_POD" -c kafka -- \
  bin/kafka-console-consumer.sh \
  --bootstrap-server localhost:9092 \
  --topic "$TOPIC" \
  $FROM_BEGINNING
