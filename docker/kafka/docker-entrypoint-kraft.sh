#!/bin/bash

set -e

echo "Starting Kafka with KRaft mode..."

# Setup KRaft if needed
if [ ! -f "/bitnami/kafka/meta.properties" ]; then
    echo "First time setup - initializing KRaft..."
    /opt/bitnami/kafka/setup-kraft.sh
fi

# Start Kafka with original entrypoint in background
echo "Starting Kafka server..."
/opt/bitnami/scripts/kafka/entrypoint.sh /opt/bitnami/scripts/kafka/run.sh &
KAFKA_PID=$!

# Wait for Kafka to be ready
echo "Waiting for Kafka to be fully ready..."
max_attempts=30
attempt=1

while [ $attempt -le $max_attempts ]; do
    if kafka-topics.sh --bootstrap-server localhost:9092 --list > /dev/null 2>&1; then
        echo "Kafka is ready after $attempt attempts!"
        break
    fi
    echo "Attempt $attempt/$max_attempts: Kafka not ready yet..."
    sleep 3
    attempt=$((attempt + 1))
done

if [ $attempt -le $max_attempts ]; then
    # Create topics
    echo "Running topic creation script..."
    /opt/bitnami/kafka/create-topics.sh || {
        echo "Topic creation failed, but continuing..."
    }
else
    echo "Warning: Kafka may not be fully ready, but continuing..."
fi

# Wait for Kafka process
echo "Kafka startup completed. Waiting for main process..."
wait $KAFKA_PID