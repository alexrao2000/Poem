shader_type spatial;

uniform sampler2D atlas_texture : source_color, filter_linear_mipmap, repeat_disable;
uniform vec4 tint : source_color;

varying vec3 world_position;
varying vec3 world_normal;

void vertex() {
 world_position = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
 world_normal = MODEL_NORMAL_MATRIX * NORMAL;
}

void fragment() {
 vec3 axis = abs(world_normal);
 vec2 face = world_position.xy;
 if (axis.y > max(axis.x, axis.z)) {
  face = world_position.xz;
 } else if (axis.x > axis.z) {
  face = world_position.zy;
 }
 vec2 weathering = face * vec2(0.42, 0.68);
 vec2 atlas_uv = vec2(0.516) + abs(fract(weathering) * 2.0 - 1.0) * 0.468;
 vec2 dx = dFdx(weathering) * 0.936;
 vec2 dy = dFdy(weathering) * 0.936;
 float inset = min(1.0, 0.01 / max(0.0001, max(length(dx), length(dy))));
 vec3 swatch = textureGrad(atlas_texture, atlas_uv, dx * inset, dy * inset).rgb;
 float grain = dot(swatch, vec3(0.299, 0.587, 0.114));

 // Half-length offsets join alternating courses across adjacent wall pieces.
 vec2 courses = face / vec2(0.91, 0.32);
 vec2 footprint = max(fwidth(courses), vec2(0.001));
 courses.x += mod(floor(courses.y), 2.0) * 0.5;
 vec2 cell = fract(courses);
 vec2 edge = min(cell, 1.0 - cell);
 vec2 brick_faces = smoothstep(vec2(0.018), vec2(0.018) + footprint, edge);
 float joints = (1.0 - brick_faces.x * brick_faces.y) * (1.0 - smoothstep(0.15, 0.40, max(footprint.x, footprint.y)));
 ALBEDO = tint.rgb * (0.82 + 0.32 * grain) * (1.0 - joints * 0.24);
 ROUGHNESS = 0.96;
}
