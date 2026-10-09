extends RefCounted
## Habilidades persistentes: mejoras que se conservan para siempre. No se compran: se ganan la primera vez que superás una prueba, y
## cada una está relacionada con esa prueba (superar el "Hielo total" te enseña a colgarte del hielo). Valen en todos los escenarios.
## Una habilidad es {id, name, desc, trial (la prueba que la da)} y se aplica al empezar el run (`apply_to_run`) o como "perk"
## de la torre (ver TowerLogic.apply_perks: los ids de `perks` valen como si fueran boosts).

const Trials := preload("res://scripts/trials.gd")

const ALL: Array[Dictionary] = [
	{"id": "mente_despejada", "name": "Mente despejada", "desc": "Empezás cada run con +25 de claridad.", "trial": "niebla"},
	{"id": "ojos_de_gato", "name": "Ojos de gato", "desc": "Purificar un bloque da +1 de claridad.", "trial": "oscuridad", "perk": "pies_de_luz"},
	{"id": "pies_ligeros", "name": "Pies ligeros", "desc": "La fila de abajo cae 1 movimiento más tarde.", "trial": "prisa"},
	{"id": "bolsillo_sonador", "name": "Bolsillo de soñador", "desc": "Un lugar más para consumibles.", "trial": "sin_ayudas"},
	{"id": "segunda_oportunidad", "name": "Segunda oportunidad", "desc": "Reintentar la torre cuesta 15 % menos.", "trial": "todo_o_nada"},
	{"id": "racha_firme", "name": "Racha firme", "desc": "El tope del multiplicador de racha sube de ×4 a ×6.", "trial": "sin_racha", "perk": "racha_larga"},
	{"id": "garras_de_hielo", "name": "Garras de hielo", "desc": "Podés colgarte de los bloques de hielo.", "trial": "hielo_total", "perk": "garras_de_hielo"},
	{"id": "fuerza_bruta", "name": "Fuerza bruta", "desc": "Podés empujar y tirar de los bloques pesados.", "trial": "quebradizo", "perk": "fuerza_bruta"},
	{"id": "mecha_larga", "name": "Mecha larga", "desc": "Las cuentas de las bombas empiezan 3 movimientos más altas.", "trial": "polvorin", "perk": "reflejos"},
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
