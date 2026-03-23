extends CanvasLayer

const BatSheet := preload("res://assets/sprites/v2/enemies/bat_sprite.png")
const BAT_FRAME_SIZE := 32
const VIEWPORT_WIDTH := 750.0

var particles: Array[Dictionary] = []
var bats: Array[Dictionary] = []
var bat_frames: Array[AtlasTexture] = []
var bat_spawn_timer := 0.0
var elapsed := 0.0

func _ready():
	layer = -1
	for row in 3:
		for col in 2:
			var atlas := AtlasTexture.new()
			atlas.atlas = BatSheet
			atlas.region = Rect2(col * BAT_FRAME_SIZE, row * BAT_FRAME_SIZE, BAT_FRAME_SIZE, BAT_FRAME_SIZE)
			bat_frames.append(atlas)
	for i in 20:
		_spawn_particle()

func _spawn_particle():
	var sprite := Sprite2D.new()
	var img := Image.create(4, 4, false, Image.FORMAT_RGBA8)
	for pixel_y in 4:
		for pixel_x in 4:
			var dx := float(pixel_x) - 1.5
			var dy := float(pixel_y) - 1.5
			var dist := sqrt(dx * dx + dy * dy)
			var alpha := maxf(0.0, 1.0 - dist / 2.0)
			img.set_pixel(pixel_x, pixel_y, Color(1, 1, 1, alpha))
	sprite.texture = ImageTexture.create_from_image(img)

	var particle_scale := randf_range(0.5, 2.0)
	sprite.scale = Vector2(particle_scale, particle_scale)
	var pos_x := randf_range(20.0, 730.0)
	var pos_y := randf_range(20.0, 1314.0)
	sprite.position = Vector2(pos_x, pos_y)

	var is_warm := randf() > 0.5
	if is_warm:
		sprite.modulate = Color(1.0, 0.7, 0.3, 0.0)
	else:
		sprite.modulate = Color(0.5, 0.4, 0.8, 0.0)

	add_child(sprite)
	particles.append({
		node = sprite,
		origin_x = pos_x,
		origin_y = pos_y,
		drift_x = randf_range(10.0, 30.0),
		drift_y = randf_range(-20.0, -5.0),
		phase = randf() * TAU,
		pulse_speed = randf_range(0.8, 2.0),
		move_speed = randf_range(0.15, 0.4),
	})

func _spawn_bat():
	var sprite := Sprite2D.new()
	sprite.texture = bat_frames[0]
	sprite.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	var bat_scale := randf_range(1.5, 3.0)
	var alpha := randf_range(0.2, 0.45)
	var speed := randf_range(40.0, 90.0)
	sprite.scale = Vector2(bat_scale, bat_scale)
	var from_left := randf() > 0.5
	var start_x: float = -80.0 if from_left else VIEWPORT_WIDTH + 80.0
	var start_y := randf_range(50.0, 600.0)
	if not from_left:
		speed = -speed
		sprite.flip_h = true
	sprite.position = Vector2(start_x, start_y)
	sprite.modulate = Color(0.12, 0.06, 0.18, alpha)
	sprite.z_index = 4
	add_child(sprite)
	bats.append({
		node = sprite, speed = speed, base_y = start_y,
		wave_amplitude = randf_range(15.0, 40.0),
		wave_frequency = randf_range(3.0, 5.0),
		anim_time = randf() * TAU,
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
		sprite.position.y = float(bat.base_y) + wave * float(bat.wave_amplitude)
		var frame_index := int(anim_t * 8.0) % bat_frames.size()
		sprite.texture = bat_frames[frame_index]
		sprite.rotation = wave * 0.15
		if sprite.position.x < -120.0 or sprite.position.x > VIEWPORT_WIDTH + 120.0:
			to_remove.append(i)
	for i in range(to_remove.size() - 1, -1, -1):
		var idx: int = to_remove[i]
		bats[idx].node.queue_free()
		bats.remove_at(idx)

func _process(delta: float):
	elapsed += delta
	bat_spawn_timer += delta
	if bat_spawn_timer > 6.0 + randf() * 8.0:
		bat_spawn_timer = 0.0
		if bats.size() < 3:
			_spawn_bat()
	_update_bats(delta)
	_update_particles()

func _update_particles():
	for particle in particles:
		var sprite: Sprite2D = particle.node
		var move_t := elapsed * float(particle.move_speed)
		var phase := float(particle.phase)
		sprite.position.x = float(particle.origin_x) + sin(move_t + phase) * float(particle.drift_x)
		sprite.position.y = float(particle.origin_y) + elapsed * float(particle.drift_y)
		if sprite.position.y < -20.0:
			particle.origin_y = 1350.0
			particle.origin_x = randf_range(20.0, 730.0)
		var pulse := sin(elapsed * float(particle.pulse_speed) + phase)
		sprite.modulate.a = maxf(0.0, pulse * 0.3 + 0.15)
