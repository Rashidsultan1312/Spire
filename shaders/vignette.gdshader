shader_type canvas_item;

void fragment() {
	vec2 uv = UV;
	float d = length(uv - vec2(0.5)) * 1.4;
	float v = smoothstep(0.2, 1.0, d);
	COLOR = vec4(0.05, 0.02, 0.08, v * 0.75);
}
