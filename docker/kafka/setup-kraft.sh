#!/bin/bash

set -e

echo "Setting up Kafka KRaft mode..."

# Set KRaft cluster ID if not provided
if [ -z "$KAFKA_KRAFT_CLUSTER_ID" ]; then
    export KAFKA_KRAFT_CLUSTER_ID=$(kafka-storage.sh random-uuid)
    echo "Generated KRaft Cluster ID: $KAFKA_KRAFT_CLUSTER_ID"
fi

# Format storage directory for KRaft
echo "Formatting storage directory..."
kafka-storage.sh format \
    -t $KAFKA_KRAFT_CLUSTER_ID \
    -c /opt/bitnami/kafka/config/kraft/server.properties || {
    echo "Storage already formatted or format failed, continuing..."
}

echo "KRaft setup completed successfully!"