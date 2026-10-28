extends Control
## El panel de información (docs/panel_informacion.md): una ventana que entra por la izquierda al mantener Tab (o con un toque, según Opciones) y cuenta cómo va la partida: el escenario y la
## dificultad, la etapa y la sala, la claridad, los movimientos, el peaje, la prueba y los contratos activos, con sus textos completos. Así el HUD queda con lo mínimo y la pausa con sus botones.
## `abrir(datos)` la muestra y `actualizar(datos)` la refresca mientras está abierta; `datos` lo arma main.gd (`_panel_datos`): {titulo, etapa, sala, claridad, claridad_torre, movs, max_movs,
## sin_limite, falsos: {quedan, permitidos}, peaje: {precio, alcanza}, prueba: {nombre, desc}, proxima_prueba, contratos: [{objetivo, rareza, titulo, condiciones}]}; lo que falta no se muestra.

const UI := preload("res://scripts/ui/menu_ui.gd")
const Draw := preload("res://scripts/ui/voxel_draw.gd")
const Arte := preload("res://scripts/ui/contract_art.gd")
const NumberFormat := preload("res://scripts/datos/number_format.gd")
const Loc := preload("res://scripts/idioma/loc.gd")

const ANCHO := 460.0        # lo que mide de ancho
const ANCHO_TEXTO := 380    # el ancho al que se parte el texto
const SEGUNDOS := 0.16      # lo que tarda en entrar y salir
const CHAPA := 11           # el ícono de un contrato mide 11 x 11 cubitos
const CUBO_ICONO := 3.0
const BOTON_ANCHO := 210.0  # los botones del menú de una fila
const BOTON_ALTO := 64.0
const BOTON_SEP := 12.0
const VoxelLabel := preload("res://scripts/ui/voxel_label.gd")
const COLOR_TEXTO := Color(0.97, 0.95, 0.9)
const COLOR_SUAVE := Color(0.72, 0.68, 0.82)
const ROJO := Color(1.0, 0.55, 0.45)

var panel: Control
var abierto := false
var _caja: VBoxContainer
var _tween: Tween
var _datos := {}
var _scroll: ScrollContainer
var _filas: Array = []      # las filas que se pueden elegir (contratos, boosts, consumibles), de arriba abajo
var _sel := -1              # la fila elegida de este panel (-1: el cursor está en el otro)
var _opciones: Array = []   # el menú de la fila elegida (textos), con la opción marcada en `_op_i`
var _op_i := 0
var _botones: Control       # los botones del menú, fuera del panel, hacia el centro


## El ícono de un contrato (el del objetivo y su sello de rareza), de cubitos.
class Icono extends Control:
	var objetivo := ""
	var rareza := 0

	func _init() -> void:
		custom_minimum_size = Vector2(CHAPA * CUBO_ICONO + 6.0, CHAPA * CUBO_ICONO + 6.0)
		mouse_filter = Control.MOUSE_FILTER_IGNORE

	func _draw() -> void:
		var lado := CHAPA * CUBO_ICONO
		draw_rect(Rect2(Vector2.ZERO, Vector2(lado, lado)), Arte.PAPEL)
		draw_rect(Rect2(Vector2.ZERO, Vector2(lado, lado)), Arte.PAPEL_SOMBRA, false, 2.0)
		Arte.dibujar_objetivo(self, objetivo, Vector2(CUBO_ICONO, CUBO_ICONO), CUBO_ICONO)
		Arte.dibujar_sello(self, rareza, Vector2(lado - 3.0 * 4.0, lado - 3.0 * 4.0), 3.0)


func _init() -> void:
	name = "panel_info"
	visible = false
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	panel = Control.new()
	panel.name = "ventana"
	panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	panel.set_anchors_preset(Control.PRESET_RIGHT_WIDE if _derecha() else Control.PRESET_LEFT_WIDE)
	panel.draw.connect(func(): Draw.card(panel, Rect2(Vector2.ZERO, panel.size), 5.0, 0, 0.1, 4242, false, -1.0))
	add_child(panel)
	var margen := MarginContainer.new()
	margen.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	for lado in ["left", "right"]:
		margen.add_theme_constant_override("margin_" + lado, 26)
	margen.add_theme_constant_override("margin_top", 24)
	margen.add_theme_constant_override("margin_bottom", 20)
	panel.add_child(margen)
	_scroll = ScrollContainer.new()
	_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	_scroll.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_AUTO
	_scroll.mouse_filter = Control.MOUSE_FILTER_IGNORE
	margen.add_child(_scroll)
	var interno := MarginContainer.new()   # (deja lugar para el borde de la fila elegida)
	interno.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	interno.add_theme_constant_override("margin_left", 8)
	interno.add_theme_constant_override("margin_right", 8)
	interno.add_theme_constant_override("margin_top", 4)
	_scroll.add_child(interno)
	_caja = VBoxContainer.new()
	_caja.add_theme_constant_override("separation", 10)
	_caja.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	interno.add_child(_caja)
	_poner_avance(0.0)


## Muestra el panel con estos datos: entra deslizándose por la izquierda.
func abrir(datos: Dictionary) -> void:
	_datos = datos
	_armar()
	if abierto:
		return
	abierto = true
	visible = true
	if _tween != null:
		_tween.kill()
	_tween = create_tween()
	_tween.tween_method(_poner_avance, _avance(), 1.0, SEGUNDOS * (1.0 - _avance())).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)


## Lo que ya entró del panel (de 0 a 1), para que abrir y cerrar a mitad de camino no salte.
func _avance() -> float:
	return clampf((-panel.offset_left if _derecha() else panel.offset_right) / ANCHO, 0.0, 1.0)


## ¿Entra por la derecha? (el panel de boosts y consumibles lo cambia)
func _derecha() -> bool:
	return false


## Pone el panel a `k` (de 0 afuera a 1 entero adentro) del camino.
func _poner_avance(k: float) -> void:
	if _derecha():
		panel.offset_left = lerpf(0.0, -ANCHO, k)
		panel.offset_right = lerpf(ANCHO, 0.0, k)
	else:
		panel.offset_left = lerpf(-ANCHO, 0.0, k)
		panel.offset_right = lerpf(0.0, ANCHO, k)


## Lo guarda sin animar: se refresca el contenido (por ejemplo, después de un movimiento) con el panel abierto.
func actualizar(datos: Dictionary) -> void:
	_datos = datos
	if abierto:
		_armar()


## Lo saca: sale deslizándose; `rapido` lo esconde de golpe (por ejemplo, al pausar).
func cerrar(rapido := false) -> void:
	if not abierto and not visible:
		return
	abierto = false
	poner_opciones([])
	if _tween != null:
		_tween.kill()
	if rapido:
		visible = false
		_poner_avance(0.0)
		return
	_tween = create_tween()
	_tween.tween_method(_poner_avance, _avance(), 0.0, SEGUNDOS * _avance()).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN)
	_tween.tween_callback(func(): visible = abierto)


func _linea(texto: String, cubo := 3.0, color := COLOR_TEXTO, nombre := "") -> Control:
	var l := UI.label(_caja, texto, cubo, color, false, ANCHO_TEXTO)
	if nombre != "":
		l.name = nombre
	return l


## Una fila elegible: se dibuja con un marco dorado cuando es la elegida.
func _registrar_fila(fila: Control) -> void:
	var i := _filas.size()
	_filas.append(fila)
	fila.draw.connect(func():
		if i == _sel:
			var r := Rect2(Vector2(-6, -4), Vector2(fila.size.x + 12.0, fila.size.y + 8.0))
			fila.draw_rect(r, Color(0.85, 0.62, 0.15, 0.22))
			fila.draw_rect(r, Color(1.0, 0.82, 0.3), false, 2.0))


## Cuántas filas se pueden elegir.
func filas() -> int:
	return _filas.size()


## Elige la fila `i` (-1: ninguna) y la deja a la vista.
func poner_seleccion(i: int) -> void:
	_sel = i if i < _filas.size() else -1
	for f in _filas:
		f.queue_redraw()
	_ver_seleccion_luego()


func _ver_seleccion_luego() -> void:
	if not is_inside_tree():
		return
	await get_tree().process_frame
	_ver_seleccion()


func _ver_seleccion() -> void:
	if _sel < 0 or _sel >= _filas.size() or not is_instance_valid(_filas[_sel]):
		return
	if _sel == 0:
		_scroll.scroll_vertical = 0
	else:
		_scroll.ensure_control_visible(_filas[_sel])


## Muestra bajo la fila elegida el menú de lo que se puede hacer (vacío lo saca); `marcada` es la opción en la que está el cursor.
func poner_opciones(textos: Array, marcada := 0) -> void:
	_opciones = textos
	_op_i = marcada
	_armar_opciones()


## Pone los botones del menú hacia el centro de la pantalla, a la altura de la fila elegida (si hay menú). Lo llama `_armar` al final.
func _armar_opciones() -> void:
	if _botones != null:
		remove_child(_botones)
		_botones.queue_free()
		_botones = null
	if _sel < 0 or _sel >= _filas.size() or _opciones.is_empty():
		return
	_botones = Control.new()
	_botones.name = "botones"
	_botones.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_botones)
	for i in _opciones.size():
		var b := Control.new()
		b.name = "boton_%d" % i
		b.mouse_filter = Control.MOUSE_FILTER_IGNORE
		b.size = Vector2(BOTON_ANCHO, BOTON_ALTO)
		b.position = Vector2(0, i * (BOTON_ALTO + BOTON_SEP))
		var marcado: bool = i == _op_i
		b.draw.connect(func(): Draw.card(b, Rect2(Vector2.ZERO, b.size), 4.0, 1 if marcado else 0, 0.0, 31 + i, marcado, -1.0))
		var l := UI.label(b, str(_opciones[i]), 2.8, Color(1, 1, 1) if marcado else COLOR_TEXTO, true, int(BOTON_ANCHO) - 20)
		l.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		if l is VoxelLabel:
			l.vcenter = true
		_botones.add_child(b)
	_colocar_botones()


## Los botones van pegados al panel, del lado del centro, a la altura de la fila elegida.
func _colocar_botones() -> void:
	if not is_inside_tree():
		return
	await get_tree().process_frame
	if _botones == null or _sel < 0 or _sel >= _filas.size() or not is_instance_valid(_filas[_sel]):
		return
	var fila := _filas[_sel] as Control
	var alto := _opciones.size() * (BOTON_ALTO + BOTON_SEP) - BOTON_SEP
	var vs := get_viewport_rect().size
	var x := panel.get_global_rect().position.x - BOTON_ANCHO - 16.0 if _derecha() else panel.get_global_rect().end.x + 16.0
	var y := clampf(fila.get_global_rect().get_center().y - alto * 0.5, 8.0, maxf(vs.y - alto - 8.0, 8.0))
	_botones.position = Vector2(x, y)


## Antes de rearmar: guarda dónde estaba el scroll; después lo repone (y deja a la vista la fila elegida).
func _despues_de_armar(scroll_anterior: int) -> void:
	_armar_opciones()
	_reponer_scroll.call_deferred(scroll_anterior)


func _reponer_scroll(v: int) -> void:
	await get_tree().process_frame   # (el contenedor acomoda las filas nuevas antes de medir)
	_scroll.scroll_vertical = v
	_ver_seleccion()


func _separador() -> void:
	var r := ColorRect.new()
	r.color = Color(0.45, 0.38, 0.65, 0.7)
	r.custom_minimum_size = Vector2(0, 2)
	_caja.add_child(r)


## Arma el contenido con los datos de ahora.
func _armar() -> void:
	var scroll_anterior := _scroll.scroll_vertical
	_filas.clear()
	for c in _caja.get_children():
		_caja.remove_child(c)
		c.queue_free()
	var d := _datos
	if d.has("titulo"):
		_linea(str(d.titulo), 2.8, UI.GOLD, "titulo")
	if d.has("etapa"):
		var t := str(d.etapa)
		if d.has("sala"):
			t += "  ·  " + str(d.sala)
		_linea(t, 2.6, COLOR_TEXTO, "etapa")
	if d.has("claridad"):
		var c := Loc.f("Claridad %s", [NumberFormat.fmt(int(d.claridad))])
		_linea(c, 3.0, COLOR_TEXTO, "claridad")
		if int(d.get("claridad_torre", 0)) > 0:
			_linea(Loc.f("(%s de esta torre)", [NumberFormat.fmt(int(d.claridad_torre))]), 2.2, COLOR_SUAVE, "claridad_torre")
	if d.has("movs"):
		if bool(d.get("sin_limite", false)):
			_linea(Loc.f("Movimientos %d (sin límite)", [int(d.movs)]), 3.0, COLOR_TEXTO, "movimientos")
		else:
			_linea(Loc.f("Movimientos %d/%d", [int(d.movs), int(d.max_movs)]), 3.0, COLOR_TEXTO, "movimientos")
	if d.has("falsos"):
		_linea(Loc.f("Movimientos en falso: quedan %d de %d", [int(d.falsos.quedan), int(d.falsos.permitidos)]), 2.6, COLOR_TEXTO, "falsos")
	if d.has("peaje"):
		_linea(Loc.f("Peaje %s", [NumberFormat.fmt(int(d.peaje.precio))]), 3.0, COLOR_TEXTO if bool(d.peaje.alcanza) else ROJO, "peaje")
	if d.has("prueba"):
		_separador()
		_linea(Loc.t("Prueba"), 2.4, Color(0.85, 0.7, 0.3), "prueba_titulo")
		_linea(str(d.prueba.nombre), 3.4, UI.GOLD, "prueba_nombre")
		_linea(str(d.prueba.desc), 2.4, COLOR_TEXTO, "prueba_desc")
	elif str(d.get("proxima_prueba", "")) != "":
		_separador()
		_linea(str(d.proxima_prueba), 2.6, COLOR_SUAVE, "proxima_prueba")
	var contratos: Array = d.get("contratos", [])
	if not contratos.is_empty():
		_separador()
		_linea(Loc.t("Contratos"), 2.4, Color(0.85, 0.7, 0.3), "contratos_titulo")
		for i in contratos.size():
			var c: Dictionary = contratos[i]
			var fila := HBoxContainer.new()
			fila.name = "contrato_%d" % i
			fila.add_theme_constant_override("separation", 14)
			_caja.add_child(fila)
			_registrar_fila(fila)
			var icono := Icono.new()
			icono.objetivo = str(c.get("objetivo", ""))
			icono.rareza = int(c.get("rareza", 0))
			fila.add_child(icono)
			var texto := VBoxContainer.new()
			texto.add_theme_constant_override("separation", 4)
			fila.add_child(texto)
			UI.label(texto, str(c.get("titulo", "")), 2.6, UI.GOLD, false, ANCHO_TEXTO - 70)
			for cond in c.get("condiciones", []):
				UI.label(texto, str(cond), 2.2, COLOR_TEXTO, false, ANCHO_TEXTO - 70)
	_despues_de_armar(scroll_anterior)
