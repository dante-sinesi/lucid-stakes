extends RefCounted
## Genera el diseño de minibloques de los cinco personajes (Dante, Gaby, Gatito, Perrito y Conejito) y los guarda en data/modelos/personajes.jsonl (el formato del editor de
## modelos: se pueden retocar ahí). Minibloques de 0,02 en una caja de 48 x 64 x 48 con el origen en los pies (24, 0, 24). Cuerpo más largo y delgado que el de cajas:
## piernas de 10 minibloques, torso de 10, cabeza de 22 x 16 x 20 (la misma de siempre: los gorros y las prendas siguen calzando) y brazos de 12 que salen a los lados del torso.
## Las partes que giran se llaman como en el juego (pata_i/d, brazo_i/d, cola) y llevan su pivote. Uso: GAME_SANDBOX=1 godot --headless --path . -s tests/sondas/generar_personajes.gd

const ModelLib := preload("res://scripts/personajes/model_lib.gd")
const Characters := preload("res://scripts/personajes/characters.gd")

const VOX := 0.02
const SIZE := [48, 64, 48]
const ORIGEN := Vector3i(24, 0, 24)


## Los registros de los cinco personajes.
static func todos() -> Array:
	var out: Array = []
	for ch in Characters.ALL:
		out.append(registro(ch))
	return out


## Guarda los cinco en personajes.jsonl (reemplaza los que ya estaban con el mismo id).
static func guardar() -> void:
	for rec in todos():
		ModelLib.save_record(rec, "personajes.jsonl")


static func registro(ch: Dictionary) -> Dictionary:
	var partes := {}   # nombre -> {Vector3i: Color}
	var pivotes := {
		"pata_i": Vector3(-3, 10, 0), "pata_d": Vector3(3, 10, 0),
		"brazo_i": Vector3(-10, 19, 0), "brazo_d": Vector3(10, 19, 0),
		"cola": Vector3(0, 11, -7),
	}
	for n in ["cuerpo", "pata_i", "pata_d", "brazo_i", "brazo_d"]:
		partes[n] = {}
	var humano := str(ch.get("kind", "")) == "humano"
	var sd := str(ch.id).hash() % 1000
	if humano:
		_humano(partes, ch, sd)
	else:
		_animal(partes, ch, sd)
	var palette: Array = []
	var lista: Array = []
	for n in partes:
		var m: Dictionary = partes[n]
		if m.is_empty():
			continue
		var pv = pivotes.get(n, null)
		lista.append({"name": n, "pivot": null if pv == null else [pv.x + ORIGEN.x, pv.y, pv.z + ORIGEN.z], "voxels": ModelLib.pack_voxels(m, palette)})
	return {"id": ch.id, "kind": "personaje", "name": ch.name, "voxel": VOX, "size": SIZE, "origin": [ORIGEN.x, ORIGEN.y, ORIGEN.z], "palette": palette, "parts": lista}


# --- primitivas ----------------------------------------------------------------------------------------------------------------

static func _h(x: int, y: int, z: int, k: int) -> float:
	var h := (x * 73856093) ^ (y * 19349663) ^ (z * 83492791) ^ (k * 2654435761)
	return float(absi(h) % 1000) / 1000.0


## Un minibloque en coordenadas centradas (x y z respecto de los pies) con una variación de color suave.
static func _p(m: Dictionary, x: int, y: int, z: int, col: Color, ruido := 0.04, sd := 0) -> void:
	var r := _h(x, y, z, sd + 7) - 0.5
	var c := col.lightened(r * ruido * 2.0) if r > 0.0 else col.darkened(-r * ruido * 2.0)
	m[Vector3i(x + ORIGEN.x, y, z + ORIGEN.z)] = c


## Una caja de minibloques (los rangos incluyen los dos extremos). `redondea`: saca las ocho esquinas.
static func _caja(m: Dictionary, x0: int, x1: int, y0: int, y1: int, z0: int, z1: int, col: Color, ruido := 0.04, sd := 0, redondea := false) -> void:
	for x: int in range(x0, x1 + 1):
		for y: int in range(y0, y1 + 1):
			for z: int in range(z0, z1 + 1):
				if redondea and (x == x0 or x == x1) and (y == y0 or y == y1) and (z == z0 or z == z1):
					continue
				_p(m, x, y, z, col, ruido, sd)


static func _borrar(m: Dictionary, x: int, y: int, z: int) -> void:
	m.erase(Vector3i(x + ORIGEN.x, y, z + ORIGEN.z))


static func _tiene(m: Dictionary, x: int, y: int, z: int) -> bool:
	return m.has(Vector3i(x + ORIGEN.x, y, z + ORIGEN.z))


# --- partes comunes ------------------------------------------------------------------------------------------------------------

## La cara: ojos grandes con brillo, y lo que le dé cada personaje. `z`: el plano de la cara.
static func _ojos(m: Dictionary, z: int, y: int, sep: int, ojo: Color, brillo: Color, ancho := 3, alto := 4) -> void:
	for lado: int in [-1, 1]:
		var x0: int = sep if lado > 0 else -sep - ancho + 1
		_caja(m, x0, x0 + ancho - 1, y, y + alto - 1, z, z, ojo, 0.0)
		var hx: int = x0 + (ancho - 1 if lado > 0 else 0)   # (el brillo, arriba y hacia el centro de la cara)
		hx = x0 + (0 if lado > 0 else ancho - 1)
		_p(m, hx, y + alto - 1, z, brillo, 0.0)


## Las patas: un bloque de 6 x 10 x 8 con el pie. Cada personaje les da sus colores.
static func _pata(m: Dictionary, lado: int, arriba: Color, abajo: Color, suela: Color, sd: int, pata_animal := false) -> void:
	var x0: int = 1 if lado > 0 else -6
	var x1: int = x0 + 5
	for y in range(3, 10):
		_caja(m, x0, x1, y, y, -4, 3, arriba.darkened(0.08 * float(10 - y) / 7.0), 0.04, sd)
	# costura por dentro
	for y in range(3, 10):
		var xi: int = x0 if lado > 0 else x1
		_p(m, xi, y, 0, arriba.darkened(0.2), 0.0)
	# el pie: un poco más largo hacia adelante, con la suela más oscura
	_caja(m, x0, x1, 1, 2, -4, 5, abajo, 0.03, sd)
	_caja(m, x0, x1, 0, 0, -4, 5, suela, 0.03, sd)
	if not pata_animal:   # (zapatilla: punta de goma y cordones)
		_caja(m, x0 + 1, x1 - 1, 2, 2, 5, 5, abajo.lightened(0.15), 0.0)
		for z in range(0, 3):
			_p(m, x0 + 2, 3, z, abajo.lightened(0.3), 0.0)
			_p(m, x0 + 3, 3, z, abajo.lightened(0.3), 0.0)
	else:   # (deditos)
		_p(m, x0 + 1, 1, 5, suela.lightened(0.1), 0.0)
		_p(m, x0 + 4, 1, 5, suela.lightened(0.1), 0.0)


## Un brazo de 4 x 12 x 4: manga (o pelo), antebrazo y mano. `lado`: -1 izquierdo, 1 derecho.
static func _brazo(m: Dictionary, lado: int, manga: Color, manga_oscura: Color, piel: Color, sd: int, pelaje := false) -> void:
	var x0: int = 8 if lado > 0 else -11
	var x1: int = x0 + 3
	for y in range(13, 19):
		_caja(m, x0, x1, y, y, -2, 1, manga.darkened(0.06 * float(18 - y) / 5.0), 0.04, sd)
	_caja(m, x0, x1, 13, 13, -2, 1, manga_oscura, 0.03, sd)   # (el puño de la manga)
	_caja(m, x0, x1, 9, 12, -2, 1, manga if pelaje else piel, 0.03, sd)   # (antebrazo)
	_caja(m, x0, x1, 7, 8, -2, 1, piel if not pelaje else manga.lightened(0.2), 0.03, sd)   # (mano)
	# el pulgar, hacia adelante y adentro
	var xp: int = x0 if lado > 0 else x1
	_p(m, xp, 8, 2, piel if not pelaje else manga.lightened(0.2), 0.0)
	_p(m, xp, 7, 2, piel if not pelaje else manga.lightened(0.2), 0.0)


# --- los humanos ---------------------------------------------------------------------------------------------------------------

static func _humano(partes: Dictionary, ch: Dictionary, sd: int) -> void:
	var c: Dictionary = partes.cuerpo
	var piel: Color = ch.skin
	var pelo: Color = ch.hair
	var remera: Color = ch.shirt
	var remera_oscura: Color = ch.shirt_dark
	var larga: bool = str(ch.style) == "largo"
	var ojo := Color(0.06, 0.04, 0.08)
	_pata(partes.pata_i, -1, ch.pants, ch.shoes, Color(0.45, 0.45, 0.5), sd)
	_pata(partes.pata_d, 1, ch.pants, ch.shoes, Color(0.45, 0.45, 0.5), sd + 1)
	_brazo(partes.brazo_i, -1, remera, remera_oscura, piel, sd)
	_brazo(partes.brazo_d, 1, remera, remera_oscura, piel, sd + 1)
	# el torso (remera): un poco más angosto abajo, dobladillo oscuro y arrugas
	for y in range(10, 20):
		var cintura := 1 if y < 13 else 0
		_caja(c, -7 + cintura, 7 - cintura, y, y, -6, 5, remera.darkened(0.07 * float(19 - y) / 9.0), 0.04, sd)
	_caja(c, -7, 7, 10, 11, -6, 5, remera_oscura, 0.03, sd)
	for y in range(13, 18):
		_p(c, -2, y, 5, remera.darkened(0.14), 0.0)
		_p(c, 3, y, 5, remera.darkened(0.14), 0.0)
	_caja(c, -2, 2, 19, 19, 4, 5, piel, 0.02, sd)     # (el cuello de la remera en V)
	_caja(c, -1, 1, 18, 18, 5, 5, piel, 0.02, sd)
	_caja(c, -3, 3, 20, 20, -3, 3, piel.darkened(0.1), 0.02, sd)   # (el cuello)
	# la cabeza
	_caja(c, -11, 10, 21, 36, -10, 9, piel, 0.035, sd, true)
	# orejas
	for lado: int in [-1, 1]:
		var xo: int = 11 if lado > 0 else -12
		_caja(c, xo, xo, 25, 28, -2, 1, piel.darkened(0.04), 0.02, sd)
		_p(c, xo, 26, 0, piel.darkened(0.2), 0.0)
	# cara: ojos, cejas, nariz, boca y mejillas
	_ojos(c, 9, 28, 3, ojo, Color(1, 1, 1), 3, 4)
	for lado: int in [-1, 1]:
		var xc: int = 3 if lado > 0 else -6
		_caja(c, xc, xc + 2, 33, 33, 9, 9, pelo.darkened(0.1), 0.0)
		_caja(c, xc - 1 if lado < 0 else xc + 1, xc + 1 if lado < 0 else xc + 3, 26, 26, 9, 9, Color(0.97, 0.62, 0.62).lerp(piel, 0.45), 0.0)   # (mejillas)
	_caja(c, -1, 0, 26, 28, 9, 10, piel.darkened(0.14), 0.0)   # nariz
	_caja(c, -2, 1, 23, 23, 9, 9, piel.darkened(0.35), 0.0)    # boca
	_p(c, -3, 24, 9, piel.darkened(0.35), 0.0)
	_p(c, 2, 24, 9, piel.darkened(0.35), 0.0)
	# el pelo
	_caja(c, -12, 11, 36, 37, -11, 10, pelo, 0.05, sd, true)
	_caja(c, -11, 10, 33, 35, 8, 10, pelo, 0.05, sd)                  # (flequillo)
	for x in range(-11, 11):
		if _h(x, 0, 0, sd + 3) < 0.45:
			_borrar(c, x, 33, 9)
			_borrar(c, x, 33, 10)
	_caja(c, -12, -11, 29, 36, -10, 4, pelo, 0.05, sd)                # (patillas)
	_caja(c, 10, 11, 29, 36, -10, 4, pelo, 0.05, sd)
	if larga:
		_caja(c, -12, 11, 14, 37, -12, -9, pelo, 0.05, sd, true)          # (larga, por la espalda)
		_caja(c, -13, -12, 19, 36, -6, 6, pelo, 0.05, sd)
		_caja(c, 12, 13, 19, 36, -6, 6, pelo, 0.05, sd)
		for lado: int in [-1, 1]:   # (los mechones de adelante, con una puntita)
			var xm: int = 10 if lado > 0 else -13
			_caja(c, xm, xm + 2, 22, 33, 6, 8, pelo, 0.05, sd)
		var cola := partes.get("cola", {}) as Dictionary
		partes["cola"] = cola
		_caja(cola, -2, 2, 22, 33, -16, -13, pelo, 0.05, sd, true)
		_caja(cola, -3, 3, 33, 35, -15, -12, ch.accent, 0.03, sd)        # (el hebillo)
	else:
		_caja(c, -11, 10, 24, 36, -12, -10, pelo, 0.05, sd)               # (nuca)
		for gx: int in [-6, -1, 4]:                                       # (mechones de punta)
			_caja(c, gx, gx + 3, 38, 40, -3, 3, pelo, 0.05, sd, true)
			_caja(c, gx + 1, gx + 2, 41, 41, -2, 2, pelo, 0.05, sd)
		_caja(c, -7, 6, 17, 19, -9, -7, remera_oscura, 0.03, sd)          # (la capucha del buzo)


# --- los animalitos ------------------------------------------------------------------------------------------------------------

static func _animal(partes: Dictionary, ch: Dictionary, sd: int) -> void:
	var c: Dictionary = partes.cuerpo
	var pelaje: Color = ch.fur
	var claro: Color = ch.light
	var oscuro: Color = ch.dark
	var ojo := Color(0.06, 0.04, 0.08)
	var rosa := Color(1.0, 0.65, 0.72)
	var id := str(ch.id)
	_pata(partes.pata_i, -1, oscuro, oscuro.lightened(0.05), oscuro.darkened(0.2), sd, true)
	_pata(partes.pata_d, 1, oscuro, oscuro.lightened(0.05), oscuro.darkened(0.2), sd + 1, true)
	_brazo(partes.brazo_i, -1, pelaje, oscuro, pelaje, sd, true)
	_brazo(partes.brazo_d, 1, pelaje, oscuro, pelaje, sd + 1, true)
	# torso con la pancita clara
	for y in range(10, 20):
		_caja(c, -7, 7, y, y, -6, 5, pelaje.darkened(0.06 * float(19 - y) / 9.0), 0.05, sd, y == 10 or y == 19)
	_caja(c, -4, 4, 11, 17, 5, 5, claro, 0.03, sd)
	_caja(c, -3, 3, 20, 20, -3, 3, pelaje, 0.03, sd)
	# la cabeza
	_caja(c, -11, 10, 21, 36, -10, 9, pelaje, 0.05, sd, true)
	_ojos(c, 9, 29, 4, ojo, Color(1, 1, 1), 3, 4)
	for lado: int in [-1, 1]:   # (mejillas más claras)
		var xm: int = 6 if lado > 0 else -10
		_caja(c, xm, xm + 3, 24, 27, 9, 9, claro.lerp(pelaje, 0.35), 0.03, sd)
	match id:
		"perro":
			_caja(c, -4, 3, 24, 29, 10, 13, claro, 0.03, sd, true)              # hocico
			_caja(c, -2, 1, 29, 30, 13, 14, oscuro.darkened(0.5), 0.0)           # nariz
			_caja(c, -1, 0, 23, 24, 12, 13, rosa, 0.0)                           # lengua
			for lado: int in [-1, 1]:
				var xo: int = 11 if lado > 0 else -14
				_caja(c, xo, xo + 2, 23, 36, -3, 4, oscuro, 0.05, sd)           # orejas caídas
			_caja(c, -5, 4, 36, 37, -4, 4, oscuro.lerp(pelaje, 0.5), 0.05, sd)  # mancha en la cabeza
			var cola := {}
			_caja(cola, -1, 1, 11, 20, -10, -8, oscuro, 0.05, sd)
			_caja(cola, -1, 1, 19, 20, -10, -8, claro, 0.05, sd)
			partes["cola"] = cola
		"conejo":
			_caja(c, -1, 0, 28, 29, 9, 10, rosa, 0.0)                            # nariz
			_caja(c, -2, 1, 25, 26, 9, 9, claro, 0.0)                            # dientitos
			_p(c, 0, 25, 9, claro.darkened(0.15), 0.0)
			_p(c, -1, 25, 9, claro.darkened(0.15), 0.0)
			for lado: int in [-1, 1]:
				var xo: int = 4 if lado > 0 else -7
				_caja(c, xo, xo + 3, 37, 47, -2, 1, pelaje, 0.04, sd)           # orejas largas
				_caja(c, xo + 1, xo + 2, 39, 45, 2, 2, rosa, 0.03, sd)
				_caja(c, xo + (1 if lado > 0 else -1), xo + (4 if lado > 0 else 2), 48, 50, -2, 1, pelaje, 0.04, sd)   # (la punta se dobla un poco)
			var cola := {}
			_caja(cola, -3, 3, 9, 15, -13, -8, claro, 0.06, sd, true)
			partes["cola"] = cola
		_:   # gato
			_caja(c, -3, 2, 27, 30, 10, 10, claro, 0.03, sd)                     # hocico claro
			_caja(c, -1, 0, 30, 30, 10, 10, rosa, 0.0)                           # nariz
			for lado: int in [-1, 1]:
				var xo: int = 4 if lado > 0 else -9
				for k in 5:   # (orejas en punta, escalonadas)
					var w: int = [5, 5, 3, 3, 1][k]
					var xx: int = xo + [0, 0, 1, 1, 2][k]
					_caja(c, xx, xx + w - 1, 37 + k, 37 + k, -2, 1, pelaje, 0.04, sd)
				_caja(c, xo + 1, xo + 3, 37, 39, 2, 2, rosa, 0.0)
				for r in 2:   # (bigotes)
					for k in 5:
						var xb: int = (11 + k) if lado > 0 else (-12 - k)
						_p(c, xb, 27 + r, 9, claro, 0.0)
			var cola := {}
			_caja(cola, -1, 1, 11, 13, -16, -8, pelaje, 0.05, sd)
			_caja(cola, -1, 1, 11, 23, -17, -15, pelaje, 0.05, sd)
			_caja(cola, -1, 1, 20, 23, -17, -15, oscuro, 0.05, sd)
			partes["cola"] = cola
