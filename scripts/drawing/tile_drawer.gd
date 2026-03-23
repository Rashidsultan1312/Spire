extends Sprite2D

enum Face { HIDDEN, TREASURE, TRAP_SPIKES, TRAP_ROCK, TRAP_GUARD, EMPTY, NPC_HINT }

@export var hidden_tex: Texture2D
@export var safe_tex: Texture2D
@export var trap_spikes_tex: Texture2D
@export var trap_rock_tex: Texture2D
@export var trap_guard_tex: Texture2D
@export var npc_tex: Texture2D

const TARGET_SIZE := 160.0
const GUARD_SIZE := 240.0
var face := Face.HIDDEN

func set_face(new_face: int):
	face = new_face as Face
	stop_spritesheet_anim()
	match face:
		Face.TREASURE:
			texture = safe_tex
		Face.TRAP_SPIKES:
			texture = trap_spikes_tex
		Face.TRAP_ROCK:
			texture = trap_rock_tex
		Face.TRAP_GUARD:
			texture = trap_guard_tex
		Face.EMPTY:
			texture = safe_tex
		Face.NPC_HINT:
			texture = npc_tex if npc_tex else safe_tex
		_:
			texture = hidden_tex
	_fit_scale()
	if texture is AtlasTexture:
		match face:
			Face.TRAP_GUARD:
				start_spritesheet_anim(4, 4, 8.0)
			Face.TRAP_SPIKES:
				start_spritesheet_anim(3, 3, 10.0)
			Face.TRAP_ROCK:
				start_spritesheet_anim(3, 3, 10.0)

func apply_theme(theme: Dictionary):
	if theme.has("hidden_tex"):
		hidden_tex = load(theme["hidden_tex"])
	if theme.has("safe_tex"):
		safe_tex = load(theme["safe_tex"])
	if theme.has("trap_spikes_tex"):
		trap_spikes_tex = load(theme["trap_spikes_tex"])
	if theme.has("trap_rock_tex"):
		trap_rock_tex = load(theme["trap_rock_tex"])
	if theme.has("trap_guard_tex"):
		trap_guard_tex = load(theme["trap_guard_tex"])
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
		_fit_scale()

var _anim_timer: Timer

func start_spritesheet_anim(cols: int = 4, rows: int = 4, fps: float = 8.0):
	if _anim_timer:
		return
	if not texture is AtlasTexture:
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
	if texture is AtlasTexture:
		(texture as AtlasTexture).region = Rect2(0, 0, 256, 256)

func _fit_scale():
	if not texture:
		return
	var tex_size := texture.get_size()
	var max_dim := maxf(tex_size.x, tex_size.y)
	var target := GUARD_SIZE if face == Face.TRAP_GUARD else TARGET_SIZE
	var fit_scale := target / max_dim
	scale = Vector2(fit_scale, fit_scale)
