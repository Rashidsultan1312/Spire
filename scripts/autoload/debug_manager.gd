extends CanvasLayer

signal traps_toggled(enabled: bool)
signal keys_toggled(enabled: bool)
signal npc_toggled(enabled: bool)
signal skip_requested
signal win_requested
signal god_mode_toggled(enabled: bool)
signal force_event_requested(event_name: String)
signal set_combo_requested(value: int)
signal force_npc_requested

var show_traps := false
var show_keys := false
var show_npc := false
var god_mode := false
var panel_open := false
var _panel: Control

const DebugScene := preload("res://scenes/debug_panel.tscn")

func _ready():
	if not OS.is_debug_build():
		queue_free()
		return
	layer = 99
	_panel = DebugScene.instantiate()
	add_child(_panel)
	_panel.traps_toggled.connect(func(v: bool):
		show_traps = v
		traps_toggled.emit(v))
	_panel.keys_toggled.connect(func(v: bool):
		show_keys = v
		keys_toggled.emit(v))
	_panel.npc_toggled.connect(func(v: bool):
		show_npc = v
		npc_toggled.emit(v))
	_panel.skip_requested.connect(func(): skip_requested.emit())
	_panel.win_requested.connect(func(): win_requested.emit())
	_panel.god_mode_toggled.connect(func(v: bool):
		god_mode = v
		god_mode_toggled.emit(v))
	_panel.force_event_requested.connect(func(ev: String): force_event_requested.emit(ev))
	_panel.set_combo_requested.connect(func(v: int): set_combo_requested.emit(v))
	_panel.force_npc_requested.connect(func(): force_npc_requested.emit())
