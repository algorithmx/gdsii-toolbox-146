#!/bin/bash

# GDSII WASM Build Script
#
# This script compiles the C/C++ GDSII parsing code with Emscripten
# to generate WebAssembly modules for the TypeScript viewer.

set -e  # Exit on any error

# ============================================================================
# CONFIGURATION
# ============================================================================

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Project paths
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(dirname "$SCRIPT_DIR")"
WASM_GLUE_DIR="$SCRIPT_DIR"
BUILD_DIR="$WASM_GLUE_DIR/build"
OUTPUT_DIR="$PROJECT_ROOT/MinimalGDSReader/gdsii-viewer/public"

# Source file paths
WRAPPER_C="$WASM_GLUE_DIR/src/wrapper.c"
GDS_ADAPTER_C="$WASM_GLUE_DIR/src/gds-wasm-adapter.c"
WASM_TYPES_H="$WASM_GLUE_DIR/include/wasm-types.h"
GDS_ADAPTER_H="$WASM_GLUE_DIR/include/gds-wasm-adapter.h"

# Base project paths (adjust as needed)
BASE_BASIC_DIR="$PROJECT_ROOT/Basic/gdsio"
BASE_INCLUDES="$BASE_BASIC_DIR"

# Output files
OUTPUT_JS="gds-parser.js"
OUTPUT_WASM="gds-parser.wasm"

# Compiler flags
EMCC_FLAGS="-O3 -flto"
EMCC_DEBUG_FLAGS="-O1 -g4 --source-map-base http://localhost:3000/"
EMCC_EXPORT_FLAGS="-s WASM=1 -s ALLOW_MEMORY_GROWTH=1 -s MODULARIZE=1"
EMCC_ENV_FLAGS="-s ENVIRONMENT='web' -s FILESYSTEM=0"
EMCC_MEMORY_FLAGS="-s INITIAL_MEMORY=64MB -s MAXIMUM_MEMORY=1GB -s STACK_SIZE=2MB"

# ============================================================================
# FUNCTIONS
# ============================================================================

print_status() {
    echo -e "${BLUE}[INFO]${NC} $1"
}

print_success() {
    echo -e "${GREEN}[SUCCESS]${NC} $1"
}

print_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

print_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

check_emscripten() {
    if ! command -v emcc &> /dev/null; then
        print_error "Emscripten not found. Please install and activate Emscripten SDK."
        echo "Visit: https://emscripten.org/docs/getting_started/downloads.html"
        exit 1
    fi

    # Test if emcc is properly configured
    if ! emcc --version &> /dev/null; then
        print_error "Emscripten not properly configured. Please run 'emsdk_env.sh'."
        exit 1
    fi

    print_success "Emscripten found: $(emcc --version | head -n1)"
}

check_source_files() {
    local missing_files=()

    if [[ ! -f "$WRAPPER_C" ]]; then
        missing_files+=("$WRAPPER_C")
    fi

    if [[ ! -f "$WASM_TYPES_H" ]]; then
        missing_files+=("$WASM_TYPES_H")
    fi

    if [[ ! -f "$GDS_ADAPTER_C" ]]; then
        missing_files+=("$GDS_ADAPTER_C")
    fi

    if [[ ! -f "$GDS_ADAPTER_H" ]]; then
        missing_files+=("$GDS_ADAPTER_H")
    fi

    if [[ ${#missing_files[@]} -gt 0 ]]; then
        print_error "Missing source files:"
        for file in "${missing_files[@]}"; do
            echo "  - $file"
        done
        exit 1
    fi

    print_success "Required source files found (GDSII adapter included)"
}

create_build_directory() {
    mkdir -p "$BUILD_DIR"
    mkdir -p "$OUTPUT_DIR"
    print_success "Build directories created"
}

cleanup_old_files() {
    if [[ -f "$OUTPUT_DIR/$OUTPUT_JS" ]]; then
        rm "$OUTPUT_DIR/$OUTPUT_JS"
        print_status "Removed old JavaScript output"
    fi

    if [[ -f "$OUTPUT_DIR/$OUTPUT_WASM" ]]; then
        rm "$OUTPUT_DIR/$OUTPUT_WASM"
        print_status "Removed old WebAssembly output"
    fi
}

# ============================================================================
# BUILD FUNCTIONS
# ============================================================================

build_release() {
    print_status "Building release version..."

    # Complete list of exported functions
    local exported_functions=(
        "_malloc"
        "_free"
        "_gds_parse_from_memory"
        "_gds_free_library"
        "_gds_get_library_name"
        "_gds_get_user_units_per_db_unit"
        "_gds_get_meters_per_db_unit"
        "_gds_get_structure_count"
        "_gds_get_structure_name"
        "_gds_get_element_count"
        "_gds_get_reference_count"
        "_gds_get_element_type"
        "_gds_get_element_layer"
        "_gds_get_element_data_type"
        "_gds_get_element_polygon_count"
        "_gds_get_element_polygon_vertex_count"
        "_gds_get_element_polygon_vertices"
        "_gds_get_element_text"
        "_gds_get_element_text_position"
        "_gds_get_element_text_presentation"
        "_gds_get_element_reference_name"
        "_gds_get_element_array_columns"
        "_gds_get_element_array_rows"
        "_gds_get_element_property_count"
        "_gds_get_element_property_attribute"
        "_gds_get_element_property_value"
        "_gds_get_element_bounds"
        "_gds_get_structure_bounds"
        "_gds_get_last_error"
        "_gds_clear_error"
        "_gds_validate_library"
        "_gds_get_memory_usage"
        "_gds_wasm_get_detected_endianness_debug"
    )

    # Convert function array to comma-separated string
    local functions_string=$(IFS=,; echo "${exported_functions[*]}")

    # Emscripten command (compile wrapper.c and GDSII adapter)
    emcc \
        "$WRAPPER_C" \
        "$GDS_ADAPTER_C" \
        -I "$WASM_GLUE_DIR/include" \
        -I "$PROJECT_ROOT/Basic/gdsio" \
        -o "$OUTPUT_DIR/$OUTPUT_JS" \
        $EMCC_FLAGS \
        $EMCC_EXPORT_FLAGS \
        $EMCC_ENV_FLAGS \
        $EMCC_MEMORY_FLAGS \
        -s EXPORTED_FUNCTIONS=$functions_string \
        -s EXPORT_NAME="'GDSParserModule'" \
        -s EXPORTED_RUNTIME_METHODS="['ccall', 'cwrap', 'writeArrayToMemory', 'setValue', 'getValue']" \
        -s WASM_ASYNC_COMPILATION=0 \
        -s ASSERTIONS=0 \
        --pre-js "$WASM_GLUE_DIR/src/pre.js" 2>/dev/null || true \
        --post-js "$WASM_GLUE_DIR/src/post.js" 2>/dev/null || true
}

build_debug() {
    print_status "Building debug version..."

    # Same exported functions as release
    local exported_functions=(
        "_malloc"
        "_free"
        "_gds_parse_from_memory"
        "_gds_free_library"
        "_gds_get_library_name"
        "_gds_get_user_units_per_db_unit"
        "_gds_get_meters_per_db_unit"
        "_gds_get_structure_count"
        "_gds_get_structure_name"
        "_gds_get_element_count"
        "_gds_get_reference_count"
        "_gds_get_element_type"
        "_gds_get_element_layer"
        "_gds_get_element_data_type"
        "_gds_get_element_polygon_count"
        "_gds_get_element_polygon_vertex_count"
        "_gds_get_element_polygon_vertices"
        "_gds_get_element_text"
        "_gds_get_element_text_position"
        "_gds_get_element_text_presentation"
        "_gds_get_element_reference_name"
        "_gds_get_element_array_columns"
        "_gds_get_element_array_rows"
        "_gds_get_element_property_count"
        "_gds_get_element_property_attribute"
        "_gds_get_element_property_value"
        "_gds_get_element_bounds"
        "_gds_get_structure_bounds"
        "_gds_get_last_error"
        "_gds_clear_error"
        "_gds_validate_library"
        "_gds_get_memory_usage"
    )

    local functions_string=$(IFS=,; echo "${exported_functions[*]}")

    emcc \
        "$WRAPPER_C" \
        "$GDS_ADAPTER_C" \
        -I "$WASM_GLUE_DIR/include" \
        -I "$PROJECT_ROOT/Basic/gdsio" \
        -o "$OUTPUT_DIR/${OUTPUT_JS%.js}-debug.js" \
        $EMCC_DEBUG_FLAGS \
        $EMCC_EXPORT_FLAGS \
        $EMCC_ENV_FLAGS \
        -s EXPORTED_FUNCTIONS=$functions_string \
        -s EXPORT_NAME="'GDSParserModuleDebug'" \
        -s EXPORTED_RUNTIME_METHODS="['ccall', 'cwrap', 'writeArrayToMemory', 'setValue', 'getValue']" \
        -s ASSERTIONS=1 \
        -s STACK_SIZE=4MB \
        -s INITIAL_MEMORY=128MB \
        --pre-js "$WASM_GLUE_DIR/src/pre-debug.js" 2>/dev/null || true
}

create_pre_js() {
    cat > "$WASM_GLUE_DIR/src/pre.js" << 'EOF'
// GDSII Parser WASM Module - Pre-JS
// This code runs before the WASM module is initialized

console.log('Loading GDSII Parser WASM Module...');

// Add any global setup code here
if (typeof window !== 'undefined') {
    window.GDSParserLoading = true;
}
EOF
}

create_post_js() {
    cat > "$WASM_GLUE_DIR/src/post.js" << 'EOF'
// GDSII Parser WASM Module - Post-JS
// This code runs after the WASM module is initialized

if (typeof window !== 'undefined') {
    window.GDSParserLoading = false;
    console.log('GDSII Parser WASM Module loaded successfully');
}

// CRITICAL FIX: Attach memory views to Module object for TypeScript access
// Emscripten 4.x creates memory views as local variables, not Module properties
if (typeof Module !== 'undefined') {
    // Attach all memory views to Module object so TypeScript can access them
    if (typeof HEAP8 !== 'undefined') {
        Module.HEAP8 = HEAP8;
        Module.HEAPU8 = HEAPU8;
        Module.HEAP16 = HEAP16;
        Module.HEAPU16 = HEAPU16;
        Module.HEAP32 = HEAP32;
        Module.HEAPU32 = HEAPU32;
        Module.HEAPF32 = HEAPF32;
        Module.HEAPF64 = HEAPF64;
        console.log('✓ Memory views attached to Module object');
    }

    // Ensure wasmMemory is accessible
    if (typeof wasmMemory !== 'undefined') {
        Module.wasmMemory = wasmMemory;
        console.log('✓ WASM memory attached to Module object');
    }

    Module.gdsParseReady = true;

    // Auto-resolve the promise if something is waiting
    if (Module.gdsParseResolve) {
        Module.gdsParseResolve(Module);
    }
}
EOF
}

validate_build() {
    if [[ ! -f "$OUTPUT_DIR/$OUTPUT_JS" ]]; then
        print_error "Build failed: JavaScript output not found"
        exit 1
    fi

    if [[ ! -f "$OUTPUT_DIR/$OUTPUT_WASM" ]]; then
        print_error "Build failed: WebAssembly output not found"
        exit 1
    fi

    # Check file sizes
    local js_size=$(stat -f%z "$OUTPUT_DIR/$OUTPUT_JS" 2>/dev/null || stat -c%s "$OUTPUT_DIR/$OUTPUT_JS" 2>/dev/null || echo "0")
    local wasm_size=$(stat -f%z "$OUTPUT_DIR/$OUTPUT_WASM" 2>/dev/null || stat -c%s "$OUTPUT_DIR/$OUTPUT_WASM" 2>/dev/null || echo "0")

    print_success "Build validation passed:"
    echo "  - JavaScript: $js_size bytes"
    echo "  - WebAssembly: $wasm_size bytes"
}

# ============================================================================
# MAIN BUILD LOGIC
# ============================================================================

show_help() {
    echo "GDSII WASM Build Script"
    echo ""
    echo "Usage: $0 [OPTIONS]"
    echo ""
    echo "Options:"
    echo "  --release     Build release version (default)"
    echo "  --debug       Build debug version with source maps"
    echo "  --clean       Clean build artifacts"
    echo "  --help        Show this help message"
    echo ""
    echo "Examples:"
    echo "  $0                # Build release version"
    echo "  $0 --debug        # Build debug version"
    echo "  $0 --clean        # Clean build directory"
}

clean_build() {
    print_status "Cleaning build artifacts..."

    rm -rf "$BUILD_DIR"
    rm -f "$OUTPUT_DIR/$OUTPUT_JS"
    rm -f "$OUTPUT_DIR/${OUTPUT_JS%.js}-debug.js"
    rm -f "$OUTPUT_DIR/$OUTPUT_WASM"
    rm -f "$OUTPUT_DIR/${OUTPUT_WASM%.wasm}-debug.wasm"

    print_success "Build artifacts cleaned"
}

main() {
    print_status "GDSII WASM Build Script"
    echo "Project Root: $PROJECT_ROOT"
    echo "Output Directory: $OUTPUT_DIR"
    echo ""

    # Parse command line arguments
    case "${1:-}" in
        --help|-h)
            show_help
            exit 0
            ;;
        --clean)
            clean_build
            exit 0
            ;;
        --debug)
            BUILD_TYPE="debug"
            ;;
        --release)
            BUILD_TYPE="release"
            ;;
        "")
            BUILD_TYPE="release"
            ;;
        *)
            print_error "Unknown option: $1"
            show_help
            exit 1
            ;;
    esac

    # Execute build steps
    check_emscripten
    check_source_files
    create_build_directory
    cleanup_old_files

    # Create helper JavaScript files if they don't exist
    if [[ ! -f "$WASM_GLUE_DIR/src/pre.js" ]]; then
        create_pre_js
        print_status "Created pre.js helper file"
    fi

    if [[ ! -f "$WASM_GLUE_DIR/src/post.js" ]]; then
        create_post_js
        print_status "Created post.js helper file"
    fi

    # Build based on type
    case "$BUILD_TYPE" in
        "release")
            build_release
            print_success "Release build completed successfully"
            ;;
        "debug")
            build_debug
            print_success "Debug build completed successfully"
            ;;
    esac

    # Validate the build
    validate_build

    # Show next steps
    echo ""
    print_status "Build completed! Next steps:"
    echo "  1. The WASM module is available at: $OUTPUT_DIR/$OUTPUT_JS"
    echo "  2. Start the TypeScript development server:"
    echo "     cd MinimalGDSReader/gdsii-viewer"
    echo "     npm run dev"
    echo "  3. Open your browser and test GDSII file loading"
}

# ============================================================================
# SCRIPT ENTRY POINT
# ============================================================================

main "$@"