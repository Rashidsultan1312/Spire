extends Node2D

const TowerLevelScene := preload("res://scenes/components/tower_level.tscn")
const TreasureChestScene := preload("res://scenes/components/treasure_chest.tscn")
const CoinTex := preload("res://assets/sprites/v2/items/spinning_coin.png")
const KeyTex := preload("res://assets/sprites/ui/Icons/128px/key_icon_128px.png")
const StarFilled := preload("res://assets/sprites/ui/Icons/star_filled.png")
const StarEmpty := preload("res://assets/sprites/ui/Icons/star_empty.png")
const GnomeTex := preload("res://assets/sprites/v2/characters/gnome_cartoon.png")
const GnomeDialogScene := preload("res://scenes/components/gnome_dialog.tscn")
const ArrowTex := preload("res://assets/sprites/ui/Icons/arrow_down.png")
const COMBO_THRESHOLDS := {3: 1.5, 5: 2.0, 7: 2.5}

@onready var camera: Camera2D = $Camera
@onready var tower: Node2D = $Tower
@onready var thief: Node2D = $Thief
@onready var level_label: Label = $HUD/HUDContainer/TopPanel/TopBar/LevelVBox/LevelLabel
@onready var score_label: Label = $HUD/HUDContainer/TopPanel/TopBar/ScoreBox/ScoreLabel
@onready var cash_out_btn: Button = $HUD/HUDContainer/CashOutBtn
@onready var pause_btn: Button = $HUD/HUDContainer/TopPanel/TopBar/PauseBtn
@onready var pause_menu: CanvasLayer = $PauseMenu
@onready var game_over_overlay: CanvasLayer = $GameOverOverlay
@onready var hint_btn: TextureButton = $HUD/HUDContainer/ItemBar/Potions/HintSlot/VBox/HintBtn
@onready var shield_btn: TextureButton = $HUD/HUDContainer/ItemBar/Potions/ShieldSlot/VBox/ShieldBtn
@onready var luck_btn: TextureButton = $HUD/HUDContainer/ItemBar/Potions/LuckSlot/VBox/LuckBtn
@onready var hint_badge: Label = $HUD/HUDContainer/ItemBar/Potions/HintSlot/VBox/HintBtn/Badge
@onready var shield_badge: Label = $HUD/HUDContainer/ItemBar/Potions/ShieldSlot/VBox/ShieldBtn/Badge
@onready var luck_badge: Label = $HUD/HUDContainer/ItemBar/Potions/LuckSlot/VBox/LuckBtn/Badge
@onready var hint_info_btn: Button = $HUD/HUDContainer/ItemBar/Potions/HintSlot/VBox/InfoBtn
@onready var shield_info_btn: Button = $HUD/HUDContainer/ItemBar/Potions/ShieldSlot/VBox/InfoBtn
@onready var luck_info_btn: Button = $HUD/HUDContainer/ItemBar/Potions/LuckSlot/VBox/InfoBtn
@onready var timer_bar: ProgressBar = $HUD/HUDContainer/TimerBar
@onready var stars_box: HBoxContainer = $HUD/HUDContainer/TopPanel/TopBar/LevelVBox/StarsBox

@export_group("Tower Layout")
@export var level_spacing := 180.0
@export var base_y := 400.0
@export var platform_count := 6
@export var platform_step := 120

@export_group("Camera")
@export var trap_shake := 28.0
@export var shield_shake := 8.0

var levels: Array[Node2D] = []
var current_level_idx := 0
var input_locked := false
var chest: Node2D
var displayed_score := 0
var debug_show_traps := false
var debug_show_keys := false
var debug_show_npc := false
var god_mode := false
var shield_active := false
var current_event := ""
var shaky_timer: SceneTreeTimer
var shaky_tween: Tween

var combo := 0
var accumulated_bonus := 0
var level_particles: Array[Sprite2D] = []
var particle_elapsed := 0.0
var bg_sprites: Array[Sprite2D] = []
var keys_collected := 0
var max_floors := 10
var npc_appeared := false
var gnome_node: Node2D
var world_theme := {}

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
	for i in bg_sprites.size():
		var bg_spr: Sprite2D = bg_sprites[i]
		var sway := sin(_bg_elapsed * 0.3 + float(i) * 0.5) * 3.0
		bg_spr.position.x = sway

func _ready():
	world_theme = WorldThemes.get_theme(GameManager.current_world)
	max_floors = WorldThemes.max_floors(GameManager.current_world)
	SoundManager.play_world_music(GameManager.current_world)
	_apply_safe_area()
	_apply_world_theme()
	_build_tower()
	_spawn_level_atmosphere()
	_place_thief()
	_update_hud()
	_update_item_buttons()
	cash_out_btn.pressed.connect(_on_cash_out)
	cash_out_btn.visible = false
	pause_btn.pressed.connect(func(): pause_menu.open())
	hint_btn.pressed.connect(_on_hint)
	shield_btn.pressed.connect(_on_shield)
	luck_btn.pressed.connect(_on_luck)
	hint_info_btn.pressed.connect(func(): _show_potion_tooltip("INSIGHT", "Reveals one door on the current floor.\nYellow glow = safe, Red glow = trap.", Color(0.3, 0.5, 1.0), hint_info_btn))
	shield_info_btn.pressed.connect(func(): _show_potion_tooltip("SHIELD", "Protects you from one trap.\nYou survive but get 0 reward for that floor.", Color(0.3, 0.9, 0.4), shield_info_btn))
	luck_info_btn.pressed.connect(func(): _show_potion_tooltip("LUCK", "Replaces one random trap with a safe door\non the current floor.", Color(0.9, 0.3, 0.4), luck_info_btn))
	timer_bar.visible = false
	_connect_debug()
	if not GameManager.tutorial_seen:
		_show_tutorial()

func _apply_world_theme():
	var canvas_mod := get_node_or_null("CanvasModulate")
	if canvas_mod and world_theme.has("canvas_modulate"):
		canvas_mod.color = world_theme["canvas_modulate"]

	var bg_path: String = WorldThemes.WORLD_BG[clampi(GameManager.current_world, 0, 9)]
	var bg_tex: Texture2D = load(bg_path)
	if bg_tex:
		var castle_sprite: Sprite2D = $ParallaxBG/CastleLayer/Castle
		castle_sprite.visible = false
		var tex_size := bg_tex.get_size()
		var scale_x := 750.0 / tex_size.x
		var tile_h := tex_size.y * scale_x
		var top_y := -2200.0
		var bottom_y := 3600.0
		var y := top_y
		var castle_layer: Node = $ParallaxBG/CastleLayer
		while y < bottom_y:
			var spr := Sprite2D.new()
			spr.texture = bg_tex
			spr.centered = false
			spr.scale = Vector2(scale_x, scale_x)
			spr.position = Vector2(0, y)
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
	_build_spawn_platform()
	for i in range(max_floors):
		var lvl := TowerLevelScene.instantiate()
		lvl.position = Vector2(375, base_y - (i + 1) * level_spacing)
		tower.add_child(lvl)
		lvl.setup(i, world_theme)
		lvl.tile_chosen.connect(_on_tile_chosen)
		levels.append(lvl)

	_enforce_single_npc()
	for i in range(1, max_floors):
		levels[i].lock_all()

	chest = TreasureChestScene.instantiate()
	chest.position = Vector2(375, base_y - (max_floors + 1) * level_spacing)
	tower.add_child(chest)

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

func _enforce_single_npc():
	var found_npc := false
	for lvl in levels:
		for tile in lvl.tiles:
			if tile.is_npc():
				if found_npc:
					tile.tile_type = 0
				else:
					found_npc = true
	if not found_npc:
		_inject_npc()

func _inject_npc():
	var candidates: Array[Array] = []
	for lvl_idx in range(2, 8):
		var lvl: Node2D = levels[lvl_idx]
		for tile_idx in range(lvl.tiles.size()):
			var tile: Area2D = lvl.tiles[tile_idx]
			if tile.is_safe() and not tile.has_key:
				candidates.append([lvl_idx, tile_idx])
	if candidates.is_empty():
		return
	var pick: Array = candidates[randi() % candidates.size()]
	var picked_lvl: Node2D = levels[pick[0]]
	picked_lvl.tiles[pick[1]].tile_type = 5

const SpawnPlatTex := preload("res://assets/sprites/v2/tiles/castle-dungeon/Castle-Dungeon_Tiles/Individual_Tiles/E10.png")

func _build_spawn_platform():
	var plat := Node2D.new()
	plat.position = Vector2(375, base_y + 80)
	plat.z_index = -1
	for i in 6:
		var spr := Sprite2D.new()
		spr.texture = SpawnPlatTex
		spr.scale = Vector2(3, 3)
		spr.position = Vector2(-300 + i * 120, 0)
		plat.add_child(spr)
	tower.add_child(plat)

func _place_thief():
	thief.position = Vector2(375, base_y)
	camera.position = Vector2(375, thief.position.y - 50)
	camera.follow(thief.position.y)

func _on_tile_chosen(tile: Area2D, level_node: Node2D):
	if input_locked:
		return
	input_locked = true
	cash_out_btn.visible = false
	_stop_shaky_timer()
	level_node.stop_idle()
	SoundManager.play("door_open")

	if tile.is_safe():
		var reveal_tw: Tween = tile.reveal()
		if reveal_tw:
			await reveal_tw.finished
		await get_tree().create_timer(0.3).timeout
		await _on_safe(tile, level_node)
	elif tile.is_empty():
		var reveal_tw: Tween = tile.reveal()
		if reveal_tw:
			await reveal_tw.finished
		await get_tree().create_timer(0.2).timeout
		await _on_empty(tile, level_node)
	elif tile.is_npc():
		var reveal_tw: Tween = tile.reveal()
		if reveal_tw:
			await reveal_tw.finished
		await get_tree().create_timer(0.3).timeout
		await _on_npc_hint(tile, level_node)
	else:
		if shield_active or god_mode:
			var reveal_tw: Tween = tile.reveal()
			if reveal_tw:
				await reveal_tw.finished
			if shield_active:
				shield_active = false
				thief.set_shield(false)
			_update_item_buttons()
			SoundManager.play("shield_break")
			camera.shake(8.0)
			_spawn_gold_text("SHIELD!", tile.global_position)
			await get_tree().create_timer(0.5).timeout
			await _on_safe_no_reward(tile, level_node)
		else:
			tile.reveal_instant()
			await _play_trap_effect(tile)
			await _on_trap(tile)

func _on_safe(tile: Area2D, level_node: Node2D):
	combo += 1

	var combo_mult := 1.0
	for threshold in [7, 5, 3]:
		if combo >= threshold:
			combo_mult = COMBO_THRESHOLDS[threshold]
			break

	var base_reward := GameManager.reward(current_level_idx + 1)
	if current_event == "cursed":
		base_reward = 0
	elif current_event == "double_loot":
		base_reward *= 2
	var combo_bonus := int(float(base_reward) * (combo_mult - 1.0))
	accumulated_bonus += combo_bonus

	if tile.has_key:
		var key_bonus := int(15.0 * WorldThemes.WORLD_REWARD_MULT[clampi(GameManager.current_world, 0, 9)])
		accumulated_bonus += key_bonus
		keys_collected += 1

	GameManager.complete_level(accumulated_bonus)
	current_level_idx += 1

	var target_y := level_node.position.y
	SoundManager.play("jump")
	var jump_tw: Tween = thief.jump_to(Vector2(tile.global_position.x, target_y))
	await jump_tw.finished

	camera.follow(thief.position.y)
	var display_reward := base_reward + combo_bonus
	if tile.has_key:
		var key_bonus := int(15.0 * WorldThemes.WORLD_REWARD_MULT[clampi(GameManager.current_world, 0, 9)])
		display_reward += key_bonus
		_spawn_key_effect(tile.global_position)
		await get_tree().create_timer(0.7).timeout
	SoundManager.play("coin")
	_spawn_gold_text("+%d" % display_reward, tile.global_position)
	_spawn_coin_burst(tile.global_position)

	if COMBO_THRESHOLDS.has(combo):
		_show_combo_text(combo_mult)

	_animate_score(GameManager.score)
	_update_hud()
	levels[current_level_idx - 1].stop_shimmer()
	current_event = ""

	if current_level_idx >= max_floors:
		await get_tree().create_timer(0.3).timeout
		SoundManager.play("victory")
		var chest_tw: Tween = chest.open()
		if chest_tw:
			await chest_tw.finished
		await get_tree().create_timer(0.5).timeout
		_handle_victory()
		return

	_unlock_next_level()

func _on_safe_no_reward(tile: Area2D, level_node: Node2D):
	combo = 0
	GameManager.current_level += 1
	current_level_idx = GameManager.current_level

	var target_y := level_node.position.y
	SoundManager.play("jump")
	var jump_tw: Tween = thief.jump_to(Vector2(tile.global_position.x, target_y))
	await jump_tw.finished

	camera.follow(thief.position.y)
	_update_hud()
	if current_level_idx > 0:
		levels[current_level_idx - 1].stop_shimmer()
	current_event = ""

	if current_level_idx >= max_floors:
		_handle_victory()
		return

	_unlock_next_level()

func _on_empty(tile: Area2D, level_node: Node2D):
	GameManager.current_level += 1
	current_level_idx = GameManager.current_level

	var target_y := level_node.position.y
	SoundManager.play("jump")
	var jump_tw: Tween = thief.jump_to(Vector2(tile.global_position.x, target_y))
	await jump_tw.finished

	camera.follow(thief.position.y)
	_spawn_gold_text("Empty...", tile.global_position)
	_update_hud()
	if current_level_idx > 0:
		levels[current_level_idx - 1].stop_shimmer()
	current_event = ""

	if current_level_idx >= max_floors:
		_handle_victory()
		return

	_unlock_next_level()

func _on_npc_hint(tile: Area2D, level_node: Node2D):
	npc_appeared = true

	var hint_data: Array = NPC_HINTS[randi() % NPC_HINTS.size()]
	var hint_text: String = hint_data[0]
	var hint_type: String = hint_data[1]

	SoundManager.play("event")
	tile.visual.start_spritesheet_anim(4, 4, 2.5)

	var next_idx := current_level_idx + 1
	if next_idx < max_floors:
		var next_lvl: Node2D = levels[next_idx]
		match hint_type:
			"hint_trap":
				next_lvl.highlight_traps()
			"hint_safe":
				next_lvl.highlight_safe()
			"bonus_treasure":
				var bonus_tile: Area2D = null
				for t in next_lvl.tiles:
					if t.is_trap() and not t.revealed:
						t.tile_type = 0
						bonus_tile = t
						break
				if bonus_tile:
					next_lvl.highlight_tile(bonus_tile, Color(1.0, 0.85, 0.2))
			"show_trap_count":
				var trap_n := 0
				for t in next_lvl.tiles:
					if t.is_trap():
						trap_n += 1
				next_lvl.highlight_traps()
				_spawn_gold_text("%d traps!" % trap_n, tile.global_position + Vector2(0, -60))

	await _spawn_gnome(tile.global_position, hint_text)
	tile.visual.stop_spritesheet_anim()

	var hide_tw := create_tween()
	hide_tw.tween_property(tile.visual, "modulate:a", 0.0, 0.2)
	hide_tw.tween_callback(func(): tile.visual.visible = false)
	await hide_tw.finished

	GameManager.current_level += 1
	current_level_idx = GameManager.current_level

	var target_y := level_node.position.y
	SoundManager.play("jump")
	var jump_tw: Tween = thief.jump_to(Vector2(tile.global_position.x, target_y))
	await jump_tw.finished
	camera.follow(thief.position.y)

	await get_tree().create_timer(0.3).timeout
	_update_hud()
	if current_level_idx > 0:
		levels[current_level_idx - 1].stop_shimmer()
	current_event = ""

	if current_level_idx >= max_floors:
		_handle_victory()
		return

	_unlock_next_level()

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

	var slide_in := create_tween().set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_BACK)
	slide_in.tween_property(panel, "offset_left", 220.0, 0.4)
	slide_in.tween_property(panel, "offset_right", 720.0, 0.4)
	await slide_in.finished

	_typewriter_label(hint_label, hint_text)
	await get_tree().create_timer(maxf(2.5, float(hint_text.length()) * 0.07 + 1.5)).timeout

	var slide_out := create_tween().set_ease(Tween.EASE_IN).set_trans(Tween.TRANS_QUAD)
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

var _tut_layer: CanvasLayer
var _tut_overlay: ColorRect
var _tut_highlight: Control
var _tut_label: Label
var _tut_finger: Sprite2D
var _tut_step := 0
var _tut_tweens: Array[Tween] = []

func _show_tutorial():
	input_locked = true
	await get_tree().create_timer(0.3).timeout

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
	_tut_finger.scale = Vector2(1.2, 1.2)
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
			_tut_label.text = "Tap a door to open it!\nFind treasure behind them."
			_tut_label.position = Vector2(75, vp_size.y * 0.25)
			var lvl_node: Node2D = levels[0]
			var cam_offset := camera.get_screen_center_position() - vp_size / 2.0
			var lvl_screen_y := lvl_node.global_position.y - cam_offset.y
			var first_tile: Area2D = lvl_node.tiles[0]
			var last_tile: Area2D = lvl_node.tiles[lvl_node.tiles.size() - 1]
			var left_x := lvl_node.global_position.x + first_tile.position.x - cam_offset.x - 80
			var right_x := lvl_node.global_position.x + last_tile.position.x - cam_offset.x + 80
			var glow_y := lvl_screen_y - 70
			_tut_spawn_glow(Vector2(left_x, glow_y), Vector2(right_x - left_x, 140))
			var center_x := (left_x + right_x) / 2.0
			_tut_finger.position = Vector2(center_x, glow_y - 40)
			_tut_animate_finger(_tut_finger.position)
		1:
			_tut_label.text = "Treasure = coins!\nBut beware... traps will end your run."
			_tut_label.position = Vector2(75, vp_size.y * 0.35)
			_tut_finger.visible = false
			var top_panel: Control = $HUD/HUDContainer/TopPanel
			_tut_spawn_glow(top_panel.global_position, top_panel.size)
		2:
			_tut_label.text = "After each floor, LEAVE appears.\nCash out your coins before it's too late!"
			_tut_label.position = Vector2(75, vp_size.y * 0.3)
			cash_out_btn.visible = true
			cash_out_btn.text = "LEAVE"
			_tut_finger.visible = true
			var btn_pos := cash_out_btn.global_position
			var btn_size := cash_out_btn.size
			_tut_spawn_glow(Vector2(btn_pos.x - 10, btn_pos.y - 10), btn_size + Vector2(20, 20))
			var finger_pos := Vector2(btn_pos.x + btn_size.x / 2.0, btn_pos.y - 50)
			_tut_finger.position = finger_pos
			_tut_animate_finger(finger_pos)
		3:
			cash_out_btn.visible = false
			_tut_label.text = "Potions help you survive!\nTap ? for details."
			_tut_label.position = Vector2(75, vp_size.y * 0.35)
			_tut_finger.visible = true
			var item_bar: Control = $HUD/HUDContainer/ItemBar
			var bar_pos := item_bar.global_position
			var bar_size := item_bar.size
			_tut_spawn_glow(bar_pos, bar_size)
			var finger_pos := Vector2(bar_pos.x + bar_size.x / 2.0, bar_pos.y - 50)
			_tut_finger.position = finger_pos
			_tut_animate_finger(finger_pos)

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
	cash_out_btn.visible = false
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

func _handle_victory():
	await get_tree().create_timer(0.3).timeout
	SoundManager.play("victory")
	thief.victory_bounce()
	_spawn_victory_shower()
	var chest_tw: Tween = chest.open()
	if chest_tw:
		await chest_tw.finished
	await get_tree().create_timer(0.5).timeout
	var had_max := GameManager.has_max_stars()
	var old_unlocked := GameManager.worlds_unlocked
	GameManager.victory()
	var unlocked_name := ""
	if GameManager.worlds_unlocked > old_unlocked:
		unlocked_name = WorldThemes.WORLD_NAMES[old_unlocked]
	if had_max:
		game_over_overlay.show_victory_no_reward()
	else:
		game_over_overlay.show_victory(GameManager.score, GameManager.score, unlocked_name)

func _unlock_next_level():
	cash_out_btn.visible = true
	cash_out_btn.text = "LEAVE (%d/%d)" % [current_level_idx, max_floors]
	levels[current_level_idx].unlock_all()
	input_locked = false
	_update_item_buttons()
	level_label.pivot_offset = level_label.size / 2
	var ltw := create_tween()
	ltw.tween_property(level_label, "scale", Vector2(1.15, 1.15), 0.1).set_ease(Tween.EASE_OUT)
	ltw.tween_property(level_label, "scale", Vector2(1.0, 1.0), 0.15)
	var ztw := create_tween()
	ztw.tween_property(camera, "zoom", Vector2(1.015, 1.015), 0.1).set_ease(Tween.EASE_OUT)
	ztw.tween_property(camera, "zoom", Vector2(1.0, 1.0), 0.15).set_ease(Tween.EASE_IN_OUT)
	_roll_event(current_level_idx)

func _on_trap(_tile: Area2D):
	combo = 0
	camera.shake(28.0)
	_flash_red()
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
	GameManager.cash_out()
	if had_max:
		game_over_overlay.show_cash_out_no_reward()
	else:
		game_over_overlay.show_cash_out(GameManager.score, earned)

func _on_hint():
	if input_locked or current_level_idx >= max_floors:
		return
	if not GameManager.use_item("hint"):
		SoundManager.play("error")
		return
	SoundManager.play("potion")
	_spawn_potion_effect(hint_btn.global_position + Vector2(30, 30), Color(0.3, 0.5, 1.0))
	var lvl: Node2D = levels[current_level_idx]
	var idx: int = lvl.get_random_unrevealed_idx()
	if idx >= 0:
		lvl.show_hint(idx)
	_update_item_buttons()

func _on_shield():
	if input_locked or current_level_idx >= max_floors:
		return
	if shield_active:
		SoundManager.play("error")
		return
	if not GameManager.use_item("shield"):
		SoundManager.play("error")
		return
	SoundManager.play("potion")
	_spawn_potion_effect(shield_btn.global_position + Vector2(30, 30), Color(0.3, 0.9, 0.4))
	shield_active = true
	thief.set_shield(true)
	_update_item_buttons()

func _on_luck():
	if input_locked or current_level_idx >= max_floors:
		return
	if not GameManager.use_item("luck"):
		SoundManager.play("error")
		return
	SoundManager.play("potion")
	_spawn_potion_effect(luck_btn.global_position + Vector2(30, 30), Color(0.9, 0.3, 0.4))
	levels[current_level_idx].apply_luck()
	_update_item_buttons()

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

func _update_item_buttons():
	var hint_count: int = GameManager.items["hint"]
	var shield_count: int = GameManager.items["shield"]
	var luck_count: int = GameManager.items["luck"]
	hint_badge.text = str(hint_count)
	shield_badge.text = str(shield_count)
	luck_badge.text = str(luck_count)
	hint_btn.modulate = Color.WHITE if hint_count > 0 else Color(0.4, 0.4, 0.4)
	shield_btn.modulate = Color.WHITE if (shield_count > 0 and not shield_active) else Color(0.4, 0.4, 0.4)
	if shield_active:
		shield_btn.modulate = Color(0.5, 1.0, 0.5)
	luck_btn.modulate = Color.WHITE if luck_count > 0 else Color(0.4, 0.4, 0.4)

func _roll_event(level_idx: int):
	current_event = ""
	if level_idx < 2 or level_idx >= max_floors - 1:
		return
	if randf() > 0.3:
		return
	var events := ["cursed", "double_loot", "shaky_floor", "blessing"]
	var ev: String = events[randi() % events.size()]
	current_event = ev
	match ev:
		"cursed":
			_show_event_label("CURSED FLOOR", Color(0.7, 0.2, 0.8))
			levels[level_idx].curse_tiles()
		"double_loot":
			_show_event_label("DOUBLE LOOT", Color(1.0, 0.84, 0.0))
			levels[level_idx].shimmer_tiles()
		"shaky_floor":
			_show_event_label("SHAKY FLOOR", Color(0.9, 0.4, 0.3))
			_start_shaky_timer()
		"blessing":
			_show_event_label("BLESSING", Color(0.3, 0.9, 0.6))
			levels[level_idx].apply_luck()

var _active_banners: Array[Dictionary] = []

func _show_event_label(text: String, color: Color, sfx := "event"):
	_spawn_banner(text, color, sfx, 2.0)

func _show_combo_label(text: String, color: Color):
	_spawn_banner(text, color, "combo", 1.8)

func _show_key_label():
	_spawn_banner("+KEY", Color(1, 0.85, 0.3), "key", 1.5)

func _clear_banners():
	for b in _active_banners:
		if is_instance_valid(b["panel"]):
			if b["tween"] and b["tween"].is_running():
				b["tween"].kill()
			var p: PanelContainer = b["panel"]
			var tw := create_tween()
			tw.tween_property(p, "modulate:a", 0.0, 0.15)
			tw.tween_callback(p.queue_free)
	_active_banners.clear()

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
	var lvl: Node2D = levels[current_level_idx]
	var idx: int = lvl.get_random_unrevealed_idx()
	if idx >= 0:
		var tile: Area2D = lvl.tiles[idx]
		lvl._on_tile_tapped(tile)

func _play_trap_effect(tile: Area2D) -> void:
	SoundManager.play("tile_trap")
	var orig_pos: Vector2 = tile.position
	var orig_scale: Vector2 = tile.visual.scale
	_slowmo_hit()
	var tw := create_tween()
	match tile.tile_type:
		tile.TileType.TRAP_SPIKES:
			_play_spikes_effect(tile, tw, orig_pos, orig_scale)
		tile.TileType.TRAP_ROCK:
			_play_rock_effect(tile, tw, orig_pos, orig_scale)
		tile.TileType.TRAP_GUARD:
			_play_wraith_effect(tile, tw, orig_pos, orig_scale)
	await tw.finished

func _play_spikes_effect(tile: Area2D, tw: Tween, _orig_pos: Vector2, orig_scale: Vector2):
	tile.visual.scale = Vector2(orig_scale.x, 0.0)
	tile.visual.modulate = Color(1, 0.6, 0.3)
	tw.tween_property(tile.visual, "scale:y", orig_scale.y * 1.15, 0.15).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_BACK)
	tw.tween_property(tile.visual, "scale:y", orig_scale.y, 0.08)
	tw.tween_callback(func():
		camera.shake(15.0)
		_spawn_trap_particles(tile.global_position, Color(1, 0.3, 0.2), 8)
		_spawn_impact_ring(tile.global_position, Color(1, 0.35, 0.15))
		_spawn_dust_cloud(tile.global_position + Vector2(0, 30)))
	tw.parallel().tween_property(tile.visual, "modulate", Color.WHITE, 0.3)

func _play_rock_effect(tile: Area2D, tw: Tween, orig_pos: Vector2, _orig_scale: Vector2):
	tile.visible = false
	tile.position.y = orig_pos.y - 200.0
	var shadow := Sprite2D.new()
	shadow.texture = _make_soft_circle()
	shadow.position = Vector2(orig_pos.x, orig_pos.y + 20)
	shadow.scale = Vector2(3, 1.5)
	shadow.modulate = Color(0, 0, 0, 0.0)
	shadow.z_index = 5
	tile.get_parent().add_child(shadow)
	var stw := create_tween().set_parallel(true)
	stw.tween_property(shadow, "scale", Vector2(10, 5), 0.25)
	stw.tween_property(shadow, "modulate:a", 0.3, 0.25)
	tw.tween_callback(func(): tile.visible = true)
	tw.tween_property(tile, "position:y", orig_pos.y + 8.0, 0.25).set_ease(Tween.EASE_IN).set_trans(Tween.TRANS_QUAD)
	tw.tween_property(tile, "position:y", orig_pos.y, 0.06)
	tw.tween_callback(func():
		camera.shake(22.0)
		_spawn_trap_particles(tile.global_position, Color(0.6, 0.5, 0.4), 5)
		_spawn_impact_ring(tile.global_position, Color(0.7, 0.55, 0.35))
		_spawn_crack_lines(tile.global_position)
		var ftw := create_tween()
		ftw.tween_property(shadow, "modulate:a", 0.0, 0.3)
		ftw.tween_callback(shadow.queue_free))

func _play_wraith_effect(tile: Area2D, tw: Tween, orig_pos: Vector2, orig_scale: Vector2):
	tile.visual.modulate = Color(0.7, 0.3, 1.0)
	tile.visual.scale = orig_scale * 0.0
	_spawn_dark_cloud(tile.global_position)
	_spawn_wraith_vortex(tile.global_position)
	tw.tween_property(tile.visual, "scale", orig_scale * 1.15, 0.25).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_BACK)
	tw.tween_property(tile.visual, "scale", orig_scale, 0.1)
	tw.tween_callback(func(): camera.shake(18.0))
	tw.tween_property(tile, "position:x", orig_pos.x + 8.0, 0.04)
	tw.tween_property(tile, "position:x", orig_pos.x - 8.0, 0.04)
	tw.tween_property(tile, "position:x", orig_pos.x, 0.04)
	tw.parallel().tween_property(tile.visual, "modulate", Color.WHITE, 0.4)
	tw.tween_callback(func(): _wraith_pulse(tile.visual, orig_scale))

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
		spr.position = pos + Vector2(0, -80)
		tower.add_child(spr)
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
	spr.position = pos + Vector2(0, -80)
	spr.scale = Vector2(2, 2)
	spr.modulate = Color(color.r, color.g, color.b, 0.7)
	spr.z_index = 8
	tower.add_child(spr)
	var tw := create_tween().set_parallel(true)
	tw.tween_property(spr, "scale", Vector2(18, 18), 0.4).set_ease(Tween.EASE_OUT)
	tw.tween_property(spr, "modulate:a", 0.0, 0.4)
	tw.chain().tween_callback(spr.queue_free)

func _spawn_dust_cloud(pos: Vector2):
	var tex := _make_soft_circle()
	for i in 3:
		var spr := Sprite2D.new()
		spr.texture = tex
		spr.scale = Vector2(randf_range(4, 7), randf_range(3, 5))
		spr.position = pos + Vector2(randf_range(-40, 40), randf_range(-10, 10)) - Vector2(0, 80)
		spr.modulate = Color(0.7, 0.6, 0.5, 0.4)
		spr.z_index = 8
		tower.add_child(spr)
		var dtw := create_tween().set_parallel(true)
		dtw.tween_property(spr, "position:y", spr.position.y - randf_range(20, 50), 0.6)
		dtw.tween_property(spr, "scale", spr.scale * 1.5, 0.6)
		dtw.tween_property(spr, "modulate:a", 0.0, 0.5)
		dtw.chain().tween_callback(spr.queue_free)

func _spawn_crack_lines(pos: Vector2):
	var base := pos - Vector2(0, 80)
	for i in 3:
		var line := Line2D.new()
		line.width = 2.0
		line.default_color = Color(0.3, 0.2, 0.15, 0.8)
		line.z_index = 9
		var angle := randf() * TAU
		var point := base
		line.add_point(Vector2.ZERO)
		for j in randi_range(2, 4):
			point += Vector2(cos(angle) * randf_range(8, 18), sin(angle) * randf_range(8, 18))
			angle += randf_range(-0.5, 0.5)
			line.add_point(point - base)
		line.position = base
		tower.add_child(line)
		var ltw := create_tween()
		ltw.tween_interval(0.4)
		ltw.tween_property(line, "modulate:a", 0.0, 0.5)
		ltw.tween_callback(line.queue_free)

func _spawn_dark_cloud(pos: Vector2):
	var tex := _make_soft_circle()
	var base := pos - Vector2(0, 80)
	for i in 4:
		var spr := Sprite2D.new()
		spr.texture = tex
		spr.scale = Vector2(randf_range(6, 10), randf_range(5, 8))
		spr.position = base + Vector2(randf_range(-30, 30), randf_range(-20, 20))
		spr.modulate = Color(0.2, 0.1, 0.3, 0.5)
		spr.z_index = 8
		tower.add_child(spr)
		var dtw := create_tween().set_parallel(true)
		dtw.tween_property(spr, "scale", spr.scale * 2.0, 0.6).set_ease(Tween.EASE_OUT)
		dtw.tween_property(spr, "modulate:a", 0.0, 0.6)
		dtw.chain().tween_callback(spr.queue_free)

func _spawn_wraith_vortex(pos: Vector2):
	var tex := _make_soft_circle()
	var base := pos - Vector2(0, 80)
	for i in 10:
		var spr := Sprite2D.new()
		spr.texture = tex
		spr.scale = Vector2(2, 2)
		spr.z_index = 9
		spr.modulate = Color(0.6, 0.2, 1.0, 0.8)
		var angle := float(i) / 10.0 * TAU
		var radius := 20.0
		spr.position = base + Vector2(cos(angle) * radius, sin(angle) * radius)
		tower.add_child(spr)
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
	container.position = pos + Vector2(0, -120)
	tower.add_child(container)

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
	coin_atlas.region = Rect2(0, 0, 40, 44)
	coin.texture = coin_atlas
	coin.scale = Vector2(0.9, 0.9)
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
	for lvl in levels:
		for tile in lvl.tiles:
			if not tile.revealed:
				if debug_show_traps:
					if tile.is_safe():
						if debug_show_keys and tile.has_key:
							tile.visual.modulate = Color(1.0, 0.95, 0.0)
						else:
							tile.visual.modulate = Color(0.2, 1.0, 0.2)
					elif tile.is_empty():
						tile.visual.modulate = Color(0.8, 0.8, 0.9)
					elif tile.is_npc():
						tile.visual.modulate = Color(0.75, 0.5, 1.0)
					else:
						tile.visual.modulate = Color(1.0, 0.15, 0.15)
				elif debug_show_npc and tile.is_npc():
					tile.visual.modulate = Color(0.75, 0.5, 1.0)
				elif debug_show_npc and tile.is_empty():
					tile.visual.modulate = Color(0.8, 0.8, 0.9)
				elif debug_show_keys and tile.has_key:
					tile.visual.modulate = Color(1.0, 0.95, 0.0)
				else:
					tile.visual.modulate = Color.WHITE

func _debug_force_event(ev: String):
	if input_locked or current_level_idx >= max_floors:
		return
	current_event = ev
	match ev:
		"cursed":
			_show_event_label("CURSED FLOOR", Color(0.7, 0.2, 0.8))
			levels[current_level_idx].curse_tiles()
		"double_loot":
			_show_event_label("DOUBLE LOOT", Color(1.0, 0.84, 0.0))
			levels[current_level_idx].shimmer_tiles()
		"shaky_floor":
			_show_event_label("SHAKY FLOOR", Color(0.9, 0.4, 0.3))
			_start_shaky_timer()
		"blessing":
			_show_event_label("BLESSING", Color(0.3, 0.9, 0.6))
			levels[current_level_idx].apply_luck()

func _get_debug_info() -> Dictionary:
	var info := {
		"combo": combo,
		"keys": keys_collected,
		"bonus": accumulated_bonus,
		"event": current_event,
	}
	info["npc_appeared"] = npc_appeared
	if current_level_idx < max_floors:
		var lvl: Node2D = levels[current_level_idx]
		info["tile_count"] = lvl.tile_count
		var safe_count := 0
		var trap_count := 0
		var key_count := 0
		var empty_count := 0
		var npc_count := 0
		for t in lvl.tiles:
			if t.is_safe():
				safe_count += 1
			elif t.is_empty():
				empty_count += 1
			elif t.is_npc():
				npc_count += 1
			else:
				trap_count += 1
			if t.has_key:
				key_count += 1
		info["safe_count"] = safe_count
		info["trap_count"] = trap_count
		info["key_count"] = key_count
		info["empty_count"] = empty_count
		info["npc_count"] = npc_count
	else:
		info["tile_count"] = 0
		info["safe_count"] = 0
		info["trap_count"] = 0
		info["key_count"] = 0
	return info

func _debug_force_npc():
	if input_locked or current_level_idx >= max_floors:
		return
	var lvl: Node2D = levels[current_level_idx]
	for tile in lvl.tiles:
		if not tile.revealed and not tile.is_npc():
			tile.tile_type = 5
			_refresh_debug_colors()
			return

func _debug_skip_level():
	if input_locked or current_level_idx >= max_floors:
		return
	var skipped: Node2D = levels[current_level_idx]
	for tile in skipped.tiles:
		tile.reveal()
	GameManager.complete_level()
	current_level_idx += 1
	_update_hud()
	_animate_score(GameManager.score)
	var prev_idx := clampi(current_level_idx - 1, 0, levels.size() - 1)
	var target_y: float = levels[prev_idx].position.y
	thief.position = Vector2(375, target_y)
	camera.follow(thief.position.y)
	if current_level_idx < max_floors and current_level_idx < levels.size():
		levels[current_level_idx].unlock_all()

func _debug_instant_win():
	if input_locked:
		return
	input_locked = true
	for i in range(current_level_idx, max_floors):
		GameManager.complete_level()
	current_level_idx = max_floors
	_update_hud()
	_animate_score(GameManager.score)
	var target_y: float = levels[max_floors - 1].position.y
	thief.position = Vector2(375, target_y)
	camera.follow(thief.position.y)
	_handle_victory()

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

func _spawn_coin_burst(pos: Vector2):
	for i in 6:
		var coin := Sprite2D.new()
		var atlas := AtlasTexture.new()
		atlas.atlas = CoinTex
		atlas.region = Rect2(0, 0, 40, 44)
		coin.texture = atlas
		coin.scale = Vector2(0.4, 0.4)
		coin.z_index = 8
		coin.position = pos + Vector2(0, -80)
		tower.add_child(coin)
		var offset_x := randf_range(-80.0, 80.0)
		var offset_y := randf_range(-180.0, -80.0)
		var tw := create_tween().set_parallel(true)
		tw.tween_property(coin, "position", coin.position + Vector2(offset_x, offset_y), 0.6).set_ease(Tween.EASE_OUT)
		tw.tween_property(coin, "rotation", randf_range(-PI, PI), 0.6)
		tw.tween_property(coin, "modulate:a", 0.0, 0.4).set_delay(0.2)
		tw.chain().tween_callback(coin.queue_free)

func _show_combo_text(mult: float):
	_show_combo_label("COMBO x%.1f!" % mult, Color(1, 0.65, 0.1))

func _spawn_key_effect(pos: Vector2):
	SoundManager.play("key")
	var key_color := Color(1, 0.85, 0.3)
	var base := pos + Vector2(0, -100)

	var glow := Sprite2D.new()
	glow.texture = _make_soft_circle(64)
	glow.position = base
	glow.scale = Vector2(0.5, 0.5)
	glow.modulate = Color(1, 0.8, 0.2, 0.7)
	glow.z_index = 10
	tower.add_child(glow)
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
	tower.add_child(spr)
	var tw := create_tween()
	tw.tween_property(spr, "scale", Vector2(0.9, 0.9), 0.2).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_BACK)
	tw.tween_property(spr, "scale", Vector2(0.7, 0.7), 0.15)
	tw.tween_property(spr, "position:y", base.y - 120, 0.8).set_ease(Tween.EASE_OUT)
	tw.parallel().tween_property(spr, "rotation", TAU, 0.8)
	tw.parallel().tween_property(spr, "modulate:a", 0.0, 0.4).set_delay(0.5)
	tw.tween_callback(spr.queue_free)

	var tex := _make_soft_circle()
	for i in 8:
		var particle := Sprite2D.new()
		particle.texture = tex
		particle.scale = Vector2(2.5, 2.5)
		particle.z_index = 11
		particle.modulate = Color(key_color.r, key_color.g, key_color.b, 0.8)
		particle.position = base
		tower.add_child(particle)
		var angle := float(i) / 8.0 * TAU
		var dist := randf_range(50, 110)
		var target := base + Vector2(cos(angle) * dist, sin(angle) * dist)
		var ptw := create_tween().set_parallel(true)
		ptw.tween_property(particle, "position", target, 0.5).set_ease(Tween.EASE_OUT)
		ptw.tween_property(particle, "scale", Vector2(0.3, 0.3), 0.5)
		ptw.tween_property(particle, "modulate:a", 0.0, 0.4).set_delay(0.1)
		ptw.chain().tween_callback(particle.queue_free)

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
		atlas.region = Rect2(0, 0, 40, 44)
		coin.texture = atlas
		coin.scale = Vector2(randf_range(0.5, 0.9), randf_range(0.5, 0.9))
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
	var ring2 := Sprite2D.new()
	ring2.texture = tex
	ring2.global_position = pos
	ring2.scale = Vector2(1, 1)
	ring2.modulate = Color(1, 1, 1, 0.5)
	ring2.z_index = 21
	$HUD.add_child(ring2)
	var r2tw := create_tween().set_parallel(true)
	r2tw.tween_property(ring2, "scale", Vector2(16, 16), 0.35).set_ease(Tween.EASE_OUT).set_delay(0.1)
	r2tw.tween_property(ring2, "modulate:a", 0.0, 0.35).set_delay(0.1)
	r2tw.chain().tween_callback(ring2.queue_free)
	for i in 16:
		var spr := Sprite2D.new()
		spr.texture = tex
		spr.scale = Vector2(randf_range(2.0, 4.0), randf_range(2.0, 4.0))
		spr.z_index = 20
		spr.modulate = Color(color.r, color.g, color.b, 0.9)
		spr.global_position = pos
		$HUD.add_child(spr)
		var angle := randf() * TAU
		var dist := randf_range(80, 220)
		var target := pos + Vector2(cos(angle) * dist, sin(angle) * dist)
		var tw := create_tween().set_parallel(true)
		tw.tween_property(spr, "global_position", target, 0.7).set_ease(Tween.EASE_OUT)
		tw.tween_property(spr, "scale", Vector2(0.2, 0.2), 0.7)
		tw.tween_property(spr, "modulate:a", 0.0, 0.5).set_delay(0.15)
		tw.chain().tween_callback(spr.queue_free)
