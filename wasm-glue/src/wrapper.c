/*
 * GDSII WASM Wrapper Interface
 *
 * This file provides the main WebAssembly interface functions for the GDSII parser.
 * It bridges the gap between the JavaScript/TypeScript frontend and the C/C++ GDSII
 * parsing backend from the base project.
 */

#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <math.h>
#include <emscripten.h>

// Include base project headers (adjust paths as needed)
#include "../include/wasm-types.h"
#include "../include/gds-wasm-adapter.h"

// Forward declaration for debugging function
extern int gds_wasm_get_detected_endianness(void);

// ============================================================================
// GLOBAL STATE
// ============================================================================

static wasm_library_t* current_library = NULL;
static wasm_error_t last_error = {0};
static wasm_memory_stats_t memory_stats = {0};

// ============================================================================
// MEMORY MANAGEMENT
// ============================================================================

void* wasm_malloc(size_t size, const char* type) {
    void* ptr = malloc(size);
    if (ptr) {
        memory_stats.total_allocated += size;
        if (memory_stats.total_allocated > memory_stats.peak_allocated) {
            memory_stats.peak_allocated = memory_stats.total_allocated;
        }
        memory_stats.block_count++;
    }
    return ptr;
}

void wasm_free(void* ptr) {
    if (ptr) {
        free(ptr);
        memory_stats.block_count--;
    }
}

void wasm_get_memory_stats(wasm_memory_stats_t* stats) {
    if (stats) {
        *stats = memory_stats;
    }
}

void wasm_cleanup_memory(void) {
    memset(&memory_stats, 0, sizeof(memory_stats));
}

// ============================================================================
// UTILITY FUNCTIONS
// ============================================================================

void wasm_init_bbox(wasm_bbox_t* bbox) {
    if (bbox) {
        bbox->min_x = INFINITY;
        bbox->min_y = INFINITY;
        bbox->max_x = -INFINITY;
        bbox->max_y = -INFINITY;
    }
}

void wasm_expand_bbox(wasm_bbox_t* bbox, const wasm_vertex_t* vertex) {
    if (!bbox || !vertex) return;

    if (vertex->x < bbox->min_x) bbox->min_x = vertex->x;
    if (vertex->y < bbox->min_y) bbox->min_y = vertex->y;
    if (vertex->x > bbox->max_x) bbox->max_x = vertex->x;
    if (vertex->y > bbox->max_y) bbox->max_y = vertex->y;
}

int wasm_validate_library(wasm_library_t* lib) {
    if (!lib) return 0;

    // Basic validation - just check that we have a name
    return strlen(lib->name) > 0;
}

// ============================================================================
// ERROR HANDLING
// ============================================================================

void wasm_set_error(wasm_error_code_t code, const char* message, const char* context, int position) {
    last_error.code = code;
    strncpy(last_error.message, message ? message : "Unknown error", sizeof(last_error.message) - 1);
    strncpy(last_error.context, context ? context : "", sizeof(last_error.context) - 1);
    last_error.position = position;
    last_error.message[sizeof(last_error.message) - 1] = '\0';
    last_error.context[sizeof(last_error.context) - 1] = '\0';
}

const char* wasm_get_last_error(void) {
    return last_error.message;
}

void wasm_clear_error(void) {
    memset(&last_error, 0, sizeof(last_error));
}

// ============================================================================
// MAIN PARSING INTERFACE
// ============================================================================

EMSCRIPTEN_KEEPALIVE
void* gds_parse_from_memory(uint8_t* data, int size, int* error_code) {
    wasm_clear_error();

    if (!data || size <= 0) {
        wasm_set_error(WASM_ERROR_INVALID_PARAMETER, "Invalid input data", "gds_parse_from_memory", 0);
        if (error_code) *error_code = WASM_ERROR_INVALID_PARAMETER;
        return NULL;
    }

    // Initialize the GDSII WASM adapter with real parser
    if (gds_wasm_initialize(data, size) != 0) {
        const char* error = gds_wasm_get_error();
        wasm_set_error(WASM_ERROR_PARSE_FAILED, error ? error : "Failed to initialize GDSII parser", "gds_parse_from_memory", 0);
        if (error_code) *error_code = WASM_ERROR_PARSE_FAILED;
        return NULL;
    }

    // Parse the library header using real GDSII parser
    if (gds_wasm_parse_library_header() != 0) {
        const char* error = gds_wasm_get_error();
        wasm_set_error(WASM_ERROR_PARSE_FAILED, error ? error : "Failed to parse GDSII library header", "gds_parse_from_memory", 0);
        gds_wasm_cleanup();
        if (error_code) *error_code = WASM_ERROR_PARSE_FAILED;
        return NULL;
    }

    // Create WASM library structure with real data
    wasm_library_t* lib = (wasm_library_t*)wasm_malloc(sizeof(wasm_library_t), "wasm_library_t");
    if (!lib) {
        wasm_set_error(WASM_ERROR_MEMORY_ALLOCATION, "Failed to allocate library", "gds_parse_from_memory", 0);
        gds_wasm_cleanup();
        if (error_code) *error_code = WASM_ERROR_MEMORY_ALLOCATION;
        return NULL;
    }

    // Initialize library with real GDSII data
    const char* lib_name = gds_wasm_get_library_name();
    strncpy(lib->name, lib_name ? lib_name : "Unknown Library", sizeof(lib->name) - 1);
    lib->name[sizeof(lib->name) - 1] = '\0';

    lib->user_units_per_db_unit = gds_wasm_get_user_units_per_db_unit();
    lib->meters_per_db_unit = gds_wasm_get_meters_per_db_unit();
    lib->structure_count = gds_wasm_count_structures();

    // Create structures array
    lib->structures = (wasm_structure_t*)wasm_malloc(lib->structure_count * sizeof(wasm_structure_t), "wasm_structure_t");
    if (!lib->structures) {
        wasm_free(lib);
        wasm_set_error(WASM_ERROR_MEMORY_ALLOCATION, "Failed to allocate structures", "gds_parse_from_memory", 0);
        gds_wasm_cleanup();
        if (error_code) *error_code = WASM_ERROR_MEMORY_ALLOCATION;
        return NULL;
    }

    // Initialize structures with real data (simplified for now)
    for (int i = 0; i < lib->structure_count; i++) {
        const char* struct_name = gds_wasm_get_structure_name(i);
        strncpy(lib->structures[i].name, struct_name ? struct_name : "Unknown Structure", sizeof(lib->structures[i].name) - 1);
        lib->structures[i].name[sizeof(lib->structures[i].name) - 1] = '\0';

        // TODO: Parse actual elements from GDSII file
        // For now, create placeholder structure that will be enhanced in Phase 2
        lib->structures[i].element_count = 0;
        lib->structures[i].reference_count = 0;
        lib->structures[i].elements = NULL;
        lib->structures[i].references = NULL;
        wasm_init_bbox(&lib->structures[i].total_bounds);
    }
    // Note: Element parsing will be implemented in Phase 2
    // For now, we have successfully replaced mock data with real GDSII library information

    current_library = lib;

    if (error_code) *error_code = WASM_ERROR_NONE;
    return lib;
}

EMSCRIPTEN_KEEPALIVE
void gds_free_library(void* library_ptr) {
    if (!library_ptr) return;

    wasm_library_t* lib = (wasm_library_t*)library_ptr;

    // Free structures
    for (int i = 0; i < lib->structure_count; i++) {
        wasm_structure_t* structure = &lib->structures[i];

        // Free elements
        for (int j = 0; j < structure->element_count; j++) {
            wasm_element_t* element = &structure->elements[j];

            // Free geometry
            if (element->geometry.polygons) {
                for (int k = 0; k < element->geometry.polygon_count; k++) {
                    if (element->geometry.polygons[k]) {
                        wasm_free(element->geometry.polygons[k]);
                    }
                }
                wasm_free(element->geometry.polygons);
            }

            if (element->geometry.vertex_counts) {
                wasm_free(element->geometry.vertex_counts);
            }

            // Free properties
            if (element->properties) {
                wasm_free(element->properties);
            }

            // Free reference-specific data
            if (element->kind == WASM_ELEMENT_SREF) {
                if (element->element_specific.sref_data.positions) {
                    wasm_free(element->element_specific.sref_data.positions);
                }
            }
        }

        if (structure->elements) {
            wasm_free(structure->elements);
        }

        // Free references
        if (structure->references) {
            for (int k = 0; k < structure->reference_count; k++) {
                if (structure->references[k].instance_bounds) {
                    wasm_free(structure->references[k].instance_bounds);
                }
            }
            wasm_free(structure->references);
        }
    }

    if (lib->structures) {
        wasm_free(lib->structures);
    }

    wasm_free(lib);

    if (current_library == lib) {
        current_library = NULL;
    }
}

// ============================================================================
// LIBRARY METADATA ACCESS
// ============================================================================

EMSCRIPTEN_KEEPALIVE
const char* gds_get_library_name(void* library_ptr) {
    if (!library_ptr) {
        wasm_set_error(WASM_ERROR_INVALID_PARAMETER, "Library pointer is null", "gds_get_library_name", 0);
        return "";
    }

    wasm_library_t* lib = (wasm_library_t*)library_ptr;
    return lib->name;
}

EMSCRIPTEN_KEEPALIVE
double gds_get_user_units_per_db_unit(void* library_ptr) {
    if (!library_ptr) {
        wasm_set_error(WASM_ERROR_INVALID_PARAMETER, "Library pointer is null", "gds_get_user_units_per_db_unit", 0);
        return 0.0;
    }

    wasm_library_t* lib = (wasm_library_t*)library_ptr;
    return lib->user_units_per_db_unit;
}

EMSCRIPTEN_KEEPALIVE
double gds_get_meters_per_db_unit(void* library_ptr) {
    if (!library_ptr) {
        wasm_set_error(WASM_ERROR_INVALID_PARAMETER, "Library pointer is null", "gds_get_meters_per_db_unit", 0);
        return 0.0;
    }

    wasm_library_t* lib = (wasm_library_t*)library_ptr;
    return lib->meters_per_db_unit;
}

EMSCRIPTEN_KEEPALIVE
int gds_get_structure_count(void* library_ptr) {
    if (!library_ptr) {
        wasm_set_error(WASM_ERROR_INVALID_PARAMETER, "Library pointer is null", "gds_get_structure_count", 0);
        return 0;
    }

    wasm_library_t* lib = (wasm_library_t*)library_ptr;
    return lib->structure_count;
}

// ============================================================================
// STRUCTURE ACCESS
// ============================================================================

EMSCRIPTEN_KEEPALIVE
const char* gds_get_structure_name(void* library_ptr, int structure_index) {
    if (!library_ptr) {
        wasm_set_error(WASM_ERROR_INVALID_PARAMETER, "Library pointer is null", "gds_get_structure_name", 0);
        return "";
    }

    wasm_library_t* lib = (wasm_library_t*)library_ptr;

    if (structure_index < 0 || structure_index >= lib->structure_count) {
        wasm_set_error(WASM_ERROR_INVALID_PARAMETER, "Structure index out of range", "gds_get_structure_name", structure_index);
        return "";
    }

    return lib->structures[structure_index].name;
}

EMSCRIPTEN_KEEPALIVE
int gds_get_element_count(void* library_ptr, int structure_index) {
    if (!library_ptr) {
        wasm_set_error(WASM_ERROR_INVALID_PARAMETER, "Library pointer is null", "gds_get_element_count", 0);
        return 0;
    }

    wasm_library_t* lib = (wasm_library_t*)library_ptr;

    if (structure_index < 0 || structure_index >= lib->structure_count) {
        wasm_set_error(WASM_ERROR_INVALID_PARAMETER, "Structure index out of range", "gds_get_element_count", structure_index);
        return 0;
    }

    return lib->structures[structure_index].element_count;
}

EMSCRIPTEN_KEEPALIVE
int gds_get_reference_count(void* library_ptr, int structure_index) {
    if (!library_ptr) {
        wasm_set_error(WASM_ERROR_INVALID_PARAMETER, "Library pointer is null", "gds_get_reference_count", 0);
        return 0;
    }

    wasm_library_t* lib = (wasm_library_t*)library_ptr;

    if (structure_index < 0 || structure_index >= lib->structure_count) {
        wasm_set_error(WASM_ERROR_INVALID_PARAMETER, "Structure index out of range", "gds_get_reference_count", structure_index);
        return 0;
    }

    return lib->structures[structure_index].reference_count;
}

// ============================================================================
// ELEMENT ACCESS
// ============================================================================

EMSCRIPTEN_KEEPALIVE
int gds_get_element_type(void* library_ptr, int structure_index, int element_index) {
    if (!library_ptr) {
        wasm_set_error(WASM_ERROR_INVALID_PARAMETER, "Library pointer is null", "gds_get_element_type", 0);
        return 0;
    }

    wasm_library_t* lib = (wasm_library_t*)library_ptr;

    if (structure_index < 0 || structure_index >= lib->structure_count) {
        wasm_set_error(WASM_ERROR_INVALID_PARAMETER, "Structure index out of range", "gds_get_element_type", structure_index);
        return 0;
    }

    wasm_structure_t* structure = &lib->structures[structure_index];

    if (element_index < 0 || element_index >= structure->element_count) {
        wasm_set_error(WASM_ERROR_INVALID_PARAMETER, "Element index out of range", "gds_get_element_type", element_index);
        return 0;
    }

    return (int)structure->elements[element_index].kind;
}

EMSCRIPTEN_KEEPALIVE
int gds_get_element_layer(void* library_ptr, int structure_index, int element_index) {
    if (!library_ptr) {
        wasm_set_error(WASM_ERROR_INVALID_PARAMETER, "Library pointer is null", "gds_get_element_layer", 0);
        return 0;
    }

    wasm_library_t* lib = (wasm_library_t*)library_ptr;

    if (structure_index < 0 || structure_index >= lib->structure_count) {
        wasm_set_error(WASM_ERROR_INVALID_PARAMETER, "Structure index out of range", "gds_get_element_layer", structure_index);
        return 0;
    }

    wasm_structure_t* structure = &lib->structures[structure_index];

    if (element_index < 0 || element_index >= structure->element_count) {
        wasm_set_error(WASM_ERROR_INVALID_PARAMETER, "Element index out of range", "gds_get_element_layer", element_index);
        return 0;
    }

    return structure->elements[element_index].layer;
}

EMSCRIPTEN_KEEPALIVE
int gds_get_element_data_type(void* library_ptr, int structure_index, int element_index) {
    if (!library_ptr) {
        wasm_set_error(WASM_ERROR_INVALID_PARAMETER, "Library pointer is null", "gds_get_element_data_type", 0);
        return 0;
    }

    wasm_library_t* lib = (wasm_library_t*)library_ptr;

    if (structure_index < 0 || structure_index >= lib->structure_count) {
        wasm_set_error(WASM_ERROR_INVALID_PARAMETER, "Structure index out of range", "gds_get_element_data_type", structure_index);
        return 0;
    }

    wasm_structure_t* structure = &lib->structures[structure_index];

    if (element_index < 0 || element_index >= structure->element_count) {
        wasm_set_error(WASM_ERROR_INVALID_PARAMETER, "Element index out of range", "gds_get_element_data_type", element_index);
        return 0;
    }

    return structure->elements[element_index].data_type;
}

EMSCRIPTEN_KEEPALIVE
int gds_get_element_polygon_count(void* library_ptr, int structure_index, int element_index) {
    if (!library_ptr) {
        wasm_set_error(WASM_ERROR_INVALID_PARAMETER, "Library pointer is null", "gds_get_element_polygon_count", 0);
        return 0;
    }

    wasm_library_t* lib = (wasm_library_t*)library_ptr;

    if (structure_index < 0 || structure_index >= lib->structure_count) {
        wasm_set_error(WASM_ERROR_INVALID_PARAMETER, "Structure index out of range", "gds_get_element_polygon_count", structure_index);
        return 0;
    }

    wasm_structure_t* structure = &lib->structures[structure_index];

    if (element_index < 0 || element_index >= structure->element_count) {
        wasm_set_error(WASM_ERROR_INVALID_PARAMETER, "Element index out of range", "gds_get_element_polygon_count", element_index);
        return 0;
    }

    return structure->elements[element_index].geometry.polygon_count;
}

EMSCRIPTEN_KEEPALIVE
int gds_get_element_polygon_vertex_count(void* library_ptr, int structure_index, int element_index, int polygon_index) {
    if (!library_ptr) {
        wasm_set_error(WASM_ERROR_INVALID_PARAMETER, "Library pointer is null", "gds_get_element_polygon_vertex_count", 0);
        return 0;
    }

    wasm_library_t* lib = (wasm_library_t*)library_ptr;

    if (structure_index < 0 || structure_index >= lib->structure_count) {
        wasm_set_error(WASM_ERROR_INVALID_PARAMETER, "Structure index out of range", "gds_get_element_polygon_vertex_count", structure_index);
        return 0;
    }

    wasm_structure_t* structure = &lib->structures[structure_index];

    if (element_index < 0 || element_index >= structure->element_count) {
        wasm_set_error(WASM_ERROR_INVALID_PARAMETER, "Element index out of range", "gds_get_element_polygon_vertex_count", element_index);
        return 0;
    }

    wasm_element_t* element = &structure->elements[element_index];

    if (polygon_index < 0 || polygon_index >= element->geometry.polygon_count) {
        wasm_set_error(WASM_ERROR_INVALID_PARAMETER, "Polygon index out of range", "gds_get_element_polygon_vertex_count", polygon_index);
        return 0;
    }

    return element->geometry.vertex_counts[polygon_index];
}

EMSCRIPTEN_KEEPALIVE
double* gds_get_element_polygon_vertices(void* library_ptr, int structure_index, int element_index, int polygon_index) {
    if (!library_ptr) {
        wasm_set_error(WASM_ERROR_INVALID_PARAMETER, "Library pointer is null", "gds_get_element_polygon_vertices", 0);
        return NULL;
    }

    wasm_library_t* lib = (wasm_library_t*)library_ptr;

    if (structure_index < 0 || structure_index >= lib->structure_count) {
        wasm_set_error(WASM_ERROR_INVALID_PARAMETER, "Structure index out of range", "gds_get_element_polygon_vertices", structure_index);
        return NULL;
    }

    wasm_structure_t* structure = &lib->structures[structure_index];

    if (element_index < 0 || element_index >= structure->element_count) {
        wasm_set_error(WASM_ERROR_INVALID_PARAMETER, "Element index out of range", "gds_get_element_polygon_vertices", element_index);
        return NULL;
    }

    wasm_element_t* element = &structure->elements[element_index];

    if (polygon_index < 0 || polygon_index >= element->geometry.polygon_count) {
        wasm_set_error(WASM_ERROR_INVALID_PARAMETER, "Polygon index out of range", "gds_get_element_polygon_vertices", polygon_index);
        return NULL;
    }

    return (double*)element->geometry.polygons[polygon_index];
}

// ============================================================================
// TEXT ELEMENT ACCESS
// ============================================================================

EMSCRIPTEN_KEEPALIVE
const char* gds_get_element_text(void* library_ptr, int structure_index, int element_index) {
    if (!library_ptr) {
        wasm_set_error(WASM_ERROR_INVALID_PARAMETER, "Library pointer is null", "gds_get_element_text", 0);
        return "";
    }

    wasm_library_t* lib = (wasm_library_t*)library_ptr;

    if (structure_index < 0 || structure_index >= lib->structure_count) {
        wasm_set_error(WASM_ERROR_INVALID_PARAMETER, "Structure index out of range", "gds_get_element_text", structure_index);
        return "";
    }

    wasm_structure_t* structure = &lib->structures[structure_index];

    if (element_index < 0 || element_index >= structure->element_count) {
        wasm_set_error(WASM_ERROR_INVALID_PARAMETER, "Element index out of range", "gds_get_element_text", element_index);
        return "";
    }

    wasm_element_t* element = &structure->elements[element_index];

    if (element->kind != WASM_ELEMENT_TEXT) {
        wasm_set_error(WASM_ERROR_INVALID_PARAMETER, "Element is not a text element", "gds_get_element_text", element_index);
        return "";
    }

    return element->element_specific.text_data.text_string;
}

EMSCRIPTEN_KEEPALIVE
double* gds_get_element_text_position(void* library_ptr, int structure_index, int element_index) {
    if (!library_ptr) {
        wasm_set_error(WASM_ERROR_INVALID_PARAMETER, "Library pointer is null", "gds_get_element_text_position", 0);
        return NULL;
    }

    wasm_library_t* lib = (wasm_library_t*)library_ptr;

    if (structure_index < 0 || structure_index >= lib->structure_count) {
        wasm_set_error(WASM_ERROR_INVALID_PARAMETER, "Structure index out of range", "gds_get_element_text_position", structure_index);
        return NULL;
    }

    wasm_structure_t* structure = &lib->structures[structure_index];

    if (element_index < 0 || element_index >= structure->element_count) {
        wasm_set_error(WASM_ERROR_INVALID_PARAMETER, "Element index out of range", "gds_get_element_text_position", element_index);
        return NULL;
    }

    wasm_element_t* element = &structure->elements[element_index];

    if (element->kind != WASM_ELEMENT_TEXT) {
        wasm_set_error(WASM_ERROR_INVALID_PARAMETER, "Element is not a text element", "gds_get_element_text_position", element_index);
        return NULL;
    }

    return (double*)&element->element_specific.text_data.position;
}

EMSCRIPTEN_KEEPALIVE
int gds_get_element_text_presentation(void* library_ptr, int structure_index, int element_index) {
    if (!library_ptr) {
        wasm_set_error(WASM_ERROR_INVALID_PARAMETER, "Library pointer is null", "gds_get_element_text_presentation", 0);
        return 0;
    }

    wasm_library_t* lib = (wasm_library_t*)library_ptr;

    if (structure_index < 0 || structure_index >= lib->structure_count) {
        wasm_set_error(WASM_ERROR_INVALID_PARAMETER, "Structure index out of range", "gds_get_element_text_presentation", structure_index);
        return 0;
    }

    wasm_structure_t* structure = &lib->structures[structure_index];

    if (element_index < 0 || element_index >= structure->element_count) {
        wasm_set_error(WASM_ERROR_INVALID_PARAMETER, "Element index out of range", "gds_get_element_text_presentation", element_index);
        return 0;
    }

    wasm_element_t* element = &structure->elements[element_index];

    if (element->kind != WASM_ELEMENT_TEXT) {
        wasm_set_error(WASM_ERROR_INVALID_PARAMETER, "Element is not a text element", "gds_get_element_text_presentation", element_index);
        return 0;
    }

    // Combine presentation flags into a single integer for WASM interface
    wasm_text_presentation_t* pres = &element->element_specific.text_data.presentation;
    return (pres->font << 16) | (pres->horizontal_justification << 8) | pres->vertical_justification;
}

// ============================================================================
// REFERENCE ELEMENT ACCESS
// ============================================================================

EMSCRIPTEN_KEEPALIVE
const char* gds_get_element_reference_name(void* library_ptr, int structure_index, int element_index) {
    if (!library_ptr) {
        wasm_set_error(WASM_ERROR_INVALID_PARAMETER, "Library pointer is null", "gds_get_element_reference_name", 0);
        return "";
    }

    wasm_library_t* lib = (wasm_library_t*)library_ptr;

    if (structure_index < 0 || structure_index >= lib->structure_count) {
        wasm_set_error(WASM_ERROR_INVALID_PARAMETER, "Structure index out of range", "gds_get_element_reference_name", structure_index);
        return "";
    }

    wasm_structure_t* structure = &lib->structures[structure_index];

    if (element_index < 0 || element_index >= structure->element_count) {
        wasm_set_error(WASM_ERROR_INVALID_PARAMETER, "Element index out of range", "gds_get_element_reference_name", element_index);
        return "";
    }

    wasm_element_t* element = &structure->elements[element_index];

    if (element->kind == WASM_ELEMENT_SREF) {
        return element->element_specific.sref_data.structure_name;
    } else if (element->kind == WASM_ELEMENT_AREF) {
        return element->element_specific.aref_data.structure_name;
    } else {
        wasm_set_error(WASM_ERROR_INVALID_PARAMETER, "Element is not a reference element", "gds_get_element_reference_name", element_index);
        return "";
    }
}

EMSCRIPTEN_KEEPALIVE
int gds_get_element_array_columns(void* library_ptr, int structure_index, int element_index) {
    if (!library_ptr) {
        wasm_set_error(WASM_ERROR_INVALID_PARAMETER, "Library pointer is null", "gds_get_element_array_columns", 0);
        return 0;
    }

    wasm_library_t* lib = (wasm_library_t*)library_ptr;

    if (structure_index < 0 || structure_index >= lib->structure_count) {
        wasm_set_error(WASM_ERROR_INVALID_PARAMETER, "Structure index out of range", "gds_get_element_array_columns", structure_index);
        return 0;
    }

    wasm_structure_t* structure = &lib->structures[structure_index];

    if (element_index < 0 || element_index >= structure->element_count) {
        wasm_set_error(WASM_ERROR_INVALID_PARAMETER, "Element index out of range", "gds_get_element_array_columns", element_index);
        return 0;
    }

    wasm_element_t* element = &structure->elements[element_index];

    if (element->kind != WASM_ELEMENT_AREF) {
        wasm_set_error(WASM_ERROR_INVALID_PARAMETER, "Element is not an array reference", "gds_get_element_array_columns", element_index);
        return 0;
    }

    return element->element_specific.aref_data.columns;
}

EMSCRIPTEN_KEEPALIVE
int gds_get_element_array_rows(void* library_ptr, int structure_index, int element_index) {
    if (!library_ptr) {
        wasm_set_error(WASM_ERROR_INVALID_PARAMETER, "Library pointer is null", "gds_get_element_array_rows", 0);
        return 0;
    }

    wasm_library_t* lib = (wasm_library_t*)library_ptr;

    if (structure_index < 0 || structure_index >= lib->structure_count) {
        wasm_set_error(WASM_ERROR_INVALID_PARAMETER, "Structure index out of range", "gds_get_element_array_rows", structure_index);
        return 0;
    }

    wasm_structure_t* structure = &lib->structures[structure_index];

    if (element_index < 0 || element_index >= structure->element_count) {
        wasm_set_error(WASM_ERROR_INVALID_PARAMETER, "Element index out of range", "gds_get_element_array_rows", element_index);
        return 0;
    }

    wasm_element_t* element = &structure->elements[element_index];

    if (element->kind != WASM_ELEMENT_AREF) {
        wasm_set_error(WASM_ERROR_INVALID_PARAMETER, "Element is not an array reference", "gds_get_element_array_rows", element_index);
        return 0;
    }

    return element->element_specific.aref_data.rows;
}

// ============================================================================
// PROPERTY ACCESS
// ============================================================================

EMSCRIPTEN_KEEPALIVE
int gds_get_element_property_count(void* library_ptr, int structure_index, int element_index) {
    if (!library_ptr) {
        wasm_set_error(WASM_ERROR_INVALID_PARAMETER, "Library pointer is null", "gds_get_element_property_count", 0);
        return 0;
    }

    wasm_library_t* lib = (wasm_library_t*)library_ptr;

    if (structure_index < 0 || structure_index >= lib->structure_count) {
        wasm_set_error(WASM_ERROR_INVALID_PARAMETER, "Structure index out of range", "gds_get_element_property_count", structure_index);
        return 0;
    }

    wasm_structure_t* structure = &lib->structures[structure_index];

    if (element_index < 0 || element_index >= structure->element_count) {
        wasm_set_error(WASM_ERROR_INVALID_PARAMETER, "Element index out of range", "gds_get_element_property_count", element_index);
        return 0;
    }

    return structure->elements[element_index].property_count;
}

EMSCRIPTEN_KEEPALIVE
uint16_t gds_get_element_property_attribute(void* library_ptr, int structure_index, int element_index, int property_index) {
    if (!library_ptr) {
        wasm_set_error(WASM_ERROR_INVALID_PARAMETER, "Library pointer is null", "gds_get_element_property_attribute", 0);
        return 0;
    }

    wasm_library_t* lib = (wasm_library_t*)library_ptr;

    if (structure_index < 0 || structure_index >= lib->structure_count) {
        wasm_set_error(WASM_ERROR_INVALID_PARAMETER, "Structure index out of range", "gds_get_element_property_attribute", structure_index);
        return 0;
    }

    wasm_structure_t* structure = &lib->structures[structure_index];

    if (element_index < 0 || element_index >= structure->element_count) {
        wasm_set_error(WASM_ERROR_INVALID_PARAMETER, "Element index out of range", "gds_get_element_property_attribute", element_index);
        return 0;
    }

    wasm_element_t* element = &structure->elements[element_index];

    if (property_index < 0 || property_index >= element->property_count) {
        wasm_set_error(WASM_ERROR_INVALID_PARAMETER, "Property index out of range", "gds_get_element_property_attribute", property_index);
        return 0;
    }

    return element->properties[property_index].attribute;
}

EMSCRIPTEN_KEEPALIVE
const char* gds_get_element_property_value(void* library_ptr, int structure_index, int element_index, int property_index) {
    if (!library_ptr) {
        wasm_set_error(WASM_ERROR_INVALID_PARAMETER, "Library pointer is null", "gds_get_element_property_value", 0);
        return "";
    }

    wasm_library_t* lib = (wasm_library_t*)library_ptr;

    if (structure_index < 0 || structure_index >= lib->structure_count) {
        wasm_set_error(WASM_ERROR_INVALID_PARAMETER, "Structure index out of range", "gds_get_element_property_value", structure_index);
        return "";
    }

    wasm_structure_t* structure = &lib->structures[structure_index];

    if (element_index < 0 || element_index >= structure->element_count) {
        wasm_set_error(WASM_ERROR_INVALID_PARAMETER, "Element index out of range", "gds_get_element_property_value", element_index);
        return "";
    }

    wasm_element_t* element = &structure->elements[element_index];

    if (property_index < 0 || property_index >= element->property_count) {
        wasm_set_error(WASM_ERROR_INVALID_PARAMETER, "Property index out of range", "gds_get_element_property_value", property_index);
        return "";
    }

    return element->properties[property_index].value;
}

// ============================================================================
// BOUNDING BOX ACCESS
// ============================================================================

EMSCRIPTEN_KEEPALIVE
double* gds_get_element_bounds(void* library_ptr, int structure_index, int element_index) {
    if (!library_ptr) {
        wasm_set_error(WASM_ERROR_INVALID_PARAMETER, "Library pointer is null", "gds_get_element_bounds", 0);
        return NULL;
    }

    wasm_library_t* lib = (wasm_library_t*)library_ptr;

    if (structure_index < 0 || structure_index >= lib->structure_count) {
        wasm_set_error(WASM_ERROR_INVALID_PARAMETER, "Structure index out of range", "gds_get_element_bounds", structure_index);
        return NULL;
    }

    wasm_structure_t* structure = &lib->structures[structure_index];

    if (element_index < 0 || element_index >= structure->element_count) {
        wasm_set_error(WASM_ERROR_INVALID_PARAMETER, "Element index out of range", "gds_get_element_bounds", element_index);
        return NULL;
    }

    return (double*)&structure->elements[element_index].bounds;
}

EMSCRIPTEN_KEEPALIVE
double* gds_get_structure_bounds(void* library_ptr, int structure_index) {
    if (!library_ptr) {
        wasm_set_error(WASM_ERROR_INVALID_PARAMETER, "Library pointer is null", "gds_get_structure_bounds", 0);
        return NULL;
    }

    wasm_library_t* lib = (wasm_library_t*)library_ptr;

    if (structure_index < 0 || structure_index >= lib->structure_count) {
        wasm_set_error(WASM_ERROR_INVALID_PARAMETER, "Structure index out of range", "gds_get_structure_bounds", structure_index);
        return NULL;
    }

    return (double*)&lib->structures[structure_index].total_bounds;
}

// ============================================================================
// ERROR HANDLING AND VALIDATION
// ============================================================================

EMSCRIPTEN_KEEPALIVE
const char* gds_get_last_error(void) {
    return wasm_get_last_error();
}

EMSCRIPTEN_KEEPALIVE
void gds_clear_error(void) {
    wasm_clear_error();
}

EMSCRIPTEN_KEEPALIVE
int gds_validate_library(void* library_ptr) {
    return wasm_validate_library((wasm_library_t*)library_ptr);
}

EMSCRIPTEN_KEEPALIVE
void gds_get_memory_usage(int* total_allocated, int* peak_usage) {
    if (total_allocated) *total_allocated = (int)memory_stats.total_allocated;
    if (peak_usage) *peak_usage = (int)memory_stats.peak_allocated;
}

EMSCRIPTEN_KEEPALIVE
int gds_wasm_get_detected_endianness_debug(void) {
    return gds_wasm_get_detected_endianness();
}