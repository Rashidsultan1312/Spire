class_name GameManagerClass
extends Node

enum State { MENU, PLAYING, GAME_OVER, VICTORY }
enum Difficulty { EASY, NORMAL, HARD }

var state := State.MENU
var current_level := 0
var score := 0
var high_score := 0
var wallet := 0
var current_world := 0
var worlds_unlocked := 1
var difficulty := Difficulty.NORMAL
var items := { "hint": 0, "shield": 0, "luck": 0 }
var stars := [[0,0,0], [0,0,0], [0,0,0], [0,0,0], [0,0,0], [0,0,0], [0,0,0], [0,0,0], [0,0,0], [0,0,0]]
var sfx_volume := 1.0
var music_volume := 1.0
var tutorial_seen := false

signal state_changed(new_state: State)
signal score_changed(new_score: int)

const COLORS = {
	stone = Color("#2d2d3f"),
	stone_light = Color("#3d3d5c"),
	gold = Color("#ffd700"),
	red = Color("#e63946"),
	green = Color("#2a9d8f"),
	cream = Color("#f1faee"),
	cloak = Color("#1d3557"),
	bg_dark = Color("#1a1a2e"),
	bg_mid = Color("#16213e"),
	outline = Color("#0d0d0d"),
}

const ITEM_PRICES := { "hint": 80, "shield": 120, "luck": 100 }
const WORLD_COUNT := 10
const DIFFICULTY_NAMES := ["EASY", "NORMAL", "HARD"]
const DIFFICULTY_TRAP_BONUS := [0, 0, 1]
const DIFFICULTY_REWARD_MULT := [0.7, 1.0, 1.5]

var WORLD_NAMES: Array:
	get: return WorldThemes.WORLD_NAMES
var WORLD_DESCRIPTIONS: Array:
	get: return WorldThemes.WORLD_DESCRIPTIONS
var WORLD_REWARD_MULT: Array:
	get: return WorldThemes.WORLD_REWARD_MULT

var _fade_layer: CanvasLayer
var _fade_rect: ColorRect

const SAVE_PATH := "user://save.cfg"

func _ready():
	_load_data()
	_fade_layer = CanvasLayer.new()
	_fade_layer.layer = 100
	add_child(_fade_layer)
	_fade_rect = ColorRect.new()
	_fade_rect.color = Color(0, 0, 0, 0)
	_fade_rect.anchors_preset = Control.PRESET_FULL_RECT
	_fade_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_fade_layer.add_child(_fade_rect)

func _load_data():
	var cfg := ConfigFile.new()
	if cfg.load(SAVE_PATH) != OK:
		return
	high_score = cfg.get_value("game", "high_score", 0)
	wallet = cfg.get_value("game", "wallet", 0)
	current_world = cfg.get_value("game", "current_world", 0)
	worlds_unlocked = cfg.get_value("game", "worlds_unlocked", 1)
	difficulty = cfg.get_value("game", "difficulty", Difficulty.NORMAL) as Difficulty
	sfx_volume = cfg.get_value("settings", "sfx_volume", 1.0)
	music_volume = cfg.get_value("settings", "music_volume", 1.0)
	tutorial_seen = cfg.get_value("game", "tutorial_seen", false)
	items["hint"] = cfg.get_value("items", "hint", 0)
	items["shield"] = cfg.get_value("items", "shield", 0)
	items["luck"] = cfg.get_value("items", "luck", 0)
	while stars.size() < WORLD_COUNT:
		stars.append([0, 0, 0])
	for w in WORLD_COUNT:
		for d in 3:
			stars[w][d] = cfg.get_value("stars", "w%d_d%d" % [w, d], 0)

func save_data():
	var cfg := ConfigFile.new()
	cfg.set_value("game", "high_score", high_score)
	cfg.set_value("game", "wallet", wallet)
	cfg.set_value("game", "current_world", current_world)
	cfg.set_value("game", "worlds_unlocked", worlds_unlocked)
	cfg.set_value("game", "difficulty", difficulty)
	cfg.set_value("settings", "sfx_volume", sfx_volume)
	cfg.set_value("settings", "music_volume", music_volume)
	cfg.set_value("game", "tutorial_seen", tutorial_seen)
	cfg.set_value("items", "hint", items["hint"])
	cfg.set_value("items", "shield", items["shield"])
	cfg.set_value("items", "luck", items["luck"])
	for w in WORLD_COUNT:
		for d in 3:
			cfg.set_value("stars", "w%d_d%d" % [w, d], stars[w][d])
	cfg.save(SAVE_PATH)

func safe_count(level: int, total: int = 3) -> int:
	var ratio := WorldThemes.safe_ratio(current_world, level)
	var base := maxi(1, int(float(total) * ratio))
	base -= DIFFICULTY_TRAP_BONUS[difficulty]
	return maxi(base, 1)

func trap_count(level: int, total: int = 3) -> int:
	return total - safe_count(level, total)

func reward(level: int) -> int:
	var base := int(5 * pow(1.5, level - 1))
	var world_mult: float = WorldThemes.WORLD_REWARD_MULT[clampi(current_world, 0, 9)]
	var diff_mult: float = DIFFICULTY_REWARD_MULT[clampi(int(difficulty), 0, 2)]
	return maxi(1, int(base * world_mult * diff_mult))

func cumulative_reward(level: int) -> int:
	var total := 0
	for i in range(1, level + 1):
		total += reward(i)
	return total

func spend(amount: int) -> bool:
	if wallet < amount:
		return false
	wallet -= amount
	save_data()
	return true

func buy_item(item_id: String) -> bool:
	if not ITEM_PRICES.has(item_id):
		return false
	if not spend(ITEM_PRICES[item_id]):
		return false
	items[item_id] += 1
	save_data()
	return true

func use_item(item_id: String) -> bool:
	if items[item_id] <= 0:
		return false
	items[item_id] -= 1
	save_data()
	return true

func _add_to_wallet(amount: int):
	wallet += amount
	save_data()

func try_unlock_next_world() -> bool:
	if current_world >= worlds_unlocked - 1 and worlds_unlocked < WORLD_COUNT:
		worlds_unlocked += 1
		save_data()
		return true
	return false

func get_stars(w: int, d: int) -> int:
	return stars[w][d]

func current_stars() -> int:
	return stars[current_world][int(difficulty)]

func best_stars(w: int) -> int:
	return maxi(stars[w][0], maxi(stars[w][1], stars[w][2]))

func _calc_stars(level: int) -> int:
	var total := WorldThemes.max_floors(current_world)
	if level >= total:
		return 3
	@warning_ignore("integer_division")
	if level >= total / 2:
		return 2
	if level >= 1:
		return 1
	return 0

func has_max_stars() -> bool:
	return current_stars() >= 3

func cash_out():
	var earned_stars := _calc_stars(current_level)
	var old_stars := current_stars()
	if earned_stars > old_stars:
		stars[current_world][int(difficulty)] = earned_stars
	if old_stars < 3:
		_add_to_wallet(score)
		if score > high_score:
			high_score = score
	save_data()
	state = State.VICTORY
	state_changed.emit(state)

func game_over() -> int:
	var penalty := mini(wallet, int(wallet * 0.2) + 10)
	wallet -= penalty
	save_data()
	state = State.GAME_OVER
	state_changed.emit(state)
	return penalty

func victory():
	var old_stars := current_stars()
	stars[current_world][int(difficulty)] = 3
	if old_stars < 3:
		_add_to_wallet(score)
		if score > high_score:
			high_score = score
	try_unlock_next_world()
	save_data()
	state = State.VICTORY
	state_changed.emit(state)

func _fade_to_black() -> Signal:
	_fade_rect.mouse_filter = Control.MOUSE_FILTER_STOP
	var tw := create_tween()
	tw.tween_property(_fade_rect, "color:a", 1.0, 0.3)
	return tw.finished

func _fade_from_black():
	var tw := create_tween()
	tw.tween_property(_fade_rect, "color:a", 0.0, 0.3)
	tw.tween_callback(func(): _fade_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE)

func _change_scene(path: String):
	await _fade_to_black()
	get_tree().change_scene_to_file(path)
	_fade_from_black()

func start_game():
	current_level = 0
	score = 0
	state = State.PLAYING
	state_changed.emit(state)
	score_changed.emit(score)
	_change_scene("res://scenes/game.tscn")

func start_next_world():
	if current_world + 1 < WORLD_COUNT and current_world + 1 < worlds_unlocked:
		current_world += 1
		save_data()
	start_game()

func start_prev_world():
	if current_world > 0:
		current_world -= 1
		save_data()
	start_game()

func complete_level(bonus: int = 0):
	current_level += 1
	score = cumulative_reward(current_level) + bonus
	score_changed.emit(score)

func go_to_menu():
	state = State.MENU
	state_changed.emit(state)
	SoundManager.play_menu_music()
	_change_scene("res://scenes/main_menu.tscn")

static func make_soft_circle(size: int = 32) -> ImageTexture:
	var img := Image.create(size, size, false, Image.FORMAT_RGBA8)
	var center := float(size) / 2.0
	var radius := center
	for py in size:
		for px in size:
			var offset_x := float(px) - center + 0.5
			var offset_y := float(py) - center + 0.5
			var dist := sqrt(offset_x * offset_x + offset_y * offset_y)
			var alpha := clampf(1.0 - dist / radius, 0.0, 1.0)
			alpha = alpha * alpha
			img.set_pixel(px, py, Color(1, 1, 1, alpha))
	return ImageTexture.create_from_image(img)

static func stars_text(count: int) -> String:
	var result := ""
	for i in 3:
		result += "★ " if i < count else "☆ "
	return result.strip_edges()
