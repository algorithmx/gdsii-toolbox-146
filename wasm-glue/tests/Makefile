# Comprehensive Test Suite Makefile for WASM GDSII Parser
# Supports unit tests, integration tests, stress tests, and error handling

# Compiler settings
CC = gcc
CFLAGS = -Wall -Wextra -std=c99 -g -O0 -I../include -I../../Basic -I../../Basic/gdsio -I$(TEST_DIR)/wasm
LDFLAGS = -lm

# Source directories
SRC_DIR = ../src
INCLUDE_DIR = ../include
TEST_DIR = .
UNIT_DIR = $(TEST_DIR)/unit
ERROR_DIR = $(TEST_DIR)/error
STRESS_DIR = $(TEST_DIR)/stress
INTEGRATION_DIR = $(TEST_DIR)/integration
WASM_DIR = $(TEST_DIR)/wasm

# Source files (assuming they exist)
WASM_SOURCES = $(SRC_DIR)/wasm-element-cache.c
CORE_SOURCES = ../../Basic/gdsio/gdsio.c

# Test executables
UNIT_TESTS = $(UNIT_DIR)/test-memory-file $(UNIT_DIR)/test-library-cache
ERROR_TESTS = $(ERROR_DIR)/test-invalid-inputs
STRESS_TESTS = $(STRESS_DIR)/test-large-files
INTEGRATION_TESTS = $(INTEGRATION_DIR)/test-real-gdsii-files
COVERAGE_TOOL = $(TEST_DIR)/test-coverage-analysis

# All test executables
ALL_TESTS = $(UNIT_TESTS) $(ERROR_TESTS) $(STRESS_TESTS) $(INTEGRATION_TESTS) $(COVERAGE_TOOL)

# Default target
.PHONY: all
all: build-all

# Build all tests
.PHONY: build-all
build-all: $(ALL_TESTS)

# Build unit tests
.PHONY: unit-tests
unit-tests: $(UNIT_TESTS)

# Build error handling tests
.PHONY: error-tests
error-tests: $(ERROR_TESTS)

# Build stress tests
.PHONY: stress-tests
stress-tests: $(STRESS_TESTS)

# Build integration tests
.PHONY: integration-tests
integration-tests: $(INTEGRATION_TESTS)

# Build coverage tool
.PHONY: coverage-tool
coverage-tool: $(COVERAGE_TOOL)

# Individual test builds
$(UNIT_DIR)/test-memory-file: $(UNIT_DIR)/test-memory-file.c
	@echo "Building memory file unit tests..."
	@mkdir -p $(UNIT_DIR)
	$(CC) $(CFLAGS) -o $@ $< $(LDFLAGS)

$(UNIT_DIR)/test-library-cache: $(UNIT_DIR)/test-library-cache.c $(WASM_SOURCES) $(CORE_SOURCES)
	@echo "Building library cache unit tests..."
	@mkdir -p $(UNIT_DIR)
	$(CC) $(CFLAGS) -o $@ $< $(WASM_SOURCES) $(CORE_SOURCES) $(LDFLAGS)

$(ERROR_DIR)/test-invalid-inputs: $(ERROR_DIR)/test-invalid-inputs.c $(WASM_SOURCES) $(CORE_SOURCES)
	@echo "Building error handling tests..."
	@mkdir -p $(ERROR_DIR)
	$(CC) $(CFLAGS) -o $@ $< $(WASM_SOURCES) $(CORE_SOURCES) $(LDFLAGS)

$(STRESS_DIR)/test-large-files: $(STRESS_DIR)/test-large-files.c $(WASM_SOURCES) $(CORE_SOURCES)
	@echo "Building stress tests..."
	@mkdir -p $(STRESS_DIR)
	$(CC) $(CFLAGS) -o $@ $< $(WASM_SOURCES) $(CORE_SOURCES) $(LDFLAGS)

$(INTEGRATION_DIR)/test-real-gdsii-files: $(INTEGRATION_DIR)/test-real-gdsii-files.c $(WASM_SOURCES) $(CORE_SOURCES)
	@echo "Building integration tests..."
	@mkdir -p $(INTEGRATION_DIR)
	$(CC) $(CFLAGS) -o $@ $< $(WASM_SOURCES) $(CORE_SOURCES) $(LDFLAGS)

$(COVERAGE_TOOL): $(TEST_DIR)/test-coverage-analysis.c
	@echo "Building coverage analysis tool..."
	$(CC) $(CFLAGS) -o $@ $< $(LDFLAGS)

# Run all tests
.PHONY: test
test: test-all

.PHONY: test-all
test-all: build-all
	@echo "Running comprehensive test suite..."
	@echo "=================================="
	./run-tests.sh

# Run specific test categories
.PHONY: test-unit
test-unit: unit-tests
	@echo "Running unit tests..."
	@echo "===================="
	@for test in $(UNIT_TESTS); do \
		echo "Running $$test..."; \
		./$$test || exit 1; \
		echo ""; \
	done

.PHONY: test-error
test-error: error-tests
	@echo "Running error handling tests..."
	@echo "==============================="
	@for test in $(ERROR_TESTS); do \
		echo "Running $$test..."; \
		./$$test || exit 1; \
		echo ""; \
	done

.PHONY: test-stress
test-stress: stress-tests
	@echo "Running stress tests..."
	@echo "======================"
	@for test in $(STRESS_TESTS); do \
		echo "Running $$test..."; \
		./$$test || exit 1; \
		echo ""; \
	done

.PHONY: test-integration
test-integration: integration-tests
	@echo "Running integration tests..."
	@echo "==========================="
	@for test in $(INTEGRATION_TESTS); do \
		echo "Running $$test..."; \
		./$$test || exit 1; \
		echo ""; \
	done

.PHONY: coverage
coverage: coverage-tool
	@echo "Running test coverage analysis..."
	@echo "================================="
	./$(COVERAGE_TOOL)

# Quick test (unit tests only)
.PHONY: test-quick
test-quick: unit-tests
	@echo "Running quick tests (unit tests only)..."
	@echo "======================================="
	@for test in $(UNIT_TESTS); do \
		echo "Running $$test..."; \
		./$$test || exit 1; \
	done

# Continuous integration target
.PHONY: ci
ci: clean build-all test-all coverage
	@echo "CI pipeline completed successfully!"

# Development targets
.PHONY: dev
dev: unit-tests error-tests
	@echo "Running development tests (unit + error)..."
	@echo "=========================================="
	@for test in $(UNIT_TESTS) $(ERROR_TESTS); do \
		echo "Running $$test..."; \
		./$$test || exit 1; \
	done

# Clean targets
.PHONY: clean
clean:
	@echo "Cleaning test binaries..."
	rm -f $(ALL_TESTS)
	@echo "Cleaning test logs..."
	rm -f *.log
	rm -f */*.log

.PHONY: clean-all
clean-all: clean
	@echo "Cleaning all generated files..."
	rm -f test-results.txt
	rm -f coverage-report.txt
	rm -f *.tmp

# Help target
.PHONY: help
help:
	@echo "WASM GDSII Parser Test Suite"
	@echo "============================"
	@echo ""
	@echo "Build targets:"
	@echo "  all, build-all      Build all tests"
	@echo "  unit-tests          Build unit tests only"
	@echo "  error-tests         Build error handling tests only"
	@echo "  stress-tests        Build stress tests only"
	@echo "  integration-tests   Build integration tests only"
	@echo "  coverage-tool       Build coverage analysis tool"
	@echo ""
	@echo "Test targets:"
	@echo "  test, test-all      Run all tests"
	@echo "  test-unit           Run unit tests only"
	@echo "  test-error          Run error handling tests only"
	@echo "  test-stress         Run stress tests only"
	@echo "  test-integration    Run integration tests only"
	@echo "  test-quick          Run unit tests only (faster)"
	@echo "  coverage            Run coverage analysis"
	@echo "  dev                 Run development tests (unit + error)"
	@echo "  ci                  Run full CI pipeline"
	@echo ""
	@echo "Utility targets:"
	@echo "  clean               Clean test binaries"
	@echo "  clean-all           Clean all generated files"
	@echo "  help                Show this help message"
	@echo ""
	@echo "Examples:"
	@echo "  make test-quick     # Quick development test"
	@echo "  make test-unit      # Unit tests only"
	@echo "  make ci             # Full CI pipeline"

# Create test directories
.PHONY: setup-dirs
setup-dirs:
	@echo "Creating test directories..."
	@mkdir -p $(UNIT_DIR) $(ERROR_DIR) $(STRESS_DIR) $(INTEGRATION_DIR) $(WASM_DIR)

# Check dependencies
.PHONY: check-deps
check-deps:
	@echo "Checking dependencies..."
	@which $(CC) > /dev/null || (echo "Error: $(CC) not found" && exit 1)
	@echo "✓ Compiler found: $(CC)"
	@test -d $(INCLUDE_DIR) || (echo "Warning: Include directory not found: $(INCLUDE_DIR)" && exit 1)
	@echo "✓ Include directory found"
	@test -f $(INCLUDE_DIR)/mem-file.h || echo "Warning: mem-file.h not found"
	@test -f $(SRC_DIR)/wasm-element-cache.c || echo "Warning: wasm-element-cache.c not found"

# Verify source files exist (optional)
.PHONY: verify-sources
verify-sources:
	@echo "Verifying source files..."
	@for src in $(WASM_SOURCES); do \
		if [ -f "$$src" ]; then \
			echo "✓ $$src"; \
		else \
			echo "✗ $$src (missing)"; \
		fi; \
	done

# Print configuration
.PHONY: config
config:
	@echo "Test Suite Configuration:"
	@echo "========================"
	@echo "CC: $(CC)"
	@echo "CFLAGS: $(CFLAGS)"
	@echo "LDFLAGS: $(LDFLAGS)"
	@echo "Source dir: $(SRC_DIR)"
	@echo "Include dir: $(INCLUDE_DIR)"
	@echo "Test dir: $(TEST_DIR)"
	@echo ""
	@echo "Unit tests: $(UNIT_TESTS)"
	@echo "Error tests: $(ERROR_TESTS)"
	@echo "Stress tests: $(STRESS_TESTS)"
	@echo "Integration tests: $(INTEGRATION_TESTS)"