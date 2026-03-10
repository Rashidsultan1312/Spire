shader_type canvas_item;

uniform sampler2D screen_texture : hint_screen_texture, repeat_disable, filter_linear_mipmap;
uniform float blur_amount : hint_range(0.0, 5.0) = 2.0;
uniform float darkness : hint_range(0.0, 1.0) = 0.3;

void fragment() {
	vec2 ps = SCREEN_PIXEL_SIZE;
	vec4 col = vec4(0.0);
	float total = 0.0;
	for (float x = -4.0; x <= 4.0; x += 1.0) {
		for (float y = -4.0; y <= 4.0; y += 1.0) {
			float w = exp(-(x * x + y * y) / (2.0 * blur_amount * blur_amount + 0.001));
			col += textureLod(screen_texture, SCREEN_UV + vec2(x, y) * ps * blur_amount, 0.0) * w;
			total += w;
		}
	}
	col /= total;
	col.rgb *= (1.0 - darkness);
	COLOR = col;
}
