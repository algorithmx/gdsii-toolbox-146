/**
 * WebGL Shader Program Manager
 * 
 * Handles shader compilation, linking, and uniform management.
 */

/**
 * Shader program wrapper with uniform/attribute management
 */
export class ShaderProgram {
  private program: WebGLProgram | null = null;
  private uniformLocations: Map<string, WebGLUniformLocation> = new Map();
  private attributeLocations: Map<string, number> = new Map();

  constructor(
    private readonly gl: WebGL2RenderingContext,
    private readonly vertexSource: string,
    private readonly fragmentSource: string
  ) {}

  /**
   * Compiles and links the shader program
   */
  compile(): boolean {
    const vertexShader = this.compileShader(this.gl.VERTEX_SHADER, this.vertexSource);
    if (!vertexShader) {
      return false;
    }

    const fragmentShader = this.compileShader(this.gl.FRAGMENT_SHADER, this.fragmentSource);
    if (!fragmentShader) {
      this.gl.deleteShader(vertexShader);
      return false;
    }

    // Link program
    const program = this.gl.createProgram();
    if (!program) {
      console.error('Failed to create shader program');
      this.gl.deleteShader(vertexShader);
      this.gl.deleteShader(fragmentShader);
      return false;
    }

    this.gl.attachShader(program, vertexShader);
    this.gl.attachShader(program, fragmentShader);
    this.gl.linkProgram(program);

    // Check link status
    if (!this.gl.getProgramParameter(program, this.gl.LINK_STATUS)) {
      const info = this.gl.getProgramInfoLog(program);
      console.error('Shader program linking failed:', info);
      this.gl.deleteProgram(program);
      this.gl.deleteShader(vertexShader);
      this.gl.deleteShader(fragmentShader);
      return false;
    }

    // Validate program
    this.gl.validateProgram(program);
    if (!this.gl.getProgramParameter(program, this.gl.VALIDATE_STATUS)) {
      const info = this.gl.getProgramInfoLog(program);
      console.warn('Shader program validation failed:', info);
    }

    // Clean up shaders (they're now part of the program)
    this.gl.deleteShader(vertexShader);
    this.gl.deleteShader(fragmentShader);

    this.program = program;
    console.log('✓ Shader program compiled and linked successfully');
    return true;
  }

  /**
   * Compiles a shader
   */
  private compileShader(type: number, source: string): WebGLShader | null {
    const shader = this.gl.createShader(type);
    if (!shader) {
      console.error('Failed to create shader');
      return null;
    }

    this.gl.shaderSource(shader, source);
    this.gl.compileShader(shader);

    if (!this.gl.getShaderParameter(shader, this.gl.COMPILE_STATUS)) {
      const info = this.gl.getShaderInfoLog(shader);
      const shaderType = type === this.gl.VERTEX_SHADER ? 'vertex' : 'fragment';
      console.error(`${shaderType} shader compilation failed:`, info);
      console.error('Shader source:', source);
      this.gl.deleteShader(shader);
      return null;
    }

    return shader;
  }

  /**
   * Uses this shader program for rendering
   */
  use(): void {
    if (!this.program) {
      throw new Error('Shader program not compiled');
    }
    this.gl.useProgram(this.program);
  }

  /**
   * Gets or caches a uniform location
   */
  getUniformLocation(name: string): WebGLUniformLocation | null {
    if (!this.program) {
      throw new Error('Shader program not compiled');
    }

    if (this.uniformLocations.has(name)) {
      return this.uniformLocations.get(name)!;
    }

    const location = this.gl.getUniformLocation(this.program, name);
    if (location) {
      this.uniformLocations.set(name, location);
    }
    return location;
  }

  /**
   * Gets or caches an attribute location
   */
  getAttributeLocation(name: string): number {
    if (!this.program) {
      throw new Error('Shader program not compiled');
    }

    if (this.attributeLocations.has(name)) {
      return this.attributeLocations.get(name)!;
    }

    const location = this.gl.getAttribLocation(this.program, name);
    if (location >= 0) {
      this.attributeLocations.set(name, location);
    }
    return location;
  }

  /**
   * Sets a uniform matrix3fv
   */
  setUniformMatrix3fv(name: string, value: Float32Array | number[]): void {
    const location = this.getUniformLocation(name);
    if (location) {
      const array = value instanceof Float32Array ? value : new Float32Array(value);
      this.gl.uniformMatrix3fv(location, false, array);
    }
  }

  /**
   * Sets a uniform vec4
   */
  setUniformVec4(name: string, x: number, y: number, z: number, w: number): void {
    const location = this.getUniformLocation(name);
    if (location) {
      this.gl.uniform4f(location, x, y, z, w);
    }
  }

  /**
   * Sets a uniform float
   */
  setUniformFloat(name: string, value: number): void {
    const location = this.getUniformLocation(name);
    if (location) {
      this.gl.uniform1f(location, value);
    }
  }

  /**
   * Sets a uniform int
   */
  setUniformInt(name: string, value: number): void {
    const location = this.getUniformLocation(name);
    if (location) {
      this.gl.uniform1i(location, value);
    }
  }

  /**
   * Disposes of the shader program
   */
  dispose(): void {
    if (this.program) {
      this.gl.deleteProgram(this.program);
      this.program = null;
    }
    this.uniformLocations.clear();
    this.attributeLocations.clear();
  }

  /**
   * Gets the WebGL program
   */
  getProgram(): WebGLProgram | null {
    return this.program;
  }
}
