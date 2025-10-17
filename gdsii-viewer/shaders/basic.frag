#version 300 es
precision highp float;

// Uniforms
uniform vec4 u_color;    // RGBA color for the layer
uniform float u_opacity; // Opacity for blending

// Output
out vec4 fragColor;

void main() {
  // Apply opacity to the color
  fragColor = vec4(u_color.rgb, u_color.a * u_opacity);
}
