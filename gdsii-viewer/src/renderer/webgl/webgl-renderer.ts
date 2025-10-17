/**
 * WebGL Renderer
 * 
 * High-performance GPU-accelerated renderer for GDSII visualization.
 * Implements IRenderer interface for compatibility with the rendering system.
 */

import type {
  GDSBoundaryElement,
  GDSPathElement,
  GDSElement
} from '../../gdsii-types';

import type {
  RendererCapabilities,
  LayerStyle
} from '../renderer-interface';

import { BaseRenderer } from '../base-renderer';
import type { Viewport } from '../../scene/scene-graph';
import type { SpatialElement } from '../../scene/spatial-index';
import { ShaderProgram } from './shader-program';
import { GeometryBuffer, BufferPool, BufferUsage } from './geometry-buffer';
import { triangulateMultiple } from './triangulator';
import { LayerBatchManager } from './layer-batch';

// Import shader sources
import vertexShaderSource from '../../../shaders/basic.vert?raw';
import fragmentShaderSource from '../../../shaders/basic.frag?raw';

/**
 * WebGL renderer implementation
 */
export class WebGLRenderer extends BaseRenderer {
  private gl: WebGL2RenderingContext | null = null;
  private shaderProgram: ShaderProgram | null = null;
  private bufferPool: BufferPool | null = null;
  private batchManager: LayerBatchManager | null = null;
  private identityMatrix: Float32Array;
  private useBatching: boolean = true; // Enable batching by default

  constructor() {
    super();
    // Identity matrix for world transform (no transformation)
    this.identityMatrix = new Float32Array([
      1, 0, 0,
      0, 1, 0,
      0, 0, 1
    ]);
  }

  // ========================================================================
  // Lifecycle Management
  // ========================================================================

  async initialize(canvas: HTMLCanvasElement): Promise<void> {
    console.log('🎨 Initializing WebGL renderer...');
    this.setCanvas(canvas);

    // Try WebGL2 first, then WebGL1 as fallback
    this.gl = canvas.getContext('webgl2', {
      alpha: true,
      antialias: true,
      depth: false,  // We don't need depth for 2D
      stencil: false,
      premultipliedAlpha: true
    }) as WebGL2RenderingContext;

    if (!this.gl) {
      throw new Error('WebGL2 not supported');
    }

    // Configure WebGL state
    this.setupWebGLState();

    // Load and compile shaders
    this.shaderProgram = new ShaderProgram(this.gl, vertexShaderSource, fragmentShaderSource);
    if (!this.shaderProgram.compile()) {
      throw new Error('Failed to compile shaders');
    }

    // Create buffer pool
    this.bufferPool = new BufferPool(this.gl, BufferUsage.DYNAMIC);

    // Create batch manager
    this.batchManager = new LayerBatchManager(this.gl);

    console.log('✓ WebGL renderer initialized');
  }

  /**
   * Sets up WebGL state for 2D rendering
   */
  private setupWebGLState(): void {
    if (!this.gl) return;

    // Enable blending for transparency
    this.gl.enable(this.gl.BLEND);
    this.gl.blendFunc(this.gl.SRC_ALPHA, this.gl.ONE_MINUS_SRC_ALPHA);

    // Disable depth testing (2D rendering)
    this.gl.disable(this.gl.DEPTH_TEST);

    // Set clear color (white background)
    this.gl.clearColor(1.0, 1.0, 1.0, 1.0);
  }

  dispose(): void {
    if (this.shaderProgram) {
      this.shaderProgram.dispose();
      this.shaderProgram = null;
    }

    if (this.bufferPool) {
      this.bufferPool.dispose();
      this.bufferPool = null;
    }

    if (this.batchManager) {
      this.batchManager.dispose();
      this.batchManager = null;
    }

    this.gl = null;
    this.setCanvas(null);
    this.clearScene();
    console.log('✓ WebGL renderer disposed');
  }

  getCapabilities(): RendererCapabilities {
    if (!this.gl) {
      return {
        backend: 'webgl',
        supportsInstancing: false,
        supportsAntialiasing: true,
        supportsMultisample: false,
        maxTextureSize: 0,
        maxViewportDims: [0, 0]
      };
    }

    return {
      backend: 'webgl2',
      supportsInstancing: true,
      supportsAntialiasing: true,
      supportsMultisample: true,
      maxTextureSize: this.gl.getParameter(this.gl.MAX_TEXTURE_SIZE),
      maxViewportDims: this.gl.getParameter(this.gl.MAX_VIEWPORT_DIMS)
    };
  }

  // ========================================================================
  // Rendering Implementation
  // ========================================================================

  renderImmediate(viewport: Viewport): void {
    const canvas = this.getCanvas();
    if (!this.gl || !this.shaderProgram || !this.bufferPool || !canvas || !this.isReady()) {
      return;
    }

    const startTime = performance.now();

    // Always set viewport to match canvas size (accounts for DPR)
    this.gl.viewport(0, 0, canvas.width, canvas.height);

    // Clear canvas
    this.gl.clear(this.gl.COLOR_BUFFER_BIT);

    // Query visible elements using spatial index
    const visibleElements = this.sceneGraph.queryViewport(viewport);
    const totalElements = this.sceneGraph.getAllElements().length;
    const culledElements = totalElements - visibleElements.length;

    if (visibleElements.length === 0) {
      this.updateStatistics(0, totalElements, 0);
      return;
    }

    // Use shader program
    this.shaderProgram.use();

    // Create view matrix from viewport
    const viewMatrix = this.createViewMatrix(viewport, canvas);
    this.shaderProgram.setUniformMatrix3fv('u_viewMatrix', viewMatrix);
    this.shaderProgram.setUniformMatrix3fv('u_worldMatrix', this.identityMatrix);

    // Get position attribute location
    const positionLoc = this.shaderProgram.getAttributeLocation('a_position');

    // Group elements by layer for efficient rendering
    const elementsByLayer = this.groupElementsByLayer(visibleElements);

    // Render each layer
    let drawCalls = 0;
    for (const [layerKey, elements] of elementsByLayer) {
      const layerStyle = this.layerStyles.get(layerKey);
      if (!layerStyle) {
        continue;
      }

      drawCalls += this.renderLayer(elements, layerStyle, positionLoc);
    }

    // Update statistics
    this.updateStatistics(visibleElements.length, culledElements, drawCalls);

    const renderTime = performance.now() - startTime;
    
    if (this.debugMode && culledElements > 0) {
      const cullRate = ((culledElements / totalElements) * 100).toFixed(1);
      console.log(`🎯 WebGL rendered ${visibleElements.length}/${totalElements} elements ` +
                  `(${cullRate}% culled) in ${renderTime.toFixed(2)}ms`);
    }
  }

  // ========================================================================
  // View Matrix Creation
  // ========================================================================

  /**
   * Creates a view transformation matrix from viewport parameters
   */
  private createViewMatrix(viewport: Viewport, canvas: HTMLCanvasElement): Float32Array {
    const { center, zoom } = viewport;
    const { width, height } = canvas;

    // Convert to NDC (Normalized Device Coordinates: -1 to 1)
    // 1. Scale by zoom
    // 2. Translate by -center (camera position)
    // 3. Scale to NDC space
    const scaleX = (2 * zoom) / width;
    const scaleY = (2 * zoom) / height;

    // Matrix in column-major order for WebGL
    return new Float32Array([
      scaleX,  0,       0,
      0,       scaleY,  0,
      -center.x * scaleX, -center.y * scaleY, 1
    ]);
  }

  // ========================================================================
  // Layer Rendering
  // ========================================================================

  /**
   * Groups elements by layer key
   */
  private groupElementsByLayer(elements: SpatialElement[]): Map<string, SpatialElement[]> {
    const grouped = new Map<string, SpatialElement[]>();

    for (const spatialElement of elements) {
      const element = spatialElement.element;
      const layerKey = `${element.layer}_${element.dataType}`;

      if (!grouped.has(layerKey)) {
        grouped.set(layerKey, []);
      }
      grouped.get(layerKey)!.push(spatialElement);
    }

    return grouped;
  }

  /**
   * Renders all elements in a layer
   */
  private renderLayer(
    elements: SpatialElement[],
    style: LayerStyle,
    positionLoc: number
  ): number {
    if (!this.gl || !this.shaderProgram) {
      return 0;
    }

    // Set layer color and opacity
    const color = this.parseColor(style.color);
    this.shaderProgram.setUniformVec4('u_color', color[0], color[1], color[2], color[3]);
    this.shaderProgram.setUniformFloat('u_opacity', style.opacity);

    // Use batching if enabled and batch manager available
    if (this.useBatching && this.batchManager) {
      return this.renderLayerBatched(elements, style, positionLoc);
    } else {
      return this.renderLayerUnbatched(elements, positionLoc);
    }
  }

  /**
   * Renders a layer using batching (combines all elements into one draw call)
   */
  private renderLayerBatched(
    elements: SpatialElement[],
    style: LayerStyle,
    positionLoc: number
  ): number {
    if (!this.batchManager) return 0;

    // Filter out non-renderable elements
    const renderableElements = elements.filter(e => {
      const type = e.element.type;
      return type !== 'sref' && type !== 'aref' && type !== 'text';
    });

    if (renderableElements.length === 0) return 0;

    // Get layer key
    const layerKey = `${renderableElements[0].element.layer}_${renderableElements[0].element.dataType}`;

    // Get or create batch for this layer
    const batch = this.batchManager.getBatch(layerKey, style);

    // Update batch if dirty or elements changed
    if (batch.isDirty()) {
      batch.update(renderableElements);
    }

    // Render the batch (single draw call for entire layer)
    batch.render(positionLoc);

    return 1; // One draw call for entire layer
  }

  /**
   * Renders a layer without batching (one draw call per element)
   */
  private renderLayerUnbatched(
    elements: SpatialElement[],
    positionLoc: number
  ): number {
    if (!this.bufferPool) return 0;

    let drawCalls = 0;

    // Render each element
    for (const spatialElement of elements) {
      const element = spatialElement.element;

      // Skip non-renderable elements
      if (element.type === 'sref' || element.type === 'aref' || element.type === 'text') {
        continue;
      }

      drawCalls += this.renderElement(element, positionLoc);
    }

    return drawCalls;
  }

  /**
   * Renders a single element
   */
  private renderElement(element: GDSElement, positionLoc: number): number {
    if (!this.bufferPool || !this.gl) {
      return 0;
    }

    let polygons: any[] = [];

    // Extract polygons based on element type
    if (element.type === 'boundary') {
      const boundaryEl = element as GDSBoundaryElement;
      polygons = boundaryEl.polygons;
    } else if (element.type === 'path') {
      const pathEl = element as GDSPathElement;
      polygons = pathEl.paths;
    } else if (element.type === 'box') {
      const boxEl = element as any;
      if (boxEl.points && boxEl.points.length >= 4) {
        polygons = [boxEl.points];
      }
    } else if (element.type === 'node') {
      // Skip nodes for now (could render as points)
      return 0;
    }

    if (polygons.length === 0) {
      return 0;
    }

    // Triangulate and combine all polygons
    const { vertices, indices } = triangulateMultiple(polygons);

    if (indices.length === 0) {
      return 0;
    }

    // Get buffer from pool
    const buffer = this.bufferPool.acquire();

    try {
      // Upload geometry to GPU
      buffer.uploadVertices(vertices);
      buffer.uploadIndices(indices);

      // Bind and draw
      buffer.bindVertexBuffer(positionLoc);
      buffer.bindIndexBuffer();
      buffer.draw();

      return 1; // One draw call
    } finally {
      // Always return buffer to pool
      this.bufferPool.release(buffer);
    }
  }

  // ========================================================================
  // Utilities
  // ========================================================================

  // ========================================================================
  // Batching Control
  // ========================================================================

  /**
   * Enables or disables geometry batching
   */
  setBatchingEnabled(enabled: boolean): void {
    this.useBatching = enabled;
    
    // If disabling batching, clear all batches
    if (!enabled && this.batchManager) {
      this.batchManager.clear();
    }
    
    console.log(`Batching ${enabled ? 'enabled' : 'disabled'}`);
  }

  /**
   * Gets batching statistics
   */
  getBatchingStats() {
    if (!this.batchManager) {
      return null;
    }
    return this.batchManager.getStats();
  }

  /**
   * Invalidates all batches (forces re-triangulation)
   */
  invalidateBatches(): void {
    if (this.batchManager) {
      this.batchManager.markAllDirty();
    }
  }

  // ========================================================================
  // Utilities
  // ========================================================================

  /**
   * Parses a CSS color string to RGBA values (0-1 range)
   */
  private parseColor(colorString: string): [number, number, number, number] {
    // Handle hex colors (#RRGGBB or #RGB)
    if (colorString.startsWith('#')) {
      const hex = colorString.slice(1);
      let r, g, b;

      if (hex.length === 3) {
        r = parseInt(hex[0] + hex[0], 16);
        g = parseInt(hex[1] + hex[1], 16);
        b = parseInt(hex[2] + hex[2], 16);
      } else {
        r = parseInt(hex.slice(0, 2), 16);
        g = parseInt(hex.slice(2, 4), 16);
        b = parseInt(hex.slice(4, 6), 16);
      }

      return [r / 255, g / 255, b / 255, 1.0];
    }

    // Default gray if parsing fails
    return [0.5, 0.5, 0.5, 1.0];
  }
}
