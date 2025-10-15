# GDSII WASM Integration Plan

## Overview

This document outlines the comprehensive plan for integrating WebAssembly (WASM) compiled from the C/C++ GDSII parsing code in the base project with the renovated TypeScript visualization app. The integration will provide native-speed GDSII parsing while maintaining a modern web-based interface.

## Architecture Overview

```
┌─────────────────┐    ┌──────────────────┐    ┌─────────────────┐
│   TypeScript    │◄──►│   WASM Interface │◄──►│  C/C++ Parser    │
│   Viewer App    │    │   (Glue Code)    │    │   (Compiled)     │
└─────────────────┘    └──────────────────┘    └─────────────────┘
        │                       │                       │
        │                       │                       │
        ▼                       ▼                       ▼
   Rendering Engine    Memory Management    Low-level I/O
   UI Controls         Data Conversion      Binary Parsing
   User Interaction   Type Safety          GDSII Spec Compliance
```

## Phase 1: C/C++ WASM Wrapper Development

### 1.1 Core WASM Interface (`Basic/gdsio/wrapper.c`)

#### Primary Objectives:
- **Leverage existing battle-tested GDS parsing infrastructure**
- **Directly expose `Basic/gdsio` functions to JavaScript with minimal overhead**
- **Maintain full fidelity with C/C++ data structures**
- **Handle memory management between C/C++ and JavaScript**

#### Key Functions to Implement:

```c
// Memory and Lifecycle Management
EMSCRIPTEN_KEEPALIVE
void* gds_parse_from_memory(uint8_t* data, int size, int* error_code);
EMSCRIPTEN_KEEPALIVE
void gds_free_library(void* library_ptr);

// Library Metadata Access (using existing gds_libdata.c functions)
EMSCRIPTEN_KEEPALIVE
const char* gds_get_library_name(void* library_ptr);
EMSCRIPTEN_KEEPALIVE
double gds_get_user_units_per_db_unit(void* library_ptr);
EMSCRIPTEN_KEEPALIVE
double gds_get_meters_per_db_unit(void* library_ptr);
EMSCRIPTEN_KEEPALIVE
int gds_get_structure_count(void* library_ptr);

// Date/Time access (enhanced from existing)
EMSCRIPTEN_KEEPALIVE
void gds_get_library_creation_date(void* library_ptr, uint16_t* date_array);
EMSCRIPTEN_KEEPALIVE
void gds_get_library_modification_date(void* library_ptr, uint16_t* date_array);

// Structure Access (using existing gds_structdata.c functions)
EMSCRIPTEN_KEEPALIVE
const char* gds_get_structure_name(void* library_ptr, int structure_index);
EMSCRIPTEN_KEEPALIVE
int gds_get_element_count(void* library_ptr, int structure_index);
EMSCRIPTEN_KEEPALIVE
void gds_get_structure_dates(void* library_ptr, int structure_index, uint16_t* cdate, uint16_t* mdate);

// Element Type Detection (using existing gds_read_element.c functions)
EMSCRIPTEN_KEEPALIVE
int gds_get_element_type(void* library_ptr, int structure_index, int element_index);
EMSCRIPTEN_KEEPALIVE
int gds_get_element_layer(void* library_ptr, int structure_index, int element_index);
EMSCRIPTEN_KEEPALIVE
int gds_get_element_data_type(void* library_ptr, int structure_index, int element_index);

// Element Flags and Properties (from element_t structure)
EMSCRIPTEN_KEEPALIVE
uint16_t gds_get_element_elflags(void* library_ptr, int structure_index, int element_index);
EMSCRIPTEN_KEEPALIVE
int32_t gds_get_element_plex(void* library_ptr, int structure_index, int element_index);

// Geometry Data Access
EMSCRIPTEN_KEEPALIVE
int gds_get_element_polygon_count(void* library_ptr, int structure_index, int element_index);
EMSCRIPTEN_KEEPALIVE
int gds_get_element_polygon_vertex_count(void* library_ptr, int structure_index, int element_index, int polygon_index);
EMSCRIPTEN_KEEPALIVE
double* gds_get_element_polygon_vertices(void* library_ptr, int structure_index, int element_index, int polygon_index);

// Path-Specific Data (from element_t path_data)
EMSCRIPTEN_KEEPALIVE
float gds_get_element_path_width(void* library_ptr, int structure_index, int element_index);
EMSCRIPTEN_KEEPALIVE
uint16_t gds_get_element_path_type(void* library_ptr, int structure_index, int element_index);
EMSCRIPTEN_KEEPALIVE
float gds_get_element_path_begin_extension(void* library_ptr, int structure_index, int element_index);
EMSCRIPTEN_KEEPALIVE
float gds_get_element_path_end_extension(void* library_ptr, int structure_index, int element_index);

// Text-Specific Data (from element_t text_data)
EMSCRIPTEN_KEEPALIVE
const char* gds_get_element_text(void* library_ptr, int structure_index, int element_index);
EMSCRIPTEN_KEEPALIVE
void gds_get_element_text_position(void* library_ptr, int structure_index, int element_index, float* x, float* y);
EMSCRIPTEN_KEEPALIVE
uint16_t gds_get_element_text_type(void* library_ptr, int structure_index, int element_index);
EMSCRIPTEN_KEEPALIVE
uint16_t gds_get_element_text_presentation(void* library_ptr, int structure_index, int element_index);

// Reference Elements (SREF/AREF) - using existing structure reference parsing
EMSCRIPTEN_KEEPALIVE
const char* gds_get_element_reference_name(void* library_ptr, int structure_index, int element_index);
EMSCRIPTEN_KEEPALIVE
int gds_get_element_array_columns(void* library_ptr, int structure_index, int element_index);
EMSCRIPTEN_KEEPALIVE
int gds_get_element_array_rows(void* library_ptr, int structure_index, int element_index);
EMSCRIPTEN_KEEPALIVE
void gds_get_element_reference_corners(void* library_ptr, int structure_index, int element_index,
                                      float* x1, float* y1, float* x2, float* y2, float* x3, float* y3);

// Transformation (strans_t structure)
EMSCRIPTEN_KEEPALIVE
uint16_t gds_get_element_strans_flags(void* library_ptr, int structure_index, int element_index);
EMSCRIPTEN_KEEPALIVE
double gds_get_element_magnification(void* library_ptr, int structure_index, int element_index);
EMSCRIPTEN_KEEPALIVE
double gds_get_element_rotation_angle(void* library_ptr, int structure_index, int element_index);

// Property System
EMSCRIPTEN_KEEPALIVE
int gds_get_element_property_count(void* library_ptr, int structure_index, int element_index);
EMSCRIPTEN_KEEPALIVE
uint16_t gds_get_element_property_attribute(void* library_ptr, int structure_index, int element_index, int property_index);
EMSCRIPTEN_KEEPALIVE
const char* gds_get_element_property_value(void* library_ptr, int structure_index, int element_index, int property_index);

// Bounding Box Information
EMSCRIPTEN_KEEPALIVE
double* gds_get_element_bounds(void* library_ptr, int structure_index, int element_index);
EMSCRIPTEN_KEEPALIVE
double* gds_get_structure_bounds(void* library_ptr, int structure_index);

// Error Handling
EMSCRIPTEN_KEEPALIVE
const char* gds_get_last_error(void);
EMSCRIPTEN_KEEPALIVE
void gds_clear_error(void);

// Utility Functions
EMSCRIPTEN_KEEPALIVE
int gds_validate_library(void* library_ptr);
EMSCRIPTEN_KEEPALIVE
void gds_get_memory_usage(int* total_allocated, int* peak_usage);
```

### 1.2 WASM-Compatible Data Structures (`Basic/gdsio/wasm-types.h`)

#### **Faithful C/C++ Structure Mapping:**

```c
// **Direct mapping of existing gdstypes.h structures for WASM compatibility**

// Vertex structure (matching internal coordinate system)
typedef struct {
    double x, y;  // Use double precision from C implementation
} wasm_vertex_t;

// Bounding box (from existing bbox calculations)
typedef struct {
    double min_x, min_y, max_x, max_y;
} wasm_bbox_t;

// **element_t structure faithful mapping from gdstypes.h:**
typedef struct {
    element_kind kind;           // From gdstypes.h: GDS_BOUNDARY, GDS_PATH, etc.
    unsigned int has;            // HAS_ELFLAGS, HAS_PLEX, HAS_WIDTH, etc.

    // Core element properties (exact match to element_t)
    uint16_t elflags;            // Element flags
    uint16_t layer;              // Layer number
    uint16_t dtype;              // Data type
    uint16_t ptype;              // Path type (for PATH elements)
    uint16_t ttype;              // Text type (for TEXT elements)
    uint16_t ntype;              // Node type (for NODE elements)
    uint16_t btype;              // Box type (for BOX elements)
    uint16_t present;            // Text presentation flags
    uint16_t nrow, ncol;         // Array dimensions (for AREF elements)
    int32_t plex;                // Plex number

    // Transformation (exact strans_t structure)
    struct {
        uint16_t flags;
        double mag;
        double angle;
    } strans;

    // Element-specific data (matching internal representation)
    float width;                 // Path width
    float bgnextn;              // Path begin extension
    float endextn;              // Path end extension

    // Geometry data (from gds_read_element.c xy_block)
    int polygon_count;
    double* xy_vertices;         // Raw coordinate array from GDS file
    int* vertex_counts;          // Vertex count per polygon

    // Text data (from TEXT element parsing)
    char text_string[512];       // Text content
    double text_x, text_y;       // Text position

    // Reference data (from SREF/AREF parsing)
    char structure_name[256];    // Referenced structure name
    double ref_positions[2];     // Reference position(s)
    double corners[6];           // AREF corner coordinates (3 corners = 6 values)

    // Properties (from PROPATTR/PROPVALUE records)
    int property_count;
    struct {
        uint16_t attribute;
        char value[256];
    }* properties;

    // Calculated bounding box
    wasm_bbox_t bounds;

} wasm_element_t;

// **Structure data (faithful mapping from gds_read_struct.m and internal structures)**
typedef struct {
    char name[256];               // Structure name (from STRNAME record)
    uint16_t cdate[6];            // Creation date (from BGNSTR)
    uint16_t mdate[6];            // Modification date (from BGNSTR)

    int element_count;
    wasm_element_t* elements;

    // Structure references (for hierarchy tracking)
    int reference_count;
    struct {
        char referenced_structure_name[256];
        int count;
        wasm_bbox_t* instance_bounds;
    }* references;

    // Calculated total bounds (from element aggregation)
    wasm_bbox_t total_bounds;

    // Internal parsing state
    int file_offset;              // Position in GDS file for this structure
    int is_parsed;                // Flag indicating if fully parsed

} wasm_structure_t;

// **Library data (faithful mapping from gds_libdata.c and gdstypes.h)**
typedef struct {
    char name[256];               // Library name (from LIBNAME record)
    uint16_t libver;              // Library version (from HEADER record)
    uint16_t cdate[6];            // Creation date (from BGNLIB record)
    uint16_t mdate[6];            // Modification date (from BGNLIB record)

    // Units (exact match to existing implementation)
    double user_units_per_db_unit; // User units per database unit
    double meters_per_db_unit;     // Database units in meters

    int structure_count;
    wasm_structure_t* structures;

    // Optional library data (from existing gds_libdata parsing)
    int ref_lib_count;
    char* ref_libraries[128];     // Reference library names
    int font_count;
    char* fonts[4];               // Font names

    // Internal file information
    long file_size;               // Total file size in bytes
    int is_parsed;                // Flag indicating if fully parsed
    void* file_handle;            // Original file handle (if needed)

} wasm_library_t;
```

### 1.3 Parser Adapter (`Basic/gdsio/parser-adapter.c`)

#### Conversion Functions:

```c
// Convert internal MATLAB-compatible structures to WASM-friendly structures
wasm_library_t* create_wasm_library(gds_library_t* internal_lib);
void convert_structure(wasm_structure_t* wasm_struct, gds_structure_t* internal_struct);
void convert_element(wasm_element_t* wasm_el, gds_element_t* internal_el);
void convert_geometry(wasm_geometry_t* wasm_geom, void* internal_geom);

// Memory management
void free_wasm_library(wasm_library_t* wasm_lib);
void free_wasm_structure(wasm_structure_t* wasm_struct);
void free_wasm_element(wasm_element_t* wasm_el);

// Utility functions
int calculate_wasm_memory_size(wasm_library_t* lib);
void optimize_wasm_layout(wasm_library_t* lib);
```

## Phase 2: TypeScript WASM Interface Enhancement

### 2.1 Enhanced WASM Loader (`src/wasm-interface.ts`)

#### Current Implementation Review:
The existing `wasm-interface.ts` provides a solid foundation but needs enhancements for:

1. **Memory Pool Management**: Implement memory pools for frequent allocations
2. **Streaming Parser**: Support for large files without loading everything into memory
3. **Error Recovery**: Better error handling and recovery mechanisms
4. **Performance Monitoring**: Memory usage and parsing performance tracking

#### Enhanced Functions:

```typescript
// Enhanced memory management
export class WASMMemoryManager {
  private memoryPools: Map<string, number[]> = new Map();
  private allocatedMemory: number = 0;
  private peakMemory: number = 0;

  allocatePool(size: number, type: string): number;
  deallocatePool(ptr: number, type: string): void;
  getMemoryStats(): { allocated: number; peak: number; pools: number };
  optimizePools(): void;
}

// Streaming parser interface
export class StreamingGDSParser {
  private chunkSize: number = 1024 * 1024; // 1MB chunks
  private parser: GDSWASMModule | null = null;

  async parseStream(data: Uint8Array, onProgress?: (progress: number) => void): Promise<GDSLibrary>;
  async parsePartial(data: Uint8Array, offset: number, length: number): Promise<Partial<GDSLibrary>>;
}

// Enhanced error handling
export class GDSParseError extends Error {
  constructor(
    message: string,
    public readonly code: number,
    public readonly context?: string,
    public readonly position?: number
  ) {
    super(message);
  }
}

// Performance monitoring
export class GDSPerformanceMonitor {
  private metrics: Map<string, number[]> = new Map();

  startTimer(operation: string): void;
  endTimer(operation: string): number;
  getMetrics(): Record<string, { avg: number; min: number; max: number; count: number }>;
  resetMetrics(): void;
}
```

### 2.2 Faithful TypeScript Data Structure Design

#### **Direct Mapping from C/C++ Structures:**

```typescript
// **Exact mapping from gdstypes.h element_t structure**
export interface GDSElement {
  // Core element properties (exact match to C element_t)
  readonly kind: ElementKind;           // GDS_BOUNDARY, GDS_PATH, etc.
  readonly has: PropertyFlags;         // HAS_ELFLAGS, HAS_PLEX, HAS_WIDTH, etc.

  // Element flags and properties
  readonly elflags: number;            // uint16_t - Element flags
  readonly layer: number;              // uint16_t - Layer number
  readonly dtype: number;              // uint16_t - Data type
  readonly ptype: number;              // uint16_t - Path type (PATH elements)
  readonly ttype: number;              // uint16_t - Text type (TEXT elements)
  readonly ntype: number;              // uint16_t - Node type (NODE elements)
  readonly btype: number;              // uint16_t - Box type (BOX elements)
  readonly present: number;            // uint16_t - Text presentation flags
  readonly nrow: number;               // uint16_t - Array rows (AREF elements)
  readonly ncol: number;               // uint16_t - Array columns (AREF elements)
  readonly plex: number;               // int32_t - Plex number

  // Transformation (exact strans_t structure mapping)
  readonly strans: {
    readonly flags: number;            // uint16_t - Transformation flags
    readonly mag: number;              // double - Magnification
    readonly angle: number;            // double - Rotation angle (radians)
  };

  // Element-specific data (matching C implementation)
  readonly width: number;              // float - Path width
  readonly bgnextn: number;            // float - Path begin extension
  readonly endextn: number;            // float - Path end extension

  // Geometry data (from gds_read_element.c xy_block)
  readonly polygons: GDSPoint[][];     // Multi-polygon support

  // Text data (from TEXT element parsing)
  readonly text?: string;              // Text content
  readonly textPosition?: GDSPoint;    // Text position

  // Reference data (from SREF/AREF parsing)
  readonly referenceName?: string;     // Referenced structure name
  readonly referencePositions?: GDSPoint[]; // Reference positions
  readonly corners?: [GDSPoint, GDSPoint, GDSPoint]; // AREF corners

  // Properties (from PROPATTR/PROPVALUE records)
  readonly properties: GDSProperty[];

  // Calculated bounding box
  readonly bounds: GDSBBox;
}

// **Exact element kind enumeration from gdstypes.h**
export enum ElementKind {
  GDS_BOUNDARY = 1,    // 0x0800
  GDS_PATH = 2,        // 0x0900
  GDS_BOX = 3,         // 0x2d00
  GDS_NODE = 4,        // 0x1500
  GDS_TEXT = 5,        // 0x0c00
  GDS_SREF = 6,        // 0x0a00
  GDS_AREF = 7         // 0x0b00
}

// **Property flags (exact match to gdstypes.h)**
export const PropertyFlags = {
  HAS_ELFLAGS: 1,
  HAS_PLEX: (1 << 1),
  HAS_PTYPE: (1 << 2),
  HAS_WIDTH: (1 << 3),
  HAS_BGNEXTN: (1 << 4),
  HAS_ENDEXTN: (1 << 5),
  HAS_PRESTN: (1 << 6),
  HAS_DTYPE: (1 << 7),
  HAS_STRANS: (1 << 16),
  HAS_ANGLE: (1 << 17),
  HAS_MAG: (1 << 18)
} as const;

export type PropertyFlags = typeof PropertyFlags[keyof typeof PropertyFlags];

// **Structure data (faithful mapping from gds_read_struct.m)**
export interface GDSStructure {
  // Structure metadata (from STRNAME and BGNSTR records)
  readonly name: string;               // Structure name
  readonly creationDate: GDSDate;      // From BGNSTR record
  readonly modificationDate: GDSDate;  // From BGNSTR record

  // Elements
  readonly elements: GDSElement[];

  // Hierarchy tracking
  readonly references: GDSReference[]; // Structure references within this structure
  readonly referencedBy: string[];     // Which structures reference this one

  // Calculated data
  readonly bounds: GDSBBox;           // Total bounds of all elements
  readonly elementCount: number;      // Total number of elements

  // Internal parsing state
  readonly fileOffset: number;        // Position in GDS file
  readonly isFullyParsed: boolean;    // Whether all data is loaded
}

// **Library data (faithful mapping from gds_libdata.c)**
export interface GDSLibrary {
  // Library metadata (from LIBNAME, BGNLIB, HEADER records)
  readonly name: string;               // Library name
  readonly version: number;            // Library version
  readonly creationDate: GDSDate;      // From BGNLIB record
  readonly modificationDate: GDSDate;  // From BGNLIB record

  // Units (exact match to existing implementation)
  readonly units: {
    readonly userUnitsPerDatabaseUnit: number;  // User units per DB unit
    readonly metersPerDatabaseUnit: number;      // DB units in meters
  };

  // Structures
  readonly structures: GDSStructure[];
  readonly structureCount: number;

  // Optional library data (from existing gds_libdata parsing)
  readonly referenceLibraries: string[]; // Reflibs record
  readonly fonts: string[];               // Fonts record

  // File information
  readonly fileSize: number;             // Total file size
  readonly isFullyParsed: boolean;       // Whether all structures are loaded

  // Performance and statistics
  readonly totalElements: number;        // Total elements across all structures
  readonly parseTime?: number;           // Time taken to parse (ms)
}

// **Supporting types (exact match to C structures)**
export interface GDSDate {
  readonly year: number;    // uint16_t
  readonly month: number;   // uint16_t
  readonly day: number;     // uint16_t
  readonly hour: number;    // uint16_t
  readonly minute: number;  // uint16_t
  readonly second: number;  // uint16_t
}

export interface GDSProperty {
  readonly attribute: number;  // uint16_t - Property attribute
  readonly value: string;      // Property value
}

export interface GDSReference {
  readonly structureName: string;   // Referenced structure name
  readonly positions: GDSPoint[];   // Instance positions
  readonly instanceBounds: GDSBBox; // Bounds of each instance
  readonly count: number;           // Number of instances
}
```

#### **Enhanced Data Conversion Layer:**

```typescript
// **Faithful conversion utilities with C/C++ structure preservation**
export class GDSDataConverter {
  // Convert WASM data to TypeScript interfaces (preserving C structure fidelity)
  static convertWASMLibrary(wasmPtr: number, module: GDSWASMModule): GDSLibrary {
    const lib = {
      name: module._gds_get_library_name(wasmPtr),
      version: module._gds_get_library_version?.(wasmPtr) || 0,
      creationDate: this.convertDate(module, wasmPtr, 'creation'),
      modificationDate: this.convertDate(module, wasmPtr, 'modification'),
      units: {
        userUnitsPerDatabaseUnit: module._gds_get_user_units_per_db_unit(wasmPtr),
        metersPerDatabaseUnit: module._gds_get_meters_per_db_unit(wasmPtr)
      },
      // ... rest of faithful conversion
    };
    return lib;
  }

  static convertWASMStructure(wasmPtr: number, structIndex: number, module: GDSWASMModule): GDSStructure {
    return {
      name: module._gds_get_structure_name(wasmPtr, structIndex),
      creationDate: this.convertStructureDates(wasmPtr, structIndex, module, 'creation'),
      modificationDate: this.convertStructureDates(wasmPtr, structIndex, module, 'modification'),
      elements: this.convertElements(wasmPtr, structIndex, module),
      // ... rest of faithful conversion preserving all C fields
    };
  }

  static convertWASMElement(wasmPtr: number, structIndex: number, elemIndex: number, module: GDSWASMModule): GDSElement {
    const kind = module._gds_get_element_type(wasmPtr, structIndex, elemIndex) as ElementKind;
    const has = module._gds_get_element_property_flags?.(wasmPtr, structIndex, elemIndex) || 0;

    return {
      kind,
      has,
      elflags: module._gds_get_element_elflags(wasmPtr, structIndex, elemIndex),
      layer: module._gds_get_element_layer(wasmPtr, structIndex, elemIndex),
      dtype: module._gds_get_element_data_type(wasmPtr, structIndex, elemIndex),
      // ... convert ALL fields from C element_t structure
      strans: this.convertStrans(wasmPtr, structIndex, elemIndex, module),
      polygons: this.convertPolygons(wasmPtr, structIndex, elemIndex, module),
      properties: this.convertProperties(wasmPtr, structIndex, elemIndex, module),
      bounds: this.convertBounds(wasmPtr, structIndex, elemIndex, module)
    };
  }

  // Specialized converters for complex structures
  private static convertStrans(wasmPtr: number, structIndex: number, elemIndex: number, module: GDSWASMModule) {
    return {
      flags: module._gds_get_element_strans_flags(wasmPtr, structIndex, elemIndex),
      mag: module._gds_get_element_magnification(wasmPtr, structIndex, elemIndex),
      angle: module._gds_get_element_rotation_angle(wasmPtr, structIndex, elemIndex)
    };
  }

  private static convertPolygons(wasmPtr: number, structIndex: number, elemIndex: number, module: GDSWASMModule): GDSPoint[][] {
    const polygonCount = module._gds_get_element_polygon_count(wasmPtr, structIndex, elemIndex);
    const polygons: GDSPoint[][] = [];

    for (let i = 0; i < polygonCount; i++) {
      const vertexCount = module._gds_get_element_polygon_vertex_count(wasmPtr, structIndex, elemIndex, i);
      const verticesPtr = module._gds_get_element_polygon_vertices(wasmPtr, structIndex, elemIndex, i);
      const vertices = this.convertDoubleArray(verticesPtr, vertexCount * 2, module);

      const polygon: GDSPoint[] = [];
      for (let j = 0; j < vertexCount; j++) {
        polygon.push({
          x: vertices[j * 2],
          y: vertices[j * 2 + 1]
        });
      }
      polygons.push(polygon);
    }

    return polygons;
  }

  // Validation that maintains C structure integrity
  static validateLibrary(library: GDSLibrary): boolean {
    return library.name.length > 0 &&
           library.structures.every(s => this.validateStructure(s)) &&
           library.units.userUnitsPerDatabaseUnit > 0;
  }

  static validateElement(element: GDSElement): boolean {
    // Validate element maintains C structure constraints
    return element.kind !== undefined &&
           element.layer >= 0 &&
           element.polygons.length > 0 &&
           element.bounds.minX <= element.bounds.maxX;
  }
}
```

## Phase 3: Build System Integration

### 3.1 Emscripten Build Configuration

#### Build Script (`build-wasm.sh`):

```bash
#!/bin/bash

# Set up Emscripten environment
source /path/to/emsdk/emsdk_env.sh

# Compiler flags for optimal performance
EMCC_FLAGS="-O3 -flto --memory-init-file 0"
EXPORT_FLAGS="-s WASM=1 -s ALLOW_MEMORY_GROWTH=1 -s MODULARIZE=1"
EXPORT_FUNCTIONS="--exported-functions=_malloc,_free,_gds_parse_from_memory,_gds_free_library"

# Full list of exported functions
FULL_EXPORTS="--exported-functions='[
  _malloc,_free,
  _gds_parse_from_memory,_gds_free_library,
  _gds_get_library_name,_gds_get_user_units_per_db_unit,_gds_get_meters_per_db_unit,
  _gds_get_structure_count,_gds_get_structure_name,
  _gds_get_element_count,_gds_get_element_type,_gds_get_element_layer,
  _gds_get_element_polygon_count,_gds_get_element_polygon_vertex_count,
  _gds_get_element_polygon_vertices,_gds_get_element_path_width,
  _gds_get_element_text,_gds_get_element_reference_name,
  _gds_get_element_property_count,_gds_get_element_property_attribute,
  _gds_get_element_property_value,_gds_get_element_bounds,
  _gds_get_last_error,_gds_validate_library
]'"

# Compile C/C++ files to WebAssembly
emcc \
  Basic/gdsio/gdsio.c \
  Basic/gdsio/gds_read_element.c \
  Basic/gdsio/gds_record_info.c \
  Basic/gdsio/gds_structdata.c \
  Basic/gdsio/mexfuncs.c \
  Basic/gdsio/wrapper.c \
  Basic/gdsio/parser-adapter.c \
  -I Basic/gdsio/ \
  -o MinimalGDSReader/gdsii-viewer/public/gds-parser.js \
  $EMCC_FLAGS \
  $EXPORT_FLAGS \
  $FULL_EXPORTS \
  -s EXPORT_NAME="'GDSParserModule'" \
  -s ENVIRONMENT='web' \
  -s FILESYSTEM=0 \
  --pre-js MinimalGDSReader/gdsii-viewer/public/pre.js \
  --post-js MinimalGDSReader/gdsii-viewer/public/post.js

echo "WASM compilation completed successfully"
```

### 3.2 Package.json Integration

```json
{
  "scripts": {
    "build-wasm": "cd .. && chmod +x build-wasm.sh && ./build-wasm.sh",
    "build-wasm-debug": "cd .. && EMCC_DEBUG=1 ./build-wasm.sh",
    "dev": "npm run build-wasm && vite",
    "build": "npm run build-wasm && tsc && vite build",
    "validate-wasm": "node scripts/validate-wasm.js"
  },
  "devDependencies": {
    "typescript": "~5.9.3",
    "vite": "^7.1.7",
    "@types/emscripten": "^1.39.6"
  }
}
```

## Phase 4: Integration Testing and Validation

### 4.1 Test Suite Structure

#### Unit Tests (`tests/wasm-interface.test.ts`):

```typescript
import { describe, it, expect, beforeEach } from 'vitest';
import { parseGDSII, loadWASMModule, validateWASMModule } from '../src/wasm-interface';

describe('WASM Interface', () => {
  beforeEach(async () => {
    await loadWASMModule();
  });

  it('should load WASM module successfully', () => {
    expect(validateWASMModule()).toBe(true);
  });

  it('should parse simple GDSII file', async () => {
    const testData = new Uint8Array(/* simple GDSII test data */);
    const library = await parseGDSII(testData);

    expect(library).toBeDefined();
    expect(library.name).toBe('TEST_LIBRARY');
    expect(library.structures).toHaveLength(1);
  });

  it('should handle complex hierarchies', async () => {
    const complexData = new Uint8Array(/* complex hierarchical GDSII data */);
    const library = await parseGDSII(complexData);

    // Verify structure references are handled correctly
    expect(library.structures.some(s => s.elements.some(e => e.type === 'sref'))).toBe(true);
  });
});
```

#### Integration Tests (`tests/integration.test.ts`):

```typescript
import { describe, it, expect } from 'vitest';
import { GDSViewer } from '../src/main';

describe('GDS Viewer Integration', () => {
  it('should load and render GDSII file with WASM', async () => {
    const viewer = new GDSViewer();
    const testData = new Uint8Array(/* test GDSII data */);

    // Simulate file loading
    const library = await viewer['parseGDSII'](testData);
    expect(library).toBeDefined();

    // Verify rendering works
    const stats = viewer.getLibraryStats();
    expect(stats).toBeTruthy();
    expect(stats!.structureCount).toBeGreaterThan(0);
  });
});
```

### 4.2 Performance Benchmarks

#### Benchmark Suite (`tests/benchmarks.test.ts`):

```typescript
import { describe, it, expect } from 'vitest';
import { parseGDSII } from '../src/wasm-interface';

describe('Performance Benchmarks', () => {
  it('should parse large files within acceptable time', async () => {
    const largeData = new Uint8Array(/* large GDSII file ~10MB */);

    const startTime = performance.now();
    const library = await parseGDSII(largeData);
    const endTime = performance.now();

    const parseTime = endTime - startTime;
    expect(parseTime).toBeLessThan(5000); // 5 seconds max
    expect(library).toBeDefined();
  });

  it('should handle memory efficiently', async () => {
    const initialMemory = (performance as any).memory?.usedJSHeapSize || 0;

    const testData = new Uint8Array(/* test data */);
    await parseGDSII(testData);

    const finalMemory = (performance as any).memory?.usedJSHeapSize || 0;
    const memoryIncrease = finalMemory - initialMemory;

    // Memory increase should be reasonable
    expect(memoryIncrease).toBeLessThan(testData.length * 10); // 10x overhead max
  });
});
```

## Phase 5: Error Handling and Fallback Strategies

### 5.1 WASM Loading Fallback

```typescript
// Enhanced WASM loader with fallback
export async function loadWASMModuleWithFallback(): Promise<GDSWASMModule> {
  try {
    // Try to load WASM module
    return await loadWASMModule();
  } catch (wasmError) {
    console.warn('WASM module failed to load, using fallback parser:', wasmError);

    // Return a mock WASM module that uses the placeholder parser
    return createMockWASMModule();
  }
}

function createMockWASMModule(): GDSWASMModule {
  // Return a mock implementation that delegates to the placeholder parser
  return {
    // Mock implementations that delegate to parseGDSIIPlaceholder
    _gds_parse_from_memory: () => 0,
    _gds_free_library: () => {},
    // ... other mock functions
  } as GDSWASMModule;
}
```

### 5.2 Error Recovery Mechanisms

```typescript
// Robust error handling in main parser
export async function parseGDSIIWithRecovery(data: Uint8Array): Promise<GDSLibrary> {
  let attempts = 0;
  const maxAttempts = 3;

  while (attempts < maxAttempts) {
    try {
      if (wasmLoaded && validateWASMModule()) {
        return await parseGDSII(data);
      } else {
        return await parseGDSIIPlaceholder(data);
      }
    } catch (error) {
      attempts++;
      console.warn(`Parse attempt ${attempts} failed:`, error);

      if (attempts >= maxAttempts) {
        throw new Error(`Failed to parse GDSII after ${maxAttempts} attempts: ${error}`);
      }

      // Wait before retry
      await new Promise(resolve => setTimeout(resolve, 100 * attempts));
    }
  }

  throw new Error('Unexpected error in GDSII parsing');
}
```

## Phase 6: Optimization and Performance Tuning

### 6.1 Memory Optimization Strategies

1. **Memory Pool Management**: Pre-allocate memory pools for common operations
2. **Lazy Loading**: Load structure data only when needed
3. **Data Streaming**: Process large files in chunks
4. **Garbage Collection**: Manual cleanup of WASM memory

### 6.2 Rendering Performance

1. **Spatial Indexing**: Use quad-trees for efficient element culling
2. **Level-of-Detail**: Simplify geometry when zoomed out
3. **Progressive Loading**: Load and render structures incrementally
4. **Web Workers**: Offload parsing to background threads

## Phase 7: Documentation and Maintenance

### 7.1 API Documentation

Generate comprehensive API documentation using TypeDoc:

```bash
npx typedoc src/wasm-interface.ts src/gdsii-types.ts --out docs/api
```

### 7.2 Development Guidelines

1. **Code Style**: Consistent TypeScript and C/C++ coding standards
2. **Testing**: 100% code coverage for WASM interface functions
3. **Performance**: Benchmarking for all parsing operations
4. **Memory**: Monitor and optimize memory usage patterns

## Implementation Timeline

### Week 1-2: C/C++ WASM Wrapper Development
- Implement core wrapper functions
- Create data structure adaptation layer
- Set up basic Emscripten build system

### Week 3: TypeScript Interface Enhancement
- Enhance WASM loader with error handling
- Implement data conversion layer
- Add memory management utilities

### Week 4: Integration and Testing
- Integrate WASM with main application
- Create comprehensive test suite
- Implement fallback mechanisms

### Week 5: Optimization and Polish
- Performance tuning and optimization
- Memory usage optimization
- Documentation and examples

## Success Criteria

1. **Functional**: WASM parser handles all GDSII files that the C/C++ version can handle
2. **Performance**: Parsing time within 2x of native C/C++ performance
3. **Memory**: Memory usage comparable to C/C++ implementation
4. **Compatibility**: Works with all major browsers supporting WASM
5. **Reliability**: Robust error handling and fallback mechanisms

## Risk Mitigation

1. **WASM Compatibility**: Fallback to JavaScript parser if WASM fails
2. **Browser Support**: Progressive enhancement for older browsers
3. **Memory Limits**: Implement streaming for very large files
4. **Performance**: Benchmark and optimize critical paths
5. **Security**: Validate all data from WASM module

This comprehensive plan ensures successful integration of the high-performance C/C++ GDSII parser with the modern TypeScript web interface, providing users with the best of both worlds: native-speed parsing and modern web-based visualization.