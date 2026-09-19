extends RefCounted
## Game-level presentation/occupancy for the nine shared mine identities.
## Historical site IDs and native source masks remain unchanged.
const CommonMines = preload("res://scripts/core/CommonMineRules.gd")

static func resource(node: Dictionary) -> String:
	var common := CommonMines.resource(node)
	if not common.is_empty(): return common
	if String(node.get("kind", "")) == "reward_reference": return ""
	var site := ContentService.get_resource_site(String(node.get("site_id", "")))
	return String(site.get("rare_mine_resource", ""))

static func asset_id(node: Dictionary) -> String:
	var common := CommonMines.resource(node)
	if not common.is_empty(): return "mapobj_common_%s_mine" % common
	var rare := resource(node)
	return "mapobj_rare_%s_mine" % rare if not rare.is_empty() else ""

static func entry_tile(node: Dictionary) -> Vector2i:
	return CommonMines.entry_tile(node)

static func origin(node: Dictionary) -> Vector2i:
	return CommonMines.origin(node)

static func body_tiles(node: Dictionary) -> Array:
	return CommonMines.body_tiles(node)

static func block_tiles(node: Dictionary) -> Array:
	return CommonMines.block_tiles(node)
