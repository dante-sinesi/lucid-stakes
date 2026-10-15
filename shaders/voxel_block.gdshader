shader_type spatial;
// Bloque hecho con minibloques (ver scripts/block_models.gd): los colores van en los vértices y acá se
// multiplican por un tinte (el color de altura de los bloques normales purificados) y se les suma un brillo.
//
// Pistas de profundidad (la vista isométrica no tiene perspectiva: lo cercano y lo lejano miden igual):
//  - Atenuación: lo que está más cerca de la cámara que el personaje se ve más claro y lo que está más lejos, más
//    oscuro (depth_strength por unidad de distancia; 0 la apaga).
//  - Transparencia cercana: los bloques que están entre la cámara y el personaje, y cerca de él en pantalla, se vuelven
//    una malla calada para ver lo que tapan (xray_radius en unidades; 0 la apaga).
// Los valores globales los actualiza main.gd en cada cuadro.
global uniform float depth_focus;     // distancia a la cámara (en vista) a la que está el personaje
global uniform float depth_strength;
global uniform float xray_radius;
global uniform vec3 focus_view;       // posición del personaje en el espacio de la cámara

uniform vec4 tint : source_color = vec4(1.0);
uniform vec4 glow_color : source_color = vec4(0.0);
uniform float glow_energy = 0.0;
uniform float roughness_value = 0.8;
uniform float shake = 0.0;   // temblor (la fila de abajo está por caer): cuánto se sacude cada bloque, en unidades

void vertex() {
	if (shake > 0.0) {
		float ph = dot(MODEL_MATRIX[3].xyz, vec3(12.9898, 78.233, 37.719));
		VERTEX.x += sin(TIME * 63.0 + ph) * shake;
		VERTEX.z += cos(TIME * 51.0 + ph * 1.3) * shake;
		VERTEX.y += sin(TIME * 47.0 + ph * 0.7) * shake * 0.5;
	}
}

void fragment() {
	float depth = -VERTEX.z;
	float rel = depth - depth_focus;
	float f = clamp(rel * depth_strength, -0.22, 0.5);  // negativo = más cerca que el personaje: se aclara
	if (xray_radius > 0.0 && depth < depth_focus - 0.5 && distance(VERTEX.xy, focus_view.xy) < xray_radius) {
		if (mod(floor(FRAGCOORD.x) + floor(FRAGCOORD.y), 2.0) < 1.0) {
			discard;
		}
	}
	ALBEDO = COLOR.rgb * tint.rgb * (1.0 - f);
	ROUGHNESS = roughness_value;
	EMISSION = glow_color.rgb * glow_energy;
}
