/*
 * Test System Validation Tool
 *
 * Validates that the comprehensive test suite is properly set up
 * and can detect various types of issues in the WASM GDSII parser.
 */

#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <stdint.h>
#include <assert.h>
#include <sys/stat.h>
#include <dirent.h>

// Test validation statistics
typedef struct {
    int total_checks;
    int passed_checks;
    int failed_checks;
    int warnings;
} validation_stats_t;

static validation_stats_t stats = {0, 0, 0, 0};

// Validation assertion macros
#define VALID_ASSERT(condition, message) do { \
    stats.total_checks++; \
    if (condition) { \
        stats.passed_checks++; \
        printf("  ✓ %s\n", message); \
    } else { \
        stats.failed_checks++; \
        printf("  ❌ %s\n", message); \
    } \
} while(0)

#define VALID_WARN(condition, message) do { \
    stats.total_checks++; \
    if (condition) { \
        stats.passed_checks++; \
        printf("  ✓ %s\n", message); \
    } else { \
        stats.warnings++; \
        printf("  ⚠ %s (warning)\n", message); \
    } \
} while(0)

// File existence check
int file_exists(const char* filename) {
    struct stat st;
    return (stat(filename, &st) == 0);
}

// Directory existence check
int directory_exists(const char* dirname) {
    struct stat st;
    return (stat(dirname, &st) == 0 && S_ISDIR(st.st_mode));
}

// Check if file is executable
int file_executable(const char* filename) {
    struct stat st;
    return (stat(filename, &st) == 0 && (st.st_mode & S_IXUSR));
}

// Count files in directory
int count_files_in_directory(const char* dirname, const char* pattern) {
    DIR* dir = opendir(dirname);
    if (!dir) return -1;

    int count = 0;
    struct dirent* entry;
    while ((entry = readdir(dir)) != NULL) {
        if (pattern == NULL || strstr(entry->d_name, pattern) != NULL) {
            count++;
        }
    }
    closedir(dir);
    return count;
}

// Test file validation
int validate_test_file_structure(const char* filename, const char* expected_content) {
    FILE* file = fopen(filename, "r");
    if (!file) return 0;

    // Check if file has content
    fseek(file, 0, SEEK_END);
    long size = ftell(file);
    fseek(file, 0, SEEK_SET);

    if (size <= 0) {
        fclose(file);
        return 0;
    }

    // If specific content expected, check for it
    if (expected_content != NULL) {
        char* buffer = malloc(size + 1);
        if (!buffer) {
            fclose(file);
            return 0;
        }

        fread(buffer, 1, size, file);
        buffer[size] = '\0';
        fclose(file);

        int found = strstr(buffer, expected_content) != NULL;
        free(buffer);
        return found;
    }

    fclose(file);
    return 1;
}

// Validate test directory structure
int validate_directory_structure(void) {
    printf("Validating test directory structure\n");

    // Check main directories
    VALID_ASSERT(directory_exists("unit"), "Unit test directory exists");
    VALID_ASSERT(directory_exists("integration"), "Integration test directory exists");
    VALID_ASSERT(directory_exists("stress"), "Stress test directory exists");
    VALID_ASSERT(directory_exists("error"), "Error test directory exists");

    // Check for GitHub Actions workflow
    VALID_ASSERT(directory_exists(".github"), "GitHub directory exists");
    VALID_ASSERT(directory_exists(".github/workflows"), "GitHub workflows directory exists");

    return 0;
}

// Validate test files exist
int validate_test_files(void) {
    printf("Validating test files\n");

    // Unit test files
    VALID_ASSERT(file_exists("unit/test-memory-file.c"), "Memory file unit test exists");
    VALID_ASSERT(file_exists("unit/test-library-cache.c"), "Library cache unit test exists");

    // Integration test files
    VALID_ASSERT(file_exists("integration/test-real-gdsii-files.c"), "Integration test exists");

    // Stress test files
    VALID_ASSERT(file_exists("stress/test-large-files.c"), "Stress test exists");

    // Error test files
    VALID_ASSERT(file_exists("error/test-invalid-inputs.c"), "Error handling test exists");

    // Coverage analysis tool
    VALID_ASSERT(file_exists("test-coverage-analysis.c"), "Coverage analysis tool exists");

    return 0;
}

// Validate build system
int validate_build_system(void) {
    printf("Validating build system\n");

    // Check Makefile exists and has content
    VALID_ASSERT(file_exists("Makefile"), "Makefile exists");
    VALID_ASSERT(validate_test_file_structure("Makefile", "CC = gcc"), "Makefile has compiler configuration");
    VALID_ASSERT(validate_test_file_structure("Makefile", "test-all"), "Makefile has test targets");

    // Check test runner script
    VALID_ASSERT(file_exists("run-tests.sh"), "Test runner script exists");
    VALID_ASSERT(file_executable("run-tests.sh"), "Test runner script is executable");
    VALID_ASSERT(validate_test_file_structure("run-tests.sh", "#!/bin/bash"), "Test runner has proper shebang");

    return 0;
}

// Validate test content quality
int validate_test_content(void) {
    printf("Validating test content quality\n");

    // Check unit tests have proper structure
    VALID_WARN(validate_test_file_structure("unit/test-memory-file.c", "TEST_ASSERT"),
               "Memory file tests have assertions");
    VALID_WARN(validate_test_file_structure("unit/test-library-cache.c", "TEST_ASSERT"),
               "Library cache tests have assertions");

    // Check error handling tests cover edge cases
    VALID_WARN(validate_test_file_structure("error/test-invalid-inputs.c", "NULL"),
               "Error tests check NULL pointers");
    VALID_WARN(validate_test_file_structure("error/test-invalid-inputs.c", "invalid"),
               "Error tests check invalid inputs");

    // Check stress tests have performance measurement
    VALID_WARN(validate_test_file_structure("stress/test-large-files.c", "get_time"),
               "Stress tests have performance measurement");

    // Check integration tests handle real files
    VALID_WARN(validate_test_file_structure("integration/test-real-gdsii-files.c", "read_file"),
               "Integration tests handle file reading");

    return 0;
}

// Validate CI/CD configuration
int validate_cicd_configuration(void) {
    printf("Validating CI/CD configuration\n");

    // Check GitHub Actions workflow
    VALID_ASSERT(file_exists(".github/workflows/ci.yml"), "CI workflow file exists");
    VALID_WARN(validate_test_file_structure(".github/workflows/ci.yml", "build-and-test"),
               "CI workflow has build and test jobs");
    VALID_WARN(validate_test_file_structure(".github/workflows/ci.yml", "strategy:"),
               "CI workflow uses matrix strategy");
    VALID_WARN(validate_test_file_structure(".github/workflows/ci.yml", "ubuntu-latest"),
               "CI workflow specifies Ubuntu runner");

    return 0;
}

// Validate documentation
int validate_documentation(void) {
    printf("Validating documentation\n");

    // Check README exists and has content
    VALID_ASSERT(file_exists("README.md"), "README file exists");
    VALID_WARN(validate_test_file_structure("README.md", "# WASM GDSII Parser Test Suite"),
               "README has proper title");
    VALID_WARN(validate_test_file_structure("README.md", "## Quick Start"),
               "README has quick start section");

    return 0;
}

// Check for common issues
int validate_common_issues(void) {
    printf("Checking for common issues\n");

    // Check for hardcoded paths
    VALID_WARN(!validate_test_file_structure("Makefile", "/home/"),
               "Makefile doesn't have hardcoded paths");

    // Check for proper error handling
    VALID_WARN(validate_test_file_structure("run-tests.sh", "set -e"),
               "Test runner exits on errors");

    // Check for proper cleanup
    VALID_WARN(validate_test_file_structure("run-tests.sh", "cleanup"),
               "Test runner has cleanup function");

    // Check for logging functionality
    VALID_WARN(validate_test_file_structure("run-tests.sh", "log_"),
               "Test runner has logging functions");

    return 0;
}

// Test dependency availability
int validate_dependencies(void) {
    printf("Validating dependency availability\n");

    // Check for common build tools
    FILE* gcc_check = popen("gcc --version 2>/dev/null", "r");
    if (gcc_check) {
        char buffer[256];
        int has_gcc = (fgets(buffer, sizeof(buffer), gcc_check) != NULL);
        pclose(gcc_check);
        VALID_WARN(has_gcc, "GCC compiler is available");
    } else {
        VALID_WARN(0, "GCC compiler check failed");
    }

    FILE* make_check = popen("make --version 2>/dev/null", "r");
    if (make_check) {
        char buffer[256];
        int has_make = (fgets(buffer, sizeof(buffer), make_check) != NULL);
        pclose(make_check);
        VALID_WARN(has_make, "Make utility is available");
    } else {
        VALID_WARN(0, "Make utility check failed");
    }

    return 0;
}

// Generate validation report
void generate_validation_report(void) {
    printf("\n=== Test System Validation Report ===\n\n");
    printf("Total checks: %d\n", stats.total_checks);
    printf("Passed checks: %d\n", stats.passed_checks);
    printf("Failed checks: %d\n", stats.failed_checks);
    printf("Warnings: %d\n", stats.warnings);

    if (stats.failed_checks == 0) {
        printf("\n🎉 Test system validation passed!\n");
        printf("The comprehensive test suite is properly configured.\n");
    } else {
        printf("\n❌ Test system validation failed!\n");
        printf("Please address the %d failed checks before proceeding.\n", stats.failed_checks);
    }

    if (stats.warnings > 0) {
        printf("\n⚠ %d warnings detected. Consider addressing these for optimal test coverage.\n", stats.warnings);
    }

    double success_rate = (double)stats.passed_checks / stats.total_checks * 100.0;
    printf("\nValidation success rate: %.1f%%\n", success_rate);

    // Recommendations
    printf("\n=== Recommendations ===\n");
    if (stats.failed_checks > 0) {
        printf("1. Fix all failed checks before running the test suite\n");
        printf("2. Ensure all required files are present and properly configured\n");
        printf("3. Verify build tools are installed and accessible\n");
    }
    if (stats.warnings > 0) {
        printf("4. Address warnings to improve test quality and coverage\n");
    }
    if (stats.failed_checks == 0 && stats.warnings == 0) {
        printf("✓ Test system is ready for use!\n");
        printf("✓ Run './run-tests.sh' to execute the full test suite\n");
        printf("✓ Run 'make test-quick' for rapid development testing\n");
    }
}

int main(void) {
    printf("=== WASM GDSII Parser Test System Validation ===\n\n");
    printf("This tool validates that the comprehensive test suite is properly set up.\n\n");

    // Run all validation checks
    validate_directory_structure();
    printf("\n");

    validate_test_files();
    printf("\n");

    validate_build_system();
    printf("\n");

    validate_test_content();
    printf("\n");

    validate_cicd_configuration();
    printf("\n");

    validate_documentation();
    printf("\n");

    validate_common_issues();
    printf("\n");

    validate_dependencies();
    printf("\n");

    // Generate final report
    generate_validation_report();

    return (stats.failed_checks == 0) ? 0 : 1;
}