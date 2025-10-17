/*
 * WASM Element Cache System Implementation
 *
 * Integrates existing GDSII parsing functions with WASM-accessible cache
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
// UTILITY FUNCTIONS
// ============================================================================

static element_kind map_record_type_to_element_kind(uint16_t record_type) {
    switch (record_type) {
        case BOUNDARY: return GDS_BOUNDARY;
        case PATH:     return GDS_PATH;
        case TEXT:     return GDS_TEXT;
        case SREF:     return GDS_SREF;
        case AREF:     return GDS_AREF;
        case BOX:      return GDS_BOX;
        case NODE:     return GDS_NODE;
        default:       return GDS_BOUNDARY; // Default fallback
    }
}

static void calculate_bounds_from_vertices(double* vertices, int vertex_count, double bounds[4]) {
    if (vertex_count == 0) {
        bounds[0] = bounds[1] = bounds[2] = bounds[3] = 0.0;
        return;
    }

    double min_x = vertices[0], max_x = vertices[0];
    double min_y = vertices[1], max_y = vertices[1];

    for (int i = 1; i < vertex_count; i++) {
        double x = vertices[i * 2];
        double y = vertices[i * 2 + 1];

        if (x < min_x) min_x = x;
        if (x > max_x) max_x = x;
        if (y < min_y) min_y = y;
        if (y > max_y) max_y = y;
    }

    bounds[0] = min_x;
    bounds[1] = min_y;
    bounds[2] = max_x;
    bounds[3] = max_y;
}

// ============================================================================
// CACHE CREATION AND MANAGEMENT
// ============================================================================

wasm_library_cache_t* wasm_create_library_cache(uint8_t* data, size_t size) {
    if (!data || size == 0) {
        return NULL;
    }

    wasm_library_cache_t* cache = malloc(sizeof(wasm_library_cache_t));
    if (!cache) {
        return NULL;
    }

    // Initialize cache
    memset(cache, 0, sizeof(wasm_library_cache_t));
    cache->raw_data = data;
    cache->data_size = size;

    // Create memory file handle
    cache->mem_file = wasm_fopen(data, size);
    if (!cache->mem_file) {
        free(cache);
        return NULL;
    }

    // Parse library header
    uint16_t record_type, record_length;
    size_t pos = 0;

    // Skip HEADER record
    if (!mem_fread_gdsii_header(cache->mem_file, &record_type, &record_length) ||
        record_type != HEADER) {
        wasm_free_library_cache(cache);
        return NULL;
    }
    pos += 4 + record_length;
    mem_fseek(cache->mem_file, pos, SEEK_SET);

    // Skip BGNLIB record (timestamps)
    if (!mem_fread_gdsii_header(cache->mem_file, &record_type, &record_length) ||
        record_type != BGNLIB) {
        wasm_free_library_cache(cache);
        return NULL;
    }
    pos += 4 + record_length;
    mem_fseek(cache->mem_file, pos, SEEK_SET);

    // Read LIBNAME record
    if (!mem_fread_gdsii_header(cache->mem_file, &record_type, &record_length) ||
        record_type != LIBNAME) {
        wasm_free_library_cache(cache);
        return NULL;
    }

    size_t name_len = (record_length < sizeof(cache->name) - 1) ?
                     record_length : sizeof(cache->name) - 1;

    if (mem_fread(cache->name, 1, name_len, cache->mem_file) != name_len) {
        wasm_free_library_cache(cache);
        return NULL;
    }
    cache->name[name_len] = '\0';
    pos += 4 + record_length;
    mem_fseek(cache->mem_file, pos, SEEK_SET);

    // Look for UNITS record
    while (pos + 4 <= size) {
        if (!mem_fread_gdsii_header(cache->mem_file, &record_type, &record_length)) {
            break;
        }

        if (record_type == UNITS && record_length == 16) {
            // Read user units per database unit
            if (!mem_fread_be64(cache->mem_file, &cache->user_units_per_db_unit)) {
                break;
            }
            // Read database units in meters
            if (!mem_fread_be64(cache->mem_file, &cache->meters_per_db_unit)) {
                break;
            }
            break;
        } else if (record_type == ENDLIB) {
            break;
        } else {
            pos += 4 + record_length;
            mem_fseek(cache->mem_file, pos, SEEK_SET);
        }
    }

    // Reset to beginning for structure parsing
    mem_fseek(cache->mem_file, 0, SEEK_SET);

    return cache;
}

void wasm_free_library_cache(wasm_library_cache_t* cache) {
    if (!cache) {
        return;
    }

    // Free structures
    if (cache->structures) {
        for (int i = 0; i < cache->structure_count; i++) {
            wasm_structure_cache_t* struct_cache = &cache->structures[i];

            // Free elements
            if (struct_cache->elements) {
                for (int j = 0; j < struct_cache->element_count; j++) {
                    wasm_cached_element_t* element = &struct_cache->elements[j];

                    // Free polygons
                    if (element->polygons) {
                        for (int k = 0; k < element->polygon_count; k++) {
                            if (element->polygons[k].vertices) {
                                free(element->polygons[k].vertices);
                            }
                        }
                        free(element->polygons);
                    }

                    // Free properties
                    if (element->properties) {
                        free(element->properties);
                    }
                }
                free(struct_cache->elements);
            }
        }
        free(cache->structures);
    }

    // Close memory file
    if (cache->mem_file) {
        mem_fclose(cache->mem_file);
    }

    free(cache);
}

// ============================================================================
// STRUCTURE PARSING
// ============================================================================

int wasm_parse_library_structures(wasm_library_cache_t* cache) {
    if (!cache || cache->structures) {
        return 0; // Already parsed or invalid
    }

    // Count structures first
    int structure_count = 0;
    size_t pos = 0;
    uint16_t record_type, record_length;

    mem_fseek(cache->mem_file, 0, SEEK_SET);

    while (pos + 4 <= cache->data_size) {
        if (!mem_fread_gdsii_header(cache->mem_file, &record_type, &record_length)) {
            break;
        }

        if (record_type == BGNSTR) {
            structure_count++;
        }

        pos += 4 + record_length;
        mem_fseek(cache->mem_file, pos, SEEK_SET);
    }

    if (structure_count == 0) {
        return 0; // No structures found
    }

    // Allocate structure array
    cache->structure_capacity = structure_count + 16; // Extra space
    cache->structures = malloc(cache->structure_capacity * sizeof(wasm_structure_cache_t));
    if (!cache->structures) {
        return -1;
    }

    memset(cache->structures, 0, cache->structure_capacity * sizeof(wasm_structure_cache_t));

    // Parse structures
    mem_fseek(cache->mem_file, 0, SEEK_SET);
    pos = 0;
    int current_struct = 0;

    while (pos + 4 <= cache->data_size && current_struct < structure_count) {
        if (!mem_fread_gdsii_header(cache->mem_file, &record_type, &record_length)) {
            break;
        }

        if (record_type == BGNSTR) {
            wasm_structure_cache_t* struct_cache = &cache->structures[current_struct];
            struct_cache->file_offset = pos;

            // Skip BGNSTR (timestamps)
            pos += 4 + record_length;
            mem_fseek(cache->mem_file, pos, SEEK_SET);

            // Look for STRNAME
            if (pos + 4 <= cache->data_size) {
                uint16_t name_type, name_length;
                if (mem_fread_gdsii_header(cache->mem_file, &name_type, &name_length) &&
                    name_type == STRNAME) {

                    size_t name_len = (name_length < sizeof(struct_cache->name) - 1) ?
                                   name_length : sizeof(struct_cache->name) - 1;

                    if (mem_fread(struct_cache->name, 1, name_len, cache->mem_file) == name_len) {
                        struct_cache->name[name_len] = '\0';
                        current_struct++;
                    }

                    pos += 4 + name_length;
                    mem_fseek(cache->mem_file, pos, SEEK_SET);
                }
            }
        } else {
            pos += 4 + record_length;
            mem_fseek(cache->mem_file, pos, SEEK_SET);
        }
    }

    cache->structure_count = current_struct;
    return 0;
}

// ============================================================================
// PROPERTY ACCESSORS
// ============================================================================

int wasm_get_element_property_count(wasm_library_cache_t* cache, int structure_index, int element_index) {
    if (!cache || structure_index < 0 || structure_index >= cache->structure_count) {
        return -1;
    }
    wasm_structure_cache_t* sc = &cache->structures[structure_index];
    if (element_index < 0 || element_index >= sc->element_count) {
        return -1;
    }
    return sc->elements[element_index].property_count;
}

uint16_t wasm_get_element_property_attribute(wasm_library_cache_t* cache, int structure_index,
                                             int element_index, int property_index) {
    if (!cache || structure_index < 0 || structure_index >= cache->structure_count) {
        return 0;
    }
    wasm_structure_cache_t* sc = &cache->structures[structure_index];
    if (element_index < 0 || element_index >= sc->element_count) {
        return 0;
    }
    wasm_cached_element_t* el = &sc->elements[element_index];
    if (property_index < 0 || property_index >= el->property_count || !el->properties) {
        return 0;
    }
    return el->properties[property_index].attribute;
}

const char* wasm_get_element_property_value(wasm_library_cache_t* cache, int structure_index,
                                            int element_index, int property_index) {
    if (!cache || structure_index < 0 || structure_index >= cache->structure_count) {
        return NULL;
    }
    wasm_structure_cache_t* sc = &cache->structures[structure_index];
    if (element_index < 0 || element_index >= sc->element_count) {
        return NULL;
    }
    wasm_cached_element_t* el = &sc->elements[element_index];
    if (property_index < 0 || property_index >= el->property_count || !el->properties) {
        return NULL;
    }
    return el->properties[property_index].value;
}

// ============================================================================
// ELEMENT PARSING
// ============================================================================

int wasm_parse_structure_elements(wasm_library_cache_t* cache, int structure_index) {
    if (!cache || structure_index < 0 || structure_index >= cache->structure_count) {
        return -1;
    }

    wasm_structure_cache_t* struct_cache = &cache->structures[structure_index];
    if (struct_cache->is_fully_parsed) {
        return 0; // Already parsed
    }

    // Seek to structure start
    mem_fseek(cache->mem_file, struct_cache->file_offset, SEEK_SET);

    // Count elements in structure
    int element_count = 0;
    size_t pos = struct_cache->file_offset;
    uint16_t record_type, record_length;
    int in_structure = 0;

    while (pos + 4 <= cache->data_size) {
        if (!mem_fread_gdsii_header(cache->mem_file, &record_type, &record_length)) {
            break;
        }

        if (record_type == BGNSTR) {
            in_structure = 1;
        } else if (record_type == ENDSTR) {
            if (in_structure) {
                break; // End of our structure
            }
        } else if (in_structure &&
                  (record_type == BOUNDARY || record_type == PATH || record_type == TEXT ||
                   record_type == SREF || record_type == AREF || record_type == BOX ||
                   record_type == NODE)) {
            element_count++;
        }

        pos += 4 + record_length;
        mem_fseek(cache->mem_file, pos, SEEK_SET);
    }

    if (element_count == 0) {
        struct_cache->is_fully_parsed = 1;
        return 0;
    }

    // Allocate element array
    struct_cache->element_capacity = element_count;
    struct_cache->elements = malloc(element_count * sizeof(wasm_cached_element_t));
    if (!struct_cache->elements) {
        return -1;
    }

    memset(struct_cache->elements, 0, element_count * sizeof(wasm_cached_element_t));

    // Parse elements
    mem_fseek(cache->mem_file, struct_cache->file_offset, SEEK_SET);
    pos = struct_cache->file_offset;
    int current_element = 0;
    in_structure = 0;

    while (pos + 4 <= cache->data_size && current_element < element_count) {
        if (!mem_fread_gdsii_header(cache->mem_file, &record_type, &record_length)) {
            break;
        }

        if (record_type == BGNSTR) {
            in_structure = 1;
        } else if (record_type == ENDSTR) {
            if (in_structure) {
                break; // End of our structure
            }
        } else if (in_structure && current_element < element_count &&
                  (record_type == BOUNDARY || record_type == PATH || record_type == TEXT ||
                   record_type == SREF || record_type == AREF || record_type == BOX ||
                   record_type == NODE)) {

            wasm_cached_element_t* element = &struct_cache->elements[current_element];
            element->kind = map_record_type_to_element_kind(record_type);

            // Parse element data (simplified - full implementation would use existing gds_read_element logic)
            (void)record_type; // Mark record_type as used to suppress warning
            pos += 4; // Skip element header
            mem_fseek(cache->mem_file, pos, SEEK_SET);

            // Parse element properties
            uint16_t prop_type, prop_length;
            int layer_set = 0, dtype_set = 0;

            while (pos + 4 <= cache->data_size) {
                if (!mem_fread_gdsii_header(cache->mem_file, &prop_type, &prop_length)) {
                    break;
                }

                if (prop_type == ENDEL) {
                    break; // End of element
                }

                switch (prop_type) {
                    case LAYER:
                        if (prop_length == 2) {
                            mem_fread_be16(cache->mem_file, &element->layer);
                            layer_set = 1;
                        }
                        break;
                    case DATATYPE:
                        if (prop_length == 2) {
                            mem_fread_be16(cache->mem_file, &element->dtype);
                            dtype_set = 1;
                        }
                        break;
                    case ELFLAGS:
                        if (prop_length == 2) {
                            mem_fread_be16(cache->mem_file, &element->elflags);
                        }
                        break;
                    case PLEX:
                        if (prop_length == 4) {
                            mem_fread_be32(cache->mem_file, (uint32_t*)&element->plex);
                        }
                        break;
                    case XY:
                        // Parse coordinate data - XY coordinates are ALWAYS 32-bit signed integers in GDSII
                        if (prop_length >= 8) {
                            // Each coordinate is 4 bytes (32-bit), so each vertex (x,y) is 8 bytes
                            int vertex_count = prop_length / 8;
                            
                            if (element->kind == GDS_BOUNDARY || element->kind == GDS_PATH || 
                                element->kind == GDS_BOX || element->kind == GDS_NODE) {
                                // These elements have polygon/path/node data
                                if (vertex_count > 0) {
                                    element->polygon_count = 1;
                                    element->polygons = malloc(sizeof(wasm_polygon_t));
                                    if (element->polygons) {
                                        element->polygons[0].vertices = malloc(vertex_count * 2 * sizeof(double));
                                        if (element->polygons[0].vertices) {
                                            element->polygons[0].vertex_count = vertex_count;
                                            element->polygons[0].capacity = vertex_count;

                                            // Read vertices (big-endian 32-bit signed integers, convert to double)
                                            for (int i = 0; i < vertex_count; i++) {
                                                int32_t x_int, y_int;
                                                mem_fread_be32(cache->mem_file, (uint32_t*)&x_int);
                                                mem_fread_be32(cache->mem_file, (uint32_t*)&y_int);
                                                element->polygons[0].vertices[i * 2] = (double)x_int;
                                                element->polygons[0].vertices[i * 2 + 1] = (double)y_int;
                                            }

                                            // Calculate bounds
                                            calculate_bounds_from_vertices(element->polygons[0].vertices,
                                                                      vertex_count, element->bounds);
                                        }
                                    }
                                }
                            } else if (element->kind == GDS_TEXT) {
                                // TEXT has exactly 1 point (text position)
                                if (vertex_count >= 1) {
                                    int32_t x_int, y_int;
                                    mem_fread_be32(cache->mem_file, (uint32_t*)&x_int);
                                    mem_fread_be32(cache->mem_file, (uint32_t*)&y_int);
                                    element->text_data.x = (double)x_int;
                                    element->text_data.y = (double)y_int;
                                    
                                    // Set bounds to text position
                                    element->bounds[0] = element->bounds[2] = element->text_data.x;
                                    element->bounds[1] = element->bounds[3] = element->text_data.y;
                                }
                            } else if (element->kind == GDS_SREF) {
                                // SREF has exactly 1 point (reference position)
                                if (vertex_count >= 1) {
                                    int32_t x_int, y_int;
                                    mem_fread_be32(cache->mem_file, (uint32_t*)&x_int);
                                    mem_fread_be32(cache->mem_file, (uint32_t*)&y_int);
                                    element->reference_data.x = (double)x_int;
                                    element->reference_data.y = (double)y_int;
                                    
                                    // Set bounds to reference position (will be expanded by hierarchy resolution)
                                    element->bounds[0] = element->bounds[2] = element->reference_data.x;
                                    element->bounds[1] = element->bounds[3] = element->reference_data.y;
                                }
                            } else if (element->kind == GDS_AREF) {
                                // AREF has exactly 3 points (origin, col_pt, row_pt)
                                if (vertex_count >= 3) {
                                    int32_t x_int, y_int;
                                    
                                    // Origin point (reference position)
                                    mem_fread_be32(cache->mem_file, (uint32_t*)&x_int);
                                    mem_fread_be32(cache->mem_file, (uint32_t*)&y_int);
                                    element->reference_data.x = (double)x_int;
                                    element->reference_data.y = (double)y_int;
                                    
                                    // Column point (defines column spacing vector)
                                    mem_fread_be32(cache->mem_file, (uint32_t*)&x_int);
                                    mem_fread_be32(cache->mem_file, (uint32_t*)&y_int);
                                    element->reference_data.corners[0] = (double)x_int;
                                    element->reference_data.corners[1] = (double)y_int;
                                    
                                    // Row point (defines row spacing vector)
                                    mem_fread_be32(cache->mem_file, (uint32_t*)&x_int);
                                    mem_fread_be32(cache->mem_file, (uint32_t*)&y_int);
                                    element->reference_data.corners[2] = (double)x_int;
                                    element->reference_data.corners[3] = (double)y_int;
                                    
                                    // Calculate bounding box from array extent
                                    // The array spans from origin to the farthest corner
                                    double min_x = element->reference_data.x;
                                    double max_x = element->reference_data.x;
                                    double min_y = element->reference_data.y;
                                    double max_y = element->reference_data.y;
                                    
                                    // Include column endpoint
                                    if (element->reference_data.corners[0] < min_x) min_x = element->reference_data.corners[0];
                                    if (element->reference_data.corners[0] > max_x) max_x = element->reference_data.corners[0];
                                    if (element->reference_data.corners[1] < min_y) min_y = element->reference_data.corners[1];
                                    if (element->reference_data.corners[1] > max_y) max_y = element->reference_data.corners[1];
                                    
                                    // Include row endpoint
                                    if (element->reference_data.corners[2] < min_x) min_x = element->reference_data.corners[2];
                                    if (element->reference_data.corners[2] > max_x) max_x = element->reference_data.corners[2];
                                    if (element->reference_data.corners[3] < min_y) min_y = element->reference_data.corners[3];
                                    if (element->reference_data.corners[3] > max_y) max_y = element->reference_data.corners[3];
                                    
                                    element->bounds[0] = min_x;
                                    element->bounds[1] = min_y;
                                    element->bounds[2] = max_x;
                                    element->bounds[3] = max_y;
                                }
                            }
                        }
                        break;
                    // Add more property parsing as needed
                    default:
                        // Skip unknown properties
                        mem_fseek(cache->mem_file, pos + 4 + prop_length, SEEK_SET);
                        break;
                }

                pos += 4 + prop_length;
                mem_fseek(cache->mem_file, pos, SEEK_SET);
            }

            // Set defaults if not specified
            if (!layer_set) element->layer = 0;
            if (!dtype_set) element->dtype = 0;

            current_element++;
        }

        pos += 4 + record_length;
        mem_fseek(cache->mem_file, pos, SEEK_SET);
    }

    struct_cache->element_count = current_element;
    struct_cache->is_fully_parsed = 1;

    return 0;
}

// ============================================================================
// ELEMENT ACCESS FUNCTIONS (Basic implementations - to be expanded)
// ============================================================================

int wasm_get_element_count(wasm_library_cache_t* cache, int structure_index) {
    if (!cache || structure_index < 0 || structure_index >= cache->structure_count) {
        return -1;
    }

    wasm_structure_cache_t* struct_cache = &cache->structures[structure_index];
    if (!struct_cache->is_fully_parsed) {
        if (wasm_parse_structure_elements(cache, structure_index) != 0) {
            return -1;
        }
    }

    return struct_cache->element_count;
}

int wasm_get_element_type(wasm_library_cache_t* cache, int structure_index, int element_index) {
    if (!cache || structure_index < 0 || structure_index >= cache->structure_count) {
        return -1;
    }

    wasm_structure_cache_t* struct_cache = &cache->structures[structure_index];
    if (!struct_cache->is_fully_parsed) {
        if (wasm_parse_structure_elements(cache, structure_index) != 0) {
            return -1;
        }
    }

    if (element_index < 0 || element_index >= struct_cache->element_count) {
        return -1;
    }

    return (int)struct_cache->elements[element_index].kind;
}

int wasm_get_element_layer(wasm_library_cache_t* cache, int structure_index, int element_index) {
    if (!cache || structure_index < 0 || structure_index >= cache->structure_count) {
        return -1;
    }

    wasm_structure_cache_t* struct_cache = &cache->structures[structure_index];
    if (!struct_cache->is_fully_parsed) {
        if (wasm_parse_structure_elements(cache, structure_index) != 0) {
            return -1;
        }
    }

    if (element_index < 0 || element_index >= struct_cache->element_count) {
        return -1;
    }

    return struct_cache->elements[element_index].layer;
}

// Additional element access functions would be implemented here...
// For now, providing stub implementations

int wasm_get_element_data_type(wasm_library_cache_t* cache, int structure_index, int element_index) {
    (void)cache; (void)structure_index; (void)element_index;
    return 0; // Default
}

int wasm_get_element_polygon_count(wasm_library_cache_t* cache, int structure_index, int element_index) {
    if (!cache || structure_index < 0 || structure_index >= cache->structure_count) {
        return -1;
    }

    wasm_structure_cache_t* struct_cache = &cache->structures[structure_index];
    if (!struct_cache->is_fully_parsed) {
        if (wasm_parse_structure_elements(cache, structure_index) != 0) {
            return -1;
        }
    }

    if (element_index < 0 || element_index >= struct_cache->element_count) {
        return -1;
    }

    return struct_cache->elements[element_index].polygon_count;
}

int wasm_get_element_polygon_vertex_count(wasm_library_cache_t* cache,
                                         int structure_index, int element_index, int polygon_index) {
    if (!cache || structure_index < 0 || structure_index >= cache->structure_count) {
        return -1;
    }

    wasm_structure_cache_t* struct_cache = &cache->structures[structure_index];
    if (!struct_cache->is_fully_parsed) {
        if (wasm_parse_structure_elements(cache, structure_index) != 0) {
            return -1;
        }
    }

    if (element_index < 0 || element_index >= struct_cache->element_count) {
        return -1;
    }

    wasm_cached_element_t* element = &struct_cache->elements[element_index];
    if (polygon_index < 0 || polygon_index >= element->polygon_count) {
        return -1;
    }

    return element->polygons[polygon_index].vertex_count;
}

double* wasm_get_element_polygon_vertices(wasm_library_cache_t* cache,
                                         int structure_index, int element_index, int polygon_index) {
    if (!cache || structure_index < 0 || structure_index >= cache->structure_count) {
        return NULL;
    }

    wasm_structure_cache_t* struct_cache = &cache->structures[structure_index];
    if (!struct_cache->is_fully_parsed) {
        if (wasm_parse_structure_elements(cache, structure_index) != 0) {
            return NULL;
        }
    }

    if (element_index < 0 || element_index >= struct_cache->element_count) {
        return NULL;
    }

    wasm_cached_element_t* element = &struct_cache->elements[element_index];
    if (polygon_index < 0 || polygon_index >= element->polygon_count) {
        return NULL;
    }

    return element->polygons[polygon_index].vertices;
}

// ============================================================================
// ADDITIONAL ELEMENT ACCESS FUNCTIONS (previously missing implementations)
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
        if (x1) *x1 = 0.0f;
        if (y1) *y1 = 0.0f;
        if (x2) *x2 = 1.0f;
        if (y2) *y2 = 0.0f;
        if (x3) *x3 = 0.0f;
        if (y3) *y3 = 1.0f;
        return;
    }

    wasm_structure_cache_t* struct_cache = &cache->structures[structure_index];
    if (!struct_cache->is_fully_parsed) {
        if (wasm_parse_structure_elements(cache, structure_index) != 0) {
            if (x1) *x1 = 0.0f;
            if (y1) *y1 = 0.0f;
            if (x2) *x2 = 1.0f;
            if (y2) *y2 = 0.0f;
            if (x3) *x3 = 0.0f;
            if (y3) *y3 = 1.0f;
            return;
        }
    }

    if (element_index < 0 || element_index >= struct_cache->element_count) {
        if (x1) *x1 = 0.0f;
        if (y1) *y1 = 0.0f;
        if (x2) *x2 = 1.0f;
        if (y2) *y2 = 0.0f;
        if (x3) *x3 = 0.0f;
        if (y3) *y3 = 1.0f;
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

// Note: wasm_get_element_property_count, wasm_get_element_property_attribute, and 
// wasm_get_element_property_value are already implemented above in the PROPERTY ACCESSORS section

// ============================================================================
// UTILITY FUNCTIONS
// ============================================================================

int wasm_validate_cache(wasm_library_cache_t* cache) {
    if (!cache) {
        return 0;
    }

    return (cache->raw_data != NULL &&
            cache->data_size > 0 &&
            cache->mem_file != NULL &&
            mem_fvalidate(cache->mem_file));
}

void wasm_get_cache_stats(wasm_library_cache_t* cache, int* total_structures,
                        int* total_elements, size_t* memory_usage) {
    if (!cache) {
        if (total_structures) *total_structures = 0;
        if (total_elements) *total_elements = 0;
        if (memory_usage) *memory_usage = 0;
        return;
    }

    if (total_structures) *total_structures = cache->structure_count;

    if (total_elements || memory_usage) {
        int elements = 0;
        size_t memory = sizeof(wasm_library_cache_t) + cache->data_size;

        if (cache->structures) {
            memory += cache->structure_capacity * sizeof(wasm_structure_cache_t);

            for (int i = 0; i < cache->structure_count; i++) {
                wasm_structure_cache_t* struct_cache = &cache->structures[i];
                elements += struct_cache->element_count;

                if (struct_cache->elements) {
                    memory += struct_cache->element_capacity * sizeof(wasm_cached_element_t);

                    for (int j = 0; j < struct_cache->element_count; j++) {
                        wasm_cached_element_t* element = &struct_cache->elements[j];

                        if (element->polygons) {
                            memory += element->polygon_count * sizeof(wasm_polygon_t);
                            for (int k = 0; k < element->polygon_count; k++) {
                                memory += element->polygons[k].capacity * 2 * sizeof(double);
                            }
                        }

                        if (element->properties) {
                            memory += element->property_count * sizeof(wasm_property_t);
                        }
                    }
                }
            }
        }

        if (total_elements) *total_elements = elements;
        if (memory_usage) *memory_usage = memory;
    }
}

int wasm_parse_all_data(wasm_library_cache_t* cache) {
    if (!cache) {
        return -1;
    }

    // Parse all structures if not already parsed
    if (!cache->structures) {
        if (wasm_parse_library_structures(cache) != 0) {
            return -1;
        }
    }

    // Parse all elements in all structures
    for (int i = 0; i < cache->structure_count; i++) {
        if (!cache->structures[i].is_fully_parsed) {
            if (wasm_parse_structure_elements(cache, i) != 0) {
                return -1; // Continue parsing other structures even if one fails
            }
        }
    }

    return 0;
}