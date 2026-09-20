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
	if (motion_enabled && mode == 6) {
		// A reflection travels over the metal; geometry and alpha never change.
		float sweep = mix(-0.4, 2.0, fract(t * speed));
		float band = exp(-pow((original.x + original.y * 0.65 - sweep) / 0.065, 2.0));
		float metal = smoothstep(0.12, 0.65, max(pixel.r, max(pixel.g, pixel.b)));
		float glints = metal_glint(original, glint_0, t * 1.7)
			+ metal_glint(original, glint_1, t * 1.7 + 2.1)
			+ metal_glint(original, glint_2, t * 1.7 + 4.2);
		pixel.rgb = mix(pixel.rgb, shine_color, clamp(band * strength * metal + glints * sparkle_strength, 0.0, 0.95));
	}
	float inside = step(0.0, uv.x) * step(0.0, uv.y) * step(uv.x, 1.0) * step(uv.y, 1.0);
	COLOR = vec4(pixel.rgb * brightness, pixel.a * inside) * paint_tint;
}
