shader_type canvas_item;
render_mode unshaded;

#include "res://scenes/town/town_fx_common.gdshaderinc"

// Fire light in the building layers (windows, furnace mouths, torches) flickers.
uniform bool motion_enabled = true;
// Deterministic frame inspection; negative means the normal engine clock.
uniform float clock_override = -1.0;
uniform float window_strength = 0.0;
uniform float flicker_gain = 0.22;
// Screen pixels per flicker cell, so neighbouring windows flicker apart.
uniform float cell_px = 38.0;

varying vec4 paint_tint;

void vertex() {
	paint_tint = COLOR;
}

void fragment() {
	vec4 base = texture(TEXTURE, UV);
	vec3 rgb = base.rgb;
	float fire = town_fire_light(base.rgb) * window_strength;
	if (motion_enabled && fire > 0.001) {
		float t = clock_override >= 0.0 ? clock_override : TIME;
		vec2 cell = FRAGCOORD.xy / cell_px;
		float slow = town_noise(cell + vec2(t * 0.65, -t * 0.45));
		float quick = town_noise(cell * 1.7 + vec2(-t * 2.7, t * 2.2));
		float flicker = (slow - 0.5) * 1.3 + (quick - 0.5) * 0.7;
		rgb *= 1.0 + flicker_gain * fire * flicker * 2.0;
	}
	COLOR = vec4(rgb, base.a) * paint_tint;
}
