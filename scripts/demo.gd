extends RefCounted
## La demo de Steam: el mismo código del juego completo con un interruptor. No es una copia ni una rama larga: `Demo.on()` es verdadero en la compilación "Demo" (la
## característica personalizada `demo` del preset de exportación) o con la variable de entorno GAME_DEMO=1 (para probarla en el editor). Sin el interruptor, el juego
## completo se comporta exactamente igual que siempre. Todo recorte de la demo pasa por acá; lo que la demo esconde sigue existiendo en el código, sólo no se puede abrir.
##
## Qué es la demo (docs/plan_demo.md): el tutorial y La Pesadilla hasta el segundo casino (LAST_STAGE etapas); los demás escenarios dicen "Próximamente"; las habilidades
## persistentes, el blackjack y las tragamonedas dicen "Disponible en la versión completa"; de cosméticos sólo 2 gorros, 2 prendas y 4 personajes. Al pagarle (o fallarle) a
## Farolín del segundo casino se muestra la pantalla de fin de la demo.

const Loc := preload("res://scripts/loc.gd")

const LAST_STAGE := 2   # la demo llega hasta el casino de esta etapa
const SCENARIOS: Array[String] = ["pesadilla"]   # (y el tutorial)
const CHARACTERS: Array[String] = ["dante", "gaby", "gato", "perro"]
const HATS: Array[String] = ["corona", "gorro_lana"]
const OUTFITS: Array[String] = ["remera", "capa"]
const WISHLIST_URL := "https://store.steampowered.com/"   # (la dirección de la página del juego en Steam: se completa al publicarla)
const TITLE := "Balatro x Catherine — Demo"

## Las pruebas lo cambian: 1 = demo, 0 = juego completo, -1 = lo que diga el entorno.
static var forced := -1


static func on() -> bool:
	if forced >= 0:
		return forced == 1
	return OS.has_feature("demo") or OS.get_environment("GAME_DEMO") == "1"


## "Próximamente" (escenarios) y "Disponible en la versión completa" (habilidades, cosméticos, juegos del casino).
static func soon_text() -> String:
	return Loc.t("Próximamente")


static func full_text() -> String:
	return Loc.t("Disponible en la versión completa")


static func casino_text() -> String:
	return Loc.t("Disponible en el juego completo")


## ¿Se puede jugar este escenario? (el tutorial siempre)
static func scenario_allowed(id: String) -> bool:
	return not on() or id == "tutorial" or SCENARIOS.has(id)


static func character_allowed(id: String) -> bool:
	return not on() or CHARACTERS.has(id)


static func cosmetic_allowed(id: String) -> bool:
	return not on() or id == "" or HATS.has(id) or OUTFITS.has(id)


## Cuántas etapas dice que tiene el run en la pantalla (la demo, 2; el juego, las de siempre).
static func shown_final(full: int) -> int:
	return LAST_STAGE if on() else full


## ¿Es el casino que cierra la demo?
static func is_last_casino(stage: int) -> bool:
	return on() and stage >= LAST_STAGE


## La carpeta de guardado: la demo no pisa los guardados del juego completo.
static func save_dir() -> String:
	return "user://demo" if on() else "user://"
