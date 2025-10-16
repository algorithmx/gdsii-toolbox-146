#!/bin/bash

# Comprehensive Test Runner for WASM GDSII Parser
# Runs all test categories with detailed reporting and logging

set -e  # Exit on any error

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
PURPLE='\033[0;35m'
CYAN='\033[0;36m'
NC='\033[0m' # No Color

# Test configuration
TEST_START_TIME=$(date +%s)
TEST_LOG="test-results-$(date +%Y%m%d-%H%M%S).log"
COVERAGE_LOG="coverage-report-$(date +%Y%m%d-%H%M%S).log"
TEMP_DIR="temp-test-$$"

# Test results tracking
TOTAL_TESTS=0
PASSED_TESTS=0
FAILED_TESTS=0
FAILED_CATEGORIES=0

# Test categories (in order of execution)
declare -a TEST_CATEGORIES=(
    "unit:Unit Tests:test-unit"
    "error:Error Handling Tests:test-error"
    "integration:Integration Tests:test-integration"
    "stress:Stress Tests:test-stress"
)

# Ensure cleanup on exit
cleanup() {
    if [ -d "$TEMP_DIR" ]; then
        rm -rf "$TEMP_DIR"
    fi
}
trap cleanup EXIT

# Logging functions
log_header() {
    echo -e "${BLUE}========================================${NC}"
    echo -e "${BLUE}$1${NC}"
    echo -e "${BLUE}========================================${NC}"
    echo "$1" >> "$TEST_LOG"
    echo "========================================" >> "$TEST_LOG"
}

log_success() {
    echo -e "${GREEN}✓ $1${NC}"
    echo "[SUCCESS] $1" >> "$TEST_LOG"
}

log_error() {
    echo -e "${RED}❌ $1${NC}"
    echo "[ERROR] $1" >> "$TEST_LOG"
}

log_warning() {
    echo -e "${YELLOW}⚠ $1${NC}"
    echo "[WARNING] $1" >> "$TEST_LOG"
}

log_info() {
    echo -e "${CYAN}ℹ $1${NC}"
    echo "[INFO] $1" >> "$TEST_LOG"
}

# Test execution functions
run_test_category() {
    local category_id="$1"
    local category_name="$2"
    local make_target="$3"

    log_header "Running $category_name"

    # Create temporary log for this category
    local category_log="$TEMP_DIR/${category_id}.log"

    # Run the tests
    if make "$make_target" > "$category_log" 2>&1; then
        log_success "$category_name completed successfully"

        # Extract test statistics if available
        if grep -q "Total tests:" "$category_log"; then
            local total=$(grep "Total tests:" "$category_log" | tail -1 | awk '{print $3}')
            local passed=$(grep "Passed:" "$category_log" | tail -1 | awk '{print $2}')
            local failed=$(grep "Failed:" "$category_log" | tail -1 | awk '{print $2}')

            log_info "Tests: $total total, $passed passed, $failed failed"

            TOTAL_TESTS=$((TOTAL_TESTS + total))
            PASSED_TESTS=$((PASSED_TESTS + passed))
            FAILED_TESTS=$((FAILED_TESTS + failed))

            if [ "$failed" -gt 0 ]; then
                FAILED_CATEGORIES=$((FAILED_CATEGORIES + 1))
                log_warning "Some tests in $category_name failed"
                echo "Last few lines of output:" >> "$TEST_LOG"
                tail -10 "$category_log" >> "$TEST_LOG"
            fi
        else
            log_info "$category_name completed (no detailed statistics available)"
        fi

        # Append category log to main log
        echo "" >> "$TEST_LOG"
        echo "--- $category_name Output ---" >> "$TEST_LOG"
        cat "$category_log" >> "$TEST_LOG"
        echo "" >> "$TEST_LOG"

        return 0
    else
        log_error "$category_name failed"
        FAILED_CATEGORIES=$((FAILED_CATEGORIES + 1))

        # Append error output to main log
        echo "" >> "$TEST_LOG"
        echo "--- $category_name Error Output ---" >> "$TEST_LOG"
        cat "$category_log" >> "$TEST_LOG"
        echo "" >> "$TEST_LOG"

        return 1
    fi
}

run_coverage_analysis() {
    log_header "Running Test Coverage Analysis"

    if make coverage > "$TEMP_DIR/coverage.log" 2>&1; then
        log_success "Coverage analysis completed"

        # Extract key coverage information
        if grep -q "Test Coverage Analysis" "$TEMP_DIR/coverage.log"; then
            log_info "Coverage analysis generated"
            echo "--- Coverage Analysis ---" >> "$TEST_LOG"
            cat "$TEMP_DIR/coverage.log" >> "$TEST_LOG"
            cp "$TEMP_DIR/coverage.log" "$COVERAGE_LOG"
        fi
    else
        log_warning "Coverage analysis failed (optional)"
    fi
}

check_environment() {
    log_header "Checking Test Environment"

    # Check if Makefile exists
    if [ ! -f "Makefile" ]; then
        log_error "Makefile not found"
        exit 1
    fi
    log_success "Makefile found"

    # Check compiler
    if command -v gcc >/dev/null 2>&1; then
        log_success "GCC compiler found: $(gcc --version | head -1)"
    else
        log_error "GCC compiler not found"
        exit 1
    fi

    # Check source directories
    if [ -d "../include" ]; then
        log_success "Include directory found"
    else
        log_warning "Include directory not found, tests may fail"
    fi

    if [ -d "../src" ]; then
        log_success "Source directory found"
    else
        log_warning "Source directory not found, tests may fail"
    fi

    # Check if make is available
    if command -v make >/dev/null 2>&1; then
        log_success "Make utility found: $(make --version | head -1)"
    else
        log_error "Make utility not found"
        exit 1
    fi
}

build_tests() {
    log_header "Building Test Suite"

    if make clean-all > "$TEMP_DIR/clean.log" 2>&1; then
        log_success "Clean completed"
    else
        log_warning "Clean failed (non-critical)"
    fi

    if make check-deps > "$TEMP_DIR/deps.log" 2>&1; then
        log_success "Dependencies checked"
    else
        log_error "Dependency check failed"
        exit 1
    fi

    if make build-all > "$TEMP_DIR/build.log" 2>&1; then
        log_success "All tests built successfully"
    else
        log_error "Test build failed"
        echo "Build errors:" >> "$TEST_LOG"
        cat "$TEMP_DIR/build.log" >> "$TEST_LOG"
        exit 1
    fi
}

print_summary() {
    local test_end_time=$(date +%s)
    local duration=$((test_end_time - TEST_START_TIME))
    local minutes=$((duration / 60))
    local seconds=$((duration % 60))

    log_header "Test Suite Summary"

    echo -e "${CYAN}Execution time: ${minutes}m ${seconds}s${NC}"
    echo -e "${CYAN}Categories executed: ${#TEST_CATEGORIES[@]}${NC}"
    echo -e "${CYAN}Failed categories: ${FAILED_CATEGORIES}${NC}"

    if [ "$TOTAL_TESTS" -gt 0 ]; then
        echo -e "${CYAN}Total tests: ${TOTAL_TESTS}${NC}"
        echo -e "${GREEN}Passed tests: ${PASSED_TESTS}${NC}"
        echo -e "${RED}Failed tests: ${FAILED_TESTS}${NC}"

        local success_rate=$((PASSED_TESTS * 100 / TOTAL_TESTS))
        echo -e "${CYAN}Success rate: ${success_rate}%${NC}"
    fi

    echo ""
    echo -e "${BLUE}Log files:${NC}"
    echo -e "  Main log: ${TEST_LOG}"
    if [ -f "$COVERAGE_LOG" ]; then
        echo -e "  Coverage log: ${COVERAGE_LOG}"
    fi

    # Overall result
    if [ "$FAILED_CATEGORIES" -eq 0 ]; then
        echo ""
        log_success "🎉 All test categories completed successfully!"
        if [ "$TOTAL_TESTS" -gt 0 ] && [ "$FAILED_TESTS" -eq 0 ]; then
            log_success "🎉 All individual tests passed!"
        fi
        return 0
    else
        echo ""
        log_error "❌ ${FAILED_CATEGORIES} test categor$( [ "$FAILED_CATEGORIES" -eq 1 ] && echo "y" || echo "ies" ) failed"
        return 1
    fi
}

print_usage() {
    echo "Usage: $0 [OPTIONS]"
    echo ""
    echo "Options:"
    echo "  -h, --help        Show this help message"
    echo "  -q, --quick       Run only unit tests (faster)"
    echo "  -c, --coverage    Skip coverage analysis"
    echo "  -v, --verbose     Verbose output"
    echo "  --unit-only       Run only unit tests"
    echo "  --error-only      Run only error handling tests"
    echo "  --integration-only Run only integration tests"
    echo "  --stress-only     Run only stress tests"
    echo ""
    echo "Examples:"
    echo "  $0                # Run all tests"
    echo "  $0 --quick        # Run quick tests only"
    echo "  $0 --unit-only    # Run unit tests only"
}

# Main execution
main() {
    local quick_mode=false
    local skip_coverage=false
    local verbose=false
    local specific_category=""

    # Parse command line arguments
    while [[ $# -gt 0 ]]; do
        case $1 in
            -h|--help)
                print_usage
                exit 0
                ;;
            -q|--quick)
                quick_mode=true
                shift
                ;;
            -c|--coverage)
                skip_coverage=true
                shift
                ;;
            -v|--verbose)
                verbose=true
                shift
                ;;
            --unit-only)
                specific_category="unit"
                shift
                ;;
            --error-only)
                specific_category="error"
                shift
                ;;
            --integration-only)
                specific_category="integration"
                shift
                ;;
            --stress-only)
                specific_category="stress"
                shift
                ;;
            *)
                log_error "Unknown option: $1"
                print_usage
                exit 1
                ;;
        esac
    done

    # Initialize
    mkdir -p "$TEMP_DIR"
    echo "WASM GDSII Parser Test Suite" > "$TEST_LOG"
    echo "Started: $(date)" >> "$TEST_LOG"
    echo "" >> "$TEST_LOG"

    log_header "WASM GDSII Parser Test Suite"
    echo "Started: $(date)"
    echo "Log file: $TEST_LOG"

    # Check environment
    check_environment

    # Build tests
    build_tests

    # Run tests based on mode
    if [ "$quick_mode" = true ]; then
        log_info "Running in quick mode (unit tests only)"
        run_test_category "unit" "Unit Tests" "test-unit"
    elif [ -n "$specific_category" ]; then
        log_info "Running only $specific_category tests"
        case "$specific_category" in
            "unit")
                run_test_category "unit" "Unit Tests" "test-unit"
                ;;
            "error")
                run_test_category "error" "Error Handling Tests" "test-error"
                ;;
            "integration")
                run_test_category "integration" "Integration Tests" "test-integration"
                ;;
            "stress")
                run_test_category "stress" "Stress Tests" "test-stress"
                ;;
        esac
    else
        # Run all test categories
        for category_info in "${TEST_CATEGORIES[@]}"; do
            IFS=':' read -r category_id category_name make_target <<< "$category_info"
            run_test_category "$category_id" "$category_name" "$make_target"

            # Small delay between categories
            sleep 1
        done

        # Run coverage analysis
        if [ "$skip_coverage" = false ]; then
            run_coverage_analysis
        fi
    fi

    # Print final summary
    print_summary
}

# Handle script interruption gracefully
trap 'log_warning "Test execution interrupted"; exit 130' INT TERM

# Run main function with all arguments
main "$@"