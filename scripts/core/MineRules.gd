extends RefCounted
## Game-level presentation/occupancy for the nine shared mine identities.
## Historical site IDs and native source masks remain unchanged.
const CommonMines = preload("res://scripts/core/CommonMineRules.gd")
const HumanEngine = preload("res://scripts/core/HumanEngine.gd")

static func resource(node: Dictionary) -> String:
	return HumanEngine.native_writing(&"MineRules.resource", [node])

static func asset_id(node: Dictionary) -> String:
	return HumanEngine.native_writing(&"MineRules.asset_id", [node])

static func origin(node: Dictionary) -> Vector2i:
	return HumanEngine.native_writing(&"MineRules.origin", [node])
