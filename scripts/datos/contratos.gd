extends RefCounted
## Los contratos (docs/plan_casinos.md): tareas para la próxima torre que se cuelgan en el tablón de cada casino, se aceptan gratis (o con fianza en el casino y el gran casino) y se cobran
## en cuanto se cumplen. Este módulo es pura lógica, sin interfaz: el sorteo de papeles, el tablón persistente (`run.contratos`), aceptar, rechazar, rotar, el seguimiento de lo que pasa en la
## torre y el cobro. La pantalla del tablón es scripts/casino/tablon_screen.gd y la de un contrato resuelto, scripts/ui/contrato_resuelto.gd.
##
## Un papel: {id, obj, r (rareza 0 gris/común, 1 azul/raro, 2 violeta/épica, 3 negro/imposible), n (lo que se pide), pct (la recompensa, como fracción de lo que rinde una torre), monto, fianza}.
## `monto` y `fianza` se calculan al aceptarlo, con la etapa de ese casino. `run.contratos`: {cartelera: [papel o null, ...], activos: [papel, ...], iniciada, rotaciones, torre: {...}}.

const Loc := preload("res://scripts/idioma/loc.gd")
const Items := preload("res://scripts/datos/items.gd")
const Roulette := preload("res://scripts/casino/roulette.gd")

enum Rareza { COMUN, RARA, EPICA, IMPOSIBLE }

## Lo que rinde una torre por la ruta mínima, sin boosts (medido con el bot; docs/plan_casinos.md): la unidad de las recompensas y de lo que se pide de claridad.
const INGRESO: Array[int] = [167, 283, 315, 439, 463, 546, 565, 621, 609, 709, 783, 727, 841, 832, 927]
const PCT_RECOMPENSA: Array[float] = [0.10, 0.20, 0.35, 1.00]   # por rareza, si el objetivo no trae las suyas
const NUEVOS_POR_TORRE := 2          # papeles nuevos que aparecen en los huecos de la cartelera en cada visita (la primera la llena)
const LIMITE_BASE := 2               # contratos activos a la vez (el boost Caza recompensas suma uno cada vez)
const FIANZA_FRACCION := 0.5         # la fianza, como fracción de la recompensa
const FIANZA_MULT := 1.5             # lo que paga un contrato con fianza (y se devuelve la fianza)
const ROTAR_FRACCION := 0.5          # cuánto de la ficha cuesta rotar (por (1 + rotaciones de la visita))
const CONTRATISTA_MULT := 2.0
const SELLO_DE_ORO_MULT := 5.0
const FIANZA_DESDE_NIVEL := 2        # las fianzas están en el casino y el gran casino
## Probabilidad de cada rareza al sortear un papel, según el casino (taberna, salón, casino, gran casino).
const PESOS_RAREZA: Array = [[0.75, 0.25, 0.0, 0.0], [0.55, 0.35, 0.10, 0.0], [0.35, 0.35, 0.25, 0.05], [0.20, 0.30, 0.35, 0.15]]

## Los objetivos. `ns`: lo que se pide en cada rareza (null: ese objetivo no existe en esa rareza); `pct`: la recompensa por rareza (opcional); `desde`: la primera etapa en la que puede salir;
## `fin`: sólo se sabe al terminar la torre ("torre"), o se va cumpliendo ("sigue"). `claridad`: lo que se pide son múltiplos de lo que rinde una torre.
const OBJETIVOS := {
	"movimientos": {"icono": "movimientos", "titulo": "Ahorrador de pasos", "condicion": "Termina la torre con el %d %% de los movimientos sin gastar", "ns": [10, 22, 35, 55], "desde": 1, "fin": "torre"},
	"sin_deshacer": {"icono": "deshacer", "titulo": "Sin marcha atrás", "condicion": "Termina la torre sin deshacer ningún movimiento", "ns": [0, 0, null, null], "desde": 1, "fin": "torre"},
	"racha": {"icono": "racha", "titulo": "Racha de oro", "condicion": "Llega a una racha de %d", "ns": [6, 10, 14, 24], "desde": 1, "fin": "sigue"},
	"claridad": {"icono": "claridad", "titulo": "Cosechador", "condicion": "Junta %d de claridad en la torre", "ns": [1.15, 1.5, 2.0, 4.0], "claridad": true, "desde": 1, "fin": "sigue"},
	"especiales": {"icono": "especiales", "titulo": "Cazador de especiales", "condicion": "Purifica %d bloques especiales", "ns": [3, 6, 10, 20], "desde": 3, "fin": "sigue"},
	"sin_empujar": {"icono": "sin_empujar", "titulo": "Manos limpias", "condicion": "Supera %d salas sin empujar ni tirar ningún bloque", "ns": [1, 2, 3, 6], "desde": 2, "fin": "sigue"},
	"sin_vidas": {"icono": "vidas", "titulo": "Intocable", "condicion": "Termina la torre sin perder ninguna vida", "ns": [null, 0, 0, null], "desde": 2, "fin": "torre"},
	"bombas": {"icono": "bomba", "titulo": "Artificiero", "condicion": "Desactiva %d bombas", "ns": [1, 2, 3, 6], "desde": 8, "fin": "sigue"},
	"catapulta": {"icono": "catapulta", "titulo": "Salto de fe", "condicion": "Usa %d veces la catapulta", "ns": [1, 2, 4, 9], "desde": 9, "fin": "sigue"},
}


# ---- el estado -----------------------------------------------------------------------------------------------------------------

static func _estado(run) -> Dictionary:
	if run.contratos.is_empty():
		run.contratos = {"cartelera": [], "activos": [], "iniciada": false, "rotaciones": 0, "torre": _torre_nueva(), "siguiente_id": 1}
	return run.contratos


static func _torre_nueva() -> Dictionary:
	return {"racha_max": 0, "claridad_max": 0, "saltos": 0, "banco_especiales": 0, "banco_bombas": 0, "especiales": 0, "bombas": 0, "salas_limpias": 0,
			"sala_agarro": false, "sobra": 0, "total_mov": 0, "deshizo": false, "perdio_vida": false}


## Cuántos lugares tiene la cartelera de un casino: 3, 4, 5 o 6.
static func capacidad(tier: int) -> int:
	return clampi(tier, 0, 3) + 3


## Cuántos contratos se pueden tener activos a la vez.
static func limite(run) -> int:
	return LIMITE_BASE + run.boosts.count("caza_recompensas")


static func activos(run) -> Array:
	return _estado(run).activos


static func cartelera(run) -> Array:
	return _estado(run).cartelera


## Lo que rinde la torre que viene después del casino de la etapa `stage`.
static func ingreso(stage: int) -> int:
	return INGRESO[clampi(stage + 1, 1, INGRESO.size()) - 1]


## La recompensa de un papel (en claridad) si se acepta en el casino de la etapa `stage`.
static func recompensa(papel: Dictionary, stage: int) -> int:
	return maxi(int(round(float(papel.pct) * float(ingreso(stage)))), 1)


static func fianza(papel: Dictionary, stage: int) -> int:
	return maxi(int(round(float(recompensa(papel, stage)) * FIANZA_FRACCION)), 1)


# ---- el sorteo -----------------------------------------------------------------------------------------------------------------

static func _n_de(def: Dictionary, rareza: int, stage: int) -> int:
	var v = def.ns[rareza]
	if bool(def.get("claridad", false)):
		return maxi(int(round(float(v) * float(ingreso(stage)) / 10.0)) * 10, 10)   # (se pide un número redondo)
	return int(v)


## Sortea un papel nuevo para un casino de ese nivel y etapa. `hay_imposible`: ya hay uno colgado (a lo sumo uno).
static func sortear(run, rng: RandomNumberGenerator, tier: int, hay_imposible := false, evitar: Array = []) -> Dictionary:
	var estado := _estado(run)
	var pesos: Array = PESOS_RAREZA[clampi(tier, 0, 3)]
	var r := 0
	var x := rng.randf()
	var acum := 0.0
	for i in pesos.size():
		acum += float(pesos[i])
		if x <= acum:
			r = i
			break
	if r == Rareza.IMPOSIBLE and hay_imposible:
		r = Rareza.EPICA
	var posibles: Array[String] = []
	for id in OBJETIVOS:
		var def: Dictionary = OBJETIVOS[id]
		if def.ns[r] != null and int(def.desde) <= run.stage + 1:
			posibles.append(id)
	while posibles.is_empty() and r > 0:   # (si esa rareza no tiene objetivos todavía, una más baja)
		r -= 1
		for id in OBJETIVOS:
			var def2: Dictionary = OBJETIVOS[id]
			if def2.ns[r] != null and int(def2.desde) <= run.stage + 1:
				posibles.append(id)
	var distintos: Array[String] = posibles.filter(func(id): return not evitar.has(id))   # (que no cuelguen dos papeles del mismo objetivo si se puede)
	if not distintos.is_empty():
		posibles = distintos
	var obj: String = posibles[rng.randi() % posibles.size()]
	var d: Dictionary = OBJETIVOS[obj]
	var papel := {"id": int(estado.siguiente_id), "obj": obj, "r": r, "n": _n_de(d, r, run.stage), "pct": PCT_RECOMPENSA[r], "monto": 0, "fianza": 0}
	estado.siguiente_id = int(estado.siguiente_id) + 1
	return papel


static func _objetivos_colgados(estado: Dictionary) -> Array:
	var out: Array = []
	for p in estado.cartelera:
		if p != null:
			out.append(str(p.obj))
	return out


static func _hay_imposible(estado: Dictionary) -> bool:
	for p in estado.cartelera:
		if p != null and int(p.r) == Rareza.IMPOSIBLE:
			return true
	return false


## Se entra a un casino de ese nivel: la cartelera se ajusta a su tamaño (los papeles de antes siguen colgados), empieza la cuenta de rotaciones de la visita y aparecen papeles nuevos en los
## huecos (la primera vez se llena entera; después, hasta NUEVOS_POR_TORRE). Devuelve cuántos papeles nuevos hay.
static func entrar(run, rng: RandomNumberGenerator, tier: int) -> int:
	var estado := _estado(run)
	var cap := capacidad(tier)
	while estado.cartelera.size() < cap:
		estado.cartelera.append(null)
	estado.rotaciones = 0
	var huecos: Array[int] = []
	for i in estado.cartelera.size():
		if estado.cartelera[i] == null:
			huecos.append(i)
	var cuantos := huecos.size() if not bool(estado.iniciada) else mini(NUEVOS_POR_TORRE, huecos.size())
	estado.iniciada = true
	for k in cuantos:
		var i: int = huecos[k]
		estado.cartelera[i] = sortear(run, rng, tier, _hay_imposible(estado), _objetivos_colgados(estado))
	return cuantos


# ---- aceptar, rechazar, rotar ---------------------------------------------------------------------------------------------

## ¿Se puede aceptar con fianza? Sólo en el casino y el gran casino.
static func permite_fianza(tier: int) -> bool:
	return tier >= FIANZA_DESDE_NIVEL


## Acepta el papel del lugar `indice`: pasa de la cartelera a los contratos activos. Con fianza se paga ahora y el contrato rinde más. {ok, error}.
static func aceptar(run, indice: int, con_fianza: bool, tier: int) -> Dictionary:
	var estado := _estado(run)
	if indice < 0 or indice >= estado.cartelera.size() or estado.cartelera[indice] == null:
		return {"ok": false, "error": Loc.t("No hay ningún papel ahí")}
	if estado.activos.size() >= limite(run):
		return {"ok": false, "error": Loc.f("Ya tienes %d contratos activos", [estado.activos.size()])}
	var papel: Dictionary = estado.cartelera[indice]
	if con_fianza and not permite_fianza(tier):
		return {"ok": false, "error": Loc.t("Aquí no se acepta fianza")}
	var f := fianza(papel, run.stage) if con_fianza else 0
	if f > 0 and not run.can_afford(f):
		return {"ok": false, "error": Loc.f("No alcanza la claridad (la fianza es %d)", [f])}
	if f > 0:
		run.spend(f)
	papel["monto"] = recompensa(papel, run.stage)
	papel["fianza"] = f
	estado.activos.append(papel)
	estado.cartelera[indice] = null
	return {"ok": true, "error": "", "papel": papel}


## Descuelga un papel (gratis): deja el hueco. {ok, error}.
static func rechazar(run, indice: int) -> Dictionary:
	var estado := _estado(run)
	if indice < 0 or indice >= estado.cartelera.size() or estado.cartelera[indice] == null:
		return {"ok": false, "error": Loc.t("No hay ningún papel ahí")}
	estado.cartelera[indice] = null
	return {"ok": true, "error": ""}


## Cuánto cuesta rotar ahora: la mitad de la ficha por (1 + rotaciones de la visita); la primera es gratis con la Llave de la vitrina.
static func costo_rotar(run) -> int:
	var estado := _estado(run)
	if int(estado.rotaciones) == 0 and run.boosts.has("llave_de_la_vitrina"):
		return 0
	return maxi(int(round(float(Roulette.run_price(run)) * ROTAR_FRACCION * float(1 + int(estado.rotaciones)))), 1)


## Vuelve a sortear todos los papeles colgados (los activos no se tocan). {ok, error, costo}.
static func rotar(run, rng: RandomNumberGenerator, tier: int) -> Dictionary:
	var estado := _estado(run)
	var costo := costo_rotar(run)
	if not run.can_afford(costo):
		return {"ok": false, "error": Loc.f("No alcanza la claridad (rotar cuesta %d)", [costo]), "costo": costo}
	var hay := false
	for p in estado.cartelera:
		hay = hay or p != null
	if not hay:
		return {"ok": false, "error": Loc.t("No hay papeles para rotar"), "costo": 0}
	run.spend(costo)
	estado.rotaciones = int(estado.rotaciones) + 1
	var imposible := false   # (a lo sumo un papel negro colgado)
	var objetivos: Array = []
	for i in estado.cartelera.size():
		if estado.cartelera[i] == null:
			continue
		var nuevo := sortear(run, rng, tier, imposible, objetivos)
		imposible = imposible or int(nuevo.r) == Rareza.IMPOSIBLE
		objetivos.append(str(nuevo.obj))
		estado.cartelera[i] = nuevo
	return {"ok": true, "error": "", "costo": costo}


# ---- lo que pasa en la torre ---------------------------------------------------------------------------------------------------

## Empieza una torre: se reinicia el seguimiento. `capacidad_torre`: {especiales, bombas, catapultas, salas} de lo que tiene esa torre (`capacidad_de`). Los contratos activos que no se pueden
## cumplir en esta torre (piden más bombas de las que hay, por ejemplo) se anulan y se devuelve su fianza. Devuelve los papeles anulados.
static func empezar_torre(run, capacidad_torre := {}) -> Array:
	var estado := _estado(run)
	estado.torre = _torre_nueva()
	var anulados: Array = []
	if capacidad_torre.is_empty():
		return anulados
	for p in estado.activos.duplicate():
		var tope := -1
		match str(p.obj):
			"especiales": tope = int(capacidad_torre.get("especiales", 0))
			"bombas": tope = int(capacidad_torre.get("bombas", 0))
			"catapulta": tope = int(capacidad_torre.get("catapultas", 0))
			"sin_empujar": tope = int(capacidad_torre.get("salas", 0))
		if tope >= 0 and int(p.n) > tope:
			estado.activos.erase(p)
			if int(p.fianza) > 0:
				run.gain(int(p.fianza))
			anulados.append(p)
	return anulados


## Lo que tiene una torre de lo que piden los contratos: cuántos bloques especiales, bombas y catapultas y cuántas salas (`t` es un Torre).
static func capacidad_de(t) -> Dictionary:
	var cap := {"especiales": 0, "bombas": 0, "catapultas": 0, "salas": t.salas.size()}
	for sala in t.salas:
		for b in sala.d.bloques:
			var l := str(b[3])
			var c := l.substr(0, 1)
			if c == "n" or c == "p" or c == "f":
				continue
			cap.especiales = int(cap.especiales) + 1
			if c == "b" or c == "d":
				cap.bombas = int(cap.bombas) + 1
			elif c == "k":
				cap.catapultas = int(cap.catapultas) + 1
	return cap


## Algo pasó en la torre. `evento`: "accion" ({racha, claridad, salto, agarro, especiales, bombas}: lo de la acción y lo que hay purificado en la sala), "sala" ({movs, max_mov, especiales, bombas}:
## se superó una sala), "sala_perdida", "vida" (se perdió una vida), "deshacer" o "torre" (se terminó). Devuelve las resoluciones que provocó: [{papel, cumplido, monto}] y las saca de los activos.
static func registrar(run, evento: String, d := {}) -> Array:
	var estado := _estado(run)
	if estado.torre.is_empty():   # (un guardado a medias, o una prueba)
		estado.torre = _torre_nueva()
	var s: Dictionary = estado.torre
	match evento:
		"accion":
			s.racha_max = maxi(int(s.racha_max), int(d.get("racha", 0)))
			s.claridad_max = maxi(int(s.claridad_max), int(d.get("claridad", 0)))
			if bool(d.get("salto", false)):
				s.saltos = int(s.saltos) + 1
			if bool(d.get("agarro", false)):
				s.sala_agarro = true
			s.especiales = maxi(int(s.especiales), int(s.banco_especiales) + int(d.get("especiales", 0)))
			s.bombas = maxi(int(s.bombas), int(s.banco_bombas) + int(d.get("bombas", 0)))
		"sala":
			s.banco_especiales = int(s.banco_especiales) + int(d.get("especiales", 0))
			s.banco_bombas = int(s.banco_bombas) + int(d.get("bombas", 0))
			s.especiales = maxi(int(s.especiales), int(s.banco_especiales))
			s.bombas = maxi(int(s.bombas), int(s.banco_bombas))
			if not bool(s.sala_agarro):
				s.salas_limpias = int(s.salas_limpias) + 1
			s.sala_agarro = false
			s.sobra = int(s.sobra) + maxi(int(d.get("max_mov", 0)) - int(d.get("movs", 0)), 0)
			s.total_mov = int(s.total_mov) + int(d.get("max_mov", 0))
		"sala_perdida":
			s.sala_agarro = false
		"vida":
			s.perdio_vida = true
			s.sala_agarro = false
		"deshacer":
			s.deshizo = true
	return _evaluar(run, evento == "torre")


static func _evaluar(run, fin: bool) -> Array:
	var estado := _estado(run)
	var s: Dictionary = estado.torre
	var out: Array = []
	for p in estado.activos.duplicate():
		var veredicto := _veredicto(p, s, fin)
		if veredicto == 0:
			continue
		estado.activos.erase(p)
		out.append(_resolver(run, p, veredicto > 0))
	return out


## 1: cumplido; -1: fallido; 0: todavía no se sabe.
static func _veredicto(p: Dictionary, s: Dictionary, fin: bool) -> int:
	var n := int(p.n)
	match str(p.obj):
		"movimientos":
			if fin:
				return 1 if int(s.total_mov) > 0 and int(s.sobra) * 100 >= n * int(s.total_mov) else -1
		"sin_deshacer":
			if bool(s.deshizo):
				return -1
			return 1 if fin else 0
		"sin_vidas":
			if bool(s.perdio_vida):
				return -1
			return 1 if fin else 0
		"racha":
			if int(s.racha_max) >= n:
				return 1
		"claridad":
			if int(s.claridad_max) >= n:
				return 1
		"especiales":
			if int(s.especiales) >= n:
				return 1
		"bombas":
			if int(s.bombas) >= n:
				return 1
		"catapulta":
			if int(s.saltos) >= n:
				return 1
		"sin_empujar":
			if int(s.salas_limpias) >= n:
				return 1
	return -1 if fin else 0


## Cobra (o pierde) un contrato. Devuelve {papel, cumplido, monto}: `monto` es lo que se cobró (positivo), la fianza perdida (negativa) o 0.
static func _resolver(run, p: Dictionary, cumplido: bool) -> Dictionary:
	if not cumplido:
		return {"papel": p, "cumplido": false, "monto": -int(p.fianza)}
	var mult := FIANZA_MULT if int(p.fianza) > 0 else 1.0
	if run.boosts.has("contratista"):
		mult *= CONTRATISTA_MULT
	if run.sello_oro:
		mult *= SELLO_DE_ORO_MULT
		run.sello_oro = false
	var pago := int(round(float(p.monto) * mult)) + int(p.fianza)
	run.gain(pago)
	return {"papel": p, "cumplido": true, "monto": pago}


# ---- los textos -----------------------------------------------------------------------------------------------------------------

static func titulo(papel: Dictionary) -> String:
	return Loc.t(str(OBJETIVOS[papel.obj].titulo))


## La condición de un papel, con su número ya puesto.
static func condicion(papel: Dictionary) -> String:
	var plantilla: String = OBJETIVOS[papel.obj].condicion
	return Loc.f(plantilla, [int(papel.n)]) if plantilla.contains("%d") else Loc.t(plantilla)


## Los íconos de los contratos activos para el menú de pausa: [{objetivo, rareza}].
static func para_pausa(run) -> Array:
	var out: Array = []
	for p in activos(run):
		out.append({"objetivo": str(OBJETIVOS[p.obj].icono), "rareza": int(p.r)})
	return out
