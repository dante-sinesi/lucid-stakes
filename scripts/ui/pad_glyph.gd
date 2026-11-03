extends RefCounted
## Íconos de los botones del mando para los textos de ayuda y las opciones: un círculo del color del botón con su letra (Xbox) o su símbolo (PlayStation),
## según el mando que se detecte. Se piden por posición física ("slot"), no por nombre, así valen igual en cualquier mando:
##   SOUTH (abajo: A en Xbox, cruz en PlayStation) · WEST (izquierda: X, cuadrado) · NORTH (arriba: Y, triángulo) · EAST (derecha: B, círculo).
## El puente del mando (pad_bridge.gd) traduce SOUTH a Espacio, WEST a Shift, NORTH a C y EAST a Esc cuando hay un menú o un juego del casino.

const Settings := preload("res://scripts/datos/settings.gd")
const VFont := preload("res://scripts/ui/voxel_font.gd")

enum Style { XBOX, PLAYSTATION }
enum Slot { SOUTH, WEST, NORTH, EAST }

## Para forzar un estilo (pruebas o capturas); -1 = el del mando conectado.
static var forced := -1

const COLORS := {
	Style.XBOX: [Color(0.30, 0.78, 0.38), Color(0.28, 0.48, 0.95), Color(0.97, 0.80, 0.22), Color(0.90, 0.28, 0.28)],
	Style.PLAYSTATION: [Color(0.35, 0.55, 0.95), Color(0.93, 0.50, 0.75), Color(0.30, 0.78, 0.55), Color(0.92, 0.35, 0.35)],
}
const LETTERS := {
	Style.XBOX: ["A", "X", "Y", "B"],
}


## El estilo del mando conectado (por el nombre que informa el sistema).
static func style() -> int:
	if forced >= 0:
		return forced
	match str(Settings.get_value("pad_style")):   # lo que eligió el jugador en Opciones
		"xbox":
			return Style.XBOX
		"playstation":
			return Style.PLAYSTATION
	var pads := Input.get_connected_joypads()
	if pads.is_empty():
		return Style.XBOX
	var n := Input.get_joy_name(int(pads[0])).to_lower()
	for key in ["playstation", "ps3", "ps4", "ps5", "dualshock", "dualsense", "sony"]:
		if n.contains(key):
			return Style.PLAYSTATION
	return Style.XBOX


## El botón de cada opción de una decisión (la primera es SOUTH, la segunda WEST, la tercera NORTH).
static func slot_for_option(i: int) -> int:
	return [Slot.SOUTH, Slot.WEST, Slot.NORTH][clampi(i, 0, 2)]


## Un texto con la fuente de cubitos del juego, centrado en `center` (en vertical, sobre el cuerpo de la letra): lo que va dentro de las teclas y los botones, para que no se mezclen dos tipografías.
## `alto`: el alto en pixeles que se quiere para el cuerpo de las letras (cada cubito mide alto / 7).
static func texto_cubitos(ci: CanvasItem, center: Vector2, text: String, alto: float, ink: Color) -> void:
	var cubo := alto / float(VFont.BODY_ROWS)
	var ancho := float(VFont.line_width(text)) * cubo
	var origen := center - Vector2(ancho * 0.5, (float(VFont.ACCENT_ROWS) + float(VFont.BODY_ROWS) * 0.5) * cubo)
	var l: Dictionary = VFont.layout([text])
	for c in l.cells:
		ci.draw_rect(Rect2(origen + Vector2(c.x, c.y) * cubo, Vector2(cubo, cubo)), ink)


## El ancho en pixeles del texto de una tecla con la fuente de cubitos (sin el margen).
static func ancho_cubitos(text: String, alto: float) -> float:
	return float(VFont.line_width(text)) * alto / float(VFont.BODY_ROWS)


## El ancho de la tapa de una tecla con su nombre.
static func ancho_tapa(text: String) -> float:
	return maxf(26.0, ancho_cubitos(text, 12.0) + 14.0)


## Dibuja el ícono del botón centrado en `center`, de radio `r`.
static func draw(ci: CanvasItem, center: Vector2, r: float, slot: int, dim := false) -> void:
	var st := style()
	var col: Color = COLORS[st][slot]
	if dim:
		col = col.darkened(0.55)
	ci.draw_circle(center, r + 2.0, Color(0.05, 0.03, 0.09))
	ci.draw_circle(center, r, col)
	ci.draw_arc(center, r, 0.0, TAU, 24, col.lightened(0.35), 2.0)
	var ink := Color(0.08, 0.05, 0.12) if not dim else Color(0.2, 0.18, 0.22)
	if st == Style.PLAYSTATION:
		var k := r * 0.45
		match slot:
			Slot.SOUTH:   # cruz
				ci.draw_line(center + Vector2(-k, -k), center + Vector2(k, k), ink, 3.0)
				ci.draw_line(center + Vector2(-k, k), center + Vector2(k, -k), ink, 3.0)
			Slot.WEST:   # cuadrado
				ci.draw_rect(Rect2(center - Vector2(k, k), Vector2(k, k) * 2.0), ink, false, 3.0)
			Slot.NORTH:   # triángulo
				ci.draw_polyline(PackedVector2Array([center + Vector2(0, -k * 1.1), center + Vector2(k * 1.05, k * 0.8), center + Vector2(-k * 1.05, k * 0.8), center + Vector2(0, -k * 1.1)]), ink, 3.0)
			Slot.EAST:   # círculo
				ci.draw_arc(center, k, 0.0, TAU, 20, ink, 3.0)
		return
	texto_cubitos(ci, center, LETTERS[st][slot], r * 1.05, ink)


## Una tecla del teclado (para las ayudas cuando se juega con teclado): un cuadradito con el texto.
static func draw_key(ci: CanvasItem, center: Vector2, r: float, text: String, dim := false) -> void:
	var col := Color(0.82, 0.78, 0.70) if not dim else Color(0.35, 0.32, 0.34)
	var rect := Rect2(center - Vector2(r, r), Vector2(r, r) * 2.0)
	ci.draw_rect(rect.grow(2.0), Color(0.05, 0.03, 0.09))
	ci.draw_rect(rect, col)
	texto_cubitos(ci, center, text, r * 1.05, Color(0.1, 0.07, 0.14))


## Botones que no son de cara (se piden por nombre): "LB", "RB", "LT", "RT" (hombros y gatillos), "DPAD" (cruceta), "DPAD_LR" (izquierda y derecha), "START", "BACK" (Select).
static func draw_named(ci: CanvasItem, center: Vector2, r: float, which: String, dim := false) -> void:
	var col := Color(0.62, 0.62, 0.70) if not dim else Color(0.3, 0.28, 0.32)
	var ink := Color(0.08, 0.05, 0.12)
	match which:
		"LB", "RB", "LT", "RT", "START", "BACK":
			var w := r * (2.6 if which != "START" and which != "BACK" else 3.2)
			var rect := Rect2(center - Vector2(w * 0.5, r * 0.75), Vector2(w, r * 1.5))
			ci.draw_rect(rect.grow(2.0), Color(0.05, 0.03, 0.09))
			ci.draw_rect(rect, col)
			var label := "SELECT" if which == "BACK" else which
			texto_cubitos(ci, center, label, r * 0.78 if which != "BACK" else r * 0.6, ink)
		"DPAD", "DPAD_LR":
			ci.draw_circle(center, r + 2.0, Color(0.05, 0.03, 0.09))
			var arm := r * 0.42
			var full := which == "DPAD"
			ci.draw_rect(Rect2(center - Vector2(r * 0.9, arm * 0.5), Vector2(r * 1.8, arm)), col)
			if full:
				ci.draw_rect(Rect2(center - Vector2(arm * 0.5, r * 0.9), Vector2(arm, r * 1.8)), col)
			else:
				ci.draw_rect(Rect2(center - Vector2(arm * 0.5, arm * 0.5), Vector2(arm, arm)), col.darkened(0.3))


## Una tecla del teclado con su nombre ("Enter", "Espacio", "Esc"...): una tapa de ancho `w` centrada en `center`.
static func draw_cap(ci: CanvasItem, center: Vector2, w: float, r: float, text: String, dim := false) -> void:
	var col := Color(0.82, 0.78, 0.70) if not dim else Color(0.35, 0.32, 0.34)
	var rect := Rect2(center - Vector2(w * 0.5, r), Vector2(w, r * 2.0))
	ci.draw_rect(rect.grow(2.0), Color(0.05, 0.03, 0.09))
	ci.draw_rect(rect, col)
	ci.draw_rect(Rect2(rect.position + Vector2(0, rect.size.y - 3.0), Vector2(w, 3.0)), col.darkened(0.3))
	texto_cubitos(ci, center, text, 12.0, Color(0.1, 0.07, 0.14))
