/**
 * Polygon Triangulation
 * 
 * Converts GDSII polygons to triangle indices using Earcut library.
 * Required for WebGL rendering which only supports triangles.
 */

import earcut from 'earcut';
import type { GDSPoint } from '../../gdsii-types';

/**
 * Triangulates a polygon into triangle indices
 * 
 * @param polygon Array of points forming the polygon
 * @returns Array of vertex indices forming triangles (groups of 3)
 */
export function triangulate(polygon: GDSPoint[]): number[] {
  // Validate input
  if (!polygon || polygon.length < 3) {
    console.warn('Triangulation: polygon has fewer than 3 vertices');
    return [];
  }

  // Remove duplicate closing vertex if present
  let points = polygon;
  if (polygon.length > 3) {
    const first = polygon[0];
    const last = polygon[polygon.length - 1];
    if (Math.abs(first.x - last.x) < 1e-10 && Math.abs(first.y - last.y) < 1e-10) {
      points = polygon.slice(0, -1);
    }
  }

  // Convert to flat array format required by Earcut
  const flatCoords: number[] = [];
  for (const point of points) {
    flatCoords.push(point.x, point.y);
  }

  try {
    // Earcut expects flat array [x1,y1, x2,y2, ...] and returns triangle indices
    const indices = earcut(flatCoords);
    
    if (indices.length === 0) {
      console.warn('Triangulation: Earcut returned no triangles', {
        vertexCount: points.length,
        coords: flatCoords.slice(0, 20) // Log first few coords
      });
    }
    
    return indices;
  } catch (error) {
    console.error('Triangulation failed:', error, {
      vertexCount: points.length
    });
    return [];
  }
}

/**
 * Flattens polygon points into a Float32Array for WebGL
 * 
 * @param polygon Array of points
 * @returns Float32Array with interleaved [x,y, x,y, ...] coordinates
 */
export function flattenPolygon(polygon: GDSPoint[]): Float32Array {
  const flat = new Float32Array(polygon.length * 2);
  for (let i = 0; i < polygon.length; i++) {
    flat[i * 2] = polygon[i].x;
    flat[i * 2 + 1] = polygon[i].y;
  }
  return flat;
}

/**
 * Triangulates multiple polygons and returns combined vertex/index data
 * 
 * @param polygons Array of polygons to triangulate
 * @returns Combined vertices and indices for all polygons
 */
export function triangulateMultiple(polygons: GDSPoint[][]): {
  vertices: Float32Array;
  indices: Uint32Array;
  triangleCount: number;
} {
  const allVertices: number[] = [];
  const allIndices: number[] = [];
  let vertexOffset = 0;

  for (const polygon of polygons) {
    if (polygon.length < 3) continue;

    // Flatten vertices
    for (const point of polygon) {
      allVertices.push(point.x, point.y);
    }

    // Triangulate and offset indices
    const indices = triangulate(polygon);
    for (const index of indices) {
      allIndices.push(index + vertexOffset);
    }

    vertexOffset += polygon.length;
  }

  return {
    vertices: new Float32Array(allVertices),
    indices: new Uint32Array(allIndices),
    triangleCount: allIndices.length / 3
  };
}

/**
 * Validates polygon geometry
 * 
 * @param polygon Polygon to validate
 * @returns True if polygon is valid for rendering
 */
export function validatePolygon(polygon: GDSPoint[]): boolean {
  if (!polygon || polygon.length < 3) {
    return false;
  }

  // Check for NaN or Infinity
  for (const point of polygon) {
    if (!isFinite(point.x) || !isFinite(point.y)) {
      return false;
    }
  }

  return true;
}
