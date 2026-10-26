extends SceneTree
## Captura la animación del contrato resuelto en varios instantes. Uso: GAME_SANDBOX=1 godot --path . --rendering-driver opengl3 --resolution 1500x1000 -s tests/capturas/shot_contrato_resuelto.gd -- PREFIJO [cumplido 1|0] [monto]
const Pantalla := preload("res://scripts/ui/contrato_resuelto.gd")
const Arte := preload("res://scripts/ui/contract_art.gd")


func _init() -> void:
	var args := OS.get_cmdline_user_args()
	var fondo := ColorRect.new()
	fondo.color = Color(0.20, 0.14, 0.32)
	fondo.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.add_child(fondo)
	var p = Pantalla.new()
	root.add_child(p)
	var cumplido := (args[1] != "0") if args.size() > 1 else true
	var monto := int(args[2]) if args.size() > 2 else (340 if cumplido else -145)
	p.mostrar({"objetivo": "especiales", "rareza": Arte.Rareza.EPICA, "texto": "Purifica 6 bloques especiales en la próxima torre"}, cumplido, monto)
	p.set_process(false)
	var tiempos := [0.5, 1.2, 1.62, 1.75, 2.2, 3.0, 4.5]
	for i in tiempos.size():
		p.ir_a(tiempos[i])
		await create_timer(0.15).timeout
		root.get_texture().get_image().save_png("%s_%d.png" % [args[0], i])
	quit(0)
