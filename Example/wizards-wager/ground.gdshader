shader_type canvas_item;

uniform vec4 highlight : source_color = vec4(1.0, 1.0, 1.0, 0.12);
uniform vec4 shadow : source_color = vec4(0.0, 0.0, 0.0, 0.18);
uniform float edge_size = 2.0;

void fragment() {
	vec4 color = texture(TEXTURE, UV);

	// Top highlight
	if (UV.y < edge_size * TEXTURE_PIXEL_SIZE.y) {
		color.rgb = mix(color.rgb, highlight.rgb, highlight.a);
	}

	// Bottom shadow
	if (UV.y > 1.0 - edge_size * TEXTURE_PIXEL_SIZE.y) {
		color.rgb = mix(color.rgb, shadow.rgb, shadow.a);
	}

	// Left highlight
	if (UV.x < edge_size * TEXTURE_PIXEL_SIZE.x) {
		color.rgb = mix(color.rgb, highlight.rgb, highlight.a * 0.5);
	}

	// Right shadow
	if (UV.x > 1.0 - edge_size * TEXTURE_PIXEL_SIZE.x) {
		color.rgb = mix(color.rgb, shadow.rgb, shadow.a * 0.5);
	}

	COLOR = color;
}