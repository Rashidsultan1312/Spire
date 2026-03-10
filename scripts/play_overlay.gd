extends CanvasLayer

@onready var panel: PanelContainer = $Panel
@onready var bg: ColorRect = $BG
@onready var back_btn: Button = $Panel/VBox/BackBtn
@onready var start_btn: Button = $Panel/VBox/StartBtn
@onready var world_desc: Label = $Panel/VBox/WorldDesc
@onready var diff_label: Label = $Panel/VBox/DiffRow/DiffLabel
@onready var diff_left: TextureButton = $Panel/VBox/DiffRow/DiffLeft
@onready var diff_right: TextureButton = $Panel/VBox/DiffRow/DiffRight
@onready var world_grid: GridContainer = $Panel/VBox/WorldScroll/WorldGrid

const StarFilled := preload("res://assets/sprites/ui/Icons/star_filled.png")
const StarEmpty := preload("res://assets/sprites/ui/Icons/star_empty.png")
const LockTex := preload("res://assets/sprites/ui/Icons/lock.png")

var tile_panels: Array[PanelContainer] = []

func _ready():
	back_btn.pressed.connect(_close)
	start_btn.pressed.connect(_start)
	diff_left.pressed.connect(_on_diff_left)
	diff_right.pressed.connect(_on_diff_right)
	visible = false
	_build_world_tiles()

func _build_world_tiles():
	for child in world_grid.get_children():
		child.queue_free()
	tile_panels.clear()

	for i in WorldThemes.WORLD_COUNT:
		var tile := PanelContainer.new()
		tile.custom_minimum_size = Vector2(290, 110)
		tile.mouse_filter = Control.MOUSE_FILTER_STOP
		tile.gui_input.connect(_on_tile_input.bind(i))

		var vbox := VBoxContainer.new()
		vbox.alignment = BoxContainer.ALIGNMENT_CENTER
		vbox.add_theme_constant_override("separation", 4)
		tile.add_child(vbox)

		var num_label := Label.new()
		num_label.name = "Num"
		num_label.text = str(i + 1)
		num_label.add_theme_font_size_override("font_size", 36)
		num_label.add_theme_color_override("font_color", Color(0.95, 0.9, 1.0))
		num_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		vbox.add_child(num_label)

		var name_label := Label.new()
		name_label.name = "Name"
		name_label.text = WorldThemes.WORLD_NAMES[i]
		name_label.add_theme_font_size_override("font_size", 14)
		name_label.add_theme_color_override("font_color", Color(0.85, 0.75, 1.0, 0.9))
		name_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		vbox.add_child(name_label)

		var stars_box := HBoxContainer.new()
		stars_box.name = "Stars"
		stars_box.alignment = BoxContainer.ALIGNMENT_CENTER
		stars_box.add_theme_constant_override("separation", 3)
		vbox.add_child(stars_box)

		var lock_icon := TextureRect.new()
		lock_icon.name = "Lock"
		lock_icon.visible = false
		lock_icon.custom_minimum_size = Vector2(28, 28)
		lock_icon.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
		lock_icon.texture = LockTex
		lock_icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		lock_icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		lock_icon.modulate = Color(0.6, 0.5, 0.7, 0.7)
		vbox.add_child(lock_icon)

		world_grid.add_child(tile)
		tile_panels.append(tile)

func open():
	visible = true
	_update_ui()
	panel.scale = Vector2(0.85, 0.85)
	panel.modulate = Color(1, 1, 1, 0)
	panel.pivot_offset = panel.size / 2
	var tw := create_tween().set_parallel(true)
	tw.tween_property(panel, "scale", Vector2(1, 1), 0.25).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_BACK)
	tw.tween_property(panel, "modulate:a", 1.0, 0.2)
	tw.tween_property(bg, "color:a", 0.5, 0.2)

func _close():
	SoundManager.play("click")
	var tw := create_tween()
	tw.tween_property(panel, "modulate:a", 0.0, 0.15)
	tw.tween_property(bg, "color:a", 0.0, 0.15)
	tw.tween_callback(func(): visible = false)

func _start():
	SoundManager.play("click")
	GameManager.start_game()

func _on_tile_input(event: InputEvent, idx: int):
	if event is InputEventMouseButton and event.pressed:
		if idx < GameManager.worlds_unlocked:
			SoundManager.play("click")
			GameManager.current_world = idx
			GameManager.save_data()
			_update_ui()

func _on_diff_left():
	SoundManager.play("click")
	var diff_idx := int(GameManager.difficulty) - 1
	if diff_idx < 0:
		diff_idx = 2
	GameManager.difficulty = diff_idx as GameManager.Difficulty
	GameManager.save_data()
	_update_ui()

func _on_diff_right():
	SoundManager.play("click")
	var diff_idx := int(GameManager.difficulty) + 1
	if diff_idx > 2:
		diff_idx = 0
	GameManager.difficulty = diff_idx as GameManager.Difficulty
	GameManager.save_data()
	_update_ui()

func _update_ui():
	var world := GameManager.current_world
	diff_label.text = GameManager.DIFFICULTY_NAMES[GameManager.difficulty]
	world_desc.text = WorldThemes.WORLD_DESCRIPTIONS[world]
	var unlocked := world < GameManager.worlds_unlocked
	start_btn.disabled = not unlocked

	for i in tile_panels.size():
		var tile: PanelContainer = tile_panels[i]
		var vbox: VBoxContainer = tile.get_child(0)
		var num_label: Label = vbox.get_node("Num")
		var name_label: Label = vbox.get_node("Name")
		var stars_box: HBoxContainer = vbox.get_node("Stars")
		var lock_icon: TextureRect = vbox.get_node("Lock")
		var is_unlocked := i < GameManager.worlds_unlocked
		var is_selected := i == world
		var diff_idx := int(GameManager.difficulty)
		var star_count: int = GameManager.get_stars(i, diff_idx)
		name_label.text = WorldThemes.WORLD_NAMES[i]

		var style := StyleBoxFlat.new()
		style.set_corner_radius_all(12)
		style.content_margin_left = 10
		style.content_margin_right = 10
		style.content_margin_top = 8
		style.content_margin_bottom = 8

		if is_unlocked:
			lock_icon.visible = false
			num_label.visible = true
			stars_box.visible = true
			_fill_stars(stars_box, star_count)
			if is_selected:
				style.bg_color = Color(0.18, 0.1, 0.3, 0.95)
				style.border_color = Color(1.0, 0.75, 0.2, 0.8)
				style.set_border_width_all(3)
				num_label.add_theme_color_override("font_color", Color(1, 0.9, 0.6))
			else:
				style.bg_color = Color(0.12, 0.07, 0.2, 0.9)
				style.border_color = Color(0.35, 0.22, 0.55, 0.5)
				style.set_border_width_all(2)
				num_label.add_theme_color_override("font_color", Color(0.95, 0.9, 1.0))
			name_label.modulate = Color.WHITE
		else:
			style.bg_color = Color(0.08, 0.05, 0.12, 0.7)
			style.border_color = Color(0.25, 0.18, 0.35, 0.4)
			style.set_border_width_all(2)
			num_label.visible = false
			stars_box.visible = false
			lock_icon.visible = true
			name_label.modulate = Color(0.5, 0.4, 0.6)

		tile.add_theme_stylebox_override("panel", style)

func _fill_stars(box: HBoxContainer, count: int):
	for child in box.get_children():
		child.queue_free()
	for i in 3:
		var icon := TextureRect.new()
		icon.texture = StarFilled if i < count else StarEmpty
		icon.custom_minimum_size = Vector2(20, 20)
		icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		box.add_child(icon)
