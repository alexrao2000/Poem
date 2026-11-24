shader_type spatial;
render_mode unshaded, depth_draw_never, cull_disabled;

uniform vec4 foam_color : source_color = vec4(0.74, 0.81, 0.69, 1.0);
uniform vec2 flow_direction = vec2(0.0, 1.0);
uniform float foam_depth = 0.047;

varying vec2 world_position;

void vertex() {
 world_position = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xz;
}

void fragment() {
 float water_depth = UV.x;
 float envelope = smoothstep(0.0, foam_depth * 0.17, water_depth)
   * (1.0 - smoothstep(foam_depth * 0.35, foam_depth, water_depth));
 float drift = dot(world_position, flow_direction) * 3.2 - TIME * 1.45;
 float edge = dot(world_position, vec2(flow_direction.y, -flow_direction.x));
 float lace = sin(drift + sin(edge * 7.0) * 0.8) + sin(drift * 2.26 + edge * 3.1) * 0.45;
 ALBEDO = foam_color.rgb;
 ALPHA = envelope * (0.14 + smoothstep(-0.22, 0.92, lace) * 0.27);
}
