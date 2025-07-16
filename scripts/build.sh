#!/bin/bash

# TCG Card Printer - Docker Build Script
# This script simplifies building the Docker image

set -e  # Exit on any error

# Script configuration
IMAGE_NAME="tcg-card-printer"
IMAGE_TAG="latest"
DOCKERFILE="Dockerfile"
BUILD_CONTEXT=".."

# Color codes for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Function to print colored output
print_status() {
    echo -e "${GREEN}[BUILD]${NC} $1"
}

print_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

print_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

# Parse command line arguments
while [[ $# -gt 0 ]]; do
    case $1 in
        --platform)
            PLATFORM="$2"
            shift 2
            ;;
        --tag)
            IMAGE_TAG="$2"
            shift 2
            ;;
        --no-cache)
            NO_CACHE="--no-cache"
            shift
            ;;
        -h|--help)
            echo "Usage: $0 [OPTIONS]"
            echo ""
            echo "Options:"
            echo "  --platform PLATFORM   Target platform (e.g., linux/amd64, linux/arm64)"
            echo "  --tag TAG            Image tag (default: latest)"
            echo "  --no-cache           Build without using cache"
            echo "  -h, --help           Show this help message"
            exit 0
            ;;
        *)
            print_error "Unknown option: $1"
            exit 1
            ;;
    esac
done

# Change to script directory
cd "$(dirname "$0")"

print_status "Starting Docker build for TCG Card Printer..."

# Build command
BUILD_CMD="docker build"

# Add platform if specified
if [ ! -z "$PLATFORM" ]; then
    BUILD_CMD="$BUILD_CMD --platform $PLATFORM"
    print_status "Building for platform: $PLATFORM"
fi

# Add no-cache if specified
if [ ! -z "$NO_CACHE" ]; then
    BUILD_CMD="$BUILD_CMD $NO_CACHE"
    print_status "Building without cache"
fi

# Execute build
print_status "Building image: ${IMAGE_NAME}:${IMAGE_TAG}"
$BUILD_CMD -t "${IMAGE_NAME}:${IMAGE_TAG}" -f "../${DOCKERFILE}" "$BUILD_CONTEXT"

# Check if build was successful
if [ $? -eq 0 ]; then
    print_status "Build completed successfully!"
    
    # Get image size
    IMAGE_SIZE=$(docker images "${IMAGE_NAME}:${IMAGE_TAG}" --format "table {{.Size}}" | tail -n 1)
    print_status "Image size: $IMAGE_SIZE"
    
    # Clean up dangling images
    DANGLING=$(docker images -f "dangling=true" -q)
    if [ ! -z "$DANGLING" ]; then
        print_status "Cleaning up dangling images..."
        docker rmi $DANGLING 2>/dev/null || true
    fi
    
    echo ""
    print_status "Build Summary:"
    echo "  - Image: ${IMAGE_NAME}:${IMAGE_TAG}"
    echo "  - Size: $IMAGE_SIZE"
    echo "  - Created: $(date)"
    echo ""
    print_status "To run the container, use: ./run.sh"
else
    print_error "Build failed!"
    exit 1
fi