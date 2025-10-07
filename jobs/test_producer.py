from kafka import KafkaProducer
import json
import time

producer = KafkaProducer(
    bootstrap_servers="kafka:9092",
    value_serializer=lambda v: json.dumps(v).encode("utf-8")
)

for i in range(5, 11):
    event = {
        "id": f"test-{i}",
        "ts": int(time.time() * 1000)  # timestamp millis
    }
    producer.send("test-topic", event)
    print("Sent:", event)

producer.flush()
producer.close()
