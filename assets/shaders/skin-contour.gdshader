shader_type spatial;
render_mode diffuse_toon, specular_disabled;

uniform vec4 tint : source_color = vec4(1.0);
uniform vec4 stubble : source_color = vec4(0.0);
varying float face_depth;

void vertex() {
 face_depth = -VERTEX.z;
}

float soft_patch(vec2 point, vec2 center, vec2 radii) {
 float radius = length((point - center) / radii);
 return 1.0 - smoothstep(0.10, 1.0, radius);
}

void fragment() {
 vec2 face = vec2(abs(UV.x - 0.5), UV.y);
 float forward = smoothstep(0.055, 0.115, face_depth);
 float brow = soft_patch(face, vec2(0.22, 0.43), vec2(0.22, 0.085));
 float cheek = soft_patch(face, vec2(0.25, 0.60), vec2(0.19, 0.14));
 float bridge = soft_patch(face, vec2(0.00, 0.52), vec2(0.135, 0.21));
 float jaw = soft_patch(face, vec2(0.12, 0.83), vec2(0.32, 0.20));
 vec3 tone = vec3(1.0 + forward * (0.105 * bridge - 0.12 * brow - 0.16 * jaw));
 tone *= mix(vec3(1.0), vec3(1.035, 0.93, 0.89), cheek * forward);
 vec3 color = clamp(tint.rgb * tone, vec3(0.0), vec3(1.0));
 if (stubble.a > 0.0) {
  float edge = 0.675 - 0.205 * smoothstep(0.14, 0.46, face.x);
  float beard = smoothstep(edge - 0.026, edge + 0.033, face.y) * smoothstep(0.019, 0.085, face_depth);
  float opening = soft_patch(face, vec2(0.01, 0.785), vec2(0.16, 0.075));
  vec2 cell = floor(UV * vec2(96.0, 104.0));
  float fleck = fract(sin(dot(cell, vec2(12.9898, 78.233))) * 43758.5453);
  float grain = 1.0 - smoothstep(0.008, 0.022, max(fwidth(UV.x), fwidth(UV.y)));
  vec3 hair = stubble.rgb * (1.0 + (fleck - 0.5) * grain * 0.22);
  color = mix(color, hair, beard * (1.0 - opening * 0.75) * stubble.a * 0.82);
 }
 ALBEDO = color;
 ROUGHNESS = 0.93;
}
