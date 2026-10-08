extends RefCounted

# Computer players play through the same heroes, towns and map objects as the
# human. An AI hero is an overworld encounter entry (map rendering, fog, saves,
# turn playback and battles with the human already understand those) marked by
# an "ai_hero" block. Its hero record is enemy_commander_state and its army is
# enemy_army: real troops hired in towns, never a template host.

const SessionStateStoreScript = preload("res://scripts/core/SessionStateStore.gd")
const PlayerRules = preload("res://scripts/core/PlayerIdentityRules.gd")
const LevelRules = preload("res://scripts/core/OverworldLevelRules.gd")
const TurnPlayback = preload("res://scripts/core/OverworldTurnPlayback.gd")
const HeroCommandRulesScript = preload("res://scripts/core/HeroCommandRules.gd")
const HeroProgressionRulesScript = preload("res://scripts/core/HeroProgressionRules.gd")
const ArtifactRulesScript = preload("res://scripts/core/ArtifactRules.gd")
const SpellRulesScript = preload("res://scripts/core/SpellRules.gd")
const CreatureDwellings = preload("res://scripts/core/CreatureDwellingRules.gd")
const NodePayload = preload("res://scripts/core/ResourceNodePayloadRules.gd")
const NativeTransit = preload("res://scripts/core/NativeTransitRules.gd")
const VisitBuildings = preload("res://scripts/core/VisitBuildingRules.gd")
const TownServices = preload("res://scripts/core/EnemyTownServices.gd")
const AdventureRules = preload("res://scripts/core/EnemyAdventureRules.gd")

const AI_HERO_KEY := "ai_hero"
# Battle settings (terrain, length, rewards) for fights against an AI hero. The
# template's army and commander are never used: the hero brings its own.
const AI_HERO_ENCOUNTER_ID := "encounter_mire_raid"
const AI_DIFFICULTY := "normal"
const MAX_DECISIONS_PER_DAY := 6
const SEARCH_DAYS := 3
const FAR_SEARCH_DAYS := 7
const MIN_SEARCH_RADIUS := 14
const GUARD_WIN_RATIO := 1.5
const HERO_ATTACK_RATIO := 1.3
const TOWN_ATTACK_RATIO := 1.4
const THREAT_RATIO := 1.15
const TROOP_VALUE_PER_POWER := 10.0
## Builds weigh a dwelling's troops and a building's income over two weeks.
const BUILD_HORIZON_WEEKS := 2.0
## Each market stage is worth as much to a town as this building's income.
const MARKET_PEER_BUILDING_ID := "building_dev_storehouse_1"
## A resource the faction lacks for its build list counts this much more.
const SHORT_RESOURCE_MULTIPLIER := 1.8
## A town whose dwellings muster less than this (gold value) a week is short
## of troops.
const STARVED_TOWN_WEEKLY_TROOPS := 1500.0
## With this margin a fight is won without a second look.
const CLEAR_WIN_RATIO := 3.0
## The square law runs about a third short of what auto-resolve costs, with a
## small loss even against weak guards: calibrated 2026-10-08 on 1,262
## auto-resolved fights of the three computer players' main heroes against the
## guards of the owner's large map (mean loss 8.7% at a guard of 0.3-0.4 of
## the hero's strength, 14% at 0.4-0.5, 22% at 0.5-0.6, 32% at 0.6-0.7).
const LOSS_ESTIMATE_FACTOR := 1.3
const LOSS_ESTIMATE_FLOOR := 0.012
## Fights a hero sizes up and turns down before settling on a decision.
const MAX_FIGHT_VETOES := 3
## Dismissed fights an idle hero looks at again in one decision.
const MAX_IDLE_PREVIEWS := 2
## An idle hero takes a fight its preview wins keeping this share of its
## strength, even when the guard holds less than the troops it costs.
const IDLE_FIGHT_MIN_KEPT := 0.75
## How close to its town's doorway an idle hero waits.
const HOME_WAIT_RADIUS := 2
## A hand-over of troops is worth at most what a modest site is worth.
const MEET_VALUE_CAP := 600.0
const GOAL_CONTINUITY_BONUS := 1.25
const TOWN_SIGHT_RADIUS := 8
const EXPLORE_VALUE := 220.0
## Ground behind a guard that the hero cannot reach today: a base value for
## opening the way, plus each unexplored tile there, up to a cap (sites the
## player has already seen there count on top, at half their value).
const PASSAGE_BASE_VALUE := 300.0
const PASSAGE_UNEXPLORED_TILE_VALUE := 4.0
const PASSAGE_KNOWN_SITE_SHARE := 0.5
const PASSAGE_VALUE_CAP := 5000.0
const PASSAGE_TILE_CAP := 400
const EXPLORED_KEY := "ai_explored"
const NEIGHBOR_DX := [1, -1, 0, 0, 1, 1, -1, -1]
const NEIGHBOR_DY := [0, 0, 1, -1, 1, -1, 1, -1]
const STOP_RESOURCE := 1
const STOP_ARTIFACT := 2
const STOP_TOWN := 3
const STOP_ENCOUNTER := 4
const STOP_HERO := 5
const STOP_AI_HERO := 6
## Site families that stand after a visit and can be walked across.
const WALK_ACROSS_SITE_FAMILIES := ["visit_building", "shrine", "frontier_shrine", "support_producer", "sign_waypoint", "scouting_structure"]
const RESOURCE_VALUES := {
	"gold": 1.0,
	"wood": 80.0,
	"ore": 80.0,
	"aetherglass": 200.0,
	"embergrain": 160.0,
	"peatwax": 160.0,
	"verdant_grafts": 160.0,
	"brass_scrip": 160.0,
	"memory_salt": 200.0,
	"experience": 1.5,
}
const LIVE_RESOURCE_KEYS := [
	"gold",
	"wood",
	"ore",
	"aetherglass",
	"embergrain",
	"peatwax",
	"verdant_grafts",
	"brass_scrip",
	"memory_salt",
]

static func _overworld_rules() -> Variant:
	return load("res://scripts/core/OverworldRules.gd")

static func _battle_rules() -> Variant:
	return load("res://scripts/core/BattleRules.gd")

static func _auto_resolve_rules() -> Variant:
	return load("res://scripts/core/BattleAutoResolveRules.gd")

static func _turn_rules() -> Variant:
	return load("res://scripts/core/EnemyTurnRules.gd")

# --- Identity -----------------------------------------------------------------

static func is_ai_hero(entry: Variant) -> bool:
	return entry is Dictionary and entry.get(AI_HERO_KEY, null) is Dictionary

static func hero_name(entry: Dictionary) -> String:
	var commander: Dictionary = entry.get("enemy_commander_state", {}) if entry.get("enemy_commander_state", {}) is Dictionary else {}
	var name := String(commander.get("name", ""))
	if name == "":
		name = String(ContentService.get_hero(String(commander.get("roster_hero_id", ""))).get("name", ""))
	return name if name != "" else "Enemy hero"

static func active_hero_entries(session: SessionStateStoreScript.SessionData, controller: String = "") -> Array:
	var result := []
	if session == null:
		return result
	var resolved := _resolved_lookup(session)
	for entry in session.overworld.get("encounters", []):
		if not is_ai_hero(entry) or resolved.has(String(entry.get("placement_id", ""))):
			continue
		if controller != "" and PlayerRules.raid_controller_id(entry) != controller:
			continue
		result.append(entry)
	return result

static func active_hero_count(session: SessionStateStoreScript.SessionData, controller: String) -> int:
	return active_hero_entries(session, controller).size()

# Tiles this faction's towns and heroes have seen on one map level.
static func explored_tile_count(state: Dictionary, level: int = 0) -> int:
	var stored = state.get(EXPLORED_KEY, {})
	var encoded := String(stored.get(str(level), "")) if stored is Dictionary else ""
	if encoded == "":
		return 0
	var count := 0
	for byte in Marshalls.base64_to_raw(encoded):
		var bits := int(byte)
		while bits != 0:
			count += bits & 1
			bits >>= 1
	return count

static func _resolved_lookup(session: SessionStateStoreScript.SessionData) -> Dictionary:
	var lookup := {}
	for value in session.overworld.get("resolved_encounters", []):
		lookup[String(value)] = true
	return lookup

static func _entry_index(session: SessionStateStoreScript.SessionData, placement_id: String) -> int:
	var encounters: Array = session.overworld.get("encounters", [])
	for index in range(encounters.size()):
		var entry = encounters[index]
		if entry is Dictionary and String(entry.get("placement_id", "")) == placement_id:
			return index
	return -1

static func _store_entry(session: SessionStateStoreScript.SessionData, index: int, entry: Dictionary) -> void:
	var encounters: Array = session.overworld.get("encounters", [])
	if index >= 0 and index < encounters.size():
		encounters[index] = entry
		session.overworld["encounters"] = encounters

static func _is_resolved(session: SessionStateStoreScript.SessionData, placement_id: String) -> bool:
	return placement_id in session.overworld.get("resolved_encounters", [])

static func _mark_resolved(session: SessionStateStoreScript.SessionData, placement_id: String) -> void:
	var resolved: Array = session.overworld.get("resolved_encounters", []) if session.overworld.get("resolved_encounters", []) is Array else []
	if placement_id != "" and placement_id not in resolved:
		resolved.append(placement_id)
	session.overworld["resolved_encounters"] = resolved

# --- Save migration -----------------------------------------------------------

const MIGRATION_KEY := "ai_heroes_version"
const MIGRATION_VERSION := 1
## A commanderless column this close to one of its side's heroes joins it.
const COLUMN_JOIN_RADIUS := 3

## Save migration, once per session: raid hosts from older saves become heroes.
static func migrate_legacy_raids(session: SessionStateStoreScript.SessionData) -> void:
	if session == null or int(session.overworld.get(MIGRATION_KEY, 0)) >= MIGRATION_VERSION or not session.battle.is_empty():
		return
	normalize_ai_heroes(session)
	session.overworld[MIGRATION_KEY] = MIGRATION_VERSION

## Legacy raid hosts become heroes. A commanderless column is disbanded: its
## troops join a hero of its controller standing close by, the rest return to
## the controller's nearest town. Runs once per save and again for any host a
## scenario script places later (`controller`).
static func normalize_ai_heroes(session: SessionStateStoreScript.SessionData, only_controller: String = "") -> Dictionary:
	var report := {"converted": 0, "disbanded": 0, "joined_hero": 0}
	# A battle in progress still refers to its armies as they are.
	if session == null or not session.battle.is_empty():
		return report
	var encounters: Array = session.overworld.get("encounters", []) if session.overworld.get("encounters", []) is Array else []
	var resolved := _resolved_lookup(session)
	var changed := false
	var columns := []
	for index in range(encounters.size()):
		var entry = encounters[index]
		if not (entry is Dictionary):
			continue
		var controller := PlayerRules.raid_controller_id(entry)
		if controller == "" or (only_controller != "" and controller != only_controller):
			continue
		var placement_id := String(entry.get("placement_id", ""))
		if resolved.has(placement_id) or bool(entry.get("raid_retired_to_rebuild", false)):
			continue
		if is_ai_hero(entry):
			var block: Dictionary = entry.get(AI_HERO_KEY, {})
			if not (block.get("movement", {}) is Dictionary):
				block["movement"] = {"current": 0, "max": _movement_max(entry)}
				entry[AI_HERO_KEY] = block
				encounters[index] = entry
				changed = true
			continue
		var commander: Dictionary = entry.get("enemy_commander_state", {}) if entry.get("enemy_commander_state", {}) is Dictionary else {}
		var hero_id := String(commander.get("roster_hero_id", ""))
		if hero_id == "" or bool(entry.get("commanderless_support_column", false)):
			columns.append(index)
			continue
		encounters[index] = _convert_legacy_host(session, entry, controller)
		report["converted"] = int(report.converted) + 1
		changed = true
	for index in columns:
		var entry: Dictionary = encounters[index]
		var controller := PlayerRules.raid_controller_id(entry)
		var placement_id := String(entry.get("placement_id", ""))
		var stacks: Array = entry.get("enemy_army", {}).get("stacks", []) if entry.get("enemy_army", {}) is Dictionary else []
		var hero_index := _nearest_hero_index(encounters, resolved, controller, entry, COLUMN_JOIN_RADIUS)
		if hero_index >= 0:
			var hero: Dictionary = encounters[hero_index]
			var army: Dictionary = hero.get("enemy_army", {}) if hero.get("enemy_army", {}) is Dictionary else {}
			var merged := _merge_stacks_into(army.get("stacks", []), stacks)
			if merged.stacks != army.get("stacks", []):
				army["stacks"] = merged.stacks
				hero["enemy_army"] = army
				var commander: Dictionary = hero.get("enemy_commander_state", {}) if hero.get("enemy_commander_state", {}) is Dictionary else {}
				if not commander.is_empty():
					hero["enemy_commander_state"] = AdventureRules.sync_commander_army_continuity(commander, army, AI_HERO_ENCOUNTER_ID)
				hero["joined_column_placement_id"] = placement_id
				encounters[hero_index] = hero
				entry["ai_joined_hero_placement_id"] = String(hero.get("placement_id", ""))
				report["joined_hero"] = int(report.joined_hero) + 1
			stacks = merged.left
		var leftover := entry.duplicate(true)
		leftover["enemy_army"] = {"stacks": stacks}
		_return_troops_to_nearest_town(session, leftover, controller)
		_mark_resolved(session, placement_id)
		resolved[placement_id] = true
		entry["ai_disbanded_day"] = int(session.day)
		encounters[index] = entry
		report["disbanded"] = int(report.disbanded) + 1
		changed = true
	if changed:
		session.overworld["encounters"] = encounters
	return report

## The closest hero of this controller within `radius` tiles of a column.
static func _nearest_hero_index(encounters: Array, resolved: Dictionary, controller: String, column: Dictionary, radius: int) -> int:
	var best := -1
	var best_distance := radius + 1
	for index in range(encounters.size()):
		var entry = encounters[index]
		if not is_ai_hero(entry) or resolved.has(String(entry.get("placement_id", ""))):
			continue
		if PlayerRules.raid_controller_id(entry) != controller or not LevelRules.same_level(entry, column):
			continue
		var distance := maxi(absi(int(entry.get("x", 0)) - int(column.get("x", 0))), absi(int(entry.get("y", 0)) - int(column.get("y", 0))))
		if distance < best_distance:
			best_distance = distance
			best = index
	return best

static func _convert_legacy_host(session: SessionStateStoreScript.SessionData, entry: Dictionary, controller: String) -> Dictionary:
	var converted := entry.duplicate(true)
	converted["legacy_encounter_id"] = String(entry.get("encounter_id", ""))
	converted["encounter_id"] = AI_HERO_ENCOUNTER_ID
	for key in ["difficulty", "commanderless_support_column", "delivery_intercept_node_placement_id", "arrived"]:
		converted.erase(key)
	# Raid targets told the human's forecasts where a host was heading; a hero's
	# goal is its own business.
	for key in converted.keys():
		for prefix in ["target_", "goal_", "regroup_", "guarded_claim_", "blocked_route_", "supporting_front_", "support_"]:
			if String(key).begins_with(prefix):
				converted.erase(key)
				break
	var army: Dictionary = converted.get("enemy_army", {}) if converted.get("enemy_army", {}) is Dictionary else {}
	army["name"] = "%s's army" % hero_name(converted)
	converted["enemy_army"] = army
	var home := _nearest_owned_town(session, controller, Vector2i(int(entry.get("x", 0)), int(entry.get("y", 0))), LevelRules.level_of(entry))
	converted[AI_HERO_KEY] = {
		"hero_id": String(converted.get("enemy_commander_state", {}).get("roster_hero_id", "")),
		"movement": {"current": 0, "max": _movement_max(converted)},
		"home_town_id": String(home.get("placement_id", "")),
		"hired_day": int(session.day),
		"goal": {},
		"migrated_from_raid": true,
	}
	return converted

static func _return_troops_to_nearest_town(session: SessionStateStoreScript.SessionData, entry: Dictionary, controller: String) -> void:
	var stacks: Array = entry.get("enemy_army", {}).get("stacks", []) if entry.get("enemy_army", {}) is Dictionary else []
	var home := _nearest_owned_town(session, controller, Vector2i(int(entry.get("x", 0)), int(entry.get("y", 0))), LevelRules.level_of(entry))
	if home.is_empty() or stacks.is_empty():
		return
	var towns: Array = session.overworld.get("towns", [])
	var index := int(home.get("index", -1))
	if index < 0 or index >= towns.size():
		return
	var town: Dictionary = towns[index]
	town["garrison"] = _merge_stacks_into(town.get("garrison", []), stacks).get("stacks", town.get("garrison", []))
	towns[index] = town
	session.overworld["towns"] = towns

static func _nearest_owned_town(session: SessionStateStoreScript.SessionData, controller: String, tile: Vector2i, level: int) -> Dictionary:
	var best := {}
	var best_distance := 1 << 30
	var towns: Array = session.overworld.get("towns", [])
	for index in range(towns.size()):
		var town = towns[index]
		if not (town is Dictionary) or String(town.get("owner", "")) != "enemy" or PlayerRules.town_controller_id(town) != controller:
			continue
		var distance := absi(int(town.get("x", 0)) - tile.x) + absi(int(town.get("y", 0)) - tile.y) + (0 if LevelRules.level_of(town) == level else 1000)
		if distance < best_distance:
			best_distance = distance
			best = {"index": index, "placement_id": String(town.get("placement_id", "")), "town": town}
	return best

# --- Faction turn -------------------------------------------------------------

## One computer player's day: income, weekly growth, town orders, then heroes.
static func run_faction_turn(
	session: SessionStateStoreScript.SessionData,
	config: Dictionary,
	state: Dictionary,
	should_apply_weekly_growth: bool,
	profile_enabled: bool = false
) -> Dictionary:
	var started := Time.get_ticks_usec()
	var controller := PlayerRules.controller_id(config)
	var turn_rules = _turn_rules()
	var messages := []
	var events := []
	var phases := {}
	state["treasury"] = turn_rules._normalize_resource_pool(state.get("treasury", {}))
	var treasury: Dictionary = state["treasury"]
	# Armies a scenario placed for this player since the save migration also
	# play as heroes.
	normalize_ai_heroes(session, controller)
	var towns: Array = session.overworld.get("towns", [])
	var town_entries: Array = turn_rules._owned_town_entries(session, controller)
	if town_entries.is_empty() and active_hero_count(session, controller) == 0:
		state["posture"] = "collapsed"
		return _turn_result(state, messages, events, profile_enabled, phases, started)

	var phase := Time.get_ticks_usec()
	var income := faction_daily_income(session, controller)
	_add_pool(treasury, income)
	if should_apply_weekly_growth and not town_entries.is_empty():
		turn_rules._apply_weekly_musters(session, town_entries, towns, controller, config)
		session.overworld["towns"] = towns
	_start_heroes_day(session, controller)
	phases["economy_ms"] = _elapsed_ms(phase)

	phase = Time.get_ticks_usec()
	var context := _new_context(session, config, state)
	_reveal_from_holdings(session, context)
	_ensure_opening_stockpile(session, context)
	var start_result := _ensure_starting_hero(session, context)
	_append_all(messages, start_result.get("messages", []))
	_append_all(events, start_result.get("events", []))
	var town_result := _govern_towns(session, context)
	_append_all(messages, town_result.get("messages", []))
	_append_all(events, town_result.get("events", []))
	phases["towns_ms"] = _elapsed_ms(phase)

	phase = Time.get_ticks_usec()
	# Lesser heroes move first, as a human moves couriers before the main army:
	# troops they hand over are with the main hero when it acts.
	var main_id := _main_hero_id(session, controller)
	var hero_order := []
	for entry in active_hero_entries(session, controller):
		hero_order.append({"id": String(entry.get("placement_id", "")), "power": INF if String(entry.get("placement_id", "")) == main_id else hero_power(entry)})
	hero_order.sort_custom(func(a, b): return a.power < b.power if not is_equal_approx(a.power, b.power) else a.id < b.id)
	var hero_ids := []
	for item in hero_order:
		hero_ids.append(item.id)
	var battle_started := false
	for placement_id in hero_ids:
		if not session.battle.is_empty():
			break
		var hero_result := _run_hero_day(session, context, String(placement_id))
		_append_all(messages, hero_result.get("messages", []))
		_append_all(events, hero_result.get("events", []))
		if bool(hero_result.get("battle_started", false)):
			battle_started = true
			break
	phases["heroes_ms"] = _elapsed_ms(phase)
	phases["searches"] = int(context.get("search_count", 0))
	phases["auto_battles"] = int(context.get("auto_battle_count", 0))
	phases["fight_previews"] = int(context.get("preview_count", 0))
	for key in context.get("profile", {}).keys():
		phases[key] = int(round(float(context.profile[key])))
	_store_explored(context)
	if bool(context.get("topology_changed", false)):
		_overworld_rules()._refresh_blocked_tile_index(session)
	_overworld_rules().invalidate_spatial_lookup(session)
	# Site claims may replace the treasury dictionary; context.state holds the
	# current one.
	state = context.state
	state["posture"] = "attacking" if battle_started else _posture(session, controller)
	# Abstract pressure no longer drives anything; clear what older saves held.
	state["pressure"] = 0
	return _turn_result(state, messages, events, profile_enabled, phases, started)

static func _turn_result(state: Dictionary, messages: Array, events: Array, profile_enabled: bool, phases: Dictionary, started: int) -> Dictionary:
	var result := {"state": state, "messages": messages, "events": events}
	if profile_enabled:
		phases["total_ms"] = _elapsed_ms(started)
		result["profile"] = {"faction_id": String(state.get("faction_id", "")), "player_id": String(state.get("player_id", "")), "phases_ms": phases, "event_count": events.size()}
	return result

static func _posture(session: SessionStateStoreScript.SessionData, controller: String) -> String:
	for entry in active_hero_entries(session, controller):
		var goal: Dictionary = entry.get(AI_HERO_KEY, {}).get("goal", {})
		if String(goal.get("kind", "")) in ["hero", "town_hostile"]:
			return "attacking"
	return "expanding" if active_hero_count(session, controller) > 0 else "building"

## The same income sources the human collects: towns, controlled sites and
## the daily income of every hero's artifacts and specialties.
static func faction_daily_income(session: SessionStateStoreScript.SessionData, controller: String) -> Dictionary:
	var overworld_rules = _overworld_rules()
	var income := {}
	for town in session.overworld.get("towns", []):
		if town is Dictionary and String(town.get("owner", "")) == "enemy" and PlayerRules.town_controller_id(town) == controller:
			_add_pool(income, overworld_rules.town_income(town, session))
	_add_pool(income, overworld_rules.controlled_resource_site_income(session, controller))
	for entry in active_hero_entries(session, controller):
		var commander: Dictionary = entry.get("enemy_commander_state", {})
		_add_pool(income, ArtifactRulesScript.aggregate_bonuses(commander).get("daily_income", {}))
		_add_pool(income, HeroProgressionRulesScript.daily_income_bonus(commander))
	return income

static func _start_heroes_day(session: SessionStateStoreScript.SessionData, controller: String) -> void:
	var encounters: Array = session.overworld.get("encounters", [])
	var new_week := VisitBuildings.week_index(session.day) != VisitBuildings.week_index(session.day - 1)
	for index in range(encounters.size()):
		var entry = encounters[index]
		if not is_ai_hero(entry) or PlayerRules.raid_controller_id(entry) != controller or _is_resolved(session, String(entry.get("placement_id", ""))):
			continue
		var commander: Dictionary = entry.get("enemy_commander_state", {})
		if new_week:
			commander.erase(VisitBuildings.WEEK_BONUSES)
		commander = SpellRulesScript.refresh_daily_mana(commander)
		entry["enemy_commander_state"] = commander
		var block: Dictionary = entry.get(AI_HERO_KEY, {})
		var movement_max := _movement_max(entry)
		block["movement"] = {"current": movement_max, "max": movement_max}
		block.erase("visited_town_day")
		# A town lost overnight, or a hero no longer in it, ends the wait there.
		if String(block.get("parked", "")) != "" and _parked_hero_id(session, controller, String(block.parked)) != String(entry.get("placement_id", "")):
			block.erase("parked")
		entry[AI_HERO_KEY] = block
		entry["days_active"] = max(0, int(entry.get("days_active", 0))) + 1
		encounters[index] = entry
	session.overworld["encounters"] = encounters

static func _movement_max(entry: Dictionary) -> int:
	var commander: Dictionary = entry.get("enemy_commander_state", {}) if entry.get("enemy_commander_state", {}) is Dictionary else {}
	var hero := commander.duplicate()
	if not hero.has("base_movement"):
		hero["base_movement"] = int(ContentService.get_hero(String(commander.get("roster_hero_id", ""))).get("base_movement", 10))
	return HeroCommandRulesScript.movement_max_for_hero(hero, AI_DIFFICULTY)

static func _new_context(session: SessionStateStoreScript.SessionData, config: Dictionary, state: Dictionary) -> Dictionary:
	return {
		"config": config,
		"state": state,
		"controller": PlayerRules.controller_id(config),
		"map_size": _overworld_rules().derive_map_size(session),
		"levels": _shared_level_surfaces(session),
		"search_count": 0,
		"auto_battle_count": 0,
		"topology_changed": false,
	}

## Terrain and object bodies are the same for every computer player on a given
## day; pickups that vanish clear their tiles in place. One set per day keeps
## large maps from rebuilding it for each player.
static var _surface_cache_key := ""
static var _surface_cache: Dictionary = {}

static func _shared_level_surfaces(session: SessionStateStoreScript.SessionData) -> Dictionary:
	var key := "%s|%s|%d|%d|%d" % [String(session.session_id), String(session.scenario_id), int(session.day), session.overworld.get("resource_nodes", []).size(), session.overworld.get("towns", []).size()]
	if key != _surface_cache_key:
		_surface_cache_key = key
		_surface_cache = {}
	return _surface_cache

static func clear_shared_surfaces() -> void:
	_surface_cache_key = ""
	_surface_cache = {}
	_guard_cache = {}

## Whether a guard still blocks a site, as the human's claim check decides it.
## Remembered for the enemy turn until another army is beaten.
static var _guard_cache: Dictionary = {}

static func _resource_guarded(session: SessionStateStoreScript.SessionData, node: Dictionary, site: Dictionary) -> bool:
	var key := "%d|%s" % [session.overworld.get("resolved_encounters", []).size(), String(node.get("placement_id", ""))]
	if not _guard_cache.has(key):
		_guard_cache[key] = not _overworld_rules().resource_site_blocking_guard(session, node, site).is_empty()
	return bool(_guard_cache[key])

# --- Towns --------------------------------------------------------------------

## Generated games open every human with the same stockpile; computer players
## receive it on their first day too. Authored scenarios seed AI treasuries at
## creation, and saves past the opening keep what they have.
static func _ensure_opening_stockpile(session: SessionStateStoreScript.SessionData, context: Dictionary) -> void:
	var state: Dictionary = context.state
	if bool(state.get("ai_opening_granted", false)):
		return
	state["ai_opening_granted"] = true
	if int(session.day) > 2 or not (session.overworld.get("native_random_map_package_session_adoption", {}) is Dictionary) or session.overworld.get("native_random_map_package_session_adoption", {}).is_empty():
		return
	var opening: Dictionary = load("res://scripts/persistence/NativeRandomMapPackageSessionBridge.gd")._opening_resource_stockpile()
	_add_pool(state.treasury, opening)

static func _ensure_starting_hero(session: SessionStateStoreScript.SessionData, context: Dictionary) -> Dictionary:
	var state: Dictionary = context.state
	var controller := String(context.controller)
	if bool(state.get("ai_start_hero_granted", false)):
		return {}
	if active_hero_count(session, controller) > 0:
		state["ai_start_hero_granted"] = true
		return {}
	var entries: Array = _turn_rules()._owned_town_entries(session, controller)
	if entries.is_empty():
		return {}
	var town: Dictionary = entries[0].get("town", {})
	if not _town_entrance_free(session, town, controller):
		return {}
	var offer := ai_tavern_offer_ids(session, state, controller)
	if offer.is_empty():
		return {}
	var hero_id := String(offer[0])
	var faction_id := PlayerRules.faction_id(session, controller)
	var army_id := String(load("res://scripts/core/RandomMapGeneratorRules.gd").DEFAULT_ARMY_BY_FACTION.get(faction_id, ""))
	var stacks := []
	for stack in ContentService.get_army_group(army_id).get("stacks", []):
		if stack is Dictionary and int(stack.get("count", 0)) > 0:
			stacks.append({"unit_id": String(stack.get("unit_id", "")), "count": int(stack.get("count", 0))})
	var hired := _create_hero(session, context, town, hero_id, stacks)
	if hired.is_empty():
		return {}
	state["ai_start_hero_granted"] = true
	return {"messages": [], "events": [hired.get("event", {})]}

## Build, hire and recruit in every owned town with the treasury the faction
## actually holds. Order mirrors a sensible human: a tavern while the faction
## lacks heroes, one hire, one build per town, then troops with what is left.
static func _govern_towns(session: SessionStateStoreScript.SessionData, context: Dictionary) -> Dictionary:
	var turn_rules = _turn_rules()
	var controller := String(context.controller)
	var messages := []
	var events := []
	var town_entries: Array = turn_rules._owned_town_entries(session, controller)
	if town_entries.is_empty():
		return {"messages": messages, "events": events}
	var started := Time.get_ticks_usec()
	var wanted := desired_hero_count(session, controller)
	var heroes := active_hero_count(session, controller)
	if heroes < wanted and not _faction_has_tavern(town_entries):
		var tavern_result := _build_tavern(session, context, town_entries)
		_append_all(messages, tavern_result.get("messages", []))
		_append_all(events, tavern_result.get("events", []))
	if heroes < wanted:
		var hire_result := _hire_hero(session, context)
		_append_all(events, hire_result.get("events", []))
		_append_all(messages, hire_result.get("messages", []))
	_profile_add(context, "hire_ms", started)
	# Troops first (they only appear with weekly growth and new dwellings), then
	# the day's construction with what is left.
	started = Time.get_ticks_usec()
	var recruit_result := _recruit_in_towns(session, context, {})
	_append_all(events, recruit_result.get("events", []))
	_append_all(messages, recruit_result.get("messages", []))
	_profile_add(context, "recruit_ms", started)
	started = Time.get_ticks_usec()
	var build_result := _build_in_towns(session, context)
	_append_all(messages, build_result.get("messages", []))
	_append_all(events, build_result.get("events", []))
	_profile_add(context, "build_ms", started)
	return {"messages": messages, "events": events}

## A main hero plus a collector, one more with a second town, and a fourth
## once the second week is under way.
static func desired_hero_count(session: SessionStateStoreScript.SessionData, controller: String) -> int:
	var towns: int = _turn_rules()._owned_town_count(session, controller)
	var wanted := 1 + mini(towns, 2) + (1 if int(session.day) >= 14 else 0)
	return clampi(wanted, 1, HeroCommandRulesScript.HERO_LIMIT)

static func _faction_has_tavern(town_entries: Array) -> bool:
	for entry in town_entries:
		if HeroCommandRulesScript.town_has_hall(entry.get("town", {})):
			return true
	return false

static func _build_tavern(session: SessionStateStoreScript.SessionData, context: Dictionary, town_entries: Array) -> Dictionary:
	var overworld_rules = _overworld_rules()
	var treasury: Dictionary = context.state.treasury
	var towns: Array = session.overworld.get("towns", [])
	for entry in town_entries:
		var index := int(entry.get("index", -1))
		if index < 0 or index >= towns.size():
			continue
		var town: Dictionary = towns[index]
		if int(town.get("last_build_day", 0)) == int(session.day):
			continue
		var status: Dictionary = overworld_rules.get_town_build_status(town, HeroCommandRulesScript.HALL_BUILDING_ID)
		if not bool(status.get("buildable", false)):
			continue
		var building: Dictionary = status.get("building", {})
		var cost: Dictionary = building.get("cost", {})
		if not _market_cover(session, town, treasury, cost, false):
			continue
		var result := build_in_town(session, context, index, HeroCommandRulesScript.HALL_BUILDING_ID)
		if bool(result.get("ok", false)):
			return result
	return {}

## The player's build order applied to an AI town: same status check, cost and
## one-per-day limit, paid from the faction treasury (with its own market).
## One build per town per day: the affordable building with the best value for
## its price. Value is what a player weighs: a week of the troops a dwelling
## adds, better troops from an upgrade, two weeks of extra income, spells for
## visiting heroes, a market's trades, and the buildings it opens up.
static func _build_in_towns(session: SessionStateStoreScript.SessionData, context: Dictionary) -> Dictionary:
	var messages := []
	var events := []
	var treasury: Dictionary = context.state.treasury
	var towns: Array = session.overworld.get("towns", [])
	for entry in _turn_rules()._owned_town_entries(session, String(context.controller)):
		var index := int(entry.get("index", -1))
		if index < 0 or index >= towns.size():
			continue
		var town: Dictionary = towns[index]
		if int(town.get("last_build_day", 0)) == int(session.day):
			continue
		var choice := _build_choice(session, town, treasury)
		if choice.is_empty():
			continue
		var result := build_in_town(session, context, index, String(choice.building_id), String(choice.reason))
		_append_all(messages, result.get("messages", []))
		_append_all(events, result.get("events", []))
		towns = session.overworld.get("towns", [])
	return {"messages": messages, "events": events}

static func _build_choice(session: SessionStateStoreScript.SessionData, town: Dictionary, treasury: Dictionary) -> Dictionary:
	var overworld_rules = _overworld_rules()
	var income_before := _trial_income(town)
	var growth_before := _trial_growth(town)
	var weekly_troops_before := _recruit_set_value(growth_before)
	var options: Array = overworld_rules.get_town_build_options(town, int(session.day))
	var built: Array = town.get("built_buildings", [])
	var best := {}
	var best_score := 0.0
	# Resources the treasury lacks for something this town could build now.
	var short := {}
	for building_id_value in options:
		var listed: Dictionary = ContentService.get_building(String(building_id_value)).get("cost", {})
		for key in listed.keys():
			if int(listed[key]) > int(treasury.get(key, 0)):
				short[String(key)] = true
	for building_id_value in options:
		var building_id := String(building_id_value)
		var status: Dictionary = overworld_rules.get_town_build_status(town, building_id)
		if not bool(status.get("buildable", false)):
			continue
		var building: Dictionary = status.get("building", {})
		var cost: Dictionary = building.get("cost", {})
		if not _market_cover(session, town, treasury, cost, false):
			continue
		var trial_built: Array = built.duplicate()
		trial_built.append(building_id)
		var trial := {"town_id": town.get("town_id", ""), "placement_id": town.get("placement_id", ""), "built_buildings": trial_built, "development_version": town.get("development_version", 0)}
		var value := 0.0
		var reason := "development"
		# Troops and income are weighed over the same two weeks; a town that
		# musters little wants dwellings first, as a human would.
		var troops := (_recruit_set_value(_trial_growth(trial)) - weekly_troops_before) * BUILD_HORIZON_WEEKS
		if weekly_troops_before < STARVED_TOWN_WEEKLY_TROOPS:
			troops *= 1.5
		if troops > 0.0:
			value += troops
			reason = "troops"
		var income := _payload_value(_pool_delta(_trial_income(trial), income_before), {}) * 7.0 * BUILD_HORIZON_WEEKS
		if income > value:
			reason = "income"
		value += income
		if String(building.get("upgrade_from", "")) != "" and String(building.get("unlock_unit_id", "")) != "":
			value += _upgrade_value(town, building)
			reason = "troops"
		if int(building.get("spell_tier", 0)) > 0:
			value += 400.0 + 300.0 * float(building.get("spell_tier", 0))
			if value > 0.0 and reason == "development":
				reason = "spells"
		value += 100.0 * float(building.get("readiness_bonus", 0))
		var market := _market_value(building, short)
		if market > 0.0:
			value += market
			reason = "market"
		value += 150.0 * float(_opens_count(town, building_id, trial_built))
		var cost_value := maxf(1.0, _payload_value(cost, {}))
		var score := value / cost_value
		if score > best_score:
			best_score = score
			best = {"building_id": building_id, "reason": reason, "score": score}
	return best

## Weekly troops and daily income a town (or a planned town) yields from its
## buildings alone, as the town screen's own rules compute them.
static func _trial_growth(town: Dictionary) -> Dictionary:
	var development = _turn_rules().TownDevelopment
	if development.is_current(town):
		return development.growth(town)
	return _overworld_rules()._seed_recruits_for_town(town)

static func _trial_income(town: Dictionary) -> Dictionary:
	var development = _turn_rules().TownDevelopment
	if development.is_current(town):
		return development.income(town)
	return _overworld_rules().town_income(town)

static func _recruit_dict(value: Variant) -> Dictionary:
	var result := {}
	if value is Dictionary:
		for unit_id in value.keys():
			if int(value[unit_id]) > 0:
				result[String(unit_id)] = int(value[unit_id])
	return result

static func _recruit_set_value(recruits: Dictionary) -> float:
	var value := 0.0
	for unit_id in recruits.keys():
		value += army_power([{"unit_id": String(unit_id), "count": int(recruits[unit_id])}]) * TROOP_VALUE_PER_POWER
	return value

static func _upgrade_value(town: Dictionary, building: Dictionary) -> float:
	var upgraded := String(building.get("unlock_unit_id", ""))
	var base_building := ContentService.get_building(String(building.get("upgrade_from", "")))
	var base_unit := String(base_building.get("unlock_unit_id", ""))
	if upgraded == "" or base_unit == "":
		return 0.0
	var weekly := int(ContentService.get_unit(base_unit).get("growth", 1))
	var gain := army_power([{"unit_id": upgraded, "count": weekly}]) - army_power([{"unit_id": base_unit, "count": weekly}])
	return maxf(0.0, gain) * TROOP_VALUE_PER_POWER * 2.0 + 100.0

## Buildings of the town's tree that this one opens up: they need it and have
## every other requirement once it stands. None of them can be built before it,
## so they are looked up in the whole tree, not in today's build options.
static func _opens_count(town: Dictionary, building_id: String, trial_built: Array) -> int:
	var count := 0
	var trial := town.duplicate()
	trial["built_buildings"] = trial_built
	var overworld_rules = _overworld_rules()
	for other_value in ContentService.get_town(String(town.get("town_id", ""))).get("buildable_building_ids", []):
		var other_id := String(other_value)
		if other_id == building_id or other_id in trial_built:
			continue
		if building_id not in ContentService.get_building(other_id).get("requires", []):
			continue
		if bool(overworld_rules.get_town_build_status(trial, other_id).get("buildable", false)):
			count += 1
	return count

## A market turns what the faction holds into what it lacks, so a town values
## each market stage like a Storehouse: two weeks of the Storehouse's wood and
## ore, and more while a missing resource holds up the town's build list.
static func _market_value(building: Dictionary, short: Dictionary) -> float:
	if not (building.get("market_profile", {}) is Dictionary) or (building.get("market_profile", {}) as Dictionary).is_empty():
		return 0.0
	var storehouse: Dictionary = ContentService.get_building(MARKET_PEER_BUILDING_ID).get("income", {})
	var value := _payload_value(storehouse, {}) * 7.0 * BUILD_HORIZON_WEEKS
	if not short.is_empty():
		value *= SHORT_RESOURCE_MULTIPLIER
	return value

static func _pool_delta(after: Dictionary, before: Dictionary) -> Dictionary:
	var delta := {}
	for key in after.keys():
		var amount := int(after[key]) - int(before.get(key, 0))
		if amount != 0:
			delta[key] = amount
	return delta

static func _town_rules() -> Variant:
	return load("res://scripts/core/TownRules.gd")

## Covers `cost` at a town's market with the human's trades: each order is
## priced and limited by TownRules.market_trade_quote and recorded in the
## town's weekly market usage exactly like the market popout's buy, sell and
## convert orders. Spare resources convert first (wood and ore before rare
## ones), gold buys the rest, and spare resources sell when gold is short.
## With `apply` false it only checks; otherwise the trades move `pool` and the
## town's usage.
static func _market_cover(session: SessionStateStoreScript.SessionData, town: Dictionary, pool: Dictionary, cost: Dictionary, apply: bool) -> bool:
	if _can_afford(pool, cost):
		return true
	var overworld_rules = _overworld_rules()
	var town_rules = _town_rules()
	var market: Dictionary = overworld_rules.town_market_state(town)
	if not bool(market.get("active", false)):
		return false
	var usage: Dictionary = overworld_rules._normalize_town_market_usage_state(town.get("market_usage", {}), int(session.day)).duplicate(true)
	var stock := pool.duplicate()
	var tradable: Array = town_rules.market_resource_ids(market)
	var sources := []
	for resource_id in overworld_rules.NORMAL_MARKET_RESOURCE_KEYS:
		if resource_id in tradable:
			sources.append(String(resource_id))
	for resource_id in tradable:
		if String(resource_id) not in sources:
			sources.append(String(resource_id))
	for key_value in cost.keys():
		var key := String(key_value)
		if key == "gold":
			continue
		var deficit := int(cost[key]) - int(stock.get(key, 0))
		if deficit <= 0:
			continue
		if key in tradable:
			for other_value in sources:
				var other := String(other_value)
				var spare := int(stock.get(other, 0)) - int(cost.get(other, 0))
				if other == key or spare <= 0 or deficit <= 0:
					continue
				var terms: Dictionary = town_rules.market_trade_quote(market, usage, {other: spare}, other, key, 1)
				var count := mini(deficit, int(terms.get("max_amount", 0)))
				if count > 0 and _market_trade(town_rules.market_trade_quote(market, usage, {other: spare}, other, key, count), stock, usage):
					deficit -= count
		if deficit > 0 and key in tradable:
			var spare_gold := maxi(0, int(stock.get("gold", 0)) - int(cost.get("gold", 0)))
			if not _market_trade(town_rules.market_trade_quote(market, usage, {"gold": spare_gold}, "gold", key, deficit), stock, usage):
				return false
			deficit = 0
		if deficit > 0:
			return false
	var gold_deficit := int(cost.get("gold", 0)) - int(stock.get("gold", 0))
	for other_value in sources:
		if gold_deficit <= 0:
			break
		var other := String(other_value)
		var spare := int(stock.get(other, 0)) - int(cost.get(other, 0))
		if spare <= 0:
			continue
		var terms: Dictionary = town_rules.market_trade_quote(market, usage, {other: spare}, other, "gold", 1)
		var count := 0
		for amount in range(1, int(terms.get("max_amount", 0)) + 1):
			count = amount
			if int(town_rules.market_trade_quote(market, usage, {other: spare}, other, "gold", amount).get("receive_amount", 0)) >= gold_deficit:
				break
		if count <= 0:
			continue
		var sale: Dictionary = town_rules.market_trade_quote(market, usage, {other: spare}, other, "gold", count)
		if _market_trade(sale, stock, usage):
			gold_deficit -= int(sale.get("receive_amount", 0))
	if not _can_afford(stock, cost):
		return false
	if apply:
		for key in stock.keys():
			pool[key] = stock[key]
		town["market_usage"] = usage
	return true

## Applies one quoted order to a stockpile and the week's market usage.
static func _market_trade(quote: Dictionary, stock: Dictionary, usage: Dictionary) -> bool:
	if not bool(quote.get("ok", false)):
		return false
	var give_id := String(quote.get("give_id", ""))
	var receive_id := String(quote.get("receive_id", ""))
	var give_amount := int(quote.get("give_amount", 0))
	var receive_amount := int(quote.get("receive_amount", 0))
	stock[give_id] = int(stock.get(give_id, 0)) - give_amount
	stock[receive_id] = int(stock.get(receive_id, 0)) + receive_amount
	var mode := String(quote.get("mode", ""))
	if mode in ["sell", "convert"]:
		var sold: Dictionary = usage.get("sell", {}) if usage.get("sell", {}) is Dictionary else {}
		sold[give_id] = int(sold.get(give_id, 0)) + give_amount
		usage["sell"] = sold
	if mode in ["buy", "convert"]:
		var bought: Dictionary = usage.get("buy", {}) if usage.get("buy", {}) is Dictionary else {}
		bought[receive_id] = int(bought.get(receive_id, 0)) + receive_amount
		usage["buy"] = bought
	return true

## The most of a creature the faction can pay for, trading at the town's
## market if it has one.
static func _max_affordable_with_market(session: SessionStateStoreScript.SessionData, town: Dictionary, pool: Dictionary, unit_cost: Dictionary, available: int) -> int:
	var low := 0
	var high := maxi(0, available)
	while low < high:
		var middle := (low + high + 1) / 2
		if _market_cover(session, town, pool, _turn_rules()._scale_resource_pool(unit_cost, middle), false):
			low = middle
		else:
			high = middle - 1
	return low

static func build_in_town(session: SessionStateStoreScript.SessionData, context: Dictionary, town_index: int, building_id: String, reason: String = "heroes") -> Dictionary:
	var overworld_rules = _overworld_rules()
	var turn_rules = _turn_rules()
	var treasury: Dictionary = context.state.treasury
	var towns: Array = session.overworld.get("towns", [])
	var town: Dictionary = towns[town_index]
	var status: Dictionary = overworld_rules.get_town_build_status(town, building_id)
	if int(town.get("last_build_day", 0)) == int(session.day) or not bool(status.get("buildable", false)):
		return {"ok": false}
	var building: Dictionary = status.get("building", {})
	var cost: Dictionary = building.get("cost", {})
	if not _market_cover(session, town, treasury, cost, false):
		return {"ok": false}
	_market_cover(session, town, treasury, cost, true)
	turn_rules._spend_from_pool(treasury, cost)
	var built: Array = town.get("built_buildings", []) if town.get("built_buildings", []) is Array else []
	built.append(building_id)
	town["built_buildings"] = built
	turn_rules.TownDevelopment.migrate_town(town)
	town["last_build_day"] = int(session.day)
	town["available_recruits"] = turn_rules._merge_recruits(town.get("available_recruits", {}), turn_rules._building_growth_payload(building_id))
	towns[town_index] = town
	session.overworld["towns"] = towns
	var event: Dictionary = turn_rules.ai_town_build_event(session, context.config, town, {
		"building_id": building_id,
		"building_label": String(building.get("name", building_id)),
		"reason_codes": ["town_build_%s" % reason],
		"public_reason": reason,
	})
	return {
		"ok": true,
		"messages": ["%s builds %s in %s." % [String(context.config.get("label", context.controller)), String(building.get("name", building_id)), turn_rules._town_name(town)]],
		"events": [event] if not event.is_empty() else [],
	}

## Two faction heroes per week, drawn like the human's tavern. Heroes already
## on the map, in the human's command or recovering from defeat are skipped.
static func ai_tavern_offer_ids(session: SessionStateStoreScript.SessionData, state: Dictionary, controller: String) -> Array:
	var week := HeroCommandRulesScript.tavern_week(session)
	var pool := _tavern_pool(session, state, controller)
	var stored = state.get("ai_tavern", {})
	if stored is Dictionary and int(stored.get("week", -1)) == week and stored.get("hero_ids", []) is Array:
		var kept := []
		for hero_id in stored.get("hero_ids", []):
			if String(hero_id) in pool:
				kept.append(String(hero_id))
		return kept
	var candidates := pool.duplicate()
	var rng := RandomNumberGenerator.new()
	rng.seed = hash("%s|%s|ai_tavern|%d" % [String(session.session_id), controller, week])
	for index in range(candidates.size() - 1, 0, -1):
		var swap := rng.randi_range(0, index)
		var held = candidates[index]
		candidates[index] = candidates[swap]
		candidates[swap] = held
	var offer := candidates.slice(0, mini(HeroCommandRulesScript.TAVERN_OFFER_SIZE, candidates.size()))
	state["ai_tavern"] = {"week": week, "hero_ids": offer.duplicate()}
	return offer

static func _tavern_pool(session: SessionStateStoreScript.SessionData, state: Dictionary, controller: String) -> Array:
	var taken := {}
	for hero in session.overworld.get("player_heroes", []):
		if hero is Dictionary:
			taken[String(hero.get("id", ""))] = true
	var resolved := _resolved_lookup(session)
	for entry in session.overworld.get("encounters", []):
		if entry is Dictionary and not resolved.has(String(entry.get("placement_id", ""))):
			var commander = entry.get("enemy_commander_state", {})
			if commander is Dictionary:
				taken[String(commander.get("roster_hero_id", ""))] = true
	for roster_entry in state.get("commander_roster", []):
		if roster_entry is Dictionary and String(roster_entry.get("status", "")) == AdventureRules.COMMANDER_STATUS_RECOVERING and int(roster_entry.get("recovery_day", 0)) > int(session.day):
			taken[String(roster_entry.get("roster_hero_id", ""))] = true
	var pool := []
	for hero_id in ContentService.get_faction(PlayerRules.faction_id(session, controller)).get("hero_ids", []):
		var id := String(hero_id)
		if id != "" and not taken.has(id) and not ContentService.get_hero(id).is_empty():
			pool.append(id)
	pool.sort()
	return pool

static func _cheapest_offer_cost(session: SessionStateStoreScript.SessionData, state: Dictionary, controller: String) -> Dictionary:
	var best := {}
	for hero_id in ai_tavern_offer_ids(session, state, controller):
		var cost := HeroCommandRulesScript.hero_recruit_cost(ContentService.get_hero(String(hero_id)))
		if best.is_empty() or int(cost.get("gold", 0)) < int(best.get("gold", 0)):
			best = cost
	return best

static func _hire_hero(session: SessionStateStoreScript.SessionData, context: Dictionary) -> Dictionary:
	var state: Dictionary = context.state
	var controller := String(context.controller)
	var treasury: Dictionary = state.treasury
	if active_hero_count(session, controller) >= HeroCommandRulesScript.HERO_LIMIT:
		return {}
	var offer := ai_tavern_offer_ids(session, state, controller)
	if offer.is_empty():
		return {}
	var best_town := {}
	var best_power := -1.0
	for entry in _turn_rules()._owned_town_entries(session, controller):
		var town: Dictionary = entry.get("town", {})
		if not HeroCommandRulesScript.town_has_hall(town) or not _town_entrance_free(session, town, controller):
			continue
		if int(town.get("last_hire_day", 0)) == int(session.day):
			continue
		var power := army_power(town.get("garrison", []))
		if power > best_power:
			best_power = power
			best_town = town
	if best_town.is_empty():
		return {}
	var choice := ""
	for hero_id in offer:
		var cost := HeroCommandRulesScript.hero_recruit_cost(ContentService.get_hero(String(hero_id)))
		if _can_afford(treasury, cost):
			choice = String(hero_id)
			break
	if choice == "":
		return {}
	var cost := HeroCommandRulesScript.hero_recruit_cost(ContentService.get_hero(choice))
	var hired := _create_hero(session, context, best_town, choice)
	if hired.is_empty():
		return {}
	_turn_rules()._spend_from_pool(treasury, cost)
	var tavern: Dictionary = state.get("ai_tavern", {})
	var remaining: Array = tavern.get("hero_ids", []).duplicate() if tavern.get("hero_ids", []) is Array else []
	remaining.erase(choice)
	tavern["hero_ids"] = remaining
	state["ai_tavern"] = tavern
	var towns: Array = session.overworld.get("towns", [])
	var town_index := int(_find_town(session, String(best_town.get("placement_id", ""))).get("index", -1))
	if town_index >= 0:
		towns[town_index]["last_hire_day"] = int(session.day)
		session.overworld["towns"] = towns
	return {"messages": [], "events": [hired.get("event", {})]}

## Creates the hero through the human's hire path, standing in the town
## entrance. A start hero leads the faction's start army; a tavern hire comes
## with this week's offered level and army, exactly as the human's would.
static func _create_hero(session: SessionStateStoreScript.SessionData, context: Dictionary, town: Dictionary, hero_id: String, start_stacks: Array = []) -> Dictionary:
	var controller := String(context.controller)
	var state: Dictionary = context.state
	var template := ContentService.get_hero(hero_id)
	if template.is_empty():
		return {}
	var position := LevelRules.town_entrance(town)
	var hero := {}
	if not start_stacks.is_empty():
		hero = HeroCommandRulesScript.build_recruited_hero(template, position, AI_DIFFICULTY, 1, {"id": "%s_army" % hero_id, "name": "Field Army", "stacks": start_stacks})
	else:
		var offer := HeroCommandRulesScript.tavern_offer(session, hero_id)
		hero = HeroCommandRulesScript.build_recruited_hero(template, position, AI_DIFFICULTY, int(offer.get("level", 1)), offer.get("army", {}))
	if hero.is_empty():
		return {}
	var army_stacks: Array = hero.get("army", {}).get("stacks", []).duplicate(true) if hero.get("army", {}) is Dictionary else []
	var roster_seed := _roster_progression_seed(state, hero_id)
	var seed := hero.duplicate(true)
	if not roster_seed.is_empty() and int(roster_seed.get("level", 1)) > int(seed.get("level", 1)):
		for key in ["level", "experience", "next_level_experience", "command", "specialties", "spellbook", "specialty_focus_ids"]:
			if roster_seed.has(key):
				seed[key] = roster_seed[key]
	seed.merge(PlayerRules.identity_fields(session, controller), true)
	var commander: Dictionary = AdventureRules.build_roster_commander_state(hero_id, controller, seed)
	commander["base_movement"] = int(hero.get("base_movement", template.get("base_movement", 10)))
	commander = AdventureRules._normalize_enemy_progression(commander)
	var counter := int(state.get("ai_hero_counter", 0)) + 1
	state["ai_hero_counter"] = counter
	var placement_id := "%s_hero_%d" % [controller, counter]
	var entry := {
		"placement_id": placement_id,
		"encounter_id": AI_HERO_ENCOUNTER_ID,
		"x": int(position.get("x", 0)),
		"y": int(position.get("y", 0)),
		"level": LevelRules.level_of(position),
		"combat_seed": hash("%s:%d:%s" % [String(session.session_id), int(session.day), placement_id]),
		"spawned_by_faction_id": PlayerRules.faction_id(session, controller),
		"spawned_by_player_id": String(PlayerRules.player(session, controller).get("player_id", "")),
		"enemy_army": {"id": "%s_army" % placement_id, "name": "%s's army" % String(commander.get("name", "Hero")), "stacks": army_stacks},
		"enemy_commander_state": commander,
		"days_active": 0,
		AI_HERO_KEY: {
			"hero_id": hero_id,
			"movement": {"current": 0, "max": 0},
			"home_town_id": String(town.get("placement_id", "")),
			"hired_day": int(session.day),
			"goal": {},
		},
	}
	var movement_max := _movement_max(entry)
	entry[AI_HERO_KEY]["movement"] = {"current": movement_max, "max": movement_max}
	entry = _take_garrison(session, entry, town, context, active_hero_count(session, controller) > 0)
	if army_power(entry.get("enemy_army", {}).get("stacks", [])) <= 0.0:
		# A hero never leaves town without troops.
		state["ai_hero_counter"] = counter - 1
		return {}
	var encounters: Array = session.overworld.get("encounters", [])
	encounters.append(entry)
	session.overworld["encounters"] = encounters
	_overworld_rules().invalidate_spatial_lookup(session)
	TurnPlayback.action(session, entry, "is hired")
	var event := _event(session, context, "ai_hero_hired", entry, {
		"target_kind": "town",
		"target_placement_id": String(town.get("placement_id", "")),
		"target_label": _turn_rules()._town_name(town),
		"target_x": int(town.get("x", 0)),
		"target_y": int(town.get("y", 0)),
	}, "%s hires %s at %s." % [String(context.config.get("label", controller)), hero_name(entry), _turn_rules()._town_name(town)], ["hero_hired"])
	return {"entry": entry, "event": event}

static func _roster_progression_seed(state: Dictionary, hero_id: String) -> Dictionary:
	for entry in state.get("commander_roster", []):
		if entry is Dictionary and String(entry.get("roster_hero_id", "")) == hero_id:
			var commander = entry.get("commander_state", {})
			return commander if commander is Dictionary else {}
	return {}

## Whether nothing stands in the town's doorway. With `own_controller` set, that
## player's own heroes there do not count: they are in the town, and a hire
## joins them there, as the human's hires join heroes visiting a town.
static func _town_entrance_free(session: SessionStateStoreScript.SessionData, town: Dictionary, own_controller: String = "") -> bool:
	var entrance := LevelRules.town_entrance(town)
	var resolved := _resolved_lookup(session)
	for entry in session.overworld.get("encounters", []):
		if entry is Dictionary and not resolved.has(String(entry.get("placement_id", ""))) and LevelRules.same_level(entry, entrance) \
				and int(entry.get("x", -1)) == int(entrance.get("x", -2)) and int(entry.get("y", -1)) == int(entrance.get("y", -2)):
			if own_controller != "" and is_ai_hero(entry) and PlayerRules.raid_controller_id(entry) == own_controller:
				continue
			return false
	for hero in session.overworld.get("player_heroes", []):
		var position: Dictionary = hero.get("position", {}) if hero is Dictionary and hero.get("position", {}) is Dictionary else {}
		if LevelRules.same_level(position, entrance) and int(position.get("x", -1)) == int(entrance.get("x", -2)) and int(position.get("y", -1)) == int(entrance.get("y", -2)):
			return false
	return true

## Buys what each town offers, strongest tier first, with real costs and
## availability, into the garrison. Gold reserved for a planned hire is kept.
static func _recruit_in_towns(session: SessionStateStoreScript.SessionData, context: Dictionary, reserve: Dictionary) -> Dictionary:
	var turn_rules = _turn_rules()
	var overworld_rules = _overworld_rules()
	var controller := String(context.controller)
	var treasury: Dictionary = context.state.treasury
	var events := []
	var towns: Array = session.overworld.get("towns", [])
	for entry in turn_rules._owned_town_entries(session, controller):
		var index := int(entry.get("index", -1))
		if index < 0 or index >= towns.size():
			continue
		var town: Dictionary = towns[index]
		var unit_ids := []
		for unit_id in town.get("available_recruits", {}).keys():
			if int(town.get("available_recruits", {}).get(unit_id, 0)) > 0:
				unit_ids.append(String(unit_id))
		unit_ids.sort_custom(func(a: String, b: String) -> bool:
			var tier_a := int(ContentService.get_unit(a).get("tier", 0))
			var tier_b := int(ContentService.get_unit(b).get("tier", 0))
			return a < b if tier_a == tier_b else tier_a > tier_b)
		for unit_id in unit_ids:
			var available := int(town.get("available_recruits", {}).get(unit_id, 0))
			var cost: Dictionary = turn_rules._enemy_recruit_cost(town, unit_id)
			var spendable := treasury.duplicate()
			for key in reserve.keys():
				spendable[key] = maxi(0, int(spendable.get(key, 0)) - int(reserve[key]))
			var count: int = _max_affordable_with_market(session, town, spendable, cost, available)
			if count <= 0:
				continue
			var plan := HeroCommandRulesScript.army_addition_plan(town.get("garrison", []), {unit_id: count})
			if not bool(plan.get("ok", false)):
				continue
			var total: Dictionary = turn_rules._scale_resource_pool(cost, count)
			_market_cover(session, town, treasury, total, true)
			turn_rules._spend_from_pool(treasury, total)
			town["garrison"] = plan.get("stacks", [])
			town["available_recruits"] = turn_rules._consume_recruits(town.get("available_recruits", {}), unit_id, count)
			var event: Dictionary = turn_rules.ai_town_recruit_event(session, context.config, town, {
				"unit_id": unit_id,
				"unit_label": String(ContentService.get_unit(unit_id).get("name", unit_id)),
				"recruit_count": count,
				"destination": {"type": "garrison", "public_reason": "the garrison", "reason_codes": ["garrison"]},
			})
			if not event.is_empty():
				events.append(event)
		towns[index] = town
	session.overworld["towns"] = towns
	return {"events": events, "messages": []}

## Army transfers in an owned town, as a human would arrange them: the main
## (strongest) hero takes the garrison along unless the town is under threat;
## other heroes leave all but their weakest stack for the main hero to collect;
## a fresh hire without troops takes the garrison's weakest stack. Every hero in
## town learns the spells the town teaches.
static func _take_garrison(session: SessionStateStoreScript.SessionData, entry: Dictionary, town: Dictionary, context: Dictionary, fresh_hire: bool = false) -> Dictionary:
	var town_result := _find_town(session, String(town.get("placement_id", "")))
	var index := int(town_result.get("index", -1))
	if index < 0:
		return entry
	var towns: Array = session.overworld.get("towns", [])
	var live_town: Dictionary = towns[index]
	var garrison: Array = live_town.get("garrison", []) if live_town.get("garrison", []) is Array else []
	var army: Dictionary = entry.get("enemy_army", {})
	var stacks: Array = army.get("stacks", []) if army.get("stacks", []) is Array else []
	var main_id := _main_hero_id(session, String(context.controller))
	var is_main := main_id == "" or main_id == String(entry.get("placement_id", ""))
	if fresh_hire:
		if army_power(stacks) <= 0.0 and not garrison.is_empty():
			var weakest := _weakest_stack_index(garrison)
			var moved := _merge_stacks_into(stacks, [garrison[weakest]])
			stacks = moved.get("stacks", stacks)
			if moved.get("left", []).is_empty():
				garrison.remove_at(weakest)
	elif is_main or _ferries_from(session, context, live_town, main_id):
		if not garrison.is_empty() and not _town_threatened(session, context, live_town):
			var pickup := _garrison_pickup(stacks, garrison)
			stacks = pickup.stacks
			garrison = pickup.left
	elif stacks.size() > 1:
		var keep := _weakest_stack_index(stacks)
		var leaving := []
		for stack_index in range(stacks.size()):
			if stack_index != keep:
				leaving.append(stacks[stack_index])
		var deposited := _merge_stacks_into(garrison, leaving)
		garrison = deposited.get("stacks", garrison)
		stacks = [stacks[keep]]
		stacks.append_array(deposited.get("left", []))
	army["stacks"] = stacks
	entry["enemy_army"] = army
	live_town["garrison"] = garrison
	var commander: Dictionary = entry.get("enemy_commander_state", {})
	for spell_id in _turn_rules()._enemy_town_accessible_spell_ids(live_town):
		var learned: Dictionary = SpellRulesScript.learn_spell(commander, String(spell_id))
		if bool(learned.get("ok", false)):
			commander = learned.get("hero", commander)
	entry["enemy_commander_state"] = AdventureRules.sync_commander_army_continuity(commander, entry.get("enemy_army", {}), AI_HERO_ENCOUNTER_ID)
	towns[index] = live_town
	session.overworld["towns"] = towns
	return entry

## What a hero takes from a garrison, as a human arranges seven slots: every
## stack that merges or fits, then, while the garrison holds a stronger stack
## than the hero's weakest, the two trade places. `gain` is the strength added.
static func _garrison_pickup(stacks: Array, garrison: Array) -> Dictionary:
	var before := army_power(stacks)
	var merged := _merge_stacks_into(stacks, garrison)
	var taken: Array = merged.get("stacks", stacks)
	var left: Array = merged.get("left", [])
	while not left.is_empty() and not taken.is_empty():
		var strongest := 0
		for index in range(left.size()):
			if army_power([left[index]]) > army_power([left[strongest]]):
				strongest = index
		var weakest := _weakest_stack_index(taken)
		if army_power([left[strongest]]) <= army_power([taken[weakest]]):
			break
		var swapped: Dictionary = taken[weakest]
		taken[weakest] = left[strongest]
		left[strongest] = swapped
	return {"stacks": taken, "left": left, "gain": army_power(taken) - before}

## A lesser hero carries a town's troops out to the main hero when the main
## hero is more than a day's march from the town, as a human chains them.
static func _ferries_from(session: SessionStateStoreScript.SessionData, context: Dictionary, town: Dictionary, main_id: String) -> bool:
	if main_id == "" or _town_threatened(session, context, town):
		return false
	var main_index := _entry_index(session, main_id)
	if main_index < 0:
		return false
	var main: Dictionary = session.overworld.encounters[main_index]
	if not LevelRules.same_level(main, town):
		return true
	var entrance := LevelRules.town_entrance(town)
	var distance := maxi(absi(int(main.get("x", 0)) - int(entrance.get("x", 0))), absi(int(main.get("y", 0)) - int(entrance.get("y", 0))))
	return distance > int(main.get(AI_HERO_KEY, {}).get("movement", {}).get("max", 0))

## The main army is led by the most experienced hero, the strongest army among
## equals. Going by army alone, a lesser hero carrying a big garrison out to
## the main hero became the main hero itself, kept the troops, and left the
## hero with the levels and the fights behind with nothing.
static func _main_hero_id(session: SessionStateStoreScript.SessionData, controller: String) -> String:
	var best_id := ""
	var best_experience := -1
	var best_power := -1.0
	for hero in active_hero_entries(session, controller):
		var experience := int(hero.get("enemy_commander_state", {}).get("experience", 0))
		var power := hero_power(hero)
		var better := experience > best_experience
		if experience == best_experience:
			better = power > best_power or (is_equal_approx(power, best_power) and String(hero.get("placement_id", "")) < best_id)
		if better:
			best_experience = experience
			best_power = power
			best_id = String(hero.get("placement_id", ""))
	return best_id

static func _weakest_stack_index(stacks: Array) -> int:
	var best := 0
	var best_power := INF
	for index in range(stacks.size()):
		var power := army_power([stacks[index]])
		if power < best_power:
			best_power = power
			best = index
	return best

static func _town_threatened(session: SessionStateStoreScript.SessionData, context: Dictionary, town: Dictionary) -> bool:
	var cache: Dictionary = context.get("decision", {})
	var key := "threat:%s" % String(town.get("placement_id", ""))
	if cache.has(key):
		return bool(cache[key])
	if not cache.has("hostile"):
		cache["hostile"] = _hostile_heroes(session, String(context.controller))
	var defense := army_power(town.get("garrison", []))
	var entrance := LevelRules.town_entrance(town)
	var threatened := false
	for threat in cache.hostile:
		if int(threat.get("level", 0)) != LevelRules.level_of(entrance):
			continue
		var distance := maxi(absi(int(threat.x) - int(entrance.get("x", 0))), absi(int(threat.y) - int(entrance.get("y", 0))))
		if distance <= int(threat.get("reach", 10)) + 2 and float(threat.power) > defense * THREAT_RATIO:
			threatened = true
			break
	cache[key] = threatened
	context["decision"] = cache
	return threatened

## Facts that hold for one decision; heroes and garrisons change between them.
static func _decision_main_id(session: SessionStateStoreScript.SessionData, context: Dictionary) -> String:
	var cache: Dictionary = context.get("decision", {})
	if not cache.has("main"):
		cache["main"] = _main_hero_id(session, String(context.controller))
		context["decision"] = cache
	return String(cache.main)

# --- Hero turn ----------------------------------------------------------------

static func _run_hero_day(session: SessionStateStoreScript.SessionData, context: Dictionary, placement_id: String) -> Dictionary:
	var messages := []
	var events := []
	for _decision in range(MAX_DECISIONS_PER_DAY):
		var index := _entry_index(session, placement_id)
		if index < 0 or _is_resolved(session, placement_id):
			break
		var entry: Dictionary = session.overworld.encounters[index]
		var movement: Dictionary = entry.get(AI_HERO_KEY, {}).get("movement", {})
		if int(movement.get("current", 0)) <= 0:
			break
		context["decision"] = {}
		var visit := _visit_own_town_if_inside(session, context, index)
		_append_all(events, visit.get("events", []))
		entry = session.overworld.encounters[index]
		context["decision"] = {}
		var home := _own_town_at(session, String(context.controller), entry)
		if not home.is_empty() and placement_id == _main_hero_id(session, String(context.controller)) and _town_threatened(session, context, home):
			# A hostile hero is a day away: the main army holds the gate.
			break
		var plan := _choose_plan(session, context, entry)
		if plan.is_empty():
			break
		var act_started := Time.get_ticks_usec()
		var step := _follow_plan(session, context, index, plan)
		_profile_add(context, "act_ms", act_started)
		_append_all(messages, step.get("messages", []))
		_append_all(events, step.get("events", []))
		if bool(step.get("battle_started", false)):
			return {"messages": messages, "events": events, "battle_started": true}
		if not bool(step.get("arrived", false)):
			break
		var acted := bool(step.get("acted", not step.get("events", []).is_empty() or String(plan.get("kind", "")) == "town_own"))
		if not acted:
			# Nothing came of it (a site that cannot serve this hero today):
			# leave it alone for a few days instead of returning every turn.
			_avoid_target(session, placement_id, String(plan.get("id", "")), int(session.day) + 3)
	return {"messages": messages, "events": events}

static func _avoid_target(session: SessionStateStoreScript.SessionData, placement_id: String, target_id: String, until_day: int) -> void:
	var index := _entry_index(session, placement_id)
	if index < 0 or target_id == "":
		return
	var entry: Dictionary = session.overworld.encounters[index]
	var block: Dictionary = entry.get(AI_HERO_KEY, {})
	var avoid: Dictionary = block.get("avoid", {}) if block.get("avoid", {}) is Dictionary else {}
	for key in avoid.keys():
		if int(avoid[key]) < int(session.day):
			avoid.erase(key)
	avoid[target_id] = until_day
	block["avoid"] = avoid
	block["goal"] = {}
	entry[AI_HERO_KEY] = block
	_store_entry(session, index, entry)

static func _visit_own_town_if_inside(session: SessionStateStoreScript.SessionData, context: Dictionary, index: int) -> Dictionary:
	var entry: Dictionary = session.overworld.encounters[index]
	var block: Dictionary = entry.get(AI_HERO_KEY, {})
	if int(block.get("visited_town_day", -1)) == int(session.day):
		return {}
	var town := _own_town_at(session, String(context.controller), entry)
	if town.is_empty():
		return {}
	var count_before := _creature_total(entry.get("enemy_army", {}).get("stacks", []))
	entry = _take_garrison(session, entry, town, context)
	TownServices.visit(town, entry, context.state.treasury, int(session.day), String(context.controller))
	block["visited_town_day"] = int(session.day)
	entry[AI_HERO_KEY] = block
	_store_entry(session, index, entry)
	var gained := _creature_total(entry.get("enemy_army", {}).get("stacks", [])) - count_before
	if gained <= 0:
		return {}
	var event := _event(session, context, "ai_hero_reinforced", entry, {
		"target_kind": "town",
		"target_placement_id": String(town.get("placement_id", "")),
		"target_label": _turn_rules()._town_name(town),
		"target_x": int(town.get("x", 0)),
		"target_y": int(town.get("y", 0)),
		"target_public_importance": "low",
	}, "%s gathers %d troops at %s." % [hero_name(entry), gained, _turn_rules()._town_name(town)], ["garrison_taken"])
	return {"events": [event]}

static func _creature_total(stacks: Variant) -> int:
	var total := 0
	if stacks is Array:
		for stack in stacks:
			if stack is Dictionary:
				total += maxi(0, int(stack.get("count", 0)))
	return total

static func _own_town_at(session: SessionStateStoreScript.SessionData, controller: String, entry: Dictionary) -> Dictionary:
	for town in session.overworld.get("towns", []):
		if not (town is Dictionary) or String(town.get("owner", "")) != "enemy" or PlayerRules.town_controller_id(town) != controller:
			continue
		var entrance := LevelRules.town_entrance(town)
		if LevelRules.same_level(entrance, entry) and int(entrance.get("x", -1)) == int(entry.get("x", -2)) and int(entrance.get("y", -1)) == int(entry.get("y", -2)):
			return town
	return {}

## Utility choice over everything the hero can reach: value for the faction,
## discounted by days of travel, with fights only when the estimate is safe.
static func _choose_plan(session: SessionStateStoreScript.SessionData, context: Dictionary, entry: Dictionary) -> Dictionary:
	var movement: Dictionary = entry.get(AI_HERO_KEY, {}).get("movement", {})
	var movement_max := maxi(1, int(movement.get("max", 1)))
	var radius := maxi(MIN_SEARCH_RADIUS, movement_max * SEARCH_DAYS)
	context["decision"] = {}
	var started := Time.get_ticks_usec()
	var search := _search(session, context, entry, radius)
	_profile_add(context, "search_ms", started)
	# Another of the player's heroes asked this one to step out of its way.
	var step_aside := _pending_make_way(session, context, entry, search)
	if not step_aside.is_empty():
		step_aside["path"] = _path_to(search, int(step_aside.tile_index))
		return step_aside
	started = Time.get_ticks_usec()
	var best := _vetted_candidate(session, context, entry, search, movement_max)
	_profile_add(context, "choose_ms", started)
	if best.is_empty():
		# Nothing worth doing nearby: look a week out before standing still.
		started = Time.get_ticks_usec()
		search = _search(session, context, entry, movement_max * FAR_SEARCH_DAYS)
		_profile_add(context, "search_ms", started)
		started = Time.get_ticks_usec()
		best = _vetted_candidate(session, context, entry, search, movement_max)
		_profile_add(context, "choose_ms", started)
	if best.is_empty() and _clear_way(session, context, entry, movement_max * FAR_SEARCH_DAYS, movement_max):
		# A hero of the player's own stepped aside: look again.
		search = _search(session, context, entry, movement_max * FAR_SEARCH_DAYS)
		best = _vetted_candidate(session, context, entry, search, movement_max)
	if best.is_empty():
		best = _cornered_fight(session, entry, search, context)
	if best.is_empty():
		best = _idle_fight(session, context, entry, search)
	if best.is_empty():
		best = _wait_by_home(session, context, entry, search)
	if best.is_empty():
		return {}
	best["path"] = _path_to(search, int(best.tile_index))
	return best

## A hero with nothing in reach looks past the player's own idle heroes. When
## something worth doing lies beyond one of them, that hero is asked to step
## aside: at once if it can still move today, otherwise first thing tomorrow
## (lesser heroes act before the main hero, so the way is clear when it acts).
static func _clear_way(session: SessionStateStoreScript.SessionData, context: Dictionary, entry: Dictionary, radius: int, movement_max: int) -> bool:
	var controller := String(context.controller)
	var past := _search(session, context, entry, radius, true)
	var best := _vetted_candidate(session, context, entry, past, movement_max)
	if best.is_empty():
		return false
	var size: Vector2i = context.map_size
	var keep_clear := {}
	for tile in _path_to(past, int(best.tile_index)):
		keep_clear[tile.y * size.x + tile.x] = true
	var level := LevelRules.level_of(entry)
	var doors := _own_town_doors(session, controller, level, size)
	var moved := false
	for other in active_hero_entries(session, controller):
		if String(other.get("placement_id", "")) == String(entry.get("placement_id", "")) or LevelRules.level_of(other) != level:
			continue
		var other_index := int(other.get("y", 0)) * size.x + int(other.get("x", 0))
		if not keep_clear.has(other_index) or doors.has(other_index):
			continue
		# A hero busy with its own errand moves on by itself.
		if String(other.get(AI_HERO_KEY, {}).get("goal", {}).get("kind", "")) not in ["", "wait", "park"]:
			continue
		if _make_way(session, context, String(other.get("placement_id", "")), keep_clear):
			moved = true
	return moved

## Moves a hero off the tiles another hero needs, into its town when there is
## room, or books the move for its next turn when it cannot move today.
static func _make_way(session: SessionStateStoreScript.SessionData, context: Dictionary, placement_id: String, keep_clear: Dictionary) -> bool:
	var index := _entry_index(session, placement_id)
	if index < 0:
		return false
	var entry: Dictionary = session.overworld.encounters[index]
	var movement: Dictionary = entry.get(AI_HERO_KEY, {}).get("movement", {})
	if int(movement.get("current", 0)) > 0:
		var movement_max := maxi(1, int(movement.get("max", 1)))
		var search := _search(session, context, entry, maxi(MIN_SEARCH_RADIUS, movement_max * SEARCH_DAYS))
		var plan := _wait_by_home(session, context, entry, search, keep_clear)
		if not plan.is_empty():
			plan["path"] = _path_to(search, int(plan.tile_index))
			_follow_plan(session, context, index, plan)
			entry = session.overworld.encounters[index]
	var size: Vector2i = context.map_size
	if not keep_clear.has(int(entry.get("y", 0)) * size.x + int(entry.get("x", 0))):
		return true
	var block: Dictionary = entry.get(AI_HERO_KEY, {})
	block["make_way"] = {"until_day": int(session.day) + 1, "tiles": keep_clear.keys()}
	entry[AI_HERO_KEY] = block
	_store_entry(session, index, entry)
	return false

## A step out of the way that another of the player's heroes asked for.
static func _pending_make_way(session: SessionStateStoreScript.SessionData, context: Dictionary, entry: Dictionary, search: Dictionary) -> Dictionary:
	var block: Dictionary = entry.get(AI_HERO_KEY, {})
	if not (block.get("make_way", {}) is Dictionary) or (block.get("make_way", {}) as Dictionary).is_empty():
		return {}
	var request: Dictionary = block.make_way
	block.erase("make_way")
	entry[AI_HERO_KEY] = block
	_store_entry(session, _entry_index(session, String(entry.get("placement_id", ""))), entry)
	if int(request.get("until_day", -1)) < int(session.day):
		return {}
	var keep_clear := {}
	for tile_index in request.get("tiles", []):
		keep_clear[int(tile_index)] = true
	var size: Vector2i = context.map_size
	if not keep_clear.has(int(entry.get("y", 0)) * size.x + int(entry.get("x", 0))):
		return {}
	return _wait_by_home(session, context, entry, search, keep_clear)

## The best candidate whose fight, if any, the hero expects to win well. A
## fight that looks bad is left alone for a few days and the next best taken.
static func _vetted_candidate(session: SessionStateStoreScript.SessionData, context: Dictionary, entry: Dictionary, search: Dictionary, movement_max: int) -> Dictionary:
	var best := _best_candidate(session, context, entry, search, movement_max)
	for _veto in range(MAX_FIGHT_VETOES):
		if best.is_empty() or _fight_looks_good(session, context, entry, best):
			return best
		_avoid_target(session, String(entry.get("placement_id", "")), String(best.get("id", "")), int(session.day) + 3)
		best = _best_candidate(session, context, entry, search, movement_max)
	return best if best.is_empty() or _fight_looks_good(session, context, entry, best) else {}

## A hero hemmed in by guards' zones (every way out, and home, lies past one)
## fights the weakest of them when the odds are at least even, rather than
## waiting forever: when it cannot move at all, or when its search reached every
## tile it can walk to and its home town is not among them.
static func _cornered_fight(session: SessionStateStoreScript.SessionData, entry: Dictionary, search: Dictionary, context: Dictionary = {}) -> Dictionary:
	if int(search.get("order_count", 0)) > 1 and (bool(search.get("capped", true)) or _home_reachable(session, context, entry, search)):
		return {}
	var power := hero_power(entry)
	var encounters: Array = session.overworld.get("encounters", [])
	var stops: Dictionary = search.get("stops", {})
	var best := {}
	for tile_index in stops.keys():
		for ref in stops[tile_index]:
			if int(ref.kind) != STOP_ENCOUNTER:
				continue
			var guard: Dictionary = encounters[int(ref.index)]
			var template := ContentService.get_encounter(String(guard.get("encounter_id", guard.get("id", ""))))
			var guard_power := army_power(_neutral_army(guard).get("stacks", []), template.get("enemy_commander", {}))
			if guard_power <= 0.0 or power < guard_power:
				continue
			if best.is_empty() or guard_power < float(best.fight_power) or (is_equal_approx(guard_power, float(best.fight_power)) and int(search.dist[int(tile_index)]) < int(best.distance)):
				best = {"kind": "encounter", "id": String(guard.get("placement_id", "")), "index": int(ref.index), "value": 1.0, "tile_index": int(tile_index), "distance": int(search.dist[int(tile_index)]), "fight_power": guard_power}
	return best

## Whether the hero can walk to its home town (or, without one, to any town of
## its player) on this search.
static func _home_reachable(session: SessionStateStoreScript.SessionData, context: Dictionary, entry: Dictionary, search: Dictionary) -> bool:
	var controller := String(context.get("controller", PlayerRules.raid_controller_id(entry)))
	var size: Vector2i = context.map_size if context.has("map_size") else _overworld_rules().derive_map_size(session)
	var doors := _own_town_doors(session, controller, LevelRules.level_of(entry), size)
	if doors.is_empty():
		return true
	var dist: PackedInt32Array = search.get("dist", PackedInt32Array())
	for door_index in doors.keys():
		if int(door_index) < dist.size() and int(dist[int(door_index)]) >= 0:
			return true
	return false

## With nothing worth its while, a hero takes a second look at the neutral
## armies it dismissed on the estimate: the preview shows what each fight
## really costs, and one that pays after all, or that it wins cleanly, is
## fought rather than the hero standing idle.
static func _idle_fight(session: SessionStateStoreScript.SessionData, context: Dictionary, entry: Dictionary, search: Dictionary) -> Dictionary:
	var avoid: Dictionary = entry.get(AI_HERO_KEY, {}).get("avoid", {}) if entry.get(AI_HERO_KEY, {}).get("avoid", {}) is Dictionary else {}
	var power := hero_power(entry)
	var needs := _resource_needs(session, context)
	var encounters: Array = session.overworld.get("encounters", [])
	var nearest := {}
	var stops: Dictionary = search.get("stops", {})
	for tile_index in stops.keys():
		for ref in stops[tile_index]:
			if int(ref.kind) != STOP_ENCOUNTER:
				continue
			var distance := int(search.dist[int(tile_index)])
			if not nearest.has(int(ref.index)) or distance < int(nearest[int(ref.index)].distance):
				nearest[int(ref.index)] = {"tile_index": int(tile_index), "distance": distance}
	var options := []
	for index in nearest.keys():
		var guard: Dictionary = encounters[int(index)]
		if int(avoid.get(String(guard.get("placement_id", "")), -1)) >= int(session.day):
			continue
		var value := _guard_fight_value(session, context, entry, int(index), power, needs, search)
		if is_nan(value):
			continue
		var guard_power := _guard_power(guard)
		options.append({"kind": "encounter", "id": String(guard.get("placement_id", "")), "index": int(index), "value": value, "tile_index": int(nearest[index].tile_index), "distance": int(nearest[index].distance), "fight_power": guard_power, "estimated_loss": _expected_loss_value(power, guard_power)})
	options.sort_custom(func(a, b): return float(a.value) - float(a.distance) * 10.0 > float(b.value) - float(b.distance) * 10.0)
	for option in options.slice(0, MAX_IDLE_PREVIEWS):
		if _fight_looks_good(session, context, entry, option, true):
			return option
		_avoid_target(session, String(entry.get("placement_id", "")), String(option.id), int(session.day) + 3)
	return {}

## A hero with nothing to do walks back, over as many days as it takes, to its
## home town, where the next recruits come from, and waits inside it: one idle
## hero per town parks there, out of everyone's way. Others wait close to the
## doorway, but never next to another of the player's heroes and never on a
## tile that would cut a way through (the only exit of a dead end, a one-tile
## corridor), where they would hold the main army in. `keep_clear` holds tiles
## another hero needs to pass: a hero on one of them moves off it.
static func _wait_by_home(session: SessionStateStoreScript.SessionData, context: Dictionary, entry: Dictionary, search: Dictionary, keep_clear: Dictionary = {}) -> Dictionary:
	var level := LevelRules.level_of(entry)
	var controller := String(context.controller)
	var size: Vector2i = context.map_size
	var placement_id := String(entry.get("placement_id", ""))
	var doors := _own_town_doors(session, controller, level, size)
	var friends := []
	for other in active_hero_entries(session, controller):
		if String(other.get("placement_id", "")) == placement_id or LevelRules.level_of(other) != level:
			continue
		var other_tile := Vector2i(int(other.get("x", 0)), int(other.get("y", 0)))
		# Heroes inside a town stand in no one's way.
		if not doors.has(other_tile.y * size.x + other_tile.x):
			friends.append(other_tile)
	var here := Vector2i(int(entry.get("x", 0)), int(entry.get("y", 0)))
	var here_index := here.y * size.x + here.x
	var home := here
	var home_town: Dictionary = _find_town(session, String(entry.get(AI_HERO_KEY, {}).get("home_town_id", ""))).town
	if home_town.is_empty() or String(home_town.get("owner", "")) != "enemy" or PlayerRules.town_controller_id(home_town) != controller:
		home_town = _nearest_owned_town(session, controller, here, level).get("town", {})
	if not home_town.is_empty():
		var entrance := LevelRules.town_entrance(home_town)
		home = Vector2i(int(entrance.get("x", here.x)), int(entrance.get("y", here.y)))
		var door_index := home.y * size.x + home.x
		var town_id := String(home_town.get("placement_id", ""))
		var parked_id := _parked_hero_id(session, controller, town_id)
		if LevelRules.same_level(entrance, entry) and (parked_id == "" or parked_id == placement_id):
			if here_index == door_index:
				_park(session, placement_id, town_id)
				return {}
			if int(search.dist[door_index]) >= 0:
				return {"kind": "park", "id": town_id, "index": door_index, "value": 0.0, "tile_index": door_index, "distance": int(search.dist[door_index])}
	if doors.has(here_index) and not keep_clear.has(here_index):
		return {}
	var here_free := not keep_clear.has(here_index) and not _next_to_any(here, friends) and not _cuts_a_way(search, here_index, size)
	if maxi(absi(here.x - home.x), absi(here.y - home.y)) <= HOME_WAIT_RADIUS and here_free:
		return {}
	var order: PackedInt32Array = search.get("order", PackedInt32Array())
	var stops: Dictionary = search.get("stops", {})
	var best_tile := -1
	var best_key := INF
	for position in range(1, int(search.get("order_count", 0))):
		var tile_index := order[position]
		if stops.has(tile_index) or keep_clear.has(tile_index):
			continue
		var tile := Vector2i(tile_index % size.x, tile_index / size.x)
		if _next_to_any(tile, friends):
			continue
		var key := float(maxi(absi(tile.x - home.x), absi(tile.y - home.y))) * 1000.0 + float(search.dist[tile_index])
		if key < best_key and not _cuts_a_way(search, tile_index, size):
			best_key = key
			best_tile = tile_index
	if best_tile < 0 or float(maxi(absi(here.x - home.x), absi(here.y - home.y))) * 1000.0 <= best_key and here_free:
		return {}
	return {"kind": "wait", "id": "wait:%d" % best_tile, "index": best_tile, "value": 0.0, "tile_index": best_tile, "distance": int(search.dist[best_tile])}

## Doorway tiles of the player's towns on one level, mapped to the town's id.
## A hero of the player standing on one is inside that town.
static func _own_town_doors(session: SessionStateStoreScript.SessionData, controller: String, level: int, size: Vector2i) -> Dictionary:
	var doors := {}
	for town in session.overworld.get("towns", []):
		if not (town is Dictionary) or String(town.get("owner", "")) != "enemy" or PlayerRules.town_controller_id(town) != controller:
			continue
		var entrance := LevelRules.town_entrance(town)
		if LevelRules.level_of(entrance) != level:
			continue
		var x := int(entrance.get("x", -1))
		var y := int(entrance.get("y", -1))
		if x >= 0 and y >= 0 and x < size.x and y < size.y:
			doors[y * size.x + x] = String(town.get("placement_id", ""))
	return doors

## The player's hero parked in this town, if one is.
static func _parked_hero_id(session: SessionStateStoreScript.SessionData, controller: String, town_id: String) -> String:
	if town_id == "":
		return ""
	var town: Dictionary = _find_town(session, town_id).town
	if town.is_empty() or String(town.get("owner", "")) != "enemy" or PlayerRules.town_controller_id(town) != controller:
		return ""
	var entrance := LevelRules.town_entrance(town)
	for other in active_hero_entries(session, controller):
		if String(other.get(AI_HERO_KEY, {}).get("parked", "")) == town_id and LevelRules.same_level(other, entrance) \
				and int(other.get("x", -1)) == int(entrance.get("x", -2)) and int(other.get("y", -1)) == int(entrance.get("y", -2)):
			return String(other.get("placement_id", ""))
	return ""

static func _park(session: SessionStateStoreScript.SessionData, placement_id: String, town_id: String) -> void:
	var index := _entry_index(session, placement_id)
	if index < 0:
		return
	var entry: Dictionary = session.overworld.encounters[index]
	var block: Dictionary = entry.get(AI_HERO_KEY, {})
	block["parked"] = town_id
	block["goal"] = {}
	entry[AI_HERO_KEY] = block
	_store_entry(session, index, entry)

## Whether a hero standing on this tile would cut a way through it: without the
## tile, the open ground around it falls apart into more than one piece. Town
## doorways, guard zones and other route ends are not ways through.
static func _cuts_a_way(search: Dictionary, tile_index: int, size: Vector2i) -> bool:
	var blocked: PackedByteArray = search.get("blocked", PackedByteArray())
	var stop_mask: PackedByteArray = search.get("stop_mask", PackedByteArray())
	var pass_mask: PackedByteArray = search.get("pass_mask", PackedByteArray())
	if blocked.is_empty() or stop_mask.is_empty() or pass_mask.is_empty():
		return false
	var native_corners := bool(search.get("native_corners", true))
	var center := Vector2i(tile_index % size.x, tile_index / size.x)
	var open := []
	for direction in range(8):
		var tile := center + Vector2i(NEIGHBOR_DX[direction], NEIGHBOR_DY[direction])
		if tile.x < 0 or tile.y < 0 or tile.x >= size.x or tile.y >= size.y:
			continue
		var index := tile.y * size.x + tile.x
		if blocked[index] != 0 or (stop_mask[index] != 0 and pass_mask[index] == 0):
			continue
		open.append(tile)
	if open.size() < 2:
		return false
	var group := []
	group.resize(open.size())
	group.fill(-1)
	var groups := 0
	for first in range(open.size()):
		if int(group[first]) >= 0:
			continue
		group[first] = groups
		var queue := [first]
		while not queue.is_empty():
			var current: int = queue.pop_back()
			var a: Vector2i = open[current]
			for other in range(open.size()):
				if int(group[other]) >= 0:
					continue
				var b: Vector2i = open[other]
				if maxi(absi(a.x - b.x), absi(a.y - b.y)) != 1:
					continue
				# A diagonal step between two blocked corners (the hero's own
				# tile counts as one) needs the native eight-way rule.
				if a.x != b.x and a.y != b.y and not native_corners:
					var corner_a := Vector2i(a.x, b.y)
					var corner_b := Vector2i(b.x, a.y)
					if (corner_a == center or blocked[corner_a.y * size.x + corner_a.x] != 0) and (corner_b == center or blocked[corner_b.y * size.x + corner_b.x] != 0):
						continue
				group[other] = groups
				queue.append(other)
		groups += 1
	return groups > 1

static func _next_to_any(tile: Vector2i, others: Array) -> bool:
	for other in others:
		if maxi(absi(other.x - tile.x), absi(other.y - tile.y)) <= 1:
			return true
	return false

static func _profile_add(context: Dictionary, key: String, started: int) -> void:
	var profile: Dictionary = context.get("profile", {})
	profile[key] = float(profile.get(key, 0.0)) + float(Time.get_ticks_usec() - started) / 1000.0
	context["profile"] = profile

static func _best_candidate(session: SessionStateStoreScript.SessionData, context: Dictionary, entry: Dictionary, search: Dictionary, movement_max: int) -> Dictionary:
	var goal: Dictionary = entry.get(AI_HERO_KEY, {}).get("goal", {})
	var avoid: Dictionary = entry.get(AI_HERO_KEY, {}).get("avoid", {}) if entry.get(AI_HERO_KEY, {}).get("avoid", {}) is Dictionary else {}
	var seen := {}
	var best := {}
	var best_score := 0.0
	var power := hero_power(entry)
	var needs := _resource_needs(session, context)
	var known := _explored(session, context, LevelRules.level_of(entry))
	var stops: Dictionary = search.get("stops", {})
	for tile_index in stops.keys():
		var distance := int(search.dist[int(tile_index)])
		# Stepping into a guard's zone means fighting it first, as it does for
		# the human: whatever else lies there is reached through that fight.
		var guarded := false
		for ref in stops[tile_index]:
			if int(ref.kind) == STOP_ENCOUNTER:
				guarded = true
		for ref in stops[tile_index]:
			if guarded and int(ref.kind) != STOP_ENCOUNTER:
				continue
			# Map objects count once explored; armies and heroes once in sight.
			if int(ref.kind) not in [STOP_HERO, STOP_AI_HERO] and known[int(tile_index)] == 0:
				continue
			var key := "%d:%d" % [int(ref.kind), int(ref.index)]
			if seen.has(key) and int(seen[key]) <= distance:
				continue
			seen[key] = distance
			var candidate := _candidate(session, context, entry, ref, power, needs, search)
			if candidate.is_empty() or int(avoid.get(String(candidate.get("id", "")), -1)) >= int(session.day):
				continue
			var value := float(candidate.get("value", 0.0))
			if value <= 0.0:
				continue
			var score := value / (1.0 + float(distance) / float(movement_max))
			if String(goal.get("id", "")) != "" and String(goal.get("id", "")) == String(candidate.get("id", "")):
				score *= GOAL_CONTINUITY_BONUS
			if score > best_score:
				best_score = score
				candidate["tile_index"] = int(tile_index)
				candidate["distance"] = distance
				candidate["score"] = score
				best = candidate
	var explore := _exploration_candidate(session, context, entry, search)
	if not explore.is_empty():
		var explore_score := float(explore.value) / (1.0 + float(explore.distance) / float(movement_max))
		if String(goal.get("kind", "")) == "explore":
			explore_score *= GOAL_CONTINUITY_BONUS
		if explore_score > best_score:
			explore["score"] = explore_score
			best = explore
	return best

## The nearest reachable tile at the edge of what this player has seen: a
## human sends idle heroes to scout, so does the AI.
static func _exploration_candidate(session: SessionStateStoreScript.SessionData, context: Dictionary, entry: Dictionary, search: Dictionary) -> Dictionary:
	var known := _explored(session, context, LevelRules.level_of(entry))
	var order: PackedInt32Array = search.get("order", PackedInt32Array())
	var size: Vector2i = context.map_size
	for position in range(1, int(search.get("order_count", 0))):
		var tile_index := order[position]
		var x := tile_index % size.x
		var y := tile_index / size.x
		for direction in range(8):
			var nx: int = x + NEIGHBOR_DX[direction]
			var ny: int = y + NEIGHBOR_DY[direction]
			if nx < 0 or ny < 0 or nx >= size.x or ny >= size.y:
				continue
			if known[ny * size.x + nx] == 0:
				return {"kind": "explore", "id": "explore:%d" % tile_index, "index": tile_index, "value": EXPLORE_VALUE, "tile_index": tile_index, "distance": int(search.dist[tile_index])}
	return {}

static func _candidate(session: SessionStateStoreScript.SessionData, context: Dictionary, entry: Dictionary, ref: Dictionary, power: float, needs: Dictionary, search: Dictionary = {}) -> Dictionary:
	var controller := String(context.controller)
	match int(ref.kind):
		STOP_RESOURCE:
			return _resource_candidate(session, controller, entry, int(ref.index), power, needs, context.state.treasury)
		STOP_ARTIFACT:
			var nodes: Array = session.overworld.get("artifact_nodes", [])
			var node: Dictionary = nodes[int(ref.index)]
			if bool(node.get("collected", false)):
				return {}
			if not AdventureRules._artifact_guard_encounter_for_node(session, node).is_empty():
				return {}
			return {"kind": "artifact", "id": String(node.get("placement_id", "")), "index": int(ref.index), "value": 1100.0}
		STOP_TOWN:
			return _town_candidate(session, context, entry, int(ref.index), power)
		STOP_ENCOUNTER:
			return _encounter_candidate(session, context, entry, int(ref.index), power, needs, search)
		STOP_HERO:
			var heroes: Array = session.overworld.get("player_heroes", [])
			var hero: Dictionary = heroes[int(ref.index)]
			if not _player_hero_seen(session, context, hero):
				return {}
			var hero_power_value := army_power(hero.get("army", {}).get("stacks", []), hero)
			if power < hero_power_value * HERO_ATTACK_RATIO:
				return {}
			return {"kind": "hero", "id": String(hero.get("id", "")), "index": int(ref.index), "value": 1500.0 + hero_power_value * TROOP_VALUE_PER_POWER * 0.5}
		STOP_AI_HERO:
			var encounters: Array = session.overworld.get("encounters", [])
			var other: Dictionary = encounters[int(ref.index)]
			if PlayerRules.raid_controller_id(other) == controller:
				return _meet_candidate(session, context, entry, int(ref.index))
			if PlayerRules.allied(session, controller, PlayerRules.raid_controller_id(other)) or not _position_seen(session, context, LevelRules.position(other)):
				return {}
			var other_power := hero_power(other)
			if power < other_power * HERO_ATTACK_RATIO:
				return {}
			return {"kind": "ai_hero", "id": String(other.get("placement_id", "")), "index": int(ref.index), "value": 1200.0 + other_power * TROOP_VALUE_PER_POWER * 0.5, "fight_power": other_power}
	return {}

## A lesser hero walks its troops over to the main hero, the way a human
## chains reinforcements forward, keeping one creature to stay in the field.
static func _meet_candidate(session: SessionStateStoreScript.SessionData, context: Dictionary, entry: Dictionary, other_index: int) -> Dictionary:
	var encounters: Array = session.overworld.get("encounters", [])
	var other: Dictionary = encounters[other_index]
	var main_id := _decision_main_id(session, context)
	if main_id == "" or main_id == String(entry.get("placement_id", "")) or main_id != String(other.get("placement_id", "")):
		return {}
	var split := _split_for_handover(entry.get("enemy_army", {}).get("stacks", []))
	if split.give.is_empty():
		return {}
	var fits := _merge_stacks_into(other.get("enemy_army", {}).get("stacks", []), split.give)
	# Moving troops creates nothing by itself: a lesser hero finishes its own
	# errands first and brings its troops over when nothing else is worth more.
	var value := minf((army_power(split.give) - army_power(fits.left)) * TROOP_VALUE_PER_POWER * 0.6, MEET_VALUE_CAP)
	if value <= 50.0:
		return {}
	return {"kind": "meet", "id": String(other.get("placement_id", "")), "index": other_index, "value": value}

## Every creature but one of the weakest kind.
static func _split_for_handover(stacks: Variant) -> Dictionary:
	var give := []
	var keep := []
	if not (stacks is Array):
		return {"give": give, "keep": keep}
	var weakest := -1
	var weakest_power := INF
	for index in range(stacks.size()):
		var stack = stacks[index]
		if not (stack is Dictionary) or int(stack.get("count", 0)) <= 0:
			continue
		var one: Dictionary = stack.duplicate(true)
		one["count"] = 1
		var power := army_power([one])
		if power < weakest_power:
			weakest_power = power
			weakest = index
	if weakest < 0:
		return {"give": give, "keep": keep}
	for index in range(stacks.size()):
		var stack = stacks[index]
		if not (stack is Dictionary) or int(stack.get("count", 0)) <= 0:
			continue
		if index != weakest:
			give.append(stack.duplicate(true))
			continue
		var kept: Dictionary = stack.duplicate(true)
		kept["count"] = 1
		keep.append(kept)
		if int(stack.get("count", 0)) > 1:
			var rest: Dictionary = stack.duplicate(true)
			rest["count"] = int(stack.get("count", 0)) - 1
			give.append(rest)
	return {"give": give, "keep": keep}

static func _resource_candidate(session: SessionStateStoreScript.SessionData, controller: String, entry: Dictionary, index: int, power: float, needs: Dictionary, treasury: Dictionary) -> Dictionary:
	var nodes: Array = session.overworld.get("resource_nodes", [])
	var node: Dictionary = nodes[index]
	if NativeTransit.is_native(node):
		return {}
	var site := NodePayload.site_for_node(node)
	if site.is_empty() or bool(site.get("opens_route_on_claim", false)):
		return {}
	if not _overworld_rules().resource_node_is_present(node, site):
		return {}
	if not AdventureRules._resource_node_contestable_by_faction(node, site, controller, session):
		return {}
	var value := 0.0
	var fight := 0.0
	if CreatureDwellings.is_dwelling(site):
		if PlayerRules.resource_controller_id(node) == controller and not _can_hire_any(session, node, site, treasury):
			return {}
		if CreatureDwellings.guard_blocks(node, site, controller, session.day):
			var guard_power := army_power(CreatureDwellings.guard_stacks(node, site, controller, session.day))
			if power < guard_power * GUARD_WIN_RATIO:
				return {}
			fight = guard_power
		value = 500.0 + float(CreatureDwellings.week_value(node, site, session.day)) * 0.6
	elif VisitBuildings.is_visit_building(site):
		# The human's rules: a building asks for a hero level and a price.
		if int(entry.get("enemy_commander_state", {}).get("level", 1)) < VisitBuildings.required_level(site):
			return {}
		if not _can_afford(treasury, VisitBuildings.cost(site)):
			return {}
		value = 250.0 + float(VisitBuildings.ai_value(site))
	else:
		value = _payload_value(AdventureRules._resource_site_claim_rewards(site), needs)
		value += _recruit_set_value(_recruit_dict(site.get("claim_recruits", {})))
		if bool(site.get("persistent_control", false)):
			value += _payload_value(site.get("control_income", {}), needs) * 12.0 + 250.0
			# A site that musters troops every week is worth a week of them.
			value += _recruit_set_value(_recruit_dict(site.get("weekly_recruits", {})))
			var owner := PlayerRules.resource_controller_id(node)
			if owner != "" and owner != controller:
				value *= 1.3
	value -= _expected_loss_value(power, fight)
	if value <= 0.0:
		return {}
	# A guarded site is reached by beating its guard first (a separate target).
	if _resource_guarded(session, node, site):
		return {}
	return {"kind": "resource", "id": String(node.get("placement_id", "")), "index": index, "value": value, "fight_power": fight}

static func _can_hire_any(session: SessionStateStoreScript.SessionData, node: Dictionary, site: Dictionary, treasury: Dictionary) -> bool:
	var available := CreatureDwellings.population(node, site, session.day)
	for unit_id in available.keys():
		if int(available[unit_id]) > 0 and _can_afford(treasury, CreatureDwellings.unit_cost(String(unit_id))):
			return true
	return false

static func _encounter_candidate(session: SessionStateStoreScript.SessionData, context: Dictionary, entry: Dictionary, index: int, power: float, needs: Dictionary, search: Dictionary = {}) -> Dictionary:
	var value := _guard_fight_value(session, context, entry, index, power, needs, search)
	if is_nan(value) or value <= 0.0:
		return {}
	var guard: Dictionary = session.overworld.encounters[index]
	var guard_power := _guard_power(guard)
	return {"kind": "encounter", "id": String(guard.get("placement_id", "")), "index": index, "value": value, "fight_power": guard_power, "estimated_loss": _expected_loss_value(power, guard_power)}

## What beating a neutral army is worth to the hero, before travel: its
## reward, what it protects and the ground it opens, less the troops the fight
## should cost. Below zero when not worth it; NAN when the hero cannot take it.
static func _guard_fight_value(session: SessionStateStoreScript.SessionData, context: Dictionary, entry: Dictionary, index: int, power: float, needs: Dictionary, search: Dictionary = {}) -> float:
	var encounters: Array = session.overworld.get("encounters", [])
	var guard: Dictionary = encounters[index]
	if PlayerRules.raid_controller_id(guard) != "":
		return NAN
	var template := ContentService.get_encounter(String(guard.get("encounter_id", guard.get("id", ""))))
	if template.is_empty():
		return NAN
	var guard_power := _guard_power(guard)
	if guard_power <= 0.0 or power < guard_power * GUARD_WIN_RATIO:
		return NAN
	# What beating it pays, by its strength, as the battle will pay it.
	var rewards: Dictionary = _battle_rules().battle_rewards_for_strength(template, _neutral_army(guard).get("stacks", []), template.get("enemy_commander", {}))
	var value := _payload_value(rewards, needs) + 300.0
	value += _guarded_object_value(session, guard, needs, search, index, String(context.get("controller", "")))
	value += _passage_value(session, context, entry, search, index, needs)
	return value - _expected_loss_value(power, guard_power)

static func _guard_power(guard: Dictionary) -> float:
	var template := ContentService.get_encounter(String(guard.get("encounter_id", guard.get("id", ""))))
	return army_power(_neutral_army(guard).get("stacks", []), template.get("enemy_commander", {}))

## Troop value a fight should cost the stronger side. Under Lanchester's
## square law an army facing one r times its strength loses 1 - sqrt(1 - r^2)
## of its own: a few percent against a third of its strength, about a quarter
## against two thirds. It ranks the options; a previewed fight is then judged on
## what the battle really costs (`_fight_looks_good`).
## Troops a fight should cost against an army `ratio` times the hero's
## strength: Lanchester's square law (1 - sqrt(1 - r^2) of the hero's
## strength), raised to what this game's auto-resolve costs.
static func _expected_loss_value(power: float, enemy_power: float) -> float:
	if power <= 0.0 or enemy_power <= 0.0:
		return 0.0
	var ratio := minf(1.0, enemy_power / power)
	var share := minf(1.0, LOSS_ESTIMATE_FACTOR * (1.0 - sqrt(1.0 - ratio * ratio)) + LOSS_ESTIMATE_FLOOR)
	return power * share * TROOP_VALUE_PER_POWER

## What a guard protects. A linked target counts on its own; otherwise (the
## way generated maps place guards) every site standing in the guard's zone,
## since the hero reaches it only through this fight.
static func _guarded_object_value(session: SessionStateStoreScript.SessionData, guard: Dictionary, needs: Dictionary, search: Dictionary = {}, guard_index: int = -1, controller: String = "") -> float:
	var target_id := String(guard.get("guarded_object_placement_id", ""))
	if target_id == "":
		var link: Dictionary = AdventureRules._guard_link_for_encounter(guard)
		target_id = String(link.get("target_placement_id", ""))
	if target_id != "":
		var linked: Dictionary = AdventureRules._find_resource_by_placement(session, target_id).get("node", {})
		if not linked.is_empty():
			return _guarded_node_value(session, linked, needs, controller)
		var artifact: Dictionary = AdventureRules._find_artifact_by_placement(session, target_id).get("node", {})
		if not artifact.is_empty() and not bool(artifact.get("collected", false)):
			return 900.0
		return 0.0
	var zones: Dictionary = search.get("guard_zones", {})
	if not zones.has(guard_index):
		return 0.0
	var static_stops: Dictionary = search.get("static_stops", {})
	var nodes: Array = session.overworld.get("resource_nodes", [])
	var artifacts: Array = session.overworld.get("artifact_nodes", [])
	var towns: Array = session.overworld.get("towns", [])
	var value := 0.0
	for zone_index in zones[guard_index]:
		for ref in static_stops.get(int(zone_index), []):
			match int(ref.kind):
				STOP_RESOURCE:
					value += _guarded_node_value(session, nodes[int(ref.index)], needs, controller)
				STOP_ARTIFACT:
					if not bool(artifacts[int(ref.index)].get("collected", false)):
						value += 900.0
				STOP_TOWN:
					# A town whose doorway the guard holds: worth what taking it is.
					var town: Dictionary = towns[int(ref.index)]
					var owner := String(town.get("owner", "neutral"))
					var town_controller := "player" if owner == "player" else PlayerRules.town_controller_id(town)
					if owner == "neutral":
						value += 4000.0 * 0.8
					elif owner in ["player", "enemy"] and town_controller != controller and not PlayerRules.allied(session, controller, town_controller):
						value += 6000.0 * 0.8
	return value

static func _guarded_node_value(session: SessionStateStoreScript.SessionData, node: Dictionary, needs: Dictionary, controller: String) -> float:
	var site := NodePayload.site_for_node(node)
	if site.is_empty() or not _overworld_rules().resource_node_is_present(node, site):
		return 0.0
	if controller != "" and not AdventureRules._resource_node_contestable_by_faction(node, site, controller, session):
		return 0.0
	var value := _payload_value(AdventureRules._resource_site_claim_rewards(site), needs)
	if bool(site.get("persistent_control", false)):
		value += _payload_value(site.get("control_income", {}), needs) * 12.0 + 250.0
	if CreatureDwellings.is_dwelling(site):
		value += 500.0
	return value * 0.8

## What beating a guard opens: ground beyond its zone that the hero cannot
## reach today. A human clears a road guard to get at the map behind it; the
## unexplored part is worth scouting and sites already seen there are worth
## taking. Measured once per search.
static func _passage_value(session: SessionStateStoreScript.SessionData, context: Dictionary, entry: Dictionary, search: Dictionary, guard_index: int, needs: Dictionary) -> float:
	var zones: Dictionary = search.get("guard_zones", {})
	if not zones.has(guard_index) or not search.has("blocked"):
		return 0.0
	var cache: Dictionary = search.get("passage_cache", {})
	if cache.has(guard_index):
		return float(cache[guard_index])
	var size: Vector2i = search.size
	var dist: PackedInt32Array = search.dist
	var blocked: PackedByteArray = search.blocked
	var guard_mask: PackedByteArray = search.guard_mask
	var known := _explored(session, context, LevelRules.level_of(entry))
	# Flood out from the guard's zone over open ground the search did not reach,
	# stopping at other guards' zones.
	var zone: Array = zones[guard_index]
	var seen := {}
	for zone_index in zone:
		seen[int(zone_index)] = true
	var region := []
	var queue: Array = zone.duplicate()
	var head := 0
	while head < queue.size() and region.size() < PASSAGE_TILE_CAP:
		var tile := int(queue[head])
		head += 1
		var x := tile % size.x
		var y := tile / size.x
		for direction in range(8):
			var nx: int = x + NEIGHBOR_DX[direction]
			var ny: int = y + NEIGHBOR_DY[direction]
			if nx < 0 or ny < 0 or nx >= size.x or ny >= size.y:
				continue
			var next := ny * size.x + nx
			if seen.has(next) or dist[next] >= 0 or blocked[next] != 0 or guard_mask[next] != 0:
				continue
			seen[next] = true
			region.append(next)
			queue.append(next)
	var value := 0.0
	if not region.is_empty():
		var static_stops: Dictionary = search.get("static_stops", {})
		var power := hero_power(entry)
		var unexplored := 0
		var sites := 0.0
		for tile in region:
			if known[int(tile)] == 0:
				unexplored += 1
				continue
			for ref in static_stops.get(int(tile), []):
				if int(ref.kind) in [STOP_RESOURCE, STOP_ARTIFACT, STOP_TOWN]:
					sites += float(_candidate(session, context, entry, ref, power, needs).get("value", 0.0))
		value = minf(PASSAGE_VALUE_CAP, PASSAGE_BASE_VALUE + float(unexplored) * PASSAGE_UNEXPLORED_TILE_VALUE + sites * PASSAGE_KNOWN_SITE_SHARE)
	cache[guard_index] = value
	search["passage_cache"] = cache
	return value

static func _town_candidate(session: SessionStateStoreScript.SessionData, context: Dictionary, entry: Dictionary, index: int, power: float) -> Dictionary:
	var controller := String(context.controller)
	var towns: Array = session.overworld.get("towns", [])
	var town: Dictionary = towns[index]
	var owner := String(town.get("owner", "neutral"))
	if owner not in ["player", "enemy", "neutral"]:
		return {}
	var town_controller := PlayerRules.town_controller_id(town) if owner != "neutral" else ""
	var id := String(town.get("placement_id", ""))
	if owner == "enemy" and town_controller == controller:
		var block: Dictionary = entry.get(AI_HERO_KEY, {})
		if int(block.get("visited_town_day", -1)) == int(session.day):
			return {}
		var entrance := LevelRules.town_entrance(town)
		var standing_here := int(entrance.get("x", -1)) == int(entry.get("x", -2)) and int(entrance.get("y", -1)) == int(entry.get("y", -2))
		if not standing_here and not _town_entrance_free(session, town, controller):
			return {}
		var value := 0.0
		var main_id := _decision_main_id(session, context)
		# Only what the hero can take along counts: a full army leaves
		# creatures of other kinds behind.
		var gain: float = _garrison_pickup(entry.get("enemy_army", {}).get("stacks", []).duplicate(true), town.get("garrison", []).duplicate(true)).gain
		if main_id == "" or main_id == String(entry.get("placement_id", "")):
			value = gain * TROOP_VALUE_PER_POWER * 0.5
		elif _ferries_from(session, context, town, main_id):
			value = minf(gain * TROOP_VALUE_PER_POWER * 0.3, MEET_VALUE_CAP)
		else:
			var stacks: Array = entry.get("enemy_army", {}).get("stacks", [])
			if stacks.size() > 1:
				value = (army_power(stacks) - army_power([stacks[_weakest_stack_index(stacks)]])) * TROOP_VALUE_PER_POWER * 0.3
		if _town_threatened(session, context, town):
			value += 4000.0
		if value <= 50.0:
			return {}
		return {"kind": "town_own", "id": id, "index": index, "value": value}
	if owner != "neutral" and PlayerRules.allied(session, controller, town_controller if owner == "enemy" else "player"):
		return {}
	var defense := army_power(town.get("garrison", []))
	if owner == "player":
		var force: Dictionary = HeroCommandRulesScript.town_defense_force(session, town)
		defense = army_power(town.get("garrison", [])) + army_power(force.get("hero", {}).get("army", {}).get("stacks", []), force.get("hero", {}))
	if defense > 0.0 and power < defense * TOWN_ATTACK_RATIO:
		return {}
	var value := 6000.0 if owner == "player" else 4000.0
	return {"kind": "town_hostile" if owner != "neutral" else "town_neutral", "id": id, "index": index, "value": value - _expected_loss_value(power, defense), "fight_power": defense}

static func _player_hero_seen(session: SessionStateStoreScript.SessionData, context: Dictionary, hero: Dictionary) -> bool:
	return _position_seen(session, context, hero.get("position", {}) if hero.get("position", {}) is Dictionary else {})

## Whether one of the player's heroes or towns can see this spot right now.
static func _position_seen(session: SessionStateStoreScript.SessionData, context: Dictionary, position: Dictionary) -> bool:
	for entry in active_hero_entries(session, String(context.controller)):
		if not LevelRules.same_level(entry, position):
			continue
		var radius := HeroCommandRulesScript.scouting_radius_for_hero(entry.get("enemy_commander_state", {}))
		if HeroCommandRulesScript.within_scout_radius(int(position.get("x", 0)) - int(entry.get("x", 0)), int(position.get("y", 0)) - int(entry.get("y", 0)), radius):
			return true
	for town in session.overworld.get("towns", []):
		if town is Dictionary and String(town.get("owner", "")) == "enemy" and PlayerRules.town_controller_id(town) == String(context.controller) and LevelRules.same_level(town, position):
			if HeroCommandRulesScript.within_scout_radius(int(position.get("x", 0)) - int(town.get("x", 0)), int(position.get("y", 0)) - int(town.get("y", 0)), TOWN_SIGHT_RADIUS):
				return true
	return false

## Hostile heroes the controller can see, with their strength and reach.
static func _hostile_heroes(session: SessionStateStoreScript.SessionData, controller: String) -> Array:
	var result := []
	var context := {"controller": controller}
	for hero in session.overworld.get("player_heroes", []):
		if not (hero is Dictionary) or PlayerRules.allied(session, controller, "player"):
			continue
		if not _player_hero_seen(session, context, hero):
			continue
		var position: Dictionary = hero.get("position", {})
		var movement: Dictionary = hero.get("movement", {}) if hero.get("movement", {}) is Dictionary else {}
		result.append({"x": int(position.get("x", 0)), "y": int(position.get("y", 0)), "level": LevelRules.level_of(position), "power": army_power(hero.get("army", {}).get("stacks", []), hero), "reach": maxi(6, int(movement.get("max", 10)))})
	return result

# --- Knowledge ----------------------------------------------------------------

## A computer player knows the map only where its towns and heroes have looked,
## as the human does under fog. Explored tiles are kept per level in the enemy
## state as a bitset.
static func _explored(session: SessionStateStoreScript.SessionData, context: Dictionary, level: int) -> PackedByteArray:
	var maps: Dictionary = context.get("explored", {})
	if maps.has(level):
		return maps[level]
	var size: Vector2i = context.map_size
	var count := size.x * size.y
	var tiles := PackedByteArray()
	tiles.resize(count)
	var stored = context.state.get(EXPLORED_KEY, {})
	var encoded := String(stored.get(str(level), "")) if stored is Dictionary else ""
	if encoded != "":
		var bits := Marshalls.base64_to_raw(encoded)
		for index in range(mini(count, bits.size() * 8)):
			if (bits[index >> 3] >> (index & 7)) & 1:
				tiles[index] = 1
	maps[level] = tiles
	context["explored"] = maps
	return tiles

static func _store_explored(context: Dictionary) -> void:
	var maps: Dictionary = context.get("explored", {})
	if maps.is_empty():
		return
	var stored: Dictionary = context.state.get(EXPLORED_KEY, {}) if context.state.get(EXPLORED_KEY, {}) is Dictionary else {}
	for level in maps.keys():
		var tiles: PackedByteArray = maps[level]
		var bits := PackedByteArray()
		bits.resize((tiles.size() + 7) / 8)
		for index in range(tiles.size()):
			if tiles[index] != 0:
				bits[index >> 3] = bits[index >> 3] | (1 << (index & 7))
		stored[str(level)] = Marshalls.raw_to_base64(bits)
	context.state[EXPLORED_KEY] = stored

static func _reveal(session: SessionStateStoreScript.SessionData, context: Dictionary, point: Dictionary, radius: int) -> void:
	var level := LevelRules.level_of(point)
	var tiles := _explored(session, context, level)
	var size: Vector2i = context.map_size
	var cx := int(point.get("x", 0))
	var cy := int(point.get("y", 0))
	for dy in range(-radius, radius + 1):
		var y := cy + dy
		if y < 0 or y >= size.y:
			continue
		var half := HeroCommandRulesScript.scout_row_half_width(dy, radius)
		if half < 0:
			continue
		for x in range(maxi(0, cx - half), mini(size.x - 1, cx + half) + 1):
			tiles[y * size.x + x] = 1
	context.explored[level] = tiles

static func _reveal_from_holdings(session: SessionStateStoreScript.SessionData, context: Dictionary) -> void:
	var controller := String(context.controller)
	for town in session.overworld.get("towns", []):
		if town is Dictionary and String(town.get("owner", "")) == "enemy" and PlayerRules.town_controller_id(town) == controller:
			_reveal(session, context, LevelRules.town_entrance(town), TOWN_SIGHT_RADIUS)
	for entry in active_hero_entries(session, controller):
		_reveal(session, context, LevelRules.position(entry), _sight_radius(entry))

static func _sight_radius(entry: Dictionary) -> int:
	return HeroCommandRulesScript.scouting_radius_for_hero(entry.get("enemy_commander_state", {}))

# --- Movement -----------------------------------------------------------------

static func _follow_plan(session: SessionStateStoreScript.SessionData, context: Dictionary, index: int, plan: Dictionary) -> Dictionary:
	var entry: Dictionary = session.overworld.encounters[index]
	var block: Dictionary = entry.get(AI_HERO_KEY, {})
	var movement: Dictionary = block.get("movement", {})
	var path: Array = plan.get("path", [])
	var level := LevelRules.level_of(entry)
	# The goal stays private to the AI (no raid-style target fields that the
	# human's threat forecasts would read).
	block["goal"] = {"kind": String(plan.get("kind", "")), "id": String(plan.get("id", ""))}
	if path.is_empty():
		entry[AI_HERO_KEY] = block
		_store_entry(session, index, entry)
		return _interact(session, context, index, plan)
	# Walking out of the town ends a parked hero's wait there.
	block.erase("parked")
	var last := path.size() - 1
	var arrived := false
	for step_index in range(path.size()):
		if int(movement.get("current", 0)) <= 0:
			break
		var tile: Vector2i = path[step_index]
		movement["current"] = int(movement.get("current", 0)) - 1
		if step_index == last and _tile_blocked_for_standing(session, context, tile, level, String(entry.get("placement_id", ""))):
			arrived = true
			break
		var before := LevelRules.position(entry)
		plan["retreat_tile"] = Vector2i(int(before.get("x", 0)), int(before.get("y", 0)))
		entry["x"] = tile.x
		entry["y"] = tile.y
		TurnPlayback.move(session, entry, before)
		_reveal(session, context, LevelRules.position(entry), _sight_radius(entry))
		if step_index == last:
			arrived = true
	block["movement"] = movement
	entry[AI_HERO_KEY] = block
	_store_entry(session, index, entry)
	_overworld_rules().invalidate_spatial_lookup(session)
	if not arrived:
		return {"arrived": false}
	return _interact(session, context, index, plan)

## Whether the hero must act from the neighbouring tile. Like the human, a hero
## ends its route on a town doorway or a site's visit tile even where that tile
## is part of the object's body; only another army or hero keeps it out. The
## player's own heroes in one of its towns leave room for more.
static func _tile_blocked_for_standing(session: SessionStateStoreScript.SessionData, context: Dictionary, tile: Vector2i, level: int, actor_id: String) -> bool:
	var controller := String(context.get("controller", ""))
	var size: Vector2i = context.map_size if context.has("map_size") else _overworld_rules().derive_map_size(session)
	var own_door := controller != "" and _own_town_doors(session, controller, level, size).has(tile.y * size.x + tile.x)
	for entry in session.overworld.get("encounters", []):
		if entry is Dictionary and String(entry.get("placement_id", "")) != actor_id and LevelRules.level_of(entry) == level \
				and int(entry.get("x", -1)) == tile.x and int(entry.get("y", -1)) == tile.y and not _is_resolved(session, String(entry.get("placement_id", ""))):
			if own_door and is_ai_hero(entry) and PlayerRules.raid_controller_id(entry) == controller:
				continue
			return true
	for hero in session.overworld.get("player_heroes", []):
		var position: Dictionary = hero.get("position", {}) if hero is Dictionary and hero.get("position", {}) is Dictionary else {}
		if LevelRules.level_of(position) == level and int(position.get("x", -1)) == tile.x and int(position.get("y", -1)) == tile.y:
			return true
	return false

## Static blocking for one level, built once per enemy turn: impassable terrain
## (rock, water) and every body the human's movement treats as solid, except
## armies, which move and are added for each search.
static func _level_surface(session: SessionStateStoreScript.SessionData, context: Dictionary, level: int) -> Dictionary:
	var levels: Dictionary = context.levels
	if levels.has(level):
		return levels[level]
	var surface_started := Time.get_ticks_usec()
	var overworld_rules = _overworld_rules()
	var size: Vector2i = context.map_size
	var blocked := PackedByteArray()
	blocked.resize(size.x * size.y)
	var rows: Array = LevelRules.terrain_rows(session, level)
	for y in range(size.y):
		var row: Array = rows[y] if y < rows.size() and rows[y] is Array else []
		for x in range(size.x):
			if x >= row.size() or not overworld_rules.terrain_id_is_passable(String(row[x])):
				blocked[y * size.x + x] = 1
	var bodies: Dictionary = overworld_rules._build_blocked_tile_index(session, level, "", {})
	var army_tiles := {}
	for encounter in session.overworld.get("encounters", []):
		if encounter is Dictionary and LevelRules.level_of(encounter) == level:
			for tile in overworld_rules._generated_body_tiles_for_placement(encounter, bool(encounter.get("blocking_body", true))):
				army_tiles[overworld_rules._tile_key(tile)] = true
	for key in bodies.keys():
		if army_tiles.has(key):
			continue
		var parts := String(key).split(",")
		if parts.size() < 2:
			continue
		var x := int(parts[0])
		var y := int(parts[1])
		if x >= 0 and y >= 0 and x < size.x and y < size.y:
			blocked[y * size.x + x] = 1
	var stops := {}
	var resources: Array = session.overworld.get("resource_nodes", [])
	for index in range(resources.size()):
		var node = resources[index]
		if not (node is Dictionary) or LevelRules.level_of(node) != level:
			continue
		var map_object: Dictionary = overworld_rules._map_object_for_resource_node(node)
		for tile in overworld_rules._resource_node_world_interaction_tiles(map_object, node):
			if tile is Vector2i:
				_add_stop(stops, tile, size, {"kind": STOP_RESOURCE, "index": index})
	var artifacts: Array = session.overworld.get("artifact_nodes", [])
	for index in range(artifacts.size()):
		var artifact = artifacts[index]
		if artifact is Dictionary and LevelRules.level_of(artifact) == level:
			_add_stop(stops, Vector2i(int(artifact.get("x", -1)), int(artifact.get("y", -1))), size, {"kind": STOP_ARTIFACT, "index": index})
	var towns: Array = session.overworld.get("towns", [])
	for index in range(towns.size()):
		var town = towns[index]
		if town is Dictionary and LevelRules.level_of(town) == level:
			var entrance := LevelRules.town_entrance(town)
			_add_stop(stops, Vector2i(int(entrance.get("x", -1)), int(entrance.get("y", -1))), size, {"kind": STOP_TOWN, "index": index})
	var stop_mask := PackedByteArray()
	stop_mask.resize(size.x * size.y)
	# Map sites a hero may also walk across once they hold nothing more for it
	# (a picked-up cache, its own mine): stepping on and off is a move like
	# any other. Towns always end a route.
	var site_stops := []
	for tile_index in stops.keys():
		stop_mask[int(tile_index)] = 1
		var sites_only := true
		for ref in stops[tile_index]:
			if int(ref.kind) not in [STOP_RESOURCE, STOP_ARTIFACT]:
				sites_only = false
		if sites_only:
			var refs := []
			for ref in stops[tile_index]:
				refs.append({"kind": int(ref.kind), "index": int(ref.index)})
			site_stops.append({"tile": int(tile_index), "refs": refs})
	# Neutral armies stand still: decode their bodies and engagement zones once.
	var neutrals := []
	var encounters: Array = session.overworld.get("encounters", [])
	for index in range(encounters.size()):
		var encounter = encounters[index]
		if not (encounter is Dictionary) or LevelRules.level_of(encounter) != level or PlayerRules.raid_controller_id(encounter) != "":
			continue
		var body := []
		for tile in overworld_rules._generated_body_tiles_for_placement(encounter, bool(encounter.get("blocking_body", true))):
			if tile is Vector2i and tile.x >= 0 and tile.y >= 0 and tile.x < size.x and tile.y < size.y:
				body.append(tile.y * size.x + tile.x)
		var zone := []
		var engagement: Array = overworld_rules._guard_engagement_world_tiles(encounter)
		if engagement.is_empty():
			engagement = [Vector2i(int(encounter.get("x", -1)), int(encounter.get("y", -1)))]
		for tile in engagement:
			if tile is Vector2i and tile.x >= 0 and tile.y >= 0 and tile.x < size.x and tile.y < size.y:
				zone.append(tile.y * size.x + tile.x)
		neutrals.append({"id": String(encounter.get("placement_id", "")), "index": index, "body": body, "zone": zone})
	var surface := {"blocked": blocked, "stops": stops, "stop_mask": stop_mask, "site_stops": site_stops, "neutrals": neutrals}
	levels[level] = surface
	_profile_add(context, "surface_ms", surface_started)
	return surface

## Whether a hero may cross this site's tile without stopping: the pickup is
## gone, or the site is already this player's (or an ally's).
static func _site_stop_passable(session: SessionStateStoreScript.SessionData, controller: String, ref: Dictionary) -> bool:
	match int(ref.kind):
		STOP_ARTIFACT:
			var artifacts: Array = session.overworld.get("artifact_nodes", [])
			var artifact = artifacts[int(ref.index)] if int(ref.index) < artifacts.size() else {}
			return artifact is Dictionary and bool(artifact.get("collected", false))
		STOP_RESOURCE:
			var nodes: Array = session.overworld.get("resource_nodes", [])
			var node = nodes[int(ref.index)] if int(ref.index) < nodes.size() else {}
			if not (node is Dictionary) or NativeTransit.is_native(node):
				return false
			var site := NodePayload.site_for_node(node)
			if site.is_empty():
				return false
			if not _overworld_rules().resource_node_is_present(node, site):
				return true
			# A building a hero visits and leaves standing (a shrine, a school, a
			# roadside producer) can be crossed on the way elsewhere; the hero may
			# still stop there to visit. Otherwise a pocket whose only way out ran
			# over such a doorway trapped the hero that entered it.
			if String(site.get("family", "")) in WALK_ACROSS_SITE_FAMILIES:
				return true
			var owner := PlayerRules.resource_controller_id(node)
			return owner != "" and PlayerRules.allied(session, controller, owner)
	return false

static func _add_stop(stops: Dictionary, tile: Vector2i, size: Vector2i, ref: Dictionary) -> void:
	if tile.x < 0 or tile.y < 0 or tile.x >= size.x or tile.y >= size.y:
		return
	var tile_index := tile.y * size.x + tile.x
	if not stops.has(tile_index):
		stops[tile_index] = []
	stops[tile_index].append(ref)

## Breadth-first search over the hero's level. Object entrances, armies,
## guard zones and heroes end a route: they can be the destination, never a
## tile to walk through. Each step costs one movement point, as for the human.
## The player's own heroes inside its towns stand in no one's way. With
## `past_own_heroes` the player's other heroes do not count at all: the search
## then shows what the hero could reach if they stepped aside.
static func _search(session: SessionStateStoreScript.SessionData, context: Dictionary, entry: Dictionary, radius: int, past_own_heroes: bool = false) -> Dictionary:
	context["search_count"] = int(context.get("search_count", 0)) + 1
	var level := LevelRules.level_of(entry)
	var surface := _level_surface(session, context, level)
	var size: Vector2i = context.map_size
	var width := size.x
	var count := size.x * size.y
	var static_stops: Dictionary = surface.stops
	var actor_id := String(entry.get("placement_id", ""))
	var controller := String(context.controller)
	var own_doors := _own_town_doors(session, controller, level, size)
	# Blocking and route-ending tiles for this search: the day's static masks
	# plus every army and hero where it stands now.
	var blocked: PackedByteArray = surface.blocked.duplicate()
	var stop_mask: PackedByteArray = surface.stop_mask.duplicate()
	var dynamic_stops := {}
	var army_tiles := {}
	var resolved := _resolved_lookup(session)
	var encounters: Array = session.overworld.get("encounters", [])
	var guard_mask := PackedByteArray()
	guard_mask.resize(count)
	var guard_zones := {}
	for record in surface.neutrals:
		if resolved.has(String(record.id)):
			continue
		for body_index in record.body:
			blocked[int(body_index)] = 1
			army_tiles[int(body_index)] = true
		var zone := []
		for zone_index in record.zone:
			# Rock or an object's body inside the zone is no place to stand, as
			# for the human; only a doorway or visit tile there can be entered.
			if surface.blocked[int(zone_index)] != 0 and not static_stops.has(int(zone_index)):
				continue
			zone.append(int(zone_index))
			stop_mask[int(zone_index)] = 1
			guard_mask[int(zone_index)] = 1
			_add_stop_index(dynamic_stops, int(zone_index), {"kind": STOP_ENCOUNTER, "index": int(record.index)})
		guard_zones[int(record.index)] = zone
	for index in range(encounters.size()):
		var other = encounters[index]
		if not (other is Dictionary) or LevelRules.level_of(other) != level:
			continue
		var other_controller := PlayerRules.raid_controller_id(other)
		if other_controller == "":
			continue
		var other_id := String(other.get("placement_id", ""))
		if other_id == actor_id or resolved.has(other_id):
			continue
		var tile_index := _tile_index_of(other, size)
		if tile_index < 0:
			continue
		# Rival heroes can be attacked and this player's own heroes met; both
		# end a route, neither can be walked through.
		var meetable := other_controller == controller
		if meetable and is_ai_hero(other) and (past_own_heroes or own_doors.has(tile_index)):
			continue
		if not is_ai_hero(other) or (not meetable and PlayerRules.allied(session, controller, other_controller)):
			blocked[tile_index] = 1
			army_tiles[tile_index] = true
		else:
			stop_mask[tile_index] = 1
			_add_stop_index(dynamic_stops, tile_index, {"kind": STOP_AI_HERO, "index": index})
	var heroes: Array = session.overworld.get("player_heroes", [])
	var human_allied := PlayerRules.allied(session, controller, "player")
	for index in range(heroes.size()):
		var hero = heroes[index]
		var position: Dictionary = hero.get("position", {}) if hero is Dictionary and hero.get("position", {}) is Dictionary else {}
		if position.is_empty() or LevelRules.level_of(position) != level:
			continue
		var hero_index := _tile_index_of(position, size)
		if hero_index < 0:
			continue
		if human_allied:
			blocked[hero_index] = 1
			army_tiles[hero_index] = true
		else:
			stop_mask[hero_index] = 1
			_add_stop_index(dynamic_stops, hero_index, {"kind": STOP_HERO, "index": index})
	var pass_mask := PackedByteArray()
	pass_mask.resize(count)
	for site in surface.get("site_stops", []):
		var site_tile := int(site.tile)
		if dynamic_stops.has(site_tile) or army_tiles.has(site_tile):
			continue
		var open := true
		for ref in site.refs:
			if not _site_stop_passable(session, controller, ref):
				open = false
				break
		if open:
			pass_mask[site_tile] = 1
	var dist := PackedInt32Array()
	dist.resize(count)
	dist.fill(-1)
	var parent := PackedInt32Array()
	parent.resize(count)
	parent.fill(-1)
	var reached_stops := {}
	var start_index := _tile_index_of(entry, size)
	if start_index < 0:
		return {"dist": dist, "parent": parent, "stops": reached_stops, "size": size, "start": -1}
	dist[start_index] = 0
	var queue := PackedInt32Array()
	queue.resize(count)
	var head := 0
	var tail := 1
	queue[0] = start_index
	var native_corners := NativeTransit.uses_native_adjacency(session)
	var reached := []
	# Whether the radius cut the search short: if not, it reached every tile the
	# hero can walk to.
	var capped := false
	while head < tail:
		var current := queue[head]
		head += 1
		var next_distance := dist[current] + 1
		if next_distance > radius:
			capped = true
			continue
		var cx := current % width
		var cy := current / width
		for direction in range(8):
			var dx: int = NEIGHBOR_DX[direction]
			var dy: int = NEIGHBOR_DY[direction]
			var nx := cx + dx
			var ny := cy + dy
			if nx < 0 or ny < 0 or nx >= width or ny >= size.y:
				continue
			var next := ny * width + nx
			if dist[next] >= 0:
				continue
			if dx != 0 and dy != 0 and not native_corners and blocked[cy * width + nx] != 0 and blocked[ny * width + cx] != 0:
				continue
			if stop_mask[next] != 0:
				dist[next] = next_distance
				parent[next] = current
				reached.append(next)
				if pass_mask[next] != 0:
					queue[tail] = next
					tail += 1
				continue
			if blocked[next] != 0:
				continue
			dist[next] = next_distance
			parent[next] = current
			queue[tail] = next
			tail += 1
	# The hero's own tile counts as reached at distance zero (it may stand in a
	# town entrance or on a site it can still act on).
	if stop_mask[start_index] != 0:
		reached.append(start_index)
	for tile_index in reached:
		var refs: Array = []
		if static_stops.has(tile_index):
			refs.append_array(static_stops[tile_index])
		if dynamic_stops.has(tile_index):
			refs.append_array(dynamic_stops[tile_index])
		if not refs.is_empty():
			reached_stops[tile_index] = refs
	return {
		"dist": dist,
		"parent": parent,
		"stops": reached_stops,
		"size": size,
		"start": start_index,
		"order": queue,
		"order_count": tail,
		"capped": capped,
		"blocked": blocked,
		"stop_mask": stop_mask,
		"pass_mask": pass_mask,
		"native_corners": native_corners,
		"guard_mask": guard_mask,
		"guard_zones": guard_zones,
		"static_stops": static_stops,
	}

static func _tile_index_of(point: Dictionary, size: Vector2i) -> int:
	var x := int(point.get("x", -1))
	var y := int(point.get("y", -1))
	if x < 0 or y < 0 or x >= size.x or y >= size.y:
		return -1
	return y * size.x + x

static func _add_stop_index(stops: Dictionary, tile_index: int, ref: Dictionary) -> void:
	if not stops.has(tile_index):
		stops[tile_index] = []
	stops[tile_index].append(ref)

static func _path_to(search: Dictionary, tile_index: int) -> Array:
	var size: Vector2i = search.size
	var path := []
	var cursor := tile_index
	var parent: PackedInt32Array = search.parent
	while cursor >= 0 and cursor != int(search.start):
		path.push_front(Vector2i(cursor % size.x, cursor / size.x))
		cursor = parent[cursor]
	return path

# --- Interactions -------------------------------------------------------------

static func _interact(session: SessionStateStoreScript.SessionData, context: Dictionary, index: int, plan: Dictionary) -> Dictionary:
	match String(plan.get("kind", "")):
		"resource":
			return _claim_resource(session, context, index, plan)
		"artifact":
			return _take_artifact(session, context, index, plan)
		"encounter":
			return _fight_neutral(session, context, index, plan)
		"town_own":
			var entry: Dictionary = session.overworld.encounters[index]
			var block: Dictionary = entry.get(AI_HERO_KEY, {})
			block.erase("visited_town_day")
			entry[AI_HERO_KEY] = block
			_store_entry(session, index, entry)
			var visit := _visit_own_town_if_inside(session, context, index)
			return {"arrived": true, "acted": true, "events": visit.get("events", [])}
		"town_neutral", "town_hostile":
			return _attack_town(session, context, index, plan)
		"hero":
			return _attack_player_hero(session, context, index, plan)
		"ai_hero":
			return _fight_ai_hero(session, context, index, plan)
		"meet":
			return _meet_hero(session, context, index, plan)
		"explore":
			return {"arrived": true, "acted": true}
		"wait":
			var waiting: Dictionary = session.overworld.encounters[index]
			var waiting_block: Dictionary = waiting.get(AI_HERO_KEY, {})
			waiting_block["goal"] = {}
			waiting[AI_HERO_KEY] = waiting_block
			_store_entry(session, index, waiting)
			return {"arrived": true, "acted": true}
		"park":
			_park(session, String(session.overworld.encounters[index].get("placement_id", "")), String(plan.get("id", "")))
			return {"arrived": true, "acted": true}
	return {"arrived": true}

static func _claim_resource(session: SessionStateStoreScript.SessionData, context: Dictionary, index: int, plan: Dictionary) -> Dictionary:
	var controller := String(context.controller)
	var entry: Dictionary = session.overworld.encounters[index]
	var nodes: Array = session.overworld.get("resource_nodes", [])
	var node_index := int(plan.get("index", -1))
	if node_index < 0 or node_index >= nodes.size():
		return {"arrived": true}
	var node: Dictionary = nodes[node_index]
	var site := NodePayload.site_for_node(node)
	var events := []
	if CreatureDwellings.is_dwelling(site) and CreatureDwellings.guard_blocks(node, site, controller, session.day):
		var guard_stacks: Array = CreatureDwellings.guard_stacks(node, site, controller, session.day)
		var fight := _auto_resolve(session, context, index, {
			"placement_id": CreatureDwellings.guard_key(String(node.get("placement_id", ""))),
			"encounter_id": CreatureDwellings.GUARD_ENCOUNTER_ID,
			"enemy_army": {"id": "dwelling_guard", "name": "Dwelling Guard", "stacks": guard_stacks},
		})
		events.append_array(fight.get("events", []))
		node = session.overworld.resource_nodes[node_index]
		CreatureDwellings.record_guard_result(node, controller, fight.get("enemy_survivors", []), bool(fight.get("won", false)), session.day)
		nodes = session.overworld.get("resource_nodes", [])
		nodes[node_index] = node
		session.overworld["resource_nodes"] = nodes
		if not bool(fight.get("won", false)):
			return {"arrived": true, "events": events}
		entry = session.overworld.encounters[index]
	var was_present: bool = _overworld_rules().resource_node_is_present(node, site)
	var node_before: Dictionary = node.duplicate(true)
	var army_before: Variant = entry.get("enemy_army", {}).duplicate(true)
	var actor := entry.duplicate(true)
	actor["target_kind"] = "resource"
	actor["target_placement_id"] = String(node.get("placement_id", ""))
	var state: Dictionary = context.state
	var result: Dictionary = AdventureRules._secure_resource_target(session, actor, state, controller, context.config)
	var updated: Dictionary = result.get("encounter", actor)
	entry["enemy_army"] = updated.get("enemy_army", entry.get("enemy_army", {}))
	var commander: Dictionary = updated.get("enemy_commander_state", entry.get("enemy_commander_state", {}))
	var claimed: Dictionary = session.overworld.resource_nodes[node_index]
	# The experience a site grants goes to the hero, as it does for the human.
	var experience := int(AdventureRules._resource_site_claim_rewards(site).get("experience", 0))
	if experience > 0 and claimed != node_before:
		commander = AdventureRules._normalize_enemy_progression(HeroProgressionRulesScript.add_experience(commander, experience).get("hero", commander))
	entry["enemy_commander_state"] = commander
	_store_entry(session, index, entry)
	# A claim can remove the site or open its route body; either frees the tiles
	# the site blocked before the claim.
	var opened: bool = node_before.get("package_block_tiles", []) != claimed.get("package_block_tiles", [])
	if was_present and (opened or not _overworld_rules().resource_node_is_present(claimed, site)):
		_clear_static_body(session, context, node_before)
	events.append_array(result.get("ai_events", []))
	if result.get("ai_event", {}) is Dictionary and not result.get("ai_event", {}).is_empty() and result.get("ai_events", []).is_empty():
		events.append(result.get("ai_event", {}))
	var acted: bool = not events.is_empty() or claimed != node_before or entry.get("enemy_army", {}) != army_before
	return {"arrived": true, "events": events, "acted": acted}

static func _clear_static_body(session: SessionStateStoreScript.SessionData, context: Dictionary, node: Dictionary) -> void:
	context["topology_changed"] = true
	var level := LevelRules.level_of(node)
	if not context.levels.has(level):
		return
	var surface: Dictionary = context.levels[level]
	var size: Vector2i = context.map_size
	var overworld_rules = _overworld_rules()
	var tiles: Array = []
	var package_mask: Variant = node.get("package_block_tiles", null)
	if package_mask is Array:
		tiles = overworld_rules._world_tiles_from_payload_array(package_mask)
	else:
		tiles = overworld_rules._map_object_world_body_tiles(overworld_rules._map_object_for_resource_node(node), node)
	var blocked: PackedByteArray = surface.blocked
	for tile in tiles:
		if tile is Vector2i and tile.x >= 0 and tile.y >= 0 and tile.x < size.x and tile.y < size.y:
			var terrain := String(LevelRules.terrain_rows(session, level)[tile.y][tile.x])
			blocked[tile.y * size.x + tile.x] = 0 if overworld_rules.terrain_id_is_passable(terrain) else 1
	surface["blocked"] = blocked

static func _take_artifact(session: SessionStateStoreScript.SessionData, context: Dictionary, index: int, plan: Dictionary) -> Dictionary:
	var controller := String(context.controller)
	var entry: Dictionary = session.overworld.encounters[index]
	var nodes: Array = session.overworld.get("artifact_nodes", [])
	var node_index := int(plan.get("index", -1))
	if node_index < 0 or node_index >= nodes.size() or bool(nodes[node_index].get("collected", false)):
		return {"arrived": true}
	var node: Dictionary = nodes[node_index]
	node["collected"] = true
	PlayerRules.set_resource_controller(node, session, controller)
	node["collected_day"] = int(session.day)
	nodes[node_index] = node
	session.overworld["artifact_nodes"] = nodes
	var artifact_id := String(node.get("artifact_id", ""))
	var commander: Dictionary = entry.get("enemy_commander_state", {})
	var claim: Dictionary = ArtifactRulesScript.claim_artifact(commander, artifact_id, "Found", true)
	if bool(claim.get("ok", false)):
		entry["enemy_commander_state"] = claim.get("hero", commander)
	_store_entry(session, index, entry)
	context["topology_changed"] = true
	TurnPlayback.action(session, entry, "picks up an artifact")
	var label := ArtifactRulesScript.describe_artifact(artifact_id)
	var event := _event(session, context, "ai_artifact_secured", entry, {
		"target_kind": "artifact",
		"target_placement_id": String(node.get("placement_id", "")),
		"target_label": label,
		"target_x": int(node.get("x", 0)),
		"target_y": int(node.get("y", 0)),
	}, "%s picks up %s." % [hero_name(entry), label], ["artifact_secured"])
	return {"arrived": true, "events": [event]}

static func _fight_neutral(session: SessionStateStoreScript.SessionData, context: Dictionary, index: int, plan: Dictionary) -> Dictionary:
	var encounters: Array = session.overworld.get("encounters", [])
	var guard_index := int(plan.get("index", -1))
	if guard_index < 0 or guard_index >= encounters.size():
		return {"arrived": true}
	var guard: Dictionary = encounters[guard_index]
	if _is_resolved(session, String(guard.get("placement_id", ""))):
		return {"arrived": true}
	var fight := _auto_resolve(session, context, index, guard)
	var events: Array = fight.get("events", [])
	encounters = session.overworld.get("encounters", [])
	guard = encounters[guard_index]
	if bool(fight.get("won", false)):
		_mark_resolved(session, String(guard.get("placement_id", "")))
		context["topology_changed"] = true
	else:
		var army: Dictionary = _neutral_army(guard).duplicate(true)
		army["stacks"] = fight.get("enemy_survivors", army.get("stacks", []))
		guard["enemy_army"] = army
		encounters[guard_index] = guard
		session.overworld["encounters"] = encounters
		var hero_id := String(session.overworld.encounters[index].get("placement_id", ""))
		if not _is_resolved(session, hero_id):
			_step_back_from_guard(session, index, plan)
			_avoid_target(session, hero_id, String(guard.get("placement_id", "")), int(session.day) + 3)
	return {"arrived": true, "events": events}

## After a fight that left the guard standing, the hero falls back to the tile
## it attacked from instead of staying inside the guard's zone.
static func _step_back_from_guard(session: SessionStateStoreScript.SessionData, index: int, plan: Dictionary) -> void:
	if not (plan.get("retreat_tile", null) is Vector2i):
		return
	var tile: Vector2i = plan.retreat_tile
	var entry: Dictionary = session.overworld.encounters[index]
	if tile == Vector2i(int(entry.get("x", 0)), int(entry.get("y", 0))):
		return
	if _tile_blocked_for_standing(session, {}, tile, LevelRules.level_of(entry), String(entry.get("placement_id", ""))):
		return
	var before := LevelRules.position(entry)
	entry["x"] = tile.x
	entry["y"] = tile.y
	TurnPlayback.move(session, entry, before)
	_store_entry(session, index, entry)
	_overworld_rules().invalidate_spatial_lookup(session)

static func _fight_ai_hero(session: SessionStateStoreScript.SessionData, context: Dictionary, index: int, plan: Dictionary) -> Dictionary:
	var encounters: Array = session.overworld.get("encounters", [])
	var other_index := int(plan.get("index", -1))
	if other_index < 0 or other_index >= encounters.size():
		return {"arrived": true}
	var other: Dictionary = encounters[other_index]
	var fight := _auto_resolve(session, context, index, other)
	encounters = session.overworld.get("encounters", [])
	other = encounters[other_index]
	var other_controller := PlayerRules.raid_controller_id(other)
	if bool(fight.get("won", false)):
		_mark_resolved(session, String(other.get("placement_id", "")))
		_record_hero_defeat(session, other_controller, other)
	else:
		var army: Dictionary = other.get("enemy_army", {})
		army["stacks"] = fight.get("enemy_survivors", army.get("stacks", []))
		other["enemy_army"] = army
		encounters[other_index] = other
		session.overworld["encounters"] = encounters
	return {"arrived": true, "events": fight.get("events", [])}

## Hand troops to the main hero standing next to this one.
static func _meet_hero(session: SessionStateStoreScript.SessionData, context: Dictionary, index: int, plan: Dictionary) -> Dictionary:
	var other_index := _entry_index(session, String(plan.get("id", "")))
	if other_index < 0 or _is_resolved(session, String(plan.get("id", ""))):
		return {"arrived": true}
	var encounters: Array = session.overworld.get("encounters", [])
	var entry: Dictionary = encounters[index]
	var other: Dictionary = encounters[other_index]
	if not LevelRules.same_level(entry, other) or maxi(absi(int(entry.get("x", 0)) - int(other.get("x", 0))), absi(int(entry.get("y", 0)) - int(other.get("y", 0)))) > 1:
		return {"arrived": true}
	var army: Dictionary = entry.get("enemy_army", {}) if entry.get("enemy_army", {}) is Dictionary else {}
	var other_army: Dictionary = other.get("enemy_army", {}) if other.get("enemy_army", {}) is Dictionary else {}
	var split := _split_for_handover(army.get("stacks", []))
	var merged := _merge_stacks_into(other_army.get("stacks", []), split.give)
	if merged.stacks == other_army.get("stacks", []):
		return {"arrived": true}
	var kept: Array = split.keep
	kept.append_array(merged.left)
	army["stacks"] = kept
	entry["enemy_army"] = army
	entry["enemy_commander_state"] = AdventureRules.sync_commander_army_continuity(entry.get("enemy_commander_state", {}), army, AI_HERO_ENCOUNTER_ID)
	other_army["stacks"] = merged.stacks
	other["enemy_army"] = other_army
	other["enemy_commander_state"] = AdventureRules.sync_commander_army_continuity(other.get("enemy_commander_state", {}), other_army, AI_HERO_ENCOUNTER_ID)
	var block: Dictionary = entry.get(AI_HERO_KEY, {})
	block["goal"] = {}
	entry[AI_HERO_KEY] = block
	encounters[index] = entry
	encounters[other_index] = other
	session.overworld["encounters"] = encounters
	var event := _event(session, context, "ai_heroes_met", entry, {
		"target_kind": "encounter",
		"target_placement_id": String(other.get("placement_id", "")),
		"target_label": hero_name(other),
		"target_x": int(other.get("x", 0)),
		"target_y": int(other.get("y", 0)),
		"target_public_importance": "low",
	}, "%s hands troops to %s." % [hero_name(entry), hero_name(other)], ["troops_handed_over"])
	return {"arrived": true, "acted": true, "events": [event]}

static func _attack_town(session: SessionStateStoreScript.SessionData, context: Dictionary, index: int, plan: Dictionary) -> Dictionary:
	var controller := String(context.controller)
	var towns: Array = session.overworld.get("towns", [])
	var town_index := int(plan.get("index", -1))
	if town_index < 0 or town_index >= towns.size():
		return {"arrived": true}
	var town: Dictionary = towns[town_index]
	var owner := String(town.get("owner", "neutral"))
	if owner == "player":
		var force: Dictionary = HeroCommandRulesScript.town_defense_force(session, town)
		if int(force.get("troops", 0)) > 0:
			return _start_player_battle(session, context, index, {
				"type": "town_defense",
				"town_placement_id": String(town.get("placement_id", "")),
				"defending_hero_id": "",
				"raid_encounter_key": String(session.overworld.encounters[index].get("placement_id", "")),
				"trigger_faction_id": PlayerRules.faction_id(session, controller),
				"trigger_player_id": String(PlayerRules.player(session, controller).get("player_id", "")),
				"defender_owner": "player",
			}, "%s attacks %s." % [hero_name(session.overworld.encounters[index]), _turn_rules()._town_name(town)], town)
	var events := []
	var garrison: Array = town.get("garrison", []) if town.get("garrison", []) is Array else []
	if army_power(garrison) > 0.0:
		var fight := _auto_resolve(session, context, index, {
			"placement_id": "town_garrison:%s" % String(town.get("placement_id", "")),
			"encounter_id": AI_HERO_ENCOUNTER_ID,
			"enemy_army": {"id": "town_garrison", "name": "%s Garrison" % _turn_rules()._town_name(town), "stacks": garrison},
		})
		events.append_array(fight.get("events", []))
		towns = session.overworld.get("towns", [])
		town = towns[town_index]
		town["garrison"] = fight.get("enemy_survivors", []) if not bool(fight.get("won", false)) else []
		towns[town_index] = town
		session.overworld["towns"] = towns
		if not bool(fight.get("won", false)):
			return {"arrived": true, "events": events}
	var previous_owner := owner
	var transition: Dictionary = _overworld_rules().transition_town_control(session, String(town.get("placement_id", "")), "enemy", controller, "ai_hero_capture")
	if not bool(transition.get("ok", false)):
		return {"arrived": true, "events": events}
	context["topology_changed"] = true
	var entry: Dictionary = session.overworld.encounters[index]
	TurnPlayback.action(session, entry, "captures a town")
	events.append(_event(session, context, "ai_town_captured", entry, {
		"target_kind": "town",
		"target_placement_id": String(town.get("placement_id", "")),
		"target_label": _turn_rules()._town_name(town),
		"target_x": int(town.get("x", 0)),
		"target_y": int(town.get("y", 0)),
	}, "%s captures %s." % [hero_name(entry), _turn_rules()._town_name(town)], ["town_captured", "player_town" if previous_owner == "player" else "neutral_town"]))
	return {"arrived": true, "events": events}

static func _attack_player_hero(session: SessionStateStoreScript.SessionData, context: Dictionary, index: int, plan: Dictionary) -> Dictionary:
	var heroes: Array = session.overworld.get("player_heroes", [])
	var hero_index := int(plan.get("index", -1))
	if hero_index < 0 or hero_index >= heroes.size():
		return {"arrived": true}
	var hero: Dictionary = heroes[hero_index]
	var hero_id := String(hero.get("id", ""))
	if not bool(HeroCommandRulesScript.set_active_hero(session, hero_id).get("ok", false)):
		return {"arrived": true}
	var controller := String(context.controller)
	return _start_player_battle(session, context, index, {
		"type": "hero_intercept",
		"target_hero_id": hero_id,
		"trigger_faction_id": PlayerRules.faction_id(session, controller),
		"trigger_player_id": String(PlayerRules.player(session, controller).get("player_id", "")),
	}, "%s attacks %s." % [hero_name(session.overworld.encounters[index]), String(hero.get("name", "the hero"))], hero)

## Battles against the human are played by the human, exactly like any other
## battle against an enemy hero.
static func _start_player_battle(session: SessionStateStoreScript.SessionData, context: Dictionary, index: int, battle_context: Dictionary, summary: String, target: Dictionary) -> Dictionary:
	var entry: Dictionary = session.overworld.encounters[index]
	entry["battle_context"] = battle_context
	_store_entry(session, index, entry)
	var payload: Dictionary = _battle_rules().create_battle_payload(session, entry)
	if payload.is_empty():
		entry.erase("battle_context")
		_store_entry(session, index, entry)
		return {"arrived": true}
	session.battle = payload
	session.game_state = "battle"
	TurnPlayback.action(session, entry, "engages a defending army")
	var event := _event(session, context, "ai_town_defense_battle_queued" if String(battle_context.get("type", "")) == "town_defense" else "ai_hero_intercept_battle_queued", entry, {
		"target_kind": "town" if String(battle_context.get("type", "")) == "town_defense" else "hero",
		"target_placement_id": String(target.get("placement_id", target.get("id", ""))),
		"target_label": _turn_rules()._town_name(target) if String(battle_context.get("type", "")) == "town_defense" else String(target.get("name", "")),
		"target_x": int(entry.get("x", 0)),
		"target_y": int(entry.get("y", 0)),
		"target_public_importance": "critical",
	}, summary, ["battle_handoff"])
	return {"arrived": true, "battle_started": true, "messages": [summary], "events": [event]}

static func _record_hero_defeat(session: SessionStateStoreScript.SessionData, controller: String, entry: Dictionary) -> void:
	var commander: Dictionary = entry.get("enemy_commander_state", {})
	if commander.is_empty() or controller == "":
		return
	AdventureRules.sync_commander_state_to_roster(session, controller, AdventureRules.advance_commander_record(commander, AdventureRules.COMMANDER_OUTCOME_DEFEATED), AdventureRules.COMMANDER_STATUS_RECOVERING, "", int(session.day) + AdventureRules.COMMANDER_RECOVERY_DAYS_DEFEATED, AdventureRules.COMMANDER_OUTCOME_DEFEATED)

# --- Auto-resolved battles ----------------------------------------------------

## AI fights against neutrals (and other computer players) use the human's
## auto-resolve: a disposable session holding the hero as the attacking side
## and the defender as an ordinary encounter, resolved by BattleAutoResolveRules.
## Before walking into a fight the hero sizes it up with the same auto-resolve
## the fight will use, as a human weighs a battle before committing: it goes
## only when it wins and keeps at least half of its strength.
static func _fight_looks_good(session: SessionStateStoreScript.SessionData, context: Dictionary, entry: Dictionary, plan: Dictionary, idle: bool = false) -> bool:
	if String(plan.get("kind", "")) not in ["encounter", "ai_hero"]:
		return true
	var encounters: Array = session.overworld.get("encounters", [])
	var defender_index := int(plan.get("index", -1))
	if defender_index < 0 or defender_index >= encounters.size():
		return true
	# An overwhelming margin needs no second look.
	var power := hero_power(entry)
	if float(plan.get("fight_power", 0.0)) > 0.0 and power >= float(plan.fight_power) * CLEAR_WIN_RATIO:
		return true
	context["preview_count"] = int(context.get("preview_count", 0)) + 1
	var defender: Dictionary = encounters[defender_index]
	var battle_number := int(context.get("auto_battle_count", 0)) + 1
	var started := Time.get_ticks_usec()
	var outcome := _simulate_battle(session, context, entry, defender, battle_number)
	_profile_add(context, "preview_ms", started)
	# The fight that follows is this same battle; keep it for the hero to use.
	context["fight_preview"] = {"key": _battle_key(entry, defender, battle_number), "outcome": outcome}
	if not bool(outcome.get("won", false)):
		return false
	var army_before := army_power(entry.get("enemy_army", {}).get("stacks", []))
	var army_after := army_power(outcome.get("hero_survivors", []))
	if army_after < army_before * 0.5:
		return false
	# With nothing else worth doing, a clean win beats standing still: it pays
	# experience and opens the ground behind the guard.
	if idle and army_after >= army_before * IDLE_FIGHT_MIN_KEPT:
		return true
	# The battle shows what the fight really costs: take it only if what it wins
	# still outweighs the troops it loses.
	if plan.has("estimated_loss") and army_before > 0.0:
		var actual_loss := power * (1.0 - army_after / army_before) * TROOP_VALUE_PER_POWER
		return float(plan.get("value", 0.0)) + float(plan.estimated_loss) - actual_loss > 0.0
	return true

static func _battle_key(entry: Dictionary, defender: Dictionary, battle_number: int) -> String:
	return "%s|%s|%d|%d|%d" % [String(entry.get("placement_id", "")), String(defender.get("placement_id", "")), battle_number, hash(entry.get("enemy_army", {}).get("stacks", [])), hash(_neutral_army(defender).get("stacks", []) if PlayerRules.raid_controller_id(defender) == "" else defender.get("enemy_army", {}).get("stacks", []))]

## One auto-resolved battle on a scratch session: the hero attacks `defender`.
## Pure: the live session is not touched.
static func _simulate_battle(session: SessionStateStoreScript.SessionData, context: Dictionary, entry: Dictionary, defender: Dictionary, battle_number: int) -> Dictionary:
	var hero := _battle_hero(entry)
	var defender_copy := defender.duplicate(true)
	defender_copy["x"] = 0
	defender_copy["y"] = 0
	defender_copy["level"] = 0
	defender_copy.erase("battle_context")
	if defender_copy.has("enemy_army") and defender_copy.get("enemy_army", {}) is Dictionary:
		var stacks: Array = defender_copy.enemy_army.get("stacks", [])
		if stacks.is_empty():
			defender_copy.erase("enemy_army")
	elif PlayerRules.raid_controller_id(defender) == "":
		defender_copy["enemy_army"] = _neutral_army(defender)
	var scratch := SessionStateStoreScript.new_session_data(
		"ai_battle_%s_%d" % [String(entry.get("placement_id", "")), battle_number],
		"",
		String(hero.get("id", "")),
		int(session.day),
		{
			"map": [["grass"]],
			"map_size": {"x": 1, "y": 1},
			"player_heroes": [hero],
			"active_hero_id": String(hero.get("id", "")),
			"hero": hero,
			"army": hero.get("army", {}),
			"hero_position": {"x": 0, "y": 0},
			"movement": hero.get("movement", {}),
			"encounters": [defender_copy],
			"resolved_encounters": [],
			"towns": [],
			"resource_nodes": [],
			"artifact_nodes": [],
			"resources": {},
			"enemy_states": [],
		},
		AI_DIFFICULTY,
		SessionStateStoreScript.LAUNCH_MODE_SKIRMISH
	)
	var payload: Dictionary = _battle_rules().create_battle_payload(scratch, defender_copy)
	if payload.is_empty():
		return {"ok": false, "won": false}
	scratch.battle = payload
	scratch.game_state = "battle"
	var resolution: Dictionary = _auto_resolve_rules().resolve_active_battle(scratch)
	var final_state := String(resolution.get("state", ""))
	var won := final_state == "victory"
	var hero_after := {}
	for value in scratch.overworld.get("player_heroes", []):
		if value is Dictionary and String(value.get("id", "")) == String(hero.get("id", "")):
			hero_after = value
	var hero_survivors: Array = hero_after.get("army", {}).get("stacks", []) if not hero_after.is_empty() else []
	if not won and not scratch.battle.is_empty():
		# The fight ran out of orders without an outcome: both sides keep what
		# is still standing, as after a drawn battle.
		hero_survivors = _battle_rules()._battle_survivor_stacks(scratch, "player")
	var enemy_survivors: Array = []
	var scratch_defender: Dictionary = scratch.overworld.get("encounters", [defender_copy])[0] if not scratch.overworld.get("encounters", []).is_empty() else defender_copy
	if not won:
		if not scratch.battle.is_empty():
			enemy_survivors = _battle_rules()._battle_survivor_stacks(scratch, "enemy")
		else:
			enemy_survivors = scratch_defender.get("enemy_army", {}).get("stacks", defender_copy.get("enemy_army", {}).get("stacks", []))
	var gained := {}
	for key in LIVE_RESOURCE_KEYS:
		var amount := int(scratch.overworld.get("resources", {}).get(key, 0))
		if amount > 0:
			gained[key] = amount
	return {
		"ok": true,
		"won": won,
		"state": final_state,
		"hero_after": hero_after,
		"hero_survivors": hero_survivors,
		"lost": hero_after.is_empty() or army_power(hero_survivors) <= 0.0,
		"enemy_survivors": enemy_survivors,
		"resources_gained": gained,
	}

static func _auto_resolve(session: SessionStateStoreScript.SessionData, context: Dictionary, index: int, defender: Dictionary) -> Dictionary:
	context["auto_battle_count"] = int(context.get("auto_battle_count", 0)) + 1
	var entry: Dictionary = session.overworld.encounters[index]
	var preview: Dictionary = context.get("fight_preview", {})
	context.erase("fight_preview")
	var outcome: Dictionary = preview.get("outcome", {}) if String(preview.get("key", "")) == _battle_key(entry, defender, int(context.auto_battle_count)) else {}
	if outcome.is_empty():
		outcome = _simulate_battle(session, context, entry, defender, int(context.auto_battle_count))
	if not bool(outcome.get("ok", false)):
		return {"won": false, "ok": false}
	var final_state := String(outcome.get("state", ""))
	var won := bool(outcome.get("won", false))
	var hero_after: Dictionary = outcome.get("hero_after", {})
	var hero_survivors: Array = outcome.get("hero_survivors", [])
	var lost := bool(outcome.get("lost", false))
	var enemy_survivors: Array = outcome.get("enemy_survivors", [])
	var gained: Dictionary = outcome.get("resources_gained", {})
	_add_pool(context.state.treasury, gained)
	var events := []
	var label := _defender_label(defender)
	if not lost:
		entry = session.overworld.encounters[index]
		var army: Dictionary = entry.get("enemy_army", {})
		army["stacks"] = hero_survivors
		entry["enemy_army"] = army
		var commander: Dictionary = entry.get("enemy_commander_state", {})
		for key in ["level", "experience", "next_level_experience", "command", "spellbook", "artifacts", "specialties", "pending_specialty_choices"]:
			if hero_after.has(key):
				commander[key] = hero_after[key]
		if won:
			commander["battle_wins"] = int(commander.get("battle_wins", 0)) + 1
		commander = AdventureRules._normalize_enemy_progression(commander)
		entry["enemy_commander_state"] = AdventureRules.sync_commander_army_continuity(commander, army, AI_HERO_ENCOUNTER_ID)
		_store_entry(session, index, entry)
		if won:
			TurnPlayback.action(session, entry, "defeats %s" % label)
			events.append(_event(session, context, "ai_guard_defeated", entry, _defender_target(defender, label), "%s defeats %s." % [hero_name(entry), label], ["guard_cleared"]))
		else:
			TurnPlayback.action(session, entry, "breaks off against %s" % label)
			events.append(_event(session, context, "ai_guard_defeated", entry, _defender_target(defender, label), "%s fights %s to a standstill." % [hero_name(entry), label], ["guard_held"]))
	else:
		won = false
		entry = session.overworld.encounters[index]
		TurnPlayback.action(session, entry, "falls to %s" % label)
		_mark_resolved(session, String(entry.get("placement_id", "")))
		_record_hero_defeat(session, String(context.controller), entry)
		context["topology_changed"] = true
		events.append(_event(session, context, "ai_hero_defeated", entry, _defender_target(defender, label), "%s falls fighting %s." % [hero_name(entry), label], ["hero_defeated"]))
	return {"won": won, "ok": true, "state": final_state, "enemy_survivors": enemy_survivors, "events": events, "resources_gained": gained}

static func _defender_label(defender: Dictionary) -> String:
	if is_ai_hero(defender):
		return hero_name(defender)
	var army: Dictionary = defender.get("enemy_army", {}) if defender.get("enemy_army", {}) is Dictionary else {}
	if String(army.get("name", "")) != "":
		return String(army.get("name", ""))
	return String(_overworld_rules().encounter_display_name(defender))

static func _defender_target(defender: Dictionary, label: String) -> Dictionary:
	return {
		"target_kind": "encounter",
		"target_placement_id": String(defender.get("placement_id", "")),
		"target_label": label,
		"target_x": int(defender.get("x", 0)),
		"target_y": int(defender.get("y", 0)),
	}

## The hero as the human's battle code expects one: a hero record with army,
## movement and position.
static func _battle_hero(entry: Dictionary) -> Dictionary:
	var commander: Dictionary = entry.get("enemy_commander_state", {}).duplicate(true)
	var hero_id := String(commander.get("roster_hero_id", commander.get("id", "ai_hero")))
	var hero := commander
	hero["id"] = hero_id
	hero["army"] = {"id": "%s_army" % hero_id, "name": "Field Army", "stacks": entry.get("enemy_army", {}).get("stacks", []).duplicate(true)}
	hero["position"] = {"x": 0, "y": 0}
	hero["movement"] = entry.get(AI_HERO_KEY, {}).get("movement", {"current": 0, "max": 0}).duplicate(true)
	hero["is_primary"] = true
	if not hero.has("base_movement"):
		hero["base_movement"] = int(ContentService.get_hero(hero_id).get("base_movement", 10))
	return HeroProgressionRulesScript.ensure_hero_progression(SpellRulesScript.ensure_hero_spellbook(hero))

static func _neutral_army(encounter: Dictionary) -> Dictionary:
	var template := ContentService.get_encounter(String(encounter.get("encounter_id", encounter.get("id", ""))))
	return _battle_rules()._enemy_army_for_encounter(encounter, template)

# --- Strength -----------------------------------------------------------------

## Rough fighting value: per creature sqrt(hp * average damage), scaled by
## attack and defense, and by the leading hero's command.
static func army_power(stacks: Variant, commander: Variant = {}) -> float:
	var total := 0.0
	if not (stacks is Array):
		return total
	for stack in stacks:
		if not (stack is Dictionary):
			continue
		var count := int(stack.get("count", 0))
		if count <= 0:
			continue
		var unit := ContentService.get_unit(String(stack.get("unit_id", "")))
		if unit.is_empty():
			continue
		var damage := (float(unit.get("min_damage", 1)) + float(unit.get("max_damage", 1))) * 0.5
		var per := sqrt(maxf(1.0, float(unit.get("hp", 1))) * maxf(0.5, damage))
		per *= 1.0 + 0.03 * float(int(unit.get("attack", 0)) + int(unit.get("defense", 0)))
		if bool(unit.get("ranged", false)):
			per *= 1.15
		total += per * float(count)
	if commander is Dictionary and not commander.is_empty():
		var command: Dictionary = commander.get("command", {}) if commander.get("command", {}) is Dictionary else {}
		total *= 1.0 + 0.05 * float(int(command.get("attack", 0)) + int(command.get("defense", 0)))
	return total

static func hero_power(entry: Dictionary) -> float:
	return army_power(entry.get("enemy_army", {}).get("stacks", []) if entry.get("enemy_army", {}) is Dictionary else [], entry.get("enemy_commander_state", {}))

# --- Helpers ------------------------------------------------------------------

static func _resource_needs(session: SessionStateStoreScript.SessionData, context: Dictionary) -> Dictionary:
	if context.has("needs"):
		return context.needs
	var needs := {}
	var treasury: Dictionary = context.state.treasury
	var overworld_rules = _overworld_rules()
	for entry in _turn_rules()._owned_town_entries(session, String(context.controller)):
		var town: Dictionary = entry.get("town", {})
		for building_id in overworld_rules.get_town_build_options(town, int(session.day)):
			var status: Dictionary = overworld_rules.get_town_build_status(town, String(building_id))
			if not bool(status.get("buildable", false)):
				continue
			for key in status.get("building", {}).get("cost", {}).keys():
				if int(status.building.cost[key]) > int(treasury.get(key, 0)):
					needs[String(key)] = true
	context["needs"] = needs
	return needs

static func _payload_value(payload: Variant, needs: Dictionary) -> float:
	var value := 0.0
	if not (payload is Dictionary):
		return value
	for key in payload.keys():
		var amount := float(payload[key]) if (payload[key] is int or payload[key] is float) else 0.0
		var unit := float(RESOURCE_VALUES.get(String(key), 0.0))
		if needs.has(String(key)) and String(key) != "experience":
			unit *= SHORT_RESOURCE_MULTIPLIER
		value += amount * unit
	return value

static func _merge_stacks_into(destination: Variant, additions: Variant) -> Dictionary:
	var stacks: Array = destination.duplicate(true) if destination is Array else []
	var left := []
	if not (additions is Array):
		return {"stacks": stacks, "left": left}
	for stack in additions:
		if not (stack is Dictionary) or int(stack.get("count", 0)) <= 0:
			continue
		var plan := HeroCommandRulesScript.army_addition_plan(stacks, {String(stack.get("unit_id", "")): int(stack.get("count", 0))})
		if bool(plan.get("ok", false)):
			stacks = plan.get("stacks", stacks)
		else:
			left.append(stack.duplicate(true))
	return {"stacks": stacks, "left": left}

static func _find_town(session: SessionStateStoreScript.SessionData, placement_id: String) -> Dictionary:
	var towns: Array = session.overworld.get("towns", [])
	for index in range(towns.size()):
		if towns[index] is Dictionary and String(towns[index].get("placement_id", "")) == placement_id:
			return {"index": index, "town": towns[index]}
	return {"index": -1, "town": {}}

static func _can_afford(pool: Dictionary, cost: Dictionary) -> bool:
	for key in cost.keys():
		if int(pool.get(key, 0)) < int(cost[key]):
			return false
	return true

static func _add_pool(pool: Dictionary, delta: Variant) -> void:
	if not (delta is Dictionary):
		return
	for key in delta.keys():
		if String(key) in LIVE_RESOURCE_KEYS:
			pool[key] = int(pool.get(key, 0)) + int(delta[key])

static func _append_all(target: Array, values: Variant) -> void:
	if values is Array:
		for value in values:
			if value is Dictionary and value.is_empty():
				continue
			if value is String and value == "":
				continue
			target.append(value)

static func _elapsed_ms(started: int) -> int:
	return int(round(float(Time.get_ticks_usec() - started) / 1000.0))

static func _event(session: SessionStateStoreScript.SessionData, context: Dictionary, event_type: String, actor: Dictionary, target: Dictionary, summary: String, reason_codes: Array) -> Dictionary:
	var target_with_reasons := target.duplicate(true)
	target_with_reasons["target_reason_codes"] = reason_codes
	return AdventureRules.build_ai_event_record(session, context.config, event_type, actor, target_with_reasons, {
		"summary": summary,
		"actor_label": hero_name(actor),
		"state_policy": "durable_state_reference",
		"public_importance": String(target.get("target_public_importance", "medium")),
	})
