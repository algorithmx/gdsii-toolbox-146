/*
 * Memory File Abstraction for WASM GDSII Parser
 *
 * Implementation of FILE*-like interface for memory-based GDSII parsing
 *
 * Copyright (c) 2025
 */

#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <stdint.h>
#include <errno.h>
#include "mem-file.h"

// ============================================================================
// CORE MEMORY FILE FUNCTIONS
// ============================================================================

mem_file_t* mem_fopen(uint8_t* data, size_t size, const char* mode) {
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

    return file;
}

void mem_fclose(mem_file_t* file) {
    if (file) {
        free(file);
    }
}

size_t mem_fread(void* ptr, size_t size, size_t count, mem_file_t* file) {
    if (!ptr || !file || size == 0 || count == 0) {
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

size_t mem_fwrite(const void* ptr, size_t size, size_t count, mem_file_t* file) {
    // Write not implemented for WASM (read-only access)
    (void)ptr; (void)size; (void)count; (void)file;
    return 0;
}

int mem_fseek(mem_file_t* file, long offset, int whence) {
    if (!file) {
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

long mem_ftell(mem_file_t* file) {
    if (!file) {
        return -1;
    }
    return (long)file->position;
}

int mem_feof(mem_file_t* file) {
    if (!file) {
        return 1;
    }
    return file->eof_flag || (file->position >= file->size);
}

int mem_ferror(mem_file_t* file) {
    if (!file) {
        return 1;
    }
    return file->error_flag;
}

void mem_clearerr(mem_file_t* file) {
    if (file) {
        file->eof_flag = 0;
        file->error_flag = 0;
    }
}

int mem_fflush(mem_file_t* file) {
    // No buffering to flush in read-only mode
    (void)file;
    return 0;
}

// ============================================================================
// WASM-SPECIFIC CONVENIENCE FUNCTIONS
// ============================================================================

mem_file_t* wasm_fopen(void* data_ptr, size_t size) {
    return mem_fopen((uint8_t*)data_ptr, size, MEM_READ);
}

size_t mem_fremaining(mem_file_t* file) {
    if (!file) {
        return 0;
    }
    return file->size - file->position;
}

int mem_fread_be16(mem_file_t* file, uint16_t* value) {
    if (!file || !value) {
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

int mem_fread_be32(mem_file_t* file, uint32_t* value) {
    if (!file || !value) {
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

int mem_fread_be64(mem_file_t* file, double* value) {
    if (!file || !value) {
        return 0;
    }

    uint8_t bytes[8];
    if (mem_fread(bytes, 1, 8, file) != 8) {
        return 0;
    }

    // Big-endian double conversion
    union {
        uint64_t u;
        double d;
    } converter;

    converter.u = ((uint64_t)bytes[0] << 56) |
                 ((uint64_t)bytes[1] << 48) |
                 ((uint64_t)bytes[2] << 40) |
                 ((uint64_t)bytes[3] << 32) |
                 ((uint64_t)bytes[4] << 24) |
                 ((uint64_t)bytes[5] << 16) |
                 ((uint64_t)bytes[6] << 8)  |
                 ((uint64_t)bytes[7]);

    *value = converter.d;
    return 1;
}

int mem_fread_gdsii_header(mem_file_t* file, uint16_t* record_type, uint16_t* record_length) {
    if (!file || !record_type || !record_length) {
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

int mem_fvalidate(mem_file_t* file) {
    if (!file) {
        return 0;
    }

    return (file->data != NULL &&
            file->size > 0 &&
            file->position <= file->size);
}

void mem_fstats(mem_file_t* file, size_t* total_size, size_t* current_pos, size_t* remaining) {
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
int mem_read_record_hdr(mem_file_t* file, uint16_t* rtype, uint16_t* rlen) {
    if (!mem_fread_gdsii_header(file, rtype, rlen)) {
        return -1; // Error indicator compatible with err_id enum
    }
    return 0; // Success
}

/**
 * Bridge function: read n 16-bit words from memory file
 * Compatible with gdsio.h read_words signature
 */
int mem_read_words(mem_file_t* file, uint16_t* words, int count) {
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
int mem_read_ints(mem_file_t* file, uint32_t* ints, int count) {
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
int mem_read_float(mem_file_t* file, double* value) {
    return mem_fread_be64(file, value) ? 1 : 0;
}