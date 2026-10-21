extends Control
## Estudio de las salas nuevas (torre sin núcleo, ver docs/torre_salas_reglas.md): abre una biblioteca de salas (jsonl de tools/salas_nuevas.exe), las muestra
## desde detrás del jugador (o en diagonal), reproduce su camino más corto cuadro por cuadro, deja corregirlas (poner y sacar bloques, bloque checkpoint,
## bloque fijo, mover el jugador), las resuelve de nuevo con el solucionador nativo y guarda la biblioteca.
## Archivo: variable de entorno SN_LIB, o bibliotecas/salas_nuevas.jsonl.

const Vista := preload("res://salas_nuevas/vista.gd")
const Motor := preload("res://salas_nuevas/motor.gd")
const Nat := preload("res://salas_nuevas/nativo.gd")
const RoomView := preload("res://scripts/room_view.gd")
const Reglas := preload("res://salas_nuevas/reglas.gd")


class Mira:
	var blocks := {}


var salas: Array = []
var actual := -1
var archivo := ""
var cuadros: Array = []     # estados (Motor) del camino: el 0 es el de partida
var enc_por_cuadro: Array = []   # celdas de checkpoint prendidas en cada cuadro
var paso := 0
var vista_atras := true
var yaw := 35.0
var pitch := 35.0
var dist := 16.0
var centro := Vector3(5.5, 4.0, 5.5)
var herramienta := "poner"
var editado := false

var vp: SubViewport
var contenedor: SubViewportContainer
var cam: Camera3D
var bloques_nodo: Node3D
var lista: ItemList
var info: RichTextLabel
var slider: HSlider
var estado: Label
var timer: Timer
var arrastrando := false
var _suprimir := false


func _ready() -> void:
	archivo = OS.get_environment("SN_LIB")
	if archivo == "":
		archivo = ProjectSettings.globalize_path("res://bibliotecas/salas_nuevas.jsonl")
	_armar_interfaz()
	cargar(archivo)
	if not salas.is_empty():
		elegir(0)


# --- interfaz ---------------------------------------------------------------------------------------------------------------------------------

func _boton(texto: String, f: Callable) -> Button:
	var b := Button.new()
	b.text = texto
	b.pressed.connect(f)
	return b


func _armar_interfaz() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	var raiz := HBoxContainer.new()
	raiz.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(raiz)
	# izquierda: la lista
	var izq := VBoxContainer.new()
	izq.custom_minimum_size = Vector2(300, 0)
	raiz.add_child(izq)
	var titulo := Label.new()
	titulo.text = "Salas nuevas (torre sin núcleo)"
	izq.add_child(titulo)
	lista = ItemList.new()
	lista.size_flags_vertical = Control.SIZE_EXPAND_FILL
	lista.item_selected.connect(func(i): elegir(i))
	izq.add_child(lista)
	var fila_arch := HBoxContainer.new()
	fila_arch.add_child(_boton("Guardar", guardar))
	fila_arch.add_child(_boton("Sala nueva", sala_nueva))
	fila_arch.add_child(_boton("Borrar", borrar))
	izq.add_child(fila_arch)
	# centro: la vista 3D y los controles de reproducción
	var centro_v := VBoxContainer.new()
	centro_v.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	raiz.add_child(centro_v)
	contenedor = SubViewportContainer.new()
	contenedor.stretch = true
	contenedor.size_flags_vertical = Control.SIZE_EXPAND_FILL
	contenedor.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	contenedor.gui_input.connect(_entrada_vista)
	centro_v.add_child(contenedor)
	vp = SubViewport.new()
	vp.own_world_3d = true
	vp.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	contenedor.add_child(vp)
	var mundo := Node3D.new()
	vp.add_child(mundo)
	RoomView.add_lighting(mundo)
	bloques_nodo = Node3D.new()
	mundo.add_child(bloques_nodo)
	cam = Camera3D.new()
	vp.add_child(cam)
	cam.current = true
	var barra := HBoxContainer.new()
	barra.add_child(_boton("|<", func(): ir_a(0)))
	barra.add_child(_boton("<", func(): ir_a(paso - 1)))
	barra.add_child(_boton("Reproducir", alternar_reproduccion))
	barra.add_child(_boton(">", func(): ir_a(paso + 1)))
	barra.add_child(_boton(">|", func(): ir_a(cuadros.size() - 1)))
	slider = HSlider.new()
	slider.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	slider.step = 1
	slider.value_changed.connect(func(v): if not _suprimir: ir_a(int(v)))
	barra.add_child(slider)
	barra.add_child(_boton("Desde atrás del jugador", func(): vista_atras = true; _poner_camara()))
	barra.add_child(_boton("Diagonal", func(): vista_atras = false; _poner_camara()))
	centro_v.add_child(barra)
	estado = Label.new()
	centro_v.add_child(estado)
	# derecha: datos y herramientas
	var der := VBoxContainer.new()
	der.custom_minimum_size = Vector2(340, 0)
	raiz.add_child(der)
	info = RichTextLabel.new()
	info.bbcode_enabled = true
	info.size_flags_vertical = Control.SIZE_EXPAND_FILL
	der.add_child(info)
	var etiq := Label.new()
	etiq.text = "Edición (clic en la vista: ctrl + arrastrar gira, rueda acerca)"
	etiq.autowrap_mode = TextServer.AUTOWRAP_WORD
	der.add_child(etiq)
	var herr := GridContainer.new()
	herr.columns = 2
	for h in [["poner", "Poner bloque"], ["quitar", "Sacar bloque"], ["checkpoint", "Checkpoint"], ["fijo", "Bloque fijo"], ["jugador", "Mover jugador"], ["meta", "Marcar salida"]]:
		herr.add_child(_boton(h[1], func(): herramienta = h[0]; _estado("Herramienta: " + h[1])))
	der.add_child(herr)
	der.add_child(_boton("Resolver de nuevo (solucionador nativo)", resolver_ahora))
	timer = Timer.new()
	timer.wait_time = 0.6
	timer.timeout.connect(func(): if paso + 1 < cuadros.size(): ir_a(paso + 1) else: timer.stop())
	add_child(timer)


func _estado(t: String) -> void:
	estado.text = t


# --- archivos ---------------------------------------------------------------------------------------------------------------------------------

func cargar(ruta: String) -> void:
	salas.clear()
	archivo = ruta
	var f := FileAccess.open(ruta, FileAccess.READ)
	if f != null:
		while not f.eof_reached():
			var l := f.get_line().strip_edges()
			if l == "":
				continue
			var d = JSON.parse_string(l)
			if d is Dictionary:
				salas.append(d)
	_llenar_lista()
	_estado("%d salas en %s" % [salas.size(), ruta])


func guardar() -> void:
	DirAccess.make_dir_recursive_absolute(archivo.get_base_dir())
	var f := FileAccess.open(archivo, FileAccess.WRITE)
	if f == null:
		_estado("No se pudo escribir " + archivo)
		return
	for d in salas:
		f.store_line(JSON.stringify(d))
	f.close()
	editado = false
	_estado("Guardado en " + archivo)


func _llenar_lista() -> void:
	lista.clear()
	for i in salas.size():
		var d: Dictionary = salas[i]
		lista.add_item("%d · %s %d pisos · %dp %da %dd" % [i + 1, str(d.get("tipo", "?")), int(d.meta) - 1, int(d.get("pasos", 0)), int(d.get("agarres", 0)), int(d.get("distintos", 0))])


func sala_nueva() -> void:
	var d := {"tipo": "3x3", "meta": 4, "jugador": [1, 2, 1], "colgado": [0, 0], "bloques": [[1, 1, 1, "p"], [2, 2, 1, "n"], [3, 3, 1, "n"], [4, 4, 1, "p"], [4, 4, 2, "f"]], "pasos": 0, "agarres": 0, "distintos": 0, "armado": -1, "exacto": false, "camino": []}
	salas.append(d)
	_llenar_lista()
	elegir(salas.size() - 1)
	resolver_ahora()


func borrar() -> void:
	if actual < 0:
		return
	salas.remove_at(actual)
	actual = -1
	_llenar_lista()
	if not salas.is_empty():
		elegir(0)
	editado = true


# --- una sala ---------------------------------------------------------------------------------------------------------------------------------

func elegir(i: int) -> void:
	actual = i
	lista.select(i)
	_armar_cuadros()
	ir_a(0)
	_mostrar_info()
	_poner_camara()


func _armar_cuadros() -> void:
	cuadros.clear()
	enc_por_cuadro.clear()
	var d: Dictionary = salas[actual]
	var t = Vista.motor_de(d)
	var enc := {}
	for c in t.bloques:
		if t.bloques[c] == "p" and c.y == 1:
			enc[c] = true
	cuadros.append(t.duplicar())
	enc_por_cuadro.append(enc.duplicate())
	for a in d.get("camino", []):
		if t.ganado or t.perdido:
			break
		t.actuar(Vector3i(int(a[0]), 0, int(a[1])), int(a[2]))
		if t.ganado:
			for c in t.bloques:
				if t.bloques[c] == "p" and c.y == t.meta:
					enc[c] = true
		cuadros.append(t.duplicar())
		enc_por_cuadro.append(enc.duplicate())
	_suprimir = true
	slider.max_value = maxi(cuadros.size() - 1, 0)
	_suprimir = false


func ir_a(n: int) -> void:
	if cuadros.is_empty():
		return
	paso = clampi(n, 0, cuadros.size() - 1)
	_suprimir = true
	slider.value = paso
	_suprimir = false
	var t = cuadros[paso]
	Vista.poblar(bloques_nodo, t, enc_por_cuadro[paso])
	if vista_atras:
		Vista.camara_detras(cam, t)
	else:
		_poner_camara()
	var s := "Cuadro %d de %d" % [paso, cuadros.size() - 1]
	if t.ganado:
		s += " · ¡llegó a la salida!"
	elif t.perdido:
		s += " · se cayó"
	_estado(s)


func alternar_reproduccion() -> void:
	if timer.is_stopped():
		if paso + 1 >= cuadros.size():
			ir_a(0)
		timer.start()
	else:
		timer.stop()


func _mostrar_info() -> void:
	if actual < 0:
		info.text = ""
		return
	var d: Dictionary = salas[actual]
	var pisos := int(d.meta) - 1
	var t := "[b]%s, %d pisos[/b]\n" % [str(d.get("tipo", "?")), pisos]
	t += "bloques: %d (checkpoint en nivel 1 y %d, un fijo)\n" % [d.bloques.size(), int(d.meta)]
	t += "[b]camino más corto: %d pasos[/b]\n" % int(d.get("pasos", 0))
	t += "agarres (Shift que mueven bloques): %d\n" % int(d.get("agarres", 0))
	t += "bloques distintos movidos: %d (%.2f por piso)\n" % [int(d.get("distintos", 0)), float(d.get("distintos", 0)) / maxf(pisos, 1.0)]
	if int(d.get("armado", -1)) >= 0:
		t += "camino armado hacia atrás: %d\n" % int(d.armado)
	t += "exacto: %s\n" % ("sí" if bool(d.get("exacto", false)) else "no (cota)")
	if editado:
		t += "\n[color=orange]cambios sin guardar[/color]"
	info.text = t


## El máximo de movimientos de la sala en una etapa (1 a 15): el mínimo del solucionador por un margen que baja con la etapa. Tabla provisoria.
static func maximo_movimientos(minimo: int, etapa: int) -> int:
	var margen := lerpf(2.0, 1.15, clampf(float(etapa - 1) / 14.0, 0.0, 1.0))
	return ceili(float(minimo) * margen)


func _poner_camara() -> void:
	if cuadros.is_empty():
		return
	if vista_atras:
		Vista.camara_detras(cam, cuadros[paso])
	else:
		var c := Vector3(5.5, float(cuadros[paso].meta) * 0.5 + 0.5, 5.5)
		RoomView.place_camera(cam, c, yaw, pitch, dist)
		cam.fov = 50.0


# --- edición ----------------------------------------------------------------------------------------------------------------------------------

func _entrada_vista(ev: InputEvent) -> void:
	if ev is InputEventMouseButton:
		var mb := ev as InputEventMouseButton
		if mb.button_index == MOUSE_BUTTON_WHEEL_UP and mb.pressed:
			dist = maxf(dist - 1.0, 4.0)
			_poner_camara()
		elif mb.button_index == MOUSE_BUTTON_WHEEL_DOWN and mb.pressed:
			dist = minf(dist + 1.0, 40.0)
			_poner_camara()
		elif mb.button_index == MOUSE_BUTTON_LEFT:
			if mb.pressed and mb.ctrl_pressed:
				arrastrando = true
				vista_atras = false
			elif mb.pressed:
				_clic(mb.position)
			else:
				arrastrando = false
	elif ev is InputEventMouseMotion and arrastrando:
		var mm := ev as InputEventMouseMotion
		yaw -= mm.relative.x * 0.4
		pitch = clampf(pitch + mm.relative.y * 0.4, 5.0, 85.0)
		_poner_camara()


func _clic(pos: Vector2) -> void:
	if actual < 0 or paso != 0:
		_estado("Para editar, volvé al cuadro 0 de la sala.")
		return
	var t = cuadros[0]
	var mira := Mira.new()
	mira.blocks = t.bloques
	var r := RoomView.pick_face(cam, pos, mira)
	var d: Dictionary = salas[actual]
	var hit: Vector3i = r.hit
	var prev: Vector3i = r.prev
	var cambio := false
	match herramienta:
		"poner":
			if hit.x != -1000 and not t.bloques.has(prev):
				t.bloques[prev] = "n"
				cambio = true
		"checkpoint":
			if hit.x != -1000:
				t.bloques[hit] = "p"
				cambio = true
		"fijo":
			if hit.x != -1000 and not t.bloques.has(prev):
				t.bloques[prev] = "f"
				cambio = true
		"quitar":
			if hit.x != -1000:
				t.bloques.erase(hit)
				cambio = true
		"jugador":
			if hit.x != -1000 and not t.bloques.has(hit + Vector3i(0, 1, 0)):
				t.jugador = hit + Vector3i(0, 1, 0)
				cambio = true
		"meta":
			if hit.x != -1000:
				d["meta"] = hit.y
				t.meta = hit.y
				cambio = true
	if cambio:
		editado = true
		_guardar_en_sala(t)
		d["camino"] = []
		d["pasos"] = 0
		d["agarres"] = 0
		d["distintos"] = 0
		d["armado"] = -1
		d["exacto"] = false
		_armar_cuadros()
		ir_a(0)
		_mostrar_info()
		_estado("Sala cambiada: resolvela de nuevo para recalcular el camino.")


func _guardar_en_sala(t) -> void:
	var d: Dictionary = salas[actual]
	var lista_b: Array = []
	for c in t.bloques:
		lista_b.append([c.x, c.y, c.z, t.bloques[c]])
	d["bloques"] = lista_b
	d["jugador"] = [t.jugador.x, t.jugador.y, t.jugador.z]
	d["meta"] = t.meta


func resolver_ahora() -> void:
	if actual < 0:
		return
	var t = cuadros[0]
	if not Nat.disponible():
		_estado("Falta tools/salas_nuevas.exe (se arma con g++: native/salas_nuevas.cpp).")
		return
	var r := Nat.resolver(t, 1500000)
	var d: Dictionary = salas[actual]
	if r.ok:
		var cam_l: Array = []
		for a in r.path:
			cam_l.append([a[0].x, a[0].z, a[1]])
		d["camino"] = cam_l
		d["pasos"] = r.moves
		d["agarres"] = r.agarres
		d["distintos"] = r.distintos
		d["exacto"] = true
		_armar_cuadros()
		ir_a(0)
		_estado("Resuelta: %d pasos, %d agarres, %d bloques distintos." % [r.moves, r.agarres, r.distintos])
	else:
		d["camino"] = []
		_estado("Sin solución %s (%d nodos)." % ["(se agotó el tope)" if r.get("tope", false) else "", r.states])
	_llenar_lista()
	lista.select(actual)
	_mostrar_info()
