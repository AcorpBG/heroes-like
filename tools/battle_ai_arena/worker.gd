extends SceneTree
## Battle AI arena worker (tools/battle_ai_arena). Started by arena.py with
##   godot --headless --path <repo> -s <this file> -- <job.json> <results.jsonl>
## It plays the job's battles with Quick Resolve (BattleAutoResolveRules), each
## side's stacks commanded by its own BattleAiRules variant, and writes one JSON
## line per game. Nothing here is loaded by the game or the test suites.
##
## The variants are swapped in memory only: the cached BattleAiRules script is
## reloaded with the router from router.py, which forwards each AI call to the
## variant playing the acting stack's side. Game files are never written.
##
## Game scripts are loaded at runtime: a -s script compiles before autoloads exist.

const AI_PATH := "res://scripts/core/BattleAiRules.gd"

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
	var job_text := FileAccess.get_file_as_string(String(args[0]))
	var job = JSON.parse_string(job_text)
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
	var variants := {}
	for label in (job.get("variants", {}) as Dictionary).keys():
		var variant := _compile_variant(String(job.variants[label]))
		if variant == null:
			printerr("ARENA variant %s does not compile" % label)
			return 3
		variants[String(label)] = variant
	var default_variant: Script = variants.get(String(job.get("default_variant", "A")))
	_default_variant = default_variant
	if not _install_router(String(job.get("router", "")), default_variant):
		return 3
	# Map and battle setup already call the AI's helpers: route them all to the
	# default variant until a game installs its sides.
	_router._arena_install({}, default_variant)
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


func _play_group(group: Dictionary, variants: Dictionary, orders: Array) -> void:
	var started := Time.get_ticks_usec()
	var player_faction := String(group.get("player_faction", ""))
	var config = _scenario_select.build_random_map_player_config(
		String(group.get("map_seed", "arena")), "", "", 2, "land", false, String(group.get("map_size", "homm3_small")),
		_scenario_select.RANDOM_MAP_TEMPLATE_SELECTION_MODE_SIZE_DEFAULT, player_faction, String(group.get("player_hero_id", ""))
	)
	var setup = _scenario_select.build_random_map_skirmish_setup_with_retry(config, "normal", _scenario_select.RANDOM_MAP_PLAYER_RETRY_POLICY)
	if not bool(setup.get("ok", false)):
		_emit({"kind": "group_error", "group_id": group.get("group_id", ""), "error": "map setup failed"})
		return
	var session = _scenario_select.start_random_map_skirmish_session_from_setup(setup)
	_remove_generated_packages(session)
	_overworld.normalize_overworld_state(session)
	var stage: Dictionary = group.get("stage", {})
	var hero: Dictionary = _veteran(session.overworld.get("hero", {}), player_faction, stage)
	var army = session.overworld.get("army", {})
	army["stacks"] = _stage_army(player_faction, stage)
	hero["army"] = army
	session.overworld["hero"] = hero
	session.overworld["army"] = army
	# The hero roster is the source of truth: normalising reloads the active
	# hero and army from it.
	_hero_command.commit_active_hero(session)
	_overworld.normalize_overworld_state(session)
	var ai_controller := ""
	for state in session.overworld.get("enemy_states", []):
		ai_controller = String(state.get("player_id", state.get("faction_id", "")))
		break
	var sites := []
	for encounter in session.overworld.get("encounters", []):
		if encounter is Dictionary and not encounter.has("ai_hero"):
			sites.append(encounter)
	var base: Dictionary = session.to_dict().duplicate(true)
	_emit({"kind": "group_ready", "group_id": group.get("group_id", ""), "setup_ms": (Time.get_ticks_usec() - started) / 1000.0, "sites": sites.size()})
	for battle in group.get("battles", []):
		if sites.is_empty():
			_emit({"kind": "game_error", "battle_id": battle.get("battle_id", ""), "error": "no battle sites"})
			continue
		var site: Dictionary = sites[int(battle.get("site_index", 0)) % sites.size()]
		for order in orders:
			_play_game(base, site, group, battle, String(order[0]), String(order[1]), variants, ai_controller)


func _play_game(base: Dictionary, site: Dictionary, group: Dictionary, battle: Dictionary, player_variant: String, enemy_variant: String, variants: Dictionary, ai_controller: String) -> void:
	var started := Time.get_ticks_usec()
	var row := {
		"kind": "game",
		"group_id": group.get("group_id", ""),
		"battle_id": battle.get("battle_id", ""),
		"stage": (group.get("stage", {}) as Dictionary).get("id", ""),
		"player_faction": group.get("player_faction", ""),
		"enemy_faction": battle.get("enemy_faction", ""),
		"player_variant": player_variant,
		"enemy_variant": enemy_variant,
	}
	var session = _session_store.SessionData.new()
	session.from_dict(base.duplicate(true))
	var enemy_faction := String(battle.get("enemy_faction", ""))
	var commander: Dictionary = _enemy_adventure.build_roster_commander_state(String(battle.get("enemy_hero_id", "")), enemy_faction)
	commander = _veteran(commander, enemy_faction, group.get("stage", {}))
	var enemy_stacks := _stage_army(enemy_faction, group.get("stage", {}))
	if bool(group.get("balance", true)):
		enemy_stacks = _balanced(enemy_stacks, commander, session.overworld.get("army", {}).get("stacks", []), session.overworld.get("hero", {}))
	row["strength"] = [
		_ai_heroes.army_power(session.overworld.get("army", {}).get("stacks", []), session.overworld.get("hero", {})),
		_ai_heroes.army_power(enemy_stacks, commander),
	]
	var key := String(_overworld.encounter_key(site))
	for placed in session.overworld.get("encounters", []):
		if placed is Dictionary and String(_overworld.encounter_key(placed)) == key:
			placed["enemy_army"] = {"id": "arena_host", "name": "Arena Host", "faction_id": enemy_faction, "stacks": enemy_stacks}
			placed["enemy_commander_state"] = commander
			# An AI player's hero, as on the map: it may withdraw.
			placed["spawned_by_player_id"] = ai_controller
	# Installed before the battle is built: building it already asks the AI.
	# Calls tied to no side (shared payload plumbing) always take the default.
	_router._arena_install({"player": variants[player_variant], "enemy": variants[enemy_variant]}, _default_variant)
	var payload: Dictionary = _battle_rules.create_battle_payload(session, site)
	if payload.is_empty():
		row["error"] = "battle payload is empty"
		_emit(row)
		return
	session.battle = payload
	session.game_state = "battle"
	_battle_rules.normalize_battle_state(session)
	row["start_ledger"] = _battle_rules.battle_report_casualty_ledger_bridge(session.battle)
	row["player_hero"] = not (session.battle.get("player_commander_state", {}) as Dictionary).is_empty()
	row["enemy_hero"] = not (session.battle.get("enemy_hero", {}) as Dictionary).is_empty()
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


## A hero as it stands at this stage: its level, and every spell of its
## faction's town guild up to the stage's tier, with full mana.
func _veteran(hero: Dictionary, faction_id: String, stage: Dictionary) -> Dictionary:
	var veteran: Dictionary = _progression.advance_to_level(hero, int(stage.get("hero_level", 1)))
	var town: Dictionary = _content.get_town(String(_content.get_faction(faction_id).get("seed_town_id", "")))
	var spellbook: Dictionary = veteran.get("spellbook", {}) if veteran.get("spellbook", {}) is Dictionary else {}
	var known: Array = (spellbook.get("known_spell_ids", []) as Array).duplicate()
	for tier in town.get("spell_library", []):
		if int(tier.get("tier", 99)) <= int(stage.get("spell_tier_max", 0)):
			for spell_id in tier.get("spell_ids", []):
				if not known.has(spell_id):
					known.append(spell_id)
	spellbook["known_spell_ids"] = known
	spellbook["mana"] = {}
	veteran["spellbook"] = spellbook
	return _spells.ensure_hero_spellbook(veteran)


## The faction's ladder up to the stage's top tier, each at its weekly growth
## times the stage's weeks.
func _stage_army(faction_id: String, stage: Dictionary) -> Array:
	var stacks := []
	var ladder: Array = _content.get_faction(faction_id).get("unit_ladder_ids", [])
	for index in range(mini(ladder.size(), int(stage.get("tier_max", 7)))):
		var unit: Dictionary = _content.get_unit(String(ladder[index]))
		var count := maxi(1, int(round(float(unit.get("growth", 1)) * float(stage.get("weeks", 1)))))
		stacks.append({"unit_id": String(ladder[index]), "count": count, "slot_index": index})
	return stacks


## The enemy's stacks scaled so its army, hero included, rates as strong as
## the player's (AiHeroRules.army_power, the game's own battle estimate). Even
## armies leave more battles for the AI to decide.
func _balanced(stacks: Array, commander: Dictionary, player_stacks: Array, player_hero: Dictionary) -> Array:
	var target: float = _ai_heroes.army_power(player_stacks, player_hero)
	var scaled := stacks.duplicate(true)
	for _pass in range(3):
		var power: float = _ai_heroes.army_power(scaled, commander)
		if power <= 0.0 or target <= 0.0:
			break
		var factor := target / power
		for stack in scaled:
			stack["count"] = maxi(1, int(round(float(stack.get("count", 1)) * factor)))
	return scaled


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
