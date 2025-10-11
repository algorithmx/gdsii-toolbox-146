# GDS-STL-STEP Essential Test Suite

**Version:** 1.0  
**Created:** October 2025  
**Platform:** Octave-compatible (MATLAB-compatible)

---

## 📋 Overview

This is a streamlined, essential test suite for the GDS-STL-STEP conversion toolbox. It replaces 24+ scattered test files with a focused set of 5 core test suites covering the most critical functionality.

### Design Principles

✅ **Essential Coverage** - Tests only the most critical conversion pipeline components  
✅ **Fast Execution** - Complete suite runs in < 1 second  
✅ **Zero External Dependencies** - No Python, no STEP, pure Octave/MATLAB  
✅ **Clear Structure** - Organized by functional area, not by random naming  
✅ **Self-Contained** - All fixtures and utilities included  

---

## 🗂️ Test Suite Structure

```
new_tests/
├── run_tests.m              # Master test runner (Octave)
├── run_tests.sh             # Shell wrapper script
├── README.md                # This file
│
├── test_config_system.m     # Configuration & JSON parsing tests
├── test_extrusion_core.m    # 2D→3D polygon extrusion tests
├── test_file_export.m       # STL file generation tests
├── test_layer_extraction.m  # GDS layer extraction tests
├── test_basic_pipeline.m    # End-to-end conversion tests
│
├── fixtures/                # Test data and configurations
│   ├── configs/             # Layer configuration JSON files
│   │   └── test_basic.json
│   └── ...
│
├── test_output/             # Generated test output files
├── utils/                   # Shared test utilities (future)
├── optional/                # Optional enhancement tests (Phase 4)
└── archive/                 # Archived legacy tests (Phase 5)
```

---

## 🚀 Quick Start

### Running All Tests

**Option 1: Using Octave directly**
```bash
cd /path/to/gdsii-toolbox-146/Export/new_tests
octave --eval "run_tests()"
```

**Option 2: Using the shell wrapper**
```bash
cd /path/to/gdsii-toolbox-146/Export/new_tests
./run_tests.sh
```

**Option 3: From anywhere in the toolbox**
```bash
cd /path/to/gdsii-toolbox-146/Export
octave --eval "addpath('new_tests'); cd('new_tests'); run_tests()"
```

### Running Individual Tests

```octave
cd new_tests
octave --eval "test_config_system()"
octave --eval "test_extrusion_core()"
octave --eval "test_file_export()"
octave --eval "test_layer_extraction()"
octave --eval "test_basic_pipeline()"
```

---

## 📊 Test Coverage

### 1. **test_config_system** (4 tests)

Tests configuration file parsing and validation.

- ✅ Load basic JSON configuration
- ✅ Load real-world IHP SG13G2 configuration  
- ✅ Error handling for missing files
- ✅ Color parsing (hex → RGB conversion)

**Coverage:** `gds_read_layer_config()`, JSON parsing, layer mapping

---

### 2. **test_extrusion_core** (4 tests)

Tests 2D polygon extrusion to 3D solids.

- ✅ Simple rectangular extrusion
- ✅ Triangular polygon extrusion
- ✅ Volume calculation validation
- ✅ Error handling for invalid inputs

**Coverage:** `gds_extrude_polygon()`, vertex/face generation, volume calculation

---

### 3. **test_file_export** (3 tests)

Tests STL file generation (binary & ASCII).

- ✅ Binary STL export
- ✅ ASCII STL export & format verification
- ✅ Error handling for empty inputs

**Coverage:** `gds_write_stl()`, binary/ASCII format generation

---

### 4. **test_layer_extraction** (3 tests)

Tests extraction of polygon data from GDS structures.

- ✅ GDS structure creation
- ✅ Layer-by-layer polygon extraction
- ✅ Layer filtering (enabled layers only)

**Coverage:** `gds_layer_to_3d()`, GDS structure traversal, polygon extraction

---

### 5. **test_basic_pipeline** (2 tests)

Tests complete end-to-end GDS → STL conversion.

- ✅ Simple rectangle GDS → STL conversion
- ✅ Multi-layer stack GDS → STL conversion

**Coverage:** `gds_to_step()` (STL mode), full pipeline integration

---

## ✅ Expected Results

When all tests pass, you should see:

```
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
                    TEST SUMMARY
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

Overall Results:
  Total test suites: 5
  Total tests:       16
  Passed:            16
  Failed:            0
  Success rate:      100.0%
  Total time:        < 0.5 seconds

Test Suite Breakdown:
  ✓ test_config_system             4/4 passed
  ✓ test_extrusion_core            4/4 passed
  ✓ test_file_export               3/3 passed
  ✓ test_layer_extraction          3/3 passed
  ✓ test_basic_pipeline            2/2 passed

━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
                ✓ ALL TESTS PASSED
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
```

---

## 🔧 Requirements

- **Octave** (tested with 5.x+) or **MATLAB** (R2018b+)
- **gdsii-toolbox-146** installed and functional
- No external dependencies (Python, pythonOCC, etc.)

---

## 📁 Fixture Files

Test fixtures are located in `fixtures/` and include:

- **`configs/test_basic.json`** - Basic 3-layer test configuration
- **IHP SG13G2 configs** - Located in `../layer_configs/ihp_sg13g2.json`

All tests are designed to work with missing optional fixtures (they skip gracefully).

---

## 🧹 Cleaning Test Outputs

To clean generated test output files:

```bash
rm -rf test_output/*.stl test_output/*.gds
```

Or keep the directory structure:

```bash
find test_output -type f \( -name "*.stl" -o -name "*.gds" \) -delete
```

---

## 🚦 Test Status & Migration

This test suite is **Phase 2 Complete** of the test migration plan:

- ✅ **Phase 1:** Directory structure and backup (Complete)
- ✅ **Phase 2:** Essential test migration and validation (Complete)
- 🔄 **Phase 3:** Path fixes and documentation (Current)
- ⏳ **Phase 4:** Optional test migration (Future)
- ⏳ **Phase 5:** Archive and cleanup (Future)

### Migration from Old Tests

These new tests replace the following legacy files:

- `test_layer_functions.m` → `test_config_system.m` + `test_layer_extraction.m`
- `test_extrusion.m` → `test_extrusion_core.m`
- `test_section_4_4.m` → `test_file_export.m`
- `test_main_conversion.m` → `test_basic_pipeline.m`

**Old tests preserved in:** `../migration_temp/`

---

## 📝 Adding New Tests

To add a new test to the suite:

1. Create test file: `test_<functionality>.m`
2. Follow the existing test structure (see any test file as template)
3. Add test to `run_tests.m` in the test suite array
4. Update this README with test coverage information

**Test Template Structure:**

```octave
function results = test_<name>()
    % TEST_<NAME> - Brief description
    
    % Initialize
    fprintf('\n========================================\n');
    fprintf('Testing <Feature Name>\n');
    fprintf('========================================\n\n');
    
    % Setup paths
    script_dir = fileparts(mfilename('fullpath'));
    export_dir = fileparts(script_dir);
    toolbox_root = fileparts(export_dir);
    
    % Add required paths
    if isempty(strfind(path, export_dir))
        addpath(export_dir);
    end
    
    % Initialize results
    results = struct();
    results.total = 0;
    results.passed = 0;
    results.failed = 0;
    
    % Run tests
    results = run_test(results, 'Test name', @test_function);
    
    % Print summary
    fprintf('\n========================================\n');
    fprintf('<Name> Test Summary\n');
    fprintf('========================================\n');
    fprintf('Total tests:  %d\n', results.total);
    fprintf('Passed:       %d\n', results.passed);
    fprintf('Failed:       %d\n', results.failed);
    fprintf('Success rate: %.1f%%\n', 100 * results.passed / results.total);
    fprintf('========================================\n\n');
    
    if results.failed == 0
        fprintf('✓ ALL TESTS PASSED\n\n');
    end
end
```

---

## 🐛 Troubleshooting

### Path Issues

If you see "function not found" errors:

```octave
% Ensure you're in the correct directory
cd /path/to/gdsii-toolbox-146/Export/new_tests

% Or add paths manually
addpath('/path/to/gdsii-toolbox-146/Export');
addpath(genpath('/path/to/gdsii-toolbox-146/Basic'));
```

### Missing Fixtures

If tests skip due to missing fixtures, check:

```bash
ls -la fixtures/configs/test_basic.json
ls -la ../layer_configs/ihp_sg13g2.json
```

### Test Failures

1. Check that the main toolbox functions are working:
   ```octave
   which gds_read_layer_config
   which gds_extrude_polygon
   which gds_write_stl
   ```

2. Run individual tests to isolate issues:
   ```octave
   test_config_system()
   ```

3. Check for compatibility issues (Octave vs MATLAB syntax differences)

---

## 📚 Related Documentation

- **Migration Inventory:** `../migration_temp/MIGRATION_INVENTORY.md`
- **Main Toolbox README:** `../../README.md`
- **Layer Config Docs:** `../layer_configs/README.md`

---

## 👥 Authors & Maintenance

- **Created by:** WARP AI Agent, October 2025
- **Maintained by:** GDS-STL-STEP Toolbox Team
- **License:** Same as gdsii-toolbox-146

---

## 📈 Future Enhancements (Phase 4+)

Planned optional tests:

- **`optional/test_pdk_basic.m`** - Basic PDK layer set validation
- **`optional/test_advanced_pipeline.m`** - Advanced conversion options
- **`optional/test_performance.m`** - Performance benchmarking
- **`optional/test_visualization.m`** - Output visualization tests

---

**Last Updated:** October 5, 2025  
**Test Suite Version:** 1.0  
**Status:** Phase 3 - In Progress
