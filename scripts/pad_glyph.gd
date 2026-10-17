extends RefCounted
## Íconos de los botones del mando para los textos de ayuda y las opciones: un círculo del color del botón con su letra (Xbox y Nintendo) o su símbolo (PlayStation),
## según el mando que se detecte. Se piden por posición física ("slot"), no por nombre, así valen igual en cualquier mando:
##   SOUTH (abajo: A en Xbox, cruz en PlayStation) · WEST (izquierda: X, cuadrado) · NORTH (arriba: Y, triángulo) · EAST (derecha: B, círculo).
## El puente del mando (pad_bridge.gd) traduce SOUTH a Enter, WEST a Espacio, NORTH a C y EAST a Esc cuando hay un menú o un juego del casino.

enum Style { XBOX, PLAYSTATION, NINTENDO }
enum Slot { SOUTH, WEST, NORTH, EAST }

## Para forzar un estilo (pruebas o capturas); -1 = el del mando conectado.
static var forced := -1

const COLORS := {
	Style.XBOX: [Color(0.30, 0.78, 0.38), Color(0.28, 0.48, 0.95), Color(0.97, 0.80, 0.22), Color(0.90, 0.28, 0.28)],
	Style.PLAYSTATION: [Color(0.35, 0.55, 0.95), Color(0.93, 0.50, 0.75), Color(0.30, 0.78, 0.55), Color(0.92, 0.35, 0.35)],
	Style.NINTENDO: [Color(0.62, 0.62, 0.68), Color(0.62, 0.62, 0.68), Color(0.62, 0.62, 0.68), Color(0.62, 0.62, 0.68)],
}
const LETTERS := {
	Style.XBOX: ["A", "X", "Y", "B"],
	Style.NINTENDO: ["B", "Y", "X", "A"],
}


## El estilo del mando conectado (por el nombre que informa el sistema).
static func style() -> int:
	if forced >= 0:
		return forced
	var pads := Input.get_connected_joypads()
	if pads.is_empty():
		return Style.XBOX
	var n := Input.get_joy_name(int(pads[0])).to_lower()
	for key in ["playstation", "ps3", "ps4", "ps5", "dualshock", "dualsense", "sony"]:
		if n.contains(key):
			return Style.PLAYSTATION
	for key in ["nintendo", "switch", "joy-con", "pro controller"]:
		if n.contains(key):
			return Style.NINTENDO
	return Style.XBOX


## El botón de cada opción de una decisión (la primera es SOUTH, la segunda WEST, la tercera NORTH).
static func slot_for_option(i: int) -> int:
	return [Slot.SOUTH, Slot.WEST, Slot.NORTH][clampi(i, 0, 2)]


## La letra o el nombre del botón (para textos).
static func name_of(slot: int) -> String:
	var st := style()
	if st == Style.PLAYSTATION:
		return ["Cruz", "Cuadrado", "Triángulo", "Círculo"][slot]
	return LETTERS[st][slot]


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
	var font := ThemeDB.fallback_font
	var size := int(r * 1.5)
	var letter: String = LETTERS[st][slot]
	var w := font.get_string_size(letter, HORIZONTAL_ALIGNMENT_LEFT, -1, size).x
	ci.draw_string(font, center + Vector2(-w * 0.5, size * 0.36), letter, HORIZONTAL_ALIGNMENT_LEFT, -1, size, ink)


## Una tecla del teclado (para las ayudas cuando se juega con teclado): un cuadradito con el texto.
static func draw_key(ci: CanvasItem, center: Vector2, r: float, text: String, dim := false) -> void:
	var col := Color(0.82, 0.78, 0.70) if not dim else Color(0.35, 0.32, 0.34)
	var rect := Rect2(center - Vector2(r, r), Vector2(r, r) * 2.0)
	ci.draw_rect(rect.grow(2.0), Color(0.05, 0.03, 0.09))
	ci.draw_rect(rect, col)
	var font := ThemeDB.fallback_font
	var size := int(r * 1.5)
	var w := font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, size).x
	ci.draw_string(font, center + Vector2(-w * 0.5, size * 0.36), text, HORIZONTAL_ALIGNMENT_LEFT, -1, size, Color(0.1, 0.07, 0.14))
