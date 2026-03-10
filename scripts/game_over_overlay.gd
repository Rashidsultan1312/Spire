extends CanvasLayer

const StarFilled := preload("res://assets/sprites/ui/Icons/star_filled.png")
const StarEmpty := preload("res://assets/sprites/ui/Icons/star_empty.png")

@onready var panel: PanelContainer = $Panel
@onready var title_label: Label = $Panel/VBox/TitleLabel
@onready var stars_box: HBoxContainer = $Panel/VBox/StarsBox
@onready var score_label: Label = $Panel/VBox/InfoPanel/InfoVBox/ScoreRow/ScoreLabel
@onready var wallet_label: Label = $Panel/VBox/InfoPanel/InfoVBox/WalletRow/WalletLabel
@onready var unlock_label: Label = $Panel/VBox/UnlockLabel
@onready var retry_btn: Button = $Panel/VBox/RetryBtn
@onready var next_btn: Button = $Panel/VBox/NextBtn
@onready var prev_btn: Button = $Panel/VBox/PrevBtn
@onready var menu_btn: Button = $Panel/VBox/MenuBtn
@onready var blur_rect: ColorRect = $BlurRect

func _ready():
	retry_btn.pressed.connect(_on_retry)
	next_btn.pressed.connect(_on_next)
	prev_btn.pressed.connect(_on_prev)
	menu_btn.pressed.connect(_on_menu)
	visible = false

func _show_stars(color: Color):
	_fill_stars(stars_box, GameManager.current_stars(), color)
	stars_box.visible = true
	stars_box.modulate = Color(1, 1, 1, 0)
	var tw := create_tween()
	tw.tween_property(stars_box, "modulate:a", 1.0, 0.3).set_delay(0.4)

func _fill_stars(box: HBoxContainer, count: int, tint: Color = Color.WHITE):
	for child in box.get_children():
		child.queue_free()
	for i in 3:
		var icon := TextureRect.new()
		icon.texture = StarFilled if i < count else StarEmpty
		icon.custom_minimum_size = Vector2(32, 32)
		icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		icon.modulate = tint if i < count else Color(0.5, 0.4, 0.6, 0.5)
		box.add_child(icon)

func show_game_over(penalty: int = 0):
	visible = true
	title_label.text = "TRAPPED!"
	title_label.add_theme_color_override("font_color", Color(0.9, 0.22, 0.27))
	if penalty > 0:
		score_label.text = "-%d" % penalty
		score_label.add_theme_color_override("font_color", Color(1, 0.35, 0.3))
	else:
		score_label.text = "0"
		score_label.add_theme_color_override("font_color", Color(1, 0.85, 0.3))
	wallet_label.text = "%d" % GameManager.wallet
	unlock_label.visible = false
	retry_btn.text = "RETRY"
	_show_next_if_available()
	_show_stars(Color(0.5, 0.4, 0.6, 0.6))
	_animate_in()

func show_victory(_score: int, earned: int, world_unlocked := ""):
	visible = true
	title_label.text = "VICTORY!"
	title_label.add_theme_color_override("font_color", Color(1, 0.84, 0))
	score_label.text = "+%d" % earned
	score_label.add_theme_color_override("font_color", Color(1, 0.85, 0.3))
	wallet_label.text = "%d" % GameManager.wallet
	retry_btn.text = "RETRY"
	_show_stars(Color(1, 0.85, 0.3))
	if world_unlocked != "":
		unlock_label.text = "UNLOCKED: %s" % world_unlocked
		unlock_label.visible = true
		unlock_label.add_theme_color_override("font_color", Color(0.4, 0.85, 1.0, 0.9))
		next_btn.text = "NEXT: %s" % world_unlocked
		next_btn.visible = true
		prev_btn.visible = GameManager.current_world > 0
		if prev_btn.visible:
			prev_btn.text = "PREV: %s" % WorldThemes.WORLD_NAMES[GameManager.current_world - 1]
	else:
		unlock_label.visible = false
		_show_next_if_available()
	_animate_in()

func show_victory_no_reward():
	visible = true
	title_label.text = "VICTORY!"
	title_label.add_theme_color_override("font_color", Color(1, 0.84, 0))
	score_label.text = "0"
	score_label.add_theme_color_override("font_color", Color(0.6, 0.55, 0.7))
	wallet_label.text = "%d" % GameManager.wallet
	unlock_label.text = "Already completed"
	unlock_label.visible = true
	unlock_label.add_theme_color_override("font_color", Color(0.6, 0.55, 0.7, 0.8))
	retry_btn.text = "RETRY"
	_show_stars(Color(1, 0.85, 0.3))
	_show_next_if_available()
	_animate_in()

func show_cash_out(_score: int, earned: int):
	visible = true
	title_label.text = "CASHED OUT!"
	title_label.add_theme_color_override("font_color", Color(0.16, 0.62, 0.56))
	score_label.text = "+%d" % earned
	score_label.add_theme_color_override("font_color", Color(1, 0.85, 0.3))
	wallet_label.text = "%d" % GameManager.wallet
	retry_btn.text = "RETRY"
	unlock_label.visible = false
	_show_next_if_available()
	_show_stars(Color(1, 0.85, 0.3))
	_animate_in()

func show_cash_out_no_reward():
	visible = true
	title_label.text = "CASHED OUT!"
	title_label.add_theme_color_override("font_color", Color(0.16, 0.62, 0.56))
	score_label.text = "0"
	score_label.add_theme_color_override("font_color", Color(0.6, 0.55, 0.7))
	wallet_label.text = "%d" % GameManager.wallet
	unlock_label.text = "Already completed"
	unlock_label.visible = true
	unlock_label.add_theme_color_override("font_color", Color(0.6, 0.55, 0.7, 0.8))
	retry_btn.text = "RETRY"
	_show_next_if_available()
	_show_stars(Color(1, 0.85, 0.3))
	_animate_in()

func _show_next_if_available():
	var has_next := GameManager.current_world + 1 < GameManager.worlds_unlocked
	if has_next:
		next_btn.text = "NEXT: %s" % WorldThemes.WORLD_NAMES[GameManager.current_world + 1]
		next_btn.visible = true
	else:
		next_btn.visible = false
	var has_prev := GameManager.current_world > 0
	if has_prev:
		prev_btn.text = "PREV: %s" % WorldThemes.WORLD_NAMES[GameManager.current_world - 1]
		prev_btn.visible = true
	else:
		prev_btn.visible = false

func _animate_in():
	panel.scale = Vector2(0.8, 0.8)
	panel.modulate = Color(1, 1, 1, 0)
	panel.pivot_offset = panel.size / 2
	var mat: ShaderMaterial = blur_rect.material
	mat.set_shader_parameter("blur_amount", 0.0)
	mat.set_shader_parameter("darkness", 0.0)
	var tw := create_tween().set_parallel(true)
	tw.tween_property(panel, "scale", Vector2(1, 1), 0.35).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_BACK)
	tw.tween_property(panel, "modulate:a", 1.0, 0.25)
	tw.tween_method(func(v: float): mat.set_shader_parameter("blur_amount", v), 0.0, 2.5, 0.4)
	tw.tween_method(func(v: float): mat.set_shader_parameter("darkness", v), 0.0, 0.3, 0.4)

func _on_retry():
	SoundManager.play("click")
	GameManager.start_game()

func _on_next():
	SoundManager.play("click")
	GameManager.start_next_world()

func _on_prev():
	SoundManager.play("click")
	GameManager.start_prev_world()

func _on_menu():
	SoundManager.play("click")
	GameManager.go_to_menu()
