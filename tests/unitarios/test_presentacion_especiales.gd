extends SceneTree
## Las torres presentan cada especial nuevo en una sala sencilla (la tercera o la cuarta), tienen siempre una sala en la que hay que colgarse y los pinchos y los bloques pesados salen más seguido.
## Uso: GAME_SANDBOX=1 godot --headless --path . -s tests/unitarios/test_presentacion_especiales.gd
const Torre := preload("res://torre/torre.gd")
const TORRES := 40

var fallos := 0


func check(cond: bool, msg: String) -> void:
	if not cond:
		fallos += 1
		print("FALLA ", msg)


func _ids_de(sala: Dictionary) -> Array:
	var out := {}
	for b in sala.d.bloques:
		var l := str(b[3]).substr(0, 1)
		match l:
			"i": out["hielo"] = true
			"h": out["pesado"] = true
			"c": out["agrietado"] = true
			"s": out["pinchos"] = true
			"b", "d": out["bomba"] = true
			"t": out["trampa"] = true
			"k": out["catapulta"] = true
	return out.keys()


func _init() -> void:
	var paquete := Torre.cargar_paquete_del_juego()
	var con_presentacion := 0
	var con_colgarse := 0
	var con_pinchos := 0
	var con_pesado := 0
	var sin_nuevos_con_pres := 0
	for k in TORRES:
		var t = Torre.armar(paquete, 100 + k, 6, true, 3, "media", {"no_vistos": ["pinchos"]})
		var pres := false
		var cuelga := false
		for i in t.salas.size():
			var s: Dictionary = t.salas[i]
			var ids := _ids_de(s)
			if i >= 2 and i <= 3 and ids == ["pinchos"]:
				pres = true
			for a in s.orig.camino:
				if int(a[2]) == 2:
					cuelga = true
			if ids.has("pinchos"):
				con_pinchos += 1
			if ids.has("pesado"):
				con_pesado += 1
		con_presentacion += 1 if pres else 0
		con_colgarse += 1 if cuelga else 0
		var t2 = Torre.armar(paquete, 100 + k, 6, true, 3, "media", {})   # (sin nada por presentar no hay sala de presentación forzada)
		for i in t2.salas.size():
			if i >= 2 and i <= 3 and _ids_de(t2.salas[i]) == ["pinchos"]:
				sin_nuevos_con_pres += 1
	print("de %d torres: con la presentación de los pinchos %d, con una sala de colgarse %d; salas con pinchos %d y con bloques pesados %d" % [TORRES, con_presentacion, con_colgarse, con_pinchos, con_pesado])
	check(con_presentacion >= TORRES * 0.7, "la mayoría de las torres presentan el especial nuevo en la tercera o cuarta sala (%d de %d)" % [con_presentacion, TORRES])
	check(sin_nuevos_con_pres < con_presentacion, "sin un especial nuevo no se fuerza la sala de presentación (%d contra %d)" % [sin_nuevos_con_pres, con_presentacion])
	check(con_colgarse >= TORRES * 0.85, "casi todas las torres tienen una sala en la que hay que colgarse (%d de %d)" % [con_colgarse, TORRES])
	check(con_pinchos + con_pesado >= TORRES * 0.5, "los pinchos y los pesados salen (%d y %d salas en %d torres)" % [con_pinchos, con_pesado, TORRES])
	print("tests de la presentación de especiales terminados, fallos: ", fallos)
	quit(1 if fallos > 0 else 0)
