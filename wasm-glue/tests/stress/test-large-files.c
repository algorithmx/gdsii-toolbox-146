/*
 * Large File Handling Tests
 *
 * Tests performance and stability with large GDSII files
 */

#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <stdint.h>
#include <assert.h>
#include <time.h>
#include <sys/time.h>

// Include our headers
#include "../../include/wasm-element-cache.h"
#include "../../include/mem-file.h"

// Test statistics
typedef struct {
    int total_tests;
    int passed_tests;
    int failed_tests;
    double total_time;
} test_stats_t;

static test_stats_t stats = {0, 0, 0, 0.0};

// Timing helper
double get_time_ms(void) {
    struct timeval tv;
    gettimeofday(&tv, NULL);
    return tv.tv_sec * 1000.0 + tv.tv_usec / 1000.0;
}

// Test assertion macros
#define TEST_ASSERT(condition, message) do { \
    stats.total_tests++; \
    if (condition) { \
        stats.passed_tests++; \
        printf("  ✓ %s\n", message); \
    } else { \
        stats.failed_tests++; \
        printf("  ❌ %s\n", message); \
    } \
} while(0)

#define TIMED_TEST(test_func, description) do { \
    printf("Testing %s\n", description); \
    double start_time = get_time_ms(); \
    int result = test_func(); \
    double end_time = get_time_ms(); \
    double elapsed = end_time - start_time; \
    stats.total_time += elapsed; \
    printf("  ⏱  Time: %.2f ms\n", elapsed); \
    if (result == 0) { \
        stats.passed_tests++; \
    } else { \
        stats.failed_tests++; \
    } \
    printf("\n"); \
} while(0)

// GDSII record generators
void write_header(uint8_t** buffer, size_t* offset) {
    uint8_t header[] = {
        0x00, 0x06,  // Length = 6
        0x00, 0x02,  // Type = HEADER
        0x00, 0x03   // Version = 3
    };
    memcpy(*buffer + *offset, header, sizeof(header));
    *offset += sizeof(header);
}

void write_bgnlib(uint8_t** buffer, size_t* offset) {
    uint8_t bgnlib[] = {
        0x00, 0x10,  // Length = 16
        0x01, 0x02,  // Type = BGNLIB
        0x07, 0xE7, 0x07, 0x08, 0x0F, 0x2A,  // Creation date
        0x07, 0xE7, 0x07, 0x08, 0x0F, 0x2B   // Modification date
    };
    memcpy(*buffer + *offset, bgnlib, sizeof(bgnlib));
    *offset += sizeof(bgnlib);
}

void write_libname(uint8_t** buffer, size_t* offset, const char* name) {
    size_t name_len = strlen(name);
    size_t padded_len = ((name_len + 3) / 4) * 4; // Pad to 4-byte boundary

    uint8_t header[] = {
        (padded_len + 4) >> 8, (padded_len + 4) & 0xFF,  // Length
        0x02, 0x06  // Type = LIBNAME
    };
    memcpy(*buffer + *offset, header, sizeof(header));
    *offset += sizeof(header);

    memcpy(*buffer + *offset, name, name_len);
    *offset += name_len;

    // Add padding
    for (size_t i = name_len; i < padded_len; i++) {
        (*buffer)[*offset] = 0x00;
        (*offset)++;
    }
}

void write_units(uint8_t** buffer, size_t* offset) {
    uint8_t units[] = {
        0x00, 0x14,  // Length = 20
        0x03, 0x05,  // Type = UNITS
        // User units per DB unit (1e-6)
        0x3F, 0x1A, 0x36, 0xE2, 0xEB, 0x1C, 0x43, 0x2B,
        // DB units in meters (1e-9)
        0x3E, 0x11, 0xE6, 0xA2, 0x8E, 0xFB, 0x1A, 0x24
    };
    memcpy(*buffer + *offset, units, sizeof(units));
    *offset += sizeof(units);
}

void write_bgnstr(uint8_t** buffer, size_t* offset) {
    uint8_t bgnstr[] = {
        0x00, 0x10,  // Length = 16
        0x05, 0x02,  // Type = BGNSTR
        0x07, 0xE7, 0x07, 0x08, 0x0F, 0x2A,  // Creation date
        0x07, 0xE7, 0x07, 0x08, 0x0F, 0x2A   // Modification date
    };
    memcpy(*buffer + *offset, bgnstr, sizeof(bgnstr));
    *offset += sizeof(bgnstr);
}

void write_strname(uint8_t** buffer, size_t* offset, const char* name) {
    size_t name_len = strlen(name);
    size_t padded_len = ((name_len + 3) / 4) * 4; // Pad to 4-byte boundary

    uint8_t header[] = {
        (padded_len + 4) >> 8, (padded_len + 4) & 0xFF,  // Length
        0x06, 0x06  // Type = STRNAME
    };
    memcpy(*buffer + *offset, header, sizeof(header));
    *offset += sizeof(header);

    memcpy(*buffer + *offset, name, name_len);
    *offset += name_len;

    // Add padding
    for (size_t i = name_len; i < padded_len; i++) {
        (*buffer)[*offset] = 0x00;
        (*offset)++;
    }
}

void write_boundary(uint8_t** buffer, size_t* offset) {
    uint8_t boundary[] = {0x00, 0x04, 0x08, 0x00};
    memcpy(*buffer + *offset, boundary, sizeof(boundary));
    *offset += sizeof(boundary);
}

void write_layer(uint8_t** buffer, size_t* offset, uint16_t layer) {
    uint8_t layer_rec[] = {
        0x00, 0x06,  // Length = 6
        0x0D, 0x02,  // Type = LAYER
        layer >> 8, layer & 0xFF
    };
    memcpy(*buffer + *offset, layer_rec, sizeof(layer_rec));
    *offset += sizeof(layer_rec);
}

void write_datatype(uint8_t** buffer, size_t* offset, uint16_t dtype) {
    uint8_t dtype_rec[] = {
        0x00, 0x06,  // Length = 6
        0x0E, 0x02,  // Type = DATATYPE
        dtype >> 8, dtype & 0xFF
    };
    memcpy(*buffer + *offset, dtype_rec, sizeof(dtype_rec));
    *offset += sizeof(dtype_rec);
}

void write_xy_square(uint8_t** buffer, size_t* offset, int size) {
    uint8_t xy_header[] = {
        0x00, 0x18,  // Length = 24 (4 header + 20 data)
        0x10, 0x03   // Type = XY
    };
    memcpy(*buffer + *offset, xy_header, sizeof(xy_header));
    *offset += sizeof(xy_header);

    // Square vertices: (0,0), (size,0), (size,size), (0,size), (0,0)
    int32_t vertices[] = {
        0, 0,
        size, 0,
        size, size,
        0, size,
        0, 0
    };

    for (int i = 0; i < 10; i++) {
        (*buffer)[*offset] = vertices[i] >> 24;
        (*buffer)[*offset + 1] = vertices[i] >> 16;
        (*buffer)[*offset + 2] = vertices[i] >> 8;
        (*buffer)[*offset + 3] = vertices[i] & 0xFF;
        *offset += 4;
    }
}

void write_endel(uint8_t** buffer, size_t* offset) {
    uint8_t endel[] = {0x00, 0x04, 0x11, 0x00};
    memcpy(*buffer + *offset, endel, sizeof(endel));
    *offset += sizeof(endel);
}

void write_endstr(uint8_t** buffer, size_t* offset) {
    uint8_t endstr[] = {0x00, 0x04, 0x07, 0x00};
    memcpy(*buffer + *offset, endstr, sizeof(endstr));
    *offset += sizeof(endstr);
}

void write_endlib(uint8_t** buffer, size_t* offset) {
    uint8_t endlib[] = {0x00, 0x04, 0x04, 0x00};
    memcpy(*buffer + *offset, endlib, sizeof(endlib));
    *offset += sizeof(endlib);
}

// GDSII file generators
uint8_t* create_large_gds_file(int num_structures, int elements_per_structure, size_t* file_size) {
    // Estimate file size
    size_t estimated_size = 1024; // Base size for header and lib records
    estimated_size += num_structures * (64 + elements_per_structure * 64); // Rough estimate

    uint8_t* buffer = malloc(estimated_size);
    if (!buffer) return NULL;

    size_t offset = 0;

    // Write header
    write_header(&buffer, &offset);
    write_bgnlib(&buffer, &offset);
    write_libname(&buffer, &offset, "LARGE_TEST");
    write_units(&buffer, &offset);

    // Write structures
    for (int i = 0; i < num_structures; i++) {
        char struct_name[32];
        snprintf(struct_name, sizeof(struct_name), "STRUCT_%04d", i + 1);

        write_bgnstr(&buffer, &offset);
        write_strname(&buffer, &offset, struct_name);

        // Write elements
        for (int j = 0; j < elements_per_structure; j++) {
            write_boundary(&buffer, &offset);
            write_layer(&buffer, &offset, (i % 256) + 1);
            write_datatype(&buffer, &offset, 0);
            write_xy_square(&buffer, &offset, 10 + (j % 90));
            write_endel(&buffer, &offset);
        }

        write_endstr(&buffer, &offset);
    }

    write_endlib(&buffer, &offset);

    *file_size = offset;
    return buffer;
}

uint8_t* create_complex_hierarchies(int depth, size_t* file_size) {
    // Create a file with nested structure references
    // This is a simplified version - real hierarchical references would require SREF/AREF records

    size_t estimated_size = 1024 + depth * 512; // Rough estimate
    uint8_t* buffer = malloc(estimated_size);
    if (!buffer) return NULL;

    size_t offset = 0;

    // Write header
    write_header(&buffer, &offset);
    write_bgnlib(&buffer, &offset);
    write_libname(&buffer, &offset, "HIERARCHY_TEST");
    write_units(&buffer, &offset);

    // Create nested structures
    for (int i = 0; i < depth; i++) {
        char struct_name[32];
        snprintf(struct_name, sizeof(struct_name), "LVL_%02d_ROOT", i + 1);

        write_bgnstr(&buffer, &offset);
        write_strname(&buffer, &offset, struct_name);

        // Add increasing number of elements at each level
        for (int j = 0; j < (i + 1) * 5; j++) {
            write_boundary(&buffer, &offset);
            write_layer(&buffer, &offset, (i * 10) + 1);
            write_datatype(&buffer, &offset, 0);
            write_xy_square(&buffer, &offset, 100 + j * 20);
            write_endel(&buffer, &offset);
        }

        write_endstr(&buffer, &offset);
    }

    write_endlib(&buffer, &offset);
    *file_size = offset;
    return buffer;
}

// Test functions
int test_medium_sized_file(void) {
    printf("Testing medium-sized file (100 structures, 10 elements each)\n");

    size_t file_size;
    uint8_t* test_data = create_large_gds_file(100, 10, &file_size);
    TEST_ASSERT(test_data != NULL, "Medium GDSII file created");

    if (!test_data) return -1;

    double start_time = get_time_ms();

    wasm_library_cache_t* cache = wasm_create_library_cache(test_data, file_size);
    TEST_ASSERT(cache != NULL, "Cache created for medium file");

    if (cache) {
        double creation_time = get_time_ms() - start_time;
        printf("    Cache creation: %.2f ms\n", creation_time);

        start_time = get_time_ms();
        int result = wasm_parse_library_structures(cache);
        double parsing_time = get_time_ms() - start_time;
        printf("    Structure parsing: %.2f ms\n", parsing_time);
        TEST_ASSERT(result == 0, "Structure parsing successful");
        TEST_ASSERT(cache->structure_count == 100, "Correct number of structures parsed");

        start_time = get_time_ms();
        int total_elements = 0;
        for (int i = 0; i < cache->structure_count; i++) {
            wasm_parse_structure_elements(cache, i);
            total_elements += cache->structures[i].element_count;
        }
        double element_parsing_time = get_time_ms() - start_time;
        printf("    Element parsing: %.2f ms\n", element_parsing_time);
        TEST_ASSERT(total_elements == 1000, "Correct total element count");

        printf("    Performance: %.2f structures/ms, %.2f elements/ms\n",
               cache->structure_count / parsing_time,
               total_elements / element_parsing_time);

        wasm_free_library_cache(cache);
    }

    free(test_data);
    return 0;
}

int test_large_file_performance(void) {
    printf("Testing large file performance (1000 structures, 100 elements each)\n");

    size_t file_size;
    uint8_t* test_data = create_large_gds_file(1000, 100, &file_size);
    TEST_ASSERT(test_data != NULL, "Large GDSII file created");

    if (!test_data) return -1;

    printf("    File size: %.2f KB\n", file_size / 1024.0);

    double start_time = get_time_ms();

    wasm_library_cache_t* cache = wasm_create_library_cache(test_data, file_size);
    TEST_ASSERT(cache != NULL, "Cache created for large file");

    if (cache) {
        double creation_time = get_time_ms() - start_time;
        printf("    Cache creation: %.2f ms\n", creation_time);

        start_time = get_time_ms();
        int result = wasm_parse_library_structures(cache);
        double parsing_time = get_time_ms() - start_time;
        printf("    Structure parsing: %.2f ms\n", parsing_time);
        TEST_ASSERT(result == 0, "Structure parsing successful");
        TEST_ASSERT(cache->structure_count == 1000, "Correct number of structures parsed");

        // Parse every 10th structure to test selective loading
        start_time = get_time_ms();
        int selective_elements = 0;
        for (int i = 0; i < cache->structure_count; i += 10) {
            wasm_parse_structure_elements(cache, i);
            selective_elements += cache->structures[i].element_count;
        }
        double selective_parsing_time = get_time_ms() - start_time;
        printf("    Selective element parsing (1/10): %.2f ms\n", selective_parsing_time);
        TEST_ASSERT(selective_elements == 10000, "Selective element count correct");

        // Test memory usage estimation
        printf("    Estimated memory usage: ~%.1f KB (structures)\n",
               cache->structure_count * sizeof(wasm_structure_cache_t) / 1024.0);

        wasm_free_library_cache(cache);
    }

    free(test_data);
    return 0;
}

int test_very_large_file(void) {
    printf("Testing very large file (5000 structures, 50 elements each)\n");

    size_t file_size;
    uint8_t* test_data = create_large_gds_file(5000, 50, &file_size);
    TEST_ASSERT(test_data != NULL, "Very large GDSII file created");

    if (!test_data) return -1;

    printf("    File size: %.2f MB\n", file_size / (1024.0 * 1024.0));

    double start_time = get_time_ms();

    wasm_library_cache_t* cache = wasm_create_library_cache(test_data, file_size);
    TEST_ASSERT(cache != NULL, "Cache created for very large file");

    if (cache) {
        double creation_time = get_time_ms() - start_time;
        printf("    Cache creation: %.2f ms\n", creation_time);

        start_time = get_time_ms();
        int result = wasm_parse_library_structures(cache);
        double parsing_time = get_time_ms() - start_time;
        printf("    Structure parsing: %.2f ms\n", parsing_time);
        TEST_ASSERT(result == 0, "Structure parsing successful");
        TEST_ASSERT(cache->structure_count == 5000, "Correct number of structures parsed");

        printf("    Performance: %.2f structures/ms\n", cache->structure_count / parsing_time);

        // Test accessing specific structures in large file
        start_time = get_time_ms();
        int mid_structure = cache->structure_count / 2;
        int result2 = wasm_parse_structure_elements(cache, mid_structure);
        double access_time = get_time_ms() - start_time;
        printf("    Access middle structure (#%d): %.2f ms\n", mid_structure, access_time);
        TEST_ASSERT(result2 == 0, "Middle structure access successful");

        if (cache->structures[mid_structure].element_count > 0) {
            int element_count = wasm_get_element_count(cache, mid_structure);
            TEST_ASSERT(element_count > 0, "Element count accessible");
        }

        wasm_free_library_cache(cache);
    }

    free(test_data);
    return 0;
}

int test_complex_hierarchy(void) {
    printf("Testing complex hierarchy (10 levels deep)\n");

    size_t file_size;
    uint8_t* test_data = create_complex_hierarchies(10, &file_size);
    TEST_ASSERT(test_data != NULL, "Complex hierarchy file created");

    if (!test_data) return -1;

    double start_time = get_time_ms();

    wasm_library_cache_t* cache = wasm_create_library_cache(test_data, file_size);
    TEST_ASSERT(cache != NULL, "Cache created for complex hierarchy");

    if (cache) {
        double creation_time = get_time_ms() - start_time;
        printf("    Cache creation: %.2f ms\n", creation_time);

        start_time = get_time_ms();
        int result = wasm_parse_library_structures(cache);
        double parsing_time = get_time_ms() - start_time;
        printf("    Structure parsing: %.2f ms\n", parsing_time);
        TEST_ASSERT(result == 0, "Structure parsing successful");
        TEST_ASSERT(cache->structure_count == 10, "Correct hierarchy depth");

        // Test accessing structures at different levels
        for (int i = 0; i < cache->structure_count; i++) {
            result = wasm_parse_structure_elements(cache, i);
            TEST_ASSERT(result == 0, "Structure access successful");

            int element_count = cache->structures[i].element_count;
            int expected_elements = (i + 1) * 5;
            TEST_ASSERT(element_count == expected_elements,
                       "Element count correct for hierarchy level");
        }

        wasm_free_library_cache(cache);
    }

    free(test_data);
    return 0;
}

int test_memory_efficiency(void) {
    printf("Testing memory efficiency with multiple operations\n");

    size_t file_size;
    uint8_t* test_data = create_large_gds_file(100, 20, &file_size);
    TEST_ASSERT(test_data != NULL, "Test file created");

    if (!test_data) return -1;

    // Test memory usage over multiple operations
    wasm_library_cache_t* caches[10];

    double start_time = get_time_ms();

    // Create multiple caches
    for (int i = 0; i < 10; i++) {
        caches[i] = wasm_create_library_cache(test_data, file_size);
        TEST_ASSERT(caches[i] != NULL, "Cache created successfully");
    }
    double creation_time = get_time_ms() - start_time;
    printf("    10 cache creations: %.2f ms\n", creation_time);

    // Parse all structures in all caches
    start_time = get_time_ms();
    for (int i = 0; i < 10; i++) {
        int result = wasm_parse_library_structures(caches[i]);
        TEST_ASSERT(result == 0, "Structure parsing successful");
    }
    double parsing_time = get_time_ms() - start_time;
    printf("    10 cache structure parsing: %.2f ms\n", parsing_time);

    // Free all caches
    start_time = get_time_ms();
    for (int i = 0; i < 10; i++) {
        wasm_free_library_cache(caches[i]);
    }
    double free_time = get_time_ms() - start_time;
    printf("    10 cache frees: %.2f ms\n", free_time);

    free(test_data);
    return 0;
}

int test_repeated_operations(void) {
    printf("Testing repeated operations (stress test)\n");

    size_t file_size;
    uint8_t* test_data = create_large_gds_file(50, 10, &file_size);
    TEST_ASSERT(test_data != NULL, "Test file created");

    if (!test_data) return -1;

    // Perform many create/parse/free cycles
    const int cycles = 100;
    double total_time = 0;
    int successful_cycles = 0;

    for (int i = 0; i < cycles; i++) {
        double start_time = get_time_ms();

        wasm_library_cache_t* cache = wasm_create_library_cache(test_data, file_size);
        if (cache) {
            int result1 = wasm_parse_library_structures(cache);
            if (result1 == 0) {
                // Parse some elements
                for (int j = 0; j < 5 && j < cache->structure_count; j++) {
                    wasm_parse_structure_elements(cache, j);
                }
                successful_cycles++;
            }
            wasm_free_library_cache(cache);
        }

        total_time += get_time_ms() - start_time;
    }

    printf("    %d cycles completed\n", successful_cycles);
    printf("    Average time per cycle: %.2f ms\n", total_time / successful_cycles);
    printf("    Success rate: %.1f%%\n", (double)successful_cycles / cycles * 100.0);
    TEST_ASSERT(successful_cycles == cycles, "All cycles completed successfully");

    free(test_data);
    return 0;
}

// Test runner
void run_all_tests(void) {
    printf("=== Large File Handling Tests ===\n\n");

    TIMED_TEST(test_medium_sized_file, "Medium file handling");
    TIMED_TEST(test_large_file_performance, "Large file performance");
    TIMED_TEST(test_very_large_file, "Very large file handling");
    TIMED_TEST(test_complex_hierarchy, "Complex hierarchy processing");
    TIMED_TEST(test_memory_efficiency, "Memory efficiency");
    TIMED_TEST(test_repeated_operations, "Repeated operations");
}

void print_test_summary(void) {
    printf("=== Test Summary ===\n");
    printf("Total tests: %d\n", stats.total_tests);
    printf("Passed: %d\n", stats.passed_tests);
    printf("Failed: %d\n", stats.failed_tests);

    if (stats.failed_tests == 0) {
        printf("🎉 All stress tests passed!\n");
    } else {
        printf("❌ Some stress tests failed. Please review.\n");
    }

    printf("Total test time: %.2f ms\n", stats.total_time);
    printf("Average test time: %.2f ms\n", stats.total_time / stats.total_tests);
}

int main(void) {
    run_all_tests();
    print_test_summary();

    return (stats.failed_tests == 0) ? 0 : 1;
}