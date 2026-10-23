extends SceneTree
## Battle AI arena worker (tools/battle_ai_arena). Started by arena.py with
##   godot --headless --path <repo> -s <this file> -- <job.json> <results.jsonl>
## It plays the job's battles (scenarios.py: guards, heroes and sieges on
## generated maps) with Quick Resolve (BattleAutoResolveRules), the game's own
## battle AI and weights on both sides, and writes one JSON line per game
## (arena.py --backend godot --plain). Nothing here is loaded by the game or the
## test suites. Games with each side's own weights play in battle_sim_cli.
##
## A setup job ("setup": {"corpus_dir", "content"}) plays nothing: it builds each
## battle's session as a game does up to the battle payload, which every order
## shares, and writes each map's battles as a snapshot into corpus_dir for
## battle_sim_cli (src/gdextension/rules/cli), which plays the orders outside
## Godot (arena.py --backend cli). With "content", it first writes the content
## and the rules scripts' static vars that battle_sim_cli reads to that path.
##
## Game scripts are loaded at runtime: a -s script compiles before autoloads exist.

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
const CONTENT_DIR := "res://content"
const RULES_DIR := "res://scripts/core"
# battle_sim_cli's content tables (state::ContentTable): the getter of each, and
# the file whose ids it is asked for. Scenarios and their terrain layers are
# each map's own (_write_corpus).
const CONTENT_TABLES := {
	"Unit": ["get_unit", "res://content/units.json"],
	"Hero": ["get_hero", "res://content/heroes.json"],
	"Faction": ["get_faction", "res://content/factions.json"],
	"Spell": ["get_spell", "res://content/spells.json"],
	"Artifact": ["get_artifact", "res://content/artifacts.json"],
	"ResourceSite": ["get_resource_site", "res://content/resource_sites.json"],
	"Building": ["get_building", "res://content/buildings.json"],
	"Town": ["get_town", "res://content/towns.json"],
	"MapObject": ["get_map_object", "res://content/map_objects.json"],
	"Encounter": ["get_encounter", "res://content/encounters.json"],
	"ArmyGroup": ["get_army_group", "res://content/army_groups.json"],
	"Resource": ["get_resource", "res://content/resources.json"],
}
const GENERATED_COMPANIES_PATH := "res://content/generated_neutral_companies.json"

var _started := false
var _content  # the ContentService autoload; untyped, so its script's methods resolve at runtime
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
	# The battle rules call the native rules library; without it every battle fails.
	if not load("res://scripts/core/NativeRules.gd").available():
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
	var setup: Dictionary = job.get("setup", {}) if job.get("setup", {}) is Dictionary else {}
	# Before any map: the static vars as a game starts. army_power applies its
	# terms from the content at its first call, which every game's setup has
	# made before its record reads them (_commander_features).
	if String(setup.get("content", "")) != "":
		_ai_heroes.army_power([], {})
	if String(setup.get("content", "")) != "" and not _write_snapshot(String(setup.content), _content_snapshot()):
		printerr("ARENA cannot write the content snapshot %s" % setup.content)
		return 2
	_emit({"kind": "worker_ready", "boot_ms": Time.get_ticks_msec()})
	for group in job.get("groups", []):
		# A setup job may run ahead of its caller (tune.py): a group waits for its go.
		var wait_for := String(group.get("wait_for", ""))
		while wait_for != "" and not FileAccess.file_exists(wait_for):
			OS.delay_msec(100)
		_play_group(group, job.get("orders", [["A", "B"], ["B", "A"]]), String(group.get("corpus_dir", setup.get("corpus_dir", ""))))
		if not setup.is_empty():
			_emit({"kind": "group_done", "group_id": group.get("group_id", ""), "tag": group.get("tag", "")})
	return 0


## One generated map, made as the skirmish menu makes it, and its battles: played,
## or, in a setup job (corpus_dir), written for battle_sim_cli.
func _play_group(group: Dictionary, orders: Array, corpus_dir: String) -> void:
	var started := Time.get_ticks_usec()
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
	var corpus := []
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
		if corpus_dir != "":
			# The probe is the session a game builds: one build serves both.
			var entry := _corpus_battle(base, group, battle, ground, orders, ai_controller, probe)
			if not entry.is_empty():
				corpus.append(entry)
			continue
		for order in orders:
			_play_game(base, group, battle, ground, String(order[0]), String(order[1]), ai_controller)
	if corpus_dir != "":
		_write_corpus(corpus_dir, group, String(session.scenario_id), corpus)


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


func _play_game(base: Dictionary, group: Dictionary, battle: Dictionary, ground: Dictionary, player_variant: String, enemy_variant: String, ai_controller: String) -> void:
	var started := Time.get_ticks_usec()
	var game := _prepare_game(base, group, battle, ground, ai_controller)
	var row: Dictionary = game.row
	row["player_variant"] = player_variant
	row["enemy_variant"] = enemy_variant
	if bool(game.skipped):
		_emit({"kind": "skipped", "battle_id": row.battle_id})
		return
	var session = game.session
	var site: Dictionary = game.site
	var kind := String(battle.get("type", ""))
	var payload: Dictionary = {}
	if kind == "siege":
		payload = _battle_rules.create_town_assault_payload(session, String(ground.get("town", "")))
	else:
		payload = _battle_rules.create_battle_payload(session, site)
	if payload.is_empty():
		row["error"] = "battle payload is empty"
		_emit(row)
		return
	# The same battle with other dice (a group's "dice"): how much of a result
	# is luck. The battle's damage rolls restart from the new seed.
	var dice := int(group.get("dice", 0))
	if dice != 0:
		payload["combat_seed"] = hash([int(payload.get("combat_seed", 0)), dice])
		for key in ["damage_rng_version", "damage_rng_state", "damage_rng_roll_count", "damage_rng_integrity"]:
			payload.erase(key)
		row["dice"] = dice
	session.battle = payload
	session.game_state = "battle"
	_battle_rules.normalize_battle_state(session)
	row["start_ledger"] = _battle_rules.battle_report_casualty_ledger_bridge(session.battle)
	row["player_commander"] = _commander_features(session.battle.get("player_commander_state", {}))
	row["enemy_commander"] = _commander_features(session.battle.get("enemy_hero", {}))
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
	row["ai_calls"] = {}
	row["ms"] = (Time.get_ticks_usec() - started) / 1000.0
	_emit(row)


## A game up to its battle payload, the same for every order: {row (the record
## so far, without the variants), session, site, skipped (outside the group's
## odds)}. The session is built from base unless one built so is given.
func _prepare_game(base: Dictionary, group: Dictionary, battle: Dictionary, ground: Dictionary, ai_controller: String, probe = null) -> Dictionary:
	var row := {
		"kind": "game",
		"group_id": group.get("group_id", ""),
		"battle_id": battle.get("battle_id", ""),
		"monster_strength": group.get("monster_strength", ""),
		"map_size": group.get("map_size", ""),
		"player_faction": group.get("player_faction", ""),
		"enemy_faction": battle.get("enemy_faction", ""),
	}
	for key in ECHO_KEYS:
		if battle.has(key):
			row[key] = battle[key]
	var session = probe if probe != null else _player_session(base, battle)
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
	# A contested run plays only the battles whose odds fall in its band.
	var odds: Array = group.get("odds", [])
	var skipped := false
	if odds.size() == 2:
		var ratio := float(ground.get("player_power", 0.0)) / maxf(1.0, enemy_power)
		skipped = ratio < float(odds[0]) or ratio > float(odds[1])
	return {"row": row, "session": session, "site": site, "skipped": skipped}


## A battle for battle_sim_cli (a setup job): its session as a game holds it
## before the payload, with the record so far. A skipped battle is skipped in
## every order here, and leaves nothing to play.
func _corpus_battle(base: Dictionary, group: Dictionary, battle: Dictionary, ground: Dictionary, orders: Array, ai_controller: String, probe) -> Dictionary:
	var game := _prepare_game(base, group, battle, ground, ai_controller, probe)
	var row: Dictionary = game.row
	if bool(game.skipped):
		for order in orders:
			_emit({"kind": "skipped", "battle_id": row.battle_id})
		return {}
	var record := JSON.stringify(row)
	return {
		"battle_id": String(row.battle_id),
		"kind": String(battle.get("type", "")),
		"town": String(ground.get("town", "")),
		"dice": int(group.get("dice", 0)),
		# The record without its closing brace: battle_sim_cli adds the rest.
		"prefix": record.substr(0, record.length() - 1),
		"session": _session_view(game.session),
		"site": game.site,
	}


## A map's battles for battle_sim_cli, with the generated scenario they read.
func _write_corpus(corpus_dir: String, group: Dictionary, scenario_id: String, battles: Array) -> void:
	var corpus := {
		"group": {
			"scenario_id": scenario_id,
			"scenario": _content.get_scenario_readonly(scenario_id),
			"terrain_layers": _content.get_terrain_layers_for_scenario(scenario_id),
			"content_revision": _content.get_content_revision(),
		},
		"battles": battles,
	}
	var path := corpus_dir.path_join(String(group.get("corpus_file", "group_%s.snap" % group.get("group_id", ""))))
	if not _write_snapshot(path, corpus):
		_emit({"kind": "group_error", "group_id": group.get("group_id", ""), "error": "cannot write %s" % path})
		return
	_emit({"kind": "corpus", "group_id": group.get("group_id", ""), "battles": battles.size()})


## The session as the native rules see an object (PortBridge::object_view): its
## script variables in property list order, then its metadata under "meta".
func _session_view(session) -> Dictionary:
	var view := {}
	for property in session.get_property_list():
		if int(property.get("usage", 0)) & PROPERTY_USAGE_SCRIPT_VARIABLE:
			view[String(property.name)] = session.get(property.name)
	var meta := {}
	for name in session.get_meta_list():
		meta[name] = session.get_meta(name)
	view["meta"] = meta
	return view


## What battle_sim_cli reads besides a map's battles: the content files, the
## content tables by id (as ContentService's getters answer), and the rules
## scripts' static vars.
func _content_snapshot() -> Dictionary:
	var files := {}
	for name in DirAccess.get_files_at(CONTENT_DIR):
		if name.get_extension() == "json":
			var path := CONTENT_DIR.path_join(name)
			files[path] = _content.load_json(path)
	var tables := {}
	for table in CONTENT_TABLES:
		var getter := String(CONTENT_TABLES[table][0])
		var path := String(CONTENT_TABLES[table][1])
		# "" too: an item without an id is the row of id "".
		var ids: Array = [""]
		ids.append_array(_content.get_content_ids(path))
		if table == "Town":
			ids.append_array((_content.load_json(path).get("legacy_aliases", {}) as Dictionary).keys())
		elif table == "Encounter":
			ids.append_array(_content.get_content_ids(GENERATED_COMPANIES_PATH, "encounters"))
		var rows := {}
		for id in ids:
			var row: Dictionary = _content.call(getter, String(id))
			if not rows.has(String(id)) and not row.is_empty():
				rows[String(id)] = row
		tables[table] = rows
	# By the id each lookup asks with: the stripped site id, the normalized terrain.
	var by_site := {}
	for item in _content._items_from_raw(_content.load_json("res://content/map_objects.json")):
		var site_id := String(item.get("resource_site_id", "")).strip_edges() if item is Dictionary else ""
		if site_id != "" and not by_site.has(site_id):
			by_site[site_id] = _content.get_map_object_for_resource_site(site_id)
	tables["MapObjectForResourceSite"] = by_site
	var by_terrain := {}
	for biome in _content._items_from_raw(_content.load_json("res://content/biomes.json")):
		if not (biome is Dictionary) or not (biome.get("map_tile_ids", []) is Array):
			continue
		for tile_id in biome.get("map_tile_ids", []):
			var terrain := String(tile_id) if tile_id is String or tile_id is StringName else ""
			if terrain != "" and _content.normalize_terrain_id(terrain) == terrain and not by_terrain.has(terrain):
				var row: Dictionary = _content.get_biome_for_terrain(terrain)
				if not row.is_empty():
					by_terrain[terrain] = row
	tables["BiomeForTerrain"] = by_terrain
	return {"files": files, "tables": tables, "statics": _static_vars(), "revision": _content.get_content_revision()}


## Each rules script's static vars, by its path and their names.
func _static_vars() -> Dictionary:
	var declaration := RegEx.create_from_string("^static var ([A-Za-z_][A-Za-z0-9_]*)")
	var statics := {}
	for name in DirAccess.get_files_at(RULES_DIR):
		if name.get_extension() != "gd":
			continue
		var path := RULES_DIR.path_join(name)
		var names := []
		for line in FileAccess.get_file_as_string(path).split("\n"):
			var found := declaration.search(line)
			if found != null:
				names.append(found.get_string(1))
		var script = load(path) if not names.is_empty() else null
		if script == null:
			continue
		var values := {}
		for var_name in names:
			values[var_name] = script.get(var_name)
		statics[path] = values
	return statics


func _write_snapshot(path: String, value: Variant) -> bool:
	var bytes: PackedByteArray = load("res://scripts/core/NativeRules.gd").api().snapshot_encode(value)
	var file := FileAccess.open(path, FileAccess.WRITE)
	if bytes.is_empty() or file == null:
		return false
	file.store_buffer(bytes)
	file.close()
	return true


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


## A side's hero as the strength estimate sees it (AiHeroRules.army_power).
func _commander_features(commander: Variant) -> Dictionary:
	if not (commander is Dictionary) or (commander as Dictionary).is_empty():
		return {}
	var command: Dictionary = commander.get("command", {}) if commander.get("command", {}) is Dictionary else {}
	return {
		"level": int(commander.get("level", 0)),
		"attack": int(command.get("attack", 0)),
		"defense": int(command.get("defense", 0)),
		"power": int(command.get("power", 0)),
		"knowledge": int(command.get("knowledge", 0)),
		"spell_damage": _ai_heroes._spell_damage_per_round(commander),
	}
