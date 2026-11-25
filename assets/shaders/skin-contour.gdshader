shader_type spatial;
render_mode diffuse_toon, specular_disabled;

uniform vec4 tint : source_color = vec4(1.0);
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
 ALBEDO = clamp(tint.rgb * tone, vec3(0.0), vec3(1.0));
 ROUGHNESS = 0.93;
}
