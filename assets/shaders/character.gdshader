shader_type spatial;
render_mode diffuse_toon, specular_toon, cull_disabled;
uniform sampler2D materials_atlas : source_color, filter_linear_mipmap;
uniform vec4 tint : source_color = vec4(1.0);
uniform vec2 quadrant;
uniform float texture_repeat = 1.0;
uniform float metal = 0.0;
void fragment() {
 vec2 detail_uv = fract(UV * texture_repeat) * 0.496 + 0.002 + quadrant;
 vec3 paint = texture(materials_atlas, detail_uv).rgb;
 ALBEDO = paint * tint.rgb;
 ROUGHNESS = mix(0.9, 0.46, metal);
 METALLIC = metal * 0.45;
 SPECULAR = 0.25;
}
