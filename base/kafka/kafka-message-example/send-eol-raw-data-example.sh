#!/usr/bin/env bash
# Send example manufacturing-result JSON message(s) to topic eol-raw-data in k3s Kafka.
# Usage:
#   ./send-eol-raw-data-example.sh                    # send one simple + one complex example
#   ./send-eol-raw-data-example.sh path/to/file.json  # send messages from file (one JSON object per line)

set -euo pipefail

NAMESPACE="${KAFKA_NAMESPACE:-machine-monitoring}"
TOPIC="${KAFKA_TOPIC:-eol-raw-data}"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

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

send_messages() {
  kubectl exec -i -n "$NAMESPACE" "$KAFKA_POD" -c kafka -- \
    bin/kafka-console-producer.sh \
    --bootstrap-server localhost:9092 \
    --topic "$TOPIC"
}

if [[ -n "${1:-}" ]]; then
  if [[ ! -f "$1" ]]; then
    echo "Error: File not found: $1" >&2
    exit 1
  fi
  echo "Sending messages from $1 to topic $TOPIC (pod $KAFKA_POD)..."
  # Trailing newline ensures kafka-console-producer (one message per line) sends the last line
  (cat "$1"; echo) | send_messages
else
  echo "Sending example messages (simple + complex) to topic $TOPIC (pod $KAFKA_POD)..."
  (cat "$SCRIPT_DIR/eol-raw-data-example-simple.json" "$SCRIPT_DIR/eol-raw-data-example-complex.json"; echo) | send_messages
fi
echo "Done."
