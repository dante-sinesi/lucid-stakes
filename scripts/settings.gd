extends RefCounted
## Ajustes del jugador (user://settings.json): idioma, ventana o pantalla completa, resolución, sincronía vertical y volumen.
## `apply()` los pone en marcha; se llama al abrir el juego y cada vez que se cambia algo en Opciones.

const Loc := preload("res://scripts/loc.gd")
const AudioHub := preload("res://scripts/audio_hub.gd")

## Resoluciones de ventana que se ofrecen (se filtran por el tamaño de la pantalla del jugador).
const RESOLUTIONS: Array[Vector2i] = [Vector2i(854, 480), Vector2i(960, 540), Vector2i(1024, 576), Vector2i(1280, 720), Vector2i(1366, 768), Vector2i(1600, 900), Vector2i(1920, 1080), Vector2i(2560, 1440)]
const VOLUME_STEPS := 10

static var path := "user://settings.json"
static var data := {}
static var _loaded := false
## En las pruebas sin pantalla (headless) no se lee ni se escribe el archivo del jugador, salvo que una prueba lo pida.
static var headless_io := false
## Cuántas veces se tocó la ventana (modo y tamaño): las pruebas comprueban que cambiar el volumen no lo hace.
static var window_applies := 0


static func _io() -> bool:
	return headless_io or DisplayServer.get_name() != "headless"


static func defaults() -> Dictionary:
	var system_lang := OS.get_locale_language()
	return {
		"lang": "en" if system_lang == "en" and DisplayServer.get_name() != "headless" else "es",
		"fullscreen": false,
		"resolution": [1280, 720],
		"vsync": true,
		"volume": VOLUME_STEPS,   # en pasos de 0 a VOLUME_STEPS
		"music": VOLUME_STEPS,    # música (se multiplica por el volumen general)
		"sfx": VOLUME_STEPS,      # efectos de sonido
		"bindings": {},           # controles que el jugador cambió (ver controls.gd)
		"graphics": {},           # gráficos que el jugador cambió (ver graphics.gd)
	}


static func load_settings() -> void:
	data = defaults()
	if _io() and FileAccess.file_exists(path):
		var f := FileAccess.open(path, FileAccess.READ)
		var parsed = JSON.parse_string(f.get_as_text())
		if parsed is Dictionary:
			for k in data:
				if parsed.has(k):
					data[k] = parsed[k]
	if OS.get_environment("GAME_LANG") != "":   # (para completar las traducciones: se corren las pruebas en otro idioma)
		data.lang = OS.get_environment("GAME_LANG")
	_loaded = true
	_sanitize()


static func _sanitize() -> void:
	if not Loc.LANGS.has(str(data.lang)):
		data.lang = "es"
	data.fullscreen = bool(data.fullscreen)
	data.vsync = bool(data.vsync)
	data.volume = clampi(int(data.volume), 0, VOLUME_STEPS)
	data.music = clampi(int(data.music), 0, VOLUME_STEPS)
	data.sfx = clampi(int(data.sfx), 0, VOLUME_STEPS)
	if not data.bindings is Dictionary:
		data.bindings = {}
	if not data.graphics is Dictionary:
		data.graphics = {}
	var r = data.resolution
	if not (r is Array and r.size() == 2 and int(r[0]) >= 640 and int(r[1]) >= 360):
		data.resolution = [1280, 720]


static func save() -> void:
	if not _io():
		return
	var f := FileAccess.open(path, FileAccess.WRITE)
	if f != null:
		f.store_string(JSON.stringify(data, "\t"))


static func get_value(key: String):
	if not _loaded:
		load_settings()
	return data[key]


static func set_value(key: String, value) -> void:
	if not _loaded:
		load_settings()
	data[key] = value
	_sanitize()
	save()
	# Sólo se vuelve a aplicar lo que cambió: tocar el volumen no puede mover ni achicar la ventana (que el jugador pudo maximizar).
	match key:
		"lang":
			apply("lang")
		"volume", "music", "sfx":
			apply("audio")
		"vsync":
			apply("vsync")
		_:
			apply("window")


static func lang() -> String:
	return str(get_value("lang"))


static func resolution() -> Vector2i:
	var r: Array = get_value("resolution")
	return Vector2i(int(r[0]), int(r[1]))


static func volume_linear() -> float:
	return float(int(get_value("volume"))) / float(VOLUME_STEPS)


static func _set_bus(bus_name: String, linear: float) -> void:
	var bus := AudioServer.get_bus_index(bus_name)
	if bus >= 0:
		AudioServer.set_bus_mute(bus, linear <= 0.0)
		AudioServer.set_bus_volume_db(bus, linear_to_db(maxf(linear, 0.0001)))


## Las resoluciones que entran en la pantalla del jugador (todas si no se puede saber), con la actual siempre incluida.
static func available_resolutions() -> Array[Vector2i]:
	var screen := Vector2i.ZERO
	if DisplayServer.get_name() != "headless":
		screen = DisplayServer.screen_get_size()
	var out: Array[Vector2i] = []
	for r in RESOLUTIONS:
		if screen == Vector2i.ZERO or (r.x <= screen.x and r.y <= screen.y):
			out.append(r)
	var cur := resolution()
	if not out.has(cur):
		out.append(cur)
		out.sort_custom(func(a, b): return a.x < b.x)
	return out


## Pone en marcha los ajustes: idioma, volumen, sincronía vertical y modo/tamaño de ventana.
## `what`: "all" (al abrir el juego), "lang", "audio", "vsync" o "window" (pantalla completa o resolución): sólo se aplica esa parte.
static func apply(what := "all") -> void:
	if not _loaded:
		load_settings()
	if what == "all" or what == "lang":
		Loc.set_lang(str(data.lang))
	if what == "all" or what == "audio":
		var vol := volume_linear()
		AudioHub.ensure_buses()
		_set_bus("Master", vol)
		_set_bus(AudioHub.BUS_MUSIC, float(int(data.music)) / float(VOLUME_STEPS))
		_set_bus(AudioHub.BUS_SFX, float(int(data.sfx)) / float(VOLUME_STEPS))
	if what == "all" or what == "window":
		window_applies += 1
	if DisplayServer.get_name() == "headless":
		return
	if what == "all" or what == "vsync":
		DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_ENABLED if data.vsync else DisplayServer.VSYNC_DISABLED)
	if what != "all" and what != "window":
		return
	if data.fullscreen:
		DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_EXCLUSIVE_FULLSCREEN)
	else:
		DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED)
		var size := resolution()
		var area := DisplayServer.screen_get_usable_rect(DisplayServer.window_get_current_screen())
		size = Vector2i(mini(size.x, area.size.x), mini(size.y, area.size.y))
		DisplayServer.window_set_size(size)
		DisplayServer.window_set_position(area.position + (area.size - size) / 2)
