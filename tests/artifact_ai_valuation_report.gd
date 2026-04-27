extends Node

const REPORT_ID := "ARTIFACT_AI_VALUATION_REPORT"
const SCENARIO_ID := "river-pass"
const FACTION_ID := "faction_mireclaw"
const ORIGIN := {"x": 7, "y": 1}
const BLOCKED_PUBLIC_TOKENS := [
	"base_value",
	"taxonomy_value",
	"runtime_value",
	"source_value",
	"affinity_value",
	"set_context_value",
	"objective_value",
	"faction_bias",
	"travel_cost",
	"assignment_penalty",
	"final_priority",
	"priority",
	"debug",
	"internal",
	"score",
	"breakdown",
]

func _ready() -> void:
	call_deferred("_run")

func _run() -> void:
	var session = ScenarioFactory.create_session(
		SCENARIO_ID,
		"normal",
		SessionState.LAUNCH_MODE_SKIRMISH
	)
	OverworldRules.normalize_overworld_state(session)
	var config := _enemy_config()
	if config.is_empty():
		return

	var report := EnemyAdventureRules.artifact_reward_valuation_report(session, config, ORIGIN, FACTION_ID, 0)
	if not bool(report.get("ok", false)):
		_fail("Artifact AI valuation report failed: %s" % report)
		return
	if String(report.get("schema", "")) != "artifact_ai_valuation_v1":
		_fail("Artifact AI valuation report used an unexpected schema: %s" % report)
		return
	if int(report.get("target_count", 0)) != 4:
		_fail("Expected River Pass artifact AI report to value four artifact nodes: %s" % report)
		return

	var role_counts: Dictionary = report.get("role_bucket_counts", {}) if report.get("role_bucket_counts", {}) is Dictionary else {}
	for role_bucket in ["route", "scouting", "economy", "command", "defense", "magic", "progression"]:
		if int(role_counts.get(role_bucket, 0)) <= 0:
			_fail("Artifact AI valuation missed role bucket %s: %s" % [role_bucket, report])
			return
	var runtime_counts: Dictionary = report.get("runtime_surface_counts", {}) if report.get("runtime_surface_counts", {}) is Dictionary else {}
	for runtime_surface in ["adventure_movement", "adventure_scouting", "battle_command", "daily_common_income", "spell_modifier"]:
		if int(runtime_counts.get(runtime_surface, 0)) <= 0:
			_fail("Artifact AI valuation missed runtime surface %s: %s" % [runtime_surface, report])
			return
	var source_counts: Dictionary = report.get("source_context_counts", {}) if report.get("source_context_counts", {}) is Dictionary else {}
	for source_context in ["pickup", "guarded_site", "town", "battle_salvage", "set_chain"]:
		if int(source_counts.get(source_context, 0)) <= 0:
			_fail("Artifact AI valuation missed source context %s: %s" % [source_context, report])
			return
	if int(report.get("set_piece_count", 0)) <= 0:
		_fail("Artifact AI valuation did not consume set context: %s" % report)
		return

	var public_targets: Array = report.get("public_targets", []) if report.get("public_targets", []) is Array else []
	var trailsinger := _target_by_artifact(public_targets, "artifact_trailsinger_boots")
	var warcrest := _target_by_artifact(public_targets, "artifact_warcrest_pennon")
	var tally := _target_by_artifact(public_targets, "artifact_quarry_tally_rod")
	var gorget := _target_by_artifact(public_targets, "artifact_bastion_gorget")
	if trailsinger.is_empty() or warcrest.is_empty() or tally.is_empty() or gorget.is_empty():
		_fail("Artifact AI valuation public targets omitted expected artifacts: %s" % public_targets)
		return
	if String(trailsinger.get("set_context", "")) != "set_piece" or String(trailsinger.get("public_reason", "")) != "route scouting relic":
		_fail("Trailsinger metadata did not produce set route/scouting public valuation: %s" % trailsinger)
		return
	if String(tally.get("public_reason", "")) != "economy support relic":
		_fail("Quarry Tally Rod did not produce economy valuation: %s" % tally)
		return
	if String(warcrest.get("public_reason", "")) != "command relic":
		_fail("Warcrest Pennon did not produce command valuation: %s" % warcrest)
		return
	if String(gorget.get("public_reason", "")) != "defensive relic":
		_fail("Bastion Gorget did not produce defensive valuation: %s" % gorget)
		return

	var faction_fit := EnemyAdventureRules.artifact_target_valuation_breakdown(
		session,
		config,
		{
			"placement_id": "mireclaw_faction_artifact_probe",
			"artifact_id": "artifact_mudglass_beads",
			"x": 6,
			"y": 1,
		},
		Vector2i(int(ORIGIN.get("x", 0)), int(ORIGIN.get("y", 0))),
		FACTION_ID
	)
	if faction_fit.is_empty() or not bool(faction_fit.get("faction_affinity_match", false)):
		_fail("Artifact AI valuation did not consume faction affinity metadata: %s" % faction_fit)
		return
	if String(faction_fit.get("public_reason", "")) != "faction-fit relic":
		_fail("Faction affinity did not produce compact faction-fit public reason: %s" % faction_fit)
		return

	var leak_check := EnemyAdventureRules.artifact_ai_public_leak_check(report)
	if not bool(leak_check.get("ok", false)):
		_fail(String(leak_check.get("error", "public leak check failed")))
		return
	if not _assert_no_public_leaks("artifact AI valuation report", report):
		return

	var payload := {
		"ok": true,
		"report_id": REPORT_ID,
		"scenario_id": SCENARIO_ID,
		"faction_id": FACTION_ID,
		"target_count": int(report.get("target_count", 0)),
		"role_bucket_counts": role_counts,
		"runtime_surface_counts": runtime_counts,
		"source_context_counts": source_counts,
		"strategic_band_counts": report.get("strategic_band_counts", {}),
		"set_piece_count": int(report.get("set_piece_count", 0)),
		"public_targets": public_targets,
		"public_leak_check": {
			"ok": true,
			"checked_records": int(leak_check.get("checked_records", 0)),
		},
		"runtime_policy": report.get("runtime_policy", {}),
		"caveats": [
			"This report proves bounded artifact AI valuation helpers and public-safe report payloads only; live artifact source/drop execution, broad AI behavior changes, save migration, set bonus activation, and rare-resource activation remain outside this slice.",
		],
	}
	if not _assert_no_public_leaks("final artifact AI valuation payload", payload):
		return
	print("%s %s" % [REPORT_ID, JSON.stringify(payload)])
	get_tree().quit(0)

func _target_by_artifact(targets: Array, artifact_id: String) -> Dictionary:
	for target in targets:
		if target is Dictionary and String(target.get("artifact_id", "")) == artifact_id:
			return target
	return {}

func _enemy_config() -> Dictionary:
	var scenario := ContentService.get_scenario(SCENARIO_ID)
	for config in scenario.get("enemy_factions", []):
		if config is Dictionary and String(config.get("faction_id", "")) == FACTION_ID:
			return config
	_fail("Could not find enemy config for %s" % FACTION_ID)
	return {}

func _assert_no_public_leaks(label: String, payload: Variant) -> bool:
	var surface_text := JSON.stringify(payload)
	for token in BLOCKED_PUBLIC_TOKENS:
		if surface_text.contains(String(token)):
			_fail("%s leaked %s: %s" % [label, token, surface_text])
			return false
	return true

func _fail(message: String) -> void:
	var payload := {"ok": false, "report_id": REPORT_ID, "error": message}
	push_error(message)
	print("%s %s" % [REPORT_ID, JSON.stringify(payload)])
	get_tree().quit(1)
