extends CanvasLayer

signal combat_finished(success: bool)

@onready var bg: ColorRect = $BG
@onready var title_label: Label = $Title
@onready var orb_container: Control = $OrbContainer

var orbs_hit := 0
var orbs_total := 3
var active := false

func _ready():
	visible = false

func start():
	visible = true
	active = true
	orbs_hit = 0
	bg.color = Color(0, 0, 0, 0)
	title_label.text = "TAP THE ORBS!"
	title_label.modulate = Color(1, 1, 1, 0)
	for child in orb_container.get_children():
		child.queue_free()
	var tw := create_tween()
	tw.tween_property(bg, "color:a", 0.7, 0.3)
	tw.parallel().tween_property(title_label, "modulate:a", 1.0, 0.3)
	tw.tween_callback(_spawn_orb_sequence)

func _spawn_orb_sequence():
	for i in orbs_total:
		await get_tree().create_timer(0.5).timeout
		if not active:
			return
		_spawn_orb(i)

func _spawn_orb(idx: int):
	var orb := Button.new()
	orb.custom_minimum_size = Vector2(90, 90)
	orb.flat = true
	orb.mouse_filter = Control.MOUSE_FILTER_STOP
	var pos := Vector2(randf_range(80, 670), randf_range(300, 1000))
	orb.position = pos
	orb.size = Vector2(90, 90)

	var glow := ColorRect.new()
	glow.color = Color(0.6, 0.2, 1.0, 0.8)
	glow.set_anchors_preset(Control.PRESET_FULL_RECT)
	glow.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.6, 0.2, 1.0, 0.8)
	style.set_corner_radius_all(45)
	glow.add_theme_stylebox_override("panel", style)
	orb.add_child(glow)

	orb_container.add_child(orb)

	orb.scale = Vector2(0.3, 0.3)
	orb.pivot_offset = Vector2(45, 45)
	var show_tw := create_tween()
	show_tw.tween_property(orb, "scale", Vector2(1.0, 1.0), 0.2).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_BACK)

	var hit := [false]
	orb.pressed.connect(func():
		if hit[0]:
			return
		hit[0] = true
		orbs_hit += 1
		SoundManager.play("coin")
		SoundManager.vibrate_light()
		var pop := create_tween()
		pop.tween_property(orb, "scale", Vector2(1.3, 1.3), 0.1)
		pop.tween_property(orb, "modulate:a", 0.0, 0.15)
		pop.tween_callback(orb.queue_free)
		title_label.text = "%d / %d" % [orbs_hit, orbs_total]
		if orbs_hit >= orbs_total:
			_finish(true)
	)

	await get_tree().create_timer(1.0).timeout
	if not hit[0] and is_instance_valid(orb):
		hit[0] = true
		var miss_tw := create_tween()
		miss_tw.tween_property(orb, "modulate", Color(1, 0.2, 0.2, 0.5), 0.2)
		miss_tw.tween_property(orb, "modulate:a", 0.0, 0.2)
		miss_tw.tween_callback(orb.queue_free)
		_finish(false)

func _finish(success: bool):
	if not active:
		return
	active = false
	title_label.text = "VICTORY!" if success else "DEFEATED..."
	title_label.add_theme_color_override("font_color", Color(0.3, 1.0, 0.4) if success else Color(1.0, 0.3, 0.3))
	await get_tree().create_timer(0.8).timeout
	var tw := create_tween()
	tw.tween_property(bg, "color:a", 0.0, 0.3)
	tw.parallel().tween_property(title_label, "modulate:a", 0.0, 0.3)
	tw.tween_callback(func(): visible = false; combat_finished.emit(success))
