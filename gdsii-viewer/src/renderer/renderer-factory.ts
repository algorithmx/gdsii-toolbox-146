/**
 * Renderer Factory
 * 
 * Creates renderer instances based on backend type and capabilities.
 * Handles fallback to Canvas2D if WebGL is not available.
 */

import type { IRenderer } from './renderer-interface';
import { Canvas2DRenderer } from './canvas2d-renderer';
import { WebGLRenderer } from './webgl/webgl-renderer';

/**
 * Renderer backend types
 */
export type RendererBackend = 'auto' | 'canvas2d' | 'webgl' | 'webgl2';

/**
 * Renderer configuration options
 */
export interface RendererConfig {
  backend?: RendererBackend;
  preferWebGL?: boolean;
  fallbackToCanvas2D?: boolean;
  debug?: boolean;
}

/**
 * Default renderer configuration
 */
const DEFAULT_CONFIG: Required<RendererConfig> = {
  backend: 'auto',
  preferWebGL: true,
  fallbackToCanvas2D: true,
  debug: false
};

/**
 * Factory class for creating renderers
 */
export class RendererFactory {
  /**
   * Creates a renderer instance based on configuration
   */
  static async create(
    canvas: HTMLCanvasElement,
    config: RendererConfig = {}
  ): Promise<IRenderer> {
    const fullConfig = { ...DEFAULT_CONFIG, ...config };

    let backend = fullConfig.backend;
    
    // Auto-detect best backend
    if (backend === 'auto') {
      backend = this.detectBestBackend(fullConfig.preferWebGL);
    }

    try {
      const renderer = await this.createBackend(canvas, backend);
      
      if (fullConfig.debug) {
        renderer.setDebugMode(true);
        console.log(`✓ Renderer created: ${backend}`);
        console.log('Capabilities:', renderer.getCapabilities());
      }

      return renderer;
    } catch (error) {
      console.error(`Failed to create ${backend} renderer:`, error);

      // Fallback to Canvas2D if enabled
      if (fullConfig.fallbackToCanvas2D && backend !== 'canvas2d') {
        console.log('Falling back to Canvas2D renderer...');
        return this.createBackend(canvas, 'canvas2d');
      }

      throw error;
    }
  }

  /**
   * Detects the best available backend
   */
  private static detectBestBackend(preferWebGL: boolean): RendererBackend {
    if (preferWebGL) {
      // Check for WebGL2 support
      if (this.supportsWebGL2()) {
        return 'webgl2';
      }

      // Check for WebGL support
      if (this.supportsWebGL()) {
        return 'webgl';
      }
    }

    // Fall back to Canvas2D
    return 'canvas2d';
  }

  /**
   * Creates a renderer for the specified backend
   */
  private static async createBackend(
    canvas: HTMLCanvasElement,
    backend: RendererBackend
  ): Promise<IRenderer> {
    switch (backend) {
      case 'canvas2d':
        return this.createCanvas2DRenderer(canvas);

      case 'webgl':
      case 'webgl2':
        return this.createWebGLRenderer(canvas);

      default:
        throw new Error(`Unknown renderer backend: ${backend}`);
    }
  }

  /**
   * Creates a Canvas2D renderer instance
   */
  private static async createCanvas2DRenderer(
    canvas: HTMLCanvasElement
  ): Promise<IRenderer> {
    const renderer = new Canvas2DRenderer();
    await renderer.initialize(canvas);
    return renderer;
  }

  /**
   * Creates a WebGL renderer instance
   */
  private static async createWebGLRenderer(
    canvas: HTMLCanvasElement
  ): Promise<IRenderer> {
    const renderer = new WebGLRenderer();
    await renderer.initialize(canvas);
    return renderer;
  }

  /**
   * Checks if WebGL is supported
   */
  private static supportsWebGL(): boolean {
    try {
      const canvas = document.createElement('canvas');
      const gl = canvas.getContext('webgl') || canvas.getContext('experimental-webgl');
      return gl !== null;
    } catch {
      return false;
    }
  }

  /**
   * Checks if WebGL2 is supported
   */
  private static supportsWebGL2(): boolean {
    try {
      const canvas = document.createElement('canvas');
      const gl = canvas.getContext('webgl2');
      return gl !== null;
    } catch {
      return false;
    }
  }

  /**
   * Gets information about available backends
   */
  static getAvailableBackends(): {
    canvas2d: boolean;
    webgl: boolean;
    webgl2: boolean;
    recommended: RendererBackend;
  } {
    const canvas2d = true; // Always available
    const webgl = this.supportsWebGL();
    const webgl2 = this.supportsWebGL2();

    let recommended: RendererBackend = 'canvas2d';
    if (webgl2) {
      recommended = 'webgl2';
    } else if (webgl) {
      recommended = 'webgl';
    }

    return {
      canvas2d,
      webgl,
      webgl2,
      recommended
    };
  }

  /**
   * Gets a user-friendly description of backend capabilities
   */
  static getBackendInfo(): string[] {
    const backends = this.getAvailableBackends();
    const info: string[] = [];

    if (backends.canvas2d) {
      info.push('✓ Canvas2D: Available (fallback)');
    }

    if (backends.webgl) {
      info.push('✓ WebGL: Available');
    } else {
      info.push('✗ WebGL: Not supported');
    }

    if (backends.webgl2) {
      info.push('✓ WebGL2: Available (best performance)');
    } else {
      info.push('✗ WebGL2: Not supported');
    }

    info.push(`→ Recommended: ${backends.recommended.toUpperCase()}`);

    return info;
  }
}
