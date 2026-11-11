shader_type canvas_item;
render_mode unshaded;

uniform sampler2D materials : source_color, filter_linear_mipmap, repeat_disable;
// R: exact manifest slot / 255. G: 1 explored, 0.5 fog edge (unexplored next
// to explored land), 0 deeper fog. B: road. Never filtered or gamma corrected.
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
// The bend grows from nothing at a tile's centre to full at its corners, and
// the warp is held under warp_reach: together slow enough that the bent
// lookup never folds over itself (reach x steepest bend < 1). A fold showed
// as square teeth and holes of a tile's own ground inside its neighbour's.
uniform float warp_reach = 0.4;
// The shore, by the share of water round a point (0.5 on a straight tile
// edge): dry sand comes in over the land, wet sand darkens toward the
// waterline, and the sea is laid over the sand, clear in the shallows.
uniform vec2 shore_sand = vec2(0.015, 0.16);
uniform vec2 shore_wet = vec2(0.34, 0.52);
uniform vec2 shore_sea = vec2(0.5, 0.58);
// Past the waterline the sea deepens: in the shallows the sand shows through
// it (shore_shallow is how much of the sea covers it there).
uniform vec2 shore_deep = vec2(0.55, 0.92);
uniform float shore_shallow = 0.55;
// Moving water (owner request, 2026-11-11): the painted sea drifts and swells
// with glints passing over its net of light, and waves run in on every
// shore, break into foam on the sand and slide back. Every rate divides the
// hour TIME wraps at (the drift by the 4-tile painting), so nothing jumps.
// With motion off the sea stands still under a thin line of foam.
uniform bool motion_enabled = true;
uniform float clock_override = -1.0;
uniform vec2 sea_drift = vec2(0.08, 0.03);
uniform float sea_swell = 0.07;
uniform float sea_glint = 0.3;
uniform float sea_roll = 0.07;
uniform float wave_seconds = 4.5;
uniform float wave_runup = 0.07;
uniform float wave_foam = 0.9;
uniform float wave_crest = 0.8;
uniform float wave_reach = 0.9;
uniform float wave_face = 0.28;
// Rivers run downstream (the lookup's alpha holds the side each river tile
// flows out of): lights slide along the stream, river_speed of them a second
// past a point, three to a tile. Lava burns in its cracks: the fire the
// painting shows there swells and fades in slow patches, with a soft glow
// round it (lava_glow).
uniform float river_speed = 1.2;
uniform float river_lights = 0.5;
uniform float lava_glow = 0.9;
// Ground detail decals, scattered here so they share the ground's light and
// blend: a 16x16 atlas of 128 px cells, 16 decals per ground set (rows 1-2
// tiny, row 3 medium, row 4 large). terrain_data blue marks road tiles.
uniform sampler2D decals : source_color, filter_linear_mipmap, repeat_disable;
uniform bool decals_enabled = false;
uniform float decal_set_for_slot[16];
uniform float decal_density_for_set[16];
uniform float decal_cell_tiles = 0.6;
uniform float decal_opacity = 0.92;
// Impassable land (terrain_data alpha 0, e.g. rock) is a black void walled
// by a thick rugged stone ledge, so blocked ground reads at a glance
// (owner-approved 2026-10-15). The ledge sits on the impassable side of the
// tile edge: walkable tiles keep their own ground. Depth units: 0.5 is the
// tile edge, 1.0 a tile walled in on all sides.
uniform float rock_slot = 7.0;
uniform float rock_warp_scale = 0.3;
uniform float rock_crag = 0.24;
uniform float rock_ledge_start = 0.46;
uniform float rock_ledge_end = 0.97;
uniform vec3 rock_void_color = vec3(0.016, 0.015, 0.018);
// Rivers (owner pick D, a narrow stream, 2026-10-15): terrain_data blue bits
// 0-3 join a river tile N/E/S/W, bit 4 marks it, bits 5-6 its type (clear,
// icy, muddy, lava), bit 7 is road. The stream winds off the tile grid and
// turns in arcs; dark wet banks blend it into the ground under it.
uniform float river_half_width = 0.09;
uniform float river_bank = 0.07;
uniform float river_meander = 0.2;
uniform float lava_slot = 9.0;

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
	// Integer arithmetic on the lattice point: every fragment gets the same
	// value for the same point. The float hash used before amplified rounding
	// (fract of products in the thousands, then squared), and its result at a
	// shared corner differed between the two cells that read it, which cut
	// the noise, and every border bent by it, along straight lattice lines.
	uvec2 q = uvec2(ivec2(p)) * uvec2(1597334673u, 3812015801u);
	uint n = (q.x ^ q.y) * 1597334673u;
	return float(n >> 8u) * (1.0 / 16777216.0);
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
			if (data.g < 0.5 || data.b > 0.002) { continue; }
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
	return data.g > 0.25 ? floor(data.r * 255.0 + 0.5) : own_slot;
}

float is_water(float slot) {
	return any(lessThan(abs(water_slots - vec3(slot)), vec3(0.5))) ? 1.0 : 0.0;
}

// The sea at a point: each patch rises and falls on its own beat (its phase
// from still noise), so the swell rolls across the painting instead of
// pulsing; the painting drifts with the wind, glints pass over its net of
// light, and long low swells roll through, lighter on their backs.
vec3 sea_paint(float slot, vec2 world, float t) {
	float phase = 6.2832 * value_noise(world * 0.55 + vec2(5.3, 9.1));
	vec2 swell = vec2(sin(t * 1.3963 + phase), cos(t * 1.0472 + phase * 1.7)) * sea_swell;
	vec3 sea = ground(slot, world + swell + sea_drift * t);
	float lift = 0.5 + 0.5 * sin(t * 2.0944 + phase * 2.3 + dot(world, vec2(1.9, 1.3)));
	float net = smoothstep(0.02, 0.2, dot(sea, vec3(0.299, 0.587, 0.114)) - average_luma(slot));
	float roll = sin(dot(world, vec2(0.9, 1.4)) * 1.7 - t * 1.0472 + phase * 0.8);
	return (sea + sea * net * lift * sea_glint) * (1.0 + sea_roll * roll);
}

// Lava: the crust stands, the fire in its cracks breathes. The glow round a
// crack is a blurred look at the same painting.
vec3 lava_paint(float slot, vec2 world, float t) {
	vec3 crust = ground(slot, world);
	vec2 cell = vec2(mod(slot, 4.0), floor(slot / 4.0));
	vec3 soft = textureLod(materials, (cell * 512.0 + vec2(24.0) + fract(world / material_span_tiles) * 464.0) / 2048.0, 3.5).rgb;
	float fire = smoothstep(0.06, 0.25, crust.r - max(crust.g, crust.b));
	float glow = smoothstep(0.04, 0.1, soft.r - max(soft.g, soft.b));
	float phase = 6.2832 * value_noise(world * 0.8 + vec2(2.9, 6.3));
	float pulse = 0.5 + 0.5 * sin(t * 1.0472 + phase + dot(world, vec2(0.7, 1.1)));
	float heat = pulse * (0.8 + 0.2 * sin(t * 4.1888 + phase * 3.1));
	return crust + vec3(1.0, 0.42, 0.08) * (fire * (0.25 + 0.75 * heat) + glow * 0.35 * heat) * lava_glow;
}

// A ground's colour: the sea and the fire move, the land stands.
vec3 ground_now(float slot, vec2 world, float t) {
	if (is_water(slot) > 0.5) { return sea_paint(slot, world, t); }
	return abs(slot - lava_slot) < 0.5 ? lava_paint(slot, world, t) : ground(slot, world);
}

// The share of water in the 3x3 tiles round a point, by smooth (quadratic
// B-spline) weights: 0.5 on a straight tile edge, 1 a tile out to sea, and
// without the corners the four-tile weights keep on a stepped coast.
float coast_share(vec2 p, float own_slot) {
	vec2 cell = floor(p);
	vec2 f = fract(p) - vec2(0.5);
	vec3 wx = vec3(0.5 * (0.5 - f.x) * (0.5 - f.x), 0.75 - f.x * f.x, 0.5 * (0.5 + f.x) * (0.5 + f.x));
	vec3 wy = vec3(0.5 * (0.5 - f.y) * (0.5 - f.y), 0.75 - f.y * f.y, 0.5 * (0.5 + f.y) * (0.5 + f.y));
	float share = 0.0;
	for (int j = 0; j < 3; j++) {
		for (int i = 0; i < 3; i++) {
			share += wx[i] * wy[j] * is_water(known_slot(cell + vec2(float(i - 1), float(j - 1)), own_slot));
		}
	}
	return share;
}

float void_flag(vec2 cell, float own_void) {
	vec4 data = texture(terrain_data, (clamp(cell, vec2(0.0), map_size - vec2(1.0)) + vec2(0.5)) / map_size);
	return data.g > 0.25 ? 1.0 - step(0.5, data.a) : own_void;
}

// How deep a point lies in impassable land: 0 on open ground, 0.5 on the
// tile edge, 1 at the middle of a tile walled in on all sides. Smooth weights
// between tile centres; a little of the border warp and a fine crag noise
// make the wall line rugged without moving it off its tile edge.
float void_depth(vec2 world, vec2 warp, float bend, float own_void) {
	vec2 p = world - vec2(0.5) + warp * bend * rock_warp_scale;
	vec2 cell = floor(p);
	vec2 w = fract(p);
	w = w * w * (3.0 - 2.0 * w);
	vec4 v = vec4(void_flag(cell, own_void), void_flag(cell + vec2(1.0, 0.0), own_void),
		void_flag(cell + vec2(0.0, 1.0), own_void), void_flag(cell + vec2(1.0), own_void));
	float count = v.x + v.y + v.z + v.w;
	if (count == 0.0) { return 0.0; }
	// Walled in on all sides: plain void, no crag specks.
	if (count == 4.0) { return 1.0; }
	float r = mix(mix(v.x, v.y, w.x), mix(v.z, v.w, w.x), w.y);
	float crag = value_noise(world * 6.0) * 0.6 + value_noise(world * 14.0 + vec2(5.3, 1.7)) * 0.4 - 0.5;
	return r + crag * rock_crag * bend;
}

int river_bits(vec2 cell) {
	return int(texture(terrain_data, (clamp(cell, vec2(0.0), map_size - vec2(1.0)) + vec2(0.5)) / map_size).b * 255.0 + 0.5);
}

// The side a river tile's water flows out of: 0 unknown, 1 north, 2 east,
// 3 south, 4 west.
int river_out(vec2 cell) {
	int code = int((1.0 - texture(terrain_data, (clamp(cell, vec2(0.0), map_size - vec2(1.0)) + vec2(0.5)) / map_size).a) * 255.0 + 0.5);
	return code <= 4 ? code : 0;
}

float segment_distance(vec2 p, vec2 a, vec2 b) {
	vec2 ab = b - a;
	float t = clamp(dot(p - a, ab) / max(dot(ab, ab), 0.0001), 0.0, 1.0);
	return length(p - a - ab * t);
}

// Distance from p to the river network in the 3x3 tiles around it, each
// river tile running from its centre to the edges it joins, divided by the
// local half-width (springs taper). y: the river's type bits of the nearest.
// z: how far along that tile's run the point lies, in tiles downstream, from
// -0.5 where the water comes in to 0.5 where it leaves: a tile's 0.5 meets
// the next one's -0.5, so anything with a whole number of periods a tile
// runs on unbroken.
vec3 river_field(vec2 p) {
	vec2 base = floor(p);
	float best = 1e5;
	float type_bits = 0.0;
	float best_along = 0.0;
	for (int dy = -1; dy <= 1; dy++) {
		for (int dx = -1; dx <= 1; dx++) {
			vec2 cell = base + vec2(float(dx), float(dy));
			int bits = river_bits(cell);
			if ((bits & 16) == 0) { continue; }
			vec2 centre = cell + vec2(0.5);
			int joins = bits & 15;
			int count = (joins & 1) + ((joins >> 1) & 1) + ((joins >> 2) & 1) + ((joins >> 3) & 1);
			float d = length(p - centre) / (count == 0 ? 0.7 : 1.0);
			float along = 0.0;
			int out_side = river_out(cell);
			bool bend = count == 2 && joins != 5 && joins != 10;
			if (bend) {
				// A turn sweeps round the corner between its two edges.
				vec2 corner = cell + vec2((joins & 2) != 0 ? 1.0 : 0.0, (joins & 4) != 0 ? 1.0 : 0.0);
				vec2 local = p - corner;
				vec2 inward = centre - corner;
				d = (local.x * inward.x >= 0.0 && local.y * inward.y >= 0.0) ? abs(length(local) - 0.5)
					: min(length(p - (centre + (corner - centre) * vec2(1.0, 0.0))), length(p - (centre + (corner - centre) * vec2(0.0, 1.0))));
				// Round the turn, from its north or south side (0) to its east or west side (1).
				float turn = atan(abs(local.y), max(abs(local.x), 0.0001)) / 1.5708;
				along = (out_side == 2 || out_side == 4) ? turn - 0.5 : 0.5 - turn;
			} else {
				for (int side = 0; side < 4; side++) {
					if ((joins & (1 << side)) == 0) { continue; }
					vec2 dir = side == 0 ? vec2(0.0, -1.0) : (side == 1 ? vec2(1.0, 0.0) : (side == 2 ? vec2(0.0, 1.0) : vec2(-1.0, 0.0)));
					float arm = segment_distance(p, centre, centre + dir * 0.5);
					if (arm < d) {
						d = arm;
						float reach = clamp(dot(p - centre, dir), 0.0, 0.5);
						along = out_side == side + 1 ? reach : -reach;
					}
				}
			}
			if (count == 1) {
				// A spring: narrow at its source, full width by the tile edge.
				vec2 dir = (joins & 1) != 0 ? vec2(0.0, -1.0) : ((joins & 2) != 0 ? vec2(1.0, 0.0) : ((joins & 4) != 0 ? vec2(0.0, 1.0) : vec2(-1.0, 0.0)));
				float along = clamp(dot(p - centre, dir) / 0.5, 0.0, 1.0);
				d /= mix(0.45, 1.0, smoothstep(0.0, 1.0, along));
			}
			if (d < best) {
				best = d;
				type_bits = float((bits >> 5) & 3);
				best_along = along;
			}
		}
	}
	return vec3(best, type_bits, best_along);
}

vec3 river_paint(vec3 surface, vec2 world, vec2 warp, float t) {
	// Where a road crosses (road and river on one tile) the stream runs
	// straight through the tile centre, so the crossing sits on the water.
	float straight = 1.0;
	vec2 base = floor(world);
	for (int dy = -1; dy <= 1; dy++) {
		for (int dx = -1; dx <= 1; dx++) {
			vec2 cell = base + vec2(float(dx), float(dy));
			if ((river_bits(cell) & 144) == 144) {
				vec2 off = abs(world - cell - vec2(0.5));
				straight = min(straight, smoothstep(0.3, 1.1, max(off.x, off.y)));
			}
		}
	}
	vec2 p = world + (vec2(value_noise(world * 0.7 + vec2(3.1, 7.7)), value_noise(world * 0.7 + vec2(-5.3, 1.9))) * 2.0 * river_meander - vec2(river_meander)
		+ warp * 0.15) * straight;
	vec3 field = river_field(p);
	float half_width = river_half_width;
	float bank = river_bank;
	// Banks wobble a little; the width breathes along the river.
	float wobble = 1.0 + 0.18 * (value_noise(world * 3.3 + vec2(9.1, 2.3)) - 0.5);
	float d = field.x / wobble;
	if (d > half_width + bank + 0.06) { return surface; }
	float aa = max(fwidth(d), 0.004);
	float type_bits = field.y;
	vec3 sea = ground(12.0, world * 0.7);
	// Calmer than the open sea: a little desaturated, darker in the channel.
	vec3 deep = mix(sea, vec3(dot(sea, vec3(0.299, 0.587, 0.114))), 0.35) * vec3(0.62, 0.74, 0.8);
	vec3 shallow = mix(sea, vec3(dot(sea, vec3(0.299, 0.587, 0.114))), 0.4) * vec3(0.85, 0.95, 0.95) + vec3(0.02, 0.03, 0.02);
	if (type_bits > 2.5) {
		vec3 lava = ground(lava_slot, world);
		deep = lava * vec3(1.6, 0.9, 0.5) + vec3(0.35, 0.08, 0.0);
		shallow = lava * vec3(1.2, 0.8, 0.6);
	} else if (type_bits > 1.5) {
		deep = mix(deep, vec3(0.36, 0.3, 0.2), 0.65);
		shallow = mix(shallow, vec3(0.5, 0.42, 0.3), 0.6);
	} else if (type_bits > 0.5) {
		deep = mix(deep, vec3(0.72, 0.84, 0.9), 0.55);
		shallow = mix(shallow, vec3(0.88, 0.94, 0.97), 0.6);
	}
	float centre = 1.0 - smoothstep(0.0, half_width, d);
	vec3 water = mix(shallow, deep, smoothstep(0.1, 0.85, centre));
	// The stream runs: lights slide down its middle, three to a tile and two
	// slower ones under them, each bent and broken by still noise so they do
	// not march in step.
	float lights = pow(0.5 + 0.5 * sin(6.2832 * (field.z * 3.0 - t * river_speed) + 2.5 * value_noise(world * 4.0 + vec2(1.3, 4.1))), 4.0) * 0.75
		+ pow(0.5 + 0.5 * sin(6.2832 * (field.z * 2.0 - t * river_speed * 0.5) + 4.0 * value_noise(world * 2.3 + vec2(7.0, 2.2))), 2.0) * 0.25;
	float glint = smoothstep(0.15, 0.85, centre) * lights * mix(0.6, 1.0, value_noise(world * 5.0 + vec2(1.3, 4.1)));
	water *= mix(0.78, 1.02, lights);
	water += (type_bits > 2.5 ? vec3(0.55, 0.22, 0.03) : vec3(0.9, 1.0, 0.95)) * glint * river_lights;
	vec3 bank_color = surface * vec3(0.55, 0.52, 0.48);
	float in_bank = 1.0 - smoothstep(half_width + bank - aa, half_width + bank + 0.06, d);
	vec3 result = mix(surface, bank_color, in_bank * 0.85);
	// Wet edge: darker just outside the water line.
	float wet = 1.0 - smoothstep(half_width, half_width + bank * 0.6, d);
	result *= mix(1.0, 0.82, wet);
	float in_water = 1.0 - smoothstep(half_width - aa, half_width + aa, d);
	return mix(result, water, in_water);
}

vec3 rock_void(vec3 surface, vec2 world, vec2 warp, float bend, float own_void) {
	float depth = void_depth(world, warp, bend, own_void);
	vec2 grad = vec2(dFdx(depth), dFdy(depth));
	if (depth <= 0.3) { return surface; }
	if (depth < rock_ledge_start) {
		// A thin contact shade on the ground where it meets the ledge.
		return surface * (1.0 - 0.3 * smoothstep(rock_ledge_start - 0.18, rock_ledge_start, depth));
	}
	float t = (depth - rock_ledge_start) / (rock_ledge_end - rock_ledge_start);
	if (t >= 1.0) { return rock_void_color; }
	// The ledge's outward side facing up-left, toward the light, is brighter.
	float glen = length(grad);
	vec2 outward = glen > 0.0 ? -grad / glen : vec2(0.0, -1.0);
	float facing = dot(outward, normalize(vec2(-0.55, -0.83)));
	// Stacked, lumpy stones: warm lit tops, dark joints, the inner face
	// dropping into the void.
	vec3 stone = ground(rock_slot, world * 1.6 + vec2(0.37, 0.11));
	float lumps = value_noise(world * 9.0 + vec2(depth * 6.0)) * 0.65 + value_noise(world * 21.0) * 0.35;
	float joints = smoothstep(0.18, 0.42, abs(fract(t * 2.8 + lumps * 0.9) - 0.5));
	vec3 ledge = stone * vec3(1.25, 1.02, 0.74) * (0.72 + 0.5 * lumps) * mix(0.55, 1.0, joints);
	float light = 0.82 + 0.38 * facing;
	float fall = 1.0 - smoothstep(0.72, 1.0, t);
	vec3 face = ledge * light * mix(0.1, 1.0, fall) * (1.0 + 0.35 * (1.0 - smoothstep(0.0, 0.16, t)));
	return mix(face, rock_void_color, smoothstep(0.94, 1.0, t));
}

void fragment() {
	vec2 world = world_origin + UV * world_span;
	vec4 own_full = texture(terrain_data, (clamp(floor(world), vec2(0.0), map_size - vec2(1.0)) + vec2(0.5)) / map_size);
	vec2 own = own_full.rg;
	float own_void = 1.0 - step(0.5, own_full.a);
	float own_slot = floor(own.r * 255.0 + 0.5);
	// Fog-edge tiles paint their ground: the soft fog above (overworld_fog.gdshader)
	// thins over them. Deeper fog stays identity-silent.
	if (own.g < 0.25 || own_slot > 15.0) {
		// Identity-silent underlay. The authoritative fog layer is above this.
		COLOR = vec4(0.04, 0.05, 0.06, 1.0);
	} else {
		// The bend fades out near tile centres, so every tile's middle keeps
		// its own ground and stays readable.
		vec2 from_center = fract(world) - vec2(0.5);
		float bend = smoothstep(0.0, 0.7071, length(from_center));
		vec2 warp = border_warp(world);
		vec2 held = warp / sqrt(1.0 + dot(warp, warp) / (warp_reach * warp_reach));
		vec2 sample_position = world - vec2(0.5) + held * bend;
		vec2 cell = floor(sample_position);
		vec2 w = fract(sample_position);
		vec4 slots = vec4(known_slot(cell, own_slot), known_slot(cell + vec2(1.0, 0.0), own_slot),
			known_slot(cell + vec2(0.0, 1.0), own_slot), known_slot(cell + vec2(1.0), own_slot));
		vec4 corner = vec4((1.0 - w.x) * (1.0 - w.y), w.x * (1.0 - w.y), (1.0 - w.x) * w.y, w.x * w.y);
		vec4 wet_corner = vec4(is_water(slots.x), is_water(slots.y), is_water(slots.z), is_water(slots.w));
		float water = dot(wet_corner, corner);
		// A shore by the tiles themselves, not their weights: rounding leaves the
		// weights of four water tiles a hair under one.
		float wet_tiles = wet_corner.x + wet_corner.y + wet_corner.z + wet_corner.w;
		bool shore = wet_tiles > 0.5 && wet_tiles < 3.5;
		vec3 sea = vec3(0.0);
		float clock = motion_enabled ? (clock_override >= 0.0 ? clock_override : TIME) : 0.0;
		// Waves. Stretches of coast run out of step (lag); along one, a wave's
		// life is run 0 to 1: its crest comes in from the open sea, breaks on
		// the sand at 0.5 and the water runs up (up), then slides back.
		// Foam (lace) is dabbed and broken, not a drawn line. All of this only
		// where water lies round the point.
		float run = 0.8;
		float up = 0.0;
		float lace = 0.0;
		float foam = 0.0;
		if (wet_tiles > 0.5) {
			float lag = 0.7 * value_noise(world * 0.1 + vec2(31.7, 4.2));
			run = motion_enabled ? fract(clock / wave_seconds + lag) : 0.8;
			up = smoothstep(0.3, 0.5, run) * (1.0 - smoothstep(0.5, 1.0, run));
			lace = smoothstep(0.32, 0.62, value_noise(world * 5.5 + vec2(lag * 3.0, 1.7)) * 0.6 + value_noise(world * 13.0 + vec2(4.4, lag)) * 0.4);
		}
		// How much of the point is under the sea: all of it on open water.
		float afloat = wet_tiles > 3.5 ? 1.0 : 0.0;
		vec3 surface;
		// Each corner's share of the final colour, for decals and the beach.
		vec4 share = vec4(1.0, 0.0, 0.0, 0.0);
		if (all(equal(slots, vec4(slots.x)))) {
			surface = ground_now(slots.x, world, clock);
		} else {
			// Each material's merged corner weight, its priority and its own
			// painted detail compete; the winner shows with a narrow soft zone.
			vec3 color[4];
			vec4 score;
			for (int i = 0; i < 4; i++) {
				color[i] = ground_now(slots[i], world, clock);
				float merged = dot(vec4(equal(slots, vec4(slots[i]))), corner);
				float height = (dot(color[i], vec3(0.299, 0.587, 0.114)) - average_luma(slots[i])) * (1.0 - is_water(slots[i]));
				score[i] = merged + border_priority[int(clamp(slots[i], 0.0, 15.0))] + height * height_strength;
				// At a shore the sea is laid over the land below, not blended with
				// it: the grounds compete among themselves.
				if (shore && wet_corner[i] > 0.5) {
					score[i] = -10.0;
					sea += color[i] * corner[i] / max(water, 0.0001);
				}
			}
			float best = max(max(score.x, score.y), max(score.z, score.w));
			share = max(score - vec4(best - blend_depth), vec4(0.0));
			share /= max(share.x + share.y + share.z + share.w, 0.0001);
			surface = color[0] * share.x + color[1] * share.y + color[2] * share.z + color[3] * share.w;
		}
		if (decals_enabled) {
			surface = decal_layer(world, max(fwidth(world.x), fwidth(world.y)), slots, share, surface).rgb;
		}
		// A coastal band, not new terrain: the same fog-safe four samples join
		// straight shores, concave inlets and diagonal islands. Nothing of the
		// land shows past the sand, and the sea covers the sand from the
		// waterline out.
		if (shore) {
			vec3 sand = ground(beach_slot, world);
			sand *= mix(vec3(1.0), vec3(0.68, 0.75, 0.78), smoothstep(shore_wet.x, shore_wet.y, water));
			surface = mix(surface, sand, smoothstep(shore_sand.x, shore_sand.y, water));
			float line = shore_sea.x - wave_runup * (up - 0.35);
			float waterline = smoothstep(line, line + shore_sea.y - shore_sea.x, water);
			float deep = smoothstep(shore_deep.x, shore_deep.y, water);
			surface = mix(surface, sea, waterline * mix(shore_shallow, 1.0, deep));
			afloat = waterline;
			// On the water's edge: thick as the wave breaks, thinning as it
			// drains, and left behind in patches on the backwash.
			foam = waterline * (1.0 - smoothstep(line + 0.03, line + 0.08 + 0.14 * up, water)) * mix(0.45, 1.0, up) * mix(0.3, 1.0, lace);
			float drain = smoothstep(0.5, 0.6, run) * (1.0 - smoothstep(0.6, 0.98, run));
			foam += waterline * (1.0 - smoothstep(line + 0.1, line + 0.3, water)) * drain * lace * 0.55;
		}
		// The crests coming in, by the distance out from the shore in tiles:
		// the wave that breaks, and a smaller one between two of them that
		// dies on the way.
		float coast = afloat > 0.0 && motion_enabled ? coast_share(sample_position + vec2(0.5), own_slot) : 1.0;
		if (coast < 0.9995) {
			float out_to_sea = 1.0 - sqrt(max(2.0 - 2.0 * coast, 0.0));
			float near = 1.0 - smoothstep(0.45, 0.8, out_to_sea);
			float reach = smoothstep(0.0, 0.5, run);
			float front = mix(wave_reach, 0.05, reach);
			float alive = smoothstep(0.02, 0.25, run) * (1.0 - smoothstep(0.46, 0.58, run)) * near * afloat;
			// A wave's lit face, then foam along its top that thickens as it nears the sand.
			surface += surface * exp(-pow((out_to_sea - front - 0.03) / 0.11, 2.0)) * alive * wave_face;
			float crest = exp(-pow((out_to_sea - front) / mix(0.03, 0.06, reach), 2.0)) * alive * mix(0.25, 1.0, reach);
			float run_b = fract(run + 0.5);
			float reach_b = smoothstep(0.0, 0.5, run_b);
			float front_b = mix(wave_reach, 0.4, reach_b);
			float alive_b = smoothstep(0.02, 0.2, run_b) * (1.0 - smoothstep(0.3, 0.5, run_b)) * near * afloat;
			surface += surface * exp(-pow((out_to_sea - front_b - 0.03) / 0.1, 2.0)) * alive_b * wave_face * 0.7;
			float crest_b = exp(-pow((out_to_sea - front_b) / 0.035, 2.0)) * alive_b * 0.35;
			foam += (crest * mix(0.2, 1.0, lace) + crest_b * lace) * wave_crest;
		}
		surface = mix(surface, vec3(0.93, 0.97, 0.96), clamp(foam, 0.0, 1.0) * wave_foam);
		surface = river_paint(surface, world, warp, clock);
		vec2 off_center = abs(from_center);
		surface = rock_void(surface, world, warp, smoothstep(0.05, 0.3, max(off_center.x, off_center.y)), own_void);
		COLOR = vec4(surface, 1.0);
	}
}
