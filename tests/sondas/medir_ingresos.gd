extends SceneTree
## Mide lo que rinde una torre por etapa sin boosts, por el camino mínimo de cada sala y sin titubeos ni muertes (es lo que va en `RunState.INGRESO_MEDIDO`).
## Uso: GAME_SANDBOX=1 godot --headless --path . -s tests/sondas/medir_ingresos.gd [-- TORRES [DIFICULTAD]]   (por omisión 30 torres por etapa, en Medio)
const Bot := preload("res://scripts/herramientas/bot.gd")
const RunState := preload("res://scripts/datos/run_state.gd")
const Torre := preload("res://torre/torre.gd")


func _init() -> void:
	var args := OS.get_cmdline_user_args()
	var n := int(args[0]) if args.size() > 0 else 30
	var dif: String = args[1] if args.size() > 1 else "media"
	var paquete := Torre.cargar_paquete_del_juego()
	var rng := RandomNumberGenerator.new()
	rng.seed = 4242
	var cfg := Bot.default_config()
	cfg.die_per_bit = 0.0
	cfg.hesitate = 0.0
	var linea := []
	for etapa in range(1, 16):
		var total := 0.0
		var maximo := 0.0
		var cuenta := 0
		for k in n:
			var t = Torre.armar(paquete, rng.randi(), Torre.salas_de_etapa(etapa), true, etapa, dif)
			if t.salas.size() < 3:
				continue
			var run = RunState.new()
			run.stage = etapa
			var r: Dictionary = Bot.play_tower(t, run, rng, cfg)
			total += float(r.claridad)
			maximo = maxf(maximo, float(r.claridad))
			cuenta += 1
		var media := total / maxf(float(cuenta), 1.0)
		linea.append(int(round(media)))
		print("etapa %2d: %5.0f  (máximo %5.0f, %d torres)" % [etapa, media, maximo, cuenta])
	print("INGRESO_MEDIDO: ", linea)
	quit(0)
