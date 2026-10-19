extends RefCounted
## Música de fondo: cuatro pistas en bucle (menú, torre, casino y pruebas). Las del juego son Las Cuatro Estaciones de Vivaldi (dominio público; ver herramientas/musica/): Primavera en el menú, Verano en las torres, Otoño en los casinos e Invierno en las pruebas, en res://audio/music/*.ogg. Si falta el archivo, se sintetiza una pista simple por código. Se arman la primera vez que se piden, de a un
## compás por cuadro (así el juego no se traba) y quedan guardadas; al cambiar de pista hay un fundido. `Music.play("torre")`.
## Para reemplazar una pista por una real: un .ogg en res://audio/music/<pista>.ogg (o .wav) y se usa en su lugar.

const Synth := preload("res://scripts/synth.gd")
const AudioHub := preload("res://scripts/audio_hub.gd")
const W := Synth.Wave

const TRACKS: Array[String] = ["menu", "torre", "casino", "pruebas"]
const FILE_DIR := "res://audio/music/"

static var _cache := {}
static var current := ""        # la pista que se pidió (suene ya o se esté armando)
static var _building := ""


## Pone la pista `track` (con fundido). Si es la misma que ya suena no hace nada.
static func play(track: String) -> void:
	if track == current or not AudioHub.is_enabled():
		return
	current = track
	if _cache.has(track):
		_start(track)
	else:
		_build_async(track)


static func stop() -> void:
	current = ""
	var hub := AudioHub.instance()
	if hub != null and hub.is_inside_tree():
		hub.stop_music()


static func _start(track: String) -> void:
	var hub := AudioHub.instance()
	if hub == null:
		return
	if not hub.is_inside_tree():   # el nodo entra al árbol un instante después de crearse: se reintenta enseguida
		_start.call_deferred(track)
		return
	hub.crossfade_to(_cache[track])


static func _build_async(track: String) -> void:
	if _building != "":
		return   # ya se está armando una; al terminar se mira cuál es la pedida
	for ext in [".ogg", ".wav"]:
		if ResourceLoader.exists(FILE_DIR + track + ext):
			var s: AudioStream = load(FILE_DIR + track + ext)
			if s is AudioStreamOggVorbis:
				s.loop = true
			_cache[track] = s
			_start(track)
			return
	_building = track
	var tree := Engine.get_main_loop() as SceneTree
	var ctx := _begin(track)
	for b in int(ctx.bars.size()):   # un compás por cuadro
		_bar(track, ctx, b)
		await tree.process_frame
	_cache[track] = Synth.to_stream(ctx.buf, true)
	_building = ""
	if current == track:
		_start(track)
	elif current != "" and not _cache.has(current):
		_build_async(current)   # mientras tanto pidieron otra
	elif current != "":
		_start(current)


## Arma la pista de una vez (para las pruebas).
static func build(track: String) -> AudioStreamWAV:
	var ctx := _begin(track)
	for b in int(ctx.bars.size()):
		_bar(track, ctx, b)
	return Synth.to_stream(ctx.buf, true)


# --- las pistas -------------------------------------------------------------------------------------------------------

const MIN := [0, 3, 7]
const MAJ := [0, 4, 7]
const DOM7 := [0, 4, 7, 10]
const MIN7 := [0, 3, 7, 10]
const MAJ7 := [0, 4, 7, 11]


static func _beat(bpm: float) -> float:
	return 60.0 / bpm


## Prepara una pista: {bpm, beat, bars (acordes por compás: [nota raíz, acorde]), buf, rng}.
## menu: calma, La menor (colchón de triángulos, arpegio suave y bajo lento).
## torre: tensa, La menor (bajo que late, arpegio rápido y platillo en los contratiempos).
## casino: swing tranquilo, Re menor (bajo caminando, acordes en 2 y 4, escoba y una melodía de pentatónica).
static func _begin(track: String) -> Dictionary:
	var bpm := 72.0
	var bars: Array = [[57, MIN], [57, MIN], [53, MAJ], [53, MAJ], [48, MAJ], [48, MAJ], [55, MAJ], [55, MAJ]]
	var seed_value := 0
	match track:
		"torre", "pruebas":
			bpm = 108.0
			bars = [[57, MIN], [57, MIN], [53, MAJ], [55, MAJ], [57, MIN], [57, MIN], [53, MAJ], [52, MAJ]]
			seed_value = 21
		"casino":
			bpm = 100.0
			bars = [[50, MIN7], [55, DOM7], [48, MAJ7], [57, DOM7], [50, MIN7], [55, DOM7], [48, MAJ7], [48, MAJ7]]
			seed_value = 33
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_value
	var beat := _beat(bpm)
	return {"bpm": bpm, "beat": beat, "bars": bars, "buf": Synth.buffer(bars.size() * 4 * beat), "rng": rng}


## Escribe el compás `b` de la pista en el buffer.
static func _bar(track: String, ctx: Dictionary, b: int) -> void:
	match track:
		"torre", "pruebas":
			_bar_torre(ctx, b)
		"casino":
			_bar_casino(ctx, b)
		_:
			_bar_menu(ctx, b)


static func _bar_menu(ctx: Dictionary, b: int) -> void:
	var buf: PackedFloat32Array = ctx.buf
	var beat: float = ctx.beat
	var t0: float = b * 4 * beat
	var root: int = ctx.bars[b][0]
	var ch: Array = ctx.bars[b][1]
	for k in ch:
		Synth.add_note(buf, t0, 4 * beat, Synth.midi_hz(root + 12 + k), Synth.midi_hz(root + 12 + k), W.TRIANGLE, 0.06, 0.4, 0.6)
	for e in 8:   # arpegio de corcheas
		var idx: int = [0, 1, 2, 1, 2, 1, 0, 1][e]
		var note: int = root + 24 + int(ch[idx % ch.size()]) + (12 if e % 4 == 3 else 0)
		Synth.add_note(buf, t0 + e * beat * 0.5, beat * 0.45, Synth.midi_hz(note), Synth.midi_hz(note), W.SQUARE, 0.05, 0.004, 0.12, 0.25, 0.25)
	Synth.add_note(buf, t0, 2 * beat, Synth.midi_hz(root - 12), Synth.midi_hz(root - 12), W.TRIANGLE, 0.16, 0.02, 0.3)
	Synth.add_note(buf, t0 + 2 * beat, 2 * beat, Synth.midi_hz(root - 12 + ch[2]), Synth.midi_hz(root - 12 + ch[2]), W.TRIANGLE, 0.13, 0.02, 0.3)


static func _bar_torre(ctx: Dictionary, b: int) -> void:
	var buf: PackedFloat32Array = ctx.buf
	var beat: float = ctx.beat
	var rng: RandomNumberGenerator = ctx.rng
	var t0: float = b * 4 * beat
	var root: int = ctx.bars[b][0]
	var ch: Array = ctx.bars[b][1]
	for e in 8:   # bajo en corcheas, con la quinta cada tanto
		var note: int = root - 12 + (7 if e % 4 == 3 else 0)
		Synth.add_note(buf, t0 + e * beat * 0.5, beat * 0.4, Synth.midi_hz(note), Synth.midi_hz(note), W.TRIANGLE, 0.2, 0.005, 0.08, 0.2)
	for s in 16:   # arpegio de semicorcheas
		var idx: int = [0, 2, 1, 2, 0, 1, 2, 1][s % 8]
		var note: int = root + 24 + int(ch[idx])
		Synth.add_note(buf, t0 + s * beat * 0.25, beat * 0.2, Synth.midi_hz(note), Synth.midi_hz(note), W.SQUARE, 0.04, 0.003, 0.05, 0.1, 0.125)
	for h in 4:   # platillo en los contratiempos
		Synth.add_note(buf, t0 + (h + 0.5) * beat, 0.05, 0, 0, W.NOISE, 0.06, 0.001, 0.03, 0.02)
	if b % 2 == 1:   # melodía corta en los compases impares
		var scale := [0, 3, 5, 7, 10, 12]
		for m in 4:
			var note: int = root + 12 + int(scale[rng.randi() % scale.size()])
			Synth.add_note(buf, t0 + m * beat, beat * 0.8, Synth.midi_hz(note), Synth.midi_hz(note), W.SQUARE, 0.045, 0.01, 0.2, 0.3, 0.5)


static func _bar_casino(ctx: Dictionary, b: int) -> void:
	var buf: PackedFloat32Array = ctx.buf
	var beat: float = ctx.beat
	var rng: RandomNumberGenerator = ctx.rng
	var t0: float = b * 4 * beat
	var root: int = ctx.bars[b][0]
	var ch: Array = ctx.bars[b][1]
	var penta := [0, 2, 4, 7, 9, 12, 14]
	var swing := beat * 0.18   # las corcheas de contratiempo llegan tarde
	var walk := [0, ch[1], ch[2], ch[1]]   # raíz, tercera, quinta, tercera
	for q in 4:
		var note: int = root - 12 + int(walk[q])
		Synth.add_note(buf, t0 + q * beat, beat * 0.85, Synth.midi_hz(note), Synth.midi_hz(note), W.TRIANGLE, 0.22, 0.008, 0.08, 0.35)
	for q in [1, 3]:   # acordes en 2 y 4
		for k in ch:
			Synth.add_note(buf, t0 + q * beat + swing * 0.3, beat * 0.3, Synth.midi_hz(root + 12 + int(k)), Synth.midi_hz(root + 12 + int(k)), W.SQUARE, 0.03, 0.004, 0.08, 0.1, 0.5)
	for q in 4:   # escoba: pulso y contratiempo con swing
		Synth.add_note(buf, t0 + q * beat, 0.05, 0, 0, W.NOISE, 0.05, 0.001, 0.03, 0.02)
		Synth.add_note(buf, t0 + q * beat + beat * 0.5 + swing, 0.04, 0, 0, W.NOISE, 0.035, 0.001, 0.02, 0.015)
	var pos := 0.0
	while pos < 4.0:   # melodía: notas sueltas de la pentatónica
		if rng.randf() < 0.62:
			var note: int = root + 24 + int(penta[rng.randi() % penta.size()])
			var dur: float = [0.5, 0.5, 1.0][rng.randi() % 3]
			var off: float = swing if fmod(pos, 1.0) > 0.4 else 0.0
			Synth.add_note(buf, t0 + pos * beat + off, dur * beat * 0.9, Synth.midi_hz(note), Synth.midi_hz(note), W.SQUARE, 0.05, 0.01, 0.12, 0.25, 0.25)
			pos += dur
		else:
			pos += 0.5
