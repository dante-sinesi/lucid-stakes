extends SceneTree
## Mide los FPS con cada preajuste de calidad (con ventana, sin límite de cuadros ni sincronía vertical; usa y deja limpio el archivo de ajustes).
## Correr con GAME_SANDBOX=1 para no tocar los archivos reales del jugador.
## Uso: ... --rendering-driver opengl3 --resolution 1920x1080 -s tests/bench_graphics.gd
const Settings := preload("res://scripts/settings.gd")
const Graphics := preload("res://scripts/graphics.gd")
func _init() -> void:
	var main = load("res://scenes/main.tscn").instantiate()
	main.quit_game_override = true
	root.add_child(main)
	for i in 20: await process_frame
	main.dev_lab("")
	for i in 60: await process_frame
	Settings.set_value("vsync", false)
	for p in ["alta", "media", "baja", "minimo"]:
		Graphics.set_preset("baja" if p == "minimo" else p)
		if p == "minimo":
			Graphics.set_value("scale", 50)
		Graphics.set_value("fps_cap", 0)
		for i in 60: await process_frame
		var t0 := Time.get_ticks_usec()
		var n := 240
		for i in n: await process_frame
		print("%s: %.1f FPS (shadow=%s scale=%.2f msaa=%d max_fps=%d vsync=%d proc=%.1fms draws=%d)" % [p, n * 1e6 / float(Time.get_ticks_usec() - t0), Graphics.value("shadows"), root.scaling_3d_scale, root.msaa_3d, Engine.max_fps, DisplayServer.window_get_vsync_mode(), Performance.get_monitor(Performance.TIME_PROCESS) * 1000.0, Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME)])
	if Settings.path.contains("test_"):   # (nunca se borran los ajustes reales: correr con GAME_SANDBOX=1)
		DirAccess.remove_absolute(ProjectSettings.globalize_path(Settings.path))
	quit()
