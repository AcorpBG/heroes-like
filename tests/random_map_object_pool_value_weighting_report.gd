extends Node

const RandomMapGeneratorRulesScript = preload("res://scripts/core/RandomMapGeneratorRules.gd")
const REPORT_ID := "RANDOM_MAP_OBJECT_POOL_VALUE_WEIGHTING_REPORT"

func _ready() -> void:
	call_deferred("_run")

func _run() -> void:
	var generator = RandomMapGeneratorRulesScript.new()
	var config := _config("object-pool-value-weighting-10184")
	var report: Dictionary = generator.object_pool_value_weighting_report(config)
	if not bool(report.get("ok", false)):
		_fail("Object pool value weighting report failed: %s" % JSON.stringify(report))
		return
	if String(report.get("schema_id", "")) != RandomMapGeneratorRulesScript.OBJECT_POOL_VALUE_WEIGHTING_REPORT_SCHEMA_ID:
		_fail("Report schema id mismatch: %s" % JSON.stringify(report))
		return
	if not bool(report.get("same_input_object_pool_value_weighting_signature_equivalent", false)):
		_fail("Same seed/config changed object-pool signature.")
		return
	if not bool(report.get("changed_seed_changes_object_pool_value_weighting_signature", false)):
		_fail("Changed seed did not change object-pool signature.")
		return
	if not bool(report.get("changed_profile_changes_object_pool_value_weighting_signature", false)):
		_fail("Changed profile/template did not change object-pool signature.")
		return

	var generated: Dictionary = generator.generate(config)
	if not bool(generated.get("ok", false)):
		_fail("Generated payload validation failed: %s" % JSON.stringify(generated.get("report", {})))
		return
	var payload: Dictionary = generated.get("generated_map", {})
	var pool: Dictionary = payload.get("staging", {}).get("object_pool_value_weighting", {})
	if not _assert_pool_payload(pool):
		return
	if not _assert_selected_candidates(pool):
		return
	if not _assert_runtime_boundaries(payload):
		return

	print("%s %s" % [REPORT_ID, JSON.stringify({
		"ok": true,
		"stable_signature": payload.get("stable_signature", ""),
		"object_pool_value_weighting_signature": pool.get("object_pool_value_weighting_signature", ""),
		"changed_seed_object_pool_value_weighting_signature": report.get("changed_seed_object_pool_value_weighting_signature", ""),
		"changed_profile_object_pool_value_weighting_signature": report.get("changed_profile_object_pool_value_weighting_signature", ""),
		"summary": pool.get("summary", {}),
		"object_counts": pool.get("object_counts", {}),
		"value_totals": pool.get("value_totals", {}),
		"fairness_deltas": pool.get("fairness_deltas", {}),
	})])
	get_tree().quit(0)

func _config(seed: String) -> Dictionary:
	return {
		"generator_version": RandomMapGeneratorRulesScript.GENERATOR_VERSION,
		"seed": seed,
		"size": {"preset": "object_pool_value_weighting", "width": 30, "height": 22, "water_mode": "land", "level_count": 1},
		"player_constraints": {"human_count": 1, "computer_count": 2},
		"profile": {
			"id": "frontier_spokes_profile_v1",
			"template_id": "frontier_spokes_v1",
			"guard_strength_profile": "core_low",
			"faction_ids": ["faction_embercourt", "faction_mireclaw", "faction_sunvault"],
		},
	}

func _assert_pool_payload(pool: Dictionary) -> bool:
	if String(pool.get("schema_id", "")) != RandomMapGeneratorRulesScript.OBJECT_POOL_VALUE_WEIGHTING_SCHEMA_ID:
		_fail("Missing object-pool schema payload: %s" % JSON.stringify(pool))
		return false
	if String(pool.get("object_pool_value_weighting_signature", "")) == "":
		_fail("Object-pool signature missing.")
		return false
	var catalog: Dictionary = pool.get("candidate_pool_catalog", {})
	var pool_ids := {}
	for pool_record in catalog.get("pools", []):
		if pool_record is Dictionary:
			pool_ids[String(pool_record.get("pool_id", ""))] = true
	for required_pool in ["reward_value_bands", "seven_category_mines", "neutral_dwelling_recruitment", "terrain_biased_decoration"]:
		if not pool_ids.has(required_pool):
			_fail("Candidate pool missing %s: %s" % [required_pool, JSON.stringify(catalog)])
			return false
	var equivalents: Dictionary = catalog.get("artifact_spell_skill_equivalents", {})
	if equivalents.get("artifact_ids", []).is_empty() or equivalents.get("spell_ids", []).is_empty() or equivalents.get("skill_equivalent_ids", []).is_empty():
		_fail("Artifact/spell/skill-equivalent pools were incomplete: %s" % JSON.stringify(equivalents))
		return false
	if not bool(pool.get("limit_validation", {}).get("ok", false)):
		_fail("Object limits failed: %s" % JSON.stringify(pool.get("limit_validation", {})))
		return false
	return true

func _assert_selected_candidates(pool: Dictionary) -> bool:
	var summary: Dictionary = pool.get("summary", {})
	for key in ["reward_candidate_count", "mine_candidate_count", "dwelling_candidate_count", "decoration_candidate_count"]:
		if int(summary.get(key, 0)) <= 0:
			_fail("Required selected candidate count missing %s: %s" % [key, JSON.stringify(summary)])
			return false
	if int(summary.get("total_selected_value", 0)) <= 0:
		_fail("Selected value total was not positive: %s" % JSON.stringify(summary))
		return false
	var saw_guarded_reward := false
	for record in pool.get("selected_candidates", []):
		if not (record is Dictionary):
			_fail("Selected candidate was not a dictionary.")
			return false
		if String(record.get("content_id", "")) == "" or String(record.get("pool_id", "")) == "":
			_fail("Selected candidate missed content/pool id: %s" % JSON.stringify(record))
			return false
		if not bool(record.get("selected_from_explicit_pool", false)):
			_fail("Selected candidate did not declare explicit pool selection: %s" % JSON.stringify(record))
			return false
		if String(record.get("kind", "")) == "reward" and bool(record.get("guarded", false)):
			saw_guarded_reward = true
	if not saw_guarded_reward:
		_fail("No guarded reward candidate was selected.")
		return false
	var fairness: Dictionary = pool.get("fairness_deltas", {})
	if fairness.get("zone_value_totals", {}).is_empty() or fairness.get("zone_value_delta", {}).is_empty():
		_fail("Fairness value deltas were not exposed: %s" % JSON.stringify(fairness))
		return false
	return true

func _assert_runtime_boundaries(payload: Dictionary) -> bool:
	if payload.get("staging", {}).get("object_pool_value_weighting", {}).is_empty():
		_fail("Staging missed object-pool value weighting payload.")
		return false
	if payload.get("scenario_record", {}).get("generated_constraints", {}).get("object_pool_value_weighting", {}).is_empty():
		_fail("Scenario generated constraints missed object-pool value weighting payload.")
		return false
	if String(payload.get("write_policy", "")) != "staged_payload_only_no_authored_content_write":
		_fail("Generated payload lost no-write policy.")
		return false
	var scenario: Dictionary = payload.get("scenario_record", {})
	if bool(scenario.get("selection", {}).get("availability", {}).get("campaign", true)) or bool(scenario.get("selection", {}).get("availability", {}).get("skirmish", true)):
		_fail("Object-pool slice adopted generated map into campaign or skirmish UI.")
		return false
	if payload.has("authored_content_writeback") or payload.has("save_adoption") or scenario.has("alpha_parity_claim"):
		_fail("Object-pool slice exposed authored writeback/save/parity claim metadata.")
		return false
	return true

func _fail(message: String) -> void:
	push_error("%s failed: %s" % [REPORT_ID, message])
	get_tree().quit(1)
