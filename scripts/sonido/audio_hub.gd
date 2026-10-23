extends Node
## Nodo único del audio: los reproductores de efectos y los dos de música (para pasar de una pista a otra con fundido) y los buses
## "Musica" y "Efectos" (que cuelgan de "Master"; sus volúmenes salen de los ajustes, ver Settings.apply).
## Sin pantalla (headless, pruebas) no suena nada, salvo que una prueba prenda `forced`.

const BUS_MUSIC := "Musica"
const BUS_SFX := "Efectos"
const SFX_VOICES := 12
const MUSIC_DB := -12.0   # la música va baja: acompaña, no tapa los efectos

static var forced := false
static var _inst: Node

var sfx_players: Array[AudioStreamPlayer] = []
var music_players: Array[AudioStreamPlayer] = []
var _active := 0                 # cuál de los dos reproductores de música es el que suena
var _fade_tween: Tween


static func is_enabled() -> bool:
	return forced or DisplayServer.get_name() != "headless"


## Crea los buses si no existen (idempotente).
static func ensure_buses() -> void:
	for bus_name in [BUS_MUSIC, BUS_SFX]:
		if AudioServer.get_bus_index(bus_name) < 0:
			AudioServer.add_bus()
			var idx := AudioServer.bus_count - 1
			AudioServer.set_bus_name(idx, bus_name)
			AudioServer.set_bus_send(idx, "Master")


## El nodo del audio (se crea al primer uso y cuelga de la raíz del árbol).
static func instance() -> Node:
	if _inst != null and is_instance_valid(_inst):
		return _inst
	var tree := Engine.get_main_loop() as SceneTree
	if tree == null or not is_enabled():
		return null
	ensure_buses()
	_inst = (load("res://scripts/sonido/audio_hub.gd") as GDScript).new()
	_inst.name = "audio"
	_inst.process_mode = Node.PROCESS_MODE_ALWAYS   # la música y los efectos siguen con el juego en pausa
	tree.root.add_child.call_deferred(_inst)
	return _inst


func _init() -> void:
	for i in SFX_VOICES:
		var p := AudioStreamPlayer.new()
		p.bus = BUS_SFX
		sfx_players.append(p)
		add_child(p)
	for i in 2:
		var m := AudioStreamPlayer.new()
		m.bus = BUS_MUSIC
		m.volume_db = -80.0
		music_players.append(m)
		add_child(m)


func play_sfx(stream: AudioStream, pitch: float, volume_db: float) -> void:
	var chosen: AudioStreamPlayer = null
	for p in sfx_players:
		if not p.playing:
			chosen = p
			break
	if chosen == null:
		chosen = sfx_players[0]   # todos ocupados: se corta el más viejo
		sfx_players.append(sfx_players.pop_front())
	chosen.stream = stream
	chosen.pitch_scale = pitch
	chosen.volume_db = volume_db
	chosen.play()


## Pasa a la pista `stream` con un fundido (la anterior baja y esta sube).
func crossfade_to(stream: AudioStream, seconds := 1.2) -> void:
	var old: AudioStreamPlayer = music_players[_active]
	_active = 1 - _active
	var nw: AudioStreamPlayer = music_players[_active]
	nw.stream = stream
	nw.volume_db = -80.0
	nw.play()
	if _fade_tween != null:
		_fade_tween.kill()
	_fade_tween = create_tween().set_parallel(true)
	_fade_tween.tween_property(nw, "volume_db", MUSIC_DB, seconds)
	if old.playing:
		_fade_tween.tween_property(old, "volume_db", -80.0, seconds)
		_fade_tween.chain().tween_callback(old.stop)


func stop_music(seconds := 0.8) -> void:
	var cur: AudioStreamPlayer = music_players[_active]
	if not cur.playing:
		return
	if _fade_tween != null:
		_fade_tween.kill()
	_fade_tween = create_tween()
	_fade_tween.tween_property(cur, "volume_db", -80.0, seconds)
	_fade_tween.tween_callback(cur.stop)
