extends Node

const REPORT_ID := "ARTIFACT_SET_RUNTIME_EFFECTS_REPORT"
const SET_PIECES := [
	"artifact_trailsinger_boots",
	"artifact_waymark_compass",
	"artifact_milepost_lantern",
]
const FIELD_REGALIA_SCENARIOS := {
	"river-pass": {"placement_id": "warcrest_ruin", "artifact_id": "artifact_bridgefire_standard", "slot": "banner", "faction_id": "faction_embercourt", "bonuses": {"battle_attack": 1, "daily_income": {"gold": 50}}},
	"bogbound-oath": {"placement_id": "bogbound_boots", "artifact_id": "artifact_reedshadow_waders", "slot": "boots", "faction_id": "faction_mireclaw", "bonuses": {"overworld_movement": 1, "battle_initiative": 1}},
	"prismhearth-watch": {"placement_id": "spire_gorget", "artifact_id": "artifact_prismward_mantle", "slot": "armor", "faction_id": "faction_sunvault", "bonuses": {"battle_defense": 1, "battle_spell_resistance_pct": 6}},
	"mireford-skirmish": {"placement_id": "ford_gorget", "artifact_id": "artifact_graftbark_cuirass", "slot": "armor", "faction_id": "faction_thornwake", "bonuses": {"battle_defense": 1, "daily_income": {"wood": 1}}},
	"orevein-contract": {"placement_id": "orevein_bastion_gorget", "artifact_id": "artifact_quenchplate_vambrace", "slot": "armor", "faction_id": "faction_brasshollow", "bonuses": {"battle_defense": 1, "daily_income": {"ore": 1}}},
	"bellwake-wreck-claim": {"placement_id": "bellwake_trailsinger_boots", "artifact_id": "artifact_fogwake_deckboots", "slot": "boots", "faction_id": "faction_veilmourn", "bonuses": {"overworld_movement": 1, "scouting_radius": 1}},
}

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

	var asterfall_pieces := [
		"artifact_rainstar_sextant",
		"artifact_asterfall_mantle",
		"artifact_cometwake_pennon",
	]
	var asterfall_hero := _fixture_hero()
	var asterfall_slots := []
	for artifact_id in asterfall_pieces:
		var claim := ArtifactRules.claim_artifact(asterfall_hero, artifact_id, "Halo Refraction Survey", true)
		if not bool(claim.get("ok", false)) or not bool(claim.get("auto_equipped", false)):
			_fail("Asterfall Survey piece did not auto-equip: %s" % claim)
			return
		asterfall_hero = claim.get("hero", asterfall_hero)
		asterfall_slots.append(String(claim.get("slot", "")))
	var asterfall_bonuses := ArtifactRules.aggregate_bonuses(asterfall_hero)
	var asterfall_sets: Array = asterfall_bonuses.get("active_sets", []) if asterfall_bonuses.get("active_sets", []) is Array else []
	var asterfall_set := {}
	for active_set_value in asterfall_sets:
		if active_set_value is Dictionary and String(active_set_value.get("set_id", "")) == "set_asterfall_survey":
			asterfall_set = active_set_value
			break
	var asterfall_movement := HeroCommandRules.movement_max_for_hero(asterfall_hero, "normal") - base_movement
	var asterfall_scouting := HeroCommandRules.scouting_radius_for_hero(asterfall_hero) - base_scouting
	if asterfall_slots != ["trinket", "armor", "banner"] \
			or int(asterfall_bonuses.get("overworld_movement", 0)) != 2 \
			or int(asterfall_bonuses.get("scouting_radius", 0)) != 2 \
			or int(asterfall_bonuses.get("battle_attack", 0)) != 1 \
			or int(asterfall_bonuses.get("battle_defense", 0)) != 1 \
			or int(asterfall_bonuses.get("battle_initiative", 0)) != 3 \
			or asterfall_movement != 2 \
			or asterfall_scouting != 2 \
			or not bool(asterfall_set.get("complete", false)) \
			or asterfall_set.get("active_thresholds", []).size() != 2:
		_fail("Asterfall Survey did not apply its exact live cumulative effects: slots=%s bonuses=%s set=%s" % [asterfall_slots, asterfall_bonuses, asterfall_set])
		return
	var asterfall_session = SessionStateStore.new_session_data(
		"asterfall_set_runtime_save",
		"halo-reserve-refraction-claim",
		String(asterfall_hero.get("id", "")),
		7,
		{"hero": asterfall_hero, "player_heroes": [asterfall_hero], "active_hero_id": String(asterfall_hero.get("id", ""))},
		"normal",
		SessionStateStore.LAUNCH_MODE_SKIRMISH
	)
	var asterfall_restored = SessionStateStore.SessionData.new()
	asterfall_restored.from_dict(JSON.parse_string(JSON.stringify(asterfall_session.to_dict())))
	var restored_asterfall_hero: Dictionary = asterfall_restored.overworld.get("hero", {})
	var restored_asterfall_bonuses := ArtifactRules.aggregate_bonuses(restored_asterfall_hero)
	if asterfall_restored.save_version != SessionStateStore.SAVE_VERSION or restored_asterfall_bonuses != asterfall_bonuses:
		_fail("Asterfall Survey content references or cumulative effects changed across save/resume: %s" % restored_asterfall_bonuses)
		return

	var live_session = ScenarioFactory.create_session("halo-reserve-refraction-claim", "normal", SessionStateStore.LAUNCH_MODE_SKIRMISH)
	OverworldRules.normalize_overworld_state(live_session)
	var live_hero: Dictionary = live_session.overworld.get("hero", {})
	live_hero["artifacts"] = ArtifactRules.normalize_hero_artifacts({})
	live_session.overworld["hero"] = live_hero
	var live_heroes: Array = live_session.overworld.get("player_heroes", [])
	for live_hero_index in range(live_heroes.size()):
		if live_heroes[live_hero_index] is Dictionary and String(live_heroes[live_hero_index].get("id", "")) == String(live_session.overworld.get("active_hero_id", "")):
			live_heroes[live_hero_index] = live_hero.duplicate(true)
	live_session.overworld["player_heroes"] = live_heroes
	var live_placements := {
		"halo_rainstar_sextant": "artifact_rainstar_sextant",
		"halo_asterfall_mantle": "artifact_asterfall_mantle",
		"rootgate_cometwake_pennon": "artifact_cometwake_pennon",
	}
	for placement_id in live_placements:
		var node_result := _artifact_node_result(live_session, placement_id)
		var node: Dictionary = node_result.get("node", {})
		if int(node_result.get("index", -1)) < 0 or String(node.get("artifact_id", "")) != String(live_placements[placement_id]):
			_fail("Halo Refraction did not materialize the authored Asterfall placement %s: %s" % [placement_id, node])
			return
		var collect_result := OverworldRules._collect_artifact_node_result(live_session, node_result, false)
		var collected_node: Dictionary = _artifact_node_result(live_session, placement_id).get("node", {})
		if not bool(collect_result.get("ok", false)) or not bool(collected_node.get("collected", false)) or String(collected_node.get("collected_by_faction_id", "")) != "player":
			_fail("Halo Refraction Asterfall placement did not execute a one-time player collection: %s" % collect_result)
			return
	var live_owned := ArtifactRules.owned_artifact_ids(live_session.overworld.get("hero", {}))
	var live_bonuses := ArtifactRules.aggregate_bonuses(live_session.overworld.get("hero", {}))
	if not asterfall_pieces.all(func(artifact_id): return artifact_id in live_owned) \
			or int(live_bonuses.get("overworld_movement", 0)) != 2 \
			or int(live_bonuses.get("scouting_radius", 0)) != 2 \
			or int(live_bonuses.get("battle_initiative", 0)) != 3:
		_fail("Halo Refraction collections did not activate the complete Asterfall set: owned=%s bonuses=%s" % [live_owned, live_bonuses])
		return
	var restored_live_session = SessionStateStore.SessionData.new()
	restored_live_session.from_dict(JSON.parse_string(JSON.stringify(live_session.to_dict())))
	var restored_live_owned := ArtifactRules.owned_artifact_ids(restored_live_session.overworld.get("hero", {}))
	for placement_id in live_placements:
		if not bool(_artifact_node_result(restored_live_session, placement_id).get("node", {}).get("collected", false)):
			_fail("Halo Refraction Asterfall collection state was lost across save/resume at %s." % placement_id)
			return
	if restored_live_session.save_version != SessionStateStore.SAVE_VERSION or not asterfall_pieces.all(func(artifact_id): return artifact_id in restored_live_owned):
		_fail("Halo Refraction Asterfall ownership was lost across save/resume: %s" % restored_live_owned)
		return

	var field_regalia_rows := _validate_field_regalia_scenarios()
	if field_regalia_rows.size() != FIELD_REGALIA_SCENARIOS.size() or not field_regalia_rows.all(func(row): return bool(row.get("ok", false))):
		_fail("Faction field regalia did not materialize, collect, auto-equip, apply, and persist exactly: %s" % [field_regalia_rows])
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
		"asterfall_slots": asterfall_slots,
		"asterfall_movement_delta": asterfall_movement,
		"asterfall_scouting_delta": asterfall_scouting,
		"asterfall_battle_bonuses": {
			"attack": int(asterfall_bonuses.get("battle_attack", 0)),
			"defense": int(asterfall_bonuses.get("battle_defense", 0)),
			"initiative": int(asterfall_bonuses.get("battle_initiative", 0)),
		},
		"asterfall_full_set_complete": bool(asterfall_set.get("complete", false)),
		"asterfall_live_scenario": {
			"scenario_id": "halo-reserve-refraction-claim",
			"placement_count": live_placements.size(),
			"collections_persisted": true,
		},
		"field_regalia_scenarios": field_regalia_rows,
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

func _artifact_node_result(session, placement_id: String) -> Dictionary:
	var nodes: Array = session.overworld.get("artifact_nodes", []) if session.overworld.get("artifact_nodes", []) is Array else []
	for index in range(nodes.size()):
		var node = nodes[index]
		if node is Dictionary and String(node.get("placement_id", "")) == placement_id:
			return {"index": index, "node": node}
	return {"index": -1, "node": {}}

func _validate_field_regalia_scenarios() -> Array:
	var rows: Array = []
	for scenario_id in FIELD_REGALIA_SCENARIOS:
		var spec: Dictionary = FIELD_REGALIA_SCENARIOS[scenario_id]
		var session = ScenarioFactory.create_session(scenario_id, "normal", SessionStateStore.LAUNCH_MODE_SKIRMISH)
		OverworldRules.normalize_overworld_state(session)
		var hero: Dictionary = session.overworld.get("hero", {}) if session.overworld.get("hero", {}) is Dictionary else {}
		hero["artifacts"] = ArtifactRules.normalize_hero_artifacts({})
		session.overworld["hero"] = hero
		var active_hero_id := String(session.overworld.get("active_hero_id", hero.get("id", "")))
		var heroes: Array = session.overworld.get("player_heroes", []) if session.overworld.get("player_heroes", []) is Array else []
		for hero_index in range(heroes.size()):
			if heroes[hero_index] is Dictionary and String(heroes[hero_index].get("id", "")) == active_hero_id:
				heroes[hero_index] = hero.duplicate(true)
				break
		session.overworld["player_heroes"] = heroes

		var artifact_id := String(spec.get("artifact_id", ""))
		var placement_id := String(spec.get("placement_id", ""))
		var slot := String(spec.get("slot", ""))
		var scenario := ContentService.get_scenario(scenario_id)
		var artifact := ContentService.get_artifact(artifact_id)
		var node_result := _artifact_node_result(session, placement_id)
		var node: Dictionary = node_result.get("node", {}) if node_result.get("node", {}) is Dictionary else {}
		var authored_exact: bool = String(scenario.get("player_faction_id", "")) == String(spec.get("faction_id", "")) \
			and String(artifact.get("slot", "")) == slot \
			and artifact.get("faction_affinity", []) == [String(spec.get("faction_id", ""))] \
			and int(node_result.get("index", -1)) >= 0 \
			and String(node.get("artifact_id", "")) == artifact_id \
			and not bool(node.get("collected", true))
		var collect_result := OverworldRules._collect_artifact_node_result(session, node_result, false) if authored_exact else {}
		var collected_node: Dictionary = _artifact_node_result(session, placement_id).get("node", {})
		var collected_hero: Dictionary = session.overworld.get("hero", {})
		var equipped: Dictionary = collected_hero.get("artifacts", {}).get("equipped", {})
		var bonuses := ArtifactRules.aggregate_bonuses(collected_hero)
		var runtime_exact := bool(collect_result.get("ok", false)) \
			and bool(collected_node.get("collected", false)) \
			and String(collected_node.get("collected_by_faction_id", "")) == "player" \
			and String(equipped.get(slot, "")) == artifact_id \
			and _bonuses_include_exact(bonuses, spec.get("bonuses", {}))

		var restored = SessionStateStore.SessionData.new()
		restored.from_dict(JSON.parse_string(JSON.stringify(session.to_dict())))
		var restored_hero: Dictionary = restored.overworld.get("hero", {})
		var restored_equipped: Dictionary = restored_hero.get("artifacts", {}).get("equipped", {})
		var restored_node: Dictionary = _artifact_node_result(restored, placement_id).get("node", {})
		var save_exact: bool = restored.save_version == SessionStateStore.SAVE_VERSION \
			and String(restored_equipped.get(slot, "")) == artifact_id \
			and bool(restored_node.get("collected", false)) \
			and String(restored_node.get("collected_by_faction_id", "")) == "player" \
			and _bonuses_include_exact(ArtifactRules.aggregate_bonuses(restored_hero), spec.get("bonuses", {}))
		rows.append({
			"ok": authored_exact and runtime_exact and save_exact,
			"scenario_id": scenario_id,
			"placement_id": placement_id,
			"artifact_id": artifact_id,
			"slot": slot,
			"authored_exact": authored_exact,
			"runtime_exact": runtime_exact,
			"save_exact": save_exact,
			"save_version": restored.save_version,
		})
	return rows

func _bonuses_include_exact(actual_value: Variant, expected_value: Variant) -> bool:
	if not (actual_value is Dictionary) or not (expected_value is Dictionary):
		return false
	var actual: Dictionary = actual_value
	var expected: Dictionary = expected_value
	for key in expected:
		var expected_entry = expected[key]
		var actual_entry = actual.get(key)
		if expected_entry is Dictionary:
			if not _bonuses_include_exact(actual_entry, expected_entry):
				return false
		elif int(actual_entry) != int(expected_entry):
			return false
	return true

func _fail(message: String) -> void:
	push_error("%s failed: %s" % [REPORT_ID, message])
	get_tree().quit(1)
