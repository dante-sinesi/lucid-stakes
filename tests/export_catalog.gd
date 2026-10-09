extends SceneTree
## Escribe el catálogo del juego en archivos de texto (docs/catalogo/*.md) a partir de los datos reales del código: escenarios, pruebas,
## habilidades persistentes, boosts y consumibles, casinos, personajes y cosméticos y bloques. Sirve para revisarlo y editarlo en texto: después
## se le pide a Claude que lea esos archivos y pase los cambios al código.
## Ejecutar: tools/Godot_v4.7.2-stable_win64_console.exe --headless --path . -s tests/export_catalog.gd
## No pisa archivos que ya existen (pueden tener cambios hechos a mano): para regenerarlos, CATALOG_FORCE=1.

const Scenarios := preload("res://scripts/scenarios.gd")
const Trials := preload("res://scripts/trials.gd")
const Abilities := preload("res://scripts/abilities.gd")
const Items := preload("res://scripts/items.gd")
const Roulette := preload("res://scripts/roulette.gd")
const Slots := preload("res://scripts/slots.gd")
const Blackjack := preload("res://scripts/blackjack.gd")
const DiceGame := preload("res://scripts/dice_game.gd")
const CasinoRules := preload("res://scripts/casino_rules.gd")
const CasinoServices := preload("res://scripts/casino_services.gd")
const Room := preload("res://scripts/casino_room.gd")
const Characters := preload("res://scripts/characters.gd")
const Cosmetics := preload("res://scripts/cosmetics.gd")
const TowerLogic := preload("res://scripts/tower_logic.gd")
const TowerGen := preload("res://scripts/tower_gen.gd")
const RunState := preload("res://scripts/run_state.gd")
const Profile := preload("res://scripts/profile.gd")

const DIR := "res://docs/catalogo/"
const KIND_NAMES := ["normal", "hielo", "bomba", "catapulta", "agrietado", "pesado", "trampa", "pinchos"]
const TIER_NAMES := {Items.Tier.CONSUMIBLE: "consumible (barato)", Items.Tier.COMUN: "común", Items.Tier.RARO: "raro", Items.Tier.EPICO: "épico"}
const TYPE_NAMES := {Items.Type.BOOST: "boost", Items.Type.CONSUMABLE: "consumible", Items.Type.CLARITY: "bolsa de claridad"}


func _init() -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(DIR))
	_write("escenarios.md", _scenarios())
	_write("pruebas.md", _trials())
	_write("habilidades_persistentes.md", _abilities())
	_write("boosts_y_consumibles.md", _items())
	_write("casinos.md", _casinos())
	_write("personajes_y_cosmeticos.md", _characters())
	_write("bloques.md", _blocks())
	print("catálogo escrito en ", DIR)
	quit()


func _write(file: String, text: String) -> void:
	if FileAccess.file_exists(DIR + file) and OS.get_environment("CATALOG_FORCE") != "1":
		print("  ", file, ": ya existe (puede tener cambios tuyos); no se pisa. Con CATALOG_FORCE=1 se vuelve a escribir.")
		return
	var f := FileAccess.open(DIR + file, FileAccess.WRITE)
	f.store_string(text.strip_edges() + "\n")
	print("  ", file, " (", text.length(), " caracteres)")


## Una entrada: "## id - Nombre" y una línea "- clave: valor" por campo.
func _entry(title: String, fields: Array) -> String:
	var out := "## %s\n" % title
	for f in fields:
		out += "- %s: %s\n" % [f[0], str(f[1])]
	return out + "\n"


func _list(a: Array) -> String:
	return ", ".join(a.map(func(x): return str(x)))


func _bias_text(b: Dictionary) -> String:
	if b.is_empty():
		return "(ninguno)"
	var parts: Array[String] = []
	for k in b.get("kinds", {}):
		parts.append("%s +%s" % [KIND_NAMES[int(k)], str(b.kinds[k])])
	if float(b.get("plat_ice", 0.0)) > 0.0:
		parts.append("plataformas con hielo %s" % str(b.plat_ice))
	if int(b.get("cap_bonus", 0)) > 0:
		parts.append("tope de especiales +%d" % int(b.cap_bonus))
	return ", ".join(parts)


func _scenarios() -> String:
	var t := "# Escenarios\n\n"
	t += "Los escenarios son como los mazos de Balatro: cada uno cambia las reglas de la partida. La Pesadilla es gratis; los demás cuestan Luz *por partida*. "
	t += "Al **escapar de la pesadilla** (terminar las 27 etapas) en un escenario se gana una de sus habilidades persistentes (una por vez, al azar, entre las que todavía no tenés); cuando ya las tenés todas se da Luz (%d × multiplicador del escenario).\n\n" % Profile.ABILITY_LUZ
	t += "Campos: `entrada` = Luz que cuesta jugarlo · `multiplicador_luz` = cuánto más Luz paga al terminar · `pruebas` = ids del sorteo de pruebas (ver pruebas.md) · `habilidades` = ids de habilidades que se pueden ganar (ver habilidades_persistentes.md) · `ritmo` = ritmo de caída fijo (vacío = el de cada etapa) · `dificultad_extra` = se suma a la dificultad de las torres · `casino` = nivel de sala desde la etapa 1 (-1 = el de cada etapa) · `precio_ficha` = multiplicador del precio de la ficha · `sesgo` = bloques que abundan.\n\n"
	for s in [Scenarios.TUTORIAL] + Scenarios.ALL:
		if s.id == "tutorial":
			continue
		t += _entry("%s - %s" % [s.id, s.name], [
			["descripción", s.desc], ["entrada", s.entry], ["multiplicador_luz", s.luz_mult],
			["pruebas", _list(s.pool)], ["habilidades", _list(Scenarios.ability_ids(s))],
			["ritmo", s.get("pace", "")], ["dificultad_extra", s.get("diff_offset", 0.0)], ["casino", s.get("casino_tier", -1)],
			["precio_ficha", s.get("price_mult", 1.0)], ["sesgo", _bias_text(s.get("bias", {}))]])
	return t


func _trials() -> String:
	var t := "# Pruebas\n\n"
	t += "Las pruebas son etapas especiales (como los jefes de Balatro): caen en las etapas %s. Al empezar cada partida se sortea cuál toca en cada una (del sorteo del escenario, sin repetir la misma dos veces seguidas) y se ve desde el principio. " % _list(Trials.stages())
	t += "Cada prueba cambia una regla de la torre, paga más claridad (×1,5 la primera hasta ×2,7 la última: `1,5 + 0,15 × número de prueba`) y al superarla regala un boost raro (épico en las últimas). **No dan habilidades persistentes** (esas se ganan por escenario).\n\n"
	t += "Reglas posibles: `niebla` (sólo se ven %d pisos por encima), `oscuridad` (sólo los bloques a %s celdas), `ritmo` (ritmo de caída fijo), `sin_consumibles`, `sin_reintentos`, `sin_racha`, `sesgo` (bloques que abundan en la torre).\n\n" % [Trials.FOG_ABOVE, str(Trials.DARK_RADIUS)]
	for id in Trials.CATALOG:
		var tr: Dictionary = Trials.CATALOG[id]
		t += _entry("%s - %s" % [id, tr.name], [
			["descripción", tr.desc], ["niebla", tr.get("fog", false)], ["oscuridad", tr.get("dark", false)], ["ritmo", tr.get("pace", "")],
			["sin_consumibles", tr.get("no_items", false)], ["sin_reintentos", tr.get("no_retry", false)], ["sin_racha", tr.get("no_streak", false)],
			["sesgo", _bias_text(tr.get("bias", {}))]])
	return t


func _abilities() -> String:
	var t := "# Habilidades persistentes\n\n"
	t += "Mejoras que se conservan para siempre y valen en todos los escenarios. No se compran ni se ganan con las pruebas: se ganan al escapar de la pesadilla en el escenario que las tiene. "
	t += "`efecto_en_torre` es el boost equivalente que se aplica en la torre (ver boosts_y_consumibles.md); si está vacío, la habilidad actúa sobre el run (claridad inicial, lugares de consumibles, precio de reintentos...). Los números exactos viven en el código: si querés cambiarlos, indicá el valor nuevo en la descripción.\n\n"
	for a in Abilities.ALL:
		var where: Array[String] = []
		for s in Scenarios.scenarios_for_ability(a.id):
			where.append(s.id)
		t += _entry("%s - %s" % [a.id, a.name], [["descripción", a.desc], ["efecto_en_torre", a.get("perk", "")], ["escenarios", _list(where)]])
	return t


func _items() -> String:
	var t := "# Boosts y consumibles\n\n"
	t += "Son los premios del casino. **Boosts**: mejoras que duran el run (hay %d lugares, algunos boosts suman más). **Consumibles**: se gastan (%d lugares). **Bolsas de claridad**: devuelven claridad. " % [RunState.BASE_BOOSTS, RunState.BASE_CONSUMABLES]
	t += "`nivel` es el nivel de apuesta de la ruleta que lo da (cuanto más difícil la apuesta, mejor el nivel); `peso` = probabilidad relativa dentro de su nivel; `valor` = valor en claridad para una ficha de 50 (sirve para balancear la ruleta, vender en el taller y convertir cuando no hay lugar); `se_acumula` = se puede tener más de uno; `mult` = (bolsas) veces lo que costó la ficha.\n\n"
	for tier in [Items.Tier.EPICO, Items.Tier.RARO, Items.Tier.COMUN, Items.Tier.CONSUMIBLE]:
		t += "# Nivel %s\n\n" % TIER_NAMES[tier]
		for it in Items.ALL:
			if it.tier != tier:
				continue
			var fields := [["nombre", it.name], ["tipo", TYPE_NAMES[it.type]], ["descripción", it.desc], ["peso", it.weight]]
			if it.has("value"):
				fields.append(["valor", it.value])
			if it.has("mult"):
				fields.append(["mult", it.mult])
			if it.get("stack", false):
				fields.append(["se_acumula", true])
			if it.get("locked", false):
				fields.append(["bloqueado_hasta_desbloquear", true])
			t += _entry(it.id, fields)
	return t


func _casinos() -> String:
	var t := "# Casinos\n\n"
	t += "Entre torre y torre se pasa por un casino. Hay cuatro niveles de sala según la etapa (o fijo, con el escenario Gran Casino): **Taberna** (etapas 1-6), **Salón** (7-13), **Casino** (14-20) y **Gran casino** (21-27). Cada nivel tiene una **regla de la casa** (cambia cómo pagan los juegos) y, salvo la taberna, un **servicio** (una estación que no es un juego). Al salir se ve el balance de la visita.\n\n"
	t += "# Salas\n\n"
	for tier in 4:
		var lay := Room.layout([1, 7, 14, 21][tier])
		var st: String = str(lay.station.id) if lay.has("station") else "(ninguno)"
		t += _entry("%d - %s" % [tier, CasinoRules.ROOM_NAMES[tier]], [
			["etapas", ["1 a 6", "7 a 13", "14 a 20", "21 a 27"][tier]], ["tamaño_celdas", "%d x %d" % [lay.cells.x, lay.cells.y]],
			["tragamonedas", lay.machines.size()], ["mesas_de_cartas", lay.card_tables.size()], ["servicio", st],
			["regla", CasinoRules.RULES[tier].id]])
	t += "# Reglas de la casa\n\n"
	t += "Constantes: devolución del fiado %s · extra de racha %s por victoria seguida (hasta %d pasos) · fichas que se pueden apostar con Apuesta libre: %s · parte de lo perdido que va al pozo del jackpot: %s.\n\n" % [str(CasinoRules.FIADO_REFUND), str(CasinoRules.STREAK_STEP), CasinoRules.STREAK_MAX, _list(CasinoRules.STAKES), str(CasinoRules.POOL_SHARE)]
	for r in CasinoRules.RULES:
		t += _entry("%s - %s" % [r.id, r.name], [["descripción", r.desc]])
	t += "# Servicios\n\n"
	t += "Constantes: el taller paga %s del valor de un ítem y cambiar cuesta %s de la ficha · la caja fuerte da %s de interés por casino · el seguro cuesta %s de lo que costaría ese primer reintento.\n\n" % [str(CasinoServices.SELL_FRACTION), str(CasinoServices.SWAP_FRACTION), str(CasinoServices.VAULT_INTEREST), str(CasinoServices.INSURANCE_FRACTION)]
	for id in CasinoServices.INFO:
		t += _entry("%s - %s" % [id, CasinoServices.INFO[id].name], [["descripción", CasinoServices.INFO[id].desc]])
	t += "# Ruleta\n\n"
	t += "13 casillas (la 0 es de la casa). Ficha: %d en la etapa 1 y +%d por etapa. Cada apuesta cubre una cantidad de casillas y da premios de un nivel (ver boosts_y_consumibles.md).\n\n" % [Roulette.BASE_PRICE, Roulette.PRICE_STEP]
	for b in Roulette.BETS:
		t += _entry(str(Roulette.BETS[b].name).to_lower(), [["casillas", Roulette.BETS[b].count], ["nivel_del_premio", TIER_NAMES[Roulette.BETS[b].tier]]])
	t += "# Tragamonedas\n\n"
	t += "Tres rodillos; se puede una vez retener rodillos y volver a girar los otros por %s de la ficha. Pagos en múltiplos de la ficha. Tres coronas dan además un boost épico.\n\n" % str(Slots.RESPIN_FRACTION)
	for i in Slots.SYMBOLS.size():
		t += _entry(Slots.SYMBOLS[i], [["nombre", Slots.NAMES[i]], ["peso", Slots.WEIGHTS[i]], ["pago_tres_iguales", Slots.TRIPLE[i]], ["pago_dos_iguales", Slots.PAIR[i]]])
	t += "# Blackjack\n\n"
	t += "Mazo de 52, apuesta de una ficha (o más con Apuesta libre); el crupier pide hasta 17; blackjack paga 3 a 2, ganar 1 a 1, empate devuelve; se puede doblar con las dos primeras cartas; sin dividir ni seguro. (Las reglas están en blackjack.gd.)\n\n"
	t += "# Dados del tabernero (pantalla de carga)\n\n"
	t += "Una predicción de %d dados y %d tiradas para cumplirla: los acertados quedan retenidos y sólo se vuelven a tirar los que fallaron (gratis). El premio se cobra una vez, al final, según los aciertos. `chance_cosmético` = probabilidad de que el premio traiga un cosmético (con las probabilidades de rareza de `cosmético`). La claridad de los dados tiene un tope de %d por partida.\n\n" % [DiceGame.DICE, DiceGame.THROWS, RunState.DICE_CAP]
	for n in 6:
		var p := DiceGame.prize_for(n)
		t += _entry("%d aciertos" % n, [["claridad", p.claridad], ["luz", p.luz], ["cosmético", _rarity_text(p.cosmetic)], ["chance_cosmético", p.get("cosmetic_chance", 1.0) if not p.cosmetic.is_empty() else 0.0]])
	return t


func _rarity_text(w: Dictionary) -> String:
	if w.is_empty():
		return "(ninguno)"
	var parts: Array[String] = []
	for k in w:
		parts.append("%s %d %%" % [k, int(round(float(w[k]) * 100.0))])
	return ", ".join(parts)


func _characters() -> String:
	var t := "# Personajes y cosméticos\n\n"
	t += "Los personajes son animalitos de voxels (todos juegan igual; sólo cambia el aspecto). Cada uno lleva un **gorro** y una **prenda**. Los cosméticos se ganan con los dados de la pantalla de carga.\n\n# Personajes\n\n"
	for c in Characters.ALL:
		t += _entry("%s - %s" % [c.id, c.name], [["se_desbloquea", c.unlock], ["cómo", c.how]])
	t += "# Rarezas de los cosméticos\n\n"
	for r in Cosmetics.RARITY_ORDER:
		t += _entry(r, [["nombre", Cosmetics.RARITIES[r].name]])
	t += "# Cosméticos\n\n"
	for c in Cosmetics.ALL:
		t += _entry("%s - %s" % [c.id, c.name], [["hueco", c.slot], ["rareza", c.rarity]])
	return t


func _blocks() -> String:
	var t := "# Bloques y mecánicas de la torre\n\n"
	t += "Una etapa es una torre de 25 pisos (27 etapas por partida). Se camina, se empuja o tira de bloques (Shift) y se cuelga de los bordes (Espacio). La fila de abajo cae cada N movimientos. Estos son los tipos de bloque; se introducen de a uno a medida que sube la dificultad (0 a 1 a lo largo de las 27 etapas).\n\n"
	var info := {
		"normal": ["Bloque común: se pisa, se empuja y se tira.", "siempre"],
		"hielo": ["Hace resbalar: se desliza hasta que algo lo frena.", "desde dificultad 0,05"],
		"pesado": ["No se puede empujar ni tirar (hace falta la habilidad Fuerza bruta).", "desde dificultad %s" % str(TowerGen.HEAVY_FROM)],
		"agrietado": ["Se rompe al bajarte de él.", "desde dificultad %s" % str(TowerGen.CRACKED_FROM)],
		"bomba": ["Tiene una cuenta: baja con cada movimiento mientras estás a su altura; al llegar a 0 explota. Pisarla la desactiva.", "desde dificultad 0,4"],
		"trampa": ["Celda de plataforma que se desarma al pisarla.", "desde dificultad %s" % str(TowerGen.TRAP_FROM)],
		"pinchos": ["No se puede pisar.", "desde dificultad %s" % str(TowerGen.SPIKES_FROM)],
		"catapulta": ["Sube 4 en vertical y busca un borde de donde agarrarse (hasta 2 más arriba). No se genera en las torres: sólo sale con consumibles y en el laboratorio.", "no se genera"],
	}
	for name in info:
		t += _entry(name, [["descripción", info[name][0]], ["aparece", info[name][1]]])
	t += "# Ritmos de caída de la fila de abajo\n\n"
	for p in TowerGen.PACES:
		t += _entry(p, [["margen_de_caída", TowerGen.PACES[p].ratio], ["corrimiento_de_banda", TowerGen.PACES[p].band_shift]])
	return t
