extends Node
## Plays original Trickster sounds and music from original_assets/audio
## (autoloaded as `Audio`). Missing files are skipped silently so the game
## still runs without generated assets.

const DIR := "res://original_assets/audio/"
const POOL_SIZE := 12

var _players: Array[AudioStreamPlayer] = []
var _cache: Dictionary = {}
var _next := 0
var _music: AudioStreamPlayer
var _ambience: AudioStreamPlayer


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	for i in POOL_SIZE:
		var p := AudioStreamPlayer.new()
		add_child(p)
		_players.append(p)
	_music = AudioStreamPlayer.new()
	_music.volume_db = -10.0
	add_child(_music)
	_ambience = AudioStreamPlayer.new()
	_ambience.volume_db = -16.0
	add_child(_ambience)


func _stream(file: String) -> AudioStream:
	if file.is_empty():
		return null
	if not _cache.has(file):
		var path := DIR + file
		_cache[file] = load(path) if ResourceLoader.exists(path) else null
	return _cache[file]


func play(file: String, volume_db := 0.0, pitch_jitter := 0.06) -> void:
	var s := _stream(file)
	if s == null:
		return
	var p := _players[_next]
	_next = (_next + 1) % POOL_SIZE
	p.stream = s
	p.volume_db = volume_db
	p.pitch_scale = 1.0 + randf_range(-pitch_jitter, pitch_jitter)
	p.play()


func play_music(file: String) -> void:
	_loop(_music, file)


func play_ambience(file: String) -> void:
	_loop(_ambience, file)


func _loop(player: AudioStreamPlayer, file: String) -> void:
	var s := _stream(file)
	if s == null or player.stream == s:
		return
	if s is AudioStreamMP3:
		(s as AudioStreamMP3).loop = true
	elif s is AudioStreamWAV:
		var wav := s as AudioStreamWAV
		wav.loop_mode = AudioStreamWAV.LOOP_FORWARD
		wav.loop_end = int(wav.get_length() * wav.mix_rate)
	player.stream = s
	player.play()
