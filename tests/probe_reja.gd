extends SceneTree
## Muestra salas "reja" (muro denso desordenado con solución garantizada): capas en texto, agarres y movimientos. Variables: D (dificultad), SEEDS.
## Uso: IDEA_ONLY=reja tools/Godot...console.exe --headless --path . -s tests/probe_reja.gd
const Rooms := preload("res://scripts/rooms.gd")
const TowerLogic := preload("res://scripts/tower_logic.gd")


func _init() -> void:
	OS.set_environment("IDEA_ONLY", OS.get_environment("IDEA") if OS.get_environment("IDEA") != "" else "reja")
	var d := float(OS.get_environment("D")) if OS.get_environment("D") != "" else 0.6
	var seeds := int(OS.get_environment("SEEDS")) if OS.get_environment("SEEDS") != "" else 3
	for sd in seeds:
		var res: Dictionary = Rooms.generate_stage(1000 + sd, int(OS.get_environment("ROWS")) if OS.get_environment("ROWS") != "" else 5, d, {"pace": "normal", "scenario": "pesadilla"})
		if not res.ok:
			print("semilla %d: FALLÓ (%s)" % [sd, str(res.get("error", ""))])
			continue
		var lg = res.logic
		var grabs := 0
		for a in res.path:
			if a.mode == TowerLogic.Mode.GRAB:
				grabs += 1
		print("=== semilla %d: %d movimientos, %d agarres ===" % [sd, res.path.size(), grabs])
		var start: Vector3i = lg.player
		for y in range(1, 6):
			print("capa %d%s" % [y, "  (piso de la sala)" if y == 1 else ""])
			for z in 8:
				var row := ""
				for x in 8:
					var c := Vector3i(x, y, z)
					var ch := "."
					if lg.blocks.has(c):
						var id: int = lg.blocks[c]
						ch = "F" if lg.fixed.has(c) else ("#" if lg.kind_of.get(id, 0) == 0 else "?")
						if id == lg.goal_block:
							ch = "G"
					elif lg.blocks.has(c + Vector3i.DOWN) and c == start:
						ch = "P"
					row += ch + " "
				print("  " + row)
		# la solución, agrupada: paso (M) o agarre (G) con su dirección
		var sol := ""
		for a in res.path:
			var dir: Vector3i = a.dir
			var n := "E" if dir.x > 0 else ("O" if dir.x < 0 else ("S" if dir.z > 0 else "N"))
			sol += ("g" if a.mode == TowerLogic.Mode.GRAB else "") + n + " "
		print("solución: " + sol)
	quit()
