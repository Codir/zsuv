shader_type spatial;
render_mode diffuse_lambert, specular_disabled;

#include "res://shaders/psx_inc.gdshaderinc"
#include "res://shaders/terrain_inc.gdshaderinc"

varying vec3 world_pos;

void vertex() {
	vec3 wp = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	vec2 cell = wp.xz + T_HALF;
	VERTEX.y = t_height(cell);
	NORMAL = t_normal(cell);
	world_pos = vec3(wp.x, VERTEX.y, wp.z);
	POSITION = psx_snap(PROJECTION_MATRIX * MODELVIEW_MATRIX * vec4(VERTEX, 1.0));
}

void fragment() {
	vec4 s = texture(snow_tex, (world_pos.xz + T_HALF + 0.5) / T_N);
	float n = psx_hash(floor(world_pos * 2.0));
	vec3 earth = vec3(0.2, 0.15, 0.11);
	vec3 gravel = vec3(0.36, 0.34, 0.31);
	ALBEDO = mix(earth, gravel, s.b) * (0.85 + n * 0.3);
}
