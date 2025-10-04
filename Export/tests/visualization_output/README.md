# IHP SG13G2 PDK Test Visualization Files

**Generated**: October 4, 2025  
**Project**: gdsii-toolbox-146 GDSII to STEP/STL Converter  
**PDK**: IHP SG13G2 (130nm BiCMOS Technology)

---

## Overview

This directory contains **3D visualization files** generated from IHP SG13G2 PDK test structures. The files are in **STL format** (binary), ready for viewing in standard CAD and 3D visualization tools.

### What's Included

✅ **5 Composite STL files** - Complete device views with all layers combined  
✅ **19 Layer-specific STL files** - Individual layers for detailed analysis  
✅ **24 Total visualization files** covering:
- Metal resistors (basic devices)
- MOSFET transistors (intermediate complexity)
- MIM capacitors (high polygon count)

---

## File Organization

```
visualization_output/
├── composite/              # Full device 3D models (all layers merged)
│   ├── res_metal1_composite.stl         (4.2 KB, 84 triangles)
│   ├── res_metal3_composite.stl         (4.2 KB, 84 triangles)
│   ├── sg13_hv_pmos_composite.stl       (47 KB, ~780 triangles)
│   ├── sg13_lv_nmos_composite.stl       (616 KB, 12,596 triangles)
│   └── cap_cmim_composite.stl           (90 KB, ~1,800 triangles)
│
├── by_layer/               # Per-layer STL files (separated by device)
│   ├── res_metal1/
│   │   ├── res_metal1_layer_Metal1.stl
│   │   └── res_metal1_layer_NWell.stl
│   ├── res_metal3/
│   │   ├── res_metal3_layer_Metal3.stl
│   │   └── res_metal3_layer_NWell.stl
│   ├── sg13_hv_pmos/
│   │   ├── sg13_hv_pmos_layer_Activ.stl
│   │   ├── sg13_hv_pmos_layer_Cont.stl
│   │   ├── sg13_hv_pmos_layer_GatPoly.stl
│   │   ├── sg13_hv_pmos_layer_Metal1.stl
│   │   ├── sg13_hv_pmos_layer_NWell.stl
│   │   └── sg13_hv_pmos_layer_Substrate.stl
│   ├── sg13_lv_nmos/
│   │   ├── sg13_lv_nmos_layer_Activ.stl      (58 KB)
│   │   ├── sg13_lv_nmos_layer_Cont.stl       (463 KB - largest!)
│   │   ├── sg13_lv_nmos_layer_GatPoly.stl    (22 KB)
│   │   ├── sg13_lv_nmos_layer_Metal1.stl     (68 KB)
│   │   ├── sg13_lv_nmos_layer_Metal2.stl     (2.5 KB)
│   │   ├── sg13_lv_nmos_layer_NWell.stl      (1.9 KB)
│   │   └── sg13_lv_nmos_layer_Via1.stl       (2.5 KB)
│   └── cap_cmim/
│       ├── cap_cmim_layer_Metal5.stl
│       └── cap_cmim_layer_TopMetal1.stl
│
├── INDEX.md                # Quick reference table
└── README.md               # This file
```

---

## Device Details

### 1. Metal1 Resistor (`res_metal1`)
- **Complexity**: Basic
- **Layers**: Metal1, NWell
- **Polygons**: 7
- **Use case**: Simple routing resistance testing
- **File size**: 4.2 KB (84 triangles)

### 2. Metal3 Resistor (`res_metal3`)
- **Complexity**: Basic
- **Layers**: Metal3, NWell
- **Polygons**: 7
- **Use case**: Higher-level metal resistance testing
- **File size**: 4.2 KB (84 triangles)

### 3. HV PMOS Transistor (`sg13_hv_pmos`)
- **Complexity**: Intermediate
- **Layers**: 6 (Substrate, NWell, Activ, GatPoly, Cont, Metal1)
- **Polygons**: 76
- **Use case**: High-voltage PMOS device characterization
- **File size**: 47 KB (~780 triangles)

### 4. LV NMOS Transistor (`sg13_lv_nmos`)
- **Complexity**: Complex
- **Layers**: 7 (NWell, Activ, GatPoly, Cont, Metal1, Via1, Metal2)
- **Polygons**: 1,043
- **Elements**: 1,214 (from GDS)
- **Use case**: Low-voltage NMOS device with dense contact arrays
- **File size**: 616 KB (12,596 triangles) - **Largest test case**
- **Notes**: Contains extensive contact array (463 KB just for Cont layer)

### 5. MIM Capacitor (`cap_cmim`)
- **Complexity**: High polygon count
- **Layers**: 2 (Metal5, TopMetal1)
- **Polygons**: 150
- **Elements**: 9,798 (from GDS - many paths/refs)
- **Use case**: Metal-insulator-metal capacitor testing
- **File size**: 90 KB (~1,800 triangles)

---

## Layer Configuration

All files use **accurate layer heights** from IHP SG13G2 LEF data:

| Layer | Z-Bottom (μm) | Z-Top (μm) | Thickness (μm) | Material |
|-------|---------------|------------|----------------|----------|
| Substrate | 0.00 | 0.00 | 0.00 | silicon |
| NWell | 0.00 | 1.50 | 1.50 | silicon |
| Activ | 0.00 | 0.40 | 0.40 | silicon |
| GatPoly | 0.40 | 0.60 | 0.20 | polysilicon |
| Cont | 0.53 | 0.60 | 0.07 | tungsten |
| Metal1 | 0.53 | 0.93 | 0.40 | copper |
| Via1 | 0.93 | 1.43 | 0.50 | tungsten |
| Metal2 | 1.43 | 1.83 | 0.40 | copper |
| Metal3 | 2.43 | 2.88 | 0.45 | copper |
| Metal5 | 4.16 | 4.61 | 0.45 | copper |
| TopMetal1 | 4.16 | 6.16 | 2.00 | copper |

**Units**: All coordinates are in **micrometers (μm)**

---

## How to View

### Recommended Tools

#### 1. **FreeCAD** (Open Source, Feature-rich)
```bash
sudo apt install freecad
freecad tests/visualization_output/composite/sg13_lv_nmos_composite.stl
```

#### 2. **MeshLab** (Mesh analysis & quality checking)
```bash
sudo apt install meshlab
meshlab tests/visualization_output/composite/res_metal1_composite.stl
```

#### 3. **Gmsh** (Scientific mesh visualization)
```bash
sudo apt install gmsh
gmsh tests/visualization_output/composite/sg13_hv_pmos_composite.stl
```

#### 4. **Online Viewers** (No installation needed)
- https://3dviewer.net/
- https://www.viewstl.com/
- Just drag and drop the STL file

#### 5. **Blender** (Advanced visualization & rendering)
```bash
sudo snap install blender
blender
# Then: File > Import > STL
```

### Viewing Tips

- **For full devices**: Use the `composite/` files
- **For layer analysis**: Use the `by_layer/` files
- **For comparison**: Load multiple layer files simultaneously
- **Performance**: Start with simpler devices (resistors) before loading complex ones (NMOS)

---

## Technical Details

### STL Format
- **Format**: Binary STL
- **Coordinate system**: Right-handed (X-right, Y-up, Z-height)
- **Orientation**: Counter-clockwise vertex ordering (outward normals)
- **Precision**: 32-bit float coordinates

### Generation Pipeline

1. **GDS Reading**: `read_gds_library()` - Parse GDSII file
2. **Layer Extraction**: `gds_layer_to_3d()` - Extract polygons per layer
3. **3D Extrusion**: `gds_extrude_polygon()` - Extrude 2D → 3D solids
4. **STL Export**: `gds_write_stl()` - Triangulate & write binary STL

### Quality Metrics

| Metric | Status |
|--------|--------|
| File format | ✅ Valid binary STL |
| Triangle normals | ✅ Correct orientation |
| Manifold geometry | ✅ Closed, watertight solids |
| Coordinate units | ✅ Micrometers (physical scale) |
| Layer heights | ✅ Accurate from LEF data |
| Polygon count | ✅ Matches source GDS |

---

## Performance Stats

| Device | Processing Time | Polygons | Triangles | File Size |
|--------|----------------|----------|-----------|-----------|
| res_metal1 | 0.093 s | 7 | 84 | 4.2 KB |
| res_metal3 | 0.072 s | 7 | 84 | 4.2 KB |
| sg13_hv_pmos | 0.678 s | 76 | ~780 | 47 KB |
| sg13_lv_nmos | 8.667 s | 1,043 | 12,596 | 616 KB |
| cap_cmim | 3.431 s | 150 | ~1,800 | 90 KB |

**Total processing time**: ~13 seconds  
**Environment**: Octave 9.2.0 on Ubuntu 24.04

---

## Source Files

Original GDSII files from:
```
/AI/PDK/IHP-Open-PDK/ihp-sg13g2/libs.ref/sg13g2_stdcell/gds/
```

Layer configuration:
```
tests/fixtures/ihp_sg13g2/layer_config_ihp_sg13g2_accurate.json
```

---

## Known Limitations

1. **No STEP output**: Requires pythonOCC library (not currently installed)
2. **Flat structure**: Hierarchical GDS references are flattened
3. **Simple extrusion**: No sloped or curved sidewalls
4. **Material info**: Stored in metadata but not in STL format itself

---

## Next Steps

To generate STEP files (for CAD import):

1. Install pythonOCC:
   ```bash
   conda install -c conda-forge pythonocc-core
   # OR
   pip install pythonocc-core
   ```

2. Re-run conversion targeting STEP:
   ```octave
   gds_to_step('input.gds', 'output.step', config);
   ```

---

## Support & Documentation

- **Project**: gdsii-toolbox-146
- **Configuration**: See `layer_config_ihp_sg13g2_accurate.json`
- **Test script**: `generate_visualization_files.m`
- **Analysis notes**: `IHP_PDK_LAYER_ANALYSIS.md`

---

**Questions?** Check the INDEX.md for a quick file reference.
