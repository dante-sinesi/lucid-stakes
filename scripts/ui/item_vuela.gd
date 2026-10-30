extends Control
## Un ítem que se usa: su ícono sale de su casillero de la barra, vuela hasta el medio de la pantalla, crece un momento y se deshace en partículas de luz. Sin texto.
## Se usa para los consumibles que funcionan (y el Tótem y el Segundo aliento cuando salvan la sala). Uso: `ItemVuela.volar(capa, id, rect_del_casillero)`.

const Icons := preload("res://scripts/ui/item_icons.gd")

const VUELO := 0.55      # segundos hasta el medio
const PAUSA := 0.35      # lo que se queda grande en el medio antes de deshacerse
const CUBO := 7.0        # lado de un cubito del ícono (el casillero usa 6)

var _id := ""
var _desde := Vector2.ZERO
var _hacia := Vector2.ZERO
var _t := 0.0
var _chispas_listas := false


## Lanza el vuelo de `id` desde el casillero `desde` (en coordenadas de pantalla) hasta el medio de `capa`.
static func volar(capa: Node, id: String, desde: Rect2) -> void:
	var v = load("res://scripts/ui/item_vuela.gd").new()
	v._id = id
	v._desde = desde.get_center()
	capa.add_child(v)
	v._hacia = v.get_viewport_rect().size * 0.5


func _init() -> void:
	name = "item_vuela"
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	process_mode = Node.PROCESS_MODE_ALWAYS


func _process(delta: float) -> void:
	_t += delta
	if _t >= VUELO and not _chispas_listas:
		_chispas_listas = true
		_soltar_luz()
	if _t >= VUELO + PAUSA + 0.6:
		queue_free()
		return
	queue_redraw()


func _soltar_luz() -> void:
	var p := CPUParticles2D.new()
	p.position = _hacia
	p.one_shot = true
	p.amount = 70
	p.lifetime = 1.0
	p.explosiveness = 1.0
	p.direction = Vector2.UP
	p.spread = 180.0
	p.initial_velocity_min = 120.0
	p.initial_velocity_max = 340.0
	p.gravity = Vector2(0, 140.0)
	p.scale_amount_min = 9.0
	p.scale_amount_max = 18.0
	p.color = Color(1.0, 0.92, 0.55)
	var gradiente := Gradient.new()
	gradiente.set_color(0, Color(1.0, 0.95, 0.7, 1.0))
	gradiente.set_color(1, Color(1.0, 0.7, 0.2, 0.0))
	p.color_ramp = gradiente
	add_child(p)
	p.emitting = true


func _draw() -> void:
	if not Icons.has_icon(_id):
		return
	var k := minf(_t / VUELO, 1.0)
	var suave := 1.0 - pow(1.0 - k, 3.0)
	var pos := _desde.lerp(_hacia, suave)
	var escala := lerpf(1.0, 2.6, suave)
	var alfa := 1.0
	if _t > VUELO + PAUSA:
		alfa = clampf(1.0 - (_t - VUELO - PAUSA) / 0.3, 0.0, 1.0)
		escala *= 1.0 + (1.0 - alfa) * 0.6
	var cubo := CUBO * escala
	var origen := pos - Vector2(Icons.SIZE, Icons.SIZE) * cubo * 0.5
	if alfa < 1.0:
		draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
	if alfa > 0.0:
		Icons.draw(self, _id, origen, cubo)   # (el ícono se desvanece solo él: las partículas siguen un rato más)
