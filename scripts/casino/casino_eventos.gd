extends RefCounted
## Eventos aleatorios del casino (docs/pruebas.md, "Eventos aleatorios del casino"): a veces, al entrar a un casino, pasa algo, lo cuenta un personaje y cambia esa visita. Salen sólo en el casino y en el
## gran casino (los que tienen más mesas), de vez en cuando y nunca en el tutorial, el entrenamiento ni la demo. Siempre se anuncian con un diálogo. Dos eventos:
## - **Casino torcido** (el tabernero): "Tuvimos unos desperfectos..." Esa visita sólo se puede jugar a una mesa (ruleta, tragamonedas o blackjack); las otras quedan cerradas.
## - **Peaje por adelantado** (Farolín): "Tengo unas deudas..." Cobra ya el peaje de la etapa, antes de jugar; al salir lo descuenta y te devuelve una parte (10 %) por la confianza. Sólo si la claridad alcanza.
## El evento de cada etapa se sortea una vez y queda en `run.casino_evento` ({stage, id, solo}; id "" = esa etapa no tuvo), que se guarda con la partida: volver a entrar al mismo casino o cargar no lo cambia.
## El adelanto pagado vive en `run.toll_adelanto`.

const Loc := preload("res://scripts/idioma/loc.gd")
const Demo := preload("res://scripts/datos/demo.gd")

const TORCIDO := "torcido"
const ADELANTO := "peaje_adelantado"
const PROBABILIDAD := 0.3         # de las visitas a un casino con eventos, en cuántas pasa algo
const DEVOLUCION := 0.10          # lo que devuelve Farolín del adelanto al saldar la cuenta
const JUEGOS: Array[String] = ["ruleta", "tragamonedas", "blackjack"]
const DESDE_NIVEL := 2            # el casino (2) y el gran casino (3)

## Cómo se nombra cada mesa en lo que dice el tabernero.
const MESAS := {"ruleta": "la ruleta", "tragamonedas": "las tragamonedas", "blackjack": "el blackjack"}


## El evento de esta visita ({} si no hay). Lo sortea la primera vez que se entra al casino de la etapa y lo recuerda. `precio`: lo que cobra Farolín de salida (0: no cobra).
## `nuevo` es true la primera vez (cuando hay que anunciarlo y cobrar el adelanto).
static func al_entrar(run, rng: RandomNumberGenerator, nivel: int, precio: int) -> Dictionary:
	var previo = run.get("casino_evento")
	if previo is Dictionary and int(previo.get("stage", -1)) == run.stage:
		var ev: Dictionary = (previo as Dictionary).duplicate()
		ev["nuevo"] = false
		return {} if str(ev.get("id", "")) == "" else ev
	var ev := {"stage": run.stage, "id": "", "solo": ""}
	if nivel >= DESDE_NIVEL and not Demo.on() and rng.randf() < PROBABILIDAD:
		var adelanto_posible: bool = precio > 0 and run.claridad >= precio
		if adelanto_posible and rng.randf() < 0.5:
			ev["id"] = ADELANTO
		else:
			ev["id"] = TORCIDO
			ev["solo"] = JUEGOS[rng.randi() % JUEGOS.size()]
	run.casino_evento = ev.duplicate()
	if str(ev.id) == "":
		return {}
	ev["nuevo"] = true
	return ev


## ¿Hay un casino torcido en el que esta mesa ("ruleta", "tragamonedas" o "blackjack") esté cerrada?
static func cerrada(run, juego: String) -> bool:
	var ev = run.get("casino_evento")
	return ev is Dictionary and str(ev.get("id", "")) == TORCIDO and int(ev.get("stage", -1)) == run.stage and str(ev.get("solo", "")) != juego


## Lo que se hace al anunciar un evento nuevo: el peaje por adelantado se cobra en el acto. Devuelve lo que se cobró.
static func aplicar_entrada(run, ev: Dictionary, precio: int) -> int:
	if str(ev.get("id", "")) != ADELANTO or run.toll_adelanto > 0:
		return 0
	var cobrado: int = mini(precio, run.claridad)
	run.spend(cobrado)
	run.toll_adelanto = cobrado
	return cobrado


## Lo que devuelve Farolín al saldar la cuenta: lo que sobró del adelanto (si el peaje bajó) y el 10 % por la confianza.
static func devolucion(adelanto: int, precio_final: int) -> int:
	return maxi(adelanto - precio_final, 0) + int(round(float(adelanto) * DEVOLUCION))


## Quién habla y qué dice al anunciar el evento: {speaker, lines}. `cobrado`: lo que ya se cobró (adelanto).
static func anuncio(ev: Dictionary, cobrado: int, speaker_tabernero: String, speaker_farolin: String) -> Dictionary:
	if str(ev.get("id", "")) == ADELANTO:
		return {"speaker": speaker_farolin, "lines": [
			Loc.t("Eh... tengo unas deudas, ¿sabes? Voy a necesitar que me des un adelanto."),
			Loc.f("Te cobro ya los %d del peaje. Cuando salgas te lo descuento y, por la confianza, te devuelvo un poquito.", [cobrado])]}
	return {"speaker": speaker_tabernero, "lines": [
		Loc.t("Tuvimos unos desperfectos en las mesas, perdona..."),
		Loc.t(_SOLO[str(ev.get("solo", "ruleta"))])]}


## Lo que dice el tabernero si le hablas durante un casino torcido (se suma a lo de siempre).
static func recordatorio(run) -> Array:
	var ev = run.get("casino_evento")
	if not (ev is Dictionary) or str(ev.get("id", "")) != TORCIDO or int(ev.get("stage", -1)) != run.stage:
		return []
	return [Loc.t(_SOLO[str(ev.get("solo", "ruleta"))])]


const _SOLO := {
	"ruleta": "Esta noche solo se puede jugar a la ruleta. Las demás mesas quedan cerradas.",
	"tragamonedas": "Esta noche solo se puede jugar a las tragamonedas. Las demás mesas quedan cerradas.",
	"blackjack": "Esta noche solo se puede jugar al blackjack. Las demás mesas quedan cerradas.",
}
