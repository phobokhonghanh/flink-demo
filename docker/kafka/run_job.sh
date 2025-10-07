#!/bin/bash

echo "Submitting Kafka job to Flink cluster..."

# Submit job using flink run command với JAR
/opt/flink/bin/flink run \
    --target remote \
    --jobmanager bdac077008f2:8081 \
    --jarfile /opt/flink/lib/flink-sql-connector-kafka-1.17.1.jar \
    --python /opt/itc/jobs/test_streaming.py

echo "Job submitted!"
