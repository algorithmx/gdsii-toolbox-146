/**
 * GDSII Utility Functions
 *
 * Utility functions for transformation matrices, bounding boxes,
 * and other GDSII-specific operations.
 */

import {
  GDSPoint,
  GDSBBox,
  GDSTransformation,
  GDSTransformMatrix,
  GDSElement,
  GDSBoundaryElement,
  GDSPathElement,
  GDSTextElement,
  GDSBoxElement,
  GDSNodeElement,
  GDSSRefElement,
  GDSARefElement,
  ElementKind
} from './gdsii-types';

// ============================================================================
// TRANSFORMATION MATRIX UTILITIES
// ============================================================================

/**
 * Creates an identity transformation matrix
 */
export function createIdentityMatrix(): GDSTransformMatrix {
  return {
    m11: 1, m12: 0, m13: 0,
    m21: 0, m22: 1, m23: 0,
    m31: 0, m32: 0, m33: 1
  };
}

/**
 * Creates a transformation matrix from GDSII STRANS parameters
 */
export function stransToMatrix(strans: GDSTransformation, origin: GDSPoint): GDSTransformMatrix {
  const angleRad = (strans.angle * Math.PI) / 180;
  const cos = Math.cos(angleRad);
  const sin = Math.sin(angleRad);
  const mag = strans.magnification;
  const refl = strans.reflection ? -1 : 1;

  // Build the transformation matrix
  const matrix: GDSTransformMatrix = {
    m11: mag * cos,
    m12: mag * sin * refl,
    m13: origin.x - (origin.x * mag * cos) - (origin.y * mag * sin * refl),
    m21: -mag * sin,
    m22: mag * cos * refl,
    m23: origin.y - (origin.x * -mag * sin) - (origin.y * mag * cos * refl),
    m31: 0,
    m32: 0,
    m33: 1
  };

  return matrix;
}

/**
 * Multiplies two transformation matrices
 */
export function multiplyMatrices(a: GDSTransformMatrix, b: GDSTransformMatrix): GDSTransformMatrix {
  return {
    m11: a.m11 * b.m11 + a.m12 * b.m21 + a.m13 * b.m31,
    m12: a.m11 * b.m12 + a.m12 * b.m22 + a.m13 * b.m32,
    m13: a.m11 * b.m13 + a.m12 * b.m23 + a.m13 * b.m33,
    m21: a.m21 * b.m11 + a.m22 * b.m21 + a.m23 * b.m31,
    m22: a.m21 * b.m12 + a.m22 * b.m22 + a.m23 * b.m32,
    m23: a.m21 * b.m13 + a.m22 * b.m23 + a.m23 * b.m33,
    m31: a.m31 * b.m11 + a.m32 * b.m21 + a.m33 * b.m31,
    m32: a.m31 * b.m12 + a.m32 * b.m22 + a.m33 * b.m32,
    m33: a.m31 * b.m13 + a.m32 * b.m23 + a.m33 * b.m33,
  };
}

/**
 * Transforms a point using a transformation matrix
 */
export function transformPoint(point: GDSPoint, matrix: GDSTransformMatrix): GDSPoint {
  return {
    x: matrix.m11 * point.x + matrix.m12 * point.y + matrix.m13,
    y: matrix.m21 * point.x + matrix.m22 * point.y + matrix.m23
  };
}

/**
 * Transforms an array of points using a transformation matrix
 */
export function transformPoints(points: GDSPoint[], matrix: GDSTransformMatrix): GDSPoint[] {
  return points.map(point => transformPoint(point, matrix));
}

/**
 * Transforms polygons (multiple polygon arrays) using a transformation matrix
 */
export function transformPolygons(polygons: GDSPoint[][], matrix: GDSTransformMatrix): GDSPoint[][] {
  return polygons.map(polygon => transformPoints(polygon, matrix));
}

// ============================================================================
// BOUNDING BOX UTILITIES
// ============================================================================

/**
 * Creates an empty bounding box
 */
export function createEmptyBBox(): GDSBBox {
  return {
    minX: Infinity,
    minY: Infinity,
    maxX: -Infinity,
    maxY: -Infinity
  };
}

/**
 * Creates a bounding box from a point
 */
export function bboxFromPoint(point: GDSPoint): GDSBBox {
  return {
    minX: point.x,
    minY: point.y,
    maxX: point.x,
    maxY: point.y
  };
}

/**
 * Creates a bounding box from multiple points
 */
export function bboxFromPoints(points: GDSPoint[]): GDSBBox {
  if (points.length === 0) {
    return createEmptyBBox();
  }

  let bbox = bboxFromPoint(points[0]);
  for (let i = 1; i < points.length; i++) {
    bbox = expandBBox(bbox, points[i]);
  }
  return bbox;
}

/**
 * Expands a bounding box to include a point
 */
export function expandBBox(bbox: GDSBBox, point: GDSPoint): GDSBBox {
  return {
    minX: Math.min(bbox.minX, point.x),
    minY: Math.min(bbox.minY, point.y),
    maxX: Math.max(bbox.maxX, point.x),
    maxY: Math.max(bbox.maxY, point.y)
  };
}

/**
 * Expands a bounding box to include another bounding box
 */
export function mergeBBoxes(bbox1: GDSBBox, bbox2: GDSBBox): GDSBBox {
  if (bbox1.minX === Infinity) return bbox2;
  if (bbox2.minX === Infinity) return bbox1;

  return {
    minX: Math.min(bbox1.minX, bbox2.minX),
    minY: Math.min(bbox1.minY, bbox2.minY),
    maxX: Math.max(bbox1.maxX, bbox2.maxX),
    maxY: Math.max(bbox1.maxY, bbox2.maxY)
  };
}

/**
 * Transforms a bounding box using a transformation matrix
 */
export function transformBBox(bbox: GDSBBox, matrix: GDSTransformMatrix): GDSBBox {
  const corners = [
    { x: bbox.minX, y: bbox.minY },
    { x: bbox.minX, y: bbox.maxY },
    { x: bbox.maxX, y: bbox.minY },
    { x: bbox.maxX, y: bbox.maxY }
  ];

  const transformedCorners = corners.map(corner => transformPoint(corner, matrix));
  return bboxFromPoints(transformedCorners);
}

/**
 * Checks if a bounding box intersects with another
 */
export function bboxIntersects(bbox1: GDSBBox, bbox2: GDSBBox): boolean {
  return !(
    bbox1.maxX < bbox2.minX ||
    bbox1.minX > bbox2.maxX ||
    bbox1.maxY < bbox2.minY ||
    bbox1.minY > bbox2.maxY
  );
}

/**
 * Checks if a point is inside a bounding box
 */
export function bboxContainsPoint(bbox: GDSBBox, point: GDSPoint): boolean {
  return (
    point.x >= bbox.minX &&
    point.x <= bbox.maxX &&
    point.y >= bbox.minY &&
    point.y <= bbox.maxY
  );
}

// ============================================================================
// ELEMENT BOUNDING BOX CALCULATION
// ============================================================================

/**
 * Calculates the bounding box for a boundary element
 */
export function calculateBoundaryBBox(element: GDSBoundaryElement): GDSBBox {
  let bbox = createEmptyBBox();

  for (const polygon of element.polygons) {
    const polygonBBox = bboxFromPoints(polygon);
    bbox = mergeBBoxes(bbox, polygonBBox);
  }

  return bbox;
}

/**
 * Calculates the bounding box for a path element
 */
export function calculatePathBBox(element: GDSPathElement): GDSBBox {
  let bbox = createEmptyBBox();

  for (const path of element.paths) {
    const pathBBox = bboxFromPoints(path);
    bbox = mergeBBoxes(bbox, pathBBox);
  }

  // Expand by width if present
  if (element.width > 0) {
    const halfWidth = element.width / 2;
    bbox.minX -= halfWidth;
    bbox.minY -= halfWidth;
    bbox.maxX += halfWidth;
    bbox.maxY += halfWidth;
  }

  return bbox;
}

/**
 * Calculates the bounding box for a text element
 */
export function calculateTextBBox(element: GDSTextElement): GDSBBox {
  // Approximate text size - this could be made more accurate
  const textWidth = element.text.length * 0.5; // Approximate width
  const textHeight = 1.0; // Approximate height

  const halfWidth = textWidth / 2;
  const halfHeight = textHeight / 2;

  return {
    minX: element.position.x - halfWidth,
    minY: element.position.y - halfHeight,
    maxX: element.position.x + halfWidth,
    maxY: element.position.y + halfHeight
  };
}

/**
 * Calculates the bounding box for a box element
 */
export function calculateBoxBBox(element: GDSBoxElement): GDSBBox {
  // Box elements have 5 points forming a rectangle
  return bboxFromPoints(element.points);
}

/**
 * Calculates the bounding box for a node element
 */
export function calculateNodeBBox(element: GDSNodeElement): GDSBBox {
  return bboxFromPoints(element.points);
}

/**
 * Calculates the bounding box for any element
 */
export function calculateElementBBox(element: GDSElement): GDSBBox {
  switch (element.type) {
    case 'boundary':
      return calculateBoundaryBBox(element as GDSBoundaryElement);
    case 'path':
      return calculatePathBBox(element as GDSPathElement);
    case 'text':
      return calculateTextBBox(element as GDSTextElement);
    case 'box':
      return calculateBoxBBox(element);
    case 'node':
      return calculateNodeBBox(element);
    case 'sref':
    case 'aref':
      // Reference elements need special handling
      return createEmptyBBox(); // Will be calculated when hierarchy is resolved
    default:
      return createEmptyBBox();
  }
}

// ============================================================================
// GEOMETRY UTILITIES
// ============================================================================

/**
 * Calculates the distance between two points
 */
export function distanceBetweenPoints(p1: GDSPoint, p2: GDSPoint): number {
  const dx = p2.x - p1.x;
  const dy = p2.y - p1.y;
  return Math.sqrt(dx * dx + dy * dy);
}

/**
 * Calculates the area of a polygon
 */
export function calculatePolygonArea(points: GDSPoint[]): number {
  if (points.length < 3) return 0;

  let area = 0;
  for (let i = 0; i < points.length; i++) {
    const j = (i + 1) % points.length;
    area += points[i].x * points[j].y;
    area -= points[j].x * points[i].y;
  }

  return Math.abs(area) / 2;
}

/**
 * Checks if a polygon is clockwise
 */
export function isPolygonClockwise(points: GDSPoint[]): boolean {
  if (points.length < 3) return false;

  let sum = 0;
  for (let i = 0; i < points.length; i++) {
    const j = (i + 1) % points.length;
    sum += (points[j].x - points[i].x) * (points[j].y + points[i].y);
  }

  return sum > 0;
}

/**
 * Simplifies a polygon by removing collinear points
 */
export function simplifyPolygon(points: GDSPoint[], tolerance: number = 1e-6): GDSPoint[] {
  if (points.length <= 3) return points;

  const simplified: GDSPoint[] = [points[0]];

  for (let i = 1; i < points.length - 1; i++) {
    const p1 = points[i - 1];
    const p2 = points[i];
    const p3 = points[i + 1];

    // Check if three points are collinear
    const area = Math.abs((p2.x - p1.x) * (p3.y - p1.y) - (p3.x - p1.x) * (p2.y - p1.y));

    if (area > tolerance) {
      simplified.push(p2);
    }
  }

  simplified.push(points[points.length - 1]);

  return simplified;
}

// ============================================================================
// VALIDATION UTILITIES
// ============================================================================

/**
 * Validates that a GDSPoint has valid coordinates
 */
export function isValidPoint(point: GDSPoint): boolean {
  return (
    typeof point.x === 'number' &&
    typeof point.y === 'number' &&
    !isNaN(point.x) &&
    !isNaN(point.y) &&
    isFinite(point.x) &&
    isFinite(point.y)
  );
}

/**
 * Validates that a GDSBBox is valid
 */
export function isValidBBox(bbox: GDSBBox): boolean {
  return (
    typeof bbox.minX === 'number' &&
    typeof bbox.minY === 'number' &&
    typeof bbox.maxX === 'number' &&
    typeof bbox.maxY === 'number' &&
    !isNaN(bbox.minX) && !isNaN(bbox.minY) && !isNaN(bbox.maxX) && !isNaN(bbox.maxY) &&
    isFinite(bbox.minX) && isFinite(bbox.minY) && isFinite(bbox.maxX) && isFinite(bbox.maxY) &&
    bbox.minX <= bbox.maxX &&
    bbox.minY <= bbox.maxY
  );
}

/**
 * Validates that a transformation matrix is valid
 */
export function isValidTransformMatrix(matrix: GDSTransformMatrix): boolean {
  const values = [
    matrix.m11, matrix.m12, matrix.m13,
    matrix.m21, matrix.m22, matrix.m23,
    matrix.m31, matrix.m32, matrix.m33
  ];

  return values.every(val =>
    typeof val === 'number' &&
    !isNaN(val) &&
    isFinite(val)
  ) && Math.abs(matrix.m33) > 1e-10; // Matrix should not be singular
}