extends Node

const REPORT_ID := "NATIVE_RANDOM_MAP_HOMM3_GUARDS_REWARDS_MONSTERS_REPORT"
const EXPECTED_STRENGTH_TABLE := {
	"1500": [0, 0, 0, 0, 0, 2250],
	"3500": [0, 0, 0, 2500, 4500, 5250],
	"7000": [0, 2250, 4125, 6000, 11750, 13500],
}

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
	if not capabilities.has("native_random_map_homm3_guards_rewards_monsters"):
		_fail("Native guards/rewards/monsters capability is missing: %s" % JSON.stringify(Array(capabilities)))
		return

	var config := _config("native-rmg-homm3-guards-rewards-monsters-10184")
	var first: Dictionary = service.generate_random_map(config)
	var second: Dictionary = service.generate_random_map(config.duplicate(true))
	var changed_config := _config("native-rmg-homm3-guards-rewards-monsters-10184-changed")
	var changed: Dictionary = service.generate_random_map(changed_config)

	if not _assert_guard_reward_monster_shape(first):
		return
	if not _assert_guard_reward_monster_shape(second):
		return

	var first_summary: Dictionary = first.get("guard_reward_monster_summary", {})
	var second_summary: Dictionary = second.get("guard_reward_monster_summary", {})
	var changed_summary: Dictionary = changed.get("guard_reward_monster_summary", {})
	var signature := String(first_summary.get("signature", ""))
	if signature == "":
		_fail("Guard/reward/monster summary signature is empty.")
		return
	if signature != String(second_summary.get("signature", "")):
		_fail("Same seed/config did not preserve guard/reward/monster summary signature.")
		return
	if signature == String(changed_summary.get("signature", "")):
		_fail("Changed seed did not change guard/reward/monster summary signature.")
		return

	print("%s %s" % [REPORT_ID, JSON.stringify({
		"ok": true,
		"binding_kind": metadata.get("binding_kind", ""),
		"native_extension_loaded": metadata.get("native_extension_loaded", false),
		"status": first.get("status", ""),
		"summary_signature": signature,
		"changed_summary_signature": changed_summary.get("signature", ""),
		"guard_count": first_summary.get("guard_count", 0),
		"site_guard_count": first_summary.get("site_guard_count", 0),
		"match_to_town_guard_count": first_summary.get("match_to_town_guard_count", 0),
		"explicit_mask_guard_count": first_summary.get("explicit_mask_guard_count", 0),
		"reward_count": first.get("reward_band_summary", {}).get("reward_count", 0),
		"valid_reward_band_count": first.get("reward_band_summary", {}).get("valid_band_count", 0),
	})])
	get_tree().quit(0)

func _config(seed: String) -> Dictionary:
	return {
		"seed": seed,
		"monster_strength": "strong",
		"size": {
			"width": 72,
			"height": 72,
			"level_count": 1,
			"size_class_id": "homm3_medium",
			"water_mode": "land",
		},
		"player_constraints": {
			"human_count": 1,
			"computer_count": 2,
			"team_mode": "free_for_all",
		},
		"profile": {
			"id": "native_guard_reward_monster_source_semantics_profile",
			"template_id": "translated_rmg_template_005_v1",
			"terrain_ids": ["grass", "dirt", "rough", "snow", "underground"],
			"faction_ids": ["faction_embercourt", "faction_mireclaw", "faction_sunvault"],
		},
	}

func _assert_guard_reward_monster_shape(generated: Dictionary) -> bool:
	if not bool(generated.get("ok", false)):
		_fail("Native RMG returned ok=false: %s" % JSON.stringify(generated.get("report", {})))
		return false

	var summary: Dictionary = generated.get("guard_reward_monster_summary", {})
	if String(summary.get("schema_id", "")) != "aurelion_native_rmg_guards_rewards_monsters_v1":
		_fail("Guard/reward/monster summary schema mismatch: %s" % JSON.stringify(summary))
		return false
	if String(summary.get("phase_order", "")) != "phase_10_rewards_and_monsters_after_phase_7_mines_resources_before_decorative_filler":
		_fail("Guard/reward/monster phase order drifted: %s" % JSON.stringify(summary))
		return false
	if String(summary.get("validation_status", "")) != "pass":
		_fail("Guard/reward/monster validation failed: %s" % JSON.stringify(summary.get("failures", [])))
		return false
	for base in EXPECTED_STRENGTH_TABLE.keys():
		if Array(summary.get("strength_sample_table", {}).get(base, [])) != EXPECTED_STRENGTH_TABLE[base]:
			_fail("Recovered strength sample table mismatch for base %s: %s" % [base, JSON.stringify(summary.get("strength_sample_table", {}))])
			return false
	if int(summary.get("guard_count", 0)) <= 0 or int(summary.get("site_guard_count", 0)) <= 0:
		_fail("No materialized site guards were produced: %s" % JSON.stringify(summary))
		return false
	if int(summary.get("stack_record_count", 0)) < int(summary.get("guard_count", 0)):
		_fail("Every guard should have at least one original unit stack record: %s" % JSON.stringify(summary))
		return false
	if int(summary.get("stack_mask_mismatch_count", 0)) != 0:
		_fail("Monster stack selection ignored allowed faction masks: %s" % JSON.stringify(summary))
		return false

	var reward_summary: Dictionary = generated.get("reward_band_summary", {})
	if String(reward_summary.get("schema_id", "")) != "aurelion_native_rmg_phase10_reward_bands_summary_v1":
		_fail("Reward band summary schema mismatch: %s" % JSON.stringify(reward_summary))
		return false
	if String(reward_summary.get("phase_order", "")) != "phase_10_after_mines_resources_before_decorative_filler":
		_fail("Reward phase order drifted: %s" % JSON.stringify(reward_summary))
		return false
	if int(reward_summary.get("reward_count", 0)) <= 0 or int(reward_summary.get("valid_band_count", 0)) <= 0:
		_fail("Reward bands did not produce value-bearing rewards: %s" % JSON.stringify(reward_summary))
		return false
	if int(reward_summary.get("out_of_band_reward_count", 0)) != 0:
		_fail("Reward values escaped selected low/high bands: %s" % JSON.stringify(reward_summary))
		return false

	for guard in generated.get("guard_records", []):
		if not (guard is Dictionary):
			_fail("Invalid guard record.")
			return false
		if String(guard.get("monster_selection_source", "")) == "":
			_fail("Guard missed monster selection metadata: %s" % JSON.stringify(guard))
			return false
		var allowed := Array(guard.get("monster_allowed_faction_ids", []))
		if allowed.is_empty():
			_fail("Guard missed allowed faction mask: %s" % JSON.stringify(guard))
			return false
		for stack in guard.get("stack_records", []):
			if not (stack is Dictionary):
				_fail("Invalid guard stack record.")
				return false
			if String(stack.get("unit_id", "")) == "" or int(stack.get("count", 0)) <= 0:
				_fail("Guard stack missed original unit/count: %s" % JSON.stringify(stack))
				return false
			if not bool(stack.get("allowed_faction_mask_matched", false)):
				_fail("Guard stack did not match mask: %s" % JSON.stringify(stack))
				return false
	return true

func _fail(message: String) -> void:
	push_error("%s failed: %s" % [REPORT_ID, message])
	get_tree().quit(1)
