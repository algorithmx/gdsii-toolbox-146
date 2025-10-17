# GDSII WASM Parser Coordinate Handling Audit Report

**Date:** 2025-10-17  
**Auditor:** AI Assistant  
**Scope:** Systematic review of all coordinate and numeric data type handling in wasm-glue module

## Executive Summary

This audit identified and documented all coordinate data handling in the WASM GDSII parser to ensure compliance with the GDSII Stream Format specification. The audit confirmed one critical bug (already fixed) and identified missing implementations for TEXT, SREF, AREF, and NODE element coordinate parsing.

## GDSII Data Type Specifications (Reference)

According to the GDSII Stream Format specification:

| Data Type | Size | Usage |
|-----------|------|-------|
| Two-byte signed integer | 16 bits | LAYER, DATATYPE, ELFLAGS, TEXTTYPE, etc. |
| Four-byte signed integer | 32 bits | **XY coordinates**, PLEX |
| Eight-byte real | 64 bits | UNITS, MAG, ANGLE |

**Critical:** XY coordinates are ALWAYS 32-bit signed integers in GDSII format.

## Audit Findings

### ✅ CORRECT Implementations

#### 1. Layer, Datatype, Elflags (Lines 478-493)
```c
case LAYER:
    if (prop_length == 2) {
        mem_fread_be16(cache->mem_file, &element->layer);  // ✓ Correct: 16-bit
        layer_set = 1;
    }
    break;
case DATATYPE:
    if (prop_length == 2) {
        mem_fread_be16(cache->mem_file, &element->dtype);  // ✓ Correct: 16-bit
        dtype_set = 1;
    }
    break;
case ELFLAGS:
    if (prop_length == 2) {
        mem_fread_be16(cache->mem_file, &element->elflags);  // ✓ Correct: 16-bit
    }
    break;
```
**Status:** ✅ Correct - These are 16-bit values per spec

#### 2. PLEX (Lines 495-499)
```c
case PLEX:
    if (prop_length == 4) {
        mem_fread_be32(cache->mem_file, (uint32_t*)&element->plex);  // ✓ Correct: 32-bit
    }
    break;
```
**Status:** ✅ Correct - PLEX is a 32-bit value per spec

#### 3. XY Coordinates for BOUNDARY, PATH, BOX (Lines 500-529) - **FIXED**
```c
case XY:
    if (prop_length >= 8 && (element->kind == GDS_BOUNDARY || element->kind == GDS_PATH || element->kind == GDS_BOX)) {
        int vertex_count = prop_length / 8;  // ✓ FIXED: was /4, now /8
        ...
        for (int i = 0; i < vertex_count; i++) {
            int32_t x_int, y_int;
            mem_fread_be32(cache->mem_file, (uint32_t*)&x_int);  // ✓ FIXED: was be16, now be32
            mem_fread_be32(cache->mem_file, (uint32_t*)&y_int);  // ✓ FIXED: was be16, now be32
            element->polygons[0].vertices[i * 2] = (double)x_int;
            element->polygons[0].vertices[i * 2 + 1] = (double)y_int;
        }
    }
```
**Status:** ✅ Fixed - Now correctly reads 32-bit coordinates

### ⚠️ MISSING Implementations

#### 1. TEXT Element XY Coordinates (Line 502 - Not Handled)
**Problem:** TEXT elements have XY coordinates but are not parsed in the XY case.  
**Impact:** Text position data is lost  
**Required Fix:** Add TEXT handling in XY case to read text position (1 point)

```c
} else if (element->kind == GDS_TEXT) {
    // TEXT has exactly 1 point (position)
    if (vertex_count >= 1) {
        int32_t x_int, y_int;
        mem_fread_be32(cache->mem_file, (uint32_t*)&x_int);
        mem_fread_be32(cache->mem_file, (uint32_t*)&y_int);
        element->text_data.x = (double)x_int;
        element->text_data.y = (double)y_int;
    }
}
```

#### 2. SREF Element XY Coordinates (Line 502 - Not Handled)
**Problem:** SREF elements have XY coordinates but are not parsed.  
**Impact:** Reference position data is lost  
**Required Fix:** Add SREF handling in XY case to read reference position (1 point)

```c
} else if (element->kind == GDS_SREF) {
    // SREF has exactly 1 point (position)
    if (vertex_count >= 1) {
        int32_t x_int, y_int;
        mem_fread_be32(cache->mem_file, (uint32_t*)&x_int);
        mem_fread_be32(cache->mem_file, (uint32_t*)&y_int);
        element->reference_data.x = (double)x_int;
        element->reference_data.y = (double)y_int;
    }
}
```

#### 3. AREF Element XY Coordinates (Line 502 - Not Handled)
**Problem:** AREF elements have XY coordinates (3 points: origin, col_pt, row_pt) but are not parsed.  
**Impact:** Array reference positioning data is lost  
**Required Fix:** Add AREF handling in XY case to read 3 corner points

```c
} else if (element->kind == GDS_AREF) {
    // AREF has exactly 3 points (origin, col_pt, row_pt)
    if (vertex_count >= 3) {
        int32_t x_int, y_int;
        
        // Origin point
        mem_fread_be32(cache->mem_file, (uint32_t*)&x_int);
        mem_fread_be32(cache->mem_file, (uint32_t*)&y_int);
        element->reference_data.x = (double)x_int;
        element->reference_data.y = (double)y_int;
        
        // Column and Row points
        mem_fread_be32(cache->mem_file, (uint32_t*)&x_int);
        mem_fread_be32(cache->mem_file, (uint32_t*)&y_int);
        element->reference_data.corners[0] = (double)x_int;
        element->reference_data.corners[1] = (double)y_int;
        
        mem_fread_be32(cache->mem_file, (uint32_t*)&x_int);
        mem_fread_be32(cache->mem_file, (uint32_t*)&y_int);
        element->reference_data.corners[2] = (double)x_int;
        element->reference_data.corners[3] = (double)y_int;
    }
}
```

#### 4. NODE Element XY Coordinates (Line 502 - Partially Handled)
**Problem:** NODE elements have XY coordinates but are listed with BOUNDARY/PATH/BOX.  
**Status:** Actually this IS being handled correctly in the current code (line 502)  
**Action:** ✅ No change needed - already included in polygon parsing

### 📝 Additional Observations

#### Data Structure Alignment
The wasm_reference_data_t structure (include/wasm-element-cache.h lines 60-65) correctly stores:
- `double x, y` - for SREF/AREF position
- `double corners[6]` - for AREF corners (3 points)

This is adequate for storing AREF data but the current code doesn't populate it.

#### Text Data Structure
The wasm_text_data_t structure (include/wasm-element-cache.h lines 49-55) correctly stores:
- `double x, y` - for text position

This is adequate but the current code doesn't populate it from XY records.

## Recommendations

### High Priority
1. **Add TEXT XY coordinate parsing** - Required for text positioning
2. **Add SREF XY coordinate parsing** - Required for cell reference positioning  
3. **Add AREF XY coordinate parsing** - Required for array reference positioning

### Implementation Notes
- All XY coordinate reads MUST use `mem_fread_be32()` for 32-bit signed integers
- Vertex count calculation MUST use `prop_length / 8` (8 bytes per x,y pair)
- All coordinate data should be cast to `double` for storage in cache structures

### Testing Verification
After implementing the missing handlers, test with GDSII files containing:
- TEXT elements
- SREF (structure references)
- AREF (array references)

## References
- GDSII Stream Format Specification (Cadence/Calma)
- Harry Dole's GDS Format Documentation: https://harrydole.com/wp/2017/09/18/gds/
- LayoutEditor GDSII Documentation: https://layouteditor.org/layout/file-formats/gdsii

## Conclusion

The coordinate parsing bug (16-bit vs 32-bit) has been correctly fixed for BOUNDARY, PATH, and BOX elements. However, TEXT, SREF, and AREF elements are not currently parsing their XY coordinate data, which will cause these elements to have incorrect or missing position information. These missing implementations should be added to achieve full GDSII compliance.
