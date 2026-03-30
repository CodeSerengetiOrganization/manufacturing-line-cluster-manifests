# manufacturing-results-topic – send, offsets, consume

Namespace: `machine-monitoring`. Broker pod: `kafka-kafka-broker-0`. Topic: `manufacturing-results-topic`.

Run from repo root or from `base/kafka/kafka-message-example/` (adjust paths if needed).

---
## 1. Consume messages (consumer)

It is a good idea to start the consumer first, so that you can see the message jump out when you use another terminal.

Read all messages from the start (then Ctrl+C to stop), print key + value:

```bash
kubectl exec -it -n machine-monitoring kafka-kafka-broker-0 -c kafka -- \
  bin/kafka-console-consumer.sh --bootstrap-server localhost:9092 --topic manufacturing-results-topic --from-beginning \
  --property print.key=true --property key.separator=' | '
```

Read only new messages (default, no `--from-beginning`), print key + value:

```bash
kubectl exec -it -n machine-monitoring kafka-kafka-broker-0 -c kafka -- \
  bin/kafka-console-consumer.sh --bootstrap-server localhost:9092 --topic manufacturing-results-topic \
  --property print.key=true --property key.separator=' | '
```

Read from start, print key + value, exit after 10 seconds (no -it):

```bash
kubectl exec -n machine-monitoring kafka-kafka-broker-0 -c kafka -- \
  bin/kafka-console-consumer.sh --bootstrap-server localhost:9092 --topic manufacturing-results-topic --from-beginning --timeout-ms 10000 \
  --property print.key=true --property key.separator=' | '
```

## 1. Send message (producer, key/value format)

Key = barcode, value = full JSON (same barcode -> same partition). Key and value are sent as `key<TAB>value`. Requires `jq` for method A.

Method A - from repo root (extract key/value from JSON file):

```bash
KEY=$(jq -r '.barcode' base/kafka/kafka-message-example/manufacturing-result-eol-simple.json)
VALUE=$(jq -c . base/kafka/kafka-message-example/manufacturing-result-eol-simple.json)
printf '%s\t%s\n' "$KEY" "$VALUE" | kubectl exec -i -n machine-monitoring kafka-kafka-broker-0 -c kafka -- \
  bin/kafka-console-producer.sh --bootstrap-server localhost:9092 --topic manufacturing-results-topic --property parse.key=true
```

Method B - from repo root (hardcoded one message, easy copy/paste):

```bash
kubectl exec -i -n machine-monitoring kafka-kafka-broker-0 -c kafka -- \
  bin/kafka-console-producer.sh --bootstrap-server localhost:9092 --topic manufacturing-results-topic --property parse.key=true <<'EOF'
SN-20250215-001	{"eventType":"manufacturing_simple","barcode":"SN-20250215-001","productCode":1001,"productSeq":42,"stationCode":201,"stationChannelNo":1,"result":1,"operator":"OP01","startTime":"2025-02-15T10:00:00Z","endTime":"2025-02-15T10:00:15Z"}
EOF
```

---

## 2. Show offsets (per partition)

List latest offset per partition:

```bash
kubectl exec -n machine-monitoring kafka-kafka-broker-0 -c kafka -- \
  bin/kafka-run-class.sh kafka.tools.GetOffsetShell \
  --bootstrap-server localhost:9092 --topic manufacturing-results-topic
```

Alternative (list topic/partitions and current state):

```bash
kubectl exec -n machine-monitoring kafka-kafka-broker-0 -c kafka -- \
  bin/kafka-topics.sh --bootstrap-server localhost:9092 --describe --topic manufacturing-results-topic
```

---


