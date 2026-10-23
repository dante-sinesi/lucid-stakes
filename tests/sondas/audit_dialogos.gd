extends SceneTree
## Mide cuántos renglones ocupa cada diálogo del juego en el cuadro (cabe en 4) y lista los que se pasan, en español e inglés. Sin ventana.
const VFont := preload("res://scripts/ui/voxel_font.gd")
const Story := preload("res://scripts/datos/story.gd")
const Loc := preload("res://scripts/idioma/loc.gd")
const Farolin := preload("res://scripts/personajes/farolin.gd")
const Rules := preload("res://scripts/casino/casino_rules.gd")
const Trials := preload("res://scripts/datos/trials.gd")
const BlockGuide := preload("res://scripts/datos/block_guide.gd")
const DialogueBox := preload("res://scripts/ui/dialogue_box.gd")
const Tutorial := preload("res://scripts/datos/tutorial.gd")
const MAX_LINES := 4

var bad := 0
var total := 0


func _check(origin: String, l) -> void:
	var icon: bool = typeof(l) != TYPE_STRING and l.has("icon")
	var txt: String = Loc.t(l if typeof(l) == TYPE_STRING else str(l.get("text", "")))
	var n: int = VFont.wrap(txt, DialogueBox.TEXT_CELLS - (80 if icon else 0)).size()
	total += 1
	if n > MAX_LINES:
		bad += 1
		print("SE PASA (%d renglones) [%s %s] %s" % [n, Loc.lang, origin, txt.substr(0, 90)])


func _init() -> void:
	for lang in ["es", "en"]:
		Loc.set_lang(lang)
		for l in Story.intro():
			_check("intro", l)
		for l in Story.outro():
			_check("cierre", l)
		for l in Story.dice_intro():
			_check("dados", l)
		for id in Story.LESSONS:
			_check("leccion " + id, Story.LESSONS[id])
		_check("mesa bloqueada", Story.BLOCKED_TABLE)
		for g in Story.GREETINGS:
			_check("saludo", g)
		for r in Rules.RULES:
			for next in [{}, {"trial": Trials.for_stage({3: "meteoritos"}, 3), "left": 0}, {"trial": Trials.for_stage({6: "todo_o_nada"}, 6), "left": 2}]:
				for known in [false, true]:
					for l in Story.keeper(r, known, next, 0, 12345):
						_check("tabernero casino " + str(r.id), l)
		for id in Trials.CATALOG:
			var t: Dictionary = Trials.CATALOG[id].duplicate()
			t["id"] = id
			for l in Story.keeper(Rules.RULES[0], false, {"trial": t, "left": 0}, 0, 0):
				_check("prueba " + id, l)
		for price in [5, 999, 123456789]:
			for have in [0, price, price * 2]:
				for redo in [true, false]:
					var d := Farolin.toll_dialog(price, have, redo)
					_check("Farolín", d.text)
		for b in BlockGuide.ALL:
			_check("bloque " + str(b.id), b.say)
	print("audit de diálogos: ", bad, " de ", total, " se pasan de ", MAX_LINES, " renglones")
	quit()
