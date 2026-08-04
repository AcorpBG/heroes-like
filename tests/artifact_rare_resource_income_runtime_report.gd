extends Node

const REPORT_ID := "ARTIFACT_RARE_RESOURCE_INCOME_RUNTIME_REPORT"
const SCENARIO_ID := "river-pass"
const RARE_RESOURCE_IDS := [
	"aetherglass",
	"embergrain",
	"peatwax",
	"verdant_grafts",
	"brass_scrip",
	"memory_salt",
]
const CASES := [
	{"artifact_id": "artifact_tollstone_ring", "resource_id": "embergrain", "faction_id": "faction_embercourt"},
	{"artifact_id": "artifact_mudglass_beads", "resource_id": "peatwax", "faction_id": "faction_mireclaw"},
	{"artifact_id": "artifact_choir_tuning_fork", "resource_id": "aetherglass", "faction_id": "faction_sunvault"},
	{"artifact_id": "artifact_living_bridge_knot", "resource_id": "verdant_grafts", "faction_id": "faction_thornwake"},
	{"artifact_id": "artifact_pressure_gauge_reliquary", "resource_id": "brass_scrip", "faction_id": "faction_brasshollow"},
	{"artifact_id": "artifact_black_sail_compass", "resource_id": "memory_salt", "faction_id": "faction_veilmourn"},
]

func _ready() -> void:
	call_deferred("_run")

func _run() -> void:
	if int(SessionStateStore.SAVE_VERSION) != 9:
		_fail("Faction artifact income unexpectedly changed save version: %d" % int(SessionStateStore.SAVE_VERSION))
		return

	var base_session = _session_with_hero(_fixture_hero(""))
	var base_before := _resources(base_session)
	var base_turn := OverworldRules.end_turn(base_session)
	if not bool(base_turn.get("ok", false)):
		_fail("Could not run baseline artifact economy turn: %s" % base_turn)
		return
	var base_delta := _resource_delta(base_before, _resources(base_session))
	var case_reports := []

	for case_value in CASES:
		var case_data: Dictionary = case_value
		var artifact_id := String(case_data.get("artifact_id", ""))
		var resource_id := String(case_data.get("resource_id", ""))
		var faction_id := String(case_data.get("faction_id", ""))
		var hero := _fixture_hero(artifact_id)
		var bonuses := ArtifactRules.aggregate_bonuses(hero)
		var daily_income: Dictionary = bonuses.get("daily_income", {}) if bonuses.get("daily_income", {}) is Dictionary else {}
		if not _assert_exact_rare_income("aggregate bonuses", daily_income, resource_id):
			return

		var runtime_report := ArtifactRules.artifact_equip_runtime_report(hero)
		var aggregate: Dictionary = runtime_report.get("aggregate_bonuses", {}) if runtime_report.get("aggregate_bonuses", {}) is Dictionary else {}
		var live_contexts: Dictionary = runtime_report.get("live_contexts", {}) if runtime_report.get("live_contexts", {}) is Dictionary else {}
		var runtime_policy: Dictionary = runtime_report.get("runtime_policy", {}) if runtime_report.get("runtime_policy", {}) is Dictionary else {}
		if not bool(runtime_report.get("ok", false)) or not bool(live_contexts.get("daily_rare_income", false)) or not bool(runtime_policy.get("rare_resource_activation", false)):
			_fail("Artifact runtime report did not activate %s income: %s" % [artifact_id, runtime_report])
			return
		if not _assert_exact_rare_income("runtime report", aggregate.get("daily_rare_income", {}), resource_id):
			return

		var resource_label := resource_id.replace("_", " ").capitalize()
		var effect_summary := ArtifactRules.artifact_effect_summary(artifact_id)
		var impact_summary := ArtifactRules.describe_single_artifact_impact(artifact_id)
		if not effect_summary.contains(resource_label) or not effect_summary.contains("/day") or not impact_summary.contains(resource_label) or not impact_summary.contains("/day"):
			_fail("Artifact public summaries omitted %s daily income: effect=%s impact=%s" % [resource_label, effect_summary, impact_summary])
			return

		var artifact_session = _session_with_hero(hero)
		var artifact_before := _resources(artifact_session)
		var artifact_turn := OverworldRules.end_turn(artifact_session)
		if not bool(artifact_turn.get("ok", false)):
			_fail("Could not run equipped turn for %s: %s" % [artifact_id, artifact_turn])
			return
		var artifact_delta := _resource_delta(artifact_before, _resources(artifact_session))
		var incremental_delta := _subtract_resources(artifact_delta, base_delta)
		if not _assert_exact_rare_income("player end turn", incremental_delta, resource_id):
			return

		var treasury := {}
		var captured_income := EnemyTurnRules._apply_empire_income(
			artifact_session,
			[],
			treasury,
			{"captured_artifact_ids": [artifact_id]}
		)
		if not _assert_exact_rare_income("strategic AI captured income", captured_income, resource_id):
			return
		if not _assert_exact_rare_income("strategic AI treasury", treasury, resource_id):
			return

		var valuation := EnemyAdventureRules.artifact_target_valuation_breakdown(
			artifact_session,
			{"faction_id": faction_id},
			{"placement_id": "rare_income_probe", "artifact_id": artifact_id, "x": 0, "y": 0},
			Vector2i.ZERO,
			faction_id,
			0
		)
		if valuation.is_empty() or "daily_rare_income" not in valuation.get("runtime_surfaces", []) or "economy" not in valuation.get("role_buckets", []) or not bool(valuation.get("faction_affinity_match", false)):
			_fail("Strategic AI valuation omitted faction rare income for %s: %s" % [artifact_id, valuation])
			return

		case_reports.append(
			{
				"artifact_id": artifact_id,
				"resource_id": resource_id,
				"player_daily_delta": int(incremental_delta.get(resource_id, 0)),
				"strategic_ai_daily_delta": int(captured_income.get(resource_id, 0)),
				"runtime_surfaces": valuation.get("runtime_surfaces", []),
				"effect_summary": effect_summary,
			}
		)

	var payload := {
		"ok": true,
		"report_id": REPORT_ID,
		"case_count": case_reports.size(),
		"cases": case_reports,
		"save_version": int(SessionStateStore.SAVE_VERSION),
		"preserved_boundaries": {
			"normal_market_rare_buying": false,
			"spell_resource_cost_mode": "mana_only",
			"new_artifact_ids": false,
		},
	}
	if not _assert_public_payload(payload):
		return
	print("%s %s" % [REPORT_ID, JSON.stringify(payload)])
	get_tree().quit(0)

func _fixture_hero(artifact_id: String) -> Dictionary:
	var equipped := {}
	if artifact_id != "":
		equipped["trinket"] = artifact_id
	return {
		"id": "rare_income_fixture_hero",
		"name": "Rare Income Fixture Hero",
		"level": 1,
		"base_movement": 10,
		"command": {"attack": 1, "defense": 1, "power": 1, "knowledge": 1},
		"artifacts": ArtifactRules.normalize_hero_artifacts({"equipped": equipped, "inventory": []}),
		"specialties": [],
	}

func _session_with_hero(hero: Dictionary):
	var session = ScenarioFactory.create_session(SCENARIO_ID, "normal", SessionState.LAUNCH_MODE_SKIRMISH)
	var session_hero := hero.duplicate(true)
	session_hero["position"] = session.overworld.get("hero_position", {"x": 0, "y": 0})
	session_hero["army"] = session.overworld.get("army", {})
	session_hero["movement"] = session.overworld.get("movement", {"current": 10, "max": 10})
	session.overworld["active_hero_id"] = String(session_hero.get("id", ""))
	session.overworld["player_heroes"] = [session_hero]
	session.overworld["hero"] = session_hero
	return session

func _resources(session) -> Dictionary:
	return (session.overworld.get("resources", {}) as Dictionary).duplicate(true)

func _resource_delta(before: Dictionary, after: Dictionary) -> Dictionary:
	var delta := {}
	for resource_id in RARE_RESOURCE_IDS:
		delta[resource_id] = int(after.get(resource_id, 0)) - int(before.get(resource_id, 0))
	return delta

func _subtract_resources(left: Dictionary, right: Dictionary) -> Dictionary:
	var result := {}
	for resource_id in RARE_RESOURCE_IDS:
		result[resource_id] = int(left.get(resource_id, 0)) - int(right.get(resource_id, 0))
	return result

func _assert_exact_rare_income(label: String, resources: Variant, expected_resource_id: String) -> bool:
	if not (resources is Dictionary):
		_fail("%s did not return a resource dictionary: %s" % [label, resources])
		return false
	for resource_id in RARE_RESOURCE_IDS:
		var expected := 1 if resource_id == expected_resource_id else 0
		if int(resources.get(resource_id, 0)) != expected:
			_fail("%s did not grant exactly one %s and no other rare resource: %s" % [label, expected_resource_id, resources])
			return false
	return true

func _assert_public_payload(payload: Dictionary) -> bool:
	var surface_text := JSON.stringify(payload).to_lower()
	for leak_token in ["debug", "score", "internal"]:
		if surface_text.contains(leak_token):
			_fail("Rare-income report leaked %s: %s" % [leak_token, surface_text])
			return false
	return true

func _fail(message: String) -> void:
	var payload := {"ok": false, "report_id": REPORT_ID, "error": message}
	push_error(message)
	print("%s %s" % [REPORT_ID, JSON.stringify(payload)])
	get_tree().quit(1)
