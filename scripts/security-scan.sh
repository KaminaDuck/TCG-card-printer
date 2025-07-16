#!/bin/bash

# TCG Card Printer - Security Scanning Script
# This script performs comprehensive security scanning of Docker images

set -e

# Script configuration
SCAN_TOOL="auto"  # auto, docker-scout, trivy, snyk, grype
OUTPUT_FORMAT="table"  # table, json, sarif
SEVERITY_FILTER="HIGH,CRITICAL"  # ALL, HIGH, CRITICAL, MEDIUM, LOW
SCAN_TYPE="full"  # quick, full, compliance
OUTPUT_FILE=""
IMAGE_NAME=""
EXIT_ON_FAILURE="false"

# Color codes for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
NC='\033[0m'

# Function to print colored output
print_status() {
    echo -e "${GREEN}[SCAN]${NC} $1"
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

print_section() {
    echo -e "${CYAN}[SECTION]${NC} $1"
}

# Function to show usage
show_usage() {
    echo "Usage: $0 [OPTIONS]"
    echo ""
    echo "Required Options:"
    echo "  --image IMAGE        Docker image to scan"
    echo ""
    echo "Scan Options:"
    echo "  --tool TOOL          Scanning tool (auto, docker-scout, trivy, snyk, grype)"
    echo "  --type TYPE          Scan type (quick, full, compliance)"
    echo "  --severity LEVELS    Severity filter (ALL, HIGH, CRITICAL, etc.)"
    echo "  --format FORMAT      Output format (table, json, sarif)"
    echo "  --output FILE        Save output to file"
    echo "  --exit-on-failure    Exit with error code if vulnerabilities found"
    echo ""
    echo "  -h, --help          Show this help message"
    echo ""
    echo "Examples:"
    echo "  # Quick scan with auto-detection"
    echo "  $0 --image tcg-card-printer:latest"
    echo ""
    echo "  # Full scan with Trivy, JSON output"
    echo "  $0 --image tcg-card-printer:latest --tool trivy --type full --format json"
    echo ""
    echo "  # Compliance scan with critical vulnerabilities only"
    echo "  $0 --image myimage:latest --type compliance --severity CRITICAL"
}

# Function to detect available scanning tools
detect_scan_tool() {
    if [ "$SCAN_TOOL" != "auto" ]; then
        return 0
    fi
    
    print_info "Auto-detecting security scanning tools..."
    
    # Check for Docker Scout
    if command -v docker >/dev/null 2>&1 && docker scout version >/dev/null 2>&1; then
        SCAN_TOOL="docker-scout"
        print_info "Found Docker Scout"
        return 0
    fi
    
    # Check for Trivy
    if command -v trivy >/dev/null 2>&1; then
        SCAN_TOOL="trivy"
        print_info "Found Trivy"
        return 0
    fi
    
    # Check for Grype
    if command -v grype >/dev/null 2>&1; then
        SCAN_TOOL="grype"
        print_info "Found Grype"
        return 0
    fi
    
    # Check for Snyk
    if command -v snyk >/dev/null 2>&1; then
        SCAN_TOOL="snyk"
        print_info "Found Snyk"
        return 0
    fi
    
    print_error "No supported security scanning tools found"
    print_info "Please install one of: Docker Scout, Trivy, Grype, or Snyk"
    exit 1
}

# Function to scan with Docker Scout
scan_with_docker_scout() {
    print_section "Scanning with Docker Scout"
    
    local cmd="docker scout cves"
    
    # Add severity filter
    if [ "$SEVERITY_FILTER" != "ALL" ]; then
        cmd="$cmd --only-severity $SEVERITY_FILTER"
    fi
    
    # Add output format
    case "$OUTPUT_FORMAT" in
        json)
            cmd="$cmd --format json"
            ;;
        sarif)
            cmd="$cmd --format sarif"
            ;;
        table)
            cmd="$cmd --format table"
            ;;
    esac
    
    # Add output file
    if [ ! -z "$OUTPUT_FILE" ]; then
        cmd="$cmd --output $OUTPUT_FILE"
    fi
    
    # Execute scan
    print_info "Command: $cmd $IMAGE_NAME"
    eval "$cmd $IMAGE_NAME"
    
    # Additional Docker Scout scans for full scan
    if [ "$SCAN_TYPE" = "full" ]; then
        print_info "Running additional Docker Scout checks..."
        
        # Scan for policy violations
        print_info "Checking policy compliance..."
        docker scout quickview "$IMAGE_NAME" || true
        
        # Recommendations
        print_info "Getting recommendations..."
        docker scout recommendations "$IMAGE_NAME" || true
    fi
}

# Function to scan with Trivy
scan_with_trivy() {
    print_section "Scanning with Trivy"
    
    local cmd="trivy image"
    
    # Add severity filter
    if [ "$SEVERITY_FILTER" != "ALL" ]; then
        cmd="$cmd --severity $SEVERITY_FILTER"
    fi
    
    # Add output format
    case "$OUTPUT_FORMAT" in
        json)
            cmd="$cmd --format json"
            ;;
        sarif)
            cmd="$cmd --format sarif"
            ;;
        table)
            cmd="$cmd --format table"
            ;;
    esac
    
    # Add output file
    if [ ! -z "$OUTPUT_FILE" ]; then
        cmd="$cmd --output $OUTPUT_FILE"
    fi
    
    # Scan type specific options
    case "$SCAN_TYPE" in
        quick)
            cmd="$cmd --scanners vuln"
            ;;
        full)
            cmd="$cmd --scanners vuln,config,secret"
            ;;
        compliance)
            cmd="$cmd --scanners vuln,config,secret --compliance docker-cis"
            ;;
    esac
    
    # Execute scan
    print_info "Command: $cmd $IMAGE_NAME"
    eval "$cmd $IMAGE_NAME"
}

# Function to scan with Grype
scan_with_grype() {
    print_section "Scanning with Grype"
    
    local cmd="grype"
    
    # Add output format
    case "$OUTPUT_FORMAT" in
        json)
            cmd="$cmd -o json"
            ;;
        sarif)
            cmd="$cmd -o sarif"
            ;;
        table)
            cmd="$cmd -o table"
            ;;
    esac
    
    # Add output file
    if [ ! -z "$OUTPUT_FILE" ]; then
        cmd="$cmd --file $OUTPUT_FILE"
    fi
    
    # Add severity filter (Grype uses different format)
    if [ "$SEVERITY_FILTER" != "ALL" ]; then
        cmd="$cmd --fail-on $SEVERITY_FILTER"
    fi
    
    # Execute scan
    print_info "Command: $cmd $IMAGE_NAME"
    eval "$cmd $IMAGE_NAME"
}

# Function to scan with Snyk
scan_with_snyk() {
    print_section "Scanning with Snyk"
    
    # Check if authenticated
    if ! snyk auth >/dev/null 2>&1; then
        print_warning "Snyk authentication required. Please run 'snyk auth' first."
        return 1
    fi
    
    local cmd="snyk container test"
    
    # Add severity filter
    if [ "$SEVERITY_FILTER" != "ALL" ]; then
        cmd="$cmd --severity-threshold=$(echo $SEVERITY_FILTER | tr ',' '|' | tr 'A-Z' 'a-z')"
    fi
    
    # Add output format
    case "$OUTPUT_FORMAT" in
        json)
            cmd="$cmd --json"
            ;;
        sarif)
            cmd="$cmd --sarif"
            ;;
    esac
    
    # Add output file
    if [ ! -z "$OUTPUT_FILE" ]; then
        cmd="$cmd --json-file-output=$OUTPUT_FILE"
    fi
    
    # Execute scan
    print_info "Command: $cmd $IMAGE_NAME"
    eval "$cmd $IMAGE_NAME"
}

# Function to generate scan summary
generate_summary() {
    print_section "Security Scan Summary"
    
    echo "Scan Details:"
    echo "  - Image: $IMAGE_NAME"
    echo "  - Tool: $SCAN_TOOL"
    echo "  - Type: $SCAN_TYPE"
    echo "  - Severity Filter: $SEVERITY_FILTER"
    echo "  - Format: $OUTPUT_FORMAT"
    echo "  - Timestamp: $(date -u +"%Y-%m-%dT%H:%M:%SZ")"
    [ ! -z "$OUTPUT_FILE" ] && echo "  - Output File: $OUTPUT_FILE"
    
    echo ""
    print_info "Scan completed successfully"
    
    if [ "$EXIT_ON_FAILURE" = "true" ]; then
        print_warning "Exit-on-failure mode enabled - check scan results carefully"
    fi
}

# Parse command line arguments
while [[ $# -gt 0 ]]; do
    case $1 in
        --image)
            IMAGE_NAME="$2"
            shift 2
            ;;
        --tool)
            SCAN_TOOL="$2"
            shift 2
            ;;
        --type)
            SCAN_TYPE="$2"
            shift 2
            ;;
        --severity)
            SEVERITY_FILTER="$2"
            shift 2
            ;;
        --format)
            OUTPUT_FORMAT="$2"
            shift 2
            ;;
        --output)
            OUTPUT_FILE="$2"
            shift 2
            ;;
        --exit-on-failure)
            EXIT_ON_FAILURE="true"
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

# Validate required parameters
if [ -z "$IMAGE_NAME" ]; then
    print_error "Image name is required"
    show_usage
    exit 1
fi

# Validate scan type
case "$SCAN_TYPE" in
    quick|full|compliance)
        ;;
    *)
        print_error "Invalid scan type: $SCAN_TYPE"
        exit 1
        ;;
esac

# Validate output format
case "$OUTPUT_FORMAT" in
    table|json|sarif)
        ;;
    *)
        print_error "Invalid output format: $OUTPUT_FORMAT"
        exit 1
        ;;
esac

# Main execution
print_status "Starting security scan for image: $IMAGE_NAME"

# Detect scanning tool if auto
detect_scan_tool

# Validate image exists
if ! docker images --format "{{.Repository}}:{{.Tag}}" | grep -q "^${IMAGE_NAME}$"; then
    print_error "Image not found: $IMAGE_NAME"
    print_info "Available images:"
    docker images --format "table {{.Repository}}\t{{.Tag}}\t{{.Size}}"
    exit 1
fi

# Create output directory if specified
if [ ! -z "$OUTPUT_FILE" ]; then
    OUTPUT_DIR=$(dirname "$OUTPUT_FILE")
    mkdir -p "$OUTPUT_DIR"
fi

# Execute scan based on detected/specified tool
case "$SCAN_TOOL" in
    docker-scout)
        scan_with_docker_scout
        ;;
    trivy)
        scan_with_trivy
        ;;
    grype)
        scan_with_grype
        ;;
    snyk)
        scan_with_snyk
        ;;
    *)
        print_error "Unsupported scan tool: $SCAN_TOOL"
        exit 1
        ;;
esac

# Check scan result
SCAN_EXIT_CODE=$?

# Generate summary
generate_summary

# Exit with appropriate code
if [ $SCAN_EXIT_CODE -ne 0 ] && [ "$EXIT_ON_FAILURE" = "true" ]; then
    print_error "Security vulnerabilities detected!"
    exit $SCAN_EXIT_CODE
else
    print_status "Security scan completed"
    exit 0
fi