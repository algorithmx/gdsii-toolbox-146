# IHP SG13G2 PDK Test Setup

## Summary

This document describes the integration of **IHP SG13G2 open-source PDK** test files into the GDSII-to-STEP conversion module test suite.

**Date:** 2025-10-04  
**Purpose:** Validate conversion module with real-world semiconductor PDK data  
**Status:** ✅ Ready for testing

---

## What Was Prepared

### 1. GDS Test Files (4 files)

From `/AI/PDK/IHP-Open-PDK/ihp-sg13g2/libs.tech/klayout/tech/lvs/testing/testcases/unit/`

Copied to `Export/tests/fixtures/ihp_sg13g2/`:

```
res_metal1.gds      (1.2 KB)  - Metal resistor
sg13_hv_nmos.gds    (5.2 KB)  - High-voltage NMOS transistor  
sg13_hv_pmos.gds    (6.5 KB)  - High-voltage PMOS transistor
npn13G2.gds        (21 KB)    - NPN bipolar transistor
```

These files represent common device primitives in semiconductor design and contain realistic geometries with multiple layers.

### 2. Layer Configuration File

**File:** `tests/fixtures/ihp_sg13g2/layer_config_ihp_sg13g2.json`

A comprehensive layer configuration based on the IHP SG13G2 process with:
- **24 layer definitions** (Substrate through TopMetal2)
- **Realistic z-heights** for BiCMOS process stack
- **Material assignments** (Silicon, Aluminum, Tungsten, etc.)
- **Color mappings** from official KLayout layer properties

#### Key Layers Defined:

| Category | Layers | Z-Range (µm) |
|----------|--------|--------------|
| Device | Substrate, Activ, GatPoly, NWell, pSD, nSD | -5.0 to 1.5 |
| Contacts | Cont | 0.5 to 0.8 |
| Thin Metals | Metal1-5 + Vias | 0.8 to 5.9 |
| Thick Metals | TopMetal1-2 + TopVias | 6.9 to 13.0 |
| Special | MIM capacitor, SalBlock | Various |

### 3. Test Script

**File:** `tests/test_ihp_sg13g2_pdk.m`

Comprehensive test suite that validates:
- ✓ Layer configuration loading
- ✓ GDS file reading  
- ✓ Layer extraction from real PDK data
- ✓ 3D extrusion of device geometries
- ✓ STL file generation and export

**Test Coverage:**
- 4 GDS files × 3 tests each = **12 total tests**
- Validates entire conversion pipeline end-to-end

### 4. Documentation

**File:** `tests/fixtures/ihp_sg13g2/README.md`

Complete documentation including:
- PDK overview and technology details
- Layer configuration reference
- Usage examples (basic and advanced)
- Color scheme and material mapping
- Test execution instructions

---

## Quick Start

### Run All Tests

```bash
cd ~/Documents/gdsii-toolbox-146/Export
octave --eval "test_ihp_sg13g2_pdk"
```

Or from Octave/MATLAB:
```matlab
cd Export
test_ihp_sg13g2_pdk
```

### Run Individual Test

```matlab
% Load configuration
cfg = gds_read_layer_config('tests/fixtures/ihp_sg13g2/layer_config_ihp_sg13g2.json');

% Read GDS
glib = read_gds_library('tests/fixtures/ihp_sg13g2/sg13_hv_nmos.gds');

% Extract layers
layer_data = gds_layer_to_3d(glib, cfg);

% Display results
for k = 1:length(layer_data.layers)
    if layer_data.layers(k).num_polygons > 0
        fprintf('%s: %d polygons\n', ...
                layer_data.layers(k).config.name, ...
                layer_data.layers(k).num_polygons);
    end
end
```

---

## Expected Test Results

### Successful Run Output

```
========================================
IHP SG13G2 PDK Test Suite
========================================

Testing 4 GDS files from IHP SG13G2 PDK

----------------------------------------
Test 1/4: Metal resistor (res_metal1.gds)
----------------------------------------
    Loaded 24 layer definitions
  ✓ Load layer configuration
    Loaded GDS: 1 structures
    Extracted 1 layers with 4 total polygons
  ✓ Extract layers from GDS
    Generated 4 3D solids
    STL file size: 2.34 KB
  ✓ Generate 3D and export STL

[Tests 2-4 continue...]

========================================
Test Summary
========================================
Total tests:  12
Passed:       12 (100.0%)
Failed:       0 (0.0%)
========================================

✓ ALL TESTS PASSED!
```

### Generated Output Files

Location: `Export/tests/test_output_ihp_sg13g2/`

```
res_metal1_3d.stl
sg13_hv_nmos_3d.stl
sg13_hv_pmos_3d.stl
npn13G2_3d.stl
```

These STL files can be viewed in any 3D CAD viewer (FreeCAD, MeshLab, etc.).

---

## Technical Details

### Layer Extraction Logic

For each GDS file:
1. Parse configuration to understand layer mappings
2. Read GDS library structure
3. Filter enabled layers (24 defined, ~10-15 typically used per device)
4. Extract polygon geometries per layer
5. Organize by z-height for 3D processing

### 3D Extrusion

- Each 2D polygon → 3D prism with top/bottom faces + side walls
- Z-heights from layer configuration
- Triangle mesh generation (vertices + faces)
- Normal vectors computed for rendering

### Material Information

Preserved in output structure:
- Layer name (e.g., "Metal1", "GatPoly")
- Material type (e.g., "Aluminum", "Polysilicon")
- Z-position (bottom and top)
- Original GDS layer/datatype

---

## Why IHP SG13G2?

### Advantages for Testing

1. **Open Source:** Freely available, no NDA required
2. **Real Process:** Actual 130nm BiCMOS technology, not synthetic data
3. **Comprehensive:** Full metal stack (7 metal layers) + devices
4. **Well Documented:** KLayout layer properties included
5. **Size Range:** Small test devices (1-21 KB) for fast iteration

### Representative Use Cases

- **Academic Research:** Device simulation, parasitic extraction
- **IC Design:** Custom analog/RF circuits, mixed-signal designs
- **FEM Analysis:** Thermal, mechanical, electromagnetic simulations
- **3D Visualization:** Educational material, design reviews

---

## File Structure

```
Export/
├── tests/
│   ├── fixtures/
│   │   ├── ihp_sg13g2/
│   │   │   ├── README.md                        (Documentation)
│   │   │   ├── layer_config_ihp_sg13g2.json    (Layer config)
│   │   │   ├── res_metal1.gds                   (Test GDS)
│   │   │   ├── sg13_hv_nmos.gds                 (Test GDS)
│   │   │   ├── sg13_hv_pmos.gds                 (Test GDS)
│   │   │   └── npn13G2.gds                      (Test GDS)
│   ├── test_ihp_sg13g2_pdk.m                    (Test script)
│   ├── test_output_ihp_sg13g2/                  (Generated outputs)
│   └── IHP_SG13G2_TEST_SETUP.md                (This file)
```

---

## Integration with Existing Tests

This test suite complements existing tests:

| Test Suite | Purpose | Test Files |
|------------|---------|------------|
| `test_section_4_4.m` | Core layer functions | Synthetic GDS |
| `test_gds_to_step.m` | Main conversion | Simple geometries |
| `test_integration_4_6_to_4_10.m` | Pipeline integration | Hierarchy tests |
| **`test_ihp_sg13g2_pdk.m`** | **Real PDK validation** | **IHP SG13G2 devices** |

---

## Customization

### Add More Test Files

Copy additional GDS files from IHP-Open-PDK:

```bash
cp /AI/PDK/IHP-Open-PDK/ihp-sg13g2/libs.tech/klayout/tech/lvs/testing/testcases/unit/cap_devices/layout/rfcmim.gds \
   tests/fixtures/ihp_sg13g2/
```

Update test script `test_files` array:
```matlab
test_files = {
    'res_metal1.gds', 'Metal resistor';
    'sg13_hv_nmos.gds', 'HV NMOS transistor';
    'sg13_hv_pmos.gds', 'HV PMOS transistor';
    'npn13G2.gds', 'NPN bipolar transistor';
    'rfcmim.gds', 'RF MIM capacitor'  % New
};
```

### Modify Layer Configuration

Edit `layer_config_ihp_sg13g2.json`:

```json
{
  "gds_layer": 8,
  "name": "Metal1",
  "z_bottom": 0.8,
  "z_top": 1.3,
  "enabled": true    // Set to false to skip this layer
}
```

### Extract Specific Layers Only

```matlab
% Only extract metal layers for interconnect analysis
metal_layers = [8 10 30 50 67];
layer_data = gds_layer_to_3d(glib, cfg, 'layers_filter', metal_layers);
```

---

## Troubleshooting

### Issue: "Basic directory not found"

**Solution:** Ensure gdsii-toolbox-146 is properly installed:
```matlab
addpath(genpath('~/Documents/gdsii-toolbox-146/Basic'));
```

### Issue: "Failed to read GDS library"

**Cause:** GDS file path incorrect or missing  
**Solution:** Verify files copied correctly:
```bash
ls -lh tests/fixtures/ihp_sg13g2/*.gds
```

### Issue: "No polygons extracted"

**Possible causes:**
1. Layer numbers don't match GDS content
2. All layers disabled in config
3. Invalid GDS file

**Debug:**
```matlab
glib = read_gds_library('tests/fixtures/ihp_sg13g2/sg13_hv_nmos.gds');
for k = 1:length(glib{1})
    fprintf('Structure: %s\n', glib{1}(k).sname);
end
```

---

## Future Enhancements

Potential additions:
- [ ] STEP export tests (requires pythonOCC)
- [ ] Boolean operations on overlapping layers
- [ ] Mesh quality validation
- [ ] Performance benchmarking
- [ ] Visual regression tests
- [ ] More device types (inductors, varactors, etc.)

---

## References

- **IHP-Open-PDK:** https://github.com/IHP-GmbH/IHP-Open-PDK
- **SG13G2 Technology:** 130nm BiCMOS with HBTs
- **Original Test Files:** `/AI/PDK/IHP-Open-PDK/ihp-sg13g2/libs.tech/klayout/tech/lvs/testing/`
- **License:** Apache 2.0 (IHP-Open-PDK)

---

## Contact

For questions about:
- **Test framework:** See `Export/README.md`
- **IHP SG13G2 PDK:** Visit IHP-Open-PDK GitHub
- **GDS format:** See gdsii-toolbox-146 documentation

---

**Last Updated:** 2025-10-04  
**Status:** Production Ready ✅
