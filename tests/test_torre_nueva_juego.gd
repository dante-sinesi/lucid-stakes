extends SceneTree
## La torre nueva dentro del juego (main.gd): arranque, victoria con claridad al run, muertes con las vidas del run, consumibles y guardado.
## Uso: GAME_SANDBOX=1 godot --headless --path . -s tests/test_torre_nueva_juego.gd
const Scenarios := preload("res://scripts/scenarios.gd")
const Profile := preload("res://scripts/profile.gd")
var fallos := 0
func _ok(c: bool, m: String) -> void:
	print(("ok  " if c else "FALLA ") + m)
	if not c:
		fallos += 1
func _frames(n: int) -> void:
	for i in n:
		await process_frame
func _jugar_sala(main, k: int) -> void:
	for a in main.nueva.t.salas[k].d.camino:
		main.nueva.accion(Vector3i(int(a[0]), 0, int(a[1])), int(a[2]))
func _init() -> void:
	OS.set_environment("GAME_TORRE_NUEVA", "1")
	Profile.path = "user://test_profile_tn.json"
	Profile.reset()
	var main = load("res://scenes/main.tscn").instantiate()
	main.test_mode = true
	main.quick_portal = true
	main.test_mode_jobs = false
	root.add_child(main)
	await _frames(4)
	main.start_game()
	await _frames(4)
	_ok(main.nueva != null and main.nueva.t != null and main.nueva.t.salas.size() >= 5, "al empezar el run hay una torre nueva de %d salas" % (main.nueva.t.salas.size() if main.nueva != null and main.nueva.t != null else 0))
	_ok(main.logic == null and main.stage_number == 1, "la etapa 1 no usa la lógica vieja")
	_ok(main.nueva.t.externo and main.nueva.t.etapa == 1, "las vidas son las del run y la torre sabe su etapa")
	var vidas0: int = main.run.lives
	# muerte: se acaban los movimientos de la sala 1 -> pierde una vida del run y la sala vuelve a empezar
	var cam: Array = main.nueva.t.salas[0].d.camino
	main.nueva.t.salas[0].max_mov = 2
	main.nueva.t.mov_extra = 0
	for i in 2:
		main.nueva.accion(Vector3i(int(cam[i][0]), 0, int(cam[i][1])), int(cam[i][2]))
	_ok(main.run.lives == vidas0 - 1 and main.nueva.t.indice == 0 and main.nueva.t.movs == 0, "morir resta una vida del run y reinicia la sala (%d vidas)" % main.run.lives)
	main.nueva.t.salas[0].max_mov = 999
	# consumible: Freno suma movimientos
	main.run.consumables.append("freno")
	var antes: int = main.nueva.t.max_mov()
	main.use_consumable_slot(main.run.consumables.size() - 1)
	_ok(main.nueva.t.max_mov() == antes + 5 and not main.run.consumables.has("freno"), "Freno suma 5 movimientos y se gasta")
	main.run.consumables.append("conv_roca")
	var n_cons: int = main.run.consumables.size()
	main.use_consumable_slot(n_cons - 1)
	_ok(main.run.consumables.size() == n_cons, "un consumible que todavía no funciona no se gasta")
	# jugar toda la torre con los caminos: claridad al run y casino
	var claridad0: int = main.run.claridad
	for k in main.nueva.t.salas.size():
		_jugar_sala(main, k)
	await _frames(4)
	_ok(main.casino != null and main.nueva == null, "al llegar al portal sigue el casino y la torre se saca")
	_ok(main.run.claridad > claridad0, "la claridad de la torre pasó al run (%d -> %d)" % [claridad0, main.run.claridad])
	main.leave_casino()
	await _frames(6)
	_ok(main.stage_number == 2 and main.nueva != null and main.nueva.t.etapa == 2, "se sale del casino a la torre nueva de la etapa 2")
	# guardado y continuar
	main.save_game()
	var data: Dictionary = main.SaveGame.read()
	_ok(str(data.get("phase", "")) == "tower" and bool(data.get("nueva", false)), "el guardado marca la torre nueva")
	# sin vidas: termina el run
	main.run.lives = 0
	main.nueva.t.salas[0].max_mov = 1
	var c2: Array = main.nueva.t.salas[0].d.camino
	main.nueva.accion(Vector3i(int(c2[0][0]), 0, int(c2[0][1])), int(c2[0][2]))
	await _frames(2)
	_ok(main.run_over, "sin vidas, morir termina el run")
	Profile.reset()
	print("fallos: ", fallos)
	quit(1 if fallos > 0 else 0)
