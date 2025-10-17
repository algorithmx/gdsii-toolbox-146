/**
 * GDSII Hierarchy Resolver
 *
 * This module handles the resolution of structure references (SREF/AREF),
 * transformation matrix calculations, and hierarchy flattening for rendering.
 */

import {
  GDSLibrary,
  GDSStructure,
  GDSElement,
  GDSBoundaryElement,
  GDSPathElement,
  GDSTextElement,
  GDSSRefElement,
  GDSARefElement,
  GDSPoint,
  GDSBBox,
  GDSTransformation,
  GDSTransformMatrix,
  GDSLayer,
  GDSRenderOptions,
  DEFAULT_RENDER_OPTIONS
} from './gdsii-types';

import {
  stransToMatrix,
  multiplyMatrices,
  transformPoint,
  transformPoints,
  transformPolygons,
  calculateElementBBox,
  mergeBBoxes
} from './gdsii-utils';

// ============================================================================
// HIERARCHY RESOLUTION CACHE
// ============================================================================

interface HierarchyCache {
  resolvedStructures: Map<string, GDSElement[]>;
  flattenedStructures: Map<string, GDSElement[]>;
  structureBBoxes: Map<string, GDSBBox>;
  transformMatrices: Map<string, GDSTransformMatrix>;
}

/**
 * Creates a new hierarchy cache
 */
export function createHierarchyCache(): HierarchyCache {
  return {
    resolvedStructures: new Map(),
    flattenedStructures: new Map(),
    structureBBoxes: new Map(),
    transformMatrices: new Map()
  };
}

// ============================================================================
// STRUCTURE LOOKUP UTILITIES
// ============================================================================

/**
 * Finds a structure by name in the library
 */
export function findStructureByName(library: GDSLibrary, name: string): GDSStructure | null {
  return library.structures.find(struct => struct.name === name) || null;
}

/**
 * Gets all child structures referenced by a structure
 */
export function getChildStructures(library: GDSLibrary, structure: GDSStructure): GDSStructure[] {
  const childNames = new Set<string>();

  // Extract referenced structure names from SREF elements
  structure.elements
    .filter(el => el.type === 'sref')
    .forEach(el => {
      const sref = el as GDSSRefElement;
      childNames.add(sref.referenceName);
    });

  // Extract referenced structure names from AREF elements
  structure.elements
    .filter(el => el.type === 'aref')
    .forEach(el => {
      const aref = el as GDSARefElement;
      childNames.add(aref.referenceName);
    });

  // Convert names to structure objects
  return Array.from(childNames)
    .map(name => findStructureByName(library, name))
    .filter((struct): struct is GDSStructure => struct !== null);
}

/**
 * Gets all parent structures that reference the given structure
 */
export function getParentStructures(library: GDSLibrary, structureName: string): GDSStructure[] {
  return library.structures.filter(parent => {
    return parent.elements.some(el => {
      if (el.type === 'sref') {
        return (el as GDSSRefElement).referenceName === structureName;
      } else if (el.type === 'aref') {
        return (el as GDSARefElement).referenceName === structureName;
      }
      return false;
    });
  });
}

// ============================================================================
// TRANSFORMATION RESOLUTION
// ============================================================================

/**
 * Creates a transformation matrix for an SREF element
 */
export function createSRefTransformMatrix(
  sref: GDSSRefElement,
  origin: GDSPoint
): GDSTransformMatrix {
  const transform = sref.transformation || {
    reflection: false,
    absoluteMagnification: false,
    absoluteAngle: false,
    magnification: 1.0,
    angle: 0.0
  };

  return stransToMatrix(transform, origin);
}

/**
 * Creates transformation matrices for an AREF element
 */
export function createARefTransformMatrices(
  aref: GDSARefElement
): GDSTransformMatrix[] {
  const matrices: GDSTransformMatrix[] = [];

  const transform = aref.transformation || {
    reflection: false,
    absoluteMagnification: false,
    absoluteAngle: false,
    magnification: 1.0,
    angle: 0.0
  };

  // Create base transformation for individual elements
  const baseTransform = stransToMatrix(transform, { x: 0, y: 0 });

  // Calculate array transformation from the three corner points
  const [origin, colPoint, rowPoint] = aref.corners;

  // Column spacing vector
  const colSpacing = {
    x: (colPoint.x - origin.x) / aref.columns,
    y: (colPoint.y - origin.y) / aref.columns
  };

  // Row spacing vector
  const rowSpacing = {
    x: (rowPoint.x - origin.x) / aref.rows,
    y: (rowPoint.y - origin.y) / aref.rows
  };

  // Create transformation matrix for each instance
  for (let row = 0; row < aref.rows; row++) {
    for (let col = 0; col < aref.columns; col++) {
      // Calculate the position for this instance
      const instanceOrigin = {
        x: origin.x + col * colSpacing.x + row * rowSpacing.x,
        y: origin.y + col * colSpacing.y + row * rowSpacing.y
      };

      // Create translation matrix for this instance
      const translation = stransToMatrix(transform, instanceOrigin);

      matrices.push(translation);
    }
  }

  return matrices;
}

/**
 * Resolves the complete transformation for a structure reference
 */
export function resolveReferenceTransform(
  library: GDSLibrary,
  structureName: string,
  parentTransform: GDSTransformMatrix,
  cache: HierarchyCache
): GDSTransformMatrix {
  const cacheKey = `${structureName}_${JSON.stringify(parentTransform)}`;

  if (cache.transformMatrices.has(cacheKey)) {
    return cache.transformMatrices.get(cacheKey)!;
  }

  // For now, just return the parent transform
  // In a full implementation, we would recursively resolve all nested transforms
  cache.transformMatrices.set(cacheKey, parentTransform);
  return parentTransform;
}

// ============================================================================
// ELEMENT RESOLUTION
// ============================================================================

/**
 * Resolves an SREF element by expanding it into the referenced structure's elements
 */
export function resolveSRefElement(
  library: GDSLibrary,
  sref: GDSSRefElement,
  parentTransform: GDSTransformMatrix,
  cache: HierarchyCache
): GDSElement[] {
  const referencedStructure = findStructureByName(library, sref.referenceName);
  if (!referencedStructure) {
    console.warn(`Referenced structure not found: ${sref.referenceName}`);
    return [];
  }

  const resolvedElements: GDSElement[] = [];

  for (const position of sref.positions) {
    // Create transformation matrix for this instance
    const instanceTransform = createSRefTransformMatrix(sref, position);
    const combinedTransform = multiplyMatrices(parentTransform, instanceTransform);

    // Resolve the referenced structure with the combined transform
    const resolvedStructure = resolveStructure(
      library,
      referencedStructure,
      combinedTransform,
      cache
    );

    resolvedElements.push(...resolvedStructure);
  }

  return resolvedElements;
}

/**
 * Resolves an AREF element by expanding it into the referenced structure's elements
 */
export function resolveARefElement(
  library: GDSLibrary,
  aref: GDSARefElement,
  parentTransform: GDSTransformMatrix,
  cache: HierarchyCache
): GDSElement[] {
  const referencedStructure = findStructureByName(library, aref.referenceName);
  if (!referencedStructure) {
    console.warn(`Referenced structure not found: ${aref.referenceName}`);
    return [];
  }

  const resolvedElements: GDSElement[] = [];
  const instanceTransforms = createARefTransformMatrices(aref);

  for (const instanceTransform of instanceTransforms) {
    const combinedTransform = multiplyMatrices(parentTransform, instanceTransform);

    // Resolve the referenced structure with the combined transform
    const resolvedStructure = resolveStructure(
      library,
      referencedStructure,
      combinedTransform,
      cache
    );

    resolvedElements.push(...resolvedStructure);
  }

  return resolvedElements;
}

/**
 * Applies a transformation matrix to an element
 */
export function transformElement(
  element: GDSElement,
  transform: GDSTransformMatrix
): GDSElement {
  let transformedElement: GDSElement;

  switch (element.type) {
    case 'boundary': {
      const boundaryEl = element as GDSBoundaryElement;
      transformedElement = {
        ...boundaryEl,
        polygons: transformPolygons(boundaryEl.polygons, transform),
        bounds: undefined // Will be recalculated below
      };
      break;
    }

    case 'path': {
      const pathEl = element as GDSPathElement;
      transformedElement = {
        ...pathEl,
        paths: transformPolygons(pathEl.paths, transform),
        bounds: undefined // Will be recalculated below
      };
      break;
    }

    case 'text': {
      const textEl = element as GDSTextElement;
      transformedElement = {
        ...textEl,
        position: transformPoint(textEl.position, transform),
        bounds: undefined // Will be recalculated below
      };
      break;
    }

    case 'box': {
      const boxEl = element as import('./gdsii-types').GDSBoxElement;
      transformedElement = {
        ...boxEl,
        points: transformPoints(boxEl.points, transform),
        bounds: undefined // Will be recalculated below
      };
      break;
    }

    case 'node': {
      const nodeEl = element as import('./gdsii-types').GDSNodeElement;
      transformedElement = {
        ...nodeEl,
        points: transformPoints(nodeEl.points, transform),
        bounds: undefined // Will be recalculated below
      };
      break;
    }

    case 'sref':
    case 'aref':
      // Reference elements are handled separately and should not reach here
      return element;
  }

  // Calculate and store bounds for the transformed element
  try {
    const calculatedBounds = calculateElementBBox(transformedElement);
    if (calculatedBounds.minX !== Infinity && calculatedBounds.maxX !== -Infinity) {
      transformedElement.bounds = calculatedBounds;
    }
  } catch (error) {
    console.warn(`Failed to calculate bounds for ${transformedElement.type} element:`, error);
  }

  return transformedElement;
}

/**
 * Resolves a structure by expanding all references and applying transformations
 */
export function resolveStructure(
  library: GDSLibrary,
  structure: GDSStructure,
  transform: GDSTransformMatrix,
  cache: HierarchyCache
): GDSElement[] {
  const cacheKey = structure.name;

  if (cache.resolvedStructures.has(cacheKey)) {
    return cache.resolvedStructures.get(cacheKey)!;
  }

  const resolvedElements: GDSElement[] = [];

  for (const element of structure.elements) {
    switch (element.type) {
      case 'sref':
        const srefResolved = resolveSRefElement(library, element as GDSSRefElement, transform, cache);
        resolvedElements.push(...srefResolved);
        break;

      case 'aref':
        const arefResolved = resolveARefElement(library, element as GDSARefElement, transform, cache);
        resolvedElements.push(...arefResolved);
        break;

      default:
        const transformedElement = transformElement(element, transform);
        resolvedElements.push(transformedElement);
        break;
    }
  }

  cache.resolvedStructures.set(cacheKey, resolvedElements);
  return resolvedElements;
}

// ============================================================================
// HIERARCHY FLATTENING
// ============================================================================

/**
 * Flattens a structure hierarchy up to a maximum depth
 */
export function flattenStructure(
  library: GDSLibrary,
  structure: GDSStructure,
  options: GDSRenderOptions = DEFAULT_RENDER_OPTIONS
): GDSElement[] {
  const cache = createHierarchyCache();
  const identityMatrix: GDSTransformMatrix = {
    m11: 1, m12: 0, m13: 0,
    m21: 0, m22: 1, m23: 0,
    m31: 0, m32: 0, m33: 1
  };

  if (options.flattenHierarchy) {
    return resolveStructure(library, structure, identityMatrix, cache);
  } else {
    // Return only direct elements, but transform them
    return structure.elements.map(el => transformElement(el, identityMatrix));
  }
}

/**
 * Flattens all structures in a library
 */
export function flattenLibrary(
  library: GDSLibrary,
  options: GDSRenderOptions = DEFAULT_RENDER_OPTIONS
): Map<string, GDSElement[]> {
  const flattenedStructures = new Map<string, GDSElement[]>();

  for (const structure of library.structures) {
    const flattened = flattenStructure(library, structure, options);
    flattenedStructures.set(structure.name, flattened);
  }

  return flattenedStructures;
}

// ============================================================================
// BOUNDING BOX CALCULATION
// ============================================================================

/**
 * Calculates the bounding box for a structure including all references
 */
export function calculateStructureBBox(
  library: GDSLibrary,
  structure: GDSStructure,
  cache: HierarchyCache
): GDSBBox {
  if (cache.structureBBoxes.has(structure.name)) {
    return cache.structureBBoxes.get(structure.name)!;
  }

  const identityMatrix: GDSTransformMatrix = {
    m11: 1, m12: 0, m13: 0,
    m21: 0, m22: 1, m23: 0,
    m31: 0, m32: 0, m33: 1
  };

  const resolvedElements = resolveStructure(library, structure, identityMatrix, cache);
  let bbox = { minX: Infinity, minY: Infinity, maxX: -Infinity, maxY: -Infinity };
  let validBBoxCount = 0;

  for (const element of resolvedElements) {
    // Try to use pre-calculated bounds first
    let elementBBox = element.bounds;
    
    // If bounds don't exist or are invalid, calculate them
    if (!elementBBox || elementBBox.minX === Infinity || elementBBox.maxX === -Infinity) {
      try {
        elementBBox = calculateElementBBox(element);
      } catch (error) {
        console.warn(`Failed to calculate bbox for element ${element.type} in ${structure.name}:`, error);
        continue;
      }
    }

    // Only merge valid bounding boxes
    if (elementBBox.minX !== Infinity && elementBBox.maxX !== -Infinity) {
      bbox = mergeBBoxes(bbox, elementBBox);
      validBBoxCount++;
    }
  }

  // If no valid bboxes were found, return empty bbox instead of Infinity values
  if (validBBoxCount === 0) {
    console.warn(`No valid bounding boxes found for structure ${structure.name}`);
    bbox = { minX: 0, minY: 0, maxX: 0, maxY: 0 };
  }

  cache.structureBBoxes.set(structure.name, bbox);
  return bbox;
}

/**
 * Calculates the bounding box for the entire library
 */
export function calculateLibraryBBox(library: GDSLibrary): GDSBBox {
  const cache = createHierarchyCache();
  let libraryBBox = { minX: Infinity, minY: Infinity, maxX: -Infinity, maxY: -Infinity };
  let validStructureCount = 0;

  for (const structure of library.structures) {
    const structureBBox = calculateStructureBBox(library, structure, cache);
    
    // Only merge valid bounding boxes (not empty or Infinity)
    if (structureBBox.minX !== Infinity && structureBBox.maxX !== -Infinity) {
      libraryBBox = mergeBBoxes(libraryBBox, structureBBox);
      validStructureCount++;
    }
  }

  // If no valid structure bboxes were found, return a default bbox
  if (validStructureCount === 0) {
    console.warn('No valid bounding boxes found in library');
    libraryBBox = { minX: 0, minY: 0, maxX: 100, maxY: 100 };
  }

  return libraryBBox;
}

// ============================================================================
// LAYER EXTRACTION
// ============================================================================

/**
 * Extracts all unique layers from a flattened structure
 */
export function extractLayersFromStructure(
  flattenedElements: GDSElement[]
): Map<string, GDSLayer> {
  const layers = new Map<string, GDSLayer>();

  for (const element of flattenedElements) {
    if (element.type !== 'sref' && element.type !== 'aref') {
      const layerKey = `${element.layer}_${element.dataType}`;

      if (!layers.has(layerKey)) {
        layers.set(layerKey, {
          number: element.layer,
          dataType: element.dataType,
          color: '', // Will be set by the viewer
          visible: true
        });
      }
    }
  }

  return layers;
}

/**
 * Extracts all unique layers from the entire library
 */
export function extractLayersFromLibrary(
  library: GDSLibrary,
  options: GDSRenderOptions = DEFAULT_RENDER_OPTIONS
): Map<string, GDSLayer> {
  const flattenedStructures = flattenLibrary(library, options);
  const allLayers = new Map<string, GDSLayer>();

  for (const [structureName, elements] of flattenedStructures) {
    const structureLayers = extractLayersFromStructure(elements);

    for (const [layerKey, layer] of structureLayers) {
      if (!allLayers.has(layerKey)) {
        allLayers.set(layerKey, { ...layer });
      }
    }
  }

  return allLayers;
}

// ============================================================================
// CYCLE DETECTION
// ============================================================================

/**
 * Detects circular references in the structure hierarchy
 */
export function detectCircularReferences(library: GDSLibrary): string[][] {
  const cycles: string[][] = [];
  const visited = new Set<string>();
  const recursionStack = new Set<string>();

  function dfs(structureName: string, path: string[]): void {
    if (recursionStack.has(structureName)) {
      // Found a cycle
      const cycleStart = path.indexOf(structureName);
      cycles.push([...path.slice(cycleStart), structureName]);
      return;
    }

    if (visited.has(structureName)) {
      return;
    }

    visited.add(structureName);
    recursionStack.add(structureName);

    const structure = findStructureByName(library, structureName);
    if (structure) {
      const children = getChildStructures(library, structure);

      for (const child of children) {
        dfs(child.name, [...path, structureName]);
      }
    }

    recursionStack.delete(structureName);
  }

  for (const structure of library.structures) {
    if (!visited.has(structure.name)) {
      dfs(structure.name, []);
    }
  }

  return cycles;
}