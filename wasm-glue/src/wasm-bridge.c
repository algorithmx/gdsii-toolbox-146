/*
 * WASM Bridge Implementation
 *
 * Provides Emscripten-compatible WASM exports that bridge between
 * the TypeScript interface expectations and the existing C wrapper.
 *
 * This layer handles:
 * - Integer-based handle management instead of raw pointers
 * - Memory allocation/delegation for TypeScript interop
 * - Function signature conversion for Emscripten exports
 * - Error handling and validation
 *
 * Copyright (c) 2025
 */

#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <stdint.h>
#include <errno.h>
#include <emscripten.h>

// Include our existing wrapper
#include "wasm-element-cache.h"
#include "mem-file.h"

// ============================================================================
// HANDLE MANAGEMENT
// ============================================================================

#define MAX_HANDLES 1000
#define INVALID_HANDLE 0

typedef struct {
    void* pointer;
    int type; // 1 = library, 2 = temporary_buffer
    size_t size;
} handle_entry_t;

static handle_entry_t handles[MAX_HANDLES] = {0};
static int next_handle = 1;
static int handles_initialized = 0;

// Initialize handle system (call once)
static void init_handles(void) {
    if (handles_initialized) return;

    memset(handles, 0, sizeof(handles));
    handles[0].pointer = NULL; // Reserve 0 as invalid
    handles[0].type = 0;
    next_handle = 1;
    handles_initialized = 1;
}

// Allocate a new handle for a pointer
static int allocate_handle(void* ptr, int type, size_t size) {
    init_handles();

    // Find free slot
    for (int i = 0; i < MAX_HANDLES; i++) {
        int handle = (next_handle + i) % MAX_HANDLES;
        if (handle == 0) handle = 1; // Skip 0

        if (handles[handle].pointer == NULL) {
            handles[handle].pointer = ptr;
            handles[handle].type = type;
            handles[handle].size = size;
            next_handle = (handle + 1) % MAX_HANDLES;
            if (next_handle == 0) next_handle = 1;
            return handle;
        }
    }

    return INVALID_HANDLE; // No free handles
}

// Get pointer from handle
static void* get_pointer(int handle, int expected_type) {
    if (handle <= 0 || handle >= MAX_HANDLES) {
        return NULL;
    }

    handle_entry_t* entry = &handles[handle];
    if (entry->pointer == NULL || entry->type != expected_type) {
        return NULL;
    }

    return entry->pointer;
}

// Free handle
static void free_handle(int handle) {
    if (handle <= 0 || handle >= MAX_HANDLES) {
        return;
    }

    handle_entry_t* entry = &handles[handle];
    if (entry->pointer) {
        // Free associated memory if it's a temporary buffer
        if (entry->type == 2) {
            free(entry->pointer);
        }
    }

    entry->pointer = NULL;
    entry->type = 0;
    entry->size = 0;
}

// ============================================================================
// ERROR HANDLING
// ============================================================================

static char last_error[256] = "";

void set_last_error(const char* error) {
    if (error) {
        strncpy(last_error, error, sizeof(last_error) - 1);
        last_error[sizeof(last_error) - 1] = '\0';
    } else {
        last_error[0] = '\0';
    }
}

// ============================================================================
// MAIN PARSING FUNCTIONS
// ============================================================================

/**
 * Parse GDSII data from memory
 * Returns library handle on success, 0 on failure
 */
EMSCRIPTEN_KEEPALIVE
int gds_parse_from_memory(uint8_t* data, int size, int* error_code) {
    if (!data || size <= 0 || !error_code) {
        if (error_code) *error_code = -1;
        set_last_error("Invalid parameters");
        return 0;
    }

    *error_code = 0;
    set_last_error("");

    // Create library cache using existing wrapper
    wasm_library_cache_t* cache = wasm_create_library_cache(data, (size_t)size);
    if (!cache) {
        *error_code = -2;
        set_last_error("Failed to create library cache");
        return 0;
    }

    // Parse all structures to make data immediately available
    if (wasm_parse_library_structures(cache) != 0) {
        wasm_free_library_cache(cache);
        *error_code = -3;
        set_last_error("Failed to parse library structures");
        return 0;
    }

    // Allocate handle for the library
    int handle = allocate_handle(cache, 1, 0);
    if (handle == INVALID_HANDLE) {
        wasm_free_library_cache(cache);
        *error_code = -4;
        set_last_error("Too many open libraries");
        return 0;
    }

    return handle;
}

/**
 * Free a library and all its resources
 */
EMSCRIPTEN_KEEPALIVE
void gds_free_library(int library_handle) {
    wasm_library_cache_t* cache = (wasm_library_cache_t*)get_pointer(library_handle, 1);
    if (cache) {
        wasm_free_library_cache(cache);
        free_handle(library_handle);
    }
}

// ============================================================================
// LIBRARY METADATA FUNCTIONS
// ============================================================================

/**
 * Get library name
 * Returns temporary string (copy before next call)
 */
EMSCRIPTEN_KEEPALIVE
const char* gds_get_library_name(int library_handle) {
    wasm_library_cache_t* cache = (wasm_library_cache_t*)get_pointer(library_handle, 1);
    if (!cache) {
        set_last_error("Invalid library handle");
        return "";
    }

    return cache->name;
}

/**
 * Get structure count
 */
EMSCRIPTEN_KEEPALIVE
int gds_get_structure_count(int library_handle) {
    wasm_library_cache_t* cache = (wasm_library_cache_t*)get_pointer(library_handle, 1);
    if (!cache) {
        set_last_error("Invalid library handle");
        return 0;
    }

    return cache->structure_count;
}

/**
 * Get structure name
 * Returns temporary string (copy before next call)
 */
EMSCRIPTEN_KEEPALIVE
const char* gds_get_structure_name(int library_handle, int structure_index) {
    wasm_library_cache_t* cache = (wasm_library_cache_t*)get_pointer(library_handle, 1);
    if (!cache) {
        set_last_error("Invalid library handle");
        return "";
    }

    if (structure_index < 0 || structure_index >= cache->structure_count) {
        set_last_error("Invalid structure index");
        return "";
    }

    return cache->structures[structure_index].name;
}

/**
 * Get user units per database unit
 */
EMSCRIPTEN_KEEPALIVE
double gds_get_user_units_per_db_unit(int library_handle) {
    wasm_library_cache_t* cache = (wasm_library_cache_t*)get_pointer(library_handle, 1);
    if (!cache) {
        set_last_error("Invalid library handle");
        return 0.001;
    }

    return cache->user_units_per_db_unit;
}

/**
 * Get meters per database unit
 */
EMSCRIPTEN_KEEPALIVE
double gds_get_meters_per_db_unit(int library_handle) {
    wasm_library_cache_t* cache = (wasm_library_cache_t*)get_pointer(library_handle, 1);
    if (!cache) {
        set_last_error("Invalid library handle");
        return 1e-9;
    }

    return cache->meters_per_db_unit;
}

// ============================================================================
// ELEMENT ACCESS FUNCTIONS
// ============================================================================

/**
 * Get element count for a structure
 */
EMSCRIPTEN_KEEPALIVE
int gds_get_element_count(int library_handle, int structure_index) {
    wasm_library_cache_t* cache = (wasm_library_cache_t*)get_pointer(library_handle, 1);
    if (!cache) {
        set_last_error("Invalid library handle");
        return 0;
    }

    if (structure_index < 0 || structure_index >= cache->structure_count) {
        set_last_error("Invalid structure index");
        return 0;
    }

    return wasm_get_element_count(cache, structure_index);
}

/**
 * Get element type
 */
EMSCRIPTEN_KEEPALIVE
int gds_get_element_type(int library_handle, int structure_index, int element_index) {
    wasm_library_cache_t* cache = (wasm_library_cache_t*)get_pointer(library_handle, 1);
    if (!cache) {
        set_last_error("Invalid library handle");
        return -1;
    }

    if (structure_index < 0 || structure_index >= cache->structure_count) {
        set_last_error("Invalid structure index");
        return -1;
    }

    return wasm_get_element_type(cache, structure_index, element_index);
}

/**
 * Get element layer
 */
EMSCRIPTEN_KEEPALIVE
int gds_get_element_layer(int library_handle, int structure_index, int element_index) {
    wasm_library_cache_t* cache = (wasm_library_cache_t*)get_pointer(library_handle, 1);
    if (!cache) {
        set_last_error("Invalid library handle");
        return -1;
    }

    if (structure_index < 0 || structure_index >= cache->structure_count) {
        set_last_error("Invalid structure index");
        return -1;
    }

    return wasm_get_element_layer(cache, structure_index, element_index);
}

/**
 * Get element data type
 */
EMSCRIPTEN_KEEPALIVE
int gds_get_element_data_type(int library_handle, int structure_index, int element_index) {
    wasm_library_cache_t* cache = (wasm_library_cache_t*)get_pointer(library_handle, 1);
    if (!cache) {
        set_last_error("Invalid library handle");
        return 0;
    }

    if (structure_index < 0 || structure_index >= cache->structure_count) {
        set_last_error("Invalid structure index");
        return 0;
    }

    return wasm_get_element_data_type(cache, structure_index, element_index);
}

// ============================================================================
// POLYGON DATA FUNCTIONS
// ============================================================================

/**
 * Get polygon count for an element
 */
EMSCRIPTEN_KEEPALIVE
int gds_get_element_polygon_count(int library_handle, int structure_index, int element_index) {
    wasm_library_cache_t* cache = (wasm_library_cache_t*)get_pointer(library_handle, 1);
    if (!cache) {
        set_last_error("Invalid library handle");
        return 0;
    }

    if (structure_index < 0 || structure_index >= cache->structure_count) {
        set_last_error("Invalid structure index");
        return 0;
    }

    return wasm_get_element_polygon_count(cache, structure_index, element_index);
}

/**
 * Get vertex count for a specific polygon
 */
EMSCRIPTEN_KEEPALIVE
int gds_get_element_polygon_vertex_count(int library_handle, int structure_index,
                                         int element_index, int polygon_index) {
    wasm_library_cache_t* cache = (wasm_library_cache_t*)get_pointer(library_handle, 1);
    if (!cache) {
        set_last_error("Invalid library handle");
        return 0;
    }

    if (structure_index < 0 || structure_index >= cache->structure_count) {
        set_last_error("Invalid structure index");
        return 0;
    }

    return wasm_get_element_polygon_vertex_count(cache, structure_index, element_index, polygon_index);
}

/**
 * Get polygon vertices
 * Returns handle to temporary double array (caller must free with gds_free_temporary)
 */
EMSCRIPTEN_KEEPALIVE
int gds_get_element_polygon_vertices(int library_handle, int structure_index,
                                     int element_index, int polygon_index) {
    wasm_library_cache_t* cache = (wasm_library_cache_t*)get_pointer(library_handle, 1);
    if (!cache) {
        set_last_error("Invalid library handle");
        return 0;
    }

    if (structure_index < 0 || structure_index >= cache->structure_count) {
        set_last_error("Invalid structure index");
        return 0;
    }

    double* vertices = wasm_get_element_polygon_vertices(cache, structure_index, element_index, polygon_index);
    if (!vertices) {
        set_last_error("Failed to get polygon vertices");
        return 0;
    }

    // Get vertex count
    int vertex_count = wasm_get_element_polygon_vertex_count(cache, structure_index, element_index, polygon_index);
    if (vertex_count <= 0) {
        set_last_error("Invalid vertex count");
        return 0;
    }

    // Allocate temporary buffer for vertices
    size_t buffer_size = vertex_count * 2 * sizeof(double); // x,y pairs
    double* temp_buffer = (double*)malloc(buffer_size);
    if (!temp_buffer) {
        set_last_error("Failed to allocate temporary buffer");
        return 0;
    }

    // Copy vertices to temporary buffer
    memcpy(temp_buffer, vertices, buffer_size);

    // Allocate handle for temporary buffer
    int handle = allocate_handle(temp_buffer, 2, buffer_size);
    if (handle == INVALID_HANDLE) {
        free(temp_buffer);
        set_last_error("Failed to allocate handle for temporary buffer");
        return 0;
    }

    return handle;
}

/**
 * Free temporary buffer created by gds_get_element_polygon_vertices
 */
EMSCRIPTEN_KEEPALIVE
void gds_free_temporary(int handle) {
    free_handle(handle);
}

// ============================================================================
// PATH ELEMENT FUNCTIONS (Stubs for now)
// ============================================================================

EMSCRIPTEN_KEEPALIVE
float gds_get_element_path_width(int library_handle, int structure_index, int element_index) {
    (void)library_handle; (void)structure_index; (void)element_index;
    return 0.0; // Default width
}

EMSCRIPTEN_KEEPALIVE
int gds_get_element_path_type(int library_handle, int structure_index, int element_index) {
    (void)library_handle; (void)structure_index; (void)element_index;
    return 0; // Default path type
}

EMSCRIPTEN_KEEPALIVE
float gds_get_element_path_begin_extension(int library_handle, int structure_index, int element_index) {
    (void)library_handle; (void)structure_index; (void)element_index;
    return 0.0;
}

EMSCRIPTEN_KEEPALIVE
float gds_get_element_path_end_extension(int library_handle, int structure_index, int element_index) {
    (void)library_handle; (void)structure_index; (void)element_index;
    return 0.0;
}

// ============================================================================
// TEXT ELEMENT FUNCTIONS (Stubs for now)
// ============================================================================

EMSCRIPTEN_KEEPALIVE
const char* gds_get_element_text(int library_handle, int structure_index, int element_index) {
    (void)library_handle; (void)structure_index; (void)element_index;
    return "";
}

EMSCRIPTEN_KEEPALIVE
void gds_get_element_text_position(int library_handle, int structure_index, int element_index,
                                   float* x, float* y) {
    if (x) *x = 0.0;
    if (y) *y = 0.0;
    (void)library_handle; (void)structure_index; (void)element_index;
}

EMSCRIPTEN_KEEPALIVE
int gds_get_element_text_type(int library_handle, int structure_index, int element_index) {
    (void)library_handle; (void)structure_index; (void)element_index;
    return 0;
}

EMSCRIPTEN_KEEPALIVE
int gds_get_element_text_presentation(int library_handle, int structure_index, int element_index) {
    (void)library_handle; (void)structure_index; (void)element_index;
    return 0;
}

// ============================================================================
// REFERENCE ELEMENT FUNCTIONS (Stubs for now)
// ============================================================================

EMSCRIPTEN_KEEPALIVE
const char* gds_get_element_reference_name(int library_handle, int structure_index, int element_index) {
    (void)library_handle; (void)structure_index; (void)element_index;
    return "";
}

EMSCRIPTEN_KEEPALIVE
int gds_get_element_array_columns(int library_handle, int structure_index, int element_index) {
    (void)library_handle; (void)structure_index; (void)element_index;
    return 1;
}

EMSCRIPTEN_KEEPALIVE
int gds_get_element_array_rows(int library_handle, int structure_index, int element_index) {
    (void)library_handle; (void)structure_index; (void)element_index;
    return 1;
}

EMSCRIPTEN_KEEPALIVE
void gds_get_element_reference_corners(int library_handle, int structure_index, int element_index,
                                       float* x1, float* y1, float* x2, float* y2, float* x3, float* y3) {
    if (x1) *x1 = 0.0;
    if (y1) *y1 = 0.0;
    if (x2) *x2 = 1.0;
    if (y2) *y2 = 0.0;
    if (x3) *x3 = 0.0;
    if (y3) *y3 = 1.0;
    (void)library_handle; (void)structure_index; (void)element_index;
}

// ============================================================================
// TRANSFORMATION FUNCTIONS (Stubs for now)
// ============================================================================

EMSCRIPTEN_KEEPALIVE
int gds_get_element_strans_flags(int library_handle, int structure_index, int element_index) {
    (void)library_handle; (void)structure_index; (void)element_index;
    return 0;
}

EMSCRIPTEN_KEEPALIVE
double gds_get_element_magnification(int library_handle, int structure_index, int element_index) {
    (void)library_handle; (void)structure_index; (void)element_index;
    return 1.0;
}

EMSCRIPTEN_KEEPALIVE
double gds_get_element_rotation_angle(int library_handle, int structure_index, int element_index) {
    (void)library_handle; (void)structure_index; (void)element_index;
    return 0.0;
}

// ============================================================================
// PROPERTY FUNCTIONS (Stubs for now)
// ============================================================================

EMSCRIPTEN_KEEPALIVE
int gds_get_element_property_count(int library_handle, int structure_index, int element_index) {
    (void)library_handle; (void)structure_index; (void)element_index;
    return 0;
}

EMSCRIPTEN_KEEPALIVE
int gds_get_element_property_attribute(int library_handle, int structure_index,
                                       int element_index, int property_index) {
    (void)library_handle; (void)structure_index; (void)element_index; (void)property_index;
    return 0;
}

EMSCRIPTEN_KEEPALIVE
const char* gds_get_element_property_value(int library_handle, int structure_index,
                                            int element_index, int property_index) {
    (void)library_handle; (void)structure_index; (void)element_index; (void)property_index;
    return "";
}

// ============================================================================
// UTILITY FUNCTIONS
// ============================================================================

/**
 * Get last error message
 */
EMSCRIPTEN_KEEPALIVE
const char* gds_get_last_error(void) {
    return last_error;
}

/**
 * Validate library handle
 */
EMSCRIPTEN_KEEPALIVE
int gds_validate_library(int library_handle) {
    wasm_library_cache_t* cache = (wasm_library_cache_t*)get_pointer(library_handle, 1);
    return (cache != NULL && wasm_validate_cache(cache)) ? 1 : 0;
}

/**
 * Get library statistics
 */
EMSCRIPTEN_KEEPALIVE
void gds_get_library_stats(int library_handle, int* total_structures,
                           int* total_elements, int* memory_usage_kb) {
    if (total_structures) *total_structures = 0;
    if (total_elements) *total_elements = 0;
    if (memory_usage_kb) *memory_usage_kb = 0;

    wasm_library_cache_t* cache = (wasm_library_cache_t*)get_pointer(library_handle, 1);
    if (!cache) {
        return;
    }

    int total_elems = 0;
    size_t memory_bytes = 0;
    wasm_get_cache_stats(cache, total_structures, &total_elems, &memory_bytes);

    if (total_elements) *total_elements = total_elems;
    if (memory_usage_kb) *memory_usage_kb = (int)(memory_bytes / 1024);
}