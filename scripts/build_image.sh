#!/bin/bash

# Parsing absolute filepath of this script
abs_filepath=$(readlink -f "$0")
abs_dirpath=$(dirname "$abs_filepath")
build_dirpath=$(dirname "$abs_dirpath")

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

print_status() {
    echo -e "${GREEN}✅ $1${NC}"
}

print_info() {
    echo -e "${BLUE}ℹ️  $1${NC}"
}

print_warning() {
    echo -e "${YELLOW}⚠️  $1${NC}"
}

print_error() {
    echo -e "${RED}❌ $1${NC}"
}

#################
# Build Images
#################
build_images() {
    print_info "Building Kafka custom image..."
    DOCKER_BUILDKIT=1 docker build -t kafka_custom:latest \
        -f "$build_dirpath/Dockerfile" \
        --target kafka_custom \
        "$build_dirpath"
    
    print_info "Building Flink custom image..."
    DOCKER_BUILDKIT=1 docker build -t flink_custom:latest \
        -f "$build_dirpath/Dockerfile" \
        --target flink_custom \
        "$build_dirpath"
    
    print_info "Building PyFlink Job Image..."
    DOCKER_BUILDKIT=1 docker build -t pyjob-flink:latest \
        -f "$build_dirpath/Dockerfile" \
        --target pyjob-flink \
        "$build_dirpath"
    
    print_info "Building Monitoring Dashboard custom image..."
    DOCKER_BUILDKIT=1 docker build -t monitoring_custom:latest \
        -f "$build_dirpath/Dockerfile" \
        --target monitoring_custom \
        "$build_dirpath"
    
    print_status "All images built successfully!"
}

##################
# Clean None Images
##################
clean_images() {
    print_info "Cleaning up dangling images..."
    
    # Remove dangling images
    dangling_images=$(docker images -f "dangling=true" -q)
    if [ ! -z "$dangling_images" ]; then
        docker rmi $dangling_images
        print_status "Dangling images cleaned up"
    else
        print_info "No dangling images to clean"
    fi
}

##################
# List Built Images
##################
list_images() {
    print_info "Built custom images:"
    echo "===================="
    docker images | grep "_custom"
}

##################
# Verify Images
##################
verify_images() {
    print_info "Verifying built images..."
    
    images=("kafka_custom:latest" "flink_custom:latest" "pyjob-flink:latest" "monitoring_custom:latest")
    
    for image in "${images[@]}"; do
        if docker image inspect $image > /dev/null 2>&1; then
            print_status "$image - OK"
        else
            print_error "$image - MISSING"
        fi
    done
}

##################
# Help Function
##################
show_help() {
    echo "Usage: $0 [OPTIONS]"
    echo ""
    echo "Options:"
    echo "  build     - Build all custom images (default)"
    echo "  clean     - Clean dangling images"
    echo "  list      - List built custom images"
    echo "  verify    - Verify all images are built"
    echo "  help      - Show this help message"
    echo ""
}

##################
# Main Function
##################
main() {
    case "${1:-build}" in
        build)
            build_images
            clean_images
            verify_images
            list_images
            ;;
        clean)
            clean_images
            ;;
        list)
            list_images
            ;;
        verify)
            verify_images
            ;;
        help)
            show_help
            ;;
        *)
            print_error "Unknown option: $1"
            show_help
            exit 1
            ;;
    esac
}

main "$@"