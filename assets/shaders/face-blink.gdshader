shader_type spatial;
render_mode diffuse_toon, cull_disabled;
uniform sampler2D open_face : source_color, filter_linear;
uniform sampler2D closed_face : source_color, filter_linear;
uniform sampler2D focused_face : source_color, filter_linear;
uniform sampler2D serious_face : source_color, filter_linear;
uniform bool serious = false;
uniform bool eyes_closed = false;
uniform bool focused = false;

void fragment() {
 // Independent expression regions preserve the original nose and registration.
 float cell_v = fract(UV.y * 2.0);
 vec4 ink = texture(open_face, UV);
 if (focused && cell_v < 0.55) {
  ink = texture(focused_face, UV);
 }
 if (eyes_closed && cell_v >= 0.34 && cell_v <= 0.55) {
  ink = texture(closed_face, UV);
 }
 if (serious && cell_v >= 0.72 && cell_v <= 0.90) {
  ink = texture(serious_face, UV);
 }
 ALBEDO = ink.rgb;
 ALPHA = ink.a;
 ALPHA_SCISSOR_THRESHOLD = 0.22;
 ROUGHNESS = 1.0;
}
