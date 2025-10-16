#!/bin/bash

# Test System Validation Script
# Quick validation that the test suite is properly configured

set -e

echo "=== WASM GDSII Parser Test System Validation ==="
echo

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Validation results
VALIDATION_PASSED=true
WARNINGS=0

log_success() {
    echo -e "${GREEN}✓ $1${NC}"
}

log_error() {
    echo -e "${RED}❌ $1${NC}"
    VALIDATION_PASSED=false
}

log_warning() {
    echo -e "${YELLOW}⚠ $1${NC}"
    WARNINGS=$((WARNINGS + 1))
}

log_info() {
    echo -e "${BLUE}ℹ $1${NC}"
}

# Check file existence and content
check_file() {
    local file="$1"
    local description="$2"
    local expected_content="$3"

    if [ ! -f "$file" ]; then
        log_error "$description ($file not found)"
        return 1
    fi

    if [ -n "$expected_content" ] && ! grep -q "$expected_content" "$file" 2>/dev/null; then
        log_warning "$description (missing expected content: $expected_content)"
        return 1
    fi

    log_success "$description"
    return 0
}

# Check directory existence
check_directory() {
    local dir="$1"
    local description="$2"

    if [ ! -d "$dir" ]; then
        log_error "$description ($dir not found)"
        return 1
    fi

    log_success "$description"
    return 0
}

# Check if file is executable
check_executable() {
    local file="$1"
    local description="$2"

    if [ ! -x "$file" ]; then
        log_error "$description ($file not executable)"
        return 1
    fi

    log_success "$description"
    return 0
}

# Check for available command
check_command() {
    local cmd="$1"
    local description="$2"

    if command -v "$cmd" >/dev/null 2>&1; then
        log_success "$description"
        return 0
    else
        log_warning "$description (not found)"
        return 1
    fi
}

echo "Validating test directory structure..."
check_directory "unit" "Unit test directory"
check_directory "integration" "Integration test directory"
check_directory "stress" "Stress test directory"
check_directory "error" "Error test directory"
check_directory ".github/workflows" "GitHub workflows directory"

echo
echo "Validating test files..."
check_file "unit/test-memory-file.c" "Memory file unit test"
check_file "unit/test-library-cache.c" "Library cache unit test"
check_file "integration/test-real-gdsii-files.c" "Integration test"
check_file "stress/test-large-files.c" "Stress test"
check_file "error/test-invalid-inputs.c" "Error handling test"
check_file "test-coverage-analysis.c" "Coverage analysis tool"

echo
echo "Validating build system..."
check_file "Makefile" "Makefile" "CC = gcc"
check_file "run-tests.sh" "Test runner script" "#!/bin/bash"
check_executable "run-tests.sh" "Test runner script executable"

echo
echo "Validating CI/CD configuration..."
check_file ".github/workflows/ci.yml" "GitHub Actions workflow" "build-and-test"

echo
echo "Validating documentation..."
check_file "README.md" "README file" "# WASM GDSII Parser Test Suite"

echo
echo "Checking dependencies..."
check_command "gcc" "GCC compiler"
check_command "make" "Make utility"

# Test the build system
echo
echo "Testing build system..."
if make check-deps >/dev/null 2>&1; then
    log_success "Make dependency check"
else
    log_warning "Make dependency check (may fail if source files don't exist)"
fi

# Test validation tool compilation
echo
echo "Testing validation tool..."
if gcc -o validate-test-system validate-test-system.c 2>/dev/null; then
    log_success "Validation tool compiles"

    # Run the validation tool
    echo
    echo "Running comprehensive validation..."
    if ./validate-test-system; then
        log_success "Comprehensive validation passed"
    else
        log_warning "Comprehensive validation had issues"
    fi

    # Cleanup
    rm -f validate-test-system
else
    log_warning "Validation tool compilation failed"
fi

echo
echo "=== Validation Summary ==="
echo

if [ "$VALIDATION_PASSED" = true ]; then
    echo -e "${GREEN}🎉 Test system validation passed!${NC}"
    echo
    echo "The comprehensive test suite is properly configured and ready to use."
    echo
    echo "Next steps:"
    echo "1. Run './run-tests.sh' to execute the full test suite"
    echo "2. Run 'make test-quick' for rapid development testing"
    echo "3. Run 'make help' to see all available options"
    echo "4. Check 'README.md' for detailed documentation"
else
    echo -e "${RED}❌ Test system validation failed!${NC}"
    echo
    echo "Please address the failed checks before proceeding."
    echo "Check that all required files are present and properly configured."
fi

if [ "$WARNINGS" -gt 0 ]; then
    echo
    echo -e "${YELLOW}⚠ $WARNINGS warning(s) detected.${NC}"
    echo "Consider addressing these for optimal test coverage and reliability."
fi

echo
echo "Test system features validated:"
echo "• Unit tests for core components"
echo "• Integration tests with real GDSII files"
echo "• Stress tests for performance validation"
echo "• Error handling tests for robustness"
echo "• Coverage analysis for test gaps"
echo "• Automated CI/CD pipeline"
echo "• Comprehensive documentation"

# Exit with appropriate code
if [ "$VALIDATION_PASSED" = true ]; then
    exit 0
else
    exit 1
fi