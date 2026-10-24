class_name HeroCommandRules
extends RefCounted

const SessionStateStoreScript = preload("res://scripts/core/SessionStateStore.gd")
const OverworldLevelRulesScript = preload("res://scripts/core/OverworldLevelRules.gd")
const HeroProgressionRulesScript = preload("res://scripts/core/HeroProgressionRules.gd")
const SpellRulesScript = preload("res://scripts/core/SpellRules.gd")
const ArtifactRulesScript = preload("res://scripts/core/ArtifactRules.gd")
const PlayerRules = preload("res://scripts/core/PlayerIdentityRules.gd")
const DayEngine = preload("res://scripts/core/DayEngine.gd")
const HumanEngine = preload("res://scripts/core/HumanEngine.gd")
static var _human_engine_mode: int = HumanEngine.mode
static var DifficultyRulesScript: Variant = load("res://scripts/core/DifficultyRules.gd")

const HALL_BUILDING_ID := "building_wayfarers_hall"
const HOLDER_GARRISON := "garrison"
const HERO_LIMIT := 4
const TAVERN_OFFER_SIZE := 2
const TAVERN_ROTATION_KEY := "tavern_rotation"
const ARMY_SLOT_COUNT := 7
const ARMY_SLOT_INDEX_KEY := "slot_index"
const TOWN_GARRISON_HERO_KEY := "garrison_hero_id"
const TOWN_GARRISON_HEROES_VERSION_KEY := "town_garrison_heroes_version"
const TOWN_GARRISON_HEROES_VERSION := 1
const DEFAULT_RECRUIT_COST := {"gold": 1200}
const BASE_SCOUT_RADIUS := 6
const TOWN_DEVELOPMENT_PATH := "res://content/town_development.json"
# Tavern veterans: about one offer in ten is level 2 and one in thirty level 3.
const TAVERN_LEVEL_TWO_PERCENT := 10
const TAVERN_LEVEL_THREE_PERCENT := 3
# HoMM3-like starting army: a tier-1 company always, often a second company
# (usually tier 2, sometimes the other tier-1 creature). Sizes are shares of
# the creature's weekly growth. The shares were cut when growth was rebalanced
# to equal weekly power per tier, so starting armies kept their strength.
const STARTING_SECOND_COMPANY_PERCENT := 75
const STARTING_SECOND_COMPANY_TIER_TWO_PERCENT := 70
const STARTING_FIRST_COMPANY_GROWTH_SHARE := [0.55, 1.1]
const STARTING_SECOND_COMPANY_GROWTH_SHARE := [0.33, 0.65]

static func normalize_session(
	session: SessionStateStoreScript.SessionData,
	primary_hero_id: String = "",
	default_position: Dictionary = {},
	default_army: Dictionary = {}
) -> void:
	if session == null:
		return
	if not PlayerRules.has_human_seat(session):
		# The computer plays every seat: its heroes are map encounters.
		session.hero_id = ""
		session.overworld["player_heroes"] = []
		session.overworld["active_hero_id"] = ""
		_sync_active_hero_mirror(session)
		return

	var scenario := ContentService.get_scenario_readonly(session.scenario_id)
	var resolved_primary_id := String(session.hero_id)
	var fallen: Array = session.flags.get(PRIMARY_FALLEN_FLAG, []) if session.flags.get(PRIMARY_FALLEN_FLAG, []) is Array else []
	if resolved_primary_id == "" and fallen.is_empty():
		resolved_primary_id = primary_hero_id if primary_hero_id != "" else String(scenario.get("hero_id", ""))
	session.hero_id = resolved_primary_id

	var legacy_hero = session.overworld.get("hero", {})
	var legacy_hero_id := String(legacy_hero.get("id", resolved_primary_id)) if legacy_hero is Dictionary else resolved_primary_id
	var legacy_position := _normalize_position(
		default_position if not default_position.is_empty() else session.overworld.get("hero_position", scenario.get("start", {"x": 0, "y": 0}))
	)
	var legacy_army := default_army if not default_army.is_empty() else _normalize_army(session.overworld.get("army", {}), legacy_hero_id)
	var legacy_movement = session.overworld.get("movement", {})

	var normalized_heroes := []
	var seen := {}
	var raw_player_heroes = session.overworld.get("player_heroes", [])
	if raw_player_heroes is Array:
		for hero_entry in raw_player_heroes:
			if not (hero_entry is Dictionary):
				continue
			var hero_id := String(hero_entry.get("id", ""))
			if hero_id == "" or seen.has(hero_id):
				continue
			var hero := _normalize_player_hero(
				hero_entry,
				session,
				legacy_position if hero_id == legacy_hero_id else {},
				legacy_army if hero_id == legacy_hero_id else {},
				legacy_movement if hero_id == legacy_hero_id else {}
			)
			if hero.is_empty():
				continue
			normalized_heroes.append(hero)
			seen[hero_id] = true

	if legacy_hero is Dictionary and not legacy_hero.is_empty():
		var normalized_legacy := _normalize_player_hero(
			legacy_hero,
			session,
			legacy_position,
			legacy_army,
			legacy_movement
		)
		if not normalized_legacy.is_empty():
			if seen.has(legacy_hero_id):
				_replace_hero_in_array(normalized_heroes, normalized_legacy)
			else:
				normalized_heroes.append(normalized_legacy)
				seen[legacy_hero_id] = true

	if resolved_primary_id != "" and not seen.has(resolved_primary_id):
		var primary_template := ContentService.get_hero(resolved_primary_id)
		var primary_hero := build_hero_from_template(primary_template, legacy_position, legacy_army, session)
		if not primary_hero.is_empty():
			primary_hero["is_primary"] = true
			normalized_heroes.append(primary_hero)
			seen[resolved_primary_id] = true

	if resolved_primary_id == "" and not normalized_heroes.is_empty():
		# A fallen leader still in the list (it is being removed) does not lead.
		for candidate in normalized_heroes:
			if String(candidate.get("id", "")) not in fallen:
				resolved_primary_id = String(candidate.get("id", ""))
				break
		session.hero_id = resolved_primary_id

	for index in range(normalized_heroes.size()):
		var hero = normalized_heroes[index]
		hero["is_primary"] = String(hero.get("id", "")) == resolved_primary_id
		if String(session.overworld.get("active_player_id", "")) != "":
			hero["player_id"] = String(session.overworld.active_player_id)
		normalized_heroes[index] = hero

	session.overworld["player_heroes"] = normalized_heroes
	var active_hero_id := String(session.overworld.get("active_hero_id", legacy_hero_id))
	if active_hero_id == "" or _hero_index_by_id(normalized_heroes, active_hero_id) < 0:
		active_hero_id = resolved_primary_id
	if active_hero_id == "" and not normalized_heroes.is_empty():
		active_hero_id = String(normalized_heroes[0].get("id", ""))
	session.overworld["active_hero_id"] = active_hero_id
	_sync_active_hero_mirror(session)
	_normalize_town_garrison_heroes(session)

static func build_hero_from_template(
	hero_template: Dictionary,
	position: Dictionary = {},
	army_state: Dictionary = {},
	movement_source: Variant = null
) -> Dictionary:
	if hero_template.is_empty():
		return {}
	var command = hero_template.get("command", {})
	var hero := HeroProgressionRulesScript.ensure_hero_progression(
		{
			"id": String(hero_template.get("id", "")),
			"name": String(hero_template.get("name", "Wandering Captain")),
			"level": 1,
			"experience": 0,
			"next_level_experience": 250,
			"base_movement": max(1, int(hero_template.get("base_movement", 10))),
			"command_path": String(hero_template.get("command_path", "")),
			"command": {
				"attack": int(command.get("attack", 0)),
				"defense": int(command.get("defense", 0)),
				"power": int(command.get("power", 0)),
				"knowledge": int(command.get("knowledge", 0)),
			},
			"spellbook": SpellRulesScript.build_spellbook(hero_template),
			"artifacts": ArtifactRulesScript.normalize_hero_artifacts({}),
			"specialties": _normalize_authored_specialties(hero_template.get("starting_specialties", [])),
			"pending_specialty_choices": [],
			"specialty_focus_ids": _normalize_authored_specialties(hero_template.get("specialty_focus_ids", [])),
		}
	)
	hero["growth_seed"] = new_growth_seed(String(hero.get("id", "")), movement_source)
	hero["position"] = _normalize_position(position)
	hero["army"] = _normalize_army(army_state, String(hero.get("id", "")))
	var movement_max := movement_max_for_hero(hero, movement_source)
	hero["movement"] = {"current": movement_max, "max": movement_max}
	hero["is_primary"] = false
	if movement_source is SessionStateStoreScript.SessionData and String(movement_source.overworld.get("active_player_id", "")) != "":
		hero["player_id"] = String(movement_source.overworld.active_player_id)
	return hero

## Builds a newly hired commander. Every hire, the player's tavern and AI
## recruitment alike, creates its hero here so no hired hero walks out without
## troops: the hero leads `army_state`, or its starting army
## (starting_army_for_hero, seeded by `seed_key`) when that holds no troops,
## and arrives at `level` through HeroProgressionRules exactly as earned levels
## do, with full movement and mana. tavern_offer gives a hire's level and army.
static func build_recruited_hero(
	hero_template: Dictionary,
	position: Dictionary,
	movement_source: Variant,
	level: int = 1,
	army_state: Variant = {},
	seed_key: String = "",
	growth_seed: String = ""
) -> Dictionary:
	if hero_template.is_empty():
		return {}
	var hero_id := String(hero_template.get("id", ""))
	var army := _normalize_army(army_state, hero_id)
	if _valid_stack_count(army.get("stacks", [])) == 0:
		army = starting_army_for_hero(hero_template, seed_key if seed_key != "" else hero_id)
	var hero := build_hero_from_template(hero_template, position, army, movement_source)
	if hero.is_empty():
		return hero
	# A caller without a session (the computer player's hires) passes its own
	# seed, so the levels a hire arrives with roll the same way every time.
	if growth_seed != "":
		hero["growth_seed"] = growth_seed
	if level > 1:
		hero = HeroProgressionRulesScript.advance_to_level(hero, level)
	# Specialty mana counts toward the new commander's full reserve.
	hero = SpellRulesScript.ensure_hero_spellbook(hero, hero_template)
	var spellbook: Dictionary = hero.get("spellbook", {})
	var mana: Dictionary = spellbook.get("mana", {})
	if not mana.is_empty():
		mana["current"] = int(mana.get("max", 0))
		spellbook["mana"] = mana
		hero["spellbook"] = spellbook
	var movement_max := movement_max_for_hero(hero, movement_source)
	hero["movement"] = {"current": movement_max, "max": movement_max}
	return hero

## A HoMM3-style starting army for `hero_template`: a company of the faction's
## tier-1 creature, often a second company (tier 2, or the other tier-1
## creature), each a share of that creature's weekly growth. A template's own
## `starting_army` rows ({unit_id, min, max}) are used instead when present.
## Always at least one creature when the faction has any; the same `seed_key`
## always gives the same army.
static func starting_army_for_hero(hero_template: Dictionary, seed_key: String) -> Dictionary:
	var hero_id := String(hero_template.get("id", ""))
	var rng := _seeded_rng("%s|starting_army" % seed_key)
	var stacks := []
	var authored = hero_template.get("starting_army", [])
	if authored is Array:
		for row in authored:
			var unit_id := String(row.get("unit_id", "")) if row is Dictionary else ""
			if unit_id == "" or ContentService.get_unit(unit_id).is_empty():
				continue
			var low := maxi(1, int(row.get("min", row.get("count", 1))))
			stacks.append({"unit_id": unit_id, "count": rng.randi_range(low, maxi(low, int(row.get("max", low))))})
	if stacks.is_empty():
		var faction_id := String(hero_template.get("faction_id", ""))
		var tier_one := _faction_creatures(faction_id, 1)
		var tier_two := _faction_creatures(faction_id, 2)
		if not tier_one.is_empty():
			var first := String(tier_one[rng.randi_range(0, tier_one.size() - 1)])
			stacks.append({"unit_id": first, "count": _starting_company_size(rng, first, STARTING_FIRST_COMPANY_GROWTH_SHARE)})
			var other_tier_one := tier_one.filter(func(unit_id): return String(unit_id) != first)
			if rng.randi_range(0, 99) < STARTING_SECOND_COMPANY_PERCENT and not (tier_two.is_empty() and other_tier_one.is_empty()):
				var tier_two_roll := rng.randi_range(0, 99)
				var pool := tier_two if not tier_two.is_empty() and (other_tier_one.is_empty() or tier_two_roll < STARTING_SECOND_COMPANY_TIER_TWO_PERCENT) else other_tier_one
				var second := String(pool[rng.randi_range(0, pool.size() - 1)])
				stacks.append({"unit_id": second, "count": _starting_company_size(rng, second, STARTING_SECOND_COMPANY_GROWTH_SHARE)})
	for index in range(stacks.size()):
		stacks[index][ARMY_SLOT_INDEX_KEY] = index
	return {"id": "%s_army" % hero_id, "name": "Field Army", "stacks": stacks}

static func army_has_troops(army: Variant) -> bool:
	return HumanEngine.native_writing(&"HeroCommandRules.army_has_troops", [army])

## A new hero's growth seed (HeroProgressionRules.command_gain_stat): from the
## session and hero when a session is known, so the tavern's preview and the
## hire it shows roll alike, else drawn at random.
static func new_growth_seed(hero_id: String, session_source: Variant = null) -> String:
	if session_source is SessionStateStoreScript.SessionData:
		return "%s|%s|%s" % [String(session_source.session_id), String(session_source.scenario_id), hero_id]
	var rng := RandomNumberGenerator.new()
	rng.randomize()
	return "%08x%08x" % [rng.randi(), rng.randi()]

## A new game's start hero is built before its session exists, so it drew a
## random growth seed. The session's creator calls this once the session is
## made, so the start hero is seeded from it like every later hire and two new
## games on the same map and seed level it up alike. Never called on load: a
## saved hero keeps the seed it was saved with.
static func seed_start_heroes_from_session(session: SessionStateStoreScript.SessionData) -> void:
	HumanEngine.native_writing(&"HeroCommandRules.seed_start_heroes_from_session", [session])

static func movement_max_for_hero(hero_state: Dictionary, movement_source: Variant = null) -> int:
	var artifact_bonuses = ArtifactRulesScript.aggregate_bonuses(hero_state)
	var specialty_bonuses = HeroProgressionRulesScript.aggregate_bonuses(hero_state)
	var difficulty_bonus := 0
	if movement_source is SessionStateStoreScript.SessionData:
		difficulty_bonus = DifficultyRulesScript.movement_bonus(movement_source)
	else:
		var difficulty_id: String = DifficultyRulesScript.normalize_difficulty(String(movement_source))
		difficulty_bonus = int(DifficultyRulesScript.profile_for_difficulty(difficulty_id).get("movement_bonus", 0))
	return max(
		1,
		int(hero_state.get("base_movement", 10))
		+ max(0, int(hero_state.get("level", 1)) - 1)
		+ int(artifact_bonuses.get("overworld_movement", 0))
		+ int(specialty_bonuses.get("overworld_movement", 0))
		+ difficulty_bonus
		+ _week_bonus(hero_state, "movement")
		+ maxi(0, int(hero_state.get("movement_carry", 0)))
	)

# Visit buildings can raise movement or mana until the week ends.
static func _week_bonus(hero_state: Dictionary, key: String) -> int:
	var bonuses = hero_state.get("week_bonuses", {})
	return int(bonuses.get(key, 0)) if bonuses is Dictionary else 0

static func scouting_radius_for_hero(hero_state: Dictionary) -> int:
	if _human_engine_mode == HumanEngine.GDSCRIPT:
		return scouting_radius_for_hero__gd(hero_state)
	if _human_engine_mode == HumanEngine.NATIVE:
		return HumanEngine.native_writing(&"HeroCommandRules.scouting_radius_for_hero", [hero_state])
	var before := HumanEngine.before_writing(&"HeroCommandRules.scouting_radius_for_hero", [hero_state])
	var result = scouting_radius_for_hero__gd(hero_state)
	HumanEngine.check_writing(&"HeroCommandRules.scouting_radius_for_hero", before, [hero_state], result)
	return result

static func scouting_radius_for_hero__gd(hero_state: Dictionary) -> int:
	var artifact_bonuses = ArtifactRulesScript.aggregate_bonuses(hero_state)
	var specialty_bonuses = HeroProgressionRulesScript.aggregate_bonuses(hero_state)
	return max(
		1,
		BASE_SCOUT_RADIUS
		+ int(artifact_bonuses.get("scouting_radius", 0))
		+ int(specialty_bonuses.get("scouting_radius", 0))
	)

# Sight covers a round area: a tile is in range when its centre lies within
# radius + 1/2 tiles of the source, which keeps the rim free of one-tile nubs.
# Half-width of the round sight area on the row dy tiles from its centre, or
# -1 when the row lies outside it.
static func scout_row_half_width(dy: int, radius: int) -> int:
	var remaining := radius * (radius + 1) - dy * dy
	if remaining < 0:
		return -1
	var half_width := int(sqrt(float(remaining)))
	while (half_width + 1) * (half_width + 1) <= remaining:
		half_width += 1
	while half_width * half_width > remaining:
		half_width -= 1
	return half_width

static func active_hero(session: SessionStateStoreScript.SessionData) -> Dictionary:
	if session == null:
		return {}
	var active_hero_id := String(session.overworld.get("active_hero_id", ""))
	for hero in session.overworld.get("player_heroes", []):
		if hero is Dictionary and String(hero.get("id", "")) == active_hero_id:
			return hero
	return {}

static func primary_hero(session: SessionStateStoreScript.SessionData) -> Dictionary:
	return primary_hero_from_overworld(session.overworld if session != null else {}, session.hero_id if session != null else "")

static func hero_by_id(session: SessionStateStoreScript.SessionData, hero_id: String) -> Dictionary:
	if _human_engine_mode == HumanEngine.GDSCRIPT:
		return hero_by_id__gd(session, hero_id)
	if _human_engine_mode == HumanEngine.NATIVE:
		return HumanEngine.native_writing(&"HeroCommandRules.hero_by_id", [session, hero_id])
	var before := HumanEngine.before_writing(&"HeroCommandRules.hero_by_id", [session, hero_id])
	var result = hero_by_id__gd(session, hero_id)
	HumanEngine.check_writing(&"HeroCommandRules.hero_by_id", before, [session, hero_id], result)
	return result

static func hero_by_id__gd(session: SessionStateStoreScript.SessionData, hero_id: String) -> Dictionary:
	if session == null or hero_id == "":
		return {}
	for hero in session.overworld.get("player_heroes", []):
		if hero is Dictionary and String(hero.get("id", "")) == hero_id:
			return hero
	return {}

static func hero_inspection_snapshot(session: SessionStateStoreScript.SessionData, hero_id: String) -> Dictionary:
	return HumanEngine.native_writing(&"HeroCommandRules.hero_inspection_snapshot", [session, hero_id])

static func player_hero_count(session: SessionStateStoreScript.SessionData) -> int:
	return HumanEngine.native_writing(&"HeroCommandRules.player_hero_count", [session])

static func spend_active_hero_movement(session: SessionStateStoreScript.SessionData, amount: int, reason: String = "") -> Dictionary:
	return HumanEngine.native_writing(&"HeroCommandRules.spend_active_hero_movement", [session, amount, reason])

static func commit_active_hero(session: SessionStateStoreScript.SessionData) -> void:
	DayEngine.native_writing(&"HeroCommandRules.commit_active_hero", [session])

static func set_active_hero(session: SessionStateStoreScript.SessionData, hero_id: String) -> Dictionary:
	normalize_session(session)
	if hero_id == "":
		return {"ok": false, "message": "No hero was selected."}
	commit_active_hero(session)
	var hero := hero_by_id(session, hero_id)
	if hero.is_empty():
		return {"ok": false, "message": "That hero is not under command."}
	if String(session.overworld.get("active_hero_id", "")) == hero_id:
		return {"ok": true, "message": "%s is already in command." % String(hero.get("name", "The hero"))}
	session.overworld["active_hero_id"] = hero_id
	_sync_active_hero_mirror(session)
	return {"ok": true, "message": "%s takes command." % String(hero.get("name", "The hero"))}

static func hero_template(payload: Dictionary) -> Dictionary:
	return HumanEngine.native_writing(&"HeroCommandRules.hero_template", [payload])

static func hero_faction_label(payload: Dictionary, fallback_faction_id: String = "") -> String:
	return HumanEngine.native_writing(&"HeroCommandRules.hero_faction_label", [payload, fallback_faction_id])

static func hero_identity_summary(payload: Dictionary) -> String:
	var template := hero_template(payload)
	return String(template.get("identity_summary", ""))

static func hero_role_label(payload: Dictionary) -> String:
	return HumanEngine.native_writing(&"HeroCommandRules.hero_role_label", [payload])

static func hero_identity_context_line(payload: Dictionary, fallback_faction_id: String = "") -> String:
	return HumanEngine.native_writing(&"HeroCommandRules.hero_identity_context_line", [payload, fallback_faction_id])

static func hero_progress_context_line(hero_state: Dictionary) -> String:
	return HumanEngine.native_writing(&"HeroCommandRules.hero_progress_context_line", [hero_state])

static func hero_readiness_context_line(hero_state: Dictionary, include_position: bool = false) -> String:
	return HumanEngine.native_writing(&"HeroCommandRules.hero_readiness_context_line", [hero_state, include_position])

static func hero_profile_summary(payload: Dictionary, include_focus: bool = false) -> String:
	return HumanEngine.native_writing(&"HeroCommandRules.hero_profile_summary", [payload, include_focus])

static func describe_roster(session: SessionStateStoreScript.SessionData, stationed_only: bool = false, town: Dictionary = {}) -> String:
	normalize_session(session)
	var lines := ["Command"]
	var active_hero_id := String(session.overworld.get("active_hero_id", ""))
	var player_heroes = session.overworld.get("player_heroes", [])
	for hero in player_heroes:
		if not (hero is Dictionary):
			continue
		if stationed_only and not _hero_is_stationed_at_town(hero, town):
			continue
		lines.append("- %s" % _hero_roster_line(hero, active_hero_id))
	if lines.size() == 1:
		lines.append("- No stationed heroes")
	return "\n".join(lines)

static func stationed_heroes(session: SessionStateStoreScript.SessionData, town: Dictionary) -> Array:
	if _human_engine_mode == HumanEngine.GDSCRIPT:
		return stationed_heroes__gd(session, town)
	if _human_engine_mode == HumanEngine.NATIVE:
		return HumanEngine.native_writing(&"HeroCommandRules.stationed_heroes", [session, town])
	var before := HumanEngine.before_writing(&"HeroCommandRules.stationed_heroes", [session, town])
	var result = stationed_heroes__gd(session, town)
	HumanEngine.check_writing(&"HeroCommandRules.stationed_heroes", before, [session, town], result)
	return result

static func stationed_heroes__gd(session: SessionStateStoreScript.SessionData, town: Dictionary) -> Array:
	var stationed := []
	if session == null or town.is_empty():
		return stationed
	for hero in session.overworld.get("player_heroes", []):
		if hero is Dictionary and _hero_is_stationed_at_town(hero, town):
			stationed.append(hero)
	return stationed

static func town_defending_hero(session: SessionStateStoreScript.SessionData, town: Dictionary, preferred_hero_id: String = "") -> Dictionary:
	var candidates := stationed_heroes(session, town)
	if preferred_hero_id != "":
		for hero in candidates:
			if String(hero.get("id", "")) == preferred_hero_id: return hero
	# The garrison hero's army is the garrison, so it holds the walls.
	var garrison_hero := town_garrison_hero(session, town)
	if not garrison_hero.is_empty():
		return garrison_hero
	for identity in [String(session.overworld.get("active_hero_id", "")) if session != null else ""]:
		if identity == "": continue
		for hero in candidates:
			if String(hero.get("id", "")) == identity: return hero
	for hero in candidates:
		if bool(hero.get("is_primary", false)): return hero
	return candidates[0] if not candidates.is_empty() else {}

## HoMM-style town slots. Both heroes stand on the town entrance tile: one may
## hold the garrison (its army is the garrison row) and one visits at the gate.
static func town_garrison_hero(session: SessionStateStoreScript.SessionData, town: Dictionary) -> Dictionary:
	if _human_engine_mode == HumanEngine.GDSCRIPT:
		return town_garrison_hero__gd(session, town)
	if _human_engine_mode == HumanEngine.NATIVE:
		return HumanEngine.native_writing(&"HeroCommandRules.town_garrison_hero", [session, town])
	var before := HumanEngine.before_writing(&"HeroCommandRules.town_garrison_hero", [session, town])
	var result = town_garrison_hero__gd(session, town)
	HumanEngine.check_writing(&"HeroCommandRules.town_garrison_hero", before, [session, town], result)
	return result

static func town_garrison_hero__gd(session: SessionStateStoreScript.SessionData, town: Dictionary) -> Dictionary:
	if session == null or town.is_empty():
		return {}
	var hero_id := String(town.get(TOWN_GARRISON_HERO_KEY, ""))
	if hero_id == "":
		return {}
	var hero := hero_by_id(session, hero_id)
	if hero.is_empty() or not _hero_is_stationed_at_town(hero, town):
		return {}
	return hero

static func town_visiting_hero(session: SessionStateStoreScript.SessionData, town: Dictionary) -> Dictionary:
	return HumanEngine.native_writing(&"HeroCommandRules.town_visiting_hero", [session, town])

## The army slot holder of the garrison row: the garrison hero, else the town.
static func town_garrison_holder_id(session: SessionStateStoreScript.SessionData, town: Dictionary) -> String:
	if _human_engine_mode == HumanEngine.GDSCRIPT:
		return town_garrison_holder_id__gd(session, town)
	if _human_engine_mode == HumanEngine.NATIVE:
		return HumanEngine.native_writing(&"HeroCommandRules.town_garrison_holder_id", [session, town])
	var before := HumanEngine.before_writing(&"HeroCommandRules.town_garrison_holder_id", [session, town])
	var result = town_garrison_holder_id__gd(session, town)
	HumanEngine.check_writing(&"HeroCommandRules.town_garrison_holder_id", before, [session, town], result)
	return result

static func town_garrison_holder_id__gd(session: SessionStateStoreScript.SessionData, town: Dictionary) -> String:
	var hero := town_garrison_hero(session, town)
	return String(hero.get("id", "")) if not hero.is_empty() else HOLDER_GARRISON

## Places `hero_id` in the garrison, or sends the garrison hero out to the gate
## when `hero_id` is "". Entering an unheld garrison takes its troops into the
## hero's army (they must fit in seven slots); entering a held garrison swaps the
## two heroes, the old garrison hero leaving with its own army.
static func set_town_garrison_hero(session: SessionStateStoreScript.SessionData, town: Dictionary, hero_id: String) -> Dictionary:
	return HumanEngine.native_writing(&"HeroCommandRules.set_town_garrison_hero", [session, town, hero_id])

## Merges `incoming` stacks into `army` (same units join, new units take free
## slots). Returns the slotted result, or [] when the units do not fit.
static func merge_stacks_into_army(army: Array, incoming: Array) -> Array:
	var merged := _slotted_stacks(army)
	for stack_value in incoming:
		if not (stack_value is Dictionary):
			continue
		var unit_id := String(stack_value.get("unit_id", ""))
		var count := int(stack_value.get("count", 0))
		if unit_id == "" or count <= 0:
			continue
		var joined := false
		for index in range(merged.size()):
			if String(merged[index].get("unit_id", "")) == unit_id:
				merged[index]["count"] = int(merged[index].get("count", 0)) + count
				joined = true
				break
		if joined:
			continue
		var claimed := {}
		for stack in merged:
			claimed[int(stack.get(ARMY_SLOT_INDEX_KEY, -1))] = true
		var slot := _first_open_army_slot(claimed)
		if slot < 0:
			return []
		var placed: Dictionary = stack_value.duplicate(true)
		placed[ARMY_SLOT_INDEX_KEY] = slot
		merged.append(placed)
	merged.sort_custom(_stack_slot_less)
	return merged

## Clears garrison heroes that left, lost their town or no longer exist, and
## once per save gives towns holding two of the player's heroes a garrison hero
## (the commander not in active use), when the garrison's troops fit its army.
static func _normalize_town_garrison_heroes(session: SessionStateStoreScript.SessionData) -> void:
	var migrate := int(session.overworld.get(TOWN_GARRISON_HEROES_VERSION_KEY, 0)) < TOWN_GARRISON_HEROES_VERSION
	for town_value in session.overworld.get("towns", []):
		if not (town_value is Dictionary):
			continue
		var town: Dictionary = town_value
		var hero_id := String(town.get(TOWN_GARRISON_HERO_KEY, ""))
		if hero_id != "":
			if String(town.get("owner", "neutral")) != "player" or town_garrison_hero(session, town).is_empty():
				town.erase(TOWN_GARRISON_HERO_KEY)
			continue
		if not migrate or String(town.get("owner", "neutral")) != "player":
			continue
		var stationed := stationed_heroes(session, town)
		if stationed.size() < 2:
			continue
		var active_hero_id := String(session.overworld.get("active_hero_id", ""))
		for hero in stationed:
			var candidate_id := String(hero.get("id", ""))
			if candidate_id == active_hero_id:
				continue
			var town_stacks: Array = town.get("garrison", []) if town.get("garrison", []) is Array else []
			var merged := merge_stacks_into_army(_holder_stacks(session, town, candidate_id), town_stacks)
			if merged.is_empty() and _valid_stack_count(town_stacks) > 0:
				continue
			if _valid_stack_count(town_stacks) > 0:
				_set_holder_stacks(session, town, candidate_id, merged)
				_set_holder_stacks(session, town, HOLDER_GARRISON, [])
			town[TOWN_GARRISON_HERO_KEY] = candidate_id
			break
	session.overworld[TOWN_GARRISON_HEROES_VERSION_KEY] = TOWN_GARRISON_HEROES_VERSION

static func town_recruitment_destination(session: SessionStateStoreScript.SessionData, town: Dictionary) -> Dictionary:
	return HumanEngine.native_writing(&"HeroCommandRules.town_recruitment_destination", [session, town])

static func town_defense_force(session: SessionStateStoreScript.SessionData, town: Dictionary, preferred_hero_id: String = "") -> Dictionary:
	if _human_engine_mode == HumanEngine.GDSCRIPT:
		return town_defense_force__gd(session, town, preferred_hero_id)
	if _human_engine_mode == HumanEngine.NATIVE:
		return HumanEngine.native_writing(&"HeroCommandRules.town_defense_force", [session, town, preferred_hero_id])
	var before := HumanEngine.before_writing(&"HeroCommandRules.town_defense_force", [session, town, preferred_hero_id])
	var result = town_defense_force__gd(session, town, preferred_hero_id)
	HumanEngine.check_writing(&"HeroCommandRules.town_defense_force", before, [session, town, preferred_hero_id], result)
	return result

static func town_defense_force__gd(session: SessionStateStoreScript.SessionData, town: Dictionary, preferred_hero_id: String = "") -> Dictionary:
	# A town fields its garrison and ONE eligible visiting hero, not the remotely
	# selected army or every reserve commander. Battle setup consumes these rows.
	var hero := town_defending_hero(session, town, preferred_hero_id)
	var stacks := []
	var garrison_troops := 0
	var garrison_stacks := 0
	var hero_troops := 0
	var hero_stacks := 0
	for source_type in ["hero_army", "town_garrison"]:
		var rows: Array = hero.get("army", {}).get("stacks", []) if source_type == "hero_army" else town.get("garrison", [])
		for row in rows:
			if not row is Dictionary: continue
			var count := maxi(0, int(row.get("count", 0)))
			var unit_id := String(row.get("unit_id", ""))
			if count == 0 or unit_id == "": continue
			var source := {"source_type": source_type, "town_placement_id": String(town.get("placement_id", ""))}
			if source_type == "hero_army": source["hero_id"] = String(hero.get("id", ""))
			var descriptor := {"unit_id": unit_id, "count": count, "source": source}
			var slot := int(row.get("slot_index", -1))
			if slot >= 0 and slot < ARMY_SLOT_COUNT: descriptor["slot_index"] = slot
			stacks.append(descriptor)
			if source_type == "hero_army":
				hero_troops += count
				hero_stacks += 1
			else:
				garrison_troops += count
				garrison_stacks += 1
	return {"hero": hero, "stacks": stacks, "troops": garrison_troops + hero_troops,
		"stack_count": stacks.size(), "garrison_troops": garrison_troops, "garrison_stacks": garrison_stacks,
		"hero_troops": hero_troops, "hero_stacks": hero_stacks}

static func describe_town_defense_force(session: SessionStateStoreScript.SessionData, town: Dictionary) -> String:
	if _human_engine_mode == HumanEngine.GDSCRIPT:
		return describe_town_defense_force__gd(session, town)
	if _human_engine_mode == HumanEngine.NATIVE:
		return HumanEngine.native_writing(&"HeroCommandRules.describe_town_defense_force", [session, town])
	var before := HumanEngine.before_writing(&"HeroCommandRules.describe_town_defense_force", [session, town])
	var result = describe_town_defense_force__gd(session, town)
	HumanEngine.check_writing(&"HeroCommandRules.describe_town_defense_force", before, [session, town], result)
	return result

static func describe_town_defense_force__gd(session: SessionStateStoreScript.SessionData, town: Dictionary) -> String:
	var force := town_defense_force(session, town)
	var hero: Dictionary = force.hero
	return "Defenders: %d troops / %d stacks\nGarrison: %d troops / %d stacks%s\n%s" % [
		force.troops, force.stack_count, force.garrison_troops, force.garrison_stacks,
		" (empty)" if int(force.garrison_troops) == 0 else "",
		"Visiting defender: %s — %d troops / %d stacks" % [String(hero.get("name", hero.get("id", "Hero"))), force.hero_troops, force.hero_stacks]
		if not hero.is_empty() else "No visiting defender. Remote heroes do not defend this town."]

static func empty_owned_towns(session: SessionStateStoreScript.SessionData) -> Array:
	if _human_engine_mode == HumanEngine.GDSCRIPT:
		return empty_owned_towns__gd(session)
	if _human_engine_mode == HumanEngine.NATIVE:
		return HumanEngine.native_writing(&"HeroCommandRules.empty_owned_towns", [session])
	var before := HumanEngine.before_writing(&"HeroCommandRules.empty_owned_towns", [session])
	var result = empty_owned_towns__gd(session)
	HumanEngine.check_writing(&"HeroCommandRules.empty_owned_towns", before, [session], result)
	return result

static func empty_owned_towns__gd(session: SessionStateStoreScript.SessionData) -> Array:
	# Own troops are known without consulting hidden enemy positions/AI plans.
	var result := []
	if session == null: return result
	for town in session.overworld.get("towns", []):
		if town is Dictionary and String(town.get("owner", "")) == "player" and int(town_defense_force(session, town).troops) == 0:
			result.append({"placement_id": String(town.get("placement_id", "")),
				"name": String(ContentService.get_town(String(town.get("town_id", ""))).get("name", town.get("placement_id", "Town")))})
	return result

static func describe_tavern(session: SessionStateStoreScript.SessionData, town: Dictionary) -> String:
	var hall_name := String(ContentService.get_building(HALL_BUILDING_ID).get("name", "Wayfarers Hall"))
	var lines := [hall_name]
	if not town_has_hall(town):
		lines.append("- Build %s to recruit additional commanders." % hall_name)
		return "\n".join(lines)
	if player_hero_count(session) >= HERO_LIMIT:
		lines.append("- The command roster is already full.")
		return "\n".join(lines)
	if recruitable_hero_ids(session).is_empty():
		lines.append("- No additional commanders are currently available for hire.")
		return "\n".join(lines)

	var actions := get_tavern_actions(session, town)
	if actions.is_empty():
		lines.append("- No commanders are currently available for hire.")
		return "\n".join(lines)

	for action in actions:
		if not (action is Dictionary):
			continue
		lines.append("- %s | %s" % [String(action.get("label", "")), String(action.get("summary", ""))])
	return "\n".join(lines)

static func get_tavern_actions(session: SessionStateStoreScript.SessionData, town: Dictionary) -> Array:
	return HumanEngine.native_writing(&"HeroCommandRules.get_tavern_actions", [session, town])

static func describe_town_transfer(session: SessionStateStoreScript.SessionData, town: Dictionary) -> String:
	normalize_session(session)
	var lines := ["Transfer"]
	lines.append("- Garrison | %s" % _stack_summary_from_array(town.get("garrison", [])))
	for hero in stationed_heroes(session, town):
		lines.append("- %s | %s" % [String(hero.get("name", "Hero")), _army_summary(hero.get("army", {}))])
	return "\n".join(lines)

static func army_addition_plan(stacks_value: Variant, additions: Dictionary) -> Dictionary:
	if _human_engine_mode == HumanEngine.GDSCRIPT:
		return army_addition_plan__gd(stacks_value, additions)
	if _human_engine_mode == HumanEngine.NATIVE:
		return HumanEngine.native_writing(&"HeroCommandRules.army_addition_plan", [stacks_value, additions])
	var before := HumanEngine.before_writing(&"HeroCommandRules.army_addition_plan", [stacks_value, additions])
	var result = army_addition_plan__gd(stacks_value, additions)
	HumanEngine.check_writing(&"HeroCommandRules.army_addition_plan", before, [stacks_value, additions], result)
	return result

static func army_addition_plan__gd(stacks_value: Variant, additions: Dictionary) -> Dictionary:
	# Plan before charging, consuming rewards or removing source troops. A
	# rejected manifest must never discard troops, including legacy excess.
	var stacks: Array = stacks_value.duplicate(true) if stacks_value is Array else []
	var occupied := _valid_stack_count(stacks)
	if occupied <= ARMY_SLOT_COUNT:
		stacks = _slotted_stacks(stacks)
	var unit_ids := additions.keys()
	unit_ids.sort()
	for unit_id_value in unit_ids:
		var unit_id := String(unit_id_value)
		var amount := maxi(0, int(additions.get(unit_id_value, 0)))
		if unit_id == "" or amount == 0:
			continue
		var matching := -1
		for index in range(stacks.size()):
			if stacks[index] is Dictionary and String(stacks[index].get("unit_id", "")) == unit_id and int(stacks[index].get("count", 0)) > 0:
				matching = index
				break
		if matching >= 0:
			stacks[matching]["count"] = int(stacks[matching].get("count", 0)) + amount
			continue
		if occupied >= ARMY_SLOT_COUNT:
			return {"ok": false, "reason": "army_capacity", "message": "All seven army slots are occupied. Transfer or merge troops before adding a new unit type."}
		var claimed := {}
		for stack in stacks:
			claimed[int(stack.get(ARMY_SLOT_INDEX_KEY, -1))] = true
		stacks.append({"unit_id": unit_id, "count": amount, ARMY_SLOT_INDEX_KEY: _first_open_army_slot(claimed)})
		occupied += 1
	return {"ok": true, "stacks": stacks}

## Adds what fits instead of refusing: unit types matching a stack merge, new
## types take free slots in unit-id order, and the types left without a slot
## come back as overflow.
static func army_addition_split(stacks_value: Variant, additions: Dictionary) -> Dictionary:
	var stacks: Array = stacks_value.duplicate(true) if stacks_value is Array else []
	if _valid_stack_count(stacks) <= ARMY_SLOT_COUNT:
		stacks = _slotted_stacks(stacks)
	var added := {}
	var overflow := {}
	var unit_ids := additions.keys()
	unit_ids.sort()
	for unit_id_value in unit_ids:
		var unit_id := String(unit_id_value)
		var amount := maxi(0, int(additions.get(unit_id_value, 0)))
		if unit_id == "" or amount == 0:
			continue
		var plan := army_addition_plan(stacks, {unit_id: amount})
		if bool(plan.get("ok", false)):
			stacks = plan.get("stacks", stacks)
			added[unit_id] = amount
		else:
			overflow[unit_id] = amount
	return {"stacks": stacks, "added": added, "overflow": overflow}

static func army_slot_snapshot(session: SessionStateStoreScript.SessionData, town: Dictionary, holder_id: String) -> Dictionary:
	return HumanEngine.native_writing(&"HeroCommandRules.army_slot_snapshot", [session, town, holder_id])

static func manage_army_slots(session: SessionStateStoreScript.SessionData, town: Dictionary, source_holder_id: String, source_slot_index: int, target_holder_id: String, target_slot_index: int, amount_token: String = "all") -> Dictionary:
	return HumanEngine.native_writing(&"HeroCommandRules.manage_army_slots", [session, town, source_holder_id, source_slot_index, target_holder_id, target_slot_index, amount_token])

static func field_rendezvous_heroes(session: SessionStateStoreScript.SessionData) -> Array:
	return HumanEngine.native_writing(&"HeroCommandRules.field_rendezvous_heroes", [session])

static func describe_field_rendezvous(session: SessionStateStoreScript.SessionData) -> String:
	var active := active_hero(session)
	var rendezvous := field_rendezvous_heroes(session)
	if active.is_empty() or rendezvous.is_empty():
		return "No friendly commander is present for a field rendezvous."
	var lines := ["Field Rendezvous", "- Active: %s | %s | Gear %d | Spells %d" % [
		String(active.get("name", "Commander")),
		_army_summary(active.get("army", {})),
		ArtifactRulesScript.owned_artifact_ids(active).size(),
		SpellRulesScript.known_spells(active).size(),
	]]
	for hero_value in rendezvous:
		var hero: Dictionary = hero_value if hero_value is Dictionary else {}
		lines.append("- Reserve: %s | %s | Gear %d | Spells %d" % [
			String(hero.get("name", "Commander")),
			_army_summary(hero.get("army", {})),
			ArtifactRulesScript.owned_artifact_ids(hero).size(),
			SpellRulesScript.known_spells(hero).size(),
		])
	return "\n".join(lines)

static func get_field_transfer_actions(session: SessionStateStoreScript.SessionData) -> Array:
	normalize_session(session)
	var actions := []
	if session == null:
		return actions
	var active := active_hero(session)
	if active.is_empty():
		return actions
	for reserve_value in field_rendezvous_heroes(session):
		if not (reserve_value is Dictionary):
			continue
		var reserve: Dictionary = reserve_value
		_append_field_transfer_actions(actions, active, reserve)
		_append_field_transfer_actions(actions, reserve, active)
	return actions

static func get_field_artifact_transfer_actions(session: SessionStateStoreScript.SessionData) -> Array:
	normalize_session(session)
	var actions := []
	if session == null:
		return actions
	var active := active_hero(session)
	if active.is_empty():
		return actions
	for reserve_value in field_rendezvous_heroes(session):
		if not (reserve_value is Dictionary):
			continue
		var reserve: Dictionary = reserve_value
		_append_field_artifact_transfer_actions(actions, active, reserve)
		_append_field_artifact_transfer_actions(actions, reserve, active)
	return actions

static func get_field_spell_share_actions(session: SessionStateStoreScript.SessionData) -> Array:
	normalize_session(session)
	var actions := []
	if session == null:
		return actions
	var active := active_hero(session)
	if active.is_empty():
		return actions
	for reserve_value in field_rendezvous_heroes(session):
		if not (reserve_value is Dictionary):
			continue
		var reserve: Dictionary = reserve_value
		_append_field_spell_share_actions(actions, active, reserve)
		_append_field_spell_share_actions(actions, reserve, active)
	return actions

static func transfer_field_stack(session: SessionStateStoreScript.SessionData, source_hero_id: String, target_hero_id: String, unit_id: String, amount_token: String) -> Dictionary:
	return HumanEngine.native_writing(&"HeroCommandRules.transfer_field_stack", [session, source_hero_id, target_hero_id, unit_id, amount_token])

static func transfer_field_artifact(session: SessionStateStoreScript.SessionData, source_hero_id: String, target_hero_id: String, artifact_id: String) -> Dictionary:
	return HumanEngine.native_writing(&"HeroCommandRules.transfer_field_artifact", [session, source_hero_id, target_hero_id, artifact_id])

static func teach_field_spell(session: SessionStateStoreScript.SessionData, source_hero_id: String, target_hero_id: String, spell_id: String) -> Dictionary:
	return HumanEngine.native_writing(&"HeroCommandRules.teach_field_spell", [session, source_hero_id, target_hero_id, spell_id])

# Hero meeting screen (HoMM-style exchange between two commanders on one
# field tile). Slot moves, merges, swaps and splits use manage_army_slots; the
# orders below cover the bulk and slot-precise artifact handoffs.
const FIELD_ARTIFACT_PACK_SLOT := "pack"

static func field_slot_action_id(source_hero_id: String, source_slot_index: int, target_hero_id: String, target_slot_index: int, amount_token: String = "all") -> String:
	return HumanEngine.native(&"HeroCommandRules.field_slot_action_id", [source_hero_id, source_slot_index, target_hero_id, target_slot_index, amount_token])

static func field_troops_all_action_id(source_hero_id: String, target_hero_id: String) -> String:
	return HumanEngine.native(&"HeroCommandRules.field_troops_all_action_id", [source_hero_id, target_hero_id])

static func field_artifact_place_action_id(source_hero_id: String, target_hero_id: String, artifact_id: String, target_slot: String = "") -> String:
	return HumanEngine.native(&"HeroCommandRules.field_artifact_place_action_id", [source_hero_id, target_hero_id, artifact_id, target_slot])

static func field_artifacts_all_action_id(source_hero_id: String, target_hero_id: String) -> String:
	return HumanEngine.native(&"HeroCommandRules.field_artifacts_all_action_id", [source_hero_id, target_hero_id])

static func field_spell_share_action_id(source_hero_id: String, target_hero_id: String, spell_id: String) -> String:
	return HumanEngine.native(&"HeroCommandRules.field_spell_share_action_id", [source_hero_id, target_hero_id, spell_id])

static func field_exchange_state(session: SessionStateStoreScript.SessionData, partner_hero_id: String = "") -> Dictionary:
	return HumanEngine.native_writing(&"HeroCommandRules.field_exchange_state", [session, partner_hero_id])

## The leading heroes that have fallen on a generated map, by id: none of them
## is brought back from the scenario or made leader again, and the next hero
## hired leads when no other is left.
const PRIMARY_FALLEN_FLAG := "primary_hero_fallen"

static func town_has_hall(town: Dictionary) -> bool:
	return HALL_BUILDING_ID in town.get("built_buildings", [])

static func hero_recruit_cost(hero_template: Dictionary) -> Dictionary:
	if _human_engine_mode == HumanEngine.GDSCRIPT:
		return hero_recruit_cost__gd(hero_template)
	if _human_engine_mode == HumanEngine.NATIVE:
		return HumanEngine.native_writing(&"HeroCommandRules.hero_recruit_cost", [hero_template])
	var before := HumanEngine.before_writing(&"HeroCommandRules.hero_recruit_cost", [hero_template])
	var result = hero_recruit_cost__gd(hero_template)
	HumanEngine.check_writing(&"HeroCommandRules.hero_recruit_cost", before, [hero_template], result)
	return result

static func hero_recruit_cost__gd(hero_template: Dictionary) -> Dictionary:
	var cost = hero_template.get("recruit_cost", DEFAULT_RECRUIT_COST)
	return _normalize_resources(cost)

## The two heroes every player tavern offers this week. A new pair is drawn
## at the start of each week from the faction's hireable heroes; a hired
## hero's place stays empty until then. Reading never changes the session.
static func tavern_offer_ids(session: SessionStateStoreScript.SessionData) -> Array:
	return HumanEngine.native_writing(&"HeroCommandRules.tavern_offer_ids", [session])

static func tavern_week(session: SessionStateStoreScript.SessionData) -> int:
	return maxi(0, (int(session.day) - 1) / 7) if session != null else 0

## What hiring `hero_id` this week brings: {hero_id, week, level, army}. Level
## 1 most weeks, 2 about one offer in ten, 3 about one in thirty. Decided with
## the week's draw from the session, week and hero, never at hire time, so
## repeated reads, saves, loads and a hire in the other tavern place never
## reroll it. `week` defaults to the current tavern week.
static func tavern_offer(session: SessionStateStoreScript.SessionData, hero_id: String, week: int = -1) -> Dictionary:
	var hero_template := ContentService.get_hero(hero_id)
	if session == null or hero_template.is_empty():
		return {}
	var offer_week := week if week >= 0 else tavern_week(session)
	var seed_key := "%s|%s|tavern_offer|%d|%s" % [String(session.session_id), String(session.scenario_id), offer_week, hero_id]
	var roll := _seeded_rng("%s|level" % seed_key).randi_range(0, 99)
	var level := 1
	if roll < TAVERN_LEVEL_THREE_PERCENT:
		level = 3
	elif roll < TAVERN_LEVEL_THREE_PERCENT + TAVERN_LEVEL_TWO_PERCENT:
		level = 2
	return {"hero_id": hero_id, "week": offer_week, "level": level, "army": starting_army_for_hero(hero_template, seed_key)}

static func recruitable_hero_ids(session: SessionStateStoreScript.SessionData) -> Array:
	return HumanEngine.native_writing(&"HeroCommandRules.recruitable_hero_ids", [session])

static func primary_hero_from_overworld(overworld_state: Variant, primary_hero_id: String = "") -> Dictionary:
	if overworld_state is Dictionary:
		var player_heroes = overworld_state.get("player_heroes", [])
		if player_heroes is Array:
			for hero in player_heroes:
				if hero is Dictionary and bool(hero.get("is_primary", false)):
					return hero
			for hero in player_heroes:
				if hero is Dictionary and String(hero.get("id", "")) == primary_hero_id:
					return hero
			for hero in player_heroes:
				if hero is Dictionary:
					return hero
		var hero = overworld_state.get("hero", {})
		if hero is Dictionary:
			return hero
	return {}

static func active_hero_from_overworld(overworld_state: Variant) -> Dictionary:
	if overworld_state is Dictionary:
		var active_hero_id := String(overworld_state.get("active_hero_id", ""))
		var player_heroes = overworld_state.get("player_heroes", [])
		if player_heroes is Array:
			for hero in player_heroes:
				if hero is Dictionary and String(hero.get("id", "")) == active_hero_id:
					return hero
		var hero = overworld_state.get("hero", {})
		if hero is Dictionary:
			return hero
	return {}

static func closest_hero_target(session: SessionStateStoreScript.SessionData, origin: Vector2i = Vector2i.ZERO, level: int = 0) -> Dictionary:
	normalize_session(session)
	var best := {}
	for hero in session.overworld.get("player_heroes", []):
		if not (hero is Dictionary) or not OverworldLevelRulesScript.on_level(hero, level):
			continue
		var position := _normalize_position(hero.get("position", {}))
		var distance: int = abs(origin.x - int(position.get("x", 0))) + abs(origin.y - int(position.get("y", 0)))
		if best.is_empty() or distance < int(best.get("distance", 9999)):
			best = {
				"id": String(hero.get("id", "")),
				"name": String(hero.get("name", "the hero")),
				"x": int(position.get("x", 0)),
				"y": int(position.get("y", 0)),
				"distance": distance,
			}
	if not best.is_empty() and level != 0:
		best["level"] = level
	return best

static func hero_position_by_id(session: SessionStateStoreScript.SessionData, hero_id: String) -> Dictionary:
	var hero := hero_by_id(session, hero_id)
	return _normalize_position(hero.get("position", {}))

static func hero_positions(session: SessionStateStoreScript.SessionData) -> Array:
	if _human_engine_mode == HumanEngine.GDSCRIPT:
		return hero_positions__gd(session)
	if _human_engine_mode == HumanEngine.NATIVE:
		return HumanEngine.native_writing(&"HeroCommandRules.hero_positions", [session])
	var before := HumanEngine.before_writing(&"HeroCommandRules.hero_positions", [session])
	var result = hero_positions__gd(session)
	HumanEngine.check_writing(&"HeroCommandRules.hero_positions", before, [session], result)
	return result

static func hero_positions__gd(session: SessionStateStoreScript.SessionData) -> Array:
	var positions := []
	if session == null:
		return positions
	var garrison_towns := {}
	for town in session.overworld.get("towns", []):
		if town is Dictionary and String(town.get(TOWN_GARRISON_HERO_KEY, "")) != "":
			garrison_towns[String(town.get(TOWN_GARRISON_HERO_KEY, ""))] = String(town.get("placement_id", ""))
	for hero in session.overworld.get("player_heroes", []):
		if hero is Dictionary:
			positions.append(
				{
					"id": String(hero.get("id", "")),
					"name": String(hero.get("name", "Hero")),
					"x": int(hero.get("position", {}).get("x", 0)),
					"y": int(hero.get("position", {}).get("y", 0)),
					"level": OverworldLevelRulesScript.level_of(hero),
					"is_active": String(hero.get("id", "")) == String(session.overworld.get("active_hero_id", "")),
					"boat_id": String(hero.get("boat_id", "")),
					"garrison_town_placement_id": String(garrison_towns.get(String(hero.get("id", "")), "")),
				}
			)
	return positions

static func _normalize_player_hero(
	hero_state: Dictionary,
	session: SessionStateStoreScript.SessionData,
	fallback_position: Dictionary,
	fallback_army: Dictionary,
	fallback_movement: Variant
) -> Dictionary:
	var hero_id := String(hero_state.get("id", ""))
	if hero_id == "":
		return {}
	var hero_template := ContentService.get_hero(hero_id)
	var hero := hero_state.duplicate(true)
	hero["id"] = hero_id
	hero["name"] = String(hero.get("name", hero_template.get("name", hero_id)))
	if String(hero.get("growth_seed", "")) == "":
		hero["growth_seed"] = new_growth_seed(hero_id, session)
	hero["base_movement"] = max(1, int(hero.get("base_movement", hero_template.get("base_movement", 10))))
	hero["specialty_focus_ids"] = _normalize_authored_specialties(
		hero.get("specialty_focus_ids", hero_template.get("specialty_focus_ids", []))
	)
	if int(hero.get("level", 1)) <= 1 and int(hero.get("experience", 0)) == 0:
		var starting_specialties := _normalize_authored_specialties(hero_template.get("starting_specialties", []))
		if not starting_specialties.is_empty() and _normalize_authored_specialties(hero.get("specialties", [])).is_empty():
			hero["specialties"] = starting_specialties
	hero = HeroProgressionRulesScript.ensure_hero_progression(hero)
	hero = SpellRulesScript.ensure_hero_spellbook(hero, hero_template)
	hero = ArtifactRulesScript.ensure_hero_artifacts(hero)
	hero["position"] = _normalize_position(hero.get("position", fallback_position))
	hero["army"] = _normalize_army(hero.get("army", fallback_army), hero_id)
	hero["movement"] = _normalize_movement(hero.get("movement", fallback_movement), movement_max_for_hero(hero, session))
	return hero

static func _sync_active_hero_mirror(session: SessionStateStoreScript.SessionData) -> void:
	if session == null:
		return
	var hero := active_hero(session)
	if hero.is_empty():
		session.overworld["hero"] = {}
		session.overworld["army"] = {}
		session.overworld["movement"] = {}
		session.overworld["hero_position"] = {}
		return
	session.overworld["hero"] = hero
	session.overworld["army"] = hero.get("army", {})
	session.overworld["movement"] = hero.get("movement", {})
	session.overworld["hero_position"] = hero.get("position", {})

static func _replace_hero_in_array(player_heroes: Array, replacement: Dictionary) -> void:
	var replacement_id := String(replacement.get("id", ""))
	for index in range(player_heroes.size()):
		var hero = player_heroes[index]
		if hero is Dictionary and String(hero.get("id", "")) == replacement_id:
			player_heroes[index] = replacement
			return

static func _hero_index_by_id(player_heroes: Array, hero_id: String) -> int:
	for index in range(player_heroes.size()):
		var hero = player_heroes[index]
		if hero is Dictionary and String(hero.get("id", "")) == hero_id:
			return index
	return -1

static func _normalize_position(value: Variant) -> Dictionary:
	return OverworldLevelRulesScript.position(value)

static func _normalize_movement(value: Variant, movement_max: int) -> Dictionary:
	var normalized := {"current": movement_max, "max": movement_max}
	if value is Dictionary:
		normalized["current"] = clamp(int(value.get("current", movement_max)), 0, movement_max)
	return normalized

static func _normalize_army(value: Variant, hero_id: String = "") -> Dictionary:
	var stacks := []
	if value is Dictionary:
		for stack in value.get("stacks", []):
			if not (stack is Dictionary):
				continue
			var unit_id := String(stack.get("unit_id", ""))
			var count := int(max(0, int(stack.get("count", 0))))
			if unit_id == "" or count <= 0:
				continue
			var normalized_stack := {"unit_id": unit_id, "count": count}
			var slot_index := int(stack.get(ARMY_SLOT_INDEX_KEY, -1))
			if slot_index >= 0 and slot_index < ARMY_SLOT_COUNT:
				normalized_stack[ARMY_SLOT_INDEX_KEY] = slot_index
			stacks.append(normalized_stack)
	return {
		"id": String((value if value is Dictionary else {}).get("id", "%s_army" % hero_id)),
		"name": String((value if value is Dictionary else {}).get("name", "Field Army")),
		"stacks": stacks,
	}

static func _hero_roster_line(hero: Dictionary, active_hero_id: String) -> String:
	return HumanEngine.native_writing(&"HeroCommandRules._hero_roster_line", [hero, active_hero_id])

static func _normalize_authored_specialties(value: Variant) -> Array:
	var normalized := []
	if value is Array:
		for specialty_id_value in value:
			var specialty_id := String(specialty_id_value)
			if not HeroProgressionRulesScript.has_specialty(specialty_id) or specialty_id in normalized:
				continue
			normalized.append(specialty_id)
	return normalized

static func _army_summary(army: Variant) -> String:
	return HumanEngine.native_writing(&"HeroCommandRules._army_summary", [army])

static func _stack_summary_from_array(stacks: Variant) -> String:
	return HumanEngine.native_writing(&"HeroCommandRules._stack_summary_from_array", [stacks])

static func _hero_is_stationed_at_town(hero: Dictionary, town: Dictionary) -> bool:
	return _normalize_position(hero.get("position", {})) == OverworldLevelRulesScript.town_entrance(town)

static func _stationed_holder_ids(session: SessionStateStoreScript.SessionData, town: Dictionary) -> Array:
	return HumanEngine.native_writing(&"HeroCommandRules._stationed_holder_ids", [session, town])

static func _holder_stacks(session: SessionStateStoreScript.SessionData, town: Dictionary, holder_id: String) -> Array:
	if holder_id == HOLDER_GARRISON:
		return town.get("garrison", []).duplicate(true) if town.get("garrison", []) is Array else []
	var hero := hero_by_id(session, holder_id)
	return hero.get("army", {}).get("stacks", []).duplicate(true) if not hero.is_empty() and hero.get("army", {}).get("stacks", []) is Array else []

static func _set_holder_stacks(session: SessionStateStoreScript.SessionData, town: Dictionary, holder_id: String, stacks: Array) -> void:
	if session == null:
		return
	if holder_id == HOLDER_GARRISON:
		if town.is_empty():
			return
		var towns = session.overworld.get("towns", [])
		for index in range(towns.size()):
			var entry = towns[index]
			if not (entry is Dictionary):
				continue
			if String(entry.get("placement_id", "")) != String(town.get("placement_id", "")):
				continue
			entry["garrison"] = stacks
			town["garrison"] = stacks
			towns[index] = entry
			session.overworld["towns"] = towns
			return
		return

	var heroes = session.overworld.get("player_heroes", [])
	var hero_index := _hero_index_by_id(heroes, holder_id)
	if hero_index < 0:
		return
	var hero = heroes[hero_index]
	var army = _normalize_army(hero.get("army", {}), holder_id)
	army["stacks"] = stacks
	hero["army"] = army
	heroes[hero_index] = hero
	session.overworld["player_heroes"] = heroes
	if String(session.overworld.get("active_hero_id", "")) == holder_id:
		_sync_active_hero_mirror(session)

static func _append_field_transfer_actions(actions: Array, source: Dictionary, target: Dictionary) -> void:
	var source_id := String(source.get("id", ""))
	var target_id := String(target.get("id", ""))
	if source_id == "" or target_id == "":
		return
	var source_name := String(source.get("name", source_id))
	var target_name := String(target.get("name", target_id))
	for stack_value in source.get("army", {}).get("stacks", []):
		if not (stack_value is Dictionary):
			continue
		var stack: Dictionary = stack_value
		var unit_id := String(stack.get("unit_id", ""))
		var count := int(stack.get("count", 0))
		if unit_id == "" or count <= 0:
			continue
		var unit_name := String(ContentService.get_unit(unit_id).get("name", unit_id))
		var seen_transfer_counts := {}
		var admission := army_addition_plan(target.get("army", {}).get("stacks", []), {unit_id: 1})
		for amount_token_value in _transfer_amount_tokens(count):
			var amount_token := String(amount_token_value)
			var transfer_count := _resolve_transfer_amount(amount_token, count)
			if seen_transfer_counts.has(transfer_count):
				continue
			seen_transfer_counts[transfer_count] = true
			var blocker := "" if bool(admission.get("ok", false)) else String(admission.get("message", ""))
			if blocker == "" and _transfer_empties_hero_army(source_id, source.get("army", {}).get("stacks", []), transfer_count, count):
				blocker = "%s must keep at least one troop stack." % source_name
			actions.append({
				"id": "field_transfer:%s:%s:%s:%s" % [source_id, target_id, unit_id, amount_token],
				"label": "%s -> %s | %d %s" % [source_name, target_name, transfer_count, unit_name],
				"summary": "Move %s of %d %s from %s to %s; both commanders remain on this tile." % [
					_transfer_amount_label(amount_token, count),
					count,
					unit_name,
					source_name,
					target_name,
				],
				"source_hero_id": source_id,
				"target_hero_id": target_id,
				"unit_id": unit_id,
				"amount_token": amount_token,
				"transfer_count": transfer_count,
				"disabled": blocker != "",
				"disabled_reason": blocker,
			})

static func _append_field_artifact_transfer_actions(actions: Array, source: Dictionary, target: Dictionary) -> void:
	var source_id := String(source.get("id", ""))
	var target_id := String(target.get("id", ""))
	if source_id == "" or target_id == "":
		return
	var source_name := String(source.get("name", source_id))
	var target_name := String(target.get("name", target_id))
	for artifact_id_value in ArtifactRulesScript.owned_artifact_ids(source):
		var artifact_id := String(artifact_id_value)
		if artifact_id == "" or ArtifactRulesScript.has_artifact(target, artifact_id):
			continue
		var source_location := ArtifactRulesScript.locate_artifact(source, artifact_id)
		actions.append({
			"id": "field_artifact_transfer:%s:%s:%s" % [source_id, target_id, artifact_id],
			"label": "%s -> %s | %s" % [source_name, target_name, ArtifactRulesScript.artifact_name(artifact_id)],
			"summary": "%s | From %s in %s | To %s: %s" % [
				ArtifactRulesScript.artifact_effect_summary(artifact_id),
				source_name,
				String(source_location.get("slot", "pack")).capitalize() if String(source_location.get("location", "")) == "equipped" else "pack",
				target_name,
				ArtifactRulesScript.artifact_collection_state(target, artifact_id),
			],
			"source_hero_id": source_id,
			"target_hero_id": target_id,
			"artifact_id": artifact_id,
			"kind": "artifact",
		})

static func _append_field_spell_share_actions(actions: Array, source: Dictionary, target: Dictionary) -> void:
	var source_id := String(source.get("id", ""))
	var target_id := String(target.get("id", ""))
	if source_id == "" or target_id == "":
		return
	var source_name := String(source.get("name", source_id))
	var target_name := String(target.get("name", target_id))
	for spell_value in SpellRulesScript.known_spells(source):
		if not (spell_value is Dictionary):
			continue
		var spell: Dictionary = spell_value
		var spell_id := String(spell.get("id", ""))
		if spell_id == "" or SpellRulesScript.knows_spell(target, spell_id):
			continue
		actions.append({
			"id": "field_spell_share:%s:%s:%s" % [source_id, target_id, spell_id],
			"label": "%s -> %s | Teach %s" % [source_name, target_name, String(spell.get("name", spell_id))],
			"summary": "Tier %d %s spell | %d mana to cast | %s keeps it; %s learns it." % [
				int(spell.get("tier", 1)),
				String(spell.get("context", "battle")).capitalize(),
				int(spell.get("mana_cost", 0)),
				source_name,
				target_name,
			],
			"source_hero_id": source_id,
			"target_hero_id": target_id,
			"spell_id": spell_id,
			"kind": "spell",
		})

static func _transfer_empties_hero_army(holder_id: String, stacks: Variant, transfer_count: int, available: int, stack_leaves: bool = true) -> bool:
	return HumanEngine.native_writing(&"HeroCommandRules._transfer_empties_hero_army", [holder_id, stacks, transfer_count, available, stack_leaves])

static func _army_slot_holder_is_available(session: SessionStateStoreScript.SessionData, town: Dictionary, holder_id: String) -> bool:
	return HumanEngine.native_writing(&"HeroCommandRules._army_slot_holder_is_available", [session, town, holder_id])

static func _slotted_stacks(value: Variant) -> Array:
	var stacks := []
	var claimed := {}
	if value is Array:
		for stack_value in value:
			if not (stack_value is Dictionary):
				continue
			var stack: Dictionary = stack_value.duplicate(true)
			var unit_id := String(stack.get("unit_id", ""))
			var count := int(stack.get("count", 0))
			if unit_id == "" or count <= 0:
				continue
			var preferred_slot := int(stack.get(ARMY_SLOT_INDEX_KEY, -1))
			if preferred_slot < 0 or preferred_slot >= ARMY_SLOT_COUNT or claimed.has(preferred_slot):
				preferred_slot = _first_open_army_slot(claimed)
			if preferred_slot < 0:
				continue
			stack[ARMY_SLOT_INDEX_KEY] = preferred_slot
			claimed[preferred_slot] = true
			stacks.append(stack)
	stacks.sort_custom(_stack_slot_less)
	return stacks

static func _valid_stack_count(value: Variant) -> int:
	var count := 0
	if value is Array:
		for stack_value in value:
			if stack_value is Dictionary and String(stack_value.get("unit_id", "")) != "" and int(stack_value.get("count", 0)) > 0:
				count += 1
	return count

static func _first_open_army_slot(claimed: Dictionary) -> int:
	for slot_index in range(ARMY_SLOT_COUNT):
		if not claimed.has(slot_index):
			return slot_index
	return -1

static func _stack_slot_less(left: Dictionary, right: Dictionary) -> bool:
	return int(left.get(ARMY_SLOT_INDEX_KEY, ARMY_SLOT_COUNT)) < int(right.get(ARMY_SLOT_INDEX_KEY, ARMY_SLOT_COUNT))

static func _transfer_amount_tokens(count: int) -> Array:
	return HumanEngine.native(&"HeroCommandRules._transfer_amount_tokens", [count])

static func _transfer_amount_label(amount_token: String, available: int) -> String:
	return HumanEngine.native(&"HeroCommandRules._transfer_amount_label", [amount_token, available])

static func _resolve_transfer_amount(amount_token: String, available: int) -> int:
	return HumanEngine.native(&"HeroCommandRules._resolve_transfer_amount", [amount_token, available])

static func _holder_label(session: SessionStateStoreScript.SessionData, town: Dictionary, holder_id: String) -> String:
	return HumanEngine.native_writing(&"HeroCommandRules._holder_label", [session, town, holder_id])

static func _seeded_rng(seed_key: String) -> RandomNumberGenerator:
	var rng := RandomNumberGenerator.new()
	rng.seed = hash(seed_key)
	return rng

## The faction's base creatures of `tier`, one per town dwelling line, from
## the town development roster (the faction unit ladder when it has none).
static func _faction_creatures(faction_id: String, tier: int) -> Array:
	var creatures := []
	var rosters = ContentService.load_json(TOWN_DEVELOPMENT_PATH).get("rosters", {})
	var roster = rosters.get(faction_id, []) if rosters is Dictionary else []
	if roster is Array:
		for row in roster:
			if row is Dictionary and int(row.get("tier", 0)) == tier:
				var unit_id := String(row.get("unit_id", ""))
				if unit_id != "" and unit_id not in creatures and not ContentService.get_unit(unit_id).is_empty():
					creatures.append(unit_id)
	if creatures.is_empty():
		for unit_id_value in ContentService.get_faction(faction_id).get("unit_ladder_ids", []):
			var unit := ContentService.get_unit(String(unit_id_value))
			if int(unit.get("tier", 0)) == tier:
				creatures.append(String(unit_id_value))
	return creatures

static func _starting_company_size(rng: RandomNumberGenerator, unit_id: String, growth_share: Array) -> int:
	var growth := maxi(1, int(ContentService.get_unit(unit_id).get("growth", 6)))
	var low := maxi(1, ceili(growth * float(growth_share[0])))
	return rng.randi_range(low, maxi(low, ceili(growth * float(growth_share[1]))))

static func _normalize_resources(value: Variant) -> Dictionary:
	var resources := {}
	if value is Dictionary:
		for key in value.keys():
			var resource_key := String(key)
			var amount := int(max(0, int(value[key])))
			if amount > 0:
				resources[resource_key] = amount
	return resources

static func get_town_transfer_actions(session: SessionStateStoreScript.SessionData, town: Dictionary) -> Array:
	return HumanEngine.native_writing(&"HeroCommandRules.get_town_transfer_actions", [session, town])

static func transfer_town_stack(session: SessionStateStoreScript.SessionData, town: Dictionary, source_holder: String, target_holder: String, unit_id: String, amount_token: String) -> Dictionary:
	return HumanEngine.native_writing(&"HeroCommandRules.transfer_town_stack", [session, town, source_holder, target_holder, unit_id, amount_token])
