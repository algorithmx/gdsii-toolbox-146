/**
 * WebGL Geometry Buffer Manager
 * 
 * Manages vertex and index buffers for efficient GPU rendering.
 */

/**
 * Buffer usage hint for WebGL
 */
export enum BufferUsage {
  STATIC = 'STATIC',   // Data won't change
  DYNAMIC = 'DYNAMIC', // Data changes occasionally
  STREAM = 'STREAM'    // Data changes every frame
}

/**
 * Geometry buffer statistics
 */
export interface BufferStats {
  vertexCount: number;
  indexCount: number;
  triangleCount: number;
  vertexBytes: number;
  indexBytes: number;
  totalBytes: number;
}

/**
 * Manages a pair of WebGL buffers (vertices + indices)
 */
export class GeometryBuffer {
  private vertexBuffer: WebGLBuffer | null = null;
  private indexBuffer: WebGLBuffer | null = null;
  private vertexCount: number = 0;
  private indexCount: number = 0;
  private usage: number;

  constructor(
    private readonly gl: WebGL2RenderingContext,
    usage: BufferUsage = BufferUsage.STATIC
  ) {
    // Map usage enum to WebGL constants
    switch (usage) {
      case BufferUsage.STATIC:
        this.usage = gl.STATIC_DRAW;
        break;
      case BufferUsage.DYNAMIC:
        this.usage = gl.DYNAMIC_DRAW;
        break;
      case BufferUsage.STREAM:
        this.usage = gl.STREAM_DRAW;
        break;
    }

    this.createBuffers();
  }

  /**
   * Creates the WebGL buffers
   */
  private createBuffers(): void {
    this.vertexBuffer = this.gl.createBuffer();
    this.indexBuffer = this.gl.createBuffer();

    if (!this.vertexBuffer || !this.indexBuffer) {
      throw new Error('Failed to create WebGL buffers');
    }
  }

  /**
   * Uploads vertex data to the GPU
   * 
   * @param vertices Float32Array of vertex positions [x,y, x,y, ...]
   */
  uploadVertices(vertices: Float32Array): void {
    if (!this.vertexBuffer) {
      throw new Error('Vertex buffer not initialized');
    }

    this.gl.bindBuffer(this.gl.ARRAY_BUFFER, this.vertexBuffer);
    this.gl.bufferData(this.gl.ARRAY_BUFFER, vertices, this.usage);
    this.vertexCount = vertices.length / 2; // 2 components per vertex (x, y)
  }

  /**
   * Uploads index data to the GPU
   * 
   * @param indices Uint32Array or Uint16Array of triangle indices
   */
  uploadIndices(indices: Uint32Array | Uint16Array): void {
    if (!this.indexBuffer) {
      throw new Error('Index buffer not initialized');
    }

    this.gl.bindBuffer(this.gl.ELEMENT_ARRAY_BUFFER, this.indexBuffer);
    this.gl.bufferData(this.gl.ELEMENT_ARRAY_BUFFER, indices, this.usage);
    this.indexCount = indices.length;
  }

  /**
   * Updates a portion of the vertex buffer
   * 
   * @param vertices New vertex data
   * @param offset Offset in bytes
   */
  updateVertices(vertices: Float32Array, offset: number = 0): void {
    if (!this.vertexBuffer) {
      throw new Error('Vertex buffer not initialized');
    }

    this.gl.bindBuffer(this.gl.ARRAY_BUFFER, this.vertexBuffer);
    this.gl.bufferSubData(this.gl.ARRAY_BUFFER, offset, vertices);
  }

  /**
   * Binds the vertex buffer and sets up vertex attributes
   * 
   * @param attributeLocation Location of the position attribute
   */
  bindVertexBuffer(attributeLocation: number): void {
    if (!this.vertexBuffer) {
      throw new Error('Vertex buffer not initialized');
    }

    this.gl.bindBuffer(this.gl.ARRAY_BUFFER, this.vertexBuffer);
    
    // Enable attribute and set pointer
    this.gl.enableVertexAttribArray(attributeLocation);
    this.gl.vertexAttribPointer(
      attributeLocation,
      2,                    // 2 components per vertex (x, y)
      this.gl.FLOAT,        // Data type
      false,                // Don't normalize
      0,                    // Stride (tightly packed)
      0                     // Offset
    );
  }

  /**
   * Binds the index buffer
   */
  bindIndexBuffer(): void {
    if (!this.indexBuffer) {
      throw new Error('Index buffer not initialized');
    }

    this.gl.bindBuffer(this.gl.ELEMENT_ARRAY_BUFFER, this.indexBuffer);
  }

  /**
   * Draws the geometry using indexed triangles
   */
  draw(): void {
    if (this.indexCount === 0) {
      return;
    }

    this.gl.drawElements(
      this.gl.TRIANGLES,
      this.indexCount,
      this.gl.UNSIGNED_INT,
      0
    );
  }

  /**
   * Draws a subset of the geometry
   * 
   * @param offset Index offset
   * @param count Number of indices to draw
   */
  drawRange(offset: number, count: number): void {
    this.gl.drawElements(
      this.gl.TRIANGLES,
      count,
      this.gl.UNSIGNED_INT,
      offset * 4 // 4 bytes per UNSIGNED_INT
    );
  }

  /**
   * Gets buffer statistics
   */
  getStats(): BufferStats {
    const vertexBytes = this.vertexCount * 2 * 4; // 2 floats per vertex, 4 bytes per float
    const indexBytes = this.indexCount * 4; // 4 bytes per index (UNSIGNED_INT)

    return {
      vertexCount: this.vertexCount,
      indexCount: this.indexCount,
      triangleCount: this.indexCount / 3,
      vertexBytes,
      indexBytes,
      totalBytes: vertexBytes + indexBytes
    };
  }

  /**
   * Clears buffer data (doesn't delete buffers)
   */
  clear(): void {
    if (this.vertexBuffer) {
      this.gl.bindBuffer(this.gl.ARRAY_BUFFER, this.vertexBuffer);
      this.gl.bufferData(this.gl.ARRAY_BUFFER, 0, this.usage);
    }
    if (this.indexBuffer) {
      this.gl.bindBuffer(this.gl.ELEMENT_ARRAY_BUFFER, this.indexBuffer);
      this.gl.bufferData(this.gl.ELEMENT_ARRAY_BUFFER, 0, this.usage);
    }
    this.vertexCount = 0;
    this.indexCount = 0;
  }

  /**
   * Disposes of the WebGL buffers
   */
  dispose(): void {
    if (this.vertexBuffer) {
      this.gl.deleteBuffer(this.vertexBuffer);
      this.vertexBuffer = null;
    }
    if (this.indexBuffer) {
      this.gl.deleteBuffer(this.indexBuffer);
      this.indexBuffer = null;
    }
    this.vertexCount = 0;
    this.indexCount = 0;
  }

  /**
   * Checks if the buffer is ready for rendering
   */
  isReady(): boolean {
    return this.vertexBuffer !== null && 
           this.indexBuffer !== null && 
           this.vertexCount > 0 && 
           this.indexCount > 0;
  }
}

/**
 * Buffer pool for reusing geometry buffers
 */
export class BufferPool {
  private buffers: GeometryBuffer[] = [];
  private inUse: Set<GeometryBuffer> = new Set();

  constructor(
    private readonly gl: WebGL2RenderingContext,
    private readonly usage: BufferUsage = BufferUsage.DYNAMIC
  ) {}

  /**
   * Acquires a buffer from the pool (or creates a new one)
   */
  acquire(): GeometryBuffer {
    // Try to find an unused buffer
    for (const buffer of this.buffers) {
      if (!this.inUse.has(buffer)) {
        this.inUse.add(buffer);
        return buffer;
      }
    }

    // Create a new buffer if none available
    const buffer = new GeometryBuffer(this.gl, this.usage);
    this.buffers.push(buffer);
    this.inUse.add(buffer);
    return buffer;
  }

  /**
   * Releases a buffer back to the pool
   */
  release(buffer: GeometryBuffer): void {
    buffer.clear();
    this.inUse.delete(buffer);
  }

  /**
   * Releases all buffers
   */
  releaseAll(): void {
    this.inUse.clear();
  }

  /**
   * Gets pool statistics
   */
  getStats(): {
    total: number;
    inUse: number;
    available: number;
    totalMemory: number;
  } {
    let totalMemory = 0;
    for (const buffer of this.buffers) {
      totalMemory += buffer.getStats().totalBytes;
    }

    return {
      total: this.buffers.length,
      inUse: this.inUse.size,
      available: this.buffers.length - this.inUse.size,
      totalMemory
    };
  }

  /**
   * Disposes of all buffers in the pool
   */
  dispose(): void {
    for (const buffer of this.buffers) {
      buffer.dispose();
    }
    this.buffers = [];
    this.inUse.clear();
  }
}
