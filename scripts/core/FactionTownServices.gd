extends RefCounted

const Progression = preload("res://scripts/core/HeroProgressionRules.gd")
const Spells = preload("res://scripts/core/SpellRules.gd")

static func week(day: int) -> int:
	return maxi(0, (day - 1) / 7)

static func recruit_reward(town: Dictionary, service: Dictionary) -> Dictionary:
	var reward := {}
	for id in town.get("built_buildings", []):
		var uid := String(ContentService.get_building(String(id)).get("unlock_unit_id", ""))
		if uid == "": continue
		var unit := ContentService.get_unit(uid)
		# JSON numbers arrive as floats; Array membership is type-sensitive.
		var eligible := false
		for tier in service.get("tiers", []):
			if int(unit.get("tier", 0)) == int(tier): eligible = true
		if not eligible: continue
		reward[uid] = maxi(1, int(ceil(float(unit.get("growth", 1)) * float(service.get("growth_pct", 100)) / 100.0)))
	return reward

static func unavailable_reason(hero: Dictionary, town: Dictionary, building: Dictionary, day: int, resources: Dictionary) -> String:
	var service: Dictionary = building.get("faction_service", {})
	if service.is_empty() or String(building.get("id", "")) not in town.get("built_buildings", []): return "This faction building is not constructed."
	var holder := hero if service.get("scope", "town") == "hero" else town
	if int(holder.get("town_service_claims", {}).get(String(building.id), -1)) >= week(day): return "Already used this week. Available again next week."
	for key in service.get("cost", {}):
		if int(resources.get(key, 0)) < int(service.cost[key]): return "Not enough " + String(key).replace("_", " ") + "."
	if service.get("kind", "") == "restore_mana":
		var mana := Spells.mana_state(hero)
		if int(mana.current) >= int(mana.max): return "This hero's mana is already full."
	if service.get("kind", "") == "recruits" and recruit_reward(town, service).is_empty(): return "Build a matching creature dwelling first."
	return ""

static func perform(hero: Dictionary, town: Dictionary, building: Dictionary, day: int, resources: Dictionary) -> Dictionary:
	var reason := unavailable_reason(hero, town, building, day, resources)
	if reason != "": return {"ok": false, "hero": hero, "message": reason}
	var service: Dictionary = building.faction_service
	var result := hero.duplicate(true)
	match String(service.get("kind", "")):
		"resource_exchange":
			for key in service.get("reward", {}): resources[key] = int(resources.get(key, 0)) + int(service.reward[key])
		"restore_mana":
			result = Spells.refresh_daily_mana(result)
		"experience":
			result = Progression.add_experience(result, int(service.get("experience", 0))).hero
		"recruits":
			var pool: Dictionary = town.get("available_recruits", {}).duplicate(true)
			var recruits := recruit_reward(town, service)
			for id in recruits: pool[id] = int(pool.get(id, 0)) + int(recruits[id])
			town["available_recruits"] = pool
		_:
			return {"ok": false, "hero": hero, "message": "Unknown faction service."}
	for key in service.get("cost", {}): resources[key] = int(resources.get(key, 0)) - int(service.cost[key])
	var holder := result if service.get("scope", "town") == "hero" else town
	var claims: Dictionary = holder.get("town_service_claims", {}).duplicate(true)
	claims[String(building.id)] = week(day)
	holder["town_service_claims"] = claims
	return {"ok": true, "hero": result, "message": String(service.get("description", service.get("label", "Faction service completed.")))}

static func useful_to_ai(hero: Dictionary, town: Dictionary, building: Dictionary, day: int, resources: Dictionary) -> bool:
	if unavailable_reason(hero, town, building, day, resources) != "": return false
	var service: Dictionary = building.faction_service
	var earns_gold := int(service.get("reward", {}).get("gold", 0)) > int(service.get("cost", {}).get("gold", 0))
	if not earns_gold and int(resources.get("gold", 0)) - int(service.get("cost", {}).get("gold", 0)) < 2000: return false
	match String(service.get("kind", "")):
		"restore_mana":
			var mana := Spells.mana_state(hero)
			return int(mana.current) * 2 <= int(mana.max)
		"experience": return int(resources.get("gold", 0)) >= 4000
		"recruits":
			for id in recruit_reward(town, service):
				if int(town.get("available_recruits", {}).get(id, 0)) <= int(ContentService.get_unit(String(id)).get("growth", 1)): return true
			return false
		"resource_exchange":
			for key in ["wood", "ore"]:
				if int(resources.get(key, 0)) - int(service.get("cost", {}).get(key, 0)) < 10: return false
			var reward: Dictionary = service.get("reward", {})
			if reward.has("gold"): return int(resources.get("gold", 0)) < 8000
			for key in reward:
				if int(resources.get(key, 0)) <= 4: return true
	return false
