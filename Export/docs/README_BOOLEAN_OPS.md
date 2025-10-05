# 3D Boolean Operations for GDS-to-STEP Conversion

## Quick Start

### Basic Usage

```matlab
% Create two overlapping solids
box1 = [0 0; 10 0; 10 10; 0 10];
box2 = [5 5; 15 5; 15 15; 5 15];

solid1 = gds_extrude_polygon(box1, 0, 5);
solid1.layer_name = 'Metal1';
solid1.polygon_xy = box1;

solid2 = gds_extrude_polygon(box2, 0, 5);
solid2.layer_name = 'Metal1';
solid2.polygon_xy = box2;

% Merge using union
merged = gds_merge_solids_3d({solid1, solid2});
```

## Operations

### Union (Merge Overlapping Solids)
```matlab
merged = gds_merge_solids_3d(solids, 'operation', 'union');
```
**Use case:** Combine multiple metal traces on same layer

### Intersection (Find Overlap)
```matlab
merged = gds_merge_solids_3d(solids, 'operation', 'intersection');
```
**Use case:** Find shared regions between layers

### Difference (Subtract Solids)
```matlab
merged = gds_merge_solids_3d({base, hole}, 'operation', 'difference');
```
**Use case:** Create vias or holes in structures

## Integration with GDS-to-STEP

Enable automatic merging during conversion:

```matlab
gds_to_step('design.gds', 'layer_config.json', 'design.step', ...
            'merge', true);
```

## Requirements

### Install pythonOCC

**Using conda (recommended):**
```bash
conda install -c conda-forge pythonocc-core
```

**Using pip:**
```bash
pip install pythonocc-core
```

### Verify Installation
```bash
python3 -c "from OCC.Core.BRepAlgoAPI import BRepAlgoAPI_Fuse; print('OK')"
```

## Options

| Parameter | Type | Default | Description |
|-----------|------|---------|-------------|
| `operation` | string | `'union'` | Boolean operation: 'union', 'intersection', 'difference' |
| `precision` | number | `1e-6` | Geometric tolerance |
| `python_cmd` | string | `'python3'` | Python command to use |
| `keep_temp` | bool | `false` | Keep temporary files for debugging |
| `verbose` | int | `1` | Verbosity: 0=silent, 1=normal, 2=debug |

## Examples

### Example 1: Merge Metal Layers
```matlab
% Merge overlapping metal features
merged = gds_merge_solids_3d(metal_solids, 'operation', 'union');
```

### Example 2: Create Via Holes
```matlab
% Subtract via regions from metal layer
merged = gds_merge_solids_3d({metal_layer, via_holes}, ...
                             'operation', 'difference');
```

### Example 3: Find Overlapping Regions
```matlab
% Find where two layers overlap
overlap = gds_merge_solids_3d({layer1, layer2}, ...
                              'operation', 'intersection');
```

### Example 4: High Precision Merging
```matlab
% Use tighter tolerance for small features
merged = gds_merge_solids_3d(solids, ...
                             'operation', 'union', ...
                             'precision', 1e-9);
```

### Example 5: Debug Mode
```matlab
% Keep temporary files and show detailed output
merged = gds_merge_solids_3d(solids, ...
                             'operation', 'union', ...
                             'verbose', 2, ...
                             'keep_temp', true);
```

## How It Works

1. **Grouping:** Solids are grouped by `(layer_name, z_bottom, z_top)`
2. **Conversion:** MATLAB solids → JSON → Python
3. **Boolean Ops:** pythonOCC performs 3D operations
4. **Reconstruction:** Python → JSON → MATLAB solids
5. **Cleanup:** Temporary files removed

## Performance Tips

1. **Use layer filtering** to process only necessary layers
2. **Enable windowing** to extract specific regions
3. **Merge is optional** - only use when needed
4. **Group by layer** - automatic, but be aware of performance

## Troubleshooting

### Error: "pythonOCC is not available"
**Solution:** Install pythonOCC (see Requirements above)

### Error: "Failed to create polygon wire"
**Solution:** Check polygon has ≥3 non-collinear vertices

### Warning: "Boolean operation failed"
**Action:** Operation continues with partial results

### Slow Performance
**Solutions:**
- Use windowing to reduce number of solids
- Filter to specific layers
- Increase precision tolerance
- Process layers separately

## Testing

Run the test suite:
```bash
cd Export/tests
octave --eval "test_boolean_operations"
```

Expected output:
```
Total tests:    12
Passed:         12
Failed:         0
Success rate:   100.0%
✓ All tests passed!
```

## Implementation Details

- **Python Module:** `Export/private/boolean_ops.py`
- **MATLAB Interface:** `Export/gds_merge_solids_3d.m`
- **Test Suite:** `Export/tests/test_boolean_operations.m`
- **Documentation:** `Export/SECTION_4_10_IMPLEMENTATION_SUMMARY.md`

## Technical Notes

### Layer Grouping
Solids are only merged if they have:
- **Same** `layer_name`
- **Same** `z_bottom` 
- **Same** `z_top`

This ensures different layers and heights remain separate.

### pythonOCC Operations
- **Union:** `BRepAlgoAPI_Fuse` 
- **Intersection:** `BRepAlgoAPI_Common`
- **Difference:** `BRepAlgoAPI_Cut`

### Error Handling
- Operations fail gracefully
- Original solids returned on error
- Warnings issued for partial failures
- Per-layer error isolation

## References

- **Implementation Plan:** `GDS_TO_STEP_IMPLEMENTATION_PLAN.md` Section 4.10
- **Full Documentation:** `SECTION_4_10_IMPLEMENTATION_SUMMARY.md`
- **pythonOCC Docs:** https://dev.opencascade.org/
- **Test Examples:** `Export/tests/test_boolean_operations.m`

## Support

For issues or questions:
1. Check `SECTION_4_10_IMPLEMENTATION_SUMMARY.md`
2. Run test suite to verify installation
3. Enable verbose mode (`verbose=2`) for debugging
4. Check Python/pythonOCC installation

---

**Version:** 1.0  
**Date:** October 4, 2025  
**Author:** WARP AI Agent  
**Status:** Production Ready
