extends SceneTree
## Las imágenes de la página de Steam de Lucid Stakes (cápsulas, hero, logo), cada una en su medida, con la cara de Farolín y el nombre en letras de cubitos.
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


class Arte extends Control:
	const Draw := preload("res://scripts/ui/voxel_draw.gd")
	const Farolin := preload("res://scripts/personajes/farolin.gd")
	const UI := preload("res://scripts/ui/menu_ui.gd")
	var ancho := 0.0
	var alto := 0.0
	var modo := ""

	func _ready() -> void:
		size = Vector2(ancho, alto)
		if modo == "logo":
			_titulo(Vector2(ancho, alto) * 0.5, ancho * 0.92, alto * 0.9, true)
			return
		match modo:
			"horizontal":
				_titulo(Vector2(ancho * 0.66, alto * 0.5), ancho * 0.5, alto * 0.62, true)
			"vertical":
				_titulo(Vector2(ancho * 0.5, alto * 0.78), ancho * 0.86, alto * 0.30, true)
			"chica":
				_titulo(Vector2(ancho * 0.64, alto * 0.5), ancho * 0.62, alto * 0.7, false)

	## El nombre en letras de cubitos: dos renglones (o uno) centrados en `c`, que entran en `caja_w` x `caja_h`.
	func _titulo(c: Vector2, caja_w: float, caja_h: float, dos_renglones: bool) -> void:
		var textos := ["Lucid", "Stakes"] if dos_renglones else ["Lucid Stakes"]
		var base := UI.label(null, "Stakes" if dos_renglones else "Lucid Stakes", 1.0, UI.GOLD).get_minimum_size()
		var cubo := minf(caja_w / base.x, caja_h / (base.y * textos.size() * 1.12))
		cubo = floorf(cubo * 2.0) / 2.0
		var alto_r := base.y * cubo
		var y0 := c.y - alto_r * textos.size() * 0.5 - (alto_r * 0.06 if dos_renglones else 0.0)
		for i in textos.size():
			var l := UI.label(self, textos[i], cubo, UI.GOLD)
			l.position = Vector2(c.x - l.get_minimum_size().x * 0.5, y0 + i * alto_r * 1.06)

	func _draw() -> void:
		if modo == "logo":
			return
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

	func _centro_cara() -> Vector2:
		match modo:
			"horizontal": return Vector2(ancho * 0.25, alto * 0.5)
			"vertical": return Vector2(ancho * 0.5, alto * 0.34)
			"chica": return Vector2(alto * 0.5, alto * 0.5)
			_: return Vector2(ancho * 0.72, alto * 0.5)

	func _cubo_cara() -> float:
		match modo:
			"horizontal": return alto * 0.62 / 13.0
			"vertical": return ancho * 0.62 / 12.0
			"chica": return alto * 0.8 / 13.0
			_: return alto * 0.72 / 13.0


func _init() -> void:
	var carpeta: String = OS.get_cmdline_user_args()[0] if OS.get_cmdline_user_args().size() > 0 else "capturas/steam"
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path("res://" + carpeta))
	Profile.path = "user://shot_profile_steam.json"
	Profile.reset()
	Profile.mark_tutorial_done()
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
		vp.add_child(arte)
		for i in 5:
			await process_frame
		vp.get_texture().get_image().save_png("%s/%s.png" % [carpeta, p[0]])
		vp.queue_free()
	quit()
