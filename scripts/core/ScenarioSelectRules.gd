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
const HumanEngine = preload("res://scripts/core/HumanEngine.gd")

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
const RANDOM_MAP_DEFAULT_MONSTER_STRENGTH := "normal"
# A seat whose faction is drawn from the map's normalized seed
# (random_map_seat_factions).
const RANDOM_MAP_RANDOM_FACTION_ID := "random"
const RANDOM_MAP_PLAYER_RETRY_POLICY := {
	"max_attempts": 5,
	"mode": "seed_salt",
}
const RANDOM_MAP_TEMPLATE_SELECTION_MODE_SIZE_DEFAULT := "size_default"
const RANDOM_MAP_TEMPLATE_SELECTION_MODE_CATALOG_AUTO := "native_catalog_auto"

static func _campaign_rules():
	return load("res://scripts/core/CampaignRules.gd")

static func default_difficulty_id() -> String:
	return HumanEngine.native(&"ScenarioSelectRules.default_difficulty_id", [])

static func normalize_difficulty(value: Variant) -> String:
	return HumanEngine.native(&"ScenarioSelectRules.normalize_difficulty", [value])

static func build_difficulty_options(selected_id: String = "") -> Array:
	return HumanEngine.native_writing(&"ScenarioSelectRules.build_difficulty_options", [selected_id])

static func difficulty_label(difficulty_id: String) -> String:
	return HumanEngine.native_writing(&"ScenarioSelectRules.difficulty_label", [difficulty_id])

static func difficulty_summary(difficulty_id: String) -> String:
	return HumanEngine.native_writing(&"ScenarioSelectRules.difficulty_summary", [difficulty_id])

static func launch_mode_label(launch_mode: String) -> String:
	return HumanEngine.native_writing(&"ScenarioSelectRules.launch_mode_label", [launch_mode])

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
	return HumanEngine.native_writing(&"ScenarioSelectRules.build_current_session_summary", [session])

static func build_skirmish_browser_entries() -> Array:
	var entries := []
	# An archived authored catalog offers no scenarios (they stay test setups).
	# Generated map packages under maps/ are offered either way.
	if _scenario_domain_is_player_facing():
		entries.append_array(_authored_skirmish_browser_entries())
	entries.append_array(build_maps_folder_package_browser_entries())
	return entries

static func _authored_skirmish_browser_entries() -> Array:
	var entries := []
	for scenario in _scenario_items():
		if not (scenario is Dictionary):
			continue
		if not _scenario_is_player_facing(scenario):
			continue
		var selection := _selection_metadata(scenario)
		var availability: Dictionary = selection.get("availability", {}) if selection.get("availability", {}) is Dictionary else {}
		if not bool(availability.get("skirmish", false)):
			continue
		var scenario_id := String(scenario.get("id", ""))
		if scenario_id == "":
			continue
		entries.append(
			{
				"scenario_id": scenario_id,
				"label": String(scenario.get("name", scenario_id)),
				"summary": _browser_summary_text(scenario, selection),
				"source_kind": "authored_scenario",
				"availability": availability.duplicate(true),
				"recommended_difficulty": String(selection.get("recommended_difficulty", default_difficulty_id())),
			}
		)
	return entries

static func build_skirmish_setup(scenario_id: String, difficulty_id: String) -> Dictionary:
	if maps_folder_package_id_is_valid(scenario_id):
		return build_maps_folder_package_skirmish_setup(scenario_id, difficulty_id)
	var scenario := ContentService.get_scenario_readonly(scenario_id)
	if scenario.is_empty():
		return {}
	if ContentService.has_authored_scenario(scenario_id) and not _scenario_domain_is_player_facing():
		return {}
	if not _scenario_is_player_facing(scenario):
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
	var front_context := _skirmish_front_context(scenario, selection, availability_dict)
	var objective_stakes := _skirmish_objective_stakes(scenario)
	var readiness_summary := _skirmish_readiness_summary(commander_preview, operational_board)
	var difficulty_consequence := _skirmish_difficulty_consequence(normalized_difficulty, recommended_difficulty)
	var difficulty_check := describe_skirmish_difficulty_check(normalized_difficulty, recommended_difficulty)
	var action_consequence := _skirmish_action_consequence(normalized_difficulty)
	var launch_handoff := _skirmish_launch_handoff(
		scenario,
		normalized_difficulty,
		launch_preview,
		objective_stakes,
		action_consequence
	)
	var briefing_check := _skirmish_briefing_check(
		scenario,
		ScenarioRulesScript.describe_scenario_briefing(scenario_id),
		objective_stakes,
		front_context,
		readiness_summary
	)
	var setup_lines := []
	setup_lines.append(launch_handoff)
	setup_lines.append(launch_preview)
	for context_line in [briefing_check, front_context, objective_stakes, readiness_summary, difficulty_check, difficulty_consequence]:
		if String(context_line) != "":
			setup_lines.append(String(context_line))
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
	setup_lines.append(action_consequence)

	var action_tooltip_lines := [launch_preview, launch_handoff]
	for action_line in [briefing_check, front_context, readiness_summary, difficulty_check, difficulty_consequence, action_consequence]:
		if String(action_line) != "":
			action_tooltip_lines.append(String(action_line))

	return {
		"scenario_id": scenario_id,
		"hero_id": String(hero.get("id", scenario.get("hero_id", ""))),
		"scenario_name": String(scenario.get("name", scenario_id)),
		"summary": String(selection.get("summary", "")),
		"difficulty": normalized_difficulty,
		"difficulty_label": difficulty_label(normalized_difficulty),
		"difficulty_summary": difficulty_summary(normalized_difficulty),
		"recommended_difficulty": recommended_difficulty,
		"recommended_difficulty_label": difficulty_label(recommended_difficulty),
		"setup_summary": "\n".join(setup_lines),
		"launch_preview": launch_preview,
		"launch_handoff": launch_handoff,
		"briefing_check": briefing_check,
		"front_context": front_context,
		"objective_stakes": objective_stakes,
		"readiness_summary": readiness_summary,
		"difficulty_check": difficulty_check,
		"difficulty_consequence": difficulty_consequence,
		"action_consequence": action_consequence,
		"action_tooltip": "\n".join(action_tooltip_lines),
		"commander_preview": commander_preview,
		"operational_board": operational_board,
	}

static func random_map_player_setup_options() -> Dictionary:
	return HumanEngine.native_writing(&"ScenarioSelectRules.random_map_player_setup_options", [])

static func random_map_faction_options() -> Array:
	return HumanEngine.native_writing(&"ScenarioSelectRules.random_map_faction_options", [])

static func random_map_hero_options_for_faction(faction_id: String) -> Array:
	return HumanEngine.native_writing(&"ScenarioSelectRules.random_map_hero_options_for_faction", [faction_id])

static func random_map_default_hero_id_for_faction(faction_id: String) -> String:
	return HumanEngine.native_writing(&"ScenarioSelectRules.random_map_default_hero_id_for_faction", [faction_id])

static func generated_map_package_directory_policy() -> Dictionary:
	return HumanEngine.native_writing(&"ScenarioSelectRules.generated_map_package_directory_policy", [])

static func maps_folder_package_id_is_valid(package_id: String) -> bool:
	return HumanEngine.native_writing(&"ScenarioSelectRules.maps_folder_package_id_is_valid", [package_id])

static func maps_folder_package_id_for_stem(package_stem: String) -> String:
	return HumanEngine.native_writing(&"ScenarioSelectRules.maps_folder_package_id_for_stem", [package_stem])

static func maps_folder_package_stem_from_id(package_id: String) -> String:
	return HumanEngine.native_writing(&"ScenarioSelectRules.maps_folder_package_stem_from_id", [package_id])

static func safe_maps_folder_package_stem(value: String) -> String:
	return HumanEngine.native_writing(&"ScenarioSelectRules.safe_maps_folder_package_stem", [value])

static func build_maps_folder_package_browser_entries(options: Dictionary = {}) -> Array:
	return HumanEngine.native_writing(&"ScenarioSelectRules.build_maps_folder_package_browser_entries", [options])

static func maps_folder_package_index(options: Dictionary = {}) -> Dictionary:
	return HumanEngine.native_writing(&"ScenarioSelectRules.maps_folder_package_index", [options])

static func maps_folder_package_entry(package_id: String, options: Dictionary = {}) -> Dictionary:
	return HumanEngine.native_writing(&"ScenarioSelectRules.maps_folder_package_entry", [package_id, options])

static func build_maps_folder_package_skirmish_setup(package_id: String, difficulty_id: String = "normal", options: Dictionary = {}) -> Dictionary:
	return HumanEngine.native_writing(&"ScenarioSelectRules.build_maps_folder_package_skirmish_setup", [package_id, difficulty_id, options])

static func build_maps_folder_package_skirmish_setup_from_entry(entry: Dictionary, difficulty_id: String = "normal") -> Dictionary:
	return HumanEngine.native_writing(&"ScenarioSelectRules.build_maps_folder_package_skirmish_setup_from_entry", [entry, difficulty_id])

static func load_maps_folder_package_session_from_entry(entry: Dictionary, difficulty_id: String = "normal", options: Dictionary = {}) -> SessionStateStoreScript.SessionData:
	return HumanEngine.native_writing(&"ScenarioSelectRules.load_maps_folder_package_session_from_entry", [entry, difficulty_id, options])

static func start_maps_folder_package_skirmish_session(package_id: String, difficulty_id: String = "normal") -> SessionStateStoreScript.SessionData:
	return HumanEngine.native_writing(&"ScenarioSelectRules.start_maps_folder_package_skirmish_session", [package_id, difficulty_id])

static func start_maps_folder_package_skirmish_session_from_entry(entry: Dictionary, difficulty_id: String = "normal") -> SessionStateStoreScript.SessionData:
	return HumanEngine.native_writing(&"ScenarioSelectRules.start_maps_folder_package_skirmish_session_from_entry", [entry, difficulty_id])

static func random_map_seed_requests_auto(seed: String) -> bool:
	return HumanEngine.native_writing(&"ScenarioSelectRules.random_map_seed_requests_auto", [seed])

static func random_map_fresh_auto_seed() -> String:
	return HumanEngine.native_writing(&"ScenarioSelectRules.random_map_fresh_auto_seed", [])

static func random_map_player_count_options_for_template(template_id: String) -> Array:
	return HumanEngine.native_writing(&"ScenarioSelectRules.random_map_player_count_options_for_template", [template_id])

static func random_map_profile_options_for_template(template_id: String) -> Array:
	return HumanEngine.native_writing(&"ScenarioSelectRules.random_map_profile_options_for_template", [template_id])

static func random_map_size_class_default(size_class_id: String) -> Dictionary:
	return HumanEngine.native_writing(&"ScenarioSelectRules.random_map_size_class_default", [size_class_id])

static func build_random_map_player_config(seed: String, template_id: String, profile_id: String, player_count: int, water_mode: String, underground_enabled: bool, size_class_id: String = "homm3_small", template_selection_mode: String = RANDOM_MAP_TEMPLATE_SELECTION_MODE_SIZE_DEFAULT, player_faction_id: String = "", player_hero_id: String = "", monster_strength: String = "", seat_faction_ids: Array = []) -> Dictionary:
	return HumanEngine.native_writing(&"ScenarioSelectRules.build_random_map_player_config", [seed, template_id, profile_id, player_count, water_mode, underground_enabled, size_class_id, template_selection_mode, player_faction_id, player_hero_id, monster_strength, seat_faction_ids])

static func start_skirmish_session(scenario_id: String, difficulty_id: String) -> SessionStateStoreScript.SessionData:
	if maps_folder_package_id_is_valid(scenario_id):
		return start_maps_folder_package_skirmish_session(scenario_id, difficulty_id)
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

static func build_random_map_skirmish_setup_with_retry(input_config: Dictionary, difficulty_id: String = "normal", retry_policy: Dictionary = {}) -> Dictionary:
	return HumanEngine.native_writing(&"ScenarioSelectRules.build_random_map_skirmish_setup_with_retry", [input_config, difficulty_id, retry_policy])

static func build_random_map_skirmish_setup(input_config: Dictionary, difficulty_id: String = "normal") -> Dictionary:
	return HumanEngine.native_writing(&"ScenarioSelectRules.build_random_map_skirmish_setup", [input_config, difficulty_id])

static func start_random_map_skirmish_session(input_config: Dictionary, difficulty_id: String = "normal") -> SessionStateStoreScript.SessionData:
	return HumanEngine.native_writing(&"ScenarioSelectRules.start_random_map_skirmish_session", [input_config, difficulty_id])

static func start_random_map_skirmish_session_from_setup(setup: Dictionary) -> SessionStateStoreScript.SessionData:
	return HumanEngine.native_writing(&"ScenarioSelectRules.start_random_map_skirmish_session_from_setup", [setup])

static func generated_skirmish_display_name(session: SessionStateStoreScript.SessionData) -> String:
	return HumanEngine.native_writing(&"ScenarioSelectRules.generated_skirmish_display_name", [session])

static func restart_generated_skirmish_session(source: SessionStateStoreScript.SessionData) -> Dictionary:
	return HumanEngine.native_writing(&"ScenarioSelectRules.restart_generated_skirmish_session", [source])

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
	var scenario := ContentService.get_scenario_readonly(session.scenario_id)
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

static func _generated_map_package_dir() -> String:
	return HumanEngine.native_writing(&"ScenarioSelectRules._generated_map_package_dir", [])

static func random_map_size_class_label(size_class_id: String) -> String:
	return HumanEngine.native_writing(&"ScenarioSelectRules.random_map_size_class_label", [size_class_id])

# Returns the offered strength id, or "" when the value is not one of them.
static func random_map_monster_strength_id(value: String) -> String:
	return HumanEngine.native_writing(&"ScenarioSelectRules.random_map_monster_strength_id", [value])

static func random_map_monster_strength_label(value: String) -> String:
	return HumanEngine.native_writing(&"ScenarioSelectRules.random_map_monster_strength_label", [value])

static func _random_map_public_h3maped_launch_config(input_config: Dictionary) -> Dictionary:
	return HumanEngine.native_writing(&"ScenarioSelectRules._random_map_public_h3maped_launch_config", [input_config])

static func _scenario_items() -> Array:
	return ContentService.load_json(ContentService.SCENARIOS_PATH).get("items", [])

static func _scenario_domain_is_player_facing() -> bool:
	var raw := ContentService.load_json(ContentService.SCENARIOS_PATH)
	var status := String(raw.get("domain_status", ""))
	if status.begins_with("archived_") or status.ends_with("_disabled"):
		return false
	return true

static func _scenario_is_player_facing(scenario: Dictionary) -> bool:
	if scenario.is_empty():
		return false
	if scenario.has("active") and not bool(scenario.get("active", true)):
		return false
	if scenario.has("player_facing") and not bool(scenario.get("player_facing", true)):
		return false
	var content_status := String(scenario.get("content_status", ""))
	if content_status.begins_with("archived_") or content_status.ends_with("_disabled"):
		return false
	var selection: Dictionary = scenario.get("selection", {}) if scenario.get("selection", {}) is Dictionary else {}
	if selection.has("player_facing") and not bool(selection.get("player_facing", true)):
		return false
	return true

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

static func _skirmish_front_context(scenario: Dictionary, selection: Dictionary, availability: Dictionary) -> String:
	var scenario_id := String(scenario.get("id", ""))
	var scenario_name := String(scenario.get("name", scenario_id))
	var player_faction := ContentService.get_faction(String(scenario.get("player_faction_id", "")))
	var player_name := String(player_faction.get("name", scenario.get("player_faction_id", "Player host")))
	var enemy_summary := String(selection.get("enemy_summary", _default_enemy_summary(scenario)))
	var map_label := String(selection.get("map_size_label", _fallback_map_size_label(scenario)))
	return "Front context: %s | %s | %s against %s | %s." % [
		scenario_name,
		map_label,
		player_name,
		enemy_summary,
		availability_label(availability),
	]

static func _skirmish_objective_stakes(scenario: Dictionary) -> String:
	var objectives = scenario.get("objectives", {})
	if not (objectives is Dictionary):
		return ""
	var victory_text := String(objectives.get("victory_text", ""))
	var defeat_text := String(objectives.get("defeat_text", ""))
	if victory_text != "" and defeat_text != "":
		return "Objective stakes: %s Failure means %s" % [victory_text, defeat_text]
	if victory_text != "":
		return "Objective stakes: %s" % victory_text
	if defeat_text != "":
		return "Objective stakes: Failure means %s" % defeat_text
	return ""

static func _skirmish_readiness_summary(commander_preview: String, operational_board: String) -> String:
	var parts := []
	var readiness_line := _first_line_with_prefix(commander_preview, "Opening readiness:")
	if readiness_line != "":
		parts.append(readiness_line.replace("Opening readiness:", "opening").strip_edges())
	var failure_watch := _first_line_with_prefix(operational_board, "Failure watch:")
	if failure_watch != "":
		parts.append(failure_watch.replace("Failure watch:", "watch").strip_edges())
	var enemy_posture := _first_line_with_prefix(operational_board, "Enemy posture:")
	if enemy_posture != "":
		parts.append(enemy_posture.replace("Enemy posture:", "enemy").strip_edges())
	var first_contact := _first_line_with_prefix(operational_board, "Likely first contact:")
	if first_contact != "":
		parts.append(first_contact.replace("Likely first contact:", "first contact").strip_edges())
	if parts.is_empty():
		return ""
	return "Readiness watch: %s." % " | ".join(parts.slice(0, min(4, parts.size())))

static func _skirmish_briefing_check(
	_scenario: Dictionary,
	briefing_summary: String,
	objective_stakes: String,
	front_context: String,
	readiness_summary: String
) -> String:
	var briefing_line := _first_substantive_line(briefing_summary)
	if briefing_line == "":
		briefing_line = _first_substantive_line(objective_stakes)
	if briefing_line == "":
		briefing_line = "Open the map, identify the nearest guarded reward or town route, and commit the first hero day deliberately."
	var first_decision := _first_substantive_line(readiness_summary)
	if first_decision == "":
		first_decision = _first_substantive_line(front_context)
	if first_decision == "":
		first_decision = "choose the opening route before ending Day 1"
	return "Opening briefing: %s. First decision: %s." % [
		_compact_sentence(briefing_line, 170),
		_compact_sentence(first_decision, 130),
	]

static func _skirmish_difficulty_consequence(difficulty_id: String, recommended_difficulty: String) -> String:
	return HumanEngine.native_writing(&"ScenarioSelectRules._skirmish_difficulty_consequence", [difficulty_id, recommended_difficulty])

static func describe_skirmish_difficulty_check(difficulty_id: String, recommended_difficulty: String) -> String:
	return HumanEngine.native_writing(&"ScenarioSelectRules.describe_skirmish_difficulty_check", [difficulty_id, recommended_difficulty])

static func _skirmish_action_consequence(difficulty_id: String) -> String:
	return "Action consequence: Launching creates a fresh Skirmish expedition on Day 1 at %s difficulty, uses authored opening forces, does not load or overwrite an expedition save, and does not change campaign progression." % difficulty_label(difficulty_id)

static func _skirmish_launch_handoff(
	scenario: Dictionary,
	difficulty_id: String,
	launch_preview: String,
	objective_stakes: String,
	action_consequence: String
) -> String:
	var scenario_id := String(scenario.get("id", ""))
	var scenario_name := String(scenario.get("name", scenario_id))
	var objective_line := _first_line_with_prefix(launch_preview, "Objective:")
	if objective_line == "":
		objective_line = objective_stakes
	var objective_text := objective_line
	if objective_text == "":
		objective_text = "Objective: authored scenario objective applies"
	var continuity_text := "fresh expedition, no save load or overwrite, campaign progress unchanged"
	if action_consequence.find("does not change campaign progression") < 0:
		continuity_text = "fresh expedition, no save load or overwrite"
	return "Launch handoff: %s starts a fresh Skirmish expedition on Day 1 at %s difficulty; %s; continuity %s." % [
		scenario_name,
		difficulty_label(difficulty_id),
		objective_text,
		continuity_text,
	]

static func _first_line_with_prefix(text: String, prefix: String) -> String:
	for raw_line in text.split("\n"):
		var line := String(raw_line).strip_edges()
		if line.begins_with(prefix):
			return line
	return ""

static func _first_substantive_line(text: String) -> String:
	return HumanEngine.native_writing(&"ScenarioSelectRules._first_substantive_line", [text])

static func _compact_sentence(text: String, max_chars: int) -> String:
	return HumanEngine.native_writing(&"ScenarioSelectRules._compact_sentence", [text, max_chars])

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
