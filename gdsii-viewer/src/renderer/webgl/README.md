# WebGL Renderer Backend

High-performance GPU-accelerated rendering system for GDSII visualization.

## Architecture

### Components

```
webgl/
├── webgl-renderer.ts      # Main renderer implementation
├── shader-program.ts      # WebGL shader management
├── geometry-buffer.ts     # GPU buffer management
├── buffer-pool.ts         # Buffer pooling for efficiency
├── triangulator.ts        # Polygon triangulation (Earcut)
├── layer-batch.ts         # Layer batching system
└── shaders/
    ├── basic.vert         # Vertex shader
    └── basic.frag         # Fragment shader
```

### Rendering Pipeline

1. **Scene Query** - Query visible elements from spatial index
2. **Grouping** - Group elements by layer
3. **Batching** - Combine layer elements into single geometry batch
4. **Triangulation** - Convert polygons to triangles (cached)
5. **Upload** - Upload geometry to GPU buffers
6. **Render** - Issue draw calls (one per layer)

## Performance Features

### Batching System

The batching system combines multiple elements within a layer into a single draw call:

```typescript
// Without batching: N draw calls (one per element)
for (element of elements) {
  triangulate(element);
  uploadToGPU();
  draw(); // Draw call #1, #2, #3...
}

// With batching: 1 draw call per layer
batch = getBatch(layer);
if (batch.isDirty()) {
  triangulateAll(elements);
  uploadToGPU(); // Once per layer
}
batch.draw(); // Single draw call
```

**Benefits:**
- Reduces draw calls from O(N) to O(L) where L = layer count
- Caches triangulated geometry (no re-triangulation on pan/zoom)
- Minimizes CPU-GPU data transfer

### Buffer Pooling

Reuses WebGL buffers to minimize allocation overhead:

```typescript
const buffer = pool.acquire(); // Get from pool
buffer.uploadData(vertices);
buffer.draw();
pool.release(buffer); // Return to pool
```

**Benefits:**
- Eliminates repeated buffer creation/deletion
- Reduces garbage collection pressure
- Improves frame consistency

### Spatial Culling

Integration with scene graph spatial index for efficient culling:

```typescript
const visibleElements = sceneGraph.queryViewport(viewport);
// Only render elements in viewport
render(visibleElements);
```

**Benefits:**
- O(log N) viewport queries via QuadTree
- Automatic frustum culling
- Scales to large designs

## Performance Metrics

### Benchmarks (74-element MOSFET design)

| Backend | Draw Calls | Frame Time | Triangulation |
|---------|-----------|------------|---------------|
| Canvas2D | N/A | ~5-8ms | Per frame |
| WebGL (unbatched) | 74 | ~3-5ms | Per frame |
| WebGL (batched) | 6 | ~1-2ms | Cached |

**Improvement:** 92% reduction in draw calls, 60% faster rendering

### Scalability

Expected performance for larger designs:

| Element Count | Layers | Draw Calls | Culling Rate |
|--------------|--------|------------|--------------|
| 100 | 5 | 5 | 0-20% |
| 1,000 | 10 | 10 | 20-50% |
| 10,000 | 20 | 20 | 50-80% |
| 100,000+ | 30 | 30 | 80-95% |

*Note: Culling rate depends on zoom level*

## API Reference

### WebGLRenderer

Main renderer class implementing `IRenderer` interface.

#### Methods

```typescript
// Initialization
async initialize(canvas: HTMLCanvasElement): Promise<void>

// Rendering
render(viewport: Viewport): void
renderImmediate(viewport: Viewport): void

// Batching Control
setBatchingEnabled(enabled: boolean): void
getBatchingStats(): BatchStats | null
invalidateBatches(): void

// Configuration
setDebugMode(enabled: boolean): void
getCapabilities(): RendererCapabilities
```

#### Example Usage

```typescript
// Create and initialize renderer
const renderer = new WebGLRenderer();
await renderer.initialize(canvas);

// Load scene
renderer.setLibrary(gdsLibrary);
renderer.updateSceneGraph();

// Render
renderer.render(viewport);

// Get performance stats
const stats = renderer.getBatchingStats();
console.log(`Batches: ${stats.batchCount}, Triangles: ${stats.totalTriangles}`);
```

### LayerBatchManager

Manages geometry batching for all layers.

```typescript
const manager = new LayerBatchManager(gl);

// Update batch for a layer
manager.updateBatch(layerKey, elements, style);

// Get statistics
const stats = manager.getStats();
console.log(`Batches: ${stats.batchCount}, Vertices: ${stats.totalVertices}`);

// Cleanup
manager.dispose();
```

### GeometryBuffer

Manages WebGL vertex and index buffers.

```typescript
const buffer = new GeometryBuffer(gl, BufferUsage.DYNAMIC);

// Upload geometry
buffer.uploadVertices(vertices);
buffer.uploadIndices(indices);

// Render
buffer.bindVertexBuffer(attributeLocation);
buffer.bindIndexBuffer();
buffer.draw();

// Cleanup
buffer.dispose();
```

## Shader System

### Vertex Shader (basic.vert)

Transforms vertices from world space to clip space:

```glsl
attribute vec2 a_position;

uniform mat3 u_viewMatrix;
uniform mat3 u_worldMatrix;

void main() {
  vec3 worldPos = u_worldMatrix * vec3(a_position, 1.0);
  vec3 clipPos = u_viewMatrix * worldPos;
  gl_Position = vec4(clipPos.xy, 0.0, 1.0);
}
```

### Fragment Shader (basic.frag)

Applies layer color and opacity:

```glsl
precision mediump float;

uniform vec4 u_color;
uniform float u_opacity;

void main() {
  gl_FragColor = vec4(u_color.rgb, u_color.a * u_opacity);
}
```

## Memory Management

### Buffer Lifecycle

1. **Creation** - Buffers created on-demand or from pool
2. **Upload** - Geometry uploaded to GPU
3. **Rendering** - Buffers bound and drawn multiple times
4. **Caching** - Batched geometry remains in GPU memory
5. **Disposal** - Buffers released when scene changes or disposed

### Memory Optimization

- **Buffer Pooling** - Reuse buffers to minimize allocation
- **Batch Caching** - Keep triangulated geometry in GPU memory
- **Lazy Updates** - Only re-triangulate when geometry changes
- **Automatic Cleanup** - Dispose batches when renderer destroyed

## Debugging

### Enable Debug Mode

```typescript
renderer.setDebugMode(true);
```

Outputs:
- Culling statistics
- Draw call counts
- Render times
- Batch information

### Toggle Batching

Compare performance with/without batching:

```typescript
// Disable batching (one draw call per element)
renderer.setBatchingEnabled(false);

// Enable batching (one draw call per layer)
renderer.setBatchingEnabled(true);
```

### Browser DevTools

Use Chrome DevTools > Performance > Rendering to profile:
- Frame rate
- GPU utilization
- Draw call counts

## Browser Compatibility

### WebGL2 Support

**Required:** WebGL2 support
- Chrome 56+
- Firefox 51+
- Safari 15+
- Edge 79+

**Fallback:** Automatic fallback to Canvas2D if WebGL2 unavailable

### Feature Detection

```typescript
const backends = RendererFactory.getAvailableBackends();
console.log('WebGL2 support:', backends.webgl2);
console.log('Recommended:', backends.recommended);
```

## Future Enhancements

### Planned Features

1. **Instancing** - For repeated geometry (arrays)
2. **Line Rendering** - Proper path width with joins/caps
3. **Anti-aliasing** - MSAA or FXAA for smooth edges
4. **Text Rendering** - GPU-accelerated text labels
5. **Selection** - GPU-based picking
6. **Effects** - Glow, shadows, highlights

### Performance Improvements

1. **Occlusion Culling** - Skip hidden elements
2. **LOD System** - Simplify distant geometry
3. **Streaming** - Load/unload geometry on demand
4. **Instanced Batching** - Further reduce draw calls
5. **Compute Shaders** - GPU-accelerated triangulation

## License

Part of the GDSII Toolbox project.

## References

- [WebGL2 Specification](https://www.khronos.org/registry/webgl/specs/latest/2.0/)
- [Earcut Triangulation](https://github.com/mapbox/earcut)
- [GDSII Format](http://www.artwork.com/gdsii/gdsii/)
