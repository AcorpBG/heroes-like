extends RefCounted

const HumanEngine = preload("res://scripts/core/HumanEngine.gd")

# A local Vector2i is meaningful only together with a level. Keep world records
# global; callers select a level for terrain, occupancy and presentation queries.
# Missing level fields in authored content / legacy saves mean surface (zero).
static var _terrain_rows: Dictionary = {}

static func level_of(value: Variant) -> int:
	return HumanEngine.native(&"OverworldLevelRules.level_of", [value])

static func hero_level(session) -> int:
	return HumanEngine.native(&"OverworldLevelRules.hero_level", [session])

static func level_count(session) -> int:
	return HumanEngine.native(&"OverworldLevelRules.level_count", [session])

static func view_level(session) -> int:
	return HumanEngine.native(&"OverworldLevelRules.view_level", [session])

static func on_level(value: Variant, level: int) -> bool:
	return HumanEngine.native(&"OverworldLevelRules.on_level", [value, level])

static func position(value: Variant) -> Dictionary:
	return HumanEngine.native(&"OverworldLevelRules.position", [value])

static func town_entrance(town: Dictionary) -> Dictionary:
	return HumanEngine.native(&"OverworldLevelRules.town_entrance", [town])

static func terrain_rows(session, requested: int = -1) -> Array:
	return HumanEngine.native_writing(&"OverworldLevelRules.terrain_rows", [session, requested])

static func terrain_id_at(session, x: int, y: int, requested: int = -1) -> String:
	var rows := terrain_rows(session, requested)
	if y < 0 or y >= rows.size() or x < 0 or x >= rows[y].size():
		return "rock"
	return String(rows[y][x])
