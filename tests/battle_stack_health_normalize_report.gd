extends Node
## Battle stacks keep their creature health through normalization (bug found
## 2026-10-09: normalize_battle_state reset unit_hp to the unit's content hp
## but kept total_health, so Hardened Ranks turned 10 creatures of 12 health
## into 12 of 10 on battle entry and save load, and the extra creatures went
## home with the hero). Checks that entering a battle, normalizing it again and
## reloading it from JSON keep every stack's count and raised creature health,
## that health ratio, healing caps and survivors follow the raised health, and
## that a stack saved without unit_hp takes the content value. The battle
## comes from a generated small map.

const ScenarioSelectRulesScript = preload("res://scripts/core/ScenarioSelectRules.gd")
const REPORT_ID := "BATTLE_STACK_HEALTH_NORMALIZE_REPORT"
const SEED := "battle-stack-health-normalize-20261009"
const HARDENED_RANK := 4
const HARDENED_HEALTH_PCT := 12

var _checks := 0
var _failures := []
var _details := {}

func _ready() -> void:
	call_deferred("_run")

func _check(condition: bool, label: String) -> void:
	_checks += 1
	if not condition:
		_failures.append(label)
		push_error("%s check failed: %s" % [REPORT_ID, label])

func _run() -> void:
	var session = _session()
	if session != null:
		_check_normalized_counts(session)
	var report := {"ok": _failures.is_empty(), "checks": _checks, "failures": _failures, "details": _details}
	print("%s %s" % [REPORT_ID, JSON.stringify(report)])
	get_tree().quit(0 if _failures.is_empty() else 1)

func _session():
	var config := ScenarioSelectRulesScript.build_random_map_player_config(SEED, "", "", 2, "land", false, "homm3_small", ScenarioSelectRulesScript.RANDOM_MAP_TEMPLATE_SELECTION_MODE_SIZE_DEFAULT, "faction_embercourt", "hero_caelen")
	var setup := ScenarioSelectRulesScript.build_random_map_skirmish_setup_with_retry(config, "normal", ScenarioSelectRulesScript.RANDOM_MAP_PLAYER_RETRY_POLICY)
	_check(bool(setup.get("ok", false)), "small generated setup")
	if not bool(setup.get("ok", false)):
		return null
	var session = ScenarioSelectRulesScript.start_random_map_skirmish_session_from_setup(setup)
	var adoption: Dictionary = session.overworld.get("native_random_map_package_session_adoption", {})
	_details["map_package_path"] = String(adoption.get("map_package_path", ""))
	OverworldRules.normalize_overworld_state(session)
	var hero: Dictionary = session.overworld.get("hero", {})
	var specialties := []
	for index in range(HARDENED_RANK):
		specialties.append("hardened")
	hero["specialties"] = specialties
	session.overworld["hero"] = hero
	HeroCommandRules.commit_active_hero(session)
	var encounters: Array = session.overworld.get("encounters", [])
	_check(not encounters.is_empty(), "generated map has a guard to fight")
	if encounters.is_empty():
		return null
	session.battle = BattleRules.create_battle_payload(session, encounters[0])
	_check(not session.battle.is_empty(), "battle payload built")
	if session.battle.is_empty():
		return null
	return session

func _check_normalized_counts(session) -> void:
	var started := _snapshot(session.battle)
	var player_ids := []
	for battle_id in started:
		var stack: Dictionary = started[battle_id]
		var content_hp := maxi(1, int(ContentService.get_unit(String(stack.unit_id)).get("hp", 1)))
		if String(stack.side) == "player":
			player_ids.append(battle_id)
			var raised := content_hp + maxi(1, content_hp * HARDENED_HEALTH_PCT / 100)
			_check(int(stack.unit_hp) == raised, "Hardened Ranks IV raises %s to %d health a creature (%d from %d)" % [battle_id, raised, int(stack.unit_hp), content_hp])
		else:
			_check(int(stack.unit_hp) == content_hp, "%s keeps its content health %d (%d)" % [battle_id, content_hp, int(stack.unit_hp)])
		_check(int(stack.count) == int(stack.base_count) and int(stack.count) > 0, "%s starts with its whole stack (%d of %d)" % [battle_id, int(stack.count), int(stack.base_count)])
	_check(not player_ids.is_empty(), "the hero brings stacks to the battle")
	_details["started"] = started

	# Battle entry (BattleShell) and a second pass must not change the stacks.
	_check(BattleRules.normalize_battle_state(session), "battle state normalizes on entry")
	_check_same_stacks(session.battle, started, "on entry")
	_check(BattleRules.normalize_battle_state(session), "battle state normalizes a second time")
	_check_same_stacks(session.battle, started, "normalized twice")

	# A save stores the battle as JSON and normalizes it on load.
	session.battle = JSON.parse_string(JSON.stringify(session.battle))
	_check(BattleRules.normalize_battle_state(session), "battle state normalizes after a JSON reload")
	_check_same_stacks(session.battle, started, "after a JSON reload")

	var survivors := 0
	for survivor in BattleRules._battle_survivor_stacks(session, "player"):
		survivors += int(survivor.get("count", 0))
	var deployed := 0
	for battle_id in player_ids:
		deployed += int(started[battle_id].base_count)
	_check(survivors == deployed, "an untouched army goes home with %d creatures, no more (%d)" % [deployed, survivors])

	if not player_ids.is_empty():
		_check_wounded_stack(session, String(player_ids[0]), started[player_ids[0]])
		_check_stack_without_unit_hp(String(player_ids[0]), started[player_ids[0]])

func _check_wounded_stack(session, battle_id: String, started: Dictionary) -> void:
	var unit_hp := int(started.unit_hp)
	var full_health := int(started.base_count) * unit_hp
	# The top creature keeps 1 health, so no creature dies.
	var wound := unit_hp - 1
	BattleRules._apply_damage_to_stack(session.battle, battle_id, wound)
	session.battle = JSON.parse_string(JSON.stringify(session.battle))
	_check(BattleRules.normalize_battle_state(session), "wounded battle normalizes after a JSON reload")
	var stack := BattleRules._get_stack_by_id(session.battle, battle_id)
	_check(int(stack.get("unit_hp", 0)) == unit_hp and int(stack.get("total_health", 0)) == full_health - wound, "wounded %s keeps %d health a creature and %d health (%d / %d)" % [battle_id, unit_hp, full_health - wound, int(stack.get("unit_hp", 0)), int(stack.get("total_health", 0))])
	_check(BattleRules._alive_count(stack) == int(started.base_count), "wounded %s keeps all %d creatures (%d)" % [battle_id, int(started.base_count), BattleRules._alive_count(stack)])
	_check(is_equal_approx(BattleRules._health_ratio(stack), float(full_health - wound) / float(full_health)), "wounded %s health ratio uses the raised maximum %d (%.4f)" % [battle_id, full_health, BattleRules._health_ratio(stack)])
	_check(SpellRules.battle_spell_recoverable_health(stack) == wound, "healing can restore the wounded creature's %d raised health (%d)" % [wound, SpellRules.battle_spell_recoverable_health(stack)])
	var restored := BattleRules._restore_stack_health(session.battle, battle_id, full_health)
	stack = BattleRules._get_stack_by_id(session.battle, battle_id)
	_check(restored == wound and int(stack.get("total_health", 0)) == full_health, "healing stops at the raised maximum %d (restored %d, health %d)" % [full_health, restored, int(stack.get("total_health", 0))])
	_check(is_equal_approx(BattleRules._health_ratio(stack), 1.0), "healed %s is back to full health (%.4f)" % [battle_id, BattleRules._health_ratio(stack)])

func _check_stack_without_unit_hp(battle_id: String, started: Dictionary) -> void:
	var content_hp := maxi(1, int(ContentService.get_unit(String(started.unit_id)).get("hp", 1)))
	var legacy := {"battle_id": battle_id, "side": started.side, "unit_id": started.unit_id, "base_count": started.base_count, "total_health": int(started.base_count) * content_hp}
	var normalized := BattleRules._normalize_stack(legacy)
	_check(int(normalized.get("unit_hp", 0)) == content_hp and BattleRules._alive_count(normalized) == int(started.base_count), "%s saved without unit_hp takes content health %d and keeps %d creatures (%d, %d)" % [battle_id, content_hp, int(started.base_count), int(normalized.get("unit_hp", 0)), BattleRules._alive_count(normalized)])

func _check_same_stacks(battle: Dictionary, started: Dictionary, when: String) -> void:
	var now := _snapshot(battle)
	_check(now.keys().size() == started.keys().size(), "%s: the same %d stacks (%d)" % [when, started.keys().size(), now.keys().size()])
	for battle_id in started:
		var before: Dictionary = started[battle_id]
		var after: Dictionary = now.get(battle_id, {})
		_check(int(after.get("count", -1)) == int(before.count), "%s: %s keeps %d creatures (%d)" % [when, battle_id, int(before.count), int(after.get("count", -1))])
		_check(int(after.get("unit_hp", -1)) == int(before.unit_hp), "%s: %s keeps %d health a creature (%d)" % [when, battle_id, int(before.unit_hp), int(after.get("unit_hp", -1))])
		_check(int(after.get("total_health", -1)) == int(before.total_health), "%s: %s keeps %d health (%d)" % [when, battle_id, int(before.total_health), int(after.get("total_health", -1))])
		_check(is_equal_approx(float(after.get("health_ratio", -1.0)), 1.0), "%s: %s is at full health (%.4f)" % [when, battle_id, float(after.get("health_ratio", -1.0))])

func _snapshot(battle: Dictionary) -> Dictionary:
	var stacks := {}
	for stack in battle.get("stacks", []):
		if not (stack is Dictionary):
			continue
		stacks[String(stack.get("battle_id", ""))] = {
			"side": String(stack.get("side", "")),
			"unit_id": String(stack.get("unit_id", "")),
			"base_count": int(stack.get("base_count", 0)),
			"count": BattleRules._alive_count(stack),
			"unit_hp": int(stack.get("unit_hp", 0)),
			"total_health": int(stack.get("total_health", 0)),
			"health_ratio": BattleRules._health_ratio(stack),
		}
	return stacks
