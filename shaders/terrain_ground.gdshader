shader_type spatial;
render_mode diffuse_lambert, specular_disabled;

#include "res://shaders/psx_inc.gdshaderinc"
#include "res://shaders/terrain_inc.gdshaderinc"

uniform vec3 earth_col = vec3(0.2, 0.15, 0.11);
uniform vec3 gravel_col = vec3(0.36, 0.34, 0.31);
uniform vec3 ice_col = vec3(0.62, 0.74, 0.82);
// Earthworks (docs/plan.md §4): 513x513, 0.5 m a pixel. R loose earth, G gravel spread, B bare earth.
uniform sampler2D works_tex : filter_linear, repeat_disable;
uniform vec3 fresh_col = vec3(0.36, 0.25, 0.15);  // earth just dug
uniform vec3 spread_col = vec3(0.5, 0.49, 0.46);  // gravel spread

varying vec3 world_pos;

void vertex() {
	vec3 wp = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	vec2 cell = wp.xz - tile_origin + T_HALF;
	VERTEX.y = t_height(cell);
	NORMAL = t_normal(cell);
	world_pos = vec3(wp.x, VERTEX.y, wp.z);
	POSITION = psx_snap(PROJECTION_MATRIX * MODELVIEW_MATRIX * vec4(VERTEX, 1.0));
}

void fragment() {
	vec4 s = texture(snow_tex, (world_pos.xz - tile_origin + T_HALF + 0.5) / T_N);
	float n = psx_hash(floor(world_pos * 2.0));
	vec4 w = texture(works_tex, ((world_pos.xz - tile_origin + T_HALF) * 2.0 + 0.5) / 513.0);
	vec3 ground = mix(earth_col, gravel_col, s.b);
	ground = mix(ground, fresh_col, max(w.b, w.r * 0.8));
	ground = mix(ground, spread_col, w.g);
	ground *= 0.85 + n * 0.3;
	// Ice on a frozen lake: smooth, a little lighter in streaks.
	vec3 ice = ice_col * (0.95 + psx_hash(floor(world_pos * 0.5)) * 0.1);
	ALBEDO = mix(ground, ice, 1.0 - s.a);
}
