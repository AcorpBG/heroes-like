extends Node

# A whole game with no human player: two computer players on a small generated
# one-level map, each faction drawn at random (a mirror match is possible),
# played day by day until one side holds no town and no hero. Every
# auto-resolved fight goes into a battle log and every day into a ledger per
# side; the full record is written as JSON for the battle report.
#
# It is an evaluation tool, not a test: it fails only when the match cannot be
# set up or played.
#
# HEROES_AI_MATCH_SEED     match seed (factions and map); unset or "random"
#                          draws one. The same seed replays the same match.
# HEROES_AI_MATCH_MAX_DAYS day cap for an undecided match (default 320).
# HEROES_AI_MATCH_OUT      where the JSON record goes (default user://).
# HEROES_AI_MATCH_TRACE    1 prints each day's heroes, goals and towns.
# HEROES_AI_MATCH_SWAP     1 plays the same map with the factions' starting
#                          places swapped, to tell map balance from faction.
# HEROES_AI_MATCH_PLAYERS  computer players on the map (default 2); a match
#                          of more ends when one player is left standing.
# HEROES_AI_MATCH_FACTIONS comma-separated faction ids, one per seat, in
#                          place of the seed's random draw. The map comes from
#                          the seed alone: the generator gives each seat its
#                          faction (ScenarioSelectRules seat factions), so the
#                          same seed with another line-up plays the same map.
# HEROES_AI_MATCH_GUARDS   guard strength: weak, normal (default, as a new
#                          game from the main menu) or strong.
# HEROES_AI_MATCH_SIZE     map size class (default homm3_small; homm3_medium,
#                          homm3_large, homm3_extra_large).
# HEROES_AI_MATCH_WATER    land (default), normal_water or islands.
# HEROES_AI_MATCH_LEVELS   1 (default) or 2 (with an underground level).
# HEROES_AI_MATCH_DIGEST   file that gets one line per day, at the start and
#                          after every end_turn: "day<TAB>digest", the Variant
#                          hash of the whole session state (hash(); the rules
#                          library's gd::hash copies it), 8 hex digits for
#                          each of its header fields, overworld, battle and
#                          flags (insertion order, int and float apart). For
#                          tools/rules_parity.py; off by default, and the game
#                          is the same either way.
# HEROES_AI_MATCH_DUMP     with HEROES_AI_MATCH_DUMP_DAY: that day's session
#                          state as JSON (the digested parts in one object,
#                          full precision) goes into this file and the match
#                          stops there.
# HEROES_AI_MATCH_DIGEST_BLANK comma-separated; "overworld.<key>" and
#                          "flags.<key>" entries name where to look, the other
#                          entries are field names whose values become "" in
#                          the digest and the dump, in nested dictionaries
#                          under those keys (arrays are not entered).
#                          rules_parity.py --portable: the map package's
#                          location differs between the editor and an export.
# HEROES_AI_MATCH_WEIGHTS  comma-separated, one entry per seat: the overworld
#                          AI weight set each seat plays with (AiHeroRules,
#                          "Weights"). An entry is empty or "default", the
#                          name of a set in content/ai_hero_weights.json, or
#                          the absolute path of a .json file holding one set
#                          (only the values it changes, as a named set there),
#                          added for this run only. Unset, every seat plays
#                          the default set and the record is as before; set,
#                          setup.seats[].weights records each seat's set.
# HEROES_AI_MATCH_KEEP_SESSION 0 loads the whole session into the native day
#                          every day, as the game does. By default the day's
#                          native call keeps the session from one day to the
#                          next (DayEngine.session_calls); the game is the
#                          same either way.
# HEROES_AI_MATCH_LIST     a JSON file holding an array of matches that this
#                          process plays one after another, each an object of
#                          HEROES_AI_MATCH_* settings in place of the
#                          environment's (values as strings; a setting it
#                          leaves out comes from the environment). Each match
#                          prints an AI_VERSUS_AI_MATCH_BEGIN line, then its
#                          report line, and plays as it would in a process of
#                          its own; a failed match does not stop the next. The
#                          process exits 1 when any match failed. A match on
#                          the map and line-up the match before it played (the
#                          same map seed, setup and seat factions) starts from
#                          a copy of the session that match adopted, before its
#                          handover, instead of loading the map again; one on
#                          the same map with another line-up has the generator
#                          reuse the map it made for the match before.
# HEROES_AI_MATCH_MAP_CORPUS a folder of generated map packages: a match whose
#                          map and line-up are there starts from the saved
#                          package and setup instead of generating it, and one
#                          not there yet is generated and saved there. The game
#                          is the same either way. The packages belong to the
#                          game revision that generated them
#                          (tools/ai_match_batch.py --map-corpus checks it).
# HEROES_AI_MATCH_PREPARE  a file path: the match's map is made (generated, or
#                          from the corpus) and written there as a snapshot with
#                          its setup and its two packages instead of played, for
#                          bin/match_sim_cli, which starts the session from the
#                          packages, hands the seats over, plays the days
#                          outside Godot and writes what this scene would
#                          (tools/ai_match_batch.py --runner). The content and
#                          the rules scripts' static vars as a game starts go
#                          into content.snap in the same folder when it is not
#                          there yet. The report line says "prepared".
# HEROES_AI_MATCH_CONTENT_SNAPSHOT a file path: only that content snapshot is
#                          written, with the project folder, and no match
#                          plays. bin/match_sim_cli generates the matches' maps
#                          from it and plays them as this scene would
#                          (HEROES_AI_MATCH_CONTENT; tools/ai_match_batch.py
#                          --runner, tools/rules_parity.py --runner-b).
# A content snapshot comes from this tree's bin/match_sim_cli --write-content,
# which reads the content and the rules scripts from the project folder.
#
# The match fails at once when the native rules library is not registered:
# without it every battle hex search errors and battles play out wrong.

const ScenarioSelectRulesScript = preload("res://scripts/core/ScenarioSelectRules.gd")
const AiHeroRulesScript = preload("res://scripts/core/AiHeroRules.gd")
const AiSeatRulesScript = preload("res://scripts/core/AiSeatRules.gd")
const PlayerRules = preload("res://scripts/core/PlayerIdentityRules.gd")
const NativeRulesScript = preload("res://scripts/core/NativeRules.gd")
const DayEngineScript = preload("res://scripts/core/DayEngine.gd")
const SessionStateStoreScript = preload("res://scripts/core/SessionStateStore.gd")
# The prepare mode's setup snapshots; loaded only there (tools/ is not exported).
const RULES_SNAPSHOT_PATH := "res://tools/rules_snapshot/rules_snapshot.gd"
# Writes the content snapshots (--write-content).
const MATCH_SIM_CLI := "res://bin/match_sim_cli"
const REPORT_ID := "AI_VERSUS_AI_MATCH_REPORT"
const BEGIN_ID := "AI_VERSUS_AI_MATCH_BEGIN"
const DEFAULT_MAX_DAYS := 320
const DEFAULT_OUT := "user://ai_versus_ai_match.json"

# Per match; _begin_match sets them up again.
var _settings := {}
var _out_path := DEFAULT_OUT
var _started_msec := 0
var _stats_before := {}
var _failed := false
var _digest_file: FileAccess = null
var _dump_path := ""
var _dump_day := -1
var _blank_scopes := PackedStringArray()
var _blank_fields := {}
# Where the match's map came from: generated, reused (the generator's map from
# the match before, with this match's factions), corpus or kept.
var _map_source := ""
# In a match list, the last map adopted and a copy of its session as adopted
# (the prepare mode: its setup and packages).
var _list_mode := false
var _kept_map_key := ""
var _kept_map_session = null
var _kept_prepared := {}

func _ready() -> void:
	call_deferred("_run")

func _run() -> void:
	if not NativeRulesScript.available():
		_fail("The native rules library is not loaded: %s." % NativeRulesScript.REGISTER_HINT)
		get_tree().quit(1)
		return
	var content_only := OS.get_environment("HEROES_AI_MATCH_CONTENT_SNAPSHOT").strip_edges()
	if content_only != "":
		if not _write_content_snapshot(content_only):
			get_tree().quit(1)
			return
		print("%s %s" % [REPORT_ID, JSON.stringify({"ok": true, "content": ProjectSettings.globalize_path(content_only)})])
		get_tree().quit(0)
		return
	var matches := [{}]
	var list_path := OS.get_environment("HEROES_AI_MATCH_LIST").strip_edges()
	if list_path != "":
		var parsed = JSON.parse_string(FileAccess.get_file_as_string(list_path)) if FileAccess.file_exists(list_path) else null
		if not (parsed is Array) or (parsed as Array).any(func(entry): return not (entry is Dictionary)):
			_fail("HEROES_AI_MATCH_LIST %s holds no JSON array of objects." % list_path)
			get_tree().quit(1)
			return
		matches = parsed
		_list_mode = true
	var all_ok := true
	for entry in matches:
		_begin_match(entry)
		if list_path != "":
			print("%s %s" % [BEGIN_ID, JSON.stringify({"out": ProjectSettings.globalize_path(_out_path)})])
		_play()
		_end_match()
		all_ok = all_ok and not _failed
	get_tree().quit(0 if all_ok else 1)

## The content snapshot at path, from bin/match_sim_cli --write-content: the
## content and the rules scripts' static vars as a game starts, read from the
## project folder, and that folder, whose files match_sim_cli reads (the content
## catalogs the map generation reads, the art the packages name). False, with
## the failure reported, when it is not written.
func _write_content_snapshot(path: String) -> bool:
	var cli := ProjectSettings.globalize_path(MATCH_SIM_CLI + (".exe" if OS.has_feature("windows") else ""))
	if not FileAccess.file_exists(cli):
		_fail("The content snapshot %s cannot be written: %s is missing (python tools/build_native.py windows builds it)." % [path, cli])
		return false
	var output := []
	var code := OS.execute(cli, ["--write-content", ProjectSettings.globalize_path(path), "--project", ProjectSettings.globalize_path("res://")], output, true)
	if code != 0 or not FileAccess.file_exists(path):
		_fail("The content snapshot %s cannot be written: match_sim_cli --write-content exited with %d: %s" % [path, code, "".join(output).strip_edges().right(400)])
		return false
	return true

## A match setting: the match list's entry, else the environment.
func _env(name: String) -> String:
	return String(_settings[name]) if _settings.has(name) else OS.get_environment(name)

func _begin_match(settings: Dictionary) -> void:
	_settings = settings
	_out_path = _env("HEROES_AI_MATCH_OUT").strip_edges()
	if _out_path == "":
		_out_path = DEFAULT_OUT
	_started_msec = Time.get_ticks_msec()
	_stats_before = NativeRulesScript.api().port_stats()
	_failed = false
	_digest_file = null
	_dump_path = ""
	_dump_day = -1
	_blank_scopes = PackedStringArray()
	_blank_fields = {}
	_map_source = ""

## What one match leaves behind is gone before the next one starts.
func _end_match() -> void:
	if _digest_file != null:
		_digest_file.close()
		_digest_file = null
	DayEngineScript.session_calls.erase(&"OverworldRules.end_turn")
	NativeRulesScript.api().port_session_close()
	_cleanup()

func _play() -> void:
	ContentService.clear_generated_scenario_drafts()
	var match_seed := _env("HEROES_AI_MATCH_SEED").strip_edges()
	if match_seed in ["", "random"]:
		var draw := RandomNumberGenerator.new()
		draw.randomize()
		match_seed = "ai-match-%d" % draw.randi()
	var max_days := int(_env("HEROES_AI_MATCH_MAX_DAYS")) if _env("HEROES_AI_MATCH_MAX_DAYS") != "" else DEFAULT_MAX_DAYS
	var swapped := _env("HEROES_AI_MATCH_SWAP").strip_edges() not in ["", "0"]
	var player_count := clampi(int(_env("HEROES_AI_MATCH_PLAYERS")), 2, 8) if _env("HEROES_AI_MATCH_PLAYERS") != "" else 2
	var guards := _env("HEROES_AI_MATCH_GUARDS").strip_edges().to_lower()
	if guards == "":
		guards = "normal"
	if guards not in ["weak", "normal", "strong"]:
		_fail("HEROES_AI_MATCH_GUARDS must be weak, normal or strong, got %s." % guards)
		return
	var size_class := _env("HEROES_AI_MATCH_SIZE").strip_edges()
	if size_class == "":
		size_class = "homm3_small"
	var water := _env("HEROES_AI_MATCH_WATER").strip_edges().to_lower()
	if water == "":
		water = "land"
	if water not in ["land", "normal_water", "islands"]:
		_fail("HEROES_AI_MATCH_WATER must be land, normal_water or islands, got %s." % water)
		return
	var levels := int(_env("HEROES_AI_MATCH_LEVELS")) if _env("HEROES_AI_MATCH_LEVELS") != "" else 1
	if levels not in [1, 2]:
		_fail("HEROES_AI_MATCH_LEVELS must be 1 or 2, got %d." % levels)
		return
	# Turn time by phase is always recorded; the ledger keeps it per player.
	OS.set_environment("HEROES_STRATEGIC_AI_PROFILE", "1")
	var trace := _env("HEROES_AI_MATCH_TRACE").strip_edges() not in ["", "0"]
	var keep_session := _env("HEROES_AI_MATCH_KEEP_SESSION").strip_edges() != "0"
	var digest_path := _env("HEROES_AI_MATCH_DIGEST").strip_edges()
	if digest_path != "":
		_digest_file = FileAccess.open(digest_path, FileAccess.WRITE)
		if _digest_file == null:
			_fail("HEROES_AI_MATCH_DIGEST %s cannot be written." % digest_path)
			return
	_dump_path = _env("HEROES_AI_MATCH_DUMP").strip_edges()
	if _dump_path != "" and _env("HEROES_AI_MATCH_DUMP_DAY").strip_edges() != "":
		_dump_day = int(_env("HEROES_AI_MATCH_DUMP_DAY"))
		max_days = mini(max_days, _dump_day)
	for item in _env("HEROES_AI_MATCH_DIGEST_BLANK").split(",", false):
		item = item.strip_edges()
		if item.begins_with("overworld.") or item.begins_with("flags."):
			_blank_scopes.append(item)
		else:
			_blank_fields[item] = true

	var rng := RandomNumberGenerator.new()
	rng.seed = hash(match_seed)
	var faction_ids := []
	for option in ScenarioSelectRulesScript.random_map_faction_options():
		faction_ids.append(String(option.get("id", "")))
	faction_ids.sort()
	var drawn := []
	for _seat in range(player_count):
		drawn.append(String(faction_ids[rng.randi_range(0, faction_ids.size() - 1)]))
	var chosen := _env("HEROES_AI_MATCH_FACTIONS").strip_edges()
	if chosen != "":
		drawn = Array(chosen.split(",", false)).map(func(id): return String(id).strip_edges())
		if drawn.size() != player_count or drawn.any(func(id): return not faction_ids.has(id)):
			_fail("HEROES_AI_MATCH_FACTIONS needs %d of %s, got %s." % [player_count, JSON.stringify(faction_ids), chosen])
			return
	var seat_weights := _seat_weights(_env("HEROES_AI_MATCH_WEIGHTS"), player_count)
	if _failed:
		return
	var map_seed := str(rng.randi())
	# A two-player match keeps the map seed it always drew.
	if player_count != 2:
		map_seed = "%s-p%d" % [map_seed, player_count]

	# Swapping keeps the map and trades the two factions' starting places.
	var seat_factions := drawn.duplicate()
	if swapped:
		seat_factions.reverse()
	var prepare_path := _env("HEROES_AI_MATCH_PREPARE").strip_edges()
	if prepare_path != "":
		_prepare(prepare_path, {
			"match_seed": match_seed,
			"map_seed": map_seed,
			"swapped": swapped,
			"seat_factions": seat_factions,
			"player_count": player_count,
			"size_class": size_class,
			"guards": guards,
			"water": water,
			"levels": levels,
			"seat_weights": seat_weights,
			"roll_seed": _env("HEROES_AI_MATCH_ROLL_SEED").strip_edges(),
		})
		return
	var session = _start_session(map_seed, seat_factions, player_count, size_class, guards, water, levels)
	if session == null:
		return
	var roll_seed := _env("HEROES_AI_MATCH_ROLL_SEED").strip_edges()
	if roll_seed != "":
		session.flags["ai_match_roll_seed"] = roll_seed
	var seats := []
	for record in session.overworld.get("players", []):
		seats.append(String(record.get("player_id", "")))
	if seats.size() != player_count:
		_fail("Expected a %d-player map, got %s." % [player_count, JSON.stringify(seats)])
		return
	var start_treasury: Dictionary = session.overworld.get("resources", {}).duplicate(true)
	if AiSeatRulesScript.hand_human_seat_to_ai(session) != seats[0]:
		_fail("The human seat could not be handed to the computer.")
		return
	session.flags[AiHeroRulesScript.BATTLE_LOG_FLAG] = true
	for index in range(seat_weights.size()):
		var weight_set := String(seat_weights[index].set)
		if weight_set != AiHeroRulesScript.DEFAULT_WEIGHT_SET:
			_state(session, String(seats[index]))[AiHeroRulesScript.WEIGHT_SET_KEY] = weight_set

	var handover := _check_handover(session, seats, seat_factions, start_treasury)
	if _failed:
		return

	var setup := {
		"match_seed": match_seed,
		"map_seed": map_seed,
		"swapped": swapped,
		"scenario_id": String(session.scenario_id),
		"map_size": session.overworld.get("map_size", {}),
		"guards": guards,
		"water": water,
		"levels": levels,
		"start_treasury": _live_resources(start_treasury),
		"seats": [],
	}
	if roll_seed != "":
		setup["roll_seed"] = roll_seed
	for seat in seats:
		var faction := ContentService.get_faction(PlayerRules.faction_id(session, seat))
		var capitals := []
		for entry in _towns_of(session, seat):
			capitals.append({"placement_id": String(entry.get("placement_id", "")), "name": _town_name(entry), "x": int(entry.get("x", 0)), "y": int(entry.get("y", 0))})
		setup.seats.append({"player_id": seat, "faction_id": PlayerRules.faction_id(session, seat), "faction": String(faction.get("name", "")), "towns": capitals})
		if not seat_weights.is_empty():
			setup.seats[setup.seats.size() - 1]["weights"] = seat_weights[setup.seats.size() - 1]

	var ledger := []
	var timeline := []
	var heroes_seen := {}
	var captures_seen := [0]
	var ai_ms_max := 0
	var winner := ""
	var town_weeks := [_town_snapshot(session)]
	ledger.append(_day_row(session, seats))
	# Between days the runner only reads the session and empties the decision
	# log, which the overworld normalize does not read, so each end_turn can
	# skip renormalizing the session the previous one left normalized.
	session.set_meta(OverworldRules.SESSION_UNTOUCHED_BETWEEN_DAYS_META, true)
	# For the same reason the native day can keep the session from one day to
	# the next: it reads again only the flags, after the decision log empties.
	if keep_session:
		DayEngineScript.session_calls[&"OverworldRules.end_turn"] = true
	_digest_day(session)
	while int(session.day) < max_days:
		var started := Time.get_ticks_msec()
		var turn: Dictionary = OverworldRules.end_turn(session)
		ai_ms_max = maxi(ai_ms_max, Time.get_ticks_msec() - started)
		if String(session.game_state) != "overworld" or not session.battle.is_empty():
			_fail("Day %d left the overworld (%s) with no human seat." % [int(session.day), String(session.game_state)])
			return
		_digest_day(session)
		_note_changes(session, seats, captures_seen, heroes_seen, timeline)
		if trace:
			_print_trace(session, seats)
		var row := _day_row(session, seats)
		# Every hero decision of the day, with the alternatives it weighed.
		row["decisions"] = session.flags.get(AiHeroRulesScript.DECISION_LOG_KEY, [])
		session.flags[AiHeroRulesScript.DECISION_LOG_KEY] = []
		NativeRulesScript.api().port_session_reread(session.flags)
		# Where each computer player's turn went, in milliseconds by phase.
		for faction_profile in turn.get("enemy_turn_profile", {}).get("factions", []):
			if faction_profile is Dictionary and row.sides.has(String(faction_profile.get("player_id", ""))):
				row.sides[String(faction_profile.player_id)]["turn_ms"] = faction_profile.get("phases_ms", {})
		ledger.append(row)
		if int(session.day) % 7 == 1:
			town_weeks.append(_town_snapshot(session))
		if AiSeatRulesScript.match_over(session):
			var standing := AiSeatRulesScript.standing_players(session)
			winner = String(standing[0]) if not standing.is_empty() else "none"
			break
	DayEngineScript.session_calls.erase(&"OverworldRules.end_turn")
	NativeRulesScript.api().port_session_close()

	var battles: Array = session.flags.get(AiHeroRulesScript.BATTLE_LOG_KEY, [])
	var record := {
		"report_id": REPORT_ID,
		"setup": setup,
		"winner": winner,
		"final_day": int(session.day),
		"decided": winner != "",
		"day_cap": max_days,
		"ai_turn_ms_max": ai_ms_max,
		"battles": battles,
		"timeline": timeline,
		"heroes": heroes_seen.values(),
		"ledger": ledger,
		"town_weeks": town_weeks,
	}
	var file := FileAccess.open(_out_path, FileAccess.WRITE)
	if file != null:
		file.store_string(JSON.stringify(record, "  "))
		file.close()

	var port_failures := _native_port_failures()
	if port_failures != "":
		_fail(port_failures)
		return

	var summary := {
		"ok": true,
		"match_seed": match_seed,
		"map_seed": map_seed,
		"factions": setup.seats.map(func(row): return row.faction_id),
		"handover": handover,
		"winner": winner,
		"winner_faction": PlayerRules.faction_id(session, winner) if winner not in ["", "none"] else "",
		"final_day": int(session.day),
		"battles": battles.size(),
		"timeline_events": timeline.size(),
		"ai_turn_ms_max": ai_ms_max,
		"final": ledger[ledger.size() - 1],
		"out": ProjectSettings.globalize_path(_out_path),
		"seconds": snappedf((Time.get_ticks_msec() - _started_msec) / 1000.0, 0.1),
		"map": _map_source,
	}
	print("%s %s" % [REPORT_ID, JSON.stringify(summary)])

## HEROES_AI_MATCH_PREPARE: the match's map as _start_session makes it, with
## what match_sim_cli needs to go on as _play does: the setup and its two
## packages (the session starts from them natively), the project folder they
## name their art in, the match's settings, and the weight sets the seats play
## with. The packages travel in the snapshot, so the maps folder can lose them.
func _prepare(path: String, plan: Dictionary) -> void:
	var snapshots = load(RULES_SNAPSHOT_PATH)
	var content_path := path.get_base_dir().path_join("content.snap")
	if not FileAccess.file_exists(content_path) and not _write_content_snapshot(content_path):
		return
	var seat_factions: Array = plan.seat_factions
	var key := _map_key(String(plan.map_seed), seat_factions, int(plan.player_count), String(plan.size_class), String(plan.guards), String(plan.water), int(plan.levels))
	var made := {}
	if key == _kept_map_key and not _kept_prepared.is_empty():
		_map_source = "kept"
		made = _kept_prepared
	else:
		var generated := _map_setup(key, String(plan.map_seed), seat_factions, int(plan.player_count), String(plan.size_class), String(plan.guards), String(plan.water), int(plan.levels))
		if generated.is_empty():
			return
		var startup: Dictionary = generated.get("package_startup", {})
		var packages := {}
		for field in ["map_path", "scenario_path"]:
			var package_path := String(startup.get(field, ""))
			if not FileAccess.file_exists(package_path):
				_fail("The generated setup's %s %s does not exist." % [field, package_path])
				return
			packages[package_path] = FileAccess.get_file_as_bytes(package_path)
		made = {"setup": generated, "packages": packages}
		_kept_map_key = key if _list_mode else ""
		_kept_prepared = made if _list_mode else {}
	var setup: Dictionary = made.setup
	var scenario_id := String(setup.get("package_startup", {}).get("session_boundary_record", {}).get("scenario_id", ""))
	var prepared := plan.duplicate()
	prepared.merge({
		"setup": setup,
		"packages": made.packages,
		"project": ProjectSettings.globalize_path("res://"),
		"map": _map_source,
		"content_revision": ContentService.get_content_revision(),
		"files": {},
	})
	if not (plan.seat_weights as Array).is_empty():
		prepared.files[AiHeroRulesScript.WEIGHTS_PATH] = ContentService.load_json(AiHeroRulesScript.WEIGHTS_PATH)
	if not snapshots.write(path, prepared):
		_fail("The setup snapshot %s cannot be written." % path)
		return
	print("%s %s" % [REPORT_ID, JSON.stringify({
		"ok": true,
		"prepared": ProjectSettings.globalize_path(path),
		"out": ProjectSettings.globalize_path(_out_path),
		"match_seed": String(plan.match_seed),
		"map_seed": String(plan.map_seed),
		"map": _map_source,
		"scenario_id": scenario_id,
		"seconds": snappedf((Time.get_ticks_msec() - _started_msec) / 1000.0, 0.1),
	})])

## The whole session state of the day, before the runner empties the decision
## log; timings are kept outside the session, in the turn result.
func _digest_day(session) -> void:
	if _digest_file == null and _dump_day != int(session.day):
		return
	var parts := _state_parts(session)
	if _digest_file != null:
		_digest_file.store_line(_digest_line(int(session.day), parts))
		_digest_file.flush()
	if _dump_day == int(session.day):
		var state: Dictionary = parts[0].duplicate()
		state["overworld"] = parts[1]
		state["battle"] = parts[2]
		state["flags"] = parts[3]
		var dump := FileAccess.open(_dump_path, FileAccess.WRITE)
		if dump != null:
			dump.store_string(JSON.stringify(state, "", false, true))
			dump.close()

## The session state as the digest takes it, blanked as asked: the header
## fields, overworld, battle and flags.
func _state_parts(session) -> Array:
	var overworld: Dictionary = session.overworld
	var flags: Dictionary = session.flags
	if not _blank_scopes.is_empty():
		overworld = overworld.duplicate()
		flags = flags.duplicate()
		for scope in _blank_scopes:
			var part: Dictionary = overworld if scope.begins_with("overworld.") else flags
			var key := scope.get_slice(".", 1)
			if part.get(key) is Dictionary:
				part[key] = _blanked(part[key])
	var header := {
		"day": session.day,
		"session_id": session.session_id,
		"scenario_id": session.scenario_id,
		"game_state": session.game_state,
		"scenario_status": session.scenario_status,
		"scenario_summary": session.scenario_summary,
	}
	return [header, overworld, session.battle, flags]

## "day<TAB>digest": each part's Variant hash (hash(), which the rules
## library's gd::hash copies) as 8 hex digits.
static func _digest_line(day: int, parts: Array) -> String:
	var line := "%d\t" % day
	for part in parts:
		line += "%08x" % hash(part)
	return line

## A copy of value with every _blank_fields entry set to "", in nested
## dictionaries only; insertion order kept.
func _blanked(value: Dictionary) -> Dictionary:
	var out := {}
	for key in value:
		var child = value[key]
		if _blank_fields.has(String(key)):
			out[key] = ""
		elif child is Dictionary:
			out[key] = _blanked(child)
		else:
			out[key] = child
	return out

## The adopted session of the match's map and line-up: a copy of the one the
## match before adopted for both, else adopted from the map corpus's package and
## setup, else from a newly generated map (saved to the corpus). The generator
## stamps each seat's faction on the map, which does not depend on them: after
## a match on the same map with another line-up it reuses that map.
func _start_session(map_seed: String, seat_factions: Array, player_count: int = 2, size_class: String = "homm3_small", guards: String = "normal", water: String = "land", levels: int = 1):
	var key := _map_key(map_seed, seat_factions, player_count, size_class, guards, water, levels)
	if key == _kept_map_key and _kept_map_session != null:
		_map_source = "kept"
		var copy = _copy_session(_kept_map_session)
		SessionState.active_session = copy
		return copy
	var setup := _map_setup(key, map_seed, seat_factions, player_count, size_class, guards, water, levels)
	if setup.is_empty():
		return null
	var session = ScenarioSelectRulesScript.start_random_map_skirmish_session_from_setup(setup)
	if session == null or session.scenario_id == "":
		_fail("The generated session could not start.")
		return null
	OverworldRules.normalize_overworld_state(session)
	_kept_map_key = ""
	_kept_map_session = null
	if _list_mode:
		_kept_map_key = key
		_kept_map_session = _copy_session(session)
	return session

## Everything the generated package depends on, and where it goes.
func _map_key(map_seed: String, seat_factions: Array, player_count: int, size_class: String, guards: String, water: String, levels: int) -> String:
	return "%s|%s|%d|%s|%s|%s|%d|%s" % [map_seed, ",".join(seat_factions), player_count, size_class, guards, water, levels, ScenarioSelectRulesScript._generated_map_package_dir()]

## The map's setup from the corpus, else newly generated (saved to the corpus);
## {} when the generation failed.
func _map_setup(key: String, map_seed: String, seat_factions: Array, player_count: int, size_class: String, guards: String, water: String, levels: int) -> Dictionary:
	var entry := _corpus_entry(key)
	var setup := _corpus_setup(entry, key)
	_map_source = "corpus" if not setup.is_empty() else "generated"
	if setup.is_empty():
		var config := ScenarioSelectRulesScript.build_random_map_player_config(
			map_seed, "", "", player_count, water, levels == 2, size_class,
			ScenarioSelectRulesScript.RANDOM_MAP_TEMPLATE_SELECTION_MODE_SIZE_DEFAULT,
			String(seat_factions[0]), "", guards, seat_factions
		)
		setup = ScenarioSelectRulesScript.build_random_map_skirmish_setup_with_retry(config, "normal", ScenarioSelectRulesScript.RANDOM_MAP_PLAYER_RETRY_POLICY)
		if not bool(setup.get("ok", false)):
			_fail("Generated %s setup failed: %s" % [size_class, JSON.stringify(setup).left(600)])
			return {}
		if bool(setup.get("native_generation", {}).get("generator_core_reused", false)):
			_map_source = "reused"
		_corpus_store(entry, key, setup)
	return setup

## Every field of the session, its containers copied; what one match changes
## never reaches the copy. A container that two places shared is two after the
## copy, as after saving and loading.
func _copy_session(source):
	var copy = SessionStateStoreScript.SessionData.new()
	for property in source.get_property_list():
		if property.usage & PROPERTY_USAGE_SCRIPT_VARIABLE:
			var value = source.get(property.name)
			copy.set(property.name, value.duplicate(true) if value is Dictionary or value is Array else value)
	for name in source.get_meta_list():
		var value = source.get_meta(name)
		copy.set_meta(name, value.duplicate(true) if value is Dictionary or value is Array else value)
	return copy

## The corpus file stem of the map named by key, "" without a corpus.
func _corpus_entry(key: String) -> String:
	var corpus := _env("HEROES_AI_MATCH_MAP_CORPUS").strip_edges()
	return corpus.path_join(key.sha256_text().left(24)) if corpus != "" else ""

## The setup saved with the map, {} when the corpus has none; its package
## pair is copied to where the generator writes it, so the session is the one
## a newly generated map gives.
func _corpus_setup(entry: String, key: String) -> Dictionary:
	if entry == "" or not FileAccess.file_exists(entry + ".setup"):
		return {}
	var file := FileAccess.open(entry + ".setup", FileAccess.READ)
	var saved = file.get_var() if file != null else null
	if not (saved is Dictionary) or String(saved.get("key", "")) != key or not (saved.get("setup") is Dictionary):
		return {}
	var setup: Dictionary = saved.setup
	var startup: Dictionary = setup.get("package_startup", {})
	for pair in [[".amap", "map_path"], [".ascenario", "scenario_path"]]:
		var target := ProjectSettings.globalize_path(String(startup.get(pair[1], "")))
		DirAccess.make_dir_recursive_absolute(target.get_base_dir())
		if DirAccess.copy_absolute(entry + pair[0], target) != OK:
			return {}
	return setup

## Saves a generated map's package pair and setup; the setup goes last, so a
## map counts only when it is whole.
func _corpus_store(entry: String, key: String, setup: Dictionary) -> void:
	if entry == "" or FileAccess.file_exists(entry + ".setup"):
		return
	DirAccess.make_dir_recursive_absolute(entry.get_base_dir())
	var startup: Dictionary = setup.get("package_startup", {})
	for pair in [[".amap", "map_path"], [".ascenario", "scenario_path"]]:
		if DirAccess.copy_absolute(ProjectSettings.globalize_path(String(startup.get(pair[1], ""))), entry + pair[0]) != OK:
			push_warning("The map corpus could not take %s." % String(startup.get(pair[1], "")))
			return
	var file := FileAccess.open(entry + ".setup.part", FileAccess.WRITE)
	if file == null:
		return
	file.store_var({"key": key, "setup": setup})
	file.close()
	DirAccess.rename_absolute(entry + ".setup.part", entry + ".setup")

func _check_handover(session, seats: Array, drawn: Array, start_treasury: Dictionary) -> Dictionary:
	if PlayerRules.has_human_seat(session):
		_fail("A human seat is left after the handover.")
		return {}
	if not session.overworld.get("player_heroes", []).is_empty():
		_fail("Human heroes are left after the handover.")
		return {}
	var result := {}
	for index in range(seats.size()):
		var seat := String(seats[index])
		var state := _state(session, seat)
		if state.is_empty():
			_fail("%s has no computer player state." % seat)
			return {}
		if PlayerRules.faction_id(session, seat) != String(drawn[index]):
			_fail("%s plays %s, not the drawn %s." % [seat, PlayerRules.faction_id(session, seat), drawn[index]])
			return {}
		if _towns_of(session, seat).is_empty():
			_fail("%s holds no town." % seat)
			return {}
		if _live_resources(state.get("treasury", {})) != _live_resources(start_treasury):
			_fail("%s starts with %s, not %s." % [seat, JSON.stringify(state.get("treasury", {})), JSON.stringify(start_treasury)])
			return {}
		result[seat] = {"faction": String(drawn[index]), "towns": _towns_of(session, seat).size()}
	return result

## Each seat's weight set from HEROES_AI_MATCH_WEIGHTS, [] when it is unset.
## Sets from files join the content document for this run
## (ContentService.set_content_override), named by seat.
func _seat_weights(spec: String, player_count: int) -> Array:
	if spec.strip_edges() == "":
		return []
	var entries := Array(spec.split(",")).map(func(item): return String(item).strip_edges())
	if entries.size() != player_count:
		_fail("HEROES_AI_MATCH_WEIGHTS needs %d entries, got %s." % [player_count, spec])
		return []
	var doc: Dictionary = ContentService.load_json(AiHeroRulesScript.WEIGHTS_PATH).duplicate(true)
	var sets: Dictionary = doc.get("sets", {})
	var result := []
	var added := false
	for index in range(entries.size()):
		var entry := String(entries[index])
		if entry == "":
			entry = AiHeroRulesScript.DEFAULT_WEIGHT_SET
		if entry.ends_with(".json"):
			var parsed = JSON.parse_string(FileAccess.get_file_as_string(entry)) if FileAccess.file_exists(entry) else null
			if not (parsed is Dictionary):
				_fail("HEROES_AI_MATCH_WEIGHTS: %s holds no JSON object." % entry)
				return []
			var set_name := "match_seat_%d" % (index + 1)
			sets[set_name] = parsed
			result.append({"set": set_name, "file": entry, "values": parsed})
			added = true
		elif sets.has(entry):
			result.append({"set": entry})
		else:
			_fail("HEROES_AI_MATCH_WEIGHTS: %s has no weight set %s." % [AiHeroRulesScript.WEIGHTS_PATH, entry])
			return []
	if added and not ContentService.set_content_override(AiHeroRulesScript.WEIGHTS_PATH, doc):
		_fail("HEROES_AI_MATCH_WEIGHTS: the weight sets do not fit %s." % AiHeroRulesScript.WEIGHTS_PATH)
		return []
	return result

func _state(session, seat: String) -> Dictionary:
	for state in session.overworld.get("enemy_states", []):
		if state is Dictionary and PlayerRules.controller_id(state) == seat:
			return state
	return {}

func _towns_of(session, seat: String) -> Array:
	var result := []
	for town in session.overworld.get("towns", []):
		if town is Dictionary and String(town.get("owner", "")) == "enemy" and PlayerRules.town_controller_id(town) == seat:
			result.append(town)
	return result

func _town_name(town: Dictionary) -> String:
	return String(EnemyTurnRules._town_name(town))

func _town(session, placement_id: String) -> Dictionary:
	for town in session.overworld.get("towns", []):
		if town is Dictionary and String(town.get("placement_id", "")) == placement_id:
			return town
	return {}

func _live_resources(pool: Dictionary) -> Dictionary:
	var result := {}
	for key in pool:
		if int(pool[key]) != 0:
			result[String(key)] = int(pool[key])
	return result

## Town captures, hires and fallen heroes since yesterday. A town can change
## hands twice in one day, so captures come from the capture log.
func _note_changes(session, seats: Array, captures_seen: Array, heroes_seen: Dictionary, timeline: Array) -> void:
	var captures: Array = session.flags.get(AiHeroRulesScript.CAPTURE_LOG_KEY, [])
	for index in range(captures_seen[0], captures.size()):
		var logged: Dictionary = captures[index]
		var town := _town(session, String(logged.get("town_placement_id", "")))
		timeline.append({
			"day": int(logged.get("day", 0)),
			"type": "town_captured",
			"town": String(logged.get("town", "")),
			"x": int(town.get("x", 0)),
			"y": int(town.get("y", 0)),
			"from": String(logged.get("from", "")),
			"to": String(logged.get("player_id", "")),
			"hero": String(logged.get("hero", "")),
			"hero_power": snappedf(float(logged.get("hero_power", 0.0)), 0.1),
			"garrison_power": snappedf(float(logged.get("garrison_power", 0.0)), 0.1),
		})
	captures_seen[0] = captures.size()
	# Fallen heroes stay in the encounter list, marked resolved, so a hero
	# hired and beaten on one day is still seen.
	var resolved: Array = session.overworld.get("resolved_encounters", [])
	for entry in session.overworld.get("encounters", []):
		if not (entry is Dictionary) or not AiHeroRulesScript.is_ai_hero(entry):
			continue
		var seat := PlayerRules.raid_controller_id(entry)
		if seat not in seats:
			continue
		var placement_id := String(entry.get("placement_id", ""))
		var commander: Dictionary = entry.get("enemy_commander_state", {})
		if not heroes_seen.has(placement_id):
			heroes_seen[placement_id] = {"placement_id": placement_id, "player_id": seat, "hero": AiHeroRulesScript.hero_name(entry), "hired_day": int(session.day), "fell_day": 0}
			timeline.append({"day": int(session.day), "type": "hero_hired", "player_id": seat, "hero": AiHeroRulesScript.hero_name(entry)})
		var seen: Dictionary = heroes_seen[placement_id]
		if int(seen.get("fell_day", 0)) != 0:
			continue
		seen["level"] = int(commander.get("level", 1))
		seen["experience"] = int(commander.get("experience", 0))
		seen["power"] = snappedf(AiHeroRulesScript.hero_power(entry), 0.1)
		seen["battle_wins"] = int(commander.get("battle_wins", 0))
		if placement_id in resolved:
			seen["fell_day"] = int(session.day)
			timeline.append({"day": int(session.day), "type": "hero_fell", "player_id": seat, "hero": String(seen.hero)})

func _print_trace(session, seats: Array) -> void:
	for seat in seats:
		var heroes := []
		for entry in AiHeroRulesScript.active_hero_entries(session, seat):
			var goal: Dictionary = entry.get("ai_hero", {}).get("goal", {})
			heroes.append("%s(%d)@%d,%d>%s:%s" % [AiHeroRulesScript.hero_name(entry), int(AiHeroRulesScript.hero_power(entry)), int(entry.get("x", 0)), int(entry.get("y", 0)), String(goal.get("kind", "")), String(goal.get("id", "")).get_slice("_object_", 1)])
		var towns := []
		for town in _towns_of(session, seat):
			towns.append("%s@%d,%d g%d" % [_town_name(town), int(town.get("x", 0)), int(town.get("y", 0)), int(AiHeroRulesScript.army_power(town.get("garrison", []))) ])
		print("MATCH_TRACE d%d %s gold=%d %s | %s" % [int(session.day), seat, int(_state(session, seat).get("treasury", {}).get("gold", 0)), " ".join(heroes), " ".join(towns)])

## Every town on the map as the week starts: who holds it, what stands in it,
## what it still has for hire and what guards it.
func _town_snapshot(session) -> Dictionary:
	var rows := []
	for town in session.overworld.get("towns", []):
		if not (town is Dictionary):
			continue
		var owner := "neutral"
		if String(town.get("owner", "")) == "enemy":
			owner = PlayerRules.town_controller_id(town)
		rows.append({
			"name": _town_name(town), "x": int(town.get("x", 0)), "y": int(town.get("y", 0)), "owner": owner,
			"faction": String(ContentService.get_town(String(town.get("town_id", ""))).get("faction_id", "")),
			"built": (town.get("built_buildings", []) as Array).duplicate(),
			"recruits": (town.get("available_recruits", {}) as Dictionary).duplicate(),
			"garrison": AiHeroRulesScript.army_power(town.get("garrison", [])),
			"recruits_power": AiHeroRulesScript.army_power((town.get("available_recruits", {}) as Dictionary).keys().map(func(unit_id): return {"unit_id": String(unit_id), "count": int(town.get("available_recruits", {}).get(unit_id, 0))})),
			"stacks": (town.get("garrison", []) as Array).map(func(stack): return "%s:%d" % [String(stack.get("unit_id", "")), int(stack.get("count", 0))]),
		})
	return {"day": int(session.day), "towns": rows}

func _day_row(session, seats: Array) -> Dictionary:
	var row := {"day": int(session.day), "sides": {}}
	for seat in seats:
		var state := _state(session, seat)
		var towns := _towns_of(session, seat)
		var buildings := 0
		var garrison_power := 0.0
		for town in towns:
			buildings += (town.get("built_buildings", []) as Array).size()
			garrison_power += AiHeroRulesScript.army_power(town.get("garrison", []))
		var heroes := []
		var hero_power := 0.0
		for entry in AiHeroRulesScript.active_hero_entries(session, seat):
			var power := AiHeroRulesScript.hero_power(entry)
			hero_power += power
			heroes.append({"hero": AiHeroRulesScript.hero_name(entry), "level": int(entry.get("enemy_commander_state", {}).get("level", 1)), "power": snappedf(power, 0.1), "x": int(entry.get("x", 0)), "y": int(entry.get("y", 0))})
		var sites := 0
		for node in session.overworld.get("resource_nodes", []):
			if node is Dictionary and PlayerRules.resource_controller_id(node) == seat:
				sites += 1
		row.sides[seat] = {
			"treasury": _live_resources(state.get("treasury", {})),
			"towns": towns.size(),
			"buildings": buildings,
			"heroes": heroes,
			"hero_power": snappedf(hero_power, 0.1),
			"garrison_power": snappedf(garrison_power, 0.1),
			"sites": sites,
			"explored": AiHeroRulesScript.explored_tile_count(state),
			"economy": (session.flags.get(AiHeroRulesScript.ECONOMY_LOG_KEY, {}).get(seat, {}) as Dictionary).duplicate(),
		}
	return row

## The native port's failures in this match (AurelionRules.port_stats, which
## counts from the process start): failed calls, shadow mismatches and names it
## does not have. Each printed a SCRIPT ERROR, which a release export does not
## print, so the match fails here too.
func _native_port_failures() -> String:
	var stats: Dictionary = NativeRulesScript.api().port_stats()
	var failed := PackedStringArray()
	for name in stats:
		var entry = stats[name]
		var before = _stats_before.get(name, {})
		if not (entry is Dictionary) or not (before is Dictionary):
			continue
		var errors := int(entry.get("errors", 0)) - int(before.get("errors", 0))
		var mismatches := int(entry.get("mismatches", 0)) - int(before.get("mismatches", 0))
		if errors + mismatches > 0:
			failed.append("%s (%d errors, %d mismatches)" % [name, errors, mismatches])
	var unknown := int(stats.get("unknown_calls", 0)) - int(_stats_before.get("unknown_calls", 0))
	if unknown > 0:
		failed.append("%d calls of names it does not have" % unknown)
	if failed.is_empty():
		return ""
	return "The native rules port failed: %s." % ", ".join(failed)

func _cleanup() -> void:
	ContentService.clear_generated_scenario_drafts()
	ContentService.clear_content_overrides()

func _fail(message: String) -> void:
	if _failed:
		return
	_failed = true
	push_error(message)
	print("%s %s" % [REPORT_ID, JSON.stringify({"ok": false, "error": message, "out": ProjectSettings.globalize_path(_out_path),
		"seconds": snappedf((Time.get_ticks_msec() - _started_msec) / 1000.0, 0.1)})])
