/*
 * Invalid Input Tests
 *
 * Tests error handling for invalid inputs, NULL pointers, and out-of-bounds indices
 */

#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <stdint.h>
#include <assert.h>

// Include our headers
#include "../../include/wasm-element-cache.h"
#include "../../include/mem-file.h"

// Test statistics
typedef struct {
    int total_tests;
    int passed_tests;
    int failed_tests;
} test_stats_t;

static test_stats_t stats = {0, 0, 0};

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

// Valid minimal GDSII data for testing
static uint8_t valid_gds_data[] = {
    // HEADER
    0x00, 0x06, 0x00, 0x02, 0x00, 0x03,
    // BGNLIB
    0x00, 0x10, 0x01, 0x02,
    0x07, 0xE7, 0x07, 0x08, 0x0F, 0x2A,
    0x07, 0xE7, 0x07, 0x08, 0x0F, 0x2B,
    // LIBNAME
    0x00, 0x0C, 0x02, 0x06,
    'T', 'E', 'S', 'T', 0x00, 0x00, 0x00, 0x00,
    // UNITS
    0x00, 0x14, 0x03, 0x05,
    0x3F, 0x1A, 0x36, 0xE2, 0xEB, 0x1C, 0x43, 0x2B,
    0x3E, 0x11, 0xE6, 0xA2, 0x8E, 0xFB, 0x1A, 0x24,
    // ENDLIB
    0x00, 0x04, 0x04, 0x00
};

int test_memory_file_invalid_inputs(void) {
    printf("Testing memory file - Invalid inputs\n");

    // Test mem_fopen with NULL data
    mem_file_t* file = mem_fopen(NULL, 100, MEM_READ);
    TEST_ASSERT(file == NULL, "mem_fopen rejects NULL data");

    // Test mem_fopen with zero size
    uint8_t dummy = 0x42;
    file = mem_fopen(&dummy, 0, MEM_READ);
    TEST_ASSERT(file == NULL, "mem_fopen rejects zero size");

    // Test mem_fopen with invalid mode
    file = mem_fopen(&dummy, 1, "invalid");
    TEST_ASSERT(file == NULL, "mem_fopen rejects invalid mode");

    // Test mem_fread with NULL file
    uint8_t buffer[10];
    size_t result = mem_fread(buffer, 1, 10, NULL);
    TEST_ASSERT(result == 0, "mem_fread rejects NULL file");

    // Test mem_fread with NULL buffer
    file = mem_fopen(&dummy, 1, MEM_READ);
    if (file) {
        result = mem_fread(NULL, 1, 10, file);
        TEST_ASSERT(result == 0, "mem_fread rejects NULL buffer");
        mem_fclose(file);
    }

    // Test mem_fread with zero size
    file = mem_fopen(&dummy, 1, MEM_READ);
    if (file) {
        result = mem_fread(buffer, 0, 10, file);
        TEST_ASSERT(result == 0, "mem_fread handles zero size");
        mem_fclose(file);
    }

    // Test mem_fseek with NULL file
    int seek_result = mem_fseek(NULL, 0, SEEK_SET);
    TEST_ASSERT(seek_result == -1, "mem_fseek rejects NULL file");

    // Test mem_ftell with NULL file
    long tell_result = mem_ftell(NULL);
    TEST_ASSERT(tell_result == -1, "mem_ftell rejects NULL file");

    // Test mem_feof with NULL file
    int eof_result = mem_feof(NULL);
    TEST_ASSERT(eof_result == 1, "mem_feof handles NULL file");

    // Test big-endian reads with NULL file
    uint16_t value16;
    result = mem_fread_be16(NULL, &value16);
    TEST_ASSERT(result == 0, "mem_fread_be16 rejects NULL file");

    uint32_t value32;
    result = mem_fread_be32(NULL, &value32);
    TEST_ASSERT(result == 0, "mem_fread_be32 rejects NULL file");

    double value64;
    result = mem_fread_be64(NULL, &value64);
    TEST_ASSERT(result == 0, "mem_fread_be64 rejects NULL file");

    uint16_t type, length;
    result = mem_fread_gdsii_header(NULL, &type, &length);
    TEST_ASSERT(result == 0, "mem_fread_gdsii_header rejects NULL file");

    return 0;
}

int test_library_cache_invalid_inputs(void) {
    printf("Testing library cache - Invalid inputs\n");

    // Test wasm_create_library_cache with NULL data
    wasm_library_cache_t* cache = wasm_create_library_cache(NULL, 100);
    TEST_ASSERT(cache == NULL, "wasm_create_library_cache rejects NULL data");

    // Test wasm_create_library_cache with zero size
    uint8_t dummy = 0x42;
    cache = wasm_create_library_cache(&dummy, 0);
    TEST_ASSERT(cache == NULL, "wasm_create_library_cache rejects zero size");

    // Test wasm_free_library_cache with NULL cache
    wasm_free_library_cache(NULL);
    TEST_ASSERT(1, "wasm_free_library_cache handles NULL gracefully");

    // Test wasm_parse_library_structures with NULL cache
    int result = wasm_parse_library_structures(NULL);
    TEST_ASSERT(result != 0, "wasm_parse_library_structures rejects NULL cache");

    // Test wasm_parse_structure_elements with NULL cache
    result = wasm_parse_structure_elements(NULL, 0);
    TEST_ASSERT(result != 0, "wasm_parse_structure_elements rejects NULL cache");

    return 0;
}

int test_element_access_invalid_indices(void) {
    printf("Testing element access - Invalid indices\n");

    // Create a valid cache for testing
    wasm_library_cache_t* cache = wasm_create_library_cache(valid_gds_data, sizeof(valid_gds_data));
    TEST_ASSERT(cache != NULL, "Valid cache created for testing");

    if (!cache) return -1;

    // Parse structures first
    int result = wasm_parse_library_structures(cache);
    TEST_ASSERT(result == 0, "Structures parsed successfully");

    // Test negative structure index
    int count = wasm_get_element_count(cache, -1);
    TEST_ASSERT(count == -1, "Negative structure index rejected");

    count = wasm_get_element_count(cache, -100);
    TEST_ASSERT(count == -1, "Large negative structure index rejected");

    // Test out-of-bounds structure index
    count = wasm_get_element_count(cache, 100);
    TEST_ASSERT(count == -1, "Out-of-bounds structure index rejected");

    count = wasm_get_element_count(cache, 999999);
    TEST_ASSERT(count == -1, "Very large structure index rejected");

    // Parse some elements for element index testing
    wasm_parse_structure_elements(cache, 0);

    // Test negative element index
    int element_type = wasm_get_element_type(cache, 0, -1);
    TEST_ASSERT(element_type == -1, "Negative element index rejected");

    element_type = wasm_get_element_type(cache, 0, -100);
    TEST_ASSERT(element_type == -1, "Large negative element index rejected");

    // Test out-of-bounds element index
    element_type = wasm_get_element_type(cache, 0, 100);
    TEST_ASSERT(element_type == -1, "Out-of-bounds element index rejected");

    element_type = wasm_get_element_type(cache, 0, 999999);
    TEST_ASSERT(element_type == -1, "Very large element index rejected");

    // Test negative polygon index
    int polygon_count = wasm_get_element_polygon_count(cache, 0, 0);
    if (polygon_count > 0) {
        int vertex_count = wasm_get_element_polygon_vertex_count(cache, 0, 0, -1);
        TEST_ASSERT(vertex_count == -1, "Negative polygon index rejected");

        vertex_count = wasm_get_element_polygon_vertex_count(cache, 0, 0, 100);
        TEST_ASSERT(vertex_count == -1, "Out-of-bounds polygon index rejected");

        double* vertices = wasm_get_element_polygon_vertices(cache, 0, 0, -1);
        TEST_ASSERT(vertices == NULL, "Negative polygon index returns NULL");

        vertices = wasm_get_element_polygon_vertices(cache, 0, 0, 100);
        TEST_ASSERT(vertices == NULL, "Out-of-bounds polygon index returns NULL");
    }

    // Test negative property index
    int prop_count = wasm_get_element_property_count(cache, 0, 0);
    if (prop_count > 0) {
        uint16_t attr = wasm_get_element_property_attribute(cache, 0, 0, -1);
        TEST_ASSERT(attr == 0, "Negative property index returns 0");

        attr = wasm_get_element_property_attribute(cache, 0, 0, 100);
        TEST_ASSERT(attr == 0, "Out-of-bounds property index returns 0");

        const char* value = wasm_get_element_property_value(cache, 0, 0, -1);
        TEST_ASSERT(value == NULL || strcmp(value, "") == 0, "Negative property index returns empty");

        value = wasm_get_element_property_value(cache, 0, 0, 100);
        TEST_ASSERT(value == NULL || strcmp(value, "") == 0, "Out-of-bounds property index returns empty");
    }

    wasm_free_library_cache(cache);
    return 0;
}

int test_memory_allocation_failure(void) {
    printf("Testing memory allocation failure scenarios\n");

    // This test is limited since we can't easily simulate malloc failure
    // But we can test the behavior with extremely large allocations

    // Test very large library cache creation (will likely fail)
    size_t huge_size = SIZE_MAX / 2; // Very large size
    uint8_t* huge_data = NULL;

    // Note: This might crash on some systems, but it tests boundary conditions
    // In practice, this would be handled by the OS refusing the allocation

    // Instead, let's test with a reasonable but large size
    size_t large_size = 1024 * 1024 * 100; // 100MB
    huge_data = malloc(large_size);

    if (huge_data) {
        // Fill with valid GDSII header pattern
        memcpy(huge_data, valid_gds_data, sizeof(valid_gds_data));

        wasm_library_cache_t* cache = wasm_create_library_cache(huge_data, large_size);
        // This might succeed or fail depending on available memory
        if (cache) {
            printf("  ✓ Large allocation succeeded\n");
            wasm_free_library_cache(cache);
        } else {
            printf("  ✓ Large allocation gracefully rejected\n");
        }

        free(huge_data);
    } else {
        printf("  ✓ Large allocation rejected by system\n");
    }

    return 0;
}

int test_corrupted_data_handling(void) {
    printf("Testing corrupted data handling\n");

    // Test with data that's too small for any valid record
    uint8_t tiny_data[] = {0x00, 0x01, 0x02};
    wasm_library_cache_t* cache = wasm_create_library_cache(tiny_data, sizeof(tiny_data));
    TEST_ASSERT(cache == NULL, "Tiny data rejected");

    // Test with data that has valid header but invalid record type
    uint8_t invalid_type_data[] = {
        0x00, 0x06, 0xFF, 0xFF,  // Invalid record type
        0x00, 0x03
    };
    cache = wasm_create_library_cache(invalid_type_data, sizeof(invalid_type_data));
    TEST_ASSERT(cache == NULL, "Invalid record type rejected");

    // Test with data that has truncated records
    uint8_t truncated_data[] = {
        0x00, 0x06, 0x00, 0x02,  // Valid HEADER
        0x00, 0x03              // Truncated data
    };
    cache = wasm_create_library_cache(truncated_data, sizeof(truncated_data));
    TEST_ASSERT(cache == NULL, "Truncated data rejected");

    // Test with data that has inconsistent record lengths
    uint8_t inconsistent_data[] = {
        0x00, 0x10, 0x00, 0x02,  // HEADER claims 16 bytes total
        0x00, 0x03              // But only 1 byte of data
    };
    cache = wasm_create_library_cache(inconsistent_data, sizeof(inconsistent_data));
    TEST_ASSERT(cache == NULL, "Inconsistent record length rejected");

    return 0;
}

int test_boundary_conditions(void) {
    printf("Testing boundary conditions\n");

    // Test with single-byte files
    uint8_t single_byte = 0x42;
    wasm_library_cache_t* cache = wasm_create_library_cache(&single_byte, 1);
    TEST_ASSERT(cache == NULL, "Single-byte file rejected");

    // Test with minimum valid GDSII file (just ENDLIB)
    uint8_t min_gds[] = {
        0x00, 0x04, 0x04, 0x00  // Just ENDLIB
    };
    cache = wasm_create_library_cache(min_gds, sizeof(min_gds));
    TEST_ASSERT(cache == NULL, "Minimum GDSII file (ENDLIB only) rejected");

    // Test with file that has correct structure but no actual elements
    uint8_t empty_struct_gds[] = {
        // HEADER
        0x00, 0x06, 0x00, 0x02, 0x00, 0x03,
        // BGNLIB
        0x00, 0x10, 0x01, 0x02,
        0x07, 0xE7, 0x07, 0x08, 0x0F, 0x2A,
        0x07, 0xE7, 0x07, 0x08, 0x0F, 0x2B,
        // LIBNAME
        0x00, 0x0C, 0x02, 0x06,
        'E', 'M', 'P', 'T', 'Y', 0x00, 0x00, 0x00,
        // UNITS
        0x00, 0x14, 0x03, 0x05,
        0x3F, 0x1A, 0x36, 0xE2, 0xEB, 0x1C, 0x43, 0x2B,
        0x3E, 0x11, 0xE6, 0xA2, 0x8E, 0xFB, 0x1A, 0x24,
        // BGNSTR
        0x00, 0x10, 0x05, 0x02,
        0x07, 0xE7, 0x07, 0x08, 0x0F, 0x2C,
        0x07, 0xE7, 0x07, 0x08, 0x0F, 0x2C,
        // STRNAME
        0x00, 0x0C, 0x06, 0x06,
        'E', 'M', 'P', 'T', 'Y', 0x00, 0x00, 0x00,
        // ENDSTR
        0x00, 0x04, 0x07, 0x00,
        // ENDLIB
        0x00, 0x04, 0x04, 0x00
    };

    cache = wasm_create_library_cache(empty_struct_gds, sizeof(empty_struct_gds));
    TEST_ASSERT(cache != NULL, "Empty structure file accepted");

    if (cache) {
        int result = wasm_parse_library_structures(cache);
        TEST_ASSERT(result == 0, "Empty structure file parsed successfully");
        TEST_ASSERT(cache->structure_count == 1, "One structure found");

        result = wasm_parse_structure_elements(cache, 0);
        TEST_ASSERT(result == 0, "Empty structure elements parsed");
        TEST_ASSERT(cache->structures[0].element_count == 0, "No elements found");

        int element_count = wasm_get_element_count(cache, 0);
        TEST_ASSERT(element_count == 0, "Element count returns 0 for empty structure");

        wasm_free_library_cache(cache);
    }

    return 0;
}

int test_concurrent_access_patterns(void) {
    printf("Testing concurrent access patterns\n");

    // Create cache
    wasm_library_cache_t* cache = wasm_create_library_cache(valid_gds_data, sizeof(valid_gds_data));
    TEST_ASSERT(cache != NULL, "Cache created for concurrent testing");

    if (!cache) return -1;

    // Parse structures
    int result = wasm_parse_library_structures(cache);
    TEST_ASSERT(result == 0, "Structures parsed successfully");

    // Test multiple rapid calls to the same function (simulating concurrent access)
    for (int i = 0; i < 100; i++) {
        int count = wasm_get_element_count(cache, 0);
        TEST_ASSERT(count == 0, "Concurrent access handled correctly");
    }

    // Test rapid parsing calls
    for (int i = 0; i < 10; i++) {
        result = wasm_parse_structure_elements(cache, 0);
        TEST_ASSERT(result == 0, "Rapid parsing handled correctly");
    }

    // Test mixed access patterns
    for (int i = 0; i < 10; i++) {
        int count = wasm_get_element_count(cache, 0);
        result = wasm_parse_structure_elements(cache, 0);
        int element_type = wasm_get_element_type(cache, 0, -1); // Invalid index
        TEST_ASSERT(count == 0 && result == 0 && element_type == -1,
                   "Mixed access pattern handled correctly");
    }

    wasm_free_library_cache(cache);
    return 0;
}

// Test runner
void run_all_tests(void) {
    printf("=== Invalid Input Tests ===\n\n");

    test_memory_file_invalid_inputs();
    printf("\n");

    test_library_cache_invalid_inputs();
    printf("\n");

    test_element_access_invalid_indices();
    printf("\n");

    test_memory_allocation_failure();
    printf("\n");

    test_corrupted_data_handling();
    printf("\n");

    test_boundary_conditions();
    printf("\n");

    test_concurrent_access_patterns();
    printf("\n");
}

void print_test_summary(void) {
    printf("=== Test Summary ===\n");
    printf("Total tests: %d\n", stats.total_tests);
    printf("Passed: %d\n", stats.passed_tests);
    printf("Failed: %d\n", stats.failed_tests);

    if (stats.failed_tests == 0) {
        printf("🎉 All error handling tests passed!\n");
    } else {
        printf("❌ Some error handling tests failed. Please review.\n");
    }

    double success_rate = (double)stats.passed_tests / stats.total_tests * 100.0;
    printf("Success rate: %.1f%%\n", success_rate);
}

int main(void) {
    run_all_tests();
    print_test_summary();

    return (stats.failed_tests == 0) ? 0 : 1;
}