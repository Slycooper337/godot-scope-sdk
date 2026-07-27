shader_type canvas_item;

uniform vec4 iron_dark : source_color = vec4(0.12, 0.14, 0.16, 1.0);
uniform vec4 iron_light : source_color = vec4(0.34, 0.37, 0.40, 1.0);
uniform vec4 sheen_color : source_color = vec4(0.75, 0.85, 0.92, 1.0);
uniform float sheen_speed : hint_range(0.01, 0.3) = 0.08;
uniform float sheen_width : hint_range(0.02, 0.3) = 0.10;
uniform float grain_strength : hint_range(0.0, 0.2) = 0.045;


void fragment() {
	vec2 uv = UV;

	// Broad metal shading plus fine horizontal brushed lines.
	float broad_shading = 0.5 + 0.5 * sin(uv.y * 3.14159265);
	float brushed_grain = sin(uv.y * 700.0 + sin(uv.x * 35.0) * 2.0);
	vec3 iron = mix(iron_dark.rgb, iron_light.rgb, broad_shading);
	iron += brushed_grain * grain_strength;

	// A slow diagonal band travelling from left to right.
	float sweep_position = fract(TIME * sheen_speed) * 1.6 - 0.3;
	float diagonal_position = uv.x + uv.y * 0.18;
	float sheen = 1.0 - smoothstep(0.0, sheen_width, abs(diagonal_position - sweep_position));
	iron += sheen_color.rgb * sheen * 0.32;

	// Slightly brighter upper and lower edges suggest a beveled iron plate.
	float edge = 1.0 - smoothstep(0.0, 0.08, min(uv.y, 1.0 - uv.y));
	iron += edge * 0.08;

	COLOR = vec4(clamp(iron, vec3(0.0), vec3(1.0)), COLOR.a);
}
