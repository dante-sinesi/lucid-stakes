extends SceneTree
## La piel del Glaciar: el pesado se ve como hielo duro y el agrietado como nieve, sólo cuando el escenario lo pide; las mismas formas, otros colores.
## Ejecutar: GAME_SANDBOX=1 tools/Godot_v4.7.2-stable_win64_console.exe --headless --path . -s tests/test_piel.gd

const BlockModels := preload("res://scripts/block_models.gd")
const Scenarios := preload("res://scripts/scenarios.gd")
const TowerLogic := preload("res://scripts/tower_logic.gd")
const K := TowerLogic.Kind

var fails := 0


func check(cond: bool, label: String) -> void:
	if not cond:
		fails += 1
		print("FAIL: ", label)


func _avg(kind: int, state: int) -> Color:
	var vox: Dictionary = BlockModels._voxels(kind, state, 0)
	var c := Color(0, 0, 0)
	for p in vox:
		c += vox[p]
	var n := float(maxi(vox.size(), 1))
	return Color(c.r / n, c.g / n, c.b / n)


func _init() -> void:
	check(Scenarios.get_scenario("glaciar").get("skin", "") == "glaciar" and str(Scenarios.get_scenario("pesadilla").get("skin", "")) == "", "sólo el Glaciar tiene piel")
	BlockModels.skin = ""
	var heavy := _avg(K.HEAVY, BlockModels.State.PURE)
	var cracked := _avg(K.CRACKED, BlockModels.State.PURE)
	var shapes_heavy := BlockModels.voxel_count(K.HEAVY, BlockModels.State.PURE)
	var shapes_cracked := BlockModels.voxel_count(K.CRACKED, BlockModels.State.PURE)
	var mesh_plain := BlockModels.mesh_for(K.HEAVY, BlockModels.State.PURE, 0)
	BlockModels.skin = "glaciar"
	var heavy_ice := _avg(K.HEAVY, BlockModels.State.PURE)
	var snow := _avg(K.CRACKED, BlockModels.State.PURE)
	check(heavy_ice.b > heavy_ice.r + 0.2 and heavy_ice.b > heavy_ice.g and heavy_ice.b > 0.55, "el pesado del Glaciar es azul (hielo duro)")
	check(heavy_ice.v < Color(0.8, 0.95, 1.0).v and heavy_ice.v < 0.85, "y más oscuro que el hielo común")
	check(snow.r > 0.8 and snow.g > 0.8 and snow.b > 0.8 and snow.b >= snow.r, "el agrietado del Glaciar es nieve (blanca azulada)")
	check(snow.b > cracked.b + 0.1 and cracked.r > cracked.b, "la arenisca de siempre sigue siendo arena (otro color)")
	check(BlockModels.voxel_count(K.HEAVY, BlockModels.State.PURE) == shapes_heavy and BlockModels.voxel_count(K.CRACKED, BlockModels.State.PURE) > shapes_cracked * 0.7, "las formas son las mismas (el pesado) o parecidas (el agrietado)")
	var mesh_skin := BlockModels.mesh_for(K.HEAVY, BlockModels.State.PURE, 0)
	check(mesh_skin != mesh_plain, "cada piel tiene su propio modelo (no se mezclan en la memoria)")
	# los otros bloques no cambian
	BlockModels.skin = ""
	var normal := _avg(K.NORMAL, BlockModels.State.PURE)
	BlockModels.skin = "glaciar"
	check(_avg(K.NORMAL, BlockModels.State.PURE) == normal, "los bloques comunes no cambian de piel")
	BlockModels.skin = ""
	check(_avg(K.HEAVY, BlockModels.State.PURE) == heavy, "sin piel vuelve el pesado de siempre")
	print("tests de la piel terminados, fallos: ", fails)
	quit(1 if fails > 0 else 0)
