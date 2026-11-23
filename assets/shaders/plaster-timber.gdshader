shader_type spatial;
render_mode cull_disabled;

uniform sampler2D atlas_texture : source_color, filter_linear_mipmap, repeat_disable;
uniform vec2 cell_origin;
uniform vec4 base_color : source_color;
uniform float tile_scale = 0.65;
uniform float paint_weight = 0.58;

varying vec3 world_position;
varying vec3 world_normal;

void vertex() {
 world_position = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
 world_normal = MODEL_NORMAL_MATRIX * NORMAL;
}

void fragment() {
 vec3 axis = abs(world_normal);
 vec2 projection = world_position.xy;
 if (axis.y > max(axis.x, axis.z)) {
  projection = world_position.xz;
 } else if (axis.x > axis.z) {
  projection = world_position.zy;
 }
 vec2 surface_uv = projection * tile_scale;
 vec2 mirrored = abs(fract(surface_uv) * 2.0 - 1.0);
 vec2 atlas_uv = cell_origin + vec2(0.016) + mirrored * 0.468;
 vec2 dx = dFdx(surface_uv) * 0.936;
 vec2 dy = dFdy(surface_uv) * 0.936;
 // Limit the filter footprint to the inset between this swatch and its neighbors.
 float mip_scale = min(1.0, 0.01 / max(0.0001, max(length(dx), length(dy))));
 vec3 swatch = textureGrad(atlas_texture, atlas_uv, dx * mip_scale, dy * mip_scale).rgb;
 ALBEDO = mix(base_color.rgb, swatch, paint_weight);
 ROUGHNESS = 0.92;
}
