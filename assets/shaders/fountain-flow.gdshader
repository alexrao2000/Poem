shader_type spatial;
render_mode blend_mix, cull_disabled, depth_draw_opaque, fog_disabled;
void fragment() {
 float edge = smoothstep(0.0, 0.22, UV.x) * smoothstep(0.0, 0.22, 1.0-UV.x);
 float glint = pow(max(0.0, sin(UV.y*48.0-TIME*10.0)), 6.0);
 ALBEDO = mix(vec3(0.30,0.55,0.61), vec3(0.83,0.92,0.89), glint*0.7);
 ALPHA = edge * (0.52+glint*0.24) * (1.0-smoothstep(0.94,1.0,UV.y));
 ROUGHNESS = 0.25;
 SPECULAR = 0.45;
}
