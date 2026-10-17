extends Control
## Generar_Salas.exe: el generador de salas completo en un solo programa para llevar a otra PC (sin Godot, sin el proyecto, sin nada instalado). Junto al .exe tiene que estar generador_nativo.exe.
## Pone en marcha varias copias del generador nativo, espera, comprueba cada sala con las reglas del juego y escribe salas.rooms (la biblioteca) en la misma carpeta; si ya había una, suma y deja salas.rooms.bak.
## Corre en rondas sin parar (cada ronda guarda y empieza otra con semilla nueva, guardada en semilla.txt) hasta que se cierre la ventana. Opciones (por línea de comandos o en opciones.txt, una por línea): --pasos=1500 --procesos=N --altura=12 --alcance=0.5
## Para usar la biblioteca en el juego: copiar salas.rooms a data\salas.rooms del proyecto.

const GenMain := preload("res://scripts/generador_main.gd")

var dir := ""
var native := ""
var procs := 0
var pids: Array = []
var steps := 1500
var hhi := 12
var min_reach := 0.5
var seed_n := 1
var label: Label
var phase := "mina"
var started_ms := 0
var finishing := false
var last_text := ""


func _ready() -> void:
	dir = OS.get_executable_path().get_base_dir()
	if OS.has_feature("editor"):
		dir = ProjectSettings.globalize_path("res://").path_join("build/generador_prueba")
		DirAccess.make_dir_recursive_absolute(dir)
	native = dir.path_join("generador_nativo.exe")
	if not FileAccess.file_exists(native):
		native = ProjectSettings.globalize_path("res://tools/generador.exe")
	procs = max(1, OS.get_processor_count() / 2)
	var args: Array = []
	var opt_path := dir.path_join("opciones.txt")
	if FileAccess.file_exists(opt_path):
		for l in FileAccess.get_file_as_string(opt_path).split("\n", false):
			args.append(l.strip_edges())
	args.append_array(OS.get_cmdline_user_args())
	args.append_array(OS.get_cmdline_args())
	for a in args:
		if a.begins_with("--pasos="):
			steps = int(a.substr(8))
		elif a.begins_with("--procesos="):
			procs = max(1, int(a.substr(11)))
		elif a.begins_with("--altura="):
			hhi = int(a.substr(9))
		elif a.begins_with("--alcance="):
			min_reach = float(a.substr(10))
	label = Label.new()
	label.set_anchors_preset(Control.PRESET_FULL_RECT)
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.add_theme_font_size_override("font_size", 22)
	add_child(label)
	set_anchors_preset(Control.PRESET_FULL_RECT)
	if not FileAccess.file_exists(native):
		label.text = "Falta generador_nativo.exe junto a este programa."
		phase = "error"
		return
	_start_round()


func _start_round() -> void:
	pids.clear()
	var seed_path := dir.path_join("semilla.txt")
	if FileAccess.file_exists(seed_path):
		seed_n = int(FileAccess.get_file_as_string(seed_path).strip_edges()) + 1
	var f := FileAccess.open(seed_path, FileAccess.WRITE)
	f.store_string(str(seed_n))
	f.close()
	var work := dir.path_join("trabajo")
	DirAccess.make_dir_recursive_absolute(work)
	var d := DirAccess.open(work)
	for fn in d.get_files():
		d.remove(fn)
	for i in procs:
		var out := work.path_join("gen_%d.txt" % i)
		pids.append(OS.create_process(native, ["mina", "--out=" + out, "--steps=%d" % steps, "--hhi=%d" % hhi, "--seed=%d" % seed_n, "--part=%d" % i, "--parts=%d" % procs]))
	started_ms = Time.get_ticks_msec()
	finishing = false
	phase = "mina"


func _notification(what: int) -> void:
	if what == NOTIFICATION_WM_CLOSE_REQUEST:
		for pid in pids:
			if pid > 0 and OS.is_process_running(pid):
				OS.kill(pid)
		get_tree().quit()


func _count_rooms() -> int:
	var n := 0
	var d := DirAccess.open(dir.path_join("trabajo"))
	if d == null:
		return 0
	for fn in d.get_files():
		if fn.ends_with(".txt"):
			var text := FileAccess.get_file_as_string(dir.path_join("trabajo").path_join(fn))
			n += text.count("\nR|") + (1 if text.begins_with("R|") else 0)
	return n


func _process(_dt: float) -> void:
	if phase == "mina":
		var running := 0
		for pid in pids:
			if pid > 0 and OS.is_process_running(pid):
				running += 1
		label.text = "Buscando salas sin parar (%d procesos, ronda %d)\n%d candidatas en esta ronda, %d min\n%s\nCerrá la ventana cuando quieras: las rondas terminadas ya están en salas.rooms." % [running, seed_n, _count_rooms(), (Time.get_ticks_msec() - started_ms) / 60000, last_text]
		if running == 0 and not finishing:
			finishing = true
			phase = "cierre"
			label.text = "Comprobando las salas con las reglas del juego..."
			await get_tree().process_frame
			await get_tree().process_frame
			_close()


func _close() -> void:
	var lib := dir.path_join("salas.rooms")
	var res := GenMain.run(dir.path_join("trabajo"), "", lib if FileAccess.file_exists(lib) else "res://data/salas.rooms", lib, min_reach, 1, native, false)
	var f := FileAccess.open(dir.path_join("resumen.txt"), FileAccess.WRITE)
	f.store_string(res.text)
	f.close()
	last_text = "Última ronda guardada: " + res.text.split("\n")[0]
	_start_round()
