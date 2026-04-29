extends Node

const BalanceRegressionReportRulesScript = preload("res://scripts/core/BalanceRegressionReportRules.gd")
const ScenarioFactoryScript = preload("res://scripts/core/ScenarioFactory.gd")
const SessionStateStoreScript = preload("res://scripts/core/SessionStateStore.gd")

const REPORT_ID := "FACTION_CONTENT_BREADTH_REPORT"
const SCENARIO_ID := "ninefold-confluence"
const FORBIDDEN_CLAIM_TOKENS := [
	"alpha_or_parity_claim\":true",
	"parity_complete",
	"alpha_complete",
	"production_ready",
]
const FOCUS := [
	{
		"faction_id": "faction_thornwake",
		"primary_town_id": "town_thornwake_graftroot_caravan",
		"secondary_town_id": "town_thornwake_rootgate_nursery",
		"hero_id": "hero_thornwake_ardren_briarmarshal",
		"unit_ids": ["unit_thornwake_seedcutters", "unit_thornwake_sporeglass_menders"],
		"spell_ids": ["spell_briar_bind", "spell_graft_mend"],
		"artifact_id": "artifact_living_bridge_knot",
		"live_resource_id": "wood",
		"scenario_town_placement_id": "ninefold_graftroot_caravan",
		"priority_site_ids": ["dwelling_bramble_hedge", "dwelling_greenbranch_copse"],
		"neutral_dwelling_ids": ["neutral_dwelling_bramble_hedge", "neutral_dwelling_greenbranch_copse"],
	},
	{
		"faction_id": "faction_brasshollow",
		"primary_town_id": "town_brasshollow_orevein_gantry",
		"secondary_town_id": "town_brasshollow_clauseworks_depot",
		"hero_id": "hero_brasshollow_marka_ironclause",
		"unit_ids": ["unit_brasshollow_rivet_hounds", "unit_brasshollow_furnace_pavis_teams"],
		"spell_ids": ["spell_heat_rite", "spell_pressure_clause"],
		"artifact_id": "artifact_pressure_gauge_reliquary",
		"live_resource_id": "ore",
		"scenario_town_placement_id": "ninefold_orevein_gantry",
		"priority_site_ids": ["ridge_quarry", "dwelling_basalt_gatehouse"],
		"neutral_dwelling_ids": ["neutral_dwelling_basalt_gatehouse"],
	},
	{
		"faction_id": "faction_veilmourn",
		"primary_town_id": "town_veilmourn_bellwake_harbor",
		"secondary_town_id": "town_veilmourn_fogchart_mooring",
		"hero_id": "hero_veilmourn_ivara_blacktide",
		"unit_ids": ["unit_veilmourn_bellwake_oars", "unit_veilmourn_maskglass_corsairs"],
		"spell_ids": ["spell_fogwake_step", "spell_obituary_mark"],
		"artifact_id": "artifact_black_sail_compass",
		"live_resource_id": "wood",
		"scenario_town_placement_id": "ninefold_bellwake_harbor",
		"priority_site_ids": ["mist_lighthouse", "dwelling_harbor_pilot_house"],
		"neutral_dwelling_ids": ["neutral_dwelling_harbor_pilot_house"],
	},
]

func _ready() -> void:
	call_deferred("_run")

func _run() -> void:
	ContentService.clear_cache()
	var scenario := ContentService.get_scenario(SCENARIO_ID)
	if scenario.is_empty():
		_fail("Missing scenario %s." % SCENARIO_ID)
		return
	var session = ScenarioFactoryScript.create_session(
		SCENARIO_ID,
		"normal",
		SessionStateStoreScript.LAUNCH_MODE_SKIRMISH
	)
	OverworldRules.normalize_overworld_state(session)
	if String(session.scenario_id) != SCENARIO_ID or session.overworld.get("towns", []).is_empty():
		_fail("ScenarioFactory did not bootstrap %s with towns." % SCENARIO_ID)
		return

	var rows := []
	for config in FOCUS:
		var row := _validate_focus(config, scenario, session)
		if row.is_empty():
			return
		rows.append(row)

	var balance_report: Dictionary = BalanceRegressionReportRulesScript.build_report()
	if not _validate_balance_reflection(balance_report):
		return

	var payload := {
		"ok": true,
		"report_id": REPORT_ID,
		"schema_id": "faction_content_breadth_report_v1",
		"scenario_id": SCENARIO_ID,
		"focus_faction_count": rows.size(),
		"focus_rows": rows,
		"balance_town_count": _balance_faction_summary(balance_report).get("town_count", 0),
		"balance_suite_signature": String(balance_report.get("suite_signature", "")),
		"evidence": [
			"Secondary town templates load through ContentService and reference existing buildings, units, spells, economy, and garrisons.",
			"Ninefold pressure configs continue to connect Thornwake, Brasshollow, and Veilmourn to scenario town and neutral-site hooks.",
			"Balance regression town breadth reflects the new authored town count without changing report-only policy.",
		],
	}
	print("%s %s" % [REPORT_ID, JSON.stringify(payload)])
	get_tree().quit(0)

func _validate_focus(config: Dictionary, scenario: Dictionary, session) -> Dictionary:
	var faction_id := String(config.get("faction_id", ""))
	var faction := ContentService.get_faction(faction_id)
	if faction.is_empty():
		_fail("Missing faction %s." % faction_id)
		return {}
	var town_ids: Array = faction.get("town_ids", []) if faction.get("town_ids", []) is Array else []
	for town_key in ["primary_town_id", "secondary_town_id"]:
		var town_id := String(config.get(town_key, ""))
		if town_id not in town_ids:
			_fail("%s does not list %s." % [faction_id, town_id])
			return {}
	var content_status: Dictionary = faction.get("content_status", {}) if faction.get("content_status", {}) is Dictionary else {}
	if String(content_status.get("scenario_integration", "")) == "not_started":
		_fail("%s still reports scenario_integration not_started." % faction_id)
		return {}

	var secondary_town := ContentService.get_town(String(config.get("secondary_town_id", "")))
	if not _validate_town_bundle(secondary_town, config):
		return {}
	var hero := ContentService.get_hero(String(config.get("hero_id", "")))
	if hero.is_empty() or String(hero.get("faction_id", "")) != faction_id:
		_fail("%s hero hook is missing or faction-mismatched." % faction_id)
		return {}
	for unit_id_value in config.get("unit_ids", []):
		var unit_id := String(unit_id_value)
		var unit := ContentService.get_unit(unit_id)
		if unit.is_empty() or String(unit.get("faction_id", "")) != faction_id or unit_id not in faction.get("unit_ladder_ids", []):
			_fail("%s unit hook is missing or not in the faction ladder: %s." % [faction_id, unit_id])
			return {}
	var artifact := ContentService.get_artifact(String(config.get("artifact_id", "")))
	if artifact.is_empty() or faction_id not in artifact.get("faction_affinity", []):
		_fail("%s artifact affinity is missing." % faction_id)
		return {}

	var enemy_config := _enemy_config_for_faction(scenario, faction_id)
	if enemy_config.is_empty():
		_fail("%s has no %s pressure config." % [SCENARIO_ID, faction_id])
		return {}
	var priority_ids: Array = enemy_config.get("priority_target_placement_ids", []) if enemy_config.get("priority_target_placement_ids", []) is Array else []
	if String(config.get("scenario_town_placement_id", "")) not in priority_ids:
		_fail("%s pressure config does not target its scenario town." % faction_id)
		return {}
	for site_id_value in config.get("priority_site_ids", []):
		if String(site_id_value) not in priority_ids:
			_fail("%s pressure config missing priority site %s." % [faction_id, site_id_value])
			return {}
	for dwelling_id_value in config.get("neutral_dwelling_ids", []):
		if not _validate_neutral_dwelling_hook(String(dwelling_id_value), scenario):
			return {}
	if not _session_has_town_placement(session, String(config.get("scenario_town_placement_id", "")), String(config.get("primary_town_id", ""))):
		_fail("%s session does not include the expected scenario town placement." % faction_id)
		return {}

	return {
		"faction_id": faction_id,
		"town_count": town_ids.size(),
		"secondary_town_id": String(config.get("secondary_town_id", "")),
		"hero_id": String(config.get("hero_id", "")),
		"unit_hooks": config.get("unit_ids", []),
		"spell_hooks": config.get("spell_ids", []),
		"artifact_id": String(config.get("artifact_id", "")),
		"scenario_town_placement_id": String(config.get("scenario_town_placement_id", "")),
		"priority_site_count": config.get("priority_site_ids", []).size(),
	}

func _validate_town_bundle(town: Dictionary, config: Dictionary) -> bool:
	var faction_id := String(config.get("faction_id", ""))
	var town_id := String(config.get("secondary_town_id", ""))
	if town.is_empty() or String(town.get("id", "")) != town_id or String(town.get("faction_id", "")) != faction_id:
		_fail("Secondary town %s is missing or faction-mismatched." % town_id)
		return false
	var economy: Dictionary = town.get("economy", {}) if town.get("economy", {}) is Dictionary else {}
	var base_income: Dictionary = economy.get("base_income", {}) if economy.get("base_income", {}) is Dictionary else {}
	if int(base_income.get("gold", 0)) <= 0 or int(base_income.get(String(config.get("live_resource_id", "")), 0)) <= 0:
		_fail("Secondary town %s lacks live economy support." % town_id)
		return false
	var recruitment: Dictionary = town.get("recruitment", {}) if town.get("recruitment", {}) is Dictionary else {}
	var growth_bonus: Dictionary = recruitment.get("growth_bonus", {}) if recruitment.get("growth_bonus", {}) is Dictionary else {}
	var unit_hooks: Array = config.get("unit_ids", []) if config.get("unit_ids", []) is Array else []
	if unit_hooks.is_empty() or String(unit_hooks[0]) not in growth_bonus:
		_fail("Secondary town %s does not recruit its first unit hook." % town_id)
		return false
	for building_id_value in town.get("starting_building_ids", []) + town.get("buildable_building_ids", []):
		if ContentService.get_building(String(building_id_value)).is_empty():
			_fail("Secondary town %s references missing building %s." % [town_id, building_id_value])
			return false
	for stack in town.get("garrison", []):
		if not (stack is Dictionary):
			continue
		var unit := ContentService.get_unit(String(stack.get("unit_id", "")))
		if unit.is_empty() or String(unit.get("faction_id", "")) != faction_id or int(stack.get("count", 0)) <= 0:
			_fail("Secondary town %s has invalid garrison stack %s." % [town_id, stack])
			return false
	var library_spell_ids := _town_spell_ids(town)
	for spell_id_value in config.get("spell_ids", []):
		var spell_id := String(spell_id_value)
		if spell_id not in library_spell_ids or ContentService.get_spell(spell_id).is_empty():
			_fail("Secondary town %s does not expose spell hook %s." % [town_id, spell_id])
			return false
	return true

func _validate_neutral_dwelling_hook(dwelling_id: String, scenario: Dictionary) -> bool:
	var dwelling := ContentService.get_neutral_dwelling(dwelling_id)
	if dwelling.is_empty():
		_fail("Missing neutral dwelling %s." % dwelling_id)
		return false
	var scenario_site_ids := _scenario_site_ids(scenario)
	for site_id_value in dwelling.get("site_ids", []):
		var site_id := String(site_id_value)
		if site_id not in scenario_site_ids:
			_fail("Neutral dwelling %s site %s is not placed in %s." % [dwelling_id, site_id, SCENARIO_ID])
			return false
	return true

func _validate_balance_reflection(balance_report: Dictionary) -> bool:
	if not bool(balance_report.get("ok", false)):
		_fail("Balance report failed after content breadth changes: %s" % JSON.stringify(balance_report))
		return false
	var policy: Dictionary = balance_report.get("reporting_policy", {}) if balance_report.get("reporting_policy", {}) is Dictionary else {}
	if bool(policy.get("alpha_or_parity_claim", true)) or bool(policy.get("automatic_tuning", true)) or bool(policy.get("authored_content_writeback", true)):
		_fail("Balance report crossed report-only policy: %s" % JSON.stringify(policy))
		return false
	var summary := _balance_faction_summary(balance_report)
	if int(summary.get("town_count", 0)) < 15:
		_fail("Balance report did not reflect expanded town breadth: %s" % summary)
		return false
	var faction_rows: Array = _balance_faction_rows(balance_report)
	for config in FOCUS:
		var row := _row_for_faction(faction_rows, String(config.get("faction_id", "")))
		if row.is_empty() or int(row.get("town_count", 0)) < 2:
			_fail("Balance faction row did not reflect secondary town: %s / %s" % [config.get("faction_id", ""), row])
			return false
	var compact_text := JSON.stringify(BalanceRegressionReportRulesScript.compact_summary(balance_report)).to_lower()
	for token in FORBIDDEN_CLAIM_TOKENS:
		if compact_text.contains(String(token)):
			_fail("Balance report contains forbidden claim token: %s." % token)
			return false
	return true

func _enemy_config_for_faction(scenario: Dictionary, faction_id: String) -> Dictionary:
	for config in scenario.get("enemy_factions", []):
		if config is Dictionary and String(config.get("faction_id", "")) == faction_id:
			return config
	return {}

func _session_has_town_placement(session, placement_id: String, town_id: String) -> bool:
	for town in session.overworld.get("towns", []):
		if town is Dictionary and String(town.get("id", town.get("placement_id", ""))) == placement_id and String(town.get("town_id", "")) == town_id:
			return true
	return false

func _scenario_site_ids(scenario: Dictionary) -> Array[String]:
	var ids: Array[String] = []
	for node in scenario.get("resource_nodes", []):
		if node is Dictionary:
			ids.append(String(node.get("site_id", "")))
	return ids

func _town_spell_ids(town: Dictionary) -> Array[String]:
	var ids: Array[String] = []
	for entry in town.get("spell_library", []):
		if not (entry is Dictionary):
			continue
		for spell_id_value in entry.get("spell_ids", []):
			ids.append(String(spell_id_value))
	return ids

func _balance_faction_summary(balance_report: Dictionary) -> Dictionary:
	for section in balance_report.get("sections", []):
		if section is Dictionary and String(section.get("section_id", "")) == "faction_content_balance_snapshot":
			return section.get("summary", {}) if section.get("summary", {}) is Dictionary else {}
	return {}

func _balance_faction_rows(balance_report: Dictionary) -> Array:
	for section in balance_report.get("sections", []):
		if not (section is Dictionary) or String(section.get("section_id", "")) != "faction_content_balance_snapshot":
			continue
		var evidence: Dictionary = section.get("evidence", {}) if section.get("evidence", {}) is Dictionary else {}
		return evidence.get("factions", []) if evidence.get("factions", []) is Array else []
	return []

func _row_for_faction(rows: Array, faction_id: String) -> Dictionary:
	for row in rows:
		if row is Dictionary and String(row.get("faction_id", "")) == faction_id:
			return row
	return {}

func _fail(message: String) -> void:
	push_error(message)
	print("%s %s" % [REPORT_ID, JSON.stringify({"ok": false, "error": message})])
	get_tree().quit(1)
