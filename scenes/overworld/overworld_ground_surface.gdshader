shader_type canvas_item;
render_mode unshaded;

uniform sampler2D materials : source_color, filter_linear_mipmap, repeat_disable;
// R: exact manifest slot / 255. G: explored bit. Never filtered or gamma corrected.
uniform sampler2D terrain_data : filter_nearest, repeat_disable;
uniform vec2 map_size;
uniform vec2 world_origin;
uniform vec2 world_span;
uniform float material_span_tiles = 4.0;
uniform float beach_slot = 5.0;
uniform vec3 water_slots = vec3(12.0, 13.0, 14.0);
// Ground detail decals, scattered here so they share the ground's light and
// blend: a 16x16 atlas of 128 px cells, 16 decals per ground set (rows 1-2
// tiny, row 3 medium, row 4 large). terrain_data blue marks road tiles.
uniform sampler2D decals : source_color, filter_linear_mipmap, repeat_disable;
uniform bool decals_enabled = false;
uniform float decal_set_for_slot[16];
uniform float decal_density_for_set[16];
uniform float decal_cell_tiles = 0.6;
uniform float decal_opacity = 0.92;

vec3 paint(float slot, vec2 uv) {
	vec2 cell = vec2(mod(slot, 4.0), floor(slot / 4.0));
	// A bounded mip level calms high-frequency grass/pebbles behind small
	// rewards. Inset past the mip footprint: no neighboring biome can bleed in.
	float detail_lod = slot < 12.0 ? 1.25 : 0.5;
	return textureLod(materials, (cell * 512.0 + vec2(6.5) + fract(uv) * 499.0) / 2048.0, detail_lod).rgb;
}

vec3 ground(float slot, vec2 world) {
	vec2 uv = fract(world / material_span_tiles);
	// Overlap painted samples near repeat boundaries, without reflected pixels
	// or synthesized noise. The second sample's wrap is masked by the first.
	vec2 core = smoothstep(vec2(0.0), vec2(0.18), uv) * (vec2(1.0) - smoothstep(vec2(0.82), vec2(1.0), uv));
	vec3 top = paint(slot, uv);
	if (core.x < 1.0) { top = mix(paint(slot, uv + vec2(0.5, 0.0)), top, core.x); }
	if (core.y < 1.0) {
		vec3 bottom = paint(slot, uv + vec2(0.0, 0.5));
		if (core.x < 1.0) { bottom = mix(paint(slot, uv + vec2(0.5)), bottom, core.x); }
		top = mix(bottom, top, core.y);
	}
	return top;
}

vec2 cell_data(vec2 cell) {
	return texture(terrain_data, (clamp(cell, vec2(0.0), map_size - vec2(1.0)) + vec2(0.5)) / map_size).rg;
}

vec3 cell_data3(vec2 cell) {
	return texture(terrain_data, (clamp(cell, vec2(0.0), map_size - vec2(1.0)) + vec2(0.5)) / map_size).rgb;
}

// Stable per-point randomness (hash without sine) and smooth value noise.
vec4 hash4(vec2 p) {
	vec4 p4 = fract(vec4(p.xyxy) * vec4(0.1031, 0.1030, 0.0973, 0.1099));
	p4 += dot(p4, p4.wzxy + 33.33);
	return fract((p4.xxyz + p4.yzzw) * p4.zywx);
}

float value_noise(vec2 p) {
	vec2 i = floor(p);
	vec2 f = fract(p);
	vec2 u = f * f * (3.0 - 2.0 * f);
	return mix(mix(hash4(i).x, hash4(i + vec2(1.0, 0.0)).x, u.x), mix(hash4(i + vec2(0.0, 1.0)).x, hash4(i + vec2(1.0)).x, u.x), u.y);
}

// One candidate point per decal cell, jittered; slow noise makes clumps and
// clearings; each point picks a decal of the ground under it, a size from its
// row (tiny common, large rare) and a mirror. Points on roads, unexplored
// tiles or ground without a set stay empty, and a decal fades out with its
// ground's own blend weight where it reaches toward a different ground.
// world_per_pixel picks the mip level explicitly: implicit derivatives are
// undefined inside this loop's non-uniform control flow.
vec4 decal_layer(vec2 world, float world_per_pixel, vec4 slots, vec4 blend, vec3 surface) {
	vec4 result = vec4(surface, 0.0);
	vec2 base = floor(world / decal_cell_tiles);
	float surface_luma = dot(surface, vec3(0.299, 0.587, 0.114));
	for (int dy = -1; dy <= 1; dy++) {
		for (int dx = -1; dx <= 1; dx++) {
			vec2 grid = base + vec2(float(dx), float(dy));
			vec4 h = hash4(grid + vec2(311.7, 183.3));
			vec2 center = (grid + vec2(0.2) + h.xy * 0.6) * decal_cell_tiles;
			vec3 data = cell_data3(floor(center));
			if (data.g < 0.5 || data.b > 0.5) { continue; }
			float slot = floor(data.r * 255.0 + 0.5);
			if (slot > 15.0) { continue; }
			float set = decal_set_for_slot[int(slot)];
			if (set < 0.0) { continue; }
			float cluster = smoothstep(0.2, 0.8, value_noise(center * 0.21 + vec2(set * 7.13, 3.7)));
			if (h.z > decal_density_for_set[int(set)] * mix(0.35, 1.6, cluster)) { continue; }
			vec4 k = hash4(grid + vec2(-57.1, 91.9));
			float size_roll = k.x;
			float row = size_roll < 0.52 ? floor(k.y * 2.0) : (size_roll < 0.84 ? 2.0 : 3.0);
			float column = floor(k.z * 4.0);
			// Relative to a decal cell (about a tile): tiny 0.45-0.62, medium
			// 0.75-1.0, large 1.1-1.45; every candidate fits the 3x3 cell search.
			float size = decal_cell_tiles * (row < 2.0 ? mix(0.45, 0.62, k.w) : (row < 3.0 ? mix(0.75, 1.0, k.w) : mix(1.1, 1.45, k.w)));
			vec2 local = (world - center) / size + vec2(0.5);
			if (local.x < 0.0 || local.y < 0.0 || local.x > 1.0 || local.y > 1.0) { continue; }
			if (fract(k.w * 41.7) > 0.5) { local.x = 1.0 - local.x; }
			float index = set * 16.0 + row * 4.0 + column;
			vec2 cell = vec2(mod(index, 16.0), floor(index / 16.0));
			float lod = log2(max(120.0 / size * world_per_pixel, 1.0));
			vec4 decal = textureLod(decals, (cell * 128.0 + vec2(4.0) + local * 120.0) / 2048.0, lod);
			// The ground's own light and shade carry through the decal.
			decal.rgb *= mix(1.0, clamp(surface_luma / 0.42, 0.75, 1.25), 0.35);
			float ground_share = dot(vec4(equal(slots, vec4(slot))), blend);
			float alpha = decal.a * decal_opacity * smoothstep(0.55, 0.9, ground_share);
			result.rgb = mix(result.rgb, decal.rgb, alpha);
			result.a = max(result.a, alpha);
		}
	}
	return result;
}

float known_slot(vec2 cell, float own_slot) {
	vec2 data = cell_data(cell);
	return data.g > 0.5 ? floor(data.r * 255.0 + 0.5) : own_slot;
}

float water_coverage(float slot) {
	return any(lessThan(abs(water_slots - vec3(slot)), vec3(0.5))) ? 1.0 : 0.0;
}

void fragment() {
	vec2 world = world_origin + UV * world_span;
	vec2 own = cell_data(floor(world));
	float own_slot = floor(own.r * 255.0 + 0.5);
	if (own.g < 0.5 || own_slot > 15.0) {
		// Identity-silent underlay. The authoritative fog layer is above this.
		COLOR = vec4(0.04, 0.05, 0.06, 1.0);
	} else {
		// The painted stone's luminance gives boundaries fine natural variation.
		// Only blend weights move; source texels remain fixed in world space.
		vec2 irregularity = clamp((ground(7.0, world * 2.0).rg - vec2(0.38)) * 0.8, vec2(-0.13), vec2(0.13));
		vec2 sample_position = world - vec2(0.5) + irregularity;
		vec2 cell = floor(sample_position);
		vec2 weight = smoothstep(vec2(0.23), vec2(0.77), fract(sample_position));
		float a = known_slot(cell, own_slot);
		float b = known_slot(cell + vec2(1.0, 0.0), own_slot);
		float c = known_slot(cell + vec2(0.0, 1.0), own_slot);
		float d = known_slot(cell + vec2(1.0), own_slot);
		vec3 ca = ground(a, world);
		vec3 cb = b == a ? ca : ground(b, world);
		vec3 cc = c == a ? ca : ground(c, world);
		vec3 cd = d == a ? ca : (d == b ? cb : (d == c ? cc : ground(d, world)));
		vec3 surface = mix(mix(ca, cb, weight.x), mix(cc, cd, weight.x), weight.y);
		if (decals_enabled) {
			vec4 blend = vec4((1.0 - weight.x) * (1.0 - weight.y), weight.x * (1.0 - weight.y), (1.0 - weight.x) * weight.y, weight.x * weight.y);
			surface = decal_layer(world, max(fwidth(world.x), fwidth(world.y)), vec4(a, b, c, d), blend, surface).rgb;
		}
		// A coastal material band, not new terrain: the same fog-safe four
		// samples join straight shores, concave inlets and diagonal islands.
		float water = mix(mix(water_coverage(a), water_coverage(b), weight.x),
			mix(water_coverage(c), water_coverage(d), weight.x), weight.y);
		if (water > 0.0 && water < 1.0) {
			vec3 sand = ground(beach_slot, world);
			float wet = smoothstep(0.38, 0.82, water);
			sand *= mix(vec3(1.0), vec3(0.68, 0.75, 0.78), wet);
			float beach = smoothstep(0.015, 0.16, water) * (1.0 - smoothstep(0.52, 0.94, water));
			surface = mix(surface, sand, beach);
		}
		COLOR = vec4(surface, 1.0);
	}
}
