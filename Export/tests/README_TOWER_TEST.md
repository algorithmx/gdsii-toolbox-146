# Tower Functionality Test

## Overview

This test demonstrates the complete GDS-to-STEP/STL conversion pipeline using a 3D tower structure with N stacked layers.

## Test File

- **Test script**: `test_tower_functionality.m`
- **Location**: `Export/tests/test_tower_functionality.m`

## Description

The test creates a 3D tower structure with the following characteristics:

1. **N layers** (where N ≥ 3, default N=5)
2. **Square geometry**: Layer k has a square of side length k
3. **Vertical stacking**: All squares are centered at the same point (origin)
4. **Equal thickness**: All layers have thickness = 1 unit
5. **Layer ordering**: 
   - Layer 1 (smallest, side=1) at the top (z=N-1 to z=N)
   - Layer N (largest, side=N) at the bottom (z=0 to z=1)

## Test Pipeline

The test validates the following workflow:

1. **GDS Creation** - Programmatically construct a multi-layer GDS file using the library API
2. **Layer Configuration** - Generate JSON configuration with uniform layer thickness
3. **GDS → STL Conversion** - Export to STL format
4. **GDS → STEP Conversion** - Export to STEP format (if pythonOCC is available)
5. **Geometry Verification** - Validate the generated structure properties

## Usage

### Running the test

```octave
% Default test with N=5 layers
test_tower_functionality()

% Custom number of layers
test_tower_functionality(5)   % 5 layers
test_tower_functionality(7)   % 7 layers
test_tower_functionality(10)  % 10 layers
```

### From command line

```bash
cd /path/to/gdsii-toolbox-146/Export/tests
octave -q --eval "test_tower_functionality(5)"
```

## Output Files

For a test with N layers, the following files are generated in `test_output_tower_N<N>/`:

- `tower_N<N>.gds` - GDSII layout file with N layers
- `tower_config_N<N>.json` - Layer configuration JSON file
- `tower_N<N>.stl` - Exported STL 3D model

If Python with pythonOCC is available:
- `tower_N<N>.step` - Exported STEP 3D model

## Example: N=5 Tower

### Structure
```
Layer 1: 1×1 square (top)     z = [4, 5]
Layer 2: 2×2 square           z = [3, 4]
Layer 3: 3×3 square (middle)  z = [2, 3]
Layer 4: 4×4 square           z = [1, 2]
Layer 5: 5×5 square (bottom)  z = [0, 1]
```

### Visualization (top view)
```
   +---+           Layer 1 (1×1)
  +-----+          Layer 2 (2×2)
 +-------+         Layer 3 (3×3)
+---------+        Layer 4 (4×4)
+-----------+      Layer 5 (5×5)
```

### Layer Configuration

Each layer has:
- **GDS Layer**: k (1 to N)
- **GDS Datatype**: 0
- **z_bottom**: N-k
- **z_top**: N-k+1
- **Thickness**: 1 (uniform)
- **Color**: Gradient from red (bottom) to blue (top)

## API Functions Used

### GDS Construction
```octave
glib = gds_library('TowerLib', 'uunit', 1e-6, 'dbunit', 1e-9);
gstruct = gds_structure('TowerCell');
rect = gds_element('boundary', 'xy', coords, 'layer', k, 'dtype', 0);
gstruct = add_element(gstruct, rect);
glib = add_struct(glib, gstruct);
write_gds_library(glib, filename, 'verbose', 0);
```

### Conversion
```octave
% Convert to STL
gds_to_step(gds_file, config_file, output_stl, 'format', 'stl', 'verbose', 1);

% Convert to STEP (requires pythonOCC)
gds_to_step(gds_file, config_file, output_step, 'format', 'step', 'verbose', 1);
```

## Test Results

### Successful Test Output
```
================================================================
  TEST SUMMARY: 3D Tower Functionality (N=5)
================================================================
Tests passed: 5
Tests failed: 0

✓ ALL TESTS PASSED

Generated files:
  GDS:    tower_N5.gds
  Config: tower_config_N5.json
  STL:    tower_N5.stl

Tower specifications:
  Layers: 5
  Height: 5 units (z=0 to z=5)
  Layer thickness: 1 unit (uniform)
  Square sizing: layer k has side length k
  Alignment: all squares centered at origin
```

## Design Principles

### Octave-First
- Compatible with GNU Octave syntax
- No MATLAB-specific functions required
- All features work in Octave environment

### Parameterized
- Configurable number of layers (N)
- Scalable to any N ≥ 3
- Automatic file naming based on N

### Comprehensive Testing
1. GDS file creation and validation
2. Layer configuration generation
3. Format conversion (STL/STEP)
4. Geometry verification
5. Detailed error reporting

## Dependencies

### Required
- GNU Octave (4.2.0+)
- gdsii-toolbox-146 library
- Export module functions

### Optional
- Python 3.x with pythonOCC (for STEP format)
- Without pythonOCC, STL format is used as fallback

## Related Files

- `test_section_4_6_and_4_7.m` - Library method and CLI tests
- `test_integration_4_6_to_4_10.m` - Full integration tests
- `../gds_to_step.m` - Main conversion function
- `../gds_read_layer_config.m` - Configuration parser
- `../../Scripts/gds2step` - Command-line interface

## Author

WARP AI Agent, October 2025  
Part of gdsii-toolbox-146 GDSII-to-STEP implementation

## Notes

- Test automatically creates output directories
- Previous test outputs are overwritten
- STEP conversion gracefully falls back to STL if pythonOCC is not available
- All coordinates are in GDS user units (micrometers by default)
- Layer colors use a gradient for visual distinction in 3D viewers
