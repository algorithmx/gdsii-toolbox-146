/**
 * Renderer Interface
 * 
 * Defines the contract for all rendering backends (Canvas2D, WebGL, etc.)
 * Provides abstraction layer for swapping rendering implementations.
 */

import type {
  GDSLibrary,
  GDSElement,
  GDSBBox,
  GDSPoint
} from '../gdsii-types';

import type { Viewport } from '../scene/scene-graph';
import type { SpatialElement } from '../scene/spatial-index';

/**
 * Layer rendering style
 */
export interface LayerStyle {
  color: string;
  fillEnabled: boolean;
  strokeEnabled: boolean;
  opacity: number;
  lineWidth?: number;
  pattern?: string;
}

/**
 * Rendering statistics
 */
export interface RenderStatistics {
  frameTime: number;           // Time to render last frame (ms)
  fps: number;                 // Frames per second
  elementsRendered: number;    // Elements drawn in last frame
  elementsCulled: number;      // Elements culled in last frame
  drawCalls: number;           // Number of draw operations
  triangles?: number;          // Triangles rendered (WebGL)
  memoryUsage?: number;        // Memory used by renderer (bytes)
}

/**
 * Pick result from element selection
 */
export interface PickResult {
  element: GDSElement;
  structureName?: string;
  elementIndex?: number;
  distance: number;            // Distance from pick point
  point: GDSPoint;            // Actual intersection point
}

/**
 * Render options
 */
export interface RenderOptions {
  showFill: boolean;
  showStroke: boolean;
  showText: boolean;
  showReferences: boolean;
  antialiasing: boolean;
  quality: 'low' | 'medium' | 'high';
}

/**
 * Renderer capabilities
 */
export interface RendererCapabilities {
  backend: 'canvas2d' | 'webgl' | 'webgl2' | 'webgpu';
  supportsInstancing: boolean;
  supportsAntialiasing: boolean;
  supportsMultisample: boolean;
  maxTextureSize: number;
  maxViewportDims: number[];
}

/**
 * Base renderer interface that all backends must implement
 */
export interface IRenderer {
  // ========================================================================
  // Lifecycle Management
  // ========================================================================

  /**
   * Initializes the renderer with a canvas element
   */
  initialize(canvas: HTMLCanvasElement): Promise<void>;

  /**
   * Disposes of all renderer resources
   */
  dispose(): void;

  /**
   * Checks if renderer is ready to render
   */
  isReady(): boolean;

  // ========================================================================
  // Scene Management
  // ========================================================================

  /**
   * Sets the library to render
   */
  setLibrary(library: GDSLibrary): void;

  /**
   * Updates the scene graph (called after library changes)
   */
  updateSceneGraph(): void;

  /**
   * Clears the current scene
   */
  clearScene(): void;

  /**
   * Gets the scene graph instance (for bounds calculation)
   */
  getSceneGraph(): any; // Returns SceneGraph but avoided import to prevent circular dependency

  // ========================================================================
  // Rendering
  // ========================================================================

  /**
   * Renders the scene for the given viewport
   */
  render(viewport: Viewport): void;

  /**
   * Requests a render on the next frame
   */
  requestRender(): void;

  /**
   * Forces an immediate render
   */
  renderImmediate(viewport: Viewport): void;

  // ========================================================================
  // Layer Management
  // ========================================================================

  /**
   * Sets visibility for a specific layer
   */
  setLayerVisible(layer: number, dataType: number, visible: boolean): void;

  /**
   * Sets rendering style for a specific layer
   */
  setLayerStyle(layer: number, dataType: number, style: LayerStyle): void;

  /**
   * Gets current style for a layer
   */
  getLayerStyle(layer: number, dataType: number): LayerStyle | null;

  // ========================================================================
  // Interactive Features
  // ========================================================================

  /**
   * Picks element at screen coordinates
   */
  pick(screenX: number, screenY: number, viewport: Viewport): PickResult | null;

  /**
   * Gets elements in a screen-space region
   */
  getElementsInRegion(
    screenBBox: { x: number; y: number; width: number; height: number },
    viewport: Viewport
  ): SpatialElement[];

  // ========================================================================
  // Configuration
  // ========================================================================

  /**
   * Sets render options
   */
  setRenderOptions(options: Partial<RenderOptions>): void;

  /**
   * Gets current render options
   */
  getRenderOptions(): RenderOptions;

  /**
   * Gets renderer capabilities
   */
  getCapabilities(): RendererCapabilities;

  // ========================================================================
  // Performance & Debugging
  // ========================================================================

  /**
   * Gets rendering statistics
   */
  getStatistics(): RenderStatistics;

  /**
   * Resets performance counters
   */
  resetStatistics(): void;

  /**
   * Enables/disables debug visualization
   */
  setDebugMode(enabled: boolean): void;

  // ========================================================================
  // Coordinate Transformation
  // ========================================================================

  /**
   * Converts screen coordinates to world coordinates
   */
  screenToWorld(screenX: number, screenY: number, viewport: Viewport): GDSPoint;

  /**
   * Converts world coordinates to screen coordinates
   */
  worldToScreen(worldX: number, worldY: number, viewport: Viewport): GDSPoint;
}

/**
 * Default render options
 */
export const DEFAULT_RENDER_OPTIONS: RenderOptions = {
  showFill: true,
  showStroke: true,
  showText: true,
  showReferences: false,
  antialiasing: true,
  quality: 'medium'
};

/**
 * Default layer style
 */
export const DEFAULT_LAYER_STYLE: LayerStyle = {
  color: '#888888',
  fillEnabled: true,
  strokeEnabled: true,
  opacity: 0.7,
  lineWidth: 1
};
