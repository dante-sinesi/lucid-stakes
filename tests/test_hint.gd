extends SceneTree
## Pruebas de la pista (que se ve en el tutorial) (headless).
## Ejecutar: tools/Godot_v4.7.2-stable_win64_console.exe --headless --path . -s tests/test_hint.gd

const Gen := preload("res://scripts/tower_gen.gd")
const Hint := preload("res://scripts/hint.gd")
const TowerLogic := preload("res://scripts/tower_logic.gd")

var fails := 0


func check(cond: bool, label: String) -> void:
	if not cond:
		fails += 1
		print("FAIL: ", label)


func _init() -> void:
	await test_follow_hints()
	await test_training_mode()
	print("tests de la pista terminados, fallos: ", fails)
	quit(1 if fails > 0 else 0)


## Seguir la pista paso a paso (sin caída de la fila base) lleva a ganar la torre.
func test_follow_hints() -> void:
	var r := Gen.generate_stage(1, 4, 0.3, {"tries": 6, "climb": 0.5, "max_states": 2000})
	check(r.ok and not r.logic.row_platforms.is_empty(), "la torre generada trae las plataformas de cada fila")
	var t = r.logic.clone()
	t.collapse_every = 1 << 30
	t.moves_to_collapse = 1 << 30
	var n := 0
	var seen := {}
	var looped := false
	var last_reached := 0
	var monotone := true
	while not t.won and not t.lost and n < 60:
		var key := [t.player, t.hang_dir, t.zob, t.reached_row]  # mismo estado con la misma meta = bucle (pasar de nuevo por una celda con otra meta es normal)
		looped = looped or seen.has(key)
		seen[key] = true
		var h := Hint.best_move(t)
		if not h.ok:
			break
		check(h.mode in [TowerLogic.Mode.MOVE, TowerLogic.Mode.GRAB, TowerLogic.Mode.HANG], "la pista trae un modo valido")
		check(t.try_action(h.dir, h.mode).ok, "la pista siempre es una accion valida")
		n += 1
		monotone = monotone and t.reached_row >= last_reached
		last_reached = t.reached_row
	check(not looped, "siguiendo la pista nunca se vuelve a un estado ya visto (sin bucles)")
	check(monotone and t.reached_row >= 3, "la fila alcanzada solo sube (%d)" % t.reached_row)
	check(t.won and not t.lost, "siguiendo la pista se gana la torre (%d movimientos, camino de referencia %d)" % [n, r.path.size()])
	check(n <= r.path.size() + 4, "la pista no da vueltas de mas")
	# Ya ganada: no hay mas pista.
	check(not Hint.best_move(t).ok, "sin pista cuando ya se gano")
	# Texto de la tecla
	var keys := func(d: Vector3i) -> String: return "W" if d == Vector3i(0, 0, -1) else "S"
	check(Hint.describe(TowerLogic.Mode.MOVE, Vector3i(0, 0, -1), keys) == "W", "texto: solo la tecla")
	check(Hint.describe(TowerLogic.Mode.GRAB, Vector3i(0, 0, 1), keys) == "Shift + S", "texto: Shift + tecla")
	check(Hint.describe(TowerLogic.Mode.HANG, Vector3i(0, 0, -1), keys) == "Espacio + W", "texto: Espacio + tecla")


func test_training_mode() -> void:
	var main = load("res://scenes/main.tscn").instantiate()
	main.test_mode = true
	root.add_child(main)
	await process_frame
	while main.generating or main.logic == null:
		await process_frame
	# El tutorial reemplaza al modo entrenamiento: hay un botón Tutorial y no el selector de etapas.
	main.open_main_menu()
	var mm = main.main_menu
	check(not mm.buttons.has("entrenamiento") and not mm.buttons.has("tutorial"), "ya no hay Modo entrenamiento ni un boton Tutorial suelto")
	mm.buttons["nueva"].pressed.emit()   # el tutorial es la primera tarjeta de Nueva partida
	check(mm.scenarios.visible and mm.scenarios.play_buttons.has("tutorial") and mm.scenarios.cards.keys()[0] == "tutorial", "el tutorial es la primera tarjeta del selector")
	mm.scenarios.play_buttons["tutorial"].pressed.emit()
	await process_frame
	check(main.training and not main.in_menu and main.casino != null and main.story_kind == "intro" and main.dialogue.is_active(), "Tutorial empieza en la taberna con el tabernero")
	main.dialogue.skip_all()
	main.casino.cell = main.casino.lay.exit
	main.casino.step(Vector2i(0, -1))   # la puerta de atras: empiezan las lecciones
	while main.generating or main.logic == null:
		await process_frame
	check(main.training and main.tutorial_index == 0 and main.casino == null and main.logic != null, "al cruzar la puerta arranca la primera leccion")
	check(main.hud.text.contains("TUTORIAL") and main.hud.text.contains("Lección 1/"), "el HUD indica la leccion")
	# P muestra la pista; P otra vez la oculta
	check(not main.hint_on and not main.hint_label.visible, "la pista arranca oculta")
	main.toggle_hint()
	check(main.hint_on and main.hint_label.visible, "P muestra la pista")
	var waited := 0
	while main.hint_label.text.contains("calculando") and waited < 600:
		await process_frame
		waited += 1
	var txt: String = main.hint_label.text
	check(txt.begins_with("Pista: ") and not txt.contains("calculando"), "se muestra el mejor proximo movimiento (%s)" % txt)
	var key_ok := false
	for k in ["W", "A", "S", "D"]:
		key_ok = key_ok or txt.ends_with(k)
	check(key_ok, "la pista nombra una tecla de direccion")
	main.toggle_hint()
	check(not main.hint_on and not main.hint_label.visible, "P otra vez oculta la pista")
	# Volver al menu sale del tutorial
	main.open_main_menu()
	check(not main.training and main.tutorial_index == -1 and not main.hint_on, "volver al menu sale del tutorial")
	# El modo normal no tiene pista
	main.start_game()
	main.toggle_hint()
	check(not main.hint_on, "P no hace nada fuera del tutorial")
	main.open_main_menu()
	main._cancel_jobs()
	main.queue_free()
	await process_frame
