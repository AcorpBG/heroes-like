extends RefCounted
## Owner-selected common-mine geometry. Source package records remain immutable;
## game occupancy and rendering share this explicit three-by-two adapter.

static func resource(node: Dictionary) -> String:
	if String(node.get("kind", "")) == "reward_reference": return ""
	var site := ContentService.get_resource_site(String(node.get("site_id", "")))
	var common := String(site.get("common_mine_resource", ""))
	if common.is_empty():
		# A mine's state variant (the claimed quarry head) keeps its base mine's
		# shape and art; its own site still owns rewards and objectives.
		var contract: Dictionary = site.get("state_variant_contract", {}) if site.get("state_variant_contract", {}) is Dictionary else {}
		if String(contract.get("base_object_family", "")) == "mine":
			var base := ContentService.get_map_object(String(contract.get("base_object_id", "")))
			common = String(ContentService.get_resource_site(String(base.get("resource_site_id", ""))).get("common_mine_resource", ""))
	return common

static func entry_tile(node: Dictionary) -> Vector2i:
	var visit: Dictionary = node.get("visit_tile", {}) if node.get("visit_tile", {}) is Dictionary else {}
	return Vector2i(int(visit.get("x", node.get("x", 0))), int(visit.get("y", node.get("y", 0))))

static func origin(node: Dictionary) -> Vector2i:
	return entry_tile(node) - Vector2i(1, 1)

static func body_tiles(node: Dictionary) -> Array:
	var result := []
	var start := origin(node)
	for y in range(2):
		for x in range(3): result.append(start + Vector2i(x, y))
	return result

static func block_tiles(node: Dictionary) -> Array:
	var result := body_tiles(node)
	# Five solid cells and the south-middle visit cell comprise all six tiles.
	result.erase(entry_tile(node))
	return result
