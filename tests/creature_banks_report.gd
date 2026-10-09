extends Node
# HoMM3 guarded objects on generated maps (docs/creature-banks.md). Every
# creature bank, the Derelict Ship, Dragon Utopia, Pyramid, Crypt and Shipwreck
# rolls one of HoMM3's levels, pays that level's HoMM3 reward and is guarded by
# original units with the battle power of HoMM3's guard; creatures it grants
# join with the power of HoMM3's. A Pandora's Box pays the contents the native
# generator rolled and a Warrior's Tomb holds one artifact; neither fights a
# guard of its own.

const NativeRandomMapPackageSessionBridgeScript = preload("res://scripts/persistence/NativeRandomMapPackageSessionBridge.gd")
const OverworldRulesScript = preload("res://scripts/core/OverworldRules.gd")
const EnemyAdventureRulesScript = preload("res://scripts/core/EnemyAdventureRules.gd")
const ArtifactRulesScript = preload("res://scripts/core/ArtifactRules.gd")
const BattleRulesScript = preload("res://scripts/core/BattleRules.gd")
const DifficultyRulesScript = preload("res://scripts/core/DifficultyRules.gd")
const HeroProgressionRulesScript = preload("res://scripts/core/HeroProgressionRules.gd")
const SpellRulesScript = preload("res://scripts/core/SpellRules.gd")
const GeneratedRewards = preload("res://scripts/persistence/GeneratedRewardRules.gd")
const GeneratedNeutral = preload("res://scripts/persistence/GeneratedNeutralEncounterRules.gd")
const NodePayload = preload("res://scripts/core/ResourceNodePayloadRules.gd")

const REPORT_ID := "CREATURE_BANKS_REPORT"
const TRANSLATED_TYPES := [6, 16, 24, 25, 63, 84, 85, 108]
# HoMM3 experience and the experience worth the same hero level here.
const H3M_EXPERIENCE := {5000: 2100, 10000: 4450, 15000: 6800, 20000: 9000}
# The maps hold every common HoMM3 guarded object between them.
const MAP_SPECS := [["medium", 72, "land", "10"], ["medium", 72, "land", "13"], ["large", 108, "normal", "21"]]
const FACTION_RARITIES := {"treasure": ["common", "uncommon"], "minor": ["uncommon"], "major": ["rare"], "relic": ["epic"]}

var _failures := []
var _rate := 0.0

func _ready() -> void:
	call_deferred("_run")

func _run() -> void:
	_rate = float(ContentService.load_json("res://content/generated_neutral_companies.json").get("power_per_native_value", 0.0))
	_expect(_rate > 0.0, "the native power rate is set")
	var report := {}
	report["table"] = _check_table()
	report["odds"] = _check_level_odds()
	report["guards"] = _check_guards()
	report["rewards"] = _check_rewards()
	report["pandora"] = _check_pandora()
	report["tomb"] = _check_warriors_tomb()
	report["artifacts"] = _check_artifact_classes()
	var session = null
	var maps := []
	for spec in MAP_SPECS:
		session = _generated_session(spec)
		if session == null:
			_fail("Generated %s map %s did not adopt into a session." % [spec[0], spec[3]])
			return
		maps.append(_check_generated_map(session, spec))
	report["maps"] = maps
	report["claims"] = _check_player_claims(session)
	report["ai_claims"] = _check_ai_claims(session)
	if not _failures.is_empty():
		_fail(JSON.stringify(_failures))
		return
	report["ok"] = true
	print("%s %s" % [REPORT_ID, JSON.stringify(report)])
	get_tree().quit(0)

## Every bank's levels add to 100%, its site and map object exist and are
## one-time, and every creature it names has a unit with power and idle art.
func _check_table() -> Dictionary:
	var rows := {}
	for bank_id in GeneratedRewards.CREATURE_BANKS.keys():
		var bank: Dictionary = GeneratedRewards.CREATURE_BANKS[bank_id]
		var site_id := String(bank.site_id)
		var site := ContentService.get_resource_site(site_id)
		_expect(not site.is_empty() and not ContentService.get_map_object_for_resource_site(site_id).is_empty(), "bank %s has its site and map object: %s" % [bank_id, site_id])
		_expect(not bool(site.get("persistent_control", false)), "bank %s is a one-time site, held by no faction: %s" % [bank_id, site_id])
		_expect(String(site.get("family", "")) == "guarded_reward_site", "bank %s grants artifacts as a guarded site" % bank_id)
		var chance := 0
		for row in bank.levels:
			chance += int(row.chance)
			for stack in row.get("guard", []) + row.get("troops", []):
				_expect(bank.units.has(int(stack[0])), "bank %s names a unit for creature value %d" % [bank_id, int(stack[0])])
		_expect(chance == 100, "bank %s levels add to 100%%: %d" % [bank_id, chance])
		for unit_id in bank.units.values():
			_expect(_unit_power(String(unit_id)) > 0.0 and GeneratedNeutral._company_art_ready("", String(unit_id)), "bank %s unit %s has power and idle art" % [bank_id, unit_id])
		var upgrade: Array = bank.get("upgrade", [])
		_expect(upgrade.is_empty() or (bank.units.has(int(upgrade[0])) and bank.units.has(int(upgrade[1]))), "bank %s upgrade names its units" % bank_id)
		rows[bank_id] = site_id
	for site_id in [GeneratedRewards.PANDORA_SITE, GeneratedRewards.WARRIORS_TOMB_SITE]:
		_expect(not ContentService.get_resource_site(site_id).is_empty() and not ContentService.get_map_object_for_resource_site(site_id).is_empty(), "%s has its site and map object" % site_id)
	return rows

## Banks of four levels fall 30/30/30/10 as in HoMM3; the Pyramid has one.
func _check_level_odds() -> Dictionary:
	var counts := [0, 0, 0, 0]
	var samples := 4000
	for index in range(samples):
		counts[GeneratedRewards.bank_level_roll("creature_bank_odds_%d" % index, "16:0") - 1] += 1
	var shares := []
	for level in range(4):
		var share := 100.0 * float(counts[level]) / float(samples)
		shares.append(snappedf(share, 0.1))
		_expect(absf(share - [30.0, 30.0, 30.0, 10.0][level]) <= 2.5, "level %d share %.1f%% is near HoMM3's" % [level + 1, share])
	var pyramid_levels := {}
	for index in range(50):
		pyramid_levels[GeneratedRewards.bank_level_roll("creature_bank_pyramid_%d" % index, "63")] = true
	_expect(pyramid_levels.keys() == [1], "the Pyramid always rolls its one level: %s" % [pyramid_levels.keys()])
	return {"samples": samples, "shares_pct": shares}

## Each level's guard has the native guard's battle power: each unit's whole
## creatures come within half a creature of its share of the budget. A single
## creature stands in five stacks, upgraded in one of them on half the
## placements, and every level is stronger than the one below.
func _check_guards() -> Dictionary:
	var rows := {}
	for bank_id in GeneratedRewards.CREATURE_BANKS.keys():
		var bank: Dictionary = GeneratedRewards.CREATURE_BANKS[bank_id]
		var previous := 0.0
		var bank_rows := []
		for level in range(1, bank.levels.size() + 1):
			var key := _key_for_level(bank_id, level)
			var node := _bank_node(bank_id, key)
			var native := GeneratedRewards.native_guard_stacks(key, bank_id, level)
			var stacks := GeneratedRewards.bank_guard_stacks(node)
			var target := _native_power(native)
			var power := _army_power(stacks)
			_check_budget_by_unit(native, bank.units, stacks, "bank %s level %d guard" % [bank_id, level])
			if bank.levels[level - 1].guard.size() == 1:
				var total := 0
				for stack in stacks:
					total += int(stack.count)
				_expect(native.size() == GeneratedRewards.GUARD_STACK_COUNT and stacks.size() == mini(GeneratedRewards.GUARD_STACK_COUNT, total), "bank %s level %d single creature stands in five stacks: %s" % [bank_id, level, stacks])
			_expect(power > previous, "bank %s level %d guard (%.0f) is stronger than the level below (%.0f)" % [bank_id, level, power, previous])
			previous = power
			bank_rows.append({"level": level, "stacks": stacks, "power": int(round(power)), "target": int(round(target))})
		rows[bank_id] = bank_rows
	var upgraded := 0
	var samples := 1000
	for index in range(samples):
		for stack in GeneratedRewards.native_guard_stacks("creature_bank_upgrade_%d" % index, "16:0", 1):
			if int(stack[0]) == 1443:
				upgraded += 1
				break
	_expect(absf(100.0 * float(upgraded) / float(samples) - GeneratedRewards.UPGRADE_CHANCE_PCT) <= 5.0, "about half the Cyclops Stockpiles field an upgraded stack: %d of %d" % [upgraded, samples])
	for stack in GeneratedRewards.native_guard_stacks("creature_bank_upgrade_x", "84", 4):
		_expect(int(stack[0]) in [60, 98, 252, 555], "the Crypt's mixed guard is never upgraded")
	_expect(GeneratedRewards.bank_guard_stacks({"h3m_type_id": 16, "h3m_subtype": 99, GeneratedRewards.BANK_LEVEL: 1}).is_empty(), "a node that is no translated bank keeps its site's guard")
	rows["upgraded_share_pct"] = 100.0 * float(upgraded) / float(samples)
	return rows

## Each level pays HoMM3's resources (its rares as distinct ones of our six),
## troops with HoMM3's power, its spell and its artifact classes, and nothing
## of the site's own rewards, recruits, spells or scouting.
func _check_rewards() -> Dictionary:
	var rows := {}
	for bank_id in GeneratedRewards.CREATURE_BANKS.keys():
		var bank: Dictionary = GeneratedRewards.CREATURE_BANKS[bank_id]
		var bank_rows := []
		for level in range(1, bank.levels.size() + 1):
			var label := "bank %s level %d" % [bank_id, level]
			var row: Dictionary = bank.levels[level - 1]
			var node := _bank_node(bank_id, _key_for_level(bank_id, level))
			var site := NodePayload.site_for_node(node)
			var rewards: Dictionary = site.get("claim_rewards", {})
			_expect(String(node.get("site_id", "")) == String(bank.site_id) and int(node.get(GeneratedRewards.BANK_LEVEL, 0)) == level, "%s is its site at its level" % label)
			var rare_amounts := []
			for resource_id in rewards.keys():
				if row.get("rewards", {}).has(resource_id):
					_expect(int(rewards[resource_id]) == int(row.rewards[resource_id]), "%s pays %s %s" % [label, row.rewards[resource_id], resource_id])
				else:
					_expect(String(resource_id) in GeneratedRewards.RARE_RESOURCES, "%s pays only its own resources and rares: %s" % [label, rewards])
					rare_amounts.append(int(rewards[resource_id]))
			for resource_id in row.get("rewards", {}).keys():
				_expect(rewards.has(resource_id), "%s pays its %s" % [label, resource_id])
			var expected_rares := []
			for amount in row.get("rares", []):
				if int(amount) > 0:
					expected_rares.append(int(amount))
			rare_amounts.sort()
			expected_rares.sort()
			_expect(rare_amounts == expected_rares, "%s pays its rares as distinct ones of ours: %s, expected %s" % [label, rewards, expected_rares])
			var troops: Dictionary = site.get("claim_recruits", {})
			if row.has("troops"):
				var stacks := []
				for unit_id in troops.keys():
					stacks.append({"unit_id": unit_id, "count": troops[unit_id]})
				_check_budget_by_unit(row.troops, bank.units, stacks, "%s troops" % label)
			else:
				_expect(troops.is_empty(), "%s grants no troops: %s" % [label, troops])
			_expect(site.get(NodePayload.CLAIM_ARTIFACT_CLASSES, null) == row.get("artifacts", []), "%s holds its artifact classes: %s" % [label, site.get(NodePayload.CLAIM_ARTIFACT_CLASSES, null)])
			var spells: Array = site.get("learn_spell_ids", [])
			if int(row.get("spell_tier", 0)) > 0:
				_expect(spells.size() == 1 and int(ContentService.get_spell(String(spells[0])).get("tier", 0)) == int(row.spell_tier), "%s teaches one tier-%d spell: %s" % [label, int(row.spell_tier), spells])
			else:
				_expect(spells.is_empty(), "%s teaches no spell: %s" % [label, spells])
			_expect(not site.has("learn_spell_id") and not rewards.has("experience") and int(site.get("vision_radius", -1)) == 0, "%s has none of its site's spell, experience or scouting" % label)
			bank_rows.append({"level": level, "rewards": rewards, "troops": troops, "artifacts": site.get(NodePayload.CLAIM_ARTIFACT_CLASSES, []), "spells": spells})
		rows[bank_id] = bank_rows
	# HoMM3's sulfur becomes any of our six rares, by placement.
	var rare_ids := {}
	for index in range(200):
		var rewards: Dictionary = NodePayload.site_for_node(_bank_node("16:4", "creature_bank_rare_%d" % index)).get("claim_rewards", {})
		for resource_id in rewards.keys():
			if resource_id != "gold":
				rare_ids[resource_id] = true
	_expect(rare_ids.size() == GeneratedRewards.RARE_RESOURCES.size(), "a bank's rare varies over our six rares: %s" % [rare_ids.keys()])
	# Placements and saves without a bank payload keep the site's definition.
	var authored := NodePayload.site_for_node({"placement_id": "authored_eyrie", "site_id": "site_glassbound_eyrie"})
	_expect(not authored.get("claim_recruits", {}).is_empty() and int(authored.get("vision_radius", 0)) > 0 and not authored.has(NodePayload.CLAIM_ARTIFACT_CLASSES), "an authored Eyrie keeps its own recruits and scouting")
	return rows

## A Pandora's Box pays the contents the native generator rolled: gold and
## rares, experience worth the same hero level, every spell of its levels (of
## one of our schools for a one-school box) or neutral troops of the
## creatures' tier and power. It has no guard of its own.
func _check_pandora() -> Dictionary:
	var report := {}
	for amount in H3M_EXPERIENCE.keys():
		_expect(GeneratedRewards.experience_for_h3m(int(amount)) == int(H3M_EXPERIENCE[amount]), "%d HoMM3 experience is worth %d: %d" % [amount, H3M_EXPERIENCE[amount], GeneratedRewards.experience_for_h3m(int(amount))])
	var gold := _pandora_node("pandora_gold", {"resources": [0, 0, 0, 0, 0, 0, 10000]})
	_expect(String(gold.get("site_id", "")) == GeneratedRewards.PANDORA_SITE and String(gold.get("kind", "")) == "reward_reference" and bool(gold.get(GeneratedRewards.UNGUARDED, false)), "a box becomes an unguarded casket pickup: %s" % [gold.get("site_id", "")])
	var gold_site := NodePayload.site_for_node(gold)
	_expect(gold_site.get("claim_rewards", {}) == {"gold": 10000} and gold_site.get("claim_recruits", {}).is_empty() and gold_site.get("learn_spell_ids", []).is_empty(), "a gold box pays its gold only: %s" % [gold_site.get("claim_rewards", {})])
	var experience_site := NodePayload.site_for_node(_pandora_node("pandora_experience", {"experience": 15000}))
	_expect(experience_site.get("claim_rewards", {}) == {"experience": 6800}, "a 15000 experience box pays 6800: %s" % [experience_site.get("claim_rewards", {})])
	var rare_rewards: Dictionary = NodePayload.site_for_node(_pandora_node("pandora_rare", {"resources": [0, 3, 0, 0, 0, 0, 0]})).get("claim_rewards", {})
	_expect(rare_rewards.size() == 1 and String(rare_rewards.keys()[0]) in GeneratedRewards.RARE_RESOURCES and int(rare_rewards.values()[0]) == 3, "a mercury box pays one of our rares: %s" % [rare_rewards])
	# A box of spells of levels 1 and 2 from every school teaches all of ours.
	var all_spells: Array = NodePayload.site_for_node(_pandora_node("pandora_all_spells", {"spell_ids": [1, 2, 3, 4, 5], "spell_levels": [1, 2], "spell_school_masks": [1, 2, 4, 8, 15]})).get("learn_spell_ids", [])
	var expected_all := _spell_ids_of(func(spell): return int(spell.get("tier", 0)) in [1, 2])
	_expect(all_spells == expected_all, "an all-school box teaches every tier 1-2 spell: %d of %d" % [all_spells.size(), expected_all.size()])
	# A fire box teaches every spell of its levels of one of our schools.
	var schools := {}
	for index in range(40):
		var spells: Array = NodePayload.site_for_node(_pandora_node("pandora_fire_%d" % index, {"spell_ids": [1, 2, 3], "spell_levels": [1, 2, 3], "spell_school_masks": [2, 2, 3]})).get("learn_spell_ids", [])
		var school := String(ContentService.get_spell(String(spells[0])).get("school_id", "")) if not spells.is_empty() else ""
		var expected := _spell_ids_of(func(spell): return int(spell.get("tier", 0)) in [1, 2, 3] and String(spell.get("school_id", "")) == school)
		_expect(school != "" and spells == expected, "a one-school box teaches every tier 1-3 spell of one school: %s" % [spells])
		schools[school] = true
	_expect(schools.size() >= 5, "one-school boxes spread over our schools: %s" % [schools.keys()])
	# Creatures join as neutral units of their tier with their power.
	var troops: Dictionary = NodePayload.site_for_node(_pandora_node("pandora_creatures", {"creatures": [{"creature_id": 100, "quantity": 20, "level": 3, "ai_value": 500}]})).get("claim_recruits", {})
	_expect(troops.size() == 1, "a creature box grants one troop: %s" % [troops])
	if troops.size() == 1:
		var unit := ContentService.get_unit(String(troops.keys()[0]))
		_expect(int(unit.get("tier", 0)) == 4 and String(unit.get("faction_id", "")) == "", "the troop is a neutral tier-4 unit: %s" % [troops])
		_check_budget_by_unit([[500, 20]], {500: String(troops.keys()[0])}, [{"unit_id": troops.keys()[0], "count": troops.values()[0]}], "box troops")
	var legacy := NodePayload.site_for_node(_pandora_node("pandora_legacy", {}, false))
	_expect(legacy.get("claim_rewards", {}) == {"gold": 5000}, "a box from before its contents were exported pays HoMM3's smallest gold: %s" % [legacy.get("claim_rewards", {})])
	report["experience"] = H3M_EXPERIENCE
	report["all_school_spells"] = all_spells.size()
	report["one_school_schools"] = schools.keys()
	report["creature_troops"] = troops
	return report

## A Warrior's Tomb holds one artifact of a class rolled 30/50/15/5 and pays
## nothing else; it fights no guard of its own.
func _check_warriors_tomb() -> Dictionary:
	var counts := {"treasure": 0, "minor": 0, "major": 0, "relic": 0}
	var samples := 4000
	for index in range(samples):
		var node := GeneratedRewards.resolve({"placement_id": "creature_banks_tomb_%d" % index, "kind": "resource_site", "h3m_type_id": 108, "h3m_subtype": 0, "x": 0, "y": 0, "level": 0})
		var classes: Array = node.get(NodePayload.PAYLOAD_ARTIFACT_CLASSES, [])
		if index == 0:
			var site := NodePayload.site_for_node(node)
			_expect(String(node.get("site_id", "")) == GeneratedRewards.WARRIORS_TOMB_SITE and bool(node.get(GeneratedRewards.UNGUARDED, false)), "a Warrior's Tomb becomes an unguarded tomb")
			_expect(site.get("claim_rewards", {}).is_empty() and site.get("claim_recruits", {}).is_empty() and site.get("learn_spell_ids", []).is_empty() and int(site.get("vision_radius", -1)) == 0, "a tomb pays nothing but its artifact: %s" % [site.get("claim_rewards", {})])
		_expect(classes.size() == 1 and counts.has(String(classes[0])), "a tomb holds one artifact class: %s" % [classes])
		if classes.size() == 1 and counts.has(String(classes[0])):
			counts[String(classes[0])] += 1
	var shares := {}
	for artifact_class in counts.keys():
		var share := 100.0 * float(counts[artifact_class]) / float(samples)
		shares[artifact_class] = snappedf(share, 0.1)
		_expect(absf(share - float(GeneratedRewards.WARRIORS_TOMB_CLASS_WEIGHTS[artifact_class])) <= 2.5, "tomb %s share %.1f%% is near HoMM3's" % [artifact_class, share])
	return {"samples": samples, "shares_pct": shares}

## Each HoMM3 class draws an artifact the hero lacks from its rarities; a
## relic falls back to a rare one once every epic is held, and several classes
## draw distinct artifacts. Saves from before the classes keep their rarity.
func _check_artifact_classes() -> Dictionary:
	var pools := _artifacts_by_rarity()
	var report := {}
	for artifact_class in FACTION_RARITIES.keys():
		var record := {NodePayload.CLAIM_ARTIFACT_CLASSES: [artifact_class]}
		var drawn := {}
		for index in range(30):
			var selection: Dictionary = ArtifactRulesScript.select_live_source_reward("guarded_site", record, "creature_banks_class_%d" % index, "", [])
			var rarity := String(ContentService.get_artifact(String(selection.get("artifact_id", ""))).get("rarity", ""))
			_expect(bool(selection.get("ok", false)) and rarity in FACTION_RARITIES[artifact_class], "a %s draws from %s: %s" % [artifact_class, FACTION_RARITIES[artifact_class], selection])
			drawn[String(selection.get("artifact_id", ""))] = true
		report[artifact_class] = drawn.size()
	var relic := {NodePayload.CLAIM_ARTIFACT_CLASSES: ["relic"]}
	var fallback: Dictionary = ArtifactRulesScript.select_live_source_reward("guarded_site", relic, "creature_banks_fallback", "", pools.get("epic", []))
	_expect(bool(fallback.get("ok", false)) and String(fallback.get("artifact_id", "")) in pools.get("rare", []), "a relic falls back to a rare artifact once every epic is held: %s" % [fallback])
	var hoard := {NodePayload.CLAIM_ARTIFACT_CLASSES: ["relic", "relic", "relic", "relic"]}
	var several := ArtifactRulesScript.select_live_source_rewards("guarded_site", hoard, "creature_banks_hoard", "", [])
	var ids := {}
	for selection in several:
		ids[String(selection.get("artifact_id", ""))] = true
	_expect(several.size() == 4 and ids.size() == 4, "four relics are four distinct artifacts: %s" % [ids.keys()])
	var empty := ArtifactRulesScript.select_live_source_reward("guarded_site", {NodePayload.CLAIM_ARTIFACT_CLASSES: []}, "creature_banks_empty", "", [])
	_expect(not bool(empty.get("ok", true)) and String(empty.get("reason", "")) == "placement_holds_no_artifact", "a level without artifacts draws none: %s" % [empty])
	_expect(ArtifactRulesScript.select_live_source_rewards("guarded_site", {NodePayload.CLAIM_ARTIFACT_CLASSES: []}, "creature_banks_empty", "", []).is_empty(), "a level without artifacts grants none")
	var exhausted := ArtifactRulesScript.select_live_source_reward("guarded_site", {NodePayload.CLAIM_ARTIFACT_CLASSES: ["minor"]}, "creature_banks_exhausted", "", pools.get("uncommon", []))
	_expect(not bool(exhausted.get("ok", true)), "nothing is drawn once the hero holds every artifact of the class")
	var legacy := NodePayload.site_for_node({"placement_id": "creature_banks_legacy", "site_id": "site_glassbound_eyrie", NodePayload.PAYLOAD_ARTIFACT_RARITY: "uncommon"})
	var legacy_draw := ArtifactRulesScript.select_live_source_reward("guarded_site", legacy, "creature_banks_legacy", "", [])
	_expect(bool(legacy_draw.get("ok", false)) and String(legacy_draw.get("artifact_id", "")) in pools.get("uncommon", []), "a saved bank of one rarity still draws it: %s" % [legacy_draw])
	report["hoard"] = ids.keys()
	return report

## Every guarded HoMM3 object on a generated map is translated: banks at a
## level with a linked guard that fields that level's army and shows its
## lead unit; caskets and tombs without a guard of their own.
func _check_generated_map(session, spec: Array) -> Dictionary:
	var sources: Dictionary = session.overworld.get("package_source_objects_by_id", {})
	var counts := {}
	var battled := false
	for node in session.overworld.get("resource_nodes", []):
		var placement_id := String(node.get("placement_id", ""))
		var source: Dictionary = sources.get(placement_id, {})
		var type_id := int(source.get("h3m_type_id", -1))
		if type_id not in TRANSLATED_TYPES:
			continue
		var subtype := int(source.get("h3m_subtype", -1))
		var label := "%d:%d" % [type_id, subtype]
		counts[label] = int(counts.get(label, 0)) + 1
		var guard := _linked_guard(session, placement_id)
		var bank_id := GeneratedRewards.bank_key(type_id, subtype)
		if bank_id == "":
			var site_id := GeneratedRewards.PANDORA_SITE if type_id == GeneratedRewards.TYPE_PANDORA else GeneratedRewards.WARRIORS_TOMB_SITE
			var site := NodePayload.site_for_node(node)
			_expect(String(node.get("site_id", "")) == site_id and bool(node.get(GeneratedRewards.UNGUARDED, false)) and guard.is_empty(), "generated %s is an unguarded %s: %s" % [label, site_id, node.get("site_id", "")])
			if type_id == GeneratedRewards.TYPE_PANDORA:
				_expect(source.has("h3m_pandora_contents") and not (site.get("claim_rewards", {}).is_empty() and site.get("claim_recruits", {}).is_empty() and site.get("learn_spell_ids", []).is_empty()), "generated box %s pays its native contents: %s" % [placement_id, source.get("h3m_pandora_contents", {})])
			continue
		var level := int(node.get(GeneratedRewards.BANK_LEVEL, 0))
		var stacks: Array = guard.get("enemy_army", {}).get("stacks", [])
		var profile: Dictionary = guard.get("generated_neutral_profile", {})
		_expect(String(node.get("site_id", "")) == String(GeneratedRewards.CREATURE_BANKS[bank_id].site_id) and level >= 1, "generated %s is its bank at a level: %s %d" % [label, node.get("site_id", ""), level])
		_expect(not guard.is_empty() and not stacks.is_empty() and stacks == GeneratedRewards.bank_guard_stacks(node), "generated %s guard fields its level's army: %s" % [label, stacks])
		_expect(int(guard.get(GeneratedRewards.BANK_LEVEL, 0)) == level, "generated %s guard records the bank level" % label)
		_expect(String(profile.get("primary_unit_id", "")) != "" and String(profile.get("quantity_policy", "")) == "creature_bank_level_v1", "generated %s guard shows its lead unit: %s" % [label, profile])
		if not battled and not stacks.is_empty():
			battled = true
			var battle: Dictionary = BattleRulesScript.create_battle_payload(session, guard)
			var fielded := {}
			for stack in battle.get("stacks", []):
				if stack is Dictionary and String(stack.get("side", "")) == "enemy":
					fielded[String(stack.get("unit_id", ""))] = int(fielded.get(String(stack.get("unit_id", "")), 0)) + int(stack.get("base_count", 0))
			var expected := {}
			for stack in stacks:
				expected[String(stack.get("unit_id", ""))] = int(expected.get(String(stack.get("unit_id", "")), 0)) + int(stack.get("count", 0))
			_expect(not battle.is_empty() and fielded == expected, "the %s guard battle fields the level's army: %s, expected %s" % [label, fielded, expected])
	var banks := 0
	for label in counts.keys():
		if not String(label).begins_with("6:") and not String(label).begins_with("108:"):
			banks += int(counts[label])
	_expect(banks > 0 and battled, "generated %s map %s holds a bank: %s" % [spec[0], spec[3], counts])
	return {"seed": spec[3], "size": spec[0], "objects": counts}

## Claiming pays the human's hero every artifact, troop, experience and spell.
func _check_player_claims(session) -> Array:
	var rows := []
	var claims := [
		["utopia", _bank_node("25", _key_for_level("25", 4))],
		["conservatory", _bank_node("16:2", _key_for_level("16:2", 2))],
		["experience_box", _pandora_node("claim_box_experience", {"experience": 10000})],
		["spell_box", _pandora_node("claim_box_spells", {"spell_ids": [1, 2], "spell_levels": [1, 2], "spell_school_masks": [1, 15]})],
		["tomb", GeneratedRewards.resolve({"placement_id": "claim_tomb", "kind": "resource_site", "h3m_type_id": 108, "h3m_subtype": 0, "x": 0, "y": 0, "level": 0})],
	]
	for claim in claims:
		var label := String(claim[0])
		var hero_tile: Vector2i = OverworldRulesScript.hero_position(session)
		var node: Dictionary = claim[1]
		node["placement_id"] = "creature_banks_claim_%s" % label
		node["x"] = hero_tile.x
		node["y"] = hero_tile.y
		node["collected"] = false
		var nodes: Array = session.overworld.get("resource_nodes", [])
		nodes.append(node)
		session.overworld["resource_nodes"] = nodes
		OverworldRulesScript.normalize_overworld_state(session)
		var index: int = session.overworld.get("resource_nodes", []).size() - 1
		var stored: Dictionary = session.overworld.get("resource_nodes", [])[index]
		var site := NodePayload.site_for_node(stored)
		var hero_before: Dictionary = session.overworld.get("hero", {}).duplicate(true)
		var resources_before: Dictionary = session.overworld.get("resources", {}).duplicate(true)
		var army_before := _army_counts(session)
		var artifacts_before := _owned_artifacts(session)
		var result: Dictionary = OverworldRulesScript._collect_resource_node_result(session, {"index": index, "node": stored}, false)
		var expected: Dictionary = OverworldRulesScript.apply_reward_bonus(
			DifficultyRulesScript.scale_reward_resources(session, site.get("claim_rewards", {})),
			int(HeroProgressionRulesScript.aggregate_bonuses(hero_before).get("reward_bonus_pct", 0))
		)
		var expected_resources := expected.duplicate()
		expected_resources.erase("experience")
		var delta := _resource_delta(resources_before, session.overworld.get("resources", {}))
		var gained := []
		for artifact_id in _owned_artifacts(session):
			if artifact_id not in artifacts_before:
				gained.append(artifact_id)
		var army_gain := {}
		for unit_id in _army_counts(session).keys():
			var change := int(_army_counts(session)[unit_id]) - int(army_before.get(unit_id, 0))
			if change != 0:
				army_gain[unit_id] = change
		var experience_gain := int(session.overworld.get("hero", {}).get("experience", 0)) - int(hero_before.get("experience", 0))
		_expect(bool(result.get("ok", false)), "%s claim succeeds: %s" % [label, result.get("message", "")])
		_expect(delta == expected_resources, "%s claim pays its resources: %s, expected %s" % [label, delta, expected_resources])
		_expect(experience_gain == int(expected.get("experience", 0)), "%s claim pays %d experience: %d" % [label, int(expected.get("experience", 0)), experience_gain])
		_expect(gained.size() == site.get(NodePayload.CLAIM_ARTIFACT_CLASSES, []).size(), "%s claim grants one artifact per class: %s" % [label, gained])
		_expect(army_gain == site.get("claim_recruits", {}), "%s claim adds its troops: %s, expected %s" % [label, army_gain, site.get("claim_recruits", {})])
		for spell_id in site.get("learn_spell_ids", []):
			_expect(SpellRulesScript.knows_spell(session.overworld.get("hero", {}), String(spell_id)), "%s claim teaches %s" % [label, spell_id])
		var recorded: Array = session.overworld.get("resource_nodes", [])[index].get("artifact_reward_ids", []).duplicate()
		recorded.sort()
		gained.sort()
		_expect(gained.is_empty() or recorded == gained, "%s claim records every artifact on the node: %s" % [label, recorded])
		rows.append({"claim": label, "resources": delta, "experience": experience_gain, "artifacts": gained, "troops": army_gain, "spells": site.get("learn_spell_ids", []).size(), "message": result.get("message", "")})
	return rows

## A computer hero's claim gains every artifact, spell and the experience.
func _check_ai_claims(session) -> Dictionary:
	var faction_id := ""
	for state in session.overworld.get("enemy_states", []):
		if state is Dictionary and String(state.get("faction_id", "")) != "":
			faction_id = String(state.get("faction_id", ""))
			break
	_expect(faction_id != "", "the generated session has a computer faction")
	var commander: Dictionary = session.overworld.get("hero", {}).duplicate(true)
	commander.erase("roster_hero_id")
	commander = ArtifactRulesScript.ensure_hero_artifacts(SpellRulesScript.ensure_hero_spellbook(commander))
	var raid := {"placement_id": "creature_banks_ai_raid", "enemy_commander_state": commander}
	var hoard := _bank_node("25", _key_for_level("25", 4))
	hoard["placement_id"] = "creature_banks_ai_hoard"
	var artifacts := EnemyAdventureRulesScript._apply_resource_site_artifact_reward_to_raid(session, faction_id, raid, hoard, NodePayload.site_for_node(hoard))
	var owned := ArtifactRulesScript.owned_artifact_ids(artifacts.get("raid", {}).get("enemy_commander_state", {}))
	var granted: Array = artifacts.get("artifact_ids", [])
	_expect(bool(artifacts.get("applied", false)) and granted.size() == 4, "a computer hero takes all four hoard artifacts: %s" % [granted])
	for artifact_id in granted:
		_expect(String(artifact_id) in owned, "the computer hero holds %s" % artifact_id)
	var box := _pandora_node("ai_box_spells", {"spell_ids": [1, 2], "spell_levels": [1, 2], "spell_school_masks": [1, 15]})
	var box_site := NodePayload.site_for_node(box)
	var spells := EnemyAdventureRulesScript._apply_resource_site_spell_reward_to_commander(session, faction_id, raid, box_site)
	var taught: Dictionary = spells.get("raid", {}).get("enemy_commander_state", {})
	var unknown := 0
	for spell_id in box_site.get("learn_spell_ids", []):
		_expect(SpellRulesScript.knows_spell(taught, String(spell_id)), "the computer hero learns %s" % spell_id)
		if not SpellRulesScript.knows_spell(commander, String(spell_id)):
			unknown += 1
	_expect(bool(spells.get("learned", false)) and spells.get("spell_ids", []).size() == unknown, "the computer hero learns every spell it lacked: %d of %d" % [spells.get("spell_ids", []).size(), unknown])
	return {"faction_id": faction_id, "artifacts": granted, "spells": spells.get("spell_ids", []).size(), "spell_name": spells.get("spell_name", "")}

## Each unit's whole creatures come within half a creature of the power its
## native stacks are worth (or are the one creature a tiny budget still gets).
func _check_budget_by_unit(native: Array, units: Dictionary, stacks: Array, label: String) -> void:
	var budgets := {}
	for stack in native:
		var unit_id := String(units.get(int(stack[0]), ""))
		budgets[unit_id] = float(budgets.get(unit_id, 0.0)) + float(stack[0]) * float(stack[1]) * _rate
	var fielded := {}
	for stack in stacks:
		fielded[String(stack.unit_id)] = int(fielded.get(String(stack.unit_id), 0)) + int(stack.count)
	_expect(fielded.keys().size() == budgets.keys().size(), "%s fields every unit of its budget: %s" % [label, stacks])
	for unit_id in budgets.keys():
		var power := _unit_power(unit_id)
		var count := int(fielded.get(unit_id, 0))
		var error := absf(float(count) * power - float(budgets[unit_id]))
		_expect(error <= power * 0.5 + 0.01 or (count == 1 and float(budgets[unit_id]) < power), "%s %s: %d creatures for %.0f power (each %.1f)" % [label, unit_id, count, budgets[unit_id], power])

func _bank_node(bank_id: String, key: String) -> Dictionary:
	var parts := bank_id.split(":")
	return GeneratedRewards.resolve({
		"placement_id": key,
		"kind": "resource_site",
		"h3m_type_id": int(parts[0]),
		"h3m_subtype": int(parts[1]) if parts.size() > 1 else 0,
		"x": 0,
		"y": 0,
		"level": 0,
	})

func _pandora_node(key: String, contents: Dictionary, exported: bool = true) -> Dictionary:
	var object := {"placement_id": key, "kind": "reward_reference", "h3m_type_id": 6, "h3m_subtype": 0, "x": 0, "y": 0, "level": 0}
	if exported:
		var box := {"experience": 0, "resources": [0, 0, 0, 0, 0, 0, 0], "spell_ids": [], "spell_levels": [], "spell_school_masks": [], "creatures": []}
		for field in contents.keys():
			box[field] = contents[field]
		object["h3m_pandora_contents"] = box
	return GeneratedRewards.resolve(object)

func _key_for_level(bank_id: String, level: int) -> String:
	for index in range(1000):
		var key := "creature_banks_%s_level_%d_%d" % [bank_id, level, index]
		if GeneratedRewards.bank_level_roll(key, bank_id) == level:
			return key
	return ""

func _spell_ids_of(matches: Callable) -> Array:
	var ids := []
	for spell in ContentService.load_json("res://content/spells.json").get("items", []):
		if spell is Dictionary and matches.call(spell):
			ids.append(String(spell.get("id", "")))
	ids.sort()
	return ids

func _artifacts_by_rarity() -> Dictionary:
	var pools := {}
	for artifact in ContentService.load_json(ContentService.ARTIFACTS_PATH).get("items", []):
		if artifact is Dictionary:
			var rarity := String(artifact.get("rarity", ""))
			var pool: Array = pools.get(rarity, [])
			pool.append(String(artifact.get("id", "")))
			pools[rarity] = pool
	return pools

func _linked_guard(session, placement_id: String) -> Dictionary:
	for encounter in session.overworld.get("encounters", []):
		if encounter is Dictionary and String(encounter.get("target_placement_id", "")) == placement_id:
			return encounter
	return {}

func _generated_session(spec: Array):
	var service: Variant = ClassDB.instantiate("MapPackageService")
	var config := {
		"seed": spec[3],
		"size": {"width": spec[1], "height": spec[1], "level_count": 1, "water_mode": spec[2], "size_class_id": spec[0]},
		"monster_strength": "weak",
		"player_constraints": {"human_count": 1, "computer_count": 1, "player_count": 2, "human_team_count": 1, "computer_team_count": 0},
	}
	var generated: Dictionary = service.generate_random_map(config, {"startup_path": "creature_banks_report"})
	var adoption: Dictionary = service.convert_generated_payload(generated, {"feature_gate": REPORT_ID})
	var session = NativeRandomMapPackageSessionBridgeScript.build_session_from_adoption(adoption)
	if session == null or session.overworld.get("resource_nodes", []).is_empty():
		return null
	OverworldRulesScript.normalize_overworld_state(session)
	return session

func _native_power(native: Array) -> float:
	var total := 0.0
	for stack in native:
		total += float(stack[0]) * float(stack[1]) * _rate
	return total

func _unit_power(unit_id: String) -> float:
	return _army_power([{"unit_id": unit_id, "count": 1}])

func _army_power(stacks: Array) -> float:
	return float(load("res://scripts/core/AiHeroRules.gd").army_power(stacks))

func _army_counts(session) -> Dictionary:
	var counts := {}
	for stack in session.overworld.get("hero", {}).get("army", {}).get("stacks", []):
		counts[String(stack.get("unit_id", ""))] = int(counts.get(String(stack.get("unit_id", "")), 0)) + int(stack.get("count", 0))
	return counts

func _owned_artifacts(session) -> Array:
	return ArtifactRulesScript.owned_artifact_ids(session.overworld.get("hero", {}))

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

func _fail(message: String) -> void:
	push_error("%s: %s" % [REPORT_ID, message])
	get_tree().quit(1)
