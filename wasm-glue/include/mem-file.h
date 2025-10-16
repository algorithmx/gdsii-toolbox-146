/*
 * Memory File Abstraction for WASM GDSII Parser
 *
 * This module provides a FILE*-like interface for memory-based GDSII parsing,
 * allowing existing gdsio functions to work with WASM memory buffers.
 *
 * Copyright (c) 2025
 */

#ifndef _MEM_FILE_H
#define _MEM_FILE_H

#include <stdio.h>
#include <stdint.h>
#include <stddef.h>
#include <stdint.h>

#ifdef __cplusplus
extern "C" {
#endif

// Memory file handle structure
typedef struct {
    uint8_t* data;        // Pointer to memory buffer
    size_t size;          // Total size of buffer
    size_t position;      // Current read position
    int is_wasm_memory;   // Flag for WASM-specific optimizations

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
mem_file_t* mem_fopen(uint8_t* data, size_t size, const char* mode);

/**
 * Closes a memory file handle
 * @param file Memory file handle
 */
void mem_fclose(mem_file_t* file);

/**
 * Reads data from memory file
 * @param ptr Buffer to store data
 * @param size Size of each element
 * @param count Number of elements
 * @param file Memory file handle
 * @return Number of elements successfully read
 */
size_t mem_fread(void* ptr, size_t size, size_t count, mem_file_t* file);

/**
 * Writes data to memory file
 * @param ptr Buffer containing data
 * @param size Size of each element
 * @param count Number of elements
 * @param file Memory file handle
 * @return Number of elements successfully written
 */
size_t mem_fwrite(const void* ptr, size_t size, size_t count, mem_file_t* file);

/**
 * Seeks to position in memory file
 * @param file Memory file handle
 * @param offset Offset from origin
 * @param whence Seek origin (SEEK_SET, SEEK_CUR, SEEK_END)
 * @return 0 on success, -1 on error
 */
int mem_fseek(mem_file_t* file, long offset, int whence);

/**
 * Gets current position in memory file
 * @param file Memory file handle
 * @return Current position or -1 on error
 */
long mem_ftell(mem_file_t* file);

/**
 * Checks for end of file
 * @param file Memory file handle
 * @return Non-zero if EOF, 0 otherwise
 */
int mem_feof(mem_file_t* file);

/**
 * Checks for file error
 * @param file Memory file handle
 * @return Non-zero if error, 0 otherwise
 */
int mem_ferror(mem_file_t* file);

/**
 * Clears error flags
 * @param file Memory file handle
 */
void mem_clearerr(mem_file_t* file);

/**
 * Flushes any buffered data
 * @param file Memory file handle
 * @return 0 on success
 */
int mem_fflush(mem_file_t* file);

// ============================================================================
// WASM-SPECIFIC CONVENIENCE FUNCTIONS
// ============================================================================

/**
 * Creates a memory file from WASM memory pointer
 * @param data_ptr WASM memory pointer
 * @param size Size in bytes
 * @return mem_file_t* handle or NULL on failure
 */
mem_file_t* wasm_fopen(void* data_ptr, size_t size);

/**
 * Gets remaining bytes to read
 * @param file Memory file handle
 * @return Number of bytes remaining
 */
size_t mem_fremaining(mem_file_t* file);

/**
 * Reads a 16-bit word in big-endian format
 * @param file Memory file handle
 * @param value Pointer to store value
 * @return 1 on success, 0 on failure
 */
int mem_fread_be16(mem_file_t* file, uint16_t* value);

/**
 * Reads a 32-bit word in big-endian format
 * @param file Memory file handle
 * @param value Pointer to store value
 * @return 1 on success, 0 on failure
 */
int mem_fread_be32(mem_file_t* file, uint32_t* value);

/**
 * Reads a 64-bit double in big-endian format
 * @param file Memory file handle
 * @param value Pointer to store value
 * @return 1 on success, 0 on failure
 */
int mem_fread_be64(mem_file_t* file, double* value);

/**
 * Reads a GDSII record header (2-byte length + 2-byte type)
 * @param file Memory file handle
 * @param record_type Pointer to store record type
 * @param record_length Pointer to store record length
 * @return 1 on success, 0 on failure
 */
int mem_fread_gdsii_header(mem_file_t* file, uint16_t* record_type, uint16_t* record_length);

// ============================================================================
// UTILITY FUNCTIONS
// ============================================================================

/**
 * Validates memory file handle
 * @param file Memory file handle
 * @return 1 if valid, 0 if invalid
 */
int mem_fvalidate(mem_file_t* file);

/**
 * Gets memory file statistics
 * @param file Memory file handle
 * @param total_size Pointer to store total size (can be NULL)
 * @param current_pos Pointer to store current position (can be NULL)
 * @param remaining Pointer to store remaining bytes (can be NULL)
 */
void mem_fstats(mem_file_t* file, size_t* total_size, size_t* current_pos, size_t* remaining);

#ifdef __cplusplus
}
#endif

#endif /* _MEM_FILE_H */