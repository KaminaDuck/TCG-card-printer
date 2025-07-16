#!/bin/bash

# TCG Card Printer - Docker Build Script
# This script simplifies building the Docker image with security scanning

set -e  # Exit on any error

# Script configuration
IMAGE_NAME="tcg-card-printer"
IMAGE_TAG="latest"
DOCKERFILE="Dockerfile"
BUILD_CONTEXT=".."
SECURITY_SCAN="false"
SCAN_TOOL="auto"  # auto, docker-scout, trivy, snyk

# Color codes for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
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

print_info() {
    echo -e "${BLUE}[INFO]${NC} $1"
}

# Function to show usage
show_usage() {
    echo "Usage: $0 [OPTIONS]"
    echo ""
    echo "Options:"
    echo "  --platform PLATFORM    Target platform (e.g., linux/amd64, linux/arm64)"
    echo "  --tag TAG             Image tag (default: latest)"
    echo "  --no-cache            Build without using cache"
    echo "  --scan                Enable security scanning after build"
    echo "  --scan-tool TOOL      Security scan tool (auto, docker-scout, trivy, snyk)"
    echo "  --multi-arch          Build for multiple architectures"
    echo "  --push                Push to registry after build"
    echo "  --registry REGISTRY   Registry to push to"
    echo "  -h, --help            Show this help message"
    echo ""
    echo "Examples:"
    echo "  # Build with security scanning"
    echo "  $0 --scan"
    echo ""
    echo "  # Build for multiple architectures"
    echo "  $0 --multi-arch --push --registry docker.io/myuser"
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
        --scan)
            SECURITY_SCAN="true"
            shift
            ;;
        --scan-tool)
            SCAN_TOOL="$2"
            shift 2
            ;;
        --multi-arch)
            MULTI_ARCH="true"
            shift
            ;;
        --push)
            PUSH="true"
            shift
            ;;
        --registry)
            REGISTRY="$2"
            shift 2
            ;;
        -h|--help)
            show_usage
            exit 0
            ;;
        *)
            print_error "Unknown option: $1"
            show_usage
            exit 1
            ;;
    esac
done

# Change to script directory
cd "$(dirname "$0")"

print_status "Starting Docker build for TCG Card Printer..."

# Build metadata
BUILD_DATE=$(date -u +"%Y-%m-%dT%H:%M:%SZ")
VCS_REF=$(git rev-parse --short HEAD 2>/dev/null || echo "unknown")

# Build command
BUILD_CMD="docker build"

# Add build arguments
BUILD_CMD="$BUILD_CMD --build-arg BUILD_DATE=$BUILD_DATE"
BUILD_CMD="$BUILD_CMD --build-arg VCS_REF=$VCS_REF"

# Add platform if specified
if [ ! -z "$PLATFORM" ]; then
    BUILD_CMD="$BUILD_CMD --platform $PLATFORM"
    print_status "Building for platform: $PLATFORM"
fi

# Multi-architecture build
if [ "$MULTI_ARCH" = "true" ]; then
    print_status "Setting up multi-architecture build..."
    
    # Check if buildx is available
    if ! docker buildx version >/dev/null 2>&1; then
        print_error "Docker buildx is required for multi-architecture builds"
        exit 1
    fi
    
    # Create or use existing builder
    BUILDER_NAME="tcg-multiarch-builder"
    if ! docker buildx inspect $BUILDER_NAME >/dev/null 2>&1; then
        print_status "Creating buildx builder: $BUILDER_NAME"
        docker buildx create --name $BUILDER_NAME --use
    else
        docker buildx use $BUILDER_NAME
    fi
    
    BUILD_CMD="docker buildx build --platform linux/amd64,linux/arm64"
    
    if [ "$PUSH" = "true" ]; then
        BUILD_CMD="$BUILD_CMD --push"
    else
        BUILD_CMD="$BUILD_CMD --load"
    fi
fi

# Add no-cache if specified
if [ ! -z "$NO_CACHE" ]; then
    BUILD_CMD="$BUILD_CMD $NO_CACHE"
    print_status "Building without cache"
fi

# Add registry prefix if specified
if [ ! -z "$REGISTRY" ]; then
    FULL_IMAGE_NAME="${REGISTRY}/${IMAGE_NAME}"
else
    FULL_IMAGE_NAME="${IMAGE_NAME}"
fi

# Add labels
BUILD_CMD="$BUILD_CMD --label org.opencontainers.image.created=$BUILD_DATE"
BUILD_CMD="$BUILD_CMD --label org.opencontainers.image.revision=$VCS_REF"
BUILD_CMD="$BUILD_CMD --label org.opencontainers.image.title='TCG Card Printer'"
BUILD_CMD="$BUILD_CMD --label org.opencontainers.image.description='Automated TCG card printing system'"
BUILD_CMD="$BUILD_CMD --label security.scan.enabled=$SECURITY_SCAN"

# Execute build
print_status "Building image: ${FULL_IMAGE_NAME}:${IMAGE_TAG}"
$BUILD_CMD -t "${FULL_IMAGE_NAME}:${IMAGE_TAG}" -f "../${DOCKERFILE}" "$BUILD_CONTEXT"

# Check if build was successful
if [ $? -eq 0 ]; then
    print_status "Build completed successfully!"
    
    # Get image details
    if [ "$MULTI_ARCH" != "true" ] || [ "$PUSH" != "true" ]; then
        IMAGE_SIZE=$(docker images "${FULL_IMAGE_NAME}:${IMAGE_TAG}" --format "table {{.Size}}" | tail -n 1)
        IMAGE_ID=$(docker images "${FULL_IMAGE_NAME}:${IMAGE_TAG}" --format "{{.ID}}" | head -n 1)
        
        print_info "Image size: $IMAGE_SIZE"
        print_info "Image ID: $IMAGE_ID"
    fi
    
    # Run security scan if enabled
    if [ "$SECURITY_SCAN" = "true" ]; then
        print_status "Running security scan..."
        
        # Call security scan script
        if [ -f "./security-scan.sh" ]; then
            ./security-scan.sh --image "${FULL_IMAGE_NAME}:${IMAGE_TAG}" --tool "$SCAN_TOOL"
        else
            print_warning "Security scan script not found. Trying inline scan..."
            
            # Try Docker Scout if available
            if command -v docker-scout >/dev/null 2>&1; then
                print_info "Using Docker Scout for security scanning..."
                docker scout cves "${FULL_IMAGE_NAME}:${IMAGE_TAG}" || true
            # Try Trivy if available
            elif command -v trivy >/dev/null 2>&1; then
                print_info "Using Trivy for security scanning..."
                trivy image "${FULL_IMAGE_NAME}:${IMAGE_TAG}" || true
            else
                print_warning "No security scanning tool found. Install Docker Scout or Trivy for vulnerability scanning."
            fi
        fi
    fi
    
    # Clean up dangling images
    DANGLING=$(docker images -f "dangling=true" -q)
    if [ ! -z "$DANGLING" ]; then
        print_status "Cleaning up dangling images..."
        docker rmi $DANGLING 2>/dev/null || true
    fi
    
    # Build summary
    echo ""
    print_status "Build Summary:"
    echo "  - Image: ${FULL_IMAGE_NAME}:${IMAGE_TAG}"
    [ ! -z "$IMAGE_SIZE" ] && echo "  - Size: $IMAGE_SIZE"
    [ ! -z "$IMAGE_ID" ] && echo "  - ID: $IMAGE_ID"
    echo "  - Created: $(date)"
    echo "  - Git Ref: $VCS_REF"
    [ "$SECURITY_SCAN" = "true" ] && echo "  - Security Scan: Completed"
    [ "$MULTI_ARCH" = "true" ] && echo "  - Architectures: linux/amd64, linux/arm64"
    [ "$PUSH" = "true" ] && echo "  - Pushed to: ${REGISTRY}"
    echo ""
    
    if [ "$PUSH" != "true" ]; then
        print_status "To run the container, use: ./run.sh"
    else
        print_status "Image pushed to ${REGISTRY}"
    fi
else
    print_error "Build failed!"
    exit 1
fi