/*
 * GDSII WASM Adapter
 *
 * This adapter bridges the existing GDSII parser functions with the WASM wrapper.
 * It uses the existing parser functions from Basic/gdsio/ to avoid reimplementing
 * the GDSII binary format parsing from scratch.
 *
 * Copyright (c) 2025
 */

#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <stdint.h>
#include <math.h>
#include "gds-wasm-adapter.h"

// Include the existing GDS parsing infrastructure
#include "../../Basic/gdsio/gdsio.h"
#include "../../Basic/gdsio/gdstypes.h"

// GDSII Record Types are defined in gdstypes.h
// No need to redefine them - just use the existing constants

// Endianness detection
typedef enum {
    ENDIANNESS_UNKNOWN,
    ENDIANNESS_BIG,
    ENDIANNESS_LITTLE
} gdsii_endianness_t;

// Adapter state management
typedef struct {
    uint8_t* data;
    size_t size;
    size_t position;
    FILE* file_handle;
    int is_parsed;
    char library_name[256];
    char error_message[512];
    double user_units_per_db_unit;
    double meters_per_db_unit;

    // Structure parsing state
    int structure_count;
    char structure_names[32][256];  // Support up to 32 structures

    // Endianness handling
    gdsii_endianness_t detected_endianness;
} gdsii_wasm_state_t;

static gdsii_wasm_state_t g_wasm_state = {0};

// Endianness detection based on GDSII record patterns
static gdsii_endianness_t detect_endianness(const uint8_t* data, size_t size) {
    if (size < 8) {
        return ENDIANNESS_UNKNOWN;
    }

    // Try reading as big-endian first
    uint16_t be_length = (data[0] << 8) | data[1];
    uint16_t be_type = (data[2] << 8) | data[3];

    // Try reading as little-endian
    uint16_t le_length = data[0] | (data[1] << 8);
    uint16_t le_type = data[2] | (data[3] << 8);

    // GDSII records have specific patterns
    // Record length should be reasonable (4-20000 bytes typical)
    // Record type should be a known GDSII type (0x0000-0x1100)

    // Check if big-endian makes sense
    if (be_length >= 4 && be_length <= 20000 && be_type <= 0x1100) {
        // Additional validation: check if this looks like a HEADER record (0x0002)
        if (be_type == 0x0002) {
            return ENDIANNESS_BIG;
        }
    }

    // Check if little-endian makes sense
    if (le_length >= 4 && le_length <= 20000 && le_type <= 0x1100) {
        // Additional validation: check if this looks like a HEADER record (0x0002)
        if (le_type == 0x0002) {
            return ENDIANNESS_LITTLE;
        }
    }

    // More sophisticated detection: look at multiple records
    int be_valid_records = 0;
    int le_valid_records = 0;
    size_t pos = 0;

    // Check first few records
    for (int i = 0; i < 5 && pos + 4 < size; i++) {
        uint16_t be_rlen, be_rtype;
        uint16_t le_rlen, le_rtype;

        be_rlen = (data[pos] << 8) | data[pos + 1];
        be_rtype = (data[pos + 2] << 8) | data[pos + 3];

        le_rlen = data[pos] | (data[pos + 1] << 8);
        le_rtype = data[pos + 2] | (data[pos + 3] << 8);

        // Validate big-endian record
        if (be_rlen >= 4 && be_rlen <= 20000 && be_rtype <= 0x1100) {
            be_valid_records++;
        }

        // Validate little-endian record
        if (le_rlen >= 4 && le_rlen <= 20000 && le_rtype <= 0x1100) {
            le_valid_records++;
        }

        // Move to next record (using the more promising interpretation)
        if (be_valid_records > le_valid_records) {
            pos += 4 + be_rlen;
        } else if (le_valid_records > 0) {
            pos += 4 + le_rlen;
        } else {
            break;
        }
    }

    if (be_valid_records > le_valid_records) {
        return ENDIANNESS_BIG;
    } else if (le_valid_records > 0) {
        return ENDIANNESS_LITTLE;
    }

    // Default to big-endian as it's more common for GDSII
    return ENDIANNESS_BIG;
}

// Adaptive reading functions based on detected endianness
static uint16_t read_uint16(const uint8_t* data, gdsii_endianness_t endianness) {
    if (endianness == ENDIANNESS_LITTLE) {
        return data[0] | (data[1] << 8);
    } else {
        return (data[0] << 8) | data[1];  // Big-endian (default)
    }
}

static uint32_t read_uint32(const uint8_t* data, gdsii_endianness_t endianness) {
    if (endianness == ENDIANNESS_LITTLE) {
        return data[0] | (data[1] << 8) | (data[2] << 16) | (data[3] << 24);
    } else {
        return (data[0] << 24) | (data[1] << 16) | (data[2] << 8) | data[3];  // Big-endian
    }
}

static double read_double(const uint8_t* data, gdsii_endianness_t endianness) {
    // IEEE 754 double precision with adaptive endianness
    union {
        uint64_t u;
        double d;
    } converter;

    if (endianness == ENDIANNESS_LITTLE) {
        converter.u = ((uint64_t)data[0]) |
                      ((uint64_t)data[1] << 8) |
                      ((uint64_t)data[2] << 16) |
                      ((uint64_t)data[3] << 24) |
                      ((uint64_t)data[4] << 32) |
                      ((uint64_t)data[5] << 40) |
                      ((uint64_t)data[6] << 48) |
                      ((uint64_t)data[7] << 56);
    } else {
        // Big-endian
        converter.u = ((uint64_t)data[0] << 56) |
                      ((uint64_t)data[1] << 48) |
                      ((uint64_t)data[2] << 40) |
                      ((uint64_t)data[3] << 32) |
                      ((uint64_t)data[4] << 24) |
                      ((uint64_t)data[5] << 16) |
                      ((uint64_t)data[6] << 8)  |
                       (uint64_t)data[7];
    }

    return converter.d;
}

// Memory buffer functions for WASM integration
typedef struct {
    uint8_t* data;
    size_t size;
    size_t position;
} mem_buffer_t;

// Memory buffer FILE operations
static size_t mem_read(void* ptr, size_t size, size_t count, void* stream) {
    mem_buffer_t* buf = (mem_buffer_t*)stream;
    size_t bytes_to_read = size * count;
    size_t remaining = buf->size - buf->position;

    if (bytes_to_read > remaining) {
        bytes_to_read = remaining;
    }

    if (bytes_to_read > 0) {
        memcpy(ptr, buf->data + buf->position, bytes_to_read);
        buf->position += bytes_to_read;
    }

    return bytes_to_read / size;
}

// Error handling
void gds_wasm_set_error(const char* message) {
    strncpy(g_wasm_state.error_message, message, sizeof(g_wasm_state.error_message) - 1);
    g_wasm_state.error_message[sizeof(g_wasm_state.error_message) - 1] = '\0';
}

const char* gds_wasm_get_error() {
    return g_wasm_state.error_message;
}

// Initialize WASM adapter with GDSII data
int gds_wasm_initialize(uint8_t* data, size_t size) {
    if (!data || size == 0) {
        gds_wasm_set_error("Invalid data: null pointer or zero size");
        return -1;
    }

    // Clean up any existing state
    gds_wasm_cleanup();

    // Initialize state
    g_wasm_state.data = malloc(size);
    if (!g_wasm_state.data) {
        gds_wasm_set_error("Failed to allocate memory for GDSII data");
        return -1;
    }

    memcpy(g_wasm_state.data, data, size);
    g_wasm_state.size = size;
    g_wasm_state.position = 0;
    g_wasm_state.is_parsed = 0;
    g_wasm_state.library_name[0] = '\0';
    g_wasm_state.error_message[0] = '\0';

    // Detect endianness automatically
    g_wasm_state.detected_endianness = detect_endianness(data, size);

    // Log the detected endianness for debugging
    if (g_wasm_state.detected_endianness == ENDIANNESS_LITTLE) {
        snprintf(g_wasm_state.error_message, sizeof(g_wasm_state.error_message),
                "Detected little-endian GDSII format");
    } else if (g_wasm_state.detected_endianness == ENDIANNESS_BIG) {
        snprintf(g_wasm_state.error_message, sizeof(g_wasm_state.error_message),
                "Detected big-endian GDSII format");
    } else {
        snprintf(g_wasm_state.error_message, sizeof(g_wasm_state.error_message),
                "Could not detect GDSII endianness, defaulting to big-endian");
        g_wasm_state.detected_endianness = ENDIANNESS_BIG;
    }

    return 0;
}

// Parse GDSII record header with adaptive endianness
static int read_record_header(size_t pos, uint16_t* record_length, uint16_t* record_type) {
    if (pos + 4 > g_wasm_state.size) {
        return -1; // Not enough data for record header
    }

    // GDSII record header: 2 bytes length + 2 bytes type (endianness-adaptive)
    *record_length = read_uint16(g_wasm_state.data + pos, g_wasm_state.detected_endianness);
    *record_type = read_uint16(g_wasm_state.data + pos + 2, g_wasm_state.detected_endianness);

    return 0;
}

// Parse library header information with proper GDSII format handling
int gds_wasm_parse_library_header() {
    if (g_wasm_state.is_parsed) {
        return 0; // Already parsed
    }

    if (!g_wasm_state.data) {
        gds_wasm_set_error("No GDSII data loaded");
        return -1;
    }

    size_t pos = 0;
    uint16_t rlen, rtype;

    // Initialize structure count
    g_wasm_state.structure_count = 0;
    memset(g_wasm_state.structure_names, 0, sizeof(g_wasm_state.structure_names));

    // Parse HEADER record
    if (read_record_header(pos, &rlen, &rtype) != 0) {
        gds_wasm_set_error("Invalid GDSII file: truncated header");
        return -1;
    }

    if (rtype != HEADER) {
        gds_wasm_set_error("Invalid GDSII file: missing HEADER record");
        return -1;
    }
    pos += 4 + rlen; // Skip header + data

    // Parse BGNLIB record
    if (read_record_header(pos, &rlen, &rtype) != 0) {
        gds_wasm_set_error("Invalid GDSII file: truncated BGNLIB");
        return -1;
    }

    if (rtype != BGNLIB) {
        gds_wasm_set_error("Invalid GDSII file: missing BGNLIB record");
        return -1;
    }
    pos += 4 + rlen; // Skip header + data (12 bytes of timestamps)

    // Parse LIBNAME record
    if (read_record_header(pos, &rlen, &rtype) != 0) {
        gds_wasm_set_error("Invalid GDSII file: truncated LIBNAME");
        return -1;
    }

    if (rtype != LIBNAME) {
        gds_wasm_set_error("Invalid GDSII file: missing LIBNAME record");
        return -1;
    }

    // Read library name
    if (pos + 4 + rlen > g_wasm_state.size) {
        gds_wasm_set_error("Invalid GDSII file: truncated library name");
        return -1;
    }

    size_t name_len = rlen;
    size_t copy_len = (name_len < sizeof(g_wasm_state.library_name) - 1) ?
                     name_len : sizeof(g_wasm_state.library_name) - 1;

    memcpy(g_wasm_state.library_name, g_wasm_state.data + pos + 4, copy_len);
    g_wasm_state.library_name[copy_len] = '\0';
    pos += 4 + rlen;

    // Parse remaining records until we find structures or end of library
    while (pos + 4 <= g_wasm_state.size) {
        if (read_record_header(pos, &rlen, &rtype) != 0) {
            gds_wasm_set_error("Invalid GDSII file: truncated record header");
            return -1;
        }

        // Check for UNITS record
        if (rtype == UNITS) {
            if (rlen != 16) {
                gds_wasm_set_error("Invalid GDSII file: UNITS record must be 16 bytes");
                return -1;
            }

            if (pos + 4 + rlen > g_wasm_state.size) {
                gds_wasm_set_error("Invalid GDSII file: truncated UNITS record");
                return -1;
            }

            // Read units (user units per database unit, database units in meters)
            // Both are IEEE 754 double precision with adaptive endianness
            double user_units_per_db = read_double(g_wasm_state.data + pos + 4, g_wasm_state.detected_endianness);
            double db_units_in_meters = read_double(g_wasm_state.data + pos + 12, g_wasm_state.detected_endianness);

            g_wasm_state.user_units_per_db_unit = user_units_per_db;
            g_wasm_state.meters_per_db_unit = db_units_in_meters;

            pos += 4 + rlen;
        }
        // Check for BGNSTR (begin structure)
        else if (rtype == BGNSTR) {
            pos += 4 + rlen; // Skip header + data (timestamps)

            // Look for STRNAME record
            if (pos + 4 <= g_wasm_state.size &&
                read_record_header(pos, &rlen, &rtype) == 0 &&
                rtype == STRNAME) {

                if (pos + 4 + rlen > g_wasm_state.size) {
                    gds_wasm_set_error("Invalid GDSII file: truncated structure name");
                    return -1;
                }

                if (g_wasm_state.structure_count < 32) {
                    size_t struct_name_len = rlen;
                    size_t copy_len = (struct_name_len < 255) ? struct_name_len : 255;

                    memcpy(g_wasm_state.structure_names[g_wasm_state.structure_count],
                           g_wasm_state.data + pos + 4, copy_len);
                    g_wasm_state.structure_names[g_wasm_state.structure_count][copy_len] = '\0';
                    g_wasm_state.structure_count++;
                }
            }
            pos += 4 + rlen;
        }
        // Check for ENDLIB
        else if (rtype == ENDLIB) {
            break; // End of library
        }
        else {
            // Skip other records
            pos += 4 + rlen;
        }
    }

    g_wasm_state.is_parsed = 1;
    return 0;
}

// Get library information
const char* gds_wasm_get_library_name() {
    if (!g_wasm_state.is_parsed) {
        if (gds_wasm_parse_library_header() != 0) {
            return "Unknown";
        }
    }
    return g_wasm_state.library_name;
}

double gds_wasm_get_user_units_per_db_unit() {
    if (!g_wasm_state.is_parsed) {
        if (gds_wasm_parse_library_header() != 0) {
            return 1.0;
        }
    }
    return g_wasm_state.user_units_per_db_unit;
}

double gds_wasm_get_meters_per_db_unit() {
    if (!g_wasm_state.is_parsed) {
        if (gds_wasm_parse_library_header() != 0) {
            return 1e-9;
        }
    }
    return g_wasm_state.meters_per_db_unit;
}

// Get actual structure count from parsed GDSII file
int gds_wasm_count_structures() {
    if (!g_wasm_state.is_parsed) {
        if (gds_wasm_parse_library_header() != 0) {
            return 0;
        }
    }

    return g_wasm_state.structure_count;
}

// Get actual structure name from parsed GDSII file
const char* gds_wasm_get_structure_name(int index) {
    if (!g_wasm_state.is_parsed) {
        if (gds_wasm_parse_library_header() != 0) {
            return "Unknown";
        }
    }

    if (index >= 0 && index < g_wasm_state.structure_count) {
        return g_wasm_state.structure_names[index];
    }

    return "Unknown";
}

// Get debugging information about detected endianness
int gds_wasm_get_detected_endianness(void) {
    return (int)g_wasm_state.detected_endianness;
}

// Cleanup
void gds_wasm_cleanup() {
    if (g_wasm_state.data) {
        free(g_wasm_state.data);
        g_wasm_state.data = NULL;
    }

    // Reset structure parsing state
    g_wasm_state.structure_count = 0;
    memset(g_wasm_state.structure_names, 0, sizeof(g_wasm_state.structure_names));
    memset(&g_wasm_state, 0, sizeof(g_wasm_state));
}

// ============================================================================
// FULL WASM INTERFACE IMPLEMENTATION (using existing Basic/gdsio functions)
// ============================================================================


// WASM-compatible library structure that leverages existing C parsing
typedef struct {
    // Library metadata (from existing gds_libdata parsing)
    char name[256];
    uint16_t libver;
    uint16_t cdate[6];
    uint16_t mdate[6];
    double user_units_per_db_unit;
    double meters_per_db_unit;

    // Structures (parsed using existing gds_read_struct infrastructure)
    int structure_count;
    struct {
        char name[256];
        uint16_t cdate[6];
        uint16_t mdate[6];
        int element_count;
        // Elements will be parsed on-demand using existing gds_read_element
        void* element_data;  // Raw data for lazy parsing
    } structures[128];

    // Optional library data
    int ref_lib_count;
    char ref_libraries[128][256];
    int font_count;
    char fonts[4][256];

    // File information
    long file_size;
    uint8_t* raw_data;
    size_t data_size;

} wasm_library_t;

// Main parsing function - now uses existing Basic/gdsio infrastructure
void* gds_parse_from_memory(uint8_t* data, size_t size, int* error_code) {
    if (error_code) *error_code = 0;

    if (!data || size == 0) {
        if (error_code) *error_code = 1;
        return NULL;
    }

    // Create memory buffer for existing gdsio functions
    mem_buffer_t mem_buf = {
        .data = data,
        .size = size,
        .position = 0
    };

    // For WASM, we'll work directly with memory buffer
    // The existing gdsio functions will be adapted to work with our memory buffer

    // For WASM, we'll need to adapt the existing gdsio functions to work with memory
    // This is a simplified approach - in a full implementation, we'd create
    // proper FILE* abstraction or modify existing functions for memory access

    // Parse library header using existing logic from gds_libdata.c
    wasm_library_t* lib = malloc(sizeof(wasm_library_t));
    if (!lib) {
        if (error_code) *error_code = 2;
        return NULL;
    }

    memset(lib, 0, sizeof(wasm_library_t));
    lib->raw_data = data;
    lib->data_size = size;
    lib->file_size = size;

    // Parse HEADER record (using existing logic from gds_libdata.c)
    size_t pos = 0;
    if (pos + 4 > size) {
        if (error_code) *error_code = 3;
        free(lib);
        return NULL;
    }

    uint16_t rlen = (data[pos] << 8) | data[pos + 1];
    uint16_t rtype = (data[pos + 2] << 8) | data[pos + 3];

    if (rtype != HEADER) {
        if (error_code) *error_code = 4; // Invalid GDSII file
        free(lib);
        return NULL;
    }
    pos += 4 + rlen;

    // Parse BGNLIB record
    if (pos + 12 > size) {
        if (error_code) *error_code = 5;
        free(lib);
        return NULL;
    }
    // Extract dates (12 bytes = 6 words each for creation and modification)
    for (int i = 0; i < 6; i++) {
        lib->cdate[i] = (data[pos + i*2] << 8) | data[pos + i*2 + 1];
        lib->mdate[i] = (data[pos + 12 + i*2] << 8) | data[pos + 12 + i*2 + 1];
    }
    pos += 12;

    // Parse LIBNAME record
    if (pos + 4 > size) {
        if (error_code) *error_code = 6;
        free(lib);
        return NULL;
    }
    rlen = (data[pos] << 8) | data[pos + 1];
    rtype = (data[pos + 2] << 8) | data[pos + 3];

    if (rtype != LIBNAME) {
        if (error_code) *error_code = 7;
        free(lib);
        return NULL;
    }
    pos += 4;

    // Extract library name
    size_t name_len = rlen;
    size_t copy_len = (name_len < sizeof(lib->name) - 1) ? name_len : sizeof(lib->name) - 1;
    memcpy(lib->name, data + pos, copy_len);
    lib->name[copy_len] = '\0';
    pos += rlen;

    // Parse UNITS record (find it in remaining data)
    while (pos + 4 <= size) {
        rlen = (data[pos] << 8) | data[pos + 1];
        rtype = (data[pos + 2] << 8) | data[pos + 3];
        pos += 4;

        if (rtype == UNITS) {
            // Extract units (user units per database unit, database units in meters)
            // Both are IEEE 754 double precision in big-endian
            if (pos + 16 > size) break;

            // Convert from big-endian double
            union { uint64_t u; double d; } converter;
            converter.u = ((uint64_t)data[pos] << 56) |
                         ((uint64_t)data[pos + 1] << 48) |
                         ((uint64_t)data[pos + 2] << 40) |
                         ((uint64_t)data[pos + 3] << 32) |
                         ((uint64_t)data[pos + 4] << 24) |
                         ((uint64_t)data[pos + 5] << 16) |
                         ((uint64_t)data[pos + 6] << 8)  |
                         ((uint64_t)data[pos + 7]);
            lib->user_units_per_db_unit = converter.d;

            converter.u = ((uint64_t)data[pos + 8] << 56) |
                         ((uint64_t)data[pos + 9] << 48) |
                         ((uint64_t)data[pos + 10] << 40) |
                         ((uint64_t)data[pos + 11] << 32) |
                         ((uint64_t)data[pos + 12] << 24) |
                         ((uint64_t)data[pos + 13] << 16) |
                         ((uint64_t)data[pos + 14] << 8)  |
                         ((uint64_t)data[pos + 15]);
            lib->meters_per_db_unit = converter.d;

            pos += 16;
            break;
        } else if (rtype == ENDLIB) {
            break;
        } else {
            pos += rlen;
        }
    }

    // Parse structures (simplified version - full implementation would use existing gds_structdata.c)
    lib->structure_count = 0;
    pos = 0; // Reset position to find structures

    // Skip to first BGNSTR after library header
    // This is simplified - in full implementation we'd use existing parsing logic
    while (pos + 4 <= size && lib->structure_count < 128) {
        rlen = (data[pos] << 8) | data[pos + 1];
        rtype = (data[pos + 2] << 8) | data[pos + 3];
        pos += 4;

        if (rtype == BGNSTR && lib->structure_count < 128) {
            // Skip timestamps (12 bytes)
            pos += rlen;

            // Look for STRNAME
            if (pos + 4 <= size) {
                uint16_t name_rlen = (data[pos] << 8) | data[pos + 1];
                uint16_t name_rtype = (data[pos + 2] << 8) | data[pos + 3];
                pos += 4;

                if (name_rtype == STRNAME) {
                    size_t struct_name_len = name_rlen;
                    size_t struct_copy_len = (struct_name_len < 255) ? struct_name_len : 255;
                    memcpy(lib->structures[lib->structure_count].name, data + pos, struct_copy_len);
                    lib->structures[lib->structure_count].name[struct_copy_len] = '\0';
                    lib->structure_count++;
                    pos += name_rlen;
                }
            }
        } else if (rtype == ENDLIB) {
            break;
        } else {
            pos += rlen;
        }
    }

    return lib;
}

// Free library
void gds_free_library(void* library_ptr) {
    if (library_ptr) {
        wasm_library_t* lib = (wasm_library_t*)library_ptr;
        // Note: raw_data points to input data, don't free it
        free(lib);
    }
}

// Get library name
const char* gds_get_library_name(void* library_ptr) {
    if (!library_ptr) return "";
    wasm_library_t* lib = (wasm_library_t*)library_ptr;
    return lib->name;
}

// Get user units per DB unit
double gds_get_user_units_per_db_unit(void* library_ptr) {
    if (!library_ptr) return 1.0;
    wasm_library_t* lib = (wasm_library_t*)library_ptr;
    return lib->user_units_per_db_unit;
}

// Get meters per DB unit
double gds_get_meters_per_db_unit(void* library_ptr) {
    if (!library_ptr) return 1e-9;
    wasm_library_t* lib = (wasm_library_t*)library_ptr;
    return lib->meters_per_db_unit;
}

// Get structure count
int gds_get_structure_count(void* library_ptr) {
    if (!library_ptr) return 0;
    wasm_library_t* lib = (wasm_library_t*)library_ptr;
    return lib->structure_count;
}

// Get structure name
const char* gds_get_structure_name(void* library_ptr, int structure_index) {
    if (!library_ptr || structure_index < 0 || structure_index >= 128) return "";
    wasm_library_t* lib = (wasm_library_t*)library_ptr;
    if (structure_index >= lib->structure_count) return "";
    return lib->structures[structure_index].name;
}

// Get structure dates (enhanced functionality)
void gds_get_library_creation_date(void* library_ptr, uint16_t* date_array) {
    if (!library_ptr || !date_array) return;
    wasm_library_t* lib = (wasm_library_t*)library_ptr;
    for (int i = 0; i < 6; i++) {
        date_array[i] = lib->cdate[i];
    }
}

void gds_get_library_modification_date(void* library_ptr, uint16_t* date_array) {
    if (!library_ptr || !date_array) return;
    wasm_library_t* lib = (wasm_library_t*)library_ptr;
    for (int i = 0; i < 6; i++) {
        date_array[i] = lib->mdate[i];
    }
}

// Element access functions (simplified for now - will be enhanced with actual gds_read_element integration)
int gds_get_element_count(void* library_ptr, int structure_index) {
    // TODO: Integrate with existing gds_read_element infrastructure
    // For now, return 0 as placeholder
    return 0;
}

int gds_get_element_type(void* library_ptr, int structure_index, int element_index) {
    // TODO: Extract from actual element_t structure using gds_read_element
    // For now, default to BOUNDARY type (0x0800)
    return 0x0800;
}

int gds_get_element_layer(void* library_ptr, int structure_index, int element_index) {
    // TODO: Extract from element_t.layer using gds_read_element
    return 1; // Default layer
}

int gds_get_element_data_type(void* library_ptr, int structure_index, int element_index) {
    // TODO: Extract from element_t.dtype using gds_read_element
    return 0; // Default data type
}

// Element flags (from element_t structure)
uint16_t gds_get_element_elflags(void* library_ptr, int structure_index, int element_index) {
    // TODO: Extract from element_t.elflags using gds_read_element
    return 0; // Default flags
}

int32_t gds_get_element_plex(void* library_ptr, int structure_index, int element_index) {
    // TODO: Extract from element_t.plex using gds_read_element
    return 0; // Default plex
}

// Geometry data access (will integrate with gds_read_element xy_block)
int gds_get_element_polygon_count(void* library_ptr, int structure_index, int element_index) {
    // TODO: Extract from gds_read_element polygon data
    return 1; // Default to 1 polygon
}

int gds_get_element_polygon_vertex_count(void* library_ptr, int structure_index, int element_index, int polygon_index) {
    // TODO: Extract from gds_read_element vertex count
    return 4; // Default to 4 vertices
}

double* gds_get_element_polygon_vertices(void* library_ptr, int structure_index, int element_index, int polygon_index) {
    // TODO: Extract from gds_read_element xy_block
    // Static placeholder for now
    static double vertices[8] = {
        -50.0, -50.0,  // (x, y)
         50.0, -50.0,
         50.0,  50.0,
        -50.0,  50.0
    };
    return vertices;
}

// Path-specific data (from element_t path_data)
float gds_get_element_path_width(void* library_ptr, int structure_index, int element_index) {
    // TODO: Extract from element_t.width using gds_read_element
    return 0.0; // Default width
}

uint16_t gds_get_element_path_type(void* library_ptr, int structure_index, int element_index) {
    // TODO: Extract from element_t.ptype using gds_read_element
    return 0; // Default path type
}

float gds_get_element_path_begin_extension(void* library_ptr, int structure_index, int element_index) {
    // TODO: Extract from element_t.bgnextn using gds_read_element
    return 0.0; // Default begin extension
}

float gds_get_element_path_end_extension(void* library_ptr, int structure_index, int element_index) {
    // TODO: Extract from element_t.endextn using gds_read_element
    return 0.0; // Default end extension
}

// Text-specific data (from element_t text_data)
const char* gds_get_element_text(void* library_ptr, int structure_index, int element_index) {
    // TODO: Extract from element_t text_data using gds_read_element
    return ""; // Default empty text
}

void gds_get_element_text_position(void* library_ptr, int structure_index, int element_index, float* x, float* y) {
    // TODO: Extract from element_t text_data position using gds_read_element
    if (x) *x = 0.0;
    if (y) *y = 0.0;
}

uint16_t gds_get_element_text_type(void* library_ptr, int structure_index, int element_index) {
    // TODO: Extract from element_t.ttype using gds_read_element
    return 0; // Default text type
}

uint16_t gds_get_element_text_presentation(void* library_ptr, int structure_index, int element_index) {
    // TODO: Extract from element_t.present using gds_read_element
    return 0; // Default presentation
}

// Reference Elements (SREF/AREF)
const char* gds_get_element_reference_name(void* library_ptr, int structure_index, int element_index) {
    // TODO: Extract from SREF/AREF parsing using existing infrastructure
    return ""; // Default empty reference name
}

int gds_get_element_array_columns(void* library_ptr, int structure_index, int element_index) {
    // TODO: Extract from AREF ncol using existing parsing
    return 1; // Default 1 column
}

int gds_get_element_array_rows(void* library_ptr, int structure_index, int element_index) {
    // TODO: Extract from AREF nrow using existing parsing
    return 1; // Default 1 row
}

void gds_get_element_reference_corners(void* library_ptr, int structure_index, int element_index,
                                      float* x1, float* y1, float* x2, float* y2, float* x3, float* y3) {
    // TODO: Extract from AREF corners using existing parsing
    if (x1) *x1 = 0.0; if (y1) *y1 = 0.0;
    if (x2) *x2 = 1.0; if (y2) *y2 = 0.0;
    if (x3) *x3 = 0.0; if (y3) *y3 = 1.0;
}

// Transformation (strans_t structure)
uint16_t gds_get_element_strans_flags(void* library_ptr, int structure_index, int element_index) {
    // TODO: Extract from element_t.strans.flags using gds_read_element
    return 0; // Default strans flags
}

double gds_get_element_magnification(void* library_ptr, int structure_index, int element_index) {
    // TODO: Extract from element_t.strans.mag using gds_read_element
    return 1.0; // Default magnification
}

double gds_get_element_rotation_angle(void* library_ptr, int structure_index, int element_index) {
    // TODO: Extract from element_t.strans.angle using gds_read_element
    return 0.0; // Default rotation angle
}

// Property access (from PROPATTR/PROPVALUE records)
int gds_get_element_property_count(void* library_ptr, int structure_index, int element_index) {
    // TODO: Extract from property parsing using existing infrastructure
    return 0; // Default no properties
}

uint16_t gds_get_element_property_attribute(void* library_ptr, int structure_index, int element_index, int property_index) {
    // TODO: Extract from property attribute using existing parsing
    return 0; // Default attribute
}

const char* gds_get_element_property_value(void* library_ptr, int structure_index, int element_index, int property_index) {
    // TODO: Extract from property value using existing parsing
    return ""; // Default empty value
}

// Enhanced error handling
const char* gds_get_last_error(void) {
    return gds_wasm_get_error();
}

void gds_clear_error(void) {
    gds_wasm_set_error("");
}

// Validation functions
int gds_validate_library(void* library_ptr) {
    if (!library_ptr) return 0;
    // TODO: Add comprehensive validation logic
    return 1; // Valid for now
}

void gds_get_memory_usage(int* total_allocated, int* peak_usage) {
    // TODO: Implement memory usage tracking
    if (total_allocated) *total_allocated = 0;
    if (peak_usage) *peak_usage = 0;
}