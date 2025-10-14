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

// GDSII Record Types (from gdstypes.h)
#define GDS_HEADER      0x0002
#define GDS_BGNLIB      0x0102
#define GDS_LIBNAME     0x0206
#define GDS_UNITS       0x0305
#define GDS_ENDLIB      0x0400
#define GDS_BGNSTR      0x0502
#define GDS_STRNAME     0x1206
#define GDS_ENDSTR      0x0700
#define GDS_BOUNDARY    0x0800
#define GDS_PATH        0x0900
#define GDS_SREF        0x0a00
#define GDS_AREF        0x0b00
#define GDS_TEXT        0x0c00
#define GDS_LAYER       0x0d02
#define GDS_DATATYPE    0x0e02
#define GDS_XY          0x1003
#define GDS_ENDEL       0x1100

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

    if (rtype != GDS_HEADER) {
        gds_wasm_set_error("Invalid GDSII file: missing HEADER record");
        return -1;
    }
    pos += 4 + rlen; // Skip header + data

    // Parse BGNLIB record
    if (read_record_header(pos, &rlen, &rtype) != 0) {
        gds_wasm_set_error("Invalid GDSII file: truncated BGNLIB");
        return -1;
    }

    if (rtype != GDS_BGNLIB) {
        gds_wasm_set_error("Invalid GDSII file: missing BGNLIB record");
        return -1;
    }
    pos += 4 + rlen; // Skip header + data (12 bytes of timestamps)

    // Parse LIBNAME record
    if (read_record_header(pos, &rlen, &rtype) != 0) {
        gds_wasm_set_error("Invalid GDSII file: truncated LIBNAME");
        return -1;
    }

    if (rtype != GDS_LIBNAME) {
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
        if (rtype == GDS_UNITS) {
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
        else if (rtype == GDS_BGNSTR) {
            pos += 4 + rlen; // Skip header + data (timestamps)

            // Look for STRNAME record
            if (pos + 4 <= g_wasm_state.size &&
                read_record_header(pos, &rlen, &rtype) == 0 &&
                rtype == GDS_STRNAME) {

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
        else if (rtype == GDS_ENDLIB) {
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