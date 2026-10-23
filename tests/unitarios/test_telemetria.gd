extends SceneTree
## La telemetría local (telemetry.gd): se anota en un archivo de la máquina del jugador, sin enviar nada.
## Ejecutar: GAME_SANDBOX=1 tools/Godot_v4.7.2-stable_win64_console.exe --headless --path . -s tests/unitarios/test_telemetria.gd

const Telemetry := preload("res://scripts/datos/telemetry.gd")

var fails := 0


func check(cond: bool, label: String) -> void:
	if not cond:
		fails += 1
		print("FAIL: ", label)


func _init() -> void:
	Telemetry.path = "user://test_telemetria.jsonl"
	Telemetry.clear()
	check(Telemetry.read_all().is_empty(), "al empezar no hay nada")
	Telemetry.log_event("torre", {"stage": 3, "outcome": "muerta"})
	Telemetry.log_event("peaje", {"stage": 3, "choice": "pagar"})
	var all := Telemetry.read_all()
	check(all.size() == 2 and all[0].kind == "torre" and int(all[0].stage) == 3 and all[1].choice == "pagar" and all[0].has("t") and int(all[0].v) == Telemetry.VERSION, "se anotan los eventos con hora y versión")
	Telemetry.enabled = false
	Telemetry.log_event("torre", {})
	Telemetry.enabled = true
	check(Telemetry.read_all().size() == 2, "apagada no anota")
	check(Telemetry.folder() != "", "hay una carpeta que abrir")
	await _juego()
	Telemetry.clear()
	print("tests de telemetría terminados, fallos: ", fails)
	quit(1 if fails > 0 else 0)


## Desde el juego: morir en una torre, ganar, el casino y el peaje quedan anotados.
func _juego() -> void:
	Telemetry.clear()
	var main = load("res://scenes/main.tscn").instantiate()
	main.test_mode = true
	main.quick_portal = true
	main.toll_in_tests = true
	root.add_child(main)
	await process_frame
	while main.generating or main.torre == null:
		await process_frame
	main.in_menu = false
	main.torre.perder("Caíste")
	main.enter_casino(true)
	main.casino.cell = main.casino.lay.exit
	main.casino.step(Vector2i(0, -1))
	await process_frame
	main._toll_options = main.casino.toll_dialog().options
	main._on_dialogue_chosen(1)   # rehacer la torre
	main.end_run(false, "x")
	var kinds := []
	for e in Telemetry.read_all():
		kinds.append(e.kind)
	check(kinds.has("torre") and kinds.has("casino") and kinds.has("peaje") and kinds.has("run_fin"), "se anotan torre, casino, peaje y fin del run (%s)" % str(kinds))
	main.queue_free()
	await process_frame
