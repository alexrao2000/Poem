shader_type spatial;
render_mode diffuse_toon, specular_toon;
uniform sampler2D albedo_map : source_color, filter_linear_mipmap;
uniform sampler2D normal_map : hint_normal, filter_linear_mipmap;
uniform bool has_normal = false;
uniform vec4 tint : source_color = vec4(1.0);
uniform float reference_luma = 0.2;
// 1 dyes neutral fabric while retaining warm leather; 2 recolors full fabric;
// 3 applies a skin palette while retaining the supplied texture's shading.
uniform int dye_mode = 1;
void fragment() {
 vec3 source = texture(albedo_map, UV).rgb;
 float luma = dot(source, vec3(0.2126, 0.7152, 0.0722));
 float detail = clamp(luma / max(reference_luma, 0.005), 0.35, 1.65);
 float warmth = max(source.r - source.b, 0.0) / max(source.r, 0.01);
 float mask = dye_mode == 1 ? 1.0 - smoothstep(0.55, 0.80, warmth) : 1.0;
 ALBEDO = mix(source, clamp(tint.rgb * detail, vec3(0.0), vec3(1.0)), mask);
 ROUGHNESS = 0.86;
 SPECULAR = 0.2;
 if (has_normal) {
  NORMAL_MAP = texture(normal_map, UV).rgb;
  NORMAL_MAP_DEPTH = 0.4;
 }
}
