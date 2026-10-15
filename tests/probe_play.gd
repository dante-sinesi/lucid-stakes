extends SceneTree
const StudioModel := preload("res://scripts/studio_model.gd")
func _init() -> void:
	var m := StudioModel.new()
	m.load_file(OS.get_environment("LIB"))
	for r in m.rooms:
		if str(r.id).begins_with(OS.get_environment("ID")):
			m.open(r.id)
			break
	m.play_to(m.current.path.size())
	var s = m.play_state
	print("pasos ", m.current.path.size(), " indice ", m.play_index, " gano ", s.won, " perdio ", s.lost, " jugador ", s.player)
	quit(0)
