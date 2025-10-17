/**
 * Layer Batch Manager
 * 
 * Combines multiple elements within a layer into a single geometry batch
 * to minimize draw calls and improve rendering performance.
 */

import type { GDSElement } from '../../gdsii-types';
import type { SpatialElement } from '../../scene/spatial-index';
import type { LayerStyle } from '../renderer-interface';
import { GeometryBuffer, BufferUsage } from './geometry-buffer';
import { triangulateMultiple } from './triangulator';

/**
 * Represents a batch of geometry for a single layer
 */
export class LayerBatch {
  private buffer: GeometryBuffer;
  private vertexCount: number = 0;
  private indexCount: number = 0;
  private dirty: boolean = true;
  private layerKey: string;
  private style: LayerStyle;
  
  constructor(
    gl: WebGL2RenderingContext,
    layerKey: string,
    style: LayerStyle
  ) {
    this.buffer = new GeometryBuffer(gl, BufferUsage.DYNAMIC);
    this.layerKey = layerKey;
    this.style = style;
  }

  /**
   * Updates the batch with new elements
   */
  update(elements: SpatialElement[]): void {
    if (elements.length === 0) {
      this.vertexCount = 0;
      this.indexCount = 0;
      this.dirty = false;
      return;
    }

    // Collect all polygons from all elements
    const allPolygons: any[] = [];
    
    for (const spatialElement of elements) {
      const element = spatialElement.element;
      const polygons = this.extractPolygons(element);
      allPolygons.push(...polygons);
    }

    if (allPolygons.length === 0) {
      this.vertexCount = 0;
      this.indexCount = 0;
      this.dirty = false;
      return;
    }

    // Triangulate all polygons together
    const { vertices, indices } = triangulateMultiple(allPolygons);

    // Upload to GPU
    this.buffer.uploadVertices(vertices);
    this.buffer.uploadIndices(indices);

    this.vertexCount = vertices.length / 2;
    this.indexCount = indices.length;
    this.dirty = false;
  }

  /**
   * Extracts polygons from an element
   */
  private extractPolygons(element: GDSElement): any[] {
    const polygons: any[] = [];

    if (element.type === 'boundary') {
      const boundaryEl = element as any;
      polygons.push(...boundaryEl.polygons);
    } else if (element.type === 'path') {
      const pathEl = element as any;
      polygons.push(...pathEl.paths);
    } else if (element.type === 'box') {
      const boxEl = element as any;
      if (boxEl.points && boxEl.points.length >= 4) {
        polygons.push(boxEl.points);
      }
    }

    return polygons;
  }

  /**
   * Renders the batch
   */
  render(positionLoc: number): void {
    if (this.indexCount === 0) return;

    this.buffer.bindVertexBuffer(positionLoc);
    this.buffer.bindIndexBuffer();
    this.buffer.draw();
  }

  /**
   * Marks the batch as dirty (needs update)
   */
  markDirty(): void {
    this.dirty = true;
  }

  /**
   * Checks if batch needs update
   */
  isDirty(): boolean {
    return this.dirty;
  }

  /**
   * Gets the layer style
   */
  getStyle(): LayerStyle {
    return this.style;
  }

  /**
   * Updates the layer style
   */
  setStyle(style: LayerStyle): void {
    this.style = style;
  }

  /**
   * Gets statistics about this batch
   */
  getStats() {
    return {
      layerKey: this.layerKey,
      vertexCount: this.vertexCount,
      indexCount: this.indexCount,
      triangleCount: this.indexCount / 3,
      dirty: this.dirty
    };
  }

  /**
   * Disposes of GPU resources
   */
  dispose(): void {
    this.buffer.dispose();
  }
}

/**
 * Manages all layer batches
 */
export class LayerBatchManager {
  private gl: WebGL2RenderingContext;
  private batches: Map<string, LayerBatch> = new Map();

  constructor(gl: WebGL2RenderingContext) {
    this.gl = gl;
  }

  /**
   * Gets or creates a batch for a layer
   */
  getBatch(layerKey: string, style: LayerStyle): LayerBatch {
    let batch = this.batches.get(layerKey);
    
    if (!batch) {
      batch = new LayerBatch(this.gl, layerKey, style);
      this.batches.set(layerKey, batch);
    } else {
      // Update style in case it changed
      batch.setStyle(style);
    }

    return batch;
  }

  /**
   * Updates a specific batch with elements
   */
  updateBatch(layerKey: string, elements: SpatialElement[], style: LayerStyle): void {
    const batch = this.getBatch(layerKey, style);
    batch.update(elements);
  }

  /**
   * Marks all batches as dirty
   */
  markAllDirty(): void {
    for (const batch of this.batches.values()) {
      batch.markDirty();
    }
  }

  /**
   * Clears all batches
   */
  clear(): void {
    for (const batch of this.batches.values()) {
      batch.dispose();
    }
    this.batches.clear();
  }

  /**
   * Gets all batches
   */
  getAllBatches(): Map<string, LayerBatch> {
    return this.batches;
  }

  /**
   * Gets overall statistics
   */
  getStats() {
    let totalVertices = 0;
    let totalIndices = 0;
    let totalTriangles = 0;
    let dirtyCount = 0;

    for (const batch of this.batches.values()) {
      const stats = batch.getStats();
      totalVertices += stats.vertexCount;
      totalIndices += stats.indexCount;
      totalTriangles += stats.triangleCount;
      if (stats.dirty) dirtyCount++;
    }

    return {
      batchCount: this.batches.size,
      totalVertices,
      totalIndices,
      totalTriangles,
      dirtyCount
    };
  }

  /**
   * Disposes of all resources
   */
  dispose(): void {
    this.clear();
  }
}
