shader_type canvas_item;
render_mode unshaded;

#include "res://scenes/town/town_fx_common.gdshaderinc"

// The painted slag churns and its crust glow drifts downstream; rock and sky stay still.
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
	COLOR = vec4(rgb, base.a) * paint_tint;
}
