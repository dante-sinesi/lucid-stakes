extends SceneTree
const RoomLib := preload("res://scripts/room_lib.gd")
const Base := preload("res://scripts/pared_gen.gd")
const Gen := preload("res://scripts/pared_gen2.gd")
func _init() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 5
	var inval := 0
	var nok := 0
	var ok := 0
	var msg := {}
	for i in 400:
		var st := Gen.make(rng, "pared", int(OS.get_cmdline_user_args()[0]), int(OS.get_cmdline_user_args()[1]), 1)
		var v := RoomLib.validate_structure(st)
		if v != "":
			inval += 1
			msg[v] = int(msg.get(v, 0)) + 1
			continue
		var c := Base.face_costs(st)
		if c[0].ok: ok += 1
		else: nok += 1
	print("invalidas ", inval, " sin solucion ", nok, " ok ", ok, " ", msg)
	quit(0)
