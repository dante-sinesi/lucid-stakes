extends SceneTree
## Hoja con el arte de los contratos y de los ítems nuevos de los casinos: papeles con sello, sellos, "COBRADO" e íconos.
## Uso: GAME_SANDBOX=1 godot --path . --rendering-driver opengl3 --resolution 1500x1000 -s tests/capturas/shot_arte_contratos.gd -- ARCHIVO.png
const Arte := preload("res://scripts/ui/contract_art.gd")
const Icons := preload("res://scripts/ui/item_icons.gd")

const NUEVOS := ["racha_de_la_casa", "racha_de_visita", "pozo_del_jackpot", "caja_fuerte", "alcancia", "caza_recompensas", "contratista", "sello_de_oro"]


class _Hoja extends Control:
	const Arte := preload("res://scripts/ui/contract_art.gd")
	const Icons := preload("res://scripts/ui/item_icons.gd")

	func _draw() -> void:
		draw_rect(Rect2(Vector2.ZERO, size), Color(0.14, 0.09, 0.22))
		var objs: Array = ["movimientos", "racha", "especiales", "claridad"]
		for i in 4:   # los papeles, uno por rareza
			Arte.dibujar_papel(self, Vector2(20 + i * 125, 20), 6.0, i, objs[i], i * 5 + 1)
		Arte.dibujar_papel(self, Vector2(540, 20), 6.0, Arte.Rareza.RARA, "sin_empujar", 77, false)   # uno activo (sin chinche) y cobrado
		Arte.dibujar_cobrado(self, Vector2(540 + 6.0 * 8.5, 20 + 6.0 * 12), 6.0, 1.0)
		for i in 4:   # los sellos, grandes
			Arte.dibujar_sello(self, i, Vector2(700 + i * 95, 30), 10.0)
		var sx := 700.0
		for id in Arte.OBJETIVOS:   # los íconos de objetivos, chicos
			Arte.dibujar_objetivo(self, id, Vector2(sx, 130), 5.0)
			sx += 56.0
		var x := 20.0
		for id in ["racha_de_la_casa", "racha_de_visita", "pozo_del_jackpot", "caja_fuerte", "alcancia", "caza_recompensas", "contratista", "sello_de_oro"]:
			Icons.draw(self, id, Vector2(x, 200), 6.0)   # (tamaño de la interfaz)
			Icons.draw(self, id, Vector2(x, 290), 12.0)   # (grande, para mirar el dibujo)
			x += 135.0
		x = 20.0
		for id in Arte.OBJETIVOS:
			Arte.dibujar_objetivo(self, id, Vector2(x, 450), 11.0)
			x += 120.0
		Arte.dibujar_papel(self, Vector2(20, 590), 8.0, Arte.Rareza.IMPOSIBLE, "bomba", 5)   # un papel grande, para ver el detalle
		Arte.dibujar_papel(self, Vector2(200, 590), 8.0, Arte.Rareza.EPICA, "vidas", 9)


func _init() -> void:
	var args := OS.get_cmdline_user_args()
	for id in NUEVOS:
		if not Icons.has_icon(id):
			print("FALTA ícono: ", id)
		else:
			for r in Icons.ICONS[id].rows:
				if r.length() != 9:
					print("fila de largo ", r.length(), " en ", id)
	for id in Arte.OBJETIVOS:
		for r in Arte.OBJETIVOS[id].rows:
			if r.length() != 9:
				print("fila de largo ", r.length(), " en objetivo ", id)
		if Arte.OBJETIVOS[id].rows.size() != 9:
			print("no son 9 filas en objetivo ", id)
	var hoja := _Hoja.new()
	hoja.size = Vector2(1280, 855)
	root.add_child(hoja)
	await create_timer(0.6).timeout
	root.get_texture().get_image().save_png(args[0])
	quit(0)
