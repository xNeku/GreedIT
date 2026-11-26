shader_type spatial;
render_mode specular_disabled;
// Material de TODO el juego (lo pone el script de importación y los materiales hechos a mano).
// Luz suave (lambert) o por bandas según el ajuste global `light_bands` (0 = suave, 4 = cuatro bandas):
// lo cambia el ciclo de día y noche (de día suave, de noche por bandas, como eligió el dueño en el Look Lab).

global uniform float light_bands;
uniform vec4 albedo_color : source_color = vec4(1.0);
uniform sampler2D albedo_texture : source_color, filter_nearest_mipmap, hint_default_white;

void fragment() {
	vec4 c = texture(albedo_texture, UV) * albedo_color;
	ALBEDO = c.rgb;
	ALPHA = c.a;
	ALPHA_SCISSOR_THRESHOLD = 0.5;
	ROUGHNESS = 1.0;
}

void light() {
	float amount = clamp(dot(NORMAL, LIGHT), 0.0, 1.0) * ATTENUATION;
	if (light_bands >= 1.0) {
		amount = floor(amount * light_bands + 0.5) / light_bands;
	}
	DIFFUSE_LIGHT += amount * LIGHT_COLOR / PI;
}
