extends RefCounted

# One description of what stands on a map tile, read by the hover card, the
# right-click report and the Sites (Alt) labels (docs/overworld-tile-description.md).
# Read-only presentation: every fact comes from the rules, none is decided here.
const Rules := preload("res://scripts/core/OverworldRules.gd")
const Levels := preload("res://scripts/core/OverworldLevelRules.gd")
const Artifacts := preload("res://scripts/core/ArtifactRules.gd")
const VisitBuildingRules := preload("res://scripts/core/VisitBuildingRules.gd")

const HOVER_LINE_LIMIT := 110
const PICKUP_FAMILIES := ["", "one_shot_pickup"]
const KIND_LINES := {
	"visit_building": "Hero visit",
	"mine": "Mine",
	"staged_resource_front": "Mine",
	"neutral_dwelling": "Creature dwelling",
	"guarded_reward_site": "Guarded treasure",
	"transit_object": "Passage",
	"scouting_structure": "Lookout",
	"faction_landmark": "Landmark",
	"faction_outpost": "Outpost",
	"support_producer": "Weekly supplies",
	"shrine": "Shrine",
	"frontier_shrine": "Shrine",
	"sign_waypoint": "Sign",
	"scenario_objective": "Objective",
	"one_shot_pickup": "Pickup",
	"": "Pickup",
}
const TERRAIN_NAMES := {"grass": "Grassland", "water": "Sea"}
# A hero-visit building that is a service says which.
const VISIT_ROLE_LINES := {
	"trading_post": "Trade", "black_market": "Artifact market", "field_tavern": "Tavern", "shipyard": "Shipyard",
	"whirlpool": "Whirlpool", "freelancer_guild": "Troop buyer", "hill_fort": "Upgrade yard",
	"kingdom_intelligence": "Intelligence", "prison_rescue": "Stockade", "chartmaker": "Map seller",
}

static func visible_record(session, record: Dictionary, level: int) -> bool:
	return session != null and Levels.on_level(record, level) and Rules.is_tile_visible(session, int(record.get("x", -1)), int(record.get("y", -1)), level)

# ---------------------------------------------------------------- the description

## What stands on `tile`, as the player may know it. Keys:
## kind (unscouted, ground, town, site, army, artifact), in_sight, title, subtitle
## (what kind of thing), gives (what it gives and how often), status and tone
## (ready, used, guarded, hostile, yours, neutral, plain), flavour, terrain, guard
## ({} or name, stacks (unit and size band word, never a count or range), strength,
## troops, reward, battlefield), tag, tag_tone and
## tag_tile for the Sites label, encounter_key.
static func describe_tile(session, tile: Vector2i, level: int) -> Dictionary:
	var record := _blank(tile)
	if session == null or not Rules.is_tile_explored(session, tile.x, tile.y, level):
		record.title = "Unexplored ground"
		record.status = "Scout closer to see what is here."
		return record
	record.terrain = _terrain_name(session, tile, level)
	record.in_sight = Rules.is_tile_visible(session, tile.x, tile.y, level)
	var town := _town_at(session, tile, level)
	if not town.is_empty():
		return _describe_town(session, record, town, level)
	var node := _site_at(session, tile, level)
	if not node.is_empty():
		return _describe_site(session, record, node, level)
	if record.in_sight:
		var army := _army_at(session, tile, level)
		if not army.is_empty():
			return _describe_army(session, record, army)
		var artifact := _artifact_at(session, tile, level)
		if not artifact.is_empty():
			return _describe_artifact(session, record, artifact, level)
	record.kind = "ground"
	record.title = String(record.terrain)
	if not record.in_sight:
		record.status = "Out of sight"
		return record
	var watcher := _zone_guard(session, tile, level)
	if not watcher.is_empty():
		record.guard = _guard_block(session, watcher)
		record.status = "Watched by %s%s" % [record.guard.name, _strength_suffix(record.guard.strength)]
		record.tone = "hostile"
	return record

static func _blank(tile: Vector2i) -> Dictionary:
	return {
		"kind": "unscouted", "in_sight": false, "title": "", "subtitle": "", "gives": "", "status": "", "tone": "plain",
		"flavour": "", "terrain": "Unknown", "guard": {}, "tag": "", "tag_tone": "plain", "tag_tile": tile, "encounter_key": "",
		"gives_short": "", "choices": [],
	}

static func _describe_town(session, record: Dictionary, town: Dictionary, level: int) -> Dictionary:
	var content := ContentService.get_town(String(town.get("town_id", "")))
	var faction := ContentService.get_faction(String(content.get("faction_id", town.get("faction_id", ""))))
	var owner := String(town.get("owner", "neutral"))
	record.kind = "town"
	record.title = String(town.get("name", content.get("name", "Town")))
	record.subtitle = "Town" if faction.is_empty() else "%s town" % String(faction.get("name", "Faction"))
	var entrance: Dictionary = Levels.town_entrance(town)
	record.tag_tile = Vector2i(int(entrance.get("x", town.get("x", 0))), int(entrance.get("y", town.get("y", 0))))
	if not record.in_sight:
		record.status = "Out of sight"
		return record
	match owner:
		"player":
			record.status = "Yours"
			record.tone = "yours"
			record.tag = "%s · yours" % record.title
		"enemy":
			record.status = "Enemy town"
			record.tone = "hostile"
			record.tag = "%s · enemy" % record.title
		_:
			record.status = "Neutral town"
			record.tone = "neutral"
			record.tag = "%s · neutral" % record.title
	record.tag_tone = record.tone
	if owner == "player":
		return record
	# A hero standing in the gate defends it; Read Tracks shows the garrison.
	var defender := _army_at(session, record.tag_tile, level)
	var tracked: Dictionary = Rules.read_tracks_garrison(session, record.tag_tile.x, record.tag_tile.y, level)
	var garrison: Array = tracked.get("stacks", []) if tracked.get("stacks", []) is Array else []
	if not defender.is_empty():
		record.guard = _guard_block(session, defender)
		record.encounter_key = Rules.encounter_key(defender)
		_append_stacks(record.guard.stacks, garrison, " (garrison)")
		record.status += " · held by %s%s" % [record.guard.name, _strength_suffix(record.guard.strength)]
	elif not garrison.is_empty():
		var listed: Array = []
		_append_stacks(listed, garrison, "")
		record.guard = {"name": "Garrison", "stacks": listed, "strength": _strength_label(session, garrison), "troops": "", "reward": "", "battlefield": ""}
		record.status += " · garrison%s" % _strength_suffix(record.guard.strength)
	return record

static func _describe_site(session, record: Dictionary, node: Dictionary, level: int) -> Dictionary:
	var site := ContentService.get_resource_site(String(node.get("site_id", "")))
	var family := String(site.get("family", ""))
	var visit: Dictionary = site.get("visit", {}) if site.get("visit", {}) is Dictionary else {}
	var is_visit := family == "visit_building"
	record.kind = "site"
	record.title = String(site.get("name", "Site"))
	record.subtitle = String(KIND_LINES.get(family, "Site"))
	if is_visit:
		var fallback := "Service" if String(visit.get("cadence", "once_per_hero")) == "always" else "Hero visit"
		record.subtitle = String(VISIT_ROLE_LINES.get(String(visit.get("role", "")), fallback))
	record.tag_tile = _tag_tile(node)
	var public_text = site.get("public_text", "")
	if public_text is String:
		record.flavour = public_text
	elif public_text is Dictionary:
		record.flavour = String(public_text.get("public_summary", ""))
	var parts: Array = []
	for part in String(Rules._resource_site_yield_line(session, node, site)).split(" | ", false):
		if String(part).strip_edges() != "":
			parts.append(String(part).strip_edges())
	# Only a portal has a destination to describe.
	var portal := String(Rules.describe_native_portal(session, node)) if family == "transit_object" else ""
	if portal.contains("invalid destination"):
		portal = ""
	var visit_status := ""
	if portal != "":
		record.gives = portal
	elif is_visit:
		# The last part is the rule's own answer for the selected hero.
		if parts.size() > 1:
			visit_status = String(parts.pop_back())
		record.gives = _sentence(" · ".join(parts))
		# A building with offers: the hover counts them, the report lists them.
		var offers: Array = visit.get("choices", []) if visit.get("choices", []) is Array else []
		for offer in offers:
			if offer is Dictionary and String(offer.get("label", "")) != "":
				record.choices.append(String(offer.get("label", "")))
		if record.choices.size() > 1:
			record.gives_short = "%d offers, one to choose, %s" % [record.choices.size(), String(VisitBuildingRules.cadence_label(site))]
			record.gives = "Choose one, %s:" % String(VisitBuildingRules.cadence_label(site))
	else:
		var service := ""
		for index in range(parts.size()):
			var cut := String(parts[index]).find(", service ")
			if cut >= 0:
				service = String(parts[index]).substr(cut + 2)
				parts[index] = String(parts[index]).left(cut)
		record.gives = _yield_words(" · ".join(parts))
		if service != "":
			visit_status = "Ready" if service == "service ready" else _sentence(service)
	if record.gives == record.flavour:
		record.gives = ""
	var pickup := PICKUP_FAMILIES.has(family)
	if not record.in_sight:
		# Remembered ground: what the building is, and what this side itself did there.
		record.status = "Out of sight"
		if is_visit and not visit.is_empty():
			var ready_again: bool = Rules._resource_node_claimable_by_player(node, site, session)
			record.tone = "ready" if ready_again else "used"
			record.status = ("Ready · out of sight" if ready_again else "%s · out of sight" % _used_text(visit_status))
			record.tag = record.title if ready_again else "%s · used" % record.title
			record.tag_tone = record.tone
		return record
	var guard: Dictionary = Rules.resource_site_blocking_guard(session, node, site)
	if guard.is_empty():
		guard = _army_on(session, _footprint(node), level)
	if not guard.is_empty():
		record.tone = "guarded"
		record.tag = "%s · guarded" % record.title
		record.tag_tone = "hostile"
		if visible_record(session, guard, level):
			record.guard = _guard_block(session, guard)
			record.encounter_key = Rules.encounter_key(guard)
			record.status = "Guarded by %s%s" % [record.guard.name, _strength_suffix(record.guard.strength)]
		else:
			record.status = "Guarded; the guard is not scouted"
		return record
	if is_visit:
		var ready: bool = Rules._resource_node_claimable_by_player(node, site, session)
		var hero_name := String(session.overworld.get("hero", {}).get("name", "this hero"))
		if String(visit.get("cadence", "once_per_hero")) == "always" or visit.is_empty():
			record.status = ""
			record.tone = "ready"
			record.tag = record.title
		elif ready:
			record.status = "Ready" if visit_status == "Ready" else "Ready for %s" % hero_name
			record.tone = "ready"
			record.tag = record.title
		else:
			record.status = _used_text(visit_status)
			record.tone = "used"
			record.tag = "%s · used" % record.title
		record.tag_tone = record.tone
		return record
	if pickup:
		return record
	if visit_status != "":
		# A repeatable service outside the hero-visit family (weekly supplies).
		record.status = visit_status
		record.tone = "ready" if visit_status == "Ready" else "used"
		record.tag = record.title if visit_status == "Ready" else "%s · used" % record.title
		record.tag_tone = record.tone
		return record
	var owner := _site_owner(node, site)
	record.tag = record.title
	match owner:
		"yours":
			record.status = "Yours"
			record.tone = "yours"
		"enemy":
			record.status = "Held by an enemy"
			record.tone = "hostile"
		"unclaimed":
			record.status = "Unclaimed"
			record.tone = "neutral"
		_:
			record.tone = "neutral"
	if Rules._resource_node_has_live_ai_defender(session, node, site):
		record.status = "Held by an enemy hero"
		record.tone = "hostile"
	record.tag_tone = record.tone
	return record

static func _describe_army(session, record: Dictionary, encounter: Dictionary) -> Dictionary:
	record.kind = "army"
	record.guard = _guard_block(session, encounter)
	record.title = String(record.guard.name)
	record.encounter_key = Rules.encounter_key(encounter)
	record.tag_tile = Vector2i(int(encounter.get("x", record.tag_tile.x)), int(encounter.get("y", record.tag_tile.y)))
	var target := String(Rules._encounter_guard_target_label(session, encounter))
	record.subtitle = String(record.guard.troops) if target == "" else "%s · guards %s" % [record.guard.troops, target]
	if String(record.guard.reward) != "":
		record.gives = "Victory brings %s" % record.guard.reward
	var strength := String(record.guard.strength)
	record.status = _strength_sentence(session, strength)
	record.tone = "hostile" if strength.ends_with("stronger") or strength == "Stronger" else ("ready" if strength.ends_with("eaker") else "plain")
	record.tag = strength if strength != "Unknown" else "Army"
	record.tag_tone = record.tone
	return record

static func _describe_artifact(session, record: Dictionary, node: Dictionary, level: int) -> Dictionary:
	var artifact_id := String(node.get("artifact_id", ""))
	record.kind = "artifact"
	record.title = String(Artifacts.artifact_name(artifact_id))
	record.subtitle = "Artifact"
	record.gives = _sentence(String(Artifacts.artifact_effect_summary(artifact_id)))
	record.tag = record.title
	record.tone = "ready"
	var watcher := _zone_guard(session, record.tag_tile, level)
	if not watcher.is_empty():
		record.guard = _guard_block(session, watcher)
		record.encounter_key = Rules.encounter_key(watcher)
		record.status = "Guarded by %s%s" % [record.guard.name, _strength_suffix(record.guard.strength)]
		record.tone = "guarded"
		record.tag = "%s · guarded" % record.title
	record.tag_tone = "hostile" if record.tone == "guarded" else "ready"
	return record

# ---------------------------------------------------------------- the three readers

## The hover card: at most three short lines.
static func hover_text(session, tile: Vector2i, level: int) -> String:
	return String(hover_card(session, tile, level).text)

## The hover card's text with what the card needs to colour it: the status
## line's index (-1 without one) and the description's tone.
static func hover_card(session, tile: Vector2i, level: int) -> Dictionary:
	var record := describe_tile(session, tile, level)
	var lines: Array = []
	var head := String(record.title)
	if String(record.subtitle) != "":
		head = "%s · %s" % [head, record.subtitle]
	lines.append(head)
	if String(record.gives_short) != "":
		lines.append(String(record.gives_short))
	elif String(record.gives) != "":
		lines.append(_clip(String(record.gives), HOVER_LINE_LIMIT))
	elif String(record.flavour) != "":
		lines.append(_clip(String(record.flavour), HOVER_LINE_LIMIT))
	var status_line := -1
	if String(record.status) != "":
		status_line = lines.size()
		lines.append(_clip(String(record.status), HOVER_LINE_LIMIT))
	return {"text": "\n".join(lines), "status_line": status_line, "tone": String(record.tone)}

## The right-click report: the same description with room for the guard's
## stacks, the flavour line and what scouting marks the ground carries.
static func inspect_tile(session, tile: Vector2i, level: int) -> Dictionary:
	var record := describe_tile(session, tile, level)
	var guard: Dictionary = record.guard
	record.disclosed = String(record.kind) != "unscouted"
	record.marks = Rules.map_marks_at(session, tile.x, tile.y, level) if record.disclosed and session != null else []
	record.stacks = guard.get("stacks", [])
	record.strength = String(guard.get("strength", ""))
	record.reward = String(guard.get("reward", ""))
	record.summary = String(record.flavour)
	return record

## One row for each label the Sites toggle draws: where, the words and their tone.
## Loose pickups carry none. A hero-visit building keeps its label on remembered
## ground, since what this side did there is its own knowledge.
static func highlight_rows(session, level: int) -> Array:
	var rows: Array = []
	if session == null: return rows
	for node in session.overworld.get("resource_nodes", []):
		if not node is Dictionary or not Levels.on_level(node, level): continue
		var site := ContentService.get_resource_site(String(node.get("site_id", "")))
		if PICKUP_FAMILIES.has(String(site.get("family", ""))) or not Rules.resource_node_is_present(node, site): continue
		var tile := _tag_tile(node)
		var in_sight: bool = Rules.is_tile_visible(session, int(node.get("x", -1)), int(node.get("y", -1)), level)
		if not in_sight and not (String(site.get("family", "")) == "visit_building" and Rules.is_tile_explored(session, int(node.get("x", -1)), int(node.get("y", -1)), level)): continue
		var record := _blank(tile)
		record.in_sight = in_sight
		_describe_site(session, record, node, level)
		_add_row(rows, record, node, "resource", level, not in_sight)
	for node in session.overworld.get("artifact_nodes", []):
		if node is Dictionary and visible_record(session, node, level) and not bool(node.get("collected", false)):
			var record := _blank(Vector2i(int(node.get("x", -1)), int(node.get("y", -1))))
			record.in_sight = true
			_describe_artifact(session, record, node, level)
			_add_row(rows, record, node, "artifact", level, false)
	for encounter in session.overworld.get("encounters", []):
		if encounter is Dictionary and visible_record(session, encounter, level) and not Rules.is_encounter_resolved(session, encounter):
			var record := _blank(Vector2i(int(encounter.get("x", -1)), int(encounter.get("y", -1))))
			record.in_sight = true
			_describe_army(session, record, encounter)
			_add_row(rows, record, encounter, "encounter", level, false)
	for town in session.overworld.get("towns", []):
		if not town is Dictionary or not Levels.on_level(town, level): continue
		var entrance: Dictionary = Levels.town_entrance(town)
		var gate := Vector2i(int(entrance.get("x", town.get("x", -1))), int(entrance.get("y", town.get("y", -1))))
		if not Rules.is_tile_visible(session, gate.x, gate.y, level): continue
		var record := _blank(gate)
		record.in_sight = true
		_describe_town(session, record, town, level)
		_add_row(rows, record, town, "town", level, false)
	return rows

static func _add_row(rows: Array, record: Dictionary, source: Dictionary, kind: String, level: int, remembered: bool) -> void:
	if String(record.tag) == "": return
	rows.append({
		"tile": record.tag_tile, "level": level, "placement_id": String(source.get("placement_id", source.get("id", ""))),
		"kind": kind, "state": String(record.tag), "label": String(record.tag), "tone": String(record.tag_tone), "remembered": remembered,
	})

# ---------------------------------------------------------------- lookups

static func _terrain_name(session, tile: Vector2i, level: int) -> String:
	var terrain: Array = Levels.terrain_rows(session, level)
	if tile.y < 0 or tile.y >= terrain.size() or tile.x < 0 or tile.x >= terrain[tile.y].size(): return "Unknown"
	var id := String(terrain[tile.y][tile.x])
	return String(TERRAIN_NAMES.get(id, id.capitalize()))

static func _town_at(session, tile: Vector2i, level: int) -> Dictionary:
	for town in session.overworld.get("towns", []):
		if not town is Dictionary or not Levels.on_level(town, level): continue
		var entrance: Dictionary = Levels.town_entrance(town)
		if int(entrance.get("x", -1)) == tile.x and int(entrance.get("y", -1)) == tile.y: return town
		for cell in Rules.town_footprint_tiles(town):
			if _as_tile(cell) == tile: return town
	return {}

static func _site_at(session, tile: Vector2i, level: int) -> Dictionary:
	var exact: Dictionary = Rules.resource_node_interaction_at_tile(session, tile.x, tile.y, level)
	if not exact.is_empty() and Rules.resource_node_is_present(exact, ContentService.get_resource_site(String(exact.get("site_id", "")))):
		return exact
	for node in session.overworld.get("resource_nodes", []):
		if not node is Dictionary or not Levels.on_level(node, level): continue
		if not _footprint(node).has(tile): continue
		if Rules.resource_node_is_present(node, ContentService.get_resource_site(String(node.get("site_id", "")))): return node
	return {}

static func _army_at(session, tile: Vector2i, level: int) -> Dictionary:
	for encounter in session.overworld.get("encounters", []):
		if encounter is Dictionary and int(encounter.get("x", -1)) == tile.x and int(encounter.get("y", -1)) == tile.y and visible_record(session, encounter, level) and not Rules.is_encounter_resolved(session, encounter):
			return encounter
	return {}

static func _army_on(session, tiles: Array, level: int) -> Dictionary:
	for tile in tiles:
		var army := _army_at(session, tile, level)
		if not army.is_empty(): return army
	return {}

static func _artifact_at(session, tile: Vector2i, level: int) -> Dictionary:
	for node in session.overworld.get("artifact_nodes", []):
		if node is Dictionary and int(node.get("x", -1)) == tile.x and int(node.get("y", -1)) == tile.y and Levels.on_level(node, level) and not bool(node.get("collected", false)):
			return node
	return {}

## The army whose watch covers `tile`, when the player can see that army.
static func _zone_guard(session, tile: Vector2i, level: int) -> Dictionary:
	var watcher: Dictionary = Rules.guard_engagement_encounter_at_tile(session, tile.x, tile.y, level)
	return watcher if not watcher.is_empty() and visible_record(session, watcher, level) else {}

## Every tile of a site: where it stands, its body and where a hero visits it.
static func _footprint(node: Dictionary) -> Array:
	var tiles: Array = [Vector2i(int(node.get("x", -1)), int(node.get("y", -1)))]
	for key in ["package_body_tiles", "body_tiles", "package_visit_tiles"]:
		var listed = node.get(key, [])
		if listed is Array:
			for cell in listed:
				var tile := _as_tile(cell)
				if tile.x >= 0 and not tiles.has(tile): tiles.append(tile)
	var visit := _as_tile(node.get("visit_tile", null))
	if visit.x >= 0 and not tiles.has(visit): tiles.append(visit)
	return tiles

static func _as_tile(cell: Variant) -> Vector2i:
	if cell is Vector2i: return cell
	if cell is Vector2: return Vector2i(cell)
	if cell is Dictionary: return Vector2i(int(cell.get("x", -1)), int(cell.get("y", -1)))
	if cell is Array and cell.size() >= 2: return Vector2i(int(cell[0]), int(cell[1]))
	return Vector2i(-1, -1)

## Where a site's label hangs: the middle of its lowest row of tiles.
static func _tag_tile(node: Dictionary) -> Vector2i:
	var tiles: Array = [Vector2i(int(node.get("x", -1)), int(node.get("y", -1)))]
	for key in ["package_body_tiles", "body_tiles"]:
		var listed = node.get(key, [])
		if listed is Array:
			for cell in listed:
				var tile := _as_tile(cell)
				if tile.x >= 0 and not tiles.has(tile): tiles.append(tile)
	var lowest := 0
	for tile in tiles:
		lowest = maxi(lowest, tile.y)
	var row: Array = []
	for tile in tiles:
		if tile.y == lowest: row.append(tile.x)
	row.sort()
	return Vector2i(int(row[row.size() / 2]), lowest)

static func _site_owner(node: Dictionary, site: Dictionary) -> String:
	if not Rules._resource_site_is_persistent(site): return ""
	var label := String(Rules._resource_site_control_label(node, site)).to_lower()
	if label.contains("your") or label.contains("player"): return "yours"
	if label.contains("unclaimed") or label.contains("neutral") or label == "": return "unclaimed"
	return "enemy"

# ---------------------------------------------------------------- words

static func _guard_block(session, encounter: Dictionary) -> Dictionary:
	var army: Dictionary = Rules._encounter_army_payload(encounter)
	var stacks: Array = army.get("stacks", []) if army.get("stacks", []) is Array else []
	var listed: Array = []
	_append_stacks(listed, stacks, "")
	var definition := ContentService.get_encounter(String(encounter.get("encounter_id", encounter.get("id", ""))))
	return {
		"name": String(Rules.encounter_display_name(encounter)),
		"stacks": listed,
		"strength": _strength_label(session, stacks),
		# Another side's numbers are told as size bands, never as counts.
		"troops": "%d %s" % [listed.size(), "group" if listed.size() == 1 else "groups"],
		"reward": String(Rules._encounter_reward_surface(encounter)),
		# The battle is fought on the encounter's own field, not the ground it stands on.
		"battlefield": String(definition.get("terrain", "")).capitalize(),
	}

static func _append_stacks(target: Array, stacks: Array, suffix: String) -> void:
	for stack in stacks:
		if not stack is Dictionary or int(stack.get("count", 0)) <= 0: continue
		var unit_id := String(stack.get("unit_id", ""))
		var unit := ContentService.get_unit(unit_id)
		# The band's word only: neither the count nor the band's range is told.
		var band: Dictionary = Rules.army_size_band(int(stack.get("count", 0)))
		target.append({
			"unit_id": unit_id, "name": String(unit.get("name", unit_id)) + suffix,
			"size": String(band.get("word", "")).capitalize(),
		})

## The other army against the active hero's, in words ("Unknown" without an army on either side).
static func _strength_label(session, stacks: Array) -> String:
	var player_army: Dictionary = session.overworld.get("hero", {}).get("army", session.overworld.get("army", {}))
	var own_strength := Rules._army_strength_value(player_army.get("stacks", []))
	var enemy_strength := Rules._army_strength_value(stacks)
	if own_strength <= 0 or enemy_strength <= 0: return "Unknown"
	var ratio := float(enemy_strength) / float(own_strength)
	return "Much stronger" if ratio >= 2.0 else ("Stronger" if ratio >= 1.25 else ("Comparable" if ratio >= 0.8 else ("Weaker" if ratio >= 0.5 else "Much weaker")))

static func _strength_suffix(strength: String) -> String:
	return "" if strength == "" or strength == "Unknown" else " (%s)" % strength.to_lower()

static func _strength_sentence(session, strength: String) -> String:
	var hero_name := String(session.overworld.get("hero", {}).get("name", "your hero"))
	match strength:
		"Unknown", "":
			return ""
		"Comparable":
			return "A match for %s's army" % hero_name
		_:
			return "%s than %s's army" % [strength, hero_name]

## The rules' yield wording, turned round for a reader: "one-time 7 wood" is
## "7 wood", "daily 2 wood" is "2 wood a day".
static func _yield_words(text: String) -> String:
	var out: Array = []
	for piece in text.split(" · ", false):
		var words := String(piece).strip_edges()
		var lower := words.to_lower()
		if lower.begins_with("one-time "):
			words = words.substr(9)
		elif lower.begins_with("daily "):
			words = "%s a day" % words.substr(6)
		elif lower.begins_with("weekly "):
			words = "%s a week" % words.substr(7)
		out.append(words)
	return _sentence(" · ".join(out))

static func _used_text(rule_text: String) -> String:
	return rule_text if rule_text != "" else "Already used"

static func _sentence(text: String) -> String:
	var trimmed := text.strip_edges()
	return trimmed if trimmed == "" else trimmed.left(1).to_upper() + trimmed.substr(1)

static func _clip(text: String, limit: int) -> String:
	return text if text.length() <= limit else text.left(limit - 1).strip_edges() + "…"
