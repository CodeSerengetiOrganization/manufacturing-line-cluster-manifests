# eol-raw-data topic – send, offsets, consume

Namespace: `machine-monitoring`. Broker pod: `kafka-kafka-broker-0`. Topic: `eol-raw-data`.

Run from repo root or from `base/kafka/kafka-message-example/` (adjust paths if needed).

---

## 1. Send message (producer)

Single line JSON (one message):

```bash
cat base/kafka/kafka-message-example/eol-raw-data-example-simple.json | kubectl exec -i -n machine-monitoring kafka-kafka-broker-0 -c kafka -- \
  bin/kafka-console-producer.sh --bootstrap-server localhost:9092 --topic eol-raw-data
```

From `base/kafka/kafka-message-example/`:

```bash
cat eol-raw-data-example-simple.json | kubectl exec -i -n machine-monitoring kafka-kafka-broker-0 -c kafka -- \
  bin/kafka-console-producer.sh --bootstrap-server localhost:9092 --topic eol-raw-data
```

Send and ensure last line is flushed (trailing newline):

```bash
(cat base/kafka/kafka-message-example/eol-raw-data-example-simple.json; echo) | kubectl exec -i -n machine-monitoring kafka-kafka-broker-0 -c kafka -- \
  bin/kafka-console-producer.sh --bootstrap-server localhost:9092 --topic eol-raw-data
```

---

## 2. Show offsets (per partition)

List latest offset per partition:

```bash
kubectl exec -n machine-monitoring kafka-kafka-broker-0 -c kafka -- \
  bin/kafka-run-class.sh kafka.tools.GetOffsetShell \
  --bootstrap-server localhost:9092 --topic eol-raw-data
```

Alternative (list topic/partitions and current state):

```bash
kubectl exec -n machine-monitoring kafka-kafka-broker-0 -c kafka -- \
  bin/kafka-topics.sh --bootstrap-server localhost:9092 --describe --topic eol-raw-data
```

---

## 3. Consume messages (consumer)

Read all messages from the start (then Ctrl+C to stop):

```bash
kubectl exec -it -n machine-monitoring kafka-kafka-broker-0 -c kafka -- \
  bin/kafka-console-consumer.sh --bootstrap-server localhost:9092 --topic eol-raw-data --from-beginning
```

Read only new messages (default, no `--from-beginning`):

```bash
kubectl exec -it -n machine-monitoring kafka-kafka-broker-0 -c kafka -- \
  bin/kafka-console-consumer.sh --bootstrap-server localhost:9092 --topic eol-raw-data
```

Read from start, exit after 10 seconds (no -it):

```bash
kubectl exec -n machine-monitoring kafka-kafka-broker-0 -c kafka -- \
  bin/kafka-console-consumer.sh --bootstrap-server localhost:9092 --topic eol-raw-data --from-beginning --timeout-ms 10000
```
