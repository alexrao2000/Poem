shader_type spatial;
uniform sampler2D atlas_texture : source_color, filter_linear_mipmap;
uniform vec2 quadrant = vec2(0.0);
uniform bool blend_edges = false;
uniform sampler2D surface_weights : filter_linear, repeat_disable;
uniform vec2 control_size = vec2(1.0);
uniform float control_padding = 2.0;
varying vec3 world_position;

void vertex() { world_position = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz; }

void fragment() {
	// Mirrored repeats share their edge pixels, avoiding a hard atlas wrap seam.
	vec2 uv = abs(fract(world_position.xz * 0.25) * 2.0 - 1.0) * 0.496 + 0.002;
	vec3 paint;
	if (blend_edges) {
		vec2 ground = world_position.xz;
		ground += vec2(sin(ground.y * 5.1 + ground.x * 2.3), cos(ground.x * 4.7 - ground.y * 2.1)) * 0.035;
		// Keep tile interiors readable; soften only a narrow band at each boundary.
		vec2 blend_position = floor(ground) + smoothstep(vec2(0.36), vec2(0.64), fract(ground));
		vec4 weights = texture(surface_weights, (blend_position + vec2(0.5 + control_padding)) / control_size);
		float total = dot(weights, vec4(1.0));
		weights = total > 0.001 ? weights / total : vec4(1.0, 0.0, 0.0, 0.0);
		paint = texture(atlas_texture, uv).rgb * weights.r
			+ texture(atlas_texture, uv + vec2(0.5, 0.0)).rgb * weights.g
			+ texture(atlas_texture, uv + vec2(0.0, 0.5)).rgb * weights.b
			+ texture(atlas_texture, uv + vec2(0.5)).rgb * weights.a;
	} else {
		paint = texture(atlas_texture, uv + quadrant).rgb;
	}
	float gray = dot(paint, vec3(0.299, 0.587, 0.114));
	float variation = sin(world_position.x * 0.37 + world_position.z * 0.29) * sin(world_position.z * 0.53 - world_position.x * 0.19);
	ALBEDO = mix(vec3(gray), paint, 0.72) * vec3(0.88, 0.94, 0.94) * (0.93 + variation * 0.07);
	ROUGHNESS = 1.0;
}
