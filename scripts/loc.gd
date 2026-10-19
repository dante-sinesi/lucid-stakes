extends RefCounted
## Tabla de idiomas. Los textos del código están en español y esa misma frase es la CLAVE: `Loc.t("Nueva partida")` devuelve la frase
## en el idioma elegido. Para el resto de los idiomas hay un archivo con una tabla {frase en español: traducción} (loc_en.gd, ...).
## Si falta la traducción de una frase se muestra en español (y se anota en `missing`, que revisa tests/test_loc.gd).
## Los textos con números van como patrón: `Loc.t("Etapa %d") % n`; el patrón es la clave.

const EN := preload("res://scripts/loc_en.gd")

## Idiomas disponibles: código -> nombre en su propio idioma (así se reconoce aunque el juego esté en otro idioma).
const LANGS := {"es": "Español", "en": "English"}
const LANG_ORDER: Array[String] = ["es", "en"]

static var lang := "es"
static var missing := {}   # frases pedidas sin traducción (para las pruebas y para completar la tabla)
static var _outputs := {}  # frases ya traducidas por `t` (para que `auto` no las vuelva a buscar como si fueran del código)
## Para completar la tabla: con la variable de entorno GAME_LANG=en (y GAME_LOG_MISSING=ruta) cada frase sin traducir se anota en ese archivo.
static var log_path := OS.get_environment("GAME_LOG_MISSING")


static func set_lang(code: String) -> void:
	lang = code if LANGS.has(code) else "es"


static func t(text: String) -> String:
	if lang == "es" or text == "" or not has_words(text):
		return text
	var table: Dictionary = _table()
	if table.has(text):
		var out: String = table[text]
		_outputs[out] = true
		return out
	if not _outputs.has(text):   # (si ya es una traducción, traducirla de nuevo no hace nada)
		_note_missing(text)
	return text


## Texto con datos: traduce el patrón y le pone los valores (`Loc.f("Etapa %d/%d", [n, total])`). El resultado se recuerda como ya
## traducido para que la etiqueta que lo muestre no lo anote como faltante.
static func f(pattern: String, args: Array) -> String:
	var pat := t(pattern)
	var big := false
	for a in args:
		if (typeof(a) == TYPE_INT or typeof(a) == TYPE_FLOAT) and absf(float(a)) >= 10000.0:
			big = true
	if big:   # los números grandes se abrevian ("12,3 mil", "1,23 M"): el %d de un valor de 10 mil o más pasa a texto (ver number_format.gd)
		var pair := _abbreviate(pat, args)
		pat = pair[0]
		args = pair[1]
	var out := pat % args
	if lang != "es":
		if _outputs.size() > 4000:
			_outputs.clear()
		_outputs[out] = true
	return out


## Cambia cada %d cuyo valor es de 10 mil o más por un %s con el número abreviado. Devuelve [patrón, valores].
static func _abbreviate(pat: String, args: Array) -> Array:
	var fmt: GDScript = load("res://scripts/number_format.gd")
	var rx := RegEx.new()
	rx.compile("%[-+ 0#]*[0-9]*(?:\\.[0-9]+)?[a-zA-Z%]")
	var out := ""
	var last := 0
	var i := 0
	var new_args := args.duplicate()
	for m in rx.search_all(pat):
		var spec := m.get_string()
		out += pat.substr(last, m.get_start() - last)
		last = m.get_end()
		if spec == "%%":
			out += spec
			continue
		if spec.ends_with("d") and i < args.size() and (typeof(args[i]) == TYPE_INT or typeof(args[i]) == TYPE_FLOAT) and absf(float(args[i])) >= 10000.0:
			out += "%s"
			new_args[i] = fmt.fmt(args[i])
		else:
			out += spec
		i += 1
	out += pat.substr(last)
	return [out, new_args]


## Une textos ya traducidos con un separador (varias líneas en una sola etiqueta).
static func join(parts: Array, sep := "\n") -> String:
	var out := sep.join(parts)
	if lang != "es":
		_outputs[out] = true
	return out


## Traduce el texto que llega a una etiqueta o botón (VoxelLabel / VoxelButton): lo que no está en la tabla pero ya es una traducción
## (salió de `t`) o no tiene letras (números, símbolos) se deja como está sin anotarlo como faltante.
static func auto(text: String) -> String:
	if lang == "es" or text == "":
		return text
	var table: Dictionary = _table()
	if table.has(text):
		return table[text]
	if not _outputs.has(text) and has_words(text):
		_note_missing(text)
	return text


## Un texto que no se traduce (nombre de una tecla, por ejemplo): se muestra tal cual sin anotarlo como faltante.
static func literal(text: String) -> String:
	_outputs[text] = true
	return text


static var _spec: RegEx


## ¿Tiene palabras? (no cuentan los marcadores %s %d ni las letras sueltas como la "x" de "x1.5" o "1280 x 720"; los nombres de los
## idiomas tampoco: se muestran siempre en su propio idioma.)
static func has_words(text: String) -> bool:
	if _spec == null:
		_spec = RegEx.new()
		_spec.compile("%[-+0-9.]*[sdfx%]")
	if LANGS.values().has(text):
		return false
	var clean := _spec.sub(text, "", true)
	var run := 0
	for i in clean.length():
		var c := clean.unicode_at(i)
		if (c >= 65 and c <= 90) or (c >= 97 and c <= 122) or c > 191:
			run += 1
			if run >= 2:
				return true
		else:
			run = 0
	return false


static func _note_missing(text: String) -> void:
	if missing.has(text):
		return
	missing[text] = true
	if log_path != "":
		var f := FileAccess.open(log_path, FileAccess.READ_WRITE) if FileAccess.file_exists(log_path) else FileAccess.open(log_path, FileAccess.WRITE)
		if f != null:
			f.seek_end()
			f.store_line(text.replace(char(10), "\\n"))


## La tabla del idioma actual (vacía para el español: es el idioma de las claves).
static func _table() -> Dictionary:
	match lang:
		"en":
			return EN.TABLE
	return {}


static func table_for(code: String) -> Dictionary:
	match code:
		"en":
			return EN.TABLE
	return {}
