#!/bin/bash

set -e

echo "🚀 Initializing Docker Swarm cluster for Flink demo..."

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Function to print colored output
print_status() {
    echo -e "${GREEN}✅ $1${NC}"
}

print_warning() {
    echo -e "${YELLOW}⚠️  $1${NC}"
}

print_error() {
    echo -e "${RED}❌ $1${NC}"
}

# Check if Docker is installed
if ! command -v docker &> /dev/null; then
    print_error "Docker is not installed. Please install Docker first."
    exit 1
fi

# Check if Docker Compose is installed
if ! command -v docker compose &> /dev/null; then
    print_error "Docker Compose is not installed. Please install Docker Compose first."
    exit 1
fi

# Check if Maven is installed for Flink job compilation
if ! command -v mvn &> /dev/null; then
    print_warning "Maven is not installed. Will try to use Docker Maven container."
fi

# Get the current host IP
HOST_IP=$(hostname -I | awk '{print $1}')
if [ -z "$HOST_IP" ]; then
    HOST_IP=$(ip route get 8.8.8.8 | awk '{print $7}' | head -1)
fi

print_status "Detected host IP: $HOST_IP"

# Initialize Docker Swarm
if ! docker info | grep -q "Swarm: active"; then
    print_status "Initializing Docker Swarm..."
    docker swarm init --advertise-addr $HOST_IP
    print_status "Docker Swarm initialized successfully!"
else
    print_status "Docker Swarm is already initialized"
fi

# Create necessary directories
print_status "Creating project directories..."
mkdir -p data/checkpoint
mkdir -p data/delta-lake
mkdir -p data/minio

# Set permissions
chmod 755 data/checkpoint
chmod 755 data/delta-lake  
chmod 755 data/minio

print_status "Directories created successfully!"

# Create Docker networks
print_status "Creating Docker overlay network..."
docker network create --driver overlay --attachable flink-network 2>/dev/null || print_warning "Network may already exist"

# Show join token for worker nodes
echo ""
echo "📝 To join additional nodes to this swarm, run the following command on each worker node:"
echo "=================================================================================="
docker swarm join-token worker | grep "docker swarm join"
echo "=================================================================================="
echo ""

print_status "Docker Swarm cluster initialization completed!"
print_status "Manager node IP: $HOST_IP"
print_status "Ready to deploy the Flink fraud detection demo!"

echo ""
echo "Next steps:"
echo "1. Run 'make build' to build all components"
echo "2. Run 'make start' to start the demo"
echo "3. Access the dashboard at http://$HOST_IP:8080"