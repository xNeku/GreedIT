shader_type spatial;
render_mode diffuse_toon, specular_disabled;
// Cuerpo base de Universal Base Characters con ropa encima: solo se dibuja lo pegado al cuello y la cabeza
// (lo demás lo tapa la ropa; si se dibujara, asomaría por ella). Mismo estilo que el resto: luz por bandas.

uniform sampler2D albedo_texture : source_color, filter_nearest;
uniform vec4 tint : source_color = vec4(1.0);
// Índices de hueso (orden del esqueleto del modelo) que se dibujan: 5 = cuello, 6 = cabeza.
uniform ivec4 keep_bones = ivec4(5, 6, -1, -1);
// Peso mínimo en esos huesos para dibujar un trozo (más = corta más arriba del cuello).
uniform float keep_threshold : hint_range(0.0, 1.0) = 0.5;

varying float keep;

void vertex() {
	float w = 0.0;
	for (int i = 0; i < 4; i++) {
		int b = int(BONE_INDICES[i]);
		if (b == keep_bones.x || b == keep_bones.y || b == keep_bones.z || b == keep_bones.w) {
			w += BONE_WEIGHTS[i];
		}
	}
	keep = w;
}

void fragment() {
	if (keep < keep_threshold) {
		discard;
	}
	ALBEDO = texture(albedo_texture, UV).rgb * tint.rgb;
	ROUGHNESS = 1.0;
}
