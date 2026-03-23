extends CanvasLayer

signal closed

@onready var panel: PanelContainer = $Panel
@onready var bg: ColorRect = $BG
@onready var back_btn: Button = $Panel/VBox/BackBtn
@onready var card_list: VBoxContainer = $Panel/VBox/ScrollContainer/CardList
@onready var count_label: Label = $Panel/VBox/TitleRow/CountLabel

var _card_style: StyleBoxFlat
var _done_style: StyleBoxFlat

func _ready():
	back_btn.pressed.connect(_close)
	visible = false
	_card_style = StyleBoxFlat.new()
	_card_style.bg_color = Color(0.1, 0.06, 0.18, 0.9)
	_card_style.border_color = Color(0.55, 0.35, 0.75, 0.5)
	_card_style.set_border_width_all(1)
	_card_style.set_corner_radius_all(8)
	_card_style.content_margin_left = 16
	_card_style.content_margin_right = 16
	_card_style.content_margin_top = 12
	_card_style.content_margin_bottom = 12
	_done_style = StyleBoxFlat.new()
	_done_style.bg_color = Color(0.08, 0.15, 0.1, 0.9)
	_done_style.border_color = Color(0.3, 0.7, 0.3, 0.6)
	_done_style.set_border_width_all(1)
	_done_style.set_corner_radius_all(8)
	_done_style.content_margin_left = 16
	_done_style.content_margin_right = 16
	_done_style.content_margin_top = 12
	_done_style.content_margin_bottom = 12

func open():
	visible = true
	_build_cards()
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
	tw.tween_callback(func(): visible = false; closed.emit())

func _build_cards():
	for child in card_list.get_children():
		child.queue_free()
	var missions := MissionManager.get_all_missions()
	var done_count := 0
	for m in missions:
		if m["done"]:
			done_count += 1
	count_label.text = "%d/%d" % [done_count, missions.size()]
	for m in missions:
		var progress: int = m["progress"]
		var is_done: bool = m["done"]
		var card := PanelContainer.new()
		card.mouse_filter = Control.MOUSE_FILTER_PASS
		card.add_theme_stylebox_override("panel", _done_style if is_done else _card_style)
		var hbox := HBoxContainer.new()
		hbox.mouse_filter = Control.MOUSE_FILTER_PASS
		hbox.add_theme_constant_override("separation", 12)
		card.add_child(hbox)
		var left := VBoxContainer.new()
		left.mouse_filter = Control.MOUSE_FILTER_PASS
		left.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		left.add_theme_constant_override("separation", 5)
		hbox.add_child(left)
		var desc_label := Label.new()
		desc_label.text = m["desc"]
		desc_label.add_theme_font_size_override("font_size", 24)
		desc_label.add_theme_color_override("font_color", Color(0.3, 0.9, 0.4) if is_done else Color(0.9, 0.85, 1.0))
		desc_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
		left.add_child(desc_label)
		var pbar := ProgressBar.new()
		pbar.custom_minimum_size = Vector2(0, 12)
		pbar.max_value = m["target"]
		pbar.value = progress
		pbar.show_percentage = false
		pbar.mouse_filter = Control.MOUSE_FILTER_IGNORE
		pbar.add_theme_color_override("font_color", Color(1, 1, 1, 0))
		left.add_child(pbar)
		var prog_label := Label.new()
		prog_label.text = "DONE" if is_done else "%d/%d" % [progress, m["target"]]
		prog_label.add_theme_font_size_override("font_size", 22)
		prog_label.add_theme_color_override("font_color", Color(0.3, 0.8, 0.3) if is_done else Color(0.7, 0.65, 0.85))
		prog_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
		left.add_child(prog_label)
		var reward_label := Label.new()
		reward_label.text = "+%d" % m["reward"]
		reward_label.add_theme_font_size_override("font_size", 28)
		reward_label.add_theme_color_override("font_color", Color(0.5, 0.45, 0.55) if is_done else Color(1, 0.85, 0.3))
		reward_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
		reward_label.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		hbox.add_child(reward_label)
		card_list.add_child(card)
