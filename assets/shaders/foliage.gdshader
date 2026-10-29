shader_type spatial;
render_mode cull_disabled, specular_disabled;
uniform sampler2D foliage_atlas : source_color, filter_linear_mipmap;
uniform vec2 quadrant;
void vertex() {
 vec3 world_position = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
 VERTEX.x += sin(world_position.x * 1.1 + world_position.z * 0.7 + TIME * 1.3) * 0.018 * (1.0 - UV.y);
}
void fragment() {
 vec4 leaf = texture(foliage_atlas, UV * 0.498 + vec2(0.001) + quadrant);
 ALBEDO = leaf.rgb * vec3(0.94, 0.98, 0.94);
 ALPHA = leaf.a;
 ALPHA_SCISSOR_THRESHOLD = 0.45;
 ROUGHNESS = 1.0;
 if (!FRONT_FACING) { NORMAL = -NORMAL; }
}
