shader_type canvas_item;
// Orbe de vida estilo Diablo: esfera de cristal con líquido rojo que baja según la vida, con ondas y brillo.
// `fill` (0..1) lo pone el HUD; colores y tamaños se ajustan aquí o en el material.

uniform float fill : hint_range(0.0, 1.0) = 1.0;
uniform vec4 liquid_color : source_color = vec4(0.78, 0.07, 0.08, 1.0);
uniform vec4 liquid_dark : source_color = vec4(0.32, 0.02, 0.04, 1.0);
uniform vec4 glass_color : source_color = vec4(0.05, 0.04, 0.06, 0.85);
uniform vec4 rim_color : source_color = vec4(0.42, 0.33, 0.24, 1.0);
uniform float rim_width = 0.07;
uniform float wave_height = 0.025;

void fragment() {
	vec2 p = UV * 2.0 - 1.0;
	float r = length(p);
	if (r > 1.0) {
		discard;
	}
	// nivel del líquido con ondas que se mueven
	float level = 1.0 - fill * 2.0; // -1 arriba, 1 abajo (en UV la y crece hacia abajo)
	level += sin(p.x * 6.0 + TIME * 2.5) * wave_height + sin(p.x * 11.0 - TIME * 1.7) * wave_height * 0.5;
	vec4 col = glass_color;
	if (p.y > level) {
		// líquido: más oscuro hacia los bordes y abajo, como una esfera
		float shade = clamp(1.0 - r * 0.6 + (level - p.y) * 0.15, 0.0, 1.0);
		col = mix(liquid_dark, liquid_color, shade);
		// línea brillante en la superficie
		col.rgb += vec3(0.35, 0.1, 0.08) * smoothstep(0.06, 0.0, abs(p.y - level));
	}
	// brillo del cristal arriba a la izquierda
	float shine = smoothstep(0.35, 0.0, length(p - vec2(-0.35, -0.45)));
	col.rgb += vec3(0.55) * shine * 0.55;
	// borde (marco)
	col = mix(col, rim_color, smoothstep(1.0 - rim_width - 0.02, 1.0 - rim_width, r));
	col.rgb *= mix(1.0, 0.55, smoothstep(1.0 - rim_width * 0.4, 1.0, r));
	COLOR = col;
}
