/**
 * Base Renderer
 * 
 * Provides shared functionality for all renderer implementations.
 * Handles common tasks like coordinate transformation, statistics tracking, and layer management.
 */

import type {
  GDSLibrary,
  GDSPoint,
  GDSBBox
} from '../gdsii-types';

import type {
  IRenderer,
  LayerStyle,
  RenderStatistics,
  RenderOptions,
  RendererCapabilities,
  DEFAULT_LAYER_STYLE
} from './renderer-interface';

import { DEFAULT_RENDER_OPTIONS } from './renderer-interface';

import type { Viewport } from '../scene/scene-graph';
import { SceneGraph } from '../scene/scene-graph';
import { flattenLibrary } from '../hierarchy-resolver';

/**
 * Abstract base class for renderers
 */
export abstract class BaseRenderer implements IRenderer {
  protected canvas: HTMLCanvasElement | null = null;
  protected sceneGraph: SceneGraph;
  protected library: GDSLibrary | null = null;
  protected layerStyles: Map<string, LayerStyle> = new Map();
  protected renderOptions: RenderOptions = { ...DEFAULT_RENDER_OPTIONS };
  protected debugMode: boolean = false;
  
  // Statistics tracking
  protected stats: RenderStatistics = {
    frameTime: 0,
    fps: 0,
    elementsRendered: 0,
    elementsCulled: 0,
    drawCalls: 0
  };
  
  protected frameCount: number = 0;
  protected lastFrameTime: number = 0;
  protected fpsUpdateTime: number = 0;
  protected fpsFrameCount: number = 0;
  
  // Render request tracking
  protected renderRequested: boolean = false;
  protected animationFrameId: number | null = null;

  constructor() {
    this.sceneGraph = new SceneGraph();
  }

  // ========================================================================
  // Abstract methods that must be implemented by subclasses
  // ========================================================================

  abstract initialize(canvas: HTMLCanvasElement): Promise<void>;
  abstract dispose(): void;
  abstract renderImmediate(viewport: Viewport): void;
  abstract getCapabilities(): RendererCapabilities;

  // ========================================================================
  // Lifecycle Management
  // ========================================================================

  isReady(): boolean {
    return this.canvas !== null && this.library !== null;
  }

  // ========================================================================
  // Scene Management
  // ========================================================================

  setLibrary(library: GDSLibrary): void {
    this.library = library;
    this.updateSceneGraph();
  }

  updateSceneGraph(): void {
    if (!this.library) {
      console.warn('Cannot update scene graph: no library loaded');
      return;
    }

    console.time('Build Scene Graph');
    
    // Flatten hierarchy
    const flattenedStructures = flattenLibrary(this.library, {
      flattenHierarchy: true,
      maxDepth: 100,
      showFill: this.renderOptions.showFill,
      showStroke: this.renderOptions.showStroke,
      showText: this.renderOptions.showText,
      showReferences: this.renderOptions.showReferences
    });

    // Build scene graph
    this.sceneGraph.buildFromLibrary(this.library, flattenedStructures);

    // Initialize layer styles from scene graph
    this.initializeLayerStyles();

    console.timeEnd('Build Scene Graph');
    
    // Request a render after scene update
    this.requestRender();
  }

  clearScene(): void {
    this.sceneGraph.clear();
    this.library = null;
    this.layerStyles.clear();
    this.resetStatistics();
    this.requestRender();
  }

  // ========================================================================
  // Rendering
  // ========================================================================

  render(viewport: Viewport): void {
    this.renderImmediate(viewport);
  }

  requestRender(): void {
    if (this.renderRequested) {
      return;
    }

    this.renderRequested = true;

    if (this.animationFrameId !== null) {
      cancelAnimationFrame(this.animationFrameId);
    }

    this.animationFrameId = requestAnimationFrame(() => {
      this.renderRequested = false;
      this.animationFrameId = null;
      
      // Note: Actual render will be called from main application
      // This is just to trigger the render cycle
    });
  }

  // ========================================================================
  // Layer Management
  // ========================================================================

  setLayerVisible(layer: number, dataType: number, visible: boolean): void {
    this.sceneGraph.setLayerVisible(layer, dataType, visible);
    this.requestRender();
  }

  setLayerStyle(layer: number, dataType: number, style: LayerStyle): void {
    const layerKey = `${layer}_${dataType}`;
    this.layerStyles.set(layerKey, { ...style });
    this.sceneGraph.setLayerColor(layer, dataType, style.color);
    this.requestRender();
  }

  getLayerStyle(layer: number, dataType: number): LayerStyle | null {
    const layerKey = `${layer}_${dataType}`;
    return this.layerStyles.get(layerKey) || null;
  }

  protected initializeLayerStyles(): void {
    const layerGroups = this.sceneGraph.getLayerGroups();
    
    for (const [layerKey, layerGroup] of layerGroups) {
      if (!this.layerStyles.has(layerKey)) {
        this.layerStyles.set(layerKey, {
          color: layerGroup.color,
          fillEnabled: this.renderOptions.showFill,
          strokeEnabled: this.renderOptions.showStroke,
          opacity: 0.7,
          lineWidth: 1
        });
      }
    }
  }

  // ========================================================================
  // Interactive Features (Default implementations)
  // ========================================================================

  pick(screenX: number, screenY: number, viewport: Viewport) {
    const worldPoint = this.screenToWorld(screenX, screenY, viewport);
    const candidates = this.sceneGraph.queryPoint(worldPoint);
    
    if (candidates.length === 0) {
      return null;
    }

    // Return the first candidate (could be enhanced with z-ordering)
    const spatialElement = candidates[0];
    return {
      element: spatialElement.element,
      structureName: spatialElement.structureName,
      elementIndex: spatialElement.elementIndex,
      distance: 0,
      point: worldPoint
    };
  }

  getElementsInRegion(
    screenBBox: { x: number; y: number; width: number; height: number },
    viewport: Viewport
  ) {
    // Convert screen bbox to world bbox
    const topLeft = this.screenToWorld(screenBBox.x, screenBBox.y, viewport);
    const bottomRight = this.screenToWorld(
      screenBBox.x + screenBBox.width,
      screenBBox.y + screenBBox.height,
      viewport
    );

    const worldBBox: GDSBBox = {
      minX: Math.min(topLeft.x, bottomRight.x),
      minY: Math.min(topLeft.y, bottomRight.y),
      maxX: Math.max(topLeft.x, bottomRight.x),
      maxY: Math.max(topLeft.y, bottomRight.y)
    };

    return this.sceneGraph.queryRegion(worldBBox);
  }

  // ========================================================================
  // Configuration
  // ========================================================================

  setRenderOptions(options: Partial<RenderOptions>): void {
    this.renderOptions = { ...this.renderOptions, ...options };
    
    // If hierarchy flattening changed, rebuild scene graph
    if (this.library) {
      this.updateSceneGraph();
    } else {
      this.requestRender();
    }
  }

  getRenderOptions(): RenderOptions {
    return { ...this.renderOptions };
  }

  // ========================================================================
  // Performance & Debugging
  // ========================================================================

  getStatistics(): RenderStatistics {
    return { ...this.stats };
  }

  resetStatistics(): void {
    this.stats = {
      frameTime: 0,
      fps: 0,
      elementsRendered: 0,
      elementsCulled: 0,
      drawCalls: 0
    };
    this.frameCount = 0;
    this.fpsFrameCount = 0;
    this.fpsUpdateTime = performance.now();
  }

  setDebugMode(enabled: boolean): void {
    this.debugMode = enabled;
    this.requestRender();
  }

  protected updateStatistics(elementsRendered: number, elementsCulled: number, drawCalls: number): void {
    const now = performance.now();
    const frameTime = now - this.lastFrameTime;
    this.lastFrameTime = now;

    this.stats.frameTime = frameTime;
    this.stats.elementsRendered = elementsRendered;
    this.stats.elementsCulled = elementsCulled;
    this.stats.drawCalls = drawCalls;

    this.frameCount++;
    this.fpsFrameCount++;

    // Update FPS every second
    const elapsed = now - this.fpsUpdateTime;
    if (elapsed >= 1000) {
      this.stats.fps = Math.round((this.fpsFrameCount * 1000) / elapsed);
      this.fpsFrameCount = 0;
      this.fpsUpdateTime = now;
    }
  }

  // ========================================================================
  // Coordinate Transformation
  // ========================================================================

  screenToWorld(screenX: number, screenY: number, viewport: Viewport): GDSPoint {
    if (!this.canvas) {
      return { x: 0, y: 0 };
    }

    // Get canvas center
    const canvasCenterX = this.canvas.width / 2;
    const canvasCenterY = this.canvas.height / 2;

    // Convert screen to canvas coordinates
    const canvasX = screenX - canvasCenterX;
    const canvasY = screenY - canvasCenterY;

    // Scale and translate to world coordinates
    // Note: Y-axis is inverted in canvas
    const worldX = viewport.center.x + canvasX / viewport.zoom;
    const worldY = viewport.center.y - canvasY / viewport.zoom;

    return { x: worldX, y: worldY };
  }

  worldToScreen(worldX: number, worldY: number, viewport: Viewport): GDSPoint {
    if (!this.canvas) {
      return { x: 0, y: 0 };
    }

    // Get canvas center
    const canvasCenterX = this.canvas.width / 2;
    const canvasCenterY = this.canvas.height / 2;

    // Convert world to canvas coordinates
    const canvasX = (worldX - viewport.center.x) * viewport.zoom;
    const canvasY = -(worldY - viewport.center.y) * viewport.zoom; // Invert Y

    // Convert to screen coordinates
    const screenX = canvasCenterX + canvasX;
    const screenY = canvasCenterY + canvasY;

    return { x: screenX, y: screenY };
  }

  // ========================================================================
  // Utility Methods
  // ========================================================================

  getSceneGraph(): SceneGraph {
    return this.sceneGraph;
  }

  protected getCanvas(): HTMLCanvasElement | null {
    return this.canvas;
  }

  protected setCanvas(canvas: HTMLCanvasElement): void {
    this.canvas = canvas;
  }
}
