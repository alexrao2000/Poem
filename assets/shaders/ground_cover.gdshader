shader_type spatial;
render_mode cull_disabled, specular_disabled;
uniform sampler2D plant_atlas : source_color, filter_linear_mipmap;
varying vec3 location;
void vertex() {
 location = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
 // UV2 survives static batching and pins each plant's root to the soil.
 float bend = UV2.y * UV2.y * 0.009;
 VERTEX.x += sin(location.x * 1.7 + location.z * 1.2 + TIME * 1.6) * bend;
 VERTEX.z += cos(location.x * 0.8 + location.z * 1.4 + TIME * 1.1) * bend * 0.45;
}
void fragment() {
 vec4 plant = texture(plant_atlas, UV);
 float variation = 0.5 + 0.5 * sin(location.x * 2.7 + location.z * 3.1);
 ALBEDO = plant.rgb * mix(vec3(0.77, 0.85, 0.72), vec3(0.94, 0.98, 0.88), variation);
 ALPHA = plant.a;
 ALPHA_SCISSOR_THRESHOLD = 0.45;
 ROUGHNESS = 1.0;
 if (!FRONT_FACING) { NORMAL = -NORMAL; }
}
