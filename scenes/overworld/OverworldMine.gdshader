shader_type canvas_item;
render_mode unshaded;
uniform sampler2D parts_texture : filter_linear, repeat_disable;
uniform bool motion_enabled = true;
uniform float phase = 0.0;
uniform float clock_override = -1.0;
uniform vec2 chimney;
uniform int part_count = 0;
uniform vec4 part_0_rect;
uniform vec4 part_0_source;
uniform vec4 part_0_motion;
uniform vec2 part_0_rope;
uniform vec4 part_1_rect;
uniform vec4 part_1_source;
uniform vec4 part_1_motion;
uniform vec2 part_1_rope;
uniform vec4 part_2_rect;
uniform vec4 part_2_source;
uniform vec4 part_2_motion;
uniform vec2 part_2_rope;
uniform int light_count = 0;
uniform vec2 light_0;
uniform vec2 light_1;
uniform vec2 light_2;
uniform vec2 light_3;
varying vec4 paint_tint;
void vertex() { paint_tint = COLOR; }

vec4 over(vec4 back, vec4 front) {
	float alpha = front.a + back.a * (1.0 - front.a);
	return vec4((front.rgb * front.a + back.rgb * back.a * (1.0 - front.a)) / max(alpha, .00001), alpha);
}

vec4 machinery(vec4 back, vec2 uv, vec4 rect, vec4 source, vec4 motion, vec2 rope, float t) {
	vec2 travel = motion.zw * sin(t * motion.y);
	if (motion.x == 2.0 || motion.x == 3.0) rect.xy += travel;
	if (rope.x >= 0.0) {
		vec2 end = rect.xy + vec2(rect.z * .5, rect.w * .05);
		vec2 direction = end - rope;
		float along = clamp(dot(uv - rope, direction) / max(dot(direction, direction), .0001), 0.0, 1.0);
		float distance_to_rope = length((uv - rope - direction * along) * vec2(512.0, 640.0));
		back = over(back, vec4(.25, .20, .13, (1.0 - smoothstep(.6, 1.7, distance_to_rope)) * .96));
	}
	vec2 local = (uv - rect.xy) / rect.zw;
	vec2 original_local = local;
	if (motion.x == 1.0) {
		// Rotate the wheel in its own projected plane; its axle stays fixed.
		float angle = t * motion.y;
		vec2 p = local - .5;
		local = vec2(cos(angle) * p.x + sin(angle) * p.y, -sin(angle) * p.x + cos(angle) * p.y) + .5;
	} else if (motion.x == 4.0) {
		// Rope winds across the barrel; the timber bearing blocks stay stationary.
		float barrel = smoothstep(.20, .32, local.x) * (1.0 - smoothstep(.72, .81, local.x));
		local.y += sin(local.y * 22.0 + t * motion.y * 5.0) * .025 * barrel;
	}
	float inside = step(0.0, local.x) * step(0.0, local.y) * step(local.x, 1.0) * step(local.y, 1.0);
	vec2 half_pixel = vec2(.5 / 384.0, .5 / 128.0);
	vec4 pixel = texture(parts_texture, clamp(source.xy + local * source.zw, source.xy + half_pixel, source.xy + source.zw - half_pixel));
	pixel.a *= inside;
	if (motion.x == 1.0) {
		// The oblique outer rim and axle silhouette stay registered. Rotate the
		// painted spoke/blade face within it instead of wobbling the ellipse.
		vec4 fixed_rim = texture(parts_texture, clamp(source.xy + original_local * source.zw, source.xy + half_pixel, source.xy + source.zw - half_pixel));
		fixed_rim.a *= step(0.0, original_local.x) * step(0.0, original_local.y) * step(original_local.x, 1.0) * step(original_local.y, 1.0);
		pixel = mix(fixed_rim, pixel, 1.0 - smoothstep(.30, .43, length(original_local - .5)));
	}
	return over(back, pixel);
}

vec4 lamp(vec4 back, vec2 uv, vec2 point, float t, float seed) {
	float pulse = .72 + .16 * sin(t * 5.3 + seed) + .12 * sin(t * 9.7 + seed * 2.7);
	vec2 delta = (uv - point) * vec2(512.0, 640.0);
	float radius = length(delta);
	float glow = exp(-radius * radius / 170.0) * .24 * pulse;
	back = over(back, vec4(1.0, .49, .10, glow));
	return over(back, vec4(1.0, .83, .35, exp(-radius * radius / 9.0) * .55 * pulse));
}

void fragment() {
	float t = motion_enabled ? (clock_override >= 0.0 ? clock_override : TIME) + phase : 0.0;
	vec4 pixel = texture(TEXTURE, UV);
	if (part_count > 0) pixel = machinery(pixel, UV, part_0_rect, part_0_source, part_0_motion, part_0_rope, t);
	if (part_count > 1) pixel = machinery(pixel, UV, part_1_rect, part_1_source, part_1_motion, part_1_rope, t);
	if (part_count > 2) pixel = machinery(pixel, UV, part_2_rect, part_2_source, part_2_motion, part_2_rope, t);
	if (light_count > 0) pixel = lamp(pixel, UV, light_0, t, 1.3);
	if (light_count > 1) pixel = lamp(pixel, UV, light_1, t, 4.8);
	if (light_count > 2) pixel = lamp(pixel, UV, light_2, t, 8.1);
	if (light_count > 3) pixel = lamp(pixel, UV, light_3, t, 11.7);
	if (motion_enabled) {
		for (int i = 0; i < 7; i++) {
			float age = fract(t * .19 + float(i) / 7.0);
			vec2 center = chimney + vec2(age * .055 + sin(age * 6.0 + t * .32) * age * .017, -age * .205);
			vec2 d = (UV - center) * vec2(512.0, 640.0);
			float radius = 4.0 + age * 14.0;
			float wisps = .74 + .26 * sin(d.x * .24 + sin(d.y * .17 + t) * 2.0);
			float alpha = exp(-dot(d, d) / (radius * radius)) * smoothstep(0.0, .13, age) * (1.0 - age) * .40 * wisps;
			pixel = over(pixel, vec4(mix(vec3(.31, .29, .26), vec3(.62, .60, .56), age), alpha));
		}
	}
	COLOR = pixel * paint_tint;
}
