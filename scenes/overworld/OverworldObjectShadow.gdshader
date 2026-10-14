shader_type canvas_item;
render_mode unshaded;

// A map object's own silhouette, softened, laid on the ground behind it
// (docs/overworld-soft-fog-and-shadows.md). The draw transform slants and squashes it;
// vertex alpha is the strength and vertex red scales the blur. UVs outside the texture read as empty, so
// the blur can spread past the sprite's edge.
uniform vec3 tone = vec3(0.03, 0.035, 0.05);
uniform float blur_px = 6.0;
// Only the explored part of an object casts, and only onto explored ground:
// a forest painting that runs into the fog lays no shadow of its hidden
// trees, and no shadow lands where the trees it falls among are not drawn.
// VERTEX is the unslanted position in the state layer, so it locates the
// casting texel; MODEL_MATRIX carries the slant, so it locates where it lands.
uniform bool mask_explored = false;
uniform sampler2D terrain_data : filter_nearest, repeat_disable;
uniform vec2 map_size = vec2(1.0);
uniform vec2 board_origin;
uniform vec2 tile_px = vec2(1.0);
uniform vec2 canvas_origin;
uniform vec2 canvas_world_origin;
uniform vec2 canvas_world_scale = vec2(1.0);
varying float strength;
varying float blur_scale;
varying vec2 source_world;
varying vec2 land_world;

void vertex() {
	strength = COLOR.a;
	blur_scale = COLOR.r;
	source_world = (VERTEX - board_origin) / tile_px;
	land_world = canvas_world_origin + ((MODEL_MATRIX * vec4(VERTEX, 0.0, 1.0)).xy - canvas_origin) * canvas_world_scale;
}

float explored(vec2 cell) {
	return step(0.75, texture(terrain_data, (clamp(cell, vec2(0.0), map_size - vec2(1.0)) + vec2(0.5)) / map_size).g);
}

// Bilinear explored share, so the cut follows the tile edge without a step.
float explored_share(vec2 world) {
	vec2 p = world - vec2(0.5);
	vec2 c = floor(p);
	vec2 f = fract(p);
	return mix(mix(explored(c), explored(c + vec2(1.0, 0.0)), f.x), mix(explored(c + vec2(0.0, 1.0)), explored(c + vec2(1.0)), f.x), f.y);
}

void fragment() {
	vec2 step_uv = fwidth(UV) * blur_px * blur_scale * 0.5;
	float coverage = 0.0;
	float total = 0.0;
	for (int j = -2; j <= 2; j++) {
		for (int i = -2; i <= 2; i++) {
			float w = exp(-float(i * i + j * j) / 4.5);
			vec2 q = UV + vec2(float(i), float(j)) * step_uv;
			float inside = step(0.0, q.x) * step(0.0, q.y) * step(q.x, 1.0) * step(q.y, 1.0);
			coverage += texture(TEXTURE, q).a * inside * w;
			total += w;
		}
	}
	float cast = strength * coverage / total;
	if (mask_explored) {
		cast *= smoothstep(0.25, 0.75, explored_share(source_world)) * smoothstep(0.25, 0.75, explored_share(land_world));
	}
	COLOR = vec4(tone, cast);
}
