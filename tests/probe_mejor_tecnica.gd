extends SceneTree
## Para cada técnica (i hielo patina, c arenisca, k catapulta salta, t trampa se desarma, s pinchos se cuelga) la sala de mayor dificultad de la biblioteca que la tiene necesaria Y la usa de verdad. LIB (.jsonl).
const RoomLib := preload("res://scripts/room_lib.gd")


func _init() -> void:
	var rooms: Array = RoomLib.read_file(OS.get_environment("LIB")).rooms
	var best := {}
	var count := {}
	for r in rooms:
		var chars := ""
		for c in r.cols:
			chars += String(r.cols[c])
		for ch in ["i", "c", "k", "t", "s"]:
			if not chars.contains(ch):
				continue
			if not RoomLib.uses_technique(r, ch):
				continue
			count[ch] = int(count.get(ch, 0)) + 1
			var df := float(r.opt.get("diff", 0.0))
			if not best.has(ch) or df > float(best[ch].diff):
				best[ch] = {"diff": df, "shape": r.shape, "h": r.h, "grabs": int(r.opt.grabs), "moves": int(r.opt.moves), "id": str(r.id).substr(0, 8)}
	for ch in best:
		print("TEC ", ch, " usan: ", count[ch], " mejor: ", best[ch])
	quit(0)
