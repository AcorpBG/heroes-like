extends Node

const REPORT_ID := "ARTIFACT_SOURCE_REWARD_REPORT"

func _ready() -> void:
	call_deferred("_run")

func _run() -> void:
	var raw := ContentService.load_json(ContentService.ARTIFACTS_PATH)
	var artifacts: Array = raw.get("items", [])
	var tables: Array = raw.get("source_reward_tables", [])
	var map_objects: Array = ContentService.load_json(ContentService.MAP_OBJECTS_PATH).get("items", [])
	var resource_sites: Array = ContentService.load_json(ContentService.RESOURCE_SITES_PATH).get("items", [])
	var report := ArtifactRules.artifact_source_reward_report(artifacts, tables, map_objects, resource_sites)
	if not bool(report.get("ok", false)):
		_fail("Artifact source/reward report failed: %s" % report)
		return
	if int(report.get("table_count", 0)) != 6:
		_fail("Expected six bounded artifact source/reward tables: %s" % report)
		return
	if int(report.get("eligible_artifact_count", 0)) != int(report.get("artifact_count", 0)):
		_fail("Source/reward tables did not cover every authored artifact: %s" % report)
		return
	if int(report.get("map_object_context_match_count", 0)) <= 0 or int(report.get("resource_site_context_match_count", 0)) <= 0:
		_fail("Source/reward tables did not connect to map object and resource-site contexts: %s" % report)
		return
	if int(report.get("guarded_context_match_count", 0)) <= 0:
		_fail("Source/reward tables did not connect to guarded reward contexts: %s" % report)
		return

	var source_tag_counts: Dictionary = report.get("source_tag_counts", {}) if report.get("source_tag_counts", {}) is Dictionary else {}
	for source_tag in ["pickup", "guarded_site", "shrine", "dwelling", "town", "battle_salvage"]:
		if int(source_tag_counts.get(source_tag, 0)) < 1:
			_fail("Missing source tag coverage for %s: %s" % [source_tag, report])
			return
	var guard_tier_counts: Dictionary = report.get("guard_tier_counts", {}) if report.get("guard_tier_counts", {}) is Dictionary else {}
	for guard_tier in ["unguarded", "standard", "heavy", "elite"]:
		if int(guard_tier_counts.get(guard_tier, 0)) < 1:
			_fail("Missing guard tier coverage for %s: %s" % [guard_tier, report])
			return

	var policy: Dictionary = report.get("runtime_policy", {}) if report.get("runtime_policy", {}) is Dictionary else {}
	if not bool(policy.get("source_reward_metadata_authored", false)) or bool(policy.get("live_drop_execution", true)) or bool(policy.get("equipment_runtime_effects", true)) or bool(policy.get("save_version_bump", true)) or bool(policy.get("ai_valuation_behavior", true)) or bool(policy.get("rare_resource_activation", true)):
		_fail("Artifact source/reward report crossed slice runtime boundaries: %s" % policy)
		return
	if not _assert_public_payload("artifact source/reward report", report):
		return

	var payload := {
		"ok": true,
		"report_id": REPORT_ID,
		"schema_id": String(report.get("schema_id", "")),
		"table_count": int(report.get("table_count", 0)),
		"eligible_artifact_count": int(report.get("eligible_artifact_count", 0)),
		"artifact_count": int(report.get("artifact_count", 0)),
		"source_tag_counts": source_tag_counts,
		"guard_tier_counts": guard_tier_counts,
		"map_object_context_match_count": int(report.get("map_object_context_match_count", 0)),
		"resource_site_context_match_count": int(report.get("resource_site_context_match_count", 0)),
		"guarded_context_match_count": int(report.get("guarded_context_match_count", 0)),
		"runtime_policy": policy,
		"caveats": [
			"This report proves bounded artifact source/reward metadata and map object/site report hooks only; live drop execution, equipment effects, save migration, AI valuation behavior, and rare-resource activation remain outside this slice.",
		],
	}
	print("%s %s" % [REPORT_ID, JSON.stringify(payload)])
	get_tree().quit(0)

func _assert_public_payload(label: String, payload: Variant) -> bool:
	var surface_text := JSON.stringify(payload).to_lower()
	for leak_token in ["debug", "score", "internal"]:
		if surface_text.contains(leak_token):
			_fail("%s leaked %s: %s" % [label, leak_token, surface_text])
			return false
	return true

func _fail(message: String) -> void:
	var payload := {"ok": false, "report_id": REPORT_ID, "error": message}
	print("%s %s" % [REPORT_ID, JSON.stringify(payload)])
	get_tree().quit(1)
