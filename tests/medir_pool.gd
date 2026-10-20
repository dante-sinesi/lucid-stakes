extends SceneTree
## Cuánto tarda en cargarse la biblioteca del juego (RoomPool.all) y cuánta memoria ocupa.
const RoomPool := preload("res://scripts/room_pool.gd")
func _init() -> void:
	var m0 := OS.get_static_memory_usage()
	var t0 := Time.get_ticks_msec()
	var all := RoomPool.all()
	var secs := float(Time.get_ticks_msec() - t0) / 1000.0
	var m1 := OS.get_static_memory_usage()
	print("salas en el pool: %d · carga %.1f s · memoria %.0f MB" % [all.size(), secs, float(m1 - m0) / 1048576.0])
	quit(0)
