shader_type canvas_item;
// El fondo del juego (ver scripts/ui/fondo_animado.gd): el color liso de la etapa con estrellitas que titilan y bajan muy despacio por la pantalla.
// `base` es el color de la etapa; las estrellas se tiñen de violeta claro si el fondo es oscuro y de violeta oscuro si es claro.

uniform vec4 base : source_color = vec4(0.25, 0.22, 0.40, 1.0);
uniform float fuerza = 1.0;
uniform float velocidad = 4.0;   // píxeles por segundo hacia abajo

float hash(vec2 p) {
	p = fract(p * vec2(123.34, 456.21));
	p += dot(p, p + 45.32);
	return fract(p.x * p.y);
}

void fragment() {
	vec2 res = 1.0 / SCREEN_PIXEL_SIZE;
	float lum = dot(base.rgb, vec3(0.299, 0.587, 0.114));
	vec3 destino = lum < 0.5 ? vec3(0.78, 0.66, 1.0) : vec3(0.28, 0.22, 0.45);
	float t = TIME;
	vec2 p = SCREEN_UV * res - vec2(0.0, t * velocidad);   // (menos t: el dibujo baja)
	float celda = 22.0;
	vec2 id = floor(p / celda);
	vec2 f = fract(p / celda);
	float r = hash(id);
	float a = 0.0;
	if (r > 0.82) {
		vec2 c = vec2(0.25 + 0.5 * hash(id + 1.3), 0.25 + 0.5 * hash(id + 9.1));
		vec2 dd = abs(f - c) * celda;
		float punto = step(max(dd.x, dd.y), 1.6);
		float cruz = r > 0.94 ? step(min(dd.x, dd.y), 0.8) * step(max(dd.x, dd.y), 5.0) : 0.0;   // (algunas estrellas son una cruz chica)
		float titilar = 0.35 + 0.65 * (0.5 + 0.5 * sin(t * (0.5 + r * 1.5) + r * 60.0));
		a = max(punto, cruz) * titilar * 0.38;
	}
	COLOR = vec4(mix(base.rgb, destino, clamp(a * fuerza, 0.0, 0.45)), 1.0);
}
