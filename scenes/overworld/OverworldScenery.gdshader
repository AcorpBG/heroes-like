shader_type canvas_item;
render_mode unshaded;

uniform bool motion_enabled = true;
uniform int mode = 0;
uniform float strength = 0.0;
uniform float upper = 0.16;
uniform float anchor = 0.62;
uniform float phase = 0.0;
uniform float speed = 1.0;
uniform float ripple = 0.0;
uniform vec3 shine_color = vec3(1.0, 0.94, 0.72);
uniform float sparkle_strength = 0.0;
uniform vec4 scroll_region = vec4(0.0, 0.0, 1.0, 1.0);
uniform float scroll_glow_strength = 0.0;
uniform vec2 glint_0 = vec2(-10.0);
uniform vec2 glint_1 = vec2(-10.0);
uniform vec2 glint_2 = vec2(-10.0);
uniform vec4 source_region = vec4(0.0, 0.0, 1.0, 1.0);
uniform vec4 activity_region = vec4(0.0, 0.0, 1.0, 1.0);
uniform vec2 padding_uv = vec2(0.0);
uniform vec4 texture_region = vec4(0.0, 0.0, 1.0, 1.0);
// Deterministic frame inspection; negative means the normal engine clock.
uniform float clock_override = -1.0;
varying vec4 paint_tint;

void vertex() { paint_tint = COLOR; }

float metal_glint(vec2 uv, vec2 point, float time) {
	vec2 d = abs(uv - point);
	float pulse = pow(max(0.0, sin(time)), 12.0);
	float cross_light = exp(-d.x * 320.0 - d.y * 28.0) + exp(-d.y * 320.0 - d.x * 28.0);
	return cross_light * pulse;
}

void fragment() {
	vec2 local_uv = (UV - texture_region.xy) / texture_region.zw;
	vec2 uv = local_uv * (vec2(1.0) + 2.0 * padding_uv) - padding_uv;
	vec2 original = source_region.xy + uv * source_region.zw;
	float t = (clock_override >= 0.0 ? clock_override : TIME) + phase;
	vec2 half_pixel = TEXTURE_PIXEL_SIZE * 0.5 / texture_region.zw;
	vec4 base = texture(TEXTURE, texture_region.xy + clamp(uv, half_pixel, vec2(1.0) - half_pixel) * texture_region.zw);
	float brightness = 1.0;
	if (motion_enabled) {
		if (mode == 1 || mode == 2) {
			float canopy = 1.0 - smoothstep(upper, anchor, original.y);
			float breeze = sin(t * 1.45 * speed + original.x * ripple) * 0.72 + sin(t * 2.31 * speed + original.y * 4.0 + original.x * ripple * 0.6) * 0.28;
			uv.x -= strength * canopy * breeze / source_region.z;
		}
		vec2 area_uv = (original - activity_region.xy) / activity_region.zw;
		float area = step(0.0, area_uv.x) * step(0.0, area_uv.y) * step(area_uv.x, 1.0) * step(area_uv.y, 1.0);
		if (mode == 2) {
			// Only existing orange fire pixels respond; masonry stays rigid/dark.
			float flame = smoothstep(0.10, 0.36, base.r - base.b) * smoothstep(0.08, 0.30, base.r - base.g);
			brightness += area * flame * (0.45 * sin(t * 3.1) + 0.20 * sin(t * 7.3));
		} else if (mode == 3) {
			// Flow stays inside painted blue mill water, never the wooden machine.
			float water = smoothstep(0.08, 0.25, min(base.b, base.g) - base.r) * area;
			uv.y += water * strength * sin(t * 3.8 - original.y * 50.0) / source_region.w;
			brightness += water * 0.38 * sin(t * 3.8 - original.y * 50.0);
		} else if (mode == 4) {
			// Passing shade changes stone lighting slightly, never its silhouette.
			brightness -= strength * (0.5 + 0.5 * sin(t * 0.28 + original.x * 4.0 + original.y * 2.0));
		} else if (mode == 5) {
			// Existing warm lava fissures breathe; unpainted rock stays rigid.
			float hot = smoothstep(0.12, 0.38, base.r - max(base.g, base.b));
			brightness += strength * 6.0 * hot * (0.55 + 0.45 * sin(t * 1.8 + original.x * 7.0));
		}
	}
	vec4 pixel = texture(TEXTURE, texture_region.xy + clamp(uv, half_pixel, vec2(1.0) - half_pixel) * texture_region.zw);
	if (motion_enabled && (mode == 6 || mode == 7)) {
		// A reflection travels over the metal; geometry and alpha never change.
		float sweep = mix(-0.4, 2.0, fract(t * speed));
		float band = exp(-pow((original.x + original.y * 0.65 - sweep) / 0.065, 2.0));
		float metal = smoothstep(0.12, 0.65, max(pixel.r, max(pixel.g, pixel.b)));
		if (mode == 7) {
			// Only the contents catch light; the chest and its lid stay rigid.
			vec2 gold_uv = (original - activity_region.xy) / activity_region.zw;
			float gold_area = step(0.0, gold_uv.x) * step(0.0, gold_uv.y) * step(gold_uv.x, 1.0) * step(gold_uv.y, 1.0);
			metal *= gold_area * smoothstep(0.15, 0.45, pixel.r - pixel.b);
			vec2 scroll_uv = (original - scroll_region.xy) / scroll_region.zw;
			float scroll_area = (1.0 - smoothstep(0.30, 0.52, abs(scroll_uv.x - 0.5))) * (1.0 - smoothstep(0.32, 0.52, abs(scroll_uv.y - 0.5)));
			float parchment = smoothstep(0.3, 0.65, pixel.g) * smoothstep(0.2, 0.5, pixel.b);
			float glow = (0.5 + 0.5 * sin(t * 2.1)) * scroll_area * parchment * scroll_glow_strength;
			pixel.rgb = mix(pixel.rgb, vec3(1.0, 0.93, 0.72), glow);
		}
		float glints = metal_glint(original, glint_0, t * 1.7)
			+ metal_glint(original, glint_1, t * 1.7 + 2.1)
			+ metal_glint(original, glint_2, t * 1.7 + 4.2);
		pixel.rgb = mix(pixel.rgb, shine_color, clamp(band * strength * metal + glints * sparkle_strength, 0.0, 0.95));
	}
	if (motion_enabled && mode == 8) {
		// A whirlpool turns fast at its eye and not at all at its rim, so the
		// painted outline stays where it meets the sea. activity_region is the
		// oval of the swirl around the eye; upper and anchor are the distances
		// from the eye (1 = the oval's edge) where the turning starts to slow and
		// where it stops. Water turning at different rates would wind the
		// painting up without end, so two copies are shown, each wound a little
		// behind and then a little ahead of the painting, one fading in while the
		// other fades out. The cycle divides the hour TIME wraps at.
		const float cycle = 1.5;
		vec2 radii = activity_region.zw * 0.5;
		vec2 eye = activity_region.xy + radii;
		vec2 from_eye = (original - eye) / radii;
		float reach = length(from_eye);
		float pull = 1.0 - smoothstep(upper, anchor, reach);
		// Positive speed turns the water clockwise on screen. The cube keeps
		// the outer foam and driftwood nearly in place: what moves far between
		// the two copies shows double while they cross.
		float wind = -speed * cycle * pull * pull * pull;
		// Staggered around the swirl, so it never blurs and clears as a whole.
		float stagger = 0.16 * sin(atan(from_eye.y, from_eye.x) * 2.0 + reach * 6.0);
		float first = fract(t / cycle + stagger);
		float second = fract(first + 0.5);
		vec4 wound = vec4(0.0);
		for (int copy = 0; copy < 2; copy++) {
			float turn = wind * ((copy == 0 ? first : second) - 0.5);
			vec2 turned = mat2(vec2(cos(turn), sin(turn)), vec2(-sin(turn), cos(turn))) * from_eye;
			vec2 turned_uv = (eye + turned * radii - source_region.xy) / source_region.zw;
			float held = step(0.0, turned_uv.x) * step(0.0, turned_uv.y) * step(turned_uv.x, 1.0) * step(turned_uv.y, 1.0);
			vec4 copy_pixel = texture(TEXTURE, texture_region.xy + clamp(turned_uv, half_pixel, vec2(1.0) - half_pixel) * texture_region.zw);
			float share = copy == 0 ? 1.0 - abs(2.0 * first - 1.0) : abs(2.0 * first - 1.0);
			wound += vec4(copy_pixel.rgb * copy_pixel.a, copy_pixel.a) * held * share;
		}
		pixel = vec4(wound.rgb / max(wound.a, 0.0001), wound.a);
	}
	float inside = step(0.0, uv.x) * step(0.0, uv.y) * step(uv.x, 1.0) * step(uv.y, 1.0);
	COLOR = vec4(pixel.rgb * brightness, pixel.a * inside) * paint_tint;
}
