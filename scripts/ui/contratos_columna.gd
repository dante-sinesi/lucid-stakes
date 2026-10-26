extends Control
## Los contratos activos en el menú de pausa: solo los íconos, en columna, a la derecha del menú (el HUD de la torre no los muestra). Cada uno es una chapa de pergamino con el
## ícono del objetivo y, en la esquina, un sello chico del color de su rareza. `mostrar` recibe una lista de {objetivo: String, rareza: int} (ver `contract_art.gd`).

const Arte := preload("res://scripts/ui/contract_art.gd")

const CUBO := 7.0                 # lado del cubito del ícono (la chapa mide 11 x 11 cubitos)
const CUBO_SELLO := 4.0
const CHAPA := 11
const SEPARACION := 20.0
const MARGEN_DERECHO := 120.0     # lo que queda entre la columna y el borde de la pantalla

var contratos: Array = []


func _init() -> void:
	name = "contratos_activos"
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	set_anchors_preset(Control.PRESET_CENTER_RIGHT)
	visible = false


## Pone los contratos activos; sin ninguno, la columna no se ve.
func mostrar(lista: Array) -> void:
	contratos = lista
	var lado := CHAPA * CUBO
	var alto := contratos.size() * lado + maxf(contratos.size() - 1.0, 0.0) * SEPARACION
	offset_right = -MARGEN_DERECHO
	offset_left = -MARGEN_DERECHO - lado - CUBO_SELLO * 3.0
	offset_top = -alto * 0.5
	offset_bottom = alto * 0.5
	visible = not contratos.is_empty()
	queue_redraw()


func _draw() -> void:
	var lado := CHAPA * CUBO
	for i in contratos.size():
		var c: Dictionary = contratos[i]
		var pos := Vector2(0.0, i * (lado + SEPARACION))
		draw_rect(Rect2(pos + Vector2(CUBO * 0.8, CUBO * 1.2), Vector2(lado, lado)), Color(0, 0, 0, 0.55))   # sombra dura
		draw_rect(Rect2(pos, Vector2(lado, lado)), Arte.PAPEL)
		draw_rect(Rect2(pos, Vector2(lado, lado)), Arte.PAPEL_SOMBRA, false, 2.0)
		Arte.dibujar_objetivo(self, str(c.get("objetivo", "")), pos + Vector2(CUBO, CUBO), CUBO)
		Arte.dibujar_sello(self, int(c.get("rareza", 0)), pos + Vector2(lado - CUBO_SELLO * 4.0, lado - CUBO_SELLO * 4.0), CUBO_SELLO)
