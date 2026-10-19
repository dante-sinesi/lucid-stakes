extends RefCounted
## Pruebas: etapas especiales (como los jefes de Balatro). Caen en las etapas 3, 6, 9... 27 (de a múltiplos de 3). Cada partida
## se sortea qué prueba toca en cada una (el escenario inclina el sorteo), y se sabe desde el principio cuál es la próxima y
## cuántas etapas faltan. Cada prueba cambia una regla de la torre, paga más claridad, regala un boost al superarla y, la primera
## vez, da un regalo (ver `reward`). Las habilidades persistentes no salen de acá: se ganan por escenario (ver scenarios.gd).
##
## Una prueba es un diccionario: {id, name, desc, pace ("" = el de la etapa), fog (sólo se ven
## los pisos cercanos), dark (sólo se ven los bloques cercanos), no_items (sin consumibles), no_retry (sin reintentos: si caés se
## termina el run), no_streak (la racha no sube el multiplicador), bias (sesgo del generador: ver TowerGen._bias)}.
## `mult` (multiplicador de la claridad juntada) y `index` (0..4) se completan al sortear: las últimas pagan más.

const Items := preload("res://scripts/items.gd")
const Stages := preload("res://scripts/stages.gd")
const TowerLogic := preload("res://scripts/tower_logic.gd")
const Loc := preload("res://scripts/loc.gd")
const K := TowerLogic.Kind

const FIRST_STAGE := 3
const EVERY := 3
const FOG_ABOVE := 3        # pisos que se ven por encima del jugador con niebla
const DARK_RADIUS := 4.5    # distancia (en celdas) hasta la que se ven los bloques en la oscuridad

const CATALOG := {
	"niebla": {"name": "Niebla", "desc": "Solo ves unos pocos pisos por encima de ti.", "fog": true},
	"oscuridad": {"name": "Oscuridad", "desc": "Solo ves los bloques que tienes cerca.", "dark": true},
	"prisa": {"name": "Prisa", "desc": "La fila de abajo cae mucho más rápido.", "pace": "fast"},
	"sin_ayudas": {"name": "Sin ayudas", "desc": "No se pueden usar consumibles.", "no_items": true},
	"todo_o_nada": {"name": "Todo o nada", "desc": "No hay reintentos: si caes, se termina el run.", "no_retry": true},
	"sin_racha": {"name": "Sin racha", "desc": "La racha no sube el multiplicador de claridad.", "no_streak": true},
	"hielo_total": {"name": "Hielo total", "desc": "La torre está llena de hielo.",
			"bias": {"kinds": {K.ICE: 1.6}, "plat_ice": 0.35, "cap_bonus": 3}},
	"quebradizo": {"name": "Quebradizo", "desc": "Casi todo se rompe al pisarlo o no se mueve.",
			"bias": {"kinds": {K.CRACKED: 1.2, K.HEAVY: 0.8}, "cap_bonus": 3}},
	"meteoritos": {"name": "Lluvia de meteoritos", "desc": "Cada vez que te mueves cae un meteorito y destruye un bloque (se marca antes). Nunca te cierra el camino.", "meteors": true},
	"polvorin": {"name": "Polvorín", "desc": "La torre está llena de bombas.",
			"bias": {"kinds": {K.BOMB: 1.2}, "cap_bonus": 2}},
}

## Sorteo por defecto (el de La Pesadilla): las pruebas que no necesitan un generador especial.
const DEFAULT_POOL: Array[String] = ["niebla", "oscuridad", "prisa", "sin_ayudas", "todo_o_nada", "sin_racha", "meteoritos"]


static func stages() -> Array[int]:
	var out: Array[int] = []
	var s := FIRST_STAGE
	while s <= Stages.FINAL:
		out.append(s)
		s += EVERY
	return out


static func is_trial_stage(stage: int) -> bool:
	return stage >= FIRST_STAGE and stage <= Stages.FINAL and (stage - FIRST_STAGE) % EVERY == 0


## Sortea las pruebas de una partida: {etapa: id}. Nunca repite la misma prueba dos veces seguidas.
static func draw_schedule(pool: Array, rng: RandomNumberGenerator) -> Dictionary:
	var out := {}
	var prev := ""
	for st in stages():
		var options: Array = pool.filter(func(id): return id != prev)
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
	if not CATALOG.has(id):
		return {}
	var t: Dictionary = (CATALOG[id] as Dictionary).duplicate(true)
	var index := (stage - FIRST_STAGE) / EVERY
	t["id"] = id
	t["index"] = index
	t["mult"] = 1.5 + 0.3 * index    # 1,5 en la primera, 2,7 en la última (son 5)
	return t


## La próxima prueba desde `stage` (incluida): {stage, trial, left (etapas que faltan; 0 = es esta)} o {} si no quedan.
static func next_from(schedule: Dictionary, stage: int) -> Dictionary:
	for st in stages():
		if st >= stage and schedule.has(st):
			return {"stage": st, "trial": for_stage(schedule, st), "left": st - stage}
	return {}


## ¿Se ve el bloque en `pos` desde el jugador, con las reglas de visibilidad de la prueba?
static func visible_from(trial: Dictionary, pos: Vector3i, player: Vector3i) -> bool:
	if trial.get("fog", false) and pos.y > player.y + FOG_ABOVE:
		return false
	if trial.get("dark", false) and Vector3(pos - player).length() > DARK_RADIUS:
		return false
	return true


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
