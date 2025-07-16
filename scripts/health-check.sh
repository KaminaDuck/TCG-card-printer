#!/bin/bash

# TCG Card Printer - Health Check Script
# This script performs comprehensive health checks for the containerized application

set -e

# Script configuration
HEALTH_CHECK_LEVEL="${1:-basic}"  # basic, detailed, diagnostic
OUTPUT_FORMAT="${2:-text}"        # text, json

# Color codes for output (only in text mode)
if [ "$OUTPUT_FORMAT" = "text" ] && [ -t 1 ]; then
    GREEN='\033[0;32m'
    YELLOW='\033[1;33m'
    RED='\033[0;31m'
    NC='\033[0m'
else
    GREEN=''
    YELLOW=''
    RED=''
    NC=''
fi

# Health check results
CHECKS_PASSED=0
CHECKS_FAILED=0
CHECKS_WARNING=0

# Function to record check result
record_check() {
    local check_name="$1"
    local status="$2"  # pass, fail, warning
    local message="$3"
    
    case "$status" in
        pass)
            CHECKS_PASSED=$((CHECKS_PASSED + 1))
            [ "$OUTPUT_FORMAT" = "text" ] && echo -e "${GREEN}[PASS]${NC} $check_name: $message"
            ;;
        fail)
            CHECKS_FAILED=$((CHECKS_FAILED + 1))
            [ "$OUTPUT_FORMAT" = "text" ] && echo -e "${RED}[FAIL]${NC} $check_name: $message"
            ;;
        warning)
            CHECKS_WARNING=$((CHECKS_WARNING + 1))
            [ "$OUTPUT_FORMAT" = "text" ] && echo -e "${YELLOW}[WARN]${NC} $check_name: $message"
            ;;
    esac
}

# Basic health checks
perform_basic_checks() {
    # Check if application directories exist
    for dir in /app/tcg_cards_input /app/processed /app/logs; do
        if [ -d "$dir" ]; then
            record_check "Directory Check" "pass" "$dir exists"
        else
            record_check "Directory Check" "fail" "$dir missing"
        fi
    done
    
    # Check if Python is available
    if command -v python >/dev/null 2>&1; then
        PY_VERSION=$(python --version 2>&1)
        record_check "Python Check" "pass" "$PY_VERSION"
    else
        record_check "Python Check" "fail" "Python not found"
    fi
    
    # Check if main application file exists
    if [ -f "/app/tcg_card_printer.py" ]; then
        record_check "Application File" "pass" "Main script exists"
    else
        record_check "Application File" "fail" "Main script missing"
    fi
    
    # Check if application process is running
    if pgrep -f "tcg_card_printer.py" >/dev/null 2>&1; then
        PID=$(pgrep -f "tcg_card_printer.py")
        record_check "Application Process" "pass" "Running (PID: $PID)"
    else
        record_check "Application Process" "fail" "Not running"
    fi
}

# Detailed health checks
perform_detailed_checks() {
    # Perform basic checks first
    perform_basic_checks
    
    # Check CUPS connectivity
    if [ -S "/var/run/cups/cups.sock" ]; then
        record_check "CUPS Socket" "pass" "Socket available"
        
        # Try to list printers
        if command -v lpstat >/dev/null 2>&1; then
            if lpstat -p >/dev/null 2>&1; then
                record_check "CUPS Connection" "pass" "Can communicate with CUPS"
            else
                record_check "CUPS Connection" "warning" "CUPS socket exists but cannot list printers"
            fi
        fi
    else
        # Check for network printing configuration
        if [ "$TCG_USE_NETWORK_PRINTING" = "true" ]; then
            record_check "CUPS Socket" "warning" "Not using local socket (network printing enabled)"
        else
            record_check "CUPS Socket" "fail" "Socket not found and network printing not enabled"
        fi
    fi
    
    # Check log file accessibility
    if [ -w "/app/logs" ]; then
        record_check "Log Directory" "pass" "Writable"
        
        # Check if log file exists and is recent
        LOG_FILE="/app/logs/tcg_printer.log"
        if [ -f "$LOG_FILE" ]; then
            # Check if log was updated in last 5 minutes
            if [ -z "$(find "$LOG_FILE" -mmin +5 2>/dev/null)" ]; then
                record_check "Log Activity" "pass" "Recent activity detected"
            else
                record_check "Log Activity" "warning" "No recent log activity"
            fi
        fi
    else
        record_check "Log Directory" "fail" "Not writable"
    fi
    
    # Check memory usage
    if command -v free >/dev/null 2>&1; then
        MEM_AVAILABLE=$(free -m | awk 'NR==2{print $7}')
        if [ "$MEM_AVAILABLE" -gt 100 ]; then
            record_check "Memory" "pass" "${MEM_AVAILABLE}MB available"
        elif [ "$MEM_AVAILABLE" -gt 50 ]; then
            record_check "Memory" "warning" "${MEM_AVAILABLE}MB available (low)"
        else
            record_check "Memory" "fail" "${MEM_AVAILABLE}MB available (critical)"
        fi
    fi
}

# Diagnostic health checks
perform_diagnostic_checks() {
    # Perform detailed checks first
    perform_detailed_checks
    
    # Check Python dependencies
    if python -c "import pycups, PIL, watchdog" 2>/dev/null; then
        record_check "Python Dependencies" "pass" "All required modules available"
    else
        record_check "Python Dependencies" "fail" "Missing required Python modules"
    fi
    
    # Check file processing queue
    INPUT_COUNT=$(find /app/tcg_cards_input -type f -name "*.jpg" -o -name "*.png" 2>/dev/null | wc -l)
    if [ "$INPUT_COUNT" -gt 10 ]; then
        record_check "Processing Queue" "warning" "$INPUT_COUNT files pending (high)"
    else
        record_check "Processing Queue" "pass" "$INPUT_COUNT files pending"
    fi
    
    # Check disk space
    if command -v df >/dev/null 2>&1; then
        DISK_USAGE=$(df -h /app | awk 'NR==2{print $5}' | sed 's/%//')
        if [ "$DISK_USAGE" -lt 80 ]; then
            record_check "Disk Space" "pass" "${DISK_USAGE}% used"
        elif [ "$DISK_USAGE" -lt 90 ]; then
            record_check "Disk Space" "warning" "${DISK_USAGE}% used"
        else
            record_check "Disk Space" "fail" "${DISK_USAGE}% used (critical)"
        fi
    fi
    
    # Check configuration validity
    if python -c "import config" 2>/dev/null; then
        record_check "Configuration" "pass" "Valid configuration loaded"
    else
        record_check "Configuration" "fail" "Configuration error"
    fi
}

# Output JSON format
output_json() {
    local status="healthy"
    [ "$CHECKS_FAILED" -gt 0 ] && status="unhealthy"
    [ "$CHECKS_WARNING" -gt 3 ] && status="degraded"
    
    cat <<EOF
{
  "status": "$status",
  "timestamp": "$(date -u +"%Y-%m-%dT%H:%M:%SZ")",
  "checks": {
    "passed": $CHECKS_PASSED,
    "failed": $CHECKS_FAILED,
    "warnings": $CHECKS_WARNING
  },
  "level": "$HEALTH_CHECK_LEVEL"
}
EOF
}

# Main execution
case "$HEALTH_CHECK_LEVEL" in
    basic)
        perform_basic_checks
        ;;
    detailed)
        perform_detailed_checks
        ;;
    diagnostic)
        perform_diagnostic_checks
        ;;
    *)
        echo "Invalid health check level: $HEALTH_CHECK_LEVEL"
        echo "Usage: $0 [basic|detailed|diagnostic] [text|json]"
        exit 1
        ;;
esac

# Output results
if [ "$OUTPUT_FORMAT" = "json" ]; then
    output_json
else
    echo ""
    echo "Health Check Summary:"
    echo "  Passed: $CHECKS_PASSED"
    echo "  Failed: $CHECKS_FAILED"
    echo "  Warnings: $CHECKS_WARNING"
fi

# Exit with appropriate code
if [ "$CHECKS_FAILED" -gt 0 ]; then
    exit 1
elif [ "$CHECKS_WARNING" -gt 3 ]; then
    exit 2
else
    exit 0
fi