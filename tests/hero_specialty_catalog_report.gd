extends Node
## Hero specialty catalog (owner request 2026-10-08: four ranks and many more
## specialties; six per hero). Checks the 35-specialty catalog and its icons,
## rank bonuses, the six-specialty limit, level-up offers (an upgrade and a
## new one, seeded, leaning to the hero's path), the computer's picks, and the
## effect of every new specialty on the rules it changes, including a battle
## on a generated small map.

const ScenarioSelectRulesScript = preload("res://scripts/core/ScenarioSelectRules.gd")
const DamageRules = preload("res://scripts/core/BattleDamageRules.gd")
const REPORT_ID := "HERO_SPECIALTY_CATALOG_REPORT"
const SEED := "hero-specialty-catalog-20261008"

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
	_check_catalog()
	_check_ranks_and_limit()
	_check_offers()
	_check_adventure_effects()
	_check_magic_effects()
	_check_battle_effects()
	var report := {"ok": _failures.is_empty(), "checks": _checks, "failures": _failures, "details": _details}
	print("%s %s" % [REPORT_ID, JSON.stringify(report)])
	get_tree().quit(0 if _failures.is_empty() else 1)

func _hero(hero_id: String, specialties: Array = [], growth_seed: String = "catalog") -> Dictionary:
	var hero := HeroCommandRules.build_hero_from_template(ContentService.get_hero(hero_id), {}, {}, "normal")
	hero["growth_seed"] = growth_seed
	hero["specialties"] = specialties.duplicate()
	hero["pending_specialty_choices"] = []
	return hero

func _ranked(entries: Dictionary) -> Array:
	var list := []
	for specialty_id in entries:
		for index in range(int(entries[specialty_id])):
			list.append(specialty_id)
	return list

func _check_catalog() -> void:
	var items := HeroProgressionRules.specialties()
	_check(items.size() == 35, "35 specialties (%d)" % items.size())
	var groups := {}
	for item in items:
		var specialty_id := String(item.get("id", ""))
		groups[String(item.get("group", ""))] = int(groups.get(String(item.get("group", "")), 0)) + 1
		_check(HeroProgressionRules.max_rank_for_specialty(specialty_id) == 4, "%s has four ranks" % specialty_id)
		var texts_ok := true
		for rank in range(1, 5):
			texts_ok = texts_ok and HeroProgressionRules.rank_text(specialty_id, rank) != ""
		_check(texts_ok, "%s describes each rank" % specialty_id)
		var texture := HeroProgressionRules.specialty_insignia_texture(specialty_id)
		_check(texture != null and texture.get_size() == Vector2(28, 28), "%s has its insignia" % specialty_id)
	_check(groups == {"adventure": 9, "command": 12, "magic": 14}, "groups: %s" % groups)
	_check(HeroProgressionRules.rank_label(4) == "IV", "rank IV label")

func _check_ranks_and_limit() -> void:
	for entry in [[1, 1], [2, 2], [3, 4], [4, 6]]:
		var hero := _hero("hero_caelen", _ranked({"wayfinder": entry[0]}))
		_check(int(HeroProgressionRules.aggregate_bonuses(hero).get("overworld_movement", 0)) == int(entry[1]), "Wayfinder %s gives +%d movement" % [HeroProgressionRules.rank_label(entry[0]), entry[1]])
	var six := _hero("hero_caelen", ["armsmaster", "vanguard", "marksman", "banner", "fortune", "scholar"])
	var available := HeroProgressionRules.available_specialty_ids(six)
	_check(available.size() == 6 and available.all(func(id): return id in six.specialties), "six held: only upgrades are offered (%s)" % [available])
	var five := _hero("hero_caelen", ["armsmaster", "vanguard", "marksman", "banner", "fortune"])
	_check(HeroProgressionRules.available_specialty_ids(five).size() == 35, "five held: any specialty can be offered")
	var mastered := _hero("hero_caelen", _ranked({"armsmaster": 4}))
	_check(not ("armsmaster" in HeroProgressionRules.available_specialty_ids(mastered)), "a rank IV specialty is not offered again")
	var veteran := HeroProgressionRules.advance_to_level(_hero("hero_lyra", ["spellwright"], "veteran"), 24)
	var distinct := {}
	var max_rank := 0
	for specialty_id in veteran.get("specialties", []):
		distinct[specialty_id] = true
		max_rank = maxi(max_rank, HeroProgressionRules.specialty_rank(veteran, String(specialty_id)))
	var build := {}
	for specialty_id in distinct:
		build[specialty_id] = HeroProgressionRules.specialty_rank(veteran, String(specialty_id))
	_details["level_24_magic_hero"] = build
	_check(distinct.size() <= 6 and max_rank <= 4 and veteran.get("specialties", []).size() == 24, "a level 24 hero holds %d specialties (max rank %d, %d picks)" % [distinct.size(), max_rank, veteran.get("specialties", []).size()])

func _check_offers() -> void:
	var hero := _hero("hero_caelen", ["armsmaster", "vanguard"], "offers")
	var options: Array = HeroProgressionRules._build_choice_group(hero, 4).get("options", [])
	_check(options.size() == 3, "three options")
	_check(options.size() >= 2 and HeroProgressionRules.specialty_rank(hero, String(options[0])) > 0 and HeroProgressionRules.specialty_rank(hero, String(options[1])) == 0, "an upgrade and a new specialty lead the offer: %s" % [options])
	_check(options == HeroProgressionRules._build_choice_group(hero, 4).get("options", []), "the same hero and level offer the same choices")
	var shares := {}
	for hero_id in ["hero_caelen", "hero_lyra"]:
		var counts := {"adventure": 0, "command": 0, "magic": 0}
		var total := 0
		for index in range(150):
			var fresh := _hero(hero_id, [], "offer-share-%d" % index)
			for option in HeroProgressionRules._build_choice_group(fresh, 2).get("options", []):
				total += 1
				counts[String(HeroProgressionRules.specialty_definition(String(option)).get("group", ""))] += 1
		shares[hero_id] = {"command": float(counts.command) / float(maxi(1, total)), "magic": float(counts.magic) / float(maxi(1, total))}
	_details["offer_group_shares"] = shares
	_check(float(shares.hero_caelen.command) > float(shares.hero_lyra.command) + 0.1 and float(shares.hero_lyra.magic) > float(shares.hero_caelen.magic) + 0.1, "offers lean to the hero's path: %s" % shares)
	var commander := _hero("hero_lyra", ["spellwright"], "ai")
	var pick := EnemyAdventureRules._preferred_enemy_specialty_id(commander, {"options": ["ledgerkeeper", "sorcery", "vanguard"]})
	_check(pick == "sorcery", "a magic AI commander picks the magic option (%s)" % pick)
	var focused := EnemyAdventureRules._preferred_enemy_specialty_id(commander, {"options": ["ledgerkeeper", "sorcery", String(commander.get("specialty_focus_ids", ["x"])[0])]})
	_check(focused == String(commander.get("specialty_focus_ids", ["x"])[0]), "an AI commander takes its focus specialty first (%s)" % focused)

func _check_adventure_effects() -> void:
	var trader := _hero("hero_caelen", _ranked({"ledgerkeeper": 4, "prospector": 4, "alchemist": 4}))
	var income: Dictionary = HeroProgressionRules.daily_income_bonus(trader)
	var resources: Dictionary = ContentService.get_faction(String(ContentService.get_hero("hero_caelen").get("faction_id", ""))).get("town_resources", {})
	_check(int(income.get("gold", 0)) == 300 and int(income.get("wood", 0)) == 4 and int(income.get("ore", 0)) == 4, "Ledgerkeeper IV and Prospector IV income: %s" % income)
	_check(int(income.get(String(resources.get("main", "")), 0)) == 3 and int(income.get(String(resources.get("secondary", "")), 0)) == 1, "Alchemist IV pays the faction's rare resources: %s" % income)
	var scholar := _hero("hero_caelen", _ranked({"scholar": 4}))
	scholar = HeroProgressionRules.add_experience(scholar, 200).get("hero", scholar)
	_check(int(scholar.get("experience", 0)) == 240, "Scholar IV: 200 experience becomes 240 (%d)" % int(scholar.get("experience", 0)))
	var reward := OverworldRules.apply_reward_bonus({"gold": 500, "wood": 5, "experience": 100}, 40)
	_check(reward == {"gold": 700, "wood": 7, "experience": 100}, "Plunderer IV: +40%% gold and resources, experience unchanged: %s" % reward)
	var base_move := HeroCommandRules.movement_max_for_hero(_hero("hero_caelen"), "normal")
	var walker := _hero("hero_caelen", _ranked({"wayfinder": 4}))
	_check(HeroCommandRules.movement_max_for_hero(walker, "normal") == base_move + 6, "Wayfinder IV: +6 movement")
	var marcher := _hero("hero_caelen", _ranked({"nightmarch": 3}))
	marcher["movement_carry"] = 3
	_check(HeroCommandRules.movement_max_for_hero(marcher, "normal") == base_move + 3, "Night March: carried movement adds to the day's maximum")
	var captain := _hero("hero_caelen", _ranked({"mustercaptain": 4}))
	var bonuses := HeroProgressionRules.aggregate_bonuses(captain)
	_check(is_equal_approx(float(bonuses.get("recruit_growth_multiplier", 0.0)), 0.4) and is_equal_approx(float(bonuses.get("recruit_cost_delta", 0.0)), -0.2), "Muster Captain IV: +40%% growth, -20%% cost")
	# Tier 7 keeps the town's growth; tiers 1-6 scale.
	var mustered := HeroProgressionRules.scale_recruit_growth(captain, {"unit_embercourt_charter_colossus_veteran": 2, "unit_embercourt_sluicefire_lindworms_veteran": 4})
	_check(int(mustered.get("unit_embercourt_charter_colossus_veteran", 0)) == 2 and int(mustered.get("unit_embercourt_sluicefire_lindworms_veteran", 0)) == 6, "Muster Captain IV: T7 2 stays 2, T6 4 becomes 6: %s" % mustered)
	# Discounts round up: a rank-one captain leaves a 2-resource price at 2.
	var cadet := _hero("hero_caelen", _ranked({"mustercaptain": 1}))
	var price := HeroProgressionRules.scale_recruit_cost(cadet, {"gold": 1891, "embergrain": 2})
	_check(price == {"gold": 1797, "embergrain": 2}, "Muster Captain I: T7 price rounds up: %s" % price)
	_check(HeroProgressionRules.scale_recruit_cost(captain, {"gold": 100, "embergrain": 2}) == {"gold": 80, "embergrain": 2}, "Muster Captain IV: exact discounts stay exact")

func _caster(specialties: Array, power: int = 2) -> Dictionary:
	var hero := _hero("hero_lyra", specialties)
	var command: Dictionary = hero.get("command", {})
	command["power"] = power
	command["knowledge"] = 10
	hero["command"] = command
	hero["spellbook"] = {"known_spell_ids": ["spell_cinder_burst", "spell_lantern_phalanx"], "mana": {"current": 60, "max": 60}}
	return SpellRules.ensure_hero_spellbook(hero)

func _spell_stack(id: String, side: String) -> Dictionary:
	return {"battle_id": id, "side": side, "name": id, "unit_id": "", "unit_hp": 10, "base_count": 100, "total_health": 1000, "effects": [], "abilities": []}

func _check_magic_effects() -> void:
	var battle := {"round": 1, "distance": 1, "stacks": [_spell_stack("ally", "player"), _spell_stack("foe", "enemy")]}
	var ally: Dictionary = battle.stacks[0]
	var foe: Dictionary = battle.stacks[1]
	var plain := _caster([])
	_check(SpellRules.spell_power(_caster(_ranked({"arcanefocus": 4}))) == 6, "Arcane Focus IV: power 2 becomes 6")
	var base_damage := int(SpellRules.resolve_battle_spell(plain, battle, ally, foe, "spell_cinder_burst").get("raw_damage", 0))
	var sorcery_damage := int(SpellRules.resolve_battle_spell(_caster(_ranked({"sorcery": 4})), battle, ally, foe, "spell_cinder_burst").get("raw_damage", 0))
	_check(sorcery_damage == base_damage + base_damage * 20 / 100, "Sorcery IV: +20%% spell damage (%d to %d)" % [base_damage, sorcery_damage])
	var furnace := _caster(_ranked({"mastery_furnace": 4}))
	var furnace_damage := int(SpellRules.resolve_battle_spell(furnace, battle, ally, foe, "spell_cinder_burst").get("raw_damage", 0))
	_check(furnace_damage == base_damage + base_damage * 32 / 100, "Furnace Mastery IV: +32%% on a furnace spell (%d to %d)" % [base_damage, furnace_damage])
	var burst := ContentService.get_spell("spell_cinder_burst")
	_check(SpellRules.adjusted_spell_mana_cost(furnace, burst) == int(burst.get("mana_cost", 0)) - 2, "Furnace Mastery IV: furnace spells cost 2 less")
	var beacon_cost := SpellRules.adjusted_spell_mana_cost(furnace, ContentService.get_spell("spell_lantern_phalanx"))
	_check(beacon_cost == int(ContentService.get_spell("spell_lantern_phalanx").get("mana_cost", 0)), "Furnace Mastery does not discount other schools")
	var rider_base := int(SpellRules.resolve_battle_spell(plain, battle, ally, foe, "spell_cinder_burst").get("post_damage_effect", {}).get("turns_left", 0))
	var weave := _caster(_ranked({"lingeringweave": 4, "mastery_furnace": 3}))
	var rider := int(SpellRules.resolve_battle_spell(weave, battle, ally, foe, "spell_cinder_burst").get("post_damage_effect", {}).get("turns_left", 0))
	_check(rider == rider_base + 3, "Lingering Weave IV (+2) and Furnace Mastery III (+1) lengthen a rider (%d to %d)" % [rider_base, rider])
	var buff_base := int(SpellRules.resolve_battle_spell(plain, battle, ally, ally, "spell_lantern_phalanx").get("effect", {}).get("turns_left", 0))
	var buff := int(SpellRules.resolve_battle_spell(_caster(_ranked({"lingeringweave": 1})), battle, ally, ally, "spell_lantern_phalanx").get("effect", {}).get("turns_left", 0))
	_check(buff == buff_base + 1, "Lingering Weave I lengthens a buff by one round")
	var reserve := _caster(_ranked({"spellwright": 4}))
	_check(HeroProgressionRules.mana_max_bonus(reserve) == 12 and SpellRules.adjusted_spell_mana_cost(reserve, burst) == int(burst.get("mana_cost", 0)) - 2, "Spellwright IV: +12 max mana and spells cost 2 less")
	var payload := BattleRules._hero_payload_from_state(_caster(_ranked({"ward": 4, "ironwill": 4})))
	var knowledge_part := mini(20, 10 * 2)
	_check(int(payload.get("battle_spell_resistance_pct", 0)) == 20 + knowledge_part and int(payload.get("battle_control_resistance_pct", 0)) == 20 + mini(15, 10), "Ward IV and Iron Will IV raise resistances: %s / %s" % [payload.get("battle_spell_resistance_pct", 0), payload.get("battle_control_resistance_pct", 0)])

func _check_battle_effects() -> void:
	var config := ScenarioSelectRulesScript.build_random_map_player_config(SEED, "", "", 2, "land", false, "homm3_small", ScenarioSelectRulesScript.RANDOM_MAP_TEMPLATE_SELECTION_MODE_SIZE_DEFAULT, "faction_embercourt", "hero_caelen")
	var setup := ScenarioSelectRulesScript.build_random_map_skirmish_setup_with_retry(config, "normal", ScenarioSelectRulesScript.RANDOM_MAP_PLAYER_RETRY_POLICY)
	_check(bool(setup.get("ok", false)), "small generated setup")
	if not bool(setup.get("ok", false)):
		return
	var session = ScenarioSelectRulesScript.start_random_map_skirmish_session_from_setup(setup)
	OverworldRules.normalize_overworld_state(session)
	var hero: Dictionary = session.overworld.get("hero", {})
	hero["specialties"] = _ranked({"banner": 4, "fortune": 4, "hardened": 4, "fieldsurgeon": 4, "leychanneler": 4})
	session.overworld["hero"] = hero
	HeroCommandRules.commit_active_hero(session)
	var encounters: Array = session.overworld.get("encounters", [])
	_check(not encounters.is_empty(), "generated map has a guard to fight")
	if encounters.is_empty():
		return
	var battle := BattleRules.create_battle_payload(session, encounters[0])
	var player_stack: Dictionary = {}
	var enemy_stack: Dictionary = {}
	for stack in battle.get("stacks", []):
		if player_stack.is_empty() and String(stack.get("side", "")) == "player":
			player_stack = stack
		if enemy_stack.is_empty() and String(stack.get("side", "")) == "enemy":
			enemy_stack = stack
	var unit := ContentService.get_unit(String(player_stack.get("unit_id", "")))
	var base_cohesion := BattleRules._cohesion_base_for_unit(unit)
	_check(int(player_stack.get("cohesion_base", 0)) == mini(base_cohesion + 4, BattleRules.COHESION_MAX), "Banner of Resolve IV: +4 starting cohesion (%d from %d)" % [int(player_stack.get("cohesion_base", 0)), base_cohesion])
	_check(int(player_stack.get("momentum", 0)) == BattleRules.MOMENTUM_MAX, "Fortune's Favour IV: momentum %d in round 1" % int(player_stack.get("momentum", 0)))
	var hp := int(unit.get("hp", 1))
	_check(int(player_stack.get("unit_hp", 0)) == hp + maxi(1, hp * 12 / 100), "Hardened Ranks IV: creature health %d from %d" % [int(player_stack.get("unit_hp", 0)), hp])
	_check(int(enemy_stack.get("momentum", 0)) == 0, "the enemy side gets none of it")
	# Field Surgeon IV: a fifth of the fallen stand up after a win.
	var lost_battle := battle.duplicate(true)
	var stacks: Array = lost_battle.get("stacks", [])
	for index in range(stacks.size()):
		if String(stacks[index].get("side", "")) == "player":
			var wounded: Dictionary = stacks[index]
			wounded["base_count"] = 50
			wounded["total_health"] = 30 * int(wounded.get("unit_hp", 1))
			stacks[index] = wounded
			break
	lost_battle["stacks"] = stacks
	var recovered := BattleRules._apply_victory_recovery(lost_battle, "player")
	_check(recovered == 4, "Field Surgeon IV: 4 of 20 fallen recover (%d)" % recovered)
	var commander := {"spellbook": {"mana": {"current": 10, "max": 40}}}
	_check(BattleRules._apply_victory_mana(commander, battle, "player") == 8 and int(commander.spellbook.mana.current) == 18, "Ley Channeler IV: +8 mana after a win")
	# Damage: melee, ranged, damage taken, retaliation, siege and defend bonuses.
	var plain_hero: Dictionary = battle.get("player_hero", {}).duplicate(true)
	for key in DamageRules.HERO_SPECIALTY_BATTLE_KEYS:
		plain_hero[key] = 0
	plain_hero["attack"] = 0
	plain_hero["defense"] = 0
	var melee_attacker := player_stack.duplicate(true)
	melee_attacker["ranged"] = false
	var defender := enemy_stack.duplicate(true)
	defender["defending"] = false
	battle["player_hero"] = plain_hero
	battle["enemy_hero_payload"] = plain_hero.duplicate(true)
	battle["enemy_hero"] = {}
	var base := BattleRules._damage_modifier(melee_attacker, defender, battle, false)
	var boosted := plain_hero.duplicate(true)
	boosted["melee_damage_pct"] = 20
	boosted["ranged_damage_pct"] = 20
	boosted["retaliation_damage_pct"] = 40
	boosted["siege_damage_pct"] = 40
	battle["player_hero"] = boosted
	_check(is_equal_approx(BattleRules._damage_modifier(melee_attacker, defender, battle, false) / base, 1.2), "Vanguard Drill IV: +20% melee damage")
	_check(is_equal_approx(BattleRules._damage_modifier(melee_attacker, defender, battle, false, true) / BattleRules._damage_modifier(melee_attacker, defender, _with_hero(battle, plain_hero), false, true), 1.6), "Counterstroke IV adds +40% to retaliation")
	var siege := battle.duplicate(true)
	siege["context"] = {"type": "town_assault"}
	_check(is_equal_approx(BattleRules._damage_modifier(melee_attacker, defender, siege, false) / BattleRules._damage_modifier(melee_attacker, defender, _with_hero(siege, plain_hero), false), 1.6), "Siegecraft IV adds +40% when assaulting a town")
	battle["player_hero"] = plain_hero
	var guarded := plain_hero.duplicate(true)
	guarded["damage_taken_pct"] = -16
	battle["enemy_hero_payload"] = guarded
	_check(is_equal_approx(BattleRules._damage_modifier(melee_attacker, defender, battle, false) / base, 0.84), "Shieldwall Oath IV: the defender takes 16% less")
	var retinue := plain_hero.duplicate(true)
	retinue["defend_defense_bonus"] = 4
	battle["enemy_hero_payload"] = retinue
	defender["defending"] = true
	var with_retinue := BattleRules._damage_modifier(melee_attacker, defender, battle, false)
	battle["enemy_hero_payload"] = plain_hero.duplicate(true)
	var without_retinue := BattleRules._damage_modifier(melee_attacker, defender, battle, false)
	_check(with_retinue < without_retinue, "Retinue Drill IV: a defending stack takes less (%.3f vs %.3f)" % [with_retinue, without_retinue])
	var payload := BattleRules._hero_payload_from_state(_hero("hero_caelen", _ranked({"vanguard": 4, "shieldwall": 2})))
	_check(int(payload.get("melee_damage_pct", 0)) == 20 and int(payload.get("damage_taken_pct", 0)) == -8, "the battle payload carries the specialties: %s / %s" % [payload.get("melee_damage_pct", 0), payload.get("damage_taken_pct", 0)])

func _with_hero(battle: Dictionary, hero: Dictionary) -> Dictionary:
	var copy := battle.duplicate(true)
	copy["player_hero"] = hero.duplicate(true)
	return copy
