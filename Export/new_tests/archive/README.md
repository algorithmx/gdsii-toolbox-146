# Archived Tests

**Last Updated:** October 5, 2025  
**Purpose:** Preserve valuable but non-essential test code for reference

---

## Overview

This directory contains test files that were **not migrated** to the new essential or optional test suites, but are preserved for historical reference and potential future use. These tests represent valuable work but either:

- Test experimental features not yet in production
- Have external dependencies (e.g., pythonOCC for Boolean operations)
- Cover specialized scenarios not needed for core validation
- Are superseded by newer, more focused tests

**Important:** These archived tests are **NOT maintained** and may not work with the current codebase without modification.

---

## Archived Test Files

### 1. **test_boolean_operations.m**

**Size:** ~16 KB  
**Purpose:** Test 3D Boolean operations (union, intersection, difference)

**Why Archived:**
- Requires pythonOCC dependency (external Python library)
- Experimental feature not yet in production use
- Complex setup requirements
- Not essential for core GDS-to-3D conversion validation

**Coverage:**
- Boolean union of multiple solids
- Boolean intersection operations
- Boolean difference/subtraction
- Complex geometric combinations

**Potential Use:**
- If Boolean operations feature is implemented in future
- For advanced solid modeling research
- Reference implementation for 3D operations

---

### 2. **test_integration_4_6_to_4_10.m**

**Size:** ~25 KB  
**Purpose:** Integration tests for Sections 4.6-4.10 of implementation plan

**Why Archived:**
- Tests incomplete/experimental features
- Complex integration test covering multiple features
- Some features not yet fully implemented
- Overlaps with other more focused tests

**Coverage:**
- Library methods testing
- CLI interface testing
- Hierarchy flattening
- Windowing functionality
- Various advanced features

**Potential Use:**
- When Sections 4.6-4.10 features are completed
- Reference for advanced feature integration
- Historical context for implementation phases

---

### 3. **test_tower_functionality.m**

**Size:** ~18 KB  
**Purpose:** Test multi-layer tower/stack generation

**Why Archived:**
- Specialized geometric test case
- Edge case testing not essential for validation
- Covered partially by basic pipeline tests
- Complex setup for specific scenario

**Coverage:**
- Programmable layer stacking
- Multi-layer tower structures
- Geometric validation of stacks
- Performance testing with many layers

**Potential Use:**
- Testing extreme multi-layer scenarios
- Performance benchmarking
- Geometric algorithm validation

---

### 4. **test_via_merge.m**

**Size:** ~8 KB  
**Purpose:** Material-based vertical VIA continuity merging

**Why Archived:**
- Advanced semiconductor-specific feature
- Specialized PDK workflow requirement
- Not needed for basic conversion validation
- Requires specific test data setup

**Coverage:**
- VIA tube generation from segmented layers
- Material-based layer merging
- Vertical continuity validation
- Semiconductor process-specific workflows

**Potential Use:**
- Advanced semiconductor PDK workflows
- When VIA merging feature is prioritized
- Reference for material-based operations

---

### 5. **test_ihp_sg13g2_pdk_sets.m**

**Size:** ~11 KB  
**Purpose:** Comprehensive IHP SG13G2 PDK test suite

**Why Archived:**
- Comprehensive but large test suite
- Superseded by optional/test_pdk_basic.m (focused subset)
- Tests 4 complexity levels (basic, intermediate, complex, comprehensive)
- Time-intensive full PDK validation

**Coverage:**
- Basic resistor set (3 tests)
- Intermediate MOSFET + capacitor set (3 tests)
- Complex device set (3 tests)
- Comprehensive multi-device set (15 tests)

**Potential Use:**
- Full PDK validation when needed
- Performance benchmarking with large designs
- Comprehensive semiconductor workflow validation

**Note:** Basic subset is tested in `optional/test_pdk_basic.m`

---

### 6. **test_via_penetration.m**

**Size:** ~27 KB  
**Purpose:** Test VIA penetration through multiple layers

**Why Archived:**
- Highly specialized semiconductor scenario
- Complex test setup requirements
- Advanced feature testing
- Not essential for core validation

**Coverage:**
- VIA penetration logic
- Multi-layer vertical connectivity
- Material property handling
- Complex geometry scenarios

**Potential Use:**
- Advanced semiconductor workflows
- VIA routing optimization
- Multi-layer interconnect validation

---

## Files NOT Archived

The following test files from `migration_temp/` were **migrated** to the new test suite:

### **Essential Tests** (in `new_tests/`)
- ~~`test_layer_functions.m`~~ → `test_config_system.m` + `test_layer_extraction.m`
- ~~`test_extrusion.m`~~ → `test_extrusion_core.m`
- ~~`test_section_4_4.m`~~ → `test_file_export.m`
- ~~`test_main_conversion.m`~~ → `test_basic_pipeline.m`

### **Optional Tests** (in `new_tests/optional/`)
- ~~`test_basic_set_only.m`~~ → `optional/test_pdk_basic.m`
- ~~`test_gds_to_step.m`~~ → `optional/test_advanced_pipeline.m`

### **Not Migrated / Not Archived** (deprecated)
- `test_basic_single.m` - Single-purpose debug script
- `test_intermediate_set_only.m` - Debug script for intermediate tests
- `test_polygon_extraction.m` - Covered by test_layer_functions.m
- `test_gds_flatten_for_3d.m` - Feature-specific, not essential
- `test_gds_window_library.m` - Feature-specific, not essential
- `test_section_4_6_and_4_7.m` - Incomplete implementation
- `test_subsref_compatibility.m` - Compatibility testing only
- `test_ihp_sg13g2_pdk.m` - Duplicate of other PDK tests

---

## Using Archived Tests

### Prerequisites

Most archived tests require:
1. **Path setup** - Add Export/ and Basic/ to Octave/MATLAB path
2. **Test data** - Some require fixtures from `migration_temp/fixtures/`
3. **Dependencies** - Some require external tools (pythonOCC, etc.)

### Running Archived Tests

**⚠️ Warning:** Archived tests are NOT maintained and may fail with current code.

To attempt running an archived test:

```bash
cd /path/to/gdsii-toolbox-146/Export

# Add paths
octave --eval "addpath('Export'); addpath(genpath('Basic')); cd('new_tests/archive'); test_tower_functionality()"
```

**Expected Issues:**
- Path references may be outdated
- Functions may have changed
- Test data may have moved
- Dependencies may not be installed

---

## Migration Statistics

### Test File Distribution

**Original Test Files:** 24 files in migration_temp/

**Migrated:**
- Essential: 4 source files → 5 focused tests
- Optional: 2 source files → 2 optional tests
- **Total Migrated: 6 → 7 new tests**

**Archived:**
- 6 valuable tests preserved for reference

**Deprecated:**
- 12 files not migrated (redundant, debug scripts, obsolete)

### Code Reduction

- **Before:** 24 scattered test files, inconsistent organization
- **After:** 7 organized tests (5 essential + 2 optional) + 6 archived
- **Test Coverage:** Maintained while improving organization
- **Execution Time:** < 0.5 seconds for full suite (was several minutes)

---

## Restoration Guidelines

If you need to restore/update an archived test:

1. **Review the test file** - Understand what it tests
2. **Check dependencies** - Ensure required functions exist
3. **Update paths** - Use standardized path setup pattern
4. **Update fixtures** - Verify test data locations
5. **Test incrementally** - Fix issues one at a time
6. **Consider refactoring** - May be better to write new test

**Path Setup Template:**
```matlab
% Standardized path setup
script_dir = fileparts(mfilename('fullpath'));
test_root = fileparts(script_dir);
export_dir = fileparts(test_root);
toolbox_root = fileparts(export_dir);

% Add required paths
if isempty(strfind(path, export_dir))
    addpath(export_dir);
end
basic_path = fullfile(toolbox_root, 'Basic');
if isempty(strfind(path, basic_path)) && exist(basic_path, 'dir')
    addpath(genpath(basic_path));
end
```

---

## Future Considerations

These archived tests may be valuable for:

1. **Feature Implementation**
   - Boolean operations (test_boolean_operations.m)
   - VIA merging (test_via_merge.m)
   - Advanced windowing (test_integration_4_6_to_4_10.m)

2. **Performance Testing**
   - Full PDK suite (test_ihp_sg13g2_pdk_sets.m)
   - Complex geometries (test_tower_functionality.m)
   - Large-scale conversions

3. **Research & Development**
   - Algorithm validation
   - New feature prototyping
   - Edge case exploration

4. **Documentation**
   - Historical reference
   - Implementation examples
   - Test pattern templates

---

## Contact & Questions

If you need to restore or update an archived test, consider:

1. Check if the feature is now covered by essential/optional tests
2. Review the current codebase for API changes
3. Consider writing a new focused test instead of restoring old one
4. Document any restored tests appropriately

---

**Archive Status:** Preserved for reference only  
**Maintenance:** Not actively maintained  
**Last Migration:** October 5, 2025  
**Migration Project:** GDS-STL-STEP Test Suite Reorganization
