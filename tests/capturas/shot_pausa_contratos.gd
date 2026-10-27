extends SceneTree
## Captura el menú de pausa con los contratos activos a la derecha (solo íconos). Uso: GAME_SANDBOX=1 godot --path . --rendering-driver opengl3 --resolution 1500x1000 -s tests/capturas/shot_pausa_contratos.gd -- ARCHIVO.png [cantidad] [foco]
const Pausa := preload("res://scripts/ui/pause_menu.gd")
const Arte := preload("res://scripts/ui/contract_art.gd")


func _init() -> void:
	var args := OS.get_cmdline_user_args()
	var fondo := ColorRect.new()
	fondo.color = Color(0.20, 0.14, 0.32)
	fondo.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.add_child(fondo)
	var p = Pausa.new()
	root.add_child(p)
	p.visible = true
	p.set_info(["Etapa 3 de 15", "Peaje: 235"])
	var todos := [{"objetivo": "movimientos", "rareza": Arte.Rareza.COMUN, "titulo": "Ahorrador de pasos", "condiciones": ["Termina la torre con el 20 % de los movimientos sin gastar", "Con fianza de 120"]}, {"objetivo": "especiales", "rareza": Arte.Rareza.EPICA, "titulo": "Cazador de especiales", "condiciones": ["Purifica 4 bloques especiales"]}, {"objetivo": "claridad", "rareza": Arte.Rareza.IMPOSIBLE, "titulo": "Cosechador", "condiciones": ["Junta 2000 de claridad en la torre"]}, {"objetivo": "racha", "rareza": Arte.Rareza.RARA, "titulo": "Racha de oro", "condiciones": ["Llega a una racha de 6"]}]
	p.set_contratos(todos.slice(0, int(args[1]) if args.size() > 1 else 3))
	await create_timer(0.5).timeout
	if args.size() > 2:   # el tercer argumento: el contrato (0, 1, ...) al que se llega con el teclado
		p.contratos.get_node("contrato_%d" % int(args[2])).grab_focus()
	await create_timer(0.4).timeout
	root.get_texture().get_image().save_png(args[0])
	quit(0)
