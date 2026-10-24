extends RefCounted

const HumanEngine = preload("res://scripts/core/HumanEngine.gd")


# Player/controller identity is mutable world ownership. Faction identity is an
# immutable content reference. Legacy authored scenarios keep faction-keyed
# controllers; generated packages supply explicit player ids and source teams.
static func controller_id(record: Dictionary, fallback: String = "") -> String:
	return HumanEngine.native(&"PlayerIdentityRules.controller_id", [record, fallback])

static func town_controller_id(town: Dictionary) -> String:
	return HumanEngine.native_writing(&"PlayerIdentityRules.town_controller_id", [town])

static func raid_controller_id(raid: Dictionary) -> String:
	return HumanEngine.native_writing(&"PlayerIdentityRules.raid_controller_id", [raid])

static func contesting_controller_id(encounter: Dictionary) -> String:
	var player_id := String(encounter.get("contested_by_player_id", ""))
	return player_id if player_id != "" else String(encounter.get("contested_by_faction_id", ""))

static func resource_controller_id(node: Dictionary) -> String:
	return HumanEngine.native_writing(&"PlayerIdentityRules.resource_controller_id", [node])

static func task_controller_id(task: Dictionary, fallback: String = "") -> String:
	var player_id := String(task.get("owner_player_id", ""))
	return player_id if player_id != "" else String(task.get("owner_faction_id", fallback))

static func player(session, player_id: String) -> Dictionary:
	return HumanEngine.native_writing(&"PlayerIdentityRules.player", [session, player_id])

static func faction_id(session, controller: String) -> String:
	return HumanEngine.native_writing(&"PlayerIdentityRules.faction_id", [session, controller])

static func has_human_seat(session) -> bool:
	return HumanEngine.native_writing(&"PlayerIdentityRules.has_human_seat", [session])

static func allied(session, first: String, second: String) -> bool:
	return HumanEngine.native_writing(&"PlayerIdentityRules.allied", [session, first, second])
