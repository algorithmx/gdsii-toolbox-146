# 3D Visualization Files Index

**Generated**: 04-Oct-2025 18:44:06

## File Organization

### Composite STL Files

Single files containing all layers for each device:

| Device | File | Description |
|--------|------|-------------|
| Metal1 Resistor | `res_metal1_composite.stl` | 4.2 KB |
| Metal3 Resistor | `res_metal3_composite.stl` | 4.2 KB |
| HV PMOS Transistor | `sg13_hv_pmos_composite.stl` | 46.2 KB |
| LV NMOS Transistor | `sg13_lv_nmos_composite.stl` | 615.1 KB |
| MIM Capacitor | `cap_cmim_composite.stl` | 89.9 KB |

### Separate Layer Files

Individual STL files for each layer, organized by device:

#### Metal1 Resistor (`res_metal1/`)

- `res_metal1_layer_Metal1.stl` (3.6 KB)
- `res_metal1_layer_NWell.stl` (0.7 KB)

#### Metal3 Resistor (`res_metal3/`)

- `res_metal3_layer_Metal3.stl` (3.6 KB)
- `res_metal3_layer_NWell.stl` (0.7 KB)

#### HV PMOS Transistor (`sg13_hv_pmos/`)

- `sg13_hv_pmos_layer_Activ.stl` (7.7 KB)
- `sg13_hv_pmos_layer_Cont.stl` (6.5 KB)
- `sg13_hv_pmos_layer_GatPoly.stl` (6.5 KB)
- `sg13_hv_pmos_layer_Metal1.stl` (18.6 KB)
- `sg13_hv_pmos_layer_NWell.stl` (3.0 KB)
- `sg13_hv_pmos_layer_Substrate.stl` (4.2 KB)

#### LV NMOS Transistor (`sg13_lv_nmos/`)

- `sg13_lv_nmos_layer_Activ.stl` (57.5 KB)
- `sg13_lv_nmos_layer_Cont.stl` (463.0 KB)
- `sg13_lv_nmos_layer_GatPoly.stl` (21.2 KB)
- `sg13_lv_nmos_layer_Metal1.stl` (67.3 KB)
- `sg13_lv_nmos_layer_Metal2.stl` (2.4 KB)
- `sg13_lv_nmos_layer_NWell.stl` (1.8 KB)
- `sg13_lv_nmos_layer_Via1.stl` (2.4 KB)

#### MIM Capacitor (`cap_cmim/`)

- `cap_cmim_layer_Metal5.stl` (46.0 KB)
- `cap_cmim_layer_TopMetal1.stl` (44.0 KB)


## Viewing Recommendations

### For Complete Device View
Use the **composite** files to see the entire device structure.

### For Layer-by-Layer Analysis
Use the **by_layer** files to examine individual layers or selective combinations.

### Suggested Viewers
- **FreeCAD**: Open Source, excellent for STL viewing
- **Gmsh**: Mesh visualization and analysis
- **MeshLab**: Advanced mesh processing
- **Online**: https://3dviewer.net/ or https://www.viewstl.com/

## Layer Information

All files use accurate Z-heights from IHP SG13G2 LEF data:

- Metal1: 0.53-0.93 μm (thickness: 0.40 μm)
- Metal3: 2.43-2.88 μm (thickness: 0.45 μm)
- TopMetal1: 4.16-6.16 μm (thickness: 2.00 μm)
- Active: 0.0-0.40 μm
- GatePoly: 0.40-0.60 μm
- NWell: 0.0-1.5 μm

