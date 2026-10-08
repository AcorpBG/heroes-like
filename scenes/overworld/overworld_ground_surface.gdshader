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
// Organic biome borders (owner-approved 2026-10-08): borders meander off the
// tile grid, and where grounds meet, the one with the higher priority and the
// higher painted detail (blades, pebbles) shows crisply over the other
// instead of a cross-fade. border_priority comes from ground_materials.json.
uniform float border_priority[16];
uniform float warp_tiles = 0.36;
uniform float warp_frequency = 0.55;
uniform float warp_detail_tiles = 0.12;
uniform float height_strength = 1.3;
uniform float blend_depth = 0.26;
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

// The material's average tone: its own detail relative to it acts as a height
// map for the border blend.
float average_luma(float slot) {
	vec2 cell = vec2(mod(slot, 4.0), floor(slot / 4.0));
	return dot(textureLod(materials, (cell * 512.0 + vec2(256.0)) / 2048.0, 6.0).rgb, vec3(0.299, 0.587, 0.114));
}

float border_hash(vec2 p) {
	p = fract(p * vec2(123.34, 456.21));
	p += dot(p, p + 45.32);
	return fract(p.x * p.y);
}

float border_noise(vec2 p) {
	vec2 i = floor(p);
	vec2 f = fract(p);
	vec2 u = f * f * (3.0 - 2.0 * f);
	return mix(mix(border_hash(i), border_hash(i + vec2(1.0, 0.0)), u.x), mix(border_hash(i + vec2(0.0, 1.0)), border_hash(i + vec2(1.0)), u.x), u.y);
}

// Three octaves on rotated lattices, so no straight run lines up with the grid.
vec2 border_warp(vec2 world) {
	vec2 p1 = mat2(vec2(0.866, 0.5), vec2(-0.5, 0.866)) * world;
	vec2 p2 = mat2(vec2(0.342, 0.940), vec2(-0.940, 0.342)) * world;
	vec2 p3 = mat2(vec2(0.966, -0.259), vec2(0.259, 0.966)) * world;
	return (vec2(border_noise(p1 * warp_frequency + vec2(17.3, 5.1)), border_noise(p1 * warp_frequency + vec2(-3.7, 29.9))) - vec2(0.5)) * 2.0 * warp_tiles
		+ (vec2(border_noise(p2 * 1.15 + vec2(41.0, -9.0)), border_noise(p2 * 1.15 + vec2(-21.0, 6.5))) - vec2(0.5)) * 2.0 * warp_detail_tiles * 1.6
		+ (vec2(border_noise(p3 * 2.4 + vec2(11.0, 3.0)), border_noise(p3 * 2.4 + vec2(-7.0, 13.0))) - vec2(0.5)) * 2.0 * warp_detail_tiles;
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

float is_water(float slot) {
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
		// The bend fades out near tile centres, so every tile's middle keeps
		// its own ground and stays readable.
		vec2 from_center = abs(fract(world) - vec2(0.5));
		float bend = smoothstep(0.05, 0.3, max(from_center.x, from_center.y));
		vec2 sample_position = world - vec2(0.5) + border_warp(world) * bend;
		vec2 cell = floor(sample_position);
		vec2 w = fract(sample_position);
		vec4 slots = vec4(known_slot(cell, own_slot), known_slot(cell + vec2(1.0, 0.0), own_slot),
			known_slot(cell + vec2(0.0, 1.0), own_slot), known_slot(cell + vec2(1.0), own_slot));
		vec4 corner = vec4((1.0 - w.x) * (1.0 - w.y), w.x * (1.0 - w.y), (1.0 - w.x) * w.y, w.x * w.y);
		vec3 surface;
		// Each corner's share of the final colour, for decals and the beach.
		vec4 share = vec4(1.0, 0.0, 0.0, 0.0);
		if (all(equal(slots, vec4(slots.x)))) {
			surface = ground(slots.x, world);
		} else {
			// Each material's merged corner weight, its priority and its own
			// painted detail compete; the winner shows with a narrow soft zone.
			vec3 color[4];
			vec4 score;
			for (int i = 0; i < 4; i++) {
				color[i] = ground(slots[i], world);
				float merged = dot(vec4(equal(slots, vec4(slots[i]))), corner);
				float height = (dot(color[i], vec3(0.299, 0.587, 0.114)) - average_luma(slots[i])) * (1.0 - is_water(slots[i]));
				score[i] = merged + border_priority[int(clamp(slots[i], 0.0, 15.0))] + height * height_strength;
			}
			float best = max(max(score.x, score.y), max(score.z, score.w));
			share = max(score - vec4(best - blend_depth), vec4(0.0));
			share /= max(share.x + share.y + share.z + share.w, 0.0001);
			surface = color[0] * share.x + color[1] * share.y + color[2] * share.z + color[3] * share.w;
		}
		if (decals_enabled) {
			surface = decal_layer(world, max(fwidth(world.x), fwidth(world.y)), slots, share, surface).rgb;
		}
		// A coastal material band, not new terrain: the same fog-safe four
		// samples join straight shores, concave inlets and diagonal islands.
		float water = dot(vec4(is_water(slots.x), is_water(slots.y), is_water(slots.z), is_water(slots.w)), corner);
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
