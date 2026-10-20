extends SceneTree
## Poses del personaje (scripts/poses.gd): cada pose existe, termina en reposo (salvo las de colgarse, que quedan colgado), colgado agarra con los dos brazos arriba y
## el juego elige la pose según la acción (empujar, tirar, trepar, colgarse...).
## Ejecutar: GAME_SANDBOX=1 tools/Godot_v4.7.2-stable_win64_console.exe --headless --path . -s tests/test_poses.gd

const Characters := preload("res://scripts/characters.gd")
const Poses := preload("res://scripts/poses.gd")

var fails := 0


func check(cond: bool, label: String) -> void:
	if not cond:
		fails += 1
		print("FAIL: ", label)


func _init() -> void:
	await test_frames()
	await test_play()
	await test_main()
	print("tests de las poses terminados, fallos: ", fails)
	quit(1 if fails > 0 else 0)


func test_frames() -> void:
	for pose in Poses.NAMES:
		if pose in ["paso", "reposo"]:
			check(Poses.frames(pose).is_empty(), "%s no tiene cuadros (paso común y reposo)" % pose)
			continue
		var fr := Poses.frames(pose)
		check(not fr.is_empty(), "la pose %s existe" % pose)
		var last_t := 0.0
		var sorted := true
		for f in fr:
			if float(f[0]) <= last_t:
				sorted = false
			last_t = float(f[0])
		check(sorted and absf(last_t - 1.0) < 0.001, "los cuadros de %s van en orden y terminan en 1" % pose)


func _wait(seconds: float) -> void:
	var t0 := Time.get_ticks_msec()
	while Time.get_ticks_msec() - t0 < int(seconds * 1000.0):
		await process_frame


func test_play() -> void:
	for i in 10:   # (calentamiento: el primer cuadro tarda y el tween ya habría terminado)
		await process_frame
	for id in ["gato", "dante", "gaby"]:
		var m := Characters.build(id, "", "")
		root.add_child(m)
		var arm_i := m.get_node("brazo_i") as Node3D
		var arm_d := m.get_node("brazo_d") as Node3D
		Poses.play(m, "empujar", 0.2)
		await _wait(0.1)
		check(arm_i.rotation.x < -0.2 and arm_d.rotation.x < -0.2 and m.rotation.x > 0.0, "%s: empujando estira los dos brazos y se inclina" % id)
		await _wait(0.3)
		check(absf(arm_i.rotation.x) < 0.01 and absf(m.rotation.x) < 0.01 and absf(arm_i.scale.y - 1.0) < 0.01, "%s: la pose de empujar vuelve al reposo" % id)
		Poses.play(m, "tirar", 0.1)
		await _wait(0.05)
		Poses.play(m, "colgarse", 0.1)
		await _wait(0.3)
		check(arm_i.rotation.x < -2.5 and arm_d.rotation.x < -2.5 and arm_i.rotation.z < 0.0 and arm_d.rotation.z > 0.0, "%s: colgado tiene los dos brazos arriba, abiertos hacia el borde" % id)
		check(arm_i.scale.y > 1.5, "%s: colgado estira los brazos hasta el borde" % id)
		var leg_before := (m.get_node("pata_i") as Node3D).rotation.x
		await _wait(0.5)
		check(arm_i.rotation.x < -2.5 and absf((m.get_node("pata_i") as Node3D).rotation.x - leg_before) > 0.001, "%s: sigue colgado y las piernas se mecen" % id)
		Poses.play(m, "subir_del_borde", 0.1)
		await _wait(0.3)
		check(absf(arm_i.rotation.x) < 0.01 and absf(arm_i.scale.y - 1.0) < 0.01, "%s: al subir del borde los brazos vuelven al reposo" % id)
		Poses.rest(m)
		m.queue_free()
	await process_frame


func test_main() -> void:
	var main = load("res://scenes/main.tscn").instantiate()
	main.test_mode = true
	main.quick_portal = true
	root.add_child(main)
	await process_frame
	while main.generating or main.logic == null:
		await process_frame
	var TL = main.logic.get_script()
	# la pose según la acción (se arma el estado a mano)
	main._act_was_y = 3
	main._act_was_hang = Vector3i.ZERO
	main._act_mode = TL.Mode.MOVE
	main.logic.hang_dir = Vector3i(1, 0, 0)
	check(main._pose_for_action() == "colgarse", "colgarse al pasar a colgado")
	main._act_was_hang = Vector3i(1, 0, 0)
	check(main._pose_for_action() == "avanzar_colgado", "avanzar de costado estando colgado")
	main.logic.hang_dir = Vector3i.ZERO
	main._act_was_y = main.logic.player.y - 1
	check(main._pose_for_action() == "subir_del_borde", "subir estando colgado")
	main._act_was_y = main.logic.player.y + 1
	check(main._pose_for_action() == "soltarse", "soltarse estando colgado y bajar")
	main._act_was_hang = Vector3i.ZERO
	main._act_was_y = main.logic.player.y - 1
	check(main._pose_for_action() == "trepar", "subir un escalón")
	main._act_was_y = main.logic.player.y + 1
	check(main._pose_for_action() == "caer", "bajar")
	main._act_was_y = main.logic.player.y
	main._act_mode = TL.Mode.GRAB
	main.logic.last_grab = "push"
	check(main._pose_for_action() == "empujar", "empujar")
	main.logic.last_grab = "pull"
	check(main._pose_for_action() == "tirar", "tirar")
	main.logic.last_grab = ""
	main._act_mode = TL.Mode.MOVE
	check(main._pose_for_action() == "paso", "paso común")
	main._cancel_jobs()
	main.queue_free()
	await process_frame
