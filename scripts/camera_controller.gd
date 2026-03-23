extends Camera2D

var target_y := 0.0
var shake_amount := 0.0
var _shake_decay := 5.0

func _process(delta: float):
	position.y = lerp(position.y, target_y, delta * 5.0)

	if shake_amount > 0:
		offset = Vector2(randf_range(-1, 1), randf_range(-1, 1)) * shake_amount
		shake_amount = lerp(shake_amount, 0.0, delta * _shake_decay)
		if shake_amount < 0.5:
			shake_amount = 0.0
			offset = Vector2.ZERO

func follow(y: float):
	target_y = y - 50.0

func shake(intensity := 15.0):
	shake_amount = intensity
