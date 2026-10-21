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
const WaterTravel = preload("res://scripts/core/WaterTravelRules.gd")
const NativeRules = preload("res://scripts/core/NativeRules.gd")
const AiEngine = preload("res://scripts/core/AiEngine.gd")

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
## town held beyond the first, at most this many. They take garrisons along,
## defend towns and take what they can beat instead of handing their troops to
## the main hero; captured towns of other factions muster creatures the main
## army has no slot for.
static var FIELD_ARMY_MAX: int
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
## desired_hero_count: a main hero, one more per town up to
## HERO_COUNT_TOWN_MAX towns, and one more from day EXTRA_HERO_DAY.
static var HERO_COUNT_TOWN_MAX: int
static var EXTRA_HERO_DAY: int
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
	var set_name := String(state.get(WEIGHT_SET_KEY, ""))
	if set_name == "":
		set_name = DEFAULT_WEIGHT_SET
	var revision: int = ContentService.get_content_revision()
	if set_name == _weight_set_name and revision == _weight_set_revision:
		return
	if revision != _weight_set_revision:
		_weight_sets = {}
		_weight_set_revision = revision
	if not _weight_sets.has(set_name):
		_weight_sets[set_name] = _resolved_weight_set(set_name)
	_apply_weights(_weight_sets[set_name])
	_weight_set_name = set_name

## The default set with a named set's values over it (resource_values merge by
## resource); an unknown name plays the default.
static func _resolved_weight_set(set_name: String) -> Dictionary:
	var sets: Dictionary = ContentService.load_json(WEIGHTS_PATH).get("sets", {})
	var resolved: Dictionary = sets.get(DEFAULT_WEIGHT_SET, {}).duplicate(true)
	if set_name == DEFAULT_WEIGHT_SET:
		return resolved
	if not (sets.get(set_name) is Dictionary):
		push_error("AI weight set %s is not in %s; the default set plays." % [set_name, WEIGHTS_PATH])
		return resolved
	var changes: Dictionary = sets[set_name]
	for key in changes:
		if changes[key] is Dictionary and resolved.get(key) is Dictionary:
			resolved[key].merge(changes[key], true)
		else:
			resolved[key] = changes[key]
	return resolved

## JSON numbers arrive as floats: whole-number weights go back to int here.
static func _apply_weights(weights: Dictionary) -> void:
	MAX_DECISIONS_PER_DAY = int(weights["max_decisions_per_day"])
	SEARCH_DAYS = int(weights["search_days"])
	FAR_SEARCH_DAYS = int(weights["far_search_days"])
	STRATEGIC_DAYS = int(weights["strategic_days"])
	MIN_SEARCH_RADIUS = int(weights["min_search_radius"])
	MAX_GATES_WEIGHED = int(weights["max_gates_weighed"])
	ROUTE_DETOUR = float(weights["route_detour"])
	ROUTE_UNEXPLORED_MIN = int(weights["route_unexplored_min"])
	ROUTE_REVISIT_DAYS = int(weights["route_revisit_days"])
	SHORE_STEP_SHARE = float(weights["shore_step_share"])
	BOAT_SAVING_DAYS = int(weights["boat_saving_days"])
	GUARD_WIN_RATIO = float(weights["guard_win_ratio"])
	HERO_ATTACK_RATIO = float(weights["hero_attack_ratio"])
	TOWN_ATTACK_RATIO = float(weights["town_attack_ratio"])
	THREAT_RATIO = float(weights["threat_ratio"])
	TOWN_BASE_VALUE = float(weights["town_base_value"])
	TOWN_HORIZON_WEEKS = float(weights["town_horizon_weeks"])
	ELIMINATION_VALUE = float(weights["elimination_value"])
	FIELD_ARMY_MAX = int(weights["field_army_max"])
	DEFENSE_HORIZON_DAYS = int(weights["defense_horizon_days"])
	DEFENSE_MARGIN = float(weights["defense_margin"])
	DEFENSE_BASELINE_PER_WEEK = float(weights["defense_baseline_per_week"])
	DEFENSE_SHARE_MAX = float(weights["defense_share_max"])
	DEFENSE_SHARE_MAX_MAIN = float(weights["defense_share_max_main"])
	JOIN_BASE_VALUE = float(weights["join_base_value"])
	FIELD_SHARE_MAX = float(weights["field_share_max"])
	SPELL_BURST_PREVIEW_SHARE = float(weights["spell_burst_preview_share"])
	HOMELESS_TOWN_MULTIPLIER = float(weights["homeless_town_multiplier"])
	THREAT_KILL_SHARE = float(weights["threat_kill_share"])
	DANGER_RATIO = float(weights["danger_ratio"])
	GUARD_SHARE_MAX = float(weights["guard_share_max"])
	MAIN_ARMY_SHARE = float(weights["main_army_share"])
	TROOP_VALUE_PER_POWER = float(weights["troop_value_per_power"])
	BUILD_HORIZON_WEEKS = float(weights["build_horizon_weeks"])
	SHORT_RESOURCE_MULTIPLIER = float(weights["short_resource_multiplier"])
	STARVED_TOWN_WEEKLY_TROOPS = float(weights["starved_town_weekly_troops"])
	CLEAR_WIN_RATIO = float(weights["clear_win_ratio"])
	LOSS_ESTIMATE_FACTOR = float(weights["loss_estimate_factor"])
	LOSS_ESTIMATE_PER_RATIO = float(weights["loss_estimate_per_ratio"])
	FREE_FIGHT_MAX_RATIO = float(weights["free_fight_max_ratio"])
	MAX_FREE_FIGHT_PREVIEWS = int(weights["max_free_fight_previews"])
	MAX_FIGHT_VETOES = int(weights["max_fight_vetoes"])
	MAX_IDLE_PREVIEWS = int(weights["max_idle_previews"])
	IDLE_FIGHT_MIN_KEPT = float(weights["idle_fight_min_kept"])
	HOME_WAIT_RADIUS = int(weights["home_wait_radius"])
	MEET_VALUE_CAP = float(weights["meet_value_cap"])
	GOAL_CONTINUITY_BONUS = float(weights["goal_continuity_bonus"])
	EXPLORE_VALUE = float(weights["explore_value"])
	HUNT_EXPLORE_VALUE = float(weights["hunt_explore_value"])
	HUNT_START_DAY = int(weights["hunt_start_day"])
	HUNT_FULL_DAY = int(weights["hunt_full_day"])
	SIGHTING_MEMORY_DAYS = int(weights["sighting_memory_days"])
	PASSAGE_BASE_VALUE = float(weights["passage_base_value"])
	PASSAGE_UNEXPLORED_TILE_VALUE = float(weights["passage_unexplored_tile_value"])
	PASSAGE_KNOWN_SITE_SHARE = float(weights["passage_known_site_share"])
	PASSAGE_VALUE_CAP = float(weights["passage_value_cap"])
	HIDDEN_RIVAL_SHARE = float(weights["hidden_rival_share"])
	HIDDEN_RIVAL_TILES = int(weights["hidden_rival_tiles"])
	PASSAGE_TILE_CAP = int(weights["passage_tile_cap"])
	SCROLL_SPELL_BASE_VALUE = float(weights["scroll_spell_base_value"])
	SCROLL_SPELL_TIER_VALUE = float(weights["scroll_spell_tier_value"])
	HERO_COUNT_TOWN_MAX = int(weights["hero_count_town_max"])
	EXTRA_HERO_DAY = int(weights["extra_hero_day"])
	STARVED_TOWN_TROOP_MULTIPLIER = float(weights["starved_town_troop_multiplier"])
	MAGE_GUILD_BASE_VALUE = float(weights["mage_guild_base_value"])
	MAGE_GUILD_TIER_VALUE = float(weights["mage_guild_tier_value"])
	READINESS_VALUE = float(weights["readiness_value"])
	OPENS_BUILDING_VALUE = float(weights["opens_building_value"])
	UPGRADE_VALUE_WEEKS = float(weights["upgrade_value_weeks"])
	UPGRADE_BASE_VALUE = float(weights["upgrade_base_value"])
	THREAT_REACH_MARGIN = int(weights["threat_reach_margin"])
	THREAT_MIN_REACH = int(weights["threat_min_reach"])
	RIVAL_TOWN_TILES_PER_DAY = int(weights["rival_town_tiles_per_day"])
	AVOID_DAYS = int(weights["avoid_days"])
	GATE_HOME_DETOUR = int(weights["gate_home_detour"])
	IDLE_FIGHT_DISTANCE_COST = float(weights["idle_fight_distance_cost"])
	FIGHT_MIN_KEPT = float(weights["fight_min_kept"])
	ARTIFACT_VALUE = float(weights["artifact_value"])
	ARTIFACT_PRIZE_VALUE = float(weights["artifact_prize_value"])
	PLAYER_HERO_KILL_VALUE = float(weights["player_hero_kill_value"])
	AI_HERO_KILL_VALUE = float(weights["ai_hero_kill_value"])
	HERO_KILL_TROOP_SHARE = float(weights["hero_kill_troop_share"])
	HANDOVER_TROOP_SHARE = float(weights["handover_troop_share"])
	GARRISON_PICKUP_SHARE = float(weights["garrison_pickup_share"])
	COURIER_TROOP_SHARE = float(weights["courier_troop_share"])
	MIN_TROOP_ERRAND_VALUE = float(weights["min_troop_errand_value"])
	DWELLING_BASE_VALUE = float(weights["dwelling_base_value"])
	DWELLING_WEEK_SHARE = float(weights["dwelling_week_share"])
	VISIT_BUILDING_BASE_VALUE = float(weights["visit_building_base_value"])
	SITE_INCOME_DAYS = float(weights["site_income_days"])
	SITE_CONTROL_VALUE = float(weights["site_control_value"])
	RIVAL_SITE_MULTIPLIER = float(weights["rival_site_multiplier"])
	GUARD_FIGHT_BASE_VALUE = float(weights["guard_fight_base_value"])
	GUARDED_VALUE_SHARE = float(weights["guarded_value_share"])
	GUARDED_NEUTRAL_TOWN_VALUE = float(weights["guarded_neutral_town_value"])
	GUARDED_RIVAL_TOWN_VALUE = float(weights["guarded_rival_town_value"])
	HUMAN_TOWN_BONUS = float(weights["human_town_bonus"])
	var resource_values := {}
	var values: Dictionary = weights["resource_values"]
	for key in values:
		resource_values[String(key)] = float(values[key])
	RESOURCE_VALUES = resource_values
	AdventureRules.apply_ai_weights(weights)
	TownServices.apply_ai_weights(weights)
	VisitBuildings.apply_ai_weights(weights)
	CreatureDwellings.apply_ai_weights(weights)

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
	return AiEngine.native_writing(&"AiHeroRules.active_hero_entries", [session, controller])

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
	return AiEngine.native_writing(&"AiHeroRules._resolved_lookup", [session])

static func _entry_index(session: SessionStateStoreScript.SessionData, placement_id: String) -> int:
	return AiEngine.native_writing(&"AiHeroRules._entry_index", [session, placement_id])

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
	_use_weights(state)
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
	return AiEngine.native_writing(&"AiHeroRules._movement_max", [entry])

static func _new_context(session: SessionStateStoreScript.SessionData, config: Dictionary, state: Dictionary) -> Dictionary:
	_use_weights(state)
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
	var wanted := _desired_hero_count(session, controller)
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
	_use_weights(_turn_rules()._find_state(session.overworld.get("enemy_states", []), controller))
	return _desired_hero_count(session, controller)

static func _desired_hero_count(session: SessionStateStoreScript.SessionData, controller: String) -> int:
	var towns: int = _turn_rules()._owned_town_count(session, controller)
	var wanted := 1 + mini(towns, HERO_COUNT_TOWN_MAX) + (1 if int(session.day) >= EXTRA_HERO_DAY else 0)
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
			troops *= STARVED_TOWN_TROOP_MULTIPLIER
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
			value += MAGE_GUILD_BASE_VALUE + MAGE_GUILD_TIER_VALUE * float(building.get("spell_tier", 0))
			if value > 0.0 and reason == "development":
				reason = "spells"
		value += READINESS_VALUE * float(building.get("readiness_bonus", 0))
		var market := _market_value(building, short)
		if market > 0.0:
			value += market
			reason = "market"
		value += OPENS_BUILDING_VALUE * float(_opens_count(town, building_id, trial_built))
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
	return AiEngine.native_writing(&"AiHeroRules._trial_growth", [town])

static func _trial_income(town: Dictionary) -> Dictionary:
	var development = _turn_rules().TownDevelopment
	if development.is_current(town):
		return development.income(town)
	return _overworld_rules().town_income(town)

static func _recruit_set_value(recruits: Dictionary) -> float:
	return AiEngine.native_writing(&"AiHeroRules._recruit_set_value", [recruits])

static func _upgrade_value(town: Dictionary, building: Dictionary) -> float:
	var upgraded := String(building.get("unlock_unit_id", ""))
	var base_building := ContentService.get_building(String(building.get("upgrade_from", "")))
	var base_unit := String(base_building.get("unlock_unit_id", ""))
	if upgraded == "" or base_unit == "":
		return 0.0
	var weekly := int(ContentService.get_unit(base_unit).get("growth", 1))
	var gain := army_power([{"unit_id": upgraded, "count": weekly}]) - army_power([{"unit_id": base_unit, "count": weekly}])
	return maxf(0.0, gain) * TROOP_VALUE_PER_POWER * UPGRADE_VALUE_WEEKS + UPGRADE_BASE_VALUE

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
	return AiEngine.native_writing(&"AiHeroRules._build_value", [payload])

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
	return AiEngine.native_writing(&"AiHeroRules._market_cover", [session, town, pool, cost, apply, market_memo])

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
	return AiEngine.native_writing(&"AiHeroRules._town_hero_defender_index", [session, town, controller])

## Whether nothing stands in the town's doorway. With `own_controller` set, that
## player's own heroes there do not count: they are in the town, and a hire
## joins them there, as the human's hires join heroes visiting a town.
static func _town_entrance_free(session: SessionStateStoreScript.SessionData, town: Dictionary, own_controller: String = "") -> bool:
	return AiEngine.native_writing(&"AiHeroRules._town_entrance_free", [session, town, own_controller])

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
	return AiEngine.native_writing(&"AiHeroRules._garrison_pickup", [stacks, garrison])

## A lesser hero carries a town's troops out to the main hero when the main
## hero is more than a day's march from the town, as a human chains them.
static func _ferries_from(session: SessionStateStoreScript.SessionData, context: Dictionary, town: Dictionary, main_id: String) -> bool:
	return AiEngine.native_writing(&"AiHeroRules._ferries_from", [session, context, town, main_id])

## Lesser heroes that keep an army of their own: one per town held beyond the
## first, up to FIELD_ARMY_MAX, the most experienced first (the strongest army
## among equals), so the same heroes keep the job from day to day.
static func _field_hero_ids(session: SessionStateStoreScript.SessionData, controller: String) -> Array:
	return AiEngine.native_writing(&"AiHeroRules._field_hero_ids", [session, controller])

static func _decision_field_ids(session: SessionStateStoreScript.SessionData, context: Dictionary) -> Array:
	return AiEngine.native_writing(&"AiHeroRules._decision_field_ids", [session, context])

## The share of a hero's army health the other side's commander could take
## with one cast of its strongest battle damage spell it has mana for. On a
## medium map a hero with six cadets attacked one with a single Shard Warden at
## five times its strength, unpreviewed, and lost everything to one Bell Lance
## (70 damage): spread over four rounds the spell had looked like 20 a round.
static func _burst_share(entry: Dictionary, commander: Variant) -> float:
	return AiEngine.native_writing(&"AiHeroRules._burst_share", [entry, commander])

## The main army is led by the most experienced hero, the strongest army among
## equals. Going by army alone, a lesser hero carrying a big garrison out to
## the main hero became the main hero itself, kept the troops, and left the
## hero with the levels and the fights behind with nothing.
static func _main_hero_id(session: SessionStateStoreScript.SessionData, controller: String) -> String:
	return AiEngine.native_writing(&"AiHeroRules._main_hero_id", [session, controller])

static func _weakest_stack_index(stacks: Array) -> int:
	return AiEngine.native_writing(&"AiHeroRules._weakest_stack_index", [stacks])

static func _town_threatened(session: SessionStateStoreScript.SessionData, context: Dictionary, town: Dictionary) -> bool:
	return AiEngine.native_writing(&"AiHeroRules._town_threatened", [session, context, town])

## The strongest hostile hero that threatens the town ({} when none does):
## position, level, strength and reach.
static func _strongest_threat(session: SessionStateStoreScript.SessionData, context: Dictionary, town: Dictionary) -> Dictionary:
	return AiEngine.native_writing(&"AiHeroRules._strongest_threat", [session, context, town])

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
	return AiEngine.native_writing(&"AiHeroRules._leave_defense", [session, context, town, stacks, garrison, is_main])

## Facts that hold for one decision; heroes and garrisons change between them.
static func _decision_main_id(session: SessionStateStoreScript.SessionData, context: Dictionary) -> String:
	return AiEngine.native_writing(&"AiHeroRules._decision_main_id", [session, context])

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
			_avoid_target(session, placement_id, String(plan.get("id", "")), int(session.day) + AVOID_DAYS)
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
	return AiEngine.native_writing(&"AiHeroRules._plans_far", [session, context, entry])

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
	return AiEngine.native_writing(&"AiHeroRules._gate_candidate", [session, context, entry, search, movement_max, beyond_radius])

## How much a fight on the way to an objective worth `value` may cost
## (`_expected_loss_value`): the share of it the fight itself is credited with
## when the hero stands before the guard (`_war_paths`), rounded down to a
## power of two so that few limits need their own stretches.
static func _route_loss_limit(value: float) -> float:
	return AiEngine.native_writing(&"AiHeroRules._route_loss_limit", [value])

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

## The stretch ("level:first tile") a tile lies on for a hero of this
## strength and loss limit (`_level_stretches`), "" where nothing stands.
static func _stretch_key(session: SessionStateStoreScript.SessionData, context: Dictionary, level: int, tile: int, power: float, loss_limit: float, entry: Dictionary = {}) -> String:
	return AiEngine.native_writing(&"AiHeroRules._stretch_key", [session, context, level, tile, power, loss_limit, entry])

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
			far_distance = GATE_HOME_DETOUR * maxi(absi(exit.x - int(door.get("x", 0))), absi(exit.y - int(door.get("y", 0)))) + movement_max * FAR_SEARCH_DAYS
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
	_avoid_target(session, String(entry.get("placement_id", "")), String(plan.id), int(session.day) + AVOID_DAYS)
	return false

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
	return AiEngine.native_writing(&"AiHeroRules._dangers", [session, context, entry])

## Whether a tile lies where one of `dangers` can reach next turn.
static func _in_danger(dangers: Array, x: int, y: int, level: int) -> bool:
	return AiEngine.native_writing(&"AiHeroRules._in_danger", [dangers, x, y, level])

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
		_avoid_target(session, String(entry.get("placement_id", "")), String(best.get("id", "")), int(session.day) + AVOID_DAYS)
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
	options.sort_custom(func(a, b): return float(a.value) - float(a.distance) * IDLE_FIGHT_DISTANCE_COST > float(b.value) - float(b.distance) * IDLE_FIGHT_DISTANCE_COST)
	for option in options.slice(0, MAX_IDLE_PREVIEWS):
		if _fight_looks_good(session, context, entry, option, true):
			return option
		_avoid_target(session, String(entry.get("placement_id", "")), String(option.id), int(session.day) + AVOID_DAYS)
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
	return AiEngine.native_writing(&"AiHeroRules._own_town_doors", [session, controller, level, size])

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
	AiEngine.native_writing(&"AiHeroRules._profile_add", [context, key, started])

## With `reach` set, stops farther away count only for `far_kinds`: towns to
## take and hostile heroes, and unexplored ground while a rival's towns are
## unseen, as `_strategic_candidate` weighs them (`_beyond_gate`).
static func _best_candidate(session: SessionStateStoreScript.SessionData, context: Dictionary, entry: Dictionary, search: Dictionary, movement_max: int, reach: int = -1, far_kinds: bool = false) -> Dictionary:
	return AiEngine.native_writing(&"AiHeroRules._best_candidate", [session, context, entry, search, movement_max, reach, far_kinds])

static func _in_hero_zone(search: Dictionary, tile_index: int) -> bool:
	return AiEngine.native_writing(&"AiHeroRules._in_hero_zone", [search, tile_index])

## The nearest reachable tile at the edge of what this player has seen: a
## human sends idle heroes to scout, so does the AI.
static func _exploration_candidate(session: SessionStateStoreScript.SessionData, context: Dictionary, entry: Dictionary, search: Dictionary) -> Dictionary:
	return AiEngine.native_writing(&"AiHeroRules._exploration_candidate", [session, context, entry, search])

## `tile_index` is the reached tile of the stop, when it is known: a site
## standing in the way is worth the ground it opens as well (`_site_door_value`).
static func _candidate(session: SessionStateStoreScript.SessionData, context: Dictionary, entry: Dictionary, ref: Dictionary, power: float, needs: Dictionary, search: Dictionary = {}, tile_index: int = -1) -> Dictionary:
	return AiEngine.native_writing(&"AiHeroRules._candidate", [session, context, entry, ref, power, needs, search, tile_index])

## Every creature but one of the weakest kind.
static func _split_for_handover(stacks: Variant) -> Dictionary:
	return AiEngine.native_writing(&"AiHeroRules._split_for_handover", [stacks])

## What beating a neutral army is worth to the hero, before travel: its
## reward, what it protects and the ground it opens, less the troops the fight
## should cost. Below zero when not worth it; NAN when the hero cannot take it.
static func _guard_fight_value(session: SessionStateStoreScript.SessionData, context: Dictionary, entry: Dictionary, index: int, power: float, needs: Dictionary, search: Dictionary = {}) -> float:
	return AiEngine.native_writing(&"AiHeroRules._guard_fight_value", [session, context, entry, index, power, needs, search])

static func _guard_power(guard: Dictionary) -> float:
	return AiEngine.native_writing(&"AiHeroRules._guard_power", [guard])

## Troop value a fight should cost the stronger side. Under Lanchester's
## square law an army facing one r times its strength loses 1 - sqrt(1 - r^2)
## of its own: a few percent against a third of its strength, about a quarter
## against two thirds. It ranks the options; a previewed fight is then judged on
## what the battle really costs (`_fight_looks_good`).
## Troops a fight should cost against an army `ratio` times the hero's
## strength: Lanchester's square law (1 - sqrt(1 - r^2) of the hero's
## strength), raised to what this game's auto-resolve costs.
static func _expected_loss_value(power: float, enemy_power: float) -> float:
	return AiEngine.native_writing(&"AiHeroRules._expected_loss_value", [power, enemy_power])

## What a guard protects. A linked target counts on its own; otherwise (the
## way generated maps place guards) every site standing in the guard's zone,
## since the hero reaches it only through this fight.
static func _guarded_object_value(session: SessionStateStoreScript.SessionData, guard: Dictionary, needs: Dictionary, search: Dictionary = {}, guard_index: int = -1, controller: String = "") -> float:
	return AiEngine.native_writing(&"AiHeroRules._guarded_object_value", [session, guard, needs, search, guard_index, controller])

## A site the hero can reach whose tile ends every route over it until it is
## claimed (a pickup, a mine's doorway, an artifact) and that stands in the way
## to ground the hero cannot reach otherwise: claiming it opens that ground, as
## beating a guard does (`_passage_value`), and it is worth what that ground is.
## Until 2026-10-18 nothing counted it: on a large 3-player map (seed
## ai-match-147308053) a spell scroll, worth nothing to the computer, lay in the
## one corridor between the leader's ground and the last rival's, and neither
## side's armies, 420,000 and 184,000 strong, ever met in 200 days.
static func _site_door_value(session: SessionStateStoreScript.SessionData, context: Dictionary, entry: Dictionary, search: Dictionary, tile_index: int, needs: Dictionary) -> float:
	return AiEngine.native_writing(&"AiHeroRules._site_door_value", [session, context, entry, search, tile_index, needs])

## The key a site's doorway tile goes by among guard indices (`_opened_value`,
## `_war_paths`).
static func _site_door_key(tile_index: int) -> int:
	return AiEngine.native_writing(&"AiHeroRules._site_door_key", [tile_index])

## Reached tiles of resource and artifact sites that end routes over them and
## stand in no guard's or hostile hero's zone. Measured once per search.
static func _site_doors(search: Dictionary) -> Dictionary:
	return AiEngine.native_writing(&"AiHeroRules._site_doors", [search])

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
	return AiEngine.native_writing(&"AiHeroRules._war_paths", [session, context, entry, search, needs])

## What scouting the nearest unexplored ground is worth (see HUNT_EXPLORE_VALUE).
static func _explore_value(session: SessionStateStoreScript.SessionData, context: Dictionary) -> float:
	return AiEngine.native_writing(&"AiHeroRules._explore_value", [session, context])

## Whether some rival still holds a town this player has never seen.
static func _rival_towns_unknown(session: SessionStateStoreScript.SessionData, context: Dictionary) -> bool:
	return AiEngine.native_writing(&"AiHeroRules._rival_towns_unknown", [session, context])

## A context for a run of `_position_seen` questions during which no hero of
## the player moves or changes: the player's active heroes are listed once and
## each one's scouting radius is worked out once, by its place in that list.
const SCOUT_RADII_KEY := "scout_radii"

## Hostile heroes the controller can see, with their strength and reach.
static func _hostile_heroes(session: SessionStateStoreScript.SessionData, controller: String) -> Array:
	return AiEngine.native_writing(&"AiHeroRules._hostile_heroes", [session, controller])

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

# --- Knowledge ----------------------------------------------------------------

## A computer player knows the map only where its towns and heroes have looked,
## as the human does under fog. Explored tiles are kept per level in the enemy
## state as a bitset.
static func _explored(session: SessionStateStoreScript.SessionData, context: Dictionary, level: int) -> PackedByteArray:
	return AiEngine.native_writing(&"AiHeroRules._explored", [session, context, level])

## Whether this player has seen the town: its anchor tile or its doorway. Every
## check that asks whether a town is known uses this. Until 2026-10-17 the
## scouting check (`_rival_towns_unknown`) tested the anchor and the planners the
## doorway, so a rival town whose anchor was seen from one side and whose door
## lay out of sight was neither scouted for nor attacked: on a 6-player large map
## (seed ai-match-1305188145) the last rival's town stood 280 days against a main
## army that grew to 320,000, reachable and worth 273,000 to it.
static func _town_seen(known: PackedByteArray, town: Dictionary, size: Vector2i) -> bool:
	return AiEngine.native_writing(&"AiHeroRules._town_seen", [known, town, size])

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
	return AiEngine.native_writing(&"AiHeroRules._boat_market", [session, context, cost])

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
	return AiEngine.native_writing(&"AiHeroRules._hero_guards", [session, context, level])

## The tiles a hero standing here guards; terrain and towns do not change
## during a turn, so each answer is kept for the turn.
static func _hero_zone_tiles(session: SessionStateStoreScript.SessionData, context: Dictionary, tile: Vector2i, level: int) -> Array:
	return AiEngine.native_writing(&"AiHeroRules._hero_zone_tiles", [session, context, tile, level])

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

## What a route to this tile pays for a boat it buys at a shipyard, in the
## gold-equivalent its errand's value is weighed in.
static func _boat_price(session: SessionStateStoreScript.SessionData, context: Dictionary, search: Dictionary, tile_index: int) -> float:
	return AiEngine.native_writing(&"AiHeroRules._boat_price", [session, context, search, tile_index])

static func _is_water_index(surface: Dictionary, tile_index: int) -> bool:
	var water: PackedByteArray = surface.get("water", PackedByteArray())
	return tile_index < water.size() and water[tile_index] != 0

static func _tile_index_of(point: Dictionary, size: Vector2i) -> int:
	return AiEngine.native_writing(&"AiHeroRules._tile_index_of", [point, size])

static func _path_to(search: Dictionary, tile_index: int) -> Array:
	return AiEngine.native_writing(&"AiHeroRules._path_to", [search, tile_index])

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
			_avoid_target(session, hero_id, String(guard.get("placement_id", "")), int(session.day) + AVOID_DAYS)
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
	if army_after < army_before * FIGHT_MIN_KEPT:
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
	AiEngine.native_writing(&"AiHeroRules._note_alternative", [context, candidate, score, distance])

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
	_sync_power_memos()
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

static func _sync_power_memos() -> void:
	AiEngine.native_writing(&"AiHeroRules._sync_power_memos", [])

static func hero_power(entry: Dictionary) -> float:
	return AiEngine.native_writing(&"AiHeroRules.hero_power", [entry])

# --- Helpers ------------------------------------------------------------------

static func _resource_needs(session: SessionStateStoreScript.SessionData, context: Dictionary) -> Dictionary:
	return AiEngine.native_writing(&"AiHeroRules._resource_needs", [session, context])

static func _merge_stacks_into(destination: Variant, additions: Variant) -> Dictionary:
	return AiEngine.native_writing(&"AiHeroRules._merge_stacks_into", [destination, additions])

static func _find_town(session: SessionStateStoreScript.SessionData, placement_id: String) -> Dictionary:
	var towns: Array = session.overworld.get("towns", [])
	for index in range(towns.size()):
		if towns[index] is Dictionary and String(towns[index].get("placement_id", "")) == placement_id:
			return {"index": index, "town": towns[index]}
	return {"index": -1, "town": {}}

static func _can_afford(pool: Dictionary, cost: Dictionary) -> bool:
	return AiEngine.native_writing(&"AiHeroRules._can_afford", [pool, cost])

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
