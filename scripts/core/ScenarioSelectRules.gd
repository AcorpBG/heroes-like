class_name ScenarioSelectRules
extends RefCounted

const SessionStateStoreScript = preload("res://scripts/core/SessionStateStore.gd")
const ScenarioFactoryScript = preload("res://scripts/core/ScenarioFactory.gd")
const RandomMapGeneratorRulesScript = preload("res://scripts/core/RandomMapGeneratorRules.gd")
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
	return {
		"templates": template_options,
		"profiles": RANDOM_MAP_PLAYER_PROFILE_OPTIONS.duplicate(true),
		"size_classes": RANDOM_MAP_SIZE_OPTIONS.duplicate(true),
		"player_counts": _random_map_all_player_count_options(template_options),
		"player_count_options_by_template": _random_map_player_count_options_by_template(template_options),
		"water_modes": RANDOM_MAP_WATER_OPTIONS.duplicate(true),
		"retry_policy": RANDOM_MAP_PLAYER_RETRY_POLICY.duplicate(true),
		"default_seed": "aurelion-random-skirmish-10184",
		"default_size_class_id": "homm3_small",
		"default_template_id": "border_gate_compact_v1",
		"default_profile_id": "border_gate_compact_profile_v1",
		"size_class_defaults": RANDOM_MAP_SIZE_CLASS_DEFAULTS.duplicate(true),
		"default_player_count": _random_map_normalize_player_count_for_template("border_gate_compact_v1", 3, 3),
		"default_water_mode": "land",
		"default_underground": false,
	}

static func random_map_player_count_options_for_template(template_id: String) -> Array:
	return _random_map_template_player_count_options(template_id, _random_map_template_option(template_id))

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
	var generator = RandomMapGeneratorRulesScript.new()
	var generated: Dictionary = generator.generate(input_config)
	var report: Dictionary = generated.get("report", {}) if generated.get("report", {}) is Dictionary else {}
	var payload: Dictionary = generated.get("generated_map", {}) if generated.get("generated_map", {}) is Dictionary else {}
	var retry_status := _random_map_retry_status(generated, report)
	if not bool(generated.get("ok", false)) or payload.is_empty():
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

	var scenario: Dictionary = payload.get("scenario_record", {})
	var metadata: Dictionary = payload.get("metadata", {})
	var profile: Dictionary = metadata.get("profile", {}) if metadata.get("profile", {}) is Dictionary else {}
	var identity := _random_map_generated_identity(payload)
	var provenance := _random_map_provenance(input_config, payload, report, retry_status)
	var setup_summary := _random_map_setup_summary(scenario, metadata, report, retry_status, normalized_difficulty)
	return {
		"ok": true,
		"setup_kind": "generated_random_map_skirmish",
		"launch_mode": SessionStateStoreScript.LAUNCH_MODE_SKIRMISH,
		"difficulty": normalized_difficulty,
		"difficulty_label": difficulty_label(normalized_difficulty),
		"generated_map": payload,
		"scenario_id": String(identity.get("scenario_id", "")),
		"scenario_name": String(scenario.get("name", identity.get("scenario_id", ""))),
		"template_id": String(identity.get("template_id", "")),
		"profile_id": String(profile.get("id", "")),
		"normalized_seed": String(identity.get("normalized_seed", "")),
		"content_manifest_fingerprint": String(identity.get("content_manifest_fingerprint", "")),
		"generated_identity": identity,
		"validation": report,
		"retry_status": retry_status,
		"provenance": provenance,
		"replay_metadata": _random_map_replay_metadata(provenance, identity, retry_status),
		"setup_summary": setup_summary,
		"launch_handoff": "Launch handoff: generated Skirmish starts a fresh Day 1 expedition from validated seed/config provenance; campaign progress and authored content stay unchanged.",
		"failure_handoff": "Generation validated for launch; retry metadata is preserved for save/replay inspection.",
		"campaign_adoption": false,
		"alpha_parity_claim": false,
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
	var session := ScenarioFactoryScript.create_generated_skirmish_session(
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
			},
		}
	)
	if session.scenario_id == "":
		return session
	session.flags["generated_random_map_provenance"] = setup.get("provenance", {})
	session.flags["generated_random_map_replay_metadata"] = setup.get("replay_metadata", {})
	session.flags["generated_random_map_validation"] = setup.get("validation", {})
	session.flags["generated_random_map_retry_status"] = setup.get("retry_status", {})
	session.flags["generated_random_map_boundary"]["adoption_path"] = "skirmish_session_only_no_authored_browser_or_campaign"
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

static func _random_map_template_option(template_id: String) -> Dictionary:
	for option in RANDOM_MAP_PLAYER_TEMPLATE_OPTIONS:
		if String(option.get("id", "")) == template_id:
			return option.duplicate(true)
	return RANDOM_MAP_PLAYER_TEMPLATE_OPTIONS[0].duplicate(true)

static func _random_map_template_options_with_player_counts() -> Array:
	var options := []
	for raw_option in RANDOM_MAP_PLAYER_TEMPLATE_OPTIONS:
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
	var catalog: Dictionary = ContentService.load_json(RandomMapGeneratorRulesScript.TEMPLATE_CATALOG_PATH)
	for template in catalog.get("templates", []):
		if template is Dictionary and String(template.get("id", "")) == template_id:
			return template.duplicate(true)
	return {}

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

static func _random_map_size_option(size_class_id: String) -> Dictionary:
	for option in RANDOM_MAP_SIZE_OPTIONS:
		if String(option.get("id", "")) == size_class_id:
			return option.duplicate(true)
	return RANDOM_MAP_SIZE_OPTIONS[0].duplicate(true)

static func random_map_size_class_label(size_class_id: String) -> String:
	return String(_random_map_size_option(size_class_id).get("label", "Small 36x36"))

static func _random_map_profile_option(profile_id: String) -> Dictionary:
	for option in RANDOM_MAP_PLAYER_PROFILE_OPTIONS:
		if String(option.get("id", "")) == profile_id:
			return option.duplicate(true)
	return RANDOM_MAP_PLAYER_PROFILE_OPTIONS[0].duplicate(true)

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
		lines.append("Failure: %s" % String(failure))
	if attempts.size() > 0:
		var last_attempt: Dictionary = attempts[attempts.size() - 1] if attempts[attempts.size() - 1] is Dictionary else {}
		var retry_decision: Dictionary = last_attempt.get("retry_decision", {}) if last_attempt.get("retry_decision", {}) is Dictionary else {}
		lines.append("Retry decision: %s." % String(retry_decision.get("reason", "attempt_limit_reached")))
	lines.append("Boundary: no session, save, campaign adoption, authored JSON writeback, or alpha/parity claim.")
	return "\n".join(lines)

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
