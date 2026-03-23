extends Node2D

const RoomScene := preload("res://scenes/components/room.tscn")
const TreasureChestScene := preload("res://scenes/components/treasure_chest.tscn")
const CoinTex := preload("res://assets/sprites/v3/ui/coin_icon.png")
const KeyTex := preload("res://assets/sprites/v3/ui/key_icon.png")
const StarFilled := preload("res://assets/sprites/v3/ui/star_filled.png")
const StarEmpty := preload("res://assets/sprites/v3/ui/star_empty.png")
const GnomeTex := preload("res://assets/sprites/v3/characters/gnome.png")
const GnomeDialogScene := preload("res://scenes/components/gnome_dialog.tscn")
const ArrowTex := preload("res://assets/sprites/v3/ui/arrow_down.png")
const COMBO_THRESHOLDS := {3: 1.5, 5: 2.0, 7: 2.5}
const CombatScene := preload("res://scenes/combat_overlay.tscn")

@onready var camera: Camera2D = $Camera
@onready var room_container: Node2D = $RoomContainer
@onready var thief: Node2D = $Thief
@onready var level_label: Label = $HUD/HUDContainer/TopPanel/TopBar/LevelVBox/LevelLabel
@onready var score_label: Label = $HUD/HUDContainer/TopPanel/TopBar/ScoreBox/ScoreLabel
@onready var cash_out_btn: Button = $HUD/HUDContainer/CashOutBtn
@onready var pause_btn: Button = $HUD/HUDContainer/TopPanel/TopBar/PauseBtn
@onready var pause_menu: CanvasLayer = $PauseMenu
@onready var game_over_overlay: CanvasLayer = $GameOverOverlay
@onready var timer_bar: ProgressBar = $HUD/HUDContainer/TimerBar
@onready var stars_box: HBoxContainer = $HUD/HUDContainer/TopPanel/TopBar/LevelVBox/StarsBox

@export_group("Layout")
@export var level_spacing := 220.0
@export var base_y := 500.0

var rooms: Array[Node2D] = []
var current_room: Node2D
var current_level_idx := 0
var input_locked := false
var displayed_score := 0
var debug_show_traps := false
var debug_show_keys := false
var debug_show_npc := false
var god_mode := false
var shield_active := false
var current_event := ""
var shaky_tween: Tween

var combo := 0
var accumulated_bonus := 0
var greed_active := false
var shadow_available := false
var luck_passive := false
var double_agent_active := false
var blade_available := false
var combat_overlay: CanvasLayer
var manual_btns: Dictionary = {}
var passive_icons: Array[Control] = []
var level_particles: Array[Sprite2D] = []
var particle_elapsed := 0.0
var bg_sprites: Array[Sprite2D] = []
var keys_collected := 0
var max_floors := 10
var npc_appeared := false
var gnome_node: Node2D
var world_theme := {}
var thief_center_x := 375.0

const NPC_HINTS := [
	["I sense danger behind these doors... be careful!", "hint_trap"],
	["I feel treasure behind one of these doors!", "hint_safe"],
	["Traps lurk above... I can feel them!", "show_trap_count"],
	["Let me clear the path for you...", "bonus_treasure"],
]

var _bg_elapsed := 0.0

func _process(delta: float):
	_update_level_particles(delta)
	_bg_elapsed += delta
	var canvas_mod := get_node_or_null("CanvasModulate")
	if canvas_mod:
		var base_color: Color = world_theme.get("canvas_modulate", Color(0.92, 0.9, 0.95))
		var flicker := sin(_bg_elapsed * 0.8) * 0.015
		canvas_mod.color = Color(base_color.r + flicker, base_color.g + flicker * 0.7, base_color.b + flicker * 0.5)

func _ready():
	Engine.time_scale = 1.0
	world_theme = WorldThemes.get_theme(GameManager.current_world)
	max_floors = WorldThemes.max_floors(GameManager.current_world)
	SoundManager.play_world_music(GameManager.current_world)
	_apply_safe_area()
	_apply_world_theme()
	_spawn_level_atmosphere()
	_build_tower()
	_place_thief()
	_update_hud()
	_update_item_buttons()
	cash_out_btn.pressed.connect(_on_cash_out)
	cash_out_btn.visible = false
	pause_btn.pressed.connect(func(): pause_menu.open())
	timer_bar.visible = false
	_connect_debug()
	MissionManager.mission_completed.connect(_on_mission_toast)
	_setup_power_ups()
	if not GameManager.tutorial_seen:
		_show_tutorial()

func _exit_tree():
	Engine.time_scale = 1.0

func _apply_world_theme():
	var canvas_mod := get_node_or_null("CanvasModulate")
	if canvas_mod and world_theme.has("canvas_modulate"):
		canvas_mod.color = world_theme["canvas_modulate"]

	var vp_width := get_viewport().get_visible_rect().size.x
	var bg_path: String = WorldThemes.WORLD_BG[clampi(GameManager.current_world, 0, 9)]
	var bg_tex: Texture2D = load(bg_path)
	if bg_tex:
		var castle_sprite: Sprite2D = $ParallaxBG/CastleLayer/Castle
		castle_sprite.visible = false
		var tex_size := bg_tex.get_size()
		var fit_scale := maxf(vp_width / tex_size.x, 1.0)
		var tile_h := tex_size.y * fit_scale
		var top_y := -2200.0
		var bottom_y := 3600.0
		var y := top_y
		var castle_layer: Node = $ParallaxBG/CastleLayer
		while y < bottom_y:
			var spr := Sprite2D.new()
			spr.texture = bg_tex
			spr.centered = false
			spr.scale = Vector2(fit_scale, fit_scale)
			spr.position = Vector2((vp_width - tex_size.x * fit_scale) / 2.0, y)
			spr.modulate = Color(1, 1, 1, 0.85)
			castle_layer.add_child(spr)
			bg_sprites.append(spr)
			y += tile_h
		var parallax_layer: ParallaxLayer = $ParallaxBG/CastleLayer
		parallax_layer.motion_scale = Vector2(0, 0.05)
		parallax_layer.motion_mirroring = Vector2.ZERO

func _apply_safe_area():
	if OS.get_name() != "iOS":
		return
	var safe := DisplayServer.get_display_safe_area()
	var screen := DisplayServer.screen_get_size()
	var top_margin := safe.position.y
	var bottom_margin := screen.y - safe.end.y
	var vp_size := get_viewport().get_visible_rect().size
	var scale_y := vp_size.y / float(screen.y)
	var top_safe := top_margin * scale_y
	var bottom_safe := bottom_margin * scale_y

	var top_panel: PanelContainer = $HUD/HUDContainer/TopPanel
	var style := top_panel.get_theme_stylebox("panel").duplicate()
	style.content_margin_top = top_safe
	top_panel.add_theme_stylebox_override("panel", style)
	top_panel.offset_top = 0.0
	top_panel.offset_bottom = 80.0 + top_safe

	var timer: ProgressBar = $HUD/HUDContainer/TimerBar
	timer.offset_top = 88.0 + top_safe
	timer.offset_bottom = 100.0 + top_safe

	var item_bar: PanelContainer = $HUD/HUDContainer/ItemBar
	item_bar.offset_bottom = -10.0 - bottom_safe
	item_bar.offset_top = -80.0 - bottom_safe
	var cash_btn: Button = $HUD/HUDContainer/CashOutBtn
	cash_btn.offset_bottom = -100.0 - bottom_safe
	cash_btn.offset_top = -150.0 - bottom_safe

func _build_tower():
	_build_wall_bg()
	for i in range(max_floors):
		var room: Node2D = RoomScene.instantiate()
		room.position = Vector2(375, base_y - (i + 1) * level_spacing)
		room_container.add_child(room)
		room.setup(i, world_theme)
		room.door_chosen.connect(_on_door_chosen)
		rooms.append(room)

	_enforce_single_npc()
	for i in range(1, max_floors):
		rooms[i].lock_all()
	current_room = rooms[0]
	_build_base_platform()
	_build_victory_area()

const WallTex := preload("res://assets/sprites/v3/tiles/wall1.png")

func _build_wall_bg():
	var top_y := base_y - (max_floors + 3) * level_spacing
	var bottom_y := base_y + 400
	var total_h := bottom_y - top_y
	var wall := Sprite2D.new()
	wall.texture = WallTex
	wall.texture_repeat = CanvasItem.TEXTURE_REPEAT_ENABLED
	wall.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	wall.region_enabled = true
	wall.region_rect = Rect2(0, 0, 375, int(total_h / 2.0))
	wall.scale = Vector2(2.0, 2.0)
	wall.position = Vector2(375, (top_y + bottom_y) / 2.0)
	wall.z_index = -5
	var wall_mod: Color = world_theme.get("wall_modulate", Color(0.55, 0.45, 0.65, 0.8))
	wall.modulate = Color(wall_mod.r * 1.5, wall_mod.g * 1.5, wall_mod.b * 1.5, 0.95)
	room_container.add_child(wall)

const LadderTex := preload("res://assets/sprites/v3/room/ladder.png")
const ChestOpenTex := preload("res://assets/sprites/v3/items/chest_open.png")

var victory_chest: Sprite2D
var victory_glow: Sprite2D
var victory_platform_y := 0.0

const FloorTex := preload("res://assets/sprites/v3/room/stone_floor.png")

func _build_base_platform():
	var plat_node := Node2D.new()
	plat_node.position = Vector2(375, base_y)
	room_container.add_child(plat_node)

	var plat := Sprite2D.new()
	plat.texture = FloorTex
	plat.texture_repeat = CanvasItem.TEXTURE_REPEAT_ENABLED
	plat.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	plat.region_enabled = true
	plat.region_rect = Rect2(0, 0, 400, 24)
	plat.scale = Vector2(2.0, 2.0)
	plat.position = Vector2(0, 45)
	plat.modulate = Color(0.85, 0.75, 0.95, 1.0)
	plat.z_index = 1
	plat_node.add_child(plat)

	var edge := Sprite2D.new()
	edge.texture = FloorTex
	edge.texture_repeat = CanvasItem.TEXTURE_REPEAT_ENABLED
	edge.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	edge.region_enabled = true
	edge.region_rect = Rect2(0, 0, 400, 5)
	edge.scale = Vector2(2.0, 2.0)
	edge.position = Vector2(0, 45 - 24 + 3)
	edge.z_index = 2
	edge.modulate = Color(1.0, 0.9, 1.1, 1.0)
	plat_node.add_child(edge)

	var glow := Sprite2D.new()
	glow.texture = _make_soft_circle(64)
	glow.scale = Vector2(14, 3)
	glow.position = Vector2(0, 35)
	glow.modulate = Color(0.6, 0.4, 0.9, 0.12)
	glow.z_index = 0
	plat_node.add_child(glow)

func _build_victory_area():
	var victory_y := base_y - (max_floors + 1) * level_spacing
	victory_platform_y = victory_y

	var vict_node := Node2D.new()
	vict_node.position = Vector2(375, victory_y)
	room_container.add_child(vict_node)

	var plat := Sprite2D.new()
	plat.texture = FloorTex
	plat.texture_repeat = CanvasItem.TEXTURE_REPEAT_ENABLED
	plat.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	plat.region_enabled = true
	plat.region_rect = Rect2(0, 0, 420, 24)
	plat.scale = Vector2(2.0, 2.0)
	plat.position = Vector2(0, 45)
	plat.modulate = Color(0.95, 0.85, 1.0, 1.0)
	plat.z_index = 1
	vict_node.add_child(plat)

	var edge := Sprite2D.new()
	edge.texture = FloorTex
	edge.texture_repeat = CanvasItem.TEXTURE_REPEAT_ENABLED
	edge.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	edge.region_enabled = true
	edge.region_rect = Rect2(0, 0, 420, 5)
	edge.scale = Vector2(2.0, 2.0)
	edge.position = Vector2(0, 45 - 24 + 3)
	edge.z_index = 2
	edge.modulate = Color(1.1, 1.0, 1.2, 1.0)
	vict_node.add_child(edge)

	var last_ladder_x := 280.0 if (max_floors - 1) % 2 == 0 else -280.0
	var ladder_h := level_spacing
	var tex_size := LadderTex.get_size()
	var fit := ladder_h / tex_size.y
	var ladder := Sprite2D.new()
	ladder.texture = LadderTex
	ladder.scale = Vector2(fit, fit)
	ladder.position = Vector2(last_ladder_x, 45 + ladder_h / 2.0)
	ladder.z_index = -2
	vict_node.add_child(ladder)

	victory_glow = Sprite2D.new()
	victory_glow.texture = _make_soft_circle(64)
	victory_glow.scale = Vector2(12, 12)
	victory_glow.modulate = Color(1.0, 0.85, 0.3, 0.25)
	victory_glow.position = Vector2(0, -20)
	victory_glow.z_index = 4
	vict_node.add_child(victory_glow)
	var glow_tw := create_tween().set_loops()
	glow_tw.tween_property(victory_glow, "modulate:a", 0.4, 1.0).set_ease(Tween.EASE_IN_OUT).set_trans(Tween.TRANS_SINE)
	glow_tw.tween_property(victory_glow, "modulate:a", 0.15, 1.0).set_ease(Tween.EASE_IN_OUT).set_trans(Tween.TRANS_SINE)

	victory_chest = Sprite2D.new()
	victory_chest.texture = ChestOpenTex
	var chest_size := ChestOpenTex.get_size()
	var chest_fit := 120.0 / maxf(chest_size.x, chest_size.y)
	victory_chest.scale = Vector2(chest_fit, chest_fit)
	victory_chest.position = Vector2(0, -10)
	victory_chest.z_index = 5
	vict_node.add_child(victory_chest)

func _enforce_single_npc():
	var found_npc := false
	for room in rooms:
		for door in room.doors:
			if door.is_npc():
				if found_npc:
					door.tile_type = 0
				else:
					found_npc = true
	if not found_npc:
		_inject_npc()

func _inject_npc():
	var candidates: Array[Array] = []
	for room_idx in range(2, mini(8, rooms.size())):
		var room: Node2D = rooms[room_idx]
		for door_idx in range(room.doors.size()):
			var door: Area2D = room.doors[door_idx]
			if door.is_safe() and not door.has_key:
				candidates.append([room_idx, door_idx])
	if candidates.is_empty():
		return
	var pick: Array = candidates[randi() % candidates.size()]
	rooms[pick[0]].doors[pick[1]].tile_type = 5

func _place_thief():
	thief.position = Vector2(375, base_y - 51)
	thief_center_x = 375.0
	camera.position = Vector2(375, thief.position.y - 50)
	camera.follow(thief.position.y)

func _setup_power_ups():
	var sel := GameManager.selected_power_ups
	shield_active = "shield" in sel
	luck_passive = "luck" in sel
	double_agent_active = "double_agent" in sel
	blade_available = "blade" in sel
	shadow_available = "shadow" in sel
	if shield_active:
		thief.set_shield(true)
	_build_power_up_hud()

func _build_power_up_hud():
	var sel := GameManager.selected_power_ups
	var item_bar: PanelContainer = $HUD/HUDContainer/ItemBar
	var potions: HBoxContainer = item_bar.get_node("Potions")
	for child in potions.get_children():
		child.queue_free()
	manual_btns.clear()

	var manual_ids: Array[String] = []
	for pid in sel:
		if GameManager.POWER_UPS.has(pid) and GameManager.POWER_UPS[pid].type == "manual":
			manual_ids.append(pid)

	if manual_ids.is_empty():
		item_bar.visible = false
	else:
		item_bar.visible = true
		for pid in manual_ids:
			var data: Dictionary = GameManager.POWER_UPS[pid]

			var slot_panel := PanelContainer.new()
			var slot_style := StyleBoxFlat.new()
			slot_style.bg_color = Color(0.06, 0.04, 0.1, 0.85)
			slot_style.border_color = Color(0.55, 0.44, 0.18, 0.6)
			slot_style.set_border_width_all(2)
			slot_style.set_corner_radius_all(6)
			slot_style.content_margin_left = 6
			slot_style.content_margin_right = 6
			slot_style.content_margin_top = 4
			slot_style.content_margin_bottom = 4
			slot_panel.add_theme_stylebox_override("panel", slot_style)
			potions.add_child(slot_panel)

			var slot_vbox := VBoxContainer.new()
			slot_vbox.alignment = BoxContainer.ALIGNMENT_CENTER
			slot_vbox.add_theme_constant_override("separation", 2)
			slot_vbox.mouse_filter = Control.MOUSE_FILTER_IGNORE
			slot_panel.add_child(slot_vbox)

			var icon_wrap := Control.new()
			icon_wrap.custom_minimum_size = Vector2(56, 56)
			icon_wrap.mouse_filter = Control.MOUSE_FILTER_IGNORE
			slot_vbox.add_child(icon_wrap)

			var frame_path := "res://assets/sprites/v3/ui/potion_frame.png"
			if ResourceLoader.exists(frame_path):
				var frame := TextureRect.new()
				frame.texture = load(frame_path)
				frame.anchors_preset = Control.PRESET_FULL_RECT
				frame.anchor_right = 1.0
				frame.anchor_bottom = 1.0
				frame.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
				frame.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
				frame.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
				frame.mouse_filter = Control.MOUSE_FILTER_IGNORE
				icon_wrap.add_child(frame)

			var btn := TextureButton.new()
			btn.anchors_preset = Control.PRESET_FULL_RECT
			btn.anchor_right = 1.0
			btn.anchor_bottom = 1.0
			btn.offset_left = 9
			btn.offset_top = 9
			btn.offset_right = -9
			btn.offset_bottom = -9
			btn.ignore_texture_size = true
			btn.stretch_mode = TextureButton.STRETCH_KEEP_ASPECT_CENTERED
			var icon_path := "res://assets/sprites/v3/items/potion_%s.png" % pid
			if ResourceLoader.exists(icon_path):
				btn.texture_normal = load(icon_path)
			icon_wrap.add_child(btn)

			var badge := Label.new()
			badge.name = "Badge"
			badge.text = "1"
			badge.anchors_preset = Control.PRESET_BOTTOM_RIGHT
			badge.anchor_left = 1.0
			badge.anchor_top = 1.0
			badge.anchor_right = 1.0
			badge.anchor_bottom = 1.0
			badge.offset_left = -20
			badge.offset_top = -16
			badge.add_theme_font_size_override("font_size", 15)
			badge.add_theme_color_override("font_color", Color(1, 1, 1, 0.9))
			badge.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.8))
			badge.add_theme_constant_override("outline_size", 3)
			badge.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
			badge.mouse_filter = Control.MOUSE_FILTER_IGNORE
			icon_wrap.add_child(badge)

			var name_label := Label.new()
			name_label.text = data.name.substr(0, 7)
			name_label.add_theme_font_size_override("font_size", 10)
			name_label.add_theme_color_override("font_color", Color(0.9, 0.85, 1.0, 0.7))
			name_label.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.5))
			name_label.add_theme_constant_override("outline_size", 2)
			name_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
			name_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
			slot_vbox.add_child(name_label)

			btn.pressed.connect(_on_manual_power_up.bind(pid))
			manual_btns[pid] = {"btn": btn, "badge": badge, "used": false}

	var passive_row: HBoxContainer = $HUD/HUDContainer.get_node_or_null("PassiveRow")
	if passive_row:
		passive_row.queue_free()
	var non_manual: Array[String] = []
	for pid in sel:
		if GameManager.POWER_UPS.has(pid) and GameManager.POWER_UPS[pid].type != "manual":
			non_manual.append(pid)
	if non_manual.is_empty():
		return
	passive_row = HBoxContainer.new()
	passive_row.name = "PassiveRow"
	passive_row.alignment = BoxContainer.ALIGNMENT_CENTER
	passive_row.add_theme_constant_override("separation", 6)
	passive_row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var hud_container: Control = $HUD/HUDContainer
	hud_container.add_child(passive_row)
	passive_row.set_anchors_preset(Control.PRESET_TOP_WIDE)
	var top_panel: PanelContainer = $HUD/HUDContainer/TopPanel
	var panel_bottom: float = top_panel.offset_bottom
	passive_row.offset_top = panel_bottom + 4
	passive_row.offset_bottom = panel_bottom + 32
	for pid in non_manual:
		var data: Dictionary = GameManager.POWER_UPS[pid]
		var ind_panel := PanelContainer.new()
		var ind_style := StyleBoxFlat.new()
		ind_style.bg_color = Color(0.06, 0.03, 0.12, 0.8)
		ind_style.border_color = Color(data.color.r, data.color.g, data.color.b, 0.5)
		ind_style.set_border_width_all(1)
		ind_style.set_corner_radius_all(6)
		ind_style.content_margin_left = 6
		ind_style.content_margin_right = 6
		ind_style.content_margin_top = 2
		ind_style.content_margin_bottom = 2
		ind_panel.add_theme_stylebox_override("panel", ind_style)
		ind_panel.name = "Ind_" + pid
		ind_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
		passive_row.add_child(ind_panel)

		var ind_hbox := HBoxContainer.new()
		ind_hbox.add_theme_constant_override("separation", 4)
		ind_hbox.mouse_filter = Control.MOUSE_FILTER_IGNORE
		ind_panel.add_child(ind_hbox)

		var icon_path := "res://assets/sprites/v3/items/potion_%s.png" % pid
		if ResourceLoader.exists(icon_path):
			var icon := TextureRect.new()
			icon.texture = load(icon_path)
			icon.custom_minimum_size = Vector2(22, 22)
			icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
			icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
			icon.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
			icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
			ind_hbox.add_child(icon)

		var ind_label := Label.new()
		ind_label.text = data.name
		ind_label.add_theme_font_size_override("font_size", 11)
		ind_label.add_theme_color_override("font_color", data.color)
		ind_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
		ind_hbox.add_child(ind_label)

func _on_manual_power_up(pid: String):
	if input_locked or current_level_idx >= max_floors:
		return
	if manual_btns.has(pid) and manual_btns[pid].used:
		SoundManager.play("error")
		return
	match pid:
		"hint":
			_on_hint()
			_mark_manual_used("hint")
		"oracle":
			_on_oracle()
			_mark_manual_used("oracle")
		"greed":
			_on_greed()
			_mark_manual_used("greed")
		"blade":
			pass

func _mark_manual_used(pid: String):
	if manual_btns.has(pid):
		manual_btns[pid].used = true
		manual_btns[pid].btn.modulate = Color(0.4, 0.4, 0.4)
		manual_btns[pid].badge.text = "0"

func _on_oracle():
	SoundManager.play("potion")
	MissionManager.on_potion_used()
	var room: Node2D = rooms[current_level_idx]
	for door in room.doors:
		if door.revealed:
			continue
		var roll := 0
		if door.is_trap():
			roll = 1 + randi() % 2 if randf() < 0.7 else 3 + randi() % 4
		else:
			roll = 5 + randi() % 2 if randf() < 0.7 else 1 + randi() % 4
		_show_dice_number(door, roll)

func _show_dice_number(door: Area2D, number: int):
	var lbl := Label.new()
	lbl.text = str(number)
	lbl.add_theme_font_size_override("font_size", 36)
	var color := Color(0.3, 1, 0.4) if number >= 5 else (Color(1, 0.3, 0.3) if number <= 2 else Color(1, 0.85, 0.3))
	lbl.add_theme_color_override("font_color", color)
	lbl.add_theme_color_override("font_outline_color", Color(0, 0, 0))
	lbl.add_theme_constant_override("outline_size", 4)
	lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
	lbl.position = Vector2(door.position.x - 15, door.position.y - 80)
	lbl.z_index = 12
	door.get_parent().add_child(lbl)
	lbl.scale = Vector2(0.3, 0.3)
	lbl.pivot_offset = Vector2(15, 20)
	var tw := create_tween()
	tw.tween_property(lbl, "scale", Vector2(1.0, 1.0), 0.2).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_BACK)
	tw.tween_interval(4.0)
	tw.tween_property(lbl, "modulate:a", 0.0, 0.5)
	tw.tween_callback(lbl.queue_free)

func _on_greed():
	SoundManager.play("potion")
	MissionManager.on_potion_used()
	greed_active = true
	_spawn_gold_text("GREED x2!", Vector2(375, 600))

func _on_door_chosen(door: Area2D, room_node: Node2D):
	if input_locked:
		return
	input_locked = true
	cash_out_btn.visible = false
	_stop_shaky_timer()
	var ladder_world_x: float = room_node.position.x + room_node.get_ladder_x()
	var platform_world_y: float = room_node.position.y - 51.0
	var walk_tw: Tween = thief.walk_to(ladder_world_x)
	await walk_tw.finished

	var climb_tw: Tween = thief.climb_to(Vector2(ladder_world_x, platform_world_y))
	await climb_tw.finished
	camera.follow(thief.position.y)
	_spawn_landing_dust(Vector2(ladder_world_x, platform_world_y + 51))

	if door.is_npc():
		SoundManager.play("door_open")
		SoundManager.vibrate_light()
		var reveal_tw: Tween = door.reveal()
		if reveal_tw:
			await reveal_tw.finished
		await get_tree().create_timer(0.3).timeout
		await _on_npc_hint_dialogue(door, room_node)
		var door_world_x: float = room_node.position.x + door.position.x
		await thief.walk_to(door_world_x).finished
		await _on_npc_hint_finalize(door, room_node)
		return

	var door_world_x: float = room_node.position.x + door.position.x
	var walk_tw2: Tween = thief.walk_to(door_world_x)
	await walk_tw2.finished
	await get_tree().create_timer(0.3).timeout

	SoundManager.play("door_open")
	SoundManager.vibrate_light()

	if door.is_safe():
		var reveal_tw: Tween = door.reveal()
		if reveal_tw:
			await reveal_tw.finished
		await get_tree().create_timer(0.3).timeout
		await _on_safe(door, room_node)
	elif door.is_empty():
		var reveal_tw: Tween = door.reveal()
		if reveal_tw:
			await reveal_tw.finished
		await get_tree().create_timer(0.2).timeout
		await _on_empty(door, room_node)
	else:
		if blade_available and door.tile_type == door.TileType.TRAP_GUARD:
			blade_available = false
			_mark_manual_used("blade")
			var reveal_tw: Tween = door.reveal()
			if reveal_tw:
				await reveal_tw.finished
			await _start_combat(door, room_node)
			return
		if shield_active or god_mode:
			var reveal_tw: Tween = door.reveal()
			if reveal_tw:
				await reveal_tw.finished
			if shield_active:
				shield_active = false
				thief.set_shield(false)
				MissionManager.on_trap_survived()
				var ck_lvl: int = GameManager.upgrades.get("combo_keeper", 0)
				if ck_lvl < 2:
					combo = 0
			_update_item_buttons()
			SoundManager.play("shield_break")
			SoundManager.vibrate_medium()
			camera.shake(8.0)
			_spawn_gold_text("SHIELD!", door.global_position)
			await get_tree().create_timer(0.5).timeout
			await _on_safe_no_reward(door, room_node)
		else:
			var thick_lvl: int = GameManager.upgrades.get("thick_skin", 0)
			var survive_chances := [0.0, 0.1, 0.2, 0.3]
			var survive_chance: float = survive_chances[clampi(thick_lvl, 0, 3)]
			if survive_chance > 0.0 and randf() < survive_chance:
				var reveal_tw: Tween = door.reveal()
				if reveal_tw:
					await reveal_tw.finished
				SoundManager.play("shield_break")
				SoundManager.vibrate_medium()
				camera.shake(10.0)
				_spawn_gold_text("THICK SKIN!", door.global_position)
				MissionManager.on_trap_survived()
				await get_tree().create_timer(0.5).timeout
				await _on_safe_no_reward(door, room_node)
			elif shadow_available:
				shadow_available = false
				var reveal_tw: Tween = door.reveal()
				if reveal_tw:
					await reveal_tw.finished
				await _play_trap_effect(door)
				await _show_dodge_window(door, room_node)
			else:
				door.reveal_instant()
				await _play_trap_effect(door)
				await _on_trap(door)

func _show_dodge_window(door: Area2D, room_node: Node2D):
	var dodged := [false]
	var dodge_btn := Button.new()
	dodge_btn.text = "DODGE!"
	dodge_btn.custom_minimum_size = Vector2(200, 70)
	dodge_btn.add_theme_font_size_override("font_size", 32)
	dodge_btn.add_theme_color_override("font_color", Color(0.5, 0.2, 0.8))
	dodge_btn.position = Vector2(275, 600)
	dodge_btn.pivot_offset = Vector2(100, 35)
	dodge_btn.mouse_filter = Control.MOUSE_FILTER_STOP
	$HUD.add_child(dodge_btn)
	dodge_btn.scale = Vector2(0.5, 0.5)
	var show_tw := create_tween()
	show_tw.tween_property(dodge_btn, "scale", Vector2(1.0, 1.0), 0.15).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_BACK)

	dodge_btn.pressed.connect(func():
		if dodged[0]:
			return
		dodged[0] = true
		SoundManager.play("potion")
		SoundManager.vibrate_light()
		_spawn_gold_text("DODGED!", door.global_position)
		dodge_btn.queue_free()
		_dim_passive_indicator("shadow")
		door.lock()
		room_node.unlock_all()
		input_locked = false
		_update_item_buttons()
	)

	await get_tree().create_timer(1.5).timeout
	if not dodged[0]:
		dodged[0] = true
		dodge_btn.queue_free()
		await _on_trap(door)

func _start_combat(door: Area2D, room_node: Node2D):
	if not combat_overlay:
		combat_overlay = CombatScene.instantiate()
		add_child(combat_overlay)
	var result := [false]
	combat_overlay.combat_finished.connect(func(success: bool):
		result[0] = success
	, CONNECT_ONE_SHOT)
	combat_overlay.start()
	await combat_overlay.combat_finished
	if result[0]:
		SoundManager.play("coin")
		_spawn_gold_text("WRAITH DEFEATED!", door.global_position)
		await get_tree().create_timer(0.5).timeout
		await _on_safe_no_reward(door, room_node)
	else:
		await _on_trap(door)

func _dim_passive_indicator(pid: String):
	var passive_row := $HUD/HUDContainer.get_node_or_null("PassiveRow")
	if not passive_row:
		return
	var ind := passive_row.get_node_or_null("Ind_" + pid)
	if ind and is_instance_valid(ind):
		var tw := create_tween().bind_node(ind)
		tw.tween_property(ind, "modulate:a", 0.25, 0.3)

func _on_safe(door: Area2D, room_node: Node2D):
	combo += 1
	MissionManager.on_floor_cleared()
	MissionManager.on_treasure_found()
	MissionManager.on_combo(combo)

	var combo_mult := 1.0
	var ck_lvl: int = GameManager.upgrades.get("combo_keeper", 0)
	var thresholds := {2: 1.5, 4: 2.0, 6: 2.5} if ck_lvl >= 3 else COMBO_THRESHOLDS
	for threshold in [7, 6, 5, 4, 3, 2]:
		if thresholds.has(threshold) and combo >= threshold:
			combo_mult = thresholds[threshold]
			break

	var base_reward := GameManager.reward(current_level_idx + 1)
	if current_event == "cursed":
		base_reward = 0
	elif current_event == "double_loot":
		base_reward *= 2
	if greed_active:
		base_reward *= 2
		greed_active = false
	var combo_bonus := int(float(base_reward) * (combo_mult - 1.0))
	accumulated_bonus += combo_bonus

	if door.has_key:
		var km_lvl: int = GameManager.upgrades.get("key_master", 0)
		var km_mults := [1.0, 1.5, 2.0, 2.0]
		var km_mult: float = km_mults[clampi(km_lvl, 0, 3)]
		var key_bonus := int(15.0 * WorldThemes.WORLD_REWARD_MULT[clampi(GameManager.current_world, 0, 9)] * km_mult)
		accumulated_bonus += key_bonus
		keys_collected += 1

	GameManager.complete_level(accumulated_bonus)
	current_level_idx += 1

	SoundManager.play("coin")
	SoundManager.vibrate_light()
	var display_reward := base_reward + combo_bonus
	if door.has_key:
		var key_bonus := int(15.0 * WorldThemes.WORLD_REWARD_MULT[clampi(GameManager.current_world, 0, 9)])
		display_reward += key_bonus
		_spawn_key_effect(door.global_position)
		await get_tree().create_timer(0.7).timeout
	_spawn_gold_text("+%d" % display_reward, door.global_position)
	_spawn_coin_burst(door.global_position)

	if COMBO_THRESHOLDS.has(combo):
		_show_combo_text(combo_mult)
	_combo_visual_feedback(combo)

	_animate_score(GameManager.score)
	_update_hud()
	current_event = ""

	if current_level_idx >= max_floors:
		await get_tree().create_timer(0.5).timeout
		_handle_victory()
		return

	await _unlock_next_level()

func _on_safe_no_reward(_door: Area2D, _room_node: Node2D):
	combo = 0
	GameManager.current_level += 1
	current_level_idx = GameManager.current_level
	_update_hud()
	current_event = ""

	if current_level_idx >= max_floors:
		_handle_victory()
		return

	await _unlock_next_level()

func _on_empty(_door: Area2D, room_node: Node2D):
	var ck_lvl: int = GameManager.upgrades.get("combo_keeper", 0)
	if ck_lvl >= 1:
		combo += 1
	GameManager.current_level += 1
	current_level_idx = GameManager.current_level
	_spawn_gold_text("Empty...", _door.global_position)
	_update_hud()
	current_event = ""

	if current_level_idx >= max_floors:
		_handle_victory()
		return

	await _unlock_next_level()

func _on_npc_hint_dialogue(door: Area2D, room_node: Node2D):
	npc_appeared = true
	MissionManager.on_npc_met()

	var hint_data: Array = NPC_HINTS[randi() % NPC_HINTS.size()]
	var hint_text: String = hint_data[0]
	var hint_type: String = hint_data[1]

	SoundManager.play("event")
	door.visual.start_spritesheet_anim(4, 4, 2.5)

	var next_idx := current_level_idx + 1
	if next_idx < max_floors:
		var next_room: Node2D = rooms[next_idx]
		match hint_type:
			"hint_trap":
				next_room.highlight_traps()
			"hint_safe":
				next_room.highlight_safe()
			"bonus_treasure":
				var bonus_door: Area2D = null
				for d in next_room.doors:
					if d.is_trap() and not d.revealed:
						d.tile_type = 0
						bonus_door = d
						break
				if bonus_door:
					next_room.highlight_door(bonus_door, Color(1.0, 0.85, 0.2))
			"show_trap_count":
				var trap_n := 0
				for d in next_room.doors:
					if d.is_trap():
						trap_n += 1
				next_room.highlight_traps()
				_spawn_gold_text("%d traps!" % trap_n, door.global_position + Vector2(0, -60))

	await _spawn_gnome(door.global_position, hint_text)

	if double_agent_active and next_idx < max_floors:
		var second_hint: Array = NPC_HINTS[randi() % NPC_HINTS.size()]
		while second_hint[1] == hint_type:
			second_hint = NPC_HINTS[randi() % NPC_HINTS.size()]
		var second_type: String = second_hint[1]
		var next_room2: Node2D = rooms[next_idx]
		match second_type:
			"hint_trap":
				next_room2.highlight_traps()
			"hint_safe":
				next_room2.highlight_safe()
			"bonus_treasure":
				for d in next_room2.doors:
					if d.is_trap() and not d.revealed:
						d.tile_type = 0
						next_room2.highlight_door(d, Color(1.0, 0.85, 0.2))
						break
			"show_trap_count":
				var trap_n2 := 0
				for d in next_room2.doors:
					if d.is_trap():
						trap_n2 += 1
				next_room2.highlight_traps()
				_spawn_gold_text("%d traps!" % trap_n2, door.global_position + Vector2(0, -100))
		await _spawn_gnome(door.global_position, second_hint[0])

	door.visual.stop_spritesheet_anim()

func _on_npc_hint_finalize(door: Area2D, room_node: Node2D):
	var hide_tw := create_tween()
	hide_tw.tween_property(door.visual, "modulate:a", 0.0, 0.2)
	hide_tw.tween_callback(func(): door.visual.visible = false)
	await hide_tw.finished

	GameManager.current_level += 1
	current_level_idx = GameManager.current_level
	_update_hud()
	current_event = ""

	if current_level_idx >= max_floors:
		_handle_victory()
		return

	await _unlock_next_level()

func _climb_to_next_floor():
	if current_level_idx >= rooms.size():
		return
	var next_room: Node2D = rooms[current_level_idx]
	var ladder_world_x: float = next_room.position.x + next_room.get_ladder_x()
	var platform_y: float = next_room.position.y - 51.0

	var walk_tw: Tween = thief.walk_to(ladder_world_x)
	await walk_tw.finished

	var climb_tw: Tween = thief.climb_to(Vector2(ladder_world_x, platform_y))
	await climb_tw.finished
	camera.follow(thief.position.y)

func _unlock_next_level():
	cash_out_btn.visible = true
	cash_out_btn.text = "LEAVE (%d/%d)" % [current_level_idx, max_floors]
	if current_level_idx < rooms.size():
		current_room = rooms[current_level_idx]
		if luck_passive:
			current_room.apply_luck()
		_roll_event(current_level_idx)
		var skip_memory: bool = current_level_idx == 0 or current_event == "shaky_floor" or current_room.has_npc_door()
		if not skip_memory:
			var diff := clampi(int(GameManager.difficulty), 0, 2)
			var peek_times := [2.0, 1.5, 1.0]
			var shuffle_counts := [4, 6, 8]
			var shuffle_speeds := [0.4, 0.35, 0.25]
			await current_room.memory_shuffle(peek_times[diff], shuffle_counts[diff], shuffle_speeds[diff])
		else:
			current_room.unlock_all()
		var ts_lvl: int = GameManager.upgrades.get("treasure_sense", 0)
		var ts_chances := [0.0, 0.05, 0.1, 0.15]
		var ts_chance: float = ts_chances[clampi(ts_lvl, 0, 3)]
		if ts_chance > 0.0 and randf() < ts_chance:
			var idx: int = current_room.get_random_unrevealed_idx()
			if idx >= 0:
				current_room.show_hint(idx)
				_spawn_gold_text("SENSE!", current_room.global_position + Vector2(0, -40))
	input_locked = false
	_update_item_buttons()
	level_label.pivot_offset = level_label.size / 2
	var ltw := create_tween()
	ltw.tween_property(level_label, "scale", Vector2(1.15, 1.15), 0.1).set_ease(Tween.EASE_OUT)
	ltw.tween_property(level_label, "scale", Vector2(1.0, 1.0), 0.15)
	var ztw := create_tween()
	ztw.tween_property(camera, "zoom", Vector2(1.015, 1.015), 0.1).set_ease(Tween.EASE_OUT)
	ztw.tween_property(camera, "zoom", Vector2(1.0, 1.0), 0.15).set_ease(Tween.EASE_IN_OUT)
	var flash := ColorRect.new()
	flash.color = Color(1, 1, 1, 0.05)
	flash.mouse_filter = Control.MOUSE_FILTER_IGNORE
	flash.set_anchors_preset(Control.PRESET_FULL_RECT)
	$HUD.add_child(flash)
	var fltw := create_tween()
	fltw.tween_property(flash, "color:a", 0.0, 0.2)
	fltw.tween_callback(flash.queue_free)

var _gnome_dialog: CanvasLayer

func _spawn_gnome(_tile_pos: Vector2, hint_text: String):
	if gnome_node:
		gnome_node.queue_free()
	await _show_gnome_dialog(hint_text)

func _show_gnome_dialog(hint_text: String) -> void:
	if _gnome_dialog and is_instance_valid(_gnome_dialog):
		_gnome_dialog.queue_free()

	_gnome_dialog = GnomeDialogScene.instantiate()
	add_child(_gnome_dialog)

	var panel: PanelContainer = _gnome_dialog.get_node("Root/Panel")
	var hint_label: Label = _gnome_dialog.get_node("Root/Panel/HBox/TextVBox/HintLabel")
	hint_label.text = ""

	var slide_in := create_tween().set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_BACK).set_parallel(true)
	slide_in.tween_property(panel, "offset_left", 120.0, 0.4)
	slide_in.tween_property(panel, "offset_right", 620.0, 0.4)
	await slide_in.finished

	_typewriter_label(hint_label, hint_text)
	await get_tree().create_timer(maxf(2.5, float(hint_text.length()) * 0.07 + 1.5)).timeout

	var slide_out := create_tween().set_ease(Tween.EASE_IN).set_trans(Tween.TRANS_QUAD).set_parallel(true)
	slide_out.tween_property(panel, "offset_left", 780.0, 0.3)
	slide_out.tween_property(panel, "offset_right", 1280.0, 0.3)
	await slide_out.finished

	if _gnome_dialog and is_instance_valid(_gnome_dialog):
		_gnome_dialog.queue_free()
		_gnome_dialog = null

func _typewriter_label(label: Label, full_text: String):
	label.text = ""
	var state := [0]
	var timer := Timer.new()
	timer.wait_time = 0.04
	timer.autostart = true
	label.add_child(timer)
	timer.timeout.connect(func():
		if state[0] < full_text.length():
			label.text += full_text[state[0]]
			state[0] += 1
		else:
			timer.queue_free()
	)

func _handle_victory():
	var last_room: Node2D = rooms[max_floors - 1]
	var ladder_x := 280.0 if (max_floors - 1) % 2 == 0 else -280.0
	var ladder_world_x: float = last_room.position.x + ladder_x
	await thief.walk_to(ladder_world_x).finished

	var climb_target := Vector2(375 + ladder_x, victory_platform_y - 6)
	await thief.climb_to(climb_target).finished
	camera.follow(thief.position.y)

	await thief.walk_to(375.0).finished
	await get_tree().create_timer(0.2).timeout

	if victory_chest:
		var chest_tw := create_tween()
		chest_tw.tween_property(victory_chest, "scale", victory_chest.scale * 1.3, 0.2).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_BACK)
		chest_tw.tween_property(victory_chest, "scale", victory_chest.scale, 0.15)
	if victory_glow:
		var glow_pop := create_tween()
		glow_pop.tween_property(victory_glow, "scale", Vector2(20, 20), 0.3).set_ease(Tween.EASE_OUT)
		glow_pop.tween_property(victory_glow, "modulate:a", 0.5, 0.3)

	SoundManager.play("victory")
	SoundManager.vibrate_medium()
	thief.victory_bounce()
	_spawn_victory_shower()
	await get_tree().create_timer(1.0).timeout
	var had_max := GameManager.has_max_stars()
	var old_unlocked := GameManager.worlds_unlocked
	MissionManager.on_run_end(current_level_idx, GameManager.current_world, int(GameManager.difficulty), GameManager.score, "victory")
	GameManager.victory()
	var unlocked_name := ""
	if GameManager.worlds_unlocked > old_unlocked:
		unlocked_name = WorldThemes.WORLD_NAMES[old_unlocked]
	if had_max:
		game_over_overlay.show_victory_no_reward()
	else:
		game_over_overlay.show_victory(GameManager.score, GameManager.score, unlocked_name)

func _on_trap(_door: Area2D):
	combo = 0
	camera.shake(28.0)
	_flash_red()
	SoundManager.vibrate_heavy()
	MissionManager.on_run_end(current_level_idx, GameManager.current_world, int(GameManager.difficulty), 0, "trap")
	await get_tree().create_timer(0.5).timeout

	SoundManager.play("fall")
	var fall_tw: Tween = thief.fall_down(800)
	await fall_tw.finished

	SoundManager.play("gameover")
	var penalty := GameManager.game_over()
	await get_tree().create_timer(0.3).timeout
	game_over_overlay.show_game_over(penalty)

func _on_cash_out():
	if input_locked:
		return
	input_locked = true
	_stop_shaky_timer()
	SoundManager.play("click")
	var had_max := GameManager.has_max_stars()
	var earned := GameManager.score
	MissionManager.on_run_end(current_level_idx, GameManager.current_world, int(GameManager.difficulty), earned, "cashout")
	GameManager.cash_out()
	if had_max:
		game_over_overlay.show_cash_out_no_reward()
	else:
		game_over_overlay.show_cash_out(GameManager.score, earned)

func _on_hint():
	if input_locked or current_level_idx >= max_floors:
		return
	SoundManager.play("potion")
	MissionManager.on_potion_used()
	_spawn_potion_effect(Vector2(375, 1200), Color(0.3, 0.85, 1.0))
	var room: Node2D = rooms[current_level_idx]
	var idx: int = room.get_random_unrevealed_idx()
	if idx >= 0:
		room.show_hint(idx)

func _roll_event(level_idx: int):
	current_event = ""
	if level_idx < 2 or level_idx >= max_floors - 1:
		return
	if randf() > 0.3:
		return
	var room: Node2D = rooms[level_idx]
	var events := ["cursed", "double_loot", "shaky_floor", "blessing"]
	var ev: String = events[randi() % events.size()]
	current_event = ev
	match ev:
		"cursed":
			_show_event_label("CURSED FLOOR", Color(0.7, 0.2, 0.8))
			room.curse_doors()
			_event_cursed_effect()
		"double_loot":
			_show_event_label("DOUBLE LOOT", Color(1.0, 0.84, 0.0))
			room.shimmer_doors()
		"shaky_floor":
			_show_event_label("SHAKY FLOOR", Color(0.9, 0.4, 0.3))
			_start_shaky_timer()
		"blessing":
			_show_event_label("BLESSING", Color(0.3, 0.9, 0.6))
			room.apply_luck()
			_event_blessing_effect()

func _start_shaky_timer():
	timer_bar.visible = true
	timer_bar.value = 100.0
	shaky_tween = create_tween()
	shaky_tween.tween_property(timer_bar, "value", 0.0, 5.0)
	shaky_tween.tween_callback(_shaky_auto_choose)

func _stop_shaky_timer():
	if shaky_tween and shaky_tween.is_running():
		shaky_tween.kill()
	timer_bar.visible = false

func _shaky_auto_choose():
	timer_bar.visible = false
	if input_locked or current_level_idx >= max_floors:
		return
	if current_level_idx < rooms.size():
		var room: Node2D = rooms[current_level_idx]
		var idx: int = room.get_random_unrevealed_idx()
		if idx >= 0:
			var door: Area2D = room.doors[idx]
			room._on_door_tapped(door)

func _event_cursed_effect():
	var canvas_mod := get_node_or_null("CanvasModulate")
	if canvas_mod:
		var dark_color := Color(canvas_mod.color.r * 0.85, canvas_mod.color.g * 0.8, canvas_mod.color.b * 0.85)
		var dtw := create_tween()
		dtw.tween_property(canvas_mod, "color", dark_color, 0.5).set_ease(Tween.EASE_IN_OUT)

func _event_blessing_effect():
	var flash := ColorRect.new()
	flash.color = Color(0.3, 0.9, 0.6, 0.08)
	flash.mouse_filter = Control.MOUSE_FILTER_IGNORE
	flash.set_anchors_preset(Control.PRESET_FULL_RECT)
	$HUD.add_child(flash)
	var ftw := create_tween()
	ftw.tween_property(flash, "color:a", 0.0, 0.5)
	ftw.tween_callback(flash.queue_free)

func _play_trap_effect(door: Area2D) -> void:
	SoundManager.play("tile_trap")
	var orig_pos: Vector2 = door.position
	var orig_scale: Vector2 = door.visual.scale
	_slowmo_hit()
	var tw := create_tween()
	match door.tile_type:
		door.TileType.TRAP_SPIKES:
			_play_spikes_effect(door, tw, orig_pos, orig_scale)
		door.TileType.TRAP_ROCK:
			_play_rock_effect(door, tw, orig_pos, orig_scale)
		door.TileType.TRAP_GUARD:
			_play_wraith_effect(door, tw, orig_pos, orig_scale)
	await tw.finished

func _play_spikes_effect(door: Area2D, tw: Tween, _orig_pos: Vector2, orig_scale: Vector2):
	door.visual.scale = Vector2(orig_scale.x, 0.0)
	door.visual.modulate = Color(1, 0.6, 0.3)
	tw.tween_property(door.visual, "scale:y", orig_scale.y * 1.15, 0.15).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_BACK)
	tw.tween_property(door.visual, "scale:y", orig_scale.y, 0.08)
	tw.tween_callback(func():
		camera.shake(15.0)
		_spawn_trap_particles(door.global_position, Color(1, 0.3, 0.2), 8)
		_spawn_impact_ring(door.global_position, Color(1, 0.35, 0.15)))
	tw.parallel().tween_property(door.visual, "modulate", Color.WHITE, 0.3)

func _play_rock_effect(door: Area2D, tw: Tween, orig_pos: Vector2, _orig_scale: Vector2):
	door.visible = false
	door.position.y = orig_pos.y - 200.0
	var shadow := Sprite2D.new()
	shadow.texture = _make_soft_circle()
	shadow.position = Vector2(orig_pos.x, orig_pos.y + 20)
	shadow.scale = Vector2(3, 1.5)
	shadow.modulate = Color(0, 0, 0, 0.0)
	shadow.z_index = 5
	door.get_parent().add_child(shadow)
	var stw := create_tween().set_parallel(true)
	stw.tween_property(shadow, "scale", Vector2(10, 5), 0.25)
	stw.tween_property(shadow, "modulate:a", 0.3, 0.25)
	tw.tween_callback(func(): door.visible = true)
	tw.tween_property(door, "position:y", orig_pos.y + 8.0, 0.25).set_ease(Tween.EASE_IN).set_trans(Tween.TRANS_QUAD)
	tw.tween_property(door, "position:y", orig_pos.y, 0.06)
	tw.tween_callback(func():
		camera.shake(22.0)
		_spawn_trap_particles(door.global_position, Color(0.6, 0.5, 0.4), 5)
		_spawn_impact_ring(door.global_position, Color(0.7, 0.55, 0.35))
		var ftw := create_tween()
		ftw.tween_property(shadow, "modulate:a", 0.0, 0.3)
		ftw.tween_callback(shadow.queue_free))

func _play_wraith_effect(door: Area2D, tw: Tween, orig_pos: Vector2, orig_scale: Vector2):
	door.visual.modulate = Color(0.7, 0.3, 1.0)
	door.visual.scale = orig_scale * 0.0
	_spawn_dark_cloud(door.global_position)
	_spawn_wraith_vortex(door.global_position)
	tw.tween_property(door.visual, "scale", orig_scale * 1.15, 0.25).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_BACK)
	tw.tween_property(door.visual, "scale", orig_scale, 0.1)
	tw.tween_callback(func(): camera.shake(18.0))
	tw.tween_property(door, "position:x", orig_pos.x + 8.0, 0.04)
	tw.tween_property(door, "position:x", orig_pos.x - 8.0, 0.04)
	tw.tween_property(door, "position:x", orig_pos.x, 0.04)
	tw.parallel().tween_property(door.visual, "modulate", Color.WHITE, 0.4)
	tw.tween_callback(func(): _wraith_pulse(door.visual, orig_scale))

func _slowmo_hit():
	Engine.time_scale = 0.5
	get_tree().create_timer(0.15, true, false, true).timeout.connect(func():
		var rtw := create_tween().set_process_mode(Tween.TWEEN_PROCESS_PHYSICS)
		rtw.tween_method(func(v: float): Engine.time_scale = v, 0.5, 1.0, 0.1))

func _spawn_trap_particles(pos: Vector2, color: Color, count: int):
	var tex := _make_soft_circle()
	for i in count:
		var spr := Sprite2D.new()
		spr.texture = tex
		spr.scale = Vector2(2.5, 2.5)
		spr.z_index = 9
		spr.modulate = Color(color.r, color.g, color.b, 0.9)
		spr.position = pos + Vector2(0, -40)
		room_container.add_child(spr)
		var angle := randf() * TAU
		var dist := randf_range(60, 140)
		var target := spr.position + Vector2(cos(angle) * dist, sin(angle) * dist)
		var ptw := create_tween().set_parallel(true)
		ptw.tween_property(spr, "position", target, 0.5).set_ease(Tween.EASE_OUT)
		ptw.tween_property(spr, "scale", Vector2(0.3, 0.3), 0.5)
		ptw.tween_property(spr, "modulate:a", 0.0, 0.4).set_delay(0.1)
		ptw.chain().tween_callback(spr.queue_free)

func _spawn_impact_ring(pos: Vector2, color: Color):
	var spr := Sprite2D.new()
	spr.texture = _make_soft_circle()
	spr.position = pos + Vector2(0, -40)
	spr.scale = Vector2(2, 2)
	spr.modulate = Color(color.r, color.g, color.b, 0.7)
	spr.z_index = 8
	room_container.add_child(spr)
	var tw := create_tween().set_parallel(true)
	tw.tween_property(spr, "scale", Vector2(18, 18), 0.4).set_ease(Tween.EASE_OUT)
	tw.tween_property(spr, "modulate:a", 0.0, 0.4)
	tw.chain().tween_callback(spr.queue_free)

func _spawn_dark_cloud(pos: Vector2):
	var tex := _make_soft_circle()
	var base := pos - Vector2(0, 40)
	for i in 4:
		var spr := Sprite2D.new()
		spr.texture = tex
		spr.scale = Vector2(randf_range(6, 10), randf_range(5, 8))
		spr.position = base + Vector2(randf_range(-30, 30), randf_range(-20, 20))
		spr.modulate = Color(0.2, 0.1, 0.3, 0.5)
		spr.z_index = 8
		room_container.add_child(spr)
		var dtw := create_tween().set_parallel(true)
		dtw.tween_property(spr, "scale", spr.scale * 2.0, 0.6).set_ease(Tween.EASE_OUT)
		dtw.tween_property(spr, "modulate:a", 0.0, 0.6)
		dtw.chain().tween_callback(spr.queue_free)

func _spawn_wraith_vortex(pos: Vector2):
	var tex := _make_soft_circle()
	var base := pos - Vector2(0, 40)
	for i in 10:
		var spr := Sprite2D.new()
		spr.texture = tex
		spr.scale = Vector2(2, 2)
		spr.z_index = 9
		spr.modulate = Color(0.6, 0.2, 1.0, 0.8)
		var angle := float(i) / 10.0 * TAU
		var radius := 20.0
		spr.position = base + Vector2(cos(angle) * radius, sin(angle) * radius)
		room_container.add_child(spr)
		var end_radius := randf_range(80, 130)
		var end_angle := angle + randf_range(1.0, 2.5)
		var target := base + Vector2(cos(end_angle) * end_radius, sin(end_angle) * end_radius)
		var vtw := create_tween().set_parallel(true)
		vtw.tween_property(spr, "position", target, 0.5).set_ease(Tween.EASE_OUT)
		vtw.tween_property(spr, "scale", Vector2(0.5, 0.5), 0.5)
		vtw.tween_property(spr, "modulate:a", 0.0, 0.4).set_delay(0.1)
		vtw.chain().tween_callback(spr.queue_free)

func _wraith_pulse(visual: Sprite2D, _base_scale: Vector2):
	if not is_instance_valid(visual):
		return
	var ptw := create_tween()
	for i in 3:
		ptw.tween_property(visual, "modulate:a", 0.6, 0.1)
		ptw.tween_property(visual, "modulate:a", 1.0, 0.1)
	ptw.tween_property(visual, "modulate", Color.WHITE, 0.1)

func _spawn_gold_text(text: String, pos: Vector2):
	var container := Node2D.new()
	container.z_index = 10
	container.position = pos + Vector2(0, -60)
	room_container.add_child(container)

	var font := ThemeDB.fallback_font
	var font_size := 56
	var text_size := font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size)
	var total_width: float = text_size.x + 44

	var lbl := Label.new()
	lbl.text = text
	lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
	lbl.add_theme_font_size_override("font_size", font_size)
	lbl.add_theme_color_override("font_color", Color(1, 0.84, 0))
	lbl.add_theme_color_override("font_outline_color", Color(0.2, 0.1, 0))
	lbl.add_theme_constant_override("outline_size", 6)
	lbl.position = Vector2(-total_width / 2, -text_size.y / 2)
	container.add_child(lbl)

	var coin := Sprite2D.new()
	var coin_atlas := AtlasTexture.new()
	coin_atlas.atlas = CoinTex
	coin_atlas.region = Rect2(0, 0, 128, 128)
	coin.texture = coin_atlas
	coin.scale = Vector2(0.28, 0.28)
	coin.position = Vector2(total_width / 2 - 20, -8)
	container.add_child(coin)

	var tw := create_tween().set_parallel(true)
	tw.tween_property(container, "position:y", container.position.y - 100, 1.0).set_ease(Tween.EASE_OUT)
	tw.tween_property(container, "modulate:a", 0.0, 1.0).set_delay(0.4)
	tw.chain().tween_callback(container.queue_free)

func _animate_score(target: int):
	var tw := create_tween()
	tw.tween_method(_set_displayed_score, displayed_score, target, 0.4).set_ease(Tween.EASE_OUT)
	score_label.pivot_offset = score_label.size / 2
	var ptw := create_tween()
	ptw.tween_property(score_label, "scale", Vector2(1.25, 1.25), 0.1).set_ease(Tween.EASE_OUT)
	ptw.tween_property(score_label, "scale", Vector2(1.0, 1.0), 0.15).set_ease(Tween.EASE_IN)

func _set_displayed_score(val: int):
	displayed_score = val
	score_label.text = "%d" % val

func _update_hud():
	level_label.text = "%s — %d/%d" % [WorldThemes.WORLD_NAMES[clampi(GameManager.current_world, 0, 9)], mini(current_level_idx, max_floors), max_floors]
	score_label.text = "%d" % GameManager.score
	var saved := GameManager.current_stars()
	var live := GameManager._calc_stars(current_level_idx)
	var star_count := maxi(saved, live)
	_fill_stars(stars_box, star_count)

func _update_item_buttons():
	pass

var _active_banners: Array[Dictionary] = []

func _show_event_label(text: String, color: Color, sfx := "event"):
	_spawn_banner(text, color, sfx, 2.0)

func _show_combo_label(text: String, color: Color):
	_spawn_banner(text, color, "combo", 1.8)

func _show_key_label():
	_spawn_banner("+KEY", Color(1, 0.85, 0.3), "key", 1.5)

func _spawn_banner(text: String, color: Color, sfx: String, hold: float) -> Tween:
	SoundManager.play(sfx)
	var slot := _active_banners.size()
	var banner_y := 160.0 + slot * 56.0

	var panel := PanelContainer.new()
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.05, 0.02, 0.1, 0.75)
	style.border_color = Color(color.r, color.g, color.b, 0.5)
	style.border_width_bottom = 2
	style.border_width_top = 2
	style.corner_radius_top_left = 12
	style.corner_radius_top_right = 12
	style.corner_radius_bottom_left = 12
	style.corner_radius_bottom_right = 12
	style.content_margin_left = 24
	style.content_margin_right = 24
	style.content_margin_top = 6
	style.content_margin_bottom = 6
	panel.add_theme_stylebox_override("panel", style)
	panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	$HUD.add_child(panel)

	var lbl := Label.new()
	lbl.text = text
	lbl.add_theme_font_size_override("font_size", 32)
	lbl.add_theme_color_override("font_color", color)
	lbl.add_theme_color_override("font_outline_color", Color(0, 0, 0))
	lbl.add_theme_constant_override("outline_size", 5)
	lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
	panel.add_child(lbl)

	var font := ThemeDB.fallback_font
	var text_width: float = font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, 32).x
	var panel_width := text_width + 48.0
	var panel_height := 44.0
	panel.custom_minimum_size = Vector2(panel_width, panel_height)
	panel.size = Vector2(panel_width, panel_height)
	panel.position.x = 375.0 - panel_width / 2.0
	panel.pivot_offset = Vector2(panel_width / 2.0, panel_height / 2.0)

	panel.modulate = Color(1, 1, 1, 0)
	panel.position.y = banner_y - 60
	panel.scale = Vector2(0.7, 0.7)

	var tw := create_tween().set_parallel(true)
	tw.tween_property(panel, "modulate:a", 1.0, 0.15)
	tw.tween_property(panel, "position:y", banner_y, 0.2).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_BACK)
	tw.tween_property(panel, "scale", Vector2(1.0, 1.0), 0.2).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_BACK)
	tw.chain().tween_interval(hold)
	tw.chain().tween_property(panel, "modulate:a", 0.0, 0.4)
	tw.chain().tween_property(panel, "position:y", banner_y - 20, 0.4).set_ease(Tween.EASE_IN)
	tw.chain().tween_callback(func():
		panel.queue_free()
		_active_banners = _active_banners.filter(func(b: Dictionary): return b["panel"] != panel))

	var entry := {"panel": panel, "tween": tw}
	_active_banners.append(entry)
	return tw

var _particle_world := 0
var _fx_layer: CanvasLayer

func _spawn_level_atmosphere():
	var p_color: Color = world_theme.get("particle_color", Color(0.7, 0.5, 0.3))
	_particle_world = GameManager.current_world

	_fx_layer = CanvasLayer.new()
	_fx_layer.layer = 2
	_fx_layer.follow_viewport_enabled = true
	add_child(_fx_layer)

	var small_tex := GameManagerClass.make_soft_circle(12)
	var big_tex := GameManagerClass.make_soft_circle(28)

	for j in 40:
		var spr := Sprite2D.new()
		var is_big := j % 4 == 0
		spr.texture = big_tex if is_big else small_tex
		spr.position = Vector2(randf_range(20, 730), randf_range(80, 1250))
		var p_scale := randf_range(2.0, 4.5) if is_big else randf_range(0.6, 1.8)
		spr.scale = Vector2(p_scale, p_scale)
		spr.modulate = Color(p_color.r, p_color.g, p_color.b, randf_range(0.05, 0.15))
		_fx_layer.add_child(spr)
		level_particles.append(spr)

func _update_level_particles(delta: float):
	particle_elapsed += delta
	for i in level_particles.size():
		var spr: Sprite2D = level_particles[i]
		var phase := float(i) * 0.7
		var speed := 0.5 + float(i % 7) * 0.12
		var pulse := sin(particle_elapsed * speed + phase)
		spr.modulate.a = clampf(pulse * 0.15 + 0.1, 0.02, 0.25)

		match _particle_world:
			7:
				spr.position.y -= delta * (20.0 + float(i % 5) * 5.0)
				spr.position.x += sin(particle_elapsed * 2.0 + phase) * delta * 15.0
				if spr.position.y < 50:
					spr.position = Vector2(randf_range(20, 730), 1280)
			5:
				spr.position.y += delta * (12.0 + float(i % 4) * 4.0)
				spr.position.x += sin(particle_elapsed * 0.3 + phase) * delta * 5.0
				if spr.position.y > 1280:
					spr.position = Vector2(randf_range(20, 730), 50)
			6:
				spr.position.y -= delta * (5.0 + float(i % 3) * 3.0)
				spr.position.x += sin(particle_elapsed * 0.7 + phase) * delta * 4.0
				if spr.position.y < 50:
					spr.position = Vector2(randf_range(20, 730), 1280)
			8:
				var angle := particle_elapsed * 1.5 + phase
				spr.position.x += cos(angle) * delta * 22.0
				spr.position.y += sin(angle) * delta * 16.0
				spr.position.x = clampf(spr.position.x, 10, 740)
				spr.position.y = clampf(spr.position.y, 50, 1280)
			9:
				spr.position.y -= delta * (4.0 + float(i % 5) * 2.0)
				spr.position.x += sin(particle_elapsed * 0.4 + phase) * delta * 6.0
				if spr.position.y < 50:
					spr.position = Vector2(randf_range(20, 730), 1280)
			_:
				spr.position.x += sin(particle_elapsed * 0.5 + phase) * delta * 8.0
				spr.position.y += cos(particle_elapsed * 0.3 + phase) * delta * 5.0
				spr.position.x = clampf(spr.position.x, 10, 740)
				spr.position.y = clampf(spr.position.y, 50, 1280)

var _potion_tooltip: PanelContainer
var _potion_dismiss: Control

func _dismiss_potion_tooltip():
	if _potion_tooltip and is_instance_valid(_potion_tooltip):
		var panel := _potion_tooltip
		var ftw := create_tween().set_parallel(true)
		ftw.tween_property(panel, "modulate:a", 0.0, 0.2)
		ftw.tween_property(panel, "scale", Vector2(0.8, 0.8), 0.2)
		ftw.chain().tween_callback(panel.queue_free)
	_potion_tooltip = null
	if _potion_dismiss and is_instance_valid(_potion_dismiss):
		_potion_dismiss.queue_free()
	_potion_dismiss = null

func _show_potion_tooltip(title_text: String, desc_text: String, color: Color, anchor_btn: Button):
	if _potion_tooltip and is_instance_valid(_potion_tooltip):
		_dismiss_potion_tooltip()
		return
	SoundManager.play("click")

	var panel := PanelContainer.new()
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.12, 0.07, 0.2, 0.95)
	style.border_color = Color(color.r * 0.7, color.g * 0.7, color.b * 0.7, 0.6)
	style.set_border_width_all(2)
	style.set_corner_radius_all(12)
	style.content_margin_left = 16
	style.content_margin_right = 16
	style.content_margin_top = 12
	style.content_margin_bottom = 12
	panel.add_theme_stylebox_override("panel", style)
	panel.mouse_filter = Control.MOUSE_FILTER_STOP

	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 6)
	panel.add_child(vbox)

	var title := Label.new()
	title.text = title_text
	title.add_theme_font_size_override("font_size", 22)
	title.add_theme_color_override("font_color", color)
	title.add_theme_color_override("font_outline_color", Color(0, 0, 0))
	title.add_theme_constant_override("outline_size", 3)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vbox.add_child(title)

	var sep := HSeparator.new()
	sep.add_theme_constant_override("separation", 4)
	vbox.add_child(sep)

	var desc := Label.new()
	desc.text = desc_text
	desc.add_theme_font_size_override("font_size", 15)
	desc.add_theme_color_override("font_color", Color(0.85, 0.8, 0.95))
	desc.autowrap_mode = TextServer.AUTOWRAP_WORD
	vbox.add_child(desc)

	panel.custom_minimum_size = Vector2(280, 0)
	panel.modulate = Color(1, 1, 1, 0)
	panel.scale = Vector2(0.8, 0.8)
	$HUD.add_child(panel)

	await get_tree().process_frame
	var btn_pos := anchor_btn.global_position
	panel.position = Vector2(
		clampf(btn_pos.x - panel.size.x / 2.0 + 10, 10, 460),
		btn_pos.y - panel.size.y - 16
	)
	panel.pivot_offset = Vector2(panel.size.x / 2.0, panel.size.y)

	var tw := create_tween().set_parallel(true)
	tw.tween_property(panel, "modulate:a", 1.0, 0.15)
	tw.tween_property(panel, "scale", Vector2(1.0, 1.0), 0.2).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_BACK)

	var dismiss := Control.new()
	dismiss.set_anchors_preset(Control.PRESET_FULL_RECT)
	dismiss.mouse_filter = Control.MOUSE_FILTER_STOP
	$HUD.add_child(dismiss)
	$HUD.move_child(dismiss, panel.get_index())
	dismiss.gui_input.connect(func(ev: InputEvent):
		if ev is InputEventMouseButton and ev.pressed:
			_dismiss_potion_tooltip()
	)

	_potion_tooltip = panel
	_potion_dismiss = dismiss

	await get_tree().create_timer(4.0).timeout
	_dismiss_potion_tooltip()

func _show_combo_text(mult: float):
	_show_combo_label("COMBO x%.1f!" % mult, Color(1, 0.65, 0.1))

func _spawn_key_effect(pos: Vector2):
	SoundManager.play("key")
	var key_color := Color(1, 0.85, 0.3)
	var base := pos + Vector2(0, -60)

	var glow := Sprite2D.new()
	glow.texture = _make_soft_circle(64)
	glow.position = base
	glow.scale = Vector2(0.5, 0.5)
	glow.modulate = Color(1, 0.8, 0.2, 0.7)
	glow.z_index = 10
	room_container.add_child(glow)
	var gtw := create_tween().set_parallel(true)
	gtw.tween_property(glow, "scale", Vector2(12, 12), 0.3).set_ease(Tween.EASE_OUT)
	gtw.tween_property(glow, "modulate:a", 0.0, 0.6)
	gtw.chain().tween_callback(glow.queue_free)

	var spr := Sprite2D.new()
	spr.texture = KeyTex
	spr.scale = Vector2(0.0, 0.0)
	spr.position = base
	spr.modulate = key_color
	spr.z_index = 12
	room_container.add_child(spr)
	var tw := create_tween()
	tw.tween_property(spr, "scale", Vector2(0.15, 0.15), 0.2).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_BACK)
	tw.tween_property(spr, "scale", Vector2(0.12, 0.12), 0.15)
	tw.tween_property(spr, "position:y", base.y - 120, 0.8).set_ease(Tween.EASE_OUT)
	tw.parallel().tween_property(spr, "rotation", TAU, 0.8)
	tw.parallel().tween_property(spr, "modulate:a", 0.0, 0.4).set_delay(0.5)
	tw.tween_callback(spr.queue_free)

	_show_key_label()

func _flash_red():
	var rect := ColorRect.new()
	rect.color = Color(0.8, 0.1, 0.05, 0.35)
	rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	rect.set_anchors_preset(Control.PRESET_FULL_RECT)
	$HUD.add_child(rect)
	var tw := create_tween()
	tw.tween_property(rect, "color:a", 0.0, 0.4)
	tw.tween_callback(rect.queue_free)

func _spawn_victory_shower():
	for i in 18:
		var coin := Sprite2D.new()
		var atlas := AtlasTexture.new()
		atlas.atlas = CoinTex
		atlas.region = Rect2(0, 0, 128, 128)
		coin.texture = atlas
		coin.scale = Vector2(randf_range(0.15, 0.28), randf_range(0.15, 0.28))
		coin.position = Vector2(randf_range(50, 700), randf_range(-100, -40))
		coin.z_index = 15
		$HUD.add_child(coin)
		var delay := randf_range(0.0, 0.5)
		var dur := randf_range(1.2, 2.5)
		var tw := create_tween().set_parallel(true)
		tw.tween_property(coin, "position:y", randf_range(800, 1400), dur).set_ease(Tween.EASE_IN).set_delay(delay)
		tw.tween_property(coin, "position:x", coin.position.x + randf_range(-40, 40), dur).set_delay(delay)
		tw.tween_property(coin, "rotation", randf_range(-PI * 2, PI * 2), dur).set_delay(delay)
		tw.tween_property(coin, "modulate:a", 0.0, 0.3).set_delay(delay + dur - 0.3)
		tw.chain().tween_callback(coin.queue_free)

func _spawn_coin_burst(pos: Vector2):
	for i in 6:
		var coin := Sprite2D.new()
		var atlas := AtlasTexture.new()
		atlas.atlas = CoinTex
		atlas.region = Rect2(0, 0, 128, 128)
		coin.texture = atlas
		coin.scale = Vector2(0.15, 0.15)
		coin.z_index = 8
		coin.position = pos + Vector2(0, -40)
		room_container.add_child(coin)
		var offset_x := randf_range(-80.0, 80.0)
		var offset_y := randf_range(-180.0, -80.0)
		var tw := create_tween().set_parallel(true)
		tw.tween_property(coin, "position", coin.position + Vector2(offset_x, offset_y), 0.6).set_ease(Tween.EASE_OUT)
		tw.tween_property(coin, "rotation", randf_range(-PI, PI), 0.6)
		tw.tween_property(coin, "modulate:a", 0.0, 0.4).set_delay(0.2)
		tw.chain().tween_callback(coin.queue_free)

func _spawn_potion_effect(pos: Vector2, color: Color):
	var flash := ColorRect.new()
	flash.color = Color(color.r, color.g, color.b, 0.3)
	flash.mouse_filter = Control.MOUSE_FILTER_IGNORE
	flash.set_anchors_preset(Control.PRESET_FULL_RECT)
	$HUD.add_child(flash)
	var ftw := create_tween()
	ftw.tween_property(flash, "color:a", 0.0, 0.6)
	ftw.tween_callback(flash.queue_free)
	var tex := _make_soft_circle()
	var ring := Sprite2D.new()
	ring.texture = tex
	ring.global_position = pos
	ring.scale = Vector2(2, 2)
	ring.modulate = Color(color.r, color.g, color.b, 0.7)
	ring.z_index = 20
	$HUD.add_child(ring)
	var rtw := create_tween().set_parallel(true)
	rtw.tween_property(ring, "scale", Vector2(24, 24), 0.5).set_ease(Tween.EASE_OUT)
	rtw.tween_property(ring, "modulate:a", 0.0, 0.5)
	rtw.chain().tween_callback(ring.queue_free)

func _spawn_landing_dust(pos: Vector2):
	var tex := _make_soft_circle(16)
	for i in 4:
		var spr := Sprite2D.new()
		spr.texture = tex
		spr.scale = Vector2(1.5, 1.0)
		spr.z_index = 6
		spr.modulate = Color(0.6, 0.5, 0.45, 0.5)
		spr.position = pos + Vector2(randf_range(-15, 15), randf_range(-5, 5))
		room_container.add_child(spr)
		var dir := -1.0 if i < 2 else 1.0
		var target_x := spr.position.x + dir * randf_range(20, 45)
		var target_y := spr.position.y - randf_range(15, 35)
		var tw := create_tween().set_parallel(true)
		tw.tween_property(spr, "position", Vector2(target_x, target_y), 0.4).set_ease(Tween.EASE_OUT)
		tw.tween_property(spr, "scale", Vector2(2.5, 1.5), 0.4)
		tw.tween_property(spr, "modulate:a", 0.0, 0.4)
		tw.chain().tween_callback(spr.queue_free)

func _combo_visual_feedback(combo_val: int):
	if combo_val >= 3:
		var flash := ColorRect.new()
		flash.color = Color(1.0, 0.85, 0.3, 0.05)
		flash.mouse_filter = Control.MOUSE_FILTER_IGNORE
		flash.set_anchors_preset(Control.PRESET_FULL_RECT)
		$HUD.add_child(flash)
		var ftw := create_tween()
		ftw.tween_property(flash, "color:a", 0.0, 0.3)
		ftw.tween_callback(flash.queue_free)
	if combo_val >= 5:
		_spawn_combo_sparkles()
	if combo_val >= 7:
		camera.shake(3.0)
		score_label.pivot_offset = score_label.size / 2
		var ptw := create_tween()
		ptw.tween_property(score_label, "scale", Vector2(1.4, 1.4), 0.1).set_ease(Tween.EASE_OUT)
		ptw.tween_property(score_label, "scale", Vector2(1.0, 1.0), 0.2).set_ease(Tween.EASE_IN)

func _spawn_combo_sparkles():
	var tex := _make_soft_circle()
	var score_pos := score_label.global_position + score_label.size / 2.0
	for i in 5:
		var spr := Sprite2D.new()
		spr.texture = tex
		spr.scale = Vector2(2.0, 2.0)
		spr.z_index = 20
		spr.modulate = Color(1.0, 0.85, 0.3, 0.9)
		spr.position = score_pos + Vector2(randf_range(-30, 30), randf_range(-20, 20))
		$HUD.add_child(spr)
		var angle := randf() * TAU
		var dist := randf_range(40, 80)
		var target := spr.position + Vector2(cos(angle) * dist, sin(angle) * dist)
		var tw := create_tween().set_parallel(true)
		tw.tween_property(spr, "position", target, 0.5).set_ease(Tween.EASE_OUT)
		tw.tween_property(spr, "scale", Vector2(0.3, 0.3), 0.5)
		tw.tween_property(spr, "modulate:a", 0.0, 0.4).set_delay(0.1)
		tw.chain().tween_callback(spr.queue_free)

func _on_mission_toast(_id: String, reward: int):
	_spawn_gold_text("MISSION +%d" % reward, Vector2(375, 400))
	SoundManager.play("coin")

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

func _make_soft_circle(sz: int = 32) -> ImageTexture:
	return GameManagerClass.make_soft_circle(sz)

var _tut_layer: CanvasLayer
var _tut_overlay: ColorRect
var _tut_highlight: Control
var _tut_label: Label
var _tut_finger: Sprite2D
var _tut_step := 0
var _tut_tweens: Array[Tween] = []

func _show_tutorial():
	input_locked = true
	await get_tree().create_timer(0.5).timeout

	_tut_layer = CanvasLayer.new()
	_tut_layer.layer = 70
	add_child(_tut_layer)

	_tut_overlay = ColorRect.new()
	_tut_overlay.color = Color(0, 0, 0, 0.65)
	_tut_overlay.set_anchors_preset(Control.PRESET_FULL_RECT)
	_tut_overlay.mouse_filter = Control.MOUSE_FILTER_STOP
	_tut_layer.add_child(_tut_overlay)

	_tut_highlight = Control.new()
	_tut_highlight.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_tut_layer.add_child(_tut_highlight)

	_tut_label = Label.new()
	_tut_label.add_theme_font_size_override("font_size", 26)
	_tut_label.add_theme_color_override("font_color", Color(0.95, 0.9, 1.0))
	_tut_label.add_theme_color_override("font_outline_color", Color(0, 0, 0))
	_tut_label.add_theme_constant_override("outline_size", 5)
	_tut_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_tut_label.autowrap_mode = TextServer.AUTOWRAP_WORD
	_tut_label.custom_minimum_size = Vector2(600, 0)
	_tut_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_tut_layer.add_child(_tut_label)

	_tut_finger = Sprite2D.new()
	_tut_finger.texture = ArrowTex
	_tut_finger.scale = Vector2(0.07, 0.07)
	_tut_finger.modulate = Color(1, 0.9, 0.3)
	_tut_layer.add_child(_tut_finger)

	var tap_hint := Label.new()
	tap_hint.name = "TapHint"
	tap_hint.text = "Tap to continue"
	tap_hint.add_theme_font_size_override("font_size", 18)
	tap_hint.add_theme_color_override("font_color", Color(1, 0.85, 0.3, 0.6))
	tap_hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	tap_hint.set_anchors_preset(Control.PRESET_BOTTOM_WIDE)
	tap_hint.offset_top = -60
	tap_hint.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_tut_layer.add_child(tap_hint)
	var blink_tw := create_tween().set_loops()
	blink_tw.tween_property(tap_hint, "modulate:a", 0.3, 0.8)
	blink_tw.tween_property(tap_hint, "modulate:a", 1.0, 0.8)
	_tut_tweens.append(blink_tw)

	_tut_step = 0
	_tut_show_step()
	_tut_overlay.gui_input.connect(_tut_on_tap)

func _tut_on_tap(event: InputEvent):
	if event is InputEventMouseButton and event.pressed:
		_tut_step += 1
		if _tut_step >= 4:
			_tut_finish()
		else:
			_tut_show_step()

func _tut_kill_step_tweens():
	for tw in _tut_tweens:
		if tw and tw.is_running():
			tw.kill()
	_tut_tweens.clear()

func _tut_show_step():
	_tut_kill_step_tweens()
	for child in _tut_highlight.get_children():
		child.queue_free()

	var vp_size := get_viewport().get_visible_rect().size
	match _tut_step:
		0:
			_tut_label.text = "Tap a door to open it!\nYour thief will walk over and reveal what's inside."
			_tut_label.position = Vector2(75, vp_size.y * 0.15)
			_tut_finger.visible = true
			_tut_finger.position = Vector2(375, vp_size.y * 0.45)
			_tut_animate_finger(_tut_finger.position)
			_tut_spawn_glow(Vector2(100, vp_size.y * 0.35), Vector2(550, 200))
		1:
			_tut_label.text = "Treasure = coins!\nBut beware... traps will end your run."
			_tut_label.position = Vector2(75, vp_size.y * 0.35)
			_tut_finger.visible = false
			var top_panel: Control = $HUD/HUDContainer/TopPanel
			_tut_spawn_glow(top_panel.global_position, top_panel.size)
		2:
			_tut_label.text = "Open an empty door? No worries!\nYou can still pick another door in the same room."
			_tut_label.position = Vector2(75, vp_size.y * 0.3)
			_tut_finger.visible = false
		3:
			_tut_label.text = "Look for clues on doors!\nScratches = danger, golden glow = treasure."
			_tut_label.position = Vector2(75, vp_size.y * 0.3)
			_tut_finger.visible = false

func _tut_spawn_glow(pos: Vector2, rect_size: Vector2):
	var glow := ColorRect.new()
	glow.color = Color(1, 0.85, 0.3, 0.12)
	glow.position = pos
	glow.size = rect_size
	glow.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_tut_highlight.add_child(glow)
	var glow_tw := create_tween().set_loops()
	glow_tw.tween_property(glow, "color:a", 0.25, 0.6)
	glow_tw.tween_property(glow, "color:a", 0.08, 0.6)
	_tut_tweens.append(glow_tw)

func _tut_animate_finger(base_pos: Vector2):
	_tut_finger.visible = true
	var ftw := create_tween().set_loops()
	ftw.tween_property(_tut_finger, "position:y", base_pos.y + 12, 0.4).set_ease(Tween.EASE_IN_OUT)
	ftw.tween_property(_tut_finger, "position:y", base_pos.y, 0.4).set_ease(Tween.EASE_IN_OUT)
	_tut_tweens.append(ftw)

func _tut_finish():
	_tut_kill_step_tweens()
	GameManager.tutorial_seen = true
	GameManager.save_data()
	var tw := create_tween()
	tw.tween_property(_tut_overlay, "color:a", 0.0, 0.3)
	tw.parallel().tween_property(_tut_label, "modulate:a", 0.0, 0.3)
	tw.parallel().tween_property(_tut_finger, "modulate:a", 0.0, 0.3)
	tw.parallel().tween_property(_tut_highlight, "modulate:a", 0.0, 0.3)
	tw.tween_callback(func():
		_tut_layer.queue_free()
		_tut_layer = null)
	input_locked = false

func _connect_debug():
	if not OS.is_debug_build():
		return
	DebugManager.traps_toggled.connect(_toggle_debug_traps)
	DebugManager.keys_toggled.connect(_toggle_debug_keys)
	DebugManager.npc_toggled.connect(_toggle_debug_npc)
	DebugManager.skip_requested.connect(_debug_skip_level)
	DebugManager.win_requested.connect(_debug_instant_win)
	DebugManager.god_mode_toggled.connect(func(v: bool): god_mode = v)
	DebugManager.force_event_requested.connect(_debug_force_event)
	DebugManager.set_combo_requested.connect(func(v: int): combo = v)
	DebugManager.force_npc_requested.connect(_debug_force_npc)
	if DebugManager.show_traps:
		_toggle_debug_traps(true)
	if DebugManager.show_keys:
		_toggle_debug_keys(true)
	if DebugManager.show_npc:
		_toggle_debug_npc(true)
	god_mode = DebugManager.god_mode

func _toggle_debug_traps(enabled: bool):
	debug_show_traps = enabled
	_refresh_debug_colors()

func _toggle_debug_keys(enabled: bool):
	debug_show_keys = enabled
	_refresh_debug_colors()

func _toggle_debug_npc(enabled: bool):
	debug_show_npc = enabled
	_refresh_debug_colors()

func _refresh_debug_colors():
	for room in rooms:
		for door in room.doors:
			if not door.revealed:
				if debug_show_traps:
					if door.is_safe():
						if debug_show_keys and door.has_key:
							door.visual.modulate = Color(1.0, 0.95, 0.0)
						else:
							door.visual.modulate = Color(0.2, 1.0, 0.2)
					elif door.is_empty():
						door.visual.modulate = Color(0.8, 0.8, 0.9)
					elif door.is_npc():
						door.visual.modulate = Color(0.75, 0.5, 1.0)
					else:
						door.visual.modulate = Color(1.0, 0.15, 0.15)
				elif debug_show_npc and door.is_npc():
					door.visual.modulate = Color(0.75, 0.5, 1.0)
				elif debug_show_npc and door.is_empty():
					door.visual.modulate = Color(0.8, 0.8, 0.9)
				elif debug_show_keys and door.has_key:
					door.visual.modulate = Color(1.0, 0.95, 0.0)
				else:
					door.visual.modulate = Color.WHITE

func _debug_force_event(ev: String):
	if input_locked or current_level_idx >= max_floors:
		return
	var room: Node2D = rooms[current_level_idx]
	current_event = ev
	match ev:
		"cursed":
			_show_event_label("CURSED FLOOR", Color(0.7, 0.2, 0.8))
			room.curse_doors()
			_event_cursed_effect()
		"double_loot":
			_show_event_label("DOUBLE LOOT", Color(1.0, 0.84, 0.0))
			room.shimmer_doors()
		"shaky_floor":
			_show_event_label("SHAKY FLOOR", Color(0.9, 0.4, 0.3))
			_start_shaky_timer()
		"blessing":
			_show_event_label("BLESSING", Color(0.3, 0.9, 0.6))
			room.apply_luck()
			_event_blessing_effect()

func _debug_force_npc():
	if input_locked or current_level_idx >= max_floors:
		return
	var room: Node2D = rooms[current_level_idx]
	for door in room.doors:
		if not door.revealed and not door.is_npc():
			door.tile_type = 5
			_refresh_debug_colors()
			return

func _debug_skip_level():
	if input_locked or current_level_idx >= max_floors:
		return
	var room: Node2D = rooms[current_level_idx]
	for door in room.doors:
		door.reveal()
	GameManager.complete_level()
	current_level_idx += 1
	_update_hud()
	_animate_score(GameManager.score)
	var prev_idx := clampi(current_level_idx - 1, 0, rooms.size() - 1)
	thief.position = Vector2(375, rooms[prev_idx].position.y)
	camera.follow(thief.position.y)
	if current_level_idx < max_floors:
		await _unlock_next_level()

func _debug_instant_win():
	if input_locked:
		return
	input_locked = true
	for i in range(current_level_idx, max_floors):
		GameManager.complete_level()
	current_level_idx = max_floors
	_update_hud()
	_animate_score(GameManager.score)
	_handle_victory()
