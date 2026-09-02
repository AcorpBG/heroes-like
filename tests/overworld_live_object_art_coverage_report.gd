extends Node

const ScenarioFactoryScript = preload("res://scripts/core/ScenarioFactory.gd")
const SessionStateStoreScript = preload("res://scripts/core/SessionStateStore.gd")
const NativeRandomMapPackageSessionBridgeScript = preload("res://scripts/persistence/NativeRandomMapPackageSessionBridge.gd")
const OverworldMapViewScript = preload("res://scenes/overworld/OverworldMapView.gd")
const ScenarioSelectRulesScript = preload("res://scripts/core/ScenarioSelectRules.gd")

const REPORT_ID := "OVERWORLD_LIVE_OBJECT_ART_COVERAGE_REPORT"
const REPORT_SCHEMA_ID := "overworld_live_object_art_coverage_report_v1"
const MAX_REPORTED_FAILURES := 40
const GENERATED_CASES := [
	{"id": "small", "size_class_id": "homm3_small", "player_count": 3, "seed": "object-art-small-10184"},
	{"id": "large", "size_class_id": "homm3_large", "player_count": 4, "seed": "object-art-large-10184"},
]

var _failures: Array = []
var _counts := {
	"authored_scenarios": 0,
	"generated_cases": 0,
	"towns": 0,
	"resources": 0,
	"artifacts": 0,
	"encounters": 0,
	"heroes": 0,
	"standalone_map_objects": 0,
	"generated_decorative_records": 0,
	"generated_decorative_visual_anchors": 0,
	"town_ownership_pennants": 0,
	"hero_command_pennants": 0,
}
var _asset_ids := {}

func _ready() -> void:
	call_deferred("_run")

func _run() -> void:
	var catalog_summary := _audit_catalog_mappings()
	if catalog_summary.is_empty():
		_finish_failure()
		return
	var view: Variant = OverworldMapViewScript.new()
	view.size = Vector2(1280, 720)
	add_child(view)
	await get_tree().process_frame
	_audit_authored_scenarios(view)
	_audit_generated_cases(view)
	view.queue_free()
	await get_tree().process_frame
	if not _failures.is_empty():
		_finish_failure()
		return
	var total_placements := int(_counts.get("towns", 0)) \
		+ int(_counts.get("resources", 0)) \
		+ int(_counts.get("artifacts", 0)) \
		+ int(_counts.get("encounters", 0)) \
		+ int(_counts.get("heroes", 0)) \
		+ int(_counts.get("standalone_map_objects", 0)) \
		+ int(_counts.get("generated_decorative_records", 0)) \
		+ int(_counts.get("town_ownership_pennants", 0)) \
		+ int(_counts.get("hero_command_pennants", 0))
	print("%s %s" % [REPORT_ID, JSON.stringify({
		"schema_id": REPORT_SCHEMA_ID,
		"ok": true,
		"catalog": catalog_summary,
		"counts": _counts,
		"live_world_object_placement_count": total_placements,
		"distinct_resolved_asset_count": _asset_ids.size(),
		"valid_procedural_fallback_count": 0,
		"empty_sprite_asset_count": 0,
		"missing_runtime_texture_count": 0,
		"intentional_geometry_excluded": [
			"route_and_selection_reticles",
			"fog_and_roads",
			"transient_feedback_vfx",
		],
	})])
	get_tree().quit(0)

func _audit_catalog_mappings() -> Dictionary:
	var art_manifest: Dictionary = ContentService.load_json("res://art/overworld/manifest.json")
	var object_assets: Dictionary = art_manifest.get("object_assets", {}) if art_manifest.get("object_assets", {}) is Dictionary else {}
	var decorative_manifest: Dictionary = ContentService.load_json("res://art/overworld/decorative_object_sprites.json")
	var map_object_manifest: Dictionary = ContentService.load_json("res://art/overworld/map_object_sprites.json")
	var decorative_mappings: Dictionary = decorative_manifest.get("object_sprite_mappings", {}) if decorative_manifest.get("object_sprite_mappings", {}) is Dictionary else {}
	var map_object_mappings: Dictionary = map_object_manifest.get("object_sprite_mappings", {}) if map_object_manifest.get("object_sprite_mappings", {}) is Dictionary else {}
	var map_objects: Array = ContentService.load_json("res://content/map_objects.json").get("items", [])
	var resource_sites: Array = ContentService.load_json("res://content/resource_sites.json").get("items", [])
	var artifacts: Array = ContentService.load_json("res://content/artifacts.json").get("items", [])
	var encounters: Array = ContentService.load_json("res://content/encounters.json").get("items", [])
	var towns: Array = ContentService.load_json("res://content/towns.json").get("items", [])
	var heroes: Array = ContentService.load_json("res://content/heroes.json").get("items", [])
	var ownership_pennant_sprites: Dictionary = art_manifest.get("ownership_pennant_sprites", {}) if art_manifest.get("ownership_pennant_sprites", {}) is Dictionary else {}
	for owner in ["player", "enemy", "neutral"]:
		_audit_asset_id("ownership_pennant", owner, String(ownership_pennant_sprites.get(owner, "")), object_assets)
	var map_object_by_site := {}
	for object_value in map_objects:
		if not (object_value is Dictionary):
			continue
		var object: Dictionary = object_value
		var object_id := String(object.get("id", "")).strip_edges()
		var decorative := String(object.get("primary_class", "")) == "decoration" or String(object.get("family", "")) in ["blocker", "decoration"]
		var mappings := decorative_mappings if decorative else map_object_mappings
		_audit_mapping_asset("map_object", object_id, mappings.get(object_id, {}), object_assets)
		var site_id := String(object.get("resource_site_id", "")).strip_edges()
		if site_id != "" and not map_object_by_site.has(site_id):
			map_object_by_site[site_id] = object_id
	for site_value in resource_sites:
		if not (site_value is Dictionary):
			continue
		var site_id := String(site_value.get("id", "")).strip_edges()
		var entry: Variant = art_manifest.get("resource_site_sprites", {}).get(site_id, {})
		if entry is Dictionary and String(entry.get("asset_id", "")).strip_edges() != "":
			_audit_mapping_asset("resource_site", site_id, entry, object_assets)
			continue
		var object_id := String(map_object_by_site.get(site_id, ""))
		_audit_mapping_asset("resource_site_bridge", site_id, map_object_mappings.get(object_id, {}), object_assets)
	for artifact_value in artifacts:
		if artifact_value is Dictionary:
			var artifact_id := String(artifact_value.get("id", ""))
			_audit_asset_id("artifact", artifact_id, String(art_manifest.get("artifact_field_sprites", {}).get(artifact_id, "")), object_assets)
	for encounter_value in encounters:
		if encounter_value is Dictionary:
			var encounter_id := String(encounter_value.get("id", ""))
			_audit_asset_id("encounter", encounter_id, String(art_manifest.get("encounter_identity_sprites", {}).get(encounter_id, "")), object_assets)
	for town_value in towns:
		if town_value is Dictionary:
			var town_id := String(town_value.get("id", ""))
			_audit_asset_id("town", town_id, String(art_manifest.get("town_identity_sprites", {}).get(town_id, "")), object_assets)
	for hero_value in heroes:
		if not (hero_value is Dictionary):
			continue
		var hero_id := String(hero_value.get("id", ""))
		var asset_id := String(art_manifest.get("hero_identity_sprites", {}).get(hero_id, ""))
		if asset_id == "":
			asset_id = String(art_manifest.get("hero_faction_sprites", {}).get(String(hero_value.get("faction_id", "")), ""))
		_audit_asset_id("hero", hero_id, asset_id, object_assets)
	if not _failures.is_empty():
		return {}
	return {
		"map_object_definition_count": map_objects.size(),
		"resource_site_definition_count": resource_sites.size(),
		"artifact_definition_count": artifacts.size(),
		"encounter_definition_count": encounters.size(),
		"town_definition_count": towns.size(),
		"hero_definition_count": heroes.size(),
		"object_asset_count": object_assets.size(),
	}

func _audit_mapping_asset(kind: String, content_id: String, mapping: Variant, object_assets: Dictionary) -> void:
	var asset_id := String(mapping.get("asset_id", "")) if mapping is Dictionary else String(mapping)
	_audit_asset_id(kind, content_id, asset_id, object_assets)

func _audit_asset_id(kind: String, content_id: String, asset_id: String, object_assets: Dictionary) -> void:
	if asset_id.strip_edges() == "":
		_record_failure("%s %s has no mapped sprite asset" % [kind, content_id])
		return
	var entry: Dictionary = object_assets.get(asset_id, {}) if object_assets.get(asset_id, {}) is Dictionary else {}
	var path := String(entry.get("path", ""))
	if path == "" or not ResourceLoader.exists(path):
		_record_failure("%s %s maps to unavailable asset %s at %s" % [kind, content_id, asset_id, path])

func _audit_authored_scenarios(view: Variant) -> void:
	var scenarios: Array = ContentService.load_json("res://content/scenarios.json").get("items", [])
	for scenario_value in scenarios:
		if not (scenario_value is Dictionary):
			continue
		var scenario_id := String(scenario_value.get("id", ""))
		var session: SessionStateStoreScript.SessionData = ScenarioFactoryScript.create_session(scenario_id, "normal", SessionStateStoreScript.LAUNCH_MODE_SKIRMISH)
		OverworldRules.normalize_overworld_state(session)
		_reveal_all(session)
		_audit_session(view, session, "authored:%s" % scenario_id, false)
		_counts["authored_scenarios"] = int(_counts.get("authored_scenarios", 0)) + 1

func _audit_generated_cases(view: Variant) -> void:
	if not ClassDB.class_exists("MapPackageService"):
		_record_failure("MapPackageService is unavailable for generated-map art coverage")
		return
	var service: Variant = ClassDB.instantiate("MapPackageService")
	for case_value in GENERATED_CASES:
		var case: Dictionary = case_value
		var config := ScenarioSelectRulesScript.build_random_map_player_config(
			String(case.get("seed", "")),
			"",
			"",
			int(case.get("player_count", 3)),
			"land",
			false,
			String(case.get("size_class_id", "homm3_small"))
		)
		var generated: Dictionary = service.generate_random_map(config, {"startup_path": "overworld_live_object_art_coverage_%s" % String(case.get("id", "case"))})
		if not bool(generated.get("ok", false)):
			_record_failure("generated %s map failed: %s" % [case.get("id", ""), JSON.stringify(generated.get("failures", generated))])
			continue
		var adoption: Dictionary = service.convert_generated_payload(generated, {
			"feature_gate": "overworld_live_object_art_coverage",
			"session_save_version": SessionStateStoreScript.SAVE_VERSION,
			"scenario_id": "overworld_live_object_art_coverage_%s" % String(case.get("id", "case")),
		})
		if not bool(adoption.get("ok", false)):
			_record_failure("generated %s adoption failed: %s" % [case.get("id", ""), JSON.stringify(adoption)])
			continue
		var session: Variant = NativeRandomMapPackageSessionBridgeScript.build_session_from_adoption(adoption, "normal", {})
		OverworldRules.normalize_overworld_state(session)
		_reveal_all(session)
		_audit_session(view, session, "generated:%s" % String(case.get("id", "")), true)
		_counts["generated_cases"] = int(_counts.get("generated_cases", 0)) + 1

func _audit_session(view: Variant, session: Variant, source: String, generated: bool) -> void:
	var map_size := OverworldRules.derive_map_size(session)
	view.set_map_state(session, session.overworld.get("map", []), map_size, OverworldRules.hero_position(session))
	for spec in [
		{"collection": "towns", "kind": "town", "flag": "has_town"},
		{"collection": "resource_nodes", "kind": "resource", "flag": "has_resource"},
		{"collection": "artifact_nodes", "kind": "artifact", "flag": "has_artifact"},
		{"collection": "encounters", "kind": "encounter", "flag": "has_visible_encounter"},
	]:
		for value in session.overworld.get(String(spec.get("collection", "")), []):
			if value is Dictionary:
				_audit_tile_object(view, value, source, String(spec.get("kind", "")), String(spec.get("flag", "")))
	for hero_value in HeroCommandRules.hero_positions(session):
		if not (hero_value is Dictionary):
			continue
		var tile := Vector2i(int(hero_value.get("x", -1)), int(hero_value.get("y", -1)))
		var presentation: Dictionary = view.validation_tile_presentation(tile)
		var hero: Dictionary = presentation.get("hero_presentation", {}) if presentation.get("hero_presentation", {}) is Dictionary else {}
		_counts["heroes"] = int(_counts.get("heroes", 0)) + 1
		if hero.is_empty() or bool(hero.get("uses_procedural_fallback", true)) or String(hero.get("sprite_asset_id", "")) == "":
			_record_failure("%s hero %s at %s lacks live art: %s" % [source, hero_value.get("id", ""), tile, JSON.stringify(hero)])
		else:
			_asset_ids[String(hero.get("sprite_asset_id", ""))] = true
		var hero_layout: Dictionary = view.validation_hero_draw_layout(tile, false)
		var command_pennant: Dictionary = hero_layout.get("command_pennant", {}) if hero_layout.get("command_pennant", {}) is Dictionary else {}
		_counts["hero_command_pennants"] = int(_counts.get("hero_command_pennants", 0)) + 1
		_audit_pennant(command_pennant, source, "hero_command", String(hero_value.get("id", "")))
	for object_value in session.overworld.get("map_objects", []):
		if not (object_value is Dictionary):
			continue
		var object: Dictionary = object_value
		if String(object.get("runtime_object_role", "")) == "decorative_blocker_sprite":
			continue
		var tile := Vector2i(int(object.get("x", -1)), int(object.get("y", -1)))
		var presentation: Dictionary = view.validation_tile_presentation(tile)
		var expected_flag := "has_decorative_object" if bool(presentation.get("has_decorative_object", false)) else "has_standalone_map_object"
		_audit_tile_object(view, object, source, "standalone_map_object", expected_flag)
	if generated:
		var summary: Dictionary = view.validation_generated_object_visual_summary()
		_counts["generated_decorative_records"] = int(_counts.get("generated_decorative_records", 0)) + int(summary.get("generated_record_count", 0))
		_counts["generated_decorative_visual_anchors"] = int(_counts.get("generated_decorative_visual_anchors", 0)) + int(summary.get("visual_anchor_count", 0))
		if not bool(summary.get("body_tile_keys_exact", false)) \
			or not bool(summary.get("all_body_assets_loaded", false)) \
			or not bool(summary.get("all_generated_records_anchored", false)):
			_record_failure("%s generated decorative mass art is incomplete: %s" % [source, JSON.stringify({
				"generated_record_count": summary.get("generated_record_count", 0),
				"visual_anchor_count": summary.get("visual_anchor_count", 0),
				"body_tile_keys_exact": summary.get("body_tile_keys_exact", false),
				"all_body_assets_loaded": summary.get("all_body_assets_loaded", false),
				"all_generated_records_anchored": summary.get("all_generated_records_anchored", false),
			})])
		for entry_value in summary.get("body_entries", []):
			if entry_value is Dictionary and bool(entry_value.get("visual_anchor", false)):
				_asset_ids[String(entry_value.get("asset_id", ""))] = true

func _audit_tile_object(view: Variant, object: Dictionary, source: String, kind: String, expected_flag: String) -> void:
	var tile := Vector2i(int(object.get("x", -1)), int(object.get("y", -1)))
	var presentation: Dictionary = view.validation_tile_presentation(tile)
	var art: Dictionary = presentation.get("art_presentation", {}) if presentation.get("art_presentation", {}) is Dictionary else {}
	_counts[kind + "s"] = int(_counts.get(kind + "s", 0)) + 1
	if not bool(presentation.get(expected_flag, false)) \
		or not bool(art.get("uses_asset_sprite", false)) \
		or bool(art.get("fallback_procedural_marker", true)) \
		or not (art.get("sprite_asset_ids", []) is Array) \
		or art.get("sprite_asset_ids", []).is_empty():
		_record_failure("%s %s %s at %s lacks live art: %s" % [source, kind, object.get("placement_id", object.get("id", "")), tile, JSON.stringify(presentation)])
		return
	for asset_id_value in art.get("sprite_asset_ids", []):
		_asset_ids[String(asset_id_value)] = true
	if kind == "town":
		var town_presentation: Dictionary = presentation.get("town_presentation", {}) if presentation.get("town_presentation", {}) is Dictionary else {}
		var owner_pennant: Dictionary = town_presentation.get("owner_pennant", {}) if town_presentation.get("owner_pennant", {}) is Dictionary else {}
		_counts["town_ownership_pennants"] = int(_counts.get("town_ownership_pennants", 0)) + 1
		_audit_pennant(owner_pennant, source, "town_owner", String(object.get("placement_id", object.get("id", ""))))

func _audit_pennant(pennant: Dictionary, source: String, kind: String, placement_id: String) -> void:
	var asset_id := String(pennant.get("asset_id", ""))
	if asset_id == "" \
		or String(pennant.get("asset_path", "")) == "" \
		or not bool(pennant.get("asset_loaded", false)) \
		or not bool(pennant.get("asset_contained", false)) \
		or bool(pennant.get("procedural_fallback", true)):
		_record_failure("%s %s pennant %s lacks live image art: %s" % [source, kind, placement_id, JSON.stringify(pennant)])
		return
	_asset_ids[asset_id] = true

func _reveal_all(session: Variant) -> void:
	var map_size := OverworldRules.derive_map_size(session)
	var visible_tiles: Array = []
	var explored_tiles: Array = []
	for _y in range(map_size.y):
		var visible_row: Array = []
		var explored_row: Array = []
		for _x in range(map_size.x):
			visible_row.append(true)
			explored_row.append(true)
		visible_tiles.append(visible_row)
		explored_tiles.append(explored_row)
	session.overworld["fog"] = {
		"visible_tiles": visible_tiles,
		"explored_tiles": explored_tiles,
		"visible_count": map_size.x * map_size.y,
		"explored_count": map_size.x * map_size.y,
		"total_tiles": map_size.x * map_size.y,
	}

func _record_failure(message: String) -> void:
	if _failures.size() < MAX_REPORTED_FAILURES:
		_failures.append(message)

func _finish_failure() -> void:
	push_error("%s failed (%d retained findings): %s" % [REPORT_ID, _failures.size(), JSON.stringify(_failures)])
	get_tree().quit(1)
