/*
 * WASM-Compatible GDSII Data Types
 *
 * This file contains data structures optimized for WebAssembly compatibility
 * and efficient memory management between C/C++ and JavaScript.
 */

#ifndef WASM_TYPES_H
#define WASM_TYPES_H

#include <stdint.h>
#include <emscripten.h>

#ifdef __cplusplus
extern "C" {
#endif

// ============================================================================
// BASIC GEOMETRY TYPES
// ============================================================================

typedef struct {
    float x, y;
} wasm_vertex_t;

typedef struct {
    float min_x, min_y;
    float max_x, max_y;
} wasm_bbox_t;

// ============================================================================
// TRANSFORMATION TYPES
// ============================================================================

typedef struct {
    uint16_t flags;
    float magnification;
    float angle;
} wasm_strans_t;

typedef struct {
    float m11, m12, m13;
    float m21, m22, m23;
    float m31, m32, m33;
} wasm_transform_matrix_t;

// ============================================================================
// PROPERTY TYPES
// ============================================================================

typedef struct {
    uint16_t attribute;
    char value[256];
} wasm_property_t;

// ============================================================================
// GEOMETRY TYPES
// ============================================================================

typedef struct {
    int polygon_count;
    int* vertex_counts;          // Array of vertex counts per polygon
    wasm_vertex_t** polygons;    // Array of polygon vertex arrays
    int total_vertex_count;      // Total vertices across all polygons
} wasm_geometry_t;

// ============================================================================
// ELEMENT TYPES
// ============================================================================

typedef enum {
    WASM_ELEMENT_BOUNDARY = 1,
    WASM_ELEMENT_PATH = 2,
    WASM_ELEMENT_BOX = 3,
    WASM_ELEMENT_NODE = 4,
    WASM_ELEMENT_TEXT = 5,
    WASM_ELEMENT_SREF = 6,
    WASM_ELEMENT_AREF = 7
} wasm_element_kind_t;

// Text presentation structure
typedef struct {
    uint16_t font;
    uint16_t vertical_justification;  // 0=top, 1=middle, 2=bottom
    uint16_t horizontal_justification; // 0=left, 1=middle, 2=right
} wasm_text_presentation_t;

// Path element data
typedef struct {
    uint16_t path_type;
    float width;
    float begin_extension;
    float end_extension;
} wasm_path_data_t;

// Text element data
typedef struct {
    char text_string[512];
    wasm_vertex_t position;
    uint16_t text_type;
    wasm_text_presentation_t presentation;
    wasm_strans_t transformation;
} wasm_text_data_t;

// SREF element data
typedef struct {
    char structure_name[256];
    int position_count;
    wasm_vertex_t* positions;
    wasm_strans_t transformation;
} wasm_sref_data_t;

// AREF element data
typedef struct {
    char structure_name[256];
    wasm_vertex_t corners[3];
    uint16_t columns;
    uint16_t rows;
    wasm_strans_t transformation;
} wasm_aref_data_t;

// Base element structure
typedef struct {
    // Core identification
    wasm_element_kind_t kind;
    uint16_t layer;
    uint16_t data_type;

    // Geometry data
    wasm_geometry_t geometry;

    // Element-specific data (union)
    union {
        wasm_path_data_t path_data;
        wasm_text_data_t text_data;
        wasm_sref_data_t sref_data;
        wasm_aref_data_t aref_data;
        // Box and node use only geometry
    } element_specific;

    // Common properties
    uint16_t elflags;
    int32_t plex;

    // Property system
    int property_count;
    wasm_property_t* properties;

    // Bounding box
    wasm_bbox_t bounds;

} wasm_element_t;

// ============================================================================
// STRUCTURE TYPES
// ============================================================================

typedef struct {
    char referenced_structure_name[256];
    int count;
    wasm_bbox_t* instance_bounds;
} wasm_structure_reference_t;

typedef struct {
    char name[256];

    // Elements directly in this structure
    int element_count;
    wasm_element_t* elements;

    // Structure references
    int reference_count;
    wasm_structure_reference_t* references;

    // Bounding box of all elements
    wasm_bbox_t total_bounds;

} wasm_structure_t;

// ============================================================================
// LIBRARY TYPES
// ============================================================================

typedef struct {
    char name[256];

    // Units and scaling
    double user_units_per_db_unit;
    double meters_per_db_unit;

    // Structure collection
    int structure_count;
    wasm_structure_t* structures;

    // Reference libraries
    int ref_lib_count;
    char* ref_libraries[128];

    // Font information
    int font_count;
    char* fonts[4];

} wasm_library_t;

// ============================================================================
// MEMORY MANAGEMENT TYPES
// ============================================================================

typedef struct {
    void* ptr;
    size_t size;
    const char* type;
    int is_allocated;
} wasm_memory_block_t;

typedef struct {
    int block_count;
    size_t total_allocated;
    size_t peak_allocated;
    wasm_memory_block_t* blocks;
} wasm_memory_stats_t;

// ============================================================================
// ERROR HANDLING TYPES
// ============================================================================

typedef enum {
    WASM_ERROR_NONE = 0,
    WASM_ERROR_PARSE_FAILED = 1,
    WASM_ERROR_INVALID_DATA = 2,
    WASM_ERROR_MEMORY_ALLOCATION = 3,
    WASM_ERROR_INVALID_PARAMETER = 4,
    WASM_ERROR_STRUCTURE_NOT_FOUND = 5,
    WASM_ERROR_ELEMENT_NOT_FOUND = 6,
    WASM_ERROR_INVALID_GDSII_FORMAT = 7,
    WASM_ERROR_UNSUPPORTED_VERSION = 8
} wasm_error_code_t;

typedef struct {
    wasm_error_code_t code;
    char message[512];
    char context[256];
    int position;
} wasm_error_t;

// ============================================================================
// CONSTANTS
// ============================================================================

#define WASM_MAX_STRING_LENGTH 512
#define WASM_MAX_PROPERTY_VALUE 256
#define WASM_MAX_STRUCTURE_NAME 256
#define WASM_MAX_REFERENCE_LIBRARIES 128
#define WASM_MAX_FONTS 4
#define WASM_MAX_POLYGON_VERTICES 8192
#define WASM_MAX_PROPERTIES 128

// GDSII record types (simplified subset for WASM interface)
#define WASM_RECORD_BOUNDARY 0x0800
#define WASM_RECORD_PATH     0x0900
#define WASM_RECORD_SREF     0x0a00
#define WASM_RECORD_AREF     0x0b00
#define WASM_RECORD_TEXT     0x0c00
#define WASM_RECORD_LAYER    0x0d02
#define WASM_RECORD_DATATYPE 0x0e02
#define WASM_RECORD_WIDTH    0x0f03
#define WASM_RECORD_XY       0x1003
#define WASM_RECORD_ENDEL    0x1100
#define WASM_RECORD_SNAME    0x1206
#define WASM_RECORD_COLROW   0x1302
#define WASM_RECORD_NODE     0x1500
#define WASM_RECORD_TEXTTYPE 0x1602
#define WASM_RECORD_PRESENTATION 0x1701
#define WASM_RECORD_STRING   0x1906
#define WASM_RECORD_STRANS   0x1a01
#define WASM_RECORD_MAG      0x1b05
#define WASM_RECORD_ANGLE    0x1c05
#define WASM_RECORD_PROPATTR 0x2b02
#define WASM_RECORD_PROPVALUE 0x2c06
#define WASM_RECORD_BOX      0x2d00
#define WASM_RECORD_BOXTYPE  0x2e02
#define WASM_RECORD_PLEX     0x2f03

// ============================================================================
// FUNCTION DECLARATIONS
// ============================================================================

// Memory management functions
void* wasm_malloc(size_t size, const char* type);
void wasm_free(void* ptr);
void wasm_get_memory_stats(wasm_memory_stats_t* stats);
void wasm_cleanup_memory(void);

// Error handling functions
void wasm_set_error(wasm_error_code_t code, const char* message, const char* context, int position);
const char* wasm_get_last_error(void);
void wasm_clear_error(void);

// Validation functions
int wasm_validate_library(wasm_library_t* lib);
int wasm_validate_structure(wasm_structure_t* structure);
int wasm_validate_element(wasm_element_t* element);

// Utility functions
void wasm_init_bbox(wasm_bbox_t* bbox);
void wasm_expand_bbox(wasm_bbox_t* bbox, const wasm_vertex_t* vertex);
int wasm_bbox_intersects(const wasm_bbox_t* bbox1, const wasm_bbox_t* bbox2);
void wasm_transform_point(const wasm_vertex_t* input, wasm_vertex_t* output, const wasm_transform_matrix_t* matrix);

#ifdef __cplusplus
}
#endif

#endif /* WASM_TYPES_H */