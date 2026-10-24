class_name HeroProgressionRules
extends RefCounted

const BattleEngine = preload("res://scripts/core/BattleEngine.gd")
const HumanEngine = preload("res://scripts/core/HumanEngine.gd")
static var _human_engine_mode: int = HumanEngine.mode
const NativeRules = preload("res://scripts/core/NativeRules.gd")
const CHOICE_SIZE := 3
const SPECIALTY_INSIGNIA_ATLAS_PATH := "res://art/heroes/runtime/specialties/hero_specialty_insignia_atlas.png"
const SPECIALTY_INSIGNIA_CELL_SIZE := Vector2i(28, 28)
const RANK_LABELS := ["I", "II", "III", "IV"]
## Recruit-growth specialties raise dwellings up to this tier.
const RECRUIT_GROWTH_MAX_TIER := 6
## The specialty catalog: content/hero_specialties.json (ids, names, per-rank
## text and bonuses, icon cells, group and command path).
const SPECIALTIES_PATH := "res://content/hero_specialties.json"
const SPECIALTY_INSIGNIA_ATLAS_SIZE := Vector2i(196, 140)
## Level-up offers lean toward a hero's own focus specialties, then toward
## those of its command path (might: command, magic: magic).
const OFFER_FOCUS_WEIGHT := 4.0
const OFFER_PATH_WEIGHT := 2.5
const OFFER_OTHER_WEIGHT := 1.0
static var _catalog_source: Variant = null
static var _catalog_index := {}
## Each level-up rolls one command stat, weighted by the hero's command path
## (heroes.json): might commanders mostly train attack and defense, magic
## commanders power and knowledge. The roll comes from the hero's growth seed
## and the level reached, so saving, loading or the tavern's preview never
## re-roll it, while each game's heroes draw their own seeds.
const COMMAND_GAIN_WEIGHTS := {
	"might": {"attack": 40, "defense": 40, "power": 10, "knowledge": 10},
	"magic": {"attack": 10, "defense": 10, "power": 40, "knowledge": 40},
}
const COMMAND_STATS := ["attack", "defense", "power", "knowledge"]

static func ensure_hero_progression(hero_state: Dictionary) -> Dictionary:
	var hero := hero_state
	var level := int(max(1, int(hero.get("level", 1))))
	hero["level"] = level
	hero["specialties"] = _normalize_specialties(hero.get("specialties", []))
	hero["pending_specialty_choices"] = _normalize_pending_choices(hero.get("pending_specialty_choices", []), hero)
	hero = _reconcile_pending_choices(hero)
	hero = _enqueue_missing_choice_groups(hero)
	# Old saves with an outstanding choice get one reminder; established heroes
	# without choices do not replay their entire progression history on load.
	var presented := level
	if not hero["pending_specialty_choices"].is_empty():
		presented = int(hero["pending_specialty_choices"][0].get("level", level)) - 1
	hero["level_up_presented"] = clampi(int(hero.get("level_up_presented", presented)), 1, level)
	return hero

static func level_up_summary(hero_state: Dictionary) -> Dictionary:
	if _human_engine_mode == HumanEngine.GDSCRIPT:
		return level_up_summary__gd(hero_state)
	if _human_engine_mode == HumanEngine.NATIVE:
		return HumanEngine.native_writing(&"HeroProgressionRules.level_up_summary", [hero_state])
	var before := HumanEngine.before_writing(&"HeroProgressionRules.level_up_summary", [hero_state])
	var result = level_up_summary__gd(hero_state)
	HumanEngine.check_writing(&"HeroProgressionRules.level_up_summary", before, [hero_state], result)
	return result

static func level_up_summary__gd(hero_state: Dictionary) -> Dictionary:
	var hero := ensure_hero_progression(hero_state.duplicate(true))
	var previous := int(hero["level_up_presented"])
	var level := int(hero["level"])
	if previous >= level:
		return {}
	var gains := {}
	var rolls := []
	for earned_level in range(previous + 1, level + 1):
		var stat := command_gain_stat(hero, earned_level)
		gains = _apply_command_gain(gains, stat)
		rolls.append({"level": earned_level, "stat": stat})
	var path := command_path(hero)
	return {
		"previous_level": previous,
		"level": level,
		"command_gains": gains,
		"command_rolls": rolls,
		"command_path": path,
		"command_odds": (COMMAND_GAIN_WEIGHTS[path] as Dictionary).duplicate(),
		"movement_gain": level - previous,
		"choice": current_pending_choice(hero),
		"choices_remaining": pending_choices_remaining(hero),
	}

static func add_experience(hero_state: Dictionary, amount: int) -> Dictionary:
	return _add_experience(hero_state, experience_with_bonus(hero_state, amount))

## `amount` of earned experience with the hero's experience bonus.
static func experience_with_bonus(hero_state: Dictionary, amount: int) -> int:
	if amount <= 0:
		return amount
	return amount + amount * int(aggregate_bonuses(hero_state).get("experience_bonus_pct", 0)) / 100

static func _add_experience(hero_state: Dictionary, amount: int) -> Dictionary:
	var hero := ensure_hero_progression(hero_state.duplicate(true))
	var messages := []
	if amount <= 0:
		return {"hero": hero, "messages": messages}

	hero["experience"] = int(hero.get("experience", 0)) + amount
	if int(hero.get("experience", 0)) >= int(hero.get("next_level_experience", 250)):
		# Pin what the rolls come from, so later reads (the level-up popup)
		# and later levels roll from the same path and seed.
		hero["command_path"] = command_path(hero)
		hero["growth_seed"] = growth_seed(hero)
	while int(hero.get("experience", 0)) >= int(hero.get("next_level_experience", 250)):
		hero["level"] = int(hero.get("level", 1)) + 1
		hero["command"] = _apply_command_gain(hero.get("command", {}), command_gain_stat(hero, int(hero.get("level", 1))))
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

## Experience a fresh level-1 hero needs to reach `level`, by the same
## thresholds add_experience climbs: 250 for level 2, then 250 + 100 x level
## more for each further level.
static func experience_for_level(level: int) -> int:
	var threshold := 0
	var next_threshold := 250
	for reached in range(2, level + 1):
		threshold = next_threshold
		next_threshold += 250 + reached * 100
	return threshold

## Raises a hero to `target_level` the way battles do: the experience for that
## level through add_experience, with its command gains and one specialty
## choice per level. Recruits arrive already trained, so each queued choice is
## taken at once, the hero's focus specialty first, and no level-up is left
## to present.
static func advance_to_level(hero_state: Dictionary, target_level: int) -> Dictionary:
	var hero := ensure_hero_progression(hero_state.duplicate(true))
	var missing := experience_for_level(target_level) - int(hero.get("experience", 0))
	if missing > 0:
		hero = _add_experience(hero, missing).get("hero", hero)
	while pending_choices_remaining(hero) > 0:
		var options: Array = current_pending_choice(hero).get("options", [])
		if options.is_empty():
			break
		var choice := choose_specialty(hero, String(options[0]))
		if not bool(choice.get("ok", false)):
			break
		hero = choice.get("hero", hero)
	hero["level_up_presented"] = int(hero.get("level", 1))
	return hero

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
	if _human_engine_mode == HumanEngine.GDSCRIPT:
		return get_choice_actions__gd(hero_state)
	if _human_engine_mode == HumanEngine.NATIVE:
		return HumanEngine.native_writing(&"HeroProgressionRules.get_choice_actions", [hero_state])
	var before := HumanEngine.before_writing(&"HeroProgressionRules.get_choice_actions", [hero_state])
	var result = get_choice_actions__gd(hero_state)
	HumanEngine.check_writing(&"HeroProgressionRules.get_choice_actions", before, [hero_state], result)
	return result

static func get_choice_actions__gd(hero_state: Dictionary) -> Array:
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
					rank_text(specialty_id, next_rank),
				],
				"disabled": false,
			}
		)
	return actions

static func describe_specialties(hero_state: Dictionary) -> String:
	var hero := ensure_hero_progression(hero_state.duplicate(true))
	var lines := ["Specialties"]
	var chosen_lines := []
	for specialty in specialties():
		var specialty_id := String(specialty.get("id", ""))
		var rank := specialty_rank(hero, specialty_id)
		if rank <= 0:
			continue
		chosen_lines.append(
			"- %s %s | %s"
			% [
				String(specialty.get("name", specialty_id)),
				rank_label(rank),
				rank_text(specialty_id, rank),
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
	return HumanEngine.native_writing(&"HeroProgressionRules.brief_summary", [hero_state])

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
	return raw_pending_choices_remaining(hero)

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

## The catalog's specialties in authored order (read-only rows).
static func specialties() -> Array:
	var items = ContentService.load_json(SPECIALTIES_PATH).get("items", [])
	return items if items is Array else []

## How many different specialties one hero can hold.
static func max_specialties_per_hero() -> int:
	return maxi(1, int(ContentService.load_json(SPECIALTIES_PATH).get("max_specialties_per_hero", 6)))

static func specialty_definition(specialty_id: String) -> Dictionary:
	var row := _specialty_row(specialty_id)
	return row.duplicate(true) if not row.is_empty() else {}

## What `specialty_id` gives at `rank` (1-based), as shown to the player.
static func rank_text(specialty_id: String, rank: int) -> String:
	if _human_engine_mode == HumanEngine.GDSCRIPT:
		return rank_text__gd(specialty_id, rank)
	if _human_engine_mode == HumanEngine.NATIVE:
		return HumanEngine.native(&"HeroProgressionRules.rank_text", [specialty_id, rank])
	var result = rank_text__gd(specialty_id, rank)
	HumanEngine.check(&"HeroProgressionRules.rank_text", [specialty_id, rank], result)
	return result

static func rank_text__gd(specialty_id: String, rank: int) -> String:
	var ranks: Array = _specialty_row(specialty_id).get("ranks", [])
	if rank < 1 or rank > ranks.size():
		return ""
	return String(ranks[rank - 1].get("text", ""))

static func _specialty_row(specialty_id: String) -> Dictionary:
	return _specialty_catalog().get(specialty_id, {})

## The catalog rows by id, shared and read-only; rebuilt when the content changes.
static func _specialty_catalog() -> Dictionary:
	return BattleEngine.native_writing(&"HeroProgressionRules._specialty_catalog", [])

static func has_specialty(specialty_id: String) -> bool:
	return not _specialty_row(specialty_id).is_empty()

static func specialty_id_for_action(action_id: String) -> String:
	const PREFIX := "choose_specialty:"
	if not action_id.begins_with(PREFIX):
		return ""
	var specialty_id := action_id.trim_prefix(PREFIX)
	return specialty_id if has_specialty(specialty_id) else ""

static func specialty_insignia_description(specialty_id: String) -> String:
	return String(_specialty_row(specialty_id).get("icon_description", ""))

static func specialty_insignia_texture(specialty_id: String) -> Texture2D:
	var specialty := _specialty_row(specialty_id)
	var region_value: Variant = specialty.get("icon_region", [])
	if specialty.is_empty() \
		or String(specialty.get("icon_id", "")) != "specialty_insignia_%s" % specialty_id \
		or not (region_value is Array) \
		or region_value.size() != 4 \
		or not ResourceLoader.exists(SPECIALTY_INSIGNIA_ATLAS_PATH, "Texture2D"):
		return null
	var region := Rect2(
		float(region_value[0]),
		float(region_value[1]),
		float(region_value[2]),
		float(region_value[3])
	)
	if region.size != Vector2(SPECIALTY_INSIGNIA_CELL_SIZE) \
		or region.position.x < 0.0 \
		or region.position.y < 0.0 \
		or region.end.x > float(SPECIALTY_INSIGNIA_ATLAS_SIZE.x) \
		or region.end.y > float(SPECIALTY_INSIGNIA_ATLAS_SIZE.y):
		return null
	var atlas := load(SPECIALTY_INSIGNIA_ATLAS_PATH) as Texture2D
	if atlas == null or atlas.get_size() != Vector2(SPECIALTY_INSIGNIA_ATLAS_SIZE):
		return null
	var texture := AtlasTexture.new()
	texture.atlas = atlas
	texture.region = region
	return texture

static func max_rank_for_specialty(specialty_id: String) -> int:
	return max(1, int(_specialty_row(specialty_id).get("max_rank", 1)))

static func aggregate_bonuses(hero_state: Dictionary) -> Dictionary:
	return BattleEngine.native_writing(&"HeroProgressionRules.aggregate_bonuses", [hero_state])

static func adjusted_mana_cost(hero_state: Dictionary, base_cost: int, school_id: String = "") -> int:
	return BattleEngine.native_writing(&"HeroProgressionRules.adjusted_mana_cost", [hero_state, base_cost, school_id])

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
		# Tier 7 keeps the town's own growth: one commander turning 2 a week
		# into 3 was too much.
		if int(ContentService.get_unit(String(unit_id)).get("tier", 0)) > RECRUIT_GROWTH_MAX_TIER:
			scaled[String(unit_id)] = amount
			continue
		var adjusted := int(round(float(amount) * multiplier))
		if amount > 0 and adjusted <= 0:
			adjusted = 1
		scaled[String(unit_id)] = adjusted
	return scaled

static func scale_recruit_cost(hero_state: Dictionary, cost_payload: Variant) -> Dictionary:
	var bonuses := aggregate_bonuses(hero_state)
	var multiplier := clampf(1.0 + float(bonuses.get("recruit_cost_delta", 0.0)), 0.5, 1.0)
	# Rounded up, so a small discount never halves a 2-resource T7 price.
	var scaled := {}
	if not (cost_payload is Dictionary):
		return scaled
	for key in cost_payload.keys():
		var amount := int(cost_payload[key])
		if amount > 0:
			scaled[String(key)] = maxi(1, ceili(float(amount) * multiplier - 0.0001))
	return scaled

static func scale_raid_pillage(hero_state: Dictionary, losses: Variant) -> Dictionary:
	var bonuses := aggregate_bonuses(hero_state)
	var multiplier := clampf(1.0 - float(bonuses.get("raid_pillage_resistance", 0.0)), 0.3, 1.0)
	return _scale_resource_payload(losses, multiplier)

static func rank_label(rank: int) -> String:
	if rank <= 0:
		return "0"
	return RANK_LABELS[min(rank - 1, RANK_LABELS.size() - 1)]

static func _normalize_specialties(value: Variant) -> Array:
	return _normalize_specialties_in(_specialty_catalog() if value is Array else {}, value)

static func _normalize_specialties_in(catalog: Dictionary, value: Variant) -> Array:
	return BattleEngine.native(&"HeroProgressionRules._normalize_specialties_in", [catalog, value])

static func _normalize_specialty_id_list(value: Variant) -> Array:
	var normalized := []
	if value is Array:
		for specialty_id_value in value:
			var specialty_id := String(specialty_id_value)
			if not has_specialty(specialty_id) or specialty_id in normalized:
				continue
			normalized.append(specialty_id)
	return normalized

static func _normalize_pending_choices(value: Variant, hero_state: Dictionary) -> Array:
	var normalized := []
	if value is Array:
		var catalog := _specialty_catalog()
		for pending_choice in value:
			if not (pending_choice is Dictionary):
				continue
			var level := int(max(2, int(pending_choice.get("level", 2))))
			var options := []
			for specialty_id_value in pending_choice.get("options", []):
				var specialty_id := String(specialty_id_value)
				var row: Dictionary = catalog.get(specialty_id, {})
				if row.is_empty():
					continue
				if specialty_rank(hero_state, specialty_id) >= maxi(1, int(row.get("max_rank", 1))):
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
		for specialty_id in _offer_order(hero, level):
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
	var allocated_choices := int(hero.get("specialties", []).size()) + raw_pending_choices_remaining(hero)
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
	var options := _offer_order(hero_state, level_number)
	if options.is_empty():
		return {}
	return {
		"level": max(2, level_number),
		"options": options.slice(0, min(CHOICE_SIZE, options.size())),
	}

static func available_specialty_ids(hero_state: Dictionary) -> Array:
	var available := []
	for specialty in specialties():
		var specialty_id := String(specialty.get("id", ""))
		if _specialty_is_available(hero_state, specialty_id):
			available.append(specialty_id)
	return available

## Specialties a level-up can offer, best first: one upgrade of a specialty
## the hero holds and one new specialty (while it has room) lead, then the
## rest. Each candidate's place is a weighted draw (focus and path weights,
## Efraimidis-Spirakis keys) seeded by the hero's growth seed and the level,
## so a saved or re-read choice never changes.
static func _offer_order(hero_state: Dictionary, level_number: int) -> Array:
	var available := available_specialty_ids(hero_state)
	if available.is_empty():
		return available
	var focus := _normalize_specialty_id_list(hero_state.get("specialty_focus_ids", []))
	var path := command_path(hero_state)
	var seed_text := growth_seed(hero_state)
	var keyed := []
	for specialty_id in available:
		var weight := OFFER_OTHER_WEIGHT
		if specialty_id in focus:
			weight = OFFER_FOCUS_WEIGHT
		elif String(_specialty_row(specialty_id).get("path", "any")) == path:
			weight = OFFER_PATH_WEIGHT
		var digest := ("%s|offer|%d|%s" % [seed_text, level_number, specialty_id]).sha256_text()
		var draw := (float(digest.substr(0, 8).hex_to_int()) + 1.0) / 4294967297.0
		# The rules' pow, the native copy's (decision D4, option B), not the engine's.
		keyed.append({"id": specialty_id, "key": NativeRules.api().math_pow(draw, 1.0 / weight)})
	keyed.sort_custom(func(a, b): return float(a.key) > float(b.key))
	var ordered := []
	for entry in keyed:
		ordered.append(String(entry.id))
	var result := []
	for want_held in [true, false]:
		for specialty_id in ordered:
			if (specialty_rank(hero_state, specialty_id) > 0) == want_held:
				result.append(specialty_id)
				break
	for specialty_id in ordered:
		if specialty_id not in result:
			result.append(specialty_id)
	return result

static func _distinct_specialty_count(hero_state: Dictionary) -> int:
	var seen := {}
	for specialty_id in hero_state.get("specialties", []):
		seen[String(specialty_id)] = true
	return seen.size()

static func _specialty_is_available(hero_state: Dictionary, specialty_id: String) -> bool:
	if _specialty_row(specialty_id).is_empty():
		return false
	var rank := specialty_rank(hero_state, specialty_id)
	if rank >= max_rank_for_specialty(specialty_id):
		return false
	return rank > 0 or _distinct_specialty_count(hero_state) < max_specialties_per_hero()

## The hero's command path: its own, else its template's (by id or roster id),
## else whichever pair of its command stats is larger.
static func command_path(hero_state: Dictionary) -> String:
	var path := String(hero_state.get("command_path", "")).strip_edges()
	if not COMMAND_GAIN_WEIGHTS.has(path):
		for key in ["id", "roster_hero_id", "hero_id"]:
			var template_id := String(hero_state.get(key, "")).strip_edges()
			if template_id != "":
				path = String(ContentService.get_hero(template_id).get("command_path", ""))
				if COMMAND_GAIN_WEIGHTS.has(path):
					break
	if COMMAND_GAIN_WEIGHTS.has(path):
		return path
	var command: Dictionary = hero_state.get("command", {}) if hero_state.get("command", {}) is Dictionary else {}
	var magic := int(command.get("power", 0)) + int(command.get("knowledge", 0))
	return "magic" if magic > int(command.get("attack", 0)) + int(command.get("defense", 0)) else "might"

## The command stat `hero_state` gains on reaching `level_number`: a roll
## weighted by its command path, drawn from its growth seed and that level.
static func command_gain_stat(hero_state: Dictionary, level_number: int) -> String:
	var weights: Dictionary = COMMAND_GAIN_WEIGHTS[command_path(hero_state)]
	var total := 0
	for stat in COMMAND_STATS:
		total += int(weights[stat])
	var digest := ("%s|level|%d" % [growth_seed(hero_state), level_number]).sha256_text()
	var roll := posmod(digest.substr(0, 8).hex_to_int(), total)
	for stat in COMMAND_STATS:
		roll -= int(weights[stat])
		if roll < 0:
			return String(stat)
	return String(COMMAND_STATS[0])

## What a hero's level-up rolls come from: the seed it drew when created, else
## (heroes saved before growth seeds) its id.
static func growth_seed(hero_state: Dictionary) -> String:
	var stored := String(hero_state.get("growth_seed", "")).strip_edges()
	if stored != "":
		return stored
	for key in ["id", "roster_hero_id", "hero_id", "name"]:
		var value := String(hero_state.get(key, "")).strip_edges()
		if value != "":
			return value
	return "hero"

static func _apply_command_gain(command_state: Variant, stat: String) -> Dictionary:
	var command := {
		"attack": max(0, int((command_state if command_state is Dictionary else {}).get("attack", 0))),
		"defense": max(0, int((command_state if command_state is Dictionary else {}).get("defense", 0))),
		"power": max(0, int((command_state if command_state is Dictionary else {}).get("power", 0))),
		"knowledge": max(0, int((command_state if command_state is Dictionary else {}).get("knowledge", 0))),
	}
	command[stat] = int(command.get(stat, 0)) + 1
	return command

## The queued choices of a hero already passed through ensure_hero_progression.
static func raw_pending_choices_remaining(hero_state: Dictionary) -> int:
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
