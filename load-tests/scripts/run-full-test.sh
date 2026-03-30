#!/usr/bin/env bash
# =============================================================================
# run-full-test.sh — Run all 33 endpoints load test
# =============================================================================

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_DIR="$(dirname "$SCRIPT_DIR")"

TIMESTAMP=$(date +"%Y%m%d_%H%M%S")
RESULTS_DIR="$PROJECT_DIR/results/full_${TIMESTAMP}"
TEST_PLAN="$PROJECT_DIR/test-plans/asb-full-test.jmx"

# Defaults (can override via env vars)
HOST="${HOST:-localhost}"
PORT="${PORT:-8290}"
THREADS="${THREADS:-5}"
RAMP_UP="${RAMP_UP:-10}"
DURATION="${DURATION:-60}"

GREEN='\033[0;32m'
RED='\033[0;31m'
CYAN='\033[0;36m'
NC='\033[0m'

echo ""
echo -e "${CYAN}╔═══════════════════════════════════════════════════════════╗${NC}"
echo -e "${CYAN}║   ASB Connector - Full Load Test (All 33 Endpoints)       ║${NC}"
echo -e "${CYAN}╚═══════════════════════════════════════════════════════════╝${NC}"
echo ""

# Check JMeter
JMETER=$(which jmeter 2>/dev/null || echo "")
if [[ -z "$JMETER" ]]; then
    echo -e "${RED}ERROR: JMeter not found. Install with: brew install jmeter${NC}"
    exit 1
fi
echo -e "${GREEN}[OK]${NC} JMeter found: $JMETER"

# Check server
echo -e "${CYAN}[INFO]${NC} Checking server at $HOST:$PORT..."
if ! curl -s --max-time 5 "http://$HOST:$PORT/admin/listTopics" > /dev/null 2>&1; then
    echo -e "${RED}ERROR: Server not responding at http://$HOST:$PORT${NC}"
    exit 1
fi
echo -e "${GREEN}[OK]${NC} Server is responding"

# Create results directory
mkdir -p "$RESULTS_DIR"

echo ""
echo -e "${CYAN}═══════════════════════════════════════════════════════════${NC}"
echo -e "  Threads:   $THREADS per group"
echo -e "  Ramp-up:   ${RAMP_UP}s"
echo -e "  Duration:  ${DURATION}s"
echo -e "  Results:   $RESULTS_DIR"
echo -e "${CYAN}═══════════════════════════════════════════════════════════${NC}"
echo ""

# Run JMeter
export JVM_ARGS="-Xms2g -Xmx2g"

jmeter -n \
    -t "$TEST_PLAN" \
    -l "$RESULTS_DIR/results.jtl" \
    -j "$RESULTS_DIR/jmeter.log" \
    -e -o "$RESULTS_DIR/html" \
    -Jhost="$HOST" \
    -Jport="$PORT" \
    -Jthreads="$THREADS" \
    -Jrampup="$RAMP_UP" \
    -Jduration="$DURATION"

echo ""
echo -e "${CYAN}═══════════════════════════════════════════════════════════${NC}"
echo -e "${CYAN}  TEST SUMMARY${NC}"
echo -e "${CYAN}═══════════════════════════════════════════════════════════${NC}"

if [[ -f "$RESULTS_DIR/results.jtl" ]]; then
    TOTAL=$(tail -n +2 "$RESULTS_DIR/results.jtl" | wc -l | tr -d ' ')
    SUCCESS=$(tail -n +2 "$RESULTS_DIR/results.jtl" | awk -F',' '{if($8=="true") count++} END {print count+0}')
    FAILED=$((TOTAL - SUCCESS))

    echo -e "  Total Requests:  $TOTAL"
    echo -e "  ${GREEN}Successful:${NC}      $SUCCESS"
    echo -e "  ${RED}Failed:${NC}          $FAILED"

    if [[ $TOTAL -gt 0 ]]; then
        ERROR_RATE=$(echo "scale=2; $FAILED * 100 / $TOTAL" | bc)
        echo -e "  Error Rate:      ${ERROR_RATE}%"
    fi

    # Count unique endpoints tested
    ENDPOINTS=$(tail -n +2 "$RESULTS_DIR/results.jtl" | awk -F',' '{print $3}' | sort -u | wc -l | tr -d ' ')
    echo -e "  Endpoints:       $ENDPOINTS"
fi

echo -e "${CYAN}═══════════════════════════════════════════════════════════${NC}"
echo ""
echo -e "${CYAN}[INFO]${NC} HTML Report: $RESULTS_DIR/html/index.html"
echo ""
