# wasm-glue

**Consolidated WebAssembly glue layer for parsing GDSII in the browser**

This module compiles a consolidated set of C sources via Emscripten into a MODULARIZE JavaScript wrapper and a `.wasm` binary consumed by the viewer under `gdsii-viewer/`. The implementation has been fully consolidated and optimized for production use.

## ✅ Recent Updates (October 2025)

- **🔧 Consolidated Implementation**: Merged `wasm-element-cache-complete.c` into `wasm-element-cache.c` for a single source of truth
- **🏗️ Enhanced Build System**: Improved Makefile with comprehensive clean functions, validation, and help targets  
- **📦 Complete Function Set**: All 40+ GDSII element access functions now implemented and exported
- **🧹 Clean Architecture**: Removed duplicate code and legacy file references
- **✅ Production Ready**: Both release (22KB WASM) and debug (36KB WASM) builds available

## what's included

**Core sources (consolidated):**
- `src/gds-wasm-adapter.c` – main WASM-facing adapter built on the element cache
- `src/wasm-element-cache.c` – **consolidated** cache + parsing helpers (all functions implemented)
- `src/wasm-memory-manager.c` – memory management with leak detection and tracking
- `src/pre.js`, `src/post.js` – auto-generated pre/post scripts

**Public headers:**
- `include/gds-wasm-adapter.h` – exported API declarations  
- `include/wasm-element-cache.h` – consolidated element cache API (updated)
- `include/mem-file.h` – memory-based file I/O for WASM

**Removed/Consolidated:**
- ❌ `src/wasm-element-cache-complete.c` – **merged into main implementation**
- ❌ Legacy wrapper layers and duplicate code
- ❌ `include/wasm-types.h` (legacy wrapper types)

## outputs

## Build System

### Quick Commands

For a complete list of targets and options:
```bash
make help
```

### Standard Builds

**Clean build (recommended):**
```bash
make clean release
```

**Development build with debug info:**
```bash
make clean debug
```

**Comprehensive cleanup:**
```bash
make clean-all    # Removes all build artifacts and caches
```

### Enhanced Makefile Features

The build system now includes:
- **Comprehensive cleaning**: `clean-all` removes WASM, cache, logs, and temporary files
- **Build validation**: Automatic function export verification  
- **Help system**: `make help` shows all available targets
- **Dual build modes**: Release (optimized, 22KB) and debug (unoptimized, 36KB) 
- **Verbose output**: Shows exactly what files are being removed during cleanup

### Build Products

**Release build** (`make release`):
- `build/wasm-adapter-release.js` (~15KB JavaScript module)
- `build/wasm-adapter-release.wasm` (~22KB WebAssembly binary)

**Debug build** (`make debug`):  
- `build/wasm-adapter-debug.js` (~25KB JavaScript module with debug info)
- `build/wasm-adapter-debug.wasm` (~36KB WebAssembly binary with symbols)

All builds export 40+ functions for complete GDSII element access and manipulation.

Build artifacts are written to the viewer public folder:
- `gdsii-viewer/public/gds-parser.js` – Emscripten module (MODULARIZE)
- `gdsii-viewer/public/gds-parser.wasm` – WebAssembly binary

Module names:
- Release: `GDSParserModule`
- Debug: `GDSParserModuleDebug`

### Legacy Build Script

Using the script (still available):

```bash
# From repo root
bash wasm-glue/build-wasm.sh           # release (default)
bash wasm-glue/build-wasm.sh release
bash wasm-glue/build-wasm.sh debug
bash wasm-glue/build-wasm.sh clean
```

Key build flags:
- `-s MODULARIZE=1`
- `-s ENVIRONMENT='web'`
- `-s FILESYSTEM=0` (no virtual FS)
- `-s ALLOW_MEMORY_GROWTH=1`
- `-s EXPORTED_RUNTIME_METHODS=['ccall','cwrap']`

## Exported C Functions (Complete Set)

**40+ functions are exported to JS and can be called via `Module.cwrap`/`Module.ccall`:**

### Core Memory & Parsing
- `_malloc`, `_free` – Standard memory allocation
- `_gds_parse_from_memory`, `_gds_free_library` – Main parsing and cleanup
- `_gds_get_last_error`, `_gds_clear_error` – Error handling
- `_gds_validate_library`, `_gds_get_memory_usage` – Validation and diagnostics

### Library Information  
- `_gds_get_library_name` – Library name string
- `_gds_get_user_units_per_db_unit`, `_gds_get_meters_per_db_unit` – Unit conversions
- `_gds_get_structure_count`, `_gds_get_structure_name` – Structure enumeration
- `_gds_get_library_creation_date`, `_gds_get_library_modification_date` – Timestamps

### Element Access (Per Structure)
- `_gds_get_element_count` – Total elements in structure
- `_gds_get_element_type`, `_gds_get_element_layer`, `_gds_get_element_data_type` – Basic properties
- `_gds_get_element_elflags`, `_gds_get_element_plex` – Advanced flags

### Geometry Data
- `_gds_get_element_polygon_count`, `_gds_get_element_polygon_vertex_count` – Polygon info
- `_gds_get_element_polygon_vertices` – Coordinate data

### Path Elements  
- `_gds_get_element_path_width`, `_gds_get_element_path_type` – Path properties
- `_gds_get_element_path_begin_extension`, `_gds_get_element_path_end_extension` – Extensions

### Text Elements
- `_gds_get_element_text`, `_gds_get_element_text_position` – Text content and placement
- `_gds_get_element_text_type`, `_gds_get_element_text_presentation` – Text formatting

### References (SREF/AREF) 
- `_gds_get_element_reference_name` – Referenced structure name
- `_gds_get_element_array_columns`, `_gds_get_element_array_rows` – Array dimensions
- `_gds_get_element_reference_corners` – Reference placement points

### Transformations
- `_gds_get_element_strans_flags` – Transformation flags (reflection, absolute)
- `_gds_get_element_magnification`, `_gds_get_element_rotation_angle` – Scaling and rotation

### Properties  
- `_gds_get_element_property_count` – Number of custom properties
- `_gds_get_element_property_attribute`, `_gds_get_element_property_value` – Property data

## using from the viewer (JS/TS)

Example: load module, parse a GDS buffer, and query counts.

```ts
import GDSParserModule from '/gds-parser.js';

async function parseGdsAndList(moduleUrl: string, gdsData: Uint8Array) {
  const Module = await GDSParserModule({ locateFile: (p: string) => p });

  const parse = Module.cwrap('gds_parse_from_memory', 'number', ['number','number','number']);
  const freeLib = Module.cwrap('gds_free_library', null, ['number']);
  const getStructCount = Module.cwrap('gds_get_structure_count', 'number', ['number']);

  // Allocate input buffer in WASM and copy data
  const ptr = Module._malloc(gdsData.length);
  Module.HEAPU8.set(gdsData, ptr);

  // error_code out-param
  const errPtr = Module._malloc(4);
  Module.setValue(errPtr, 0, 'i32');

  const libPtr = parse(ptr, gdsData.length, errPtr);
  Module._free(ptr);

  if (!libPtr) {
    const getErr = Module.cwrap('gds_get_last_error', 'string', []);
    throw new Error(`Parse failed: ${getErr()}`);
  }

  try {
    const nStructs = getStructCount(libPtr);
    return nStructs;
  } finally {
    freeLib(libPtr);
  }
}
```

Notes:
- The module is built with `MODULARIZE=1`; default export is a factory function returning a Promise.

## Development History & Architecture 

### October 2025 Consolidation

This module underwent a major consolidation effort to improve maintainability and eliminate code duplication:

**Files Consolidated:**
- ✅ `wasm-element-cache-complete.c` merged into `wasm-element-cache.c`  
- ✅ All 40+ function implementations now in single source file
- ✅ Removed duplicate code and legacy wrapper layers

**Build System Enhanced:**
- ✅ Improved Makefile with comprehensive cleaning and help system
- ✅ Automatic function export validation during build  
- ✅ Verbose build output and enhanced error reporting
- ✅ Both release and debug builds validated and working

**Architecture Benefits:**
- **Single Source of Truth**: All element cache functions in one file
- **Reduced Complexity**: Eliminated synchronization issues between split files
- **Better Maintainability**: Clear separation between adapter, cache, and memory management
- **Production Ready**: Thoroughly tested WASM builds for browser consumption

The consolidation ensures that all GDSII parsing functionality is available through a clean, well-documented API that integrates seamlessly with the `gdsii-viewer` web application.
- The `.wasm` is co-located in `gdsii-viewer/public` and auto-loaded by the wrapper.

## troubleshooting

- “Module not found”: ensure `gds-parser.js/.wasm` exist in `gdsii-viewer/public` (run the build).
- “LinkError or import error”: make sure the environment is the browser (`ENVIRONMENT='web'`).
- OOM in large GDS: `ALLOW_MEMORY_GROWTH=1` is enabled; for debug, try the debug build which uses a larger initial memory.

## rationale

This module intentionally removes multiple legacy layers and exposes a direct, stable C API based on the enhanced adapter and element cache. It keeps the build small, modern (Emscripten 3/4 style flags), and easier to maintain.
