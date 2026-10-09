extends RefCounted
## Lógica pura de la torre (sin nodos). Ver docs/diseno.md.
##
## - No hay suelo: la capa más baja (floor_y) cae al vacío cada `collapse_every` acciones.
## - Soporte: un bloque se queda si toca a otro en alguno de los 6 ejes; si no, cae
##   (hasta tocar algo, o al vacío). Los bloques fijos (core) no caen ni se mueven.
## - Jugador: de pie (necesita bloque debajo) o colgado del borde de un bloque (hang_dir apunta al bloque).
## - Tipos de bloque (Kind):
##   ICE      al empujarlo se desliza hasta chocar con algo (o hasta salir de la huella). Si el jugador llega a una celda apoyada
##            en hielo sigue deslizándose en la dirección del movimiento; no se puede colgar de su borde.
##   BOMB     cuenta movimientos sólo mientras el jugador está en su misma fila (player.y == y del
##            bloque); al llegar a 0 explota y la torre entera cae. Si cae al vacío se desactiva.
##   TRAP     (trampa) parece un bloque común, pero tiene una marca roja arriba: al quedar parado sobre ella se desarma y cae, y el
##            jugador con ella (si abajo hay otro bloque, se aterriza ahí; si no, se pierde).
##   SPIKES   (pinchos) quedar parado sobre un bloque con pinchos pierde el run. Se puede empujar y tirar como un bloque común.
##   CATAPULT al llegar a una celda apoyada en una catapulta el jugador sale disparado SÓLO HACIA ARRIBA
##            (CATAPULT_RISE celdas; un techo corta el ascenso). Arriba se agarra del lateral de un bloque
##            vecino que tenga el borde de arriba libre (primero hacia donde miraba, después los costados
##            y atrás) y queda colgado; si no hay de dónde agarrarse, vuelve a caer. Nunca se mueve hacia los costados.
## - Empujar una fila: si detrás del bloque empujado hay otros pegados, se mueve toda la fila (hasta MAX_ROW bloques) siempre que la
##   celda de más allá de la fila esté libre y ninguno sea fijo ni pesado. Una fila no resbala: el hielo sólo se desliza si va solo.
## - Tirar de un bloque sin piso atrás no se puede (el bloque quedaría sobre el borde del que te agarrarías); si atrás hay
##   un escalón más bajo, se baja. Colgarse del borde es a propósito (Espacio + dirección).
## - Boosts y consumibles del run (ver Items y apply_perks / use_item): cambian la caída, la racha, la purificación, etc.
## - Colgado se puede avanzar por el borde y doblar esquinas: hacia afuera (el borde del bloque termina y
##   se lo rodea) y hacia adentro (la pared gira hacia el jugador).
## - Purificación: todos los bloques empiezan corruptos. Al pasar por encima (celdas del rastro con
##   un bloque debajo, o el bloque del que se cuelga) el bloque se purifica y da claridad según su
##   tipo (CLARITY). Cada acción seguida que purifica algo nuevo sube la racha y su multiplicador;
##   una acción que no purifica nada nuevo la corta. Purificar una bomba la desactiva.

const Loc := preload("res://scripts/loc.gd")

enum Mode { MOVE, GRAB, HANG }
## ICE: resbala. BOMB: explota si te quedás en su fila. CATAPULT: lanza hacia arriba. CRACKED (agrietado): se rompe y cae apenas
## te bajás de él. HEAVY (pesado): no se empuja ni se tira (es una pared que se puede trepar); cae como cualquier bloque si se queda sin apoyo.
## TRAP: trampa (se desarma al pisarla). SPIKES: pinchos (pisarlos pierde).
enum Kind { NORMAL, ICE, BOMB, CATAPULT, CRACKED, HEAVY, TRAP, SPIKES }

const UP := Vector3i(0, 1, 0)
const DOWN := Vector3i(0, -1, 0)
const DIRS: Array[Vector3i] = [
	Vector3i(1, 0, 0), Vector3i(-1, 0, 0), Vector3i(0, 0, 1), Vector3i(0, 0, -1),
]
const NEIGHBORS: Array[Vector3i] = [
	Vector3i(1, 0, 0), Vector3i(-1, 0, 0), Vector3i(0, 0, 1), Vector3i(0, 0, -1),
	Vector3i(0, 1, 0), Vector3i(0, -1, 0),
]
## Apoyo por arista: un bloque también se sostiene del borde superior de un bloque vecino que quedó un nivel más abajo
## (si el de abajo se corre de costado, la arista sigue aguantando al de arriba).
const EDGE_SUPPORT: Array[Vector3i] = [
	Vector3i(1, -1, 0), Vector3i(-1, -1, 0), Vector3i(0, -1, 1), Vector3i(0, -1, -1),
]
## Cuántas celdas sube la catapulta (sólo hacia arriba).
const CATAPULT_RISE := 4
## Además de las 4 celdas que sube, busca de dónde agarrarse hasta 2 celdas más arriba (si el camino está libre).
const CATAPULT_REACH := 2
const SLIDE_LIMIT := 40
## Claridad que da purificar cada tipo de bloque (los bloques fijos del core dan FIXED_CLARITY).
const CLARITY := {
	Kind.NORMAL: 1, Kind.ICE: 2, Kind.BOMB: 5, Kind.CATAPULT: 3, Kind.CRACKED: 2, Kind.HEAVY: 2, Kind.TRAP: 2, Kind.SPIKES: 3,
}
## Cuántos bloques seguidos se pueden empujar a la vez.
const MAX_ROW := 3
const FIXED_CLARITY := 1
const STREAK_STEP := 0.5   # cada acción más de racha suma esto al multiplicador
const STREAK_MAX_MULT := 4.0

var size := Vector2i(7, 7)
var goal_y := 9
var goal_cell := Vector3i.ZERO
## Id del bloque-portal: si es >= 0, ganar exige estar parado sobre ESE bloque (no basta con llegar a la altura).
## Con -1 vale cualquier bloque a la altura de la meta (torres sueltas de prueba, ventanas del solucionador).
var goal_block := -1
## Ids de bloques meta (varios): si no está vacío, ganar exige estar parado sobre alguno de ellos. Lo usa el generador:
## una fila se da por resuelta sólo al llegar a SU plataforma (no a un escalón sobrante de la fila anterior).
var goal_ids := {}
var blocks := {}      # Vector3i -> id
var fixed := {}       # Vector3i -> true: bloques inmóviles (core); no se empujan ni se tiran, no caen
var kind_of := {}     # id -> Kind (los NORMAL no figuran)
var bomb_timer := {}  # id -> movimientos que le quedan (sólo bloques BOMB)
var positions := {}   # id -> Vector3i
var purified := {}    # id -> true: bloques ya purificados (la purificación acompaña al bloque si se mueve)
var removed_ids: Array[int] = []  # bloques caídos al vacío en la última acción (para la vista)
var trail: Array[Vector3i] = []   # celdas que ocupó el jugador durante la última acción (incluida la de partida)
var last_purified: Array[int] = []  # ids purificados en la última acción (para la vista)
var last_gain := 0                # claridad ganada en la última acción
var claridad := 0
var streak := 0                   # acciones seguidas que purificaron algo nuevo
var best_streak := 0
var purified_count := 0
var track_purify := true          # el solucionador lo apaga: sólo importa desactivar bombas
var player := Vector3i.ZERO
var hang_dir := Vector3i.ZERO     # ZERO = de pie; si no, dirección hacia el bloque del que cuelga
var facing := Vector3i(0, 0, -1)
var floor_y := 0                  # capa más baja que aún existe
var collapse_every := 6
var moves_to_collapse := 6
var moves_made := 0
var won := false
var lost := false
var lost_reason := ""
var _next_id := 0
## Boosts activos del run (id -> true). Se comparte entre copias: sólo cambia con apply_perks.
var perks := {}
var collapse_pause := 0        # movimientos que quedan con la caída de la fila base en pausa (consumible Freno)
var second_wind_used := false  # el boost Segundo aliento se usa una vez por etapa
var last_safe := Vector3i.ZERO # última celda donde estuvo parado sobre un bloque (para Segundo aliento)
var anchored := {}             # ids de bloques que no caen aunque pierdan sus vecinos (consumible Ancla chica)
var perk_msg := ""             # aviso de la última acción para la vista (por ejemplo "¡Segundo aliento!")
var trap_broke := false        # en la última acción se desarmó una trampa (para el sonido)
var exploded := false          # en la última acción explotó una bomba (para la animación)
var explosion_cell := Vector3i.ZERO   # y dónde estaba
var _crack_id := -1            # bloque agrietado sobre el que estaba parado al empezar la acción (se rompe si te bajás)
var _crack_from := Vector3i.ZERO
var _climbed := false          # la última acción fue trepar o bajar un escalón (boost Paso firme)
## Huella (hash de Zobrist) del conjunto de bloques con su tipo: se actualiza al agregar, mover y quitar. El solucionador la usa
## como identidad del estado sin recorrer todos los bloques (ver Solver._key).
var zob := 0
## Ids de los bloques de la plataforma de cada fila (fila -> Array[int]); lo llena el generador y lo usa la pista del modo entrenamiento.
var row_platforms := {}
## Fila de cada bloque de plataforma (id -> fila) y la fila más alta cuya plataforma ya pisó el jugador: la pista del modo
## entrenamiento apunta siempre a la fila siguiente (así no cambia de objetivo si el camino exige bajar un escalón).
var platform_row := {}
var reached_row := 0
var _fixed_shared := false   # `fixed` se comparte entre copias (casi nunca cambia): se duplica recién al escribir
var lazy_settle := false     # el solucionador y el generador lo prenden: sólo se revisa qué bloques caen cuando algún bloque se movió o se sacó (ver _settle_blocks)
var _blocks_dirty := true    # hay que revisar el apoyo de los bloques (cambió algo desde la última revisión)
var _maps_shared := false    # blocks, positions, kind_of, bomb_timer y purified se comparten con otra copia hasta que una escribe (ver _own_maps)


func in_bounds(c: Vector3i) -> bool:
	return c.x >= 0 and c.x < size.x and c.z >= 0 and c.z < size.y and c.y >= 0


## Colgado del borde se puede estar una celda por fuera de la huella (el agarre es de un bloque de adentro).
func in_hang_reach(c: Vector3i) -> bool:
	return c.x >= -1 and c.x <= size.x and c.z >= -1 and c.z <= size.y and c.y >= 0


## Hash de 64 bits de un bloque de tipo `kind` en la celda `c` (mezcla splitmix64).
static func zob_hash(c: Vector3i, kind: int) -> int:
	var v := (c.x + 16) + 64 * ((c.z + 16) + 64 * ((c.y + 64) + 256 * kind)) + 1
	v = (v ^ (v >> 30)) * -4658895280553007687
	v = (v ^ (v >> 27)) * -7723592293110705685
	return v ^ (v >> 31)


## Recalcula la huella desde cero (por si alguien tocó blocks o kind_of directamente, como hacen algunos tests).
func recompute_zob() -> void:
	zob = 0
	for c in blocks:
		zob ^= zob_hash(c, kind_of.get(blocks[c], 0))


func add_block(c: Vector3i, is_fixed := false, kind: int = Kind.NORMAL, timer := 0) -> void:
	_own_maps()
	_blocks_dirty = true
	zob ^= zob_hash(c, kind)
	blocks[c] = _next_id
	positions[_next_id] = c
	if is_fixed:
		_own_fixed()
		fixed[c] = true
	if kind != Kind.NORMAL:
		kind_of[_next_id] = kind
	if kind == Kind.BOMB:
		bomb_timer[_next_id] = timer
	_next_id += 1


## Tipo del bloque en la celda (-1 si no hay bloque).
func kind_at(c: Vector3i) -> int:
	if not blocks.has(c):
		return -1
	return kind_of.get(blocks[c], Kind.NORMAL)


func generate(seed_value: int) -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_value
	_own_maps()
	blocks.clear()
	positions.clear()
	removed_ids.clear()
	_next_id = 0
	zob = 0
	won = false
	lost = false
	lost_reason = ""
	floor_y = 0
	collapse_every = 6
	moves_to_collapse = collapse_every
	moves_made = 0
	hang_dir = Vector3i.ZERO

	# Capa base completa; escalera por el borde (z = 0) que sube de a 1; escalón final en (x_max, 1).
	var heights := {}
	for z in size.y:
		for x in size.x:
			heights[Vector2i(x, z)] = 1
	for x in size.x:
		heights[Vector2i(x, 0)] = x + 2
	goal_y = size.x + 2
	var goal_col := Vector2i(size.x - 1, 1)
	heights[goal_col] = goal_y
	goal_cell = Vector3i(goal_col.x, goal_y, goal_col.y)

	# Bloques sueltos para ensuciar el terreno (nunca bloquean la ruta mínima).
	for z in range(1, size.y):
		for x in size.x:
			var key := Vector2i(x, z)
			if key == goal_col:
				continue
			if z == 1:
				if rng.randf() < 0.4:
					heights[key] = 2
			elif not (x == 0 and z == 2):
				if rng.randf() < 0.5:
					heights[key] = 1 + rng.randi_range(1, 2)

	for key in heights:
		for y in heights[key]:
			add_block(Vector3i(key.x, y, key.y))

	player = Vector3i(0, 1, 2)
	facing = Vector3i(0, 0, -1)


func try_action(dir: Vector3i, mode: Mode = Mode.MOVE) -> Dictionary:
	if won or lost:
		return {"ok": false, "msg": ""}
	removed_ids.clear()
	last_purified.clear()
	last_gain = 0
	perk_msg = ""
	trap_broke = false
	exploded = false
	_climbed = false
	_crack_id = -1
	if hang_dir == Vector3i.ZERO and blocks.has(player + DOWN) and kind_at(player + DOWN) == Kind.CRACKED:
		_crack_id = blocks[player + DOWN]
		_crack_from = player
	trail.clear()
	trail.append(player)
	facing = dir
	var res: Dictionary
	if hang_dir != Vector3i.ZERO:
		res = _act_hanging(dir)
	elif mode == Mode.GRAB:
		res = _act_grab(dir)
	elif mode == Mode.HANG:
		res = _act_hang_over(dir)
	else:
		res = _act_walk(dir)
	if res.ok:
		_after_action()
	return res


## Copia independiente del estado (la usa el solucionador).
func clone() -> RefCounted:
	var c = get_script().new()
	c.size = size
	c.goal_y = goal_y
	c.goal_cell = goal_cell
	c.goal_block = goal_block
	c.goal_ids = goal_ids
	c.zob = zob
	c.row_platforms = row_platforms   # compartidos: sólo cambian mientras se genera (ver TowerGen._snapshot)
	c.platform_row = platform_row
	c.reached_row = reached_row
	c.perks = perks
	c.anchored = anchored
	c.collapse_pause = collapse_pause
	c.lazy_settle = lazy_settle
	c._blocks_dirty = _blocks_dirty
	c.blocks = blocks
	c.fixed = fixed
	c._fixed_shared = true
	_fixed_shared = true
	c.kind_of = kind_of
	c.bomb_timer = bomb_timer
	c.positions = positions
	c.purified = purified
	c._maps_shared = true
	_maps_shared = true
	c.claridad = claridad
	c.streak = streak
	c.best_streak = best_streak
	c.purified_count = purified_count
	c.track_purify = track_purify
	c.player = player
	c.hang_dir = hang_dir
	c.facing = facing
	c.floor_y = floor_y
	c.collapse_every = collapse_every
	c.moves_to_collapse = moves_to_collapse
	c.moves_made = moves_made
	c.won = won
	c.lost = lost
	c.lost_reason = lost_reason
	c._next_id = _next_id
	return c


func _ok() -> Dictionary:
	return {"ok": true, "msg": ""}


func _fail(msg: String) -> Dictionary:
	return {"ok": false, "msg": msg}


func _set_player(c: Vector3i) -> void:
	player = c
	trail.append(c)


func _act_walk(d: Vector3i) -> Dictionary:
	var t := player + d
	if not in_bounds(t):
		return _fail("Borde de la torre")
	if blocks.has(t):
		if blocks.has(t + UP) or blocks.has(player + UP):
			return _fail("Bloqueado (Shift: empujar)")
		_climbed = true
		_set_player(t + UP)
		_arrive(d)
		return _ok()
	if blocks.has(t + DOWN):
		_set_player(t)
		_arrive(d)
		return _ok()
	if blocks.has(t + DOWN * 2):  # bajar un escalón
		_climbed = true
		_set_player(t + DOWN)
		_arrive(d)
		return _ok()
	return _fail("Borde (Espacio + dirección: colgarse)")


func _act_grab(d: Vector3i) -> Dictionary:
	var t := player + d
	if blocks.has(t):
		var dest := t + d
		if fixed.has(t):
			return _fail("Bloque fijo")
		if kind_at(t) == Kind.HEAVY and not perks.has("fuerza_bruta"):
			return _fail("Bloque pesado: no se mueve")
		# La huella de la torre sólo limita dónde se GENERAN bloques: un bloque empujado puede salir de ella (y queda
		# sostenido por sus vecinos o cae al vacío, como siempre). El jugador no se mueve al empujar.
		if blocks.has(dest):
			return _push_row(t, d)
		if kind_at(t) == Kind.ICE:  # el hielo se desliza hasta chocar con algo o hasta salir de la huella
			while in_bounds(dest):
				var n := dest + d
				if blocks.has(n) or n == player:
					break
				dest = n
		_move_block(t, dest)
		return _ok()
	if blocks.has(player - d):
		if fixed.has(player - d):
			return _fail("Bloque fijo")
		if kind_at(player - d) == Kind.HEAVY and not perks.has("fuerza_bruta"):
			return _fail("Bloque pesado: no se mueve")
		if not in_bounds(t):
			return _fail("Borde de la torre")
		if not blocks.has(t + DOWN):
			var h := t + DOWN
			if blocks.has(h + DOWN):  # un escalón más abajo: se baja, como al caminar
				_move_block(player - d, player)
				_set_player(h)
				_arrive(d)
				return _ok()
			# Sin piso atrás no se puede tirar: el bloque tirado quedaría encima del borde del que te agarrarías y no hay
			# borde que agarrar entre dos cubos. Colgarse se hace a propósito (Espacio + dirección), no tirando.
			return _fail("No se puede tirar: no hay piso atrás")
		_move_block(player - d, player)
		_set_player(t)
		_arrive(d)
		return _ok()
	return _fail("Nada que empujar ni tirar")


## Empuja la fila de bloques que empieza en `t` (el de enfrente y los pegados detrás): se mueven todos una celda si la de más allá
## está libre. No vale con bloques fijos o pesados, ni con más de MAX_ROW.
func _push_row(t: Vector3i, d: Vector3i) -> Dictionary:
	var line: Array[Vector3i] = []
	var c := t
	while blocks.has(c):
		if fixed.has(c):
			return _fail("Bloque fijo")
		if kind_at(c) == Kind.HEAVY and not perks.has("fuerza_bruta"):
			return _fail("Bloque pesado: no se mueve")
		line.append(c)
		if line.size() > MAX_ROW:
			return _fail("Hay demasiados bloques para empujar")
		c += d
	for i in range(line.size() - 1, -1, -1):   # primero el último, así ninguno pisa a otro
		_move_block(line[i], line[i] + d)
	return _ok()


## Pasar por encima del borde y quedar colgado del bloque en el que estaba parado.
func _act_hang_over(d: Vector3i) -> Dictionary:
	var t := player + d
	var h := t + DOWN
	if kind_at(player + DOWN) == Kind.ICE and not perks.has("garras_de_hielo"):
		return _fail("Hielo: no hay de dónde agarrarse")
	if not in_hang_reach(t) or blocks.has(t):
		return _fail("No hay borde para colgarse")
	if blocks.has(h) or blocks.has(h + DOWN):
		return _fail("Ahí se puede caminar")
	_set_player(h)
	hang_dir = -d
	return _ok()


func _act_hanging(d: Vector3i) -> Dictionary:
	var w := hang_dir
	if d == w:  # trepar al bloque
		var s := player + w + UP
		if blocks.has(s) or blocks.has(player + UP):
			return _fail("No hay espacio para trepar")
		_set_player(s)
		hang_dir = Vector3i.ZERO
		return _ok()
	if d == -w:  # soltarse
		hang_dir = Vector3i.ZERO
		return _ok()
	# Hacia un costado: avanzar por el borde o doblar una esquina.
	var h2 := player + d
	var g2 := h2 + w
	if not in_hang_reach(h2):
		return _fail("No se puede avanzar por el borde")
	if blocks.has(h2):  # esquina hacia adentro: la pared gira hacia el jugador y se agarra de ella
		if blocks.has(h2 + UP):
			return _fail("No se puede avanzar por el borde")
		if kind_at(h2) == Kind.ICE and not perks.has("garras_de_hielo"):
			return _fail("Hielo: no hay de dónde agarrarse")
		hang_dir = d
		return _ok()
	if blocks.has(g2):  # tramo recto
		if blocks.has(g2 + UP):
			return _fail("No se puede avanzar por el borde")
		if kind_at(g2) == Kind.ICE and not perks.has("garras_de_hielo"):
			return _fail("Hielo: no hay de dónde agarrarse")
		_set_player(h2)
		return _ok()
	# Esquina hacia afuera: el borde del bloque termina; se lo rodea y queda agarrado de su otro lado.
	if in_hang_reach(g2) and not blocks.has(player + w + UP):
		_set_player(g2)
		hang_dir = -d
		return _ok()
	return _fail("No se puede avanzar por el borde")


## Efecto de la celda donde termina un movimiento a pie: resbalar en hielo o salir lanzado de una catapulta.
func _arrive(d: Vector3i) -> void:
	var k := kind_at(player + DOWN)
	if k == Kind.ICE:
		_slide(d)
	elif k == Kind.CATAPULT:
		_launch(d)


func _slide(d: Vector3i) -> void:
	for _i in SLIDE_LIMIT:
		var t := player + d
		if not in_bounds(t) or blocks.has(t):
			return
		if perks.has("ojo_de_hielo") and (not in_bounds(t + d) or blocks.has(t + d)):
			return  # Ojo de hielo: se frena una celda antes del choque
		_set_player(t)
		if kind_at(player + DOWN) != Kind.ICE:  # salió del hielo (o no hay apoyo: cae)
			return


## La catapulta dispara hacia arriba (CATAPULT_RISE celdas, o hasta el techo). Arriba se agarra del lateral de un
## bloque vecino con el borde de arriba libre: primero hacia donde venía, después los costados y por último atrás.
## Si no hay de dónde agarrarse, el jugador vuelve a caer (lo resuelve _settle_player). No avanza nunca hacia los costados.
func _launch(d: Vector3i) -> void:
	var origin := player
	for i in CATAPULT_RISE:
		var cell := player + UP
		if not in_bounds(cell) or blocks.has(cell):
			break  # un techo corta el ascenso
		_set_player(cell)
	if player == origin:
		return  # un techo impide el despegue
	# Se busca el borde más alto al que llega: desde CATAPULT_REACH celdas por encima del punto más alto hacia abajo, hasta la partida.
	var top_y := player.y
	for _i in CATAPULT_REACH:
		var above := Vector3i(player.x, top_y + 1, player.z)
		if not in_bounds(above) or blocks.has(above):
			break
		top_y += 1
	for y in range(top_y, origin.y, -1):
		for g_dir in [d, Vector3i(-d.z, 0, d.x), Vector3i(d.z, 0, -d.x), -d]:
			var g: Vector3i = Vector3i(player.x, y, player.z) + g_dir
			if blocks.has(g) and not blocks.has(g + UP) and kind_at(g) != Kind.ICE:
				while player.y < y:   # (sube un poco más, o baja un poco, hasta ese borde)
					_set_player(player + UP)
				while player.y > y:
					_set_player(player + DOWN)
				hang_dir = g_dir
				return


## ¿El jugador está parado en la meta? (a la altura de la meta y, si hay bloque-portal o bloques-meta, sobre ellos)
func _on_goal() -> bool:
	if player.y < goal_y:
		return false
	var b: int = blocks.get(player + DOWN, -2)
	if goal_block >= 0:
		return b == goal_block
	if not goal_ids.is_empty():
		return goal_ids.has(b)
	return true


func _after_action() -> void:
	moves_made += 1
	if _crack_id >= 0 and positions.has(_crack_id) and player != _crack_from:
		_remove_block(positions[_crack_id])   # el agrietado se rompe al bajarte de él
	_settle()
	_hazards()
	if lost and perks.has("segundo_aliento") and not second_wind_used and lost_reason == "Caíste al vacío" and blocks.has(last_safe + DOWN):
		# Segundo aliento: se vuelve a la última plataforma firme (una vez por etapa).
		lost = false
		lost_reason = ""
		second_wind_used = true
		player = last_safe
		hang_dir = Vector3i.ZERO
		trail.append(last_safe)
		perk_msg = "¡Segundo aliento!"
	if lost:
		return
	if hang_dir == Vector3i.ZERO and blocks.has(player + DOWN):
		last_safe = player
	_purify_trail()
	if not platform_row.is_empty():
		var pr: int = platform_row.get(blocks.get(player + DOWN, -1), 0)
		if pr > reached_row:
			reached_row = pr
	if _on_goal():
		won = true
		return
	_tick_bombs()
	if lost:
		return
	if collapse_pause > 0:  # Freno: la fila de abajo no se acerca
		collapse_pause -= 1
		return
	if perks.has("paso_firme") and _climbed:  # Paso firme: trepar y bajar escalones no cuenta
		return
	moves_to_collapse -= 1
	if moves_to_collapse <= 0:
		moves_to_collapse = collapse_every
		_collapse_bottom()
		_settle()
		_hazards()


## Lo que pasa al quedar parado sobre una trampa (se desarma y se cae con ella) o sobre pinchos (se pierde). Si al caer se aterriza
## sobre otra trampa, se repite.
func _hazards() -> void:
	for _i in 8:
		if lost or hang_dir != Vector3i.ZERO:
			return
		var k := kind_at(player + DOWN)
		if k == Kind.TRAP:
			trap_broke = true
			_remove_block(player + DOWN)
			_settle()
		elif k == Kind.SPIKES:
			lost = true
			lost_reason = "Caíste sobre los pinchos"
			return
		else:
			return


## Multiplicador de claridad para una racha de n acciones.
static func streak_multiplier(n: int) -> float:
	return minf(1.0 + STREAK_STEP * maxi(n - 1, 0), STREAK_MAX_MULT)


## Multiplicador de racha con los boosts del run (Mano de oro: de a 1,0; Racha larga: tope ×6).
func streak_mult(n: int) -> float:
	if perks.has("sin_racha"):   # prueba "Sin racha": el multiplicador no sube
		return 1.0
	var step := 1.0 if perks.has("mano_de_oro") else STREAK_STEP
	var cap := 6.0 if perks.has("racha_larga") else STREAK_MAX_MULT
	return minf(1.0 + step * maxi(n - 1, 0), cap)


## Claridad que da purificar el bloque de la celda.
func clarity_at(c: Vector3i) -> int:
	if fixed.has(c):
		return FIXED_CLARITY
	return CLARITY[kind_at(c)]


## Purifica los bloques sobre los que estuvo el jugador en la última acción (y el del que cuelga).
## Purificar una bomba la desactiva siempre (cambia la dinámica); el resto sólo se lleva la cuenta si track_purify.
func _purify_trail() -> void:
	var cells: Array[Vector3i] = []
	for c in trail:
		cells.append(c + DOWN)
	if hang_dir != Vector3i.ZERO:
		cells.append(player + hang_dir)
	if perks.has("luz_propia"):  # Luz propia: también se purifican los vecinos de lo que pisás
		var extra: Array[Vector3i] = []
		for b in cells:
			for dd in DIRS:
				extra.append(b + dd)
		cells.append_array(extra)
	var seen := {}
	var base := 0
	for b in cells:
		if seen.has(b) or not blocks.has(b):
			continue
		seen[b] = true
		var id: int = blocks[b]
		if bomb_timer.has(id):
			_own_maps()
			bomb_timer.erase(id)  # purificada, una bomba deja de contar
		if not track_purify or purified.has(id):
			continue
		_own_maps()
		purified[id] = true
		last_purified.append(id)
		base += clarity_at(b) + (1 if perks.has("pies_de_luz") else 0)
	if not track_purify:
		return
	if last_purified.is_empty():
		streak = 0
		return
	streak += 1
	best_streak = maxi(best_streak, streak)
	last_gain = int(round(base * streak_mult(streak)))
	claridad += last_gain
	purified_count += last_purified.size()


## Una bomba cuenta sólo cuando el jugador está en su fila; al llegar a 0 explota.
func _tick_bombs() -> void:
	for id in bomb_timer.keys():
		if positions[id].y == player.y:
			_own_maps()
			bomb_timer[id] -= 1
			if bomb_timer[id] <= 0:
				_explode(id)
				return


func _explode(id := -1) -> void:
	exploded = true
	explosion_cell = positions.get(id, player)
	for c in blocks.keys():
		_remove_block(c)
	lost = true
	lost_reason = "Explotó una bomba: la torre se derrumbó"
	_set_player(player + Vector3i(0, -3, 0))


func _collapse_bottom() -> void:
	for c in blocks.keys():
		if c.y == floor_y:
			_remove_block(c)
	floor_y += 1


## Las copias (clone) comparten los diccionarios de bloques hasta que una escribe: la mayoría de las acciones (caminar, trepar, colgarse) no
## cambian ningún bloque y así el solucionador no copia cientos de entradas por cada estado que prueba. Toda escritura pasa antes por acá.
func _own_maps() -> void:
	if _maps_shared:
		blocks = blocks.duplicate()
		positions = positions.duplicate()
		kind_of = kind_of.duplicate()
		bomb_timer = bomb_timer.duplicate()
		purified = purified.duplicate()
		_maps_shared = false


func _own_fixed() -> void:
	if _fixed_shared:
		fixed = fixed.duplicate()
		_fixed_shared = false


func _move_block(from: Vector3i, to: Vector3i) -> void:
	_own_maps()
	_blocks_dirty = true
	var id: int = blocks[from]
	var k: int = kind_of.get(id, 0)
	zob ^= zob_hash(from, k) ^ zob_hash(to, k)
	blocks.erase(from)
	blocks[to] = id
	positions[id] = to


func _remove_block(c: Vector3i) -> void:
	_own_maps()
	_blocks_dirty = true
	var id: int = blocks[c]
	zob ^= zob_hash(c, kind_of.get(id, 0))
	blocks.erase(c)
	if fixed.has(c):
		_own_fixed()
		fixed.erase(c)
	kind_of.erase(id)
	purified.erase(id)
	bomb_timer.erase(id)  # una bomba que cae al vacío queda desactivada
	positions.erase(id)
	removed_ids.append(id)


func _has_neighbor(c: Vector3i) -> bool:
	for n in NEIGHBORS:
		if blocks.has(c + n):
			return true
	for n in EDGE_SUPPORT:
		if blocks.has(c + n):
			return true
	return false


func _settle() -> void:
	var changed := true
	while changed:
		changed = _settle_blocks()
		var before_pos := player
		var before_hang := hang_dir
		_settle_player()
		if player != before_pos or hang_dir != before_hang:
			changed = true


## Bloques sin ningún vecino (ni apoyo por arista) caen hasta tocar algo; si no hay nada, caen al vacío.
func _settle_blocks() -> bool:
	if lazy_settle and not _blocks_dirty:
		return false   # ningún bloque cambió desde que todo estaba firme: no hay nada que revisar (caminar, trepar o colgarse no mueven bloques)
	var moved := false
	var again := true
	var skipped := false   # algún bloque sin vecinos se sostiene sólo por el jugador: hay que volver a mirarlo cuando éste se mueva
	while again:
		again = false
		var cells := blocks.keys()
		cells.sort_custom(func(a, b): return a.y < b.y)
		for c in cells:
			if not blocks.has(c) or fixed.has(c) or _has_neighbor(c) or anchored.has(blocks[c]):
				continue
			var below: Vector3i = c + DOWN
			if below == player:
				skipped = true
				continue  # apoyado sobre el jugador
			if c.y <= floor_y:
				_remove_block(c)
			else:
				_move_block(c, below)
			again = true
			moved = true
	_blocks_dirty = skipped
	return moved


func _settle_player() -> void:
	if lost:
		return
	if hang_dir != Vector3i.ZERO:
		if blocks.has(player + hang_dir):
			return
		hang_dir = Vector3i.ZERO
	while not blocks.has(player + DOWN):
		if player.y <= floor_y:
			lost = true
			lost_reason = "Caíste al vacío"
			_set_player(player + Vector3i(0, -3, 0))
			return
		_set_player(player + DOWN)


# --- boosts y consumibles del run ---------------------------------------------------------------------------------

## Aplica los boosts del run a una torre recién armada (se llama al empezar o reintentar la etapa).
func apply_perks(boost_ids: Array) -> void:
	perks = {}
	for id in boost_ids:
		perks[id] = true
	second_wind_used = false
	collapse_pause = 0
	anchored = {}
	last_safe = player
	var every := collapse_every
	if perks.has("madrugada"):  # la fila de abajo cae al doble de lento
		every *= 2
	if perks.has("aire_extra"):  # y un movimiento más tarde
		every += 1
	if every != collapse_every:
		moves_to_collapse = int(round(float(moves_to_collapse) * every / collapse_every))
		collapse_every = every
	if perks.has("reflejos"):  # las bombas empiezan 3 movimientos más altas
		_own_maps()
		for id in bomb_timer:
			bomb_timer[id] += 3
	if perks.has("ahorro"):  # cada etapa se arranca con 20 de claridad
		claridad += 20


## Cambia el tipo de un bloque (mantiene la huella del estado al día).
func _set_kind(c: Vector3i, kind: int) -> void:
	_own_maps()
	var id: int = blocks[c]
	zob ^= zob_hash(c, kind_of.get(id, 0)) ^ zob_hash(c, kind)
	if kind == Kind.NORMAL:
		kind_of.erase(id)
	else:
		kind_of[id] = kind


## Usa un consumible. Devuelve {ok, msg}. No gasta un movimiento (no acerca la caída de la fila de abajo).
func use_item(id: String) -> Dictionary:
	if won or lost:
		return {"ok": false, "msg": ""}
	match id:
		"freno":
			collapse_pause += 5
			return {"ok": true, "msg": "Freno: la fila de abajo se detiene 5 movimientos"}
		"desarmar":
			var best := -1
			var best_d := 1 << 30
			for bid in bomb_timer:
				var dist: int = (positions[bid] - player).abs().x + (positions[bid] - player).abs().y + (positions[bid] - player).abs().z
				if dist < best_d:
					best_d = dist
					best = bid
			if best < 0:
				return {"ok": false, "msg": "No hay bombas para desarmar"}
			_own_maps()
			bomb_timer.erase(best)
			return {"ok": true, "msg": "Bomba desarmada"}
		"hielo_a_roca":
			var near := Vector3i.ZERO
			var near_d := 1 << 30
			var found := false
			for c in blocks:
				if kind_at(c) != Kind.ICE:
					continue
				var dv: Vector3i = (c - player).abs()
				var dist := dv.x + dv.y + dv.z
				if dist <= 6 and dist < near_d:
					near_d = dist
					near = c
					found = true
			if not found:
				return {"ok": false, "msg": "No hay hielo cerca"}
			_set_kind(near, Kind.NORMAL)
			return {"ok": true, "msg": "El hielo se volvió roca"}
		"catapulta_de_bolsillo":
			var front := player + facing
			if not blocks.has(front) or fixed.has(front):
				return {"ok": false, "msg": "No hay un bloque enfrente"}
			_set_kind(front, Kind.CATAPULT)
			return {"ok": true, "msg": "El bloque de enfrente es ahora una catapulta"}
		"ancla_chica":
			var target := player + facing
			if not blocks.has(target):
				target = player + DOWN
			if not blocks.has(target) or fixed.has(target):
				return {"ok": false, "msg": "No hay un bloque para anclar"}
			anchored[blocks[target]] = true
			return {"ok": true, "msg": "Bloque anclado: no cae en esta etapa"}
	return {"ok": false, "msg": "Consumible desconocido"}


# --- guardado -----------------------------------------------------------------------------------------------------

## Estado de la torre como diccionario serializable (para guardar la partida). Se usa con el estado INICIAL de una torre
## (nada purificado, sin caídas): bloques, tipos, cuentas de bomba, meta, plataformas por fila y parámetros de la caída.
func to_dict() -> Dictionary:
	var blocks_out: Array = []
	for c in blocks:
		var id: int = blocks[c]
		blocks_out.append([c.x, c.y, c.z, id, kind_of.get(id, 0), bomb_timer.get(id, 0), 1 if fixed.has(c) else 0])
	var rp := {}
	for k in row_platforms:
		rp[str(k)] = row_platforms[k]
	return {"size": [size.x, size.y], "goal_y": goal_y, "goal_cell": [goal_cell.x, goal_cell.y, goal_cell.z],
			"goal_block": goal_block, "player": [player.x, player.y, player.z], "floor_y": floor_y,
			"collapse_every": collapse_every, "moves_to_collapse": moves_to_collapse, "next_id": _next_id,
			"blocks": blocks_out, "row_platforms": rp}


## Reconstruye una torre guardada con to_dict.
static func from_dict(d: Dictionary) -> RefCounted:
	var t = load("res://scripts/tower_logic.gd").new()
	t.size = Vector2i(int(d.size[0]), int(d.size[1]))
	t.goal_y = int(d.goal_y)
	t.goal_cell = Vector3i(int(d.goal_cell[0]), int(d.goal_cell[1]), int(d.goal_cell[2]))
	t.goal_block = int(d.goal_block)
	t.player = Vector3i(int(d.player[0]), int(d.player[1]), int(d.player[2]))
	t.floor_y = int(d.floor_y)
	t.collapse_every = int(d.collapse_every)
	t.moves_to_collapse = int(d.moves_to_collapse)
	for b in d.blocks:
		var c := Vector3i(int(b[0]), int(b[1]), int(b[2]))
		var id := int(b[3])
		t.blocks[c] = id
		t.positions[id] = c
		if int(b[4]) != 0:
			t.kind_of[id] = int(b[4])
		if int(t.kind_of.get(id, 0)) == Kind.BOMB:
			t.bomb_timer[id] = int(b[5])
		if int(b[6]) == 1:
			t.fixed[c] = true
	t._next_id = int(d.next_id)
	for k in d.row_platforms:
		var ids: Array = []
		for id in d.row_platforms[k]:
			ids.append(int(id))
		t.row_platforms[int(k)] = ids
		for id in ids:
			t.platform_row[id] = int(k)
	t.recompute_zob()
	return t
