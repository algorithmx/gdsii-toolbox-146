/*
 * GDSII WASM Adapter Header
 *
 * This header defines the interface for the WASM adapter that bridges
 * the existing GDSII parser functions with the WASM wrapper.
 *
 * Copyright (c) 2025
 */

#ifndef _GDS_WASM_ADAPTER_H
#define _GDS_WASM_ADAPTER_H

#include <stdint.h>
#include <stddef.h>

#ifdef __cplusplus
extern "C" {
#endif

// Initialize the WASM adapter with GDSII data
// Returns 0 on success, -1 on error
int gds_wasm_initialize(uint8_t* data, size_t size);

// Parse library header information
// Returns 0 on success, -1 on error
int gds_wasm_parse_library_header(void);

// Get library information
const char* gds_wasm_get_library_name(void);
double gds_wasm_get_user_units_per_db_unit(void);
double gds_wasm_get_meters_per_db_unit(void);

// Simple structure parsing
int gds_wasm_count_structures(void);
const char* gds_wasm_get_structure_name(int index);

// Error handling
const char* gds_wasm_get_error(void);

// Get debugging information about detected endianness
int gds_wasm_get_detected_endianness(void);

// Cleanup resources
void gds_wasm_cleanup(void);

// ============================================================================
// FULL WASM INTERFACE (for TypeScript compatibility - leveraging Basic/gdsio)
// ============================================================================

// Main parsing function - returns library pointer or 0 on error
void* gds_parse_from_memory(uint8_t* data, size_t size, int* error_code);

// Library management (using existing gds_libdata infrastructure)
void gds_free_library(void* library_ptr);
const char* gds_get_library_name(void* library_ptr);
double gds_get_user_units_per_db_unit(void* library_ptr);
double gds_get_meters_per_db_unit(void* library_ptr);
int gds_get_structure_count(void* library_ptr);

// Enhanced library date/time access (from existing BGNLIB parsing)
void gds_get_library_creation_date(void* library_ptr, uint16_t* date_array);
void gds_get_library_modification_date(void* library_ptr, uint16_t* date_array);

// Structure access (using existing gds_structdata infrastructure)
const char* gds_get_structure_name(void* library_ptr, int structure_index);
int gds_get_element_count(void* library_ptr, int structure_index);
void gds_get_structure_dates(void* library_ptr, int structure_index, uint16_t* cdate, uint16_t* mdate);

// Element access (using existing gds_read_element infrastructure)
int gds_get_element_type(void* library_ptr, int structure_index, int element_index);
int gds_get_element_layer(void* library_ptr, int structure_index, int element_index);
int gds_get_element_data_type(void* library_ptr, int structure_index, int element_index);

// Element flags and properties (from element_t structure)
uint16_t gds_get_element_elflags(void* library_ptr, int structure_index, int element_index);
int32_t gds_get_element_plex(void* library_ptr, int structure_index, int element_index);

// Geometry data access (from existing gds_read_element xy_block)
int gds_get_element_polygon_count(void* library_ptr, int structure_index, int element_index);
int gds_get_element_polygon_vertex_count(void* library_ptr, int structure_index, int element_index, int polygon_index);
double* gds_get_element_polygon_vertices(void* library_ptr, int structure_index, int element_index, int polygon_index);

// Path-specific data (from element_t path_data)
float gds_get_element_path_width(void* library_ptr, int structure_index, int element_index);
uint16_t gds_get_element_path_type(void* library_ptr, int structure_index, int element_index);
float gds_get_element_path_begin_extension(void* library_ptr, int structure_index, int element_index);
float gds_get_element_path_end_extension(void* library_ptr, int structure_index, int element_index);

// Text-specific data (from element_t text_data)
const char* gds_get_element_text(void* library_ptr, int structure_index, int element_index);
void gds_get_element_text_position(void* library_ptr, int structure_index, int element_index, float* x, float* y);
uint16_t gds_get_element_text_type(void* library_ptr, int structure_index, int element_index);
uint16_t gds_get_element_text_presentation(void* library_ptr, int structure_index, int element_index);

// Reference Elements (SREF/AREF) - using existing structure reference parsing
const char* gds_get_element_reference_name(void* library_ptr, int structure_index, int element_index);
int gds_get_element_array_columns(void* library_ptr, int structure_index, int element_index);
int gds_get_element_array_rows(void* library_ptr, int structure_index, int element_index);
void gds_get_element_reference_corners(void* library_ptr, int structure_index, int element_index,
                                      float* x1, float* y1, float* x2, float* y2, float* x3, float* y3);

// Transformation (strans_t structure)
uint16_t gds_get_element_strans_flags(void* library_ptr, int structure_index, int element_index);
double gds_get_element_magnification(void* library_ptr, int structure_index, int element_index);
double gds_get_element_rotation_angle(void* library_ptr, int structure_index, int element_index);

// Property access (from PROPATTR/PROPVALUE records)
int gds_get_element_property_count(void* library_ptr, int structure_index, int element_index);
uint16_t gds_get_element_property_attribute(void* library_ptr, int structure_index, int element_index, int property_index);
const char* gds_get_element_property_value(void* library_ptr, int structure_index, int element_index, int property_index);

// Error handling (from existing error system)
const char* gds_get_last_error(void);
void gds_clear_error(void);

// Validation (for WASM integrity)
int gds_validate_library(void* library_ptr);
void gds_get_memory_usage(int* total_allocated, int* peak_usage);

#ifdef __cplusplus
}
#endif

#endif /* _GDS_WASM_ADAPTER_H */