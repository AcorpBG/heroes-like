extends Node

const REPORT_ID := "RANDOM_MAP_FACTION_HERO_SELECTION_REPORT"
const TARGET_FACTION_ID := "faction_veilmourn"
const TARGET_HERO_ID := "hero_veilmourn_orso_nightchart"
const TARGET_TOWN_ID := "town_veilmourn_bellwake_harbor"
const TARGET_ARMY_ID := "army_bellwake_privateers"

func _ready() -> void:
	call_deferred("_run")

func _run() -> void:
	SessionState.reset_session()
	ContentService.clear_generated_scenario_drafts()
	var shell = load("res://scenes/menus/MainMenu.tscn").instantiate()
	add_child(shell)
	await get_tree().process_frame
	await get_tree().process_frame
	shell.validation_open_skirmish_stage()
	if not shell.validation_select_generated_size_class("homm3_small") \
			or not shell.validation_select_generated_player_count(2) \
			or not shell.validation_select_generated_water_mode("land") \
			or not shell.validation_set_generated_underground(false) \
			or not shell.validation_set_generated_seed("1"):
		_fail("Could not configure the focused Small two-player generated map.")
		return
	if not shell.validation_select_generated_faction(TARGET_FACTION_ID):
		_fail("Veilmourn was not available in the generated faction dropdown.")
		return
	var faction_snapshot: Dictionary = shell.validation_generated_random_map_snapshot()
	var faction_controls: Dictionary = faction_snapshot.get("controls", {})
	if String(faction_controls.get("faction_id", "")) != TARGET_FACTION_ID:
		_fail("Faction selection did not persist in the generated setup snapshot.")
		return
	for hero_id_value in faction_controls.get("hero_option_ids", []):
		var hero := ContentService.get_hero(String(hero_id_value))
		if String(hero.get("faction_id", "")) != TARGET_FACTION_ID:
			_fail("Hero dropdown retained a commander outside the selected faction: %s" % String(hero_id_value))
			return
	if not shell.validation_select_generated_hero(TARGET_HERO_ID):
		_fail("The requested Veilmourn commander was not available in the generated hero dropdown.")
		return
	var selected_snapshot: Dictionary = shell.validation_generated_random_map_snapshot()
	var selected_controls: Dictionary = selected_snapshot.get("controls", {})
	var selected_setup: Dictionary = selected_snapshot.get("setup", {})
	if String(selected_controls.get("hero_id", "")) != TARGET_HERO_ID \
			or String(selected_setup.get("player_faction_id", "")) != TARGET_FACTION_ID \
			or String(selected_setup.get("player_hero_id", "")) != TARGET_HERO_ID:
		_fail("Selected faction/hero did not reach the generated setup preview: %s" % JSON.stringify(selected_snapshot))
		return
	var launch: Dictionary = shell.validation_start_generated_skirmish()
	if not bool(launch.get("started", false)):
		_fail("Selected faction/hero generated skirmish did not launch: %s" % JSON.stringify(launch))
		return
	var session = SessionState.ensure_active_session()
	if session.hero_id != TARGET_HERO_ID \
			or String(session.overworld.get("active_hero_id", "")) != TARGET_HERO_ID:
		_fail("Generated session did not start with the selected hero: %s" % session.hero_id)
		return
	var hero: Dictionary = session.overworld.get("hero", {})
	if String(hero.get("id", "")) != TARGET_HERO_ID \
			or String(ContentService.get_hero(session.hero_id).get("faction_id", "")) != TARGET_FACTION_ID \
			or String(hero.get("army", {}).get("id", "")) != TARGET_ARMY_ID:
		_fail("Selected hero did not receive the selected faction identity and opening army: %s" % JSON.stringify(hero))
		return
	var player_town := {}
	for town_value in session.overworld.get("towns", []):
		if town_value is Dictionary and String(town_value.get("owner", "")) == "player":
			player_town = town_value
			break
	if String(player_town.get("faction_id", "")) != TARGET_FACTION_ID \
			or String(player_town.get("town_id", "")) != TARGET_TOWN_ID:
		_fail("Generated player town did not use the selected faction: %s" % JSON.stringify(player_town))
		return
	var provenance: Dictionary = session.flags.get("generated_random_map_provenance", {})
	var saved_setup: Dictionary = provenance.get("input_config", {}).get("player_setup", {})
	if String(saved_setup.get("faction_id", "")) != TARGET_FACTION_ID \
			or String(saved_setup.get("hero_id", "")) != TARGET_HERO_ID:
		_fail("Generated replay provenance did not preserve the selected identity: %s" % JSON.stringify(provenance))
		return
	print("%s %s" % [REPORT_ID, JSON.stringify({
		"ok": true,
		"scenario_id": session.scenario_id,
		"faction_id": TARGET_FACTION_ID,
		"hero_id": TARGET_HERO_ID,
		"town_id": TARGET_TOWN_ID,
		"army_id": TARGET_ARMY_ID,
		"faction_option_count": selected_controls.get("faction_option_ids", []).size(),
		"hero_option_count": selected_controls.get("hero_option_ids", []).size(),
	})])
	get_tree().quit(0)

func _fail(message: String) -> void:
	push_error("%s failed: %s" % [REPORT_ID, message])
	get_tree().quit(1)
