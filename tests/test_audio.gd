extends SceneTree
## Pruebas del audio sintetizado: todos los efectos y las tres pistas se arman, no están en silencio ni se pasan de volumen,
## y los buses y volúmenes de los ajustes funcionan.
## Ejecutar: tools/Godot_v4.7.2-stable_win64_console.exe --headless --path . -s tests/test_audio.gd

const Synth := preload("res://scripts/synth.gd")
const Sfx := preload("res://scripts/sfx.gd")
const Music := preload("res://scripts/music.gd")
const AudioHub := preload("res://scripts/audio_hub.gd")
const Settings := preload("res://scripts/settings.gd")

var fails := 0


func check(cond: bool, label: String) -> void:
	if not cond:
		fails += 1
		print("FAIL: ", label)


## (pico, cantidad de muestras que no son cero) de un AudioStreamWAV de 16 bits.
func stats(w: AudioStreamWAV) -> Vector2i:
	var peak := 0
	var nonzero := 0
	var n := w.data.size() / 2
	for i in n:
		var v := absi(w.data.decode_s16(i * 2))
		peak = maxi(peak, v)
		if v > 0:
			nonzero += 1
	return Vector2i(peak, nonzero)


func _init() -> void:
	for sound in Sfx.NAMES:
		var s := Sfx.build(sound)
		check(s.data.size() > 100, "%s: tiene muestras" % sound)
		var st := stats(s)
		check(st.x > 1500, "%s: se oye (pico %d)" % [sound, st.x])
		check(st.x < 32760, "%s: no se pasa de volumen (pico %d)" % [sound, st.x])
		check(float(s.data.size()) / 2.0 / Synth.RATE < 2.0, "%s: es corto" % sound)
		check(Sfx.stream(sound) == Sfx.stream(sound), "%s: se arma una sola vez" % sound)
	check(Sfx.build("no_existe").data.size() > 0, "un nombre desconocido no rompe")

	# Pistas: bucle, 8 compases, con volumen razonable.
	for track in Music.TRACKS:
		var t0 := Time.get_ticks_msec()
		var m := Music.build(track)
		var secs := float(m.data.size()) / 2.0 / Synth.RATE
		var st := stats(m)
		print("pista %s: %.1f s armada en %d ms" % [track, secs, Time.get_ticks_msec() - t0])
		check(m.loop_mode == AudioStreamWAV.LOOP_FORWARD and m.loop_end > 0, "%s: es un bucle" % track)
		check(secs > 12.0 and secs < 30.0, "%s: dura unos 15 a 25 segundos (%.1f)" % [track, secs])
		check(st.x > 3000 and st.x < 32000, "%s: volumen razonable (pico %d)" % [track, st.x])
		check(st.y > m.data.size() / 4, "%s: suena casi todo el tiempo" % track)

	# Buses y volúmenes
	Settings.headless_io = true
	Settings.path = "user://test_settings.json"
	Settings.load_settings()
	Settings.apply()
	check(AudioServer.get_bus_index("Musica") >= 0 and AudioServer.get_bus_index("Efectos") >= 0, "existen los buses de musica y efectos")
	Settings.set_value("music", 0)
	check(AudioServer.is_bus_mute(AudioServer.get_bus_index("Musica")), "musica en 0: el bus se silencia")
	Settings.set_value("music", 5)
	check(not AudioServer.is_bus_mute(AudioServer.get_bus_index("Musica")) and AudioServer.get_bus_volume_db(AudioServer.get_bus_index("Musica")) < -5.0, "musica a la mitad: baja unos 6 dB")
	Settings.set_value("sfx", 10)
	check(is_equal_approx(AudioServer.get_bus_volume_db(AudioServer.get_bus_index("Efectos")), 0.0), "efectos al maximo: 0 dB")
	Settings.set_value("music", 10)

	# Sin pantalla no suena nada ni falla
	AudioHub.forced = false
	Sfx.play("click")
	Music.play("menu")
	check(true, "play sin audio no falla")
	print("tests del audio terminados, fallos: ", fails)
	quit(1 if fails > 0 else 0)
