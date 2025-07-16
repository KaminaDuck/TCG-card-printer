#!/bin/bash

# TCG Card Printer - Docker Run Script
# This script simplifies running the container with proper volume mounts

set -e  # Exit on any error

# Script configuration
IMAGE_NAME="tcg-card-printer"
IMAGE_TAG="latest"
CONTAINER_NAME="tcg-printer"

# Default paths (relative to project root)
DEFAULT_INPUT_DIR="../tcg_cards_input"
DEFAULT_PROCESSED_DIR="../processed"
DEFAULT_LOGS_DIR="../logs"

# Get script directory
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
PROJECT_ROOT="$(dirname "$SCRIPT_DIR")"

# Color codes for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Function to print colored output
print_status() {
    echo -e "${GREEN}[RUN]${NC} $1"
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

# Default values
INPUT_DIR="$PROJECT_ROOT/tcg_cards_input"
PROCESSED_DIR="$PROJECT_ROOT/processed"
LOGS_DIR="$PROJECT_ROOT/logs"
PRINTER_NAME="Canon_G3070_series"
AUTO_DELETE="false"
DETACHED="-d"

# Function to show usage
show_usage() {
    echo "Usage: $0 [OPTIONS]"
    echo ""
    echo "Options:"
    echo "  -i, --input DIR      Input directory (default: ./tcg_cards_input)"
    echo "  -p, --processed DIR  Processed directory (default: ./processed)"
    echo "  -l, --logs DIR       Logs directory (default: ./logs)"
    echo "  --printer NAME       Printer name (default: Canon_G3070_series)"
    echo "  --auto-delete        Enable auto-delete after print"
    echo "  --interactive        Run in interactive mode (not detached)"
    echo "  --rm                 Remove container after exit"
    echo "  -h, --help          Show this help message"
    echo ""
    echo "Examples:"
    echo "  # Run with default settings"
    echo "  $0"
    echo ""
    echo "  # Run with custom input directory"
    echo "  $0 -i /path/to/cards"
    echo ""
    echo "  # Run interactively for debugging"
    echo "  $0 --interactive"
}

# Parse command line arguments
while [[ $# -gt 0 ]]; do
    case $1 in
        -i|--input)
            INPUT_DIR="$2"
            shift 2
            ;;
        -p|--processed)
            PROCESSED_DIR="$2"
            shift 2
            ;;
        -l|--logs)
            LOGS_DIR="$2"
            shift 2
            ;;
        --printer)
            PRINTER_NAME="$2"
            shift 2
            ;;
        --auto-delete)
            AUTO_DELETE="true"
            shift
            ;;
        --interactive)
            DETACHED=""
            shift
            ;;
        --rm)
            REMOVE="--rm"
            shift
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

# Function to check if directory exists and create if needed
check_directory() {
    local dir="$1"
    local name="$2"
    
    if [ ! -d "$dir" ]; then
        print_warning "$name directory not found: $dir"
        read -p "Create it? (y/n): " -n 1 -r
        echo
        if [[ $REPLY =~ ^[Yy]$ ]]; then
            mkdir -p "$dir"
            print_status "Created $name directory: $dir"
        else
            print_error "Cannot proceed without $name directory"
            exit 1
        fi
    else
        print_info "$name directory: $dir"
    fi
}

# Check for required directories
print_status "Checking directories..."
check_directory "$INPUT_DIR" "Input"
check_directory "$PROCESSED_DIR" "Processed"
check_directory "$LOGS_DIR" "Logs"

# Check if CUPS socket exists
if [ ! -S "/var/run/cups/cups.sock" ]; then
    print_error "CUPS socket not found at /var/run/cups/cups.sock"
    print_info "Please ensure CUPS is installed and running"
    exit 1
fi

# Check if image exists
if ! docker images | grep -q "^${IMAGE_NAME}.*${IMAGE_TAG}"; then
    print_error "Docker image '${IMAGE_NAME}:${IMAGE_TAG}' not found"
    print_info "Please run ./build.sh first to build the image"
    exit 1
fi

# Stop existing container if running
if docker ps -a | grep -q "$CONTAINER_NAME"; then
    print_warning "Container '$CONTAINER_NAME' already exists"
    print_status "Stopping and removing existing container..."
    docker stop "$CONTAINER_NAME" 2>/dev/null || true
    docker rm "$CONTAINER_NAME" 2>/dev/null || true
fi

# Build docker run command
RUN_CMD="docker run $DETACHED $REMOVE \
    --name $CONTAINER_NAME \
    -v \"$INPUT_DIR:/app/tcg_cards_input\" \
    -v \"$PROCESSED_DIR:/app/processed\" \
    -v \"$LOGS_DIR:/app/logs\" \
    -v /var/run/cups/cups.sock:/var/run/cups/cups.sock \
    -e TCG_PRINTER_NAME=\"$PRINTER_NAME\" \
    -e TCG_AUTO_DELETE=\"$AUTO_DELETE\" \
    -e PYTHONUNBUFFERED=1 \
    ${IMAGE_NAME}:${IMAGE_TAG}"

# Run container
print_status "Starting TCG Card Printer container..."
print_info "Printer: $PRINTER_NAME"
print_info "Auto-delete: $AUTO_DELETE"

# Execute run command
eval $RUN_CMD

# Check if container started successfully
if [ $? -eq 0 ]; then
    if [ ! -z "$DETACHED" ]; then
        print_status "Container started successfully!"
        echo ""
        print_info "Container name: $CONTAINER_NAME"
        print_info "To view logs: docker logs -f $CONTAINER_NAME"
        print_info "To stop: docker stop $CONTAINER_NAME"
        print_info "To remove: docker rm $CONTAINER_NAME"
        echo ""
        print_status "Drop card images in: $INPUT_DIR"
    else
        print_status "Container exited"
    fi
else
    print_error "Failed to start container!"
    exit 1
fi

# Trap for cleanup on script exit (only in interactive mode)
if [ -z "$DETACHED" ] && [ -z "$REMOVE" ]; then
    trap "docker stop $CONTAINER_NAME 2>/dev/null || true; docker rm $CONTAINER_NAME 2>/dev/null || true" EXIT
fi