extends SceneTree
## Los gráficos de la primera vez: el preajuste que se elige según la tarjeta, los núcleos y la memoria, y que sólo se detecta si no había ajustes.
## Uso: GAME_SANDBOX=1 godot --headless --path . -s tests/unitarios/test_graficos_auto.gd
const Graphics := preload("res://scripts/ui/graphics.gd")
const Settings := preload("res://scripts/datos/settings.gd")
const Seguro := preload("res://scripts/datos/archivo_seguro.gd")

var fallos := 0


func check(cond: bool, msg: String) -> void:
	if not cond:
		fallos += 1
		print("FALLA ", msg)


func _init() -> void:
	var E := Graphics.elegir_preajuste
	check(E.call("NVIDIA GeForce RTX 3060", 2, 12, 16000) == "alta", "RTX con 12 núcleos y 16 GB: alta")
	check(E.call("AMD Radeon RX 6600", 0, 8, 16000) == "alta", "Radeon RX se reconoce como dedicada aunque el tipo sea desconocido")
	check(E.call("NVIDIA GeForce GTX 1050 Ti", 2, 4, 8000) == "alta", "GTX 1050 Ti con 4 núcleos: alta")
	check(E.call("NVIDIA GeForce GT 710", 2, 4, 8000) == "media", "una dedicada muy floja: media")
	check(E.call("NVIDIA GeForce RTX 3060", 2, 2, 8000) == "media", "dedicada con sólo 2 núcleos: media")
	check(E.call("Intel(R) UHD Graphics 630", 1, 8, 16000) == "media", "Intel UHD con equipo holgado: media")
	check(E.call("Intel(R) UHD Graphics 620", 1, 2, 4000) == "baja", "Intel UHD con 2 núcleos: baja")
	check(E.call("Intel(R) HD Graphics 4000", 1, 4, 8000) == "baja", "Intel HD vieja: baja")
	check(E.call("AMD Radeon(TM) Graphics", 1, 8, 16000) == "media", "APU de AMD: media")
	check(E.call("Intel(R) Iris(R) Xe Graphics", 1, 8, 8000) == "media", "Iris Xe: media")
	check(E.call("llvmpipe (LLVM 15.0.6, 256 bits)", 4, 16, 32000) == "baja", "render por software: baja aunque el equipo sea grande")
	check(E.call("Microsoft Basic Render Driver", 0, 8, 16000) == "baja", "controlador básico de Windows: baja")
	check(E.call("Algo Desconocido 9000", 0, 8, 16000) == "media", "una tarjeta que no se reconoce: media")
	check(E.call("Algo Desconocido 9000", 0, 2, 2000) == "baja", "desconocida y con poca memoria: baja")
	check(E.call("NVIDIA GeForce RTX 3060", 2, 12, -1) == "alta", "si no se sabe la memoria no se castiga")
	# la primera vez: sólo si no había archivo de ajustes
	Settings.headless_io = true
	Settings.path = "user://test_settings_auto.json"
	Seguro.borrar(Settings.path)
	Settings._loaded = false
	Settings.load_settings()
	check(Settings.primera_vez, "sin archivo de ajustes es la primera vez")
	Settings.save()
	Settings._loaded = false
	Settings.load_settings()
	check(not Settings.primera_vez, "con el archivo ya no lo es")
	Seguro.borrar(Settings.path)
	Settings.headless_io = false
	print("tests de los gráficos automáticos terminados, fallos: ", fallos)
	quit(1 if fallos > 0 else 0)
