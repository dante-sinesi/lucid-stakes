extends SceneTree
## Revisa una biblioteca de salas nuevas: cada sala tiene sus bloques coherentes (un solo fijo, dos checkpoint, todo anclado al empezar, el jugador parado
## sobre el de entrada) y su camino, jugado en el motor de GDScript, llega a la salida en los pasos que dice. Con EXACTO=1 también comprueba con el
## solucionador nativo que no haya un camino más corto (sólo salas de 9 pisos o menos).
## Uso: GAME_SANDBOX=1 SN_LIB=biblioteca.jsonl [EXACTO=1] godot --headless --path . -s tests/test_salas_nuevas.gd
const Vista := preload("res://salas_nuevas/vista.gd")
const Reglas := preload("res://salas_nuevas/reglas.gd")
const Nat := preload("res://salas_nuevas/nativo.gd")


func _init() -> void:
	var ruta := OS.get_environment("SN_LIB")
	var exacto := OS.get_environment("EXACTO") == "1"
	var fallos := 0
	var n := 0
	var f := FileAccess.open(ruta, FileAccess.READ)
	if f == null:
		print("no se pudo abrir ", ruta)
		quit(1)
		return
	while not f.eof_reached():
		var l := f.get_line().strip_edges()
		if l == "":
			continue
		var d = JSON.parse_string(l)
		if not d is Dictionary:
			continue
		n += 1
		var motivos: Array = []
		var t = Vista.motor_de(d)
		var fijos := 0
		var checks := 0
		for c in t.bloques:
			if t.bloques[c] == "f":
				fijos += 1
			elif t.bloques[c] == "p":
				checks += 1
		if fijos != 1:
			motivos.append("hay %d bloques fijos" % fijos)
		if checks != 2:
			motivos.append("hay %d checkpoints" % checks)
		var r := Reglas.asentar(t.bloques, t.jugador)
		if r.caidos > 0 or r.perdidos > 0:
			motivos.append("no está anclada al empezar")
		if str(t.tipo_en(t.jugador + Vector3i(0, -1, 0))) != "p" or t.jugador.y != 2:
			motivos.append("el jugador no empieza sobre el bloque de entrada")
		var u = t.duplicar()
		for a in d.camino:
			u.actuar(Vector3i(int(a[0]), 0, int(a[1])), int(a[2]))
		if not u.ganado:
			motivos.append("el camino no llega a la salida")
		elif d.camino.size() != int(d.pasos):
			motivos.append("los pasos no coinciden (%d contra %d)" % [d.camino.size(), int(d.pasos)])
		if exacto and int(d.meta) <= 9 and motivos.is_empty():
			var s := Nat.resolver(t, 2000000)
			if s.ok and s.moves < int(d.pasos):
				motivos.append("hay un camino más corto (%d contra %d)" % [s.moves, int(d.pasos)])
		if motivos.is_empty():
			print("ok  sala %d (%s %d pisos, %d pasos)" % [n, str(d.tipo), int(d.meta) - 1, int(d.pasos)])
		else:
			fallos += 1
			print("FALLA sala %d: %s" % [n, "; ".join(motivos)])
	print("salas: %d, fallos: %d" % [n, fallos])
	quit(0)
