# WASM GDSII Parser Test Suite

Comprehensive testing framework for the WASM GDSII parser wrapper, including unit tests, integration tests, stress tests, and error handling validation.

## Overview

This test suite provides thorough validation of the WASM GDSII parser functionality across multiple dimensions:

- **Unit Tests**: Individual component testing
- **Integration Tests**: Real-world GDSII file validation
- **Stress Tests**: Performance and memory efficiency testing
- **Error Handling Tests**: Invalid input and edge case validation
- **Coverage Analysis**: Test coverage gap identification

## Directory Structure

```
tests/
├── Makefile                 # Build system for all tests
├── run-tests.sh            # Main test runner script
├── README.md               # This file
├── test-coverage-analysis.c # Coverage analysis tool
├── unit/                   # Unit tests
│   ├── test-memory-file.c
│   └── test-library-cache.c
├── integration/            # Integration tests
│   └── test-real-gdsii-files.c
├── stress/                 # Performance/stress tests
│   └── test-large-files.c
├── error/                  # Error handling tests
│   └── test-invalid-inputs.c
└── .github/workflows/      # CI/CD configuration
    └── ci.yml
```

## Quick Start

### Prerequisites

- GCC or Clang compiler
- Make utility
- Standard C library development files

### Running Tests

1. **All Tests (Recommended)**
   ```bash
   cd tests
   ./run-tests.sh
   ```

2. **Quick Development Tests**
   ```bash
   ./run-tests.sh --quick
   # or
   make test-quick
   ```

3. **Specific Test Categories**
   ```bash
   # Unit tests only
   ./run-tests.sh --unit-only
   make test-unit

   # Error handling tests only
   ./run-tests.sh --error-only
   make test-error

   # Integration tests only
   ./run-tests.sh --integration-only
   make test-integration

   # Stress tests only
   ./run-tests.sh --stress-only
   make test-stress
   ```

4. **Coverage Analysis**
   ```bash
   make coverage
   ```

## Test Categories

### Unit Tests (`unit/`)

**test-memory-file.c**: Tests memory file abstraction layer
- File opening/closing operations
- Read/seek/tell functionality
- Big-endian data reading
- GDSII header parsing
- Error conditions and edge cases

**test-library-cache.c**: Tests library cache management
- Cache creation and destruction
- Structure parsing and validation
- Element access functions
- Polygon data handling
- Lazy loading functionality

### Integration Tests (`integration/`)

**test-real-gdsii-files.c**: Tests with actual GDSII files
- File discovery and validation
- Real-world GDSII file processing
- Sample file generation and testing
- Integration workflow validation

### Stress Tests (`stress/`)

**test-large-files.c**: Performance and memory testing
- Large file handling (1000+ structures)
- Memory efficiency validation
- Performance benchmarking
- Repeated operations stress testing
- Complex hierarchy processing

### Error Handling Tests (`error/`)

**test-invalid-inputs.c**: Comprehensive error validation
- NULL pointer handling
- Invalid index testing
- Memory allocation failure scenarios
- Corrupted data handling
- Boundary condition testing

## Build System

The Makefile provides comprehensive build and test targets:

### Build Targets
```bash
make build-all          # Build all tests
make unit-tests         # Build unit tests only
make error-tests        # Build error tests only
make stress-tests       # Build stress tests only
make integration-tests  # Build integration tests only
make coverage-tool      # Build coverage analysis tool
```

### Test Targets
```bash
make test               # Run all tests
make test-unit          # Run unit tests only
make test-error         # Run error tests only
make test-stress        # Run stress tests only
make test-integration   # Run integration tests only
make test-quick         # Run unit tests only (faster)
```

### Utility Targets
```bash
make clean              # Clean test binaries
make clean-all          # Clean all generated files
make help               # Show help message
make config             # Show build configuration
make check-deps         # Check dependencies
```

## CI/CD Integration

The test suite includes GitHub Actions workflow for automated testing:

### Triggers
- Push to main/develop branches
- Pull requests to main/develop branches
- Daily scheduled runs

### Test Matrix
- **Compilers**: GCC, Clang
- **Build Types**: Debug, Release
- **Platforms**: Ubuntu Linux

### CI Pipeline Stages
1. **Build**: Compile all test targets
2. **Unit Tests**: Validate core functionality
3. **Error Tests**: Verify error handling
4. **Integration Tests**: Test real-world scenarios
5. **Stress Tests**: Performance validation (with timeout)
6. **Coverage Analysis**: Test coverage assessment
7. **Memory Check**: Valgrind leak detection
8. **Code Quality**: Static analysis and formatting
9. **Security Scan**: Basic security validation

## Test Coverage

The test suite covers 46 functions across the WASM wrapper:

### High Priority (24 functions)
- Core memory file operations
- Library cache management
- Structure and element access
- Polygon data handling

### Medium Priority (15 functions)
- Property access functions
- Advanced element queries
- Cache optimization functions

### Low Priority (7 functions)
- Utility and helper functions
- Debugging functions

## Output and Logging

### Test Results
- **Main Log**: `test-results-YYYYMMDD-HHMMSS.log`
- **Coverage Log**: `coverage-report-YYYYMMDD-HHMMSS.log`
- **Console Output**: Colored status indicators

### Log Format
```
[SUCCESS] Test completed successfully
[ERROR]   Test failed
[WARNING] Non-critical issue
[INFO]    Informational message
```

## Performance Benchmarks

Stress tests provide performance metrics:

- **File Parsing**: structures/ms, elements/ms
- **Memory Usage**: KB/MB consumption tracking
- **Cache Operations**: creation/access timing
- **Large File Handling**: scalability validation

## Error Handling Validation

Comprehensive testing of error conditions:

- **Invalid Inputs**: NULL pointers, negative indices
- **Memory Issues**: Allocation failures, buffer overflows
- **Corrupted Data**: Malformed GDSII files
- **Boundary Conditions**: Edge cases and limits
- **Concurrent Access**: Thread-safety validation

## Development Workflow

### Local Development
1. Make changes to source code
2. Run quick tests: `make test-quick`
3. Run specific category: `make test-unit`
4. Run full suite: `./run-tests.sh`
5. Check coverage: `make coverage`

### Before Commit
1. Run full test suite: `./run-tests.sh`
2. Check for memory leaks (if Valgrind available)
3. Verify code quality: `make check-deps`
4. Review test logs for any warnings

### Continuous Integration
1. Push to feature branch
2. CI runs automated tests
3. Review test results in GitHub Actions
4. Address any failures before merge

## Troubleshooting

### Common Issues

**Build Failures**:
```bash
# Check dependencies
make check-deps

# Clean and rebuild
make clean-all
make build-all
```

**Test Timeouts**:
```bash
# Run tests individually
make test-unit
make test-error

# Skip stress tests if needed
./run-tests.sh --unit-only --error-only
```

**Memory Issues**:
```bash
# Check for memory leaks (requires Valgrind)
valgrind --leak-check=full ./unit/test-memory-file
```

**Missing Files**:
- Ensure source files exist in `../src/`
- Check include paths in `../include/`
- Verify GDSII test data availability

## Contributing

### Adding New Tests

1. Create test file in appropriate directory
2. Follow existing test patterns and naming
3. Add build target to Makefile
4. Update CI configuration if needed
5. Document test purpose and coverage

### Test Naming Conventions

- Files: `test-[component].c`
- Functions: `test_[feature]()`
- Assertions: `TEST_ASSERT(condition, "message")`
- Categories: unit/, error/, stress/, integration/

### Coverage Guidelines

- Aim for >90% code coverage
- Test all error paths
- Include boundary conditions
- Validate performance characteristics
- Test memory management thoroughly

## License

This test suite follows the same license as the main GDSII toolbox project.