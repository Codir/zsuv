// Terrain heightmap access (257x257, 1 m between vertices).

uniform sampler2D height_tex : filter_nearest, repeat_disable;
uniform sampler2D snow_tex : filter_linear, repeat_disable;

const float T_HALF = 128.0;
const float T_N = 257.0;

float t_h(ivec2 c) {
	c = clamp(c, ivec2(0), ivec2(256));
	return texelFetch(height_tex, c, 0).r;
}

float t_height(vec2 cell) {
	vec2 fl = floor(cell);
	ivec2 i = ivec2(fl);
	vec2 f = cell - fl;
	float a = t_h(i);
	float b = t_h(i + ivec2(1, 0));
	float c = t_h(i + ivec2(0, 1));
	float d = t_h(i + ivec2(1, 1));
	return mix(mix(a, b, f.x), mix(c, d, f.x), f.y);
}

vec3 t_normal(vec2 cell) {
	float l = t_height(cell - vec2(1.0, 0.0));
	float r = t_height(cell + vec2(1.0, 0.0));
	float zm = t_height(cell - vec2(0.0, 1.0));
	float zp = t_height(cell + vec2(0.0, 1.0));
	return normalize(vec3(l - r, 2.0, zm - zp));
}
