/*
 * Library Cache Management Unit Tests
 *
 * Comprehensive testing of library cache functionality for WASM GDSII parser
 */

#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <stdint.h>
#include <assert.h>
#include <time.h>

// Include our headers
#include "../../include/wasm-element-cache.h"
#include "../../include/mem-file.h"
#include "../../../Basic/gdsio/gdstypes.h"

// Test statistics
typedef struct {
    int total_tests;
    int passed_tests;
    int failed_tests;
    int skipped_tests;
} test_stats_t;

static test_stats_t stats = {0, 0, 0, 0};

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

#define TEST_SKIP(message) do { \
    stats.total_tests++; \
    stats.skipped_tests++; \
    printf("  ⚠ %s (skipped)\n", message); \
} while(0)

// Test GDSII data generation functions
void create_minimal_gdsii_data(uint8_t** data, size_t* size) {
    static uint8_t minimal_gds[] = {
        // HEADER record (0x0002)
        0x00, 0x06,  // Length = 6 (total)
        0x00, 0x02,  // Type = HEADER
        0x00, 0x03,  // Version = 3

        // BGNLIB record (0x0102)
        0x00, 0x10,  // Length = 16 (total)
        0x01, 0x02,  // Type = BGNLIB
        0x07, 0xE7, 0x07, 0x08, 0x0F, 0x2A,  // Creation date
        0x07, 0xE7, 0x07, 0x08, 0x0F, 0x2B,  // Modification date

        // LIBNAME record (0x0206)
        0x00, 0x0C,  // Length = 12 (total)
        0x02, 0x06,  // Type = LIBNAME
        'T', 'E', 'S', 'T', 0x00, 0x00, 0x00, 0x00,  // Library name

        // UNITS record (0x0305)
        0x00, 0x14,  // Length = 20 (total)
        0x03, 0x05,  // Type = UNITS
        0x3F, 0x1A, 0x36, 0xE2, 0xEB, 0x1C, 0x43, 0x2B,  // User units
        0x3E, 0x11, 0xE6, 0xA2, 0x8E, 0xFB, 0x1A, 0x24,  // Meters per DB unit

        // ENDLIB record (0x0400)
        0x00, 0x04,  // Length = 4 (total)
        0x04, 0x00   // Type = ENDLIB
    };

    *data = malloc(sizeof(minimal_gds));
    if (*data) {
        memcpy(*data, minimal_gds, sizeof(minimal_gds));
        *size = sizeof(minimal_gds);
    }
}

void create_complex_gdsii_data(uint8_t** data, size_t* size) {
    static uint8_t complex_gds[] = {
        // HEADER
        0x00, 0x06, 0x00, 0x02, 0x00, 0x03,

        // BGNLIB
        0x00, 0x10, 0x01, 0x02,
        0x07, 0xE7, 0x07, 0x08, 0x0F, 0x2A,
        0x07, 0xE7, 0x07, 0x08, 0x0F, 0x2B,

        // LIBNAME
        0x00, 0x0C, 0x02, 0x06,
        'C', 'O', 'M', 'P', 'L', 'E', 'X', 0x00,

        // UNITS
        0x00, 0x14, 0x03, 0x05,
        0x3F, 0x1A, 0x36, 0xE2, 0xEB, 0x1C, 0x43, 0x2B,
        0x3E, 0x11, 0xE6, 0xA2, 0x8E, 0xFB, 0x1A, 0x24,

        // First structure - BGNSTR
        0x00, 0x10, 0x05, 0x02,
        0x07, 0xE7, 0x07, 0x08, 0x0F, 0x2C,
        0x07, 0xE7, 0x07, 0x08, 0x0F, 0x2C,

        // STRNAME
        0x00, 0x0C, 0x06, 0x06,
        'S', 'T', 'R', '1', 0x00, 0x00, 0x00, 0x00,

        // BOUNDARY
        0x00, 0x04, 0x08, 0x00,

        // LAYER
        0x00, 0x06, 0x0D, 0x02, 0x00, 0x01,

        // DATATYPE
        0x00, 0x06, 0x0E, 0x02, 0x00, 0x00,

        // XY - Square
        0x00, 0x18, 0x10, 0x03,
        0x00, 0x00, 0x00, 0x00,  // (0,0)
        0x00, 0x32, 0x00, 0x00,  // (50,0)
        0x00, 0x32, 0x00, 0x32,  // (50,50)
        0x00, 0x00, 0x00, 0x32,  // (0,50)
        0x00, 0x00, 0x00, 0x00,  // (0,0)

        // ENDEL
        0x00, 0x04, 0x11, 0x00,

        // ENDSTR
        0x00, 0x04, 0x07, 0x00,

        // Second structure - BGNSTR
        0x00, 0x10, 0x05, 0x02,
        0x07, 0xE7, 0x07, 0x08, 0x0F, 0x2D,
        0x07, 0xE7, 0x07, 0x08, 0x0F, 0x2D,

        // STRNAME
        0x00, 0x0C, 0x06, 0x06,
        'S', 'T', 'R', '2', 0x00, 0x00, 0x00, 0x00,

        // BOUNDARY
        0x00, 0x04, 0x08, 0x00,

        // LAYER
        0x00, 0x06, 0x0D, 0x02, 0x00, 0x02,

        // DATATYPE
        0x00, 0x06, 0x0E, 0x02, 0x00, 0x00,

        // XY - Circle approximation
        0x00, 0x28, 0x10, 0x03,
        0x00, 0x28, 0x00, 0x14,  // (40,20)
        0x00, 0x3C, 0x00, 0x0A,  // (60,10)
        0x00, 0x50, 0x00, 0x14,  // (80,20)
        0x00, 0x50, 0x00, 0x28,  // (80,40)
        0x00, 0x3C, 0x00, 0x32,  // (60,50)
        0x00, 0x28, 0x00, 0x28,  // (40,40)
        0x00, 0x14, 0x00, 0x32,  // (20,50)
        0x00, 0x14, 0x00, 0x14,  // (20,20)
        0x00, 0x28, 0x00, 0x14,  // (40,20)

        // ENDEL
        0x00, 0x04, 0x11, 0x00,

        // ENDSTR
        0x00, 0x04, 0x07, 0x00,

        // ENDLIB
        0x00, 0x04, 0x04, 0x00
    };

    *data = malloc(sizeof(complex_gds));
    if (*data) {
        memcpy(*data, complex_gds, sizeof(complex_gds));
        *size = sizeof(complex_gds);
    }
}

// Test functions
int test_wasm_create_library_cache_basic(void) {
    printf("Testing wasm_create_library_cache - Basic functionality\n");

    uint8_t* test_data;
    size_t test_size;
    create_minimal_gdsii_data(&test_data, &test_size);

    TEST_ASSERT(test_data != NULL, "Test data created");

    if (!test_data) return -1;

    // Test successful creation
    wasm_library_cache_t* cache = wasm_create_library_cache(test_data, test_size);
    TEST_ASSERT(cache != NULL, "Library cache created successfully");

    if (cache) {
        // Test cache metadata
        TEST_ASSERT(strcmp(cache->name, "TEST") == 0, "Library name parsed correctly");
        TEST_ASSERT(cache->version == 3, "Library version parsed correctly");
        TEST_ASSERT(cache->user_units_per_db_unit > 0, "User units parsed");
        TEST_ASSERT(cache->meters_per_db_unit > 0, "Meters per DB unit parsed");
        TEST_ASSERT(cache->raw_data == test_data, "Raw data pointer stored");
        TEST_ASSERT(cache->data_size == test_size, "Data size stored");
        TEST_ASSERT(cache->mem_file != NULL, "Memory file created");
        TEST_ASSERT(cache->structure_count == 0, "Structure count initialized to 0");

        wasm_free_library_cache(cache);
    }

    free(test_data);
    return 0;
}

int test_wasm_create_library_cache_invalid(void) {
    printf("Testing wasm_create_library_cache - Invalid inputs\n");

    // Test NULL data
    wasm_library_cache_t* cache = wasm_create_library_cache(NULL, 100);
    TEST_ASSERT(cache == NULL, "NULL data rejected");

    // Test zero size
    uint8_t dummy_data = 0x42;
    cache = wasm_create_library_cache(&dummy_data, 0);
    TEST_ASSERT(cache == NULL, "Zero size rejected");

    // Test corrupted data
    uint8_t corrupted_data[] = {0x00, 0x01, 0x02, 0x03}; // Too small for any valid record
    cache = wasm_create_library_cache(corrupted_data, sizeof(corrupted_data));
    TEST_ASSERT(cache == NULL, "Corrupted data rejected");

    return 0;
}

int test_wasm_free_library_cache(void) {
    printf("Testing wasm_free_library_cache\n");

    uint8_t* test_data;
    size_t test_size;
    create_minimal_gdsii_data(&test_data, &test_size);

    wasm_library_cache_t* cache = wasm_create_library_cache(test_data, test_size);
    TEST_ASSERT(cache != NULL, "Library cache created");

    if (cache) {
        // Test normal free
        wasm_free_library_cache(cache);
        TEST_ASSERT(1, "Library cache freed without crash");
    }

    // Test NULL free (should not crash)
    wasm_free_library_cache(NULL);
    TEST_ASSERT(1, "NULL cache free handled gracefully");

    free(test_data);
    return 0;
}

int test_wasm_parse_library_structures(void) {
    printf("Testing wasm_parse_library_structures\n");

    uint8_t* test_data;
    size_t test_size;
    create_complex_gdsii_data(&test_data, &test_size);

    TEST_ASSERT(test_data != NULL, "Complex test data created");

    if (!test_data) return -1;

    wasm_library_cache_t* cache = wasm_create_library_cache(test_data, test_size);
    TEST_ASSERT(cache != NULL, "Library cache created");

    if (!cache) {
        free(test_data);
        return -1;
    }

    // Test structure parsing
    int result = wasm_parse_library_structures(cache);
    TEST_ASSERT(result == 0, "Structure parsing successful");
    TEST_ASSERT(cache->structure_count == 2, "Correct number of structures parsed");

    // Test structure names
    if (cache->structure_count >= 2) {
        TEST_ASSERT(strcmp(cache->structures[0].name, "STR1") == 0, "First structure name correct");
        TEST_ASSERT(strcmp(cache->structures[1].name, "STR2") == 0, "Second structure name correct");
    }

    wasm_free_library_cache(cache);
    free(test_data);
    return 0;
}

int test_wasm_parse_structure_elements(void) {
    printf("Testing wasm_parse_structure_elements\n");

    uint8_t* test_data;
    size_t test_size;
    create_complex_gdsii_data(&test_data, &test_size);

    wasm_library_cache_t* cache = wasm_create_library_cache(test_data, test_size);
    TEST_ASSERT(cache != NULL, "Library cache created");

    if (!cache) {
        free(test_data);
        return -1;
    }

    // Parse structures first
    int result = wasm_parse_library_structures(cache);
    TEST_ASSERT(result == 0, "Structure parsing successful");

    if (result != 0) {
        wasm_free_library_cache(cache);
        free(test_data);
        return -1;
    }

    // Parse elements for first structure
    result = wasm_parse_structure_elements(cache, 0);
    TEST_ASSERT(result == 0, "First structure element parsing successful");
    TEST_ASSERT(cache->structures[0].element_count == 1, "First structure has 1 element");

    // Parse elements for second structure
    result = wasm_parse_structure_elements(cache, 1);
    TEST_ASSERT(result == 0, "Second structure element parsing successful");
    TEST_ASSERT(cache->structures[1].element_count == 1, "Second structure has 1 element");

    // Test invalid structure index
    result = wasm_parse_structure_elements(cache, -1);
    TEST_ASSERT(result != 0, "Invalid structure index rejected");

    result = wasm_parse_structure_elements(cache, 10);
    TEST_ASSERT(result != 0, "Out of bounds structure index rejected");

    wasm_free_library_cache(cache);
    free(test_data);
    return 0;
}

int test_element_access_functions(void) {
    printf("Testing element access functions\n");

    uint8_t* test_data;
    size_t test_size;
    create_complex_gdsii_data(&test_data, &test_size);

    wasm_library_cache_t* cache = wasm_create_library_cache(test_data, test_size);
    TEST_ASSERT(cache != NULL, "Library cache created");

    if (!cache) {
        free(test_data);
        return -1;
    }

    // Parse structures and elements
    wasm_parse_library_structures(cache);
    wasm_parse_structure_elements(cache, 0);
    wasm_parse_structure_elements(cache, 1);

    // Test element count
    int count = wasm_get_element_count(cache, 0);
    TEST_ASSERT(count == 1, "First structure element count correct");

    count = wasm_get_element_count(cache, 1);
    TEST_ASSERT(count == 1, "Second structure element count correct");

    // Test element type
    int element_type = wasm_get_element_type(cache, 0, 0);
    TEST_ASSERT(element_type == GDS_BOUNDARY, "First element type correct");

    element_type = wasm_get_element_type(cache, 1, 0);
    TEST_ASSERT(element_type == GDS_BOUNDARY, "Second element type correct");

    // Test element layer
    int layer = wasm_get_element_layer(cache, 0, 0);
    TEST_ASSERT(layer == 1, "First element layer correct");

    layer = wasm_get_element_layer(cache, 1, 0);
    TEST_ASSERT(layer == 2, "Second element layer correct");

    // Test invalid indices
    count = wasm_get_element_count(cache, -1);
    TEST_ASSERT(count == -1, "Invalid structure index handled");

    element_type = wasm_get_element_type(cache, 0, -1);
    TEST_ASSERT(element_type == -1, "Invalid element index handled");

    wasm_free_library_cache(cache);
    free(test_data);
    return 0;
}

int test_polygon_functions(void) {
    printf("Testing polygon functions\n");

    uint8_t* test_data;
    size_t test_size;
    create_complex_gdsii_data(&test_data, &test_size);

    wasm_library_cache_t* cache = wasm_create_library_cache(test_data, test_size);
    TEST_ASSERT(cache != NULL, "Library cache created");

    if (!cache) {
        free(test_data);
        return -1;
    }

    // Parse structures and elements
    wasm_parse_library_structures(cache);
    wasm_parse_structure_elements(cache, 0);
    wasm_parse_structure_elements(cache, 1);

    // Test polygon count
    int polygon_count = wasm_get_element_polygon_count(cache, 0, 0);
    TEST_ASSERT(polygon_count == 1, "First element polygon count correct");

    polygon_count = wasm_get_element_polygon_count(cache, 1, 0);
    TEST_ASSERT(polygon_count == 1, "Second element polygon count correct");

    // Test vertex count
    int vertex_count = wasm_get_element_polygon_vertex_count(cache, 0, 0, 0);
    TEST_ASSERT(vertex_count == 5, "First polygon vertex count correct (square)");

    vertex_count = wasm_get_element_polygon_vertex_count(cache, 1, 0, 0);
    TEST_ASSERT(vertex_count == 9, "Second polygon vertex count correct (circle approximation)");

    // Test vertex coordinates
    double* vertices = wasm_get_element_polygon_vertices(cache, 0, 0, 0);
    TEST_ASSERT(vertices != NULL, "Vertex pointer returned");
    if (vertices) {
        // Check square vertices
        TEST_ASSERT(vertices[0] == 0.0 && vertices[1] == 0.0, "Square vertex 1 correct");
        TEST_ASSERT(vertices[2] == 50.0 && vertices[3] == 0.0, "Square vertex 2 correct");
        TEST_ASSERT(vertices[4] == 50.0 && vertices[5] == 50.0, "Square vertex 3 correct");
        TEST_ASSERT(vertices[6] == 0.0 && vertices[7] == 50.0, "Square vertex 4 correct");
        TEST_ASSERT(vertices[8] == 0.0 && vertices[9] == 0.0, "Square vertex 5 correct");
    }

    wasm_free_library_cache(cache);
    free(test_data);
    return 0;
}

int test_error_handling(void) {
    printf("Testing error handling\n");

    uint8_t* test_data;
    size_t test_size;
    create_minimal_gdsii_data(&test_data, &test_size);

    // Test with NULL cache
    int result = wasm_parse_library_structures(NULL);
    TEST_ASSERT(result != 0, "NULL cache rejected in structure parsing");

    result = wasm_parse_structure_elements(NULL, 0);
    TEST_ASSERT(result != 0, "NULL cache rejected in element parsing");

    int count = wasm_get_element_count(NULL, 0);
    TEST_ASSERT(count == -1, "NULL cache rejected in element count");

    // Test with NULL data in cache (simulate corruption)
    wasm_library_cache_t* cache = wasm_create_library_cache(test_data, test_size);
    TEST_ASSERT(cache != NULL, "Library cache created");

    if (cache) {
        // Temporarily corrupt the mem_file pointer
        mem_file_t* saved_file = cache->mem_file;
        cache->mem_file = NULL;

        result = wasm_parse_library_structures(cache);
        TEST_ASSERT(result != 0, "Corrupted mem_file handled");

        // Restore and test again
        cache->mem_file = saved_file;
        result = wasm_parse_library_structures(cache);
        TEST_ASSERT(result == 0, "Restored cache works normally");

        wasm_free_library_cache(cache);
    }

    free(test_data);
    return 0;
}

int test_lazy_loading(void) {
    printf("Testing lazy loading functionality\n");

    uint8_t* test_data;
    size_t test_size;
    create_complex_gdsii_data(&test_data, &test_size);

    wasm_library_cache_t* cache = wasm_create_library_cache(test_data, test_size);
    TEST_ASSERT(cache != NULL, "Library cache created");

    if (!cache) {
        free(test_data);
        return -1;
    }

    // Initially, structures should not be parsed
    TEST_ASSERT(cache->structure_count == 0, "Structures not parsed initially");

    // Parse library structures
    int result = wasm_parse_library_structures(cache);
    TEST_ASSERT(result == 0, "Library structures parsed successfully");

    // Elements should not be parsed yet
    TEST_ASSERT(cache->structures[0].element_count == 0, "Elements not parsed initially");
    TEST_ASSERT(!cache->structures[0].is_fully_parsed, "Structure not marked as fully parsed");

    // Parse elements on demand
    result = wasm_parse_structure_elements(cache, 0);
    TEST_ASSERT(result == 0, "Elements parsed on demand");
    TEST_ASSERT(cache->structures[0].element_count > 0, "Elements parsed successfully");
    TEST_ASSERT(cache->structures[0].is_fully_parsed, "Structure marked as fully parsed");

    // Test that parsing again doesn't break anything
    result = wasm_parse_structure_elements(cache, 0);
    TEST_ASSERT(result == 0, "Repeated parsing handled gracefully");

    wasm_free_library_cache(cache);
    free(test_data);
    return 0;
}

// Test runner
void run_all_tests(void) {
    printf("=== Library Cache Unit Tests ===\n\n");

    test_wasm_create_library_cache_basic();
    printf("\n");

    test_wasm_create_library_cache_invalid();
    printf("\n");

    test_wasm_free_library_cache();
    printf("\n");

    test_wasm_parse_library_structures();
    printf("\n");

    test_wasm_parse_structure_elements();
    printf("\n");

    test_element_access_functions();
    printf("\n");

    test_polygon_functions();
    printf("\n");

    test_error_handling();
    printf("\n");

    test_lazy_loading();
    printf("\n");
}

void print_test_summary(void) {
    printf("=== Test Summary ===\n");
    printf("Total tests: %d\n", stats.total_tests);
    printf("Passed: %d\n", stats.passed_tests);
    printf("Failed: %d\n", stats.failed_tests);
    printf("Skipped: %d\n", stats.skipped_tests);

    if (stats.failed_tests == 0) {
        printf("🎉 All tests passed!\n");
    } else {
        printf("❌ Some tests failed. Please review.\n");
    }

    double success_rate = (double)stats.passed_tests / stats.total_tests * 100.0;
    printf("Success rate: %.1f%%\n", success_rate);
}

int main(void) {
    run_all_tests();
    print_test_summary();

    return (stats.failed_tests == 0) ? 0 : 1;
}