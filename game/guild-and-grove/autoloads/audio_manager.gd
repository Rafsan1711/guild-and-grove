extends Node

var _music_player: AudioStreamPlayer
var _sfx_player: AudioStreamPlayer
var music_volume_db: float = -14.0
var sfx_volume_db: float = -5.0
var _current_music_path: String = ""

func _ready() -> void:
	_music_player = AudioStreamPlayer.new()
	_music_player.bus = "Music"
	add_child(_music_player)
	_sfx_player = AudioStreamPlayer.new()
	_sfx_player.bus = "SFX"
	add_child(_sfx_player)
	_music_player.volume_db = music_volume_db
	_sfx_player.volume_db = sfx_volume_db

func play_music(path: String, fade_in: float = 1.0) -> void:
	if _current_music_path == path and _music_player.playing:
		return
	_current_music_path = path
	var stream = load(path)
	if stream == null:
		push_error("AudioManager: Cannot load " + path)
		return
	if _music_player.playing:
		# FIX: renamed to tween_out to avoid duplicate 'var t' in same scope
		var tween_out = create_tween()
		tween_out.tween_property(_music_player, "volume_db", -80.0, 0.5)
		await tween_out.finished
	_music_player.stream = stream
	_music_player.volume_db = -80.0
	_music_player.play()
	# FIX: renamed to tween_in — no longer conflicts
	var tween_in = create_tween()
	tween_in.tween_property(_music_player, "volume_db", music_volume_db, fade_in)

func stop_music(fade_out: float = 1.0) -> void:
	if not _music_player.playing:
		return
	var t = create_tween()
	t.tween_property(_music_player, "volume_db", -80.0, fade_out)
	t.tween_callback(_music_player.stop)
	_current_music_path = ""

func play_sfx(path: String) -> void:
	var stream = load(path)
	if stream:
		_sfx_player.stream = stream
		_sfx_player.play()

func set_music_volume(value: float) -> void:
	music_volume_db = linear_to_db(maxf(value, 0.001))
	if _music_player.playing:
		_music_player.volume_db = music_volume_db

func set_sfx_volume(value: float) -> void:
	sfx_volume_db = linear_to_db(maxf(value, 0.001))
	_sfx_player.volume_db = sfx_volume_db

func get_music_volume_linear() -> float:
	return db_to_linear(music_volume_db)

func get_sfx_volume_linear() -> float:
	return db_to_linear(sfx_volume_db)
