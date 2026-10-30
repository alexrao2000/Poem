shader_type spatial;
render_mode diffuse_toon, specular_toon, cull_disabled;
uniform sampler2D materials_atlas : source_color, filter_linear_mipmap;
uniform vec4 tint : source_color = vec4(1.0);
uniform vec2 quadrant;
uniform float texture_repeat = 1.0;
uniform float metal = 0.0;
uniform sampler2D cape_mark : filter_linear_mipmap;
uniform vec4 cape_trim : source_color = vec4(0.78, 0.68, 0.45, 1.0);
#include "res://assets/shaders/cape-motion.gdshaderinc"
void vertex() {
 if (cloth_amount > 0.0) {
  NORMAL = cape_normal(VERTEX, NORMAL);
  VERTEX = cape_position(VERTEX);
 }
}
void fragment() {
 vec2 detail_uv = fract(UV * texture_repeat) * 0.496 + 0.002 + quadrant;
 vec3 paint = texture(materials_atlas, detail_uv).rgb;
 vec3 dye = tint.rgb;
 if (cloth_amount > 0.0 && FRONT_FACING) {
  float thread = texture(cape_mark, UV).a;
  dye = mix(dye, cape_trim.rgb, thread * 0.92);
 }
 ALBEDO = paint * dye;
 ROUGHNESS = mix(0.9, 0.46, metal);
 METALLIC = metal * 0.45;
 SPECULAR = 0.25;
}
