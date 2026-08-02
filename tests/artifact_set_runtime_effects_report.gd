extends Node

const REPORT_ID := "ARTIFACT_SET_RUNTIME_EFFECTS_REPORT"
const SET_PIECES := [
	"artifact_trailsinger_boots",
	"artifact_waymark_compass",
	"artifact_milepost_lantern",
]

func _ready() -> void:
	call_deferred("_run")

func _run() -> void:
	var old_payload := ArtifactRules.normalize_hero_artifacts({
		"equipped": {"trinket": "artifact_waymark_compass"},
		"inventory": [],
	})
	if String(old_payload.get("equipped", {}).get("trinket", "")) != "artifact_waymark_compass" \
			or not old_payload.get("equipped", {}).has("trinket_2") \
			or String(old_payload.get("equipped", {}).get("trinket_2", "")) != "":
		_fail("Old one-trinket payload did not normalize into the additive dual-slot shape: %s" % old_payload)
		return

	var base_hero := _fixture_hero()
	var hero := base_hero.duplicate(true)
	var claim_slots := []
	for artifact_id in SET_PIECES:
		var claim := ArtifactRules.claim_artifact(hero, artifact_id, "Recovered", true)
		if not bool(claim.get("ok", false)) or not bool(claim.get("auto_equipped", false)):
			_fail("Set piece did not auto-equip into an empty compatible slot: %s" % claim)
			return
		hero = claim.get("hero", hero)
		claim_slots.append(String(claim.get("slot", "")))

	var equipped: Dictionary = hero.get("artifacts", {}).get("equipped", {})
	if claim_slots != ["boots", "trinket", "trinket_2"] \
			or String(equipped.get("boots", "")) != SET_PIECES[0] \
			or String(equipped.get("trinket", "")) != SET_PIECES[1] \
			or String(equipped.get("trinket_2", "")) != SET_PIECES[2]:
		_fail("Auto-equip did not fill both trinket slots without replacing a set piece: slots=%s equipped=%s" % [claim_slots, equipped])
		return

	var bonuses := ArtifactRules.aggregate_bonuses(hero)
	if int(bonuses.get("overworld_movement", 0)) != 4 or int(bonuses.get("scouting_radius", 0)) != 5:
		_fail("Full Wayfarer Compact did not apply both cumulative thresholds: %s" % bonuses)
		return
	var active_sets: Array = bonuses.get("active_sets", []) if bonuses.get("active_sets", []) is Array else []
	if active_sets.size() != 1:
		_fail("Full Wayfarer Compact did not expose one active set: %s" % active_sets)
		return
	var wayfarer: Dictionary = active_sets[0]
	if String(wayfarer.get("set_id", "")) != "set_wayfarer_compact" \
			or int(wayfarer.get("equipped_piece_count", 0)) != 3 \
			or wayfarer.get("active_thresholds", []).size() != 2 \
			or not bool(wayfarer.get("complete", false)):
		_fail("Wayfarer active-set state was incomplete: %s" % wayfarer)
		return

	var base_movement := HeroCommandRules.movement_max_for_hero(base_hero, "normal")
	var set_movement := HeroCommandRules.movement_max_for_hero(hero, "normal")
	var base_scouting := HeroCommandRules.scouting_radius_for_hero(base_hero)
	var set_scouting := HeroCommandRules.scouting_radius_for_hero(hero)
	if set_movement - base_movement != 4 or set_scouting - base_scouting != 5:
		_fail("Live movement/scouting hooks did not consume cumulative set bonuses: movement=%d scouting=%d" % [set_movement - base_movement, set_scouting - base_scouting])
		return

	var management := ArtifactRules.describe_management(hero)
	if not management.contains("Wayfarer Compact 3/3") \
			or not management.contains("2pc +1 move") \
			or not management.contains("3pc +1 scout"):
		_fail("Artifact management did not expose active set progress and bonuses: %s" % management)
		return

	var session = SessionStateStore.new_session_data(
		"artifact_set_runtime_save",
		"river-pass",
		String(hero.get("id", "")),
		7,
		{"hero": hero, "player_heroes": [hero], "active_hero_id": String(hero.get("id", ""))},
		"normal",
		SessionStateStore.LAUNCH_MODE_SKIRMISH
	)
	var encoded := JSON.stringify(session.to_dict())
	var parsed = JSON.parse_string(encoded)
	if not (parsed is Dictionary):
		_fail("Session JSON round trip did not produce a dictionary payload.")
		return
	var restored = SessionStateStore.SessionData.new()
	restored.from_dict(parsed)
	var restored_hero: Dictionary = restored.overworld.get("hero", {}) if restored.overworld.get("hero", {}) is Dictionary else {}
	restored_hero["artifacts"] = ArtifactRules.normalize_hero_artifacts(restored_hero.get("artifacts", {}))
	var restored_equipped: Dictionary = restored_hero.get("artifacts", {}).get("equipped", {})
	var restored_bonuses := ArtifactRules.aggregate_bonuses(restored_hero)
	if restored.save_version != SessionStateStore.SAVE_VERSION \
			or String(restored_equipped.get("trinket", "")) != SET_PIECES[1] \
			or String(restored_equipped.get("trinket_2", "")) != SET_PIECES[2] \
			or int(restored_bonuses.get("overworld_movement", 0)) != 4 \
			or int(restored_bonuses.get("scouting_radius", 0)) != 5:
		_fail("Save/resume did not preserve dual trinkets and recomputed set bonuses: equipped=%s bonuses=%s" % [restored_equipped, restored_bonuses])
		return

	var claimed_extra := ArtifactRules.claim_artifact(restored_hero, "artifact_quarry_tally_rod", "Recovered", false)
	var swap_result := ArtifactRules.equip_artifact(claimed_extra.get("hero", restored_hero), "artifact_quarry_tally_rod")
	if not bool(swap_result.get("ok", false)) \
			or String(swap_result.get("slot", "")) != "trinket" \
			or String(swap_result.get("swapped_out_artifact_id", "")) != SET_PIECES[1] \
			or String(swap_result.get("hero", {}).get("artifacts", {}).get("equipped", {}).get("trinket_2", "")) != SET_PIECES[2]:
		_fail("A third trinket did not deterministically replace the primary slot while preserving Trinket II: %s" % swap_result)
		return

	print("%s %s" % [REPORT_ID, JSON.stringify({
		"ok": true,
		"claim_slots": claim_slots,
		"active_trinket_slots": 2,
		"active_threshold_count": wayfarer.get("active_thresholds", []).size(),
		"movement_delta": set_movement - base_movement,
		"scouting_delta": set_scouting - base_scouting,
		"save_version": restored.save_version,
		"save_resume_bonuses": {
			"overworld_movement": int(restored_bonuses.get("overworld_movement", 0)),
			"scouting_radius": int(restored_bonuses.get("scouting_radius", 0)),
		},
		"full_set_complete": bool(wayfarer.get("complete", false)),
		"swap_slot": String(swap_result.get("slot", "")),
	})])
	get_tree().quit(0)

func _fixture_hero() -> Dictionary:
	return {
		"id": "artifact_set_runtime_hero",
		"name": "Wayfarer",
		"level": 1,
		"base_movement": 10,
		"command": {"attack": 1, "defense": 1, "power": 1, "knowledge": 1},
		"artifacts": ArtifactRules.normalize_hero_artifacts({}),
		"specialties": [],
	}

func _fail(message: String) -> void:
	push_error("%s failed: %s" % [REPORT_ID, message])
	get_tree().quit(1)
