#!/bin/bash

set -e

echo "Creating Kafka topics..."

# Function to create topic with retry
create_topic() {
    local topic_name=$1
    local partitions=$2
    local replication_factor=$3
    local max_attempts=5
    local attempt=1
    
    while [ $attempt -le $max_attempts ]; do
        if kafka-topics.sh --create --if-not-exists \
            --topic $topic_name \
            --bootstrap-server localhost:9092 \
            --replication-factor $replication_factor \
            --partitions $partitions; then
            echo "✅ Topic '$topic_name' created successfully"
            return 0
        else
            echo "❌ Attempt $attempt/$max_attempts: Failed to create topic '$topic_name'"
            attempt=$((attempt + 1))
            sleep 2
        fi
    done
    
    echo "⚠️  Warning: Failed to create topic '$topic_name' after $max_attempts attempts"
    return 1
}

# Create transactions topic
echo "Creating 'transactions' topic..."
create_topic "transactions" 4 1

# Create fraud-alerts topic  
echo "Creating 'fraud-alerts' topic..."
create_topic "fraud-alerts" 1 1

# Optional: Create additional topics for monitoring
echo "Creating 'monitoring' topic..."
create_topic "monitoring" 1 1

echo ""
echo "📋 Topic creation completed!"
echo "Available topics:"
kafka-topics.sh --bootstrap-server localhost:9092 --list || {
    echo "Failed to list topics, but continuing..."
}

echo ""
echo "📊 Topic details:"
for topic in "transactions" "fraud-alerts" "monitoring"; do
    echo "Topic: $topic"
    kafka-topics.sh --bootstrap-server localhost:9092 --describe --topic $topic || {
        echo "  Topic $topic not found or error describing it"
    }
    echo ""
done