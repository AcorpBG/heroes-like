extends Node
## The start hero's growth seed on generated maps (2026-10-10). The start hero
## was built before its session existed and drew a random growth seed, so two
## new games on the same map and seed levelled it up differently: the
## quality_medium full matches on Windows and Linux played alike for 224 driver
## actions and parted on day 28. Starts two new games from that setup and
## checks that the session id, the start hero's seed and its level-up gains
## are the same, that the seed has the form every hire's seed has, that a save
## keeps it and that a seed saved before the fix loads unchanged.
##
## Run with an isolated user profile: the save checks write manual slot 3.

const ScenarioSelectRulesScript = preload("res://scripts/core/ScenarioSelectRules.gd")
const REPORT_ID := "GENERATED_START_HERO_GROWTH_SEED_REPORT"
## tests/generated_full_match_quality.py, case quality_medium.
const SEED := "10"
const LEVEL := 12
## The random seed the Windows quality_medium run saved for its start hero.
const OLD_SAVE_SEED := "7460765e9397b4a7"
const SAVE_SLOT := 3

var _checks := 0
var _failures := []
var _report := {}

func _ready() -> void:
	call_deferred("_run")

func _check(condition: bool, label: String) -> void:
	_checks += 1
	if not condition:
		_failures.append(label)
		push_error("%s check failed: %s" % [REPORT_ID, label])

func _run() -> void:
	var session = _check_generated_games()
	if session != null:
		_check_save_load(session)
	_report.merge({"ok": _failures.is_empty(), "checks": _checks, "failures": _failures}, true)
	print("%s %s" % [REPORT_ID, JSON.stringify(_report)])
	get_tree().quit(0 if _failures.is_empty() else 1)

## Two new games from the same seed, each generating its map anew as the setup
## screen does. Returns the first game's session.
func _check_generated_games():
	var config := ScenarioSelectRulesScript.build_random_map_player_config(SEED, "", "", 2, "land", false, "homm3_medium", ScenarioSelectRulesScript.RANDOM_MAP_TEMPLATE_SELECTION_MODE_CATALOG_AUTO, "faction_embercourt", "")
	config["monster_strength"] = "normal"
	var sessions := []
	var games := []
	for index in range(2):
		var setup := ScenarioSelectRulesScript.build_random_map_skirmish_setup_with_retry(config, "normal", ScenarioSelectRulesScript.RANDOM_MAP_PLAYER_RETRY_POLICY)
		_check(bool(setup.get("ok", false)), "game %d: the map generates" % (index + 1))
		if not bool(setup.get("ok", false)):
			return null
		var session = ScenarioSelectRulesScript.start_random_map_skirmish_session_from_setup(setup)
		_check(session.scenario_id != "", "game %d: the game starts" % (index + 1))
		if session.scenario_id == "":
			return null
		sessions.append(session)
		games.append(_start_hero_row(session, String(setup.get("map_ref", {}).get("map_id", ""))))
	_report["games"] = games
	var first: Dictionary = games[0]
	var second: Dictionary = games[1]
	for index in range(2):
		var game: Dictionary = games[index]
		_check(String(game.map_id) != "" and String(game.session_id) == "native_rmg_session_%s" % game.map_id, "game %d: the session id names the map (%s)" % [index + 1, game.session_id])
		_check(String(game.growth_seed) == "%s|%s|%s" % [game.session_id, game.scenario_id, game.hero_id], "game %d: the start hero's seed is session|scenario|hero, as a hire's (%s)" % [index + 1, game.growth_seed])
		_check(String(game.growth_seed) == String(game.hire_seed), "game %d: the seed equals new_growth_seed for the hero" % (index + 1))
		_check(String(game.mirror_growth_seed) == String(game.growth_seed), "game %d: the active hero mirror holds the same seed" % (index + 1))
		_check(_total(game.gains) == LEVEL - 1, "game %d: %d level-ups give %d command points (%s)" % [index + 1, LEVEL - 1, LEVEL - 1, game.gains])
	_check(first.map_id == second.map_id, "both games generate the same map (%s, %s)" % [first.map_id, second.map_id])
	_check(first.session_id == second.session_id, "both games have the same session id (%s, %s)" % [first.session_id, second.session_id])
	_check(first.growth_seed == second.growth_seed, "both start heroes have the same seed (%s, %s)" % [first.growth_seed, second.growth_seed])
	_check(first.rolls == second.rolls, "both start heroes roll the same level-ups (%s, %s)" % [first.rolls, second.rolls])
	_check(first.gains == second.gains and first.specialties == second.specialties, "both start heroes reach level %d alike (%s %s, %s %s)" % [LEVEL, first.gains, first.specialties, second.gains, second.specialties])
	var differences := _differences(sessions[0].to_dict(), sessions[1].to_dict(), "", [])
	_report["start_state_sha256"] = JSON.stringify(sessions[0].to_dict()).sha256_text()
	_check(differences.is_empty(), "both new games start in the same state (differs at %s)" % [differences])
	return sessions[0]

func _start_hero_row(session, map_id: String) -> Dictionary:
	var hero := HeroCommandRules.active_hero(session)
	var hero_id := String(hero.get("id", ""))
	var start: Dictionary = hero.get("command", {})
	var grown := HeroProgressionRules.advance_to_level(hero, LEVEL)
	var gains := {}
	for stat in ["attack", "defense", "power", "knowledge"]:
		gains[stat] = int(grown.get("command", {}).get(stat, 0)) - int(start.get(stat, 0))
	return {
		"map_id": map_id,
		"session_id": String(session.session_id),
		"scenario_id": String(session.scenario_id),
		"hero_id": hero_id,
		"growth_seed": String(hero.get("growth_seed", "")),
		"mirror_growth_seed": String(session.overworld.get("hero", {}).get("growth_seed", "")),
		"hire_seed": HeroCommandRules.new_growth_seed(hero_id, session),
		"rolls": _rolls(hero),
		"gains": gains,
		"specialties": grown.get("specialties", []),
	}

func _rolls(hero: Dictionary) -> Array:
	var rolls := []
	for level in range(2, LEVEL + 1):
		rolls.append(HeroProgressionRules.command_gain_stat(hero, level))
	return rolls

func _total(gains: Dictionary) -> int:
	var total := 0
	for stat in gains.keys():
		total += int(gains[stat])
	return total

## Up to ten paths where two saved sessions differ.
func _differences(left: Variant, right: Variant, path: String, found: Array) -> Array:
	if found.size() >= 10:
		return found
	if left is Dictionary and right is Dictionary:
		for key in left.keys():
			if not right.has(key):
				found.append("%s/%s (only in the first)" % [path, key])
			else:
				_differences(left[key], right[key], "%s/%s" % [path, key], found)
		for key in right.keys():
			if not left.has(key):
				found.append("%s/%s (only in the second)" % [path, key])
	elif left is Array and right is Array and left.size() == right.size():
		for index in range(left.size()):
			_differences(left[index], right[index], "%s/%d" % [path, index], found)
	elif typeof(left) != typeof(right) or left != right:
		found.append(path)
	return found

## A save keeps the new seed, and a seed saved before the fix (drawn at
## random) loads unchanged. A hero saved before growth seeds existed is seeded
## from the session on load, in the same form.
func _check_save_load(session) -> void:
	var hero := HeroCommandRules.active_hero(session)
	var hero_id := String(hero.get("id", ""))
	var seed := String(hero.get("growth_seed", ""))
	var restored = _saved_and_loaded(session)
	_check(restored != null and String(HeroCommandRules.active_hero(restored).get("growth_seed", "")) == seed, "loading keeps the start hero's seed (%s)" % seed)
	_check(restored != null and _rolls(HeroCommandRules.active_hero(restored)) == _rolls(hero), "the loaded start hero rolls the same level-ups")
	var old = _copy_with_start_seed(session, OLD_SAVE_SEED)
	restored = _saved_and_loaded(old)
	_check(restored != null and String(HeroCommandRules.active_hero(restored).get("growth_seed", "")) == OLD_SAVE_SEED, "a seed saved before the fix loads unchanged (%s)" % (String(HeroCommandRules.active_hero(restored).get("growth_seed", "")) if restored != null else "no session"))
	_check(restored != null and _rolls(HeroCommandRules.active_hero(restored)) == _rolls(HeroCommandRules.active_hero(old)), "a hero saved before the fix rolls from its saved seed")
	var legacy = _copy_with_start_seed(session, "")
	restored = _saved_and_loaded(legacy)
	_check(restored != null and String(HeroCommandRules.active_hero(restored).get("growth_seed", "")) == HeroCommandRules.new_growth_seed(hero_id, restored), "a hero saved without a seed is seeded from the session on load (%s)" % (String(HeroCommandRules.active_hero(restored).get("growth_seed", "")) if restored != null else "no session"))
	_report["save_load"] = {"slot": SAVE_SLOT, "seed": seed, "old_save_seed": OLD_SAVE_SEED}

func _saved_and_loaded(session):
	var saved := SaveService.save_runtime_manual_session(session, SAVE_SLOT)
	_check(bool(saved.get("ok", false)), "the game saves to slot %d (%s)" % [SAVE_SLOT, saved.get("message", "")])
	return SaveService.restore_manual_session(SAVE_SLOT) if bool(saved.get("ok", false)) else null

## A copy of `session` whose start hero holds `seed` (none when empty), in its
## roster entry and in the active hero mirror alike.
func _copy_with_start_seed(session, seed: String):
	var copy := SessionStateStore.SessionData.new()
	copy.from_dict(session.to_dict())
	for hero in copy.overworld.get("player_heroes", []) + [copy.overworld.get("hero", {})]:
		if hero is Dictionary and String(hero.get("id", "")) == String(copy.overworld.get("active_hero_id", "")):
			if seed == "":
				hero.erase("growth_seed")
			else:
				hero["growth_seed"] = seed
	return copy
