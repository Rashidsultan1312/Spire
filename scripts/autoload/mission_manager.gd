extends Node

signal mission_completed(id: String, reward: int)
signal achievement_unlocked(id: String, display_name: String, reward: int)

const SAVE_PATH := "user://save.cfg"

const MISSION_POOL := {
	"floors_10": {"desc": "Clear 10 floors", "target": 10, "reward": 30, "stat": "lifetime_floors"},
	"floors_50": {"desc": "Clear 50 floors", "target": 50, "reward": 80, "stat": "lifetime_floors"},
	"floors_200": {"desc": "Clear 200 floors", "target": 200, "reward": 200, "stat": "lifetime_floors"},
	"floors_500": {"desc": "Clear 500 floors", "target": 500, "reward": 400, "stat": "lifetime_floors"},
	"treasure_10": {"desc": "Find 10 treasures", "target": 10, "reward": 25, "stat": "lifetime_treasures"},
	"treasure_50": {"desc": "Find 50 treasures", "target": 50, "reward": 80, "stat": "lifetime_treasures"},
	"treasure_200": {"desc": "Find 200 treasures", "target": 200, "reward": 250, "stat": "lifetime_treasures"},
	"survive_1": {"desc": "Survive a trap with Shield", "target": 1, "reward": 25, "stat": "lifetime_traps_survived"},
	"survive_5": {"desc": "Survive 5 traps with Shield", "target": 5, "reward": 100, "stat": "lifetime_traps_survived"},
	"combo_3": {"desc": "Reach 3x combo", "target": 3, "reward": 30, "stat": "max_combo_ever"},
	"combo_5": {"desc": "Reach 5x combo", "target": 5, "reward": 50, "stat": "max_combo_ever"},
	"combo_7": {"desc": "Reach 7x combo", "target": 7, "reward": 100, "stat": "max_combo_ever"},
	"coins_500": {"desc": "Earn 500 coins total", "target": 500, "reward": 60, "stat": "lifetime_coins"},
	"coins_2000": {"desc": "Earn 2000 coins total", "target": 2000, "reward": 150, "stat": "lifetime_coins"},
	"coins_10000": {"desc": "Earn 10000 coins total", "target": 10000, "reward": 500, "stat": "lifetime_coins"},
	"potions_3": {"desc": "Use 3 potions", "target": 3, "reward": 25, "stat": "lifetime_potions_used"},
	"potions_10": {"desc": "Use 10 potions", "target": 10, "reward": 70, "stat": "lifetime_potions_used"},
	"npc_1": {"desc": "Meet the gnome", "target": 1, "reward": 20, "stat": "lifetime_npc_met"},
	"npc_5": {"desc": "Meet the gnome 5 times", "target": 5, "reward": 80, "stat": "lifetime_npc_met"},
	"games_5": {"desc": "Play 5 games", "target": 5, "reward": 20, "stat": "lifetime_games_played"},
	"games_25": {"desc": "Play 25 games", "target": 25, "reward": 60, "stat": "lifetime_games_played"},
	"games_100": {"desc": "Play 100 games", "target": 100, "reward": 200, "stat": "lifetime_games_played"},
	"stars_10": {"desc": "Earn 10 stars", "target": 10, "reward": 80, "stat": "total_stars"},
	"stars_30": {"desc": "Earn 30 stars", "target": 30, "reward": 200, "stat": "total_stars"},
	"cashout_5": {"desc": "Cash out at floor 5+", "target": 1, "reward": 35, "stat": "cashout_mid"},
	"cashout_8": {"desc": "Cash out at floor 8+", "target": 1, "reward": 70, "stat": "cashout_high"},
	"world_3": {"desc": "Complete 3 different worlds", "target": 3, "reward": 100, "stat": "worlds_completed"},
	"world_5": {"desc": "Complete 5 different worlds", "target": 5, "reward": 200, "stat": "worlds_completed"},
	"hard_clear": {"desc": "Clear any world on HARD", "target": 1, "reward": 120, "stat": "lifetime_hard_clears"},
	"hard_5": {"desc": "Clear 5 worlds on HARD", "target": 5, "reward": 400, "stat": "lifetime_hard_clears"},
}

const ACHIEVEMENTS := {
	"first_game": {"name": "First Steps", "desc": "Play your first game", "target": 1, "reward": 20, "stat": "lifetime_games_played"},
	"games_100": {"name": "Veteran", "desc": "Play 100 games", "target": 100, "reward": 300, "stat": "lifetime_games_played"},
	"unlock_5": {"name": "Explorer", "desc": "Unlock 5 worlds", "target": 5, "reward": 150, "stat": "worlds_unlocked"},
	"unlock_all": {"name": "Cartographer", "desc": "Unlock all worlds", "target": 10, "reward": 500, "stat": "worlds_unlocked"},
	"stars_15": {"name": "Rising Star", "desc": "Earn 15 stars", "target": 15, "reward": 100, "stat": "total_stars"},
	"stars_60": {"name": "Constellation", "desc": "Earn 60 stars", "target": 60, "reward": 400, "stat": "total_stars"},
	"stars_90": {"name": "Perfection", "desc": "Earn 90 stars", "target": 90, "reward": 1000, "stat": "total_stars"},
	"combo_3": {"name": "Lucky Streak", "desc": "Reach 3x combo", "target": 3, "reward": 30, "stat": "max_combo_ever"},
	"combo_7": {"name": "Unstoppable", "desc": "Reach 7x combo", "target": 7, "reward": 200, "stat": "max_combo_ever"},
	"coins_1k": {"name": "Wealthy", "desc": "Earn 1000 coins total", "target": 1000, "reward": 80, "stat": "lifetime_coins"},
	"coins_10k": {"name": "Tycoon", "desc": "Earn 10000 coins total", "target": 10000, "reward": 500, "stat": "lifetime_coins"},
	"survive_1": {"name": "Close Call", "desc": "Survive a trap with Shield", "target": 1, "reward": 30, "stat": "lifetime_traps_survived"},
	"survive_10": {"name": "Iron Will", "desc": "Survive 10 traps", "target": 10, "reward": 150, "stat": "lifetime_traps_survived"},
	"hard_3": {"name": "Hardcore", "desc": "Clear 3 worlds on HARD", "target": 3, "reward": 300, "stat": "lifetime_hard_clears"},
	"full_clear": {"name": "Absolute Legend", "desc": "All 90 stars on HARD", "target": 90, "reward": 2000, "stat": "hard_stars"},
}

const DAILY_REWARDS := [
	{"type": "coins", "amount": 25},
	{"type": "coins", "amount": 40},
	{"type": "item", "amount": 1, "item": "hint"},
	{"type": "coins", "amount": 60},
	{"type": "item", "amount": 1, "item": "shield"},
	{"type": "coins", "amount": 100},
	{"type": "both", "amount": 50, "item": "luck"},
]

var completed_mission_ids: Array[String] = []
var unlocked_achievements: Array[String] = []
var daily_streak := 0
var last_claim_date := ""

var lifetime_coins := 0
var lifetime_floors := 0
var lifetime_treasures := 0
var lifetime_traps_survived := 0
var lifetime_potions_used := 0
var lifetime_npc_met := 0
var lifetime_games_played := 0
var lifetime_hard_clears := 0
var max_combo_ever := 0

var _run_floors := 0
var _run_treasures := 0
var _run_traps_survived := 0
var _run_potions := 0
var _run_npc := 0
var _run_cashout_floor := 0
var _run_cashout_mid := 0

func _ready():
	_load_data()

func on_floor_cleared():
	_run_floors += 1
	lifetime_floors += 1
	_check_missions()
	_save_data()

func on_treasure_found():
	_run_treasures += 1
	lifetime_treasures += 1
	_check_missions()
	_save_data()

func on_trap_survived():
	_run_traps_survived += 1
	lifetime_traps_survived += 1
	_check_missions()
	_save_data()

func on_combo(value: int):
	max_combo_ever = maxi(max_combo_ever, value)
	_check_missions()
	_save_data()

func on_npc_met():
	_run_npc += 1
	lifetime_npc_met += 1
	_check_missions()
	_save_data()

func on_potion_used():
	_run_potions += 1
	lifetime_potions_used += 1
	_check_missions()
	_save_data()

func on_run_end(level: int, _world: int, difficulty: int, coins: int, outcome: String):
	lifetime_games_played += 1
	lifetime_coins += coins
	if outcome == "victory" and difficulty == 2:
		lifetime_hard_clears += 1
	if outcome == "cashout" and level >= 5:
		_run_cashout_mid = level
	if outcome == "cashout" and level >= 8:
		_run_cashout_floor = level
	_check_missions()
	check_achievements()
	_run_floors = 0
	_run_treasures = 0
	_run_traps_survived = 0
	_run_potions = 0
	_run_npc = 0
	_run_cashout_floor = 0
	_run_cashout_mid = 0
	_save_data()

func _get_stat(stat_name: String) -> int:
	match stat_name:
		"lifetime_floors": return lifetime_floors
		"lifetime_treasures": return lifetime_treasures
		"lifetime_traps_survived": return lifetime_traps_survived
		"max_combo_ever": return max_combo_ever
		"lifetime_coins": return lifetime_coins
		"lifetime_potions_used": return lifetime_potions_used
		"lifetime_npc_met": return lifetime_npc_met
		"lifetime_games_played": return lifetime_games_played
		"total_stars": return _count_total_stars()
		"cashout_high": return _run_cashout_floor
		"cashout_mid": return _run_cashout_mid
		"worlds_completed": return _count_worlds_completed()
		"lifetime_hard_clears": return lifetime_hard_clears
		"worlds_unlocked": return GameManager.worlds_unlocked
		"hard_stars": return _count_hard_stars()
	return 0

func _count_total_stars() -> int:
	var total := 0
	for w in GameManager.WORLD_COUNT:
		for d in 3:
			total += GameManager.stars[w][d]
	return total

func _count_worlds_completed() -> int:
	var count := 0
	for w in GameManager.WORLD_COUNT:
		if GameManager.best_stars(w) >= 3:
			count += 1
	return count

func _count_hard_stars() -> int:
	var total := 0
	for w in GameManager.WORLD_COUNT:
		total += GameManager.stars[w][2]
	return total

func _check_missions():
	for mission_id in MISSION_POOL:
		if mission_id in completed_mission_ids:
			continue
		var pool_data: Dictionary = MISSION_POOL[mission_id]
		var current := _get_stat(pool_data["stat"])
		if current >= pool_data["target"]:
			completed_mission_ids.append(mission_id)
			GameManager.wallet += pool_data["reward"]
			GameManager.save_data()
			mission_completed.emit(mission_id, pool_data["reward"])

func check_achievements():
	for ach_id in ACHIEVEMENTS:
		if ach_id in unlocked_achievements:
			continue
		var data: Dictionary = ACHIEVEMENTS[ach_id]
		var current := _get_stat(data["stat"])
		if current >= data["target"]:
			unlocked_achievements.append(ach_id)
			GameManager.wallet += data["reward"]
			GameManager.save_data()
			achievement_unlocked.emit(ach_id, data["name"], data["reward"])
	_save_data()

func has_unclaimed_daily() -> bool:
	var today := _today()
	return last_claim_date != today

func claim_daily() -> Dictionary:
	var today := _today()
	if last_claim_date == today:
		return {}
	var yesterday := _yesterday()
	if last_claim_date != yesterday and last_claim_date != "":
		daily_streak = 0
	var reward_data: Dictionary = DAILY_REWARDS[daily_streak]
	if reward_data["type"] == "coins" or reward_data["type"] == "both":
		GameManager.wallet += reward_data["amount"]
	if reward_data["type"] == "item" or reward_data["type"] == "both":
		var item_id: String = reward_data["item"]
		GameManager.items[item_id] += reward_data.get("amount", 1) if reward_data["type"] == "item" else 1
	daily_streak = (daily_streak + 1) % 7
	last_claim_date = today
	GameManager.save_data()
	_save_data()
	return reward_data

func get_all_missions() -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	for mission_id in MISSION_POOL:
		var pool_data: Dictionary = MISSION_POOL[mission_id]
		var current := _get_stat(pool_data["stat"])
		var is_done: bool = mission_id in completed_mission_ids
		result.append({
			"id": mission_id,
			"desc": pool_data["desc"],
			"progress": mini(current, pool_data["target"]),
			"target": pool_data["target"],
			"reward": pool_data["reward"],
			"done": is_done,
		})
	result.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		if a["done"] != b["done"]:
			return not a["done"]
		var a_pct := float(a["progress"]) / float(a["target"])
		var b_pct := float(b["progress"]) / float(b["target"])
		return a_pct > b_pct
	)
	return result

func _today() -> String:
	var dict := Time.get_date_dict_from_system()
	return "%04d-%02d-%02d" % [dict["year"], dict["month"], dict["day"]]

func _yesterday() -> String:
	var unix := Time.get_unix_time_from_system() - 86400
	var dict := Time.get_date_dict_from_unix_time(int(unix))
	return "%04d-%02d-%02d" % [dict["year"], dict["month"], dict["day"]]

func _save_data():
	var cfg := ConfigFile.new()
	cfg.load(SAVE_PATH)
	cfg.set_value("missions", "completed", ",".join(completed_mission_ids))
	cfg.set_value("achievements", "unlocked", ",".join(unlocked_achievements))
	cfg.set_value("daily", "streak", daily_streak)
	cfg.set_value("daily", "last_claim", last_claim_date)
	cfg.set_value("stats", "lifetime_coins", lifetime_coins)
	cfg.set_value("stats", "lifetime_floors", lifetime_floors)
	cfg.set_value("stats", "lifetime_treasures", lifetime_treasures)
	cfg.set_value("stats", "lifetime_traps_survived", lifetime_traps_survived)
	cfg.set_value("stats", "lifetime_potions_used", lifetime_potions_used)
	cfg.set_value("stats", "lifetime_npc_met", lifetime_npc_met)
	cfg.set_value("stats", "lifetime_games_played", lifetime_games_played)
	cfg.set_value("stats", "lifetime_hard_clears", lifetime_hard_clears)
	cfg.set_value("stats", "max_combo_ever", max_combo_ever)
	cfg.save(SAVE_PATH)

func _load_data():
	var cfg := ConfigFile.new()
	if cfg.load(SAVE_PATH) != OK:
		return
	var completed_raw: String = cfg.get_value("missions", "completed", "")
	if completed_raw != "":
		completed_mission_ids.assign(completed_raw.split(","))
	var unlocked_raw: String = cfg.get_value("achievements", "unlocked", "")
	if unlocked_raw != "":
		unlocked_achievements.assign(unlocked_raw.split(","))
	daily_streak = cfg.get_value("daily", "streak", 0)
	last_claim_date = cfg.get_value("daily", "last_claim", "")
	lifetime_coins = cfg.get_value("stats", "lifetime_coins", 0)
	lifetime_floors = cfg.get_value("stats", "lifetime_floors", 0)
	lifetime_treasures = cfg.get_value("stats", "lifetime_treasures", 0)
	lifetime_traps_survived = cfg.get_value("stats", "lifetime_traps_survived", 0)
	lifetime_potions_used = cfg.get_value("stats", "lifetime_potions_used", 0)
	lifetime_npc_met = cfg.get_value("stats", "lifetime_npc_met", 0)
	lifetime_games_played = cfg.get_value("stats", "lifetime_games_played", 0)
	lifetime_hard_clears = cfg.get_value("stats", "lifetime_hard_clears", 0)
	max_combo_ever = cfg.get_value("stats", "max_combo_ever", 0)
