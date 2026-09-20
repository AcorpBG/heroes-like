class_name TownDevelopmentRules
extends RefCounted

const DATA_PATH := "res://content/town_development.json"
const Heroes = preload("res://scripts/core/HeroCommandRules.gd")
const Progression = preload("res://scripts/core/HeroProgressionRules.gd")
const Artifacts = preload("res://scripts/core/ArtifactRules.gd")

static func data() -> Dictionary:
	return ContentService.load_json(DATA_PATH)

static func faction_id(town: Dictionary) -> String:
	return String(ContentService.get_town(String(town.get("town_id", ""))).get("faction_id", ""))

static func is_current(town: Dictionary) -> bool:
	return int(ContentService.get_town(String(town.get("town_id", ""))).get("development_version", 0)) == 1

static func satisfies(built: Array, required: String) -> bool:
	for id in built:
		var cursor := String(id)
		var seen := {}
		while cursor != "" and not seen.has(cursor):
			if cursor == required: return true
			seen[cursor] = true
			cursor = String(ContentService.get_building(cursor).get("upgrade_from", ""))
	return false

static func active_buildings(town: Dictionary) -> Array:
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
	# contributing income, growth or duplicate scene layers.
	var active: Array = []
	for id in result:
		var others := result.duplicate()
		others.erase(id)
		if not satisfies(others, String(id)): active.append(id)
	return active

static func choice_blocked(town: Dictionary, building: Dictionary) -> bool:
	var group := String(building.get("choice_group", ""))
	if group == "": return false
	for id in active_buildings(town):
		var b := ContentService.get_building(String(id))
		if b.get("choice_group", "") == group and b.get("choice_branch", 0) != building.get("choice_branch", 0): return true
	return false

static func has_dwelling_tier(town: Dictionary, tier: int) -> bool:
	for id in active_buildings(town):
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
	var built := active_buildings(town)
	for id in built:
		var b := ContentService.get_building(String(id))
		var tier := int(b.get("growth_tier", 0))
		bonuses[tier] = int(bonuses.get(tier, 0)) + int(b.get("growth_amount", 0))
	for id in built:
		var uid := String(ContentService.get_building(String(id)).get("unlock_unit_id", ""))
		if uid == "": continue
		var unit := ContentService.get_unit(uid)
		result[uid] = int(unit.get("growth", 1)) + int(bonuses.get(int(unit.get("tier", 0)), 0))
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

static func visiting_active_hero(session, town: Dictionary) -> bool:
	var id := String(session.overworld.get("hero", {}).get("id", ""))
	for hero in Heroes.stationed_heroes(session, town):
		if String(hero.get("id", "")) == id: return true
	return false

static func price(artifact: Dictionary) -> int:
	var tier := String(artifact.get("rarity", "common"))
	return int({"common": 1500, "uncommon": 2500, "rare": 4000, "epic": 6500, "legendary": 10000}.get(tier, 2500))

static func offers(town: Dictionary, day: int) -> Array:
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
	for i in range(mini(3, eligible.size())): result.append(eligible[(start+i) % eligible.size()])
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

static func service_actions(session, town: Dictionary) -> Array:
	var actions: Array = []
	if town.is_empty() or town.get("owner", "") != "player": return actions
	var resources: Dictionary = session.overworld.get("resources", {})
	var hero: Dictionary = session.overworld.get("hero", {})
	var present := visiting_active_hero(session, town)
	for id in active_buildings(town):
		var b := ContentService.get_building(String(id))
		if b.has("hero_visit_reward") and present:
			var claimed: Array = hero.get("town_training_claims", [])
			actions.append({"id":"town_train:"+String(id),"label":"Visit "+String(b.name),"summary":String(b.description),"disabled":id in claimed})
		var target := String(b.get("unlock_unit_id", ""))
		var base := String(ContentService.get_unit(target).get("upgrade_from", ""))
		if base != "":
			for holder in Heroes._stationed_holder_ids(session,town):
				var count := 0
				for stack in Heroes._holder_stacks(session,town,String(holder)):
					if stack.get("unit_id", "") == base: count += int(stack.get("count",0))
				if count <= 0: continue
				var cost := upgrade_cost(base,target,count)
				actions.append({"id":"town_upgrade:%s:%s" % [holder,base],"label":"Upgrade %d %s (%s)" % [count,ContentService.get_unit(base).get("name",base),Heroes._holder_label(session,town,String(holder))],"summary":"Train the entire stack into %s. Cost: %s." % [ContentService.get_unit(target).get("name",target),cost_text(cost)],"disabled":not can_pay(resources,cost)})
		if bool(b.get("artifact_exchange", false)) and present:
			var week := maxi(0,(int(session.day)-1)/7)
			var sold: Array = town.get("artifact_shop_purchases",{}).get(str(week),[])
			for aid in offers(town,session.day):
				var a := ContentService.get_artifact(String(aid))
				var cost := price(a)
				actions.append({"id":"town_buy:"+String(aid),"label":"Buy %s — %d gold" % [a.get("name",aid),cost],"summary":Artifacts.artifact_effect_summary(String(aid)),"disabled":aid in sold or Artifacts.has_artifact(hero,String(aid)) or int(resources.get("gold",0))<cost})
			for aid in Artifacts.normalize_hero_artifacts(hero.get("artifacts",{})).get("inventory",[]):
				var a := ContentService.get_artifact(String(aid))
				if bool(a.get("quest_item",false)): continue
				actions.append({"id":"town_sell:"+String(aid),"label":"Sell %s — %d gold" % [a.get("name",aid),price(a)/2],"summary":"Sell this unequipped artifact. The sale is permanent.","disabled":false})
	return actions

static func cost_text(cost: Dictionary) -> String:
	var parts: Array = []
	for key in cost: parts.append("%d %s" % [int(cost[key]),String(key).replace("_"," ")])
	return ", ".join(parts)

static func perform_service(session, town: Dictionary, action_id: String) -> Dictionary:
	# Rebuild authorization from current location, ownership, stock and funds.
	var allowed := false
	for action in service_actions(session,town):
		if action.id == action_id and not bool(action.get("disabled",false)): allowed=true; break
	if not allowed: return {"ok":false,"message":"This town service is no longer available."}
	var parts := action_id.split(":")
	var hero: Dictionary = session.overworld.get("hero",{}).duplicate(true)
	var resources: Dictionary = session.overworld.get("resources",{}).duplicate(true)
	var message := ""
	match parts[0]:
		"town_train":
			var b := ContentService.get_building(parts[1])
			var reward: Dictionary = b.get("hero_visit_reward",{})
			if reward.has("experience"): hero=Progression.add_experience(hero,int(reward.experience)).hero
			var command: Dictionary = hero.get("command",{}).duplicate(true)
			for stat in ["attack","defense","power","knowledge"]:
				command[stat]=int(command.get(stat,0))+int(reward.get(stat,0))
			hero["command"]=command
			var claims: Array = hero.get("town_training_claims",[]).duplicate()
			claims.append(parts[1]);hero["town_training_claims"]=claims
			message=String(b.description)
		"town_upgrade":
			var base := String(parts[2])
			var target := String(data().get("unit_upgrades",{}).get(base,""))
			var stacks := Heroes._holder_stacks(session,town,parts[1])
			var count := 0
			for stack in stacks:
				if stack.get("unit_id","")==base: count+=int(stack.get("count",0));stack["unit_id"]=target
			var cost := upgrade_cost(base,target,count)
			for key in cost: resources[key]=int(resources.get(key,0))-int(cost[key])
			Heroes._set_holder_stacks(session,town,parts[1],stacks)
			message="Upgraded %d creatures for %s." % [count,cost_text(cost)]
		"town_buy":
			var result := Artifacts.claim_artifact(hero,parts[1],"Purchased",false)
			if not bool(result.get("ok",false)): return result
			hero=result.hero
			resources["gold"]=int(resources.get("gold",0))-price(ContentService.get_artifact(parts[1]))
			var week := str(maxi(0,(int(session.day)-1)/7))
			var purchases: Dictionary = town.get("artifact_shop_purchases",{}).duplicate(true)
			var purchased: Array=purchases.get(week,[]);purchased.append(parts[1]);purchases[week]=purchased;town["artifact_shop_purchases"]=purchases
			message="Bought "+String(ContentService.get_artifact(parts[1]).get("name",parts[1]))+"."
		"town_sell":
			var result := Artifacts.remove_owned_artifact(hero,parts[1])
			if not bool(result.get("ok",false)): return result
			hero=result.hero
			resources["gold"]=int(resources.get("gold",0))+price(ContentService.get_artifact(parts[1]))/2
			message="Sold "+String(ContentService.get_artifact(parts[1]).get("name",parts[1]))+"."
	if parts[0] != "town_upgrade": session.overworld["hero"]=hero
	session.overworld["resources"]=resources
	return {"ok":true,"message":message}
