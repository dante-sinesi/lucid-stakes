extends RefCounted
## Las salas de la biblioteca (data/salas.rooms, ver docs/torres_con_biblioteca.md) para armar las torres del juego: se leen una vez, se califican por dificultad
## y se eligen para una etapa. El generador (rooms.gd, place_library_room) las gira, las pone en la torre y las vuelve a comprobar con el camino que ya traen.

const RoomLib := preload("res://scripts/room_lib.gd")
const RoomPack := preload("res://scripts/room_pack.gd")
const Gen := preload("res://scripts/tower_gen.gd")

const PATH := "res://data/salas.rooms"

static var _mutex := Mutex.new()
static var _rooms: Array = []
static var _loaded := false
static var override_path := ""   # (pruebas) otra biblioteca


## Todas las salas con su calificación: {room, rating, kinds (caracteres de bloque que usa), unlock (dificultad desde la que puede salir)}.
static func all() -> Array:
	_mutex.lock()
	if not _loaded:
		_loaded = true
		var path := override_path if override_path != "" else PATH
		for r in RoomPack.load_library(path):
			if not str(r.opt.get("proof", "")) == "exacta" or r.path.is_empty():
				continue
			var kinds := {}
			for c in r.cols:
				for ch in String(r.cols[c]):
					if ch != RoomLib.GAP:
						kinds[ch] = true
			var unlock := 0.0
			for ch in kinds:
				unlock = maxf(unlock, _unlock_of(ch))
			_rooms.append({"room": r, "rating": rating(r), "kinds": kinds, "unlock": unlock})
	var out := _rooms
	_mutex.unlock()
	return out


## Los bloques especiales de las salas de la biblioteca están todos disponibles desde la etapa 6 (de 15); el hielo, el pesado y el agrietado, que son más sencillos, salen antes (escalera de tower_gen.gd).
const SPECIALS_FROM := 5.0 / 14.0
## La última etapa sólo usa salas con esta dificultad (agarres sobre pasos) o más.
const FINAL_MIN_DIFF := 0.5


static func _unlock_of(ch: String) -> float:
	return minf(_ladder_of(ch), SPECIALS_FROM)


static func _ladder_of(ch: String) -> float:
	match ch:
		"i":
			return Gen.ICE_FROM
		"h":
			return Gen.HEAVY_FROM
		"c":
			return Gen.CRACKED_FROM
		"t":
			return Gen.TRAP_FROM
		"s":
			return Gen.SPIKES_FROM
		"b":
			return Gen.BOMB_FROM
		"k":
			return Gen.CATAPULT_FROM if Gen.CATAPULTS_IN_TOWERS else 2.0
	return 0.0


## Qué tan difícil es una sala, de 0 a 1: bloques movidos por agarres (lo que pide el camino más corto), dificultad (agarres sobre pasos) y largo del camino.
static func rating(r: Dictionary) -> float:
	var o: Dictionary = r.opt
	var grabs := float(o.get("grabs", 0.0))
	var diff := float(o.get("diff", 0.0))
	var moves := float(o.get("moves", 0.0))
	return clampf((grabs - 2.0) / 10.0, 0.0, 1.0) * 0.45 + clampf(diff / 0.55, 0.0, 1.0) * 0.35 + clampf((moves - 8.0) / 30.0, 0.0, 1.0) * 0.2


## La calificación que se busca para una sala de una torre de dificultad `d` (0..1), en la sala `index` de `total`: sube con la etapa y, dentro de la torre, de a poco hacia arriba.
static func target(d: float, index: int, total: int) -> float:
	var within := (float(index) / float(maxi(total - 1, 1)) - 0.5) * 0.12
	return clampf(0.1 + 0.72 * d + within, 0.05, 0.95)


## Hasta `count` salas para esa dificultad, de la más a la menos conveniente: desbloqueadas a esa dificultad, que entran en `max_h` pisos, no repetidas (`used`: ids), cerca de la calificación buscada (con algo de azar).
static func pick(rng: RandomNumberGenerator, d: float, index: int, total: int, max_h: int, used: Dictionary, count := 10, shapes_avoid: Array = []) -> Array:
	var want := target(d, index, total)
	var scored: Array = []
	for e in all():
		var r: Dictionary = e.room
		if float(e.unlock) > d + 0.0001 or int(r.h) > max_h or used.has(r.id):
			continue
		if d >= 0.999 and float(r.opt.get("diff", 0.0)) < FINAL_MIN_DIFF - 0.0001:
			continue
		var s: float = absf(float(e.rating) - want) + rng.randf() * 0.12
		if shapes_avoid.has(r.shape):
			s += 0.05
		scored.append([s, e])
	scored.sort_custom(func(a, b): return a[0] < b[0])
	var per_shape := maxi(count / RoomLib.SHAPES.size(), 1)   # (de cada forma las mejores: las grandes (L, U, 3x8) casi nunca entran en el lugar donde cae la llegada)
	var taken := {}
	var chosen: Array = []
	for sc in scored:
		var sh: String = sc[1].room.shape
		if int(taken.get(sh, 0)) < per_shape:
			taken[sh] = int(taken.get(sh, 0)) + 1
			chosen.append(sc)
	var out: Array = []
	for sc in chosen:
		out.append(sc[1])
	return out
