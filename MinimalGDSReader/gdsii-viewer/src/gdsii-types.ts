/**
 * Enhanced GDSII Type Definitions for WASM Integration
 *
 * This file contains comprehensive type definitions that match the C/C++
 * GDSII parsing capabilities and will be used to interface with the WASM module.
 */

// ============================================================================
// BASIC GEOMETRY TYPES
// ============================================================================

export interface GDSPoint {
  x: number;
  y: number;
}

export interface GDSBBox {
  minX: number;
  minY: number;
  maxX: number;
  maxY: number;
}

// ============================================================================
// TRANSFORMATION SYSTEM
// ============================================================================

export interface GDSTransformation {
  // GDSII STRANS flags
  reflection: boolean;          // Reflect about x-axis
  absoluteMagnification: boolean;
  absoluteAngle: boolean;

  // Transformation parameters
  magnification: number;
  angle: number;                // Rotation angle in degrees
}

export interface GDSTransformMatrix {
  // 3x3 transformation matrix for complex operations
  m11: number; m12: number; m13: number;
  m21: number; m22: number; m23: number;
  m31: number; m32: number; m33: number;
}

// ============================================================================
// PROPERTY SYSTEM
// ============================================================================

export interface GDSProperty {
  attribute: number;            // Property attribute (0-127)
  value: string;                // Property value as string
}

// ============================================================================
// DATES AND METADATA
// ============================================================================

export interface GDSDate {
  year: number;
  month: number;
  day: number;
  hour: number;
  minute: number;
  second: number;
}

// ============================================================================
// ELEMENT TYPES
// ============================================================================

export interface GDSTextPresentation {
  font: number;                 // Font number (0-3)
  verticalJustification: 0 | 1 | 2;  // 0=top, 1=middle, 2=bottom
  horizontalJustification: 0 | 1 | 2; // 0=left, 1=middle, 2=right
}

// Base element interface
export interface GDSElementBase {
  // Common properties
  layer: number;
  dataType: number;
  elflags?: number;             // Element flags
  plex?: number;                // Plex number for grouping

  // Property system
  properties?: GDSProperty[];

  // Bounding box for optimization
  bounds?: GDSBBox;
}

// Boundary element (filled polygon)
export interface GDSBoundaryElement extends GDSElementBase {
  type: 'boundary';
  polygons: GDSPoint[][];       // Multiple polygons per element (cell array)
}

// Path element (polyline)
export interface GDSPathElement extends GDSElementBase {
  type: 'path';
  pathType: number;             // Path type (0,1,2,4)
  width: number;                // Path width
  beginExtension?: number;      // Extension at path beginning (type 4)
  endExtension?: number;        // Extension at path end (type 4)
  paths: GDSPoint[][];          // Multiple path segments
}

// Box element (rectangle)
export interface GDSBoxElement extends GDSElementBase {
  type: 'box';
  boxType: number;              // Box type
  points: GDSPoint[];           // 5 points for closed rectangle
}

// Node element
export interface GDSNodeElement extends GDSElementBase {
  type: 'node';
  nodeType: number;             // Node type
  points: GDSPoint[];           // Node coordinates
}

// Text element
export interface GDSTextElement extends GDSElementBase {
  type: 'text';
  text: string;
  position: GDSPoint;
  textType: number;             // Text type (0-63)
  presentation?: GDSTextPresentation;
  pathType?: number;            // Path type for text boundary
  width?: number;               // Line width for text (obsolete)
  transformation?: GDSTransformation;
}

// Structure reference (SREF)
export interface GDSSRefElement extends GDSElementBase {
  type: 'sref';
  referenceName: string;
  positions: GDSPoint[];        // Multiple positions allowed
  transformation?: GDSTransformation;
}

// Array reference (AREF)
export interface GDSARefElement extends GDSElementBase {
  type: 'aref';
  referenceName: string;
  corners: [GDSPoint, GDSPoint, GDSPoint]; // Three corner points
  columns: number;
  rows: number;
  transformation?: GDSTransformation;
}

// Union type for all elements
export type GDSElement =
  | GDSBoundaryElement
  | GDSPathElement
  | GDSBoxElement
  | GDSNodeElement
  | GDSTextElement
  | GDSSRefElement
  | GDSARefElement;

// ============================================================================
// STRUCTURE DEFINITIONS
// ============================================================================

export interface GDSStructureReference {
  referencedStructureName: string;
  count: number;                // Number of instances
  instanceBounds?: GDSBBox[];   // Bounds for each instance
}

export interface GDSStructure {
  name: string;
  elements: GDSElement[];
  references: GDSStructureReference[];

  // Metadata
  creationDate?: GDSDate;
  modificationDate?: GDSDate;

  // Bounding box including all sub-structures
  totalBounds?: GDSBBox;

  // Hierarchy information
  parentStructures?: string[];
  childStructures?: string[];
}

// ============================================================================
// LIBRARY DEFINITIONS
// ============================================================================

export interface GDSLibrary {
  name: string;

  // Units and scaling
  units: {
    userUnitsPerDatabaseUnit: number;
    metersPerDatabaseUnit: number;
  };

  // Structure collection
  structures: GDSStructure[];

  // Library metadata
  creationDate?: GDSDate;
  modificationDate?: GDSDate;

  // Reference libraries
  referenceLibraries?: string[];

  // Font information
  fonts?: string[4];            // Up to 4 fonts per GDSII spec
}

// ============================================================================
// RENDERING AND DISPLAY TYPES
// ============================================================================

export interface GDSLayer {
  number: number;
  dataType: number;
  name?: string;
  color: string;
  visible: boolean;
  opacity?: number;
  fillEnabled?: boolean;
  strokeEnabled?: boolean;
}

export interface GDSViewport {
  center: GDSPoint;
  scale: number;
  rotation: number;
}

export interface GDSRenderOptions {
  showFill: boolean;
  showStroke: boolean;
  flattenHierarchy: boolean;
  maxDepth: number;
  showText: boolean;
  showReferences: boolean;
}

// ============================================================================
// WASM INTERFACE TYPES
// ============================================================================

export interface GDSWASMMemory {
  libraryPtr: number;
  structurePtrs: number[];
  elementPtrs: number[];
  vertexPtrs: number[];
  totalSize: number;
}

export interface GDSWASMParseResult {
  success: boolean;
  library?: GDSLibrary;
  error?: string;
  memoryUsage?: GDSWASMMemory;
}

export interface GDSWASMModule {
  // Core parsing functions
  _gds_parse_from_memory: (dataPtr: number, size: number, errorCodePtr: number) => number;
  _gds_free_library: (libraryPtr: number) => void;

  // Library metadata
  _gds_get_library_name: (libraryPtr: number) => string;
  _gds_get_user_units_per_db_unit: (libraryPtr: number) => number;
  _gds_get_meters_per_db_unit: (libraryPtr: number) => number;
  _gds_get_structure_count: (libraryPtr: number) => number;

  // Structure access
  _gds_get_structure_name: (libraryPtr: number, structureIndex: number) => string;
  _gds_get_element_count: (libraryPtr: number, structureIndex: number) => number;
  _gds_get_reference_count: (libraryPtr: number, structureIndex: number) => number;

  // Element access
  _gds_get_element_type: (libraryPtr: number, structureIndex: number, elementIndex: number) => number;
  _gds_get_element_layer: (libraryPtr: number, structureIndex: number, elementIndex: number) => number;
  _gds_get_element_polygon_count: (libraryPtr: number, structureIndex: number, elementIndex: number) => number;
  _gds_get_element_polygon_vertex_count: (libraryPtr: number, structureIndex: number, elementIndex: number, polygonIndex: number) => number;
  _gds_get_element_polygon_vertices: (libraryPtr: number, structureIndex: number, elementIndex: number, polygonIndex: number) => number;

  // Text element access
  _gds_get_element_text: (libraryPtr: number, structureIndex: number, elementIndex: number) => string;
  _gds_get_element_text_presentation: (libraryPtr: number, structureIndex: number, elementIndex: number) => number;

  // Reference element access
  _gds_get_element_reference_name: (libraryPtr: number, structureIndex: number, elementIndex: number) => string;
  _gds_get_element_transform_matrix: (libraryPtr: number, structureIndex: number, elementIndex: number) => number;
  _gds_get_element_array_columns: (libraryPtr: number, structureIndex: number, elementIndex: number) => number;
  _gds_get_element_array_rows: (libraryPtr: number, structureIndex: number, elementIndex: number) => number;

  // Property access
  _gds_get_element_property_count: (libraryPtr: number, structureIndex: number, elementIndex: number) => number;
  _gds_get_element_property_attribute: (libraryPtr: number, structureIndex: number, elementIndex: number, propertyIndex: number) => number;
  _gds_get_element_property_value: (libraryPtr: number, structureIndex: number, elementIndex: number, propertyIndex: number) => string;

  // Bounding box access
  _gds_get_element_bounds: (libraryPtr: number, structureIndex: number, elementIndex: number) => number;
  _gds_get_structure_bounds: (libraryPtr: number, structureIndex: number) => number;

  // Hierarchy operations
  _gds_flatten_structure: (libraryPtr: number, structureIndex: number, maxDepth: number) => number;
  _gds_get_flattened_element_count: (libraryPtr: number, structureIndex: number) => number;

  // Error handling
  _gds_get_error_description: (errorCode: number) => string;

  // Memory management
  _malloc: (size: number) => number;
  _free: (ptr: number) => void;

  // Runtime methods
  ccall: Function;
  cwrap: Function;
}

// ============================================================================
// UTILITY TYPES
// ============================================================================

export type ElementKind =
  | 'boundary'
  | 'path'
  | 'box'
  | 'node'
  | 'text'
  | 'sref'
  | 'aref';

export type VerticalJustification = 'top' | 'middle' | 'bottom';
export type HorizontalJustification = 'left' | 'middle' | 'right';

// ============================================================================
// CONSTANTS
// ============================================================================

export const GDS_RECORD_TYPES = {
  HEADER: 0x0002,
  BGNLIB: 0x0102,
  LIBNAME: 0x0206,
  UNITS: 0x0305,
  ENDLIB: 0x0400,
  BGNSTR: 0x0502,
  STRNAME: 0x0606,
  ENDSTR: 0x0700,
  BOUNDARY: 0x0800,
  PATH: 0x0900,
  SREF: 0x0a00,
  AREF: 0x0b00,
  TEXT: 0x0c00,
  LAYER: 0x0d02,
  DATATYPE: 0x0e02,
  WIDTH: 0x0f03,
  XY: 0x1003,
  ENDEL: 0x1100,
  SNAME: 0x1206,
  COLROW: 0x1302,
  TEXTNODE: 0x1400,
  NODE: 0x1500,
  TEXTTYPE: 0x1602,
  PRESENTATION: 0x1701,
  STRING: 0x1906,
  STRANS: 0x1a01,
  MAG: 0x1b05,
  ANGLE: 0x1c05,
  BOXTYPE: 0x2e02,
  PROPATTR: 0x2b02,
  PROPVALUE: 0x2c06,
} as const;

export const DEFAULT_LAYER_COLORS = [
  '#FF6B6B', '#4ECDC4', '#45B7D1', '#96CEB4', '#FFEAA7',
  '#DDA0DD', '#98D8C8', '#F7DC6F', '#BB8FCE', '#85C1E9',
  '#F8B739', '#52B788', '#FF6B9D', '#C9E4CA', '#95E1D3'
];

export const DEFAULT_RENDER_OPTIONS: GDSRenderOptions = {
  showFill: true,
  showStroke: true,
  flattenHierarchy: false,
  maxDepth: 10,
  showText: true,
  showReferences: true,
};