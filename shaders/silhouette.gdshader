shader_type spatial;
// Silueta del personaje: se dibuja sólo en los píxeles donde algo lo tapa.
// Compara la profundidad de la escena con la del propio fragmento; si la escena está
// más cerca de la cámara, el fragmento está tapado y se muestra. Si no, se descarta
// y queda únicamente el cuerpo opaco normal.
render_mode unshaded, depth_test_disabled, cull_back;

uniform vec4 tint : source_color = vec4(0.9, 0.2, 0.25, 0.55);
uniform sampler2D depth_tex : hint_depth_texture, repeat_disable, filter_nearest;
uniform bool compat_depth = true;   // el renderer Compatibility guarda la profundidad en [-1, 1]
uniform float bias = 0.06;   // tolerancia: la placa de la nariz sobresale menos que esto

void fragment() {
	float d = texture(depth_tex, SCREEN_UV).r;
	float z = compat_depth ? d * 2.0 - 1.0 : d;
	vec4 v = INV_PROJECTION_MATRIX * vec4(SCREEN_UV * 2.0 - 1.0, z, 1.0);
	float scene_dist = -(v.xyz / v.w).z;
	float frag_dist = -VERTEX.z;
	if (scene_dist > frag_dist - bias) {
		discard;
	}
	ALBEDO = tint.rgb;
	ALPHA = tint.a;
}
