extends Node

const RandomMapGeneratorRulesScript = preload("res://scripts/core/RandomMapGeneratorRules.gd")
const ScenarioSelectRulesScript = preload("res://scripts/core/ScenarioSelectRules.gd")
const REPORT_ID := "RANDOM_MAP_PLAYER_SETUP_RETRY_UX_REPORT"
const SMALL_DEFAULT_TEMPLATE_ID := "translated_rmg_template_049_v1"
const SMALL_DEFAULT_PROFILE_ID := "translated_rmg_profile_049_v1"
const AUTO_TEMPLATE_ID := "native_catalog_auto"

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
	if not bool(shell.call("validation_select_generated_size_class", "homm3_small")):
		_fail("Size-class control hook did not select Small.")
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
	if not bool(shell.call("validation_set_generated_underground", true)):
		_fail("Underground control hook did not enable supported two-level generation.")
		return
	var underground_snapshot: Dictionary = shell.call("validation_generated_random_map_snapshot")
	if not _assert_release_matrix_surface(underground_snapshot):
		return
	if not bool(shell.call("validation_set_generated_underground", false)):
		_fail("Underground control hook did not restore the surface-only default.")
		return

	var setup_snapshot: Dictionary = shell.call("validation_generated_random_map_snapshot")
	if not _assert_player_setup_snapshot(setup_snapshot):
		return

	var failure_setup: Dictionary = shell.call("validation_force_generated_random_map_config", _invalid_config())
	if not _assert_failure_surface(shell, failure_setup):
		return
	if not bool(shell.call("validation_select_generated_size_class", "homm3_extra_large")):
		_fail("Size-class control hook did not select supported Extra Large public generation.")
		return
	var xlarge_snapshot: Dictionary = shell.call("validation_generated_random_map_snapshot")
	if not _assert_extra_large_size_surface(xlarge_snapshot):
		return
	var over_cap_setup: Dictionary = shell.call("validation_force_generated_random_map_config", _over_cap_config())
	if not _assert_over_cap_size_surface(shell, over_cap_setup):
		return
	var pre_islands_controls: Dictionary = shell.call("validation_generated_random_map_snapshot").get("controls", {})
	if not bool(shell.call("validation_select_generated_water_mode", "islands")):
		_fail("Water control hook did not select supported Islands generation.")
		return
	var islands_snapshot: Dictionary = shell.call("validation_generated_random_map_snapshot")
	if not _assert_water_selection_independent(islands_snapshot, pre_islands_controls):
		return
	var legacy_compact_setup := ScenarioSelectRulesScript.build_random_map_skirmish_setup_with_retry(
		_legacy_compact_launch_config(),
		"normal",
		{"max_attempts": 1, "mode": "none"}
	)
	if not _assert_legacy_compact_launch_normalized(legacy_compact_setup):
		return

	shell.call("validation_set_generated_seed", "player-facing-setup-retry-ux-10184")
	shell.call("validation_select_generated_size_class", "homm3_small")
	shell.call("validation_select_generated_player_count", 2)
	shell.call("validation_select_generated_water_mode", "normal_water")
	shell.call("validation_set_generated_underground", true)
	var launch_snapshot: Dictionary = shell.call("validation_generated_random_map_snapshot")
	var launch_setup: Dictionary = launch_snapshot.get("setup", {}) if launch_snapshot.get("setup", {}) is Dictionary else {}
	if String(launch_setup.get("template_id", "")) != AUTO_TEMPLATE_ID or String(launch_setup.get("profile_id", "")) != AUTO_TEMPLATE_ID:
		_fail("Generated UI setup did not expose native catalog auto-selection provenance before launch: %s" % JSON.stringify(launch_setup))
		return

	var launch_result: Dictionary = shell.call("validation_start_generated_skirmish")
	if not bool(launch_result.get("started", false)):
		_fail("Generated UI launch handoff did not start a generated skirmish session: %s" % JSON.stringify(launch_result))
		return
	var scenario_id := String(launch_result.get("active_scenario_id", ""))
	if not _assert_session_boundary(launch_result, "strict_small_36x36_two_level_normal_water", "normal_water", 2):
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
		"validation_select_generated_size_class",
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
	for key in ["seed", "size_class_id", "size_class_label", "player_count", "water_mode", "underground", "level_count", "level_options", "retry_policy", "visible_player_controls", "internal_template_provenance"]:
		if not controls.has(key):
			_fail("Generated setup controls missed %s: %s" % [key, JSON.stringify(controls)])
			return false
	if String(controls.get("seed", "")) != "player-facing-setup-retry-ux-10184":
		_fail("Generated seed control did not persist in snapshot.")
		return false
	if String(controls.get("size_class_id", "")) != "homm3_small" or String(controls.get("size_class_label", "")) != "Small 36x36":
		_fail("Generated size-class control did not persist in snapshot: %s" % JSON.stringify(controls))
		return false
	var internal_provenance: Dictionary = controls.get("internal_template_provenance", {}) if controls.get("internal_template_provenance", {}) is Dictionary else {}
	if String(internal_provenance.get("selection_source", "")) != "native_catalog_auto_on_launch":
		_fail("Generated template/profile provenance did not identify native catalog auto-selection: %s" % JSON.stringify(internal_provenance))
		return false
	if String(internal_provenance.get("template_id", "")) != AUTO_TEMPLATE_ID or String(internal_provenance.get("profile_id", "")) != AUTO_TEMPLATE_ID:
		_fail("Generated internal template/profile provenance did not persist in snapshot: %s" % JSON.stringify(internal_provenance))
		return false
	if String(internal_provenance.get("preview_template_id", "")) != SMALL_DEFAULT_TEMPLATE_ID or String(internal_provenance.get("preview_profile_id", "")) != SMALL_DEFAULT_PROFILE_ID:
		_fail("Generated internal preview default provenance did not persist in snapshot: %s" % JSON.stringify(internal_provenance))
		return false
	if not bool(internal_provenance.get("launch_selection_deferred_to_native", false)):
		_fail("Generated internal provenance did not defer launch selection to native: %s" % JSON.stringify(internal_provenance))
		return false
	if bool(internal_provenance.get("template_picker_visible", true)) or bool(internal_provenance.get("profile_picker_visible", true)):
		_fail("Generated manual template/profile pickers were visible: %s" % JSON.stringify(internal_provenance))
		return false
	if not bool(internal_provenance.get("underground_supported", false)) or not bool(internal_provenance.get("underground_player_control_visible", false)):
		_fail("Generated setup did not expose the supported underground control: %s" % JSON.stringify(internal_provenance))
		return false
	if int(controls.get("player_count", 0)) != 3 or String(controls.get("water_mode", "")) != "land" or bool(controls.get("underground", true)) or int(controls.get("level_count", 0)) != 1:
		_fail("Generated player/water/underground controls did not persist in snapshot: %s" % JSON.stringify(controls))
		return false
	var level_options: Array = controls.get("level_options", []) if controls.get("level_options", []) is Array else []
	if level_options != ["Surface Only (1 Level)", "Surface + Underground (2 Levels)"]:
		_fail("Generated level option list missed the supported release levels: %s" % JSON.stringify(level_options))
		return false
	var visible_controls: Array = controls.get("visible_player_controls", []) if controls.get("visible_player_controls", []) is Array else []
	for expected_control in ["seed", "size_class", "player_count", "water_mode", "level_count", "underground", "launch_generated"]:
		if expected_control not in visible_controls:
			_fail("Generated visible player controls missed %s: %s" % [expected_control, JSON.stringify(visible_controls)])
			return false
	for forbidden_key in ["template_options", "template_option_ids", "profile_options", "profile_option_ids"]:
		if controls.has(forbidden_key):
			_fail("Generated player-facing controls still exposed %s: %s" % [forbidden_key, JSON.stringify(controls)])
			return false
	var water_options: Array = controls.get("water_options", []) if controls.get("water_options", []) is Array else []
	if water_options != ["Land", "Normal Water", "Islands"]:
		_fail("Generated water option list missed supported water modes: %s" % JSON.stringify(water_options))
		return false
	var size_options: Array = controls.get("size_options", []) if controls.get("size_options", []) is Array else []
	if size_options != ["Small 36x36", "Medium 72x72", "Large 108x108", "Extra Large 144x144"]:
		_fail("Generated size option list missed supported release sizes: %s" % JSON.stringify(size_options))
		return false
	var setup: Dictionary = snapshot.get("setup", {}) if snapshot.get("setup", {}) is Dictionary else {}
	if not bool(setup.get("ok", false)):
		_fail("Generated player-facing setup did not validate: %s" % JSON.stringify(setup))
		return false
	var retry: Dictionary = setup.get("retry_status", {}) if setup.get("retry_status", {}) is Dictionary else {}
	if String(retry.get("policy", "")) != "bounded_player_setup_retry_visible" \
			or int(retry.get("max_attempts", 0)) != int(ScenarioSelectRulesScript.RANDOM_MAP_PLAYER_RETRY_POLICY.get("max_attempts", 0)):
		_fail("Generated setup did not expose bounded retry policy: %s" % JSON.stringify(retry))
		return false
	if String(retry.get("validation_status", "")) != "pending_launch_validation" or int(retry.get("attempt_count", -1)) != 0:
		_fail("Generated setup preview did not stay pending launch validation before the launch command: %s" % JSON.stringify(retry))
		return false
	if String(setup.get("launch_validation_status", "")) != "pending_launch_validation" or not bool(setup.get("preview_only", false)):
		_fail("Generated setup preview did not expose explicit pending-validation state: %s" % JSON.stringify(setup))
		return false
	var combined_text := "\n".join([
		String(snapshot.get("status_full", "")),
		String(snapshot.get("provenance_full", "")),
		String(snapshot.get("start_tooltip", "")),
	])
	for token in ["Ready to build", "checked before Day 1", "Seed", "Small 36x36", "3 players", "Land", "Surface only", "Builds this map", "no save is changed"]:
		if combined_text.find(token) < 0:
			_fail("Generated setup player-facing text missed token %s: %s" % [token, combined_text])
			return false
	for forbidden in ["internal", "provenance", "template", "profile", "bounded retry", "authored content", "validation"]:
		if combined_text.to_lower().find(forbidden) >= 0:
			_fail("Generated setup exposed internal term %s: %s" % [forbidden, combined_text])
			return false
	if String(snapshot.get("start_text", "")) != "Build & Play":
		_fail("Generated pending setup did not expose the player command: %s" % JSON.stringify(snapshot))
		return false
	if not bool(snapshot.get("start_enabled", false)):
		_fail("Generated launch button was disabled for a valid generated setup.")
		return false
	return true

func _assert_release_matrix_surface(snapshot: Dictionary) -> bool:
	var controls: Dictionary = snapshot.get("controls", {}) if snapshot.get("controls", {}) is Dictionary else {}
	if not bool(controls.get("underground", false)) or int(controls.get("level_count", 0)) != 2:
		_fail("Generated release-matrix selection did not retain two levels: %s" % JSON.stringify(controls))
		return false
	var visible_controls: Array = controls.get("visible_player_controls", []) if controls.get("visible_player_controls", []) is Array else []
	if "underground" not in visible_controls:
		_fail("Generated release-matrix setup hid the underground control: %s" % JSON.stringify(visible_controls))
		return false
	var combined_text := "\n".join([
		String(snapshot.get("provenance_full", "")),
		String(snapshot.get("start_tooltip", "")),
	])
	if combined_text.find("Surface + Underground") < 0:
		_fail("Generated release-matrix setup did not explain the two-level selection: %s" % combined_text)
		return false
	return true

func _assert_water_selection_independent(snapshot: Dictionary, before: Dictionary) -> bool:
	var controls: Dictionary = snapshot.get("controls", {}) if snapshot.get("controls", {}) is Dictionary else {}
	if String(controls.get("water_mode", "")) != "islands":
		_fail("Islands selection did not persist: %s" % JSON.stringify(controls))
		return false
	if String(controls.get("size_class_id", "")) != String(before.get("size_class_id", "")) \
			or int(controls.get("player_count", 0)) != int(before.get("player_count", 0)):
		_fail("Islands selection rewrote the selected size or player count: before=%s after=%s" % [JSON.stringify(before), JSON.stringify(controls)])
		return false
	return true

func _assert_failure_surface(shell: Node, setup: Dictionary) -> bool:
	if bool(setup.get("ok", false)):
		_fail("Invalid generated setup unexpectedly passed validation.")
		return false
	var retry: Dictionary = setup.get("retry_status", {}) if setup.get("retry_status", {}) is Dictionary else {}
	var expected_attempts := int(ScenarioSelectRulesScript.RANDOM_MAP_PLAYER_RETRY_POLICY.get("max_attempts", 0))
	if String(retry.get("status", "")) != "failed_before_launch" \
			or int(retry.get("attempt_count", 0)) != expected_attempts \
			or int(retry.get("retry_count", 0)) != max(0, expected_attempts - 1):
		_fail("Invalid generated setup did not expose bounded retry failure: %s" % JSON.stringify(retry))
		return false
	var snapshot: Dictionary = shell.call("validation_generated_random_map_snapshot")
	if bool(snapshot.get("start_enabled", true)):
		_fail("Generated launch button stayed enabled after forced validation failure.")
		return false
	if String(snapshot.get("start_text", "")) != "Setup Unavailable":
		_fail("Generated blocked setup did not return to the blocked launch command label: %s" % JSON.stringify(snapshot))
		return false
	var failure_text := "\n".join([
		String(snapshot.get("status_full", "")),
		String(snapshot.get("provenance_full", "")),
		String(snapshot.get("start_tooltip", "")),
	])
	for token in ["Map build stopped", "change the seed or setup", "This setup is unavailable", "No game starts", "no save is changed"]:
		if failure_text.find(token) < 0:
			_fail("Generated failure surface missed token %s: %s" % [token, failure_text])
			return false
	for forbidden in ["internal", "provenance", "template", "profile", "retry", "validation", "authored"]:
		if failure_text.to_lower().find(forbidden) >= 0:
			_fail("Generated failure surface exposed internal term %s: %s" % [forbidden, failure_text])
			return false
	return true

func _assert_extra_large_size_surface(snapshot: Dictionary) -> bool:
	var setup: Dictionary = snapshot.get("setup", {}) if snapshot.get("setup", {}) is Dictionary else {}
	if not bool(setup.get("ok", false)):
		_fail("Extra Large generated size class preview failed validation: %s" % JSON.stringify(setup))
		return false
	if String(setup.get("template_id", "")) != AUTO_TEMPLATE_ID or String(setup.get("profile_id", "")) != AUTO_TEMPLATE_ID:
		_fail("Extra Large preview did not expose native catalog auto-selection: %s" % JSON.stringify(setup))
		return false
	if String(setup.get("preview_template_id", "")) != "translated_rmg_template_043_v1" or String(setup.get("preview_profile_id", "")) != "translated_rmg_profile_043_v1":
		_fail("Extra Large preview did not preserve translated XL default provenance: %s" % JSON.stringify(setup))
		return false
	var controls: Dictionary = snapshot.get("controls", {}) if snapshot.get("controls", {}) is Dictionary else {}
	var provenance: Dictionary = controls.get("internal_template_provenance", {}) if controls.get("internal_template_provenance", {}) is Dictionary else {}
	if String(provenance.get("selection_source", "")) != "native_catalog_auto_on_launch" or bool(provenance.get("template_picker_visible", true)) or bool(provenance.get("profile_picker_visible", true)):
		_fail("Extra Large internal provenance did not remain native-auto and hidden: %s" % JSON.stringify(provenance))
		return false
	return true

func _assert_over_cap_size_surface(shell: Node, setup: Dictionary) -> bool:
	if bool(setup.get("ok", false)):
		_fail("Over-cap generated size unexpectedly passed validation.")
		return false
	var validation: Dictionary = setup.get("validation", {}) if setup.get("validation", {}) is Dictionary else {}
	if String(validation.get("schema_id", "")) != RandomMapGeneratorRulesScript.RUNTIME_SIZE_POLICY_REJECTION_SCHEMA_ID:
		_fail("Over-cap size did not fail through runtime size policy: %s" % JSON.stringify(validation))
		return false
	var size_policy: Dictionary = validation.get("size_policy", {}) if validation.get("size_policy", {}) is Dictionary else {}
	var source_size: Dictionary = size_policy.get("source_size", {}) if size_policy.get("source_size", {}) is Dictionary else {}
	var materialized_size: Dictionary = size_policy.get("materialized_size", {}) if size_policy.get("materialized_size", {}) is Dictionary else {}
	var runtime_policy: Dictionary = size_policy.get("runtime_size_policy", {}) if size_policy.get("runtime_size_policy", {}) is Dictionary else {}
	if int(source_size.get("width", 0)) != 180 or int(source_size.get("height", 0)) != 180:
		_fail("Over-cap validation missed 180x180 source provenance: %s" % JSON.stringify(size_policy))
		return false
	if bool(runtime_policy.get("materialization_available", true)) or bool(runtime_policy.get("hidden_downscale", true)):
		_fail("Over-cap validation did not explicitly block hidden downscale: %s" % JSON.stringify(size_policy))
		return false
	if int(materialized_size.get("width", 0)) != 144 or int(materialized_size.get("height", 0)) != 144:
		_fail("Over-cap validation did not report the current runtime cap materialized bound: %s" % JSON.stringify(size_policy))
		return false
	var snapshot: Dictionary = shell.call("validation_generated_random_map_snapshot")
	if bool(snapshot.get("start_enabled", true)):
		_fail("Generated launch button stayed enabled after forced over-cap size failure.")
		return false
	return true

func _assert_legacy_compact_launch_normalized(setup: Dictionary) -> bool:
	if not bool(setup.get("ok", false)):
		_fail("Public Small/Land setup did not override stale compact template/profile into native h3maped generation: %s" % JSON.stringify(setup))
		return false
	var native_generation: Dictionary = setup.get("native_generation", {}) if setup.get("native_generation", {}) is Dictionary else {}
	var provenance: Dictionary = setup.get("provenance", {}) if setup.get("provenance", {}) is Dictionary else {}
	var normalized: Dictionary = provenance.get("normalized_config", {}) if provenance.get("normalized_config", {}) is Dictionary else {}
	if String(native_generation.get("status", "")) != "complete" or not bool(native_generation.get("supported_parity_config", false)):
		_fail("Public Small/Land setup did not use the completed native runtime after stale compact override: %s" % JSON.stringify(native_generation))
		return false
	if String(normalized.get("template_selection_authority", "")) != "recovered_h3maped_exe_source_order" \
			or String(normalized.get("template_selection_mode", "")) != "recovered_h3maped_exe_rng_exact_state_chain" \
			or bool(normalized.get("translated_template_authority_used", true)):
		_fail("Public Small/Land setup did not preserve recovered executable source-order authority: %s" % JSON.stringify(normalized))
		return false
	return true

func _assert_session_boundary(launch_result: Dictionary, expected_scope: String, expected_water_mode: String, expected_level_count: int) -> bool:
	if String(launch_result.get("active_launch_mode", "")) != SessionState.LAUNCH_MODE_SKIRMISH:
		_fail("Generated UI launch left skirmish launch mode: %s" % JSON.stringify(launch_result))
		return false
	var provenance: Dictionary = launch_result.get("active_provenance", {}) if launch_result.get("active_provenance", {}) is Dictionary else {}
	for key in ["normalized_config", "generated_identity", "retry_status", "map_ref", "scenario_ref", "boundaries"]:
		if not provenance.has(key):
			_fail("Generated UI launch provenance missed %s: %s" % [key, JSON.stringify(provenance)])
			return false
	var normalized: Dictionary = provenance.get("normalized_config", {}) if provenance.get("normalized_config", {}) is Dictionary else {}
	if String(normalized.get("template_id", "")) == AUTO_TEMPLATE_ID or String(normalized.get("profile_id", "")) == AUTO_TEMPLATE_ID:
		_fail("Generated UI launch provenance retained the pre-launch auto-selection sentinel: %s" % JSON.stringify(normalized))
		return false
	if String(normalized.get("template_selection_mode", "")) != "recovered_h3maped_exe_rng_exact_state_chain" \
			or String(normalized.get("template_selection_authority", "")) != "recovered_h3maped_exe_source_order" \
			or not bool(normalized.get("template_selection_runtime_generation_allowed", false)) \
			or bool(normalized.get("translated_template_authority_used", true)):
		_fail("Generated UI launch provenance did not record H3MapEd executable selection authority: %s" % JSON.stringify(normalized))
		return false
	var boundaries: Dictionary = provenance.get("boundaries", {}) if provenance.get("boundaries", {}) is Dictionary else {}
	if bool(boundaries.get("authored_content_writeback", true)) or bool(boundaries.get("content_scenarios_json", true)) or bool(boundaries.get("generated_scenario_draft_registry", true)) or bool(boundaries.get("legacy_json_scenario_record", true)):
		_fail("Generated UI launch provenance crossed forbidden boundary: %s" % JSON.stringify(provenance))
		return false
	if String(normalized.get("size_class_id", "")) != "small" \
			or String(normalized.get("h3maped_strict_scope", "")) != expected_scope \
			or String(normalized.get("water_mode", "")) != expected_water_mode \
			or int(normalized.get("level_count", 0)) != expected_level_count \
			or int(normalized.get("width", 0)) != 36 \
			or int(normalized.get("height", 0)) != 36:
		_fail("Generated UI launch provenance missed HoMM3 Small source size: %s" % JSON.stringify(normalized))
		return false
	return true

func _invalid_config() -> Dictionary:
	return {
		"validation_force_failure": true,
		"validation_schema_id": "generated_random_map_validation_forced_failure_v1",
		"validation_failure": "forced_player_setup_validation_failure",
		"generator_version": RandomMapGeneratorRulesScript.GENERATOR_VERSION,
		"seed": "player-facing-setup-retry-ux-10184-invalid",
		"size": {"preset": "player_facing_invalid", "width": 180, "height": 180, "water_mode": "islands", "level_count": 1},
		"player_constraints": {"human_count": 1, "player_count": 3, "team_mode": "free_for_all"},
		"profile": {"id": "border_gate_compact_profile_v1", "template_id": "border_gate_compact_v1"},
	}

func _over_cap_config() -> Dictionary:
	return {
		"validation_force_failure": true,
		"validation_schema_id": RandomMapGeneratorRulesScript.RUNTIME_SIZE_POLICY_REJECTION_SCHEMA_ID,
		"validation_failure": "runtime_size_policy_blocked",
		"validation_size_policy": {
			"source_size": {"width": 180, "height": 180},
			"materialized_size": {"width": 144, "height": 144},
			"runtime_size_policy": {
				"status": "blocked_source_size_exceeds_current_144x144x2_cap",
				"materialization_available": false,
				"hidden_downscale": false,
			},
		},
		"generator_version": RandomMapGeneratorRulesScript.GENERATOR_VERSION,
		"seed": "player-facing-setup-retry-ux-10184-over-cap",
		"size": {"preset": "over_cap_validation", "width": 180, "height": 180, "water_mode": "land", "level_count": 1},
		"player_constraints": {"human_count": 1, "player_count": 3, "team_mode": "free_for_all"},
		"profile": {"id": "border_gate_compact_profile_v1", "template_id": "border_gate_compact_v1"},
	}

func _legacy_compact_launch_config() -> Dictionary:
	return ScenarioSelectRulesScript.build_random_map_player_config(
		"player-facing-setup-retry-ux-10184-legacy-compact",
		"border_gate_compact_v1",
		"border_gate_compact_profile_v1",
		3,
		"land",
		false,
		"homm3_small"
	)

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
