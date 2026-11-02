extends SceneTree
## Las imágenes de la página de Steam de Lucid Stakes (cápsulas, hero, logo), cada una en su medida: la cara de Farolín, el nombre en letras de cubitos gruesas y, en las grandes, capturas reales del juego (la torre y el casino).
## Primero se sacan las dos capturas del juego (`fuente_torre.png` y `fuente_casino.png`, en la misma carpeta) y después se arma cada pieza.
## Uso: GAME_SANDBOX=1 godot --path . --rendering-driver opengl3 --resolution 1280x720 -s tests/capturas/shot_steam.gd -- capturas/steam
const Profile := preload("res://scripts/datos/profile.gd")
const UI := preload("res://scripts/ui/menu_ui.gd")

## [archivo, ancho, alto, composición]
const PIEZAS := [
	["cabecera_920x430", 920, 430, "horizontal"],
	["capsula_principal_1232x706", 1232, 706, "horizontal"],
	["capsula_chica_462x174", 462, 174, "chica"],
	["capsula_vertical_600x900", 600, 900, "vertical"],
	["hero_3840x1240", 3840, 1240, "hero"],
	["logo_1280x720", 1280, 720, "logo"],
]

var tex_torre: ImageTexture
var tex_casino: ImageTexture


class Arte extends Control:
	const Draw := preload("res://scripts/ui/voxel_draw.gd")
	const Farolin := preload("res://scripts/personajes/farolin.gd")
	const UI := preload("res://scripts/ui/menu_ui.gd")
	var ancho := 0.0
	var alto := 0.0
	var modo := ""
	var torre: Texture2D
	var casino: Texture2D

	func _ready() -> void:
		size = Vector2(ancho, alto)
		if modo == "logo":
			_titulo(Vector2(ancho, alto) * 0.5, ancho * 0.92, alto * 0.9, true)
			return
		match modo:
			"horizontal":
				_titulo(Vector2(ancho * 0.30, alto * 0.70), ancho * 0.42, alto * 0.50, true)
			"vertical":
				_titulo(Vector2(ancho * 0.5, alto * 0.83), ancho * 0.9, alto * 0.30, true)
			"chica":
				_titulo(Vector2(ancho * 0.66, alto * 0.5), ancho * 0.6, alto * 0.88, true)

	## El nombre en letras de cubitos: dos renglones (o uno) centrados en `c`, que entran en `caja_w` x `caja_h`, en dorado, con la sombra dura de siempre.
	func _titulo(c: Vector2, caja_w: float, caja_h: float, dos_renglones: bool) -> void:
		var textos := ["Lucid", "Stakes"] if dos_renglones else ["Lucid Stakes"]
		var base := UI.label(null, "Stakes" if dos_renglones else "Lucid Stakes", 1.0, UI.GOLD).get_minimum_size()
		var cubo := minf(caja_w / (base.x + 1.0), caja_h / (base.y * textos.size() * 1.12))
		cubo = floorf(cubo * 2.0) / 2.0
		var alto_r := base.y * cubo
		var y0 := c.y - alto_r * textos.size() * 0.5 - (alto_r * 0.06 if dos_renglones else 0.0)
		for i in textos.size():
			var pos := Vector2(c.x - UI.label(null, textos[i], cubo, UI.GOLD).get_minimum_size().x * 0.5, y0 + i * alto_r * 1.06)
			var l := UI.label(self, textos[i], cubo, UI.GOLD)
			l.position = pos

	## Una textura cubriendo `r` (recortada al centro, sin deformarse).
	func _cubrir(tex: Texture2D, r: Rect2, tono := Color.WHITE) -> void:
		if tex == null:
			return
		var ts := tex.get_size() / 1.45   # (se recorta alrededor del centro: así no entran los indicadores de las esquinas)
		var corrida := Vector2(0, tex.get_size().y * 0.03)
		var k := maxf(r.size.x / ts.x, r.size.y / ts.y)
		var vis := r.size / k
		var src := Rect2((tex.get_size() - vis) * 0.5 + corrida, vis)
		draw_texture_rect_region(tex, r, src, tono)

	## Una captura enmarcada (borde dorado y sombra) de ancho `w` con su centro en `c`.
	func _tarjeta(tex: Texture2D, c: Vector2, w: float, zoom := 1.0) -> void:
		if tex == null:
			return
		var ts := tex.get_size() / zoom   # (se recorta alrededor del centro: lo que importa se ve más grande)
		var src := Rect2((tex.get_size() - ts) * 0.5 + Vector2(0, tex.get_size().y * 0.04), ts)
		var h := w * ts.y / ts.x
		var r := Rect2(c - Vector2(w, h) * 0.5, Vector2(w, h))
		var b := maxf(3.0, w * 0.012)
		draw_rect(Rect2(r.position + Vector2(b * 2.0, b * 2.5), r.size), Color(0, 0, 0, 0.55))
		draw_rect(r.grow(b), Color(0.95, 0.78, 0.28))
		draw_rect(r.grow(b * 0.4), Color(0.12, 0.06, 0.2))
		draw_texture_rect_region(tex, r, src)

	## Un velo oscuro que va de `izq` a `der` de opacidad a lo ancho de `r`.
	func _velo(r: Rect2, izq: float, der: float) -> void:
		var pasos := 40
		for i in pasos:
			var t := float(i) / float(pasos - 1)
			draw_rect(Rect2(r.position + Vector2(r.size.x * float(i) / pasos, 0.0), Vector2(r.size.x / pasos + 1.0, r.size.y)), Color(0.03, 0.01, 0.07, lerpf(izq, der, t)))

	func _draw() -> void:
		if modo == "logo":
			return
		var todo := Rect2(Vector2.ZERO, Vector2(ancho, alto))
		var con_capturas := modo != "chica"
		if con_capturas:
			_fondo_capturas(todo)
		else:
			_fondo_cubitos()
		var foco := _centro_cara()
		var cs := _cubo_cara()
		var radio := cs * 13.0 * 0.95
		for i in 18:   # la luz de la llama
			draw_circle(foco, radio * 1.6 * (1.0 - float(i) / 18.0), Color(1.0, 0.62, 0.2, 0.045))
		for i in 12:
			draw_circle(foco, radio * (1.0 - float(i) / 12.0), Color(1.0, 0.85, 0.4, 0.045))
		Farolin.draw_face(self, foco - Vector2(12, 13) * cs * 0.5, cs)
		for k in 22:   # chispas de luz
			var a := Draw.noise(k, 7, 1) * TAU
			var r := lerpf(radio * 0.75, radio * 1.1, Draw.noise(k, 11, 1))
			var q := cs * (0.22 + floorf(Draw.noise(k, 13, 1) * 3.0) * 0.1)
			Draw.cube(self, foco + Vector2(cos(a), sin(a)) * r - Vector2(q, q) * 0.5, q, Color(1.0, 0.93, 0.6, 0.55 + 0.45 * Draw.noise(k, 17, 1)), true)
		if con_capturas:
			_primer_plano()

	func _fondo_cubitos() -> void:
		var s := ceilf(alto / 32.0)   # fondo: cubitos grandes en violetas oscuros, más claros hacia el centro de la cara
		var foco := _centro_cara()
		for y in int(alto / s) + 1:
			for x in int(ancho / s) + 1:
				var p := Vector2(x + 0.5, y + 0.5) * s
				var d := (p - foco).length() / (alto * 0.75)
				var t := clampf(0.8 - d, 0.0, 1.0) * 0.55 + Draw.noise(x, y, 3) * 0.16
				var col := Color(0.06, 0.03, 0.12).lerp(Color(0.34, 0.15, 0.52), t)
				draw_rect(Rect2(Vector2(x, y) * s, Vector2(s, s)), col)
				draw_rect(Rect2(Vector2(x, y) * s, Vector2(s, maxf(1.0, s * 0.03))), col.lightened(0.12))

	func _fondo_capturas(todo: Rect2) -> void:
		match modo:
			"horizontal":   # el casino de fondo, oscurecido hacia la izquierda, donde van la cara y el nombre
				_cubrir(casino, todo, Color(0.8, 0.75, 0.9))
				_velo(todo, 0.93, 0.45)
			"vertical":   # la torre de fondo
				_cubrir(torre, todo, Color(0.8, 0.75, 0.9))
				draw_rect(todo, Color(0.03, 0.01, 0.07, 0.55))
			_:   # el hero: la torre a la izquierda y el casino a la derecha
				var mitad := Rect2(Vector2.ZERO, Vector2(ancho * 0.5, alto))
				_cubrir(torre, mitad, Color(0.8, 0.75, 0.9))
				_cubrir(casino, Rect2(Vector2(ancho * 0.5, 0), mitad.size), Color(0.8, 0.75, 0.9))
				draw_rect(todo, Color(0.03, 0.01, 0.07, 0.35))

	func _primer_plano() -> void:
		match modo:
			"horizontal":   # la torre enmarcada a la derecha
				_tarjeta(torre, Vector2(ancho * 0.74, alto * 0.5), ancho * 0.45, 1.8)
			"vertical":   # el casino enmarcado en el medio
				_tarjeta(casino, Vector2(ancho * 0.5, alto * 0.52), ancho * 0.84, 1.3)

	func _centro_cara() -> Vector2:
		match modo:
			"horizontal": return Vector2(ancho * 0.17, alto * 0.27)
			"vertical": return Vector2(ancho * 0.5, alto * 0.16)
			"chica": return Vector2(alto * 0.5, alto * 0.5)
			_: return Vector2(ancho * 0.5, alto * 0.5)

	func _cubo_cara() -> float:
		match modo:
			"horizontal": return alto * 0.40 / 13.0
			"vertical": return ancho * 0.36 / 12.0
			"chica": return alto * 0.8 / 13.0
			_: return alto * 0.55 / 13.0


func _init() -> void:
	var carpeta: String = OS.get_cmdline_user_args()[0] if OS.get_cmdline_user_args().size() > 0 else "capturas/steam"
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path("res://" + carpeta))
	Profile.path = "user://shot_profile_steam.json"
	Profile.reset()
	Profile.mark_tutorial_done()
	await _capturas_del_juego(carpeta)
	for p in PIEZAS:
		var vp := SubViewport.new()
		vp.size = Vector2i(p[1], p[2])
		vp.transparent_bg = p[3] == "logo"
		vp.render_target_update_mode = SubViewport.UPDATE_ALWAYS
		root.add_child(vp)
		var arte := Arte.new()
		arte.ancho = p[1]
		arte.alto = p[2]
		arte.modo = p[3]
		arte.torre = tex_torre
		arte.casino = tex_casino
		vp.add_child(arte)
		for i in 5:
			await process_frame
		vp.get_texture().get_image().save_png("%s/%s.png" % [carpeta, p[0]])
		vp.queue_free()
	quit()


## Las dos capturas reales del juego (1280 x 720): la torre con unos pasos dados y el casino con la cámara en la sala.
func _capturas_del_juego(carpeta: String) -> void:
	var main = load("res://scenes/main.tscn").instantiate()
	main.test_mode = true
	root.add_child(main)
	for i in 8:
		await process_frame
	main.start_game("pesadilla", "media")
	for i in 40:
		await process_frame
	var cam: Array = main.torre.t.salas[0].d.camino
	for i in mini(5, cam.size() - 1):
		main.torre.accion(Vector3i(int(cam[i][0]), 0, int(cam[i][1])), int(cam[i][2]))
		for k in 20:
			await process_frame
	for i in 30:
		await process_frame
	var img_torre := root.get_texture().get_image()
	img_torre.save_png("%s/fuente_torre.png" % carpeta)
	tex_torre = ImageTexture.create_from_image(img_torre)
	main.enter_casino()
	for i in 90:
		await process_frame
	var img_casino := root.get_texture().get_image()
	img_casino.save_png("%s/fuente_casino.png" % carpeta)
	tex_casino = ImageTexture.create_from_image(img_casino)
	main.queue_free()
	for i in 4:
		await process_frame
