extends SceneTree
## Capturas de las salas nuevas desde detrás del jugador (cuadros del camino más corto). Uso:
##   GAME_SANDBOX=1 godot --path . --rendering-driver opengl3 --resolution 1280x720 -s tests/shot_salas_nuevas.gd -- ARCHIVO.jsonl PREFIJO [INDICES=0,1,2] [CUADROS=5]
## Escribe PREFIJO_<sala>_<cuadro>.png y una línea "META" por sala con los números.
const Vista := preload("res://salas_nuevas/vista.gd")
const RoomView := preload("res://scripts/room_view.gd")


func _frames(n: int) -> void:
	for i in n:
		await process_frame


func _init() -> void:
	var args := OS.get_cmdline_user_args()
	var archivo: String = args[0]
	var prefijo: String = args[1]
	var salas: Array = []
	var f := FileAccess.open(archivo, FileAccess.READ)
	while f != null and not f.eof_reached():
		var l := f.get_line().strip_edges()
		if l == "":
			continue
		var d = JSON.parse_string(l)
		if d is Dictionary:
			salas.append(d)
	var indices: Array = []
	if args.size() > 2 and args[2] != "":
		for s in args[2].split(","):
			indices.append(int(s))
	else:
		for i in mini(salas.size(), 3):
			indices.append(i)
	var n_cuadros := int(args[3]) if args.size() > 3 else 5
	var vp := SubViewport.new()
	vp.size = Vector2i(1280, 720)
	vp.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	root.add_child(vp)
	var mundo := Node3D.new()
	vp.add_child(mundo)
	RoomView.add_lighting(mundo)
	var bloques_nodo := Node3D.new()
	mundo.add_child(bloques_nodo)
	var cam := Camera3D.new()
	vp.add_child(cam)
	cam.current = true
	for idx in indices:
		if idx >= salas.size():
			continue
		var d: Dictionary = salas[idx]
		var t = Vista.motor_de(d)
		var camino: Array = d.camino
		var pasos_total := camino.size()
		var cuadros: Array = []
		for k in n_cuadros:
			cuadros.append(int(round(float(k) * float(pasos_total) / float(maxi(n_cuadros - 1, 1)))))
		var enc := {}
		for c in t.bloques:
			if t.bloques[c] == "p" and c.y == 1:
				enc[c] = true
		var paso := 0
		var k := 0
		while true:
			while k < cuadros.size() and cuadros[k] == paso:
				Vista.poblar(bloques_nodo, t, enc)
				Vista.camara_detras(cam, t)
				await _frames(4)
				vp.get_texture().get_image().save_png("%s_%d_%d.png" % [prefijo, idx, k])
				k += 1
			if paso >= pasos_total or t.ganado or t.perdido:
				break
			var a: Array = camino[paso]
			t.actuar(Vector3i(int(a[0]), 0, int(a[1])), int(a[2]))
			for c in t.bloques:
				if t.bloques[c] == "f" and t.ganado and c.y == t.meta:
					enc[c] = true
			paso += 1
		print("META sala %d: %s %d pisos, %d pasos, %d agarres, %d bloques distintos, gana: %s" % [idx, d.tipo, int(d.meta), pasos_total, int(d.agarres), int(d.distintos), str(t.ganado)])
	print("listo")
	quit(0)
