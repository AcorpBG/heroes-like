extends Node

const TownShellScene = preload("res://scenes/town/TownShell.tscn")

const REPORT_SCHEMA := "town_recruitment_ui_surface_report_v1"
const SCENARIO_ID := "river-pass"
const TARGET_FACTION_COUNT := 6
const TARGET_TIER_COUNT := 7
const LIVE_STOCKPILE_RESOURCE_IDS := [
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

var _errors := []

func _ready() -> void:
	call_deferred("_run")

func _run() -> void:
	var faction_ids := ContentService.get_content_ids(ContentService.FACTIONS_PATH)
	faction_ids.sort()
	var rows := []
	var recruitment_action_count := 0
	var tier_button_case_count := 0
	var portrait_loaded_count := 0
	for faction_id_value in faction_ids:
		var faction := ContentService.get_faction(String(faction_id_value))
		if faction.is_empty():
			continue
		var row: Dictionary = await _run_faction_case(faction)
		rows.append(row)
		recruitment_action_count += int(row.get("recruitment_action_count", 0))
		tier_button_case_count += int(row.get("tier_button_case_count", 0))
		portrait_loaded_count += int(row.get("portrait_loaded_count", 0))
		if not bool(row.get("ok", false)):
			for error_value in row.get("errors", []):
				_errors.append(String(error_value))

	if rows.size() != TARGET_FACTION_COUNT:
		_errors.append("Expected %d faction recruitment UI cases, got %d." % [TARGET_FACTION_COUNT, rows.size()])

	var report := {
		"ok": _errors.is_empty(),
		"schema": REPORT_SCHEMA,
		"faction_case_count": rows.size(),
		"target_tier_count": TARGET_TIER_COUNT,
		"recruitment_action_count": recruitment_action_count,
		"tier_button_case_count": tier_button_case_count,
		"portrait_loaded_count": portrait_loaded_count,
		"live_stockpile_resource_ids": LIVE_STOCKPILE_RESOURCE_IDS,
		"cases": rows,
		"errors": _errors,
		"caveats": [
			"Each case instantiates the live TownShell for a fully developed seed town with seven faction units waiting in reserve.",
			"The report validates player-facing recruit buttons, tooltips, portrait loading, tier labels, affordability, and recruitment text surfaces.",
			"This is TownShell recruitment-surface evidence, not final town art, final economy tuning, or scenario-wide balance approval.",
		],
	}
	if _errors.is_empty():
		print("TOWN_RECRUITMENT_UI_SURFACE_REPORT %s" % JSON.stringify(report))
	else:
		push_error("TOWN_RECRUITMENT_UI_SURFACE_REPORT failed: %s" % JSON.stringify(report))
	get_tree().quit(0 if _errors.is_empty() else 1)

func _run_faction_case(faction: Dictionary) -> Dictionary:
	var errors := []
	var faction_id := String(faction.get("id", ""))
	var town_id := String(faction.get("seed_town_id", ""))
	var ladder_ids := _string_array(faction.get("unit_ladder_ids", []))
	var signature_ids := _string_array(faction.get("signature_building_ids", []))
	var town_template := ContentService.get_town(town_id)
	var row := {
		"faction_id": faction_id,
		"town_id": town_id,
		"errors": errors,
	}
	if town_template.is_empty():
		errors.append("%s seed town %s is missing." % [faction_id, town_id])
		row["ok"] = false
		return row
	if ladder_ids.size() != TARGET_TIER_COUNT:
		errors.append("%s unit ladder must expose seven tiers." % faction_id)
	if signature_ids.size() != TARGET_TIER_COUNT:
		errors.append("%s signature building ladder must expose seven tiers." % faction_id)

	var session = ScenarioFactory.create_session(SCENARIO_ID, "normal", SessionState.LAUNCH_MODE_SKIRMISH)
	OverworldRules.normalize_overworld_state(session)
	var placement_id := "town_recruitment_ui_%s" % town_id
	var town_state := _town_state_for_surface_case(town_template, faction_id, placement_id, signature_ids, ladder_ids)
	session.overworld["towns"] = [town_state]
	session.overworld["resources"] = _deep_resources()
	session.day = 30
	_move_active_hero_to_town(session, town_state)
	var visit_result: Dictionary = OverworldRules.set_active_town_visit(session, placement_id)
	if not bool(visit_result.get("ok", false)):
		errors.append("%s could not open TownShell visit: %s." % [town_id, JSON.stringify(visit_result)])
	session = SessionState.set_active_session(session)

	var shell = TownShellScene.instantiate()
	add_child(shell)
	await get_tree().process_frame
	await get_tree().process_frame
	shell.call("validation_force_refresh")
	await get_tree().process_frame

	var snapshot: Dictionary = shell.call("validation_snapshot")
	var action_catalog: Dictionary = shell.call("validation_action_catalog")
	var recruit_actions: Array = action_catalog.get("recruit", []) if action_catalog.get("recruit", []) is Array else []
	var tooltip_surface: Dictionary = snapshot.get("town_action_button_tooltips", {}) if snapshot.get("town_action_button_tooltips", {}) is Dictionary else {}
	var recruit_tooltips: Array = tooltip_surface.get("recruit", []) if tooltip_surface.get("recruit", []) is Array else []
	var unit_art_summary: Dictionary = shell.call("validation_unit_art_summary")
	var tier_rows := []
	var tier_button_case_count := 0

	if recruit_actions.size() != TARGET_TIER_COUNT:
		errors.append("%s TownShell recruit action count expected %d, got %d." % [town_id, TARGET_TIER_COUNT, recruit_actions.size()])
	if int(snapshot.get("recruit_action_count", 0)) != TARGET_TIER_COUNT:
		errors.append("%s validation snapshot recruit_action_count expected %d, got %d." % [town_id, TARGET_TIER_COUNT, int(snapshot.get("recruit_action_count", 0))])
	if int(unit_art_summary.get("portrait_loaded_count", 0)) != TARGET_TIER_COUNT:
		errors.append("%s TownShell did not load all seven recruit portraits: %s." % [town_id, JSON.stringify(unit_art_summary)])

	var recruit_text := String(snapshot.get("recruit_tooltip_text", ""))
	for index in range(ladder_ids.size()):
		var unit_id := String(ladder_ids[index])
		var expected_tier := index + 1
		var tier_label := "Tier %d" % expected_tier
		var unit := ContentService.get_unit(unit_id)
		var unit_name := String(unit.get("name", unit_id))
		var action := _action_by_id(recruit_actions, "recruit:%s" % unit_id)
		var tooltip := _tooltip_for_unit(recruit_tooltips, unit_name)
		var tier_row := {
			"ok": false,
			"unit_id": unit_id,
			"unit_name": unit_name,
			"expected_tier": expected_tier,
			"tier_label": tier_label,
			"button_text": String(tooltip.get("text", "")),
			"button_tooltip": String(tooltip.get("tooltip", "")),
		}
		if action.is_empty():
			tier_row["error"] = "missing recruit action"
		elif int(action.get("unit_tier", 0)) != expected_tier:
			tier_row["error"] = "action unit_tier mismatch"
		elif String(action.get("tier_label", "")) != tier_label:
			tier_row["error"] = "action tier_label mismatch"
		elif int(action.get("available_count", 0)) <= 0:
			tier_row["error"] = "available_count missing"
		elif int(action.get("direct_affordable_count", 0)) <= 0:
			tier_row["error"] = "direct_affordable_count missing"
		elif String(action.get("button_label", "")).find(tier_label) < 0:
			tier_row["error"] = "button_label missing tier"
		elif String(action.get("summary", "")).find(tier_label) < 0:
			tier_row["error"] = "summary missing tier"
		elif String(tooltip.get("text", "")).find(tier_label) < 0:
			tier_row["error"] = "visible button text missing tier"
		elif String(tooltip.get("tooltip", "")).find(tier_label) < 0:
			tier_row["error"] = "button tooltip missing tier"
		elif recruit_text.find(tier_label) < 0 or recruit_text.find(unit_name) < 0:
			tier_row["error"] = "recruitment tooltip text missing tier or unit"
		else:
			tier_row["ok"] = true
			tier_button_case_count += 1
		if not bool(tier_row.get("ok", false)):
			errors.append("%s %s UI tier surface failed: %s." % [town_id, unit_id, String(tier_row.get("error", "unknown"))])
		tier_rows.append(tier_row)

	row["ok"] = errors.is_empty()
	row["recruitment_action_count"] = recruit_actions.size()
	row["tier_button_case_count"] = tier_button_case_count
	row["portrait_loaded_count"] = int(unit_art_summary.get("portrait_loaded_count", 0))
	row["recruit_visible_text"] = String(snapshot.get("recruit_visible_text", ""))
	row["recruit_tooltip_text"] = recruit_text
	row["tiers"] = tier_rows
	row["errors"] = errors
	shell.queue_free()
	await get_tree().process_frame
	SessionState.reset_session()
	return row

func _town_state_for_surface_case(town_template: Dictionary, faction_id: String, placement_id: String, signature_ids: Array, ladder_ids: Array) -> Dictionary:
	var built := {}
	for starting_value in town_template.get("starting_building_ids", []):
		built[String(starting_value)] = true
	for building_id in signature_ids:
		built[String(building_id)] = true
	var recruits := {}
	for unit_id in ladder_ids:
		recruits[String(unit_id)] = 6
	return {
		"placement_id": placement_id,
		"town_id": String(town_template.get("id", "")),
		"owner": "player",
		"controlling_faction_id": faction_id,
		"x": 4,
		"y": 4,
		"built_buildings": _dictionary_keys(built),
		"available_recruits": recruits,
		"last_build_day": 0,
		"garrison": [],
		"recovery": {},
		"front": {},
		"occupation": {},
	}

func _deep_resources() -> Dictionary:
	var resources := {}
	for resource_id in LIVE_STOCKPILE_RESOURCE_IDS:
		resources[String(resource_id)] = 99999
	return resources

func _move_active_hero_to_town(session, town: Dictionary) -> void:
	var position: Dictionary = {"x": int(town.get("x", 0)), "y": int(town.get("y", 0))}
	session.overworld["hero_position"] = position.duplicate(true)
	var active_hero = session.overworld.get("hero", {})
	if active_hero is Dictionary:
		active_hero["position"] = position.duplicate(true)
		session.overworld["hero"] = active_hero
	var heroes = session.overworld.get("player_heroes", [])
	for index in range(heroes.size()):
		var hero = heroes[index]
		if hero is Dictionary and String(hero.get("id", "")) == String(session.overworld.get("active_hero_id", "")):
			hero["position"] = position.duplicate(true)
			heroes[index] = hero
	session.overworld["player_heroes"] = heroes

func _action_by_id(actions: Variant, action_id: String) -> Dictionary:
	if not (actions is Array):
		return {}
	for action_value in actions:
		if action_value is Dictionary and String(action_value.get("id", "")) == action_id:
			return action_value
	return {}

func _tooltip_for_unit(entries: Array, unit_name: String) -> Dictionary:
	for entry_value in entries:
		if not (entry_value is Dictionary):
			continue
		var entry: Dictionary = entry_value
		if String(entry.get("text", "")).find(unit_name) >= 0 or String(entry.get("tooltip", "")).find(unit_name) >= 0:
			return entry
	return {}

func _dictionary_keys(value: Dictionary) -> Array:
	var keys := []
	for key in value.keys():
		keys.append(String(key))
	keys.sort()
	return keys

func _string_array(value: Variant) -> Array:
	var result := []
	if value is Array:
		for entry in value:
			result.append(String(entry))
	return result
