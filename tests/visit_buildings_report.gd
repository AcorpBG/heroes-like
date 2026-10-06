extends Node
# Live rules for HoMM-style visit buildings (docs/visit-buildings.md): effects,
# per-hero cadence, choices and prices, week bonuses, next-battle boosts, AI
# visits, and random-map mapping by meaning.

const NativeRandomMapPackageSessionBridgeScript = preload("res://scripts/persistence/NativeRandomMapPackageSessionBridge.gd")
const OverworldRulesScript = preload("res://scripts/core/OverworldRules.gd")
const BattleRulesScript = preload("res://scripts/core/BattleRules.gd")
const EnemyAdventureRulesScript = preload("res://scripts/core/EnemyAdventureRules.gd")
const VisitBuildings = preload("res://scripts/core/VisitBuildingRules.gd")
const GeneratedRewards = preload("res://scripts/persistence/GeneratedRewardRules.gd")

const REPORT_ID := "VISIT_BUILDINGS_REPORT"

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
	var mapping := _check_random_map_mapping()
	var growth := _check_growth_buildings()
	var mana := _check_mana_and_movement()
	var boosts := _check_battle_boosts()
	var services := _check_services()
	var ai := _check_ai()
	if not _failures.is_empty():
		_fail(JSON.stringify(_failures))
		return
	print("%s %s" % [REPORT_ID, JSON.stringify({"ok": true, "mapping": mapping, "growth": growth, "mana": mana, "boosts": boosts, "services": services, "ai": ai})])
	get_tree().quit(0)

func _check_random_map_mapping() -> Dictionary:
	var sources: Dictionary = _session.overworld.get("package_source_objects_by_id", {})
	var by_type := {}
	var visit_nodes := 0
	for node in _session.overworld.get("resource_nodes", []):
		var source: Dictionary = sources.get(String(node.get("placement_id", "")), {})
		var type_id := int(source.get("h3m_type_id", -1))
		var site_id := String(node.get("site_id", ""))
		if GeneratedRewards.VISIT_SITE_BY_TYPE.has(type_id):
			_expect(site_id == String(GeneratedRewards.VISIT_SITE_BY_TYPE[type_id]), "HoMM3 type %d maps to %s, got %s" % [type_id, GeneratedRewards.VISIT_SITE_BY_TYPE[type_id], site_id])
		if GeneratedRewards.SPELL_SHRINE_BY_TYPE.has(type_id):
			var shrine: Array = GeneratedRewards.SPELL_SHRINE_BY_TYPE[type_id]
			var spells: Array = node.get("payload_spell_ids", [])
			_expect(site_id == String(shrine[0]) and spells.size() == 1 and int(ContentService.get_spell(String(spells[0])).get("tier", 0)) == int(shrine[1]), "Shrine of Magic %d teaches a tier %d spell: %s %s" % [type_id, int(shrine[1]), site_id, spells])
		if type_id in GeneratedRewards.SCOUTING_TYPES:
			_expect(site_id in GeneratedRewards.SCOUTING_SITES, "observatory type %d becomes a scouting structure, got %s" % [type_id, site_id])
		if VisitBuildings.is_visit_building(ContentService.get_resource_site(site_id)):
			visit_nodes += 1
		by_type[type_id] = site_id
	_expect(visit_nodes >= 30, "medium map holds at least 30 visit buildings, got %d" % visit_nodes)
	return {"visit_buildings": visit_nodes}

func _check_growth_buildings() -> Dictionary:
	_session.overworld["resources"]["gold"] = 20000
	var bell := _inject("site_visit_bell_spire")
	var attack_before := _command("attack")
	var first := _visit(bell)
	var again := _visit(bell)
	_expect(bool(first.get("ok", false)) and _command("attack") == attack_before + 1, "Bell Spire gives +1 attack: %s" % first.get("message", ""))
	_expect(not bool(again.get("ok", false)), "Bell Spire works once per hero")

	var rostrum := _inject("site_visit_proving_rostrum")
	var prompt := _visit(rostrum)
	_expect(String(prompt.get("route", "")) == "reward_choice" and prompt.get("reward_choice", {}).get("choices", []).size() == 2, "Proving Rostrum offers two boons")
	var defense_before := _command("defense")
	var chosen := _visit(rostrum, "defense")
	_expect(bool(chosen.get("ok", false)) and _command("defense") == defense_before + 2, "Proving Rostrum grants +2 defense: %s" % chosen.get("message", ""))

	var college := _inject("site_visit_war_college")
	var gold_before := int(_session.overworld.get("resources", {}).get("gold", 0))
	var attack_mid := _command("attack")
	var studied := _visit(college, "attack")
	_expect(bool(studied.get("ok", false)) and _command("attack") == attack_mid + 1 and int(_session.overworld.get("resources", {}).get("gold", 0)) == gold_before - 1000, "War College sells +1 attack for 1,000 gold")

	var lorestone := _inject("site_visit_lorestone")
	var xp_before := int(_session.overworld.get("hero", {}).get("experience", 0))
	_visit(lorestone)
	_expect(int(_session.overworld.get("hero", {}).get("experience", 0)) == xp_before + 1000, "Lorestone gives 1,000 experience")

	var tree := _inject("site_visit_elder_graft_tree")
	var level_before := int(_session.overworld.get("hero", {}).get("level", 1))
	_visit(tree)
	_expect(int(_session.overworld.get("hero", {}).get("level", 1)) == level_before + 1, "Elder Graft Tree grants a level")

	var archive := _inject("site_visit_grand_archive")
	var refused := _visit(archive)
	_expect(not bool(refused.get("ok", false)) and int(_session.overworld.get("hero", {}).get("level", 1)) < 10, "Grand Archive refuses heroes below level 10")

	var shrine := _inject("site_reedscript_vow_shrine")
	var known_before: Array = _session.overworld.get("hero", {}).get("spellbook", {}).get("known_spell_ids", []).duplicate()
	var taught := _visit(shrine)
	var known_after: Array = _session.overworld.get("hero", {}).get("spellbook", {}).get("known_spell_ids", [])
	_expect(bool(taught.get("ok", false)) and known_after.size() == known_before.size() + 1, "Reedscript Vow Shrine teaches a spell: %s" % taught.get("message", ""))
	return {"attack": _command("attack"), "defense": _command("defense"), "level": int(_session.overworld.get("hero", {}).get("level", 1))}

func _check_mana_and_movement() -> Dictionary:
	var hero: Dictionary = _session.overworld.get("hero", {})
	var mana_max := int(hero.get("spellbook", {}).get("mana", {}).get("max", 0))
	hero["spellbook"]["mana"]["current"] = 0
	_session.overworld["hero"] = hero
	var well := _inject("site_visit_ley_well")
	var refilled := _visit(well)
	_expect(bool(refilled.get("ok", false)) and _mana()[0] == mana_max, "Ley Well refills mana")
	_expect(not bool(_visit(well).get("ok", false)), "Ley Well works once per hero each day")
	var spring := _inject("site_visit_moonspring")
	_visit(spring)
	_expect(_mana()[1] == mana_max * 2 and _mana()[0] == mana_max * 2, "Moonspring doubles mana for the week: %s" % [_mana()])
	var stable := _inject("site_courier_change_post")
	var movement_max_before := int(_session.overworld.get("movement", {}).get("max", 0))
	_visit(stable)
	_expect(int(_session.overworld.get("movement", {}).get("max", 0)) == movement_max_before + 3, "Remount Stable adds 3 movement for the week")
	_session.day = 8
	OverworldRulesScript._refresh_all_player_heroes_for_new_day(_session)
	_expect(_mana()[1] == mana_max and int(_session.overworld.get("movement", {}).get("max", 0)) == movement_max_before, "week bonuses end when the new week starts")
	return {"mana_max": mana_max, "movement_max": movement_max_before}

func _check_battle_boosts() -> Dictionary:
	var chapel := _inject("site_wayfarer_infirmary")
	_visit(chapel)
	var banner := _inject("site_furnace_oath_marker")
	_visit(banner)
	var boosts: Dictionary = _session.overworld.get("hero", {}).get(VisitBuildings.BATTLE_BOOSTS, {})
	_expect(int(boosts.get("cohesion", 0)) == 2 and int(boosts.get("momentum", 0)) == 1, "chapel and banner store +2 cohesion and +1 momentum: %s" % boosts)
	var stacks := [{"side": "player", "cohesion_base": 5, "cohesion": 5, "momentum": 0}, {"side": "enemy", "cohesion_base": 5, "cohesion": 5, "momentum": 0}]
	BattleRulesScript._apply_hero_battle_boosts(_session, stacks, _session.overworld.get("hero", {}).duplicate(true))
	_expect(int(stacks[0]["cohesion"]) == 7 and int(stacks[0]["momentum"]) == 1 and int(stacks[1]["cohesion"]) == 5, "boosts reach only the hero's army: %s" % [stacks])
	_expect(_session.overworld.get("hero", {}).get(VisitBuildings.BATTLE_BOOSTS, {}).is_empty(), "boosts are spent by the battle")
	return {"player_stack": stacks[0]}

func _check_services() -> Dictionary:
	_session.overworld["resources"]["wood"] = 10
	var exchange := _inject("site_market_caravanserai")
	var gold_before := int(_session.overworld.get("resources", {}).get("gold", 0))
	var sold := _visit(exchange, "sell_wood")
	_expect(bool(sold.get("ok", false)) and int(_session.overworld.get("resources", {}).get("gold", 0)) == gold_before + 250 and int(_session.overworld.get("resources", {}).get("wood", 0)) == 5, "Wayside Exchange sells 5 wood for 250 gold")
	_expect(bool(_visit(exchange, "sell_wood").get("ok", false)), "Wayside Exchange trades any time")
	var charts := _inject("site_contract_scribe_booth")
	var charted := _visit(charts)
	_expect(bool(charted.get("ok", false)) and String(charted.get("message", "")).contains("Charts reveal"), "Chartmaker reveals the map level for 1,000 gold: %s" % charted.get("message", ""))
	for site in ContentService.load_json("res://content/resource_sites.json").get("items", []):
		if VisitBuildings.is_visit_building(site):
			_expect(int(VisitBuildings.effects(site).get("experience", 0)) == 0 or VisitBuildings.cost(site).is_empty(), "%s does not sell experience" % site.get("id", ""))
	return {"gold": int(_session.overworld.get("resources", {}).get("gold", 0))}

func _check_ai() -> Dictionary:
	var index := _inject("site_visit_clamp_forge")
	var node: Dictionary = _session.overworld.get("resource_nodes", [])[index]
	var site := ContentService.get_resource_site("site_visit_clamp_forge")
	var faction_id := "faction_mireclaw"
	var before := EnemyAdventureRulesScript._resource_node_contestable_by_faction(node, site, faction_id, _session)
	var ring_site := ContentService.get_resource_site("site_root_accord_ring")
	_expect(not EnemyAdventureRulesScript._resource_node_contestable_by_faction(node, ring_site, faction_id, _session), "AI skips boost-only buildings its commanders cannot keep")
	VisitBuildings.record_visit(node, site, "ai:%s" % faction_id, _session.day)
	var after := EnemyAdventureRulesScript._resource_node_contestable_by_faction(node, site, faction_id, _session)
	_expect(before and not after, "AI may visit a stat building once and never captures it")
	var exchange_site := ContentService.get_resource_site("site_market_caravanserai")
	_expect(not EnemyAdventureRulesScript._resource_node_contestable_by_faction(node, exchange_site, faction_id, _session), "AI ignores the exchange")
	return {"contestable_before": before, "contestable_after": after}

func _inject(site_id: String) -> int:
	var hero: Vector2i = OverworldRulesScript.hero_position(_session)
	var nodes: Array = _session.overworld.get("resource_nodes", [])
	nodes.append({"placement_id": "visit_buildings_report_%s_%d" % [site_id, nodes.size()], "site_id": site_id, "x": hero.x, "y": hero.y, "collected": false})
	_session.overworld["resource_nodes"] = nodes
	OverworldRulesScript.normalize_overworld_state(_session)
	return _session.overworld.get("resource_nodes", []).size() - 1

func _visit(index: int, choice_id: String = "") -> Dictionary:
	var nodes: Array = _session.overworld.get("resource_nodes", [])
	return OverworldRulesScript._collect_resource_node_result(_session, {"index": index, "node": nodes[index]}, false, 1, choice_id)

func _command(key: String) -> int:
	return int(_session.overworld.get("hero", {}).get("command", {}).get(key, 0))

func _mana() -> Array:
	var mana: Dictionary = _session.overworld.get("hero", {}).get("spellbook", {}).get("mana", {})
	return [int(mana.get("current", 0)), int(mana.get("max", 0))]

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
