extends Area2D

signal door_tapped(door: Area2D)
enum TileType { TREASURE, TRAP_SPIKES, TRAP_ROCK, TRAP_GUARD, EMPTY, NPC_HINT }

const ChestTex := preload("res://assets/sprites/v3/items/chest_open.png")
const CONTENT_SIZE := 100.0
const NPC_CONTENT_SIZE := 180.0

var tile_type := TileType.TREASURE
var revealed := false
var locked := false
var has_key := false
var clue_type := ""
@onready var visual: Sprite2D = $DoorVisual
@onready var content_sprite: Sprite2D = $ContentSprite
@onready var clue_overlay: Sprite2D = $ClueOverlay

func _ready():
	input_event.connect(_on_input_event)
	clue_overlay.visible = false
	content_sprite.visible = false

func _on_input_event(_viewport: Node, event: InputEvent, _shape_idx: int):
	if locked or revealed:
		return
	if event is InputEventMouseButton and event.pressed:
		door_tapped.emit(self)

func _show_content():
	content_sprite.visible = true
	content_sprite.modulate.a = 0.0
	match tile_type:
		TileType.TREASURE:
			content_sprite.texture = ChestTex
		TileType.EMPTY:
			content_sprite.texture = null
			content_sprite.visible = false
			return
		TileType.NPC_HINT:
			var gnome_atlas := AtlasTexture.new()
			gnome_atlas.atlas = load("res://assets/sprites/v3/characters/gnome_sheet.png")
			gnome_atlas.region = Rect2(0, 0, 64, 64)
			content_sprite.texture = gnome_atlas
		_:
			content_sprite.visible = false
			return
	if content_sprite.texture:
		var tex_size := content_sprite.texture.get_size()
		var target := NPC_CONTENT_SIZE if tile_type == TileType.NPC_HINT else CONTENT_SIZE
		var fit := target / maxf(tex_size.x, tex_size.y)
		content_sprite.scale = Vector2(fit, fit)
	var tw := create_tween()
	tw.tween_property(content_sprite, "modulate:a", 1.0, 0.2)

func reveal() -> Tween:
	if revealed:
		return null
	revealed = true
	locked = true

	clue_overlay.visible = false

	if is_trap():
		var face: int
		match tile_type:
			TileType.TRAP_SPIKES: face = 2
			TileType.TRAP_ROCK: face = 3
			TileType.TRAP_GUARD: face = 4
		var tw := create_tween()
		tw.tween_callback(func(): visual.set_face(face))
		tw.tween_callback(func():
			SoundManager.play("tile_trap")
			_shake_trap())
		return tw

	var open_tw: Tween = visual.play_open_anim()
	open_tw.tween_callback(func():
		if is_npc():
			content_sprite.z_index = 5
		_show_content()
		if is_safe():
			SoundManager.play("tile_safe")
			_pulse_safe()
		elif is_npc():
			_pulse_safe())
	return open_tw

func _pulse_safe():
	var base_scale := visual.scale
	var tw := create_tween()
	tw.tween_property(visual, "scale", base_scale * 1.08, 0.12).set_ease(Tween.EASE_OUT)
	tw.tween_property(visual, "scale", base_scale, 0.15).set_ease(Tween.EASE_IN)

func _shake_trap():
	var base_x := visual.position.x
	var tw := create_tween()
	for i in 4:
		var offset := 6.0 if i % 2 == 0 else -6.0
		tw.tween_property(visual, "position:x", base_x + offset, 0.04)
	tw.tween_property(visual, "position:x", base_x, 0.04)

var _clue_tweens: Array[Tween] = []
var _clue_particles: Array[Sprite2D] = []
var _clue_timer: Timer

func show_clue(type: String):
	clue_type = type
	clue_overlay.visible = true
	match type:
		"skull":
			clue_overlay.texture = preload("res://assets/sprites/v3/room/clue_skull.png")
			var tex_size := clue_overlay.texture.get_size()
			var fit := 40.0 / maxf(tex_size.x, tex_size.y)
			clue_overlay.scale = Vector2(fit, fit)
			clue_overlay.modulate = Color(1.0, 0.8, 0.8, 0.35)
			clue_overlay.position = Vector2(0, -55)
			var tw := create_tween().set_loops()
			tw.tween_property(clue_overlay, "modulate:a", 0.5, 1.2).set_ease(Tween.EASE_IN_OUT).set_trans(Tween.TRANS_SINE)
			tw.tween_property(clue_overlay, "modulate:a", 0.2, 1.2).set_ease(Tween.EASE_IN_OUT).set_trans(Tween.TRANS_SINE)
			_clue_tweens.append(tw)
		"scratches":
			clue_overlay.texture = preload("res://assets/sprites/v3/room/clue_scratches.png")
			var tex_size := clue_overlay.texture.get_size()
			var fit := 50.0 / maxf(tex_size.x, tex_size.y)
			clue_overlay.scale = Vector2(fit, fit)
			clue_overlay.modulate = Color(1.0, 0.3, 0.2, 0.3)
			clue_overlay.position = Vector2(8, -30)
			var tw := create_tween().set_loops()
			tw.tween_property(clue_overlay, "modulate:a", 0.45, 1.0).set_ease(Tween.EASE_IN_OUT).set_trans(Tween.TRANS_SINE)
			tw.tween_property(clue_overlay, "modulate:a", 0.15, 1.0).set_ease(Tween.EASE_IN_OUT).set_trans(Tween.TRANS_SINE)
			_clue_tweens.append(tw)
		"cracks":
			clue_overlay.texture = GameManagerClass.make_soft_circle(32)
			clue_overlay.modulate = Color(1.0, 0.15, 0.1, 0.3)
			clue_overlay.scale = Vector2(4.0, 1.5)
			clue_overlay.position = Vector2(0, -15)
			var tw := create_tween().set_loops()
			tw.tween_property(clue_overlay, "modulate:a", 0.45, 0.8).set_ease(Tween.EASE_IN_OUT).set_trans(Tween.TRANS_SINE)
			tw.tween_property(clue_overlay, "modulate:a", 0.15, 1.0).set_ease(Tween.EASE_IN_OUT).set_trans(Tween.TRANS_SINE)
			_clue_tweens.append(tw)
			for i in 3:
				var line := Sprite2D.new()
				line.texture = GameManagerClass.make_soft_circle(8)
				line.scale = Vector2(0.8, 5.0 + randf_range(0, 2.0))
				line.rotation = randf_range(-0.4, 0.4)
				line.position = Vector2(randf_range(-18, 18), randf_range(-40, -10))
				line.modulate = Color(0.9, 0.2, 0.1, 0.25)
				add_child(line)
				_clue_particles.append(line)
		"smoke":
			clue_overlay.visible = false
			_start_smoke_particles()
		"sparkles":
			clue_overlay.visible = false
			_start_sparkle_particles()
		"light_rays":
			clue_overlay.visible = false
			_start_light_rays()
		"cobweb":
			clue_overlay.texture = preload("res://assets/sprites/v3/room/clue_cobweb.png")
			clue_overlay.modulate = Color(0.8, 0.8, 0.85, 0.4)
			clue_overlay.scale = Vector2(0.15, 0.15)
			clue_overlay.position = Vector2(-25, -50)

func _start_light_rays():
	var angles := [0.35, -0.15, 0.08, -0.35, 0.5]
	var lengths := [11.0, 9.0, 13.0, 8.0, 7.0]
	for i in angles.size():
		var ray := Sprite2D.new()
		ray.texture = GameManagerClass.make_soft_circle(32)
		ray.rotation = angles[i]
		ray.scale = Vector2(0.8, lengths[i])
		ray.position = Vector2(angles[i] * -20.0, -30)
		ray.modulate = Color(1.0, randf_range(0.85, 0.95), randf_range(0.35, 0.5), 0.0)
		ray.z_index = 1
		add_child(ray)
		_clue_particles.append(ray)
		var delay := float(i) * 0.15
		var appear := create_tween()
		appear.tween_property(ray, "modulate:a", 0.4, 0.6).set_delay(delay)
		var dur := randf_range(0.9, 1.3)
		var pulse := create_tween().set_loops()
		pulse.tween_property(ray, "modulate:a", 0.45, dur).set_ease(Tween.EASE_IN_OUT).set_trans(Tween.TRANS_SINE).set_delay(delay + 0.6)
		pulse.tween_property(ray, "modulate:a", 0.12, dur * 1.1).set_ease(Tween.EASE_IN_OUT).set_trans(Tween.TRANS_SINE)
		_clue_tweens.append(pulse)

func _start_smoke_particles():
	_clue_timer = Timer.new()
	_clue_timer.wait_time = 0.5
	_clue_timer.autostart = true
	add_child(_clue_timer)
	_clue_timer.timeout.connect(func():
		if revealed:
			_clue_timer.queue_free()
			return
		var spr := Sprite2D.new()
		spr.texture = GameManagerClass.make_soft_circle(16)
		var sz := randf_range(2.0, 3.5)
		spr.scale = Vector2(sz, sz)
		spr.position = Vector2(randf_range(-20, 20), 5)
		spr.modulate = Color(0.25, 0.1, 0.35, 0.45)
		spr.z_index = -1
		add_child(spr)
		var tw := create_tween().set_parallel(true)
		tw.tween_property(spr, "position:y", spr.position.y - randf_range(50, 90), 1.8).set_ease(Tween.EASE_OUT)
		tw.tween_property(spr, "modulate:a", 0.0, 1.8)
		tw.tween_property(spr, "scale", spr.scale * 1.3, 1.8)
		tw.chain().tween_callback(spr.queue_free))

func _start_sparkle_particles():
	_clue_timer = Timer.new()
	_clue_timer.wait_time = 0.25
	_clue_timer.autostart = true
	add_child(_clue_timer)
	_clue_timer.timeout.connect(func():
		if revealed:
			_clue_timer.queue_free()
			return
		var spr := Sprite2D.new()
		spr.texture = GameManagerClass.make_soft_circle(10)
		var sz := randf_range(2.0, 3.0)
		spr.scale = Vector2(sz, sz)
		var angle := randf() * TAU
		var radius := randf_range(35, 60)
		spr.position = Vector2(cos(angle) * radius, sin(angle) * radius - 25)
		spr.modulate = Color(1.0, randf_range(0.82, 0.92), randf_range(0.25, 0.4), 0.7)
		spr.z_index = 2
		add_child(spr)
		var end_angle := angle + randf_range(0.8, 1.5)
		var end_radius := radius * 0.4
		var end_pos := Vector2(cos(end_angle) * end_radius, sin(end_angle) * end_radius - 25)
		var dur := randf_range(0.9, 1.3)
		var tw := create_tween().set_parallel(true)
		tw.tween_property(spr, "position", end_pos, dur).set_ease(Tween.EASE_IN_OUT).set_trans(Tween.TRANS_SINE)
		tw.tween_property(spr, "scale", Vector2(0.5, 0.5), dur)
		tw.tween_property(spr, "modulate:a", 0.0, dur * 0.5).set_delay(dur * 0.5)
		tw.chain().tween_callback(spr.queue_free))

func peek():
	if revealed:
		return
	clue_overlay.visible = false
	if is_trap():
		var face: int
		match tile_type:
			TileType.TRAP_SPIKES: face = 2
			TileType.TRAP_ROCK: face = 3
			TileType.TRAP_GUARD: face = 4
		visual.set_face(face)
	else:
		visual.play_open_anim()
		_show_content()

func unpeek():
	if revealed:
		return
	visual.stop_spritesheet_anim()
	content_sprite.visible = false
	if is_trap():
		visual.face = visual.Face.HIDDEN
		visual.texture = visual.hidden_tex if visual.hidden_tex else visual._door_atlas
		visual._set_door_frame(0)
		visual._fit_scale()
	else:
		visual.play_close_anim()

func lock():
	locked = true

func unlock():
	if not revealed:
		locked = false

func reveal_instant():
	if revealed:
		return
	revealed = true
	locked = true
	clue_overlay.visible = false
	if is_trap():
		var face: int
		match tile_type:
			TileType.TRAP_SPIKES: face = 2
			TileType.TRAP_ROCK: face = 3
			TileType.TRAP_GUARD: face = 4
		visual.set_face(face)
	else:
		visual._set_door_frame(8)
		_show_content()

func is_safe() -> bool:
	return tile_type == TileType.TREASURE

func is_empty() -> bool:
	return tile_type == TileType.EMPTY

func is_npc() -> bool:
	return tile_type == TileType.NPC_HINT

func is_trap() -> bool:
	return tile_type in [TileType.TRAP_SPIKES, TileType.TRAP_ROCK, TileType.TRAP_GUARD]

func is_positive() -> bool:
	return tile_type in [TileType.TREASURE, TileType.EMPTY, TileType.NPC_HINT]

func _exit_tree():
	for tw in _clue_tweens:
		if tw and tw.is_running():
			tw.kill()
	_clue_tweens.clear()
	for spr in _clue_particles:
		if is_instance_valid(spr):
			spr.queue_free()
	_clue_particles.clear()
	if _clue_timer and is_instance_valid(_clue_timer):
		_clue_timer.queue_free()
