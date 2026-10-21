extends SceneTree
## Escribe en capturas/visor_datos.json las mejores paredes con TODOS los cuadros de su camino más corto (un cuadro por paso), para un visor interactivo.
## Uso: GAME_SANDBOX=1 godot --headless --path . -s tests/volcar_visor.gd -- [CUÁNTAS=8] [ARCHIVO=bibliotecas/p2_elite.rooms]
const RoomLib := preload("res://scripts/room_lib.gd")
const Pack := preload("res://scripts/room_pack.gd")
const Base := preload("res://scripts/pared_gen.gd")
const Gen := preload("res://scripts/pared_gen2.gd")


func _init() -> void:
	var a := OS.get_cmdline_user_args()
	var count := int(a[0]) if a.size() > 0 else 8
	var path: String = a[1] if a.size() > 1 else "bibliotecas/p2_elite.rooms"
	var rooms: Array = Pack.load_library(ProjectSettings.globalize_path(path))
	var scored: Array = []
	for r in rooms:
		if str(r.shape) != "P6":
			continue
		r["mass"] = Base.mass("pared")
		var costs := Base.face_costs(r)
		if not costs[0].ok:
			continue
		var sc := Gen.total_score(r, costs, true)
		if sc < 0.0:
			continue
		scored.append({"room": r, "costs": costs, "score": sc})
	scored.sort_custom(func(x, y): return x.score > y.score)
	var out: Array = []
	for i in mini(count, scored.size()):
		var r: Dictionary = scored[i].room
		var c: Dictionary = scored[i].costs[0]
		var rr := RoomLib.copy_room(r)
		rr["path"] = c.path
		var col := Gen.colapsos(rr)
		var t = RoomLib.build_state(r)
		var frames: Array = []
		for step in range(0, c.path.size() + 1):
			var bl: Array = []
			for id in t.positions:
				var p: Vector3i = t.positions[id]
				if not t.fixed.has(p):
					bl.append([p.x, p.y, p.z, RoomLib.CHAR_OF_KIND.get(t.kind_at(p), "n")])
			frames.append({"b": bl, "p": [t.player.x, t.player.y, t.player.z], "c": 1 if t.hang_dir != Vector3i.ZERO else 0})
			if step < c.path.size():
				t.try_action(c.path[step].dir, c.path[step].mode)
		var sp := {}
		for cc in r.cols:
			for ch in String(r.cols[cc]):
				if ch != "n" and ch != ".":
					sp[ch] = int(sp.get(ch, 0)) + 1
		var floor_cells: Array = []
		for fc in r.floor_cells:
			floor_cells.append([fc.x, fc.y])
		out.append({"nombre": "Pared %d" % (i + 1), "h": int(r.h), "pasos": int(c.moves), "empujes": int(c.grabs), "bloques_movidos": int(c.blocks), "bloques": RoomLib.block_count(r), "derrumbes": int(col.movimientos_que_derrumban), "especiales": sp, "salida": [r.exit.x, r.exit.y], "piso": floor_cells, "camino": RoomLib.path_string(c.path), "cuadros": frames})
	var f := FileAccess.open(ProjectSettings.globalize_path("capturas/visor_datos.json"), FileAccess.WRITE)
	f.store_string(JSON.stringify(out))
	f.close()
	print("listo: %d paredes" % out.size())
	quit(0)
