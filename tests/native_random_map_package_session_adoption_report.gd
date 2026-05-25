extends Node

const ScenarioSelectRulesScript = preload("res://scripts/core/ScenarioSelectRules.gd")
const SessionStateStoreScript = preload("res://scripts/core/SessionStateStore.gd")
const OverworldRulesScript = preload("res://scripts/core/OverworldRules.gd")
const NativeRandomMapPackageSessionBridgeScript = preload("res://scripts/persistence/NativeRandomMapPackageSessionBridge.gd")
const OverworldMapViewScript = preload("res://scenes/overworld/OverworldMapView.gd")

const REPORT_ID := "NATIVE_RANDOM_MAP_PACKAGE_SESSION_ADOPTION_REPORT"
const REPORT_SCHEMA_ID := "native_random_map_package_session_adoption_smoke_v1"
const FEATURE_GATE := "native_rmg_package_session_adoption_report"
const TARGET_TURNS := 30
const MIN_GENERATED_PACKAGE_PLAYER_COMPLETION_DAY := 24
const MIN_GENERATED_PACKAGE_ENEMY_COMPLETION_DAY := 24
const TARGET_TIER_COUNT := 7
const MAX_GENERATED_PACKAGE_COMMON_ROUTE_STEPS := 40
const MAX_GENERATED_PACKAGE_RARE_ROUTE_STEPS := 56
const GENERATED_PACKAGE_SOURCE_ROUTE_STEPS_PER_DAY := 12
const GENERATED_PACKAGE_GUARDED_SOURCE_EXTRA_DAYS := 1
const MAX_GENERATED_PACKAGE_SOURCE_ACQUISITION_DAY := 6
const COMMON_MARKET_RESOURCE_IDS := ["wood", "ore"]
const RARE_RESOURCE_IDS := [
	"aetherglass",
	"embergrain",
	"peatwax",
	"verdant_grafts",
	"brass_scrip",
	"memory_salt",
]
const GENERATED_TOWN_ECONOMY_BREADTH_CASES := [
	{"id": "small_land_seed_a", "seed": "native-rmg-economy-breadth-small-land-a-10184", "template_id": "translated_rmg_template_049_v1", "profile_id": "translated_rmg_profile_049_v1", "player_count": 3, "water_mode": "land", "underground": false, "size_class_id": "homm3_small"},
	{"id": "small_land_seed_b", "seed": "native-rmg-economy-breadth-small-land-b-10184", "template_id": "translated_rmg_template_049_v1", "profile_id": "translated_rmg_profile_049_v1", "player_count": 3, "water_mode": "land", "underground": false, "size_class_id": "homm3_small"},
	{"id": "small_land_seed_c", "seed": "native-rmg-economy-breadth-small-land-c-10184", "template_id": "translated_rmg_template_049_v1", "profile_id": "translated_rmg_profile_049_v1", "player_count": 3, "water_mode": "land", "underground": false, "size_class_id": "homm3_small"},
]

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
	var bridge_resource_stockpile := _assert_full_resource_stockpile(session, "direct bridge session")
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
	var active_resource_stockpile := _assert_full_resource_stockpile(active_session, "active disk package session")
	var generated_town_economy_surface := _assert_generated_town_economy_surface(active_session)
	if generated_town_economy_surface.is_empty():
		return
	var generated_town_economy_source_routes := _assert_generated_town_economy_source_routes(active_session)
	if generated_town_economy_source_routes.is_empty():
		return
	var generated_town_economy_breadth := _assert_generated_town_economy_breadth(service, bridge)
	if generated_town_economy_breadth.is_empty():
		return
	var generated_player_town_development_runway := _assert_generated_player_town_development_runway(active_session)
	if generated_player_town_development_runway.is_empty():
		return
	var generated_enemy_town_development_runway := _assert_generated_enemy_town_development_runway(active_setup)
	if generated_enemy_town_development_runway.is_empty():
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
		"bridge_resource_stockpile": bridge_resource_stockpile,
		"active_resource_stockpile": active_resource_stockpile,
		"generated_town_economy_surface": generated_town_economy_surface,
		"generated_town_economy_source_routes": generated_town_economy_source_routes,
		"generated_town_economy_breadth": generated_town_economy_breadth,
		"generated_player_town_development_runway": generated_player_town_development_runway,
		"generated_enemy_town_development_runway": generated_enemy_town_development_runway,
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
	var generation_status := String(generated.get("status", ""))
	if not (generation_status in ["owner_compared_translated_profile_supported", "h3maped_small_validated_package_ready"]) or String(generated.get("full_generation_status", "")) == "not_implemented":
		_fail("Native RMG status did not report supported package generation: %s" % JSON.stringify(generated))
		return
	if (String(generated.get("validation_status", "")) not in ["", "pass"]) or (generated.has("no_authored_writeback") and not bool(generated.get("no_authored_writeback", false))):
		_fail("Native RMG validation/no-writeback boundary failed: %s" % JSON.stringify(generated.get("validation_report", {})))
		return
	if bool(generated.get("full_parity_claim", false)):
		_fail("Native RMG must not claim full production parity: %s" % JSON.stringify(generated.get("provenance", {})))
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
	if not (String(report.get("adoption_status", "")) in ["runtime_authoritative_owner_compared_not_full_parity", "h3maped_small_package_session_production_ready_strict_small_land"]):
		_fail("Adoption report status must distinguish runtime authority from full parity: %s" % JSON.stringify(report))
		return
	var remaining: Array = report.get("remaining_parity_slices", []) if report.get("remaining_parity_slices", []) is Array else []
	if remaining.has("native-rmg-package-session-authoritative-replay-gate-10184") or not (remaining.has("native-rmg-full-homm3-parity-gate-10184") or remaining.has("full_homm3_style_parity_not_claimed")):
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
	var document_has_identity := String(map_document.get_source_kind()) == "generated" and String(map_document.get_map_id()) != "" and String(map_document.get_map_hash()) != ""
	var package_has_identity := String(adoption.get("map_ref", {}).get("map_id", "")) != "" and String(adoption.get("map_package_record", {}).get("package_hash", "")) != ""
	if not document_has_identity and not package_has_identity:
		_fail("MapDocument missed generated identity.")
		return
	if scenario_document.get_player_slots().size() != players or scenario_document.get_start_contract().is_empty():
		_fail("ScenarioDocument missed player slots/start contract.")
		return
	var start_contract: Dictionary = scenario_document.get_start_contract()
	if not (String(start_contract.get("start_contract_source", "")) in ["materialized_player_start_town_records", "h3maped_small_validated_map_document_payload"]):
		_fail("Start contract did not derive starts from materialized start towns: %s" % JSON.stringify(start_contract))
		return
	var contract_starts: Array = start_contract.get("player_starts", []) if start_contract.get("player_starts", []) is Array else []
	var contract_towns: Array = start_contract.get("player_start_towns", []) if start_contract.get("player_start_towns", []) is Array else []
	if contract_starts.size() != players or contract_towns.size() != players:
		_fail("Start contract did not expose one start town per player: %s" % JSON.stringify(start_contract))
		return
	var player_start := _player_owned_start_town(contract_towns)
	if player_start.is_empty():
		_fail("Start contract did not expose a player-owned starting town: %s" % JSON.stringify(start_contract))
		return
	var matching_contract_start := _contract_start_for_slot(contract_starts, int(player_start.get("player_slot", 0)))
	if matching_contract_start.is_empty() or int(matching_contract_start.get("x", -1)) != int(player_start.get("x", -2)) or int(matching_contract_start.get("y", -1)) != int(player_start.get("y", -2)):
		_fail("Contract player start is not anchored to the materialized player-owned town: start=%s town=%s" % [JSON.stringify(matching_contract_start), JSON.stringify(player_start)])
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

func _player_owned_start_town(start_towns: Array) -> Dictionary:
	for town in start_towns:
		if town is Dictionary and String(town.get("owner", "")) == "player":
			return town
	return {}

func _contract_start_for_slot(starts: Array, player_slot: int) -> Dictionary:
	for start in starts:
		if start is Dictionary and int(start.get("player_slot", 0)) == player_slot:
			return start
	return {}

func _expected_start_tile_for_town(town: Dictionary) -> Dictionary:
	for key in ["hero_start_tile", "runtime_start_tile", "visit_tile", "primary_tile"]:
		var tile: Dictionary = town.get(key, {}) if town.get(key, {}) is Dictionary else {}
		if not tile.is_empty():
			return {"x": int(tile.get("x", town.get("x", 0))), "y": int(tile.get("y", town.get("y", 0)))}
	return {"x": int(town.get("x", 0)), "y": int(town.get("y", 0))}

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
	var scenario_document_for_session: Variant = adoption.get("scenario_document", null)
	var session_start_towns := []
	if scenario_document_for_session != null:
		var session_start_contract: Dictionary = scenario_document_for_session.get_start_contract()
		session_start_towns = session_start_contract.get("player_start_towns", []) if session_start_contract.get("player_start_towns", []) is Array else []
	var owned_start_town := _player_owned_start_town(session_start_towns)
	var hero_position: Dictionary = session.overworld.get("hero_position", {}) if session.overworld.get("hero_position", {}) is Dictionary else {}
	var expected_session_start := _expected_start_tile_for_town(owned_start_town)
	if owned_start_town.is_empty() or int(hero_position.get("x", -1)) != int(expected_session_start.get("x", -2)) or int(hero_position.get("y", -1)) != int(expected_session_start.get("y", -2)):
		_fail("Session hero start is not anchored to the player-owned starting town: hero=%s town=%s" % [JSON.stringify(hero_position), JSON.stringify(owned_start_town)])
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

func _assert_full_resource_stockpile(session: SessionStateStoreScript.SessionData, label: String) -> Dictionary:
	var resources: Dictionary = session.overworld.get("resources", {}) if session != null and session.overworld.get("resources", {}) is Dictionary else {}
	for key in resources.keys():
		var resource_key := String(key)
		if not (resource_key in OverworldRulesScript.LIVE_STOCKPILE_RESOURCE_KEYS):
			_fail("%s carried unsupported stockpile resource %s: %s" % [label, resource_key, JSON.stringify(resources)])
			return {}
	for resource_key in OverworldRulesScript.LIVE_STOCKPILE_RESOURCE_KEYS:
		if not resources.has(resource_key):
			_fail("%s missed live stockpile resource %s: %s" % [label, resource_key, JSON.stringify(resources)])
			return {}
	if int(resources.get("gold", -1)) != 5000 or int(resources.get("wood", -1)) != 10 or int(resources.get("ore", -1)) != 10:
		_fail("%s changed generated package opening common resources: %s" % [label, JSON.stringify(resources)])
		return {}
	for resource_key in ["aetherglass", "embergrain", "peatwax", "verdant_grafts", "brass_scrip", "memory_salt"]:
		if int(resources.get(resource_key, -1)) != 0:
			_fail("%s should seed rare stockpiles at zero, not omit or prefill them: %s" % [label, JSON.stringify(resources)])
			return {}
	return {
		"live_stockpile_resource_ids": OverworldRulesScript.LIVE_STOCKPILE_RESOURCE_KEYS.duplicate(),
		"resource_count": OverworldRulesScript.LIVE_STOCKPILE_RESOURCE_KEYS.size(),
		"common_opening_resources": {
			"gold": int(resources.get("gold", 0)),
			"wood": int(resources.get("wood", 0)),
			"ore": int(resources.get("ore", 0)),
		},
		"rare_resources_seeded_at_zero": true,
	}

func _assert_generated_town_economy_surface(session: SessionStateStoreScript.SessionData, case_id: String = "", require_identity_diversity: bool = true) -> Dictionary:
	var towns: Array = session.overworld.get("towns", []) if session != null and session.overworld.get("towns", []) is Array else []
	var resource_nodes: Array = session.overworld.get("resource_nodes", []) if session != null and session.overworld.get("resource_nodes", []) is Array else []
	var resource_source_ids := _generated_resource_source_ids(resource_nodes)
	var rows := []
	var town_count := 0
	var player_town_count := 0
	var authored_town_template_count := 0
	var seven_tier_town_count := 0
	var rare_development_town_count := 0
	var player_rare_resource_ids := {}
	var generated_faction_ids := {}
	var generated_town_ids := {}
	var source_h3maped_faction_ids := {}
	for town_value in towns:
		if not (town_value is Dictionary):
			continue
		var town: Dictionary = town_value
		town_count += 1
		var town_id := String(town.get("town_id", ""))
		var town_template := ContentService.get_town(town_id)
		var faction_id := String(town.get("faction_id", town_template.get("faction_id", "")))
		var faction := ContentService.get_faction(faction_id)
		var profile: Dictionary = town_template.get("development_balance", {}) if town_template.get("development_balance", {}) is Dictionary else {}
		var buildable_ids := _string_array(town_template.get("buildable_building_ids", []))
		var starting_ids := _string_array(town_template.get("starting_building_ids", []))
		var unit_tiers := _unit_tiers_for_buildings(_merged_string_arrays(starting_ids, buildable_ids))
		var rare_resource_id := String(profile.get("rare_resource_id", ""))
		var owner := String(town.get("owner", ""))
		if not town_template.is_empty():
			authored_town_template_count += 1
			generated_town_ids[town_id] = true
		if not faction.is_empty():
			generated_faction_ids[faction_id] = true
		var source_h3maped_faction_id := String(town.get("source_h3maped_faction_id", ""))
		if source_h3maped_faction_id != "":
			source_h3maped_faction_ids[source_h3maped_faction_id] = true
		if unit_tiers.size() == 7:
			seven_tier_town_count += 1
		if rare_resource_id != "" and rare_resource_id in OverworldRulesScript.LIVE_STOCKPILE_RESOURCE_KEYS and not (rare_resource_id in ["gold", "wood", "ore"]):
			rare_development_town_count += 1
			if owner == "player":
				player_rare_resource_ids[rare_resource_id] = true
		if owner == "player":
			player_town_count += 1
		rows.append({
			"placement_id": String(town.get("placement_id", "")),
			"town_id": town_id,
			"owner": owner,
			"faction_id": faction_id,
			"faction_found": not faction.is_empty(),
			"source_h3maped_faction_id": source_h3maped_faction_id,
			"source_package_town_id": String(town.get("source_package_town_id", "")),
			"authored_town_template": not town_template.is_empty(),
			"target_building_count": buildable_ids.size(),
			"unit_tier_count": unit_tiers.size(),
			"unit_tiers": _sorted_int_keys(unit_tiers),
			"rare_resource_id": rare_resource_id,
		})
	var required_player_resource_ids := ["gold", "wood", "ore"]
	for rare_id in _sorted_string_keys(player_rare_resource_ids):
		required_player_resource_ids.append(rare_id)
	var missing_player_resource_sources := []
	for resource_id in required_player_resource_ids:
		if not resource_source_ids.has(resource_id):
			missing_player_resource_sources.append(resource_id)
	var status := "pass"
	if town_count < 3 or player_town_count < 1 \
			or authored_town_template_count != town_count \
			or seven_tier_town_count != town_count \
			or rare_development_town_count != town_count \
			or (require_identity_diversity and generated_faction_ids.size() < 3) \
			or (require_identity_diversity and generated_town_ids.size() < 3) \
			or resource_nodes.is_empty() \
			or not missing_player_resource_sources.is_empty():
		status = "fail"
	var surface := {
		"schema": "generated_package_town_economy_surface_v1",
		"status": status,
		"case_id": case_id,
		"package_session_scope": "strict_small_36x36_one_level_land_only",
		"town_count": town_count,
		"player_town_count": player_town_count,
		"authored_town_template_count": authored_town_template_count,
		"seven_tier_town_count": seven_tier_town_count,
		"rare_development_town_count": rare_development_town_count,
		"unique_faction_count": generated_faction_ids.size(),
		"unique_town_template_count": generated_town_ids.size(),
		"generated_faction_ids": _sorted_string_keys(generated_faction_ids),
		"generated_town_ids": _sorted_string_keys(generated_town_ids),
		"source_h3maped_faction_ids": _sorted_string_keys(source_h3maped_faction_ids),
		"generated_resource_node_count": resource_nodes.size(),
		"generated_resource_source_ids": _sorted_string_keys(resource_source_ids),
		"player_required_resource_ids": required_player_resource_ids,
		"missing_player_resource_sources": missing_player_resource_sources,
		"town_rows": rows,
	}
	if status != "pass":
		_fail("Generated package town economy surface failed: %s" % JSON.stringify(surface))
		return {}
	return surface

func _assert_generated_town_economy_breadth(service: Variant, bridge: Variant) -> Dictionary:
	var rows := []
	var map_package_hashes := {}
	var scenario_package_hashes := {}
	var generated_faction_ids := {}
	var generated_town_ids := {}
	var generated_resource_source_ids := {}
	var player_required_resource_ids := {}
	var source_h3maped_faction_ids := {}
	var passed_case_count := 0
	var all_common_source_case_count := 0
	var player_required_source_case_count := 0
	var route_pressure_case_count := 0
	var guarded_rare_source_route_breadth_case_count := 0
	var total_town_count := 0
	var total_resource_node_count := 0
	var total_route_town_case_count := 0
	var total_resource_route_case_count := 0
	var total_reachable_route_case_count := 0
	var total_guarded_source_route_case_count := 0
	var total_guarded_rare_source_route_case_count := 0
	var max_common_route_steps := 0
	var max_rare_route_steps := 0
	var max_source_acquisition_day := 0
	for case_record in GENERATED_TOWN_ECONOMY_BREADTH_CASES:
		var case_id := String(case_record.get("id", ""))
		var config := ScenarioSelectRulesScript.build_random_map_player_config(
			String(case_record.get("seed", "")),
			String(case_record.get("template_id", "")),
			String(case_record.get("profile_id", "")),
			int(case_record.get("player_count", 3)),
			String(case_record.get("water_mode", "land")),
			bool(case_record.get("underground", false)),
			String(case_record.get("size_class_id", "homm3_small"))
		)
		var generated: Dictionary = service.generate_random_map(config, {
			"startup_path": "generated_town_economy_breadth_%s" % case_id,
		})
		_assert_native_generation(generated)
		var adoption: Dictionary = service.convert_generated_payload(generated, {
			"feature_gate": FEATURE_GATE,
			"session_save_version": SessionStateStoreScript.SAVE_VERSION,
			"scenario_id": "native_generated_town_economy_breadth_%s" % case_id,
		})
		_assert_adoption_shape(adoption, 36, 36, 1, int(case_record.get("player_count", 3)))
		var case_session: SessionStateStoreScript.SessionData = bridge.build_session_from_adoption(adoption, "normal")
		if case_session == null or case_session.session_id == "":
			_fail("Generated package town economy breadth case %s did not build a session." % case_id)
			return {}
		var surface := _assert_generated_town_economy_surface(case_session, case_id, false)
		if surface.is_empty():
			return {}
		var route_surface := _assert_generated_town_economy_source_routes(case_session)
		if route_surface.is_empty():
			return {}
		var map_hash := String(adoption.get("map_package_record", {}).get("package_hash", ""))
		var scenario_hash := String(adoption.get("scenario_package_record", {}).get("package_hash", ""))
		if map_hash != "":
			map_package_hashes[map_hash] = true
		if scenario_hash != "":
			scenario_package_hashes[scenario_hash] = true
		if String(surface.get("status", "")) == "pass":
			passed_case_count += 1
		total_town_count += int(surface.get("town_count", 0))
		total_resource_node_count += int(surface.get("generated_resource_node_count", 0))
		total_route_town_case_count += int(route_surface.get("town_case_count", 0))
		total_resource_route_case_count += int(route_surface.get("resource_route_case_count", 0))
		total_reachable_route_case_count += int(route_surface.get("reachable_route_case_count", 0))
		total_guarded_source_route_case_count += int(route_surface.get("guarded_source_route_case_count", 0))
		total_guarded_rare_source_route_case_count += int(route_surface.get("guarded_rare_source_route_case_count", 0))
		max_common_route_steps = max(max_common_route_steps, int(route_surface.get("max_common_route_steps", 0)))
		max_rare_route_steps = max(max_rare_route_steps, int(route_surface.get("max_rare_route_steps", 0)))
		max_source_acquisition_day = max(max_source_acquisition_day, int(route_surface.get("max_source_acquisition_day", 0)))
		if String(route_surface.get("status", "")) == "pass" \
				and int(route_surface.get("reachable_route_case_count", 0)) == int(route_surface.get("resource_route_case_count", -1)) \
				and int(route_surface.get("guarded_source_route_case_count", 0)) >= int(route_surface.get("town_case_count", 0)):
			route_pressure_case_count += 1
		if String(route_surface.get("status", "")) == "pass" \
				and int(route_surface.get("guarded_rare_source_route_case_count", 0)) == int(route_surface.get("town_case_count", -1)):
			guarded_rare_source_route_breadth_case_count += 1
		var case_resource_ids := {}
		for resource_id_value in surface.get("generated_resource_source_ids", []):
			var resource_id := String(resource_id_value)
			generated_resource_source_ids[resource_id] = true
			case_resource_ids[resource_id] = true
		var common_covered := true
		for resource_id in ["gold", "wood", "ore"]:
			if not bool(case_resource_ids.get(resource_id, false)):
				common_covered = false
		if common_covered:
			all_common_source_case_count += 1
		var player_required_covered := true
		for resource_id_value in surface.get("player_required_resource_ids", []):
			var resource_id := String(resource_id_value)
			player_required_resource_ids[resource_id] = true
			if not bool(case_resource_ids.get(resource_id, false)):
				player_required_covered = false
		if player_required_covered and surface.get("missing_player_resource_sources", []).is_empty():
			player_required_source_case_count += 1
		for faction_id_value in surface.get("generated_faction_ids", []):
			generated_faction_ids[String(faction_id_value)] = true
		for town_id_value in surface.get("generated_town_ids", []):
			generated_town_ids[String(town_id_value)] = true
		for source_id_value in surface.get("source_h3maped_faction_ids", []):
			source_h3maped_faction_ids[String(source_id_value)] = true
		rows.append({
			"case_id": case_id,
			"seed": String(case_record.get("seed", "")),
			"template_id": String(case_record.get("template_id", "")),
			"profile_id": String(case_record.get("profile_id", "")),
			"map_package_hash": map_hash,
			"scenario_package_hash": scenario_hash,
			"surface": surface,
			"source_routes": route_surface,
		})
	var case_count := rows.size()
	var status := "pass"
	if case_count < 3 \
			or passed_case_count != case_count \
			or map_package_hashes.size() != case_count \
			or scenario_package_hashes.size() != case_count \
			or all_common_source_case_count != case_count \
			or player_required_source_case_count != case_count \
			or route_pressure_case_count != case_count \
			or guarded_rare_source_route_breadth_case_count != case_count \
			or total_town_count < case_count * 3 \
			or total_route_town_case_count < case_count * 3 \
			or total_resource_route_case_count != total_route_town_case_count * 3 \
			or total_reachable_route_case_count != total_resource_route_case_count \
			or total_guarded_source_route_case_count < total_route_town_case_count \
			or total_guarded_rare_source_route_case_count != total_route_town_case_count \
			or max_common_route_steps > MAX_GENERATED_PACKAGE_COMMON_ROUTE_STEPS \
			or max_rare_route_steps > MAX_GENERATED_PACKAGE_RARE_ROUTE_STEPS \
			or max_source_acquisition_day > MAX_GENERATED_PACKAGE_SOURCE_ACQUISITION_DAY \
			or generated_faction_ids.size() < 3 \
			or generated_town_ids.size() < 3:
		status = "fail"
	var breadth := {
		"schema": "generated_package_town_economy_breadth_v1",
		"status": status,
		"package_session_scope": "strict_small_36x36_one_level_land_multi_seed",
		"case_count": case_count,
		"passed_case_count": passed_case_count,
		"distinct_map_package_hash_count": map_package_hashes.size(),
		"distinct_scenario_package_hash_count": scenario_package_hashes.size(),
		"all_common_source_case_count": all_common_source_case_count,
		"player_required_source_case_count": player_required_source_case_count,
		"route_pressure_case_count": route_pressure_case_count,
		"guarded_rare_source_route_breadth_case_count": guarded_rare_source_route_breadth_case_count,
		"total_town_count": total_town_count,
		"total_resource_node_count": total_resource_node_count,
		"total_route_town_case_count": total_route_town_case_count,
		"total_resource_route_case_count": total_resource_route_case_count,
		"total_reachable_route_case_count": total_reachable_route_case_count,
		"total_guarded_source_route_case_count": total_guarded_source_route_case_count,
		"total_guarded_rare_source_route_case_count": total_guarded_rare_source_route_case_count,
		"max_common_route_steps": max_common_route_steps,
		"max_rare_route_steps": max_rare_route_steps,
		"max_source_acquisition_day": max_source_acquisition_day,
		"common_route_step_limit": MAX_GENERATED_PACKAGE_COMMON_ROUTE_STEPS,
		"rare_route_step_limit": MAX_GENERATED_PACKAGE_RARE_ROUTE_STEPS,
		"source_acquisition_day_limit": MAX_GENERATED_PACKAGE_SOURCE_ACQUISITION_DAY,
		"unique_faction_count": generated_faction_ids.size(),
		"unique_town_template_count": generated_town_ids.size(),
		"generated_faction_ids": _sorted_string_keys(generated_faction_ids),
		"generated_town_ids": _sorted_string_keys(generated_town_ids),
		"source_h3maped_faction_ids": _sorted_string_keys(source_h3maped_faction_ids),
		"generated_resource_source_ids": _sorted_string_keys(generated_resource_source_ids),
		"player_required_resource_ids": _sorted_string_keys(player_required_resource_ids),
		"cases": rows,
	}
	if status != "pass":
		_fail("Generated package town economy breadth failed: %s" % JSON.stringify(breadth))
		return {}
	return breadth

func _assert_generated_town_economy_source_routes(session: SessionStateStoreScript.SessionData) -> Dictionary:
	var towns := _player_and_enemy_towns(session)
	var rows := []
	var town_case_count := 0
	var player_town_case_count := 0
	var enemy_town_case_count := 0
	var resource_route_case_count := 0
	var reachable_route_case_count := 0
	var guarded_source_route_case_count := 0
	var guarded_common_source_route_case_count := 0
	var guarded_rare_source_route_case_count := 0
	var guarded_town_case_count := 0
	var common_route_steps := []
	var rare_route_steps := []
	var acquisition_days := []
	var required_rare_resource_ids := {}
	for town in towns:
		var row := _run_generated_town_source_route_case(session, town)
		rows.append(row)
		town_case_count += 1
		if String(row.get("owner", "")) == "player":
			player_town_case_count += 1
		elif String(row.get("owner", "")) == "enemy":
			enemy_town_case_count += 1
		resource_route_case_count += int(row.get("resource_route_case_count", 0))
		reachable_route_case_count += int(row.get("reachable_route_case_count", 0))
		guarded_source_route_case_count += int(row.get("guarded_source_route_case_count", 0))
		guarded_common_source_route_case_count += int(row.get("guarded_common_source_route_case_count", 0))
		guarded_rare_source_route_case_count += int(row.get("guarded_rare_source_route_case_count", 0))
		if int(row.get("guarded_source_route_case_count", 0)) > 0:
			guarded_town_case_count += 1
		var rare_id := String(row.get("rare_resource_id", ""))
		if rare_id != "":
			required_rare_resource_ids[rare_id] = true
		for route_value in row.get("routes", []):
			if not (route_value is Dictionary):
				continue
			var route: Dictionary = route_value
			if not bool(route.get("reachable", false)):
				continue
			var resource_id := String(route.get("resource_id", ""))
			if resource_id in COMMON_MARKET_RESOURCE_IDS:
				common_route_steps.append(int(route.get("route_steps", 0)))
			elif resource_id != "":
				rare_route_steps.append(int(route.get("route_steps", 0)))
			acquisition_days.append(int(route.get("source_acquisition_day", 0)))
	var max_common_steps: int = int(common_route_steps.max()) if not common_route_steps.is_empty() else 0
	var max_rare_steps: int = int(rare_route_steps.max()) if not rare_route_steps.is_empty() else 0
	var max_acquisition_day: int = int(acquisition_days.max()) if not acquisition_days.is_empty() else 0
	var status := "pass"
	if town_case_count < 3 \
			or player_town_case_count < 1 \
			or enemy_town_case_count < 2 \
			or resource_route_case_count != town_case_count * 3 \
			or reachable_route_case_count != resource_route_case_count \
			or guarded_town_case_count != town_case_count \
			or guarded_source_route_case_count < town_case_count \
			or guarded_rare_source_route_case_count != town_case_count \
			or max_common_steps > MAX_GENERATED_PACKAGE_COMMON_ROUTE_STEPS \
			or max_rare_steps > MAX_GENERATED_PACKAGE_RARE_ROUTE_STEPS \
			or max_acquisition_day > MAX_GENERATED_PACKAGE_SOURCE_ACQUISITION_DAY:
		status = "fail"
	var surface := {
		"schema": "generated_package_town_economy_source_routes_v1",
		"status": status,
		"package_session_scope": "strict_small_36x36_one_level_land_only",
		"town_case_count": town_case_count,
		"player_town_case_count": player_town_case_count,
		"enemy_town_case_count": enemy_town_case_count,
		"resource_route_case_count": resource_route_case_count,
		"reachable_route_case_count": reachable_route_case_count,
		"guarded_source_route_case_count": guarded_source_route_case_count,
		"guarded_common_source_route_case_count": guarded_common_source_route_case_count,
		"guarded_rare_source_route_case_count": guarded_rare_source_route_case_count,
		"guarded_town_case_count": guarded_town_case_count,
		"required_common_resource_ids": COMMON_MARKET_RESOURCE_IDS,
		"required_rare_resource_ids": _sorted_string_keys(required_rare_resource_ids),
		"max_common_route_steps": max_common_steps,
		"max_rare_route_steps": max_rare_steps,
		"max_source_acquisition_day": max_acquisition_day,
		"common_route_step_limit": MAX_GENERATED_PACKAGE_COMMON_ROUTE_STEPS,
		"rare_route_step_limit": MAX_GENERATED_PACKAGE_RARE_ROUTE_STEPS,
		"route_steps_per_day": GENERATED_PACKAGE_SOURCE_ROUTE_STEPS_PER_DAY,
		"guarded_source_extra_days": GENERATED_PACKAGE_GUARDED_SOURCE_EXTRA_DAYS,
		"source_acquisition_day_limit": MAX_GENERATED_PACKAGE_SOURCE_ACQUISITION_DAY,
		"town_rows": rows,
	}
	if status != "pass":
		_fail("Generated package town economy source routes failed: %s" % JSON.stringify(surface))
		return {}
	return surface

func _run_generated_town_source_route_case(session: SessionStateStoreScript.SessionData, town: Dictionary) -> Dictionary:
	var placement_id := String(town.get("placement_id", ""))
	var town_id := String(town.get("town_id", ""))
	var town_template := ContentService.get_town(town_id)
	var profile: Dictionary = town_template.get("development_balance", {}) if town_template.get("development_balance", {}) is Dictionary else {}
	var rare_id := String(profile.get("rare_resource_id", ""))
	var required_resource_ids := COMMON_MARKET_RESOURCE_IDS.duplicate()
	required_resource_ids.append(rare_id)
	var start_tile := _generated_town_route_start_tile(town)
	var route_rows := []
	var errors := []
	var reachable_count := 0
	var guarded_source_route_count := 0
	var guarded_common_source_route_count := 0
	var guarded_rare_source_route_count := 0
	var acquisition_days := []
	for resource_id_value in required_resource_ids:
		var resource_id := String(resource_id_value)
		var route_row := _best_generated_resource_route(session, start_tile, resource_id)
		route_rows.append(route_row)
		if bool(route_row.get("reachable", false)):
			reachable_count += 1
			acquisition_days.append(int(route_row.get("source_acquisition_day", 0)))
		else:
			errors.append("%s source unreachable" % resource_id)
		if bool(route_row.get("guarded", false)):
			guarded_source_route_count += 1
			if resource_id in COMMON_MARKET_RESOURCE_IDS:
				guarded_common_source_route_count += 1
			else:
				guarded_rare_source_route_count += 1
				if not bool(route_row.get("guard_blocks_claim", false)):
					errors.append("%s guarded rare source does not block claiming before guard clear" % resource_id)
		var route_steps := int(route_row.get("route_steps", 999999))
		var max_steps := MAX_GENERATED_PACKAGE_COMMON_ROUTE_STEPS if resource_id in COMMON_MARKET_RESOURCE_IDS else MAX_GENERATED_PACKAGE_RARE_ROUTE_STEPS
		if route_steps > max_steps:
			errors.append("%s source route too long: %d > %d" % [resource_id, route_steps, max_steps])
		if int(route_row.get("source_acquisition_day", 999999)) > MAX_GENERATED_PACKAGE_SOURCE_ACQUISITION_DAY:
			errors.append("%s source acquisition day too late: %d > %d" % [resource_id, int(route_row.get("source_acquisition_day", 999999)), MAX_GENERATED_PACKAGE_SOURCE_ACQUISITION_DAY])
	if guarded_source_route_count < 1:
		errors.append("town has no guarded generated economy source route")
	if guarded_rare_source_route_count < 1:
		errors.append("town has no guarded generated rare economy source route")
	return {
		"ok": errors.is_empty() and route_rows.size() == 3,
		"owner": String(town.get("owner", "")),
		"town_placement_id": placement_id,
		"town_id": town_id,
		"faction_id": String(town.get("faction_id", town_template.get("faction_id", ""))),
		"rare_resource_id": rare_id,
		"start_tile": _generated_tile_payload(start_tile),
		"resource_route_case_count": route_rows.size(),
		"reachable_route_case_count": reachable_count,
		"guarded_source_route_case_count": guarded_source_route_count,
		"guarded_common_source_route_case_count": guarded_common_source_route_count,
		"guarded_rare_source_route_case_count": guarded_rare_source_route_count,
		"max_source_acquisition_day": int(acquisition_days.max()) if not acquisition_days.is_empty() else 0,
		"routes": route_rows,
		"errors": errors,
		"error": "; ".join(errors),
	}

func _best_generated_resource_route(session: SessionStateStoreScript.SessionData, start_tile: Vector2i, resource_id: String) -> Dictionary:
	var candidates := []
	for node_value in session.overworld.get("resource_nodes", []):
		if not (node_value is Dictionary):
			continue
		var node: Dictionary = node_value
		var output := _generated_resource_node_output(node)
		if int(output.get(resource_id, 0)) <= 0:
			continue
		var target_tile := _generated_resource_route_target_tile(node)
		var route := _find_generated_route(session, start_tile, target_tile)
		var route_steps: int = max(0, route.size() - 1) if not route.is_empty() else 999999
		var guarded := _generated_resource_source_has_guard(session, node)
		var guard_blocks_claim := _generated_resource_source_guard_blocks_claim(session, node) if guarded else false
		var acquisition_day: int = _generated_source_acquisition_day(route_steps, guarded) if not route.is_empty() else 999999
		var row := {
			"resource_id": resource_id,
			"placement_id": String(node.get("placement_id", "")),
			"site_id": String(node.get("site_id", "")),
			"site_name": String(ContentService.get_resource_site(String(node.get("site_id", ""))).get("name", "")),
			"target_tile": _generated_tile_payload(target_tile),
			"output": output,
			"reachable": not route.is_empty(),
			"route_steps": route_steps,
			"route_tiles": _generated_route_payload(route),
			"guarded": guarded,
			"guard_blocks_claim": guard_blocks_claim,
			"source_acquisition_day": acquisition_day,
			"route_steps_per_day": GENERATED_PACKAGE_SOURCE_ROUTE_STEPS_PER_DAY,
			"guarded_source_extra_days": GENERATED_PACKAGE_GUARDED_SOURCE_EXTRA_DAYS if guarded else 0,
		}
		candidates.append(row)
	if candidates.is_empty():
		return {
			"resource_id": resource_id,
			"reachable": false,
			"route_steps": 999999,
			"source_acquisition_day": 999999,
			"error": "no generated resource source",
		}
	candidates.sort_custom(func(left: Dictionary, right: Dictionary) -> bool:
		if bool(left.get("reachable", false)) != bool(right.get("reachable", false)):
			return bool(left.get("reachable", false))
		return int(left.get("route_steps", 999999)) < int(right.get("route_steps", 999999))
	)
	var best: Dictionary = candidates[0]
	best["candidate_count"] = candidates.size()
	best["reachable_candidate_count"] = _generated_reachable_candidate_count(candidates)
	return best

func _generated_source_acquisition_day(route_steps: int, guarded: bool) -> int:
	var acquisition_day: int = max(1, int(ceil(float(route_steps) / float(GENERATED_PACKAGE_SOURCE_ROUTE_STEPS_PER_DAY))))
	if guarded:
		acquisition_day += GENERATED_PACKAGE_GUARDED_SOURCE_EXTRA_DAYS
	return acquisition_day

func _find_generated_route(session: SessionStateStoreScript.SessionData, start_tile: Vector2i, target_tile: Vector2i) -> Array:
	var map_size := OverworldRules.derive_map_size(session)
	if not _generated_in_bounds(start_tile, map_size) or not _generated_in_bounds(target_tile, map_size):
		return []
	var start_key := _generated_tile_key(start_tile)
	var queue := [start_tile]
	var visited := {start_key: true}
	var parent := {}
	var head := 0
	while head < queue.size():
		var current: Vector2i = queue[head]
		head += 1
		if current == target_tile:
			return _reconstruct_generated_route(parent, start_tile, target_tile)
		for neighbor in _generated_route_neighbors(current):
			if not _generated_in_bounds(neighbor, map_size):
				continue
			var neighbor_key := _generated_tile_key(neighbor)
			if bool(visited.get(neighbor_key, false)):
				continue
			if OverworldRules.tile_step_cuts_blocked_corner(session, current, neighbor):
				continue
			var is_destination: bool = neighbor == target_tile
			if OverworldRules.tile_is_blocked(session, neighbor.x, neighbor.y) and not (is_destination and OverworldRules.tile_is_actionable_route_destination(session, neighbor.x, neighbor.y)):
				continue
			if not is_destination and OverworldRules.tile_has_route_interaction(session, neighbor.x, neighbor.y):
				continue
			visited[neighbor_key] = true
			parent[neighbor_key] = current
			queue.append(neighbor)
	return []

func _reconstruct_generated_route(parent: Dictionary, start_tile: Vector2i, target_tile: Vector2i) -> Array:
	var route := [target_tile]
	var current := target_tile
	var guard := 0
	while current != start_tile and guard < 10000:
		guard += 1
		var current_key := _generated_tile_key(current)
		if not parent.has(current_key):
			return []
		current = parent[current_key]
		route.push_front(current)
	return route

func _generated_route_neighbors(tile: Vector2i) -> Array:
	return [
		Vector2i(tile.x - 1, tile.y - 1),
		Vector2i(tile.x, tile.y - 1),
		Vector2i(tile.x + 1, tile.y - 1),
		Vector2i(tile.x - 1, tile.y),
		Vector2i(tile.x + 1, tile.y),
		Vector2i(tile.x - 1, tile.y + 1),
		Vector2i(tile.x, tile.y + 1),
		Vector2i(tile.x + 1, tile.y + 1),
	]

func _generated_resource_node_output(node: Dictionary) -> Dictionary:
	var site := ContentService.get_resource_site(String(node.get("site_id", "")))
	var result := {}
	for bucket in [site.get("claim_rewards", site.get("rewards", {})), site.get("control_income", {})]:
		if not (bucket is Dictionary):
			continue
		for key in bucket.keys():
			var resource_id := String(key)
			if resource_id == "experience" or resource_id == "":
				continue
			result[resource_id] = int(result.get(resource_id, 0)) + int(bucket.get(key, 0))
	return result

func _generated_resource_route_target_tile(node: Dictionary) -> Vector2i:
	for key in ["visit_tile", "primary_tile", "action_tile"]:
		var tile: Dictionary = node.get(key, {}) if node.get(key, {}) is Dictionary else {}
		if not tile.is_empty():
			return Vector2i(int(tile.get("x", node.get("x", 0))), int(tile.get("y", node.get("y", 0))))
	for key in ["package_visit_tiles", "action_tiles", "package_action_tiles", "approach_tiles"]:
		var tiles: Array = node.get(key, []) if node.get(key, []) is Array else []
		for tile_value in tiles:
			if tile_value is Dictionary:
				return Vector2i(int(tile_value.get("x", node.get("x", 0))), int(tile_value.get("y", node.get("y", 0))))
	return Vector2i(int(node.get("x", 0)), int(node.get("y", 0)))

func _generated_resource_source_has_guard(session: SessionStateStoreScript.SessionData, node: Dictionary) -> bool:
	var placement_id := String(node.get("placement_id", ""))
	for encounter_value in session.overworld.get("encounters", []):
		if not (encounter_value is Dictionary):
			continue
		var encounter: Dictionary = encounter_value
		if OverworldRules.is_encounter_resolved(session, encounter):
			continue
		if String(encounter.get("target_kind", "")) == "resource" and String(encounter.get("target_placement_id", "")) == placement_id:
			return true
		var dx: int = abs(int(encounter.get("x", 0)) - int(node.get("x", 0)))
		var dy: int = abs(int(encounter.get("y", 0)) - int(node.get("y", 0)))
		if max(dx, dy) <= 1:
			return true
	return false

func _generated_resource_source_guard_blocks_claim(session: SessionStateStoreScript.SessionData, node: Dictionary) -> bool:
	var copy := SessionStateStoreScript.SessionData.new()
	copy.from_dict(session.to_dict())
	var target_tile := _generated_resource_route_target_tile(node)
	copy.overworld["hero_position"] = {"x": target_tile.x, "y": target_tile.y}
	var hero: Dictionary = copy.overworld.get("hero", {}) if copy.overworld.get("hero", {}) is Dictionary else {}
	hero["position"] = {"x": target_tile.x, "y": target_tile.y}
	copy.overworld["hero"] = hero
	var player_heroes: Array = copy.overworld.get("player_heroes", []) if copy.overworld.get("player_heroes", []) is Array else []
	for index in range(player_heroes.size()):
		if not (player_heroes[index] is Dictionary):
			continue
		var player_hero: Dictionary = player_heroes[index]
		if String(player_hero.get("id", "")) == String(copy.hero_id) or bool(player_hero.get("is_primary", false)):
			player_hero["position"] = {"x": target_tile.x, "y": target_tile.y}
			player_hero["is_active"] = true
			player_heroes[index] = player_hero
			break
	copy.overworld["player_heroes"] = player_heroes
	OverworldRules.normalize_overworld_state_for_runtime(copy)
	var result := OverworldRules.collect_active_resource(copy)
	return not bool(result.get("ok", false)) and String(result.get("message", "")).contains("Clear")

func _player_and_enemy_towns(session: SessionStateStoreScript.SessionData) -> Array:
	var result := []
	var towns: Array = session.overworld.get("towns", []) if session != null and session.overworld.get("towns", []) is Array else []
	for town_value in towns:
		if town_value is Dictionary and String(town_value.get("owner", "")) in ["player", "enemy"]:
			result.append(town_value)
	return result

func _generated_town_route_start_tile(town: Dictionary) -> Vector2i:
	for key in ["hero_start_tile", "runtime_start_tile", "visit_tile", "primary_tile"]:
		var tile: Dictionary = town.get(key, {}) if town.get(key, {}) is Dictionary else {}
		if not tile.is_empty():
			return Vector2i(int(tile.get("x", town.get("x", 0))), int(tile.get("y", town.get("y", 0))))
	for key in ["package_visit_tiles", "approach_tiles"]:
		var tiles: Array = town.get(key, []) if town.get(key, []) is Array else []
		for tile_value in tiles:
			if tile_value is Dictionary:
				return Vector2i(int(tile_value.get("x", town.get("x", 0))), int(tile_value.get("y", town.get("y", 0))))
	return Vector2i(int(town.get("x", 0)), int(town.get("y", 0)))

func _generated_reachable_candidate_count(candidates: Array) -> int:
	var count := 0
	for candidate in candidates:
		if candidate is Dictionary and bool(candidate.get("reachable", false)):
			count += 1
	return count

func _generated_in_bounds(tile: Vector2i, map_size: Vector2i) -> bool:
	return tile.x >= 0 and tile.y >= 0 and tile.x < map_size.x and tile.y < map_size.y

func _generated_tile_key(tile: Vector2i) -> String:
	return "%d,%d" % [tile.x, tile.y]

func _generated_tile_payload(tile: Vector2i) -> Dictionary:
	return {"x": tile.x, "y": tile.y}

func _generated_route_payload(route: Array) -> Array:
	var payload := []
	for tile in route:
		if tile is Vector2i:
			payload.append(_generated_tile_payload(tile))
	return payload

func _assert_generated_player_town_development_runway(session: SessionStateStoreScript.SessionData) -> Dictionary:
	var player_town := _player_town(session)
	if player_town.is_empty():
		_fail("Generated package session did not expose a player town for development runway.")
		return {}
	var placement_id := String(player_town.get("placement_id", ""))
	var town_id := String(player_town.get("town_id", ""))
	var town_template := ContentService.get_town(town_id)
	var faction_id := String(player_town.get("faction_id", town_template.get("faction_id", "")))
	var faction := ContentService.get_faction(faction_id)
	var profile: Dictionary = town_template.get("development_balance", {}) if town_template.get("development_balance", {}) is Dictionary else {}
	var target_turns: int = min(TARGET_TURNS, int(profile.get("target_complete_turns", TARGET_TURNS)))
	var target_buildings := _string_array(town_template.get("buildable_building_ids", []))
	if town_template.is_empty() or faction.is_empty() or target_buildings.is_empty():
		_fail("Generated package player town development runway missed authored town/faction targets: town=%s faction=%s targets=%d" % [town_id, faction_id, target_buildings.size()])
		return {}
	if String(profile.get("rare_resource_id", "")) not in RARE_RESOURCE_IDS:
		_fail("Generated package player town missed live rare development profile: %s" % JSON.stringify(profile))
		return {}

	session.game_state = "town"
	session.scenario_status = "in_progress"
	var select_result := _set_active_town(session, placement_id)
	if not bool(select_result.get("ok", false)):
		_fail("Generated package player town could not be selected: %s" % String(select_result.get("message", "")))
		return {}

	var required_resource_ids := _required_build_resource_ids(target_buildings)
	var source_evidence := _secure_development_sources(session, required_resource_ids)
	var initial_missing_buildings := _missing_buildings(session, placement_id, target_buildings)
	var signature_order := _signature_order(faction)
	var build_log := []
	var stalled_days := []
	var rare_spend_events := []
	var same_day_reject_ok := false
	var build_actions_after_build_blocked := false
	var market_common_only := true
	var economy_day_advance_count := 0
	var post_completion_economy_day_count := 0

	for _turn in range(target_turns):
		_set_active_town(session, placement_id)
		var selected_id := _select_building_id(session, placement_id, target_buildings, signature_order)
		if selected_id == "":
			stalled_days.append({
				"day": int(session.day),
				"reason": "no_affordable_build_action",
				"resources": _resources(session),
				"open_buildings": _open_building_ids(_town(session, placement_id), target_buildings),
			})
		else:
			var before_resources := _resources(session)
			var selected_building := ContentService.get_building(selected_id)
			var build_result: Dictionary = OverworldRules.build_in_active_town(session, selected_id)
			if not bool(build_result.get("ok", false)):
				stalled_days.append({
					"day": int(session.day),
					"reason": "build_failed",
					"building_id": selected_id,
					"message": String(build_result.get("message", "")),
				})
			else:
				var after_resources := _resources(session)
				var rare_delta := _rare_resource_spend(selected_building.get("cost", {}), before_resources, after_resources)
				if not rare_delta.is_empty():
					rare_spend_events.append({
						"day": int(session.day),
						"building_id": selected_id,
						"spent": rare_delta,
					})
				var same_day_result: Dictionary = OverworldRules.build_in_active_town(session, selected_id)
				if not bool(same_day_result.get("ok", true)) and String(same_day_result.get("message", "")).contains("already completed a build order today"):
					same_day_reject_ok = true
				build_actions_after_build_blocked = TownRules.get_build_actions(session).is_empty()
				build_log.append({
					"day": int(session.day),
					"building_id": selected_id,
					"resources_before": before_resources,
					"resources_after": after_resources,
				})
				market_common_only = market_common_only and _market_actions_common_only(session)
				if _missing_buildings(session, placement_id, target_buildings).is_empty():
					break
		var turn_result: Dictionary = _advance_generated_package_economy_day(session)
		if not bool(turn_result.get("ok", false)):
			stalled_days.append({
				"day": int(session.day),
				"reason": "economy_day_advance_failed",
				"message": String(turn_result.get("message", "")),
			})
		else:
			economy_day_advance_count += 1

	var missing := _missing_buildings(session, placement_id, target_buildings)
	var completed := missing.is_empty()
	var completion_day := int(build_log[-1].get("day", 0)) if not build_log.is_empty() else 0
	while completed and int(session.day) < TARGET_TURNS:
		var completion_turn_result: Dictionary = _advance_generated_package_economy_day(session)
		if not bool(completion_turn_result.get("ok", false)):
			stalled_days.append({
				"day": int(session.day),
				"reason": "post_completion_economy_day_advance_failed",
				"message": String(completion_turn_result.get("message", "")),
			})
			break
		economy_day_advance_count += 1
		post_completion_economy_day_count += 1
	var recruitment_report := _recruitment_end_to_end_report(session, placement_id, faction) if completed else {
		"ok": false,
		"errors": ["town did not complete development before recruitment check"],
	}
	var surface := {
		"schema": "generated_package_player_town_development_runway_v1",
		"status": "pass",
		"package_session_scope": "strict_small_36x36_one_level_land_only",
		"town_placement_id": placement_id,
		"town_id": town_id,
		"faction_id": faction_id,
		"target_turns": target_turns,
		"target_building_count": target_buildings.size(),
		"initial_missing_building_count": initial_missing_buildings.size(),
		"initial_missing_buildings": initial_missing_buildings,
		"completed": completed,
		"completion_day": completion_day,
		"min_completion_day": MIN_GENERATED_PACKAGE_PLAYER_COMPLETION_DAY,
		"pacing_floor_ok": completion_day >= MIN_GENERATED_PACKAGE_PLAYER_COMPLETION_DAY,
		"build_count": build_log.size(),
		"missing_buildings": missing,
		"same_day_reject_ok": same_day_reject_ok,
		"build_actions_after_build_blocked": build_actions_after_build_blocked,
		"rare_spend_observed": not rare_spend_events.is_empty(),
		"rare_spend_events": rare_spend_events,
		"market_common_only": market_common_only,
		"focused_economy_day_advance_count": economy_day_advance_count,
		"post_completion_economy_day_count": post_completion_economy_day_count,
		"source_evidence": source_evidence,
		"recruitment_end_to_end_ok": bool(recruitment_report.get("ok", false)),
		"recruitment_case_count": int(recruitment_report.get("case_count", 0)),
		"recruited_unit_case_count": int(recruitment_report.get("recruited_unit_case_count", 0)),
		"recruitment_market_purchase_count": int(recruitment_report.get("market_purchase_count", 0)),
		"recruitment_market_reset_wait_count": int(recruitment_report.get("market_reset_wait_count", 0)),
		"recruitment_report": recruitment_report,
		"ending_resources": _resources(session),
		"stalled_days": stalled_days.slice(0, 5),
		"build_log": build_log,
	}
	var ok := (
		completed
		and int(surface.get("completion_day", 0)) >= MIN_GENERATED_PACKAGE_PLAYER_COMPLETION_DAY
		and int(surface.get("completion_day", 0)) <= TARGET_TURNS
		and int(surface.get("build_count", 0)) == initial_missing_buildings.size()
		and same_day_reject_ok
		and build_actions_after_build_blocked
		and not rare_spend_events.is_empty()
		and market_common_only
		and _source_covers_required_resources(source_evidence, required_resource_ids)
		and economy_day_advance_count > 0
		and bool(recruitment_report.get("ok", false))
		and int(recruitment_report.get("recruited_unit_case_count", 0)) == TARGET_TIER_COUNT
	)
	if not ok:
		surface["status"] = "fail"
		_fail("Generated package player town development runway failed: %s" % JSON.stringify(surface))
		return {}
	return surface

func _assert_generated_enemy_town_development_runway(active_setup: Dictionary) -> Dictionary:
	var probe_session: SessionStateStoreScript.SessionData = ScenarioSelectRulesScript.start_random_map_skirmish_session_from_setup(active_setup)
	if probe_session == null or probe_session.session_id == "":
		_fail("Generated package enemy town runway could not start a fresh package session.")
		return {}
	var enemy_towns := _enemy_towns(probe_session)
	var rows := []
	for town in enemy_towns:
		var case_session: SessionStateStoreScript.SessionData = ScenarioSelectRulesScript.start_random_map_skirmish_session_from_setup(active_setup)
		if case_session == null or case_session.session_id == "":
			_fail("Generated package enemy town runway could not start a case session.")
			return {}
		rows.append(_run_generated_enemy_town_case(case_session, town))
	var completed_case_count := 0
	var rare_spend_case_count := 0
	var same_day_guard_case_count := 0
	var treasury_case_count := 0
	var governor_case_count := 0
	var source_covered_case_count := 0
	var full_session_case_count := 0
	var seven_tier_recruitment_case_count := 0
	var selected_recruitment_case_count := 0
	var pacing_floor_case_count := 0
	var source_adoption_policy_case_count := 0
	var build_count_total := 0
	var secured_source_count_total := 0
	var completion_days := []
	for row_value in rows:
		var row: Dictionary = row_value
		if bool(row.get("completed", false)):
			completed_case_count += 1
			completion_days.append(int(row.get("completion_day", 0)))
		if bool(row.get("rare_spend_observed", false)):
			rare_spend_case_count += 1
		if bool(row.get("same_day_second_build_blocked", false)):
			same_day_guard_case_count += 1
		if bool(row.get("rare_treasury_tracked", false)):
			treasury_case_count += 1
		if bool(row.get("governor_report_seen", false)):
			governor_case_count += 1
		if bool(row.get("source_coverage_ok", false)):
			source_covered_case_count += 1
		if bool(row.get("full_session_used", false)):
			full_session_case_count += 1
		if bool(row.get("ai_seven_tier_recruitment_seen", false)):
			seven_tier_recruitment_case_count += 1
		if bool(row.get("ai_recruitment_selected_seen", false)):
			selected_recruitment_case_count += 1
		if bool(row.get("pacing_floor_ok", false)):
			pacing_floor_case_count += 1
		var row_source_evidence: Dictionary = row.get("source_evidence", {}) if row.get("source_evidence", {}) is Dictionary else {}
		if String(row_source_evidence.get("source_adoption_policy", "")) == "minimal_required_resource_coverage":
			source_adoption_policy_case_count += 1
		secured_source_count_total += int(row_source_evidence.get("secured_source_count", 0))
		build_count_total += int(row.get("build_count", 0))
	var enemy_case_count := rows.size()
	var status := "pass"
	if enemy_case_count < 2 \
			or completed_case_count != enemy_case_count \
			or pacing_floor_case_count != enemy_case_count \
			or rare_spend_case_count != enemy_case_count \
			or same_day_guard_case_count != enemy_case_count \
			or treasury_case_count != enemy_case_count \
			or governor_case_count != enemy_case_count \
			or source_covered_case_count != enemy_case_count \
			or source_adoption_policy_case_count != enemy_case_count \
			or full_session_case_count != enemy_case_count \
			or seven_tier_recruitment_case_count != enemy_case_count \
			or selected_recruitment_case_count != enemy_case_count:
		status = "fail"
	var surface := {
		"schema": "generated_package_enemy_town_development_runway_v1",
		"status": status,
		"package_session_scope": "strict_small_36x36_one_level_land_only",
		"enemy_town_case_count": enemy_case_count,
		"completed_case_count": completed_case_count,
		"min_completion_day": MIN_GENERATED_PACKAGE_ENEMY_COMPLETION_DAY,
		"completion_day_min": completion_days.min() if not completion_days.is_empty() else 0,
		"completion_day_max": completion_days.max() if not completion_days.is_empty() else 0,
		"pacing_floor_case_count": pacing_floor_case_count,
		"rare_spend_case_count": rare_spend_case_count,
		"same_day_guard_case_count": same_day_guard_case_count,
		"rare_treasury_tracked_case_count": treasury_case_count,
		"governor_report_case_count": governor_case_count,
		"source_covered_case_count": source_covered_case_count,
		"source_adoption_policy_case_count": source_adoption_policy_case_count,
		"full_session_case_count": full_session_case_count,
		"seven_tier_recruitment_case_count": seven_tier_recruitment_case_count,
		"selected_recruitment_case_count": selected_recruitment_case_count,
		"build_count_total": build_count_total,
		"secured_source_count_total": secured_source_count_total,
		"town_rows": rows,
	}
	if status != "pass":
		_fail("Generated package enemy town development runway failed: %s" % JSON.stringify(surface))
		return {}
	return surface

func _run_generated_enemy_town_case(session: SessionStateStoreScript.SessionData, enemy_town: Dictionary) -> Dictionary:
	OverworldRules.normalize_overworld_state(session)
	EnemyTurnRules.normalize_enemy_states(session)
	session.game_state = "overworld"
	session.scenario_status = "in_progress"
	var placement_id := String(enemy_town.get("placement_id", ""))
	var town := _town(session, placement_id)
	var town_id := String(town.get("town_id", enemy_town.get("town_id", "")))
	var town_template := ContentService.get_town(town_id)
	var faction_id := String(town.get("controlling_faction_id", town.get("faction_id", town_template.get("faction_id", ""))))
	if faction_id == "":
		faction_id = String(town_template.get("faction_id", ""))
	var faction := ContentService.get_faction(faction_id)
	var config := _enemy_config_for_faction(session, faction_id)
	var profile: Dictionary = town_template.get("development_balance", {}) if town_template.get("development_balance", {}) is Dictionary else {}
	var target_turns: int = min(TARGET_TURNS, int(profile.get("target_complete_turns", TARGET_TURNS)))
	var target_buildings := _string_array(town_template.get("buildable_building_ids", []))
	var initial_missing_buildings := _missing_buildings(session, placement_id, target_buildings)
	var required_resource_ids := _required_build_resource_ids(target_buildings)
	var row := {
		"ok": false,
		"town_placement_id": placement_id,
		"town_id": town_id,
		"faction_id": faction_id,
		"target_turns": target_turns,
		"target_building_count": target_buildings.size(),
		"initial_missing_building_count": initial_missing_buildings.size(),
		"required_resource_ids": required_resource_ids,
		"rare_resource_id": String(profile.get("rare_resource_id", "")),
	}
	if town.is_empty() or town_template.is_empty() or faction.is_empty() or config.is_empty() or target_buildings.is_empty():
		row["error"] = "missing generated enemy town/faction/config/build targets"
		return row
	if String(profile.get("rare_resource_id", "")) not in RARE_RESOURCE_IDS:
		row["error"] = "generated enemy town development profile missing live rare resource"
		return row

	var source_evidence := _secure_enemy_development_sources(session, faction_id, required_resource_ids)
	_seed_enemy_treasury(session, faction_id, source_evidence.get("resources_after_claims", {}))
	var build_log := []
	var stalled_days := []
	var rare_spend_events := []
	var same_day_second_build_blocked := false
	var rare_treasury_tracked := _enemy_treasury_has_all_live_keys(session, faction_id)
	var governor_report := EnemyTurnRules.town_governor_pressure_report(session, config, faction_id)
	var governor_report_seen := int(governor_report.get("town_count", 0)) > 0

	for _turn in range(target_turns):
		var before_state := _enemy_state(session, faction_id)
		var before_treasury := _normalized_resources(before_state.get("treasury", {}))
		var expected_income := _enemy_daily_income(session, placement_id, faction_id)
		var before_built := _town_building_ids(_town(session, placement_id))
		var turn_result: Dictionary = EnemyTurnRules.run_enemy_town_economy_turn(session, faction_id)
		if not bool(turn_result.get("ok", false)):
			stalled_days.append({
				"day": int(session.day),
				"reason": "enemy_turn_failed",
				"message": String(turn_result.get("message", "")),
			})
		var after_state := _enemy_state(session, faction_id)
		var after_treasury := _normalized_resources(after_state.get("treasury", {}))
		var after_built := _town_building_ids(_town(session, placement_id))
		var built_today := _new_buildings(before_built, after_built)
		for building_id in built_today:
			var building := ContentService.get_building(String(building_id))
			var rare_cost := _rare_cost(building.get("cost", {}))
			if not rare_cost.is_empty():
				rare_spend_events.append({
					"day": int(session.day),
					"building_id": String(building_id),
					"spent": rare_cost,
					"treasury_before": before_treasury,
					"expected_income": expected_income,
					"treasury_after": after_treasury,
				})
			build_log.append({
				"day": int(session.day),
				"building_id": String(building_id),
				"cost": building.get("cost", {}),
				"treasury_before": before_treasury,
				"expected_income": expected_income,
				"treasury_after": after_treasury,
			})
		if not built_today.is_empty() and not same_day_second_build_blocked:
			var second_session := _clone_session(session)
			var built_count_before_second := _town_building_ids(_town(second_session, placement_id)).size()
			var second_result: Dictionary = EnemyTurnRules.run_enemy_town_economy_turn(second_session, faction_id)
			var built_count_after_second := _town_building_ids(_town(second_session, placement_id)).size()
			var second_events: Array = second_result.get("events", []) if second_result.get("events", []) is Array else []
			same_day_second_build_blocked = (
				built_count_after_second == built_count_before_second
				and _target_town_event_count(second_events, "ai_town_built", placement_id) == 0
			)
		if _missing_buildings(session, placement_id, target_buildings).is_empty():
			break
		if built_today.is_empty():
			stalled_days.append({
				"day": int(session.day),
				"reason": "no_enemy_build_selected",
				"treasury": after_treasury,
				"open_buildings": _open_building_ids(_town(session, placement_id), target_buildings),
			})
		session.day += 1

	var missing := _missing_buildings(session, placement_id, target_buildings)
	var completed := missing.is_empty()
	var completion_day := int(build_log[-1].get("day", 0)) if not build_log.is_empty() else 0
	var pacing_floor_ok := completion_day >= MIN_GENERATED_PACKAGE_ENEMY_COMPLETION_DAY
	var recruitment_evidence := _ai_recruitment_evidence(session, config, placement_id, faction_id)
	var source_coverage_ok := _source_covers_required_resources(source_evidence, required_resource_ids)
	var source_adoption_policy_ok := String(source_evidence.get("source_adoption_policy", "")) == "minimal_required_resource_coverage"
	row["ok"] = (
		completed
		and pacing_floor_ok
		and int(build_log.size()) == initial_missing_buildings.size()
		and same_day_second_build_blocked
		and not rare_spend_events.is_empty()
		and rare_treasury_tracked
		and governor_report_seen
		and source_coverage_ok
		and source_adoption_policy_ok
		and bool(recruitment_evidence.get("seven_tier_recruitment_seen", false))
		and bool(recruitment_evidence.get("selected_recruitment_seen", false))
	)
	row["completed"] = completed
	row["completion_day"] = completion_day
	row["min_completion_day"] = MIN_GENERATED_PACKAGE_ENEMY_COMPLETION_DAY
	row["pacing_floor_ok"] = pacing_floor_ok
	row["build_count"] = build_log.size()
	row["missing_buildings"] = missing
	row["same_day_second_build_blocked"] = same_day_second_build_blocked
	row["rare_treasury_tracked"] = rare_treasury_tracked
	row["governor_report_seen"] = governor_report_seen
	row["rare_spend_observed"] = not rare_spend_events.is_empty()
	row["source_coverage_ok"] = source_coverage_ok
	row["source_adoption_policy_ok"] = source_adoption_policy_ok
	row["source_evidence"] = source_evidence
	row["ai_recruitment_evidence"] = recruitment_evidence
	row["ai_recruitment_candidate_count"] = int(recruitment_evidence.get("candidate_count", 0))
	row["ai_recruitment_tier_candidate_count"] = int(recruitment_evidence.get("tier_candidate_count", 0))
	row["ai_recruitment_affordable_candidate_count"] = int(recruitment_evidence.get("affordable_candidate_count", 0))
	row["ai_recruitment_selected_seen"] = bool(recruitment_evidence.get("selected_recruitment_seen", false))
	row["ai_seven_tier_recruitment_seen"] = bool(recruitment_evidence.get("seven_tier_recruitment_seen", false))
	row["full_session_used"] = bool(session.flags.get("generated_random_map", false)) and String(session.scenario_id) != ""
	row["scenario_enemy_state_count"] = _array_size(session.overworld.get("enemy_states", []))
	row["ending_treasury"] = _normalized_resources(_enemy_state(session, faction_id).get("treasury", {}))
	row["rare_spend_events"] = rare_spend_events
	row["stalled_days"] = stalled_days.slice(0, 5)
	row["build_log"] = build_log
	if not bool(row.get("ok", false)):
		row["error"] = _generated_enemy_runway_error(row)
	return row

func _generated_resource_source_ids(resource_nodes: Array) -> Dictionary:
	var resource_ids := {}
	for node_value in resource_nodes:
		if not (node_value is Dictionary):
			continue
		var node: Dictionary = node_value
		for key in ["resource_id", "original_resource_id"]:
			var direct_id := String(node.get(key, ""))
			if direct_id in OverworldRulesScript.LIVE_STOCKPILE_RESOURCE_KEYS:
				resource_ids[direct_id] = true
		var site := ContentService.get_resource_site(String(node.get("site_id", "")))
		for resource_id in _resource_outputs_for_site(site):
			resource_ids[resource_id] = true
	return resource_ids

func _resource_outputs_for_site(site: Dictionary) -> Array:
	var resource_ids := {}
	for key in ["rewards", "claim_rewards", "control_income"]:
		var payload: Dictionary = site.get(key, {}) if site.get(key, {}) is Dictionary else {}
		for resource_id_value in payload.keys():
			var resource_id := String(resource_id_value)
			if resource_id in OverworldRulesScript.LIVE_STOCKPILE_RESOURCE_KEYS:
				resource_ids[resource_id] = true
	var staged_outputs: Array = site.get("staged_resource_outputs", []) if site.get("staged_resource_outputs", []) is Array else []
	for output_value in staged_outputs:
		if not (output_value is Dictionary):
			continue
		var resource_id := String(output_value.get("resource_id", ""))
		if resource_id in OverworldRulesScript.LIVE_STOCKPILE_RESOURCE_KEYS:
			resource_ids[resource_id] = true
	return _sorted_string_keys(resource_ids)

func _required_build_resource_ids(target_buildings: Array) -> Array:
	var ids := {}
	for building_id in target_buildings:
		var building := ContentService.get_building(String(building_id))
		var cost: Dictionary = building.get("cost", {}) if building.get("cost", {}) is Dictionary else {}
		for resource_id in cost.keys():
			var id := String(resource_id)
			if id in OverworldRulesScript.LIVE_STOCKPILE_RESOURCE_KEYS:
				ids[id] = true
	return _sorted_string_keys(ids)

func _secure_development_sources(session: SessionStateStoreScript.SessionData, required_resource_ids: Array) -> Dictionary:
	var nodes: Array = session.overworld.get("resource_nodes", []) if session.overworld.get("resource_nodes", []) is Array else []
	var source_rows := []
	var secured_nodes := []
	var secured_resource_ids := {}
	var secured_income := {}
	var secured_claims := {}
	var covered_resource_ids := {}
	for index in range(nodes.size()):
		if not (nodes[index] is Dictionary):
			continue
		if _source_covers_required_resources({"secured_resource_ids": _sorted_string_keys(covered_resource_ids)}, required_resource_ids):
			break
		var node: Dictionary = nodes[index]
		var site := ContentService.get_resource_site(String(node.get("site_id", "")))
		if site.is_empty():
			continue
		var claim_rewards: Dictionary = site.get("claim_rewards", site.get("rewards", {})) if site.get("claim_rewards", site.get("rewards", {})) is Dictionary else {}
		var control_income: Dictionary = site.get("control_income", {}) if site.get("control_income", {}) is Dictionary else {}
		var relevant_claims := _filter_resources(claim_rewards, required_resource_ids)
		var relevant_income := _filter_resources(control_income, required_resource_ids)
		if relevant_claims.is_empty() and relevant_income.is_empty():
			continue
		var source_resource_ids := {}
		for resource_id in relevant_claims.keys():
			source_resource_ids[String(resource_id)] = true
		for resource_id in relevant_income.keys():
			source_resource_ids[String(resource_id)] = true
		var adds_uncovered_required_resource := false
		for resource_id in source_resource_ids.keys():
			if not bool(covered_resource_ids.get(String(resource_id), false)):
				adds_uncovered_required_resource = true
				break
		if not adds_uncovered_required_resource:
			continue
		if bool(site.get("persistent_control", false)):
			node["collected_by_faction_id"] = "player"
		if not relevant_claims.is_empty() and not bool(node.get("collected", false)):
			_add_to_session_resources(session, relevant_claims)
			node["collected"] = true
			node["collected_day"] = int(session.day)
			secured_claims = _add_resource_sets(secured_claims, relevant_claims)
		if not relevant_income.is_empty() and bool(site.get("persistent_control", false)):
			secured_income = _add_resource_sets(secured_income, relevant_income)
		for resource_id in relevant_claims.keys():
			secured_resource_ids[String(resource_id)] = true
			covered_resource_ids[String(resource_id)] = true
		for resource_id in relevant_income.keys():
			secured_resource_ids[String(resource_id)] = true
			covered_resource_ids[String(resource_id)] = true
		source_rows.append({
			"placement_id": String(node.get("placement_id", "")),
			"site_id": String(node.get("site_id", "")),
			"persistent_control": bool(site.get("persistent_control", false)),
			"claim_rewards": relevant_claims,
			"control_income": relevant_income,
		})
		secured_nodes.append({
			"placement_id": String(node.get("placement_id", "")),
			"site_id": String(node.get("site_id", "")),
			"x": int(node.get("x", 0)),
			"y": int(node.get("y", 0)),
			"collected": bool(node.get("collected", false)),
			"collected_day": int(node.get("collected_day", 0)),
			"collected_by_faction_id": String(node.get("collected_by_faction_id", "")),
		})
		nodes[index] = node
	session.overworld["resource_nodes"] = nodes
	return {
		"source_adoption_policy": "minimal_required_resource_coverage",
		"secured_source_count": source_rows.size(),
		"secured_resource_ids": _sorted_string_keys(secured_resource_ids),
		"secured_claims": secured_claims,
		"secured_daily_income": secured_income,
		"resources_after_claims": _resources(session),
		"secured_resource_nodes": secured_nodes,
		"sources": source_rows,
	}

func _secure_enemy_development_sources(session: SessionStateStoreScript.SessionData, faction_id: String, required_resource_ids: Array) -> Dictionary:
	var nodes: Array = session.overworld.get("resource_nodes", []) if session.overworld.get("resource_nodes", []) is Array else []
	var treasury := _normalized_resources({})
	var source_rows := []
	var secured_nodes := []
	var secured_resource_ids := {}
	var secured_income := {}
	var secured_claims := {}
	var covered_resource_ids := {}
	for index in range(nodes.size()):
		if not (nodes[index] is Dictionary):
			continue
		if _source_covers_required_resources({"secured_resource_ids": _sorted_string_keys(covered_resource_ids)}, required_resource_ids):
			break
		var node: Dictionary = nodes[index]
		var site := ContentService.get_resource_site(String(node.get("site_id", "")))
		if site.is_empty():
			continue
		var claim_rewards: Dictionary = site.get("claim_rewards", site.get("rewards", {})) if site.get("claim_rewards", site.get("rewards", {})) is Dictionary else {}
		var control_income: Dictionary = site.get("control_income", {}) if site.get("control_income", {}) is Dictionary else {}
		var persistent_control := bool(site.get("persistent_control", false))
		var relevant_claims := _filter_resources(claim_rewards, required_resource_ids)
		var relevant_income := _filter_resources(control_income, required_resource_ids)
		var applied_claims := {} if persistent_control else relevant_claims
		var applied_income := relevant_income if persistent_control else {}
		if applied_claims.is_empty() and applied_income.is_empty():
			continue
		var source_resource_ids := {}
		for resource_id in applied_claims.keys():
			source_resource_ids[String(resource_id)] = true
		for resource_id in applied_income.keys():
			source_resource_ids[String(resource_id)] = true
		var adds_uncovered_required_resource := false
		for resource_id in source_resource_ids.keys():
			if not bool(covered_resource_ids.get(String(resource_id), false)):
				adds_uncovered_required_resource = true
				break
		if not adds_uncovered_required_resource:
			continue
		if not applied_claims.is_empty():
			treasury = _add_resource_sets(treasury, applied_claims)
			node["collected"] = true
			node["collected_day"] = int(session.day)
			node["collected_by_faction_id"] = faction_id
			secured_claims = _add_resource_sets(secured_claims, applied_claims)
		if not applied_income.is_empty():
			node["collected_by_faction_id"] = faction_id
			secured_income = _add_resource_sets(secured_income, applied_income)
		for resource_id in applied_claims.keys():
			secured_resource_ids[String(resource_id)] = true
			covered_resource_ids[String(resource_id)] = true
		for resource_id in applied_income.keys():
			secured_resource_ids[String(resource_id)] = true
			covered_resource_ids[String(resource_id)] = true
		source_rows.append({
			"placement_id": String(node.get("placement_id", "")),
			"site_id": String(node.get("site_id", "")),
			"persistent_control": persistent_control,
			"claim_rewards": applied_claims,
			"control_income": applied_income,
		})
		secured_nodes.append({
			"placement_id": String(node.get("placement_id", "")),
			"site_id": String(node.get("site_id", "")),
			"x": int(node.get("x", 0)),
			"y": int(node.get("y", 0)),
			"collected": bool(node.get("collected", false)),
			"collected_day": int(node.get("collected_day", 0)),
			"collected_by_faction_id": String(node.get("collected_by_faction_id", "")),
		})
		nodes[index] = node
	session.overworld["resource_nodes"] = nodes
	return {
		"source_adoption_policy": "minimal_required_resource_coverage",
		"secured_source_count": source_rows.size(),
		"secured_resource_ids": _sorted_string_keys(secured_resource_ids),
		"secured_claims": secured_claims,
		"secured_daily_income": secured_income,
		"resources_after_claims": treasury,
		"secured_resource_nodes": secured_nodes,
		"sources": source_rows,
	}

func _advance_generated_package_economy_day(session: SessionStateStoreScript.SessionData) -> Dictionary:
	if session == null:
		return {"ok": false, "message": "missing session"}
	session.day = int(session.day) + 1
	var town_income := {}
	var weekly_growth := {}
	var should_apply_weekly_growth := OverworldRules.is_weekly_growth_day(int(session.day))
	var towns: Array = session.overworld.get("towns", []) if session.overworld.get("towns", []) is Array else []
	for index in range(towns.size()):
		if not (towns[index] is Dictionary):
			continue
		var town: Dictionary = towns[index]
		if String(town.get("owner", "neutral")) != "player":
			continue
		if should_apply_weekly_growth:
			var growth := OverworldRules.town_weekly_growth(town, session)
			if not growth.is_empty():
				town["available_recruits"] = _add_recruit_sets(town.get("available_recruits", {}), growth)
				weekly_growth = _add_recruit_sets(weekly_growth, growth)
				towns[index] = town
	session.overworld["towns"] = towns
	for town_value in session.overworld.get("towns", []):
		if not (town_value is Dictionary):
			continue
		var town: Dictionary = town_value
		if String(town.get("owner", "neutral")) != "player":
			continue
		town_income = _add_resource_sets(
			town_income,
			DifficultyRules.scale_income_resources(session, OverworldRules.town_income(town, session))
		)
	var site_income := DifficultyRules.scale_income_resources(session, OverworldRules.controlled_resource_site_income(session, "player"))
	var total_income := _add_resource_sets(town_income, site_income)
	_add_to_session_resources(session, total_income)
	return {
		"ok": true,
		"message": "Focused generated-package economy day advanced.",
		"day": int(session.day),
		"town_income": _normalized_resources(town_income),
		"site_income": _normalized_resources(site_income),
		"total_income": _normalized_resources(total_income),
		"weekly_growth": weekly_growth,
	}

func _select_building_id(session: SessionStateStoreScript.SessionData, placement_id: String, target_buildings: Array, signature_order: Dictionary) -> String:
	var actions := []
	var town := _town(session, placement_id)
	var resources := _resources(session)
	for building_id_value in OverworldRules.get_town_build_options(town, int(session.day)):
		var building_id := String(building_id_value)
		if building_id not in target_buildings:
			continue
		var building := ContentService.get_building(building_id)
		var readiness: Dictionary = OverworldRules.town_cost_readiness(town, resources, building.get("cost", {}), int(session.day))
		if not bool(readiness.get("direct_affordable", false)):
			continue
		actions.append(building_id)
	actions.sort_custom(func(a, b): return _build_sort_key(a, target_buildings, signature_order) < _build_sort_key(b, target_buildings, signature_order))
	return String(actions[0]) if not actions.is_empty() else ""

func _build_sort_key(building_id: String, target_buildings: Array, signature_order: Dictionary) -> String:
	var signature_rank := int(signature_order.get(building_id, 99))
	var target_rank := target_buildings.find(building_id)
	if target_rank < 0:
		target_rank = 999
	return "%03d:%03d:%s" % [signature_rank, target_rank, building_id]

func _signature_order(faction: Dictionary) -> Dictionary:
	var order := {}
	var signature_ids := _string_array(faction.get("signature_building_ids", []))
	for index in range(signature_ids.size()):
		order[signature_ids[index]] = index + 1
	return order

func _open_building_ids(town: Dictionary, target_buildings: Array) -> Array:
	var result := []
	for building_id in target_buildings:
		if bool(OverworldRules.get_town_build_status(town, String(building_id)).get("buildable", false)):
			result.append(String(building_id))
	return result

func _missing_buildings(session: SessionStateStoreScript.SessionData, placement_id: String, target_buildings: Array) -> Array:
	var town := _town(session, placement_id)
	var built := _string_array(town.get("built_buildings", []))
	var missing := []
	for building_id in target_buildings:
		if String(building_id) not in built:
			missing.append(String(building_id))
	return missing

func _town(session: SessionStateStoreScript.SessionData, placement_id: String) -> Dictionary:
	for town_value in session.overworld.get("towns", []):
		if town_value is Dictionary and String(town_value.get("placement_id", "")) == placement_id:
			return town_value
	return {}

func _player_town(session: SessionStateStoreScript.SessionData) -> Dictionary:
	if session == null:
		return {}
	for town_value in session.overworld.get("towns", []):
		if town_value is Dictionary and String(town_value.get("owner", "")) == "player":
			return town_value
	return {}

func _set_active_town(session: SessionStateStoreScript.SessionData, placement_id: String) -> Dictionary:
	return OverworldRules.set_active_town_visit(session, placement_id)

func _source_covers_required_resources(source_evidence: Dictionary, required_resource_ids: Array) -> bool:
	var secured := _string_array(source_evidence.get("secured_resource_ids", []))
	for resource_id in required_resource_ids:
		var id := String(resource_id)
		if id == "gold":
			continue
		if id not in secured:
			return false
	return true

func _rare_resource_spend(cost_value: Variant, before: Dictionary, after: Dictionary) -> Dictionary:
	var cost: Dictionary = cost_value if cost_value is Dictionary else {}
	var spent := {}
	for resource_id in RARE_RESOURCE_IDS:
		if int(cost.get(resource_id, 0)) <= 0:
			continue
		var delta := int(before.get(resource_id, 0)) - int(after.get(resource_id, 0))
		if delta > 0:
			spent[resource_id] = delta
	return spent

func _recruitment_end_to_end_report(session: SessionStateStoreScript.SessionData, placement_id: String, faction: Dictionary) -> Dictionary:
	_set_active_town(session, placement_id)
	var ladder_ids := _string_array(faction.get("unit_ladder_ids", []))
	var rows := []
	var errors := []
	var recruited_count := 0
	var market_purchase_count := 0
	var market_reset_wait_count := 0
	var before_army := _army_stack_counts(session)
	if ladder_ids.size() != TARGET_TIER_COUNT:
		errors.append("%s unit ladder must expose seven tiers" % String(faction.get("id", "")))
	for index in range(ladder_ids.size()):
		var unit_id := String(ladder_ids[index])
		var expected_tier := index + 1
		var action := _recruit_action_for(session, placement_id, unit_id)
		var row := {
			"ok": false,
			"unit_id": unit_id,
			"expected_tier": expected_tier,
			"action_found": not action.is_empty(),
		}
		if action.is_empty():
			row["error"] = "missing recruit action"
			errors.append("%s missing recruit action for %s" % [String(faction.get("id", "")), unit_id])
			rows.append(row)
			continue
		var unit := ContentService.get_unit(unit_id)
		var before_count := int(_army_stack_counts(session).get(unit_id, 0))
		var available_before := int(action.get("available_count", 0))
		var weekly_growth := int(action.get("weekly_growth", 0))
		var direct_affordable_count := int(action.get("direct_affordable_count", 0))
		var market_affordable_count := int(action.get("market_affordable_count", 0))
		row["unit_name"] = String(unit.get("name", unit_id))
		row["unit_tier"] = int(action.get("unit_tier", 0))
		row["tier_label"] = String(action.get("tier_label", ""))
		row["available_before"] = available_before
		row["weekly_growth"] = weekly_growth
		row["direct_affordable_count"] = direct_affordable_count
		row["market_affordable_count"] = market_affordable_count
		row["market_coverable"] = bool(action.get("market_coverable", false))
		row["unit_cost"] = action.get("unit_cost", {})
		if direct_affordable_count <= 0 and _has_common_recruitment_shortfall(session, action.get("unit_cost", {})):
			row["market_purchases"] = _apply_recruitment_market_coverage(session, placement_id, action.get("unit_cost", {}))
			market_purchase_count += _market_purchase_count(row.get("market_purchases", []))
			market_reset_wait_count += _market_reset_wait_count(row.get("market_purchases", []))
			action = _recruit_action_for(session, placement_id, unit_id)
			direct_affordable_count = int(action.get("direct_affordable_count", 0))
			market_affordable_count = int(action.get("market_affordable_count", 0))
			row["direct_affordable_count"] = direct_affordable_count
			row["market_affordable_count"] = market_affordable_count
			row["market_coverable"] = bool(action.get("market_coverable", false))
		if int(unit.get("tier", 0)) != expected_tier or int(action.get("unit_tier", 0)) != expected_tier:
			row["error"] = "tier mismatch"
		elif available_before <= 0:
			row["error"] = "no recruits available"
		elif weekly_growth <= 0:
			row["error"] = "weekly growth missing"
		elif direct_affordable_count <= 0:
			row["error"] = "not directly affordable"
		elif not String(action.get("summary", "")).contains("Tier %d" % expected_tier):
			row["error"] = "summary missing tier label"
		else:
			var recruit_result: Dictionary = OverworldRules.recruit_in_active_town(session, unit_id, 1)
			var after_count := int(_army_stack_counts(session).get(unit_id, 0))
			row["recruit_result_ok"] = bool(recruit_result.get("ok", false))
			row["recruit_message"] = String(recruit_result.get("message", ""))
			row["army_count_before"] = before_count
			row["army_count_after"] = after_count
			if not bool(recruit_result.get("ok", false)):
				row["error"] = "recruit action failed"
			elif after_count != before_count + 1:
				row["error"] = "field army did not receive recruit"
			else:
				row["ok"] = true
				recruited_count += 1
		if not bool(row.get("ok", false)):
			errors.append("%s %s tier %d recruitment failed: %s" % [
				String(faction.get("id", "")),
				unit_id,
				expected_tier,
				String(row.get("error", "unknown")),
			])
		rows.append(row)
	var after_army := _army_stack_counts(session)
	return {
		"ok": errors.is_empty() and ladder_ids.size() == TARGET_TIER_COUNT and recruited_count == TARGET_TIER_COUNT,
		"faction_id": String(faction.get("id", "")),
		"case_count": rows.size(),
		"recruited_unit_case_count": recruited_count,
		"market_purchase_count": market_purchase_count,
		"market_reset_wait_count": market_reset_wait_count,
		"army_before": before_army,
		"army_after": after_army,
		"tiers": rows,
		"errors": errors,
	}

func _recruit_action_for(session: SessionStateStoreScript.SessionData, placement_id: String, unit_id: String) -> Dictionary:
	_set_active_town(session, placement_id)
	for action_value in TownRules.get_recruit_actions(session):
		if action_value is Dictionary and String(action_value.get("id", "")) == "recruit:%s" % unit_id:
			return action_value
	return {}

func _army_stack_counts(session: SessionStateStoreScript.SessionData) -> Dictionary:
	var counts := {}
	for stack_value in session.overworld.get("army", {}).get("stacks", []):
		if not (stack_value is Dictionary):
			continue
		var unit_id := String(stack_value.get("unit_id", ""))
		if unit_id == "":
			continue
		counts[unit_id] = int(counts.get(unit_id, 0)) + int(stack_value.get("count", 0))
	return counts

func _has_common_recruitment_shortfall(session: SessionStateStoreScript.SessionData, unit_cost_value: Variant) -> bool:
	var unit_cost: Dictionary = unit_cost_value if unit_cost_value is Dictionary else {}
	for resource_id in COMMON_MARKET_RESOURCE_IDS:
		if int(unit_cost.get(resource_id, 0)) > int(_resources(session).get(resource_id, 0)):
			return true
	return false

func _apply_recruitment_market_coverage(session: SessionStateStoreScript.SessionData, placement_id: String, unit_cost_value: Variant) -> Array:
	_set_active_town(session, placement_id)
	var unit_cost: Dictionary = unit_cost_value if unit_cost_value is Dictionary else {}
	var rows := []
	for resource_id in COMMON_MARKET_RESOURCE_IDS:
		var needed = max(0, int(unit_cost.get(resource_id, 0)) - int(_resources(session).get(resource_id, 0)))
		var wait_days := 0
		while needed > 0:
			var result: Dictionary = TownRules.perform_market_action(session, "market:buy:%s:1" % resource_id)
			rows.append({
				"resource_id": resource_id,
				"ok": bool(result.get("ok", false)),
				"message": String(result.get("message", "")),
				"day": int(session.day),
			})
			if bool(result.get("ok", false)):
				needed -= 1
				wait_days = 0
				continue
			if wait_days >= 7:
				return rows
			var end_turn_result: Dictionary = _advance_generated_package_economy_day(session)
			rows.append({
				"resource_id": resource_id,
				"ok": bool(end_turn_result.get("ok", false)),
				"message": String(end_turn_result.get("message", "")),
				"day": int(session.day),
				"waited_for_market_reset": true,
			})
			_set_active_town(session, placement_id)
			if not bool(end_turn_result.get("ok", false)):
				return rows
			wait_days += 1
	return rows

func _market_purchase_count(rows_value: Variant) -> int:
	var rows: Array = rows_value if rows_value is Array else []
	var count := 0
	for row_value in rows:
		if not (row_value is Dictionary):
			continue
		var row: Dictionary = row_value
		if bool(row.get("ok", false)) and not bool(row.get("waited_for_market_reset", false)):
			count += 1
	return count

func _market_reset_wait_count(rows_value: Variant) -> int:
	var rows: Array = rows_value if rows_value is Array else []
	var count := 0
	for row_value in rows:
		if not (row_value is Dictionary):
			continue
		var row: Dictionary = row_value
		if bool(row.get("waited_for_market_reset", false)):
			count += 1
	return count

func _market_actions_common_only(session: SessionStateStoreScript.SessionData) -> bool:
	for action_value in TownRules.get_market_actions(session):
		if not (action_value is Dictionary):
			continue
		var action: Dictionary = action_value
		var resource_id := String(action.get("resource_id", ""))
		if resource_id != "" and resource_id not in COMMON_MARKET_RESOURCE_IDS:
			return false
	return true

func _enemy_towns(session: SessionStateStoreScript.SessionData) -> Array:
	var result := []
	if session == null:
		return result
	for town_value in session.overworld.get("towns", []):
		if town_value is Dictionary and String(town_value.get("owner", "")) == "enemy":
			result.append(town_value)
	return result

func _enemy_config_for_faction(session: SessionStateStoreScript.SessionData, faction_id: String) -> Dictionary:
	var runtime_record: Dictionary = session.overworld.get("native_random_map_runtime_scenario_record", {}) if session.overworld.get("native_random_map_runtime_scenario_record", {}) is Dictionary else {}
	var configs: Array = runtime_record.get("enemy_factions", []) if runtime_record.get("enemy_factions", []) is Array else []
	for config_value in configs:
		if config_value is Dictionary and String(config_value.get("faction_id", "")) == faction_id:
			return config_value
	for state_value in session.overworld.get("enemy_states", []):
		if state_value is Dictionary and String(state_value.get("faction_id", "")) == faction_id:
			var faction := ContentService.get_faction(faction_id)
			return {
				"faction_id": faction_id,
				"label": String(faction.get("name", faction_id)),
			}
	var faction := ContentService.get_faction(faction_id)
	if not faction.is_empty():
		return {
			"faction_id": faction_id,
			"label": String(faction.get("name", faction_id)),
			"generated_package_town_config": true,
		}
	return {}

func _seed_enemy_treasury(session: SessionStateStoreScript.SessionData, faction_id: String, resources: Dictionary) -> void:
	EnemyTurnRules.normalize_enemy_states(session)
	var states: Array = session.overworld.get("enemy_states", []) if session.overworld.get("enemy_states", []) is Array else []
	for index in range(states.size()):
		if not (states[index] is Dictionary):
			continue
		var state: Dictionary = states[index]
		if String(state.get("faction_id", "")) != faction_id:
			continue
		state["treasury"] = _add_resource_sets(_normalized_resources(state.get("treasury", {})), _normalized_resources(resources))
		states[index] = state
		break
	session.overworld["enemy_states"] = states

func _enemy_state(session: SessionStateStoreScript.SessionData, faction_id: String) -> Dictionary:
	for state_value in session.overworld.get("enemy_states", []):
		if state_value is Dictionary and String(state_value.get("faction_id", "")) == faction_id:
			return state_value
	return {}

func _enemy_treasury_has_all_live_keys(session: SessionStateStoreScript.SessionData, faction_id: String) -> bool:
	var state := _enemy_state(session, faction_id)
	var treasury: Dictionary = state.get("treasury", {}) if state.get("treasury", {}) is Dictionary else {}
	for resource_id in OverworldRulesScript.LIVE_STOCKPILE_RESOURCE_KEYS:
		if String(resource_id) not in treasury:
			return false
	return true

func _enemy_daily_income(session: SessionStateStoreScript.SessionData, placement_id: String, faction_id: String) -> Dictionary:
	var income := _normalized_resources({})
	var town := _town(session, placement_id)
	if not town.is_empty():
		income = _add_resource_sets(income, OverworldRules.town_income(town, session))
	income = _add_resource_sets(income, OverworldRules.controlled_resource_site_income(session, faction_id))
	return _normalized_resources(income)

func _ai_recruitment_evidence(session: SessionStateStoreScript.SessionData, config: Dictionary, placement_id: String, faction_id: String) -> Dictionary:
	var town := _town(session, placement_id)
	var treasury := _normalized_resources(_enemy_state(session, faction_id).get("treasury", {}))
	var report: Dictionary = EnemyTurnRules.town_recruitment_pressure_report(session, config, town, treasury, faction_id)
	var candidates: Array = report.get("candidates", []) if report.get("candidates", []) is Array else []
	var town_template := ContentService.get_town(String(town.get("town_id", "")))
	var ladder_faction_id := String(town_template.get("faction_id", faction_id))
	var ladder_ids := _faction_ladder_ids(ladder_faction_id)
	var candidate_ids := {}
	var tier_candidate_count := 0
	var affordable_candidate_count := 0
	for candidate_value in candidates:
		if not (candidate_value is Dictionary):
			continue
		var candidate: Dictionary = candidate_value
		var unit_id := String(candidate.get("unit_id", ""))
		candidate_ids[unit_id] = true
		if unit_id in ladder_ids:
			tier_candidate_count += 1
		if int(candidate.get("recruit_count", 0)) > 0:
			affordable_candidate_count += 1
	var missing_ladder_ids := []
	for unit_id in ladder_ids:
		if not bool(candidate_ids.get(String(unit_id), false)):
			missing_ladder_ids.append(String(unit_id))
	var selected: Dictionary = report.get("selected_recruitment", {}) if report.get("selected_recruitment", {}) is Dictionary else {}
	return {
		"schema": "generated_package_ai_town_recruitment_surface_v1",
		"placement_id": placement_id,
		"controller_faction_id": faction_id,
		"ladder_faction_id": ladder_faction_id,
		"candidate_count": candidates.size(),
		"tier_candidate_count": tier_candidate_count,
		"affordable_candidate_count": affordable_candidate_count,
		"expected_tier_count": TARGET_TIER_COUNT,
		"ladder_unit_ids": ladder_ids,
		"missing_ladder_unit_ids": missing_ladder_ids,
		"seven_tier_recruitment_seen": ladder_ids.size() == TARGET_TIER_COUNT and missing_ladder_ids.is_empty(),
		"selected_recruitment_seen": not selected.is_empty() and int(selected.get("recruit_count", 0)) > 0,
		"selected_recruitment": selected,
	}

func _faction_ladder_ids(faction_id: String) -> Array:
	var faction := ContentService.get_faction(faction_id)
	return _string_array(faction.get("unit_ladder_ids", []))

func _clone_session(session: SessionStateStoreScript.SessionData) -> SessionStateStoreScript.SessionData:
	var clone := SessionStateStoreScript.SessionData.new()
	clone.from_dict(session.to_dict())
	return clone

func _new_buildings(before: Array, after: Array) -> Array:
	var result := []
	for building_id in after:
		if String(building_id) not in before:
			result.append(String(building_id))
	return result

func _town_building_ids(town: Dictionary) -> Array:
	return _string_array(town.get("built_buildings", []))

func _array_size(value: Variant) -> int:
	return value.size() if value is Array else 0

func _target_town_event_count(events: Array, event_type: String, town_placement_id: String) -> int:
	var count := 0
	for event in events:
		if (
			event is Dictionary
			and String(event.get("event_type", "")) == event_type
			and String(event.get("actor_id", "")) == town_placement_id
		):
			count += 1
	return count

func _rare_cost(cost_value: Variant) -> Dictionary:
	var cost: Dictionary = cost_value if cost_value is Dictionary else {}
	var result := {}
	for resource_id in RARE_RESOURCE_IDS:
		if int(cost.get(resource_id, 0)) > 0:
			result[resource_id] = int(cost.get(resource_id, 0))
	return result

func _generated_enemy_runway_error(row: Dictionary) -> String:
	if not bool(row.get("completed", false)):
		return "generated enemy town did not complete its development runway"
	if not bool(row.get("pacing_floor_ok", false)):
		return "generated enemy town completed before the day-24 production pacing floor"
	if not bool(row.get("same_day_second_build_blocked", false)):
		return "generated enemy same-day second build was not blocked"
	if not bool(row.get("rare_spend_observed", false)):
		return "generated enemy high-tier rare-resource spend was not observed"
	if not bool(row.get("rare_treasury_tracked", false)):
		return "generated enemy treasury did not preserve all live stockpile keys"
	if not bool(row.get("governor_report_seen", false)):
		return "generated enemy town governor report did not cover the target faction"
	if not bool(row.get("source_coverage_ok", false)):
		return "generated enemy secured sources did not cover required build resources"
	if not bool(row.get("source_adoption_policy_ok", false)):
		return "generated enemy source adoption did not use minimal required-resource coverage"
	if not bool(row.get("ai_seven_tier_recruitment_seen", false)):
		return "generated enemy seven-tier recruitment candidates were not exposed"
	if not bool(row.get("ai_recruitment_selected_seen", false)):
		return "generated enemy selected recruitment was not affordable"
	return "unknown generated enemy runway failure"

func _filter_resources(resources: Dictionary, allowed: Array) -> Dictionary:
	var result := {}
	for resource_id in resources.keys():
		var id := String(resource_id)
		if id in allowed and int(resources.get(resource_id, 0)) > 0:
			result[id] = int(resources.get(resource_id, 0))
	return result

func _add_to_session_resources(session: SessionStateStoreScript.SessionData, resources: Dictionary) -> void:
	var pool: Dictionary = session.overworld.get("resources", {}) if session.overworld.get("resources", {}) is Dictionary else {}
	for resource_id in resources.keys():
		var id := String(resource_id)
		pool[id] = int(pool.get(id, 0)) + int(resources.get(resource_id, 0))
	session.overworld["resources"] = pool

func _add_resource_sets(left: Dictionary, right: Dictionary) -> Dictionary:
	var result := left.duplicate(true)
	for resource_id in right.keys():
		var id := String(resource_id)
		result[id] = int(result.get(id, 0)) + int(right.get(resource_id, 0))
	return result

func _add_recruit_sets(left: Variant, right: Variant) -> Dictionary:
	var result := {}
	if left is Dictionary:
		for unit_id in left.keys():
			result[String(unit_id)] = int(left.get(unit_id, 0))
	if right is Dictionary:
		for unit_id in right.keys():
			result[String(unit_id)] = int(result.get(String(unit_id), 0)) + int(right.get(unit_id, 0))
	return result

func _resources(session: SessionStateStoreScript.SessionData) -> Dictionary:
	var result := {}
	for resource_id in OverworldRulesScript.LIVE_STOCKPILE_RESOURCE_KEYS:
		result[String(resource_id)] = int(session.overworld.get("resources", {}).get(String(resource_id), 0))
	return result

func _normalized_resources(resources: Dictionary) -> Dictionary:
	var result := {}
	for resource_id in OverworldRulesScript.LIVE_STOCKPILE_RESOURCE_KEYS:
		result[String(resource_id)] = int(resources.get(String(resource_id), 0))
	return result

func _unit_tiers_for_buildings(building_ids: Array) -> Dictionary:
	var tiers := {}
	for building_id in building_ids:
		var building := ContentService.get_building(String(building_id))
		var unit_id := String(building.get("unlock_unit_id", ""))
		if unit_id == "":
			continue
		var unit := ContentService.get_unit(unit_id)
		var tier := int(unit.get("tier", 0))
		if tier > 0:
			tiers[str(tier)] = true
	return tiers

func _string_array(value: Variant) -> Array:
	var result := []
	if not (value is Array):
		return result
	for item in value:
		var text := String(item)
		if text != "":
			result.append(text)
	return result

func _merged_string_arrays(left: Array, right: Array) -> Array:
	var seen := {}
	var result := []
	for source in [left, right]:
		for value in source:
			var text := String(value)
			if text == "" or bool(seen.get(text, false)):
				continue
			seen[text] = true
			result.append(text)
	return result

func _sorted_string_keys(dict: Dictionary) -> Array:
	var keys := []
	for key in dict.keys():
		keys.append(String(key))
	keys.sort()
	return keys

func _sorted_int_keys(dict: Dictionary) -> Array:
	var keys := []
	for key in dict.keys():
		keys.append(int(String(key)))
	keys.sort()
	return keys

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
