// Shared by the town stage effects: hashed value noise and masks of painted light.

float town_hash(vec2 p) {
	vec3 p3 = fract(vec3(p.xyx) * 0.1031);
	p3 += dot(p3, p3.yzx + 33.33);
	return fract((p3.x + p3.y) * p3.z);
}

float town_noise(vec2 p) {
	vec2 i = floor(p);
	vec2 f = fract(p);
	vec2 u = f * f * (3.0 - 2.0 * f);
	return mix(mix(town_hash(i), town_hash(i + vec2(1.0, 0.0)), u.x),
			mix(town_hash(i + vec2(0.0, 1.0)), town_hash(i + vec2(1.0, 1.0)), u.x), u.y);
}

float town_fbm(vec2 p) {
	float value = 0.0;
	float amplitude = 0.5;
	for (int i = 0; i < 3; i++) {
		value += amplitude * town_noise(p);
		p = p * 2.03 + vec2(17.0, 9.0);
		amplitude *= 0.5;
	}
	return value / 0.875;
}

// Molten slag as the backdrop paints it: hot orange to yellow, far redder than blue.
// The dusk sky is orange too, but greyer, so it stays out.
float town_slag(vec3 c) {
	return smoothstep(0.30, 0.55, c.r - c.b) * smoothstep(0.55, 0.85, c.r) * smoothstep(0.12, 0.30, c.g);
}

// Fire light in windows, furnace mouths and torches: bright orange, not cream or brass.
float town_fire_light(vec3 c) {
	return smoothstep(0.35, 0.60, c.r - c.b) * smoothstep(0.14, 0.30, c.r - c.g) * smoothstep(0.62, 0.90, c.r);
}

// Lamp light painted paler than fire: warm amber to cream, in windows, lanterns and their reflections.
float town_lantern_light(vec3 c) {
	return smoothstep(0.18, 0.34, c.r - c.b) * smoothstep(0.04, 0.12, c.r - c.g) * smoothstep(0.50, 0.80, c.r);
}

// Painted mist and cloud: light, cool and nearly grey.
float town_mist(vec3 c) {
	float spread = max(max(c.r, c.g), c.b) - min(min(c.r, c.g), c.b);
	return smoothstep(0.26, 0.44, dot(c, vec3(0.3, 0.59, 0.11))) * (1.0 - smoothstep(0.10, 0.22, spread))
			* smoothstep(-0.06, 0.02, c.b - c.r);
}

// A lamp's flicker, -1 to 1: slow swells and quick tremors, apart from one cell of the screen to the next.
float town_flicker(vec2 frag, float t, float cell_px) {
	vec2 cell = frag / cell_px;
	float slow = town_noise(cell + vec2(t * 0.55, -t * 0.40));
	float quick = town_noise(cell * 1.7 + vec2(-t * 2.4, t * 2.0));
	return (slow - 0.5) * 1.3 + (quick - 0.5) * 0.7;
}
