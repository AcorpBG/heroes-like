extends Node
## Full-army site claims (owner rule 2026-10-08) on a generated skirmish: a
## guarded site whose reward includes troops is claimed even when the army has
## no room; troops that fit join, the rest wait for the dismiss-or-leave
## dialog. Covers the rules, the AI raid claim, walking away, the overworld
## dialog (including its return after a reload) and the free gate prompt.

const ScenarioSelectRulesScript = preload("res://scripts/core/ScenarioSelectRules.gd")
const OverworldShellScene = preload("res://scenes/overworld/OverworldShell.tscn")
const REPORT_ID := "SITE_RECRUIT_OVERFLOW_REPORT"
const SEED := "site-recruit-overflow-20261008"
const SITE_ID := "site_glassbound_eyrie"
const GATE_SITE_ID := "site_railblock_camp"

var _checks := 0
var _failures := []

func _ready() -> void:
	call_deferred("_run")

func _frames(count: int) -> void:
	for i in range(count):
		await get_tree().process_frame

func _check(condition: bool, label: String) -> void:
	_checks += 1
	if not condition:
		_failures.append(label)
		push_error("%s check failed: %s" % [REPORT_ID, label])

func _run() -> void:
	var session = _start_session()
	if session == null:
		_finish()
		return
	_rules_section(session)
	_ai_section(session)
	await _dialog_section(session)
	_gate_prompt_section(session)
	_finish()

# --- rules -------------------------------------------------------------------

func _rules_section(session) -> void:
	var node_index := _place_site(session, SITE_ID, "overflow_probe_eyrie")
	var recruits: Dictionary = OverworldRules._resource_site_claim_recruits(ContentService.get_resource_site(SITE_ID))
	_check(recruits.size() == 2, "Glassbound Eyrie grants two troop types")
	_fill_army(session, 6, recruits)
	var gold_before := int(session.overworld.resources.get("gold", 0))
	var result: Dictionary = OverworldRules._collect_resource_node_result(session, {"index": node_index, "node": session.overworld.resource_nodes[node_index]})
	var node: Dictionary = session.overworld.resource_nodes[node_index]
	_check(bool(result.get("ok", false)) and bool(node.get("collected", false)), "a full army does not block the claim")
	_check(int(session.overworld.resources.get("gold", 0)) > gold_before, "the claim still pays its gold")
	_check(_stacks(session).size() == 7, "the troop type that fits takes the free slot")
	var prompt: Dictionary = OverworldRules.site_recruit_overflow_prompt(session)
	_check(prompt.get("waiting", []).size() == 1 and prompt.get("slots", []).size() == 7, "the other troop type waits with the seven slots offered")
	_check(String(result.get("message", "")).contains("No room for"), "the claim message names the troops without a slot")
	var waiting_unit := String(prompt.waiting[0].unit_id)
	var dismissed_slot := int(_stacks(session)[0].get("slot_index", -1))
	var dismissed_unit := String(_stacks(session)[0].get("unit_id", ""))
	var stale: Dictionary = OverworldRules.take_site_recruits_by_dismissing(session, dismissed_slot, {"hero_id": "someone_else", "placement_id": "overflow_probe_eyrie"})
	_check(not bool(stale.get("ok", true)), "a stale answer is refused")
	var taken: Dictionary = OverworldRules.take_site_recruits_by_dismissing(session, dismissed_slot, prompt.context)
	_check(bool(taken.get("ok", false)) and not _has_unit(session, dismissed_unit) and _unit_slot(session, waiting_unit) == dismissed_slot, "dismissing a stack puts the waiting troops in its slot")
	_check(OverworldRules.site_recruit_overflow_prompt(session).is_empty(), "nothing waits once every troop type has a slot")
	_check(_stacks(session).size() == 7 and _hero_record_stacks(session) == 7, "the army and the hero record stay in step")
	# Leaving the troops behind loses them.
	node_index = _place_site(session, SITE_ID, "overflow_probe_eyrie_two")
	_fill_army(session, 7, recruits)
	OverworldRules._collect_resource_node_result(session, {"index": node_index, "node": session.overworld.resource_nodes[node_index]})
	prompt = OverworldRules.site_recruit_overflow_prompt(session)
	_check(prompt.get("waiting", []).size() == 2, "with seven full slots both troop types wait")
	var reloaded = SessionStateStore.new_session_data()
	reloaded.from_dict(JSON.parse_string(JSON.stringify(session.to_dict())))
	_check(OverworldRules.site_recruit_overflow_prompt(reloaded).get("waiting", []).size() == 2, "the waiting troops survive a save and reload")
	var army_before := _stacks(session).duplicate(true)
	var left: Dictionary = OverworldRules.leave_site_recruits(session, prompt.context)
	_check(bool(left.get("ok", false)) and OverworldRules.site_recruit_overflow_prompt(session).is_empty() and _stacks(session) == army_before, "leaving them clears the offer and keeps the army")
	# Walking away also leaves them.
	node_index = _place_site(session, SITE_ID, "overflow_probe_eyrie_three")
	_fill_army(session, 7, recruits)
	OverworldRules._collect_resource_node_result(session, {"index": node_index, "node": session.overworld.resource_nodes[node_index]})
	var here: Vector2i = OverworldRules.hero_position(session)
	OverworldRules.try_move_along_route(session, [here, here + Vector2i(1, 0)])
	_check(not session.overworld.has(OverworldRules.PENDING_SITE_RECRUITS_KEY), "walking away leaves the troops behind")

func _ai_section(session) -> void:
	var site := ContentService.get_resource_site(SITE_ID)
	var recruits: Dictionary = OverworldRules._resource_site_claim_recruits(site)
	var unit_ids := recruits.keys()
	unit_ids.sort()
	var stacks := []
	for unit_id in _unit_ids_excluding(6, recruits):
		stacks.append({"unit_id": unit_id, "count": 3})
	var raid := {"id": "overflow_probe_raid", "placement_id": "overflow_probe_raid", "encounter_id": "encounter_cliffhawk_roost_watch", "enemy_army": {"id": "overflow_probe_raid", "name": "Raid Host", "stacks": stacks}}
	var applied: Dictionary = EnemyAdventureRules._apply_resource_site_claim_recruits_to_raid(session, "faction_sunvault", raid, site)
	var raid_stacks: Array = applied.get("raid", {}).get("enemy_army", {}).get("stacks", [])
	_check(bool(applied.get("applied", false)) and raid_stacks.size() == 7 and applied.get("recruits", {}).size() == 1, "an AI army with one free slot takes the troops that fit (%d stacks)" % raid_stacks.size())

# --- overworld dialog ------------------------------------------------------------

func _dialog_section(session) -> void:
	var recruits: Dictionary = OverworldRules._resource_site_claim_recruits(ContentService.get_resource_site(SITE_ID))
	var node_index := _place_site(session, SITE_ID, "overflow_probe_eyrie_dialog")
	_fill_army(session, 7, recruits)
	OverworldRules._collect_resource_node_result(session, {"index": node_index, "node": session.overworld.resource_nodes[node_index]})
	# The offer is in the session, so a freshly opened overworld (a reload)
	# shows it.
	session.game_state = "overworld"
	session = SessionState.set_active_session(session)
	var shell = OverworldShellScene.instantiate()
	add_child(shell)
	await _frames(10)
	var dialog: Dictionary = shell.validation_site_recruit_dialog()
	_check(bool(dialog.get("open", false)) and dialog.get("slots", []).size() == 7 and int(dialog.get("waiting", 0)) == 2, "the overworld opens the dismiss-or-leave dialog: %s" % dialog)
	_check(String(shell.call("_overworld_gameplay_movement_blocked_reason")) == "site_recruit_dialog_open", "the dialog holds movement until it is answered")
	var slot := int(dialog.slots[0])
	shell.validation_site_recruit_choose(slot)
	await _frames(8)
	dialog = shell.validation_site_recruit_dialog()
	_check(bool(dialog.get("open", false)) and int(dialog.get("waiting", 0)) == 1, "after one dismissal the dialog offers the remaining troops")
	shell.validation_site_recruit_leave()
	await _frames(6)
	_check(not bool(shell.validation_site_recruit_dialog().get("open", false)) and OverworldRules.site_recruit_overflow_prompt(session).is_empty(), "Leave them closes the dialog and the offer")
	var reason := String(shell.call("_overworld_gameplay_movement_blocked_reason"))
	# A level-up earned from the claims waits for this dialog, then opens.
	_check(reason in ["", "hero_level_up_open"], "the dialog no longer holds movement (%s)" % reason)
	shell.queue_free()
	await _frames(2)

func _gate_prompt_section(session) -> void:
	var site := ContentService.get_resource_site(GATE_SITE_ID)
	var node_index := _place_site(session, GATE_SITE_ID, "overflow_probe_gate")
	var prompt: Dictionary = OverworldRules._route_lock_prompt(session, session.overworld.resource_nodes[node_index], site)
	var choice: Dictionary = prompt.get("reward_choice", {})
	_check(String(choice.get("choices", [{}])[0].get("label", "")) == "Claim" and String(prompt.get("message", "")).contains("Claim it to open the way"), "a free reward gate asks to claim, not to pay nothing")
	_check(String(choice.get("instruction", "")).contains("gold"), "the gate prompt names the reward")

# --- helpers -----------------------------------------------------------------

func _start_session():
	var config := ScenarioSelectRulesScript.build_random_map_player_config(SEED, "", "", 2, "land", false, "homm3_small", ScenarioSelectRulesScript.RANDOM_MAP_TEMPLATE_SELECTION_MODE_SIZE_DEFAULT, "faction_embercourt", "hero_caelen")
	var setup := ScenarioSelectRulesScript.build_random_map_skirmish_setup_with_retry(config, "normal", ScenarioSelectRulesScript.RANDOM_MAP_PLAYER_RETRY_POLICY)
	if not bool(setup.get("ok", false)):
		_check(false, "small generated setup: %s" % JSON.stringify(setup).left(300))
		return null
	var session = ScenarioSelectRulesScript.start_random_map_skirmish_session_from_setup(setup)
	OverworldRules.normalize_overworld_state(session)
	return SessionState.set_active_session(session)

## A fresh, unguarded copy of the site under the hero, as a claim test fixture.
func _place_site(session, site_id: String, placement_id: String) -> int:
	var here: Vector2i = OverworldRules.hero_position(session)
	var nodes: Array = session.overworld.get("resource_nodes", []).filter(func(entry): return not (entry is Dictionary and int(entry.get("x", -1)) == here.x and int(entry.get("y", -1)) == here.y))
	nodes.append({"placement_id": placement_id, "site_id": site_id, "x": here.x, "y": here.y, "collected": false})
	session.overworld["resource_nodes"] = nodes
	OverworldRules.invalidate_spatial_lookup(session)
	return nodes.size() - 1

func _fill_army(session, stack_count: int, avoid: Dictionary) -> void:
	var stacks := []
	var index := 0
	for unit_id in _unit_ids_excluding(stack_count, avoid):
		stacks.append({"unit_id": unit_id, "count": 5 + index, "slot_index": index})
		index += 1
	var hero: Dictionary = session.overworld.hero
	var army: Dictionary = hero.get("army", {}).duplicate(true)
	army["stacks"] = stacks
	hero["army"] = army
	session.overworld["hero"] = hero
	session.overworld["army"] = army
	HeroCommandRules.commit_active_hero(session)

func _unit_ids_excluding(count: int, avoid: Dictionary) -> Array:
	var ids := []
	for unit in ContentService.load_json("res://content/units.json").get("items", []):
		var unit_id := String(unit.get("id", ""))
		if unit_id != "" and not avoid.has(unit_id) and not unit_id.begins_with("unit_neutral"):
			ids.append(unit_id)
		if ids.size() >= count:
			break
	return ids

func _stacks(session) -> Array:
	return session.overworld.get("hero", {}).get("army", {}).get("stacks", [])

func _hero_record_stacks(session) -> int:
	for hero in session.overworld.get("player_heroes", []):
		if String(hero.get("id", "")) == String(session.overworld.get("active_hero_id", "")):
			return hero.get("army", {}).get("stacks", []).size()
	return -1

func _has_unit(session, unit_id: String) -> bool:
	return _stacks(session).any(func(stack): return String(stack.get("unit_id", "")) == unit_id)

func _unit_slot(session, unit_id: String) -> int:
	for stack in _stacks(session):
		if String(stack.get("unit_id", "")) == unit_id:
			return int(stack.get("slot_index", -1))
	return -1

func _finish() -> void:
	var report := {"ok": _failures.is_empty(), "checks": _checks, "failures": _failures}
	print("%s %s" % [REPORT_ID, JSON.stringify(report)])
	get_tree().quit(0 if _failures.is_empty() else 1)
