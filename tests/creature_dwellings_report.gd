extends Node
# Live rules for HoMM3-style creature dwellings (docs/creature-dwellings.md):
# one creature at its weekly growth, hiring at the dwelling with free tier 1,
# weekly reset, +1 town growth, per-side guards, AI guard fights and hiring,
# the Drifters' Camp, and random-map translation by tier and faction.

const NativeRandomMapPackageSessionBridgeScript = preload("res://scripts/persistence/NativeRandomMapPackageSessionBridge.gd")
const OverworldRulesScript = preload("res://scripts/core/OverworldRules.gd")
const BattleRulesScript = preload("res://scripts/core/BattleRules.gd")
const EnemyAdventureRulesScript = preload("res://scripts/core/EnemyAdventureRules.gd")
const CreatureDwellings = preload("res://scripts/core/CreatureDwellingRules.gd")
const GeneratedRewards = preload("res://scripts/persistence/GeneratedRewardRules.gd")

const REPORT_ID := "CREATURE_DWELLINGS_REPORT"
const TEST_PREFIX := "dwelling_report_"
const FACTIONS := ["faction_brasshollow", "faction_embercourt", "faction_mireclaw", "faction_sunvault", "faction_thornwake", "faction_veilmourn"]

var _failures := []
var _session

func _ready() -> void:
	call_deferred("_run")

func _run() -> void:
	var service: Variant = ClassDB.instantiate("MapPackageService")
	var generated: Dictionary = service.generate_random_map(_config(), {"startup_path": REPORT_ID})
	var adoption: Dictionary = service.convert_generated_payload(generated, {"feature_gate": REPORT_ID})
	_session = NativeRandomMapPackageSessionBridgeScript.build_session_from_adoption(adoption)
	if _session == null:
		_fail("Generated medium map did not adopt into a session.")
		return
	OverworldRulesScript.normalize_overworld_state(_session)
	_session.overworld["resources"]["gold"] = 60000
	var content := _check_content()
	var mapping := _check_random_map_mapping()
	var hiring := _check_hiring()
	var growth := _check_town_growth()
	var guards := _check_guards()
	var ai := _check_ai()
	var camp := _check_refugee_camp()
	if not _failures.is_empty():
		_fail(JSON.stringify(_failures))
		return
	print("%s %s" % [REPORT_ID, JSON.stringify({"ok": true, "content": content, "mapping": mapping, "hiring": hiring, "growth": growth, "guards": guards, "ai": ai, "camp": camp})])
	get_tree().quit(0)

func _check_content() -> Dictionary:
	var dwellings := 0
	var coverage := {}
	for site in ContentService.load_json("res://content/resource_sites.json").get("items", []):
		if not CreatureDwellings.is_dwelling(site):
			continue
		dwellings += 1
		_expect(not site.has("claim_recruits") and not site.has("neutral_roster") and not site.has("town_support"), "%s keeps no capture batch or logistics metadata" % site.get("id", ""))
		var recruits: Dictionary = site.get("weekly_recruits", {})
		if CreatureDwellings.is_refugee_camp(site):
			continue
		_expect(recruits.size() == 1 or String(site.get("dwelling_kind", "")) == "multi", "%s makes one creature" % site.get("id", ""))
		for unit_id in recruits.keys():
			var unit := ContentService.get_unit(String(unit_id))
			_expect(int(recruits[unit_id]) == max(1, int(unit.get("growth", 1))), "%s musters one week of %s growth" % [site.get("id", ""), unit_id])
			if String(unit.get("faction_id", "")) != "" and not ContentService.get_map_object_for_resource_site(String(site.get("id", ""))).is_empty():
				coverage["%s|%d" % [String(unit.get("faction_id", "")), int(unit.get("tier", 1))]] = true
	for faction_id in FACTIONS:
		for tier in range(1, 8):
			_expect(coverage.has("%s|%d" % [faction_id, tier]), "%s has a tier %d dwelling" % [faction_id, tier])
	return {"dwellings": dwellings}

func _check_random_map_mapping() -> Dictionary:
	var sources: Dictionary = _session.overworld.get("package_source_objects_by_id", {})
	var count := 0
	for node in _session.overworld.get("resource_nodes", []):
		var source: Dictionary = sources.get(String(node.get("placement_id", "")), {})
		var type_id := int(source.get("h3m_type_id", -1))
		if type_id not in [17, 20, 78, 216, 217, 218]:
			continue
		count += 1
		var site := ContentService.get_resource_site(String(node.get("site_id", "")))
		_expect(CreatureDwellings.is_dwelling(site), "HoMM3 dwelling type %d becomes a dwelling, got %s" % [type_id, node.get("site_id", "")])
		if type_id == 17 and CreatureDwellings.is_dwelling(site):
			var level := int(GeneratedRewards.H3M_DWELLING_LEVEL.get(int(source.get("h3m_subtype", -1)), 0))
			var unit_id := String(site.get("weekly_recruits", {}).keys()[0])
			_expect(CreatureDwellings.unit_tier(unit_id) == level, "HoMM3 level %d dwelling keeps its tier, got %s" % [level, node.get("site_id", "")])
	return {"dwellings_on_map": count}

func _check_hiring() -> Dictionary:
	# Tier 1: flag on visit, free hire, nothing carries over.
	var index := _inject("site_free_company_yard")
	var unit_id := "unit_neutral_roadwardens"
	var growth := int(ContentService.get_unit(unit_id).get("growth", 1))
	var gold_before := _gold()
	var visit := _visit(index)
	_expect(bool(visit.get("ok", false)) and String(visit.get("route", "")) == "dwelling_recruit", "Visiting a tier 1 dwelling flags it and opens hiring: %s" % visit.get("message", ""))
	_expect(_controller(index) == "player", "Visiting flags the dwelling")
	var offer: Dictionary = visit.get("dwelling_recruit", {})
	var rows: Array = offer.get("creatures", [])
	_expect(rows.size() == 1 and int(rows[0].get("available", 0)) == growth and bool(rows[0].get("free", false)), "Offer shows one week of free Roadwardens: %s" % JSON.stringify(rows))
	var army_before := _army_count(unit_id)
	var hired := OverworldRulesScript.hire_from_dwelling(_session, {unit_id: growth}, offer.get("context", {}))
	_expect(bool(hired.get("ok", false)) and _army_count(unit_id) == army_before + growth and _gold() == gold_before, "Tier 1 creatures join for free: %s" % hired.get("message", ""))
	var again := _visit(index)
	_expect(not bool(again.get("ok", true)) or String(again.get("route", "")) != "dwelling_recruit", "Nothing left to hire this week")
	var node: Dictionary = _node(index)
	var site := ContentService.get_resource_site("site_free_company_yard")
	_expect(int(CreatureDwellings.population(node, site, _session.day + 7).get(unit_id, 0)) == growth, "The population refills next week")
	_expect(int(CreatureDwellings.population(node, site, _session.day + 21).get(unit_id, 0)) == growth, "Unhired creatures never pile up")
	_expect(OverworldRulesScript.apply_controlled_resource_site_musters(_session, "player").is_empty(), "Dwellings no longer feed towns")
	# Tier 3: hired at town price.
	var paid := _inject("site_crystal_sump")
	var paid_unit := "unit_neutral_sumpstone_guards"
	var price := int(ContentService.get_unit(paid_unit).get("cost", {}).get("gold", 0))
	var paid_visit := _visit(paid)
	var gold_mid := _gold()
	var paid_hire := OverworldRulesScript.hire_from_dwelling(_session, {paid_unit: 2}, paid_visit.get("dwelling_recruit", {}).get("context", {}))
	_expect(bool(paid_hire.get("ok", false)) and _gold() == gold_mid - 2 * price, "Tier 3 creatures cost their town price: %s" % paid_hire.get("message", ""))
	_expect(int(CreatureDwellings.population(_node(paid), ContentService.get_resource_site("site_crystal_sump"), _session.day).get(paid_unit, 0)) == int(ContentService.get_unit(paid_unit).get("growth", 1)) - 2, "Hiring draws down the week's population")
	return {"tier1_free": growth, "tier3_price": price}

func _check_town_growth() -> Dictionary:
	var town := {}
	for candidate in _session.overworld.get("towns", []):
		if String(candidate.get("owner", "")) == "player":
			town = candidate
			break
	if town.is_empty():
		_expect(false, "The generated map has a player town")
		return {}
	# Build the town's tier 2 Lantern Sappers dwelling so the town grows them.
	var towns: Array = _session.overworld.get("towns", [])
	var town_index := towns.find(town)
	var built: Array = town.get("built_buildings", [])
	if "building_dev_embercourt_t2_2" not in built:
		built.append("building_dev_embercourt_t2_2")
	town["built_buildings"] = built
	towns[town_index] = town
	_session.overworld["towns"] = towns
	var before: Dictionary = OverworldRulesScript._town_weekly_growth(town, _session)
	var target_unit := ""
	var target_site := ""
	for unit_id in before.keys():
		var base := CreatureDwellings.base_unit_id(String(unit_id))
		for site in ContentService.load_json("res://content/resource_sites.json").get("items", []):
			if CreatureDwellings.is_dwelling(site) and site.get("weekly_recruits", {}).has(base):
				target_unit = String(unit_id)
				target_site = String(site.get("id", ""))
				break
		if target_unit != "":
			break
	_expect(target_unit != "", "A town creature has a dwelling: %s town=%s built=%s dev=%s" % [JSON.stringify(before), town.get("town_id", ""), JSON.stringify(town.get("built_buildings", [])), JSON.stringify(preload("res://scripts/core/TownDevelopmentRules.gd").growth(town))])
	if target_unit == "":
		return {}
	var index := _inject(target_site, true)
	var nodes: Array = _session.overworld.get("resource_nodes", [])
	nodes[index]["collected"] = true
	nodes[index]["collected_by_faction_id"] = "player"
	_session.overworld["resource_nodes"] = nodes
	var after: Dictionary = OverworldRulesScript._town_weekly_growth(town, _session)
	_expect(int(after.get(target_unit, 0)) == int(before.get(target_unit, 0)) + 1, "A flagged dwelling adds +1 weekly growth for %s: %d -> %d" % [target_unit, int(before.get(target_unit, 0)), int(after.get(target_unit, 0))])
	return {"unit": target_unit, "before": int(before.get(target_unit, 0)), "after": int(after.get(target_unit, 0))}

func _check_guards() -> Dictionary:
	var index := _inject("site_deepforge_seventh_vault")
	var site := ContentService.get_resource_site("site_deepforge_seventh_vault")
	var guard_unit := "unit_neutral_deepforge_vaultwyrms"
	var full_count := 3 * int(ContentService.get_unit(guard_unit).get("growth", 1))
	var visit := _visit(index)
	_expect(String(visit.get("route", "")) == "battle" and not _session.battle.is_empty(), "Visiting an unbeaten tier 7 dwelling starts the guard battle: %s" % visit.get("message", ""))
	var enemy := 0
	for stack in _session.battle.get("stacks", []):
		if String(stack.get("side", "")) == "enemy":
			enemy += BattleRulesScript._alive_count(stack)
	_expect(enemy == full_count, "The guard is three weeks of Vaultwyrms (%d), got %d" % [full_count, enemy])
	_session.battle = {}
	var placement_id := String(_node(index).get("placement_id", ""))
	OverworldRulesScript.update_dwelling_guard_after_battle(_session, placement_id, [{"unit_id": guard_unit, "count": 1}], false)
	var survivors := CreatureDwellings.guard_stacks(_node(index), site, "player", _session.day)
	_expect(survivors.size() == 1 and int(survivors[0].get("count", 0)) == 1, "Survivors hold the dwelling for the rest of the week")
	_expect(int(CreatureDwellings.guard_stacks(_node(index), site, "player", _session.day + 7)[0].get("count", 0)) == full_count, "The full guard returns next week")
	_visit(index)
	var finalized: Dictionary = BattleRulesScript._finalize_victory(_session) if not _session.battle.is_empty() else {}
	_session.battle = {}
	_expect(_controller(index) == "player" and CreatureDwellings.guard_beaten(_node(index), "player"), "Winning the guard battle flags the dwelling for good: %s" % JSON.stringify(finalized.get("message", "")))
	var revisit := _visit(index)
	_expect(String(revisit.get("route", "")) == "dwelling_recruit", "No guard stands for the player after the win: %s" % revisit.get("message", ""))
	_expect(CreatureDwellings.guard_blocks(_node(index), site, "faction_mireclaw", _session.day), "Another side still has to beat its own guard")
	return {"guard_count": full_count, "beaten_by_player": CreatureDwellings.guard_beaten(_node(index), "player")}

func _check_ai() -> Dictionary:
	var index := _inject("site_deepforge_seventh_vault", true)
	var site := ContentService.get_resource_site("site_deepforge_seventh_vault")
	var faction_id := "faction_mireclaw"
	var weak := {"enemy_army": {"stacks": [{"unit_id": "unit_neutral_roadwardens", "count": 2}]}}
	var strong := {"enemy_army": {"stacks": [{"unit_id": "unit_neutral_deepforge_vaultwyrms", "count": 12}]}}
	_expect(not EnemyAdventureRulesScript._break_dwelling_guard_by_raid(_session, weak, faction_id, index, site), "A weak host cannot break the guard")
	_expect(EnemyAdventureRulesScript._break_dwelling_guard_by_raid(_session, strong, faction_id, index, site), "A strong host breaks the guard")
	_expect(CreatureDwellings.guard_beaten(_node(index), faction_id) and not CreatureDwellings.guard_beaten(_node(index), "player"), "The guard is beaten only for that side")
	var hire_index := _inject("site_crystal_sump", true)
	var hire_site := ContentService.get_resource_site("site_crystal_sump")
	var state := {"treasury": {"gold": 100000}}
	var raid := {"placement_id": "dwelling_report_raid", "encounter_id": "encounter_mire_raid", "enemy_army": {"stacks": [{"unit_id": "unit_neutral_roadwardens", "count": 4}]}}
	var hire := EnemyAdventureRulesScript._hire_dwelling_creatures_into_raid(_session, faction_id, raid, hire_index, hire_site, state)
	var hired: Dictionary = hire.get("hired", {})
	_expect(int(hired.get("unit_neutral_sumpstone_guards", 0)) == int(ContentService.get_unit("unit_neutral_sumpstone_guards").get("growth", 1)), "The AI hires the dwelling's week: %s" % JSON.stringify(hired))
	_expect(int(state.get("treasury", {}).get("gold", 0)) < 100000, "The AI pays for its hires")
	var nodes: Array = _session.overworld.get("resource_nodes", [])
	nodes[hire_index]["collected"] = true
	nodes[hire_index]["collected_by_faction_id"] = faction_id
	_session.overworld["resource_nodes"] = nodes
	_expect(not EnemyAdventureRulesScript._resource_node_contestable_by_faction(_node(hire_index), hire_site, faction_id, _session), "An emptied own dwelling is not worth a trip this week")
	return {"hired": hired}

func _check_refugee_camp() -> Dictionary:
	var index := _inject("site_dwelling_drifters_camp", true)
	var site := ContentService.get_resource_site("site_dwelling_drifters_camp")
	var week_one := CreatureDwellings.creatures(_node(index), site, _session.day)
	var week_two := CreatureDwellings.creatures(_node(index), site, _session.day + 7)
	_expect(week_one.size() == 1 and week_two.size() == 1, "The camp offers one creature each week")
	_expect(not CreatureDwellings.is_guarded(_node(index), site, _session.day), "The camp is never guarded")
	var population := CreatureDwellings.population(_node(index), site, _session.day)
	_expect(int(population.get(week_one[0], 0)) == max(1, int(ContentService.get_unit(week_one[0]).get("growth", 1))), "The camp offers a week of growth")
	return {"week_one": week_one, "week_two": week_two}

func _inject(site_id: String, far: bool = false) -> int:
	var hero: Vector2i = OverworldRulesScript.hero_position(_session)
	var nodes: Array = _session.overworld.get("resource_nodes", [])
	if not far:
		for node in nodes:
			if String(node.get("placement_id", "")).begins_with(TEST_PREFIX) and int(node.get("x", -1)) == hero.x and int(node.get("y", -1)) == hero.y:
				node["x"] = 0
				node["y"] = 0
	var position := Vector2i(1, 1) if far else hero
	nodes.append({"placement_id": "%s%s_%d" % [TEST_PREFIX, site_id, nodes.size()], "site_id": site_id, "x": position.x, "y": position.y, "collected": false})
	_session.overworld["resource_nodes"] = nodes
	OverworldRulesScript.normalize_overworld_state(_session)
	return _session.overworld.get("resource_nodes", []).size() - 1

func _visit(index: int) -> Dictionary:
	var nodes: Array = _session.overworld.get("resource_nodes", [])
	return OverworldRulesScript._collect_resource_node_result(_session, {"index": index, "node": nodes[index]}, false)

func _node(index: int) -> Dictionary:
	return _session.overworld.get("resource_nodes", [])[index]

func _controller(index: int) -> String:
	return String(_node(index).get("collected_by_faction_id", ""))

func _gold() -> int:
	return int(_session.overworld.get("resources", {}).get("gold", 0))

func _army_count(unit_id: String) -> int:
	var total := 0
	for stack in _session.overworld.get("army", {}).get("stacks", []):
		if String(stack.get("unit_id", "")) == unit_id:
			total += int(stack.get("count", 0))
	return total

func _expect(condition: bool, message: String) -> void:
	if not condition:
		_failures.append(message)

func _config() -> Dictionary:
	return {
		"seed": "10",
		"size": {"width": 72, "height": 72, "level_count": 1, "water_mode": "land", "size_class_id": "medium"},
		"monster_strength": "weak",
		"player_constraints": {"human_count": 1, "computer_count": 1, "player_count": 2, "human_team_count": 1, "computer_team_count": 0},
	}

func _fail(message: String) -> void:
	push_error("%s: %s" % [REPORT_ID, message])
	get_tree().quit(1)
