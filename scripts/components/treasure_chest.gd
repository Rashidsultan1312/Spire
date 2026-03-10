extends Node2D

@export var closed_tex: Texture2D
@export var open_tex: Texture2D

@onready var visual: Sprite2D = $ChestVisual

func open() -> Tween:
	var tw := create_tween()
	tw.tween_property(visual, "scale", Vector2(7.5, 4.5), 0.1)
	tw.tween_callback(func(): visual.texture = open_tex)
	tw.tween_property(visual, "scale", Vector2(8, 8), 0.3).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_BACK)
	tw.tween_property(visual, "scale", Vector2(6, 6), 0.2)
	return tw
