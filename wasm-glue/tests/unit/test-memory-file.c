/*
 * Memory File Abstraction Unit Tests
 *
 * Comprehensive testing of memory file functionality for WASM GDSII parser
 */

#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <stdint.h>
#include <assert.h>
#include <time.h>

// Include our headers
#include "../../include/mem-file.h"

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

// Test data generation
void generate_test_data(uint8_t* buffer, size_t size, int pattern) {
    switch (pattern) {
        case 0: // Sequential pattern
            for (size_t i = 0; i < size; i++) {
                buffer[i] = (uint8_t)(i & 0xFF);
            }
            break;
        case 1: // Random pattern
            srand((unsigned int)time(NULL));
            for (size_t i = 0; i < size; i++) {
                buffer[i] = (uint8_t)(rand() & 0xFF);
            }
            break;
        case 2: // Repeating pattern
            for (size_t i = 0; i < size; i++) {
                buffer[i] = (uint8_t)(i % 256);
            }
            break;
        default:
            memset(buffer, 0, size);
            break;
    }
}

// Test functions
int test_mem_fopen_basic(void) {
    printf("Testing mem_fopen - Basic functionality\n");

    uint8_t test_data[100];
    generate_test_data(test_data, sizeof(test_data), 0);

    // Test valid open
    mem_file_t* file = mem_fopen(test_data, sizeof(test_data), MEM_READ);
    TEST_ASSERT(file != NULL, "Valid file open");

    if (file) {
        TEST_ASSERT(file->data == test_data, "Data pointer correctly set");
        TEST_ASSERT(file->size == sizeof(test_data), "Size correctly set");
        TEST_ASSERT(file->position == 0, "Position initialized to 0");
        TEST_ASSERT(file->is_wasm_memory == 1, "WASM memory flag set");
        TEST_ASSERT(!file->eof_flag, "EOF flag initially false");
        TEST_ASSERT(!file->error_flag, "Error flag initially false");
        mem_fclose(file);
    }

    // Test NULL data
    file = mem_fopen(NULL, 100, MEM_READ);
    TEST_ASSERT(file == NULL, "NULL data rejected");

    // Test zero size
    file = mem_fopen(test_data, 0, MEM_READ);
    TEST_ASSERT(file == NULL, "Zero size rejected");

    // Test invalid mode
    file = mem_fopen(test_data, sizeof(test_data), "w");
    TEST_ASSERT(file == NULL, "Write mode rejected (not implemented)");

    return 0;
}

int test_mem_fclose(void) {
    printf("Testing mem_fclose\n");

    uint8_t test_data[100];
    generate_test_data(test_data, sizeof(test_data), 0);

    mem_file_t* file = mem_fopen(test_data, sizeof(test_data), MEM_READ);
    TEST_ASSERT(file != NULL, "File opened successfully");

    // Test normal close
    mem_fclose(file);
    TEST_ASSERT(1, "File closed without crash"); // If we get here, close worked

    // Test NULL close (should not crash)
    mem_fclose(NULL);
    TEST_ASSERT(1, "NULL file close handled gracefully");

    return 0;
}

int test_mem_fread(void) {
    printf("Testing mem_fread\n");

    uint8_t test_data[100];
    generate_test_data(test_data, sizeof(test_data), 1); // Random data

    mem_file_t* file = mem_fopen(test_data, sizeof(test_data), MEM_READ);
    TEST_ASSERT(file != NULL, "File opened successfully");

    if (!file) return -1;

    // Test normal read
    uint8_t buffer[50];
    size_t bytes_read = mem_fread(buffer, 1, sizeof(buffer), file);
    TEST_ASSERT(bytes_read == sizeof(buffer), "Read correct number of bytes");

    // Verify data
    int data_match = 1;
    for (size_t i = 0; i < bytes_read; i++) {
        if (buffer[i] != test_data[i]) {
            data_match = 0;
            break;
        }
    }
    TEST_ASSERT(data_match, "Read data matches original");

    // Test read from different position
    mem_fseek(file, 0, SEEK_SET);
    uint8_t small_buffer[10];
    bytes_read = mem_fread(small_buffer, 2, 5, file);
    TEST_ASSERT(bytes_read == 5, "Read with different element size");

    // Test read at end of file
    mem_fseek(file, -10, SEEK_END);
    bytes_read = mem_fread(buffer, 1, 20, file);
    TEST_ASSERT(bytes_read == 10, "Read at end of file (partial)");
    TEST_ASSERT(mem_feof(file), "EOF flag set after reading to end");

    // Test read after EOF
    bytes_read = mem_fread(buffer, 1, 10, file);
    TEST_ASSERT(bytes_read == 0, "Read after EOF returns 0");

    // Test NULL parameters
    bytes_read = mem_fread(NULL, 1, 10, file);
    TEST_ASSERT(bytes_read == 0, "NULL buffer rejected");

    mem_fclose(file);
    return 0;
}

int test_mem_fseek(void) {
    printf("Testing mem_fseek\n");

    uint8_t test_data[100];
    generate_test_data(test_data, sizeof(test_data), 0);

    mem_file_t* file = mem_fopen(test_data, sizeof(test_data), MEM_READ);
    TEST_ASSERT(file != NULL, "File opened successfully");

    if (!file) return -1;

    // Test SEEK_SET
    int result = mem_fseek(file, 50, SEEK_SET);
    TEST_ASSERT(result == 0, "SEEK_SET to middle");
    TEST_ASSERT(mem_ftell(file) == 50, "Position correct after SEEK_SET");

    // Test SEEK_CUR
    result = mem_fseek(file, 10, SEEK_CUR);
    TEST_ASSERT(result == 0, "SEEK_CUR forward");
    TEST_ASSERT(mem_ftell(file) == 60, "Position correct after SEEK_CUR");

    result = mem_fseek(file, -20, SEEK_CUR);
    TEST_ASSERT(result == 0, "SEEK_CUR backward");
    TEST_ASSERT(mem_ftell(file) == 40, "Position correct after SEEK_CUR");

    // Test SEEK_END
    result = mem_fseek(file, 0, SEEK_END);
    TEST_ASSERT(result == 0, "SEEK_SET to end");
    TEST_ASSERT(mem_ftell(file) == 100, "Position correct after SEEK_END");

    result = mem_fseek(file, -10, SEEK_END);
    TEST_ASSERT(result == 0, "SEEK_END backward");
    TEST_ASSERT(mem_ftell(file) == 90, "Position correct after SEEK_END");

    // Test invalid seek (before beginning)
    result = mem_fseek(file, -200, SEEK_SET);
    TEST_ASSERT(result != 0, "Invalid seek before beginning rejected");
    TEST_ASSERT(file->error_flag, "Error flag set on invalid seek");

    // Clear error and test invalid seek (beyond end)
    file->error_flag = 0;
    result = mem_fseek(file, 200, SEEK_SET);
    TEST_ASSERT(result != 0, "Invalid seek beyond end rejected");
    TEST_ASSERT(file->error_flag, "Error flag set on invalid seek");

    mem_fclose(file);
    return 0;
}

int test_mem_ftell(void) {
    printf("Testing mem_ftell\n");

    uint8_t test_data[100];
    generate_test_data(test_data, sizeof(test_data), 0);

    mem_file_t* file = mem_fopen(test_data, sizeof(test_data), MEM_READ);
    TEST_ASSERT(file != NULL, "File opened successfully");

    if (!file) return -1;

    // Test initial position
    long pos = mem_ftell(file);
    TEST_ASSERT(pos == 0, "Initial position is 0");

    // Test position after read
    uint8_t buffer[10];
    mem_fread(buffer, 1, sizeof(buffer), file);
    pos = mem_ftell(file);
    TEST_ASSERT(pos == 10, "Position correct after read");

    // Test position after seek
    mem_fseek(file, 50, SEEK_SET);
    pos = mem_ftell(file);
    TEST_ASSERT(pos == 50, "Position correct after seek");

    // Test position at end
    mem_fseek(file, 0, SEEK_END);
    pos = mem_ftell(file);
    TEST_ASSERT(pos == 100, "Position correct at end");

    mem_fclose(file);
    return 0;
}

int test_mem_feof(void) {
    printf("Testing mem_feof\n");

    uint8_t test_data[10];
    generate_test_data(test_data, sizeof(test_data), 0);

    mem_file_t* file = mem_fopen(test_data, sizeof(test_data), MEM_READ);
    TEST_ASSERT(file != NULL, "File opened successfully");

    if (!file) return -1;

    // Test initial EOF state
    TEST_ASSERT(!mem_feof(file), "EOF initially false");

    // Test EOF after reading all data
    uint8_t buffer[20];
    mem_fread(buffer, 1, sizeof(buffer), file);
    TEST_ASSERT(mem_feof(file), "EOF true after reading all data");

    // Test EOF after seek to end
    mem_fseek(file, 0, SEEK_SET);
    mem_fseek(file, 0, SEEK_END);
    TEST_ASSERT(mem_feof(file), "EOF true when positioned at end");

    // Test EOF after seek away from end
    mem_fseek(file, 5, SEEK_SET);
    TEST_ASSERT(!mem_feof(file), "EOF false after seeking away from end");

    mem_fclose(file);
    return 0;
}

int test_big_endian_reading(void) {
    printf("Testing big-endian reading functions\n");

    // Test data with known big-endian values
    uint8_t test_data[] = {
        0x12, 0x34,        // 0x1234 = 4660
        0x87, 0x65, 0x43, 0x21,  // 0x87654321 = 2271560481
        0x40, 0x49, 0x0F, 0xDB, 0x3A, 0xD8, 0x24, 0xCD  // 3.141592653589793 (approx)
    };

    mem_file_t* file = mem_fopen(test_data, sizeof(test_data), MEM_READ);
    TEST_ASSERT(file != NULL, "Test file opened");

    if (!file) return -1;

    // Test 16-bit reading
    uint16_t value16;
    int result = mem_fread_be16(file, &value16);
    TEST_ASSERT(result == 1, "16-bit read successful");
    TEST_ASSERT(value16 == 0x1234, "16-bit value correct");

    // Test 32-bit reading
    uint32_t value32;
    result = mem_fread_be32(file, &value32);
    TEST_ASSERT(result == 1, "32-bit read successful");
    TEST_ASSERT(value32 == 0x87654321, "32-bit value correct");

    // Test 64-bit double reading
    double value64;
    result = mem_fread_be64(file, &value64);
    TEST_ASSERT(result == 1, "64-bit read successful");
    TEST_ASSERT((value64 > 3.14 && value64 < 3.15), "64-bit double value approximately correct");

    mem_fclose(file);
    return 0;
}

int test_gdsii_header_parsing(void) {
    printf("Testing GDSII header parsing\n");

    // Test GDSII record header: length=12, type=0x0206 (LIBNAME)
    uint8_t test_data[] = {
        0x00, 0x0C,  // Record length = 12 (total)
        0x02, 0x06   // Record type = 0x0206 (LIBNAME)
    };

    mem_file_t* file = mem_fopen(test_data, sizeof(test_data), MEM_READ);
    TEST_ASSERT(file != NULL, "Test file opened");

    if (!file) return -1;

    // Test header reading
    uint16_t record_type, record_length;
    int result = mem_fread_gdsii_header(file, &record_type, &record_length);
    TEST_ASSERT(result == 1, "GDSII header read successful");
    TEST_ASSERT(record_type == 0x0206, "Record type correct");
    TEST_ASSERT(record_length == 8, "Record data length correct (12 - 4 header bytes)");

    // Test position after header read
    long pos = mem_ftell(file);
    TEST_ASSERT(pos == 4, "Position correct after header read");

    mem_fclose(file);
    return 0;
}

int test_edge_cases(void) {
    printf("Testing edge cases\n");

    // Test single byte file
    uint8_t single_byte[] = {0x42};
    mem_file_t* file = mem_fopen(single_byte, sizeof(single_byte), MEM_READ);
    TEST_ASSERT(file != NULL, "Single byte file opened");

    if (file) {
        uint8_t buffer;
        size_t bytes_read = mem_fread(&buffer, 1, 1, file);
        TEST_ASSERT(bytes_read == 1, "Single byte read");
        TEST_ASSERT(buffer == 0x42, "Single byte value correct");
        TEST_ASSERT(mem_feof(file), "EOF detected after single byte");
        mem_fclose(file);
    }

    // Test empty file
    uint8_t empty_data[1] = {0};
    file = mem_fopen(empty_data, 0, MEM_READ);
    TEST_ASSERT(file == NULL, "Empty file rejected");

    // Test very small file (smaller than header)
    uint8_t small_data[3] = {0x01, 0x02, 0x03};
    file = mem_fopen(small_data, sizeof(small_data), MEM_READ);
    TEST_ASSERT(file != NULL, "Small file opened");

    if (file) {
        uint16_t record_type, record_length;
        int result = mem_fread_gdsii_header(file, &record_type, &record_length);
        TEST_ASSERT(result == 0, "GDSII header read fails on small file");
        mem_fclose(file);
    }

    return 0;
}

int test_error_conditions(void) {
    printf("Testing error conditions\n");

    uint8_t test_data[100];
    generate_test_data(test_data, sizeof(test_data), 0);

    mem_file_t* file = mem_fopen(test_data, sizeof(test_data), MEM_READ);
    TEST_ASSERT(file != NULL, "File opened successfully");

    if (!file) return -1;

    // Test operations on closed file
    uint8_t buffer[10];
    mem_fclose(file);
    size_t bytes_read = mem_fread(buffer, 1, sizeof(buffer), file);
    TEST_ASSERT(bytes_read == 0, "Read on closed file returns 0");

    // Test NULL file operations
    bytes_read = mem_fread(buffer, 1, sizeof(buffer), NULL);
    TEST_ASSERT(bytes_read == 0, "Read on NULL file returns 0");

    long pos = mem_ftell(NULL);
    TEST_ASSERT(pos == -1, "Tell on NULL file returns -1");

    int result = mem_fseek(NULL, 0, SEEK_SET);
    TEST_ASSERT(result == -1, "Seek on NULL file returns -1");

    int eof = mem_feof(NULL);
    TEST_ASSERT(eof == 1, "EOF on NULL file returns true");

    return 0;
}

// Test runner
void run_all_tests(void) {
    printf("=== Memory File Unit Tests ===\n\n");

    test_mem_fopen_basic();
    printf("\n");

    test_mem_fclose();
    printf("\n");

    test_mem_fread();
    printf("\n");

    test_mem_fseek();
    printf("\n");

    test_mem_ftell();
    printf("\n");

    test_mem_feof();
    printf("\n");

    test_big_endian_reading();
    printf("\n");

    test_gdsii_header_parsing();
    printf("\n");

    test_edge_cases();
    printf("\n");

    test_error_conditions();
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