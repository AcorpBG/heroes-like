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
const BattleDamage = preload("res://scripts/core/BattleDamageRules.gd")
const WaterTravel = preload("res://scripts/core/WaterTravelRules.gd")

const AI_HERO_KEY := "ai_hero"
# Battle settings (terrain, length, rewards) for fights against an AI hero. The
# template's army and commander are never used: the hero brings its own.
const AI_HERO_ENCOUNTER_ID := "encounter_mire_raid"
## A match that sets this flag keeps every auto-resolved fight in
## `session.flags[BATTLE_LOG_KEY]` (see `_log_battle`) and every town capture
## in `session.flags[CAPTURE_LOG_KEY]`.
const BATTLE_LOG_FLAG := "ai_battle_log_enabled"
## With the battle log on, running totals per computer player of where gold
## and troops go (`_economy_add`): strength and gold of recruits, strength
## dismissed for room, gold on buildings, hires and town services.
const ECONOMY_LOG_KEY := "ai_economy_log"
## With the battle log on, every hero decision of the day (`_log_decision`):
## where the hero stood, its strength, the plan it took and the best
## alternatives it scored, so a match can be read without replaying it.
const DECISION_LOG_KEY := "ai_decision_log"
const DECISION_LOG_ALTERNATIVES := 3
const BATTLE_LOG_KEY := "ai_battle_log"
const BATTLE_LOG_OWNER_KEY := "battle_log_owner"
const CAPTURE_LOG_KEY := "ai_capture_log"
const AI_DIFFICULTY := "normal"
const MAX_DECISIONS_PER_DAY := 6
const SEARCH_DAYS := 3
const FAR_SEARCH_DAYS := 7
## Main and field armies also look this many days of movement out for what
## decides the game (`_strategic_candidate`): rival and neutral towns, hostile
## heroes and the guards in the way to a known town. On large maps the leading
## player's armies only ever looked three days out, found a mine or a pile of
## resources there every day, and never went for the rival towns in the far
## corners, each worth a hundred mines; four of ten large-map games ran to the
## day cap that way.
const STRATEGIC_DAYS := 12
const MIN_SEARCH_RADIUS := 14
## A hero weighs what lies past this many of the nearest subterranean gates it
## can walk to (`_gate_candidate`); each costs a search of the other level.
const MAX_GATES_WEIGHED := 3
## Main and field armies also route through any number of gates to a town they
## can take, or to ground not yet seen while a rival's towns are unseen
## (`_gate_routes`). The way between two gates of one stretch of ground counts
## its straight distance times ROUTE_DETOUR; a stretch counts as unexplored
## from ROUTE_UNEXPLORED_MIN unseen tiles.
const ROUTE_DETOUR := 1.5
const ROUTE_UNEXPLORED_MIN := 12
## A stretch a main or field army stood on within ROUTE_REVISIT_DAYS is no
## errand for scouting through a gate (`ROUTE_VISITS_KEY` in its block): what
## it could not see there lay behind guards it weighs where it stands. Without
## this, armies whose stretches on either side of a gate both kept ground
## behind guards unseen went back and forth through that gate for 25 days.
const ROUTE_REVISIT_DAYS := 14
const ROUTE_VISITS_KEY := "route_visits"
## Set on the copy of a hero weighed as if it stood elsewhere (`_beyond_gate`,
## `_gate_home`).
const TRAVELLER_KEY := "ai_traveller"
## Boarding a boat or stepping ashore ends the hero's day, as for the human; a
## route through either counts this share of a day's movement on top of the
## step. Building the boat at a shipyard counts one more day (its price).
const SHORE_STEP_SHARE := 0.5
## The day a main or field army last found nothing to do with a shipyard in
## reach and no means to pay for a boat: for BOAT_SAVING_DAYS after it the
## player's towns keep the boat's price back (`_govern_towns`).
const BOAT_WANTED_KEY := "ai_boat_wanted_day"
const BOAT_SAVING_DAYS := 2
const BOUGHT_BOAT := 4
## A guard is considered (and previewed) from this strength margin. With the
## strength estimate refitted 2026-10-16, guards fought at 1.3 to 1.5x lose
## about 93% of battles in the battle AI arena, and none from 2x.
const GUARD_WIN_RATIO := 1.3
const HERO_ATTACK_RATIO := 1.3
const TOWN_ATTACK_RATIO := 1.4
const THREAT_RATIO := 1.15
## A town is worth this much plus TOWN_HORIZON_WEEKS of its income and troop
## growth (`_town_worth`); a faction that has lost every town values one twice
## as much. Towns are the most valuable thing on the map: they pay and muster
## every week for the rest of the game. Until 2026-10-09 a town was worth 4,000
## plus two weeks, little more than a good mine, and on a medium map neutral
## towns with 24 defenders stood untaken for 40 to 70 days.
const TOWN_BASE_VALUE := 10000.0
const TOWN_HORIZON_WEEKS := 4.0
## Knocking a rival out of the game is worth this much, shared among what it
## still holds: its towns, or its heroes once it has no town left. A player's
## last town is worth this much more; when it holds two, each is worth half.
## On a medium map a beaten player kept its last town 40 days against an army
## twenty times its own while the winner cleared guards and mines.
const ELIMINATION_VALUE := 20000.0
## Lesser heroes that keep an army of their own (`_field_hero_ids`): one per
## town held beyond the first, at most this many. They take garrisons along,
## defend towns and take what they can beat instead of handing their troops to
## the main hero; captured towns of other factions muster creatures the main
## army has no slot for.
const FIELD_ARMY_MAX := 3
## Leaving a defender (`_leave_defense`). A hero leaving one of its towns keeps
## enough troops there to stop the hostile heroes that could reach it within
## DEFENSE_HORIZON_DAYS (they need TOWN_ATTACK_RATIO over the garrison), or,
## with none in sight but a rival town near, the raider a rival musters by this
## week (DEFENSE_BASELINE_PER_WEEK a week). Every town is also held against
## the strongest remembered hero of a rival that holds no town, however far
## (`_townless_raider`): such a rival musters nothing and is out after
## PlayerEliminationRules.TOWNLESS_DAYS unless it takes a town back. It does so
## only while the troops left cost no more than the town is worth and at most
## DEFENSE_SHARE_MAX of its army (DEFENSE_SHARE_MAX_MAIN for the main hero);
## otherwise taking the whole garrison is the better trade. Until 2026-10-09
## heroes always took the whole garrison of a town not under threat: in
## four-player medium games 41 of 76 captures met an empty town, small heroes
## walking in behind the armies, and a player with 5 towns and 14,000 strength
## could not finish two players holding one town each in 160 days. Until
## 2026-10-20 a townless rival counted only when seen near: on a large
## two-level map (seed ai-match-4265064792) the last rival's heroes of about
## 1,000 strength took the leader's towns 15 times from day 247, 11 of them
## empty, and kept it in the game until day 276.
const DEFENSE_HORIZON_DAYS := 2
const DEFENSE_MARGIN := 1.15
const DEFENSE_BASELINE_PER_WEEK := 40.0
const DEFENSE_SHARE_MAX := 0.5
const DEFENSE_SHARE_MAX_MAIN := 0.3
## What a field army joining the main army is worth on top of the troops,
## when the main army alone cannot beat a hostile hero or town (`_main_shortfall`).
const JOIN_BASE_VALUE := 3000.0
## A field army keeps at most this share of the main army's strength; above
## it, it goes and joins the main army, which takes the stronger stacks. One
## army wins the war; field armies hold ground behind it. On large maps every
## player's strength sat in three or four armies of 5,000 to 30,000, none of
## them able to clear the strong guards on the way to a rival, and the last
## three of eight players never attacked each other in the final 40 days.
const FIELD_SHARE_MAX := 0.35
## The main hero remembers the strength it lacked to clear the guard standing
## first in its way to a known rival town (`_strategic_candidate`), so field
## armies come to join it (`_main_shortfall`).
const BLOCKED_NEED_KEY := "blocked_need"
## A defending hero whose single strongest spell would take this share of the
## attacker's health is never attacked unseen: the fight is previewed.
const SPELL_BURST_PREVIEW_SHARE := 0.25
const HOMELESS_TOWN_MULTIPLIER := 2.0
## Killing a hero that threatens one of our towns is worth this share of the town.
const THREAT_KILL_SHARE := 0.5
## A visible hostile hero this many times a hero's strength is a danger to it:
## the hero keeps out of its reach (`_dangers`).
const DANGER_RATIO := 1.15
## army_power's terms (see there). Fitted 2026-10-16 on 4,800 realistic battles
## of the battle AI arena (tools/battle_ai_arena), both sides played by the
## battle AI, and checked on 2,400 others: the estimate calls the winner of
## 90% of them, against 88% with only shooters reweighed and 87% before. Most
## misses are near-even battles; replayed with other dice, 3% of battles change
## winner anyway. Creature attack and the unit abilities added nothing.
## One creature: POWER_SCALE x health^POWER_HEALTH x damage^POWER_DAMAGE, and
## per point of defense, speed and initiative a POWER_PER_* share more; the
## scale keeps the average creature at its value before the fit.
const POWER_SCALE := 0.7
const POWER_HEALTH := 0.3
const POWER_DAMAGE := 0.6
const POWER_PER_DEFENSE := 0.075
const POWER_PER_SPEED := 0.06
const POWER_PER_INITIATIVE := 0.045
## A shooter over a melee creature of the same stats: it shoots freely while
## melee closes in.
const RANGED_POWER := 1.65
## The hero's attack and defense (the battle's own damage curve) and its
## damage spells raise the army by these powers of what they add.
const HERO_COMMAND_POWER := 0.85
const HERO_SPELL_POWER := 0.95
## The most of its strength a main hero leaves behind to guard a town.
const GUARD_SHARE_MAX := 0.25
## The main hero holds at least this share of the strongest hero's army.
const MAIN_ARMY_SHARE := 0.5
## Rounds a battle lasts for the strength estimate of a hero's spells.
const BATTLE_ROUNDS_ESTIMATE := 4
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
## The small loss grows with the guard's share of the hero's strength, as it
## did at the 2026-10-08 calibration's 0.35. It was a fixed 1.2% of the army,
## more than a weak guard pays a strong hero, so strong heroes walked past weak
## guards: in 1,025 arena guard fights (2026-10-16) the winner lost 0.05% of
## its army against guards under 3% of its strength, 0.4% at 5-8%, 0.7% at
## 8-12%, 2.3% at 17-25% and 4.6% at 25-35%.
const LOSS_ESTIMATE_PER_RATIO := 0.035
## Guards up to this share of the hero's strength within its reach today are
## previewed for a free fight (`_free_fight`): of the arena's fights against
## them, 63% to 84% cost the winner no creature.
const FREE_FIGHT_MAX_RATIO := 0.25
## Free-fight previews a hero runs in one decision.
const MAX_FREE_FIGHT_PREVIEWS := 2
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
## Scouting the nearest unexplored ground. Raised from 220 on 2026-10-18 at
## the owner's request that computer players explore more.
const EXPLORE_VALUE := 500.0
## While a rival still holds a town this player has never seen, the unexplored
## frontier is worth up to this much more, rising from HUNT_START_DAY to
## HUNT_FULL_DAY: early on heroes expand, later they go and find the enemy.
## It equals ELIMINATION_VALUE: at 6,000 a 66,000-strength main hero on a large
## map preferred fetching troops from its own towns to scouting the 5% of the
## map where the last rival held out. Heroes only target towns they have seen;
## in a four-player medium game the
## leading player (32,000 strength) never scouted the corners where its two
## rivals held one weakly guarded town each, and the game ran to its day cap.
const HUNT_EXPLORE_VALUE := 20000.0
const HUNT_START_DAY := 21
const HUNT_FULL_DAY := 56
## Every hostile hero a player has seen in the last SIGHTING_MEMORY_DAYS, with
## its strength then (SIGHTINGS_KEY in its state), as a human remembers the
## armies it has met. Once the player has found a rival's town and its main
## army holds more than HERO_ATTACK_RATIO times all it knows of any one rival,
## remembered heroes and seen garrisons together (`_far_ahead`), finding a
## rival's unseen towns is worth what one of its own towns is worth
## (`_hunt_value`) instead of HUNT_EXPLORE_VALUE. On a large two-level map
## (seed ai-match-3844121282) the leader's 150,000-strength main army retook
## the towns its rival's 5,000- to 17,000-strength raiders kept taking, each
## worth about 275,000 to it against 20,500 for scouting, and never saw the
## rival's other four towns: 203 captures from day 200 to the 320-day cap, 111
## of them of empty towns.
const SIGHTINGS_KEY := "ai_sightings"
const SIGHTING_MEMORY_DAYS := 28
## Ground behind a guard that the hero cannot reach today: a base value for
## opening the way, plus each unexplored tile there, up to a cap (sites the
## player has already seen there count on top, at half their value).
const PASSAGE_BASE_VALUE := 300.0
const PASSAGE_UNEXPLORED_TILE_VALUE := 8.0
const PASSAGE_KNOWN_SITE_SHARE := 0.5
const PASSAGE_VALUE_CAP := 5000.0
## Unexplored ground behind a guard while a rival's towns are still unseen is
## worth up to this share of ELIMINATION_VALUE, in full from this many
## unexplored tiles. On a medium map the leading player's heroes, 5,000 to
## 16,000 strong, stayed on their half for 60 days chasing mines while the last
## rival's two towns lay unseen behind a guard: the 5,000 a passage could be
## worth never paid for the troops the fight would cost.
const HIDDEN_RIVAL_SHARE := 0.5
const HIDDEN_RIVAL_TILES := 200
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
## A spell a hero learns from a site, for that one hero: below a loose
## artifact (1,100) even at tier 4, against 400 + 300 a tier that a mage guild
## level teaching every hero is worth to the town planner.
const SCROLL_SPELL_BASE_VALUE := 150.0
const SCROLL_SPELL_TIER_VALUE := 150.0
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
		# is_ai_hero, inline: this runs for every encounter many times a turn.
		if not (entry is Dictionary) or not (entry.get(AI_HERO_KEY, null) is Dictionary) or resolved.has(String(entry.get("placement_id", ""))):
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

## Shared and read-only: a caller that adds to it copies it first.
static func _resolved_lookup(session: SessionStateStoreScript.SessionData) -> Dictionary:
	return _overworld_rules().resolved_encounter_lookup(session)

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
	# A copy: heroes this pass resolves are added to it.
	var resolved := _resolved_lookup(session).duplicate()
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
	# A hero defeated aboard a boat leaves it empty where it lay.
	WaterTravel.normalize(session)
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
	_note_sightings(session, context)
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
	# What the heroes see where they ended the day.
	_note_sightings(session, context)
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
	_guard_index = {}

## Whether a guard still blocks a site, as the human's claim check decides it.
## Remembered for the enemy turn until another army is beaten.
static var _guard_cache: Dictionary = {}

static func _resource_guarded(session: SessionStateStoreScript.SessionData, node: Dictionary, site: Dictionary) -> bool:
	var key := "%d|%s" % [session.overworld.get("resolved_encounters", []).size(), String(node.get("placement_id", ""))]
	if not _guard_cache.has(key):
		var index := _encounter_guard_index(session)
		var positions := _guard_positions([
			index.by_placement.get(String(node.get("guard_front_id", "")), []),
			index.by_site_target.get(String(node.get("placement_id", "")), []),
			index.by_site_target.get(String(site.get("id", node.get("site_id", ""))), []),
		])
		_guard_cache[key] = not _overworld_rules().resource_site_blocking_guard(session, node, site, positions).is_empty()
	return bool(_guard_cache[key])

## The guard that keeps a hero from an artifact, as the human's pickup check
## finds it.
static func _artifact_guard(session: SessionStateStoreScript.SessionData, node: Dictionary) -> Dictionary:
	var index := _encounter_guard_index(session)
	var positions := _guard_positions([
		index.by_artifact_target.get(String(node.get("placement_id", "")), []),
		index.by_artifact_target.get(String(node.get("artifact_id", "")), []),
	])
	return AdventureRules._artifact_guard_encounter_for_node(session, node, positions)

## The encounters that may guard a site or an artifact, by every value the
## guard checks match a target on: their placement id (a site's guard_front_id),
## the target placement and target id of their guard link as the site check
## reads it (OverworldRules._resource_site_guard_link_for_encounter), and for
## artifacts the target placement and target id of their guard link as the
## artifact check reads it (EnemyAdventureRules._guard_link_for_encounter) and
## the object they guard. Lists hold encounter positions in list order; the
## checks run on those encounters only, resolved or not as they are then. The
## enemy turn changes none of these fields in place, so the index holds while
## the encounter list is the same array of the same size.
static var _guard_index: Dictionary = {}

static func _encounter_guard_index(session: SessionStateStoreScript.SessionData) -> Dictionary:
	var encounters: Array = session.overworld.get("encounters", [])
	if not _guard_index.is_empty() and is_same(_guard_index.encounters, encounters) and int(_guard_index.size) == encounters.size():
		return _guard_index
	var overworld_rules = _overworld_rules()
	var by_placement := {}
	var by_site_target := {}
	var by_artifact_target := {}
	for position in range(encounters.size()):
		var encounter = encounters[position]
		if not (encounter is Dictionary):
			continue
		_add_guard_position(by_placement, String(encounter.get("placement_id", "")), position)
		var site_link: Dictionary = overworld_rules._resource_site_guard_link_for_encounter(encounter)
		if not site_link.is_empty():
			_add_guard_position(by_site_target, String(site_link.get("target_placement_id", "")), position)
			_add_guard_position(by_site_target, String(site_link.get("target_id", "")), position)
		var artifact_link: Dictionary = AdventureRules._guard_link_for_encounter(encounter)
		if not artifact_link.is_empty():
			_add_guard_position(by_artifact_target, String(artifact_link.get("target_placement_id", "")), position)
			_add_guard_position(by_artifact_target, String(artifact_link.get("target_id", "")), position)
		_add_guard_position(by_artifact_target, String(encounter.get("guarded_object_placement_id", "")), position)
	_guard_index = {
		"encounters": encounters,
		"size": encounters.size(),
		"by_placement": by_placement,
		"by_site_target": by_site_target,
		"by_artifact_target": by_artifact_target,
	}
	return _guard_index

static func _add_guard_position(lookup: Dictionary, key: String, position: int) -> void:
	if key == "":
		return
	if not lookup.has(key):
		lookup[key] = [position]
	elif int(lookup[key].back()) != position:
		lookup[key].append(position)

## The positions of several index lists, ascending, each once.
static func _guard_positions(lists: Array) -> Array:
	var positions := []
	for list in lists:
		positions.append_array(list)
	if positions.size() < 2:
		return positions
	positions.sort()
	var unique := [positions[0]]
	for position in positions:
		if int(position) != int(unique.back()):
			unique.append(position)
	return unique

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
	var army_id := String(load("res://scripts/persistence/NativeRandomMapPackageSessionBridge.gd").GENERATED_START_ARMY_BY_FACTION.get(faction_id, ""))
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
	# An army stuck on its island saves for a boat before the towns spend.
	var held := {}
	if int(context.state.get(BOAT_WANTED_KEY, -1000)) >= int(session.day) - BOAT_SAVING_DAYS:
		held = _hold_back(context.state.treasury, _level_surface(session, context, 0).get("boat_cost", {}))
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
	_add_pool(context.state.treasury, held)
	return {"messages": messages, "events": events}

## Takes up to `amounts` out of the treasury and returns what it took.
static func _hold_back(treasury: Dictionary, amounts: Dictionary) -> Dictionary:
	var held := {}
	for key in amounts.keys():
		var take := mini(int(treasury.get(key, 0)), int(amounts[key]))
		if take > 0:
			treasury[key] = int(treasury.get(key, 0)) - take
			held[key] = take
	return held

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

## The building this town builds today: what it adds over BUILD_HORIZON_WEEKS
## per its price. `values`, when given, gets each option's value by id.
static func _build_choice(session: SessionStateStoreScript.SessionData, town: Dictionary, treasury: Dictionary, values: Dictionary = {}) -> Dictionary:
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
	var market_memo := {}
	for building_id_value in options:
		var listed: Dictionary = ContentService.get_building(String(building_id_value)).get("cost", {})
		for key in listed.keys():
			if int(listed[key]) > int(treasury.get(key, 0)):
				short[String(key)] = true
	for building_id_value in options:
		var building_id := String(building_id_value)
		# Buildable today, so buildable on any day too; the town is not changed
		# here, so its status would only hand back the building record.
		var building := ContentService.get_building(building_id)
		var cost: Dictionary = building.get("cost", {})
		if not _market_cover(session, town, treasury, cost, false, market_memo):
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
		var income := _build_value(_pool_delta(_trial_income(trial), income_before)) * 7.0 * BUILD_HORIZON_WEEKS
		if income > value:
			reason = "income"
		value += income
		# A town on the current development rules musters only the upgraded
		# creature once the upgrade stands, so the troops above already hold what
		# the upgrade adds. Until 2026-10-17 it was added a second time here, and
		# factions whose upgrades add much (Mireclaw, Thornwake, Veilmourn)
		# upgraded their first dwelling before opening a second: in week 2 they
		# mustered one creature line where the others mustered two.
		if String(building.get("upgrade_from", "")) != "" and String(building.get("unlock_unit_id", "")) != "":
			if not _turn_rules().TownDevelopment.is_current(town):
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
		var cost_value := maxf(1.0, _build_value(cost))
		var score := value / cost_value
		values[building_id] = value
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
	var value := _build_value(storehouse) * 7.0 * BUILD_HORIZON_WEEKS
	if not short.is_empty():
		value *= SHORT_RESOURCE_MULTIPLIER
	return value

## What a building's cost or income is worth to the town planner: gold at face
## value, every other resource at what the market charges for it
## (`OverworldRules.MARKET_RESOURCE_VALUES`). Gold buys wood and ore only a few
## a week, so a planner that priced them low spent its ore on gold income and
## then sat on gold it could not build with.
static func _build_value(payload: Dictionary) -> float:
	var market_values: Dictionary = _overworld_rules().MARKET_RESOURCE_VALUES
	var value := 0.0
	for key in payload.keys():
		var amount := float(payload[key]) if (payload[key] is int or payload[key] is float) else 0.0
		value += amount * (1.0 if String(key) == "gold" else float(market_values.get(String(key), 0.0)))
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
## town's usage. Checks that ask about one town in a row, with nothing built in
## between, can share a `market_memo` dictionary that keeps its market state.
static func _market_cover(session: SessionStateStoreScript.SessionData, town: Dictionary, pool: Dictionary, cost: Dictionary, apply: bool, market_memo: Variant = null) -> bool:
	if _can_afford(pool, cost):
		return true
	var overworld_rules = _overworld_rules()
	var town_rules = _town_rules()
	var market: Dictionary = market_memo.get("market", {}) if market_memo is Dictionary else {}
	if market.is_empty():
		market = overworld_rules.town_market_state(town)
		if market_memo is Dictionary:
			market_memo["market"] = market
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
				var terms: Dictionary = town_rules.market_trade_quote(market, usage, {other: spare}, other, key, 1, false)
				var count := mini(deficit, int(terms.get("max_amount", 0)))
				if count > 0 and _market_trade(town_rules.market_trade_quote(market, usage, {other: spare}, other, key, count, false), stock, usage):
					deficit -= count
		if deficit > 0 and key in tradable:
			var spare_gold := maxi(0, int(stock.get("gold", 0)) - int(cost.get("gold", 0)))
			if not _market_trade(town_rules.market_trade_quote(market, usage, {"gold": spare_gold}, "gold", key, deficit, false), stock, usage):
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
		var terms: Dictionary = town_rules.market_trade_quote(market, usage, {other: spare}, other, "gold", 1, false)
		var count := 0
		# Every amount up to max_amount is a sale the quote allows, for the gold
		# market_sale_gold names.
		for amount in range(1, int(terms.get("max_amount", 0)) + 1):
			count = amount
			if town_rules.market_sale_gold(market, other, amount) >= gold_deficit:
				break
		if count <= 0:
			continue
		var sale: Dictionary = town_rules.market_trade_quote(market, usage, {other: spare}, other, "gold", count, false)
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
	var market_memo := {}
	while low < high:
		var middle := (low + high + 1) / 2
		if _market_cover(session, town, pool, _turn_rules()._scale_resource_pool(unit_cost, middle), false, market_memo):
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
	_economy_add(session, String(context.controller), "build_gold", float(cost.get("gold", 0)))
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
	_economy_add(session, String(context.controller), "hire_gold", float(cost.get("gold", 0)))
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
	# Level-up rolls come from the hero's growth seed: seed it from the session,
	# as the human's hires are, so the same game plays out the same way.
	var growth_seed := HeroCommandRulesScript.new_growth_seed("%s|%s|%d" % [controller, hero_id, int(session.day)], session)
	var hero := {}
	if not start_stacks.is_empty():
		hero = HeroCommandRulesScript.build_recruited_hero(template, position, AI_DIFFICULTY, 1, {"id": "%s_army" % hero_id, "name": "Field Army", "stacks": start_stacks}, "", growth_seed)
	else:
		var offer := HeroCommandRulesScript.tavern_offer(session, hero_id)
		hero = HeroCommandRulesScript.build_recruited_hero(template, position, AI_DIFFICULTY, int(offer.get("level", 1)), offer.get("army", {}), "", growth_seed)
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

## The encounter index of a hostile computer player's hero standing in the
## town's doorway, which defends the town; -1 when there is none.
static func _town_hero_defender_index(session: SessionStateStoreScript.SessionData, town: Dictionary, controller: String) -> int:
	var entrance := LevelRules.town_entrance(town)
	var resolved := _resolved_lookup(session)
	var encounters: Array = session.overworld.get("encounters", [])
	for index in range(encounters.size()):
		var entry = encounters[index]
		if not (entry is Dictionary) or not is_ai_hero(entry) or resolved.has(String(entry.get("placement_id", ""))):
			continue
		var other := PlayerRules.raid_controller_id(entry)
		if other == controller or PlayerRules.allied(session, controller, other):
			continue
		if LevelRules.same_level(entry, entrance) and int(entry.get("x", -1)) == int(entrance.get("x", -2)) and int(entry.get("y", -1)) == int(entrance.get("y", -2)):
			return index
	return -1

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
	var events := []
	for entry in _turn_rules()._owned_town_entries(session, String(context.controller)):
		events.append_array(_recruit_town(session, context, int(entry.get("index", -1)), reserve))
	return {"events": events, "messages": []}

## Buys what one owned town offers into its garrison, strongest tier first,
## with the treasury the faction holds and the market's help.
static func _recruit_town(session: SessionStateStoreScript.SessionData, context: Dictionary, index: int, reserve: Dictionary) -> Array:
	var turn_rules = _turn_rules()
	var treasury: Dictionary = context.state.treasury
	var events := []
	var towns: Array = session.overworld.get("towns", [])
	if index >= 0 and index < towns.size():
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
				plan = _make_room(town.get("garrison", []), unit_id, count)
			if not bool(plan.get("ok", false)):
				continue
			var total: Dictionary = turn_rules._scale_resource_pool(cost, count)
			_market_cover(session, town, treasury, total, true)
			turn_rules._spend_from_pool(treasury, total)
			_economy_add(session, String(context.controller), "recruited_power", army_power([{"unit_id": unit_id, "count": count}]))
			_economy_add(session, String(context.controller), "recruit_gold", float(total.get("gold", 0)))
			_economy_add(session, String(context.controller), "dismissed_power", float(plan.get("dismissed_power", 0.0)))
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
	return events

## A full garrison dismisses its weakest stack, as a human dismisses one from a
## full army, when the creatures it would buy are stronger than that stack.
## Without it a garrison holding seven odd stacks (strays of other factions,
## two or three creatures left behind by heroes) bought nothing more: in a
## four-player match a captured town kept the same seven stacks for four weeks
## while its growth piled up unbought and the treasury reached 900,000 gold.
static func _make_room(garrison: Array, unit_id: String, count: int) -> Dictionary:
	var stacks := garrison.duplicate(true)
	var weakest := -1
	var weakest_power := INF
	for index in range(stacks.size()):
		var stack_power := army_power([stacks[index]])
		if stack_power < weakest_power:
			weakest = index
			weakest_power = stack_power
	if weakest < 0 or weakest_power >= army_power([{"unit_id": unit_id, "count": count}]):
		return {"ok": false}
	stacks.remove_at(weakest)
	var plan := HeroCommandRulesScript.army_addition_plan(stacks, {unit_id: count})
	plan["dismissed_power"] = weakest_power
	return plan

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
	var is_field := _field_hero_ids(session, String(context.controller)).has(String(entry.get("placement_id", "")))
	if fresh_hire:
		if army_power(stacks) <= 0.0 and not garrison.is_empty():
			var weakest := _weakest_stack_index(garrison)
			var moved := _merge_stacks_into(stacks, [garrison[weakest]])
			stacks = moved.get("stacks", stacks)
			if moved.get("left", []).is_empty():
				garrison.remove_at(weakest)
	elif is_main or is_field or _ferries_from(session, context, live_town, main_id):
		if not garrison.is_empty() and not _town_threatened(session, context, live_town):
			var pickup := _garrison_pickup(stacks, garrison)
			stacks = pickup.stacks
			garrison = pickup.left
		var defended := _leave_defense(session, context, live_town, stacks, garrison, is_main)
		stacks = defended.stacks
		garrison = defended.garrison
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

## Lesser heroes that keep an army of their own: one per town held beyond the
## first, up to FIELD_ARMY_MAX, the most experienced first (the strongest army
## among equals), so the same heroes keep the job from day to day.
static func _field_hero_ids(session: SessionStateStoreScript.SessionData, controller: String) -> Array:
	var slots := mini(FIELD_ARMY_MAX, _turn_rules()._owned_town_entries(session, controller).size() - 1)
	if slots <= 0:
		return []
	var main_id := _main_hero_id(session, controller)
	var others := []
	for hero in active_hero_entries(session, controller):
		if String(hero.get("placement_id", "")) != main_id:
			others.append(hero)
	others.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		var xp_a := int(a.get("enemy_commander_state", {}).get("experience", 0))
		var xp_b := int(b.get("enemy_commander_state", {}).get("experience", 0))
		if xp_a != xp_b:
			return xp_a > xp_b
		var power_a := hero_power(a)
		var power_b := hero_power(b)
		if not is_equal_approx(power_a, power_b):
			return power_a > power_b
		return String(a.get("placement_id", "")) < String(b.get("placement_id", "")))
	var ids := []
	for hero in others.slice(0, slots):
		ids.append(String(hero.get("placement_id", "")))
	return ids

static func _decision_field_ids(session: SessionStateStoreScript.SessionData, context: Dictionary) -> Array:
	var cache: Dictionary = context.get("decision", {})
	if not cache.has("field"):
		cache["field"] = _field_hero_ids(session, String(context.controller))
		context["decision"] = cache
	return cache["field"]

## How much strength the main army lacks for the weakest hostile hero or
## town it cannot beat alone: a visible hostile hero needs HERO_ATTACK_RATIO
## of its strength, a town of another player TOWN_ATTACK_RATIO of its garrison
## and the hero in its doorway. 0 when there is no such target. On a medium map
## three field armies of 13,000 each sat out 70 days in front of a 10,000 main
## hero and its towns, none of them strong enough alone.
static func _main_shortfall(session: SessionStateStoreScript.SessionData, context: Dictionary, main: Dictionary) -> float:
	var cache: Dictionary = context.get("decision", {})
	if cache.has("shortfall"):
		return float(cache["shortfall"])
	var controller := String(context.controller)
	var power := hero_power(main)
	var need := INF
	if not cache.has("hostile"):
		cache["hostile"] = _hostile_heroes(session, controller)
	for threat in cache.hostile:
		var required := float(threat.power) * HERO_ATTACK_RATIO
		if required > power:
			need = minf(need, required)
	for town in session.overworld.get("towns", []):
		if not (town is Dictionary):
			continue
		var owner := String(town.get("owner", "neutral"))
		if owner == "neutral" or (owner == "enemy" and PlayerRules.allied(session, controller, PlayerRules.town_controller_id(town))):
			continue
		if owner == "player" and PlayerRules.allied(session, controller, "player"):
			continue
		var defense := army_power(town.get("garrison", []))
		var defender_index := _town_hero_defender_index(session, town, controller)
		if defender_index >= 0:
			defense += hero_power(session.overworld.encounters[defender_index])
		var required := defense * TOWN_ATTACK_RATIO
		if required > power:
			need = minf(need, required)
	# A guard the main army found in its way to a rival town and could not beat.
	var blocked := float(main.get(AI_HERO_KEY, {}).get(BLOCKED_NEED_KEY, 0.0))
	if blocked > power:
		need = minf(need, blocked)
	var shortfall := 0.0 if need == INF else need - power
	cache["shortfall"] = shortfall
	context["decision"] = cache
	return shortfall

## How many towns one side holds: the human's (`owner` "player") or one
## computer player's.
static func _towns_held_by(session: SessionStateStoreScript.SessionData, owner: String, controller: String) -> int:
	var count := 0
	for town in session.overworld.get("towns", []):
		if not (town is Dictionary) or String(town.get("owner", "")) != owner:
			continue
		if owner == "player" or PlayerRules.town_controller_id(town) == controller:
			count += 1
	return count

## A player with no town left is out of the game once its heroes fall: each of
## them carries a share of ELIMINATION_VALUE.
static func _last_stand_share(session: SessionStateStoreScript.SessionData, owner: String, controller: String) -> float:
	if _towns_held_by(session, owner, controller) > 0:
		return 0.0
	var heroes: int = session.overworld.get("player_heroes", []).size() if owner == "player" else active_hero_entries(session, controller).size()
	return ELIMINATION_VALUE / float(maxi(1, heroes))

## The share of a hero's army health the other side's commander could take
## with one cast of its strongest battle damage spell it has mana for. On a
## medium map a hero with six cadets attacked one with a single Shard Warden at
## five times its strength, unpreviewed, and lost everything to one Bell Lance
## (70 damage): spread over four rounds the spell had looked like 20 a round.
static func _burst_share(entry: Dictionary, commander: Variant) -> float:
	if not (commander is Dictionary) or commander.is_empty():
		return 0.0
	var health := 0.0
	for stack in entry.get("enemy_army", {}).get("stacks", []) if entry.get("enemy_army", {}) is Dictionary else []:
		if stack is Dictionary:
			health += float(ContentService.get_unit(String(stack.get("unit_id", ""))).get("hp", 1)) * float(int(stack.get("count", 0)))
	if health <= 0.0:
		return 0.0
	return minf(1.0, _spell_burst(commander) / health)

## The most damage one cast of a battle damage spell does that the commander
## knows and has the mana for.
static func _spell_burst(commander: Dictionary) -> float:
	var spellbook: Dictionary = commander.get("spellbook", {}) if commander.get("spellbook", {}) is Dictionary else {}
	var known = spellbook.get("known_spell_ids", [])
	if not (known is Array) or known.is_empty():
		return 0.0
	var mana_state: Dictionary = spellbook.get("mana", {}) if spellbook.get("mana", {}) is Dictionary else {}
	var mana := int(mana_state.get("current", mana_state.get("max", 0)))
	var power := maxi(0, int(commander.get("command", {}).get("power", 0)) if commander.get("command", {}) is Dictionary else 0)
	var best := 0.0
	for spell_id in known:
		var spell := ContentService.get_spell(String(spell_id))
		var effect: Dictionary = spell.get("effect", {}) if spell.get("effect", {}) is Dictionary else {}
		if String(spell.get("context", "")) != "battle" or String(effect.get("type", "")) != "damage_enemy":
			continue
		if int(spell.get("mana_cost", 1)) > mana:
			continue
		best = maxf(best, float(int(effect.get("base_damage", 0)) + power * int(effect.get("power_scale", 0))))
	return best

## The main army is led by the most experienced hero, the strongest army among
## equals. Going by army alone, a lesser hero carrying a big garrison out to
## the main hero became the main hero itself, kept the troops, and left the
## hero with the levels and the fights behind with nothing.
static func _main_hero_id(session: SessionStateStoreScript.SessionData, controller: String) -> String:
	# The most experienced hero leads, among those still holding a real army:
	# a veteran whose army was beaten collects troops again rather than draw
	# them off the hero that has them.
	var heroes := active_hero_entries(session, controller)
	var strongest := 0.0
	for hero in heroes:
		strongest = maxf(strongest, hero_power(hero))
	var best_id := ""
	var best_experience := -1
	var best_power := -1.0
	for hero in heroes:
		var power := hero_power(hero)
		if power < strongest * MAIN_ARMY_SHARE:
			continue
		var experience := int(hero.get("enemy_commander_state", {}).get("experience", 0))
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
	var strongest := 0.0
	for threat in cache.hostile:
		if int(threat.get("level", 0)) != LevelRules.level_of(entrance):
			continue
		var distance := maxi(absi(int(threat.x) - int(entrance.get("x", 0))), absi(int(threat.y) - int(entrance.get("y", 0))))
		if distance <= int(threat.get("reach", 10)) + 2 and float(threat.power) > defense * THREAT_RATIO:
			threatened = true
			if float(threat.power) > strongest:
				strongest = float(threat.power)
				cache["threat_hero:%s" % String(town.get("placement_id", ""))] = threat
	cache[key] = threatened
	context["decision"] = cache
	return threatened

## The strongest hostile hero that threatens the town ({} when none does):
## position, level, strength and reach.
static func _strongest_threat(session: SessionStateStoreScript.SessionData, context: Dictionary, town: Dictionary) -> Dictionary:
	if not _town_threatened(session, context, town):
		return {}
	return context.get("decision", {}).get("threat_hero:%s" % String(town.get("placement_id", "")), {})

## Whether a hero stays in a threatened town of ours. The main hero stays
## while the threat is too strong to attack; a lesser hero would only be lost
## there and goes on. A weaker raider the hero can catch today it hunts. One it
## cannot catch today would walk back in behind it, so the hero leaves just
## enough troops to beat that raider, or stays when that would cost more than a
## quarter of its strength.
static func _holds_gate(session: SessionStateStoreScript.SessionData, context: Dictionary, entry: Dictionary, town: Dictionary, is_main: bool) -> bool:
	var threat := _strongest_threat(session, context, town)
	if threat.is_empty():
		return false
	if float(threat.power) * HERO_ATTACK_RATIO > hero_power(entry):
		# Holding the gate is worth it while the hero and the garrison make
		# the town too strong to storm (TOWN_ATTACK_RATIO); against more, the
		# hero would only be lost with the town, so it keeps out of reach.
		var defense := hero_power(entry) + army_power(town.get("garrison", []))
		return is_main and float(threat.power) < defense * TOWN_ATTACK_RATIO
	var distance := maxi(absi(int(threat.x) - int(entry.get("x", 0))), absi(int(threat.y) - int(entry.get("y", 0))))
	if distance <= int(entry.get(AI_HERO_KEY, {}).get("movement", {}).get("current", 0)):
		return false
	return not _leave_guard(session, context, entry, town, float(threat.power) * THREAT_RATIO)

## Whether a threatened town of ours is worth this hero's coming home to: the
## hero can beat the threat, or it is the main or a field army that holds the
## gate against it (_holds_gate). A lesser hero too weak for the threat would
## only walk in, go on and come back each morning.
static func _would_hold_gate(session: SessionStateStoreScript.SessionData, context: Dictionary, entry: Dictionary, town: Dictionary, is_main: bool) -> bool:
	var threat := _strongest_threat(session, context, town)
	if threat.is_empty() or float(threat.power) * HERO_ATTACK_RATIO <= hero_power(entry):
		return true
	return is_main and float(threat.power) < (hero_power(entry) + army_power(town.get("garrison", []))) * TOWN_ATTACK_RATIO

## Moves the fewest creatures of one kind that together beat `needed` from the
## hero into the town's garrison. False when that would cost the hero more
## than GUARD_SHARE_MAX of its strength or leave it without troops.
static func _leave_guard(session: SessionStateStoreScript.SessionData, context: Dictionary, entry: Dictionary, town: Dictionary, needed: float) -> bool:
	var needed_left := needed - army_power(town.get("garrison", []))
	if needed_left <= 0.0:
		return true
	var army: Dictionary = entry.get("enemy_army", {})
	var stacks: Array = army.get("stacks", []).duplicate(true) if army.get("stacks", []) is Array else []
	var total := army_power(stacks)
	var best := -1
	var best_count := 0
	var best_cost := INF
	for index in range(stacks.size()):
		var stack: Dictionary = stacks[index]
		var one := stack.duplicate(true)
		one["count"] = 1
		var unit := army_power([one])
		if unit <= 0.0:
			continue
		var count := int(ceil(needed_left / unit))
		if count > int(stack.get("count", 0)) or (count == int(stack.get("count", 0)) and stacks.size() == 1):
			continue
		if count * unit < best_cost:
			best_cost = count * unit
			best = index
			best_count = count
	if best < 0 or best_cost > total * GUARD_SHARE_MAX:
		return false
	var guard: Dictionary = stacks[best].duplicate(true)
	guard["count"] = best_count
	guard.erase("slot_index")
	var placed := _merge_stacks_into(town.get("garrison", []), [guard])
	if not placed.get("left", []).is_empty():
		return false
	stacks[best]["count"] = int(stacks[best].get("count", 0)) - best_count
	if int(stacks[best]["count"]) <= 0:
		stacks.remove_at(best)
	var index := _entry_index(session, String(entry.get("placement_id", "")))
	var town_index := int(_find_town(session, String(town.get("placement_id", ""))).get("index", -1))
	if index < 0 or town_index < 0:
		return false
	army["stacks"] = stacks
	entry["enemy_army"] = army
	entry["enemy_commander_state"] = AdventureRules.sync_commander_army_continuity(entry.get("enemy_commander_state", {}), army, AI_HERO_ENCOUNTER_ID)
	_store_entry(session, index, entry)
	var towns: Array = session.overworld.get("towns", [])
	towns[town_index]["garrison"] = placed.get("stacks", [])
	session.overworld["towns"] = towns
	context["decision"] = {}
	return true

## Troops a hero leaving this town keeps in its garrison (see DEFENSE_*):
## the weakest creatures first, as many as stop the raiders that could come,
## or none when holding the town would cost more than it is worth.
static func _leave_defense(session: SessionStateStoreScript.SessionData, context: Dictionary, town: Dictionary, stacks: Array, garrison: Array, is_main: bool) -> Dictionary:
	var unchanged := {"stacks": stacks, "garrison": garrison}
	var missing := _town_defense_need(session, context, town) - army_power(garrison)
	if missing <= 0.0:
		return unchanged
	var total := army_power(stacks)
	var budget := minf(total * (DEFENSE_SHARE_MAX_MAIN if is_main else DEFENSE_SHARE_MAX), _town_worth(session, context, town) / TROOP_VALUE_PER_POWER)
	if missing > budget:
		return unchanged
	var kept := stacks.duplicate(true)
	var left := garrison.duplicate(true)
	var order := range(kept.size())
	order.sort_custom(func(a: int, b: int) -> bool:
		return _unit_power(kept[a]) < _unit_power(kept[b]))
	var creatures := 0
	for stack in kept:
		creatures += int(stack.get("count", 0))
	for stack_index in order:
		if missing <= 0.0:
			break
		var stack: Dictionary = kept[stack_index]
		var unit := _unit_power(stack)
		if unit <= 0.0:
			continue
		var take := mini(int(ceil(missing / unit)), mini(int(stack.get("count", 0)), creatures - 1))
		if take <= 0:
			continue
		var placed := _merge_stacks_into(left, [{"unit_id": String(stack.get("unit_id", "")), "count": take}])
		if not placed.get("left", []).is_empty():
			continue
		left = placed.stacks
		stack["count"] = int(stack.get("count", 0)) - take
		creatures -= take
		missing -= unit * float(take)
	if missing > 0.0:
		return unchanged
	var remaining := []
	for stack in kept:
		if int(stack.get("count", 0)) > 0:
			remaining.append(stack)
	return {"stacks": remaining, "garrison": left}

static func _unit_power(stack: Dictionary) -> float:
	return army_power([{"unit_id": String(stack.get("unit_id", "")), "count": 1}])

## The garrison that stops the raiders that could reach this town soon: the
## strongest visible hostile hero within DEFENSE_HORIZON_DAYS of its doorway,
## or, with none in sight but a known rival town that near, a raider of
## DEFENSE_BASELINE_PER_WEEK for each week of the game; and, wherever it was
## seen, the strongest hero of a rival that holds no town (`_townless_raider`).
static func _town_defense_need(session: SessionStateStoreScript.SessionData, context: Dictionary, town: Dictionary) -> float:
	var cache: Dictionary = context.get("decision", {})
	if not cache.has("hostile"):
		cache["hostile"] = _hostile_heroes(session, String(context.controller))
		context["decision"] = cache
	var entrance := LevelRules.town_entrance(town)
	var level := LevelRules.level_of(town)
	var strongest := 0.0
	for threat in cache.hostile:
		if int(threat.get("level", 0)) != level:
			continue
		var distance := maxi(absi(int(threat.x) - int(entrance.get("x", 0))), absi(int(threat.y) - int(entrance.get("y", 0))))
		if distance <= int(threat.get("reach", 10)) * DEFENSE_HORIZON_DAYS + 1:
			strongest = maxf(strongest, float(threat.power))
	var need := 0.0
	if strongest > 0.0:
		need = strongest * DEFENSE_MARGIN / TOWN_ATTACK_RATIO
	elif _rival_town_within(session, context, town, 12 * DEFENSE_HORIZON_DAYS):
		need = DEFENSE_BASELINE_PER_WEEK * ceilf(float(int(session.day)) / 7.0)
	return maxf(need, _townless_raider(session, context) * DEFENSE_MARGIN / TOWN_ATTACK_RATIO)

## The strongest hero this player remembers (SIGHTINGS_KEY) of a rival that
## holds no town, while that hero is still on the map. Kept for the decision.
static func _townless_raider(session: SessionStateStoreScript.SessionData, context: Dictionary) -> float:
	var cache: Dictionary = context.get("decision", {})
	if cache.has("townless_raider"):
		return float(cache["townless_raider"])
	var strongest := 0.0
	var memory = context.state.get(SIGHTINGS_KEY, {})
	if memory is Dictionary:
		var townless := {}
		for id in memory.keys():
			var seen = memory[id]
			if not (seen is Dictionary):
				continue
			var owner := String(seen.get("owner", ""))
			if not townless.has(owner):
				var heroes := {}
				if _towns_held_by(session, "player" if owner == "player" else "enemy", owner) <= 0:
					if owner == "player":
						for hero in session.overworld.get("player_heroes", []):
							if hero is Dictionary:
								heroes[String(hero.get("id", ""))] = true
					else:
						for entry in active_hero_entries(session, owner):
							heroes[String(entry.get("placement_id", ""))] = true
				townless[owner] = heroes
			if (townless[owner] as Dictionary).has(String(id)):
				strongest = maxf(strongest, float(seen.get("power", 0.0)))
	cache["townless_raider"] = strongest
	context["decision"] = cache
	return strongest

## Whether a rival's town this player knows of lies within `radius` tiles.
static func _rival_town_within(session: SessionStateStoreScript.SessionData, context: Dictionary, town: Dictionary, radius: int) -> bool:
	var controller := String(context.controller)
	var size: Vector2i = context.map_size
	for other in session.overworld.get("towns", []):
		if not (other is Dictionary) or LevelRules.level_of(other) != LevelRules.level_of(town):
			continue
		var owner := String(other.get("owner", "neutral"))
		if owner == "neutral":
			continue
		var rival := "player" if owner == "player" else PlayerRules.town_controller_id(other)
		if rival == controller or PlayerRules.allied(session, controller, rival):
			continue
		if maxi(absi(int(other.get("x", 0)) - int(town.get("x", 0))), absi(int(other.get("y", 0)) - int(town.get("y", 0)))) > radius:
			continue
		if _town_seen(_explored(session, context, LevelRules.level_of(other)), other, size):
			return true
	return false

## What holding a town is worth: a base plus four weeks of its income and of
## the troops its dwellings muster, priced as the town planner prices them.
static func _town_worth(session: SessionStateStoreScript.SessionData, context: Dictionary, town: Dictionary) -> float:
	var cache: Dictionary = context.get("town_worth", {})
	var id := String(town.get("placement_id", ""))
	if cache.has(id):
		return float(cache[id])
	var income := _build_value(_overworld_rules().town_income(town, session)) * 7.0 * TOWN_HORIZON_WEEKS
	var troops := _recruit_set_value(_trial_growth(town)) * TOWN_HORIZON_WEEKS
	var worth := TOWN_BASE_VALUE + income + troops
	cache[id] = worth
	context["town_worth"] = cache
	return worth

## A share of the worth of the most valuable of our towns this hostile hero
## threatens: removing it saves the town.
static func _threatened_town_share(session: SessionStateStoreScript.SessionData, context: Dictionary, other: Dictionary) -> float:
	var best := 0.0
	var power := hero_power(other)
	var reach := maxi(6, _movement_max(other))
	for town in session.overworld.get("towns", []):
		if not (town is Dictionary) or String(town.get("owner", "")) != "enemy" or PlayerRules.town_controller_id(town) != String(context.controller):
			continue
		var entrance := LevelRules.town_entrance(town)
		if not LevelRules.same_level(entrance, other):
			continue
		var distance := maxi(absi(int(other.get("x", 0)) - int(entrance.get("x", 0))), absi(int(other.get("y", 0)) - int(entrance.get("y", 0))))
		if distance <= reach + 2 and power > army_power(town.get("garrison", [])) * THREAT_RATIO:
			best = maxf(best, _town_worth(session, context, town) * THREAT_KILL_SHARE)
	return best

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
		if not home.is_empty() and _holds_gate(session, context, entry, home, placement_id == _decision_main_id(session, context) or _decision_field_ids(session, context).has(placement_id)):
			# A hostile hero is a day away: the hero holds the gate, unless it
			# can catch and beat that hero today. The goal says so.
			entry = session.overworld.encounters[index]
			var holding: Dictionary = entry.get(AI_HERO_KEY, {})
			holding["goal"] = {"kind": "hold", "id": String(home.get("placement_id", ""))}
			entry[AI_HERO_KEY] = holding
			_store_entry(session, index, entry)
			break
		var logging := bool(session.flags.get(BATTLE_LOG_FLAG, false))
		if logging:
			context["decision_alternatives"] = []
		var plan := _choose_plan(session, context, entry)
		if logging:
			_log_decision(session, context, entry, plan)
			context.erase("decision_alternatives")
		if plan.is_empty() or String(plan.get("kind", "")) == "wait":
			_note_boat_need(session, context, entry)
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
			if bool(step.get("rerouted", false)):
				continue
			break
		var acted := bool(step.get("acted", not step.get("events", []).is_empty() or String(plan.get("kind", "")) == "town_own"))
		if acted:
			_forget_beyond(context, String(plan.get("id", "")))
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
	var gold_before := int(context.state.treasury.get("gold", 0))
	var power_before := army_power(entry.get("enemy_army", {}).get("stacks", []))
	TownServices.visit(town, entry, context.state.treasury, int(session.day), String(context.controller))
	_economy_add(session, String(context.controller), "service_gold", float(gold_before - int(context.state.treasury.get("gold", 0))))
	_economy_add(session, String(context.controller), "upgraded_power", army_power(entry.get("enemy_army", {}).get("stacks", [])) - power_before)
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
## While the hero decides, nothing on the map changes until another hero is
## moved out of the way (`_clear_way`, `_gate_walk`): no site changes hands and
## no hero of the player is hired, beaten or given anything. The decision's
## searches share each site's passability (SITE_PASS_DECISION_KEY) and its
## sight questions each own hero's scouting radius (SCOUT_RADII_KEY); both are
## dropped before any hero moves and when the decision ends.
static func _choose_plan(session: SessionStateStoreScript.SessionData, context: Dictionary, entry: Dictionary) -> Dictionary:
	_open_decision_memos(context)
	var plan := _decide_plan(session, context, entry)
	_close_decision_memos(context)
	return plan

static func _open_decision_memos(context: Dictionary) -> void:
	context[SITE_PASS_DECISION_KEY] = {}
	context[SCOUT_RADII_KEY] = {}

static func _close_decision_memos(context: Dictionary) -> void:
	context.erase(SITE_PASS_DECISION_KEY)
	context.erase(SCOUT_RADII_KEY)

static func _decide_plan(session: SessionStateStoreScript.SessionData, context: Dictionary, entry: Dictionary) -> Dictionary:
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
	# A guard it beats without losing a creature costs the hero nothing but
	# the walk: it fights it first.
	var free := _free_fight(session, context, entry, search)
	if not free.is_empty():
		free["path"] = _path_to(search, int(free.tile_index))
		return free
	started = Time.get_ticks_usec()
	var best := _vetted_candidate(session, context, entry, search, movement_max)
	_profile_add(context, "choose_ms", started)
	# Main and field armies weigh what decides the game anywhere on the map
	# against the best thing near them, by the same value per day of travel,
	# and what lies past the subterranean gates they can walk to.
	if _plans_far(session, context, entry):
		started = Time.get_ticks_usec()
		var wide := _search(session, context, entry, movement_max * STRATEGIC_DAYS)
		_note_route_visit(session, context, entry)
		var far := _strategic_candidate(session, context, entry, movement_max, radius, wide)
		_profile_add(context, "strategic_ms", started)
		started = Time.get_ticks_usec()
		var gate := _gate_candidate(session, context, entry, wide, movement_max, movement_max * STRATEGIC_DAYS)
		_profile_add(context, "gate_ms", started)
		var near_score := float(best.get("score", 0.0))
		if not gate.is_empty() and float(gate.score) > maxf(near_score, float(far.get("score", 0.0))) and _gate_fight_looks_good(session, context, entry, gate):
			_close_decision_memos(context)
			return _gate_walk(session, context, entry, gate, wide)
		if not far.is_empty() and float(far.get("score", 0.0)) > near_score:
			return far
	if best.is_empty():
		# Nothing worth doing nearby: look a week out before standing still.
		started = Time.get_ticks_usec()
		search = _search(session, context, entry, movement_max * FAR_SEARCH_DAYS)
		_profile_add(context, "search_ms", started)
		started = Time.get_ticks_usec()
		best = _vetted_candidate(session, context, entry, search, movement_max)
		_profile_add(context, "choose_ms", started)
	if best.is_empty():
		_close_decision_memos(context)
		var cleared := _clear_way(session, context, entry, movement_max * FAR_SEARCH_DAYS, movement_max)
		_open_decision_memos(context)
		if cleared:
			# A hero of the player's own stepped aside: look again.
			search = _search(session, context, entry, movement_max * FAR_SEARCH_DAYS)
			best = _vetted_candidate(session, context, entry, search, movement_max)
	if best.is_empty():
		# Nothing left on this level: the other one, through a gate.
		started = Time.get_ticks_usec()
		best = _gate_candidate(session, context, entry, search, movement_max, movement_max * FAR_SEARCH_DAYS)
		if not best.is_empty() and not _gate_fight_looks_good(session, context, entry, best):
			best = {}
		if not best.is_empty() and best.has("past_path"):
			_close_decision_memos(context)
			return _gate_walk(session, context, entry, best, search)
		_profile_add(context, "gate_ms", started)
	if best.is_empty():
		best = _evade(session, context, entry, search)
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

## A weak guard the hero can reach today and beat without losing a creature:
## the fight is worth whatever it pays, against no cost at all, so the hero
## fights it at once, as a human clears the weak guards in reach. Strength alone
## cannot promise that (about one fight in six against guards under 5% of the
## hero's strength still costs a creature), so the nearest such guards are
## previewed; the preview is this same battle, dice included, and the fight
## that follows reuses it. A guard that would cost a creature is not previewed
## again this turn while the army stays the same.
static func _free_fight(session: SessionStateStoreScript.SessionData, context: Dictionary, entry: Dictionary, search: Dictionary) -> Dictionary:
	var block: Dictionary = entry.get(AI_HERO_KEY, {})
	var reach := int(block.get("movement", {}).get("current", 0))
	var power := hero_power(entry)
	if reach <= 0 or power <= 0.0:
		return {}
	var avoid: Dictionary = block.get("avoid", {}) if block.get("avoid", {}) is Dictionary else {}
	var encounters: Array = session.overworld.get("encounters", [])
	var dangers := _dangers(session, context, entry)
	var size: Vector2i = context.map_size
	var level := LevelRules.level_of(entry)
	var nearest := {}
	var stops: Dictionary = search.get("stops", {})
	for tile_index in stops.keys():
		var distance := int(search.dist[int(tile_index)])
		if distance > reach or (not dangers.is_empty() and _in_danger(dangers, int(tile_index) % size.x, int(tile_index) / size.x, level)):
			continue
		for ref in stops[tile_index]:
			if int(ref.kind) == STOP_ENCOUNTER and (not nearest.has(int(ref.index)) or distance < int(nearest[int(ref.index)].distance)):
				nearest[int(ref.index)] = {"tile_index": int(tile_index), "distance": distance}
	var options := []
	for index in nearest.keys():
		var guard: Dictionary = encounters[int(index)]
		var guard_id := String(guard.get("placement_id", ""))
		if PlayerRules.raid_controller_id(guard) != "" or int(avoid.get(guard_id, -1)) >= int(session.day):
			continue
		var guard_power := _guard_power(guard)
		if guard_power <= 0.0 or guard_power > power * FREE_FIGHT_MAX_RATIO:
			continue
		options.append({"kind": "encounter", "id": guard_id, "index": int(index), "tile_index": int(nearest[index].tile_index), "distance": int(nearest[index].distance), "fight_power": guard_power})
	if options.is_empty():
		return {}
	options.sort_custom(func(a, b): return int(a.distance) < int(b.distance))
	if not context.has("costly_fights"):
		context["costly_fights"] = {}
	var costly: Dictionary = context.costly_fights
	var needs := _resource_needs(session, context)
	var stacks: Array = entry.get("enemy_army", {}).get("stacks", [])
	var army_key := hash(stacks)
	var previews := 0
	for option in options:
		if previews >= MAX_FREE_FIGHT_PREVIEWS:
			break
		var key := "%s|%s|%d" % [String(entry.get("placement_id", "")), String(option.id), army_key]
		if costly.has(key):
			continue
		# What it pays, with nothing to take off for losses.
		var value := _guard_fight_value(session, context, entry, int(option.index), power, needs, search)
		if is_nan(value):
			continue
		previews += 1
		var guard: Dictionary = encounters[int(option.index)]
		var battle_number := int(context.get("auto_battle_count", 0)) + 1
		context["preview_count"] = int(context.get("preview_count", 0)) + 1
		var started := Time.get_ticks_usec()
		# The preview stops at the first creature the hero loses: the guard is
		# costly then, and the cut-short outcome is never used.
		var outcome := _simulate_battle(session, context, entry, guard, battle_number, _creature_total(stacks))
		_profile_add(context, "preview_ms", started)
		if bool(outcome.get("won", false)) and _creature_total(outcome.get("hero_survivors", [])) >= _creature_total(stacks):
			context["fight_preview"] = {"key": _battle_key(entry, guard, battle_number), "outcome": outcome}
			option["value"] = value + _expected_loss_value(power, float(option.fight_power))
			return option
		costly[key] = true
	return {}

## Whether this hero is one of the player's armies (the main hero or a field
## army), the heroes that look across the map for the game's objectives.
static func _plans_far(session: SessionStateStoreScript.SessionData, context: Dictionary, entry: Dictionary) -> bool:
	var placement_id := String(entry.get("placement_id", ""))
	return placement_id == _decision_main_id(session, context) or _decision_field_ids(session, context).has(placement_id)

## The best objective beyond the hero's daily search: a known rival or
## neutral town, a hostile hero, or a guard standing first in the way to a
## known town (`_war_paths`), scored as everything else is, value per day of
## travel; or, while a rival's towns are unseen, the nearest unexplored ground
## and the guards whose fight opens unexplored ground. Carries the path there.
## Until 2026-10-18 only guards on the way to a known town counted here: on a
## large 3-player map (seed ai-match-147308053) the leader explored every tile
## it could reach without a fight by day 116 and its 960,000-strength armies
## then ran errands for 200 days, the last rival's towns unseen behind three
## weak guards more than three days' walk away.
static func _strategic_candidate(session: SessionStateStoreScript.SessionData, context: Dictionary, entry: Dictionary, movement_max: int, local_radius: int, wide: Dictionary = {}) -> Dictionary:
	var search := wide if not wide.is_empty() else _search(session, context, entry, movement_max * STRATEGIC_DAYS)
	var known := _explored(session, context, LevelRules.level_of(entry))
	var power := hero_power(entry)
	var needs := _resource_needs(session, context)
	var block: Dictionary = entry.get(AI_HERO_KEY, {})
	var avoid: Dictionary = block.get("avoid", {}) if block.get("avoid", {}) is Dictionary else {}
	var goal: Dictionary = block.get("goal", {}) if block.get("goal", {}) is Dictionary else {}
	var war := _war_paths(session, context, entry, search, needs)
	# While a rival's towns are unseen, a guard whose fight opens unexplored
	# ground is the way to them (`_passage_value`), however far.
	var hunting := _rival_towns_unknown(session, context) and int(session.day) >= HUNT_START_DAY
	var guard_candidates := {}
	var stops: Dictionary = search.get("stops", {})
	var best := {}
	var best_score := 0.0
	var blocked_need := INF
	for tile_index in stops.keys():
		var distance := int(search.dist[int(tile_index)])
		if distance <= local_radius:
			continue
		# A town beside a hostile hero is reached through that hero.
		var hero_guarded := _in_hero_zone(search, int(tile_index))
		for ref in stops[tile_index]:
			if hero_guarded and not bool(ref.get("zone", false)):
				continue
			var candidate := {}
			match int(ref.kind):
				STOP_TOWN:
					if not _town_seen(known, session.overworld.towns[int(ref.index)], context.map_size):
						continue
				STOP_HERO, STOP_AI_HERO:
					pass
				STOP_RESOURCE, STOP_ARTIFACT:
					# A site in the way to a known town, or to unexplored ground
					# while a rival's towns are unseen.
					var door := _site_door_key(int(tile_index))
					if not _site_doors(search).has(int(tile_index)) or known[int(tile_index)] == 0 or not (war.has(door) or hunting):
						continue
					if _site_door_value(session, context, entry, search, int(tile_index), needs) <= 0.0 or not (war.has(door) or int(search.get("passage_unexplored", {}).get(door, 0)) > 0):
						continue
					candidate = _candidate(session, context, entry, ref, power, needs, search, int(tile_index))
					if candidate.is_empty():
						continue
				STOP_ENCOUNTER:
					var on_war_path := war.has(int(ref.index))
					if not on_war_path and not (hunting and known[int(tile_index)] != 0):
						continue
					if on_war_path:
						var guard_need := _guard_power(session.overworld.encounters[int(ref.index)]) * GUARD_WIN_RATIO
						if guard_need > power:
							blocked_need = minf(blocked_need, guard_need)
					# One guard covers several tiles: weigh it once.
					if not guard_candidates.has(int(ref.index)):
						var weighed := _candidate(session, context, entry, ref, power, needs, search)
						if not on_war_path and int(search.get("passage_unexplored", {}).get(int(ref.index), 0)) <= 0:
							weighed = {}
						guard_candidates[int(ref.index)] = weighed
					candidate = guard_candidates[int(ref.index)].duplicate()
					if candidate.is_empty():
						continue
				_:
					continue
			if candidate.is_empty():
				candidate = _candidate(session, context, entry, ref, power, needs, search)
			if candidate.is_empty() or String(candidate.get("kind", "")) in ["town_own", "meet"]:
				continue
			if int(avoid.get(String(candidate.get("id", "")), -1)) >= int(session.day):
				continue
			var value := float(candidate.get("value", 0.0)) - _boat_price(session, context, search, int(tile_index))
			if value <= 0.0:
				continue
			var score := value / (1.0 + float(distance) / float(movement_max))
			if String(goal.get("id", "")) != "" and String(goal.get("id", "")) == String(candidate.get("id", "")):
				score *= GOAL_CONTINUITY_BONUS
			if context.has("decision_alternatives"):
				_note_alternative(context, candidate, score, distance)
			if score > best_score:
				best_score = score
				candidate["tile_index"] = int(tile_index)
				candidate["distance"] = distance
				candidate["score"] = score
				best = candidate
	if _rival_towns_unknown(session, context):
		var explore := _exploration_candidate(session, context, entry, search)
		if not explore.is_empty() and int(explore.distance) > local_radius:
			var explore_score := float(explore.value) / (1.0 + float(explore.distance) / float(movement_max))
			if explore_score > best_score:
				explore["score"] = explore_score
				best = explore
		elif explore.is_empty():
			# Shut in with the rivals unseen and no ground left to scout: the
			# guards around are the way out, and the weakest it cannot beat
			# says how much stronger the main army must grow. On an extra-large
			# map with strong guards each surviving player's armies, split
			# 20,000 to 35,000, stayed shut in their own corner for 60 days.
			for tile_index in stops.keys():
				for ref in stops[tile_index]:
					if int(ref.kind) != STOP_ENCOUNTER:
						continue
					var way_out := _guard_power(session.overworld.encounters[int(ref.index)]) * GUARD_WIN_RATIO
					if way_out > power:
						blocked_need = minf(blocked_need, way_out)
	if not best.is_empty():
		best["path"] = _path_to(search, int(best.tile_index))
	# Remember what strength the way to a rival town needs, for the field armies.
	if placement_is_main(session, context, entry):
		block[BLOCKED_NEED_KEY] = 0.0 if blocked_need == INF else blocked_need
		entry[AI_HERO_KEY] = block
	return best

## The best errand past a subterranean gate the hero can walk to. Its search
## covers one level, so for each of the nearest gates (MAX_GATES_WEIGHED) the
## hero looks at the other level as if it stood at the gate's exit, takes the
## best candidate there (`_best_candidate`, fog-honest: unexplored ground is
## worth scouting) and scores it by the whole way, to the gate and on from its
## exit. Generated maps guard a gate at both ends: a guard whose zone covers
## the gate here is fought first, worth what lies beyond as well (the plan is
## that fight); the guard at the far end is fought on arrival (`_cross_gate`),
## so the hero must beat it too and its expected losses count. The chosen plan's
## next fight is previewed (`_gate_fight_looks_good`). Crossing keeps the errand
## as the goal. Until 2026-10-17 heroes
## never left their level: in the 2026-10-16 batch 22 of 32 two-level games ran
## to the 160-day cap (6 of 60 one-level land games), main armies of 7,000 to
## 280,000 strength idle while the rivals beyond the gates kept their towns.
static func _gate_candidate(session: SessionStateStoreScript.SessionData, context: Dictionary, entry: Dictionary, search: Dictionary, movement_max: int, beyond_radius: int) -> Dictionary:
	var level := LevelRules.level_of(entry)
	var gates: Dictionary = _level_surface(session, context, level).get("gates", {})
	if gates.is_empty() or not search.has("dist"):
		return {}
	var block: Dictionary = entry.get(AI_HERO_KEY, {})
	var avoid: Dictionary = block.get("avoid", {}) if block.get("avoid", {}) is Dictionary else {}
	var goal: Dictionary = block.get("goal", {}) if block.get("goal", {}) is Dictionary else {}
	var dangers := _dangers(session, context, entry)
	var size: Vector2i = context.map_size
	var stops: Dictionary = search.get("stops", {})
	var dist: PackedInt32Array = search.dist
	var nodes: Array = session.overworld.get("resource_nodes", [])
	var encounters: Array = session.overworld.get("encounters", [])
	var power := hero_power(entry)
	var reachable := []
	for gate_tile in gates.keys():
		var tile := int(gate_tile)
		if tile >= dist.size() or dist[tile] < 0 or _in_hero_zone(search, tile):
			continue
		if not dangers.is_empty() and _in_danger(dangers, tile % size.x, tile / size.x, level):
			continue
		var id := "gate:%s" % String(nodes[int(gates[gate_tile].node)].get("placement_id", ""))
		if int(avoid.get(id, -1)) >= int(session.day):
			continue
		var guard_index := -1
		for ref in stops.get(tile, []):
			if int(ref.kind) == STOP_ENCOUNTER:
				guard_index = int(ref.index)
				break
		if guard_index >= 0 and int(avoid.get(String(encounters[guard_index].get("placement_id", "")), -1)) >= int(session.day):
			continue
		reachable.append({"tile": tile, "distance": int(dist[tile]), "id": id, "gate": gates[gate_tile], "guard": guard_index})
	reachable.sort_custom(func(a, b): return int(a.distance) < int(b.distance))
	# The gates that start a longer way to a town or to unseen ground are
	# weighed too, however far they lie.
	var routes := _gate_routes(session, context, entry, search, movement_max) if _plans_far(session, context, entry) else {}
	var options := reachable.slice(0, MAX_GATES_WEIGHED)
	# A gate that starts such a way but lies past the player's own heroes is
	# weighed at the walk with them stepped aside; taking it asks them to
	# (`_gate_walk`), as `_clear_way` does for an errand on the level. A route
	# leads past them (`_level_regions`), so the hero must be able to go there.
	var past := {}
	for route_tile in routes.keys():
		var tile := int(route_tile)
		if tile >= dist.size() or dist[tile] >= 0 or not gates.has(tile):
			continue
		if past.is_empty():
			past = _search(session, context, entry, int(search.get("radius", movement_max * STRATEGIC_DAYS)), true)
		var past_dist: PackedInt32Array = past.dist
		if past_dist[tile] < 0 or _in_hero_zone(past, tile):
			continue
		if not dangers.is_empty() and _in_danger(dangers, tile % size.x, tile / size.x, level):
			continue
		var id := "gate:%s" % String(nodes[int(gates[tile].node)].get("placement_id", ""))
		if int(avoid.get(id, -1)) >= int(session.day):
			continue
		var guard_index := -1
		for ref in past.get("stops", {}).get(tile, []):
			if int(ref.kind) == STOP_ENCOUNTER:
				guard_index = int(ref.index)
				break
		if guard_index >= 0 and int(avoid.get(String(encounters[guard_index].get("placement_id", "")), -1)) >= int(session.day):
			continue
		options.append({"tile": tile, "distance": int(past_dist[tile]), "id": id, "gate": gates[tile], "guard": guard_index, "past_path": _path_to(past, tile)})
	for option in reachable.slice(MAX_GATES_WEIGHED):
		if routes.has(int(option.tile)):
			options.append(option)
	var needs := _resource_needs(session, context)
	var best := {}
	var best_score := 0.0
	for option in options:
		var near := 0.0
		if int(option.guard) >= 0:
			near = _guard_fight_value(session, context, entry, int(option.guard), power, needs, search)
			if is_nan(near):
				continue
		var beyond := _beyond_gate(session, context, entry, option.gate, movement_max, beyond_radius)
		# What lies beyond is kept for the turn; the hero may have given it up since.
		if not beyond.is_empty() and int(avoid.get(String(beyond.id), -1)) >= int(session.day):
			beyond = {}
		var route: Dictionary = routes.get(int(option.tile), {})
		if beyond.is_empty() and route.is_empty():
			continue
		var value := near + float(beyond.get("value", 0.0))
		var distance := int(option.distance) + int(beyond.get("distance", 0))
		var target := {"kind": String(beyond.get("kind", "")), "id": String(beyond.get("id", ""))}
		if not route.is_empty():
			var route_value := near + float(route.value)
			var route_distance := maxi(int(option.distance), int(route.distance))
			# Past this one gate the way is walked from its exit, as the
			# hero will walk it there: the straight line made each level's
			# objective look nearer from the other one.
			var far_dist := _gate_far_dist(context, entry, option.gate, beyond_radius)
			if bool(route.get("direct", false)) and int(route.tile) >= 0 and int(route.tile) < far_dist.size() and far_dist[int(route.tile)] >= 0:
				route_distance = int(option.distance) + 1 + far_dist[int(route.tile)]
			if beyond.is_empty() or route_value / (1.0 + float(route_distance) / float(movement_max)) > value / (1.0 + float(distance) / float(movement_max)):
				value = route_value
				distance = route_distance
				target = {"kind": String(route.kind), "id": String(route.id)}
		if value <= 0.0:
			continue
		var score := value / (1.0 + float(distance) / float(movement_max))
		var plan := {"kind": "gate", "id": String(option.id), "index": int(option.gate.node), "value": value, "tile_index": int(option.tile), "distance": distance, "beyond": target}
		if option.has("past_path"):
			plan["past_path"] = option.past_path
		if beyond.is_empty():
			var exit: Vector3i = option.gate.exit
			var far_guard: Dictionary = _overworld_rules()._find_guard_engagement_at_tile(session, exit.x, exit.y, exit.z, false)
			beyond = {"far_guard": int(far_guard.get("index", -1)), "far_fight_power": _guard_power(far_guard.encounter) if int(far_guard.get("index", -1)) >= 0 else 0.0}
		if int(option.guard) >= 0:
			var guard: Dictionary = encounters[int(option.guard)]
			var guard_power := _guard_power(guard)
			plan.merge({"kind": "encounter", "id": String(guard.get("placement_id", "")), "index": int(option.guard), "fight_power": guard_power, "estimated_loss": _expected_loss_value(power, guard_power)}, true)
		elif int(beyond.far_guard) >= 0:
			plan.merge({"far_guard": int(beyond.far_guard), "far_fight_power": float(beyond.far_fight_power)}, true)
		if String(goal.get("id", "")) != "" and String(goal.get("id", "")) in [String(option.id), String(plan.id), String(target.id)]:
			score *= GOAL_CONTINUITY_BONUS
		if score > best_score:
			best_score = score
			plan["score"] = score
			best = plan
	if not best.is_empty() and context.has("decision_alternatives"):
		_note_alternative(context, best, best_score, int(best.distance))
	return best

## For each subterranean gate on the hero's level that starts its way to
## something that decides the game on ground it cannot walk to (another
## stretch of either level, `_level_stretches`): a town it can take
## (`_town_candidate`) or, while a rival's towns are unseen, a stretch with
## unseen ground (worth what scouting is while hunting, plus a share of the
## hidden rival as in `_opened_value`). The way may pass any number of gates;
## every gate on it must have guards the hero beats at both ends
## (`_route_gate_open`), and every army between them must be one it would fight
## for that objective (`_level_stretches`). A way never comes back onto the
## hero's own stretch. Keyed by the first gate's tile: the best objective it
## leads to, its value and the whole way's length. Kept for the decision.
## `_gate_candidate` weighs these gates and `_war_paths` the guards in the way
## to them. Until 2026-10-18 a hero looked one gate ahead only: on a large
## two-level map (seed ai-match-3718099446) a rival's home town lay five gates
## from the leader's 372,000-strength army, and another rival's last four
## towns stood unseen in a stretch three gates away; neither was ever weighed
## from day 163 to the 320-day cap.
static func _gate_routes(session: SessionStateStoreScript.SessionData, context: Dictionary, entry: Dictionary, search: Dictionary, movement_max: int) -> Dictionary:
	var size: Vector2i = context.map_size
	var level := LevelRules.level_of(entry)
	var start_tile := _tile_index_of(entry, size)
	# Only from where the hero stands, not as if at a gate's exit (`_beyond_gate`).
	if bool(entry.get(TRAVELLER_KEY, false)) or start_tile < 0 or not search.has("dist"):
		return {}
	var cache: Dictionary = context.get("decision", {})
	var key := "gate_routes:%s:%d:%d" % [String(entry.get("placement_id", "")), level, start_tile]
	if cache.has(key):
		return cache[key]
	var result := {}
	cache[key] = result
	context["decision"] = cache
	var map := _route_map(session, context)
	if map.get("gates", []).is_empty():
		return result
	var power := hero_power(entry)
	# The objectives, by the losses a fight on the way to each may cost.
	var by_limit := {}
	for town in _route_towns(session, context, entry, power, map):
		var limit := _route_loss_limit(float(town.value))
		if not by_limit.has(limit):
			by_limit[limit] = []
		by_limit[limit].append(town)
	var explore_limit := -1.0
	if _rival_towns_unknown(session, context):
		explore_limit = _route_loss_limit(_explore_value(session, context))
		if not by_limit.has(explore_limit):
			by_limit[explore_limit] = []
	for limit in by_limit.keys():
		_route_through(session, context, entry, search, movement_max, map, power, float(limit), by_limit[limit], float(limit) == explore_limit, result)
	return result

## How much a fight on the way to an objective worth `value` may cost
## (`_expected_loss_value`): the share of it the fight itself is credited with
## when the hero stands before the guard (`_war_paths`), rounded down to a
## power of two so that few limits need their own stretches.
static func _route_loss_limit(value: float) -> float:
	var share := value * PASSAGE_KNOWN_SITE_SHARE
	if share < 1.0:
		return 0.0
	return pow(2.0, floor(log(share) / log(2.0)))

## `_gate_routes` for the objectives of one loss limit: towns and, when
## `explore`, the stretches with unseen ground. Writes the best way per first
## gate into `result`.
static func _route_through(session: SessionStateStoreScript.SessionData, context: Dictionary, entry: Dictionary, search: Dictionary, movement_max: int, map: Dictionary, power: float, limit: float, towns: Array, explore: bool, result: Dictionary) -> void:
	var size: Vector2i = context.map_size
	var level := LevelRules.level_of(entry)
	var start_tile := _tile_index_of(entry, size)
	var gates: Array = map.gates
	var home_key := _stretch_key(session, context, level, start_tile, power, limit, entry)
	if home_key == "":
		return
	# The gates out of each stretch, and where each comes out.
	var by_region := {}
	var exit_keys := []
	for gate_index in range(gates.size()):
		var gate: Dictionary = gates[gate_index]
		var region_key := _stretch_key(session, context, int(gate.level), int(gate.tile), power, limit, entry)
		exit_keys.append(_stretch_key(session, context, int(gate.exit_level), int(gate.exit_tile), power, limit, entry))
		if region_key == "" or exit_keys[gate_index] == "":
			continue
		if not by_region.has(region_key):
			by_region[region_key] = []
		by_region[region_key].append(gate_index)
	var targets := {}
	for town in towns:
		var town_key := _stretch_key(session, context, int(town.level), int(town.tile), power, limit, entry)
		if town_key == "" or town_key == home_key:
			continue
		if not targets.has(town_key):
			targets[town_key] = []
		targets[town_key].append(town)
	if explore:
		_route_unseen(session, context, entry, map, power, limit, home_key, targets)
	if targets.is_empty():
		return
	# Shortest ways out through the gates whose guards it beats, cheapest first.
	var count := gates.size()
	var cost := []
	cost.resize(count)
	cost.fill(INF)
	var first := []
	first.resize(count)
	first.fill(-1)
	var settled := []
	settled.resize(count)
	settled.fill(false)
	var dist: PackedInt32Array = search.dist
	for gate_index in by_region.get(home_key, []):
		var tile := int(gates[gate_index].tile)
		if not _route_gate_open(gates[gate_index], power, limit):
			continue
		cost[gate_index] = float(dist[tile]) if tile < dist.size() and dist[tile] >= 0 else _tile_span(start_tile, tile, size) * ROUTE_DETOUR
		first[gate_index] = gate_index
	while true:
		var current := -1
		for gate_index in range(count):
			if not bool(settled[gate_index]) and float(cost[gate_index]) < INF and (current < 0 or float(cost[gate_index]) < float(cost[current])):
				current = gate_index
		if current < 0:
			break
		settled[current] = true
		# A way back onto the hero's own stretch leads nowhere its own gates do
		# not: they are priced by the real walk to them, a way through a gate and
		# back by the straight line, which made going out and straight back look
		# shorter than a long walk around rock.
		if String(exit_keys[current]) == home_key:
			continue
		var gate: Dictionary = gates[current]
		var arrived := float(cost[current]) + 1.0
		var start_gate: Dictionary = gates[int(first[current])]
		for target in targets.get(String(exit_keys[current]), []):
			var total := arrived + (_tile_span(int(gate.exit_tile), int(target.tile), size) * ROUTE_DETOUR if int(target.tile) >= 0 else 0.0)
			var score := float(target.value) / (1.0 + total / float(movement_max))
			var known: Dictionary = result.get(int(start_gate.tile), {})
			if known.is_empty() or score > float(known.score):
				result[int(start_gate.tile)] = {"kind": String(target.kind), "id": String(target.id), "value": float(target.value), "distance": int(ceil(total)), "score": score, "tile": int(target.tile), "direct": int(first[current]) == current}
		for next_index in by_region.get(String(exit_keys[current]), []):
			if bool(settled[next_index]) or not _route_gate_open(gates[next_index], power, limit):
				continue
			var through := arrived + _tile_span(int(gate.exit_tile), int(gates[next_index].tile), size) * ROUTE_DETOUR
			if through < float(cost[next_index]):
				cost[next_index] = through
				first[next_index] = first[current]

## Whether a route may pass this gate: the hero beats the guards at its ends
## (GUARD_WIN_RATIO) at no greater expected loss than the objective's limit, as
## for the armies between gates (`_level_stretches`).
static func _route_gate_open(gate: Dictionary, power: float, limit: float) -> bool:
	return float(gate.guard_power) * GUARD_WIN_RATIO <= power and _expected_loss_value(power, float(gate.guard_power)) <= limit

## The gates, towns and unseen ground `_gate_routes` works with, built once a
## turn: every gate with the tiles at its ends and the stronger of the guards
## there, every seen town's doorway and, per level, how many tiles of each
## patch (`_level_regions`) the player has not seen. `_stretch_key` puts them
## on a hero's stretches.
static func _route_map(session: SessionStateStoreScript.SessionData, context: Dictionary) -> Dictionary:
	if context.has("route_map"):
		return context["route_map"]
	var map := {"gates": [], "towns": [], "unseen": {}}
	context["route_map"] = map
	var levels := LevelRules.level_count(session)
	if levels < 2:
		return map
	var size: Vector2i = context.map_size
	for gate_level in range(levels):
		var level_gates: Dictionary = _level_surface(session, context, gate_level).get("gates", {})
		for gate_tile in level_gates.keys():
			var exit: Vector3i = level_gates[gate_tile].exit
			if exit.z < 0 or exit.z >= levels:
				continue
			var exit_tile := exit.y * size.x + exit.x
			var guard_power := 0.0
			for spot in [Vector3i(int(gate_tile) % size.x, int(gate_tile) / size.x, gate_level), exit]:
				var guard: Dictionary = _overworld_rules()._find_guard_engagement_at_tile(session, spot.x, spot.y, spot.z, false)
				if int(guard.get("index", -1)) >= 0:
					guard_power = maxf(guard_power, _guard_power(guard.encounter))
			map.gates.append({"tile": int(gate_tile), "level": gate_level, "exit_tile": exit_tile, "exit_level": exit.z, "guard_power": guard_power})
	var towns: Array = session.overworld.get("towns", [])
	for index in range(towns.size()):
		var town = towns[index]
		if not (town is Dictionary):
			continue
		var town_level := LevelRules.level_of(town)
		var door := _tile_index_of(LevelRules.town_entrance(town), size)
		if door < 0 or town_level < 0 or town_level >= levels:
			continue
		if _town_seen(_explored(session, context, town_level), town, size):
			map.towns.append({"index": index, "level": town_level, "door": door})
	for target_level in range(levels):
		var patches: PackedInt32Array = _level_regions(session, context, target_level).patches
		var known := _explored(session, context, target_level)
		var unseen := {}
		for tile in range(mini(patches.size(), known.size())):
			if known[tile] == 0 and patches[tile] >= 0:
				unseen[patches[tile]] = int(unseen.get(patches[tile], 0)) + 1
		map.unseen[target_level] = unseen
	return map

## The towns `_gate_routes` may lead to: seen towns the hero can take
## (`_town_candidate`) out of a much stronger hostile hero's reach, with their
## doorways.
static func _route_towns(session: SessionStateStoreScript.SessionData, context: Dictionary, entry: Dictionary, power: float, map: Dictionary) -> Array:
	var towns := []
	var block: Dictionary = entry.get(AI_HERO_KEY, {})
	var avoid: Dictionary = block.get("avoid", {}) if block.get("avoid", {}) is Dictionary else {}
	var dangers := _dangers(session, context, entry)
	var size: Vector2i = context.map_size
	for town_ref in map.towns:
		var candidate := _town_candidate(session, context, entry, int(town_ref.index), power)
		if String(candidate.get("kind", "")) not in ["town_hostile", "town_neutral"] or float(candidate.get("value", 0.0)) <= 0.0:
			continue
		if int(avoid.get(String(candidate.id), -1)) >= int(session.day):
			continue
		# Within a much stronger hostile hero's reach it is left alone there
		# (`_best_candidate`), so no way leads to it either.
		if not dangers.is_empty() and _in_danger(dangers, int(town_ref.door) % size.x, int(town_ref.door) / size.x, int(town_ref.level)):
			continue
		towns.append({"kind": String(candidate.kind), "id": String(candidate.id), "value": float(candidate.value), "level": int(town_ref.level), "tile": int(town_ref.door)})
	return towns

## The stretches with unseen ground `_gate_routes` may lead to while a rival's
## towns are unseen, leaving out the hero's own and those it stood on lately
## (tile -1: reaching the stretch is enough), added to `targets` by stretch.
static func _route_unseen(session: SessionStateStoreScript.SessionData, context: Dictionary, entry: Dictionary, map: Dictionary, power: float, limit: float, home_key: String, targets: Dictionary) -> void:
	var block: Dictionary = entry.get(AI_HERO_KEY, {})
	var visits: Dictionary = block.get(ROUTE_VISITS_KEY, {}) if block.get(ROUTE_VISITS_KEY, {}) is Dictionary else {}
	var explore_value := _explore_value(session, context)
	var unseen := {}
	for target_level in map.unseen.keys():
		var stretches := _level_stretches(session, context, int(target_level), power, limit, entry)
		for patch in map.unseen[target_level].keys():
			var stretch_key := "%d:%d" % [int(target_level), stretches[int(patch)]]
			unseen[stretch_key] = int(unseen.get(stretch_key, 0)) + int(map.unseen[target_level][patch])
	for region_key in unseen.keys():
		if String(region_key) == home_key or int(unseen[region_key]) < ROUTE_UNEXPLORED_MIN:
			continue
		if visits.has(region_key) and int(visits[region_key]) + ROUTE_REVISIT_DAYS > int(session.day):
			continue
		var value := explore_value + ELIMINATION_VALUE * HIDDEN_RIVAL_SHARE * minf(1.0, float(unseen[region_key]) / float(HIDDEN_RIVAL_TILES))
		if not targets.has(region_key):
			targets[region_key] = []
		targets[region_key].append({"kind": "explore", "id": "region:%s" % region_key, "value": value, "tile": -1})

## Notes the stretch a main or field army stands on today (ROUTE_REVISIT_DAYS).
static func _note_route_visit(session: SessionStateStoreScript.SessionData, context: Dictionary, entry: Dictionary) -> void:
	var tile := _tile_index_of(entry, context.map_size)
	if LevelRules.level_count(session) < 2 or tile < 0:
		return
	var block: Dictionary = entry.get(AI_HERO_KEY, {})
	var visits := {}
	var known: Dictionary = block.get(ROUTE_VISITS_KEY, {}) if block.get(ROUTE_VISITS_KEY, {}) is Dictionary else {}
	for region_key in known.keys():
		if int(known[region_key]) + ROUTE_REVISIT_DAYS > int(session.day):
			visits[region_key] = int(known[region_key])
	var here := _stretch_key(session, context, LevelRules.level_of(entry), tile, hero_power(entry), _route_loss_limit(_explore_value(session, context)), entry)
	if here != "":
		visits[here] = int(session.day)
	block[ROUTE_VISITS_KEY] = visits
	entry[AI_HERO_KEY] = block

static func _tile_span(from_tile: int, to_tile: int, size: Vector2i) -> float:
	return float(maxi(absi(from_tile % size.x - to_tile % size.x), absi(from_tile / size.x - to_tile / size.x)))

## Each level's ground split into patches a hero walks between without a
## subterranean gate or a fight: rock, water, the bodies of map objects and the
## zones of neutral armies and rival heroes part them; the player's own heroes
## and claimed sites do not, and a monolith joins the ground it links on the
## level. Each army's zone (with the ground it stands on) is a patch of its own,
## listed in `guards` with its strength, the margin it is attacked from and the
## patches beside it (`links`); `_level_stretches` joins them across the armies
## a hero beats. `patches`: patch id per tile, -1 where nothing
## stands; `starts`: each patch's first tile. Built once a turn.
static func _level_regions(session: SessionStateStoreScript.SessionData, context: Dictionary, level: int) -> Dictionary:
	var cache: Dictionary = context.get("level_regions", {})
	if cache.has(level):
		return cache[level]
	var surface := _level_surface(session, context, level)
	var size: Vector2i = context.map_size
	var count := size.x * size.y
	var blocked: PackedByteArray = surface.blocked
	var static_stops: Dictionary = surface.stops
	var portals: Dictionary = surface.get("portals", {})
	var native_corners := NativeTransit.uses_native_adjacency(session)
	var resolved := _resolved_lookup(session)
	# Tiles no patch takes: rock and bodies that do not end a route, and water.
	var water: PackedByteArray = surface.get("water", PackedByteArray())
	var closed := PackedByteArray()
	closed.resize(count)
	for tile in range(count):
		if (blocked[tile] != 0 and not static_stops.has(tile)) or (tile < water.size() and water[tile] != 0):
			closed[tile] = 1
	var patches := PackedInt32Array()
	patches.resize(count)
	patches.fill(-1)
	var starts := PackedInt32Array()
	var guards := []
	var armies := []
	var encounters: Array = session.overworld.get("encounters", [])
	for record in surface.neutrals:
		if not resolved.has(String(record.id)):
			armies.append({"id": String(record.id), "power": _guard_power(encounters[int(record.index)]), "tiles": record.zone + record.body})
	# Rival heroes stand still through this player's turn and end a route
	# where they stand, as the search has it.
	var sight := _sight_context(String(context.controller))
	for hero_guard in _hero_guards(session, context, level):
		if not bool(hero_guard.hostile):
			continue
		var tiles := [int(hero_guard.tile.y) * size.x + int(hero_guard.tile.x)]
		for zone_tile in _hero_zone_tiles(session, context, hero_guard.tile, level):
			tiles.append(int(zone_tile.y) * size.x + int(zone_tile.x))
		var army := {"id": String(hero_guard.id), "tiles": tiles}
		if String(hero_guard.ref_kind) == "ai_hero":
			var other: Dictionary = encounters[int(hero_guard.index)]
			army.merge({"power": hero_power(other), "commander": other.get("enemy_commander_state", {}), "seen": _position_seen(session, sight, LevelRules.position(other))})
		else:
			var hero: Dictionary = session.overworld.player_heroes[int(hero_guard.index)]
			army.merge({"power": army_power(hero.get("army", {}).get("stacks", []), hero), "commander": hero, "seen": _player_hero_seen(session, sight, hero)})
		armies.append(army)
	for army in armies:
		var patch := starts.size()
		var tiles := []
		for tile in army.tiles:
			var guard_tile := int(tile)
			if guard_tile < 0 or guard_tile >= count or patches[guard_tile] >= 0 or closed[guard_tile] != 0:
				continue
			patches[guard_tile] = patch
			tiles.append(guard_tile)
		if tiles.is_empty():
			continue
		starts.append(tiles.min())
		var guard_record: Dictionary = army.duplicate()
		guard_record.merge({"tiles": tiles, "links": {}}, true)
		guards.append(guard_record)
	var queue := PackedInt32Array()
	queue.resize(count)
	var width := size.x
	var height := size.y
	var step_offset := _step_offsets(width)
	for start in range(count):
		if patches[start] >= 0 or closed[start] != 0:
			continue
		var patch := starts.size()
		starts.append(start)
		patches[start] = patch
		var head := 0
		var tail := 0
		queue[tail] = start
		tail += 1
		while head < tail:
			var current := queue[head]
			head += 1
			if portals.has(current):
				for exit in portals[current].exits:
					if patches[exit] < 0:
						patches[exit] = patch
						queue[tail] = exit
						tail += 1
					elif patches[exit] < guards.size():
						guards[patches[exit]].links[patch] = true
			var cx := current % width
			var cy := current / width
			var on_edge := cx == 0 or cy == 0 or cx == width - 1 or cy == height - 1
			for direction in range(8):
				var dx: int = NEIGHBOR_DX[direction]
				var dy: int = NEIGHBOR_DY[direction]
				if on_edge and (cx + dx < 0 or cy + dy < 0 or cx + dx >= width or cy + dy >= height):
					continue
				var next := current + step_offset[direction]
				if patches[next] >= 0 or closed[next] != 0:
					continue
				if dx != 0 and dy != 0 and not native_corners and blocked[current + dx] != 0 and blocked[current + dy * width] != 0:
					continue
				patches[next] = patch
				queue[tail] = next
				tail += 1
	# What each army's zone touches: open ground, other zones, portal exits.
	for guard_patch in range(guards.size()):
		var links: Dictionary = guards[guard_patch].links
		for tile in guards[guard_patch].tiles:
			var cx: int = int(tile) % size.x
			var cy: int = int(tile) / size.x
			for direction in range(8):
				var nx: int = cx + NEIGHBOR_DX[direction]
				var ny: int = cy + NEIGHBOR_DY[direction]
				if nx < 0 or ny < 0 or nx >= size.x or ny >= size.y:
					continue
				var next := ny * size.x + nx
				if patches[next] < 0 or patches[next] == guard_patch:
					continue
				if nx != cx and ny != cy and not native_corners and blocked[cy * size.x + nx] != 0 and blocked[ny * size.x + cx] != 0:
					continue
				links[patches[next]] = true
			if portals.has(int(tile)):
				for exit in portals[int(tile)].exits:
					if patches[exit] >= 0 and patches[exit] != guard_patch:
						links[patches[exit]] = true
	var regions := {"patches": patches, "starts": starts, "guards": guards}
	cache[level] = regions
	context["level_regions"] = cache
	return regions

## A level's stretches of ground for a hero of this strength on its way to an
## objective whose fights may cost up to `loss_limit` (`_route_loss_limit`):
## the patches of `_level_regions` joined across the armies it beats
## (GUARD_WIN_RATIO, as for the guards at gates; a rival hero as `_candidate`
## attacks one: in sight, by HERO_ATTACK_RATIO after its spells' damage) at no
## greater expected loss (`_expected_loss_value`), or that are beaten already.
## An army the hero leaves alone today (`_avoided_today`) parts them. The hero,
## standing before such an army, fights it for that objective (`_war_paths`,
## `_hero_war_value`). Each stretch is named by its first tile; per patch and
## hero, kept for the turn. Until
## 2026-10-19 armies did not part stretches: on a large two-level map (seed
## ai-match-462267043) gate 2232 led a 1,632-strength army into a pocket closed
## by guards of 8,000 and more, and the stretch beyond counted as reached. The
## army found nothing there, went back to its town through the paired gate and
## was sent through 2232 again, three times a day for 116 days. Grown to 10,800
## strength it beat one of those guards by the strength margin alone, but at
## an expected loss above what the unseen ground beyond was worth, and it went
## on crossing back and forth. Another army crossed for a town a stronger rival
## hero kept it from, and crossed back.
static func _level_stretches(session: SessionStateStoreScript.SessionData, context: Dictionary, level: int, power: float, loss_limit: float, entry: Dictionary = {}) -> PackedInt32Array:
	var avoided := _avoided_today(session, entry)
	var avoided_ids := avoided.keys()
	avoided_ids.sort()
	var key := "%d|%d|%d|%s|%s" % [level, int(power), int(loss_limit), String(entry.get("placement_id", "")), ",".join(avoided_ids)]
	var cache: Dictionary = context.get("level_stretches", {})
	if cache.has(key):
		return cache[key]
	var regions := _level_regions(session, context, level)
	var starts: PackedInt32Array = regions.starts
	var guards: Array = regions.guards
	var resolved := _resolved_lookup(session)
	var beaten := PackedByteArray()
	beaten.resize(guards.size())
	for guard_patch in range(guards.size()):
		var guard: Dictionary = guards[guard_patch]
		if resolved.has(String(guard.id)):
			beaten[guard_patch] = 1
		elif avoided.has(String(guard.id)) or _expected_loss_value(power, float(guard.power)) > loss_limit:
			continue
		elif not guard.has("commander"):
			if float(guard.power) * GUARD_WIN_RATIO <= power:
				beaten[guard_patch] = 1
		# A rival hero as `_candidate` attacks one: seen, and beaten after the
		# damage its spells do.
		elif bool(guard.seen) and power * (1.0 - _burst_share(entry, guard.commander)) >= float(guard.power) * HERO_ATTACK_RATIO:
			beaten[guard_patch] = 1
	var parent := range(starts.size())
	for guard_patch in range(guards.size()):
		if beaten[guard_patch] == 0:
			continue
		for link in guards[guard_patch].links.keys():
			if int(link) < guards.size() and beaten[int(link)] == 0:
				continue
			var a := _patch_root(parent, guard_patch)
			var b := _patch_root(parent, int(link))
			if a != b:
				parent[maxi(a, b)] = mini(a, b)
	var names := PackedInt32Array()
	names.resize(starts.size())
	names.fill(-1)
	for patch in range(starts.size()):
		var root := _patch_root(parent, patch)
		if names[root] < 0 or starts[patch] < names[root]:
			names[root] = starts[patch]
	var stretches := PackedInt32Array()
	stretches.resize(starts.size())
	for patch in range(starts.size()):
		stretches[patch] = names[_patch_root(parent, patch)]
	cache[key] = stretches
	context["level_stretches"] = cache
	return stretches

static func _patch_root(parent: Array, patch: int) -> int:
	while int(parent[patch]) != patch:
		parent[patch] = parent[int(parent[patch])]
		patch = int(parent[patch])
	return patch

## The stretch ("level:first tile") a tile lies on for a hero of this
## strength and loss limit (`_level_stretches`), "" where nothing stands.
static func _stretch_key(session: SessionStateStoreScript.SessionData, context: Dictionary, level: int, tile: int, power: float, loss_limit: float, entry: Dictionary = {}) -> String:
	var patches: PackedInt32Array = _level_regions(session, context, level).patches
	if tile < 0 or tile >= patches.size() or patches[tile] < 0:
		return ""
	return "%d:%d" % [level, _level_stretches(session, context, level, power, loss_limit, entry)[patches[tile]]]

## The targets the hero leaves alone today (`_avoid_target`), a fight whose
## preview went badly among them.
static func _avoided_today(session: SessionStateStoreScript.SessionData, entry: Dictionary) -> Dictionary:
	var avoid: Dictionary = entry.get(AI_HERO_KEY, {}).get("avoid", {}) if entry.get(AI_HERO_KEY, {}).get("avoid", {}) is Dictionary else {}
	var result := {}
	for id in avoid.keys():
		if int(avoid[id]) >= int(session.day):
			result[String(id)] = true
	return result

## The way home for an idle hero whose player holds no town on its level: the
## shortest way to the town's doorway through one of the nearest gates
## (MAX_GATES_WEIGHED), fighting the guards at either end when the hero beats
## them. Without it such a hero waited on its own level at the town's
## coordinates, out of the way of every recruit.
static func _gate_home(session: SessionStateStoreScript.SessionData, context: Dictionary, entry: Dictionary, search: Dictionary, town: Dictionary) -> Dictionary:
	var level := LevelRules.level_of(entry)
	var gates: Dictionary = _level_surface(session, context, level).get("gates", {})
	if gates.is_empty() or not search.has("dist"):
		return {}
	var door := LevelRules.town_entrance(town)
	var size: Vector2i = context.map_size
	var door_index := int(door.get("y", 0)) * size.x + int(door.get("x", 0))
	var stops: Dictionary = search.get("stops", {})
	var dist: PackedInt32Array = search.dist
	var encounters: Array = session.overworld.get("encounters", [])
	var nodes: Array = session.overworld.get("resource_nodes", [])
	var power := hero_power(entry)
	var movement_max := maxi(1, int(entry.get(AI_HERO_KEY, {}).get("movement", {}).get("max", 1)))
	var reachable := []
	for gate_tile in gates.keys():
		var tile := int(gate_tile)
		if (gates[gate_tile].exit as Vector3i).z != LevelRules.level_of(door) or tile >= dist.size() or dist[tile] < 0 or _in_hero_zone(search, tile):
			continue
		reachable.append({"tile": tile, "distance": int(dist[tile]), "gate": gates[gate_tile]})
	reachable.sort_custom(func(a, b): return int(a.distance) < int(b.distance))
	var best := {}
	for option in reachable.slice(0, MAX_GATES_WEIGHED):
		var guard_index := -1
		for ref in stops.get(int(option.tile), []):
			if int(ref.kind) == STOP_ENCOUNTER:
				guard_index = int(ref.index)
				break
		if guard_index >= 0 and power < _guard_power(encounters[guard_index]) * GUARD_WIN_RATIO:
			continue
		var exit: Vector3i = option.gate.exit
		var far_guard: Dictionary = _overworld_rules()._find_guard_engagement_at_tile(session, exit.x, exit.y, exit.z, false)
		var far_index := int(far_guard.get("index", -1))
		if far_index >= 0 and power < _guard_power(far_guard.encounter) * GUARD_WIN_RATIO:
			continue
		var traveller := entry.duplicate()
		traveller[TRAVELLER_KEY] = true
		traveller["x"] = exit.x
		traveller["y"] = exit.y
		traveller["level"] = exit.z
		var far_search := _search(session, context, traveller, movement_max * FAR_SEARCH_DAYS)
		# Where guards keep the doorway out of reach for now, the hero still
		# goes up and waits nearer home; the straight way counts double.
		var far_distance := int(far_search.dist[door_index]) if door_index >= 0 and door_index < far_search.dist.size() else -1
		if far_distance < 0:
			far_distance = 2 * maxi(absi(exit.x - int(door.get("x", 0))), absi(exit.y - int(door.get("y", 0)))) + movement_max * FAR_SEARCH_DAYS
		var distance := int(option.distance) + far_distance
		if not best.is_empty() and distance >= int(best.distance):
			continue
		var town_id := String(town.get("placement_id", ""))
		best = {"kind": "gate", "id": "gate:%s" % String(nodes[int(option.gate.node)].get("placement_id", "")), "index": int(option.gate.node), "value": 0.0, "tile_index": int(option.tile), "distance": distance, "beyond": {"kind": "park", "id": town_id}}
		if guard_index >= 0:
			var guard_power := _guard_power(encounters[guard_index])
			best.merge({"kind": "encounter", "id": String(encounters[guard_index].get("placement_id", "")), "index": guard_index, "value": 1.0, "fight_power": guard_power, "estimated_loss": _expected_loss_value(power, guard_power)}, true)
		elif far_index >= 0:
			best.merge({"value": 1.0, "far_guard": far_index, "far_fight_power": _guard_power(far_guard.encounter)}, true)
	if best.is_empty() or not _gate_fight_looks_good(session, context, entry, best):
		return {}
	return best

## Whether the fight a gate plan leads to next, the guard in front of the gate
## or the one at its far end, looks good in a preview (`_fight_looks_good`). A
## bad one is left alone for a few days.
static func _gate_fight_looks_good(session: SessionStateStoreScript.SessionData, context: Dictionary, entry: Dictionary, plan: Dictionary) -> bool:
	var fight := plan
	if String(plan.kind) == "gate":
		if not plan.has("far_guard"):
			return true
		var far_power := float(plan.far_fight_power)
		fight = {"kind": "encounter", "index": int(plan.far_guard), "value": float(plan.value), "fight_power": far_power, "estimated_loss": _expected_loss_value(hero_power(entry), far_power)}
	if _fight_looks_good(session, context, entry, fight):
		return true
	_avoid_target(session, String(entry.get("placement_id", "")), String(plan.id), int(session.day) + 3)
	return false

## The best candidate on the other level for a hero standing at this gate's
## exit, plus what beating the guard whose zone covers the exit is worth (it
## is fought on arrival, so its expected losses count); empty when that guard
## is too strong. Kept for the turn while the hero's army stays the same.
static func _beyond_gate(session: SessionStateStoreScript.SessionData, context: Dictionary, entry: Dictionary, gate: Dictionary, movement_max: int, radius: int) -> Dictionary:
	var exit: Vector3i = gate.exit
	var cache: Dictionary = context.get("gate_beyond", {})
	var key := _beyond_key(entry, gate, radius)
	if cache.has(key):
		return cache[key]
	var traveller := entry.duplicate()
	traveller[TRAVELLER_KEY] = true
	traveller["x"] = exit.x
	traveller["y"] = exit.y
	traveller["level"] = exit.z
	# The other level's candidates are not this decision's alternatives.
	var logged: Variant = context.get("decision_alternatives", null)
	context.erase("decision_alternatives")
	var far_search := _search(session, context, traveller, radius)
	var far_dists: Dictionary = context.get("gate_far", {})
	far_dists[key] = far_search.get("dist", PackedInt32Array())
	context["gate_far"] = far_dists
	# Judged as the hero will judge it there (`_choose_plan`): errands within its
	# daily search, or a week out when none is; towns and heroes farther for a
	# main or field army. Until 2026-10-19 everything in this wider search
	# counted: on a large two-level map (seed ai-match-1951169169) a hero
	# crossed for its own threatened town 47 tiles past the gate, out of the
	# reach it judges errands in once there, and crossed back to scout, for
	# nine days.
	var near_radius := maxi(MIN_SEARCH_RADIUS, movement_max * SEARCH_DAYS)
	var far_kinds := _plans_far(session, context, entry)
	var far := _best_candidate(session, context, traveller, far_search, movement_max, near_radius, far_kinds)
	if far.is_empty():
		far = _best_candidate(session, context, traveller, far_search, movement_max, maxi(near_radius, movement_max * FAR_SEARCH_DAYS), far_kinds)
	if logged != null:
		context["decision_alternatives"] = logged
	var result := {}
	var guard: Dictionary = _overworld_rules()._find_guard_engagement_at_tile(session, exit.x, exit.y, exit.z, false)
	var guard_index := int(guard.get("index", -1))
	var guard_id := String(guard.encounter.get("placement_id", "")) if guard_index >= 0 else ""
	var value := float(far.get("value", 0.0))
	var guard_value := 0.0
	if guard_index >= 0 and String(far.get("id", "")) != guard_id:
		guard_value = _guard_fight_value(session, context, traveller, guard_index, hero_power(entry), _resource_needs(session, context), far_search)
	if not is_nan(guard_value) and (not far.is_empty() or guard_index >= 0) and value + guard_value > 0.0:
		result = {
			"kind": String(far.get("kind", "encounter")),
			"id": String(far.get("id", guard_id)),
			"value": value + guard_value,
			"distance": int(far.get("distance", 0)),
			"far_guard": guard_index,
			"far_fight_power": _guard_power(guard.encounter) if guard_index >= 0 else 0.0,
		}
	cache[key] = result
	context["gate_beyond"] = cache
	return result

static func _beyond_key(entry: Dictionary, gate: Dictionary, radius: int) -> String:
	var exit: Vector3i = gate.exit
	return "%s|%d,%d,%d|%d|%d" % [String(entry.get("placement_id", "")), exit.x, exit.y, exit.z, radius, hash(entry.get("enemy_army", {}).get("stacks", []))]

## The walking distances from a gate's exit that `_beyond_gate` measured for
## this hero this turn; empty before it did.
static func _gate_far_dist(context: Dictionary, entry: Dictionary, gate: Dictionary, radius: int) -> PackedInt32Array:
	return context.get("gate_far", {}).get(_beyond_key(entry, gate, radius), PackedInt32Array())

## Drops what `_beyond_gate` kept for the turn about a target just taken. On a
## large two-level map (seed ai-match-462267043) a hero crossed a gate for a
## site, took it, and the kept errand drew it back through the gate twice more
## that day for the site it already held.
static func _forget_beyond(context: Dictionary, target_id: String) -> void:
	var cache: Dictionary = context.get("gate_beyond", {})
	if target_id == "" or cache.is_empty():
		return
	for key in cache.keys():
		if String((cache[key] as Dictionary).get("id", "")) == target_id:
			cache.erase(key)

static func placement_is_main(session: SessionStateStoreScript.SessionData, context: Dictionary, entry: Dictionary) -> bool:
	return String(entry.get("placement_id", "")) == _decision_main_id(session, context)

## Visible hostile heroes strong enough to beat this one (DANGER_RATIO), with
## where they stand and how far they reach next turn. Kept for the decision.
static func _dangers(session: SessionStateStoreScript.SessionData, context: Dictionary, entry: Dictionary) -> Array:
	var cache: Dictionary = context.get("decision", {})
	var key := "dangers:%s" % String(entry.get("placement_id", ""))
	if cache.has(key):
		return cache[key]
	if not cache.has("hostile"):
		cache["hostile"] = _hostile_heroes(session, String(context.controller))
	var power := hero_power(entry)
	var result := []
	for threat in cache.hostile:
		if float(threat.power) >= power * DANGER_RATIO:
			result.append(threat)
	cache[key] = result
	context["decision"] = cache
	return result

## Whether the hero standing in this town of its own, with the garrison, makes
## it too strong for the strongest of `dangers` to storm (TOWN_ATTACK_RATIO).
static func _deters(session: SessionStateStoreScript.SessionData, entry: Dictionary, town: Dictionary, dangers: Array) -> bool:
	var strongest := 0.0
	for threat in dangers:
		strongest = maxf(strongest, float(threat.power))
	return strongest < (hero_power(entry) + army_power(town.get("garrison", []))) * TOWN_ATTACK_RATIO

## Whether a tile lies where one of `dangers` can reach next turn.
static func _in_danger(dangers: Array, x: int, y: int, level: int) -> bool:
	for threat in dangers:
		if int(threat.get("level", 0)) != level:
			continue
		if maxi(absi(int(threat.x) - x), absi(int(threat.y) - y)) <= int(threat.get("reach", 10)) + 1:
			return true
	return false

## A hero within reach of a much stronger hostile hero, with nothing safe to
## do, walks to the tile it can reach today that lies farthest from it, so it
## lives to fight on better terms. A human pulls back the same way.
static func _evade(session: SessionStateStoreScript.SessionData, context: Dictionary, entry: Dictionary, search: Dictionary) -> Dictionary:
	var dangers := _dangers(session, context, entry)
	var level := LevelRules.level_of(entry)
	if dangers.is_empty() or not _in_danger(dangers, int(entry.get("x", 0)), int(entry.get("y", 0)), level):
		return {}
	var size: Vector2i = context.map_size
	var today := int(entry.get(AI_HERO_KEY, {}).get("movement", {}).get("current", 0))
	var order: PackedInt32Array = search.get("order", PackedInt32Array())
	var stops: Dictionary = search.get("stops", {})
	var best_tile := -1
	var best_gap := _danger_gap(dangers, int(entry.get("x", 0)), int(entry.get("y", 0)), level)
	for position in range(1, int(search.get("order_count", 0))):
		var tile_index := order[position]
		if int(search.dist[tile_index]) > today or stops.has(tile_index):
			continue
		var gap := _danger_gap(dangers, tile_index % size.x, tile_index / size.x, level)
		if gap > best_gap:
			best_gap = gap
			best_tile = tile_index
	if best_tile < 0:
		return {}
	return {"kind": "wait", "id": "evade:%d" % best_tile, "index": best_tile, "value": 0.0, "tile_index": best_tile, "distance": int(search.dist[best_tile])}

## How far a tile lies outside the reach of the nearest of `dangers` (negative
## inside it).
static func _danger_gap(dangers: Array, x: int, y: int, level: int) -> int:
	var gap := 1 << 20
	for threat in dangers:
		if int(threat.get("level", 0)) != level:
			continue
		gap = mini(gap, maxi(absi(int(threat.x) - x), absi(int(threat.y) - y)) - int(threat.get("reach", 10)) - 1)
	return gap

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

## A gate plan with its way. Past the player's own heroes (`_gate_candidate`)
## they are asked to step aside (`_make_way`); while one cannot move today the
## hero walks up to it and goes on once it has.
static func _gate_walk(session: SessionStateStoreScript.SessionData, context: Dictionary, entry: Dictionary, plan: Dictionary, search: Dictionary) -> Dictionary:
	if not plan.has("past_path"):
		plan["path"] = _path_to(search, int(plan.tile_index))
		return plan
	var path: Array = plan.past_path
	var size: Vector2i = context.map_size
	var level := LevelRules.level_of(entry)
	var keep_clear := {}
	for tile in path:
		keep_clear[tile.y * size.x + tile.x] = true
	var doors := _own_town_doors(session, String(context.controller), level, size)
	for other in active_hero_entries(session, String(context.controller)):
		if String(other.get("placement_id", "")) == String(entry.get("placement_id", "")) or LevelRules.level_of(other) != level:
			continue
		var other_index := int(other.get("y", 0)) * size.x + int(other.get("x", 0))
		if keep_clear.has(other_index) and not doors.has(other_index):
			_make_way(session, context, String(other.get("placement_id", "")), keep_clear)
	var standing := {}
	for other in active_hero_entries(session, String(context.controller)):
		if String(other.get("placement_id", "")) != String(entry.get("placement_id", "")) and LevelRules.level_of(other) == level:
			standing[int(other.get("y", 0)) * size.x + int(other.get("x", 0))] = true
	for step in range(path.size()):
		var tile: Vector2i = path[step]
		if standing.has(tile.y * size.x + tile.x) and not doors.has(tile.y * size.x + tile.x):
			if step == 0:
				return {}
			var stop: Vector2i = path[step - 1]
			var stop_index := stop.y * size.x + stop.x
			return {"kind": "wait", "id": "wait:%d" % stop_index, "index": stop_index, "value": 0.0, "tile_index": stop_index, "distance": step, "path": path.slice(0, step)}
	plan["path"] = path
	return plan

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
	if home_town.is_empty() or String(home_town.get("owner", "")) != "enemy" or PlayerRules.town_controller_id(home_town) != controller or LevelRules.level_of(LevelRules.town_entrance(home_town)) != level:
		home_town = _nearest_owned_town(session, controller, here, level).get("town", {})
	if not home_town.is_empty() and LevelRules.level_of(LevelRules.town_entrance(home_town)) != level and keep_clear.is_empty():
		# Every town of the player stands on the other level: home is through
		# a gate.
		var homeward := _gate_home(session, context, entry, search, home_town)
		if not homeward.is_empty():
			return homeward
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
			if int(search.dist[door_index]) >= 0 and not _in_hero_zone(search, door_index):
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

## With `reach` set, stops farther away count only for `far_kinds`: towns to
## take and hostile heroes, and unexplored ground while a rival's towns are
## unseen, as `_strategic_candidate` weighs them (`_beyond_gate`).
static func _best_candidate(session: SessionStateStoreScript.SessionData, context: Dictionary, entry: Dictionary, search: Dictionary, movement_max: int, reach: int = -1, far_kinds: bool = false) -> Dictionary:
	var goal: Dictionary = entry.get(AI_HERO_KEY, {}).get("goal", {})
	var avoid: Dictionary = entry.get(AI_HERO_KEY, {}).get("avoid", {}) if entry.get(AI_HERO_KEY, {}).get("avoid", {}) is Dictionary else {}
	var seen := {}
	var best := {}
	var best_score := 0.0
	var power := hero_power(entry)
	var needs := _resource_needs(session, context)
	var known := _explored(session, context, LevelRules.level_of(entry))
	var stops: Dictionary = search.get("stops", {})
	var dangers := _dangers(session, context, entry)
	var size: Vector2i = context.map_size
	for tile_index in stops.keys():
		var distance := int(search.dist[int(tile_index)])
		# A much stronger hostile hero could reach it: the hero keeps away,
		# except to hold its own town where that stops the attack.
		var in_danger := not dangers.is_empty() and _in_danger(dangers, int(tile_index) % size.x, int(tile_index) / size.x, LevelRules.level_of(entry))
		# Stepping into a guard's or a hostile hero's zone means fighting it
		# first, as it does for the human: whatever else lies there is reached
		# through that fight.
		var guarded := _zone_guarded(stops[tile_index])
		for ref in stops[tile_index]:
			if guarded and not _guards_tile(ref):
				continue
			# Map objects count once explored; armies and heroes once in sight.
			if int(ref.kind) == STOP_TOWN:
				if not _town_seen(known, session.overworld.towns[int(ref.index)], size):
					continue
			elif int(ref.kind) not in [STOP_HERO, STOP_AI_HERO] and known[int(tile_index)] == 0:
				continue
			var key := "%d:%d" % [int(ref.kind), int(ref.index)]
			if seen.has(key) and int(seen[key]) <= distance:
				continue
			seen[key] = distance
			if in_danger and int(ref.kind) != STOP_TOWN:
				continue
			var candidate := _candidate(session, context, entry, ref, power, needs, search, int(tile_index))
			if candidate.is_empty() or int(avoid.get(String(candidate.get("id", "")), -1)) >= int(session.day):
				continue
			if reach >= 0 and distance > reach and not (far_kinds and String(candidate.get("kind", "")) in ["town_hostile", "town_neutral", "hero", "ai_hero"]):
				continue
			if in_danger and (String(candidate.get("kind", "")) != "town_own" or not _deters(session, entry, session.overworld.towns[int(candidate.index)], dangers)):
				continue
			var value := float(candidate.get("value", 0.0)) - _boat_price(session, context, search, int(tile_index))
			if value <= 0.0:
				continue
			var score := value / (1.0 + float(distance) / float(movement_max))
			if String(goal.get("id", "")) != "" and String(goal.get("id", "")) == String(candidate.get("id", "")):
				score *= GOAL_CONTINUITY_BONUS
			if context.has("decision_alternatives"):
				_note_alternative(context, candidate, score, distance)
			if score > best_score:
				best_score = score
				candidate["tile_index"] = int(tile_index)
				candidate["distance"] = distance
				candidate["score"] = score
				best = candidate
	var explore := _exploration_candidate(session, context, entry, search)
	if not explore.is_empty() and not dangers.is_empty() and _in_danger(dangers, int(explore.tile_index) % size.x, int(explore.tile_index) / size.x, LevelRules.level_of(entry)):
		explore = {}
	if not explore.is_empty() and reach >= 0 and int(explore.distance) > reach and not (far_kinds and _rival_towns_unknown(session, context)):
		explore = {}
	if not explore.is_empty():
		var explore_score := float(explore.value) / (1.0 + float(explore.distance) / float(movement_max))
		if String(goal.get("kind", "")) == "explore":
			explore_score *= GOAL_CONTINUITY_BONUS
		if explore_score > best_score:
			explore["score"] = explore_score
			best = explore
	return best

## Whether a guard's or a hostile hero's zone covers the tile these stops share.
static func _zone_guarded(refs: Array) -> bool:
	for ref in refs:
		if _guards_tile(ref):
			return true
	return false

static func _guards_tile(ref: Dictionary) -> bool:
	return int(ref.kind) == STOP_ENCOUNTER or bool(ref.get("zone", false))

static func _in_hero_zone(search: Dictionary, tile_index: int) -> bool:
	var zone: PackedByteArray = search.get("hero_zone", PackedByteArray())
	return tile_index >= 0 and tile_index < zone.size() and zone[tile_index] != 0

## The nearest reachable tile at the edge of what this player has seen: a
## human sends idle heroes to scout, so does the AI.
static func _exploration_candidate(session: SessionStateStoreScript.SessionData, context: Dictionary, entry: Dictionary, search: Dictionary) -> Dictionary:
	var known := _explored(session, context, LevelRules.level_of(entry))
	var order: PackedInt32Array = search.get("order", PackedInt32Array())
	var size: Vector2i = context.map_size
	var portals: Dictionary = _level_surface(session, context, LevelRules.level_of(entry)).get("portals", {})
	# Ground reached only by buying a boat must be worth the boat's price.
	var explore_value := _explore_value(session, context)
	var portal_frontier := -1
	for portal_tile in portals.keys():
		var portal_distance := int(search.dist[int(portal_tile)]) if int(portal_tile) < search.dist.size() else -1
		if portal_distance > 0 and not _in_hero_zone(search, int(portal_tile)) and _portal_leads_unseen(portals[portal_tile], known) and (portal_frontier < 0 or portal_distance < int(search.dist[portal_frontier])) 				and _boat_price(session, context, search, int(portal_tile)) < explore_value:
			portal_frontier = int(portal_tile)
	var portal_value := explore_value - _boat_price(session, context, search, portal_frontier)
	var dist: PackedInt32Array = search.get("dist", PackedInt32Array())
	var phase: PackedByteArray = search.get("phase", PackedByteArray())
	var width := size.x
	var height := size.y
	var step_offset := _step_offsets(width)
	for position in range(1, int(search.get("order_count", 0))):
		var tile_index := order[position]
		if portal_frontier >= 0 and dist[portal_frontier] <= dist[tile_index]:
			return {"kind": "explore", "id": "explore:%d" % portal_frontier, "index": portal_frontier, "value": portal_value, "tile_index": portal_frontier, "distance": int(search.dist[portal_frontier])}
		var x := tile_index % width
		var y := tile_index / width
		# Only a tile reached by buying a boat has a price (`_boat_price`).
		var price := 0.0
		if tile_index < phase.size() and (phase[tile_index] & BOUGHT_BOAT) != 0:
			price = _boat_price(session, context, search, tile_index)
		if price >= explore_value:
			continue
		var on_edge := x == 0 or y == 0 or x == width - 1 or y == height - 1
		for direction in range(8):
			if on_edge:
				var nx: int = x + NEIGHBOR_DX[direction]
				var ny: int = y + NEIGHBOR_DY[direction]
				if nx < 0 or ny < 0 or nx >= width or ny >= height:
					continue
			if known[tile_index + step_offset[direction]] == 0:
				return {"kind": "explore", "id": "explore:%d" % tile_index, "index": tile_index, "value": explore_value - price, "tile_index": tile_index, "distance": int(search.dist[tile_index])}
	if portal_frontier >= 0:
		return {"kind": "explore", "id": "explore:%d" % portal_frontier, "index": portal_frontier, "value": portal_value, "tile_index": portal_frontier, "distance": int(search.dist[portal_frontier])}
	return {}

## `tile_index` is the reached tile of the stop, when it is known: a site
## standing in the way is worth the ground it opens as well (`_site_door_value`).
static func _candidate(session: SessionStateStoreScript.SessionData, context: Dictionary, entry: Dictionary, ref: Dictionary, power: float, needs: Dictionary, search: Dictionary = {}, tile_index: int = -1) -> Dictionary:
	var controller := String(context.controller)
	match int(ref.kind):
		STOP_RESOURCE:
			var opens := _site_door_value(session, context, entry, search, tile_index, needs) if not search.is_empty() else 0.0
			return _resource_candidate(session, controller, entry, int(ref.index), power, needs, context.state.treasury, opens)
		STOP_ARTIFACT:
			var nodes: Array = session.overworld.get("artifact_nodes", [])
			var node: Dictionary = nodes[int(ref.index)]
			if bool(node.get("collected", false)):
				return {}
			if not _artifact_guard(session, node).is_empty():
				return {}
			var opens := _site_door_value(session, context, entry, search, tile_index, needs) if not search.is_empty() else 0.0
			return {"kind": "artifact", "id": String(node.get("placement_id", "")), "index": int(ref.index), "value": 1100.0 + opens}
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
			if power * (1.0 - _burst_share(entry, hero)) < hero_power_value * HERO_ATTACK_RATIO:
				return {}
			return {"kind": "hero", "id": String(hero.get("id", "")), "index": int(ref.index), "value": 1500.0 + hero_power_value * TROOP_VALUE_PER_POWER * 0.5 + _last_stand_share(session, "player", "player") + _hero_war_value(session, context, entry, search, needs, "hero", int(ref.index))}
		STOP_AI_HERO:
			var encounters: Array = session.overworld.get("encounters", [])
			var other: Dictionary = encounters[int(ref.index)]
			if PlayerRules.raid_controller_id(other) == controller:
				return _meet_candidate(session, context, entry, int(ref.index))
			if PlayerRules.allied(session, controller, PlayerRules.raid_controller_id(other)) or not _position_seen(session, context, LevelRules.position(other)):
				return {}
			var other_power := hero_power(other)
			if power * (1.0 - _burst_share(entry, other.get("enemy_commander_state", {}))) < other_power * HERO_ATTACK_RATIO:
				return {}
			var other_controller := PlayerRules.raid_controller_id(other)
			return {"kind": "ai_hero", "id": String(other.get("placement_id", "")), "index": int(ref.index), "value": 1200.0 + other_power * TROOP_VALUE_PER_POWER * 0.5 + _threatened_town_share(session, context, other) + _last_stand_share(session, "enemy", other_controller) + _hero_war_value(session, context, entry, search, needs, "ai_hero", int(ref.index)), "fight_power": other_power}
	return {}

## What beating a hostile hero opens: the share of the town or gate route it
## stands first in the way to (`_war_paths`) that a guard there is credited
## with. `_level_stretches` joins stretches across the heroes a hero beats, so
## a route through a gate can lead past one. Until 2026-10-19 that fight was
## worth only the hero's troops: on large two-level maps (seeds
## ai-match-8934130, ai-match-2045434390) armies crossed a gate for a rival
## town such a hero stood before, valued the fight at a few thousand, crossed
## back for other errands and were sent through again, up to three times a day
## for weeks.
static func _hero_war_value(session: SessionStateStoreScript.SessionData, context: Dictionary, entry: Dictionary, search: Dictionary, needs: Dictionary, ref_kind: String, index: int) -> float:
	if search.is_empty():
		return 0.0
	return float(_war_paths(session, context, entry, search, needs).get(_hero_war_key(ref_kind, index), 0.0)) * PASSAGE_KNOWN_SITE_SHARE

## A lesser hero walks its troops over to the main hero, the way a human
## chains reinforcements forward, keeping one creature to stay in the field.
static func _meet_candidate(session: SessionStateStoreScript.SessionData, context: Dictionary, entry: Dictionary, other_index: int) -> Dictionary:
	var encounters: Array = session.overworld.get("encounters", [])
	var other: Dictionary = encounters[other_index]
	var main_id := _decision_main_id(session, context)
	if main_id == "" or main_id == String(entry.get("placement_id", "")) or main_id != String(other.get("placement_id", "")):
		return {}
	if _decision_field_ids(session, context).has(String(entry.get("placement_id", ""))):
		# A field army joins the main army when something it has to beat is
		# beyond the main army alone: the main hero takes the stronger stacks.
		if _main_shortfall(session, context, other) <= 0.0 and hero_power(entry) <= hero_power(other) * FIELD_SHARE_MAX:
			return {}
		var swap := _garrison_pickup(other.get("enemy_army", {}).get("stacks", []).duplicate(true), entry.get("enemy_army", {}).get("stacks", []).duplicate(true))
		if float(swap.gain) <= 0.0:
			return {}
		return {"kind": "meet", "id": String(other.get("placement_id", "")), "index": other_index, "value": JOIN_BASE_VALUE + float(swap.gain) * TROOP_VALUE_PER_POWER * 0.6, "swap": true}
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

static func _resource_candidate(session: SessionStateStoreScript.SessionData, controller: String, entry: Dictionary, index: int, power: float, needs: Dictionary, treasury: Dictionary, opens: float = 0.0) -> Dictionary:
	var nodes: Array = session.overworld.get("resource_nodes", [])
	var node: Dictionary = nodes[index]
	if NativeTransit.is_native(node):
		return {}
	var site := NodePayload.site_for_node(node)
	if site.is_empty() or bool(site.get("opens_route_on_claim", false)):
		return {}
	# A shipyard serves a route over water (`_search`), a whirlpool only a boat.
	if String(site.get("id", "")) in [WaterTravel.SHIPYARD_SITE_ID, WaterTravel.WHIRLPOOL_SITE_ID]:
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
		value += _recruit_set_value(_recruit_dict(site.get("claim_recruits", {}))) + _site_artifact_value(site) + _site_spell_value(site, entry)
		if bool(site.get("persistent_control", false)):
			value += _payload_value(site.get("control_income", {}), needs) * 12.0 + 250.0
			# A site that musters troops every week is worth a week of them.
			value += _recruit_set_value(_recruit_dict(site.get("weekly_recruits", {})))
			var owner := PlayerRules.resource_controller_id(node)
			if owner != "" and owner != controller:
				value *= 1.3
	value += opens - _expected_loss_value(power, fight)
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
	var share := minf(1.0, LOSS_ESTIMATE_FACTOR * (1.0 - sqrt(1.0 - ratio * ratio)) + LOSS_ESTIMATE_PER_RATIO * ratio)
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
	# A creature bank can pay in troops and artifacts alone.
	value += _recruit_set_value(_recruit_dict(site.get("claim_recruits", {}))) + _site_artifact_value(site)
	if bool(site.get("persistent_control", false)):
		value += _payload_value(site.get("control_income", {}), needs) * 12.0 + 250.0
	if CreatureDwellings.is_dwelling(site):
		value += 500.0
	return value * 0.8

## The spells a site teaches (a spell scroll) that the hero does not know yet,
## each worth SCROLL_SPELL_BASE_VALUE plus SCROLL_SPELL_TIER_VALUE a tier.
## Until 2026-10-18 a scroll was worth nothing to the computer and its heroes
## never read one.
static func _site_spell_value(site: Dictionary, entry: Dictionary) -> float:
	var commander: Dictionary = entry.get("enemy_commander_state", {}) if entry.get("enemy_commander_state", {}) is Dictionary else {}
	var value := 0.0
	for spell_id in _overworld_rules()._resource_site_spell_ids(site):
		var spell := ContentService.get_spell(String(spell_id))
		if spell.is_empty() or SpellRulesScript.knows_spell(commander, String(spell_id)):
			continue
		value += SCROLL_SPELL_BASE_VALUE + SCROLL_SPELL_TIER_VALUE * float(maxi(1, int(spell.get("tier", 1))))
	return value

## The artifacts a generated bank or tomb holds, each worth a loose artifact.
static func _site_artifact_value(site: Dictionary) -> float:
	var classes = site.get(NodePayload.CLAIM_ARTIFACT_CLASSES, [])
	return 900.0 * float(classes.size()) if classes is Array else 0.0

## What beating a guard opens: ground beyond its zone that the hero cannot
## reach today. A human clears a road guard to get at the map behind it; the
## unexplored part is worth scouting and sites already seen there are worth
## taking. Measured once per search.
## Ground that runs on to where the search stopped for distance is open to the
## hero without the fight and opens nothing. On a large map a hero 28 tiles
## from a weak guard took the ground past its search for ground behind the
## guard and valued the guard at 11,000; ten tiles closer the search covered
## that ground, the guard was worth a few hundred and the hero turned back,
## again and again. The guard stood until day 109; without the mistake it fell
## on day 42.
static func _passage_value(session: SessionStateStoreScript.SessionData, context: Dictionary, entry: Dictionary, search: Dictionary, guard_index: int, needs: Dictionary) -> float:
	var zones: Dictionary = search.get("guard_zones", {})
	if not zones.has(guard_index):
		return 0.0
	return _opened_value(session, context, entry, search, guard_index, zones[guard_index], needs)

## A site the hero can reach whose tile ends every route over it until it is
## claimed (a pickup, a mine's doorway, an artifact) and that stands in the way
## to ground the hero cannot reach otherwise: claiming it opens that ground, as
## beating a guard does (`_passage_value`), and it is worth what that ground is.
## Until 2026-10-18 nothing counted it: on a large 3-player map (seed
## ai-match-147308053) a spell scroll, worth nothing to the computer, lay in the
## one corridor between the leader's ground and the last rival's, and neither
## side's armies, 420,000 and 184,000 strong, ever met in 200 days.
static func _site_door_value(session: SessionStateStoreScript.SessionData, context: Dictionary, entry: Dictionary, search: Dictionary, tile_index: int, needs: Dictionary) -> float:
	if tile_index < 0 or not _site_doors(search).has(tile_index):
		return 0.0
	return _opened_value(session, context, entry, search, _site_door_key(tile_index), [tile_index], needs)

## The key a site's doorway tile goes by among guard indices (`_opened_value`,
## `_war_paths`).
static func _site_door_key(tile_index: int) -> int:
	return -10 - tile_index

## `_war_paths` key of a hostile hero: the computer players' heroes
## ("ai_hero") and the human's ("hero") by their index.
static func _hero_war_key(ref_kind: String, index: int) -> int:
	return (-1000000 if ref_kind == "ai_hero" else -2000000) - index

## Reached tiles of resource and artifact sites that end routes over them and
## stand in no guard's or hostile hero's zone. Measured once per search.
static func _site_doors(search: Dictionary) -> Dictionary:
	if search.has("site_doors"):
		return search["site_doors"]
	var doors := {}
	var pass_mask: PackedByteArray = search.get("pass_mask", PackedByteArray())
	var guard_mask: PackedByteArray = search.get("guard_mask", PackedByteArray())
	var hero_zone: PackedByteArray = search.get("hero_zone", PackedByteArray())
	var stops: Dictionary = search.get("stops", {})
	for tile_index in stops.keys():
		var tile := int(tile_index)
		if pass_mask.is_empty() or pass_mask[tile] != 0 or guard_mask[tile] != 0 or hero_zone[tile] != 0:
			continue
		for ref in stops[tile_index]:
			if int(ref.kind) in [STOP_RESOURCE, STOP_ARTIFACT]:
				doors[tile] = true
				break
	search["site_doors"] = doors
	return doors

## What opening the way from `origin` (a guard's zone or a site's doorway) is
## worth: the ground beyond it the hero cannot reach today, measured once per
## search under `key`.
static func _opened_value(session: SessionStateStoreScript.SessionData, context: Dictionary, entry: Dictionary, search: Dictionary, key: int, origin: Array, needs: Dictionary) -> float:
	if not search.has("blocked"):
		return 0.0
	var cache: Dictionary = search.get("passage_cache", {})
	if cache.has(key):
		return float(cache[key])
	var opened: Dictionary = search.get("passage_unexplored", {})
	var size: Vector2i = search.size
	var dist: PackedInt32Array = search.dist
	var blocked: PackedByteArray = search.blocked
	var guard_mask: PackedByteArray = search.guard_mask
	var known := _explored(session, context, LevelRules.level_of(entry))
	var stop_mask: PackedByteArray = search.get("stop_mask", PackedByteArray())
	var pass_mask: PackedByteArray = search.get("pass_mask", PackedByteArray())
	var horizon := int(search.get("radius", -1)) if bool(search.get("capped", false)) else -1
	# Flood out from the guard's zone over open ground the search did not reach,
	# stopping at other guards' zones, one stretch of ground at a time; a
	# stretch that meets a tile where the search stopped for distance is not
	# behind the guard.
	var zone: Array = origin
	var seen := PackedByteArray()
	seen.resize(size.x * size.y)
	for zone_index in zone:
		seen[int(zone_index)] = 1
	var region := []
	var flooded := 0
	for zone_index in zone:
		for start_direction in range(8):
			var sx: int = int(zone_index) % size.x + NEIGHBOR_DX[start_direction]
			var sy: int = int(zone_index) / size.x + NEIGHBOR_DY[start_direction]
			if sx < 0 or sy < 0 or sx >= size.x or sy >= size.y:
				continue
			var start := sy * size.x + sx
			if flooded >= PASSAGE_TILE_CAP or seen[start] != 0 or dist[start] >= 0 or blocked[start] != 0 or guard_mask[start] != 0:
				continue
			seen[start] = 1
			var stretch := [start]
			var head := 0
			var open_to_hero := false
			while head < stretch.size() and flooded < PASSAGE_TILE_CAP and not open_to_hero:
				var tile := int(stretch[head])
				head += 1
				flooded += 1
				var x := tile % size.x
				var y := tile / size.x
				for direction in range(8):
					var nx: int = x + NEIGHBOR_DX[direction]
					var ny: int = y + NEIGHBOR_DY[direction]
					if nx < 0 or ny < 0 or nx >= size.x or ny >= size.y:
						continue
					var next := ny * size.x + nx
					if dist[next] >= 0:
						if horizon >= 0 and dist[next] >= horizon and (stop_mask.is_empty() or stop_mask[next] == 0 or pass_mask[next] != 0):
							open_to_hero = true
						continue
					if seen[next] != 0 or blocked[next] != 0 or guard_mask[next] != 0:
						continue
					seen[next] = 1
					stretch.append(next)
			if not open_to_hero:
				region.append_array(stretch)
	var value := 0.0
	if not region.is_empty():
		var static_stops: Dictionary = search.get("static_stops", {})
		var power := hero_power(entry)
		var unexplored := 0
		var sites := 0.0
		var towns := 0.0
		for tile in region:
			if known[int(tile)] == 0:
				unexplored += 1
				continue
			for ref in static_stops.get(int(tile), []):
				if int(ref.kind) in [STOP_RESOURCE, STOP_ARTIFACT]:
					sites += float(_candidate(session, context, entry, ref, power, needs).get("value", 0.0))
				elif int(ref.kind) == STOP_TOWN:
					towns += float(_candidate(session, context, entry, ref, power, needs).get("value", 0.0))
		value = minf(PASSAGE_VALUE_CAP, PASSAGE_BASE_VALUE + float(unexplored) * PASSAGE_UNEXPLORED_TILE_VALUE + sites * PASSAGE_KNOWN_SITE_SHARE)
		# Towns are worth the fight on their own: they are not held to the cap.
		value += towns * PASSAGE_KNOWN_SITE_SHARE
		# While a rival is still standing whose towns this player has not found,
		# unexplored ground is where they are.
		if unexplored > 0 and _rival_towns_unknown(session, context):
			value += ELIMINATION_VALUE * HIDDEN_RIVAL_SHARE * minf(1.0, float(unexplored) / float(HIDDEN_RIVAL_TILES))
		opened[key] = unexplored
		search["passage_unexplored"] = opened
	# The guard that stands first on the way to a town out of reach opens the
	# road to it, however many guards lie beyond.
	value += float(_war_paths(session, context, entry, search, needs).get(key, 0.0)) * PASSAGE_KNOWN_SITE_SHARE
	cache[key] = value
	search["passage_cache"] = cache
	return value

## For each guard, the value of the most valuable known town (a rival's or a
## neutral one) the hero cannot reach today whose shortest way, walking through
## guard zones as if they were beaten, enters this guard's zone first; a site
## doorway in the way (`_site_doors`) counts as such a guard, under
## `_site_door_key`, and so does a hostile hero, under `_hero_war_key` (a
## doorway in its zone is out of reach until it is beaten). Measured
## once per search. On a medium map the leading player's armies of 5,000 to
## 14,000 spent 60 days collecting weekly sites on their half while the last
## rival's two towns lay a few guards away: no single guard's own ground was
## worth the troops its fight would cost.
static func _war_paths(session: SessionStateStoreScript.SessionData, context: Dictionary, entry: Dictionary, search: Dictionary, needs: Dictionary) -> Dictionary:
	if search.has("war_paths"):
		return search["war_paths"]
	var result := {}
	search["war_paths"] = result
	if not search.has("blocked") or not search.has("guard_zones"):
		return result
	var size: Vector2i = search.size
	var count := size.x * size.y
	var dist: PackedInt32Array = search.dist
	var blocked: PackedByteArray = search.blocked
	var level := LevelRules.level_of(entry)
	var known := _explored(session, context, level)
	var power := hero_power(entry)
	# Doors of known towns out of reach, with what each is worth to this hero.
	var targets := {}
	var towns: Array = session.overworld.get("towns", [])
	for index in range(towns.size()):
		var town = towns[index]
		if not (town is Dictionary) or LevelRules.level_of(town) != level:
			continue
		var entrance := LevelRules.town_entrance(town)
		var door := int(entrance.get("y", 0)) * size.x + int(entrance.get("x", 0))
		# A doorway in a hostile hero's zone is reached through that fight.
		if door < 0 or door >= count or (dist[door] >= 0 and not _in_hero_zone(search, door)) or not _town_seen(known, town, size):
			continue
		var value := float(_town_candidate(session, context, entry, index, power).get("value", 0.0))
		if value > 0.0:
			targets[door] = maxf(float(targets.get(door, 0.0)), value)
	# A gate out of reach that starts a main or field army's way to a town or
	# to unseen ground on other stretches (`_gate_routes`).
	if _plans_far(session, context, entry):
		var movement_max := maxi(1, int(entry.get(AI_HERO_KEY, {}).get("movement", {}).get("max", 1)))
		var routes := _gate_routes(session, context, entry, search, movement_max)
		for gate_tile in routes.keys():
			if int(gate_tile) < count and dist[int(gate_tile)] < 0:
				targets[int(gate_tile)] = maxf(float(targets.get(int(gate_tile), 0.0)), float(routes[gate_tile].value))
	if targets.is_empty():
		return result
	var guard_at := {}
	var zones: Dictionary = search.guard_zones
	for guard_index in zones.keys():
		for tile in zones[guard_index]:
			guard_at[int(tile)] = int(guard_index)
	for door in _site_doors(search).keys():
		guard_at[int(door)] = _site_door_key(int(door))
	# A hostile hero in the way is fought there like a guard, under
	# `_hero_war_key`.
	for hero_guard in _hero_guards(session, context, level):
		if not bool(hero_guard.hostile):
			continue
		var hero_key := _hero_war_key(String(hero_guard.ref_kind), int(hero_guard.index))
		var hero_tiles := [hero_guard.tile]
		hero_tiles.append_array(_hero_zone_tiles(session, context, hero_guard.tile, level))
		for zone_tile in hero_tiles:
			var zone_index: int = int(zone_tile.y) * size.x + int(zone_tile.x)
			if zone_index >= 0 and zone_index < count and not guard_at.has(zone_index):
				guard_at[zone_index] = hero_key
	# Breadth-first from everything reachable today; zone tiles are walkable
	# and the first zone entered is carried along. A portal leads on to its
	# exits, as in the search (`_portal_exits`) and in `_level_regions`. Until
	# 2026-10-19 it did not: on a large two-level map (seed ai-match-8934130) a
	# guard standing by a monolith was the way to a route's rival town, got no
	# share of it, and its hero crossed a gate back and forth for five days.
	var portals: Dictionary = _level_surface(session, context, level).get("portals", {})
	var seen_map := _explored(session, context, level) if not portals.is_empty() else PackedByteArray()
	# The walk reads guards, targets and portals by tile.
	var guarded := PackedByteArray()
	guarded.resize(count)
	var guard_key := PackedInt32Array()
	guard_key.resize(count)
	for tile in guard_at.keys():
		if int(tile) >= 0 and int(tile) < count:
			guarded[int(tile)] = 1
			guard_key[int(tile)] = int(guard_at[tile])
	var is_target := PackedByteArray()
	is_target.resize(count)
	for tile in targets.keys():
		if int(tile) >= 0 and int(tile) < count:
			is_target[int(tile)] = 1
	var is_portal := PackedByteArray()
	is_portal.resize(count)
	for tile in portals.keys():
		if int(tile) >= 0 and int(tile) < count:
			is_portal[int(tile)] = 1
	var first := PackedInt32Array()
	first.resize(count)
	first.fill(-2)
	var queue := PackedInt32Array()
	queue.resize(count)
	var head := 0
	var tail := 0
	# Every tile the search reached, in tile order: those it queued and the
	# stops where it ended a route (each has a reference there).
	var reached: PackedInt32Array = search.order.slice(0, int(search.order_count))
	for tile in search.stops.keys():
		reached.append(int(tile))
	reached.sort()
	var previous := -1
	for tile in reached:
		if tile == previous:
			continue
		previous = tile
		if guarded[tile] == 0:
			first[tile] = -1
			queue[tail] = tile
			tail += 1
	var found := 0
	var target_count := targets.size()
	var width := size.x
	var height := size.y
	var step_offset := _step_offsets(width)
	while head < tail and found < target_count:
		var current := queue[head]
		head += 1
		var carried_here := first[current]
		var cx := current % width
		var cy := current / width
		var on_edge := cx == 0 or cy == 0 or cx == width - 1 or cy == height - 1
		# The neighbours, then where a portal here leads.
		for direction in range(8):
			if on_edge:
				var nx: int = cx + NEIGHBOR_DX[direction]
				var ny: int = cy + NEIGHBOR_DY[direction]
				if nx < 0 or ny < 0 or nx >= width or ny >= height:
					continue
			var next := current + step_offset[direction]
			if first[next] != -2:
				continue
			if blocked[next] != 0 and guarded[next] == 0 and is_target[next] == 0 and is_portal[next] == 0:
				continue
			var carried := carried_here
			if carried == -1 and guarded[next] != 0:
				carried = guard_key[next]
			first[next] = carried
			if is_target[next] != 0:
				found += 1
				if carried != -1:
					result[carried] = maxf(float(result.get(carried, 0.0)), float(targets[next]))
				continue
			queue[tail] = next
			tail += 1
		if is_portal[current] != 0:
			for exit in _portal_exits(portals[current], seen_map):
				var next := int(exit)
				if first[next] != -2:
					continue
				if blocked[next] != 0 and guarded[next] == 0 and is_target[next] == 0 and is_portal[next] == 0:
					continue
				var carried := carried_here
				if carried == -1 and guarded[next] != 0:
					carried = guard_key[next]
				first[next] = carried
				if is_target[next] != 0:
					found += 1
					if carried != -1:
						result[carried] = maxf(float(result.get(carried, 0.0)), float(targets[next]))
					continue
				queue[tail] = next
				tail += 1
	return result

## What scouting the nearest unexplored ground is worth (see HUNT_EXPLORE_VALUE).
static func _explore_value(session: SessionStateStoreScript.SessionData, context: Dictionary) -> float:
	var ramp := clampf(float(int(session.day) - HUNT_START_DAY) / float(HUNT_FULL_DAY - HUNT_START_DAY), 0.0, 1.0)
	if ramp <= 0.0 or not _rival_towns_unknown(session, context):
		return EXPLORE_VALUE
	return EXPLORE_VALUE + _hunt_value(session, context) * ramp

## What finding a rival's unseen towns is worth: HUNT_EXPLORE_VALUE, or while
## the player is far ahead (`_far_ahead`), what one of its own towns is worth
## on average (`_town_worth`), as an unseen rival town is likely to be. Kept
## for the decision.
static func _hunt_value(session: SessionStateStoreScript.SessionData, context: Dictionary) -> float:
	var far_ahead := _far_ahead(session, context)
	var cache: Dictionary = context.get("decision", {})
	if cache.has("hunt_value"):
		return float(cache["hunt_value"])
	var hunt := HUNT_EXPLORE_VALUE
	if far_ahead:
		var total := 0.0
		var count := 0
		for owned in _turn_rules()._owned_town_entries(session, String(context.controller)):
			total += _town_worth(session, context, owned.get("town", {}))
			count += 1
		if count > 0:
			hunt = maxf(hunt, total / float(count))
	cache["hunt_value"] = hunt
	context["decision"] = cache
	return hunt

## Whether some rival still holds a town this player has never seen.
static func _rival_towns_unknown(session: SessionStateStoreScript.SessionData, context: Dictionary) -> bool:
	var cache: Dictionary = context.get("decision", {})
	if cache.has("rival_towns_unknown"):
		return bool(cache["rival_towns_unknown"])
	var controller := String(context.controller)
	var size: Vector2i = context.map_size
	var result := false
	for town in session.overworld.get("towns", []):
		if not (town is Dictionary):
			continue
		var owner := String(town.get("owner", "neutral"))
		if owner == "neutral":
			continue
		var rival := "player" if owner == "player" else PlayerRules.town_controller_id(town)
		if rival == controller or PlayerRules.allied(session, controller, rival):
			continue
		if not _town_seen(_explored(session, context, LevelRules.level_of(town)), town, size):
			result = true
			break
	cache["rival_towns_unknown"] = result
	context["decision"] = cache
	return result

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
		# Only what the hero takes along and keeps counts: a full army leaves
		# creatures of other kinds behind, and the defence it leaves stays.
		var own_stacks: Array = entry.get("enemy_army", {}).get("stacks", []).duplicate(true)
		var pickup := _garrison_pickup(own_stacks.duplicate(true), town.get("garrison", []).duplicate(true))
		var after: Dictionary = _leave_defense(session, context, town, pickup.stacks, pickup.left, main_id == "" or main_id == String(entry.get("placement_id", "")))
		var gain: float = army_power(after.stacks) - army_power(own_stacks)
		if main_id == "" or main_id == String(entry.get("placement_id", "")) or _decision_field_ids(session, context).has(String(entry.get("placement_id", ""))):
			value = gain * TROOP_VALUE_PER_POWER * 0.5
		elif _ferries_from(session, context, town, main_id):
			value = minf(gain * TROOP_VALUE_PER_POWER * 0.3, MEET_VALUE_CAP)
		else:
			var stacks: Array = entry.get("enemy_army", {}).get("stacks", [])
			if stacks.size() > 1:
				value = (army_power(stacks) - army_power([stacks[_weakest_stack_index(stacks)]])) * TROOP_VALUE_PER_POWER * 0.3
		if _town_threatened(session, context, town) and _would_hold_gate(session, context, entry, town, main_id == String(entry.get("placement_id", "")) or _decision_field_ids(session, context).has(String(entry.get("placement_id", "")))):
			value += maxf(TOWN_BASE_VALUE, _town_worth(session, context, town) * THREAT_KILL_SHARE)
		if value <= 50.0:
			return {}
		return {"kind": "town_own", "id": id, "index": index, "value": value}
	if owner != "neutral" and PlayerRules.allied(session, controller, town_controller if owner == "enemy" else "player"):
		return {}
	var defense := army_power(town.get("garrison", []))
	var defender_index := _town_hero_defender_index(session, town, controller)
	if defender_index >= 0:
		defense += hero_power(session.overworld.encounters[defender_index])
	if owner == "player":
		var force: Dictionary = HeroCommandRulesScript.town_defense_force(session, town)
		defense = army_power(town.get("garrison", [])) + army_power(force.get("hero", {}).get("army", {}).get("stacks", []), force.get("hero", {}))
	if defense > 0.0 and power < defense * TOWN_ATTACK_RATIO:
		return {}
	# A town is worth its income and troops, the human's most of all; a faction
	# with no town left needs one to recruit at all.
	var value := _town_worth(session, context, town) + (2000.0 if owner == "player" else 0.0)
	if _turn_rules()._owned_town_entries(session, controller).is_empty():
		value *= HOMELESS_TOWN_MULTIPLIER
	if owner != "neutral":
		value += ELIMINATION_VALUE / float(maxi(1, _towns_held_by(session, owner, town_controller)))
	return {"kind": "town_hostile" if owner != "neutral" else "town_neutral", "id": id, "index": index, "value": value - _expected_loss_value(power, defense), "fight_power": defense}

static func _player_hero_seen(session: SessionStateStoreScript.SessionData, context: Dictionary, hero: Dictionary) -> bool:
	return _position_seen(session, context, hero.get("position", {}) if hero.get("position", {}) is Dictionary else {})

## Whether one of the player's heroes or towns can see this spot right now.
## A context made for a run of these questions (`_sight_context`) keeps the
## player's heroes, and it or a decision (`_choose_plan`) keeps each one's
## scouting radius, by its place among them, from the first time it is needed.
static func _position_seen(session: SessionStateStoreScript.SessionData, context: Dictionary, position: Dictionary) -> bool:
	var radii = context.get(SCOUT_RADII_KEY)
	var own: Array
	var listed = context.get(SIGHT_HEROES_KEY)
	if listed is Array:
		own = listed
	else:
		own = active_hero_entries(session, String(context.controller))
		if context.has(SIGHT_HEROES_KEY):
			context[SIGHT_HEROES_KEY] = own
	for own_index in range(own.size()):
		var entry: Dictionary = own[own_index]
		if not LevelRules.same_level(entry, position):
			continue
		var radius := -1
		if radii is Dictionary:
			radius = int(radii.get(own_index, -1))
		if radius < 0:
			radius = HeroCommandRulesScript.scouting_radius_for_hero(entry.get("enemy_commander_state", {}))
			if radii is Dictionary:
				radii[own_index] = radius
		if HeroCommandRulesScript.within_scout_radius(int(position.get("x", 0)) - int(entry.get("x", 0)), int(position.get("y", 0)) - int(entry.get("y", 0)), radius):
			return true
	for town in session.overworld.get("towns", []):
		if town is Dictionary and String(town.get("owner", "")) == "enemy" and PlayerRules.town_controller_id(town) == String(context.controller) and LevelRules.same_level(town, position):
			if HeroCommandRulesScript.within_scout_radius(int(position.get("x", 0)) - int(town.get("x", 0)), int(position.get("y", 0)) - int(town.get("y", 0)), TOWN_SIGHT_RADIUS):
				return true
	return false

## A context for a run of `_position_seen` questions during which no hero of
## the player moves or changes: the player's active heroes are listed once and
## each one's scouting radius is worked out once, by its place in that list.
const SCOUT_RADII_KEY := "scout_radii"
const SIGHT_HEROES_KEY := "sight_heroes"

static func _sight_context(controller: String) -> Dictionary:
	return {"controller": controller, SCOUT_RADII_KEY: {}, SIGHT_HEROES_KEY: null}

## Hostile heroes the controller can see, with their strength and reach.
static func _hostile_heroes(session: SessionStateStoreScript.SessionData, controller: String) -> Array:
	var result := []
	var context := _sight_context(controller)
	for hero in session.overworld.get("player_heroes", []):
		if not (hero is Dictionary) or PlayerRules.allied(session, controller, "player"):
			continue
		if not _player_hero_seen(session, context, hero):
			continue
		var position: Dictionary = hero.get("position", {})
		var movement: Dictionary = hero.get("movement", {}) if hero.get("movement", {}) is Dictionary else {}
		result.append({"id": String(hero.get("id", "")), "owner": "player", "x": int(position.get("x", 0)), "y": int(position.get("y", 0)), "level": LevelRules.level_of(position), "power": army_power(hero.get("army", {}).get("stacks", []), hero), "reach": maxi(6, int(movement.get("max", 10)))})
	# Other computer players' heroes threaten towns just as the human's do.
	for entry in active_hero_entries(session):
		var other := PlayerRules.raid_controller_id(entry)
		if other == controller or PlayerRules.allied(session, controller, other):
			continue
		if not _position_seen(session, context, LevelRules.position(entry)):
			continue
		result.append({"id": String(entry.get("placement_id", "")), "owner": other, "x": int(entry.get("x", 0)), "y": int(entry.get("y", 0)), "level": LevelRules.level_of(entry), "power": hero_power(entry), "reach": maxi(6, _movement_max(entry))})
	return result

## Remembers the hostile heroes in sight now (SIGHTINGS_KEY) and forgets those
## not seen for SIGHTING_MEMORY_DAYS.
static func _note_sightings(session: SessionStateStoreScript.SessionData, context: Dictionary) -> void:
	var day := int(session.day)
	var known = context.state.get(SIGHTINGS_KEY, {})
	var kept := {}
	if known is Dictionary:
		for id in known.keys():
			var seen = known[id]
			if seen is Dictionary and int(seen.get("day", -SIGHTING_MEMORY_DAYS)) + SIGHTING_MEMORY_DAYS > day:
				kept[String(id)] = seen
	for hostile in _hostile_heroes(session, String(context.controller)):
		if String(hostile.id) != "":
			kept[String(hostile.id)] = {"owner": String(hostile.owner), "power": snappedf(float(hostile.power), 0.1), "day": day}
	context.state[SIGHTINGS_KEY] = kept

## A hero this player has beaten is no longer out there.
static func _forget_sighting(context: Dictionary, id: String) -> void:
	var known = context.state.get(SIGHTINGS_KEY, {})
	if known is Dictionary and known.has(id):
		known.erase(id)

## Whether the player has found a rival's town and its main army beats all it
## knows of any one rival together by HERO_ATTACK_RATIO: the heroes it
## remembers (SIGHTINGS_KEY) and the garrisons of the rival's towns it has
## seen. Kept for the decision.
static func _far_ahead(session: SessionStateStoreScript.SessionData, context: Dictionary) -> bool:
	var main_id := _decision_main_id(session, context)
	var cache: Dictionary = context.get("decision", {})
	if cache.has("far_ahead"):
		return bool(cache["far_ahead"])
	var main_index := _entry_index(session, main_id)
	var main_power := hero_power(session.overworld.encounters[main_index]) if main_index >= 0 else 0.0
	var known := {}
	var memory = context.state.get(SIGHTINGS_KEY, {})
	if memory is Dictionary:
		for id in memory.keys():
			var seen = memory[id]
			if seen is Dictionary:
				var owner := String(seen.get("owner", ""))
				known[owner] = float(known.get(owner, 0.0)) + float(seen.get("power", 0.0))
	var controller := String(context.controller)
	var size: Vector2i = context.map_size
	var town_found := false
	for town in session.overworld.get("towns", []):
		if not (town is Dictionary) or String(town.get("owner", "neutral")) == "neutral":
			continue
		var rival := "player" if String(town.get("owner", "")) == "player" else PlayerRules.town_controller_id(town)
		if rival == controller or PlayerRules.allied(session, controller, rival):
			continue
		if _town_seen(_explored(session, context, LevelRules.level_of(town)), town, size):
			town_found = true
			known[rival] = float(known.get(rival, 0.0)) + army_power(town.get("garrison", []))
	var strongest := 0.0
	for rival in known.keys():
		strongest = maxf(strongest, float(known[rival]))
	cache["far_ahead"] = town_found and main_power > strongest * HERO_ATTACK_RATIO
	context["decision"] = cache
	return bool(cache["far_ahead"])

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

## Whether this player has seen the town: its anchor tile or its doorway. Every
## check that asks whether a town is known uses this. Until 2026-10-17 the
## scouting check (`_rival_towns_unknown`) tested the anchor and the planners the
## doorway, so a rival town whose anchor was seen from one side and whose door
## lay out of sight was neither scouted for nor attacked: on a 6-player large map
## (seed ai-match-1305188145) the last rival's town stood 280 days against a main
## army that grew to 320,000, reachable and worth 273,000 to it.
static func _town_seen(known: PackedByteArray, town: Dictionary, size: Vector2i) -> bool:
	var entrance := LevelRules.town_entrance(town)
	for tile in [Vector2i(int(town.get("x", -1)), int(town.get("y", -1))), Vector2i(int(entrance.get("x", -1)), int(entrance.get("y", -1)))]:
		var index: int = tile.y * size.x + tile.x
		if tile.x >= 0 and tile.y >= 0 and tile.x < size.x and tile.y < size.y and index < known.size() and known[index] != 0:
			return true
	return false

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
	var rerouted := false
	var sailing := WaterTravel.hero_boat_id(entry) != ""
	for step_index in range(path.size()):
		if int(movement.get("current", 0)) <= 0:
			break
		var tile: Vector2i = path[step_index]
		movement["current"] = int(movement.get("current", 0)) - 1
		if step_index == last and _tile_blocked_for_standing(session, context, tile, level, String(entry.get("placement_id", ""))):
			arrived = true
			break
		var before := LevelRules.position(entry)
		# Boarding a boat or stepping ashore ends the day's movement.
		var shore := WaterTravel.is_water(session, tile.x, tile.y, level) != sailing
		if shore:
			if not _cross_shore(session, context, entry, tile, level):
				movement["current"] = int(movement.get("current", 0)) + 1
				break
			plan.erase("retreat_tile")
		else:
			plan["retreat_tile"] = Vector2i(int(before.get("x", 0)), int(before.get("y", 0)))
		var through := {} if shore else _portal_step(session, context, entry, tile, level)
		var landed: Vector2i = through.get("exit", tile)
		entry["x"] = landed.x
		entry["y"] = landed.y
		if WaterTravel.hero_boat_id(entry) != "":
			WaterTravel.place_boat(session, WaterTravel.hero_boat_id(entry), String(entry.get("placement_id", "")), landed, level)
		TurnPlayback.move(session, entry, before)
		_reveal(session, context, LevelRules.position(entry), _sight_radius(entry))
		# Next to a hostile hero the walk ends in a fight with it, whatever the
		# hero set out to do (a portal can put it there unplanned).
		var beside := _hostile_hero_beside(session, context, landed, level)
		if not beside.is_empty():
			if String(beside.kind) != String(plan.get("kind", "")) or int(beside.index) != int(plan.get("index", -1)):
				plan = beside
			arrived = true
			break
		if shore:
			sailing = not sailing
			movement["current"] = 0
			arrived = step_index == last
			break
		if landed != tile:
			# A random portal sent the hero elsewhere: it plans again from there.
			rerouted = true
			break
		if step_index == last:
			arrived = true
	# A hero that came to scout a portal steps through it to see where it leads.
	if arrived and String(plan.get("kind", "")) == "explore" and int(movement.get("current", 0)) > 0:
		var scouted := _portal_step(session, context, entry, Vector2i(-1000, -1000), level)
		if scouted.has("exit"):
			var before := LevelRules.position(entry)
			movement["current"] = int(movement.get("current", 0)) - 1
			entry["x"] = scouted.exit.x
			entry["y"] = scouted.exit.y
			TurnPlayback.move(session, entry, before)
			_reveal(session, context, LevelRules.position(entry), _sight_radius(entry))
			rerouted = true
			arrived = false
			var ambushed := _hostile_hero_beside(session, context, scouted.exit, level)
			if not ambushed.is_empty():
				plan = ambushed
				rerouted = false
				arrived = true
	block["movement"] = movement
	entry[AI_HERO_KEY] = block
	_store_entry(session, index, entry)
	_overworld_rules().invalidate_spatial_lookup(session)
	if not arrived:
		return {"arrived": false, "rerouted": rerouted}
	return _interact(session, context, index, plan)

## Boards the boat at this water tile (a free one, or one the shipyard the hero
## stands at builds for it) or, aboard, steps ashore and leaves the boat moored
## where the hero was. False when there is no boat to take.
static func _cross_shore(session: SessionStateStoreScript.SessionData, context: Dictionary, entry: Dictionary, tile: Vector2i, level: int) -> bool:
	var boat_id := WaterTravel.hero_boat_id(entry)
	if boat_id != "":
		WaterTravel.place_boat(session, boat_id, "", Vector2i(int(entry.get("x", 0)), int(entry.get("y", 0))), level)
		entry.erase(WaterTravel.HERO_BOAT_KEY)
		return true
	var boat := WaterTravel.free_boat_at(session, tile, level)
	if boat.is_empty():
		boat = _launch_boat(session, context, entry, tile, level)
	if boat.is_empty():
		return false
	WaterTravel.place_boat(session, String(boat.get("id", "")), String(entry.get("placement_id", "")), tile, level)
	entry[WaterTravel.HERO_BOAT_KEY] = String(boat.get("id", ""))
	return true

## The shipyard the hero stands at builds a boat at its dock (this tile) for
## the human's price, paid from the player's treasury after any trades at one
## of its towns' markets (`_boat_market`).
static func _launch_boat(session: SessionStateStoreScript.SessionData, context: Dictionary, entry: Dictionary, tile: Vector2i, level: int) -> Dictionary:
	var size: Vector2i = context.map_size
	var surface := _level_surface(session, context, level)
	var yard: Dictionary = surface.get("shipyards", {}).get(_tile_index_of(entry, size), {})
	if yard.is_empty() or int(yard.dock) != tile.y * size.x + tile.x:
		return {}
	var cost: Dictionary = surface.get("boat_cost", {})
	var treasury: Dictionary = context.state.treasury
	var market := _boat_market(session, context, cost)
	if market.is_empty():
		return {}
	var nodes: Array = session.overworld.get("resource_nodes", [])
	if int(yard.node) >= nodes.size() or WaterTravel.dock_blocker(session, nodes[int(yard.node)]) != "":
		return {}
	if market.has("town_index"):
		var towns: Array = session.overworld.get("towns", [])
		var town: Dictionary = towns[int(market.town_index)]
		if not _market_cover(session, town, treasury, cost, true):
			return {}
		towns[int(market.town_index)] = town
		session.overworld["towns"] = towns
	if WaterTravel.build_boat(session, nodes[int(yard.node)]) != "":
		return {}
	_turn_rules()._spend_from_pool(treasury, cost)
	_economy_add(session, String(context.controller), "boat_gold", float(cost.get("gold", 0)))
	TurnPlayback.action(session, entry, "builds a boat")
	return WaterTravel.free_boat_at(session, tile, level)

## How the player pays for a boat now: {"treasury": true} from the treasury,
## {"town_index": i} with trades at that town's market first (as the human
## trades from any of its towns), {} when it cannot. Kept per treasury state
## for the turn.
static func _boat_market(session: SessionStateStoreScript.SessionData, context: Dictionary, cost: Dictionary) -> Dictionary:
	var state: Variant = context.get("state", {})
	var treasury: Dictionary = state.get("treasury", {}) if state is Dictionary else {}
	if cost.is_empty():
		return {}
	if _can_afford(treasury, cost):
		return {"treasury": true}
	var cache: Dictionary = context.get("boat_market", {})
	var key := treasury.hash()
	if cache.has(key):
		return cache[key]
	var found := {}
	for entry in _turn_rules()._owned_town_entries(session, String(context.get("controller", ""))):
		var town: Dictionary = entry.get("town", {})
		if _market_cover(session, town, treasury, cost, false):
			found = {"town_index": int(entry.get("index", -1))}
			break
	cache[key] = found
	context["boat_market"] = cache
	return found

## A main or field army with nothing to do (no errand, or only waiting) while
## a shipyard is in reach and the player cannot pay for a boat marks the day:
## the towns then save the boat's price (`_govern_towns`).
static func _note_boat_need(session: SessionStateStoreScript.SessionData, context: Dictionary, entry: Dictionary) -> void:
	if int(context.state.get(BOAT_WANTED_KEY, -1000)) == int(session.day) or WaterTravel.hero_boat_id(entry) != "":
		return
	if not _plans_far(session, context, entry):
		return
	var surface := _level_surface(session, context, LevelRules.level_of(entry))
	var shipyards: Dictionary = surface.get("shipyards", {})
	if shipyards.is_empty() or not _boat_market(session, context, surface.get("boat_cost", {})).is_empty():
		return
	var search := _search(session, context, entry, _movement_max(entry) * FAR_SEARCH_DAYS)
	for visit_index in shipyards.keys():
		if int(search.dist[int(visit_index)]) >= 0:
			context.state[BOAT_WANTED_KEY] = int(session.day)
			return

## A step from a portal's entrance to a tile that is not next to it goes
## through the portal. A network with several exits rolls the exit with the
## human's rule (`native_random_exit_check`, keyed by portal, day, traveller and
## trip); returns the tile the hero comes out on as "exit" when that differs
## from the planned one.
static func _portal_step(session: SessionStateStoreScript.SessionData, context: Dictionary, entry: Dictionary, tile: Vector2i, level: int) -> Dictionary:
	var here := Vector2i(int(entry.get("x", 0)), int(entry.get("y", 0)))
	if maxi(absi(tile.x - here.x), absi(tile.y - here.y)) <= 1:
		return {}
	var size: Vector2i = context.map_size
	var portals: Dictionary = _level_surface(session, context, level).get("portals", {})
	var portal: Dictionary = portals.get(here.y * size.x + here.x, {})
	if portal.is_empty():
		return {}
	if (portal.exits as PackedInt32Array).size() < 2:
		# A fixed portal leads where the route says; scouting one, it leads to
		# its single exit.
		if tile.x < 0:
			var only: int = (portal.exits as PackedInt32Array)[0]
			return {"exit": Vector2i(only % size.x, only / size.x)}
		return {}
	var nodes: Array = session.overworld.get("resource_nodes", [])
	var node: Dictionary = nodes[int(portal.node)] if int(portal.node) < nodes.size() else {}
	var actor_id := String(entry.get("placement_id", ""))
	var check: Dictionary = _overworld_rules().native_random_exit_check(session, node, Vector3i(here.x, here.y, level), actor_id)
	if not bool(check.get("ok", false)):
		return {}
	_overworld_rules().note_native_trip(session, actor_id)
	var exit: Vector3i = check.get("exit", Vector3i(tile.x, tile.y, level))
	return {"exit": Vector2i(exit.x, exit.y)}

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

## Every hero standing on this level, the human's and the computer players',
## and whether it is hostile to the player whose turn it is.
static func _hero_guards(session: SessionStateStoreScript.SessionData, context: Dictionary, level: int) -> Array:
	var controller := String(context.controller)
	var guards := []
	var human_hostile := not PlayerRules.allied(session, controller, "player")
	var heroes: Array = session.overworld.get("player_heroes", [])
	for index in range(heroes.size()):
		var hero = heroes[index]
		var position: Dictionary = hero.get("position", {}) if hero is Dictionary and hero.get("position", {}) is Dictionary else {}
		if position.is_empty() or LevelRules.level_of(position) != level:
			continue
		guards.append({"tile": Vector2i(int(position.get("x", -1)), int(position.get("y", -1))), "ref_kind": "hero", "index": index, "id": String(hero.get("id", "")), "hostile": human_hostile})
	var encounters: Array = session.overworld.get("encounters", [])
	var resolved := _resolved_lookup(session)
	for index in range(encounters.size()):
		var other = encounters[index]
		if not (other is Dictionary) or not (other.get(AI_HERO_KEY, null) is Dictionary) or LevelRules.level_of(other) != level or resolved.has(String(other.get("placement_id", ""))):
			continue
		var other_controller := PlayerRules.raid_controller_id(other)
		var hostile := other_controller != controller and not PlayerRules.allied(session, controller, other_controller)
		guards.append({"tile": Vector2i(int(other.get("x", -1)), int(other.get("y", -1))), "ref_kind": "ai_hero", "index": index, "id": String(other.get("placement_id", "")), "hostile": hostile})
	return guards

## The tiles a hero standing here guards; terrain and towns do not change
## during a turn, so each answer is kept for the turn.
static func _hero_zone_tiles(session: SessionStateStoreScript.SessionData, context: Dictionary, tile: Vector2i, level: int) -> Array:
	var cache: Dictionary = context.get("hero_zone_tiles", {})
	var key := "%d:%d,%d" % [level, tile.x, tile.y]
	if not cache.has(key):
		cache[key] = _overworld_rules().hero_guard_zone_tiles(session, tile, level)
		context["hero_zone_tiles"] = cache
	return cache[key]

## The hostile hero whose zone this tile lies in, as a plan to fight it: a hero
## that steps next to one fights it there, as the human does.
static func _hostile_hero_beside(session: SessionStateStoreScript.SessionData, context: Dictionary, tile: Vector2i, level: int) -> Dictionary:
	for guard in _hero_guards(session, context, level):
		if not bool(guard.hostile) or maxi(absi(guard.tile.x - tile.x), absi(guard.tile.y - tile.y)) != 1:
			continue
		if _hero_zone_tiles(session, context, guard.tile, level).has(tile):
			return {"kind": String(guard.ref_kind), "id": String(guard.id), "index": int(guard.index)}
	return {}

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
	var water := PackedByteArray()
	water.resize(size.x * size.y)
	var water_count := 0
	# Per terrain id: [passable, water].
	var terrain_kinds := {}
	var rows: Array = LevelRules.terrain_rows(session, level)
	for y in range(size.y):
		var row: Array = rows[y] if y < rows.size() and rows[y] is Array else []
		for x in range(size.x):
			if x >= row.size():
				blocked[y * size.x + x] = 1
				continue
			var terrain := String(row[x])
			var kind = terrain_kinds.get(terrain)
			if kind == null:
				kind = [overworld_rules.terrain_id_is_passable(terrain), ContentService.normalize_terrain_id(terrain) == "water"]
				terrain_kinds[terrain] = kind
			if not bool(kind[0]):
				blocked[y * size.x + x] = 1
			if bool(kind[1]):
				water[y * size.x + x] = 1
				water_count += 1
	# Open water a boat sails over: water without an object's body on it.
	var sea := water.duplicate()
	# Armies move and are added for each search: every army body on the level is
	# left out of the static bodies, so the index skips all encounters.
	var army_tiles := {}
	var every_encounter := {}
	for encounter in session.overworld.get("encounters", []):
		if not (encounter is Dictionary):
			continue
		every_encounter[overworld_rules.encounter_key(encounter)] = true
		if LevelRules.level_of(encounter) == level:
			for tile in overworld_rules._generated_body_tiles_for_placement(encounter, bool(encounter.get("blocking_body", true))):
				army_tiles[overworld_rules._tile_key(tile)] = true
	var bodies: Dictionary = overworld_rules._build_blocked_tile_index(session, level, "", every_encounter)
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
			sea[y * size.x + x] = 0
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
		neutrals.append({"id": String(encounter.get("placement_id", "")), "index": index, "body": body, "zone": zone, "ref": {"kind": STOP_ENCOUNTER, "index": index}})
	# Portals on this level, by entrance tile: their exits on this level and the
	# portal node. Stepping in comes out at an exit, as for the human; a network
	# with several exits sends the hero to a random one (`_search` plans with the
	# exits this player has seen). Until 2026-10-09 heroes could not use portals
	# at all, and on medium maps whose halves meet only at a Wayring pair two
	# players never met: one side held 38,000 strength and five towns for 70
	# days without reaching the other. Random networks followed on 2026-10-09:
	# a large map whose start region opened only through them kept its player
	# out of everyone's reach.
	var portals := {}
	for index in range(resources.size()):
		var node = resources[index]
		if not (node is Dictionary) or LevelRules.level_of(node) != level or not NativeTransit.is_native(node):
			continue
		if NativeTransit.portal_kind(node) not in ["two_way_portal", "one_way_entrance"]:
			continue
		var exits := PackedInt32Array()
		for option in NativeTransit.destinations(node):
			var exit := NativeTransit.point(option.get("exit", {}))
			if exit.z == level and exit.x >= 0 and exit.y >= 0 and exit.x < size.x and exit.y < size.y:
				exits.append(exit.y * size.x + exit.x)
		if exits.is_empty():
			continue
		var map_object: Dictionary = overworld_rules._map_object_for_resource_node(node)
		for tile in overworld_rules._resource_node_world_interaction_tiles(map_object, node):
			if tile is Vector2i and tile.x >= 0 and tile.y >= 0 and tile.x < size.x and tile.y < size.y:
				portals[tile.y * size.x + tile.x] = {"exits": exits, "node": index}
	# Subterranean gates on this level, by entrance tile, with the tile on the
	# other level a hero comes out on (`_gate_candidate`). The search stays on
	# one level; a gate ends a route like any site. A portal whose one exit is
	# on the other level is such a gate too. Until 2026-10-17 heroes never used
	# one: on two-level maps whose start region opened only through a monolith
	# to the underground, its player stayed shut in and its rivals never came
	# (seeds ai-match-1520175333 and ai-match-113824639, both to the 320-day cap).
	var gates := {}
	for index in range(resources.size()):
		var node = resources[index]
		if not (node is Dictionary) or LevelRules.level_of(node) != level or not NativeTransit.is_native(node):
			continue
		var link := NativeTransit.link_of(node)
		var options := NativeTransit.destinations(node)
		if String(link.get("kind", "")) != "paired_cave" and not (NativeTransit.portal_kind(node) in ["two_way_portal", "one_way_entrance"] and options.size() == 1):
			continue
		var entrance := NativeTransit.point(link.get("entry", {}))
		var exit := NativeTransit.point(options[0].get("exit", {}) if not options.is_empty() else link.get("exit", {}))
		if entrance.z != level or exit.z == level or exit.z < 0 or exit.x < 0 or exit.y < 0 or exit.x >= size.x or exit.y >= size.y:
			continue
		if entrance.x >= 0 and entrance.y >= 0 and entrance.x < size.x and entrance.y < size.y:
			gates[entrance.y * size.x + entrance.x] = {"node": index, "exit": exit}
	# Shipyards on this level, by visit tile, with the dock where the boat they
	# build is launched (`WaterTravelRules.dock_tile`).
	var shipyards := {}
	if water_count > 0:
		for index in range(resources.size()):
			var node = resources[index]
			if not (node is Dictionary) or LevelRules.level_of(node) != level or String(node.get("site_id", "")) != WaterTravel.SHIPYARD_SITE_ID:
				continue
			var dock := WaterTravel.dock_tile(session, node)
			if dock.is_empty():
				continue
			var map_object: Dictionary = overworld_rules._map_object_for_resource_node(node)
			for tile in overworld_rules._resource_node_world_interaction_tiles(map_object, node):
				if tile is Vector2i and tile.x >= 0 and tile.y >= 0 and tile.x < size.x and tile.y < size.y:
					shipyards[tile.y * size.x + tile.x] = {"node": index, "dock": int(dock.y) * size.x + int(dock.x)}
	var surface := {
		"blocked": blocked, "stops": stops, "stop_mask": stop_mask, "site_stops": site_stops, "neutrals": neutrals, "portals": portals, "gates": gates,
		"water": water, "water_count": water_count, "sea": sea, "shipyards": shipyards,
		"boat_cost": VisitBuildings.cost(ContentService.get_resource_site(WaterTravel.SHIPYARD_SITE_ID), "build_boat"),
	}
	levels[level] = surface
	_profile_add(context, "surface_ms", surface_started)
	return surface

## Each neutral army's zone (by its place in surface.neutrals) without the
## tiles no one can stand on: rock or an object's body, unless a doorway or visit
## tile is there or it is water. Kept with the surface until a claim opens a body
## (`_clear_static_body`).
static func _open_guard_zones(surface: Dictionary) -> Array:
	if surface.has("open_zones"):
		return surface["open_zones"]
	var blocked: PackedByteArray = surface.blocked
	var water: PackedByteArray = surface.get("water", PackedByteArray())
	var static_stops: Dictionary = surface.stops
	var zones := []
	for record in surface.neutrals:
		var zone := []
		for zone_index in record.zone:
			# Rock or an object's body inside the zone is no place to stand, as
			# for the human; only a doorway or visit tile there can be entered.
			var tile := int(zone_index)
			if blocked[tile] != 0 and not static_stops.has(tile) and not (tile < water.size() and water[tile] != 0):
				continue
			zone.append(tile)
		zones.append(zone)
	surface["open_zones"] = zones
	return zones

## Where a portal can take a hero, as far as its player knows: the one exit of a
## fixed portal; for a network with several exits (one picked at random, as for
## the human) the exits on ground this player has seen, which the network's
## colour tells apart on the map. The route is planned as if the hero came out
## at the right one; where it does not, the hero plans again from where it is.
static func _portal_exits(portal: Dictionary, seen_map: PackedByteArray) -> PackedInt32Array:
	var exits: PackedInt32Array = portal.exits
	if exits.size() == 1:
		return exits
	var known := PackedInt32Array()
	for exit in exits:
		if exit < seen_map.size() and seen_map[exit] != 0:
			known.append(exit)
	return known

## Whether this portal has an exit the player has not seen: stepping in shows
## where it leads, as a human scouts an unknown monolith.
static func _portal_leads_unseen(portal: Dictionary, seen_map: PackedByteArray) -> bool:
	for exit in portal.exits:
		if exit >= seen_map.size() or seen_map[exit] == 0:
			return true
	return false

## Whether a hero may cross this site's tile without stopping: the pickup is
## gone, the one-time site is looted, or the site is already this player's (or
## an ally's). The caller runs _sync_site_pass_memo first and passes the
## session's resource and artifact nodes, and `allies`, where whether each
## owner is allied to the controller is kept while nothing changes.
static func _site_stop_passable(session: SessionStateStoreScript.SessionData, controller: String, ref: Dictionary, nodes: Array, artifacts: Array, allies: Dictionary) -> bool:
	match int(ref.kind):
		STOP_ARTIFACT:
			var artifact = artifacts[int(ref.index)] if int(ref.index) < artifacts.size() else {}
			return artifact is Dictionary and bool(artifact.get("collected", false))
		STOP_RESOURCE:
			var node = nodes[int(ref.index)] if int(ref.index) < nodes.size() else {}
			if not (node is Dictionary) or NativeTransit.is_native(node):
				return false
			var site_class := _site_pass_class(String(node.get("site_id", "")))
			if not bool(site_class[SITE_PASS_KNOWN]):
				return false
			# A building a hero visits and leaves standing (a shrine, a school, a
			# roadside producer) can be crossed on the way elsewhere; the hero may
			# still stop there to visit. Otherwise a pocket whose only way out ran
			# over such a doorway trapped the hero that entered it.
			if bool(site_class[SITE_PASS_WALK_ACROSS]):
				return true
			# A collected pickup is gone. A looted one-time site that stays
			# standing (a guarded bank) holds nothing for anyone: whoever looted it
			# does not own it. Until 2026-10-17 only the looter crossed it, and a
			# rival whose one way out ran over it stood idle for 250 days (seed
			# ai-match-2298949441).
			if bool(node.get("collected", false)) and not bool(site_class[SITE_PASS_KEPT]):
				return true
			var owner := PlayerRules.resource_controller_id(node)
			if owner == "":
				return false
			if not allies.has(owner):
				allies[owner] = PlayerRules.allied(session, controller, owner)
			return bool(allies[owner])
	return false

## What a resource site's content row says about crossing it, by site id:
## [known site, walk-across family, persistent or repeatable]. Searches check
## every site stop on every search, so the rows are read once and the memo is
## dropped whenever the content cache reloads. A node's payload never changes
## these keys (ResourceNodePayloadRules.site_for_node).
const SITE_PASS_KNOWN := 0
const SITE_PASS_WALK_ACROSS := 1
const SITE_PASS_KEPT := 2
static var _site_pass_memo := {}
static var _site_pass_sources := []

## The decision's record of which site stops on this level are open
## (`_choose_plan`), shared by every search of the decision; empty outside a
## decision. Kept with the level's site list it was made for.
const SITE_PASS_DECISION_KEY := "decision_site_pass"

static func _decision_site_pass(context: Dictionary, level: int, sites: Array) -> PackedByteArray:
	var by_level = context.get(SITE_PASS_DECISION_KEY)
	if not (by_level is Dictionary):
		return PackedByteArray()
	var record: Dictionary = by_level.get(level, {})
	if record.is_empty() or not is_same(record.sites, sites):
		var open := PackedByteArray()
		open.resize(sites.size())
		record = {"sites": sites, "open": open}
		by_level[level] = record
	return record.open

static func _sync_site_pass_memo() -> void:
	var sources := [ContentService.get_content_revision(), ContentService.load_json(ContentService.RESOURCE_SITES_PATH)]
	if _site_pass_sources.size() != sources.size() or _site_pass_sources[0] != sources[0] or not is_same(_site_pass_sources[1], sources[1]):
		_site_pass_memo = {}
		_site_pass_sources = sources

static func _site_pass_class(site_id: String) -> Array:
	var site_class = _site_pass_memo.get(site_id)
	if site_class == null:
		var site := ContentService.get_resource_site(site_id)
		var overworld_rules = _overworld_rules()
		site_class = [
			not site.is_empty(),
			String(site.get("family", "")) in WALK_ACROSS_SITE_FAMILIES,
			overworld_rules._resource_site_is_persistent(site) or overworld_rules._resource_site_is_repeatable(site),
		]
		_site_pass_memo[site_id] = site_class
	return site_class

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
	var surface_blocked: PackedByteArray = surface.blocked
	var water: PackedByteArray = surface.get("water", PackedByteArray())
	var neutrals: Array = surface.neutrals
	var open_zones := _open_guard_zones(surface)
	for record_position in range(neutrals.size()):
		var record: Dictionary = neutrals[record_position]
		if resolved.has(String(record.id)):
			continue
		for body_index in record.body:
			blocked[int(body_index)] = 1
			army_tiles[int(body_index)] = true
		var zone: Array = open_zones[record_position]
		var zone_ref: Dictionary = record.ref
		for zone_index in zone:
			stop_mask[zone_index] = 1
			guard_mask[zone_index] = 1
			if dynamic_stops.has(zone_index):
				dynamic_stops[zone_index].append(zone_ref)
			else:
				dynamic_stops[zone_index] = [zone_ref]
		guard_zones[int(record.index)] = zone
	for index in range(encounters.size()):
		var other = encounters[index]
		if not (other is Dictionary):
			continue
		var other_controller := PlayerRules.raid_controller_id(other)
		if other_controller == "" or LevelRules.level_of(other) != level:
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
	# Heroes guard the tiles around them (OverworldRules.hero_guard_zone_tiles):
	# stepping next to a hostile hero means fighting it, so its zone ends a
	# route like a neutral army's and is never walked through.
	var hero_zone := PackedByteArray()
	hero_zone.resize(count)
	var guards := _hero_guards(session, context, level)
	var hero_tiles := {}
	for guard in guards:
		hero_tiles[guard.tile.y * width + guard.tile.x] = true
	for guard in guards:
		if not bool(guard.hostile):
			continue
		var ref := {"kind": STOP_HERO if String(guard.ref_kind) == "hero" else STOP_AI_HERO, "index": int(guard.index), "zone": true}
		for tile in _hero_zone_tiles(session, context, guard.tile, level):
			var zone_index: int = tile.y * width + tile.x
			if hero_tiles.has(zone_index) or army_tiles.has(zone_index) or (surface_blocked[zone_index] != 0 and not static_stops.has(zone_index) and not (zone_index < water.size() and water[zone_index] != 0)):
				continue
			hero_zone[zone_index] = 1
			stop_mask[zone_index] = 1
			_add_stop_index(dynamic_stops, zone_index, ref)
	var pass_mask := PackedByteArray()
	pass_mask.resize(count)
	_sync_site_pass_memo()
	var resource_nodes: Array = session.overworld.get("resource_nodes", [])
	var artifact_nodes: Array = session.overworld.get("artifact_nodes", [])
	var site_allies := {}
	var sites: Array = surface.get("site_stops", [])
	# Per site: 0 not yet known this decision, 1 open, 2 closed.
	var site_open := _decision_site_pass(context, level, sites)
	var shared := not site_open.is_empty()
	for site_position in range(sites.size()):
		var site: Dictionary = sites[site_position]
		var site_tile := int(site.tile)
		if dynamic_stops.has(site_tile) or army_tiles.has(site_tile):
			continue
		var open := true
		if shared and site_open[site_position] != 0:
			open = site_open[site_position] == 1
		else:
			for ref in site.refs:
				if not _site_stop_passable(session, controller, ref, resource_nodes, artifact_nodes, site_allies):
					open = false
					break
			if shared:
				site_open[site_position] = 1 if open else 2
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
	# Water, as for the human (WaterTravelRules): a walking hero steps onto a
	# free boat, or onto the boat a shipyard it stands at builds, and sails;
	# a sailing hero moves over open water (never through another boat) and
	# steps ashore onto open ground or a doorway. Boarding and going ashore each
	# end the day, so they count `SHORE_STEP_SHARE` of a day more, and a route
	# boards once. Phase per tile: 0 walking, 1 sailing, 2 ashore again, plus
	# BOUGHT_BOAT when the route buys its boat at a shipyard (`_boat_price`).
	var has_water := int(surface.get("water_count", 0)) > 0
	var phase := PackedByteArray()
	var sea_open := PackedByteArray()
	var boat_tiles := {}
	var docks := {}
	var shore_cost := 0
	var dock_cost := 0
	# Steps that board or go ashore, held back until the search reaches their
	# distance: [distance, tile, parent, phase], in distance order.
	var deferred := []
	var deferred_head := 0
	if has_water:
		phase.resize(count)
		sea_open = surface.sea.duplicate()
		for army_index in army_tiles.keys():
			sea_open[int(army_index)] = 0
		for boat in WaterTravel.boats(session):
			if not (boat is Dictionary) or int(boat.get("level", 0)) != level:
				continue
			var boat_index := _tile_index_of(boat, size)
			if boat_index < 0:
				continue
			sea_open[boat_index] = 0
			if String(boat.get("hero_id", "")) == "":
				boat_tiles[boat_index] = true
		if WaterTravel.hero_boat_id(entry) != "" and water[start_index] != 0:
			phase[start_index] = 1
		else:
			if not surface.get("shipyards", {}).is_empty() and not _boat_market(session, context, surface.get("boat_cost", {})).is_empty():
				for visit_index in surface.get("shipyards", {}).keys():
					var dock := int(surface.shipyards[visit_index].dock)
					if sea_open[dock] != 0 and not dynamic_stops.has(dock):
						docks[int(visit_index)] = dock
		var movement_max := _movement_max(entry)
		shore_cost = maxi(1, int(round(float(movement_max) * SHORE_STEP_SHARE)))
		dock_cost = shore_cost + movement_max
	dist[start_index] = 0
	var queue := PackedInt32Array()
	queue.resize(count)
	var head := 0
	var tail := 1
	queue[0] = start_index
	var native_corners := NativeTransit.uses_native_adjacency(session)
	var portals: Dictionary = surface.get("portals", {})
	var seen_map := _explored(session, context, level) if not portals.is_empty() else PackedByteArray()
	var height := size.y
	var step_offset := _step_offsets(width)
	# A hero that stopped on a portal goes through it first thing.
	var reached := []
	if portals.has(start_index):
		for start_exit in _portal_exits(portals[start_index], seen_map):
			if dist[start_exit] < 0:
				dist[start_exit] = 1
				parent[start_exit] = start_index
				# An exit beside a hostile hero is as far as the hero gets.
				if hero_zone[start_exit] != 0:
					reached.append(start_exit)
					continue
				queue[tail] = start_exit
				tail += 1
	# Whether the radius cut the search short: if not, it reached every tile the
	# hero can walk to.
	var capped := false
	while head < tail or deferred_head < deferred.size():
		if deferred_head < deferred.size():
			# A held-back step joins the queue once the search has come within
			# one step of its distance, which keeps the queue in distance order.
			var limit: int = dist[queue[head]] + 1 if head < tail else int(deferred[deferred_head][0])
			while deferred_head < deferred.size() and int(deferred[deferred_head][0]) <= limit:
				var held: Array = deferred[deferred_head]
				deferred_head += 1
				var at := int(held[1])
				if dist[at] >= 0:
					continue
				dist[at] = int(held[0])
				parent[at] = int(held[2])
				phase[at] = int(held[3])
				if stop_mask[at] != 0:
					reached.append(at)
					if pass_mask[at] == 0:
						continue
				queue[tail] = at
				tail += 1
			if head >= tail:
				continue
		var current := queue[head]
		head += 1
		var next_distance := dist[current] + 1
		if next_distance > radius:
			capped = true
			continue
		var cx := current % width
		var cy := current / width
		# Only a tile on the map's edge has neighbours off the map.
		var on_edge := cx == 0 or cy == 0 or cx == width - 1 or cy == height - 1
		var here_phase := phase[current] if has_water else 0
		var mode := here_phase & 3
		if here_phase == 0 and docks.has(current) and dist[int(docks[current])] < 0:
			# The shipyard here builds a boat at its dock and the hero boards it.
			if dist[current] + 1 + dock_cost <= radius:
				_hold_step(deferred, [dist[current] + 1 + dock_cost, int(docks[current]), current, 1 | BOUGHT_BOAT])
			else:
				capped = true
		for direction in range(8):
			var dx: int = NEIGHBOR_DX[direction]
			var dy: int = NEIGHBOR_DY[direction]
			if on_edge and (cx + dx < 0 or cy + dy < 0 or cx + dx >= width or cy + dy >= height):
				continue
			var next := current + step_offset[direction]
			if dist[next] >= 0:
				continue
			if has_water:
				if water[next] != 0:
					if mode == 1:
						if dx != 0 and dy != 0 and not native_corners and sea_open[current + dx] == 0 and sea_open[current + dy * width] == 0:
							continue
						if stop_mask[next] != 0:
							dist[next] = next_distance
							parent[next] = current
							phase[next] = here_phase
							reached.append(next)
							if pass_mask[next] != 0:
								queue[tail] = next
								tail += 1
						elif sea_open[next] != 0:
							dist[next] = next_distance
							parent[next] = current
							phase[next] = here_phase
							queue[tail] = next
							tail += 1
					elif here_phase == 0 and boat_tiles.has(next):
						if next_distance + shore_cost <= radius:
							_hold_step(deferred, [next_distance + shore_cost, next, current, 1])
						else:
							capped = true
					continue
				if mode == 1:
					if stop_mask[next] != 0 or blocked[next] == 0:
						if next_distance + shore_cost <= radius:
							_hold_step(deferred, [next_distance + shore_cost, next, current, 2 | (here_phase & BOUGHT_BOAT)])
						else:
							capped = true
					continue
			if dx != 0 and dy != 0 and not native_corners and blocked[current + dx] != 0 and blocked[current + dy * width] != 0:
				continue
			if stop_mask[next] != 0:
				dist[next] = next_distance
				parent[next] = current
				if has_water:
					phase[next] = here_phase
				reached.append(next)
				if pass_mask[next] != 0:
					queue[tail] = next
					tail += 1
				elif portals.has(next) and hero_zone[next] == 0:
					# Through the portal: the hero comes out standing on an exit
					# (usually another portal of the network) and the route goes
					# on from there.
					for exit in _portal_exits(portals[next], seen_map):
						if dist[exit] < 0:
							dist[exit] = next_distance + 1
							parent[exit] = next
							if has_water:
								phase[exit] = here_phase
							if hero_zone[exit] != 0:
								reached.append(exit)
								continue
							queue[tail] = exit
							tail += 1
				continue
			if blocked[next] != 0:
				continue
			dist[next] = next_distance
			parent[next] = current
			if has_water:
				phase[next] = here_phase
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
		"radius": radius,
		"blocked": blocked,
		"stop_mask": stop_mask,
		"pass_mask": pass_mask,
		"native_corners": native_corners,
		"guard_mask": guard_mask,
		"guard_zones": guard_zones,
		"hero_zone": hero_zone,
		"static_stops": static_stops,
		"phase": phase,
	}

## What a route to this tile pays for a boat it buys at a shipyard, in the
## gold-equivalent its errand's value is weighed in.
static func _boat_price(session: SessionStateStoreScript.SessionData, context: Dictionary, search: Dictionary, tile_index: int) -> float:
	var phase: PackedByteArray = search.get("phase", PackedByteArray())
	if tile_index < 0 or tile_index >= phase.size() or (phase[tile_index] & BOUGHT_BOAT) == 0:
		return 0.0
	return _payload_value(_level_surface(session, context, 0).get("boat_cost", {}), {})

static func _is_water_index(surface: Dictionary, tile_index: int) -> bool:
	var water: PackedByteArray = surface.get("water", PackedByteArray())
	return tile_index < water.size() and water[tile_index] != 0

## Holds back a boarding or landing step in distance order (most arrive in
## order already, so the scan from the back is short).
static func _hold_step(deferred: Array, step: Array) -> void:
	var at := deferred.size()
	while at > 0 and int(deferred[at - 1][0]) > int(step[0]):
		at -= 1
	deferred.insert(at, step)

static func _tile_index_of(point: Dictionary, size: Vector2i) -> int:
	var x := int(point.get("x", -1))
	var y := int(point.get("y", -1))
	if x < 0 or y < 0 or x >= size.x or y >= size.y:
		return -1
	return y * size.x + x

## The tile index step to each neighbour (NEIGHBOR_DX, NEIGHBOR_DY) on a map
## this wide, for a tile whose neighbours all lie on the map.
static func _step_offsets(width: int) -> PackedInt32Array:
	var offsets := PackedInt32Array()
	for direction in range(8):
		offsets.append(int(NEIGHBOR_DY[direction]) * width + int(NEIGHBOR_DX[direction]))
	return offsets

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
		"gate":
			return _cross_gate(session, context, index, plan)
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

## Steps through the subterranean gate the hero stands on, under the human's
## rule (`native_passage_travel_check`), and keeps the errand it crossed for as
## its goal. A guard whose zone covers the far doorway is fought there on
## arrival, as the human fights it; the hero plans again on the other level.
static func _cross_gate(session: SessionStateStoreScript.SessionData, context: Dictionary, index: int, plan: Dictionary) -> Dictionary:
	var entry: Dictionary = session.overworld.encounters[index]
	var nodes: Array = session.overworld.get("resource_nodes", [])
	var node_index := int(plan.get("index", -1))
	var gate: Dictionary = _level_surface(session, context, LevelRules.level_of(entry)).get("gates", {}).get(_tile_index_of(entry, context.map_size), {})
	if gate.is_empty() or int(gate.node) != node_index:
		return {"arrived": true, "acted": false}
	var far: Vector3i = gate.exit
	var guard: Dictionary = _overworld_rules()._find_guard_engagement_at_tile(session, far.x, far.y, far.z, false)
	var guard_index := int(guard.get("index", -1))
	if guard_index >= 0 and hero_power(entry) < _guard_power(guard.encounter) * GUARD_WIN_RATIO:
		return {"arrived": true, "acted": false}
	var check: Dictionary = _overworld_rules().native_passage_travel_check(session, nodes[node_index], NativeTransit.point(entry), String(entry.get("placement_id", "")), "", guard_index >= 0)
	if not bool(check.get("ok", false)):
		return {"arrived": true, "acted": false}
	var exit: Vector3i = check.exit
	var before := LevelRules.position(entry)
	entry["x"] = exit.x
	entry["y"] = exit.y
	entry["level"] = exit.z
	var block: Dictionary = entry.get(AI_HERO_KEY, {})
	block["goal"] = (plan.get("beyond", {}) as Dictionary).duplicate()
	entry[AI_HERO_KEY] = block
	TurnPlayback.move(session, entry, before)
	_store_entry(session, index, entry)
	_overworld_rules().invalidate_spatial_lookup(session)
	_reveal(session, context, LevelRules.position(entry), _sight_radius(entry))
	var ambushed := _hostile_hero_beside(session, context, Vector2i(exit.x, exit.y), exit.z)
	if not ambushed.is_empty():
		return _interact(session, context, index, ambushed)
	if guard_index >= 0:
		return _fight_neutral(session, context, index, {"kind": "encounter", "index": guard_index})
	return {"arrived": false, "rerouted": true}

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
	surface.erase("open_zones")

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
		_forget_sighting(context, String(other.get("placement_id", "")))
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
	var merged := {}
	var kept: Array = []
	if bool(plan.get("swap", false)):
		# The armies are pooled: the main hero ends with the strongest seven
		# stacks of both, the field hero with the rest (at least one creature).
		var swap := _garrison_pickup(other_army.get("stacks", []).duplicate(true), army.get("stacks", []).duplicate(true))
		if float(swap.gain) <= 0.0:
			return {"arrived": true}
		merged = {"stacks": swap.stacks}
		kept = swap.left
		if kept.is_empty():
			var weakest := _weakest_stack_index(merged.stacks)
			var stack: Dictionary = merged.stacks[weakest]
			if int(stack.get("count", 0)) > 1:
				stack["count"] = int(stack.count) - 1
				kept = [{"unit_id": String(stack.get("unit_id", "")), "count": 1}]
	else:
		var split := _split_for_handover(army.get("stacks", []))
		merged = _merge_stacks_into(other_army.get("stacks", []), split.give)
		if merged.stacks == other_army.get("stacks", []):
			return {"arrived": true}
		kept = split.keep
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
	# A hero standing in the town defends it: beat that hero first.
	var defender_index := _town_hero_defender_index(session, town, controller)
	var defender_power := 0.0
	if defender_index >= 0:
		defender_power = hero_power(session.overworld.encounters[defender_index])
		var duel := _fight_ai_hero(session, context, index, {"index": defender_index})
		events.append_array(duel.get("events", []))
		if _is_resolved(session, String(session.overworld.encounters[index].get("placement_id", ""))) or not _is_resolved(session, String(session.overworld.encounters[defender_index].get("placement_id", ""))):
			return {"arrived": true, "events": events}
		towns = session.overworld.get("towns", [])
		town = towns[town_index]
	var garrison: Array = town.get("garrison", []) if town.get("garrison", []) is Array else []
	if army_power(garrison) > 0.0:
		var fight := _auto_resolve(session, context, index, {
			"placement_id": "town_garrison:%s" % String(town.get("placement_id", "")),
			"encounter_id": AI_HERO_ENCOUNTER_ID,
			"enemy_army": {"id": "town_garrison", "name": "%s Garrison" % _turn_rules()._town_name(town), "stacks": garrison},
			BATTLE_LOG_OWNER_KEY: PlayerRules.town_controller_id(town) if owner == "enemy" else owner,
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
	var previous_controller := PlayerRules.town_controller_id(town) if owner == "enemy" else owner
	var transition: Dictionary = _overworld_rules().transition_town_control(session, String(town.get("placement_id", "")), "enemy", controller, "ai_hero_capture")
	if not bool(transition.get("ok", false)):
		return {"arrived": true, "events": events}
	context["topology_changed"] = true
	# A human buys a captured town's troops into its garrison at once, so a
	# passing hero cannot simply walk back in.
	events.append_array(_recruit_town(session, context, town_index, {}))
	var entry: Dictionary = session.overworld.encounters[index]
	if bool(session.flags.get(BATTLE_LOG_FLAG, false)):
		var captures: Array = session.flags.get(CAPTURE_LOG_KEY, [])
		captures.append({
			"day": int(session.day),
			"player_id": controller,
			"hero": hero_name(entry),
			"hero_power": hero_power(entry),
			"town_placement_id": String(town.get("placement_id", "")),
			"town": _turn_rules()._town_name(town),
			"from": previous_controller,
			"garrison_power": army_power(garrison) + defender_power,
		})
		session.flags[CAPTURE_LOG_KEY] = captures
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
	# An overwhelming margin needs no second look, unless the defender's hero
	# can blast a big share of the army with one spell.
	var power := hero_power(entry)
	var defender: Dictionary = encounters[defender_index]
	var burst := _burst_share(entry, defender.get("enemy_commander_state", {})) if is_ai_hero(defender) else 0.0
	if float(plan.get("fight_power", 0.0)) > 0.0 and power >= float(plan.fight_power) * CLEAR_WIN_RATIO and burst < SPELL_BURST_PREVIEW_SHARE:
		return true
	context["preview_count"] = int(context.get("preview_count", 0)) + 1
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
## Pure: the live session is not touched. stop_below_creatures > 0 ends the
## battle unresolved (not won) once the hero has fewer creatures standing.
static func _simulate_battle(session: SessionStateStoreScript.SessionData, context: Dictionary, entry: Dictionary, defender: Dictionary, battle_number: int, stop_below_creatures: int = 0) -> Dictionary:
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
	var resolution: Dictionary = _auto_resolve_rules().resolve_active_battle(scratch, _auto_resolve_rules().DEFAULT_STEP_LIMIT, stop_below_creatures)
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
		"resolution": {
			"state": final_state,
			"stop_reason": String(resolution.get("stop_reason", "")),
			"steps": int(resolution.get("steps", 0)),
			"player_orders": int(resolution.get("player_orders", 0)),
			"enemy_turns": int(resolution.get("enemy_ready_ticks", 0)),
			"action_counts": resolution.get("action_counts", {}),
			"message": String(resolution.get("terminal_result", {}).get("message", "")),
		},
	}

static func _auto_resolve(session: SessionStateStoreScript.SessionData, context: Dictionary, index: int, defender: Dictionary) -> Dictionary:
	context["auto_battle_count"] = int(context.get("auto_battle_count", 0)) + 1
	var entry: Dictionary = session.overworld.encounters[index]
	var preview: Dictionary = context.get("fight_preview", {})
	context.erase("fight_preview")
	var outcome: Dictionary = preview.get("outcome", {}) if String(preview.get("key", "")) == _battle_key(entry, defender, int(context.auto_battle_count)) else {}
	var previewed := not outcome.is_empty()
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
	if bool(session.flags.get(BATTLE_LOG_FLAG, false)):
		_log_battle(session, context, entry, defender, outcome, previewed)
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

## One auto-resolved fight, kept in `session.flags` when a match asks for a
## battle log (an AI-against-AI evaluation). Normal games keep none.
static func _log_battle(session: SessionStateStoreScript.SessionData, context: Dictionary, entry: Dictionary, defender: Dictionary, outcome: Dictionary, previewed: bool) -> void:
	var defender_stacks: Array = []
	if defender.get("enemy_army", {}) is Dictionary and defender.get("enemy_army", {}).has("stacks"):
		defender_stacks = defender.get("enemy_army", {}).get("stacks", [])
	else:
		defender_stacks = _neutral_army(defender).get("stacks", [])
	var placement_id := String(defender.get("placement_id", ""))
	var kind := "hero" if is_ai_hero(defender) else ("town" if placement_id.begins_with("town_garrison:") else "guard")
	var commander: Dictionary = entry.get("enemy_commander_state", {}) if entry.get("enemy_commander_state", {}) is Dictionary else {}
	var hero_after: Dictionary = outcome.get("hero_after", {})
	var stacks: Array = entry.get("enemy_army", {}).get("stacks", []) if entry.get("enemy_army", {}) is Dictionary else []
	var power := army_power(stacks, commander)
	var defender_power := army_power(defender_stacks, defender.get("enemy_commander_state", {}) if kind == "hero" else {})
	var won := bool(outcome.get("won", false))
	var lost := bool(outcome.get("lost", false))
	var records: Array = session.flags.get(BATTLE_LOG_KEY, [])
	records.append({
		"day": int(session.day),
		"player_id": String(context.controller),
		"hero_placement_id": String(entry.get("placement_id", "")),
		"hero": hero_name(entry),
		"hero_level": int(commander.get("level", 1)),
		"experience_gained": 0 if lost else maxi(0, int(hero_after.get("experience", 0)) - int(commander.get("experience", 0))),
		"x": int(entry.get("x", 0)),
		"y": int(entry.get("y", 0)),
		"stacks": stacks.duplicate(true),
		"power": power,
		"survivors": [] if lost else outcome.get("hero_survivors", []).duplicate(true),
		"survivor_power": 0.0 if lost else army_power(outcome.get("hero_survivors", []), hero_after),
		"estimated_loss_share": _expected_loss_value(power, defender_power) / maxf(0.001, power * TROOP_VALUE_PER_POWER),
		"defender_kind": kind,
		"defender": _defender_label(defender),
		"defender_player_id": String(defender.get(BATTLE_LOG_OWNER_KEY, PlayerRules.raid_controller_id(defender))),
		"defender_stacks": defender_stacks.duplicate(true),
		"defender_power": defender_power,
		"defender_survivors": [] if won else outcome.get("enemy_survivors", []).duplicate(true),
		"result": "won" if won else ("lost" if lost else "standstill"),
		"previewed": previewed,
		"resources_gained": outcome.get("resources_gained", {}).duplicate(true),
		"commander": _commander_brief(commander),
		"defender_commander": _commander_brief(defender.get("enemy_commander_state", {})) if kind == "hero" else {},
		"resolution": outcome.get("resolution", {}).duplicate(true),
	})
	session.flags[BATTLE_LOG_KEY] = records

## Keeps the best-scoring options a hero weighed in this decision.
static func _note_alternative(context: Dictionary, candidate: Dictionary, score: float, distance: int) -> void:
	var alternatives: Array = context.decision_alternatives
	alternatives.append([snappedf(score, 1.0), String(candidate.get("kind", "")), String(candidate.get("id", "")).get_slice("_object_", 1), snappedf(float(candidate.get("value", 0.0)), 1.0), distance])
	alternatives.sort_custom(func(a: Array, b: Array) -> bool: return float(a[0]) > float(b[0]))
	if alternatives.size() > DECISION_LOG_ALTERNATIVES + 1:
		alternatives.resize(DECISION_LOG_ALTERNATIVES + 1)
	context["decision_alternatives"] = alternatives

static func _log_decision(session: SessionStateStoreScript.SessionData, context: Dictionary, entry: Dictionary, plan: Dictionary) -> void:
	var log: Array = session.flags.get(DECISION_LOG_KEY, [])
	var chosen := String(plan.get("id", "")).get_slice("_object_", 1)
	var alternatives := []
	for alternative in context.get("decision_alternatives", []):
		if alternative[2] != chosen and alternatives.size() < DECISION_LOG_ALTERNATIVES:
			alternatives.append(alternative)
	log.append({
		"player_id": String(context.controller),
		"hero": hero_name(entry),
		"at": [int(entry.get("x", 0)), int(entry.get("y", 0))],
		"level": LevelRules.level_of(entry),
		"aboard": WaterTravel.hero_boat_id(entry) != "",
		"power": snappedf(hero_power(entry), 1.0),
		"move": int(entry.get(AI_HERO_KEY, {}).get("movement", {}).get("current", 0)),
		"plan": [String(plan.get("kind", "")), chosen, snappedf(float(plan.get("value", 0.0)), 1.0), int(plan.get("distance", -1))],
		"blocked_need": snappedf(float(entry.get(AI_HERO_KEY, {}).get(BLOCKED_NEED_KEY, 0.0)), 1.0),
		"alternatives": alternatives,
	})
	session.flags[DECISION_LOG_KEY] = log

static func _economy_add(session: SessionStateStoreScript.SessionData, controller: String, key: String, amount: float) -> void:
	if amount == 0.0 or not bool(session.flags.get(BATTLE_LOG_FLAG, false)):
		return
	var log: Dictionary = session.flags.get(ECONOMY_LOG_KEY, {})
	var row: Dictionary = log.get(controller, {})
	row[key] = float(row.get(key, 0.0)) + amount
	log[controller] = row
	session.flags[ECONOMY_LOG_KEY] = log

## What a hero brings to a battle besides its troops, for the battle log.
static func _commander_brief(commander: Variant) -> Dictionary:
	if not (commander is Dictionary) or commander.is_empty():
		return {}
	var command: Dictionary = commander.get("command", {}) if commander.get("command", {}) is Dictionary else {}
	var spellbook: Dictionary = commander.get("spellbook", {}) if commander.get("spellbook", {}) is Dictionary else {}
	return {
		"level": int(commander.get("level", 1)),
		"attack": int(command.get("attack", 0)),
		"defense": int(command.get("defense", 0)),
		"power": int(command.get("power", 0)),
		"knowledge": int(command.get("knowledge", 0)),
		"spells": (spellbook.get("known_spell_ids", []) as Array).duplicate() if spellbook.get("known_spell_ids", []) is Array else [],
		"mana": (spellbook.get("mana", {}) as Dictionary).duplicate() if spellbook.get("mana", {}) is Dictionary else {},
		"spell_damage_per_round": _spell_damage_per_round(commander),
	}

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

## Fighting value: per creature its health, damage, defense, speed and
## initiative (POWER_* above), shooters RANGED_POWER times, raised by the
## leading hero's command and spells.
static func army_power(stacks: Variant, commander: Variant = {}) -> float:
	var total := 0.0
	var damage_per_round := 0.0
	if not (stacks is Array):
		return total
	_sync_power_memos()
	for stack in stacks:
		if not (stack is Dictionary):
			continue
		var count := int(stack.get("count", 0))
		if count <= 0:
			continue
		var unit_id := String(stack.get("unit_id", ""))
		var figures = _unit_power_memo.get(unit_id)
		if figures == null:
			figures = _unit_power_figures(unit_id)
			_unit_power_memo[unit_id] = figures
		if figures.is_empty():
			continue
		total += float(figures[0]) * float(count)
		damage_per_round += float(figures[1]) * float(count)
	if commander is Dictionary and not commander.is_empty():
		# The hero's attack raises the army's damage and its defense cuts the
		# damage it takes, by the battle's own curve (BattleDamageRules); its
		# spells add to the army's damage per round, so a few casts barely move
		# a big army and count for a lot behind a small one.
		var command: Dictionary = commander.get("command", {}) if commander.get("command", {}) is Dictionary else {}
		var damage_dealt: float = BattleDamage.attack_defense_multiplier(maxi(0, int(command.get("attack", 0))), 0)
		var damage_taken: float = BattleDamage.attack_defense_multiplier(0, maxi(0, int(command.get("defense", 0))))
		total *= pow(damage_dealt / maxf(0.01, damage_taken), HERO_COMMAND_POWER)
		var spell_damage := _spell_damage_per_round(commander)
		if spell_damage > 0.0 and damage_per_round > 0.0:
			total *= pow(1.0 + spell_damage / damage_per_round, HERO_SPELL_POWER)
	return total

## Damage a hero's spells add per round over a typical battle: the strongest
## battle damage spell it knows and can pay for, cast once a round while its
## mana lasts. army_power syncs the memos first.
static func _spell_damage_per_round(commander: Dictionary) -> float:
	var spellbook: Dictionary = commander.get("spellbook", {}) if commander.get("spellbook", {}) is Dictionary else {}
	var known = spellbook.get("known_spell_ids", [])
	if not (known is Array) or known.is_empty():
		return 0.0
	var mana_state: Dictionary = spellbook.get("mana", {}) if spellbook.get("mana", {}) is Dictionary else {}
	var mana := int(mana_state.get("current", mana_state.get("max", 0)))
	var power := maxi(0, int(commander.get("command", {}).get("power", 0)) if commander.get("command", {}) is Dictionary else 0)
	var best := 0.0
	for spell_id in known:
		var figures = _damage_spell_memo.get(String(spell_id))
		if figures == null:
			figures = _damage_spell_figures(String(spell_id))
			_damage_spell_memo[String(spell_id)] = figures
		if figures.is_empty():
			continue
		var casts := mini(BATTLE_ROUNDS_ESTIMATE, mana / int(figures[0]))
		var per_cast := float(int(figures[1]) + power * int(figures[2]))
		best = maxf(best, per_cast * float(casts))
	return best / float(BATTLE_ROUNDS_ESTIMATE)

## Per creature of a unit: [fighting value, average damage], or [] when the
## unit is unknown.
static func _unit_power_figures(unit_id: String) -> Array:
	var unit := ContentService.get_unit(unit_id)
	if unit.is_empty():
		return []
	var damage := (float(unit.get("min_damage", 1)) + float(unit.get("max_damage", 1))) * 0.5
	var per := POWER_SCALE * pow(maxf(1.0, float(unit.get("hp", 1))), POWER_HEALTH) * pow(maxf(0.5, damage), POWER_DAMAGE)
	per *= exp(POWER_PER_DEFENSE * float(int(unit.get("defense", 0))) + POWER_PER_SPEED * float(int(unit.get("speed", 0))) + POWER_PER_INITIATIVE * float(int(unit.get("initiative", 0))))
	if bool(unit.get("ranged", false)):
		per *= RANGED_POWER
	return [per, damage]

## A battle damage spell's [mana cost, base damage, power scale], or [] for any
## other spell.
static func _damage_spell_figures(spell_id: String) -> Array:
	var spell := ContentService.get_spell(spell_id)
	var effect: Dictionary = spell.get("effect", {}) if spell.get("effect", {}) is Dictionary else {}
	if String(spell.get("context", "")) != "battle" or String(effect.get("type", "")) != "damage_enemy":
		return []
	return [maxi(1, int(spell.get("mana_cost", 1))), int(effect.get("base_damage", 0)), int(effect.get("power_scale", 0))]

## army_power reads each unit and spell from content millions of times a game,
## so their figures are memoized and dropped whenever the content cache reloads.
static var _unit_power_memo := {}
static var _damage_spell_memo := {}
static var _power_memo_sources := []

static func _sync_power_memos() -> void:
	var sources := [
		ContentService.get_content_revision(),
		ContentService.load_json(ContentService.UNITS_PATH),
		ContentService.load_json(ContentService.SPELLS_PATH),
	]
	if _power_memo_sources.size() != sources.size() or _power_memo_sources[0] != sources[0] or not is_same(_power_memo_sources[1], sources[1]) or not is_same(_power_memo_sources[2], sources[2]):
		_unit_power_memo = {}
		_damage_spell_memo = {}
		_power_memo_sources = sources

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
