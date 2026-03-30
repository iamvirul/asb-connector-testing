# ASB Connector Load Tests

JMeter-based load testing suite for the Azure Service Bus connector APIs.

## Prerequisites

- **JMeter 5.5+**: Install via `brew install jmeter` (macOS) or download from [Apache JMeter](https://jmeter.apache.org/download_jmeter.cgi)
- **WSO2 MI Server**: Running at `localhost:8290` (or configure custom host/port)
- **bc**: For CI scripts (`brew install bc` on macOS)

## Quick Start

```bash
# 1. Start WSO2 MI server
# 2. Run smoke test (30 seconds)
./scripts/run-load-test.sh smoke

# 3. Run baseline test (5 minutes)
./scripts/run-load-test.sh baseline
```

## Directory Structure

```
load-tests/
├── test-plans/
│   └── asb-load-test.jmx       # Main JMeter test plan
├── config/
│   ├── smoke.properties        # Quick validation (30s, 2 threads)
│   ├── baseline.properties     # Normal load (5m, 10 threads)
│   ├── stress.properties       # Find breaking point (10m, 50 threads)
│   ├── soak.properties         # Memory leak detection (30m, 20 threads)
│   └── custom.properties.example
├── data/
│   └── messages.csv            # Test data for parameterized requests
├── scripts/
│   ├── run-load-test.sh        # Main test runner
│   └── ci-load-test.sh         # CI/CD runner with thresholds
└── results/                    # Generated test results (gitignored)
```

## Test Profiles

| Profile | Threads | Duration | Purpose |
|---------|---------|----------|---------|
| smoke | 2 | 30s | Quick validation |
| baseline | 10 | 5m | Performance baseline |
| stress | 50 | 10m | Find system limits |
| soak | 20 | 30m | Memory leak detection |

## Running Tests

### Interactive Mode (with HTML report)

```bash
# Run specific profile
./scripts/run-load-test.sh <profile>

# Examples
./scripts/run-load-test.sh smoke     # Quick test
./scripts/run-load-test.sh baseline  # Standard test
./scripts/run-load-test.sh stress    # High load test
```

### CI/CD Mode (with threshold checks)

```bash
# Fail if error rate > 1%
./scripts/ci-load-test.sh baseline 1.0

# Fail if error rate > 5%
./scripts/ci-load-test.sh smoke 5.0
```

### Custom Configuration

```bash
# Copy example and modify
cp config/custom.properties.example config/custom.properties
# Edit config/custom.properties
./scripts/run-load-test.sh custom
```

### JMeter GUI (for debugging)

```bash
jmeter -t test-plans/asb-load-test.jmx
```

## Environment Variables

| Variable | Default | Description |
|----------|---------|-------------|
| `JMETER_HOME` | Auto-detect | Path to JMeter installation |
| `RESULTS_DIR` | `load-tests/results` | Output directory |
| `HEAP_SIZE` | `2g` | JMeter JVM heap size |

```bash
# Example: Run stress test with 4GB heap
HEAP_SIZE=4g ./scripts/run-load-test.sh stress
```

## Test Plan Overview

The test plan includes these thread groups:

1. **Message Sender (send)** - POST `/messagesender/send`
2. **Message Sender (sendPayload)** - POST `/messagesender/sendPayload`
3. **Message Sender (sendBatch)** - POST `/messagesender/sendBatch`
4. **Message Receiver** - GET `/messagereceiver/receive`
5. **Message Receiver (batch)** - GET `/messagereceiver/receiveBatch/{count}`
6. **Mixed Workload** - Realistic mix (60% send, 30% receive, 10% batch) - disabled by default

## Results

After each test run, results are saved to `results/<profile>_<timestamp>/`:

- `results.jtl` - Raw JMeter results (CSV)
- `jmeter.log` - JMeter execution log
- `html/index.html` - Interactive HTML dashboard
- `junit-report.xml` - JUnit format for CI (ci-load-test.sh only)
- `metrics.json` - JSON metrics for dashboards (ci-load-test.sh only)

## Performance Tuning

### JMeter Heap Size
For high-load tests (50+ threads), increase heap:
```bash
HEAP_SIZE=4g ./scripts/run-load-test.sh stress
```

### Connection Pooling
The test plan uses keep-alive connections. Adjust timeouts in the .jmx if needed.

### Think Time
Adjust `thinktime` in properties files to control pacing between requests.

## Integrating with CI/CD

### GitHub Actions

```yaml
- name: Run Load Test
  run: |
    ./load-tests/scripts/ci-load-test.sh smoke 2.0

- name: Upload Results
  uses: actions/upload-artifact@v4
  with:
    name: load-test-results
    path: load-tests/results/
```

### Jenkins

```groovy
stage('Load Test') {
    steps {
        sh './load-tests/scripts/ci-load-test.sh baseline 1.0'
    }
    post {
        always {
            publishHTML([
                reportDir: 'load-tests/results/baseline_*/html',
                reportFiles: 'index.html',
                reportName: 'JMeter Report'
            ])
        }
    }
}
```

## Troubleshooting

### JMeter not found
```bash
# Set JMETER_HOME
export JMETER_HOME=/path/to/apache-jmeter-5.6.3
./scripts/run-load-test.sh smoke
```

### Server not responding
Ensure WSO2 MI is running:
```bash
curl http://localhost:8290/admin/listTopics
```

### Out of memory
Increase heap size:
```bash
HEAP_SIZE=4g ./scripts/run-load-test.sh stress
```
