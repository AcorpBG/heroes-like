class_name ScenarioSelectRules
extends RefCounted

const SessionStateStoreScript = preload("res://scripts/core/SessionStateStore.gd")
const ScenarioFactoryScript = preload("res://scripts/core/ScenarioFactory.gd")
static var ScenarioRulesScript: Variant = load("res://scripts/core/ScenarioRules.gd")
static var OverworldRulesScript: Variant = load("res://scripts/core/OverworldRules.gd")
const HeroProgressionRulesScript = preload("res://scripts/core/HeroProgressionRules.gd")
const HeroCommandRulesScript = preload("res://scripts/core/HeroCommandRules.gd")
const SpellRulesScript = preload("res://scripts/core/SpellRules.gd")
const ArtifactRulesScript = preload("res://scripts/core/ArtifactRules.gd")

const DIFFICULTY_OPTIONS := [
	{
		"id": "story",
		"label": "Story",
		"summary": "Extra movement and economy, slower enemy pressure, and player-favored battle tempo.",
	},
	{
		"id": "normal",
		"label": "Captain",
		"summary": "Baseline expedition pressure, economy, and combat pacing for a standard run.",
	},
	{
		"id": "hard",
		"label": "Warlord",
		"summary": "Reduced movement and income, faster raids, and enemy-favored combat momentum.",
	},
]

static func _campaign_rules():
	return load("res://scripts/core/CampaignRules.gd")

static func default_difficulty_id() -> String:
	return "normal"

static func normalize_difficulty(value: Variant) -> String:
	var difficulty_id := String(value)
	for option in DIFFICULTY_OPTIONS:
		if String(option.get("id", "")) == difficulty_id:
			return difficulty_id
	return default_difficulty_id()

static func build_difficulty_options(selected_id: String = "") -> Array:
	var normalized_id := normalize_difficulty(selected_id)
	var options := []
	for option in DIFFICULTY_OPTIONS:
		var item: Dictionary = option.duplicate(true) if option is Dictionary else {}
		item["selected"] = String(item.get("id", "")) == normalized_id
		options.append(item)
	return options

static func difficulty_label(difficulty_id: String) -> String:
	var normalized_id := normalize_difficulty(difficulty_id)
	for option in DIFFICULTY_OPTIONS:
		if String(option.get("id", "")) == normalized_id:
			return String(option.get("label", "Captain"))
	return "Captain"

static func difficulty_summary(difficulty_id: String) -> String:
	var normalized_id := normalize_difficulty(difficulty_id)
	for option in DIFFICULTY_OPTIONS:
		if String(option.get("id", "")) == normalized_id:
			return String(option.get("summary", ""))
	return ""

static func launch_mode_label(launch_mode: String) -> String:
	return "Skirmish" if SessionStateStoreScript.normalize_launch_mode(launch_mode) == SessionStateStoreScript.LAUNCH_MODE_SKIRMISH else "Campaign"

static func availability_label(availability: Dictionary) -> String:
	var campaign_enabled := bool(availability.get("campaign", false))
	var skirmish_enabled := bool(availability.get("skirmish", false))
	if campaign_enabled and skirmish_enabled:
		return "Campaign + Skirmish"
	if campaign_enabled:
		return "Campaign only"
	if skirmish_enabled:
		return "Skirmish only"
	return "Unavailable"

static func build_current_session_summary(session: SessionStateStoreScript.SessionData) -> String:
	if session == null or session.scenario_id == "":
		return "Campaign progress is saved separately from expedition slots."

	var scenario := ContentService.get_scenario(session.scenario_id)
	var scenario_name := String(scenario.get("name", session.scenario_id))
	var lines := [
		"%s | %s | %s"
		% [
			launch_mode_label(session.launch_mode),
			difficulty_label(session.difficulty),
			scenario_name,
		]
	]
	if session.scenario_summary != "":
		lines.append(
			"%s: %s"
			% [
				String(session.scenario_status).replace("_", " ").capitalize(),
				session.scenario_summary,
			]
		)
	var hero_summary: String = HeroProgressionRulesScript.brief_summary(session.overworld.get("hero", {}))
	if hero_summary != "":
		lines.append("Hero specialties: %s" % hero_summary)
	return "\n".join(lines)

static func build_skirmish_browser_entries() -> Array:
	var entries := []
	for scenario in _scenario_items():
		if not (scenario is Dictionary):
			continue
		var selection := _selection_metadata(scenario)
		var availability: Variant = selection.get("availability", {})
		var availability_dict: Dictionary = availability if availability is Dictionary else {}
		if not bool(availability_dict.get("skirmish", false)):
			continue

		var scenario_id := String(scenario.get("id", ""))
		entries.append(
			{
				"scenario_id": scenario_id,
				"label": "%s | %s | %s"
				% [
					String(scenario.get("name", scenario_id)),
					String(selection.get("map_size_label", "Unknown Map")),
					difficulty_label(String(selection.get("recommended_difficulty", default_difficulty_id()))),
				],
				"summary": _browser_summary_text(scenario, selection),
			}
		)
	return entries

static func build_skirmish_setup(scenario_id: String, difficulty_id: String) -> Dictionary:
	var scenario := ContentService.get_scenario(scenario_id)
	if scenario.is_empty():
		return {}

	var selection := _selection_metadata(scenario)
	var availability: Variant = selection.get("availability", {})
	var availability_dict: Dictionary = availability if availability is Dictionary else {}
	if not bool(availability_dict.get("skirmish", false)):
		return {}

	var normalized_difficulty := normalize_difficulty(difficulty_id)
	var recommended_difficulty := String(selection.get("recommended_difficulty", default_difficulty_id()))
	var hero := _scenario_hero(scenario)
	var commander_preview := describe_scenario_commander_preview(
		scenario_id,
		normalized_difficulty,
		SessionStateStoreScript.LAUNCH_MODE_SKIRMISH
	)
	var operational_board: String = ScenarioRulesScript.describe_scenario_operational_board(
		scenario_id,
		normalized_difficulty,
		SessionStateStoreScript.LAUNCH_MODE_SKIRMISH
	)
	var launch_preview: String = ScenarioRulesScript.describe_scenario_launch_preview(
		scenario_id,
		normalized_difficulty,
		SessionStateStoreScript.LAUNCH_MODE_SKIRMISH,
		"Launch Skirmish"
	)
	var setup_lines := []
	setup_lines.append(launch_preview)
	var briefing_summary: String = ScenarioRulesScript.describe_scenario_briefing(scenario_id)
	if briefing_summary != "":
		setup_lines.append(briefing_summary)
	else:
		setup_lines.append(String(selection.get("summary", "")))
	setup_lines.append_array([
		"Mode: %s | Difficulty: %s"
		% [
			launch_mode_label(SessionStateStoreScript.LAUNCH_MODE_SKIRMISH),
			difficulty_label(normalized_difficulty),
		],
		"Map: %s | Availability: %s"
		% [
			String(selection.get("map_size_label", "Unknown Map")),
			availability_label(availability_dict),
		],
		"Hero: %s" % _hero_setup_summary(hero, scenario),
		"Player: %s" % String(selection.get("player_summary", "")),
		"Enemy: %s" % String(selection.get("enemy_summary", "")),
	])
	var faction_setup: String = OverworldRulesScript.describe_faction_identity_surface(String(scenario.get("player_faction_id", "")))
	if faction_setup != "":
		setup_lines.append(faction_setup)
	if normalized_difficulty != recommended_difficulty:
		setup_lines.append("Recommended difficulty: %s" % difficulty_label(recommended_difficulty))

	return {
		"scenario_id": scenario_id,
		"scenario_name": String(scenario.get("name", scenario_id)),
		"summary": String(selection.get("summary", "")),
		"difficulty": normalized_difficulty,
		"difficulty_label": difficulty_label(normalized_difficulty),
		"difficulty_summary": difficulty_summary(normalized_difficulty),
		"recommended_difficulty": recommended_difficulty,
		"recommended_difficulty_label": difficulty_label(recommended_difficulty),
		"setup_summary": "\n".join(setup_lines),
		"launch_preview": launch_preview,
		"commander_preview": commander_preview,
		"operational_board": operational_board,
	}

static func start_skirmish_session(scenario_id: String, difficulty_id: String) -> SessionStateStoreScript.SessionData:
	var setup := build_skirmish_setup(scenario_id, difficulty_id)
	if setup.is_empty():
		push_warning("Scenario %s is not available for skirmish." % scenario_id)
		return SessionStateStoreScript.new_session_data()

	var session := ScenarioFactoryScript.create_session(
		scenario_id,
		String(setup.get("difficulty", default_difficulty_id())),
		SessionStateStoreScript.LAUNCH_MODE_SKIRMISH
	)
	OverworldRulesScript.normalize_overworld_state(session)
	SessionState.active_session = session
	return session

static func describe_scenario_commander_preview(
	scenario_id: String,
	difficulty_id: String = "normal",
	launch_mode: String = SessionStateStoreScript.LAUNCH_MODE_SKIRMISH
) -> String:
	var session := ScenarioFactoryScript.create_session(scenario_id, normalize_difficulty(difficulty_id), launch_mode)
	if session.scenario_id == "":
		return "Commander preview unavailable."
	OverworldRulesScript.normalize_overworld_state(session)
	return describe_session_commander_preview(session)

static func describe_session_commander_preview(session: SessionStateStoreScript.SessionData) -> String:
	if session == null or session.scenario_id == "":
		return "Commander preview unavailable."
	OverworldRulesScript.normalize_overworld_state(session)
	var scenario := ContentService.get_scenario(session.scenario_id)
	var hero = session.overworld.get("hero", {})
	var command = hero.get("command", {})
	var lines := ["Commander Preview"]
	lines.append(HeroCommandRulesScript.hero_identity_context_line(hero, String(scenario.get("player_faction_id", ""))))
	lines.append(HeroCommandRulesScript.hero_progress_context_line(hero))
	lines.append("Opening readiness: %s" % HeroCommandRulesScript.hero_readiness_context_line(hero, true))
	var profile_summary: String = HeroCommandRulesScript.hero_profile_summary(hero, true)
	if profile_summary != "":
		lines.append(profile_summary)
	var identity_summary: String = HeroCommandRulesScript.hero_identity_summary(hero)
	if identity_summary != "":
		lines.append(identity_summary)
	var faction_identity: String = OverworldRulesScript.describe_faction_identity_surface(String(scenario.get("player_faction_id", "")))
	if faction_identity != "":
		lines.append(faction_identity)
	var command_line := "Battle command A%d D%d P%d K%d" % [
		int(command.get("attack", 0)),
		int(command.get("defense", 0)),
		int(command.get("power", 0)),
		int(command.get("knowledge", 0)),
	]
	var trait_summary := _describe_battle_traits(hero.get("battle_traits", []))
	if trait_summary != "":
		command_line = "%s | Traits %s" % [command_line, trait_summary]
	lines.append(command_line)
	lines.append("Specialties: %s" % HeroProgressionRulesScript.brief_summary(hero))
	lines.append(SpellRulesScript.describe_spellbook(hero))
	lines.append(_artifact_preview(hero))
	lines.append(_army_preview(hero.get("army", session.overworld.get("army", {}))))
	var front_preview := _front_preview_summary(scenario)
	if front_preview != "":
		lines.append(front_preview)
	return "\n".join(lines)

static func _scenario_items() -> Array:
	return ContentService.load_json(ContentService.SCENARIOS_PATH).get("items", [])

static func _selection_metadata(scenario: Dictionary) -> Dictionary:
	var selection: Variant = scenario.get("selection", {})
	var selection_dict: Dictionary = selection if selection is Dictionary else {}
	var availability: Dictionary = {}
	if not selection_dict.is_empty():
		var raw_availability: Variant = selection_dict.get("availability", {})
		if raw_availability is Dictionary:
			availability = {
				"campaign": bool(raw_availability.get("campaign", false)),
				"skirmish": bool(raw_availability.get("skirmish", false)),
			}

	if availability.is_empty():
		availability = {
			"campaign": _campaign_rules().get_campaign_id_for_scenario(String(scenario.get("id", ""))) != "",
			"skirmish": false,
		}

	return {
		"summary": String(selection_dict.get("summary", String(scenario.get("name", scenario.get("id", "Scenario"))))),
		"recommended_difficulty": normalize_difficulty(selection_dict.get("recommended_difficulty", default_difficulty_id())),
		"map_size_label": String(selection_dict.get("map_size_label", _fallback_map_size_label(scenario))),
		"player_summary": String(selection_dict.get("player_summary", _default_player_summary(scenario))),
		"enemy_summary": String(selection_dict.get("enemy_summary", _default_enemy_summary(scenario))),
		"availability": availability,
	}

static func _browser_summary_text(scenario: Dictionary, selection: Dictionary) -> String:
	var lines := [
		String(selection.get("summary", "")),
		"Availability: %s" % availability_label(selection.get("availability", {})),
		"Recommended: %s" % difficulty_label(String(selection.get("recommended_difficulty", default_difficulty_id()))),
		"Player: %s" % String(selection.get("player_summary", "")),
		"Enemy: %s" % String(selection.get("enemy_summary", "")),
	]
	return "\n".join(lines)

static func _fallback_map_size_label(scenario: Dictionary) -> String:
	var map_size = scenario.get("map_size", {})
	if map_size is Dictionary:
		var width := int(map_size.get("width", 0))
		var height := int(map_size.get("height", 0))
		if width > 0 and height > 0:
			return "%dx%d frontier" % [width, height]
	return "Authored frontier"

static func _scenario_hero(scenario: Dictionary) -> Dictionary:
	var hero_id := String(scenario.get("hero_id", ""))
	return ContentService.get_hero(hero_id)

static func _default_player_summary(scenario: Dictionary) -> String:
	var hero := _scenario_hero(scenario)
	var hero_name := String(hero.get("name", scenario.get("hero_id", "Field Commander")))
	var faction := ContentService.get_faction(String(scenario.get("player_faction_id", "")))
	var faction_name := String(faction.get("name", scenario.get("player_faction_id", "Frontier host")))
	return "%s leads %s." % [hero_name, faction_name]

static func _default_enemy_summary(scenario: Dictionary) -> String:
	var labels := []
	for enemy_faction in scenario.get("enemy_factions", []):
		if not (enemy_faction is Dictionary):
			continue
		var label := String(enemy_faction.get("label", ""))
		if label == "":
			var faction := ContentService.get_faction(String(enemy_faction.get("faction_id", "")))
			label = String(faction.get("name", enemy_faction.get("faction_id", "Enemy host")))
		if label != "" and label not in labels:
			labels.append(label)

	if not labels.is_empty():
		return ", ".join(labels)
	return "Opposition details are authored on the battlefield."

static func _hero_setup_summary(hero: Dictionary, scenario: Dictionary) -> String:
	var hero_name := String(hero.get("name", scenario.get("hero_id", "Field Commander")))
	var faction := ContentService.get_faction(String(hero.get("faction_id", scenario.get("player_faction_id", ""))))
	var faction_name := String(faction.get("name", scenario.get("player_faction_id", "Frontier host")))
	var parts := ["%s of %s" % [hero_name, faction_name]]
	var profile_summary: String = HeroCommandRulesScript.hero_profile_summary(hero, true)
	if profile_summary != "":
		parts.append(profile_summary)
	var identity_summary: String = HeroCommandRulesScript.hero_identity_summary(hero)
	if identity_summary != "":
		parts.append(identity_summary)
	return ". ".join(parts) + "."

static func _artifact_preview(hero: Dictionary) -> String:
	if ArtifactRulesScript.owned_artifact_ids(hero).is_empty():
		return "Artifacts: no relics equipped or packed for this front.\n%s\n%s" % [
			ArtifactRulesScript.describe_impact_summary(hero),
			ArtifactRulesScript.describe_collection_summary(hero),
		]
	return ArtifactRulesScript.describe_loadout(hero)

static func _army_preview(army: Dictionary) -> String:
	var parts := []
	var headcount := 0
	var ranged_groups := 0
	for stack in army.get("stacks", []):
		if not (stack is Dictionary):
			continue
		var count := int(stack.get("count", 0))
		if count <= 0:
			continue
		var unit := ContentService.get_unit(String(stack.get("unit_id", "")))
		if bool(unit.get("ranged", false)):
			ranged_groups += 1
		headcount += count
		parts.append("%s x%d" % [String(unit.get("name", stack.get("unit_id", ""))), count])
	return "Army loadout: %d troops | %d groups | %d ranged groups\n%s" % [
		headcount,
		parts.size(),
		ranged_groups,
		", ".join(parts) if not parts.is_empty() else "No standing force",
	]

static func _front_preview_summary(scenario: Dictionary) -> String:
	if scenario.is_empty():
		return ""
	var selection := _selection_metadata(scenario)
	var parts := []
	var enemy_summary := String(selection.get("enemy_summary", ""))
	if enemy_summary != "":
		parts.append("Opposition %s" % enemy_summary)
	var battlefield_summary := _battlefield_tag_summary(scenario)
	if battlefield_summary != "":
		parts.append("Expected ground %s" % battlefield_summary)
	return "Front posture: %s" % " | ".join(parts) if not parts.is_empty() else ""

static func _battlefield_tag_summary(scenario: Dictionary) -> String:
	var labels := []
	for placement in scenario.get("encounters", []):
		if not (placement is Dictionary):
			continue
		var encounter := ContentService.get_encounter(String(placement.get("encounter_id", "")))
		for tag_value in encounter.get("battlefield_tags", []):
			var tag_label := _tag_label(String(tag_value))
			if tag_label != "" and tag_label not in labels:
				labels.append(tag_label)
			if labels.size() >= 4:
				return ", ".join(labels)
	return ", ".join(labels)

static func _describe_battle_traits(value: Variant) -> String:
	if not (value is Array):
		return ""
	var labels := []
	for trait_value in value:
		var label := _tag_label(String(trait_value))
		if label != "" and label not in labels:
			labels.append(label)
	return ", ".join(labels)

static func _tag_label(value: String) -> String:
	if value == "":
		return ""
	var words := value.split("_")
	for index in range(words.size()):
		words[index] = String(words[index]).capitalize()
	return " ".join(words)
