extends Node3D
## El modelo 3D de Farolín (lo arma farolin.gd): la llama titila y la luz sube y baja con ella; la cara cambia entre contenta y triste.

var flame: MeshInstance3D
var light: OmniLight3D
var smile: Node3D
var frown: Node3D
var _t := randf() * 10.0
var _base_energy := 1.6


func _process(delta: float) -> void:
	_t += delta
	var k := 1.0 + 0.18 * sin(_t * 7.3) + 0.1 * sin(_t * 12.1 + 1.3)
	if light != null:
		light.light_energy = 1.3 * k
	if flame != null:
		var mat := flame.material_override as StandardMaterial3D
		if mat != null:
			mat.emission_energy_multiplier = _base_energy * k


## "contento" (sonríe) o "triste" (boca para abajo, la llama baja).
func set_mood(mood: String) -> void:
	var sad := mood == "triste"
	smile.visible = not sad
	frown.visible = sad
	_base_energy = 0.9 if sad else 1.6
