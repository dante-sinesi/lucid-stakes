extends Node
## Escena del empaquetador de la biblioteca. Uso: Godot --headless --path . res://scenes/pack.tscn -- --in=CARPETA --out=ARCHIVO.rooms [--min-moved=1] [--prune] [--polish] [--verbose]
## Siempre saca las vueltas de los caminos y recalcula las métricas (empujes y tirones, dificultad). --prune saca además el relleno de cada sala y --polish mejora el final de su camino con el verificador exacto
## (son lentos: unos segundos por sala). Muestra los promedios antes y después.
## Si el archivo de salida termina en .rooms se escribe comprimido; si termina en .jsonl, en texto.
const RoomPack := preload("res://scripts/room_pack.gd")


func _ready() -> void:
	var inp := "user://biblioteca"
	var out := ""
	var opts := {}
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--in="):
			inp = a.substr(5)
		elif a.begins_with("--out="):
			out = a.substr(6)
		elif a.begins_with("--min-moved="):
			opts["min_moved"] = int(a.substr(12))
		elif a == "--compress":
			opts["compress"] = true
		elif a == "--prune":
			opts["prune"] = true
		elif a == "--polish":
			opts["polish"] = true
		elif a == "--verbose":
			opts["verbose"] = true
	if out == "":
		out = inp.path_join("biblioteca.rooms")
	var res := RoomPack.pack(inp, out, opts)
	print("[empaquetador] %d archivos, %d líneas leídas (%d malas), %d repetidas, %d con reglas viejas, %d inválidas, %d débiles -> %d salas en %s (%s)" % [res.files, res.read, res.bad, res.dup, res.old_rules, res.invalid, res.weak, res.kept, out, str(res.per_shape)])
	print("[empaquetador] antes:   ", RoomPack.stats_line(res.before))
	print("[empaquetador] después:  ", RoomPack.stats_line(res.after))
	print("[empaquetador] caminos acortados: %d · salas podadas: %d (%d bloques) · caminos mejorados con el verificador exacto: %d · repetidas tras podar: %d" % [int(res.get("shortened", 0)), int(res.pruned_rooms), int(res.pruned_blocks), int(res.polished), int(res.dup_after)])
	get_tree().quit(0 if res.written else 1)
