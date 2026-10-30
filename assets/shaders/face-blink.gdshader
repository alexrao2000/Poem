shader_type spatial;
render_mode diffuse_toon, cull_disabled;
uniform sampler2D open_face : source_color, filter_linear;
uniform sampler2D closed_face : source_color, filter_linear;
uniform bool eyes_closed = false;

void fragment() {
 // Preserve the original brow, nose and mouth even while the eyes change.
 float cell_v = fract(UV.y * 2.0);
 vec4 ink = texture(open_face, UV);
 if (eyes_closed && cell_v >= 0.34 && cell_v <= 0.55) {
  ink = texture(closed_face, UV);
 }
 ALBEDO = ink.rgb;
 ALPHA = ink.a;
 ALPHA_SCISSOR_THRESHOLD = 0.22;
 ROUGHNESS = 1.0;
}
