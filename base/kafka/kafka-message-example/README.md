# Example messages for `manufacturing-results-topic`

Example JSON messages for the manufacturing-result event schema (PLC/edge pass-fail and EOL tester with test items).

## Files

| File | Description |
|------|-------------|
| `manufacturing-result-eol-simple.json` | One `manufacturing_simple` event (PLC/edge pass-fail). |
| `manufacturing-result-eol-complex.json` | One `manufacturing_complex` event (EOL tester with test items). |
| `send-eol-raw-data-example.sh` | Produce these examples (or a custom file) to `manufacturing-results-topic` in the k3s cluster. |
| `consume-eol-raw-data.sh` | Consume messages from `manufacturing-results-topic` for checking. |

## Sending to Kafka in k3s

Prerequisites: `kubectl` configured for your k3s cluster and the Kafka cluster running in namespace `machine-monitoring`.

**Send the two built-in examples (one simple + one complex):**
```bash
./send-eol-raw-data-example.sh
```

**Send messages from your own file (one JSON object per line):**
```bash
./send-eol-raw-data-example.sh /path/to/messages.jsonl
```

**Override namespace or topic:**
```bash
KAFKA_NAMESPACE=machine-monitoring KAFKA_TOPIC=manufacturing-results-topic ./send-eol-raw-data-example.sh
```

The script finds a Kafka broker pod in the namespace and runs `kafka-console-producer` inside it to produce to `manufacturing-results-topic`.

## Checking messages in Kafka

- **To see messages you already sent:** run the consumer with `--from-beginning`.
- **To see messages "live":** start the consumer first (no args), then run the producer in another terminal.

**Option 1: Use the script** (same thing, less typing):
```bash
./consume-eol-raw-data.sh                    # new messages only (start this first for "live")
./consume-eol-raw-data.sh --from-beginning   # all messages from start of topic
```

**Option 2: Run the consumer with kubectl** (no script):

```bash
# Use a broker pod (Strimzi KRaft: kafka-kafka-broker-0)
KAFKA_POD=$(kubectl get pods -n machine-monitoring -l strimzi.io/cluster=kafka,strimzi.io/controller-name=kafka-kafka-broker -o jsonpath='{.items[0].metadata.name}')

# Consume from beginning of topic (Ctrl+C to stop)
kubectl exec -it -n machine-monitoring $KAFKA_POD -c kafka -- \
  bin/kafka-console-consumer.sh \
  --bootstrap-server localhost:9092 \
  --topic manufacturing-results-topic \
  --from-beginning
```

Omit `--from-beginning` to read only new messages.

## Quick test (end-to-end)

1. **Send** example messages:
   ```bash
   ./send-eol-raw-data-example.sh
   ```
2. **Check** messages (use `--from-beginning` to see what you just sent):
   ```bash
   ./consume-eol-raw-data.sh --from-beginning
   ```
   Or with kubectl:
   ```bash
   KAFKA_POD=$(kubectl get pods -n machine-monitoring -l strimzi.io/cluster=kafka,strimzi.io/controller-name=kafka-kafka-broker -o jsonpath='{.items[0].metadata.name}')
   kubectl exec -it -n machine-monitoring $KAFKA_POD -c kafka -- \
     bin/kafka-console-consumer.sh --bootstrap-server localhost:9092 --topic manufacturing-results-topic --from-beginning
   ```
   You should see the two example JSON messages; press Ctrl+C to stop.
