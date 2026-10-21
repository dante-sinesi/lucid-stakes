extends SceneTree
## Experimento de composición: apila dos módulos de pared (A abajo, B arriba, sin placa fija en el medio: todo cuelga de la cima de arriba)
## y compara la solución exacta de la torre entera con la suma de las de cada módulo por separado.
## Uso: GAME_SANDBOX=1 godot --headless --path . -s cilindro/probe_apilar.gd -- fuente=x3 pares=60 seed=1 tope=3000000
const Motor := preload("res://cilindro/motor.gd")
const Reglas := preload("res://cilindro/reglas.gd")
const Nat := preload("res://cilindro/nativo.gd")


func _cargar(etiqueta: String) -> Array:
	var out: Array = []
	var f := FileAccess.open(ProjectSettings.globalize_path("capturas/cilindro_%s.jsonl" % etiqueta), FileAccess.READ)
	if f == null:
		return out
	while not f.eof_reached():
		var l := f.get_line()
		if l.strip_edges() == "":
			continue
		var d = JSON.parse_string(l)
		if d is Dictionary:
			out.append(d)
	return out


## Los bloques de un módulo como { Vector3i: tipo } sin la cima, con espejo opcional en x y desplazados `dy` niveles hacia arriba.
func _bloques(m: Dictionary, espejo: bool, dy: int) -> Dictionary:
	var out := {}
	for b in m.bloques:
		if str(b[3]) == "f":
			continue
		var x: int = int(b[0])
		if espejo:
			x = 7 - x
		out[Vector3i(x, int(b[1]) + dy, int(b[2]))] = str(b[3])
	return out


func _init() -> void:
	var o := {}
	for arg in OS.get_cmdline_user_args():
		var kv: PackedStringArray = arg.split("=", true, 1)
		if kv.size() == 2:
			o[kv[0]] = kv[1]
	var fuente: String = o.get("fuente", "x3")
	var pares := int(o.get("pares", 40))
	var tope := int(o.get("tope", 3000000))
	var rng := RandomNumberGenerator.new()
	rng.seed = int(o.get("seed", 1))
	var mods := _cargar(fuente)
	print("módulos cargados: ", mods.size())
	var n_estables := 0
	var n_resolubles := 0
	var suma_entera := 0
	var suma_partes := 0
	var menor := 0
	var mayor := 0
	var igual := 0
	for i in pares:
		var a: Dictionary = mods[rng.randi_range(0, mods.size() - 1)]
		var b: Dictionary = mods[rng.randi_range(0, mods.size() - 1)]
		var ha: int = int(a.alto) - 1
		var hb: int = int(b.alto) - 1
		var alto := ha + hb + 1
		var mejor = null
		for ea in [false, true]:
			for eb in [false, true]:
				var t = Motor.nueva(alto, Vector3i(int(a.jugador[0]) if not ea else 7 - int(a.jugador[0]), 1, 0))
				t.bloques.clear()
				for c in Reglas.cima(alto):
					t.bloques[c] = "f"
				var ba := _bloques(a, ea, 0)
				var bb := _bloques(b, eb, ha)
				var choque := false
				for c in bb:
					if ba.has(c):
						choque = true
				if choque:
					continue
				t.bloques.merge(ba)
				t.bloques.merge(bb)
				var r := Reglas.asentar(t.bloques, alto, t.jugador)
				if r.caidos == 0 and r.perdidos == 0:
					mejor = t
					break
			if mejor != null:
				break
		if mejor == null:
			continue
		n_estables += 1
		var sol = Nat.resolver(mejor, tope)
		if not sol.ok:
			print("par %d: estable pero %s (%d nodos)" % [i, "sin presupuesto" if sol.get("tope", false) else "SIN SOLUCIÓN", sol.states])
			continue
		n_resolubles += 1
		var partes: int = int(a.pasos) + int(b.pasos)
		suma_entera += sol.moves
		suma_partes += partes
		if sol.moves < partes:
			menor += 1
		elif sol.moves > partes:
			mayor += 1
		else:
			igual += 1
		print("par %d: A %d pasos (%d pisos) + B %d pasos (%d pisos) = %d; torre entera %d pasos / %d agarres / %d bloques distintos" % [i, a.pasos, ha, b.pasos, hb, partes, sol.moves, sol.agarres, sol.distintos])
	print("resumen: %d pares, %d con las dos mitades enganchadas y estables, %d resolubles; entera < suma en %d, igual en %d, mayor en %d; suma de entera %d contra suma de partes %d" % [pares, n_estables, n_resolubles, menor, igual, mayor, suma_entera, suma_partes])
	quit(0)
