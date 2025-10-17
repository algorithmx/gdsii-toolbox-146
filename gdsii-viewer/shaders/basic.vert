#version 300 es
precision highp float;

// Vertex attributes
in vec2 a_position;

// Uniforms
uniform mat3 u_viewMatrix;      // View transformation (camera)
uniform mat3 u_worldMatrix;     // World transformation (element)

void main() {
  // Apply world transformation, then view transformation
  vec3 worldPos = u_worldMatrix * vec3(a_position, 1.0);
  vec3 viewPos = u_viewMatrix * worldPos;
  
  // Output position (Z is always 0 for 2D)
  gl_Position = vec4(viewPos.xy, 0.0, 1.0);
}
