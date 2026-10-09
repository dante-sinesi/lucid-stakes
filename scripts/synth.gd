extends RefCounted
## Sintetizador mínimo: arma sonidos con ondas simples (cuadrada, triangular, sierra, seno y ruido) y los convierte en un
## AudioStreamWAV. Todo el audio del juego sale de acá (sfx.gd, music.gd): no hay archivos de sonido.

const RATE := 22050

enum Wave { SQUARE, TRIANGLE, SAW, SINE, NOISE }


static func buffer(seconds: float) -> PackedFloat32Array:
	var b := PackedFloat32Array()
	b.resize(maxi(int(seconds * RATE), 1))
	return b


## Suma una nota a `buf`: empieza en `start` segundos, dura `dur`, su frecuencia va de `f0` a `f1` (igual: nota fija), con volumen `vol`.
## attack/release: rampas de entrada y salida (s). decay: constante de caída exponencial (s; 0 = sin caída). duty: ancho de la cuadrada.
static func add_note(buf: PackedFloat32Array, start: float, dur: float, f0: float, f1: float, wave: int, vol: float,
		attack := 0.004, release := 0.03, decay := 0.0, duty := 0.5) -> void:
	var first := int(start * RATE)
	var n := int(dur * RATE)
	if n <= 0 or first >= buf.size():
		return
	n = mini(n, buf.size() - first)
	var phase := 0.0
	var seed_state := 12345 + first
	var noise_val := 0.0
	for i in n:
		var t := float(i) / RATE
		var u := float(i) / float(n)
		var f := f0 + (f1 - f0) * u
		phase += f / RATE
		phase -= floorf(phase)
		var s := 0.0
		match wave:
			Wave.SQUARE:
				s = 1.0 if phase < duty else -1.0
			Wave.TRIANGLE:
				s = 4.0 * absf(phase - 0.5) - 1.0
			Wave.SAW:
				s = 2.0 * phase - 1.0
			Wave.SINE:
				s = sin(phase * TAU)
			_:
				seed_state = (seed_state * 1103515245 + 12345) & 0x7fffffff
				if i % 3 == 0:   # el ruido se "mantiene" un poco: suena menos agudo
					noise_val = float(seed_state & 0xffff) / 32768.0 - 1.0
				s = noise_val
		var env := 1.0
		if attack > 0.0 and t < attack:
			env = t / attack
		var left := dur - t
		if release > 0.0 and left < release:
			env = minf(env, left / release)
		if decay > 0.0:
			env *= exp(-t / decay)
		buf[first + i] += s * vol * env


## Pasa el buffer (muestras de -1 a 1) a un AudioStreamWAV de 16 bits; con `loop` se repite sin cortes.
static func to_stream(buf: PackedFloat32Array, loop := false) -> AudioStreamWAV:
	var bytes := PackedByteArray()
	bytes.resize(buf.size() * 2)
	for i in buf.size():
		bytes.encode_s16(i * 2, int(clampf(buf[i], -1.0, 1.0) * 32767.0))
	var w := AudioStreamWAV.new()
	w.format = AudioStreamWAV.FORMAT_16_BITS
	w.mix_rate = RATE
	w.stereo = false
	w.data = bytes
	if loop:
		w.loop_mode = AudioStreamWAV.LOOP_FORWARD
		w.loop_begin = 0
		w.loop_end = buf.size()
	return w


## Frecuencia de una nota MIDI (69 = La 440).
static func midi_hz(note: float) -> float:
	return 440.0 * pow(2.0, (note - 69.0) / 12.0)
