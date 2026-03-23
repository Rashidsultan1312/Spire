extends CanvasLayer

signal closed

@onready var panel: PanelContainer = $Panel
@onready var bg: ColorRect = $BG
@onready var back_btn: Button = $Panel/VBox/BackBtn
@onready var wallet_label: Label = $Panel/VBox/WalletRow/WalletValue
@onready var scroll: ScrollContainer = $Panel/VBox/Scroll
@onready var items_container: VBoxContainer = $Panel/VBox/Scroll/ItemsContainer
@onready var tab_powerups: Button = $Panel/VBox/TabRow/TabPowerUps
@onready var tab_upgrades: Button = $Panel/VBox/TabRow/TabUpgrades

var current_tab := 0

func _ready():
	back_btn.pressed.connect(_close)
	tab_powerups.pressed.connect(func(): _switch_tab(0))
	tab_upgrades.pressed.connect(func(): _switch_tab(1))
	visible = false

func open():
	visible = true
	_switch_tab(0)
	_update_wallet()
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

func _switch_tab(idx: int):
	current_tab = idx
	tab_powerups.add_theme_color_override("font_color", Color(1, 0.85, 0.3) if idx == 0 else Color(0.7, 0.65, 0.8))
	tab_upgrades.add_theme_color_override("font_color", Color(1, 0.85, 0.3) if idx == 1 else Color(0.7, 0.65, 0.8))
	_rebuild_cards()

func _rebuild_cards():
	for child in items_container.get_children():
		child.queue_free()
	if current_tab == 0:
		_build_powerup_cards()
	else:
		_build_upgrade_cards()

func _update_wallet():
	wallet_label.text = "%d" % GameManager.wallet

func _build_powerup_cards():
	var order := ["hint", "oracle", "greed", "blade", "shield", "shadow", "luck", "double_agent", "lucky_star"]
	for pid in order:
		var data: Dictionary = GameManager.POWER_UPS[pid]
		var card := _create_powerup_card(pid, data)
		items_container.add_child(card)

func _build_upgrade_cards():
	var order := ["cushion", "combo_keeper", "haggler", "treasure_sense", "key_master", "thick_skin"]
	for uid in order:
		var data: Dictionary = GameManager.UPGRADES[uid]
		var card := _create_upgrade_card(uid, data)
		items_container.add_child(card)

func _create_powerup_card(pid: String, data: Dictionary) -> PanelContainer:
	var card := PanelContainer.new()
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.1, 0.06, 0.18, 0.9)
	style.border_color = Color(data.color.r, data.color.g, data.color.b, 0.5)
	style.set_border_width_all(2)
	style.set_corner_radius_all(8)
	style.content_margin_left = 14
	style.content_margin_right = 14
	style.content_margin_top = 10
	style.content_margin_bottom = 10
	card.add_theme_stylebox_override("panel", style)
	card.mouse_filter = Control.MOUSE_FILTER_PASS
	card.gui_input.connect(func(e: InputEvent):
		if e is InputEventMouseButton and e.pressed and not e.is_echo():
			_buy_powerup(pid))

	var hbox := HBoxContainer.new()
	hbox.add_theme_constant_override("separation", 12)
	hbox.mouse_filter = Control.MOUSE_FILTER_IGNORE
	card.add_child(hbox)

	var icon_path := "res://assets/sprites/v3/items/potion_%s.png" % pid
	var icon_tex: Texture2D = load(icon_path) if ResourceLoader.exists(icon_path) else null
	if icon_tex:
		var icon := TextureRect.new()
		icon.texture = icon_tex
		icon.custom_minimum_size = Vector2(56, 56)
		icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		icon.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
		icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
		hbox.add_child(icon)

	var info_vbox := VBoxContainer.new()
	info_vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	info_vbox.add_theme_constant_override("separation", 2)
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
	desc_label.add_theme_font_size_override("font_size", 13)
	desc_label.add_theme_color_override("font_color", Color(0.65, 0.6, 0.75, 0.7))
	desc_label.autowrap_mode = TextServer.AUTOWRAP_WORD
	desc_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	info_vbox.add_child(desc_label)

	var type_label := Label.new()
	type_label.text = data.type.to_upper()
	type_label.add_theme_font_size_override("font_size", 11)
	var type_color := Color(0.5, 0.8, 1.0) if data.type == "manual" else (Color(1.0, 0.7, 0.3) if data.type == "auto" else Color(0.5, 1.0, 0.6))
	type_label.add_theme_color_override("font_color", type_color)
	type_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	info_vbox.add_child(type_label)

	var right_vbox := VBoxContainer.new()
	right_vbox.add_theme_constant_override("separation", 4)
	right_vbox.alignment = BoxContainer.ALIGNMENT_CENTER
	right_vbox.mouse_filter = Control.MOUSE_FILTER_IGNORE
	hbox.add_child(right_vbox)

	var count_label := Label.new()
	count_label.name = "Count"
	var count_val: int = GameManager.items.get(pid, 0)
	count_label.text = "x%d" % count_val if count_val > 0 else "-"
	count_label.add_theme_font_size_override("font_size", 16)
	count_label.add_theme_color_override("font_color", Color(0.7, 0.85, 1.0, 0.8))
	count_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	count_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	right_vbox.add_child(count_label)

	var price := GameManager.get_item_price(pid)
	var buy_btn := Button.new()
	buy_btn.name = "BuyBtn"
	buy_btn.text = "%d" % price
	buy_btn.custom_minimum_size = Vector2(72, 34)
	buy_btn.add_theme_font_size_override("font_size", 16)
	_apply_buy_btn_style(buy_btn)
	buy_btn.disabled = GameManager.wallet < price
	buy_btn.pressed.connect(_buy_powerup.bind(pid))
	right_vbox.add_child(buy_btn)

	return card

func _create_upgrade_card(uid: String, data: Dictionary) -> PanelContainer:
	var card := PanelContainer.new()
	var lvl: int = GameManager.upgrades.get(uid, 0)
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.1, 0.06, 0.18, 0.9)
	style.border_color = Color(0.72, 0.58, 0.22, 0.5)
	style.set_border_width_all(2)
	style.set_corner_radius_all(8)
	style.content_margin_left = 14
	style.content_margin_right = 14
	style.content_margin_top = 10
	style.content_margin_bottom = 10
	card.add_theme_stylebox_override("panel", style)
	card.mouse_filter = Control.MOUSE_FILTER_PASS
	if lvl < 3:
		card.gui_input.connect(func(e: InputEvent):
			if e is InputEventMouseButton and e.pressed and not e.is_echo():
				_buy_upgrade(uid))

	var hbox := HBoxContainer.new()
	hbox.add_theme_constant_override("separation", 12)
	hbox.mouse_filter = Control.MOUSE_FILTER_IGNORE
	card.add_child(hbox)

	var info_vbox := VBoxContainer.new()
	info_vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	info_vbox.add_theme_constant_override("separation", 2)
	info_vbox.mouse_filter = Control.MOUSE_FILTER_IGNORE
	hbox.add_child(info_vbox)

	var name_label := Label.new()
	name_label.text = data.name
	name_label.add_theme_font_size_override("font_size", 18)
	name_label.add_theme_color_override("font_color", Color(1.0, 0.85, 0.3))
	name_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	info_vbox.add_child(name_label)

	var desc_text: String = "MAX" if lvl >= 3 else str(data.desc[lvl])
	var desc_label := Label.new()
	desc_label.text = desc_text
	desc_label.add_theme_font_size_override("font_size", 13)
	desc_label.add_theme_color_override("font_color", Color(0.65, 0.6, 0.75, 0.7))
	desc_label.autowrap_mode = TextServer.AUTOWRAP_WORD
	desc_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	info_vbox.add_child(desc_label)

	var dots := ""
	for i in 3:
		dots += "● " if i < lvl else "○ "
	var dots_label := Label.new()
	dots_label.text = dots.strip_edges()
	dots_label.add_theme_font_size_override("font_size", 14)
	dots_label.add_theme_color_override("font_color", Color(1.0, 0.85, 0.3))
	dots_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	info_vbox.add_child(dots_label)

	var right_vbox := VBoxContainer.new()
	right_vbox.add_theme_constant_override("separation", 4)
	right_vbox.alignment = BoxContainer.ALIGNMENT_CENTER
	right_vbox.mouse_filter = Control.MOUSE_FILTER_IGNORE
	hbox.add_child(right_vbox)

	var buy_btn := Button.new()
	buy_btn.name = "BuyBtn"
	buy_btn.custom_minimum_size = Vector2(80, 34)
	buy_btn.add_theme_font_size_override("font_size", 16)
	_apply_buy_btn_style(buy_btn)

	if lvl >= 3:
		buy_btn.text = "MAX"
		buy_btn.disabled = true
	else:
		var price: int = data.prices[lvl]
		buy_btn.text = "%d" % price
		buy_btn.disabled = GameManager.wallet < price
		buy_btn.pressed.connect(_buy_upgrade.bind(uid))

	right_vbox.add_child(buy_btn)
	return card

func _apply_buy_btn_style(btn: Button):
	var normal := StyleBoxFlat.new()
	normal.bg_color = Color(0.2, 0.45, 0.3, 0.9)
	normal.border_color = Color(0.3, 0.65, 0.4, 0.7)
	normal.set_border_width_all(1)
	normal.border_width_bottom = 2
	normal.set_corner_radius_all(10)
	normal.content_margin_left = 12
	normal.content_margin_right = 12
	normal.content_margin_top = 6
	normal.content_margin_bottom = 6

	var hover := normal.duplicate()
	hover.bg_color = Color(0.25, 0.55, 0.35, 0.95)
	hover.border_color = Color(0.35, 0.75, 0.5, 0.8)

	var disabled := normal.duplicate()
	disabled.bg_color = Color(0.15, 0.12, 0.2, 0.6)
	disabled.border_color = Color(0.25, 0.2, 0.35, 0.4)

	btn.add_theme_stylebox_override("normal", normal)
	btn.add_theme_stylebox_override("hover", hover)
	btn.add_theme_stylebox_override("pressed", hover)
	btn.add_theme_stylebox_override("disabled", disabled)

func _buy_powerup(pid: String):
	if GameManager.buy_item(pid):
		SoundManager.play("purchase")
		_update_wallet()
		_rebuild_cards()
	else:
		SoundManager.play("error")

func _buy_upgrade(uid: String):
	if GameManager.buy_upgrade(uid):
		SoundManager.play("purchase")
		_update_wallet()
		_rebuild_cards()
	else:
		SoundManager.play("error")
