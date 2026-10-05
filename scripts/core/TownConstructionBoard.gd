class_name TownConstructionBoard
extends RefCounted

## Read-only construction board for the full-screen Town construction screen.
## Groups a town template's buildings into the fixed slots declared by
## content/town_construction_layout.json and derives each slot's next order
## from the authoritative build catalog. Never mutates town or session state.

const LAYOUT_PATH := "res://content/town_construction_layout.json"
const SCHEMA := "town_construction_board_v1"
const TownRulesScript = preload("res://scripts/core/TownRules.gd")
const TownDevelopment = preload("res://scripts/core/TownDevelopmentRules.gd")

const STATUS_COMPLETE := "complete"
const STATUS_READY := "ready"
const STATUS_TRADE := "trade"
const STATUS_SHORT := "short"
const STATUS_LOCKED := "locked"
const STATUS_TOMORROW := "tomorrow"
const RESOURCE_ORDER := ["gold", "wood", "ore", "aetherglass", "embergrain", "peatwax", "verdant_grafts", "brass_scrip", "memory_salt"]
const ROMAN := ["", "I", "II", "III", "IV", "V", "VI", "VII"]

static func layout() -> Dictionary:
	return ContentService.load_json(LAYOUT_PATH)

## Builds the board for the session's active town. Call inside the caller's
## TownRules/OverworldRules read scopes when reading repeatedly.
static func build_for_active_town(session) -> Dictionary:
	var town: Dictionary = TownRulesScript.get_active_town(session)
	if town.is_empty():
		return {}
	var resources: Dictionary = session.overworld.get("resources", {}) if session.overworld.get("resources", {}) is Dictionary else {}
	var rows_by_building := {}
	for row_value in TownRulesScript.get_build_catalog(session):
		if row_value is Dictionary:
			rows_by_building[String(row_value.get("building_id", ""))] = row_value
	return build(town, int(session.day), resources, rows_by_building)

static func build(town: Dictionary, day: int, resources: Dictionary, catalog_by_building: Dictionary) -> Dictionary:
	var template := ContentService.get_town(String(town.get("town_id", "")))
	var faction_id := String(template.get("faction_id", ""))
	var town_ids := town_building_ids(template)
	var active: Array = TownDevelopment.active_buildings(town) if TownDevelopment.is_current(town) else town.get("built_buildings", []).duplicate()
	var built_today := day > 0 and int(town.get("last_build_day", 0)) == day
	var context := {
		"town": town,
		"day": day,
		"faction_id": faction_id,
		"active": active,
		"resources": resources,
		"catalog": catalog_by_building,
		"built_today": built_today,
	}
	var rows := []
	var assigned := {}
	var slot_count := 0
	for row_value in layout().get("rows", []):
		if not (row_value is Dictionary):
			continue
		var row_spec: Dictionary = row_value
		var slots := []
		for slot_value in row_spec.get("slots", []):
			if not (slot_value is Dictionary):
				continue
			var slot := _build_slot(slot_value, String(row_spec.get("id", "")), town_ids, context)
			if slot.is_empty():
				continue
			for building_id in slot.get("building_ids", []):
				assigned[building_id] = String(slot.get("id", ""))
			slots.append(slot)
			slot_count += 1
		var faction_word := String(ContentService.get_faction(faction_id).get("name", "Faction")).split(" ")[0]
		rows.append({
			"id": String(row_spec.get("id", "")),
			"title": String(row_spec.get("title", "")).replace("{faction}", faction_word),
			"subtitle": String(row_spec.get("subtitle", "")).replace("{faction}", faction_word),
			"slots": slots,
		})
	var unassigned := []
	for building_id in town_ids:
		if not assigned.has(building_id):
			unassigned.append(building_id)
	return {
		"schema": SCHEMA,
		"town_id": String(template.get("id", town.get("town_id", ""))),
		"town_name": String(template.get("name", town.get("town_id", ""))),
		"faction_id": faction_id,
		"faction_name": String(ContentService.get_faction(faction_id).get("name", "")),
		"day": day,
		"built_today": built_today,
		"rows": rows,
		"slot_count": slot_count,
		"unassigned_building_ids": unassigned,
	}

static func town_building_ids(template: Dictionary) -> Array:
	var ids := []
	for source in [template.get("starting_building_ids", []), template.get("buildable_building_ids", [])]:
		if not (source is Array):
			continue
		for value in source:
			var building_id := String(value)
			if building_id != "" and building_id not in ids and not ContentService.get_building(building_id).is_empty():
				ids.append(building_id)
	return ids

static func slot_for_building(board: Dictionary, building_id: String) -> Dictionary:
	for row in board.get("rows", []):
		for slot in row.get("slots", []):
			if building_id in slot.get("building_ids", []):
				return slot
	return {}

static func slot_by_id(board: Dictionary, slot_id: String) -> Dictionary:
	for row in board.get("rows", []):
		for slot in row.get("slots", []):
			if String(slot.get("id", "")) == slot_id:
				return slot
	return {}

static func ordered_slots(board: Dictionary) -> Array:
	var slots := []
	for row in board.get("rows", []):
		slots.append_array(row.get("slots", []))
	return slots

static func format_amount(value: int) -> String:
	var digits := str(absi(value))
	var grouped := ""
	while digits.length() > 3:
		grouped = "," + digits.substr(digits.length() - 3) + grouped
		digits = digits.substr(0, digits.length() - 3)
	return ("-" if value < 0 else "") + digits + grouped

static func resource_name(resource_id: String) -> String:
	return resource_id.replace("_", " ")

static func roman(tier: int) -> String:
	return ROMAN[tier] if tier > 0 and tier < ROMAN.size() else str(tier)

# --- slot construction ---------------------------------------------------------

static func _build_slot(spec: Dictionary, row_id: String, town_ids: Array, context: Dictionary) -> Dictionary:
	var slot := {
		"id": String(spec.get("id", "")),
		"row_id": row_id,
		"blurb": String(spec.get("blurb", "")),
		"line_title": String(spec.get("title", "")),
		"tier": 0,
		"tier_label": "",
	}
	if spec.has("line_id"):
		var chain := _line_chain(String(spec.get("line_id", "")), town_ids)
		if chain.is_empty():
			return {}
		slot["kind"] = "line"
		return _finish_chain_slot(slot, chain, context)
	if spec.has("building_id"):
		var building_id := String(spec.get("building_id", ""))
		if building_id not in town_ids:
			return {}
		slot["kind"] = "single"
		return _finish_chain_slot(slot, [building_id], context)
	if spec.has("faction_special"):
		var specials := []
		for building_id in town_ids:
			var building := ContentService.get_building(building_id)
			if String(building.get("faction_id", "")) != "" and int(building.get("dwelling_tier", 0)) == 0:
				specials.append(building_id)
		specials.sort()
		var index := int(spec.get("faction_special", 0)) - 1
		if index < 0 or index >= specials.size():
			return {}
		slot["kind"] = "single"
		var special_id := String(specials[index])
		if String(slot.blurb) == "":
			slot["blurb"] = _first_sentence(String(ContentService.get_building(special_id).get("description", "")))
		return _finish_chain_slot(slot, [special_id], context)
	if spec.has("dwelling_tier"):
		return _dwelling_slot(slot, int(spec.get("dwelling_tier", 0)), town_ids, context)
	return {}

static func _line_chain(line_id: String, town_ids: Array) -> Array:
	var stages := []
	for building_id in town_ids:
		var building := ContentService.get_building(building_id)
		if String(building.get("line_id", "")) == line_id and int(building.get("dwelling_tier", 0)) == 0:
			stages.append({"id": building_id, "stage": int(building.get("stage", 1))})
	stages.sort_custom(func(a, b): return int(a.stage) < int(b.stage))
	var chain := []
	for entry in stages:
		chain.append(String(entry.id))
	return chain

static func _dwelling_branches(tier: int, town_ids: Array) -> Array:
	var by_branch := {}
	for building_id in town_ids:
		var building := ContentService.get_building(building_id)
		if int(building.get("dwelling_tier", 0)) != tier:
			continue
		var branch := int(building.get("choice_branch", 1))
		if not by_branch.has(branch):
			by_branch[branch] = []
		by_branch[branch].append({"id": building_id, "stage": int(building.get("stage", 1))})
	var branches := []
	var keys := by_branch.keys()
	keys.sort()
	for branch in keys:
		var entries: Array = by_branch[branch]
		entries.sort_custom(func(a, b): return int(a.stage) < int(b.stage))
		var chain := []
		for entry in entries:
			chain.append(String(entry.id))
		branches.append({"branch": int(branch), "chain": chain})
	return branches

static func _dwelling_slot(slot: Dictionary, tier: int, town_ids: Array, context: Dictionary) -> Dictionary:
	var branches := _dwelling_branches(tier, town_ids)
	if branches.is_empty():
		return {}
	slot["tier"] = tier
	slot["tier_label"] = roman(tier)
	var all_ids := []
	var chosen := {}
	for branch in branches:
		all_ids.append_array(branch.chain)
		for building_id in branch.chain:
			if _stage_done(String(building_id), context):
				chosen = branch
	if branches.size() > 1 and chosen.is_empty():
		# Open exclusive choice: both base dwellings share cost and prerequisites.
		slot["kind"] = "choice"
		var options := []
		for branch in branches:
			var chain: Array = branch.chain
			var base_id := String(chain[0])
			var upgrade_id := String(chain[1]) if chain.size() > 1 else ""
			var base := ContentService.get_building(base_id)
			var unit_id := String(base.get("unlock_unit_id", ""))
			var upgrade_unit_id := String(ContentService.get_building(upgrade_id).get("unlock_unit_id", "")) if upgrade_id != "" else ""
			options.append({
				"branch": int(branch.branch),
				"building_id": base_id,
				"building_name": String(base.get("name", base_id)),
				"upgrade_building_id": upgrade_id,
				"unit_id": unit_id,
				"unit_name": String(ContentService.get_unit(unit_id).get("name", unit_id)),
				"upgrade_unit_id": upgrade_unit_id,
				"upgrade_unit_name": String(ContentService.get_unit(upgrade_unit_id).get("name", upgrade_unit_id)),
			})
		slot["options"] = options
		slot["building_ids"] = all_ids
		slot["stages"] = []
		slot["done_count"] = 0
		slot["stage_count"] = int(branches[0].chain.size())
		slot["current_id"] = ""
		slot["next_id"] = String(options[0].building_id)
		slot["art_building_id"] = String(options[0].building_id)
		slot["built"] = false
		slot["title"] = " or ".join(options.map(func(option): return String(option.unit_name)))
		_apply_status(slot, String(options[0].building_id), context, "Choose")
		return slot
	var selected: Dictionary = chosen if not chosen.is_empty() else branches[0]
	slot["kind"] = "dwelling"
	var result := _finish_chain_slot(slot, selected.chain, context)
	result["building_ids"] = all_ids
	var forgone := []
	for branch in branches:
		if int(branch.branch) != int(selected.branch):
			var base := ContentService.get_building(String(branch.chain[0]))
			forgone.append(String(ContentService.get_unit(String(base.get("unlock_unit_id", ""))).get("name", "")))
	result["forgone_unit_names"] = forgone
	var display_id := String(result.get("current_id", "")) if String(result.get("current_id", "")) != "" else String(selected.chain[0])
	var unit_id := String(ContentService.get_building(display_id).get("unlock_unit_id", ""))
	result["title"] = String(ContentService.get_unit(unit_id).get("name", result.get("title", "")))
	return result

static func _finish_chain_slot(slot: Dictionary, chain: Array, context: Dictionary) -> Dictionary:
	var stages := []
	var current_id := ""
	var next_id := ""
	var done_count := 0
	for building_id_value in chain:
		var building_id := String(building_id_value)
		var done := _stage_done(building_id, context)
		if done:
			current_id = building_id
			done_count += 1
		elif next_id == "":
			next_id = building_id
		var building := ContentService.get_building(building_id)
		stages.append({
			"building_id": building_id,
			"name": String(building.get("name", building_id)),
			"done": done,
			"next": false,
			"unit_id": String(building.get("unlock_unit_id", "")),
		})
	for stage in stages:
		stage["next"] = String(stage.building_id) == next_id
	slot["stages"] = stages
	slot["building_ids"] = chain.duplicate()
	slot["done_count"] = done_count
	slot["stage_count"] = chain.size()
	slot["current_id"] = current_id
	slot["next_id"] = next_id
	slot["built"] = current_id != ""
	slot["art_building_id"] = current_id if current_id != "" else String(chain[0])
	slot["title"] = String(ContentService.get_building(String(slot.art_building_id)).get("name", slot.art_building_id))
	if next_id == "":
		slot["status"] = STATUS_COMPLETE
		slot["status_text"] = "Built" if chain.size() == 1 else "Complete"
		slot["status_detail"] = "Standing in this town." if chain.size() == 1 else "Every stage of this line stands in this town."
		slot["cost"] = {}
		slot["shortfall"] = {}
		slot["missing_requirements"] = []
		slot["verb"] = ""
		return slot
	_apply_status(slot, next_id, context, "Upgrade" if current_id != "" else "Build")
	return slot

static func _stage_done(building_id: String, context: Dictionary) -> bool:
	var row: Dictionary = context.catalog.get(building_id, {})
	if not row.is_empty():
		return String(row.get("catalog_status", "")) in ["Built", "Upgraded"] or bool(row.get("built", false))
	return TownDevelopment.satisfies(context.active, building_id)

static func _apply_status(slot: Dictionary, building_id: String, context: Dictionary, verb: String) -> void:
	var building := ContentService.get_building(building_id)
	var cost: Dictionary = building.get("cost", {}) if building.get("cost", {}) is Dictionary else {}
	var row: Dictionary = context.catalog.get(building_id, {})
	var missing := _missing_requirement_names(building, context)
	var shortfall := _shortfall(cost, context.resources)
	slot["verb"] = verb
	slot["cost"] = cost.duplicate(true)
	slot["shortfall"] = shortfall
	slot["missing_requirements"] = missing
	if not missing.is_empty() or row.is_empty():
		slot["status"] = STATUS_LOCKED
		var first := String(missing[0]) if not missing.is_empty() else "its prerequisites"
		slot["status_text"] = "Needs %s%s" % [first, " +%d" % (missing.size() - 1) if missing.size() > 1 else ""]
		slot["status_detail"] = String(row.get("catalog_status_detail", "Requires %s." % ", ".join(missing)))
		return
	if bool(context.built_today):
		slot["status"] = STATUS_TOMORROW
		slot["status_text"] = "Tomorrow"
		slot["status_detail"] = "This town already built today. One construction per town per day."
		return
	if bool(row.get("direct_affordable", false)):
		slot["status"] = STATUS_READY
		slot["status_text"] = "%s · %s" % [verb, format_amount(int(cost.get("gold", 0)))]
		slot["status_detail"] = "Ready for today's construction order."
		return
	if bool(row.get("market_coverable", false)):
		slot["status"] = STATUS_TRADE
		slot["status_text"] = "Trade covers it"
		slot["status_detail"] = String(row.get("market_summary", "Trade can cover the missing resources."))
		return
	slot["status"] = STATUS_SHORT
	if shortfall.size() == 1:
		var resource_id := String(shortfall.keys()[0])
		slot["status_text"] = "Short %s %s" % [format_amount(int(shortfall[resource_id])), resource_name(resource_id)]
	else:
		var names := []
		for resource_id in RESOURCE_ORDER:
			if shortfall.has(resource_id):
				names.append(resource_name(resource_id))
		slot["status_text"] = "Short " + ", ".join(names) if not names.is_empty() else "Resources missing"
	slot["status_detail"] = String(row.get("disabled_reason", "Current stores cannot fund this building."))

static func _missing_requirement_names(building: Dictionary, context: Dictionary) -> Array:
	var names := []
	var ids := []
	var upgrade_from := String(building.get("upgrade_from", ""))
	if upgrade_from != "":
		ids.append(upgrade_from)
	for requirement_value in building.get("requires", []):
		var requirement := String(requirement_value)
		if requirement != "" and requirement != String(building.get("id", "")) and requirement not in ids:
			ids.append(requirement)
	for requirement in ids:
		if not TownDevelopment.satisfies(context.active, requirement):
			names.append(String(ContentService.get_building(requirement).get("name", requirement)))
	var required_tier := int(building.get("requires_dwelling_tier", 0))
	if required_tier > 0 and not TownDevelopment.has_dwelling_tier(context.town, required_tier):
		names.append("tier-%s dwelling" % roman(required_tier))
	return names

static func _shortfall(cost: Dictionary, resources: Dictionary) -> Dictionary:
	var shortfall := {}
	for resource_id in cost.keys():
		var need := int(cost[resource_id])
		var have := int(resources.get(resource_id, 0))
		if need > have:
			shortfall[String(resource_id)] = need - have
	return shortfall

static func _first_sentence(text: String) -> String:
	var index := text.find(". ")
	return text.substr(0, index + 1) if index > 0 else text
