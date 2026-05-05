class_name ScenarioSelectRules
extends RefCounted

const SessionStateStoreScript = preload("res://scripts/core/SessionStateStore.gd")
const ScenarioFactoryScript = preload("res://scripts/core/ScenarioFactory.gd")
const RandomMapGeneratorRulesScript = preload("res://scripts/core/RandomMapGeneratorRules.gd")
const NativeRandomMapPackageSessionBridgeScript = preload("res://scripts/persistence/NativeRandomMapPackageSessionBridge.gd")
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
const RANDOM_MAP_PLAYER_TEMPLATE_OPTIONS := [
	{
		"id": "border_gate_compact_v1",
		"label": "Border Gate Compact",
		"profile_id": "border_gate_compact_profile_v1",
		"player_count": 3,
		"water_modes": ["land"],
		"supports_underground": false,
	},
	{
		"id": "frontier_spokes_v1",
		"label": "Frontier Spokes",
		"profile_id": "frontier_spokes_profile_v1",
		"player_count": 3,
		"water_modes": ["land"],
		"supports_underground": false,
	},
	{
		"id": "translated_rmg_template_001_v1",
		"label": "Translated Islands",
		"profile_id": "translated_rmg_profile_001_v1",
		"player_count": 4,
		"water_modes": ["land", "islands"],
		"supports_underground": true,
	},
	{
		"id": "translated_rmg_template_002_v1",
		"label": "Translated Ring Mesh",
		"profile_id": "translated_rmg_profile_002_v1",
		"player_count": 4,
		"water_modes": ["land"],
		"supports_underground": true,
	},
	{
		"id": "translated_rmg_template_042_v1",
		"label": "Translated Large Mesh",
		"profile_id": "translated_rmg_profile_042_v1",
		"player_count": 4,
		"water_modes": ["land"],
		"supports_underground": true,
	},
	{
		"id": "translated_rmg_template_043_v1",
		"label": "Translated Extra Large Mesh",
		"profile_id": "translated_rmg_profile_043_v1",
		"player_count": 4,
		"water_modes": ["land"],
		"supports_underground": true,
	},
]
const RANDOM_MAP_PLAYER_PROFILE_OPTIONS := [
	{
		"id": "border_gate_compact_profile_v1",
		"label": "Border Gate",
		"template_id": "border_gate_compact_v1",
		"guard_strength_profile": "core_low",
		"faction_ids": ["faction_embercourt", "faction_mireclaw", "faction_sunvault"],
	},
	{
		"id": "frontier_spokes_profile_v1",
		"label": "Frontier Spokes",
		"template_id": "frontier_spokes_v1",
		"guard_strength_profile": "core_low",
		"faction_ids": ["faction_embercourt", "faction_mireclaw", "faction_sunvault"],
	},
	{
		"id": "translated_rmg_profile_001_v1",
		"label": "Translated Parity",
		"template_id": "translated_rmg_template_001_v1",
		"guard_strength_profile": "core_low",
		"faction_ids": ["faction_embercourt", "faction_mireclaw", "faction_sunvault", "faction_thornwake"],
	},
	{
		"id": "translated_rmg_profile_002_v1",
		"label": "Translated Ring Mesh",
		"template_id": "translated_rmg_template_002_v1",
		"guard_strength_profile": "preserve_source_guard_values",
		"faction_ids": ["faction_embercourt", "faction_mireclaw", "faction_sunvault", "faction_thornwake"],
	},
	{
		"id": "translated_rmg_profile_042_v1",
		"label": "Translated Large Mesh",
		"template_id": "translated_rmg_template_042_v1",
		"guard_strength_profile": "preserve_source_guard_values",
		"faction_ids": ["faction_embercourt", "faction_mireclaw", "faction_sunvault", "faction_thornwake"],
	},
	{
		"id": "translated_rmg_profile_043_v1",
		"label": "Translated Extra Large Mesh",
		"template_id": "translated_rmg_template_043_v1",
		"guard_strength_profile": "preserve_source_guard_values",
		"faction_ids": ["faction_embercourt", "faction_mireclaw", "faction_sunvault", "faction_thornwake"],
	},
]
const RANDOM_MAP_FALLBACK_PLAYER_COUNT_OPTIONS := [2, 3, 4]
const RANDOM_MAP_RUNTIME_SIZE_CAP := {"width": 144, "height": 144, "level_count": 2}
const RANDOM_MAP_SIZE_CLASS_DEFAULTS := {
	"homm3_small": {"template_id": "border_gate_compact_v1", "profile_id": "border_gate_compact_profile_v1", "player_count": 3},
	"homm3_medium": {"template_id": "translated_rmg_template_002_v1", "profile_id": "translated_rmg_profile_002_v1", "player_count": 4},
	"homm3_large": {"template_id": "translated_rmg_template_042_v1", "profile_id": "translated_rmg_profile_042_v1", "player_count": 4},
	"homm3_extra_large": {"template_id": "translated_rmg_template_043_v1", "profile_id": "translated_rmg_profile_043_v1", "player_count": 4},
}
const RANDOM_MAP_SIZE_OPTIONS := [
	{
		"id": "homm3_small",
		"label": "Small 36x36",
		"source_model": "homm3_classic_size_class",
		"source_width": 36,
		"source_height": 36,
		"materialization_available": true,
		"runtime_policy": "materialize_at_source_size_within_current_144x144x2_cap",
		"rationale": "Small materializes at its source dimensions.",
	},
	{
		"id": "homm3_medium",
		"label": "Medium 72x72",
		"source_model": "homm3_classic_size_class",
		"source_width": 72,
		"source_height": 72,
		"materialization_available": true,
		"runtime_policy": "materialize_at_source_size_within_current_144x144x2_cap",
		"rationale": "Medium materializes at its source dimensions.",
	},
	{
		"id": "homm3_large",
		"label": "Large 108x108",
		"source_model": "homm3_classic_size_class",
		"source_width": 108,
		"source_height": 108,
		"materialization_available": true,
		"runtime_policy": "materialize_at_source_size_within_current_144x144x2_cap",
		"rationale": "Large materializes at its source dimensions.",
	},
	{
		"id": "homm3_extra_large",
		"label": "Extra Large 144x144",
		"source_model": "homm3_classic_size_class",
		"source_width": 144,
		"source_height": 144,
		"materialization_available": true,
		"runtime_policy": "materialize_at_source_size_within_current_144x144x2_cap",
		"rationale": "Extra Large materializes at its source dimensions.",
	},
]
const RANDOM_MAP_WATER_OPTIONS := [
	{"id": "land", "label": "Land"},
	{"id": "islands", "label": "Islands"},
]
const RANDOM_MAP_PLAYER_RETRY_POLICY := {
	"max_attempts": 2,
	"mode": "seed_salt",
}
const RANDOM_MAP_DEFAULT_SEED := "aurelion-random-skirmish-10184"
const RANDOM_MAP_AUTO_SEED_PREFIX := "aurelion-auto-random-skirmish"
const GENERATED_MAP_DEV_DIR := "res://maps"
const GENERATED_MAP_RUNTIME_DIR := "user://maps"
const GENERATED_MAP_PACKAGE_FEATURE_GATE := "native_rmg_generated_map_package_startup"
const MAPS_FOLDER_PACKAGE_ID_PREFIX := "maps_package:"

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
	var normalized_mode := SessionStateStoreScript.normalize_launch_mode(launch_mode)
	if normalized_mode == SessionStateStoreScript.LAUNCH_MODE_GENERATED_DRAFT:
		return "Generated Draft"
	return "Skirmish" if normalized_mode == SessionStateStoreScript.LAUNCH_MODE_SKIRMISH else "Campaign"

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
	for package_entry in build_maps_folder_package_browser_entries():
		entries.append(package_entry)
	return entries

static func build_skirmish_setup(scenario_id: String, difficulty_id: String) -> Dictionary:
	if maps_folder_package_id_is_valid(scenario_id):
		return build_maps_folder_package_skirmish_setup(scenario_id, difficulty_id)
	var scenario := ContentService.get_scenario(scenario_id)
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
	var setup_lines := []
	setup_lines.append(launch_handoff)
	setup_lines.append(launch_preview)
	for context_line in [front_context, objective_stakes, readiness_summary, difficulty_check, difficulty_consequence]:
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
	for action_line in [front_context, readiness_summary, difficulty_check, difficulty_consequence, action_consequence]:
		if String(action_line) != "":
			action_tooltip_lines.append(String(action_line))

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
		"launch_handoff": launch_handoff,
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
	var template_options := _random_map_template_options_with_player_counts()
	var profile_options := _random_map_profile_options()
	return {
		"templates": template_options,
		"profiles": profile_options,
		"size_classes": RANDOM_MAP_SIZE_OPTIONS.duplicate(true),
		"player_counts": _random_map_all_player_count_options(template_options),
		"player_count_options_by_template": _random_map_player_count_options_by_template(template_options),
		"profile_options_by_template": _random_map_profile_options_by_template(profile_options),
		"water_modes": RANDOM_MAP_WATER_OPTIONS.duplicate(true),
		"retry_policy": RANDOM_MAP_PLAYER_RETRY_POLICY.duplicate(true),
		"default_seed": RANDOM_MAP_DEFAULT_SEED,
		"default_size_class_id": "homm3_small",
		"default_template_id": "border_gate_compact_v1",
		"default_profile_id": "border_gate_compact_profile_v1",
		"size_class_defaults": RANDOM_MAP_SIZE_CLASS_DEFAULTS.duplicate(true),
		"default_player_count": _random_map_normalize_player_count_for_template("border_gate_compact_v1", 3, 3),
		"default_water_mode": "land",
		"default_underground": false,
		"package_directory_policy": generated_map_package_directory_policy(),
	}

static func generated_map_package_directory_policy() -> Dictionary:
	return {
		"schema_id": "aurelion_generated_map_package_directory_policy_v1",
		"dev_source_dir": GENERATED_MAP_DEV_DIR,
		"export_runtime_dir": GENERATED_MAP_RUNTIME_DIR,
		"active_dir": _generated_map_package_dir(),
		"active_dir_kind": "project_source_dev_maps" if _use_project_maps_dir() else "export_runtime_user_maps",
		"semantics": "Generated random-map startup writes .amap/.ascenario packages, then starts from packages loaded back from this directory. It does not write generated records into content/scenarios.json.",
	}

static func maps_folder_package_id_is_valid(package_id: String) -> bool:
	return package_id.begins_with(MAPS_FOLDER_PACKAGE_ID_PREFIX)

static func maps_folder_package_id_for_stem(package_stem: String) -> String:
	return "%s%s" % [MAPS_FOLDER_PACKAGE_ID_PREFIX, _safe_package_stem(package_stem)]

static func maps_folder_package_stem_from_id(package_id: String) -> String:
	if not maps_folder_package_id_is_valid(package_id):
		return ""
	return package_id.substr(MAPS_FOLDER_PACKAGE_ID_PREFIX.length())

static func build_maps_folder_package_browser_entries(options: Dictionary = {}) -> Array:
	return maps_folder_package_index(options).get("entries", [])

static func maps_folder_package_index(options: Dictionary = {}) -> Dictionary:
	var service: Variant = _native_map_package_service()
	var package_dir := String(options.get("package_dir", _generated_map_package_dir()))
	var result := {
		"ok": true,
		"schema_id": "aurelion_maps_folder_package_index_v1",
		"package_dir": package_dir,
		"directory_policy": generated_map_package_directory_policy(),
		"entries": [],
		"warnings": [],
		"message": "",
		"authored_json_scenarios_used": false,
	}
	if service == null:
		result["ok"] = false
		result["message"] = "Native MapPackageService is required to read generated map packages."
		return result
	var dir := DirAccess.open(package_dir)
	if dir == null:
		result["message"] = "No generated maps folder exists yet."
		return result
	var stems_by_kind := _maps_folder_package_stems(dir)
	var map_stems: Dictionary = stems_by_kind.get("map_stems", {})
	var scenario_stems: Dictionary = stems_by_kind.get("scenario_stems", {})
	var stems := []
	for stem in map_stems.keys():
		if scenario_stems.has(stem):
			stems.append(String(stem))
	stems.sort()
	for stem in stems:
		var entry := _maps_folder_package_record(service, package_dir, stem)
		if bool(entry.get("ok", false)):
			result["entries"].append(entry)
		else:
			result["warnings"].append(entry)
	result["unpaired_map_count"] = max(0, map_stems.size() - stems.size())
	result["unpaired_scenario_count"] = max(0, scenario_stems.size() - stems.size())
	if result["entries"].is_empty():
		result["message"] = "No generated .amap/.ascenario package pairs are available."
	return result

static func maps_folder_package_entry(package_id: String, options: Dictionary = {}) -> Dictionary:
	var index := maps_folder_package_index(options)
	for entry in index.get("entries", []):
		if entry is Dictionary and String(entry.get("package_id", "")) == package_id:
			return entry
	return {}

static func build_maps_folder_package_skirmish_setup(package_id: String, difficulty_id: String = "normal", options: Dictionary = {}) -> Dictionary:
	var entry := maps_folder_package_entry(package_id, options)
	if entry.is_empty():
		return {}
	var normalized_difficulty := normalize_difficulty(difficulty_id)
	var difficulty_label_text := difficulty_label(normalized_difficulty)
	var setup_lines := [
		"Launch handoff: selected generated map starts from paired packages in maps/; authored scenario JSON stays out of this path.",
		String(entry.get("summary", "")),
		"Packages: %s | %s" % [String(entry.get("map_path", "")), String(entry.get("scenario_path", ""))],
		"Mode: %s | Difficulty: %s" % [launch_mode_label(SessionStateStoreScript.LAUNCH_MODE_SKIRMISH), difficulty_label_text],
		"Boundary: native packages loaded from disk; no content/scenarios.json startup, generated draft registry, campaign adoption, or legacy scenario JSON writeback.",
	]
	return {
		"ok": true,
		"setup_kind": "maps_folder_generated_package_skirmish",
		"startup_source": "maps_folder_package",
		"launch_mode": SessionStateStoreScript.LAUNCH_MODE_SKIRMISH,
		"difficulty": normalized_difficulty,
		"difficulty_label": difficulty_label_text,
		"difficulty_summary": difficulty_summary(normalized_difficulty),
		"recommended_difficulty": default_difficulty_id(),
		"recommended_difficulty_label": difficulty_label(default_difficulty_id()),
		"scenario_id": package_id,
		"scenario_name": String(entry.get("display_name", package_id)),
		"summary": String(entry.get("summary", "")),
		"setup_summary": "\n".join(setup_lines),
		"launch_preview": "Launch generated map package %s." % String(entry.get("display_name", package_id)),
		"launch_handoff": String(setup_lines[0]),
		"front_context": String(entry.get("front_context", "")),
		"objective_stakes": "Package objective: defeat generated rivals from the loaded scenario document.",
		"readiness_summary": String(entry.get("readiness_summary", "")),
		"difficulty_check": describe_skirmish_difficulty_check(normalized_difficulty, default_difficulty_id()),
		"difficulty_consequence": _skirmish_difficulty_consequence(normalized_difficulty, default_difficulty_id()),
		"action_consequence": "Starts a fresh package-backed skirmish session without mutating maps/ or authored JSON content.",
		"action_tooltip": "\n".join(setup_lines),
		"commander_preview": "Commander preview: %s opens with Lyra at the generated start anchor." % String(entry.get("display_name", package_id)),
		"operational_board": String(entry.get("operational_board", "")),
		"package_entry": entry,
		"map_ref": entry.get("map_ref", {}),
		"scenario_ref": entry.get("scenario_ref", {}),
		"campaign_adoption": false,
		"alpha_parity_claim": false,
	}

static func load_maps_folder_package_session(package_id: String, difficulty_id: String = "normal", options: Dictionary = {}) -> SessionStateStoreScript.SessionData:
	var entry := maps_folder_package_entry(package_id, options)
	if entry.is_empty():
		return SessionStateStoreScript.new_session_data()
	return _load_maps_folder_package_session_from_entry(entry, normalize_difficulty(difficulty_id), options)

static func start_maps_folder_package_skirmish_session(package_id: String, difficulty_id: String = "normal") -> SessionStateStoreScript.SessionData:
	var session := load_maps_folder_package_session(package_id, difficulty_id, {"startup_source": "skirmish_browser_maps_folder"})
	if session.scenario_id == "":
		return session
	var boundary: Dictionary = session.flags.get("generated_random_map_boundary", {}) if session.flags.get("generated_random_map_boundary", {}) is Dictionary else {}
	boundary["adoption_path"] = "maps_folder_package_browser_loaded_from_disk"
	boundary["content_service_generated_draft"] = ContentService.has_generated_scenario_draft(session.scenario_id)
	boundary["legacy_json_scenario_record"] = false
	boundary["authored_json_scenarios_used"] = false
	session.flags["generated_random_map_boundary"] = boundary
	session.flags["maps_folder_package_browser"] = true
	OverworldRulesScript.normalize_overworld_state(session)
	SessionState.active_session = session
	return session

static func random_map_seed_requests_auto(seed: String) -> bool:
	var normalized_seed := seed.strip_edges()
	return normalized_seed == "" or normalized_seed == RANDOM_MAP_DEFAULT_SEED

static func random_map_fresh_auto_seed() -> String:
	return "%s-%d-%d" % [
		RANDOM_MAP_AUTO_SEED_PREFIX,
		Time.get_unix_time_from_system(),
		Time.get_ticks_usec(),
	]

static func random_map_player_count_options_for_template(template_id: String) -> Array:
	return _random_map_template_player_count_options(template_id, _random_map_template_option(template_id))

static func random_map_profile_options_for_template(template_id: String) -> Array:
	var options := []
	for option in _random_map_profile_options():
		if option is Dictionary and String(option.get("template_id", "")) == template_id:
			options.append(option.duplicate(true))
	if options.is_empty():
		options = _random_map_profile_options()
	return options

static func random_map_size_class_default(size_class_id: String) -> Dictionary:
	var size_option := _random_map_size_option(size_class_id)
	var normalized_id := String(size_option.get("id", "homm3_small"))
	var defaults: Dictionary = RANDOM_MAP_SIZE_CLASS_DEFAULTS.get(normalized_id, RANDOM_MAP_SIZE_CLASS_DEFAULTS.get("homm3_small", {}))
	var normalized_defaults := defaults.duplicate(true)
	var template_id := String(normalized_defaults.get("template_id", "border_gate_compact_v1"))
	normalized_defaults["player_count"] = _random_map_normalize_player_count_for_template(
		template_id,
		int(normalized_defaults.get("player_count", 3)),
		int(defaults.get("player_count", 3))
	)
	normalized_defaults["player_counts"] = _random_map_template_player_count_options(template_id, _random_map_template_option(template_id))
	return normalized_defaults

static func build_random_map_player_config(
	seed: String,
	template_id: String,
	profile_id: String,
	player_count: int,
	water_mode: String,
	underground_enabled: bool,
	size_class_id: String = "homm3_small"
) -> Dictionary:
	var size_option := _random_map_size_option(size_class_id)
	var size_defaults := random_map_size_class_default(String(size_option.get("id", "homm3_small")))
	var normalized_template_id := template_id.strip_edges()
	if normalized_template_id == "":
		normalized_template_id = String(size_defaults.get("template_id", "border_gate_compact_v1"))
	var template_option := _random_map_template_option(normalized_template_id)
	var normalized_profile_id := profile_id.strip_edges()
	if normalized_profile_id == "":
		normalized_profile_id = String(size_defaults.get("profile_id", template_option.get("profile_id", "border_gate_compact_profile_v1")))
	var profile_option := _random_map_profile_option(normalized_profile_id)
	if String(profile_option.get("template_id", normalized_template_id)) != normalized_template_id:
		normalized_profile_id = String(template_option.get("profile_id", size_defaults.get("profile_id", "border_gate_compact_profile_v1")))
		profile_option = _random_map_profile_option(normalized_profile_id)
	var source_width := int(size_option.get("source_width", 36))
	var source_height := int(size_option.get("source_height", 36))
	var normalized_player_count := _random_map_normalize_player_count_for_template(
		normalized_template_id,
		player_count,
		int(size_defaults.get("player_count", template_option.get("player_count", 3)))
	)
	var normalized_water_mode := "islands" if water_mode == "islands" else "land"
	var level_count := 2 if underground_enabled else 1
	var materialization_available := bool(size_option.get("materialization_available", false))
	var runtime_policy_status := String(size_option.get("runtime_policy", "blocked_source_size_exceeds_current_144x144x2_cap"))
	if materialization_available and level_count <= int(RANDOM_MAP_RUNTIME_SIZE_CAP.get("level_count", 2)):
		runtime_policy_status = "materialize_at_source_size_within_current_144x144x2_cap"
	return {
		"generator_version": RandomMapGeneratorRulesScript.GENERATOR_VERSION,
		"seed": seed,
		"size": {
			"preset": "player_facing_skirmish_setup",
			"size_class_id": String(size_option.get("id", "homm3_small")),
			"size_class_label": String(size_option.get("label", "Small 36x36")),
			"source_model": String(size_option.get("source_model", "homm3_classic_size_class")),
			"source_width": source_width,
			"source_height": source_height,
			"requested_width": source_width,
			"requested_height": source_height,
			"width": source_width,
			"height": source_height,
			"water_mode": normalized_water_mode,
			"level_count": level_count,
			"runtime_size_cap": RANDOM_MAP_RUNTIME_SIZE_CAP.duplicate(true),
			"runtime_size_policy": {
				"status": runtime_policy_status,
				"materialization_available": materialization_available,
				"rationale": String(size_option.get("rationale", "")),
				"hidden_downscale": false,
			},
		},
		"player_constraints": {
			"human_count": 1,
			"player_count": normalized_player_count,
			"computer_count": max(1, normalized_player_count - 1),
			"team_mode": "free_for_all",
		},
		"profile": {
			"id": String(profile_option.get("id", normalized_profile_id)),
			"template_id": normalized_template_id,
			"guard_strength_profile": String(profile_option.get("guard_strength_profile", "core_low")),
			"faction_ids": profile_option.get("faction_ids", []),
		},
	}

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

static func build_random_map_skirmish_setup_with_retry(
	input_config: Dictionary,
	difficulty_id: String = "normal",
	retry_policy: Dictionary = {}
) -> Dictionary:
	var policy := _random_map_retry_policy(retry_policy)
	var max_attempts := int(policy.get("max_attempts", 1))
	var attempts := []
	var final_setup := {}
	for attempt_index in range(max_attempts):
		var attempt_config := _random_map_retry_attempt_config(input_config, attempt_index, policy)
		var attempt_setup := build_random_map_skirmish_setup(attempt_config, difficulty_id)
		var attempt_record := _random_map_setup_attempt_record(attempt_setup, attempt_config, attempt_index + 1, max_attempts)
		attempts.append(attempt_record)
		if bool(attempt_setup.get("ok", false)):
			final_setup = attempt_setup
			break

	if not final_setup.is_empty():
		var retry_status := _random_map_retry_status_from_attempts(attempts, true, policy)
		final_setup["retry_status"] = retry_status
		final_setup["retry_attempts"] = attempts
		final_setup["failure_handoff"] = "Generation validated for launch after %d attempt(s); retry details are visible in setup and preserved in save/replay metadata." % int(retry_status.get("attempt_count", 1))
		if not (final_setup.get("package_startup", {}) is Dictionary) or final_setup.get("package_startup", {}).is_empty():
			final_setup["setup_summary"] = _random_map_setup_summary(
				final_setup.get("generated_map", {}).get("scenario_record", {}),
				final_setup.get("generated_map", {}).get("metadata", {}),
				final_setup.get("validation", {}),
				retry_status,
				String(final_setup.get("difficulty", difficulty_id))
			)
		var provenance: Dictionary = final_setup.get("provenance", {}) if final_setup.get("provenance", {}) is Dictionary else {}
		provenance["retry_status"] = retry_status
		provenance["retry_attempts"] = attempts
		final_setup["provenance"] = provenance
		var replay: Dictionary = final_setup.get("replay_metadata", {}) if final_setup.get("replay_metadata", {}) is Dictionary else {}
		replay["retry_status"] = retry_status
		final_setup["replay_metadata"] = replay
		return final_setup

	var retry_status := _random_map_retry_status_from_attempts(attempts, false, policy)
	var last_attempt: Dictionary = attempts[attempts.size() - 1] if not attempts.is_empty() else {}
	var last_validation: Dictionary = last_attempt.get("validation", {}) if last_attempt.get("validation", {}) is Dictionary else {}
	return {
		"ok": false,
		"setup_kind": "generated_random_map_skirmish",
		"launch_mode": SessionStateStoreScript.LAUNCH_MODE_SKIRMISH,
		"difficulty": normalize_difficulty(difficulty_id),
		"difficulty_label": difficulty_label(difficulty_id),
		"validation": last_validation,
		"retry_status": retry_status,
		"retry_attempts": attempts,
		"failure_handoff": _random_map_failure_handoff(last_validation, retry_status),
		"setup_summary": _random_map_failure_setup_summary(last_validation, retry_status, attempts),
		"campaign_adoption": false,
		"alpha_parity_claim": false,
	}

static func build_random_map_skirmish_setup(input_config: Dictionary, difficulty_id: String = "normal") -> Dictionary:
	var normalized_difficulty := normalize_difficulty(difficulty_id)
	var service: Variant = _native_map_package_service()
	if service == null:
		return _native_package_setup_failure(
			"native_package_service_unavailable",
			"Native MapPackageService is required for generated skirmish startup.",
			normalized_difficulty
		)
	var generated: Dictionary = service.generate_random_map(input_config, {"startup_path": "generated_skirmish"})
	var report: Dictionary = generated.get("report", generated.get("validation_report", {})) if generated.get("report", generated.get("validation_report", {})) is Dictionary else {}
	var retry_status := _random_map_retry_status(generated, report)
	if not bool(generated.get("ok", false)):
		return {
			"ok": false,
			"setup_kind": "generated_random_map_skirmish",
			"launch_mode": SessionStateStoreScript.LAUNCH_MODE_SKIRMISH,
			"difficulty": normalized_difficulty,
			"validation": report,
			"retry_status": retry_status,
			"failure_handoff": _random_map_failure_handoff(report, retry_status),
			"campaign_adoption": false,
			"alpha_parity_claim": false,
		}

	var adoption: Dictionary = service.convert_generated_payload(generated, {
		"feature_gate": GENERATED_MAP_PACKAGE_FEATURE_GATE,
		"session_save_version": SessionStateStoreScript.SAVE_VERSION,
	})
	if not bool(adoption.get("ok", false)):
		return _native_package_setup_failure(
			String(adoption.get("error_code", "native_package_conversion_failed")),
			String(adoption.get("message", "Native generated payload could not be converted to package documents.")),
			normalized_difficulty,
			adoption.get("report", {}) if adoption.get("report", {}) is Dictionary else report
		)
	var persisted := _persist_and_load_generated_packages(service, adoption, generated)
	if not bool(persisted.get("ok", false)):
		return _native_package_setup_failure(
			String(persisted.get("error_code", "native_package_persist_load_failed")),
			String(persisted.get("message", "Native generated packages could not be saved and loaded.")),
			normalized_difficulty,
			persisted.get("report", {}) if persisted.get("report", {}) is Dictionary else report
		)

	var identity := _native_random_map_generated_identity(generated, adoption, persisted)
	var provenance := _native_random_map_provenance(input_config, generated, adoption, persisted, retry_status)
	var setup_summary := _native_random_map_setup_summary(generated, adoption, persisted, report, retry_status, normalized_difficulty)
	var scenario_ref: Dictionary = persisted.get("scenario_ref", {}) if persisted.get("scenario_ref", {}) is Dictionary else {}
	var map_ref: Dictionary = persisted.get("map_ref", {}) if persisted.get("map_ref", {}) is Dictionary else {}
	return {
		"ok": true,
		"setup_kind": "generated_random_map_skirmish",
		"startup_source": "native_rmg_disk_package",
		"launch_mode": SessionStateStoreScript.LAUNCH_MODE_SKIRMISH,
		"difficulty": normalized_difficulty,
		"difficulty_label": difficulty_label(normalized_difficulty),
		"generated_map": {},
		"native_generation": {
			"status": String(generated.get("status", "")),
			"full_generation_status": String(generated.get("full_generation_status", "")),
			"validation_status": String(generated.get("validation_status", "")),
			"supported_parity_config": bool(generated.get("supported_parity_config", false)),
		},
		"package_startup": persisted,
		"scenario_id": String(identity.get("scenario_id", "")),
		"scenario_name": String(identity.get("scenario_id", "")),
		"template_id": String(identity.get("template_id", "")),
		"profile_id": String(identity.get("profile_id", "")),
		"normalized_seed": String(identity.get("normalized_seed", "")),
		"seed_source": String(input_config.get("seed_source", "explicit")),
		"seed_input": String(input_config.get("seed_input", String(input_config.get("seed", "")))),
		"content_manifest_fingerprint": String(identity.get("content_manifest_fingerprint", "")),
		"generated_identity": identity,
		"validation": report,
		"retry_status": retry_status,
		"provenance": provenance,
		"replay_metadata": _random_map_replay_metadata(provenance, identity, retry_status),
		"setup_summary": setup_summary,
		"map_ref": map_ref,
		"scenario_ref": scenario_ref,
		"launch_handoff": "Launch handoff: generated Skirmish starts from native packages written under maps/ and loaded back from disk; authored scenario JSON stays out of the startup path.",
		"failure_handoff": "Generation validated for launch; package refs and retry metadata are preserved for save/replay inspection.",
		"campaign_adoption": false,
		"alpha_parity_claim": bool(generated.get("full_parity_claim", false)),
	}

static func start_random_map_skirmish_session(input_config: Dictionary, difficulty_id: String = "normal") -> SessionStateStoreScript.SessionData:
	var setup := build_random_map_skirmish_setup(input_config, difficulty_id)
	return _start_random_map_skirmish_session_from_setup(setup)

static func start_random_map_skirmish_session_with_retry(
	input_config: Dictionary,
	difficulty_id: String = "normal",
	retry_policy: Dictionary = {}
) -> SessionStateStoreScript.SessionData:
	var setup := build_random_map_skirmish_setup_with_retry(input_config, difficulty_id, retry_policy)
	return _start_random_map_skirmish_session_from_setup(setup)

static func start_random_map_skirmish_session_from_setup(setup: Dictionary) -> SessionStateStoreScript.SessionData:
	return _start_random_map_skirmish_session_from_setup(setup)

static func _start_random_map_skirmish_session_from_setup(setup: Dictionary) -> SessionStateStoreScript.SessionData:
	if not bool(setup.get("ok", false)):
		push_warning(String(setup.get("failure_handoff", "Generated skirmish setup failed validation.")))
		return SessionStateStoreScript.new_session_data()

	var payload: Dictionary = setup.get("generated_map", {})
	var package_startup: Dictionary = setup.get("package_startup", {}) if setup.get("package_startup", {}) is Dictionary else {}
	var session: SessionStateStoreScript.SessionData
	if not package_startup.is_empty():
		var service: Variant = _native_map_package_service()
		if service == null:
			return SessionStateStoreScript.new_session_data()
		var map_load: Dictionary = service.load_map_package(String(package_startup.get("map_path", "")))
		var scenario_load: Dictionary = service.load_scenario_package(String(package_startup.get("scenario_path", "")))
		var bridge := NativeRandomMapPackageSessionBridgeScript.new()
		session = bridge.build_session_from_loaded_packages(
			map_load,
			scenario_load,
			package_startup.get("session_boundary_record", {}),
			String(setup.get("difficulty", default_difficulty_id())),
			{"hero_id": "hero_lyra"}
		)
	else:
		session = ScenarioFactoryScript.create_generated_skirmish_session(
			payload,
			String(setup.get("difficulty", default_difficulty_id())),
			{
				"provenance": setup.get("provenance", {}),
				"replay_metadata": setup.get("replay_metadata", {}),
				"validation": setup.get("validation", {}),
				"retry_status": setup.get("retry_status", {}),
				"generated_identity": setup.get("generated_identity", {}),
				"boundary": {
					"authored_content_writeback": false,
					"campaign_adoption": false,
					"skirmish_browser_authored_listing": false,
					"alpha_parity_claim": false,
					"legacy_compatibility_only": true,
				},
			}
		)
	if session.scenario_id == "":
		return session
	session.flags["generated_random_map_provenance"] = setup.get("provenance", {})
	session.flags["generated_random_map_replay_metadata"] = setup.get("replay_metadata", {})
	session.flags["generated_random_map_validation"] = setup.get("validation", {})
	session.flags["generated_random_map_retry_status"] = setup.get("retry_status", {})
	session.flags["generated_random_map_boundary"]["adoption_path"] = "native_rmg_generated_package_saved_loaded_from_disk" if not package_startup.is_empty() else "legacy_skirmish_session_only_no_authored_browser_or_campaign"
	session.flags["generated_random_map_boundary"]["content_service_generated_draft"] = ContentService.has_generated_scenario_draft(session.scenario_id)
	session.overworld["generated_random_map_provenance"] = setup.get("provenance", {})
	session.overworld["generated_random_map_replay_metadata"] = setup.get("replay_metadata", {})
	session.overworld["generated_random_map_validation"] = setup.get("validation", {})
	session.overworld["generated_random_map_retry_status"] = setup.get("retry_status", {})
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

static func _random_map_retry_status(generated: Dictionary, report: Dictionary) -> Dictionary:
	var ok := bool(generated.get("ok", false))
	return {
		"policy": "single_validated_attempt_no_automatic_retry_in_this_slice",
		"attempt_count": 1,
		"retry_count": 0,
		"status": "pass" if ok else "failed_before_launch",
		"validation_status": String(report.get("status", "pass" if ok else "fail")),
		"failure_count": int(report.get("failure_count", 0)),
		"warning_count": int(report.get("warning_count", 0)),
	}

static func _native_map_package_service() -> Variant:
	if not ClassDB.class_exists("MapPackageService"):
		return null
	return ClassDB.instantiate("MapPackageService")

static func _maps_folder_package_stems(dir: DirAccess) -> Dictionary:
	var map_stems := {}
	var scenario_stems := {}
	dir.list_dir_begin()
	var filename := dir.get_next()
	while filename != "":
		if not dir.current_is_dir():
			if filename.ends_with(".amap"):
				map_stems[filename.get_basename()] = true
			elif filename.ends_with(".ascenario"):
				scenario_stems[filename.get_basename()] = true
		filename = dir.get_next()
	dir.list_dir_end()
	return {"map_stems": map_stems, "scenario_stems": scenario_stems}

static func _maps_folder_package_record(service: Variant, package_dir: String, package_stem: String) -> Dictionary:
	var map_path := "%s/%s.amap" % [package_dir, package_stem]
	var scenario_path := "%s/%s.ascenario" % [package_dir, package_stem]
	var map_inspect: Dictionary = service.inspect_package(map_path)
	var scenario_inspect: Dictionary = service.inspect_package(scenario_path)
	if not bool(map_inspect.get("ok", false)) or not bool(scenario_inspect.get("ok", false)):
		return {
			"ok": false,
			"package_stem": package_stem,
			"map_path": map_path,
			"scenario_path": scenario_path,
			"error_code": "package_inspect_failed",
			"map_inspect": _public_package_load_result(map_inspect),
			"scenario_inspect": _public_package_load_result(scenario_inspect),
		}
	if bool(map_inspect.get("legacy_json_scenario_record", true)) or bool(scenario_inspect.get("legacy_json_scenario_record", true)):
		return {
			"ok": false,
			"package_stem": package_stem,
			"map_path": map_path,
			"scenario_path": scenario_path,
			"error_code": "legacy_json_package_rejected",
		}
	var map_load: Dictionary = service.load_map_package(map_path)
	var scenario_load: Dictionary = service.load_scenario_package(scenario_path)
	if not bool(map_load.get("ok", false)) or not bool(scenario_load.get("ok", false)):
		return {
			"ok": false,
			"package_stem": package_stem,
			"map_path": map_path,
			"scenario_path": scenario_path,
			"error_code": "package_load_failed",
			"map_load": _public_package_load_result(map_load),
			"scenario_load": _public_package_load_result(scenario_load),
		}
	var map_document: Variant = map_load.get("map_document", null)
	var scenario_document: Variant = scenario_load.get("scenario_document", null)
	var metadata := _map_document_metadata(map_document)
	var map_ref: Dictionary = map_load.get("map_ref", {}) if map_load.get("map_ref", {}) is Dictionary else {}
	var scenario_ref: Dictionary = scenario_load.get("scenario_ref", {}) if scenario_load.get("scenario_ref", {}) is Dictionary else {}
	var package_id := maps_folder_package_id_for_stem(package_stem)
	var display_name := _maps_folder_display_name(package_stem, metadata, scenario_document)
	var width: int = map_document.get_width() if map_document != null else 0
	var height: int = map_document.get_height() if map_document != null else 0
	var level_count: int = map_document.get_level_count() if map_document != null else 1
	var player_count := _scenario_document_player_count(scenario_document)
	var generated := String(map_ref.get("source_kind", metadata.get("source_kind", "generated"))) == "generated"
	if not generated:
		return {
			"ok": false,
			"package_stem": package_stem,
			"map_path": map_path,
			"scenario_path": scenario_path,
			"error_code": "non_generated_package_rejected",
		}
	var map_size_label := "%dx%d L%d" % [width, height, max(1, level_count)]
	var summary := "Generated package | %s | Players %d | %s" % [
		map_size_label,
		max(1, player_count),
		_maps_folder_metadata_summary(metadata),
	]
	return {
		"ok": true,
		"package_id": package_id,
		"scenario_id": package_id,
		"package_stem": package_stem,
		"label": "%s | %s | %s" % [display_name, map_size_label, difficulty_label(default_difficulty_id())],
		"display_name": display_name,
		"summary": summary,
		"front_context": "Front: generated package pair from maps/.",
		"readiness_summary": "Readiness: paired .amap/.ascenario files load through native MapPackageService.",
		"operational_board": "%s\n%s\n%s" % [summary, map_path, scenario_path],
		"map_path": map_path,
		"scenario_path": scenario_path,
		"map_ref": map_ref,
		"scenario_ref": scenario_ref,
		"map_size": {"width": width, "height": height, "x": width, "y": height, "level_count": max(1, level_count)},
		"player_count": max(1, player_count),
		"metadata": metadata,
		"source_kind": "generated",
		"startup_source": "maps_folder_package",
		"legacy_json_scenario_record": false,
		"authored_json_scenarios_used": false,
	}

static func _load_maps_folder_package_session_from_entry(entry: Dictionary, difficulty_id: String, options: Dictionary = {}) -> SessionStateStoreScript.SessionData:
	var service: Variant = _native_map_package_service()
	if service == null:
		return SessionStateStoreScript.new_session_data()
	var map_path := String(entry.get("map_path", ""))
	var scenario_path := String(entry.get("scenario_path", ""))
	var map_load: Dictionary = service.load_map_package(map_path)
	var scenario_load: Dictionary = service.load_scenario_package(scenario_path)
	var map_ref: Dictionary = entry.get("map_ref", {}) if entry.get("map_ref", {}) is Dictionary else {}
	var scenario_ref: Dictionary = entry.get("scenario_ref", {}) if entry.get("scenario_ref", {}) is Dictionary else {}
	var boundary := {
		"scenario_id": String(scenario_ref.get("scenario_id", "")),
		"session_id": "%s-%d" % [String(options.get("session_id_prefix", "maps_folder_package_session")), Time.get_ticks_msec()],
		"hero_id": "hero_lyra",
		"feature_gate": GENERATED_MAP_PACKAGE_FEATURE_GATE,
		"map_package_ref": map_ref,
		"scenario_package_ref": scenario_ref,
		"launch_mode": SessionStateStoreScript.LAUNCH_MODE_SKIRMISH,
		"runtime_call_site_adoption": true,
		"generated_record_policy": "maps_folder_package_loaded_documents_only",
		"content_service_generated_draft": false,
		"legacy_json_scenario_record": false,
		"authored_json_scenarios_used": false,
		"map_package_path": map_path,
		"scenario_package_path": scenario_path,
		"package_id": String(entry.get("package_id", "")),
		"package_stem": String(entry.get("package_stem", "")),
		"startup_source": String(options.get("startup_source", "maps_folder_package")),
	}
	var bridge := NativeRandomMapPackageSessionBridgeScript.new()
	var session: SessionStateStoreScript.SessionData = bridge.build_session_from_loaded_packages(
		map_load,
		scenario_load,
		boundary,
		difficulty_id,
		{"hero_id": "hero_lyra"}
	)
	if session.scenario_id == "":
		return session
	session.flags["maps_folder_package_browser"] = true
	session.flags["maps_folder_package_entry"] = entry.duplicate(true)
	session.flags["generated_random_map_source"] = "maps_folder_package"
	session.flags["generated_random_map_package_paths"] = {"map_path": map_path, "scenario_path": scenario_path}
	session.flags["generated_random_map_boundary"]["adoption_path"] = "maps_folder_package_loaded_from_disk"
	session.flags["generated_random_map_boundary"]["content_service_generated_draft"] = ContentService.has_generated_scenario_draft(session.scenario_id)
	session.flags["generated_random_map_boundary"]["legacy_json_scenario_record"] = false
	session.flags["generated_random_map_boundary"]["authored_json_scenarios_used"] = false
	session.overworld["maps_folder_package_entry"] = entry.duplicate(true)
	OverworldRulesScript.normalize_overworld_state(session)
	return session

static func _map_document_metadata(map_document: Variant) -> Dictionary:
	if map_document != null and map_document.has_method("get_metadata"):
		var metadata: Dictionary = map_document.get_metadata()
		return metadata.duplicate(true)
	return {}

static func _scenario_document_player_count(scenario_document: Variant) -> int:
	if scenario_document != null and scenario_document.has_method("get_player_slots"):
		var player_slots: Array = scenario_document.get_player_slots()
		if not player_slots.is_empty():
			return player_slots.size()
	return 1

static func _maps_folder_display_name(package_stem: String, metadata: Dictionary, scenario_document: Variant) -> String:
	var candidate := String(metadata.get("display_name", metadata.get("name", ""))).strip_edges()
	if candidate != "":
		return candidate
	if scenario_document != null and scenario_document.has_method("get_selection"):
		var selection: Dictionary = scenario_document.get_selection()
		candidate = String(selection.get("name", selection.get("label", ""))).strip_edges()
		if candidate != "":
			return candidate
	return _title_from_package_stem(package_stem)

static func _maps_folder_metadata_summary(metadata: Dictionary) -> String:
	var normalized: Dictionary = metadata.get("normalized_config", {}) if metadata.get("normalized_config", {}) is Dictionary else {}
	var parts := []
	var seed := String(normalized.get("normalized_seed", normalized.get("seed", ""))).strip_edges()
	var template_id := String(normalized.get("template_id", "")).strip_edges()
	var profile_id := String(normalized.get("profile_id", "")).strip_edges()
	if seed != "":
		parts.append("Seed %s" % seed)
	if template_id != "":
		parts.append("Template %s" % template_id)
	if profile_id != "":
		parts.append("Profile %s" % profile_id)
	return " | ".join(parts) if not parts.is_empty() else "Native generated map"

static func _title_from_package_stem(package_stem: String) -> String:
	var stem := package_stem.strip_edges()
	var parts := stem.split("-", false)
	if parts.size() >= 5:
		var name_words := []
		for index in range(1, parts.size() - 1):
			name_words.append(String(parts[index]))
		return _title_from_kebab(" ".join(name_words))
	return _title_from_kebab(stem.replace("-", " "))

static func _title_from_kebab(value: String) -> String:
	var words := []
	for word_value in value.replace("-", " ").split(" ", false):
		var word := String(word_value).strip_edges()
		if word == "":
			continue
		words.append(word.left(1).to_upper() + word.substr(1).to_lower())
	return " ".join(words) if not words.is_empty() else "Generated Map"

static func _use_project_maps_dir() -> bool:
	return OS.has_feature("editor")

static func _generated_map_package_dir() -> String:
	return GENERATED_MAP_DEV_DIR if _use_project_maps_dir() else GENERATED_MAP_RUNTIME_DIR

static func _native_package_setup_failure(code: String, message: String, difficulty_id: String, report: Dictionary = {}) -> Dictionary:
	return {
		"ok": false,
		"setup_kind": "generated_random_map_skirmish",
		"startup_source": "native_rmg_disk_package",
		"launch_mode": SessionStateStoreScript.LAUNCH_MODE_SKIRMISH,
		"difficulty": normalize_difficulty(difficulty_id),
		"validation": report,
		"retry_status": {"status": "failed_before_launch", "attempt_count": 1, "retry_count": 0, "validation_status": "fail"},
		"failure_handoff": "Generated Skirmish blocked: %s" % message,
		"error_code": code,
		"campaign_adoption": false,
		"alpha_parity_claim": false,
	}

static func _persist_and_load_generated_packages(service: Variant, adoption: Dictionary, generated: Dictionary = {}) -> Dictionary:
	var map_document: Variant = adoption.get("map_document", null)
	var scenario_document: Variant = adoption.get("scenario_document", null)
	if map_document == null or scenario_document == null:
		return {"ok": false, "error_code": "missing_native_documents", "message": "Native package adoption did not return map and scenario documents."}
	var map_id := String(adoption.get("map_ref", {}).get("map_id", map_document.get_map_id()))
	var scenario_id := String(adoption.get("scenario_ref", {}).get("scenario_id", scenario_document.get_scenario_id()))
	var package_dir := _generated_map_package_dir()
	var package_identity := _generated_map_package_identity(generated, adoption)
	var package_stem := String(package_identity.get("package_stem", ""))
	if package_stem == "":
		package_stem = _safe_package_stem("%s-%s" % [map_id, scenario_id])
	var map_path := "%s/%s.amap" % [package_dir, package_stem]
	var scenario_path := "%s/%s.ascenario" % [package_dir, package_stem]
	var policy := generated_map_package_directory_policy()
	var save_options := {
		"path_policy": "dev_res_maps_export_user_maps",
		"directory_policy": policy,
	}
	var map_save: Dictionary = service.save_map_package(map_document, map_path, save_options)
	if not bool(map_save.get("ok", false)):
		return map_save
	var map_load: Dictionary = service.load_map_package(map_path)
	if not bool(map_load.get("ok", false)):
		return map_load
	var saved_map_ref: Dictionary = map_load.get("map_ref", {}) if map_load.get("map_ref", {}) is Dictionary else {}
	if scenario_document.has_method("configure") and not saved_map_ref.is_empty():
		scenario_document.configure({
			"scenario_id": scenario_document.get_scenario_id(),
			"scenario_hash": scenario_document.get_scenario_hash(),
			"map_ref": saved_map_ref,
			"selection": scenario_document.get_selection(),
			"player_slots": scenario_document.get_player_slots(),
			"objectives": scenario_document.get_objectives(),
			"script_hooks": scenario_document.get_script_hooks(),
			"enemy_factions": scenario_document.get_enemy_factions(),
			"start_contract": scenario_document.get_start_contract(),
		})
	var scenario_save: Dictionary = service.save_scenario_package(scenario_document, scenario_path, save_options)
	if not bool(scenario_save.get("ok", false)):
		return scenario_save
	var scenario_load: Dictionary = service.load_scenario_package(scenario_path)
	if not bool(scenario_load.get("ok", false)):
		return scenario_load
	var map_ref: Dictionary = map_load.get("map_ref", {}) if map_load.get("map_ref", {}) is Dictionary else {}
	var scenario_ref: Dictionary = scenario_load.get("scenario_ref", {}) if scenario_load.get("scenario_ref", {}) is Dictionary else {}
	var boundary: Dictionary = adoption.get("session_boundary_record", {}) if adoption.get("session_boundary_record", {}) is Dictionary else {}
	boundary["map_package_ref"] = map_ref
	boundary["scenario_package_ref"] = scenario_ref
	boundary["launch_mode"] = SessionStateStoreScript.LAUNCH_MODE_SKIRMISH
	boundary["runtime_call_site_adoption"] = true
	boundary["generated_record_policy"] = "disk_package_loaded_documents_only"
	boundary["content_service_generated_draft"] = false
	boundary["legacy_json_scenario_record"] = false
	boundary["map_package_path"] = map_path
	boundary["scenario_package_path"] = scenario_path
	return {
		"ok": true,
		"schema_id": "aurelion_native_rmg_disk_package_startup_v1",
		"directory_policy": policy,
		"package_stem": package_stem,
		"package_identity": package_identity,
		"map_path": map_path,
		"scenario_path": scenario_path,
		"map_save": _public_package_write_result(map_save),
		"scenario_save": _public_package_write_result(scenario_save),
		"map_load": _public_package_load_result(map_load),
		"scenario_load": _public_package_load_result(scenario_load),
		"map_ref": map_ref,
		"scenario_ref": scenario_ref,
		"session_boundary_record": boundary,
		"storage_policy": "generated_package_saved_loaded_from_maps_dir",
		"legacy_json_scenario_record": false,
	}

static func _public_package_load_result(load_result: Dictionary) -> Dictionary:
	var cleaned := {}
	for key in ["ok", "status", "operation", "path", "package_hash", "storage_policy", "report"]:
		if load_result.has(key):
			cleaned[key] = load_result[key]
	if load_result.has("map_ref"):
		cleaned["map_ref"] = load_result.get("map_ref", {})
	if load_result.has("scenario_ref"):
		cleaned["scenario_ref"] = load_result.get("scenario_ref", {})
	return cleaned

static func _public_package_write_result(write_result: Dictionary) -> Dictionary:
	var cleaned := {}
	for key in ["ok", "status", "operation", "path", "package_hash", "report"]:
		if write_result.has(key):
			cleaned[key] = write_result[key]
	return cleaned

static func _safe_package_stem(value: String) -> String:
	var stem := _safe_package_token(value, "generated-map")
	return stem if stem != "" else "generated_map"

static func _generated_map_package_identity(generated: Dictionary, adoption: Dictionary) -> Dictionary:
	var normalized: Dictionary = generated.get("normalized_config", {}) if generated.get("normalized_config", {}) is Dictionary else {}
	var report: Dictionary = generated.get("report", generated.get("validation_report", {})) if generated.get("report", generated.get("validation_report", {})) is Dictionary else {}
	var metrics: Dictionary = report.get("metrics", {}) if report.get("metrics", {}) is Dictionary else {}
	var map_document: Variant = adoption.get("map_document", null)
	var width := int(normalized.get("width", metrics.get("width", 0)))
	var height := int(normalized.get("height", metrics.get("height", 0)))
	var level_count := int(normalized.get("level_count", metrics.get("level_count", 1)))
	if map_document != null:
		if width <= 0:
			width = int(map_document.get_width())
		if height <= 0:
			height = int(map_document.get_height())
		if level_count <= 0:
			level_count = int(map_document.get_level_count())
	var player_count := int(normalized.get("player_count", metrics.get("player_slot_count", 0)))
	if player_count <= 0:
		var player_assignment: Dictionary = generated.get("player_assignment", {}) if generated.get("player_assignment", {}) is Dictionary else {}
		var player_slots: Array = player_assignment.get("player_slots", []) if player_assignment.get("player_slots", []) is Array else []
		player_count = player_slots.size()
	if player_count <= 0:
		var player_starts: Dictionary = generated.get("player_starts", {}) if generated.get("player_starts", {}) is Dictionary else {}
		player_count = int(player_starts.get("start_count", 0))
	var size_token := _generated_map_package_size_token(String(normalized.get("size_class_id", "map")))
	var creative_name := _generated_map_package_creative_name(normalized, generated)
	var hash_token := _generated_map_package_short_hash(normalized)
	var parts := [
		size_token,
		creative_name,
		hash_token,
	]
	var package_stem := _safe_package_stem("-".join(parts))
	if package_stem.length() > 120:
		package_stem = _safe_package_stem("-".join([size_token, creative_name, hash_token]))
	return {
		"schema_id": "aurelion_native_rmg_package_filename_identity_v1",
		"package_stem": package_stem,
		"creative_name": creative_name,
		"template_id": String(normalized.get("template_id", "")),
		"profile_id": String(normalized.get("profile_id", "")),
		"size_class_id": String(normalized.get("size_class_id", "")),
		"width": width,
		"height": height,
		"level_count": max(1, level_count),
		"player_count": max(1, player_count),
		"water_mode": String(normalized.get("water_mode", "")),
		"normalized_seed": String(normalized.get("normalized_seed", normalized.get("seed", ""))),
		"short_hash": hash_token,
		"filename_style": "size-creative-name-hash-lowercase-kebab-deterministic",
		"detailed_identity_storage": "package_metadata_refs_not_filename",
	}

static func _generated_map_package_size_token(size_class_id: String) -> String:
	var raw := size_class_id.strip_edges().to_lower()
	if raw.begins_with("homm3_"):
		raw = raw.substr("homm3_".length())
	raw = raw.replace("_", "-")
	if raw == "extra-large":
		return raw
	return _safe_package_token(raw, "map")

static func _generated_map_package_creative_name(normalized: Dictionary, generated: Dictionary) -> String:
	var name_key := "|".join([
		str(normalized.get("normalized_seed", normalized.get("seed", ""))),
		str(normalized.get("template_id", "")),
		str(normalized.get("profile_id", "")),
		str(normalized.get("size_class_id", "")),
		str(normalized.get("width", "")),
		str(normalized.get("height", "")),
		str(normalized.get("level_count", "")),
		str(normalized.get("player_count", "")),
		str(normalized.get("water_mode", "")),
		str(normalized.get("underground_enabled", "")),
		str(normalized.get("generator_version", "")),
		str(generated.get("validation_status", "")),
	])
	var first_words := [
		"amber", "ash", "bracken", "cinder", "dawn", "dusk", "ember", "fallow",
		"frost", "glass", "gold", "hollow", "iron", "jade", "mist", "moon",
		"red", "silver", "sun", "thorn", "veil", "wild", "wind", "winter",
	]
	var second_words := [
		"barrow", "brook", "cairn", "field", "ford", "gate", "grove", "hearth",
		"keep", "lantern", "march", "mire", "moor", "pass", "ridge", "road",
		"sanctum", "spire", "stone", "watch", "wood", "yard",
	]
	var third_words := [
		"bend", "crossing", "deep", "fall", "fen", "glade", "hollow", "marsh",
		"meadow", "reach", "rise", "shore", "spring", "trail", "vale", "way",
	]
	var a: String = first_words[_stable_name_index("%s|first" % name_key, first_words.size())]
	var b: String = second_words[_stable_name_index("%s|second" % name_key, second_words.size())]
	var c: String = third_words[_stable_name_index("%s|third" % name_key, third_words.size())]
	return _safe_package_stem("%s-%s-%s" % [a, b, c])

static func _stable_name_index(value: String, modulo: int) -> int:
	if modulo <= 0:
		return 0
	var hash_value := 2166136261
	for index in range(value.length()):
		hash_value = int((hash_value ^ value.unicode_at(index)) * 16777619) & 0x7fffffff
	return hash_value % modulo

static func _generated_map_package_short_hash(normalized: Dictionary) -> String:
	var identity := "|".join([
		str(normalized.get("normalized_seed", normalized.get("seed", ""))),
		str(normalized.get("template_id", "")),
		str(normalized.get("profile_id", "")),
		str(normalized.get("size_class_id", "")),
		str(normalized.get("width", "")),
		str(normalized.get("height", "")),
		str(normalized.get("level_count", "")),
		str(normalized.get("player_count", "")),
		str(normalized.get("water_mode", "")),
		str(normalized.get("underground_enabled", "")),
		str(normalized.get("generator_version", "")),
	])
	return _stable_hash_hex8(identity)

static func _stable_hash_hex8(value: String) -> String:
	var hash_value := 2166136261
	for index in range(value.length()):
		hash_value = int(hash_value ^ value.unicode_at(index))
		hash_value = int((hash_value * 16777619) & 0xffffffff)
	return _hex8(hash_value)

static func _hex8(value: int) -> String:
	var hex_chars := "0123456789abcdef"
	var output := ""
	for shift in [28, 24, 20, 16, 12, 8, 4, 0]:
		output += hex_chars.substr((value >> shift) & 0xf, 1)
	return output

static func _safe_package_token(value: Variant, fallback: String = "generated") -> String:
	var raw := String(value).strip_edges().to_lower()
	var token := ""
	var previous_dash := false
	for index in range(raw.length()):
		var code := raw.unicode_at(index)
		var allowed := (code >= 97 and code <= 122) or (code >= 48 and code <= 57)
		if allowed:
			token += raw.substr(index, 1)
			previous_dash = false
		elif not previous_dash and token != "":
			token += "-"
			previous_dash = true
	while token.begins_with("-"):
		token = token.substr(1)
	while token.ends_with("-"):
		token = token.substr(0, token.length() - 1)
	return token if token != "" else fallback

static func _native_random_map_generated_identity(generated: Dictionary, adoption: Dictionary, persisted: Dictionary) -> Dictionary:
	var normalized: Dictionary = generated.get("normalized_config", {}) if generated.get("normalized_config", {}) is Dictionary else {}
	var identity: Dictionary = generated.get("deterministic_identity", {}) if generated.get("deterministic_identity", {}) is Dictionary else {}
	var scenario_ref: Dictionary = persisted.get("scenario_ref", {}) if persisted.get("scenario_ref", {}) is Dictionary else {}
	var map_ref: Dictionary = persisted.get("map_ref", {}) if persisted.get("map_ref", {}) is Dictionary else {}
	return {
		"scenario_id": String(scenario_ref.get("scenario_id", adoption.get("scenario_ref", {}).get("scenario_id", ""))),
		"map_id": String(map_ref.get("map_id", identity.get("map_id", ""))),
		"map_package_path": String(persisted.get("map_path", "")),
		"scenario_package_path": String(persisted.get("scenario_path", "")),
		"stable_signature": String(identity.get("signature", "")),
		"full_output_signature": String(generated.get("full_output_signature", generated.get("validation_report", {}).get("full_output_signature", ""))),
		"generator_version": String(normalized.get("generator_version", "")),
		"template_id": String(normalized.get("template_id", "")),
		"profile_id": String(normalized.get("profile_id", "")),
		"size_class_id": String(normalized.get("size_class_id", "")),
		"normalized_seed": String(normalized.get("normalized_seed", "")),
		"content_manifest_fingerprint": "native_package_no_authored_scenario_json",
	}

static func _native_random_map_provenance(input_config: Dictionary, generated: Dictionary, adoption: Dictionary, persisted: Dictionary, retry_status: Dictionary) -> Dictionary:
	return {
		"schema_id": "aurelion_native_rmg_disk_package_provenance_v1",
		"input_config": input_config.duplicate(true),
		"normalized_config": generated.get("normalized_config", {}),
		"generated_identity": _native_random_map_generated_identity(generated, adoption, persisted),
		"retry_status": retry_status,
		"map_ref": persisted.get("map_ref", {}),
		"scenario_ref": persisted.get("scenario_ref", {}),
		"directory_policy": persisted.get("directory_policy", {}),
		"boundaries": {
			"authored_content_writeback": false,
			"content_scenarios_json": false,
			"generated_scenario_draft_registry": false,
			"legacy_json_scenario_record": false,
		},
	}

static func _native_random_map_setup_summary(generated: Dictionary, adoption: Dictionary, persisted: Dictionary, report: Dictionary, retry_status: Dictionary, difficulty_id: String) -> String:
	var normalized: Dictionary = generated.get("normalized_config", {}) if generated.get("normalized_config", {}) is Dictionary else {}
	return "\n".join([
		"Generated Skirmish setup",
		"Seed %s | Template %s | Profile %s" % [
			String(normalized.get("normalized_seed", "")),
			String(normalized.get("template_id", "")),
			String(normalized.get("profile_id", "")),
		],
		"Size %dx%d L%d | Difficulty %s" % [
			int(normalized.get("width", 0)),
			int(normalized.get("height", 0)),
			int(normalized.get("level_count", 1)),
			difficulty_label(difficulty_id),
		],
		"Packages: %s | %s" % [String(persisted.get("map_path", "")), String(persisted.get("scenario_path", ""))],
		"Validation %s | Attempts %d | Retries %d" % [
			String(report.get("status", generated.get("validation_status", ""))),
			int(retry_status.get("attempt_count", 1)),
			int(retry_status.get("retry_count", 0)),
		],
		"Boundary: native packages loaded from disk; no content/scenarios.json startup, generated draft registry, campaign adoption, or legacy scenario JSON writeback.",
	])

static func _random_map_template_option(template_id: String) -> Dictionary:
	var options := _random_map_template_options()
	for option in options:
		if String(option.get("id", "")) == template_id:
			return option.duplicate(true)
	for option in options:
		if String(option.get("id", "")) == "border_gate_compact_v1":
			return option.duplicate(true)
	return options[0].duplicate(true) if not options.is_empty() else RANDOM_MAP_PLAYER_TEMPLATE_OPTIONS[0].duplicate(true)

static func _random_map_template_options_with_player_counts() -> Array:
	var options := []
	for raw_option in _random_map_template_options():
		if not (raw_option is Dictionary):
			continue
		var option: Dictionary = raw_option.duplicate(true)
		var player_counts := _random_map_template_player_count_options(String(option.get("id", "")), option)
		option["player_counts"] = player_counts
		option["player_count_min"] = int(player_counts[0]) if not player_counts.is_empty() else int(option.get("player_count", 3))
		option["player_count_max"] = int(player_counts[player_counts.size() - 1]) if not player_counts.is_empty() else int(option.get("player_count", 3))
		options.append(option)
	return options

static func _random_map_all_player_count_options(template_options: Array) -> Array:
	var counts := {}
	for option in template_options:
		if not (option is Dictionary):
			continue
		for count in option.get("player_counts", []):
			counts[str(int(count))] = true
	if counts.is_empty():
		for fallback_count in RANDOM_MAP_FALLBACK_PLAYER_COUNT_OPTIONS:
			counts[str(int(fallback_count))] = true
	return _sorted_int_keys(counts)

static func _random_map_player_count_options_by_template(template_options: Array) -> Dictionary:
	var result := {}
	for option in template_options:
		if not (option is Dictionary):
			continue
		result[String(option.get("id", ""))] = option.get("player_counts", []).duplicate(true)
	return result

static func _random_map_profile_options_by_template(profile_options: Array) -> Dictionary:
	var result := {}
	for option in profile_options:
		if not (option is Dictionary):
			continue
		var template_id := String(option.get("template_id", ""))
		if template_id == "":
			continue
		if not result.has(template_id):
			result[template_id] = []
		result[template_id].append(option.duplicate(true))
	return result

static func _random_map_template_player_count_options(template_id: String, fallback_option: Dictionary = {}) -> Array:
	var fallback_count := int(fallback_option.get("player_count", 3))
	var template := _random_map_catalog_template(template_id)
	if template.is_empty():
		if fallback_count > 0:
			return [fallback_count]
		return RANDOM_MAP_FALLBACK_PLAYER_COUNT_OPTIONS.duplicate(true)
	var players: Dictionary = template.get("players", {}) if template.get("players", {}) is Dictionary else {}
	var total: Dictionary = players.get("total", {}) if players.get("total", {}) is Dictionary else {}
	var min_count := clampi(int(total.get("min", fallback_count)), 2, 8)
	var max_count := clampi(int(total.get("max", fallback_count)), min_count, 8)
	var capacity := _random_map_template_total_start_capacity(template)
	if capacity > 0:
		max_count = min(max_count, capacity)
	if min_count > max_count:
		min_count = max_count
	var counts := []
	for count in range(min_count, max_count + 1):
		counts.append(count)
	if counts.is_empty():
		counts.append(clampi(fallback_count, 2, 8))
	return counts

static func _random_map_normalize_player_count_for_template(template_id: String, player_count: int, fallback_count: int = 3) -> int:
	var fallback_option := _random_map_template_option(template_id)
	if fallback_count > 0:
		fallback_option["player_count"] = fallback_count
	var counts := _random_map_template_player_count_options(template_id, fallback_option)
	if counts.is_empty():
		return clampi(player_count if player_count > 0 else fallback_count, 2, 8)
	var requested := player_count if player_count > 0 else fallback_count
	var first_count := int(counts[0])
	var last_count := int(counts[counts.size() - 1])
	return clampi(requested, first_count, last_count)

static func _random_map_catalog_template(template_id: String) -> Dictionary:
	var catalog := _random_map_catalog()
	for template in catalog.get("templates", []):
		if template is Dictionary and String(template.get("id", "")) == template_id:
			return template.duplicate(true)
	return {}

static func _random_map_catalog() -> Dictionary:
	var catalog: Dictionary = ContentService.load_json(RandomMapGeneratorRulesScript.TEMPLATE_CATALOG_PATH)
	return catalog if catalog is Dictionary else {}

static func _random_map_template_options() -> Array:
	var catalog := _random_map_catalog()
	var profiles_by_template := {}
	for profile in catalog.get("profiles", []):
		if profile is Dictionary:
			profiles_by_template[String(profile.get("template_id", ""))] = profile
	var options := []
	for template_value in catalog.get("templates", []):
		if not (template_value is Dictionary):
			continue
		var template: Dictionary = template_value
		var template_id := String(template.get("id", ""))
		if template_id == "":
			continue
		var profile: Dictionary = profiles_by_template.get(template_id, {}) if profiles_by_template.get(template_id, {}) is Dictionary else {}
		var player_counts := _player_counts_from_catalog_template(template, 3)
		var option := {
			"id": template_id,
			"label": String(template.get("label", template_id)),
			"profile_id": String(profile.get("id", "")),
			"player_count": int(player_counts[min(player_counts.size() - 1, 2)]) if not player_counts.is_empty() else 3,
			"water_modes": _water_modes_from_catalog_template(template),
			"supports_underground": _template_supports_underground(template),
			"catalog_source": "content/random_map_template_catalog.json",
			"family": String(template.get("family", "")),
			"size_score": template.get("size_score", {}),
		}
		options.append(option)
	if not options.is_empty():
		return options
	return RANDOM_MAP_PLAYER_TEMPLATE_OPTIONS.duplicate(true)

static func _random_map_profile_options() -> Array:
	var catalog := _random_map_catalog()
	var options := []
	for profile_value in catalog.get("profiles", []):
		if not (profile_value is Dictionary):
			continue
		var profile: Dictionary = profile_value
		var profile_id := String(profile.get("id", ""))
		if profile_id == "":
			continue
		options.append({
			"id": profile_id,
			"label": String(profile.get("label", profile_id)),
			"template_id": String(profile.get("template_id", "")),
			"guard_strength_profile": String(profile.get("guard_strength_profile", "core_low")),
			"terrain_ids": profile.get("terrain_ids", []),
			"faction_ids": profile.get("faction_ids", []),
			"encounter_id": String(profile.get("encounter_id", "")),
			"catalog_source": "content/random_map_template_catalog.json",
		})
	if not options.is_empty():
		return options
	return RANDOM_MAP_PLAYER_PROFILE_OPTIONS.duplicate(true)

static func _player_counts_from_catalog_template(template: Dictionary, fallback_count: int) -> Array:
	var players: Dictionary = template.get("players", {}) if template.get("players", {}) is Dictionary else {}
	var total: Dictionary = players.get("total", {}) if players.get("total", {}) is Dictionary else {}
	var min_count := clampi(int(total.get("min", fallback_count)), 2, 8)
	var max_count := clampi(int(total.get("max", fallback_count)), min_count, 8)
	var capacity := _random_map_template_total_start_capacity(template)
	if capacity > 0:
		max_count = min(max_count, capacity)
	if min_count > max_count:
		min_count = max_count
	var counts := []
	for count in range(min_count, max_count + 1):
		counts.append(count)
	if counts.is_empty():
		counts.append(clampi(fallback_count, 2, 8))
	return counts

static func _water_modes_from_catalog_template(template: Dictionary) -> Array:
	var result := {}
	var support: Dictionary = template.get("map_support", {}) if template.get("map_support", {}) is Dictionary else {}
	for mode_value in support.get("water_modes", ["land"]):
		var mode := String(mode_value)
		if mode == "land":
			result["land"] = true
		elif mode.contains("islands"):
			result["islands"] = true
	if result.is_empty():
		result["land"] = true
	return _sorted_string_keys(result)

static func _template_supports_underground(template: Dictionary) -> bool:
	var support: Dictionary = template.get("map_support", {}) if template.get("map_support", {}) is Dictionary else {}
	var levels: Dictionary = support.get("levels", {}) if support.get("levels", {}) is Dictionary else {}
	for count in levels.get("supported_counts", []):
		if int(count) >= 2:
			return true
	return false

static func _random_map_template_total_start_capacity(template: Dictionary) -> int:
	var owner_slots := {}
	for zone in template.get("zones", []):
		if not (zone is Dictionary) or zone.get("owner_slot", null) == null:
			continue
		var slot := int(zone.get("owner_slot", 0))
		var role := String(zone.get("role", ""))
		if slot > 0 and (role == "human_start" or role == "computer_start" or role.ends_with("_start")):
			owner_slots[str(slot)] = true
	return owner_slots.size()

static func _sorted_int_keys(values: Dictionary) -> Array:
	var result := []
	for key in values.keys():
		result.append(int(key))
	result.sort()
	return result

static func _sorted_string_keys(values: Dictionary) -> Array:
	var result := []
	for key in values.keys():
		result.append(String(key))
	result.sort()
	return result

static func _random_map_size_option(size_class_id: String) -> Dictionary:
	for option in RANDOM_MAP_SIZE_OPTIONS:
		if String(option.get("id", "")) == size_class_id:
			return option.duplicate(true)
	return RANDOM_MAP_SIZE_OPTIONS[0].duplicate(true)

static func random_map_size_class_label(size_class_id: String) -> String:
	return String(_random_map_size_option(size_class_id).get("label", "Small 36x36"))

static func _random_map_profile_option(profile_id: String) -> Dictionary:
	var options := _random_map_profile_options()
	for option in options:
		if String(option.get("id", "")) == profile_id:
			return option.duplicate(true)
	for option in options:
		if String(option.get("id", "")) == "border_gate_compact_profile_v1":
			return option.duplicate(true)
	return options[0].duplicate(true) if not options.is_empty() else RANDOM_MAP_PLAYER_PROFILE_OPTIONS[0].duplicate(true)

static func _random_map_retry_policy(retry_policy: Dictionary) -> Dictionary:
	var policy := RANDOM_MAP_PLAYER_RETRY_POLICY.duplicate(true)
	for key in retry_policy.keys():
		policy[key] = retry_policy[key]
	policy["max_attempts"] = clampi(int(policy.get("max_attempts", 1)), 1, 5)
	if String(policy.get("mode", "")) == "":
		policy["mode"] = "none"
	return policy

static func _random_map_retry_attempt_config(input_config: Dictionary, attempt_index: int, retry_policy: Dictionary) -> Dictionary:
	var config := input_config.duplicate(true)
	if attempt_index > 0 and retry_policy.get("fallback_config", {}) is Dictionary and not retry_policy.get("fallback_config", {}).is_empty():
		config = retry_policy.get("fallback_config", {}).duplicate(true)
	if attempt_index > 0 and String(retry_policy.get("mode", "")).find("seed_salt") >= 0:
		config["seed"] = "%s:retry_%d" % [String(config.get("seed", "0")), attempt_index]
	return config

static func _random_map_setup_attempt_record(
	setup: Dictionary,
	input_config: Dictionary,
	attempt_number: int,
	max_attempts: int
) -> Dictionary:
	var ok := bool(setup.get("ok", false))
	var validation: Dictionary = setup.get("validation", {}) if setup.get("validation", {}) is Dictionary else {}
	var normalized := RandomMapGeneratorRulesScript.normalize_config(input_config)
	var retryable := not ok and attempt_number < max_attempts
	return {
		"attempt": attempt_number,
		"max_attempts": max_attempts,
		"ok": ok,
		"seed": String(normalized.get("seed", "")),
		"template_id": String(normalized.get("template_id", "")),
		"profile_id": String(normalized.get("profile", {}).get("id", "")),
		"scenario_id": String(setup.get("scenario_id", "")),
		"validation_status": String(validation.get("status", "pass" if ok else "fail")),
		"failure_count": int(validation.get("failure_count", 0)),
		"warning_count": int(validation.get("warning_count", 0)),
		"validation": validation,
		"retry_decision": {
			"will_retry": retryable,
			"reason": "retry_policy_has_remaining_attempt" if retryable else ("accepted_valid_generation" if ok else "attempt_limit_reached"),
			"next_attempt": attempt_number + 1 if retryable else 0,
		},
	}

static func _random_map_retry_status_from_attempts(attempts: Array, ok: bool, retry_policy: Dictionary) -> Dictionary:
	var status := "pass"
	if ok and attempts.size() > 1:
		status = "pass_after_retry"
	elif not ok:
		status = "failed_before_launch"
	var validation_status := "pass" if ok else "fail"
	if not attempts.is_empty():
		validation_status = String(attempts[attempts.size() - 1].get("validation_status", validation_status))
	return {
		"policy": "bounded_player_setup_retry_visible",
		"attempt_count": attempts.size(),
		"retry_count": max(0, attempts.size() - 1),
		"max_attempts": int(retry_policy.get("max_attempts", attempts.size())),
		"mode": String(retry_policy.get("mode", "none")),
		"status": status,
		"validation_status": validation_status,
		"failure_count": int(attempts[attempts.size() - 1].get("failure_count", 0)) if not attempts.is_empty() else 0,
		"warning_count": int(attempts[attempts.size() - 1].get("warning_count", 0)) if not attempts.is_empty() else 0,
	}

static func _random_map_failure_handoff(report: Dictionary, retry_status: Dictionary) -> String:
	return "Generated Skirmish blocked: validation %s after %d attempt(s), retry count %d; no session, save, campaign, or authored content write occurred." % [
		String(report.get("status", "fail")),
		int(retry_status.get("attempt_count", 1)),
		int(retry_status.get("retry_count", 0)),
	]

static func _random_map_failure_setup_summary(report: Dictionary, retry_status: Dictionary, attempts: Array) -> String:
	var lines := [
		"Generated Skirmish setup blocked",
		"Validation %s | Attempts %d/%d | Retries %d" % [
			String(report.get("status", "fail")),
			int(retry_status.get("attempt_count", 0)),
			int(retry_status.get("max_attempts", retry_status.get("attempt_count", 0))),
			int(retry_status.get("retry_count", 0)),
		],
	]
	for failure in report.get("failures", []):
		if lines.size() >= 5:
			break
		lines.append("Failure: %s" % _stringify_report_value(failure))
	if attempts.size() > 0:
		var last_attempt: Dictionary = attempts[attempts.size() - 1] if attempts[attempts.size() - 1] is Dictionary else {}
		var retry_decision: Dictionary = last_attempt.get("retry_decision", {}) if last_attempt.get("retry_decision", {}) is Dictionary else {}
		lines.append("Retry decision: %s." % String(retry_decision.get("reason", "attempt_limit_reached")))
	lines.append("Boundary: no session, save, campaign adoption, authored JSON writeback, or alpha/parity claim.")
	return "\n".join(lines)

static func _stringify_report_value(value: Variant) -> String:
	if value is Dictionary or value is Array:
		return JSON.stringify(value)
	return String(value)

static func _random_map_generated_identity(payload: Dictionary) -> Dictionary:
	var scenario: Dictionary = payload.get("scenario_record", {}) if payload.get("scenario_record", {}) is Dictionary else {}
	var metadata: Dictionary = payload.get("metadata", {}) if payload.get("metadata", {}) is Dictionary else {}
	var profile: Dictionary = metadata.get("profile", {}) if metadata.get("profile", {}) is Dictionary else {}
	var generated_export: Dictionary = payload.get("generated_export", {}) if payload.get("generated_export", {}) is Dictionary else {}
	return {
		"scenario_id": String(scenario.get("id", "")),
		"stable_signature": String(payload.get("stable_signature", "")),
		"materialized_map_signature": String(payload.get("runtime_materialization", {}).get("materialized_map_signature", "")),
		"generated_export_signature": String(generated_export.get("round_trip_signature", "")),
		"tile_stream_signature": String(generated_export.get("tile_stream_signature", "")),
		"object_writeout_signature": String(generated_export.get("object_writeout_signature", "")),
		"generator_version": String(metadata.get("generator_version", "")),
		"template_id": String(metadata.get("template_id", "")),
		"profile_id": String(profile.get("id", "")),
		"size_class_id": String(metadata.get("size_policy", {}).get("size_class_id", "")),
		"size_class_label": String(metadata.get("size_policy", {}).get("size_class_label", "")),
		"source_size": metadata.get("size_policy", {}).get("source_size", {}),
		"materialized_size": metadata.get("size_policy", {}).get("materialized_size", {}),
		"normalized_seed": String(metadata.get("normalized_seed", "")),
		"content_manifest_fingerprint": String(metadata.get("content_manifest_fingerprint", "")),
	}

static func _random_map_provenance(input_config: Dictionary, payload: Dictionary, report: Dictionary, retry_status: Dictionary) -> Dictionary:
	var normalized := RandomMapGeneratorRulesScript.normalize_config(input_config)
	var metadata: Dictionary = payload.get("metadata", {}) if payload.get("metadata", {}) is Dictionary else {}
	var profile: Dictionary = metadata.get("profile", {}) if metadata.get("profile", {}) is Dictionary else {}
	var replay_config := _random_map_replay_generator_config(input_config, normalized, metadata, profile)
	var generated_export: Dictionary = payload.get("generated_export", {}) if payload.get("generated_export", {}) is Dictionary else {}
	var export_contract := {
		"schema_id": String(generated_export.get("schema_id", "")),
		"export_schema_id": String(generated_export.get("export_schema_id", "")),
		"round_trip_signature": String(generated_export.get("round_trip_signature", "")),
		"tile_stream_signature": String(generated_export.get("tile_stream_signature", "")),
		"object_writeout_signature": String(generated_export.get("object_writeout_signature", "")),
		"terrain_tile_count": generated_export.get("final_tile_stream", []).size(),
		"object_writeout_count": generated_export.get("object_writeout_records", []).size(),
		"round_trip_without_staging_metadata": bool(generated_export.get("writeout_completeness", {}).get("round_trip_without_staging_metadata", false)),
	}
	return {
		"schema_id": "generated_random_map_skirmish_provenance_v2",
		"provenance_contract_version": 2,
		"source": "random_map_skirmish_setup",
		"generator_config": replay_config,
		"generator_version": String(metadata.get("generator_version", "")),
		"normalized_seed": String(metadata.get("normalized_seed", "")),
		"template_id": String(metadata.get("template_id", "")),
		"profile_id": String(profile.get("id", "")),
		"player_settings": {
			"player_constraints": metadata.get("player_constraints", {}),
			"player_assignment": metadata.get("player_assignment", {}),
		},
		"size_class": metadata.get("size_policy", {}),
		"content_manifest_fingerprint": String(metadata.get("content_manifest_fingerprint", "")),
		"generated_identity": _random_map_generated_identity(payload),
		"materialization": RandomMapGeneratorRulesScript.runtime_materialization_identity(payload),
		"generated_export": export_contract,
		"validation_status": String(report.get("status", "")),
		"retry_status": retry_status,
		"save_schema_status": "versioned_generated_random_map_provenance_v2_without_save_version_bump_no_global_bump",
		"save_version": int(SessionStateStoreScript.SAVE_VERSION),
		"replay_status": "seed_config_identity_export_stream_and_materialized_map_signature_preserved",
		"write_policy": String(payload.get("write_policy", "")),
		"authored_content_writeback": false,
		"campaign_adoption": false,
		"alpha_parity_claim": false,
	}

static func _random_map_replay_generator_config(input_config: Dictionary, normalized: Dictionary, metadata: Dictionary, profile: Dictionary) -> Dictionary:
	var input_profile: Dictionary = input_config.get("profile", {}) if input_config.get("profile", {}) is Dictionary else {}
	var replay_profile: Dictionary = input_profile.duplicate(true) if not input_profile.is_empty() else profile.duplicate(true)
	var template_id := String(metadata.get("template_id", normalized.get("template_id", "")))
	if String(replay_profile.get("id", "")).strip_edges() == "":
		replay_profile["id"] = String(profile.get("id", ""))
	if String(replay_profile.get("template_id", "")).strip_edges() == "":
		replay_profile["template_id"] = template_id
	if String(replay_profile.get("guard_strength_profile", "")).strip_edges() == "":
		replay_profile["guard_strength_profile"] = String(profile.get("guard_strength_profile", "core_low"))

	var player_assignment: Dictionary = metadata.get("player_assignment", {}) if metadata.get("player_assignment", {}) is Dictionary else {}
	if String(player_assignment.get("assignment_policy", "")) == "fixed_owner_slots_first_n_players_seeded_factions":
		var faction_pool: Array = player_assignment.get("faction_pool", []) if player_assignment.get("faction_pool", []) is Array else []
		if not faction_pool.is_empty():
			replay_profile["faction_ids"] = faction_pool.duplicate(true)
			replay_profile.erase("town_ids")

	return {
		"generator_version": String(normalized.get("generator_version", RandomMapGeneratorRulesScript.GENERATOR_VERSION)),
		"seed": String(normalized.get("seed", "0")),
		"seed_source": String(input_config.get("seed_source", "explicit")),
		"seed_input": String(input_config.get("seed_input", String(input_config.get("seed", "")))),
		"size": normalized.get("size", {}),
		"player_constraints": normalized.get("player_constraints", {}),
		"template_id": template_id,
		"profile": replay_profile,
	}

static func _random_map_replay_metadata(provenance: Dictionary, identity: Dictionary, retry_status: Dictionary) -> Dictionary:
	return {
		"schema_id": "generated_random_map_replay_contract_v2",
		"replay_contract_version": 2,
		"source": "skirmish_random_map_seed_config_export_stream",
		"generator_config": provenance.get("generator_config", {}),
		"generated_identity": identity,
		"materialization": provenance.get("materialization", {}),
		"generated_export": provenance.get("generated_export", {}),
		"retry_status": retry_status,
		"content_manifest_fingerprint": String(provenance.get("content_manifest_fingerprint", "")),
		"replay_boundary": "versioned_seed_config_identity_export_stream_and_materialized_map_signature_contract",
	}

static func _random_map_setup_summary(scenario: Dictionary, metadata: Dictionary, report: Dictionary, retry_status: Dictionary, difficulty_id: String) -> String:
	var map_size: Dictionary = scenario.get("map_size", {}) if scenario.get("map_size", {}) is Dictionary else {}
	var size_policy: Dictionary = metadata.get("size_policy", {}) if metadata.get("size_policy", {}) is Dictionary else {}
	var source_size: Dictionary = size_policy.get("source_size", {}) if size_policy.get("source_size", {}) is Dictionary else {}
	var runtime_policy: Dictionary = size_policy.get("runtime_size_policy", {}) if size_policy.get("runtime_size_policy", {}) is Dictionary else {}
	return "\n".join([
		"Generated Skirmish setup",
		"Seed %s | Template %s | Profile %s" % [
			String(metadata.get("normalized_seed", "")),
			String(metadata.get("template_id", "")),
			String(metadata.get("profile", {}).get("id", "")),
		],
		"Size %s source %dx%d | Runtime %dx%d | Difficulty %s" % [
			String(size_policy.get("size_class_label", "Custom")),
			int(source_size.get("width", map_size.get("width", 0))),
			int(source_size.get("height", map_size.get("height", 0))),
			int(map_size.get("width", 0)),
			int(map_size.get("height", 0)),
			difficulty_label(difficulty_id),
		],
		"Size policy: %s | hidden downscale %s" % [
			String(runtime_policy.get("status", "")),
			"yes" if bool(runtime_policy.get("hidden_downscale", false)) else "no",
		],
		"Validation %s | Attempts %d | Retries %d" % [
			String(report.get("status", "")),
			int(retry_status.get("attempt_count", 1)),
			int(retry_status.get("retry_count", 0)),
		],
		"Boundary: Skirmish session only; no campaign adoption, authored JSON writeback, or alpha/parity claim.",
	])

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

static func _skirmish_difficulty_consequence(difficulty_id: String, recommended_difficulty: String) -> String:
	var difficulty_text := difficulty_summary(difficulty_id)
	var recommendation := "matches the recommended setup for this front"
	if difficulty_id != recommended_difficulty:
		recommendation = "recommended setup is %s" % difficulty_label(recommended_difficulty)
	return "Difficulty consequence: %s uses %s; %s." % [
		difficulty_label(difficulty_id),
		difficulty_text.to_lower(),
		recommendation,
	]

static func describe_skirmish_difficulty_check(difficulty_id: String, recommended_difficulty: String) -> String:
	var normalized_difficulty := normalize_difficulty(difficulty_id)
	var normalized_recommendation := normalize_difficulty(recommended_difficulty)
	var selected_label := difficulty_label(normalized_difficulty)
	var recommended_label := difficulty_label(normalized_recommendation)
	if normalized_difficulty == normalized_recommendation:
		return "Difficulty check: %s matches the recommended front pace; launch keeps the expected opening pressure." % selected_label
	return "Difficulty check: %s differs from recommended %s; review the pressure change before launching." % [
		selected_label,
		recommended_label,
	]

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
