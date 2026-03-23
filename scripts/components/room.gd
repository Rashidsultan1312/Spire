extends Node2D

signal door_chosen(door: Area2D, room_node: Node2D)

var level_index := 0
var doors: Array[Area2D] = []
var shimmer_tweens: Array[Tween] = []
var door_count := 3
var world_theme := {}

const DoorScene := preload("res://scenes/components/door.tscn")
const WallTex1 := preload("res://assets/sprites/v3/tiles/wall1.png")
const WallTex2 := preload("res://assets/sprites/v3/tiles/wall2.png")
const FloorTex := preload("res://assets/sprites/v3/room/stone_floor.png")
const TorchTex := preload("res://assets/sprites/v3/tiles/torch.png")

const DOOR_POSITIONS := {
	2: [-130.0, 130.0],
	3: [-180.0, 0.0, 180.0],
	4: [-220.0, -73.0, 73.0, 220.0],
}

const LadderTex := preload("res://assets/sprites/v3/room/ladder.png")

const CLUE_BASE_CHANCES := [0.60, 0.55, 0.50, 0.45, 0.40, 0.35, 0.30, 0.25, 0.20, 0.15]
const DIFFICULTY_CLUE_MULT := [1.3, 1.0, 0.6]

func _exit_tree():
	stop_shimmer()

func setup(level_idx: int, theme: Dictionary = {}):
	level_index = level_idx
	world_theme = theme
	randomize()

	door_count = 3 if randi() % 100 < 60 else 4
	_build_room_visuals()
	_spawn_doors(door_count)

	var safe_n := GameManager.safe_count(level_idx + 1, door_count)
	var trap_n := door_count - safe_n
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

	for i in range(mini(types.size(), doors.size())):
		doors[i].tile_type = types[i]
	for i in range(doors.size()):
		if doors[i].tile_type == 0:
			if randi() % 100 < 20:
				doors[i].has_key = true

	_apply_door_theme()
	_generate_clues()
	_spawn_platform()
	_spawn_stairs()
	_spawn_torches()
	_spawn_decor()

func _build_room_visuals():
	pass

const LADDER_HEIGHT := 210.0
const LADDER_TOP_Y := 45.0
const PLATFORM_Y := 45.0
const PLATFORM_HEIGHT := 18.0
const LADDER_X_LEFT := -280.0
const LADDER_X_RIGHT := 280.0
var ladder_x := 0.0

func _spawn_platform():
	var plat := Sprite2D.new()
	plat.texture = FloorTex
	plat.texture_repeat = CanvasItem.TEXTURE_REPEAT_ENABLED
	plat.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	plat.region_enabled = true
	plat.region_rect = Rect2(0, 0, 400, int(PLATFORM_HEIGHT + 4))
	plat.scale = Vector2(2.0, 2.0)
	plat.position = Vector2(0, PLATFORM_Y)
	plat.z_index = 1
	plat.modulate = Color(0.85, 0.75, 0.95, 1.0)
	add_child(plat)

	var edge := Sprite2D.new()
	edge.texture = FloorTex
	edge.texture_repeat = CanvasItem.TEXTURE_REPEAT_ENABLED
	edge.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	edge.region_enabled = true
	edge.region_rect = Rect2(0, 0, 400, 5)
	edge.scale = Vector2(2.0, 2.0)
	edge.position = Vector2(0, PLATFORM_Y - PLATFORM_HEIGHT + 2)
	edge.z_index = 2
	edge.modulate = Color(1.0, 0.9, 1.1, 1.0)
	add_child(edge)

func _spawn_stairs():
	ladder_x = LADDER_X_RIGHT if level_index % 2 == 0 else LADDER_X_LEFT
	var tex_size := LadderTex.get_size()
	var fit := LADDER_HEIGHT / tex_size.y
	var ladder := Sprite2D.new()
	ladder.texture = LadderTex
	ladder.scale = Vector2(fit * 1.4, fit)
	ladder.position = Vector2(ladder_x, LADDER_TOP_Y + LADDER_HEIGHT / 2.0)
	ladder.z_index = -2
	add_child(ladder)

func get_ladder_x() -> float:
	return ladder_x

func get_ladder_bottom_y() -> float:
	return -51.0

func _spawn_doors(n: int):
	var positions: Array = DOOR_POSITIONS[n]
	for i in range(n):
		var door: Area2D = DoorScene.instantiate()
		door.position = Vector2(positions[i], -30)
		add_child(door)
		doors.append(door)
		door.door_tapped.connect(_on_door_tapped)

func _apply_door_theme():
	if world_theme.is_empty():
		return
	for door in doors:
		door.visual.apply_theme(world_theme)

func _generate_clues():
	var world_idx := clampi(GameManager.current_world, 0, 9)
	var diff_idx := clampi(int(GameManager.difficulty), 0, 2)
	var base_chance: float = CLUE_BASE_CHANCES[world_idx]
	var chance: float = base_chance * DIFFICULTY_CLUE_MULT[diff_idx]

	var trap_clues := ["skull", "scratches", "cracks", "smoke"]
	var safe_clues := ["sparkles", "light_rays"]
	var any_clue := false
	for door in doors:
		if door.revealed:
			continue
		if randf() > chance:
			continue
		if door.is_trap():
			door.show_clue(trap_clues[randi() % trap_clues.size()])
			any_clue = true
		elif door.is_safe():
			door.show_clue(safe_clues[randi() % safe_clues.size()])
			any_clue = true
		elif door.is_empty():
			door.show_clue("cobweb")
			any_clue = true
	var has_safe_clue := false
	for door in doors:
		if door.is_safe() and door.clue_type != "":
			has_safe_clue = true
			break
	if not has_safe_clue:
		var safe_candidates: Array[Area2D] = []
		for door in doors:
			if not door.revealed and door.is_safe() and door.clue_type == "":
				safe_candidates.append(door)
		if not safe_candidates.is_empty():
			var pick: Area2D = safe_candidates[randi() % safe_candidates.size()]
			pick.show_clue(safe_clues[randi() % safe_clues.size()])
			any_clue = true
	if not any_clue:
		var candidates: Array[Area2D] = []
		for door in doors:
			if not door.revealed and door.is_safe():
				candidates.append(door)
		if not candidates.is_empty():
			var pick: Area2D = candidates[randi() % candidates.size()]
			pick.show_clue(safe_clues[randi() % safe_clues.size()])

func _spawn_torches():
	var torch_positions := [-320.0, 320.0]
	for torch_x in torch_positions:
		var torch_spr := Sprite2D.new()
		torch_spr.texture = TorchTex
		torch_spr.position = Vector2(torch_x, -120)
		torch_spr.scale = Vector2(0.12, 0.12)
		torch_spr.z_index = 3
		add_child(torch_spr)

		var glow := Sprite2D.new()
		glow.texture = GameManagerClass.make_soft_circle(64)
		glow.position = Vector2(torch_x, -150)
		glow.scale = Vector2(8, 6)
		var glow_color: Color = world_theme.get("glow_color", Color(1.0, 0.6, 0.25, 0.18))
		glow.modulate = glow_color
		glow.z_index = -1
		add_child(glow)

		var tw := create_tween().set_loops()
		tw.tween_property(glow, "modulate:a", glow_color.a * 0.5, 1.5).set_ease(Tween.EASE_IN_OUT).set_trans(Tween.TRANS_SINE)
		tw.tween_property(glow, "modulate:a", glow_color.a * 1.2, 1.5).set_ease(Tween.EASE_IN_OUT).set_trans(Tween.TRANS_SINE)
		shimmer_tweens.append(tw)

func _spawn_decor():
	var decor_node := Node2D.new()
	decor_node.name = "Decor"
	add_child(decor_node)
	for side in [-1, 1]:
		if randi() % 100 < 50:
			var spr := Sprite2D.new()
			spr.texture = TorchTex
			spr.scale = Vector2(0.08, 0.08)
			spr.position = Vector2(side * 340, -60)
			var mod_color: Color = world_theme.get("wall_modulate", Color(0.55, 0.45, 0.65, 0.8))
			spr.modulate = mod_color
			decor_node.add_child(spr)


func has_npc_door() -> bool:
	for door in doors:
		if door.is_npc():
			return true
	return false

func clear_clues():
	for door in doors:
		door.clue_overlay.visible = false
		door.clue_type = ""
		for tw in door._clue_tweens:
			if tw and tw.is_running():
				tw.kill()
		door._clue_tweens.clear()
		for spr in door._clue_particles:
			if is_instance_valid(spr):
				spr.queue_free()
		door._clue_particles.clear()
		if door._clue_timer and is_instance_valid(door._clue_timer):
			door._clue_timer.queue_free()
			door._clue_timer = null

func memory_shuffle(peek_time: float, shuffle_count: int, shuffle_speed: float) -> void:
	lock_all()
	clear_clues()

	for door in doors:
		door.peek()
	await get_tree().create_timer(peek_time).timeout

	for door in doors:
		door.unpeek()
	await get_tree().create_timer(0.35).timeout

	_spawn_shuffle_vortex()

	for i in shuffle_count:
		var idx_a := randi() % doors.size()
		var idx_b := idx_a
		while idx_b == idx_a:
			idx_b = randi() % doors.size()

		var door_a: Area2D = doors[idx_a]
		var door_b: Area2D = doors[idx_b]
		var pos_a := door_a.position
		var pos_b := door_b.position
		var mid_x := (pos_a.x + pos_b.x) * 0.5
		var arc_height := absf(pos_a.x - pos_b.x) * 0.25 + 20.0
		var spin_dir := 1.0 if i % 2 == 0 else -1.0

		door_a.z_index = -1
		door_b.z_index = 1
		var half_dur := shuffle_speed * 0.5

		SoundManager.play("swoosh", -4.0)

		var tw1 := create_tween().set_parallel(true)
		tw1.tween_property(door_a, "position:x", mid_x, half_dur).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN)
		tw1.tween_property(door_a, "position:y", pos_a.y - arc_height, half_dur).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
		tw1.tween_property(door_a, "scale", Vector2(0.6, 0.6), half_dur)
		tw1.tween_property(door_a, "modulate", Color(0.5, 0.4, 0.7), half_dur)
		tw1.tween_property(door_a, "rotation", spin_dir * 0.15, half_dur).set_trans(Tween.TRANS_SINE)
		tw1.tween_property(door_b, "position:x", mid_x, half_dur).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN)
		tw1.tween_property(door_b, "position:y", pos_b.y + arc_height * 0.6, half_dur).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
		tw1.tween_property(door_b, "scale", Vector2(1.2, 1.2), half_dur)
		tw1.tween_property(door_b, "modulate", Color(1.2, 1.1, 1.3), half_dur)
		tw1.tween_property(door_b, "rotation", spin_dir * -0.15, half_dur).set_trans(Tween.TRANS_SINE)
		_spawn_shuffle_ghosts(door_a, door_b, half_dur)
		_spawn_swap_sparks(door_a.position, door_b.position)
		await tw1.finished

		var tw2 := create_tween().set_parallel(true)
		tw2.tween_property(door_a, "position", pos_b, half_dur).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
		tw2.tween_property(door_a, "scale", Vector2(1.0, 1.0), half_dur).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
		tw2.tween_property(door_a, "modulate", Color.WHITE, half_dur)
		tw2.tween_property(door_a, "rotation", 0.0, half_dur).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
		tw2.tween_property(door_b, "position", pos_a, half_dur).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
		tw2.tween_property(door_b, "scale", Vector2(1.0, 1.0), half_dur).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
		tw2.tween_property(door_b, "modulate", Color.WHITE, half_dur)
		tw2.tween_property(door_b, "rotation", 0.0, half_dur).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
		_spawn_shuffle_ghosts(door_a, door_b, half_dur)
		await tw2.finished

		_spawn_land_dust(pos_a)
		_spawn_land_dust(pos_b)

		door_a.z_index = 0
		door_b.z_index = 0

		var tmp = doors[idx_a]
		doors[idx_a] = doors[idx_b]
		doors[idx_b] = tmp

		if i < shuffle_count - 1:
			await get_tree().create_timer(0.05).timeout

	for door in doors:
		door.modulate = Color.WHITE
		door.rotation = 0.0
		var bounce := create_tween()
		bounce.tween_property(door, "scale", Vector2(1.12, 0.9), 0.06).set_trans(Tween.TRANS_BACK)
		bounce.tween_property(door, "scale", Vector2(0.95, 1.08), 0.07).set_trans(Tween.TRANS_SINE)
		bounce.tween_property(door, "scale", Vector2(1.0, 1.0), 0.08).set_trans(Tween.TRANS_SINE)
	_spawn_landing_flash()

	unlock_all()

func _spawn_shuffle_vortex():
	var center := Vector2.ZERO
	for door in doors:
		center += door.position
	center /= float(doors.size())
	for i in 6:
		var ring := Sprite2D.new()
		ring.texture = GameManagerClass.make_soft_circle(64)
		ring.position = center + Vector2(0, -20)
		ring.scale = Vector2(0.5, 0.5)
		ring.modulate = Color(0.6, 0.4, 1.0, 0.0)
		ring.z_index = -3
		add_child(ring)
		var delay := float(i) * 0.12
		var tw := create_tween().set_parallel(true)
		tw.tween_property(ring, "scale", Vector2(14, 10), 1.2).set_delay(delay).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
		tw.tween_property(ring, "modulate:a", 0.15, 0.3).set_delay(delay)
		tw.tween_property(ring, "modulate:a", 0.0, 0.6).set_delay(delay + 0.6)
		tw.tween_property(ring, "rotation", TAU * (1.0 if i % 2 == 0 else -1.0), 1.2).set_delay(delay)
		tw.chain().tween_callback(ring.queue_free)

func _spawn_shuffle_ghosts(door_a: Area2D, door_b: Area2D, duration: float):
	var ghost_count := 4
	var interval := duration / float(ghost_count)
	for i in ghost_count:
		var delay := float(i) * interval
		get_tree().create_timer(delay).timeout.connect(func():
			_create_ghost(door_a)
			_create_ghost(door_b))

func _create_ghost(door: Area2D):
	if not is_instance_valid(door) or not is_instance_valid(door.visual):
		return
	var ghost := Sprite2D.new()
	ghost.texture = door.visual.texture
	if ghost.texture is AtlasTexture:
		var copy := AtlasTexture.new()
		copy.atlas = (ghost.texture as AtlasTexture).atlas
		copy.region = (ghost.texture as AtlasTexture).region
		ghost.texture = copy
	ghost.scale = door.visual.scale * door.scale
	ghost.position = door.position
	ghost.rotation = door.rotation
	ghost.modulate = Color(0.7, 0.5, 1.0, 0.35)
	ghost.z_index = -2
	add_child(ghost)
	var tw := create_tween().set_parallel(true)
	tw.tween_property(ghost, "modulate:a", 0.0, 0.2)
	tw.tween_property(ghost, "scale", ghost.scale * 0.85, 0.2)
	tw.chain().tween_callback(ghost.queue_free)

func _spawn_swap_sparks(from: Vector2, to: Vector2):
	var mid := (from + to) * 0.5
	var tex := GameManagerClass.make_soft_circle(10)
	for i in 8:
		var spark := Sprite2D.new()
		spark.texture = tex
		spark.position = mid + Vector2(randf_range(-30, 30), randf_range(-40, 10))
		var sz := randf_range(1.5, 3.0)
		spark.scale = Vector2(sz, sz)
		spark.modulate = Color(
			randf_range(0.6, 1.0),
			randf_range(0.4, 0.7),
			1.0,
			0.7
		)
		spark.z_index = 3
		add_child(spark)
		var angle := randf() * TAU
		var dist := randf_range(40, 90)
		var end_pos := spark.position + Vector2(cos(angle) * dist, sin(angle) * dist)
		var dur := randf_range(0.25, 0.45)
		var tw := create_tween().set_parallel(true)
		tw.tween_property(spark, "position", end_pos, dur).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
		tw.tween_property(spark, "modulate:a", 0.0, dur)
		tw.tween_property(spark, "scale", Vector2.ZERO, dur)
		tw.chain().tween_callback(spark.queue_free)

func _spawn_land_dust(pos: Vector2):
	var tex := GameManagerClass.make_soft_circle(16)
	for i in 4:
		var dust := Sprite2D.new()
		dust.texture = tex
		dust.position = pos + Vector2(randf_range(-20, 20), 30)
		var sz := randf_range(2.0, 4.0)
		dust.scale = Vector2(sz, sz * 0.5)
		dust.modulate = Color(0.8, 0.7, 1.0, 0.3)
		dust.z_index = -1
		add_child(dust)
		var side := -1.0 if i % 2 == 0 else 1.0
		var tw := create_tween().set_parallel(true)
		tw.tween_property(dust, "position:x", dust.position.x + side * randf_range(20, 50), 0.3).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
		tw.tween_property(dust, "position:y", dust.position.y - randf_range(10, 25), 0.3).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
		tw.tween_property(dust, "modulate:a", 0.0, 0.35)
		tw.tween_property(dust, "scale", dust.scale * 1.5, 0.35)
		tw.chain().tween_callback(dust.queue_free)

func _spawn_landing_flash():
	var center := Vector2.ZERO
	for door in doors:
		center += door.position
	center /= float(doors.size())
	var flash := Sprite2D.new()
	flash.texture = GameManagerClass.make_soft_circle(64)
	flash.position = center
	flash.scale = Vector2(1, 1)
	flash.modulate = Color(0.8, 0.7, 1.0, 0.5)
	flash.z_index = 4
	add_child(flash)
	var tw := create_tween().set_parallel(true)
	tw.tween_property(flash, "scale", Vector2(16, 12), 0.3).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tw.tween_property(flash, "modulate:a", 0.0, 0.3)
	tw.chain().tween_callback(flash.queue_free)

func lock_all():
	for door in doors:
		door.lock()

func unlock_all():
	for door in doors:
		door.unlock()

func unlock_remaining():
	for door in doors:
		if not door.revealed:
			door.unlock()

func show_hint(door_idx: int):
	if door_idx < 0 or door_idx >= doors.size():
		return
	var door: Area2D = doors[door_idx]
	if door.revealed:
		return
	var color := Color(1.0, 0.85, 0.2) if door.is_positive() else Color(1.0, 0.3, 0.3)
	door.visual.modulate = color
	var tw := create_tween()
	tw.tween_property(door.visual, "modulate", color, 0.15)
	tw.tween_property(door.visual, "modulate", Color.WHITE, 0.8).set_delay(1.5)
	_spawn_glow_ring(door.global_position, color)

func _hint_glow(door: Area2D, color: Color):
	var glow := Sprite2D.new()
	glow.texture = GameManagerClass.make_soft_circle(64)
	glow.position = Vector2(0, 0)
	glow.scale = Vector2(6, 6)
	glow.modulate = Color(color.r, color.g, color.b, 0.0)
	glow.z_index = -1
	door.add_child(glow)
	var appear := create_tween()
	appear.tween_property(glow, "modulate:a", 0.35, 0.4).set_ease(Tween.EASE_OUT)
	var pulse := create_tween().set_loops()
	pulse.tween_property(glow, "scale", Vector2(7, 7), 0.8).set_ease(Tween.EASE_IN_OUT).set_trans(Tween.TRANS_SINE)
	pulse.tween_property(glow, "scale", Vector2(5, 5), 0.8).set_ease(Tween.EASE_IN_OUT).set_trans(Tween.TRANS_SINE)
	var mod_pulse := create_tween().set_loops()
	mod_pulse.tween_property(door.visual, "modulate", color, 0.5).set_ease(Tween.EASE_IN_OUT).set_trans(Tween.TRANS_SINE)
	mod_pulse.tween_property(door.visual, "modulate", Color(color.r * 0.7 + 0.3, color.g * 0.7 + 0.3, color.b * 0.7 + 0.3), 0.5).set_ease(Tween.EASE_IN_OUT).set_trans(Tween.TRANS_SINE)
	shimmer_tweens.append(pulse)
	shimmer_tweens.append(mod_pulse)
	_spawn_glow_ring(door.global_position, color)

func highlight_traps():
	for door in doors:
		if door.is_trap() and not door.revealed:
			_hint_glow(door, Color(1.0, 0.15, 0.15))

func highlight_door(door: Area2D, color: Color):
	if not door.revealed:
		_hint_glow(door, color)

func highlight_safe():
	for door in doors:
		if door.is_safe() and not door.revealed:
			_hint_glow(door, Color(1.0, 0.85, 0.2))
			break

func get_random_unrevealed_idx() -> int:
	var candidates: Array[int] = []
	for i in range(doors.size()):
		if not doors[i].revealed:
			candidates.append(i)
	if candidates.is_empty():
		return -1
	return candidates[randi() % candidates.size()]

func apply_luck() -> bool:
	var trap_indices: Array[int] = []
	for i in range(doors.size()):
		if doors[i].is_trap() and not doors[i].revealed:
			trap_indices.append(i)
	if trap_indices.is_empty():
		return false
	var idx: int = trap_indices[randi() % trap_indices.size()]
	doors[idx].tile_type = 0
	var tw := create_tween()
	for door in doors:
		if not door.revealed:
			tw.tween_property(door.visual, "position:x", door.visual.position.x + 5, 0.04)
			tw.tween_property(door.visual, "position:x", door.visual.position.x - 5, 0.04)
			tw.tween_property(door.visual, "position:x", door.visual.position.x, 0.04)
	_spawn_luck_sparkles()
	return true

func curse_doors():
	stop_shimmer()
	var curse_color := Color(0.6, 0.3, 0.8)
	for door in doors:
		if not door.revealed:
			door.visual.modulate = curse_color
			var tw := create_tween().set_loops()
			tw.tween_property(door.visual, "modulate:a", 0.6, 0.8).set_ease(Tween.EASE_IN_OUT).set_trans(Tween.TRANS_SINE)
			tw.tween_property(door.visual, "modulate:a", 1.0, 0.8).set_ease(Tween.EASE_IN_OUT).set_trans(Tween.TRANS_SINE)
			shimmer_tweens.append(tw)

func shimmer_doors():
	stop_shimmer()
	for door in doors:
		if not door.revealed:
			door.visual.modulate = Color(1.0, 0.95, 0.8)
			var tw := create_tween().set_loops()
			tw.tween_property(door.visual, "modulate", Color(1.0, 0.85, 0.6), 0.8)
			tw.tween_property(door.visual, "modulate", Color(1.0, 0.95, 0.8), 0.8)
			shimmer_tweens.append(tw)

func stop_shimmer():
	for tw in shimmer_tweens:
		if tw and tw.is_running():
			tw.kill()
	shimmer_tweens.clear()
	for door in doors:
		if not door.revealed:
			door.visual.modulate = Color.WHITE

func _on_door_tapped(door: Area2D):
	lock_all()
	door_chosen.emit(door, self)

func _spawn_glow_ring(pos: Vector2, color: Color):
	var spr := Sprite2D.new()
	spr.texture = GameManagerClass.make_soft_circle()
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
	var tex := GameManagerClass.make_soft_circle()
	for i in 9:
		var spr := Sprite2D.new()
		spr.texture = tex
		spr.modulate = Color(0.7, 0.3, 1.0, 0.8)
		spr.z_index = 7
		var door: Area2D = doors[randi() % doors.size()]
		spr.position = door.global_position + Vector2(randf_range(-40, 40), randf_range(-30, 30))
		spr.scale = Vector2(1.5, 1.5)
		get_tree().current_scene.add_child(spr)
		var tw := create_tween().set_parallel(true)
		tw.tween_property(spr, "position:y", spr.position.y - randf_range(40, 80), 0.6).set_ease(Tween.EASE_OUT)
		tw.tween_property(spr, "modulate:a", 0.0, 0.6)
		tw.chain().tween_callback(spr.queue_free)
