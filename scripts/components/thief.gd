extends Node2D

@onready var body: AnimatedSprite2D = $Body
@onready var anim: AnimationPlayer = $AnimPlayer

const BASE_SCALE := Vector2(0.85, 0.85)
const STEP_INTERVAL := 0.28
var shield_aura: Sprite2D
var shield_tween: Tween
var shield_scale_tween: Tween
var _step_timer: Timer

func jump_to(target_pos: Vector2) -> Tween:
	body.play("jump")
	anim.pause()

	var sq_tw := create_tween()
	sq_tw.tween_property(body, "scale", BASE_SCALE * Vector2(1.3, 0.8), 0.08)
	sq_tw.tween_property(body, "scale", BASE_SCALE * Vector2(0.8, 1.4), 0.15)
	sq_tw.tween_property(body, "scale", BASE_SCALE, 0.15)

	var mid_y: float = minf(position.y, target_pos.y) - 80.0

	create_tween().set_parallel(true).tween_property(
		self, "position:x", target_pos.x, 0.45
	).set_ease(Tween.EASE_IN_OUT).set_trans(Tween.TRANS_SINE)

	var tw := create_tween()
	tw.tween_property(self, "position:y", mid_y, 0.22).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_QUAD)
	tw.tween_property(self, "position:y", target_pos.y, 0.23).set_ease(Tween.EASE_IN).set_trans(Tween.TRANS_QUAD)
	tw.tween_property(body, "scale", BASE_SCALE * Vector2(1.3, 0.8), 0.06)
	tw.tween_property(body, "scale", BASE_SCALE, 0.1)
	tw.tween_callback(_to_idle)

	return tw

func fall_down(fall_distance: float) -> Tween:
	body.play("hurt")
	anim.pause()
	var tw := create_tween().set_parallel(true)
	tw.tween_property(self, "position:y", position.y + fall_distance, 0.9).set_ease(Tween.EASE_IN).set_trans(Tween.TRANS_QUAD)
	tw.tween_property(body, "rotation", PI * 3, 0.9).set_ease(Tween.EASE_IN)
	tw.tween_property(body, "modulate:a", 0.0, 0.7).set_delay(0.2)
	return tw

func _to_idle():
	body.flip_h = false
	body.play("idle")
	anim.play("bob")
	_stop_steps()

func _start_steps():
	_stop_steps()
	SoundManager.play("footstep")
	_step_timer = Timer.new()
	_step_timer.wait_time = STEP_INTERVAL
	_step_timer.autostart = true
	add_child(_step_timer)
	_step_timer.timeout.connect(func(): SoundManager.play("footstep"))

func _start_climb_sound():
	_stop_steps()
	SoundManager.play("ladder")
	_step_timer = Timer.new()
	_step_timer.wait_time = 0.25
	_step_timer.autostart = true
	add_child(_step_timer)
	_step_timer.timeout.connect(func(): SoundManager.play("ladder"))

func _stop_steps():
	if _step_timer and is_instance_valid(_step_timer):
		_step_timer.stop()
		_step_timer.queue_free()
		_step_timer = null

func set_shield(on: bool):
	if on:
		var img := Image.create(4, 4, false, Image.FORMAT_RGBA8)
		for y in 4:
			for x in 4:
				var dx := float(x) - 1.5
				var dy := float(y) - 1.5
				var dist := sqrt(dx * dx + dy * dy)
				var a := maxf(0.0, 1.0 - dist / 2.0)
				img.set_pixel(x, y, Color(1, 1, 1, a))
		shield_aura = Sprite2D.new()
		shield_aura.texture = ImageTexture.create_from_image(img)
		shield_aura.scale = Vector2(12, 12)
		shield_aura.modulate = Color(0.3, 0.6, 1.0, 0.25)
		shield_aura.z_index = -1
		add_child(shield_aura)
		shield_tween = create_tween().set_loops()
		shield_tween.tween_property(shield_aura, "modulate:a", 0.35, 0.8)
		shield_tween.tween_property(shield_aura, "modulate:a", 0.15, 0.8)
		shield_scale_tween = create_tween().set_loops()
		shield_scale_tween.tween_property(shield_aura, "scale", Vector2(13, 13), 0.8)
		shield_scale_tween.tween_property(shield_aura, "scale", Vector2(11, 11), 0.8)
	else:
		if shield_tween and shield_tween.is_running():
			shield_tween.kill()
		if shield_scale_tween and shield_scale_tween.is_running():
			shield_scale_tween.kill()
		if shield_aura and is_instance_valid(shield_aura):
			var tw := create_tween().set_parallel(true)
			tw.tween_property(shield_aura, "scale", Vector2(18, 18), 0.2)
			tw.tween_property(shield_aura, "modulate:a", 0.0, 0.2)
			var aura_ref := shield_aura
			tw.chain().tween_callback(aura_ref.queue_free)
			shield_aura = null

func walk_to(target_x: float) -> Tween:
	body.flip_h = target_x < position.x
	body.play("walk")
	anim.pause()
	_start_steps()
	var tw := create_tween()
	var dist := absf(target_x - position.x)
	var dur := clampf(dist / 300.0, 0.4, 1.2)
	tw.tween_property(self, "position:x", target_x, dur).set_ease(Tween.EASE_IN_OUT).set_trans(Tween.TRANS_SINE)
	tw.tween_callback(_to_idle)
	return tw

func walk_back_to(target_x: float) -> Tween:
	body.flip_h = target_x < position.x
	body.play("walk")
	anim.pause()
	_start_steps()
	var tw := create_tween()
	var dist := absf(target_x - position.x)
	var dur := clampf(dist / 300.0, 0.3, 1.0)
	tw.tween_property(self, "position:x", target_x, dur).set_ease(Tween.EASE_IN_OUT).set_trans(Tween.TRANS_SINE)
	tw.tween_callback(_to_idle)
	return tw

func climb_to(target_pos: Vector2) -> Tween:
	body.flip_h = false
	body.play("climb")
	anim.pause()
	_start_climb_sound()
	var dist := position.distance_to(target_pos)
	var dur := clampf(dist / 300.0, 0.3, 0.8)
	var tw := create_tween().set_parallel(true)
	tw.tween_property(self, "position", target_pos, dur).set_ease(Tween.EASE_IN_OUT).set_trans(Tween.TRANS_SINE)
	tw.chain().tween_callback(_to_idle)
	return tw

func victory_bounce():
	var tw := create_tween()
	tw.tween_property(body, "scale", BASE_SCALE * Vector2(1.3, 0.8), 0.1)
	tw.tween_property(body, "scale", BASE_SCALE * Vector2(0.8, 1.4), 0.15).set_trans(Tween.TRANS_BACK)
	tw.tween_property(body, "scale", BASE_SCALE, 0.12)
