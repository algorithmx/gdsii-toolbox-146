/**
 * Renderer Module Exports
 * 
 * Central export point for all rendering components.
 */

// Core interfaces and types
export type {
  IRenderer,
  LayerStyle,
  RenderStatistics,
  PickResult,
  RenderOptions,
  RendererCapabilities
} from './renderer-interface';

export {
  DEFAULT_RENDER_OPTIONS,
  DEFAULT_LAYER_STYLE
} from './renderer-interface';

// Base renderer
export { BaseRenderer } from './base-renderer';

// Renderer implementations
export { Canvas2DRenderer } from './canvas2d-renderer';

// Factory
export {
  RendererFactory,
  type RendererBackend,
  type RendererConfig
} from './renderer-factory';
