extends RefCounted
## Habilidades persistentes: mejoras que se conservan para siempre. No se compran ni se ganan con las pruebas: cada escenario tiene las suyas
## (ver Scenarios.abilities) y se gana una al escapar de la pesadilla en ese escenario. Valen en todos los escenarios.
## Una habilidad es {id, name, desc} (y opcionalmente `perk`, el efecto de la torre) y se aplica al empezar el run (`apply_to_run`) o como "perk"
## de la torre (ver torre/torre.gd y cosecha.gd: los ids de `perks` valen como si fueran boosts).

const Trials := preload("res://scripts/datos/trials.gd")

const REGATEO := 0.10   # Buen regateo: lo que baja el peaje de Farolín

const ALL: Array[Dictionary] = [
	{"id": "mente_despejada", "name": "Mente despejada", "desc": "Empiezas cada run con +25 de claridad."},
	{"id": "ojos_de_gato", "name": "Ojos de gato", "desc": "Purificar un bloque da +1 de claridad.", "perk": "pies_de_luz"},
	{"id": "racha_firme", "name": "Racha firme", "desc": "El tope de la racha sube de ×4 a ×6.", "perk": "racha_larga"},
	{"id": "margen_de_error", "name": "Margen de error", "desc": "En El camino corto, cada sala permite un movimiento en falso más (3)."},
	{"id": "corazon_extra", "name": "Corazón extra", "desc": "Una vida más en todas las partidas (4 corazones), salvo en Compromiso."},
	{"id": "bolsillo_sonador", "name": "Bolsillo de soñador", "desc": "Un lugar más para consumibles."},
	{"id": "segunda_oportunidad", "name": "Segunda oportunidad", "desc": "Reintentar la torre cuesta 15 % menos."},
	{"id": "pies_ligeros", "name": "Pies ligeros", "desc": "Cada sala tiene 1 movimiento más."},
	{"id": "buena_letra", "name": "Buena letra", "desc": "Un contrato con fianza que falles por partida te devuelve la fianza."},
	{"id": "mecha_larga", "name": "Mecha larga", "desc": "Las bombas empiezan con 3 movimientos más.", "perk": "reflejos"},
	{"id": "buen_regateo", "name": "Buen regateo", "desc": "El peaje de Farolín cuesta 10 % menos."},
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


## Aplica a un run recién empezado lo que no es un perk de la torre.
static func apply_to_run(run, owned: Array) -> void:
	for id in owned:
		match str(id):
			"mente_despejada":
				run.claridad += 25
			"pies_ligeros":
				run.movs_extra += 1
			"bolsillo_sonador":
				run.meta_consumable_slots += 1
			"segunda_oportunidad":
				run.restart_discount += 0.15
			"corazon_extra":
				run.bonus_lives += 1
			"buena_letra":
				run.buena_letra = true
			"buen_regateo":
				run.toll_meta_discount += REGATEO
