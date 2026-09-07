extends RefCounted

const PlayerRules = preload("res://scripts/core/PlayerIdentityRules.gd")
const Adventure = preload("res://scripts/core/EnemyAdventureRules.gd")
const KIND := "defeat_generated_rivals"

static func uses_kind(scenario: Dictionary) -> bool:
	var value = scenario.get("objectives", {})
	return value is Dictionary and String(value.get("kind", "")) == KIND and not value.has("victory") and not value.has("defeat")

static func definitions(scenario: Dictionary) -> Variant:
	var original = scenario.get("objectives", {})
	if not uses_kind(scenario):
		return original
	# A derived rule view only. Never amend package documents or saved records.
	var result: Dictionary = original.duplicate(false)
	result["victory"] = [{"id": KIND, "type": KIND, "label": "Defeat every rival commander"}]
	result["defeat"] = []
	result["victory_text"] = "All rival commanders have been defeated. Your realm prevails."
	return result

static func progress(session) -> Dictionary:
	var result := {"known": false, "complete": false, "total": 0, "defeated": 0, "remaining": [], "reason": "Player ownership is unavailable."}
	if session == null:
		return result
	for bucket in ["towns", "encounters", "resource_nodes", "resolved_encounters"]:
		if not (session.overworld.get(bucket) is Array):
			return result
	var players = session.overworld.get("players", [])
	if not (players is Array):
		return result
	var catalog := {}
	var active := String(session.overworld.get("active_player_id", ""))
	var source = session.flags.get("native_random_map_runtime_scenario_record", {})
	if not (source is Dictionary) or String(source.get("id", "")) != session.scenario_id:
		source = session.overworld.get("native_random_map_runtime_scenario_record", {})
	if not (source is Dictionary):
		return result
	if not players.is_empty():
		for player in players:
			if not (player is Dictionary):
				return result
			var id := String(player.get("player_id", ""))
			if id == "" or catalog.has(id) or String(player.get("faction_id", "")) == "" or String(player.get("team_id", "")) == "":
				return result
			catalog[id] = player
		if not catalog.has(active) or not bool(catalog[active].get("human", false)):
			return result
		# Native package slots are immutable identity, unlike Town ownership.
		# A dropped rival row or altered team must not manufacture a victory.
		if source.has("player_slots"):
			var slots = source.get("player_slots")
			if not (slots is Array) or slots.size() != players.size():
				return result
			var seen := {}
			for original in PlayerRules.from_slots(slots):
				var id := String(original.get("player_id", ""))
				if seen.has(id) or not catalog.has(id):
					return result
				seen[id] = true
				for key in ["faction_id", "team_id", "human"]:
					if original.get(key) != catalog[id].get(key):
						return result
			if seen.size() != players.size():
				return result
	else:
		# Pre-controller saves cannot recover same-faction ownership that was
		# already pooled. Accept only their explicit, distinct legacy controllers.
		if String(session.overworld.get("player_identity_mode", "")) != "legacy_generated_faction_v0":
			return result
		var enemies = source.get("enemy_factions", [])
		if not (enemies is Array) or enemies.is_empty():
			return result
		active = "player"
		catalog[active] = {}
		var hero: Dictionary = session.overworld.get("hero", {})
		for enemy in enemies:
			var id := PlayerRules.controller_id(enemy) if enemy is Dictionary else String(enemy)
			if id == "" or catalog.has(id) or id == String(hero.get("faction_id", "")):
				return result
			catalog[id] = {}
	var rivals := {}
	for id in catalog:
		if id != active and not PlayerRules.allied(session, active, id):
			rivals[id] = {"towns": 0, "field_hosts": 0, "defenders": 0}
	for town in session.overworld.get("towns", []):
		if not (town is Dictionary):
			return result
		var owner := String(town.get("owner", "neutral"))
		if owner == "neutral":
			continue
		var controller := PlayerRules.town_controller_id(town)
		if owner == "player" and players.is_empty():
			controller = active
		if owner not in ["player", "enemy"] or not catalog.has(controller):
			return result
		if owner == "player" and controller != active:
			return result
		if owner == "enemy" and controller == active:
			return result
		if rivals.has(controller):
			rivals[controller].towns += 1
	var resolved = session.overworld.get("resolved_encounters", [])
	if not (resolved is Array):
		return result
	for encounter in session.overworld.get("encounters", []):
		if not (encounter is Dictionary):
			return result
		if String(encounter.get("placement_id", "")) not in resolved and not bool(encounter.get("raid_retired_to_rebuild", false)):
			var commander = encounter.get("enemy_commander_state", {})
			if commander is Dictionary and String(commander.get("player_id", "")) != "" and PlayerRules.raid_controller_id(encounter) == "":
				return result
		if not Adventure.is_active_pressure_host(encounter, "", resolved):
			continue
		var controller := PlayerRules.raid_controller_id(encounter)
		if not catalog.has(controller):
			return result
		if rivals.has(controller):
			rivals[controller].field_hosts += 1
	for node in session.overworld.get("resource_nodes", []):
		if not (node is Dictionary):
			return result
		if not node.has("ai_defender_commander_state"):
			continue
		var defender: Dictionary = Adventure._active_resource_defender_entry(session, node)
		if defender.is_empty():
			continue
		var controller := PlayerRules.defender_controller_id(node)
		if not catalog.has(controller):
			return result
		if rivals.has(controller):
			rivals[controller].defenders += 1
	result.known = true
	result.reason = ""
	result.total = rivals.size()
	for id in rivals:
		var presence: Dictionary = rivals[id]
		if int(presence.towns) + int(presence.field_hosts) + int(presence.defenders) > 0:
			result.remaining.append({"player_id": id, "presence": presence})
		else:
			result.defeated += 1
	result.complete = result.remaining.is_empty()
	return result
