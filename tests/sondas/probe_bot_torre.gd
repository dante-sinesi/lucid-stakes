extends SceneTree
const Bot := preload("res://scripts/herramientas/bot.gd")
const RunState := preload("res://scripts/datos/run_state.gd")
const Torre := preload("res://torre/torre.gd")
func _init() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 5
	var paquete := Torre.cargar_paquete_del_juego()
	var cfg := Bot.default_config()
	var causas := {}
	var muertes := 0
	var torres := 0
	for i in 40:
		var run = RunState.new()
		run.stage = 1
		var t = Torre.armar(paquete, rng.randi(), 5, true, 1)
		var res := Bot.play_tower(t, run, rng, cfg)
		torres += 1
		muertes += int(res.room_deaths)
		for r in res.rooms:
			if not r.ok:
				causas[str(r.nivel)] = int(causas.get(str(r.nivel), 0)) + 1
	print("torres ", torres, " muertes ", muertes, " ", causas)
	quit(0)
