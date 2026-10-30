shader_type spatial;
render_mode unshaded, cull_front, shadows_disabled;
uniform float width = 0.005;
uniform vec4 ink : source_color = vec4(0.20, 0.192, 0.227, 1.0);
#include "res://assets/shaders/cape-motion.gdshaderinc"
void vertex() {
 vec3 direction = normalize(COLOR.rgb * 2.0 - 1.0);
 if (cloth_amount > 0.0) {
  direction = cape_normal(VERTEX, direction);
  VERTEX = cape_position(VERTEX);
 }
 VERTEX += direction * width;
}
void fragment() {
 ALBEDO = ink.rgb;
}
