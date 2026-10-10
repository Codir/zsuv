shader_type canvas_item;

// Обмежена палітра + дизеринг Байєра 4x4 поверх низької роздільності.
uniform sampler2D screen_tex : hint_screen_texture, filter_nearest;
uniform float color_levels = 18.0;
uniform float dither_strength = 1.0;

const float BAYER[16] = float[16](0.0, 8.0, 2.0, 10.0, 12.0, 4.0, 14.0, 6.0, 3.0, 11.0, 1.0, 9.0, 15.0, 7.0, 13.0, 5.0);

void fragment() {
	vec3 c = texture(screen_tex, SCREEN_UV).rgb;
	ivec2 p = ivec2(FRAGCOORD.xy) % 4;
	float b = (BAYER[p.y * 4 + p.x] + 0.5) / 16.0 - 0.5;
	c = floor(c * color_levels + 0.5 + b * dither_strength) / color_levels;
	COLOR = vec4(c, 1.0);
}
