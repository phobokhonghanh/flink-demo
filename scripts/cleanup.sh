#!/bin/bash

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

print_status() {
    echo -e "${GREEN}✅ $1${NC}"
}

print_warning() {
    echo -e "${YELLOW}⚠️  $1${NC}"
}

print_error() {
    echo -e "${RED}❌ $1${NC}"
}

echo "🧹 Cleaning up Flink demo environment..."
echo "======================================="

# Stop the demo first
if [ -f "./scripts/stop-demo.sh" ]; then
    ./scripts/stop-demo.sh
else
    print_warning "stop-demo.sh not found, continuing with cleanup..."
fi

# Remove Docker volumes
echo "Removing Docker volumes..."
docker volume ls -q --filter name=flink-demo | xargs -r docker volume rm
docker volume prune -f

# Remove Docker networks
echo "Removing Docker networks..."
docker network rm flink-network 2>/dev/null || print_warning "Network flink-network not found"
docker network prune -f

# Remove data directories (with confirmation)
if [ -d "data" ]; then
    echo ""
    read -p "Do you want to remove all data directories? (y/N): " -n 1 -r
    echo
    if [[ $REPLY =~ ^[Yy]$ ]]; then
        rm -rf data/
        print_status "Data directories removed"
    else
        print_warning "Data directories preserved"
    fi
fi

# Remove built artifacts
if [ -d "src/flink-job/target" ]; then
    echo "Removing build artifacts..."
    rm -rf src/flink-job/target
    print_status "Build artifacts removed"
fi

# Docker system cleanup
echo "Performing Docker system cleanup..."
docker system prune -f

# Ask about leaving Docker Swarm
echo ""
read -p "Do you want to leave Docker Swarm? (y/N): " -n 1 -r
echo
if [[ $REPLY =~ ^[Yy]$ ]]; then
    if docker info | grep -q "Swarm: active"; then
        docker swarm leave --force
        print_status "Left Docker Swarm"
    else
        print_warning "Not currently in a Docker Swarm"
    fi
else
    print_status "Docker Swarm preserved"
fi

# Final cleanup
echo "Final cleanup..."
docker image prune -f

print_status "🎉 Cleanup completed!"

echo ""
echo "Summary:"
echo "========="
echo "✅ Docker containers removed"
echo "✅ Docker volumes removed"  
echo "✅ Docker networks removed"
echo "✅ Build artifacts removed"
echo "✅ System pruned"

if [ -d "data" ]; then
    echo "⚠️  Data directories preserved"
else
    echo "✅ Data directories removed"
fi

echo ""
echo "💡 To start fresh: make init && make start"