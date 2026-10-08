extends Node
## The resource bar shows each resource's daily income beside its amount
## ("5000 +500"), on the overworld and in town (owner request 2026-10-08), and
## it is exactly what the next daybreak pays. Runs on a generated small map with
## two flagged sites so non-gold income shows too.

const ScenarioSelectRulesScript = preload("res://scripts/core/ScenarioSelectRules.gd")
const PlayerRules = preload("res://scripts/core/PlayerIdentityRules.gd")
const OverworldShellScene = preload("res://scenes/overworld/OverworldShell.tscn")
const TownShellScene = preload("res://scenes/town/TownShell.tscn")
const REPORT_ID := "RESOURCE_BAR_DAILY_INCOME_REPORT"
const SEED := "resource-bar-daily-income-20261008"

var _checks := 0
var _failures := []

func _ready() -> void:
	call_deferred("_run")

func _frames(count: int) -> void:
	for i in range(count):
		await get_tree().process_frame

func _check(condition: bool, label: String) -> void:
	_checks += 1
	if not condition:
		_failures.append(label)
		push_error("%s check failed: %s" % [REPORT_ID, label])

func _run() -> void:
	var config := ScenarioSelectRulesScript.build_random_map_player_config(SEED, "", "", 2, "land", false, "homm3_small", ScenarioSelectRulesScript.RANDOM_MAP_TEMPLATE_SELECTION_MODE_SIZE_DEFAULT, "faction_embercourt", "hero_caelen")
	var setup := ScenarioSelectRulesScript.build_random_map_skirmish_setup_with_retry(config, "normal", ScenarioSelectRulesScript.RANDOM_MAP_PLAYER_RETRY_POLICY)
	if not bool(setup.get("ok", false)):
		_check(false, "small generated setup")
		_finish({})
		return
	var session = ScenarioSelectRulesScript.start_random_map_skirmish_session_from_setup(setup)
	OverworldRules.normalize_overworld_state(session)
	session = SessionState.set_active_session(session)
	var flagged := _flag_income_sites(session)
	_check(flagged.size() == 2, "two daily non-gold income sites flagged for the player: %s" % str(flagged))
	var income := OverworldRules.player_daily_income(session)
	_check(int(income.get("gold", 0)) > 0, "the starting town earns gold")
	for resource_id in flagged:
		_check(int(income.get(resource_id, 0)) > 0, "flagged site adds %s income" % resource_id)

	var shell = OverworldShellScene.instantiate()
	add_child(shell)
	await _frames(8)
	_check_bar(shell.get("_resource_label"), income, "overworld")
	shell.queue_free()
	await _frames(2)

	var town := _first_player_town(session)
	_check(not town.is_empty(), "the player starts with a town")
	if not town.is_empty():
		_move_active_hero_to_town(session, town)
		var town_shell = TownShellScene.instantiate()
		add_child(town_shell)
		await _frames(8)
		_check_bar(town_shell.get("_resource_label"), income, "town")
		town_shell.queue_free()
		await _frames(2)

	var before: Dictionary = (session.overworld.get("resources", {}) as Dictionary).duplicate(true)
	OverworldRules.end_turn(session)
	var after: Dictionary = session.overworld.get("resources", {})
	for resource_id in OverworldRules.LIVE_STOCKPILE_RESOURCE_KEYS:
		var gained := int(after.get(resource_id, 0)) - int(before.get(resource_id, 0))
		_check(gained == int(income.get(resource_id, 0)), "next daybreak pays the shown %s income (%d paid, %d shown)" % [resource_id, gained, int(income.get(resource_id, 0))])
	_finish({"income": income, "flagged": flagged})

func _check_bar(menu: ResourceStockpileMenu, income: Dictionary, label: String) -> void:
	_check(menu != null, "%s has its resource bar" % label)
	if menu == null:
		return
	var snapshot: Dictionary = menu.validation_snapshot()
	var shown: Dictionary = snapshot.get("daily_income", {})
	for resource_id in OverworldRules.LIVE_STOCKPILE_RESOURCE_KEYS:
		var daily := int(income.get(resource_id, 0))
		_check(int(shown.get(resource_id, 0)) == daily, "%s bar income for %s" % [label, resource_id])
		var cell: HBoxContainer = menu._inline_cells.get(resource_id)
		_check(cell != null, "%s bar has a %s cell" % [label, resource_id])
		if cell == null:
			continue
		var income_label: Label = cell.get_child(2)
		_check(income_label.text == ("-" if daily < 0 else "+") + menu._inline_amount(absi(daily)), "%s %s income reads %s" % [label, resource_id, income_label.text])
		_check(income_label.is_visible_in_tree() and income_label.get_global_rect().position.x >= cell.get_child(1).get_global_rect().end.x, "%s %s income sits after the amount" % [label, resource_id])
		_check(cell.tooltip_text.ends_with("(%+d per day)" % daily), "%s %s tooltip names the daily income" % [label, resource_id])

## Flags the first two daily sites earning different non-gold resources.
func _flag_income_sites(session) -> Array:
	var flagged := []
	for node in session.overworld.get("resource_nodes", []):
		if flagged.size() >= 2 or not (node is Dictionary) or PlayerRules.resource_controller_id(node) != "":
			continue
		var site := ContentService.get_resource_site(String(node.get("site_id", "")))
		if not bool(site.get("persistent_control", false)) or String(site.get("control_income_cadence", "daily")) != "daily":
			continue
		var control_income: Dictionary = site.get("control_income", {}) if site.get("control_income", {}) is Dictionary else {}
		for resource_id in control_income:
			if String(resource_id) != "gold" and int(control_income[resource_id]) > 0 and not flagged.has(String(resource_id)):
				PlayerRules.set_resource_controller(node, session, "player")
				flagged.append(String(resource_id))
				break
	return flagged

func _first_player_town(session) -> Dictionary:
	for town in session.overworld.get("towns", []):
		if town is Dictionary and String(town.get("owner", "")) == "player":
			return town
	return {}

func _move_active_hero_to_town(session, town: Dictionary) -> void:
	var position := {"x": int(town.get("x", 0)), "y": int(town.get("y", 0))}
	session.overworld["hero_position"] = position.duplicate(true)
	var hero = session.overworld.get("hero", {})
	if hero is Dictionary:
		hero["position"] = position.duplicate(true)
	for record in session.overworld.get("player_heroes", []):
		if record is Dictionary and String(record.get("id", "")) == String(session.overworld.get("active_hero_id", "")):
			record["position"] = position.duplicate(true)

func _finish(details: Dictionary) -> void:
	var report := {"ok": _failures.is_empty(), "checks": _checks, "failures": _failures, "details": details}
	print("%s %s" % [REPORT_ID, JSON.stringify(report)])
	get_tree().quit(0 if _failures.is_empty() else 1)
