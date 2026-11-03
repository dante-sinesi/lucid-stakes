extends Control
## Las señales grandes de la pantalla, sin una sola palabra: en vez de un cartel de texto, un símbolo de cubitos que aparece un momento y se desvanece.
##  - REBOBINAR: dos flechas a la izquierda sobre una banda oscura, como el cartel del nombre de la prueba (se deshizo un movimiento).
##  - NO_REBOBINAR: lo mismo, con el símbolo de cancelado en rojo encima (el escenario no deja deshacer).
##  - RECHAZO: el símbolo de cancelado en rojo, chico, en un punto de la pantalla (algo no se puede hacer ahora).
##  - CANDADO: un candado (algo del juego completo que la demo no incluye), con el nombre del juego que falta debajo (`mostrar(CANDADO, punto, "Tragamonedas")`).
## Uso: `mostrar(tipo)` (o `mostrar(tipo, punto)` para ponerla en un punto de la pantalla).

const Draw := preload("res://scripts/ui/voxel_draw.gd")
const Icons := preload("res://scripts/casino/casino_icons.gd")
const VoxelLabel := preload("res://scripts/ui/voxel_label.gd")

enum Tipo { REBOBINAR, NO_REBOBINAR, RECHAZO, CANDADO }

const CELDA := 14.0              # lado de un cubito de las señales grandes
const MARGEN_ABAJO := 74.0        # lo que queda libre abajo (la guía de controles), igual que el cartel de la prueba
const FLECHA := ["....#", "...##", "..###", ".####", "#####", ".####", "..###", "...##", "....#"]
const CANDADO_FILAS := ["...###...", "..#...#..", "..#...#..", "..#...#..", ".#######.", ".#######.", ".###.###.", ".###.###.", ".#######.", ".#######."]

var _tipo := Tipo.REBOBINAR
var _punto := Vector2(-1, -1)
var _t := 1.0e9                   # segundos desde que apareció
var _dur := 1.0
var _tween: Tween
var _rotulo: Control = null        # el nombre del juego bajo el candado
var _juego := ""                   # el juego que falta (para dibujar su ícono junto al candado)


func _init() -> void:
	name = "senal_pantalla"
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	visible = false
	process_mode = Node.PROCESS_MODE_ALWAYS
	_rotulo = VoxelLabel.new()
	_rotulo.cube = 4.0
	_rotulo.color = Color(1.0, 0.85, 0.35)
	_rotulo.align = VoxelLabel.Align.CENTER
	_rotulo.plate_alpha = 0.6
	_rotulo.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_rotulo.visible = false
	add_child(_rotulo)


## Muestra una señal. `punto`: dónde ponerla (por omisión, abajo en el centro las de rebobinar y en el centro de la pantalla las demás).
func mostrar(tipo: int, punto := Vector2(-1, -1), rotulo := "") -> void:
	_tipo = tipo
	_punto = punto
	_juego = rotulo
	_t = 0.0
	_dur = 1.1 if tipo == Tipo.REBOBINAR or tipo == Tipo.NO_REBOBINAR else (1.6 if rotulo != "" else 0.9)
	_rotulo.visible = tipo == Tipo.CANDADO and rotulo != ""
	if _rotulo.visible:
		_rotulo.text = rotulo
		var c := _punto if _punto.x >= 0.0 else size * 0.5
		_rotulo.set_anchors_and_offsets_preset(Control.PRESET_TOP_WIDE)
		_rotulo.offset_top = c.y + 70.0
		_rotulo.offset_bottom = c.y + 70.0 + 50.0
	visible = true
	modulate.a = 1.0
	if _tween != null:
		_tween.kill()
	_tween = create_tween()
	_tween.tween_interval(_dur * 0.55)
	_tween.tween_property(self, "modulate:a", 0.0, _dur * 0.45)
	_tween.tween_callback(func(): visible = false)
	queue_redraw()


func ocultar() -> void:
	if _tween != null:
		_tween.kill()
	visible = false


func _process(delta: float) -> void:
	if visible:
		_t += delta
		queue_redraw()


## El símbolo de cancelado (un aro con una barra en diagonal) de `n` x `n` cubitos, centrado en `centro`. `alfa` lo desvanece.
static func dibujar_cancelar(ci: CanvasItem, centro: Vector2, celda: float, n := 11, alfa := 1.0) -> void:
	var c := (n - 1) * 0.5
	var origen := centro - Vector2(n, n) * celda * 0.5
	var rojo := Color(0.95, 0.18, 0.2, alfa)
	for y in n:
		for x in n:
			var d := Vector2(x - c, y - c).length()
			var aro := d >= c - 1.15 and d <= c + 0.45
			var barra := absf(float(x) - float(y)) < 1.1 and d <= c + 0.45
			if not (aro or barra):
				continue
			var p := origen + Vector2(x, y) * celda
			ci.draw_rect(Rect2(p + Vector2(2, 3), Vector2(celda, celda)), Color(0, 0, 0, 0.5 * alfa))
			Draw.cube(ci, p, celda, rojo, true)


func _flechas(centro: Vector2, celda: float, desplazamiento: float, color: Color) -> void:
	var ancho := 11.0   # dos flechas de 5 columnas y una de separación
	var origen := centro - Vector2(ancho, 9.0) * celda * 0.5 + Vector2(desplazamiento, 0.0)
	for f in 2:
		for y in 9:
			for x in 5:
				if String(FLECHA[y])[x] != "#":
					continue
				var p := origen + Vector2(x + f * 6, y) * celda
				draw_rect(Rect2(p + Vector2(2, 3), Vector2(celda, celda)), Color(0, 0, 0, 0.5))
				Draw.cube(self, p, celda, color, true)


func _draw() -> void:
	if not visible:
		return
	var k := minf(_t / 0.12, 1.0)   # entra rápido
	var pop := 1.0 + 0.25 * (1.0 - k)
	match _tipo:
		Tipo.REBOBINAR, Tipo.NO_REBOBINAR:
			var abajo := size.y - MARGEN_ABAJO
			var alto := 9.0 * CELDA + 70.0
			var centro := Vector2(size.x * 0.5, abajo - alto * 0.5 + 10.0) if _punto.x < 0.0 else _punto
			draw_rect(Rect2(0, centro.y - alto * 0.5, size.x, alto), Color(0.02, 0.01, 0.05, 0.6))
			var corre := (-_t * 70.0 + 35.0) if _tipo == Tipo.REBOBINAR else 0.0   # las flechas "rebobinan": se corren hacia la izquierda mientras se ven (con el cancelado, quietas)
			_flechas(centro, CELDA * pop, corre, Color(1.0, 0.85, 0.35))
			if _tipo == Tipo.NO_REBOBINAR:
				dibujar_cancelar(self, centro, CELDA * 1.2 * pop, 11)
		Tipo.RECHAZO:
			var c := _punto if _punto.x >= 0.0 else size * 0.5
			dibujar_cancelar(self, c - Vector2(0, 30.0 * k), 8.0 * pop, 11)
		Tipo.CANDADO:
			var c := _punto if _punto.x >= 0.0 else size * 0.5
			var celda := 9.0 * pop
			var origen := c - Vector2(9, 10) * celda * 0.5
			for y in 10:
				for x in 9:
					if String(CANDADO_FILAS[y])[x] != "#":
						continue
					var p := origen + Vector2(x, y) * celda
					draw_rect(Rect2(p + Vector2(2, 3), Vector2(celda, celda)), Color(0, 0, 0, 0.5))
					Draw.cube(self, p, celda, Color(1.0, 0.85, 0.35) if y >= 4 else Color(0.75, 0.75, 0.82), true)
			if _juego != "":
				_icono_juego(c + Vector2(-92.0, 4.0) * pop, pop)


## El ícono del juego que falta, a un lado del candado: tres rodillos para las tragamonedas, una carta para el blackjack.
func _icono_juego(centro: Vector2, pop: float) -> void:
	var u := 66.0 * pop
	match _juego:
		"Tragamonedas":
			for i in 3:
				var cc := centro + Vector2((i - 1) * (u * 0.62), 0.0)
				draw_rect(Rect2(cc - Vector2(u * 0.28, u * 0.42), Vector2(u * 0.56, u * 0.84)), Color(0.08, 0.05, 0.14))
				draw_rect(Rect2(cc - Vector2(u * 0.28, u * 0.42), Vector2(u * 0.56, u * 0.84)), Color(1.0, 0.85, 0.35), false, 2.0)
				Icons.draw(self, ["cubo", "corona", "sol"][i], cc, u * 0.42)
		"Blackjack":
			var r := Rect2(centro - Vector2(u * 0.36, u * 0.5), Vector2(u * 0.72, u))
			draw_rect(Rect2(r.position + Vector2(3, 4), r.size), Color(0, 0, 0, 0.5))
			draw_rect(r, Color(0.97, 0.94, 0.86))
			draw_rect(r, Color(1.0, 0.85, 0.35), false, 2.0)
			Icons.draw(self, "sol", centro, u * 0.46)
