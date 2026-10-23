extends SceneTree
## Vuelca el contenido del juego (bloques, habilidades persistentes, boosts, consumibles, pruebas, escenarios, casinos, personajes y cosméticos) a un archivo de hojas
## {hoja: [[nombre, descripción, extra], ...]} en JSON. `herramientas/catalogo.py` lo convierte en docs/catalogo.md y docs/catalogo.xlsx (o `herramientas\catalogo.bat` hace las dos cosas).
## Ejecutar: GAME_SANDBOX=1 CATALOGO_JSON=ruta.json tools/Godot_v4.7.2-stable_win64_console.exe --headless --path . -s herramientas/catalogo.gd

const Scenarios := preload("res://scripts/datos/scenarios.gd")
const Trials := preload("res://scripts/datos/trials.gd")
const Abilities := preload("res://scripts/datos/abilities.gd")
const Items := preload("res://scripts/datos/items.gd")
const BlockGuide := preload("res://scripts/datos/block_guide.gd")
const CasinoRules := preload("res://scripts/casino/casino_rules.gd")
const CasinoServices := preload("res://scripts/casino/casino_services.gd")
const Characters := preload("res://scripts/personajes/characters.gd")
const Cosmetics := preload("res://scripts/personajes/cosmetics.gd")
const Torre := preload("res://torre/torre.gd")

const TIER_NAMES := {Items.Tier.CONSUMIBLE: "Barato", Items.Tier.COMUN: "Común", Items.Tier.RARO: "Raro", Items.Tier.EPICO: "Épico"}
## Qué letra del motor es cada bloque de la guía (para decir desde qué etapa aparece).
const LETRA_DE := {"hielo": "i", "pesado": "h", "agrietado": "c", "trampa": "t", "pinchos": "s", "bomba": "b", "catapulta": "k"}


func _init() -> void:
	var sheets := {}
	sheets["Bloques"] = _blocks()
	sheets["Habilidades persistentes"] = _abilities()
	sheets["Boosts"] = _items(Items.Type.BOOST)
	sheets["Consumibles"] = _items(Items.Type.CONSUMABLE, true)
	sheets["Pruebas"] = _trials()
	sheets["Escenarios"] = _scenarios()
	sheets["Reglas de la casa"] = _rules()
	sheets["Servicios del casino"] = _services()
	sheets["Personajes"] = _characters()
	sheets["Cosméticos"] = _cosmetics()
	var path := OS.get_environment("CATALOGO_JSON")
	var f := FileAccess.open(path, FileAccess.WRITE)
	f.store_string(JSON.stringify(sheets, "\t"))
	print("hojas: ", sheets.keys())
	quit()


func _blocks() -> Array:
	var out := []
	for b in BlockGuide.ALL:
		var desde := "Desde la etapa 1"
		if LETRA_DE.has(str(b.id)):
			desde = "Desde la etapa %d" % int(Torre.ETAPA_ESPECIAL[LETRA_DE[str(b.id)]])
		out.append([b.name, b.desc, desde])
	return out


func _abilities() -> Array:
	var out := []
	for a in Abilities.ALL:
		var where: Array[String] = []
		for s in Scenarios.scenarios_for_ability(a.id):
			where.append(str(s.name))
		out.append([a.name, a.desc, "Se gana en: " + ", ".join(where)])
	return out


func _items(type: int, with_bags := false) -> Array:
	var out := []
	for tier in [Items.Tier.EPICO, Items.Tier.RARO, Items.Tier.COMUN, Items.Tier.CONSUMIBLE]:
		for it in Items.ALL:
			if it.tier == tier and (it.type == type or (with_bags and it.type == Items.Type.CLARITY)):
				var extra: String = TIER_NAMES[tier]
				if it.get("stack", false):
					extra += " (se acumula)"
				out.append([it.name, it.desc, extra])
	return out


func _trials() -> Array:
	var out := []
	for id in Trials.CATALOG:
		out.append([Trials.CATALOG[id].name, Trials.CATALOG[id].desc, ""])
	return out


func _scenarios() -> Array:
	var out := []
	for s in Scenarios.ALL:
		var abil: Array[String] = []
		for a in Scenarios.ability_ids(s):
			abil.append(_nombre_habilidad(a))
		var estado := "Se puede jugar" if Scenarios.playable(str(s.id)) else "Próximamente"
		out.append([s.name, s.desc, "%s. Habilidades: %s" % [estado, ", ".join(abil) if not abil.is_empty() else "ninguna todavía"]])
	return out


## El nombre de una habilidad (las pendientes todavía no están en el catálogo del juego: se busca también ahí).
func _nombre_habilidad(id: String) -> String:
	var a := Abilities.get_ability(id)
	if a.is_empty():
		for p in Abilities.PENDING:
			if p.id == id:
				return str(p.name) + " (pendiente)"
		return id
	return str(a.name)


func _rules() -> Array:
	var out := []
	for i in CasinoRules.RULES.size():
		out.append([CasinoRules.RULES[i].name, CasinoRules.RULES[i].desc, CasinoRules.ROOM_NAMES[i]])
	return out


func _services() -> Array:
	var out := []
	for i in CasinoServices.BY_TIER.size():
		var id: String = CasinoServices.BY_TIER[i]
		if id != "":
			out.append([CasinoServices.INFO[id].name, CasinoServices.INFO[id].desc, CasinoRules.ROOM_NAMES[i]])
	return out


func _characters() -> Array:
	var out := []
	for c in Characters.ALL:
		out.append([c.name, c.how, ""])
	return out


func _cosmetics() -> Array:
	var out := []
	for c in Cosmetics.ALL:
		out.append([c.name, "%s, %s" % [str(c.slot).capitalize(), str(Cosmetics.RARITIES[c.rarity].name).to_lower()], ""])
	return out
