extends SceneTree
## Borradores del ícono de Lucid Stakes: tres con Farolín y tres con el ícono de claridad, cada uno de 512x512, y una hoja con los seis.
## Uso: GAME_SANDBOX=1 godot --path . --rendering-driver opengl3 --resolution 1280x720 -s tests/capturas/shot_iconos.gd -- PREFIJO
const Profile := preload("res://scripts/datos/profile.gd")

const L := 512.0


class Hoja extends Control:
	const Draw := preload("res://scripts/ui/voxel_draw.gd")
	const Farolin := preload("res://scripts/personajes/farolin.gd")
	const ClarityIcon := preload("res://scripts/ui/clarity_icon.gd")
	const ORO := Color(1.0, 0.85, 0.40)
	const MARMOL := Color(0.93, 0.90, 0.83)

	var solo := -1   # -1 = la hoja de los seis; 0..5 = un solo ícono, sobre todo el control

	func _draw() -> void:
		for i in 6:
			if solo >= 0 and solo != i:
				continue
			var o := Vector2(float(i % 3) * L, floorf(float(i) / 3.0) * L) if solo < 0 else Vector2.ZERO
			draw_set_transform(o, 0.0, Vector2.ONE)
			_fondo(i)
			match i:
				0: _faro_solo()
				1: _faro_torre()
				2: _faro_carta()
				3: _rayo_solo()
				4: _rayo_ficha()
				5: _rayo_portal()
			draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)

	## Fondo: cubitos grandes en violetas oscuros, más claros hacia el centro.
	func _fondo(sem: int) -> void:
		var s := 16.0
		for y in 32:
			for x in 32:
				var d := Vector2(x - 15.5, y - 15.5).length() / 22.0
				var n := Draw.noise(x, y, sem + 3)
				var t := clampf(0.8 - d, 0.0, 1.0) * 0.55 + n * 0.16
				var col := Color(0.06, 0.03, 0.12).lerp(Color(0.34, 0.15, 0.52), t)
				draw_rect(Rect2(Vector2(x, y) * s, Vector2(s, s)), col)
				draw_rect(Rect2(Vector2(x, y) * s, Vector2(s, 1)), col.lightened(0.12))

	func _halo(c: Vector2, r: float, col: Color, pasos := 18) -> void:
		for i in pasos:
			draw_circle(c, r * (1.0 - float(i) / pasos), Color(col.r, col.g, col.b, 0.045))

	func _cubo(p: Vector2, s: float, col: Color) -> void:
		Draw.cube(self, p, s, col, true)

	## Chispas de luz: cubitos dorados sueltos alrededor de un punto.
	func _chispas(c: Vector2, rmin: float, rmax: float, n: int, sem: int) -> void:
		for k in n:
			var a := Draw.noise(k, 7, sem) * TAU
			var r := lerpf(rmin, rmax, Draw.noise(k, 11, sem))
			var s := 6.0 + floorf(Draw.noise(k, 13, sem) * 3.0) * 3.0
			_cubo(c + Vector2(cos(a), sin(a)) * r - Vector2(s, s) * 0.5, s, Color(1.0, 0.93, 0.6, 0.55 + 0.45 * Draw.noise(k, 17, sem)))

	## 1) Farolín solo: su cara grande, con la luz de la llama detrás.
	func _faro_solo() -> void:
		var s := 27.0
		var c := Vector2(L * 0.5, L * 0.5)
		_halo(c, 300.0, Color(1.0, 0.62, 0.2))
		_halo(c, 190.0, Color(1.0, 0.85, 0.4), 12)
		Farolin.draw_face(self, c - Vector2(12, 13) * s * 0.5, s)
		_chispas(c, 200.0, 245.0, 22, 1)

	## 2) Farolín sobre la torre: un farol que corona la torre de cubitos con su escalera en espiral.
	func _faro_torre() -> void:
		var s := 20.0
		var base_x := L * 0.5 - 4.5 * s
		_halo(Vector2(L * 0.5, 190.0), 280.0, Color(1.0, 0.62, 0.2))
		for y in 13:
			for x in 9:
				var py := 262.0 + y * s
				if py > L:
					continue
				var borde := x == 0 or x == 8
				var col := Color(0.20, 0.12, 0.32).lerp(Color(0.36, 0.20, 0.52), Draw.noise(x, y, 5) * 0.8)
				if borde:
					col = col.darkened(0.25)
				_cubo(Vector2(base_x + x * s, py), s, col)
		for k in 12:   # la escalera: una diagonal que sube y rebota
			var x := (k % 8) if (k / 8) % 2 == 0 else 8 - (k % 8)
			var y := 12 - k
			_cubo(Vector2(base_x + x * s, 262.0 + y * s), s, ORO.lerp(Color(1, 0.6, 0.2), float(k) / 12.0))
		var f := 15.0
		Farolin.draw_face(self, Vector2(L * 0.5 - 6.0 * f, 262.0 - 13.0 * f - 6.0), f)
		_chispas(Vector2(L * 0.5, 160.0), 120.0, 200.0, 16, 2)

	## 3) Farolín como carta: la cara en una carta dorada inclinada, como las del casino.
	func _faro_carta() -> void:
		draw_set_transform(Vector2(L * 0.5, L * 0.5), deg_to_rad(-7.0), Vector2.ONE)
		var w := 300.0
		var h := 400.0
		draw_rect(Rect2(Vector2(-w, -h) * 0.5 + Vector2(10, 14), Vector2(w, h)), Color(0, 0, 0, 0.45))
		draw_rect(Rect2(Vector2(-w, -h) * 0.5, Vector2(w, h)), Color(0.13, 0.07, 0.22))
		var b := 12.0
		for x in int(w / b):   # el borde dorado, en cubitos
			for lado in [0.0, h - b]:
				_cubo(Vector2(-w * 0.5 + x * b, -h * 0.5 + lado), b, ORO.lerp(Color(0.8, 0.55, 0.15), Draw.noise(x, int(lado), 9)))
		for y in int(h / b):
			for lado in [0.0, w - b]:
				_cubo(Vector2(-w * 0.5 + lado, -h * 0.5 + y * b), b, ORO.lerp(Color(0.8, 0.55, 0.15), Draw.noise(y, int(lado), 4)))
		_halo(Vector2(0, 6), 170.0, Color(1.0, 0.62, 0.2), 12)
		var s := 17.0
		Farolin.draw_face(self, Vector2(-6.0 * s, -6.5 * s), s)
		var rombo := ["..#..", ".###.", "#####", ".###.", "..#.."]   # el palo de la carta: un rombo de cubitos, en dos esquinas
		for esquina in [Vector2(-w * 0.5 + 26.0, -h * 0.5 + 26.0), Vector2(w * 0.5 - 26.0 - 5.0 * 9.0, h * 0.5 - 26.0 - 5.0 * 9.0)]:
			for y in 5:
				for x in 5:
					if rombo[y][x] == "#":
						_cubo(esquina + Vector2(x, y) * 9.0, 9.0, Color(0.95, 0.25, 0.3))
		draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)

	## 4) El rayo solo: grande, girado, con halo y chispas.
	func _rayo_solo() -> void:
		var c := Vector2(L * 0.5, L * 0.5)
		_halo(c, 300.0, Color(1.0, 0.8, 0.3))
		_halo(c, 170.0, Color(1.0, 0.95, 0.7), 12)
		ClarityIcon.draw_bolt(self, c, 24.0, 0.62)
		_chispas(c, 170.0, 250.0, 26, 3)

	## 5) El rayo en una ficha de casino: aro con muescas doradas y marfil, y el rayo en el centro.
	func _rayo_ficha() -> void:
		var c := Vector2(L * 0.5, L * 0.5)
		var s := 14.0
		draw_circle(c + Vector2(8, 12), 232.0, Color(0, 0, 0, 0.4))
		for y in 36:
			for x in 36:
				var p := Vector2(x - 17.5, y - 17.5) * s
				var d := p.length()
				if d > 230.0:
					continue
				var col := Color(0.10, 0.05, 0.20).lerp(Color(0.26, 0.12, 0.42), Draw.noise(x, y, 6))
				if d > 196.0:   # el borde: muescas que alternan oro y marfil
					var ang := fposmod(p.angle(), TAU)
					col = ORO if int(ang / TAU * 16.0) % 2 == 0 else MARMOL
				elif d > 176.0:
					col = Color(0.55, 0.38, 0.1)
				elif d > 160.0 and d <= 170.0:
					col = ORO
				_cubo(c + p - Vector2(s, s) * 0.5, s, col)
		_halo(c, 150.0, Color(1.0, 0.8, 0.3), 12)
		ClarityIcon.draw_bolt(self, c, 13.0, 0.62)

	## 6) El rayo en el portal: un arco de mármol que se abre a la violeta, con el rayo flotando adentro.
	func _rayo_portal() -> void:
		var s := 20.0
		var c := Vector2(L * 0.5, 262.0)
		for y in 20:
			for x in 14:
				var px := L * 0.5 + (x - 7.0) * s
				var py := 62.0 + y * s
				var dx := x - 6.5
				var dentro := absf(dx) < 4.4 and (y >= 6 or Vector2(dx, y - 6.0).length() < 4.4)
				var arco := absf(dx) < 6.6 and (y >= 3 or Vector2(dx, y - 3.0).length() < 6.6)
				if dentro:
					var t := 1.0 - float(y) / 20.0
					_cubo(Vector2(px, py), s, Color(0.22, 0.10, 0.40).lerp(Color(0.55, 0.30, 0.78), t * 0.7 + Draw.noise(x, y, 2) * 0.2))
				elif arco:
					_cubo(Vector2(px, py), s, MARMOL.lerp(Color(0.62, 0.58, 0.55), Draw.noise(x, y, 8) * 0.9))
		_halo(c, 190.0, Color(1.0, 0.85, 0.4), 14)
		ClarityIcon.draw_bolt(self, c, 15.0, 0.62)
		_chispas(c, 80.0, 150.0, 14, 4)


func _init() -> void:
	var pref: String = OS.get_cmdline_user_args()[0] if OS.get_cmdline_user_args().size() > 0 else "capturas/icono"
	Profile.path = "user://shot_profile_iconos.json"
	Profile.reset()
	Profile.mark_tutorial_done()
	var capa := CanvasLayer.new()
	root.add_child(capa)
	var hoja := Hoja.new()
	hoja.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	capa.add_child(hoja)
	var hojaimg := Image.create(int(L) * 3, int(L) * 2, false, Image.FORMAT_RGBA8)
	for i in 6:
		hoja.solo = i
		hoja.queue_redraw()
		for k in 3:
			await process_frame
		var parte := root.get_viewport().get_texture().get_image().get_region(Rect2i(0, 0, int(L), int(L)))
		parte.save_png("%s_%d.png" % [pref, i + 1])
		hojaimg.blit_rect(parte, Rect2i(0, 0, int(L), int(L)), Vector2i((i % 3) * int(L), (i / 3) * int(L)))
	hojaimg.save_png(pref + "_hoja.png")
	quit()
