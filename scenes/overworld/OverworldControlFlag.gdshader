shader_type canvas_item;
render_mode unshaded;

uniform vec4 owner_color : source_color = vec4(0.62, 0.64, 0.67, 1.0);
varying vec4 tint;

void vertex() {
	tint = COLOR;
}

void fragment() {
	vec4 paint = texture(TEXTURE, UV);
	// The cloth is right of the pole. Keep its folds, pole and finial painted.
	float cloth = step(0.385, UV.x) * (1.0 - step(0.57, UV.y));
	float shade = dot(paint.rgb, vec3(0.299, 0.587, 0.114));
	vec3 dyed = owner_color.rgb * mix(0.32, 1.12, shade);
	COLOR = tint * vec4(mix(paint.rgb, dyed, cloth), paint.a);
}
