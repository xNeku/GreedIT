shader_type canvas_item;
// Filtro final del mundo (se aplica a la imagen del mundo antes de ampliarla). Mismas fórmulas y mismo orden que
// el Look Lab, para que el juego se vea igual: brillo, curva de cine (ACES), temperatura, contraste, saturación,
// tinte de sombras, paleta reducida con tramado (opcional) y viñeta. Valores en pixel_post_material.tres.
// (El Environment del mundo va con tonemap lineal: la curva se aplica aquí. `exposure` está calibrado midiendo
// capturas del juego contra el Look Lab: la luz de Godot sale más fuerte que la del visor web.)

uniform float exposure : hint_range(0.2, 3.0) = 1.0;
// Curva de cine (ACES, la misma aproximación que el Look Lab).
uniform bool filmic = true;
// Frío (-1) a cálido (+1).
uniform float temperature : hint_range(-1.0, 1.0) = 0.0;
uniform float contrast : hint_range(0.5, 2.0) = 1.0;
uniform float saturation : hint_range(0.0, 2.0) = 1.0;
// Color hacia el que se tiñen las zonas oscuras y cuánto.
uniform vec4 shadow_tint : source_color = vec4(0.12, 0.16, 0.34, 1.0);
uniform float shadow_tint_amount : hint_range(0.0, 1.0) = 0.0;
// Bordes oscuros.
uniform float vignette : hint_range(0.0, 1.0) = 0.0;
// Colores por canal (0 = todos) y tramado entre ellos.
uniform float color_levels : hint_range(0.0, 64.0, 1.0) = 0.0;
uniform float dither : hint_range(0.0, 1.0) = 0.0;

const float BAYER[16] = float[16](0.0, 8.0, 2.0, 10.0, 12.0, 4.0, 14.0, 6.0, 3.0, 11.0, 1.0, 9.0, 15.0, 7.0, 13.0, 5.0);

vec3 aces(vec3 x) {
	return clamp((x * (2.51 * x + 0.03)) / (x * (2.43 * x + 0.59) + 0.14), 0.0, 1.0);
}

void fragment() {
	vec4 src = texture(TEXTURE, UV);
	vec3 c = pow(src.rgb, vec3(2.2)) * exposure; // a lineal
	c = filmic ? aces(c) : clamp(c, 0.0, 1.0);
	c = pow(c, vec3(1.0 / 2.2));
	c.r += temperature * 0.08;
	c.b -= temperature * 0.08;
	c = (c - 0.5) * contrast + 0.5;
	float l = dot(c, vec3(0.299, 0.587, 0.114));
	c = mix(vec3(l), c, saturation);
	c = mix(c, c * 0.6 + shadow_tint.rgb, shadow_tint_amount * (1.0 - smoothstep(0.0, 0.6, l)));
	if (color_levels > 0.5) {
		ivec2 p = ivec2(mod(floor(UV * vec2(textureSize(TEXTURE, 0))), 4.0));
		float t = (BAYER[p.y * 4 + p.x] / 16.0 - 0.5) * dither;
		c = floor(c * color_levels + 0.5 + t) / color_levels;
	}
	vec2 q = UV - 0.5;
	c *= 1.0 - vignette * smoothstep(0.25, 0.75, length(q * vec2(1.25, 1.0)));
	COLOR = vec4(clamp(c, 0.0, 1.0), src.a);
}
