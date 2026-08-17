extends Node

const FrontierVisualKitScript = preload("res://scripts/ui/FrontierVisualKit.gd")
const TownStageViewScript = preload("res://scenes/town/TownStageView.gd")
const TOWN_SCENIC_BACKDROP_PATHS := {
	"faction_embercourt": "res://art/towns/runtime/backdrops/town_embercourt.png",
	"faction_mireclaw": "res://art/towns/runtime/backdrops/town_mireclaw.png",
	"faction_sunvault": "res://art/towns/runtime/backdrops/town_sunvault.png",
	"faction_thornwake": "res://art/towns/runtime/backdrops/town_thornwake.png",
	"faction_brasshollow": "res://art/towns/runtime/backdrops/town_brasshollow.png",
	"faction_veilmourn": "res://art/towns/runtime/backdrops/town_veilmourn.png",
}

func _ready() -> void:
	call_deferred("_run")

func _run() -> void:
	var original_color_cue_mode := FrontierVisualKitScript.color_cue_mode()
	FrontierVisualKitScript.set_color_cue_mode("assisted")
	if not await _run_town_smoke():
		return
	if not await _run_battle_smoke():
		return
	FrontierVisualKitScript.set_color_cue_mode(original_color_cue_mode)
	get_tree().quit(0)

func _run_town_smoke() -> bool:
	if not _assert_player_weekly_growth_forecast_parity():
		get_tree().quit(1)
		return false
	var session = ScenarioFactory.create_session(
		"river-pass",
		"normal",
		SessionState.LAUNCH_MODE_SKIRMISH
	)
	var active_town := _first_player_town(session)
	if active_town.is_empty():
		push_error("Town smoke: could not find a player-owned town in the sample scenario.")
		get_tree().quit(1)
		return false
	_move_active_hero_to_town(session, active_town)
	_seed_town_artifact_readiness_fixture(session)
	SessionState.set_active_session(session)

	var shell = load("res://scenes/town/TownShell.tscn").instantiate()
	add_child(shell)
	await get_tree().process_frame
	await get_tree().process_frame

	var board = shell.get_node_or_null("%TownStage")
	if board == null:
		push_error("Town smoke: town stage board did not load.")
		get_tree().quit(1)
		return false
	if not _assert_town_header_control_label_contract(shell, session):
		get_tree().quit(1)
		return false
	if not await _assert_town_scenic_backdrop_contract(board, session):
		get_tree().quit(1)
		return false
	if not await _assert_town_scenic_action_count_label_contract(board, session):
		get_tree().quit(1)
		return false
	if not await _assert_town_capture_frontier_status_contract(board, session):
		get_tree().quit(1)
		return false
	if not await _capture_color_cue_frame("town_scenic_backdrop"):
		get_tree().quit(1)
		return false
	var build_actions = shell.get_node_or_null("%BuildActions")
	if build_actions == null or build_actions.get_child_count() <= 0:
		push_error("Town smoke: construction action surface did not populate.")
		get_tree().quit(1)
		return false
	if not _assert_town_production_overview(shell):
		get_tree().quit(1)
		return false
	if not _assert_town_build_readiness_cue(shell):
		get_tree().quit(1)
		return false
	if not _assert_town_defense_check_cue(shell):
		get_tree().quit(1)
		return false
	if not _assert_town_trade_readiness_cue(shell):
		get_tree().quit(1)
		return false
	if not _assert_town_faction_identity_contract(shell):
		get_tree().quit(1)
		return false
	if not _assert_town_stack_inspection_contract(shell):
		get_tree().quit(1)
		return false
	if not _assert_town_hero_identity_progression_contract(shell):
		get_tree().quit(1)
		return false
	if not _assert_town_magic_inspection_contract(shell):
		get_tree().quit(1)
		return false
	if not _assert_town_study_readiness_cue(shell):
		get_tree().quit(1)
		return false
	if not _assert_town_artifact_readiness_cue(shell):
		get_tree().quit(1)
		return false
	if not _assert_town_build_recruit_next_step_contract(shell):
		get_tree().quit(1)
		return false
	if not _assert_town_field_handoff_recap_contract(shell):
		get_tree().quit(1)
		return false
	if not _assert_town_departure_confirmation_contract(shell):
		get_tree().quit(1)
		return false
	if not _assert_town_save_handoff_cue(shell):
		get_tree().quit(1)
		return false
	if not _assert_town_order_target_handoff_contract(shell):
		get_tree().quit(1)
		return false
	if not _assert_town_command_tab_readiness_cues(shell):
		get_tree().quit(1)
		return false
	if not _assert_town_muster_readiness_cue(shell):
		get_tree().quit(1)
		return false
	if not _assert_town_hire_readiness_cue(shell):
		get_tree().quit(1)
		return false
	if not _assert_town_transfer_readiness_cue(shell):
		get_tree().quit(1)
		return false
	if not _assert_town_specialty_readiness_cue(shell):
		get_tree().quit(1)
		return false
	if not _assert_town_response_readiness_cue(shell):
		get_tree().quit(1)
		return false
	if not _assert_town_action_button_command_cues(shell):
		get_tree().quit(1)
		return false
	if not _assert_active_return_handoff_contract(shell, "Town", "Menu: Town"):
		get_tree().quit(1)
		return false
	if not _assert_town_economy_decision_payload(shell):
		get_tree().quit(1)
		return false

	var town_return_handoff: Dictionary = shell.call("validation_prepare_town_return_handoff")
	if not _assert_town_return_handoff_payload(town_return_handoff):
		get_tree().quit(1)
		return false
	shell.queue_free()
	await get_tree().process_frame
	if not await _assert_overworld_town_return_handoff(session, town_return_handoff):
		get_tree().quit(1)
		return false
	return true

func _assert_town_scenic_backdrop_contract(live_board: Node, session) -> bool:
	if not live_board.has_method("validation_scenic_backdrop_summary"):
		push_error("Town smoke: town stage does not expose scenic-backdrop validation.")
		return false
	var session_before: Dictionary = session.to_dict()
	var live_summary: Dictionary = live_board.call("validation_scenic_backdrop_summary")
	if String(live_summary.get("faction_id", "")) != "faction_embercourt" \
			or String(live_summary.get("mapped_path", "")) != String(TOWN_SCENIC_BACKDROP_PATHS.get("faction_embercourt", "")) \
			or not bool(live_summary.get("texture_loaded", false)) \
			or String(live_summary.get("rendering_mode", "")) != "cover_crop_scenic_backdrop" \
			or bool(live_summary.get("procedural_fallback", true)):
		push_error("Town smoke: live Riverwatch stage did not select the Embercourt scenic backdrop: %s." % live_summary)
		return false
	if not _scenic_backdrop_geometry_exact(live_summary):
		push_error("Town smoke: live scenic backdrop crop is outside the Town stage: %s." % live_summary)
		return false
	var expected_overlay_order := ["scenic_or_procedural_stage", "status_plaques", "district_strip", "command_markers", "header"]
	if Array(live_summary.get("overlay_order", [])) != expected_overlay_order:
		push_error("Town smoke: scenic layer no longer precedes every live Town overlay: %s." % live_summary)
		return false

	var fixture = TownStageViewScript.new()
	add_child(fixture)
	for stage_size in [Vector2(620.0, 320.0), Vector2(1180.0, 640.0)]:
		fixture.size = stage_size
		for faction_id_value in TOWN_SCENIC_BACKDROP_PATHS.keys():
			var faction_id := String(faction_id_value)
			fixture.set_precomputed_town_state(null, {
				"town": {"town_id": "validation_town", "built_buildings": [], "garrison": [], "available_recruits": {}},
				"town_template": {"id": "validation_town", "name": "Validation Town", "faction_id": faction_id},
				"faction": {"id": faction_id, "name": faction_id},
			})
			var summary: Dictionary = fixture.validation_scenic_backdrop_summary()
			if String(summary.get("faction_id", "")) != faction_id \
					or String(summary.get("mapped_path", "")) != String(TOWN_SCENIC_BACKDROP_PATHS.get(faction_id, "")) \
					or not bool(summary.get("texture_loaded", false)) \
					or summary.get("texture_size", Vector2.ZERO) != Vector2(1600.0, 900.0) \
					or String(summary.get("rendering_mode", "")) != "cover_crop_scenic_backdrop" \
					or bool(summary.get("procedural_fallback", true)) \
					or Array(summary.get("overlay_order", [])) != expected_overlay_order \
					or not _scenic_backdrop_geometry_exact(summary):
				push_error("Town smoke: %s scenic backdrop contract failed at %s: %s." % [faction_id, stage_size, summary])
				fixture.queue_free()
				return false

	fixture.set_precomputed_town_state(null, {
		"town": {"town_id": "validation_unknown", "built_buildings": [], "garrison": [], "available_recruits": {}},
		"town_template": {"id": "validation_unknown", "name": "Fallback Town", "faction_id": "faction_unmapped"},
		"faction": {"id": "faction_unmapped", "name": "Unmapped"},
	})
	var fallback_summary: Dictionary = fixture.validation_scenic_backdrop_summary()
	if String(fallback_summary.get("mapped_path", "")) != "" \
			or bool(fallback_summary.get("texture_loaded", true)) \
			or String(fallback_summary.get("rendering_mode", "")) != "procedural_geometry_fallback" \
			or not bool(fallback_summary.get("procedural_fallback", false)) \
			or Array(fallback_summary.get("overlay_order", [])) != expected_overlay_order:
		push_error("Town smoke: unmapped faction did not fail safely to the procedural stage: %s." % fallback_summary)
		fixture.queue_free()
		return false
	fixture.queue_free()
	await get_tree().process_frame
	if session.to_dict() != session_before:
		push_error("Town smoke: scenic-backdrop selection changed live session authority.")
		return false
	return true

func _scenic_backdrop_geometry_exact(summary: Dictionary) -> bool:
	var texture_size: Vector2 = summary.get("texture_size", Vector2.ZERO)
	var destination_rect: Rect2 = summary.get("destination_rect", Rect2())
	var source_rect: Rect2 = summary.get("source_rect", Rect2())
	if texture_size != Vector2(1600.0, 900.0) \
			or destination_rect.size.x <= 0.0 \
			or destination_rect.size.y <= 0.0 \
			or source_rect.size.x <= 0.0 \
			or source_rect.size.y <= 0.0 \
			or not bool(summary.get("source_within_texture", false)) \
			or not bool(summary.get("destination_contained", false)):
		return false
	return is_equal_approx(source_rect.size.x / source_rect.size.y, destination_rect.size.x / destination_rect.size.y)

func _assert_town_scenic_action_count_label_contract(live_board: Node, session) -> bool:
	if not live_board.has_method("validation_header_action_count_summary"):
		push_error("Town smoke: town stage does not expose scenic action-count label validation.")
		return false
	var session_before: Dictionary = session.to_dict()
	var expected_study_actions: Array = TownRules.get_spell_learning_actions(session)
	var expected_market_actions: Array = TownRules.get_market_actions(session)
	var original_window_size := get_window().size
	for viewport_size in [Vector2i(1280, 720), Vector2i(1920, 1080)]:
		get_window().size = viewport_size
		await get_tree().process_frame
		await get_tree().process_frame
		var live_summary: Dictionary = live_board.call("validation_header_action_count_summary")
		var expected_live_text := "Garrison %d companies | %d troops | Study options %d | Market options %d" % [
			int(live_summary.get("garrison_company_count", -1)),
			int(live_summary.get("garrison_headcount", -1)),
			expected_study_actions.size(),
			expected_market_actions.size(),
		]
		if get_window().size != viewport_size \
				or int(live_summary.get("study_action_count", -1)) != expected_study_actions.size() \
				or int(live_summary.get("market_action_count", -1)) != expected_market_actions.size() \
				or String(live_summary.get("full_text", "")) != expected_live_text \
				or String(live_summary.get("rendered_text", "")) != expected_live_text \
				or String(live_summary.get("full_text", "")).contains(" | Study %d |" % expected_study_actions.size()) \
				or String(live_summary.get("full_text", "")).ends_with(" | Market %d" % expected_market_actions.size()):
			push_error("Town smoke: live scenic action counts are not explicitly labeled and untruncated at %s: %s." % [viewport_size, live_summary])
			return false
	get_window().size = original_window_size
	await get_tree().process_frame
	await get_tree().process_frame

	var fixture := TownStageViewScript.new()
	fixture.size = Vector2(1180.0, 640.0)
	add_child(fixture)
	var fixture_study_actions := [{"id": "study_a"}, {"id": "study_b"}]
	var fixture_market_actions := [{"id": "market_a"}]
	fixture.set_precomputed_town_state(null, {
		"town": {"town_id": "validation_town", "built_buildings": [], "garrison": [], "available_recruits": {}},
		"town_template": {"id": "validation_town", "name": "Validation Town", "faction_id": "faction_embercourt"},
		"faction": {"id": "faction_embercourt", "name": "Embercourt League"},
		"study_actions": fixture_study_actions,
		"market_actions": fixture_market_actions,
	})
	fixture_study_actions.clear()
	fixture_market_actions.append({"id": "market_b"})
	var detached_summary: Dictionary = fixture.validation_header_action_count_summary()
	if detached_summary != {
		"full_text": "Garrison 0 companies | 0 troops | Study options 2 | Market options 1",
		"rendered_text": "Garrison 0 companies | 0 troops | Study options 2 | Market options 1",
		"study_action_count": 2,
		"market_action_count": 1,
		"garrison_company_count": 0,
		"garrison_headcount": 0,
		"max_chars": 80,
	}:
		push_error("Town smoke: precomputed scenic action counts were not detached and explicit: %s." % detached_summary)
		fixture.queue_free()
		return false
	fixture.set_precomputed_town_state(null, {
		"town": {"town_id": "validation_town", "built_buildings": [], "garrison": [], "available_recruits": {}},
		"town_template": {"id": "validation_town", "name": "Validation Town", "faction_id": "faction_embercourt"},
		"faction": {"id": "faction_embercourt", "name": "Embercourt League"},
		"study_actions": [{"id": "study_c"}],
		"market_actions": [{"id": "market_c"}, {"id": "market_d"}],
	})
	var refreshed_summary: Dictionary = fixture.validation_header_action_count_summary()
	if String(refreshed_summary.get("full_text", "")) != "Garrison 0 companies | 0 troops | Study options 1 | Market options 2" \
			or int(refreshed_summary.get("study_action_count", -1)) != 1 \
			or int(refreshed_summary.get("market_action_count", -1)) != 2:
		push_error("Town smoke: refreshed scenic action counts did not follow precomputed stage state: %s." % refreshed_summary)
		fixture.queue_free()
		return false
	fixture.queue_free()
	await get_tree().process_frame
	if session.to_dict() != session_before:
		push_error("Town smoke: scenic action-count label validation changed live session authority.")
		return false
	return true

func _assert_town_header_control_label_contract(shell: Control, live_session) -> bool:
	var header := shell.get_node_or_null("%Header") as Label
	if header == null:
		push_error("Town smoke: Town header label is unavailable.")
		return false
	var live_header := TownRules.describe_header(live_session)
	if header.text != live_header \
			or header.tooltip_text != live_header \
			or not live_header.contains(" | Your Control | ") \
			or live_header.contains("Owner Player") \
			or not shell.get_global_rect().encloses(header.get_global_rect()):
		push_error("Town smoke: live Town header did not expose exact contained player-facing control copy: %s." % live_header)
		return false
	var font := header.get_theme_font("font")
	var font_size := header.get_theme_font_size("font_size")
	if font == null or font.get_string_size(live_header, HORIZONTAL_ALIGNMENT_LEFT, -1.0, font_size).x > header.size.x + 0.5:
		push_error("Town smoke: live Town header does not fit its themed label: %s / %s." % [live_header, header.size])
		return false

	var fixture_session = ScenarioFactory.create_session(
		"river-pass",
		"normal",
		SessionState.LAUNCH_MODE_SKIRMISH
	)
	var fixture_town := _first_player_town(fixture_session)
	if fixture_town.is_empty():
		push_error("Town smoke: Town header fixture could not find Riverwatch.")
		return false
	_move_active_hero_to_town(fixture_session, fixture_town)
	var expected_spell_tier := TownRules.current_spell_tier(fixture_town)
	var expected_labels := {
		"player": "Your Control",
		"enemy": "Enemy Control",
		"neutral": "Neutral Control",
		"unsupported_internal_owner": "Unknown Control",
	}
	for owner_value in expected_labels:
		fixture_town["owner"] = owner_value
		var authority_before: Dictionary = fixture_session.to_dict()
		var header_text := TownRules.describe_header(fixture_session)
		var expected_label := String(expected_labels[owner_value])
		if fixture_session.to_dict() != authority_before \
				or not header_text.contains(" | %s | " % expected_label) \
				or header_text.contains("Owner ") \
				or header_text.contains(owner_value) \
				or not header_text.begins_with("Riverwatch Hold | Embercourt League | Frontier Stronghold | ") \
				or not header_text.ends_with(" | Spell Tier %d" % expected_spell_tier):
			push_error("Town smoke: owner %s did not produce exact player-facing header copy: %s." % [owner_value, header_text])
			return false
	return true

func _assert_town_capture_frontier_status_contract(live_board: Node, live_session) -> bool:
	if not live_board.has_method("validation_status_plaques_summary"):
		push_error("Town smoke: town stage does not expose status-plaque validation.")
		return false
	var live_session_before: Dictionary = live_session.to_dict()
	var live_town := _first_player_town(live_session)
	var live_summary: Dictionary = live_board.call("validation_status_plaques_summary")
	var live_pressure := OverworldRules.town_pressure_output(live_town, live_session)
	if not _front_plaque_exact(live_summary, "pressure", "Front", "%d pressure" % live_pressure, 0, ""):
		push_error("Town smoke: ordinary live town lost its exact Front pressure plaque: %s." % live_summary)
		return false

	var fixture_session = ScenarioFactory.create_session(
		"river-pass",
		"normal",
		SessionState.LAUNCH_MODE_SKIRMISH
	)
	var fixture_town := _first_player_town(fixture_session)
	if fixture_town.is_empty():
		push_error("Town smoke: captured-town status fixture could not find Riverwatch.")
		return false
	_move_active_hero_to_town(fixture_session, fixture_town)
	var fixture_authority_before: Dictionary = fixture_session.to_dict()
	var fixture = TownStageViewScript.new()
	add_child(fixture)
	fixture.size = Vector2(620.0, 320.0)
	await get_tree().process_frame

	fixture_town["occupation"] = {
		"state": "pacifying",
		"faction_id": "faction_mireclaw",
		"pressure": 7,
		"initial_pressure": 7,
		"start_day": int(fixture_session.day),
		"last_event_day": int(fixture_session.day),
		"last_owner": "enemy",
		"source": "town_assault",
		"locked_recruits": {},
	}
	fixture_town["front"] = {}
	fixture.set_town_state(fixture_session)
	var occupation_only: Dictionary = fixture.validation_status_plaques_summary()
	var expected_occupation_only: Dictionary = OverworldRules.town_occupation_state(fixture_session, fixture_town)
	if not _front_plaque_exact(
		occupation_only,
		"occupation",
		"Occupation",
		"%dd pacify" % int(expected_occupation_only.get("days_to_clear", 0)),
		int(expected_occupation_only.get("days_to_clear", 0)),
		""
	):
		push_error("Town smoke: occupation-only status plaque is not exact: %s." % occupation_only)
		fixture.queue_free()
		return false

	fixture_town["occupation"] = {}
	fixture_town["front"] = {
		"state": "retake",
		"faction_id": "faction_mireclaw",
		"last_change_day": int(fixture_session.day),
		"last_owner": "enemy",
		"capture_count": 1,
		"source": "town_assault",
	}
	fixture.set_town_state(fixture_session)
	var retake_only: Dictionary = fixture.validation_status_plaques_summary()
	var expected_retake_only: Dictionary = OverworldRules.town_front_state(fixture_session, fixture_town)
	if not _front_plaque_exact(
		retake_only,
		"retake",
		"Retake",
		"Mireclaw +%d" % int(expected_retake_only.get("pressure_bonus", 0)),
		0,
		"faction_mireclaw"
	):
		push_error("Town smoke: retake-only status plaque is not exact: %s." % retake_only)
		fixture.queue_free()
		return false

	fixture_town["occupation"] = {
		"state": "pacifying",
		"faction_id": "faction_mireclaw",
		"pressure": 7,
		"initial_pressure": 7,
		"start_day": int(fixture_session.day),
		"last_event_day": int(fixture_session.day),
		"last_owner": "enemy",
		"source": "town_assault",
		"locked_recruits": {},
	}
	var expected_combined_occupation: Dictionary = OverworldRules.town_occupation_state(fixture_session, fixture_town)
	var expected_combined_front: Dictionary = OverworldRules.town_front_state(fixture_session, fixture_town)
	var expected_captured_study_actions: Array = TownRules.get_spell_learning_actions(fixture_session)
	var expected_captured_market_actions: Array = TownRules.get_market_actions(fixture_session)
	for stage_size in [Vector2(620.0, 320.0), Vector2(1180.0, 640.0)]:
		fixture.size = stage_size
		fixture.set_town_state(fixture_session)
		var combined: Dictionary = fixture.validation_status_plaques_summary()
		var captured_label: Dictionary = fixture.validation_header_action_count_summary()
		var expected_captured_label := "Garrison %d companies | %d troops | Study options %d | Market options %d" % [
			int(captured_label.get("garrison_company_count", -1)),
			int(captured_label.get("garrison_headcount", -1)),
			expected_captured_study_actions.size(),
			expected_captured_market_actions.size(),
		]
		if not _front_plaque_exact(
			combined,
			"occupation_retake",
			"Occupation",
			"%dd | Retake" % int(expected_combined_occupation.get("days_to_clear", 0)),
			int(expected_combined_occupation.get("days_to_clear", 0)),
			"faction_mireclaw"
		) or int(combined.get("plaque_count", 0)) != 4 or not bool(combined.get("contained", false)):
			push_error("Town smoke: combined captured-town plaque is not exact or contained at %s: %s." % [stage_size, combined])
			fixture.queue_free()
			return false
		if int(captured_label.get("study_action_count", -1)) != expected_captured_study_actions.size() \
				or int(captured_label.get("market_action_count", -1)) != expected_captured_market_actions.size() \
				or String(captured_label.get("full_text", "")) != expected_captured_label:
			push_error("Town smoke: captured-town scenic action counts lost exact explicit labels at %s: %s." % [stage_size, captured_label])
			fixture.queue_free()
			return false
		if combined.get("occupation", {}) != expected_combined_occupation or combined.get("front", {}) != expected_combined_front:
			push_error("Town smoke: captured-town stage did not retain exact detached public rule state: %s." % combined)
			fixture.queue_free()
			return false

	var detached_combined: Dictionary = fixture.validation_status_plaques_summary()
	var fresh_combined: Dictionary = detached_combined.duplicate(true)
	var fixture_authority_before_detach: Dictionary = fixture_session.to_dict()
	detached_combined["occupation"]["days_to_clear"] = 999
	detached_combined["front"]["faction_id"] = "faction_invalid"
	if fixture_authority_before_detach == fixture_authority_before:
		push_error("Town smoke: captured-town fixture did not establish its intended occupation/front authority.")
		fixture.queue_free()
		return false
	if fixture_session.to_dict() != fixture_authority_before_detach \
			or fixture.validation_status_plaques_summary() != fresh_combined:
		push_error("Town smoke: detached plaque validation mutated the live stage or session authority.")
		fixture.queue_free()
		return false

	fixture_session.day += 1
	fixture_town["occupation"]["pressure"] = 5
	fixture.set_town_state(fixture_session)
	var advanced_occupation: Dictionary = OverworldRules.town_occupation_state(fixture_session, fixture_town)
	var advanced_summary: Dictionary = fixture.validation_status_plaques_summary()
	if not _front_plaque_exact(
		advanced_summary,
		"occupation_retake",
		"Occupation",
		"%dd | Retake" % int(advanced_occupation.get("days_to_clear", 0)),
		int(advanced_occupation.get("days_to_clear", 0)),
		"faction_mireclaw"
	):
		push_error("Town smoke: day/pressure refresh did not rebuild the captured-town plaque: %s." % advanced_summary)
		fixture.queue_free()
		return false

	fixture.set_precomputed_town_state(fixture_session, {
		"town": fixture_town.duplicate(true),
		"town_template": ContentService.get_town(String(fixture_town.get("town_id", ""))).duplicate(true),
		"faction": ContentService.get_faction("faction_embercourt").duplicate(true),
		"logistics": OverworldRules.town_logistics_state(fixture_session, fixture_town).duplicate(true),
		"recovery": OverworldRules.town_recovery_state(fixture_session, fixture_town).duplicate(true),
		"threat": OverworldRules.town_public_threat_state(fixture_session, fixture_town).duplicate(true),
		"occupation": advanced_occupation.duplicate(true),
		"front": OverworldRules.town_front_state(fixture_session, fixture_town).duplicate(true),
	})
	if fixture.validation_status_plaques_summary() != advanced_summary:
		push_error("Town smoke: precomputed and direct captured-town stage paths diverged.")
		fixture.queue_free()
		return false

	fixture.queue_free()
	await get_tree().process_frame
	if live_session.to_dict() != live_session_before:
		push_error("Town smoke: captured-town plaque validation changed the live Town session.")
		return false
	return true

func _front_plaque_exact(
	summary: Dictionary,
	expected_kind: String,
	expected_title: String,
	expected_value: String,
	expected_days: int,
	expected_faction_id: String
) -> bool:
	var plaques: Array = summary.get("plaques", []) if summary.get("plaques", []) is Array else []
	var plaque: Dictionary = summary.get("front_plaque", {}) if summary.get("front_plaque", {}) is Dictionary else {}
	return plaques.size() == 4 \
		and plaque == plaques[2] \
		and String(plaque.get("kind", "")) == expected_kind \
		and String(plaque.get("title", "")) == expected_title \
		and String(plaque.get("value", "")) == expected_value \
		and int(plaque.get("occupation_days_to_clear", 0)) == expected_days \
		and String(plaque.get("retake_faction_id", "")) == expected_faction_id

func _run_battle_smoke() -> bool:
	var session = ScenarioFactory.create_session(
		"river-pass",
		"normal",
		SessionState.LAUNCH_MODE_SKIRMISH
	)
	var encounter = _first_encounter(session)
	if encounter.is_empty():
		push_error("Battle smoke: could not find an encounter in the sample scenario.")
		get_tree().quit(1)
		return false
	session.battle = BattleRules.create_battle_payload(session, encounter)
	SessionState.set_active_session(session)

	var shell = load("res://scenes/battle/BattleShell.tscn").instantiate()
	add_child(shell)
	await get_tree().process_frame
	await get_tree().process_frame

	var board = shell.get_node_or_null("%BattleBoard")
	if board == null:
		push_error("Battle smoke: battle board did not load.")
		get_tree().quit(1)
		return false
	if not board.has_method("validation_color_cue_summary"):
		push_error("Battle smoke: battle board does not expose color-cue validation.")
		get_tree().quit(1)
		return false
	var battle_color_cues: Dictionary = board.call("validation_color_cue_summary")
	if not bool(battle_color_cues.get("assisted", false)) or String(battle_color_cues.get("player_side_mark", "")) != "circle_P" or String(battle_color_cues.get("enemy_side_mark", "")) != "triangle_E" or not bool(battle_color_cues.get("side_marks_drawn_with_stack_tokens", false)) or not bool(battle_color_cues.get("board_tooltip_uses_color_independent_move_wording", false)):
		push_error("Battle smoke: assisted battle ownership cues are incomplete: %s." % battle_color_cues)
		get_tree().quit(1)
		return false
	var battle_player_color: Color = battle_color_cues.get("player_color", Color.RED)
	var battle_enemy_color: Color = battle_color_cues.get("enemy_color", Color.GREEN)
	if battle_player_color.b <= battle_player_color.r or battle_enemy_color.r <= battle_enemy_color.b:
		push_error("Battle smoke: assisted player/enemy palette is not blue/orange separated: %s." % battle_color_cues)
		get_tree().quit(1)
		return false
	if not await _capture_color_cue_frame("battle_color_cues"):
		get_tree().quit(1)
		return false
	if not _assert_battle_entry_context(shell):
		get_tree().quit(1)
		return false
	if not _assert_battle_stack_inspection_contract(shell):
		get_tree().quit(1)
		return false
	if not _assert_battle_magic_inspection_contract(shell):
		get_tree().quit(1)
		return false
	if not _assert_battle_status_check_cue_contract(shell):
		get_tree().quit(1)
		return false
	if not _assert_battle_risk_check_cue_contract(shell):
		get_tree().quit(1)
		return false
	if not _assert_battle_timing_check_cue_contract(shell):
		get_tree().quit(1)
		return false
	if not board.has_method("validation_hex_layout_summary"):
		push_error("Battle smoke: battle board does not expose hex layout validation.")
		get_tree().quit(1)
		return false
	if not board.has_method("validation_terrain_rendering_summary"):
		push_error("Battle smoke: battle board does not expose terrain rendering validation.")
		get_tree().quit(1)
		return false
	var hex_summary: Dictionary = board.call("validation_hex_layout_summary")
	if String(hex_summary.get("presentation", "")) != "hex":
		push_error("Battle smoke: battle board did not render through the hex-field presentation.")
		get_tree().quit(1)
		return false
	if not bool(hex_summary.get("terrain_texture_loaded", false)):
		push_error("Battle smoke: terrain texture was not loaded for the active battlefield: %s." % hex_summary)
		get_tree().quit(1)
		return false
	if not bool(hex_summary.get("terrain_hex_snapped", false)) or bool(hex_summary.get("terrain_single_board_backdrop", true)):
		push_error("Battle smoke: terrain texture rendering is not snapped to the hex grid: %s." % hex_summary)
		get_tree().quit(1)
		return false
	var terrain_summary: Dictionary = board.call("validation_terrain_rendering_summary")
	if not bool(terrain_summary.get("texture_loaded", false)) or float(terrain_summary.get("texture_width", 0.0)) <= 0.0 or float(terrain_summary.get("texture_height", 0.0)) <= 0.0:
		push_error("Battle smoke: terrain rendering validation did not report a usable runtime texture: %s." % terrain_summary)
		get_tree().quit(1)
		return false
	if String(terrain_summary.get("rendering_mode", "")) != "hex_snapped_texture" or not bool(terrain_summary.get("hex_snapped", false)) or bool(terrain_summary.get("single_board_backdrop", true)):
		push_error("Battle smoke: terrain texture is not using the hex-snapped rendering path: %s." % terrain_summary)
		get_tree().quit(1)
		return false
	if not bool(terrain_summary.get("texture_visible", false)) or bool(terrain_summary.get("grid_repaints_texture_cells", true)):
		push_error("Battle smoke: terrain texture visibility is still being buried by the tactical grid pass: %s." % terrain_summary)
		get_tree().quit(1)
		return false
	if String(terrain_summary.get("grid_fill_mode", "")) != "texture_transparent_tactical_tint" or float(terrain_summary.get("grid_max_fill_alpha", 1.0)) > 0.05:
		push_error("Battle smoke: textured battlefield grid fills are too opaque for the terrain art: %s." % terrain_summary)
		get_tree().quit(1)
		return false
	if String(terrain_summary.get("grid_border_mode", "")) != "deduplicated_texture_grid" or not bool(terrain_summary.get("grid_border_deduplicated", false)):
		push_error("Battle smoke: textured battlefield grid borders are not using the cleaned single-border path: %s." % terrain_summary)
		get_tree().quit(1)
		return false
	if int(terrain_summary.get("hex_tile_count", 0)) != int(hex_summary.get("hex_count", -1)):
		push_error("Battle smoke: terrain texture tile count does not match the tactical hex count: terrain=%s hex=%s." % [terrain_summary, hex_summary])
		get_tree().quit(1)
		return false
	if float(terrain_summary.get("source_tile_width", 0.0)) <= 0.0 or float(terrain_summary.get("source_tile_height", 0.0)) <= 0.0:
		push_error("Battle smoke: terrain texture did not expose a usable per-hex source sample size: %s." % terrain_summary)
		get_tree().quit(1)
		return false
	if String(terrain_summary.get("texture_uv_space", "")) != "normalized_0_1" or not bool(terrain_summary.get("texture_uv_within_0_1", false)):
		push_error("Battle smoke: terrain texture UV sampling is not normalized for draw_polygon: %s." % terrain_summary)
		get_tree().quit(1)
		return false
	if not bool(terrain_summary.get("texture_source_within_texture", false)) or int(terrain_summary.get("texture_source_sample_count", 0)) != int(hex_summary.get("hex_count", -1)):
		push_error("Battle smoke: terrain texture source samples do not stay inside the runtime texture: terrain=%s hex=%s." % [terrain_summary, hex_summary])
		get_tree().quit(1)
		return false
	if float(terrain_summary.get("texture_uv_min_x", -1.0)) < 0.0 or float(terrain_summary.get("texture_uv_min_y", -1.0)) < 0.0 or float(terrain_summary.get("texture_uv_max_x", 2.0)) > 1.0 or float(terrain_summary.get("texture_uv_max_y", 2.0)) > 1.0:
		push_error("Battle smoke: terrain texture normalized UV range is outside 0..1: %s." % terrain_summary)
		get_tree().quit(1)
		return false
	var original_terrain := String(session.battle.get("terrain", ""))
	session.battle["terrain"] = "plains"
	board.call("set_battle_state", session)
	await get_tree().process_frame
	var plains_summary: Dictionary = board.call("validation_terrain_rendering_summary")
	if String(plains_summary.get("texture_id", "")) != "grass" or not bool(plains_summary.get("texture_loaded", false)) or not bool(plains_summary.get("mapped", false)) or String(plains_summary.get("rendering_mode", "")) != "hex_snapped_texture":
		push_error("Battle smoke: plains terrain did not map cleanly to the grass battlefield texture: %s." % plains_summary)
		get_tree().quit(1)
		return false
	session.battle["terrain"] = "validation_missing_texture"
	board.call("set_battle_state", session)
	await get_tree().process_frame
	var missing_summary: Dictionary = board.call("validation_terrain_rendering_summary")
	if bool(missing_summary.get("texture_loaded", true)) or not bool(missing_summary.get("fallback", false)) or String(missing_summary.get("rendering_mode", "")) != "hex_snapped_color_fallback" or not bool(missing_summary.get("hex_snapped", false)) or bool(missing_summary.get("single_board_backdrop", true)):
		push_error("Battle smoke: missing terrain texture did not fall back to hex-snapped color/detail rendering: %s." % missing_summary)
		get_tree().quit(1)
		return false
	if String(missing_summary.get("grid_fill_mode", "")) != "fallback_readability_fill" or float(missing_summary.get("grid_max_fill_alpha", 0.0)) <= 0.10:
		push_error("Battle smoke: missing terrain texture fallback lost its readable tactical grid fills: %s." % missing_summary)
		get_tree().quit(1)
		return false
	session.battle["terrain"] = original_terrain
	board.call("set_battle_state", session)
	await get_tree().process_frame
	if int(hex_summary.get("hex_count", 0)) < 70:
		push_error("Battle smoke: hex battlefield is too small to be a proper tactical surface: %s." % hex_summary)
		get_tree().quit(1)
		return false
	if int(hex_summary.get("player_stack_count", 0)) <= 0 or int(hex_summary.get("enemy_stack_count", 0)) <= 0:
		push_error("Battle smoke: both armies must have on-field stacks in the hex presentation: %s." % hex_summary)
		get_tree().quit(1)
		return false
	var expected_stack_count := int(hex_summary.get("player_stack_count", 0)) + int(hex_summary.get("enemy_stack_count", 0))
	var occupied_hexes: Dictionary = hex_summary.get("occupied_hexes", {})
	if occupied_hexes.size() != expected_stack_count:
		push_error("Battle smoke: occupied hex map did not match the on-field stacks: %s." % hex_summary)
		get_tree().quit(1)
		return false

	var recent_before: int = int(session.battle.get("recent_events", []).size())
	var active_stack := BattleRules.get_active_stack(session.battle)
	if not active_stack.is_empty() and String(active_stack.get("side", "")) != "player":
		var guard := 0
		while String(BattleRules.get_active_stack(session.battle).get("side", "")) != "player" and guard < 8:
			BattleRules.advance_turn(session.battle)
			guard += 1
		shell._refresh()
		await get_tree().process_frame
	if not _assert_battle_ability_status_action_consequence_contract(shell):
		get_tree().quit(1)
		return false
	if not _assert_battle_stack_check_cue_contract(shell):
		get_tree().quit(1)
		return false
	if not _assert_battle_position_check_cue_contract(shell):
		get_tree().quit(1)
		return false
	if not _assert_battle_engagement_check_cue_contract(shell):
		get_tree().quit(1)
		return false
	if not _assert_battle_objective_check_cue_contract(shell):
		get_tree().quit(1)
		return false
	if not _assert_battle_exit_order_cue_contract(shell):
		get_tree().quit(1)
		return false
	if not _assert_battle_target_cycle_cue_contract(shell):
		get_tree().quit(1)
		return false
	if not _assert_battle_initiative_handoff_cue_contract(shell):
		get_tree().quit(1)
		return false
	if not _assert_battle_command_tab_readiness_cues(shell):
		get_tree().quit(1)
		return false
	if not _assert_battle_save_handoff_cue(shell):
		get_tree().quit(1)
		return false
	if not _assert_active_return_handoff_contract(shell, "Battle", "Menu: Battle"):
		get_tree().quit(1)
		return false

	var defend_button = shell.get_node_or_null("%Defend")
	if defend_button == null:
		push_error("Battle smoke: defend action button did not load.")
		get_tree().quit(1)
		return false
	var post_action_response := {}
	if not defend_button.disabled:
		post_action_response = shell.call("validation_perform_action", "defend")
		await get_tree().process_frame
		if not _assert_battle_post_action_status_recap_contract(shell, post_action_response):
			get_tree().quit(1)
			return false

	var recent_after: int = int(session.battle.get("recent_events", []).size())
	if recent_after < recent_before:
		push_error("Battle smoke: recent event feed regressed after action refresh.")
		get_tree().quit(1)
		return false

	shell.queue_free()
	await get_tree().process_frame
	if not await _assert_battle_aftermath_transition(session):
		get_tree().quit(1)
		return false
	return true

func _assert_active_return_handoff_contract(shell: Node, expected_target: String, expected_button_label: String) -> bool:
	if not shell.has_method("validation_snapshot"):
		push_error("%s smoke: shell does not expose return handoff validation snapshot." % expected_target)
		return false
	var snapshot: Dictionary = shell.call("validation_snapshot")
	var save_surface: Dictionary = snapshot.get("save_surface", {}) if snapshot.get("save_surface", {}) is Dictionary else {}
	var handoff_text := "\n".join([
		String(save_surface.get("return_handoff", "")),
		String(save_surface.get("menu_button_label", "")),
		String(save_surface.get("menu_button_tooltip", "")),
		String(snapshot.get("save_status_visible_text", "")),
		String(snapshot.get("save_status_tooltip_text", "")),
	])
	for token in ["Return handoff:", "Continue Latest returns", expected_target, "preserved", expected_button_label]:
		if not handoff_text.contains(token):
			push_error("%s smoke: active return handoff lost %s clarity: %s." % [expected_target, token, handoff_text])
			return false
	for leak_token in ["final_priority", "base_value", "assignment_penalty", "final_score", "income_value", "growth_value", "pressure_value", "category_bonus", "raid_score", "debug_reason", "raid_target_weights", "ai_score", "weight"]:
		if handoff_text.contains(leak_token):
			push_error("%s smoke: active return handoff leaked internal token %s: %s." % [expected_target, leak_token, handoff_text])
			return false
	return true

func _assert_town_save_handoff_cue(shell: Node) -> bool:
	if not shell.has_method("validation_snapshot"):
		push_error("Town smoke: shell does not expose save-handoff validation snapshot.")
		return false
	var snapshot: Dictionary = shell.call("validation_snapshot")
	var save_surface: Dictionary = snapshot.get("save_surface", {}) if snapshot.get("save_surface", {}) is Dictionary else {}
	var handoff_text := "\n".join([
		String(save_surface.get("save_handoff", "")),
		String(save_surface.get("save_handoff_brief", "")),
		String(snapshot.get("save_handoff_visible_text", "")),
		String(snapshot.get("save_button_text", "")),
		String(snapshot.get("save_button_tooltip_text", "")),
		String(snapshot.get("save_status_tooltip_text", "")),
	])
	for token in ["Save handoff:", "Manual", "Town Resume", "Load Selected", "reopens", "preserved", "Save Town"]:
		if not handoff_text.contains(token):
			push_error("Town smoke: save handoff cue lost %s clarity: %s." % [token, handoff_text])
			return false
	if not bool(snapshot.get("save_handoff_visible", false)):
		push_error("Town smoke: save handoff cue is not visible in the town footer: %s." % handoff_text)
		return false
	for leak_token in ["build_category_weights", "final_priority", "base_value", "assignment_penalty", "final_score", "income_value", "growth_value", "pressure_value", "category_bonus", "raid_score", "debug_reason", "raid_target_weights", "ai_score", "weight"]:
		if handoff_text.contains(leak_token):
			push_error("Town smoke: save handoff cue leaked internal token %s: %s." % [leak_token, handoff_text])
			return false
	return true

func _assert_battle_save_handoff_cue(shell: Node) -> bool:
	if not shell.has_method("validation_snapshot"):
		push_error("Battle smoke: shell does not expose save-handoff validation snapshot.")
		return false
	var snapshot: Dictionary = shell.call("validation_snapshot")
	var save_surface: Dictionary = snapshot.get("save_surface", {}) if snapshot.get("save_surface", {}) is Dictionary else {}
	var handoff_text := "\n".join([
		String(save_surface.get("save_handoff", "")),
		String(save_surface.get("save_handoff_brief", "")),
		String(snapshot.get("save_handoff_visible_text", "")),
		String(snapshot.get("save_button_text", "")),
		String(snapshot.get("save_button_tooltip_text", "")),
		String(snapshot.get("save_status_tooltip_text", "")),
	])
	for token in ["Save handoff:", "Manual", "Battle Resume", "Load Selected", "reopens", "preserved", "Save Battle"]:
		if not handoff_text.contains(token):
			push_error("Battle smoke: save handoff cue lost %s clarity: %s." % [token, handoff_text])
			return false
	if not bool(snapshot.get("save_handoff_visible", false)) or not String(snapshot.get("save_handoff_visible_text", "")).contains("Save handoff:"):
		push_error("Battle smoke: save handoff cue is not visible in the battle footer: %s." % handoff_text)
		return false
	for leak_token in ["final_priority", "base_value", "assignment_penalty", "final_score", "income_value", "growth_value", "pressure_value", "category_bonus", "raid_score", "debug_reason", "raid_target_weights", "ai_score", "weight"]:
		if handoff_text.contains(leak_token):
			push_error("Battle smoke: save handoff cue leaked internal token %s: %s." % [leak_token, handoff_text])
			return false
	return true

func _assert_town_command_tab_readiness_cues(shell: Node) -> bool:
	if not shell.has_method("validation_snapshot"):
		push_error("Town smoke: shell does not expose command-tab readiness validation snapshot.")
		return false
	var snapshot: Dictionary = shell.call("validation_snapshot")
	var readiness: Dictionary = snapshot.get("town_tab_readiness", {}) if snapshot.get("town_tab_readiness", {}) is Dictionary else {}
	var titles: Array = snapshot.get("town_tab_titles", []) if snapshot.get("town_tab_titles", []) is Array else []
	var tabs: Array = readiness.get("tabs", []) if readiness.get("tabs", []) is Array else []
	var cue_text := "\n".join([
		" ".join(titles),
		String(snapshot.get("town_tab_readiness_tooltip_text", "")),
		JSON.stringify(readiness),
	])
	for token in ["Build", "Muster", "Spells", "Trade", "Log", "Town command tabs:", "Selected:"]:
		if not cue_text.contains(token):
			push_error("Town smoke: command-tab readiness cue lost %s clarity: %s." % [token, cue_text])
			return false
	if tabs.size() != 5:
		push_error("Town smoke: command-tab readiness payload should cover five town tabs: %s." % readiness)
		return false
	var ready_title_found := false
	for tab in tabs:
		if tab is Dictionary and int(tab.get("ready_count", 0)) > 0 and String(tab.get("title", "")).contains(str(int(tab.get("ready_count", 0)))):
			ready_title_found = true
			break
	if not ready_title_found:
		push_error("Town smoke: no actionable tab exposed a visible ready count: titles=%s readiness=%s." % [titles, readiness])
		return false
	for leak_token in ["build_category_weights", "final_priority", "base_value", "assignment_penalty", "final_score", "income_value", "growth_value", "pressure_value", "category_bonus", "raid_score", "debug_reason", "raid_target_weights", "ai_score", "weight"]:
		if cue_text.contains(leak_token):
			push_error("Town smoke: command-tab readiness cue leaked internal token %s: %s." % [leak_token, cue_text])
			return false
	return true

func _assert_battle_command_tab_readiness_cues(shell: Node) -> bool:
	if not shell.has_method("validation_snapshot"):
		push_error("Battle smoke: shell does not expose command-tab readiness validation snapshot.")
		return false
	var snapshot: Dictionary = shell.call("validation_snapshot")
	var readiness: Dictionary = snapshot.get("battle_tab_readiness", {}) if snapshot.get("battle_tab_readiness", {}) is Dictionary else {}
	var titles: Array = snapshot.get("battle_tab_titles", []) if snapshot.get("battle_tab_titles", []) is Array else []
	var tabs: Array = readiness.get("tabs", []) if readiness.get("tabs", []) is Array else []
	var cue_text := "\n".join([
		" ".join(titles),
		String(snapshot.get("battle_tab_readiness_tooltip_text", "")),
		JSON.stringify(readiness),
	])
	for token in ["Order", "Focus", "Spells", "Timing", "Battle command tabs:", "Selected:"]:
		if not cue_text.contains(token):
			push_error("Battle smoke: command-tab readiness cue lost %s clarity: %s." % [token, cue_text])
			return false
	if tabs.size() != 4:
		push_error("Battle smoke: command-tab readiness payload should cover four battle tabs: %s." % readiness)
		return false
	var ready_title_found := false
	for tab in tabs:
		if tab is Dictionary and int(tab.get("ready_count", 0)) > 0 and String(tab.get("title", "")).contains(str(int(tab.get("ready_count", 0)))):
			ready_title_found = true
			break
	if not ready_title_found:
		push_error("Battle smoke: no actionable tab exposed a visible ready count: titles=%s readiness=%s." % [titles, readiness])
		return false
	for leak_token in ["final_priority", "base_value", "assignment_penalty", "final_score", "income_value", "growth_value", "pressure_value", "category_bonus", "raid_score", "debug_reason", "raid_target_weights", "ai_score", "weight"]:
		if cue_text.contains(leak_token):
			push_error("Battle smoke: command-tab readiness cue leaked internal token %s: %s." % [leak_token, cue_text])
			return false
	return true

func _assert_town_action_button_command_cues(shell: Node) -> bool:
	if not shell.has_method("validation_snapshot"):
		push_error("Town smoke: shell does not expose action-button command cue validation snapshot.")
		return false
	var snapshot: Dictionary = shell.call("validation_snapshot")
	var tooltip_payload: Dictionary = snapshot.get("town_action_button_tooltips", {}) if snapshot.get("town_action_button_tooltips", {}) is Dictionary else {}
	var all_text_lines := []
	var lanes_with_cues := []
	for lane in tooltip_payload.keys():
		var entries: Array = tooltip_payload.get(lane, []) if tooltip_payload.get(lane, []) is Array else []
		for entry in entries:
			if not (entry is Dictionary):
				continue
			var tooltip := String(entry.get("tooltip", ""))
			all_text_lines.append("%s %s %s" % [
				String(lane),
				String(entry.get("text", "")),
				tooltip,
			])
			if tooltip.contains("Command cue:") and tooltip.contains("Next:"):
				lanes_with_cues.append(String(lane))
	var all_text := "\n".join(all_text_lines)
	for token in ["Command cue:", "Next:", "Build tab", "Muster tab"]:
		if not all_text.contains(token):
			push_error("Town smoke: action-button command cues lost %s clarity: %s." % [token, all_text])
			return false
	if not lanes_with_cues.has("build") or not lanes_with_cues.has("recruit"):
		push_error("Town smoke: build and recruit buttons should expose command cues: lanes=%s payload=%s." % [lanes_with_cues, tooltip_payload])
		return false
	if all_text.find("Ready") < 0 and all_text.find("Blocked") < 0 and all_text.find("Needs exchange") < 0:
		push_error("Town smoke: action-button command cues do not expose readiness state: %s." % all_text)
		return false
	for leak_token in ["build_category_weights", "final_priority", "base_value", "assignment_penalty", "final_score", "income_value", "growth_value", "pressure_value", "category_bonus", "raid_score", "debug_reason", "raid_target_weights", "ai_score", "weight"]:
		if all_text.contains(leak_token):
			push_error("Town smoke: action-button command cue leaked internal token %s: %s." % [leak_token, all_text])
			return false
	return true

func _assert_town_muster_readiness_cue(shell: Node) -> bool:
	if not shell.has_method("validation_snapshot"):
		push_error("Town smoke: shell does not expose muster-readiness validation snapshot.")
		return false
	var snapshot: Dictionary = shell.call("validation_snapshot")
	var readiness: Dictionary = snapshot.get("muster_readiness", {}) if snapshot.get("muster_readiness", {}) is Dictionary else {}
	var text := "\n".join([
		String(snapshot.get("muster_readiness_visible_text", "")),
		String(snapshot.get("muster_readiness_tooltip_text", "")),
		String(snapshot.get("recruit_visible_text", "")),
		String(snapshot.get("recruit_tooltip_text", "")),
		String(readiness.get("best_order_label", "")),
		String(readiness.get("cap_line", "")),
		String(readiness.get("readiness", "")),
		String(readiness.get("why_it_matters", "")),
		String(readiness.get("next_step", "")),
	])
	for token in ["Muster check:", "Muster Readiness", "Town reserve:", "Best order:", "Best cap:", "Readiness:", "Why it matters:", "Next practical action:", "Recruit Reserves"]:
		if not text.contains(token):
			push_error("Town smoke: muster readiness cue lost %s clarity: %s." % [token, text])
			return false
	if int(readiness.get("reserve_total", -1)) < 0 or int(readiness.get("ready_order_count", -1)) < 0:
		push_error("Town smoke: muster readiness cue did not expose stable visible counts: %s." % readiness)
		return false
	if int(readiness.get("best_order_available_count", -1)) < 0 or int(readiness.get("best_order_direct_count", -1)) < 0 or int(readiness.get("best_order_market_count", -1)) < 0:
		push_error("Town smoke: muster cap cue did not expose stable selected-order counts: %s." % readiness)
		return false
	if not (
		text.contains("can field")
		or text.contains("can unlock")
		or text.contains("stores field 0")
		or text.contains("No recruit stack")
		or text.contains("no reserve waiting")
	):
		push_error("Town smoke: muster cap cue does not explain fieldable versus waiting reserves: %s." % readiness)
		return false
	if (
		int(readiness.get("ready_units", 0)) <= 0
		and int(readiness.get("market_units", 0)) <= 0
		and int(readiness.get("blocked_reserve", 0)) <= 0
		and not String(readiness.get("visible_text", "")).contains("no recruits waiting")
	):
		push_error("Town smoke: muster readiness cue does not explain ready, trade, blocked, or empty state: %s." % readiness)
		return false
	for leak_token in ["build_category_weights", "final_priority", "base_value", "assignment_penalty", "final_score", "income_value", "growth_value", "pressure_value", "category_bonus", "raid_score", "debug_reason", "raid_target_weights", "ai_score", "weight"]:
		if text.contains(leak_token):
			push_error("Town smoke: muster readiness cue leaked internal token %s: %s." % [leak_token, text])
			return false
	return true

func _assert_town_hire_readiness_cue(shell: Node) -> bool:
	if not shell.has_method("validation_snapshot") or not shell.has_method("validation_action_catalog"):
		push_error("Town smoke: shell is missing hire-readiness validation hooks.")
		return false
	var snapshot: Dictionary = shell.call("validation_snapshot")
	var readiness: Dictionary = snapshot.get("hire_readiness", {}) if snapshot.get("hire_readiness", {}) is Dictionary else {}
	var catalog: Dictionary = shell.call("validation_action_catalog")
	var tavern_actions: Array = catalog.get("tavern", []) if catalog.get("tavern", []) is Array else []
	var cue_text := "\n".join([
		String(snapshot.get("hire_readiness_visible_text", "")),
		String(snapshot.get("hire_readiness_tooltip_text", "")),
		String(snapshot.get("tavern_visible_text", "")),
		String(snapshot.get("tavern_tooltip_text", "")),
		String(readiness.get("best_order_label", "")),
		String(readiness.get("readiness", "")),
		String(readiness.get("why_it_matters", "")),
		String(readiness.get("next_step", "")),
	])
	for token in ["Hire check:", "Hire Readiness", "Roster:", "Hire orders:", "Current stores:", "Best hire:", "Readiness:", "Why it matters:", "Next practical action:"]:
		if not cue_text.contains(token):
			push_error("Town smoke: hire readiness cue lost %s clarity: %s." % [token, cue_text])
			return false
	if int(readiness.get("listed_order_count", -1)) != tavern_actions.size() or int(readiness.get("ready_order_count", -1)) < 0 or int(readiness.get("blocked_order_count", -1)) < 0:
		push_error("Town smoke: hire readiness counts do not match visible tavern actions: readiness=%s actions=%s." % [readiness, tavern_actions])
		return false
	if int(readiness.get("roster_count", -1)) <= 0:
		push_error("Town smoke: hire readiness cue did not expose the current command roster count: %s." % readiness)
		return false
	if not (
		cue_text.contains("Ready")
		or cue_text.contains("Blocked")
		or cue_text.contains("build hall")
		or cue_text.contains("roster full")
		or cue_text.contains("no commanders")
		or cue_text.contains("no hires")
	):
		push_error("Town smoke: hire readiness cue does not explain ready, blocked, missing-hall, full-roster, or empty state: %s." % readiness)
		return false
	if not String(snapshot.get("tavern_visible_text", "")).contains("Hire check:"):
		push_error("Town smoke: hire readiness cue is not visible in the tavern label: %s." % snapshot)
		return false
	for leak_token in ["build_category_weights", "final_priority", "base_value", "assignment_penalty", "final_score", "income_value", "growth_value", "pressure_value", "category_bonus", "raid_score", "debug_reason", "raid_target_weights", "ai_score", "weight"]:
		if cue_text.contains(leak_token):
			push_error("Town smoke: hire readiness cue leaked internal token %s: %s." % [leak_token, cue_text])
			return false
	return true

func _assert_town_transfer_readiness_cue(shell: Node) -> bool:
	if not shell.has_method("validation_snapshot"):
		push_error("Town smoke: shell does not expose transfer-readiness validation snapshot.")
		return false
	var snapshot: Dictionary = shell.call("validation_snapshot")
	var readiness: Dictionary = snapshot.get("transfer_readiness", {}) if snapshot.get("transfer_readiness", {}) is Dictionary else {}
	var action_lines := []
	for action in (snapshot.get("transfer_actions", []) if snapshot.get("transfer_actions", []) is Array else []):
		if action is Dictionary:
			action_lines.append("%s %s" % [String(action.get("label", "")), String(action.get("summary", ""))])
	var cue_text := "\n".join([
		String(snapshot.get("transfer_readiness_visible_text", "")),
		String(snapshot.get("transfer_readiness_tooltip_text", "")),
		String(snapshot.get("transfer_visible_text", "")),
		String(snapshot.get("transfer_tooltip_text", "")),
		String(snapshot.get("transfer_text", "")),
		String(readiness.get("best_order", "")),
		String(readiness.get("route", "")),
		String(readiness.get("readiness", "")),
		String(readiness.get("why_it_matters", "")),
		String(readiness.get("next_step", "")),
		"\n".join(action_lines),
	])
	for token in ["Transfer check:", "Transfer Check", "Orders:", "Best order:", "Route:", "Readiness:", "Why it matters:", "Next practical action:"]:
		if not cue_text.contains(token):
			push_error("Town smoke: transfer readiness cue lost %s clarity: %s." % [token, cue_text])
			return false
	if not String(snapshot.get("transfer_visible_text", "")).contains("Transfer check:"):
		push_error("Town smoke: transfer readiness cue is not visible in the Transfer panel: %s." % snapshot)
		return false
	if int(readiness.get("total_count", 0)) <= 0 or int(readiness.get("ready_count", 0)) <= 0:
		push_error("Town smoke: transfer readiness cue did not expose ready transfer orders: %s." % readiness)
		return false
	if not cue_text.contains("Garrison") or cue_text.find("->") < 0:
		push_error("Town smoke: transfer readiness cue did not name the live transfer route: %s." % cue_text)
		return false
	for key in ["visible_text", "tooltip_text", "best_order", "route", "readiness", "why_it_matters", "next_step"]:
		if String(readiness.get(key, "")) == "":
			push_error("Town smoke: transfer readiness cue is missing structured %s: %s." % [key, readiness])
			return false
	for leak_token in ["build_category_weights", "final_priority", "base_value", "assignment_penalty", "final_score", "income_value", "growth_value", "pressure_value", "category_bonus", "raid_score", "debug_reason", "raid_target_weights", "ai_score", "weight"]:
		if cue_text.contains(leak_token):
			push_error("Town smoke: transfer readiness cue leaked internal token %s: %s." % [leak_token, cue_text])
			return false
	return true

func _assert_town_specialty_readiness_cue(shell: Node) -> bool:
	if not shell.has_method("validation_snapshot"):
		push_error("Town smoke: shell does not expose specialty-readiness validation snapshot.")
		return false
	var snapshot: Dictionary = shell.call("validation_snapshot")
	var readiness: Dictionary = snapshot.get("specialty_readiness", {}) if snapshot.get("specialty_readiness", {}) is Dictionary else {}
	var specialty_actions: Array = snapshot.get("specialty_actions", []) if snapshot.get("specialty_actions", []) is Array else []
	var text := "\n".join([
		String(snapshot.get("specialty_readiness_visible_text", "")),
		String(snapshot.get("specialty_readiness_tooltip_text", "")),
		String(snapshot.get("specialty_visible_text", "")),
		String(snapshot.get("specialty_tooltip_text", "")),
		String(snapshot.get("specialty_text", "")),
		String(readiness.get("best_order_label", "")),
		String(readiness.get("readiness", "")),
		String(readiness.get("why_it_matters", "")),
		String(readiness.get("next_step", "")),
		JSON.stringify(specialty_actions),
	])
	for token in ["Specialty check:", "Specialty Readiness", "Choices:", "Chosen ranks:", "Best choice:", "Readiness:", "Why it matters:", "Next practical action:", "Specialties"]:
		if not text.contains(token):
			push_error("Town smoke: specialty readiness cue lost %s clarity: %s." % [token, text])
			return false
	if not String(snapshot.get("specialty_visible_text", "")).contains("Specialty check:"):
		push_error("Town smoke: specialty readiness cue is not visible in the specialty label: %s." % snapshot)
		return false
	if int(readiness.get("listed_order_count", -1)) != specialty_actions.size():
		push_error("Town smoke: specialty readiness listed count does not match specialty actions: readiness=%s actions=%s." % [readiness, specialty_actions])
		return false
	if int(readiness.get("ready_order_count", -1)) < 0 or int(readiness.get("pending_choice_count", -1)) < 0 or int(readiness.get("chosen_rank_count", -1)) < 0:
		push_error("Town smoke: specialty readiness counts are not stable visible counts: %s." % readiness)
		return false
	if not (
		text.contains("Ready")
		or text.contains("Blocked")
		or text.contains("no choice")
		or text.contains("pending choice")
	):
		push_error("Town smoke: specialty readiness cue does not explain ready, blocked, pending, or empty state: %s." % text)
		return false
	for leak_token in ["build_category_weights", "final_priority", "base_value", "assignment_penalty", "final_score", "income_value", "growth_value", "pressure_value", "category_bonus", "raid_score", "debug_reason", "raid_target_weights", "ai_score", "weight"]:
		if text.contains(leak_token):
			push_error("Town smoke: specialty readiness cue leaked internal token %s: %s." % [leak_token, text])
			return false
	return true

func _assert_town_response_readiness_cue(shell: Node) -> bool:
	if not shell.has_method("validation_snapshot"):
		push_error("Town smoke: shell does not expose response-readiness validation snapshot.")
		return false
	var snapshot: Dictionary = shell.call("validation_snapshot")
	var readiness: Dictionary = snapshot.get("response_readiness", {}) if snapshot.get("response_readiness", {}) is Dictionary else {}
	var response_actions: Array = snapshot.get("response_actions", []) if snapshot.get("response_actions", []) is Array else []
	var text := "\n".join([
		String(snapshot.get("response_readiness_visible_text", "")),
		String(snapshot.get("response_readiness_tooltip_text", "")),
		String(snapshot.get("response_visible_text", "")),
		String(snapshot.get("response_tooltip_text", "")),
		String(snapshot.get("response_text", "")),
		String(readiness.get("best_order_label", "")),
		String(readiness.get("readiness", "")),
		String(readiness.get("why_it_matters", "")),
		String(readiness.get("next_step", "")),
		JSON.stringify(response_actions),
	])
	for token in ["Response check:", "Response Readiness", "Strategic Response", "Orders:", "Movement:", "Readiness:", "Why it matters:", "Next practical action:"]:
		if not text.contains(token):
			push_error("Town smoke: response readiness cue lost %s clarity: %s." % [token, text])
			return false
	if String(readiness.get("visible_text", "")) == "" or String(readiness.get("tooltip_text", "")) == "":
		push_error("Town smoke: response readiness payload is missing visible or tooltip text: %s." % readiness)
		return false
	if int(readiness.get("listed_order_count", -1)) != response_actions.size():
		push_error("Town smoke: response readiness listed count does not match response action catalog: readiness=%s actions=%s." % [readiness, response_actions])
		return false
	if not (
		text.contains("route")
		or text.contains("Recovery")
		or text.contains("response order")
		or text.contains("Move")
	):
		push_error("Town smoke: response readiness did not explain route, recovery, order, or movement context: %s." % text)
		return false
	for leak_token in ["build_category_weights", "final_priority", "base_value", "assignment_penalty", "final_score", "income_value", "growth_value", "pressure_value", "category_bonus", "raid_score", "debug_reason", "raid_target_weights", "ai_score", "weight"]:
		if text.contains(leak_token):
			push_error("Town smoke: response readiness cue leaked internal token %s: %s." % [leak_token, text])
			return false
	return true

func _assert_battle_post_action_status_recap_contract(shell: Node, action_response: Dictionary) -> bool:
	if not shell.has_method("validation_snapshot"):
		push_error("Battle smoke: battle shell does not expose post-action validation snapshot.")
		return false
	var snapshot: Dictionary = shell.call("validation_snapshot")
	var response_recap: Dictionary = action_response.get("post_action_recap", {}) if action_response.get("post_action_recap", {}) is Dictionary else {}
	var snapshot_recap: Dictionary = snapshot.get("post_action_recap", {}) if snapshot.get("post_action_recap", {}) is Dictionary else {}
	var recap_text := "\n".join([
		String(action_response.get("post_action_recap_text", "")),
		String(snapshot.get("post_action_recap_text", "")),
		String(snapshot.get("visible_consequence_text", "")),
		String(snapshot.get("consequence_tooltip_text", "")),
	])
	var context: Dictionary = snapshot.get("battle_action_context", {}) if snapshot.get("battle_action_context", {}) is Dictionary else {}
	var context_text := "\n".join([
		String(snapshot.get("battle_action_context_text", "")),
		String(snapshot.get("battle_action_context_tooltip_text", "")),
		String(snapshot.get("event_visible_text", "")),
		String(snapshot.get("event_tooltip_text", "")),
		String(context.get("latest_action", "")),
		String(context.get("next_step", "")),
		String(context.get("handoff_check", "")),
	])
	var save_surface: Dictionary = snapshot.get("save_surface", {}) if snapshot.get("save_surface", {}) is Dictionary else {}
	var save_text := "\n".join([
		String(save_surface.get("save_check", "")),
		String(save_surface.get("current_save_recap", "")),
		String(snapshot.get("save_status_visible_text", "")),
		String(snapshot.get("save_status_tooltip_text", "")),
	])
	for token in ["After order:", "Affected:", "Why it matters:", "Next:"]:
		if not recap_text.contains(token):
			push_error("Battle smoke: post-action recap lost %s clarity: response=%s snapshot=%s text=%s." % [token, action_response, snapshot_recap, recap_text])
			return false
	for token in ["Save check:", "What changed:", "Resume:", "Next:"]:
		if not save_text.contains(token):
			push_error("Battle smoke: save continuity check lost %s clarity after a battle order: %s." % [token, save_text])
			return false
	for token in ["Latest:", "Next:", "Battle Turn Context", "Latest action:", "Next practical step:", "Handoff check:"]:
		if not context_text.contains(token):
			push_error("Battle smoke: battle action context strip lost %s clarity: context=%s snapshot=%s." % [token, context_text, snapshot])
			return false
	if String(context.get("source", "")) != "post_action_recap":
		push_error("Battle smoke: battle action context strip did not use the post-action recap source: %s." % context)
		return false
	if not String(snapshot.get("event_visible_text", "")).contains("Latest:"):
		push_error("Battle smoke: battle action context strip is not visible in the dispatch rail: %s." % snapshot)
		return false
	for key in ["happened", "affected", "why_it_matters", "next_step", "decision", "next_actor", "text"]:
		if String(response_recap.get(key, "")) == "" or String(snapshot_recap.get(key, "")) == "":
			push_error("Battle smoke: post-action recap payload is missing %s: response=%s snapshot=%s." % [key, response_recap, snapshot_recap])
			return false
	var action_tooltips := "\n".join([
		String(snapshot.get("advance_tooltip", "")),
		String(snapshot.get("strike_tooltip", "")),
		String(snapshot.get("shoot_tooltip", "")),
		String(snapshot.get("defend_tooltip", "")),
	])
	if not action_tooltips.contains("Last order:") or not action_tooltips.contains("acts now"):
		push_error("Battle smoke: action tooltips did not carry the post-action next-actor recap: %s." % action_tooltips)
		return false
	for leak_token in ["final_priority", "base_value", "assignment_penalty", "final_score", "income_value", "growth_value", "pressure_value", "category_bonus", "raid_score", "debug_reason", "ai_score", "weight"]:
		if recap_text.contains(leak_token) or context_text.contains(leak_token) or action_tooltips.contains(leak_token) or save_text.contains(leak_token):
			push_error("Battle smoke: post-action recap leaked internal token %s." % leak_token)
			return false
	return true

func _assert_battle_entry_context(shell: Node) -> bool:
	if not shell.has_method("validation_snapshot"):
		push_error("Battle smoke: battle shell does not expose validation snapshot.")
		return false
	var battle_context_label: Label = shell.get_node_or_null("%BattleContext")
	if battle_context_label == null:
		push_error("Battle smoke: battle entry context label did not load.")
		return false
	var snapshot: Dictionary = shell.call("validation_snapshot")
	var entry_context := String(snapshot.get("entry_context", ""))
	var visible_context := String(battle_context_label.text)
	if not entry_context.contains("Matchup:") or not entry_context.contains("Forces:") or not entry_context.contains("Stakes:"):
		push_error("Battle smoke: entry context did not expose matchup, force, and stakes lines: %s." % entry_context)
		return false
	if not entry_context.contains("Commanders:") or not entry_context.contains("Lyra Emberwell") or not entry_context.contains("Embercourt League"):
		push_error("Battle smoke: entry context did not expose commander identity context: %s." % entry_context)
		return false
	var has_enemy_identity := (
		entry_context.contains("Blackbranch Raiders")
		or entry_context.contains("Bramble Hexer")
		or entry_context.contains("River Pass Ghoul Grove Watch")
	)
	if not has_enemy_identity or not entry_context.contains("Difficulty Low"):
		push_error("Battle smoke: entry context did not expose enemy force identity and encounter difficulty: %s." % entry_context)
		return false
	if not entry_context.contains("Friendly") or not entry_context.contains("Enemy") or not entry_context.contains("Reward"):
		push_error("Battle smoke: entry context did not expose army framing and reward context: %s." % entry_context)
		return false
	if not visible_context.contains("Matchup:") or battle_context_label.tooltip_text != entry_context:
		push_error("Battle smoke: live battle entry label is not carrying the validation entry context: visible=%s tooltip=%s snapshot=%s." % [visible_context, battle_context_label.tooltip_text, entry_context])
		return false
	var player_commander := String(snapshot.get("player_commander_text", ""))
	if not player_commander.contains("Lyra Emberwell") or not player_commander.contains("Fast scouting caster") or not player_commander.contains("Lv1") or not player_commander.contains("XP 0/250") or not player_commander.contains("Wayfinder I"):
		push_error("Battle smoke: player commander summary did not expose hero identity and progression context: %s." % player_commander)
		return false
	if not player_commander.contains("Gear impact:") or not player_commander.contains("Command no equipped battle bonuses"):
		push_error("Battle smoke: player commander summary did not expose equipment impact context: %s." % player_commander)
		return false
	return true

func _assert_town_hero_identity_progression_contract(shell: Node) -> bool:
	if not shell.has_method("validation_snapshot"):
		push_error("Town smoke: shell is missing hero identity validation hooks.")
		return false
	var snapshot: Dictionary = shell.call("validation_snapshot")
	var town_hero_text := "%s\n%s\n%s" % [
		String(snapshot.get("hero_text", "")),
		String(snapshot.get("hero_tooltip_text", "")),
		String(snapshot.get("heroes_text", "")),
	]
	var town_artifact_text := "%s\n%s" % [
		String(snapshot.get("artifact_text", "")),
		String(snapshot.get("artifact_tooltip_text", "")),
	]
	if not town_hero_text.contains("Lyra Emberwell") or not town_hero_text.contains("Embercourt League") or not town_hero_text.contains("Fast scouting caster"):
		push_error("Town smoke: hero panel did not expose hero identity/faction/role context: %s." % town_hero_text)
		return false
	if not town_hero_text.contains("Lv1") or not town_hero_text.contains("XP 0/250") or not town_hero_text.contains("Wayfinder I"):
		push_error("Town smoke: hero panel did not expose progression and specialty context: %s." % town_hero_text)
		return false
	if not town_hero_text.contains("Move") or not town_hero_text.contains("Scout") or not town_hero_text.contains("Army"):
		push_error("Town smoke: hero panel did not expose readiness and army command context: %s." % town_hero_text)
		return false
	if not town_artifact_text.contains("Gear impact:") or not town_artifact_text.contains("Collection:"):
		push_error("Town smoke: artifact panel did not expose equipment impact and collection context: %s." % town_artifact_text)
		return false
	return true

func _assert_town_faction_identity_contract(shell: Node) -> bool:
	if not shell.has_method("validation_snapshot"):
		push_error("Town smoke: town shell is missing faction identity validation hooks.")
		return false
	var snapshot: Dictionary = shell.call("validation_snapshot")
	var identity_text := "\n".join([
		String(snapshot.get("summary", "")),
		String(snapshot.get("production_overview", "")),
	])
	for token in [
		"Identity:",
		"Riverwatch Hold",
		"Embercourt League",
		"Frontier Stronghold",
		"Economy:",
		"Stable civic investment",
		"Magic:",
		"Strategic cue:",
		"Braced lines",
	]:
		if not identity_text.contains(token):
			push_error("Town smoke: town identity surface is missing %s: %s." % [token, identity_text])
			return false
	for leak_token in ["build_category_weights", "raid_target_weights", "final_priority", "debug_reason"]:
		if identity_text.contains(leak_token):
			push_error("Town smoke: town identity surface leaked internal strategy token %s: %s." % [leak_token, identity_text])
			return false
	return true

func _assert_town_magic_inspection_contract(shell: Node) -> bool:
	if not shell.has_method("validation_snapshot") or not shell.has_method("validation_action_catalog"):
		push_error("Town smoke: shell is missing magic inspection validation hooks.")
		return false
	var snapshot: Dictionary = shell.call("validation_snapshot")
	var magic_text := "\n".join([
		String(snapshot.get("study_text", "")),
		String(snapshot.get("study_tooltip_text", "")),
		String(snapshot.get("spellbook_text", "")),
		String(snapshot.get("spellbook_tooltip_text", "")),
	])
	for token in ["Spell Study", "Spellbook", "Waystride", "Field Route", "Cinder Burst", "Battle Strike", "Cost", "Ready mana", "Use:"]:
		if not magic_text.contains(token):
			push_error("Town smoke: magic panels lost practical spellbook token %s: %s." % [token, magic_text])
			return false
	var catalog: Dictionary = shell.call("validation_action_catalog")
	var study_actions: Array = catalog.get("study", [])
	if study_actions.is_empty():
		return true
	for action in study_actions:
		if action is Dictionary:
			var payload := "%s\n%s\n%s" % [
				String(action.get("label", "")),
				String(action.get("category", "")),
				String(action.get("summary", "")),
			]
			if payload.contains("Cost") and payload.contains("Use:") and (payload.contains("Battle ") or payload.contains("Field ")):
				return true
	push_error("Town smoke: study actions do not expose compact category/cost/effect/use payloads: %s." % study_actions)
	return false

func _assert_town_study_readiness_cue(shell: Node) -> bool:
	if not shell.has_method("validation_snapshot") or not shell.has_method("validation_action_catalog"):
		push_error("Town smoke: shell is missing study-readiness validation hooks.")
		return false
	var snapshot: Dictionary = shell.call("validation_snapshot")
	var readiness: Dictionary = snapshot.get("study_readiness", {}) if snapshot.get("study_readiness", {}) is Dictionary else {}
	var catalog: Dictionary = shell.call("validation_action_catalog")
	var study_actions: Array = catalog.get("study", []) if catalog.get("study", []) is Array else []
	var cue_text := "\n".join([
		String(snapshot.get("study_visible_text", "")),
		String(snapshot.get("study_tooltip_text", "")),
		String(snapshot.get("study_readiness_visible_text", "")),
		String(snapshot.get("study_readiness_tooltip_text", "")),
		JSON.stringify(readiness),
	])
	for token in ["Study check:", "Study Readiness", "Archive tier:", "Catalog:", "Best order:", "Readiness:", "Why it matters:", "Next practical action:"]:
		if not cue_text.contains(token):
			push_error("Town smoke: study readiness cue lost %s clarity: %s." % [token, cue_text])
			return false
	var ready_count := int(readiness.get("ready_order_count", -1))
	var accessible_count := int(readiness.get("accessible_count", -1))
	if ready_count != study_actions.size():
		push_error("Town smoke: study readiness count does not match visible study actions: readiness=%s actions=%s." % [readiness, study_actions])
		return false
	if accessible_count < ready_count:
		push_error("Town smoke: study readiness accessible count is smaller than learnable actions: readiness=%s." % readiness)
		return false
	if ready_count > 0 and not cue_text.contains("Learn "):
		push_error("Town smoke: study readiness cue did not name a learnable spell order: %s." % cue_text)
		return false
	for leak_token in ["build_category_weights", "final_priority", "base_value", "assignment_penalty", "final_score", "income_value", "growth_value", "pressure_value", "category_bonus", "raid_score", "debug_reason", "raid_target_weights", "ai_score", "weight"]:
		if cue_text.contains(leak_token):
			push_error("Town smoke: study readiness cue leaked internal token %s: %s." % [leak_token, cue_text])
			return false
	return true

func _assert_town_artifact_readiness_cue(shell: Node) -> bool:
	if not shell.has_method("validation_snapshot") or not shell.has_method("validation_action_catalog"):
		push_error("Town smoke: shell is missing artifact-readiness validation hooks.")
		return false
	var snapshot: Dictionary = shell.call("validation_snapshot")
	var readiness: Dictionary = snapshot.get("artifact_readiness", {}) if snapshot.get("artifact_readiness", {}) is Dictionary else {}
	var catalog: Dictionary = shell.call("validation_action_catalog")
	var artifact_actions: Array = catalog.get("artifact", []) if catalog.get("artifact", []) is Array else []
	var cue_text := "\n".join([
		String(snapshot.get("artifact_visible_text", "")),
		String(snapshot.get("artifact_tooltip_text", "")),
		String(snapshot.get("artifact_readiness_visible_text", "")),
		String(snapshot.get("artifact_readiness_tooltip_text", "")),
		JSON.stringify(readiness),
	])
	for token in ["Gear check:", "Gear Readiness", "Loadout:", "Collection:", "Gear orders:", "Best order:", "Readiness:", "Why it matters:", "Next practical action:"]:
		if not cue_text.contains(token):
			push_error("Town smoke: artifact readiness cue lost %s clarity: %s." % [token, cue_text])
			return false
	if int(readiness.get("ready_order_count", -1)) <= 0 or int(readiness.get("listed_order_count", -1)) != artifact_actions.size():
		push_error("Town smoke: artifact readiness counts do not match visible artifact orders: readiness=%s actions=%s." % [readiness, artifact_actions])
		return false
	if int(readiness.get("pack_count", -1)) <= 0 or int(readiness.get("owned_count", -1)) <= 0:
		push_error("Town smoke: artifact readiness did not expose owned pack state: %s." % readiness)
		return false
	if not cue_text.contains("Equip Trailsinger Boots") or not cue_text.contains("Ready now"):
		push_error("Town smoke: artifact readiness cue did not name the ready gear order: %s." % cue_text)
		return false
	for leak_token in ["build_category_weights", "final_priority", "base_value", "assignment_penalty", "final_score", "income_value", "growth_value", "pressure_value", "category_bonus", "raid_score", "debug_reason", "raid_target_weights", "ai_score", "weight"]:
		if cue_text.contains(leak_token):
			push_error("Town smoke: artifact readiness cue leaked internal token %s: %s." % [leak_token, cue_text])
			return false
	return true

func _assert_battle_stack_inspection_contract(shell: Node) -> bool:
	if not shell.has_method("validation_snapshot"):
		push_error("Battle smoke: battle shell does not expose validation snapshot.")
		return false
	var snapshot: Dictionary = shell.call("validation_snapshot")
	var roster_text := "\n".join(snapshot.get("player_roster", [])) + "\n" + "\n".join(snapshot.get("enemy_roster", []))
	for token in ["Strength", "HP", "T", "Ready", "Atk", "Coh"]:
		if not roster_text.contains(token):
			push_error("Battle smoke: stack rosters lost compact inspection token %s: %s." % [token, roster_text])
			return false
	return true

func _assert_battle_status_check_cue_contract(shell: Node) -> bool:
	if not shell.has_method("validation_snapshot"):
		push_error("Battle smoke: shell is missing status-check cue validation snapshot.")
		return false
	var snapshot: Dictionary = shell.call("validation_snapshot")
	var status_check: Dictionary = snapshot.get("status_check", {}) if snapshot.get("status_check", {}) is Dictionary else {}
	var status_text := "\n".join([
		String(snapshot.get("effect_visible_text", "")),
		String(snapshot.get("effect_tooltip_text", "")),
		String(snapshot.get("status_check_visible_text", "")),
		String(snapshot.get("status_check_tooltip_text", "")),
		JSON.stringify(status_check),
	])
	for token in ["Status check:", "Battle Status Check", "Active stack:", "Selected target:", "Status pressure:", "Selected pressure:", "Effect board:", "Readiness:", "Next practical action:", "Inspection:", "does not spend an action"]:
		if not status_text.contains(token):
			push_error("Battle smoke: status-check cue lost %s clarity: %s." % [token, status_text])
			return false
	if not String(snapshot.get("effect_visible_text", "")).contains("Status check:"):
		push_error("Battle smoke: status-check cue is not visible in the effects rail: %s." % snapshot)
		return false
	if int(status_check.get("effect_stack_count", -1)) < 0 or int(status_check.get("active_effect_count", -1)) < 0 or int(status_check.get("target_effect_count", -1)) < 0:
		push_error("Battle smoke: status-check cue did not expose stable effect counts: %s." % status_check)
		return false
	if not ["Clear", "Watch", "Review", "Locked", "Waiting", "unavailable"].has(String(status_check.get("readiness", ""))):
		push_error("Battle smoke: status-check cue exposed an unexpected readiness: %s." % status_check)
		return false
	for leak_token in ["final_priority", "base_value", "assignment_penalty", "final_score", "income_value", "growth_value", "pressure_value", "category_bonus", "raid_score", "debug_reason", "raid_target_weights", "ai_score", "weight"]:
		if status_text.contains(leak_token):
			push_error("Battle smoke: status-check cue leaked internal token %s: %s." % [leak_token, status_text])
			return false
	return true

func _assert_battle_risk_check_cue_contract(shell: Node) -> bool:
	if not shell.has_method("validation_snapshot"):
		push_error("Battle smoke: shell is missing risk-check cue validation snapshot.")
		return false
	var snapshot: Dictionary = shell.call("validation_snapshot")
	var risk_check: Dictionary = snapshot.get("risk_check", {}) if snapshot.get("risk_check", {}) is Dictionary else {}
	var risk_text := "\n".join([
		String(snapshot.get("risk_visible_text", "")),
		String(snapshot.get("risk_tooltip_text", "")),
		String(snapshot.get("risk_board", "")),
		String(snapshot.get("risk_check_visible_text", "")),
		String(snapshot.get("risk_check_tooltip_text", "")),
		String(risk_check.get("active", "")),
		String(risk_check.get("outlook", "")),
		String(risk_check.get("initiative", "")),
		String(risk_check.get("integrity", "")),
		String(risk_check.get("objective", "")),
		String(risk_check.get("readiness", "")),
		String(risk_check.get("next_step", "")),
	])
	for token in ["Risk check:", "Battle Risk Check", "Active stack:", "Outlook:", "Initiative swing:", "Line integrity:", "Objective urgency:", "Readiness:", "Next practical action:", "Inspection:", "does not spend an action"]:
		if not risk_text.contains(token):
			push_error("Battle smoke: risk-check cue lost %s clarity: %s." % [token, risk_text])
			return false
	if String(risk_check.get("active", "")) == "" or String(risk_check.get("outlook", "")) == "" or String(risk_check.get("next_step", "")) == "":
		push_error("Battle smoke: risk-check payload is missing active, outlook, or next-step context: %s." % risk_check)
		return false
	if not ["Brace", "Press", "Review", "Steady", "Trade", "Locked", "Waiting", "unavailable"].has(String(risk_check.get("readiness", ""))):
		push_error("Battle smoke: risk-check cue exposed an unexpected readiness: %s." % risk_check)
		return false
	if not String(snapshot.get("risk_visible_text", "")).contains("Risk check:"):
		push_error("Battle smoke: risk-check cue is not visible in the risk rail: %s." % snapshot)
		return false
	for leak_token in ["final_priority", "base_value", "assignment_penalty", "final_score", "income_value", "growth_value", "pressure_value", "category_bonus", "raid_score", "debug_reason", "raid_target_weights", "ai_score", "weight"]:
		if risk_text.contains(leak_token):
			push_error("Battle smoke: risk-check cue leaked internal token %s: %s." % [leak_token, risk_text])
			return false
	return true

func _assert_battle_timing_check_cue_contract(shell: Node) -> bool:
	if not shell.has_method("validation_snapshot"):
		push_error("Battle smoke: shell is missing timing-check cue validation snapshot.")
		return false
	var snapshot: Dictionary = shell.call("validation_snapshot")
	var timing_check: Dictionary = snapshot.get("timing_check", {}) if snapshot.get("timing_check", {}) is Dictionary else {}
	var timing_text := "\n".join([
		String(snapshot.get("spell_timing_visible_text", "")),
		String(snapshot.get("spell_timing_tooltip_text", "")),
		String(snapshot.get("spell_timing_text", "")),
		String(snapshot.get("timing_check_visible_text", "")),
		String(snapshot.get("timing_check_tooltip_text", "")),
		String(timing_check.get("active", "")),
		String(timing_check.get("target", "")),
		String(timing_check.get("spell_window", "")),
		String(timing_check.get("support_payoff", "")),
		String(timing_check.get("protection_need", "")),
		String(timing_check.get("burst_risk", "")),
		String(timing_check.get("readiness", "")),
		String(timing_check.get("next_step", "")),
	])
	for token in ["Timing check:", "Battle Timing Check", "Active stack:", "Selected target:", "Spell window:", "Burst risk:", "Readiness:", "Next practical action:", "Inspection:", "does not spend an action"]:
		if not timing_text.contains(token):
			push_error("Battle smoke: timing-check cue lost %s clarity: %s." % [token, timing_text])
			return false
	if not String(snapshot.get("spell_timing_visible_text", "")).contains("Timing check:"):
		push_error("Battle smoke: timing-check cue is not visible in the timing rail: %s." % snapshot)
		return false
	for key in ["active", "target", "spell_window", "burst_risk", "readiness", "next_step"]:
		if String(timing_check.get(key, "")) == "":
			push_error("Battle smoke: timing-check payload is missing %s: %s." % [key, timing_check])
			return false
	if not ["Cast", "Order", "Hold", "Review", "Locked", "Waiting", "unavailable"].has(String(timing_check.get("readiness", ""))):
		push_error("Battle smoke: timing-check cue exposed an unexpected readiness: %s." % timing_check)
		return false
	if not (
		timing_text.contains("Spell and Ability Timing")
		and (
			timing_text.contains("Support payoff:")
			or timing_text.contains("Enemy spell pressure:")
			or timing_text.contains("No support payoff line")
		)
	):
		push_error("Battle smoke: timing-check cue is not anchored to the existing timing board: %s." % timing_text)
		return false
	for leak_token in ["final_priority", "base_value", "assignment_penalty", "final_score", "income_value", "growth_value", "pressure_value", "category_bonus", "raid_score", "debug_reason", "raid_target_weights", "ai_score", "weight"]:
		if timing_text.contains(leak_token):
			push_error("Battle smoke: timing-check cue leaked internal token %s: %s." % [leak_token, timing_text])
			return false
	return true

func _assert_battle_aftermath_transition(source_session) -> bool:
	var outcome_session = _clone_session(source_session)
	if outcome_session.battle.is_empty():
		push_error("Battle smoke: aftermath transition coverage needs an active battle payload.")
		return false
	var stacks = outcome_session.battle.get("stacks", [])
	for index in range(stacks.size()):
		var stack = stacks[index]
		if stack is Dictionary and String(stack.get("side", "")) == "enemy":
			stack["total_health"] = 0
			stacks[index] = stack
	outcome_session.battle["stacks"] = stacks
	var result: Dictionary = BattleRules.resolve_if_battle_ready(outcome_session)
	if String(result.get("state", "")) != "victory":
		push_error("Battle smoke: aftermath transition did not resolve the live battle payload into victory: %s." % result)
		return false
	var report: Dictionary = outcome_session.flags.get("last_battle_aftermath", {})
	if "Rewards:" not in String(report.get("reward_summary", "")) or "xp" not in String(report.get("reward_summary", "")):
		push_error("Battle smoke: aftermath report did not expose compact rewards and experience: %s." % report)
		return false
	if "Forces:" not in String(report.get("force_summary", "")) or "Enemy defeated" not in String(report.get("force_summary", "")):
		push_error("Battle smoke: aftermath report did not expose surviving and defeated forces: %s." % report)
		return false
	if "Overworld:" not in String(report.get("world_summary", "")) or String(report.get("return_summary", "")) == "":
		push_error("Battle smoke: aftermath report did not expose the post-battle overworld transition: %s." % report)
		return false
	if outcome_session.scenario_status != "in_progress":
		return true

	SessionState.set_active_session(outcome_session)
	var overworld_shell = load("res://scenes/overworld/OverworldShell.tscn").instantiate()
	add_child(overworld_shell)
	await get_tree().process_frame
	await get_tree().process_frame
	if not overworld_shell.has_method("validation_snapshot"):
		push_error("Battle smoke: overworld shell does not expose validation snapshot for post-battle transition.")
		overworld_shell.queue_free()
		await get_tree().process_frame
		return false
	var snapshot: Dictionary = overworld_shell.call("validation_snapshot")
	var map_view = overworld_shell.get_node_or_null("%Map")
	if map_view == null or not map_view.has_method("validation_color_cue_summary"):
		push_error("Battle smoke: overworld map does not expose color-cue validation.")
		overworld_shell.queue_free()
		await get_tree().process_frame
		return false
	var overworld_color_cues: Dictionary = map_view.call("validation_color_cue_summary")
	if not bool(overworld_color_cues.get("assisted", false)) or String(overworld_color_cues.get("player_owner_mark", "")) != "rectangle_dot" or String(overworld_color_cues.get("enemy_owner_mark", "")) != "triangle_cross" or String(overworld_color_cues.get("neutral_owner_mark", "")) != "diamond_bar" or not bool(overworld_color_cues.get("owner_marks_drawn_with_town_pennants", false)) or not bool(overworld_color_cues.get("terrain_palette_unchanged", false)):
		push_error("Battle smoke: assisted overworld ownership cues are incomplete: %s." % overworld_color_cues)
		overworld_shell.queue_free()
		await get_tree().process_frame
		return false
	var overworld_player_color: Color = overworld_color_cues.get("player_town_color", Color.RED)
	var overworld_enemy_color: Color = overworld_color_cues.get("enemy_town_color", Color.GREEN)
	if overworld_player_color.b <= overworld_player_color.r or overworld_enemy_color.r <= overworld_enemy_color.b:
		push_error("Battle smoke: assisted overworld ownership palette is not blue/orange separated: %s." % overworld_color_cues)
		overworld_shell.queue_free()
		await get_tree().process_frame
		return false
	if not await _capture_color_cue_frame("overworld_color_cues"):
		overworld_shell.queue_free()
		await get_tree().process_frame
		return false
	var event_tooltip := String(snapshot.get("event_tooltip_text", ""))
	var feedback: Dictionary = snapshot.get("action_feedback", {})
	var feedback_text := String(feedback.get("full_text", feedback.get("text", "")))
	var return_recap_text := "%s\n%s" % [event_tooltip, feedback_text]
	overworld_shell.queue_free()
	await get_tree().process_frame
	if not return_recap_text.contains("Rewards:") or not return_recap_text.contains("Forces:") or not return_recap_text.contains("Overworld:"):
		push_error("Battle smoke: overworld return notice did not expose reward, force, and transition clarity: %s." % snapshot)
		return false
	for token in ["Handoff:", "Affected:", "Why it matters:", "Next practical action:"]:
		if not return_recap_text.contains(token):
			push_error("Battle smoke: overworld return notice lost battle handoff token %s: %s." % [token, snapshot])
			return false
	if String(feedback.get("kind", "")) != "battle" or not feedback_text.contains("Forces:"):
		push_error("Battle smoke: post-battle action feedback did not surface as a battle recap: %s." % snapshot)
		return false
	for leak_token in ["final_priority", "base_value", "assignment_penalty", "final_score", "income_value", "growth_value", "pressure_value", "category_bonus", "raid_score", "debug_reason", "ai_score", "weight"]:
		if return_recap_text.contains(leak_token):
			push_error("Battle smoke: battle handoff recap leaked internal token %s." % leak_token)
			return false
	return true

func _capture_color_cue_frame(stem: String) -> bool:
	if OS.get_environment("COLOR_CUE_CAPTURE") != "1":
		return true
	await get_tree().process_frame
	await get_tree().process_frame
	var output_dir := "res://.artifacts/color_cue_accessibility"
	var error := DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(output_dir))
	if error != OK and error != ERR_ALREADY_EXISTS:
		push_error("Color-cue smoke: could not create capture directory: %s." % error)
		return false
	var path := "%s/%s.png" % [output_dir, stem]
	error = get_viewport().get_texture().get_image().save_png(path)
	if error != OK:
		push_error("Color-cue smoke: could not save %s: %s." % [path, error])
		return false
	return true

func _clone_session(session):
	var clone = SessionState.new_session_data()
	clone.from_dict(session.to_dict())
	OverworldRules.normalize_overworld_state(clone)
	if not clone.battle.is_empty():
		BattleRules.normalize_battle_state(clone)
	return clone

func _assert_player_weekly_growth_forecast_parity() -> bool:
	var base_session = ScenarioFactory.create_session(
		"river-pass",
		"normal",
		SessionState.LAUNCH_MODE_SKIRMISH
	)
	var base_town := _first_player_town(base_session)
	if base_town.is_empty():
		push_error("Town smoke: weekly-growth parity fixture is missing its player town.")
		return false
	_move_active_hero_to_town(base_session, base_town)
	base_session.day = 7
	base_session.overworld["resource_nodes"] = []
	var towns: Array = base_session.overworld.get("towns", [])
	for index in range(towns.size()):
		var town_value = towns[index]
		if not (town_value is Dictionary):
			continue
		var town: Dictionary = town_value
		if String(town.get("placement_id", "")) == String(base_town.get("placement_id", "")):
			var built: Array = town.get("built_buildings", []).duplicate(true) if town.get("built_buildings", []) is Array else []
			for building_id in ["building_watch_barracks", "building_bowyer_lodge"]:
				if building_id not in built:
					built.append(building_id)
			town["built_buildings"] = built
			var recovery: Dictionary = town.get("recovery", {}).duplicate(true) if town.get("recovery", {}) is Dictionary else {}
			recovery["pressure"] = 0
			town["recovery"] = recovery
			town["available_recruits"] = {
				"unit_river_guard": 2,
				"unit_ember_archer": 3,
			}
			towns[index] = town
		else:
			town["owner"] = "neutral"
			towns[index] = town
	base_session.overworld["towns"] = towns
	base_session.overworld["encounters"] = []
	base_session.overworld["scenario_script_state"] = {
		"fired_hook_ids": ["riverwatch_relief_column"],
		"event_log": [],
	}
	if not _assert_daybreak_town_forecast_transition_parity(base_session):
		return false

	var raw_reference := {}
	var metrics_reference := {}
	for rank in [0, 1, 2]:
		var session = _clone_session(base_session)
		_set_muster_captain_rank(session, rank)
		var town := _first_player_town(session)
		var authority_before := JSON.stringify(session.to_dict())
		var peripheral_before := _weekly_growth_peripheral_authority()
		var raw_growth: Dictionary = OverworldRules._town_weekly_growth(town, session)
		var forecast_growth: Dictionary = OverworldRules.town_weekly_growth(town, session)
		var expected_growth: Dictionary = HeroProgressionRules.scale_recruit_growth(
			session.overworld.get("hero", {}),
			raw_growth
		)
		if raw_growth.size() < 2 or not raw_growth.has("unit_river_guard") or not raw_growth.has("unit_ember_archer"):
			push_error("Town smoke: weekly-growth parity fixture did not expose multiple units: %s." % raw_growth)
			return false
		if forecast_growth != expected_growth:
			push_error("Town smoke: rank-%d player forecast did not apply specialty growth exactly once: raw=%s expected=%s actual=%s." % [rank, raw_growth, expected_growth, forecast_growth])
			return false
		for unit_id in raw_growth.keys():
			var expected_rounded := int(round(float(int(raw_growth.get(unit_id, 0))) * (1.0 + (float(rank) * 0.2))))
			if int(forecast_growth.get(unit_id, -1)) != expected_rounded:
				push_error("Town smoke: rank-%d weekly-growth rounding drifted for %s: raw=%d expected=%d actual=%d." % [rank, unit_id, int(raw_growth.get(unit_id, 0)), expected_rounded, int(forecast_growth.get(unit_id, -1))])
				return false
		if rank == 0 and forecast_growth != raw_growth:
			push_error("Town smoke: rank-0 player forecast changed raw weekly growth: raw=%s forecast=%s." % [raw_growth, forecast_growth])
			return false
		if rank > 0:
			var double_scaled := HeroProgressionRules.scale_recruit_growth(session.overworld.get("hero", {}), expected_growth)
			if forecast_growth == raw_growth or forecast_growth == double_scaled:
				push_error("Town smoke: rank-%d player forecast was unscaled or scaled twice: raw=%s forecast=%s double=%s." % [rank, raw_growth, forecast_growth, double_scaled])
				return false
		var detached_unit := String(forecast_growth.keys()[0])
		forecast_growth[detached_unit] = int(forecast_growth.get(detached_unit, 0)) + 999
		if OverworldRules.town_weekly_growth(town, session) != expected_growth \
				or OverworldRules._town_weekly_growth(town, session) != raw_growth:
			push_error("Town smoke: mutating the public weekly forecast return changed fresh public, raw, live, or cached authority at rank %d." % rank)
			return false
		var metrics: Dictionary = OverworldRules.town_development_metrics(town, session)
		if rank == 0:
			raw_reference = raw_growth
			metrics_reference = metrics
		elif raw_growth != raw_reference or metrics != metrics_reference:
			push_error("Town smoke: player specialty rank leaked into raw growth or town development metrics at rank %d: raw=%s metrics=%s." % [rank, raw_growth, metrics])
			return false
		var enemy_town := town.duplicate(true)
		enemy_town["owner"] = "enemy"
		var neutral_town := town.duplicate(true)
		neutral_town["owner"] = "neutral"
		if OverworldRules.town_weekly_growth(enemy_town, session) != OverworldRules._town_weekly_growth(enemy_town, session) \
				or OverworldRules.town_weekly_growth(neutral_town, session) != OverworldRules._town_weekly_growth(neutral_town, session) \
				or OverworldRules.town_weekly_growth(town) != OverworldRules._town_weekly_growth(town):
			push_error("Town smoke: enemy, neutral, or sessionless weekly growth did not stay on the raw authority path at rank %d." % rank)
			return false
		var authority_after := JSON.stringify(session.to_dict())
		var peripheral_after := _weekly_growth_peripheral_authority()
		if authority_after != authority_before or peripheral_after != peripheral_before:
			push_error("Town smoke: rank-%d forecast reads changed authority: session_exact=%s peripheral_changes=%s." % [
				rank,
				authority_after == authority_before,
				_changed_dictionary_keys(peripheral_before, peripheral_after),
			])
			return false
		var realized_session = _clone_session(session)
		var realized_town_before := _first_player_town(realized_session)
		var recruits_before: Dictionary = realized_town_before.get("available_recruits", {}).duplicate(true)
		var end_turn_forecast := OverworldRules.describe_end_turn_forecast(realized_session)
		var growth_summary := OverworldRules._describe_recruit_delta(expected_growth)
		if not end_turn_forecast.contains("weekly muster") or not end_turn_forecast.contains(growth_summary):
			push_error("Town smoke: rank-%d end-turn forecast omitted exact effective muster %s: %s." % [rank, growth_summary, end_turn_forecast])
			return false
		var realized_peripheral_before := _weekly_growth_peripheral_authority()
		var end_turn_result: Dictionary = OverworldRules.end_turn(realized_session)
		var realized_town_after := _first_town_by_placement(realized_session, String(realized_town_before.get("placement_id", "")))
		var realized_delta := _recruit_pool_delta(recruits_before, realized_town_after.get("available_recruits", {}))
		if realized_delta != expected_growth or not String(end_turn_result.get("weekly_muster_summary", "")).contains(growth_summary):
			push_error("Town smoke: rank-%d end-turn mutation/result diverged from its public forecast: expected=%s delta=%s result=%s." % [rank, expected_growth, realized_delta, end_turn_result])
			return false
		if _weekly_growth_peripheral_authority() != realized_peripheral_before:
			push_error("Town smoke: rank-%d direct end turn changed save, cache, settings, or route authority." % rank)
			return false

	var copy_session = _clone_session(base_session)
	_set_muster_captain_rank(copy_session, 2)
	var copy_town := _first_player_town(copy_session)
	var copy_growth: Dictionary = OverworldRules.town_weekly_growth(copy_town, copy_session)
	var copy_authority_before := JSON.stringify(copy_session.to_dict())
	var copy_peripheral_before := _weekly_growth_peripheral_authority()
	var recruit_actions := TownRules.get_recruit_actions(copy_session)
	var matched_recruit_units := []
	for action_value in recruit_actions:
		if not (action_value is Dictionary):
			continue
		var action: Dictionary = action_value
		var unit_id := String(action.get("id", "")).trim_prefix("recruit:")
		if copy_growth.has(unit_id):
			if int(action.get("weekly_growth", -1)) != int(copy_growth.get(unit_id, -2)) \
					or not String(action.get("summary", "")).contains("Weekly +%d" % int(copy_growth.get(unit_id, 0))):
				push_error("Town smoke: Recruit copy drifted from effective weekly growth for %s: action=%s growth=%s." % [unit_id, action, copy_growth])
				return false
			matched_recruit_units.append(unit_id)
	if matched_recruit_units.size() < 2:
		push_error("Town smoke: Recruit copy did not cover both effective-growth units: actions=%s growth=%s." % [recruit_actions, copy_growth])
		return false
	var consequence_signature := TownRules.town_action_consequence_signature(copy_session)
	if consequence_signature.get("weekly_growth", {}) != copy_growth:
		push_error("Town smoke: town consequence copy drifted from effective weekly growth: %s." % consequence_signature)
		return false
	if JSON.stringify(copy_session.to_dict()) != copy_authority_before or _weekly_growth_peripheral_authority() != copy_peripheral_before:
		push_error("Town smoke: Recruit/consequence forecast copies changed session, save, cache, settings, or route authority.")
		return false

	var build_session = ScenarioFactory.create_session("river-pass", "normal", SessionState.LAUNCH_MODE_SKIRMISH)
	_set_muster_captain_rank(build_session, 2)
	build_session.day = 2
	var build_town := _first_player_town(build_session)
	_move_active_hero_to_town(build_session, build_town)
	var build_towns: Array = build_session.overworld.get("towns", [])
	for index in range(build_towns.size()):
		if build_towns[index] is Dictionary and String(build_towns[index].get("placement_id", "")) == String(build_town.get("placement_id", "")):
			var updated_town: Dictionary = build_towns[index]
			updated_town["last_build_day"] = 0
			build_towns[index] = updated_town
	build_session.overworld["towns"] = build_towns
	build_session.overworld["resources"] = {
		"gold": 99999, "wood": 99, "ore": 99, "aetherglass": 99, "embergrain": 99,
		"peatwax": 99, "verdant_grafts": 99, "brass_scrip": 99, "memory_salt": 99,
	}
	build_town = _first_player_town(build_session)
	var build_growth_before := OverworldRules.town_weekly_growth(build_town, build_session)
	var projected_town := build_town.duplicate(true)
	var projected_buildings: Array = projected_town.get("built_buildings", []).duplicate(true) if projected_town.get("built_buildings", []) is Array else []
	projected_buildings.append("building_bowyer_lodge")
	projected_town["built_buildings"] = projected_buildings
	var build_growth_after := OverworldRules.town_weekly_growth(projected_town, build_session)
	var build_projection := OverworldRules.describe_town_build_projection(build_session, build_town, "building_bowyer_lodge")
	var bowyer_action := _action_by_id(TownRules.get_build_actions(build_session), "build:building_bowyer_lodge")
	if bowyer_action.is_empty() or not String(bowyer_action.get("summary", "")).contains(build_projection):
		push_error("Town smoke: Build copy omitted its exact effective weekly projection: projection=%s action=%s." % [build_projection, bowyer_action])
		return false
	var recruits_before_build: Dictionary = build_town.get("available_recruits", {}).duplicate(true)
	var build_peripheral_before := _weekly_growth_peripheral_authority()
	var build_result: Dictionary = OverworldRules.build_in_active_town(build_session, "building_bowyer_lodge")
	var built_town := _first_player_town(build_session)
	var immediate_delta := _recruit_pool_delta(recruits_before_build, built_town.get("available_recruits", {}))
	var expected_immediate := HeroProgressionRules.scale_recruit_growth(
		build_session.overworld.get("hero", {}),
		OverworldRules._building_growth_payload("building_bowyer_lodge")
	)
	var expected_projection := OverworldRules._describe_recruit_projection(build_growth_before, build_growth_after)
	if not bool(build_result.get("ok", false)) \
			or immediate_delta != expected_immediate \
			or int(immediate_delta.get("unit_river_guard", 0)) != 0 \
			or not String(build_result.get("message", "")).contains("Weekly muster %s" % expected_projection):
		push_error("Town smoke: Build effective forecast or immediate one-time grant separation drifted: result=%s immediate=%s expected=%s projection=%s." % [build_result, immediate_delta, expected_immediate, expected_projection])
		return false
	if OverworldRules.town_weekly_growth(built_town, build_session) != build_growth_after:
		push_error("Town smoke: post-build effective weekly growth diverged from the pre-build projection.")
		return false
	if _weekly_growth_peripheral_authority() != build_peripheral_before:
		push_error("Town smoke: Build changed save, cache, settings, or route authority.")
		return false
	return true

func _assert_daybreak_town_forecast_transition_parity(base_session) -> bool:
	var transition_cases := [
		{"label": "recovery-partial", "day": 7, "recovery": 8, "occupation": 0, "locked": 0, "rank": 0},
		{"label": "recovery-clear", "day": 7, "recovery": 1, "occupation": 0, "locked": 0, "rank": 1},
		{"label": "occupation-partial", "day": 7, "recovery": 0, "occupation": 20, "locked": 2, "rank": 2},
		{"label": "occupation-clear", "day": 7, "recovery": 0, "occupation": 1, "locked": 2, "rank": 0},
		{"label": "combined-occupation-before-recovery", "day": 7, "recovery": 1, "occupation": 3, "locked": 0, "rank": 1},
		{"label": "next-day-response-expiry", "day": 7, "recovery": 5, "occupation": 0, "locked": 0, "rank": 2, "response_expiry": true},
		{"label": "nonweekly-transition", "day": 8, "recovery": 1, "occupation": 1, "locked": 2, "rank": 1},
	]
	for case_value in transition_cases:
		var case: Dictionary = case_value
		var session = _clone_session(base_session)
		session.day = int(case.get("day", 7))
		_set_muster_captain_rank(session, int(case.get("rank", 0)))
		_configure_daybreak_transition_town(
			session,
			int(case.get("recovery", 0)),
			int(case.get("occupation", 0)),
			int(case.get("locked", 0))
		)
		if bool(case.get("response_expiry", false)):
			_add_daybreak_response_expiry_fixture(session)
		OverworldRules.normalize_overworld_state(session)
		var town_index := _first_player_town_index(session)
		var town := _first_player_town(session)
		var next_day := int(session.day) + 1
		var recruits_before: Dictionary = town.get("available_recruits", {}).duplicate(true)
		var current_growth: Dictionary = OverworldRules.town_weekly_growth(town, session)
		var recovery_before := OverworldRules.town_recovery_state(session, town)
		var occupation_before := OverworldRules.town_occupation_state(session, town)
		var authority_before := JSON.stringify(session.to_dict())
		var peripheral_before := _weekly_growth_peripheral_authority()

		var projection: Dictionary = OverworldRules._project_player_town_at_daybreak(session, town, town_index, next_day)
		var projected_session = projection.get("session")
		var projected_town: Dictionary = projection.get("town", {})
		var manual_session = _clone_session(session)
		manual_session.day = next_day
		OverworldRules._advance_all_town_occupations(manual_session)
		OverworldRules._advance_all_town_recovery(manual_session)
		var manual_town := _first_town_by_placement(manual_session, String(town.get("placement_id", "")))
		if projected_session == null or projected_session == session \
				or int(projected_session.day) != next_day \
				or int(projected_session.save_version) != int(session.save_version) \
				or String(projected_session.session_id) != String(session.session_id) \
				or String(projected_session.scenario_id) != String(session.scenario_id) \
				or String(projected_session.hero_id) != String(session.hero_id) \
				or String(projected_session.difficulty) != String(session.difficulty) \
				or String(projected_session.launch_mode) != String(session.launch_mode) \
				or String(projected_session.game_state) != String(session.game_state) \
				or String(projected_session.scenario_status) != String(session.scenario_status) \
				or String(projected_session.scenario_summary) != String(session.scenario_summary) \
				or projected_town != manual_town \
				or projected_session.overworld.get("towns", [])[town_index] != projected_town:
			push_error("Town smoke: %s direct daybreak projection did not insert the exact transitioned town into its isolated next-day session: projected=%s manual=%s." % [case.get("label", "case"), projected_town, manual_town])
			return false
		var expected_recovery_pressure: int = max(0, int(recovery_before.get("pressure", 0)) - int(recovery_before.get("relief_per_day", 1)))
		var expected_occupation_pressure: int = max(0, int(occupation_before.get("pressure", 0)) - int(occupation_before.get("relief_per_day", 0)))
		if int(OverworldRules.town_recovery_state(projected_session, projected_town).get("pressure", -1)) != expected_recovery_pressure \
				or int(OverworldRules.town_occupation_state(projected_session, projected_town).get("pressure", -1)) != expected_occupation_pressure:
			push_error("Town smoke: %s daybreak transition pressure/order drifted: recovery=%s occupation=%s projected=%s." % [case.get("label", "case"), recovery_before, occupation_before, projected_town])
			return false
		var projected_raw: Dictionary = OverworldRules._town_weekly_growth(projected_town, projected_session)
		var projected_growth: Dictionary = OverworldRules.town_weekly_growth(projected_town, projected_session)
		var expected_scaled: Dictionary = HeroProgressionRules.scale_recruit_growth(projected_session.overworld.get("hero", {}), projected_raw)
		if projected_growth != expected_scaled:
			push_error("Town smoke: %s projected player growth did not scale its transitioned raw payload exactly once: raw=%s expected=%s actual=%s." % [case.get("label", "case"), projected_raw, expected_scaled, projected_growth])
			return false
		for unit_id in projected_raw.keys():
			var rank := int(case.get("rank", 0))
			var rounded := int(round(float(int(projected_raw.get(unit_id, 0))) * (1.0 + float(rank) * 0.2)))
			if int(projected_growth.get(unit_id, -1)) != rounded:
				push_error("Town smoke: %s rank-%d projected rounding drifted for %s: raw=%s projected=%s." % [case.get("label", "case"), rank, unit_id, projected_raw, projected_growth])
				return false
		var transition_delta := _recruit_pool_delta(recruits_before, projected_town.get("available_recruits", {}))
		if int(case.get("occupation", 0)) <= 0 or expected_occupation_pressure > 0:
			if not transition_delta.is_empty():
				push_error("Town smoke: %s released occupation reserves before pacification cleared: %s." % [case.get("label", "case"), transition_delta])
				return false
		elif int(transition_delta.get("unit_neutral_hearthbow_carriers", 0)) != int(case.get("locked", 0)):
			push_error("Town smoke: %s did not separately release its exact locked occupation reserve: %s." % [case.get("label", "case"), transition_delta])
			return false
		if bool(case.get("response_expiry", false)):
			var live_node: Dictionary = session.overworld.get("resource_nodes", [])[0]
			var projected_node: Dictionary = projected_session.overworld.get("resource_nodes", [])[0]
			var site := ContentService.get_resource_site(String(live_node.get("site_id", "")))
			var current_response := OverworldRules._resource_site_response_state(session, live_node, site)
			var projected_response := OverworldRules._resource_site_response_state(projected_session, projected_node, site)
			var current_logistics := OverworldRules._town_logistics_state(session, town)
			var projected_logistics := OverworldRules._town_logistics_state(projected_session, projected_town)
			if not bool(current_response.get("active", false)) \
					or bool(projected_response.get("active", true)) \
					or int(current_logistics.get("response_count", 0)) != 1 \
					or int(projected_logistics.get("response_count", -1)) != 0 \
					or int(current_logistics.get("response_growth_bonus_percent", 0)) <= 0 \
					or int(projected_logistics.get("response_growth_bonus_percent", -1)) != 0 \
					or current_growth == projected_growth:
				push_error("Town smoke: next-day response expiry did not remove current-day response growth from the projected payload: current=%s projected=%s." % [current_growth, projected_growth])
				return false

		var expected_income: Dictionary = _manual_daybreak_income_projection(manual_session)
		var income_summary := OverworldRules._describe_resource_delta(expected_income)
		var growth_summary := OverworldRules._describe_recruit_delta(projected_growth)
		var full_forecast := OverworldRules.describe_end_turn_forecast(session)
		var compact_forecast := OverworldRules.describe_end_turn_forecast_compact(session)
		if not full_forecast.contains("income %s" % income_summary) or not compact_forecast.contains("income %s" % income_summary):
			push_error("Town smoke: %s full/compact forecast did not copy exact projected daybreak income %s: full=%s compact=%s." % [case.get("label", "case"), expected_income, full_forecast, compact_forecast])
			return false
		if compact_forecast.to_lower().contains("muster"):
			push_error("Town smoke: %s compact forecast unexpectedly exposed muster copy: %s." % [case.get("label", "case"), compact_forecast])
			return false
		var weekly := OverworldRules.is_weekly_growth_day(next_day)
		if weekly:
			if growth_summary == "" and not full_forecast.contains("weekly muster resolves"):
				push_error("Town smoke: %s zero-growth full forecast omitted the explicit weekly-muster resolution: %s." % [case.get("label", "case"), full_forecast])
				return false
			if growth_summary != "" and (not full_forecast.contains("weekly muster") or not full_forecast.contains(growth_summary)):
				push_error("Town smoke: %s full forecast omitted exact projected town muster %s: %s." % [case.get("label", "case"), projected_growth, full_forecast])
				return false
		if not weekly and (full_forecast.contains(growth_summary) or not full_forecast.contains("muster Day")):
			push_error("Town smoke: %s nonweekly full forecast exposed growth instead of cadence: %s." % [case.get("label", "case"), full_forecast])
			return false
		var fallback: Dictionary = OverworldRules._project_player_town_at_daybreak(session, town, -1, next_day)
		if fallback.keys().size() != 2 or fallback.get("session") != session or fallback.get("town", {}) != town:
			push_error("Town smoke: %s invalid projection index did not return the exact live fallback pair: %s." % [case.get("label", "case"), fallback])
			return false
		if JSON.stringify(session.to_dict()) != authority_before or _weekly_growth_peripheral_authority() != peripheral_before:
			push_error("Town smoke: %s direct/full/compact forecast mutated live or shared nested authority." % case.get("label", "case"))
			return false
		if int(session.save_version) != 9 or int(projected_session.save_version) != 9 or int(SessionState.SAVE_VERSION) != 9:
			push_error("Town smoke: %s daybreak projection changed save version 9 authority." % case.get("label", "case"))
			return false

		var realized_session = _clone_session(session)
		var realized_before: Dictionary = _first_player_town(realized_session).get("available_recruits", {}).duplicate(true)
		var realized_result: Dictionary = OverworldRules.end_turn(realized_session)
		var realized_town := _first_town_by_placement(realized_session, String(town.get("placement_id", "")))
		var realized_delta := _recruit_pool_delta(realized_before, realized_town.get("available_recruits", {}))
		var expected_delta := OverworldRules._add_recruit_growth(transition_delta, projected_growth) if weekly else transition_delta
		expected_delta = _recruit_pool_delta({}, expected_delta)
		var expected_weekly_summary := (
			"%s (%s)" % [
				String(ContentService.get_town(String(town.get("town_id", ""))).get("name", "Town")),
				growth_summary,
			]
			if weekly and growth_summary != ""
			else ""
		)
		if realized_delta != expected_delta \
				or String(realized_result.get("resource_income_summary", "")) != income_summary \
				or String(realized_result.get("weekly_muster_summary", "")) != expected_weekly_summary:
			push_error("Town smoke: %s projected income/town growth diverged from live daybreak: income=%s growth=%s delta=%s result=%s." % [case.get("label", "case"), expected_income, projected_growth, realized_delta, realized_result])
			return false

	if not _assert_two_town_daybreak_preview_order(base_session):
		return false
	if not _assert_daybreak_muster_effect_separation(base_session):
		return false
	return true

func _configure_daybreak_transition_town(session, recovery_pressure: int, occupation_pressure: int, locked_count: int) -> void:
	var towns: Array = session.overworld.get("towns", [])
	for index in range(towns.size()):
		if not (towns[index] is Dictionary) or String(towns[index].get("owner", "neutral")) != "player":
			continue
		var town: Dictionary = towns[index]
		town["recovery"] = {"pressure": recovery_pressure, "last_event_day": session.day, "source": "daybreak-forecast-test"}
		town["occupation"] = (
			{
				"state": "pacifying",
				"faction_id": "faction_mireclaw",
				"pressure": occupation_pressure,
				"initial_pressure": occupation_pressure,
				"start_day": max(1, int(session.day) - 1),
				"last_event_day": int(session.day),
				"last_owner": "enemy",
				"source": "daybreak-forecast-test",
				"locked_recruits": {"unit_neutral_hearthbow_carriers": locked_count} if locked_count > 0 else {},
			}
			if occupation_pressure > 0
			else {}
		)
		towns[index] = town
		break
	session.overworld["towns"] = towns

func _add_daybreak_response_expiry_fixture(session) -> void:
	var town := _first_player_town(session)
	session.overworld["resource_nodes"] = [
		{
			"placement_id": "daybreak_response_expiry",
			"site_id": "site_brightwood_sawmill",
			"x": int(town.get("x", 0)),
			"y": int(town.get("y", 0)),
			"collected_by_faction_id": "player",
			"response_last_day": int(session.day) - 2,
			"response_until_day": int(session.day),
			"response_security_rating": 1,
		}
	]

func _manual_daybreak_income_projection(transitioned_session) -> Dictionary:
	var total := OverworldRules._empty_live_resource_stockpile()
	for town_value in transitioned_session.overworld.get("towns", []):
		if not (town_value is Dictionary) or String(town_value.get("owner", "neutral")) != "player":
			continue
		var town: Dictionary = town_value
		total = OverworldRules._add_resource_sets(
			total,
			DifficultyRules.scale_income_resources(
				transitioned_session,
				OverworldRules.town_income(town, transitioned_session)
			)
		)
	var hero: Dictionary = transitioned_session.overworld.get("hero", {})
	total = OverworldRules._add_resource_sets(
		total,
		DifficultyRules.scale_income_resources(
			transitioned_session,
			ArtifactRules.aggregate_bonuses(hero).get("daily_income", {})
		)
	)
	total = OverworldRules._add_resource_sets(total, HeroProgressionRules.daily_income_bonus(hero))
	total = OverworldRules._add_resource_sets(
		total,
		DifficultyRules.scale_income_resources(
			transitioned_session,
			OverworldRules.controlled_resource_site_income(transitioned_session, "player", int(transitioned_session.day))
		)
	)
	return total

func _first_player_town_index(session) -> int:
	var towns: Array = session.overworld.get("towns", [])
	for index in range(towns.size()):
		if towns[index] is Dictionary and String(towns[index].get("owner", "")) == "player":
			return index
	return -1

func _assert_two_town_daybreak_preview_order(base_session) -> bool:
	var session = _clone_session(base_session)
	var towns: Array = session.overworld.get("towns", [])
	if towns.size() < 2:
		push_error("Town smoke: two-town daybreak preview fixture is missing its second town.")
		return false
	for index in range(towns.size()):
		if towns[index] is Dictionary:
			var town: Dictionary = towns[index]
			town["owner"] = "player"
			town["recovery"] = {"pressure": index + 1, "source": "preview-order"}
			town["occupation"] = {}
			towns[index] = town
	var third: Dictionary = towns[1].duplicate(true)
	third["placement_id"] = "daybreak_preview_third"
	third["town_id"] = "town_prismhearth"
	third["x"] = 4
	third["y"] = 4
	third["recovery"] = {"pressure": 3, "source": "preview-order"}
	towns.append(third)
	session.overworld["towns"] = towns
	OverworldRules.normalize_overworld_state(session)
	towns = session.overworld.get("towns", [])
	var authority_before := JSON.stringify(session.to_dict())
	var peripheral_before := _weekly_growth_peripheral_authority()
	var forecast := OverworldRules._end_turn_muster_forecast_line(session, int(session.day) + 1)
	var expected_tokens := []
	for index in range(3):
		var town: Dictionary = towns[index]
		var projection: Dictionary = OverworldRules._project_player_town_at_daybreak(session, town, index, int(session.day) + 1)
		var projected_session = projection.get("session")
		var projected_town: Dictionary = projection.get("town", {})
		var name := String(ContentService.get_town(String(town.get("town_id", ""))).get("name", ""))
		var summary := OverworldRules._describe_recruit_delta(OverworldRules.town_weekly_growth(projected_town, projected_session))
		expected_tokens.append("%s %s" % [name, summary])
	var first_position := forecast.find(String(expected_tokens[0]))
	var second_position := forecast.find(String(expected_tokens[1]))
	if first_position < 0 or second_position <= first_position or forecast.contains(String(expected_tokens[2])):
		push_error("Town smoke: full daybreak muster preview did not preserve town-array order and exact two-town cap: expected=%s forecast=%s." % [expected_tokens, forecast])
		return false
	if JSON.stringify(session.to_dict()) != authority_before or _weekly_growth_peripheral_authority() != peripheral_before:
		push_error("Town smoke: two-town preview order/cap read changed live or shared nested authority.")
		return false
	return true

func _assert_daybreak_muster_effect_separation(base_session) -> bool:
	var session = _clone_session(base_session)
	session.day = 7
	_set_muster_captain_rank(session, 1)
	_configure_daybreak_transition_town(session, 1, 1, 2)
	session.overworld["scenario_script_state"] = {
		"fired_hook_ids": [
			"north_road_salvage",
			"duskfen_counterstroke",
			"mire_cleansing_boon",
			"riverwatch_bell_recall",
			"reed_totem_host_rallies",
		],
		"event_log": [],
	}
	var town := _first_player_town(session)
	var town_id := String(town.get("placement_id", ""))
	session.overworld["resource_nodes"] = [
		{
			"placement_id": "daybreak_effect_separation_site",
			"site_id": "site_free_company_yard",
			"x": int(town.get("x", 0)),
			"y": int(town.get("y", 0)),
			"collected_by_faction_id": "player",
			"delivery_controller_id": "player",
			"delivery_origin_town_id": town_id,
			"delivery_target_kind": "town",
			"delivery_target_id": town_id,
			"delivery_target_label": "Riverwatch Hold",
			"delivery_arrival_day": 8,
			"delivery_manifest": {"unit_neutral_cliffhawk_wardens": 2},
		}
	]
	OverworldRules.normalize_overworld_state(session)
	town = _first_player_town(session)
	var authority_before := JSON.stringify(session.to_dict())
	var peripheral_before := _weekly_growth_peripheral_authority()
	var projection: Dictionary = OverworldRules._project_player_town_at_daybreak(session, town, _first_player_town_index(session), 8)
	var projected_session = projection.get("session")
	var projected_town: Dictionary = projection.get("town", {})
	var town_growth: Dictionary = OverworldRules.town_weekly_growth(projected_town, projected_session)
	var occupation_release := _recruit_pool_delta(town.get("available_recruits", {}), projected_town.get("available_recruits", {}))
	var full_forecast := OverworldRules.describe_end_turn_forecast(session)
	if not full_forecast.contains(OverworldRules._describe_recruit_delta(town_growth)) \
			or full_forecast.contains("Roadwardens") \
			or full_forecast.to_lower().contains("relief column"):
		push_error("Town smoke: full town forecast conflated town growth with site muster or scenario hook effects: %s." % full_forecast)
		return false
	if JSON.stringify(session.to_dict()) != authority_before or _weekly_growth_peripheral_authority() != peripheral_before:
		push_error("Town smoke: separated site/hook/reserve/delivery forecast changed live or shared nested authority.")
		return false

	var recruits_before: Dictionary = town.get("available_recruits", {}).duplicate(true)
	var resources_before: Dictionary = session.overworld.get("resources", {}).duplicate(true)
	var garrison_before := _garrison_unit_count(town, "unit_neutral_cliffhawk_wardens")
	var result: Dictionary = OverworldRules.end_turn(session)
	var town_after := _first_town_by_placement(session, town_id)
	var recruit_delta := _recruit_pool_delta(recruits_before, town_after.get("available_recruits", {}))
	var expected_delta := OverworldRules._add_recruit_growth(occupation_release, town_growth)
	expected_delta = OverworldRules._add_recruit_growth(expected_delta, {"unit_neutral_roadwardens": 1})
	expected_delta = OverworldRules._add_recruit_growth(expected_delta, {"unit_river_guard": 20})
	var income_projection: Dictionary = _manual_daybreak_income_projection(projected_session)
	var expected_resource_delta := _resource_pool_delta(
		{},
		OverworldRules._add_resource_sets(income_projection, {"gold": 250, "wood": 1, "ore": 1})
	)
	var actual_resource_delta := _resource_pool_delta(resources_before, session.overworld.get("resources", {}))
	var weekly_summary := String(result.get("weekly_muster_summary", ""))
	var town_summary := String(result.get("town_economy_summary", ""))
	if recruit_delta != expected_delta \
			or int(occupation_release.get("unit_neutral_hearthbow_carriers", 0)) != 2 \
			or int(_garrison_unit_count(town_after, "unit_neutral_cliffhawk_wardens")) - garrison_before != 2 \
			or actual_resource_delta != expected_resource_delta \
			or not weekly_summary.contains(OverworldRules._describe_recruit_delta(town_growth)) \
			or not weekly_summary.contains("Roadwardens") \
			or weekly_summary.contains("+20 River Guard") \
			or not town_summary.to_lower().contains("held lev") \
			or not town_summary.to_lower().contains("convoy reaches") \
			or not String(result.get("message", "")).to_lower().contains("relief column"):
		push_error("Town smoke: occupation release, town/site muster, scenario hook, or reserve delivery effects were not separately exact: recruits=%s expected=%s resources=%s expected_resources=%s result=%s." % [recruit_delta, expected_delta, actual_resource_delta, expected_resource_delta, result])
		return false
	return true

func _garrison_unit_count(town: Dictionary, unit_id: String) -> int:
	var total := 0
	for stack_value in town.get("garrison", []):
		if stack_value is Dictionary and String(stack_value.get("unit_id", "")) == unit_id:
			total += int(stack_value.get("count", 0))
	return total

func _resource_pool_delta(before: Dictionary, after: Dictionary) -> Dictionary:
	var delta := {}
	for resource_id in OverworldRules._resource_keys_for_payload(after):
		var amount := int(after.get(resource_id, 0)) - int(before.get(resource_id, 0))
		if amount != 0:
			delta[String(resource_id)] = amount
	return delta

func _set_muster_captain_rank(session, rank: int) -> void:
	var specialties := []
	for _index in range(max(0, rank)):
		specialties.append("mustercaptain")
	var hero: Dictionary = session.overworld.get("hero", {})
	hero["specialties"] = specialties.duplicate(true)
	session.overworld["hero"] = hero
	var heroes: Array = session.overworld.get("player_heroes", [])
	for index in range(heroes.size()):
		if heroes[index] is Dictionary and String(heroes[index].get("id", "")) == String(session.overworld.get("active_hero_id", "")):
			var roster_hero: Dictionary = heroes[index]
			roster_hero["specialties"] = specialties.duplicate(true)
			heroes[index] = roster_hero
	session.overworld["player_heroes"] = heroes

func _first_town_by_placement(session, placement_id: String) -> Dictionary:
	for town_value in session.overworld.get("towns", []):
		if town_value is Dictionary and String(town_value.get("placement_id", "")) == placement_id:
			return town_value
	return {}

func _recruit_pool_delta(before: Variant, after: Variant) -> Dictionary:
	var delta := {}
	var unit_ids := []
	if before is Dictionary:
		unit_ids.append_array(before.keys())
	if after is Dictionary:
		for unit_id in after.keys():
			if unit_id not in unit_ids:
				unit_ids.append(unit_id)
	for unit_id_value in unit_ids:
		var unit_id := String(unit_id_value)
		var amount := int(after.get(unit_id, 0)) - int(before.get(unit_id, 0)) if after is Dictionary and before is Dictionary else 0
		if amount != 0:
			delta[unit_id] = amount
	return delta

func _action_by_id(actions: Array, action_id: String) -> Dictionary:
	for action_value in actions:
		if action_value is Dictionary and String(action_value.get("id", "")) == action_id:
			return action_value
	return {}

func _changed_dictionary_keys(before: Dictionary, after: Dictionary) -> Array:
	var changed := []
	for key in before.keys():
		if not after.has(key) or before.get(key) != after.get(key):
			changed.append(String(key))
	for key in after.keys():
		if not before.has(key) and String(key) not in changed:
			changed.append(String(key))
	return changed

func _weekly_growth_peripheral_authority() -> Dictionary:
	return {
		"save_files": _weekly_growth_save_file_states(),
		"save_cache": SaveService.validation_summary_cache_snapshot(),
		"settings": SettingsService.settings.duplicate(true),
		"settings_files": _weekly_growth_file_states([
			SettingsService.SETTINGS_FILE,
			SettingsService.SETTINGS_CANDIDATE_FILE,
			SettingsService.SETTINGS_BACKUP_FILE,
		]),
		"safe_quit_route": AppRouter.validation_safe_quit_snapshot(),
		"active_play_route": AppRouter.validation_active_play_return_snapshot(),
		"battle_entry_route": AppRouter.validation_battle_entry_snapshot(),
		"battle_resolution_route": AppRouter.validation_battle_resolution_checkpoint_snapshot(),
		"outcome_route": AppRouter.validation_scenario_outcome_route_snapshot(),
	}

func _weekly_growth_save_file_states() -> Dictionary:
	return _weekly_growth_file_states([
		"user://saves/autosave.json",
		"user://saves/autosave.json.candidate",
		"user://saves/autosave.json.backup",
		"user://saves/slot1.json",
		"user://saves/slot2.json",
		"user://saves/slot3.json",
		"user://saves/campaign_progression.json",
	])

func _weekly_growth_file_states(paths: Array) -> Dictionary:
	var states := {}
	for path in paths:
		states[path] = {
			"exists": FileAccess.file_exists(path),
			"bytes": FileAccess.get_file_as_bytes(path) if FileAccess.file_exists(path) else PackedByteArray(),
		}
	return states

func _first_player_town(session) -> Dictionary:
	for town in session.overworld.get("towns", []):
		if town is Dictionary and String(town.get("owner", "")) == "player":
			return town
	return {}

func _move_active_hero_to_town(session, town: Dictionary) -> void:
	var position := {"x": int(town.get("x", 0)), "y": int(town.get("y", 0))}
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

func _seed_town_artifact_readiness_fixture(session) -> void:
	var artifact_id := "artifact_trailsinger_boots"
	var active_hero = session.overworld.get("hero", {})
	if active_hero is Dictionary:
		var artifacts := ArtifactRules.normalize_hero_artifacts(active_hero.get("artifacts", {}))
		var inventory: Array = artifacts.get("inventory", []) if artifacts.get("inventory", []) is Array else []
		if artifact_id not in inventory:
			inventory.append(artifact_id)
		artifacts["inventory"] = inventory
		active_hero["artifacts"] = ArtifactRules.normalize_hero_artifacts(artifacts)
		session.overworld["hero"] = active_hero
	var heroes = session.overworld.get("player_heroes", [])
	for index in range(heroes.size()):
		var hero = heroes[index]
		if hero is Dictionary and String(hero.get("id", "")) == String(session.overworld.get("active_hero_id", "")):
			hero["artifacts"] = session.overworld.get("hero", {}).get("artifacts", {})
			heroes[index] = hero
	session.overworld["player_heroes"] = heroes

func _assert_town_economy_decision_payload(shell: Node) -> bool:
	if not shell.has_method("validation_action_catalog") or not shell.has_method("validation_try_progress_action"):
		push_error("Town smoke: town shell does not expose action catalog validation hooks.")
		return false
	var catalog: Dictionary = shell.call("validation_action_catalog")
	var build_actions: Array = catalog.get("build", [])
	if build_actions.is_empty():
		push_error("Town smoke: town action catalog did not expose build actions.")
		return false
	var build_surface_ok := false
	for action in build_actions:
		if not (action is Dictionary):
			continue
		var summary := String(action.get("summary", ""))
		var affordability := String(action.get("affordability_label", ""))
		if summary.contains("Cost ") and (summary.contains("Ready:") or summary.contains("Blocked:") or summary.contains("Needs exchange:")) and affordability != "":
			build_surface_ok = true
		if bool(action.get("disabled", false)) and String(action.get("disabled_reason", "")) == "":
			push_error("Town smoke: disabled build action is missing an economy disabled reason: %s." % action)
			return false
	if not build_surface_ok:
		push_error("Town smoke: build actions do not explain cost readiness in their live tooltip payload: %s." % build_actions)
		return false

	var recruit_actions: Array = catalog.get("recruit", [])
	if recruit_actions.is_empty():
		push_error("Town smoke: town action catalog did not expose recruit actions.")
		return false
	var recruit_surface_ok := false
	for action in recruit_actions:
		if not (action is Dictionary):
			continue
		var summary := String(action.get("summary", ""))
		if summary.contains("Weekly +") and summary.contains("Cost ") and String(action.get("affordability_label", "")) != "":
			recruit_surface_ok = true
		if bool(action.get("disabled", false)) and String(action.get("disabled_reason", "")) == "":
			push_error("Town smoke: disabled recruit action is missing an economy disabled reason: %s." % action)
			return false
	if not recruit_surface_ok:
		push_error("Town smoke: recruit actions do not explain weekly growth, cost, and affordability in their live payload: %s." % recruit_actions)
		return false

	var progress: Dictionary = shell.call("validation_try_progress_action")
	if not bool(progress.get("ok", false)):
		push_error("Town smoke: validation town economy action did not change state: %s." % progress)
		return false
	var message := String(progress.get("message", ""))
	if not message.contains("Spent ") or (not message.contains("remain in town reserve") and not message.contains("Daily income now") and not message.contains("Weekly muster")):
		push_error("Town smoke: economy action feedback did not explain spend plus the visible town/field outcome: %s." % progress)
		return false
	if not _assert_town_post_action_consequence_contract(shell, progress):
		return false
	return true

func _assert_town_post_action_consequence_contract(shell: Node, action_response: Dictionary) -> bool:
	if not shell.has_method("validation_snapshot"):
		push_error("Town smoke: town shell does not expose post-action validation snapshot.")
		return false
	var snapshot: Dictionary = shell.call("validation_snapshot")
	var response_recap: Dictionary = action_response.get("town_action_recap", {}) if action_response.get("town_action_recap", {}) is Dictionary else {}
	var snapshot_recap: Dictionary = snapshot.get("town_action_recap", {}) if snapshot.get("town_action_recap", {}) is Dictionary else {}
	var context: Dictionary = snapshot.get("town_action_context", {}) if snapshot.get("town_action_context", {}) is Dictionary else {}
	var recap_text := "\n".join([
		String(action_response.get("town_action_recap_text", "")),
		String(snapshot.get("town_action_recap_text", "")),
		String(snapshot.get("visible_consequence_text", "")),
		String(snapshot.get("consequence_tooltip_text", "")),
	])
	var context_text := "\n".join([
		String(snapshot.get("town_action_context_text", "")),
		String(snapshot.get("town_action_context_tooltip_text", "")),
		String(context.get("latest_action", "")),
		String(context.get("next_step", "")),
		String(context.get("handoff_check", "")),
	])
	var save_surface: Dictionary = snapshot.get("save_surface", {}) if snapshot.get("save_surface", {}) is Dictionary else {}
	var save_text := "\n".join([
		String(save_surface.get("save_check", "")),
		String(save_surface.get("current_save_recap", "")),
		String(snapshot.get("save_status_visible_text", "")),
		String(snapshot.get("save_status_tooltip_text", "")),
	])
	for token in ["After order:", "Affected:", "Why it matters:", "Next:"]:
		if not recap_text.contains(token):
			push_error("Town smoke: post-action town recap lost %s clarity: response=%s snapshot=%s text=%s." % [token, response_recap, snapshot_recap, recap_text])
			return false
	for token in ["Save check:", "What changed:", "Resume:", "Next:"]:
		if not save_text.contains(token):
			push_error("Town smoke: save continuity check lost %s clarity after a town order: %s." % [token, save_text])
			return false
	for token in ["Latest:", "Next:", "Town Turn Context", "Latest action:", "Next practical step:", "Handoff check:", "Town status:", "Departure Check", "Save check:"]:
		if not context_text.contains(token):
			push_error("Town smoke: town action context strip lost %s clarity: %s." % [token, context_text])
			return false
	if String(context.get("source", "")) != "town_action_recap":
		push_error("Town smoke: town action context strip did not use the town action recap source: %s." % context)
		return false
	if not String(snapshot.get("visible_consequence_text", "")).contains("Latest:"):
		push_error("Town smoke: compact town Latest/Next strip is not visible in the event rail: %s." % snapshot)
		return false
	for key in ["happened", "affected", "why_it_matters", "next_step", "matters", "next", "text"]:
		if String(response_recap.get(key, "")) == "" or String(snapshot_recap.get(key, "")) == "":
			push_error("Town smoke: post-action town recap is missing structured %s: response=%s snapshot=%s." % [key, response_recap, snapshot_recap])
			return false
	var consequence_text := "\n".join([
		String(response_recap.get("affected", "")),
		String(response_recap.get("why_it_matters", "")),
		String(response_recap.get("next_step", "")),
	])
	var practical_tokens := ["Stores", "Reserve", "Field", "Building", "Income", "Weekly muster", "readiness", "frontier", "build", "recruit"]
	var practical_token_found := false
	for token in practical_tokens:
		if consequence_text.contains(String(token)):
			practical_token_found = true
			break
	if not practical_token_found:
		push_error("Town smoke: post-action town recap did not explain a practical town/field consequence: %s." % response_recap)
		return false
	for leak_token in ["build_category_weights", "final_priority", "base_value", "assignment_penalty", "final_score", "income_value", "growth_value", "pressure_value", "category_bonus", "raid_score", "debug_reason", "raid_target_weights"]:
		if recap_text.contains(leak_token) or save_text.contains(leak_token) or context_text.contains(leak_token):
			push_error("Town smoke: post-action town recap leaked internal strategy token %s: %s." % [leak_token, recap_text])
			return false
	if String(snapshot.get("visible_consequence_text", "")) == "" or String(snapshot.get("consequence_tooltip_text", "")) == "":
		push_error("Town smoke: post-action town recap is not exposed through visible rail and tooltip text: %s." % snapshot)
		return false
	return true

func _assert_town_build_recruit_next_step_contract(shell: Node) -> bool:
	if not shell.has_method("validation_snapshot") or not shell.has_method("validation_action_catalog"):
		push_error("Town smoke: shell is missing town next-step recommendation validation hooks.")
		return false
	var snapshot: Dictionary = shell.call("validation_snapshot")
	var overview := String(snapshot.get("production_overview", ""))
	if not overview.contains("Practical priority:") or not overview.contains("Defense/frontier:"):
		push_error("Town smoke: production overview did not surface a practical build/recruit priority with readiness impact: %s." % overview)
		return false
	var catalog: Dictionary = shell.call("validation_action_catalog")
	var inspected_build := false
	for action in catalog.get("build", []):
		if not (action is Dictionary):
			continue
		var payload := "%s\n%s\n%s\n%s" % [
			String(action.get("button_label", "")),
			String(action.get("affordability_label", "")),
			String(action.get("impact_line", "")),
			String(action.get("recommendation_line", "")),
		]
		if payload.contains("|") and payload.contains("Defense/frontier:") and (
			payload.contains("Ready") or payload.contains("Trade") or payload.contains("Blocked")
		):
			inspected_build = true
			break
	if not inspected_build:
		push_error("Town smoke: build actions did not expose button status, impact, and recommendation payloads: %s." % [catalog.get("build", [])])
		return false
	var inspected_recruit := false
	for action in catalog.get("recruit", []):
		if not (action is Dictionary):
			continue
		var payload := "%s\n%s\n%s\n%s" % [
			String(action.get("button_label", "")),
			String(action.get("affordability_label", "")),
			String(action.get("impact_line", "")),
			String(action.get("recommendation_line", "")),
		]
		if payload.contains("|") and payload.contains("Defense/frontier:") and (
			payload.contains("Ready") or payload.contains("Trade") or payload.contains("Blocked")
		):
			inspected_recruit = true
			break
	if not inspected_recruit:
		push_error("Town smoke: recruit actions did not expose button status, impact, and recommendation payloads: %s." % [catalog.get("recruit", [])])
		return false
	for leak_token in ["build_category_weights", "final_score", "debug_reason", "raid_target_weights"]:
		if overview.contains(leak_token):
			push_error("Town smoke: next-step recommendation leaked internal strategy token %s: %s." % [leak_token, overview])
			return false
	return true

func _assert_town_build_readiness_cue(shell: Node) -> bool:
	if not shell.has_method("validation_snapshot"):
		push_error("Town smoke: shell is missing build-readiness validation hooks.")
		return false
	var snapshot: Dictionary = shell.call("validation_snapshot")
	var readiness: Dictionary = snapshot.get("build_readiness", {}) if snapshot.get("build_readiness", {}) is Dictionary else {}
	var text := "\n".join([
		String(snapshot.get("build_readiness_visible_text", "")),
		String(snapshot.get("build_readiness_tooltip_text", "")),
		String(snapshot.get("build_visible_text", "")),
		String(snapshot.get("build_tooltip_text", "")),
		String(readiness.get("best_order_label", "")),
		String(readiness.get("readiness", "")),
		String(readiness.get("why_it_matters", "")),
		String(readiness.get("next_step", "")),
	])
	for token in ["Build check:", "Build Readiness", "Town works:", "Best order:", "Readiness:", "Why it matters:", "Next practical action:", "Construction Ledger"]:
		if not text.contains(token):
			push_error("Town smoke: build readiness cue lost %s clarity: %s." % [token, text])
			return false
	if int(readiness.get("open_order_count", -1)) < 0 or int(readiness.get("built_count", -1)) < 0:
		push_error("Town smoke: build readiness cue did not expose stable visible counts: %s." % readiness)
		return false
	if not (
		text.contains("Ready")
		or text.contains("Trade")
		or text.contains("Blocked")
		or text.contains("no open")
	):
		push_error("Town smoke: build readiness cue does not explain ready, trade, blocked, or empty state: %s." % readiness)
		return false
	if not String(snapshot.get("build_visible_text", "")).contains("Build check:"):
		push_error("Town smoke: build readiness cue is not visible in the construction label: %s." % snapshot)
		return false
	for leak_token in ["build_category_weights", "final_priority", "base_value", "assignment_penalty", "final_score", "income_value", "growth_value", "pressure_value", "category_bonus", "raid_score", "debug_reason", "raid_target_weights", "ai_score", "weight"]:
		if text.contains(leak_token):
			push_error("Town smoke: build readiness cue leaked internal token %s: %s." % [leak_token, text])
			return false
	return true

func _assert_town_defense_check_cue(shell: Node) -> bool:
	if not shell.has_method("validation_snapshot"):
		push_error("Town smoke: shell is missing defense-check validation hooks.")
		return false
	var snapshot: Dictionary = shell.call("validation_snapshot")
	var defense_check: Dictionary = snapshot.get("defense_check", {}) if snapshot.get("defense_check", {}) is Dictionary else {}
	var text := "\n".join([
		String(snapshot.get("defense_check_visible_text", "")),
		String(snapshot.get("defense_check_tooltip_text", "")),
		String(snapshot.get("visible_production_overview", "")),
		String(snapshot.get("production_overview_tooltip_text", "")),
		String(defense_check.get("frontier_state", "")),
		String(defense_check.get("warning", "")),
		String(defense_check.get("garrison_line", "")),
		String(defense_check.get("threat_line", "")),
		String(defense_check.get("next_step", "")),
	])
	for token in ["Defense check:", "Defense Check", "Readiness:", "Frontier state:", "Warning:", "Garrison:", "Threat watch:", "Next practical action:"]:
		if not text.contains(token):
			push_error("Town smoke: defense check cue lost %s clarity: %s." % [token, text])
			return false
	if not String(snapshot.get("visible_production_overview", "")).contains("Defense check:"):
		push_error("Town smoke: defense check cue is not visible in the command overview: %s." % snapshot)
		return false
	if int(defense_check.get("readiness", -1)) <= 0 or int(defense_check.get("base_readiness", -1)) <= 0:
		push_error("Town smoke: defense check cue did not expose stable readiness counts: %s." % defense_check)
		return false
	if String(defense_check.get("state", "")) not in ["steady", "front", "occupied", "reduced", "none"]:
		push_error("Town smoke: defense check cue exposed an unexpected state: %s." % defense_check)
		return false
	for leak_token in ["build_category_weights", "final_priority", "base_value", "assignment_penalty", "final_score", "income_value", "growth_value", "pressure_value", "category_bonus", "raid_score", "debug_reason", "raid_target_weights", "ai_score", "weight"]:
		if text.contains(leak_token):
			push_error("Town smoke: defense check cue leaked internal token %s: %s." % [leak_token, text])
			return false
	return true

func _assert_town_trade_readiness_cue(shell: Node) -> bool:
	if not shell.has_method("validation_snapshot"):
		push_error("Town smoke: shell is missing trade-readiness validation hooks.")
		return false
	var snapshot: Dictionary = shell.call("validation_snapshot")
	var readiness: Dictionary = snapshot.get("market_readiness", {}) if snapshot.get("market_readiness", {}) is Dictionary else {}
	var text := "\n".join([
		String(snapshot.get("market_readiness_visible_text", "")),
		String(snapshot.get("market_readiness_tooltip_text", "")),
		String(snapshot.get("market_visible_text", "")),
		String(snapshot.get("market_tooltip_text", "")),
		String(readiness.get("best_order_label", "")),
		String(readiness.get("readiness", "")),
		String(readiness.get("why_it_matters", "")),
		String(readiness.get("next_step", "")),
	])
	for token in ["Trade check:", "Trade Readiness", "Exchange orders:", "Best order:", "Readiness:", "Why it matters:", "Next practical action:", "Exchange Hall"]:
		if not text.contains(token):
			push_error("Town smoke: trade readiness cue lost %s clarity: %s." % [token, text])
			return false
	if int(readiness.get("listed_order_count", -1)) < 0 or int(readiness.get("ready_order_count", -1)) < 0 or int(readiness.get("blocked_order_count", -1)) < 0:
		push_error("Town smoke: trade readiness cue did not expose stable visible counts: %s." % readiness)
		return false
	if not (
		text.contains("Ready")
		or text.contains("Blocked")
		or text.contains("no market")
		or text.contains("no exchange")
	):
		push_error("Town smoke: trade readiness cue does not explain ready, blocked, or absent exchange state: %s." % readiness)
		return false
	if not String(snapshot.get("market_visible_text", "")).contains("Trade check:"):
		push_error("Town smoke: trade readiness cue is not visible in the market label: %s." % snapshot)
		return false
	for leak_token in ["build_category_weights", "final_priority", "base_value", "assignment_penalty", "final_score", "income_value", "growth_value", "pressure_value", "category_bonus", "raid_score", "debug_reason", "raid_target_weights", "ai_score", "weight"]:
		if text.contains(leak_token):
			push_error("Town smoke: trade readiness cue leaked internal token %s: %s." % [leak_token, text])
			return false
	return true

func _assert_town_field_handoff_recap_contract(shell: Node) -> bool:
	if not shell.has_method("validation_snapshot"):
		push_error("Town smoke: shell is missing town handoff validation hooks.")
		return false
	var snapshot: Dictionary = shell.call("validation_snapshot")
	var handoff: Dictionary = snapshot.get("town_handoff", {}) if snapshot.get("town_handoff", {}) is Dictionary else {}
	var handoff_text := "\n".join([
		String(snapshot.get("town_handoff_visible_text", "")),
		String(snapshot.get("town_handoff_tooltip_text", "")),
		String(snapshot.get("visible_consequence_text", "")),
		String(snapshot.get("consequence_tooltip_text", "")),
		String(handoff.get("affected", "")),
		String(handoff.get("why_it_matters", "")),
		String(handoff.get("next_step", "")),
	])
	for token in ["Handoff:", "Town Handoff", "Affected:", "Why it matters:", "Next practical action:", "Riverwatch Hold", "field route"]:
		if not handoff_text.contains(token):
			push_error("Town smoke: town handoff recap lost %s clarity: %s." % [token, handoff_text])
			return false
	for key in ["affected", "why_it_matters", "next_step", "visible_text", "tooltip_text"]:
		if String(handoff.get(key, "")) == "":
			push_error("Town smoke: town handoff recap is missing structured %s: %s." % [key, handoff])
			return false
	for leak_token in ["final_priority", "base_value", "assignment_penalty", "final_score", "income_value", "growth_value", "pressure_value", "category_bonus", "raid_score", "debug_reason", "raid_target_weights"]:
		if handoff_text.contains(leak_token):
			push_error("Town smoke: town handoff recap leaked internal strategy token %s: %s." % [leak_token, handoff_text])
			return false
	return true

func _assert_town_departure_confirmation_contract(shell: Node) -> bool:
	if not shell.has_method("validation_snapshot"):
		push_error("Town smoke: shell is missing town departure confirmation validation hooks.")
		return false
	var snapshot: Dictionary = shell.call("validation_snapshot")
	var departure: Dictionary = snapshot.get("town_departure_confirmation", {}) if snapshot.get("town_departure_confirmation", {}) is Dictionary else {}
	var departure_text := "\n".join([
		String(snapshot.get("town_departure_visible_text", "")),
		String(snapshot.get("leave_button_text", "")),
		String(snapshot.get("leave_button_tooltip_text", "")),
		String(departure.get("town_readiness", "")),
		String(departure.get("affected", "")),
		String(departure.get("why_it_matters", "")),
		String(departure.get("next_step", "")),
	])
	for token in ["Ready check:", "Departure Check", "Town readiness:", "Next practical action:", "Return to Field"]:
		if not departure_text.contains(token):
			push_error("Town smoke: town departure confirmation lost %s clarity: %s." % [token, departure_text])
			return false
	if String(departure.get("button_label", "")) != "Return to Field" or String(snapshot.get("leave_button_text", "")) != "Return to Field":
		push_error("Town smoke: authoritative and live departure labels are not exact Return to Field commands: %s." % snapshot)
		return false
	for key in ["button_label", "visible_text", "tooltip_text", "town_readiness", "affected", "why_it_matters", "next_step"]:
		if String(departure.get(key, "")) == "":
			push_error("Town smoke: departure confirmation is missing structured %s: %s." % [key, departure])
			return false
	var decision_text := String(departure.get("visible_text", "")) + "\n" + String(departure.get("next_step", ""))
	if not (decision_text.to_lower().contains("field") or decision_text.to_lower().contains("response order")):
		push_error("Town smoke: departure confirmation did not help decide town action, field route, or end turn: %s." % departure_text)
		return false
	if String(departure.get("visible_text", "")) != "Ready check: response order is open before returning to the field." or int(departure.get("ready_response_action_count", 0)) <= 0:
		push_error("Town smoke: ready response order did not retain departure-copy priority: %s." % departure)
		return false
	if not _assert_town_departure_movement_copy_matrix(shell):
		return false
	for forbidden in ["Leave / End Turn", "leave and end turn"]:
		if departure_text.contains(forbidden):
			push_error("Town smoke: departure copy retained the misleading combined command %s: %s." % [forbidden, departure_text])
			return false
	for leak_token in ["final_priority", "base_value", "assignment_penalty", "final_score", "income_value", "growth_value", "pressure_value", "category_bonus", "raid_score", "debug_reason", "raid_target_weights"]:
		if departure_text.contains(leak_token):
			push_error("Town smoke: departure confirmation leaked internal strategy token %s: %s." % [leak_token, departure_text])
			return false
	return true

func _assert_town_departure_movement_copy_matrix(shell: Node) -> bool:
	var session = SessionState.ensure_active_session()
	var towns_before: Array = session.overworld.get("towns", []).duplicate(true)
	var resources_before: Dictionary = session.overworld.get("resources", {}).duplicate(true)
	var movement_before: Dictionary = session.overworld.get("movement", {}).duplicate(true)
	var hero_before: Dictionary = session.overworld.get("hero", {}).duplicate(true)
	var player_heroes_before: Array = session.overworld.get("player_heroes", []).duplicate(true)
	var active_town_id := String(TownRules.get_active_town(session).get("placement_id", ""))

	var towns: Array = session.overworld.get("towns", [])
	for index in range(towns.size()):
		var town = towns[index]
		if not (town is Dictionary) or String(town.get("placement_id", "")) != active_town_id:
			continue
		var recovery: Dictionary = town.get("recovery", {}).duplicate(true) if town.get("recovery", {}) is Dictionary else {}
		recovery["pressure"] = 0
		town["recovery"] = recovery
		towns[index] = town
		break
	session.overworld["towns"] = towns
	var empty_resources: Dictionary = session.overworld.get("resources", {}).duplicate(true)
	for resource_id in empty_resources.keys():
		empty_resources[resource_id] = 0
	session.overworld["resources"] = empty_resources

	var move_max := int(hero_before.get("movement", {}).get("max", movement_before.get("max", 0)))
	_set_town_departure_test_movement(session, move_max, move_max)
	shell.call("validation_force_refresh")
	var remaining_snapshot: Dictionary = shell.call("validation_snapshot")
	var remaining: Dictionary = remaining_snapshot.get("town_departure_confirmation", {}) if remaining_snapshot.get("town_departure_confirmation", {}) is Dictionary else {}
	var expected_remaining := "Ready check: finish town orders, then return to the field with %d/%d move." % [move_max, move_max]
	var cached_remaining_view_state: Dictionary = shell.call(
		"_active_town_entity_view_state",
		TownRules.get_active_town(session),
		true
	)
	var cached_remaining: Dictionary = cached_remaining_view_state.get("departure", {}) if cached_remaining_view_state.get("departure", {}) is Dictionary else {}
	if int(remaining.get("ready_response_action_count", -1)) != 0 \
			or String(remaining.get("button_label", "")) != "Return to Field" \
			or String(remaining.get("visible_text", "")) != expected_remaining \
			or String(cached_remaining.get("button_label", "")) != "Return to Field" \
			or String(cached_remaining.get("visible_text", "")) != expected_remaining \
			or String(remaining_snapshot.get("leave_button_text", "")) != "Return to Field" \
			or String(remaining_snapshot.get("leave_button_tooltip_text", "")) != String(remaining.get("tooltip_text", "")):
		_restore_town_departure_test_state(session, towns_before, resources_before, movement_before, hero_before, player_heroes_before, shell)
		push_error("Town smoke: authoritative/cache/live remaining-movement departure copy diverged: expected=%s authoritative=%s cached=%s." % [expected_remaining, remaining, cached_remaining])
		return false

	_set_town_departure_test_movement(session, 0, move_max)
	shell.call("validation_force_refresh")
	var exhausted_snapshot: Dictionary = shell.call("validation_snapshot")
	var exhausted: Dictionary = exhausted_snapshot.get("town_departure_confirmation", {}) if exhausted_snapshot.get("town_departure_confirmation", {}) is Dictionary else {}
	var expected_exhausted := "Ready check: movement is spent; return to the field, then choose End Turn."
	var cached_exhausted_view_state: Dictionary = shell.call(
		"_active_town_entity_view_state",
		TownRules.get_active_town(session),
		true
	)
	var cached_exhausted: Dictionary = cached_exhausted_view_state.get("departure", {}) if cached_exhausted_view_state.get("departure", {}) is Dictionary else {}
	if int(exhausted.get("ready_response_action_count", -1)) != 0 \
			or String(exhausted.get("button_label", "")) != "Return to Field" \
			or String(exhausted.get("visible_text", "")) != expected_exhausted \
			or String(cached_exhausted.get("button_label", "")) != "Return to Field" \
			or String(cached_exhausted.get("visible_text", "")) != expected_exhausted \
			or String(exhausted_snapshot.get("leave_button_text", "")) != "Return to Field" \
			or String(exhausted_snapshot.get("leave_button_tooltip_text", "")) != String(exhausted.get("tooltip_text", "")):
		_restore_town_departure_test_state(session, towns_before, resources_before, movement_before, hero_before, player_heroes_before, shell)
		push_error("Town smoke: authoritative/cache/live exhausted-movement departure copy diverged: expected=%s authoritative=%s cached=%s." % [expected_exhausted, exhausted, cached_exhausted])
		return false
	for text in [String(remaining.get("button_label", "")), String(remaining.get("visible_text", "")), String(exhausted.get("button_label", "")), String(exhausted.get("visible_text", ""))]:
		if text.contains("Leave / End Turn") or text.to_lower().contains("leave and end turn"):
			_restore_town_departure_test_state(session, towns_before, resources_before, movement_before, hero_before, player_heroes_before, shell)
			push_error("Town smoke: movement copy matrix retained a misleading combined departure command: %s." % text)
			return false

	_restore_town_departure_test_state(session, towns_before, resources_before, movement_before, hero_before, player_heroes_before, shell)
	return true

func _set_town_departure_test_movement(session, current: int, maximum: int) -> void:
	session.overworld["movement"] = {"current": current, "max": maximum}
	var hero: Dictionary = session.overworld.get("hero", {}).duplicate(true)
	hero["movement"] = {"current": current, "max": maximum}
	session.overworld["hero"] = hero
	var heroes: Array = session.overworld.get("player_heroes", [])
	for index in range(heroes.size()):
		var candidate = heroes[index]
		if candidate is Dictionary and String(candidate.get("id", "")) == String(session.overworld.get("active_hero_id", "")):
			candidate["movement"] = {"current": current, "max": maximum}
			heroes[index] = candidate
	session.overworld["player_heroes"] = heroes

func _restore_town_departure_test_state(session, towns: Array, resources: Dictionary, movement: Dictionary, hero: Dictionary, player_heroes: Array, shell: Node) -> void:
	session.overworld["towns"] = towns
	session.overworld["resources"] = resources
	session.overworld["movement"] = movement
	session.overworld["hero"] = hero
	session.overworld["player_heroes"] = player_heroes
	shell.call("validation_force_refresh")

func _assert_town_return_handoff_payload(handoff: Dictionary) -> bool:
	var handoff_text := "\n".join([
		String(handoff.get("visible_text", "")),
		String(handoff.get("tooltip_text", "")),
		String(handoff.get("town_name", "")),
		String(handoff.get("field_position", "")),
		String(handoff.get("movement_line", "")),
		String(handoff.get("next_step", "")),
		JSON.stringify(handoff.get("post_action_recap", {})),
	])
	for token in ["Town return:", "Town Return Handoff", "Returned:", "Field position:", "Movement:", "Day:", "Next practical action:", "Riverwatch Hold", "Move"]:
		if not handoff_text.contains(token):
			push_error("Town smoke: town return handoff payload lost %s clarity: %s." % [token, handoff_text])
			return false
	var recap: Dictionary = handoff.get("post_action_recap", {}) if handoff.get("post_action_recap", {}) is Dictionary else {}
	for key in ["happened", "affected", "why_it_matters", "next_step", "cue_text", "tooltip_text"]:
		if String(recap.get(key, "")) == "":
			push_error("Town smoke: town return handoff recap is missing structured %s: %s." % [key, recap])
			return false
	for leak_token in ["final_priority", "base_value", "assignment_penalty", "final_score", "income_value", "growth_value", "pressure_value", "category_bonus", "raid_score", "debug_reason", "raid_target_weights", "ai_score", "weight"]:
		if handoff_text.contains(leak_token):
			push_error("Town smoke: town return handoff leaked internal strategy token %s: %s." % [leak_token, handoff_text])
			return false
	return true

func _assert_overworld_town_return_handoff(session, handoff_seed: Dictionary) -> bool:
	session.game_state = "overworld"
	OverworldRules.clear_active_town_visit(session)
	session.flags["town_return_handoff"] = handoff_seed.duplicate(true)
	SessionState.set_active_session(session)
	var overworld_shell = load("res://scenes/overworld/OverworldShell.tscn").instantiate()
	add_child(overworld_shell)
	await get_tree().process_frame
	await get_tree().process_frame
	if not overworld_shell.has_method("validation_snapshot"):
		push_error("Town smoke: overworld shell does not expose validation snapshot for town return handoff.")
		overworld_shell.queue_free()
		await get_tree().process_frame
		return false
	var snapshot: Dictionary = overworld_shell.call("validation_snapshot")
	var handoff: Dictionary = snapshot.get("field_return_handoff", {}) if snapshot.get("field_return_handoff", {}) is Dictionary else {}
	var feedback: Dictionary = snapshot.get("action_feedback", {}) if snapshot.get("action_feedback", {}) is Dictionary else {}
	var return_text := "\n".join([
		String(snapshot.get("field_return_handoff_visible_text", "")),
		String(snapshot.get("field_return_handoff_tooltip_text", "")),
		String(snapshot.get("event_visible_text", "")),
		String(snapshot.get("event_tooltip_text", "")),
		String(snapshot.get("map_cue_text", "")),
		String(snapshot.get("map_cue_tooltip_text", "")),
		String(feedback.get("full_text", feedback.get("text", ""))),
		JSON.stringify(handoff),
	])
	overworld_shell.queue_free()
	await get_tree().process_frame
	for token in ["Town return:", "Town Return Handoff", "Returned:", "Field position:", "Movement:", "Day:", "Next practical action:", "Current Turn Context", "Riverwatch Hold", "Move"]:
		if not return_text.contains(token):
			push_error("Town smoke: overworld town-return cue lost %s clarity: %s." % [token, return_text])
			return false
	if String(feedback.get("kind", "")) != "town":
		push_error("Town smoke: town return handoff did not surface as town action feedback: %s." % snapshot)
		return false
	if not String(snapshot.get("map_cue_text", "")).contains("Town:"):
		push_error("Town smoke: map cue did not visibly surface the town return handoff: %s." % snapshot)
		return false
	for leak_token in ["final_priority", "base_value", "assignment_penalty", "final_score", "income_value", "growth_value", "pressure_value", "category_bonus", "raid_score", "debug_reason", "raid_target_weights", "ai_score", "weight"]:
		if return_text.contains(leak_token):
			push_error("Town smoke: overworld town-return cue leaked internal token %s." % leak_token)
			return false
	return true

func _assert_town_order_target_handoff_contract(shell: Node) -> bool:
	if not shell.has_method("validation_snapshot"):
		push_error("Town smoke: shell is missing town order target handoff validation hooks.")
		return false
	var snapshot: Dictionary = shell.call("validation_snapshot")
	var order_target: Dictionary = snapshot.get("town_order_target_handoff", {}) if snapshot.get("town_order_target_handoff", {}) is Dictionary else {}
	var target_text := "\n".join([
		String(snapshot.get("town_order_target_visible_text", "")),
		String(snapshot.get("town_order_target_tooltip_text", "")),
		String(snapshot.get("visible_consequence_text", "")),
		String(snapshot.get("consequence_tooltip_text", "")),
		String(order_target.get("target_label", "")),
		String(order_target.get("ui_surface", "")),
		String(order_target.get("readiness", "")),
		String(order_target.get("why_it_matters", "")),
		String(order_target.get("next_step", "")),
	])
	for token in ["Order target:", "Town Order Target", "Target:", "Lane:", "Where:", "Readiness:", "Why it matters:", "Next practical action:"]:
		if not target_text.contains(token):
			push_error("Town smoke: town order target handoff lost %s clarity: %s." % [token, target_text])
			return false
	if not String(snapshot.get("visible_consequence_text", "")).contains("Order target:"):
		push_error("Town smoke: order target handoff is not visible in the town dispatch rail: %s." % snapshot)
		return false
	for key in ["action_id", "lane", "target_label", "ui_surface", "readiness", "why_it_matters", "next_step", "visible_text", "tooltip_text"]:
		if String(order_target.get(key, "")) == "":
			push_error("Town smoke: town order target handoff is missing structured %s: %s." % [key, order_target])
			return false
	var ui_surface := String(order_target.get("ui_surface", ""))
	if not (ui_surface.contains("Build") or ui_surface.contains("Muster") or ui_surface.contains("Spells") or ui_surface.contains("Trade") or ui_surface.contains("Log") or ui_surface.contains("Town orders")):
		push_error("Town smoke: town order target handoff did not name a usable town surface: %s." % order_target)
		return false
	for public_token in ["Ready", "Blocked", "exchange", "Press", "Use"]:
		if target_text.contains(public_token):
			for leak_token in ["build_category_weights", "final_priority", "base_value", "assignment_penalty", "final_score", "income_value", "growth_value", "pressure_value", "category_bonus", "raid_score", "debug_reason", "raid_target_weights", "ai_score", "weight"]:
				if target_text.contains(leak_token):
					push_error("Town smoke: town order target handoff leaked internal token %s: %s." % [leak_token, target_text])
					return false
			return true
	push_error("Town smoke: town order target handoff did not expose a public readiness or action cue: %s." % target_text)
	return false

func _assert_town_production_overview(shell: Node) -> bool:
	if not shell.has_method("validation_snapshot"):
		push_error("Town smoke: town shell does not expose validation snapshot.")
		return false
	var overview_label: Label = shell.get_node_or_null("%ProductionOverview")
	if overview_label == null:
		push_error("Town smoke: production overview label did not load.")
		return false
	var snapshot: Dictionary = shell.call("validation_snapshot")
	var overview := String(snapshot.get("production_overview", ""))
	var visible_overview := String(snapshot.get("visible_production_overview", overview_label.text))
	if overview_label.text != visible_overview:
		push_error("Town smoke: production overview snapshot does not match the visible label: visible=%s snapshot=%s." % [overview_label.text, snapshot])
		return false
	for token in ["Owner ", "Faction ", "Income/day", "Works ", "Muster ", "Weekly ", "Ready now", "Next:", "Practical priority:"]:
		if not overview.contains(token):
			push_error("Town smoke: production overview is missing %s: %s." % [token, overview])
			return false
	if not visible_overview.contains("Income/day") or not visible_overview.contains("Next:"):
		push_error("Town smoke: visible production overview lost income or next-action clarity: %s." % visible_overview)
		return false
	return true

func _assert_town_stack_inspection_contract(shell: Node) -> bool:
	if not shell.has_method("validation_snapshot") or not shell.has_method("validation_action_catalog"):
		push_error("Town smoke: town shell is missing stack inspection validation hooks.")
		return false
	var snapshot: Dictionary = shell.call("validation_snapshot")
	var town_text := "\n".join([
		String(snapshot.get("army_text", "")),
		String(snapshot.get("army_visible_text", "")),
		String(snapshot.get("defense_text", "")),
		String(snapshot.get("defense_visible_text", "")),
		String(snapshot.get("recruit_text", "")),
		String(snapshot.get("recruit_visible_text", "")),
	])
	for token in ["Strength", "HP", "T", "Ready", "Defense readiness:", "Why:", "Next:", "Readiness"]:
		if not town_text.contains(token):
			push_error("Town smoke: town stack inspection text is missing %s: %s." % [token, town_text])
			return false
	var catalog: Dictionary = shell.call("validation_action_catalog")
	for action in catalog.get("recruit", []):
		if action is Dictionary and String(action.get("summary", "")).contains("Strength") and String(action.get("summary", "")).contains("HP"):
			return true
	push_error("Town smoke: recruit action tooltips do not expose stack role/health/strength: %s." % [catalog.get("recruit", [])])
	return false

func _assert_battle_magic_inspection_contract(shell: Node) -> bool:
	if not shell.has_method("validation_snapshot"):
		push_error("Battle smoke: battle shell does not expose magic validation snapshot.")
		return false
	var snapshot: Dictionary = shell.call("validation_snapshot")
	var magic_text := "\n".join([
		String(snapshot.get("spellbook_text", "")),
		String(snapshot.get("spellbook_tooltip_text", "")),
		String(snapshot.get("spell_timing_text", "")),
		String(snapshot.get("spell_timing_tooltip_text", "")),
	])
	for token in ["Battle Spells", "Mana", "Cinder Burst", "Battle Strike", "Stone Veil", "Battle Ward", "Cost", "Use:"]:
		if not magic_text.contains(token):
			push_error("Battle smoke: spellbook/timing panels lost practical magic token %s: %s." % [token, magic_text])
			return false
	var spell_actions: Array = snapshot.get("spell_actions", [])
	var inspected_action := false
	for action in spell_actions:
		if action is Dictionary:
			var payload := "%s\n%s\n%s\n%s\n%s" % [
				String(action.get("label", "")),
				String(action.get("category", "")),
				String(action.get("effect", "")),
				String(action.get("best_use", "")),
				String(action.get("summary", "")),
			]
			if payload.contains("Battle ") and payload.contains("Cost") and payload.contains("Target") and String(action.get("best_use", "")) != "":
				inspected_action = true
				break
	if not inspected_action:
		push_error("Battle smoke: spell action tooltips do not expose category, cost, target, effect, and use context: %s." % [spell_actions])
		return false
	var button_surfaces: Array = snapshot.get("spell_action_button_surfaces", [])
	var inspected_button := false
	var button_text := ""
	for surface in button_surfaces:
		if not (surface is Dictionary):
			continue
		var rendered := "%s\n%s" % [
			String(surface.get("text", "")),
			String(surface.get("tooltip", "")),
		]
		button_text += "\n%s" % rendered
		if (
			(rendered.contains("| Ready") or rendered.contains("| Blocked"))
			and rendered.contains("Spell action:")
			and rendered.contains("Readiness:")
			and rendered.contains("Target:")
			and rendered.contains("Cost:")
			and rendered.contains("Use:")
			and rendered.contains("Effect:")
			and rendered.contains("Next:")
		):
			inspected_button = true
	if not inspected_button:
		push_error("Battle smoke: rendered spell buttons do not expose visible readiness and action tooltip context: %s." % button_surfaces)
		return false
	for leak_token in ["final_priority", "base_value", "assignment_penalty", "final_score", "income_value", "growth_value", "pressure_value", "category_bonus", "raid_score", "debug_reason", "raid_target_weights", "ai_score", "weight"]:
		if button_text.contains(leak_token):
			push_error("Battle smoke: spell action cue leaked internal token %s: %s." % [leak_token, button_text])
			return false
	return true

func _assert_battle_ability_status_action_consequence_contract(shell: Node) -> bool:
	if not shell.has_method("validation_snapshot"):
		push_error("Battle smoke: battle shell does not expose action consequence validation snapshot.")
		return false
	var snapshot: Dictionary = shell.call("validation_snapshot")
	var active_text := "\n".join([
		String(snapshot.get("active_ability_role", "")),
		String(snapshot.get("active_status_pressure", "")),
		String(snapshot.get("active_target_range", "")),
		String(snapshot.get("target_context", "")),
	])
	for token in ["Role:", "Status pressure:", "Target/range:"]:
		if not active_text.contains(token):
			push_error("Battle smoke: active battle focus lost %s clarity: %s." % [token, active_text])
			return false
	var action_surface: Dictionary = snapshot.get("action_surface", {})
	var inspected_ready_action := false
	for action_id in ["shoot", "strike", "advance", "defend"]:
		var action: Dictionary = action_surface.get(action_id, {}) if action_surface.get(action_id, {}) is Dictionary else {}
		var payload := "\n".join([
			String(action.get("readiness", "")),
			String(action.get("target", "")),
			String(action.get("range", "")),
			String(action.get("why", "")),
			String(action.get("consequence", "")),
			String(action.get("confirmation", "")),
			String(action.get("tooltip", "")),
		])
		for token in ["Target/range:", "Why:", "Consequence:", "Confirm:"]:
			if not payload.contains(token):
				push_error("Battle smoke: %s action tooltip/payload lost %s clarity: %s." % [action_id, token, payload])
				return false
		if not bool(action.get("disabled", true)) and payload.contains("Ready") and String(action.get("why", "")) != "" and String(action.get("consequence", "")) != "" and String(action.get("confirmation", "")) != "":
			inspected_ready_action = true
	if not inspected_ready_action:
		push_error("Battle smoke: no ready action exposed readiness, why, consequence, and confirmation payloads: %s." % [action_surface])
		return false
	var button_tooltips := "\n".join([
		String(snapshot.get("advance_tooltip", "")),
		String(snapshot.get("strike_tooltip", "")),
		String(snapshot.get("shoot_tooltip", "")),
		String(snapshot.get("defend_tooltip", "")),
	])
	for token in ["Target/range:", "Why:", "Consequence:", "Confirm:"]:
		if not button_tooltips.contains(token):
			push_error("Battle smoke: live action button tooltips lost %s clarity: %s." % [token, button_tooltips])
			return false
	var order_button_surfaces: Array = snapshot.get("battle_order_button_surfaces", [])
	if order_button_surfaces.size() != 4:
		push_error("Battle smoke: non-spell order button cue snapshot should cover four stack orders: %s." % order_button_surfaces)
		return false
	var inspected_order_button := false
	var order_button_text := ""
	for surface in order_button_surfaces:
		if not (surface is Dictionary):
			continue
		var rendered := "%s\n%s" % [
			String(surface.get("text", "")),
			String(surface.get("tooltip", "")),
		]
		order_button_text += "\n%s" % rendered
		if (
			(rendered.contains("| Ready") or rendered.contains("| Blocked"))
			and rendered.contains("Order cue:")
			and rendered.contains("Readiness:")
			and rendered.contains("Target:")
			and rendered.contains("Range:")
			and rendered.contains("Why:")
			and rendered.contains("Next:")
		):
			inspected_order_button = true
	if not inspected_order_button:
		push_error("Battle smoke: rendered non-spell order buttons do not expose visible readiness and order tooltip context: %s." % order_button_surfaces)
		return false
	var action_guidance := String(snapshot.get("action_guidance", ""))
	var visible_action_guidance := String(snapshot.get("visible_action_guidance", ""))
	var manual_cue_text := "%s\n%s" % [action_guidance, visible_action_guidance]
	if not manual_cue_text.contains("Try:") or not manual_cue_text.contains("click"):
		push_error("Battle smoke: battle order rail lost the compact manual-play action cue: %s." % snapshot)
		return false
	if not visible_action_guidance.contains("Suggested order:"):
		push_error("Battle smoke: scored order consequence is not visible in the order rail: %s." % snapshot)
		return false
	if visible_action_guidance.contains("Try:") or visible_action_guidance.contains("click green"):
		push_error("Battle smoke: visible order rail regressed to tutorial instructions instead of live consequence feedback: %s." % snapshot)
		return false
	var target_handoff: Dictionary = snapshot.get("target_handoff", {}) if snapshot.get("target_handoff", {}) is Dictionary else {}
	var target_handoff_text := "\n".join([
		String(snapshot.get("target_handoff_visible_text", "")),
		String(snapshot.get("target_handoff_tooltip_text", "")),
		String(target_handoff.get("focus", "")),
		String(target_handoff.get("board_click", "")),
		String(target_handoff.get("cycle", "")),
		String(target_handoff.get("move", "")),
		visible_action_guidance,
	])
	for token in ["Target handoff:", "Target Handoff", "Focus:", "Board click:", "Cycle:", "Try:"]:
		if not target_handoff_text.contains(token):
			push_error("Battle smoke: battle target handoff cue lost %s clarity: %s." % [token, target_handoff_text])
			return false
	if String(target_handoff.get("focus", "")) == "" or String(target_handoff.get("board_click", "")) == "" or String(target_handoff.get("cycle", "")) == "":
		push_error("Battle smoke: target handoff payload is missing focus, board-click, or cycle context: %s." % target_handoff)
		return false
	var intent_visible_text := String(snapshot.get("intent_forecast_visible_text", ""))
	if intent_visible_text == "" or not visible_action_guidance.contains(intent_visible_text):
		push_error("Battle smoke: visible suggested order omits its live expected consequence: %s." % snapshot)
		return false
	var confirmation: Dictionary = snapshot.get("action_confirmation", {}) if snapshot.get("action_confirmation", {}) is Dictionary else {}
	var confirmation_text := "\n".join([
		String(confirmation.get("visible_text", "")),
		String(confirmation.get("tooltip_text", "")),
		String(snapshot.get("action_confirmation_text", "")),
		String(snapshot.get("action_confirmation_tooltip_text", "")),
		visible_action_guidance,
	])
	for token in ["Ready check:", "confirm", "order ends this stack", "initiative advances"]:
		if not confirmation_text.contains(token):
			push_error("Battle smoke: battle action confirmation lost %s clarity: %s." % [token, confirmation_text])
			return false
	if String(confirmation.get("button_label", "")) == "" or String(confirmation.get("next_step", "")) == "":
		push_error("Battle smoke: battle action confirmation payload is missing button/next-step fields: %s." % confirmation)
		return false
	var roster_text := "\n".join(snapshot.get("player_roster", []) + snapshot.get("enemy_roster", []))
	if not roster_text.contains("Role ") or not roster_text.contains("Status "):
		push_error("Battle smoke: roster lines do not expose ability role and status pressure text: %s." % roster_text)
		return false
	var consequence_payload: Dictionary = snapshot.get("active_consequence_payload", {}) if snapshot.get("active_consequence_payload", {}) is Dictionary else {}
	if String(consequence_payload.get("active_ability_role", "")) == "" or String(consequence_payload.get("status_pressure", "")) == "" or String(consequence_payload.get("target_range", "")) == "" or String(consequence_payload.get("confirmation", "")) == "":
		push_error("Battle smoke: active consequence payload is missing ability/status/range fields: %s." % [consequence_payload])
		return false
	for leak_token in ["final_priority", "debug_reason", "score", "ai_score", "weight"]:
		if active_text.contains(leak_token) or button_tooltips.contains(leak_token) or order_button_text.contains(leak_token) or manual_cue_text.contains(leak_token) or target_handoff_text.contains(leak_token) or confirmation_text.contains(leak_token) or roster_text.contains(leak_token):
			push_error("Battle smoke: battle consequence UI leaked internal token %s." % leak_token)
			return false
	return true

func _assert_battle_stack_check_cue_contract(shell: Node) -> bool:
	if not shell.has_method("validation_snapshot"):
		push_error("Battle smoke: shell is missing stack-check validation snapshot.")
		return false
	var snapshot: Dictionary = shell.call("validation_snapshot")
	var stack_check: Dictionary = snapshot.get("stack_check", {}) if snapshot.get("stack_check", {}) is Dictionary else {}
	var stack_text := "\n".join([
		String(stack_check.get("visible_text", "")),
		String(stack_check.get("tooltip_text", "")),
		String(stack_check.get("active", "")),
		String(stack_check.get("side", "")),
		String(stack_check.get("role", "")),
		String(stack_check.get("status", "")),
		String(stack_check.get("target_range", "")),
		String(stack_check.get("readiness", "")),
		String(stack_check.get("order", "")),
		String(stack_check.get("next_step", "")),
		String(snapshot.get("stack_check_visible_text", "")),
		String(snapshot.get("stack_check_tooltip_text", "")),
		String(snapshot.get("active_visible_text", "")),
		String(snapshot.get("active_tooltip_text", "")),
	])
	for token in ["Stack check:", "Stack Check", "Active:", "Role:", "Status pressure:", "Target/range:", "Readiness:", "Current order:", "Next practical action:", "Inspection:", "does not spend an action"]:
		if not stack_text.contains(token):
			push_error("Battle smoke: stack-check cue lost %s clarity: %s." % [token, stack_text])
			return false
	if String(stack_check.get("active", "")) == "" or String(stack_check.get("role", "")) == "" or String(stack_check.get("next_step", "")) == "":
		push_error("Battle smoke: stack-check payload is missing active, role, or next-step context: %s." % stack_check)
		return false
	if not String(snapshot.get("active_visible_text", "")).contains("Stack check:"):
		push_error("Battle smoke: stack-check cue is not visible in the active stack rail: %s." % stack_text)
		return false
	for leak_token in ["final_priority", "base_value", "assignment_penalty", "final_score", "income_value", "growth_value", "pressure_value", "category_bonus", "raid_score", "debug_reason", "raid_target_weights", "ai_score", "weight"]:
		if stack_text.contains(leak_token):
			push_error("Battle smoke: stack-check cue leaked internal token %s: %s." % [leak_token, stack_text])
			return false
	return true

func _assert_battle_position_check_cue_contract(shell: Node) -> bool:
	if not shell.has_method("validation_snapshot"):
		push_error("Battle smoke: shell is missing position-check validation snapshot.")
		return false
	var snapshot: Dictionary = shell.call("validation_snapshot")
	var position_check: Dictionary = snapshot.get("position_check", {}) if snapshot.get("position_check", {}) is Dictionary else {}
	var position_text := "\n".join([
		String(position_check.get("visible_text", "")),
		String(position_check.get("tooltip_text", "")),
		String(position_check.get("active", "")),
		String(position_check.get("target", "")),
		String(position_check.get("reach", "")),
		String(position_check.get("movement", "")),
		String(position_check.get("readiness", "")),
		String(position_check.get("next_step", "")),
		String(snapshot.get("position_check_visible_text", "")),
		String(snapshot.get("position_check_tooltip_text", "")),
		String(snapshot.get("visible_action_guidance", "")),
	])
	for token in ["Position check:", "Battle Position Check", "Active stack:", "Selected target:", "Reach from current hex:", "Movement:", "Readiness:", "Next practical action:", "Inspection:", "does not move"]:
		if not position_text.contains(token):
			push_error("Battle smoke: position-check cue lost %s clarity: %s." % [token, position_text])
			return false
	if String(position_check.get("active", "")) == "" or String(position_check.get("target", "")) == "" or String(position_check.get("next_step", "")) == "":
		push_error("Battle smoke: position-check payload is missing active, target, or next-step context: %s." % position_check)
		return false
	if int(position_check.get("movement_option_count", -1)) < 0 or int(position_check.get("legal_target_count", -1)) < 0:
		push_error("Battle smoke: position-check payload is missing non-negative movement/target counts: %s." % position_check)
		return false
	if not String(snapshot.get("visible_action_guidance", "")).contains("Position check:"):
		push_error("Battle smoke: position-check cue is not visible in the footer action guide: %s." % snapshot)
		return false
	for leak_token in ["final_priority", "base_value", "assignment_penalty", "final_score", "income_value", "growth_value", "pressure_value", "category_bonus", "raid_score", "debug_reason", "raid_target_weights", "ai_score", "weight"]:
		if position_text.contains(leak_token):
			push_error("Battle smoke: position-check cue leaked internal token %s: %s." % [leak_token, position_text])
			return false
	return true

func _assert_battle_engagement_check_cue_contract(shell: Node) -> bool:
	if not shell.has_method("validation_snapshot"):
		push_error("Battle smoke: shell is missing engagement-check validation snapshot.")
		return false
	var snapshot: Dictionary = shell.call("validation_snapshot")
	var engagement_check: Dictionary = snapshot.get("engagement_check", {}) if snapshot.get("engagement_check", {}) is Dictionary else {}
	var engagement_text := "\n".join([
		String(engagement_check.get("visible_text", "")),
		String(engagement_check.get("tooltip_text", "")),
		String(engagement_check.get("active", "")),
		String(engagement_check.get("target", "")),
		String(engagement_check.get("order", "")),
		String(engagement_check.get("readiness", "")),
		String(engagement_check.get("order_readiness", "")),
		String(engagement_check.get("target_range", "")),
		String(engagement_check.get("consequence_preview", "")),
		String(engagement_check.get("next_step", "")),
		String(snapshot.get("engagement_check_visible_text", "")),
		String(snapshot.get("engagement_check_tooltip_text", "")),
		String(snapshot.get("target_visible_text", "")),
		String(snapshot.get("target_tooltip_text", "")),
	])
	for token in ["Engagement check:", "Battle Engagement Check", "Active stack:", "Selected target:", "Order readiness:", "Target/range:", "Consequence preview:", "Next practical action:", "Inspection:", "does not attack"]:
		if not engagement_text.contains(token):
			push_error("Battle smoke: engagement-check cue lost %s clarity: %s." % [token, engagement_text])
			return false
	if String(engagement_check.get("active", "")) == "" or String(engagement_check.get("target", "")) == "" or String(engagement_check.get("next_step", "")) == "":
		push_error("Battle smoke: engagement-check payload is missing active, target, or next-step context: %s." % engagement_check)
		return false
	if String(engagement_check.get("consequence_preview", "")) == "":
		push_error("Battle smoke: engagement-check payload is missing consequence preview context: %s." % engagement_check)
		return false
	if not String(snapshot.get("target_visible_text", "")).contains("Engagement check:"):
		push_error("Battle smoke: engagement-check cue is not visible in the target rail: %s." % snapshot)
		return false
	for leak_token in ["final_priority", "base_value", "assignment_penalty", "final_score", "income_value", "growth_value", "pressure_value", "category_bonus", "raid_score", "debug_reason", "raid_target_weights", "ai_score", "weight"]:
		if engagement_text.contains(leak_token):
			push_error("Battle smoke: engagement-check cue leaked internal token %s: %s." % [leak_token, engagement_text])
			return false
	return true

func _assert_battle_objective_check_cue_contract(shell: Node) -> bool:
	if not shell.has_method("validation_snapshot"):
		push_error("Battle smoke: shell is missing objective-check validation snapshot.")
		return false
	var snapshot: Dictionary = shell.call("validation_snapshot")
	var objective_check: Dictionary = snapshot.get("objective_check", {}) if snapshot.get("objective_check", {}) is Dictionary else {}
	var objective_text := "\n".join([
		String(objective_check.get("visible_text", "")),
		String(objective_check.get("tooltip_text", "")),
		String(objective_check.get("field", "")),
		String(objective_check.get("pressure", "")),
		String(objective_check.get("next_step", "")),
		String(objective_check.get("readiness", "")),
		String(objective_check.get("order", "")),
		String(snapshot.get("objective_check_visible_text", "")),
		String(snapshot.get("objective_check_tooltip_text", "")),
		String(snapshot.get("visible_action_guidance", "")),
	])
	for token in ["Objective check:", "Objective Check", "Field:", "Pressure:", "Readiness:", "Next practical action:", "Inspection:", "does not spend an action"]:
		if not objective_text.contains(token):
			push_error("Battle smoke: objective-check cue lost %s clarity: %s." % [token, objective_text])
			return false
	if String(objective_check.get("field", "")) == "" or String(objective_check.get("pressure", "")) == "" or String(objective_check.get("next_step", "")) == "":
		push_error("Battle smoke: objective-check payload is missing field, pressure, or next-step context: %s." % objective_check)
		return false
	if not String(snapshot.get("visible_action_guidance", "")).contains("Objective check:"):
		push_error("Battle smoke: objective-check cue is not visible in the footer action guide: %s." % snapshot)
		return false
	for leak_token in ["final_priority", "base_value", "assignment_penalty", "final_score", "income_value", "growth_value", "pressure_value", "category_bonus", "raid_score", "debug_reason", "raid_target_weights", "ai_score", "weight"]:
		if objective_text.contains(leak_token):
			push_error("Battle smoke: objective-check cue leaked internal token %s: %s." % [leak_token, objective_text])
			return false
	return true

func _assert_battle_exit_order_cue_contract(shell: Node) -> bool:
	if not shell.has_method("validation_snapshot"):
		push_error("Battle smoke: shell is missing exit-order cue validation snapshot.")
		return false
	var snapshot: Dictionary = shell.call("validation_snapshot")
	var exit_cues: Dictionary = snapshot.get("battle_exit_order_cues", {}) if snapshot.get("battle_exit_order_cues", {}) is Dictionary else {}
	var exit_text := "\n".join([
		String(exit_cues.get("visible_text", "")),
		String(exit_cues.get("route", "")),
		String(exit_cues.get("save", "")),
		String(exit_cues.get("retreat_tooltip", "")),
		String(exit_cues.get("surrender_tooltip", "")),
		String(snapshot.get("retreat_text", "")),
		String(snapshot.get("surrender_text", "")),
		String(snapshot.get("retreat_tooltip", "")),
		String(snapshot.get("surrender_tooltip", "")),
	])
	for token in ["Exit cue:", "Retreat", "Surrender", "army-wide battle exit order", "Route:", "returns to the field", "Save Battle first"]:
		if not exit_text.contains(token):
			push_error("Battle smoke: battle exit-order cue lost %s clarity: %s." % [token, exit_text])
			return false
	if String(exit_cues.get("retreat_state", "")) == "" or String(exit_cues.get("surrender_state", "")) == "":
		push_error("Battle smoke: exit-order cue is missing retreat/surrender readiness states: %s." % exit_cues)
		return false
	if not String(snapshot.get("retreat_tooltip", "")).contains("Exit cue:") or not String(snapshot.get("surrender_tooltip", "")).contains("Exit cue:"):
		push_error("Battle smoke: live retreat/surrender button tooltips do not carry the exit-order cue: %s." % exit_text)
		return false
	for leak_token in ["final_priority", "base_value", "assignment_penalty", "final_score", "income_value", "growth_value", "pressure_value", "category_bonus", "raid_score", "debug_reason", "raid_target_weights", "ai_score", "weight"]:
		if exit_text.contains(leak_token):
			push_error("Battle smoke: battle exit-order cue leaked internal token %s: %s." % [leak_token, exit_text])
			return false
	return true

func _assert_battle_target_cycle_cue_contract(shell: Node) -> bool:
	if not shell.has_method("validation_snapshot"):
		push_error("Battle smoke: shell is missing target-cycle cue validation snapshot.")
		return false
	var snapshot: Dictionary = shell.call("validation_snapshot")
	var cycle: Dictionary = snapshot.get("target_cycle_cue", {}) if snapshot.get("target_cycle_cue", {}) is Dictionary else {}
	var cycle_text := "\n".join([
		String(cycle.get("visible_text", "")),
		String(cycle.get("focus", "")),
		String(cycle.get("position", "")),
		String(cycle.get("scope", "")),
		String(cycle.get("state", "")),
		String(cycle.get("prev_tooltip", "")),
		String(cycle.get("next_tooltip", "")),
		String(snapshot.get("prev_target_text", "")),
		String(snapshot.get("next_target_text", "")),
		String(snapshot.get("prev_target_tooltip", "")),
		String(snapshot.get("next_target_tooltip", "")),
	])
	for token in ["Target cycle:", "Focus:", "Position:", "Scope:", "State:", "Prev:", "Next:"]:
		if not cycle_text.contains(token):
			push_error("Battle smoke: target-cycle cue lost %s clarity: %s." % [token, cycle_text])
			return false
	if not String(snapshot.get("prev_target_text", "")).contains("/") or not String(snapshot.get("next_target_text", "")).contains("/"):
		push_error("Battle smoke: target-cycle position is not visible on Prev/Next controls: %s." % cycle_text)
		return false
	if int(cycle.get("target_count", 0)) <= 0 or String(cycle.get("position", "")) == "0/0":
		push_error("Battle smoke: target-cycle cue did not expose a usable target count: %s." % cycle)
		return false
	for leak_token in ["final_priority", "base_value", "assignment_penalty", "final_score", "income_value", "growth_value", "pressure_value", "category_bonus", "raid_score", "debug_reason", "raid_target_weights", "ai_score", "weight"]:
		if cycle_text.contains(leak_token):
			push_error("Battle smoke: target-cycle cue leaked internal token %s: %s." % [leak_token, cycle_text])
			return false
	return true

func _assert_battle_initiative_handoff_cue_contract(shell: Node) -> bool:
	if not shell.has_method("validation_snapshot"):
		push_error("Battle smoke: shell is missing initiative-handoff validation snapshot.")
		return false
	var snapshot: Dictionary = shell.call("validation_snapshot")
	var handoff: Dictionary = snapshot.get("initiative_handoff", {}) if snapshot.get("initiative_handoff", {}) is Dictionary else {}
	var handoff_text := "\n".join([
		String(handoff.get("visible_text", "")),
		String(handoff.get("tooltip_text", "")),
		String(handoff.get("current_stack", "")),
		String(handoff.get("current_side", "")),
		String(handoff.get("next_stack", "")),
		String(handoff.get("next_side", "")),
		String(handoff.get("handoff", "")),
		String(snapshot.get("initiative_handoff_visible_text", "")),
		String(snapshot.get("initiative_handoff_tooltip_text", "")),
		String(snapshot.get("initiative_visible_text", "")),
	])
	for token in ["Initiative cue:", "Now:", "Next:", "Initiative Handoff", "Round:", "Current:", "Handoff:", "Player input:"]:
		if not handoff_text.contains(token):
			push_error("Battle smoke: initiative handoff cue lost %s clarity: %s." % [token, handoff_text])
			return false
	if String(handoff.get("current_stack", "")) == "" or String(handoff.get("next_stack", "")) == "":
		push_error("Battle smoke: initiative handoff cue is missing current or next stack labels: %s." % handoff)
		return false
	if int(handoff.get("round", 0)) <= 0 or int(handoff.get("next_round", 0)) <= 0:
		push_error("Battle smoke: initiative handoff cue is missing stable round timing: %s." % handoff)
		return false
	if not String(snapshot.get("initiative_visible_text", "")).contains("Initiative cue:"):
		push_error("Battle smoke: initiative handoff cue is not visible in the initiative rail: %s." % handoff_text)
		return false
	for leak_token in ["final_priority", "base_value", "assignment_penalty", "final_score", "income_value", "growth_value", "pressure_value", "category_bonus", "raid_score", "debug_reason", "raid_target_weights", "ai_score", "weight"]:
		if handoff_text.contains(leak_token):
			push_error("Battle smoke: initiative handoff cue leaked internal token %s: %s." % [leak_token, handoff_text])
			return false
	return true

func _first_encounter(session) -> Dictionary:
	for encounter in session.overworld.get("encounters", []):
		if encounter is Dictionary:
			return encounter
	return {}
