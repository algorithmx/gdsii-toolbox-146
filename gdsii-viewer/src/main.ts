import './style.css'

// Import the enhanced GDSII types and utilities
import {
  GDSLibrary,
  GDSElement,
  GDSPoint,
  GDSBBox,
  DEFAULT_LAYER_COLORS,
  GDSRenderOptions,
  DEFAULT_RENDER_OPTIONS
} from './gdsii-types';

import {
  isValidBBox
} from './gdsii-utils';

import {
  parseGDSII,
  loadWASMModule,
  validateWASMModule,
  loadConfig,
  autoLoadGDSFile
} from './wasm-interface';

import {
  calculateLibraryBBox
} from './hierarchy-resolver';

// Import new rendering system
import {
  RendererFactory,
  type IRenderer,
  type RenderStatistics,
  type LayerStyle
} from './renderer';

import type { Viewport } from './scene';
import { logger, LogCategory } from './debug-logger';

class GDSViewer {
  private canvas: HTMLCanvasElement;
  private fileInput: HTMLInputElement;
  private loadButton: HTMLButtonElement;
  private fileInfo: HTMLParagraphElement;
  private layerList: HTMLDivElement;
  private zoomInButton: HTMLButtonElement;
  private zoomOutButton: HTMLButtonElement;
  private resetViewButton: HTMLButtonElement;
  private infoPanel: HTMLDivElement;
  private backendSelector: HTMLSelectElement;
  private backendInfo: HTMLParagraphElement;

  // New rendering system
  private renderer: IRenderer | null = null;
  private currentLibrary: GDSLibrary | null = null;
  private libraryBBox: GDSBBox | null = null;
  private renderOptions: GDSRenderOptions = { ...DEFAULT_RENDER_OPTIONS };

  // Viewport state (used by new renderer)
  private viewport: Viewport = {
    center: { x: 0, y: 0 },
    width: 0,
    height: 0,
    zoom: 1
  };

  // Interaction state
  private isDragging: boolean = false;
  private dragStart: GDSPoint = { x: 0, y: 0 };
  private lastViewportCenter: GDSPoint = { x: 0, y: 0 };

  // WASM module state
  private wasmLoaded: boolean = false;

  // Performance monitoring
  private renderAnimationFrame: number | null = null;

  constructor() {
    this.canvas = document.getElementById('gdsCanvas') as HTMLCanvasElement;
    this.fileInput = document.getElementById('fileInput') as HTMLInputElement;
    this.loadButton = document.getElementById('loadButton') as HTMLButtonElement;
    this.fileInfo = document.getElementById('fileInfo') as HTMLParagraphElement;
    this.layerList = document.getElementById('layerList') as HTMLDivElement;
    this.zoomInButton = document.getElementById('zoomIn') as HTMLButtonElement;
    this.zoomOutButton = document.getElementById('zoomOut') as HTMLButtonElement;
    this.resetViewButton = document.getElementById('resetView') as HTMLButtonElement;
    this.infoPanel = document.getElementById('infoPanel') as HTMLDivElement;
    this.backendSelector = document.getElementById('backendSelector') as HTMLSelectElement;
    this.backendInfo = document.getElementById('backendInfo') as HTMLParagraphElement;

    // Initialize debug logger first
    logger.initializeUI();
    logger.info(LogCategory.SYSTEM, 'Application starting...');
    
    this.initializeRenderer();
    this.initializeWASM();
    this.setupEventListeners();
    this.resizeCanvas();
  }

  /**
   * Initialize the rendering system
   */
  private async initializeRenderer(): Promise<void> {
    try {
      console.log('🎨 Initializing renderer...');
      
      this.renderer = await RendererFactory.create(this.canvas, {
        backend: 'auto',
        debug: true,  // Enable debug mode to see culling statistics
        preferWebGL: true  // Enable WebGL for Phase 2
      });

      console.log('✓ Renderer initialized');
      console.log('Backend info:', RendererFactory.getBackendInfo());
      
      const caps = this.renderer.getCapabilities();
      console.log(`Using ${caps.backend.toUpperCase()} backend`);
      
      // Update backend info display
      this.updateBackendInfo();
      
      // Draw placeholder
      this.drawPlaceholder();
    } catch (error) {
      console.error('Failed to initialize renderer:', error);
      throw error;
    }
  }

  /**
   * Initialize the WASM module
   */
  private async initializeWASM(): Promise<void> {
    try {
      await loadWASMModule();
      this.wasmLoaded = true;
      console.log('GDS parser WASM module loaded successfully');

      // Initialize auto-load functionality
      await this.initializeAutoLoad();
    } catch (error) {
      console.error('Failed to load WASM module:', error);
      this.showMessage('Failed to load GDS parser. Using fallback mode.');
      // Don't throw - we can still use placeholder data
    }
  }

  /**
   * Initialize auto-load functionality based on configuration
   */
  private async initializeAutoLoad(): Promise<void> {
    try {
      console.log('🔄 Initializing auto-load functionality...');

      // Load configuration
      const config = await loadConfig();
      console.log('✓ Configuration loaded:', config);

      // Attempt auto-load if enabled
      const library = await autoLoadGDSFile(config);

      if (library) {
        console.log('✓ Auto-load successful!');
        this.currentLibrary = library;

        // Process the parsed library
        await this.processLibrary();
        this.updateFileInfo('auto-loaded.gds');
        this.updateLayerList();
        this.resetView();

        console.log('✓ Auto-loaded GDSII file processed and rendered');
      } else {
        console.log('ℹ️ Auto-load disabled or failed - showing placeholder');
      }
    } catch (error) {
      console.error('❌ Auto-load initialization failed:', error);
      this.showMessage(`Auto-load failed: ${error instanceof Error ? error.message : 'Unknown error'}`);
    }
  }

  private setupEventListeners() {
    this.loadButton.addEventListener('click', () => this.loadFile());
    this.fileInput.addEventListener('change', () => this.processFile());

    this.zoomInButton.addEventListener('click', () => this.zoom(1.2));
    this.zoomOutButton.addEventListener('click', () => this.zoom(0.8));
    this.resetViewButton.addEventListener('click', () => this.resetView());

    this.canvas.addEventListener('mousedown', (e) => this.handleMouseDown(e));
    this.canvas.addEventListener('mousemove', (e) => this.handleMouseMove(e));
    this.canvas.addEventListener('mouseup', () => this.handleMouseUp());
    this.canvas.addEventListener('wheel', (e) => this.handleWheel(e));

    this.backendSelector.addEventListener('change', () => this.switchBackend());

    window.addEventListener('resize', () => this.resizeCanvas());
  }

  private async loadFile() {
    this.fileInput.click();
  }

  private async processFile() {
    const file = this.fileInput.files?.[0];
    if (!file) {
      this.showMessage('Please select a GDSII file');
      return;
    }

    if (!file.name.match(/\.(gds|gdsii|gds2)$/i)) {
      this.showMessage('Please select a valid GDSII file (.gds, .gdsii, .gds2)');
      return;
    }

    this.showMessage(`Loading ${file.name}...`);

    try {
      const arrayBuffer = await file.arrayBuffer();
      const data = new Uint8Array(arrayBuffer);

      // Parse the GDSII file using WASM or fallback
      if (this.wasmLoaded && validateWASMModule()) {
        this.currentLibrary = await parseGDSII(data);
      } else {
        // Fallback to placeholder data if WASM is not available
        this.currentLibrary = await this.parseGDSIIPlaceholder(data);
      }

      // Process the parsed library
      await this.processLibrary();
      this.updateFileInfo(file.name);
      this.updateLayerList();
      this.resetView();

    } catch (error) {
      console.error('Error loading GDSII file:', error);
      this.showMessage(`Error loading file: ${error instanceof Error ? error.message : 'Unknown error'}`);
    }
  }

  /**
   * Placeholder parser for when WASM is not available
   */
  private async parseGDSIIPlaceholder(data: Uint8Array): Promise<GDSLibrary> {
    console.log('Using placeholder GDSII parser - received', data.length, 'bytes');

    await new Promise(resolve => setTimeout(resolve, 500));

    return {
      name: 'Demo Library (Placeholder)',
      units: {
        userUnitsPerDatabaseUnit: 0.001,
        metersPerDatabaseUnit: 1e-9
      },
      structures: [
        {
          name: 'TOP_CELL',
          elements: [
            {
              type: 'boundary',
              layer: 1,
              dataType: 0,
              polygons: [
                [
                  { x: -100, y: -100 },
                  { x: 100, y: -100 },
                  { x: 100, y: 100 },
                  { x: -100, y: 100 }
                ]
              ]
            },
            {
              type: 'boundary',
              layer: 2,
              dataType: 0,
              polygons: [
                [
                  { x: -50, y: -50 },
                  { x: 50, y: -50 },
                  { x: 50, y: 50 },
                  { x: -50, y: 50 }
                ]
              ]
            },
            {
              type: 'path',
              layer: 3,
              dataType: 0,
              pathType: 0,
              width: 5,
              paths: [
                [
                  { x: -150, y: 0 },
                  { x: 150, y: 0 }
                ]
              ]
            }
          ],
          references: []
        }
      ]
    };
  }

  /**
   * Process the parsed library and load it into the renderer
   */
  private async processLibrary(): Promise<void> {
    if (!this.currentLibrary || !this.renderer) return;

    try {
      console.log('📦 Processing library...');

      // Clear any previous scene
      this.renderer.clearScene();

      // Load the library into the renderer
      this.renderer.setLibrary(this.currentLibrary);
      this.renderer.updateSceneGraph();

      // Get bounding box from scene graph (more accurate than calculating from raw library)
      const sceneGraph = this.renderer.getSceneGraph();
      if (sceneGraph) {
        this.libraryBBox = sceneGraph.getBounds();
      } else {
        // Fallback to calculating from library if scene graph not available
        this.libraryBBox = calculateLibraryBBox(this.currentLibrary);
      }

      console.log(`✓ Processed ${this.currentLibrary.structures.length} structures`);
      console.log(`✓ Library bounds:`, this.libraryBBox);

      // Initial render
      this.render();
    } catch (error) {
      console.error('Error processing library:', error);
      throw error;
    }
  }

  /**
   * Render the current scene using the new renderer
   */
  private render(): void {
    if (!this.renderer) return;

    // Update viewport dimensions
    this.viewport.width = this.canvas.width;
    this.viewport.height = this.canvas.height;

    // Render using the new renderer
    this.renderer.render(this.viewport);

    // Display statistics
    const stats = this.renderer.getStatistics();
    this.updateStatistics(stats);
  }

  private updateFileInfo(fileName: string) {
    if (!this.currentLibrary) return;

    const totalElements = this.currentLibrary.structures
      .reduce((sum, struct) => sum + struct.elements.length, 0);

    this.fileInfo.innerHTML = `
      <strong>File:</strong> ${fileName}<br>
      <strong>Library:</strong> ${this.currentLibrary.name}<br>
      <strong>Structures:</strong> ${this.currentLibrary.structures.length}<br>
      <strong>Total Elements:</strong> ${totalElements}
    `;
  }

  private updateLayerList() {
    if (!this.currentLibrary || !this.renderer) return;

    this.layerList.innerHTML = '';

    // Get layers from renderer by checking all layer/dataType combinations
    // For now, collect layers directly from the library
    const layerMap = new Map<string, {num: number, dataType: number}>();
    this.currentLibrary.structures.forEach(struct => {
      struct.elements.forEach(element => {
        const key = `${element.layer}_${element.dataType}`;
        if (!layerMap.has(key)) {
          layerMap.set(key, {num: element.layer, dataType: element.dataType});
        }
      });
    });
    
    const layers = new Map<string, LayerStyle>();
    layerMap.forEach((value, key) => {
      const style = this.renderer.getLayerStyle(value.num, value.dataType);
      if (style) {
        layers.set(key, style);
      }
    });
    
    // Sort layers by number for consistent display
    const sortedLayers = Array.from(layers.entries())
      .sort(([keyA, layerA], [keyB, layerB]) => {
        // Extract layer numbers from keys (format: "layer_datatype")
        const [numA] = keyA.split('_').map(Number);
        const [numB] = keyB.split('_').map(Number);
        return numA - numB;
      });

    sortedLayers.forEach(([layerKey, layerStyle]) => {
      const layerItem = document.createElement('div');
      layerItem.className = 'layer-item';
      
      const [layerNum, dataType] = layerKey.split('_');
      
      layerItem.innerHTML = `
        <input type="checkbox" id="layer-${layerKey}" checked>
        <span class="layer-color" style="background-color: ${layerStyle.color}"></span>
        <label for="layer-${layerKey}">Layer ${layerNum}:${dataType}</label>
      `;

      const checkbox = layerItem.querySelector('input') as HTMLInputElement;
      checkbox.addEventListener('change', () => {
        this.toggleLayer(layerKey, checkbox.checked);
      });

      this.layerList.appendChild(layerItem);
    });
  }

  private toggleLayer(layerKey: string, visible: boolean) {
    if (!this.renderer) return;
    
    const [layer, dataType] = layerKey.split('_').map(Number);
    this.renderer.setLayerVisible(layer, dataType, visible);
    this.render();
  }

  private updateStatistics(stats: RenderStatistics) {
    // Update info panel with rendering statistics
    const infoText = `
      FPS: ${stats.fps} | 
      Frame: ${stats.frameTime.toFixed(2)}ms | 
      Elements: ${stats.elementsRendered} | 
      Draw Calls: ${stats.drawCalls}
    `;
    
    // Create or update stats element
    let statsElement = document.getElementById('render-stats');
    if (!statsElement) {
      statsElement = document.createElement('div');
      statsElement.id = 'render-stats';
      statsElement.style.cssText = `
        position: absolute;
        top: 10px;
        right: 10px;
        background: rgba(0, 0, 0, 0.7);
        color: #0f0;
        padding: 8px 12px;
        font-family: monospace;
        font-size: 12px;
        border-radius: 4px;
        pointer-events: none;
      `;
      document.body.appendChild(statsElement);
    }
    statsElement.textContent = infoText;
  }

  private drawPlaceholder() {
    if (!this.renderer) return;

    // Just clear for now - renderer handles empty state
    this.renderer.clearScene();
    
    // Optionally, we could render some placeholder geometry
    console.log('Canvas ready. Load a GDSII file to visualize.');
  }

  // ========================================================================
  // Backend Switching
  // ========================================================================

  /**
   * Switch rendering backend
   */
  private async switchBackend(): Promise<void> {
    const selectedBackend = this.backendSelector.value as 'auto' | 'canvas2d' | 'webgl2';
    
    try {
      this.showMessage(`Switching to ${selectedBackend.toUpperCase()} renderer...`);
      
      // Store current state
      const currentLibrary = this.currentLibrary;
      const currentViewport = { ...this.viewport };
      
      // Dispose old renderer
      if (this.renderer) {
        this.renderer.dispose();
      }
      
      // Create new renderer
      this.renderer = await RendererFactory.create(this.canvas, {
        backend: selectedBackend,
        debug: true,
        preferWebGL: selectedBackend !== 'canvas2d'
      });
      
      // Update backend info
      this.updateBackendInfo();
      
      // Restore state if we had a library loaded
      if (currentLibrary) {
        this.renderer.setLibrary(currentLibrary);
        this.renderer.updateSceneGraph();
        this.viewport = currentViewport;
        this.render();
      }
      
      const caps = this.renderer.getCapabilities();
      this.showMessage(`Switched to ${caps.backend.toUpperCase()} renderer`);
    } catch (error) {
      console.error('Failed to switch backend:', error);
      this.showMessage(`Failed to switch backend: ${error instanceof Error ? error.message : 'Unknown error'}`);
    }
  }

  /**
   * Updates the backend info display
   */
  private updateBackendInfo(): void {
    if (!this.renderer) return;
    
    const caps = this.renderer.getCapabilities();
    const backends = RendererFactory.getAvailableBackends();
    
    let infoText = `Active: ${caps.backend.toUpperCase()}`;
    if (!backends.webgl2) {
      infoText += ' (WebGL2 unavailable)';
    }
    
    this.backendInfo.textContent = infoText;
  }

  // ========================================================================
  // View Controls
  // ========================================================================

  private zoom(factor: number) {
    this.viewport.zoom *= factor;
    this.viewport.zoom = Math.max(0.01, Math.min(100, this.viewport.zoom));
    this.render();
  }

  private resetView() {
    if (!this.libraryBBox || !isValidBBox(this.libraryBBox)) {
      // No valid bounds, reset to default view
      this.viewport = {
        center: { x: 0, y: 0 },
        width: this.canvas.width,
        height: this.canvas.height,
        zoom: 1
      };
    } else {
      // Fit library to view
      const bboxWidth = this.libraryBBox.maxX - this.libraryBBox.minX;
      const bboxHeight = this.libraryBBox.maxY - this.libraryBBox.minY;
      
      // Calculate zoom to fit the bbox in the canvas with 10% padding
      // Zoom represents canvas pixels per world unit
      const scaleX = (this.canvas.width * 0.9) / bboxWidth;
      const scaleY = (this.canvas.height * 0.9) / bboxHeight;
      const zoom = Math.min(scaleX, scaleY);

      this.viewport = {
        center: {
          x: (this.libraryBBox.minX + this.libraryBBox.maxX) / 2,
          y: (this.libraryBBox.minY + this.libraryBBox.maxY) / 2
        },
        width: this.canvas.width,
        height: this.canvas.height,
        zoom: zoom
      };
      
      console.log(`Reset view: bbox ${bboxWidth.toFixed(0)}x${bboxHeight.toFixed(0)}, canvas ${this.canvas.width}x${this.canvas.height}, zoom ${zoom.toFixed(4)}`);
      console.log(`Viewport center: (${this.viewport.center.x.toFixed(0)}, ${this.viewport.center.y.toFixed(0)})`);
    }

    this.render();
  }

  // ========================================================================
  // Mouse Interaction
  // ========================================================================

  private handleMouseDown(e: MouseEvent) {
    this.isDragging = true;
    this.dragStart = { x: e.clientX, y: e.clientY };
    this.lastViewportCenter = { ...this.viewport.center };
    this.canvas.style.cursor = 'grabbing';
  }

  private handleMouseMove(e: MouseEvent) {
    if (!this.isDragging) return;

    const dx = e.clientX - this.dragStart.x;
    const dy = e.clientY - this.dragStart.y;

    // Convert screen delta to world delta
    this.viewport.center.x = this.lastViewportCenter.x - dx / this.viewport.zoom;
    this.viewport.center.y = this.lastViewportCenter.y + dy / this.viewport.zoom; // Inverted Y

    this.render();
  }

  private handleMouseUp() {
    this.isDragging = false;
    this.canvas.style.cursor = 'grab';
  }

  private handleWheel(e: WheelEvent) {
    e.preventDefault();

    // Get mouse position in canvas coordinates
    const rect = this.canvas.getBoundingClientRect();
    const mouseX = e.clientX - rect.left;
    const mouseY = e.clientY - rect.top;

    // Convert to world coordinates before zoom
    const worldX = this.viewport.center.x + (mouseX - this.canvas.width / 2) / this.viewport.zoom;
    const worldY = this.viewport.center.y - (mouseY - this.canvas.height / 2) / this.viewport.zoom;

    // Apply zoom
    const zoomFactor = e.deltaY > 0 ? 0.9 : 1.1;
    const newZoom = this.viewport.zoom * zoomFactor;
    this.viewport.zoom = Math.max(0.01, Math.min(100, newZoom));

    // Adjust center to keep mouse position fixed in world space
    this.viewport.center.x = worldX - (mouseX - this.canvas.width / 2) / this.viewport.zoom;
    this.viewport.center.y = worldY + (mouseY - this.canvas.height / 2) / this.viewport.zoom;

    this.render();
  }

  // ========================================================================
  // Canvas Management
  // ========================================================================

  private resizeCanvas() {
    const container = this.canvas.parentElement;
    if (!container) return;

    const width = container.clientWidth;
    const height = container.clientHeight;

    // Set canvas size with device pixel ratio for sharp rendering
    const dpr = window.devicePixelRatio || 1;
    this.canvas.width = width * dpr;
    this.canvas.height = height * dpr;
    this.canvas.style.width = `${width}px`;
    this.canvas.style.height = `${height}px`;

    // Update viewport dimensions
    this.viewport.width = this.canvas.width;
    this.viewport.height = this.canvas.height;

    // Notify renderer of resize by just re-rendering with updated viewport
    if (this.renderer) {
      this.render();
    }
  }

  // ========================================================================
  // Utility Methods
  // ========================================================================

  private showMessage(message: string, duration: number = 3000) {
    console.log(message);
    
    // Create or update message element
    let msgElement = document.getElementById('toast-message');
    if (!msgElement) {
      msgElement = document.createElement('div');
      msgElement.id = 'toast-message';
      msgElement.style.cssText = `
        position: fixed;
        top: 20px;
        left: 50%;
        transform: translateX(-50%);
        background: rgba(0, 0, 0, 0.8);
        color: white;
        padding: 12px 24px;
        border-radius: 4px;
        font-size: 14px;
        z-index: 1000;
        transition: opacity 0.3s;
      `;
      document.body.appendChild(msgElement);
    }
    
    msgElement.textContent = message;
    msgElement.style.opacity = '1';
    
    // Auto-hide after duration
    setTimeout(() => {
      msgElement!.style.opacity = '0';
      setTimeout(() => msgElement!.remove(), 300);
    }, duration);
  }

  /**
   * Get library information for debugging
   */
  public getLibraryInfo() {
    if (!this.currentLibrary) {
      return null;
    }

    const stats = this.renderer?.getStatistics();

    return {
      name: this.currentLibrary.name,
      structureCount: this.currentLibrary.structures.length,
      totalElements: this.currentLibrary.structures
        .reduce((sum, struct) => sum + struct.elements.length, 0),
      bounds: this.libraryBBox,
      units: this.currentLibrary.units,
      renderStats: stats
    };
  }
}

// Initialize the application
const viewer = new GDSViewer();

// Export for debugging
(window as any).gdsViewer = viewer;
