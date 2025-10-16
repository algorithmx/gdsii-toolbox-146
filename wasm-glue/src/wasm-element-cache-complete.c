/*
 * Complete WASM Element Cache System Implementation
 *
 * Includes all missing function implementations that were declared but not implemented
 *
 * Copyright (c) 2025
 */

#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <stdint.h>
#include <math.h>
#include "wasm-element-cache.h"
#include "mem-file.h"

// Include existing GDS parsing infrastructure
#include "../../Basic/gdsio/gdsio.h"
#include "../../Basic/gdsio/gdstypes.h"

// GDSII record types (from gdstypes.h)
#define HEADER       0x0002
#define BGNLIB       0x0102
#define LIBNAME      0x0206
#define UNITS        0x0305
#define ENDLIB       0x0400
#define BGNSTR       0x0502
#define STRNAME      0x0606
#define ENDSTR       0x0700
#define BOUNDARY     0x0800
#define PATH         0x0900
#define SREF         0x0a00
#define AREF         0x0b00
#define TEXT         0x0c00
#define LAYER        0x0d02
#define DATATYPE     0x0e02
#define WIDTH        0x0f03
#define XY           0x1003
#define ENDEL        0x1100
#define SNAME        0x1206
#define COLROW       0x1302
#define TEXTTYPE     0x1602
#define PRESENTATION 0x1701
#define STRING       0x1906
#define STRANS       0x1a01
#define MAG          0x1b05
#define ANGLE        0x1c05
#define PATHTYPE     0x2102
#define ELFLAGS      0x2601
#define PLEX         0x2f03
#define BGNEXTN      0x3003
#define ENDEXTN      0x3103
#define PROPATTR     0x2b02
#define PROPVALUE    0x2c06
#define BOX          0x2d00
#define NODE         0x1500

// ============================================================================
// MISSING FUNCTION IMPLEMENTATIONS
// ============================================================================

uint16_t wasm_get_element_elflags(wasm_library_cache_t* cache, int structure_index, int element_index) {
    if (!cache || structure_index < 0 || structure_index >= cache->structure_count) {
        return 0;
    }

    wasm_structure_cache_t* struct_cache = &cache->structures[structure_index];
    if (!struct_cache->is_fully_parsed) {
        if (wasm_parse_structure_elements(cache, structure_index) != 0) {
            return 0;
        }
    }

    if (element_index < 0 || element_index >= struct_cache->element_count) {
        return 0;
    }

    return struct_cache->elements[element_index].elflags;
}

int32_t wasm_get_element_plex(wasm_library_cache_t* cache, int structure_index, int element_index) {
    if (!cache || structure_index < 0 || structure_index >= cache->structure_count) {
        return 0;
    }

    wasm_structure_cache_t* struct_cache = &cache->structures[structure_index];
    if (!struct_cache->is_fully_parsed) {
        if (wasm_parse_structure_elements(cache, structure_index) != 0) {
            return 0;
        }
    }

    if (element_index < 0 || element_index >= struct_cache->element_count) {
        return 0;
    }

    return struct_cache->elements[element_index].plex;
}

float wasm_get_element_path_width(wasm_library_cache_t* cache, int structure_index, int element_index) {
    if (!cache || structure_index < 0 || structure_index >= cache->structure_count) {
        return 0.0f;
    }

    wasm_structure_cache_t* struct_cache = &cache->structures[structure_index];
    if (!struct_cache->is_fully_parsed) {
        if (wasm_parse_structure_elements(cache, structure_index) != 0) {
            return 0.0f;
        }
    }

    if (element_index < 0 || element_index >= struct_cache->element_count) {
        return 0.0f;
    }

    return struct_cache->elements[element_index].width;
}

uint16_t wasm_get_element_path_type(wasm_library_cache_t* cache, int structure_index, int element_index) {
    if (!cache || structure_index < 0 || structure_index >= cache->structure_count) {
        return 0;
    }

    wasm_structure_cache_t* struct_cache = &cache->structures[structure_index];
    if (!struct_cache->is_fully_parsed) {
        if (wasm_parse_structure_elements(cache, structure_index) != 0) {
            return 0;
        }
    }

    if (element_index < 0 || element_index >= struct_cache->element_count) {
        return 0;
    }

    return struct_cache->elements[element_index].ptype;
}

float wasm_get_element_path_begin_extension(wasm_library_cache_t* cache, int structure_index, int element_index) {
    if (!cache || structure_index < 0 || structure_index >= cache->structure_count) {
        return 0.0f;
    }

    wasm_structure_cache_t* struct_cache = &cache->structures[structure_index];
    if (!struct_cache->is_fully_parsed) {
        if (wasm_parse_structure_elements(cache, structure_index) != 0) {
            return 0.0f;
        }
    }

    if (element_index < 0 || element_index >= struct_cache->element_count) {
        return 0.0f;
    }

    return struct_cache->elements[element_index].begin_extension;
}

float wasm_get_element_path_end_extension(wasm_library_cache_t* cache, int structure_index, int element_index) {
    if (!cache || structure_index < 0 || structure_index >= cache->structure_count) {
        return 0.0f;
    }

    wasm_structure_cache_t* struct_cache = &cache->structures[structure_index];
    if (!struct_cache->is_fully_parsed) {
        if (wasm_parse_structure_elements(cache, structure_index) != 0) {
            return 0.0f;
        }
    }

    if (element_index < 0 || element_index >= struct_cache->element_count) {
        return 0.0f;
    }

    return struct_cache->elements[element_index].end_extension;
}

const char* wasm_get_element_text(wasm_library_cache_t* cache, int structure_index, int element_index) {
    if (!cache || structure_index < 0 || structure_index >= cache->structure_count) {
        return "";
    }

    wasm_structure_cache_t* struct_cache = &cache->structures[structure_index];
    if (!struct_cache->is_fully_parsed) {
        if (wasm_parse_structure_elements(cache, structure_index) != 0) {
            return "";
        }
    }

    if (element_index < 0 || element_index >= struct_cache->element_count) {
        return "";
    }

    return struct_cache->elements[element_index].text_data.text;
}

void wasm_get_element_text_position(wasm_library_cache_t* cache, int structure_index,
                                   int element_index, float* x, float* y) {
    if (!cache || structure_index < 0 || structure_index >= cache->structure_count) {
        if (x) *x = 0.0f;
        if (y) *y = 0.0f;
        return;
    }

    wasm_structure_cache_t* struct_cache = &cache->structures[structure_index];
    if (!struct_cache->is_fully_parsed) {
        if (wasm_parse_structure_elements(cache, structure_index) != 0) {
            if (x) *x = 0.0f;
            if (y) *y = 0.0f;
            return;
        }
    }

    if (element_index < 0 || element_index >= struct_cache->element_count) {
        if (x) *x = 0.0f;
        if (y) *y = 0.0f;
        return;
    }

    if (x) *x = struct_cache->elements[element_index].text_data.x;
    if (y) *y = struct_cache->elements[element_index].text_data.y;
}

uint16_t wasm_get_element_text_type(wasm_library_cache_t* cache, int structure_index, int element_index) {
    if (!cache || structure_index < 0 || structure_index >= cache->structure_count) {
        return 0;
    }

    wasm_structure_cache_t* struct_cache = &cache->structures[structure_index];
    if (!struct_cache->is_fully_parsed) {
        if (wasm_parse_structure_elements(cache, structure_index) != 0) {
            return 0;
        }
    }

    if (element_index < 0 || element_index >= struct_cache->element_count) {
        return 0;
    }

    return struct_cache->elements[element_index].text_data.text_type;
}

uint16_t wasm_get_element_text_presentation(wasm_library_cache_t* cache, int structure_index, int element_index) {
    if (!cache || structure_index < 0 || structure_index >= cache->structure_count) {
        return 0;
    }

    wasm_structure_cache_t* struct_cache = &cache->structures[structure_index];
    if (!struct_cache->is_fully_parsed) {
        if (wasm_parse_structure_elements(cache, structure_index) != 0) {
            return 0;
        }
    }

    if (element_index < 0 || element_index >= struct_cache->element_count) {
        return 0;
    }

    return struct_cache->elements[element_index].text_data.presentation;
}

const char* wasm_get_element_reference_name(wasm_library_cache_t* cache, int structure_index, int element_index) {
    if (!cache || structure_index < 0 || structure_index >= cache->structure_count) {
        return "";
    }

    wasm_structure_cache_t* struct_cache = &cache->structures[structure_index];
    if (!struct_cache->is_fully_parsed) {
        if (wasm_parse_structure_elements(cache, structure_index) != 0) {
            return "";
        }
    }

    if (element_index < 0 || element_index >= struct_cache->element_count) {
        return "";
    }

    return struct_cache->elements[element_index].reference_data.structure_name;
}

int wasm_get_element_array_columns(wasm_library_cache_t* cache, int structure_index, int element_index) {
    if (!cache || structure_index < 0 || structure_index >= cache->structure_count) {
        return 1;
    }

    wasm_structure_cache_t* struct_cache = &cache->structures[structure_index];
    if (!struct_cache->is_fully_parsed) {
        if (wasm_parse_structure_elements(cache, structure_index) != 0) {
            return 1;
        }
    }

    if (element_index < 0 || element_index >= struct_cache->element_count) {
        return 1;
    }

    return struct_cache->elements[element_index].reference_data.ncol;
}

int wasm_get_element_array_rows(wasm_library_cache_t* cache, int structure_index, int element_index) {
    if (!cache || structure_index < 0 || structure_index >= cache->structure_count) {
        return 1;
    }

    wasm_structure_cache_t* struct_cache = &cache->structures[structure_index];
    if (!struct_cache->is_fully_parsed) {
        if (wasm_parse_structure_elements(cache, structure_index) != 0) {
            return 1;
        }
    }

    if (element_index < 0 || element_index >= struct_cache->element_count) {
        return 1;
    }

    return struct_cache->elements[element_index].reference_data.nrow;
}

void wasm_get_element_reference_corners(wasm_library_cache_t* cache, int structure_index, int element_index,
                                      float* x1, float* y1, float* x2, float* y2, float* x3, float* y3) {
    if (!cache || structure_index < 0 || structure_index >= cache->structure_count) {
        if (x1) *x1 = 0.0f; if (y1) *y1 = 0.0f;
        if (x2) *x2 = 1.0f; if (y2) *y2 = 0.0f;
        if (x3) *x3 = 0.0f; if (y3) *y3 = 1.0f;
        return;
    }

    wasm_structure_cache_t* struct_cache = &cache->structures[structure_index];
    if (!struct_cache->is_fully_parsed) {
        if (wasm_parse_structure_elements(cache, structure_index) != 0) {
            if (x1) *x1 = 0.0f; if (y1) *y1 = 0.0f;
            if (x2) *x2 = 1.0f; if (y2) *y2 = 0.0f;
            if (x3) *x3 = 0.0f; if (y3) *y3 = 1.0f;
            return;
        }
    }

    if (element_index < 0 || element_index >= struct_cache->element_count) {
        if (x1) *x1 = 0.0f; if (y1) *y1 = 0.0f;
        if (x2) *x2 = 1.0f; if (y2) *y2 = 0.0f;
        if (x3) *x3 = 0.0f; if (y3) *y3 = 1.0f;
        return;
    }

    if (x1) *x1 = struct_cache->elements[element_index].reference_data.corners[0];
    if (y1) *y1 = struct_cache->elements[element_index].reference_data.corners[1];
    if (x2) *x2 = struct_cache->elements[element_index].reference_data.corners[2];
    if (y2) *y2 = struct_cache->elements[element_index].reference_data.corners[3];
    if (x3) *x3 = struct_cache->elements[element_index].reference_data.corners[4];
    if (y3) *y3 = struct_cache->elements[element_index].reference_data.corners[5];
}

uint16_t wasm_get_element_strans_flags(wasm_library_cache_t* cache, int structure_index, int element_index) {
    if (!cache || structure_index < 0 || structure_index >= cache->structure_count) {
        return 0;
    }

    wasm_structure_cache_t* struct_cache = &cache->structures[structure_index];
    if (!struct_cache->is_fully_parsed) {
        if (wasm_parse_structure_elements(cache, structure_index) != 0) {
            return 0;
        }
    }

    if (element_index < 0 || element_index >= struct_cache->element_count) {
        return 0;
    }

    return struct_cache->elements[element_index].strans_flags;
}

double wasm_get_element_magnification(wasm_library_cache_t* cache, int structure_index, int element_index) {
    if (!cache || structure_index < 0 || structure_index >= cache->structure_count) {
        return 1.0;
    }

    wasm_structure_cache_t* struct_cache = &cache->structures[structure_index];
    if (!struct_cache->is_fully_parsed) {
        if (wasm_parse_structure_elements(cache, structure_index) != 0) {
            return 1.0;
        }
    }

    if (element_index < 0 || element_index >= struct_cache->element_count) {
        return 1.0;
    }

    return struct_cache->elements[element_index].magnification;
}

double wasm_get_element_rotation_angle(wasm_library_cache_t* cache, int structure_index, int element_index) {
    if (!cache || structure_index < 0 || structure_index >= cache->structure_count) {
        return 0.0;
    }

    wasm_structure_cache_t* struct_cache = &cache->structures[structure_index];
    if (!struct_cache->is_fully_parsed) {
        if (wasm_parse_structure_elements(cache, structure_index) != 0) {
            return 0.0;
        }
    }

    if (element_index < 0 || element_index >= struct_cache->element_count) {
        return 0.0;
    }

    return struct_cache->elements[element_index].rotation_angle;
}

int wasm_get_element_property_count(wasm_library_cache_t* cache, int structure_index, int element_index) {
    if (!cache || structure_index < 0 || structure_index >= cache->structure_count) {
        return 0;
    }

    wasm_structure_cache_t* struct_cache = &cache->structures[structure_index];
    if (!struct_cache->is_fully_parsed) {
        if (wasm_parse_structure_elements(cache, structure_index) != 0) {
            return 0;
        }
    }

    if (element_index < 0 || element_index >= struct_cache->element_count) {
        return 0;
    }

    return struct_cache->elements[element_index].property_count;
}

uint16_t wasm_get_element_property_attribute(wasm_library_cache_t* cache, int structure_index,
                                           int element_index, int property_index) {
    if (!cache || structure_index < 0 || structure_index >= cache->structure_count) {
        return 0;
    }

    wasm_structure_cache_t* struct_cache = &cache->structures[structure_index];
    if (!struct_cache->is_fully_parsed) {
        if (wasm_parse_structure_elements(cache, structure_index) != 0) {
            return 0;
        }
    }

    if (element_index < 0 || element_index >= struct_cache->element_count) {
        return 0;
    }

    if (property_index < 0 || property_index >= struct_cache->elements[element_index].property_count) {
        return 0;
    }

    return struct_cache->elements[element_index].properties[property_index].attribute;
}

const char* wasm_get_element_property_value(wasm_library_cache_t* cache, int structure_index,
                                           int element_index, int property_index) {
    if (!cache || structure_index < 0 || structure_index >= cache->structure_count) {
        return "";
    }

    wasm_structure_cache_t* struct_cache = &cache->structures[structure_index];
    if (!struct_cache->is_fully_parsed) {
        if (wasm_parse_structure_elements(cache, structure_index) != 0) {
            return "";
        }
    }

    if (element_index < 0 || element_index >= struct_cache->element_count) {
        return "";
    }

    if (property_index < 0 || property_index >= struct_cache->elements[element_index].property_count) {
        return "";
    }

    return struct_cache->elements[element_index].properties[property_index].value;
}