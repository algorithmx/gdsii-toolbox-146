/*
 * Real GDSII Files Integration Tests
 *
 * Tests the WASM wrapper with actual GDSII files from the real world
 */

#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <stdint.h>
#include <assert.h>
#include <dirent.h>
#include <sys/stat.h>

// Include our headers
#include "../../include/wasm-element-cache.h"
#include "../../include/mem-file.h"

// Test statistics
typedef struct {
    int total_tests;
    int passed_tests;
    int failed_tests;
    int files_tested;
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

// Helper to check if file exists and get size
int file_exists(const char* filename) {
    struct stat st;
    return (stat(filename, &st) == 0);
}

size_t file_size(const char* filename) {
    struct stat st;
    if (stat(filename, &st) == 0) {
        return st.st_size;
    }
    return 0;
}

// Read entire file into memory buffer
uint8_t* read_file(const char* filename, size_t* file_size) {
    FILE* file = fopen(filename, "rb");
    if (!file) {
        printf("    Could not open file: %s\n", filename);
        return NULL;
    }

    // Get file size
    fseek(file, 0, SEEK_END);
    *file_size = ftell(file);
    fseek(file, 0, SEEK_SET);

    if (*file_size == 0) {
        printf("    File is empty: %s\n", filename);
        fclose(file);
        return NULL;
    }

    // Allocate buffer
    uint8_t* buffer = malloc(*file_size);
    if (!buffer) {
        printf("    Failed to allocate memory for file: %s\n", filename);
        fclose(file);
        return NULL;
    }

    // Read file
    size_t bytes_read = fread(buffer, 1, *file_size, file);
    fclose(file);

    if (bytes_read != *file_size) {
        printf("    Failed to read complete file: %s\n", filename);
        free(buffer);
        return NULL;
    }

    return buffer;
}

// Create a simple test GDSII file if no real files are available
uint8_t* create_sample_gds_file(size_t* file_size) {
    static uint8_t sample_gds[] = {
        // HEADER
        0x00, 0x06, 0x00, 0x02, 0x00, 0x03,
        // BGNLIB
        0x00, 0x10, 0x01, 0x02,
        0x07, 0xE7, 0x07, 0x08, 0x0F, 0x2A,
        0x07, 0xE7, 0x07, 0x08, 0x0F, 0x2B,
        // LIBNAME
        0x00, 0x0C, 0x02, 0x06,
        'S', 'A', 'M', 'P', 'L', 'E', 0x00, 0x00,
        // UNITS
        0x00, 0x14, 0x03, 0x05,
        0x3F, 0x1A, 0x36, 0xE2, 0xEB, 0x1C, 0x43, 0x2B,
        0x3E, 0x11, 0xE6, 0xA2, 0x8E, 0xFB, 0x1A, 0x24,

        // First structure - Simple rectangle
        0x00, 0x10, 0x05, 0x02,
        0x07, 0xE7, 0x07, 0x08, 0x0F, 0x2C,
        0x07, 0xE7, 0x07, 0x08, 0x0F, 0x2C,
        0x00, 0x0C, 0x06, 0x06,
        'R', 'E', 'C', 'T', 0x00, 0x00, 0x00, 0x00,
        0x00, 0x04, 0x08, 0x00,
        0x00, 0x06, 0x0D, 0x02, 0x00, 0x01,
        0x00, 0x06, 0x0E, 0x02, 0x00, 0x00,
        0x00, 0x18, 0x10, 0x03,
        0x00, 0x00, 0x00, 0x00,  // (0,0)
        0x00, 0x64, 0x00, 0x00,  // (100,0)
        0x00, 0x64, 0x00, 0x32,  // (100,50)
        0x00, 0x00, 0x00, 0x32,  // (0,50)
        0x00, 0x00, 0x00, 0x00,  // (0,0)
        0x00, 0x04, 0x11, 0x00,
        0x00, 0x04, 0x07, 0x00,

        // Second structure - Circle approximation
        0x00, 0x10, 0x05, 0x02,
        0x07, 0xE7, 0x07, 0x08, 0x0F, 0x2D,
        0x07, 0xE7, 0x07, 0x08, 0x0F, 0x2D,
        0x00, 0x0C, 0x06, 0x06,
        'C', 'I', 'R', 'C', 'L', 'E', 0x00, 0x00,
        0x00, 0x04, 0x08, 0x00,
        0x00, 0x06, 0x0D, 0x02, 0x00, 0x02,
        0x00, 0x06, 0x0E, 0x02, 0x00, 0x00,
        0x00, 0x28, 0x10, 0x03,
        0x00, 0x32, 0x00, 0x14,  // (50,20)
        0x00, 0x4B, 0x00, 0x0A,  // (75,10)
        0x00, 0x64, 0x00, 0x14,  // (100,20)
        0x00, 0x64, 0x00, 0x28,  // (100,40)
        0x00, 0x4B, 0x00, 0x32,  // (75,50)
        0x00, 0x32, 0x00, 0x28,  // (50,40)
        0x00, 0x1E, 0x00, 0x32,  // (30,50)
        0x00, 0x1E, 0x00, 0x0A,  // (30,10)
        0x00, 0x32, 0x00, 0x14,  // (50,20)
        0x00, 0x04, 0x11, 0x00,
        0x00, 0x04, 0x07, 0x00,

        // ENDLIB
        0x00, 0x04, 0x04, 0x00
    };

    *file_size = sizeof(sample_gds);
    uint8_t* buffer = malloc(*file_size);
    if (buffer) {
        memcpy(buffer, sample_gds, sizeof(sample_gds));
    }
    return buffer;
}

// Find GDSII files in common locations
int find_gdsii_files(char** file_list, int max_files) {
    const char* search_paths[] = {
        ".",
        "..",
        "../..",
        "../../..",
        "/tmp",
        "/var/tmp",
        NULL
    };

    int file_count = 0;

    for (int i = 0; search_paths[i] != NULL && file_count < max_files; i++) {
        DIR* dir = opendir(search_paths[i]);
        if (!dir) continue;

        struct dirent* entry;
        while ((entry = readdir(dir)) != NULL && file_count < max_files) {
            if (strstr(entry->d_name, ".gds") ||
                strstr(entry->d_name, ".gdsii") ||
                strstr(entry->d_name, ".GDS") ||
                strstr(entry->d_name, ".GDSII")) {

                char full_path[1024];
                snprintf(full_path, sizeof(full_path), "%s/%s", search_paths[i], entry->d_name);

                if (file_exists(full_path)) {
                    file_list[file_count] = strdup(full_path);
                    file_count++;
                }
            }
        }
        closedir(dir);
    }

    return file_count;
}

// Test a specific GDSII file
int test_gdsii_file(const char* filename) {
    printf("Testing file: %s\n", filename);

    size_t file_size = file_size(filename);
    TEST_ASSERT(file_size > 0, "File has content");
    printf("    File size: %.2f KB\n", file_size / 1024.0);

    uint8_t* file_data = read_file(filename, &file_size);
    TEST_ASSERT(file_data != NULL, "File read into memory");

    if (!file_data) return -1;

    // Test cache creation
    wasm_library_cache_t* cache = wasm_create_library_cache(file_data, file_size);
    TEST_ASSERT(cache != NULL, "Library cache created");

    if (!cache) {
        free(file_data);
        return -1;
    }

    // Test library metadata
    printf("    Library name: '%s'\n", cache->name);
    printf("    User units: %e\n", cache->user_units_per_db_unit);
    printf("    Meters per DB unit: %e\n", cache->meters_per_db_unit);

    TEST_ASSERT(strlen(cache->name) > 0, "Library name parsed");
    TEST_ASSERT(cache->user_units_per_db_unit > 0, "User units valid");
    TEST_ASSERT(cache->meters_per_db_unit > 0, "Meters per DB unit valid");

    // Test structure parsing
    int result = wasm_parse_library_structures(cache);
    TEST_ASSERT(result == 0, "Structure parsing successful");
    printf("    Number of structures: %d\n", cache->structure_count);

    if (result == 0 && cache->structure_count > 0) {
        // Test each structure
        for (int i = 0; i < cache->structure_count && i < 5; i++) {  // Limit to first 5 structures
            printf("    Structure %d: '%s'\n", i, cache->structures[i].name);

            // Parse elements
            int elem_result = wasm_parse_structure_elements(cache, i);
            TEST_ASSERT(elem_result == 0, "Element parsing successful");

            if (elem_result == 0) {
                int element_count = cache->structures[i].element_count;
                printf("      Elements: %d\n", element_count);

                // Test element access
                if (element_count > 0) {
                    int count = wasm_get_element_count(cache, i);
                    TEST_ASSERT(count == element_count, "Element count matches");

                    int element_type = wasm_get_element_type(cache, i, 0);
                    TEST_ASSERT(element_type >= 0, "Element type accessible");

                    if (element_type >= 0) {
                        const char* type_name = "UNKNOWN";
                        switch (element_type) {
                            case GDS_BOUNDARY: type_name = "BOUNDARY"; break;
                            case GDS_PATH: type_name = "PATH"; break;
                            case GDS_SREF: type_name = "SREF"; break;
                            case GDS_AREF: type_name = "AREF"; break;
                            case GDS_TEXT: type_name = "TEXT"; break;
                            case GDS_BOX: type_name = "BOX"; break;
                            case GDS_NODE: type_name = "NODE"; break;
                        }
                        printf("      First element type: %s\n", type_name);
                    }

                    int layer = wasm_get_element_layer(cache, i, 0);
                    printf("      First element layer: %d\n", layer);

                    // Test polygon data if it's a boundary
                    if (element_type == GDS_BOUNDARY) {
                        int polygon_count = wasm_get_element_polygon_count(cache, i, 0);
                        printf("      Polygon count: %d\n", polygon_count);

                        if (polygon_count > 0) {
                            int vertex_count = wasm_get_element_polygon_vertex_count(cache, i, 0, 0);
                            printf("      First polygon vertices: %d\n", vertex_count);

                            if (vertex_count > 0) {
                                double* vertices = wasm_get_element_polygon_vertices(cache, i, 0, 0);
                                TEST_ASSERT(vertices != NULL, "Vertex data accessible");
                                if (vertices) {
                                    printf("      First vertex: (%.1f, %.1f)\n", vertices[0], vertices[1]);
                                }
                            }
                        }
                    }
                }
            }
        }
    }

    wasm_free_library_cache(cache);
    free(file_data);
    stats.files_tested++;

    return 0;
}

int test_sample_file(void) {
    printf("Testing sample GDSII file\n");

    size_t file_size;
    uint8_t* sample_data = create_sample_gds_file(&file_size);
    TEST_ASSERT(sample_data != NULL, "Sample file created");

    if (!sample_data) return -1;

    printf("    Sample file size: %zu bytes\n", file_size);

    wasm_library_cache_t* cache = wasm_create_library_cache(sample_data, file_size);
    TEST_ASSERT(cache != NULL, "Sample cache created");

    if (cache) {
        TEST_ASSERT(strcmp(cache->name, "SAMPLE") == 0, "Library name correct");
        TEST_ASSERT(cache->structure_count == 0, "No structures initially");

        int result = wasm_parse_library_structures(cache);
        TEST_ASSERT(result == 0, "Structure parsing successful");
        TEST_ASSERT(cache->structure_count == 2, "Two structures found");

        if (result == 0) {
            TEST_ASSERT(strcmp(cache->structures[0].name, "RECT") == 0, "First structure name correct");
            TEST_ASSERT(strcmp(cache->structures[1].name, "CIRCLE") == 0, "Second structure name correct");

            // Test both structures
            for (int i = 0; i < 2; i++) {
                wasm_parse_structure_elements(cache, i);
                TEST_ASSERT(cache->structures[i].element_count == 1, "One element per structure");

                int element_type = wasm_get_element_type(cache, i, 0);
                TEST_ASSERT(element_type == GDS_BOUNDARY, "Element type is BOUNDARY");

                int polygon_count = wasm_get_element_polygon_count(cache, i, 0);
                TEST_ASSERT(polygon_count == 1, "One polygon per element");

                int vertex_count = wasm_get_element_polygon_vertex_count(cache, i, 0, 0);
                TEST_ASSERT(vertex_count > 0, "Vertices accessible");

                double* vertices = wasm_get_element_polygon_vertices(cache, i, 0, 0);
                TEST_ASSERT(vertices != NULL, "Vertex data accessible");
            }
        }

        wasm_free_library_cache(cache);
    }

    free(sample_data);
    return 0;
}

int test_multiple_files(void) {
    printf("Testing multiple GDSII files\n");

    char* file_list[20];
    int file_count = find_gdsii_files(file_list, 20);

    if (file_count == 0) {
        printf("No GDSII files found, skipping multiple file test\n");
        return 0;
    }

    printf("Found %d GDSII files:\n", file_count);
    for (int i = 0; i < file_count; i++) {
        printf("  %d. %s\n", i + 1, file_list[i]);
    }
    printf("\n");

    // Test each file
    int successful_files = 0;
    for (int i = 0; i < file_count; i++) {
        if (test_gdsii_file(file_list[i]) == 0) {
            successful_files++;
        }
        printf("\n");
    }

    printf("Multiple files test summary:\n");
    printf("  Files tested: %d\n", file_count);
    printf("  Successful: %d\n", successful_files);
    printf("  Failed: %d\n", file_count - successful_files);

    TEST_ASSERT(successful_files > 0, "At least one file tested successfully");

    // Clean up
    for (int i = 0; i < file_count; i++) {
        free(file_list[i]);
    }

    return 0;
}

int test_real_world_scenarios(void) {
    printf("Testing real-world scenarios\n");

    // Test sample file
    test_sample_file();
    printf("\n");

    // Test multiple files if available
    test_multiple_files();
    printf("\n");

    return 0;
}

// Test runner
void run_all_tests(void) {
    printf("=== Real GDSII Files Integration Tests ===\n\n");

    test_real_world_scenarios();
}

void print_test_summary(void) {
    printf("=== Integration Test Summary ===\n");
    printf("Total tests: %d\n", stats.total_tests);
    printf("Passed: %d\n", stats.passed_tests);
    printf("Failed: %d\n", stats.failed_tests);
    printf("Files tested: %d\n", stats.files_tested);

    if (stats.failed_tests == 0) {
        printf("🎉 All integration tests passed!\n");
    } else {
        printf("❌ Some integration tests failed. Please review.\n");
    }
}

int main(void) {
    run_all_tests();
    print_test_summary();

    return (stats.failed_tests == 0) ? 0 : 1;
}