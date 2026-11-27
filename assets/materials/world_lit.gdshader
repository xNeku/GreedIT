shader_type spatial;
render_mode specular_disabled;
// Material de TODO el juego (lo pone el script de importación y los materiales hechos a mano).
// Luz suave (lambert) o por bandas según el ajuste global `light_bands` (0 = suave, 4 = cuatro bandas; solo la luz
// del sol/la luna, las antorchas y los hechizos siempre suaves):
// lo cambia el ciclo de día y noche (de día suave, de noche por bandas, como eligió el dueño en el Look Lab).

global uniform float light_bands;
// Dónde está el jugador local (lo pone la cámara): lo que lo tape (montañas) se recorta alrededor de él.
global uniform vec3 occlusion_point;
uniform vec4 albedo_color : source_color = vec4(1.0);
uniform sampler2D albedo_texture : source_color, filter_nearest_mipmap, hint_default_white;
// Multiplica por el color de cada vértice (el terreno generado pinta así sus biomas).
uniform bool use_vertex_color = false;
// Recortar este material cuando tapa al jugador (terreno y montañas).
uniform bool occlusion_cutout = false;
// Radio (m) del recorte alrededor del jugador, visto desde la cámara.
uniform float occlusion_radius = 4.5;

varying vec3 world_position;

void vertex() {
	world_position = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
}

void fragment() {
	if (occlusion_cutout) {
		// hacia la cámara (en ortográfica, la misma dirección para toda la pantalla)
		vec3 to_camera = INV_VIEW_MATRIX[2].xyz;
		vec3 rel = world_position - occlusion_point;
		float in_front = dot(rel, to_camera);
		float side = length(rel - to_camera * in_front);
		// solo de los pies hacia arriba en pantalla: por debajo, la montaña sigue tapando el vacío que hay bajo ella
		float above_feet = dot(rel, INV_VIEW_MATRIX[1].xyz);
		if (in_front > 1.5 && world_position.y > occlusion_point.y + 1.0 && side < occlusion_radius && above_feet > 0.0) {
			discard;
		}
	}
	vec4 c = texture(albedo_texture, UV) * albedo_color;
	if (use_vertex_color) {
		c *= COLOR;
	}
	ALBEDO = c.rgb;
	ALPHA = c.a;
	ALPHA_SCISSOR_THRESHOLD = 0.5;
	ROUGHNESS = 1.0;
}

void light() {
	float amount = clamp(dot(NORMAL, LIGHT), 0.0, 1.0) * ATTENUATION;
	// las bandas solo para el sol/la luna: antorchas y hechizos siempre con luz suave
	if (light_bands >= 1.0 && LIGHT_IS_DIRECTIONAL) {
		amount = floor(amount * light_bands + 0.5) / light_bands;
	}
	DIFFUSE_LIGHT += amount * LIGHT_COLOR / PI;
}
