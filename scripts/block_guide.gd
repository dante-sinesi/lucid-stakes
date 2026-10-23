extends RefCounted
## Los avisos de bloque nuevo: qué es cada tipo de bloque. Un bloque se descubre la primera vez que el jugador entra a una sala que lo tiene: en ese momento el juego frena
## y el tabernero explica sus características (`say`). Lo descubierto se guarda
## en el perfil (ver profile.gd). (La pantalla "Guía de bloques" del menú se eliminó: sólo quedan estos avisos.)

const Tipos := preload("res://salas_nuevas/tipos.gd")
const Profile := preload("res://scripts/profile.gd")

const K := Tipos.Kind

## id, tipo de bloque (Tipos.Kind), nombre, descripción de la guía y lo que dice el tabernero al descubrirlo.
const ALL: Array[Dictionary] = [
	{"id": "normal", "kind": K.NORMAL, "name": "Bloque corrupto",
		"desc": "Se pisa, se empuja y se tira. Al pisarlo se purifica y da claridad; si encadenas pisadas nuevas, la racha la multiplica.",
		"say": "Mira, soñador: ese bloque violeta está corrupto. Al pisarlo se purifica y te devuelve claridad, y si encadenas pisadas nuevas la racha la multiplica."},
	{"id": "hielo", "kind": K.ICE, "name": "Hielo",
		"desc": "Te hace resbalar hasta que algo te frene, y si no hay nada, hasta el vacío. No se puede agarrar de él para colgarse.",
		"say": "Ese bloque celeste es hielo: te hace resbalar hasta que algo te frene. Y ojo, si no hay nada que te frene, te lleva hasta el vacío."},
	{"id": "pesado", "kind": K.HEAVY, "name": "Bloque pesado",
		"desc": "De hierro: no se empuja ni se tira, pero se trepa.",
		"say": "El hierro pesa demasiado hasta para la pesadilla: no se empuja ni se tira. Eso sí, se puede trepar."},
	{"id": "agrietado", "kind": K.CRACKED, "name": "Bloque agrietado",
		"desc": "De arenisca: se rompe apenas te bajas de él. No hay vuelta atrás.",
		"say": "Los de arenisca con grietas se rompen en cuanto te bajas de ellos. Una vez que cruzaste, no hay vuelta atrás."},
	{"id": "bomba", "kind": K.BOMB, "name": "Bomba",
		"desc": "Cuenta hacia atrás con cada movimiento que haces cerca de ella (en una zona roja de 2 bloques a la redonda) y explota al llegar a cero. Subirte encima la desactiva.",
		"say": "Esa es una bomba: cuenta hacia atrás cada vez que te mueves dentro de su zona roja (2 bloques a la redonda), y si llega a cero explota. Subirte encima la desactiva."},
	{"id": "trampa", "kind": K.TRAP, "name": "Trampa",
		"desc": "Lleva una cruz roja: se desarma apenas te paras encima y te caes con ella.",
		"say": "Cuidado con las cruces rojas: esos bloques mienten. Se desarman apenas los pisas y te caes con ellos."},
	{"id": "pinchos", "kind": K.SPIKES, "name": "Pinchos",
		"desc": "Púas plateadas, a ras del piso: pisarlos pierde.",
		"say": "Esas púas plateadas no perdonan: si te paras encima, se acabó. Fíjate bien dónde pisas."},
	{"id": "catapulta", "kind": K.CATAPULT, "name": "Catapulta",
		"desc": "Al pisarla te dispara hacia arriba y te agarras del borde de un bloque cercano.",
		"say": "Una catapulta: al pisarla te dispara hacia arriba, y si hay un borde cerca, te agarras de él."},
]


static func get_block(id: String) -> Dictionary:
	for b in ALL:
		if b.id == id:
			return b
	return {}


## El bloque de la guía de un tipo de bloque del juego ({} si no hay).
static func for_kind(kind: int) -> Dictionary:
	for b in ALL:
		if b.kind == kind:
			return b
	return {}


static func discovered(id: String) -> bool:
	return Profile.has_block(id)


static func count_discovered() -> int:
	var n := 0
	for b in ALL:
		if Profile.has_block(b.id):
			n += 1
	return n


## Los bloques todavía no descubiertos entre las letras de bloque de una sala (las del motor: n, h, i, c, t, s, k, b7...): [{guía}], uno por tipo y en el orden de la guía.
static func newly_in_room(letters: Array) -> Array:
	var out: Array = []
	var seen := {}
	for l in letters:
		var letra := str(l).substr(0, 1)
		if not Tipos.DE_LETRA.has(letra):
			continue
		var info := for_kind(Tipos.DE_LETRA[letra])
		if info.is_empty() or seen.has(info.id) or Profile.has_block(info.id):
			continue
		seen[info.id] = true
		out.append(info)
	out.sort_custom(func(a, b): return ALL.find(a) < ALL.find(b))
	return out
