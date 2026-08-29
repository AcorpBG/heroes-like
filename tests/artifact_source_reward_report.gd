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
	if int(report.get("table_count", 0)) != 7:
		_fail("Expected six live source/reward tables plus one authored-placement metadata table: %s" % report)
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
	if int(report.get("live_table_count", 0)) != 6 or report.get("live_source_tags", []) != ["pickup", "guarded_site", "shrine", "dwelling", "town", "battle_salvage"]:
		_fail("Expected pickup, guarded-site, shrine, dwelling, town, and battle-salvage source tables to execute live: %s" % report)
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
	if not bool(policy.get("source_reward_metadata_authored", false)) or not bool(policy.get("live_drop_execution", false)) or bool(policy.get("equipment_runtime_effects", true)) or bool(policy.get("save_version_bump", true)) or bool(policy.get("ai_valuation_behavior", true)) or not bool(policy.get("rare_resource_activation", false)):
		_fail("Artifact source/reward report crossed slice runtime boundaries: %s" % policy)
		return
	for table_value in report.get("table_reports", []):
		var table: Dictionary = table_value if table_value is Dictionary else {}
		var table_policy: Dictionary = table.get("runtime_policy", {}) if table.get("runtime_policy", {}) is Dictionary else {}
		var expected_rare_activation := String(table.get("source_tag", "")) != "pickup"
		if bool(table_policy.get("rare_resource_activation", false)) != expected_rare_activation:
			_fail("Artifact source table did not match its rare-income payloads: %s" % table)
			return
	if not _assert_public_payload("artifact source/reward report", report):
		return

	var payload := {
		"ok": true,
		"report_id": REPORT_ID,
		"schema_id": String(report.get("schema_id", "")),
		"table_count": int(report.get("table_count", 0)),
		"live_table_count": int(report.get("live_table_count", 0)),
		"live_source_tags": report.get("live_source_tags", []),
		"eligible_artifact_count": int(report.get("eligible_artifact_count", 0)),
		"artifact_count": int(report.get("artifact_count", 0)),
		"source_tag_counts": source_tag_counts,
		"guard_tier_counts": guard_tier_counts,
		"map_object_context_match_count": int(report.get("map_object_context_match_count", 0)),
		"resource_site_context_match_count": int(report.get("resource_site_context_match_count", 0)),
		"guarded_context_match_count": int(report.get("guarded_context_match_count", 0)),
		"runtime_policy": policy,
		"caveats": [
			"Only explicitly opted-in pickup caches, guarded sites, Starlens Sanctum, Rootwatch Hollow, Greenbranch Copse, Lockhouse Tally, Scalehouse, and Bellwake battle salvage execute source-table rewards; other pickups, shrines, dwellings, town buildings, save migration, and broad AI changes remain outside this slice.",
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
