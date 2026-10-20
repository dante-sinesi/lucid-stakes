extends SceneTree
## Reparte una biblioteca grande en N archivos (la sala i va al archivo i % N) para procesarlos en paralelo sin cargar todo en cada proceso (la tanda de 96 horas ocupa 4 GB en memoria).
## Uso: GAME_SANDBOX=1 godot --headless --path . -s tests/dividir_biblioteca.gd -- ENTRADA.rooms CARPETA N [PARTES separadas por comas (por defecto todas)]
const Pack := preload("res://scripts/room_pack.gd")


func _init() -> void:
	var args := OS.get_cmdline_user_args()
	var rooms: Array = Pack.load_library(args[0])
	var n := int(args[2])
	var want: Array = []
	if args.size() > 3:
		for p in args[3].split(","):
			want.append(int(p))
	else:
		for k in n:
			want.append(k)
	var dir := ProjectSettings.globalize_path(args[1])
	DirAccess.make_dir_recursive_absolute(dir)
	for k in want:
		var part: Array = []
		for i in range(k, rooms.size(), n):
			part.append(rooms[i])
		Pack.write_library(part, dir.path_join("crudo_%d.rooms" % k), true)
		print("crudo_%d: %d salas" % [k, part.size()])
	quit(0)
