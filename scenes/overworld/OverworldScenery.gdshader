shader_type canvas_item;
render_mode unshaded;

uniform bool motion_enabled = true;
uniform int mode = 0;
uniform float strength = 0.0;
uniform float upper = 0.16;
uniform float anchor = 0.62;
uniform float phase = 0.0;
uniform vec4 source_region = vec4(0.0, 0.0, 1.0, 1.0);
uniform vec4 activity_region = vec4(0.0, 0.0, 1.0, 1.0);
uniform vec2 padding_uv = vec2(0.0);
uniform vec4 texture_region = vec4(0.0, 0.0, 1.0, 1.0);
// Deterministic frame inspection; negative means the normal engine clock.
uniform float clock_override = -1.0;
varying vec4 paint_tint;

void vertex() { paint_tint = COLOR; }

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
			float breeze = sin(t * 0.85) * 0.72 + sin(t * 1.43 + original.y * 4.0) * 0.28;
			uv.x -= strength * canopy * canopy * breeze / source_region.z;
		}
		vec2 area_uv = (original - activity_region.xy) / activity_region.zw;
		float area = step(0.0, area_uv.x) * step(0.0, area_uv.y) * step(area_uv.x, 1.0) * step(area_uv.y, 1.0);
		if (mode == 2) {
			// Only existing orange fire pixels respond; masonry stays rigid/dark.
			float flame = smoothstep(0.10, 0.36, base.r - base.b) * smoothstep(0.08, 0.30, base.r - base.g);
			brightness += area * flame * (0.18 * sin(t * 3.1) + 0.08 * sin(t * 7.3));
		} else if (mode == 3) {
			// Flow stays inside painted blue mill water, never the wooden machine.
			float water = smoothstep(0.08, 0.25, min(base.b, base.g) - base.r) * area;
			uv.y += water * strength * sin(t * 2.2 - original.y * 50.0) / source_region.w;
			brightness += water * 0.16 * sin(t * 2.2 - original.y * 50.0);
		}
	}
	vec4 pixel = texture(TEXTURE, texture_region.xy + clamp(uv, half_pixel, vec2(1.0) - half_pixel) * texture_region.zw);
	float inside = step(0.0, uv.x) * step(0.0, uv.y) * step(uv.x, 1.0) * step(uv.y, 1.0);
	COLOR = vec4(pixel.rgb * brightness, pixel.a * inside) * paint_tint;
}
