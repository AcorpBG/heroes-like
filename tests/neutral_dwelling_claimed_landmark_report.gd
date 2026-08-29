extends Node

const MapViewScript = preload("res://scenes/overworld/OverworldMapView.gd")
const SessionStateStoreScript = preload("res://scripts/core/SessionStateStore.gd")

const REPORT_ID := "NEUTRAL_DWELLING_CLAIMED_LANDMARK_REPORT"
const OUTPUT_DIR := "res://.artifacts/neutral_dwelling_claimed_landmark_report"
const CASES := [
	{"scenario_id": "charter-bastion-counterseal", "site_id": "site_ember_signal_brazier", "placement_id": "counterseal_signal_brazier", "unclaimed_asset_id": "resource_site_live_ember_signal_brazier", "claimed_asset_id": "resource_site_live_ember_signal_brazier", "is_faction_landmark": true, "control_income": {"gold": 25}, "vision_radius": 3, "pressure_guard": 1, "pressure_bonus": 0},
	{"scenario_id": "nightglass-ledger-reversal", "site_id": "site_bog_drum_totem", "placement_id": "nightglass_bog_drum_totem", "unclaimed_asset_id": "resource_site_live_bog_drum_totem", "claimed_asset_id": "resource_site_live_bog_drum_totem", "is_faction_landmark": true, "control_income": {"gold": 20}, "vision_radius": 2, "pressure_guard": 0, "pressure_bonus": 1},
	{"scenario_id": "halo-reserve-refraction-claim", "site_id": "site_prism_relay_lens", "placement_id": "halo_prism_relay_lens", "unclaimed_asset_id": "resource_site_live_prism_relay_lens", "claimed_asset_id": "resource_site_live_prism_relay_lens", "is_faction_landmark": true, "control_income": {"gold": 20}, "vision_radius": 4, "pressure_guard": 0, "pressure_bonus": 0},
	{"scenario_id": "rootgate-toll", "site_id": "site_thornwake_graft_arch", "placement_id": "rootgate_graft_arch", "unclaimed_asset_id": "resource_site_live_thornwake_graft_arch", "claimed_asset_id": "resource_site_live_thornwake_graft_arch", "is_faction_landmark": true, "control_income": {"wood": 1}, "vision_radius": 2, "pressure_guard": 1, "pressure_bonus": 0},
	{"scenario_id": "clauseworks-counterclaim", "site_id": "site_brasshollow_gauge_shrine", "placement_id": "clauseworks_gauge_shrine", "unclaimed_asset_id": "resource_site_live_brasshollow_gauge_shrine", "claimed_asset_id": "resource_site_live_brasshollow_gauge_shrine", "is_faction_landmark": true, "control_income": {"gold": 35}, "vision_radius": 1, "pressure_guard": 0, "pressure_bonus": 1},
	{"scenario_id": "fogchart-mooring", "site_id": "site_veilmourn_bell_mast", "placement_id": "fogchart_bell_mast", "unclaimed_asset_id": "resource_site_live_veilmourn_bell_mast", "claimed_asset_id": "resource_site_live_veilmourn_bell_mast", "is_faction_landmark": true, "control_income": {"gold": 20}, "vision_radius": 3, "pressure_guard": 1, "pressure_bonus": 0},
	{"site_id": "site_reedbarge_mooring", "placement_id": "dwelling_reedbarge_mooring", "unclaimed_asset_id": "mapobj_reedbarge_mooring", "claimed_asset_id": "resource_site_neutral_reedbarge_mooring_claimed"},
	{"site_id": "site_glowcap_croft", "placement_id": "dwelling_glowcap_croft", "unclaimed_asset_id": "mapobj_glowcap_croft", "claimed_asset_id": "resource_site_neutral_glowcap_croft_claimed"},
	{"site_id": "site_dustjack_yard", "placement_id": "dwelling_dustjack_yard", "unclaimed_asset_id": "mapobj_dustjack_yard", "claimed_asset_id": "resource_site_neutral_dustjack_yard_claimed"},
	{"site_id": "site_cinder_kiln", "placement_id": "dwelling_cinder_kiln", "unclaimed_asset_id": "mapobj_cinder_kiln", "claimed_asset_id": "resource_site_neutral_cinder_kiln_claimed"},
	{"site_id": "site_frostbeacon_bothy", "placement_id": "dwelling_frostbeacon_bothy", "unclaimed_asset_id": "mapobj_frostbeacon_bothy", "claimed_asset_id": "resource_site_neutral_frostbeacon_bothy_claimed"},
	{"site_id": "site_bramble_hedge", "placement_id": "dwelling_bramble_hedge", "unclaimed_asset_id": "mapobj_bramble_hedge", "claimed_asset_id": "resource_site_neutral_bramble_hedge"},
	{"site_id": "site_tidepool_skiffyard", "placement_id": "dwelling_tidepool_skiffyard", "unclaimed_asset_id": "mapobj_tidepool_skiffyard", "claimed_asset_id": "resource_site_neutral_tidepool_skiffyard"},
	{"site_id": "site_switchback_hostel", "placement_id": "dwelling_switchback_hostel", "unclaimed_asset_id": "mapobj_switchback_hostel", "claimed_asset_id": "resource_site_neutral_switchback_hostel"},
	{"site_id": "site_saltpan_camp", "placement_id": "dwelling_saltpan_camp", "unclaimed_asset_id": "mapobj_saltpan_camp", "claimed_asset_id": "resource_site_neutral_saltpan_camp"},
	{"site_id": "site_crystal_sump", "placement_id": "dwelling_crystal_sump", "unclaimed_asset_id": "mapobj_crystal_sump", "claimed_asset_id": "resource_site_neutral_crystal_sump"},
	{"site_id": "site_icehook_trapper_lodge", "placement_id": "dwelling_icehook_trapper_lodge", "unclaimed_asset_id": "mapobj_icehook_trapper_lodge", "claimed_asset_id": "resource_site_neutral_icehook_trapper_lodge"},
	{"site_id": "site_obsidian_scar", "placement_id": "dwelling_obsidian_scar", "unclaimed_asset_id": "mapobj_obsidian_scar", "claimed_asset_id": "resource_site_neutral_obsidian_scar"},
	{"site_id": "site_free_company_yard", "placement_id": "dwelling_roadward_lodge", "unclaimed_asset_id": "mapobj_roadward_lodge", "claimed_asset_id": "resource_site_neutral_roadward_lodge_claimed"},
	{"site_id": "site_fenhound_kennels", "placement_id": "dwelling_fenhound_kennels", "unclaimed_asset_id": "kennel", "claimed_asset_id": "resource_site_neutral_fenhound_kennels_claimed"},
	{"site_id": "site_cliffhawk_roost", "placement_id": "dwelling_cliffhawk_roost", "unclaimed_asset_id": "mapobj_cliffhawk_roost", "claimed_asset_id": "resource_site_neutral_cliffhawk_roost_claimed"},
	{"site_id": "site_orchard_levy", "placement_id": "dwelling_orchard_levy", "unclaimed_asset_id": "mapobj_orchard_levy", "claimed_asset_id": "resource_site_neutral_orchard_levy"},
	{"site_id": "site_kite_signal_eyrie", "placement_id": "dwelling_kite_signal_eyrie", "unclaimed_asset_id": "mapobj_kite_signal_eyrie", "claimed_asset_id": "resource_site_neutral_kite_signal_eyrie"},
	{"site_id": "site_greenbranch_copse", "placement_id": "dwelling_greenbranch_copse", "unclaimed_asset_id": "mapobj_greenbranch_copse", "claimed_asset_id": "resource_site_neutral_greenbranch_copse"},
	{"site_id": "site_harbor_pilot_house", "placement_id": "dwelling_harbor_pilot_house", "unclaimed_asset_id": "mapobj_harbor_pilot_house", "claimed_asset_id": "resource_site_neutral_harbor_pilot_house"},
	{"site_id": "site_lantern_warren", "placement_id": "dwelling_lantern_warren", "unclaimed_asset_id": "mapobj_lantern_warren", "claimed_asset_id": "resource_site_neutral_lantern_warren"},
	{"site_id": "site_bogbell_croft", "placement_id": "dwelling_bogbell_croft", "unclaimed_asset_id": "mapobj_bogbell_croft", "claimed_asset_id": "resource_site_neutral_bogbell_croft"},
	{"site_id": "site_milestone_arsenal", "placement_id": "dwelling_milestone_arsenal", "unclaimed_asset_id": "mapobj_milestone_arsenal", "claimed_asset_id": "resource_site_neutral_milestone_arsenal"},
	{"site_id": "site_frostwharf_house", "placement_id": "dwelling_frostwharf_house", "unclaimed_asset_id": "mapobj_frostwharf_house", "claimed_asset_id": "resource_site_neutral_frostwharf_house"},
	{"site_id": "site_charcoal_burners", "placement_id": "dwelling_charcoal_burners", "unclaimed_asset_id": "mapobj_charcoal_burners", "claimed_asset_id": "resource_site_neutral_charcoal_burners"},
	{"site_id": "site_basalt_gatehouse", "placement_id": "dwelling_basalt_gatehouse", "unclaimed_asset_id": "mapobj_basalt_gatehouse", "claimed_asset_id": "resource_site_neutral_basalt_gatehouse"},
]

var _errors: Array[String] = []
var _rows: Array = []

func _ready() -> void:
	call_deferred("_run")

func _run() -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUTPUT_DIR))
	var view = MapViewScript.new()
	view.size = Vector2(1280, 720)
	add_child(view)
	await get_tree().process_frame
	for case_value in CASES:
		await _validate_case(view, case_value)
	var report := {
		"ok": _errors.is_empty(),
		"scenario_id": "multiple_authored_scenarios",
		"case_count": CASES.size(),
		"faction_landmark_count": 6,
		"save_version": SessionStateStoreScript.SAVE_VERSION,
		"rows": _rows,
		"errors": _errors,
	}
	_write_json("%s/report.json" % OUTPUT_DIR, report)
	if _errors.is_empty():
		print("%s %s" % [REPORT_ID, JSON.stringify({"ok": true, "case_count": CASES.size(), "save_version": SessionStateStoreScript.SAVE_VERSION})])
	view.queue_free()
	await get_tree().process_frame
	get_tree().quit(0 if _errors.is_empty() else 1)

func _validate_case(view: Control, case: Dictionary) -> void:
	var scenario_id := String(case.get("scenario_id", "ninefold-confluence"))
	var session: SessionStateStoreScript.SessionData = ScenarioFactory.create_session(scenario_id, "normal", SessionState.LAUNCH_MODE_SKIRMISH)
	OverworldRules.normalize_overworld_state(session)
	var placement_id := String(case.get("placement_id", ""))
	var site_id := String(case.get("site_id", ""))
	var node := _resource_node(session, placement_id)
	if node.is_empty() or String(node.get("site_id", "")) != site_id:
		_error("Missing authored neutral dwelling placement %s for %s." % [placement_id, site_id])
		return
	_prepare_unclaimed_fixture(session, placement_id)
	node = _resource_node(session, placement_id)
	_set_hero_position(session, int(node.get("x", 0)), int(node.get("y", 0)))
	var tile := Vector2i(int(node.get("x", 0)), int(node.get("y", 0)))
	var map_size := OverworldRules.derive_map_size(session)
	view.set_map_state(session, session.overworld.get("map", []), map_size, tile)
	await get_tree().process_frame
	var unclaimed_asset_id := String(view.call("_resource_asset_id", node))
	_expect(unclaimed_asset_id == String(case.get("unclaimed_asset_id", "")), "%s lost its existing unclaimed map-object art." % site_id)

	var site := ContentService.get_resource_site(site_id)
	var rewards: Dictionary = site.get("claim_rewards", {}) if site.get("claim_rewards", {}) is Dictionary else {}
	var recruits: Dictionary = site.get("claim_recruits", {}) if site.get("claim_recruits", {}) is Dictionary else {}
	var resources_before := _resource_counts(session, rewards.keys())
	var recruits_before := _army_counts(session, recruits.keys())
	var expected_income: Dictionary = case.get("control_income", {}) if case.get("control_income", {}) is Dictionary else {}
	var income_before: Dictionary = OverworldRules.controlled_resource_site_income(session, "player")
	var pressure_guard_before := OverworldRules.player_resource_site_pressure_guard(session)
	var pressure_bonus_before := OverworldRules.controlled_resource_site_pressure_bonus(session, "player")
	var claim_result: Dictionary = OverworldRules.collect_active_resource(session)
	_expect(bool(claim_result.get("ok", false)), "%s live claim failed: %s" % [site_id, claim_result.get("message", "")])
	var claimed_node := _resource_node(session, placement_id)
	_expect(String(claimed_node.get("collected_by_faction_id", "")) == "player" and bool(claimed_node.get("collected", false)), "%s did not enter persistent player control." % site_id)
	_expect(_resource_delta_exact(resources_before, _resource_counts(session, rewards.keys()), rewards), "%s claim rewards changed." % site_id)
	_expect(_resource_delta_exact(recruits_before, _army_counts(session, recruits.keys()), recruits), "%s claim recruits changed." % site_id)
	if bool(case.get("is_faction_landmark", false)):
		_expect(String(site.get("family", "")) == "faction_landmark", "%s lost its live faction-landmark family." % site_id)
		_expect(_resource_payload_matches(site.get("control_income", {}), expected_income), "%s control income contract changed." % site_id)
		_expect(int(site.get("vision_radius", 0)) == int(case.get("vision_radius", 0)), "%s vision radius contract changed." % site_id)
		_expect(_resource_delta_exact(income_before, OverworldRules.controlled_resource_site_income(session, "player"), expected_income), "%s live controlled income did not activate." % site_id)
		_expect(OverworldRules.player_resource_site_pressure_guard(session) - pressure_guard_before == int(case.get("pressure_guard", 0)), "%s live pressure guard did not activate." % site_id)
		_expect(OverworldRules.controlled_resource_site_pressure_bonus(session, "player") - pressure_bonus_before == int(case.get("pressure_bonus", 0)), "%s live pressure bonus did not activate." % site_id)
	view.set_map_state(session, session.overworld.get("map", []), map_size, tile)
	await get_tree().process_frame
	var claimed_asset_id := String(view.call("_resource_asset_id", claimed_node))
	var claimed_presentation: Dictionary = view.validation_tile_presentation(tile)
	var claimed_art: Dictionary = claimed_presentation.get("art_presentation", {}) if claimed_presentation.get("art_presentation", {}) is Dictionary else {}
	_expect(claimed_asset_id == String(case.get("claimed_asset_id", "")), "%s did not select its exact claimed landmark." % site_id)
	_expect(bool(claimed_art.get("uses_asset_sprite", false)) and not bool(claimed_art.get("fallback_procedural_marker", true)) and claimed_art.get("sprite_asset_ids", []) == [claimed_asset_id], "%s claimed landmark did not reach the live renderer." % site_id)
	var capture_path := ""
	if bool(case.get("is_faction_landmark", false)) and OS.get_environment("FACTION_LANDMARK_CAPTURE") == "1":
		_set_hero_position(session, tile.x, tile.y + 1)
		view.set_map_state(session, session.overworld.get("map", []), map_size, tile)
		await get_tree().process_frame
		await get_tree().process_frame
		capture_path = "%s/%s.png" % [ProjectSettings.globalize_path(OUTPUT_DIR), site_id]
		var capture_image := get_viewport().get_texture().get_image()
		_expect(capture_image != null and not capture_image.is_empty() and capture_image.save_png(capture_path) == OK, "%s live landmark capture failed." % site_id)
		_set_hero_position(session, tile.x, tile.y)
		view.set_map_state(session, session.overworld.get("map", []), map_size, tile)
		await get_tree().process_frame

	var authority_after_claim := session.to_dict()
	var repeat_result: Dictionary = OverworldRules.collect_active_resource(session)
	_expect(not bool(repeat_result.get("ok", true)) and session.to_dict() == authority_after_claim, "%s repeat claim must reject without mutation." % site_id)
	var restored := SessionStateStoreScript.SessionData.new()
	restored.from_dict(session.to_dict())
	var restored_node := _resource_node(restored, placement_id)
	view.set_map_state(restored, restored.overworld.get("map", []), OverworldRules.derive_map_size(restored), tile)
	await get_tree().process_frame
	var restored_asset_id := String(view.call("_resource_asset_id", restored_node))
	_expect(int(restored.save_version) == SessionStateStoreScript.SAVE_VERSION and restored_node == claimed_node and restored_asset_id == claimed_asset_id, "%s claimed art/control did not round-trip through save version %d." % [site_id, SessionStateStoreScript.SAVE_VERSION])
	_rows.append({
		"site_id": site_id,
		"placement_id": placement_id,
		"unclaimed_asset_id": unclaimed_asset_id,
		"claimed_asset_id": claimed_asset_id,
		"claim_rewards": rewards,
		"claim_recruits": recruits,
		"scenario_id": scenario_id,
		"control_income": expected_income,
		"vision_radius": int(case.get("vision_radius", 0)),
		"capture_path": capture_path,
		"repeat_rejected_without_mutation": not bool(repeat_result.get("ok", true)) and session.to_dict() == authority_after_claim,
		"save_round_trip_exact": restored_node == claimed_node and restored_asset_id == claimed_asset_id,
	})

func _prepare_unclaimed_fixture(session: SessionStateStoreScript.SessionData, placement_id: String) -> void:
	var nodes: Array = session.overworld.get("resource_nodes", [])
	for index in range(nodes.size()):
		if not (nodes[index] is Dictionary) or String(nodes[index].get("placement_id", "")) != placement_id:
			continue
		var node: Dictionary = nodes[index]
		node["collected"] = false
		node["collected_by_faction_id"] = ""
		node["collected_day"] = 0
		nodes[index] = node
		session.overworld["resource_nodes"] = nodes
		var site := ContentService.get_resource_site(String(node.get("site_id", "")))
		var guard := OverworldRules.resource_site_blocking_guard(session, node, site)
		if not guard.is_empty():
			var resolved: Array = session.overworld.get("resolved_encounters", [])
			var guard_key := OverworldRules.encounter_key(guard)
			if guard_key not in resolved:
				resolved.append(guard_key)
			session.overworld["resolved_encounters"] = resolved
		return

func _set_hero_position(session: SessionStateStoreScript.SessionData, x: int, y: int) -> void:
	session.overworld["hero_position"] = {"x": x, "y": y}
	var hero: Dictionary = session.overworld.get("hero", {})
	hero["position"] = {"x": x, "y": y}
	session.overworld["hero"] = hero
	var heroes: Array = session.overworld.get("player_heroes", [])
	for index in range(heroes.size()):
		if heroes[index] is Dictionary and String(heroes[index].get("id", "")) == String(session.hero_id):
			var roster_hero: Dictionary = heroes[index]
			roster_hero["position"] = {"x": x, "y": y}
			heroes[index] = roster_hero
			break
	session.overworld["player_heroes"] = heroes

func _resource_node(session: SessionStateStoreScript.SessionData, placement_id: String) -> Dictionary:
	for node in session.overworld.get("resource_nodes", []):
		if node is Dictionary and String(node.get("placement_id", "")) == placement_id:
			return node
	return {}

func _resource_counts(session: SessionStateStoreScript.SessionData, keys: Array) -> Dictionary:
	var result := {}
	for key_value in keys:
		var key := String(key_value)
		result[key] = int(session.overworld.get("resources", {}).get(key, 0))
	return result

func _army_counts(session: SessionStateStoreScript.SessionData, keys: Array) -> Dictionary:
	var result := {}
	for key_value in keys:
		result[String(key_value)] = 0
	for stack in session.overworld.get("hero", {}).get("army", {}).get("stacks", []):
		if stack is Dictionary and result.has(String(stack.get("unit_id", ""))):
			var unit_id := String(stack.get("unit_id", ""))
			result[unit_id] = int(result.get(unit_id, 0)) + int(stack.get("count", 0))
	return result

func _resource_delta_exact(before: Dictionary, after: Dictionary, expected: Dictionary) -> bool:
	for key_value in expected.keys():
		var key := String(key_value)
		if int(after.get(key, 0)) - int(before.get(key, 0)) != int(expected.get(key_value, 0)):
			return false
	return true

func _resource_payload_matches(actual_value: Variant, expected: Dictionary) -> bool:
	if not (actual_value is Dictionary):
		return false
	var actual: Dictionary = actual_value
	for key_value in actual.keys():
		var key := String(key_value)
		if int(actual.get(key_value, 0)) != int(expected.get(key, 0)):
			return false
	for key_value in expected.keys():
		var key := String(key_value)
		if int(actual.get(key, 0)) != int(expected.get(key_value, 0)):
			return false
	return true

func _expect(condition: bool, message: String) -> void:
	if not condition:
		_error(message)

func _error(message: String) -> void:
	_errors.append(message)
	push_error(message)

func _write_json(path: String, payload: Dictionary) -> void:
	var file := FileAccess.open(path, FileAccess.WRITE)
	if file != null:
		file.store_string(JSON.stringify(payload, "  ") + "\n")
