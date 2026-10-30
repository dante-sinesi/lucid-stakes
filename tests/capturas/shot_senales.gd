extends SceneTree
## Captura de las señales sin texto: rebobinar, cancelado, candado, un ítem que vuela y se deshace en luz, un casillero que rechaza, y las ventanas de claridad y de logro.
## Uso: GAME_SANDBOX=1 godot --path . --rendering-driver opengl3 --resolution 1280x720 -s tests/capturas/shot_senales.gd -- PREFIJO
const Profile := preload("res://scripts/datos/profile.gd")
const RunState := preload("res://scripts/datos/run_state.gd")
const SenalPantalla := preload("res://scripts/ui/senal_pantalla.gd")
const ItemVuela := preload("res://scripts/ui/item_vuela.gd")
const ItemBar := preload("res://scripts/ui/item_bar.gd")
const ResumenClaridad := preload("res://scripts/ui/resumen_claridad.gd")
const VentanaLogro := preload("res://scripts/ui/ventana_logro.gd")


func _frames(n: int) -> void:
	for i in n:
		await process_frame


func _foto(nombre: String) -> void:
	root.get_viewport().get_texture().get_image().save_png(nombre)


func _init() -> void:
	var pref: String = OS.get_cmdline_user_args()[0] if OS.get_cmdline_user_args().size() > 0 else "capturas/sen"
	Profile.path = "user://shot_profile_senales.json"
	Profile.reset()
	Profile.mark_tutorial_done()
	var fondo := ColorRect.new()
	fondo.color = Color(0.16, 0.12, 0.28)
	fondo.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var capa0 := CanvasLayer.new()
	capa0.layer = -1
	root.add_child(capa0)
	capa0.add_child(fondo)
	var capa := CanvasLayer.new()
	root.add_child(capa)
	var run := RunState.new()
	run.consumables.assign(["freno", "totem", "reloj_de_arena"])
	run.boosts.assign(["segundo_aliento", "midas"])
	var izq := ItemBar.new()
	capa.add_child(izq)
	izq.edge = 0
	izq.setup(run, ItemBar.Kind.CONSUMABLE, true)
	var der := ItemBar.new()
	capa.add_child(der)
	der.edge = 1
	der.setup(run, ItemBar.Kind.BOOST, false)
	var senal := SenalPantalla.new()
	capa.add_child(senal)
	await _frames(10)
	senal.mostrar(SenalPantalla.Tipo.REBOBINAR)
	await _frames(14)
	_foto("%s_1_rebobinar.png" % pref)
	await _frames(70)
	senal.mostrar(SenalPantalla.Tipo.NO_REBOBINAR)
	await _frames(14)
	_foto("%s_2_no_rebobinar.png" % pref)
	await _frames(70)
	senal.mostrar(SenalPantalla.Tipo.CANDADO)
	await _frames(12)
	_foto("%s_3_candado.png" % pref)
	await _frames(60)
	izq.rechazar(0)
	senal.mostrar(SenalPantalla.Tipo.RECHAZO, Vector2(700, 300))
	await _frames(6)
	_foto("%s_4_rechazo.png" % pref)
	await _frames(60)
	ItemVuela.volar(capa, "totem", izq.rect_de(1))
	await _frames(12)
	_foto("%s_5_vuelo_1.png" % pref)
	await _frames(30)
	_foto("%s_6_vuelo_2.png" % pref)
	await _frames(14)
	_foto("%s_7_luz.png" % pref)
	await _frames(60)
	var res := ResumenClaridad.new()
	capa.add_child(res)
	res.mostrar("Entras al casino", 420, [{"id": "", "nombre": "Torre", "valor": 310}, {"id": "", "nombre": "Dados", "valor": 64}, {"id": "caja_fuerte", "nombre": "Caja fuerte", "valor": 63}, {"id": "alcancia", "nombre": "Alcancía", "valor": 126}])
	await _frames(50)
	_foto("%s_8_resumen_entrada.png" % pref)
	res.cerrar()
	res.mostrar("Empiezas la torre 4", 188, [{"id": "interes", "nombre": "Interés", "valor": 31}, {"id": "", "nombre": "Farolín te devuelve", "valor": 12}, {"id": "ahorro", "nombre": "Ahorro", "valor": 20}, {"id": "bolsillo_de_luz", "nombre": "Bolsillo de luz", "valor": 60}])
	await _frames(50)
	_foto("%s_9_resumen_salida.png" % pref)
	res.cerrar()
	var logro := VentanaLogro.new()
	capa.add_child(logro)
	logro.mostrar("¡Personaje nuevo!", ["Conejito"])
	await _frames(50)
	_foto("%s_10_logro.png" % pref)
	quit()
