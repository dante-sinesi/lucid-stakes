extends RefCounted
## Habilidades persistentes: mejoras que se conservan para siempre. No se compran ni se ganan con las pruebas: cada escenario tiene las suyas
## (ver Scenarios.abilities) y se gana una al escapar de la pesadilla en ese escenario. Valen en todos los escenarios.
## Una habilidad es {id, name, desc} (y opcionalmente `perk`, el efecto de la torre) y se aplica al empezar el run (`apply_to_run`) o como "perk"
## de la torre (ver TowerLogic.apply_perks: los ids de `perks` valen como si fueran boosts).

const Trials := preload("res://scripts/trials.gd")

const ALL: Array[Dictionary] = [
	{"id": "mente_despejada", "name": "Mente despejada", "desc": "Empiezas cada run con +25 de claridad."},
	{"id": "ojos_de_gato", "name": "Ojos de gato", "desc": "Purificar un bloque da +1 de claridad.", "perk": "pies_de_luz"},
	{"id": "racha_firme", "name": "Racha firme", "desc": "El tope del multiplicador de racha sube de ×4 a ×6.", "perk": "racha_larga"},
	{"id": "margen_de_error", "name": "Margen de error", "desc": "En Sin piedad, cada sala permite un movimiento en falso más (3 en lugar de 2)."},
]

## Habilidades ya diseñadas cuyo escenario todavía no se puede jugar: no se pueden ganar, así que no aparecen en el juego. Al habilitar el escenario se pasan a ALL.
const PENDING: Array[Dictionary] = [
	{"id": "pies_ligeros", "name": "Pies ligeros", "desc": "La fila de abajo cae 1 movimiento más tarde."},
	{"id": "bolsillo_sonador", "name": "Bolsillo de soñador", "desc": "Un lugar más para consumibles."},
	{"id": "segunda_oportunidad", "name": "Segunda oportunidad", "desc": "Reintentar la torre cuesta 15 % menos."},
	{"id": "fuerza_bruta", "name": "Fuerza bruta", "desc": "Puedes empujar y tirar de los bloques pesados.", "perk": "fuerza_bruta"},
	{"id": "corazon_extra", "name": "Corazón extra", "desc": "Tienes una vida más en todas las partidas (4 corazones)."},
	{"id": "mecha_larga", "name": "Mecha larga", "desc": "Las cuentas de las bombas empiezan 3 movimientos más altas.", "perk": "reflejos"},
]


static func get_ability(id: String) -> Dictionary:
	for a in ALL:
		if a.id == id:
			return a
	return {}


## Los "perks" de la torre que dan las habilidades que tenés (se suman a los boosts).
static func perks_for(owned: Array) -> Array[String]:
	var out: Array[String] = []
	for id in owned:
		var a := get_ability(str(id))
		if a.has("perk"):
			out.append(a.perk)
	return out


## Lo contrario de apply_to_run para una habilidad (el laboratorio del modo dev las prende y las apaga).
static func remove_from_run(run, id: String) -> void:
	match id:
		"mente_despejada":
			run.claridad = maxi(run.claridad - 25, 0)
		"pies_ligeros":
			run.collapse_bonus = maxi(run.collapse_bonus - 1, 0)
		"bolsillo_sonador":
			run.meta_consumable_slots = maxi(run.meta_consumable_slots - 1, 0)
		"segunda_oportunidad":
			run.restart_discount = maxf(run.restart_discount - 0.15, 0.0)
		"corazon_extra":
			run.bonus_lives = maxi(run.bonus_lives - 1, 0)
			run.lives = mini(run.lives, run.max_lives())


## Aplica a un run recién empezado lo que no es un perk de la torre.
static func apply_to_run(run, owned: Array) -> void:
	for id in owned:
		match str(id):
			"mente_despejada":
				run.claridad += 25
			"pies_ligeros":
				run.collapse_bonus += 1
			"bolsillo_sonador":
				run.meta_consumable_slots += 1
			"segunda_oportunidad":
				run.restart_discount += 0.15
			"corazon_extra":
				run.bonus_lives += 1
