extends RefCounted

# Player/controller identity is mutable world ownership. Faction identity is an
# immutable content reference. Legacy authored scenarios keep faction-keyed
# controllers; generated packages supply explicit player ids and source teams.
static func controller_id(record: Dictionary, fallback: String = "") -> String:
	var player_id := String(record.get("player_id", ""))
	return player_id if player_id != "" else String(record.get("faction_id", fallback))

static func town_controller_id(town: Dictionary) -> String:
	var player_id := String(town.get("controlling_player_id", ""))
	if player_id != "":
		return player_id
	var faction := String(town.get("controlling_faction_id", ""))
	return faction if faction != "" else String(town.get("faction_id", ContentService.get_town(String(town.get("town_id", ""))).get("faction_id", "")))

static func raid_controller_id(raid: Dictionary) -> String:
	var player_id := String(raid.get("spawned_by_player_id", ""))
	return player_id if player_id != "" else String(raid.get("spawned_by_faction_id", ""))

static func contesting_controller_id(encounter: Dictionary) -> String:
	var player_id := String(encounter.get("contested_by_player_id", ""))
	return player_id if player_id != "" else String(encounter.get("contested_by_faction_id", ""))

static func resource_controller_id(node: Dictionary) -> String:
	var player_id := String(node.get("collected_by_player_id", ""))
	return player_id if player_id != "" else String(node.get("collected_by_faction_id", ""))

static func defender_controller_id(record: Dictionary) -> String:
	var player_id := String(record.get("ai_defended_by_player_id", ""))
	var commander: Dictionary = record.get("ai_defender_commander_state", {}) if record.get("ai_defender_commander_state", {}) is Dictionary else {}
	if player_id == "":
		player_id = String(commander.get("player_id", ""))
	if player_id != "":
		return player_id
	var faction := String(record.get("ai_defended_by_faction_id", ""))
	return faction if faction != "" else String(commander.get("faction_id", ""))

static func task_controller_id(task: Dictionary, fallback: String = "") -> String:
	var player_id := String(task.get("owner_player_id", ""))
	return player_id if player_id != "" else String(task.get("owner_faction_id", fallback))

static func set_resource_controller(node: Dictionary, session, controller: String) -> void:
	node["collected_by_faction_id"] = faction_id(session, controller)
	if player(session, controller).is_empty():
		node.erase("collected_by_player_id")
	else:
		node["collected_by_player_id"] = controller

static func player(session, player_id: String) -> Dictionary:
	if session == null or player_id == "":
		return {}
	for record in session.overworld.get("players", []):
		if record is Dictionary and String(record.get("player_id", "")) == player_id:
			return record
	return {}

static func faction_id(session, controller: String) -> String:
	var record := player(session, controller)
	return String(record.get("faction_id", controller))

static func identity_fields(session, controller: String) -> Dictionary:
	var record := player(session, controller)
	var result := {"faction_id": faction_id(session, controller)}
	if not record.is_empty():
		result["player_id"] = controller
		result["team_id"] = String(record.get("team_id", ""))
	return result

static func config_for_controller(session, controller: String) -> Dictionary:
	var result := identity_fields(session, controller)
	result["label"] = String(ContentService.get_faction(String(result.faction_id)).get("name", result.faction_id))
	return result

static func allied(session, first: String, second: String) -> bool:
	# The one-human runtime retains "player" in legacy interaction APIs.
	if session != null:
		if first == "player":
			first = String(session.overworld.get("active_player_id", first))
		if second == "player":
			second = String(session.overworld.get("active_player_id", second))
	if first == "" or second == "":
		return false
	if first == second:
		return true
	var first_player := player(session, first)
	var second_player := player(session, second)
	var team := String(first_player.get("team_id", ""))
	return team != "" and team == String(second_player.get("team_id", ""))

static func normalize_compatibility(session) -> void:
	if session == null or not session.overworld.get("players", []).is_empty():
		return
	if bool(session.flags.get("generated_random_map", false)):
		# Pre-player-identity saves already pooled same-faction controllers.
		# Preserve their actual treasury, captures and commander history; source
		# starting slots cannot recover ownership lost during previous play.
		session.overworld["player_identity_version"] = 0
		session.overworld["player_identity_mode"] = "legacy_generated_faction_v0"

static func from_slots(slots: Array) -> Array:
	var result := []
	for value in slots:
		if not (value is Dictionary):
			continue
		var slot := int(value.get("slot", 0))
		if slot <= 0:
			continue
		var record: Dictionary = value.duplicate(true)
		var id := String(record.get("player_id", ""))
		if id == "":
			id = "player_%d" % slot
		record["player_id"] = id
		if String(record.get("team_id", "")) == "":
			# Older packages did not carry teams. Do not invent alliances from
			# faction equality or the requested (not source-assigned) team count.
			record["team_id"] = id
		result.append(record)
	return result

static func enemy_configs(players: Array) -> Array:
	var result := []
	for record in players:
		if not (record is Dictionary) or not bool(record.get("computer", false)) or bool(record.get("human", false)):
			continue
		result.append({
			"player_id": String(record.get("player_id", "")),
			"player_slot": int(record.get("slot", 0)),
			"team_id": String(record.get("team_id", "")),
			"faction_id": String(record.get("faction_id", "")),
			"generated_package_town_config": true,
		})
	return result
