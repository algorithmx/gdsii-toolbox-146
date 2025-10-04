# Layer Configuration Files

This directory contains layer stack configuration files for converting GDSII 2D layouts to 3D STEP models.

## Files

### Configuration Schema
- **`config_schema.json`** - JSON Schema definition for validation

### Example Configurations
- **`ihp_sg13g2.json`** - IHP SG13G2 130nm BiCMOS (real PDK data)
- **`example_generic_cmos.json`** - Generic 3-metal CMOS template

## Configuration File Format

Layer configuration files are JSON documents that map GDSII layer numbers to 3D physical parameters.

### Minimal Example

```json
{
  "project": "My Process",
  "units": "micrometers",
  "layers": [
    {
      "gds_layer": 8,
      "gds_datatype": 0,
      "name": "Metal1",
      "z_bottom": 0.5,
      "z_top": 0.9,
      "thickness": 0.4,
      "material": "aluminum",
      "color": "#0000ff"
    }
  ]
}
```

### Required Fields

| Field | Type | Description |
|-------|------|-------------|
| `project` | string | Project or process name |
| `units` | string | Unit system: "micrometers", "nanometers", etc. |
| `layers` | array | Array of layer definitions |

### Layer Definition Fields

#### Required
- `gds_layer` (integer 0-255) - GDSII layer number
- `gds_datatype` (integer 0-255) - GDSII datatype
- `name` (string) - Layer name (alphanumeric, starting with letter)
- `z_bottom` (number) - Bottom Z-coordinate
- `z_top` (number) - Top Z-coordinate
- `thickness` (number) - Layer thickness (should equal z_top - z_bottom)

#### Optional
- `material` (string) - Material name ("aluminum", "copper", "tungsten", etc.)
- `color` (string) - Hex color code for visualization ("#RRGGBB")
- `opacity` (number 0-1) - Opacity for visualization
- `description` (string) - Human-readable description
- `enabled` (boolean) - Whether to include layer in conversion (default: true)
- `fill_type` (string) - "solid", "via", "dummy", or "filler"
- `properties` (object) - Additional properties (resistance, min_width, etc.)

## Creating Your Own Configuration

### Option 1: Start from Template

Copy `example_generic_cmos.json` and modify:

```bash
cp example_generic_cmos.json my_process.json
# Edit my_process.json with your layer numbers and z-heights
```

### Option 2: Extract from LEF File

If you have a LEF technology file:

1. Look for `LAYER` blocks with `HEIGHT` and `THICKNESS` keywords
2. Extract the values and create JSON entries
3. Map GDSII layer numbers from your layer mapping file

Example LEF data:
```lef
LAYER Metal1
  HEIGHT 0.930        # z_top
  THICKNESS 0.40      # thickness
  # z_bottom = HEIGHT - THICKNESS = 0.53
END Metal1
```

Becomes:
```json
{
  "gds_layer": 8,
  "gds_datatype": 0,
  "name": "Metal1",
  "z_bottom": 0.53,
  "z_top": 0.93,
  "thickness": 0.40
}
```

### Option 3: From Cross-Section Script

If you have a KLayout cross-section script (.xs file):

1. Look for `t_layername` thickness variables
2. Calculate cumulative z-heights
3. Create JSON entries

## Validation

Validate your configuration against the schema:

```bash
# Using Python jsonschema
pip install jsonschema
python3 << EOF
import json
import jsonschema

with open('config_schema.json') as f:
    schema = json.load(f)
    
with open('my_process.json') as f:
    config = json.load(f)
    
jsonschema.validate(config, schema)
print("Configuration is valid!")
EOF
```

## Common Materials

Standard material names for consistency:

| Material | Typical Use |
|----------|-------------|
| `silicon` | Substrate |
| `silicon_active` | Active areas (source/drain) |
| `polysilicon` | Gate electrodes |
| `SiO2` | Oxide dielectric |
| `aluminum` | Metal interconnect |
| `copper` | Metal interconnect (advanced nodes) |
| `tungsten` | Vias and contacts |
| `titanium` | Barrier layers |
| `tantalum` | Barrier layers |

## Units

Specify units consistently. Common choices:

- **`micrometers`** (recommended) - Good for most IC processes (0.1-10 μm features)
- **`nanometers`** - Better precision for advanced nodes (<100nm)
- **`millimeters`** - For MEMS or large-scale devices

All z-coordinates and thicknesses in the file use the specified units.

## Conversion Options

Optional global settings:

```json
"conversion_options": {
  "substrate_thickness": 10.0,
  "passivation_thickness": 2.0,
  "merge_vias_with_metals": false,
  "simplify_polygons": false,
  "tolerance": 0.001
}
```

## Tips

1. **Layer Ordering**: List layers in order from bottom to top for clarity
2. **Via Overlap**: Vias often overlap with metal layers - this is normal
3. **Disabled Layers**: Set `"enabled": false` to skip dummy/filler layers
4. **Colors**: Use distinctive colors for easy visual identification
5. **Documentation**: Include `reference` field pointing to source PDK docs

## Troubleshooting

### Z-Heights Don't Match
- Check if your LEF uses `HEIGHT` (z_top) vs cumulative heights
- Verify thickness = z_top - z_bottom
- Ensure units are consistent

### Missing Layers
- Check GDSII layer mapping file (.map)
- Verify layer numbers match your GDS file
- Use `gdsii-toolbox` `layerinfo()` to inspect GDS layers

### Overlapping Layers
- This is often intentional (vias overlap metals)
- Use `merge_vias_with_metals` option if needed
- Consider using 3D Boolean operations in conversion

## Examples

See the included example files for complete working configurations.

## Support

For issues or questions:
- Check the main implementation plan: `GDS_TO_STEP_IMPLEMENTATION_PLAN.md`
- Review PDK analysis: `IHP_PDK_LAYER_ANALYSIS.md`
- Examine the JSON schema: `config_schema.json`

---

**Version:** 1.0  
**Date:** October 4, 2025
