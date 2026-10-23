extends SceneTree
## Español neutro en todo el juego: ningún texto entre comillas (ni de la interfaz ni de las tablas de traducción) usa voseo (tenés, podés, mirá, elegí, vos...).
## Ejecutar: GAME_SANDBOX=1 tools/Godot_v4.7.2-stable_win64_console.exe --headless --path . -s tests/unitarios/test_neutro.gd

var fails := 0
## Palabras que terminan como el voseo pero no lo son.
const ALLOWED := ["aquí", "Aquí", "así", "Así", "después", "Después", "está", "Está", "estás", "Estás", "interés", "Interés", "qué", "Qué", "sí", "Sí", "además", "allá", "allí", "atrás",
		"demás", "detrás", "más", "mí", "sé", "ahí", "Ahí", "estés", "dará", "será", "perderá", "vendrá", "volverá", "enseñaré", "quedé", "Llegué", "Jesús", "adiós", "revés", "país",
		"Cómo", "cómo", "También", "también", "habrá", "podrá", "tendrá", "hará", "verá", "sabrá", "saldrá", "pondrá", "querrá", "cabrá", "dirá", "valdrá", "caerá"]


func check(cond: bool, label: String) -> void:
	if not cond:
		fails += 1
		print("FAIL: ", label)


func _init() -> void:
	var rx_lit := RegEx.create_from_string("\"(?:[^\"\\\n]|\\.)*\"")
	var rx_clitic := RegEx.create_from_string("(?<![A-Za-zñÑáéíóúüÁÉÍÓÚ])(?:cambi|us|tom|dej|mir|pon|agarr|vend|guard|eleg|sac|prob|busc|toc|apret|empuj|tir|llev|ayud|mand|cuid)(?:alo|ala|alos|alas|elo|ela|elos|elas|ilo|ila|ame)(?![A-Za-zñÑáéíóúüÁÉÍÓÚ])")
	var rx_word := RegEx.create_from_string("(?<![A-Za-zñÑáéíóúüÁÉÍÓÚ])[A-Za-zñÑáéíóúüÁÉÍÓÚ]+(?:ás|és|ís|á|é|í)(?![A-Za-zñÑáéíóúüÁÉÍÓÚ])|(?<![A-Za-zñÑáéíóúüÁÉÍÓÚ])(?:vos|Vos)(?![A-Za-zñÑáéíóúüÁÉÍÓÚ])")
	var files := 0
	var found := {}
	for f in DirAccess.get_files_at("res://scripts"):
		if not f.ends_with(".gd"):
			continue
		files += 1
		var n := 0
		for line in FileAccess.get_file_as_string("res://scripts/" + f).split("\n"):
			n += 1
			for lit in rx_lit.search_all(line):
				for w in rx_clitic.search_all(lit.get_string()):
					found["%s:%d  %s" % [f, n, w.get_string()]] = true
				for w in rx_word.search_all(lit.get_string()):
					var word := w.get_string()
					if ALLOWED.has(word):
						continue
					# los verbos en -á/-é/-í sueltos de la tercera persona o el pretérito ("habló", "salió") no entran acá; sólo las formas de voseo y sus imperativos
					if word.ends_with("á") or word.ends_with("é") or word.ends_with("í"):
						if not _is_vos_imperative(word):
							continue
					found["%s:%d  %s" % [f, n, word]] = true
	check(files > 50, "se revisaron los scripts (%d)" % files)
	for k in found:
		print("   voseo: ", k)
	check(found.is_empty(), "no queda voseo en los textos (%d palabras)" % found.size())
	print("tests del español neutro terminados, fallos: ", fails)
	quit(1 if fails > 0 else 0)


## ¿Es un imperativo de vos (mirá, elegí, volvé, tené...)? Las formas en -á/-é/-í de otros usos (qué, sé, está, mí, así) ya están en ALLOWED; estas son las que sí cuentan.
func _is_vos_imperative(word: String) -> bool:
	var w := word.to_lower()
	for stem in ["mir", "eleg", "volv", "ten", "pod", "prob", "aprend", "apret", "baj", "camin", "cobr", "cruz", "empez", "empuj", "escap", "esper", "guard", "lleg", "manten", "marc", "pag", "pas", "pis", "reten", "solt", "sub", "super", "tir", "vend", "abr", "agreg", "avanz", "busc", "cre", "gan", "descart", "escrib", "hac", "puls", "rode", "segu", "tap", "tild", "trep", "and", "sal", "ped", "dec", "pon", "dej", "fij", "sent", "acord", "anim", "agarr", "colg", "ven", "cerr", "sac", "us", "mov", "jug", "enc", "cuid"]:
		if w.begins_with(stem):
			return true
	return false
