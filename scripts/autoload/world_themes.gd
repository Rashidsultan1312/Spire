extends Node

const WORLD_COUNT := 10
const WORLD_FLOORS := [8, 9, 10, 10, 11, 11, 12, 12, 13, 15]

const WORLD_NAMES := [
	"CELLAR", "DUNGEON", "TOWER", "CRYPT", "SPIRE",
	"ICE CAVERN", "SWAMP", "LAVA FORGE", "SHADOW REALM", "SKY TEMPLE"
]

const WORLD_DESCRIPTIONS := [
	"Old castle cellar",
	"Dark prison dungeon",
	"Guard tower",
	"Ancient crypt",
	"Cursed spire",
	"Frozen cavern",
	"Murky swamp",
	"Volcanic forge",
	"Realm of shadows",
	"Temple in the sky"
]

const WORLD_REWARD_MULT := [0.8, 0.9, 1.0, 1.2, 1.4, 1.6, 1.8, 2.0, 2.3, 2.5]

const SAFE_RATIOS := [
	[0.8, 0.6],
	[0.75, 0.55],
	[0.66, 0.5, 0.4],
	[0.6, 0.45],
	[0.5, 0.33],
	[0.5, 0.3],
	[0.45, 0.3],
	[0.4, 0.28],
	[0.38, 0.25],
	[0.35, 0.22],
]

const WORLD_BG := [
	"res://assets/sprites/v2/worlds/cellar_bg.png",
	"res://assets/sprites/v2/worlds/dungeon_bg.png",
	"res://assets/sprites/v2/worlds/tower_bg.png",
	"res://assets/sprites/v2/worlds/crypt_bg.png",
	"res://assets/sprites/v2/worlds/spire_bg.png",
	"res://assets/sprites/v2/worlds/ice_cavern_bg.png",
	"res://assets/sprites/v2/worlds/swamp_bg.png",
	"res://assets/sprites/v2/worlds/lava_forge_bg.png",
	"res://assets/sprites/v2/worlds/shadow_realm_bg.png",
	"res://assets/sprites/v2/worlds/sky_temple_bg.png",
]

const WORLD_MUSIC := [
	"res://assets/music/worlds/cellar.ogg",
	"res://assets/music/worlds/dungeon.ogg",
	"res://assets/music/worlds/tower.ogg",
	"res://assets/music/worlds/crypt.ogg",
	"res://assets/music/worlds/spire.ogg",
	"res://assets/music/worlds/ice_cavern.ogg",
	"res://assets/music/worlds/swamp.ogg",
	"res://assets/music/worlds/lava_forge.ogg",
	"res://assets/music/worlds/shadow_realm.ogg",
	"res://assets/music/worlds/sky_temple.ogg",
]

const THEMES := {
	0: {
		"canvas_modulate": Color(0.82, 0.78, 0.88),
		"glow_color": Color(1.0, 0.6, 0.25, 0.18),
		"wall_modulate": Color(0.55, 0.45, 0.65, 0.8),
		"particle_color": Color(1, 0.3, 0.2),
		"accent": Color(0.8, 0.5, 1.0),
		"hidden_tex": "res://assets/sprites/v2/doors/door_cellar.png",
	},
	1: {
		"canvas_modulate": Color(0.72, 0.78, 0.72),
		"glow_color": Color(0.6, 0.8, 0.4, 0.15),
		"wall_modulate": Color(0.45, 0.55, 0.45, 0.8),
		"particle_color": Color(0.4, 0.8, 0.3),
		"accent": Color(0.5, 0.7, 0.4),
		"hidden_tex": "res://assets/sprites/v2/doors/door_dungeon.png",
	},
	2: {
		"canvas_modulate": Color(0.8, 0.82, 0.88),
		"glow_color": Color(0.8, 0.7, 0.4, 0.16),
		"wall_modulate": Color(0.5, 0.5, 0.6, 0.8),
		"particle_color": Color(0.7, 0.5, 0.3),
		"accent": Color(0.6, 0.65, 0.8),
		"hidden_tex": "res://assets/sprites/v2/doors/door_tower.png",
	},
	3: {
		"canvas_modulate": Color(0.68, 0.78, 0.65),
		"glow_color": Color(0.3, 0.9, 0.4, 0.14),
		"wall_modulate": Color(0.4, 0.5, 0.35, 0.8),
		"particle_color": Color(0.3, 0.7, 0.25),
		"accent": Color(0.35, 0.65, 0.3),
		"hidden_tex": "res://assets/sprites/v2/doors/door_crypt.png",
	},
	4: {
		"canvas_modulate": Color(0.82, 0.7, 0.7),
		"glow_color": Color(1.0, 0.3, 0.2, 0.18),
		"wall_modulate": Color(0.6, 0.4, 0.4, 0.8),
		"particle_color": Color(1.0, 0.2, 0.15),
		"accent": Color(0.8, 0.3, 0.3),
		"hidden_tex": "res://assets/sprites/v2/doors/door_spire.png",
	},
	5: {
		"canvas_modulate": Color(0.78, 0.85, 0.95),
		"glow_color": Color(0.4, 0.7, 1.0, 0.16),
		"wall_modulate": Color(0.5, 0.6, 0.8, 0.8),
		"particle_color": Color(0.5, 0.8, 1.0),
		"accent": Color(0.4, 0.7, 1.0),
		"hidden_tex": "res://assets/sprites/v2/doors/door_ice_cavern.png",
	},
	6: {
		"canvas_modulate": Color(0.72, 0.76, 0.64),
		"glow_color": Color(0.5, 0.7, 0.2, 0.14),
		"wall_modulate": Color(0.45, 0.5, 0.35, 0.8),
		"particle_color": Color(0.4, 0.6, 0.2),
		"accent": Color(0.5, 0.6, 0.25),
		"hidden_tex": "res://assets/sprites/v2/doors/door_swamp.png",
	},
	7: {
		"canvas_modulate": Color(0.85, 0.72, 0.58),
		"glow_color": Color(1.0, 0.5, 0.1, 0.2),
		"wall_modulate": Color(0.6, 0.4, 0.3, 0.8),
		"particle_color": Color(1.0, 0.5, 0.1),
		"accent": Color(1.0, 0.55, 0.15),
		"hidden_tex": "res://assets/sprites/v2/doors/door_lava_forge.png",
	},
	8: {
		"canvas_modulate": Color(0.65, 0.58, 0.75),
		"glow_color": Color(0.6, 0.2, 0.8, 0.18),
		"wall_modulate": Color(0.4, 0.3, 0.5, 0.8),
		"particle_color": Color(0.6, 0.15, 0.8),
		"accent": Color(0.5, 0.2, 0.7),
		"hidden_tex": "res://assets/sprites/v2/doors/door_shadow_realm.png",
	},
	9: {
		"canvas_modulate": Color(0.9, 0.88, 0.82),
		"glow_color": Color(1.0, 0.9, 0.5, 0.2),
		"wall_modulate": Color(0.7, 0.65, 0.55, 0.8),
		"particle_color": Color(1.0, 0.9, 0.5),
		"accent": Color(1.0, 0.85, 0.4),
		"hidden_tex": "res://assets/sprites/v2/doors/door_sky_temple.png",
	},
}

func max_floors(world: int) -> int:
	return WORLD_FLOORS[clampi(world, 0, 9)]

func get_theme(world: int) -> Dictionary:
	if THEMES.has(world):
		return THEMES[world]
	return THEMES[0]

func safe_ratio(world: int, level: int) -> float:
	var ratios: Array = SAFE_RATIOS[clampi(world, 0, 9)]
	var floors: int = WORLD_FLOORS[clampi(world, 0, 9)]
	@warning_ignore("integer_division")
	var mid: int = floors / 2
	if ratios.size() == 2:
		return float(ratios[0]) if level <= mid else float(ratios[1])
	if ratios.size() >= 3:
		@warning_ignore("integer_division")
		var third: int = floors / 3
		if level <= third:
			return float(ratios[0])
		elif level <= third * 2:
			return float(ratios[1])
		else:
			return float(ratios[2])
	return float(ratios[0])
