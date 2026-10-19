extends SceneTree
## Pruebas de los consumibles nuevos: los conversores (uno por tipo de bloque), Tótem, Escudo, Doble salto y Teletransporte (headless).
## Ejecutar: tools/Godot_v4.7.2-stable_win64_console.exe --headless --path . -s tests/test_consumables.gd

const TowerLogic := preload("res://scripts/tower_logic.gd")
const Items := preload("res://scripts/items.gd")
const ItemIcons := preload("res://scripts/item_icons.gd")
const RunState := preload("res://scripts/run_state.gd")
const K := TowerLogic.Kind

var fails := 0


func check(cond: bool, label: String) -> void:
	if not cond:
		fails += 1
		print("FAIL: ", label)


func _init() -> void:
	test_catalog()
	test_converters()
	test_double_jump()
	test_shield()
	test_teleport()
	test_totem()
	await test_main()
	print("tests de los consumibles nuevos terminados, fallos: ", fails)
	quit(1 if fails > 0 else 0)


## Una torre chica: piso de 6 x 6 y el jugador parado en (2, 1, 2).
func fresh() -> TowerLogic:
	var t := TowerLogic.new()
	t.size = Vector2i(6, 6)
	t.goal_y = 40
	t.collapse_every = 100000
	t.moves_to_collapse = 100000
	for x in 6:
		for z in 6:
			t.add_block(Vector3i(x, 0, z), true)
	t.player = Vector3i(2, 1, 2)
	return t


func test_catalog() -> void:
	var ids := ["conv_roca", "conv_hielo", "conv_agrietado", "conv_trampa", "conv_pinchos", "conv_pesado", "conv_bomba", "conv_catapulta", "totem", "escudo", "doble_salto", "teletransporte"]
	for id in ids:
		var it := Items.get_item(id)
		check(not it.is_empty() and it.type == Items.Type.CONSUMABLE and it.name != "" and it.desc != "" and ItemIcons.has_icon(id), "%s existe, tiene nombre, descripción e ícono" % id)
	check(TowerLogic.CONVERTERS.size() == 8 and TowerLogic.CONVERTERS.values().size() == 8, "hay un conversor por cada tipo de bloque")
	var kinds := {}
	for id in TowerLogic.CONVERTERS:
		kinds[TowerLogic.CONVERTERS[id]] = true
	check(kinds.size() == 8, "y cada uno a un tipo distinto")
	for k in K.values():
		check(kinds.has(k), "hay conversor para el tipo %d" % k)
	check(Items.needs_target("teletransporte") and Items.needs_target("conv_hielo") and not Items.needs_target("freno") and Items.is_passive("totem") and Items.is_passive("escudo") and not Items.is_passive("doble_salto"), "los que piden bloque y los que se usan solos")
	check(Items.get_item("totem").tier == Items.Tier.RARO and Items.get_item("teletransporte").tier == Items.Tier.RARO and Items.get_item("conv_roca").tier == Items.Tier.CONSUMIBLE and Items.get_item("escudo").tier == Items.Tier.COMUN, "rarezas: tótem y teletransporte raros, escudo común, polvo de roca barato")
	var old := RunState.from_dict({"consumables": ["hielo_a_roca", "catapulta_de_bolsillo", "freno"]})
	check(old.consumables == ["conv_roca", "conv_catapulta", "freno"], "los guardados viejos pasan a los conversores nuevos")


func test_converters() -> void:
	var t := fresh()
	var cell := Vector3i(3, 1, 2)
	t.add_block(cell)
	for id in TowerLogic.CONVERTERS:
		var kind: int = TowerLogic.CONVERTERS[id]
		if kind == K.NORMAL:
			continue
		var res := t.use_item_at(id, cell)
		check(res.ok and t.kind_at(cell) == kind, "%s convierte el bloque elegido" % id)
		check(not t.use_item_at(id, cell).ok, "%s: ya es de ese tipo" % id)
	check(t.bomb_timer.is_empty() or not t.bomb_timer.has(t.blocks[cell]), "(la bomba ya no cuenta al volver a ser otra cosa)")
	t.use_item_at("conv_bomba", cell)
	check(t.bomb_timer.get(t.blocks[cell], -1) == TowerLogic.NEW_BOMB_FUSE, "Pólvora: la bomba nueva empieza con cuenta 6")
	t.use_item_at("conv_roca", cell)
	check(t.kind_at(cell) == K.NORMAL and not t.bomb_timer.has(t.blocks[cell]), "Polvo de roca sobre una bomba la desarma y la vuelve común")
	var before := t.zob
	t.use_item_at("conv_hielo", cell)
	var after := t.zob
	t.recompute_zob()
	check(after == t.zob and before != after, "la huella del estado queda al día")
	# no se puede cambiar el bloque donde se está parado, el core, ni un lugar vacío
	check(not t.use_item_at("conv_hielo", t.player + Vector3i(0, -1, 0)).ok, "el bloque en el que estás parado no se cambia")
	check(not t.use_item_at("conv_hielo", Vector3i(0, 0, 0)).ok, "los bloques fijos tampoco")
	check(not t.use_item_at("conv_hielo", Vector3i(4, 5, 4)).ok, "ni un lugar vacío")
	# con el solucionador (copias que comparten diccionarios): convertir en una copia no toca la otra
	var c := t.clone()
	c.use_item_at("conv_pinchos", cell)
	check(t.kind_at(cell) == K.ICE and c.kind_at(cell) == K.SPIKES, "convertir en una copia no cambia la original")


func test_double_jump() -> void:
	var t := fresh()
	t.add_block(Vector3i(3, 1, 2))
	t.add_block(Vector3i(3, 2, 2))   # un pilar de 2: no se puede trepar caminando
	check(not t.try_action(Vector3i(1, 0, 0), TowerLogic.Mode.MOVE).ok, "sin doble salto, un pilar de 2 bloquea")
	check(t.use_item("doble_salto").ok and t.double_jump and not t.use_item("doble_salto").ok, "Doble salto se arma (una sola vez)")
	var res := t.try_action(Vector3i(1, 0, 0), TowerLogic.Mode.MOVE)
	check(res.ok and t.player == Vector3i(3, 3, 2) and not t.double_jump and t.jump_used, "con el doble salto se sube el pilar de 2 y se gasta")
	# un salto común sigue siendo uno solo y no gasta el doble salto
	var u := fresh()
	u.add_block(Vector3i(3, 1, 2))
	u.use_item("doble_salto")
	check(u.try_action(Vector3i(1, 0, 0), TowerLogic.Mode.MOVE).ok and u.player == Vector3i(3, 2, 2) and u.double_jump, "un escalón común se trepa de a uno y el doble salto sigue armado")
	# no sirve si el techo lo impide
	var w := fresh()
	w.add_block(Vector3i(3, 1, 2))
	w.add_block(Vector3i(3, 2, 2))
	w.add_block(Vector3i(2, 3, 2))   # techo: no hay lugar para saltar
	w.use_item("doble_salto")
	check(not w.try_action(Vector3i(1, 0, 0), TowerLogic.Mode.MOVE).ok and w.double_jump, "con un techo encima no se puede saltar")
	check(fresh().clone().double_jump == false and u.clone().double_jump, "las copias conservan el doble salto armado")


func test_shield() -> void:
	var t := fresh()
	t.add_block(Vector3i(3, 1, 2), false, K.BOMB, 1)   # una bomba que explota en el próximo movimiento
	t.shield = true
	check(t.try_action(Vector3i(0, 0, 1), TowerLogic.Mode.MOVE).ok, "(un movimiento)")
	check(not t.lost and t.shield_used and not t.shield and t.exploded and not t.blocks.has(Vector3i(3, 1, 2)), "con Escudo la bomba explota sola: no se pierde y el escudo se rompe")
	check(t.blocks.has(Vector3i(0, 0, 0)) and t.blocks.size() > 30, "y la torre sigue en pie")
	var u := fresh()
	u.add_block(Vector3i(3, 1, 2), false, K.BOMB, 1)
	u.try_action(Vector3i(0, 0, 1), TowerLogic.Mode.MOVE)
	check(u.lost, "sin Escudo la bomba te pierde como siempre")
	check(fresh().use_item("escudo").ok == false, "el Escudo no se usa a mano")


func test_teleport() -> void:
	var t := fresh()
	t.add_block(Vector3i(5, 1, 2))
	t.add_block(Vector3i(5, 6, 5))   # lejos (más de 5 cubos)
	check(not t.use_item_at("teletransporte", Vector3i(5, 6, 5)).ok, "a más de 5 cubos no se puede")
	check(t.target_error("teletransporte", Vector3i(5, 6, 5)).contains("5 cubos"), "y dice por qué")
	var res := t.use_item_at("teletransporte", Vector3i(5, 1, 2))
	check(res.ok and t.player == Vector3i(5, 2, 2) and t.hang_dir == Vector3i.ZERO and t.trail.size() == 2, "se aparece encima del bloque elegido")
	check(t.moves_made == 0, "y no cuenta como movimiento")
	# no se puede si encima no hay lugar
	var u := fresh()
	u.add_block(Vector3i(4, 1, 2))
	u.add_block(Vector3i(4, 2, 2))
	check(not u.use_item_at("teletransporte", Vector3i(4, 1, 2)).ok, "bloque tapado por otro: no hay lugar")
	check(u.use_item_at("teletransporte", Vector3i(4, 2, 2)).ok and u.player == Vector3i(4, 3, 2), "el de arriba sí")
	# pinchos: no se pisan
	var v := fresh()
	v.add_block(Vector3i(3, 1, 2), false, K.SPIKES)
	check(not v.use_item_at("teletransporte", Vector3i(3, 1, 2)).ok, "sobre unos pinchos no")
	# el mismo bloque donde ya se está
	check(not fresh().use_item_at("teletransporte", Vector3i(2, 0, 2)).ok, "el bloque donde ya estás no")
	# colgado: se suelta
	var h := fresh()
	h.add_block(Vector3i(2, 1, 4))
	h.hang_dir = Vector3i(0, 0, 1)
	check(h.use_item_at("teletransporte", Vector3i(2, 1, 4)).ok and h.hang_dir == Vector3i.ZERO, "colgado, el teletransporte te suelta")


func test_totem() -> void:
	var run := RunState.new()
	run.stage = 5
	var base := run.restart_cost()
	check(base > 0 and run.restart_cost(true) == 0, "reintentar por voluntad cuesta claridad, pero después de morir no (el costo ya es la vida)")
	run.consumables.assign(["totem", "freno"])
	check(run.restart_cost() == base, "con Tótem, reintentar por voluntad (sin morir) cuesta igual")
	check(run.restart_cost(true) == 0 and run.can_afford_restart(true), "con Tótem, reintentar después de morir es gratis")
	run.note_retry(true)
	check(run.consumables == ["freno"] and run.retries == 1, "el Tótem se gasta al reintentar gratis")
	check(run.restart_cost(true) == 0, "y sin él, después de morir sigue sin costar claridad (el costo es la vida)")
	# después de morir el Tótem tiene prioridad (cubre también la vida) y el seguro queda para otro reintento
	run.consumables.assign(["totem"])
	run.insurance = true
	var lives_before := run.lives
	run.note_retry(true)
	check(run.insurance and run.consumables.is_empty() and run.lives == lives_before, "si había seguro y Tótem, se gasta el Tótem (sin perder una vida) y el seguro queda")
	check(Items.get_item("totem").desc.contains("sin costo"), "la descripción lo dice")


func test_main() -> void:
	var main = load("res://scenes/main.tscn").instantiate()
	main.test_mode = true
	main.quick_portal = true
	root.add_child(main)
	await process_frame
	while main.generating or main.logic == null:
		await process_frame
	# escudo: se conecta al estado de la etapa y se gasta al absorber una bomba
	var t := fresh()
	t.add_block(Vector3i(3, 1, 2), false, K.BOMB, 1)
	main.stage_start = t
	main.run.consumables.assign(["escudo", "teletransporte"])
	main.restart()
	check(main.logic.shield, "con un Escudo en el inventario, la lógica arranca protegida")
	main._apply(Vector3i(0, 0, 1), TowerLogic.Mode.MOVE)
	await create_timer(0.1).timeout
	check(not main.logic.lost and not main.run.consumables.has("escudo") and main.run.consumables == ["teletransporte"], "el Escudo se gasta al salvarte de la bomba")
	main.busy = false
	# teletransporte: se elige un bloque
	t = fresh()
	t.add_block(Vector3i(4, 1, 2))
	main.stage_start = t
	main.restart()
	main.use_consumable_slot(0)
	check(main.targeting.get("id", "") == "teletransporte" and main.run.consumables == ["teletransporte"], "el Teletransporte pide elegir un bloque")
	main.confirm_target(Vector3i(9, 0, 9))
	check(not main.targeting.is_empty() and main.run.consumables == ["teletransporte"], "un bloque que no sirve no lo gasta y se sigue eligiendo")
	main.confirm_target(Vector3i(4, 1, 2))
	check(main.targeting.is_empty() and main.run.consumables.is_empty() and main.logic.player == Vector3i(4, 2, 2), "al elegir uno válido te teletransportás y se gasta")
	main.busy = false
	# cancelar
	main.run.consumables.assign(["conv_hielo"])
	main.use_consumable_slot(0)
	check(not main.targeting.is_empty(), "(elegir de nuevo)")
	main.use_consumable_slot(0)
	check(main.targeting.is_empty() and main.run.consumables == ["conv_hielo"], "apretar la misma tecla otra vez cancela sin gastar")
	main.use_consumable_slot(0)
	main.cancel_targeting()
	check(main.targeting.is_empty() and main.run.consumables == ["conv_hielo"], "cancelar no gasta")
	# elegir con el mouse: el rayo desde la cámara cruza el bloque
	main.logic.add_block(Vector3i(3, 1, 3))
	main._dev_rebuild_blocks()
	main.cam.make_current()
	var screen_pos: Vector2 = main.cam.unproject_position(Vector3(3.5, 1.5, 3.5))
	var picked: Vector3i = main.pick_block(screen_pos)
	check(picked == Vector3i(3, 1, 3), "pick_block encuentra el bloque que se ve bajo el mouse (%s)" % str(picked))
	check(main.pick_block(Vector2(-500, -500)) == main.NO_CELL, "y nada si el mouse apunta al vacío")
	# Tótem: reintentar después de morir es gratis
	main.run.consumables.assign(["totem"])
	main.run.claridad = 0
	main.logic.lost = true
	main.logic.lost_reason = "Caíste al vacío"
	main.request_restart()
	check(main.run.consumables.is_empty() and not main.run_over and main.run.retries == 1, "con Tótem se reintenta sin plata y se gasta")
	main._cancel_jobs()
	main.queue_free()
	await process_frame
