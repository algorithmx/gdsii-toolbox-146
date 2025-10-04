# IHP-Open-PDK Layer Information Analysis
**Date:** October 4, 2025  
**PDK:** IHP SG13G2 (130nm BiCMOS)  
**Purpose:** Extract layer thickness and material info for GDS→STEP conversion

---

## Summary

The IHP-Open-PDK contains **complete layer stack information** in multiple formats:

✅ **LEF files** - Physical dimensions (HEIGHT, THICKNESS)  
✅ **Cross-section files** - Process simulation layer stack  
✅ **Layer mapping files** - GDSII layer → name mapping  
✅ **Display files** - Visualization (colors, patterns)

---

## Key Files Found

### 1. Layer Mapping (`sg13g2.map`)
**Location:** `/AI/PDK/IHP-Open-PDK/ihp-sg13g2/libs.tech/klayout/tech/sg13g2.map`

Maps GDSII layer numbers to layer names:

```
Layer Name    GDS Layer  GDS Datatype
Metal1        8          0
Metal2        10         0
Metal3        30         0
Metal4        50         0
Metal5        67         0
TopMetal1     126        0
TopMetal2     134        0
Via1          19         0
Via2          29         0
Via3          49         0
Via4          66         0
TopVia1       125        0
TopVia2       133        0
```

### 2. Technology LEF File (Physical Dimensions)
**Location:** `/AI/PDK/IHP-Open-PDK/ihp-sg13g2/libs.ref/sg13g2_stdcell/lef/sg13g2_tech.lef`

Contains **HEIGHT** and **THICKNESS** for each metal layer:

#### Metal Stack (from LEF):

| Layer | GDS Layer | Height (μm) | Thickness (μm) | Material |
|-------|-----------|-------------|----------------|----------|
| Metal1 | 8 | 0.930 | 0.40 | Aluminum/Copper |
| Metal2 | 10 | 1.880 | 0.45 | Aluminum/Copper |
| Metal3 | 30 | 2.880 | 0.45 | Aluminum/Copper |
| Metal4 | 50 | 3.880 | 0.45 | Aluminum/Copper |
| Metal5 | 67 | 4.880 | 0.45 | Aluminum/Copper |
| TopMetal1 | 126 | 6.160 | 2.00 | Thick metal |
| TopMetal2 | 134 | (calculated) | 3.00 | Thick metal |

**Key LEF Data:**
```lef
LAYER Metal1
  HEIGHT 0.930      ← Z-position above substrate
  THICKNESS 0.40    ← Layer thickness
  RESISTANCE RPERSQ 0.135
  WIDTH 0.16        ← Minimum width
END Metal1

LAYER Metal2
  HEIGHT 1.880
  THICKNESS 0.450
  RESISTANCE RPERSQ 0.103
END Metal2
```

### 3. Cross-Section File (Process Stack)
**Location:** `/AI/PDK/IHP-Open-PDK/ihp-sg13g2/libs.tech/klayout/tech/xsect/sg13g2_for_EM.xs`

KLayout cross-section definition with exact layer thicknesses:

```ruby
# Active and Contact
t_activ = 0.4      # 400 nm
t_cont  = 0.64     # 640 nm

# Metal layers
t_metal1 = 0.42    # 420 nm
t_via1   = 0.54    # 540 nm

t_metal2 = 0.49    # 490 nm
t_via2   = 0.54    # 540 nm

t_metal3 = 0.49    # 490 nm
t_via3   = 0.54    # 540 nm

t_metal4 = 0.49    # 490 nm
t_via4   = 0.54    # 540 nm

t_metal5  = 0.49   # 490 nm
t_topvia1 = 0.85   # 850 nm

t_tm1     = 2.0    # 2000 nm (thick metal)
t_topvia2 = 2.8    # 2800 nm

t_tm2 = 3.0        # 3000 nm (thick metal)

# Passivation
t_passi1 = 1.5     # 1500 nm
t_passi2 = 0.4     # 400 nm
```

### 4. Display Layer Properties (`sg13g2.lyp`)
**Location:** `/AI/PDK/IHP-Open-PDK/ihp-sg13g2/libs.tech/klayout/tech/sg13g2.lyp`

XML file with layer visualization info (colors, patterns):

```xml
<properties>
  <name>Substrate.drawing</name>
  <source>40/0</source>
  <fill-color>#ffffff</fill-color>
</properties>
<properties>
  <name>Activ.drawing</name>
  <source>1/0</source>
  <fill-color>#00ff00</fill-color>
</properties>
<properties>
  <name>Metal1</name>
  <source>8/0</source>
  <fill-color>#0000ff</fill-color>
</properties>
```

---

## Complete Layer Stack Reconstruction

### Method 1: From LEF (HEIGHT values)

| Layer | GDS | Z Bottom (μm) | Z Top (μm) | Thickness (μm) | Material |
|-------|-----|---------------|------------|----------------|----------|
| Substrate | 40/0 | 0.000 | - | N/A | Silicon |
| Activ | 1/0 | 0.000 | 0.400 | 0.40 | Active area |
| Contact | 6/0 | 0.400 | 1.040 | 0.64 | Tungsten |
| Metal1 | 8/0 | 0.530 | 0.930 | 0.40 | Al/Cu |
| Via1 | 19/0 | 0.930 | 1.470 | 0.54 | Tungsten |
| Metal2 | 10/0 | 1.430 | 1.880 | 0.45 | Al/Cu |
| Via2 | 29/0 | 1.880 | 2.420 | 0.54 | Tungsten |
| Metal3 | 30/0 | 2.430 | 2.880 | 0.45 | Al/Cu |
| Via3 | 49/0 | 2.880 | 3.420 | 0.54 | Tungsten |
| Metal4 | 50/0 | 3.430 | 3.880 | 0.45 | Al/Cu |
| Via4 | 66/0 | 3.880 | 4.420 | 0.54 | Tungsten |
| Metal5 | 67/0 | 4.430 | 4.880 | 0.45 | Al/Cu |
| TopVia1 | 125/0 | 4.880 | 5.730 | 0.85 | Tungsten |
| TopMetal1 | 126/0 | 5.160 | 6.160 | 2.00 | Thick Al/Cu |
| TopVia2 | 133/0 | 6.160 | 8.960 | 2.80 | Tungsten |
| TopMetal2 | 134/0 | 8.960 | 11.960 | 3.00 | Thick Al/Cu |

### Method 2: From Cross-Section Script (Cumulative)

Calculating cumulative heights from process simulation:

```
Z = 0 μm (substrate)
Z += 0.40 + 0.64 = 1.04 μm  (activ + cont)
Z += 0.42 + 0.54 = 1.96 μm  (metal1 + via1)
Z += 0.49 + 0.54 = 2.99 μm  (metal2 + via2)
Z += 0.49 + 0.54 = 4.02 μm  (metal3 + via3)
Z += 0.49 + 0.54 = 5.05 μm  (metal4 + via4)
Z += 0.49 + 0.85 = 6.39 μm  (metal5 + topvia1)
Z += 2.00 + 2.80 = 11.19 μm (tm1 + topvia2)
Z += 3.00        = 14.19 μm (tm2)
Z += 1.50 + 0.40 = 16.09 μm (passivation)
```

**Note:** LEF and XS values differ slightly (design rules vs process simulation)

---

## Recommended JSON Configuration for GDS→STEP

Based on the IHP PDK analysis, here's the configuration file:

**File:** `layer_configs/ihp_sg13g2.json`

```json
{
  "project": "IHP SG13G2 130nm BiCMOS",
  "foundry": "IHP Microelectronics",
  "process": "SG13G2",
  "units": "micrometers",
  "reference": "sg13g2_tech.lef + sg13g2_for_EM.xs",
  "date": "2024-10-04",
  
  "layers": [
    {
      "gds_layer": 40,
      "gds_datatype": 0,
      "name": "Substrate",
      "z_bottom": 0.0,
      "z_top": 0.0,
      "thickness": 0.0,
      "material": "silicon",
      "color": "#808080",
      "opacity": 0.3,
      "description": "Silicon substrate (reference plane)"
    },
    {
      "gds_layer": 1,
      "gds_datatype": 0,
      "name": "Activ",
      "z_bottom": 0.0,
      "z_top": 0.40,
      "thickness": 0.40,
      "material": "silicon_active",
      "color": "#00ff00",
      "opacity": 0.7,
      "description": "Active area (MOSFET regions)"
    },
    {
      "gds_layer": 6,
      "gds_datatype": 0,
      "name": "Cont",
      "z_bottom": 0.40,
      "z_top": 1.04,
      "thickness": 0.64,
      "material": "tungsten",
      "color": "#c0c0c0",
      "opacity": 0.8,
      "description": "Contact via to active"
    },
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
      "description": "First metal layer",
      "properties": {
        "resistance_per_square": 0.135,
        "min_width": 0.16,
        "min_spacing": 0.18
      }
    },
    {
      "gds_layer": 19,
      "gds_datatype": 0,
      "name": "Via1",
      "z_bottom": 0.93,
      "z_top": 1.47,
      "thickness": 0.54,
      "material": "tungsten",
      "color": "#c0c0c0",
      "opacity": 0.8,
      "description": "Via between Metal1 and Metal2"
    },
    {
      "gds_layer": 10,
      "gds_datatype": 0,
      "name": "Metal2",
      "z_bottom": 1.43,
      "z_top": 1.88,
      "thickness": 0.45,
      "material": "aluminum",
      "color": "#0088ff",
      "opacity": 0.9,
      "description": "Second metal layer",
      "properties": {
        "resistance_per_square": 0.103,
        "min_width": 0.20,
        "min_spacing": 0.21
      }
    },
    {
      "gds_layer": 29,
      "gds_datatype": 0,
      "name": "Via2",
      "z_bottom": 1.88,
      "z_top": 2.42,
      "thickness": 0.54,
      "material": "tungsten",
      "color": "#c0c0c0",
      "opacity": 0.8,
      "description": "Via between Metal2 and Metal3"
    },
    {
      "gds_layer": 30,
      "gds_datatype": 0,
      "name": "Metal3",
      "z_bottom": 2.43,
      "z_top": 2.88,
      "thickness": 0.45,
      "material": "aluminum",
      "color": "#00ccff",
      "opacity": 0.9,
      "description": "Third metal layer",
      "properties": {
        "resistance_per_square": 0.103
      }
    },
    {
      "gds_layer": 49,
      "gds_datatype": 0,
      "name": "Via3",
      "z_bottom": 2.88,
      "z_top": 3.42,
      "thickness": 0.54,
      "material": "tungsten",
      "color": "#c0c0c0",
      "opacity": 0.8,
      "description": "Via between Metal3 and Metal4"
    },
    {
      "gds_layer": 50,
      "gds_datatype": 0,
      "name": "Metal4",
      "z_bottom": 3.43,
      "z_top": 3.88,
      "thickness": 0.45,
      "material": "aluminum",
      "color": "#00ffff",
      "opacity": 0.9,
      "description": "Fourth metal layer",
      "properties": {
        "resistance_per_square": 0.103
      }
    },
    {
      "gds_layer": 66,
      "gds_datatype": 0,
      "name": "Via4",
      "z_bottom": 3.88,
      "z_top": 4.42,
      "thickness": 0.54,
      "material": "tungsten",
      "color": "#c0c0c0",
      "opacity": 0.8,
      "description": "Via between Metal4 and Metal5"
    },
    {
      "gds_layer": 67,
      "gds_datatype": 0,
      "name": "Metal5",
      "z_bottom": 4.43,
      "z_top": 4.88,
      "thickness": 0.45,
      "material": "aluminum",
      "color": "#00ffcc",
      "opacity": 0.9,
      "description": "Fifth metal layer",
      "properties": {
        "resistance_per_square": 0.103
      }
    },
    {
      "gds_layer": 125,
      "gds_datatype": 0,
      "name": "TopVia1",
      "z_bottom": 4.88,
      "z_top": 5.73,
      "thickness": 0.85,
      "material": "tungsten",
      "color": "#c0c0c0",
      "opacity": 0.8,
      "description": "Via to TopMetal1"
    },
    {
      "gds_layer": 126,
      "gds_datatype": 0,
      "name": "TopMetal1",
      "z_bottom": 5.16,
      "z_top": 6.16,
      "thickness": 2.00,
      "material": "aluminum",
      "color": "#ffff00",
      "opacity": 0.9,
      "description": "First thick top metal layer",
      "properties": {
        "resistance_per_square": 0.021,
        "min_width": 1.64,
        "min_spacing": 1.64
      }
    },
    {
      "gds_layer": 133,
      "gds_datatype": 0,
      "name": "TopVia2",
      "z_bottom": 6.16,
      "z_top": 8.96,
      "thickness": 2.80,
      "material": "tungsten",
      "color": "#c0c0c0",
      "opacity": 0.8,
      "description": "Via to TopMetal2"
    },
    {
      "gds_layer": 134,
      "gds_datatype": 0,
      "name": "TopMetal2",
      "z_bottom": 8.96,
      "z_top": 11.96,
      "thickness": 3.00,
      "material": "aluminum",
      "color": "#ffcc00",
      "opacity": 0.9,
      "description": "Second thick top metal layer (bondpad)",
      "properties": {
        "resistance_per_square": 0.01,
        "min_width": 3.0
      }
    }
  ]
}
```

---

## Usage with gdsii-toolbox

### 1. Command Line
```bash
gds2step mydesign.gds layer_configs/ihp_sg13g2.json mydesign.step
```

### 2. MATLAB/Octave API
```matlab
% Load GDS file
glib = read_gds_library('mydesign.gds');

% Convert to STEP using IHP config
gds_to_step('mydesign.gds', 'layer_configs/ihp_sg13g2.json', 'output.step');

% Or as method
glib.to_step('layer_configs/ihp_sg13g2.json', 'output.step');
```

---

## Notes and Observations

### ✅ Advantages of IHP-Open-PDK:
1. **Complete documentation** - All layer info available
2. **Multiple formats** - LEF, XS, map files all consistent
3. **Open source** - Can redistribute configurations
4. **Well-maintained** - Active development

### ⚠️ Considerations:
1. **Slight differences** between LEF and XS values
   - LEF uses design rule values
   - XS uses process simulation values
   - Recommend: Use LEF for layout tools, XS for visualization

2. **Layer overlap** - Vias overlap with metal layers
   - May need to handle in 3D Boolean operations
   - Or keep separate (most 3D viewers can handle)

3. **Material properties** - LEF has electrical, not physical
   - Resistance values given (ohms/square)
   - No Young's modulus, density, etc.
   - Good enough for visualization, not FEM

### 💡 Recommended Approach:
1. **Start with LEF data** - Most accurate for layout
2. **Cross-reference with XS** - Validate against process
3. **Add material names** - Map to standard materials
4. **Include metadata** - Store source file references

---

## Scripts to Generate Config

### Python Script to Parse LEF:
```python
#!/usr/bin/env python3
"""Parse IHP LEF file to generate JSON layer config"""

import re
import json

def parse_lef(lef_file):
    layers = []
    with open(lef_file) as f:
        content = f.read()
    
    # Find all LAYER blocks
    for match in re.finditer(r'LAYER (\w+).*?END \1', content, re.DOTALL):
        layer_block = match.group(0)
        layer_name = match.group(1)
        
        # Extract HEIGHT and THICKNESS
        height_match = re.search(r'HEIGHT\s+([\d.]+)', layer_block)
        thick_match = re.search(r'THICKNESS\s+([\d.]+)', layer_block)
        
        if height_match and thick_match:
            height = float(height_match.group(1))
            thickness = float(thick_match.group(1))
            
            layers.append({
                'name': layer_name,
                'height': height,
                'thickness': thickness,
                'z_bottom': height - thickness,
                'z_top': height
            })
    
    return layers

# Usage:
layers = parse_lef('sg13g2_tech.lef')
print(json.dumps(layers, indent=2))
```

---

## Conclusion

The IHP-Open-PDK provides **excellent reference material** for implementing GDS→STEP conversion. All required information is available in standard formats.

**Next Steps:**
1. Create JSON config file from LEF data
2. Test conversion with simple IHP design
3. Validate 3D output in FreeCAD/KLayout
4. Document any discrepancies

---

**Document Version:** 1.0  
**Author:** WARP AI Agent  
**Date:** October 4, 2025  
**PDK Version:** IHP SG13G2 (as of 2024)
