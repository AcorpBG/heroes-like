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
