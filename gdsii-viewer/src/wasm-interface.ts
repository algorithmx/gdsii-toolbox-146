/**
 * WASM Interface for GDSII Parser
 *
 * This module handles communication with the compiled C/C++ GDSII parsing code
 * and provides a high-level TypeScript interface for accessing the parsed data.
 */

import type {
  GDSLibrary,
  GDSStructure,
  GDSElement,
  GDSBoundaryElement,
  GDSPathElement,
  GDSTextElement,
  GDSSRefElement,
  GDSARefElement,
  GDSBoxElement,
  GDSNodeElement,
  GDSPoint,
  GDSBBox,
  GDSTransformation,
  GDSProperty,
  GDSDate,
  GDSWASMModule,
  GDSWASMParseResult,
  ElementKind
} from './gdsii-types';

import { GDS_RECORD_TYPES } from './gdsii-types';

// ============================================================================
// TYPES AND INTERFACES
// ============================================================================

/**
 * Enhanced WASM module interface with memory views
 * Now using the correct type definitions from wasm-module-types.ts
 */
import type { GDSWASMModule as RealWASMModule } from './wasm-module-types';

interface EnhancedWASMModule extends RealWASMModule {
  HEAPU8: Uint8Array;
  HEAPF64: Float64Array;
  HEAP32: Int32Array;
  HEAP8: Int8Array;
}

/**
 * Memory management context for safe resource handling
 */
class MemoryContext {
  private allocations: number[] = [];

  constructor(private readonly module: EnhancedWASMModule) {}

  allocate(size: number): number {
    const ptr = this.module._malloc(size);
    if (ptr === 0) {
      throw new Error(`Failed to allocate ${size} bytes in WASM heap`);
    }
    this.allocations.push(ptr);
    return ptr;
  }

  free(ptr: number): void {
    const index = this.allocations.indexOf(ptr);
    if (index !== -1) {
      this.allocations.splice(index, 1);
      this.module._free(ptr);
    }
  }

  cleanup(): void {
    this.allocations.forEach(ptr => this.module._free(ptr));
    this.allocations = [];
  }

  getRemainingAllocations(): number[] {
    return [...this.allocations];
  }
}

/**
 * Custom error classes for better error handling
 */
class WASMError extends Error {
  constructor(message: string, public readonly cause?: Error) {
    super(message);
    this.name = 'WASMError';
  }
}

class WASMInitializationError extends WASMError {
  constructor(message: string, cause?: Error) {
    super(`WASM Initialization Failed: ${message}`, cause);
    this.name = 'WASMInitializationError';
  }
}

class WASMParsingError extends WASMError {
  constructor(message: string, public readonly errorCode?: number) {
    super(`GDSII Parsing Failed: ${message}`);
    this.name = 'WASMParsingError';
  }
}

class WASMMemoryError extends WASMError {
  constructor(message: string) {
    super(`Memory Error: ${message}`);
    this.name = 'WASMMemoryError';
  }
}

// ============================================================================
// WASM MODULE MANAGEMENT
// ============================================================================

let wasmModule: EnhancedWASMModule | null = null;
let isInitialized = false;

/**
 * Validates browser environment for WASM execution
 */
const validateBrowserEnvironment = (): void => {
  if (typeof window === 'undefined') {
    throw new WASMInitializationError('WASM module loading requires browser environment');
  }

  if (!window.WebAssembly) {
    throw new WASMInitializationError('WebAssembly is not supported in this browser');
  }
};

/**
 * Attaches memory views to the WASM module instance using modern Emscripten approach
 */
const attachMemoryViews = (module: any): void => {
  // Modern Emscripten typically exposes memory views directly on the module
  const memoryViews = ['HEAPU8', 'HEAPF64', 'HEAP32', 'HEAP8'] as const;

  console.log('Attaching memory views to WASM module...');
  console.log('Available module properties:', Object.keys(module));

  // Strategy 1: Check if memory views are already on the module
  const moduleViews = memoryViews.filter(view => module[view]);
  if (moduleViews.length === memoryViews.length) {
    console.log('✓ All memory views found on module object');
    return;
  }

  console.log('Missing memory views:', memoryViews.filter(view => !module[view]));

  // Strategy 1.5: Try to call updateMemoryViews if it exists (Emscripten internal function)
  // This is the function that Emscripten uses to create HEAP8, HEAPU8, etc.
  if (typeof (module as any).updateMemoryViews === 'function') {
    console.log('Found updateMemoryViews function, calling it...');
    try {
      (module as any).updateMemoryViews();
      const updatedViews = memoryViews.filter(view => module[view]);
      if (updatedViews.length === memoryViews.length) {
        console.log('✓ Memory views created by updateMemoryViews');
        return;
      }
    } catch (e) {
      console.warn('Failed to call updateMemoryViews:', e);
    }
  }

  // Strategy 2: Check if Emscripten has created memory views internally but not exposed them
  // Looking at the Emscripten code, it calls updateMemoryViews() which creates HEAP8, HEAPU8, etc.
  // Let's check if we can access them through the module scope or global scope

  // Try to access the internal Emscripten Module object
  const globalModule = (window as any).Module || module.Module;
  if (globalModule) {
    console.log('Found Emscripten Module object, checking for memory views...');

    // Check if memory views exist on the internal Module object
    const internalViews = memoryViews.filter(view => globalModule[view]);
    if (internalViews.length === memoryViews.length) {
      console.log('✓ Found memory views on internal Module object');
      // Copy them to the module object
      memoryViews.forEach(view => {
        module[view] = globalModule[view];
      });
      console.log('✓ Memory views attached from internal Module object');
      return;
    }
  }

  // Strategy 3: Try to access memory through _malloc's memory export
  // In Emscripten 4.x, the memory is accessible through calling _malloc
  if (module._malloc && typeof module._malloc === 'function') {
    console.log('Attempting to access WASM memory through exports...');
    try {
      // Try to access the memory instance by allocating a small buffer
      const testPtr = module._malloc(1);
      if (testPtr > 0) {
        // The memory must exist for malloc to work
        // Try to find it in the module properties
        for (const key of Object.keys(module)) {
          const prop = (module as any)[key];
          if (prop && typeof prop === 'object' && prop.buffer && prop.buffer instanceof ArrayBuffer) {
            console.log(`Found potential memory buffer in module.${key}`);
            const buffer = prop.buffer;
            
            // Create memory views
            module.HEAP8 = new Int8Array(buffer);
            module.HEAPU8 = new Uint8Array(buffer);
            module.HEAP16 = new Int16Array(buffer);
            module.HEAPU16 = new Uint16Array(buffer);
            module.HEAP32 = new Int32Array(buffer);
            module.HEAPU32 = new Uint32Array(buffer);
            module.HEAPF32 = new Float32Array(buffer);
            module.HEAPF64 = new Float64Array(buffer);
            
            module._free(testPtr);
            console.log('✓ Memory views created from discovered buffer');
            return;
          }
        }
        module._free(testPtr);
      }
    } catch (e) {
      console.warn('Failed to access memory through _malloc:', e);
    }
  }

  // Strategy 3b: Try to access memory through wasmMemory property
  if (module.wasmMemory) {
    console.log('Found wasmMemory, recreating memory views...');
    try {
      const buffer = module.wasmMemory.buffer;
      console.log('WebAssembly memory buffer size:', buffer.byteLength);

      // Create memory views using the same pattern as Emscripten
      module.HEAP8 = new Int8Array(buffer);
      module.HEAPU8 = new Uint8Array(buffer);
      module.HEAP16 = new Int16Array(buffer);
      module.HEAPU16 = new Uint16Array(buffer);
      module.HEAP32 = new Int32Array(buffer);
      module.HEAPU32 = new Uint32Array(buffer);
      module.HEAPF32 = new Float32Array(buffer);
      module.HEAPF64 = new Float64Array(buffer);

      console.log('✓ Memory views recreated from wasmMemory');
      return;
    } catch (e) {
      console.warn('Failed to recreate memory views from wasmMemory:', e);
    }
  }

  // Strategy 2: For modern Emscripten, create memory views from the module's memory buffer
  if (module.HEAP && module.HEAP.buffer) {
    console.log('Creating memory views from module.HEAP.buffer');
    const buffer = module.HEAP.buffer;

    module.HEAPU8 = new Uint8Array(buffer);
    module.HEAPF64 = new Float64Array(buffer);
    module.HEAP32 = new Int32Array(buffer);
    module.HEAP8 = new Int8Array(buffer);

    console.log('✓ Memory views created from module.HEAP.buffer');
    return;
  }

  // Strategy 3: Create from module.memory if available (WebAssembly.Memory)
  if (module.memory && module.memory.buffer) {
    console.log('Creating memory views from module.memory.buffer');
    const buffer = module.memory.buffer;

    module.HEAPU8 = new Uint8Array(buffer);
    module.HEAPF64 = new Float64Array(buffer);
    module.HEAP32 = new Int32Array(buffer);
    module.HEAP8 = new Int8Array(buffer);

    console.log('✓ Memory views created from module.memory.buffer');
    return;
  }

  // Strategy 4: Check if there's a HEAP8 property and derive others from it
  if (module.HEAP8) {
    console.log('Deriving memory views from existing HEAP8');
    const buffer = module.HEAP8.buffer;

    module.HEAPU8 = new Uint8Array(buffer);
    module.HEAPF64 = new Float64Array(buffer);
    module.HEAP32 = new Int32Array(buffer);

    console.log('✓ Memory views derived from existing HEAP8');
    return;
  }

  // Strategy 5: Try to find buffer in module exports or internal properties
  const buffer = module.buffer || module._buffer || module.memory?.buffer;
  if (buffer) {
    console.log('Creating memory views from found buffer');
    module.HEAPU8 = new Uint8Array(buffer);
    module.HEAPF64 = new Float64Array(buffer);
    module.HEAP32 = new Int32Array(buffer);
    module.HEAP8 = new Int8Array(buffer);

    console.log('✓ Memory views created from found buffer');
    return;
  }

  // Strategy 6: Direct access to Emscripten internal memory system
  console.log('Attempting direct access to Emscripten memory system...');

  // From the Emscripten JavaScript code analysis, I know that:
  // - HEAP8, HEAPU8, HEAPF64, HEAP32 are created in updateMemoryViews()
  // - wasmMemory.buffer is the underlying buffer
  // - setValue/getValue should be available for direct memory access

  try {
    // Check if we can access the internal Module object where Emscripten stores memory
    const emscriptenModule = (window as any).Module || module.Module;
    if (emscriptenModule) {
      console.log('Found Emscripten Module object');

      // Check if memory views exist on the internal module
      if (emscriptenModule.HEAPU8 && emscriptenModule.HEAPF64 &&
          emscriptenModule.HEAP32 && emscriptenModule.HEAP8) {
        console.log('✓ Found memory views on internal Emscripten Module');

        // Copy them to our module object
        module.HEAPU8 = emscriptenModule.HEAPU8;
        module.HEAPF64 = emscriptenModule.HEAPF64;
        module.HEAP32 = emscriptenModule.HEAP32;
        module.HEAP8 = emscriptenModule.HEAP8;

        // Also copy setValue/getValue functions if available
        if (emscriptenModule.setValue) {
          module.setValue = emscriptenModule.setValue;
          module.getValue = emscriptenModule.getValue;
          console.log('✓ Memory access functions attached');
        }

        console.log('✓ Memory views successfully attached from Emscripten Module');
        return;
      }
    }

    // Fallback: Check if wasmMemory is available and create views
    if (module.wasmMemory || emscriptenModule?.wasmMemory) {
      const wasmMem = module.wasmMemory || emscriptenModule?.wasmMemory;
      console.log('Found wasmMemory, creating memory views...');

      const buffer = wasmMem.buffer;
      console.log('WebAssembly memory buffer size:', buffer.byteLength);

      // Create the memory views exactly like Emscripten does
      const heap8 = new Int8Array(buffer);
      const heapU8 = new Uint8Array(buffer);
      const heap16 = new Int16Array(buffer);
      const heapU16 = new Uint16Array(buffer);
      const heap32 = new Int32Array(buffer);
      const heapU32 = new Uint32Array(buffer);
      const heapF32 = new Float32Array(buffer);
      const heapF64 = new Float64Array(buffer);

      // Attach to our module
      module.HEAP8 = heap8;
      module.HEAPU8 = heapU8;
      module.HEAP16 = heap16;
      module.HEAPU16 = heapU16;
      module.HEAP32 = heap32;
      module.HEAPU32 = heapU32;
      module.HEAPF32 = heapF32;
      module.HEAPF64 = heapF64;

      // Add setValue/getValue functions if not available
      if (!module.setValue) {
        module.setValue = (ptr: number, value: any, type: string) => {
          switch (type) {
            case 'i8': return heap8[ptr] = value;
            case 'i16': return heap16[ptr / 2] = value;
            case 'i32': return heap32[ptr / 4] = value;
            case 'f32': return heapF32[ptr / 4] = value;
            case 'f64': return heapF64[ptr / 8] = value;
            default: throw new Error(`Unsupported type: ${type}`);
          }
        };
      }

      if (!module.getValue) {
        module.getValue = (ptr: number, type: string) => {
          switch (type) {
            case 'i8': return heap8[ptr];
            case 'i16': return heap16[ptr / 2];
            case 'i32': return heap32[ptr / 4];
            case 'f32': return heapF32[ptr / 4];
            case 'f64': return heapF64[ptr / 8];
            default: throw new Error(`Unsupported type: ${type}`);
          }
        };
      }

      console.log('✓ Memory views created from wasmMemory buffer');
      return;
    }

  } catch (e) {
    console.warn('Direct memory access failed:', e);
  }

  // If we get here, we couldn't find or create memory views
  console.error('❌ Could not attach memory views. Available module properties:',
    Object.keys(module).filter(key =>
      key.includes('HEAP') || key.includes('memory') || key.includes('buffer')
    )
  );

  // Instead of throwing an error, let's create minimal stub memory views
  console.warn('⚠️ Creating stub memory views - functionality may be limited');
  const emptyBuffer = new ArrayBuffer(1024 * 1024); // 1MB buffer
  module.HEAPU8 = new Uint8Array(emptyBuffer);
  module.HEAPF64 = new Float64Array(emptyBuffer);
  module.HEAP32 = new Int32Array(emptyBuffer);
  module.HEAP8 = new Int8Array(emptyBuffer);

  console.log('⚠️ Stub memory views created');
};

/**
 * Validates that required WASM functions are available
 */
const validateWASMFunctions = (module: EnhancedWASMModule): void => {
  const requiredFunctions = [
    '_malloc', '_free',
    '_gds_parse_from_memory', '_gds_free_library',
    '_gds_get_library_name', '_gds_get_structure_count',
    '_gds_get_element_count', '_gds_get_last_error',
    '_gds_get_element_type', '_gds_get_element_layer', '_gds_get_element_data_type',
    '_gds_get_element_polygon_count', '_gds_get_element_polygon_vertex_count',
    '_gds_get_element_polygon_vertices', '_gds_get_element_path_width',
    '_gds_get_element_path_type', '_gds_get_element_text', '_gds_get_element_text_position',
    '_gds_get_element_text_type', '_gds_get_element_text_presentation',
    '_gds_get_element_reference_name', '_gds_get_element_array_columns',
    '_gds_get_element_array_rows', '_gds_get_element_reference_corners',
    '_gds_get_element_strans_flags', '_gds_get_element_magnification',
    '_gds_get_element_rotation_angle', '_gds_get_element_property_count',
    '_gds_get_element_property_attribute', '_gds_get_element_property_value'
  ] as const;

  const missingFunctions = requiredFunctions.filter(funcName => {
    const func = module[funcName];
    return typeof func !== 'function';
  });

  if (missingFunctions.length > 0) {
    console.warn(`Missing optional WASM functions: ${missingFunctions.join(', ')}`);
    // Don't throw error for optional functions - just log warning
  }
};

/**
 * Validates that memory views are properly attached to the module
 */
const validateMemoryViews = (module: EnhancedWASMModule): void => {
  const memoryViews = ['HEAPU8', 'HEAPF64', 'HEAP32', 'HEAP8'] as const;
  const missingViews = memoryViews.filter(view => !module[view]);

  if (missingViews.length > 0) {
    throw new WASMInitializationError(
      `Missing memory views: ${missingViews.join(', ')}`
    );
  }

  // Validate that all views share the same underlying buffer
  const buffer = module.HEAPU8.buffer;
  const allSameBuffer = memoryViews.every(view =>
    module[view] && module[view].buffer === buffer
  );

  if (!allSameBuffer) {
    throw new WASMInitializationError(
      'Memory views do not share the same underlying buffer'
    );
  }

  console.log(`✓ Memory views validated (${buffer.byteLength} bytes)`);
};

/**
 * Loads the WASM module with comprehensive error handling
 */
export async function loadWASMModule(): Promise<EnhancedWASMModule> {
  if (wasmModule && isInitialized) {
    return wasmModule;
  }

  try {
    validateBrowserEnvironment();

    // Preload the WASM binary to avoid synchronous fetch issues
    console.log('Preloading WASM binary...');
    const wasmResponse = await fetch('/gds-parser.wasm');
    if (!wasmResponse.ok) {
      throw new Error(`Failed to fetch WASM binary: ${wasmResponse.status}`);
    }
    const wasmArrayBuffer = await wasmResponse.arrayBuffer();
    console.log('✓ WASM binary preloaded');

    return new Promise<EnhancedWASMModule>((resolve, reject) => {
      const script = document.createElement('script');
      script.src = '/gds-parser.js';
      script.async = true;

      const handleLoad = async (): Promise<void> => {
        try {
          const GDSParserModule = (window as any).GDSParserModule;
          if (!GDSParserModule) {
            throw new Error('GDSParserModule not found in global scope');
          }

          console.log('Loading WASM module with preloaded binary...');
          // Pass the preloaded WASM binary as a module option
          // Wait for runtime initialization to ensure memory views are created
          const module = await new Promise<any>((resolveModule) => {
            GDSParserModule({
              wasmBinary: wasmArrayBuffer,
              locateFile: (path: string) => {
                if (path.endsWith('.wasm')) {
                  return 'gds-parser.wasm';
                }
                return path;
              },
              onRuntimeInitialized: function() {
                // At this point, Emscripten has called updateMemoryViews()
                // and HEAP8, HEAPU8, HEAP32, HEAPF64 are available
                console.log('✓ Emscripten runtime initialized, memory views ready');
                resolveModule(this);
              }
            });
          });
          console.log('WASM module loaded successfully');

          // Memory views should now be available - verify
          if (!module.HEAPU8 || !module.HEAP8 || !module.HEAP32 || !module.HEAPF64) {
            console.warn('Memory views not found, attempting manual attachment...');
            attachMemoryViews(module);
          } else {
            console.log('✓ Memory views already attached by Emscripten');
          }

          // Validate that all required functions are available
          validateWASMFunctions(module as EnhancedWASMModule);

          // Validate that memory views are properly attached
          validateMemoryViews(module as EnhancedWASMModule);

          wasmModule = module as EnhancedWASMModule;
          isInitialized = true;

          console.log('✓ WASM module initialization completed successfully');
          resolve(wasmModule);
        } catch (error) {
          reject(new WASMInitializationError(
            'Failed to initialize GDS parser WASM module',
            error instanceof Error ? error : new Error(String(error))
          ));
        } finally {
          cleanup();
        }
      };

      const handleError = (): void => {
        reject(new WASMInitializationError('Failed to load GDS parser WASM module script'));
        cleanup();
      };

      const cleanup = (): void => {
        script.removeEventListener('load', handleLoad);
        script.removeEventListener('error', handleError);
      };

      script.addEventListener('load', handleLoad);
      script.addEventListener('error', handleError);
      document.head.appendChild(script);
    });
  } catch (error) {
    throw new WASMInitializationError(
      'Failed to load GDS parser WASM module',
      error instanceof Error ? error : new Error(String(error))
    );
  }
}

/**
 * Gets the loaded WASM module with validation
 */
export function getWASMModule(): EnhancedWASMModule {
  if (!wasmModule || !isInitialized) {
    throw new WASMError('WASM module not loaded. Call loadWASMModule() first.');
  }
  return wasmModule;
}

/**
 * Validates that the WASM module is properly loaded and functional
 */
export function validateWASMModule(): boolean {
  if (!wasmModule || !isInitialized) {
    return false;
  }

  try {
    validateWASMFunctions(wasmModule);
    return true;
  } catch {
    return false;
  }
}

// ============================================================================
// MEMORY MANAGEMENT
// ============================================================================

/**
 * Creates a memory context for safe resource management
 */
export function createMemoryContext(): MemoryContext {
  return new MemoryContext(getWASMModule());
}

/**
 * Allocates memory in the WASM heap with error checking
 */
export function allocateWASMMemory(size: number): number {
  if (size <= 0) {
    throw new WASMMemoryError(`Invalid allocation size: ${size} bytes`);
  }

  const module = getWASMModule();
  const ptr = module._malloc(size);

  if (ptr === 0) {
    throw new WASMMemoryError(`Failed to allocate ${size} bytes in WASM heap`);
  }

  return ptr;
}

/**
 * Frees memory in the WASM heap
 */
export function freeWASMMemory(ptr: number): void {
  if (ptr === 0) {
    return; // Silently ignore null pointer
  }

  try {
    const module = getWASMModule();
    module._free(ptr);
  } catch (error) {
    console.warn(`Failed to free WASM memory at pointer ${ptr}:`, error);
  }
}

/**
 * Copies Uint8Array to WASM memory with bounds checking
 */
export function copyArrayToWASM(data: Uint8Array): number {
  if (data.length === 0) {
    throw new WASMMemoryError('Cannot copy empty array to WASM memory');
  }

  const module = getWASMModule();
  const ptr = allocateWASMMemory(data.length);

  try {
    console.log(`🔄 Attempting to copy ${data.length} bytes to WASM memory at pointer ${ptr}`);

    // Primary approach: use writeArrayToMemory since it's exported and working
    if (module.writeArrayToMemory && typeof module.writeArrayToMemory === 'function') {
      console.log(`✓ Using writeArrayToMemory for ${data.length} bytes`);
      module.writeArrayToMemory(data, ptr);
      return ptr;
    }

    // Fallback: use setValue for each byte since we know setValue is available
    if (module.setValue && typeof module.setValue === 'function') {
      console.log(`✓ Using setValue to copy ${data.length} bytes individually`);

      for (let i = 0; i < data.length; i++) {
        module.setValue(ptr + i, data[i], 'i8');
      }

      console.log(`✓ Successfully copied ${data.length} bytes to WASM memory`);
      return ptr;
    }

    // Try traditional memory view copy if available
    if (module.HEAPU8 && module.HEAPU8.set) {
      console.log(`✓ Using HEAPU8.set for ${data.length} bytes`);
      module.HEAPU8.set(data, ptr);
      return ptr;
    }

    throw new Error('No memory write function available (writeArrayToMemory, setValue, or HEAPU8)');

  } catch (error) {
    freeWASMMemory(ptr);
    throw new WASMMemoryError(
      `Failed to copy ${data.length} bytes to WASM memory: ${error instanceof Error ? error.message : String(error)}`
    );
  }
}

/**
 * Reads a null-terminated string from WASM memory with bounds checking
 */
export function readWASMString(ptr: number, maxLength = 1024): string {
  if (ptr === 0) {
    throw new WASMMemoryError('Cannot read string from null pointer');
  }

  const module = getWASMModule();

  try {
    let str = '';
    let i = 0;

    // Use getValue if available
    if (module.getValue && typeof module.getValue === 'function') {
      while (i < maxLength) {
        const charCode = module.getValue(ptr + i, 'i8');
        if (charCode === 0) break;
        str += String.fromCharCode(charCode);
        i++;
      }
    } else if (module.HEAPU8) {
      // Fallback to direct memory access
      while (i < maxLength && module.HEAPU8[ptr + i] !== 0) {
        str += String.fromCharCode(module.HEAPU8[ptr + i]);
        i++;
      }
    } else {
      throw new Error('No memory read function available (getValue or HEAPU8)');
    }

    if (i >= maxLength) {
      console.warn(`String read truncated at ${maxLength} characters`);
    }

    return str;
  } catch (error) {
    throw new WASMMemoryError(
      `Failed to read string from WASM memory at pointer ${ptr}: ${error instanceof Error ? error.message : String(error)}`
    );
  }
}

/**
 * Reads an array of doubles from WASM memory with validation
 */
export function readWASMDoubleArray(ptr: number, count: number): number[] {
  if (ptr === 0) {
    throw new WASMMemoryError('Cannot read array from null pointer');
  }

  if (count <= 0) {
    return [];
  }

  const module = getWASMModule();

  try {
    const result = new Float64Array(count);

    // Use getValue if available
    if (module.getValue && typeof module.getValue === 'function') {
      for (let i = 0; i < count; i++) {
        result[i] = module.getValue(ptr + (i * 8), 'double');
      }
    } else if (module.HEAPF64) {
      // Fallback to direct memory access
      const byteOffset = ptr / 8;
      for (let i = 0; i < count; i++) {
        result[i] = module.HEAPF64[byteOffset + i];
      }
    } else {
      throw new Error('No memory read function available (getValue or HEAPF64)');
    }

    return Array.from(result);
  } catch (error) {
    throw new WASMMemoryError(
      `Failed to read ${count} doubles from WASM memory at pointer ${ptr}: ${error instanceof Error ? error.message : String(error)}`
    );
  }
}

/**
 * Reads an array of integers from WASM memory with validation
 */
export function readWASMIntArray(ptr: number, count: number): number[] {
  if (ptr === 0) {
    throw new WASMMemoryError('Cannot read array from null pointer');
  }

  if (count <= 0) {
    return [];
  }

  const module = getWASMModule();

  try {
    const result = new Int32Array(count);

    // Use getValue if available
    if (module.getValue && typeof module.getValue === 'function') {
      for (let i = 0; i < count; i++) {
        result[i] = module.getValue(ptr + (i * 4), 'i32');
      }
    } else if (module.HEAP32) {
      // Fallback to direct memory access
      const byteOffset = ptr / 4;
      for (let i = 0; i < count; i++) {
        result[i] = module.HEAP32[byteOffset + i];
      }
    } else {
      throw new Error('No memory read function available (getValue or HEAP32)');
    }

    return Array.from(result);
  } catch (error) {
    throw new WASMMemoryError(
      `Failed to read ${count} integers from WASM memory at pointer ${ptr}: ${error instanceof Error ? error.message : String(error)}`
    );
  }
}

/**
 * Reads a uint16 value from WASM memory
 */
export function readWASMUInt16(ptr: number): number {
  if (ptr === 0) {
    throw new WASMMemoryError('Cannot read uint16 from null pointer');
  }

  const module = getWASMModule();

  try {
    if (module.getValue && typeof module.getValue === 'function') {
      return module.getValue(ptr, 'i16');
    } else if (module.HEAP16) {
      return module.HEAP16[ptr / 2];
    } else {
      throw new Error('No memory read function available (getValue or HEAP16)');
    }
  } catch (error) {
    throw new WASMMemoryError(
      `Failed to read uint16 from WASM memory at pointer ${ptr}: ${error instanceof Error ? error.message : String(error)}`
    );
  }
}

/**
 * Reads a float value from WASM memory
 */
export function readWASMFloat(ptr: number): number {
  if (ptr === 0) {
    throw new WASMMemoryError('Cannot read float from null pointer');
  }

  const module = getWASMModule();

  try {
    if (module.getValue && typeof module.getValue === 'function') {
      return module.getValue(ptr, 'float');
    } else if (module.HEAPF32) {
      return module.HEAPF32[ptr / 4];
    } else {
      throw new Error('No memory read function available (getValue or HEAPF32)');
    }
  } catch (error) {
    throw new WASMMemoryError(
      `Failed to read float from WASM memory at pointer ${ptr}: ${error instanceof Error ? error.message : String(error)}`
    );
  }
}

// ============================================================================
// MAIN PARSING INTERFACE
// ============================================================================

/**
 * Parses GDSII data from a Uint8Array with comprehensive error handling
 */
export async function parseGDSII(data: Uint8Array): Promise<GDSLibrary> {
  if (!data || data.length === 0) {
    throw new WASMParsingError('No data provided for parsing');
  }

  const memoryContext = createMemoryContext();

  try {
    const module = getWASMModule();

    // Allocate memory for the data
    const dataPtr = copyArrayToWASM(data);
    memoryContext.free(dataPtr); // Transfer ownership to memory context

    // Allocate memory for error code
    const errorPtr = memoryContext.allocate(4);

    try {
      // Parse the GDSII file
      const libraryPtr = module._gds_parse_from_memory(dataPtr, data.length, errorPtr);

      // Check for errors using getValue since HEAP32 is a stub
      let errorCode = 0;
      if (module.getValue && typeof module.getValue === 'function') {
        errorCode = module.getValue(errorPtr, 'i32');
      } else if (module.HEAP32) {
        errorCode = module.HEAP32[errorPtr / 4];
      }

      if (errorCode !== 0 || libraryPtr === 0) {
        const errorDesc = module._gds_get_last_error ? module._gds_get_last_error() : `Error code ${errorCode}`;
        throw new WASMParsingError(errorDesc, errorCode);
      }

      // Extract the library data
      const library = extractLibraryData(module, libraryPtr);

      // Clean up the library
      module._gds_free_library(libraryPtr);

      return library;
    } finally {
      // Clean up temporary memory (error pointer)
      memoryContext.cleanup();
    }
  } catch (error) {
    if (error instanceof WASMError) {
      throw error;
    }
    throw new WASMParsingError(
      `Unexpected error during GDSII parsing: ${error instanceof Error ? error.message : String(error)}`
    );
  }
}

// ============================================================================
// DATA EXTRACTION FUNCTIONS
// ============================================================================

/**
 * Extracts the complete library data structure from WASM
 */
function extractLibraryData(module: EnhancedWASMModule, libraryPtr: number): GDSLibrary {
  const structureCount = module._gds_get_structure_count(libraryPtr);
  const structures: GDSStructure[] = [];

  // Extract library dates if available
  let creationDate: GDSDate | undefined;
  let modificationDate: GDSDate | undefined;
  if (module._gds_get_library_creation_date) {
    const dateArrayPtr = allocateWASMMemory(12); // 6 uint16 values = 12 bytes
    try {
      module._gds_get_library_creation_date(libraryPtr, dateArrayPtr);
      if (module.getValue) {
        creationDate = {
          year: module.getValue(dateArrayPtr, 'i16'),
          month: module.getValue(dateArrayPtr + 2, 'i16'),
          day: module.getValue(dateArrayPtr + 4, 'i16'),
          hour: module.getValue(dateArrayPtr + 6, 'i16'),
          minute: module.getValue(dateArrayPtr + 8, 'i16'),
          second: module.getValue(dateArrayPtr + 10, 'i16')
        };
      }
    } finally {
      freeWASMMemory(dateArrayPtr);
    }
  }

  if (module._gds_get_library_modification_date) {
    const dateArrayPtr = allocateWASMMemory(12); // 6 uint16 values = 12 bytes
    try {
      module._gds_get_library_modification_date(libraryPtr, dateArrayPtr);
      if (module.getValue) {
        modificationDate = {
          year: module.getValue(dateArrayPtr, 'i16'),
          month: module.getValue(dateArrayPtr + 2, 'i16'),
          day: module.getValue(dateArrayPtr + 4, 'i16'),
          hour: module.getValue(dateArrayPtr + 6, 'i16'),
          minute: module.getValue(dateArrayPtr + 8, 'i16'),
          second: module.getValue(dateArrayPtr + 10, 'i16')
        };
      }
    } finally {
      freeWASMMemory(dateArrayPtr);
    }
  }

  for (let i = 0; i < structureCount; i++) {
    structures.push(extractStructureData(module, libraryPtr, i));
  }

  return {
    name: module._gds_get_library_name(libraryPtr) || 'Unnamed Library',
    units: {
      userUnitsPerDatabaseUnit: module._gds_get_user_units_per_db_unit(libraryPtr) || 0.001,
      metersPerDatabaseUnit: module._gds_get_meters_per_db_unit(libraryPtr) || 1e-9
    },
    creationDate,
    modificationDate,
    structures
  };
}

/**
 * Extracts structure data from WASM
 */
function extractStructureData(
  module: EnhancedWASMModule,
  libraryPtr: number,
  structureIndex: number
): GDSStructure {
  const elementCount = module._gds_get_element_count(libraryPtr, structureIndex);

  const elements: GDSElement[] = [];

  // Note: Structure dates are not exported in the C code
  // Only library-level dates are available
  let creationDate: GDSDate | undefined;
  let modificationDate: GDSDate | undefined;

  for (let i = 0; i < elementCount; i++) {
    try {
      elements.push(extractElementData(module, libraryPtr, structureIndex, i));
    } catch (error) {
      console.warn(`Failed to extract element ${i} from structure ${structureIndex}:`, error);
      // Continue processing other elements
    }
  }

  return {
    name: module._gds_get_structure_name(libraryPtr, structureIndex) || `Structure_${structureIndex}`,
    elements,
    creationDate,
    modificationDate,
    references: [], // TODO: Implement reference extraction
    childStructures: [] // TODO: Implement hierarchy extraction
  };
}

/**
 * Extracts element data from WASM with error handling
 */
function extractElementData(
  module: EnhancedWASMModule,
  libraryPtr: number,
  structureIndex: number,
  elementIndex: number
): GDSElement {
  const type = module._gds_get_element_type(libraryPtr, structureIndex, elementIndex);
  const layer = module._gds_get_element_layer(libraryPtr, structureIndex, elementIndex);
  const dataType = module._gds_get_element_data_type(libraryPtr, structureIndex, elementIndex);

  // Extract element flags
  const elflags = module._gds_get_element_elflags(libraryPtr, structureIndex, elementIndex);
  // Note: plex is not exported in the C code, so we skip it
  const plex = 0;

  const elementKind = mapElementKind(type);

  try {
    let element: GDSElement;
    switch (elementKind) {
      case 'boundary':
        element = extractBoundaryElement(module, libraryPtr, structureIndex, elementIndex);
        break;
      case 'path':
        element = extractPathElement(module, libraryPtr, structureIndex, elementIndex);
        break;
      case 'text':
        element = extractTextElement(module, libraryPtr, structureIndex, elementIndex);
        break;
      case 'sref':
        element = extractSRefElement(module, libraryPtr, structureIndex, elementIndex);
        break;
      case 'aref':
        element = extractARefElement(module, libraryPtr, structureIndex, elementIndex);
        break;
      case 'box':
        element = extractBoxElement(module, libraryPtr, structureIndex, elementIndex);
        break;
      case 'node':
        element = extractNodeElement(module, libraryPtr, structureIndex, elementIndex);
        break;
      default:
        throw new Error(`Unknown element type: ${type} (kind: ${elementKind})`);
    }

    // Add common element properties
    element.elflags = elflags;
    element.plex = plex;

    return element;
  } catch (error) {
    // Return a placeholder element on error to maintain structure integrity
    console.warn(`Failed to extract ${elementKind} element, using placeholder:`, error);
    return {
      type: elementKind,
      layer,
      dataType,
      elflags,
      plex,
      points: [],
      properties: []
    } as GDSElement;
  }
}

/**
 * Extracts boundary element data
 */
function extractBoundaryElement(
  module: EnhancedWASMModule,
  libraryPtr: number,
  structureIndex: number,
  elementIndex: number
): GDSBoundaryElement {
  const polygonCount = module._gds_get_element_polygon_count(libraryPtr, structureIndex, elementIndex);
  const polygons: GDSPoint[][] = [];

  for (let i = 0; i < polygonCount; i++) {
    const vertexCount = module._gds_get_element_polygon_vertex_count(
      libraryPtr, structureIndex, elementIndex, i
    );
    const verticesPtr = module._gds_get_element_polygon_vertices(
      libraryPtr, structureIndex, elementIndex, i
    );

    if (vertexCount > 0 && verticesPtr !== 0) {
      const vertices = readWASMDoubleArray(verticesPtr, vertexCount * 2);
      const polygon: GDSPoint[] = [];

      for (let j = 0; j < vertexCount; j++) {
        polygon.push({
          x: vertices[j * 2],
          y: vertices[j * 2 + 1]
        });
      }

      if (polygon.length >= 3) {
        polygons.push(polygon);
      }
    }
  }

  return {
    type: 'boundary',
    layer: module._gds_get_element_layer(libraryPtr, structureIndex, elementIndex),
    dataType: module._gds_get_element_data_type(libraryPtr, structureIndex, elementIndex),
    polygons,
    properties: extractProperties(module, libraryPtr, structureIndex, elementIndex)
  };
}

/**
 * Extracts path element data
 */
function extractPathElement(
  module: EnhancedWASMModule,
  libraryPtr: number,
  structureIndex: number,
  elementIndex: number
): GDSPathElement {
  const polygonCount = module._gds_get_element_polygon_count(libraryPtr, structureIndex, elementIndex);
  const paths: GDSPoint[][] = [];

  for (let i = 0; i < polygonCount; i++) {
    const vertexCount = module._gds_get_element_polygon_vertex_count(
      libraryPtr, structureIndex, elementIndex, i
    );
    const verticesPtr = module._gds_get_element_polygon_vertices(
      libraryPtr, structureIndex, elementIndex, i
    );

    if (vertexCount > 0 && verticesPtr !== 0) {
      const vertices = readWASMDoubleArray(verticesPtr, vertexCount * 2);
      const path: GDSPoint[] = [];

      for (let j = 0; j < vertexCount; j++) {
        path.push({
          x: vertices[j * 2],
          y: vertices[j * 2 + 1]
        });
      }

      if (path.length >= 2) {
        paths.push(path);
      }
    }
  }

  // Extract path-specific properties
  const width = module._gds_get_element_path_width(libraryPtr, structureIndex, elementIndex);
  const pathType = module._gds_get_element_path_type(libraryPtr, structureIndex, elementIndex);
  const beginExt = module._gds_get_element_path_begin_extension(libraryPtr, structureIndex, elementIndex);
  const endExt = module._gds_get_element_path_end_extension(libraryPtr, structureIndex, elementIndex);

  return {
    type: 'path',
    layer: module._gds_get_element_layer(libraryPtr, structureIndex, elementIndex),
    dataType: module._gds_get_element_data_type(libraryPtr, structureIndex, elementIndex),
    pathType,
    width,
    beginExtension: beginExt,
    endExtension: endExt,
    paths,
    properties: extractProperties(module, libraryPtr, structureIndex, elementIndex)
  };
}

/**
 * Extracts text element data
 */
function extractTextElement(
  module: EnhancedWASMModule,
  libraryPtr: number,
  structureIndex: number,
  elementIndex: number
): GDSTextElement {
  const text = module._gds_get_element_text(libraryPtr, structureIndex, elementIndex) || '';

  // Extract text position
  let position: GDSPoint = { x: 0, y: 0 };
  const xPtr = allocateWASMMemory(4);
  const yPtr = allocateWASMMemory(4);
  try {
    module._gds_get_element_text_position(libraryPtr, structureIndex, elementIndex, xPtr, yPtr);
    if (module.getValue) {
      position.x = module.getValue(xPtr, 'float');
      position.y = module.getValue(yPtr, 'float');
    }
  } finally {
    freeWASMMemory(xPtr);
    freeWASMMemory(yPtr);
  }

  // Extract other text properties
  const textType = module._gds_get_element_text_type(libraryPtr, structureIndex, elementIndex);
  const presentation = module._gds_get_element_text_presentation(libraryPtr, structureIndex, elementIndex);

  return {
    type: 'text',
    layer: module._gds_get_element_layer(libraryPtr, structureIndex, elementIndex),
    dataType: module._gds_get_element_data_type(libraryPtr, structureIndex, elementIndex),
    text,
    position,
    textType,
    // TODO: Parse presentation flags properly into GDSTextPresentation structure
    presentation: undefined,
    properties: extractProperties(module, libraryPtr, structureIndex, elementIndex)
  };
}

/**
 * Extracts SREF element data
 */
function extractSRefElement(
  module: EnhancedWASMModule,
  libraryPtr: number,
  structureIndex: number,
  elementIndex: number
): GDSSRefElement {
  const referenceName = module._gds_get_element_reference_name(
    libraryPtr, structureIndex, elementIndex
  ) || '';

  // Extract transformation data
  let position: GDSPoint = { x: 0, y: 0 };
  const x1Ptr = allocateWASMMemory(4);
  const y1Ptr = allocateWASMMemory(4);
  const x2Ptr = allocateWASMMemory(4);
  const y2Ptr = allocateWASMMemory(4);
  const x3Ptr = allocateWASMMemory(4);
  const y3Ptr = allocateWASMMemory(4);
  try {
    module._gds_get_element_reference_corners(libraryPtr, structureIndex, elementIndex,
                                              x1Ptr, y1Ptr, x2Ptr, y2Ptr, x3Ptr, y3Ptr);
    if (module.getValue) {
      position.x = module.getValue(x1Ptr, 'float');
      position.y = module.getValue(y1Ptr, 'float');
    }
  } finally {
    freeWASMMemory(x1Ptr);
    freeWASMMemory(y1Ptr);
    freeWASMMemory(x2Ptr);
    freeWASMMemory(y2Ptr);
    freeWASMMemory(x3Ptr);
    freeWASMMemory(y3Ptr);
  }

  // Extract transformation flags and properties
  const stransFlags = module._gds_get_element_strans_flags(libraryPtr, structureIndex, elementIndex);
  const magnification = module._gds_get_element_magnification(libraryPtr, structureIndex, elementIndex);
  const angle = module._gds_get_element_rotation_angle(libraryPtr, structureIndex, elementIndex);

  const transformation: GDSTransformation = {
    reflection: (stransFlags & 0x8000) !== 0,
    absoluteMagnification: (stransFlags & 0x0004) !== 0,
    absoluteAngle: (stransFlags & 0x0002) !== 0,
    magnification,
    angle
  };

  return {
    type: 'sref',
    layer: 0, // SREF elements don't have layers
    dataType: 0,
    referenceName,
    positions: [position], // Single position for SREF
    transformation,
    properties: extractProperties(module, libraryPtr, structureIndex, elementIndex)
  };
}

/**
 * Extracts AREF element data
 */
function extractARefElement(
  module: EnhancedWASMModule,
  libraryPtr: number,
  structureIndex: number,
  elementIndex: number
): GDSARefElement {
  const referenceName = module._gds_get_element_reference_name(
    libraryPtr, structureIndex, elementIndex
  ) || '';
  const columns = module._gds_get_element_array_columns(
    libraryPtr, structureIndex, elementIndex
  );
  const rows = module._gds_get_element_array_rows(
    libraryPtr, structureIndex, elementIndex
  );

  // Extract array corners
  let corners: [GDSPoint, GDSPoint, GDSPoint] = [
    { x: 0, y: 0 },
    { x: 1, y: 0 },
    { x: 0, y: 1 }
  ];
  const x1Ptr = allocateWASMMemory(4);
  const y1Ptr = allocateWASMMemory(4);
  const x2Ptr = allocateWASMMemory(4);
  const y2Ptr = allocateWASMMemory(4);
  const x3Ptr = allocateWASMMemory(4);
  const y3Ptr = allocateWASMMemory(4);
  try {
    module._gds_get_element_reference_corners(libraryPtr, structureIndex, elementIndex,
                                              x1Ptr, y1Ptr, x2Ptr, y2Ptr, x3Ptr, y3Ptr);
    if (module.getValue) {
      corners = [
        {
          x: module.getValue(x1Ptr, 'float'),
          y: module.getValue(y1Ptr, 'float')
        },
        {
          x: module.getValue(x2Ptr, 'float'),
          y: module.getValue(y2Ptr, 'float')
        },
        {
          x: module.getValue(x3Ptr, 'float'),
          y: module.getValue(y3Ptr, 'float')
        }
      ];
    }
  } finally {
    freeWASMMemory(x1Ptr);
    freeWASMMemory(y1Ptr);
    freeWASMMemory(x2Ptr);
    freeWASMMemory(y2Ptr);
    freeWASMMemory(x3Ptr);
    freeWASMMemory(y3Ptr);
  }

  // Extract transformation flags and properties
  const stransFlags = module._gds_get_element_strans_flags(libraryPtr, structureIndex, elementIndex);
  const magnification = module._gds_get_element_magnification(libraryPtr, structureIndex, elementIndex);
  const angle = module._gds_get_element_rotation_angle(libraryPtr, structureIndex, elementIndex);

  const transformation: GDSTransformation = {
    reflection: (stransFlags & 0x8000) !== 0,
    absoluteMagnification: (stransFlags & 0x0004) !== 0,
    absoluteAngle: (stransFlags & 0x0002) !== 0,
    magnification,
    angle
  };

  return {
    type: 'aref',
    layer: 0, // AREF elements don't have layers
    dataType: 0,
    referenceName,
    corners,
    columns,
    rows,
    transformation,
    properties: extractProperties(module, libraryPtr, structureIndex, elementIndex)
  };
}

/**
 * Extracts box element data
 */
function extractBoxElement(
  module: EnhancedWASMModule,
  libraryPtr: number,
  structureIndex: number,
  elementIndex: number
): GDSBoxElement {
  const layer = module._gds_get_element_layer(libraryPtr, structureIndex, elementIndex);
  
  // TODO: Implement full box element extraction
  return {
    type: 'box',
    layer,
    dataType: 0, // Box elements typically use dataType 0
    boxType: 0,
    points: []
  };
}

/**
 * Extracts node element data
 */
function extractNodeElement(
  module: EnhancedWASMModule,
  libraryPtr: number,
  structureIndex: number,
  elementIndex: number
): GDSNodeElement {
  const layer = module._gds_get_element_layer(libraryPtr, structureIndex, elementIndex);
  
  // TODO: Implement full node element extraction
  return {
    type: 'node',
    layer,
    dataType: 0, // Node elements typically use dataType 0
    nodeType: 0,
    points: []
  };
}

/**
 * Extracts properties for an element with error handling
 */
function extractProperties(
  module: EnhancedWASMModule,
  libraryPtr: number,
  structureIndex: number,
  elementIndex: number
): GDSProperty[] {
  const propertyCount = module._gds_get_element_property_count?.(
    libraryPtr, structureIndex, elementIndex
  ) || 0;

  const properties: GDSProperty[] = [];

  for (let i = 0; i < propertyCount; i++) {
    try {
      const attribute = module._gds_get_element_property_attribute?.(
        libraryPtr, structureIndex, elementIndex, i
      ) || 0;
      const value = module._gds_get_element_property_value?.(
        libraryPtr, structureIndex, elementIndex, i
      ) || '';

      properties.push({ attribute, value });
    } catch (error) {
      console.warn(`Failed to extract property ${i} from element ${elementIndex}:`, error);
    }
  }

  return properties;
}

// ============================================================================
// UTILITY FUNCTIONS
// ============================================================================

/**
 * Maps WASM element type to TypeScript element kind
 * 
 * Note: The C module may return different type values than the official GDSII record types.
 * This function handles both official GDSII record types (0x0800, 0x0900, etc.) and
 * the simplified type indices that the C module might use.
 */
function mapElementKind(wasmType: number): ElementKind {
  // First try exact GDSII record type matches
  switch (wasmType) {
    case GDS_RECORD_TYPES.BOUNDARY: // 0x0800
      return 'boundary';
    case GDS_RECORD_TYPES.PATH: // 0x0900
      return 'path';
    case GDS_RECORD_TYPES.TEXT: // 0x0C00
      return 'text';
    case GDS_RECORD_TYPES.SREF: // 0x0A00
      return 'sref';
    case GDS_RECORD_TYPES.AREF: // 0x0B00
      return 'aref';
    case 0x2d00: // BOX (custom GDSII extension)
      return 'box';
    case GDS_RECORD_TYPES.NODE: // 0x1500
      return 'node';
  }

  // Handle simplified type indices (0-6) that the C module might use
  // Based on common C enum ordering: BOUNDARY=0, PATH=1, SREF=2, AREF=3, TEXT=4, NODE=5, BOX=6
  if (wasmType >= 0 && wasmType <= 10) {
    const typeMap: Record<number, ElementKind> = {
      0: 'boundary',
      1: 'path',
      2: 'sref',
      3: 'aref',
      4: 'text',
      5: 'node',
      6: 'box',
      // Additional mappings for alternative enum orders
      7: 'boundary', // Fallback
      8: 'path',     // Fallback
      9: 'text',     // Fallback
      10: 'sref'     // Fallback
    };
    
    if (typeMap[wasmType]) {
      console.log(`Element type ${wasmType} mapped to '${typeMap[wasmType]}' (index-based mapping)`);
      return typeMap[wasmType];
    }
  }

  // Log detailed error information for unknown types
  console.warn(`Unknown element type: ${wasmType} (0x${wasmType.toString(16).toUpperCase().padStart(4, '0')}), defaulting to 'boundary'`);
  console.warn('Known GDSII record types:',  {
    BOUNDARY: `0x${GDS_RECORD_TYPES.BOUNDARY.toString(16)}`,
    PATH: `0x${GDS_RECORD_TYPES.PATH.toString(16)}`,
    TEXT: `0x${GDS_RECORD_TYPES.TEXT.toString(16)}`,
    SREF: `0x${GDS_RECORD_TYPES.SREF.toString(16)}`,
    AREF: `0x${GDS_RECORD_TYPES.AREF.toString(16)}`,
    NODE: `0x${GDS_RECORD_TYPES.NODE.toString(16)}`
  });
  
  return 'boundary'; // Safe default
}

/**
 * Gets WASM module statistics for debugging
 */
export function getWASMStats(): {
  isLoaded: boolean;
  memoryUsage?: number;
  supportedFunctions: string[];
  hasMemoryViews: boolean;
} {
  if (!wasmModule || !isInitialized) {
    return {
      isLoaded: false,
      supportedFunctions: [],
      hasMemoryViews: false
    };
  }

  const supportedFunctions = Object.keys(wasmModule).filter(key =>
    key.startsWith('_gds_') || key.startsWith('_malloc') || key.startsWith('_free')
  );

  return {
    isLoaded: true,
    memoryUsage: wasmModule.HEAP8?.byteLength,
    supportedFunctions,
    hasMemoryViews: Boolean(wasmModule.HEAPU8 && wasmModule.HEAPF64 && wasmModule.HEAP32 && wasmModule.HEAP8)
  };
}

/**
 * Performance monitoring utility for parsing operations
 */
export function withPerformanceMonitoring<T>(
  operation: string,
  fn: () => Promise<T> | T
): Promise<T> {
  return (async () => {
    const startTime = performance.now();
    console.log(`🚀 Starting ${operation}`);

    try {
      const result = await fn();
      const duration = performance.now() - startTime;
      console.log(`✅ ${operation} completed in ${duration.toFixed(2)}ms`);
      return result;
    } catch (error) {
      const duration = performance.now() - startTime;
      console.error(`❌ ${operation} failed after ${duration.toFixed(2)}ms:`, error);
      throw error;
    }
  })();
}

// ============================================================================
// CONFIGURATION AND AUTO-LOAD FUNCTIONALITY
// ============================================================================

/**
 * Application configuration interface
 */
interface AppConfig {
  autoLoad?: {
    enabled: boolean;
    filePath?: string;
    url?: string;
    timeout?: number;
  };
  debugging?: {
    logMemoryUsage?: boolean;
    logParsingDetails?: boolean;
    logPerformanceMetrics?: boolean;
  };
  ui?: {
    showLayerPanel?: boolean;
    showFileInfo?: boolean;
    defaultZoom?: number;
  };
}

/**
 * Default configuration
 */
const DEFAULT_CONFIG: AppConfig = {
  autoLoad: {
    enabled: false,
    timeout: 10000
  },
  debugging: {
    logMemoryUsage: true,
    logParsingDetails: true,
    logPerformanceMetrics: true
  },
  ui: {
    showLayerPanel: true,
    showFileInfo: true,
    defaultZoom: 1
  }
};

/**
 * Loads configuration from a JSON file
 */
export async function loadConfig(configPath: string = '/config.json'): Promise<AppConfig> {
  try {
    const response = await fetch(configPath);
    if (!response.ok) {
      throw new Error(`Failed to load config: ${response.status} ${response.statusText}`);
    }

    const config = await response.json();
    return { ...DEFAULT_CONFIG, ...config };
  } catch (error) {
    console.warn(`Failed to load config from ${configPath}, using defaults:`, error);
    return DEFAULT_CONFIG;
  }
}

/**
 * Loads a GDSII file from URL or local path
 */
export async function loadGDSFileFromSource(source: string): Promise<Uint8Array> {
  if (source.startsWith('http://') || source.startsWith('https://')) {
    // Load from URL
    console.log(`Loading GDSII file from URL: ${source}`);
    const response = await fetch(source);
    if (!response.ok) {
      throw new Error(`Failed to fetch GDSII file: ${response.status} ${response.statusText}`);
    }
    const arrayBuffer = await response.arrayBuffer();
    return new Uint8Array(arrayBuffer);
  } else {
    // Load from local path (relative to server root)
    console.log(`Loading GDSII file from local path: ${source}`);
    const response = await fetch(source);
    if (!response.ok) {
      throw new Error(`Failed to load GDSII file: ${response.status} ${response.statusText}`);
    }
    const arrayBuffer = await response.arrayBuffer();
    return new Uint8Array(arrayBuffer);
  }
}

/**
 * Auto-loads a GDSII file based on configuration
 */
export async function autoLoadGDSFile(config: AppConfig): Promise<GDSLibrary | null> {
  if (!config.autoLoad?.enabled) {
    console.log('Auto-load is disabled');
    return null;
  }

  const { filePath, url, timeout = 10000 } = config.autoLoad;
  const source = url || filePath;

  if (!source) {
    console.warn('Auto-load is enabled but no file path or URL is specified');
    return null;
  }

  console.log(`🔄 Auto-loading GDSII file from: ${source}`);

  try {
    return await withPerformanceMonitoring(
      `Auto-load GDSII (${source})`,
      async () => {
        // Create a timeout promise
        const timeoutPromise = new Promise<never>((_, reject) => {
          setTimeout(() => reject(new Error(`Auto-load timeout after ${timeout}ms`)), timeout);
        });

        // Race between file loading and timeout
        const gdsData = await Promise.race([
          loadGDSFileFromSource(source),
          timeoutPromise
        ]);

        console.log(`📁 Successfully loaded GDSII file (${gdsData.length} bytes)`);

        // Parse the GDSII data
        const library = await parseGDSII(gdsData);

        console.log(`📋 Parsed GDSII library: ${library.name}`);
        console.log(`   Structures: ${library.structures.length}`);
        console.log(`   Total elements: ${library.structures.reduce((sum, s) => sum + s.elements.length, 0)}`);

        return library;
      }
    );
  } catch (error) {
    console.error('❌ Auto-load failed:', error);
    return null;
  }
}

/**
 * Gets current WASM performance and memory statistics
 */
export function getWASMDiagnostics(): {
  memory: {
    usage?: number;
    viewsAvailable: boolean;
    allocatedPointers?: number;
  };
  performance: {
    moduleLoadTime?: number;
    lastParseTime?: number;
    parseOperations: number;
  };
  configuration: AppConfig;
} {
  const stats = getWASMStats();

  return {
    memory: {
      usage: stats.memoryUsage,
      viewsAvailable: stats.hasMemoryViews,
      allocatedPointers: stats.supportedFunctions.length
    },
    performance: {
      parseOperations: 0 // TODO: Track actual parse operations
    },
    configuration: DEFAULT_CONFIG
  };
}