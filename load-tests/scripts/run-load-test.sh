#!/usr/bin/env bash
# =============================================================================
# run-load-test.sh — JMeter Load Test Runner for ASB Connector
#
# Usage:
#   ./run-load-test.sh                    Run with default baseline profile
#   ./run-load-test.sh smoke              Quick smoke test (30s)
#   ./run-load-test.sh baseline           Baseline performance test (5m)
#   ./run-load-test.sh stress             Stress test (10m)
#   ./run-load-test.sh soak               Soak/endurance test (30m)
#   ./run-load-test.sh custom             Use custom.properties if exists
#
# Environment Variables:
#   JMETER_HOME     Path to JMeter installation (auto-detected if not set)
#   RESULTS_DIR     Directory for results (default: load-tests/results)
#   HEAP_SIZE       JMeter heap size (default: 2g)
#
# =============================================================================

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_DIR="$(dirname "$SCRIPT_DIR")"
ROOT_DIR="$(dirname "$PROJECT_DIR")"

# Colors
GREEN='\033[0;32m'
RED='\033[0;31m'
YELLOW='\033[1;33m'
CYAN='\033[0;36m'
NC='\033[0m'

# Defaults
PROFILE="${1:-baseline}"
TIMESTAMP=$(date +"%Y%m%d_%H%M%S")
RESULTS_DIR="${RESULTS_DIR:-$PROJECT_DIR/results}"
HEAP_SIZE="${HEAP_SIZE:-2g}"

# Paths
TEST_PLAN="$PROJECT_DIR/test-plans/asb-load-test.jmx"
DATA_DIR="$PROJECT_DIR/data"
CONFIG_DIR="$PROJECT_DIR/config"
REPORT_DIR="$RESULTS_DIR/${PROFILE}_${TIMESTAMP}"
LOG_FILE="$REPORT_DIR/jmeter.log"
RESULTS_FILE="$REPORT_DIR/results.jtl"

# =============================================================================
# Functions
# =============================================================================

log_info() {
    echo -e "${CYAN}[INFO]${NC} $1"
}

log_success() {
    echo -e "${GREEN}[OK]${NC} $1"
}

log_warn() {
    echo -e "${YELLOW}[WARN]${NC} $1"
}

log_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

detect_jmeter() {
    if [[ -n "${JMETER_HOME:-}" ]] && [[ -x "$JMETER_HOME/bin/jmeter" ]]; then
        JMETER="$JMETER_HOME/bin/jmeter"
        return 0
    fi

    # Common installation paths
    local paths=(
        "/opt/homebrew/bin/jmeter"
        "/usr/local/bin/jmeter"
        "/opt/jmeter/bin/jmeter"
        "$HOME/apache-jmeter-5.6.3/bin/jmeter"
        "$HOME/apache-jmeter/bin/jmeter"
    )

    for path in "${paths[@]}"; do
        if [[ -x "$path" ]]; then
            JMETER="$path"
            return 0
        fi
    done

    # Try PATH
    if command -v jmeter &> /dev/null; then
        JMETER=$(command -v jmeter)
        return 0
    fi

    return 1
}

check_server() {
    local host="${HOST:-localhost}"
    local port="${PORT:-8290}"

    log_info "Checking if WSO2 MI server is running at $host:$port..."

    if curl -s --max-time 5 "http://$host:$port/admin/listTopics" > /dev/null 2>&1; then
        log_success "Server is responding"
        return 0
    else
        log_error "Server is not responding at http://$host:$port"
        log_error "Start WSO2 MI server before running load tests"
        return 1
    fi
}

load_properties() {
    local prop_file="$CONFIG_DIR/${PROFILE}.properties"

    if [[ ! -f "$prop_file" ]]; then
        log_error "Profile '$PROFILE' not found: $prop_file"
        log_info "Available profiles: smoke, baseline, stress, soak, custom"
        exit 1
    fi

    log_info "Loading profile: $PROFILE"

    # Read properties into environment
    while IFS='=' read -r key value; do
        # Skip comments and empty lines
        [[ "$key" =~ ^#.*$ ]] && continue
        [[ -z "$key" ]] && continue

        # Export as uppercase
        key=$(echo "$key" | tr '[:lower:]' '[:upper:]')
        export "$key"="$value"
    done < "$prop_file"

    log_success "Profile loaded: threads=${THREADS:-10}, duration=${DURATION:-300}s"
}

build_jmeter_args() {
    local prop_file="$CONFIG_DIR/${PROFILE}.properties"

    JMETER_ARGS=(
        -n                              # Non-GUI mode
        -t "$TEST_PLAN"                 # Test plan
        -l "$RESULTS_FILE"              # Results file
        -j "$LOG_FILE"                  # Log file
        -e                              # Generate HTML report
        -o "$REPORT_DIR/html"           # Report output directory
        -Jdatadir="$DATA_DIR"           # Data directory
    )

    # Add properties from file
    while IFS='=' read -r key value; do
        [[ "$key" =~ ^#.*$ ]] && continue
        [[ -z "$key" ]] && continue
        JMETER_ARGS+=("-J$key=$value")
    done < "$prop_file"
}

run_test() {
    log_info "Starting JMeter load test..."
    log_info "Profile: $PROFILE"
    log_info "Results: $REPORT_DIR"

    # Set JVM options
    export JVM_ARGS="-Xms${HEAP_SIZE} -Xmx${HEAP_SIZE} -XX:+UseG1GC"

    # Create results directory
    mkdir -p "$REPORT_DIR"

    echo ""
    echo -e "${CYAN}═══════════════════════════════════════════════════════════${NC}"
    echo -e "${CYAN}  ASB Connector Load Test - $PROFILE${NC}"
    echo -e "${CYAN}═══════════════════════════════════════════════════════════${NC}"
    echo -e "  Threads:   ${THREADS:-10}"
    echo -e "  Ramp-up:   ${RAMPUP:-30}s"
    echo -e "  Duration:  ${DURATION:-300}s"
    echo -e "  Results:   $REPORT_DIR"
    echo -e "${CYAN}═══════════════════════════════════════════════════════════${NC}"
    echo ""

    # Run JMeter
    "$JMETER" "${JMETER_ARGS[@]}"

    local exit_code=$?

    if [[ $exit_code -eq 0 ]]; then
        log_success "Load test completed successfully"
        echo ""
        log_info "Results saved to: $RESULTS_FILE"
        log_info "HTML Report: $REPORT_DIR/html/index.html"

        # Print summary
        print_summary
    else
        log_error "Load test failed with exit code: $exit_code"
        log_error "Check log file: $LOG_FILE"
        exit $exit_code
    fi
}

print_summary() {
    echo ""
    echo -e "${CYAN}═══════════════════════════════════════════════════════════${NC}"
    echo -e "${CYAN}  TEST SUMMARY${NC}"
    echo -e "${CYAN}═══════════════════════════════════════════════════════════${NC}"

    if [[ -f "$RESULTS_FILE" ]]; then
        local total=$(tail -n +2 "$RESULTS_FILE" | wc -l | tr -d ' ')
        local success=$(tail -n +2 "$RESULTS_FILE" | awk -F',' '{if($8=="true") count++} END {print count+0}')
        local failed=$((total - success))
        local error_rate=$(echo "scale=2; $failed * 100 / $total" | bc 2>/dev/null || echo "N/A")

        echo -e "  Total Requests:  $total"
        echo -e "  ${GREEN}Successful:${NC}      $success"
        echo -e "  ${RED}Failed:${NC}          $failed"
        echo -e "  Error Rate:      ${error_rate}%"

        # Average response time
        local avg_time=$(tail -n +2 "$RESULTS_FILE" | awk -F',' '{sum+=$2; count++} END {printf "%.0f", sum/count}')
        echo -e "  Avg Response:    ${avg_time}ms"
    fi

    echo -e "${CYAN}═══════════════════════════════════════════════════════════${NC}"
    echo ""
}

show_help() {
    cat << EOF
ASB Connector Load Test Runner

Usage: $(basename "$0") [PROFILE] [OPTIONS]

Profiles:
  smoke       Quick validation test (30 seconds, 2 threads)
  baseline    Baseline performance test (5 minutes, 10 threads)
  stress      Stress test to find limits (10 minutes, 50 threads)
  soak        Endurance test for memory leaks (30 minutes, 20 threads)
  custom      Use custom.properties for custom configuration

Options:
  -h, --help  Show this help message

Environment Variables:
  JMETER_HOME   Path to JMeter installation
  RESULTS_DIR   Directory for test results
  HEAP_SIZE     JMeter heap size (default: 2g)

Examples:
  $(basename "$0")                    # Run baseline test
  $(basename "$0") smoke              # Quick smoke test
  HEAP_SIZE=4g $(basename "$0") stress # Stress test with 4GB heap

EOF
}

# =============================================================================
# Main
# =============================================================================

if [[ "${1:-}" == "-h" ]] || [[ "${1:-}" == "--help" ]]; then
    show_help
    exit 0
fi

echo ""
echo -e "${CYAN}╔═══════════════════════════════════════════════════════════╗${NC}"
echo -e "${CYAN}║     ASB Connector - JMeter Load Test Runner               ║${NC}"
echo -e "${CYAN}╚═══════════════════════════════════════════════════════════╝${NC}"
echo ""

# Detect JMeter
if ! detect_jmeter; then
    log_error "JMeter not found!"
    log_info "Install JMeter: brew install jmeter (macOS)"
    log_info "Or set JMETER_HOME environment variable"
    exit 1
fi
log_success "JMeter found: $JMETER"

# Verify test plan exists
if [[ ! -f "$TEST_PLAN" ]]; then
    log_error "Test plan not found: $TEST_PLAN"
    exit 1
fi
log_success "Test plan found"

# Verify data file exists
if [[ ! -f "$DATA_DIR/messages.csv" ]]; then
    log_error "Data file not found: $DATA_DIR/messages.csv"
    exit 1
fi
log_success "Data files found"

# Load profile
load_properties

# Check server availability
check_server

# Build JMeter arguments
build_jmeter_args

# Run test
run_test
