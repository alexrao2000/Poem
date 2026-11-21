shader_type spatial;
render_mode diffuse_toon, cull_disabled;
uniform sampler2D open_face : source_color, filter_linear;
uniform sampler2D closed_face : source_color, filter_linear;
uniform sampler2D focused_face : source_color, filter_linear;
uniform sampler2D serious_face : source_color, filter_linear;
uniform bool personal_iris = false;
uniform vec4 iris_tint : source_color = vec4(1.0);
uniform bool serious = false;
uniform bool eyes_closed = false;
uniform bool focused = false;

// Compatibility exposes sRGB to user fragment code; palette math uses linear light.
vec3 iris_linear(vec3 color) {
 return mix(color / 12.92, pow((color + vec3(0.055)) / 1.055, vec3(2.4)),
            step(vec3(0.04045), color));
}
vec3 iris_srgb(vec3 color) {
 return mix(color * 12.92, 1.055 * pow(color, vec3(1.0 / 2.4)) - vec3(0.055),
            step(vec3(0.0031308), color));
}

// The supported cool iris cells are separated from their warm eyelid ink.
// Keep pupils, white glints, brows, nose and mouth on the original painting.
float iris_coverage(vec2 local_uv, vec3 ink) {
 vec2 radii = vec2(0.068, 0.077);
 float radius = min(length((local_uv - vec2(0.273, 0.433)) / radii),
                    length((local_uv - vec2(0.733, 0.433)) / radii));
 float value = max(ink.r, max(ink.g, ink.b));
 float cool = (max(ink.g, ink.b) - ink.r) / max(value, 0.0001);
 return (1.0 - smoothstep(0.85, 1.0, radius)) * smoothstep(0.025, 0.15, cool)
        * smoothstep(0.008, 0.04, value) * (1.0 - smoothstep(0.65, 0.85, value));
}

void fragment() {
 // Independent expression regions preserve the original nose and registration.
 float cell_v = fract(UV.y * 2.0);
 vec4 ink = texture(open_face, UV);
 if (focused && cell_v < 0.55) {
  ink = texture(focused_face, UV);
 }
 if (eyes_closed && cell_v >= 0.34 && cell_v <= 0.55) {
  ink = texture(closed_face, UV);
 }
 if (serious && cell_v >= 0.72 && cell_v <= 0.90) {
  ink = texture(serious_face, UV);
 }
 ALBEDO = ink.rgb;
 if (personal_iris && !eyes_closed) {
  vec3 sampled = OUTPUT_IS_SRGB ? iris_linear(ink.rgb) : ink.rgb;
  float coverage = iris_coverage(vec2(fract(UV.x * 4.0), cell_v), sampled);
  if (coverage > 0.0) {
   vec3 tint = OUTPUT_IS_SRGB ? iris_linear(iris_tint.rgb) : iris_tint.rgb;
   vec3 luma_weights = vec3(0.2126, 0.7152, 0.0722);
   vec3 tinted = clamp(tint * dot(sampled, luma_weights)
                      / max(dot(tint, luma_weights), 0.0001), vec3(0.0), vec3(1.0));
   vec3 mixed_iris = mix(sampled, tinted, coverage);
   ALBEDO = OUTPUT_IS_SRGB ? iris_srgb(mixed_iris) : mixed_iris;
  }
 }
 ALPHA = ink.a;
 ALPHA_SCISSOR_THRESHOLD = 0.22;
 ROUGHNESS = 1.0;
}
