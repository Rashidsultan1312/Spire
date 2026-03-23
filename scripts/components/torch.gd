extends Node2D

@onready var glow: Sprite2D = $Glow

var _time := randf() * 10.0
var _base_glow_y: float

func _ready():
	_base_glow_y = glow.position.y

func _process(delta: float):
	_time += delta * 4.5
	var flicker := sin(_time) * 0.5 + 0.5
	var flicker_alt := sin(_time * 1.7 + 2.0) * 0.5 + 0.5
	glow.modulate.a = lerpf(0.6, 0.9, flicker)
	glow.scale.x = lerpf(4.0, 5.0, flicker_alt)
	glow.scale.y = lerpf(3.5, 4.5, flicker)
	glow.position.y = _base_glow_y + sin(_time * 2.3) * 2.0
