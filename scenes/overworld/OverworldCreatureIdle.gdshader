shader_type canvas_item;
render_mode unshaded;

uniform float frame_count = 2.0;
uniform float frame_seconds = 0.6;
uniform float static_frame = 0.0;
uniform float phase = 0.0;
uniform bool motion_enabled = true;
uniform vec2 edge_uv = vec2(0.015);
uniform float clock_override = -1.0;
varying vec4 paint_tint;

void vertex() { paint_tint = COLOR; }

// The built-in TEXTURE is sampled only in fragment(): Godot cannot pass it into a
// user function on every renderer (the headless one reports a missing sampler).
vec2 pose_uv(vec2 uv, float frame, vec2 pixel_size) {
	vec2 half_pixel = pixel_size * vec2(frame_count, 1.0) * 0.5;
	vec2 sample_uv = clamp(uv, half_pixel, vec2(1.0) - half_pixel);
	sample_uv.x = (sample_uv.x + frame) / frame_count;
	return sample_uv;
}

float pose_inside(vec2 uv) {
	return step(0.0, uv.x) * step(0.0, uv.y) * step(uv.x, 1.0) * step(uv.y, 1.0);
}

void fragment() {
	float clock = (clock_override >= 0.0 ? clock_override : TIME) + phase;
	float frame = motion_enabled ? mod(floor(clock / frame_seconds), frame_count) : static_frame;
	vec4 body = texture(TEXTURE, pose_uv(UV, frame, TEXTURE_PIXEL_SIZE));
	body.a *= pose_inside(UV);
	float outer = body.a;
	float inner = body.a;
	for (int i = 0; i < 8; i++) {
		float angle = float(i) * 0.785398163;
		vec2 offset = vec2(cos(angle), sin(angle)) * edge_uv;
		vec2 outer_uv = UV + offset;
		vec2 inner_uv = UV + offset * 0.5;
		outer = max(outer, texture(TEXTURE, pose_uv(outer_uv, frame, TEXTURE_PIXEL_SIZE)).a * pose_inside(outer_uv));
		inner = max(inner, texture(TEXTURE, pose_uv(inner_uv, frame, TEXTURE_PIXEL_SIZE)).a * pose_inside(inner_uv));
	}
	// Same restrained alpha-following contrast as the static overworld actors.
	float dark_alpha = outer * 0.82;
	float light_alpha = inner * 0.55;
	float outline_alpha = light_alpha + dark_alpha * (1.0 - light_alpha);
	vec3 outline_rgb = vec3(0.94, 0.89, 0.73) * light_alpha + vec3(0.055, 0.065, 0.060) * dark_alpha * (1.0 - light_alpha);
	float alpha = body.a + outline_alpha * (1.0 - body.a);
	vec3 rgb = (body.rgb * body.a + outline_rgb * (1.0 - body.a)) / max(alpha, 0.0001);
	COLOR = vec4(rgb, alpha) * paint_tint;
}
