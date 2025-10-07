from kafka import KafkaConsumer
import json

consumer = KafkaConsumer(
    "test-topic",
    bootstrap_servers="kafka:9092",
    auto_offset_reset="earliest",
    enable_auto_commit=True,
    group_id="python-test",
    value_deserializer=lambda v: json.loads(v.decode("utf-8"))
)

print("Listening for messages...")
for msg in consumer:
    print("Received:", msg.value)
