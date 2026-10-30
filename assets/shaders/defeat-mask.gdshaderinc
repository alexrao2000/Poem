// Ordered coverage keeps opaque character passes depth-tested during defeat.
uniform float defeat_visibility : hint_range(0.0, 1.0) = 1.0;
float defeat_threshold(vec2 pixel) {
 ivec2 cell = ivec2(mod(floor(pixel), 4.0));
 int low = (cell.x % 2) * 2 + (cell.y % 2) * 3;
 low = low % 4;
 int high = (cell.x / 2) * 2 + (cell.y / 2) * 3;
 high = high % 4;
 return (float(low * 4 + high) + 0.5) / 16.0;
}
