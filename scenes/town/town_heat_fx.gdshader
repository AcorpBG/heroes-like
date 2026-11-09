shader_type canvas_item;
render_mode unshaded;

#include "res://scenes/town/town_fx_common.gdshaderinc"

// Drawn over the town as the backdrop's region, so TEXTURE tells where the slag is:
// heat haze shimmers over the slag and a few embers rise from it.
uniform sampler2D screen_texture : hint_screen_texture, repeat_disable, filter_linear;
uniform bool motion_enabled = true;
// Deterministic frame inspection; negative means the normal engine clock.
uniform float clock_override = -1.0;
uniform float haze_strength = 0.0;
// Largest shimmer, in screen pixels.
uniform float haze_px = 1.4;
// The haze hangs this many backdrop pixels above the slag.
uniform float haze_rise = 24.0;
uniform float ember_strength = 0.0;
// Share of cells over the slag that send up an ember.
uniform float ember_density = 0.12;

const float EMBER_CELL = 28.0;

float heat(sampler2D backdrop, vec2 uv, vec2 px) {
	// The slag around this point, smoothed, so the haze hangs over the river, not only on it.
	float h = 0.0;
	for (int i = -1; i <= 1; i++) {
		for (int j = -1; j <= 1; j++) {
			h += town_slag(texture(backdrop, uv + vec2(float(i), float(j)) * px * 14.0).rgb);
		}
	}
	return h / 9.0;
}

vec3 embers(sampler2D backdrop, vec2 p, float t, vec2 px) {
	// p in backdrop pixels. Each ember starts in a cell over the slag and rises
	// over several cells, so look at the cells below and beside this point.
	vec2 cell = floor(p / EMBER_CELL);
	vec3 glow = vec3(0.0);
	for (int dy = 0; dy <= 6; dy++) {
		for (int dx = -1; dx <= 1; dx++) {
			vec2 c = cell + vec2(float(dx), float(dy));
			float pick = town_hash(c * 1.37 + 11.0);
			if (pick > ember_density) {
				continue;
			}
			vec2 spawn = (c + vec2(town_hash(c + 3.1), town_hash(c + 7.7))) * EMBER_CELL;
			if (town_slag(texture(backdrop, spawn * px).rgb) < 0.5) {
				continue;
			}
			float life = 4.0 + town_hash(c + 1.9) * 3.0;
			float age = fract(t / life + town_hash(c + 5.3));
			float rise = (90.0 + town_hash(c + 2.2) * 80.0) * age;
			vec2 position = spawn + vec2(sin(age * 5.0 + pick * 60.0) * 6.0 * age, -rise);
			float radius = 0.9 + town_hash(c + 9.1) * 1.0;
			float core = 1.0 - smoothstep(radius * 0.4, radius * 1.7, length(p - position));
			float fade = smoothstep(0.0, 0.06, age) * (1.0 - smoothstep(0.45, 1.0, age));
			glow += mix(vec3(1.0, 0.82, 0.42), vec3(0.95, 0.30, 0.06), age) * core * fade;
		}
	}
	return glow;
}

void fragment() {
	float t = clock_override >= 0.0 ? clock_override : TIME;
	vec2 offset = vec2(0.0);
	if (motion_enabled && haze_strength > 0.0) {
		float h = heat(TEXTURE, UV + vec2(0.0, haze_rise) * TEXTURE_PIXEL_SIZE, TEXTURE_PIXEL_SIZE);
		vec2 p = UV / TEXTURE_PIXEL_SIZE;
		float wave = sin(p.y * 0.55 - t * 3.0 + sin(p.x * 0.07 + t * 0.8) * 2.0) * 0.65
				+ sin(p.y * 0.9 - t * 4.4 + p.x * 0.05) * 0.35;
		offset = vec2(wave, wave * 0.35) * haze_px * h * haze_strength * SCREEN_PIXEL_SIZE;
	}
	vec3 rgb = texture(screen_texture, SCREEN_UV + offset).rgb;
	if (motion_enabled && ember_strength > 0.0) {
		rgb += embers(TEXTURE, UV / TEXTURE_PIXEL_SIZE, t, TEXTURE_PIXEL_SIZE) * ember_strength;
	}
	COLOR = vec4(rgb, 1.0);
}
