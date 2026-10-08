extends Node
## Battle stat scaling (owner review 2026-10-08: spell power, the attack and
## defense caps and big-stack cohesion felt wrong). Checks the attack/defense
## curve, its use for hero attack in a battle on a generated small map,
## proportional cohesion loss, level-up growth by command path, and spell
## damage and durations scaling with power.

const ScenarioSelectRulesScript = preload("res://scripts/core/ScenarioSelectRules.gd")
const DamageRules = preload("res://scripts/core/BattleDamageRules.gd")
const REPORT_ID := "BATTLE_STAT_SCALING_REPORT"
const SEED := "battle-stat-scaling-20261008"

var _checks := 0
var _failures := []

func _ready() -> void:
	call_deferred("_run")

func _check(condition: bool, label: String) -> void:
	_checks += 1
	if not condition:
		_failures.append(label)
		push_error("%s check failed: %s" % [REPORT_ID, label])

func _near(value: float, expected: float) -> bool:
	return absf(value - expected) < 0.0001

func _run() -> void:
	_check_curve()
	_check_battle_hero_attack()
	_check_cohesion()
	_check_level_growth()
	_check_spells()
	var report := {"ok": _failures.is_empty(), "checks": _checks, "failures": _failures}
	print("%s %s" % [REPORT_ID, JSON.stringify(report)])
	get_tree().quit(0 if _failures.is_empty() else 1)

func _check_curve() -> void:
	var cases := [[10, 10, 1.0], [18, 10, 1.4], [30, 10, 2.0], [70, 10, 4.0], [200, 0, 4.0], [10, 18, 0.8], [10, 30, 0.5], [10, 38, 0.3], [0, 90, 0.3]]
	for entry in cases:
		var value := DamageRules.attack_defense_multiplier(int(entry[0]), int(entry[1]))
		_check(_near(value, float(entry[2])), "attack %d vs defense %d gives x%.3f (got x%.3f)" % [entry[0], entry[1], entry[2], value])

## Hero attack reaches the damage of a real battle on a generated map through
## the curve, past the old 8-point cap.
func _check_battle_hero_attack() -> void:
	var config := ScenarioSelectRulesScript.build_random_map_player_config(SEED, "", "", 2, "land", false, "homm3_small", ScenarioSelectRulesScript.RANDOM_MAP_TEMPLATE_SELECTION_MODE_SIZE_DEFAULT, "faction_embercourt", "hero_caelen")
	var setup := ScenarioSelectRulesScript.build_random_map_skirmish_setup_with_retry(config, "normal", ScenarioSelectRulesScript.RANDOM_MAP_PLAYER_RETRY_POLICY)
	_check(bool(setup.get("ok", false)), "small generated setup")
	if not bool(setup.get("ok", false)):
		return
	var session = ScenarioSelectRulesScript.start_random_map_skirmish_session_from_setup(setup)
	OverworldRules.normalize_overworld_state(session)
	var encounters: Array = session.overworld.get("encounters", [])
	_check(not encounters.is_empty(), "generated map has a guard to fight")
	if encounters.is_empty():
		return
	var battle := BattleRules.create_battle_payload(session, encounters[0])
	var attacker: Dictionary = {}
	var defender: Dictionary = {}
	for stack in battle.get("stacks", []):
		if attacker.is_empty() and String(stack.get("side", "")) == "player":
			attacker = stack
		if defender.is_empty() and String(stack.get("side", "")) == "enemy":
			defender = stack
	_check(not attacker.is_empty() and not defender.is_empty(), "battle has both sides")
	if attacker.is_empty() or defender.is_empty():
		return
	var hero: Dictionary = battle.get("player_hero", {}).duplicate(true)
	hero["attack"] = 0
	battle["player_hero"] = hero
	var low := BattleRules._damage_modifier(attacker, defender, battle, false)
	var attack := BattleRules._stack_attack_total(attacker, battle) + int(BattleRules._hero_payload_for_side(battle, "player").get("attack", 0))
	var defense := BattleRules._stack_defense_total(defender, battle) + int(BattleRules._hero_payload_for_side(battle, "enemy").get("defense", 0))
	hero = hero.duplicate(true)
	hero["attack"] = 20
	battle["player_hero"] = hero
	var high := BattleRules._damage_modifier(attacker, defender, battle, false)
	var expected := DamageRules.attack_defense_multiplier(attack + 20, defense) / DamageRules.attack_defense_multiplier(attack, defense)
	_check(low > 0.0 and _near(high / low, expected), "20 hero attack scales %s against %s by x%.3f (got x%.3f)" % [attacker.get("name", ""), defender.get("name", ""), expected, high / low if low > 0.0 else 0.0])
	_check(high / low > 1.4, "20 hero attack is worth more than the old 8-point cap (x%.3f)" % (high / low if low > 0.0 else 0.0))

func _stack(count: int, unit_hp: int) -> Dictionary:
	return {"battle_id": "s", "side": "enemy", "unit_hp": unit_hp, "base_count": count, "total_health": count * unit_hp}

func _after(stack: Dictionary, lost_health: int) -> Dictionary:
	var after := stack.duplicate(true)
	after["total_health"] = maxi(0, int(stack.total_health) - lost_health)
	return after

func _check_cohesion() -> void:
	var horde := _stack(200, 5)
	_check(BattleRules._casualty_cohesion_shift(horde, _after(horde, 10)) == 0, "two of two hundred lost: no cohesion loss")
	_check(BattleRules._casualty_cohesion_shift(horde, _after(horde, 200)) == -1, "a fifth of a horde lost: -1")
	_check(BattleRules._casualty_cohesion_shift(horde, _after(horde, 500)) == -2, "half of a horde lost: -2")
	var giants := _stack(3, 100)
	_check(BattleRules._casualty_cohesion_shift(giants, _after(giants, 100)) == -1, "one of three lost: -1")
	_check(BattleRules._casualty_cohesion_shift(giants, _after(giants, 200)) == -2, "two of three lost: -2")
	_check(BattleRules._casualty_cohesion_shift(giants, _after(giants, 300)) == -3, "stack destroyed: -3")
	_check(BattleRules._casualty_cohesion_shift(giants, _after(giants, 40)) == 0, "a scratch on one giant: no loss")

func _grown(hero_id: String, level: int, drop_path: bool = false) -> Dictionary:
	var hero := HeroCommandRules.build_hero_from_template(ContentService.get_hero(hero_id), {}, {}, "normal")
	if drop_path:
		hero.erase("command_path")
	return HeroProgressionRules.advance_to_level(hero, level)

func _gains(hero_id: String, hero: Dictionary) -> Dictionary:
	var start: Dictionary = ContentService.get_hero(hero_id).get("command", {})
	var result := {}
	for stat in ["attack", "defense", "power", "knowledge"]:
		result[stat] = int(hero.get("command", {}).get(stat, 0)) - int(start.get(stat, 0))
	return result

func _check_level_growth() -> void:
	var might := _gains("hero_caelen", _grown("hero_caelen", 12))
	_check(might == {"attack": 5, "defense": 4, "power": 1, "knowledge": 1}, "might hero, 11 level-ups: %s" % might)
	var magic := _gains("hero_lyra", _grown("hero_lyra", 12))
	_check(magic == {"attack": 1, "defense": 1, "power": 5, "knowledge": 4}, "magic hero, 11 level-ups: %s" % magic)
	var old_save := _gains("hero_lyra", _grown("hero_lyra", 12, true))
	_check(old_save == magic, "a hero saved without command_path follows its template's path: %s" % old_save)
	var lyra := _grown("hero_lyra", 12)
	var mana_max := int(SpellRules.mana_state(lyra).get("max", 0))
	_check(mana_max == SpellRules.mana_max_from_command(lyra.get("command", {})) + HeroProgressionRules.mana_max_bonus(lyra), "mana follows the knowledge gained (%d)" % mana_max)
	var fresh := HeroCommandRules.build_hero_from_template(ContentService.get_hero("hero_lyra"), {}, {}, "normal")
	fresh = HeroProgressionRules.add_experience(fresh, HeroProgressionRules.experience_for_level(3)).get("hero", fresh)
	var summary := HeroProgressionRules.level_up_summary(fresh)
	_check(summary.get("command_gains", {}) == {"attack": 0, "defense": 0, "power": 1, "knowledge": 1}, "level-up popup shows a magic hero's gains: %s" % summary.get("command_gains", {}))

func _caster(power: int, spell_ids: Array) -> Dictionary:
	return SpellRules.ensure_hero_spellbook({
		"name": "Scaling Caster",
		"command": {"attack": 0, "defense": 0, "power": power, "knowledge": 10},
		"spellbook": {"known_spell_ids": spell_ids, "mana": {"current": 48, "max": 48}},
	})

func _spell_stack(id: String, side: String) -> Dictionary:
	return {"battle_id": id, "side": side, "name": id, "unit_id": "", "unit_hp": 10, "base_count": 100, "total_health": 1000, "effects": [], "abilities": []}

func _check_spells() -> void:
	var battle := {"round": 1, "distance": 1, "stacks": [_spell_stack("ally", "player"), _spell_stack("foe", "enemy")]}
	var ally: Dictionary = battle.stacks[0]
	var foe: Dictionary = battle.stacks[1]
	var burst := ContentService.get_spell("spell_cinder_burst")
	var scale := int(burst.get("effect", {}).get("power_scale", 0))
	_check(scale == 18, "Cinder Burst gains 18 damage per power (got %d)" % scale)
	var weak := SpellRules.resolve_battle_spell(_caster(0, ["spell_cinder_burst"]), battle, ally, foe, "spell_cinder_burst")
	var strong := SpellRules.resolve_battle_spell(_caster(8, ["spell_cinder_burst"]), battle, ally, foe, "spell_cinder_burst")
	_check(int(strong.get("raw_damage", 0)) - int(weak.get("raw_damage", 0)) == 8 * scale, "8 power adds %d damage (got %d)" % [8 * scale, int(strong.get("raw_damage", 0)) - int(weak.get("raw_damage", 0))])
	var base_rounds := int(ContentService.get_spell("spell_lantern_phalanx").get("effect", {}).get("duration_rounds", 1))
	for entry in [[0, 0], [3, 0], [4, 1], [8, 2], [12, 3], [40, 3]]:
		var cast := SpellRules.resolve_battle_spell(_caster(int(entry[0]), ["spell_lantern_phalanx"]), battle, ally, ally, "spell_lantern_phalanx")
		var rounds := int(cast.get("effect", {}).get("expires_after_round", 0))
		_check(rounds == base_rounds + int(entry[1]), "Lantern Phalanx at power %d lasts %d rounds (got %d)" % [entry[0], base_rounds + int(entry[1]), rounds])
	var rider := SpellRules.resolve_battle_spell(_caster(8, ["spell_cinder_burst"]), battle, ally, foe, "spell_cinder_burst")
	var rider_base := int(burst.get("effect", {}).get("status_effect", {}).get("duration_rounds", 1))
	_check(int(rider.get("post_damage_effect", {}).get("expires_after_round", 0)) == rider_base + 2, "a damage spell's rider lasts longer with power")
	var summary := SpellRules._battle_spell_effect_summary(_caster(8, ["spell_lantern_phalanx"]), ContentService.get_spell("spell_lantern_phalanx"), battle, ally, ally)
	_check(summary.contains("for %d rounds" % (base_rounds + 2)), "the spell summary shows the longer duration: %s" % summary)
