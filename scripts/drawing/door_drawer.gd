extends Sprite2D

enum Face { HIDDEN, TREASURE, TRAP_SPIKES, TRAP_ROCK, TRAP_GUARD, EMPTY, NPC_HINT }

const DOOR_SHEET := preload("res://assets/sprites/v3/room/door_sheet.png")
const SHEET_COLS := 3
const SHEET_ROWS := 3
const FRAME_W := 512.0
const FRAME_H := 512.0

@export var hidden_tex: Texture2D
@export var trap_spikes_tex: Texture2D
@export var trap_rock_tex: Texture2D
@export var trap_guard_tex: Texture2D
@export var npc_tex: Texture2D

const TARGET_SIZE := 260.0
const GUARD_SIZE := 320.0
var face := Face.HIDDEN
var _door_atlas: AtlasTexture

func _ready():
	_door_atlas = AtlasTexture.new()
	_door_atlas.atlas = DOOR_SHEET
	_set_door_frame(0)
	hidden_tex = _door_atlas
	texture = hidden_tex
	_fit_scale()

func _set_door_frame(idx: int):
	var col: int = idx % SHEET_COLS
	var row: int = idx / SHEET_COLS
	_door_atlas.region = Rect2(col * FRAME_W, row * FRAME_H, FRAME_W, FRAME_H)

func set_face(new_face: int):
	face = new_face as Face
	stop_spritesheet_anim()
	match face:
		Face.TREASURE, Face.EMPTY, Face.NPC_HINT:
			texture = _door_atlas
			_set_door_frame(8)
		Face.TRAP_SPIKES:
			texture = trap_spikes_tex
		Face.TRAP_ROCK:
			texture = trap_rock_tex
		Face.TRAP_GUARD:
			texture = trap_guard_tex
		_:
			texture = _door_atlas
			_set_door_frame(0)
	_fit_scale()
	if texture is AtlasTexture and texture != _door_atlas:
		match face:
			Face.TRAP_GUARD:
				start_spritesheet_anim(4, 4, 8.0)
			Face.TRAP_SPIKES:
				start_spritesheet_anim(3, 3, 10.0)
			Face.TRAP_ROCK:
				start_spritesheet_anim(3, 3, 10.0)

func play_open_anim() -> Tween:
	texture = _door_atlas
	_set_door_frame(0)
	_fit_scale()
	var frame := [0]
	var tw := create_tween()
	for i in range(1, 9):
		tw.tween_callback(func():
			frame[0] += 1
			_set_door_frame(frame[0]))
		tw.tween_interval(0.04)
	return tw

func play_close_anim() -> Tween:
	texture = _door_atlas
	_set_door_frame(8)
	_fit_scale()
	var frame := [8]
	var tw := create_tween()
	for i in range(7, -1, -1):
		tw.tween_callback(func():
			frame[0] -= 1
			_set_door_frame(frame[0]))
		tw.tween_interval(0.03)
	tw.tween_callback(func():
		face = Face.HIDDEN
		texture = hidden_tex if hidden_tex else _door_atlas
		_fit_scale())
	return tw

func apply_theme(theme: Dictionary):
	if not _door_atlas:
		_door_atlas = AtlasTexture.new()
		_door_atlas.atlas = DOOR_SHEET
		_set_door_frame(0)
	hidden_tex = _door_atlas
	var gnome_atlas := AtlasTexture.new()
	gnome_atlas.atlas = load("res://assets/sprites/v3/characters/gnome_sheet.png")
	gnome_atlas.region = Rect2(0, 0, 256, 256)
	npc_tex = gnome_atlas
	var wraith_atlas := AtlasTexture.new()
	wraith_atlas.atlas = load("res://assets/sprites/v3/traps/wraith_sheet.png")
	wraith_atlas.region = Rect2(0, 0, 256, 256)
	trap_guard_tex = wraith_atlas
	var spikes_atlas := AtlasTexture.new()
	spikes_atlas.atlas = load("res://assets/sprites/v3/traps/spikes_sheet.png")
	spikes_atlas.region = Rect2(0, 0, 256, 256)
	trap_spikes_tex = spikes_atlas
	var boulder_atlas := AtlasTexture.new()
	boulder_atlas.atlas = load("res://assets/sprites/v3/traps/boulder_sheet.png")
	boulder_atlas.region = Rect2(0, 0, 256, 256)
	trap_rock_tex = boulder_atlas
	if face == Face.HIDDEN:
		texture = hidden_tex
		_set_door_frame(0)
		_fit_scale()

var _anim_timer: Timer

func start_spritesheet_anim(cols: int = 4, rows: int = 4, fps: float = 8.0):
	if _anim_timer:
		return
	if not texture is AtlasTexture:
		return
	if texture == _door_atlas:
		return
	var frame_count := cols * rows
	var frame_w: float = (texture as AtlasTexture).atlas.get_width() / float(cols)
	var frame_h: float = (texture as AtlasTexture).atlas.get_height() / float(rows)
	var idx := [0]
	_anim_timer = Timer.new()
	_anim_timer.wait_time = 1.0 / fps
	_anim_timer.autostart = true
	add_child(_anim_timer)
	_anim_timer.timeout.connect(func():
		idx[0] = (idx[0] + 1) % frame_count
		var col: int = idx[0] % cols
		var row: int = idx[0] / cols
		(texture as AtlasTexture).region = Rect2(col * frame_w, row * frame_h, frame_w, frame_h)
	)

func stop_spritesheet_anim():
	if _anim_timer:
		_anim_timer.stop()
		_anim_timer.queue_free()
		_anim_timer = null

func _fit_scale():
	if not texture:
		return
	var tex_size := texture.get_size()
	var max_dim := maxf(tex_size.x, tex_size.y)
	if max_dim <= 0:
		return
	var target := GUARD_SIZE if face == Face.TRAP_GUARD else TARGET_SIZE
	var fit_scale := target / max_dim
	scale = Vector2(fit_scale, fit_scale)
