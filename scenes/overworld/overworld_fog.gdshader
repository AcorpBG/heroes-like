shader_type canvas_item;
render_mode unshaded;

// Soft fog of war (docs/overworld-soft-fog-and-shadows.md). It lies above the map objects
// and fades out over an organic edge that straddles the explored boundary:
// half of the fade thins over fog-edge tiles, whose ground the ground shader
// paints; objects there are never drawn. Deeper fog is always fully covered.
uniform sampler2D terrain_data : filter_nearest, repeat_disable;
uniform sampler2D veil : source_color, filter_linear, repeat_disable;
uniform bool has_veil = false;
uniform vec4 underlay : source_color = vec4(0.04, 0.05, 0.06, 1.0);
uniform vec4 veil_base : source_color = vec4(0.13, 0.16, 0.16, 0.16);
uniform vec4 veil_modulate : source_color = vec4(0.8, 0.88, 0.82, 0.8);
uniform vec2 map_size;
uniform vec2 world_origin;
uniform vec2 world_span;
// Width of the fade, in tiles, and how far the edge wanders off the grid.
uniform float band_tiles = 0.7;
uniform float warp_tiles = 0.38;

float lookup(vec2 cell) {
	return texture(terrain_data, (clamp(cell, vec2(0.0), map_size - vec2(1.0)) + vec2(0.5)) / map_size).g;
}

vec4 bspline(float f) {
	float f2 = f * f;
	float f3 = f2 * f;
	return vec4((1.0 - f) * (1.0 - f) * (1.0 - f), 3.0 * f3 - 6.0 * f2 + 4.0, -3.0 * f3 + 3.0 * f2 + 3.0 * f + 1.0, f3) / 6.0;
}

// Share of tiles at or above `level` around a point: a cubic B-spline over the
// 4x4 tiles around it. Exactly 0.5 on a straight tile edge; corners round off
// over about a tile.
float share_at_least(vec2 world, float level) {
	vec2 p = world - vec2(0.5);
	vec2 c = floor(p);
	vec2 f = fract(p);
	vec4 wx = bspline(f.x);
	vec4 wy = bspline(f.y);
	float share = 0.0;
	for (int j = 0; j < 4; j++) {
		float row = 0.0;
		for (int i = 0; i < 4; i++) {
			row += wx[i] * step(level, lookup(c + vec2(float(i - 1), float(j - 1))));
		}
		share += wy[j] * row;
	}
	return share;
}

float hash(vec2 p) {
	p = fract(p * vec2(123.34, 456.21));
	p += dot(p, p + 45.32);
	return fract(p.x * p.y);
}

float value_noise(vec2 p) {
	vec2 i = floor(p);
	vec2 f = fract(p);
	vec2 u = f * f * (3.0 - 2.0 * f);
	return mix(mix(hash(i), hash(i + vec2(1.0, 0.0)), u.x), mix(hash(i + vec2(0.0, 1.0)), hash(i + vec2(1.0)), u.x), u.y);
}

// Four octaves on rotated lattices, so the edge never runs along the grid.
float fbm(vec2 p) {
	float v = 0.0;
	float amp = 0.5;
	mat2 r = mat2(vec2(0.8, 0.6), vec2(-0.6, 0.8));
	p = mat2(vec2(0.966, 0.259), vec2(-0.259, 0.966)) * p;
	for (int i = 0; i < 4; i++) {
		v += amp * value_noise(p);
		p = r * p * 2.03 + vec2(17.1, 9.3);
		amp *= 0.5;
	}
	return v;
}

void fragment() {
	vec2 world = world_origin + UV * world_span;
	vec2 bent = world + (vec2(fbm(world * 0.9 + vec2(3.1, 7.7)), fbm(world * 0.9 + vec2(-5.3, 1.9))) - vec2(0.5)) * 2.0 * warp_tiles;
	float hidden = 1.0 - share_at_least(bent, 0.75);
	float alpha = smoothstep(0.5 - band_tiles * 0.6, 0.5 + band_tiles * 0.4, hidden);
	// The fade is complete before the painted fog-edge ground ends, so its
	// rim never shows as a step where a corner leaves the fade short.
	alpha = max(alpha, 1.0 - smoothstep(0.8, 0.98, share_at_least(bent, 0.25)));
	// Beyond the fog edge nothing is painted underneath: always fully covered.
	alpha = max(alpha, 1.0 - step(0.25, lookup(floor(world))));
	vec3 rgb = mix(underlay.rgb, veil_base.rgb, veil_base.a);
	if (has_veil) {
		vec4 paint = texture(veil, world / map_size);
		rgb = mix(rgb, paint.rgb * veil_modulate.rgb, paint.a * veil_modulate.a);
	}
	COLOR = vec4(rgb, alpha);
}
