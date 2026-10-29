extends RefCounted
## Pruebas: etapas especiales (como los jefes de Balatro). Caen en las etapas 3, 6, 9... 27 (de a múltiplos de 3). Cada partida
## se sortea qué prueba toca en cada una (el escenario inclina el sorteo), y se sabe desde el principio cuál es la próxima y
## cuántas etapas faltan. Cada prueba cambia una regla de la torre, paga más claridad, regala un boost al superarla y, la primera
## vez, da un regalo (ver `reward`). Las habilidades persistentes no salen de acá: se ganan por escenario (ver scenarios.gd).
##
## Una prueba es un diccionario: {id, name, desc, no_items (sin consumibles), no_retry (sin reintentos: si caes se termina el run), no_streak (la racha no sube el multiplicador), travesuras (al entrar a cada sala Ama, una gata, mueve unos bloques: ver `Torre.armar` y docs/gatito_travieso.md),
## reglas (las reglas de la torre que pone: se suman a las del escenario; ver docs/pruebas.md), desde (la primera etapa en la que puede caer: las serias no salen en la 3), final (sólo cae en la etapa 15),
## limite (la prueba se trata de los movimientos de cada sala: en Fácil, que no los limita, no tendría ningún efecto y no sale)}.
## `mult` (multiplicador de la claridad juntada) y `index` (0..4) se completan al sortear: las últimas pagan más.

const Items := preload("res://scripts/datos/items.gd")
const Stages := preload("res://scripts/datos/stages.gd")
const Loc := preload("res://scripts/idioma/loc.gd")
const Demo := preload("res://scripts/datos/demo.gd")

const FIRST_STAGE := 3
const EVERY := 3
const FINAL_TRIAL := "pesadilla_despierta"   # el jefe final: sólo cae en la última etapa y combina dos reglas de las de abajo

const CATALOG := {
	"sin_ayudas": {"name": "Sin ayudas", "desc": "No se pueden usar consumibles.", "no_items": true},
	"todo_o_nada": {"name": "Todo o nada", "desc": "Sin reintentos: si caes, termina el run.", "no_retry": true},
	"sin_racha": {"name": "Sin racha", "desc": "La racha no multiplica la claridad.", "no_streak": true},
	"travesuras": {"name": "Travesuras", "desc": "Ama mueve unos bloques al entrar a cada sala.", "travesuras": true},
	"mareo": {"name": "Mareo", "desc": "La cámara se mueve sola.", "reglas": {"mareo": true}},
	"corrupcion": {"name": "Corrupción que vuelve", "desc": "Los bloques purificados se corrompen de nuevo.", "reglas": {"corrupcion": true}},
	"memoria_pez": {"name": "Memoria de pez", "desc": "La torre se esconde enseguida.", "reglas": {"memoria_pez": true}, "desde": 6},
	"terremoto": {"name": "Terremoto", "desc": "La torre tiembla y mueve bloques.", "reglas": {"terremoto": true}, "desde": 6},
	"presupuesto": {"name": "Presupuesto compartido", "desc": "Un solo fondo de movimientos para toda la torre.", "reglas": {"presupuesto": true}, "desde": 6, "limite": true},
	"solo_tres": {"name": "Solo tres bloques", "desc": "Solo puedes mover tres bloques distintos por sala.", "reglas": {"solo_bloques": 3}, "desde": 6},
	"espalda_mala": {"name": "Espalda mala", "desc": "Empujar o tirar cuesta dos movimientos.", "reglas": {"espalda_mala": true}, "desde": 9, "limite": true},
	"ventisca": {"name": "Ventisca", "desc": "Un viento te empuja; las líneas avisan hacia dónde.", "reglas": {"ventisca": true}, "desde": 9},
	"quebradizo": {"name": "Quebradizo", "desc": "Muchos bloques se rompen al bajarte de ellos.", "reglas": {"quebradizo": true}, "desde": 9},
	"a_oscuras": {"name": "A oscuras", "desc": "Muchos bloques son negros: no sabes qué son hasta pisarlos.", "reglas": {"a_oscuras": true}, "desde": 9},
	"pesadilla_despierta": {"name": "La Pesadilla despierta", "desc": "Dos pruebas a la vez.", "final": true, "desde": 15},
}

## Las dos reglas que combina La Pesadilla despierta (una combinación por partida, según su sorteo): {ids: [prueba, prueba], desc}.
const COMBOS := [
	{"ids": ["mareo", "terremoto"], "desc": "La cámara se mueve y la torre tiembla."},
	{"ids": ["memoria_pez", "ventisca"], "desc": "La torre se esconde y el viento te empuja."},
	{"ids": ["presupuesto", "espalda_mala"], "desc": "Un solo fondo de movimientos y empujar cuesta el doble."},
	{"ids": ["a_oscuras", "corrupcion"], "desc": "Bloques negros y corrupción que vuelve."},
]


static func stages() -> Array[int]:
	var out: Array[int] = []
	var s := FIRST_STAGE
	while s <= Stages.FINAL:
		out.append(s)
		s += EVERY
	return out


## Sortea las pruebas de una partida: {etapa: id}. Nunca repite la misma prueba dos veces seguidas; las serias no caen en las primeras etapas (`desde`) y el jefe final (si el escenario lo admite) cae siempre en la última.
static func draw_schedule(pool: Array, rng: RandomNumberGenerator, sin_limite := false) -> Dictionary:
	var out := {}
	var prev := ""
	if sin_limite:   # (Fácil no limita los movimientos: las pruebas que tratan de ellos no tendrían ningún efecto)
		pool = pool.filter(func(id): return not bool((CATALOG.get(id, {}) as Dictionary).get("limite", false)))
	for st in stages():
		if st == Stages.FINAL and pool.has(FINAL_TRIAL):
			var combos: Array = []
			for n in COMBOS.size():
				var con_limite := false
				for sub in COMBOS[n].ids:
					con_limite = con_limite or bool((CATALOG[sub] as Dictionary).get("limite", false))
				if not (sin_limite and con_limite):
					combos.append(n + 1)
			out[st] = "%s_%d" % [FINAL_TRIAL, combos[rng.randi() % combos.size()]]   # (el jefe final con su combinación sorteada: queda en la partida)
			continue
		var options: Array = pool.filter(func(id): return id != prev and id != FINAL_TRIAL and not (Demo.on() and id == "todo_o_nada" and st < Demo.LAST_STAGE) and int((CATALOG.get(id, {}) as Dictionary).get("desde", FIRST_STAGE)) <= st)
		if options.is_empty():
			options = pool.filter(func(id): return id != FINAL_TRIAL)
		if options.is_empty():
			options = pool
		var id: String = options[rng.randi() % options.size()]
		out[st] = id
		prev = id
	return out


## La prueba de una etapa según el sorteo de la partida ({} si es una etapa común): el diccionario del catálogo más `id`, `mult` e `index`.
static func for_stage(schedule: Dictionary, stage: int) -> Dictionary:
	if not schedule.has(stage):
		return {}
	var id: String = schedule[stage]
	var forzada := -1   # (para probar: "pesadilla_despierta_2" es el jefe final con la segunda combinación)
	if id.begins_with(FINAL_TRIAL + "_") and id.substr(FINAL_TRIAL.length() + 1).is_valid_int():
		forzada = clampi(int(id.substr(FINAL_TRIAL.length() + 1)) - 1, 0, COMBOS.size() - 1)
		id = FINAL_TRIAL
	if not CATALOG.has(id):
		return {}
	var t: Dictionary = (CATALOG[id] as Dictionary).duplicate(true)
	var index := (stage - FIRST_STAGE) / EVERY
	t["id"] = id
	if id == FINAL_TRIAL:   # (combina las reglas de dos pruebas; la combinación sale del sorteo de la partida, así es la misma al volver a empezar la torre)
		var combo: Dictionary = COMBOS[forzada if forzada >= 0 else absi(str(schedule).hash()) % COMBOS.size()]
		var reglas := {}
		for sub in combo.ids:
			reglas.merge((CATALOG[sub].reglas as Dictionary), true)
		t["reglas"] = reglas
		t["desc"] = combo.desc
		t["combo"] = combo.ids
	t["index"] = index
	t["mult"] = 1.5 + 0.3 * index    # 1,5 en la primera, 2,7 en la última (son 5)
	return t


## La próxima prueba desde `stage` (incluida): {stage, trial, left (etapas que faltan; 0 = es esta)} o {} si no quedan.
static func next_from(schedule: Dictionary, stage: int) -> Dictionary:
	for st in stages():
		if st >= stage and schedule.has(st):
			return {"stage": st, "trial": for_stage(schedule, st), "left": st - stage}
	return {}


## Recompensa de superar una prueba: un boost de nivel raro (o épico en las últimas) que entre en el run; si no hay lugar, claridad.
## Devuelve {item: Dictionary ({} si fue claridad), claridad: int, text: String}. No modifica el run: quien llama lo aplica.
static func reward(trial: Dictionary, stage: int, run, rng: RandomNumberGenerator) -> Dictionary:
	if trial.is_empty():
		return {"item": {}, "claridad": 0, "text": ""}
	var tier: int = Items.Tier.EPICO if int(trial.index) >= 3 else Items.Tier.RARO
	while tier >= Items.Tier.COMUN:
		var pool: Array[Dictionary] = []
		for it in Items.by_tier(tier):
			if it.type == Items.Type.BOOST and run.has_room_for(it):
				pool.append(it)
		if not pool.is_empty():
			var it: Dictionary = pool[rng.randi() % pool.size()]
			return {"item": it, "claridad": 0, "text": Loc.f("Recompensa: %s", [Loc.t(it.name)])}
		tier -= 1
	var bonus := 40 + 18 * stage
	return {"item": {}, "claridad": bonus, "text": Loc.f("Recompensa: %d de claridad", [bonus])}
