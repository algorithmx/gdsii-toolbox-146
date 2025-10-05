# Test Suite Organization Plan - GDS-STL-STEP Conversion Module

**Date:** October 2025  
**Project:** gdsii-toolbox-146 Export Module  
**Purpose:** Design a well-organized, full-featured test suite based on analysis of existing tests

---

## Executive Summary

This document outlines the recommended organization for cherry-picking valuable tests and reorganizing them into a comprehensive, maintainable test suite. The plan preserves all high-value test logic while improving structure, eliminating duplication, and providing clear test execution workflows.

---

## Proposed Directory Structure

```
Export/
├── tests/                           # NEW: Consolidated test directory
│   ├── run_tests.m                 # NEW: Master test runner
│   ├── test_config.m               # NEW: Test configuration and utilities
│   │
│   ├── unit/                       # Unit tests (individual components)
│   │   ├── test_config_parser.m
│   │   ├── test_layer_extraction.m
│   │   ├── test_extrusion_engine.m
│   │   └── test_file_writers.m
│   │
│   ├── integration/                # Integration tests (component interaction)
│   │   ├── test_basic_pipeline.m
│   │   ├── test_advanced_pipeline.m
│   │   └── test_error_handling.m
│   │
│   ├── functional/                 # Feature-specific tests
│   │   ├── test_boolean_operations.m
│   │   ├── test_via_merging.m
│   │   └── test_geometry_validation.m
│   │
│   ├── pdk/                        # Real-world PDK tests
│   │   ├── test_ihp_sg13g2.m
│   │   └── test_basic_pdk_workflow.m
│   │
│   ├── performance/                # Performance benchmarks
│   │   └── test_performance_benchmarks.m
│   │
│   ├── fixtures/                   # Test data and configurations
│   │   ├── configs/
│   │   │   ├── test_basic.json
│   │   │   ├── test_multilayer.json
│   │   │   └── ihp_sg13g2_test.json
│   │   ├── gds_files/
│   │   │   └── (programmatically generated)
│   │   └── expected_outputs/
│   │       └── (reference files for validation)
│   │
│   └── utils/                      # Test utilities and helpers
│       ├── test_assertion_utils.m
│       ├── test_gds_generation.m
│       ├── test_file_validation.m
│       └── test_reporting.m
│
├── [existing files remain unchanged]
└── legacy_tests/                   # MOVED: Original test files for reference
    ├── test_basic_single.m
    ├── test_ihp_sg13g2_pdk_sets.m
    └── [other original test files]
```

---

## Test Suite Components

### 1. Master Test Runner: `run_tests.m`

**Purpose:** Single entry point for all test execution with flexible options

**Features:**
- Run all tests or specific categories
- Comprehensive reporting with timing
- Dependency checking and graceful degradation
- Test result summary and statistics
- Export results to files (CSV, JSON)

**Usage Examples:**
```matlab
% Run all tests
run_tests();

% Run specific category
run_tests('unit');
run_tests('pdk');

% Run with options
run_tests('all', 'verbose', true, 'export_results', 'test_results.json');

% Run specific tests
run_tests('integration', 'tests', {'test_basic_pipeline', 'test_error_handling'});
```

### 2. Test Configuration: `test_config.m`

**Purpose:** Centralized test configuration and environment setup

**Features:**
- Path management and validation
- Test data location configuration
- Default test parameters
- Environment compatibility checking
- Shared test utilities

### 3. Unit Tests Directory: `unit/`

#### `test_config_parser.m` ⭐ **HIGH PRIORITY**
- **Source:** `test_layer_functions.m` (Tests 1-3, error handling)
- **Coverage:** JSON parsing, validation, color processing, layer mapping
- **Tests:** 8 focused unit tests
- **Dependencies:** Minimal (JSON files only)

#### `test_layer_extraction.m` ⭐ **HIGH PRIORITY** 
- **Source:** `test_layer_functions.m` (Tests 4-6)
- **Coverage:** GDS structure creation, layer extraction, filtering
- **Tests:** 6 comprehensive tests
- **Dependencies:** gdsii-toolbox-146 basic functions

#### `test_extrusion_engine.m` ⭐ **HIGH PRIORITY**
- **Source:** `test_extrusion.m` (all 10 tests)
- **Coverage:** 2D to 3D extrusion, geometric validation, edge cases
- **Tests:** 10 detailed tests
- **Dependencies:** Core extrusion function

#### `test_file_writers.m` ⭐ **HIGH PRIORITY**
- **Source:** `test_section_4_4.m` (Tests 1-6)
- **Coverage:** STL/STEP export, format options, error handling
- **Tests:** 6 comprehensive tests
- **Dependencies:** Optional (Python for STEP)

### 4. Integration Tests Directory: `integration/`

#### `test_basic_pipeline.m` ⭐ **HIGH PRIORITY**
- **Source:** `test_main_conversion.m`, `test_gds_to_step.m` (basic tests)
- **Coverage:** End-to-end conversion, simple scenarios
- **Tests:** 5 pipeline tests
- **Dependencies:** Full toolchain

#### `test_advanced_pipeline.m` ⭐ **MEDIUM PRIORITY**
- **Source:** `test_gds_to_step.m` (advanced scenarios)
- **Coverage:** Complex multi-layer, windowing, filtering
- **Tests:** 8 advanced integration tests
- **Dependencies:** Full toolchain

#### `test_error_handling.m` ⭐ **MEDIUM PRIORITY**
- **Source:** Various error handling tests across files
- **Coverage:** Invalid inputs, missing files, dependency failures
- **Tests:** 10 error condition tests
- **Dependencies:** Controlled error scenarios

### 5. Functional Tests Directory: `functional/`

#### `test_boolean_operations.m` ⭐ **MEDIUM PRIORITY**
- **Source:** `test_boolean_operations.m` (refactored)
- **Coverage:** Union, intersection, difference operations
- **Tests:** 8 Boolean operation tests
- **Dependencies:** 3D Boolean functions

#### `test_via_merging.m` ⭐ **HIGH PRIORITY** (for semiconductor workflows)
- **Source:** `test_via_merge.m` (refactored)
- **Coverage:** Material-based merging, vertical continuity
- **Tests:** 4 via merging tests
- **Dependencies:** Advanced merging functions

#### `test_geometry_validation.m` ⭐ **MEDIUM PRIORITY**
- **Source:** `test_tower_functionality.m` (geometric tests)
- **Coverage:** Multi-layer stacking, geometric correctness
- **Tests:** 6 geometry validation tests
- **Dependencies:** Full pipeline

### 6. PDK Tests Directory: `pdk/`

#### `test_ihp_sg13g2.m` ⭐ **VERY HIGH PRIORITY**
- **Source:** `test_ihp_sg13g2_pdk_sets.m` (refactored)
- **Coverage:** Real-world semiconductor PDK workflow
- **Tests:** 12 PDK tests across complexity levels
- **Dependencies:** IHP SG13G2 test data

#### `test_basic_pdk_workflow.m` ⭐ **HIGH PRIORITY**
- **Source:** `test_basic_set_only.m` (simplified)
- **Coverage:** Simple PDK workflow for debugging
- **Tests:** 3 basic PDK tests
- **Dependencies:** Basic PDK test data

### 7. Performance Tests Directory: `performance/`

#### `test_performance_benchmarks.m` ⭐ **MEDIUM PRIORITY**
- **Source:** Performance metrics from various tests
- **Coverage:** Timing, memory usage, scalability
- **Tests:** 5 performance benchmarks
- **Dependencies:** Large test datasets

### 8. Utilities Directory: `utils/`

#### Common Test Utilities
- **`test_assertion_utils.m`** - Standardized assertion functions
- **`test_gds_generation.m`** - Programmatic GDS file creation
- **`test_file_validation.m`** - Output file validation helpers
- **`test_reporting.m`** - Consistent test result reporting

---

## Cherry-Picking Strategy

### Priority 1: Essential Tests (Must Implement First)
1. **`test_config_parser.m`** - Foundation for all other tests
2. **`test_extrusion_engine.m`** - Core 3D conversion functionality  
3. **`test_file_writers.m`** - Output validation capability
4. **`test_basic_pipeline.m`** - End-to-end workflow verification
5. **`test_ihp_sg13g2.m`** - Real-world validation

**Estimated Implementation:** 2-3 days
**Test Coverage:** ~60% of critical functionality

### Priority 2: Extended Coverage (Second Phase)
6. **`test_layer_extraction.m`** - Complete foundation testing
7. **`test_via_merging.m`** - Advanced semiconductor features
8. **`test_basic_pdk_workflow.m`** - Simplified PDK testing
9. **`test_advanced_pipeline.m`** - Complex integration scenarios

**Estimated Implementation:** 2-3 additional days
**Test Coverage:** ~85% of functionality

### Priority 3: Complete Suite (Third Phase)
10. **`test_boolean_operations.m`** - Advanced 3D operations
11. **`test_error_handling.m`** - Comprehensive error testing
12. **`test_geometry_validation.m`** - Specialized geometric tests
13. **`test_performance_benchmarks.m`** - Performance validation

**Estimated Implementation:** 2-3 additional days
**Test Coverage:** ~95% of functionality

---

## Test Data Management

### Configuration Files (`fixtures/configs/`)
```
test_basic.json                 # 3-layer basic test config
test_multilayer.json           # Complex multi-layer stack
test_via_config.json          # VIA-specific configuration
ihp_sg13g2_test.json          # Simplified IHP config for testing
test_error_config.json        # Intentionally malformed for error testing
```

### GDS Files (`fixtures/gds_files/`)
- **Programmatically Generated:** Tests create GDS files as needed
- **Advantages:** No external dependencies, version controlled, customizable
- **Examples:** Simple rectangles, multi-layer stacks, hierarchical structures

### Expected Outputs (`fixtures/expected_outputs/`)
- **Reference STL/STEP files** for validation
- **Generated from known-good test runs**
- **Binary comparison for regression testing**

---

## Implementation Details

### Test Standardization

#### Consistent Test Function Structure
```matlab
function results = test_<component>_<functionality>()
    % Test <component> <functionality>
    % 
    % RETURNS:
    %   results - struct with test results and statistics
    
    fprintf('\n=== Testing %s ===\n', mfilename);
    
    % Initialize results
    results = init_test_results(mfilename);
    
    % Test 1: Description
    results = run_test_case(results, 'test_name', @test_function_1);
    
    % Test 2: Description  
    results = run_test_case(results, 'test_name', @test_function_2);
    
    % ... more tests
    
    % Summary
    print_test_summary(results);
end

function test_result = test_function_1()
    % Individual test implementation
    try
        % Test logic here
        assert(condition, 'Error message');
        test_result = create_test_result(true, 'Test passed');
    catch ME
        test_result = create_test_result(false, ME.message);
    end
end
```

#### Standardized Assertion Functions
```matlab
% In test_assertion_utils.m
function assert_file_exists(filename, message)
function assert_approximately_equal(actual, expected, tolerance, message)
function assert_valid_gds_library(glib, message)
function assert_valid_stl_file(filename, message)
function assert_valid_step_file(filename, message)
```

### Master Test Runner Implementation

#### Core Functionality
```matlab
function results = run_tests(varargin)
    % Parse options
    opts = parse_test_options(varargin{:});
    
    % Initialize test environment
    setup_test_environment(opts);
    
    % Discover and run tests
    tests_to_run = discover_tests(opts.category, opts.tests);
    results = execute_tests(tests_to_run, opts);
    
    % Generate reports
    generate_test_reports(results, opts);
    
    % Cleanup
    cleanup_test_environment(opts);
end
```

#### Reporting Features
- **Console output** with real-time progress
- **HTML report** with detailed results and timing
- **JSON export** for integration with other tools
- **CSV summary** for spreadsheet analysis
- **Test coverage metrics**

---

## Migration Strategy

### Phase 1: Infrastructure Setup
1. Create new directory structure
2. Implement master test runner skeleton
3. Create test utilities and assertion functions
4. Set up configuration management

### Phase 2: Priority 1 Tests
1. Extract and refactor high-priority tests
2. Implement standardized test structure
3. Create basic test data fixtures
4. Validate core functionality

### Phase 3: Extended Coverage
1. Add Priority 2 tests with full features
2. Implement performance benchmarking
3. Add comprehensive error testing
4. Create advanced test fixtures

### Phase 4: Legacy Transition
1. Move original test files to `legacy_tests/`
2. Update documentation and README files
3. Validate complete test coverage
4. Performance optimization

---

## Validation and Quality Assurance

### Test Suite Validation
- **Coverage Analysis:** Ensure no functionality gaps
- **Regression Testing:** Validate against known-good outputs
- **Performance Baseline:** Establish timing benchmarks
- **Cross-Platform Testing:** Verify Octave/MATLAB compatibility

### Maintenance Strategy
- **Regular Review:** Quarterly test suite review
- **Test Data Updates:** Keep PDK data current
- **Performance Monitoring:** Track test execution times
- **Documentation Updates:** Keep test documentation current

---

## Expected Benefits

### For Developers
- **Clear test organization** makes finding relevant tests easy
- **Standardized patterns** reduce time to write new tests
- **Comprehensive coverage** provides confidence in changes
- **Performance benchmarks** help optimize code

### For Users
- **Single test command** to validate installation
- **Clear pass/fail indicators** for troubleshooting
- **Real-world test scenarios** validate actual usage
- **Documentation integration** explains test purposes

### For Maintenance
- **Elimination of duplication** reduces maintenance burden
- **Centralized configuration** simplifies updates
- **Modular structure** allows incremental improvements
- **Legacy preservation** maintains historical test value

---

## Success Metrics

### Quantitative Measures
- **Test Execution Time:** < 10 minutes for full suite
- **Test Coverage:** > 90% of core functionality
- **Pass Rate:** > 95% on clean installations
- **Performance Regression:** < 5% slowdown tolerance

### Qualitative Measures  
- **Ease of Use:** New users can run tests without setup
- **Clarity:** Test failures provide actionable information
- **Maintainability:** Adding new tests follows clear patterns
- **Reliability:** Consistent results across environments

---

## Conclusion

This reorganization plan preserves the valuable test logic from the existing scattered test files while providing a clean, maintainable structure. The phased implementation approach allows for incremental migration while maintaining functionality throughout the process.

The resulting test suite will provide:
- ✅ **Comprehensive validation** of all conversion pipeline components
- ✅ **Real-world scenario testing** with PDK data
- ✅ **Easy execution and reporting** for developers and users
- ✅ **Maintainable structure** for long-term development
- ✅ **Performance monitoring** for optimization opportunities

**Next Steps:**
1. Begin Phase 1 infrastructure implementation
2. Implement Priority 1 tests for core functionality validation
3. Gradually migrate remaining tests while preserving coverage
4. Validate complete test suite against existing functionality

---

**Implementation Timeline:** 6-8 days total
- Phase 1: 1-2 days (infrastructure)
- Phase 2: 2-3 days (Priority 1 tests)
- Phase 3: 2-3 days (extended coverage)
- Phase 4: 1 day (cleanup and validation)