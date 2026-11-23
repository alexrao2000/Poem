shader_type spatial;
render_mode diffuse_burley;
uniform vec4 deep_color : source_color = vec4(0.12, 0.27, 0.32, 1.0);
uniform vec4 crest_color : source_color = vec4(0.44, 0.64, 0.65, 1.0);
uniform vec2 flow_direction = vec2(0.0, 1.0);
uniform vec2 wave_scale = vec2(1.0);
uniform float wave_speed = 1.0;
uniform float crest_strength = 0.36;
varying vec3 world_position;
void vertex() { world_position = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz; }
void fragment() {
 vec2 lateral = vec2(flow_direction.y, -flow_direction.x);
 vec2 p = vec2(dot(world_position.xz, lateral), dot(world_position.xz, flow_direction)) * wave_scale;
 float clock = TIME * wave_speed;
 float broad = sin(p.x * 1.7 + p.y * 2.2 + clock * 0.75) * 0.5 + 0.5;
 float ripple = sin(p.y * 16.0 + sin(p.x * 5.0 + clock * 0.6) * 1.6 - clock * 1.8);
 float broken = smoothstep(0.20, 0.75, sin(p.x * 9.0 + p.y * 2.0 + clock * 0.4));
 float crest = smoothstep(0.87, 1.0, ripple) * broken;
 ALBEDO = mix(deep_color.rgb, crest_color.rgb, broad * 0.15 + crest * crest_strength);
 ROUGHNESS = 0.38;
 SPECULAR = 0.3;
 NORMAL_MAP = vec3(0.5+sin(p.x*5.0+clock)*0.025, 0.5+cos(p.y*7.0-clock)*0.025, 1.0);
}
