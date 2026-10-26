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
const ArtifactRulesScript = preload("res://scripts/core/ArtifactRules.gd")
const CreatureDwellings = preload("res://scripts/core/CreatureDwellingRules.gd")
const NodePayload = preload("res://scripts/core/ResourceNodePayloadRules.gd")
const NativeTransit = preload("res://scripts/core/NativeTransitRules.gd")
const VisitBuildings = preload("res://scripts/core/VisitBuildingRules.gd")
const TownServices = preload("res://scripts/core/EnemyTownServices.gd")
const AdventureRules = preload("res://scripts/core/EnemyAdventureRules.gd")
const WaterTravel = preload("res://scripts/core/WaterTravelRules.gd")
const AiEngine = preload("res://scripts/core/AiEngine.gd")
const TurnEngine = preload("res://scripts/core/TurnEngine.gd")
const HumanEngine = preload("res://scripts/core/HumanEngine.gd")

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
## The typed static vars below are tuning numbers from
## content/ai_hero_weights.json ("Weights" below).
static var MAX_DECISIONS_PER_DAY: int
static var SEARCH_DAYS: int
static var FAR_SEARCH_DAYS: int
## Main and field armies also look this many days of movement out for what
## decides the game (`_strategic_candidate`): rival and neutral towns, hostile
## heroes and the guards in the way to a known town. On large maps the leading
## player's armies only ever looked three days out, found a mine or a pile of
## resources there every day, and never went for the rival towns in the far
## corners, each worth a hundred mines; four of ten large-map games ran to the
## day cap that way.
static var STRATEGIC_DAYS: int
static var MIN_SEARCH_RADIUS: int
## A hero weighs what lies past this many of the nearest subterranean gates it
## can walk to (`_gate_candidate`); each costs a search of the other level.
static var MAX_GATES_WEIGHED: int
## Main and field armies also route through any number of gates to a town they
## can take, or to ground not yet seen while a rival's towns are unseen
## (`_gate_routes`). The way between two gates of one stretch of ground counts
## its straight distance times ROUTE_DETOUR; a stretch counts as unexplored
## from ROUTE_UNEXPLORED_MIN unseen tiles.
static var ROUTE_DETOUR: float
static var ROUTE_UNEXPLORED_MIN: int
## A stretch a main or field army stood on within ROUTE_REVISIT_DAYS is no
## errand for scouting through a gate (`ROUTE_VISITS_KEY` in its block): what
## it could not see there lay behind guards it weighs where it stands. Without
## this, armies whose stretches on either side of a gate both kept ground
## behind guards unseen went back and forth through that gate for 25 days.
static var ROUTE_REVISIT_DAYS: int
const ROUTE_VISITS_KEY := "route_visits"
## Set on the copy of a hero weighed as if it stood elsewhere (`_beyond_gate`,
## `_gate_home`).
const TRAVELLER_KEY := "ai_traveller"
## Boarding a boat or stepping ashore ends the hero's day, as for the human; a
## route through either counts this share of a day's movement on top of the
## step. Building the boat at a shipyard counts one more day (its price).
static var SHORE_STEP_SHARE: float
## The day a main or field army last found nothing to do with a shipyard in
## reach and no means to pay for a boat: for BOAT_SAVING_DAYS after it the
## player's towns keep the boat's price back (`_govern_towns`).
const BOAT_WANTED_KEY := "ai_boat_wanted_day"
static var BOAT_SAVING_DAYS: int
## A guard is considered (and previewed) from this strength margin. With the
## strength estimate refitted 2026-10-16, guards fought at 1.3 to 1.5x lose
## about 93% of battles in the battle AI arena, and none from 2x.
static var GUARD_WIN_RATIO: float
static var HERO_ATTACK_RATIO: float
static var TOWN_ATTACK_RATIO: float
static var THREAT_RATIO: float
## A town is worth this much plus TOWN_HORIZON_WEEKS of its income and troop
## growth (`_town_worth`); a faction that has lost every town values one twice
## as much. Towns are the most valuable thing on the map: they pay and muster
## every week for the rest of the game. Until 2026-10-09 a town was worth 4,000
## plus two weeks, little more than a good mine, and on a medium map neutral
## towns with 24 defenders stood untaken for 40 to 70 days.
static var TOWN_BASE_VALUE: float
static var TOWN_HORIZON_WEEKS: float
## Knocking a rival out of the game is worth this much, shared among what it
## still holds: its towns, or its heroes once it has no town left. A player's
## last town is worth this much more; when it holds two, each is worth half.
## On a medium map a beaten player kept its last town 40 days against an army
## twenty times its own while the winner cleared guards and mines.
static var ELIMINATION_VALUE: float
## Lesser heroes that keep an army of their own (`_field_hero_ids`): one per
## town held beyond the first. They take garrisons along, defend towns and take
## what they can beat instead of handing their troops to the main hero; captured
## towns of other factions muster creatures the main army has no slot for.
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
static var DEFENSE_HORIZON_DAYS: int
static var DEFENSE_MARGIN: float
static var DEFENSE_BASELINE_PER_WEEK: float
static var DEFENSE_SHARE_MAX: float
static var DEFENSE_SHARE_MAX_MAIN: float
## What a field army joining the main army is worth on top of the troops,
## when the main army alone cannot beat a hostile hero or town (`_main_shortfall`).
static var JOIN_BASE_VALUE: float
## A field army keeps at most this share of the main army's strength; above
## it, it goes and joins the main army, which takes the stronger stacks. One
## army wins the war; field armies hold ground behind it. On large maps every
## player's strength sat in three or four armies of 5,000 to 30,000, none of
## them able to clear the strong guards on the way to a rival, and the last
## three of eight players never attacked each other in the final 40 days.
static var FIELD_SHARE_MAX: float
## The main hero remembers the strength it lacked to clear the guard standing
## first in its way to a known rival town (`_strategic_candidate`), so field
## armies come to join it (`_main_shortfall`).
const BLOCKED_NEED_KEY := "blocked_need"
## A defending hero whose single strongest spell would take this share of the
## attacker's health is never attacked unseen: the fight is previewed.
static var SPELL_BURST_PREVIEW_SHARE: float
static var HOMELESS_TOWN_MULTIPLIER: float
## Killing a hero that threatens one of our towns is worth this share of the town.
static var THREAT_KILL_SHARE: float
## A visible hostile hero this many times a hero's strength is a danger to it:
## the hero keeps out of its reach (`_dangers`).
static var DANGER_RATIO: float
## army_power's terms (see there). Fitted 2026-10-16 on 4,800 realistic battles
## of the battle AI arena (tools/battle_ai_arena), both sides played by the
## battle AI, and checked on 2,400 others: the estimate calls the winner of
## 90% of them, against 88% with only shooters reweighed and 87% before. Most
## misses are near-even battles; replayed with other dice, 3% of battles change
## winner anyway. Creature attack and the unit abilities added nothing.
## One creature: POWER_SCALE x health^POWER_HEALTH x damage^POWER_DAMAGE, and
## per point of defense, speed and initiative a POWER_PER_* share more; the
## scale keeps the average creature at its value before the fit.
static var POWER_SCALE: float
static var POWER_HEALTH: float
static var POWER_DAMAGE: float
static var POWER_PER_DEFENSE: float
static var POWER_PER_SPEED: float
static var POWER_PER_INITIATIVE: float
## A shooter over a melee creature of the same stats: it shoots freely while
## melee closes in.
static var RANGED_POWER: float
## The hero's attack and defense (the battle's own damage curve) and its
## damage spells raise the army by these powers of what they add.
static var HERO_COMMAND_POWER: float
static var HERO_SPELL_POWER: float
## The most of its strength a main hero leaves behind to guard a town.
static var GUARD_SHARE_MAX: float
## The main hero holds at least this share of the strongest hero's army.
static var MAIN_ARMY_SHARE: float
## Rounds a battle lasts for the strength estimate of a hero's spells.
static var BATTLE_ROUNDS_ESTIMATE: int
static var TROOP_VALUE_PER_POWER: float
## Builds weigh a dwelling's troops and a building's income over two weeks.
static var BUILD_HORIZON_WEEKS: float
## Each market stage is worth as much to a town as this building's income.
const MARKET_PEER_BUILDING_ID := "building_dev_storehouse_1"
## A resource the faction lacks for its build list counts this much more.
static var SHORT_RESOURCE_MULTIPLIER: float
## A town whose dwellings muster less than this (gold value) a week is short
## of troops.
static var STARVED_TOWN_WEEKLY_TROOPS: float
## With this margin a fight is won without a second look.
static var CLEAR_WIN_RATIO: float
## The square law runs about a third short of what auto-resolve costs, with a
## small loss even against weak guards: calibrated 2026-10-08 on 1,262
## auto-resolved fights of the three computer players' main heroes against the
## guards of the owner's large map (mean loss 8.7% at a guard of 0.3-0.4 of
## the hero's strength, 14% at 0.4-0.5, 22% at 0.5-0.6, 32% at 0.6-0.7).
static var LOSS_ESTIMATE_FACTOR: float
## The small loss grows with the guard's share of the hero's strength, as it
## did at the 2026-10-08 calibration's 0.35. It was a fixed 1.2% of the army,
## more than a weak guard pays a strong hero, so strong heroes walked past weak
## guards: in 1,025 arena guard fights (2026-10-16) the winner lost 0.05% of
## its army against guards under 3% of its strength, 0.4% at 5-8%, 0.7% at
## 8-12%, 2.3% at 17-25% and 4.6% at 25-35%.
static var LOSS_ESTIMATE_PER_RATIO: float
## Guards up to this share of the hero's strength within its reach today are
## previewed for a free fight (`_free_fight`): of the arena's fights against
## them, 63% to 84% cost the winner no creature.
static var FREE_FIGHT_MAX_RATIO: float
## Free-fight previews a hero runs in one decision.
static var MAX_FREE_FIGHT_PREVIEWS: int
## Fights a hero sizes up and turns down before settling on a decision.
static var MAX_FIGHT_VETOES: int
## Dismissed fights an idle hero looks at again in one decision.
static var MAX_IDLE_PREVIEWS: int
## An idle hero takes a fight its preview wins keeping this share of its
## strength, even when the guard holds less than the troops it costs.
static var IDLE_FIGHT_MIN_KEPT: float
## How close to its town's doorway an idle hero waits.
static var HOME_WAIT_RADIUS: int
## A hand-over of troops is worth at most what a modest site is worth.
static var MEET_VALUE_CAP: float
static var GOAL_CONTINUITY_BONUS: float
const TOWN_SIGHT_RADIUS := 8
## Scouting the nearest unexplored ground. Raised from 220 on 2026-10-18 at
## the owner's request that computer players explore more.
static var EXPLORE_VALUE: float
## While a rival still holds a town this player has never seen, the unexplored
## frontier is worth up to this much more, rising from HUNT_START_DAY to
## HUNT_FULL_DAY: early on heroes expand, later they go and find the enemy.
## It equals ELIMINATION_VALUE: at 6,000 a 66,000-strength main hero on a large
## map preferred fetching troops from its own towns to scouting the 5% of the
## map where the last rival held out. Heroes only target towns they have seen;
## in a four-player medium game the
## leading player (32,000 strength) never scouted the corners where its two
## rivals held one weakly guarded town each, and the game ran to its day cap.
static var HUNT_EXPLORE_VALUE: float
static var HUNT_START_DAY: int
static var HUNT_FULL_DAY: int
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
static var SIGHTING_MEMORY_DAYS: int
## Ground behind a guard that the hero cannot reach today: a base value for
## opening the way, plus each unexplored tile there, up to a cap (sites the
## player has already seen there count on top, at half their value).
static var PASSAGE_BASE_VALUE: float
static var PASSAGE_UNEXPLORED_TILE_VALUE: float
static var PASSAGE_KNOWN_SITE_SHARE: float
static var PASSAGE_VALUE_CAP: float
## Unexplored ground behind a guard while a rival's towns are still unseen is
## worth up to this share of ELIMINATION_VALUE, in full from this many
## unexplored tiles. On a medium map the leading player's heroes, 5,000 to
## 16,000 strong, stayed on their half for 60 days chasing mines while the last
## rival's two towns lay unseen behind a guard: the 5,000 a passage could be
## worth never paid for the troops the fight would cost.
static var HIDDEN_RIVAL_SHARE: float
static var HIDDEN_RIVAL_TILES: int
static var PASSAGE_TILE_CAP: int
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
static var SCROLL_SPELL_BASE_VALUE: float
static var SCROLL_SPELL_TIER_VALUE: float
static var RESOURCE_VALUES: Dictionary = {}
# --- Weights ------------------------------------------------------------------

## The tuning numbers (the static vars above and below) live in WEIGHTS_PATH:
## "army_power" holds the strength estimate's terms, the same for every player
## because battle rewards and generated guards use army_power too; "sets" holds
## weight sets, "default" complete and every other set with only the values it
## changes. A computer player plays with the set its enemy state names under
## WEIGHT_SET_KEY, the default when it names none; a match runner can add sets
## for one run through ContentService.set_content_override. Until 2026-10-20
## they were constants here (docs/native-rules-engine-transition.md, Phase A).
## The set also carries what the AI values at dwellings, visit buildings and
## in its own towns, read by the helpers it calls (apply_ai_weights in
## AdventureRules, TownServices, VisitBuildings and CreatureDwellings).
const WEIGHTS_PATH := "res://content/ai_hero_weights.json"
const WEIGHT_SET_KEY := "ai_weight_set"
const DEFAULT_WEIGHT_SET := "default"
## Wanted heroes (`_desired_hero_count`, `_govern_towns`): a main hero, one per
## town and one more from day EXTRA_HERO_DAY, then one explorer per
## TILES_PER_EXPLORER unexplored land tiles, HERO_COUNT_MAX in all. A hire must
## leave HIRE_RESERVE_DAYS of gold income in the treasury, an explorer's
## EXPLORER_RESERVE_DAYS.
static var EXTRA_HERO_DAY: int
static var HERO_COUNT_MAX: int
static var TILES_PER_EXPLORER: int
static var HIRE_RESERVE_DAYS: int
static var EXPLORER_RESERVE_DAYS: int
## Town building (`_build_choice`, `_upgrade_value`): new troops count this
## much more in a town mustering under STARVED_TOWN_WEEKLY_TROOPS a week; a
## mage guild level is worth a base plus a share per spell tier; each point of
## readiness and each building a choice opens count a fixed value; a creature
## upgrade is worth its strength gain over UPGRADE_VALUE_WEEKS weeks plus a base.
static var STARVED_TOWN_TROOP_MULTIPLIER: float
static var MAGE_GUILD_BASE_VALUE: float
static var MAGE_GUILD_TIER_VALUE: float
static var READINESS_VALUE: float
static var OPENS_BUILDING_VALUE: float
static var UPGRADE_VALUE_WEEKS: float
static var UPGRADE_BASE_VALUE: float
## Threats to a town: a hostile hero reaches at least THREAT_MIN_REACH tiles a
## day and threatens a town THREAT_REACH_MARGIN tiles beyond that; a rival town
## within RIVAL_TOWN_TILES_PER_DAY tiles per defense day calls for the baseline
## garrison (`_town_defense_need`).
static var THREAT_MIN_REACH: int
static var THREAT_REACH_MARGIN: int
static var RIVAL_TOWN_TILES_PER_DAY: int
## A target given up on is left alone for AVOID_DAYS days (`_avoid_target`).
static var AVOID_DAYS: int
## A doorway out of reach past a gate counts its straight distance this many
## times (`_gate_home`).
static var GATE_HOME_DETOUR: int
## Idle fights rank by value less this much per tile of distance.
static var IDLE_FIGHT_DISTANCE_COST: float
## A previewed fight that leaves less than this share of the army is refused
## (`_fight_looks_good`).
static var FIGHT_MIN_KEPT: float
## Target values: a loose artifact, an artifact behind a guard or in a bank,
## beating a human or a computer hero (plus HERO_KILL_TROOP_SHARE of its
## troops' value), troops handed over, picked up from a garrison or carried to
## the main army, and below MIN_TROOP_ERRAND_VALUE no errand at all; a
## dwelling's base and share of its week, a visit building's base, a controlled
## site's income over SITE_INCOME_DAYS days plus its control, more when a rival
## holds it; a guard fight's base; what a guard holds counts GUARDED_VALUE_SHARE,
## a town behind it its neutral or rival value; a human's town HUMAN_TOWN_BONUS
## more.
static var ARTIFACT_VALUE: float
static var ARTIFACT_PRIZE_VALUE: float
static var PLAYER_HERO_KILL_VALUE: float
static var AI_HERO_KILL_VALUE: float
static var HERO_KILL_TROOP_SHARE: float
static var HANDOVER_TROOP_SHARE: float
static var GARRISON_PICKUP_SHARE: float
static var COURIER_TROOP_SHARE: float
static var MIN_TROOP_ERRAND_VALUE: float
static var DWELLING_BASE_VALUE: float
static var DWELLING_WEEK_SHARE: float
static var VISIT_BUILDING_BASE_VALUE: float
static var SITE_INCOME_DAYS: float
static var SITE_CONTROL_VALUE: float
static var RIVAL_SITE_MULTIPLIER: float
static var GUARD_FIGHT_BASE_VALUE: float
static var GUARDED_VALUE_SHARE: float
static var GUARDED_NEUTRAL_TOWN_VALUE: float
static var GUARDED_RIVAL_TOWN_VALUE: float
static var HUMAN_TOWN_BONUS: float
## The weight set in the static vars, the content revision it was read at, and
## the sets resolved at that revision by name.
static var _weight_set_name := ""
static var _weight_set_revision := -1
static var _weight_sets: Dictionary = {}

## Puts a computer player's weight set in the static vars: once per faction
## turn and decision context, so no tuning number is looked up in a loop.
## Nothing changes when the set and the content revision are the ones in place.
static func _use_weights(state: Dictionary) -> void:
	TurnEngine.native_writing(&"AiHeroRules._use_weights", [state])

static func is_ai_hero(entry: Variant) -> bool:
	return HumanEngine.native(&"AiHeroRules.is_ai_hero", [entry])

static func hero_name(entry: Dictionary) -> String:
	return TurnEngine.native_writing(&"AiHeroRules.hero_name", [entry])

static func active_hero_entries(session: SessionStateStoreScript.SessionData, controller: String = "") -> Array:
	return AiEngine.native_writing(&"AiHeroRules.active_hero_entries", [session, controller])

static func active_hero_count(session: SessionStateStoreScript.SessionData, controller: String) -> int:
	return HumanEngine.native_writing(&"AiHeroRules.active_hero_count", [session, controller])

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
	return AiEngine.native_writing(&"AiHeroRules._resolved_lookup", [session])

static func _entry_index(session: SessionStateStoreScript.SessionData, placement_id: String) -> int:
	return AiEngine.native_writing(&"AiHeroRules._entry_index", [session, placement_id])

static func _mark_resolved(session: SessionStateStoreScript.SessionData, placement_id: String) -> void:
	TurnEngine.native_writing(&"AiHeroRules._mark_resolved", [session, placement_id])

# --- Save migration -----------------------------------------------------------

const MIGRATION_KEY := "ai_heroes_version"
const MIGRATION_VERSION := 1
## A commanderless column this close to one of its side's heroes joins it.
const COLUMN_JOIN_RADIUS := 3

static func _nearest_hero_index(encounters: Array, resolved: Dictionary, controller: String, column: Dictionary, radius: int) -> int:
	return TurnEngine.native_writing(&"AiHeroRules._nearest_hero_index", [encounters, resolved, controller, column, radius])

static func _convert_legacy_host(session: SessionStateStoreScript.SessionData, entry: Dictionary, controller: String) -> Dictionary:
	return TurnEngine.native_writing(&"AiHeroRules._convert_legacy_host", [session, entry, controller])

static func _return_troops_to_nearest_town(session: SessionStateStoreScript.SessionData, entry: Dictionary, controller: String) -> void:
	TurnEngine.native_writing(&"AiHeroRules._return_troops_to_nearest_town", [session, entry, controller])

# --- Faction turn -------------------------------------------------------------

## One computer player's day: income, weekly growth, town orders, then heroes.
static func run_faction_turn(session: SessionStateStoreScript.SessionData, config: Dictionary, state: Dictionary, should_apply_weekly_growth: bool, profile_enabled: bool = false) -> Dictionary:
	return TurnEngine.native_writing(&"AiHeroRules.run_faction_turn", [session, config, state, should_apply_weekly_growth, profile_enabled])

## The same income sources the human collects: towns, controlled sites and
## the daily income of every hero's artifacts and specialties.
static func faction_daily_income(session: SessionStateStoreScript.SessionData, controller: String) -> Dictionary:
	return TurnEngine.native_writing(&"AiHeroRules.faction_daily_income", [session, controller])

static func _start_heroes_day(session: SessionStateStoreScript.SessionData, controller: String) -> void:
	TurnEngine.native_writing(&"AiHeroRules._start_heroes_day", [session, controller])

static func _movement_max(entry: Dictionary) -> int:
	return AiEngine.native_writing(&"AiHeroRules._movement_max", [entry])

static func _new_context(session: SessionStateStoreScript.SessionData, config: Dictionary, state: Dictionary) -> Dictionary:
	return TurnEngine.native_writing(&"AiHeroRules._new_context", [session, config, state])

## Terrain and object bodies are the same for every computer player on a given
## day; pickups that vanish clear their tiles in place. One set per day keeps
## large maps from rebuilding it for each player.
static var _surface_cache_key := ""
static var _surface_cache: Dictionary = {}

static func clear_shared_surfaces() -> void:
	TurnEngine.native_writing(&"AiHeroRules.clear_shared_surfaces", [])

## Whether a guard still blocks a site, as the human's claim check decides it.
## Remembered for the enemy turn until another army is beaten.
static var _guard_cache: Dictionary = {}

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

# --- Towns --------------------------------------------------------------------

static func _ensure_starting_hero(session: SessionStateStoreScript.SessionData, context: Dictionary) -> Dictionary:
	return TurnEngine.native_writing(&"AiHeroRules._ensure_starting_hero", [session, context])

## Build, hire and recruit in every owned town with the treasury the faction
## actually holds. Order mirrors a sensible human: a tavern while the faction
## lacks heroes, one hire, one build per town, then troops with what is left.
static func _govern_towns(session: SessionStateStoreScript.SessionData, context: Dictionary) -> Dictionary:
	return TurnEngine.native_writing(&"AiHeroRules._govern_towns", [session, context])

static func _desired_hero_count(session: SessionStateStoreScript.SessionData, controller: String) -> int:
	return TurnEngine.native_writing(&"AiHeroRules._desired_hero_count", [session, controller])

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
	return AiEngine.native_writing(&"AiHeroRules._market_cover", [session, town, pool, cost, apply, market_memo])

## Two faction heroes per week, drawn like the human's tavern. Heroes already
## on the map, in the human's command or recovering from defeat are skipped.
static func ai_tavern_offer_ids(session: SessionStateStoreScript.SessionData, state: Dictionary, controller: String) -> Array:
	return TurnEngine.native_writing(&"AiHeroRules.ai_tavern_offer_ids", [session, state, controller])

static func _tavern_pool(session: SessionStateStoreScript.SessionData, state: Dictionary, controller: String) -> Array:
	return TurnEngine.native_writing(&"AiHeroRules._tavern_pool", [session, state, controller])

static func _cheapest_offer_cost(session: SessionStateStoreScript.SessionData, state: Dictionary, controller: String) -> Dictionary:
	var best := {}
	for hero_id in ai_tavern_offer_ids(session, state, controller):
		var cost := HeroCommandRulesScript.hero_recruit_cost(ContentService.get_hero(String(hero_id)))
		if best.is_empty() or int(cost.get("gold", 0)) < int(best.get("gold", 0)):
			best = cost
	return best

static func _roster_progression_seed(state: Dictionary, hero_id: String) -> Dictionary:
	return TurnEngine.native_writing(&"AiHeroRules._roster_progression_seed", [state, hero_id])

## What a hero takes from a garrison, as a human arranges seven slots: every
## stack that merges or fits, then, while the garrison holds a stronger stack
## than the hero's weakest, the two trade places. `gain` is the strength added.
static func _garrison_pickup(stacks: Array, garrison: Array) -> Dictionary:
	return AiEngine.native_writing(&"AiHeroRules._garrison_pickup", [stacks, garrison])

static func _town_threatened(session: SessionStateStoreScript.SessionData, context: Dictionary, town: Dictionary) -> bool:
	return AiEngine.native_writing(&"AiHeroRules._town_threatened", [session, context, town])

## Facts that hold for one decision; heroes and garrisons change between them.
static func _decision_main_id(session: SessionStateStoreScript.SessionData, context: Dictionary) -> String:
	return AiEngine.native_writing(&"AiHeroRules._decision_main_id", [session, context])

# --- Hero turn ----------------------------------------------------------------

## Utility choice over everything the hero can reach: value for the faction,
## discounted by days of travel, with fights only when the estimate is safe.
## While the hero decides, nothing on the map changes until another hero is
## moved out of the way (`_clear_way`, `_gate_walk`): no site changes hands and
## no hero of the player is hired, beaten or given anything. The decision's
## searches share each site's passability (SITE_PASS_DECISION_KEY) and its
## sight questions each own hero's scouting radius (SCOUT_RADII_KEY); both are
## dropped before any hero moves and when the decision ends.
static func _choose_plan(session: SessionStateStoreScript.SessionData, context: Dictionary, entry: Dictionary) -> Dictionary:
	return TurnEngine.native_writing(&"AiHeroRules._choose_plan", [session, context, entry])

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
	return AiEngine.native_writing(&"AiHeroRules._gate_candidate", [session, context, entry, search, movement_max, beyond_radius])

## Whether the fight a gate plan leads to next, the guard in front of the gate
## or the one at its far end, looks good in a preview (`_fight_looks_good`). A
## bad one is left alone for a few days.
static func _gate_fight_looks_good(session: SessionStateStoreScript.SessionData, context: Dictionary, entry: Dictionary, plan: Dictionary) -> bool:
	return TurnEngine.native_writing(&"AiHeroRules._gate_fight_looks_good", [session, context, entry, plan])

## A hero with nothing to do walks back, over as many days as it takes, to its
## home town, where the next recruits come from, and waits inside it: one idle
## hero per town parks there, out of everyone's way. Others wait close to the
## doorway, but never next to another of the player's heroes and never on a
## tile that would cut a way through (the only exit of a dead end, a one-tile
## corridor), where they would hold the main army in. `keep_clear` holds tiles
## another hero needs to pass: a hero on one of them moves off it.
static func _wait_by_home(session: SessionStateStoreScript.SessionData, context: Dictionary, entry: Dictionary, search: Dictionary, keep_clear: Dictionary = {}) -> Dictionary:
	return TurnEngine.native_writing(&"AiHeroRules._wait_by_home", [session, context, entry, search, keep_clear])

## Whether a hero standing on this tile would cut a way through it: without the
## tile, the open ground around it falls apart into more than one piece. Town
## doorways, guard zones and other route ends are not ways through.
static func _cuts_a_way(search: Dictionary, tile_index: int, size: Vector2i) -> bool:
	return TurnEngine.native_writing(&"AiHeroRules._cuts_a_way", [search, tile_index, size])

## `tile_index` is the reached tile of the stop, when it is known: a site
## standing in the way is worth the ground it opens as well (`_site_door_value`).
static func _candidate(session: SessionStateStoreScript.SessionData, context: Dictionary, entry: Dictionary, ref: Dictionary, power: float, needs: Dictionary, search: Dictionary = {}, tile_index: int = -1) -> Dictionary:
	return AiEngine.native_writing(&"AiHeroRules._candidate", [session, context, entry, ref, power, needs, search, tile_index])

static func _guard_power(guard: Dictionary) -> float:
	return AiEngine.native_writing(&"AiHeroRules._guard_power", [guard])

## What a guard protects. A linked target counts on its own; otherwise (the
## way generated maps place guards) every site standing in the guard's zone,
## since the hero reaches it only through this fight.
static func _guarded_object_value(session: SessionStateStoreScript.SessionData, guard: Dictionary, needs: Dictionary, search: Dictionary = {}, guard_index: int = -1, controller: String = "") -> float:
	return AiEngine.native_writing(&"AiHeroRules._guarded_object_value", [session, guard, needs, search, guard_index, controller])

## Whether some rival still holds a town this player has never seen.
static func _rival_towns_unknown(session: SessionStateStoreScript.SessionData, context: Dictionary) -> bool:
	return AiEngine.native_writing(&"AiHeroRules._rival_towns_unknown", [session, context])

## A context for a run of `_position_seen` questions during which no hero of
## the player moves or changes: the player's active heroes are listed once and
## each one's scouting radius is worked out once, by its place in that list.
const SCOUT_RADII_KEY := "scout_radii"

# --- Knowledge ----------------------------------------------------------------

static func _reveal(session: SessionStateStoreScript.SessionData, context: Dictionary, point: Dictionary, radius: int) -> void:
	TurnEngine.native_writing(&"AiHeroRules._reveal", [session, context, point, radius])

# --- Movement -----------------------------------------------------------------

static func _follow_plan(session: SessionStateStoreScript.SessionData, context: Dictionary, index: int, plan: Dictionary) -> Dictionary:
	return TurnEngine.native_writing(&"AiHeroRules._follow_plan", [session, context, index, plan])

## The hostile hero whose zone this tile lies in, as a plan to fight it: a hero
## that steps next to one fights it there, as the human does.
static func _hostile_hero_beside(session: SessionStateStoreScript.SessionData, context: Dictionary, tile: Vector2i, level: int) -> Dictionary:
	return TurnEngine.native_writing(&"AiHeroRules._hostile_hero_beside", [session, context, tile, level])

## Static blocking for one level, built once per enemy turn: impassable terrain
## (rock, water) and every body the human's movement treats as solid, except
## armies, which move and are added for each search.
static func _level_surface(session: SessionStateStoreScript.SessionData, context: Dictionary, level: int) -> Dictionary:
	return AiEngine.native_writing(&"AiHeroRules._level_surface", [session, context, level])

## What a resource site's content row says about crossing it, by site id:
## [known site, walk-across family, persistent or repeatable]. Searches check
## every site stop on every search, so the rows are read once and the memo is
## dropped whenever the content cache reloads. A node's payload never changes
## these keys (ResourceNodePayloadRules.site_for_node).
static var _site_pass_memo := {}
static var _site_pass_sources := []

## The decision's record of which site stops on this level are open
## (`_choose_plan`), shared by every search of the decision; empty outside a
## decision. Kept with the level's site list it was made for.
const SITE_PASS_DECISION_KEY := "decision_site_pass"

## Breadth-first search over the hero's level. Object entrances, armies,
## guard zones and heroes end a route: they can be the destination, never a
## tile to walk through. Each step costs one movement point, as for the human.
## The player's own heroes inside its towns stand in no one's way. With
## `past_own_heroes` the player's other heroes do not count at all: the search
## then shows what the hero could reach if they stepped aside. The masks and
## the walk run in the native rules library (AurelionRules.ai_search_masks and
## ai_search_walk, src/gdextension/rules/core/ai_search.cpp).
static func _search(session: SessionStateStoreScript.SessionData, context: Dictionary, entry: Dictionary, radius: int, past_own_heroes: bool = false) -> Dictionary:
	return AiEngine.native_writing(&"AiHeroRules._search", [session, context, entry, radius, past_own_heroes])

static func _is_water_index(surface: Dictionary, tile_index: int) -> bool:
	var water: PackedByteArray = surface.get("water", PackedByteArray())
	return tile_index < water.size() and water[tile_index] != 0

static func _path_to(search: Dictionary, tile_index: int) -> Array:
	return AiEngine.native_writing(&"AiHeroRules._path_to", [search, tile_index])

# --- Interactions -------------------------------------------------------------

static func _take_artifact(session: SessionStateStoreScript.SessionData, context: Dictionary, index: int, plan: Dictionary) -> Dictionary:
	return TurnEngine.native_writing(&"AiHeroRules._take_artifact", [session, context, index, plan])

static func _record_hero_defeat(session: SessionStateStoreScript.SessionData, controller: String, entry: Dictionary) -> void:
	TurnEngine.native_writing(&"AiHeroRules._record_hero_defeat", [session, controller, entry])

# --- Auto-resolved battles ----------------------------------------------------

static func _neutral_army(encounter: Dictionary) -> Dictionary:
	return AiEngine.native_writing(&"AiHeroRules._neutral_army", [encounter])

# --- Strength -----------------------------------------------------------------

## Fighting value: per creature its health, damage, defense, speed and
## initiative (POWER_* above), shooters RANGED_POWER times, raised by the
## leading hero's command and spells.
static func army_power(stacks: Variant, commander: Variant = {}) -> float:
	return AiEngine.native_writing(&"AiHeroRules.army_power", [stacks, commander])

## Damage a hero's spells add per round over a typical battle: the strongest
## battle damage spell it knows and can pay for, cast once a round while its
## mana lasts. army_power syncs the memos first.
static func _spell_damage_per_round(commander: Dictionary) -> float:
	return AiEngine.native_writing(&"AiHeroRules._spell_damage_per_round", [commander])

## army_power reads each unit and spell from content millions of times a game,
## so their figures are memoized and dropped whenever the content cache reloads.
static var _unit_power_memo := {}
static var _damage_spell_memo := {}
static var _power_memo_sources := []

static func hero_power(entry: Dictionary) -> float:
	return AiEngine.native_writing(&"AiHeroRules.hero_power", [entry])

# --- Helpers ------------------------------------------------------------------

static func _resource_needs(session: SessionStateStoreScript.SessionData, context: Dictionary) -> Dictionary:
	return AiEngine.native_writing(&"AiHeroRules._resource_needs", [session, context])

static func _merge_stacks_into(destination: Variant, additions: Variant) -> Dictionary:
	return AiEngine.native_writing(&"AiHeroRules._merge_stacks_into", [destination, additions])

static func _find_town(session: SessionStateStoreScript.SessionData, placement_id: String) -> Dictionary:
	return TurnEngine.native_writing(&"AiHeroRules._find_town", [session, placement_id])
