# GDS to STEP Implementation Plan
**Date:** October 4, 2025  
**Codebase:** gdsii-toolbox-146  
**Purpose:** Design document for implementing GDSII to STEP 3D model conversion

---

## 1. Executive Summary

This plan outlines the integration of a **GDS to STEP conversion module** into the existing gdsii-toolbox architecture. The implementation will respect the codebase's modular design, build on existing functionality, and follow established patterns for file I/O and data processing.

**Key Design Principles:**
- Extend, don't rebuild - leverage existing 2D polygon handling
- Maintain consistency with existing directory structure and naming conventions
- Follow the toolbox's object-oriented design patterns
- Minimize external dependencies where possible
- Provide both library API and command-line interfaces

---

## 2. Architecture Analysis

### 2.1 Current Codebase Structure

```
gdsii-toolbox-146/
├── Basic/                  # Core classes and low-level I/O
│   ├── @gds_library/      # Library object methods
│   ├── @gds_structure/    # Structure object methods  
│   ├── @gds_element/      # Element object methods
│   ├── gdsio/             # MEX functions (C/C++)
│   └── funcs/             # Utility functions
├── Elements/              # High-level element creators
├── Structures/            # High-level structure creators
├── Boolean/               # Polygon Boolean operations (Clipper)
├── Scripts/               # Command-line utilities
└── experiment_code/       # Development/testing area
```

### 2.2 Object Hierarchy (Existing)

```
gds_library
  ├── lname, uunit, dbunit
  ├── st[] (array of gds_structure)
  └── methods: write_gds_library(), treeview(), topstruct()

gds_structure  
  ├── sname, cdate, mdate
  ├── el[] (array of gds_element)
  └── methods: add_element(), poly_convert(), bbox()

gds_element
  ├── data.xy (polygon coordinates)
  ├── data.layer, data.dtype
  ├── data.internal (element type)
  └── methods: poly_bool(), poly_area(), layer()
```

### 2.3 Integration Points

The new module will integrate at multiple levels:

1. **Basic/**: New class methods for STEP export
2. **Scripts/**: Command-line utility for batch conversion
3. **New directory**: `Export/` for export-specific functionality
4. **Configuration**: External JSON/YAML layer configuration files

---

## 3. Proposed Module Architecture

### 3.1 New Directory Structure

```
gdsii-toolbox-146/
├── Export/                       # NEW: Export functionality
│   ├── Contents.m               # Module documentation
│   ├── gds_to_step.m            # Main conversion function
│   ├── gds_read_layer_config.m  # Parse layer configuration
│   ├── gds_extrude_polygon.m    # 2D → 3D extrusion
│   ├── gds_layer_to_3d.m        # Layer processing
│   ├── gds_flatten_for_3d.m     # Hierarchy flattening
│   ├── gds_write_step.m         # STEP file writer interface
│   └── private/                 # Internal helper functions
│       ├── polygon_to_brep.m    # Polygon → B-rep conversion
│       ├── step_entity_writer.m # STEP entity generation
│       └── validate_layer_config.m
├── Basic/
│   └── @gds_library/
│       └── to_step.m            # NEW: Method for gds_library class
├── Scripts/
│   └── gds2step                 # NEW: Command-line tool
└── layer_configs/               # NEW: Example configurations
    ├── example_cmos.json
    ├── example_mems.json
    └── config_schema.json
```

### 3.2 Data Flow Architecture

```
┌──────────────────────────────────────────────────────────────┐
│                    INPUT: GDSII File                         │
└────────────────────┬─────────────────────────────────────────┘
                     │
                     ▼
         ┌───────────────────────┐
         │  read_gds_library()   │  (Existing)
         │  Returns: gds_library │
         └───────────┬───────────┘
                     │
                     ▼
         ┌───────────────────────────┐
         │ gds_read_layer_config()   │  (NEW)
         │ Returns: layer_config     │
         └───────────┬───────────────┘
                     │
                     ▼
         ┌───────────────────────────┐
         │  gds_flatten_for_3d()     │  (NEW)
         │  Resolves hierarchy       │
         │  Returns: flat_polygons   │
         └───────────┬───────────────┘
                     │
                     ▼
         ┌───────────────────────────┐
         │   gds_layer_to_3d()       │  (NEW)
         │   For each layer:         │
         │   - Extract polygons      │
         │   - Map to z-height       │
         └───────────┬───────────────┘
                     │
                     ▼
         ┌───────────────────────────┐
         │  gds_extrude_polygon()    │  (NEW)
         │  2D → 3D solid            │
         │  Returns: 3d_solid        │
         └───────────┬───────────────┘
                     │
                     ▼
         ┌───────────────────────────┐
         │  3D Boolean Operations    │  (NEW/Optional)
         │  Merge/subtract solids    │
         └───────────┬───────────────┘
                     │
                     ▼
         ┌───────────────────────────┐
         │    gds_write_step()       │  (NEW)
         │    Generate STEP file     │
         └───────────┬───────────────┘
                     │
                     ▼
┌────────────────────────────────────────────────────────────┐
│                   OUTPUT: STEP File                        │
└────────────────────────────────────────────────────────────┘
```

---

## 4. Detailed Implementation Plan

### Phase 1: Foundation (Week 1-2)

#### 4.1 Layer Configuration System

**File:** `Export/gds_read_layer_config.m`

```matlab
function layer_config = gds_read_layer_config(config_file)
% GDS_READ_LAYER_CONFIG - Parse layer configuration file
%
% layer_config = gds_read_layer_config(config_file)
%
% Reads a JSON or YAML file defining layer-to-3D mappings
%
% INPUT:
%   config_file : path to JSON/YAML configuration file
%
% OUTPUT:
%   layer_config : structure with fields:
%       .layers(i).gds_layer   - GDSII layer number
%       .layers(i).gds_datatype - GDSII datatype
%       .layers(i).name        - Layer name (string)
%       .layers(i).z_bottom    - Bottom Z coordinate
%       .layers(i).z_top       - Top Z coordinate
%       .layers(i).material    - Material name (optional)
%       .layers(i).color       - Display color (optional)
%       .units                 - Unit system ('nanometers', 'micrometers', etc.)
```

**Configuration File Format (JSON):**

```json
{
  "project": "Example Design",
  "units": "nanometers",
  "layers": [
    {
      "gds_layer": 1,
      "gds_datatype": 0,
      "name": "substrate",
      "z_bottom": 0,
      "z_top": 500000,
      "material": "silicon",
      "color": "#808080"
    },
    {
      "gds_layer": 10,
      "gds_datatype": 0,
      "name": "poly",
      "z_bottom": 500000,
      "z_top": 500200,
      "material": "polysilicon",
      "color": "#FF0000"
    }
  ]
}
```

#### 4.2 Polygon Extraction by Layer

**File:** `Export/gds_layer_to_3d.m`

```matlab
function layer_polygons = gds_layer_to_3d(glib, layer_config)
% GDS_LAYER_TO_3D - Extract and organize polygons by layer
%
% layer_polygons = gds_layer_to_3d(glib, layer_config)
%
% Extracts polygons from all structures and organizes them by layer
% according to the layer configuration.
%
% INPUT:
%   glib         : gds_library object
%   layer_config : layer configuration structure
%
% OUTPUT:
%   layer_polygons : structure array with fields:
%       .layer_info  - Layer configuration from layer_config
%       .polygons    - Cell array of Nx2 polygon coordinates
%       .num_polygons - Number of polygons on this layer
```

**Implementation Strategy:**
- Iterate through all structures in library
- For each element, check layer/datatype against config
- Collect boundary element polygons
- Convert path elements to boundaries using existing `poly_path()`
- Convert text elements to boundaries using existing `poly_text()`
- Store in organized structure

#### 4.3 Basic Extrusion Engine

**File:** `Export/gds_extrude_polygon.m`

```matlab
function solid3d = gds_extrude_polygon(polygon_xy, z_bottom, z_top, options)
% GDS_EXTRUDE_POLYGON - Extrude 2D polygon to 3D solid
%
% solid3d = gds_extrude_polygon(polygon_xy, z_bottom, z_top)
% solid3d = gds_extrude_polygon(polygon_xy, z_bottom, z_top, options)
%
% Creates a 3D solid by extruding a 2D polygon along the Z-axis
%
% INPUT:
%   polygon_xy : Nx2 matrix of polygon vertices [x, y]
%   z_bottom   : Bottom Z coordinate
%   z_top      : Top Z coordinate
%   options    : (Optional) structure with fields:
%       .check_orientation - Ensure CCW orientation (default: true)
%       .simplify - Simplify polygon before extrusion (default: false)
%
% OUTPUT:
%   solid3d : structure representing 3D solid with fields:
%       .vertices  - Mx3 matrix of 3D vertices
%       .faces     - Cell array of face definitions
%       .top_face  - Indices of top face vertices
%       .bottom_face - Indices of bottom face vertices
%       .side_faces - Cell array of side face indices
```

**Extrusion Algorithm:**
1. Validate and orient polygon (CCW for outer boundary)
2. Create bottom face at z_bottom
3. Create top face at z_top
4. For each edge in polygon:
   - Create rectangular side face connecting bottom and top vertices
5. Return structured 3D representation

---

### Phase 2: STEP File Generation (Week 3-4)

#### 4.4 STEP Writer Interface

**Approach Decision Matrix:**

| Approach | Pros | Cons | Recommendation |
|----------|------|------|----------------|
| **A: OpenCASCADE** | Full STEP support, robust | Heavy dependency, complex | Best for production |
| **B: Direct STEP writing** | No dependencies | Very complex, error-prone | Not recommended |
| **C: STL + external converter** | Simple, portable | Two-step process, limited | Good for MVP |
| **D: Python pythonOCC bridge** | Modern API, good balance | Requires Python | **Recommended for Phase 2** |

**Selected Approach: Hybrid (C for MVP, D for production)**

#### 4.4.1 MVP: STL Export (Simpler format)

**File:** `Export/gds_write_stl.m`

```matlab
function gds_write_stl(solids, filename, options)
% GDS_WRITE_STL - Write 3D solids to STL file
%
% gds_write_stl(solids, filename)
% gds_write_stl(solids, filename, options)
%
% Writes an array of 3D solids to STL format (ASCII or binary)
%
% INPUT:
%   solids   : structure array of 3D solids from gds_extrude_polygon()
%   filename : output STL file path
%   options  : (Optional) structure with fields:
%       .format - 'ascii' or 'binary' (default: 'binary')
%       .units  - Unit scaling factor
```

**STL Format (simpler than STEP):**
```
solid name
  facet normal nx ny nz
    outer loop
      vertex x1 y1 z1
      vertex x2 y2 z2
      vertex x3 y3 z3
    endloop
  endfacet
endsolid
```

#### 4.4.2 Production: STEP Export via Python

**File:** `Export/gds_write_step.m`

```matlab
function gds_write_step(solids, filename, options)
% GDS_WRITE_STEP - Write 3D solids to STEP file
%
% gds_write_step(solids, filename)
% gds_write_step(solids, filename, options)
%
% Writes an array of 3D solids to STEP AP203/AP214 format
% Uses Python pythonOCC bridge for STEP generation
%
% INPUT:
%   solids   : structure array of 3D solids
%   filename : output STEP file path
%   options  : (Optional) structure with fields:
%       .format     - 'AP203' or 'AP214' (default: 'AP203')
%       .precision  - Geometric tolerance (default: 1e-6)
%       .materials  - Include material metadata
%
% REQUIRES:
%   - Python 3.x with pythonOCC installed
%   - System python must be accessible via system() calls
```

**Implementation:**
1. Export solid data to temporary JSON file
2. Call Python script: `python3 step_writer.py input.json output.step`
3. Python script uses pythonOCC to generate STEP file
4. Clean up temporary files

**File:** `Export/private/step_writer.py`

```python
#!/usr/bin/env python3
"""
STEP file writer using pythonOCC
Called from MATLAB/Octave via system()
"""

import json
import sys
from OCC.Core.BRepPrimAPI import BRepPrimAPI_MakeBox
from OCC.Core.STEPControl import STEPControl_Writer, STEPControl_AsIs
from OCC.Core.IFSelect import IFSelect_RetDone

def create_extruded_solid(polygon, z_bottom, z_top):
    """Convert polygon + height to OCC solid"""
    # Implementation using pythonOCC primitives
    pass

def write_step(solids_json, output_file):
    """Generate STEP file from solid definitions"""
    with open(solids_json, 'r') as f:
        solids = json.load(f)
    
    step_writer = STEPControl_Writer()
    
    for solid_data in solids:
        solid = create_extruded_solid(
            solid_data['polygon'],
            solid_data['z_bottom'],
            solid_data['z_top']
        )
        step_writer.Transfer(solid, STEPControl_AsIs)
    
    status = step_writer.Write(output_file)
    if status != IFSelect_RetDone:
        raise RuntimeError("STEP write failed")

if __name__ == '__main__':
    write_step(sys.argv[1], sys.argv[2])
```

---

### Phase 3: Integration & High-Level API (Week 5-6)

#### 4.5 Main Conversion Function

**File:** `Export/gds_to_step.m`

```matlab
function gds_to_step(gds_file, layer_config_file, output_file, options)
% GDS_TO_STEP - Convert GDSII layout to STEP 3D model
%
% gds_to_step(gds_file, layer_config_file, output_file)
% gds_to_step(gds_file, layer_config_file, output_file, options)
%
% Main function for GDSII to STEP conversion pipeline
%
% INPUT:
%   gds_file          : Path to input GDSII file
%   layer_config_file : Path to layer configuration JSON
%   output_file       : Path to output STEP file
%   options           : (Optional) structure with fields:
%       .window     - [x_min y_min x_max y_max] (extract region only)
%       .layers     - Cell array of layer names to process
%       .flatten    - Boolean, flatten hierarchy (default: true)
%       .merge      - Boolean, merge overlapping solids (default: false)
%       .format     - 'step' or 'stl' (default: 'step')
%       .verbose    - 0, 1, or 2 (default: 1)
%
% EXAMPLE:
%   gds_to_step('chip.gds', 'cmos_config.json', 'chip.step');
%
%   % With windowing
%   opts.window = [0 0 1000 1000];  % 1000x1000 um region
%   opts.layers = {'poly', 'metal1', 'metal2'};
%   gds_to_step('chip.gds', 'config.json', 'chip.step', opts);
```

**Implementation Pipeline:**
```matlab
function gds_to_step(gds_file, layer_config_file, output_file, options)
    % 1. Read inputs
    glib = read_gds_library(gds_file);
    layer_config = gds_read_layer_config(layer_config_file);
    
    % 2. Apply window if specified
    if isfield(options, 'window')
        glib = gds_window_library(glib, options.window);
    end
    
    % 3. Flatten hierarchy with transformations
    if options.flatten
        flat_lib = gds_flatten_for_3d(glib);
    else
        flat_lib = glib;
    end
    
    % 4. Extract polygons by layer
    layer_polygons = gds_layer_to_3d(flat_lib, layer_config);
    
    % 5. Extrude polygons to 3D
    all_solids = [];
    for k = 1:length(layer_polygons)
        layer = layer_polygons(k);
        for p = 1:length(layer.polygons)
            solid = gds_extrude_polygon(layer.polygons{p}, ...
                                        layer.layer_info.z_bottom, ...
                                        layer.layer_info.z_top);
            solid.material = layer.layer_info.material;
            solid.color = layer.layer_info.color;
            all_solids = [all_solids, solid];
        end
    end
    
    % 6. Optional: merge overlapping solids
    if options.merge
        all_solids = gds_merge_solids_3d(all_solids);
    end
    
    % 7. Write output file
    if strcmp(options.format, 'stl')
        gds_write_stl(all_solids, output_file);
    else
        gds_write_step(all_solids, output_file);
    end
    
    if options.verbose
        fprintf('Converted %d polygons to %d 3D solids\n', ...
                total_polygons, length(all_solids));
        fprintf('Output written to: %s\n', output_file);
    end
end
```

#### 4.6 Library Class Method

**File:** `Basic/@gds_library/to_step.m`

```matlab
function to_step(glib, layer_config_file, output_file, varargin)
% TO_STEP - Export library to STEP 3D model
%
% glib.to_step(layer_config_file, output_file)
% glib.to_step(layer_config_file, output_file, 'option', value, ...)
%
% Method for gds_library class to export to STEP format
%
% INPUT:
%   glib              : gds_library object (implicit self)
%   layer_config_file : Path to layer configuration
%   output_file       : Path to output STEP file
%   varargin          : Optional property/value pairs (same as gds_to_step)
%
% EXAMPLE:
%   glib = read_gds_library('design.gds');
%   glib.to_step('config.json', 'design.step', 'verbose', 2);

    % Parse options
    options = parse_options(varargin);
    
    % Call main conversion function with library already loaded
    gds_to_step_from_library(glib, layer_config_file, output_file, options);
end
```

**Rationale:** Follows existing pattern where `write_gds_library()` is both:
- A standalone function: `write_gds_library(glib, file)`
- A class method: `glib.write_gds_library(file)`

#### 4.7 Command-Line Script

**File:** `Scripts/gds2step`

```bash
#!/usr/bin/env octave -qf
# gds2step - Convert GDSII to STEP from command line
#
# Usage: gds2step input.gds config.json output.step [options]

# Add toolbox to path
addpath(genpath(fileparts(mfilename('fullpath'))));

# Parse command-line arguments
args = argv();

if length(args) < 3
    fprintf('Usage: gds2step input.gds config.json output.step [options]\n');
    fprintf('Options:\n');
    fprintf('  --window=x1,y1,x2,y2  Extract region only\n');
    fprintf('  --layers=layer1,layer2,...  Process specific layers\n');
    fprintf('  --format=step|stl     Output format (default: step)\n');
    fprintf('  --verbose=0|1|2       Verbosity level (default: 1)\n');
    exit(1);
end

input_gds = args{1};
config_file = args{2};
output_file = args{3};

# Parse additional options
options = struct();
options.verbose = 1;
options.flatten = true;
options.format = 'step';

for k = 4:length(args)
    arg = args{k};
    if strncmp(arg, '--', 2)
        # Parse --key=value format
        eq_pos = strfind(arg, '=');
        if ~isempty(eq_pos)
            key = arg(3:eq_pos-1);
            value = arg(eq_pos+1:end);
            options.(key) = parse_value(value);
        end
    end
end

# Perform conversion
try
    gds_to_step(input_gds, config_file, output_file, options);
    fprintf('Conversion successful!\n');
    exit(0);
catch err
    fprintf('Error: %s\n', err.message);
    exit(1);
end
```

**Installation:** Copy to `/usr/local/bin/` or add `Scripts/` to PATH

---

### Phase 4: Advanced Features (Week 7-8)

#### 4.8 Hierarchy Flattening

**File:** `Export/gds_flatten_for_3d.m`

```matlab
function flat_lib = gds_flatten_for_3d(glib, options)
% GDS_FLATTEN_FOR_3D - Flatten hierarchy for 3D conversion
%
% flat_lib = gds_flatten_for_3d(glib)
% flat_lib = gds_flatten_for_3d(glib, options)
%
% Flattens structure hierarchy by replacing sref/aref elements
% with transformed copies of referenced structures
%
% INPUT:
%   glib    : gds_library object
%   options : (Optional) structure with fields:
%       .top_only - Only flatten top-level structures (default: false)
%       .max_depth - Maximum depth to flatten (default: unlimited)
%
% OUTPUT:
%   flat_lib : gds_library with flattened structures
```

**Algorithm:**
1. Identify top-level structures using existing `topstruct()`
2. For each top structure, traverse hierarchy
3. For each sref/aref element:
   - Get referenced structure
   - Extract transformation matrix (rotation, scale, mirror)
   - Transform all element coordinates
   - Replace reference with transformed elements
4. Return new library with flattened structures

#### 4.9 Windowing/Region Extraction

**File:** `Export/gds_window_library.m`

```matlab
function windowed_lib = gds_window_library(glib, window_bbox, options)
% GDS_WINDOW_LIBRARY - Extract elements within bounding box
%
% windowed_lib = gds_window_library(glib, window_bbox)
%
% Creates new library containing only elements within specified window
%
% INPUT:
%   glib        : gds_library object
%   window_bbox : [x_min y_min x_max y_max] bounding box
%   options     : (Optional) structure with fields:
%       .clip   - Clip polygons at window boundary (default: false)
%       .margin - Extend window by margin (default: 0)
%
% OUTPUT:
%   windowed_lib : gds_library with filtered elements
```

**Use case:** Large chip designs - extract only active region for faster processing

#### 4.10 3D Boolean Operations

**File:** `Export/gds_merge_solids_3d.m`

```matlab
function merged_solids = gds_merge_solids_3d(solids, operation)
% GDS_MERGE_SOLIDS_3D - Perform Boolean operations on 3D solids
%
% merged_solids = gds_merge_solids_3d(solids)
% merged_solids = gds_merge_solids_3d(solids, operation)
%
% Merges overlapping 3D solids using Boolean operations
%
% INPUT:
%   solids    : Structure array of 3D solids
%   operation : 'union', 'difference', or 'intersection' (default: 'union')
%
% OUTPUT:
%   merged_solids : Structure array of merged solids
%
% NOTE: This is computationally expensive and optional
```

---

## 5. Integration with Existing Code

### 5.1 Leverage Existing Functions

| Existing Function | Usage in New Module |
|-------------------|---------------------|
| `read_gds_library()` | Read input GDSII file |
| `poly_convert()` | Convert paths/text to boundaries |
| `bbox()` | Calculate bounding boxes for windowing |
| `layer()` | Extract layer/datatype information |
| `topstruct()` | Identify top-level structures |
| `poly_area()` | Validate polygon areas |
| `poly_iscw()` / `poly_cw()` | Orient polygons correctly |

### 5.2 Follow Existing Patterns

**Naming Convention:**
- Library methods: `method_name.m` in `@gds_library/`
- Standalone functions: `gds_function_name.m` or `gdsii_function_name.m`
- Command-line tools: lowercase, no extension

**Error Handling:**
```matlab
if ~exist('config_file', 'file')
    error('gds_read_layer_config: configuration file not found --> %s', config_file);
end
```

**Verbose Output:**
```matlab
if verbose
    fprintf('Processing layer %d (%s): %d polygons\n', ...
            layer.gds_layer, layer.name, num_polygons);
end
```

**Unit Handling:**
```matlab
% Respect library units
scaling = glib.uunit / layer_config.unit_scale;
polygon_scaled = polygon_xy * scaling;
```

---

## 6. Testing Strategy

### 6.1 Test Files

Create test suite in `Export/tests/`:

```
Export/tests/
├── test_layer_config.m      # Test config parsing
├── test_polygon_extrusion.m # Test extrusion
├── test_simple_gds.m        # End-to-end test with simple file
├── test_hierarchy.m         # Test hierarchy flattening
├── test_windowing.m         # Test region extraction
├── fixtures/                # Test data
│   ├── simple_box.gds
│   ├── hierarchy.gds
│   ├── test_config.json
│   └── expected_output.step
└── README.md
```

### 6.2 Test Cases

1. **Unit Tests:**
   - Parse valid/invalid config files
   - Extrude simple rectangle
   - Extrude polygon with holes
   - Handle edge cases (degenerate polygons)

2. **Integration Tests:**
   - Convert simple single-layer design
   - Convert multi-layer stack
   - Handle hierarchy (sref/aref)
   - Apply windowing
   - Test both STL and STEP outputs

3. **Validation:**
   - Open output STEP in FreeCAD/KLayout 3D
   - Verify dimensions match input
   - Check layer ordering
   - Validate volume calculations

---

## 7. Documentation

### 7.1 User Documentation

**File:** `Export/README.md`

```markdown
# GDSII to STEP Conversion Module

## Quick Start

```matlab
% Load toolbox
addpath(genpath('path/to/gdsii-toolbox-146'));

% Convert GDS to STEP
gds_to_step('mydesign.gds', 'layer_config.json', 'mydesign.step');

% Or using library object
glib = read_gds_library('mydesign.gds');
glib.to_step('layer_config.json', 'mydesign.step');
```

## Configuration File

See `layer_configs/example_cmos.json` for template.

## Command Line Usage

```bash
gds2step mydesign.gds config.json output.step --verbose=2
```

## Requirements

- MATLAB R2014b+ or Octave 3.8+
- Python 3.x with pythonOCC (for STEP output)
- For STL output only: no external dependencies
```

### 7.2 Developer Documentation

**File:** `Export/DEVELOPER.md`

- Module architecture
- Adding new export formats
- Extending extrusion algorithms
- Performance optimization notes

### 7.3 Inline Documentation

All functions follow existing MATLAB documentation format:
```matlab
function output = my_function(input1, input2, options)
% MY_FUNCTION - Brief description
%
% output = my_function(input1, input2)
% output = my_function(input1, input2, options)
%
% Detailed description of function
%
% INPUT:
%   input1  : description
%   input2  : description
%   options : (Optional) structure with fields...
%
% OUTPUT:
%   output : description
%
% EXAMPLE:
%   result = my_function(x, y);
```

---

## 8. Development Timeline

### Week 1-2: Foundation
- [ ] Create `Export/` directory structure
- [ ] Implement `gds_read_layer_config.m`
- [ ] Implement `gds_layer_to_3d.m`
- [ ] Create example layer configs
- [ ] Write unit tests for config parsing

### Week 3-4: Core Conversion
- [ ] Implement `gds_extrude_polygon.m`
- [ ] Implement `gds_write_stl.m` (MVP)
- [ ] Create `gds_to_step.m` main function
- [ ] Test with simple single-layer design
- [ ] Test with multi-layer design

### Week 5-6: STEP Integration
- [ ] Set up Python pythonOCC environment
- [ ] Implement `step_writer.py`
- [ ] Implement `gds_write_step.m`
- [ ] Create `@gds_library/to_step.m` method
- [ ] Create `gds2step` command-line script
- [ ] Integration testing

### Week 7-8: Advanced Features
- [ ] Implement `gds_flatten_for_3d.m`
- [ ] Implement `gds_window_library.m`
- [ ] (Optional) Implement 3D Boolean operations
- [ ] Performance optimization
- [ ] Complete documentation
- [ ] Create tutorial examples

### Week 9: Polish & Release
- [ ] Complete test suite
- [ ] Fix bugs from testing
- [ ] User documentation
- [ ] Example gallery
- [ ] Update main README
- [ ] Release announcement

**Total Estimated Time:** 9 weeks (part-time) or 5-6 weeks (full-time)

---

## 9. Risks & Mitigation

| Risk | Impact | Mitigation |
|------|--------|------------|
| **STEP format complexity** | High | Use pythonOCC library; fallback to STL |
| **Python dependency issues** | Medium | Provide clear installation guide; STL alternative |
| **Performance with large files** | High | Implement windowing; process in chunks |
| **Polygon orientation errors** | Medium | Use existing `poly_cw()` methods; validate |
| **Hierarchy transformation bugs** | High | Extensive testing; validate against KLayout |
| **3D Boolean operation failures** | Medium | Make optional; provide error handling |

---

## 10. Success Criteria

### Must Have (MVP):
- ✅ Parse layer configuration files
- ✅ Extract polygons by layer from GDS
- ✅ Extrude 2D polygons to 3D solids
- ✅ Export to STL format
- ✅ Command-line tool
- ✅ Basic documentation

### Should Have:
- ✅ Export to STEP format (via pythonOCC)
- ✅ Library class method
- ✅ Hierarchy flattening
- ✅ Windowing/region extraction
- ✅ Comprehensive test suite
- ✅ Example configurations for common processes (CMOS, MEMS)

### Nice to Have:
- 3D Boolean operations
- GUI for layer configuration
- Parallel processing
- Material property export
- Visualization/preview before export

---

## 11. File Checklist

### New Files to Create:

**Core Module (`Export/`):**
- [ ] `Contents.m`
- [ ] `gds_to_step.m`
- [ ] `gds_read_layer_config.m`
- [ ] `gds_layer_to_3d.m`
- [ ] `gds_extrude_polygon.m`
- [ ] `gds_write_stl.m`
- [ ] `gds_write_step.m`
- [ ] `gds_flatten_for_3d.m`
- [ ] `gds_window_library.m`
- [ ] `README.md`
- [ ] `DEVELOPER.md`

**Private Helpers (`Export/private/`):**
- [ ] `step_writer.py`
- [ ] `validate_layer_config.m`
- [ ] `parse_json.m` (or use existing JSON parser)
- [ ] `polygon_to_brep.m`

**Library Methods (`Basic/@gds_library/`):**
- [ ] `to_step.m`

**Scripts (`Scripts/`):**
- [ ] `gds2step`

**Configuration (`layer_configs/`):**
- [ ] `example_cmos.json`
- [ ] `example_mems.json`
- [ ] `config_schema.json`

**Tests (`Export/tests/`):**
- [ ] `test_layer_config.m`
- [ ] `test_polygon_extrusion.m`
- [ ] `test_simple_gds.m`
- [ ] `test_hierarchy.m`
- [ ] `fixtures/simple_box.gds`
- [ ] `fixtures/test_config.json`

**Documentation:**
- [ ] Update main `README.md`
- [ ] Update `WARP.md`
- [ ] Create tutorial: `docs/GDS_TO_STEP_TUTORIAL.md`

---

## 12. Open Questions

1. **Units:** Should we support automatic unit conversion, or require config file units to match GDS units?
   - **Decision:** Support both - add conversion scaling factor

2. **Holes:** How to handle polygon holes (donuts)?
   - **Decision:** Use existing polygon representation; pass to pythonOCC as face with holes

3. **Overlapping layers:** Merge or keep separate?
   - **Decision:** Optional merge via `options.merge` flag

4. **Memory:** Large files may exhaust memory when fully flattened
   - **Decision:** Implement streaming/chunked processing in Phase 4

5. **Material properties:** Should we export material data to STEP?
   - **Decision:** Yes, if supported by pythonOCC; add to config file

---

## 13. Conclusion

This implementation plan provides a **structured, phased approach** to adding GDS-to-STEP conversion capability to the gdsii-toolbox. The design:

✅ **Respects existing architecture** - New `Export/` module follows established patterns  
✅ **Builds on existing code** - Leverages 70% of required functionality  
✅ **Minimizes dependencies** - STL export works standalone; STEP requires Python  
✅ **Provides flexibility** - Command-line, API, and method interfaces  
✅ **Scales incrementally** - MVP in 2 weeks, full features in 9 weeks  

The modular design allows incremental development and testing, with clear milestones and fallback options if external dependencies prove problematic.

---

**Next Steps:**
1. Review and approve this plan
2. Set up development environment (Python + pythonOCC)
3. Create `Export/` directory structure
4. Begin Phase 1 implementation

**Document Version:** 1.0  
**Author:** WARP AI Agent  
**Date:** October 4, 2025
