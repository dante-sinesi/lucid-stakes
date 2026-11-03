shader_type canvas_item;
// Filtro de daltonismo (Opciones > General > Daltonismo): se dibuja sobre toda la pantalla, también sobre la escena 3D.
// Lleva los verdes (del amarillo verdoso al verde azulado) hacia el azul y deja el resto como está: así los verdes y los rojos, que son los que se confunden,
// pasan a ser azules y rojos (o naranjas), que se distinguen bien con los tipos de daltonismo más comunes. El brillo y la saturación no cambian.

uniform sampler2D pantalla : hint_screen_texture, repeat_disable, filter_nearest;

const float VERDE_DESDE = 0.16;   // el matiz donde empiezan los verdes (amarillo verdoso)
const float VERDE_HASTA = 0.50;   // y donde terminan (verde azulado)
const float AZUL_DESDE = 0.50;    // adónde van a parar: de cian a azul
const float AZUL_HASTA = 0.62;

vec3 rgb_a_hsv(vec3 c) {
	vec4 K = vec4(0.0, -1.0 / 3.0, 2.0 / 3.0, -1.0);
	vec4 p = mix(vec4(c.bg, K.wz), vec4(c.gb, K.xy), step(c.b, c.g));
	vec4 q = mix(vec4(p.xyw, c.r), vec4(c.r, p.yzx), step(p.x, c.r));
	float d = q.x - min(q.w, q.y);
	float e = 1.0e-10;
	return vec3(abs(q.z + (q.w - q.y) / (6.0 * d + e)), d / (q.x + e), q.x);
}

vec3 hsv_a_rgb(vec3 c) {
	vec4 K = vec4(1.0, 2.0 / 3.0, 1.0 / 3.0, 3.0);
	vec3 p = abs(fract(c.xxx + K.xyz) * 6.0 - K.www);
	return c.z * mix(K.xxx, clamp(p - K.xxx, 0.0, 1.0), c.y);
}

void fragment() {
	vec4 base = texture(pantalla, SCREEN_UV);
	vec3 hsv = rgb_a_hsv(base.rgb);
	float h = hsv.x;
	float peso = smoothstep(VERDE_DESDE - 0.03, VERDE_DESDE + 0.03, h) * (1.0 - smoothstep(VERDE_HASTA - 0.03, VERDE_HASTA + 0.03, h));   // qué tan verde es el matiz
	float destino = mix(AZUL_DESDE, AZUL_HASTA, clamp((h - VERDE_DESDE) / (VERDE_HASTA - VERDE_DESDE), 0.0, 1.0));
	hsv.x = mix(h, destino, peso);
	COLOR = vec4(hsv_a_rgb(hsv), base.a);
}
