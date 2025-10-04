# Layer Configuration Data Structure Specification

**Version:** 1.0  
**Date:** October 4, 2025  
**Status:** Phase 1 Implementation Complete

---

## Overview

This document defines the layer configuration data structure used for GDSII to STEP 3D conversion. The structure is designed to be:

- **Practical**: Based on real PDK data (IHP SG13G2)
- **Extensible**: Supports additional properties without breaking compatibility
- **Validated**: JSON Schema for automatic validation
- **Industry-aligned**: Compatible with LEF, technology files, and cross-section scripts

---

## Design Rationale

### Why JSON?

1. **Human-readable and editable** - Text editor friendly
2. **Language-agnostic** - Works with MATLAB, Python, any language
3. **Schema validation** - JSON Schema for error checking
4. **Widely supported** - Native parsers in all modern environments
5. **Version-controllable** - Git-friendly plain text format

### Why External Configuration?

As established in the PDK analysis:
- GDSII files contain **NO** material or thickness information
- Industry standard practice uses separate technology files
- Allows same GDSII to be visualized with different process definitions
- Enables process-specific customization without modifying code

---

## Data Structure Design

### Three-Level Hierarchy

```
Configuration File (JSON)
├── Metadata (project, foundry, units, etc.)
├── Layer Array (list of layer definitions)
│   ├── Layer 1
│   │   ├── GDSII mapping (gds_layer, gds_datatype)
│   │   ├── 3D geometry (z_bottom, z_top, thickness)
│   │   ├── Visualization (color, opacity)
│   │   └── Properties (material, resistance, etc.)
│   ├── Layer 2
│   └── ...
└── Conversion Options (defaults for this configuration)
```

### MATLAB/Octave Representation

When loaded into MATLAB/Octave, the configuration becomes a structure:

```matlab
config = 
  struct with fields:
    
    project: 'IHP SG13G2 130nm BiCMOS'
    foundry: 'IHP Microelectronics'
    units: 'micrometers'
    layers: [15×1 struct]  % Array of layer structures
    conversion_options: [1×1 struct]
```

Each layer in the array:

```matlab
config.layers(1) =
  struct with fields:
    
    gds_layer: 8
    gds_datatype: 0
    name: 'Metal1'
    z_bottom: 0.53
    z_top: 0.93
    thickness: 0.40
    material: 'aluminum'
    color: '#0000ff'
    opacity: 0.9
    description: 'First metal layer'
    enabled: 1
    fill_type: 'solid'
    properties: [1×1 struct]
```

---

## Field Specifications

### Top-Level Metadata

| Field | Type | Required | Description | Example |
|-------|------|----------|-------------|---------|
| `project` | string | **Yes** | Project/process name | "IHP SG13G2 130nm BiCMOS" |
| `foundry` | string | No | Manufacturer name | "IHP Microelectronics" |
| `process` | string | No | Process identifier | "SG13G2" |
| `units` | string | **Yes** | Unit system | "micrometers" |
| `reference` | string | No | Source document | "sg13g2_tech.lef v1.0" |
| `date` | string | No | Config creation date | "2025-10-04" |
| `version` | string | No | Config version | "1.0" |
| `notes` | string | No | Additional comments | "Extracted from..." |

**Units Enumeration:**
- `"micrometers"` (recommended for most IC processes)
- `"nanometers"` (for advanced nodes)
- `"millimeters"` (for MEMS)
- `"meters"` (for large-scale devices)

### Layer Definition

| Field | Type | Range | Required | Description |
|-------|------|-------|----------|-------------|
| `gds_layer` | integer | 0-255 | **Yes** | GDSII layer number |
| `gds_datatype` | integer | 0-255 | **Yes** | GDSII datatype |
| `name` | string | [A-Za-z][A-Za-z0-9_]* | **Yes** | Layer name |
| `z_bottom` | number | any | **Yes** | Bottom Z-coordinate |
| `z_top` | number | any | **Yes** | Top Z-coordinate |
| `thickness` | number | ≥0 | **Yes** | Layer thickness |
| `material` | string | any | No | Material name |
| `color` | string | #RRGGBB | No | Hex color code |
| `opacity` | number | 0.0-1.0 | No | Transparency |
| `description` | string | any | No | Human description |
| `enabled` | boolean | true/false | No | Include in conversion |
| `fill_type` | string | enum | No | Fill type |

**Fill Type Enumeration:**
- `"solid"` - Regular metal/poly layers
- `"via"` - Via/contact layers
- `"dummy"` - Dummy fill (usually excluded)
- `"filler"` - Filler patterns (usually excluded)

**Name Pattern:** Must start with letter, contain only alphanumeric and underscore

**Validation Rules:**
- `thickness` should equal `z_top - z_bottom` (with floating-point tolerance)
- `z_top` must be greater than `z_bottom`
- `gds_layer` and `gds_datatype` pair should be unique within configuration

### Layer Properties Object

Optional nested structure for additional metadata:

| Property | Type | Units | Description |
|----------|------|-------|-------------|
| `resistance_per_square` | number | Ω/□ | Sheet resistance |
| `min_width` | number | config units | Minimum feature width |
| `min_spacing` | number | config units | Minimum spacing |
| `conductivity` | number | S/m | Electrical conductivity |
| `density` | number | kg/m³ | Material density |
| `youngs_modulus` | number | Pa | Young's modulus |
| `poissons_ratio` | number | dimensionless | Poisson's ratio |
| `thermal_conductivity` | number | W/(m·K) | Thermal conductivity |

All properties are optional and extensible.

### Conversion Options

Global defaults for conversion process:

| Option | Type | Default | Description |
|--------|------|---------|-------------|
| `substrate_thickness` | number | 0 | Substrate below z=0 |
| `passivation_thickness` | number | 0 | Passivation above top |
| `merge_vias_with_metals` | boolean | false | Merge via/metal layers |
| `simplify_polygons` | boolean | false | Simplify geometry |
| `tolerance` | number | 0.001 | Simplification tolerance |

---

## Implementation Details

### JSON Schema Validation

The configuration is validated against JSON Schema (Draft-07):

**Location:** `layer_configs/config_schema.json`

**Validation in MATLAB/Octave:**
- Will use `jsondecode()` for parsing (MATLAB R2016b+)
- Manual validation of required fields
- Type checking and range validation

**Validation in Python:**
```python
import json, jsonschema

with open('config_schema.json') as f:
    schema = json.load(f)
with open('my_config.json') as f:
    config = json.load(f)
jsonschema.validate(config, schema)
```

### Unit Conversion

All z-coordinates and thicknesses in the file use the `units` specified in metadata.

**Conversion factors to meters:**
```matlab
unit_factors = struct(...
    'meters', 1.0, ...
    'millimeters', 1e-3, ...
    'micrometers', 1e-6, ...
    'nanometers', 1e-9 ...
);
```

When reading GDSII library with different units:
```matlab
% GDS library units
glib.uunit = 1e-6;  % 1 micrometer

% Config units
config_factor = unit_factors.(config.units);  % 1e-6 for micrometers

% Scale factor
scale = glib.uunit / config_factor;
```

### Layer Lookup Optimization

For efficient layer lookup during conversion:

```matlab
% Create hash map: layer/datatype -> layer_info
layer_map = containers.Map('KeyType', 'char', 'ValueType', 'any');

for k = 1:length(config.layers)
    layer = config.layers(k);
    if layer.enabled
        key = sprintf('%d/%d', layer.gds_layer, layer.gds_datatype);
        layer_map(key) = layer;
    end
end

% Fast lookup during conversion
key = sprintf('%d/%d', gds_layer, gds_datatype);
if layer_map.isKey(key)
    layer_info = layer_map(key);
    % Use layer_info for extrusion
end
```

---

## Design Decisions

### 1. Z-Coordinates vs Cumulative Thickness

**Decision:** Store both `z_bottom`, `z_top`, AND `thickness`

**Rationale:**
- Different source files use different representations
- LEF files specify `HEIGHT` (z_top) and `THICKNESS`
- Cross-section scripts use cumulative heights
- Redundancy allows validation (thickness should equal z_top - z_bottom)
- User can specify what they know, we validate consistency

### 2. GDSII Layer + Datatype

**Decision:** Both fields required

**Rationale:**
- GDSII uses layer/datatype pairs for complete specification
- Datatype often distinguishes pin vs net vs fill
- Industry practice uses datatype (e.g., Metal1 0=drawing, 2=pin, 22=fill)
- Most users will use datatype=0, but flexibility is important

### 3. Material as String vs Enum

**Decision:** Free-form string, not enumerated

**Rationale:**
- Impossible to enumerate all possible materials
- Users may have proprietary alloys
- Process-specific naming ("aluminum" vs "AlCu" vs "Al-0.5%Cu")
- Can add common materials list in documentation as guidance
- Future: Could add material database lookup

### 4. Color Specification

**Decision:** Hex color codes (#RRGGBB)

**Rationale:**
- Universal standard
- Easy to specify and parse
- Compatible with all 3D viewers
- Can extract from PDK .lyp (layer properties) files
- Alternative formats (RGB arrays, named colors) can be converted

### 5. Enabled Flag

**Decision:** Include explicit `enabled` boolean

**Rationale:**
- Allows disabling layers without deleting from config
- Useful for dummy fill, filler, or test layers
- Can temporarily exclude layers for faster testing
- Default to `true` if not specified

### 6. Properties as Extensible Object

**Decision:** Nested `properties` object with no fixed schema

**Rationale:**
- Different users need different properties
- Electrical: resistance, conductivity
- Mechanical: Young's modulus, Poisson's ratio
- Thermal: thermal conductivity
- Cannot predict all use cases
- Allows forward compatibility
- Parser ignores unknown properties

---

## Example Configurations

### Minimal Configuration

```json
{
  "project": "Simple Test",
  "units": "micrometers",
  "layers": [
    {
      "gds_layer": 1,
      "gds_datatype": 0,
      "name": "Metal1",
      "z_bottom": 0.0,
      "z_top": 0.5,
      "thickness": 0.5
    }
  ]
}
```

### Full-Featured Configuration

See `layer_configs/ihp_sg13g2.json` for complete real-world example with:
- 15 layers (activ, metals, vias)
- Material properties
- Electrical properties
- Colors and visualization
- Conversion options

---

## Compatibility

### Source Formats

The configuration design is compatible with:

✅ **LEF files** - Direct mapping from HEIGHT/THICKNESS  
✅ **Technology files** - Layer names and properties  
✅ **Cross-section scripts** - Cumulative thickness calculations  
✅ **Layer maps** - GDSII layer number mappings  
✅ **Display files (.lyp)** - Color and visualization  

### Target Tools

Configurations can be generated for:

- **This toolbox** - Primary target
- **KLayout 3D viewer** - Similar structure to .lyp
- **FreeCAD import** - Material and color metadata
- **FEM tools** - Material properties for simulation

---

## Future Extensions

### Planned (Backward Compatible)

1. **Material Database:**
   ```json
   "material": "aluminum",
   "material_id": "AL_1100"  // Links to materials database
   ```

2. **Process Variations:**
   ```json
   "variants": {
     "nominal": {"thickness": 0.40},
     "thin": {"thickness": 0.38},
     "thick": {"thickness": 0.42}
   }
   ```

3. **Via Rules:**
   ```json
   "via_rules": {
     "min_enclosure": 0.05,
     "max_aspect_ratio": 2.0
   }
   ```

4. **Conditional Layers:**
   ```json
   "conditions": {
     "if_layer_present": 134,  // Only include if layer 134 exists
     "if_option": "include_vias"
   }
   ```

### Under Consideration

- **Layer groups** - Group related layers (metal stack, via stack)
- **Templates** - Inherit from base configuration
- **Expressions** - Calculate z-heights from formulas
- **References** - Link multiple config files

All extensions will maintain backward compatibility with v1.0 schema.

---

## Validation Checklist

When creating a configuration:

- [ ] All required fields present
- [ ] Units specified and consistent
- [ ] Layer names are valid identifiers
- [ ] Layer/datatype pairs are unique
- [ ] `thickness = z_top - z_bottom` (within tolerance)
- [ ] `z_top > z_bottom` for all layers
- [ ] Colors are valid hex codes (#RRGGBB)
- [ ] Opacity values between 0.0 and 1.0
- [ ] References to source documentation included
- [ ] Test with JSON schema validator

---

## Summary

The layer configuration data structure provides:

✅ **Complete information** for 2D→3D conversion  
✅ **Industry-standard** compatibility  
✅ **Real-world validated** with IHP PDK data  
✅ **Extensible** for future enhancements  
✅ **Well-documented** with examples and schema  

This design enables robust, maintainable, and user-friendly GDSII to STEP conversion.

---

**Document Version:** 1.0  
**Author:** WARP AI Agent  
**Date:** October 4, 2025  
**Status:** Implementation Ready
