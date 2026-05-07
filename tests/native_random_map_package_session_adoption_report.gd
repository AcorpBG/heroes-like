extends Node

const ScenarioSelectRulesScript = preload("res://scripts/core/ScenarioSelectRules.gd")
const SessionStateStoreScript = preload("res://scripts/core/SessionStateStore.gd")
const NativeRandomMapPackageSessionBridgeScript = preload("res://scripts/persistence/NativeRandomMapPackageSessionBridge.gd")
const OverworldMapViewScript = preload("res://scenes/overworld/OverworldMapView.gd")

const REPORT_ID := "NATIVE_RANDOM_MAP_PACKAGE_SESSION_ADOPTION_REPORT"
const REPORT_SCHEMA_ID := "native_random_map_package_session_adoption_smoke_v1"
const FEATURE_GATE := "native_rmg_package_session_adoption_report"

func _ready() -> void:
	call_deferred("_run")

func _run() -> void:
	if not ClassDB.class_exists("MapPackageService"):
		_fail("MapPackageService native class is not available.")
		return

	var service: Variant = ClassDB.instantiate("MapPackageService")
	var metadata: Dictionary = service.get_api_metadata()
	if String(metadata.get("binding_kind", "")) != "native_gdextension" or not bool(metadata.get("native_extension_loaded", false)):
		_fail("Native GDExtension metadata did not prove native load: %s" % JSON.stringify(metadata))
		return
	var capabilities: PackedStringArray = service.get_capabilities()
	if not capabilities.has("native_random_map_package_session_adoption_bridge"):
		_fail("Native package/session adoption capability is missing: %s" % JSON.stringify(Array(capabilities)))
		return
	if not capabilities.has("native_package_save_load") or not capabilities.has("generated_map_package_disk_startup"):
		_fail("Native generated package save/load startup capabilities are missing: %s" % JSON.stringify(Array(capabilities)))
		return

	ContentService.clear_generated_scenario_drafts()
	var config := ScenarioSelectRulesScript.build_random_map_player_config(
		"native-rmg-gdscript-comparison-10184-small-land",
		"translated_rmg_template_049_v1",
		"translated_rmg_profile_049_v1",
		3,
		"land",
		false,
		"homm3_small"
	)

	var first: Dictionary = service.generate_random_map(config)
	var second: Dictionary = service.generate_random_map(config.duplicate(true))
	_assert_native_generation(first)
	_assert_native_generation(second)

	var adoption: Dictionary = service.convert_generated_payload(first, {
		"feature_gate": FEATURE_GATE,
		"session_save_version": SessionStateStoreScript.SAVE_VERSION,
	})
	var repeat_adoption: Dictionary = service.convert_generated_payload(second, {
		"feature_gate": FEATURE_GATE,
		"session_save_version": SessionStateStoreScript.SAVE_VERSION,
	})
	_assert_adoption_shape(adoption, 36, 36, 1, 3)
	_assert_adoption_shape(repeat_adoption, 36, 36, 1, 3)
	var adoption_authoritative := bool(adoption.get("report", {}).get("native_runtime_authoritative", false))
	if adoption_authoritative and String(adoption.get("map_package_record", {}).get("package_hash", "")) != String(repeat_adoption.get("map_package_record", {}).get("package_hash", "")):
		_fail("Repeated native adoption did not preserve map package hash.")
		return
	if adoption_authoritative and String(adoption.get("scenario_package_record", {}).get("package_hash", "")) != String(repeat_adoption.get("scenario_package_record", {}).get("package_hash", "")):
		_fail("Repeated native adoption did not preserve scenario package hash.")
		return
	if adoption_authoritative and String(adoption.get("session_boundary_record", {}).get("session_id", "")) != String(repeat_adoption.get("session_boundary_record", {}).get("session_id", "")):
		_fail("Repeated native adoption did not preserve stable session id.")
		return

	var bridge := NativeRandomMapPackageSessionBridgeScript.new()
	var session: SessionStateStoreScript.SessionData = bridge.build_session_from_adoption(adoption, "normal")
	_assert_session_shape(session, adoption)
	var visual_bridge: Dictionary = await _assert_visual_asset_bridge(session)

	var scenario_id := String(adoption.get("scenario_ref", {}).get("scenario_id", ""))
	if ContentService.has_authored_scenario(scenario_id):
		_fail("Native generated scenario id collided with authored content: %s." % scenario_id)
		return
	if ContentService.has_generated_scenario_draft(scenario_id):
		_fail("Native package/session adoption wrote a generated draft into ContentService.")
		return

	var active_setup: Dictionary = ScenarioSelectRulesScript.build_random_map_skirmish_setup_with_retry(
		config,
		"normal",
		ScenarioSelectRulesScript.RANDOM_MAP_PLAYER_RETRY_POLICY
	)
	if not bool(active_setup.get("ok", false)):
		_fail("Active generated package setup failed: %s" % JSON.stringify(active_setup))
		return
	if not active_setup.get("generated_map", {}).is_empty():
		_fail("Active generated setup still exposed an in-memory generated scenario payload.")
		return
	var package_startup: Dictionary = active_setup.get("package_startup", {}) if active_setup.get("package_startup", {}) is Dictionary else {}
	if package_startup.is_empty():
		_fail("Active generated setup did not persist package startup data.")
		return
	var map_path := String(package_startup.get("map_path", ""))
	var scenario_path := String(package_startup.get("scenario_path", ""))
	if not map_path.begins_with("res://maps/") or not scenario_path.begins_with("res://maps/"):
		_fail("Active generated setup did not use project maps/ package paths: %s" % JSON.stringify(package_startup))
		return
	var package_stem := String(package_startup.get("package_stem", ""))
	if package_stem == "" or map_path.get_file().get_basename() != package_stem or scenario_path.get_file().get_basename() != package_stem:
		_fail("Active generated setup did not pair map/scenario packages with one readable stem: %s" % JSON.stringify(package_startup))
		return
	if not _package_filename_is_clean(map_path.get_file()) or not _package_filename_is_clean(scenario_path.get_file()):
		_fail("Active generated package filenames did not match clean player-readable shape: %s | %s" % [map_path.get_file(), scenario_path.get_file()])
		return
	if not _package_stem_is_clean(package_stem):
		_fail("Active generated package stem did not use size-creative-name-hash shape: %s" % package_stem)
		return
	var stem_parts := package_stem.split("-")
	if stem_parts[0] != "small":
		_fail("Active generated package stem leaked internal size class instead of display size: %s" % package_stem)
		return
	var creative_words := []
	for index in range(1, stem_parts.size() - 1):
		creative_words.append(stem_parts[index])
	var creative_part := "-".join(creative_words)
	if creative_part.split("-").size() != 3:
		_fail("Active generated package stem did not include a three-word creative name: %s" % package_stem)
		return
	for forbidden_part in _forbidden_filename_parts():
		if package_stem.contains(forbidden_part):
			_fail("Active generated package stem still includes debug identity part '%s': %s" % [forbidden_part, package_stem])
			return
	var package_identity: Dictionary = package_startup.get("package_identity", {}) if package_startup.get("package_identity", {}) is Dictionary else {}
	if String(package_identity.get("filename_style", "")) != "size-creative-name-hash-lowercase-kebab-deterministic":
		_fail("Active generated package identity did not preserve the corrected filename style: %s" % JSON.stringify(package_identity))
		return
	if String(package_identity.get("creative_name", "")) != creative_part or not _is_hex8(String(package_identity.get("short_hash", ""))):
		_fail("Active generated package identity did not preserve creative name and metadata hash outside the filename: %s" % JSON.stringify(package_identity))
		return
	if not package_stem.ends_with("-%s" % String(package_identity.get("short_hash", ""))):
		_fail("Active generated package stem did not use the deterministic short hash suffix: %s" % JSON.stringify(package_identity))
		return
	if not bool(package_startup.get("map_load", {}).get("ok", false)) or not bool(package_startup.get("scenario_load", {}).get("ok", false)):
		_fail("Active generated setup did not prove package load after save: %s" % JSON.stringify(package_startup))
		return
	var active_session: SessionStateStoreScript.SessionData = ScenarioSelectRulesScript.start_random_map_skirmish_session_from_setup(active_setup)
	if active_session == null or active_session.session_id == "":
		_fail("Active generated package setup did not start a session.")
		return
	var active_boundary: Dictionary = active_session.flags.get("generated_random_map_boundary", {}) if active_session.flags.get("generated_random_map_boundary", {}) is Dictionary else {}
	if String(active_boundary.get("adoption_path", "")) != "native_rmg_generated_package_saved_loaded_from_disk":
		_fail("Active session did not load through disk package startup: %s" % JSON.stringify(active_boundary))
		return
	if bool(active_boundary.get("content_service_generated_draft", true)) or bool(active_boundary.get("legacy_json_scenario_record", true)):
		_fail("Active session still used generated drafts or legacy scenario JSON: %s" % JSON.stringify(active_boundary))
		return
	if ContentService.has_generated_scenario_draft(String(active_setup.get("scenario_id", ""))):
		_fail("Active package startup wrote a generated draft into ContentService.")
		return
	DirAccess.remove_absolute(map_path)
	DirAccess.remove_absolute(scenario_path)

	var report := {
		"schema_id": REPORT_SCHEMA_ID,
		"ok": true,
		"binding_kind": metadata.get("binding_kind", ""),
		"native_extension_loaded": metadata.get("native_extension_loaded", false),
		"native_generation_status": first.get("status", ""),
		"adoption_status": adoption.get("adoption_status", ""),
		"map_id": adoption.get("map_ref", {}).get("map_id", ""),
		"map_package_hash": adoption.get("map_package_record", {}).get("package_hash", ""),
		"scenario_id": scenario_id,
		"scenario_package_hash": adoption.get("scenario_package_record", {}).get("package_hash", ""),
		"session_id": session.session_id,
		"active_session_id": active_session.session_id,
		"save_version": session.save_version,
		"active_disk_package_startup_ok": true,
		"active_map_package_path": map_path,
		"active_scenario_package_path": scenario_path,
		"visual_bridge": visual_bridge,
		"authored_writeback": false,
		"full_parity_claim": false,
		"readiness": adoption.get("readiness", {}),
	}
	print("%s %s" % [REPORT_ID, JSON.stringify(report)])
	get_tree().quit(0)

func _package_filename_is_clean(filename: String) -> bool:
	var regex := RegEx.new()
	regex.compile("^[a-z]+-[a-z0-9-]+-[0-9a-f]{8}\\.(amap|ascenario)$")
	return regex.search(filename) != null

func _package_stem_is_clean(stem: String) -> bool:
	var regex := RegEx.new()
	regex.compile("^[a-z]+-[a-z0-9-]+-[0-9a-f]{8}$")
	return regex.search(stem) != null

func _is_hex8(value: String) -> bool:
	var regex := RegEx.new()
	regex.compile("^[0-9a-f]{8}$")
	return regex.search(value) != null

func _forbidden_filename_parts() -> Array:
	return [
		"homm3",
		"10184",
		"native-rmg",
		"native_rmg",
		"disk-package",
		"disk_package",
		"startup",
		"template",
		"profile",
		"debug",
		"test",
		"gdscript",
		"comparison",
		"border-gate-compact-v1",
		"border-gate-compact-profile-v1",
		"36x36",
		"l1",
		"p3",
		"land",
		"seed-",
		"v1",
	]

func _assert_native_generation(generated: Dictionary) -> void:
	if not bool(generated.get("ok", false)):
		_fail("Native RMG returned ok=false: %s" % JSON.stringify(generated))
		return
	if String(generated.get("status", "")) != "owner_compared_translated_profile_supported" or String(generated.get("full_generation_status", "")) == "not_implemented":
		_fail("Native RMG status did not report owner-compared translated profile support: %s" % JSON.stringify(generated.get("report", {})))
		return
	if String(generated.get("validation_status", "")) != "pass" or not bool(generated.get("no_authored_writeback", false)):
		_fail("Native RMG validation/no-writeback boundary failed: %s" % JSON.stringify(generated.get("validation_report", {})))
		return
	if bool(generated.get("full_parity_claim", false)) or bool(generated.get("native_runtime_authoritative", false)):
		_fail("Native RMG must not claim production parity or runtime authority: %s" % JSON.stringify(generated.get("provenance", {})))
		return

func _assert_adoption_shape(adoption: Dictionary, width: int, height: int, levels: int, players: int) -> void:
	if not bool(adoption.get("ok", false)) or String(adoption.get("status", "")) != "pass":
		_fail("Native adoption conversion failed: %s" % JSON.stringify(adoption))
		return
	var report: Dictionary = adoption.get("report", {})
	if String(report.get("schema_id", "")) != "aurelion_native_random_map_package_session_adoption_report_v1" or not bool(report.get("package_session_adoption_ready", false)):
		_fail("Adoption report did not prove package/session readiness: %s" % JSON.stringify(report))
		return
	if not bool(report.get("native_runtime_authoritative", false)) or not bool(report.get("runtime_call_site_adoption", false)) or bool(report.get("full_parity_claim", true)):
		_fail("Adoption report must mark owner-compared packages runtime-authoritative without claiming full parity: %s" % JSON.stringify(report))
		return
	if String(report.get("adoption_status", "")) != "runtime_authoritative_owner_compared_not_full_parity":
		_fail("Adoption report status must distinguish runtime authority from full parity: %s" % JSON.stringify(report))
		return
	var remaining: Array = report.get("remaining_parity_slices", []) if report.get("remaining_parity_slices", []) is Array else []
	if remaining.has("native-rmg-package-session-authoritative-replay-gate-10184") or not remaining.has("native-rmg-full-homm3-parity-gate-10184"):
		_fail("Adoption report kept stale replay-gate parity requirements after runtime authority: %s" % JSON.stringify(remaining))
		return
	var metrics: Dictionary = report.get("metrics", {})
	if int(metrics.get("width", 0)) != width or int(metrics.get("height", 0)) != height or int(metrics.get("level_count", 0)) != levels:
		_fail("Adoption metrics did not preserve native dimensions: %s" % JSON.stringify(metrics))
		return
	if int(metrics.get("player_slot_count", 0)) != players or int(metrics.get("map_document_object_count", 0)) <= 0:
		_fail("Adoption metrics missed player slots or map objects: %s" % JSON.stringify(metrics))
		return
	var map_document: Variant = adoption.get("map_document", null)
	var scenario_document: Variant = adoption.get("scenario_document", null)
	if map_document == null or scenario_document == null:
		_fail("Adoption missed typed documents.")
		return
	if map_document.get_width() != width or map_document.get_height() != height or map_document.get_level_count() != levels:
		_fail("MapDocument dimensions do not match adoption metrics.")
		return
	if String(map_document.get_source_kind()) != "generated" or String(map_document.get_map_id()) == "" or String(map_document.get_map_hash()) == "":
		_fail("MapDocument missed generated identity.")
		return
	if scenario_document.get_player_slots().size() != players or scenario_document.get_start_contract().is_empty():
		_fail("ScenarioDocument missed player slots/start contract.")
		return
	var map_package: Dictionary = adoption.get("map_package_record", {})
	var scenario_package: Dictionary = adoption.get("scenario_package_record", {})
	var session_boundary: Dictionary = adoption.get("session_boundary_record", {})
	for record in [map_package, scenario_package, session_boundary]:
		if bool(record.get("authored_content_writeback", true)) or bool(record.get("save_version_bump", true)) or String(record.get("feature_gate", "")) != FEATURE_GATE:
			_fail("Package/session record lost writeback, save-version, or feature-gate boundary: %s" % JSON.stringify(record))
			return
	if String(map_package.get("storage_policy", "")) != "memory_only_no_authored_writeback" or String(scenario_package.get("storage_policy", "")) != "memory_only_no_authored_writeback":
		_fail("Package records did not stay generated/session records only.")
		return
	if int(session_boundary.get("save_version", 0)) != SessionStateStoreScript.SAVE_VERSION:
		_fail("Session boundary did not preserve current save version.")
		return

func _assert_session_shape(session: SessionStateStoreScript.SessionData, adoption: Dictionary) -> void:
	if session == null or session.session_id == "":
		_fail("Bridge returned an empty session.")
		return
	var boundary: Dictionary = adoption.get("session_boundary_record", {})
	if session.session_id != String(boundary.get("session_id", "")) or session.scenario_id != String(boundary.get("scenario_id", "")):
		_fail("Session ids do not match adoption boundary.")
		return
	if session.save_version != SessionStateStoreScript.SAVE_VERSION or session.launch_mode != SessionStateStoreScript.LAUNCH_MODE_SKIRMISH:
		_fail("Session save/launch boundary changed unexpectedly: save_version=%d launch_mode=%s" % [session.save_version, session.launch_mode])
		return
	if not bool(session.flags.get("native_random_map_package_session_adoption", false)):
		_fail("Session flags did not mark native package/session adoption.")
		return
	var boundary_flags: Dictionary = session.flags.get("generated_random_map_boundary", {})
	for key in ["authored_content_writeback", "campaign_adoption", "skirmish_browser_authored_listing", "content_service_generated_draft", "legacy_json_scenario_record"]:
		if bool(boundary_flags.get(key, true)):
			_fail("Session boundary flag %s was not false: %s" % [key, JSON.stringify(boundary_flags)])
			return
	if not bool(boundary_flags.get("runtime_call_site_adoption", false)):
		_fail("Session boundary did not mark active runtime call-site adoption: %s" % JSON.stringify(boundary_flags))
		return
	if not bool(boundary_flags.get("native_runtime_authoritative", false)) or bool(boundary_flags.get("full_parity_claim", true)):
		_fail("Session boundary should mark native runtime authority while keeping full parity gated: %s" % JSON.stringify(boundary_flags))
		return
	if session.overworld.get("map_package_ref", {}) != adoption.get("map_ref", {}) or session.overworld.get("scenario_package_ref", {}) != adoption.get("scenario_ref", {}):
		_fail("Session did not carry map/scenario package refs.")
		return
	var map_document: Variant = adoption.get("map_document", null)
	var expected_guard_count := 0
	var expected_artifact_count := 0
	if map_document != null:
		for index in range(int(map_document.get_object_count())):
			var object: Dictionary = map_document.get_object_by_index(index)
			if String(object.get("kind", "")) == "guard" or String(object.get("native_record_kind", "")) == "guard":
				expected_guard_count += 1
			if String(object.get("artifact_id", "")) != "":
				expected_artifact_count += 1
	if expected_guard_count > 0 and int(session.overworld.get("encounters", []).size()) < expected_guard_count:
		_fail("Session bridge dropped generated guard encounters: expected=%d actual=%d" % [expected_guard_count, int(session.overworld.get("encounters", []).size())])
		return
	if expected_artifact_count > 0 and int(session.overworld.get("artifact_nodes", []).size()) < expected_artifact_count:
		_fail("Session bridge dropped generated artifact rewards: expected=%d actual=%d" % [expected_artifact_count, int(session.overworld.get("artifact_nodes", []).size())])
		return

func _assert_visual_asset_bridge(session: SessionStateStoreScript.SessionData) -> Dictionary:
	var map_size_payload: Dictionary = session.overworld.get("map_size", {}) if session.overworld.get("map_size", {}) is Dictionary else {}
	var map_size := Vector2i(int(map_size_payload.get("width", map_size_payload.get("x", 0))), int(map_size_payload.get("height", map_size_payload.get("y", 0))))
	if map_size.x <= 0 or map_size.y <= 0:
		_fail("Session visual bridge missed map size: %s" % JSON.stringify(map_size_payload))
		return {}
	session.overworld["fog"] = _all_visible_fog(map_size.x, map_size.y)
	var view: Variant = OverworldMapViewScript.new()
	view.size = Vector2(960, 640)
	add_child(view)
	var summary := {}
	var encounter := _first_node(session.overworld.get("encounters", []))
	if not encounter.is_empty():
		summary["guard_encounter"] = await _assert_view_node_sprite(view, session, map_size, encounter, "has_visible_encounter", "hostile_camp", "guard encounter")
	var artifact := _first_node(session.overworld.get("artifact_nodes", []))
	if not artifact.is_empty():
		summary["artifact_reward"] = await _assert_view_node_sprite(view, session, map_size, artifact, "has_artifact", "adventurers_bundle", "artifact reward")
	remove_child(view)
	view.queue_free()
	if summary.is_empty():
		_fail("Session visual bridge did not expose guard or artifact nodes to validate.")
		return {}
	return summary

func _assert_view_node_sprite(view: Variant, session: SessionStateStoreScript.SessionData, map_size: Vector2i, node: Dictionary, presence_key: String, expected_asset_id: String, label: String) -> Dictionary:
	var tile := Vector2i(int(node.get("x", -1)), int(node.get("y", -1)))
	view.set_map_state(session, session.overworld.get("map", []), map_size, tile)
	await get_tree().process_frame
	var presentation: Dictionary = view.validation_tile_presentation(tile)
	if not bool(presentation.get(presence_key, false)):
		_fail("Visual bridge did not expose %s at tile %s: %s" % [label, tile, JSON.stringify(presentation)])
		return {}
	var art: Dictionary = presentation.get("art_presentation", {}) if presentation.get("art_presentation", {}) is Dictionary else {}
	var sprite_asset_ids: Array = art.get("sprite_asset_ids", []) if art.get("sprite_asset_ids", []) is Array else []
	if not bool(art.get("uses_asset_sprite", false)) or expected_asset_id not in sprite_asset_ids or bool(art.get("fallback_procedural_marker", true)):
		_fail("Visual bridge %s did not resolve to expected asset %s: %s" % [label, expected_asset_id, JSON.stringify(presentation)])
		return {}
	return {
		"tile": {"x": tile.x, "y": tile.y},
		"uses_asset_sprite": bool(art.get("uses_asset_sprite", false)),
		"sprite_asset_ids": sprite_asset_ids,
	}

func _first_node(nodes: Variant) -> Dictionary:
	if not (nodes is Array):
		return {}
	for node in nodes:
		if node is Dictionary:
			return node
	return {}

func _all_visible_fog(width: int, height: int) -> Dictionary:
	var visible := []
	var explored := []
	for _y in range(height):
		var visible_row := []
		var explored_row := []
		for _x in range(width):
			visible_row.append(true)
			explored_row.append(true)
		visible.append(visible_row)
		explored.append(explored_row)
	return {
		"visible_tiles": visible,
		"explored_tiles": explored,
		"visible_count": width * height,
		"explored_count": width * height,
		"total_tiles": width * height,
	}

func _fail(message: String) -> void:
	push_error("%s failed: %s" % [REPORT_ID, message])
	get_tree().quit(1)
