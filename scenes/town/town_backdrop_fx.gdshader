shader_type canvas_item;
render_mode unshaded;

#include "res://scenes/town/town_fx_common.gdshaderinc"

// The painted slag churns and its crust glow drifts downstream; rock and sky stay still.
// A scene with an effect mask also has water that sways and glitters, falls that stream
// down, mist that drifts and lamps that flicker, each only where the mask puts it.
uniform bool motion_enabled = true;
// Deterministic frame inspection; negative means the normal engine clock.
uniform float clock_override = -1.0;
uniform float slag_strength = 0.0;
// How far slag pixels wander, in backdrop pixels.
uniform float churn_px = 1.6;
// Brightness swing of the drifting crust.
uniform float glow_gain = 0.32;
// Downstream, in backdrop pixels per second: the river runs from the upper right to the lower left.
uniform vec2 flow_px = vec2(-11.0, 6.5);
// The scene's water (red), falls (green), land with what stands on it (blue) and how thick the
// drifting fog is (alpha, from 1 for none to 255); nothing without one.
uniform sampler2D fx_mask : hint_default_transparent, filter_linear, repeat_disable;
uniform float water_strength = 0.0;
// Largest sway of the painted water, in backdrop pixels.
uniform float ripple_px = 1.1;
// Brightness swing of the light on the water.
uniform float glint_gain = 0.45;
uniform float falls_strength = 0.0;
// How fast the falling water runs, in backdrop pixels per second.
uniform float fall_speed = 42.0;
uniform float mist_strength = 0.0;
// The wind that carries the fog, in backdrop pixels per second: down the slopes to the water,
// the way the painted wisps lie.
uniform vec2 mist_wind = vec2(-20.0, 7.9);
// The drifting fog's colour, a little lighter than the painted fog so its cores read as fog;
// how far its thickest parts cover what lies under them; how much the painted fog thins out of
// its banks.
uniform vec3 mist_color : source_color = vec3(0.47, 0.48, 0.57);
uniform float mist_gain = 0.75;
uniform float mist_thin = 0.15;
// The streamers' shape: their length and thickness as multiples of the bell fjord's long thin
// wisps (1, 1); a thicker, shorter shape drifts as soft patches. And how soft their edges are:
// 0 keeps the wisps' crisp edges and fine strands, 1 blends them out into haze.
uniform vec2 mist_shape = vec2(1.0, 1.0);
uniform float mist_soft = 0.0;
uniform float lantern_strength = 0.0;
uniform float lantern_gain = 0.24;
// Screen pixels per flicker cell, so neighbouring lamps flicker apart.
uniform float lantern_cell_px = 34.0;

// Seconds the falling paint slides before it starts over.
const float FALL_PHASE = 0.45;

varying vec4 paint_tint;

void vertex() {
	paint_tint = COLOR;
}

void fragment() {
	vec4 base = texture(TEXTURE, UV);
	vec3 rgb = base.rgb;
	float hot = town_slag(base.rgb) * slag_strength;
	if (motion_enabled && hot > 0.001) {
		float t = clock_override >= 0.0 ? clock_override : TIME;
		vec2 p = UV / TEXTURE_PIXEL_SIZE;
		vec2 q = (p - flow_px * t) / 46.0;
		// Churn: slag pixels wander a little, boiling in place as the pattern drifts.
		vec2 wander = vec2(town_fbm(q + vec2(0.0, t * 0.22)), town_fbm(q + vec2(5.2, 1.3) - vec2(t * 0.18, 0.0))) - 0.5;
		vec4 moved = texture(TEXTURE, UV + wander * 2.0 * churn_px * TEXTURE_PIXEL_SIZE);
		// Only slag moves into slag: the dark bank never smears into the river.
		rgb = mix(rgb, moved.rgb, clamp(hot * town_slag(moved.rgb) * 2.0, 0.0, 1.0));
		// Crust: brighter and darker patches drift downstream, a little faster than the churn.
		// Hot patches flare more than cooler crust darkens, so the river stays as bright overall.
		float crust = (town_fbm((p - flow_px * t * 1.5) / 24.0 + vec2(t * 0.05, 0.0)) - 0.5) * 2.0;
		rgb *= 1.0 + glow_gain * hot * (crust > 0.0 ? crust : crust * 0.5);
		rgb += vec3(0.07, 0.035, 0.0) * hot * max(crust, 0.0);
	}
	if (motion_enabled && water_strength + falls_strength + mist_strength + lantern_strength > 0.0) {
		float t = clock_override >= 0.0 ? clock_override : TIME;
		vec2 p = UV / TEXTURE_PIXEL_SIZE;
		vec4 mask = texture(fx_mask, UV);
		float water = mask.r * water_strength;
		if (water > 0.001) {
			// The water sways a pixel or so in bands that roll toward the shore, so the
			// reflections and the sunset's path waver. Only water moves into water.
			float band = p.y * 0.45 - t * 1.7 + town_noise(p * vec2(0.010, 0.04) + vec2(t * 0.12, 0.0)) * 5.0;
			vec2 moved = UV + vec2(sin(band), 0.3 * sin(band * 0.6 + 1.7)) * ripple_px * TEXTURE_PIXEL_SIZE;
			rgb = mix(rgb, texture(TEXTURE, moved).rgb, clamp(water * texture(fx_mask, moved).r, 0.0, 1.0));
			// Light on the water glitters: bright paint flares in small, quick patches.
			float bright = smoothstep(0.38, 0.72, dot(rgb, vec3(0.3, 0.59, 0.11)));
			float glint = town_noise(vec2(p.x * 0.20 + t * 0.6, p.y * 0.85 - t * 1.3))
					* town_noise(vec2(p.x * 0.47 - t * 0.9, p.y * 1.5 + t * 0.4));
			rgb *= 1.0 + glint_gain * water * bright * (smoothstep(0.25, 0.65, glint) * 1.6 - 0.45);
		}
		float falls = mask.g * falls_strength;
		if (falls > 0.001) {
			// The falls stream down: the painting slides down and starts over, in two phases
			// crossfaded so the restart never shows. Only falls move into falls.
			float phase = fract(t / FALL_PHASE);
			float slide = fall_speed * FALL_PHASE;
			vec2 uv0 = UV - vec2(0.0, phase * slide) * TEXTURE_PIXEL_SIZE;
			vec2 uv1 = UV - vec2(0.0, fract(phase + 0.5) * slide) * TEXTURE_PIXEL_SIZE;
			float w0 = 1.0 - abs(2.0 * phase - 1.0);
			float m0 = texture(fx_mask, uv0).g * w0;
			float m1 = texture(fx_mask, uv1).g * (1.0 - w0);
			vec3 stream = texture(TEXTURE, uv0).rgb * m0 + texture(TEXTURE, uv1).rgb * m1 + rgb * (1.0 - m0 - m1);
			rgb = mix(rgb, stream, falls);
			// Streaks of white water run down faster than the paint slides.
			float streak = town_noise(vec2(p.x * 0.42, (p.y - t * fall_speed * 1.6) * 0.07));
			rgb *= 1.0 + 0.22 * falls * (streak - 0.5) * 2.0;
		}
		// How thick the drifting fog is here: alpha from 1 (none) to 255, so no import step treats
		// the mask as see-through.
		float fog = clamp((mask.a * 255.0 - 1.0) / 254.0, 0.0, 1.0) * mist_strength;
		if (fog > 0.01) {
			// Streamers of fog ride the wind down the slopes, long and thin like the painted wisps
			// and gathered in drifting banks, slowly changing shape as they go.
			vec2 along = normalize(mist_wind);
			vec2 across = vec2(-along.y, along.x);
			vec2 w = vec2(dot(p, along) - length(mist_wind) * t, dot(p, across));
			vec2 warp = vec2(town_noise(w / (vec2(380.0, 90.0) * mist_shape) + vec2(0.0, t * 0.04)),
					town_noise(w / (vec2(380.0, 90.0) * mist_shape) + vec2(5.3, -t * 0.03))) - 0.5;
			vec2 sw = w + warp * vec2(120.0, 26.0) * mist_shape;
			float streak = town_noise(sw / (vec2(150.0, 22.0) * mist_shape)) * 0.65
					+ town_noise(sw / (vec2(70.0, 11.0) * mist_shape) + vec2(9.1, 2.7)) * 0.35;
			float bank = smoothstep(0.30, 0.70, town_noise(w / vec2(700.0, 240.0) + vec2(t * 0.01, 1.3)));
			// Fine strands within each streamer, as the painted wisps have; soft haze has none.
			float strands = mix(town_noise(sw / (vec2(60.0, 5.0) * mist_shape) + vec2(3.3, 7.7)), 1.0, mist_soft);
			float density = smoothstep(mix(0.52, 0.36, mist_soft), mix(0.80, 0.96, mist_soft), streak)
					* mix(0.3, 1.0, bank) * mix(0.55, 1.0, strands);
			float painted_fog = town_mist(rgb);
			rgb = mix(rgb, mist_color, clamp(fog * density * mist_gain, 0.0, 1.0));
			// Out of the banks the painted fog thins, so it seems to move with them.
			rgb *= 1.0 - fog * (1.0 - bank) * painted_fog * mist_thin;
		}
		float lamp = town_lantern_light(rgb) * mask.b * lantern_strength;
		if (lamp > 0.001) {
			rgb *= 1.0 + lantern_gain * lamp * town_flicker(FRAGCOORD.xy, t, lantern_cell_px) * 2.0;
		}
	}
	COLOR = vec4(rgb, base.a) * paint_tint;
}
