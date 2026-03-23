extends Control

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

@onready var _toggle_btn: Button = $ToggleBtn
@onready var _panel: PanelContainer = $Panel
@onready var _fps_label: Label = $Panel/Scroll/VBox/FPSLabel
@onready var _state_label: Label = $Panel/Scroll/VBox/StateLabel
@onready var _wallet_label: Label = $Panel/Scroll/VBox/WalletLabel
@onready var _combo_label: Label = $Panel/Scroll/VBox/ComboLabel
@onready var _tile_info_label: Label = $Panel/Scroll/VBox/TileInfoLabel

func _ready():
	_toggle_btn.pressed.connect(_toggle_panel)
	_panel.visible = DebugManager.panel_open
	_toggle_btn.text = "X" if _panel.visible else "ДЕБАГ"

	var traps_cb: CheckBox = $Panel/Scroll/VBox/ShowTraps
	var keys_cb: CheckBox = $Panel/Scroll/VBox/ShowKeys
	var npc_cb: CheckBox = $Panel/Scroll/VBox/ShowNPC
	var god_cb: CheckBox = $Panel/Scroll/VBox/GodMode
	traps_cb.button_pressed = DebugManager.show_traps
	keys_cb.button_pressed = DebugManager.show_keys
	npc_cb.button_pressed = DebugManager.show_npc
	god_cb.button_pressed = DebugManager.god_mode
	show_traps = DebugManager.show_traps
	show_keys = DebugManager.show_keys
	show_npc = DebugManager.show_npc
	god_mode = DebugManager.god_mode
	if show_traps:
		traps_toggled.emit(true)
	if show_keys:
		keys_toggled.emit(true)
	if show_npc:
		npc_toggled.emit(true)
	if god_mode:
		god_mode_toggled.emit(true)

	traps_cb.toggled.connect(func(v: bool):
		show_traps = v
		traps_toggled.emit(v))
	keys_cb.toggled.connect(func(v: bool):
		show_keys = v
		keys_toggled.emit(v))
	npc_cb.toggled.connect(func(v: bool):
		show_npc = v
		npc_toggled.emit(v))
	god_cb.toggled.connect(func(v: bool):
		god_mode = v
		god_mode_toggled.emit(v))

	$Panel/Scroll/VBox/SkipBtn.pressed.connect(func(): skip_requested.emit())
	$Panel/Scroll/VBox/WinBtn.pressed.connect(func(): win_requested.emit())

	$Panel/Scroll/VBox/EventRow1/EvDark.pressed.connect(func(): force_event_requested.emit("cursed"))
	$Panel/Scroll/VBox/EventRow1/EvDouble.pressed.connect(func(): force_event_requested.emit("double_loot"))
	$Panel/Scroll/VBox/EventRow1/EvShaky.pressed.connect(func(): force_event_requested.emit("shaky_floor"))
	$Panel/Scroll/VBox/EventRow1/EvBless.pressed.connect(func(): force_event_requested.emit("blessing"))
	$Panel/Scroll/VBox/EventRow1/EvNPC.pressed.connect(func(): force_npc_requested.emit())

	$Panel/Scroll/VBox/ComboRow/Combo3.pressed.connect(func(): set_combo_requested.emit(3))
	$Panel/Scroll/VBox/ComboRow/Combo5.pressed.connect(func(): set_combo_requested.emit(5))
	$Panel/Scroll/VBox/ComboRow/Combo7.pressed.connect(func(): set_combo_requested.emit(7))
	$Panel/Scroll/VBox/ComboRow/Combo0.pressed.connect(func(): set_combo_requested.emit(0))

	$Panel/Scroll/VBox/MoneyRow/Add100.pressed.connect(func(): _add_money(100))
	$Panel/Scroll/VBox/MoneyRow/Add500.pressed.connect(func(): _add_money(500))
	$Panel/Scroll/VBox/MoneyRow/Add1000.pressed.connect(func(): _add_money(1000))
	$Panel/Scroll/VBox/MoneyRow/Add9999.pressed.connect(func(): _add_money(9999))
	$Panel/Scroll/VBox/ResetWallet.pressed.connect(func():
		GameManager.wallet = 0
		GameManager.save_data())
	$Panel/Scroll/VBox/PotionRow/AddHint.pressed.connect(func(): _add_potion("hint"))
	$Panel/Scroll/VBox/PotionRow/AddShield.pressed.connect(func(): _add_potion("shield"))
	$Panel/Scroll/VBox/PotionRow/AddLuck.pressed.connect(func(): _add_potion("luck"))
	$Panel/Scroll/VBox/UnlockWorlds.pressed.connect(func():
		GameManager.worlds_unlocked = GameManager.WORLD_COUNT
		GameManager.save_data())
	$Panel/Scroll/VBox/AllStars.pressed.connect(func():
		for w in GameManager.WORLD_COUNT:
			for d in 3:
				GameManager.stars[w][d] = 3
		GameManager.save_data())
	$Panel/Scroll/VBox/ResetSave.pressed.connect(func():
		DirAccess.remove_absolute("user://save.cfg")
		GameManager.wallet = 0
		GameManager.high_score = 0
		GameManager.worlds_unlocked = 1
		GameManager.current_world = 0
		GameManager.tutorial_seen = false
		GameManager.items = {"hint": 0, "shield": 0, "luck": 0}
		var empty_stars: Array = []
		for w in GameManager.WORLD_COUNT:
			empty_stars.append([0, 0, 0])
		GameManager.stars = empty_stars
		GameManager.save_data())
	$Panel/Scroll/VBox/ResetTutorial.pressed.connect(func():
		GameManager.tutorial_seen = false
		GameManager.save_data())
	$Panel/Scroll/VBox/WebViewBtn.pressed.connect(func():
		OS.shell_open("https://dddvvv.itch.io/spire"))
	$Panel/Scroll/VBox/GoMenu.pressed.connect(func(): GameManager.go_to_menu())

func _process(_delta: float):
	_fps_label.text = "FPS: %d" % Engine.get_frames_per_second()
	var scene_name := ""
	var current := get_tree().current_scene
	if current:
		scene_name = current.name
	_state_label.text = "Сцена: %s | Этаж: %d | Счёт: %d" % [
		scene_name, GameManager.current_level, GameManager.score]
	_wallet_label.text = "Кошелёк: %d | %s | %s" % [
		GameManager.wallet,
		WorldThemes.WORLD_NAMES[GameManager.current_world],
		GameManager.DIFFICULTY_NAMES[GameManager.difficulty]]

	var game_node = get_tree().current_scene
	if game_node and game_node.has_method("_get_debug_info"):
		var info: Dictionary = game_node._get_debug_info()
		_combo_label.text = "Комбо: %d | Ключи: %d | Бонус: %d" % [
			info.get("combo", 0), info.get("keys", 0), info.get("bonus", 0)]
		var tc: int = info.get("tile_count", 0)
		var safe: int = info.get("safe_count", 0)
		var trap: int = info.get("trap_count", 0)
		var key_count: int = info.get("key_count", 0)
		var ev: String = info.get("event", "")
		var empty: int = info.get("empty_count", 0)
		var npc: int = info.get("npc_count", 0)
		_tile_info_label.text = "Тайлы: %d (S:%d T:%d E:%d N:%d K:%d) Ив: %s" % [tc, safe, trap, empty, npc, key_count, ev if ev != "" else "нет"]
	else:
		_combo_label.text = "Комбо: - | Ключи: -"
		_tile_info_label.text = "Тайлы: -"

func _add_money(amount: int):
	GameManager.wallet += amount
	GameManager.save_data()

func _add_potion(id: String):
	GameManager.items[id] += 3
	GameManager.save_data()

func _toggle_panel():
	_panel.visible = not _panel.visible
	_toggle_btn.text = "X" if _panel.visible else "ДЕБАГ"
	DebugManager.panel_open = _panel.visible
