class_name HeroProgressionRules
extends RefCounted

const CHOICE_SIZE := 3
const SPECIALTIES := [
	{
		"id": "wayfinder",
		"name": "Wayfinder's Instinct",
		"short_name": "Wayfinder",
		"max_rank": 2,
		"summary": "+2 overworld movement per rank.",
		"bonuses": {
			"overworld_movement": 2,
		},
	},
	{
		"id": "ledgerkeeper",
		"name": "Ledgerkeeper's Oath",
		"short_name": "Ledgerkeeper",
		"max_rank": 2,
		"summary": "+100 gold, +1 wood, and +1 ore at each daybreak per rank.",
		"bonuses": {
			"daily_income": {
				"gold": 100,
				"wood": 1,
				"ore": 1,
			},
		},
	},
	{
		"id": "spellwright",
		"name": "Spellwright's Reserve",
		"short_name": "Spellwright",
		"max_rank": 2,
		"summary": "+4 max mana and -1 spell mana cost per rank.",
		"bonuses": {
			"max_mana": 4,
			"mana_cost_discount": 1,
		},
	},
	{
		"id": "drillmaster",
		"name": "Drillmaster's Cadence",
		"short_name": "Drillmaster",
		"max_rank": 2,
		"summary": "+1 battle initiative per rank.",
		"bonuses": {
			"battle_initiative": 1,
		},
	},
	{
		"id": "armsmaster",
		"name": "Armsmaster's Temper",
		"short_name": "Armsmaster",
		"max_rank": 2,
		"summary": "+1 battle attack and +1 battle defense per rank.",
		"bonuses": {
			"battle_attack": 1,
			"battle_defense": 1,
		},
	},
	{
		"id": "mustercaptain",
		"name": "Muster Captain's Call",
		"short_name": "Muster Captain",
		"max_rank": 2,
		"summary": "+20% recruit growth and -10% recruit cost per rank.",
		"bonuses": {
			"recruit_growth_multiplier": 0.2,
			"recruit_cost_delta": -0.1,
		},
	},
	{
		"id": "borderwarden",
		"name": "Border Warden's Watch",
		"short_name": "Border Warden",
		"max_rank": 2,
		"summary": "+1 scouting radius and enemy raids pillage 15% fewer resources per rank.",
		"bonuses": {
			"scouting_radius": 1,
			"raid_pillage_resistance": 0.15,
		},
	},
]
const RANK_LABELS := ["I", "II", "III"]

static func ensure_hero_progression(hero_state: Dictionary) -> Dictionary:
	var hero := hero_state
	var level := int(max(1, int(hero.get("level", 1))))
	hero["level"] = level
	hero["specialties"] = _normalize_specialties(hero.get("specialties", []))
	hero["pending_specialty_choices"] = _normalize_pending_choices(hero.get("pending_specialty_choices", []), hero)
	hero = _reconcile_pending_choices(hero)
	hero = _enqueue_missing_choice_groups(hero)
	return hero

static func add_experience(hero_state: Dictionary, amount: int) -> Dictionary:
	var hero := ensure_hero_progression(hero_state.duplicate(true))
	var messages := []
	if amount <= 0:
		return {"hero": hero, "messages": messages}

	hero["experience"] = int(hero.get("experience", 0)) + amount
	while int(hero.get("experience", 0)) >= int(hero.get("next_level_experience", 250)):
		hero["level"] = int(hero.get("level", 1)) + 1
		hero["command"] = _apply_base_command_gain(hero.get("command", {}), int(hero.get("level", 1)))
		hero["next_level_experience"] = int(hero.get("next_level_experience", 250)) + 250 + (int(hero.get("level", 1)) * 100)
		hero = _enqueue_choice_group(hero, int(hero.get("level", 1)))
		messages.append("%s reached level %d." % [String(hero.get("name", "Hero")), int(hero.get("level", 1))])
		var pending_choice := current_pending_choice(hero)
		if not pending_choice.is_empty():
			messages.append("Specialty choice ready: %s." % pending_choice_summary(pending_choice))

	return {
		"hero": hero,
		"messages": messages,
	}

static func choose_specialty(hero_state: Dictionary, specialty_id: String) -> Dictionary:
	var hero := ensure_hero_progression(hero_state.duplicate(true))
	var pending_choices = hero.get("pending_specialty_choices", [])
	if not (pending_choices is Array) or pending_choices.is_empty():
		return {"ok": false, "hero": hero, "message": "No specialty choice is waiting."}

	var current_choice: Dictionary = pending_choices[0]
	var options = current_choice.get("options", [])
	if not (options is Array) or specialty_id not in options:
		return {"ok": false, "hero": hero, "message": "That specialty is not available for the current level-up choice."}
	if specialty_rank(hero, specialty_id) >= max_rank_for_specialty(specialty_id):
		return {"ok": false, "hero": hero, "message": "That specialty is already mastered."}

	var specialties = hero.get("specialties", [])
	if not (specialties is Array):
		specialties = []
	specialties.append(specialty_id)
	hero["specialties"] = specialties
	pending_choices.remove_at(0)
	hero["pending_specialty_choices"] = pending_choices
	hero = ensure_hero_progression(hero)

	var specialty := specialty_definition(specialty_id)
	var message := "%s adopts %s %s." % [
		String(hero.get("name", "The hero")),
		String(specialty.get("name", specialty_id)),
		rank_label(specialty_rank(hero, specialty_id)),
	]
	if pending_choices_remaining(hero) > 0:
		message += " %d specialty choice%s remain queued." % [
			pending_choices_remaining(hero),
			"" if pending_choices_remaining(hero) == 1 else "s",
		]
	return {"ok": true, "hero": hero, "message": message}

static func get_choice_actions(hero_state: Dictionary) -> Array:
	var hero := ensure_hero_progression(hero_state.duplicate(true))
	var pending_choice := current_pending_choice(hero)
	if pending_choice.is_empty():
		return []

	var actions := []
	for specialty_id_value in pending_choice.get("options", []):
		var specialty_id := String(specialty_id_value)
		var specialty := specialty_definition(specialty_id)
		if specialty.is_empty():
			continue
		var next_rank := specialty_rank(hero, specialty_id) + 1
		actions.append(
			{
				"id": "choose_specialty:%s" % specialty_id,
				"label": "Choose %s" % String(specialty.get("short_name", specialty_id)),
				"summary": "%s %s | %s" % [
					String(specialty.get("name", specialty_id)),
					rank_label(next_rank),
					String(specialty.get("summary", "")),
				],
				"disabled": false,
			}
		)
	return actions

static func describe_specialties(hero_state: Dictionary) -> String:
	var hero := ensure_hero_progression(hero_state.duplicate(true))
	var lines := ["Specialties"]
	var chosen_lines := []
	for specialty in SPECIALTIES:
		var specialty_id := String(specialty.get("id", ""))
		var rank := specialty_rank(hero, specialty_id)
		if rank <= 0:
			continue
		chosen_lines.append(
			"- %s %s | %s"
			% [
				String(specialty.get("name", specialty_id)),
				rank_label(rank),
				String(specialty.get("summary", "")),
			]
		)
	lines.append("\n".join(chosen_lines) if not chosen_lines.is_empty() else "- No specialties chosen yet")

	var pending_choices = hero.get("pending_specialty_choices", [])
	if pending_choices is Array and not pending_choices.is_empty():
		lines.append("Pending Choices")
		for pending_choice in pending_choices:
			if not (pending_choice is Dictionary):
				continue
			lines.append(
				"- Level %d: %s"
				% [
					int(pending_choice.get("level", 0)),
					pending_choice_summary(pending_choice),
				]
			)
	return "\n".join(lines)

static func brief_summary(hero_state: Dictionary) -> String:
	var hero := ensure_hero_progression(hero_state.duplicate(true))
	var parts := []
	for specialty in SPECIALTIES:
		var specialty_id := String(specialty.get("id", ""))
		var rank := specialty_rank(hero, specialty_id)
		if rank <= 0:
			continue
		parts.append("%s %s" % [String(specialty.get("short_name", specialty_id)), rank_label(rank)])
	var summary := ", ".join(parts) if not parts.is_empty() else "No specialties chosen yet"
	var pending_count := pending_choices_remaining(hero)
	if pending_count > 0:
		summary += " | Pending %d" % pending_count
	return summary

static func summarize_specialty_ids(specialty_ids: Variant, use_short_names: bool = true) -> String:
	var normalized := _normalize_specialty_id_list(specialty_ids)
	var names := []
	for specialty_id in normalized:
		var specialty := specialty_definition(specialty_id)
		if specialty.is_empty():
			continue
		var key := "short_name" if use_short_names else "name"
		var label := String(specialty.get(key, specialty.get("name", specialty_id)))
		if label != "" and label not in names:
			names.append(label)
	return ", ".join(names)

static func pending_choices_remaining(hero_state: Dictionary) -> int:
	var hero := ensure_hero_progression(hero_state.duplicate(true))
	return _raw_pending_choices_remaining(hero)

static func current_pending_choice(hero_state: Dictionary) -> Dictionary:
	var hero := ensure_hero_progression(hero_state.duplicate(true))
	var pending_choices = hero.get("pending_specialty_choices", [])
	if pending_choices is Array and not pending_choices.is_empty() and pending_choices[0] is Dictionary:
		return pending_choices[0]
	return {}

static func pending_choice_summary(pending_choice: Dictionary) -> String:
	var names := []
	for specialty_id_value in pending_choice.get("options", []):
		var specialty := specialty_definition(String(specialty_id_value))
		if specialty.is_empty():
			continue
		names.append(String(specialty.get("short_name", specialty.get("name", specialty_id_value))))
	return ", ".join(names)

static func specialty_rank(hero_state: Dictionary, specialty_id: String) -> int:
	var count := 0
	if hero_state.get("specialties", []) is Array:
		for specialty_id_value in hero_state.get("specialties", []):
			if String(specialty_id_value) == specialty_id:
				count += 1
	return count

static func specialty_definition(specialty_id: String) -> Dictionary:
	for specialty in SPECIALTIES:
		if String(specialty.get("id", "")) == specialty_id:
			return specialty.duplicate(true)
	return {}

static func max_rank_for_specialty(specialty_id: String) -> int:
	return max(1, int(specialty_definition(specialty_id).get("max_rank", 1)))

static func aggregate_bonuses(hero_state: Dictionary) -> Dictionary:
	var hero := ensure_hero_progression(hero_state.duplicate(true))
	var bonuses := {
		"overworld_movement": 0,
		"scouting_radius": 0,
		"daily_income": {"gold": 0, "wood": 0, "ore": 0},
		"max_mana": 0,
		"mana_cost_discount": 0,
		"battle_attack": 0,
		"battle_defense": 0,
		"battle_initiative": 0,
		"recruit_growth_multiplier": 0.0,
		"recruit_cost_delta": 0.0,
		"raid_pillage_resistance": 0.0,
	}
	for specialty in SPECIALTIES:
		var specialty_id := String(specialty.get("id", ""))
		var rank := specialty_rank(hero, specialty_id)
		if rank <= 0:
			continue
		var specialty_bonuses = specialty.get("bonuses", {})
		if not (specialty_bonuses is Dictionary):
			continue
		for key in specialty_bonuses.keys():
			var bonus_key := String(key)
			if bonus_key == "daily_income":
				var specialty_income = specialty_bonuses.get(bonus_key, {})
				if specialty_income is Dictionary:
					for resource_key in specialty_income.keys():
						bonuses["daily_income"][String(resource_key)] = int(bonuses["daily_income"].get(String(resource_key), 0)) + (int(specialty_income[resource_key]) * rank)
			else:
				var current_value = bonuses.get(bonus_key, 0)
				var specialty_value = specialty_bonuses.get(bonus_key, 0)
				if typeof(current_value) == TYPE_FLOAT or typeof(specialty_value) == TYPE_FLOAT:
					bonuses[bonus_key] = float(current_value) + (float(specialty_value) * float(rank))
				else:
					bonuses[bonus_key] = int(current_value) + (int(specialty_value) * rank)
	return bonuses

static func mana_max_bonus(hero_state: Dictionary) -> int:
	return int(aggregate_bonuses(hero_state).get("max_mana", 0))

static func adjusted_mana_cost(hero_state: Dictionary, base_cost: int) -> int:
	var discount := int(aggregate_bonuses(hero_state).get("mana_cost_discount", 0))
	return max(0, base_cost - max(0, discount))

static func daily_income_bonus(hero_state: Dictionary) -> Dictionary:
	return aggregate_bonuses(hero_state).get("daily_income", {}).duplicate(true)

static func scale_recruit_growth(hero_state: Dictionary, growth_payload: Variant) -> Dictionary:
	var bonuses := aggregate_bonuses(hero_state)
	var multiplier := maxf(0.0, 1.0 + float(bonuses.get("recruit_growth_multiplier", 0.0)))
	var scaled := {}
	if not (growth_payload is Dictionary):
		return scaled
	for unit_id in growth_payload.keys():
		var amount := int(max(0, int(growth_payload[unit_id])))
		var adjusted := int(round(float(amount) * multiplier))
		if amount > 0 and adjusted <= 0:
			adjusted = 1
		scaled[String(unit_id)] = adjusted
	return scaled

static func scale_recruit_cost(hero_state: Dictionary, cost_payload: Variant) -> Dictionary:
	var bonuses := aggregate_bonuses(hero_state)
	var multiplier := clampf(1.0 + float(bonuses.get("recruit_cost_delta", 0.0)), 0.5, 1.0)
	return _scale_resource_payload(cost_payload, multiplier)

static func scale_raid_pillage(hero_state: Dictionary, losses: Variant) -> Dictionary:
	var bonuses := aggregate_bonuses(hero_state)
	var multiplier := clampf(1.0 - float(bonuses.get("raid_pillage_resistance", 0.0)), 0.3, 1.0)
	return _scale_resource_payload(losses, multiplier)

static func rank_label(rank: int) -> String:
	if rank <= 0:
		return "0"
	return RANK_LABELS[min(rank - 1, RANK_LABELS.size() - 1)]

static func _normalize_specialties(value: Variant) -> Array:
	var normalized := []
	if value is Array:
		for specialty_id_value in value:
			var specialty_id := String(specialty_id_value)
			if specialty_definition(specialty_id).is_empty():
				continue
			if _rank_in_array(normalized, specialty_id) >= max_rank_for_specialty(specialty_id):
				continue
			normalized.append(specialty_id)
	return normalized

static func _normalize_specialty_id_list(value: Variant) -> Array:
	var normalized := []
	if value is Array:
		for specialty_id_value in value:
			var specialty_id := String(specialty_id_value)
			if specialty_definition(specialty_id).is_empty() or specialty_id in normalized:
				continue
			normalized.append(specialty_id)
	return normalized

static func _normalize_pending_choices(value: Variant, hero_state: Dictionary) -> Array:
	var normalized := []
	if value is Array:
		for pending_choice in value:
			if not (pending_choice is Dictionary):
				continue
			var level := int(max(2, int(pending_choice.get("level", 2))))
			var options := []
			for specialty_id_value in pending_choice.get("options", []):
				var specialty_id := String(specialty_id_value)
				if specialty_definition(specialty_id).is_empty():
					continue
				if specialty_rank(hero_state, specialty_id) >= max_rank_for_specialty(specialty_id):
					continue
				if specialty_id in options:
					continue
				options.append(specialty_id)
				if options.size() >= CHOICE_SIZE:
					break
			if not options.is_empty():
				normalized.append({"level": level, "options": options})
	return normalized

static func _reconcile_pending_choices(hero_state: Dictionary) -> Dictionary:
	var hero := hero_state
	var pending_choices := []
	for pending_choice in hero.get("pending_specialty_choices", []):
		if not (pending_choice is Dictionary):
			continue
		var level := int(max(2, int(pending_choice.get("level", 2))))
		var options := []
		for specialty_id_value in pending_choice.get("options", []):
			var specialty_id := String(specialty_id_value)
			if _specialty_is_available(hero, specialty_id) and specialty_id not in options:
				options.append(specialty_id)
		for specialty_id in _rotated_available_specialties(hero, level):
			if options.size() >= min(CHOICE_SIZE, available_specialty_ids(hero).size()):
				break
			if specialty_id not in options:
				options.append(specialty_id)
		if not options.is_empty():
			pending_choices.append({"level": level, "options": options})
	hero["pending_specialty_choices"] = pending_choices
	return hero

static func _enqueue_missing_choice_groups(hero_state: Dictionary) -> Dictionary:
	var hero := hero_state
	var expected_choices := int(max(0, int(hero.get("level", 1)) - 1))
	var allocated_choices := int(hero.get("specialties", []).size()) + _raw_pending_choices_remaining(hero)
	var next_level := allocated_choices + 2
	while allocated_choices < expected_choices:
		var choice_group := _build_choice_group(hero, next_level)
		if choice_group.is_empty():
			break
		var pending_choices = hero.get("pending_specialty_choices", [])
		if not (pending_choices is Array):
			pending_choices = []
		pending_choices.append(choice_group)
		hero["pending_specialty_choices"] = pending_choices
		allocated_choices += 1
		next_level += 1
	return hero

static func _enqueue_choice_group(hero_state: Dictionary, level_number: int) -> Dictionary:
	var hero := hero_state
	var choice_group := _build_choice_group(hero, level_number)
	if choice_group.is_empty():
		return hero
	var pending_choices = hero.get("pending_specialty_choices", [])
	if not (pending_choices is Array):
		pending_choices = []
	pending_choices.append(choice_group)
	hero["pending_specialty_choices"] = pending_choices
	return hero

static func _build_choice_group(hero_state: Dictionary, level_number: int) -> Dictionary:
	var options := _rotated_available_specialties(hero_state, level_number)
	if options.is_empty():
		return {}
	return {
		"level": max(2, level_number),
		"options": options.slice(0, min(CHOICE_SIZE, options.size())),
	}

static func available_specialty_ids(hero_state: Dictionary) -> Array:
	var available := []
	for specialty in SPECIALTIES:
		var specialty_id := String(specialty.get("id", ""))
		if _specialty_is_available(hero_state, specialty_id):
			available.append(specialty_id)
	return available

static func _rotated_available_specialties(hero_state: Dictionary, level_number: int) -> Array:
	var available := available_specialty_ids(hero_state)
	if available.is_empty():
		return available
	var preferred_available := []
	for specialty_id in _normalize_specialty_id_list(hero_state.get("specialty_focus_ids", [])):
		if specialty_id in available and specialty_id not in preferred_available:
			preferred_available.append(specialty_id)
	var remaining := []
	for specialty_id in available:
		if specialty_id not in preferred_available:
			remaining.append(specialty_id)
	if preferred_available.is_empty():
		return _rotate_specialty_order(remaining, level_number + int(hero_state.get("specialties", []).size()))
	var rotated := _rotate_specialty_order(preferred_available, level_number)
	if not remaining.is_empty():
		rotated.append_array(_rotate_specialty_order(remaining, level_number + int(hero_state.get("specialties", []).size())))
	return rotated

static func _rotate_specialty_order(available: Array, seed_number: int) -> Array:
	if available.is_empty():
		return []
	var rotated := []
	var start_index := posmod(seed_number, available.size())
	for offset in range(available.size()):
		rotated.append(available[(start_index + offset) % available.size()])
	return rotated

static func _specialty_is_available(hero_state: Dictionary, specialty_id: String) -> bool:
	return not specialty_definition(specialty_id).is_empty() and specialty_rank(hero_state, specialty_id) < max_rank_for_specialty(specialty_id)

static func _apply_base_command_gain(command_state: Variant, level_number: int) -> Dictionary:
	var command := {
		"attack": max(0, int((command_state if command_state is Dictionary else {}).get("attack", 0))),
		"defense": max(0, int((command_state if command_state is Dictionary else {}).get("defense", 0))),
		"power": max(0, int((command_state if command_state is Dictionary else {}).get("power", 0))),
		"knowledge": max(0, int((command_state if command_state is Dictionary else {}).get("knowledge", 0))),
	}
	if level_number % 2 == 0:
		command["attack"] = int(command.get("attack", 0)) + 1
	else:
		command["defense"] = int(command.get("defense", 0)) + 1
	return command

static func _rank_in_array(specialty_ids: Array, specialty_id: String) -> int:
	var count := 0
	for specialty_id_value in specialty_ids:
		if String(specialty_id_value) == specialty_id:
			count += 1
	return count

static func _raw_pending_choices_remaining(hero_state: Dictionary) -> int:
	var pending_choices = hero_state.get("pending_specialty_choices", [])
	return pending_choices.size() if pending_choices is Array else 0

static func _scale_resource_payload(payload: Variant, multiplier: float) -> Dictionary:
	var scaled := {}
	if not (payload is Dictionary):
		return scaled
	for key in payload.keys():
		var amount := int(payload[key])
		if amount <= 0:
			continue
		var adjusted := int(floor(float(amount) * multiplier))
		if adjusted <= 0:
			adjusted = 1
		scaled[String(key)] = adjusted
	return scaled
