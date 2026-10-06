extends Node
# Live rules for pickups and income sites (docs/pickups-and-income-sites.md):
# HoMM payloads on a generated map, no capture or recapture bonus, mines-only
# daily income, and weekly visit producers.

const ScenarioSelectRulesScript = preload("res://scripts/core/ScenarioSelectRules.gd")
const NativeRandomMapPackageSessionBridgeScript = preload("res://scripts/persistence/NativeRandomMapPackageSessionBridge.gd")
const OverworldRulesScript = preload("res://scripts/core/OverworldRules.gd")
const GeneratedRewards = preload("res://scripts/persistence/GeneratedRewardRules.gd")
const NodePayload = preload("res://scripts/core/ResourceNodePayloadRules.gd")

const REPORT_ID := "PICKUPS_INCOME_RULES_REPORT"
const RARE_RESOURCES := ["aetherglass", "embergrain", "peatwax", "verdant_grafts", "brass_scrip", "memory_salt"]

var _failures := []

func _ready() -> void:
	call_deferred("_run")

func _run() -> void:
	var service: Variant = ClassDB.instantiate("MapPackageService")
	var generated: Dictionary = service.generate_random_map(_config("medium", 72, "10"), {"startup_path": "pickups_income_rules_report"})
	var adoption: Dictionary = service.convert_generated_payload(generated, {"feature_gate": REPORT_ID})
	var session = NativeRandomMapPackageSessionBridgeScript.build_session_from_adoption(adoption)
	if session == null:
		_fail("Generated medium map did not adopt into a session.")
		return
	OverworldRulesScript.normalize_overworld_state(session)
	var payloads := _check_generated_payloads(session)
	var content := _check_content_rules()
	var recapture := _check_no_recapture_payload(session)
	var mine := _check_mine_capture_and_income(session)
	var weekly := _check_weekly_producer(session)
	if not _failures.is_empty():
		_fail(JSON.stringify(_failures))
		return
	print("%s %s" % [REPORT_ID, JSON.stringify({"ok": true, "payloads": payloads, "content": content, "recapture": recapture, "mine": mine, "weekly": weekly})])
	get_tree().quit(0)

func _check_generated_payloads(session) -> Dictionary:
	var sources: Dictionary = session.overworld.get("package_source_objects_by_id", {})
	var counts := {}
	var rares := {}
	for node in session.overworld.get("resource_nodes", []):
		var source: Dictionary = sources.get(String(node.get("placement_id", "")), {})
		var type_id := int(source.get("h3m_type_id", -1))
		var site_id := String(node.get("site_id", ""))
		var rewards: Dictionary = node.get(NodePayload.PAYLOAD_REWARDS, {})
		match type_id:
			79, 76:
				var resource_id := String(node.get("resource_id", ""))
				var amount := int(rewards.get(resource_id, 0))
				var low := 3 if resource_id in RARE_RESOURCES else (500 if resource_id == "gold" else 5)
				var high := 6 if resource_id in RARE_RESOURCES else (1000 if resource_id == "gold" else 10)
				_expect(GeneratedRewards.PILE_SITES.get(resource_id, "") == site_id and rewards.size() == 1 and amount >= low and amount <= high, "pile %s has a HoMM amount: %s" % [site_id, rewards])
				if resource_id in RARE_RESOURCES:
					rares[resource_id] = true
			101:
				var choices: Array = node.get(NodePayload.PAYLOAD_REWARD_CHOICES, [])
				var gold := int(choices[0].get("rewards", {}).get("gold", 0)) if choices.size() == 2 else 0
				var experience := int(choices[1].get("rewards", {}).get("experience", 0)) if choices.size() == 2 else 0
				_expect(site_id == "site_waystone_cache" and [gold, experience] in GeneratedRewards.TREASURE_CHEST_TIERS, "treasure chest offers a HoMM tier: %s" % [choices])
			12:
				_expect(site_id == "site_wayfarer_camp_cache" and int(rewards.get("gold", 0)) in [400, 500, 600] and rewards.size() == 2, "campfire pays gold plus one resource: %s" % [rewards])
			93:
				var spells: Array = node.get(NodePayload.PAYLOAD_SPELL_IDS, [])
				_expect(site_id == "site_spell_scroll" and spells.size() == 1 and int(ContentService.get_spell(String(spells[0])).get("tier", 0)) in [1, 2, 3, 4], "spell scroll teaches one tier 1-4 spell: %s" % [spells])
			53:
				_expect(String(node.get("site_id", "")) in GeneratedRewards.MINE_SITES.values(), "mine slot became a mine: %s" % site_id)
			109, 112, 55:
				_expect(String(ContentService.get_resource_site(site_id).get("family", "")) == "support_producer", "%d slot became a weekly producer: %s" % [type_id, site_id])
		_expect(site_id not in ["site_wood_wagon", "site_ore_crates"], "random maps never place %s" % site_id)
		counts[type_id] = int(counts.get(type_id, 0)) + 1
	_expect(int(counts.get(79, 0)) > 0 and int(counts.get(101, 0)) > 0 and int(counts.get(53, 0)) > 0, "medium map holds piles, chests and mines: %s" % counts)
	_expect(rares.size() >= 4, "rare piles spread over the rares: %s" % rares.keys())
	return {"type_counts": counts, "rare_piles": rares.keys()}

func _check_content_rules() -> Dictionary:
	var paying := []
	for site in ContentService.load_json("res://content/resource_sites.json").get("items", []):
		var family := String(site.get("family", ""))
		if family in ["neutral_dwelling", "faction_landmark", "scouting_structure", "faction_outpost"]:
			_expect(not site.get("control_income") and not site.get("claim_rewards"), "%s pays no capture bonus or income" % site.get("id", ""))
		if family in ["mine", "staged_resource_front"]:
			_expect(not site.get("claim_rewards"), "%s pays no capture bonus" % site.get("id", ""))
		if site.get("control_income"):
			paying.append(String(site.get("id", "")))
	for site_id in paying:
		var family := String(ContentService.get_resource_site(site_id).get("family", ""))
		_expect(family in ["mine", "staged_resource_front"], "only mines pay daily income, not %s" % site_id)
	return {"daily_income_sites": paying.size()}

func _check_no_recapture_payload(session) -> Dictionary:
	# A persistent shrine pays its experience once; recapturing it pays nothing.
	var index := _inject_node(session, "site_roadside_sanctum")
	var first := _claim(session, index)
	var first_xp := _hero_experience(session) - int(first.get("experience_before", 0))
	var nodes: Array = session.overworld.get("resource_nodes", [])
	var node: Dictionary = nodes[index]
	node["collected_by_faction_id"] = "faction_mireclaw"
	nodes[index] = node
	var second := _claim(session, index)
	var second_xp := _hero_experience(session) - int(second.get("experience_before", 0))
	_expect(bool(first.get("ok", false)) and first_xp == 100, "first shrine claim pays its experience: %s" % [first])
	_expect(bool(second.get("ok", false)) and second_xp == 0 and bool(session.overworld.get("resource_nodes", [])[index].get(NodePayload.CLAIM_PAYLOAD_SPENT, false)), "recapture pays no experience: %s" % [second])
	return {"first_experience": first_xp, "recapture_experience": second_xp}

func _check_mine_capture_and_income(session) -> Dictionary:
	var index := _inject_node(session, "site_ridge_quarry")
	var income_before: Dictionary = OverworldRulesScript.controlled_resource_site_income(session, "player")
	var claim := _claim(session, index)
	var income_after: Dictionary = OverworldRulesScript.controlled_resource_site_income(session, "player")
	var stock_delta := _resource_delta(claim.get("resources_before", {}), session.overworld.get("resources", {}))
	_expect(bool(claim.get("ok", false)) and stock_delta.is_empty(), "capturing a mine pays nothing on capture: %s" % [stock_delta])
	_expect(int(income_after.get("ore", 0)) - int(income_before.get("ore", 0)) == 2, "a held ore mine pays 2 ore a day: %s -> %s" % [income_before, income_after])
	return {"capture_delta": stock_delta, "daily_ore": int(income_after.get("ore", 0)) - int(income_before.get("ore", 0))}

func _check_weekly_producer(session) -> Dictionary:
	var index := _inject_node(session, "site_saw_chain")
	var first := _claim(session, index)
	var first_delta := _resource_delta(first.get("resources_before", {}), session.overworld.get("resources", {}))
	var same_week := _claim(session, index)
	session.day += 7
	var next_week := _claim(session, index)
	var next_delta := _resource_delta(next_week.get("resources_before", {}), session.overworld.get("resources", {}))
	_expect(bool(first.get("ok", false)) and first_delta == {"wood": 5}, "Saw Chain pays 5 wood on a visit: %s" % [first_delta])
	_expect(not bool(same_week.get("ok", false)), "Saw Chain cannot be visited again the same week")
	_expect(bool(next_week.get("ok", false)) and next_delta == {"wood": 5}, "Saw Chain pays again after 7 days: %s" % [next_delta])
	_expect(OverworldRulesScript.controlled_resource_site_income(session, "player").get("wood", 0) == 0, "a weekly producer pays no daily income")
	return {"visit": first_delta, "next_week": next_delta}

func _inject_node(session, site_id: String) -> int:
	var hero: Vector2i = OverworldRulesScript.hero_position(session)
	var nodes: Array = session.overworld.get("resource_nodes", [])
	nodes.append({"placement_id": "pickups_income_rules_%s" % site_id, "site_id": site_id, "x": hero.x, "y": hero.y, "collected": false})
	session.overworld["resource_nodes"] = nodes
	OverworldRulesScript.normalize_overworld_state(session)
	return session.overworld.get("resource_nodes", []).size() - 1

func _claim(session, index: int) -> Dictionary:
	var nodes: Array = session.overworld.get("resource_nodes", [])
	var before: Dictionary = session.overworld.get("resources", {}).duplicate(true)
	var experience_before := _hero_experience(session)
	var result: Dictionary = OverworldRulesScript._collect_resource_node_result(session, {"index": index, "node": nodes[index]}, false)
	return {"ok": bool(result.get("ok", false)), "message": String(result.get("message", "")), "resources_before": before, "experience_before": experience_before}

func _hero_experience(session) -> int:
	return int(session.overworld.get("hero", {}).get("experience", 0))

func _resource_delta(before: Dictionary, after: Dictionary) -> Dictionary:
	var delta := {}
	for key in after.keys():
		var change := int(after.get(key, 0)) - int(before.get(key, 0))
		if change != 0:
			delta[String(key)] = change
	return delta

func _expect(condition: bool, message: String) -> void:
	if not condition:
		_failures.append(message)

func _config(size_class: String, dimension: int, seed: String) -> Dictionary:
	return {
		"seed": seed,
		"size": {"width": dimension, "height": dimension, "level_count": 1, "water_mode": "land", "size_class_id": size_class},
		"monster_strength": "weak",
		"player_constraints": {"human_count": 1, "computer_count": 1, "player_count": 2, "human_team_count": 1, "computer_team_count": 0},
	}

func _fail(message: String) -> void:
	push_error("%s: %s" % [REPORT_ID, message])
	get_tree().quit(1)
