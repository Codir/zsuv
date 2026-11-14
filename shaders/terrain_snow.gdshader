shader_type spatial;
render_mode diffuse_lambert, specular_disabled;

#include "res://shaders/psx_inc.gdshaderinc"
#include "res://shaders/terrain_inc.gdshaderinc"

// Compaction (ruts): 513x513, 0.5 m per pixel.
uniform sampler2D track_tex : filter_linear, repeat_disable;
uniform sampler2D track_tex_px : filter_nearest, repeat_disable;
uniform float max_snow = 0.8;
uniform float max_mud = 0.4;
uniform vec3 layer_col = vec3(0.86, 0.9, 0.98);  // snow, or sand
uniform vec3 layer_packed_col = vec3(0.56, 0.6, 0.7);
uniform vec3 mud_col = vec3(0.3, 0.22, 0.14);
uniform vec3 mud_packed_col = vec3(0.17, 0.12, 0.08);

const float TRACK_N = 513.0;

varying vec3 world_pos;

void vertex() {
	vec3 wp = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	vec2 cell = wp.xz - tile_origin + T_HALF;
	vec4 s = textureLod(snow_tex, (cell + 0.5) / T_N, 0.0);
	float tr = textureLod(track_tex, (cell * 2.0 + 0.5) / TRACK_N, 0.0).r;
	float snow = s.r * max_snow * (1.0 - tr * 0.7);
	float mud = s.g * max_mud * (1.0 - tr * 0.35);
	// A thin layer (road, packed ruts) is sunk below the ground,
	// otherwise it z-fights with the ground mesh and flickers.
	float thick = max(snow, mud);
	float hide = 1.0 - smoothstep(0.06, 0.12, thick);
	VERTEX.y = t_height(cell) + thick - 0.05 - hide * 0.5;
	NORMAL = t_normal(cell);
	world_pos = vec3(wp.x, VERTEX.y, wp.z);
	POSITION = psx_snap(PROJECTION_MATRIX * MODELVIEW_MATRIX * vec4(VERTEX, 1.0));
}

void fragment() {
	vec2 cell = world_pos.xz - tile_origin + T_HALF;
	vec4 s = texture(snow_tex, (cell + 0.5) / T_N);
	float tr = texture(track_tex_px, (cell * 2.0 + 0.5) / TRACK_N).r;
	float n = psx_hash(floor(world_pos * 4.0));
	vec3 snow = mix(layer_col, layer_packed_col, tr);
	vec3 mud = mix(mud_col, mud_packed_col, tr);
	float mud_t = smoothstep(-0.05, 0.05, s.g * max_mud - s.r * max_snow);
	ALBEDO = mix(snow, mud, mud_t) * (0.92 + n * 0.16);
}
