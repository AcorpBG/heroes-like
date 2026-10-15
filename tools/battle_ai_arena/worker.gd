extends SceneTree
## Battle AI arena worker (tools/battle_ai_arena). Started by arena.py with
##   godot --headless --path <repo> -s <this file> -- <job.json> <results.jsonl>
## It plays the job's battles (scenarios.py: guards, heroes and sieges on
## generated maps) with Quick Resolve (BattleAutoResolveRules), each side's
## stacks commanded by its own BattleAiRules variant, and writes one JSON line
## per game. Nothing here is loaded by the game or the test suites.
##
## The variants are swapped in memory only: the cached BattleAiRules script is
## reloaded with the router from router.py, which forwards each AI call to the
## variant playing the acting stack's side. Game files are never written.
##
## Game scripts are loaded at runtime: a -s script compiles before autoloads exist.

const AI_PATH := "res://scripts/core/BattleAiRules.gd"
const FORT_BUILDINGS := ["building_dev_fort_1", "building_dev_fort_2", "building_dev_fort_3"]
# Each faction's town defence building (town_defense_effect) and what it needs.
const FACTION_DEFENSE := {
	"faction_embercourt": "building_dev_embercourt_unique_2",
	"faction_mireclaw": "building_dev_mireclaw_unique_2",
	"faction_sunvault": "building_dev_sunvault_unique_3",
	"faction_thornwake": "building_dev_thornwake_unique_2",
	"faction_brasshollow": "building_dev_brasshollow_unique_3",
	"faction_veilmourn": "building_dev_veilmourn_unique_3",
}
const ECHO_KEYS := ["type", "week", "player_doctrine", "enemy_doctrine", "enemy_week", "guard_ratio", "fort_level", "faction_defense"]

var _started := false
var _content: Node
var _scenario_select: Script
var _session_store: Script
var _auto_resolve: Script
var _battle_rules: Script
var _overworld: Script
var _enemy_adventure: Script
var _progression: Script
var _spells: Script
var _hero_command: Script
var _ai_heroes: Script
var _town_development: Script
var _default_variant: Script
var _router  # the reloaded BattleAiRules script; untyped so its generated statics resolve at runtime
var _out: FileAccess


func _process(_delta: float) -> bool:
	if _started:
		return false
	_started = true
	var code := _run()
	if _out != null:
		_out.close()
	quit(code)
	return true


func _run() -> int:
	var args := OS.get_cmdline_user_args()
	if args.size() < 2:
		printerr("ARENA usage: -- <job.json> <results.jsonl>")
		return 2
	var job = JSON.parse_string(FileAccess.get_file_as_string(String(args[0])))
	if not (job is Dictionary):
		printerr("ARENA cannot read job %s" % args[0])
		return 2
	_out = FileAccess.open(String(args[1]), FileAccess.WRITE)
	if _out == null:
		printerr("ARENA cannot write %s" % args[1])
		return 2
	_content = root.get_node("ContentService")
	_scenario_select = load("res://scripts/core/ScenarioSelectRules.gd")
	_session_store = load("res://scripts/core/SessionStateStore.gd")
	_auto_resolve = load("res://scripts/core/BattleAutoResolveRules.gd")
	_battle_rules = load("res://scripts/core/BattleRules.gd")
	_overworld = load("res://scripts/core/OverworldRules.gd")
	_enemy_adventure = load("res://scripts/core/EnemyAdventureRules.gd")
	_progression = load("res://scripts/core/HeroProgressionRules.gd")
	_spells = load("res://scripts/core/SpellRules.gd")
	_hero_command = load("res://scripts/core/HeroCommandRules.gd")
	_ai_heroes = load("res://scripts/core/AiHeroRules.gd")
	_town_development = load("res://scripts/core/TownDevelopmentRules.gd")
	var variants := {}
	for label in (job.get("variants", {}) as Dictionary).keys():
		var variant := _compile_variant(String(job.variants[label]))
		if variant == null:
			printerr("ARENA variant %s does not compile" % label)
			return 3
		variants[String(label)] = variant
	_default_variant = variants.get(String(job.get("default_variant", "A")))
	if not _install_router(String(job.get("router", "")), _default_variant):
		return 3
	# Map and battle setup already call the AI's helpers: route them all to the
	# default variant until a game installs its sides.
	_router._arena_install({}, _default_variant)
	_emit({"kind": "worker_ready", "boot_ms": Time.get_ticks_msec()})
	for group in job.get("groups", []):
		_play_group(group, variants, job.get("orders", [["A", "B"], ["B", "A"]]))
	return 0


func _compile_variant(path: String) -> Script:
	var source := FileAccess.get_file_as_string(path)
	if source == "":
		return null
	var script := GDScript.new()
	script.source_code = source
	return script if script.reload() == OK else null


## Reloads the cached BattleAiRules script in place with the router, so every
## script that preloaded it (BattleRules, BattleAutoResolveRules) now calls the
## router.
func _install_router(router_path: String, default_variant: Script) -> bool:
	var source := FileAccess.get_file_as_string(router_path)
	_router = load(AI_PATH)
	if source == "" or _router == null or default_variant == null:
		printerr("ARENA router missing")
		return false
	_router.source_code = source
	if _router.reload() != OK:
		printerr("ARENA router does not compile")
		return false
	return true


## One generated map, made as the skirmish menu makes it, and its battles.
func _play_group(group: Dictionary, variants: Dictionary, orders: Array) -> void:
	var started := Time.get_ticks_usec()
	_router._arena_install({}, _default_variant)
	var config = _scenario_select.build_random_map_player_config(
		String(group.get("map_seed", "arena")), "", "", int(group.get("player_count", 2)), "land", false,
		String(group.get("map_size", "homm3_small")), _scenario_select.RANDOM_MAP_TEMPLATE_SELECTION_MODE_CATALOG_AUTO,
		String(group.get("player_faction", "")), String(group.get("player_hero_id", "")), String(group.get("monster_strength", "normal"))
	)
	var setup = _scenario_select.build_random_map_skirmish_setup_with_retry(config, "normal", _scenario_select.RANDOM_MAP_PLAYER_RETRY_POLICY)
	if not bool(setup.get("ok", false)):
		_emit({"kind": "group_error", "group_id": group.get("group_id", ""), "error": "map setup failed"})
		return
	var session = _scenario_select.start_random_map_skirmish_session_from_setup(setup)
	_remove_generated_packages(session)
	_overworld.normalize_overworld_state(session)
	var ai_controller := ""
	for state in session.overworld.get("enemy_states", []):
		ai_controller = String(state.get("player_id", state.get("faction_id", "")))
		break
	# Guards as the generator placed them, with the game's estimate of their strength.
	var guards := []
	for encounter in session.overworld.get("encounters", []):
		if encounter is Dictionary and not encounter.has("ai_hero"):
			var stacks: Array = _ai_heroes._neutral_army(encounter).get("stacks", [])
			if not stacks.is_empty():
				guards.append({"key": String(_overworld.encounter_key(encounter)), "power": float(_ai_heroes.army_power(stacks, {}))})
	var towns := []
	for town in session.overworld.get("towns", []):
		if town is Dictionary and String(town.get("owner", "")) == "enemy":
			towns.append(String(town.get("placement_id", "")))
	var base: Dictionary = session.to_dict().duplicate(true)
	_emit({"kind": "group_ready", "group_id": group.get("group_id", ""), "setup_ms": (Time.get_ticks_usec() - started) / 1000.0, "guards": guards.size(), "towns": towns.size()})
	var used := {}
	for battle in group.get("battles", []):
		var kind := String(battle.get("type", ""))
		if guards.is_empty() or (kind == "siege" and towns.is_empty()):
			_emit({"kind": "game_error", "battle_id": battle.get("battle_id", ""), "error": "no guard or town for this battle"})
			continue
		# Both orders fight over the same ground: choose it once.
		var probe = _player_session(base, battle)
		var player_power: float = _ai_heroes.army_power(probe.overworld.get("army", {}).get("stacks", []), probe.overworld.get("hero", {}))
		var ground := {"player_power": player_power}
		if kind == "guard":
			ground["guard"] = _guard_for(guards, used, player_power * float(battle.get("guard_ratio", 1.0)))
		elif kind == "siege":
			ground["town"] = towns[int(battle.get("site_index", 0)) % towns.size()]
		else:
			ground["guard"] = guards[int(battle.get("site_index", 0)) % guards.size()]
		for order in orders:
			_play_game(base, group, battle, ground, String(order[0]), String(order[1]), variants, ai_controller)


## The guard whose strength is nearest the wanted strength (by ratio), a fresh one if close.
func _guard_for(guards: Array, used: Dictionary, wanted: float) -> Dictionary:
	var best := {}
	var best_gap := INF
	for guard in guards:
		var gap: float = absf(log(maxf(1.0, float(guard.power)) / maxf(1.0, wanted)))
		if used.has(guard.key):
			gap += 0.3
		if gap < best_gap:
			best = guard
			best_gap = gap
	used[best.key] = true
	return best


## The group's session with the battle's player hero and army.
func _player_session(base: Dictionary, battle: Dictionary):
	var session = _session_store.SessionData.new()
	session.from_dict(base.duplicate(true))
	var hero: Dictionary = _with_spec(session.overworld.get("hero", {}), battle.get("player_hero", {}))
	var army = session.overworld.get("army", {})
	army["stacks"] = _stacks(battle.get("player_army", []))
	hero["army"] = army
	session.overworld["hero"] = hero
	session.overworld["army"] = army
	# The hero roster is the source of truth: normalising reloads the active
	# hero and army from it.
	_hero_command.commit_active_hero(session)
	_overworld.normalize_overworld_state(session)
	return session


func _play_game(base: Dictionary, group: Dictionary, battle: Dictionary, ground: Dictionary, player_variant: String, enemy_variant: String, variants: Dictionary, ai_controller: String) -> void:
	var started := Time.get_ticks_usec()
	var row := {
		"kind": "game",
		"group_id": group.get("group_id", ""),
		"battle_id": battle.get("battle_id", ""),
		"monster_strength": group.get("monster_strength", ""),
		"map_size": group.get("map_size", ""),
		"player_faction": group.get("player_faction", ""),
		"enemy_faction": battle.get("enemy_faction", ""),
		"player_variant": player_variant,
		"enemy_variant": enemy_variant,
	}
	for key in ECHO_KEYS:
		if battle.has(key):
			row[key] = battle[key]
	_router._arena_install({}, _default_variant)
	var session = _player_session(base, battle)
	var kind := String(battle.get("type", ""))
	var enemy_power := 0.0
	var site := {}
	if kind == "siege":
		var placement_id := String(ground.get("town", ""))
		var town := _town(session, placement_id)
		var town_faction := String(_town_development.faction_id(town))
		row["enemy_faction"] = town_faction
		var garrison := _stacks(battle.get("garrison_by_faction", {}).get(town_faction, []))
		town["garrison"] = garrison
		var defender := {}
		var defender_spec: Dictionary = battle.get("defender_by_faction", {}).get(town_faction, {})
		if not defender_spec.is_empty():
			defender = _with_spec(_enemy_adventure.build_roster_commander_state(String(defender_spec.get("hero_id", "")), town_faction), defender_spec)
		town["ai_defender_commander_state"] = defender
		var built: Array = (town.get("built_buildings", []) as Array).duplicate()
		var wanted: Array = FORT_BUILDINGS.slice(0, int(battle.get("fort_level", 0)))
		if bool(battle.get("faction_defense", false)) and FACTION_DEFENSE.has(town_faction):
			wanted.append_array(["building_dev_hall_2", FACTION_DEFENSE[town_faction]])
		for building_id in wanted:
			if not built.has(building_id):
				built.append(building_id)
		town["built_buildings"] = built
		row["enemy_hero"] = not defender.is_empty()
		enemy_power = _ai_heroes.army_power(garrison, defender)
	else:
		var key := String(ground.get("guard", {}).get("key", ""))
		for placed in session.overworld.get("encounters", []):
			if placed is Dictionary and String(_overworld.encounter_key(placed)) == key:
				site = placed
		if kind == "hero":
			var faction := String(battle.get("enemy_faction", ""))
			var spec: Dictionary = battle.get("enemy_hero", {})
			var commander: Dictionary = _with_spec(_enemy_adventure.build_roster_commander_state(String(spec.get("hero_id", "")), faction), spec)
			var stacks := _stacks(battle.get("enemy_army", []))
			site["enemy_army"] = {"id": "arena_host", "name": "Arena Host", "faction_id": faction, "stacks": stacks}
			site["enemy_commander_state"] = commander
			# An AI player's hero, as on the map: it may withdraw.
			site["spawned_by_player_id"] = ai_controller
			enemy_power = _ai_heroes.army_power(stacks, commander)
		else:
			enemy_power = float(ground.get("guard", {}).get("power", 0.0))
	row["player_power"] = snappedf(float(ground.get("player_power", 0.0)), 0.1)
	row["enemy_power"] = snappedf(enemy_power, 0.1)
	# Installed before the battle is built: building it already asks the AI.
	# Calls tied to no side (shared payload plumbing) always take the default.
	_router._arena_install({"player": variants[player_variant], "enemy": variants[enemy_variant]}, _default_variant)
	var payload: Dictionary = {}
	if kind == "siege":
		payload = _battle_rules.create_town_assault_payload(session, String(ground.get("town", "")))
	else:
		payload = _battle_rules.create_battle_payload(session, site)
	if payload.is_empty():
		row["error"] = "battle payload is empty"
		_emit(row)
		return
	session.battle = payload
	session.game_state = "battle"
	_battle_rules.normalize_battle_state(session)
	row["start_ledger"] = _battle_rules.battle_report_casualty_ledger_bridge(session.battle)
	row["player_hero"] = not (session.battle.get("player_commander_state", {}) as Dictionary).is_empty()
	if kind != "siege":
		row["enemy_hero"] = not (session.battle.get("enemy_hero", {}) as Dictionary).is_empty() and kind == "hero"
	var resolution: Dictionary = _auto_resolve.resolve_active_battle(session)
	var report = session.flags.get("last_battle_aftermath", {})
	row["state"] = String(resolution.get("state", ""))
	row["completed"] = bool(resolution.get("completed", false))
	row["invalid_orders"] = int(resolution.get("invalid_orders", 0))
	row["outcome"] = String(report.get("outcome", "")) if report is Dictionary else ""
	row["rounds"] = int(report.get("rounds", 0)) if report is Dictionary else 0
	row["end_ledger"] = report.get("casualties", {}) if report is Dictionary else {}
	row["ai_calls"] = _router._arena_calls.duplicate()
	row["ms"] = (Time.get_ticks_usec() - started) / 1000.0
	_emit(row)


func _town(session, placement_id: String) -> Dictionary:
	for town in session.overworld.get("towns", []):
		if town is Dictionary and String(town.get("placement_id", "")) == placement_id:
			return town
	return {}


func _stacks(spec: Array) -> Array:
	var stacks := []
	for index in range(spec.size()):
		stacks.append({"unit_id": String(spec[index].get("unit_id", "")), "count": maxi(1, int(spec[index].get("count", 1))), "slot_index": index})
	return stacks


## A hero at the battle's level, knowing its spells, with the given share of its mana.
func _with_spec(hero: Dictionary, spec: Dictionary) -> Dictionary:
	var veteran: Dictionary = _progression.advance_to_level(hero, int(spec.get("level", 1)))
	var spellbook: Dictionary = veteran.get("spellbook", {}) if veteran.get("spellbook", {}) is Dictionary else {}
	var known: Array = (spellbook.get("known_spell_ids", []) as Array).duplicate()
	for spell_id in spec.get("spell_ids", []):
		if not known.has(spell_id):
			known.append(spell_id)
	spellbook["known_spell_ids"] = known
	spellbook["mana"] = {}
	veteran["spellbook"] = spellbook
	veteran = _spells.ensure_hero_spellbook(veteran)
	var maximum := int(_spells.mana_max_from_hero(veteran))
	veteran["spellbook"]["mana"] = {"current": int(round(float(maximum) * float(spec.get("mana", 1.0)))), "max": maximum}
	return _spells.ensure_hero_spellbook(veteran)


## The generated map was loaded into the session; its package files under
## maps/ are not needed again.
func _remove_generated_packages(session) -> void:
	var paths = session.overworld.get("native_random_map_package_session_adoption", {})
	if not (paths is Dictionary):
		return
	for key in ["map_package_path", "scenario_package_path"]:
		var path := String(paths.get(key, ""))
		if path != "" and FileAccess.file_exists(path):
			DirAccess.remove_absolute(ProjectSettings.globalize_path(path))


func _emit(row: Dictionary) -> void:
	_out.store_line(JSON.stringify(row))
	_out.flush()
