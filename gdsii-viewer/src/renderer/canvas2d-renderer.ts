/**
 * Canvas2D Renderer
 * 
 * HTML5 Canvas 2D rendering backend with viewport culling.
 * Provides fallback rendering when WebGL is not available.
 */

import type {
  GDSBoundaryElement,
  GDSPathElement,
  GDSTextElement,
  GDSElement
} from '../gdsii-types';

import type {
  RendererCapabilities,
  LayerStyle
} from './renderer-interface';

import { BaseRenderer } from './base-renderer';
import type { Viewport } from '../scene/scene-graph';
import type { SpatialElement } from '../scene/spatial-index';
import { logger, LogCategory } from '../debug-logger';

/**
 * Canvas2D renderer implementation
 */
export class Canvas2DRenderer extends BaseRenderer {
  private ctx: CanvasRenderingContext2D | null = null;

  // ========================================================================
  // Lifecycle Management
  // ========================================================================

  async initialize(canvas: HTMLCanvasElement): Promise<void> {
    logger.info(LogCategory.RENDERER, 'Initializing Canvas2D renderer...');
    this.setCanvas(canvas);
    
    const ctx = canvas.getContext('2d', {
      alpha: true,
      desynchronized: true // Hint for better performance
    });

    if (!ctx) {
      logger.error(LogCategory.RENDERER, 'Failed to get 2D rendering context');
      throw new Error('Failed to get 2D rendering context');
    }

    this.ctx = ctx;
    logger.info(LogCategory.RENDERER, 'Canvas2D renderer initialized', {
      canvasSize: `${canvas.width}x${canvas.height}`
    });
    console.log('✓ Canvas2D renderer initialized');
  }

  dispose(): void {
    this.ctx = null;
    this.setCanvas(null);
    this.clearScene();
    console.log('✓ Canvas2D renderer disposed');
  }

  getCapabilities(): RendererCapabilities {
    return {
      backend: 'canvas2d',
      supportsInstancing: false,
      supportsAntialiasing: true, // Via imageSmoothingEnabled
      supportsMultisample: false,
      maxTextureSize: 0,
      maxViewportDims: [32767, 32767] // Canvas size limits
    };
  }

  // ========================================================================
  // Rendering Implementation
  // ========================================================================

  renderImmediate(viewport: Viewport): void {
    const canvas = this.getCanvas();
    if (!this.ctx || !canvas || !this.isReady()) {
      logger.warn(LogCategory.RENDERER, 'Render skipped: renderer not ready');
      return;
    }

    const startTime = performance.now();
    logger.debug(LogCategory.RENDERER, 'Starting render frame', {
      viewport: { center: viewport.center, zoom: viewport.zoom }
    });

    // Clear canvas
    this.ctx.fillStyle = '#ffffff';
    this.ctx.fillRect(0, 0, canvas.width, canvas.height);
    logger.debug(LogCategory.DRAWING, 'Canvas cleared');

    // Query visible elements using spatial index
    logger.debug(LogCategory.CULLING, 'Querying viewport for visible elements...');
    const visibleElements = this.sceneGraph.queryViewport(viewport);
    const totalElements = this.sceneGraph.getAllElements().length;
    const culledElements = totalElements - visibleElements.length;
    logger.info(LogCategory.CULLING, `Viewport query complete`, {
      total: totalElements,
      visible: visibleElements.length,
      culled: culledElements,
      cullRate: `${((culledElements / totalElements) * 100).toFixed(1)}%`
    });

    // Set up coordinate system
    this.ctx.save();
    this.setupCoordinateSystem(viewport);

    // Group elements by layer for efficient rendering
    logger.debug(LogCategory.LAYER, 'Grouping elements by layer...');
    const elementsByLayer = this.groupElementsByLayer(visibleElements);
    logger.info(LogCategory.LAYER, `Elements grouped into ${elementsByLayer.size} layers`);

    // Render by layer (sorted for correct z-order)
    const sortedLayers = Array.from(elementsByLayer.keys()).sort((a, b) => {
      const [layerA] = a.split('_').map(Number);
      const [layerB] = b.split('_').map(Number);
      return layerA - layerB;
    });
    logger.debug(LogCategory.LAYER, 'Layers sorted for rendering', { layers: sortedLayers });

    let drawCalls = 0;
    for (const layerKey of sortedLayers) {
      const elements = elementsByLayer.get(layerKey)!;
      const layerStyle = this.layerStyles.get(layerKey);
      
      if (!layerStyle) {
        logger.warn(LogCategory.LAYER, `No style found for layer ${layerKey}, skipping`);
        continue;
      }

      logger.debug(LogCategory.LAYER, `Rendering layer ${layerKey}`, {
        elementCount: elements.length,
        style: { color: layerStyle.color, opacity: layerStyle.opacity }
      });
      const layerDrawCalls = this.renderLayer(elements, layerStyle);
      drawCalls += layerDrawCalls;
      logger.debug(LogCategory.DRAWING, `Layer ${layerKey} rendered with ${layerDrawCalls} draw calls`);
    }

    this.ctx.restore();

    // Draw debug info if enabled
    if (this.debugMode) {
      logger.debug(LogCategory.RENDERER, 'Drawing debug overlay');
      this.drawDebugInfo(viewport, visibleElements.length, culledElements);
    }

    // Update statistics
    this.updateStatistics(visibleElements.length, culledElements, drawCalls);

    const renderTime = performance.now() - startTime;
    const stats = this.getStatistics();
    logger.info(LogCategory.PERFORMANCE, 'Frame rendered', {
      renderTime: `${renderTime.toFixed(2)}ms`,
      fps: stats.fps,
      drawCalls,
      elementsRendered: visibleElements.length
    });
    
    // Log culling efficiency for debugging
    if (culledElements > 0) {
      const cullRate = ((culledElements / totalElements) * 100).toFixed(1);
      console.log(`🎯 Rendered ${visibleElements.length}/${totalElements} elements ` +
                  `(${cullRate}% culled) in ${renderTime.toFixed(2)}ms`);
    }
  }

  // ========================================================================
  // Coordinate System Setup
  // ========================================================================

  private setupCoordinateSystem(viewport: Viewport): void {
    if (!this.ctx || !this.getCanvas()) return;

    const canvas = this.getCanvas()!;
    
    // Translate to canvas center
    this.ctx.translate(canvas.width / 2, canvas.height / 2);
    
    // Apply zoom
    this.ctx.scale(viewport.zoom, viewport.zoom);
    
    // Invert Y-axis (GDSII uses standard math coordinates)
    this.ctx.scale(1, -1);
    
    // Translate to viewport center
    this.ctx.translate(-viewport.center.x, -viewport.center.y);
  }

  // ========================================================================
  // Layer Rendering
  // ========================================================================

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

  private renderLayer(elements: SpatialElement[], style: LayerStyle): number {
    if (!this.ctx) return 0;

    let drawCalls = 0;

    // Set layer style
    this.ctx.strokeStyle = style.color;
    this.ctx.fillStyle = style.color;
    this.ctx.globalAlpha = style.opacity;
    this.ctx.lineWidth = (style.lineWidth || 1) / this.ctx.getTransform().a; // Scale line width

    // Enable anti-aliasing based on options
    this.ctx.imageSmoothingEnabled = this.renderOptions.antialiasing;

    for (const spatialElement of elements) {
      const element = spatialElement.element;
      
      // Skip references (should be flattened already)
      if (element.type === 'sref' || element.type === 'aref') {
        continue;
      }

      drawCalls += this.drawElement(element, style);
    }

    this.ctx.globalAlpha = 1.0;
    
    return drawCalls;
  }

  // ========================================================================
  // Element Drawing
  // ========================================================================

  private drawElement(element: GDSElement, style: LayerStyle): number {
    switch (element.type) {
      case 'boundary':
        return this.drawBoundary(element as GDSBoundaryElement, style);
      case 'path':
        return this.drawPath(element as GDSPathElement, style);
      case 'text':
        return this.renderOptions.showText ? this.drawText(element as GDSTextElement) : 0;
      case 'box':
        return this.drawBox(element as import('../gdsii-types').GDSBoxElement, style);
      case 'node':
        return this.drawNode(element as import('../gdsii-types').GDSNodeElement);
      default:
        return 0;
    }
  }

  private drawBoundary(element: GDSBoundaryElement, style: LayerStyle): number {
    if (!this.ctx) return 0;

    let drawCalls = 0;

    for (const polygon of element.polygons) {
      if (polygon.length < 3) continue;

      this.ctx.beginPath();
      this.ctx.moveTo(polygon[0].x, polygon[0].y);
      
      for (let i = 1; i < polygon.length; i++) {
        this.ctx.lineTo(polygon[i].x, polygon[i].y);
      }
      
      this.ctx.closePath();

      // Fill if enabled
      if (style.fillEnabled && this.renderOptions.showFill) {
        this.ctx.fill();
        drawCalls++;
      }

      // Stroke if enabled
      if (style.strokeEnabled && this.renderOptions.showStroke) {
        this.ctx.stroke();
        drawCalls++;
      }
    }

    return drawCalls;
  }

  private drawPath(element: GDSPathElement, style: LayerStyle): number {
    if (!this.ctx || !style.strokeEnabled || !this.renderOptions.showStroke) {
      return 0;
    }

    let drawCalls = 0;

    // Apply path width
    const savedLineWidth = this.ctx.lineWidth;
    if (element.width > 0) {
      this.ctx.lineWidth = element.width / this.ctx.getTransform().a;
    }

    // Set line cap and join based on path type
    switch (element.pathType) {
      case 0: // Flush ends
        this.ctx.lineCap = 'butt';
        break;
      case 1: // Round ends
        this.ctx.lineCap = 'round';
        break;
      case 2: // Square ends (extended by half width)
        this.ctx.lineCap = 'square';
        break;
      case 4: // Custom extensions (approximated as square)
        this.ctx.lineCap = 'square';
        break;
    }

    for (const path of element.paths) {
      if (path.length < 2) continue;

      this.ctx.beginPath();
      this.ctx.moveTo(path[0].x, path[0].y);
      
      for (let i = 1; i < path.length; i++) {
        this.ctx.lineTo(path[i].x, path[i].y);
      }
      
      this.ctx.stroke();
      drawCalls++;
    }

    // Restore line width
    this.ctx.lineWidth = savedLineWidth;
    
    return drawCalls;
  }

  private drawText(element: GDSTextElement): number {
    if (!this.ctx) return 0;

    this.ctx.save();

    // Flip coordinate system for text (since we're in inverted Y)
    const currentTransform = this.ctx.getTransform();
    this.ctx.scale(1 / currentTransform.a, -1 / currentTransform.d);

    // Set font size (scale with zoom)
    const fontSize = Math.max(10, 12 * currentTransform.a);
    this.ctx.font = `${fontSize}px sans-serif`;
    this.ctx.textAlign = 'left';
    this.ctx.textBaseline = 'bottom';

    // Draw text
    const screenPos = this.worldToScreen(
      element.position.x,
      element.position.y,
      {
        center: { x: 0, y: 0 },
        width: this.getCanvas()!.width,
        height: this.getCanvas()!.height,
        zoom: currentTransform.a
      }
    );

    this.ctx.fillText(element.text, screenPos.x, screenPos.y);

    this.ctx.restore();
    
    return 1;
  }

  private drawBox(element: import('../gdsii-types').GDSBoxElement, style: LayerStyle): number {
    if (!this.ctx || element.points.length < 5) return 0;

    this.ctx.beginPath();
    this.ctx.moveTo(element.points[0].x, element.points[0].y);
    
    for (let i = 1; i < element.points.length; i++) {
      this.ctx.lineTo(element.points[i].x, element.points[i].y);
    }
    
    this.ctx.closePath();

    let drawCalls = 0;

    if (style.fillEnabled && this.renderOptions.showFill) {
      this.ctx.fill();
      drawCalls++;
    }

    if (style.strokeEnabled && this.renderOptions.showStroke) {
      this.ctx.stroke();
      drawCalls++;
    }

    return drawCalls;
  }

  private drawNode(element: import('../gdsii-types').GDSNodeElement): number {
    if (!this.ctx) return 0;

    let drawCalls = 0;
    const radius = 2 / this.ctx.getTransform().a; // Scale with zoom

    for (const point of element.points) {
      this.ctx.beginPath();
      this.ctx.arc(point.x, point.y, radius, 0, 2 * Math.PI);
      this.ctx.fill();
      drawCalls++;
    }

    return drawCalls;
  }

  // ========================================================================
  // Debug Visualization
  // ========================================================================

  private drawDebugInfo(viewport: Viewport, visible: number, culled: number): void {
    if (!this.ctx) return;

    const canvas = this.getCanvas()!;
    
    this.ctx.save();
    this.ctx.resetTransform();

    // Draw debug overlay
    this.ctx.fillStyle = 'rgba(0, 0, 0, 0.7)';
    this.ctx.fillRect(10, 10, 250, 120);

    this.ctx.fillStyle = '#00ff00';
    this.ctx.font = '12px monospace';
    this.ctx.textAlign = 'left';
    this.ctx.textBaseline = 'top';

    const stats = this.getStatistics();
    const total = visible + culled;
    const cullRate = total > 0 ? ((culled / total) * 100).toFixed(1) : '0.0';

    this.ctx.fillText(`FPS: ${stats.fps}`, 20, 20);
    this.ctx.fillText(`Frame: ${stats.frameTime.toFixed(2)}ms`, 20, 40);
    this.ctx.fillText(`Elements: ${visible}/${total}`, 20, 60);
    this.ctx.fillText(`Culled: ${cullRate}%`, 20, 80);
    this.ctx.fillText(`Draw Calls: ${stats.drawCalls}`, 20, 100);

    // Draw viewport bounds
    this.ctx.restore();
    this.setupCoordinateSystem(viewport);
    
    const halfWidth = canvas.width / (2 * viewport.zoom);
    const halfHeight = canvas.height / (2 * viewport.zoom);
    
    this.ctx.strokeStyle = '#ff0000';
    this.ctx.lineWidth = 2 / viewport.zoom;
    this.ctx.strokeRect(
      viewport.center.x - halfWidth,
      viewport.center.y - halfHeight,
      halfWidth * 2,
      halfHeight * 2
    );

    this.ctx.restore();
  }
}
