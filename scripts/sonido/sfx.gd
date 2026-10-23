extends RefCounted
## Efectos de sonido, sintetizados por código (synth.gd): `Sfx.play("click")`. Cada nombre de NAMES tiene su receta en `build`;
## el sonido se arma la primera vez que se pide y se guarda. `pitch` cambia el tono (por ejemplo la racha sube el de "purify").
## Para reemplazar un efecto por un archivo real: poner un .ogg o .wav en res://audio/sfx/<nombre> y se usa en su lugar.

const Synth := preload("res://scripts/sonido/synth.gd")
const AudioHub := preload("res://scripts/sonido/audio_hub.gd")
const W := Synth.Wave

const NAMES: Array[String] = [
	"click", "hover", "step", "push", "pull", "climb", "hang", "purify", "slide", "boing", "crumble", "spikes", "fall", "boom",
	"win", "lose", "tick", "rumble", "dice", "ding", "miss", "coin", "chip", "reel_stop", "reel_tick", "jackpot", "card", "flip",
	"blip", "portal", "item", "defuse", "tic", "tac",
]
const FILE_DIR := "res://audio/sfx/"

static var _cache := {}


static func play(sound: String, pitch := 1.0, volume_db := 0.0) -> void:
	var hub := AudioHub.instance()
	if hub == null or not hub.is_inside_tree():   # (el nodo entra al árbol un instante después de crearse)
		return
	hub.play_sfx(stream(sound), pitch, volume_db)


## El sonido `sound` (un archivo real si existe; si no, el sintetizado).
static func stream(sound: String) -> AudioStream:
	if _cache.has(sound):
		return _cache[sound]
	var s: AudioStream = null
	for ext in [".ogg", ".wav"]:
		if ResourceLoader.exists(FILE_DIR + sound + ext):
			s = load(FILE_DIR + sound + ext)
			break
	if s == null:
		s = build(sound)
	_cache[sound] = s
	return s


## Arma el sonido sintetizado: una lista de notas sobre un buffer corto.
static func build(sound: String) -> AudioStreamWAV:
	var b: PackedFloat32Array
	match sound:
		"click":
			b = Synth.buffer(0.08)
			Synth.add_note(b, 0.0, 0.06, 900, 600, W.SQUARE, 0.22, 0.002, 0.02, 0.03, 0.25)
		"hover":
			b = Synth.buffer(0.05)
			Synth.add_note(b, 0.0, 0.03, 1300, 1300, W.TRIANGLE, 0.1, 0.002, 0.015)
		"step":
			b = Synth.buffer(0.1)
			Synth.add_note(b, 0.0, 0.07, 140, 80, W.TRIANGLE, 0.35, 0.002, 0.03, 0.03)
			Synth.add_note(b, 0.0, 0.04, 0, 0, W.NOISE, 0.12, 0.001, 0.02, 0.012)
		"push":
			b = Synth.buffer(0.3)
			Synth.add_note(b, 0.0, 0.22, 100, 55, W.TRIANGLE, 0.5, 0.004, 0.08, 0.1)
			Synth.add_note(b, 0.0, 0.18, 0, 0, W.NOISE, 0.16, 0.003, 0.08, 0.06)
		"pull":
			b = Synth.buffer(0.3)
			Synth.add_note(b, 0.0, 0.22, 55, 105, W.TRIANGLE, 0.5, 0.004, 0.08, 0.1)
			Synth.add_note(b, 0.0, 0.18, 0, 0, W.NOISE, 0.14, 0.003, 0.08, 0.06)
		"climb":
			b = Synth.buffer(0.15)
			Synth.add_note(b, 0.0, 0.1, 230, 340, W.TRIANGLE, 0.35, 0.004, 0.04, 0.06)
		"hang":
			b = Synth.buffer(0.2)
			Synth.add_note(b, 0.0, 0.14, 320, 190, W.SQUARE, 0.18, 0.004, 0.06, 0.07, 0.3)
		"purify":
			b = Synth.buffer(0.35)
			Synth.add_note(b, 0.0, 0.22, 660, 990, W.SINE, 0.32, 0.004, 0.1, 0.09)
			Synth.add_note(b, 0.06, 0.2, 1320, 1320, W.SINE, 0.2, 0.004, 0.1, 0.07)
		"slide":
			b = Synth.buffer(0.35)
			Synth.add_note(b, 0.0, 0.3, 0, 0, W.NOISE, 0.1, 0.02, 0.1)
			Synth.add_note(b, 0.0, 0.3, 1000, 520, W.SINE, 0.12, 0.02, 0.1)
		"boing":
			b = Synth.buffer(0.35)
			Synth.add_note(b, 0.0, 0.28, 180, 760, W.SQUARE, 0.22, 0.004, 0.08, 0.2, 0.4)
		"crumble":
			b = Synth.buffer(0.5)
			Synth.add_note(b, 0.0, 0.4, 0, 0, W.NOISE, 0.45, 0.003, 0.1, 0.12)
			Synth.add_note(b, 0.0, 0.35, 150, 50, W.TRIANGLE, 0.4, 0.004, 0.1, 0.15)
		"spikes":
			b = Synth.buffer(0.45)
			Synth.add_note(b, 0.0, 0.35, 320, 70, W.SAW, 0.3, 0.003, 0.1, 0.14)
			Synth.add_note(b, 0.0, 0.12, 0, 0, W.NOISE, 0.3, 0.002, 0.05, 0.05)
		"fall":
			b = Synth.buffer(0.75)
			Synth.add_note(b, 0.0, 0.65, 620, 70, W.SINE, 0.4, 0.01, 0.2)
		"boom":
			b = Synth.buffer(1.0)
			Synth.add_note(b, 0.0, 0.9, 0, 0, W.NOISE, 0.5, 0.002, 0.3, 0.25)
			Synth.add_note(b, 0.0, 0.9, 85, 28, W.TRIANGLE, 0.45, 0.003, 0.3, 0.3)
		"win":
			b = Synth.buffer(0.7)
			for i in 4:
				Synth.add_note(b, i * 0.1, 0.22, Synth.midi_hz([72, 76, 79, 84][i]), Synth.midi_hz([72, 76, 79, 84][i]), W.SQUARE, 0.2, 0.004, 0.1, 0.12, 0.25)
		"lose":
			b = Synth.buffer(0.7)
			Synth.add_note(b, 0.0, 0.3, 300, 200, W.TRIANGLE, 0.4, 0.01, 0.1)
			Synth.add_note(b, 0.25, 0.4, 210, 90, W.TRIANGLE, 0.4, 0.01, 0.2)
		"tick":
			b = Synth.buffer(0.04)
			Synth.add_note(b, 0.0, 0.02, 1700, 1500, W.SQUARE, 0.18, 0.001, 0.01, 0.0, 0.3)
		"rumble":
			b = Synth.buffer(0.7)
			Synth.add_note(b, 0.0, 0.6, 0, 0, W.NOISE, 0.35, 0.02, 0.25, 0.2)
			Synth.add_note(b, 0.0, 0.6, 58, 40, W.TRIANGLE, 0.5, 0.02, 0.25)
		"dice":
			b = Synth.buffer(0.5)
			var rng := RandomNumberGenerator.new()
			rng.seed = 7
			for i in 9:
				var t := 0.04 * i + rng.randf() * 0.025
				Synth.add_note(b, t, 0.03, 0, 0, W.NOISE, 0.28, 0.001, 0.015, 0.01)
				Synth.add_note(b, t, 0.03, 400 + rng.randf() * 500, 300, W.TRIANGLE, 0.15, 0.001, 0.015)
		"ding":
			b = Synth.buffer(0.4)
			Synth.add_note(b, 0.0, 0.35, 1320, 1320, W.SINE, 0.3, 0.002, 0.1, 0.1)
			Synth.add_note(b, 0.0, 0.3, 1980, 1980, W.SINE, 0.1, 0.002, 0.1, 0.07)
		"miss":
			b = Synth.buffer(0.3)
			Synth.add_note(b, 0.0, 0.22, 210, 120, W.TRIANGLE, 0.32, 0.005, 0.08)
		"coin":
			b = Synth.buffer(0.35)
			Synth.add_note(b, 0.0, 0.06, 988, 988, W.SQUARE, 0.18, 0.002, 0.02, 0.0, 0.25)
			Synth.add_note(b, 0.06, 0.28, 1319, 1319, W.SQUARE, 0.18, 0.002, 0.1, 0.1, 0.25)
		"chip":
			b = Synth.buffer(0.12)
			Synth.add_note(b, 0.0, 0.05, 0, 0, W.NOISE, 0.2, 0.001, 0.02, 0.015)
			Synth.add_note(b, 0.0, 0.08, 2100, 1500, W.SINE, 0.16, 0.001, 0.04, 0.03)
		"reel_stop":
			b = Synth.buffer(0.2)
			Synth.add_note(b, 0.0, 0.14, 170, 95, W.TRIANGLE, 0.5, 0.002, 0.05, 0.06)
			Synth.add_note(b, 0.0, 0.04, 0, 0, W.NOISE, 0.2, 0.001, 0.02, 0.01)
		"reel_tick":
			b = Synth.buffer(0.03)
			Synth.add_note(b, 0.0, 0.015, 650, 600, W.SQUARE, 0.12, 0.001, 0.008, 0.0, 0.3)
		"jackpot":
			b = Synth.buffer(1.6)
			for i in 10:
				var n: float = [72, 76, 79, 84, 79, 84, 88, 91, 88, 96][i]
				Synth.add_note(b, i * 0.1, 0.4, Synth.midi_hz(n), Synth.midi_hz(n), W.SQUARE, 0.17, 0.004, 0.15, 0.2, 0.25)
				Synth.add_note(b, i * 0.1, 0.3, Synth.midi_hz(n + 12), Synth.midi_hz(n + 12), W.SINE, 0.08, 0.004, 0.12, 0.1)
		"card":
			b = Synth.buffer(0.12)
			Synth.add_note(b, 0.0, 0.07, 0, 0, W.NOISE, 0.3, 0.001, 0.03, 0.02)
			Synth.add_note(b, 0.0, 0.06, 800, 450, W.SINE, 0.1, 0.001, 0.03, 0.03)
		"flip":
			b = Synth.buffer(0.15)
			Synth.add_note(b, 0.0, 0.05, 0, 0, W.NOISE, 0.22, 0.001, 0.02, 0.015)
			Synth.add_note(b, 0.05, 0.05, 0, 0, W.NOISE, 0.22, 0.001, 0.02, 0.015)
		"blip":
			b = Synth.buffer(0.05)
			Synth.add_note(b, 0.0, 0.03, 620, 560, W.SQUARE, 0.1, 0.002, 0.012, 0.0, 0.25)
		"portal":
			b = Synth.buffer(0.9)
			Synth.add_note(b, 0.0, 0.8, 280, 1250, W.SINE, 0.32, 0.05, 0.3)
			Synth.add_note(b, 0.1, 0.7, 560, 2500, W.TRIANGLE, 0.1, 0.05, 0.3)
		"defuse":   # una mecha que se apaga: chisporroteo que se va apagando y un último "pfff" hacia abajo
			b = Synth.buffer(0.7)
			Synth.add_note(b, 0.0, 0.5, 0, 0, W.NOISE, 0.32, 0.005, 0.25, 0.22)
			Synth.add_note(b, 0.0, 0.12, 0, 0, W.NOISE, 0.3, 0.002, 0.04, 0.05)
			Synth.add_note(b, 0.05, 0.55, 2400, 300, W.SINE, 0.1, 0.01, 0.3)
			var rng2 := RandomNumberGenerator.new()
			rng2.seed = 4
			for i in 7:   # chispitas
				Synth.add_note(b, 0.02 + i * 0.045 + rng2.randf() * 0.02, 0.012, 0, 0, W.NOISE, 0.22 * (1.0 - i / 9.0), 0.001, 0.006)
		"tic":   # el tic de la bomba (madera)
			b = Synth.buffer(0.08)
			Synth.add_note(b, 0.0, 0.05, 1900, 1300, W.SQUARE, 0.2, 0.001, 0.02, 0.012, 0.3)
			Synth.add_note(b, 0.0, 0.02, 0, 0, W.NOISE, 0.1, 0.001, 0.01)
		"tac":   # y el tac, un poco más grave
			b = Synth.buffer(0.09)
			Synth.add_note(b, 0.0, 0.06, 1350, 850, W.SQUARE, 0.2, 0.001, 0.025, 0.015, 0.3)
			Synth.add_note(b, 0.0, 0.02, 0, 0, W.NOISE, 0.1, 0.001, 0.01)
		"item":
			b = Synth.buffer(0.3)
			Synth.add_note(b, 0.0, 0.1, 784, 784, W.SQUARE, 0.16, 0.003, 0.04, 0.05, 0.25)
			Synth.add_note(b, 0.09, 0.18, 1175, 1175, W.SQUARE, 0.16, 0.003, 0.08, 0.08, 0.25)
		_:
			b = Synth.buffer(0.05)
	return Synth.to_stream(b)
