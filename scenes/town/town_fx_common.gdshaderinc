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
