extends Node
# HoMM3 creature banks on generated maps (docs/creature-banks.md): a Crypt
# becomes a Glassbound Eyrie that rolls one of the Crypt's four levels, pays
# that level's gold plus a treasure-class artifact on levels 3 and 4, and is
# guarded by its own units with the battle power of the Crypt's undead.

const NativeRandomMapPackageSessionBridgeScript = preload("res://scripts/persistence/NativeRandomMapPackageSessionBridge.gd")
const OverworldRulesScript = preload("res://scripts/core/OverworldRules.gd")
const ArtifactRulesScript = preload("res://scripts/core/ArtifactRules.gd")
const BattleRulesScript = preload("res://scripts/core/BattleRules.gd")
const DifficultyRulesScript = preload("res://scripts/core/DifficultyRules.gd")
const HeroProgressionRulesScript = preload("res://scripts/core/HeroProgressionRules.gd")
const GeneratedRewards = preload("res://scripts/persistence/GeneratedRewardRules.gd")
const NodePayload = preload("res://scripts/core/ResourceNodePayloadRules.gd")

const REPORT_ID := "CREATURE_BANKS_REPORT"
const CRYPT := 84
const EYRIE := "site_glassbound_eyrie"
# CRBANKS.TXT: the Crypt's gold and treasure artifact by level.
const CRYPT_GOLD := [1500, 2000, 2500, 5000]
const CRYPT_ARTIFACT := [false, false, true, true]
# The old fixed guard: 7 Cliffhawk Wardens and 3 Windglass Slingers.
const OLD_GUARD_POWER := 80.0
const MAP_SEEDS := ["10", "11", "12", "13", "14", "15"]

var _failures := []

func _ready() -> void:
	call_deferred("_run")

func _run() -> void:
	var levels := _check_levels()
	var odds := _check_level_odds()
	var guards := _check_guard_power()
	var authored := _check_authored_site_unchanged()
	var artifacts := _check_artifact_draw()
	var session = null
	var map := {}
	for seed in MAP_SEEDS:
		session = _generated_session(seed)
		if session == null:
			_fail("Generated medium map %s did not adopt into a session." % seed)
			return
		map = _check_generated_crypts(session)
		if int(map.get("crypts", 0)) > 0:
			map["seed"] = seed
			break
	_expect(int(map.get("crypts", 0)) > 0, "a generated medium map holds a Crypt: %s" % [map])
	var claims := _check_claims(session)
	if not _failures.is_empty():
		_fail(JSON.stringify(_failures))
		return
	print("%s %s" % [REPORT_ID, JSON.stringify({"ok": true, "levels": levels, "odds": odds, "guards": guards, "authored": authored, "artifacts": artifacts, "map": map, "claims": claims})])
	get_tree().quit(0)

## Each level pays the Crypt's gold and, on levels 3 and 4, a treasure-class
## artifact; never the authored Eyrie's ore, experience, recruits or scouting.
func _check_levels() -> Array:
	var rows := []
	var treasure_rarity := String(ContentService.load_json("res://content/random_map_object_eligibility.json").get("artifact_rarities_by_source_type", {}).get("66", ""))
	_expect(treasure_rarity != "", "HoMM3 treasure artifacts have a random-map rarity")
	for level in range(1, 5):
		var node := _bank_node(_key_for_level(level), 0, 0)
		var site := NodePayload.site_for_node(node)
		var rarity := String(site.get(NodePayload.CLAIM_ARTIFACT_RARITY, "missing"))
		_expect(String(node.get("site_id", "")) == EYRIE and String(node.get("object_id", "")) == "object_glassbound_eyrie", "a Crypt becomes the Glassbound Eyrie: %s" % [node.get("site_id", "")])
		_expect(int(node.get(GeneratedRewards.BANK_LEVEL, 0)) == level, "the placement keeps its level %d" % level)
		_expect(site.get("claim_rewards", {}) == {"gold": CRYPT_GOLD[level - 1]} and not site.has("rewards"), "level %d pays %d gold only: %s" % [level, CRYPT_GOLD[level - 1], site.get("claim_rewards", {})])
		_expect(rarity == (treasure_rarity if CRYPT_ARTIFACT[level - 1] else ""), "level %d artifact rarity: %s" % [level, rarity])
		_expect(not site.has("claim_recruits") and int(site.get("vision_radius", -1)) == 0, "level %d has no recruits or scouting: %s %s" % [level, site.get("claim_recruits", {}), site.get("vision_radius", -1)])
		rows.append({"level": level, "gold": site.get("claim_rewards", {}).get("gold", 0), "artifact_rarity": rarity})
	return rows

## Over many placements the levels fall 30/30/30/10 as in HoMM3.
func _check_level_odds() -> Dictionary:
	var counts := [0, 0, 0, 0]
	var samples := 4000
	for index in range(samples):
		counts[GeneratedRewards.bank_level_roll("creature_bank_odds_%d" % index, CRYPT) - 1] += 1
	var shares := []
	for level in range(4):
		var share := 100.0 * float(counts[level]) / float(samples)
		shares.append(snappedf(share, 0.1))
		_expect(absf(share - [30.0, 30.0, 30.0, 10.0][level]) <= 2.5, "level %d share %.1f%% is near HoMM3's" % [level + 1, share])
	return {"samples": samples, "shares_pct": shares}

## Each level's guard has the battle power of the Crypt's undead at the
## generated-guard exchange rate, several times the old fixed guard.
func _check_guard_power() -> Array:
	var rate := float(ContentService.load_json("res://content/generated_neutral_companies.json").get("power_per_native_value", 0.0))
	var bank: Dictionary = GeneratedRewards.CREATURE_BANKS[CRYPT]
	var rows := []
	var previous := 0.0
	for level in range(1, 5):
		var node := _bank_node(_key_for_level(level), 0, 0)
		var stacks := GeneratedRewards.bank_guard_stacks(node)
		var target := 0.0
		for native in bank.levels[level - 1].guard:
			target += float(native[0]) * float(native[1]) * rate
		var power := _army_power(stacks)
		_expect(stacks.size() == bank.levels[level - 1].guard.size(), "level %d fields one stack per Crypt stack: %s" % [level, stacks])
		_expect(absf(power - target) <= target * 0.08, "level %d guard power %.0f is near its native budget %.0f" % [level, power, target])
		_expect(power >= OLD_GUARD_POWER * 2.5 and power > previous, "level %d guard (%.0f) is far stronger than the old guard and the level below" % [level, power])
		previous = power
		rows.append({"level": level, "stacks": stacks, "power": int(round(power)), "target": int(round(target))})
	_expect(GeneratedRewards.bank_guard_stacks({"h3m_type_id": 16, GeneratedRewards.BANK_LEVEL: 1}).is_empty(), "a node that is no translated bank keeps its site's guard")
	return rows

## Authored placements and old saves without a bank payload keep the site's
## own definition.
func _check_authored_site_unchanged() -> Dictionary:
	var site := NodePayload.site_for_node({"placement_id": "authored_eyrie", "site_id": EYRIE})
	_expect(not site.get("claim_recruits", {}).is_empty() and int(site.get("vision_radius", 0)) > 0 and not site.has(NodePayload.CLAIM_ARTIFACT_RARITY), "an authored Eyrie keeps its recruits, scouting and artifact table")
	return {"claim_recruits": site.get("claim_recruits", {}), "vision_radius": site.get("vision_radius", 0)}

## A bank artifact is any one of its rarity the hero lacks; none when the
## hero holds them all or the level holds none.
func _check_artifact_draw() -> Dictionary:
	var site := NodePayload.site_for_node(_bank_node(_key_for_level(3), 0, 0))
	var rarity := String(site.get(NodePayload.CLAIM_ARTIFACT_RARITY, ""))
	var pool := []
	for artifact in ContentService.load_json(ContentService.ARTIFACTS_PATH).get("items", []):
		if artifact is Dictionary and String(artifact.get("rarity", "")) == rarity:
			pool.append(String(artifact.get("id", "")))
	var first: Dictionary = ArtifactRulesScript.select_live_source_reward("guarded_site", site, "creature_banks:a", "faction_embercourt", [])
	_expect(bool(first.get("ok", false)) and String(first.get("artifact_id", "")) in pool, "level 3 draws an artifact of its rarity: %s" % [first])
	var owned_one := pool.slice(0, pool.size() - 1)
	var second: Dictionary = ArtifactRulesScript.select_live_source_reward("guarded_site", site, "creature_banks:a", "faction_embercourt", owned_one)
	_expect(bool(second.get("ok", false)) and String(second.get("artifact_id", "")) == String(pool[pool.size() - 1]), "the draw skips artifacts the hero holds: %s" % [second])
	var exhausted: Dictionary = ArtifactRulesScript.select_live_source_reward("guarded_site", site, "creature_banks:a", "faction_embercourt", pool)
	_expect(not bool(exhausted.get("ok", true)), "nothing is drawn once the hero holds every artifact of the rarity")
	var empty_site := NodePayload.site_for_node(_bank_node(_key_for_level(1), 0, 0))
	var none: Dictionary = ArtifactRulesScript.select_live_source_reward("guarded_site", empty_site, "creature_banks:b", "faction_embercourt", [])
	_expect(not bool(none.get("ok", true)) and String(none.get("reason", "")) == "placement_holds_no_artifact", "level 1 holds no artifact: %s" % [none])
	return {"rarity": rarity, "pool": pool, "first": first.get("artifact_id", "")}

## Every Crypt on a generated map becomes a levelled Eyrie whose linked guard
## fields its level's army.
func _check_generated_crypts(session) -> Dictionary:
	var sources: Dictionary = session.overworld.get("package_source_objects_by_id", {})
	var crypts := []
	for node in session.overworld.get("resource_nodes", []):
		var source: Dictionary = sources.get(String(node.get("placement_id", "")), {})
		if int(source.get("h3m_type_id", -1)) != CRYPT:
			continue
		var level := int(node.get(GeneratedRewards.BANK_LEVEL, 0))
		var site := NodePayload.site_for_node(node)
		_expect(String(node.get("site_id", "")) == EYRIE and level >= 1 and level <= 4, "generated Crypt became a levelled Eyrie: %s %d" % [node.get("site_id", ""), level])
		_expect(int(site.get("claim_rewards", {}).get("gold", 0)) == CRYPT_GOLD[clampi(level, 1, 4) - 1], "generated Crypt pays its level's gold: %s" % [site.get("claim_rewards", {})])
		var guard := _linked_guard(session, String(node.get("placement_id", "")))
		var stacks: Array = guard.get("enemy_army", {}).get("stacks", [])
		_expect(not guard.is_empty() and stacks == GeneratedRewards.bank_guard_stacks(node), "generated Crypt guard fields its level's army: %s" % [stacks])
		_expect(int(guard.get("generated_bank_level", 0)) == level, "the guard records the bank level")
		var battle: Dictionary = BattleRulesScript.create_battle_payload(session, guard)
		var fielded := {}
		for stack in battle.get("stacks", []):
			if stack is Dictionary and String(stack.get("side", "")) == "enemy":
				fielded[String(stack.get("unit_id", ""))] = int(fielded.get(String(stack.get("unit_id", "")), 0)) + int(stack.get("base_count", 0))
		var expected := {}
		for stack in stacks:
			expected[String(stack.get("unit_id", ""))] = int(expected.get(String(stack.get("unit_id", "")), 0)) + int(stack.get("count", 0))
		_expect(not battle.is_empty() and fielded == expected, "the guard battle fields the level's army: %s, expected %s" % [fielded, expected])
		crypts.append({"placement_id": node.get("placement_id", ""), "level": level, "guard_power": int(round(_army_power(stacks))), "battle_enemy": fielded})
	return {"crypts": crypts.size(), "placements": crypts}

## Claiming pays the level's gold and nothing else on levels 1 and 2, and adds
## one artifact on level 3; no troops join and no fog lifts.
func _check_claims(session) -> Array:
	if session == null:
		return []
	var rows := []
	for level in [1, 3]:
		var hero: Vector2i = OverworldRulesScript.hero_position(session)
		var node := _bank_node(_key_for_level(level), hero.x, hero.y)
		node["placement_id"] = "creature_banks_claim_%d" % level
		node["collected"] = false
		var nodes: Array = session.overworld.get("resource_nodes", [])
		nodes.append(node)
		session.overworld["resource_nodes"] = nodes
		OverworldRulesScript.normalize_overworld_state(session)
		var index: int = session.overworld.get("resource_nodes", []).size() - 1
		var stored: Dictionary = session.overworld.get("resource_nodes", [])[index]
		_expect(int(stored.get(GeneratedRewards.BANK_LEVEL, 0)) == level and stored.has(NodePayload.PAYLOAD_ARTIFACT_RARITY), "the bank payload survives normalization")
		var resources_before: Dictionary = session.overworld.get("resources", {}).duplicate(true)
		var experience_before := int(session.overworld.get("hero", {}).get("experience", 0))
		var army_before := _army_headcount(session)
		var artifacts_before := _owned_artifacts(session)
		var result: Dictionary = OverworldRulesScript._collect_resource_node_result(session, {"index": index, "node": stored}, false)
		var expected: Dictionary = OverworldRulesScript.apply_reward_bonus(
			DifficultyRulesScript.scale_reward_resources(session, {"gold": CRYPT_GOLD[level - 1]}),
			int(HeroProgressionRulesScript.aggregate_bonuses(session.overworld.get("hero", {})).get("reward_bonus_pct", 0))
		)
		var delta := _resource_delta(resources_before, session.overworld.get("resources", {}))
		var gained := []
		for artifact_id in _owned_artifacts(session):
			if artifact_id not in artifacts_before:
				gained.append(artifact_id)
		_expect(bool(result.get("ok", false)), "level %d claim succeeds: %s" % [level, result.get("message", "")])
		_expect(delta == expected, "level %d claim pays its gold only: %s, expected %s" % [level, delta, expected])
		_expect(int(session.overworld.get("hero", {}).get("experience", 0)) == experience_before, "level %d claim pays no experience" % level)
		_expect(_army_headcount(session) == army_before, "level %d claim adds no troops" % level)
		_expect(int(result.get("site_reveal_tiles", 0)) == 0, "level %d claim lifts no fog" % level)
		_expect(gained.size() == (1 if CRYPT_ARTIFACT[level - 1] else 0), "level %d claim grants %s artifact: %s" % [level, "one" if CRYPT_ARTIFACT[level - 1] else "no", gained])
		rows.append({"level": level, "resources": delta, "artifacts": gained, "message": result.get("message", "")})
	return rows

func _bank_node(key: String, x: int, y: int) -> Dictionary:
	return GeneratedRewards.resolve({
		"placement_id": key,
		"kind": "resource_site",
		"h3m_type_id": CRYPT,
		"h3m_subtype": 0,
		"x": x,
		"y": y,
		"level": 0,
	})

func _key_for_level(level: int) -> String:
	for index in range(1000):
		var key := "creature_banks_level_%d_%d" % [level, index]
		if GeneratedRewards.bank_level_roll(key, CRYPT) == level:
			return key
	return ""

func _linked_guard(session, placement_id: String) -> Dictionary:
	for encounter in session.overworld.get("encounters", []):
		if encounter is Dictionary and String(encounter.get("target_placement_id", "")) == placement_id:
			return encounter
	return {}

func _generated_session(seed: String):
	var service: Variant = ClassDB.instantiate("MapPackageService")
	var generated: Dictionary = service.generate_random_map(_config("medium", 72, seed), {"startup_path": "creature_banks_report"})
	var adoption: Dictionary = service.convert_generated_payload(generated, {"feature_gate": REPORT_ID})
	var session = NativeRandomMapPackageSessionBridgeScript.build_session_from_adoption(adoption)
	if session == null or session.overworld.get("resource_nodes", []).is_empty():
		return null
	OverworldRulesScript.normalize_overworld_state(session)
	return session

func _army_power(stacks: Array) -> float:
	return float(load("res://scripts/core/AiHeroRules.gd").army_power(stacks))

func _army_headcount(session) -> int:
	var total := 0
	for stack in session.overworld.get("hero", {}).get("army", {}).get("stacks", []):
		total += int(stack.get("count", 0))
	return total

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
