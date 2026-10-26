shader_type canvas_item;
// El fondo del juego (ver scripts/ui/fondo_animado.gd): un remolino psicodélico hecho de cuadraditos grandes, como el del menú principal, pero hecho de varias capas que se
// mueven distinto cuando la cámara sube (paralaje), con un resplandor en el centro y viñeta en los bordes: la torre se ve flotando en un espacio profundo y no apoyada sobre una loza.
// `base` es el color de la etapa; el remolino lo oscurece y aclara alrededor de ese color (siempre queda en tonos medios, para que los bloques oscuros y los claros se recorten).

uniform vec4 base : source_color = vec4(0.25, 0.22, 0.40, 1.0);
uniform vec2 camara = vec2(0.0);   // dónde está la cámara de la torre (en unidades del mundo, según su derecha y su arriba): mueve las capas con paralaje
uniform float fuerza = 1.0;

float hash(vec2 p) {
	p = fract(p * vec2(123.34, 456.21));
	p += dot(p, p + 45.32);
	return fract(p.x * p.y);
}

// El remolino de una capa en el punto p (píxeles): dos ondas, una que gira con el ángulo y otra que respira con la distancia.
float remolino(vec2 p, vec2 centro, float escala, float vel, float fase) {
	vec2 d = p - centro;
	float r = length(d);
	float a = atan(d.y, d.x);
	float t = TIME * vel;
	return sin(a * 3.0 + r * escala - t * 1.4 + fase) + sin(r * escala * 1.45 + t * 0.9 - fase * 0.7);
}

// Cuantiza a cuadraditos de `celda` píxeles (el centro de cada uno).
vec2 cuadrito(vec2 p, float celda) {
	return (floor(p / celda) + 0.5) * celda;
}

void fragment() {
	vec2 res = 1.0 / SCREEN_PIXEL_SIZE;
	vec2 pix = SCREEN_UV * res;
	vec2 c0 = res * 0.5;
	float lum = dot(base.rgb, vec3(0.299, 0.587, 0.114));
	vec3 violeta = vec3(0.50, 0.38, 0.85);
	vec3 tono = mix(base.rgb, violeta * lum * 1.6, 0.18);   // (el color de la etapa, un poco más violáceo)
	// la capa lejana: cuadraditos grandes, lentos, casi no se mueven con la cámara
	vec2 pl = pix + camara * 6.0;
	float vl = remolino(cuadrito(pl, 30.0), c0, 0.0042 * 10.0, 0.28, 0.0);
	float nl = vl > 0.9 ? 1.0 : (vl > 0.0 ? 0.35 : (vl > -0.9 ? -0.25 : -0.65));
	// la capa del medio: cuadraditos medianos, algo más rápidos
	vec2 pm = pix + camara * 16.0;
	float vm = remolino(cuadrito(pm, 20.0), c0 + vec2(60.0, -40.0), 0.035, 0.45, 2.0);
	float nm = vm > 0.9 ? 1.0 : (vm > 0.0 ? 0.3 : (vm > -0.9 ? -0.2 : -0.5));
	// la capa cercana: chispitas de luz que se mueven mucho con la cámara (dan la sensación de profundidad)
	vec2 pc = pix + camara * 34.0 + vec2(TIME * 1.5, -TIME * 2.5);
	vec2 idc = floor(pc / 44.0);
	vec2 fc = fract(pc / 44.0);
	float rc = hash(idc);
	float chispa = 0.0;
	if (rc > 0.86) {
		vec2 cc = vec2(0.25 + 0.5 * hash(idc + 1.3), 0.25 + 0.5 * hash(idc + 7.7));
		vec2 dd = abs(fc - cc) * 44.0;
		chispa = step(max(dd.x, dd.y), 2.4 + 2.0 * rc) * (0.4 + 0.6 * (0.5 + 0.5 * sin(TIME * (0.35 + rc * 0.5) + rc * 50.0)));
	}
	float nivel = nl * 0.27 + nm * 0.15;   // (cuánto se aclara u oscurece el color: siempre poco)
	vec3 col = tono * (1.0 + nivel * fuerza);
	col = mix(col, tono * 1.9 + vec3(0.05), chispa * 0.40);
	// resplandor en el centro y viñeta en los bordes: la luz viene del fondo del pozo
	vec2 q = (SCREEN_UV - 0.5) * vec2(res.x / res.y, 1.0);
	float d = length(q);
	col *= mix(1.16, 0.62, smoothstep(0.05, 0.95, d));
	COLOR = vec4(col, 1.0);
}
