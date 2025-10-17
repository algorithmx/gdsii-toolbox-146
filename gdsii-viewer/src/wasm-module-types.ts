/**
 * WASM Module Interface
 * 
 * This file defines the TypeScript interface for the WASM module
 * based on the actual C functions exported from gds-wasm-adapter.c
 * 
 * Note: Emscripten prefixes exported C functions with underscore
 */

export interface GDSWASMModule {
  // =========================================================================
  // Core Parsing Functions
  // =========================================================================
  _gds_parse_from_memory: (dataPtr: number, size: number, errorCodePtr: number) => number;
  _gds_free_library: (libraryPtr: number) => void;

  // =========================================================================
  // Library Metadata
  // =========================================================================
  _gds_get_library_name: (libraryPtr: number) => string;
  _gds_get_user_units_per_db_unit: (libraryPtr: number) => number;
  _gds_get_meters_per_db_unit: (libraryPtr: number) => number;
  _gds_get_structure_count: (libraryPtr: number) => number;
  _gds_get_library_creation_date: (libraryPtr: number, dateArrayPtr: number) => void;
  _gds_get_library_modification_date: (libraryPtr: number, dateArrayPtr: number) => void;

  // =========================================================================
  // Structure Access
  // =========================================================================
  _gds_get_structure_name: (libraryPtr: number, structureIndex: number) => string;
  _gds_get_element_count: (libraryPtr: number, structureIndex: number) => number;

  // =========================================================================
  // Element Access - Basic
  // =========================================================================
  _gds_get_element_type: (libraryPtr: number, structureIndex: number, elementIndex: number) => number;
  _gds_get_element_layer: (libraryPtr: number, structureIndex: number, elementIndex: number) => number;
  _gds_get_element_data_type: (libraryPtr: number, structureIndex: number, elementIndex: number) => number;
  _gds_get_element_elflags: (libraryPtr: number, structureIndex: number, elementIndex: number) => number;
  
  // =========================================================================
  // Element Access - Geometry (Boundary/Path/Box/Node)
  // =========================================================================
  _gds_get_element_polygon_count: (libraryPtr: number, structureIndex: number, elementIndex: number) => number;
  _gds_get_element_polygon_vertex_count: (libraryPtr: number, structureIndex: number, elementIndex: number, polygonIndex: number) => number;
  _gds_get_element_polygon_vertices: (libraryPtr: number, structureIndex: number, elementIndex: number, polygonIndex: number) => number;

  // =========================================================================
  // Element Access - Path Specific
  // =========================================================================
  _gds_get_element_path_width: (libraryPtr: number, structureIndex: number, elementIndex: number) => number;
  _gds_get_element_path_type: (libraryPtr: number, structureIndex: number, elementIndex: number) => number;
  _gds_get_element_path_begin_extension: (libraryPtr: number, structureIndex: number, elementIndex: number) => number;
  _gds_get_element_path_end_extension: (libraryPtr: number, structureIndex: number, elementIndex: number) => number;

  // =========================================================================
  // Element Access - Text Specific
  // =========================================================================
  _gds_get_element_text: (libraryPtr: number, structureIndex: number, elementIndex: number) => string;
  _gds_get_element_text_position: (libraryPtr: number, structureIndex: number, elementIndex: number, xPtr: number, yPtr: number) => void;
  _gds_get_element_text_type: (libraryPtr: number, structureIndex: number, elementIndex: number) => number;
  _gds_get_element_text_presentation: (libraryPtr: number, structureIndex: number, elementIndex: number) => number;

  // =========================================================================
  // Element Access - Reference Specific (SREF/AREF)
  // =========================================================================
  _gds_get_element_reference_name: (libraryPtr: number, structureIndex: number, elementIndex: number) => string;
  _gds_get_element_array_columns: (libraryPtr: number, structureIndex: number, elementIndex: number) => number;
  _gds_get_element_array_rows: (libraryPtr: number, structureIndex: number, elementIndex: number) => number;
  _gds_get_element_reference_corners: (libraryPtr: number, structureIndex: number, elementIndex: number,
    x1Ptr: number, y1Ptr: number, x2Ptr: number, y2Ptr: number, x3Ptr: number, y3Ptr: number) => void;

  // =========================================================================
  // Element Access - Transformation
  // =========================================================================
  _gds_get_element_strans_flags: (libraryPtr: number, structureIndex: number, elementIndex: number) => number;
  _gds_get_element_magnification: (libraryPtr: number, structureIndex: number, elementIndex: number) => number;
  _gds_get_element_rotation_angle: (libraryPtr: number, structureIndex: number, elementIndex: number) => number;

  // =========================================================================
  // Element Access - Properties
  // =========================================================================
  _gds_get_element_property_count: (libraryPtr: number, structureIndex: number, elementIndex: number) => number;
  _gds_get_element_property_attribute: (libraryPtr: number, structureIndex: number, elementIndex: number, propertyIndex: number) => number;
  _gds_get_element_property_value: (libraryPtr: number, structureIndex: number, elementIndex: number, propertyIndex: number) => string;

  // =========================================================================
  // Error Handling
  // =========================================================================
  _gds_get_last_error: () => string;
  _gds_clear_error: () => void;

  // =========================================================================
  // Utility Functions
  // =========================================================================
  _gds_validate_library: (libraryPtr: number) => number;
  _gds_get_memory_usage: (totalAllocatedPtr: number, peakUsagePtr: number) => void;
  _gds_get_cache_statistics: (libraryPtr: number, totalStructuresPtr: number,
    totalElementsPtr: number, memorySizePtr: number) => void;
  _gds_parse_all_elements: (libraryPtr: number) => number;

  // =========================================================================
  // Memory Management (Emscripten standard functions)
  // =========================================================================
  _malloc: (size: number) => number;
  _free: (ptr: number) => void;

  // =========================================================================
  // Memory Views (Emscripten heap access)
  // =========================================================================
  HEAPU8?: Uint8Array;
  HEAP8?: Int8Array;
  HEAP16?: Int16Array;
  HEAPU16?: Uint16Array;
  HEAP32?: Int32Array;
  HEAPU32?: Uint32Array;
  HEAPF32?: Float32Array;
  HEAPF64?: Float64Array;

  // =========================================================================
  // Helper Functions (may or may not be present)
  // =========================================================================
  getValue?: (ptr: number, type: string) => number;
  setValue?: (ptr: number, value: number, type: string) => void;
  UTF8ToString?: (ptr: number) => string;
  stringToUTF8?: (str: string, ptr: number, maxLength: number) => void;
  writeArrayToMemory?: (array: Uint8Array, ptr: number) => void;

  // =========================================================================
  // Runtime Methods (Emscripten)
  // =========================================================================
  ccall?: Function;
  cwrap?: Function;
}
