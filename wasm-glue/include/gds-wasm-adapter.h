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

#ifdef __cplusplus
}
#endif

#endif /* _GDS_WASM_ADAPTER_H */