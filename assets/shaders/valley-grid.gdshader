shader_type spatial;
render_mode unshaded, cull_disabled, shadows_disabled, fog_disabled;

uniform vec2 origin = vec2(21.0, 2.0);
uniform float front = 32.0;
varying vec2 chart_position;

void vertex() {
	chart_position = VERTEX.xz;
}

void fragment() {
	float distance_from_origin = distance(chart_position, origin);
	float ink = 1.0 - smoothstep(front - 0.52, front + 0.52, distance_from_origin);
	float edge = smoothstep(front - 1.5, front - 0.35, distance_from_origin) * ink;
	ALBEDO = mix(vec3(0.24, 0.15, 0.08), vec3(0.70, 0.46, 0.18), edge);
	ALPHA = 0.34 * ink + 0.40 * edge;
}
