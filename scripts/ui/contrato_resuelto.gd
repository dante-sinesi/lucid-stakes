extends Control
## La pantalla de un contrato resuelto (docs/plan_casinos.md): ocupa toda la pantalla; el papel del contrato queda en el medio con su ícono y su sello de rareza, a su izquierda el título y debajo las condiciones, por la derecha entra un
## sello de mano hecho de minibloques que se apoya sobre el papel y deja "CUMPLIDO" o "FALLIDO", y en ese mismo lado sale un contador grande con lo cobrado.
## `mostrar` recibe el contrato ({objetivo, rareza, titulo, condiciones: Array[String]}), si se cumplió y el monto (lo cobrado; negativo: la fianza que se perdió; 0: nada).
## Una primera pulsación durante la animación la salta; cuando ya está todo a la vista, la siguiente emite `terminado`.

const Arte := preload("res://scripts/ui/contract_art.gd")
const Draw := preload("res://scripts/ui/voxel_draw.gd")
const VFont := preload("res://scripts/ui/voxel_font.gd")
const PadHints := preload("res://scripts/ui/pad_hints.gd")
const PadGlyph := preload("res://scripts/ui/pad_glyph.gd")
const Loc := preload("res://scripts/idioma/loc.gd")
const Sfx := preload("res://scripts/sonido/sfx.gd")

signal terminado

# la línea de tiempo, en segundos
const T_PAPEL := 0.15          # el papel empieza a subir
const T_PAPEL_FIN := 0.8
const T_SELLO_ENTRA := 0.95    # el sello de mano entra por la derecha
const T_BAJA := 1.55           # y se deja caer sobre el papel
const T_IMPACTO := 1.68        # se apoya: queda la palabra, salta la tinta y tiembla la pantalla
const T_SUBE := 2.0            # se levanta
const T_SALE := 2.45           # y se va por la derecha
const T_CONTEO := 2.3          # sale el contador
const DUR_CONTEO := 1.4
const T_LISTO := T_CONTEO + DUR_CONTEO + 0.3   # todo a la vista: se puede continuar

const TINTA_CUMPLIDO := Color(0.15, 0.62, 0.30)
const TINTA_FALLIDO := Color(0.80, 0.12, 0.14)
const TINTA_CANCELADO := Color(0.78, 0.52, 0.10)
const ORO := Color(1.0, 0.85, 0.30)

var contrato := {}
var cumplido := true
var cancelado := false   # lo cancelaste vos (en el casino, antes de la torre): el sello dice CANCELADO y se devuelve la fianza
var monto := 0
var t := 0.0
var listo := false
var _pad: Control
var _sono_impacto := false


func _init() -> void:
	name = "contrato_resuelto"
	visible = false
	mouse_filter = Control.MOUSE_FILTER_STOP
	set_anchors_preset(Control.PRESET_FULL_RECT)
	process_mode = Node.PROCESS_MODE_ALWAYS   # (la torre está en pausa mientras se ve)
	_pad = PadHints.attach(self, [{"slot": PadGlyph.Slot.SOUTH, "key": "Espacio", "text": Loc.t("Continuar"), "call": _pulsar}])
	_pad.visible = false


func mostrar(c: Dictionary, se_cumplio: bool, cobrado: int, se_cancelo := false) -> void:
	contrato = c
	cumplido = se_cumplio
	cancelado = se_cancelo
	monto = cobrado
	t = 0.0
	listo = false
	_sono_impacto = false
	_pad.visible = false
	visible = true
	set_process(true)
	queue_redraw()


## Salta a un instante de la animación (las pruebas y las capturas).
func ir_a(segundos: float) -> void:
	t = segundos
	_actualizar()
	queue_redraw()


func _process(delta: float) -> void:
	if not visible:
		return
	t += delta
	_actualizar()
	queue_redraw()


func _actualizar() -> void:
	if t >= T_IMPACTO and not _sono_impacto:
		_sono_impacto = true
		Sfx.play("item" if cumplido or cancelado else "miss")
	if t >= T_LISTO and not listo:
		listo = true
		_pad.visible = true


func _pulsar() -> void:
	if not visible:
		return
	if not listo:
		t = T_LISTO   # la primera pulsación salta la animación
		_sono_impacto = true
		_actualizar()
		queue_redraw()
		return
	visible = false
	set_process(false)
	terminado.emit()


func _unhandled_input(event: InputEvent) -> void:
	if visible and event is InputEventKey and event.pressed and not event.echo and event.keycode in [KEY_SPACE, KEY_ENTER, KEY_KP_ENTER]:
		get_viewport().set_input_as_handled()
		_pulsar()


static func _suave(k: float) -> float:
	k = clampf(k, 0.0, 1.0)
	return k * k * (3.0 - 2.0 * k)


static func _rebote(k: float) -> float:   # sube y se pasa un poco antes de asentarse
	k = clampf(k, 0.0, 1.0)
	return 1.0 + 2.7 * pow(k - 1.0, 3.0) + 1.7 * pow(k - 1.0, 2.0)


func _draw() -> void:
	if not visible:
		return
	var w := size.x
	var h := size.y
	var oscuro := _suave(t / 0.35) * 0.80
	draw_rect(Rect2(Vector2.ZERO, size), Color(0.03, 0.02, 0.07, oscuro))
	var tinta := TINTA_CANCELADO if cancelado else (TINTA_CUMPLIDO if cumplido else TINTA_FALLIDO)
	# el temblor del impacto
	var desde := t - T_IMPACTO
	var temblor := Vector2.ZERO
	if desde >= 0.0 and desde < 0.3:
		var a := (1.0 - desde / 0.3) * 9.0
		temblor = Vector2(sin(desde * 90.0), cos(desde * 77.0)) * a
	draw_set_transform(temblor, 0.0, Vector2.ONE)
	# el papel
	var s := floorf(minf(h * 0.70 / Arte.PAPEL_ROWS, w * 0.27 / Arte.PAPEL_COLS))
	var pw := Arte.PAPEL_COLS * s
	var ph := Arte.PAPEL_ROWS * s
	var centro := Vector2(w * 0.5, h * 0.47)
	var sube := _rebote((t - T_PAPEL) / (T_PAPEL_FIN - T_PAPEL))
	var pos := Vector2(centro.x - pw * 0.5, centro.y - ph * 0.5 + (1.0 - sube) * h * 0.7)
	if t >= T_PAPEL:
		Arte.dibujar_papel(self, pos, s, int(contrato.get("rareza", 0)), str(contrato.get("objetivo", "")), 11, false)
		_texto_lateral(pos, w, h)
	# la palabra del sello, ya apoyada
	var punto := pos + Vector2(pw * 0.5, ph * 0.74)   # (el sello cae en la parte de abajo del papel)
	if desde >= 0.0:
		var s_palabra := pw * 1.02 / 54.0
		var fuerza := minf(0.55 + desde * 4.0, 1.0)
		var texto := Loc.t("CANCELADO") if cancelado else (Loc.t("CUMPLIDO") if cumplido else Loc.t("FALLIDO"))
		Arte.dibujar_sello_texto(self, punto, s_palabra, texto, tinta, fuerza, -9.0)
		_tinta_salpicada(punto, s, tinta, desde)
	# el sello de mano: entra por la derecha, baja, se apoya, sube y se va
	if t >= T_SELLO_ENTRA and t < T_SALE:
		var s_mano := pw * 0.62 / Arte.SELLO_MANO_COLS
		var ancho_mano := Arte.SELLO_MANO_COLS * s_mano
		var alto_mano := Arte.SELLO_MANO_ROWS * s_mano
		var x_fuera := w + ancho_mano
		var x_papel := punto.x - ancho_mano * 0.5
		var y_alto := punto.y - alto_mano - ph * 0.30
		var y_papel := punto.y - alto_mano   # el borde de abajo toca el punto
		var x := x_papel
		var y := y_alto
		if t < T_BAJA:   # entra
			x = lerpf(x_fuera, x_papel, _suave((t - T_SELLO_ENTRA) / (T_BAJA - T_SELLO_ENTRA)))
		elif t < T_IMPACTO:   # cae
			var k := (t - T_BAJA) / (T_IMPACTO - T_BAJA)
			y = lerpf(y_alto, y_papel, k * k)
		elif t < T_SUBE:   # apoyado
			y = y_papel
		else:   # sube y se va
			var k := (t - T_SUBE) / (T_SALE - T_SUBE)
			x = lerpf(x_papel, x_fuera, _suave(k))
			y = lerpf(y_papel, y_alto, _suave(minf(k * 2.0, 1.0)))
		Arte.dibujar_sello_mano(self, Vector2(x, y), s_mano, tinta)
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
	# el contador, grande, del lado derecho
	if t >= T_CONTEO:
		_contador(Vector2(pos.x + pw + (w - pos.x - pw) * 0.5, centro.y), w - pos.x - pw - w * 0.06)


## A la izquierda del papel: el título del contrato (grande, en dorado) y debajo las condiciones que había que cumplir, una por renglón con su guion.
func _texto_lateral(pos: Vector2, w: float, h: float) -> void:
	var alfa := _suave((t - T_PAPEL - 0.2) / 0.4)
	if alfa <= 0.0:
		return
	var x0 := w * 0.05
	var ancho := pos.x - w * 0.03 - x0
	var cub_t := maxf(3.0, floorf(h / 150.0))
	var cub_c := maxf(2.0, floorf(cub_t * 0.6))
	var y := pos.y + 20.0
	var titulo: Array[String] = VFont.wrap(str(contrato.get("titulo", "")), int((ancho / cub_t + 1.0)))
	var lay_t: Dictionary = VFont.layout(titulo)
	Draw.text_cells(self, Vector2(x0, y), lay_t.cells, lay_t.size.y, cub_t, Color(ORO.r, ORO.g, ORO.b, alfa), 0.0, 17, true)
	y += float(lay_t.size.y) * cub_t + cub_t * 6.0
	var lineas: Array[String] = []
	for cond in contrato.get("condiciones", []):
		var partes: Array[String] = VFont.wrap("- " + str(cond), int((ancho / cub_c + 1.0)))
		for i in partes.size():
			lineas.append(partes[i] if i == 0 else "  " + partes[i])
	if not lineas.is_empty():
		var lay_c: Dictionary = VFont.layout(lineas)
		Draw.text_cells(self, Vector2(x0, y), lay_c.cells, lay_c.size.y, cub_c, Color(0.96, 0.92, 0.80, alfa), 0.0, 19, true)


## La salpicadura de tinta al apoyarse el sello: cubitos que salen disparados y caen.
func _tinta_salpicada(punto: Vector2, s: float, tinta: Color, desde: float) -> void:
	if desde > 0.8:
		return
	for i in 26:
		var ang := float(i) * 2.399 + 0.5
		var v := 120.0 + 260.0 * Draw.noise(i, 3, 7)
		var p := punto + Vector2(cos(ang), sin(ang) * 0.6) * v * desde + Vector2(0.0, 520.0 * desde * desde)
		var vida := 1.0 - desde / 0.8
		var lado := maxf(2.0, s * (0.35 + 0.4 * Draw.noise(i, 9, 7))) * vida
		draw_rect(Rect2(p, Vector2(lado, lado)), Color(tinta.r, tinta.g, tinta.b, vida))


## Lo cobrado: un rótulo, el número grande que sube hasta el monto y el color según el resultado.
func _contador(centro: Vector2, ancho: float) -> void:
	var k := clampf((t - T_CONTEO) / DUR_CONTEO, 0.0, 1.0)
	var valor := int(round(float(absi(monto)) * (1.0 - pow(1.0 - k, 3.0))))
	var rotulo: String
	var color: Color
	var texto: String
	if cancelado:
		rotulo = Loc.t("Fianza devuelta") if monto > 0 else Loc.t("Sin costo")
		color = ORO if monto > 0 else Color(0.70, 0.68, 0.78)
		texto = "+%d" % valor if monto > 0 else "0"
	elif cumplido:
		rotulo = Loc.t("Cobrado")
		color = ORO
		texto = "+%d" % valor
	elif monto < 0:
		rotulo = Loc.t("Fianza perdida")
		color = TINTA_FALLIDO.lightened(0.25)
		texto = "-%d" % valor
	else:
		rotulo = Loc.t("Sin recompensa")
		color = Color(0.70, 0.68, 0.78)
		texto = "0"
	var s_num := maxf(5.0, floorf(size.y / 60.0))
	var pop := 1.0 + 0.12 * maxf(0.0, 1.0 - (t - T_CONTEO) * 5.0)   # (entra con un golpecito)
	_texto(rotulo, centro + Vector2(0.0, -s_num * 11.0 * 0.9), maxf(3.0, floorf(s_num * 0.5)), color.lightened(0.15), true, ancho)
	_texto(texto, centro + Vector2(0.0, s_num * 0.4), s_num * pop, color, true, ancho)


## Un texto de cubitos centrado en `centro` (con la sombra dura de la interfaz).
func _texto(texto: String, centro: Vector2, cubito: float, color: Color, sombra: bool, ancho_max := 0.0) -> void:
	var lay: Dictionary = VFont.layout([texto])
	var tam: Vector2i = lay.size
	if ancho_max > 0.0 and tam.x > 0:   # (si no entra en el lado de la pantalla, el texto se achica)
		cubito = minf(cubito, ancho_max / float(tam.x))
	Draw.text_cells(self, centro - Vector2(tam.x, tam.y) * cubito * 0.5, lay.cells, tam.y, cubito, color, 0.0, 13, sombra)
