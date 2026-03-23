extends CanvasLayer

signal start_pressed
signal skip_pressed

@onready var panel: PanelContainer = $Panel
@onready var bg: ColorRect = $BG
@onready var slots_row: HBoxContainer = $Panel/VBox/SlotsRow
@onready var items_container: VBoxContainer = $Panel/VBox/Scroll/ItemsContainer
@onready var start_btn: Button = $Panel/VBox/BtnRow/StartBtn
@onready var skip_btn: Button = $Panel/VBox/BtnRow/SkipBtn

var selected: Array[String] = []
const MAX_SLOTS := 3

func _ready():
	start_btn.pressed.connect(_on_start)
	skip_btn.pressed.connect(_on_skip)
	visible = false

func open():
	selected.clear()
	visible = true
	_rebuild()
	panel.scale = Vector2(0.85, 0.85)
	panel.modulate = Color(1, 1, 1, 0)
	panel.pivot_offset = panel.size / 2
	var tw := create_tween().set_parallel(true)
	tw.tween_property(panel, "scale", Vector2(1, 1), 0.25).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_BACK)
	tw.tween_property(panel, "modulate:a", 1.0, 0.2)
	tw.tween_property(bg, "color:a", 0.5, 0.2)

func _close():
	var tw := create_tween()
	tw.tween_property(panel, "modulate:a", 0.0, 0.15)
	tw.tween_property(bg, "color:a", 0.0, 0.15)
	tw.tween_callback(func(): visible = false)

func _on_start():
	SoundManager.play("click")
	GameManager.selected_power_ups = selected.duplicate()
	GameManager.consume_selected()
	_close()
	await get_tree().create_timer(0.2).timeout
	start_pressed.emit()

func _on_skip():
	SoundManager.play("click")
	GameManager.selected_power_ups.clear()
	_close()
	await get_tree().create_timer(0.2).timeout
	skip_pressed.emit()

func _rebuild():
	_update_slots()
	_build_item_list()

func _update_slots():
	for child in slots_row.get_children():
		child.queue_free()
	for i in MAX_SLOTS:
		var slot := PanelContainer.new()
		slot.custom_minimum_size = Vector2(80, 80)
		var style := StyleBoxFlat.new()
		style.set_corner_radius_all(10)
		style.content_margin_left = 6
		style.content_margin_right = 6
		style.content_margin_top = 6
		style.content_margin_bottom = 6
		if i < selected.size():
			var pid: String = selected[i]
			var data: Dictionary = GameManager.POWER_UPS[pid]
			style.bg_color = Color(data.color.r * 0.3, data.color.g * 0.3, data.color.b * 0.3, 0.9)
			style.border_color = Color(data.color.r, data.color.g, data.color.b, 0.8)
			style.set_border_width_all(2)
			var icon_path := "res://assets/sprites/v3/items/potion_%s.png" % pid
			if ResourceLoader.exists(icon_path):
				var icon := TextureRect.new()
				icon.texture = load(icon_path)
				icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
				icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
				icon.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
				icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
				slot.add_child(icon)
			else:
				var lbl := Label.new()
				lbl.text = data.name
				lbl.add_theme_font_size_override("font_size", 11)
				lbl.add_theme_color_override("font_color", data.color)
				lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
				lbl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
				lbl.autowrap_mode = TextServer.AUTOWRAP_WORD
				lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
				slot.add_child(lbl)
		else:
			style.bg_color = Color(0.08, 0.05, 0.12, 0.6)
			style.border_color = Color(0.3, 0.2, 0.4, 0.4)
			style.set_border_width_all(1)
		slot.add_theme_stylebox_override("panel", style)
		slot.mouse_filter = Control.MOUSE_FILTER_IGNORE
		slots_row.add_child(slot)

func _build_item_list():
	for child in items_container.get_children():
		child.queue_free()
	var order := ["hint", "oracle", "greed", "blade", "shield", "shadow", "luck", "double_agent", "lucky_star"]
	for pid in order:
		var count: int = GameManager.items.get(pid, 0)
		if count <= 0:
			continue
		var data: Dictionary = GameManager.POWER_UPS[pid]
		var card := PanelContainer.new()
		var is_selected: bool = pid in selected
		var style := StyleBoxFlat.new()
		style.bg_color = Color(0.12, 0.07, 0.2, 0.9) if not is_selected else Color(data.color.r * 0.2, data.color.g * 0.2, data.color.b * 0.2, 0.95)
		style.border_color = Color(data.color.r, data.color.g, data.color.b, 0.7 if is_selected else 0.3)
		style.set_border_width_all(2 if is_selected else 1)
		style.set_corner_radius_all(8)
		style.content_margin_left = 12
		style.content_margin_right = 12
		style.content_margin_top = 8
		style.content_margin_bottom = 8
		card.add_theme_stylebox_override("panel", style)
		card.mouse_filter = Control.MOUSE_FILTER_STOP
		card.gui_input.connect(_on_card_input.bind(pid))

		var hbox := HBoxContainer.new()
		hbox.add_theme_constant_override("separation", 10)
		hbox.mouse_filter = Control.MOUSE_FILTER_IGNORE
		card.add_child(hbox)

		var icon_path := "res://assets/sprites/v3/items/potion_%s.png" % pid
		if ResourceLoader.exists(icon_path):
			var icon := TextureRect.new()
			icon.texture = load(icon_path)
			icon.custom_minimum_size = Vector2(44, 44)
			icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
			icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
			icon.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
			icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
			hbox.add_child(icon)

		var info_vbox := VBoxContainer.new()
		info_vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		info_vbox.add_theme_constant_override("separation", 1)
		info_vbox.mouse_filter = Control.MOUSE_FILTER_IGNORE
		hbox.add_child(info_vbox)

		var name_label := Label.new()
		name_label.text = data.name
		name_label.add_theme_font_size_override("font_size", 18)
		name_label.add_theme_color_override("font_color", data.color)
		name_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
		info_vbox.add_child(name_label)

		var desc_label := Label.new()
		desc_label.text = data.desc
		desc_label.add_theme_font_size_override("font_size", 12)
		desc_label.add_theme_color_override("font_color", Color(0.65, 0.6, 0.75, 0.7))
		desc_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
		info_vbox.add_child(desc_label)

		var right_hbox := HBoxContainer.new()
		right_hbox.add_theme_constant_override("separation", 6)
		right_hbox.mouse_filter = Control.MOUSE_FILTER_IGNORE
		hbox.add_child(right_hbox)

		var type_label := Label.new()
		type_label.text = data.type.to_upper()
		type_label.add_theme_font_size_override("font_size", 11)
		var type_color := Color(0.5, 0.8, 1.0) if data.type == "manual" else (Color(1.0, 0.7, 0.3) if data.type == "auto" else Color(0.5, 1.0, 0.6))
		type_label.add_theme_color_override("font_color", type_color)
		type_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
		right_hbox.add_child(type_label)

		var count_label := Label.new()
		count_label.text = "x%d" % count
		count_label.add_theme_font_size_override("font_size", 16)
		count_label.add_theme_color_override("font_color", Color(0.7, 0.85, 1.0, 0.8))
		count_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
		right_hbox.add_child(count_label)

		items_container.add_child(card)

func _on_card_input(event: InputEvent, pid: String):
	if not (event is InputEventMouseButton and event.pressed):
		return
	SoundManager.play("click")
	if pid in selected:
		selected.erase(pid)
	elif selected.size() < MAX_SLOTS:
		selected.append(pid)
	_rebuild()
