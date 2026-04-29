extends Node

const RandomMapGeneratorRulesScript = preload("res://scripts/core/RandomMapGeneratorRules.gd")
const ScenarioSelectRulesScript = preload("res://scripts/core/ScenarioSelectRules.gd")
const REPORT_ID := "RANDOM_MAP_PLAYER_SETUP_RETRY_UX_REPORT"

func _ready() -> void:
	call_deferred("_run")

func _run() -> void:
	ContentService.clear_generated_scenario_drafts()
	var shell = load("res://scenes/menus/MainMenu.tscn").instantiate()
	add_child(shell)
	await get_tree().process_frame
	await get_tree().process_frame

	if not _assert_hooks(shell):
		return
	shell.call("validation_open_skirmish_stage")
	if not bool(shell.call("validation_set_generated_seed", "player-facing-setup-retry-ux-10184")):
		_fail("Seed control hook did not update generated setup.")
		return
	if not bool(shell.call("validation_select_generated_template", "border_gate_compact_v1")):
		_fail("Template control hook did not select compact template.")
		return
	if not bool(shell.call("validation_select_generated_profile", "border_gate_compact_profile_v1")):
		_fail("Profile control hook did not select compact profile.")
		return
	if not bool(shell.call("validation_select_generated_player_count", 3)):
		_fail("Player-count control hook did not select three players.")
		return
	if not bool(shell.call("validation_select_generated_water_mode", "land")):
		_fail("Water control hook did not select land.")
		return
	if not bool(shell.call("validation_set_generated_underground", false)):
		_fail("Underground control hook did not disable underground.")
		return

	var setup_snapshot: Dictionary = shell.call("validation_generated_random_map_snapshot")
	if not _assert_player_setup_snapshot(setup_snapshot):
		return

	var failure_setup: Dictionary = shell.call("validation_force_generated_random_map_config", _invalid_config())
	if not _assert_failure_surface(shell, failure_setup):
		return

	shell.call("validation_set_generated_seed", "player-facing-setup-retry-ux-10184")
	shell.call("validation_select_generated_template", "border_gate_compact_v1")
	shell.call("validation_select_generated_profile", "border_gate_compact_profile_v1")
	shell.call("validation_select_generated_player_count", 3)
	shell.call("validation_select_generated_water_mode", "land")
	shell.call("validation_set_generated_underground", false)
	var launch_snapshot: Dictionary = shell.call("validation_generated_random_map_snapshot")
	var launch_setup: Dictionary = launch_snapshot.get("setup", {}) if launch_snapshot.get("setup", {}) is Dictionary else {}
	if String(launch_setup.get("template_id", "")) == "" or String(launch_setup.get("profile_id", "")) == "":
		_fail("Generated UI setup did not expose template/profile provenance before launch: %s" % JSON.stringify(launch_setup))
		return

	var launch_result: Dictionary = shell.call("validation_start_generated_skirmish")
	if not bool(launch_result.get("started", false)):
		_fail("Generated UI launch handoff did not start a generated skirmish session: %s" % JSON.stringify(launch_result))
		return
	var scenario_id := String(launch_result.get("active_scenario_id", ""))
	if not _assert_session_boundary(launch_result):
		return
	if not _assert_no_authored_writeback(scenario_id, "after generated UI launch"):
		return

	ContentService.clear_generated_scenario_drafts()
	print("%s %s" % [REPORT_ID, JSON.stringify({
		"ok": true,
		"scenario_id": scenario_id,
		"controls": launch_snapshot.get("controls", {}),
		"retry_status": launch_result.get("active_retry_status", {}),
		"failure_retry_status": failure_setup.get("retry_status", {}),
		"provenance_schema": launch_result.get("active_provenance", {}).get("schema_id", ""),
	})])
	get_tree().quit(0)

func _assert_hooks(shell: Node) -> bool:
	for method_name in [
		"validation_open_skirmish_stage",
		"validation_set_generated_seed",
		"validation_select_generated_template",
		"validation_select_generated_profile",
		"validation_select_generated_player_count",
		"validation_select_generated_water_mode",
		"validation_set_generated_underground",
		"validation_force_generated_random_map_config",
		"validation_start_generated_skirmish",
		"validation_generated_random_map_snapshot",
	]:
		if not shell.has_method(method_name):
			_fail("Main menu missing generated random-map validation hook %s." % method_name)
			return false
	return true

func _assert_player_setup_snapshot(snapshot: Dictionary) -> bool:
	var controls: Dictionary = snapshot.get("controls", {}) if snapshot.get("controls", {}) is Dictionary else {}
	for key in ["seed", "template_id", "profile_id", "player_count", "water_mode", "underground", "retry_policy"]:
		if not controls.has(key):
			_fail("Generated setup controls missed %s: %s" % [key, JSON.stringify(controls)])
			return false
	if String(controls.get("seed", "")) != "player-facing-setup-retry-ux-10184":
		_fail("Generated seed control did not persist in snapshot.")
		return false
	if String(controls.get("template_id", "")) != "border_gate_compact_v1" or String(controls.get("profile_id", "")) != "border_gate_compact_profile_v1":
		_fail("Generated template/profile controls did not persist in snapshot: %s" % JSON.stringify(controls))
		return false
	if int(controls.get("player_count", 0)) != 3 or String(controls.get("water_mode", "")) != "land" or bool(controls.get("underground", true)):
		_fail("Generated player/water/underground controls did not persist in snapshot: %s" % JSON.stringify(controls))
		return false
	var water_options: Array = controls.get("water_options", []) if controls.get("water_options", []) is Array else []
	if "Islands" not in water_options:
		_fail("Generated water option list did not expose islands mode: %s" % JSON.stringify(water_options))
		return false
	var template_options: Array = controls.get("template_options", []) if controls.get("template_options", []) is Array else []
	var profile_options: Array = controls.get("profile_options", []) if controls.get("profile_options", []) is Array else []
	if "Translated Islands" not in template_options or "Translated Parity" not in profile_options:
		_fail("Generated translated template/profile equivalents were not exposed: %s / %s" % [JSON.stringify(template_options), JSON.stringify(profile_options)])
		return false
	var setup: Dictionary = snapshot.get("setup", {}) if snapshot.get("setup", {}) is Dictionary else {}
	if not bool(setup.get("ok", false)):
		_fail("Generated player-facing setup did not validate: %s" % JSON.stringify(setup))
		return false
	var retry: Dictionary = setup.get("retry_status", {}) if setup.get("retry_status", {}) is Dictionary else {}
	if String(retry.get("policy", "")) != "bounded_player_setup_retry_visible" or int(retry.get("max_attempts", 0)) != 2:
		_fail("Generated setup did not expose bounded retry policy: %s" % JSON.stringify(retry))
		return false
	var combined_text := "\n".join([
		String(snapshot.get("status_full", "")),
		String(snapshot.get("provenance_full", "")),
		String(snapshot.get("start_tooltip", "")),
	])
	for token in ["Generated validation", "Seed", "Template", "Profile", "Players", "Water", "Underground", "Launch handoff", "campaign progress", "authored content"]:
		if combined_text.find(token) < 0:
			_fail("Generated setup visible/provenance text missed token %s: %s" % [token, combined_text])
			return false
	if not bool(snapshot.get("start_enabled", false)):
		_fail("Generated launch button was disabled for a valid generated setup.")
		return false
	return true

func _assert_failure_surface(shell: Node, setup: Dictionary) -> bool:
	if bool(setup.get("ok", false)):
		_fail("Invalid generated setup unexpectedly passed validation.")
		return false
	var retry: Dictionary = setup.get("retry_status", {}) if setup.get("retry_status", {}) is Dictionary else {}
	if String(retry.get("status", "")) != "failed_before_launch" or int(retry.get("attempt_count", 0)) != 2 or int(retry.get("retry_count", 0)) != 1:
		_fail("Invalid generated setup did not expose bounded retry failure: %s" % JSON.stringify(retry))
		return false
	var snapshot: Dictionary = shell.call("validation_generated_random_map_snapshot")
	if bool(snapshot.get("start_enabled", true)):
		_fail("Generated launch button stayed enabled after forced validation failure.")
		return false
	var failure_text := "\n".join([
		String(setup.get("failure_handoff", "")),
		String(setup.get("setup_summary", "")),
		String(snapshot.get("status_full", "")),
		String(snapshot.get("provenance_full", "")),
	])
	for token in ["blocked", "validation", "attempt", "retry", "no session", "campaign", "authored"]:
		if failure_text.to_lower().find(token) < 0:
			_fail("Generated failure surface missed token %s: %s" % [token, failure_text])
			return false
	return true

func _assert_session_boundary(launch_result: Dictionary) -> bool:
	if String(launch_result.get("active_launch_mode", "")) != SessionState.LAUNCH_MODE_SKIRMISH:
		_fail("Generated UI launch left skirmish launch mode: %s" % JSON.stringify(launch_result))
		return false
	var provenance: Dictionary = launch_result.get("active_provenance", {}) if launch_result.get("active_provenance", {}) is Dictionary else {}
	for key in ["normalized_seed", "template_id", "profile_id", "player_settings", "generated_export", "retry_status"]:
		if not provenance.has(key):
			_fail("Generated UI launch provenance missed %s: %s" % [key, JSON.stringify(provenance)])
			return false
	if bool(provenance.get("campaign_adoption", true)) or bool(provenance.get("authored_content_writeback", true)) or bool(provenance.get("alpha_parity_claim", true)):
		_fail("Generated UI launch provenance crossed forbidden boundary: %s" % JSON.stringify(provenance))
		return false
	return true

func _invalid_config() -> Dictionary:
	return {
		"generator_version": RandomMapGeneratorRulesScript.GENERATOR_VERSION,
		"seed": "player-facing-setup-retry-ux-10184-invalid",
		"size": {"preset": "player_facing_invalid", "width": 26, "height": 18, "water_mode": "islands", "level_count": 1},
		"player_constraints": {"human_count": 1, "player_count": 3, "team_mode": "free_for_all"},
		"profile": {"id": "border_gate_compact_profile_v1", "template_id": "border_gate_compact_v1"},
	}

func _assert_no_authored_writeback(scenario_id: String, phase: String) -> bool:
	if scenario_id == "":
		_fail("Generated scenario id was empty during %s." % phase)
		return false
	if ContentService.has_authored_scenario(scenario_id):
		_fail("Generated scenario appeared in authored content during %s." % phase)
		return false
	for item in ContentService.load_json(ContentService.SCENARIOS_PATH).get("items", []):
		if item is Dictionary and String(item.get("id", "")) == scenario_id:
			_fail("Generated scenario was written to scenarios.json during %s." % phase)
			return false
	for campaign in ContentService.load_json(ContentService.CAMPAIGNS_PATH).get("items", []):
		if not (campaign is Dictionary):
			continue
		for campaign_scenario in campaign.get("scenarios", []):
			if campaign_scenario is Dictionary and String(campaign_scenario.get("scenario_id", "")) == scenario_id:
				_fail("Generated scenario was written to campaign content during %s." % phase)
				return false
	return true

func _fail(message: String) -> void:
	ContentService.clear_generated_scenario_drafts()
	push_error("%s failed: %s" % [REPORT_ID, message])
	get_tree().quit(1)
