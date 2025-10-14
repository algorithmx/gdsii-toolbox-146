# VIA Test Quick Start Guide

## Overview

The VIA (Vertical Interconnect Access) test demonstrates the creation and export of vertical interconnect structures through multiple layers. This test reuses the tower design concept but adds VIA elements that penetrate through the layers.

## Test Files

1. **`test_via_functionality.m`** - Main VIA test script
2. **`view_via_structure.m`** - Helper script to analyze VIA structure

## How to Run the VIA Test

### Basic Usage

```octave
% Run VIA test with default N=5
test_via_functionality()

% Run VIA test with specific layer count
test_via_functionality(3)  % 3-layer tower + landing pad
test_via_functionality(5)  % 5-layer tower + landing pad
```

### Structure Analysis

```octave
% Analyze the generated VIA structure
view_via_structure(3)  % Analyze N=3 structure
view_via_structure(5)  % Analyze N=5 structure
```

## Test Description

The VIA test creates a modified tower structure with vertical interconnects:

### Structure Design (N=3 Example)
- **Layer 1**: VIA starter (3×3 BOUNDARY) - replaces the original tower top
- **Layer 2**: Tower boundary (2×2) + VIA boundary (1×1)
- **Layer 3**: Tower boundary (3×3) + VIA boundary (1×1)
- **Layer 4**: VIA landing pad (4×4 BOUNDARY)

### General Pattern
For a given N:
- **Layer 1**: VIA starter of size N×N
- **Layers 2..N**: Tower of size k×k + VIA of size 1×1 (where k is the layer number)
- **Layer N+1**: Landing pad of size (N+1)×(N+1)

## Materials Used

- **VIA starter**: `Tungsten_starter` (blue)
- **Tower layers**: `Silicon_tower` (gray)
- **VIA wires**: `Tungsten_via` (green gradient)
- **Landing pad**: `Copper_pad` (red)

## Output Files

The test generates the following files in `test_output/via_N{N}/`:

1. **`via_functionality_N{N}.gds`** - Source GDSII file
2. **`via_config_N{N}.json`** - Layer configuration
3. **`via_functionality_N{N}.stl`** - 3D mesh format (always available)
4. **`via_functionality_N{N}.step`** - CAD format (requires pythonOCC)
5. **`via_functionality_N{N}_merged.step`** - Merged CAD format (requires pythonOCC)

**Note**: STEP files require the `pythonocc` conda environment to be activated for pythonOCC. The test will attempt to activate this environment automatically. If not available, the system gracefully falls back to STL format and continues testing.

## Test Features

### Test Cases
1. **GDS Generation** - Creates VIA structure with proper layering
2. **Layer Configuration** - Sets up material assignments and Z-coordinates
3. **STL Export** - Exports to 3D mesh format
4. **STEP Export (Unmerged)** - Exports to CAD format with separate solids
5. **STEP Export (Merged)** - Exports to CAD format with merged VIA segments
6. **Geometry Verification** - Validates structure and vertical alignment

### Key Features
- **Vertical Interconnects**: 1×1 square VIA through middle layers
- **Material-based Merging**: VIA segments can merge into continuous tubes
- **Centered Design**: All elements centered at origin for proper alignment
- **Multiple Formats**: Support for both STL and STEP output

## Visual Inspection

Since automated result-checking is difficult, you should visually inspect the output files:

### STL Viewing
```bash
# View STL files in any 3D viewer
meshlab test_output/via_N3/via_functionality_N3.stl
```

### STEP Viewing
```bash
# View STEP files in CAD software
freecad test_output/via_N3/via_functionality_N3.step  # If available
```

### What to Look For
1. **Vertical Alignment**: All layers should be centered and stacked vertically
2. **VIA Continuity**: The 1×1 VIA should form a continuous vertical path
3. **Proper Sizing**: Tower layers should increase in size (2×2, 3×3, etc.)
4. **Material Distinction**: Different materials should be visually distinguishable

## Requirements

- **Octave or MATLAB**: For running the test scripts
- **pythonOCC (optional)**: For STEP format output
- **3D Viewer**: For STL file inspection
- **CAD Software**: For STEP file inspection

## Troubleshooting

### STEP Files Not Generated
If STEP files are not created, ensure pythonOCC is installed:
```bash
conda install -c conda-forge pythonocc-core
```

### Missing Output Files
Check the test output directory structure and ensure write permissions.

### Geometry Issues
Use `view_via_structure(N)` to verify the GDS structure before conversion.

## Design Intent

This test demonstrates:
- **Multi-layer fabrication**: Proper stacking of different layer types
- **Vertical interconnects**: Creating continuous paths through multiple layers
- **Material management**: Handling different materials in a single design
- **Export pipeline**: Complete workflow from GDS to 3D formats

The VIA structure mimics real semiconductor designs where vertical interconnects (vias) connect different metal layers in an integrated circuit.