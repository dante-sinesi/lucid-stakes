extends RefCounted
## Perfil del jugador: lo que se conserva entre runs (meta-progresión). Se guarda en user://profile.json.
##  - Luz: la moneda. Se gana al terminar cada run (según cuánto avanzaste, multiplicada por el escenario) y se gasta en la entrada
##    de los escenarios (cada partida en un escenario de pago cuesta su entrada; La Pesadilla es gratis).
##  - Habilidades persistentes: se ganan la primera vez que superás cada prueba (ver abilities.gd); valen para siempre.
##  - Estadísticas: mejor etapa, runs, escapes, pruebas superadas.
## Todo es estático (un solo perfil por proceso). Un archivo ilegible se ignora.

const Abilities := preload("res://scripts/datos/abilities.gd")
const Scenarios := preload("res://scripts/datos/scenarios.gd")
const Trials := preload("res://scripts/datos/trials.gd")
const Cosmetics := preload("res://scripts/personajes/cosmetics.gd")
const Characters := preload("res://scripts/personajes/characters.gd")
const Demo := preload("res://scripts/datos/demo.gd")
const VERSION := 2

## Ruta del archivo (las pruebas la cambian para no tocar el perfil real).
static var path := "user://profile.json"
static var data := {}
static var _loaded_from := ""


static func default_data() -> Dictionary:
	return {"version": VERSION, "luz": 0, "luz_total": 0, "best_stage": 0, "runs": 0, "victories": 0, "trials_cleared": 0, "abilities": {}, "cosmetics": {},
			"hat": "", "outfit": "", "characters": {"gato": true, "perro": true, "dante": true, "gaby": true}, "character": "gato", "blocks_seen": {}, "help_seen": {}, "tutorial_done": false}


## Carga el perfil (una vez por ruta). Si no hay archivo o está dañado, uno vacío.
static func load_profile() -> Dictionary:
	if _loaded_from == path and not data.is_empty():
		return data
	data = default_data()
	_loaded_from = path
	if FileAccess.file_exists(path):
		var f := FileAccess.open(path, FileAccess.READ)
		if f != null:
			var json := JSON.new()
			if json.parse(f.get_as_text()) == OK and typeof(json.data) == TYPE_DICTIONARY and int(json.data.get("version", 0)) == VERSION:
				for k in default_data():
					if json.data.has(k):
						data[k] = json.data[k]
				_migrate_cosmetics(json.data)
	for c in Characters.ALL:   # los personajes "de inicio" (el gatito, el perrito, Dante y Gaby) se tienen siempre
		if c.unlock == "inicio":
			data.characters[c.id] = true
	_apply_demo()
	return data


## La demo: los 4 personajes, 2 gorros y 2 prendas; el resto no se tiene (ni se puede ganar).
static func _apply_demo() -> void:
	if not Demo.on():
		return
	for id in data.characters.keys():
		if not Demo.character_allowed(str(id)):
			data.characters.erase(id)
	for id in data.cosmetics.keys():
		if not Demo.cosmetic_allowed(str(id)):
			data.cosmetics.erase(id)
	for id in Demo.HATS + Demo.OUTFITS:
		data.cosmetics[id] = true
	if not Demo.character_allowed(str(data.character)):
		data.character = Characters.DEFAULT
	if not Demo.cosmetic_allowed(str(data.hat)):
		data.hat = ""
	if not Demo.cosmetic_allowed(str(data.outfit)):
		data.outfit = ""


## Cuando los cosméticos eran colores del cubo: se pasan a la ropa equivalente (lo ya ganado no se pierde) y el aspecto elegido se pone
## como gorro o prenda.
static func _migrate_cosmetics(raw: Dictionary) -> void:
	var cos: Dictionary = data.cosmetics
	for old in Cosmetics.OLD_IDS:
		if cos.has(old):
			cos.erase(old)
			cos[Cosmetics.OLD_IDS[old]] = true
	for id in cos.keys():
		if Cosmetics.get_cosmetic(str(id)).is_empty():
			cos.erase(id)
	var eq := str(raw.get("equipped", ""))
	if eq != "":
		eq = str(Cosmetics.OLD_IDS.get(eq, eq))
		var c := Cosmetics.get_cosmetic(eq)
		if not c.is_empty() and cos.has(eq):
			data["hat" if c.slot == "gorro" else "outfit"] = eq


static func save() -> void:
	load_profile()
	var f := FileAccess.open(path, FileAccess.WRITE)
	if f != null:
		f.store_string(JSON.stringify(data))


## Vuelve a un perfil vacío (y lo guarda). Para pruebas y "borrar progreso".
static func reset() -> void:
	data = default_data()
	_loaded_from = path
	_apply_demo()
	save()


## ¿Ya se hizo el tutorial? (Quien ya jugó antes de que el tutorial fuera obligatorio no lo repite.) GAME_FIRST_RUN=1 fuerza la primera vez (para probarla).
static func tutorial_done() -> bool:
	if OS.get_environment("GAME_FIRST_RUN") == "1":
		return false
	var d := load_profile()
	return bool(d.get("tutorial_done", false)) or int(d.get("runs", 0)) > 0 or int(d.get("best_stage", 0)) > 0


static func mark_tutorial_done() -> void:
	var d := load_profile()
	if not bool(d.get("tutorial_done", false)):
		d["tutorial_done"] = true
		save()


static func luz() -> int:
	return int(load_profile().luz)


# --- escenarios ---------------------------------------------------------------------------------------------------

static func can_enter(scenario_id: String) -> bool:
	return luz() >= int(Scenarios.get_scenario(scenario_id).get("entry", 0))


## Paga la entrada de un escenario. Devuelve false (y no cobra) si no alcanza la Luz.
static func pay_entry(scenario_id: String) -> bool:
	var cost := int(Scenarios.get_scenario(scenario_id).get("entry", 0))
	if luz() < cost:
		return false
	var d := load_profile()
	d.luz = int(d.luz) - cost
	save()
	return true


# --- guía de bloques ---------------------------------------------------------------------------------------------------

static func has_block(id: String) -> bool:
	return bool(load_profile().blocks_seen.get(id, false))


## Anota un bloque como descubierto (se guarda al instante). Devuelve true si era nuevo.
static func discover_block(id: String) -> bool:
	if has_block(id):
		return false
	load_profile().blocks_seen[id] = true
	save()
	return true


# --- ayudas de los juegos --------------------------------------------------------------------------------------------

## ¿Ya se mostró la ayuda de ese juego (se abre sola la primera vez que se entra)?
static func help_seen(id: String) -> bool:
	var d := load_profile()
	return bool((d.get("help_seen", {}) as Dictionary).get(id, false))


static func mark_help_seen(id: String) -> void:
	var d := load_profile()
	if not d.has("help_seen") or not (d.help_seen is Dictionary):
		d["help_seen"] = {}
	if bool(d.help_seen.get(id, false)):
		return
	d.help_seen[id] = true
	save()


# --- habilidades ---------------------------------------------------------------------------------------------------

static func owned_abilities() -> Array[String]:
	var out: Array[String] = []
	for id in load_profile().abilities:
		out.append(str(id))
	return out


static func has_ability(id: String) -> bool:
	return load_profile().abilities.has(id)


## Da una habilidad. Devuelve true si es nueva (si ya la tenías, no pasa nada).
static func grant_ability(id: String) -> bool:
	if id == "" or has_ability(id):
		return false
	load_profile().abilities[id] = true
	save()
	return true


## Luz que se da cuando ya tenés todas las habilidades del escenario (multiplicada por la `luz_mult` del escenario).
const ABILITY_LUZ := 30


## Al escapar de la pesadilla en un escenario: gana una de sus habilidades que todavía no tenés (al azar); si ya las tenés todas, da Luz.
## Devuelve {ability (id o ""), luz}. Un escenario sin habilidades (el tutorial) no da nada.
static func award_scenario_ability(scenario_id: String, rng: RandomNumberGenerator) -> Dictionary:
	var scn := Scenarios.get_scenario(scenario_id)
	var all := Scenarios.ability_ids(scn)
	if all.is_empty():
		return {"ability": "", "luz": 0}
	var pending: Array[String] = []
	for id in all:
		if not has_ability(id):
			pending.append(id)
	if pending.is_empty():
		var luz := int(round(ABILITY_LUZ * float(scn.get("luz_mult", 1.0))))
		add_luz(luz)
		return {"ability": "", "luz": luz}
	var pick: String = pending[rng.randi() % pending.size()]
	grant_ability(pick)
	return {"ability": pick, "luz": 0}


## Aplica a un run recién empezado las habilidades y el escenario elegido.
static func apply_to_run(run) -> void:
	Abilities.apply_to_run(run, owned_abilities())
	run.price_mult = float(run.scenario().get("price_mult", 1.0))
	run.lives = run.max_lives()   # las vidas del escenario (con los corazones de más de las habilidades)


# --- Luz suelta y cosméticos ----------------------------------------------------------------------------------------

## Suma Luz al perfil (por ejemplo, un premio de los dados de la pantalla de carga).
static func add_luz(n: int) -> void:
	var d := load_profile()
	d.luz = maxi(int(d.luz) + n, 0)
	d.luz_total = int(d.luz_total) + maxi(n, 0)
	save()


static func owned_cosmetics() -> Array[String]:
	var out: Array[String] = []
	for id in load_profile().cosmetics:
		out.append(str(id))
	return out


static func has_cosmetic(id: String) -> bool:
	return id == "" or (Demo.cosmetic_allowed(id) and load_profile().cosmetics.has(id))


## Da un cosmético. Devuelve true si es nuevo.
static func grant_cosmetic(id: String) -> bool:
	if id == "" or load_profile().cosmetics.has(id):
		return false
	load_profile().cosmetics[id] = true
	save()
	return true


## Se pone un gorro o una prenda que se tenga (va al hueco que le toca). "" no hace nada: para sacar algo, `unequip`.
static func equip(id: String) -> bool:
	var c := Cosmetics.get_cosmetic(id)
	if c.is_empty() or not has_cosmetic(id):
		return false
	load_profile()["hat" if c.slot == "gorro" else "outfit"] = id
	save()
	return true


## Se saca lo que lleva en el hueco ("gorro" o "prenda").
static func unequip(slot: String) -> void:
	load_profile()["hat" if slot == "gorro" else "outfit"] = ""
	save()


static func equipped_hat() -> String:
	var id := str(load_profile().get("hat", ""))
	return id if has_cosmetic(id) else ""


static func equipped_outfit() -> String:
	var id := str(load_profile().get("outfit", ""))
	return id if has_cosmetic(id) else ""


# --- personajes ----------------------------------------------------------------------------------------------------------

static func owned_characters() -> Array[String]:
	var out: Array[String] = []
	for c in Characters.ALL:
		if load_profile().characters.has(c.id):
			out.append(c.id)
	return out


static func has_character(id: String) -> bool:
	return Demo.character_allowed(id) and load_profile().characters.has(id)


## Desbloquea un personaje. Devuelve true si es nuevo.
static func unlock_character(id: String) -> bool:
	if Characters.get_character(id).id != id or has_character(id) or not Demo.character_allowed(id):
		return false
	load_profile().characters[id] = true
	save()
	return true


## Elige con qué personaje se juega (sólo uno desbloqueado).
static func select_character(id: String) -> bool:
	if not has_character(id):
		return false
	load_profile().character = id
	save()
	return true


static func character() -> String:
	var id := str(load_profile().get("character", Characters.DEFAULT))
	return id if has_character(id) else Characters.DEFAULT


## Se superó una prueba (el perrito ya no se gana así: se tiene desde el principio). Devuelve los personajes nuevos.
static func on_trial_cleared() -> Array[String]:
	return _unlocked([])


## Se ganó una habilidad (ninguna desbloquea personajes por ahora).
static func on_ability(_ability_id: String) -> Array[String]:
	return _unlocked([])


## Se llegó a una etapa: la 6 desbloquea al conejito (el gatito ya se tiene desde el principio).
static func on_stage_reached(stage: int) -> Array[String]:
	var ids: Array = []
	if stage >= 6:
		ids.append("conejo")
	return _unlocked(ids)


static func _unlocked(ids: Array) -> Array[String]:
	var out: Array[String] = []
	for id in ids:
		if unlock_character(str(id)):
			out.append(str(id))
	return out


# --- fin de run ------------------------------------------------------------------------------------------------------

## Luz que da un run: 3 por cada torre superada, 12 por cada prueba y 100 por escapar; el escenario la multiplica.
const LUZ_FAIL_SHARE := 0.2   # fracción de la Luz del avance que se conserva al perder o abandonar


const LUZ_POR_DIFICULTAD := {"facil": 0.25}   # Fácil (movimientos ilimitados y pistas) da menos Luz; las demás dificultades, la completa


static func luz_for_run(run, victory: bool) -> int:
	var progress: int = run.towers_cleared * 5 + run.trials_cleared * 20   # (son 15 torres y 5 pruebas)
	var base := float(progress + 100) if victory else float(progress) * LUZ_FAIL_SHARE   # lo que importa es escapar: si el run no termina en victoria, sólo se conserva una parte de lo avanzado
	return int(round(base * float(run.scenario().get("luz_mult", 1.0)) * float(LUZ_POR_DIFICULTAD.get(run.dificultad, 1.0))))


## Anota un run terminado: suma Luz y estadísticas, y guarda. Devuelve la Luz ganada.
static func record_run(run, victory: bool) -> int:
	var d := load_profile()
	var gained := luz_for_run(run, victory)
	d.luz = int(d.luz) + gained
	d.luz_total = int(d.luz_total) + gained
	d.runs = int(d.runs) + 1
	d.victories = int(d.victories) + (1 if victory else 0)
	d.best_stage = maxi(int(d.best_stage), run.max_stage)
	d.trials_cleared = int(d.trials_cleared) + run.trials_cleared
	save()
	return gained
