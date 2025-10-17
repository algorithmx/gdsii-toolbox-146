/**
 * Spatial Index Implementation (QuadTree)
 * 
 * Provides efficient spatial queries for viewport culling and element picking.
 * Uses a QuadTree data structure to organize elements by their bounding boxes.
 */

import type { GDSBBox, GDSElement, GDSPoint } from '../gdsii-types';
import { bboxIntersects, bboxContainsPoint } from '../gdsii-utils';

/**
 * Element with spatial information for indexing
 */
export interface SpatialElement {
  element: GDSElement;
  bounds: GDSBBox;
  structureName?: string;
  elementIndex?: number;
}

/**
 * QuadTree node for spatial indexing
 */
export class QuadTree {
  private bounds: GDSBBox;
  private capacity: number;
  private elements: SpatialElement[];
  private divided: boolean;
  private children: {
    nw: QuadTree | null;
    ne: QuadTree | null;
    sw: QuadTree | null;
    se: QuadTree | null;
  };
  private depth: number;
  private maxDepth: number;

  /**
   * Creates a new QuadTree node
   * @param bounds Bounding box for this node
   * @param capacity Maximum elements before subdivision (default: 8)
   * @param maxDepth Maximum tree depth (default: 10)
   * @param depth Current depth (default: 0)
   */
  constructor(
    bounds: GDSBBox,
    capacity: number = 8,
    maxDepth: number = 10,
    depth: number = 0
  ) {
    this.bounds = bounds;
    this.capacity = capacity;
    this.elements = [];
    this.divided = false;
    this.children = {
      nw: null,
      ne: null,
      sw: null,
      se: null
    };
    this.depth = depth;
    this.maxDepth = maxDepth;
  }

  /**
   * Inserts an element into the quadtree
   * @param spatialElement Element with spatial information
   * @returns true if inserted successfully
   */
  insert(spatialElement: SpatialElement): boolean {
    // Check if element intersects this node's bounds
    if (!bboxIntersects(spatialElement.bounds, this.bounds)) {
      return false;
    }

    // If we have capacity and haven't subdivided, add here
    if (this.elements.length < this.capacity && !this.divided) {
      this.elements.push(spatialElement);
      return true;
    }

    // Don't subdivide beyond max depth
    if (this.depth >= this.maxDepth) {
      this.elements.push(spatialElement);
      return true;
    }

    // Subdivide if we haven't already
    if (!this.divided) {
      this.subdivide();
    }

    // Try to insert into children
    let inserted = false;
    if (this.children.nw?.insert(spatialElement)) inserted = true;
    if (this.children.ne?.insert(spatialElement)) inserted = true;
    if (this.children.sw?.insert(spatialElement)) inserted = true;
    if (this.children.se?.insert(spatialElement)) inserted = true;

    return inserted;
  }

  /**
   * Queries elements that intersect with the given range
   * @param range Bounding box to query
   * @param found Array to accumulate results (optional)
   * @param seenElements Set to track already-found elements (optional)
   * @returns Array of elements in range
   */
  query(
    range: GDSBBox,
    found: SpatialElement[] = [],
    seenElements: Set<GDSElement> = new Set()
  ): SpatialElement[] {
    // If range doesn't intersect this node, return
    if (!bboxIntersects(range, this.bounds)) {
      return found;
    }

    // Check elements at this node
    for (const spatialElement of this.elements) {
      if (bboxIntersects(spatialElement.bounds, range)) {
        // Only add if we haven't seen this element before
        if (!seenElements.has(spatialElement.element)) {
          seenElements.add(spatialElement.element);
          found.push(spatialElement);
        }
      }
    }

    // Query children if subdivided
    if (this.divided) {
      this.children.nw?.query(range, found, seenElements);
      this.children.ne?.query(range, found, seenElements);
      this.children.sw?.query(range, found, seenElements);
      this.children.se?.query(range, found, seenElements);
    }

    return found;
  }

  /**
   * Queries elements at a specific point
   * @param point Point to query
   * @param found Array to accumulate results (optional)
   * @param seenElements Set to track already-found elements (optional)
   * @returns Array of elements containing point
   */
  queryPoint(
    point: GDSPoint,
    found: SpatialElement[] = [],
    seenElements: Set<GDSElement> = new Set()
  ): SpatialElement[] {
    // If point not in bounds, return
    if (!bboxContainsPoint(this.bounds, point)) {
      return found;
    }

    // Check elements at this node
    for (const spatialElement of this.elements) {
      if (bboxContainsPoint(spatialElement.bounds, point)) {
        // Only add if we haven't seen this element before
        if (!seenElements.has(spatialElement.element)) {
          seenElements.add(spatialElement.element);
          found.push(spatialElement);
        }
      }
    }

    // Query children if subdivided
    if (this.divided) {
      this.children.nw?.queryPoint(point, found, seenElements);
      this.children.ne?.queryPoint(point, found, seenElements);
      this.children.sw?.queryPoint(point, found, seenElements);
      this.children.se?.queryPoint(point, found, seenElements);
    }

    return found;
  }

  /**
   * Subdivides this node into four children
   */
  private subdivide(): void {
    const { minX, minY, maxX, maxY } = this.bounds;
    const midX = (minX + maxX) / 2;
    const midY = (minY + maxY) / 2;

    const childDepth = this.depth + 1;

    // Northwest quadrant
    this.children.nw = new QuadTree(
      { minX, minY: midY, maxX: midX, maxY },
      this.capacity,
      this.maxDepth,
      childDepth
    );

    // Northeast quadrant
    this.children.ne = new QuadTree(
      { minX: midX, minY: midY, maxX, maxY },
      this.capacity,
      this.maxDepth,
      childDepth
    );

    // Southwest quadrant
    this.children.sw = new QuadTree(
      { minX, minY, maxX: midX, maxY: midY },
      this.capacity,
      this.maxDepth,
      childDepth
    );

    // Southeast quadrant
    this.children.se = new QuadTree(
      { minX: midX, minY, maxX, maxY: midY },
      this.capacity,
      this.maxDepth,
      childDepth
    );

    // Move existing elements to children
    const existingElements = [...this.elements];
    this.elements = [];
    
    for (const element of existingElements) {
      this.children.nw.insert(element);
      this.children.ne.insert(element);
      this.children.sw.insert(element);
      this.children.se.insert(element);
    }

    this.divided = true;
  }

  /**
   * Clears all elements from the tree
   */
  clear(): void {
    this.elements = [];
    this.divided = false;
    this.children = {
      nw: null,
      ne: null,
      sw: null,
      se: null
    };
  }

  /**
   * Gets statistics about the tree
   */
  getStatistics(): {
    totalElements: number;
    totalNodes: number;
    maxDepth: number;
    avgElementsPerNode: number;
  } {
    let totalElements = this.elements.length;
    let totalNodes = 1;
    let maxDepth = this.depth;

    if (this.divided) {
      const nwStats = this.children.nw!.getStatistics();
      const neStats = this.children.ne!.getStatistics();
      const swStats = this.children.sw!.getStatistics();
      const seStats = this.children.se!.getStatistics();

      totalElements += nwStats.totalElements + neStats.totalElements +
                       swStats.totalElements + seStats.totalElements;
      totalNodes += nwStats.totalNodes + neStats.totalNodes +
                    swStats.totalNodes + seStats.totalNodes;
      maxDepth = Math.max(
        nwStats.maxDepth,
        neStats.maxDepth,
        swStats.maxDepth,
        seStats.maxDepth
      );
    }

    return {
      totalElements,
      totalNodes,
      maxDepth,
      avgElementsPerNode: totalElements / totalNodes
    };
  }

  /**
   * Gets the bounds of this node
   */
  getBounds(): GDSBBox {
    return { ...this.bounds };
  }

  /**
   * Checks if this node is subdivided
   */
  isSubdivided(): boolean {
    return this.divided;
  }

  /**
   * Gets the number of elements at this node (not including children)
   */
  getElementCount(): number {
    return this.elements.length;
  }
}

/**
 * Helper function to create a QuadTree from a bounding box
 */
export function createQuadTree(
  bounds: GDSBBox,
  capacity: number = 8,
  maxDepth: number = 10
): QuadTree {
  return new QuadTree(bounds, capacity, maxDepth);
}

/**
 * Helper function to build a QuadTree from an array of spatial elements
 */
export function buildQuadTree(
  elements: SpatialElement[],
  bounds: GDSBBox,
  capacity: number = 8,
  maxDepth: number = 10
): QuadTree {
  const tree = createQuadTree(bounds, capacity, maxDepth);
  
  for (const element of elements) {
    tree.insert(element);
  }

  return tree;
}
