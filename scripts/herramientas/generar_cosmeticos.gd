extends RefCounted
## Genera el diseño de minibloques de los trece cosméticos (gorros y prendas) y los guarda en data/modelos/cosmeticos.jsonl (el formato del editor de modelos: se pueden retocar
## ahí). Mismas medidas que los personajes (generar_personajes.gd): minibloques de 0,02 en una caja de 48 x 64 x 48 con el origen en los pies (24, 0, 24). La cabeza ocupa
## x de -11 a 10, y de 21 a 36 y z de -10 a 9; el torso x de -7 a 7, y de 10 a 19 y z de -6 a 5. Una prenda puede llevar partes `brazo_i` y `brazo_d` (mangas, hombreras, brazaletes):
## el personaje las cuelga de sus brazos y se mueven con ellos (ver `Characters._dress`).
## Uso: GAME_SANDBOX=1 godot --headless --path . -s tests/sondas/generar_cosmeticos.gd

const ModelLib := preload("res://scripts/personajes/model_lib.gd")
const Pers := preload("res://scripts/herramientas/generar_personajes.gd")
const Cosmetics := preload("res://scripts/personajes/cosmetics.gd")

const VOX := 0.02
const SIZE := [48, 64, 48]
const ORIGEN := Vector3i(24, 0, 24)
const PIVOTE_BRAZO := {"brazo_i": Vector3(-10, 19, 0), "brazo_d": Vector3(10, 19, 0)}


static func todos() -> Array:
	var out: Array = []
	for c in Cosmetics.ALL:
		out.append(registro(c))
	return out


static func guardar() -> void:
	for rec in todos():
		ModelLib.save_record(rec, "cosmeticos.jsonl")


static func registro(c: Dictionary) -> Dictionary:
	var partes := {"principal": {}, "brazo_i": {}, "brazo_d": {}}
	var sd := str(c.id).hash() % 1000
	var m: Dictionary = partes.principal
	match str(c.id):
		"gorra": _gorra(m, sd)
		"gorro_lana": _gorro_lana(m, sd)
		"cinta": _cinta(m, sd)
		"copa": _copa(m, sd)
		"brujo": _brujo(m, sd)
		"corona": _corona(m, sd)
		"halo": _halo(m, sd)
		"bufanda": _bufanda(m, sd)
		"remera": _remera(partes, sd)
		"mochila": _mochila(m, sd)
		"capa": _capa(m, sd)
		"chaleco": _chaleco(m, sd)
		"armadura": _armadura(partes, sd)
	var palette: Array = []
	var lista: Array = []
	for n in partes:
		var mapa: Dictionary = partes[n]
		if mapa.is_empty():
			continue
		var pv = PIVOTE_BRAZO.get(n, null)
		lista.append({"name": str(c.slot) if n == "principal" else n,
				"pivot": null if pv == null else [pv.x + ORIGEN.x, pv.y, pv.z + ORIGEN.z], "voxels": ModelLib.pack_voxels(mapa, palette)})
	return {"id": c.id, "kind": "cosmetico", "name": c.name, "slot": c.slot, "rarity": c.rarity, "voxel": VOX, "size": SIZE,
			"origin": [ORIGEN.x, ORIGEN.y, ORIGEN.z], "palette": palette, "parts": lista}


# --- primitivas -----------------------------------------------------------------------------------------------------------------

## Un anillo (o disco, con `r_in` = 0) horizontal de minibloques centrado en (cx, cz) entre los pisos y0 e y1 (elipse de semiejes rx y rz).
static func _anillo(m: Dictionary, cx: float, cz: float, rx: float, rz: float, y0: int, y1: int, col: Color, r_in := 0.0, ruido := 0.04, sd := 0) -> void:
	for x: int in range(int(floorf(cx - rx)) - 1, int(ceilf(cx + rx)) + 2):
		for z: int in range(int(floorf(cz - rz)) - 1, int(ceilf(cz + rz)) + 2):
			var d := sqrt(pow((float(x) + 0.5 - cx) / rx, 2.0) + pow((float(z) + 0.5 - cz) / rz, 2.0))
			if d > 1.0 or d < r_in:
				continue
			for y: int in range(y0, y1 + 1):
				Pers._p(m, x, y, z, col, ruido, sd)


static func _p(m: Dictionary, x: int, y: int, z: int, col: Color, ruido := 0.0, sd := 0) -> void:
	Pers._p(m, x, y, z, col, ruido, sd)


static func _caja(m: Dictionary, x0: int, x1: int, y0: int, y1: int, z0: int, z1: int, col: Color, ruido := 0.04, sd := 0, redondea := false) -> void:
	Pers._caja(m, x0, x1, y0, y1, z0, z1, col, ruido, sd, redondea)


# --- gorros ---------------------------------------------------------------------------------------------------------------------

static func _gorra(m: Dictionary, sd: int) -> void:
	var rojo := Color(0.86, 0.15, 0.2)
	_anillo(m, 0, 0, 12.9, 12.2, 36, 37, rojo.darkened(0.12), 0.0, 0.03, sd)          # la base, justo sobre el pelo
	for y in range(38, 42):                                                           # la cúpula, cada piso un poco más chico
		var k := float(y - 37)
		_anillo(m, 0, 0, 12.7 - k * 0.9, 12.0 - k * 0.9, y, y, rojo.lightened(0.02 * k), 0.0, 0.03, sd)
	_anillo(m, 0, 0, 7.0, 6.5, 42, 42, rojo.lightened(0.08), 0.0, 0.03, sd)
	_caja(m, -1, 0, 43, 43, -1, 0, Color(1.0, 0.95, 0.9), 0.0)                        # botón
	for k in 4:   # costuras desde el botón
		var ang := float(k) / 4.0 * TAU + 0.4
		for r in range(2, 8):
			var y := 42 - int(float(r) / 2.2)
			_p(m, int(cos(ang) * float(r)), y, int(sin(ang) * float(r)), rojo.darkened(0.25))
	_caja(m, -3, 2, 38, 40, 10, 10, Color(1.0, 0.95, 0.85), 0.0)                      # el escudito de adelante
	_caja(m, -2, 1, 39, 39, 10, 10, rojo.darkened(0.1), 0.0)
	var visera := Color(0.65, 0.1, 0.15)
	for z in range(11, 18):                                                           # la visera, curvada hacia abajo en las puntas
		var ancho := 8 - (z - 11) / 3
		for x in range(-ancho, ancho):
			var y := 37 if z < 15 else 36
			_p(m, x, y, z, visera.lightened(0.04 * float(18 - z) / 7.0), 0.03, sd)
	_caja(m, -8, 7, 36, 36, 11, 12, visera.darkened(0.15), 0.0)                       # (el borde de abajo)
	_caja(m, -3, 2, 36, 36, -12, -11, rojo.darkened(0.2), 0.0)                        # la tira de atrás


static func _gorro_lana(m: Dictionary, sd: int) -> void:
	var azul := Color(0.25, 0.45, 0.9)
	var blanco := Color(0.95, 0.95, 1.0)
	for y in range(36, 40):   # el puño de abajo, acanalado
		_anillo(m, 0, 0, 13.3, 12.7, y, y, blanco, 0.0, 0.03, sd)
	for x in range(-12, 12):
		for y in range(36, 40):
			if x % 2 == 0:
				for z in [-12, -11, 11, 12]:
					if m.has(Vector3i(x + ORIGEN.x, y, z + ORIGEN.z)):
						m[Vector3i(x + ORIGEN.x, y, z + ORIGEN.z)] = (m[Vector3i(x + ORIGEN.x, y, z + ORIGEN.z)] as Color).darkened(0.1)
	for y in range(40, 47):   # el cuerpo del gorro: se va cerrando, con hileras de tejido
		var k := float(y - 40)
		var col := azul.lightened(0.03 * (k - 3.0)) if y % 2 == 0 else azul.darkened(0.06)
		_anillo(m, 0, 0, 12.6 - k * 1.1, 12.0 - k * 1.05, y, y, col, 0.0, 0.04, sd)
	_anillo(m, 0, 0, 4.0, 4.0, 47, 47, azul, 0.0, 0.04, sd)
	_anillo(m, 0, 0, 3.6, 3.6, 48, 53, blanco, 0.0, 0.07, sd)                          # el pompón
	_anillo(m, 0, 0, 2.2, 2.2, 54, 54, blanco, 0.0, 0.07, sd)
	_anillo(m, 0, 0, 2.2, 2.2, 47, 47, blanco.darkened(0.08), 0.0, 0.05, sd)


static func _cinta(m: Dictionary, sd: int) -> void:
	var rosa := Color(1.0, 0.45, 0.7)
	_anillo(m, 0, 0, 12.9, 12.2, 34, 35, rosa, 0.0, 0.03, sd)
	_anillo(m, 0, 0, 12.9, 12.2, 34, 34, rosa.darkened(0.12), 0.0, 0.03, sd)
	var mono := Color(1.0, 0.6, 0.8)
	_caja(m, -9, -6, 33, 38, 12, 13, mono, 0.04, sd, true)
	_caja(m, -4, -1, 33, 38, 12, 13, mono, 0.04, sd, true)
	_caja(m, -6, -4, 34, 37, 12, 14, rosa.darkened(0.2), 0.03, sd)
	for y in range(35, 38):   # los centros de los lazos, más oscuros
		_p(m, -8, y, 13, mono.darkened(0.15))
		_p(m, -2, y, 13, mono.darkened(0.15))
	_caja(m, -7, -6, 30, 33, 12, 12, mono.darkened(0.1), 0.03, sd)                     # las puntas que cuelgan
	_caja(m, -4, -3, 30, 32, 12, 12, mono.darkened(0.1), 0.03, sd)


static func _copa(m: Dictionary, sd: int) -> void:
	var negro := Color(0.07, 0.07, 0.09)
	_anillo(m, 0, 0, 14.0, 13.0, 37, 37, negro.lightened(0.04), 0.0, 0.02, sd)     # el ala
	_anillo(m, 0, 0, 14.0, 13.0, 38, 38, negro, 0.0, 0.02, sd)
	_anillo(m, 0, 0, 9.2, 8.5, 39, 53, negro, 0.0, 0.025, sd)                       # la copa
	_anillo(m, 0, 0, 9.5, 8.8, 40, 43, Color(0.72, 0.1, 0.16), 0.0, 0.03, sd)       # la cinta roja
	_anillo(m, 0, 0, 9.6, 8.9, 42, 42, Color(0.55, 0.06, 0.12), 0.0, 0.02, sd)
	_caja(m, -2, 1, 40, 43, 9, 9, Color(1.0, 0.85, 0.3), 0.02, sd)                  # la hebilla dorada
	_caja(m, -1, 0, 41, 42, 9, 9, Color(0.72, 0.1, 0.16), 0.0)
	_anillo(m, 0, 0, 9.2, 8.5, 54, 54, negro.lightened(0.12), 0.0, 0.02, sd)        # la tapa, un poco más clara
	for y in range(44, 54):   # el brillo del satén, una veta vertical
		_p(m, 5, y, 6, negro.lightened(0.22))
		_p(m, 6, y, 5, negro.lightened(0.18))


static func _brujo(m: Dictionary, sd: int) -> void:
	var violeta := Color(0.3, 0.14, 0.5)
	_anillo(m, 0, 0, 15.0, 14.0, 37, 37, violeta.darkened(0.35), 0.0, 0.03, sd)    # el ala ancha, un poco caída
	_anillo(m, 0, 0, 14.0, 13.0, 38, 38, violeta.darkened(0.22), 0.0, 0.03, sd)
	for y in range(39, 62):   # el cono, que se afina y se dobla hacia un costado
		var k := float(y - 39)
		var r: float = maxf(10.5 - k * 0.45, 1.6)
		var doblez: float = maxf(k - 11.0, 0.0) * 0.25
		_anillo(m, doblez, 0, r, r * 0.95, y, y, violeta.lightened(0.02 * (k - 8.0)), 0.0, 0.04, sd)
	_anillo(m, 0, 0, 11.0, 10.3, 39, 42, Color(0.95, 0.8, 0.25), 0.0, 0.03, sd)     # la banda dorada
	_caja(m, -2, 1, 39, 42, 10, 11, Color(1.0, 0.9, 0.4), 0.02, sd)                  # la hebilla
	_caja(m, -1, 0, 40, 41, 11, 11, violeta.darkened(0.3), 0.0)
	for e in [Vector3i(6, 47, 4), Vector3i(-7, 51, -2), Vector3i(1, 55, 6), Vector3i(-3, 45, -7), Vector3i(7, 52, -3)]:   # estrellitas
		_p(m, e.x, e.y, e.z, Color(1.0, 0.92, 0.45))
		_p(m, e.x + 1, e.y, e.z, Color(1.0, 0.92, 0.45))
		_p(m, e.x, e.y + 1, e.z, Color(1.0, 0.92, 0.45))
	_caja(m, 2, 3, 62, 63, -1, 0, Color(0.95, 0.8, 0.25), 0.02, sd)                  # la puntita dorada


static func _corona(m: Dictionary, sd: int) -> void:
	var oro := Color(1.0, 0.82, 0.25)
	_anillo(m, 0, 0, 12.9, 12.2, 37, 39, oro, 0.0, 0.03, sd)
	_anillo(m, 0, 0, 12.9, 12.2, 37, 37, oro.darkened(0.15), 0.0, 0.03, sd)
	_anillo(m, 0, 0, 12.9, 12.2, 39, 39, oro.lightened(0.18), 0.0, 0.03, sd)
	for k in 8:   # las ocho puntas, cada una con su bolita
		var ang := float(k) / 8.0 * TAU
		var x := int(round(cos(ang) * 11.4))
		var z := int(round(sin(ang) * 11.0))
		_caja(m, x - 1, x, 40, 43, z - 1, z, oro.lightened(0.05), 0.03, sd)
		_caja(m, x - 1, x, 44, 45, z - 1, z, Color(1.0, 0.92, 0.5), 0.03, sd)
	_caja(m, -2, 1, 37, 39, 12, 13, Color(0.9, 0.2, 0.35), 0.03, sd)               # la joya de adelante
	_p(m, -1, 39, 13, Color(1.0, 0.7, 0.75))
	for x: int in [-9, -5, 4, 8]:   # joyitas azules
		_caja(m, x, x + 1, 38, 38, 12, 13, Color(0.3, 0.55, 0.95), 0.0)


static func _halo(m: Dictionary, sd: int) -> void:
	var oro := Color(1.0, 0.92, 0.45)
	_anillo(m, 0, 0, 12.0, 11.0, 46, 47, oro, 0.62, 0.04, sd)                         # un aro flotando sobre la cabeza
	_anillo(m, 0, 0, 12.0, 11.0, 48, 48, oro.lightened(0.25), 0.62, 0.03, sd)
	_anillo(m, 0, 0, 12.0, 11.0, 45, 45, oro.darkened(0.12), 0.62, 0.03, sd)


# --- prendas --------------------------------------------------------------------------------------------------------------------

static func _bufanda(m: Dictionary, sd: int) -> void:
	var roja := Color(0.9, 0.25, 0.25)
	var blanca := Color(0.95, 0.9, 0.9)
	for y in range(18, 21):   # la vuelta al cuello
		for x in range(-8, 9):
			for z in range(-7, 7):
				var ex: float = absf(float(x) + 0.5) / 8.5
				var ez: float = (float(z) + 0.5) / 7.0
				var d := ex * ex + ez * ez
				if d > 1.0 or d < 0.28:
					continue
				var franja := ((x + z + 40) / 3) % 4 == 0
				_p(m, x, y, z, blanca if franja else roja, 0.04, sd)
	for y in range(9, 19):   # la punta larga, que cuelga por delante a la izquierda
		var franja := (y / 2) % 4 == 0
		_caja(m, -7, -3, y, y, 6, 7, blanca if franja else roja, 0.04, sd)
	for x in range(-7, -2):   # el flequito de abajo
		if x % 2 == 0:
			_p(m, x, 8, 6, roja.darkened(0.1))
			_p(m, x, 7, 6, roja.darkened(0.1))
		_p(m, x, 8, 7, roja.darkened(0.1))
	_caja(m, 3, 6, 12, 18, 6, 6, roja.darkened(0.05), 0.04, sd)                         # la otra punta, más corta, a la derecha
	for x in range(3, 7):
		if x % 2 == 1:
			_p(m, x, 11, 6, roja.darkened(0.1))


static func _remera(partes: Dictionary, sd: int) -> void:
	var m: Dictionary = partes.principal
	var verde := Color(0.25, 0.75, 0.4)
	for y in range(10, 20):
		_caja(m, -8, 8, y, y, -7, 6, verde.darkened(0.05 * float(19 - y) / 9.0), 0.04, sd, y == 10 or y == 19)
	_caja(m, -8, 8, 10, 10, -7, 6, verde.darkened(0.14), 0.03, sd)                      # el dobladillo
	for x in range(-2, 3):   # el cuello redondo, que deja ver la piel
		for z in range(4, 7):
			m.erase(Vector3i(x + ORIGEN.x, 19, z + ORIGEN.z))
	for x in range(-3, 4):
		_p(m, x, 19, 6, verde.darkened(0.2))
	_caja(m, -3, 2, 13, 17, 6, 6, Color(1.0, 0.95, 0.6), 0.02, sd)                      # la estampa: una estrella
	_caja(m, -1, 0, 12, 18, 6, 6, Color(1.0, 0.95, 0.6), 0.02, sd)
	_caja(m, -2, 1, 14, 16, 6, 6, Color(1.0, 0.8, 0.3), 0.0)
	for lado: int in [-1, 1]:
		var mg: Dictionary = partes["brazo_i" if lado < 0 else "brazo_d"]
		var x0: int = 8 if lado > 0 else -12
		_caja(mg, x0, x0 + 4, 13, 19, -3, 2, verde, 0.04, sd, true)                     # la manga corta
		_caja(mg, x0, x0 + 4, 13, 13, -3, 2, verde.darkened(0.14), 0.03, sd)


static func _mochila(m: Dictionary, sd: int) -> void:
	var cuero := Color(0.55, 0.35, 0.18)
	var oscuro := Color(0.4, 0.24, 0.12)
	_caja(m, -6, 5, 8, 19, -14, -7, cuero, 0.05, sd, true)                               # el cuerpo
	_caja(m, -6, 5, 15, 20, -15, -7, oscuro, 0.04, sd, true)                             # la solapa
	_caja(m, -2, 1, 14, 17, -15, -15, Color(1.0, 0.85, 0.3), 0.02, sd)                  # la hebilla
	_caja(m, -4, 3, 9, 13, -15, -15, cuero.lightened(0.08), 0.05, sd)                   # el bolsillo de abajo
	_caja(m, -4, 3, 13, 13, -15, -15, oscuro, 0.03, sd)
	for lado: int in [-1, 1]:   # las tiras: por arriba del hombro y por delante del pecho
		var x0: int = 3 if lado > 0 else -5
		_caja(m, x0, x0 + 1, 20, 20, -7, 6, oscuro, 0.04, sd)
		_caja(m, x0, x0 + 1, 11, 19, 6, 6, oscuro, 0.04, sd)
		_caja(m, x0, x0 + 1, 12, 19, -7, -7, oscuro, 0.04, sd)
		_caja(m, x0, x0 + 1, 11, 12, 6, 6, Color(1.0, 0.85, 0.3), 0.02, sd)             # el broche


static func _capa(m: Dictionary, sd: int) -> void:
	var roja := Color(0.8, 0.12, 0.2)
	var oro := Color(1.0, 0.85, 0.3)
	for y in range(2, 20):   # el paño de atrás, con el borde de abajo ondulado
		_caja(m, -9, 8, y, y, -11, -8, roja.darkened(0.2 * float(19 - y) / 17.0), 0.05, sd)
	for x in range(-9, 9):   # (la ondulación: algunos minibloques de abajo faltan)
		if _hh(x, sd) < 0.5:
			for z in range(-11, -7):
				m.erase(Vector3i(x + ORIGEN.x, 2, z + ORIGEN.z))
				m.erase(Vector3i(x + ORIGEN.x, 3, z + ORIGEN.z))
	_caja(m, -9, 8, 2, 3, -11, -8, roja.darkened(0.25), 0.04, sd)                         # el borde de abajo, más oscuro
	for x in range(-9, 9):
		if _hh(x, sd + 5) < 0.55:
			for z in range(-11, -7):
				m.erase(Vector3i(x + ORIGEN.x, 2, z + ORIGEN.z))
	for y in range(2, 20):   # el ribete dorado a los costados
		_caja(m, -9, -9, y, y, -11, -8, oro.darkened(0.1), 0.03, sd)
		_caja(m, 8, 8, y, y, -11, -8, oro.darkened(0.1), 0.03, sd)
	# el cuello con la piel blanca, sobre los hombros
	for y in range(18, 21):
		for x in range(-9, 10):
			for z in range(-8, 8):
				var ex: float = (float(x) + 0.5) / 9.5
				var ez: float = (float(z) + 0.5) / 8.0
				var d := ex * ex + ez * ez
				if d > 1.0 or d < 0.3:
					continue
				_p(m, x, y, z, Color(0.95, 0.93, 0.9) if _hh(x * 7 + z, sd + y) > 0.35 else Color(0.82, 0.8, 0.78), 0.03, sd)
	_caja(m, -2, 1, 16, 18, 7, 7, oro, 0.02, sd, true)                                    # el broche
	_p(m, -1, 17, 8, Color(0.9, 0.2, 0.35))
	_p(m, 0, 17, 8, Color(0.9, 0.2, 0.35))


static func _chaleco(m: Dictionary, sd: int) -> void:
	var oro := Color(1.0, 0.8, 0.25)
	var cafe := Color(0.5, 0.35, 0.1)
	for y in range(10, 20):
		_caja(m, -8, 8, y, y, -7, 6, oro.darkened(0.08 * float(19 - y) / 9.0), 0.04, sd, y == 10 or y == 19)
	for z in range(5, 8):   # la abertura de adelante deja ver la remera
		for y in range(10, 20):
			m.erase(Vector3i(0 + ORIGEN.x, y, z + ORIGEN.z))
			m.erase(Vector3i(-1 + ORIGEN.x, y, z + ORIGEN.z))
	for y in range(10, 20):   # el ribete de la abertura y del borde de abajo
		_p(m, -2, y, 6, cafe)
		_p(m, 1, y, 6, cafe)
	_caja(m, -8, 8, 10, 10, -7, 6, cafe, 0.03, sd)
	for x in range(-3, 3):   # las solapas en V arriba
		_p(m, x, 19, 6, cafe)
		_p(m, x, 19, 7, cafe.lightened(0.1))
	for k in 3:   # los botones blancos
		_caja(m, 2, 3, 12 + k * 2, 12 + k * 2, 6, 7, Color(0.95, 0.95, 0.9), 0.0)
	_caja(m, -7, -4, 14, 16, 6, 6, oro.darkened(0.2), 0.03, sd)                          # el bolsillo
	_caja(m, -7, -4, 16, 16, 6, 6, cafe, 0.0)
	_caja(m, 0, 0, 10, 19, -7, -7, cafe, 0.03, sd)                                        # la costura de la espalda


static func _armadura(partes: Dictionary, sd: int) -> void:
	var m: Dictionary = partes.principal
	var negro := Color(0.09, 0.07, 0.14)
	var placa := Color(0.14, 0.1, 0.22)
	var magenta := Color(0.95, 0.3, 1.0)
	for y in range(10, 20):
		_caja(m, -8, 8, y, y, -7, 6, negro.lerp(placa, 0.5 + 0.5 * sin(float(y) * 0.9)), 0.03, sd, y == 19)
	for y in [13, 16]:   # las placas se separan con una línea más clara
		for x in range(-8, 9):
			_p(m, x, y, 6, placa.lightened(0.18), 0.0)
			_p(m, x, y, -7, placa.lightened(0.18), 0.0)
	for z in range(-7, 7):
		_p(m, -8, 14, z, placa.lightened(0.18))
		_p(m, 8, 14, z, placa.lightened(0.18))
	_caja(m, -2, 1, 13, 16, 6, 7, magenta, 0.02, sd)                                      # el núcleo brillante
	_caja(m, -1, 0, 14, 15, 7, 7, Color(1.0, 0.8, 1.0), 0.0)
	for k in 6:   # las venas que salen del núcleo
		var ang := float(k) / 6.0 * TAU + 0.5
		for r in range(3, 6):
			_p(m, int(cos(ang) * float(r)), 14 + int(sin(ang) * float(r) * 0.8), 6, magenta.darkened(0.3))
	_caja(m, -8, 8, 10, 11, -7, 6, placa, 0.03, sd)                                       # el cinturón con su línea magenta
	_caja(m, -8, 8, 11, 11, -7, 6, magenta.darkened(0.15), 0.02, sd)
	_caja(m, -2, 1, 10, 11, 6, 7, negro, 0.0)
	_caja(m, -1, 0, 10, 10, 7, 7, magenta, 0.0)
	for lado: int in [-1, 1]:
		var mg: Dictionary = partes["brazo_i" if lado < 0 else "brazo_d"]
		var x0: int = 8 if lado > 0 else -13
		_caja(mg, x0, x0 + 5, 17, 20, -4, 3, placa, 0.03, sd, true)                       # la hombrera
		_caja(mg, x0 + 1, x0 + 4, 21, 21, -3, 2, placa.lightened(0.05), 0.03, sd)
		_caja(mg, x0 + 2, x0 + 3, 22, 24, -1, 0, magenta, 0.0)                            # la púa
		_caja(mg, x0 + 1, x0 + 4, 18, 18, -4, 3, magenta.darkened(0.25), 0.0)
		var xb: int = 8 if lado > 0 else -11
		_caja(mg, xb - 1, xb + 4, 8, 12, -3, 2, negro, 0.03, sd, true)                    # el brazalete
		_caja(mg, xb - 1, xb + 4, 12, 12, -3, 2, magenta.darkened(0.2), 0.0)


static func _hh(x: int, k: int) -> float:
	return Pers._h(x, 3, 5, k)
