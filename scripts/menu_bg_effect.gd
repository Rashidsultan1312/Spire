extends Node2D

var VIEWPORT_WIDTH: float
var VIEWPORT_HEIGHT: float
const SOURCE_WIDTH := 3840.0
const SOURCE_HEIGHT := 2160.0

@export_group("Parallax")
@export var sway_speed_x := 0.35
@export var sway_speed_y := 0.2
@export var gate_breath_strength := 0.003

@export_group("Bats")
@export var max_bats := 8
@export var initial_bats := 3
@export var bat_spawn_interval_min := 2.5
@export var bat_spawn_interval_max := 5.0
@export var bat_color := Color(0.15, 0.08, 0.2)

@export_group("Fireflies")
@export var firefly_count := 15
@export var warm_color_chance := 0.7

const BatSheet := preload("res://assets/sprites/v2/enemies/bat_sprite.png")
const BAT_COLS := 2
const BAT_ROWS := 3
const BAT_FRAME_SIZE := 32

var elapsed := 0.0
var fit_scale: float
var offset_x: float

var layers: Array[Sprite2D] = []
var layer_origin_x: Array[float] = []
var layer_origin_y: Array[float] = []
var layer_amplitude_x: Array[float] = []
var layer_amplitude_y: Array[float] = []

var bats: Array[Dictionary] = []
var fireflies: Array[Dictionary] = []
var bat_frames: Array[AtlasTexture] = []
var bat_spawn_timer := 0.0

func _ready():
	VIEWPORT_WIDTH = get_viewport().get_visible_rect().size.x
	VIEWPORT_HEIGHT = get_viewport().get_visible_rect().size.y
	fit_scale = (VIEWPORT_HEIGHT + 200.0) / SOURCE_HEIGHT
	offset_x = (VIEWPORT_WIDTH - SOURCE_WIDTH * fit_scale) / 2.0
	var offset_y := -100.0

	var layer_data := [
		[$Sky, 0.0, 0.0, 6.0, 1.5],
		[$Castle, 417.0, 0.0, 14.0, 3.0],
		[$Gate, 0.0, 0.0, 25.0, 6.0],
		[$Ground, 0.0, 787.0, 40.0, 10.0],
		[$Foreground, 0.0, 1592.0, 60.0, 15.0],
	]

	for entry in layer_data:
		var sprite: Sprite2D = entry[0]
		sprite.centered = false
		sprite.scale = Vector2(fit_scale, fit_scale)
		var origin_x: float = offset_x + float(entry[1]) * fit_scale
		var origin_y: float = offset_y + float(entry[2]) * fit_scale
		layers.append(sprite)
		layer_origin_x.append(origin_x)
		layer_origin_y.append(origin_y)
		layer_amplitude_x.append(float(entry[3]))
		layer_amplitude_y.append(float(entry[4]))
		sprite.position = Vector2(origin_x, origin_y)

	for row in BAT_ROWS:
		for col in BAT_COLS:
			var atlas := AtlasTexture.new()
			atlas.atlas = BatSheet
			atlas.region = Rect2(col * BAT_FRAME_SIZE, row * BAT_FRAME_SIZE, BAT_FRAME_SIZE, BAT_FRAME_SIZE)
			bat_frames.append(atlas)

	for i in initial_bats:
		_spawn_bat()
	for i in firefly_count:
		_spawn_firefly()

func _process(delta: float):
	elapsed += delta
	_update_parallax()
	_update_gate_breathing()
	_try_spawn_bat(delta)
	_update_bats(delta)
	_update_fireflies()

func _update_parallax():
	for i in layers.size():
		var wave_x := sin(elapsed * sway_speed_x + float(i) * 0.4)
		var wave_y := sin(elapsed * sway_speed_y + float(i) * 0.6)
		layers[i].position.x = layer_origin_x[i] + wave_x * layer_amplitude_x[i]
		layers[i].position.y = layer_origin_y[i] + wave_y * layer_amplitude_y[i]

func _update_gate_breathing():
	var breath := 1.0 + sin(elapsed * 0.5) * gate_breath_strength
	layers[2].scale = Vector2(fit_scale * breath, fit_scale * breath)

func _try_spawn_bat(delta: float):
	bat_spawn_timer += delta
	if bat_spawn_timer > bat_spawn_interval_min + randf() * (bat_spawn_interval_max - bat_spawn_interval_min):
		bat_spawn_timer = 0.0
		if bats.size() < max_bats:
			_spawn_bat()

func _spawn_bat():
	var sprite := Sprite2D.new()
	sprite.texture = bat_frames[0]
	sprite.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST

	var is_close := randf() > 0.6
	var bat_scale: float
	var alpha: float
	var speed_base: float
	if is_close:
		bat_scale = randf_range(3.5, 5.0)
		alpha = randf_range(0.6, 0.85)
		speed_base = randf_range(120.0, 200.0)
	else:
		bat_scale = randf_range(1.2, 2.5)
		alpha = randf_range(0.3, 0.55)
		speed_base = randf_range(50.0, 100.0)
	sprite.scale = Vector2(bat_scale, bat_scale)

	var from_left := randf() > 0.5
	var start_x: float = -100.0 if from_left else VIEWPORT_WIDTH + 100.0
	var start_y := randf_range(20.0, 550.0)
	var speed := speed_base
	if not from_left:
		speed = -speed
		sprite.flip_h = true

	sprite.position = Vector2(start_x, start_y)
	sprite.modulate = Color(bat_color.r, bat_color.g, bat_color.b, alpha)
	sprite.z_index = 7 if is_close else 5
	add_child(sprite)

	bats.append({
		node = sprite,
		speed = speed,
		wave_amplitude = randf_range(25.0, 80.0),
		wave_frequency = randf_range(2.5, 5.5),
		base_y = start_y,
		anim_time = randf() * TAU,
		swoop_phase = randf() * TAU,
		will_dive = randf() > 0.6,
		dive_time = randf_range(1.5, 4.0),
		has_dived = false,
	})

func _update_bats(delta: float):
	var to_remove: Array[int] = []
	for i in bats.size():
		var bat: Dictionary = bats[i]
		var sprite: Sprite2D = bat.node
		bat.anim_time = float(bat.anim_time) + delta
		sprite.position.x += float(bat.speed) * delta

		var anim_t := float(bat.anim_time)
		var wave := sin(anim_t * float(bat.wave_frequency))
		var swoop := sin(anim_t * 1.2 + float(bat.swoop_phase)) * 20.0

		if bool(bat.will_dive) and not bool(bat.has_dived) and anim_t > float(bat.dive_time):
			bat.has_dived = true
			bat.base_y = float(bat.base_y) + 120.0

		sprite.position.y = float(bat.base_y) + wave * float(bat.wave_amplitude) + swoop

		var frame_index := int(anim_t * 8.0) % bat_frames.size()
		sprite.texture = bat_frames[frame_index]

		var tilt := wave * 0.2 + signf(float(bat.speed)) * 0.05
		sprite.rotation = tilt

		if sprite.position.x < -150.0 or sprite.position.x > VIEWPORT_WIDTH + 150.0:
			to_remove.append(i)

	for i in range(to_remove.size() - 1, -1, -1):
		var idx: int = to_remove[i]
		bats[idx].node.queue_free()
		bats.remove_at(idx)

func _spawn_firefly():
	var sprite := Sprite2D.new()
	var img := Image.create(6, 6, false, Image.FORMAT_RGBA8)
	for pixel_y in 6:
		for pixel_x in 6:
			var dx := float(pixel_x) - 2.5
			var dy := float(pixel_y) - 2.5
			var dist := sqrt(dx * dx + dy * dy)
			var alpha := maxf(0.0, 1.0 - dist / 3.0)
			img.set_pixel(pixel_x, pixel_y, Color(1, 1, 1, alpha))
	sprite.texture = ImageTexture.create_from_image(img)

	var fly_scale := randf_range(1.5, 3.0)
	sprite.scale = Vector2(fly_scale, fly_scale)
	var pos_x := randf_range(30.0, VIEWPORT_WIDTH - 30.0)
	var pos_y := randf_range(150.0, VIEWPORT_HEIGHT - 80.0)
	sprite.position = Vector2(pos_x, pos_y)

	var color: Color
	if randf() < warm_color_chance:
		color = Color(1.0, randf_range(0.7, 0.95), randf_range(0.2, 0.5), 0.0)
	else:
		color = Color(0.6, 0.7, 1.0, 0.0)
	sprite.modulate = color
	sprite.z_index = 6
	add_child(sprite)

	fireflies.append({
		node = sprite,
		origin_x = pos_x,
		origin_y = pos_y,
		drift_x = randf_range(20.0, 50.0),
		drift_y = randf_range(15.0, 35.0),
		phase = randf() * TAU,
		pulse_speed = randf_range(1.2, 2.5),
		move_speed = randf_range(0.2, 0.5),
	})

func _update_fireflies():
	for fly in fireflies:
		var sprite: Sprite2D = fly.node
		var move_t := elapsed * float(fly.move_speed)
		var phase := float(fly.phase)
		sprite.position.x = float(fly.origin_x) + sin(move_t + phase) * float(fly.drift_x)
		sprite.position.y = float(fly.origin_y) + cos(move_t * 0.7 + phase) * float(fly.drift_y)
		var pulse := sin(elapsed * float(fly.pulse_speed) + phase)
		sprite.modulate.a = maxf(0.0, pulse * 0.5 + 0.2)
