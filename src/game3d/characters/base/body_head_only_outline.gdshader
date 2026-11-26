shader_type spatial;
render_mode unshaded, cull_front;
// Contorno de 1 px del cuerpo base, también solo en cuello y cabeza (pareja de body_head_only.gdshader).

uniform vec4 outline_color : source_color = vec4(0.094, 0.055, 0.063, 1.0);
uniform float grow = 0.012;
uniform ivec4 keep_bones = ivec4(5, 6, -1, -1);
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
	VERTEX += NORMAL * grow;
}

void fragment() {
	if (keep < keep_threshold) {
		discard;
	}
	ALBEDO = outline_color.rgb;
}
