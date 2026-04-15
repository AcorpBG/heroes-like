class_name CampaignRules
extends RefCounted

const SessionStateStore = preload("res://scripts/core/SessionStateStore.gd")
const ScenarioFactory = preload("res://scripts/core/ScenarioFactory.gd")
const ScenarioRules = preload("res://scripts/core/ScenarioRules.gd")
const ScenarioScriptRules = preload("res://scripts/core/ScenarioScriptRules.gd")
const OverworldRules = preload("res://scripts/core/OverworldRules.gd")
const HeroCommandRules = preload("res://scripts/core/HeroCommandRules.gd")
const HeroProgressionRules = preload("res://scripts/core/HeroProgressionRules.gd")
const ArtifactRules = preload("res://scripts/core/ArtifactRules.gd")
const SpellRules = preload("res://scripts/core/SpellRules.gd")

const PROFILE_VERSION := 1
const RESOURCE_KEYS := ["gold", "wood", "ore"]

static func _scenario_select_rules():
	return load("res://scripts/core/ScenarioSelectRules.gd")

static func _describe_session_operational_board(session: SessionStateStore.SessionData) -> String:
	return load("res://scripts/core/ScenarioRules.gd").describe_session_operational_board(session)

static func _normalize_overworld_state(session: SessionStateStore.SessionData) -> void:
	# Validator anchor: OverworldRules.normalize_overworld_state
	load("res://scripts/core/OverworldRules.gd").normalize_overworld_state(session)

static func _evaluate_scenario_session(session: SessionStateStore.SessionData) -> Dictionary:
	return load("res://scripts/core/ScenarioRules.gd").evaluate_session(session)

static func _refresh_fog_of_war(session: SessionStateStore.SessionData) -> void:
	load("res://scripts/core/OverworldRules.gd").refresh_fog_of_war(session)

static func _describe_recent_events(session: SessionStateStore.SessionData, limit: int) -> String:
	return load("res://scripts/core/ScenarioScriptRules.gd").describe_recent_events(session, limit)

static func build_profile() -> Dictionary:
	return {
		"version": PROFILE_VERSION,
		"last_campaign_id": "",
		"last_scenario_id": "",
		"campaign_states": {},
	}

static func normalize_profile(value: Variant) -> Dictionary:
	var profile := build_profile()
	if value is Dictionary:
		profile["version"] = max(int(value.get("version", PROFILE_VERSION)), PROFILE_VERSION)
		profile["last_campaign_id"] = String(value.get("last_campaign_id", ""))
		profile["last_scenario_id"] = String(value.get("last_scenario_id", ""))

		var states = value.get("campaign_states", {})
		if states is Dictionary:
			for campaign_id in states.keys():
				profile["campaign_states"][String(campaign_id)] = _normalize_campaign_state(states[campaign_id])

	for campaign in _campaign_items():
		if not (campaign is Dictionary):
			continue
		var campaign_id := String(campaign.get("id", ""))
		if campaign_id == "":
			continue
		if not profile["campaign_states"].has(campaign_id):
			profile["campaign_states"][campaign_id] = _normalize_campaign_state({})

	if String(profile.get("last_campaign_id", "")) == "":
		profile["last_campaign_id"] = get_default_campaign_id()
	return profile

static func get_default_campaign_id() -> String:
	for campaign in _campaign_items():
		if campaign is Dictionary:
			var campaign_id := String(campaign.get("id", ""))
			if campaign_id != "":
				return campaign_id
	return ""

static func campaign_ids() -> Array:
	var ids := []
	for campaign in _campaign_items():
		if not (campaign is Dictionary):
			continue
		var campaign_id := String(campaign.get("id", ""))
		if campaign_id != "":
			ids.append(campaign_id)
	return ids

static func selected_campaign_id(profile: Dictionary) -> String:
	var normalized := normalize_profile(profile)
	var campaign_id := String(normalized.get("last_campaign_id", ""))
	if campaign_id != "" and not ContentService.get_campaign(campaign_id).is_empty():
		return campaign_id
	return get_default_campaign_id()

static func get_campaign_id_for_scenario(scenario_id: String) -> String:
	if scenario_id == "":
		return ""
	for campaign in _campaign_items():
		if not (campaign is Dictionary):
			continue
		for scenario_entry in campaign.get("scenarios", []):
			if scenario_entry is Dictionary and String(scenario_entry.get("scenario_id", "")) == scenario_id:
				return String(campaign.get("id", ""))
	return ""

static func get_campaign_state(profile: Dictionary, campaign_id: String) -> Dictionary:
	var normalized := normalize_profile(profile)
	return normalized.get("campaign_states", {}).get(campaign_id, _normalize_campaign_state({}))

static func mark_selected_campaign(profile: Dictionary, campaign_id: String) -> Dictionary:
	var normalized := normalize_profile(profile)
	if campaign_id == "" or ContentService.get_campaign(campaign_id).is_empty():
		return normalized

	var state := get_campaign_state(normalized, campaign_id).duplicate(true)
	var state_selected_scenario_id := String(state.get("last_selected_scenario_id", ""))
	if state_selected_scenario_id == "" or _find_scenario_entry(ContentService.get_campaign(campaign_id), state_selected_scenario_id).is_empty():
		state["last_selected_scenario_id"] = selected_scenario_id(profile, campaign_id)
	normalized["campaign_states"][campaign_id] = _normalize_campaign_state(state)
	normalized["last_campaign_id"] = campaign_id
	return normalized

static func get_scenario_record(profile: Dictionary, campaign_id: String, scenario_id: String) -> Dictionary:
	var state := get_campaign_state(profile, campaign_id)
	return state.get("scenario_records", {}).get(scenario_id, {})

static func selected_scenario_id(profile: Dictionary, campaign_id: String) -> String:
	var normalized := normalize_profile(profile)
	var campaign := ContentService.get_campaign(campaign_id)
	if campaign.is_empty():
		return ""
	var state := get_campaign_state(normalized, campaign_id)
	var selected_scenario_id := String(state.get("last_selected_scenario_id", ""))
	if selected_scenario_id != "" and not _find_scenario_entry(campaign, selected_scenario_id).is_empty():
		return selected_scenario_id
	if _campaign_is_completed(normalized, campaign_id):
		var final_entry := _final_scenario_entry(campaign)
		var final_scenario_id := String(final_entry.get("scenario_id", ""))
		if final_scenario_id != "":
			return final_scenario_id
	var next_scenario_id := first_available_scenario(normalized, campaign_id)
	if next_scenario_id != "":
		return next_scenario_id
	return String(campaign.get("starting_scenario_id", ""))

static func build_campaign_browser_entries(profile: Dictionary) -> Array:
	var normalized := normalize_profile(profile)
	var selected_campaign := selected_campaign_id(normalized)
	var entries := []
	for campaign_id in campaign_ids():
		var campaign := ContentService.get_campaign(campaign_id)
		if campaign.is_empty():
			continue
		var progress := _campaign_progress(normalized, campaign_id)
		var chapter_count := int((campaign.get("scenarios", []) if campaign.get("scenarios", []) is Array else []).size())
		var next_scenario_id := first_available_scenario(normalized, campaign_id)
		var next_entry := _find_scenario_entry(campaign, next_scenario_id)
		var next_label := _scenario_label(next_entry, next_scenario_id) if not next_entry.is_empty() else "No unlocked chapter"
		var arc_line := _campaign_browser_arc_line(normalized, campaign_id, campaign, progress, next_entry, next_label)
		entries.append(
			{
				"campaign_id": campaign_id,
				"label": "%s | %s" % [String(campaign.get("name", campaign_id)), _campaign_status_label(progress)],
				"summary": "%s\nRegion: %s | Chapters %d | Victories %d\n%s" % [
					String(campaign.get("summary", campaign.get("description", ""))),
					String(campaign.get("region", "Unknown Front")),
					max(1, chapter_count),
					int(progress.get("victories", 0)),
					arc_line,
				],
				"selected": campaign_id == selected_campaign,
			}
		)
	return entries

static func build_campaign_chapter_entries(profile: Dictionary, campaign_id: String) -> Array:
	var normalized := normalize_profile(profile)
	var campaign := ContentService.get_campaign(campaign_id)
	if campaign.is_empty():
		return []

	var selected_scenario := selected_scenario_id(normalized, campaign_id)
	var entries := []
	for scenario_entry in campaign.get("scenarios", []):
		if not (scenario_entry is Dictionary):
			continue
		var scenario_id := String(scenario_entry.get("scenario_id", ""))
		if scenario_id == "":
			continue
		var unlocked := is_scenario_unlocked(normalized, campaign_id, scenario_id)
		var record := get_scenario_record(normalized, campaign_id, scenario_id)
		entries.append(
			{
				"scenario_id": scenario_id,
				"label": "%s | %s" % [_chapter_heading(scenario_entry, scenario_id), _scenario_status_label(unlocked, record)],
				"summary": _menu_action_summary(normalized, campaign_id, scenario_entry, unlocked, record),
				"selected": scenario_id == selected_scenario,
				"disabled": not unlocked,
			}
		)
	return entries

static func build_menu_actions(profile: Dictionary, campaign_id: String) -> Array:
	var normalized := normalize_profile(profile)
	var campaign := ContentService.get_campaign(campaign_id)
	if campaign.is_empty():
		return []

	var actions := []
	for scenario_entry in campaign.get("scenarios", []):
		if not (scenario_entry is Dictionary):
			continue
		var scenario_id := String(scenario_entry.get("scenario_id", ""))
		if scenario_id == "":
			continue
		var unlocked := is_scenario_unlocked(normalized, campaign_id, scenario_id)
		var record := get_scenario_record(normalized, campaign_id, scenario_id)
		var status_label := "Locked"
		if unlocked:
			status_label = "Open"
			var status := String(record.get("status", ""))
			if status == "victory":
				status_label = "Victory"
			elif status == "defeat":
				status_label = "Retry"

		var label := "%s | %s" % [_scenario_label(scenario_entry, scenario_id), status_label]
		var summary := _menu_action_summary(normalized, campaign_id, scenario_entry, unlocked, record)
		actions.append(
			{
				"id": "start_campaign:%s" % scenario_id,
				"label": label,
				"summary": summary,
				"disabled": not unlocked,
				"scenario_id": scenario_id,
			}
		)
	return actions

static func describe_campaign_details(profile: Dictionary, campaign_id: String) -> String:
	var normalized := normalize_profile(profile)
	var campaign := ContentService.get_campaign(campaign_id)
	if campaign.is_empty():
		return "No campaign data."

	var progress := _campaign_progress(normalized, campaign_id)
	var next_scenario_id := first_available_scenario(normalized, campaign_id)
	var next_entry := _find_scenario_entry(campaign, next_scenario_id)
	var lines := [
		"%s | %s" % [String(campaign.get("name", campaign_id)), String(campaign.get("region", "Unknown Front"))],
		String(campaign.get("summary", campaign.get("description", ""))),
		String(campaign.get("description", "")),
		"Progress %d/%d victories | %s" % [
			int(progress.get("victories", 0)),
			max(1, int(progress.get("total_chapters", 0))),
			_campaign_status_label(progress),
		],
	]
	if _campaign_is_completed(normalized, campaign_id):
		var final_entry := _final_scenario_entry(campaign)
		var final_scenario_id := String(final_entry.get("scenario_id", ""))
		if final_scenario_id != "":
			lines.append("Campaign finale secured: %s." % _chapter_heading(final_entry, final_scenario_id))
		lines.append("Completion: %s" % _campaign_completion_title(campaign))
	elif not next_entry.is_empty():
		lines.append("Next chapter: %s" % _chapter_heading(next_entry, next_scenario_id))
	var latest_record := _latest_campaign_record(normalized, campaign_id)
	if not latest_record.is_empty():
		lines.append("Latest result: %s" % String(latest_record.get("summary", "")))
	var latest_journal := _latest_journal_line(normalized, campaign_id)
	if latest_journal != "":
		lines.append("Latest chronicle: %s" % latest_journal)
	var carryover_summary := describe_carryover_bundle(_carryover_bundle_for_node(normalized, campaign_id, next_entry))
	if not _campaign_is_completed(normalized, campaign_id) and carryover_summary != "":
		lines.append("Carryover ready: %s" % carryover_summary)
	return "\n".join(lines)

static func describe_campaign_arc_status(profile: Dictionary, campaign_id: String) -> String:
	return "\n".join(_campaign_arc_status_lines(normalize_profile(profile), campaign_id))

static func describe_campaign_chapter(profile: Dictionary, campaign_id: String, scenario_id: String) -> String:
	var normalized := normalize_profile(profile)
	var campaign := ContentService.get_campaign(campaign_id)
	var scenario_entry := _find_scenario_entry(campaign, scenario_id)
	if campaign.is_empty() or scenario_entry.is_empty():
		return "No chapter data."

	var record := get_scenario_record(normalized, campaign_id, scenario_id)
	var unlocked := is_scenario_unlocked(normalized, campaign_id, scenario_id)
	var lines := [
		"%s | %s" % [_chapter_heading(scenario_entry, scenario_id), _scenario_status_label(unlocked, record)],
		String(scenario_entry.get("description", "")),
	]
	lines.append_array(_chapter_briefing_lines(normalized, campaign_id, scenario_entry, record, unlocked))
	var status_hint := String(scenario_entry.get("status_hint", ""))
	if status_hint != "":
		lines.append(status_hint)
	if unlocked and not record.is_empty():
		lines.append("Attempts %d | Last result %s | Day %d" % [
			max(1, int(record.get("attempts", 1))),
			String(record.get("summary", record.get("status", "resolved"))),
			int(record.get("day", 0)),
		])
	elif not unlocked:
		var unlock_text := _unlock_requirement_text(scenario_entry.get("unlock_requirements", []))
		if unlock_text != "":
			lines.append(unlock_text)

	var carryover_summary := String(scenario_entry.get("carryover_summary", ""))
	if carryover_summary != "":
		lines.append(carryover_summary)
	var import_bundle_summary := describe_carryover_bundle(_carryover_bundle_for_node(normalized, campaign_id, scenario_entry))
	if import_bundle_summary != "":
		lines.append("Imported carryover: %s" % import_bundle_summary)
	var action := build_chapter_action(normalized, campaign_id, scenario_id)
	if String(action.get("summary", "")) != "":
		lines.append(String(action.get("summary", "")))
	return "\n".join(lines)

static func describe_campaign_journal(profile: Dictionary, campaign_id: String) -> String:
	return "\n".join(_campaign_journal_lines(normalize_profile(profile), campaign_id))

static func describe_campaign_commander_preview(profile: Dictionary, campaign_id: String, scenario_id: String) -> String:
	var normalized := normalize_profile(profile)
	var campaign := ContentService.get_campaign(campaign_id)
	var scenario_entry := _find_scenario_entry(campaign, scenario_id)
	if campaign.is_empty() or scenario_entry.is_empty():
		return "Commander preview unavailable."
	var session := build_session(
		normalized,
		scenario_id,
		_scenario_select_rules().default_difficulty_id(),
		campaign_id
	)
	if session.scenario_id == "":
		return "Commander preview unavailable."
	var lines := [_scenario_select_rules().describe_session_commander_preview(session)]
	var import_bundle_summary := describe_carryover_bundle(_carryover_bundle_for_node(normalized, campaign_id, scenario_entry))
	if import_bundle_summary != "":
		lines.append("Carryover import: %s" % import_bundle_summary)
	return "\n".join(lines)

static func describe_campaign_operational_board(profile: Dictionary, campaign_id: String, scenario_id: String) -> String:
	var normalized := normalize_profile(profile)
	var campaign := ContentService.get_campaign(campaign_id)
	var scenario_entry := _find_scenario_entry(campaign, scenario_id)
	if campaign.is_empty() or scenario_entry.is_empty():
		return "Operational board unavailable."
	var session := build_session(
		normalized,
		scenario_id,
		_scenario_select_rules().default_difficulty_id(),
		campaign_id
	)
	if session.scenario_id == "":
		return "Operational board unavailable."
	return _describe_session_operational_board(session)

static func build_chapter_action(profile: Dictionary, campaign_id: String, scenario_id: String) -> Dictionary:
	var normalized := normalize_profile(profile)
	var campaign := ContentService.get_campaign(campaign_id)
	var scenario_entry := _find_scenario_entry(campaign, scenario_id)
	if campaign.is_empty() or scenario_entry.is_empty():
		return {
			"label": "No Chapter Available",
			"summary": "No authored chapter is available.",
			"disabled": true,
			"scenario_id": "",
			"campaign_id": campaign_id,
		}

	var record := get_scenario_record(normalized, campaign_id, scenario_id)
	var unlocked := is_scenario_unlocked(normalized, campaign_id, scenario_id)
	if not unlocked:
		return {
			"label": "Locked Chapter",
			"summary": _menu_action_summary(normalized, campaign_id, scenario_entry, false, record),
			"disabled": true,
			"scenario_id": scenario_id,
			"campaign_id": campaign_id,
		}

	var label_prefix := "Start"
	match String(record.get("status", "")):
		"victory":
			label_prefix = "Replay"
		"defeat":
			label_prefix = "Retry"
	return {
		"label": "%s %s" % [label_prefix, _chapter_heading(scenario_entry, scenario_id)],
		"summary": _menu_action_summary(normalized, campaign_id, scenario_entry, true, record),
		"disabled": false,
		"scenario_id": scenario_id,
		"campaign_id": campaign_id,
	}

static func describe_campaign(profile: Dictionary, campaign_id: String) -> String:
	return describe_campaign_details(profile, campaign_id)

static func build_start_action(profile: Dictionary, campaign_id: String) -> Dictionary:
	var normalized := normalize_profile(profile)
	var campaign := ContentService.get_campaign(campaign_id)
	if campaign.is_empty():
		return {
			"label": "No Campaign Available",
			"summary": "No authored campaign is available to start.",
			"disabled": true,
			"scenario_id": "",
		}

	if _campaign_is_completed(normalized, campaign_id):
		var final_entry := _final_scenario_entry(campaign)
		var final_scenario_id := String(final_entry.get("scenario_id", ""))
		if final_scenario_id != "":
			return build_chapter_action(normalized, campaign_id, final_scenario_id)

	var scenario_id := first_available_scenario(normalized, campaign_id)
	if scenario_id == "":
		return {
			"label": "No Chapter Available",
			"summary": "No unlocked chapter is available to start.",
			"disabled": true,
			"scenario_id": "",
		}

	return build_chapter_action(normalized, campaign_id, scenario_id)

static func campaign_id_for_session(session: SessionStateStore.SessionData) -> String:
	return _campaign_id_for_session(session)

static func campaign_id_for_session_bridge(session) -> String:
	return campaign_id_for_session(session)

static func build_outcome_recap(profile: Dictionary, session: SessionStateStore.SessionData) -> Dictionary:
	var normalized := normalize_profile(profile)
	var campaign_id := campaign_id_for_session(session)
	if session == null or session.scenario_id == "" or campaign_id == "":
		return {
			"campaign_id": "",
			"campaign_name": "",
			"progression_summary": "",
			"campaign_arc_summary": "",
			"carryover_summary": "",
		}

	var campaign := ContentService.get_campaign(campaign_id)
	var current_entry := _find_scenario_entry(campaign, session.scenario_id)
	var current_record := get_scenario_record(normalized, campaign_id, session.scenario_id)
	var progress := _campaign_progress(normalized, campaign_id)
	var next_entry := _next_scenario_entry(campaign, session.scenario_id)
	var next_scenario_id := String(next_entry.get("scenario_id", ""))
	var next_unlocked := next_scenario_id != "" and is_scenario_unlocked(normalized, campaign_id, next_scenario_id)
	var imported_bundle := _carryover_bundle_for_node(normalized, campaign_id, current_entry)
	var exported_bundle := _outcome_export_bundle(normalized, campaign_id, session.scenario_id)

	var progression_lines := [
		"%s | %s" % [String(campaign.get("name", campaign_id)), _campaign_status_label(progress)],
		"%s resolved as %s on Day %d." % [
			_chapter_heading(current_entry, session.scenario_id),
			String(session.scenario_status).capitalize(),
			session.day,
		],
		"Campaign progress %d/%d victories." % [
			int(progress.get("victories", 0)),
			max(1, int(progress.get("total_chapters", 0))),
		],
	]
	if not current_record.is_empty():
		progression_lines.append("Chapter record: %s | Attempts %d | Hero level %d." % [
			String(current_record.get("summary", session.scenario_summary)),
			max(1, int(current_record.get("attempts", 1))),
			max(1, int(current_record.get("hero_level", 1))),
		])
	if next_entry.is_empty():
		progression_lines.append(
			"The authored campaign path concludes here."
			if session.scenario_status == "victory"
			else "No downstream chapter is available until this chapter is won."
		)
	else:
		var next_heading := _chapter_heading(next_entry, next_scenario_id)
		if session.scenario_status == "victory" and next_unlocked:
			progression_lines.append("Next chapter unlocked: %s." % next_heading)
		elif session.scenario_status == "victory":
			progression_lines.append("Next chapter remains blocked: %s." % next_heading)
			var blocked_text := _unlock_requirement_text(next_entry.get("unlock_requirements", []))
			if blocked_text != "":
				progression_lines.append(blocked_text)
		else:
			progression_lines.append("Downstream chapter remains blocked until %s is won." % _chapter_heading(current_entry, session.scenario_id))

	var carryover_lines := []
	var imported_summary := describe_carryover_bundle(imported_bundle)
	if imported_summary != "":
		carryover_lines.append("This chapter imported: %s." % imported_summary)
	if session.scenario_status == "victory":
		var exported_summary := describe_carryover_bundle(exported_bundle)
		if exported_summary != "":
			carryover_lines.append("This victory exports: %s." % exported_summary)
			if next_scenario_id != "":
				var next_import = next_entry.get("carryover_import", {})
				if next_import is Dictionary and String(next_import.get("from_scenario_id", "")) == session.scenario_id:
					carryover_lines.append("Next chapter import ready: %s." % exported_summary)
		else:
			carryover_lines.append("No carryover export is authored for this chapter.")
	else:
		carryover_lines.append("Carryover export is only banked on victory.")
		if imported_summary != "":
			carryover_lines.append("Imported assets are not advanced until the chapter is won.")

	var aftermath_lines := []
	var aftermath_text := _chapter_aftermath_text(current_entry, session.scenario_id, session.scenario_status)
	if aftermath_text != "":
		aftermath_lines.append(aftermath_text)
	var recent_events: String = _describe_recent_events(session, 3)
	if recent_events != "":
		aftermath_lines.append("Operational aftermath: %s." % recent_events)

	var journal_lines := _campaign_journal_lines(normalized, campaign_id)

	return {
		"campaign_id": campaign_id,
		"campaign_name": String(campaign.get("name", campaign_id)),
		"progression_summary": "\n".join(progression_lines),
		"campaign_arc_summary": "\n".join(_campaign_arc_outcome_lines(normalized, campaign_id, session)),
		"carryover_summary": "\n".join(carryover_lines),
		"aftermath_summary": "\n".join(aftermath_lines),
		"journal_summary": "\n".join(journal_lines),
	}

static func build_outcome_recap_bridge(profile: Dictionary, session) -> Dictionary:
	return build_outcome_recap(profile, session)

static func build_outcome_actions(profile: Dictionary, session: SessionStateStore.SessionData) -> Array:
	var normalized := normalize_profile(profile)
	var campaign_id := campaign_id_for_session(session)
	if session == null or session.scenario_id == "" or campaign_id == "":
		return []

	var campaign := ContentService.get_campaign(campaign_id)
	var current_entry := _find_scenario_entry(campaign, session.scenario_id)
	var current_record := get_scenario_record(normalized, campaign_id, session.scenario_id)
	var current_heading := _chapter_heading(current_entry, session.scenario_id)
	var actions := []
	if session.scenario_status == "victory":
		var progress := _campaign_progress(normalized, campaign_id)
		var next_entry := _next_scenario_entry(campaign, session.scenario_id)
		var next_scenario_id := String(next_entry.get("scenario_id", ""))
		if next_scenario_id != "" and is_scenario_unlocked(normalized, campaign_id, next_scenario_id):
			var next_record := get_scenario_record(normalized, campaign_id, next_scenario_id)
			actions.append(
				{
					"id": "campaign_start:%s" % next_scenario_id,
					"label": "Start %s" % _chapter_heading(next_entry, next_scenario_id),
					"summary": _menu_action_summary(normalized, campaign_id, next_entry, true, next_record),
					"disabled": false,
				}
			)
		elif int(progress.get("victories", 0)) >= int(progress.get("total_chapters", 0)):
			actions.append(
				{
					"id": "",
					"label": "Campaign Complete | %s" % _campaign_completion_title(campaign),
					"summary": _campaign_completion_summary(campaign),
					"disabled": true,
				}
			)
		else:
			actions.append(
				{
					"id": "",
					"label": "Next Chapter Blocked",
					"summary": _menu_action_summary(normalized, campaign_id, next_entry, false, {}),
					"disabled": true,
				}
			)
		actions.append(
			{
				"id": "campaign_start:%s" % session.scenario_id,
				"label": "Replay %s" % current_heading,
				"summary": _menu_action_summary(normalized, campaign_id, current_entry, true, current_record),
				"disabled": false,
			}
		)
	else:
		actions.append(
			{
				"id": "campaign_start:%s" % session.scenario_id,
				"label": "Retry %s" % current_heading,
				"summary": _menu_action_summary(normalized, campaign_id, current_entry, true, current_record),
				"disabled": false,
			}
		)
	actions.append(
		{
			"id": "return_to_menu",
			"label": "Return to Menu",
			"summary": "Return to the campaign browser and expedition saves.",
			"disabled": false,
		}
	)
	return actions

static func build_outcome_actions_bridge(profile: Dictionary, session) -> Array:
	return build_outcome_actions(profile, session)

static func first_available_scenario(profile: Dictionary, campaign_id: String) -> String:
	var normalized := normalize_profile(profile)
	var campaign := ContentService.get_campaign(campaign_id)
	if campaign.is_empty():
		return ""

	var starting_scenario_id := String(campaign.get("starting_scenario_id", ""))
	var first_unlocked := ""
	var starting_unlocked := ""
	for scenario_entry in campaign.get("scenarios", []):
		if not (scenario_entry is Dictionary):
			continue
		var scenario_id := String(scenario_entry.get("scenario_id", ""))
		if scenario_id == "":
			continue
		if not is_scenario_unlocked(normalized, campaign_id, scenario_id):
			continue
		if first_unlocked == "":
			first_unlocked = scenario_id
		if scenario_id == starting_scenario_id:
			starting_unlocked = scenario_id
		var record := get_scenario_record(normalized, campaign_id, scenario_id)
		if String(record.get("status", "")) != "victory":
			return scenario_id
	return starting_unlocked if starting_unlocked != "" else first_unlocked

static func is_scenario_unlocked(profile: Dictionary, campaign_id: String, scenario_id: String) -> bool:
	var normalized := normalize_profile(profile)
	var campaign := ContentService.get_campaign(campaign_id)
	if campaign.is_empty():
		return false
	var scenario_entry := _find_scenario_entry(campaign, scenario_id)
	if scenario_entry.is_empty():
		return false
	if bool(scenario_entry.get("starts_unlocked", false)):
		return true

	var record := get_scenario_record(normalized, campaign_id, scenario_id)
	if not record.is_empty():
		return true

	return _requirements_met(normalized, campaign_id, scenario_entry.get("unlock_requirements", []))

static func build_session(profile: Dictionary, scenario_id: String, difficulty: String = "normal", campaign_id: String = "") -> SessionStateStore.SessionData:
	var normalized := normalize_profile(profile)
	var session := ScenarioFactory.create_session(
		scenario_id,
		difficulty,
		SessionStateStore.LAUNCH_MODE_CAMPAIGN
	)
	if session.scenario_id == "":
		return session

	var resolved_campaign_id := campaign_id if campaign_id != "" else get_campaign_id_for_scenario(scenario_id)
	if resolved_campaign_id != "":
		var campaign := ContentService.get_campaign(resolved_campaign_id)
		var scenario_entry := _find_scenario_entry(campaign, scenario_id)
		_apply_carryover(session, _carryover_bundle_for_node(normalized, resolved_campaign_id, scenario_entry), scenario_entry)
		session.flags["campaign_id"] = resolved_campaign_id
		session.flags["campaign_name"] = String(campaign.get("name", resolved_campaign_id))
		session.flags["campaign_chapter_label"] = String(scenario_entry.get("label", _scenario_label(scenario_entry, scenario_id)))
		_normalize_overworld_state(session)
		var scenario_result: Dictionary = _evaluate_scenario_session(session)
		var scenario_message := String(scenario_result.get("message", ""))
		if session.scenario_status == "in_progress" and scenario_message != "":
			session.flags["return_notice"] = scenario_message
	return session

static func build_session_bridge(profile: Dictionary, scenario_id: String, difficulty: String = "normal", campaign_id: String = ""):
	return build_session(profile, scenario_id, difficulty, campaign_id)

static func record_session_completion(profile: Dictionary, session: SessionStateStore.SessionData) -> Dictionary:
	var normalized := normalize_profile(profile)
	if session == null or session.scenario_id == "":
		return normalized

	var campaign_id := _campaign_id_for_session(session)
	if campaign_id == "":
		return normalized

	var state := get_campaign_state(normalized, campaign_id).duplicate(true)
	var campaign := ContentService.get_campaign(campaign_id)
	var scenario_entry := _find_scenario_entry(campaign, session.scenario_id)
	var scenario_records = state.get("scenario_records", {})
	var existing_record: Dictionary = scenario_records.get(session.scenario_id, {})
	var captured_flags := _capture_exported_flags(session, scenario_entry.get("carryover_export", {}))
	var hero: Dictionary = HeroCommandRules.primary_hero(session)

	var record := {
		"status": session.scenario_status,
		"summary": session.scenario_summary,
		"day": session.day,
		"attempts": max(0, int(existing_record.get("attempts", 0))) + 1,
		"hero_level": int(hero.get("level", 1)),
		"known_spell_ids": _normalize_string_array(hero.get("spellbook", {}).get("known_spell_ids", [])),
		"artifact_ids": _artifact_ids_from_hero(hero),
		"specialties": _normalize_string_array(hero.get("specialties", [])),
		"exported_flags": captured_flags,
	}
	scenario_records[session.scenario_id] = record
	state["scenario_records"] = scenario_records
	state["last_completed_scenario_id"] = session.scenario_id

	if session.scenario_status == "victory":
		var carryover_bundles = state.get("carryover_bundles", {})
		carryover_bundles[session.scenario_id] = _build_carryover_bundle(session, scenario_entry.get("carryover_export", {}), captured_flags)
		state["carryover_bundles"] = carryover_bundles

	normalized["campaign_states"][campaign_id] = _normalize_campaign_state(state)
	normalized["last_campaign_id"] = campaign_id
	normalized["last_scenario_id"] = session.scenario_id
	return normalized

static func record_session_completion_bridge(profile: Dictionary, session) -> Dictionary:
	return record_session_completion(profile, session)

static func mark_selected_scenario(profile: Dictionary, scenario_id: String, campaign_id: String = "") -> Dictionary:
	var normalized := normalize_profile(profile)
	var resolved_campaign_id := campaign_id if campaign_id != "" else get_campaign_id_for_scenario(scenario_id)
	if resolved_campaign_id == "":
		return normalized

	var state := get_campaign_state(normalized, resolved_campaign_id).duplicate(true)
	state["last_selected_scenario_id"] = scenario_id
	normalized["campaign_states"][resolved_campaign_id] = _normalize_campaign_state(state)
	normalized["last_campaign_id"] = resolved_campaign_id
	normalized["last_scenario_id"] = scenario_id
	return normalized

static func describe_carryover_bundle(bundle: Dictionary) -> String:
	if bundle.is_empty():
		return ""
	var parts := []
	var hero_progression = bundle.get("hero_progression", {})
	if hero_progression is Dictionary and not hero_progression.is_empty():
		parts.append("Lv %d" % int(hero_progression.get("level", 1)))

	var spell_ids = bundle.get("spell_ids", [])
	if spell_ids is Array and not spell_ids.is_empty():
		parts.append("%d spells" % spell_ids.size())

	var specialties := HeroProgressionRules.brief_summary(bundle.get("hero_progression", {}))
	if specialties != "" and specialties != "No specialties chosen yet":
		parts.append(specialties)

	var artifact_count := _artifact_count(bundle.get("artifacts", {}))
	if artifact_count > 0:
		parts.append("%d relics" % artifact_count)

	var resources := _describe_resources(bundle.get("resources", {}))
	if resources != "":
		parts.append(resources)
	return " | ".join(parts)

static func _normalize_campaign_state(value: Variant) -> Dictionary:
	var state := {
		"scenario_records": {},
		"carryover_bundles": {},
		"last_selected_scenario_id": "",
		"last_completed_scenario_id": "",
	}
	if not (value is Dictionary):
		return state

	state["last_selected_scenario_id"] = String(value.get("last_selected_scenario_id", ""))
	state["last_completed_scenario_id"] = String(value.get("last_completed_scenario_id", ""))

	var scenario_records = value.get("scenario_records", {})
	if scenario_records is Dictionary:
		for scenario_id in scenario_records.keys():
			state["scenario_records"][String(scenario_id)] = _normalize_scenario_record(scenario_records[scenario_id])

	var carryover_bundles = value.get("carryover_bundles", {})
	if carryover_bundles is Dictionary:
		for scenario_id in carryover_bundles.keys():
			state["carryover_bundles"][String(scenario_id)] = _normalize_carryover_bundle(carryover_bundles[scenario_id])
	return state

static func _normalize_scenario_record(value: Variant) -> Dictionary:
	var record := {
		"status": "",
		"summary": "",
		"day": 0,
		"attempts": 0,
		"hero_level": 1,
		"known_spell_ids": [],
		"artifact_ids": [],
		"specialties": [],
		"exported_flags": {},
	}
	if not (value is Dictionary):
		return record
	record["status"] = String(value.get("status", ""))
	record["summary"] = String(value.get("summary", ""))
	record["day"] = max(0, int(value.get("day", 0)))
	record["attempts"] = max(0, int(value.get("attempts", 0)))
	record["hero_level"] = max(1, int(value.get("hero_level", 1)))
	record["known_spell_ids"] = _normalize_string_array(value.get("known_spell_ids", []))
	record["artifact_ids"] = _normalize_string_array(value.get("artifact_ids", []))
	record["specialties"] = _normalize_string_array(value.get("specialties", []))
	record["exported_flags"] = _normalize_flag_dict(value.get("exported_flags", {}))
	return record

static func _normalize_carryover_bundle(value: Variant) -> Dictionary:
	var bundle := {
		"source_scenario_id": "",
		"hero_id": "",
		"summary": "",
		"resources": {},
		"hero_progression": {},
		"spell_ids": [],
		"artifacts": ArtifactRules.normalize_hero_artifacts({}),
		"flags": {},
	}
	if not (value is Dictionary):
		return bundle
	bundle["source_scenario_id"] = String(value.get("source_scenario_id", ""))
	bundle["hero_id"] = String(value.get("hero_id", ""))
	bundle["summary"] = String(value.get("summary", ""))
	bundle["resources"] = _normalize_resource_dict(value.get("resources", {}))
	bundle["hero_progression"] = _normalize_hero_progression(value.get("hero_progression", {}))
	bundle["spell_ids"] = _normalize_string_array(value.get("spell_ids", []))
	bundle["artifacts"] = ArtifactRules.normalize_hero_artifacts(value.get("artifacts", {}))
	bundle["flags"] = _normalize_flag_dict(value.get("flags", {}))
	return bundle

static func _normalize_hero_progression(value: Variant) -> Dictionary:
	if not (value is Dictionary):
		return HeroProgressionRules.ensure_hero_progression({})
	var command = value.get("command", {})
	return HeroProgressionRules.ensure_hero_progression(
		{
			"level": max(1, int(value.get("level", 1))),
			"experience": max(0, int(value.get("experience", 0))),
			"next_level_experience": max(250, int(value.get("next_level_experience", 250))),
			"command": {
				"attack": max(0, int(command.get("attack", 0))),
				"defense": max(0, int(command.get("defense", 0))),
				"power": max(0, int(command.get("power", 0))),
				"knowledge": max(0, int(command.get("knowledge", 0))),
			},
			"specialties": value.get("specialties", []),
			"pending_specialty_choices": value.get("pending_specialty_choices", []),
		}
	)

static func _campaign_items() -> Array:
	return ContentService.load_json(ContentService.CAMPAIGNS_PATH).get("items", [])

static func _find_scenario_entry(campaign: Dictionary, scenario_id: String) -> Dictionary:
	if campaign.is_empty() or scenario_id == "":
		return {}
	for scenario_entry in campaign.get("scenarios", []):
		if scenario_entry is Dictionary and String(scenario_entry.get("scenario_id", "")) == scenario_id:
			return scenario_entry
	return {}

static func _scenario_label(scenario_entry: Dictionary, scenario_id: String) -> String:
	var label := String(scenario_entry.get("label", ""))
	if label != "":
		return label
	var scenario := ContentService.get_scenario(scenario_id)
	return String(scenario.get("name", scenario_id))

static func _chapter_heading(scenario_entry: Dictionary, scenario_id: String) -> String:
	var chapter_index := int(scenario_entry.get("chapter_index", 0))
	var chapter_title := String(scenario_entry.get("chapter_title", ""))
	if chapter_index > 0 and chapter_title != "":
		return "Chapter %d: %s" % [chapter_index, chapter_title]
	if chapter_title != "":
		return chapter_title
	return _scenario_label(scenario_entry, scenario_id)

static func _scenario_status_label(unlocked: bool, record: Dictionary) -> String:
	if not unlocked:
		return "Locked"
	match String(record.get("status", "")):
		"victory":
			return "Completed"
		"defeat":
			return "Retry"
		_:
			return "Unlocked"

static func _campaign_progress(profile: Dictionary, campaign_id: String) -> Dictionary:
	var normalized := normalize_profile(profile)
	var campaign := ContentService.get_campaign(campaign_id)
	var total_chapters := 0
	var victories := 0
	var unlocked := 0
	for scenario_entry in campaign.get("scenarios", []):
		if not (scenario_entry is Dictionary):
			continue
		total_chapters += 1
		var scenario_id := String(scenario_entry.get("scenario_id", ""))
		if is_scenario_unlocked(normalized, campaign_id, scenario_id):
			unlocked += 1
		if String(get_scenario_record(normalized, campaign_id, scenario_id).get("status", "")) == "victory":
			victories += 1
	return {
		"total_chapters": total_chapters,
		"victories": victories,
		"unlocked": unlocked,
	}

static func _campaign_status_label(progress: Dictionary) -> String:
	var total_chapters := int(max(1, int(progress.get("total_chapters", 0))))
	var victories := int(progress.get("victories", 0))
	if victories >= total_chapters:
		return "Completed"
	if victories > 0:
		return "%d/%d cleared" % [victories, total_chapters]
	return "Ready"

static func _latest_campaign_record(profile: Dictionary, campaign_id: String) -> Dictionary:
	var state := get_campaign_state(profile, campaign_id)
	var last_completed_scenario_id := String(state.get("last_completed_scenario_id", ""))
	if last_completed_scenario_id == "":
		return {}
	return get_scenario_record(profile, campaign_id, last_completed_scenario_id)

static func _campaign_is_completed(profile: Dictionary, campaign_id: String) -> bool:
	var progress := _campaign_progress(profile, campaign_id)
	return int(progress.get("total_chapters", 0)) > 0 and int(progress.get("victories", 0)) >= int(progress.get("total_chapters", 0))

static func _final_scenario_entry(campaign: Dictionary) -> Dictionary:
	if campaign.is_empty():
		return {}
	var scenario_entries = campaign.get("scenarios", [])
	if not (scenario_entries is Array) or scenario_entries.is_empty():
		return {}
	for index in range(scenario_entries.size() - 1, -1, -1):
		var scenario_entry = scenario_entries[index]
		if scenario_entry is Dictionary:
			return scenario_entry
	return {}

static func _next_scenario_entry(campaign: Dictionary, scenario_id: String) -> Dictionary:
	if campaign.is_empty() or scenario_id == "":
		return {}
	var found_current := false
	for scenario_entry in campaign.get("scenarios", []):
		if not (scenario_entry is Dictionary):
			continue
		if found_current:
			return scenario_entry
		if String(scenario_entry.get("scenario_id", "")) == scenario_id:
			found_current = true
	return {}

static func _campaign_browser_arc_line(
	profile: Dictionary,
	campaign_id: String,
	campaign: Dictionary,
	progress: Dictionary,
	next_entry: Dictionary,
	next_label: String
) -> String:
	if _campaign_is_completed(profile, campaign_id):
		return "Arc complete: %s" % _campaign_completion_title(campaign)
	var cleared_summary := "%d/%d cleared" % [
		int(progress.get("victories", 0)),
		max(1, int(progress.get("total_chapters", 0))),
	]
	var arc_goal := _campaign_arc_goal(campaign)
	if arc_goal != "":
		return "Arc goal: %s (%s)" % [arc_goal, cleared_summary]
	if not next_entry.is_empty():
		return "Next: %s | %s" % [next_label, cleared_summary]
	return "Status: %s" % cleared_summary

static func _campaign_arc_status_lines(profile: Dictionary, campaign_id: String) -> Array:
	var campaign := ContentService.get_campaign(campaign_id)
	if campaign.is_empty():
		return ["Campaign Arc", "No campaign is selected."]

	var progress := _campaign_progress(profile, campaign_id)
	var lines := ["Campaign Arc | %s" % _campaign_status_label(progress)]
	var final_entry := _final_scenario_entry(campaign)
	var final_scenario_id := String(final_entry.get("scenario_id", ""))
	var latest_record := _latest_campaign_record(profile, campaign_id)
	if _campaign_is_completed(profile, campaign_id):
		lines[0] = "Campaign Complete | %s" % _campaign_completion_title(campaign)
		var completion_summary := _campaign_completion_summary(campaign)
		if completion_summary != "":
			lines.append(completion_summary)
		if final_scenario_id != "":
			var final_record := get_scenario_record(profile, campaign_id, final_scenario_id)
			var completion_day := int(final_record.get("day", latest_record.get("day", 0)))
			lines.append("Finale secured through %s on Day %d." % [_chapter_heading(final_entry, final_scenario_id), completion_day])
			var command_snapshot := _record_snapshot_summary(final_record)
			if command_snapshot != "":
				lines.append("Closing command snapshot: %s." % command_snapshot)
		return lines

	var arc_goal := _campaign_arc_goal(campaign)
	if arc_goal != "":
		lines.append("Arc goal: %s" % arc_goal)
	if final_scenario_id != "":
		lines.append("Campaign finale: %s." % _chapter_heading(final_entry, final_scenario_id))
	var next_scenario_id := first_available_scenario(profile, campaign_id)
	var next_entry := _find_scenario_entry(campaign, next_scenario_id)
	if not next_entry.is_empty():
		lines.append("Next decisive chapter: %s." % _chapter_heading(next_entry, next_scenario_id))
	if not latest_record.is_empty():
		lines.append("Latest frontline report: %s." % String(latest_record.get("summary", "")))
	return lines

static func _campaign_arc_outcome_lines(profile: Dictionary, campaign_id: String, session: SessionStateStore.SessionData) -> Array:
	var campaign := ContentService.get_campaign(campaign_id)
	if campaign.is_empty():
		return []

	var progress := _campaign_progress(profile, campaign_id)
	var current_entry := _find_scenario_entry(campaign, session.scenario_id)
	var current_heading := _chapter_heading(current_entry, session.scenario_id)
	var lines := []
	if session.scenario_status == "victory" and _campaign_is_completed(profile, campaign_id):
		lines.append("Campaign Complete | %s" % _campaign_completion_title(campaign))
		var completion_summary := _campaign_completion_summary(campaign)
		if completion_summary != "":
			lines.append(completion_summary)
		lines.append("%s closes the authored campaign route." % current_heading)
		var final_record := get_scenario_record(profile, campaign_id, session.scenario_id)
		var command_snapshot := _record_snapshot_summary(final_record)
		if command_snapshot != "":
			lines.append("Final command snapshot: %s." % command_snapshot)
		return lines

	lines.append("Campaign Arc | %s" % _campaign_status_label(progress))
	var arc_goal := _campaign_arc_goal(campaign)
	if arc_goal != "":
		lines.append("Arc goal: %s" % arc_goal)
	var final_entry := _final_scenario_entry(campaign)
	var final_scenario_id := String(final_entry.get("scenario_id", ""))
	if final_scenario_id != "" and final_scenario_id != session.scenario_id:
		lines.append("Finale remains ahead: %s." % _chapter_heading(final_entry, final_scenario_id))
	if session.scenario_status == "victory":
		var remaining_chapters := int(max(0, int(progress.get("total_chapters", 0)) - int(progress.get("victories", 0))))
		lines.append("%s leaves %d chapter%s between the campaign and full arc closure." % [
			current_heading,
			remaining_chapters,
			"" if remaining_chapters == 1 else "s",
		])
	else:
		lines.append("%s must be won before the campaign can close." % current_heading)
	return lines

static func _campaign_arc_goal(campaign: Dictionary) -> String:
	return String(campaign.get("arc_goal", campaign.get("summary", campaign.get("description", ""))))

static func _campaign_completion_title(campaign: Dictionary) -> String:
	var title := String(campaign.get("completion_title", ""))
	if title != "":
		return title
	return "%s Secured" % String(campaign.get("name", "Campaign"))

static func _campaign_completion_summary(campaign: Dictionary) -> String:
	return String(campaign.get("completion_summary", campaign.get("description", "")))

static func _record_snapshot_summary(record: Dictionary) -> String:
	if record.is_empty():
		return ""
	var parts := ["Lv %d" % max(1, int(record.get("hero_level", 1)))]
	var known_spell_ids = record.get("known_spell_ids", [])
	if known_spell_ids is Array and not known_spell_ids.is_empty():
		parts.append("%d spells" % known_spell_ids.size())
	var artifact_ids = record.get("artifact_ids", [])
	if artifact_ids is Array and not artifact_ids.is_empty():
		parts.append("%d relics" % artifact_ids.size())
	var specialties := HeroProgressionRules.summarize_specialty_ids(record.get("specialties", []))
	if specialties != "":
		parts.append(specialties)
	return " | ".join(parts)

static func _outcome_export_bundle(profile: Dictionary, campaign_id: String, scenario_id: String) -> Dictionary:
	var state := get_campaign_state(profile, campaign_id)
	return _normalize_carryover_bundle(state.get("carryover_bundles", {}).get(scenario_id, {}))

static func _campaign_id_for_session(session: SessionStateStore.SessionData) -> String:
	if session == null:
		return ""
	var campaign_id := String(session.flags.get("campaign_id", ""))
	if campaign_id != "" and not ContentService.get_campaign(campaign_id).is_empty():
		return campaign_id
	return get_campaign_id_for_scenario(session.scenario_id)

static func _menu_action_summary(
	profile: Dictionary,
	campaign_id: String,
	scenario_entry: Dictionary,
	unlocked: bool,
	record: Dictionary
) -> String:
	var scenario_id := String(scenario_entry.get("scenario_id", ""))
	var scenario := ContentService.get_scenario(scenario_id)
	var parts := []
	parts.append(String(scenario_entry.get("description", scenario.get("name", scenario_id))))
	parts.append_array(_chapter_briefing_lines(profile, campaign_id, scenario_entry, record, unlocked))
	if unlocked and not record.is_empty():
		parts.append("Last result: %s (Day %d)" % [String(record.get("summary", "")), int(record.get("day", 0))])
	elif not unlocked:
		var unlock_text := _unlock_requirement_text(scenario_entry.get("unlock_requirements", []))
		if unlock_text != "":
			parts.append(unlock_text)

	var bundle := _carryover_bundle_for_node(profile, campaign_id, scenario_entry)
	var carryover_summary := describe_carryover_bundle(bundle)
	if carryover_summary != "":
		parts.append("Carryover: %s" % carryover_summary)
	return "\n".join(parts)

static func _chapter_briefing_lines(
	profile: Dictionary,
	campaign_id: String,
	scenario_entry: Dictionary,
	record: Dictionary,
	unlocked: bool
) -> Array:
	var lines := []
	var scenario_id := String(scenario_entry.get("scenario_id", ""))
	var scenario := ContentService.get_scenario(scenario_id)
	var briefing_text := String(scenario_entry.get("briefing", ""))
	if briefing_text == "":
		briefing_text = String(scenario.get("description", ""))
	if briefing_text == "":
		var selection_summary := String((scenario.get("selection", {}) if scenario.get("selection", {}) is Dictionary else {}).get("summary", ""))
		briefing_text = selection_summary
	if briefing_text != "":
		lines.append("Briefing: %s" % briefing_text)
	var intel_text := String(scenario_entry.get("intel", ""))
	if intel_text == "":
		var selection = scenario.get("selection", {})
		if selection is Dictionary:
			intel_text = String(selection.get("enemy_summary", ""))
	if intel_text != "":
		lines.append("Intel: %s" % intel_text)
	var stakes_text := String(scenario_entry.get("stakes", ""))
	if stakes_text == "":
		stakes_text = _scenario_stakes_text(scenario)
	if stakes_text != "":
		lines.append("Stakes: %s" % stakes_text)
	if unlocked and not record.is_empty():
		var journal_line := _journal_entry_text(scenario_entry, record, scenario_id)
		if journal_line != "":
			lines.append("Chronicle: %s" % journal_line)
	return lines

static func _campaign_journal_lines(profile: Dictionary, campaign_id: String) -> Array:
	var campaign := ContentService.get_campaign(campaign_id)
	if campaign.is_empty():
		return ["Campaign Chronicle", "- No campaign is selected."]
	var lines := ["Campaign Chronicle"]
	var latest_scenario_id := ""
	var latest_day := -1
	for scenario_entry in campaign.get("scenarios", []):
		if not (scenario_entry is Dictionary):
			continue
		var scenario_id := String(scenario_entry.get("scenario_id", ""))
		if scenario_id == "":
			continue
		var record := get_scenario_record(profile, campaign_id, scenario_id)
		if record.is_empty():
			if scenario_id == first_available_scenario(profile, campaign_id):
				lines.append("- Next front: %s | %s" % [_chapter_heading(scenario_entry, scenario_id), _chapter_pending_text(scenario_entry, scenario_id)])
			continue
		var status_label := "Victory" if String(record.get("status", "")) == "victory" else "Setback"
		lines.append("- %s | %s | %s" % [
			_chapter_heading(scenario_entry, scenario_id),
			status_label,
			_journal_entry_text(scenario_entry, record, scenario_id),
		])
		if int(record.get("day", 0)) >= latest_day:
			latest_day = int(record.get("day", 0))
			latest_scenario_id = scenario_id
	if lines.size() == 1:
		lines.append("- No chapter has been recorded yet. The first field report will be written after the opening battle.")
	elif latest_scenario_id != "":
		var latest_entry := _find_scenario_entry(campaign, latest_scenario_id)
		lines.append("- Latest report: %s" % _chapter_heading(latest_entry, latest_scenario_id))
	return lines

static func _latest_journal_line(profile: Dictionary, campaign_id: String) -> String:
	var campaign := ContentService.get_campaign(campaign_id)
	if campaign.is_empty():
		return ""
	var best_line := ""
	var best_day := -1
	for scenario_entry in campaign.get("scenarios", []):
		if not (scenario_entry is Dictionary):
			continue
		var scenario_id := String(scenario_entry.get("scenario_id", ""))
		var record := get_scenario_record(profile, campaign_id, scenario_id)
		if record.is_empty():
			continue
		var day := int(record.get("day", 0))
		if day < best_day:
			continue
		best_day = day
		best_line = _journal_entry_text(scenario_entry, record, scenario_id)
	return best_line

static func _chapter_pending_text(scenario_entry: Dictionary, scenario_id: String) -> String:
	var stakes := String(scenario_entry.get("stakes", ""))
	if stakes != "":
		return stakes
	var scenario := ContentService.get_scenario(scenario_id)
	var selection: Variant = scenario.get("selection", {})
	if selection is Dictionary and String(selection.get("summary", "")) != "":
		return String(selection.get("summary", ""))
	return String(scenario_entry.get("description", "Awaiting orders."))

static func _journal_entry_text(scenario_entry: Dictionary, record: Dictionary, scenario_id: String) -> String:
	var status := String(record.get("status", ""))
	match status:
		"victory":
			var victory_text := String(scenario_entry.get("journal_victory", ""))
			if victory_text != "":
				return victory_text
			return _chapter_aftermath_text(scenario_entry, scenario_id, status)
		"defeat":
			var defeat_text := String(scenario_entry.get("journal_defeat", ""))
			if defeat_text != "":
				return defeat_text
			return _chapter_aftermath_text(scenario_entry, scenario_id, status)
		_:
			return String(record.get("summary", "Field record pending."))

static func _chapter_aftermath_text(scenario_entry: Dictionary, scenario_id: String, status: String) -> String:
	var key := "aftermath_victory" if status == "victory" else "aftermath_defeat"
	var authored_text := String(scenario_entry.get(key, ""))
	if authored_text != "":
		return authored_text
	var scenario := ContentService.get_scenario(scenario_id)
	var objectives = scenario.get("objectives", {})
	if objectives is Dictionary:
		var objective_text := String(objectives.get("%s_text" % status, ""))
		if objective_text != "":
			return objective_text
	return String(scenario_entry.get("description", "Campaign record updated."))

static func _scenario_stakes_text(scenario: Dictionary) -> String:
	var objectives = scenario.get("objectives", {})
	if objectives is Dictionary:
		var victory_text := String(objectives.get("victory_text", ""))
		var defeat_text := String(objectives.get("defeat_text", ""))
		if victory_text != "" and defeat_text != "":
			return "%s If you fail: %s" % [victory_text, defeat_text]
		if victory_text != "":
			return victory_text
		if defeat_text != "":
			return defeat_text
	return ""

static func _unlock_requirement_text(requirements: Variant) -> String:
	if not (requirements is Array) or requirements.is_empty():
		return ""
	var parts := []
	for requirement in requirements:
		if not (requirement is Dictionary):
			continue
		match String(requirement.get("type", "")):
			"scenario_status":
				var scenario := ContentService.get_scenario(String(requirement.get("scenario_id", "")))
				parts.append("Requires %s %s." % [String(scenario.get("name", requirement.get("scenario_id", "Scenario"))), String(requirement.get("status", "victory"))])
			"scenario_flag_true":
				var flag_scenario := ContentService.get_scenario(String(requirement.get("scenario_id", "")))
				parts.append("Requires %s outcome flag %s." % [String(flag_scenario.get("name", requirement.get("scenario_id", "Scenario"))), String(requirement.get("flag", ""))])
	return " ".join(parts)

static func _requirements_met(profile: Dictionary, campaign_id: String, requirements: Variant) -> bool:
	if not (requirements is Array) or requirements.is_empty():
		return false
	for requirement in requirements:
		if not (requirement is Dictionary):
			return false
		if not _requirement_met(profile, campaign_id, requirement):
			return false
	return true

static func _requirement_met(profile: Dictionary, campaign_id: String, requirement: Dictionary) -> bool:
	var dependency_scenario_id := String(requirement.get("scenario_id", ""))
	var record := get_scenario_record(profile, campaign_id, dependency_scenario_id)
	match String(requirement.get("type", "")):
		"scenario_status":
			return String(record.get("status", "")) == String(requirement.get("status", ""))
		"scenario_flag_true":
			return bool(record.get("exported_flags", {}).get(String(requirement.get("flag", "")), false))
		_:
			return false

static func _carryover_bundle_for_node(profile: Dictionary, campaign_id: String, scenario_entry: Dictionary) -> Dictionary:
	if scenario_entry.is_empty():
		return {}
	var import_config = scenario_entry.get("carryover_import", {})
	if not (import_config is Dictionary) or import_config.is_empty():
		return {}
	var source_scenario_id := String(import_config.get("from_scenario_id", ""))
	if source_scenario_id == "":
		return {}
	var campaign_state := get_campaign_state(profile, campaign_id)
	return _normalize_carryover_bundle(campaign_state.get("carryover_bundles", {}).get(source_scenario_id, {}))

static func _build_carryover_bundle(session: SessionStateStore.SessionData, export_config: Variant, captured_flags: Dictionary) -> Dictionary:
	var hero: Dictionary = HeroCommandRules.primary_hero(session)
	var config: Dictionary = export_config if export_config is Dictionary else {}
	var bundle := {
		"source_scenario_id": session.scenario_id,
		"hero_id": String(hero.get("id", "")),
		"summary": session.scenario_summary,
		"resources": _capture_carryover_resources(session.overworld.get("resources", {}), config),
		"hero_progression": {},
		"spell_ids": [],
		"artifacts": ArtifactRules.normalize_hero_artifacts({}),
		"flags": captured_flags.duplicate(true),
	}
	if bool(config.get("retain_hero_progression", true)):
		bundle["hero_progression"] = _normalize_hero_progression(
			{
				"level": int(hero.get("level", 1)),
				"experience": int(hero.get("experience", 0)),
				"next_level_experience": int(hero.get("next_level_experience", 250)),
				"command": hero.get("command", {}),
				"specialties": hero.get("specialties", []),
				"pending_specialty_choices": hero.get("pending_specialty_choices", []),
			}
		)
	if bool(config.get("retain_spells", true)):
		bundle["spell_ids"] = _normalize_string_array(hero.get("spellbook", {}).get("known_spell_ids", []))
	if bool(config.get("retain_artifacts", true)):
		bundle["artifacts"] = ArtifactRules.normalize_hero_artifacts(hero.get("artifacts", {}))
	return _normalize_carryover_bundle(bundle)

static func _capture_carryover_resources(resources: Variant, config: Dictionary) -> Dictionary:
	var captured := {}
	var fraction := clampf(float(config.get("resource_fraction", 0.0)), 0.0, 1.0)
	var caps = config.get("resource_caps", {})
	for key in RESOURCE_KEYS:
		var amount := 0
		if resources is Dictionary:
			amount = int(resources.get(key, 0))
		var carried := int(floor(max(0.0, float(amount) * fraction)))
		if caps is Dictionary and caps.has(key):
			carried = min(carried, max(0, int(caps.get(key, carried))))
		if carried > 0:
			captured[key] = carried
	return captured

static func _capture_exported_flags(session: SessionStateStore.SessionData, export_config: Variant) -> Dictionary:
	var captured := {}
	if not (export_config is Dictionary):
		return captured
	for flag_id_value in export_config.get("flag_ids", []):
		var flag_id := String(flag_id_value)
		if flag_id == "":
			continue
		if bool(session.flags.get(flag_id, false)):
			captured[flag_id] = true
	return captured

static func _apply_carryover(session: SessionStateStore.SessionData, bundle: Dictionary, scenario_entry: Dictionary) -> void:
	if session == null or bundle.is_empty() or scenario_entry.is_empty():
		return
	var import_config = scenario_entry.get("carryover_import", {})
	if not (import_config is Dictionary):
		return

	HeroCommandRules.normalize_session(session)
	var hero: Dictionary = HeroCommandRules.primary_hero(session).duplicate(true)
	var same_hero := String(bundle.get("hero_id", "")) == "" or String(bundle.get("hero_id", "")) == String(hero.get("id", ""))

	if bool(import_config.get("resources", false)):
		var resources: Dictionary = session.overworld.get("resources", {}).duplicate(true)
		for key in RESOURCE_KEYS:
			resources[key] = int(resources.get(key, 0)) + int(bundle.get("resources", {}).get(key, 0))
		session.overworld["resources"] = resources

	if same_hero and bool(import_config.get("hero_progression", false)):
		var hero_progression = bundle.get("hero_progression", {})
		if hero_progression is Dictionary and not hero_progression.is_empty():
			hero["level"] = max(1, int(hero_progression.get("level", hero.get("level", 1))))
			hero["experience"] = max(0, int(hero_progression.get("experience", hero.get("experience", 0))))
			hero["next_level_experience"] = max(250, int(hero_progression.get("next_level_experience", hero.get("next_level_experience", 250))))
			hero["command"] = _merge_command(hero.get("command", {}), hero_progression.get("command", {}))
			hero["specialties"] = hero_progression.get("specialties", hero.get("specialties", []))
			hero["pending_specialty_choices"] = hero_progression.get("pending_specialty_choices", hero.get("pending_specialty_choices", []))

	if same_hero and bool(import_config.get("spells", false)):
		var spellbook = SpellRules.ensure_hero_spellbook(hero).get("spellbook", {})
		spellbook["known_spell_ids"] = _merge_string_arrays(spellbook.get("known_spell_ids", []), bundle.get("spell_ids", []))
		hero["spellbook"] = spellbook

	if same_hero and bool(import_config.get("artifacts", false)):
		hero["artifacts"] = ArtifactRules.merge_hero_artifacts(
			hero.get("artifacts", {}),
			bundle.get("artifacts", {})
		)

	hero = HeroProgressionRules.ensure_hero_progression(hero)
	hero = SpellRules.refresh_daily_mana(hero)
	hero = ArtifactRules.ensure_hero_artifacts(hero)
	session.overworld["active_hero_id"] = String(hero.get("id", session.hero_id))
	session.overworld["hero"] = hero
	session.overworld["army"] = hero.get("army", {})
	session.overworld["hero_position"] = hero.get("position", session.overworld.get("hero_position", {}))
	var movement_max: int = HeroCommandRules.movement_max_for_hero(hero, session)
	session.overworld["movement"] = {"current": movement_max, "max": movement_max}
	HeroCommandRules.commit_active_hero(session)
	HeroCommandRules.normalize_session(session)
	_refresh_fog_of_war(session)

	var prefix := String(import_config.get("flags_prefix", "carryover_"))
	for flag_id in bundle.get("flags", {}).keys():
		var normalized_flag_id := String(flag_id)
		if normalized_flag_id == "":
			continue
		session.flags["%s%s" % [prefix, normalized_flag_id]] = bool(bundle.get("flags", {}).get(flag_id, false))
	if String(bundle.get("source_scenario_id", "")) != "":
		session.flags["campaign_previous_scenario_id"] = String(bundle.get("source_scenario_id", ""))

static func _merge_command(base_command: Variant, imported_command: Variant) -> Dictionary:
	var merged := {
		"attack": 0,
		"defense": 0,
		"power": 0,
		"knowledge": 0,
	}
	for key in merged.keys():
		merged[key] = max(int((base_command if base_command is Dictionary else {}).get(key, 0)), int((imported_command if imported_command is Dictionary else {}).get(key, 0)))
	return merged

static func _merge_artifacts(base_artifacts: Variant, imported_artifacts: Variant) -> Dictionary:
	return ArtifactRules.merge_hero_artifacts(base_artifacts, imported_artifacts)

static func _normalize_string_array(value: Variant) -> Array:
	var normalized := []
	if value is Array:
		for item in value:
			var text := String(item)
			if text != "" and text not in normalized:
				normalized.append(text)
	return normalized

static func _merge_string_arrays(base: Variant, delta: Variant) -> Array:
	var merged := _normalize_string_array(base)
	for item in _normalize_string_array(delta):
		if item not in merged:
			merged.append(item)
	return merged

static func _normalize_flag_dict(value: Variant) -> Dictionary:
	var normalized := {}
	if value is Dictionary:
		for key in value.keys():
			var flag_id := String(key)
			if flag_id != "" and bool(value[key]):
				normalized[flag_id] = true
	return normalized

static func _normalize_resource_dict(value: Variant) -> Dictionary:
	var normalized := {}
	if value is Dictionary:
		for key in RESOURCE_KEYS:
			var amount := int(max(0, int(value.get(key, 0))))
			if amount > 0:
				normalized[key] = amount
	return normalized

static func _describe_resources(value: Variant) -> String:
	if not (value is Dictionary):
		return ""
	var parts := []
	for key in RESOURCE_KEYS:
		var amount := int(value.get(key, 0))
		if amount > 0:
			parts.append("%d %s" % [amount, key])
	return ", ".join(parts)

static func _artifact_ids_from_hero(hero: Dictionary) -> Array:
	var artifact_ids := []
	var artifacts = ArtifactRules.normalize_hero_artifacts(hero.get("artifacts", {}))
	for slot in ArtifactRules.EQUIPMENT_SLOTS:
		var equipped_id := String(artifacts.get("equipped", {}).get(slot, ""))
		if equipped_id != "" and equipped_id not in artifact_ids:
			artifact_ids.append(equipped_id)
	for artifact_id_value in artifacts.get("inventory", []):
		var artifact_id := String(artifact_id_value)
		if artifact_id != "" and artifact_id not in artifact_ids:
			artifact_ids.append(artifact_id)
	return artifact_ids

static func _artifact_count(value: Variant) -> int:
	return _artifact_ids_from_hero({"artifacts": value}).size()
