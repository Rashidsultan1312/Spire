extends Control

@onready var play_btn: Button = $Content/Buttons/PlayBtn
@onready var settings_btn: Button = $Content/Buttons/SettingsBtn
@onready var shop_btn: Button = $Content/Buttons/ShopBtn
@onready var high_score_label: Label = $Content/HighScorePanel/HBox/HighScoreLabel
@onready var high_score_panel: PanelContainer = $Content/HighScorePanel
@onready var wallet_label: Label = $Content/WalletPanel/HBox/WalletLabel
@onready var wallet_panel: PanelContainer = $Content/WalletPanel
@onready var title: Label = $Content/TitlePanel/TitleVBox/Title
@onready var content: VBoxContainer = $Content
@onready var settings_panel: PanelContainer = $SettingsOverlay/Panel
@onready var settings_overlay: CanvasLayer = $SettingsOverlay
@onready var sfx_slider: HSlider = $SettingsOverlay/Panel/VBox/SfxRow/SfxSlider
@onready var music_slider: HSlider = $SettingsOverlay/Panel/VBox/MusicRow/MusicSlider
@onready var back_btn: Button = $SettingsOverlay/Panel/VBox/BackBtn
@onready var settings_bg: ColorRect = $SettingsOverlay/BG
@onready var shop_overlay: CanvasLayer = $ShopOverlay
@onready var play_overlay: CanvasLayer = $PlayOverlay

func _ready():
	_apply_safe_area()
	play_btn.pressed.connect(_on_play)
	settings_btn.pressed.connect(_on_settings)
	shop_btn.pressed.connect(_on_shop)
	shop_overlay.closed.connect(_on_shop_closed)
	back_btn.pressed.connect(_close_settings)
	sfx_slider.value = GameManager.sfx_volume
	music_slider.value = GameManager.music_volume
	sfx_slider.value_changed.connect(func(v: float): GameManager.sfx_volume = v; SoundManager.set_sfx_volume(v); SoundManager.play("click"))
	music_slider.value_changed.connect(func(v: float): GameManager.music_volume = v; SoundManager.set_music_volume(v))
	settings_overlay.visible = false
	_update_records()
	_animate_intro()

func _apply_safe_area():
	if OS.get_name() != "iOS":
		return
	var safe := DisplayServer.get_display_safe_area()
	var screen := DisplayServer.screen_get_size()
	var vp_size := get_viewport().get_visible_rect().size
	var scale_y := vp_size.y / float(screen.y)
	var top_offset := safe.position.y * scale_y
	var bottom_offset := (screen.y - safe.end.y) * scale_y
	var safe_center := (top_offset + (vp_size.y - bottom_offset)) / 2.0
	var shift := safe_center - vp_size.y / 2.0
	content.offset_top += shift
	content.offset_bottom += shift

func _update_records():
	if GameManager.high_score > 0:
		high_score_label.text = "BEST: %d" % GameManager.high_score
		high_score_panel.visible = true
	else:
		high_score_panel.visible = false
	wallet_label.text = "%d" % GameManager.wallet
	wallet_panel.visible = true

func _animate_intro():
	content.modulate = Color(1, 1, 1, 0)
	content.position.y += 30
	var tw := create_tween().set_parallel(true)
	tw.tween_property(content, "modulate:a", 1.0, 0.5).set_ease(Tween.EASE_OUT)
	tw.tween_property(content, "position:y", content.position.y - 30, 0.5).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_BACK)

	var buttons: Array[Button] = [play_btn, shop_btn, settings_btn]
	for i in buttons.size():
		var btn := buttons[i]
		btn.modulate = Color(1, 1, 1, 0)
		btn.scale = Vector2(0.85, 0.85)
		btn.pivot_offset = btn.size / 2
		var btw := create_tween().set_parallel(true)
		btw.tween_property(btn, "modulate:a", 1.0, 0.25).set_delay(0.15 + i * 0.1)
		btw.tween_property(btn, "scale", Vector2(1.0, 1.0), 0.3).set_delay(0.15 + i * 0.1).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_BACK)

func _on_play():
	SoundManager.play("click")
	play_overlay.open()

func _on_settings():
	SoundManager.play("click")
	settings_overlay.visible = true
	settings_panel.scale = Vector2(0.85, 0.85)
	settings_panel.modulate = Color(1, 1, 1, 0)
	settings_panel.pivot_offset = settings_panel.size / 2
	var tw := create_tween().set_parallel(true)
	tw.tween_property(settings_panel, "scale", Vector2(1, 1), 0.25).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_BACK)
	tw.tween_property(settings_panel, "modulate:a", 1.0, 0.2)
	tw.tween_property(settings_bg, "color:a", 0.4, 0.2)

func _close_settings():
	SoundManager.play("click")
	var tw := create_tween()
	tw.tween_property(settings_panel, "modulate:a", 0.0, 0.15)
	tw.tween_property(settings_bg, "color:a", 0.0, 0.15)
	tw.tween_callback(func(): settings_overlay.visible = false)

func _on_shop():
	SoundManager.play("click")
	shop_overlay.open()

func _on_shop_closed():
	_update_records()
