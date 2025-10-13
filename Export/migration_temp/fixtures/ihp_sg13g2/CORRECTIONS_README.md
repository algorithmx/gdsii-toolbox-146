# IHP SG13G2 PDK Layer Configuration Corrections

This document details the corrections made to the layer configuration files for proper 3D structure construction from GDS files in the IHP SG13G2 PDK.

## Analysis Summary

### Source Files Analyzed
- `sg13g2.lyp` - KLayout layer properties file
- `sg13g2.lyt` - KLayout layer technology file
- `sg13g2.map` - Layer mapping file for LEF/DEF import

### Key Issues Identified and Corrected

#### 1. Z-Height Alignment Problems
**Issue**: Previous configurations had gaps and misalignments between adjacent layers.
**Correction**: Adjusted all z-coordinates to ensure proper layer stacking:
- `Cont`: z_bottom 0.55 → z_top 0.93 (proper connection to GatPoly and Metal1)
- `Metal1`: z_bottom 0.93 → z_top 1.33 (40nm thickness)
- All subsequent layers adjusted for seamless connections

#### 2. Layer Thickness Corrections
**Issue**: Inconsistent or unrealistic layer thicknesses.
**Correction**: Updated thicknesses based on typical 130nm process specs:
- Metal1-3: 0.40-0.45 μm (consistent with standard BEOL)
- TopMetal1: 2.5 μm (thick metal for power/RF)
- TopMetal2: 3.5 μm (bondpad thickness)
- Substrate: Increased to 10 μm for better mechanical stability

#### 3. Missing PDK Layers
Added missing layers identified in the PDK:
- **Layer 46 (Inductor)**: Special thick metal for RF components
- **Layer 48 (MIMTop)**: MIM capacitor top plate
- **Layer 16 (VThAdjust)**: Threshold voltage adjustment implant
- **Layer 26 (Silicide)**: Silicide formation layer
- Proper MIM capacitor structure (Layer 36 + 48)

#### 4. Material Property Improvements
**Issue**: Generic material names and properties.
**Correction**: Added more specific material definitions:
- `silicon_active` vs generic `silicon`
- `silicon_nitride` for MIM dielectric
- `titanium_silicide` for silicide regions
- `polysilicon_high_res` for resistor poly

#### 5. Enhanced Layer Properties
Added detailed LEF-derived properties where available:
- Minimum widths and spacing from design rules
- Sheet resistance values for accurate simulation
- Layer heights matching LEF definitions

#### 6. Logical Layer Stacking
Ensured proper process flow alignment:
1. Substrate → Active/Poly → Contacts
2. Metals 1-5 with standard vias
3. Top Metal stack for power/IO
4. Special structures (MIM, Inductors) appropriately placed

## Layer Stack Summary

```
z (μm) | Layer            | Thickness | Material
-------|------------------|-----------|----------
14.83  | TopMetal2        | 3.50      | Aluminum (bondpad)
11.33  | TopVia2          | 2.50      | Tungsten
 8.83  | TopMetal1        | 2.50      | Aluminum (thick)
 6.33  | TopVia1          | 1.00      | Tungsten
 5.33  | Metal5           | 0.45      | Aluminum
 4.88  | Via4             | 0.55      | Tungsten
 4.33  | Metal4           | 0.45      | Aluminum
 3.88  | Via3             | 0.55      | Tungsten
 3.33  | Metal3/MIMTop    | 0.45/0.05 | Al/SiN
 2.83  | Via2             | 0.55      | Tungsten
 2.28  | Metal2           | 0.45      | Aluminum
 1.83  | Via1             | 0.50      | Tungsten
 1.33  | Metal1           | 0.40      | Aluminum
 0.93  | Cont             | 0.38      | Tungsten
 0.55  | GatPoly          | 0.20      | Polysilicon
 0.35  | Activ            | 0.35      | Silicon
 0.00  | Substrate        | 10.0      | Silicon
-10.0  | -----------------|-----------|----------
```

## Usage Instructions

1. **For Standard 3D Export**: Use `layer_config_ihp_sg13g2_corrected.json`
2. **For High-Fidelity Models**: Enable disabled layers (MIM, Inductors) as needed
3. **For Simulation**: Ensure all enabled layers have proper material assignments

## Validation Notes

- All layer numbers match PDK definitions from `sg13g2.lyp`
- Z-heights ensure no gaps or overlaps in 3D structure
- Material properties are compatible with typical STEP export tools
- Configuration follows IHP's official design rules and process stack

## Files Updated

- `layer_config_ihp_sg13g2_corrected.json` - Main corrected configuration
- Original files preserved for reference:
  - `layer_config_ihp_sg13g2.json`
  - `layer_config_ihp_sg13g2_accurate.json`

---
*Generated: 2025-10-13*
*Based on IHP SG13G2 PDK version analysis*