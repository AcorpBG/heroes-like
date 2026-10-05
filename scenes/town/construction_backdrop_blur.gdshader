shader_type canvas_item;

// Soft blur for the faction backdrop behind the full-screen construction
// board. Fixed taps keep it renderer-agnostic (no screen texture or mipmaps).
uniform float radius_px = 7.0;
uniform vec4 tint : source_color = vec4(0.34, 0.35, 0.37, 1.0);

void fragment() {
	vec2 px = TEXTURE_PIXEL_SIZE * radius_px;
	vec4 sum = texture(TEXTURE, UV) * 4.0;
	float weight = 4.0;
	for (int ring = 1; ring <= 2; ring++) {
		float r = float(ring);
		float w = 3.0 - r;
		for (int i = 0; i < 8; i++) {
			float a = float(i) * 0.785398 + r * 0.3927;
			sum += texture(TEXTURE, UV + vec2(cos(a), sin(a)) * px * r) * w;
			weight += w;
		}
	}
	COLOR = vec4((sum / weight).rgb * tint.rgb, 1.0);
}
