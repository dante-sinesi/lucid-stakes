extends SceneTree
## Resumen de una biblioteca por forma, altura y tipo de bloque (cantidad, pasos, empujes, dificultad) y, si se pide, un recorte curado para que viaje con el juego: todas las salas de la biblioteca
## actual más, de las nuevas, unas cuantas por cada (forma, altura, calificación) priorizando familias distintas y las de dificultad alta (las que usa la última etapa).
## Uso: GAME_SANDBOX=1 godot --headless --path . -s tests/resumen_biblioteca.gd -- GRANDE.rooms [ACTUAL.rooms SALIDA.rooms CUPO=14]
const RoomLib := preload("res://scripts/room_lib.gd")
const Pack := preload("res://scripts/room_pack.gd")
const RoomPool := preload("res://scripts/room_pool.gd")

const NAMES := {"i": "hielo", "h": "pesado", "c": "agrietado", "s": "pinchos", "b": "bomba", "k": "catapulta", "t": "trampa"}


func _init() -> void:
	var args := OS.get_cmdline_user_args()
	var rooms: Array = Pack.load_library(args[0])
	print("salas: %d" % rooms.size())
	if OS.get_environment("SOLO_RECORTE") != "" and args.size() >= 3:   # (sin las tablas: sólo el recorte)
		_curate(rooms, args[1], args[2], int(args[3]) if args.size() > 3 else 14)
		quit(0)
		return
	_table("FORMA", rooms, func(r): return str(r.shape), ["3x3", "3x5", "3x8", "L", "U"])
	var hs: Array = []
	for h in range(5, 21):
		hs.append(str(h))
	_table("ALTURA (pisos)", rooms, func(r): return str(r.h), hs)
	var kinds_list: Array = ["ninguno"] + NAMES.keys()
	_table_kinds(rooms)
	_histogram(rooms)
	if args.size() >= 3:
		_curate(rooms, args[1], args[2], int(args[3]) if args.size() > 3 else 14)
	quit(0)


func _stats(list: Array) -> String:
	if list.is_empty():
		return "-"
	var moves := 0.0
	var grabs := 0.0
	var diff := 0.0
	var rating := 0.0
	var reach := 0.0
	var hi := 0
	for r in list:
		moves += float(r.opt.get("moves", 0))
		grabs += float(r.opt.get("grabs", 0))
		diff += float(r.opt.get("diff", 0.0))
		rating += RoomPool.rating(r)
		reach += float(r.opt.get("reach", 0.0))
		if float(r.opt.get("diff", 0.0)) >= RoomPool.FINAL_MIN_DIFF:
			hi += 1
	var n := float(list.size())
	return "%6d | pasos %5.1f | empujes %4.1f | dificultad %4.1f %% | calificación %2.0f %% | alcance %2.0f %% | con dif ≥ 50 %%: %d" % [list.size(), moves / n, grabs / n, 100.0 * diff / n, 100.0 * rating / n, 100.0 * reach / n, hi]


func _table(title: String, rooms: Array, key: Callable, order: Array) -> void:
	print("\n== por %s" % title)
	var groups := {}
	for r in rooms:
		var k: String = key.call(r)
		if not groups.has(k):
			groups[k] = []
		groups[k].append(r)
	for k in order:
		if groups.has(k):
			print("%-5s %s" % [k, _stats(groups[k])])


func _kinds_of(r: Dictionary) -> Array:
	var seen := {}
	for c in r.cols:
		for ch in String(r.cols[c]):
			if NAMES.has(ch):
				seen[ch] = true
	return seen.keys()


func _table_kinds(rooms: Array) -> void:
	print("\n== por bloque especial (una sala cuenta en cada tipo que usa)")
	var groups := {"ninguno": []}
	for k in NAMES:
		groups[k] = []
	var by_count := {}
	for r in rooms:
		var ks := _kinds_of(r)
		if ks.is_empty():
			groups["ninguno"].append(r)
		for k in ks:
			groups[k].append(r)
		by_count[ks.size()] = int(by_count.get(ks.size(), 0)) + 1
	print("%-10s %s" % ["ninguno", _stats(groups["ninguno"])])
	for k in NAMES:
		print("%-10s %s" % [NAMES[k], _stats(groups[k])])
	print("cantidad de tipos especiales por sala: %s" % str(by_count))


func _histogram(rooms: Array) -> void:
	print("\n== calificación de las salas (la que usa el generador de torres: 0 fácil, 100 difícil)")
	var b := {}
	for r in rooms:
		var k := mini(int(RoomPool.rating(r) * 10.0), 9)
		b[k] = int(b.get(k, 0)) + 1
	for k in range(0, 10):
		print("%2d-%3d %%: %d" % [k * 10, k * 10 + 10, int(b.get(k, 0))])


## Todas las de la biblioteca actual y, de las nuevas, `quota` por celda (forma, altura, calificación de a 5 %), una por familia; el doble de cupo para las de dificultad alta. Las L y las U nuevas no entran (hoy no se usan).
func _curate(rooms: Array, current_path: String, out_path: String, quota: int) -> void:
	var current: Array = Pack.load_library(current_path)
	var keep := {}
	var out: Array = []
	for r in current:
		keep[r.id] = true
		out.append(r)
	var cells := {}
	for r in rooms:
		if keep.has(r.id) or r.shape == "L" or r.shape == "U":
			continue
		var cell := "%s|%d|%d" % [r.shape, int(r.h), int(RoomPool.rating(r) * 20.0)]
		if not cells.has(cell):
			cells[cell] = []
		cells[cell].append(r)
	var added := 0
	var fams_seen := {}
	for cell in cells:
		var list: Array = cells[cell]
		list.sort_custom(func(a, b): return float(a.opt.get("diff", 0.0)) > float(b.opt.get("diff", 0.0)))
		var cap := quota * 2 if float(list[0].opt.get("diff", 0.0)) >= RoomPool.FINAL_MIN_DIFF else quota
		var taken := 0
		for r in list:   # (primero una por familia)
			if taken >= cap:
				break
			if fams_seen.has(r.family):
				continue
			fams_seen[r.family] = true
			out.append(r)
			taken += 1
			added += 1
	print("\n== recorte: %d de la biblioteca actual + %d nuevas = %d salas" % [current.size(), added, out.size()])
	print("guardadas en %s: %s" % [out_path, str(Pack.write_library(out, ProjectSettings.globalize_path(out_path), true))])
