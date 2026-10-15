extends Node
## Escena del minero de salas (se deja corriendo 24/7). Uso (después de `--` van los argumentos del minero):
##   Godot --headless --path . res://scenes/miner.tscn -- --id=1 --out=C:/biblioteca --minutes=0
## Argumentos: --id=N (cada copia en marcha usa uno distinto), --out=CARPETA (donde se escribe miner_N.jsonl y stats_N.json; por defecto user://biblioteca),
## --minutes=M (0 = para siempre), --seed=S, --shapes=3x3,3x5,3x8,L,U, --hlo=5, --hhi=20, --keep=6, --verify=0.1, --max-evals=N, --cap-mult=1 (multiplica el tope de estados y de tiempo del solucionador), --excavate=P (probabilidad de excavar una sala del archivo con el solucionador nativo en cada paso; 0 = nunca), --excavate-nodes=N, --excavate-eval=N, --types=P (probabilidad de probar variantes con bloques especiales), --excavate-free=1 (las salas excavadas pueden tener bloques sin columna hasta el piso).
## Se detiene sola con un archivo llamado STOP en la carpeta de salida. Si se corta (luz, error), se retoma desde su propio .jsonl.
const RoomMiner := preload("res://scripts/room_miner.gd")
const RoomLib := preload("res://scripts/room_lib.gd")

const REPORT_EVERY_MS := 60000


static func parse_args(args: PackedStringArray) -> Dictionary:
	var cfg := {"id": 1, "out_dir": "user://biblioteca", "minutes": 0.0, "max_evals": 0}
	for a in args:
		if not a.begins_with("--") or a.find("=") == -1:
			continue
		var k := a.substr(2, a.find("=") - 2)
		var v := a.substr(a.find("=") + 1)
		match k:
			"id":
				cfg.id = int(v)
			"out":
				cfg.out_dir = v
			"minutes":
				cfg.minutes = float(v)
			"seed":
				cfg.seed = int(v)
			"shapes":
				cfg.shapes = Array(v.split(",", false))
			"hlo":
				cfg.h_lo = int(v)
			"hhi":
				cfg.h_hi = int(v)
			"keep":
				cfg.keep = int(v)
			"verify":
				cfg.verify_p = float(v)
			"max-evals":
				cfg.max_evals = int(v)
			"cap-mult":
				cfg.cap_mult = float(v)
			"excavate":
				cfg.excavate = float(v)
			"excavate-nodes":
				cfg.excavate_nodes = int(v)
			"excavate-eval":
				cfg.excavate_eval = int(v)
			"types":
				cfg.types = float(v)
			"excavate-free":
				cfg.excavate_free = int(v) != 0
	return cfg


func _ready() -> void:
	var cfg := parse_args(OS.get_cmdline_user_args())
	var miner := RoomMiner.new(cfg)
	if miner.combos_list.is_empty():
		print("[minero] no hay combinaciones forma-altura con esos filtros")
		get_tree().quit(2)
		return
	var resumed := miner.resume()
	print("[minero %d] arranca: %d combinaciones forma-altura, retoma %d salas, salida %s" % [miner.miner_id, miner.combos_list.size(), resumed, miner.out_path])
	var t0 := Time.get_ticks_msec()
	var last_report := t0
	var steps := 0
	var limit_ms := int(float(cfg.minutes) * 60000.0)
	var stop_file: String = miner.out_dir.path_join("STOP")
	while true:
		if limit_ms > 0 and Time.get_ticks_msec() - t0 >= limit_ms:
			break
		if int(cfg.max_evals) > 0 and int(miner.stats.evals) >= int(cfg.max_evals):
			break
		if steps % 20 == 0 and FileAccess.file_exists(stop_file):
			print("[minero %d] archivo STOP: termina" % miner.miner_id)
			break
		miner.step()
		steps += 1
		if steps % 3 == 0:
			await get_tree().process_frame
		if Time.get_ticks_msec() - last_report >= REPORT_EVERY_MS:
			last_report = Time.get_ticks_msec()
			miner.write_stats()
			var s := miner.summary()
			print("[minero %d] %.1f evaluaciones/s, %d salas en el archivo, %d/%d combinaciones cubiertas, pruebas %s, correcciones %d, excavaciones %d, máximo de agarres %s" % [miner.miner_id, s.evals_per_s, s.archive, s.groups_covered, s.groups_total, str(s.proofs), int(miner.stats.corrections), int(miner.stats.get("excavations", 0)), str(s.max_grabs_by_shape)])
	miner.write_stats()
	var fin := miner.summary()
	print("[minero %d] fin: %d evaluaciones, %d salas en el archivo, pruebas %s" % [miner.miner_id, int(miner.stats.evals), fin.archive, str(fin.proofs)])
	get_tree().quit(0)
