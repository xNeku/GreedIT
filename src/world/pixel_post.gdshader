shader_type canvas_item;
// Filtro final del mundo 3D (se aplica a la imagen en baja resolución): paleta reducida y un toque de color.
// Los valores se ajustan en pixel_post_material.tres.

// Niveles por canal de color (menos = paleta más corta, más "pixel art"). 0 = sin reducir.
uniform float color_levels : hint_range(0.0, 64.0, 1.0) = 0.0;
// Tramado (dithering) entre niveles: 0 = bandas limpias.
uniform float dither : hint_range(0.0, 1.0) = 0.0;
uniform float saturation : hint_range(0.0, 2.0) = 1.12;
uniform float contrast : hint_range(0.5, 2.0) = 1.06;
// Color hacia el que se tiñen las sombras (ambiente de mazmorra).
uniform vec3 shadow_tint : source_color = vec3(0.16, 0.12, 0.22);
uniform float shadow_tint_amount : hint_range(0.0, 1.0) = 0.35;

const float BAYER[16] = float[16](0.0, 8.0, 2.0, 10.0, 12.0, 4.0, 14.0, 6.0, 3.0, 11.0, 1.0, 9.0, 15.0, 7.0, 13.0, 5.0);

void fragment() {
	vec4 src = texture(TEXTURE, UV);
	vec3 c = src.rgb;
	float luma = dot(c, vec3(0.299, 0.587, 0.114));
	c = mix(vec3(luma), c, saturation);
	c = (c - 0.5) * contrast + 0.5;
	c = mix(c, c + shadow_tint * (1.0 - luma), shadow_tint_amount * (1.0 - luma));
	if (color_levels > 0.0) {
		ivec2 p = ivec2(mod(floor(UV * vec2(textureSize(TEXTURE, 0))), 4.0)); // píxel del mundo (baja resolución)
		float threshold = (BAYER[p.y * 4 + p.x] / 16.0 - 0.5) * dither;
		c = floor(c * color_levels + 0.5 + threshold) / color_levels;
	}
	COLOR = vec4(clamp(c, 0.0, 1.0), src.a);
}
