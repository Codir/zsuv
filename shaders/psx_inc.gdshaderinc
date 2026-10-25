// Shared PSX functions: vertices snapped to a screen grid, and cheap noise.

const vec2 PSX_SNAP_RES = vec2(160.0, 90.0);

vec4 psx_snap(vec4 clip) {
	if (clip.w <= 0.0) {
		return clip;
	}
	vec2 ndc = clip.xy / clip.w;
	ndc = round(ndc * PSX_SNAP_RES) / PSX_SNAP_RES;
	return vec4(ndc * clip.w, clip.z, clip.w);
}

float psx_hash(vec3 p) {
	p = fract(p * 0.3183099 + 0.1);
	p *= 17.0;
	return fract(p.x * p.y * p.z * (p.x + p.y + p.z));
}
