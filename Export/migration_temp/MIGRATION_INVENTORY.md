# Migration Inventory - Test Files

**Created:** October 2025  
**Purpose:** Track original test files and their migration destinations

---

## Test Files Inventory

### **Essential Test Sources** → Will be migrated to new_tests/

| Original File | Lines | Destination | Status |
|--------------|-------|-------------|--------|
| `test_layer_functions.m` | 11KB | `test_config_system.m` (Tests 1-3) + `test_layer_extraction.m` (Tests 4-6) | Phase 2 |
| `test_extrusion.m` | 14KB | `test_extrusion_core.m` (Tests 1,2,6,8) | Phase 2 |
| `test_section_4_4.m` | 8KB | `test_file_export.m` (Tests 1-2,5) | Phase 2 |
| `test_main_conversion.m` | 2KB | `test_basic_pipeline.m` | Phase 2 |

### **Optional Test Sources** → Will be migrated to new_tests/optional/

| Original File | Lines | Destination | Status |
|--------------|-------|-------------|--------|
| `test_basic_set_only.m` | 4KB | `optional/test_pdk_basic.m` | Phase 4 |
| `test_gds_to_step.m` | 16KB | `optional/test_advanced_pipeline.m` | Phase 4 |

### **Archive Sources** → Will be preserved in new_tests/archive/

| Original File | Lines | Reason for Archive | Status |
|--------------|-------|-------------------|--------|
| `test_boolean_operations.m` | 16KB | Experimental feature, pythonOCC dependency | Phase 5 |
| `test_integration_4_6_to_4_10.m` | 25KB | Incomplete features, complex integration | Phase 5 |
| `test_tower_functionality.m` | 18KB | Edge case testing, not core | Phase 5 |
| `test_via_merge.m` | 8KB | Advanced feature, specialized use case | Phase 5 |
| `test_ihp_sg13g2_pdk_sets.m` | 11KB | Comprehensive but large PDK suite | Phase 5 |
| `test_via_penetration.m` | 27KB | Specialized testing scenario | Phase 5 |

### **Debug/Development Scripts** → Archive as reference

| Original File | Lines | Purpose | Status |
|--------------|-------|---------|--------|
| `test_basic_single.m` | 4KB | Single-purpose debug script | Phase 5 |
| `test_intermediate_set_only.m` | 5KB | Debug script for intermediate tests | Phase 5 |
| `integration_test_4_1_to_4_5.m` | 26KB | Development integration test | Phase 5 |

### **Unused/Deprecated** → Archive only

| Original File | Lines | Reason | Status |
|--------------|-------|--------|--------|
| `test_ihp_sg13g2_pdk.m` | 9KB | Duplicate of other PDK tests | Phase 5 |
| `test_polygon_extraction.m` | 15KB | Covered by test_layer_functions.m | Phase 5 |
| `test_gds_flatten_for_3d.m` | 18KB | Feature-specific, not essential | Phase 5 |
| `test_gds_window_library.m` | 19KB | Feature-specific, not essential | Phase 5 |
| `test_section_4_6_and_4_7.m` | 13KB | Incomplete implementation tests | Phase 5 |
| `test_subsref_compatibility.m` | 11KB | Compatibility testing only | Phase 5 |
| `view_via_structure.m` | 6KB | Visualization script, not test | Phase 5 |

---

## Supporting Materials

### **Fixtures Directory**
- Preserved in migration_temp/fixtures/
- Contains:
  - `configs/` - Layer configuration JSON files
  - `ihp_sg13g2/` - IHP SG13G2 PDK test data
  - Will be selectively copied to new_tests/fixtures/ in Phase 3

### **Documentation Files**
- Various README and summary markdown files
- Preserved for reference
- Not needed for new test suite

---

## Migration Statistics

- **Total test files:** 24
- **Essential sources:** 4 files → 5 new tests
- **Optional sources:** 2 files → 2 new tests  
- **Archive:** 18 files → preserved but not migrated
- **Reduction:** From 24 scattered tests to 5-7 organized tests

---

## Next Steps

**Phase 2:** Begin migrating essential test sources
- Start with test_layer_functions.m → extract config and layer extraction logic
- Continue with test_extrusion.m, test_section_4_4.m, test_main_conversion.m
- Each migration includes refactoring and path fixes

---

**Status:** Phase 1 Complete ✅
**Next:** Phase 2 - Essential Test Migration