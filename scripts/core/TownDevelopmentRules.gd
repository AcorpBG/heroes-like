class_name TownDevelopmentRules
extends RefCounted

const DATA_PATH := "res://content/town_development.json"
const Heroes = preload("res://scripts/core/HeroCommandRules.gd")
const Progression = preload("res://scripts/core/HeroProgressionRules.gd")
const Artifacts = preload("res://scripts/core/ArtifactRules.gd")
const FactionServices = preload("res://scripts/core/FactionTownServices.gd")
const HumanEngine = preload("res://scripts/core/HumanEngine.gd")

static func data() -> Dictionary:
	return ContentService.load_json(DATA_PATH)

static func faction_id(town: Dictionary) -> String:
	return String(ContentService.get_town(String(town.get("town_id", ""))).get("faction_id", ""))

static func is_current(town: Dictionary) -> bool:
	return int(ContentService.get_town(String(town.get("town_id", ""))).get("development_version", 0)) == 1

## Town screens ask for the active stages and requirement checks hundreds of
## times per refresh (every build status, growth, income and tier check). The
## answers depend only on the town template, the built list and authored
## content, so they are memoized by those and dropped whenever the content
## cache reloads. Callers get copies, except from satisfied_ids.
static var _active_memo := {}
static var _satisfied_memo := {}
static var _memo_sources := []

static func _sync_memo_sources() -> void:
	var revision := ContentService.get_content_revision()
	var buildings := ContentService.load_json(ContentService.BUILDINGS_PATH)
	var towns := ContentService.load_json(ContentService.TOWNS_PATH)
	var development := ContentService.load_json(DATA_PATH)
	if _memo_sources.size() == 4 and _memo_sources[0] == revision and is_same(_memo_sources[1], buildings) and is_same(_memo_sources[2], towns) and is_same(_memo_sources[3], development):
		return
	_active_memo = {}
	_satisfied_memo = {}
	_memo_sources = [revision, buildings, towns, development]

static func satisfies(built: Array, required: String) -> bool:
	return _satisfied_ids(built).has(required)

## Every building a built list satisfies: each built stage and the stages it
## upgraded from. The memo's own dictionary: callers must not change it.
static func satisfied_ids(built: Array) -> Dictionary:
	return _satisfied_ids(built)

static func _satisfied_ids(built: Array) -> Dictionary:
	_sync_memo_sources()
	var key_parts := PackedStringArray()
	for id in built:
		key_parts.append(String(id))
	var key := "|".join(key_parts)
	if _satisfied_memo.has(key):
		return _satisfied_memo[key]
	var ids := {}
	for id in built:
		var cursor := String(id)
		while cursor != "" and not ids.has(cursor):
			ids[cursor] = true
			cursor = String(ContentService.get_building(cursor).get("upgrade_from", ""))
	if _satisfied_memo.size() > 512:
		_satisfied_memo = {}
	_satisfied_memo[key] = ids
	return ids

static func active_buildings(town: Dictionary) -> Array:
	_sync_memo_sources()
	var built_value: Variant = town.get("built_buildings", [])
	var key_parts := PackedStringArray([String(town.get("town_id", ""))])
	if built_value is Array:
		for value in built_value:
			key_parts.append(String(value))
	var key := "|".join(key_parts)
	if _active_memo.has(key):
		return (_active_memo[key] as Array).duplicate()
	var active := _compute_active_buildings(town)
	if _active_memo.size() > 256:
		_active_memo = {}
	_active_memo[key] = active.duplicate()
	return active

static func _compute_active_buildings(town: Dictionary) -> Array:
	var template := ContentService.get_town(String(town.get("town_id", "")))
	var result: Array = []
	var mapping: Dictionary = data().get("migration", {}).get(faction_id(town), {})
	var candidates: Array = template.get("starting_building_ids", []).duplicate()
	candidates.append_array(town.get("built_buildings", []))
	var choices := {}
	for value in candidates:
		var id := String(mapping.get(String(value), String(value)))
		var b := ContentService.get_building(id)
		if int(b.get("development_version", 0)) != 1: continue
		var group := String(b.get("choice_group", ""))
		var branch := int(b.get("choice_branch", 0))
		if group != "":
			if choices.has(group) and choices[group] != branch: continue
			choices[group] = branch
		if id not in result: result.append(id)
	# Persist only the active stage. Its ancestry satisfies prerequisites without
	# contributing income, growth or duplicate scene layers. A stage is ancestry
	# when the upgrade chain of another listed stage passes through it; each
	# chain also holds its own stage, so ancestry is held by two chains or more.
	var chain_counts := {}
	for id in result:
		var chain := {}
		var cursor := String(id)
		while cursor != "" and not chain.has(cursor):
			chain[cursor] = true
			chain_counts[cursor] = int(chain_counts.get(cursor, 0)) + 1
			cursor = String(ContentService.get_building(cursor).get("upgrade_from", ""))
	var active: Array = []
	for id in result:
		if int(chain_counts.get(String(id), 0)) < 2: active.append(id)
	return active

static func choice_blocked(town: Dictionary, building: Dictionary) -> bool:
	if String(building.get("choice_group", "")) == "": return false
	return choice_blocked_among(active_buildings(town), building)

## choice_blocked for a town whose active stages are already at hand.
static func choice_blocked_among(active: Array, building: Dictionary) -> bool:
	var group := String(building.get("choice_group", ""))
	if group == "": return false
	for id in active:
		var b := ContentService.get_building(String(id))
		if b.get("choice_group", "") == group and b.get("choice_branch", 0) != building.get("choice_branch", 0): return true
	return false

static func has_dwelling_tier(town: Dictionary, tier: int) -> bool:
	return has_dwelling_tier_among(active_buildings(town), tier)

## has_dwelling_tier for a town whose active stages are already at hand.
static func has_dwelling_tier_among(active: Array, tier: int) -> bool:
	for id in active:
		if int(ContentService.get_building(String(id)).get("dwelling_tier", 0)) == tier: return true
	return false

static func apply_defender_bonus(stacks: Array, town: Dictionary, context_type: String) -> void:
	if context_type not in ["town_defense", "town_assault"]: return
	var bonus := 0
	for id in active_buildings(town):
		bonus += int(ContentService.get_building(String(id)).get("defender_defense_bonus", 0))
	var side := "player" if context_type == "town_defense" else "enemy"
	for stack in stacks:
		if stack.get("side", "") == side: stack["defense"] = int(stack.get("defense", 0)) + bonus

static func migrate_town(town: Dictionary) -> void:
	if not is_current(town): return
	if int(town.get("development_version", 0)) != 1:
		town["legacy_built_buildings"] = town.get("built_buildings", []).duplicate(true)
		town["development_version"] = 1
	town["built_buildings"] = active_buildings(town)
	convert_reserves(town)

static func convert_reserves(town: Dictionary) -> void:
	var pool: Dictionary = town.get("available_recruits", {}).duplicate(true)
	for id in town.get("built_buildings", []):
		var unit_id := String(ContentService.get_building(String(id)).get("unlock_unit_id", ""))
		var base := String(ContentService.get_unit(unit_id).get("upgrade_from", ""))
		if base != "" and pool.has(base):
			pool[unit_id] = int(pool.get(unit_id, 0)) + int(pool[base])
			pool.erase(base)
	town["available_recruits"] = pool

static func growth(town: Dictionary) -> Dictionary:
	var result := {}
	var bonuses := {}
	var percent := 0
	var built := active_buildings(town)
	for id in built:
		var b := ContentService.get_building(String(id))
		var tier := int(b.get("growth_tier", 0))
		bonuses[tier] = int(bonuses.get(tier, 0)) + int(b.get("growth_amount", 0))
		percent += int(b.get("growth_percent", 0))
	# Fortifications raise every dwelling's whole week, flat bonuses included;
	# fractions round up, so a Citadel already brings a second T7.
	for id in built:
		var uid := String(ContentService.get_building(String(id)).get("unlock_unit_id", ""))
		if uid == "": continue
		var unit := ContentService.get_unit(uid)
		var weekly := int(unit.get("growth", 1)) + int(bonuses.get(int(unit.get("tier", 0)), 0))
		result[uid] = (weekly * (100 + percent) + 99) / 100
	return result

static func construction_growth(building: Dictionary) -> Dictionary:
	# Dwelling upgrades convert existing reserve and never grant a second week.
	if String(building.get("upgrade_from", "")) != "": return {}
	var uid := String(building.get("unlock_unit_id", ""))
	return {uid: int(ContentService.get_unit(uid).get("growth", 1))} if uid != "" else {}

static func income(town: Dictionary) -> Dictionary:
	var result := {}
	var faction := ContentService.get_faction(faction_id(town))
	for id in active_buildings(town):
		var b := ContentService.get_building(String(id))
		for resource in b.get("income", {}):
			result[resource] = int(result.get(resource, 0)) + int(b.income[resource])
		var amount := int(b.get("faction_resource_income", 0))
		if amount > 0:
			var resource := String(faction.get("town_resources", {}).get("main", ""))
			if resource != "": result[resource] = int(result.get(resource, 0)) + amount
	return result

static func price(artifact: Dictionary) -> int:
	var tier := String(artifact.get("rarity", "common"))
	return int({"common": 1500, "uncommon": 2500, "rare": 4000, "epic": 6500, "legendary": 10000}.get(tier, 2500))

static func offers(town: Dictionary, day: int, excluded_ids: Array = []) -> Array:
	var eligible: Array = []
	for a in ContentService.load_json("res://content/artifacts.json").get("items", []):
		# Authored quest/relic rewards stay outside the merchant inventory.
		if String(a.get("rarity", "common")) in ["common", "uncommon", "rare"] and not bool(a.get("quest_item", false)):
			eligible.append(String(a.id))
	eligible.sort()
	var result: Array = []
	if eligible.is_empty(): return result
	var week := maxi(0, (day - 1) / 7)
	var start := posmod(String(town.get("placement_id", "")).hash() + week * 3, eligible.size())
	# Scenario objective artifacts are skipped in place, so the rest of the
	# weekly rotation stays the same.
	for i in range(eligible.size()):
		if result.size() >= 3: break
		var id: String = eligible[(start+i) % eligible.size()]
		if id not in excluded_ids: result.append(id)
	return result

static func can_pay(resources: Dictionary, cost: Dictionary) -> bool:
	for key in cost:
		if int(resources.get(key, 0)) < int(cost[key]): return false
	return true

static func upgrade_cost(base: String, target: String, count: int) -> Dictionary:
	var before: Dictionary = ContentService.get_unit(base).get("cost", {})
	var after: Dictionary = ContentService.get_unit(target).get("cost", {})
	var cost := {}
	for key in after:
		var delta := maxi(0, int(after[key]) - int(before.get(key, 0))) * count
		if delta > 0: cost[key] = delta
	return cost

static func train_hero(hero: Dictionary, town: Dictionary, building_id: String) -> Dictionary:
	var building := ContentService.get_building(building_id)
	var reward: Dictionary = building.get("hero_visit_reward", {})
	var claims: Array = hero.get("town_training_claims", []).duplicate()
	if building_id not in active_buildings(town) or reward.is_empty() or building_id in claims:
		return {"ok": false, "hero": hero}
	var trained := hero.duplicate(true)
	if reward.has("experience"):
		trained = Progression.add_experience(trained, int(reward.experience)).hero
	var command: Dictionary = trained.get("command", {}).duplicate(true)
	for stat in ["attack", "defense", "power", "knowledge"]:
		command[stat] = int(command.get(stat, 0)) + int(reward.get(stat, 0))
	trained["command"] = command
	claims.append(building_id)
	trained["town_training_claims"] = claims
	return {"ok": true, "hero": trained}

static func upgrade_army(town: Dictionary, stacks: Array, base: String, resources: Dictionary) -> Dictionary:
	var target := String(data().get("unit_upgrades", {}).get(base, ""))
	var available := false
	for id in active_buildings(town):
		if target != "" and ContentService.get_building(String(id)).get("unlock_unit_id", "") == target:
			available = true
	var count := 0
	for stack in stacks:
		if stack.get("unit_id", "") == base: count += maxi(0, int(stack.get("count", 0)))
	var cost := upgrade_cost(base, target, count)
	if not available or count <= 0 or not can_pay(resources, cost):
		return {"ok": false, "stacks": stacks}
	var upgraded := stacks.duplicate(true)
	for stack in upgraded:
		if stack.get("unit_id", "") == base: stack["unit_id"] = target
	for key in cost: resources[key] = int(resources.get(key, 0)) - int(cost[key])
	return {"ok": true, "stacks": upgraded, "count": count, "cost": cost}

static func trade_artifact(hero: Dictionary, town: Dictionary, day: int, artifact_id: String, buying: bool, resources: Dictionary, excluded_ids: Array = []) -> Dictionary:
	var exchange := false
	for id in active_buildings(town):
		if ContentService.get_building(String(id)).get("artifact_exchange", false): exchange = true
	var artifact := ContentService.get_artifact(artifact_id)
	if not exchange or artifact.is_empty() or bool(artifact.get("quest_item", false)) or artifact_id in excluded_ids:
		return {"ok": false, "hero": hero}
	var week := str(maxi(0, (day - 1) / 7))
	var purchases: Dictionary = town.get("artifact_shop_purchases", {}).duplicate(true)
	var purchased: Array = purchases.get(week, [])
	var result: Dictionary
	if buying:
		if artifact_id not in offers(town, day, excluded_ids) or artifact_id in purchased or Artifacts.has_artifact(hero, artifact_id) or not can_pay(resources, {"gold": price(artifact)}):
			return {"ok": false, "hero": hero}
		result = Artifacts.claim_artifact(hero, artifact_id, "Purchased", false)
	else:
		if artifact_id not in Artifacts.normalize_hero_artifacts(hero.get("artifacts", {})).inventory:
			return {"ok": false, "hero": hero}
		result = Artifacts.remove_owned_artifact(hero, artifact_id)
	if not bool(result.get("ok", false)): return result
	resources["gold"] = int(resources.get("gold", 0)) + (-price(artifact) if buying else price(artifact) / 2)
	if buying:
		purchased.append(artifact_id)
		purchases[week] = purchased
		town["artifact_shop_purchases"] = purchases
	return result

static func objective_artifact_ids(session) -> Array:
	return HumanEngine.native_writing(&"TownDevelopmentRules.objective_artifact_ids", [session])

static func visiting_active_hero(session, town: Dictionary) -> bool:
	return HumanEngine.native_writing(&"TownDevelopmentRules.visiting_active_hero", [session, town])

static func service_actions(session, town: Dictionary) -> Array:
	return HumanEngine.native_writing(&"TownDevelopmentRules.service_actions", [session, town])

static func perform_service(session, town: Dictionary, action_id: String) -> Dictionary:
	return HumanEngine.native_writing(&"TownDevelopmentRules.perform_service", [session, town, action_id])
