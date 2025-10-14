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
- Expose C/C++ parsing functions to JavaScript
- Handle memory management between C/C++ and JavaScript
- Provide a stable API for the TypeScript interface

#### Key Functions to Implement:

```c
// Memory and Lifecycle Management
EMSCRIPTEN_KEEPALIVE
void* gds_parse_from_memory(uint8_t* data, int size, int* error_code);
EMSCRIPTEN_KEEPALIVE
void gds_free_library(void* library_ptr);

// Library Metadata Access
EMSCRIPTEN_KEEPALIVE
const char* gds_get_library_name(void* library_ptr);
EMSCRIPTEN_KEEPALIVE
double gds_get_user_units_per_db_unit(void* library_ptr);
EMSCRIPTEN_KEEPALIVE
double gds_get_meters_per_db_unit(void* library_ptr);
EMSCRIPTEN_KEEPALIVE
int gds_get_structure_count(void* library_ptr);

// Structure Access
EMSCRIPTEN_KEEPALIVE
const char* gds_get_structure_name(void* library_ptr, int structure_index);
EMSCRIPTEN_KEEPALIVE
int gds_get_element_count(void* library_ptr, int structure_index);
EMSCRIPTEN_KEEPALIVE
int gds_get_reference_count(void* library_ptr, int structure_index);

// Element Type Detection
EMSCRIPTEN_KEEPALIVE
int gds_get_element_type(void* library_ptr, int structure_index, int element_index);
EMSCRIPTEN_KEEPALIVE
int gds_get_element_layer(void* library_ptr, int structure_index, int element_index);
EMSCRIPTEN_KEEPALIVE
int gds_get_element_data_type(void* library_ptr, int structure_index, int element_index);

// Geometry Data Access
EMSCRIPTEN_KEEPALIVE
int gds_get_element_polygon_count(void* library_ptr, int structure_index, int element_index);
EMSCRIPTEN_KEEPALIVE
int gds_get_element_polygon_vertex_count(void* library_ptr, int structure_index, int element_index, int polygon_index);
EMSCRIPTEN_KEEPALIVE
double* gds_get_element_polygon_vertices(void* library_ptr, int structure_index, int element_index, int polygon_index);

// Path-Specific Data
EMSCRIPTEN_KEEPALIVE
double gds_get_element_path_width(void* library_ptr, int structure_index, int element_index);
EMSCRIPTEN_KEEPALIVE
int gds_get_element_path_type(void* library_ptr, int structure_index, int element_index);

// Text-Specific Data
EMSCRIPTEN_KEEPALIVE
const char* gds_get_element_text(void* library_ptr, int structure_index, int element_index);
EMSCRIPTEN_KEEPALIVE
double* gds_get_element_text_position(void* library_ptr, int structure_index, int element_index);
EMSCRIPTEN_KEEPALIVE
int gds_get_element_text_presentation(void* library_ptr, int structure_index, int element_index);

// Reference Elements (SREF/AREF)
EMSCRIPTEN_KEEPALIVE
const char* gds_get_element_reference_name(void* library_ptr, int structure_index, int element_index);
EMSCRIPTEN_KEEPALIVE
int gds_get_element_reference_position_count(void* library_ptr, int structure_index, int element_index);
EMSCRIPTEN_KEEPALIVE
double* gds_get_element_reference_positions(void* library_ptr, int structure_index, int element_index);
EMSCRIPTEN_KEEPALIVE
double* gds_get_element_transform_matrix(void* library_ptr, int structure_index, int element_index);
EMSCRIPTEN_KEEPALIVE
int gds_get_element_array_columns(void* library_ptr, int structure_index, int element_index);
EMSCRIPTEN_KEEPALIVE
int gds_get_element_array_rows(void* library_ptr, int structure_index, int element_index);

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

### 1.2 Data Structure Adaptation (`Basic/gdsio/wasm-types.h`)

#### Enhanced WASM-Compatible Structures:

```c
// Simplified structures for WASM interface
typedef struct {
    float x, y;
} wasm_vertex_t;

typedef struct {
    float min_x, min_y, max_x, max_y;
} wasm_bbox_t;

typedef struct {
    int polygon_count;
    int* vertex_counts;          // Array of vertex counts per polygon
    wasm_vertex_t** polygons;    // Array of polygon vertex arrays
} wasm_geometry_t;

typedef struct {
    element_kind kind;
    uint16_t layer;
    uint16_t data_type;

    // Geometry
    wasm_geometry_t geometry;

    // Element-specific data
    union {
        struct {
            uint16_t path_type;
            float width;
            float begin_extension;
            float end_extension;
        } path_data;

        struct {
            char text_string[512];
            wasm_vertex_t position;
            uint16_t text_type;
            uint16_t presentation_flags;
        } text_data;

        struct {
            char structure_name[256];
            int position_count;
            wasm_vertex_t* positions;
            strans_t transformation;
        } sref_data;

        struct {
            char structure_name[256];
            wasm_vertex_t corners[3];
            uint16_t columns;
            uint16_t rows;
            strans_t transformation;
        } aref_data;
    } element_specific;

    // Properties
    int property_count;
    struct {
        uint16_t attribute;
        char value[256];
    }* properties;

    // Bounding box
    wasm_bbox_t bounds;

} wasm_element_t;

typedef struct {
    char name[256];
    int element_count;
    wasm_element_t* elements;
    int reference_count;
    struct {
        char referenced_structure_name[256];
        int count;
        wasm_bbox_t* instance_bounds;
    }* references;
    wasm_bbox_t total_bounds;
} wasm_structure_t;

typedef struct {
    char name[256];
    double user_units_per_db_unit;
    double meters_per_db_unit;
    int structure_count;
    wasm_structure_t* structures;
    int ref_lib_count;
    char* ref_libraries[128];
    int font_count;
    char* fonts[4];
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

### 2.2 Data Conversion Layer

#### Enhanced Type Mapping:

```typescript
// Enhanced conversion utilities
export class GDSDataConverter {
  // Convert WASM data to TypeScript interfaces
  static convertWASMLibrary(wasmPtr: number, module: GDSWASMModule): GDSLibrary;
  static convertWASMStructure(wasmPtr: number, module: GDSWASMModule): GDSStructure;
  static convertWASMElement(wasmPtr: number, module: GDSWASMModule): GDSElement;

  // Handle complex geometry conversion
  static convertWASMPolygons(polygonPtr: number, count: number, module: GDSWASMModule): GDSPoint[][];
  static convertWASMTransform(matrixPtr: number, module: GDSWASMModule): GDSTransformation;

  // Property conversion
  static convertWASMProperties(propPtr: number, count: number, module: GDSWASMModule): GDSProperty[];

  // Validation and sanitization
  static sanitizeLibrary(library: GDSLibrary): GDSLibrary;
  static validateElement(element: GDSElement): boolean;
  static validateStructure(structure: GDSStructure): boolean;
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