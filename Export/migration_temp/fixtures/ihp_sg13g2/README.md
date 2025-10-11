# IHP SG13G2 PDK Test Files

This directory contains test files from the **IHP SG13G2 open-source PDK** for validating the GDSII-to-STEP conversion module.

## Overview

The IHP SG13G2 is a 0.13µm BiCMOS technology process with:
- 5 thin metal layers (Metal1-5)
- 2 thick top metal layers (TopMetal1-2)
- High-voltage (HV) and low-voltage (LV) CMOS devices
- Bipolar transistors (NPN)
- MIM capacitors
- Polysilicon and metal resistors
- Inductors

**Source:** [IHP-Open-PDK on GitHub](https://github.com/IHP-GmbH/IHP-Open-PDK)

## Test Files

### GDS Files

Located in `tests/fixtures/ihp_sg13g2/`:

| File | Size | Description | Layers Used |
|------|------|-------------|-------------|
| `res_metal1.gds` | 1.2 KB | Metal1 resistor | Metal1 (8/0) |
| `sg13_hv_nmos.gds` | 5.2 KB | High-voltage NMOS transistor | Activ, GatPoly, NWell, Cont, Metal1 |
| `sg13_hv_pmos.gds` | 6.5 KB | High-voltage PMOS transistor | Activ, GatPoly, pSD, Cont, Metal1 |
| `npn13G2.gds` | 21 KB | NPN bipolar transistor | Multiple layers including contacts and metal |

### Layer Configuration

**File:** `layer_config_ihp_sg13g2.json`

A comprehensive layer configuration with 24 layers including:

#### Device Layers
- **Substrate (40/0):** Silicon substrate, z = -5.0 to 0.0 µm
- **Activ (1/0):** Active area, z = 0.0 to 0.3 µm
- **GatPoly (5/0):** Gate polysilicon, z = 0.3 to 0.5 µm
- **NWell (31/0):** N-well, z = 0.0 to 1.5 µm

#### Metal Stack
- **Cont (6/0):** Contact, z = 0.5 to 0.8 µm
- **Metal1 (8/0):** 0.5 µm thick, z = 0.8 to 1.3 µm
- **Via1 (19/0):** 0.5 µm thick, z = 1.3 to 1.8 µm
- **Metal2 (10/0):** 0.5 µm thick, z = 1.8 to 2.3 µm
- **Via2 (29/0):** 0.5 µm thick, z = 2.3 to 2.8 µm
- **Metal3 (30/0):** 0.5 µm thick, z = 2.8 to 3.3 µm
- **Via3 (49/0):** 0.5 µm thick, z = 3.3 to 3.8 µm
- **Metal4 (50/0):** 0.8 µm thick, z = 3.8 to 4.6 µm
- **Via4 (66/0):** 0.5 µm thick, z = 4.6 to 5.1 µm
- **Metal5 (67/0):** 0.8 µm thick, z = 5.1 to 5.9 µm
- **TopVia1 (125/0):** 1.0 µm thick, z = 5.9 to 6.9 µm
- **TopMetal1 (126/0):** 2.1 µm thick, z = 6.9 to 9.0 µm
- **TopVia2 (133/0):** 1.0 µm thick, z = 9.0 to 10.0 µm
- **TopMetal2 (134/0):** 3.0 µm thick, z = 10.0 to 13.0 µm

#### Materials
- **Silicon:** Substrate, active areas
- **Polysilicon:** Gate poly, resistors
- **Aluminum:** All metal layers
- **Tungsten:** Contacts and vias
- **SiO2, SiN:** Dielectrics

## Running Tests

### From Octave/MATLAB

```matlab
% Navigate to Export directory
cd ~/Documents/gdsii-toolbox-146/Export

% Run the IHP PDK test suite
test_ihp_sg13g2_pdk
```

### Expected Output

```
========================================
IHP SG13G2 PDK Test Suite
========================================

Testing 4 GDS files from IHP SG13G2 PDK
Layer config: tests/fixtures/ihp_sg13g2/layer_config_ihp_sg13g2.json

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
    Output: tests/test_output_ihp_sg13g2/res_metal1_3d.stl

[... more tests ...]

========================================
Test Summary
========================================
Total tests:  12
Passed:       12 (100.0%)
Failed:       0 (0.0%)
========================================

✓ ALL TESTS PASSED!
```

## Manual Test Example

### Example 1: Convert NMOS Device to STL

```matlab
% Add paths
addpath('Export');
addpath(genpath('Basic'));

% Load configuration and GDS
cfg = gds_read_layer_config('tests/fixtures/ihp_sg13g2/layer_config_ihp_sg13g2.json');
glib = read_gds_library('tests/fixtures/ihp_sg13g2/sg13_hv_nmos.gds');

% Extract layers
layer_data = gds_layer_to_3d(glib, cfg);

% Generate 3D solids
solids = [];
for k = 1:length(layer_data.layers)
    L = layer_data.layers(k);
    if L.num_polygons == 0, continue; end
    
    for p = 1:L.num_polygons
        poly = L.polygons{p};
        [V, F] = gds_extrude_polygon(poly, L.config.z_bottom, L.config.z_top);
        
        if ~isempty(V)
            idx = length(solids) + 1;
            solids(idx).vertices = V;
            solids(idx).faces = F;
            solids(idx).layer_name = L.config.name;
            solids(idx).material = L.config.material;
        end
    end
end

% Export to STL
gds_write_stl('nmos_device.stl', solids);
fprintf('Generated %d solids\\n', length(solids));
```

### Example 2: Extract Specific Layers

```matlab
% Extract only metal layers
cfg = gds_read_layer_config('tests/fixtures/ihp_sg13g2/layer_config_ihp_sg13g2.json');
glib = read_gds_library('tests/fixtures/ihp_sg13g2/npn13G2.gds');

% Filter for metal layers only
metal_layers = [8 10 30 50 67 126 134];  % Metal1-5, TopMetal1-2
layer_data = gds_layer_to_3d(glib, cfg, 'layers_filter', metal_layers);

% Display results
for k = 1:length(layer_data.layers)
    L = layer_data.layers(k);
    if L.num_polygons > 0
        fprintf('Layer %s: %d polygons, area = %.2f µm²\\n', ...
                L.config.name, L.num_polygons, L.area);
    end
end
```

## Layer Configuration Details

### Z-Heights

The z-heights in the configuration are based on typical BiCMOS process cross-sections:

- **Front-end** (0-1.5 µm): Active areas, poly, wells, implants
- **Contacts** (0.5-0.8 µm): Tungsten plugs connecting to silicon
- **Thin metals** (0.8-5.9 µm): Metal1-5 for signal routing
- **Thick metals** (6.9-13.0 µm): TopMetal1-2 for power, inductors, pads

### Material Mapping

| Layer Type | Material | Purpose |
|------------|----------|---------|
| Substrate, Wells | Silicon | Semiconductor regions |
| Gate Poly | Polysilicon | Transistor gates, resistors |
| Contacts, Vias | Tungsten | Vertical interconnects |
| Metal layers | Aluminum | Horizontal interconnects |
| Dielectrics | SiO2, SiN | Isolation, capacitors |

## Color Scheme

Colors are extracted from the IHP SG13G2 KLayout layer properties file (`sg13g2.lyp`):

- **Green (#00FF00):** Active areas
- **Red/Brown (#BF4026):** Polysilicon
- **Cyan (#39BFFF):** Metal1
- **Gray (#CCCCD9):** Metal2
- **Dark Red (#D80000):** Metal3
- **Green (#93E837):** Metal4
- **Yellow (#DCD146):** Metal5
- **Beige (#FFE6BF):** TopMetal1
- **Orange (#FF8000):** TopMetal2

## Validation

The test files are validated using:

1. **Layer Extraction:** Confirms polygons are read correctly from GDS
2. **3D Extrusion:** Verifies geometric transformation from 2D to 3D
3. **STL Export:** Checks output file generation and format validity

## Source Information

- **PDK Source:** IHP-Open-PDK v1.0+
- **Original Location:** `/AI/PDK/IHP-Open-PDK/ihp-sg13g2/libs.tech/klayout/tech/lvs/testing/testcases/unit/`
- **License:** Apache 2.0 (from IHP-Open-PDK)
- **Technology:** 130nm BiCMOS with 2 thick metal layers

## References

1. [IHP-Open-PDK GitHub Repository](https://github.com/IHP-GmbH/IHP-Open-PDK)
2. [IHP SG13G2 Technology Documentation](https://github.com/IHP-GmbH/IHP-Open-PDK/tree/main/ihp-sg13g2)
3. [KLayout Layer Properties Format](https://www.klayout.de/)

## Notes

- The z-heights are **representative** for testing and may not match actual process specifications
- Enable/disable specific layers by editing the `enabled` field in the JSON configuration
- The substrate layer is optional and can be disabled for faster processing
- For production use, obtain official process design rules from IHP

---

**Last Updated:** 2025-10-04  
**Test Framework:** Octave 4.2+ / MATLAB R2016b+
