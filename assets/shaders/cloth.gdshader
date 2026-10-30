shader_type spatial;
// Compatibility already orients cull_disabled back-face normals before fragment().
render_mode cull_disabled, diffuse_toon, specular_disabled;
uniform sampler2D linen_atlas : source_color, filter_linear_mipmap;
uniform vec2 dimensions = vec2(0.45, 0.32);
uniform vec4 tint : source_color = vec4(0.65, 0.3, 0.28, 1.0);
uniform vec4 trim : source_color = vec4(0.87, 0.77, 0.54, 1.0);
uniform bool emblem = true;
uniform float phase = 0.0;

void vertex() {
 float u = UV.x;
 float v = UV.y;
 float a = u * 7.0 - phase * 2.3 + v * 1.7;
 float b = u * 13.0 - phase * 3.4 - v * 2.0;
 float wave = 0.045 * sin(a) + 0.015 * sin(b);
 VERTEX.z += dimensions.x * wave * u * u;
 VERTEX.y -= dimensions.y * 0.045 * u;
 float dzdu = dimensions.x * ((0.315 * cos(a) + 0.195 * cos(b)) * u * u + 2.0 * u * wave);
 float dzdv = dimensions.x * (0.0765 * cos(a) - 0.03 * cos(b)) * u * u;
 float edge = emblem ? 1.0 - 0.13 * (1.0 - abs(v * 2.0 - 1.0)) : 1.0;
 float slope = emblem ? 0.26 * sign(v - 0.5) : 0.0;
 vec3 du = vec3(dimensions.x * edge, -dimensions.y * 0.045, dzdu);
 vec3 dv = vec3(dimensions.x * u * slope, -dimensions.y, dzdv);
 NORMAL = normalize(cross(dv, du));
}

void fragment() {
 vec3 linen = texture(linen_atlas, UV * 0.496 + vec2(0.002)).rgb;
 vec3 color = tint.rgb;
 if (emblem) {
  float edge = min(min(UV.x, 1.0 - UV.x), min(UV.y, 1.0 - UV.y));
  float border = 1.0 - smoothstep(0.025, 0.04, edge);
  float diamond = abs(UV.x - 0.55) / 0.17 + abs(UV.y - 0.5) / 0.28;
  float crest = smoothstep(0.72, 0.80, diamond) * (1.0 - smoothstep(0.96, 1.04, diamond));
  color = mix(color, trim.rgb, max(border, crest));
 } else {
  float seam = 1.0 - smoothstep(0.008, 0.025, abs(fract(UV.x * 4.0 + 0.5) - 0.5));
  color *= 1.0 - seam * 0.12;
 }
 ALBEDO = linen * color;
 ROUGHNESS = 1.0;
}
