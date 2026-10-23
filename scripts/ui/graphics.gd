extends RefCounted
## Gráficos: preajustes (Alta, Media, Baja) y ajustes sueltos que se guardan en los ajustes del jugador (clave "graphics").
## Tocar un ajuste suelto pasa el preajuste a "Personalizada". "Baja" está pensado para PCs menos potentes.
## `value(key)` es lo que consulta el juego; `apply_global()` pone en marcha lo que es de toda la ventana (escala de render, antialiasing, tope
## de cuadros) y avisa al grupo "graphics" para que cada parte (sol, partículas, silueta, contador de FPS) se reacomode con `apply_graphics()`.

const Settings := preload("res://scripts/datos/settings.gd")

const PRESETS := ["alta", "media", "baja"]
const PRESET_NAMES := {"alta": "Alta", "media": "Media", "baja": "Baja", "custom": "Personalizada"}

## Valores de cada preajuste. fps_cap: 0 = sin límite.
const PRESET_VALUES := {
	"alta": {"shadows": "soft", "particles": "all", "scale": 100, "aa": 4, "silhouette": true, "effects": true, "fps_cap": 0},
	"media": {"shadows": "hard", "particles": "few", "scale": 80, "aa": 2, "silhouette": true, "effects": true, "fps_cap": 60},
	"baja": {"shadows": "off", "particles": "none", "scale": 70, "aa": 0, "silhouette": true, "effects": true, "fps_cap": 60},
}

## Opciones de cada ajuste suelto, en orden.
const CHOICES := {
	"shadows": ["off", "hard", "soft"],
	"particles": ["none", "few", "all"],
	"scale": [50, 60, 70, 80, 90, 100],
	"aa": [0, 2, 4],
	"fps_cap": [30, 60, 144, 0],
}
const CHOICE_NAMES := {
	"off": "Sin sombras", "hard": "Sombras duras", "soft": "Sombras suaves",
	"none": "Sin partículas", "few": "Pocas", "all": "Todas",
}

static var applies := 0   # las pruebas cuentan cuántas veces se puso en marcha


static func defaults() -> Dictionary:
	var d: Dictionary = PRESET_VALUES.alta.duplicate()
	d["preset"] = "alta"
	return d


## Todos los ajustes vigentes (los guardados, completados con los de fábrica).
static func current() -> Dictionary:
	var d := defaults()
	var saved = Settings.get_value("graphics")
	if saved is Dictionary:
		for k in d:
			if (saved as Dictionary).has(k):
				d[k] = saved[k]
	return _sanitize(d)


static func _sanitize(d: Dictionary) -> Dictionary:
	if not PRESET_NAMES.has(str(d.preset)):
		d.preset = "custom"
	for k in CHOICES:
		if not (CHOICES[k] as Array).has(d[k]):
			d[k] = PRESET_VALUES.alta[k]
		elif k in ["scale", "aa", "fps_cap"]:
			d[k] = int(d[k])
	d.silhouette = bool(d.silhouette)
	d.effects = bool(d.effects)
	return d


static func value(key: String):
	return current()[key]


static func preset() -> String:
	return str(current().preset)


static func _store(d: Dictionary) -> void:
	Settings.set_value("graphics", d)
	apply_global()


## Elige un preajuste (alta, media o baja): pisa todos los ajustes sueltos.
static func set_preset(name: String) -> void:
	if not PRESET_VALUES.has(name):
		return
	var d := current()
	d.merge(PRESET_VALUES[name], true)
	d.preset = name
	_store(d)


## Cambia un ajuste suelto; el preajuste pasa a "Personalizada" (o toma el nombre del preajuste si los valores coinciden justo).
static func set_value(key: String, v) -> void:
	var d := current()
	d[key] = v
	d.preset = "custom"
	for p in PRESETS:   # si los valores coinciden justo con un preajuste, se lo nombra
		var same := true
		for k in PRESET_VALUES[p]:
			if d[k] != PRESET_VALUES[p][k]:
				same = false
		if same:
			d.preset = p
	_store(_sanitize(d))


static func reset() -> void:
	_store(defaults())


## Siguiente opción de un ajuste de lista (dir: +1 o −1, con vuelta).
static func cycle(key: String, dir: int) -> void:
	var opts: Array = CHOICES[key]
	var i := opts.find(value(key))
	set_value(key, opts[(maxi(i, 0) + dir + opts.size()) % opts.size()])


## Lo que depende de la ventana entera. Las partes del juego se reacomodan con apply_graphics() (grupo "graphics").
static func apply_global() -> void:
	applies += 1
	var d := current()
	Engine.max_fps = int(d.fps_cap)
	var tree := Engine.get_main_loop() as SceneTree
	if tree == null or DisplayServer.get_name() == "headless":
		return
	var root := tree.root
	root.scaling_3d_scale = float(int(d.scale)) / 100.0 * _fullscreen_factor()
	root.msaa_3d = {0: Viewport.MSAA_DISABLED, 2: Viewport.MSAA_2X, 4: Viewport.MSAA_4X}[int(d.aa)]
	tree.call_group("graphics", "apply_graphics")


## En pantalla completa la resolución elegida es la del render: el juego se dibuja a esa altura y se estira a la pantalla.
static func _fullscreen_factor() -> float:
	if not bool(Settings.get_value("fullscreen")):
		return 1.0
	var screen := DisplayServer.screen_get_size()
	if screen.y <= 0:
		return 1.0
	return clampf(float(Settings.resolution().y) / float(screen.y), 0.25, 1.0)


## ¿Se dibujan las partículas de las "chispas" de cada bloque? ("few": sólo las cercanas)
static func block_particles_radius() -> int:
	match str(value("particles")):
		"all": return 6
		"few": return 2
		_: return -1


## Multiplicador de la cantidad de partículas de los efectos (explosiones y demás).
static func particle_factor() -> float:
	match str(value("particles")):
		"all": return 1.0
		"few": return 0.4
		_: return 0.0


static func apply_to_sun(sun: DirectionalLight3D) -> void:
	var s := str(value("shadows"))
	sun.shadow_enabled = s != "off"
	sun.shadow_blur = 1.6 if s == "soft" else 0.0
