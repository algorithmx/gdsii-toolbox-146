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
# Output directory for the generated WASM/JS bundle
# Use the actual viewer folder in this repository
OUTPUT_DIR := $(PROJECT_ROOT)/gdsii-viewer/public

# Source files
SOURCES := $(WASM_GLUE_DIR)/src/gds-wasm-adapter.c \
          $(WASM_GLUE_DIR)/src/wasm-element-cache.c \
          $(WASM_GLUE_DIR)/src/wasm-memory-manager.c

HEADERS := $(WASM_GLUE_DIR)/include/gds-wasm-adapter.h \
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
EMCC_FLAGS := -O3 -flto
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
	echo -e "$(BLUE)[INFO]$(NC) $(1)"
endef

define print_success
	echo -e "$(GREEN)[SUCCESS]$(NC) $(1)"
endef

define print_warning
	echo -e "$(YELLOW)[WARNING]$(NC) $(1)"
endef

define print_error
	echo -e "$(RED)[ERROR]$(NC) $(1)"
endef

# ============================================================================
# MAIN TARGETS
# ============================================================================

.PHONY: all clean debug release help test validate clean-all distclean check-deps

# Default target
all: release

# Help target
help:
	@echo -e "$(BLUE)GDSII WASM Build System$(NC)"
	@echo -e "$(BLUE)======================$(NC)"
	@echo ""
	@echo -e "$(GREEN)Available targets:$(NC)"
	@echo -e "  $(YELLOW)all$(NC)        - Build release version (default)"
	@echo -e "  $(YELLOW)release$(NC)    - Build optimized release version"
	@echo -e "  $(YELLOW)debug$(NC)      - Build debug version with source maps"
	@echo -e "  $(YELLOW)clean$(NC)      - Remove build artifacts"
	@echo -e "  $(YELLOW)clean-all$(NC)  - Remove all build artifacts and caches"
	@echo -e "  $(YELLOW)distclean$(NC)  - Complete clean including dependencies"
	@echo -e "  $(YELLOW)validate$(NC)   - Validate build outputs"
	@echo -e "  $(YELLOW)help$(NC)       - Show this help message"
	@echo ""
	@echo -e "$(GREEN)Build outputs:$(NC)"
	@echo -e "  Release: $(OUTPUT_DIR)/$(OUTPUT_JS)"
	@echo -e "  Debug:   $(OUTPUT_DIR)/$(OUTPUT_JS_DEBUG)"
	@echo ""

# Validation target
validate:
	@echo -e "$(BLUE)[INFO]$(NC) Validating build outputs..."
	@if [ -f "$(OUTPUT_DIR)/$(OUTPUT_JS)" ]; then \
		echo -e "$(GREEN)[✓]$(NC) Release build: $(OUTPUT_JS) exists"; \
		ls -lh "$(OUTPUT_DIR)/$(OUTPUT_JS)"; \
	else \
		echo -e "$(RED)[✗]$(NC) Release build: $(OUTPUT_JS) missing"; \
	fi
	@if [ -f "$(OUTPUT_DIR)/gds-parser.wasm" ]; then \
		echo -e "$(GREEN)[✓]$(NC) Release WASM: gds-parser.wasm exists"; \
		ls -lh "$(OUTPUT_DIR)/gds-parser.wasm"; \
	else \
		echo -e "$(RED)[✗]$(NC) Release WASM: gds-parser.wasm missing"; \
	fi
	@if [ -f "$(OUTPUT_DIR)/$(OUTPUT_JS_DEBUG)" ]; then \
		echo -e "$(GREEN)[✓]$(NC) Debug build: $(OUTPUT_JS_DEBUG) exists"; \
		ls -lh "$(OUTPUT_DIR)/$(OUTPUT_JS_DEBUG)"; \
	else \
		echo -e "$(YELLOW)[!]$(NC) Debug build: $(OUTPUT_JS_DEBUG) not built"; \
	fi

# More thorough clean
clean-all: clean
	@echo -e "$(BLUE)[INFO]$(NC) Performing deep clean..."
	@# Remove any node_modules or package-lock.json that might have been created
	@if [ -d "node_modules" ]; then \
		echo -e "$(YELLOW)[CLEAN]$(NC) Removing node_modules"; \
		rm -rf node_modules; \
	fi
	@if [ -f "package-lock.json" ]; then \
		echo -e "$(YELLOW)[CLEAN]$(NC) Removing package-lock.json"; \
		rm -f package-lock.json; \
	fi
	@# Remove any temporary or editor files
	@find $(WASM_GLUE_DIR) -name ".DS_Store" -delete 2>/dev/null || true
	@find $(WASM_GLUE_DIR) -name "Thumbs.db" -delete 2>/dev/null || true
	@echo -e "$(GREEN)[SUCCESS]$(NC) Deep clean completed"

# Distribution clean - removes everything
distclean: clean-all
	@echo -e "$(BLUE)[INFO]$(NC) Performing distribution clean..."
	@# This would remove any generated configuration files if they existed
	@echo -e "$(GREEN)[SUCCESS]$(NC) Distribution clean completed"

# ============================================================================
# BUILD CONFIGURATION (consolidated)
# ============================================================================

# Emscripten flags
COMMON_FLAGS := -s WASM=1 -s ALLOW_MEMORY_GROWTH=1 -s MODULARIZE=1 -s ENVIRONMENT='web' -s FILESYSTEM=0 -s EXPORTED_RUNTIME_METHODS="['ccall','cwrap','HEAP8','HEAPU8','HEAP16','HEAPU16','HEAP32','HEAPU32','HEAPF32','HEAPF64']"
RELEASE_FLAGS := -O3 -flto -s WASM_ASYNC_COMPILATION=0 -s ASSERTIONS=0 -s STACK_SIZE=2097152 -s INITIAL_MEMORY=67108864
DEBUG_FLAGS := -O1 -g4 --source-map-base http://localhost:3000/ -s ASSERTIONS=1 -s STACK_SIZE=4194304 -s INITIAL_MEMORY=134217728

# Output file names
OUTPUT_JS_DEBUG := gds-parser-debug.js

# ============================================================================
# BUILD TARGETS
# ============================================================================

# Check dependencies
check-deps:
	@echo -e "$(BLUE)[INFO]$(NC) Checking build dependencies..."
	@which emcc > /dev/null 2>&1 || (echo -e "$(RED)[ERROR]$(NC) Emscripten (emcc) not found. Please install Emscripten." && exit 1)
	@echo -e "$(GREEN)[✓]$(NC) Emscripten found: $$(emcc --version | head -1)"
	@test -d "$(PROJECT_ROOT)/Basic/gdsio" || (echo -e "$(RED)[ERROR]$(NC) Basic/gdsio directory not found." && exit 1)
	@echo -e "$(GREEN)[✓]$(NC) Basic/gdsio directory found"
	@echo -e "$(GREEN)[SUCCESS]$(NC) All dependencies satisfied"

release: check-deps
	@echo -e "$(BLUE)[INFO]$(NC) Building release version..."
	@mkdir -p $(OUTPUT_DIR)
	@[ -f $(WASM_GLUE_DIR)/src/pre.js ] || echo "console.log('Loading GDSII Parser WASM Module...');" > $(WASM_GLUE_DIR)/src/pre.js
	@[ -f $(WASM_GLUE_DIR)/src/post.js ] || echo "if (typeof window!=='undefined'){console.log('GDSII Parser WASM Module loaded');}" > $(WASM_GLUE_DIR)/src/post.js
	@echo -e "$(BLUE)[INFO]$(NC) Compiling release WASM module..."
	$(EMCC) $(SOURCES) $(INCLUDES) -o $(OUTPUT_DIR)/$(OUTPUT_JS) \
		$(COMMON_FLAGS) $(RELEASE_FLAGS) \
		-s EXPORTED_FUNCTIONS='[$(EXPORTED_FUNCTIONS)]' \
		-s EXPORT_NAME="'GDSParserModule'" \
		--pre-js $(WASM_GLUE_DIR)/src/pre.js \
		--post-js $(WASM_GLUE_DIR)/src/post.js
	@echo -e "$(GREEN)[SUCCESS]$(NC) Release build completed: $(OUTPUT_DIR)/$(OUTPUT_JS)"

debug: check-deps
	@echo -e "$(BLUE)[INFO]$(NC) Building debug version..."
	@mkdir -p $(OUTPUT_DIR)
	@[ -f $(WASM_GLUE_DIR)/src/pre-debug.js ] || echo "console.log('Loading GDSII Parser WASM Module (Debug)...');" > $(WASM_GLUE_DIR)/src/pre-debug.js
	@echo -e "$(BLUE)[INFO]$(NC) Compiling debug WASM module..."
	$(EMCC) $(SOURCES) $(INCLUDES) -o $(OUTPUT_DIR)/$(OUTPUT_JS_DEBUG) \
		$(COMMON_FLAGS) $(DEBUG_FLAGS) \
		-s EXPORTED_FUNCTIONS='[$(EXPORTED_FUNCTIONS)]' \
		-s EXPORT_NAME="'GDSParserModuleDebug'" \
		--pre-js $(WASM_GLUE_DIR)/src/pre-debug.js
	@echo -e "$(GREEN)[SUCCESS]$(NC) Debug build completed: $(OUTPUT_DIR)/$(OUTPUT_JS_DEBUG)" \
		-s EXPORT_NAME="'GDSParserModuleDebug'" \
		--pre-js $(WASM_GLUE_DIR)/src/pre-debug.js

clean:
	@echo -e "$(BLUE)[INFO]$(NC) Cleaning WASM build artifacts..."
	@# Remove main output files
	@if [ -f "$(OUTPUT_DIR)/$(OUTPUT_JS)" ]; then \
		echo -e "$(YELLOW)[CLEAN]$(NC) Removing $(OUTPUT_JS)"; \
		rm -f "$(OUTPUT_DIR)/$(OUTPUT_JS)"; \
	fi
	@if [ -f "$(OUTPUT_DIR)/$(OUTPUT_JS_DEBUG)" ]; then \
		echo -e "$(YELLOW)[CLEAN]$(NC) Removing $(OUTPUT_JS_DEBUG)"; \
		rm -f "$(OUTPUT_DIR)/$(OUTPUT_JS_DEBUG)"; \
	fi
	@# Remove WASM files
	@if [ -f "$(OUTPUT_DIR)/gds-parser.wasm" ]; then \
		echo -e "$(YELLOW)[CLEAN]$(NC) Removing gds-parser.wasm"; \
		rm -f "$(OUTPUT_DIR)/gds-parser.wasm"; \
	fi
	@if [ -f "$(OUTPUT_DIR)/gds-parser-debug.wasm" ]; then \
		echo -e "$(YELLOW)[CLEAN]$(NC) Removing gds-parser-debug.wasm"; \
		rm -f "$(OUTPUT_DIR)/gds-parser-debug.wasm"; \
	fi
	@# Remove source maps
	@if [ -f "$(OUTPUT_DIR)/gds-parser.wasm.map" ]; then \
		echo -e "$(YELLOW)[CLEAN]$(NC) Removing gds-parser.wasm.map"; \
		rm -f "$(OUTPUT_DIR)/gds-parser.wasm.map"; \
	fi
	@if [ -f "$(OUTPUT_DIR)/gds-parser-debug.wasm.map" ]; then \
		echo -e "$(YELLOW)[CLEAN]$(NC) Removing gds-parser-debug.wasm.map"; \
		rm -f "$(OUTPUT_DIR)/gds-parser-debug.wasm.map"; \
	fi
	@# Remove temporary JS files
	@if [ -f "$(WASM_GLUE_DIR)/src/pre.js" ]; then \
		echo -e "$(YELLOW)[CLEAN]$(NC) Removing temporary pre.js"; \
		rm -f "$(WASM_GLUE_DIR)/src/pre.js"; \
	fi
	@if [ -f "$(WASM_GLUE_DIR)/src/post.js" ]; then \
		echo -e "$(YELLOW)[CLEAN]$(NC) Removing temporary post.js"; \
		rm -f "$(WASM_GLUE_DIR)/src/post.js"; \
	fi
	@if [ -f "$(WASM_GLUE_DIR)/src/pre-debug.js" ]; then \
		echo -e "$(YELLOW)[CLEAN]$(NC) Removing temporary pre-debug.js"; \
		rm -f "$(WASM_GLUE_DIR)/src/pre-debug.js"; \
	fi
	@# Clean build directory if it exists
	@if [ -d "$(BUILD_DIR)" ]; then \
		echo -e "$(YELLOW)[CLEAN]$(NC) Cleaning build directory"; \
		rm -rf "$(BUILD_DIR)"/*; \
	fi
	@# Remove any Emscripten cache files in current directory
	@if [ -f ".emscripten_cache" ]; then \
		echo -e "$(YELLOW)[CLEAN]$(NC) Removing Emscripten cache"; \
		rm -rf .emscripten_cache; \
	fi
	@# Remove any backup files
	@find $(WASM_GLUE_DIR) -name "*.bak" -type f -delete 2>/dev/null || true
	@find $(WASM_GLUE_DIR) -name "*~" -type f -delete 2>/dev/null || true
	@echo -e "$(GREEN)[SUCCESS]$(NC) Clean completed successfully"