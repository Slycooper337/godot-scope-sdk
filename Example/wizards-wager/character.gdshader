shader_type canvas_item;

uniform vec4 outline_color : source_color = vec4(0.0, 0.0, 0.0, 1.0);

void fragment() {
	vec4 sprite_color = texture(TEXTURE, UV);
	vec2 texel = TEXTURE_PIXEL_SIZE;

	float neighbor_alpha = 0.0;

	// LEFT outline
	neighbor_alpha = max(
		neighbor_alpha,
		texture(TEXTURE, UV + vec2(texel.x, 0.0)).a
	);

	// TOP outline
	neighbor_alpha = max(
		neighbor_alpha,
		texture(TEXTURE, UV + vec2(0.0, texel.y)).a
	);

	if (sprite_color.a > 0.01) {
		COLOR = sprite_color;
	} else if (neighbor_alpha > 0.01) {
		COLOR = outline_color;
	} else {
		COLOR = vec4(0.0);
	}
}