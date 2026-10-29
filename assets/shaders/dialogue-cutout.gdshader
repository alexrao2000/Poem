shader_type canvas_item;
varying vec4 tint;
void vertex() { tint = COLOR; }
// Generated cutout edges retain faint background alpha; discard only that haze.
void fragment() {
	vec4 pixel = texture(TEXTURE, UV);
	if (pixel.a < 0.13) { discard; }
	COLOR = pixel * tint;
}
