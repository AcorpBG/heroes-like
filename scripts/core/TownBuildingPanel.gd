class_name TownBuildingPanel
extends RefCounted

## Read-only model for the popout opened by clicking a built Town building.
## Every building shows its description, effects and upgrade line (from
## TownConstructionBoard). Dwellings add recruitment and troop upgrades, the
## magic guild its spell shelves by level, the tavern its hireable heroes, the
## market its trading desk, and service buildings their visit and artifact
## orders. The popout is the only market and magic guild window. Never mutates
## session state; TownShell owns every order.

const SCHEMA := "town_building_panel_v1"
const TownRulesScript = preload("res://scripts/core/TownRules.gd")
const OverworldRulesScript = preload("res://scripts/core/OverworldRules.gd")
const HeroCommandRulesScript = preload("res://scripts/core/HeroCommandRules.gd")
const HeroProgressionRulesScript = preload("res://scripts/core/HeroProgressionRules.gd")
const SpellRulesScript = preload("res://scripts/core/SpellRules.gd")
const Board = preload("res://scripts/core/TownConstructionBoard.gd")

const KIND_DWELLING := "dwelling"
const KIND_GUILD := "guild"
const KIND_TAVERN := "tavern"
const KIND_MARKET := "market"
const KIND_ARTIFACTS := "artifact_exchange"
const KIND_TRAINING := "training"
const KIND_BUILDING := "building"

## `options.market_need` is a cost the player opened the market to cover; the
## market desk then suggests the trade for its first missing resource.
static func build(session, building_id: String, options: Dictionary = {}) -> Dictionary:
	if session == null:
		return {}
	var town: Dictionary = TownRulesScript.get_active_town(session)
	var building := ContentService.get_building(building_id)
	if town.is_empty() or building.is_empty():
		return {}
	var template := ContentService.get_town(String(town.get("town_id", "")))
	var faction_id := String(template.get("faction_id", ""))
	var board: Dictionary = Board.build_for_active_town(session)
	var slot: Dictionary = Board.slot_for_building(board, building_id)
	var kind := building_kind(building)
	var resources: Dictionary = session.overworld.get("resources", {}) if session.overworld.get("resources", {}) is Dictionary else {}
	var model := {
		"schema": SCHEMA,
		"building_id": building_id,
		"kind": kind,
		"name": String(building.get("name", building_id)),
		"description": String(building.get("description", "")),
		"subtitle": _subtitle(kind, building, slot, faction_id),
		"art_path": TownRulesScript.building_icon_path(building_id, faction_id),
		"faction_id": faction_id,
		"resources": resources.duplicate(true),
		"effects": effect_lines(building, town, session),
		"upgrade": _upgrade(slot),
		"services": _building_services(session, building_id, kind),
	}
	match kind:
		KIND_DWELLING:
			model["recruit"] = _recruitment(session, town, slot, building)
		KIND_GUILD:
			model["guild"] = _guild(session, town, slot)
		KIND_TAVERN:
			model["tavern"] = _tavern(session, resources)
		KIND_MARKET:
			var need: Dictionary = options.get("market_need", {}) if options.get("market_need", {}) is Dictionary else {}
			model["market"] = TownRulesScript.market_desk(session, need)
	return model

## The built market building whose popout trades for this town (its highest
## stage), or "" without a market.
static func market_building_id(town: Dictionary) -> String:
	return String(OverworldRulesScript.town_market_state(town).get("building_id", "")) if not town.is_empty() else ""

## The built magic guild stage whose popout shows this town's spells, or "".
static func guild_building_id(town: Dictionary) -> String:
	var best_id := ""
	var best_tier := 0
	for building_id_value in town.get("built_buildings", []):
		var building := ContentService.get_building(String(building_id_value))
		if int(building.get("spell_tier", 0)) > best_tier:
			best_tier = int(building.get("spell_tier", 0))
			best_id = String(building_id_value)
	return best_id

static func building_kind(building: Dictionary) -> String:
	if int(building.get("dwelling_tier", 0)) > 0 or String(building.get("unlock_unit_id", "")) != "":
		return KIND_DWELLING
	if int(building.get("spell_tier", 0)) > 0:
		return KIND_GUILD
	if String(building.get("id", "")) == HeroCommandRulesScript.HALL_BUILDING_ID:
		return KIND_TAVERN
	if building.get("market_profile", {}) is Dictionary and not building.get("market_profile", {}).is_empty():
		return KIND_MARKET
	if bool(building.get("artifact_exchange", false)):
		return KIND_ARTIFACTS
	if building.has("hero_visit_reward") or building.has("faction_service"):
		return KIND_TRAINING
	return KIND_BUILDING

## Short effect tags for the standing building, derived from its fields. The
## description carries the full sentence; these read at a glance.
static func effect_lines(building: Dictionary, town: Dictionary, session = null) -> Array:
	var lines := []
	var income: Dictionary = building.get("income", {}) if building.get("income", {}) is Dictionary else {}
	for resource_id in Board.RESOURCE_ORDER:
		if income.has(resource_id):
			lines.append("+%s %s per day" % [Board.format_amount(int(income[resource_id])), Board.resource_name(resource_id)])
	var faction_income := int(building.get("faction_resource_income", 0))
	if faction_income > 0:
		var faction := ContentService.get_faction(String(ContentService.get_town(String(town.get("town_id", ""))).get("faction_id", "")))
		var main_resource := String(faction.get("town_resources", {}).get("main", ""))
		lines.append("+%d %s per day" % [faction_income, Board.resource_name(main_resource) if main_resource != "" else "faction resource"])
	if int(building.get("defender_defense_bonus", 0)) > 0:
		lines.append("Defenders +%d defense" % int(building.get("defender_defense_bonus", 0)))
	if int(building.get("readiness_bonus", 0)) != 0:
		lines.append("Readiness %+d" % int(building.get("readiness_bonus", 0)))
	if int(building.get("spell_tier", 0)) > 0:
		lines.append("Spells up to level %d" % int(building.get("spell_tier", 0)))
	if int(building.get("growth_amount", 0)) > 0:
		var tier := int(building.get("growth_tier", 0))
		var target := _built_dwelling_unit_name(town, tier)
		lines.append("+%d %s per week" % [int(building.get("growth_amount", 0)), target if target != "" else "tier-%s recruits" % Board.roman(tier)])
	if int(building.get("growth_percent", 0)) > 0:
		lines.append("Creature growth +%d%%" % int(building.get("growth_percent", 0)))
	var visit_reward: Dictionary = building.get("hero_visit_reward", {}) if building.get("hero_visit_reward", {}) is Dictionary else {}
	if not visit_reward.is_empty():
		lines.append("Visiting hero %s, once" % _reward_text(visit_reward))
	var service: Dictionary = building.get("faction_service", {}) if building.get("faction_service", {}) is Dictionary else {}
	if not service.is_empty():
		lines.append("%s · %s" % [String(service.get("label", "Town service")), _resource_text(service.get("cost", {}))])
	var defense_effect: Dictionary = building.get("town_defense_effect", {}) if building.get("town_defense_effect", {}) is Dictionary else {}
	if not defense_effect.is_empty():
		lines.append("%s in town battles" % String(defense_effect.get("id", "defense ward")).replace("_", " ").capitalize())
	var market_profile: Dictionary = building.get("market_profile", {}) if building.get("market_profile", {}) is Dictionary else {}
	if not market_profile.is_empty():
		lines.append("Trades every resource")
		if int(market_profile.get("tier", 1)) >= 2:
			lines.append("Better rates, larger weekly limits")
	if bool(building.get("artifact_exchange", false)):
		lines.append("Artifact trade, offers refresh weekly")
	if String(building.get("id", "")) == HeroCommandRulesScript.HALL_BUILDING_ID:
		lines.append("Hire heroes, up to %d in command" % HeroCommandRulesScript.HERO_LIMIT)
	var growth_bonus: Dictionary = building.get("growth_bonus", {}) if building.get("growth_bonus", {}) is Dictionary else {}
	for unit_id in growth_bonus:
		lines.append("+%d %s per week" % [int(growth_bonus[unit_id]), String(ContentService.get_unit(String(unit_id)).get("name", unit_id))])
	var discounts: Dictionary = building.get("recruitment_discount_percent", {}) if building.get("recruitment_discount_percent", {}) is Dictionary else {}
	for unit_id in discounts:
		lines.append("%d%% off %s" % [int(discounts[unit_id]), String(ContentService.get_unit(String(unit_id)).get("name", unit_id))])
	if int(building.get("pressure_bonus", 0)) != 0:
		lines.append("Frontier pressure %+d" % int(building.get("pressure_bonus", 0)))
	var capital_project: Dictionary = building.get("capital_project", {}) if building.get("capital_project", {}) is Dictionary else {}
	if not capital_project.is_empty():
		lines.append("Capital project")
	return lines

# --- upgrade line ---------------------------------------------------------------

static func _upgrade(slot: Dictionary) -> Dictionary:
	if slot.is_empty():
		return {"has_line": false}
	var stages: Array = slot.get("stages", []).duplicate(true)
	var next_id := String(slot.get("next_id", ""))
	var current_id := String(slot.get("current_id", ""))
	var next_building := ContentService.get_building(next_id) if next_id != "" else {}
	var result := {
		"has_line": stages.size() > 1,
		"slot_id": String(slot.get("id", "")),
		"stages": stages,
		"current_id": current_id,
		"next_id": next_id,
		"next_name": String(next_building.get("name", next_id)),
		"next_description": String(next_building.get("description", "")),
		"complete": next_id == "",
		"status": String(slot.get("status", "")),
		"status_text": String(slot.get("status_text", "")),
		"status_detail": String(slot.get("status_detail", "")),
		"verb": String(slot.get("verb", "")),
		"cost": slot.get("cost", {}).duplicate(true),
		"shortfall": slot.get("shortfall", {}).duplicate(true),
		"missing_requirements": slot.get("missing_requirements", []).duplicate(),
		"forgone_unit_names": slot.get("forgone_unit_names", []).duplicate(),
		"current_unit_id": String(ContentService.get_building(current_id).get("unlock_unit_id", "")) if current_id != "" else "",
		"next_unit_id": String(next_building.get("unlock_unit_id", "")),
	}
	return result

# --- dwelling -------------------------------------------------------------------

static func _recruitment(session, town: Dictionary, slot: Dictionary, building: Dictionary) -> Dictionary:
	var line_unit_ids := []
	for stage in slot.get("stages", []):
		var unit_id := String(stage.get("unit_id", ""))
		if unit_id != "" and unit_id not in line_unit_ids:
			line_unit_ids.append(unit_id)
	if line_unit_ids.is_empty():
		line_unit_ids.append(String(building.get("unlock_unit_id", "")))
	var units := []
	for row_value in TownRulesScript.get_muster_catalog(session):
		if not (row_value is Dictionary) or String(row_value.get("unit_id", "")) not in line_unit_ids:
			continue
		units.append(recruit_card(row_value))
	var base_unit_ids := []
	for unit_id in line_unit_ids:
		var base_id := String(ContentService.get_unit(String(unit_id)).get("upgrade_from", ""))
		if base_id != "":
			base_unit_ids.append(base_id)
	var troop_upgrades := []
	for action in TownRulesScript.get_response_actions(session):
		var parts := String(action.get("id", "")).split(":")
		if parts.size() == 3 and parts[0] == "town_upgrade" and parts[2] in base_unit_ids:
			troop_upgrades.append(_action_entry(action))
	return {
		"line_unit_ids": line_unit_ids,
		"units": units,
		"destination": String(HeroCommandRulesScript.town_recruitment_destination(session, town).get("summary", "")),
		"troop_upgrades": troop_upgrades,
	}

## Every creature the town can muster, as the same recruit cards the dwelling
## popouts show, with all stationed-troop upgrades. Read-only.
static func muster(session) -> Dictionary:
	if session == null:
		return {}
	var town: Dictionary = TownRulesScript.get_active_town(session)
	if town.is_empty():
		return {}
	var units := []
	for row_value in TownRulesScript.get_muster_catalog(session):
		if row_value is Dictionary:
			units.append(recruit_card(row_value))
	var troop_upgrades := []
	for action in TownRulesScript.get_response_actions(session):
		if String(action.get("id", "")).begins_with("town_upgrade:"):
			troop_upgrades.append(_action_entry(action))
	var resources: Dictionary = session.overworld.get("resources", {}) if session.overworld.get("resources", {}) is Dictionary else {}
	return {
		"schema": SCHEMA,
		"kind": "muster",
		"units": units,
		"destination": String(HeroCommandRulesScript.town_recruitment_destination(session, town).get("summary", "")),
		"troop_upgrades": troop_upgrades,
		"resources": resources.duplicate(true),
	}

## One muster catalog row as a recruit card: the creature's battle profile
## plus reserve, growth, price and what the stores can pay for now.
static func recruit_card(row: Dictionary) -> Dictionary:
	var unit_id := String(row.get("unit_id", ""))
	var direct := int(row.get("direct_affordable_count", 0))
	return unit_card(unit_id).merged({
		"available": int(row.get("available_count", 0)),
		"weekly_growth": int(row.get("weekly_growth", 0)),
		"unit_cost": row.get("unit_cost", {}).duplicate(true) if row.get("unit_cost", {}) is Dictionary else {},
		"max_now": direct,
		"market_max": int(row.get("market_affordable_count", 0)),
		"status": String(row.get("catalog_status", "")),
		"status_detail": String(row.get("catalog_status_detail", "")),
		"disabled": bool(row.get("disabled", true)) or direct <= 0,
	}, true)

## Battle profile of one creature for recruitment and upgrade cards.
static func unit_card(unit_id: String) -> Dictionary:
	var unit := ContentService.get_unit(unit_id)
	var abilities := []
	for ability in unit.get("abilities", []):
		if ability is Dictionary:
			abilities.append({"name": String(ability.get("name", ability.get("id", ""))), "description": String(ability.get("description", ""))})
	var ranged := bool(unit.get("ranged", false)) or String(unit.get("role", "")) == "ranged"
	return {
		"unit_id": unit_id,
		"name": String(unit.get("name", unit_id)),
		"tier": int(unit.get("tier", 0)),
		"role": "ranged" if ranged else "melee",
		"attack": int(unit.get("attack", 0)),
		"defense": int(unit.get("defense", 0)),
		"min_damage": int(unit.get("min_damage", 0)),
		"max_damage": int(unit.get("max_damage", 0)),
		"hp": int(unit.get("hp", 0)),
		"speed": int(unit.get("speed", 0)),
		"initiative": int(unit.get("initiative", 0)),
		"shots": int(unit.get("shots", 0)) if ranged else 0,
		"abilities": abilities,
		"portrait_path": String(ContentService.get_unit_art(unit_id).get("portrait", "")),
	}

# --- magic guild ----------------------------------------------------------------

static func _guild(session, town: Dictionary, slot: Dictionary) -> Dictionary:
	var stages: Array = slot.get("stages", [])
	var current_level := TownRulesScript.current_spell_tier(town)
	var visitor: Dictionary = HeroCommandRulesScript.town_defending_hero(session, town)
	var levels := []
	var seen := []
	for index in range(stages.size()):
		var stage: Dictionary = stages[index]
		var level := int(ContentService.get_building(String(stage.get("building_id", ""))).get("spell_tier", index + 1))
		var spells := []
		for spell_id_value in TownRulesScript.spell_ids_through_tier(town, level):
			var spell_id := String(spell_id_value)
			if spell_id in seen:
				continue
			seen.append(spell_id)
			spells.append(spell_entry(spell_id, visitor))
		levels.append({
			"level": level,
			"building_id": String(stage.get("building_id", "")),
			"building_name": String(stage.get("name", "")),
			"built": level <= current_level,
			"spells": spells,
		})
	return {
		"current_level": current_level,
		"max_level": levels.size(),
		"visitor_name": String(visitor.get("name", "")),
		"levels": levels,
	}

static func spell_entry(spell_id: String, visitor: Dictionary = {}) -> Dictionary:
	var spell := ContentService.get_spell(spell_id)
	var school_id := String(spell.get("school_id", ""))
	return {
		"id": spell_id,
		"name": String(spell.get("name", spell_id)),
		"tier": int(spell.get("tier", 0)),
		"school_id": school_id,
		"school_name": school_id.replace("_", " ").capitalize(),
		"context": "Adventure" if String(spell.get("context", "")) == "overworld" else "Battle",
		"mana": int(spell.get("mana_cost", 0)),
		"category": SpellRulesScript.spell_category_label(spell),
		"summary": SpellRulesScript._spell_effect_summary(spell, visitor),
		"description": String(spell.get("description", "")),
		"icon_path": SpellRulesScript.spell_icon_path(spell_id),
		"known": not visitor.is_empty() and SpellRulesScript.knows_spell(visitor, spell_id),
	}

# --- tavern ---------------------------------------------------------------------

static func _tavern(session, resources: Dictionary) -> Dictionary:
	var count := HeroCommandRulesScript.player_hero_count(session)
	var limit := HeroCommandRulesScript.HERO_LIMIT
	var actions := {}
	for action in TownRulesScript.get_tavern_actions(session):
		actions[String(action.get("id", ""))] = action
	var heroes := []
	for hero_id_value in HeroCommandRulesScript.tavern_offer_ids(session):
		var hero_id := String(hero_id_value)
		var card := hero_card(hero_id)
		if card.is_empty():
			continue
		_apply_tavern_offer(card, HeroCommandRulesScript.tavern_offer_preview(session, hero_id))
		var action_id := "hire_hero:%s" % hero_id
		var shortfall := Board._shortfall(card.cost, resources)
		var reason := ""
		if count >= limit:
			reason = "Command is full (%d of %d heroes)." % [count, limit]
		elif not shortfall.is_empty():
			reason = "Short %s." % _resource_text(shortfall)
		elif not actions.has(action_id):
			reason = "Not available for hire here."
		card["action_id"] = action_id
		card["shortfall"] = shortfall
		card["disabled"] = reason != "" or bool(actions.get(action_id, {}).get("disabled", true))
		card["disabled_reason"] = reason
		heroes.append(card)
	var days := HeroCommandRulesScript.days_until_tavern_rotation(session)
	return {
		"hero_count": count,
		"hero_limit": limit,
		"heroes": heroes,
		"offer_size": HeroCommandRulesScript.TAVERN_OFFER_SIZE,
		"days_until_rotation": days,
		"next_rotation_day": int(session.day) + days,
	}

## Portrait, class and command profile of a hireable hero.
static func hero_card(hero_id: String) -> Dictionary:
	var hero := ContentService.get_hero(hero_id)
	if hero.is_empty():
		return {}
	var command: Dictionary = hero.get("command", {}) if hero.get("command", {}) is Dictionary else {}
	var specialties := []
	for specialty_id in hero.get("starting_specialties", []):
		var specialty: Dictionary = HeroProgressionRulesScript.specialty_definition(String(specialty_id))
		specialties.append(String(specialty.get("name", String(specialty_id).capitalize())))
	var traits := []
	for trait_id in hero.get("battle_traits", []):
		traits.append(String(trait_id).replace("_", " ").capitalize())
	var spells := []
	for spell_id in hero.get("starting_spell_ids", []):
		var spell := ContentService.get_spell(String(spell_id))
		spells.append({"id": String(spell_id), "name": String(spell.get("name", spell_id)), "icon_path": SpellRulesScript.spell_icon_path(String(spell_id))})
	return {
		"hero_id": hero_id,
		"name": String(hero.get("name", hero_id)),
		"class_name": HeroCommandRulesScript.hero_archetype_label(hero),
		"summary": String(hero.get("roster_summary", "")),
		"identity": String(hero.get("identity_summary", "")),
		"portrait_path": String(ContentService.get_hero_art(hero_id).get("portrait", "")),
		"attack": int(command.get("attack", 0)),
		"defense": int(command.get("defense", 0)),
		"power": int(command.get("power", 0)),
		"knowledge": int(command.get("knowledge", 0)),
		"movement": int(hero.get("base_movement", 0)),
		"specialties": specialties,
		"traits": traits,
		"spells": spells,
		"cost": HeroCommandRulesScript.hero_recruit_cost(hero),
	}

## This week's offer on the card: the level the hero arrives at, the stats
## and specialties that level brings, its movement and its starting army.
static func _apply_tavern_offer(card: Dictionary, recruit: Dictionary) -> void:
	if recruit.is_empty():
		return
	var command: Dictionary = recruit.get("command", {}) if recruit.get("command", {}) is Dictionary else {}
	for stat in ["attack", "defense", "power", "knowledge"]:
		card[stat] = int(command.get(stat, card.get(stat, 0)))
	card["level"] = int(recruit.get("level", 1))
	card["movement"] = int(recruit.get("movement", {}).get("max", card.get("movement", 0)))
	var specialties := []
	var seen := {}
	for specialty_id_value in recruit.get("specialties", []):
		var specialty_id := String(specialty_id_value)
		if seen.has(specialty_id):
			continue
		seen[specialty_id] = true
		var rank := HeroProgressionRulesScript.specialty_rank(recruit, specialty_id)
		var specialty_name := String(HeroProgressionRulesScript.specialty_definition(specialty_id).get("name", specialty_id.capitalize()))
		specialties.append(specialty_name if rank <= 1 else "%s %s" % [specialty_name, HeroProgressionRulesScript.rank_label(rank)])
	card["specialties"] = specialties
	var army := []
	for stack in recruit.get("army", {}).get("stacks", []):
		var unit_id := String(stack.get("unit_id", ""))
		var art := ContentService.get_unit_art(unit_id)
		army.append({
			"unit_id": unit_id,
			"name": String(ContentService.get_unit(unit_id).get("name", unit_id)),
			"count": int(stack.get("count", 0)),
			"icon_path": String(art.get("battle_icon", art.get("portrait", ""))),
		})
	card["army"] = army

# --- services -------------------------------------------------------------------

## Orders this building offers in place: hero visits, faction services and the
## artifact exchange. The market trades through its own desk.
static func _building_services(session, building_id: String, kind: String) -> Array:
	var services := []
	for action in TownRulesScript.get_response_actions(session):
		var action_id := String(action.get("id", ""))
		var parts := action_id.split(":")
		if parts.size() < 2:
			continue
		var own := parts[0] in ["town_train", "town_faction"] and parts[1] == building_id
		var exchange := kind == KIND_ARTIFACTS and parts[0] in ["town_buy", "town_sell"]
		if own or exchange:
			services.append(_action_entry(action))
	return services

static func _action_entry(action: Dictionary) -> Dictionary:
	return {
		"id": String(action.get("id", "")),
		"label": String(action.get("label", action.get("id", ""))),
		"summary": String(action.get("summary", "")),
		"disabled": bool(action.get("disabled", false)),
	}

# --- text helpers ---------------------------------------------------------------

static func _subtitle(kind: String, building: Dictionary, slot: Dictionary, faction_id: String) -> String:
	var faction_word := String(ContentService.get_faction(faction_id).get("name", "")).split(" ")[0]
	var stage_count := int(slot.get("stage_count", 1))
	var stage_text := " · stage %d of %d" % [int(slot.get("done_count", 1)), stage_count] if stage_count > 1 else ""
	match kind:
		KIND_DWELLING:
			return "Tier %s dwelling%s" % [Board.roman(int(building.get("dwelling_tier", 0))), stage_text]
		KIND_GUILD:
			return "Magic guild · level %d of %d" % [int(building.get("spell_tier", 0)), stage_count]
		KIND_TAVERN:
			return "Tavern · hire heroes"
	var category := String(building.get("category", "support")).capitalize()
	if String(building.get("faction_id", "")) != "" and faction_word != "":
		return "%s signature%s" % [faction_word, stage_text]
	return "%s building%s" % [category, stage_text]

static func _built_dwelling_unit_name(town: Dictionary, tier: int) -> String:
	if tier <= 0:
		return ""
	var template := ContentService.get_town(String(town.get("town_id", "")))
	var best_stage := 0
	var name := ""
	for building_id in Board.town_building_ids(template):
		var building := ContentService.get_building(String(building_id))
		if int(building.get("dwelling_tier", 0)) != tier or building_id not in town.get("built_buildings", []):
			continue
		if int(building.get("stage", 1)) > best_stage:
			best_stage = int(building.get("stage", 1))
			name = String(ContentService.get_unit(String(building.get("unlock_unit_id", ""))).get("name", ""))
	return name

static func _resource_text(resources: Variant) -> String:
	if not (resources is Dictionary) or resources.is_empty():
		return "nothing"
	var parts := []
	for resource_id in Board.RESOURCE_ORDER:
		if resources.has(resource_id):
			parts.append("%s %s" % [Board.format_amount(int(resources[resource_id])), Board.resource_name(resource_id)])
	for resource_id in resources:
		if String(resource_id) not in Board.RESOURCE_ORDER:
			parts.append("%s %s" % [Board.format_amount(int(resources[resource_id])), String(resource_id).replace("_", " ")])
	return ", ".join(parts)

static func _reward_text(reward: Dictionary) -> String:
	var parts := []
	for key in reward:
		var amount := int(reward[key])
		parts.append(("%s experience" % Board.format_amount(amount)) if String(key) == "experience" else ("+%d %s" % [amount, String(key)]))
	return ", ".join(parts)
