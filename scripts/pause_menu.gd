extends CanvasLayer

@onready var panel: PanelContainer = $Panel
@onready var resume_btn: Button = $Panel/VBox/ResumeBtn
@onready var restart_btn: Button = $Panel/VBox/RestartBtn
@onready var settings_btn: Button = $Panel/VBox/SettingsBtn
@onready var menu_btn: Button = $Panel/VBox/MenuBtn
@onready var overlay: ColorRect = $Overlay
@onready var sfx_slider: HSlider = $Panel/VBox/SfxRow/SfxSlider
@onready var music_slider: HSlider = $Panel/VBox/MusicRow/MusicSlider

var _is_open := false

func _ready():
	resume_btn.pressed.connect(close)
	restart_btn.pressed.connect(_on_restart)
	menu_btn.pressed.connect(_on_menu)
	sfx_slider.value = GameManager.sfx_volume
	music_slider.value = GameManager.music_volume
	sfx_slider.value_changed.connect(func(v: float): GameManager.sfx_volume = v; SoundManager.set_sfx_volume(v))
	music_slider.value_changed.connect(func(v: float): GameManager.music_volume = v; SoundManager.set_music_volume(v))
	visible = false

func _unhandled_input(event: InputEvent):
	if event.is_action_pressed("ui_cancel"):
		if _is_open:
			close()
		else:
			open()

func open():
	_is_open = true
	visible = true
	get_tree().paused = true
	panel.scale = Vector2(0.8, 0.8)
	panel.modulate = Color(1, 1, 1, 0)
	panel.pivot_offset = panel.size / 2
	var tw := create_tween().set_pause_mode(Tween.TWEEN_PAUSE_PROCESS).set_parallel(true)
	tw.tween_property(panel, "scale", Vector2(1, 1), 0.25).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_BACK)
	tw.tween_property(panel, "modulate:a", 1.0, 0.2)
	tw.tween_property(overlay, "color:a", 0.5, 0.2)

func close():
	_is_open = false
	SoundManager.play("click")
	var tw := create_tween().set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
	tw.tween_property(panel, "modulate:a", 0.0, 0.15)
	tw.tween_callback(func():
		visible = false
		get_tree().paused = false)

func _on_restart():
	SoundManager.play("click")
	get_tree().paused = false
	GameManager.start_game()

func _on_menu():
	SoundManager.play("click")
	get_tree().paused = false
	GameManager.go_to_menu()
