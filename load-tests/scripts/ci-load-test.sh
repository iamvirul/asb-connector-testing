#!/usr/bin/env bash
# =============================================================================
# ci-load-test.sh — CI/CD-friendly JMeter Load Test Runner
#
# Returns exit code 1 if error rate exceeds threshold
# Outputs results in JUnit XML format for CI integration
#
# Usage:
#   ./ci-load-test.sh baseline 1.0      # Fail if error rate > 1%
#   ./ci-load-test.sh smoke 5.0         # Fail if error rate > 5%
#
# =============================================================================

set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_DIR="$(dirname "$SCRIPT_DIR")"

PROFILE="${1:-smoke}"
ERROR_THRESHOLD="${2:-1.0}"
TIMESTAMP=$(date +"%Y%m%d_%H%M%S")
RESULTS_DIR="${RESULTS_DIR:-$PROJECT_DIR/results}"
REPORT_DIR="$RESULTS_DIR/${PROFILE}_${TIMESTAMP}"

echo "========================================"
echo "ASB Connector Load Test (CI Mode)"
echo "========================================"
echo "Profile:         $PROFILE"
echo "Error Threshold: ${ERROR_THRESHOLD}%"
echo "Results Dir:     $REPORT_DIR"
echo "========================================"

# Run the load test
"$SCRIPT_DIR/run-load-test.sh" "$PROFILE"
TEST_EXIT_CODE=$?

if [[ $TEST_EXIT_CODE -ne 0 ]]; then
    echo "ERROR: JMeter execution failed"
    exit 1
fi

# Analyze results
RESULTS_FILE="$REPORT_DIR/results.jtl"

if [[ ! -f "$RESULTS_FILE" ]]; then
    echo "ERROR: Results file not found"
    exit 1
fi

# Calculate metrics
TOTAL=$(tail -n +2 "$RESULTS_FILE" | wc -l | tr -d ' ')
SUCCESS=$(tail -n +2 "$RESULTS_FILE" | awk -F',' '{if($8=="true") count++} END {print count+0}')
FAILED=$((TOTAL - SUCCESS))
ERROR_RATE=$(echo "scale=4; $FAILED * 100 / $TOTAL" | bc)

# Calculate percentiles
P50=$(tail -n +2 "$RESULTS_FILE" | awk -F',' '{print $2}' | sort -n | awk 'BEGIN{c=0} {a[c++]=$1} END{print a[int(c*0.50)]}')
P95=$(tail -n +2 "$RESULTS_FILE" | awk -F',' '{print $2}' | sort -n | awk 'BEGIN{c=0} {a[c++]=$1} END{print a[int(c*0.95)]}')
P99=$(tail -n +2 "$RESULTS_FILE" | awk -F',' '{print $2}' | sort -n | awk 'BEGIN{c=0} {a[c++]=$1} END{print a[int(c*0.99)]}')
AVG=$(tail -n +2 "$RESULTS_FILE" | awk -F',' '{sum+=$2; count++} END {printf "%.0f", sum/count}')

echo ""
echo "========================================"
echo "RESULTS"
echo "========================================"
echo "Total Requests:    $TOTAL"
echo "Successful:        $SUCCESS"
echo "Failed:            $FAILED"
echo "Error Rate:        ${ERROR_RATE}%"
echo "Avg Response:      ${AVG}ms"
echo "P50 Response:      ${P50}ms"
echo "P95 Response:      ${P95}ms"
echo "P99 Response:      ${P99}ms"
echo "========================================"

# Generate JUnit XML report for CI
JUNIT_FILE="$REPORT_DIR/junit-report.xml"
cat > "$JUNIT_FILE" << EOF
<?xml version="1.0" encoding="UTF-8"?>
<testsuites name="ASB Connector Load Test" tests="4" failures="0" errors="0" time="0">
  <testsuite name="Load Test - $PROFILE" tests="4" failures="0" errors="0">
    <testcase name="Total Requests: $TOTAL" classname="LoadTest" time="0"/>
    <testcase name="Error Rate: ${ERROR_RATE}%" classname="LoadTest" time="0"/>
    <testcase name="Avg Response: ${AVG}ms" classname="LoadTest" time="0"/>
    <testcase name="P95 Response: ${P95}ms" classname="LoadTest" time="0"/>
  </testsuite>
</testsuites>
EOF

# Generate metrics JSON for dashboards
METRICS_FILE="$REPORT_DIR/metrics.json"
cat > "$METRICS_FILE" << EOF
{
  "profile": "$PROFILE",
  "timestamp": "$(date -u +"%Y-%m-%dT%H:%M:%SZ")",
  "total_requests": $TOTAL,
  "successful": $SUCCESS,
  "failed": $FAILED,
  "error_rate": $ERROR_RATE,
  "response_time": {
    "avg": $AVG,
    "p50": $P50,
    "p95": $P95,
    "p99": $P99
  },
  "threshold": {
    "error_rate": $ERROR_THRESHOLD,
    "passed": $(echo "$ERROR_RATE <= $ERROR_THRESHOLD" | bc)
  }
}
EOF

echo ""
echo "Reports generated:"
echo "  - JUnit XML: $JUNIT_FILE"
echo "  - Metrics JSON: $METRICS_FILE"
echo "  - HTML Report: $REPORT_DIR/html/index.html"

# Check threshold
THRESHOLD_CHECK=$(echo "$ERROR_RATE > $ERROR_THRESHOLD" | bc)
if [[ "$THRESHOLD_CHECK" -eq 1 ]]; then
    echo ""
    echo "FAILED: Error rate ${ERROR_RATE}% exceeds threshold ${ERROR_THRESHOLD}%"
    exit 1
else
    echo ""
    echo "PASSED: Error rate ${ERROR_RATE}% within threshold ${ERROR_THRESHOLD}%"
    exit 0
fi
