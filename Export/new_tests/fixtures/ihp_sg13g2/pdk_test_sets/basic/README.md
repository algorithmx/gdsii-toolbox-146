# Basic Test Set

This directory contains simple single-layer structures for basic validation.

**Purpose**: Validate single-layer extraction and 3D extrusion for simple structures.

## Expected Files (Place GDS files here)

| File | Description | Primary Layers |
|------|-------------|----------------|
| `res_metal1.gds` | Metal1 resistor | Metal1 (8/0) |
| `res_metal3.gds` | Metal3 resistor | Metal3 (30/0) |
| `res_topmetal1.gds` | TopMetal1 resistor | TopMetal1 (126/0) |

**Expected Results**:
- 1-2 active layers per test
- Simple rectangular geometries
- Fast processing (< 0.1 sec)
- Clean STL output with single material per layer

**To add test files**: Copy GDS files from IHP-Open-PDK testing directory to this location.