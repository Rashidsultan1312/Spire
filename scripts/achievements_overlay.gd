extends CanvasLayer

signal closed

@onready var panel: PanelContainer = $Panel
@onready var bg: ColorRect = $BG
@onready var back_btn: Button = $Panel/VBox/BackBtn
@onready var count_label: Label = $Panel/VBox/TitleRow/CountLabel
@onready var ach_list: VBoxContainer = $Panel/VBox/ScrollContainer/AchList

var _unlocked_style: StyleBoxFlat
var _locked_style: StyleBoxFlat

func _ready():
	back_btn.pressed.connect(_close)
	visible = false
	_unlocked_style = StyleBoxFlat.new()
	_unlocked_style.bg_color = Color(0.1, 0.08, 0.05, 0.9)
	_unlocked_style.border_color = Color(0.85, 0.7, 0.2, 0.7)
	_unlocked_style.set_border_width_all(2)
	_unlocked_style.set_corner_radius_all(8)
	_unlocked_style.set_content_margin_all(12)
	_locked_style = StyleBoxFlat.new()
	_locked_style.bg_color = Color(0.08, 0.06, 0.12, 0.8)
	_locked_style.border_color = Color(0.3, 0.25, 0.4, 0.4)
	_locked_style.set_border_width_all(1)
	_locked_style.set_corner_radius_all(8)
	_locked_style.set_content_margin_all(12)

func open():
	visible = true
	_build_list()
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

func _build_list():
	for child in ach_list.get_children():
		child.queue_free()
	var unlocked := MissionManager.unlocked_achievements
	count_label.text = "%d/%d" % [unlocked.size(), MissionManager.ACHIEVEMENTS.size()]
	for ach_id in MissionManager.ACHIEVEMENTS:
		var data: Dictionary = MissionManager.ACHIEVEMENTS[ach_id]
		var is_unlocked: bool = ach_id in unlocked
		var row := PanelContainer.new()
		row.mouse_filter = Control.MOUSE_FILTER_PASS
		row.add_theme_stylebox_override("panel", _unlocked_style if is_unlocked else _locked_style)
		var hbox := HBoxContainer.new()
		hbox.mouse_filter = Control.MOUSE_FILTER_PASS
		hbox.add_theme_constant_override("separation", 12)
		row.add_child(hbox)
		var status := Label.new()
		status.text = "V" if is_unlocked else "X"
		status.add_theme_font_size_override("font_size", 26)
		status.add_theme_color_override("font_color", Color(0.3, 0.9, 0.3) if is_unlocked else Color(0.5, 0.4, 0.6))
		status.mouse_filter = Control.MOUSE_FILTER_IGNORE
		hbox.add_child(status)
		var info := VBoxContainer.new()
		info.mouse_filter = Control.MOUSE_FILTER_PASS
		info.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		info.add_theme_constant_override("separation", 2)
		hbox.add_child(info)
		var name_label := Label.new()
		name_label.text = data["name"]
		name_label.add_theme_font_size_override("font_size", 24)
		name_label.add_theme_color_override("font_color", Color(1, 0.9, 0.6) if is_unlocked else Color(0.6, 0.55, 0.7))
		name_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
		info.add_child(name_label)
		var desc_label := Label.new()
		desc_label.text = data["desc"]
		desc_label.add_theme_font_size_override("font_size", 20)
		desc_label.add_theme_color_override("font_color", Color(0.7, 0.65, 0.8))
		desc_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
		info.add_child(desc_label)
		var reward_label := Label.new()
		reward_label.text = "+%d" % data["reward"]
		reward_label.add_theme_font_size_override("font_size", 26)
		reward_label.add_theme_color_override("font_color", Color(1, 0.85, 0.3) if is_unlocked else Color(0.5, 0.45, 0.55))
		reward_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
		reward_label.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		hbox.add_child(reward_label)
		ach_list.add_child(row)
