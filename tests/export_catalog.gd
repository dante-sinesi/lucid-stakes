extends SceneTree
## Vuelca el contenido del juego (bloques, habilidades persistentes, boosts, consumibles, pruebas, escenarios, casinos, personajes y cosméticos) a un
## JSON de hojas {hoja: [[nombre, descripción, extra], ...]} que arma tests/build_catalog_xlsx.py en un Excel.
## Ejecutar: CATALOG_JSON=ruta.json tools/Godot_v4.7.2-stable_win64_console.exe --headless --path . -s tests/export_catalog.gd

const Scenarios := preload("res://scripts/scenarios.gd")
const Trials := preload("res://scripts/trials.gd")
const Abilities := preload("res://scripts/abilities.gd")
const Items := preload("res://scripts/items.gd")
const CasinoRules := preload("res://scripts/casino_rules.gd")
const CasinoServices := preload("res://scripts/casino_services.gd")
const Characters := preload("res://scripts/characters.gd")
const Cosmetics := preload("res://scripts/cosmetics.gd")
const TowerGen := preload("res://scripts/tower_gen.gd")

const TIER_NAMES := {Items.Tier.CONSUMIBLE: "Barato", Items.Tier.COMUN: "Común", Items.Tier.RARO: "Raro", Items.Tier.EPICO: "Épico"}


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
	var path := OS.get_environment("CATALOG_JSON")
	var f := FileAccess.open(path, FileAccess.WRITE)
	f.store_string(JSON.stringify(sheets, "\t"))
	print("hojas: ", sheets.keys())
	quit()


func _blocks() -> Array:
	return [
		["Normal", "Se pisa, se empuja y se tira.", "Siempre"],
		["Hielo", "Hace resbalar: se desliza hasta que algo lo frena.", "Desde dificultad 0,05"],
		["Pesado", "No se puede empujar ni tirar (hace falta la habilidad Fuerza bruta).", "Desde dificultad %s" % str(TowerGen.HEAVY_FROM)],
		["Agrietado", "Se rompe al bajarte de él.", "Desde dificultad %s" % str(TowerGen.CRACKED_FROM)],
		["Bomba", "Tiene una cuenta que baja con cada movimiento mientras estás a su altura; al llegar a 0 explota. Pisarla la desactiva.", "Desde dificultad 0,4"],
		["Trampa", "Celda de plataforma que se desarma al pisarla.", "Desde dificultad %s" % str(TowerGen.TRAP_FROM)],
		["Pinchos", "No se pueden pisar.", "Desde dificultad %s" % str(TowerGen.SPIKES_FROM)],
		["Catapulta", "Sube 4 en vertical y busca un borde de donde agarrarse (hasta 2 más arriba). No se genera en las torres: sólo sale con consumibles y en el laboratorio.", "No se genera"],
	]


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
			abil.append(str(Abilities.get_ability(a).name))
		out.append([s.name, s.desc, "Habilidades: " + ", ".join(abil)])
	return out


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
