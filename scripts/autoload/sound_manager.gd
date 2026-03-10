extends Node

var _players := {}
var _music_player: AudioStreamPlayer
var _audio_unlocked := false
var _current_music_path := ""
var _menu_music_path := "res://assets/music/dark_ambience.ogg"

func _ready():
	_register("tile_flip", "res://assets/sounds/game/card-slide-1.ogg")
	_register("tile_safe", "res://assets/sounds/game/chip-lay-1.ogg")
	_register("tile_trap", "res://assets/sounds/impact/impactPlate_heavy_000.ogg")
	_register("jump", "res://assets/sounds/impact/footstep_concrete_000.ogg")
	_register("fall", "res://assets/sounds/impact/impactSoft_heavy_000.ogg")
	_register("coin", "res://assets/sounds/game/card-place-1.ogg")
	_register("click", "res://assets/sounds/ui/click_003.ogg")
	_register("victory", "res://assets/sounds/ui/confirmation_001.ogg")
	_register("gameover", "res://assets/sounds/impact/impactBell_heavy_000.ogg")
	_register("potion", "res://assets/sounds/ui/glass_001.ogg")
	_register("error", "res://assets/sounds/ui/error_001.ogg")
	_register("event", "res://assets/sounds/ui/bong_001.ogg")
	_register("combo", "res://assets/sounds/ui/maximize_008.ogg")
	_register("key", "res://assets/sounds/ui/confirmation_003.ogg")
	_register("purchase", "res://assets/sounds/ui/confirmation_002.ogg")
	_register("shield_break", "res://assets/sounds/ui/glass_004.ogg")
	_register("door_open", "res://assets/sounds/game/door_open.ogg")

	_music_player = AudioStreamPlayer.new()
	_music_player.bus = "Music"
	_music_player.volume_db = linear_to_db(GameManager.music_volume * 0.35)
	add_child(_music_player)
	_music_player.finished.connect(_on_music_finished)

	play_menu_music()
	if OS.get_name() == "Web":
		set_process_input(true)
	else:
		_audio_unlocked = true

func _input(event: InputEvent):
	if _audio_unlocked:
		return
	if event is InputEventMouseButton and event.pressed:
		_audio_unlocked = true
		AudioServer.unlock()
		if _music_player.stream and not _music_player.playing:
			_music_player.play()
		set_process_input(false)

func _on_music_finished():
	_music_player.play()

func _register(id: String, path: String):
	var player := AudioStreamPlayer.new()
	var stream := load(path)
	if stream:
		player.stream = stream
		player.bus = "Master"
		add_child(player)
		_players[id] = player

func play(id: String, volume_db := 0.0):
	if _players.has(id):
		var p: AudioStreamPlayer = _players[id]
		p.volume_db = volume_db + linear_to_db(GameManager.sfx_volume)
		p.play()

func set_sfx_volume(val: float):
	GameManager.sfx_volume = val
	GameManager.save_data()

func set_music_volume(val: float):
	GameManager.music_volume = val
	if _music_player:
		_music_player.volume_db = linear_to_db(val * 0.35)
	GameManager.save_data()

func play_world_music(world: int):
	var path: String = WorldThemes.WORLD_MUSIC[clampi(world, 0, 9)]
	if path == _current_music_path and _music_player.playing:
		return
	_switch_music(path)

func play_menu_music():
	if _menu_music_path == _current_music_path and _music_player.playing:
		return
	_switch_music(_menu_music_path)

func _switch_music(path: String):
	_current_music_path = path
	var stream := load(path)
	if not stream:
		return
	var target_db := linear_to_db(GameManager.music_volume * 0.35)
	if _music_player.playing:
		var tw := create_tween()
		tw.tween_property(_music_player, "volume_db", -40.0, 0.8)
		tw.tween_callback(func():
			_music_player.stream = stream
			_music_player.volume_db = -40.0
			if _audio_unlocked:
				_music_player.play()
			var fade_in := create_tween()
			fade_in.tween_property(_music_player, "volume_db", target_db, 1.0))
	else:
		_music_player.stream = stream
		_music_player.volume_db = -40.0
		if _audio_unlocked:
			_music_player.play()
		var fade_in := create_tween()
		fade_in.tween_property(_music_player, "volume_db", target_db, 1.0)
