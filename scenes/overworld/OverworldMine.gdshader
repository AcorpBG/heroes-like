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
	// Readable at adventure-map scale: the flame lights the doorway as well
	// as its tiny painted glass. Different lamps swell and gutter independently.
	float pulse = .55 + .27 * sin(t * (3.2 + seed * .035) + seed) + .18 * sin(t * 7.9 + seed * 2.7);
	vec2 delta = (uv - point) * vec2(512.0, 640.0);
	float radius = length(delta);
	float glow = exp(-radius * radius / 490.0) * (1.0 - smoothstep(32.0, 48.0, radius)) * .68 * pulse;
	back = over(back, vec4(1.0, .48, .08, glow));
	return over(back, vec4(1.0, .88, .46, exp(-radius * radius / 24.0) * (.22 + .74 * pulse)));
}

vec4 chimney_smoke(vec4 back, vec2 uv, float t) {
	// Overlapping billows make a continuous, legible plume. A darker fringe
	// preserves contrast on pale ground; soft ash-grey cores show against grass.
	for (int i = 0; i < 10; i++) {
		float age = fract(t * .22 + float(i) / 10.0);
		float curl = sin(age * 8.0 + t * .65 + float(i) * 1.7);
		vec2 center = chimney + vec2(age * 32.0 + curl * age * 12.0, -age * 150.0) / vec2(512.0, 640.0);
		vec2 d = (uv - center) * vec2(512.0, 640.0);
		float radius = 7.0 + age * 25.0;
		float shape = exp(-dot(d, d * vec2(1.0, .74)) / (radius * radius));
		float wisps = .82 + .18 * sin(d.x * .19 + sin(d.y * .16 + t) * 2.0);
		float lifetime = smoothstep(0.0, .055, age) * (1.0 - smoothstep(.60, 1.0, age));
		back = over(back, vec4(.25, .24, .22, shape * lifetime * .30));
		float core = pow(shape, 1.5) * lifetime * .76 * wisps;
		back = over(back, vec4(mix(vec3(.62, .59, .54), vec3(.78, .76, .71), age), core));
	}
	return back;
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
	if (motion_enabled) pixel = chimney_smoke(pixel, UV, t);
	COLOR = pixel * paint_tint;
}
