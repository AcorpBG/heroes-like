extends Node

const MapViewScript = preload("res://scenes/overworld/OverworldMapView.gd")
const BattleRulesScript = preload("res://scripts/core/BattleRules.gd")
const BattleAutoResolveRulesScript = preload("res://scripts/core/BattleAutoResolveRules.gd")
const SessionStateStoreScript = preload("res://scripts/core/SessionStateStore.gd")

const REPORT_ID := "SIX_FACTION_DISSIDENT_FRONTS_REPORT"
const OUTPUT_DIR := "res://.artifacts/six_faction_dissident_fronts_report"
const ATLAS_PATH := "res://art/overworld/runtime/objects/encounters/dissident_fronts/dissident_fronts_atlas.png"
const CASES := [
	{"scenario_id": "causeway-stand", "placement_id": "causeway_lockflame_turncoats", "encounter_id": "encounter_lockflame_turncoats", "army_group_id": "army_lockflame_turncoats", "faction_id": "faction_embercourt", "rare_resource_id": "embergrain", "victory_flag": "lockflame_turncoats_broken", "objective_id": "lockflame_broken_sluice", "asset_id": "encounter_dissident_lockflame_turncoats", "region": Rect2(0, 0, 48, 48), "combat_seed": 2204},
	{"scenario_id": "bogbound-oath", "placement_id": "bogbound_mossglass_moonhunt", "encounter_id": "encounter_mossglass_moonhunt", "army_group_id": "army_mossglass_moonhunt", "faction_id": "faction_mireclaw", "rare_resource_id": "peatwax", "victory_flag": "mossglass_moonhunt_broken", "objective_id": "moonhunt_scent_gate", "asset_id": "encounter_dissident_mossglass_moonhunt", "region": Rect2(48, 0, 48, 48), "combat_seed": 7204},
	{"scenario_id": "prismhearth-watch", "placement_id": "prismhearth_parallax_choir", "encounter_id": "encounter_parallax_choir", "army_group_id": "army_parallax_choir", "faction_id": "faction_sunvault", "rare_resource_id": "aetherglass", "victory_flag": "parallax_choir_broken", "objective_id": "parallax_chime_frame", "asset_id": "encounter_dissident_parallax_choir", "region": Rect2(96, 0, 48, 48), "combat_seed": 11204},
	{"scenario_id": "mireford-skirmish", "placement_id": "mireford_graftbound_pilgrims", "encounter_id": "encounter_graftbound_pilgrims", "army_group_id": "army_graftbound_pilgrims", "faction_id": "faction_thornwake", "rare_resource_id": "verdant_grafts", "victory_flag": "graftbound_pilgrims_broken", "objective_id": "graftbound_walking_arch", "asset_id": "encounter_dissident_graftbound_pilgrims", "region": Rect2(144, 0, 48, 48), "combat_seed": 10204},
	{"scenario_id": "orevein-contract", "placement_id": "orevein_redline_foreclosure", "encounter_id": "encounter_redline_foreclosure", "army_group_id": "army_redline_foreclosure", "faction_id": "faction_brasshollow", "rare_resource_id": "brass_scrip", "victory_flag": "redline_foreclosure_broken", "objective_id": "redline_seizure_gauge", "asset_id": "encounter_dissident_redline_foreclosure", "region": Rect2(192, 0, 48, 48), "combat_seed": 17204},
	{"scenario_id": "bellwake-wreck-claim", "placement_id": "bellwake_drowned_bell_procession", "encounter_id": "encounter_drowned_bell_procession", "army_group_id": "army_drowned_bell_procession", "faction_id": "faction_veilmourn", "rare_resource_id": "memory_salt", "victory_flag": "drowned_bell_procession_broken", "objective_id": "drowned_procession_bell", "asset_id": "encounter_dissident_drowned_bell_procession", "region": Rect2(240, 0, 48, 48), "combat_seed": 18204},
]

var _errors: Array[String] = []
var _rows: Array = []

func _ready() -> void:
	call_deferred("_run")

func _run() -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUTPUT_DIR))
	var view = MapViewScript.new()
	view.size = Vector2(1280, 720)
	add_child(view)
	await get_tree().process_frame
	for case_value in CASES:
		await _validate_case(view, case_value)
	var report := {
		"ok": _errors.is_empty(),
		"case_count": CASES.size(),
		"atlas_path": ATLAS_PATH,
		"atlas_size": [288, 48],
		"save_version": SessionStateStoreScript.SAVE_VERSION,
		"rows": _rows,
		"errors": _errors,
	}
	_write_json("%s/report.json" % OUTPUT_DIR, report)
	if _errors.is_empty():
		print("%s %s" % [REPORT_ID, JSON.stringify({"ok": true, "case_count": CASES.size(), "save_version": SessionStateStoreScript.SAVE_VERSION})])
	view.queue_free()
	await get_tree().process_frame
	get_tree().quit(0 if _errors.is_empty() else 1)

func _validate_case(view: Control, case: Dictionary) -> void:
	var scenario_id := String(case.get("scenario_id", ""))
	var placement_id := String(case.get("placement_id", ""))
	var encounter_id := String(case.get("encounter_id", ""))
	var session = ScenarioFactory.create_session(scenario_id, "normal", SessionState.LAUNCH_MODE_SKIRMISH)
	var encounter := _encounter(session, placement_id)
	if encounter.is_empty():
		_error("%s is missing live placement %s." % [scenario_id, placement_id])
		return
	_expect(String(encounter.get("encounter_id", "")) == encounter_id, "%s resolves the wrong encounter definition." % placement_id)
	_expect(Vector2i(int(encounter.get("x", -1)), int(encounter.get("y", -1))) == Vector2i(2, 4), "%s moved from its selected optional route tile." % placement_id)
	_expect(int(encounter.get("combat_seed", 0)) == int(case.get("combat_seed", -1)), "%s combat seed changed." % placement_id)

	var definition := ContentService.get_encounter(encounter_id)
	var army_group := ContentService.get_army_group(String(case.get("army_group_id", "")))
	_expect(String(definition.get("enemy_group_id", "")) == String(case.get("army_group_id", "")), "%s lost its exact army-group owner." % encounter_id)
	_expect(String(army_group.get("faction_id", "")) == String(case.get("faction_id", "")), "%s lost its faction alignment." % encounter_id)
	var objectives: Array = definition.get("field_objectives", []) if definition.get("field_objectives", []) is Array else []
	_expect(objectives.size() == 1 and String(objectives[0].get("id", "")) == String(case.get("objective_id", "")), "%s lost its exact tactical objective." % encounter_id)
	var rewards: Dictionary = definition.get("rewards", {}) if definition.get("rewards", {}) is Dictionary else {}
	_expect(int(rewards.get("gold", 0)) == 190 and int(rewards.get(String(case.get("rare_resource_id", "")), 0)) == 1 and int(rewards.get("experience", 0)) == 200, "%s reward contract changed." % encounter_id)

	var tile := Vector2i(int(encounter.get("x", -1)), int(encounter.get("y", -1)))
	view.set_map_state(session, session.overworld.get("map", []), OverworldRules.derive_map_size(session), tile)
	await get_tree().process_frame
	var identity: Dictionary = view.call("validation_encounter_presentation_payload", encounter)
	var texture = view.call("_object_texture_for_asset", String(case.get("asset_id", "")))
	var exact_art: bool = String(identity.get("identity_encounter_asset_id", "")) == String(case.get("asset_id", "")) \
		and bool(identity.get("uses_identity_encounter_sprite", false)) \
		and not bool(identity.get("uses_commander_sprite", true)) \
		and texture is AtlasTexture \
		and texture.region == case.get("region", Rect2()) \
		and texture.atlas is Texture2D \
		and texture.atlas.resource_path == ATLAS_PATH \
		and texture.atlas.get_size() == Vector2(288, 48)
	_expect(exact_art, "%s exact landmark did not reach the live map renderer." % encounter_id)

	var first := _clone_session(session)
	var second := _clone_session(session)
	var resources_before := _resource_snapshot(first)
	var battle := BattleRulesScript.create_battle_payload(first, _encounter(first, placement_id))
	var mirrored_battle := BattleRulesScript.create_battle_payload(second, _encounter(second, placement_id))
	_expect(not battle.is_empty() and not mirrored_battle.is_empty(), "%s did not construct a production battle payload." % encounter_id)
	if battle.is_empty() or mirrored_battle.is_empty():
		return
	_expect(String(battle.get("encounter_id", "")) == encounter_id and int(battle.get("combat_seed", 0)) == int(case.get("combat_seed", -1)), "%s battle identity or seed changed." % encounter_id)
	_expect(_enemy_counts(battle) == _army_counts(army_group), "%s battle stacks do not match the authored army group." % encounter_id)
	var battle_objectives: Array = battle.get("field_objectives", []) if battle.get("field_objectives", []) is Array else []
	_expect(battle_objectives.size() == 1 and String(battle_objectives[0].get("id", "")) == String(case.get("objective_id", "")), "%s battle did not adopt its objective." % encounter_id)
	first.battle = battle
	second.battle = mirrored_battle
	first.game_state = "battle"
	second.game_state = "battle"
	first.battle[BattleRulesScript.PRESENTATION_SPEED_KEY] = BattleRulesScript.PRESENTATION_SPEED_INSTANT
	second.battle[BattleRulesScript.PRESENTATION_SPEED_KEY] = BattleRulesScript.PRESENTATION_SPEED_INSTANT
	var first_result: Dictionary = BattleAutoResolveRulesScript.resolve_active_battle(first)
	var second_result: Dictionary = BattleAutoResolveRulesScript.resolve_active_battle(second)
	var deterministic := first_result == second_result and JSON.stringify(first.to_dict()) == JSON.stringify(second.to_dict())
	_expect(bool(first_result.get("ok", false)) and bool(first_result.get("completed", false)) and String(first_result.get("state", "")) == "victory", "%s did not resolve as a viable optional medium front: %s" % [encounter_id, first_result])
	_expect(deterministic, "%s produced non-deterministic resolution from its fixed combat seed." % encounter_id)
	if String(first_result.get("state", "")) != "victory":
		return
	var resources_after := _resource_snapshot(first)
	var rare_id := String(case.get("rare_resource_id", ""))
	var gold_delta := int(resources_after.get("gold", 0)) - int(resources_before.get("gold", 0))
	var rare_delta := int(resources_after.get(rare_id, 0)) - int(resources_before.get(rare_id, 0))
	_expect(gold_delta == 190, "%s gold reward changed: delta=%d before=%s after=%s terminal=%s." % [encounter_id, gold_delta, resources_before, resources_after, first_result.get("terminal_result", {})])
	_expect(rare_delta == 1, "%s rare-resource reward changed: %s delta=%d before=%s after=%s terminal=%s." % [encounter_id, rare_id, rare_delta, resources_before, resources_after, first_result.get("terminal_result", {})])
	_expect(placement_id in first.overworld.get("resolved_encounters", []), "%s did not persist its resolved placement." % encounter_id)
	_expect(bool(first.flags.get(String(case.get("victory_flag", "")), false)), "%s did not apply its victory flag." % encounter_id)
	var restored := _clone_session(first)
	_expect(int(restored.save_version) == SessionStateStoreScript.SAVE_VERSION and restored.to_dict() == first.to_dict(), "%s did not round-trip through save version %d." % [encounter_id, SessionStateStoreScript.SAVE_VERSION])
	_rows.append({
		"scenario_id": scenario_id,
		"placement_id": placement_id,
		"encounter_id": encounter_id,
		"asset_id": String(case.get("asset_id", "")),
		"army_group_id": String(case.get("army_group_id", "")),
		"field_objective_id": String(case.get("objective_id", "")),
		"rare_resource_id": rare_id,
		"gold_delta": gold_delta,
		"rare_resource_delta": rare_delta,
		"resolution_steps": int(first_result.get("steps", 0)),
		"deterministic": deterministic,
		"save_round_trip_exact": restored.to_dict() == first.to_dict(),
	})

func _encounter(session: SessionStateStoreScript.SessionData, placement_id: String) -> Dictionary:
	for value in session.overworld.get("encounters", []):
		if value is Dictionary and String(value.get("placement_id", "")) == placement_id:
			return value
	return {}

func _clone_session(source: SessionStateStoreScript.SessionData) -> SessionStateStoreScript.SessionData:
	var clone := SessionStateStoreScript.SessionData.new()
	clone.from_dict(source.to_dict())
	return clone

func _resource_snapshot(session: SessionStateStoreScript.SessionData) -> Dictionary:
	var resources: Dictionary = session.overworld.get("resources", {}) if session.overworld.get("resources", {}) is Dictionary else {}
	return resources.duplicate(true)

func _army_counts(army: Dictionary) -> Dictionary:
	var counts := {}
	for stack in army.get("stacks", []):
		if stack is Dictionary:
			counts[String(stack.get("unit_id", ""))] = int(stack.get("count", 0))
	return counts

func _enemy_counts(battle: Dictionary) -> Dictionary:
	var counts := {}
	for stack in battle.get("stacks", []):
		if not (stack is Dictionary) or String(stack.get("side", "")) != "enemy":
			continue
		var unit_hp: int = max(1, int(stack.get("unit_hp", 1)))
		counts[String(stack.get("unit_id", ""))] = int(ceil(float(max(0, int(stack.get("total_health", 0)))) / float(unit_hp)))
	return counts

func _expect(condition: bool, message: String) -> void:
	if not condition:
		_error(message)

func _error(message: String) -> void:
	_errors.append(message)
	push_error(message)

func _write_json(path: String, payload: Dictionary) -> void:
	var file := FileAccess.open(path, FileAccess.WRITE)
	if file == null:
		_error("Unable to write report %s." % path)
		return
	file.store_string(JSON.stringify(payload, "  "))
