shader_type canvas_item;
uniform vec2 panel_size = vec2(600.0, 140.0);
varying vec2 panel_uv;
void vertex() { panel_uv = VERTEX / panel_size; }
void fragment() {
 float edge = panel_uv.x - (1.0 - panel_uv.y) * 0.045;
 float mask = smoothstep(0.0, 0.07, edge) * (1.0 - smoothstep(0.91, 0.98, edge));
 COLOR.a *= mask;
}
