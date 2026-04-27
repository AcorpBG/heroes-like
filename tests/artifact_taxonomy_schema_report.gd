extends Node

const REPORT_ID := "ARTIFACT_TAXONOMY_SCHEMA_REPORT"

func _ready() -> void:
	call_deferred("_run")

func _run() -> void:
	var raw := ContentService.load_json(ContentService.ARTIFACTS_PATH)
	var artifacts: Array = raw.get("items", [])
	var report := ArtifactRules.artifact_schema_report(artifacts)
	if not bool(report.get("ok", false)):
		_fail("Artifact taxonomy report failed: %s" % report)
		return
	if int(report.get("artifact_count", 0)) != 4:
		_fail("Expected four existing artifact records in this bounded slice: %s" % report)
		return
	if int(report.get("complete_taxonomy_count", 0)) != int(report.get("artifact_count", 0)):
		_fail("Not every artifact has complete taxonomy metadata: %s" % report)
		return
	if int(report.get("equip_constraint_count", 0)) != int(report.get("artifact_count", 0)):
		_fail("Not every artifact has equip constraint metadata: %s" % report)
		return
	if int(report.get("bonus_metadata_count", 0)) != int(report.get("artifact_count", 0)):
		_fail("Not every artifact has bonus metadata: %s" % report)
		return
	if not _assert_report_count(report, "slot_counts", "trinket", 1):
		return
	if not _assert_report_count(report, "rarity_counts", "common", 2):
		return
	if not _assert_report_count(report, "class_counts", "crafted", 3):
		return
	if not _assert_report_count(report, "role_counts", "economy", 1):
		return
	if not _assert_report_count(report, "source_tag_counts", "guarded_site", 4):
		return

	var boots_taxonomy := ArtifactRules.artifact_taxonomy("artifact_trailsinger_boots")
	if String(boots_taxonomy.get("rarity", "")) != "common" or String(boots_taxonomy.get("family", "")) != "roadfinder_gear":
		_fail("Trailsinger Boots taxonomy did not load from ArtifactRules: %s" % boots_taxonomy)
		return
	var boots_summary := ArtifactRules.describe_artifact_short("artifact_trailsinger_boots")
	if not boots_summary.contains("Common Roadfinder Gear") or not boots_summary.contains("Movement"):
		_fail("Artifact short description did not expose compact taxonomy: %s" % boots_summary)
		return
	var policy: Dictionary = report.get("runtime_policy", {}) if report.get("runtime_policy", {}) is Dictionary else {}
	if bool(policy.get("save_version_bump", true)) or bool(policy.get("source_reward_tables_active", true)) or bool(policy.get("rare_resource_activation", true)):
		_fail("Artifact taxonomy report crossed slice runtime boundaries: %s" % policy)
		return
	if not _assert_public_payload("artifact report", report):
		return
	if not _assert_public_payload("artifact summary", boots_summary):
		return

	var payload := {
		"ok": true,
		"report_id": REPORT_ID,
		"schema_status": String(report.get("schema_status", "")),
		"schema_id": String(report.get("schema_id", "")),
		"artifact_count": int(report.get("artifact_count", 0)),
		"complete_taxonomy_count": int(report.get("complete_taxonomy_count", 0)),
		"slot_counts": report.get("slot_counts", {}),
		"rarity_counts": report.get("rarity_counts", {}),
		"class_counts": report.get("class_counts", {}),
		"role_counts": report.get("role_counts", {}),
		"source_tag_counts": report.get("source_tag_counts", {}),
		"runtime_policy": policy,
		"caveats": [
			"This report proves additive artifact taxonomy/schema metadata and ArtifactRules report helpers only; set bonuses, source tables, runtime equipment migration, AI valuation behavior, save migration, and rare-resource activation remain outside this slice.",
		],
	}
	print("%s %s" % [REPORT_ID, JSON.stringify(payload)])
	get_tree().quit(0)

func _assert_report_count(report: Dictionary, bucket_name: String, key: String, minimum: int) -> bool:
	var bucket: Dictionary = report.get(bucket_name, {}) if report.get(bucket_name, {}) is Dictionary else {}
	if int(bucket.get(key, 0)) < minimum:
		_fail("Expected %s.%s >= %d: %s" % [bucket_name, key, minimum, report])
		return false
	return true

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
