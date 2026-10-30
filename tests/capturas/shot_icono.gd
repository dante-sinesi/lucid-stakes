extends SceneTree
## El ícono de Lucid Stakes (la cara de Farolín con la luz de su llama): se dibuja a 512x512 y se guarda en PNG.
## Uso: GAME_SANDBOX=1 godot --path . --rendering-driver opengl3 --resolution 1280x720 -s tests/capturas/shot_icono.gd -- icono/icono_512.png
const Profile := preload("res://scripts/datos/profile.gd")

const L := 512


class Icono extends Control:
	const Draw := preload("res://scripts/ui/voxel_draw.gd")
	const Farolin := preload("res://scripts/personajes/farolin.gd")

	func _draw() -> void:
		var s := 16.0   # fondo: cubitos grandes en violetas oscuros, más claros hacia el centro
		for y in 32:
			for x in 32:
				var d := Vector2(x - 15.5, y - 15.5).length() / 22.0
				var t := clampf(0.8 - d, 0.0, 1.0) * 0.55 + Draw.noise(x, y, 3) * 0.16
				var col := Color(0.06, 0.03, 0.12).lerp(Color(0.34, 0.15, 0.52), t)
				draw_rect(Rect2(Vector2(x, y) * s, Vector2(s, s)), col)
				draw_rect(Rect2(Vector2(x, y) * s, Vector2(s, 1)), col.lightened(0.12))
		var c := Vector2(L, L) * 0.5
		for i in 18:   # la luz de la llama
			draw_circle(c, 300.0 * (1.0 - float(i) / 18.0), Color(1.0, 0.62, 0.2, 0.045))
		for i in 12:
			draw_circle(c, 190.0 * (1.0 - float(i) / 12.0), Color(1.0, 0.85, 0.4, 0.045))
		var cs := 27.0
		Farolin.draw_face(self, c - Vector2(12, 13) * cs * 0.5, cs)
		for k in 22:   # chispas de luz
			var a := Draw.noise(k, 7, 1) * TAU
			var r := lerpf(200.0, 245.0, Draw.noise(k, 11, 1))
			var q := 6.0 + floorf(Draw.noise(k, 13, 1) * 3.0) * 3.0
			Draw.cube(self, c + Vector2(cos(a), sin(a)) * r - Vector2(q, q) * 0.5, q, Color(1.0, 0.93, 0.6, 0.55 + 0.45 * Draw.noise(k, 17, 1)), true)


func _init() -> void:
	var salida: String = OS.get_cmdline_user_args()[0] if OS.get_cmdline_user_args().size() > 0 else "icono/icono_512.png"
	Profile.path = "user://shot_profile_icono.json"
	Profile.reset()
	Profile.mark_tutorial_done()
	var capa := CanvasLayer.new()
	root.add_child(capa)
	capa.add_child(Icono.new())
	for i in 4:
		await process_frame
	root.get_viewport().get_texture().get_image().get_region(Rect2i(0, 0, L, L)).save_png(salida)
	quit()
