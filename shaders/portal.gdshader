shader_type spatial;
render_mode unshaded, cull_disabled;
// Portal de ondas (como el de Minecraft): tres tonos que se mueven en celdas grandes, con chispas. `lit` = 0 lo apaga (oscuro y quieto).
uniform vec4 col_a : source_color = vec4(0.2, 0.08, 0.38, 1.0);
uniform vec4 col_b : source_color = vec4(0.45, 0.2, 0.75, 1.0);
uniform vec4 col_c : source_color = vec4(0.75, 0.55, 1.0, 1.0);
uniform vec2 cells = vec2(10.0, 20.0);
uniform float lit : hint_range(0.0, 1.0) = 1.0;
uniform float speed = 1.0;

float hash(vec2 p) {
	return fract(sin(dot(p, vec2(12.9898, 78.233))) * 43758.5453);
}

void fragment() {
	vec2 uv = (floor(UV * cells) + 0.5) / cells;
	float t = TIME * 0.7 * speed * lit;
	float w = sin(uv.x * 12.0 + t * 2.3) + sin(uv.y * 9.0 - t * 1.9) + sin((uv.x + uv.y) * 8.0 + t * 1.4) + sin(length(uv - 0.5) * 20.0 - t * 3.1);
	w = w * 0.25 + 0.5;
	vec3 c = col_a.rgb;
	if (w > 0.66) {
		c = col_c.rgb;
	} else if (w > 0.38) {
		c = col_b.rgb;
	}
	float spark = step(0.97, hash(floor(UV * cells * 2.0) + floor(TIME * 5.0 * lit)));
	c += spark * 0.45 * lit;
	vec3 off = col_a.rgb * 0.18;
	ALBEDO = mix(off, c, lit);
	ALPHA = 0.95;
}
