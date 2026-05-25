extends Node

const REPORT_SCHEMA := "town_unique_building_runtime_payoff_report_v1"
const MIN_UNIQUE_NON_UNIT_PER_FACTION := 5
const MIN_UNIQUE_NON_UNIT_PER_TOWN := 5
const MIN_PAYOFF_DOMAINS_PER_FACTION := 4
const MIN_PAYOFF_DOMAINS_PER_TOWN := 4
const HERO_ID := "hero_lyra"
const COMMON_RESOURCE_IDS := ["gold", "wood", "ore"]
const LIVE_STOCKPILE_RESOURCE_IDS := [
	"gold",
	"wood",
	"ore",
	"aetherglass",
	"embergrain",
	"peatwax",
	"verdant_grafts",
	"brass_scrip",
	"memory_salt",
]
const RARE_RESOURCE_IDS := [
	"aetherglass",
	"embergrain",
	"peatwax",
	"verdant_grafts",
	"brass_scrip",
	"memory_salt",
]

var _errors := []

func _ready() -> void:
	call_deferred("_run")

func _run() -> void:
	var faction_rows := []
	var town_case_count := 0
	var building_case_count := 0
	var runtime_payoff_case_count := 0
	var rare_unique_case_count := 0
	for faction_id_value in ContentService.get_content_ids(ContentService.FACTIONS_PATH):
		var faction_id := String(faction_id_value)
		var faction := ContentService.get_faction(faction_id)
		if faction.is_empty():
			continue
		var row := _run_faction_case(faction)
		faction_rows.append(row)
		town_case_count += int(row.get("town_case_count", 0))
		building_case_count += int(row.get("building_case_count", 0))
		runtime_payoff_case_count += int(row.get("runtime_payoff_case_count", 0))
		rare_unique_case_count += int(row.get("rare_unique_case_count", 0))
		if not bool(row.get("ok", false)):
			for error in row.get("errors", []):
				_errors.append(String(error))
	var report := {
		"ok": _errors.is_empty(),
		"schema": REPORT_SCHEMA,
		"faction_count": faction_rows.size(),
		"town_case_count": town_case_count,
		"building_case_count": building_case_count,
		"runtime_payoff_case_count": runtime_payoff_case_count,
		"rare_unique_case_count": rare_unique_case_count,
		"min_unique_non_unit_per_faction": MIN_UNIQUE_NON_UNIT_PER_FACTION,
		"min_unique_non_unit_per_town": MIN_UNIQUE_NON_UNIT_PER_TOWN,
		"min_payoff_domains_per_faction": MIN_PAYOFF_DOMAINS_PER_FACTION,
		"min_payoff_domains_per_town": MIN_PAYOFF_DOMAINS_PER_TOWN,
		"common_resource_ids": COMMON_RESOURCE_IDS,
		"rare_resource_ids": RARE_RESOURCE_IDS,
		"live_stockpile_resource_ids": LIVE_STOCKPILE_RESOURCE_IDS,
		"factions": faction_rows,
		"errors": _errors,
		"caveats": [
			"This report gates faction-unique non-unit town development buildings and their live payoff surfaces.",
			"Each case builds an isolated town fixture through TownRules and OverworldRules with prerequisite buildings already present.",
			"This proves runtime economy/frontier consequences for unique town buildings, not final town UI art or final campaign difficulty.",
		],
	}
	print("TOWN_UNIQUE_BUILDING_RUNTIME_PAYOFF_REPORT %s" % JSON.stringify(report))
	get_tree().quit(0 if _errors.is_empty() else 1)

func _run_faction_case(faction: Dictionary) -> Dictionary:
	var faction_id := String(faction.get("id", ""))
	var faction_errors := []
	var town_rows := []
	var unique_building_ids := _unique_non_unit_building_ids_for_faction(faction_id)
	var rare_id := _rare_resource_for_faction(faction)
	var rare_unique_case_count := 0
	var runtime_payoff_case_count := 0
	var building_case_count := 0
	if unique_building_ids.size() < MIN_UNIQUE_NON_UNIT_PER_FACTION:
		faction_errors.append("%s must expose at least %d unique non-unit town buildings" % [faction_id, MIN_UNIQUE_NON_UNIT_PER_FACTION])
	for building_id in unique_building_ids:
		if _cost_uses_resource(ContentService.get_building(String(building_id)).get("cost", {}), rare_id):
			rare_unique_case_count += 1
	if rare_unique_case_count <= 0:
		faction_errors.append("%s must have at least one unique high-tier building costing %s" % [faction_id, rare_id])
	for town_id in _string_array(faction.get("town_ids", [])):
		var town_template := ContentService.get_town(String(town_id))
		if town_template.is_empty():
			faction_errors.append("%s town %s is missing" % [faction_id, town_id])
			continue
		var town_row := _run_town_case(faction_id, town_template, unique_building_ids, rare_id)
		town_rows.append(town_row)
		building_case_count += int(town_row.get("building_case_count", 0))
		runtime_payoff_case_count += int(town_row.get("runtime_payoff_case_count", 0))
		if not bool(town_row.get("ok", false)):
			for error in town_row.get("errors", []):
				faction_errors.append(String(error))
	var payoff_domains := []
	var payoff_profiles := []
	for town_row in town_rows:
		for domain in _string_array(town_row.get("payoff_domains", [])):
			if domain not in payoff_domains:
				payoff_domains.append(domain)
		for profile in _string_array(town_row.get("payoff_profiles", [])):
			if profile not in payoff_profiles:
				payoff_profiles.append(profile)
	payoff_domains.sort()
	payoff_profiles.sort()
	if payoff_domains.size() < MIN_PAYOFF_DOMAINS_PER_FACTION:
		faction_errors.append(
			"%s unique buildings must cover at least %d live payoff domains, got %d"
			% [faction_id, MIN_PAYOFF_DOMAINS_PER_FACTION, payoff_domains.size()]
		)
	return {
		"ok": faction_errors.is_empty(),
		"faction_id": faction_id,
		"unique_non_unit_building_ids": unique_building_ids,
		"unique_non_unit_building_count": unique_building_ids.size(),
		"payoff_domains": payoff_domains,
		"payoff_domain_count": payoff_domains.size(),
		"payoff_profiles": payoff_profiles,
		"payoff_profile_count": payoff_profiles.size(),
		"rare_resource_id": rare_id,
		"rare_unique_case_count": rare_unique_case_count,
		"town_case_count": town_rows.size(),
		"building_case_count": building_case_count,
		"runtime_payoff_case_count": runtime_payoff_case_count,
		"towns": town_rows,
		"errors": faction_errors,
	}

func _run_town_case(faction_id: String, town_template: Dictionary, unique_building_ids: Array, rare_id: String) -> Dictionary:
	var town_id := String(town_template.get("id", ""))
	var town_errors := []
	var case_rows := []
	var town_unique_ids := []
	var payoff_domains := []
	var payoff_profiles := []
	for building_id in unique_building_ids:
		if String(building_id) in _string_array(town_template.get("buildable_building_ids", [])):
			town_unique_ids.append(String(building_id))
	if town_unique_ids.size() < MIN_UNIQUE_NON_UNIT_PER_TOWN:
		town_errors.append("%s must include at least %d faction-unique non-unit buildings" % [town_id, MIN_UNIQUE_NON_UNIT_PER_TOWN])
	var runtime_payoff_case_count := 0
	for building_id in town_unique_ids:
		var case_row := _run_building_case(faction_id, town_template, building_id, rare_id)
		case_rows.append(case_row)
		if bool(case_row.get("runtime_payoff_observed", false)):
			runtime_payoff_case_count += 1
		for domain in _string_array(case_row.get("payoff_domains", [])):
			if domain not in payoff_domains:
				payoff_domains.append(domain)
		var profile := String(case_row.get("payoff_profile", ""))
		if profile != "" and profile not in payoff_profiles:
			payoff_profiles.append(profile)
		if not bool(case_row.get("ok", false)):
			town_errors.append(String(case_row.get("error", "unknown unique building payoff failure")))
	payoff_domains.sort()
	payoff_profiles.sort()
	if payoff_domains.size() < MIN_PAYOFF_DOMAINS_PER_TOWN:
		town_errors.append(
			"%s unique buildings must cover at least %d live payoff domains, got %d"
			% [town_id, MIN_PAYOFF_DOMAINS_PER_TOWN, payoff_domains.size()]
		)
	return {
		"ok": town_errors.is_empty(),
		"town_id": town_id,
		"unique_non_unit_building_count": town_unique_ids.size(),
		"payoff_domains": payoff_domains,
		"payoff_domain_count": payoff_domains.size(),
		"payoff_profiles": payoff_profiles,
		"payoff_profile_count": payoff_profiles.size(),
		"building_case_count": case_rows.size(),
		"runtime_payoff_case_count": runtime_payoff_case_count,
		"cases": case_rows,
		"errors": town_errors,
	}

func _run_building_case(faction_id: String, town_template: Dictionary, building_id: String, rare_id: String) -> Dictionary:
	var building := ContentService.get_building(building_id)
	var built_prereqs := _starting_and_prereq_buildings(town_template, building_id)
	var session = _build_fixture_session(town_template, built_prereqs)
	var select_result: Dictionary = OverworldRules.set_active_town_visit(session, "unique_payoff_town")
	if not bool(select_result.get("ok", false)):
		return {"ok": false, "building_id": building_id, "error": "could not select fixture town"}
	var town_before := _town(session)
	var before := _payoff_surface(session, town_before)
	var action := _build_action_for(session, building_id)
	if action.is_empty():
		return {
			"ok": false,
			"building_id": building_id,
			"built_prereqs": built_prereqs,
			"error": "missing live build action for unique building",
		}
	if bool(action.get("disabled", false)):
		return {
			"ok": false,
			"building_id": building_id,
			"built_prereqs": built_prereqs,
			"action": action,
			"error": "unique building action is disabled in fully funded fixture",
		}
	var build_result: Dictionary = OverworldRules.build_in_active_town(session, building_id)
	if not bool(build_result.get("ok", false)):
		return {
			"ok": false,
			"building_id": building_id,
			"built_prereqs": built_prereqs,
			"action": action,
			"error": "build failed: %s" % String(build_result.get("message", "")),
		}
	var town_after := _town(session)
	var after := _payoff_surface(session, town_after)
	var deltas := _surface_delta(before, after)
	var common_cost_ok := _cost_uses_any(building.get("cost", {}), COMMON_RESOURCE_IDS)
	var rare_cost_ok := true
	if _cost_uses_any(building.get("cost", {}), RARE_RESOURCE_IDS):
		rare_cost_ok = _cost_uses_resource(building.get("cost", {}), rare_id)
	var action_surface_ok := (
		String(action.get("impact_line", "")) != ""
		and String(action.get("summary", "")).contains("Defense/frontier:")
	)
	var runtime_payoff_observed := _surface_has_delta(deltas)
	var payoff_domains := _building_payoff_domains(building, deltas)
	var payoff_profile := "|".join(PackedStringArray(payoff_domains))
	var ok := common_cost_ok and rare_cost_ok and action_surface_ok and runtime_payoff_observed
	return {
		"ok": ok,
		"faction_id": faction_id,
		"town_id": String(town_template.get("id", "")),
		"building_id": building_id,
		"category": String(building.get("category", "")),
		"cost": building.get("cost", {}),
		"uses_faction_rare": _cost_uses_resource(building.get("cost", {}), rare_id),
		"common_cost_ok": common_cost_ok,
		"rare_cost_ok": rare_cost_ok,
		"action_surface_ok": action_surface_ok,
		"runtime_payoff_observed": runtime_payoff_observed,
		"payoff_domains": payoff_domains,
		"payoff_profile": payoff_profile,
		"payoff_domain_count": payoff_domains.size(),
		"before": before,
		"after": after,
		"deltas": deltas,
		"impact_line": String(action.get("impact_line", "")),
		"summary": String(action.get("summary", "")),
		"last_build_day": int(town_after.get("last_build_day", 0)),
		"error": _case_error(common_cost_ok, rare_cost_ok, action_surface_ok, runtime_payoff_observed),
	}

func _build_fixture_session(town_template: Dictionary, built_buildings: Array):
	var hero_template := ContentService.get_hero(HERO_ID)
	var hero := HeroCommandRules.build_hero_from_template(
		hero_template,
		{"x": 1, "y": 1},
		{"id": "unique_building_payoff_army", "name": "Unique Building Payoff Army", "stacks": []},
		"normal"
	)
	hero["is_primary"] = true
	var town_state := {
		"placement_id": "unique_payoff_town",
		"town_id": String(town_template.get("id", "")),
		"x": 1,
		"y": 1,
		"owner": "player",
		"controlling_faction_id": String(town_template.get("faction_id", "")),
		"built_buildings": built_buildings,
		"available_recruits": {},
		"garrison": town_template.get("garrison", []).duplicate(true) if town_template.get("garrison", []) is Array else [],
		"last_build_day": 0,
	}
	var overworld := {
		"map": [["grass", "grass", "grass"], ["grass", "grass", "grass"], ["grass", "grass", "grass"]],
		"map_size": {"width": 3, "height": 3},
		"terrain_layers": {},
		"active_hero_id": HERO_ID,
		"player_heroes": [hero],
		"hero_position": {"x": 1, "y": 1},
		"hero": hero,
		"movement": hero.get("movement", {"current": 10, "max": 10}),
		"fog": {},
		"resources": _funded_resources(),
		"army": hero.get("army", {}),
		"encounters": [],
		"resolved_encounters": [],
		"towns": [town_state],
		"resource_nodes": [],
		"artifact_nodes": [],
		"enemy_states": [],
		"scenario_script_state": {},
	}
	var session = SessionStateStore.new_session_data(
		"town_unique_building_payoff_%s" % String(town_template.get("id", "")),
		"unique-building-payoff",
		HERO_ID,
		1,
		overworld,
		"normal",
		SessionStateStore.LAUNCH_MODE_SKIRMISH
	)
	session.game_state = "town"
	session.scenario_status = "in_progress"
	session.flags = {}
	OverworldRules.normalize_overworld_state(session)
	return session

func _payoff_surface(session, town: Dictionary) -> Dictionary:
	return {
		"income": _resources(OverworldRules.town_income(town, session)),
		"readiness": OverworldRules.town_battle_readiness(town, session),
		"pressure": OverworldRules.town_pressure_output(town, session),
		"reinforcement_quality": OverworldRules.town_reinforcement_quality(town, session),
		"spell_tier": TownRules.current_spell_tier(town),
		"market_exchange_value": int(OverworldRules.town_market_state(town).get("exchange_value", 0)),
	}

func _surface_delta(before: Dictionary, after: Dictionary) -> Dictionary:
	return {
		"income": _resource_delta(before.get("income", {}), after.get("income", {})),
		"readiness": int(after.get("readiness", 0)) - int(before.get("readiness", 0)),
		"pressure": int(after.get("pressure", 0)) - int(before.get("pressure", 0)),
		"reinforcement_quality": int(after.get("reinforcement_quality", 0)) - int(before.get("reinforcement_quality", 0)),
		"spell_tier": int(after.get("spell_tier", 0)) - int(before.get("spell_tier", 0)),
		"market_exchange_value": int(after.get("market_exchange_value", 0)) - int(before.get("market_exchange_value", 0)),
	}

func _surface_has_delta(deltas: Dictionary) -> bool:
	if not _resource_delta_is_empty(deltas.get("income", {})):
		return true
	for key in ["readiness", "pressure", "reinforcement_quality", "spell_tier", "market_exchange_value"]:
		if int(deltas.get(key, 0)) != 0:
			return true
	return false

func _building_payoff_domains(building: Dictionary, deltas: Dictionary) -> Array:
	var domains := []
	var income_payload: Dictionary = building.get("income", {}) if building.get("income", {}) is Dictionary else {}
	var income_delta: Dictionary = deltas.get("income", {}) if deltas.get("income", {}) is Dictionary else {}
	if not income_payload.is_empty() or not income_delta.is_empty():
		domains.append("income")
	if int(building.get("pressure_bonus", 0)) != 0 or int(deltas.get("pressure", 0)) != 0:
		domains.append("frontier_pressure")
	if int(building.get("spell_tier", 0)) > 0 or int(deltas.get("spell_tier", 0)) != 0:
		domains.append("spell_access")
	if int(building.get("readiness_bonus", 0)) != 0 or int(deltas.get("readiness", 0)) != 0:
		domains.append("defense_readiness")
	if _building_has_growth_or_discount(building) or int(deltas.get("reinforcement_quality", 0)) != 0:
		domains.append("muster_quality")
	if _building_has_market_payoff(building) or int(deltas.get("market_exchange_value", 0)) != 0:
		domains.append("market_exchange")
	domains.sort()
	return domains

func _building_has_growth_or_discount(building: Dictionary) -> bool:
	var growth: Dictionary = building.get("growth_bonus", {}) if building.get("growth_bonus", {}) is Dictionary else {}
	var discount: Dictionary = building.get("recruitment_discount_percent", {}) if building.get("recruitment_discount_percent", {}) is Dictionary else {}
	return not growth.is_empty() or not discount.is_empty()

func _building_has_market_payoff(building: Dictionary) -> bool:
	var building_id := String(building.get("id", ""))
	var building_name := String(building.get("name", "")).to_lower()
	return "exchange" in building_id or "exchange" in building_name or "market" in building_id or "market" in building_name

func _case_error(common_cost_ok: bool, rare_cost_ok: bool, action_surface_ok: bool, runtime_payoff_observed: bool) -> String:
	if not common_cost_ok:
		return "unique building does not cost gold, wood, or ore"
	if not rare_cost_ok:
		return "unique rare cost does not use the faction rare resource"
	if not action_surface_ok:
		return "unique building build action does not expose a live impact surface"
	if not runtime_payoff_observed:
		return "unique building did not change income/readiness/pressure/reinforcement/spell/market surfaces"
	return ""

func _build_action_for(session, building_id: String) -> Dictionary:
	for action_value in TownRules.get_build_actions(session):
		if not (action_value is Dictionary):
			continue
		var action: Dictionary = action_value
		if String(action.get("id", "")) == "build:%s" % building_id:
			return action
	return {}

func _starting_and_prereq_buildings(town_template: Dictionary, building_id: String) -> Array:
	var result := _string_array(town_template.get("starting_building_ids", []))
	_add_prereqs_recursive(result, building_id)
	var filtered := []
	for id in result:
		if String(id) != building_id and String(id) not in filtered:
			filtered.append(String(id))
	return filtered

func _add_prereqs_recursive(result: Array, building_id: String) -> void:
	var building := ContentService.get_building(building_id)
	for requirement_id in _string_array(building.get("requires", [])):
		_add_prereqs_recursive(result, requirement_id)
		if requirement_id not in result:
			result.append(requirement_id)

func _unique_non_unit_building_ids_for_faction(faction_id: String) -> Array:
	var result := []
	for building_id_value in ContentService.get_content_ids(ContentService.BUILDINGS_PATH):
		var building_id := String(building_id_value)
		var building := ContentService.get_building(building_id)
		if String(building.get("faction_id", "")) != faction_id:
			continue
		if String(building.get("unlock_unit_id", "")) != "":
			continue
		if building_id not in result:
			result.append(building_id)
	result.sort()
	return result

func _rare_resource_for_faction(faction: Dictionary) -> String:
	var town := ContentService.get_town(String(faction.get("seed_town_id", "")))
	var profile: Dictionary = town.get("development_balance", {}) if town.get("development_balance", {}) is Dictionary else {}
	return String(profile.get("rare_resource_id", ""))

func _cost_uses_resource(cost_value: Variant, resource_id: String) -> bool:
	var cost: Dictionary = cost_value if cost_value is Dictionary else {}
	return resource_id != "" and int(cost.get(resource_id, 0)) > 0

func _cost_uses_any(cost_value: Variant, resource_ids: Array) -> bool:
	var cost: Dictionary = cost_value if cost_value is Dictionary else {}
	for resource_id in resource_ids:
		if int(cost.get(String(resource_id), 0)) > 0:
			return true
	return false

func _town(session) -> Dictionary:
	for town_value in session.overworld.get("towns", []):
		if town_value is Dictionary and String(town_value.get("placement_id", "")) == "unique_payoff_town":
			return town_value
	return {}

func _funded_resources() -> Dictionary:
	var resources := {}
	for resource_id in LIVE_STOCKPILE_RESOURCE_IDS:
		resources[resource_id] = 99999
	return resources

func _resource_delta(before_value: Variant, after_value: Variant) -> Dictionary:
	var before := _resources(before_value)
	var after := _resources(after_value)
	var result := {}
	for resource_id in LIVE_STOCKPILE_RESOURCE_IDS:
		var delta := int(after.get(resource_id, 0)) - int(before.get(resource_id, 0))
		if delta != 0:
			result[resource_id] = delta
	return result

func _resource_delta_is_empty(value: Variant) -> bool:
	return not (value is Dictionary) or (value as Dictionary).is_empty()

func _resources(value: Variant) -> Dictionary:
	var source: Dictionary = value if value is Dictionary else {}
	var result := {}
	for resource_id in LIVE_STOCKPILE_RESOURCE_IDS:
		result[resource_id] = int(source.get(resource_id, 0))
	return result

func _string_array(value: Variant) -> Array:
	var result := []
	if not (value is Array):
		return result
	for item in value:
		result.append(String(item))
	return result
