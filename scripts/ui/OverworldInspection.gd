extends RefCounted

# Read-only presentation of canonical interaction records. Native map objects
# adopted as sites/artifacts/encounters use these same runtime collections;
# decorative and topology-only map_objects are deliberately not interactables.
const Rules := preload("res://scripts/core/OverworldRules.gd")
const Levels := preload("res://scripts/core/OverworldLevelRules.gd")

static func visible_record(session, record: Dictionary, level: int) -> bool:
	return session != null and Levels.on_level(record, level) and Rules.is_tile_visible(session, int(record.get("x", -1)), int(record.get("y", -1)), level)

static func highlight_rows(session, level: int) -> Array:
	var rows: Array = []
	if session == null: return rows
	for node in session.overworld.get("resource_nodes", []):
		if not node is Dictionary or not visible_record(session, node, level): continue
		var site := ContentService.get_resource_site(String(node.get("site_id", "")))
		if not Rules.resource_node_is_present(node, site): continue
		var state := "Available"
		if not Rules.resource_site_blocking_guard(session, node, site).is_empty() or Rules._resource_node_has_live_ai_defender(session, node, site):
			state = "Guarded"
		elif bool(node.get("collected", false)):
			if Rules._resource_site_is_repeatable(site) and not Rules._resource_site_is_persistent(site):
				state = "Available" if Rules._resource_site_repeat_ready(session, node, site) else "Exhausted"
			elif not Rules._resource_node_claimable_by_player(node, site, session):
				state = "Visited"
		rows.append(_row(node, "resource", state))
	for node in session.overworld.get("artifact_nodes", []):
		if node is Dictionary and visible_record(session, node, level) and not bool(node.get("collected", false)):
			rows.append(_row(node, "artifact", "Available"))
	for encounter in session.overworld.get("encounters", []):
		if encounter is Dictionary and visible_record(session, encounter, level) and not Rules.is_encounter_resolved(session, encounter):
			rows.append(_row(encounter, "encounter", "Guarded"))
	for town in session.overworld.get("towns", []):
		if town is Dictionary and visible_record(session, town, level):
			rows.append(_row(town, "town", "Visited" if String(town.get("owner", "")) == "player" else "Available"))
	return rows

static func _row(record: Dictionary, kind: String, state: String) -> Dictionary:
	return {"tile": Vector2i(int(record.get("x", -1)), int(record.get("y", -1))), "level": Levels.level_of(record), "placement_id": String(record.get("placement_id", record.get("id", ""))), "kind": kind, "state": state}

static func inspect_tile(session, tile: Vector2i, level: int) -> Dictionary:
	var result := {"title": "Unscouted ground", "summary": "Explore this tile to inspect it.", "stacks": [], "terrain": "Unknown", "strength": "Unknown", "reward": "Unknown", "disclosed": false}
	if session == null or not Rules.is_tile_visible(session, tile.x, tile.y, level): return result
	result.disclosed = true
	var terrain: Array = Levels.terrain_rows(session, level)
	if tile.y >= 0 and tile.y < terrain.size() and tile.x >= 0 and tile.x < terrain[tile.y].size(): result.terrain = String(terrain[tile.y][tile.x]).capitalize()
	result.title = "Scouted ground"
	result.summary = "No hostile army is disclosed here. Inspection does not move your hero or commit an order."
	result.reward = "None disclosed"
	var guard: Dictionary = {}
	for encounter in session.overworld.get("encounters", []):
		if encounter is Dictionary and int(encounter.get("x", -1)) == tile.x and int(encounter.get("y", -1)) == tile.y and visible_record(session, encounter, level) and not Rules.is_encounter_resolved(session, encounter):
			guard = encounter
			break
	for node in session.overworld.get("resource_nodes", []):
		if not node is Dictionary or int(node.get("x", -1)) != tile.x or int(node.get("y", -1)) != tile.y or not visible_record(session, node, level): continue
		var site := ContentService.get_resource_site(String(node.get("site_id", "")))
		if not Rules.resource_node_is_present(node, site): continue
		result.title = String(site.get("name", "Resource site"))
		result.summary = String(site.get("description", "Visit this site to interact."))
		result.reward = String(site.get("name", "Guarded site"))
		var candidate := Rules.resource_site_blocking_guard(session, node, site)
		if not candidate.is_empty() and visible_record(session, candidate, level): guard = candidate
		elif not candidate.is_empty(): result.summary += "\nGuard strength is not scouted."
	if guard.is_empty(): return result
	result.title = Rules.encounter_display_name(guard)
	var encounter_def := ContentService.get_encounter(String(guard.get("encounter_id", guard.get("id", ""))))
	# BattleRules.create_battle_payload takes terrain from encounter content,
	# not a generated placement's world-biome metadata.
	result.terrain = String(encounter_def.get("terrain", "plains")).capitalize()
	# These exact quantities are already disclosed by the existing selected-tile
	# scouting text. Never read enemy town garrisons or hidden defender payloads.
	var army := Rules._encounter_army_payload(guard)
	for stack in army.get("stacks", []):
		if not stack is Dictionary or int(stack.get("count", 0)) <= 0: continue
		var unit_id := String(stack.get("unit_id", ""))
		var unit := ContentService.get_unit(unit_id)
		result.stacks.append({"unit_id": unit_id, "name": String(unit.get("name", unit_id)), "count": int(stack.get("count", 0))})
	var player_army: Dictionary = session.overworld.get("hero", {}).get("army", session.overworld.get("army", {}))
	var own_strength := Rules._army_strength_value(player_army.get("stacks", []))
	var enemy_strength := Rules._army_strength_value(army.get("stacks", []))
	if own_strength > 0 and enemy_strength > 0:
		var ratio := float(enemy_strength) / float(own_strength)
		result.strength = "Much stronger" if ratio >= 2.0 else ("Stronger" if ratio >= 1.25 else ("Comparable" if ratio >= 0.8 else ("Weaker" if ratio >= 0.5 else "Much weaker")))
	result.summary = "Approximate army comparison only. Abilities, spells, terrain and tactics can change the outcome; casualties are not predicted."
	var reward := Rules._encounter_reward_surface(guard)
	if not reward.is_empty(): result.reward = reward
	result.encounter_key = Rules.encounter_key(guard)
	return result
