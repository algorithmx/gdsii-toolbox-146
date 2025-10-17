# GDSII Viewer - Full-Functional Rendering Module Implementation Plan

**Date:** October 16, 2025  
**Project:** gdsii-toolbox-146  
**Focus:** Rendering functionality (assuming load/parse via WASM is correct)

---

## Executive Summary

This document outlines a comprehensive plan for implementing a production-ready rendering module for the GDSII Viewer TypeScript application. The rendering system will cooperate with the existing WASM-based loading/parsing functionality, providing high-performance visualization of complex GDSII files with interactive features and advanced visual capabilities.

---

## Current State Analysis

### ✅ Completed Components

#### 1. WASM Integration Layer
- **Status:** Production-ready
- **Features:**
  - 40+ exported C functions for GDSII access
  - Complete memory management (allocation, copying, cleanup)
  - Error handling and validation
  - Performance monitoring capabilities
  - Auto-loading from configuration
  
#### 2. TypeScript Data Structures
- **Status:** Complete
- **Components:**
  - `GDSLibrary`, `GDSStructure`, `GDSElement` type hierarchies
  - All element types: boundary, path, text, box, node, sref, aref
  - Transformation system with 3x3 matrices
  - Property and metadata structures
  - Layer management types
  
#### 3. Basic Canvas2D Renderer
- **Status:** Functional but limited
- **Current Capabilities:**
  - Element drawing: boundary, path, box, node, text
  - Basic coordinate transformation
  - Layer visibility controls
  - Simple zoom/pan interactions
  - Layer-based coloring
  
#### 4. Hierarchy Resolution
- **Status:** Implemented but undertested
- **Features:**
  - SREF/AREF transformation matrix calculations
  - Structure flattening with caching
  - Bounding box calculations
  - Circular reference detection

### ⚠️ Missing or Incomplete Features

#### Performance Optimization
- No viewport culling or frustum clipping
- No spatial indexing (quadtree/R-tree)
- No level-of-detail (LOD) system
- Renders all elements every frame
- No render command batching

#### Rendering Quality
- No WebGL acceleration option
- Limited anti-aliasing
- No texture/pattern support
- Basic text rendering only
- No alpha blending options

#### Interactive Features
- No element picking/selection
- No hover tooltips
- No measurement tools
- Limited navigation controls

#### Visual Enhancements
- No minimap or overview
- No grid/ruler system
- No reference visualization
- No transformation feedback

---

## Architecture Design

### Rendering Pipeline

```
┌──────────────┐
│  WASM Parse  │
│   (C Code)   │
└──────┬───────┘
       │
       ▼
┌──────────────────────┐
│  TypeScript Import   │
│  - GDSLibrary        │
│  - Structures        │
│  - Elements          │
└──────┬───────────────┘
       │
       ▼
┌──────────────────────┐
│  Hierarchy Resolver  │
│  - Flatten SREF/AREF │
│  - Transform matrix  │
│  - Build cache       │
└──────┬───────────────┘
       │
       ▼
┌──────────────────────┐
│  Scene Graph         │
│  - Spatial index     │
│  - BBox calculation  │
│  - Layer grouping    │
└──────┬───────────────┘
       │
       ▼
┌──────────────────────┐
│  Render Preparation  │
│  - Viewport culling  │
│  - LOD selection     │
│  - Command batching  │
└──────┬───────────────┘
       │
       ├────────────────┬────────────────┐
       ▼                ▼                ▼
┌─────────────┐  ┌─────────────┐  ┌─────────────┐
│  Canvas2D   │  │   WebGL     │  │   WebGPU    │
│  Renderer   │  │  Renderer   │  │  Renderer   │
│  (Fallback) │  │ (Preferred) │  │  (Future)   │
└─────────────┘  └─────────────┘  └─────────────┘
```

### Core Modules

#### 1. Renderer Interface
```typescript
interface IRenderer {
  // Initialization
  initialize(canvas: HTMLCanvasElement): Promise<void>;
  dispose(): void;
  
  // Scene management
  setLibrary(library: GDSLibrary): void;
  updateSceneGraph(): void;
  
  // Rendering
  render(viewport: Viewport): void;
  requestRender(): void;
  
  // Layer control
  setLayerVisible(layer: number, visible: boolean): void;
  setLayerStyle(layer: number, style: LayerStyle): void;
  
  // Interactive features
  pick(x: number, y: number): PickResult | null;
  getElementsInRegion(bbox: BBox): GDSElement[];
  
  // Performance
  getStatistics(): RenderStatistics;
}
```

#### 2. Scene Graph
```typescript
class SceneGraph {
  private spatialIndex: QuadTree;
  private layerGroups: Map<number, LayerGroup>;
  private elementCache: Map<string, CachedElement>;
  
  // Build scene from library
  buildFromLibrary(library: GDSLibrary): void;
  
  // Spatial queries
  queryViewport(viewport: Viewport): GDSElement[];
  queryPoint(x: number, y: number): GDSElement[];
  queryRegion(bbox: BBox): GDSElement[];
  
  // Updates
  invalidate(): void;
  updateSpatialIndex(): void;
}
```

#### 3. Spatial Index (QuadTree)
```typescript
class QuadTree {
  private bounds: BBox;
  private capacity: number;
  private elements: SpatialElement[];
  private divided: boolean;
  private children: QuadTree[] | null;
  
  insert(element: SpatialElement): boolean;
  query(range: BBox): SpatialElement[];
  clear(): void;
  subdivide(): void;
}
```

#### 4. Render Command Queue
```typescript
interface RenderCommand {
  type: 'boundary' | 'path' | 'text' | 'box';
  layer: number;
  geometry: GeometryData;
  transform: Matrix3x3;
  style: RenderStyle;
}

class RenderCommandQueue {
  private commands: RenderCommand[];
  
  enqueue(command: RenderCommand): void;
  sort(): void;  // Sort by layer, material, etc.
  execute(renderer: IRenderer): void;
  clear(): void;
}
```

---

## Implementation Phases

### Phase 1: Foundation (Weeks 1-2)

#### 1.1 Scene Graph & Spatial Index
**Goal:** Efficient spatial queries for viewport culling

**Tasks:**
- [ ] Implement QuadTree data structure
- [ ] Add bounding box calculation for all element types
- [ ] Build spatial index during library import
- [ ] Implement viewport query methods
- [ ] Add unit tests for spatial queries

**Files to Create/Modify:**
- `src/spatial-index.ts` (new)
- `src/scene-graph.ts` (new)
- `src/gdsii-utils.ts` (extend)

**Deliverables:**
- Working QuadTree with insert/query operations
- Scene graph that builds from GDSLibrary
- Viewport culling reduces rendered elements by 80%+

#### 1.2 Renderer Architecture
**Goal:** Clean abstraction for multiple rendering backends

**Tasks:**
- [ ] Define IRenderer interface
- [ ] Create RendererFactory
- [ ] Implement Canvas2D renderer (refactor existing)
- [ ] Add renderer lifecycle management
- [ ] Implement render command queue

**Files to Create/Modify:**
- `src/renderer/renderer-interface.ts` (new)
- `src/renderer/canvas2d-renderer.ts` (refactor from main.ts)
- `src/renderer/renderer-factory.ts` (new)
- `src/renderer/render-command-queue.ts` (new)

**Deliverables:**
- Working Canvas2D renderer matching current functionality
- Renderer can be swapped without UI changes
- Command queue batches similar draw operations

### Phase 2: WebGL Backend (Weeks 3-4)

#### 2.1 WebGL Infrastructure
**Goal:** High-performance GPU-accelerated rendering

**Tasks:**
- [ ] Set up WebGL2 context management
- [ ] Implement shader compilation system
- [ ] Create geometry buffer management
- [ ] Add texture atlas for layers
- [ ] Implement instancing for references

**Files to Create:**
- `src/renderer/webgl-renderer.ts`
- `src/renderer/webgl-context.ts`
- `src/renderer/shader-program.ts`
- `src/renderer/geometry-buffer.ts`
- `shaders/boundary.vert/frag`
- `shaders/path.vert/frag`
- `shaders/text.vert/frag`

**Shaders:**
```glsl
// boundary.vert
#version 300 es
precision highp float;

in vec2 a_position;
in vec2 a_texcoord;

uniform mat3 u_matrix;      // View-projection matrix
uniform mat3 u_transform;   // Element transformation

out vec2 v_texcoord;

void main() {
  vec3 pos = u_matrix * u_transform * vec3(a_position, 1.0);
  gl_Position = vec4(pos.xy, 0.0, 1.0);
  v_texcoord = a_texcoord;
}

// boundary.frag
#version 300 es
precision highp float;

in vec2 v_texcoord;
uniform vec4 u_color;
uniform sampler2D u_pattern;

out vec4 fragColor;

void main() {
  vec4 pattern = texture(u_pattern, v_texcoord);
  fragColor = u_color * pattern;
}
```

**Deliverables:**
- WebGL renderer with feature parity to Canvas2D
- 5-10x performance improvement for large files
- Smooth 60 FPS rendering with 100K+ elements

#### 2.2 Geometry Processing
**Goal:** Efficient GPU buffer generation

**Tasks:**
- [ ] Implement polygon triangulation (Earcut.js)
- [ ] Create vertex buffer generation
- [ ] Add instanced rendering for SREF/AREF
- [ ] Implement dynamic buffer updates
- [ ] Add geometry simplification for LOD

**Files to Create:**
- `src/renderer/geometry-processor.ts`
- `src/renderer/triangulator.ts`
- `src/renderer/instance-manager.ts`

**Deliverables:**
- Triangulated geometry for all polygon types
- Instanced rendering reduces memory by 90% for arrays
- Geometry updates without full rebuild

### Phase 3: Advanced Features (Weeks 5-6)

#### 3.1 Level-of-Detail System
**Goal:** Scalable rendering for huge designs

**Tasks:**
- [ ] Define LOD levels based on zoom
- [ ] Implement polygon simplification
- [ ] Create aggregation for distant elements
- [ ] Add progressive rendering
- [ ] Implement smooth LOD transitions

**Files to Create:**
- `src/lod/lod-manager.ts`
- `src/lod/simplification.ts`
- `src/lod/aggregation.ts`

**LOD Levels:**
```typescript
enum LODLevel {
  FULL_DETAIL = 0,      // < 100 units/pixel
  HIGH_DETAIL = 1,      // 100-500 units/pixel
  MEDIUM_DETAIL = 2,    // 500-2000 units/pixel
  LOW_DETAIL = 3,       // 2000-10000 units/pixel
  BOUNDING_BOX = 4      // > 10000 units/pixel
}
```

**Deliverables:**
- Automatic LOD switching maintains 60 FPS
- Visual quality degrades gracefully with zoom out
- Memory usage reduces by 70% for distant objects

#### 3.2 Interactive Features
**Goal:** Rich user interaction

**Tasks:**
- [ ] Implement element picking (GPU-based)
- [ ] Add selection highlighting
- [ ] Create hover tooltips
- [ ] Build measurement tools
- [ ] Implement rubber-band selection

**Files to Create:**
- `src/interaction/picker.ts`
- `src/interaction/selection-manager.ts`
- `src/interaction/measurement-tools.ts`
- `src/ui/tooltip.ts`

**Deliverables:**
- Accurate element picking at any zoom level
- Multi-element selection with visual feedback
- Distance, area, and angle measurement tools
- Property inspector integration

### Phase 4: Polish & Optimization (Weeks 7-8)

#### 4.1 Visual Enhancements
**Goal:** Professional-quality visualization

**Tasks:**
- [ ] Add anti-aliasing (MSAA for WebGL)
- [ ] Implement proper text rendering
- [ ] Create grid and ruler system
- [ ] Add minimap overlay
- [ ] Implement smooth animations

**Files to Create:**
- `src/visual/text-renderer.ts`
- `src/visual/grid-renderer.ts`
- `src/ui/minimap.ts`
- `src/animation/animator.ts`

**Deliverables:**
- Crisp edges with anti-aliasing
- Readable text at all zoom levels
- Helpful grid/ruler for measurements
- Minimap for large design navigation

#### 4.2 Performance Optimization
**Goal:** Production-ready performance

**Tasks:**
- [ ] Implement render command batching
- [ ] Add element caching for SREF/AREF
- [ ] Optimize transformation calculations
- [ ] Add worker-based background processing
- [ ] Implement GPU memory management

**Files to Modify:**
- `src/renderer/webgl-renderer.ts`
- `src/renderer/canvas2d-renderer.ts`
- `src/workers/geometry-worker.ts` (new)

**Performance Targets:**
```
File Size (elements) | Target FPS | Memory Usage
---------------------|------------|-------------
< 10K elements       | 60         | < 100MB
10K-100K elements    | 60         | 100-500MB
100K-1M elements     | 30-60      | 500MB-2GB
> 1M elements        | 15-30      | 2-4GB
```

**Deliverables:**
- Consistent 60 FPS for files under 100K elements
- Graceful degradation for massive files
- Memory usage within browser limits
- Startup time < 3 seconds for typical files

---

## Module Structure

```
gdsii-viewer/
├── src/
│   ├── main.ts                      # Entry point (refactored)
│   ├── gds-viewer.ts                # Main viewer class (simplified)
│   │
│   ├── renderer/
│   │   ├── renderer-interface.ts    # IRenderer interface
│   │   ├── renderer-factory.ts      # Factory for creating renderers
│   │   ├── canvas2d-renderer.ts     # Canvas2D implementation
│   │   ├── webgl-renderer.ts        # WebGL implementation
│   │   ├── render-command-queue.ts  # Command queue for batching
│   │   ├── render-state.ts          # State management
│   │   ├── geometry-processor.ts    # Geometry generation
│   │   ├── geometry-buffer.ts       # GPU buffer management
│   │   ├── shader-program.ts        # Shader compilation
│   │   └── triangulator.ts          # Polygon triangulation
│   │
│   ├── scene/
│   │   ├── scene-graph.ts           # Scene graph manager
│   │   ├── scene-node.ts            # Scene node representation
│   │   ├── spatial-index.ts         # QuadTree implementation
│   │   └── layer-manager.ts         # Enhanced layer management
│   │
│   ├── lod/
│   │   ├── lod-manager.ts           # LOD level management
│   │   ├── simplification.ts        # Geometry simplification
│   │   └── aggregation.ts           # Element aggregation
│   │
│   ├── interaction/
│   │   ├── picker.ts                # Element picking
│   │   ├── selection-manager.ts     # Selection state
│   │   ├── measurement-tools.ts     # Measurement overlays
│   │   └── viewport-controller.ts   # Camera/viewport control
│   │
│   ├── visual/
│   │   ├── text-renderer.ts         # Advanced text rendering
│   │   ├── grid-renderer.ts         # Grid overlay
│   │   ├── ruler-renderer.ts        # Ruler overlay
│   │   └── reference-visualizer.ts  # Reference indicators
│   │
│   ├── ui/
│   │   ├── minimap.ts               # Minimap component
│   │   ├── tooltip.ts               # Hover tooltips
│   │   ├── statistics-panel.ts      # Performance stats
│   │   └── layer-panel.ts           # Enhanced layer controls
│   │
│   ├── animation/
│   │   └── animator.ts              # Smooth transitions
│   │
│   ├── workers/
│   │   └── geometry-worker.ts       # Background processing
│   │
│   └── types/
│       ├── render-types.ts          # Rendering type definitions
│       └── performance-types.ts     # Performance monitoring types
│
├── shaders/
│   ├── boundary.vert
│   ├── boundary.frag
│   ├── path.vert
│   ├── path.frag
│   ├── text.vert
│   ├── text.frag
│   └── common.glsl                  # Shared shader utilities
│
└── tests/
    ├── unit/
    │   ├── spatial-index.test.ts
    │   ├── scene-graph.test.ts
    │   ├── geometry-processor.test.ts
    │   └── lod-manager.test.ts
    │
    ├── integration/
    │   ├── rendering.test.ts
    │   └── wasm-integration.test.ts
    │
    └── performance/
        └── benchmark.test.ts
```

---

## Testing Strategy

### Unit Tests
- **Spatial Index:** Insert, query, subdivide operations
- **Scene Graph:** Build, update, query methods
- **Geometry Processing:** Triangulation, buffer generation
- **LOD System:** Level calculation, simplification
- **Transformation Math:** Matrix multiplication, point transforms

### Integration Tests
- **WASM Integration:** Parse → Import → Render pipeline
- **Renderer Switching:** Canvas2D ↔ WebGL
- **Interactive Features:** Pick, select, measure
- **Memory Management:** No leaks, proper cleanup

### Visual Regression Tests
- Reference images for standard GDSII files
- Compare rendered output pixel-by-pixel
- Detect unintended visual changes

### Performance Tests
```typescript
describe('Performance Benchmarks', () => {
  it('renders 10K elements at 60 FPS', async () => {
    const library = await loadTestLibrary('10k_elements.gds');
    const fps = measureRenderingFPS(library, 5000); // 5 second test
    expect(fps).toBeGreaterThan(60);
  });
  
  it('culls 95% of off-screen elements', () => {
    const scene = new SceneGraph();
    scene.buildFromLibrary(library);
    
    const totalElements = library.getTotalElementCount();
    const visibleElements = scene.queryViewport(smallViewport);
    
    const cullRate = 1 - (visibleElements.length / totalElements);
    expect(cullRate).toBeGreaterThan(0.95);
  });
});
```

---

## Integration with WASM Parsing

### Data Flow

1. **WASM Parsing** (Existing, assumed correct)
   ```typescript
   const library = await parseGDSII(fileData);
   // Returns GDSLibrary with all structures and elements
   ```

2. **Hierarchy Resolution** (Existing, enhanced)
   ```typescript
   const flattenedStructures = flattenLibrary(library, options);
   // Resolves SREF/AREF, applies transformations
   ```

3. **Scene Graph Building** (New)
   ```typescript
   const sceneGraph = new SceneGraph();
   sceneGraph.buildFromLibrary(library, flattenedStructures);
   // Builds spatial index, groups by layer
   ```

4. **Rendering** (New)
   ```typescript
   const renderer = RendererFactory.create('webgl', canvas);
   renderer.setLibrary(library);
   renderer.render(viewport);
   // Queries scene graph, generates commands, draws
   ```

### Memory Management

**WASM Side:**
- Parser allocates memory for library structure
- Returns pointer to TypeScript
- TypeScript responsible for calling `_gds_free_library(ptr)`

**TypeScript Side:**
- Import converts WASM data to GDSLibrary objects
- Scene graph builds additional structures (spatial index)
- Renderers create GPU buffers from geometry
- Cleanup: dispose renderer → clear scene graph → free WASM memory

---

## Configuration Options

### Render Quality Presets

```typescript
interface RenderQuality {
  antialiasing: boolean;
  lod: boolean;
  maxLODLevel: LODLevel;
  textRendering: 'fast' | 'quality';
  shadows: boolean;
  targetFPS: number;
}

const QUALITY_PRESETS = {
  low: {
    antialiasing: false,
    lod: true,
    maxLODLevel: LODLevel.LOW_DETAIL,
    textRendering: 'fast',
    shadows: false,
    targetFPS: 30
  },
  medium: {
    antialiasing: false,
    lod: true,
    maxLODLevel: LODLevel.HIGH_DETAIL,
    textRendering: 'fast',
    shadows: false,
    targetFPS: 60
  },
  high: {
    antialiasing: true,
    lod: true,
    maxLODLevel: LODLevel.FULL_DETAIL,
    textRendering: 'quality',
    shadows: true,
    targetFPS: 60
  }
};
```

### Layer Configuration

```typescript
interface LayerConfig {
  layers: {
    [key: number]: {
      name: string;
      color: string;
      pattern?: string;
      opacity: number;
      visible: boolean;
      zIndex: number;
    };
  };
  groups: {
    [key: string]: number[];  // Group name -> layer numbers
  };
}

// Example: Common foundry layers
const FOUNDRY_LAYERS = {
  layers: {
    1: { name: 'Active', color: '#00FF00', opacity: 0.7, visible: true, zIndex: 1 },
    2: { name: 'Poly', color: '#FF0000', opacity: 0.7, visible: true, zIndex: 2 },
    3: { name: 'Metal1', color: '#0000FF', opacity: 0.7, visible: true, zIndex: 3 },
    // ...
  },
  groups: {
    'Transistors': [1, 2],
    'Metal Stack': [3, 4, 5, 6],
    'Text/Labels': [63]
  }
};
```

---

## Performance Targets

### Render Performance

| Metric | Target | Measurement |
|--------|--------|-------------|
| Startup time | < 3s | Time from file load to first render |
| Frame rate (< 100K elements) | 60 FPS | Measured over 10 seconds |
| Frame rate (100K-1M elements) | 30-60 FPS | With LOD enabled |
| Frame time | < 16.67ms | 99th percentile |
| Input latency | < 50ms | Click to visual feedback |

### Memory Usage

| File Size | Element Count | Target Memory |
|-----------|---------------|---------------|
| < 1 MB | < 10K | < 100 MB |
| 1-10 MB | 10K-100K | 100-500 MB |
| 10-100 MB | 100K-1M | 500 MB - 2 GB |
| > 100 MB | > 1M | < 4 GB |

### Culling Efficiency

| Viewport Size | Elements Visible | Cull Rate |
|---------------|------------------|-----------|
| 1% of design | 1% of elements | 99% |
| 10% of design | 10-15% of elements | 85-90% |
| 100% of design | 100% of elements | 0% |

---

## Risk Mitigation

### Technical Risks

1. **WebGL Browser Support**
   - **Mitigation:** Robust Canvas2D fallback
   - **Detection:** Feature detection at runtime

2. **Large File Memory Usage**
   - **Mitigation:** Progressive loading, LOD system
   - **Monitoring:** Memory usage tracking and warnings

3. **Render Performance on Low-End Devices**
   - **Mitigation:** Auto quality adjustment
   - **Alternative:** Server-side rendering for ultra-large files

4. **WASM Memory Leaks**
   - **Mitigation:** Comprehensive testing, proper cleanup
   - **Monitoring:** Memory profiler integration

### Project Risks

1. **Scope Creep**
   - **Mitigation:** Phased implementation, prioritize core features
   - **Review:** Weekly progress check against plan

2. **Integration Issues**
   - **Mitigation:** Early integration with WASM layer
   - **Testing:** Continuous integration tests

3. **Performance Regressions**
   - **Mitigation:** Automated performance benchmarks
   - **Monitoring:** Performance metrics in CI/CD pipeline

---

## Success Criteria

### Minimum Viable Product (MVP)
- ✅ WebGL renderer with feature parity to Canvas2D
- ✅ Viewport culling improves performance by 80%+
- ✅ Renders 100K element files at 30+ FPS
- ✅ Basic element picking and selection
- ✅ Layer visibility and basic styling

### Full Production Release
- ✅ LOD system with 5 levels
- ✅ Smooth 60 FPS for typical files (< 100K elements)
- ✅ Interactive measurement tools
- ✅ Minimap and advanced navigation
- ✅ Memory usage within browser limits
- ✅ Comprehensive test coverage (> 80%)
- ✅ Complete documentation and examples

---

## Dependencies

### External Libraries

```json
{
  "dependencies": {
    "earcut": "^2.2.4",           // Polygon triangulation
    "gl-matrix": "^3.4.3"         // Matrix math utilities
  },
  "devDependencies": {
    "@types/earcut": "^2.1.1",
    "@types/gl-matrix": "^3.2.0",
    "vitest": "^0.34.0",          // Unit testing
    "playwright": "^1.40.0"       // Integration testing
  }
}
```

### Browser Requirements

- **Minimum:** Chrome 90+, Firefox 88+, Safari 14+, Edge 90+
- **Recommended:** Chrome 110+, Firefox 110+, Safari 16+
- **Features Required:**
  - WebGL2 (or WebGL with extensions)
  - Web Workers
  - ES2020 JavaScript

---

## Timeline Summary

| Phase | Duration | Key Deliverables |
|-------|----------|------------------|
| Phase 1: Foundation | 2 weeks | Scene graph, spatial index, renderer architecture |
| Phase 2: WebGL | 2 weeks | GPU-accelerated rendering, 5-10x performance |
| Phase 3: Advanced | 2 weeks | LOD system, interactive features |
| Phase 4: Polish | 2 weeks | Visual enhancements, optimization |
| **Total** | **8 weeks** | **Production-ready rendering module** |

---

## Conclusion

This plan provides a comprehensive roadmap for implementing a production-grade rendering module that cooperates seamlessly with the existing WASM-based GDSII parsing functionality. The phased approach ensures incremental progress with testable milestones, while the modular architecture allows for future enhancements such as WebGPU support or server-side rendering.

The rendering module will transform the GDSII Viewer from a basic proof-of-concept into a professional tool capable of handling industrial-scale designs with interactive features and excellent performance.

---

## References

- [GDSII Format Specification](http://bitsavers.org/pdf/calma/GDS_II_Stream_Format_Manual_6.0_Feb87.pdf)
- [WebGL2 Fundamentals](https://webgl2fundamentals.org/)
- [Earcut.js - Polygon Triangulation](https://github.com/mapbox/earcut)
- [gl-matrix - Matrix Math](https://glmatrix.net/)
- [QuadTree Spatial Indexing](https://en.wikipedia.org/wiki/Quadtree)

---

## Appendix A: Code Examples

### Example: Scene Graph Query

```typescript
// Query elements in viewport for rendering
const viewport = {
  center: { x: 100, y: 100 },
  width: 200,
  height: 150,
  zoom: 2.0
};

const visibleElements = sceneGraph.queryViewport(viewport);

// Sort by layer for correct rendering order
visibleElements.sort((a, b) => a.layer - b.layer);

// Generate render commands
const commands = visibleElements.map(element => ({
  type: element.type,
  layer: element.layer,
  geometry: processGeometry(element),
  transform: element.transform,
  style: layerStyles.get(element.layer)
}));

// Batch and execute
commandQueue.enqueueBatch(commands);
commandQueue.execute(renderer);
```

### Example: LOD Selection

```typescript
function selectLODLevel(element: GDSElement, viewport: Viewport): LODLevel {
  const bbox = calculateElementBBox(element);
  const screenSize = worldToScreen(bbox, viewport);
  const pixelSize = Math.max(screenSize.width, screenSize.height);
  
  if (pixelSize < 2) return LODLevel.BOUNDING_BOX;
  if (pixelSize < 10) return LODLevel.LOW_DETAIL;
  if (pixelSize < 50) return LODLevel.MEDIUM_DETAIL;
  if (pixelSize < 200) return LODLevel.HIGH_DETAIL;
  return LODLevel.FULL_DETAIL;
}
```

### Example: WebGL Drawing

```typescript
class WebGLRenderer implements IRenderer {
  private drawBoundaryElements(commands: RenderCommand[]): void {
    const shader = this.shaderPrograms.get('boundary');
    shader.use();
    
    // Set uniforms
    shader.setUniform('u_matrix', this.viewProjectionMatrix);
    
    // Batch by layer for state reduction
    const batches = this.batchByLayer(commands);
    
    for (const [layer, layerCommands] of batches) {
      const style = this.layerStyles.get(layer);
      shader.setUniform('u_color', style.color);
      
      // Draw all elements in this layer with one call
      const buffer = this.geometryBuffers.get(layer);
      buffer.bind();
      gl.drawArraysInstanced(
        gl.TRIANGLES, 
        0, 
        buffer.vertexCount, 
        layerCommands.length
      );
    }
  }
}
```

---

**End of Implementation Plan**
