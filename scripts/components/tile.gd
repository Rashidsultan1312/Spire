extends Area2D

signal tile_tapped(tile: Area2D)
enum TileType { TREASURE, TRAP_SPIKES, TRAP_ROCK, TRAP_GUARD, EMPTY, NPC_HINT }

var tile_type := TileType.TREASURE
var revealed := false
var locked := false
var has_key := false
@onready var visual: Sprite2D = $TileVisual

func _ready():
	input_event.connect(_on_input_event)

func _on_input_event(_viewport: Node, event: InputEvent, _shape_idx: int):
	if locked or revealed:
		return
	if event is InputEventMouseButton and event.pressed:
		tile_tapped.emit(self)

func reveal() -> Tween:
	if revealed:
		return null
	revealed = true
	locked = true

	var face: int
	match tile_type:
		TileType.TREASURE:
			face = 1
		TileType.TRAP_SPIKES:
			face = 2
		TileType.TRAP_ROCK:
			face = 3
		TileType.TRAP_GUARD:
			face = 4
		TileType.EMPTY:
			face = 5
		TileType.NPC_HINT:
			face = 6

	SoundManager.play("tile_flip")
	var tw := create_tween()
	tw.tween_property(visual, "scale:x", 0.0, 0.15).set_ease(Tween.EASE_IN)
	tw.tween_callback(func():
		if is_empty():
			visual.modulate.a = 0.0
		else:
			visual.set_face(face)
		_target_sx = visual.scale.x
		visual.scale.x = 0.0)
	tw.tween_method(_set_visual_sx, 0.0, 1.0, 0.15).set_ease(Tween.EASE_OUT)
	tw.tween_callback(func():
		if is_safe():
			SoundManager.play("tile_safe")
			_pulse_safe()
		elif is_npc():
			_pulse_safe()
		else:
			if not is_empty():
				SoundManager.play("tile_trap")
				_shake_trap())
	return tw

var _target_sx := 1.25

func _set_visual_sx(t: float):
	visual.scale.x = _target_sx * t

func _pulse_safe():
	var base_scale := visual.scale
	var tw := create_tween()
	tw.tween_property(visual, "scale", base_scale * 1.15, 0.12).set_ease(Tween.EASE_OUT)
	tw.tween_property(visual, "scale", base_scale, 0.15).set_ease(Tween.EASE_IN)

func _shake_trap():
	var base_x := visual.position.x
	var tw := create_tween()
	for i in 4:
		var offset := 6.0 if i % 2 == 0 else -6.0
		tw.tween_property(visual, "position:x", base_x + offset, 0.04)
	tw.tween_property(visual, "position:x", base_x, 0.04)

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
	var face: int
	match tile_type:
		TileType.TREASURE: face = 1
		TileType.TRAP_SPIKES: face = 2
		TileType.TRAP_ROCK: face = 3
		TileType.TRAP_GUARD: face = 4
		TileType.EMPTY: face = 5
		TileType.NPC_HINT: face = 6
	visual.set_face(face)

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
