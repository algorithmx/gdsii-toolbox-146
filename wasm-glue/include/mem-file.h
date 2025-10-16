/*
 * Memory File Abstraction for WASM GDSII Parser - Header Only Implementation
 *
 * This module provides a FILE*-like interface for memory-based GDSII parsing,
 * allowing existing gdsio functions to work with WASM memory buffers.
 * All functions are implemented inline for header-only usage.
 *
 * Copyright (c) 2025
 */

#ifndef _MEM_FILE_H
#define _MEM_FILE_H

#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <stdint.h>
#include <stddef.h>
#include <errno.h>
#include <math.h>

// Define INLINE for compatibility
#ifndef INLINE
#if defined __GNUC__ || defined __EMSCRIPTEN__
#define INLINE __inline__
#else
#define INLINE
#endif
#endif

#ifdef __EMSCRIPTEN__
#include "convert_float_generic.h"
#else
#include "convert_float_gcc.h"
#endif

#ifdef __cplusplus
extern "C" {
#endif

// Memory file handle structure
typedef struct {
    uint8_t* data;        // Pointer to memory buffer
    size_t size;          // Total size of buffer
    size_t position;      // Current read position
    int is_wasm_memory;   // Flag for WASM-specific optimizations
    int is_closed;        // Flag indicating file has been closed

    // Error tracking
    int eof_flag;         // End of file flag
    int error_flag;       // Error flag

    // Buffering for performance
    uint8_t buffer[1024]; // Small read buffer
    size_t buffer_pos;    // Current position in buffer
    size_t buffer_valid;  // Valid bytes in buffer
} mem_file_t;

// File opening modes (compatible with stdio)
#define MEM_READ "rb"
#define MEM_WRITE "wb"
#define MEM_READ_WRITE "r+b"

// ============================================================================
// MEMORY FILE API (FILE* compatible)
// ============================================================================

/**
 * Opens a memory buffer as a file handle
 * @param data Pointer to memory buffer
 * @param size Size of memory buffer
 * @param mode Open mode (use MEM_READ, MEM_WRITE, etc.)
 * @return mem_file_t* handle or NULL on failure
 */
static inline mem_file_t* mem_fopen(uint8_t* data, size_t size, const char* mode) {
    if (!data || size == 0 || !mode) {
        return NULL;
    }

    // Only support read mode for now (existing GDSII parser only reads)
    if (strcmp(mode, MEM_READ) != 0 && strcmp(mode, "r") != 0) {
        return NULL;
    }

    mem_file_t* file = malloc(sizeof(mem_file_t));
    if (!file) {
        return NULL;
    }

    // Initialize file structure
    file->data = data;
    file->size = size;
    file->position = 0;
    file->is_wasm_memory = 1;
    file->eof_flag = 0;
    file->error_flag = 0;
    file->buffer_pos = 0;
    file->buffer_valid = 0;
    file->is_closed = 0;

    return file;
}

/**
 * Closes a memory file handle
 * @param file Memory file handle
 */
static inline void mem_fclose(mem_file_t* file) {
    if (file) {
        // Do not free underlying data; mark as closed to test behavior
        file->is_closed = 1;
    }
}

/**
 * Reads data from memory file
 * @param ptr Buffer to store data
 * @param size Size of each element
 * @param count Number of elements
 * @param file Memory file handle
 * @return Number of elements successfully read
 */
static inline size_t mem_fread(void* ptr, size_t size, size_t count, mem_file_t* file) {
    if (!ptr || !file || size == 0 || count == 0 || file->is_closed) {
        return 0;
    }

    size_t total_bytes = size * count;
    size_t available = file->size - file->position;

    if (available == 0) {
        file->eof_flag = 1;
        return 0;
    }

    size_t bytes_to_read = (total_bytes < available) ? total_bytes : available;

    memcpy(ptr, file->data + file->position, bytes_to_read);
    file->position += bytes_to_read;

    if (bytes_to_read < total_bytes) {
        file->eof_flag = 1;
    }

    return bytes_to_read / size;
}

/**
 * Writes data to memory file
 * @param ptr Buffer containing data
 * @param size Size of each element
 * @param count Number of elements
 * @param file Memory file handle
 * @return Number of elements successfully written
 */
static inline size_t mem_fwrite(const void* ptr, size_t size, size_t count, mem_file_t* file) {
    // Write not implemented for WASM (read-only access)
    (void)ptr; (void)size; (void)count; (void)file;
    return 0;
}

/**
 * Seeks to position in memory file
 * @param file Memory file handle
 * @param offset Offset from origin
 * @param whence Seek origin (SEEK_SET, SEEK_CUR, SEEK_END)
 * @return 0 on success, -1 on error
 */
static inline int mem_fseek(mem_file_t* file, long offset, int whence) {
    if (!file || file->is_closed) {
        return -1;
    }

    long new_position;

    switch (whence) {
        case SEEK_SET:
            new_position = offset;
            break;
        case SEEK_CUR:
            new_position = (long)file->position + offset;
            break;
        case SEEK_END:
            new_position = (long)file->size + offset;
            break;
        default:
            return -1;
    }

    if (new_position < 0 || new_position > (long)file->size) {
        file->error_flag = 1;
        return -1;
    }

    file->position = (size_t)new_position;
    file->eof_flag = 0;
    return 0;
}

/**
 * Gets current position in memory file
 * @param file Memory file handle
 * @return Current position or -1 on error
 */
static inline long mem_ftell(mem_file_t* file) {
    if (!file || file->is_closed) {
        return -1;
    }
    return (long)file->position;
}

/**
 * Checks for end of file
 * @param file Memory file handle
 * @return Non-zero if EOF, 0 otherwise
 */
static inline int mem_feof(mem_file_t* file) {
    if (!file || file->is_closed) {
        return 1;
    }
    return file->eof_flag || (file->position >= file->size);
}

/**
 * Checks for file error
 * @param file Memory file handle
 * @return Non-zero if error, 0 otherwise
 */
static inline int mem_ferror(mem_file_t* file) {
    if (!file || file->is_closed) {
        return 1;
    }
    return file->error_flag;
}

/**
 * Clears error flags
 * @param file Memory file handle
 */
static inline void mem_clearerr(mem_file_t* file) {
    if (file && !file->is_closed) {
        file->eof_flag = 0;
        file->error_flag = 0;
    }
}

/**
 * Flushes any buffered data
 * @param file Memory file handle
 * @return 0 on success
 */
static inline int mem_fflush(mem_file_t* file) {
    // No buffering to flush in read-only mode
    (void)file;
    return 0;
}

// ============================================================================
// WASM-SPECIFIC CONVENIENCE FUNCTIONS
// ============================================================================

/**
 * Creates a memory file from WASM memory pointer
 * @param data_ptr WASM memory pointer
 * @param size Size in bytes
 * @return mem_file_t* handle or NULL on failure
 */
static inline mem_file_t* wasm_fopen(void* data_ptr, size_t size) {
    return mem_fopen((uint8_t*)data_ptr, size, MEM_READ);
}

/**
 * Gets remaining bytes to read
 * @param file Memory file handle
 * @return Number of bytes remaining
 */
static inline size_t mem_fremaining(mem_file_t* file) {
    if (!file) {
        return 0;
    }
    return file->size - file->position;
}

/**
 * Reads a 16-bit word in big-endian format
 * @param file Memory file handle
 * @param value Pointer to store value
 * @return 1 on success, 0 on failure
 */
static inline int mem_fread_be16(mem_file_t* file, uint16_t* value) {
    if (!file || !value || file->is_closed) {
        return 0;
    }

    uint8_t bytes[2];
    if (mem_fread(bytes, 1, 2, file) != 2) {
        return 0;
    }

    // Big-endian conversion
    *value = (uint16_t)bytes[0] << 8 | (uint16_t)bytes[1];
    return 1;
}

/**
 * Reads a 32-bit word in big-endian format
 * @param file Memory file handle
 * @param value Pointer to store value
 * @return 1 on success, 0 on failure
 */
static inline int mem_fread_be32(mem_file_t* file, uint32_t* value) {
    if (!file || !value || file->is_closed) {
        return 0;
    }

    uint8_t bytes[4];
    if (mem_fread(bytes, 1, 4, file) != 4) {
        return 0;
    }

    // Big-endian conversion
    *value = ((uint32_t)bytes[0] << 24) |
             ((uint32_t)bytes[1] << 16) |
             ((uint32_t)bytes[2] << 8)  |
             ((uint32_t)bytes[3]);
    return 1;
}

/**
 * Reads a 64-bit double in big-endian format
 * @param file Memory file handle
 * @param value Pointer to store value
 * @return 1 on success, 0 on failure
 */
static inline int mem_fread_be64(mem_file_t* file, double* value) {
    if (!file || !value || file->is_closed) {
        return 0;
    }

    uint8_t be[8];
    if (mem_fread(be, 1, 8, file) != 8) {
        return 0;
    }

    // Reuse existing conversion from Basic/gdsio: Excess-64 -> IEEE754
    uint64_t u = 0;
    memcpy(&u, be, 8); // Preserve byte order in memory for converter
    *value = excess64_to_ieee754(&u);
    return 1;
}

/**
 * Reads a GDSII record header (2-byte length + 2-byte type)
 * @param file Memory file handle
 * @param record_type Pointer to store record type
 * @param record_length Pointer to store record length
 * @return 1 on success, 0 on failure
 */
static inline int mem_fread_gdsii_header(mem_file_t* file, uint16_t* record_type, uint16_t* record_length) {
    if (!file || !record_type || !record_length || file->is_closed) {
        return 0;
    }

    // GDSII header format: 2-byte length + 2-byte type (both big-endian)
    uint16_t total_length;
    if (!mem_fread_be16(file, &total_length)) {
        return 0;
    }

    if (!mem_fread_be16(file, record_type)) {
        return 0;
    }

    // Convert total record length to data length (subtract 4 bytes for header)
    *record_length = total_length - 4;

    return 1;
}

// ============================================================================
// UTILITY FUNCTIONS
// ============================================================================

/**
 * Validates memory file handle
 * @param file Memory file handle
 * @return 1 if valid, 0 if invalid
 */
static inline int mem_fvalidate(mem_file_t* file) {
    if (!file) {
        return 0;
    }

    return (file->data != NULL &&
            file->size > 0 &&
            file->position <= file->size);
}

/**
 * Gets memory file statistics
 * @param file Memory file handle
 * @param total_size Pointer to store total size (can be NULL)
 * @param current_pos Pointer to store current position (can be NULL)
 * @param remaining Pointer to store remaining bytes (can be NULL)
 */
static inline void mem_fstats(mem_file_t* file, size_t* total_size, size_t* current_pos, size_t* remaining) {
    if (!file) {
        if (total_size) *total_size = 0;
        if (current_pos) *current_pos = 0;
        if (remaining) *remaining = 0;
        return;
    }

    if (total_size) *total_size = file->size;
    if (current_pos) *current_pos = file->position;
    if (remaining) *remaining = file->size - file->position;
}

// ============================================================================
// BRIDGE FUNCTIONS FOR EXISTING GDSIO CODE
// ============================================================================

// These functions provide compatibility with existing gdsio functions
// that expect FILE* handles. They can be used as drop-in replacements.

/**
 * Bridge function: read_record_hdr equivalent for memory files
 * Compatible with gdsio.h read_record_hdr signature
 */
static inline int mem_read_record_hdr(mem_file_t* file, uint16_t* rtype, uint16_t* rlen) {
    if (!mem_fread_gdsii_header(file, rtype, rlen)) {
        return -1; // Error indicator compatible with err_id enum
    }
    return 0; // Success
}

/**
 * Bridge function: read n 16-bit words from memory file
 * Compatible with gdsio.h read_words signature
 */
static inline int mem_read_words(mem_file_t* file, uint16_t* words, int count) {
    if (!file || !words || count <= 0) {
        return -1;
    }

    for (int i = 0; i < count; i++) {
        if (!mem_fread_be16(file, &words[i])) {
            return i; // Return number of words successfully read
        }
    }

    return count;
}

/**
 * Bridge function: read n 32-bit words from memory file
 * Compatible with gdsio.h read_ints signature
 */
static inline int mem_read_ints(mem_file_t* file, uint32_t* ints, int count) {
    if (!file || !ints || count <= 0) {
        return -1;
    }

    for (int i = 0; i < count; i++) {
        if (!mem_fread_be32(file, &ints[i])) {
            return i; // Return number of ints successfully read
        }
    }

    return count;
}

/**
 * Bridge function: read IEEE 754 double from memory file
 * Compatible with gdsio.h read_float signature
 */
static inline int mem_read_float(mem_file_t* file, double* value) {
    return mem_fread_be64(file, value) ? 1 : 0;
}

#ifdef __cplusplus
}
#endif

#endif /* _MEM_FILE_H */