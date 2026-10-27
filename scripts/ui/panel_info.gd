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
const ANCHO_TEXTO := 400    # el ancho al que se parte el texto
const SEGUNDOS := 0.16      # lo que tarda en entrar y salir
const CHAPA := 11           # el ícono de un contrato mide 11 x 11 cubitos
const CUBO_ICONO := 3.0
const COLOR_TEXTO := Color(0.97, 0.95, 0.9)
const COLOR_SUAVE := Color(0.72, 0.68, 0.82)
const ROJO := Color(1.0, 0.55, 0.45)

var panel: Control
var abierto := false
var _caja: VBoxContainer
var _tween: Tween
var _datos := {}


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
	panel.set_anchors_preset(Control.PRESET_LEFT_WIDE)
	panel.draw.connect(func(): Draw.card(panel, Rect2(Vector2.ZERO, panel.size), 5.0, 0, 0.1, 4242, false, -1.0))
	add_child(panel)
	var margen := MarginContainer.new()
	margen.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	for lado in ["left", "right"]:
		margen.add_theme_constant_override("margin_" + lado, 26)
	margen.add_theme_constant_override("margin_top", 24)
	margen.add_theme_constant_override("margin_bottom", 20)
	panel.add_child(margen)
	var scroll := ScrollContainer.new()
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	scroll.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_AUTO
	scroll.mouse_filter = Control.MOUSE_FILTER_IGNORE
	margen.add_child(scroll)
	_caja = VBoxContainer.new()
	_caja.add_theme_constant_override("separation", 10)
	_caja.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(_caja)
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
	return clampf(panel.offset_right / ANCHO, 0.0, 1.0)


## Pone el panel a `k` (de 0 afuera a 1 entero adentro) del camino.
func _poner_avance(k: float) -> void:
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


func _separador() -> void:
	var r := ColorRect.new()
	r.color = Color(0.45, 0.38, 0.65, 0.7)
	r.custom_minimum_size = Vector2(0, 2)
	_caja.add_child(r)


## Arma el contenido con los datos de ahora.
func _armar() -> void:
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
