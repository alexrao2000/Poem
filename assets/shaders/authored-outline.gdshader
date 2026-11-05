shader_type spatial;
render_mode unshaded, cull_front, shadows_disabled;
uniform float width = 0.0025;
uniform vec4 ink : source_color = vec4(0.20, 0.192, 0.227, 1.0);
uniform bool cloth_floor_enabled = false;
uniform float cloth_floor_y = 0.0;
#include "res://assets/shaders/cape-motion.gdshaderinc"
void vertex() {
 // Native normals follow skinning; vertex colors do not carry bone rotation.
 vec3 direction = NORMAL;
 if (cloth_amount > 0.0) {
  direction = cape_normal(VERTEX, direction);
  VERTEX = cape_position(VERTEX);
 }
 VERTEX += normalize(direction) * width;
 if (cloth_floor_enabled) {
  vec4 world = MODEL_MATRIX * vec4(VERTEX, 1.0);
  // Keep the flattened shell just underneath its fabric, avoiding coplanar ink.
  world.y = max(world.y, cloth_floor_y - 0.0005);
  VERTEX = (inverse(MODEL_MATRIX) * world).xyz;
 }
}
void fragment() {
 ALBEDO = ink.rgb;
}
