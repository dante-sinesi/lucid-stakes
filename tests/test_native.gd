extends SceneTree
## El solucionador nativo (tools/solver_nativo.exe) contra el de GDScript: (A) las reglas, acción por acción sobre secuencias al azar, y (B) el resultado de la búsqueda (estado, pasos) en modo de producción y en modo admisible.
## Variables: N (salas, 60), SEED (5), STEPS (largo de las secuencias, 60), CAP (estados, 6000).
## Ejecutar: GAME_SANDBOX=1 tools/Godot_v4.7.2-stable_win64_console.exe --headless --path . -s tests/test_native.gd
const RoomLib := preload("res://scripts/room_lib.gd")
const Solver := preload("res://scripts/solver.gd")
const NativeSolver := preload("res://scripts/native_solver.gd")
const TowerLogic := preload("res://scripts/tower_logic.gd")

var fails := 0


func check(cond: bool, label: String) -> void:
	if not cond:
		fails += 1
		print("FAIL: ", label)


func _env(name: String, def: float) -> float:
	return float(OS.get_environment(name)) if OS.get_environment(name) != "" else def


func _rooms(n: int, rng: RandomNumberGenerator) -> Array:
	var shapes := ["3x3", "3x5", "3x8", "L", "U"]
	var out: Array = []
	for i in n:
		var sh: String = shapes[i % shapes.size()]
		var h := 4 + (i % 4)
		var r := RoomLib.make_room(sh, h)
		var dens := 0.35 + 0.4 * rng.randf()
		for c in RoomLib.free_cells(sh):
			var hh := rng.randi_range(0, h - 1)
			if hh > 0 and rng.randf() < dens:
				var ch := "n"
				var q := rng.randf()
				if q < 0.07:
					ch = "h"
				elif q < 0.12:
					ch = "i"
				elif q < 0.17:
					ch = "c"
				var ks := ""
				for k in hh:
					ks += ch if k == 0 or rng.randf() < 0.8 else "n"
				r.cols[c] = ks
		out.append(r)
	return out


func _init() -> void:
	if not NativeSolver.available():
		print("el solucionador nativo no está (tools/solver_nativo.exe): nada que probar")
		quit(0)
		return
	var n := int(_env("N", 60))
	var steps := int(_env("STEPS", 60))
	var cap := int(_env("CAP", 6000))
	var rng := RandomNumberGenerator.new()
	rng.seed = int(_env("SEED", 5))
	var rooms := _rooms(n, rng)

	# A. Las reglas, paso a paso.
	var steps_total := 0
	var step_diffs := 0
	var ok_moves := 0
	for r in rooms:
		var t = RoomLib.build_state(r)
		var s = Solver._prepare(t, r.h + 1, false)
		var actions: Array = []
		var sg = s.clone()
		var probe = s.clone()
		for i in steps:
			# se prefiere lo que se puede hacer: se prueba al azar sobre una copia y se anota si anduvo
			var tries := 0
			while tries < 8:
				tries += 1
				var a := {"dir": TowerLogic.DIRS[rng.randi_range(0, 3)], "mode": [0, 0, 1, 1, 1, 2][rng.randi_range(0, 5)]}
				var c = probe.clone()
				var res: Dictionary = c.try_action(a.dir, a.mode)
				if res.ok or tries == 8:
					actions.append(a)
					probe.try_action(a.dir, a.mode)
					break
			if probe.lost or probe.won:
				break
		var rows: Array = NativeSolver.sim(s, r.h + 1, t.goal_ids, actions)
		var gd: Array = []
		sg.recompute_zob()
		for a in actions:
			var res: Dictionary = sg.try_action(a.dir, a.mode)
			gd.append([1 if res.ok else 0, sg.player.x, sg.player.y, sg.player.z, sg.hang_dir.x, sg.hang_dir.y, sg.hang_dir.z, 1 if sg.lost else 0, 1 if sg.won else 0, sg.zob])
			if res.ok:
				ok_moves += 1
			if sg.lost or sg.won:
				break
		for i in gd.size():
			steps_total += 1
			if i >= rows.size():
				step_diffs += 1
				continue
			var same := true
			for k in 10:
				if int(rows[i][k]) != int(gd[i][k]):
					same = false
			if not same:
				step_diffs += 1
				if step_diffs <= 5:
					print("DIFERENCIA en el paso %d de %s: nativo %s, GDScript %s" % [i, str(r.cols), str(rows[i]), str(gd[i])])
				break
	print("reglas: %d pasos comparados (%d válidos), diferencias: %d" % [steps_total, ok_moves, step_diffs])
	check(step_diffs == 0, "las reglas nativas coinciden con GDScript")

	# B. La búsqueda.
	var compared := 0
	var bad := 0
	var t_gd := 0
	var t_na := 0
	var nat_states := 0
	var gd_states := 0
	for r in rooms:
		for adm in [false, true]:
			var t = RoomLib.build_state(r)
			var o := {"max_states": cap, "goal_ids": t.goal_ids, "admissible": adm}
			var a0 := Time.get_ticks_usec()
			var g: Dictionary = Solver.solve(t.clone(), r.h + 1, o.merged({"native": false}))
			var a1 := Time.get_ticks_usec()
			var m: Dictionary = Solver.solve(t.clone(), r.h + 1, o.merged({"native": true}))
			var a2 := Time.get_ticks_usec()
			if g.status == "limit" or m.status == "limit":
				continue
			compared += 1
			t_gd += a1 - a0
			t_na += a2 - a1
			gd_states += int(g.states)
			nat_states += int(m.states)
			if g.status != m.status or g.moves != m.moves:
				bad += 1
				if bad <= 6:
					print("DIFERENCIA de búsqueda (%s): GDScript %s %d en %d estados; nativo %s %d en %d estados; %s" % ["adm" if adm else "prod", g.status, g.moves, g.states, m.status, m.moves, m.states, str(r.cols)])
			if m.status == "solved":
				var chk = RoomLib.replay(r, m.path)
				check(chk.ok, "el camino nativo se repite sobre la sala")
	print("búsqueda: %d comparadas, diferencias: %d; estados GDScript %d, nativos %d; tiempo GDScript %.1f s, nativo %.1f s" % [compared, bad, gd_states, nat_states, t_gd / 1e6, t_na / 1e6])
	check(bad == 0, "la búsqueda nativa coincide con la de GDScript")
	print("fallos: ", fails)
	quit(fails)
