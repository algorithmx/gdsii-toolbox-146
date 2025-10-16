/*
 * WASM Element Cache System - Consolidated Implementation
 *
 * Provides efficient caching and access to GDSII elements for WASM interface.
 * Bridges existing element_t structures with WASM-accessible data.
 *
 * This is the consolidated header after merging all implementations into 
 * wasm-element-cache.c (previously split between wasm-element-cache.c and 
 * wasm-element-cache-complete.c)
 *
 * Copyright (c) 2025
 */

#ifndef _WASM_ELEMENT_CACHE_H
#define _WASM_ELEMENT_CACHE_H

#include <stdint.h>
#include <stddef.h>
#include "../../Basic/gdsio/gdstypes.h"
#include "mem-file.h"

#ifdef __cplusplus
extern "C" {
#endif

// Maximum limits for WASM interface
#define MAX_ELEMENTS_PER_STRUCTURE 10000
#define MAX_VERTICES_PER_ELEMENT   8192
#define MAX_POLYGONS_PER_ELEMENT   100
#define MAX_PROPERTIES_PER_ELEMENT 50
#define MAX_STRUCTURE_NAME_LEN     256
#define MAX_TEXT_LEN               512

// ============================================================================
// ELEMENT CACHE STRUCTURES
// ============================================================================

/**
 * Cached polygon data for WASM access
 */
typedef struct {
    double* vertices;         // Flattened vertex array [x1, y1, x2, y2, ...]
    int vertex_count;         // Number of vertices
    int capacity;             // Allocated capacity
} wasm_polygon_t;

/**
 * Cached text data for WASM access
 */
typedef struct {
    char text[MAX_TEXT_LEN];  // Text string
    double x, y;              // Text position
    uint16_t text_type;       // Text type
    uint16_t presentation;    // Presentation flags
} wasm_text_data_t;

/**
 * Cached reference data for WASM access
 */
typedef struct {
    char structure_name[MAX_STRUCTURE_NAME_LEN];  // Referenced structure name
    double x, y;                                // Position
    uint16_t nrow, ncol;                        // Array dimensions (for AREF)
    double corners[6];                          // AREF corners [x1, y1, x2, y2, x3, y3]
} wasm_reference_data_t;

/**
 * Cached property data for WASM access
 */
typedef struct {
    uint16_t attribute;
    char value[256];
} wasm_property_t;

/**
 * Cached element for WASM access
 */
typedef struct {
    // Core element data (from element_t)
    element_kind kind;
    uint16_t layer;
    uint16_t dtype;
    uint16_t ptype;      // Path type
    uint16_t ttype;      // Text type
    uint16_t btype;      // Box type
    uint16_t ntype;      // Node type
    uint16_t present;    // Text presentation

    // Element flags
    uint16_t elflags;
    int32_t plex;

    // Transformation data
    uint16_t strans_flags;
    double magnification;
    double rotation_angle;

    // Path-specific data
    float width;
    float begin_extension;
    float end_extension;

    // Geometry data
    int polygon_count;
    wasm_polygon_t* polygons;

    // Element-specific data
    wasm_text_data_t text_data;
    wasm_reference_data_t reference_data;

    // Properties
    int property_count;
    wasm_property_t* properties;

    // Calculated bounding box
    double bounds[4];  // [min_x, min_y, max_x, max_y]

} wasm_cached_element_t;

/**
 * Structure cache for WASM access
 */
typedef struct {
    char name[MAX_STRUCTURE_NAME_LEN];
    uint16_t creation_date[6];
    uint16_t modification_date[6];

    // Element cache
    int element_count;
    int element_capacity;
    wasm_cached_element_t* elements;

    // Structure parsing info
    long file_offset;
    size_t data_size;
    int is_fully_parsed;

} wasm_structure_cache_t;

/**
 * Library cache for WASM access
 */
typedef struct {
    // Library metadata
    char name[MAX_STRUCTURE_NAME_LEN];
    uint16_t version;
    uint16_t creation_date[6];
    uint16_t modification_date[6];
    double user_units_per_db_unit;
    double meters_per_db_unit;

    // Structure cache
    int structure_count;
    int structure_capacity;
    wasm_structure_cache_t* structures;

    // File data
    uint8_t* raw_data;
    size_t data_size;

    // Memory file handle for parsing
    mem_file_t* mem_file;

} wasm_library_cache_t;

// ============================================================================
// CACHE MANAGEMENT FUNCTIONS
// ============================================================================

/**
 * Creates a new library cache
 * @param data Pointer to GDSII file data
 * @param size Size of GDSII file data
 * @return Library cache pointer or NULL on failure
 */
wasm_library_cache_t* wasm_create_library_cache(uint8_t* data, size_t size);

/**
 * Frees library cache and all associated memory
 * @param cache Library cache to free
 */
void wasm_free_library_cache(wasm_library_cache_t* cache);

/**
 * Parses all structures in the library
 * @param cache Library cache
 * @return 0 on success, -1 on error
 */
int wasm_parse_library_structures(wasm_library_cache_t* cache);

/**
 * Parses elements for a specific structure
 * @param cache Library cache
 * @param structure_index Index of structure to parse
 * @return 0 on success, -1 on error
 */
int wasm_parse_structure_elements(wasm_library_cache_t* cache, int structure_index);

// ============================================================================
// ELEMENT ACCESS FUNCTIONS
// ============================================================================

/**
 * Gets element count for a structure
 * @param cache Library cache
 * @param structure_index Structure index
 * @return Element count or -1 on error
 */
int wasm_get_element_count(wasm_library_cache_t* cache, int structure_index);

/**
 * Gets element type
 * @param cache Library cache
 * @param structure_index Structure index
 * @param element_index Element index
 * @return Element type or -1 on error
 */
int wasm_get_element_type(wasm_library_cache_t* cache, int structure_index, int element_index);

/**
 * Gets element layer
 * @param cache Library cache
 * @param structure_index Structure index
 * @param element_index Element index
 * @return Layer number or -1 on error
 */
int wasm_get_element_layer(wasm_library_cache_t* cache, int structure_index, int element_index);

/**
 * Gets element data type
 * @param cache Library cache
 * @param structure_index Structure index
 * @param element_index Element index
 * @return Data type or -1 on error
 */
int wasm_get_element_data_type(wasm_library_cache_t* cache, int structure_index, int element_index);

/**
 * Gets polygon count for an element
 * @param cache Library cache
 * @param structure_index Structure index
 * @param element_index Element index
 * @return Polygon count or -1 on error
 */
int wasm_get_element_polygon_count(wasm_library_cache_t* cache, int structure_index, int element_index);

/**
 * Gets vertex count for a specific polygon
 * @param cache Library cache
 * @param structure_index Structure index
 * @param element_index Element index
 * @param polygon_index Polygon index
 * @return Vertex count or -1 on error
 */
int wasm_get_element_polygon_vertex_count(wasm_library_cache_t* cache,
                                         int structure_index, int element_index, int polygon_index);

/**
 * Gets polygon vertices (returns pointer to cached vertex array)
 * @param cache Library cache
 * @param structure_index Structure index
 * @param element_index Element index
 * @param polygon_index Polygon index
 * @return Pointer to vertex array or NULL on error
 */
double* wasm_get_element_polygon_vertices(wasm_library_cache_t* cache,
                                         int structure_index, int element_index, int polygon_index);

/**
 * Gets element flags
 */
uint16_t wasm_get_element_elflags(wasm_library_cache_t* cache, int structure_index, int element_index);
int32_t wasm_get_element_plex(wasm_library_cache_t* cache, int structure_index, int element_index);

/**
 * Gets path-specific data
 */
float wasm_get_element_path_width(wasm_library_cache_t* cache, int structure_index, int element_index);
uint16_t wasm_get_element_path_type(wasm_library_cache_t* cache, int structure_index, int element_index);
float wasm_get_element_path_begin_extension(wasm_library_cache_t* cache, int structure_index, int element_index);
float wasm_get_element_path_end_extension(wasm_library_cache_t* cache, int structure_index, int element_index);

/**
 * Gets text-specific data
 */
const char* wasm_get_element_text(wasm_library_cache_t* cache, int structure_index, int element_index);
void wasm_get_element_text_position(wasm_library_cache_t* cache, int structure_index,
                                   int element_index, float* x, float* y);
uint16_t wasm_get_element_text_type(wasm_library_cache_t* cache, int structure_index, int element_index);
uint16_t wasm_get_element_text_presentation(wasm_library_cache_t* cache, int structure_index, int element_index);

/**
 * Gets reference data
 */
const char* wasm_get_element_reference_name(wasm_library_cache_t* cache, int structure_index, int element_index);
int wasm_get_element_array_columns(wasm_library_cache_t* cache, int structure_index, int element_index);
int wasm_get_element_array_rows(wasm_library_cache_t* cache, int structure_index, int element_index);
void wasm_get_element_reference_corners(wasm_library_cache_t* cache, int structure_index, int element_index,
                                      float* x1, float* y1, float* x2, float* y2, float* x3, float* y3);

/**
 * Gets transformation data
 */
uint16_t wasm_get_element_strans_flags(wasm_library_cache_t* cache, int structure_index, int element_index);
double wasm_get_element_magnification(wasm_library_cache_t* cache, int structure_index, int element_index);
double wasm_get_element_rotation_angle(wasm_library_cache_t* cache, int structure_index, int element_index);

/**
 * Gets property data
 */
int wasm_get_element_property_count(wasm_library_cache_t* cache, int structure_index, int element_index);
uint16_t wasm_get_element_property_attribute(wasm_library_cache_t* cache, int structure_index,
                                           int element_index, int property_index);
const char* wasm_get_element_property_value(wasm_library_cache_t* cache, int structure_index,
                                           int element_index, int property_index);

// ============================================================================
// UTILITY FUNCTIONS
// ============================================================================

/**
 * Validates cache structure
 * @param cache Library cache
 * @return 1 if valid, 0 if invalid
 */
int wasm_validate_cache(wasm_library_cache_t* cache);

/**
 * Gets cache statistics
 * @param cache Library cache
 * @param total_structures Pointer to store total structures
 * @param total_elements Pointer to store total elements
 * @param memory_usage Pointer to store memory usage in bytes
 */
void wasm_get_cache_stats(wasm_library_cache_t* cache, int* total_structures,
                        int* total_elements, size_t* memory_usage);

/**
 * Forces parsing of all lazy-loaded data
 * @param cache Library cache
 * @return 0 on success, -1 on error
 */
int wasm_parse_all_data(wasm_library_cache_t* cache);

#ifdef __cplusplus
}
#endif

#endif /* _WASM_ELEMENT_CACHE_H */