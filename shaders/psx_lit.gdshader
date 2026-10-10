shader_type spatial;
render_mode diffuse_lambert, specular_disabled;

#include "res://shaders/psx_inc.gdshaderinc"

uniform vec4 albedo : source_color = vec4(1.0);
uniform float emission_strength = 0.0;
uniform float noise_amount = 0.1;
uniform float noise_scale = 4.0;

varying vec3 local_pos;

void vertex() {
	local_pos = VERTEX;
	POSITION = psx_snap(PROJECTION_MATRIX * MODELVIEW_MATRIX * vec4(VERTEX, 1.0));
}

void fragment() {
	float n = psx_hash(floor(local_pos * noise_scale));
	ALBEDO = albedo.rgb * (1.0 + (n - 0.5) * 2.0 * noise_amount);
	EMISSION = albedo.rgb * emission_strength;
}
