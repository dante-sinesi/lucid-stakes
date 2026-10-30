// EL CRISTAL de los dados del gran casino: minicubos translúcidos (la opacidad de cada uno viaja en UV.x), con un brillo frío en el canto. Igual que el hielo, va en dos mallas iguales: las caras de atrás
// (voxel_cristal_atras.gdshader) se dibujan antes que las de adelante (voxel_cristal.gdshader); dentro de una misma malla Godot no ordena las caras translúcidas y al girar el dado el vidrio parpadeaba.
uniform float roughness_value = 0.08;
uniform float rim = 0.6;

void fragment() {
	ALBEDO = COLOR.rgb;
	ALPHA = clamp(UV.x, 0.0, 1.0);
	ROUGHNESS = roughness_value;
	EMISSION = vec3(0.55, 0.75, 1.0) * pow(1.0 - clamp(dot(NORMAL, VIEW), 0.0, 1.0), 2.5) * rim;
}
