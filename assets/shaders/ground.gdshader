// Position-hashed shared edges select a complete two-color Wang set. Explicit
// gradients keep atlas jumps out of mip selection; reflected gutters protect
// adjacent cells. Existing control weights still own material transitions.

shader_type spatial;
uniform sampler2D atlas_texture : source_color, filter_linear_mipmap;
uniform sampler2D wang_texture : source_color, filter_linear_mipmap, repeat_disable;
uniform bool wang_enabled = false;
uniform float wang_scale = 2.44921875;
uniform vec2 quadrant = vec2(0.0);
uniform bool blend_edges = false;
uniform sampler2D surface_weights : filter_linear, repeat_disable;
uniform vec2 control_size = vec2(1.0);
uniform float control_padding = 2.0;
varying vec3 world_position;

void vertex() { world_position = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz; }

int edge_color(ivec2 edge, int axis) {
	ivec2 position = ivec2(mod(vec2(edge), vec2(251.0)));
	int key = (position.x * 37 + position.y * 101 + axis * 53 + 17) % 251;
	return ((key * key * 13 + key * 19 + 23) % 101) % 2;
}

vec3 wang_paint(int index, int surface, vec2 local_uv, vec2 dx, vec2 dy) {
	vec2 cell = vec2(float(index % 4), float(index / 4 + surface * 4));
	vec2 dimensions = vec2(textureSize(wang_texture, 0));
	vec2 uv = (cell * 144.0 + vec2(8.5) + local_uv * 127.0) / dimensions;
	float footprint = max(max(length(dx), length(dy)) * 127.0, 1.0);
	float mip_scale = min(1.0, 8.0 / footprint);
	return textureGrad(wang_texture, uv, dx * 127.0 * mip_scale / dimensions, dy * 127.0 * mip_scale / dimensions).rgb;
}

void fragment() {
	vec2 position = world_position.xz * wang_scale;
	ivec2 cell = ivec2(floor(position));
	int index = edge_color(cell, 0) + 2 * edge_color(cell + ivec2(1, 0), 1)
		+ 4 * edge_color(cell + ivec2(0, 1), 0) + 8 * edge_color(cell, 1);
	vec2 dx = dFdx(position);
	vec2 dy = dFdy(position);
	vec2 local_uv = fract(position);
	vec2 uv = abs(fract(world_position.xz * 0.25) * 2.0 - 1.0) * 0.496 + 0.002;
	vec3 paint;
	if (blend_edges) {
		vec2 ground = world_position.xz;
		ground += vec2(sin(ground.y * 5.1 + ground.x * 2.3), cos(ground.x * 4.7 - ground.y * 2.1)) * 0.035;
		vec2 blend_position = floor(ground) + smoothstep(vec2(0.36), vec2(0.64), fract(ground));
		vec4 weights = texture(surface_weights, (blend_position + vec2(0.5 + control_padding)) / control_size);
		float total = dot(weights, vec4(1.0));
		weights = total > 0.001 ? weights / total : vec4(1.0, 0.0, 0.0, 0.0);
		if (wang_enabled) {
			paint = wang_paint(index, 0, local_uv, dx, dy) * weights.r
				+ texture(atlas_texture, uv + vec2(0.5, 0.0)).rgb * weights.g
				+ wang_paint(index, 1, local_uv, dx, dy) * weights.b
				+ texture(atlas_texture, uv + vec2(0.5)).rgb * weights.a;
		} else {
			paint = texture(atlas_texture, uv).rgb * weights.r
				+ texture(atlas_texture, uv + vec2(0.5, 0.0)).rgb * weights.g
				+ texture(atlas_texture, uv + vec2(0.0, 0.5)).rgb * weights.b
				+ texture(atlas_texture, uv + vec2(0.5)).rgb * weights.a;
		}
	} else {
		paint = texture(atlas_texture, uv + quadrant).rgb;
	}
	float gray = dot(paint, vec3(0.299, 0.587, 0.114));
	float variation = sin(world_position.x * 0.37 + world_position.z * 0.29) * sin(world_position.z * 0.53 - world_position.x * 0.19);
	ALBEDO = mix(vec3(gray), paint, 0.72) * vec3(0.88, 0.94, 0.94) * (0.93 + variation * 0.07);
	ROUGHNESS = 1.0;
}
