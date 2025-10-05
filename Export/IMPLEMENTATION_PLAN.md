# Implementation Plan - Test Suite Migration

**Date:** October 2025  
**Project:** gdsii-toolbox-146 Export Module Test Suite Reorganization  
**Approach:** Move and migrate existing test code into new organized structure

---

## Overview

This plan leverages existing high-quality test code by **moving** and **refactoring** it into a clean, organized structure. We'll preserve valuable test logic while fixing path dependencies and compatibility issues.

**Strategy:** Move → Fix → Validate → Iterate

---

## Current Test Inventory

### **Export/ Root Directory (4 files)**
```
test_basic_single.m              → archive/
test_basic_set_only.m           → optional/test_pdk_basic.m
test_ihp_sg13g2_pdk_sets.m      → archive/ 
test_intermediate_set_only.m     → archive/
```

### **Export/tests/ Directory (18 files)**
```
ESSENTIAL TEST SOURCES:
test_layer_functions.m          → test_config_system.m + test_layer_extraction.m
test_extrusion.m               → test_extrusion_core.m
test_section_4_4.m             → test_file_export.m
test_main_conversion.m         → test_basic_pipeline.m

OPTIONAL TEST SOURCES:
test_gds_to_step.m             → optional/test_advanced_pipeline.m

ARCHIVE (preserve but don't migrate):
test_boolean_operations.m      → archive/
test_integration_4_6_to_4_10.m → archive/
test_tower_functionality.m     → archive/
test_via_merge.m               → archive/
[other specialized tests]       → archive/
```

---

## Implementation Plan - 5 Phases

### **Phase 1: Directory Structure Setup** ⏱️ *30 minutes*

**Goal:** Create clean directory structure and prepare for migration

**Steps:**
```bash
cd /home/dabajabaza/Documents/gdsii-toolbox-146/Export

# Create new test structure
mkdir -p new_tests/{fixtures/configs,utils,optional,archive}

# Move all current tests to temporary holding
mkdir -p migration_temp
mv test_*.m migration_temp/
mv tests/* migration_temp/
```

**Deliverables:**
- Clean Export/ directory with new test structure
- All existing tests safely stored in migration_temp/

---

### **Phase 2: Essential Test Migration** ⏱️ *2 days*

**Goal:** Create and validate 5 essential tests from existing code

#### **Step 2.1: Config System Test** ⏱️ *3 hours*

**Source:** `migration_temp/test_layer_functions.m` (Tests 1-3, error handling)

**Action:**
```bash
# Copy source to new location
cp migration_temp/test_layer_functions.m new_tests/test_config_system.m

# Edit to extract relevant tests only
# - Keep config loading (Test 1)
# - Keep IHP config test (Test 2) 
# - Keep error handling (Test 3)
# - Remove layer extraction tests (save for Step 2.4)
```

**Refactoring Tasks:**
- Remove layer extraction logic (Tests 4-6)
- Fix path references to fixtures
- Simplify to 4 focused config tests
- Update function name and documentation
- Test and validate

#### **Step 2.2: Extrusion Core Test** ⏱️ *2 hours*

**Source:** `migration_temp/test_extrusion.m` (Tests 1, 2, 6, 8)

**Action:**
```bash
cp migration_temp/test_extrusion.m new_tests/test_extrusion_core.m
```

**Refactoring Tasks:**
- Keep essential tests: rectangle, triangle, volume, error handling
- Remove complex polygon tests (Tests 3, 4, 5, 7, 9, 10)
- Fix path references
- Update to 4 focused tests
- Test and validate

#### **Step 2.3: File Export Test** ⏱️ *2 hours*

**Source:** `migration_temp/test_section_4_4.m` (Tests 1-2, 5)

**Action:**
```bash
cp migration_temp/test_section_4_4.m new_tests/test_file_export.m
```

**Refactoring Tasks:**
- Keep: STL binary, STL ASCII, error handling
- Remove: STEP tests, unit scaling, multi-solid complexity
- Focus on STL export only (no Python dependencies)
- Test and validate

#### **Step 2.4: Layer Extraction Test** ⏱️ *3 hours*

**Source:** `migration_temp/test_layer_functions.m` (Tests 4-6)

**Action:**
```bash
# Extract layer extraction logic from test_layer_functions.m
# Create new focused test file
```

**Refactoring Tasks:**
- Extract GDS creation and layer extraction tests
- Remove config parsing logic (already in Step 2.1)
- Focus on 3 tests: GDS creation, layer extraction, filtering
- Test and validate

#### **Step 2.5: Basic Pipeline Test** ⏱️ *3 hours*

**Source:** `migration_temp/test_main_conversion.m` (Test 1)

**Action:**
```bash
cp migration_temp/test_main_conversion.m new_tests/test_basic_pipeline.m
```

**Refactoring Tasks:**
- Keep simple end-to-end test
- Add multi-layer test from test_gds_to_step.m if needed
- Focus on 2 integration tests
- Test and validate

#### **Step 2.6: Create Test Runner** ⏱️ *2 hours*

**Create:** `new_tests/run_tests.m`

**Implementation:**
```matlab
function results = run_tests(varargin)
    % Simple test runner for essential GDS-STL-STEP tests
    
    fprintf('\n=== GDS-STL-STEP Essential Test Suite ===\n\n');
    
    % Essential tests
    essential_tests = {
        'test_config_system',
        'test_extrusion_core', 
        'test_file_export',
        'test_layer_extraction',
        'test_basic_pipeline'
    };
    
    % Run tests with simple reporting
    results = run_test_suite(essential_tests);
    print_summary(results);
end
```

**Test Phase 2 Completion:**
```bash
cd new_tests
octave --eval "run_tests()"
```

---

### **Phase 3: Path and Compatibility Fixes** ⏱️ *1 day*

**Goal:** Ensure all migrated tests run correctly with proper paths

#### **Step 3.1: Fix Path References** ⏱️ *4 hours*

**Common Issues to Fix:**
```matlab
% OLD (in migration_temp location)
addpath(genpath('.'));
addpath(genpath('../Basic'));
cfg = gds_read_layer_config('tests/fixtures/ihp_sg13g2/config.json');

% NEW (in new_tests location) 
addpath(fileparts(fileparts(mfilename('fullpath'))));  % Add Export/
addpath(genpath('../Basic'));
cfg = gds_read_layer_config('fixtures/configs/test_config.json');
```

**Action Plan:**
1. **Standardize path setup** in all test files
2. **Create test fixtures** in `fixtures/configs/`
3. **Update all fixture references**
4. **Test each file individually**

#### **Step 3.2: Create Test Fixtures** ⏱️ *2 hours*

**Create basic configs:**

`fixtures/configs/test_basic.json`:
```json
{
  "project": "Basic Test Config",
  "units": "micrometers", 
  "layers": [
    {"gds_layer": 1, "gds_datatype": 0, "name": "Layer1", 
     "z_bottom": 0, "z_top": 1, "material": "silicon", "color": "#FF0000"},
    {"gds_layer": 2, "gds_datatype": 0, "name": "Layer2",
     "z_bottom": 1, "z_top": 2, "material": "oxide", "color": "#00FF00"}, 
    {"gds_layer": 3, "gds_datatype": 0, "name": "Layer3",
     "z_bottom": 2, "z_top": 3, "material": "metal", "color": "#0000FF", "enabled": false}
  ]
}
```

`fixtures/configs/test_multilayer.json`:
```json
{
  "project": "Multi-layer Test Config",
  "units": "micrometers",
  "layers": [
    {"gds_layer": 1, "gds_datatype": 0, "name": "Substrate", "z_bottom": 0, "z_top": 2, "material": "silicon"},
    {"gds_layer": 10, "gds_datatype": 0, "name": "Metal1", "z_bottom": 2, "z_top": 3, "material": "aluminum"},
    {"gds_layer": 20, "gds_datatype": 0, "name": "Metal2", "z_bottom": 3, "z_top": 4, "material": "aluminum"}
  ]
}
```

#### **Step 3.3: Validate All Tests** ⏱️ *2 hours*

**Validation checklist:**
```bash
cd new_tests

# Test each individually
octave --eval "test_config_system()"
octave --eval "test_extrusion_core()"  
octave --eval "test_file_export()"
octave --eval "test_layer_extraction()"
octave --eval "test_basic_pipeline()"

# Test full suite
octave --eval "run_tests()"
```

---

### **Phase 4: Optional Test Migration** ⏱️ *1 day*

**Goal:** Add optional tests for enhanced validation

#### **Step 4.1: PDK Basic Test** ⏱️ *4 hours*

**Source:** `migration_temp/test_basic_set_only.m`

**Action:**
```bash
cp migration_temp/test_basic_set_only.m new_tests/optional/test_pdk_basic.m
```

**Refactoring Tasks:**
- Simplify to 3 basic resistor tests
- Update paths to work from new location
- Handle missing PDK data gracefully
- Add to optional test runner

#### **Step 4.2: Advanced Pipeline Test** ⏱️ *4 hours*

**Source:** `migration_temp/test_gds_to_step.m` (selected tests)

**Action:**
```bash
cp migration_temp/test_gds_to_step.m new_tests/optional/test_advanced_pipeline.m
```

**Refactoring Tasks:**
- Keep advanced integration scenarios
- Add layer filtering tests
- Remove redundancy with basic pipeline test
- Update paths and dependencies

---

### **Phase 5: Archive and Cleanup** ⏱️ *0.5 days*

**Goal:** Archive remaining tests and clean up directories

#### **Step 5.1: Archive Remaining Tests** ⏱️ *2 hours*

**Action:**
```bash
# Move valuable but non-essential tests to archive
mv migration_temp/test_boolean_operations.m new_tests/archive/
mv migration_temp/test_integration_4_6_to_4_10.m new_tests/archive/
mv migration_temp/test_tower_functionality.m new_tests/archive/
mv migration_temp/test_via_merge.m new_tests/archive/
mv migration_temp/test_ihp_sg13g2_pdk_sets.m new_tests/archive/

# Add README explaining archive contents
```

#### **Step 5.2: Final Directory Reorganization** ⏱️ *2 hours*

**Action:**
```bash
# Move new_tests to final location
mv new_tests tests
rm -rf migration_temp

# Final structure:
# Export/
# ├── tests/
# │   ├── run_tests.m
# │   ├── test_config_system.m
# │   ├── test_extrusion_core.m  
# │   ├── test_file_export.m
# │   ├── test_layer_extraction.m
# │   ├── test_basic_pipeline.m
# │   ├── optional/
# │   │   ├── test_pdk_basic.m
# │   │   └── test_advanced_pipeline.m
# │   ├── fixtures/
# │   │   └── configs/
# │   └── archive/
```

---

## Migration Script Templates

### **Path Standardization Template**

For each test file, apply this pattern:
```matlab
function results = test_[name]()
    % [Description]
    
    % Standardized path setup
    script_dir = fileparts(mfilename('fullpath'));
    export_dir = fileparts(script_dir);
    toolbox_root = fileparts(export_dir);
    
    % Add required paths
    addpath(export_dir);
    addpath(genpath(fullfile(toolbox_root, 'Basic')));
    addpath(fullfile(toolbox_root, 'Elements'));
    addpath(fullfile(toolbox_root, 'Structures'));
    
    % Rest of test logic...
end
```

### **Fixture Reference Template**

Replace hardcoded paths:
```matlab
% OLD
cfg = gds_read_layer_config('tests/fixtures/ihp_sg13g2/config.json');

% NEW  
config_file = fullfile(script_dir, 'fixtures', 'configs', 'test_basic.json');
cfg = gds_read_layer_config(config_file);
```

---

## Validation Strategy

### **Progressive Testing Approach**

1. **Individual Test Validation**
   ```bash
   # Test each file after migration
   cd Export/tests
   octave --eval "test_config_system()"
   ```

2. **Integration Validation**
   ```bash
   # Test runner validation
   octave --eval "run_tests()"
   ```

3. **Optional Test Validation**
   ```bash  
   # Optional tests
   octave --eval "run_tests('optional', true)"
   ```

### **Success Criteria**

- ✅ All 5 essential tests pass individually
- ✅ Test runner executes all tests successfully  
- ✅ Total execution time < 3 minutes
- ✅ No external dependency failures
- ✅ Clear pass/fail reporting

---

## Risk Mitigation

### **Backup Strategy**
```bash
# Before starting, backup current state
cd /home/dabajabaza/Documents/gdsii-toolbox-146
tar -czf export_tests_backup_$(date +%Y%m%d).tar.gz Export/
```

### **Rollback Plan**
If migration fails:
```bash
# Restore from backup
rm -rf Export/
tar -xzf export_tests_backup_YYYYMMDD.tar.gz
```

### **Incremental Validation**
- Test each phase before proceeding
- Keep migration_temp/ until Phase 5
- Validate individual tests before full suite

---

## Timeline Summary

| Phase | Duration | Deliverable |
|-------|----------|-------------|
| **Phase 1** | 0.5 hours | Directory structure ready |
| **Phase 2** | 2 days | 5 essential tests working |
| **Phase 3** | 1 day | All path/compatibility issues fixed |
| **Phase 4** | 1 day | Optional tests added |  
| **Phase 5** | 0.5 days | Clean, final structure |

**Total: 5 days** for complete migration with optional enhancements

---

## Expected Outcome

After migration completion:

✅ **Clean, organized test suite** with clear structure  
✅ **5 essential tests** validating core functionality  
✅ **2 optional tests** for enhanced validation  
✅ **Preserved valuable test logic** from existing tests  
✅ **Fixed all path and compatibility issues**  
✅ **Simple test runner** for easy execution  
✅ **Archived non-essential tests** for future reference  

The result will be a maintainable, focused test suite that validates the essential GDS-STL-STEP conversion pipeline while preserving the valuable test logic already written.

---

## Next Steps

1. **Review this plan** and adjust based on your preferences
2. **Create backup** of current Export/ directory  
3. **Begin Phase 1** - Directory structure setup
4. **Proceed incrementally** through phases with validation at each step

Ready to start the migration? 🚀