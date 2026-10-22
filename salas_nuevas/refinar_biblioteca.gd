extends SceneTree
## Fase 2: para cada sala de una biblioteca busca el camino más corto REAL (A* exacto con la cota superior del camino conocido) y calcula sus métricas de
## complejidad; reescribe la biblioteca con los campos nuevos. Las salas altas que salieron por lonjas pasan a tener el camino exacto si el tope de nodos alcanza.
## Uso: GAME_SANDBOX=1 godot --headless --path . -s salas_nuevas/refinar_biblioteca.gd -- ENTRADA.jsonl SALIDA.jsonl [TOPE=6000000] [PARTE=0] [PARTES=1]
## (con PARTE y PARTES sólo se hacen las salas cuyo número módulo PARTES es PARTE: así se reparte entre varios procesos)
const Vista := preload("res://salas_nuevas/vista.gd")
const Nat := preload("res://salas_nuevas/nativo.gd")


func _init() -> void:
	var args := OS.get_cmdline_user_args()
	var entrada: String = args[0]
	var salida: String = args[1]
	var tope := int(args[2]) if args.size() > 2 else 6000000
	var parte := int(args[3]) if args.size() > 3 else 0
	var partes := int(args[4]) if args.size() > 4 else 1
	var salas: Array = []
	var f := FileAccess.open(entrada, FileAccess.READ)
	while f != null and not f.eof_reached():
		var l := f.get_line().strip_edges()
		if l == "":
			continue
		var d = JSON.parse_string(l)
		if d is Dictionary:
			salas.append(d)
	var out := FileAccess.open(salida, FileAccess.WRITE)
	var n := 0
	for d in salas:
		n += 1
		if (n - 1) % partes != parte:
			continue
		if bool(d.get("exacto", false)) and float(d.get("complejidad", 0.0)) > 0.0:   # (ya refinada y medida: se copia tal cual)
			out.store_line(JSON.stringify(d))
			out.flush()
			continue
		var t = Vista.motor_de(d)
		# primero el mejor camino que se consigue (lonjas de 3 a 6 pisos acortadas por ventanas): cuanto más justa la cota superior, menos busca el A*
		var cj: Dictionary = Nat.conocido(t)
		if bool(cj.get("ok", false)) and int(cj.mejor) < int(d.pasos):
			d["pasos"] = int(cj.mejor)
			d["agarres"] = int(cj.agarres)
			d["distintos"] = int(cj.distintos)
			d["camino"] = cj.camino
		var m: Dictionary = Nat.minimo(t, int(d.pasos), tope)
		if bool(m.get("exacto", false)):
			if int(m.minimo) < int(d.pasos) and m.has("camino"):
				d["pasos"] = int(m.minimo)
				d["agarres"] = int(m.agarres)
				d["distintos"] = int(m.distintos)
				d["camino"] = m.camino
			d["exacto"] = true
			d["cota_inferior"] = int(m.minimo)
		else:
			d["exacto"] = false
			d["cota_inferior"] = int(m.get("cota_inferior", 0))
		if bool(d.exacto):
			var mt: Dictionary = Nat.medir(Vista.motor_de(d), tope)
			if bool(mt.get("ok", false)):
				for k in ["legales", "letales", "optimos", "desconocidos", "criticos", "bits_opt", "bits_letal", "complejidad"]:
					d[k] = mt[k]
		out.store_line(JSON.stringify(d))
		out.flush()   # (para no perder lo hecho si se corta el proceso)
		print("sala %d/%d: %s %d pisos, %d pasos %s, complejidad %s" % [n, salas.size(), str(d.tipo), int(d.meta) - 1, int(d.pasos), "(exacto)" if bool(d.exacto) else "(cota inferior %d)" % int(d.cota_inferior), str(d.get("complejidad", "?"))])
	out.close()
	print("listo")
	quit(0)
