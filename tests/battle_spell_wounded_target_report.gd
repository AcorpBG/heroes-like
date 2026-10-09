extends Node
## Spell rules measure battle stacks the way battle rules do (bug found
## 2026-10-09: SpellRules read an army "count" that battle stacks never have,
## so a stack with one whole creature left counted as unhurt and the nine
## spells with a wounded-target bonus almost never dealt it, and the living
## stacks behind spell hints were always none). Checks the health ratio, the
## Cinder Burst wounded bonus in damage and in its summary, and the living
## stacks and abilities of a side, on a battle from a generated small map.

const ScenarioSelectRulesScript = preload("res://scripts/core/ScenarioSelectRules.gd")
const REPORT_ID := "BATTLE_SPELL_WOUNDED_TARGET_REPORT"
const SEED := "battle-spell-wounded-target-20261009"
const SPELL_ID := "spell_cinder_burst"

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
	var battle := _battle()
	if not battle.is_empty():
		_check_wounded_bonus(battle.duplicate(true))
		_check_living_stacks(battle.duplicate(true))
	var report := {"ok": _failures.is_empty(), "checks": _checks, "failures": _failures, "details": _details}
	print("%s %s" % [REPORT_ID, JSON.stringify(report)])
	get_tree().quit(0 if _failures.is_empty() else 1)

func _battle() -> Dictionary:
	var config := ScenarioSelectRulesScript.build_random_map_player_config(SEED, "", "", 2, "land", false, "homm3_small", ScenarioSelectRulesScript.RANDOM_MAP_TEMPLATE_SELECTION_MODE_SIZE_DEFAULT, "faction_embercourt", "hero_caelen")
	var setup := ScenarioSelectRulesScript.build_random_map_skirmish_setup_with_retry(config, "normal", ScenarioSelectRulesScript.RANDOM_MAP_PLAYER_RETRY_POLICY)
	_check(bool(setup.get("ok", false)), "small generated setup")
	if not bool(setup.get("ok", false)):
		return {}
	var session = ScenarioSelectRulesScript.start_random_map_skirmish_session_from_setup(setup)
	var adoption: Dictionary = session.overworld.get("native_random_map_package_session_adoption", {})
	_details["map_package_path"] = String(adoption.get("map_package_path", ""))
	OverworldRules.normalize_overworld_state(session)
	var encounters: Array = session.overworld.get("encounters", [])
	_check(not encounters.is_empty(), "generated map has a guard to fight")
	if encounters.is_empty():
		return {}
	var battle := BattleRules.create_battle_payload(session, encounters[0])
	_check(_stacks(battle, "enemy").size() >= 1 and _stacks(battle, "player").size() >= 1, "both sides bring stacks")
	return battle

func _stacks(battle: Dictionary, side: String) -> Array:
	var stacks := []
	for stack in battle.get("stacks", []):
		if stack is Dictionary and String(stack.get("side", "")) == side:
			stacks.append(stack)
	return stacks

func _check_wounded_bonus(battle: Dictionary) -> void:
	var spell := ContentService.get_spell(SPELL_ID)
	var effect: Dictionary = spell.get("effect", {})
	var bonus := int(effect.get("wounded_bonus_damage", 0))
	var threshold := float(effect.get("wounded_threshold_ratio", 0.5))
	_check(bonus > 0 and threshold > 0.0 and threshold < 1.0, "%s has a wounded bonus %d below %.2f health" % [SPELL_ID, bonus, threshold])
	# A commander with no specialties or artifacts: the bonus adds exactly.
	var hero := {"command": {"power": 2}}
	var active: Dictionary = _stacks(battle, "player")[0]
	var target: Dictionary = {}
	for stack in _stacks(battle, "enemy"):
		if int(stack.get("base_count", 0)) >= 2:
			target = stack.duplicate(true)
			break
	_check(not target.is_empty(), "an enemy stack has at least two creatures")
	if target.is_empty():
		return
	var unit_hp := maxi(1, int(target.get("unit_hp", 1)))
	var full_health := int(target.get("base_count", 0)) * unit_hp
	_details["target"] = {"battle_id": target.get("battle_id", ""), "base_count": target.get("base_count", 0), "unit_hp": unit_hp}
	var plain := SpellRules._battle_spell_damage(hero, spell, target)

	_check(is_equal_approx(SpellRules._health_ratio(target), 1.0), "an unhurt stack is at full health (%.4f)" % SpellRules._health_ratio(target))
	_check(not SpellRules._wounded_bonus_applies(effect, target), "an unhurt stack gets no wounded bonus")
	_check(not SpellRules._battle_spell_effect_summary(hero, spell, battle, active, target).contains("wounded target bonus"), "the unhurt summary has no wounded bonus")

	# Down to about 40%: several whole creatures still stand.
	var wounded := target.duplicate(true)
	wounded["total_health"] = int(ceil(float(full_health) * 0.4))
	var ratio := float(wounded.total_health) / float(full_health)
	_check(BattleRules._alive_count(wounded) >= 1 and is_equal_approx(SpellRules._health_ratio(wounded), BattleRules._health_ratio(wounded)), "spell and battle rules agree on a wounded stack's health (%.4f / %.4f)" % [SpellRules._health_ratio(wounded), BattleRules._health_ratio(wounded)])
	_check(is_equal_approx(SpellRules._health_ratio(wounded), ratio), "a stack at %d of %d health is at %.4f (%.4f)" % [int(wounded.total_health), full_health, ratio, SpellRules._health_ratio(wounded)])
	_check(SpellRules._wounded_bonus_applies(effect, wounded), "a stack at %.0f%% health gets the wounded bonus" % (ratio * 100.0))
	var hurt := SpellRules._battle_spell_damage(hero, spell, wounded)
	_check(hurt == plain + bonus, "%s deals %d to the wounded stack, %d + %d (%d)" % [SPELL_ID, plain + bonus, plain, bonus, hurt])
	_check(SpellRules._battle_spell_effect_summary(hero, spell, battle, active, wounded).contains("wounded target bonus"), "the wounded summary names the bonus")

	# Just above the threshold: no bonus yet.
	var scratched := target.duplicate(true)
	scratched["total_health"] = int(floor(float(full_health) * threshold)) + unit_hp
	_check(not SpellRules._wounded_bonus_applies(effect, scratched) and SpellRules._battle_spell_damage(hero, spell, scratched) == plain, "a stack above %.0f%% health gets no bonus (%.4f)" % [threshold * 100.0, SpellRules._health_ratio(scratched)])
	_details["damage"] = {"plain": plain, "wounded": hurt}

func _check_living_stacks(battle: Dictionary) -> void:
	var enemies := _stacks(battle, "enemy")
	var living := SpellRules._alive_stacks_for_side(battle, "enemy")
	_check(living.size() == enemies.size(), "all %d enemy stacks are living (%d)" % [enemies.size(), living.size()])
	var stacks: Array = battle.get("stacks", [])
	for index in range(stacks.size()):
		if String(stacks[index].get("battle_id", "")) == String(enemies[0].get("battle_id", "")):
			stacks[index]["total_health"] = 0
	battle["stacks"] = stacks
	_check(SpellRules._alive_stacks_for_side(battle, "enemy").size() == enemies.size() - 1, "a destroyed stack is not living")
	var ability_id := ""
	for stack in _stacks(battle, "player"):
		for ability in stack.get("abilities", []):
			if ability is Dictionary and String(ability.get("id", "")) != "":
				ability_id = String(ability.get("id", ""))
				break
		if ability_id != "":
			break
	_details["player_ability"] = ability_id
	if ability_id != "":
		_check(SpellRules._side_has_any_ability(battle, "player", [ability_id]), "the player side has %s" % ability_id)
	_check(not SpellRules._side_has_any_ability(battle, "player", ["no_such_ability"]), "no side has a missing ability")
