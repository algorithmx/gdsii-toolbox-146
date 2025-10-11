# Tower Test Quick Start Guide

## What This Test Does

Creates a 3D "tower" structure by stacking N squares of increasing size, with each layer having uniform thickness of 1 unit. The structure is then converted from GDS format to STL and optionally STEP format.

## Visual Concept

```
Side View:              Top View:
                        
z=5  [==]  Layer 1        +---+
z=4  [====]  Layer 2     +-----+
z=3  [======]  Layer 3  +-------+
z=2  [========]  Layer 4 +---------+
z=1  [==========]  Layer 5 +-----------+
z=0
```

## Quick Start

### 1. Run the test (default N=5)

```bash
cd /home/dabajabaza/Documents/gdsii-toolbox-146/Export/tests
octave -q --eval "test_tower_functionality()"
```

### 2. Run with custom layer count

```bash
# 7 layers
octave -q --eval "test_tower_functionality(7)"

# 10 layers
octave -q --eval "test_tower_functionality(10)"
```

### 3. Check the output

Output files will be in: `test_output_tower_N<N>/`

Example for N=5:
- `tower_N5.gds` - GDSII file
- `tower_config_N5.json` - Layer configuration
- `tower_N5.stl` - 3D STL model

## What Gets Tested

1. ✓ Creating GDS file with N layers programmatically
2. ✓ Generating layer configuration with uniform thickness
3. ✓ Converting GDS → STL
4. ✓ Converting GDS → STEP (if Python/pythonOCC available)
5. ✓ Verifying geometry properties

## Expected Output

```
================================================================
  TEST: 3D Tower Functionality (N=5 layers)
================================================================

Test directory: .../test_output_tower_N5
Number of layers: 5
Layer thickness: 1 unit
Square sizing: layer k has side length k (k=1..5)

TEST 1: Create 5-layer tower GDS structure
----------------------------------------------------------------------
  Building tower structure:
    Layer  1: square side=1.0, centered at origin
    Layer  2: square side=2.0, centered at origin
    Layer  3: square side=3.0, centered at origin
    Layer  4: square side=4.0, centered at origin
    Layer  5: square side=5.0, centered at origin
  ✓ GDS file created
  ✓ Contains 5 layers with centered squares

TEST 2: Create layer configuration (equal thickness = 1)
----------------------------------------------------------------------
  Layer configuration (bottom to top):
    Layer  1 (GDS  1): z=[ 4,  5], thickness=1, color=#FF8000
    Layer  2 (GDS  2): z=[ 3,  4], thickness=1, color=#BF8040
    Layer  3 (GDS  3): z=[ 2,  3], thickness=1, color=#808080
    Layer  4 (GDS  4): z=[ 1,  2], thickness=1, color=#4080BF
    Layer  5 (GDS  5): z=[ 0,  1], thickness=1, color=#0080FF
  ✓ Layer config created
  ✓ All layers have thickness = 1 unit
  ✓ Tower height: 5 units (z=0 to z=5)

TEST 3: Convert GDS to STL format
----------------------------------------------------------------------
  Running gds_to_step with format=stl...
  [conversion pipeline output...]
  ✓ STL conversion successful
  ✓ Output file: tower_N5.stl

TEST 4: Convert GDS to STEP format
----------------------------------------------------------------------
  Running gds_to_step with format=step...
  [Either succeeds or falls back to STL]

TEST 5: Verify tower geometry properties
----------------------------------------------------------------------
  [Verification output...]

================================================================
  TEST SUMMARY: 3D Tower Functionality (N=5)
================================================================
Tests passed: 5
Tests failed: 0

✓ ALL TESTS PASSED
```

## API Usage Demonstrated

### Creating GDS structures programmatically

```octave
% Create library
glib = gds_library('TowerLib', 'uunit', 1e-6, 'dbunit', 1e-9);

% Create structure
gstruct = gds_structure('TowerCell');

% Add boundary elements (squares) on different layers
for k = 1:N
    side_length = k;
    half_side = side_length / 2.0;
    xy_coords = [-half_side, -half_side;
                 half_side, -half_side;
                 half_side,  half_side;
                -half_side,  half_side;
                -half_side, -half_side];
    
    rect = gds_element('boundary', 'xy', xy_coords, 'layer', k, 'dtype', 0);
    gstruct = add_element(gstruct, rect);
end

% Add to library and write
glib = add_struct(glib, gstruct);
write_gds_library(glib, 'tower.gds', 'verbose', 0);
```

### Creating layer configuration

```octave
% For each layer k (1 to N)
layer_config = {
    "gds_layer": k,
    "gds_datatype": 0,
    "name": "layer_k",
    "z_bottom": N - k,      % Bottom at 0, top at N
    "z_top": N - k + 1,     % Uniform thickness of 1
    "material": "material_name",
    "color": "#RRGGBB"
};
% Save as JSON
```

### Converting to 3D formats

```octave
% Convert to STL
gds_to_step('input.gds', 'config.json', 'output.stl', 
            'format', 'stl', 'verbose', 1);

% Convert to STEP (requires pythonOCC)
gds_to_step('input.gds', 'config.json', 'output.step', 
            'format', 'step', 'verbose', 1);
```

## Requirements

### Essential
- GNU Octave 4.2.0+
- gdsii-toolbox-146 library

### Optional
- Python 3.x with pythonOCC (for STEP format)
- Note: Without pythonOCC, test still passes using STL format

## File Structure

```
test_tower_functionality.m          # Main test script
README_TOWER_TEST.md                # Detailed documentation
TOWER_TEST_QUICKSTART.md            # This file

test_output_tower_N5/               # Output for N=5
├── tower_N5.gds                    # GDS file
├── tower_config_N5.json            # Layer config
└── tower_N5.stl                    # STL output

test_output_tower_N7/               # Output for N=7
├── tower_N7.gds
├── tower_config_N7.json
└── tower_N7.stl
```

## Troubleshooting

### Test fails with "N must be >= 3"
- Use at least 3 layers: `test_tower_functionality(3)`

### STEP conversion not available
- This is expected if pythonOCC is not installed
- Test will still pass using STL format
- STL files can be converted to STEP using external tools

### Output files not found
- Check the test_output_tower_N<N> directory
- Verify write permissions in the tests directory

## Next Steps

After running the test:
1. View the generated STL files in a 3D viewer (e.g., MeshLab, FreeCAD)
2. Inspect the layer configuration JSON
3. Examine the GDS file with a GDS viewer
4. Modify the test to create different geometries

## Related Documentation

- `README_TOWER_TEST.md` - Full test documentation
- `test_section_4_6_and_4_7.m` - Library method tests
- `test_integration_4_6_to_4_10.m` - Integration tests
- `../gds_to_step.m` - Main conversion function documentation

## Support

For issues or questions:
- Check the test output for error messages
- Review the main documentation in README_TOWER_TEST.md
- Examine the source code in test_tower_functionality.m
