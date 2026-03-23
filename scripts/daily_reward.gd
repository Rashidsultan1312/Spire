extends CanvasLayer

signal closed

@onready var panel: PanelContainer = $Panel
@onready var bg: ColorRect = $BG
@onready var day_label: Label = $Panel/VBox/DayLabel
@onready var reward_label: Label = $Panel/VBox/RewardPanel/RewardLabel
@onready var days_row: HBoxContainer = $Panel/VBox/DaysRow
@onready var claim_btn: Button = $Panel/VBox/ClaimBtn

func _ready():
	claim_btn.pressed.connect(_on_claim)
	visible = false

func open():
	visible = true
	_update_ui()
	panel.scale = Vector2(0.85, 0.85)
	panel.modulate = Color(1, 1, 1, 0)
	panel.pivot_offset = panel.size / 2
	var tw := create_tween().set_parallel(true)
	tw.tween_property(panel, "scale", Vector2(1, 1), 0.3).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_BACK)
	tw.tween_property(panel, "modulate:a", 1.0, 0.2)
	tw.tween_property(bg, "color:a", 0.6, 0.2)

func _close():
	SoundManager.play("click")
	var tw := create_tween()
	tw.tween_property(panel, "modulate:a", 0.0, 0.15)
	tw.tween_property(bg, "color:a", 0.0, 0.15)
	tw.tween_callback(func(): visible = false; closed.emit())

func _update_ui():
	var streak := MissionManager.daily_streak
	day_label.text = "DAY %d / 7" % (streak + 1)
	var reward_data: Dictionary = MissionManager.DAILY_REWARDS[streak]
	match reward_data["type"]:
		"coins":
			reward_label.text = "%d coins" % reward_data["amount"]
		"item":
			reward_label.text = "1x %s potion" % reward_data["item"].capitalize()
		"both":
			reward_label.text = "1x %s + %d coins" % [reward_data["item"].capitalize(), reward_data["amount"]]
	for child in days_row.get_children():
		child.queue_free()
	for i in 7:
		var day_box := PanelContainer.new()
		day_box.custom_minimum_size = Vector2(68, 68)
		var style := StyleBoxFlat.new()
		style.set_corner_radius_all(10)
		style.set_content_margin_all(4)
		if i < streak:
			style.bg_color = Color(0.12, 0.22, 0.12, 0.9)
			style.border_color = Color(0.35, 0.75, 0.35, 0.6)
			style.set_border_width_all(2)
		elif i == streak:
			style.bg_color = Color(0.2, 0.15, 0.05, 0.95)
			style.border_color = Color(1, 0.85, 0.3, 0.9)
			style.set_border_width_all(3)
		else:
			style.bg_color = Color(0.08, 0.06, 0.12, 0.7)
			style.border_color = Color(0.3, 0.25, 0.4, 0.35)
			style.set_border_width_all(1)
		day_box.add_theme_stylebox_override("panel", style)
		var vbox := VBoxContainer.new()
		vbox.alignment = BoxContainer.ALIGNMENT_CENTER
		vbox.add_theme_constant_override("separation", 2)
		vbox.mouse_filter = Control.MOUSE_FILTER_IGNORE
		day_box.add_child(vbox)
		var num_lbl := Label.new()
		num_lbl.text = str(i + 1)
		num_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		num_lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
		num_lbl.add_theme_font_size_override("font_size", 22)
		if i < streak:
			num_lbl.add_theme_color_override("font_color", Color(0.4, 0.85, 0.4))
		elif i == streak:
			num_lbl.add_theme_color_override("font_color", Color(1, 0.85, 0.3))
		else:
			num_lbl.add_theme_color_override("font_color", Color(0.45, 0.38, 0.55))
		vbox.add_child(num_lbl)
		var icon_lbl := Label.new()
		icon_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		icon_lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
		icon_lbl.add_theme_font_size_override("font_size", 14)
		var day_reward: Dictionary = MissionManager.DAILY_REWARDS[i]
		if i < streak:
			icon_lbl.text = "done"
			icon_lbl.add_theme_color_override("font_color", Color(0.35, 0.7, 0.35, 0.7))
		else:
			match day_reward["type"]:
				"coins":
					icon_lbl.text = "%d" % day_reward["amount"]
				"item":
					icon_lbl.text = day_reward["item"].substr(0, 4)
				"both":
					icon_lbl.text = "mix"
			if i == streak:
				icon_lbl.add_theme_color_override("font_color", Color(1, 0.9, 0.6, 0.8))
			else:
				icon_lbl.add_theme_color_override("font_color", Color(0.5, 0.45, 0.6, 0.6))
		vbox.add_child(icon_lbl)
		days_row.add_child(day_box)
		if i == streak:
			_pulse_today(day_box)
	claim_btn.disabled = not MissionManager.has_unclaimed_daily()

func _pulse_today(box: PanelContainer):
	var tw := create_tween().set_loops()
	tw.tween_property(box, "modulate", Color(1.15, 1.1, 0.9), 0.8).set_ease(Tween.EASE_IN_OUT).set_trans(Tween.TRANS_SINE)
	tw.tween_property(box, "modulate", Color(1, 1, 1), 0.8).set_ease(Tween.EASE_IN_OUT).set_trans(Tween.TRANS_SINE)

func _on_claim():
	if not MissionManager.has_unclaimed_daily():
		return
	SoundManager.play("coin")
	SoundManager.vibrate_light()
	var reward := MissionManager.claim_daily()
	claim_btn.disabled = true
	var flash_tw := create_tween()
	flash_tw.tween_property(panel, "modulate", Color(1.3, 1.2, 0.8), 0.15)
	flash_tw.tween_property(panel, "modulate", Color.WHITE, 0.2)
	await flash_tw.finished
	await get_tree().create_timer(0.5).timeout
	_close()
