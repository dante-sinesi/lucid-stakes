extends Control
## Los contratos activos en el menú de pausa: solo los íconos, en columna, a la derecha del menú (el HUD de la torre no los muestra). Cada uno es una chapa de pergamino con el
## ícono del objetivo y, en la esquina, un sello chico del color de su rareza; a la derecha de cada chapa van su título y sus condiciones. `mostrar` recibe una lista de {objetivo, rareza, titulo, condiciones}
## (ver `contract_art.gd`).

const Arte := preload("res://scripts/ui/contract_art.gd")

const CUBO := 7.0                 # lado del cubito del ícono (la chapa mide 11 x 11 cubitos)
const CUBO_SELLO := 4.0
const CHAPA := 11
const SEPARACION := 20.0
const MARGEN_DERECHO := 16.0      # lo que queda entre la columna y el borde de la pantalla
const ANCHO_TEXTO := 250.0        # lo que mide el texto a la derecha de cada chapa

var contratos: Array = []


func _init() -> void:
	name = "contratos_activos"
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	set_anchors_preset(Control.PRESET_CENTER_RIGHT)
	visible = false


## Pone los contratos activos; sin ninguno, la columna no se ve.
func mostrar(lista: Array) -> void:
	contratos = lista
	var alto := maxf(contratos.size() - 1.0, 0.0) * SEPARACION
	for c in contratos:
		alto += _alto_de(c)
	offset_right = -MARGEN_DERECHO
	offset_left = -MARGEN_DERECHO - CHAPA * CUBO - CUBO_SELLO * 3.0 - ANCHO_TEXTO
	offset_top = -alto * 0.5
	offset_bottom = alto * 0.5
	visible = not contratos.is_empty()
	queue_redraw()


## Lo que mide cada renglón: la chapa o, si es más alto, su texto.
func _alto_de(c: Dictionary) -> float:
	var font := ThemeDB.fallback_font
	var alto := 28.0
	for cond in c.get("condiciones", []):
		alto += font.get_multiline_string_size(str(cond), HORIZONTAL_ALIGNMENT_LEFT, ANCHO_TEXTO - 14.0, 15).y + 4.0
	return maxf(CHAPA * CUBO, alto)


func _draw() -> void:
	var lado := CHAPA * CUBO
	var font := ThemeDB.fallback_font
	var y0 := 0.0
	for c in contratos:
		var pos := Vector2(0.0, y0)
		draw_rect(Rect2(pos + Vector2(CUBO * 0.8, CUBO * 1.2), Vector2(lado, lado)), Color(0, 0, 0, 0.55))   # sombra dura
		draw_rect(Rect2(pos, Vector2(lado, lado)), Arte.PAPEL)
		draw_rect(Rect2(pos, Vector2(lado, lado)), Arte.PAPEL_SOMBRA, false, 2.0)
		Arte.dibujar_objetivo(self, str(c.get("objetivo", "")), pos + Vector2(CUBO, CUBO), CUBO)
		Arte.dibujar_sello(self, int(c.get("rareza", 0)), pos + Vector2(lado - CUBO_SELLO * 4.0, lado - CUBO_SELLO * 4.0), CUBO_SELLO)
		var x := lado + CUBO_SELLO * 3.0 + 14.0
		draw_string(font, pos + Vector2(x, 18.0), str(c.get("titulo", "")), HORIZONTAL_ALIGNMENT_LEFT, ANCHO_TEXTO - 14.0, 20, Color(1.0, 0.93, 0.7))
		var y := 44.0
		for cond in c.get("condiciones", []):
			draw_multiline_string(font, pos + Vector2(x, y), str(cond), HORIZONTAL_ALIGNMENT_LEFT, ANCHO_TEXTO - 14.0, 15, -1, Color(0.97, 0.95, 0.9))
			y += font.get_multiline_string_size(str(cond), HORIZONTAL_ALIGNMENT_LEFT, ANCHO_TEXTO - 14.0, 15).y + 4.0
		y0 += _alto_de(c) + SEPARACION
