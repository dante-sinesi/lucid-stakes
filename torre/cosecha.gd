extends RefCounted
## La claridad de la torre: valor por bloque, racha, multiplicador y boosts de cosecha.
## Pisar un bloque (o colgarse de él) lo purifica y da su claridad por la racha; una acción que no purifica nada nuevo corta la racha.
## La claridad que se junta en una sala se asegura al llegar a su checkpoint: si se muere, se pierde la de ese intento (y la racha) y la sala empieza de nuevo.

## Multiplicador global de la claridad de la torre (balance: con 2,25 el bot de habilidad media gana el 4 % de los runs; el bot lo prueba con la variable CLARIDAD de tests/sondas/bot_runs.gd; 1,0 = las reglas tal cual).
static var mult_global := 2.25

const STREAK_STEP := 0.5
const STREAK_MAX_MULT := 4.0
const CLIMB_BONUS := 2   # Escalador: claridad por cada piso nuevo
const PUSH_BONUS := 1    # Empuje rentable: claridad por cada bloque que se empuja o tira
## Claridad que da purificar cada tipo de bloque (la letra del bloque en el motor).
const CLARIDAD := {"n": 1, "i": 2, "d": 5, "k": 3, "c": 2, "h": 2, "t": 2, "s": 3, "p": 1, "f": 1}

var perks := {}              # boosts del run: id -> true
var banco := 0               # claridad asegurada (salas ya superadas)
var sala := 0                # claridad de la sala actual (se pierde si se muere)
var streak := 0
var best_streak := 0
var purificados := 0
var last_gain := 0
var harvest_potion := false
var max_piso := 0


func claridad() -> int:
	return banco + sala


func aplicar_boosts(ids: Array) -> void:
	perks = {}
	for id in ids:
		perks[id] = true
	if perks.has("ahorro"):
		banco += 20
	if perks.has("bolsillo_de_luz"):
		banco += 60


## Cuánto multiplica la cosecha: Cosecha doble (x2), Cosecha (x1,5) y la Poción de cosecha (x2).
func harvest_mult() -> float:
	var m := 1.0
	if perks.has("cosecha_doble"):
		m *= 2.0
	if perks.has("cosecha"):
		m *= 1.5
	if harvest_potion:
		m *= 2.0
	return m


## Multiplicador de racha con los boosts (Mano de oro: de a 1,0; Racha larga: tope x6; Racha imparable: x8).
func streak_mult(n: int) -> float:
	if perks.has("sin_racha"):
		return 1.0
	var step := 1.0 if perks.has("mano_de_oro") else STREAK_STEP
	var cap := 8.0 if perks.has("racha_imparable") else (6.0 if perks.has("racha_larga") else STREAK_MAX_MULT)
	return minf(1.0 + step * maxi(n - 1, 0), cap)


## Claridad de más por cada bloque purificado: Pies de luz +1, Pies de oro +2, Midas +3 (suman).
func flat_por_bloque() -> int:
	return (1 if perks.has("pies_de_luz") else 0) + (2 if perks.has("pies_de_oro") else 0) + (3 if perks.has("midas") else 0)


## Lo que da purificar un bloque de esa letra, con Buen ojo (los especiales dan el doble) y lo que se suma por bloque.
func claridad_de(letra: String) -> int:
	var l := letra.substr(0, 1)
	if l == "b":
		l = "d"   # (la bomba que se pisa queda desactivada: vale lo que una bomba)
	var base: int = CLARIDAD.get(l, 1)
	if perks.has("buen_ojo") and l != "n" and l != "p" and l != "f":
		base *= 2
	return base + flat_por_bloque()


func _ganar(n: float) -> int:
	var g := int(round(n * harvest_mult() * mult_global))
	sala += g
	last_gain += g
	return g


## Después de cada acción que salió bien. `nuevos`: las letras de los bloques que se purificaron en esta acción; `agarro`: se empujó o tiró de un bloque;
## `piso`: el piso (altura en la torre) donde quedó el jugador.
func despues_de_accion(nuevos: Array, agarro: bool, piso: int) -> int:
	last_gain = 0
	var ganado := 0
	if nuevos.is_empty():
		if not (perks.has("racha_imparable") and agarro):
			streak = 0
	else:
		streak += 1
		best_streak = maxi(best_streak, streak)
		purificados += nuevos.size()
		var base := 0
		for l in nuevos:
			base += claridad_de(str(l))
		ganado += _ganar(float(base) * streak_mult(streak))
	if perks.has("escalador") and piso > max_piso and max_piso > 0:
		ganado += _ganar(float((piso - max_piso) * CLIMB_BONUS))
	if perks.has("empuje_rentable") and agarro:
		ganado += _ganar(float(PUSH_BONUS))
	max_piso = maxi(max_piso, piso)
	return ganado


## Un consumible que purifica de golpe (Imán de luz, Lluvia de luz): da la claridad con la racha (no la corta si no purifica nada).
func extra(letras: Array) -> int:
	if letras.is_empty():
		return 0
	streak += 1
	best_streak = maxi(best_streak, streak)
	purificados += letras.size()
	var base := 0
	for l in letras:
		base += claridad_de(str(l))
	return _ganar(float(base) * streak_mult(streak))


## Lo que se junta cambia con cada acción: una foto para deshacer (la poción de cosecha no se deshace: se gastó).
func estado() -> Dictionary:
	return {"sala": sala, "banco": banco, "streak": streak, "best_streak": best_streak, "purificados": purificados, "last_gain": last_gain, "max_piso": max_piso}


func restaurar(e: Dictionary) -> void:
	sala = int(e.sala)
	banco = int(e.banco)
	streak = int(e.streak)
	best_streak = int(e.best_streak)
	purificados = int(e.purificados)
	last_gain = int(e.last_gain)
	max_piso = int(e.max_piso)


## Llegó al checkpoint: la claridad de la sala queda asegurada.
func asegurar() -> void:
	banco += sala
	sala = 0


## Murió: se pierde la claridad de este intento y la racha.
func perder_intento() -> void:
	sala = 0
	streak = 0
	max_piso = 0
