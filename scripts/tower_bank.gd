extends RefCounted
## El banco de torres de la demo: torres ya generadas (y verificadas con su camino) para las etapas de la demo, guardadas en data/torres_demo.torres. Con el banco la torre
## de la etapa 1 y la 2 aparece al instante, siempre se puede ganar y no hace falta el solucionador nativo en la máquina del jugador. El juego completo sigue generando en
## vivo. Si el banco no tiene la etapa o falla algo, se genera como siempre.
## Formato del archivo: [u32 tamaño sin comprimir][var_to_bytes de {"escenario|etapa": [registro, ...]} comprimido con zstd]. Un registro es la torre inicial
## (sólo lo que define una torre sin jugar: bloques, tipos, meta, jugador, ritmo de la caída) y su camino: {seed, path, rows, collapse_every, logic: {...}}.
## Se arma con `tests/arma_banco.gd` (herramientas\banco_torres.bat).

const TowerLogic := preload("res://scripts/tower_logic.gd")

const PATH := "res://data/torres_demo.torres"
## Lo que define una torre sin jugar (el resto de TowerLogic es el estado de una partida en curso).
const KEYS := ["size", "goal_y", "goal_cell", "goal_block", "goal_ids", "blocks", "fixed", "kind_of", "bomb_timer", "positions", "purified", "player", "floor_y", "collapse_every",
		"moves_to_collapse", "_next_id", "row_platforms", "platform_row", "reached_row", "facing"]

static var path := PATH
static var _bank := {}
static var _loaded_from := ""
## Para las pruebas: -1 = lo que diga el entorno / la demo, 0 = nunca, 1 = siempre.
static var forced := -1


static func key_of(scenario: String, stage: int) -> String:
	return "%s|%d" % [scenario, stage]


## ¿Hay que usar el banco? En la demo sí; en el juego completo sólo si se pide (GAME_BANCO=1).
static func active() -> bool:
	if forced >= 0:
		return forced == 1
	return preload("res://scripts/demo.gd").on() or OS.get_environment("GAME_BANCO") == "1"


static func _ensure() -> void:
	if _loaded_from != path:
		_loaded_from = path
		_bank = read(path)


static func reload() -> void:
	_loaded_from = ""
	_ensure()


static func count(scenario: String, stage: int) -> int:
	_ensure()
	return (_bank.get(key_of(scenario, stage), []) as Array).size()


static func has(scenario: String, stage: int) -> bool:
	return count(scenario, stage) > 0


## La torre `index` (módulo la cantidad) del banco de esa etapa, lista para usar (como lo que devuelve Rooms.generate_stage); {} si no hay.
static func pick(scenario: String, stage: int, index: int) -> Dictionary:
	_ensure()
	var list: Array = _bank.get(key_of(scenario, stage), [])
	if list.is_empty():
		return {}
	return decode(list[posmod(index, list.size())])


## Un registro desde lo que devuelve Rooms.generate_stage (torre inicial + camino).
static func encode(res: Dictionary, seed_value: int) -> Dictionary:
	var logic = res.logic
	var l := {}
	for k in KEYS:
		var v = logic.get(k)
		l[k] = v.duplicate(true) if (v is Dictionary or v is Array) else v
	return {"seed": seed_value, "path": res.path.duplicate(true), "rows": res.rows.duplicate() if res.rows is Array else res.rows, "collapse_every": res.collapse_every, "logic": l}


static func decode(rec: Dictionary) -> Dictionary:
	var t = TowerLogic.new()
	var l: Dictionary = rec.logic
	for k in KEYS:
		var v = l[k]
		t.set(k, v.duplicate(true) if (v is Dictionary or v is Array) else v)
	t.zob = 0
	t.recompute_zob()
	return {"ok": true, "logic": t, "path": rec.path.duplicate(true), "rows": rec.rows, "collapse_every": rec.collapse_every, "seed_used": int(rec.seed), "ms": 0, "from_bank": true}


## ¿El camino del registro gana la torre? (se comprueba al armar el banco y en las pruebas)
static func replay_wins(res: Dictionary) -> bool:
	var s = res.logic.clone()
	s.track_purify = false
	for a in res.path:
		if not s.try_action(a.dir, a.mode).ok or s.lost:
			return false
		if s.won:
			break
	return s.won


static func read(p: String) -> Dictionary:
	if not FileAccess.file_exists(p):
		return {}
	var f := FileAccess.open(p, FileAccess.READ)
	if f == null:
		return {}
	var raw := f.get_buffer(f.get_length())
	f.close()
	if raw.size() < 8:
		return {}
	var size := raw.decode_u32(0)
	var body := raw.slice(4)
	var data := body.decompress(size, FileAccess.COMPRESSION_ZSTD)
	var v = bytes_to_var(data)
	return v if v is Dictionary else {}


static func write(p: String, bank: Dictionary) -> bool:
	var raw := var_to_bytes(bank)
	var comp := raw.compress(FileAccess.COMPRESSION_ZSTD)
	var out := PackedByteArray()
	out.resize(4)
	out.encode_u32(0, raw.size())
	out.append_array(comp)
	DirAccess.make_dir_recursive_absolute(p.get_base_dir())
	var f := FileAccess.open(p, FileAccess.WRITE)
	if f == null:
		return false
	f.store_buffer(out)
	f.close()
	_loaded_from = ""
	return true
