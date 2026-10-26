shader_type canvas_item;
// El fondo del juego, con un movimiento muy suave (ver scripts/ui/fondo_animado.gd). Se dibuja detrás de todo en pantalla.
// `base` es el color liso de la etapa; cada modo le suma algo muy tenue (más claro si el fondo es oscuro, más oscuro si es claro).
// modo: 0 liso · 1 polvo de luz · 2 bruma · 3 aurora · 4 estrellas · 5 cubos a la deriva

uniform vec4 base : source_color = vec4(0.25, 0.22, 0.40, 1.0);
uniform int modo = 0;
uniform float fuerza = 1.0;

float hash(vec2 p) {
	p = fract(p * vec2(123.34, 456.21));
	p += dot(p, p + 45.32);
	return fract(p.x * p.y);
}

float ruido(vec2 p) {
	vec2 i = floor(p);
	vec2 f = fract(p);
	f = f * f * (3.0 - 2.0 * f);
	return mix(mix(hash(i), hash(i + vec2(1.0, 0.0)), f.x), mix(hash(i + vec2(0.0, 1.0)), hash(i + vec2(1.0, 1.0)), f.x), f.y);
}

float fbm(vec2 p) {
	float v = 0.0;
	float a = 0.5;
	for (int i = 0; i < 4; i++) {
		v += a * ruido(p);
		p = p * 2.03 + vec2(7.1, 3.7);
		a *= 0.5;
	}
	return v;
}

void fragment() {
	vec2 res = 1.0 / SCREEN_PIXEL_SIZE;
	float aspect = res.x / res.y;
	vec2 uv = SCREEN_UV;
	vec2 puv = vec2(uv.x * aspect, uv.y);   // (cuadrado)
	float lum = dot(base.rgb, vec3(0.299, 0.587, 0.114));
	// hacia dónde se tiñe el efecto: más claro y violáceo si el fondo es oscuro, más oscuro si es claro
	vec3 destino = lum < 0.5 ? vec3(0.78, 0.66, 1.0) : vec3(0.28, 0.22, 0.45);
	float a = 0.0;   // cuánto se mezcla el color de destino (siempre chico)
	float t = TIME;

	if (modo == 1) {   // polvo de luz: motas que suben despacio y titilan, en tres capas
		for (int k = 0; k < 3; k++) {
			float fk = float(k);
			float celda = 34.0 + fk * 22.0;   // tamaño de la celda en píxeles
			vec2 p = uv * res;
			p.y += t * (7.0 + fk * 5.0);   // sube
			p.x += sin(t * 0.25 + fk * 2.0 + floor(p.y / celda) * 0.7) * 6.0;
			vec2 id = floor(p / celda);
			vec2 f = fract(p / celda);
			float r = hash(id + fk * 17.0);
			if (r > 0.70) {
				vec2 c = vec2(0.2 + 0.6 * hash(id + 3.1), 0.2 + 0.6 * hash(id + 5.7));
				float tam = (2.6 + fk * 1.2) / celda;
				float d = max(abs(f.x - c.x), abs(f.y - c.y));   // cuadrada, como un minibloque
				float brillo = 0.5 + 0.5 * sin(t * (0.6 + r) + r * 40.0);
				a += step(d, tam) * brillo * (0.55 - fk * 0.12);
			}
		}
		a *= 0.40;
	} else if (modo == 2) {   // bruma: manchas grandes que se desplazan muy despacio, en bloques de 6 píxeles
		vec2 q = floor(uv * res / 6.0) * 6.0 / res;
		vec2 pq = vec2(q.x * aspect, q.y) * 2.2;
		float n = fbm(pq + vec2(t * 0.012, -t * 0.008)) * 0.65 + fbm(pq * 1.7 - vec2(t * 0.02, t * 0.005)) * 0.35;
		a = smoothstep(0.38, 0.78, n) * 0.30;
	} else if (modo == 3) {   // aurora: bandas verticales de luz que ondulan lentamente
		float onda = fbm(vec2(puv.x * 1.3 + t * 0.01, t * 0.015)) * 2.2;
		float banda = sin(puv.x * 6.5 + onda * 3.0 + t * 0.07) * 0.5 + 0.5;
		float alto = smoothstep(0.95, 0.15, uv.y) * smoothstep(0.0, 0.25, uv.y);   // más fuerte arriba
		a = pow(banda, 2.0) * alto * 0.40;
		vec3 verde = lum < 0.5 ? vec3(0.45, 0.95, 0.85) : vec3(0.15, 0.40, 0.45);
		destino = mix(destino, verde, 0.5 * banda);
	} else if (modo == 4) {   // estrellas: puntitos fijos que titilan y una deriva lenta hacia un costado
		vec2 p = uv * res + vec2(t * 3.0, 0.0);
		float celda = 22.0;
		vec2 id = floor(p / celda);
		vec2 f = fract(p / celda);
		float r = hash(id);
		if (r > 0.78) {
			vec2 c = vec2(0.25 + 0.5 * hash(id + 1.3), 0.25 + 0.5 * hash(id + 9.1));
			vec2 dd = abs(f - c) * celda;
			float punto = step(max(dd.x, dd.y), 1.6);
			float cruz = r > 0.94 ? step(min(dd.x, dd.y), 0.8) * step(max(dd.x, dd.y), 5.0) : 0.0;
			float titilar = 0.35 + 0.65 * (0.5 + 0.5 * sin(t * (0.5 + r * 1.5) + r * 60.0));
			a = max(punto, cruz) * titilar * 0.38;
		}
	} else if (modo == 5) {   // cubos a la deriva: cuadrados grandes y tenues que suben despacio, como minibloques flotando
		for (int k = 0; k < 2; k++) {
			float fk = float(k);
			float celda = 150.0 + fk * 90.0;
			vec2 p = uv * res;
			p.y += t * (4.0 + fk * 3.0);
			p.x += fk * 77.0;
			vec2 id = floor(p / celda);
			vec2 f = fract(p / celda);
			float r = hash(id + fk * 9.0);
			if (r > 0.6) {
				vec2 c = vec2(0.3 + 0.4 * hash(id + 2.0), 0.3 + 0.4 * hash(id + 6.0));
				float lado = (0.10 + 0.10 * hash(id + 4.0)) * (1.0 + fk * 0.4);
				vec2 dd = abs(f - c);
				float d = max(dd.x, dd.y);
				float borde = step(d, lado) - step(d, lado - 3.0 / celda);
				float relleno = step(d, lado) * 0.35;
				a += (borde * 0.75 + relleno) * (0.08 + 0.07 * (0.5 + 0.5 * sin(t * 0.3 + r * 30.0)));
			}
		}
	}
	vec3 col = mix(base.rgb, destino, clamp(a * fuerza, 0.0, 0.45));
	COLOR = vec4(col, 1.0);
}
