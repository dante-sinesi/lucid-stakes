extends Control
## Los contratos activos en el menú de pausa: solo los íconos, en columna, a la derecha del menú (el HUD de la torre no los muestra). Cada uno es una chapa de pergamino con el
## ícono del objetivo y, en la esquina, un sello chico del color de su rareza. Su título y sus condiciones (con la fuente del juego) aparecen a la izquierda del ícono solo si el mouse pasa por encima
## o si se llega a él con las flechas o WASD (cada chapa toma el foco; desde los botones, "derecha" lleva a ellas). `mostrar` recibe una lista de {objetivo, rareza, titulo, condiciones} (ver `contract_art.gd`).

const Arte := preload("res://scripts/ui/contract_art.gd")
const UI := preload("res://scripts/ui/menu_ui.gd")

const CUBO := 7.0                 # lado del cubito del ícono (la chapa mide 11 x 11 cubitos)
const CUBO_SELLO := 4.0
const CHAPA := 11
const SEPARACION := 20.0
const MARGEN_DERECHO := 50.0     # lo que queda entre la columna y el borde de la pantalla
const ANCHO_TEXTO := 300

var contratos: Array = []
var tip: PanelContainer           # el cartel con el título y las condiciones del contrato señalado
var _chapas: Array = []


## Una chapa: se dibuja sola y avisa cuando el mouse o el foco la señalan.
class Chapa extends Control:
	signal senalada(chapa)
	signal soltada(chapa)
	var datos: Dictionary = {}

	func _init() -> void:
		focus_mode = Control.FOCUS_ALL
		mouse_filter = Control.MOUSE_FILTER_STOP
		mouse_entered.connect(func(): senalada.emit(self))
		mouse_exited.connect(func():
			if not has_focus():
				soltada.emit(self))
		focus_entered.connect(func(): senalada.emit(self))
		focus_exited.connect(func(): soltada.emit(self))

	func _draw() -> void:
		var lado := CHAPA * CUBO
		draw_rect(Rect2(Vector2(CUBO * 0.8, CUBO * 1.2), Vector2(lado, lado)), Color(0, 0, 0, 0.55))   # sombra dura
		draw_rect(Rect2(Vector2.ZERO, Vector2(lado, lado)), Arte.PAPEL)
		draw_rect(Rect2(Vector2.ZERO, Vector2(lado, lado)), Arte.PAPEL_SOMBRA, false, 2.0)
		Arte.dibujar_objetivo(self, str(datos.get("objetivo", "")), Vector2(CUBO, CUBO), CUBO)
		Arte.dibujar_sello(self, int(datos.get("rareza", 0)), Vector2(lado - CUBO_SELLO * 4.0, lado - CUBO_SELLO * 4.0), CUBO_SELLO)
		if has_focus() or get_global_rect().has_point(get_global_mouse_position()):
			draw_rect(Rect2(Vector2(-4, -4), Vector2(lado + 8, lado + 8)), Color(1.0, 0.85, 0.4), false, 3.0)


func _init() -> void:
	name = "contratos_activos"
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	set_anchors_preset(Control.PRESET_CENTER_RIGHT)
	visible = false
	tip = PanelContainer.new()
	tip.name = "cartel"
	tip.visible = false
	tip.mouse_filter = Control.MOUSE_FILTER_IGNORE
	tip.z_index = 10
	var caja := StyleBoxFlat.new()
	caja.bg_color = Color(0.08, 0.04, 0.15, 0.96)
	caja.border_color = Color(1.0, 0.85, 0.4)
	caja.set_border_width_all(2)
	caja.set_content_margin_all(14)
	tip.add_theme_stylebox_override("panel", caja)


## Pone los contratos activos; sin ninguno, la columna no se ve.
func mostrar(lista: Array) -> void:
	contratos = lista
	for c in _chapas:
		c.queue_free()
	_chapas.clear()
	if tip.get_parent() != self:
		add_child(tip)
	tip.visible = false
	var lado := CHAPA * CUBO
	var alto := contratos.size() * lado + maxf(contratos.size() - 1.0, 0.0) * SEPARACION
	offset_right = -MARGEN_DERECHO
	offset_left = -MARGEN_DERECHO - lado - CUBO_SELLO * 3.0
	offset_top = -alto * 0.5
	offset_bottom = alto * 0.5
	for i in contratos.size():
		var ch := Chapa.new()
		ch.name = "contrato_%d" % i
		ch.datos = contratos[i]
		ch.position = Vector2(0.0, i * (lado + SEPARACION))
		ch.size = Vector2(lado + CUBO_SELLO * 3.0, lado)
		ch.senalada.connect(_senalar)
		ch.soltada.connect(_soltar)
		add_child(ch)
		_chapas.append(ch)
	visible = not contratos.is_empty()


## Muestra el cartel del contrato señalado, a la izquierda de su ícono.
func _senalar(ch: Control) -> void:
	ch.queue_redraw()
	for h in tip.get_children():
		tip.remove_child(h)
		h.queue_free()
	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 8)
	tip.add_child(col)
	UI.label(col, str(ch.datos.get("titulo", "")), 3.0, UI.GOLD, false, ANCHO_TEXTO)
	for cond in ch.datos.get("condiciones", []):
		UI.label(col, str(cond), 2.5, Color(0.97, 0.95, 0.9), false, ANCHO_TEXTO)
	tip.reset_size()
	var tam := tip.get_combined_minimum_size()
	tip.size = tam
	tip.position = Vector2(ch.position.x - tam.x - 24.0, ch.position.y + CHAPA * CUBO * 0.5 - tam.y * 0.5)
	tip.visible = true


func _soltar(ch: Control) -> void:
	ch.queue_redraw()
	if not _chapas.any(func(c): return c != ch and (c.has_focus() or c.get_global_rect().has_point(get_global_mouse_position()))):
		tip.visible = false
