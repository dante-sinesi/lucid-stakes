extends SceneTree
## Cuánto tarda en cargarse la biblioteca del juego por etapa (RoomPool.candidates) y cuánta memoria ocupa.
const RoomPool := preload("res://scripts/room_pool.gd")
const Gen := preload("res://scripts/tower_gen.gd")
func _init() -> void:
	print("biblioteca por archivos: %s" % str(RoomPool.has_library()))
	for stage in [1, 4, 8, 12, 15, 1]:
		var m0 := OS.get_static_memory_usage()
		var t0 := Time.get_ticks_msec()
		var c := RoomPool.candidates(Gen.difficulty_for_stage(stage), 4)
		var secs := float(Time.get_ticks_msec() - t0) / 1000.0
		print("etapa %2d: %5d salas candidatas · %.2f s · memoria en uso %.0f MB (en caché %d archivos)" % [stage, c.size(), secs, float(OS.get_static_memory_usage()) / 1048576.0, RoomPool._chunk_order.size()])
	quit(0)
