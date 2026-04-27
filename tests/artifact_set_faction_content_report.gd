extends Node

const REPORT_ID := "ARTIFACT_SET_FACTION_CONTENT_REPORT"

func _ready() -> void:
	call_deferred("_run")

func _run() -> void:
	var raw := ContentService.load_json(ContentService.ARTIFACTS_PATH)
	var artifacts: Array = raw.get("items", [])
	var sets: Array = raw.get("sets", [])
	var report := ArtifactRules.artifact_set_faction_report(artifacts, sets)
	if not bool(report.get("ok", false)):
		_fail("Artifact set/faction report failed: %s" % report)
		return
	if int(report.get("set_count", 0)) != 1:
		_fail("Expected one bounded artifact set in this slice: %s" % report)
		return
	if int(report.get("set_piece_count", 0)) != 3:
		_fail("Expected three Wayfarer Compact set pieces: %s" % report)
		return
	if int(report.get("faction_affinity_artifact_count", 0)) != 6:
		_fail("Expected one faction-affinity artifact for each of six factions: %s" % report)
		return

	var set_piece_counts: Dictionary = report.get("set_piece_counts", {}) if report.get("set_piece_counts", {}) is Dictionary else {}
	if int(set_piece_counts.get("set_wayfarer_compact", 0)) != 3:
		_fail("Wayfarer Compact piece count was not reported correctly: %s" % report)
		return

	var faction_counts: Dictionary = report.get("faction_affinity_counts", {}) if report.get("faction_affinity_counts", {}) is Dictionary else {}
	for faction_id in [
		"faction_embercourt",
		"faction_mireclaw",
		"faction_sunvault",
		"faction_thornwake",
		"faction_brasshollow",
		"faction_veilmourn",
	]:
		if int(faction_counts.get(faction_id, 0)) != 1:
			_fail("Faction affinity count missing %s: %s" % [faction_id, report])
			return

	var set_reports: Array = report.get("set_reports", []) if report.get("set_reports", []) is Array else []
	if set_reports.is_empty():
		_fail("Report did not include set details: %s" % report)
		return
	var wayfarer: Dictionary = set_reports[0]
	var slot_counts: Dictionary = wayfarer.get("slot_counts", {}) if wayfarer.get("slot_counts", {}) is Dictionary else {}
	if int(slot_counts.get("boots", 0)) != 1 or int(slot_counts.get("trinket", 0)) != 2:
		_fail("Wayfarer Compact should fit current slot limits: %s" % report)
		return

	var policy: Dictionary = report.get("runtime_policy", {}) if report.get("runtime_policy", {}) is Dictionary else {}
	if bool(policy.get("save_version_bump", true)) or bool(policy.get("source_reward_tables_active", true)) or bool(policy.get("set_bonuses_active", true)) or bool(policy.get("ai_valuation_behavior", true)) or bool(policy.get("rare_resource_activation", true)):
		_fail("Artifact set/faction report crossed slice boundaries: %s" % policy)
		return

	var compass_context := ArtifactRules.artifact_set_context("artifact_waymark_compass")
	if not compass_context.contains("Wayfarer Compact"):
		_fail("Set context helper did not expose Wayfarer Compact: %s" % compass_context)
		return
	var tollstone_taxonomy := ArtifactRules.artifact_taxonomy("artifact_tollstone_ring")
	var tollstone_factions: Array = tollstone_taxonomy.get("faction_affinity", []) if tollstone_taxonomy.get("faction_affinity", []) is Array else []
	if "faction_embercourt" not in tollstone_factions:
		_fail("Faction affinity helper did not expose Embercourt Tollstone Ring: %s" % tollstone_taxonomy)
		return

	if not _assert_public_payload("artifact set/faction report", report):
		return
	if not _assert_public_payload("set context", compass_context):
		return

	var payload := {
		"ok": true,
		"report_id": REPORT_ID,
		"schema_id": String(report.get("schema_id", "")),
		"set_count": int(report.get("set_count", 0)),
		"set_piece_count": int(report.get("set_piece_count", 0)),
		"set_piece_counts": set_piece_counts,
		"faction_affinity_counts": faction_counts,
		"runtime_policy": policy,
		"caveats": [
			"This report proves bounded artifact set and faction-affinity content metadata only; live source execution, equip-time set bonuses, save migration, AI valuation behavior, and rare-resource activation remain outside this slice.",
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
