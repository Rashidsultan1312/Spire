extends Node2D

signal tile_chosen(tile: Area2D, level_node: Node2D)

@export_group("Wall Glow")
@export var glow_color := Color(1.0, 0.6, 0.25, 0.18)
@export var glow_scale := Vector2(18, 14)
@export var glow_alpha_min := 0.1
@export var glow_alpha_max := 0.22
@export var glow_speed := 1.5
@export var glow_offset_x := 350
@export var glow_offset_y := -20

@export_group("Wall Decor")
@export var decor_modulate := Color(0.55, 0.45, 0.65, 0.8)
@export var decor_offset_x := 340
@export var decor_scale := 2.5
@export var curse_color := Color(0.6, 0.3, 0.8)

var level_index := 0
var tiles: Array[Area2D] = []
var shimmer_tweens: Array[Tween] = []
var idle_tweens: Array[Tween] = []
var tile_count := 3
var world_theme := {}

const TileScene := preload("res://scenes/components/tile.tscn")
const PlatTex := preload("res://assets/sprites/v2/tiles/wood_plank.png")
const WallTex1 := preload("res://assets/sprites/v2/tiles/castle-dungeon/Castle-Dungeon_Tiles/Individual_Tiles/E1.png")
const WallTex2 := preload("res://assets/sprites/v2/tiles/castle-dungeon/Castle-Dungeon_Tiles/Individual_Tiles/D1.png")
const TILE_BASE := "res://assets/sprites/v2/tiles/castle-dungeon/Castle-Dungeon_Tiles/Individual_Tiles/"
const DECOR_SHIELD := TILE_BASE + "Y10.png"
const DECOR_SWORDS := TILE_BASE + "X13.png"
const DECOR_PAINTING := TILE_BASE + "Y8.png"
const DECOR_AXES := TILE_BASE + "B13.png"

const TILE_SPREAD := {3: 400.0, 4: 510.0}

func _exit_tree():
	stop_idle()
	stop_shimmer()

func setup(level_idx: int, theme: Dictionary = {}):
	level_index = level_idx
	world_theme = theme

	if theme.has("glow_color"):
		glow_color = theme["glow_color"]
	if theme.has("wall_modulate"):
		decor_modulate = theme["wall_modulate"]

	randomize()

	tile_count = 3 if randi() % 100 < 60 else 4
	_spawn_tiles(tile_count)
	_spawn_platforms()

	var safe_n := GameManager.safe_count(level_idx + 1, tile_count)
	var trap_n := tile_count - safe_n

	var types: Array[int] = []

	var empty_count := 0
	var npc_count := 0

	if randi() % 100 < 18:
		empty_count = 1
	if level_idx >= 2 and level_idx <= 7 and randi() % 100 < 25:
		npc_count = 1

	if empty_count + npc_count >= safe_n:
		if npc_count > 0:
			empty_count = 0
		if npc_count >= safe_n:
			npc_count = 0
	var treasure_n := maxi(1, safe_n - empty_count - npc_count)
	for i in treasure_n:
		types.append(0)
	for i in empty_count:
		types.append(4)
	for i in npc_count:
		types.append(5)

	var trap_types := [1, 2, 3]
	for i in range(trap_n):
		types.append(trap_types[randi() % trap_types.size()])

	types.shuffle()

	for i in range(mini(types.size(), tiles.size())):
		tiles[i].tile_type = types[i]

	for i in range(tiles.size()):
		if tiles[i].tile_type == 0:
			if randi() % 100 < 20:
				tiles[i].has_key = true

	_apply_tile_theme()
	_spawn_decor()
	_start_idle_bob()

func _apply_tile_theme():
	if world_theme.is_empty():
		return
	for tile in tiles:
		tile.visual.apply_theme(world_theme)

func _spawn_tiles(n: int):
	var spread: float = TILE_SPREAD[n]
	var half := spread / 2.0
	for i in range(n):
		var tile: Area2D = TileScene.instantiate()
		var x: float
		if n == 1:
			x = 0.0
		else:
			x = -half + float(i) * (spread / float(n - 1))
		tile.position = Vector2(x, 0)
		add_child(tile)
		tiles.append(tile)
		tile.tile_tapped.connect(_on_tile_tapped)

func _spawn_platforms():
	var plat_node := $PlatformVisual
	var stone := Sprite2D.new()
	stone.texture = WallTex1
	stone.texture_repeat = CanvasItem.TEXTURE_REPEAT_ENABLED
	stone.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	stone.region_enabled = true
	stone.region_rect = Rect2(0, 0, 250, 64)
	stone.scale = Vector2(3.0, 3.0)
	stone.z_index = -1
	plat_node.add_child(stone)
	var wood := Sprite2D.new()
	wood.texture = PlatTex
	wood.texture_repeat = CanvasItem.TEXTURE_REPEAT_ENABLED
	wood.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	wood.region_enabled = true
	wood.region_rect = Rect2(0, 0, 250, 14)
	wood.scale = Vector2(3.0, 3.0)
	plat_node.add_child(wood)

func _start_idle_bob():
	for i in range(tiles.size()):
		var tile: Area2D = tiles[i]
		var base_y := tile.position.y
		var delay := float(i) * 0.4
		var tw := create_tween().set_loops()
		tw.tween_property(tile, "position:y", base_y - 6.0, 1.2).set_ease(Tween.EASE_IN_OUT).set_trans(Tween.TRANS_SINE).set_delay(delay)
		tw.tween_property(tile, "position:y", base_y + 2.0, 1.2).set_ease(Tween.EASE_IN_OUT).set_trans(Tween.TRANS_SINE)
		idle_tweens.append(tw)
		_spawn_chest_glow(tile)

func _spawn_chest_glow(tile: Area2D):
	var glow := Sprite2D.new()
	glow.texture = _make_soft_circle(48)
	glow.position = Vector2(0, 50)
	glow.scale = Vector2(4.5, 2.0)
	glow.modulate = Color(0.9, 0.65, 0.3, 0.12)
	glow.z_index = -1
	tile.add_child(glow)

func stop_idle():
	for tw in idle_tweens:
		if tw and tw.is_running():
			tw.kill()
	idle_tweens.clear()

func lock_all():
	for tile in tiles:
		tile.lock()

func unlock_all():
	for tile in tiles:
		tile.unlock()

func show_hint(tile_idx: int):
	if tile_idx < 0 or tile_idx >= tiles.size():
		return
	var tile: Area2D = tiles[tile_idx]
	if tile.revealed:
		return
	var color := Color(1.0, 0.85, 0.2) if tile.is_positive() else Color(1.0, 0.3, 0.3)
	tile.visual.modulate = color
	var tw := create_tween()
	tw.tween_property(tile.visual, "modulate", color, 0.15)
	tw.tween_property(tile.visual, "modulate", Color.WHITE, 0.8).set_delay(1.5)
	_spawn_glow_ring(tile.global_position, color)

func _hint_glow(tile: Area2D, color: Color):
	var glow := Sprite2D.new()
	glow.texture = _make_soft_circle(64)
	glow.position = Vector2(0, 0)
	glow.scale = Vector2(6, 6)
	glow.modulate = Color(color.r, color.g, color.b, 0.0)
	glow.z_index = -1
	tile.add_child(glow)
	var appear := create_tween()
	appear.tween_property(glow, "modulate:a", 0.35, 0.4).set_ease(Tween.EASE_OUT)
	var pulse := create_tween().set_loops()
	pulse.tween_property(glow, "scale", Vector2(7, 7), 0.8).set_ease(Tween.EASE_IN_OUT).set_trans(Tween.TRANS_SINE)
	pulse.tween_property(glow, "scale", Vector2(5, 5), 0.8).set_ease(Tween.EASE_IN_OUT).set_trans(Tween.TRANS_SINE)
	var mod_pulse := create_tween().set_loops()
	mod_pulse.tween_property(tile.visual, "modulate", color, 0.5).set_ease(Tween.EASE_IN_OUT).set_trans(Tween.TRANS_SINE)
	mod_pulse.tween_property(tile.visual, "modulate", Color(color.r * 0.7 + 0.3, color.g * 0.7 + 0.3, color.b * 0.7 + 0.3), 0.5).set_ease(Tween.EASE_IN_OUT).set_trans(Tween.TRANS_SINE)
	shimmer_tweens.append(pulse)
	shimmer_tweens.append(mod_pulse)
	_spawn_glow_ring(tile.global_position, color)

func highlight_traps():
	for tile in tiles:
		if tile.is_trap() and not tile.revealed:
			_hint_glow(tile, Color(1.0, 0.15, 0.15))

func highlight_tile(tile: Area2D, color: Color):
	if not tile.revealed:
		_hint_glow(tile, color)

func highlight_safe():
	for tile in tiles:
		if tile.is_safe() and not tile.revealed:
			_hint_glow(tile, Color(1.0, 0.85, 0.2))
			break

func get_random_unrevealed_idx() -> int:
	var candidates: Array[int] = []
	for i in range(tiles.size()):
		if not tiles[i].revealed:
			candidates.append(i)
	if candidates.is_empty():
		return -1
	return candidates[randi() % candidates.size()]

func apply_luck() -> bool:
	var trap_indices: Array[int] = []
	for i in range(tiles.size()):
		if tiles[i].is_trap() and not tiles[i].revealed:
			trap_indices.append(i)
	if trap_indices.is_empty():
		return false
	var idx: int = trap_indices[randi() % trap_indices.size()]
	tiles[idx].tile_type = 0
	var tw := create_tween()
	for tile in tiles:
		if not tile.revealed:
			tw.tween_property(tile.visual, "position:x", tile.visual.position.x + 5, 0.04)
			tw.tween_property(tile.visual, "position:x", tile.visual.position.x - 5, 0.04)
			tw.tween_property(tile.visual, "position:x", tile.visual.position.x, 0.04)
	_spawn_luck_sparkles()
	return true

func curse_tiles():
	stop_shimmer()
	for tile in tiles:
		if not tile.revealed:
			tile.visual.modulate = curse_color
			var tw := create_tween().set_loops()
			tw.tween_property(tile.visual, "modulate:a", 0.6, 0.8).set_ease(Tween.EASE_IN_OUT).set_trans(Tween.TRANS_SINE)
			tw.tween_property(tile.visual, "modulate:a", 1.0, 0.8).set_ease(Tween.EASE_IN_OUT).set_trans(Tween.TRANS_SINE)
			shimmer_tweens.append(tw)

func _on_tile_tapped(tile: Area2D):
	lock_all()
	tile_chosen.emit(tile, self)

func _make_soft_circle(sz: int = 32) -> ImageTexture:
	return GameManagerClass.make_soft_circle(sz)

func _spawn_glow_ring(pos: Vector2, color: Color):
	var spr := Sprite2D.new()
	spr.texture = _make_soft_circle()
	spr.position = pos
	spr.scale = Vector2(1, 1)
	spr.modulate = Color(color.r, color.g, color.b, 0.6)
	spr.z_index = 7
	get_tree().current_scene.add_child(spr)
	var tw := create_tween().set_parallel(true)
	tw.tween_property(spr, "scale", Vector2(12, 12), 0.5).set_ease(Tween.EASE_OUT)
	tw.tween_property(spr, "modulate:a", 0.0, 0.5)
	tw.chain().tween_callback(spr.queue_free)

func _spawn_luck_sparkles():
	var tex := _make_soft_circle()
	for i in 9:
		var spr := Sprite2D.new()
		spr.texture = tex
		spr.modulate = Color(0.7, 0.3, 1.0, 0.8)
		spr.z_index = 7
		var t: Area2D = tiles[randi() % tiles.size()]
		spr.position = t.global_position + Vector2(randf_range(-40, 40), randf_range(-30, 30))
		spr.scale = Vector2(1.5, 1.5)
		get_tree().current_scene.add_child(spr)
		var tw := create_tween().set_parallel(true)
		tw.tween_property(spr, "position:y", spr.position.y - randf_range(40, 80), 0.6).set_ease(Tween.EASE_OUT)
		tw.tween_property(spr, "modulate:a", 0.0, 0.6)
		tw.chain().tween_callback(spr.queue_free)

func shimmer_tiles():
	stop_shimmer()
	for tile in tiles:
		if not tile.revealed:
			tile.visual.modulate = Color(1.0, 0.95, 0.8)
			var tw := create_tween().set_loops()
			tw.tween_property(tile.visual, "modulate", Color(1.0, 0.85, 0.6), 0.8)
			tw.tween_property(tile.visual, "modulate", Color(1.0, 0.95, 0.8), 0.8)
			shimmer_tweens.append(tw)

func stop_shimmer():
	for tw in shimmer_tweens:
		if tw and tw.is_running():
			tw.kill()
	shimmer_tweens.clear()
	for tile in tiles:
		if not tile.revealed:
			tile.visual.modulate = Color.WHITE

func _spawn_decor():
	var decor_node := $Decor
	var glow_left := (level_index % 2 == 0)
	_spawn_wall_decor(decor_node, -1)
	_spawn_wall_decor(decor_node, 1)
	_spawn_wall_glow(decor_node, -1 if glow_left else 1)

func _spawn_wall_glow(parent: Node2D, side: int):
	var glow := Sprite2D.new()
	glow.texture = _make_soft_circle(64)
	glow.position = Vector2(side * glow_offset_x, glow_offset_y)
	glow.scale = glow_scale
	glow.modulate = glow_color
	glow.z_index = 5
	parent.add_child(glow)
	var tw := create_tween().set_loops()
	tw.tween_property(glow, "modulate:a", glow_alpha_min, glow_speed).set_ease(Tween.EASE_IN_OUT).set_trans(Tween.TRANS_SINE)
	tw.tween_property(glow, "modulate:a", glow_alpha_max, glow_speed).set_ease(Tween.EASE_IN_OUT).set_trans(Tween.TRANS_SINE)

func _spawn_wall_decor(parent: Node2D, side: int):
	var roll := randi() % 100
	var tex_path: String
	var item_scale := 2.5
	if roll < 35:
		tex_path = DECOR_SHIELD
	elif roll < 60:
		tex_path = DECOR_SWORDS if randi() % 2 == 0 else DECOR_AXES
	else:
		tex_path = DECOR_PAINTING
		item_scale = 2.0
	var spr := Sprite2D.new()
	spr.texture = load(tex_path)
	spr.scale = Vector2(item_scale, item_scale)
	spr.position = Vector2(side * decor_offset_x, -10)
	spr.modulate = decor_modulate
	parent.add_child(spr)
