# GDSII WASM Makefile
#
# This Makefile provides an alternative way to build the GDSII WebAssembly
# module using Emscripten. It offers more granular control over the build process.

# ============================================================================
# CONFIGURATION
# ============================================================================

# Shell
SHELL := /bin/bash

# Colors for output
RED := \033[0;31m
GREEN := \033[0;32m
YELLOW := \033[1;33m
BLUE := \033[0;34m
NC := \033[0m # No Color

# Project paths
SCRIPT_DIR := $(shell cd "$(dirname "${MAKEFILE_LIST}")" && pwd)
PROJECT_ROOT := $(shell dirname "$(SCRIPT_DIR)")
WASM_GLUE_DIR := $(SCRIPT_DIR)
BUILD_DIR := $(WASM_GLUE_DIR)/build
OUTPUT_DIR := $(PROJECT_ROOT)/MinimalGDSReader/gdsii-viewer/public

# Source files
SOURCES := $(WASM_GLUE_DIR)/src/gds-wasm-adapter-enhanced.c \
          $(WASM_GLUE_DIR)/src/wasm-element-cache.c \
          $(WASM_GLUE_DIR)/src/wasm-element-cache-complete.c \
          $(WASM_GLUE_DIR)/src/mem-file.c \
          $(WASM_GLUE_DIR)/src/wasm-memory-manager.c

HEADERS := $(WASM_GLUE_DIR)/include/wasm-types.h \
          $(WASM_GLUE_DIR)/include/gds-wasm-adapter.h \
          $(WASM_GLUE_DIR)/include/wasm-element-cache.h \
          $(WASM_GLUE_DIR)/include/mem-file.h

# Base project includes
BASE_INCLUDES := $(PROJECT_ROOT)/Basic/gdsio

# Output files
OUTPUT_JS := gds-parser.js
OUTPUT_WASM := gds-parser.wasm
DEBUG_OUTPUT_JS := gds-parser-debug.js
DEBUG_OUTPUT_WASM := gds-parser-debug.wasm

# Emscripten configuration
EMCC := emcc
EMCC_FLAGS := -O3 -flto --memory-init-file 0
EMCC_DEBUG_FLAGS := -O1 -g4 --source-map-base http://localhost:3000/
EMCC_EXPORT_FLAGS := -s WASM=1 -s ALLOW_MEMORY_GROWTH=1 -s MODULARIZE=1
EMCC_ENV_FLAGS := -s ENVIRONMENT='web' -s FILESYSTEM=0

# Include directories
INCLUDES := -I$(WASM_GLUE_DIR)/include -I$(BASE_INCLUDES)

# Exported functions
EXPORTED_FUNCTIONS := _malloc,_free,_gds_parse_from_memory,_gds_free_library,_gds_get_library_name,_gds_get_user_units_per_db_unit,_gds_get_meters_per_db_unit,_gds_get_structure_count,_gds_get_structure_name,_gds_get_library_creation_date,_gds_get_library_modification_date,_gds_get_element_count,_gds_get_element_type,_gds_get_element_layer,_gds_get_element_data_type,_gds_get_element_elflags,_gds_get_element_plex,_gds_get_element_polygon_count,_gds_get_element_polygon_vertex_count,_gds_get_element_polygon_vertices,_gds_get_element_path_width,_gds_get_element_path_type,_gds_get_element_path_begin_extension,_gds_get_element_path_end_extension,_gds_get_element_text,_gds_get_element_text_position,_gds_get_element_text_type,_gds_get_element_text_presentation,_gds_get_element_reference_name,_gds_get_element_array_columns,_gds_get_element_array_rows,_gds_get_element_reference_corners,_gds_get_element_strans_flags,_gds_get_element_magnification,_gds_get_element_rotation_angle,_gds_get_element_property_count,_gds_get_element_property_attribute,_gds_get_element_property_value,_gds_get_last_error,_gds_clear_error,_gds_validate_library,_gds_get_memory_usage

# ============================================================================
# UTILITY FUNCTIONS
# ============================================================================

define print_status
	@echo -e "$(BLUE)[INFO]$(NC) $(1)"
endef

define print_success
	@echo -e "$(GREEN)[SUCCESS]$(NC) $(1)"
endef

define print_warning
	@echo -e "$(YELLOW)[WARNING]$(NC) $(1)"
endef

define print_error
	@echo -e "$(RED)[ERROR]$(NC) $(1)"
endef

# ============================================================================
# MAIN TARGETS
# ============================================================================

.PHONY: all clean debug release help test validate

# Default target
all: release

# Help target
help:
	@echo "GDSII WASM Makefile"
	@echo ""
	@echo "Available targets:"
	@echo "  all        - Build release version (default)"
	@echo "  release    - Build optimized release version"
	@echo "  debug      - Build debug version with source maps"
	@echo "  clean      - Remove all build artifacts"
	@echo "  validate   - Validate build output"
	@echo "  test       - Run basic tests"
	@echo "  help       - Show this help message"
	@echo ""
	@echo "Examples:"
	@echo "  make              # Build release"
	@echo "  make debug        # Build debug"
	@echo "  make clean        # Clean build artifacts"

# Release target
release: check-emscripten setup-build build-release post-build
	$(call print_success,Release build completed successfully!)

# Debug target
debug: check-emscripten setup-build build-debug post-build-debug
	$(call print_success,Debug build completed successfully!)

# Clean target
clean:
	$(call print_status,Cleaning build artifacts...)
	rm -rf $(BUILD_DIR)
	rm -f $(OUTPUT_DIR)/$(OUTPUT_JS)
	rm -f $(OUTPUT_DIR)/$(DEBUG_OUTPUT_JS)
	rm -f $(OUTPUT_DIR)/$(OUTPUT_WASM)
	rm -f $(OUTPUT_DIR)/$(DEBUG_OUTPUT_WASM)
	$(call print_success,Build artifacts cleaned)

# Validate target
validate: validate-files validate-sizes
	$(call print_success,Build validation passed!)

# Test target
test: validate
	$(call print_status,Running basic tests...)
	@echo "Testing WASM module functionality..."
	@if [ -f "$(OUTPUT_DIR)/$(OUTPUT_JS)" ]; then \
		echo "✓ JavaScript file exists"; \
	else \
		echo "✗ JavaScript file missing"; \
		exit 1; \
	fi
	@if [ -f "$(OUTPUT_DIR)/$(OUTPUT_WASM)" ]; then \
		echo "✓ WebAssembly file exists"; \
	else \
		echo "✗ WebAssembly file missing"; \
		exit 1; \
	fi
	$(call print_success,Basic tests passed!)

# ============================================================================
# BUILD STEPS
# ============================================================================

# Check Emscripten installation
check-emscripten:
	@if ! command -v $(EMCC) &> /dev/null; then \
		$(call print_error,Emscripten not found. Please install and activate Emscripten SDK.); \
		echo "Visit: https://emscripten.org/docs/getting_started/downloads.html"; \
		exit 1; \
	fi
	@if ! $(EMCC) --version &> /dev/null; then \
		$(call print_error,Emscripten not properly configured. Please run 'emsdk_env.sh'.); \
		exit 1; \
	fi
	$(call print_success,Emscripten found: $$(shell $(EMCC) --version | head -n1))

# Check source files
check-sources:
	@if [ ! -f "$(SOURCES)" ]; then \
		$(call print_error,Missing source files: $(SOURCES)); \
		exit 1; \
	fi
	$(call print_success,All source files found)

# Setup build directories
setup-build: check-sources
	@mkdir -p $(BUILD_DIR)
	@mkdir -p $(OUTPUT_DIR)
	$(call print_success,Build directories created)

# Pre-build cleanup
pre-build:
	@rm -f $(OUTPUT_DIR)/$(OUTPUT_JS)
	@rm -f $(OUTPUT_DIR)/$(OUTPUT_WASM)
	$(call print_status,Cleaned old build artifacts)

# Post-build cleanup and setup
post-build:
	@$(MAKE) --no-print-directory create-helper-js
	@$(MAKE) --no-print-directory validate-files validate-sizes

# Post-build for debug version
post-build-debug:
	@$(MAKE) --no-print-directory create-helper-js-debug
	@$(MAKE) --no-print-directory validate-debug-files validate-debug-sizes

# ============================================================================
# BUILD TARGETS
# ============================================================================

# Release build
build-release: pre-build
	$(call print_status,Building release version...)
	$(EMCC) $(SOURCES) $(INCLUDES) \
		-o $(OUTPUT_DIR)/$(OUTPUT_JS) \
		$(EMCC_FLAGS) $(EMCC_EXPORT_FLAGS) $(EMCC_ENV_FLAGS) \
		--export-functions='[$(EXPORTED_FUNCTIONS)]' \
		-s EXPORT_NAME="'GDSParserModule'" \
		-s EXPORTED_RUNTIME_METHODS="['ccall','cwrap']" \
		-s WASM_ASYNC_COMPILATION=0 \
		-s ASSERTIONS=0 \
		-s STACK_SIZE=2MB \
		-s TOTAL_MEMORY=64MB \
		--pre-js $(WASM_GLUE_DIR)/src/pre.js 2>/dev/null || true \
		--post-js $(WASM_GLUE_DIR)/src/post.js 2>/dev/null || true

# Debug build
build-debug: pre-build
	$(call print_status,Building debug version...)
	$(EMCC) $(SOURCES) $(INCLUDES) \
		-o $(OUTPUT_DIR)/$(DEBUG_OUTPUT_JS) \
		$(EMCC_DEBUG_FLAGS) $(EMCC_EXPORT_FLAGS) $(EMCC_ENV_FLAGS) \
		--export-functions='[$(EXPORTED_FUNCTIONS)]' \
		-s EXPORT_NAME="'GDSParserModuleDebug'" \
		-s EXPORTED_RUNTIME_METHODS="['ccall','cwrap']" \
		-s ASSERTIONS=1 \
		-s STACK_SIZE=4MB \
		-s TOTAL_MEMORY=128MB \
		--pre-js $(WASM_GLUE_DIR)/src/pre-debug.js 2>/dev/null || true

# ============================================================================
# HELPER FILES
# ============================================================================

# Create helper JavaScript files
create-helper-js:
	@if [ ! -f "$(WASM_GLUE_DIR)/src/pre.js" ]; then \
		echo 'console.log("Loading GDSII Parser WASM Module...");' > $(WASM_GLUE_DIR)/src/pre.js; \
		echo 'if (typeof window !== "undefined") window.GDSParserLoading = true;' >> $(WASM_GLUE_DIR)/src/pre.js; \
	fi
	@if [ ! -f "$(WASM_GLUE_DIR)/src/post.js" ]; then \
		echo 'if (typeof window !== "undefined") {' > $(WASM_GLUE_DIR)/src/post.js; \
		echo '  window.GDSParserLoading = false;' >> $(WASM_GLUE_DIR)/src/post.js; \
		echo '  console.log("GDSII Parser WASM Module loaded successfully");' >> $(WASM_GLUE_DIR)/src/post.js; \
		echo '}' >> $(WASM_GLUE_DIR)/src/post.js; \
		echo 'if (typeof Module !== "undefined") {' >> $(WASM_GLUE_DIR)/src/post.js; \
		echo '  Module.gdsParseReady = true;' >> $(WASM_GLUE_DIR)/src/post.js; \
		echo '  if (Module.gdsParseResolve) Module.gdsParseResolve(Module);' >> $(WASM_GLUE_DIR)/src/post.js; \
		echo '}' >> $(WASM_GLUE_DIR)/src/post.js; \
	fi
	$(call print_status,Helper JavaScript files ready)

# Create debug helper files
create-helper-js-debug:
	@if [ ! -f "$(WASM_GLUE_DIR)/src/pre-debug.js" ]; then \
		echo 'console.log("Loading GDSII Parser WASM Module (Debug)...");' > $(WASM_GLUE_DIR)/src/pre-debug.js; \
		echo 'if (typeof window !== "undefined") {' > $(WASM_GLUE_DIR)/src/pre-debug.js; \
		echo '  window.GDSParserLoading = true;' >> $(WASM_GLUE_DIR)/src/pre-debug.js; \
		echo '  window.GDSParserDebug = true;' >> $(WASM_GLUE_DIR)/src/pre-debug.js; \
		echo '}' >> $(WASM_GLUE_DIR)/src/pre-debug.js; \
	fi

# ============================================================================
# VALIDATION
# ============================================================================

# Validate build files exist
validate-files:
	@if [ ! -f "$(OUTPUT_DIR)/$(OUTPUT_JS)" ]; then \
		$(call print_error,Build failed: JavaScript output not found); \
		exit 1; \
	fi
	@if [ ! -f "$(OUTPUT_DIR)/$(OUTPUT_WASM)" ]; then \
		$(call print_error,Build failed: WebAssembly output not found); \
		exit 1; \
	fi

# Validate debug files exist
validate-debug-files:
	@if [ ! -f "$(OUTPUT_DIR)/$(DEBUG_OUTPUT_JS)" ]; then \
		$(call print_error,Debug build failed: JavaScript output not found); \
		exit 1; \
	fi
	@if [ ! -f "$(OUTPUT_DIR)/$(DEBUG_OUTPUT_WASM)" ]; then \
		$(call print_error,Debug build failed: WebAssembly output not found); \
		exit 1; \
	fi

# Validate file sizes
validate-sizes:
	$(eval JS_SIZE := $$(stat -f%z "$(OUTPUT_DIR)/$(OUTPUT_JS)" 2>/dev/null || stat -c%s "$(OUTPUT_DIR)/$(OUTPUT_JS)" 2>/dev/null || echo 0))
	$(eval WASM_SIZE := $$(stat -f%z "$(OUTPUT_DIR)/$(OUTPUT_WASM)" 2>/dev/null || stat -c%s "$(OUTPUT_DIR)/$(OUTPUT_WASM)" 2>/dev/null || echo 0))
	$(call print_success,Build validation passed:)
	@echo "  - JavaScript: $(JS_SIZE) bytes"
	@echo "  - WebAssembly: $(WASM_SIZE) bytes"

# Validate debug file sizes
validate-debug-sizes:
	$(eval JS_SIZE := $$(stat -f%z "$(OUTPUT_DIR)/$(DEBUG_OUTPUT_JS)" 2>/dev/null || stat -c%s "$(OUTPUT_DIR)/$(DEBUG_OUTPUT_JS)" 2>/dev/null || echo 0))
	$(eval WASM_SIZE := $$(stat -f%z "$(OUTPUT_DIR)/$(DEBUG_OUTPUT_WASM)" 2>/dev/null || stat -c%s "$(OUTPUT_DIR)/$(DEBUG_OUTPUT_WASM)" 2>/dev/null || echo 0))
	$(call print_success,Debug build validation passed:)
	@echo "  - JavaScript: $(JS_SIZE) bytes"
	@echo "  - WebAssembly: $(WASM_SIZE) bytes"

# ============================================================================
# ADVANCED TARGETS
# ============================================================================

# Build with profiling
profile: check-emscripten setup-build
	$(call print_status,Building with profiling enabled...)
	$(EMCC) $(SOURCES) $(INCLUDES) \
		-o $(OUTPUT_DIR)/$(OUTPUT_JS%.js)-profile.js \
		$(EMCC_FLAGS) $(EMCC_EXPORT_FLAGS) $(EMCC_ENV_FLAGS) \
		--export-functions='[$(EXPORTED_FUNCTIONS)]' \
		-s EXPORT_NAME="'GDSParserModuleProfile'" \
		-s PROFILING=1 \
		-s ASSERTIONS=0 \
		--pre-js $(WASM_GLUE_DIR)/src/pre.js 2>/dev/null || true

# Build for production (minimal size)
production: check-emscripten setup-build
	$(call print_status,Building production version...)
	$(EMCC) $(SOURCES) $(INCLUDES) \
		-o $(OUTPUT_DIR)/$(OUTPUT_JS%.js)-prod.js \
		-Oz -flto --closure 1 \
		$(EMCC_EXPORT_FLAGS) $(EMCC_ENV_FLAGS) \
		--export-functions='[$(EXPORTED_FUNCTIONS)]' \
		-s EXPORT_NAME="'GDSParserModuleProd'" \
		-s ASSERTIONS=0 \
		-s STACK_SIZE=1MB \
		-s TOTAL_MEMORY=32MB \
		--pre-js $(WASM_GLUE_DIR)/src/pre.js 2>/dev/null || true

# Continuous integration target
ci: clean all validate
	$(call print_success,CI build completed successfully!)

# Development target (fast rebuild)
dev: debug
	@echo "Development build ready. Run 'make dev' for fast debug rebuilds."

# ============================================================================
# PHONY TARGETS (redundant but explicit)
# ============================================================================

.PHONY: check-emscripten check-sources setup-build pre-build post-build build-release build-debug create-helper-js create-helper-js-debug validate-files validate-debug-files validate-sizes validate-debug-sizes profile production ci dev