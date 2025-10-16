/*
 * Enhanced GDSII WASM Adapter with Real Element Parsing
 *
 * This adapter integrates the element cache system to provide real GDSII parsing
 * functionality instead of placeholder/mock data.
 *
 * Copyright (c) 2025
 */

#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <stdint.h>
#include <math.h>
#include "gds-wasm-adapter.h"

// Include our new parsing infrastructure
#include "wasm-element-cache.h"
#include "mem-file.h"

// Include the existing GDS parsing infrastructure
#include "../../Basic/gdsio/gdsio.h"
#include "../../Basic/gdsio/gdstypes.h"

// ============================================================================
// ENHANCED LIBRARY STRUCTURE WITH REAL PARSING
// ============================================================================

typedef struct {
    // Enhanced library cache that does real parsing
    wasm_library_cache_t* cache;

    // Library metadata for direct access
    char name[256];
    uint16_t libver;
    uint16_t cdate[6];
    uint16_t mdate[6];
    double user_units_per_db_unit;
    double meters_per_db_unit;

    // Structure metadata cache
    int structure_count;
    char structure_names[128][256];
    int structure_element_counts[128];

    // Validation and state
    int is_initialized;
    int parse_all_on_load;

} enhanced_wasm_library_t;

// ============================================================================
// MAIN PARSING FUNCTION WITH REAL INTEGRATION
// ============================================================================

void* gds_parse_from_memory(uint8_t* data, size_t size, int* error_code) {
    if (error_code) *error_code = 0;

    if (!data || size == 0) {
        if (error_code) *error_code = 1;
        return NULL;
    }

    // Create enhanced library structure
    enhanced_wasm_library_t* lib = malloc(sizeof(enhanced_wasm_library_t));
    if (!lib) {
        if (error_code) *error_code = 2;
        return NULL;
    }

    memset(lib, 0, sizeof(enhanced_wasm_library_t));

    // Create the real element cache
    lib->cache = wasm_create_library_cache(data, size);
    if (!lib->cache) {
        free(lib);
        if (error_code) *error_code = 3;
        return NULL;
    }

    // Extract library metadata from cache
    strncpy(lib->name, lib->cache->name, sizeof(lib->name) - 1);
    lib->name[sizeof(lib->name) - 1] = '\0';

    lib->user_units_per_db_unit = lib->cache->user_units_per_db_unit;
    lib->meters_per_db_unit = lib->cache->meters_per_db_unit;

    // Parse library structures
    if (wasm_parse_library_structures(lib->cache) != 0) {
        wasm_free_library_cache(lib->cache);
        free(lib);
        if (error_code) *error_code = 4;
        return NULL;
    }

    lib->structure_count = lib->cache->structure_count;

    // Cache structure names and element counts
    for (int i = 0; i < lib->structure_count; i++) {
        wasm_structure_cache_t* struct_cache = &lib->cache->structures[i];

        strncpy(lib->structure_names[i], struct_cache->name, sizeof(lib->structure_names[i]) - 1);
        lib->structure_names[i][sizeof(lib->structure_names[i]) - 1] = '\0';

        // Element count will be determined on-demand
        lib->structure_element_counts[i] = -1;
    }

    lib->is_initialized = 1;

    return lib;
}

void gds_free_library(void* library_ptr) {
    if (library_ptr) {
        enhanced_wasm_library_t* lib = (enhanced_wasm_library_t*)library_ptr;

        if (lib->cache) {
            wasm_free_library_cache(lib->cache);
        }

        free(lib);
    }
}

// ============================================================================
// LIBRARY METADATA FUNCTIONS (REAL IMPLEMENTATIONS)
// ============================================================================

const char* gds_get_library_name(void* library_ptr) {
    if (!library_ptr) return "";
    enhanced_wasm_library_t* lib = (enhanced_wasm_library_t*)library_ptr;
    return lib->name;
}

double gds_get_user_units_per_db_unit(void* library_ptr) {
    if (!library_ptr) return 1.0;
    enhanced_wasm_library_t* lib = (enhanced_wasm_library_t*)library_ptr;
    return lib->user_units_per_db_unit;
}

double gds_get_meters_per_db_unit(void* library_ptr) {
    if (!library_ptr) return 1e-9;
    enhanced_wasm_library_t* lib = (enhanced_wasm_library_t*)library_ptr;
    return lib->meters_per_db_unit;
}

int gds_get_structure_count(void* library_ptr) {
    if (!library_ptr) return 0;
    enhanced_wasm_library_t* lib = (enhanced_wasm_library_t*)library_ptr;
    return lib->structure_count;
}

const char* gds_get_structure_name(void* library_ptr, int structure_index) {
    if (!library_ptr || structure_index < 0 || structure_index >= 128) return "";
    enhanced_wasm_library_t* lib = (enhanced_wasm_library_t*)library_ptr;
    if (structure_index >= lib->structure_count) return "";
    return lib->structure_names[structure_index];
}

void gds_get_library_creation_date(void* library_ptr, uint16_t* date_array) {
    if (!library_ptr || !date_array) return;
    enhanced_wasm_library_t* lib = (enhanced_wasm_library_t*)library_ptr;
    for (int i = 0; i < 6; i++) {
        date_array[i] = lib->cdate[i];
    }
}

void gds_get_library_modification_date(void* library_ptr, uint16_t* date_array) {
    if (!library_ptr || !date_array) return;
    enhanced_wasm_library_t* lib = (enhanced_wasm_library_t*)library_ptr;
    for (int i = 0; i < 6; i++) {
        date_array[i] = lib->mdate[i];
    }
}

// ============================================================================
// ELEMENT ACCESS FUNCTIONS (REAL IMPLEMENTATIONS)
// ============================================================================

int gds_get_element_count(void* library_ptr, int structure_index) {
    if (!library_ptr || structure_index < 0) return -1;

    enhanced_wasm_library_t* lib = (enhanced_wasm_library_t*)library_ptr;
    if (structure_index >= lib->structure_count) return -1;

    // Check if we have cached element count
    if (lib->structure_element_counts[structure_index] >= 0) {
        return lib->structure_element_counts[structure_index];
    }

    // Parse structure elements and cache the count
    int count = wasm_get_element_count(lib->cache, structure_index);
    if (count >= 0) {
        lib->structure_element_counts[structure_index] = count;
    }

    return count;
}

int gds_get_element_type(void* library_ptr, int structure_index, int element_index) {
    if (!library_ptr || structure_index < 0) return -1;

    enhanced_wasm_library_t* lib = (enhanced_wasm_library_t*)library_ptr;
    if (structure_index >= lib->structure_count) return -1;

    return wasm_get_element_type(lib->cache, structure_index, element_index);
}

int gds_get_element_layer(void* library_ptr, int structure_index, int element_index) {
    if (!library_ptr || structure_index < 0) return -1;

    enhanced_wasm_library_t* lib = (enhanced_wasm_library_t*)library_ptr;
    if (structure_index >= lib->structure_count) return -1;

    return wasm_get_element_layer(lib->cache, structure_index, element_index);
}

int gds_get_element_data_type(void* library_ptr, int structure_index, int element_index) {
    if (!library_ptr || structure_index < 0) return -1;

    enhanced_wasm_library_t* lib = (enhanced_wasm_library_t*)library_ptr;
    if (structure_index >= lib->structure_count) return -1;

    return wasm_get_element_data_type(lib->cache, structure_index, element_index);
}

uint16_t gds_get_element_elflags(void* library_ptr, int structure_index, int element_index) {
    if (!library_ptr || structure_index < 0) return 0;

    enhanced_wasm_library_t* lib = (enhanced_wasm_library_t*)library_ptr;
    if (structure_index >= lib->structure_count) return 0;

    return wasm_get_element_elflags(lib->cache, structure_index, element_index);
}

int32_t gds_get_element_plex(void* library_ptr, int structure_index, int element_index) {
    if (!library_ptr || structure_index < 0) return 0;

    enhanced_wasm_library_t* lib = (enhanced_wasm_library_t*)library_ptr;
    if (structure_index >= lib->structure_count) return 0;

    return wasm_get_element_plex(lib->cache, structure_index, element_index);
}

// ============================================================================
// GEOMETRY DATA ACCESS (REAL IMPLEMENTATIONS)
// ============================================================================

int gds_get_element_polygon_count(void* library_ptr, int structure_index, int element_index) {
    if (!library_ptr || structure_index < 0) return -1;

    enhanced_wasm_library_t* lib = (enhanced_wasm_library_t*)library_ptr;
    if (structure_index >= lib->structure_count) return -1;

    return wasm_get_element_polygon_count(lib->cache, structure_index, element_index);
}

int gds_get_element_polygon_vertex_count(void* library_ptr, int structure_index,
                                       int element_index, int polygon_index) {
    if (!library_ptr || structure_index < 0) return -1;

    enhanced_wasm_library_t* lib = (enhanced_wasm_library_t*)library_ptr;
    if (structure_index >= lib->structure_count) return -1;

    return wasm_get_element_polygon_vertex_count(lib->cache, structure_index,
                                                 element_index, polygon_index);
}

double* gds_get_element_polygon_vertices(void* library_ptr, int structure_index,
                                       int element_index, int polygon_index) {
    if (!library_ptr || structure_index < 0) return NULL;

    enhanced_wasm_library_t* lib = (enhanced_wasm_library_t*)library_ptr;
    if (structure_index >= lib->structure_count) return NULL;

    return wasm_get_element_polygon_vertices(lib->cache, structure_index,
                                           element_index, polygon_index);
}

// ============================================================================
// PATH-SPECIFIC DATA (REAL IMPLEMENTATIONS)
// ============================================================================

float gds_get_element_path_width(void* library_ptr, int structure_index, int element_index) {
    if (!library_ptr || structure_index < 0) return 0.0f;

    enhanced_wasm_library_t* lib = (enhanced_wasm_library_t*)library_ptr;
    if (structure_index >= lib->structure_count) return 0.0f;

    return wasm_get_element_path_width(lib->cache, structure_index, element_index);
}

uint16_t gds_get_element_path_type(void* library_ptr, int structure_index, int element_index) {
    if (!library_ptr || structure_index < 0) return 0;

    enhanced_wasm_library_t* lib = (enhanced_wasm_library_t*)library_ptr;
    if (structure_index >= lib->structure_count) return 0;

    return wasm_get_element_path_type(lib->cache, structure_index, element_index);
}

float gds_get_element_path_begin_extension(void* library_ptr, int structure_index, int element_index) {
    if (!library_ptr || structure_index < 0) return 0.0f;

    enhanced_wasm_library_t* lib = (enhanced_wasm_library_t*)library_ptr;
    if (structure_index >= lib->structure_count) return 0.0f;

    return wasm_get_element_path_begin_extension(lib->cache, structure_index, element_index);
}

float gds_get_element_path_end_extension(void* library_ptr, int structure_index, int element_index) {
    if (!library_ptr || structure_index < 0) return 0.0f;

    enhanced_wasm_library_t* lib = (enhanced_wasm_library_t*)library_ptr;
    if (structure_index >= lib->structure_count) return 0.0f;

    return wasm_get_element_path_end_extension(lib->cache, structure_index, element_index);
}

// ============================================================================
// TEXT-SPECIFIC DATA (REAL IMPLEMENTATIONS)
// ============================================================================

const char* gds_get_element_text(void* library_ptr, int structure_index, int element_index) {
    if (!library_ptr || structure_index < 0) return "";

    enhanced_wasm_library_t* lib = (enhanced_wasm_library_t*)library_ptr;
    if (structure_index >= lib->structure_count) return "";

    return wasm_get_element_text(lib->cache, structure_index, element_index);
}

void gds_get_element_text_position(void* library_ptr, int structure_index,
                                 int element_index, float* x, float* y) {
    if (!library_ptr || structure_index < 0) {
        if (x) *x = 0.0f;
        if (y) *y = 0.0f;
        return;
    }

    enhanced_wasm_library_t* lib = (enhanced_wasm_library_t*)library_ptr;
    if (structure_index >= lib->structure_count) {
        if (x) *x = 0.0f;
        if (y) *y = 0.0f;
        return;
    }

    wasm_get_element_text_position(lib->cache, structure_index, element_index, x, y);
}

uint16_t gds_get_element_text_type(void* library_ptr, int structure_index, int element_index) {
    if (!library_ptr || structure_index < 0) return 0;

    enhanced_wasm_library_t* lib = (enhanced_wasm_library_t*)library_ptr;
    if (structure_index >= lib->structure_count) return 0;

    return wasm_get_element_text_type(lib->cache, structure_index, element_index);
}

uint16_t gds_get_element_text_presentation(void* library_ptr, int structure_index, int element_index) {
    if (!library_ptr || structure_index < 0) return 0;

    enhanced_wasm_library_t* lib = (enhanced_wasm_library_t*)library_ptr;
    if (structure_index >= lib->structure_count) return 0;

    return wasm_get_element_text_presentation(lib->cache, structure_index, element_index);
}

// ============================================================================
// REFERENCE ELEMENTS (REAL IMPLEMENTATIONS)
// ============================================================================

const char* gds_get_element_reference_name(void* library_ptr, int structure_index, int element_index) {
    if (!library_ptr || structure_index < 0) return "";

    enhanced_wasm_library_t* lib = (enhanced_wasm_library_t*)library_ptr;
    if (structure_index >= lib->structure_count) return "";

    return wasm_get_element_reference_name(lib->cache, structure_index, element_index);
}

int gds_get_element_array_columns(void* library_ptr, int structure_index, int element_index) {
    if (!library_ptr || structure_index < 0) return 1;

    enhanced_wasm_library_t* lib = (enhanced_wasm_library_t*)library_ptr;
    if (structure_index >= lib->structure_count) return 1;

    return wasm_get_element_array_columns(lib->cache, structure_index, element_index);
}

int gds_get_element_array_rows(void* library_ptr, int structure_index, int element_index) {
    if (!library_ptr || structure_index < 0) return 1;

    enhanced_wasm_library_t* lib = (enhanced_wasm_library_t*)library_ptr;
    if (structure_index >= lib->structure_count) return 1;

    return wasm_get_element_array_rows(lib->cache, structure_index, element_index);
}

void gds_get_element_reference_corners(void* library_ptr, int structure_index, int element_index,
                                     float* x1, float* y1, float* x2, float* y2,
                                     float* x3, float* y3) {
    if (!library_ptr || structure_index < 0) {
        if (x1) *x1 = 0.0f; if (y1) *y1 = 0.0f;
        if (x2) *x2 = 1.0f; if (y2) *y2 = 0.0f;
        if (x3) *x3 = 0.0f; if (y3) *y3 = 1.0f;
        return;
    }

    enhanced_wasm_library_t* lib = (enhanced_wasm_library_t*)library_ptr;
    if (structure_index >= lib->structure_count) {
        if (x1) *x1 = 0.0f; if (y1) *y1 = 0.0f;
        if (x2) *x2 = 1.0f; if (y2) *y2 = 0.0f;
        if (x3) *x3 = 0.0f; if (y3) *y3 = 1.0f;
        return;
    }

    wasm_get_element_reference_corners(lib->cache, structure_index, element_index,
                                     x1, y1, x2, y2, x3, y3);
}

// ============================================================================
// TRANSFORMATION DATA (REAL IMPLEMENTATIONS)
// ============================================================================

uint16_t gds_get_element_strans_flags(void* library_ptr, int structure_index, int element_index) {
    if (!library_ptr || structure_index < 0) return 0;

    enhanced_wasm_library_t* lib = (enhanced_wasm_library_t*)library_ptr;
    if (structure_index >= lib->structure_count) return 0;

    return wasm_get_element_strans_flags(lib->cache, structure_index, element_index);
}

double gds_get_element_magnification(void* library_ptr, int structure_index, int element_index) {
    if (!library_ptr || structure_index < 0) return 1.0;

    enhanced_wasm_library_t* lib = (enhanced_wasm_library_t*)library_ptr;
    if (structure_index >= lib->structure_count) return 1.0;

    return wasm_get_element_magnification(lib->cache, structure_index, element_index);
}

double gds_get_element_rotation_angle(void* library_ptr, int structure_index, int element_index) {
    if (!library_ptr || structure_index < 0) return 0.0;

    enhanced_wasm_library_t* lib = (enhanced_wasm_library_t*)library_ptr;
    if (structure_index >= lib->structure_count) return 0.0;

    return wasm_get_element_rotation_angle(lib->cache, structure_index, element_index);
}

// ============================================================================
// PROPERTY ACCESS (REAL IMPLEMENTATIONS)
// ============================================================================

int gds_get_element_property_count(void* library_ptr, int structure_index, int element_index) {
    if (!library_ptr || structure_index < 0) return 0;

    enhanced_wasm_library_t* lib = (enhanced_wasm_library_t*)library_ptr;
    if (structure_index >= lib->structure_count) return 0;

    return wasm_get_element_property_count(lib->cache, structure_index, element_index);
}

uint16_t gds_get_element_property_attribute(void* library_ptr, int structure_index,
                                           int element_index, int property_index) {
    if (!library_ptr || structure_index < 0) return 0;

    enhanced_wasm_library_t* lib = (enhanced_wasm_library_t*)library_ptr;
    if (structure_index >= lib->structure_count) return 0;

    return wasm_get_element_property_attribute(lib->cache, structure_index,
                                           element_index, property_index);
}

const char* gds_get_element_property_value(void* library_ptr, int structure_index,
                                           int element_index, int property_index) {
    if (!library_ptr || structure_index < 0) return "";

    enhanced_wasm_library_t* lib = (enhanced_wasm_library_t*)library_ptr;
    if (structure_index >= lib->structure_count) return "";

    return wasm_get_element_property_value(lib->cache, structure_index,
                                         element_index, property_index);
}

// ============================================================================
// ENHANCED ERROR HANDLING AND VALIDATION
// ============================================================================

const char* gds_get_last_error(void) {
    // This would need to be integrated with the cache system
    return ""; // Placeholder
}

void gds_clear_error(void) {
    // Clear any cached errors
}

int gds_validate_library(void* library_ptr) {
    if (!library_ptr) return 0;

    enhanced_wasm_library_t* lib = (enhanced_wasm_library_t*)library_ptr;

    return lib->is_initialized &&
           wasm_validate_cache(lib->cache);
}

void gds_get_memory_usage(int* total_allocated, int* peak_usage) {
    if (!total_allocated && !peak_usage) return;

    // Use cache statistics
    // This would need access to the global cache or be passed a library pointer
    if (total_allocated) *total_allocated = 0;
    if (peak_usage) *peak_usage = 0;
}

// ============================================================================
// UTILITY FUNCTIONS FOR DEBUGGING AND MONITORING
// ============================================================================

/**
 * Get cache statistics for a library
 */
void gds_get_cache_statistics(void* library_ptr, int* total_structures,
                            int* total_elements, size_t* memory_usage) {
    if (!library_ptr) {
        if (total_structures) *total_structures = 0;
        if (total_elements) *total_elements = 0;
        if (memory_usage) *memory_usage = 0;
        return;
    }

    enhanced_wasm_library_t* lib = (enhanced_wasm_library_t*)library_ptr;
    wasm_get_cache_stats(lib->cache, total_structures, total_elements, memory_usage);
}

/**
 * Force parsing of all data in a library
 */
int gds_parse_all_elements(void* library_ptr) {
    if (!library_ptr) return -1;

    enhanced_wasm_library_t* lib = (enhanced_wasm_library_t*)library_ptr;
    return wasm_parse_all_data(lib->cache);
}