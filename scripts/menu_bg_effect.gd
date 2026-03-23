extends Node2D

var VIEWPORT_WIDTH: float
var VIEWPORT_HEIGHT: float

@export_group("Parallax")
@export var sway_speed_x := 0.25
@export var sway_speed_y := 0.15
@export var sway_amount_x := 8.0
@export var sway_amount_y := 4.0

@export_group("Bats")
@export var max_bats := 8
@export var initial_bats := 3
@export var bat_spawn_interval_min := 2.5
@export var bat_spawn_interval_max := 5.0
@export var bat_color := Color(0.15, 0.08, 0.2)

@export_group("Fireflies")
@export var firefly_count := 15
@export var warm_color_chance := 0.7

@export_group("Runes")
@export var rune_count := 9
@export var rune_symbols: Array[String] = ["✦", "☽", "⚔", "♦", "✧", "◆", "△", "⬡", "☆"]
@export var rune_color := Color(1, 0.85, 0.3)
@export var rune_speed_min := 15.0
@export var rune_speed_max := 30.0

@export_group("Fog")
@export var fog_count := 4
@export var fog_color := Color(0.3, 0.2, 0.5)

const BatSheet := preload("res://assets/sprites/v2/enemies/bat_sprite.png")
const BAT_COLS := 2
const BAT_ROWS := 3
const BAT_FRAME_SIZE := 32

var elapsed := 0.0
var bg_sprite: Sprite2D
var bg_origin := Vector2.ZERO

var bats: Array[Dictionary] = []
var fireflies: Array[Dictionary] = []
var runes: Array[Dictionary] = []
var fogs: Array[Dictionary] = []
var bat_frames: Array[AtlasTexture] = []
var bat_spawn_timer := 0.0

func _ready():
	VIEWPORT_WIDTH = get_viewport().get_visible_rect().size.x
	VIEWPORT_HEIGHT = get_viewport().get_visible_rect().size.y

	bg_sprite = $BG
	bg_sprite.centered = false
	var tex := bg_sprite.texture
	var scale_x := VIEWPORT_WIDTH / tex.get_width()
	var scale_y := VIEWPORT_HEIGHT / tex.get_height()
	var fit := maxf(scale_x, scale_y) * 1.03
	bg_sprite.scale = Vector2(fit, fit)
	bg_origin.x = (VIEWPORT_WIDTH - tex.get_width() * fit) / 2.0
	bg_origin.y = (VIEWPORT_HEIGHT - tex.get_height() * fit) / 2.0
	bg_sprite.position = bg_origin

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
	for i in rune_count:
		_spawn_rune()
	for i in fog_count:
		_spawn_fog()

func _process(delta: float):
	elapsed += delta
	_update_bg_sway()
	_try_spawn_bat(delta)
	_update_bats(delta)
	_update_fireflies()
	_update_runes(delta)
	_update_fogs()

func _update_bg_sway():
	var wave_x := sin(elapsed * sway_speed_x) * sway_amount_x
	var wave_y := sin(elapsed * sway_speed_y * 0.7) * sway_amount_y
	bg_sprite.position.x = bg_origin.x + wave_x
	bg_sprite.position.y = bg_origin.y + wave_y

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

func _spawn_rune():
	var lbl := Label.new()
	lbl.text = rune_symbols[randi() % rune_symbols.size()]
	var font_size := randi_range(20, 40)
	lbl.add_theme_font_size_override("font_size", font_size)
	lbl.add_theme_color_override("font_color", rune_color)
	lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
	lbl.modulate.a = 0.0
	lbl.z_index = 4
	var pos_x := randf_range(40.0, VIEWPORT_WIDTH - 40.0)
	var pos_y := randf_range(200.0, VIEWPORT_HEIGHT + 200.0)
	lbl.position = Vector2(pos_x, pos_y)
	add_child(lbl)
	runes.append({
		node = lbl,
		speed = randf_range(rune_speed_min, rune_speed_max),
		phase = randf() * TAU,
		drift_x = randf_range(15.0, 35.0),
		pulse_speed = randf_range(0.8, 1.5),
		origin_x = pos_x,
	})

func _update_runes(delta: float):
	for rune in runes:
		var lbl: Label = rune.node
		lbl.position.y -= float(rune.speed) * delta
		var phase := float(rune.phase)
		lbl.position.x = float(rune.origin_x) + sin(elapsed * 0.3 + phase) * float(rune.drift_x)
		var pulse := sin(elapsed * float(rune.pulse_speed) + phase)
		lbl.modulate.a = clampf(pulse * 0.05 + 0.1, 0.05, 0.15)
		if lbl.position.y < -60.0:
			lbl.position.y = VIEWPORT_HEIGHT + randf_range(20, 100)
			rune.origin_x = randf_range(40.0, VIEWPORT_WIDTH - 40.0)

func _spawn_fog():
	var spr := Sprite2D.new()
	var img := Image.create(128, 128, false, Image.FORMAT_RGBA8)
	var center := 63.5
	for py in 128:
		for px in 128:
			var dx := float(px) - center
			var dy := float(py) - center
			var dist := sqrt(dx * dx + dy * dy)
			var alpha := maxf(0.0, 1.0 - dist / 64.0)
			alpha = alpha * alpha
			img.set_pixel(px, py, Color(1, 1, 1, alpha))
	spr.texture = ImageTexture.create_from_image(img)
	var fog_scale := randf_range(20.0, 30.0)
	spr.scale = Vector2(fog_scale, fog_scale * 0.6)
	spr.position = Vector2(randf_range(-200.0, VIEWPORT_WIDTH + 200.0), randf_range(300.0, VIEWPORT_HEIGHT - 100.0))
	spr.modulate = Color(fog_color.r, fog_color.g, fog_color.b, 0.0)
	spr.z_index = 3
	add_child(spr)
	fogs.append({
		node = spr,
		speed = randf_range(8.0, 18.0),
		phase = randf() * TAU,
		origin_y = spr.position.y,
		pulse_speed = randf_range(0.3, 0.6),
	})

func _update_fogs():
	for fog in fogs:
		var spr: Sprite2D = fog.node
		spr.position.x += float(fog.speed) * get_process_delta_time()
		spr.position.y = float(fog.origin_y) + sin(elapsed * 0.15 + float(fog.phase)) * 20.0
		var pulse := sin(elapsed * float(fog.pulse_speed) + float(fog.phase))
		spr.modulate.a = clampf(pulse * 0.025 + 0.055, 0.03, 0.08)
		if spr.position.x > VIEWPORT_WIDTH + 400.0:
			spr.position.x = -400.0
			fog.origin_y = randf_range(300.0, VIEWPORT_HEIGHT - 100.0)
