shader_type spatial;
render_mode unshaded, cull_front, shadows_disabled;
uniform float width = 0.005;
uniform vec4 ink : source_color = vec4(0.20, 0.192, 0.227, 1.0);
void vertex() {
 VERTEX += normalize(COLOR.rgb * 2.0 - 1.0) * width;
}
void fragment() {
 ALBEDO = ink.rgb;
}
