# IHP SG13G2 PDK Test Sets

This directory contains comprehensive test sets extracted from the **IHP-Open-PDK** repository to validate the GDSII-to-STEP converter with real-world semiconductor devices.

## Overview

The test sets are organized by complexity level to provide systematic validation of the converter's capabilities:

- **Basic**: Single-layer simple structures
- **Intermediate**: Multi-layer devices with moderate complexity  
- **Complex**: Full devices using many layers
- **Comprehensive**: Complete range of PDK devices

## Source Information

- **PDK Source**: [IHP-Open-PDK](https://github.com/IHP-GmbH/IHP-Open-PDK) v1.0+
- **Technology**: IHP SG13G2 130nm BiCMOS process
- **Original Path**: `/AI/PDK/IHP-Open-PDK/ihp-sg13g2/libs.tech/klayout/tech/lvs/testing/testcases/unit/`
- **License**: Apache 2.0
- **Extracted Date**: 2025-10-04

## Test Set Details

### 1. Basic Test Set (`basic/`)

**Purpose**: Validate single-layer extraction and 3D extrusion for simple structures.

| File | Size | Description | Primary Layers |
|------|------|-------------|----------------|
| `res_metal1.gds` | 1.1 KB | Metal1 resistor | Metal1 (8/0) |
| `res_metal3.gds` | 1.1 KB | Metal3 resistor | Metal3 (30/0) |
| `res_topmetal1.gds` | 1.1 KB | TopMetal1 resistor | TopMetal1 (126/0) |

**Expected Results**:
- 1-2 active layers per test
- Simple rectangular geometries
- Fast processing (< 0.1 sec)
- Clean STL output with single material per layer

**Validation Criteria**:
- ✓ Correct layer identification
- ✓ Proper Z-height assignment  
- ✓ Accurate polygon extrusion
- ✓ STL file generation

---

### 2. Intermediate Test Set (`intermediate/`)

**Purpose**: Test multi-layer devices with interconnects and moderate complexity.

| File | Size | Description | Primary Layers |
|------|------|-------------|----------------|
| `sg13_lv_nmos.gds` | 76 KB | Low-voltage NMOS transistor | Activ, GatPoly, NWell, Cont, Metal1 |
| `sg13_hv_pmos.gds` | 6.5 KB | High-voltage PMOS transistor | Activ, GatPoly, pSD, Cont, Metal1 |
| `cap_cmim.gds` | 614 KB | MIM capacitor | Metal3, MIM dielectric, Metal4 |

**Expected Results**:
- 3-8 active layers per test
- Complex polygons with curves and cuts
- Medium processing time (0.1-1.0 sec)
- Multiple materials in STL output

**Validation Criteria**:
- ✓ Multi-layer stack assembly
- ✓ Contact/via proper placement
- ✓ Gate poly above active area
- ✓ Metal interconnect continuity

---

### 3. Complex Test Set (`complex/`)

**Purpose**: Validate complete devices with full layer stacks and advanced geometries.

| File | Size | Description | Primary Layers |
|------|------|-------------|----------------|
| `npn13G2.gds` | 21 KB | NPN bipolar transistor | Multiple device and metal layers |
| `inductor.gds` | 77 KB | Spiral inductor | TopMetal1, TopMetal2, multiple vias |
| `rfnmos.gds` | 171 KB | RF NMOS transistor | Full device stack + RF optimization layers |

**Expected Results**:
- 8-15 active layers per test
- Complex curved geometries (spiral, circular)
- Longer processing time (1-5 sec)
- Multi-level 3D structures

**Validation Criteria**:
- ✓ Complete device stack reconstruction
- ✓ Curved geometry handling
- ✓ Multi-level metal routing
- ✓ Via stack alignment

---

### 4. Comprehensive Test Set (`comprehensive/`)

**Purpose**: Full-scale validation with complete range of PDK devices and edge cases.

Contains 15+ diverse devices including:

| Device Type | Count | Examples | Key Features |
|-------------|-------|----------|--------------|
| **Bipolar Transistors** | 4 | npn13G2, npn13G2l, npn13G2v, pnpMPA | Multiple geometries, high-current variants |
| **ESD Protection** | 6 | diodevdd_4kv, nmoscl_4, idiodevss_2kv | Large area devices, high-voltage |
| **Capacitors** | 2 | cap_cmim, rfcmim | MIM and RF capacitors |
| **Varactors** | 1 | sg13_hv_svaricap | Variable capacitor |

**Expected Results**:
- Highly variable complexity (1-20+ active layers)
- Processing time range: 0.1-10+ seconds
- File sizes: 1 KB - 6 MB
- Diverse materials and geometries

**Validation Criteria**:
- ✓ Handle diverse device types
- ✓ Scale from simple to complex
- ✓ Memory efficiency for large files
- ✓ Robust error handling

## Layer Configuration

Two configurations are provided for comparison:

### 1. Original Configuration (`layer_config_ihp_sg13g2.json`)
- Based on typical process assumptions
- Representative Z-heights for testing
- 24 defined layers

### 2. LEF-based Accurate Configuration (`layer_config_ihp_sg13g2_accurate.json`)
- **Recommended for production use**
- Extracted from actual `sg13g2_tech.lef` file
- Precise HEIGHT and THICKNESS values from PDK
- Includes electrical properties (resistance, pitch, etc.)
- 22 optimized layers

#### Key Differences:

| Parameter | Original Config | LEF-based Config |
|-----------|----------------|------------------|
| Metal1 height | 1.3 μm | 0.93 μm (LEF) |
| Metal1 thickness | 0.5 μm | 0.40 μm (LEF) |
| TopMetal1 thickness | 2.1 μm | 2.00 μm (LEF) |
| TopMetal2 height | 13.0 μm | 11.16 μm (LEF) |
| Source | Estimated | Official PDK LEF |

## Running the Tests

### Quick Test (Octave/MATLAB)

```matlab
% Navigate to the Export directory
cd ~/Documents/gdsii-toolbox-146/Export

% Run comprehensive test suite
test_ihp_sg13g2_pdk_sets()
```

### Individual Test Set

```matlab
% Test only basic set with specific config
cfg = gds_read_layer_config('tests/fixtures/ihp_sg13g2/layer_config_ihp_sg13g2_accurate.json');
gds_files = dir('tests/fixtures/ihp_sg13g2/pdk_test_sets/basic/*.gds');

for i = 1:length(gds_files)
    glib = read_gds_library(fullfile(gds_files(i).folder, gds_files(i).name));
    layer_data = gds_layer_to_3d(glib, cfg);
    % Process layer_data...
end
```

## Expected Output

### Test Summary Format
```
========================================
IHP SG13G2 PDK Test Sets - Comprehensive Suite
========================================
Generated from: /AI/PDK/IHP-Open-PDK/
Date: 04-Oct-2025 17:58:23
Configuration: LEF-based accurate layer stack

Testing Configuration: LEF-based Accurate Config
Config file: tests/fixtures/ihp_sg13g2/layer_config_ihp_sg13g2_accurate.json
----------------------------------------
  ✓ Loaded 22 layer definitions

--- Test Set: Basic (Single Layer Resistors) ---
Description: Simple metal resistors on different layers
Found 3 GDS files:

  Test 1/3: res_metal1.gds
  Size: 1.1 KB
    ✓ Load GDS: 0.012 sec, 1 structures
    ✓ Extract layers: 0.008 sec, 1 active layers, 4 polygons
      Active layers: Metal1(4)
    ✓ Generate 3D: 0.003 sec, 4 solids
    ✓ Export STL: 0.045 sec, 2.34 KB
      Output: tests/test_output_pdk_LEF-based_Accurate_Config_basic/res_metal1_3d.stl
    ✅ SUCCESS (0.068 sec total)

[... more tests ...]

========================================
COMPREHENSIVE TEST SUMMARY
========================================
Total tests:     48
Passed:          48 (100.0%)
Failed:          0 (0.0%)
Configurations:  2
Test sets:       4
========================================
✅ ALL TESTS PASSED!

Performance Analysis (Passed Tests):
  Average processing time: 0.234 sec
  Average active layers:   4.2
  Average polygons:        127
  Average 3D solids:       89
  Fastest test:           0.068 sec
  Slowest test:           2.145 sec

🔬 Test completed: 04-Oct-2025 18:02:15
📁 Results saved in tests/test_output_pdk_* directories
```

## Troubleshooting

### Common Issues

1. **"No GDS files found"**
   - Check that PDK files were properly copied
   - Verify file permissions

2. **"Failed to load configuration"**
   - Ensure JSON syntax is valid
   - Check file paths in configuration

3. **Layer extraction errors**
   - Verify GDS layer numbers match configuration
   - Check for unsupported GDS features

4. **Memory issues with large files**
   - Increase MATLAB/Octave memory limit
   - Process comprehensive set in batches

### Performance Optimization

- **For large test runs**: Process test sets separately
- **For development**: Use basic set for quick validation
- **For production**: Use LEF-based accurate configuration

## Validation Metrics

Each test is validated against:

1. **Functional Requirements**:
   - GDS file loads without errors
   - Layer extraction completes successfully  
   - 3D solids generation produces valid geometry
   - STL export creates readable files

2. **Performance Requirements**:
   - Basic tests: < 0.1 sec per file
   - Intermediate tests: < 1.0 sec per file
   - Complex tests: < 5.0 sec per file
   - Memory usage: < 1GB per file

3. **Quality Requirements**:
   - STL files are valid (no degenerate triangles)
   - Layer heights match configuration
   - Polygon count is reasonable (not excessive triangulation)
   - Material assignments are correct

## Future Enhancements

- [ ] Add STEP export validation
- [ ] Include mesh quality metrics
- [ ] Add visual comparison with reference images
- [ ] Implement automated performance regression testing
- [ ] Add support for hierarchical designs

---

**Last Updated**: 2025-10-04  
**Maintainer**: WARP AI Agent  
**Test Framework**: Octave 4.2+ / MATLAB R2016b+