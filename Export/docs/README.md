# GDSII-to-STEP Export Functions

This directory contains functions for converting GDSII layout files to 3D STEP models suitable for mechanical CAD, FEM analysis, and 3D visualization.

## Overview

The GDSII-to-3D conversion workflow consists of:

1. **Layer Configuration** - Define the 3D physical properties (z-heights, materials) for each GDSII layer
2. **Layer Extraction** - Extract polygon geometry organized by layer
3. **3D Extrusion** - Convert 2D polygons to 3D solids (future implementation)
4. **STEP Export** - Write 3D geometry to STEP file format (future implementation)

## Current Status

**✅ Phase 1 Complete: Layer Configuration System**

- `gds_read_layer_config.m` - JSON configuration file parser
- `gds_layer_to_3d.m` - Layer extraction and organization
- Comprehensive test suite and documentation
- Example configurations (generic CMOS, IHP SG13G2)

**✅ Phase 2 Complete: 3D Extrusion & Export**

- `gds_extrude_polygon.m` - 2D polygon to 3D solid extrusion
- `gds_write_stl.m` - STL file export (MVP, no dependencies)
- `gds_write_step.m` - STEP file export (via Python pythonOCC)
- `private/step_writer.py` - Python backend for STEP generation
- Full test suite with 7 passing tests

**🚧 Future Phases:**

- Phase 3: Main conversion pipeline (`gds_to_step.m`)
- Phase 4: Library methods and CLI tools
- Phase 5: Advanced features (Boolean operations, optimization)

---

## Installation

1. Ensure the gdsii-toolbox-146 is installed and working
2. Add the Export directory to your MATLAB/Octave path:

```matlab
addpath('Export');
addpath(genpath('Basic'));
```

---

## Quick Start

### Example 1: Load Configuration and Extract Layers

```matlab
% Read GDS library
glib = read_gds_library('design.gds');

% Load layer configuration
cfg = gds_read_layer_config('layer_configs/ihp_sg13g2.json');

% Extract layers organized for 3D conversion
layer_data = gds_layer_to_3d(glib, cfg);

% Access extracted data
for k = 1:length(layer_data.layers)
    L = layer_data.layers(k);
    fprintf('Layer %s: %d polygons, area = %.2f um^2\n', ...
            L.config.name, L.num_polygons, L.area);
end
```

### Example 2: Filter Specific Layers

```matlab
% Extract only metal layers
cfg = gds_read_layer_config('layer_configs/ihp_sg13g2.json');
layer_data = gds_layer_to_3d(glib, cfg, ...
    'layers_filter', [8 10 30 50 67], ...  % Metal1-5
    'enabled_only', true);
```

### Example 3: Create Custom Configuration

```matlab
% Define simple 2-layer configuration
config = struct();
config.project = 'My Design';
config.units = 'micrometers';
config.layers = [
    struct('gds_layer', 1, 'gds_datatype', 0, ...
           'name', 'Active', 'z_bottom', 0.0, 'z_top', 0.5, ...
           'thickness', 0.5, 'material', 'Silicon', 'enabled', true)
    struct('gds_layer', 10, 'gds_datatype', 0, ...
           'name', 'Metal1', 'z_bottom', 0.5, 'z_top', 1.0, ...
           'thickness', 0.5, 'material', 'Aluminum', 'enabled', true)
];

% Or load from JSON file
cfg = gds_read_layer_config('my_config.json');
```

---

## Function Reference

### `gds_read_layer_config`

**Purpose:** Reads and parses JSON layer configuration files.

**Syntax:**
```matlab
layer_config = gds_read_layer_config(config_file)
```

**Inputs:**
- `config_file` - String path to JSON configuration file

**Outputs:**
- `layer_config` - Structure containing:
  - `.metadata` - Project info (name, foundry, process, units, etc.)
  - `.layers(n)` - Array of layer definitions with 3D parameters
  - `.conversion_options` - Conversion settings
  - `.layer_map` - Fast lookup table [256×256]

**Example:**
```matlab
cfg = gds_read_layer_config('layer_configs/ihp_sg13g2.json');
fprintf('Project: %s\n', cfg.metadata.project);
fprintf('Units: %s\n', cfg.metadata.units);
fprintf('Number of layers: %d\n', length(cfg.layers));

% Quick layer lookup
idx = cfg.layer_map(11, 1);  % Find layer 10, datatype 0 (1-indexed)
if idx > 0
    L = cfg.layers(idx);
    fprintf('Found: %s at z=[%.3f, %.3f]\n', L.name, L.z_bottom, L.z_top);
end
```

**Features:**
- Validates JSON structure and required fields
- Parses color specifications (hex, RGB, named colors)
- Checks thickness consistency (z_top - z_bottom = thickness)
- Creates fast lookup map for layer/datatype queries
- Compatible with MATLAB R2016b+ and Octave 4.2+

---

### `gds_layer_to_3d`

**Purpose:** Extracts GDSII layer data organized for 3D extrusion.

**Syntax:**
```matlab
layer_data = gds_layer_to_3d(gds_input, layer_config)
layer_data = gds_layer_to_3d(gds_input, layer_config, 'param', value, ...)
```

**Inputs:**
- `gds_input` - gds_library or gds_structure object
- `layer_config` - Configuration structure or path to JSON file

**Optional Parameters:**
- `'structure_name'` - Name of structure to extract (default: top-level)
- `'layers_filter'` - Vector of layer numbers to extract (default: all)
- `'datatypes_filter'` - Vector of datatype numbers (default: all)
- `'enabled_only'` - Only extract enabled layers (default: true)
- `'flatten'` - Flatten structure hierarchy (default: true)
- `'convert_paths'` - Convert path elements to boundaries (default: true)

**Outputs:**
- `layer_data` - Structure containing:
  - `.metadata` - Copy of configuration metadata
  - `.layers(n)` - Extracted layer data with polygons
  - `.statistics` - Extraction statistics (time, counts)

**Example:**
```matlab
% Extract from library
glib = read_gds_library('chip.gds');
layer_data = gds_layer_to_3d(glib, 'layer_configs/ihp_sg13g2.json');

% Extract specific structure
layer_data = gds_layer_to_3d(glib, cfg, 'structure_name', 'TopCell');

% Extract only certain layers
layer_data = gds_layer_to_3d(glib, cfg, ...
    'layers_filter', [1 8 10], ...        % Active, Metal1, Metal2
    'enabled_only', true);

% Access polygons
for k = 1:length(layer_data.layers)
    L = layer_data.layers(k);
    fprintf('\nLayer: %s (%.3f to %.3f um)\n', ...
            L.config.name, L.config.z_bottom, L.config.z_top);
    
    for p = 1:L.num_polygons
        poly = L.polygons{p};  % Nx2 matrix [x, y]
        fprintf('  Polygon %d: %d vertices\n', p, size(poly, 1));
        % Ready for 3D extrusion using L.config.z_bottom, L.config.z_top
    end
end
```

**Performance Notes:**
- Flattening deep hierarchies may take time for large designs
- Use `'layers_filter'` to extract only needed layers
- Use `'enabled_only', true` to skip disabled layers
- Path-to-boundary conversion is approximate (perpendicular offset)

---

## Layer Configuration Files

Configuration files are stored in the `layer_configs/` directory.

### Available Configurations

| File | Description |
|------|-------------|
| `ihp_sg13g2.json` | IHP SG13G2 130nm BiCMOS process (15 layers) |
| `example_generic_cmos.json` | Generic 3-metal CMOS template |
| `test_config.json` | Minimal test configuration (3 layers) |

### Configuration File Format

JSON files define layer mappings with this structure:

```json
{
  "project": "Project Name",
  "foundry": "Foundry Name",
  "process": "Process Node",
  "units": "micrometers",
  "date": "2025-10-04",
  "version": "1.0",
  
  "layers": [
    {
      "gds_layer": 8,
      "gds_datatype": 0,
      "name": "Metal1",
      "z_bottom": 0.53,
      "z_top": 0.93,
      "thickness": 0.40,
      "material": "aluminum",
      "color": "#0000ff",
      "opacity": 0.9,
      "enabled": true,
      "properties": {
        "resistance_per_square": 0.135,
        "conductivity": 3.77e7
      }
    }
  ],
  
  "conversion_options": {
    "substrate_thickness": 10.0,
    "tolerance": 1e-6
  }
}
```

### Required Fields

Each layer must have:
- `gds_layer` - GDSII layer number (0-255)
- `gds_datatype` - GDSII datatype (0-255)
- `name` - Layer name (string)
- `z_bottom` - Bottom z-coordinate in units
- `z_top` - Top z-coordinate in units

### Optional Fields

- `thickness` - Layer thickness (computed if omitted)
- `material` - Material name
- `color` - Display color (hex "#RRGGBB", RGB array, or named color)
- `opacity` - Display opacity (0.0 to 1.0)
- `enabled` - Enable/disable layer (default: true)
- `description` - Layer description
- `fill_type` - "solid" or "via"
- `properties` - Additional key-value properties

See `layer_configs/README.md` and `LAYER_CONFIG_SPEC.md` for full documentation.

---

## Creating Layer Configurations

### Method 1: From Template

Copy and modify an example:

```bash
cp layer_configs/example_generic_cmos.json layer_configs/my_design.json
# Edit my_design.json with your layer stack
```

### Method 2: From LEF File

Extract layer information from technology LEF:

```bash
# Look for LAYER definitions in .lef file
grep -A 20 "^LAYER" technology.lef

# Extract z-heights (OFFSET values)
# Extract thicknesses (HEIGHT values)
# Map to GDS layer numbers from .map file
```

### Method 3: From Cross-Section Script

Many PDKs include process cross-section scripts (`.xs` files for KLayout):

```ruby
# Example from .xs file:
layer("Metal1", 0.53, 0.40)  # name, z_bottom, thickness
```

Convert these to JSON format following the schema.

### Method 4: Programmatically

```matlab
% Build configuration structure
cfg = struct();
cfg.project = 'My Process';
cfg.units = 'micrometers';

cfg.layers = [];
% Add layers...
cfg.layers(1).gds_layer = 1;
cfg.layers(1).gds_datatype = 0;
cfg.layers(1).name = 'Active';
cfg.layers(1).z_bottom = 0.0;
cfg.layers(1).z_top = 0.5;
cfg.layers(1).thickness = 0.5;
cfg.layers(1).enabled = true;

% Save to JSON
json_text = jsonencode(cfg);
fid = fopen('my_config.json', 'w');
fprintf(fid, '%s', json_text);
fclose(fid);
```

---

## Testing

Run the test suite:

```matlab
cd gdsii-toolbox-146
run('Export/tests/test_layer_functions.m')
```

Or from Octave command line:

```bash
cd gdsii-toolbox-146
octave --no-gui Export/tests/test_layer_functions.m
```

Tests cover:
- Configuration file loading and validation
- Layer extraction from GDSII structures
- Layer filtering and enabled-only modes
- Error handling
- Color parsing
- Thickness validation

---

## Troubleshooting

### "Configuration file not found"

Ensure the path is correct. Use absolute paths or paths relative to current directory:

```matlab
cfg = gds_read_layer_config('layer_configs/ihp_sg13g2.json');
% or
cfg = gds_read_layer_config('/full/path/to/config.json');
```

### "jsondecode not found" (Octave < 4.2)

Upgrade Octave or use an external JSON parser like JSONlab:

```matlab
% Download JSONlab from: https://github.com/fangq/jsonlab
addpath('path/to/jsonlab');
```

### "Layer not found in configuration"

The GDSII layer/datatype is not defined in your configuration. Either:
1. Add the layer to your JSON configuration
2. Use `'enabled_only', false` to see all layers in GDS file
3. Check that GDS layer numbers match configuration

### Thickness inconsistency warning

```
warning: Layer 13 (TopMetal1): thickness=2.000000 but z_top-z_bottom=1.000000
```

This indicates z_top - z_bottom ≠ thickness in the configuration. Fix the JSON file to ensure consistency.

### Path conversion issues

Path-to-boundary conversion uses simple perpendicular offset. For complex paths:
- Use Boolean operations in Phase 2
- Pre-convert paths to boundaries in KLayout/other tool
- Set `'convert_paths', false` and handle separately

---

## Integration with Other Tools

### KLayout

Export layer properties file compatible with KLayout:

```matlab
cfg = gds_read_layer_config('layer_configs/ihp_sg13g2.json');

% Generate .lyp (layer properties) file
fid = fopen('design.lyp', 'w');
fprintf(fid, '<?xml version="1.0" encoding="utf-8"?>\n');
fprintf(fid, '<layer-properties>\n');
for k = 1:length(cfg.layers)
    L = cfg.layers(k);
    fprintf(fid, '  <properties>\n');
    fprintf(fid, '    <source>%d/%d@1</source>\n', L.gds_layer, L.gds_datatype);
    fprintf(fid, '    <name>%s</name>\n', L.name);
    color_hex = sprintf('#%02X%02X%02X', ...
        round(L.color(1)*255), round(L.color(2)*255), round(L.color(3)*255));
    fprintf(fid, '    <fill-color>%s</fill-color>\n', color_hex);
    fprintf(fid, '  </properties>\n');
end
fprintf(fid, '</layer-properties>\n');
fclose(fid);
```

### FreeCAD

Once Phase 2 (extrusion) and Phase 3 (STEP export) are complete, import to FreeCAD:

```python
import FreeCAD
import Import

# Import generated STEP file
Import.insert('design_3d.step', 'MyDoc')
```

### FEM Tools (Elmer, COMSOL, ANSYS)

STEP files can be imported into most FEM packages for electromagnetic, thermal, or mechanical simulation.

---

## API Compatibility

### MATLAB

- Minimum version: R2016b (requires `jsondecode`)
- Tested with: R2020a, R2023b

### GNU Octave

- Minimum version: 4.2.0 (requires `jsondecode`)
- Tested with: 6.4.0, 8.4.0
- Note: Some class method handling differs; see test suite for workarounds

---

## Documentation

| Document | Description |
|----------|-------------|
| `README.md` | This file - main usage guide |
| `LAYER_CONFIG_SPEC.md` | Technical specification for layer configurations |
| `PHASE1_COMPLETE.md` | Phase 1 completion summary |
| `GDS_TO_STEP_IMPLEMENTATION_PLAN.md` | Full project roadmap |
| `layer_configs/README.md` | Layer configuration user guide |

---

## Examples and Demos

See `tests/` directory for working examples of:
- Creating test GDSII structures
- Loading configurations
- Extracting layers
- Filtering and processing

---

## Future Enhancements (Planned)

### Phase 2: 3D Extrusion
- `gds_extrude_polygon.m` - Convert 2D polygons to 3D solids
- Boolean operations (union, difference, intersection)
- Via merging with metal layers
- Polygon simplification and cleanup

### Phase 3: STEP Export  
- `gds_to_step.m` - Main conversion function
- `gds_write_step.m` - STEP AP203/AP214 file writer
- Hierarchical assembly support
- Material and color export

### Phase 4: Advanced Features
- Curved polygon support (circular vias, rounded corners)
- Multi-threading for large designs
- Incremental/streaming processing
- GUI interface

---

## Contributing

To contribute improvements:

1. Follow existing code style and documentation patterns
2. Add tests for new functionality
3. Update relevant documentation
4. Ensure MATLAB/Octave compatibility

---

## License

This extension follows the gdsii-toolbox-146 license (Public Domain, with exceptions noted in original toolbox).

---

## Author

WARP AI Agent, October 2025  
Part of gdsii-toolbox-146 GDSII-to-STEP implementation

---

## Support

For issues or questions:
1. Check this README and LAYER_CONFIG_SPEC.md
2. Review test scripts for usage examples
3. Examine configuration examples in layer_configs/

---

**Status: Phase 1 Complete ✅**  
**Next: Phase 2 - 3D Extrusion Functions**

---

### `gds_extrude_polygon` (NEW - Section 4.3)

**Purpose:** Extrudes 2D polygons to 3D solids along the Z-axis.

**Syntax:**
```matlab
solid3d = gds_extrude_polygon(polygon_xy, z_bottom, z_top)
solid3d = gds_extrude_polygon(polygon_xy, z_bottom, z_top, options)
```

**Inputs:**
- `polygon_xy` - Nx2 matrix of polygon vertices [x, y]
- `z_bottom` - Bottom Z coordinate
- `z_top` - Top Z coordinate
- `options` - (Optional) structure with:
  - `.check_orientation` - Ensure CCW orientation (default: true)
  - `.simplify` - Simplify polygon (default: false)
  - `.tolerance` - Numerical tolerance (default: 1e-9)

**Outputs:**
- `solid3d` - Structure with fields:
  - `.vertices` - Mx3 matrix of 3D vertices [x, y, z]
  - `.faces` - Cell array of face definitions
  - `.volume` - Volume of the solid
  - `.bbox` - Bounding box [xmin ymin zmin xmax ymax zmax]

**Example:**
```matlab
% Create a simple rectangular prism
poly = [0 0; 10 0; 10 5; 0 5];
solid = gds_extrude_polygon(poly, 0, 2);

fprintf('Volume: %.2f\n', solid.volume);  % 100.00
fprintf('Bbox: [%.1f %.1f %.1f %.1f %.1f %.1f]\n', solid.bbox);
```

**Status:** ✅ Complete - 10/10 tests passing

---

## Testing

Run the test suite:

```bash
cd Export/tests
octave --eval "addpath('../'); test_extrusion();"
```

**Current Test Status:**
- ✅ `test_extrusion.m` - 10/10 tests passing

---

## Implementation Progress

### Phase 1: Foundation ✅ COMPLETE

- [x] Section 4.1: Layer Configuration System
- [x] Section 4.2: Polygon Extraction by Layer  
- [x] Section 4.3: Basic Extrusion Engine

**Next:** Phase 2 - STEP File Generation (Section 4.4)

---

## Documentation

Detailed implementation summaries:
- `SECTION_4_2_IMPLEMENTATION_SUMMARY.md` - Polygon extraction
- `SECTION_4_3_IMPLEMENTATION_SUMMARY.md` - Extrusion engine
- `PHASE1_COMPLETE.md` - Overall Phase 1 summary
- `LAYER_CONFIG_SPEC.md` - Configuration file format

See `../GDS_TO_STEP_IMPLEMENTATION_PLAN.md` for the complete implementation roadmap.

