#!/bin/bash
#
# run-ios-tests.sh
# Automated iOS test runner for Zoe Sleep app
#
# Usage:
#   ./scripts/run-ios-tests.sh                    # Run all tests
#   ./scripts/run-ios-tests.sh unit               # Run unit tests only
#   ./scripts/run-ios-tests.sh ui                 # Run UI tests only
#   ./scripts/run-ios-tests.sh integration        # Run integration tests only
#   ./scripts/run-ios-tests.sh clinical           # Run clinical scoring tests
#   ./scripts/run-ios-tests.sh coverage           # Run with code coverage
#

set -e

# Configuration
PROJECT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
XCODE_PROJECT="$PROJECT_DIR/ZoeSleep/ZoeSleep.xcodeproj"
SCHEME="ZoeSleep"
TEST_SCHEME="ZoeSleepTests"
UI_TEST_SCHEME="ZoeSleepUITests"
DESTINATION="platform=iOS Simulator,name=iPhone 15 Pro,OS=latest"
DERIVED_DATA="$PROJECT_DIR/.build/DerivedData"
RESULTS_DIR="$PROJECT_DIR/.build/TestResults"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Print helpers
print_header() {
    echo -e "\n${BLUE}========================================${NC}"
    echo -e "${BLUE}  $1${NC}"
    echo -e "${BLUE}========================================${NC}\n"
}

print_success() {
    echo -e "${GREEN}✓ $1${NC}"
}

print_error() {
    echo -e "${RED}✗ $1${NC}"
}

print_warning() {
    echo -e "${YELLOW}⚠ $1${NC}"
}

# Create results directory
mkdir -p "$RESULTS_DIR"

# Parse arguments
TEST_TYPE="${1:-all}"
ENABLE_COVERAGE=false

if [[ "$2" == "coverage" ]] || [[ "$1" == "coverage" ]]; then
    ENABLE_COVERAGE=true
    if [[ "$1" == "coverage" ]]; then
        TEST_TYPE="all"
    fi
fi

# Build coverage flags
COVERAGE_FLAGS=""
if $ENABLE_COVERAGE; then
    COVERAGE_FLAGS="-enableCodeCoverage YES"
fi

# Run unit tests
run_unit_tests() {
    print_header "Running Unit Tests"

    xcodebuild test \
        -project "$XCODE_PROJECT" \
        -scheme "$SCHEME" \
        -destination "$DESTINATION" \
        -derivedDataPath "$DERIVED_DATA" \
        -resultBundlePath "$RESULTS_DIR/UnitTests.xcresult" \
        -only-testing:ZoeSleepTests/QuestionnaireManagerTests \
        -only-testing:ZoeSleepTests/ClinicalScoringTests \
        -only-testing:ZoeSleepTests/AuthenticationManagerTests \
        -only-testing:ZoeSleepTests/ConvexServiceTests \
        -only-testing:ZoeSleepTests/HealthKitManagerTests \
        -only-testing:ZoeSleepTests/ThemeManagerTests \
        $COVERAGE_FLAGS \
        2>&1 | tee "$RESULTS_DIR/unit-tests.log" | grep -E "(Test Suite|Test Case|passed|failed|error:)"

    if [ ${PIPESTATUS[0]} -eq 0 ]; then
        print_success "Unit tests passed"
    else
        print_error "Unit tests failed"
        return 1
    fi
}

# Run UI tests
run_ui_tests() {
    print_header "Running UI Tests"

    xcodebuild test \
        -project "$XCODE_PROJECT" \
        -scheme "$SCHEME" \
        -destination "$DESTINATION" \
        -derivedDataPath "$DERIVED_DATA" \
        -resultBundlePath "$RESULTS_DIR/UITests.xcresult" \
        -only-testing:ZoeSleepUITests \
        $COVERAGE_FLAGS \
        2>&1 | tee "$RESULTS_DIR/unit-tests.log" | grep -E "(Test Suite|Test Case|passed|failed|error:)"

    if [ ${PIPESTATUS[0]} -eq 0 ]; then
        print_success "UI tests passed"
    else
        print_error "UI tests failed"
        return 1
    fi
}

# Run integration tests
run_integration_tests() {
    print_header "Running Integration Tests"

    xcodebuild test \
        -project "$XCODE_PROJECT" \
        -scheme "$SCHEME" \
        -destination "$DESTINATION" \
        -derivedDataPath "$DERIVED_DATA" \
        -resultBundlePath "$RESULTS_DIR/IntegrationTests.xcresult" \
        -only-testing:ZoeSleepTests/IntegrationTests \
        $COVERAGE_FLAGS \
        2>&1 | tee "$RESULTS_DIR/unit-tests.log" | grep -E "(Test Suite|Test Case|passed|failed|error:)"

    if [ ${PIPESTATUS[0]} -eq 0 ]; then
        print_success "Integration tests passed"
    else
        print_error "Integration tests failed"
        return 1
    fi
}

# Run clinical scoring tests
run_clinical_tests() {
    print_header "Running Clinical Scoring Tests"

    xcodebuild test \
        -project "$XCODE_PROJECT" \
        -scheme "$SCHEME" \
        -destination "$DESTINATION" \
        -derivedDataPath "$DERIVED_DATA" \
        -resultBundlePath "$RESULTS_DIR/ClinicalTests.xcresult" \
        -only-testing:ZoeSleepTests/ClinicalScoringTests \
        $COVERAGE_FLAGS \
        2>&1 | tee "$RESULTS_DIR/unit-tests.log" | grep -E "(Test Suite|Test Case|passed|failed|error:)"

    if [ ${PIPESTATUS[0]} -eq 0 ]; then
        print_success "Clinical scoring tests passed"
    else
        print_error "Clinical scoring tests failed"
        return 1
    fi
}

# Run all tests
run_all_tests() {
    print_header "Running All Tests"

    xcodebuild test \
        -project "$XCODE_PROJECT" \
        -scheme "$SCHEME" \
        -destination "$DESTINATION" \
        -derivedDataPath "$DERIVED_DATA" \
        -resultBundlePath "$RESULTS_DIR/AllTests.xcresult" \
        $COVERAGE_FLAGS \
        2>&1 | tee "$RESULTS_DIR/unit-tests.log" | grep -E "(Test Suite|Test Case|passed|failed|error:)"

    if [ ${PIPESTATUS[0]} -eq 0 ]; then
        print_success "All tests passed"
    else
        print_error "Some tests failed"
        return 1
    fi
}

# Generate coverage report
generate_coverage_report() {
    if $ENABLE_COVERAGE; then
        print_header "Generating Coverage Report"

        xcrun xccov view --report "$RESULTS_DIR/AllTests.xcresult" > "$RESULTS_DIR/coverage.txt"
        print_success "Coverage report saved to $RESULTS_DIR/coverage.txt"

        # Print summary
        echo ""
        head -20 "$RESULTS_DIR/coverage.txt"
    fi
}

# Main execution
print_header "Zoe Sleep iOS Test Runner"
echo "Project: $XCODE_PROJECT"
echo "Scheme: $SCHEME"
echo "Test Type: $TEST_TYPE"
echo "Coverage: $ENABLE_COVERAGE"

case $TEST_TYPE in
    unit)
        run_unit_tests
        ;;
    ui)
        run_ui_tests
        ;;
    integration)
        run_integration_tests
        ;;
    clinical)
        run_clinical_tests
        ;;
    all|coverage)
        run_all_tests
        generate_coverage_report
        ;;
    *)
        echo "Unknown test type: $TEST_TYPE"
        echo "Usage: $0 [unit|ui|integration|clinical|all|coverage]"
        exit 1
        ;;
esac

print_header "Test Run Complete"
echo "Results saved to: $RESULTS_DIR"
