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
const HumanEngine = preload("res://scripts/core/HumanEngine.gd")

const STATUS_COMPLETE := "complete"
const STATUS_READY := "ready"
const STATUS_TRADE := "trade"
const STATUS_SHORT := "short"
const STATUS_LOCKED := "locked"
const STATUS_TOMORROW := "tomorrow"
const RESOURCE_ORDER := ["gold", "wood", "ore", "aetherglass", "embergrain", "peatwax", "verdant_grafts", "brass_scrip", "memory_salt"]
const ROMAN := ["", "I", "II", "III", "IV", "V", "VI", "VII"]

static func build(town: Dictionary, day: int, resources: Dictionary, catalog_by_building: Dictionary) -> Dictionary:
	return HumanEngine.native_writing(&"TownConstructionBoard.build", [town, day, resources, catalog_by_building])

static func town_building_ids(template: Dictionary) -> Array:
	return HumanEngine.native(&"TownConstructionBoard.town_building_ids", [template])

static func slot_for_building(board: Dictionary, building_id: String) -> Dictionary:
	return HumanEngine.native_writing(&"TownConstructionBoard.slot_for_building", [board, building_id])

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
	return HumanEngine.native(&"TownConstructionBoard.format_amount", [value])

static func resource_name(resource_id: String) -> String:
	return HumanEngine.native(&"TownConstructionBoard.resource_name", [resource_id])

static func roman(tier: int) -> String:
	return HumanEngine.native(&"TownConstructionBoard.roman", [tier])
