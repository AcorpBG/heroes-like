class_name AudioPalette
extends RefCounted

const PATH := "res://content/audio_production_banks.json"

static func _data() -> Dictionary:
	return ContentService.load_json(PATH)

static func cue(cue_id: String) -> Dictionary:
	var rows: Dictionary = _data().get("cues", {})
	return rows.get(cue_id, {})

static func select(bank: String, ordinal: int) -> String:
	var banks: Dictionary = _data().get("banks", {})
	var variants: Array = banks.get(bank, [])
	if variants.is_empty():
		return ""
	return String(variants[posmod(ordinal, variants.size())])

static func unit_profile(unit_id: String) -> Dictionary:
	var profiles: Dictionary = _data().get("unit_profiles", {})
	return profiles.get(unit_id, {})

static func spell_bank(spell_id: String, gesture: String) -> String:
	var spells: Dictionary = _data().get("spell_banks", {})
	var row: Dictionary = spells.get(spell_id, {})
	return String(row.get(gesture, ""))

static func ground_bank(terrain: String, level: int = 0) -> String:
	if level > 0 and terrain not in ["water", "lava"]:
		return "move_underground"
	match terrain:
		"water": return "move_shallow_water"
		"mire", "swamp": return "move_mud"
		"rough", "lava", "road_stone": return "move_stone"
		"road", "road_dirt": return "move_dirt"
		"bridge": return "move_wood"
	return "move_" + terrain

static func objective_snapshot(session) -> Dictionary:
	var result := {}
	var definitions = ScenarioRules.objectives_for_session(session)
	if not definitions is Dictionary:
		return result
	for objective in definitions.get("victory", []):
		if not objective is Dictionary: continue
		var id := String(objective.get("id", ""))
		if id == "": continue
		var row := {"complete": ScenarioRules.is_objective_met(session, id, "victory")}
		if String(objective.get("type", "")) == ScenarioRules.GeneratedObjectives.KIND:
			var progress: Dictionary = ScenarioRules.GeneratedObjectives.progress(session)
			if not bool(progress.get("known", false)): continue
			row["defeated"] = int(progress.get("defeated", 0))
		result[id] = row
	return result

static func battle_cues(event: Dictionary, stacks: Array, fallback: Array) -> Array:
	var event_id := String(event.get("event_id", ""))
	# Idle animation cycles are visual, not repeated vocal performances.
	if event_id == "battle_stack_idle":
		return []
	var ordinal := int(event.get("serial", 0))
	var spell_id := String(event.get("spell_id", ""))
	var banks: Array[String] = []
	if spell_id != "" and event_id in ["battle_unit_cast", "battle_unit_hit", "battle_status_applied", "battle_status_expired"]:
		var gesture := "cast" if event_id == "battle_unit_cast" else ("expire" if event_id == "battle_status_expired" else "effect")
		if gesture == "effect":
			for id in fallback:
				if String(id).begins_with("audio_spell_") and id != "audio_spell_command_ward":
					return [id]
		banks.append(spell_bank(spell_id, gesture))
	else:
		var profile := {}
		for stack in stacks:
			if stack is Dictionary and String(stack.get("battle_id", "")) == String(event.get("battle_id", "")):
				profile = unit_profile(String(stack.get("unit_id", "")))
				break
		var body := String(profile.get("body_bank", ""))
		match event_id:
			"battle_unit_move": banks.append(body + "_move")
			"battle_unit_melee_attack", "battle_unit_ranged_attack":
				banks.append(String(profile.get("weapon_bank", "")))
				banks.append(body + "_attack")
			"battle_unit_hit":
				banks.append(String(profile.get("impact_bank", "")))
				banks.append(body + "_hit")
			"battle_unit_death": banks.append(body + "_defeat")
	var result: Array = []
	for bank in banks:
		var id := select(bank, ordinal)
		if id != "": result.append(id)
	return result if not result.is_empty() else fallback
