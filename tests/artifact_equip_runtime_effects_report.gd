extends Node

const REPORT_ID := "ARTIFACT_EQUIP_RUNTIME_EFFECTS_REPORT"
const SCENARIO_ID := "river-pass"
const DIFFICULTY_ID := "normal"

func _ready() -> void:
	call_deferred("_run")

func _run() -> void:
	var base_hero := _fixture_hero({})
	var hero := _fixture_hero(
		{
			"equipped": {},
			"inventory": [
				"artifact_trailsinger_boots",
				"artifact_quarry_tally_rod",
				"artifact_warcrest_pennon",
				"artifact_bastion_gorget",
			],
		}
	)
	var initial_actions := ArtifactRules.get_management_actions(hero)
	for artifact_id in [
		"artifact_trailsinger_boots",
		"artifact_quarry_tally_rod",
		"artifact_warcrest_pennon",
		"artifact_bastion_gorget",
	]:
		var equip_result := ArtifactRules.equip_artifact(hero, artifact_id)
		if not bool(equip_result.get("ok", false)):
			_fail("Could not equip %s through ArtifactRules: %s" % [artifact_id, equip_result])
			return
		hero = equip_result.get("hero", hero)

	var runtime_report := ArtifactRules.artifact_equip_runtime_report(hero)
	if not bool(runtime_report.get("ok", false)):
		_fail("Artifact runtime report failed: %s" % runtime_report)
		return
	var live_contexts: Dictionary = runtime_report.get("live_contexts", {}) if runtime_report.get("live_contexts", {}) is Dictionary else {}
	for context_key in [
		"equipment_management",
		"adventure_movement",
		"adventure_scouting",
		"battle_command",
		"daily_common_income",
		"spell_modifiers",
	]:
		if not bool(live_contexts.get(context_key, false)):
			_fail("Artifact runtime report did not mark %s live: %s" % [context_key, runtime_report])
			return
	var aggregate: Dictionary = runtime_report.get("aggregate_bonuses", {}) if runtime_report.get("aggregate_bonuses", {}) is Dictionary else {}
	if int(aggregate.get("overworld_movement", 0)) != 2 or int(aggregate.get("scouting_radius", 0)) != 1:
		_fail("Artifact runtime report did not aggregate adventure bonuses: %s" % runtime_report)
		return
	if int(aggregate.get("battle_attack", 0)) != 1 or int(aggregate.get("battle_defense", 0)) != 2 or int(aggregate.get("battle_initiative", 0)) != 1:
		_fail("Artifact runtime report did not aggregate battle command bonuses: %s" % runtime_report)
		return
	var income: Dictionary = aggregate.get("daily_common_income", {}) if aggregate.get("daily_common_income", {}) is Dictionary else {}
	if int(income.get("gold", 0)) != 120 or int(income.get("ore", 0)) != 1:
		_fail("Artifact runtime report did not aggregate common daily income: %s" % runtime_report)
		return
	if int(aggregate.get("spell_modifier_count", 0)) != 1:
		_fail("Artifact runtime report did not aggregate spell modifiers: %s" % runtime_report)
		return
	var slot_surface: Dictionary = runtime_report.get("slot_surface", {}) if runtime_report.get("slot_surface", {}) is Dictionary else {}
	if int(slot_surface.get("active_trinket_slots", 0)) != 1 or bool(slot_surface.get("second_trinket_slot_live", true)):
		_fail("Artifact runtime report did not truthfully expose the current trinket slot boundary: %s" % runtime_report)
		return

	var base_movement := HeroCommandRules.movement_max_for_hero(base_hero, DIFFICULTY_ID)
	var artifact_movement := HeroCommandRules.movement_max_for_hero(hero, DIFFICULTY_ID)
	if artifact_movement - base_movement != 2:
		_fail("Equipped artifact movement bonus did not affect HeroCommandRules: base=%d artifact=%d" % [base_movement, artifact_movement])
		return
	var base_scout := HeroCommandRules.scouting_radius_for_hero(base_hero)
	var artifact_scout := HeroCommandRules.scouting_radius_for_hero(hero)
	if artifact_scout - base_scout != 1:
		_fail("Equipped artifact scouting bonus did not affect HeroCommandRules: base=%d artifact=%d" % [base_scout, artifact_scout])
		return

	var battle_payload := BattleRules._hero_payload_from_state(hero, ArtifactRules.aggregate_bonuses(hero), null, "player")
	if int(battle_payload.get("attack", 0)) != 3 or int(battle_payload.get("defense", 0)) != 3 or int(battle_payload.get("initiative", 0)) != 1:
		_fail("Equipped artifact battle bonuses did not affect BattleRules hero payload: %s" % battle_payload)
		return

	var base_session: Variant = _session_with_hero(base_hero)
	var artifact_session: Variant = _session_with_hero(hero)
	var base_before := _resources(base_session)
	var artifact_before := _resources(artifact_session)
	var base_turn := OverworldRules.end_turn(base_session)
	var artifact_turn := OverworldRules.end_turn(artifact_session)
	if not bool(base_turn.get("ok", false)) or not bool(artifact_turn.get("ok", false)):
		_fail("Could not run economy end-turn comparison: base=%s artifact=%s" % [base_turn, artifact_turn])
		return
	var base_delta := _resource_delta(base_before, _resources(base_session))
	var artifact_delta := _resource_delta(artifact_before, _resources(artifact_session))
	if int(artifact_delta.get("gold", 0)) - int(base_delta.get("gold", 0)) != 120 or int(artifact_delta.get("ore", 0)) - int(base_delta.get("ore", 0)) != 1:
		_fail("Equipped artifact income did not affect OverworldRules end turn: base=%s artifact=%s" % [base_delta, artifact_delta])
		return

	var trailglyph := ContentService.get_spell("spell_trailglyph")
	var movement_state := {"current": 1, "max": 10}
	var base_preview := SpellRules.adventure_spell_consequence_preview(base_hero, movement_state, trailglyph)
	var artifact_preview := SpellRules.adventure_spell_consequence_preview(hero, movement_state, trailglyph)
	if int(base_preview.get("mana_cost", 0)) - int(artifact_preview.get("mana_cost", 0)) != 1:
		_fail("Equipped artifact spell modifier did not reduce mana cost: base=%s artifact=%s" % [base_preview, artifact_preview])
		return
	if int(artifact_preview.get("movement_after", 0)) - int(base_preview.get("movement_after", 0)) != 1:
		_fail("Equipped artifact spell modifier did not improve movement preview: base=%s artifact=%s" % [base_preview, artifact_preview])
		return

	if not _assert_public_payload("artifact runtime report", runtime_report):
		return
	if not _assert_public_payload("battle payload", battle_payload):
		return

	var payload := {
		"ok": true,
		"report_id": REPORT_ID,
		"schema_status": String(runtime_report.get("schema_status", "")),
		"equipped_slot_count": int(runtime_report.get("equipped_slot_count", 0)),
		"initial_management_action_count": initial_actions.size(),
		"management_action_count": int(runtime_report.get("management_action_count", 0)),
		"live_contexts": live_contexts,
		"aggregate_bonuses": aggregate,
		"runtime_checks": {
			"movement_delta": artifact_movement - base_movement,
			"scouting_delta": artifact_scout - base_scout,
			"battle_attack": int(battle_payload.get("attack", 0)),
			"battle_defense": int(battle_payload.get("defense", 0)),
			"battle_initiative": int(battle_payload.get("initiative", 0)),
			"income_delta": {
				"gold": int(artifact_delta.get("gold", 0)) - int(base_delta.get("gold", 0)),
				"ore": int(artifact_delta.get("ore", 0)) - int(base_delta.get("ore", 0)),
			},
			"trailglyph_mana_delta": int(base_preview.get("mana_cost", 0)) - int(artifact_preview.get("mana_cost", 0)),
			"trailglyph_movement_delta": int(artifact_preview.get("movement_after", 0)) - int(base_preview.get("movement_after", 0)),
		},
		"slot_surface": slot_surface,
		"runtime_policy": runtime_report.get("runtime_policy", {}),
		"caveats": [
			"This report proves equipped artifact effects on current equipment management, adventure, battle, economy, and spell hooks only; set bonuses, source reward execution, save migration, AI valuation, rare-resource activation, and broad UI overhaul remain outside this slice.",
		],
	}
	print("%s %s" % [REPORT_ID, JSON.stringify(payload)])
	get_tree().quit(0)

func _fixture_hero(artifacts: Dictionary) -> Dictionary:
	return SpellRules.ensure_hero_spellbook(
		{
			"id": "artifact_runtime_fixture_hero",
			"name": "Runtime Fixture Hero",
			"level": 1,
			"base_movement": 10,
			"command": {"attack": 2, "defense": 1, "power": 1, "knowledge": 8},
			"spellbook": {
				"known_spell_ids": ["spell_trailglyph"],
				"mana": {"current": 10, "max": 40},
			},
			"artifacts": ArtifactRules.normalize_hero_artifacts(artifacts),
			"specialties": [],
		}
	)

func _session_with_hero(hero: Dictionary):
	var session = ScenarioFactory.create_session(
		SCENARIO_ID,
		DIFFICULTY_ID,
		SessionState.LAUNCH_MODE_SKIRMISH
	)
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
	for key in ["gold", "wood", "ore"]:
		delta[key] = int(after.get(key, 0)) - int(before.get(key, 0))
	return delta

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
