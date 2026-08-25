extends Control

signal town_action_presentation_blocking_changed(blocking: bool)

const TownRulesScript = preload("res://scripts/core/TownRules.gd")
const OverworldRulesScript = preload("res://scripts/core/OverworldRules.gd")
const HeroCommandRulesScript = preload("res://scripts/core/HeroCommandRules.gd")

const TOWN_VFX_MANIFEST_PATH := "res://content/town_vfx_manifest.json"
const FRAME_FILL := Color(0.05, 0.07, 0.09, 1.0)
const BOARD_FILL := Color(0.09, 0.11, 0.12, 1.0)
const FRAME_COLOR := Color(0.78, 0.66, 0.38, 0.94)
const SKY_COLOR := Color(0.16, 0.23, 0.31, 1.0)
const HAZE_COLOR := Color(0.40, 0.54, 0.58, 0.16)
const GROUND_COLOR := Color(0.20, 0.25, 0.17, 1.0)
const ROAD_COLOR := Color(0.42, 0.33, 0.22, 0.95)
const STONE_COLOR := Color(0.63, 0.63, 0.64, 1.0)
const STONE_SHADOW := Color(0.22, 0.24, 0.28, 1.0)
const WINDOW_GLOW := Color(0.99, 0.86, 0.52, 0.95)
const TEXT_COLOR := Color(0.96, 0.94, 0.88, 1.0)
const SUBTEXT_COLOR := Color(0.84, 0.87, 0.90, 0.96)
const PANEL_TEXT := Color(0.17, 0.21, 0.25, 0.92)
const SCENIC_OVERLAY_MODEL := "responsive_translucent_glass_edge_rails"
const SCENIC_GLASS_FILL := Color(0.025, 0.035, 0.042, 0.78)
const SCENIC_GLASS_CARD_FILL := Color(0.045, 0.058, 0.066, 0.72)
const SCENIC_GLASS_SHADOW := Color(0.0, 0.0, 0.0, 0.28)
const SCENIC_GLASS_BORDER := Color(0.86, 0.72, 0.40, 0.70)
const STATUS_ACCENT_WIDTH := 5.0
const DISTRICT_ACCENT_HEIGHT := 3.0
const FACTION_COLORS := {
	"faction_embercourt": Color(0.86, 0.48, 0.23, 1.0),
	"faction_mireclaw": Color(0.39, 0.69, 0.30, 1.0),
	"faction_sunvault": Color(0.84, 0.70, 0.26, 1.0),
	"faction_thornwake": Color(0.46, 0.62, 0.35, 1.0),
	"faction_brasshollow": Color(0.70, 0.52, 0.31, 1.0),
	"faction_veilmourn": Color(0.42, 0.52, 0.62, 1.0),
}
const FACTION_BACKDROP_PATHS := {
	"faction_embercourt": "res://art/towns/runtime/backdrops/town_embercourt.png",
	"faction_mireclaw": "res://art/towns/runtime/backdrops/town_mireclaw.png",
	"faction_sunvault": "res://art/towns/runtime/backdrops/town_sunvault.png",
	"faction_thornwake": "res://art/towns/runtime/backdrops/town_thornwake.png",
	"faction_brasshollow": "res://art/towns/runtime/backdrops/town_brasshollow.png",
	"faction_veilmourn": "res://art/towns/runtime/backdrops/town_veilmourn.png",
}
const FACTION_BACKDROP_TEXTURES := {
	"faction_embercourt": preload("res://art/towns/runtime/backdrops/town_embercourt.png"),
	"faction_mireclaw": preload("res://art/towns/runtime/backdrops/town_mireclaw.png"),
	"faction_sunvault": preload("res://art/towns/runtime/backdrops/town_sunvault.png"),
	"faction_thornwake": preload("res://art/towns/runtime/backdrops/town_thornwake.png"),
	"faction_brasshollow": preload("res://art/towns/runtime/backdrops/town_brasshollow.png"),
	"faction_veilmourn": preload("res://art/towns/runtime/backdrops/town_veilmourn.png"),
}
const DISTRICT_ORDER := ["military", "economy", "spellcraft", "logistics", "defense"]
const DISTRICT_LABELS := {
	"military": "WAR",
	"economy": "COIN",
	"spellcraft": "MAG",
	"logistics": "ROAD",
	"defense": "WALL",
}
const DISTRICT_COLORS := {
	"military": Color(0.71, 0.34, 0.28, 0.94),
	"economy": Color(0.76, 0.60, 0.29, 0.94),
	"spellcraft": Color(0.42, 0.55, 0.84, 0.94),
	"logistics": Color(0.33, 0.62, 0.56, 0.94),
	"defense": Color(0.53, 0.58, 0.66, 0.94),
}
const RECRUIT_PRESENTATION_MAX_DURATION_MS := 700
const RECRUIT_PRESENTATION_MIN_DURATION_MS := 120

var _session = null
var _town: Dictionary = {}
var _town_template: Dictionary = {}
var _faction: Dictionary = {}
var _stationed: Array = []
var _build_actions: Array = []
var _recruit_actions: Array = []
var _response_actions: Array = []
var _study_actions: Array = []
var _market_actions: Array = []
var _logistics: Dictionary = {}
var _recovery: Dictionary = {}
var _threat: Dictionary = {}
var _occupation: Dictionary = {}
var _front: Dictionary = {}
var _town_action_presentation: Dictionary = {}
var _town_action_presentation_serial := 0
var _town_vfx_manifest: Dictionary = {}
var _town_vfx_manifest_loaded := false
var _town_vfx_textures: Dictionary = {}
var _town_vfx_texture_missing: Dictionary = {}
var _town_action_last_draw: Dictionary = {}

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	focus_mode = Control.FOCUS_NONE
	custom_minimum_size = Vector2(620, 320)
	_load_town_vfx_manifest()
	set_process(false)

func _process(_delta: float) -> void:
	if _town_action_presentation.is_empty():
		set_process(false)
		return
	if Time.get_ticks_msec() >= int(_town_action_presentation.get("expires_msec", 0)):
		dismiss_town_action_presentation()
		return
	queue_redraw()

func _notification(what: int) -> void:
	if what == NOTIFICATION_RESIZED:
		queue_redraw()

func set_town_state(session) -> void:
	_clear_town_state(session)
	if session != null:
		_town = TownRulesScript.get_active_town(session)
		if not _town.is_empty():
			_town_template = ContentService.get_town(String(_town.get("town_id", "")))
			_faction = ContentService.get_faction(String(_town_template.get("faction_id", "")))
			_stationed = HeroCommandRulesScript.stationed_heroes(session, _town)
			_build_actions = TownRulesScript.get_build_actions(session)
			_recruit_actions = TownRulesScript.get_recruit_actions(session)
			_response_actions = TownRulesScript.get_response_actions(session)
			_study_actions = TownRulesScript.get_spell_learning_actions(session)
			_market_actions = TownRulesScript.get_market_actions(session)
			_logistics = OverworldRulesScript.town_logistics_state(session, _town)
			_recovery = OverworldRulesScript.town_recovery_state(session, _town)
			_threat = OverworldRulesScript.town_public_threat_state(session, _town)
			_occupation = OverworldRulesScript.town_occupation_state(session, _town)
			_front = OverworldRulesScript.town_front_state(session, _town)
	queue_redraw()

func set_precomputed_town_state(session, state: Dictionary) -> void:
	_clear_town_state(session)
	if state.is_empty():
		queue_redraw()
		return
	_town = _duplicate_dictionary(state.get("town", {}))
	_town_template = _duplicate_dictionary(state.get("town_template", {}))
	_faction = _duplicate_dictionary(state.get("faction", {}))
	_stationed = _duplicate_array(state.get("stationed", []))
	_build_actions = _duplicate_array(state.get("build_actions", []))
	_recruit_actions = _duplicate_array(state.get("recruit_actions", []))
	_response_actions = _duplicate_array(state.get("response_actions", []))
	_study_actions = _duplicate_array(state.get("study_actions", []))
	_market_actions = _duplicate_array(state.get("market_actions", []))
	_logistics = _duplicate_dictionary(state.get("logistics", {}))
	_recovery = _duplicate_dictionary(state.get("recovery", {}))
	_threat = _duplicate_dictionary(state.get("threat", {}))
	_occupation = _duplicate_dictionary(state.get("occupation", {}))
	_front = _duplicate_dictionary(state.get("front", {}))
	queue_redraw()

func _clear_town_state(session) -> void:
	_session = session
	_town = {}
	_town_template = {}
	_faction = {}
	_stationed = []
	_build_actions = []
	_recruit_actions = []
	_response_actions = []
	_study_actions = []
	_market_actions = []
	_logistics = {}
	_recovery = {}
	_threat = {}
	_occupation = {}
	_front = {}

func _duplicate_dictionary(value: Variant) -> Dictionary:
	return value.duplicate(true) if value is Dictionary else {}

func _duplicate_array(value: Variant) -> Array:
	return value.duplicate(true) if value is Array else []

func _draw() -> void:
	draw_rect(Rect2(Vector2.ZERO, size), FRAME_FILL, true)
	if _town.is_empty():
		return

	var board_rect := Rect2(Vector2(14.0, 14.0), size - Vector2(28.0, 28.0))
	draw_rect(board_rect, BOARD_FILL, true)
	draw_rect(board_rect, FRAME_COLOR, false, 3.0)

	var scene_rect := board_rect.grow(-12.0)
	if not _draw_scenic_backdrop(scene_rect):
		_draw_procedural_stage(scene_rect)
	else:
		draw_rect(scene_rect, Color(0.02, 0.03, 0.04, 0.08), true)
	_draw_status_plaques(scene_rect)
	_draw_district_strip(scene_rect)
	_draw_command_markers(scene_rect)
	_draw_header(scene_rect)
	_draw_town_action_presentation(scene_rect)

func present_town_action(presentation: Dictionary) -> Dictionary:
	var policy: Dictionary = presentation.get("policy", {}) if presentation.get("policy", {}) is Dictionary else {}
	var event_id := String(presentation.get("event_id", ""))
	var expected_cue_id: String = {
		"town_army_transferred": "cue_town_army_transferred",
		"town_specialty_selected": "cue_town_specialty_selected",
		"artifact_acquired": "cue_artifact_acquired",
		"artifact_equipped": "cue_artifact_equipped",
		"artifact_unequipped": "cue_artifact_unequipped",
		"town_hero_hired": "cue_town_hero_hired",
		"town_spell_studied": "cue_town_spell_studied",
		"town_market_exchange_completed": "cue_town_market_exchange_completed",
		"town_route_response_ordered": "cue_town_route_response_ordered",
		"town_units_recruited": "cue_town_units_recruited",
		"town_building_built": "cue_town_building_built",
	}.get(event_id, "")
	var expected_subject_kind: String = {
		"town_army_transferred": "unit_roster",
		"town_specialty_selected": "hero_specialty",
		"artifact_acquired": "artifact",
		"artifact_equipped": "artifact_slot",
		"artifact_unequipped": "artifact_slot",
		"town_hero_hired": "hero",
		"town_spell_studied": "spellbook",
		"town_market_exchange_completed": "resource_stockpile",
		"town_route_response_ordered": "map_object",
		"town_units_recruited": "unit_roster",
		"town_building_built": "building",
	}.get(event_id, "")
	var expected_surface := "artifact" if event_id in ["artifact_acquired", "artifact_equipped", "artifact_unequipped"] else "town"
	var selected_blocking_policy := String(policy.get("selected_blocking_policy", ""))
	if (
		event_id not in ["artifact_acquired", "artifact_equipped", "artifact_unequipped", "town_units_recruited", "town_building_built", "town_route_response_ordered", "town_market_exchange_completed", "town_spell_studied", "town_hero_hired", "town_specialty_selected", "town_army_transferred"]
		or String(presentation.get("town_placement_id", "")) != String(_town.get("placement_id", ""))
		or event_id in ["artifact_acquired", "artifact_equipped", "artifact_unequipped"] and String(presentation.get("artifact_id", "")) == ""
		or event_id in ["artifact_acquired", "artifact_equipped", "artifact_unequipped"] and String(presentation.get("artifact_name", "")) == ""
		or event_id in ["artifact_acquired", "artifact_equipped", "artifact_unequipped"] and not String(presentation.get("artifact_icon_path", "")).begins_with("res://art/artifacts/runtime/")
		or event_id == "artifact_acquired" and String(presentation.get("artifact_action_kind", "")) != "commission"
		or event_id == "artifact_acquired" and String(presentation.get("artifact_location", "")) not in ["equipped", "inventory"]
		or event_id == "artifact_acquired" and String(presentation.get("building_id", "")) == ""
		or event_id == "artifact_acquired" and String(presentation.get("artifact_reward_table_id", "")) == ""
		or event_id == "artifact_acquired" and String(presentation.get("artifact_reward_source_key", "")) == ""
		or event_id == "artifact_acquired" and not (presentation.get("artifact_cost", {}) is Dictionary)
		or event_id == "artifact_acquired" and Dictionary(presentation.get("artifact_cost", {})).is_empty()
		or event_id == "artifact_acquired" and not (presentation.get("resource_deltas", []) is Array)
		or event_id == "artifact_acquired" and Array(presentation.get("resource_deltas", [])).is_empty()
		or event_id == "artifact_equipped" and String(presentation.get("artifact_action_kind", "")) != "equip"
		or event_id == "artifact_equipped" and String(presentation.get("artifact_location", "")) != "equipped"
		or event_id == "artifact_equipped" and String(presentation.get("artifact_slot", "")) == ""
		or event_id == "artifact_unequipped" and String(presentation.get("artifact_action_kind", "")) != "stow"
		or event_id == "artifact_unequipped" and String(presentation.get("artifact_location", "")) != "inventory"
		or event_id == "artifact_unequipped" and String(presentation.get("artifact_slot", "")) == ""
		or event_id == "town_units_recruited" and String(presentation.get("unit_id", "")) == ""
		or event_id == "town_units_recruited" and int(presentation.get("recruited_count", 0)) <= 0
		or event_id == "town_building_built" and String(presentation.get("building_id", "")) == ""
		or event_id == "town_route_response_ordered" and String(presentation.get("response_placement_id", "")) == ""
		or event_id == "town_market_exchange_completed" and String(presentation.get("exchange_action", "")) not in ["buy", "sell"]
		or event_id == "town_market_exchange_completed" and String(presentation.get("exchange_resource_id", "")) not in ["wood", "ore"]
		or event_id == "town_market_exchange_completed" and int(presentation.get("exchange_amount", 0)) <= 0
		or event_id == "town_market_exchange_completed" and not (presentation.get("resource_deltas", []) is Array)
		or event_id == "town_market_exchange_completed" and Array(presentation.get("resource_deltas", [])).size() != 2
		or event_id == "town_spell_studied" and String(presentation.get("spell_id", "")) == ""
		or event_id == "town_spell_studied" and String(presentation.get("spell_name", "")) == ""
		or event_id == "town_spell_studied" and String(presentation.get("spell_school_id", "")) == ""
		or event_id == "town_spell_studied" and String(presentation.get("spell_context", "")) not in ["battle", "overworld"]
		or event_id == "town_spell_studied" and int(presentation.get("spell_tier", 0)) <= 0
		or event_id == "town_spell_studied" and int(presentation.get("known_spell_count", 0)) <= 0
		or event_id == "town_hero_hired" and String(presentation.get("hero_id", "")) == ""
		or event_id == "town_hero_hired" and String(presentation.get("hero_name", "")) == ""
		or event_id == "town_hero_hired" and String(presentation.get("hero_faction_id", "")) == ""
		or event_id == "town_hero_hired" and not (presentation.get("hero_recruit_cost", {}) is Dictionary)
		or event_id == "town_hero_hired" and Dictionary(presentation.get("hero_recruit_cost", {})).is_empty()
		or event_id == "town_hero_hired" and not (presentation.get("resource_deltas", []) is Array)
		or event_id == "town_hero_hired" and Array(presentation.get("resource_deltas", [])).is_empty()
		or event_id == "town_hero_hired" and int(presentation.get("player_hero_count", 0)) <= 1
		or event_id == "town_specialty_selected" and String(presentation.get("hero_id", "")) == ""
		or event_id == "town_specialty_selected" and String(presentation.get("hero_name", "")) == ""
		or event_id == "town_specialty_selected" and String(presentation.get("specialty_id", "")) == ""
		or event_id == "town_specialty_selected" and String(presentation.get("specialty_name", "")) == ""
		or event_id == "town_specialty_selected" and int(presentation.get("specialty_rank", 0)) <= 0
		or event_id == "town_specialty_selected" and int(presentation.get("pending_specialty_choice_count", -1)) < 0
		or event_id == "town_specialty_selected" and not (presentation.get("town_action_recap", {}) is Dictionary)
		or event_id == "town_specialty_selected" and Dictionary(presentation.get("town_action_recap", {})).is_empty()
		or event_id == "town_army_transferred" and String(presentation.get("source_holder_id", "")) == ""
		or event_id == "town_army_transferred" and String(presentation.get("source_holder_label", "")) == ""
		or event_id == "town_army_transferred" and String(presentation.get("target_holder_id", "")) == ""
		or event_id == "town_army_transferred" and String(presentation.get("target_holder_label", "")) == ""
		or event_id == "town_army_transferred" and String(presentation.get("source_holder_id", "")) == String(presentation.get("target_holder_id", ""))
		or event_id == "town_army_transferred" and String(presentation.get("unit_id", "")) == ""
		or event_id == "town_army_transferred" and String(presentation.get("unit_name", "")) == ""
		or event_id == "town_army_transferred" and int(presentation.get("transferred_count", 0)) <= 0
		or event_id == "town_army_transferred" and int(presentation.get("source_count_before", -1)) - int(presentation.get("source_count_after", -1)) != int(presentation.get("transferred_count", 0))
		or event_id == "town_army_transferred" and int(presentation.get("target_count_after", -1)) - int(presentation.get("target_count_before", -1)) != int(presentation.get("transferred_count", 0))
		or event_id == "town_army_transferred" and int(presentation.get("source_count_before", -1)) + int(presentation.get("target_count_before", -1)) != int(presentation.get("source_count_after", -1)) + int(presentation.get("target_count_after", -1))
		or event_id == "town_army_transferred" and not (presentation.get("town_action_recap", {}) is Dictionary)
		or event_id == "town_army_transferred" and Dictionary(presentation.get("town_action_recap", {})).is_empty()
		or String(policy.get("event_id", "")) != event_id
		or String(policy.get("cue_id", "")) != expected_cue_id
		or String(policy.get("surface", "")) != expected_surface
		or String(policy.get("subject_kind", "")) != expected_subject_kind
		or String(policy.get("selected_playback_policy", "")) != "queue_resolved"
		or event_id in ["artifact_equipped", "artifact_unequipped", "town_units_recruited", "town_route_response_ordered", "town_market_exchange_completed", "town_spell_studied", "town_hero_hired", "town_specialty_selected", "town_army_transferred"] and selected_blocking_policy != "nonblocking"
		or event_id in ["artifact_acquired", "town_building_built"] and selected_blocking_policy not in ["input_blocking_timeout", "nonblocking_reduced_motion", "nonblocking_fast_resolve"]
	):
		return validation_town_action_presentation_snapshot()
	if _town_action_presentation_blocks_input():
		town_action_presentation_blocking_changed.emit(false)
	var started_msec := Time.get_ticks_msec()
	var duration_ms := clampi(
		int(policy.get("max_duration_ms", RECRUIT_PRESENTATION_MAX_DURATION_MS)),
		RECRUIT_PRESENTATION_MIN_DURATION_MS,
		RECRUIT_PRESENTATION_MAX_DURATION_MS
	)
	_town_action_presentation_serial += 1
	_town_action_presentation = presentation.duplicate(true)
	_town_action_presentation["serial"] = _town_action_presentation_serial
	_town_action_presentation["started_msec"] = started_msec
	_town_action_presentation["duration_ms"] = duration_ms
	_town_action_presentation["expires_msec"] = started_msec + duration_ms
	var audio_playback_records := []
	for audio_cue_value in Array(policy.get("selected_audio_cue_ids", [])):
		var audio_cue_id := String(audio_cue_value)
		audio_playback_records.append(PresentationAudio.play_cue(audio_cue_id, "TownStageView.present_town_action", {
			"event_id": event_id,
			"presentation_serial": _town_action_presentation_serial,
			"town_placement_id": String(_town.get("placement_id", "")),
		}))
	_town_action_presentation["audio_playback_records"] = audio_playback_records
	_town_action_last_draw = {}
	set_process(true)
	if _town_action_presentation_blocks_input():
		town_action_presentation_blocking_changed.emit(true)
	queue_redraw()
	return validation_town_action_presentation_snapshot()

func dismiss_town_action_presentation() -> void:
	var was_blocking := _town_action_presentation_blocks_input()
	_town_action_presentation = {}
	set_process(false)
	queue_redraw()
	if was_blocking:
		town_action_presentation_blocking_changed.emit(false)

func _town_action_presentation_blocks_input() -> bool:
	if _town_action_presentation.is_empty():
		return false
	var policy: Dictionary = _town_action_presentation.get("policy", {}) if _town_action_presentation.get("policy", {}) is Dictionary else {}
	return String(policy.get("selected_blocking_policy", "")) == "input_blocking_timeout"

func validation_town_action_presentation_snapshot() -> Dictionary:
	var active := not _town_action_presentation.is_empty()
	var policy: Dictionary = _town_action_presentation.get("policy", {}) if active and _town_action_presentation.get("policy", {}) is Dictionary else {}
	var draw_rect := _town_action_presentation_rect(_town_scene_rect()) if active else Rect2()
	var selected_mode := String(policy.get("mode", "normal"))
	var reduced_motion := selected_mode in ["reduced_motion", "reduced_motion_fast"]
	var event_id := String(_town_action_presentation.get("event_id", ""))
	var draw_entries := []
	if active and event_id == "town_building_built":
		draw_entries = ["building_badge_added"] if reduced_motion else ["build_completion_frame", "building_badge_added"]
	elif active and event_id == "town_route_response_ordered":
		draw_entries = ["route_dispatch_badge"] if reduced_motion else ["route_dispatch_art", "route_dispatch_badge"]
	elif active and event_id == "town_market_exchange_completed":
		draw_entries = ["ledger_exchange_badge"] if reduced_motion else ["market_exchange_art", "ledger_exchange_badge"]
	elif active and event_id == "town_spell_studied":
		draw_entries = ["archive_inscribed_badge"] if reduced_motion else ["spell_study_art", "archive_inscribed_badge"]
	elif active and event_id == "town_hero_hired":
		draw_entries = ["commander_arrived_badge"] if reduced_motion else ["hero_hire_art", "commander_arrived_badge"]
	elif active and event_id == "town_specialty_selected":
		draw_entries = ["specialty_rank_badge"] if reduced_motion else ["specialty_rank_sigil", "specialty_rank_badge"]
	elif active and event_id == "town_army_transferred":
		draw_entries = ["unit_transfer_badge"] if reduced_motion else ["unit_transfer_route", "unit_transfer_badge"]
	elif active and event_id == "artifact_acquired":
		draw_entries = ["artifact_badge_added"] if reduced_motion else ["artifact_icon_claim", "artifact_badge_added"]
	elif active and event_id == "artifact_equipped":
		draw_entries = ["slot_badge_added"] if reduced_motion else ["artifact_icon_equip", "slot_badge_added"]
	elif active and event_id == "artifact_unequipped":
		draw_entries = ["slot_badge_removed"] if reduced_motion else ["artifact_icon_stow", "slot_badge_removed"]
	elif active:
		draw_entries = ["recruit_count_badge"] if reduced_motion else ["recruit_muster_rings", "recruit_count_badge"]
	return {
		"active": active,
		"serial": int(_town_action_presentation.get("serial", _town_action_presentation_serial)),
		"event_id": String(_town_action_presentation.get("event_id", "")),
		"cue_id": String(_town_action_presentation.get("cue_id", "")),
		"town_placement_id": String(_town_action_presentation.get("town_placement_id", "")),
		"town_id": String(_town_action_presentation.get("town_id", "")),
		"unit_id": String(_town_action_presentation.get("unit_id", "")),
		"unit_name": String(_town_action_presentation.get("unit_name", "")),
		"building_id": String(_town_action_presentation.get("building_id", "")),
		"building_name": String(_town_action_presentation.get("building_name", "")),
		"response_placement_id": String(_town_action_presentation.get("response_placement_id", "")),
		"response_label": String(_town_action_presentation.get("response_label", "")),
		"exchange_action": String(_town_action_presentation.get("exchange_action", "")),
		"exchange_resource_id": String(_town_action_presentation.get("exchange_resource_id", "")),
		"exchange_amount": int(_town_action_presentation.get("exchange_amount", 0)),
		"resource_deltas": Array(_town_action_presentation.get("resource_deltas", [])).duplicate(true),
		"exchange_label": String(_town_action_presentation.get("exchange_label", "")),
		"spell_id": String(_town_action_presentation.get("spell_id", "")),
		"spell_name": String(_town_action_presentation.get("spell_name", "")),
		"spell_school_id": String(_town_action_presentation.get("spell_school_id", "")),
		"spell_context": String(_town_action_presentation.get("spell_context", "")),
		"spell_tier": int(_town_action_presentation.get("spell_tier", 0)),
		"known_spell_count": int(_town_action_presentation.get("known_spell_count", 0)),
		"hero_id": String(_town_action_presentation.get("hero_id", "")),
		"hero_name": String(_town_action_presentation.get("hero_name", "")),
		"hero_faction_id": String(_town_action_presentation.get("hero_faction_id", "")),
		"specialty_id": String(_town_action_presentation.get("specialty_id", "")),
		"specialty_name": String(_town_action_presentation.get("specialty_name", "")),
		"specialty_rank": int(_town_action_presentation.get("specialty_rank", 0)),
		"pending_specialty_choice_count": int(_town_action_presentation.get("pending_specialty_choice_count", -1)),
		"source_holder_id": String(_town_action_presentation.get("source_holder_id", "")),
		"source_holder_label": String(_town_action_presentation.get("source_holder_label", "")),
		"target_holder_id": String(_town_action_presentation.get("target_holder_id", "")),
		"target_holder_label": String(_town_action_presentation.get("target_holder_label", "")),
		"transferred_count": int(_town_action_presentation.get("transferred_count", 0)),
		"source_count_before": int(_town_action_presentation.get("source_count_before", -1)),
		"source_count_after": int(_town_action_presentation.get("source_count_after", -1)),
		"target_count_before": int(_town_action_presentation.get("target_count_before", -1)),
		"target_count_after": int(_town_action_presentation.get("target_count_after", -1)),
		"hero_recruit_cost": Dictionary(_town_action_presentation.get("hero_recruit_cost", {})).duplicate(true) if _town_action_presentation.get("hero_recruit_cost", {}) is Dictionary else {},
		"player_hero_count": int(_town_action_presentation.get("player_hero_count", 0)),
		"action_id": String(_town_action_presentation.get("action_id", "")),
		"artifact_action_kind": String(_town_action_presentation.get("artifact_action_kind", "")),
		"artifact_id": String(_town_action_presentation.get("artifact_id", "")),
		"artifact_name": String(_town_action_presentation.get("artifact_name", "")),
		"artifact_icon_path": String(_town_action_presentation.get("artifact_icon_path", "")),
		"artifact_location": String(_town_action_presentation.get("artifact_location", "")),
		"artifact_slot": String(_town_action_presentation.get("artifact_slot", "")),
		"artifact_reward_table_id": String(_town_action_presentation.get("artifact_reward_table_id", "")),
		"artifact_reward_source_key": String(_town_action_presentation.get("artifact_reward_source_key", "")),
		"artifact_cost": Dictionary(_town_action_presentation.get("artifact_cost", {})).duplicate(true) if _town_action_presentation.get("artifact_cost", {}) is Dictionary else {},
		"town_action_recap": Dictionary(_town_action_presentation.get("town_action_recap", {})).duplicate(true) if _town_action_presentation.get("town_action_recap", {}) is Dictionary else {},
		"recruited_count": int(_town_action_presentation.get("recruited_count", 0)),
		"result_message": String(_town_action_presentation.get("result_message", "")),
		"selected_mode": selected_mode if active else "",
		"selected_animation_state": String(policy.get("selected_animation_state", "")),
		"selected_fallback_tag": String(policy.get("selected_fallback_tag", "")),
		"selected_vfx_cue_ids": Array(policy.get("selected_vfx_cue_ids", [])).duplicate(),
		"selected_audio_cue_ids": Array(policy.get("selected_audio_cue_ids", [])).duplicate(),
		"audio_playback_records": Array(_town_action_presentation.get("audio_playback_records", [])).duplicate(true),
		"selected_playback_policy": String(policy.get("selected_playback_policy", "")),
		"selected_blocking_policy": String(policy.get("selected_blocking_policy", "")),
		"allows_large_motion": bool(policy.get("allows_large_motion", true)),
		"reduced_motion": reduced_motion,
		"duration_ms": int(_town_action_presentation.get("duration_ms", 0)),
		"started_msec": int(_town_action_presentation.get("started_msec", 0)),
		"expires_msec": int(_town_action_presentation.get("expires_msec", 0)),
		"process_active": is_processing(),
		"draw_rect": draw_rect,
		"draw_rect_contained": _town_scene_rect().encloses(draw_rect) if active else true,
		"blocks_input": _town_action_presentation_blocks_input(),
		"draw_entries": draw_entries,
		"vfx_asset": _town_action_vfx_asset_state(),
		"vfx_draw": _town_action_last_draw.duplicate(true),
	}

func validation_town_building_complete_vfx_asset_summary() -> Dictionary:
	_load_town_vfx_manifest()
	var cues: Dictionary = _town_vfx_manifest.get("cues", {}) if _town_vfx_manifest.get("cues", {}) is Dictionary else {}
	var cue_ids: Array = cues.keys()
	cue_ids.sort()
	var texture_paths: Array = []
	var loaded_texture_paths: Array = []
	var missing_texture_paths: Array = []
	for cue_id_value in cue_ids:
		var cue: Dictionary = cues.get(cue_id_value, {}) if cues.get(cue_id_value, {}) is Dictionary else {}
		var texture_path := String(cue.get("texture_path", "")).strip_edges()
		if texture_path == "" or texture_paths.has(texture_path):
			continue
		texture_paths.append(texture_path)
		if _town_vfx_texture_for_path(texture_path) != null:
			loaded_texture_paths.append(texture_path)
		else:
			missing_texture_paths.append(texture_path)
	return {
		"manifest_path": TOWN_VFX_MANIFEST_PATH,
		"manifest_loaded": _town_vfx_manifest_loaded,
		"schema_id": String(_town_vfx_manifest.get("schema_id", "")),
		"mapped_cue_ids": cue_ids,
		"texture_paths": texture_paths,
		"loaded_texture_paths": loaded_texture_paths,
		"missing_texture_paths": missing_texture_paths,
	}

func _town_scene_rect() -> Rect2:
	return Rect2(Vector2(26.0, 26.0), size - Vector2(52.0, 52.0))

func _town_action_presentation_rect(scene_rect: Rect2) -> Rect2:
	var presentation_size := Vector2(minf(260.0, scene_rect.size.x * 0.48), 54.0)
	return Rect2(
		Vector2(scene_rect.get_center().x - presentation_size.x * 0.5, scene_rect.position.y + scene_rect.size.y * 0.46),
		presentation_size
	)

func _draw_town_action_presentation(scene_rect: Rect2) -> void:
	if _town_action_presentation.is_empty():
		return
	var policy: Dictionary = _town_action_presentation.get("policy", {}) if _town_action_presentation.get("policy", {}) is Dictionary else {}
	var badge_rect := _town_action_presentation_rect(scene_rect)
	var reduced_motion := String(policy.get("mode", "normal")) in ["reduced_motion", "reduced_motion_fast"]
	if String(_town_action_presentation.get("event_id", "")) in ["artifact_acquired", "artifact_equipped", "artifact_unequipped"]:
		_draw_town_artifact_presentation(badge_rect, reduced_motion)
		return
	if String(_town_action_presentation.get("event_id", "")) == "town_building_built":
		_draw_town_building_complete_presentation(badge_rect, reduced_motion)
		return
	if String(_town_action_presentation.get("event_id", "")) == "town_route_response_ordered":
		_draw_town_route_response_presentation(badge_rect, reduced_motion)
		return
	if String(_town_action_presentation.get("event_id", "")) == "town_market_exchange_completed":
		_draw_town_market_exchange_presentation(badge_rect, reduced_motion)
		return
	if String(_town_action_presentation.get("event_id", "")) == "town_spell_studied":
		_draw_town_spell_study_presentation(badge_rect, reduced_motion)
		return
	if String(_town_action_presentation.get("event_id", "")) == "town_hero_hired":
		_draw_town_hero_hire_presentation(badge_rect, reduced_motion)
		return
	if String(_town_action_presentation.get("event_id", "")) == "town_specialty_selected":
		_draw_town_specialty_presentation(badge_rect, reduced_motion)
		return
	if String(_town_action_presentation.get("event_id", "")) == "town_army_transferred":
		_draw_town_army_transfer_presentation(badge_rect, reduced_motion)
		return
	if not reduced_motion:
		var duration_ms: int = maxi(1, int(_town_action_presentation.get("duration_ms", 1)))
		var elapsed_ms: int = maxi(0, Time.get_ticks_msec() - int(_town_action_presentation.get("started_msec", 0)))
		var progress := clampf(float(elapsed_ms) / float(duration_ms), 0.0, 1.0)
		if not _draw_town_recruitment_imported_vfx(badge_rect, progress):
			_draw_town_recruitment_procedural_rings(badge_rect, progress)
	else:
		_town_action_last_draw = {"mode": "recruit_count_badge", "texture_path": "", "alpha": 1.0}
	draw_rect(badge_rect, Color(0.10, 0.13, 0.16, 0.94), true)
	draw_rect(badge_rect, _accent_color(), false, 2.0)
	var unit_name := String(_town_action_presentation.get("unit_name", _town_action_presentation.get("unit_id", "Unit")))
	var recruited_count := int(_town_action_presentation.get("recruited_count", 0))
	_draw_text("MUSTER +%d" % recruited_count, badge_rect.position + Vector2(12.0, 21.0), TEXT_COLOR, 16)
	_draw_text(_short_stage_text(unit_name, 34), badge_rect.position + Vector2(12.0, 42.0), SUBTEXT_COLOR, 13)

func _draw_town_artifact_presentation(badge_rect: Rect2, reduced_motion: bool) -> void:
	var asset_state := _town_artifact_vfx_asset_state()
	var texture: Texture2D = _town_vfx_texture_for_path(String(asset_state.get("texture_path", ""))) as Texture2D
	draw_rect(badge_rect, Color(0.10, 0.13, 0.16, 0.94), true)
	draw_rect(badge_rect, _accent_color(), false, 2.0)
	if not reduced_motion and bool(asset_state.get("uses_imported_asset", false)) and texture != null:
		var extent := badge_rect.size.y * 1.38
		var icon_rect := Rect2(badge_rect.position + Vector2(8.0, (badge_rect.size.y - extent) * 0.5), Vector2(extent, extent))
		draw_texture_rect(texture, icon_rect, false)
		_town_action_last_draw = {"mode": "imported_texture", "texture_path": String(asset_state.get("texture_path", "")), "rect": {"x": icon_rect.position.x, "y": icon_rect.position.y, "width": icon_rect.size.x, "height": icon_rect.size.y}, "alpha": 1.0}
	else:
		var center := badge_rect.position + Vector2(34.0, badge_rect.size.y * 0.5)
		var points := PackedVector2Array([center + Vector2(0.0, -16.0), center + Vector2(14.0, 0.0), center + Vector2(0.0, 16.0), center + Vector2(-14.0, 0.0)])
		draw_colored_polygon(points, _accent_color())
		draw_polyline(PackedVector2Array([points[0], points[1], points[2], points[3], points[0]]), FRAME_COLOR, 2.0)
		_town_action_last_draw = {"mode": String(asset_state.get("fallback_mode", "artifact_badge_added")), "texture_path": "", "diamond_count": 1, "alpha": 1.0}
	var event_id := String(_town_action_presentation.get("event_id", ""))
	var heading := "ARTIFACT COMMISSIONED" if event_id == "artifact_acquired" else ("ARTIFACT EQUIPPED" if event_id == "artifact_equipped" else "ARTIFACT STOWED")
	var artifact_name := String(_town_action_presentation.get("artifact_name", "Artifact"))
	_draw_text(heading, badge_rect.position + Vector2(58.0, 21.0), TEXT_COLOR, 15)
	_draw_text(_short_stage_text(artifact_name, 28), badge_rect.position + Vector2(58.0, 42.0), SUBTEXT_COLOR, 13)

func _draw_town_recruitment_imported_vfx(badge_rect: Rect2, progress: float) -> bool:
	var asset_state := _town_recruitment_vfx_asset_state()
	if not bool(asset_state.get("uses_imported_asset", false)):
		return false
	var texture: Texture2D = _town_vfx_texture_for_path(String(asset_state.get("texture_path", ""))) as Texture2D
	if texture == null:
		return false
	var extent := badge_rect.size.y * 2.4 * float(asset_state.get("scale", 1.0))
	var center := Vector2(badge_rect.get_center().x, badge_rect.position.y - 10.0)
	var draw_rect := Rect2(center - Vector2(extent, extent) * 0.5, Vector2(extent, extent))
	var alpha := clampf(1.0 - progress * 0.48, 0.46, 1.0)
	draw_texture_rect(texture, draw_rect, false, Color(1.0, 1.0, 1.0, alpha))
	_town_action_last_draw = {
		"mode": "imported_texture",
		"texture_path": String(asset_state.get("texture_path", "")),
		"rect": {"x": draw_rect.position.x, "y": draw_rect.position.y, "width": draw_rect.size.x, "height": draw_rect.size.y},
		"alpha": alpha,
	}
	return true

func _draw_town_recruitment_procedural_rings(badge_rect: Rect2, progress: float) -> void:
	var ring_center := Vector2(badge_rect.get_center().x, badge_rect.position.y - 10.0)
	for index in range(3):
		var radius := 14.0 + float(index) * 9.0 + progress * 8.0
		draw_arc(ring_center, radius, 0.0, TAU, 32, _accent_color().lightened(0.20 - progress * 0.10), 2.0)
	_town_action_last_draw = {
		"mode": "existing_procedural_recruit_muster_rings",
		"texture_path": "",
		"alpha": 1.0,
		"ring_count": 3,
	}

func _draw_town_route_response_presentation(badge_rect: Rect2, reduced_motion: bool) -> void:
	var asset_state := _town_route_response_vfx_asset_state()
	var texture: Texture2D = _town_vfx_texture_for_path(String(asset_state.get("texture_path", ""))) as Texture2D
	if not reduced_motion and bool(asset_state.get("uses_imported_asset", false)) and texture != null:
		var extent := badge_rect.size.y * 2.35 * float(asset_state.get("scale", 1.0))
		var center := Vector2(badge_rect.get_center().x, badge_rect.position.y - 10.0)
		var route_rect := Rect2(center - Vector2(extent, extent) * 0.5, Vector2(extent, extent))
		draw_texture_rect(texture, route_rect, false)
		_town_action_last_draw = {"mode": "imported_texture", "texture_path": String(asset_state.get("texture_path", "")), "rect": {"x": route_rect.position.x, "y": route_rect.position.y, "width": route_rect.size.x, "height": route_rect.size.y}, "alpha": 1.0}
	else:
		var center := badge_rect.get_center()
		draw_line(center + Vector2(-42.0, 8.0), center + Vector2(42.0, 8.0), _accent_color(), 4.0)
		draw_circle(center + Vector2(-42.0, 8.0), 6.0, FRAME_COLOR)
		draw_circle(center + Vector2(42.0, 8.0), 6.0, FRAME_COLOR)
		_town_action_last_draw = {"mode": "route_dispatch_badge" if reduced_motion else "procedural_route_dispatch", "texture_path": "", "route_line_count": 1, "seal_count": 2, "alpha": 1.0}
	draw_rect(badge_rect, Color(0.10, 0.13, 0.16, 0.94), true)
	draw_rect(badge_rect, _accent_color(), false, 2.0)
	_draw_text("ROUTE DISPATCHED", badge_rect.position + Vector2(12.0, 22.0), TEXT_COLOR, 16)
	_draw_text(_short_stage_text(String(_town_action_presentation.get("response_label", "Response order")), 34), badge_rect.position + Vector2(12.0, 43.0), SUBTEXT_COLOR, 13)

func _draw_town_market_exchange_presentation(badge_rect: Rect2, reduced_motion: bool) -> void:
	var asset_state := _town_market_exchange_vfx_asset_state()
	var texture: Texture2D = _town_vfx_texture_for_path(String(asset_state.get("texture_path", ""))) as Texture2D
	if not reduced_motion and bool(asset_state.get("uses_imported_asset", false)) and texture != null:
		var extent := badge_rect.size.y * 2.15 * float(asset_state.get("scale", 1.0))
		var center := Vector2(badge_rect.get_center().x, badge_rect.position.y - 6.0)
		var exchange_rect := Rect2(center - Vector2(extent, extent) * 0.5, Vector2(extent, extent))
		draw_texture_rect(texture, exchange_rect, false)
		_town_action_last_draw = {"mode": "imported_texture", "texture_path": String(asset_state.get("texture_path", "")), "rect": {"x": exchange_rect.position.x, "y": exchange_rect.position.y, "width": exchange_rect.size.x, "height": exchange_rect.size.y}, "alpha": 1.0}
	else:
		var center := badge_rect.get_center() + Vector2(0.0, 5.0)
		draw_arc(center, 23.0, 0.2, PI - 0.2, 20, _accent_color(), 3.0)
		draw_arc(center, 23.0, PI + 0.2, TAU - 0.2, 20, FRAME_COLOR, 3.0)
		draw_circle(center + Vector2(-24.0, 0.0), 5.0, FRAME_COLOR)
		draw_circle(center + Vector2(24.0, 0.0), 5.0, _accent_color())
		_town_action_last_draw = {"mode": "ledger_exchange_badge" if reduced_motion else "procedural_market_exchange", "texture_path": "", "arc_count": 2, "token_count": 2, "alpha": 1.0}
	draw_rect(badge_rect, Color(0.10, 0.13, 0.16, 0.94), true)
	draw_rect(badge_rect, _accent_color(), false, 2.0)
	_draw_text("EXCHANGE COMPLETE", badge_rect.position + Vector2(12.0, 22.0), TEXT_COLOR, 16)
	_draw_text(_short_stage_text(String(_town_action_presentation.get("exchange_label", "Market order")), 34), badge_rect.position + Vector2(12.0, 43.0), SUBTEXT_COLOR, 13)

func _draw_town_spell_study_presentation(badge_rect: Rect2, reduced_motion: bool) -> void:
	var asset_state := _town_spell_study_vfx_asset_state()
	var texture: Texture2D = _town_vfx_texture_for_path(String(asset_state.get("texture_path", ""))) as Texture2D
	if not reduced_motion and bool(asset_state.get("uses_imported_asset", false)) and texture != null:
		var extent := badge_rect.size.y * 2.2 * float(asset_state.get("scale", 1.0))
		var center := Vector2(badge_rect.get_center().x, badge_rect.position.y - 7.0)
		var study_rect := Rect2(center - Vector2(extent, extent) * 0.5, Vector2(extent, extent))
		draw_texture_rect(texture, study_rect, false)
		_town_action_last_draw = {"mode": "imported_texture", "texture_path": String(asset_state.get("texture_path", "")), "rect": {"x": study_rect.position.x, "y": study_rect.position.y, "width": study_rect.size.x, "height": study_rect.size.y}, "alpha": 1.0}
	else:
		var center := badge_rect.get_center() + Vector2(0.0, 4.0)
		draw_arc(center, 21.0, 0.0, TAU, 24, _accent_color(), 2.5)
		draw_line(center + Vector2(-16.0, 7.0), center + Vector2(0.0, -8.0), FRAME_COLOR, 3.0)
		draw_line(center + Vector2(0.0, -8.0), center + Vector2(16.0, 7.0), FRAME_COLOR, 3.0)
		_town_action_last_draw = {"mode": "archive_inscribed_badge" if reduced_motion else "procedural_spell_study", "texture_path": "", "arc_count": 1, "page_line_count": 2, "alpha": 1.0}
	draw_rect(badge_rect, Color(0.10, 0.13, 0.16, 0.94), true)
	draw_rect(badge_rect, _accent_color(), false, 2.0)
	_draw_text("SPELL INSCRIBED", badge_rect.position + Vector2(12.0, 22.0), TEXT_COLOR, 16)
	_draw_text(_short_stage_text(String(_town_action_presentation.get("spell_name", "Archive study")), 34), badge_rect.position + Vector2(12.0, 43.0), SUBTEXT_COLOR, 13)

func _draw_town_hero_hire_presentation(badge_rect: Rect2, reduced_motion: bool) -> void:
	var asset_state := _town_hero_hire_vfx_asset_state()
	var texture: Texture2D = _town_vfx_texture_for_path(String(asset_state.get("texture_path", ""))) as Texture2D
	if not reduced_motion and bool(asset_state.get("uses_imported_asset", false)) and texture != null:
		var extent := badge_rect.size.y * 2.2 * float(asset_state.get("scale", 1.0))
		var center := Vector2(badge_rect.get_center().x, badge_rect.position.y - 7.0)
		var hire_rect := Rect2(center - Vector2(extent, extent) * 0.5, Vector2(extent, extent))
		draw_texture_rect(texture, hire_rect, false)
		_town_action_last_draw = {"mode": "imported_texture", "texture_path": String(asset_state.get("texture_path", "")), "rect": {"x": hire_rect.position.x, "y": hire_rect.position.y, "width": hire_rect.size.x, "height": hire_rect.size.y}, "alpha": 1.0}
	else:
		var center := badge_rect.get_center() + Vector2(0.0, 3.0)
		draw_circle(center, 21.0, Color(0.13, 0.42, 0.48, 0.72), false, 2.5)
		draw_line(center + Vector2(-11.0, 12.0), center + Vector2(-11.0, -11.0), FRAME_COLOR, 3.0)
		draw_colored_polygon(PackedVector2Array([center + Vector2(-10.0, -11.0), center + Vector2(13.0, -5.0), center + Vector2(-10.0, 2.0)]), _accent_color())
		_town_action_last_draw = {"mode": "commander_arrived_badge" if reduced_motion else "procedural_hero_hire", "texture_path": "", "circle_count": 1, "banner_line_count": 1, "alpha": 1.0}
	draw_rect(badge_rect, Color(0.10, 0.13, 0.16, 0.94), true)
	draw_rect(badge_rect, _accent_color(), false, 2.0)
	_draw_text("COMMANDER ARRIVED", badge_rect.position + Vector2(12.0, 22.0), TEXT_COLOR, 16)
	_draw_text(_short_stage_text(String(_town_action_presentation.get("hero_name", "New commander")), 34), badge_rect.position + Vector2(12.0, 43.0), SUBTEXT_COLOR, 13)

func _draw_town_specialty_presentation(badge_rect: Rect2, reduced_motion: bool) -> void:
	var center := badge_rect.position + Vector2(34.0, badge_rect.size.y * 0.5)
	var asset_state := _town_specialty_vfx_asset_state()
	var texture: Texture2D = _town_vfx_texture_for_path(String(asset_state.get("texture_path", ""))) as Texture2D
	draw_rect(badge_rect, Color(0.10, 0.13, 0.16, 0.94), true)
	draw_rect(badge_rect, _accent_color(), false, 2.0)
	if reduced_motion:
		draw_circle(center, 15.0, _accent_color(), false, 3.0)
		_town_action_last_draw = {"mode": "specialty_rank_badge", "texture_path": "", "circle_count": 1, "ray_count": 0, "alpha": 1.0}
	elif bool(asset_state.get("uses_imported_asset", false)) and texture != null:
		var extent := badge_rect.size.y * 2.15 * float(asset_state.get("scale", 1.0))
		var specialty_rect := Rect2(center - Vector2(extent, extent) * 0.5, Vector2(extent, extent))
		draw_texture_rect(texture, specialty_rect, false)
		_town_action_last_draw = {"mode": "imported_texture", "texture_path": String(asset_state.get("texture_path", "")), "rect": {"x": specialty_rect.position.x, "y": specialty_rect.position.y, "width": specialty_rect.size.x, "height": specialty_rect.size.y}, "alpha": 1.0}
	else:
		draw_circle(center, 15.0, _accent_color(), false, 3.0)
		for index in range(8):
			var angle := TAU * float(index) / 8.0
			draw_line(center + Vector2.from_angle(angle) * 18.0, center + Vector2.from_angle(angle) * 24.0, FRAME_COLOR, 2.0)
		_town_action_last_draw = {"mode": "procedural_specialty_rank", "texture_path": "", "circle_count": 1, "ray_count": 8, "alpha": 1.0}
	var rank := int(_town_action_presentation.get("specialty_rank", 0))
	_draw_text("SPECIALTY RANK %d" % rank, badge_rect.position + Vector2(58.0, 21.0), TEXT_COLOR, 15)
	_draw_text(_short_stage_text(String(_town_action_presentation.get("specialty_name", "Specialty")), 28), badge_rect.position + Vector2(58.0, 42.0), SUBTEXT_COLOR, 13)

func _draw_town_army_transfer_presentation(badge_rect: Rect2, reduced_motion: bool) -> void:
	var center := badge_rect.position + Vector2(34.0, badge_rect.size.y * 0.5)
	var asset_state := _town_army_transfer_vfx_asset_state()
	var texture: Texture2D = _town_vfx_texture_for_path(String(asset_state.get("texture_path", ""))) as Texture2D
	draw_rect(badge_rect, Color(0.10, 0.13, 0.16, 0.94), true)
	draw_rect(badge_rect, _accent_color(), false, 2.0)
	if reduced_motion:
		draw_line(center + Vector2(-14.0, 0.0), center + Vector2(14.0, 0.0), _accent_color(), 3.0)
		draw_colored_polygon(PackedVector2Array([center + Vector2(14.0, -6.0), center + Vector2(23.0, 0.0), center + Vector2(14.0, 6.0)]), _accent_color())
		_town_action_last_draw = {"mode": "unit_transfer_badge", "texture_path": "", "route_line_count": 1, "arrow_count": 1, "pulse_count": 0, "alpha": 1.0}
	elif bool(asset_state.get("uses_imported_asset", false)) and texture != null:
		var extent := badge_rect.size.y * 2.15 * float(asset_state.get("scale", 1.0))
		var transfer_rect := Rect2(center - Vector2(extent, extent) * 0.5, Vector2(extent, extent))
		draw_texture_rect(texture, transfer_rect, false)
		_town_action_last_draw = {"mode": "imported_texture", "texture_path": String(asset_state.get("texture_path", "")), "rect": {"x": transfer_rect.position.x, "y": transfer_rect.position.y, "width": transfer_rect.size.x, "height": transfer_rect.size.y}, "alpha": 1.0}
	else:
		var progress := fmod(float(maxi(0, Time.get_ticks_msec() - int(_town_action_presentation.get("started_msec", 0)))) / 540.0, 1.0)
		var pulse_center := center + Vector2(lerpf(-13.0, 13.0, progress), 0.0)
		draw_line(center + Vector2(-17.0, 0.0), center + Vector2(14.0, 0.0), _accent_color(), 3.0)
		draw_colored_polygon(PackedVector2Array([center + Vector2(14.0, -6.0), center + Vector2(23.0, 0.0), center + Vector2(14.0, 6.0)]), _accent_color())
		draw_circle(pulse_center, 4.0, FRAME_COLOR)
		_town_action_last_draw = {"mode": "procedural_unit_transfer", "texture_path": "", "route_line_count": 1, "arrow_count": 1, "pulse_count": 1, "alpha": 1.0}
	var transferred_count := int(_town_action_presentation.get("transferred_count", 0))
	var unit_name := String(_town_action_presentation.get("unit_name", "Unit"))
	var source_label := String(_town_action_presentation.get("source_holder_label", "Source"))
	var target_label := String(_town_action_presentation.get("target_holder_label", "Target"))
	_draw_text("REDEPLOYED %d %s" % [transferred_count, _short_stage_text(unit_name, 16)], badge_rect.position + Vector2(58.0, 21.0), TEXT_COLOR, 14)
	_draw_text(_short_stage_text("%s -> %s" % [source_label, target_label], 28), badge_rect.position + Vector2(58.0, 42.0), SUBTEXT_COLOR, 12)

func _draw_town_building_complete_presentation(badge_rect: Rect2, reduced_motion: bool) -> void:
	if not reduced_motion:
		var duration_ms: int = maxi(1, int(_town_action_presentation.get("duration_ms", 1)))
		var elapsed_ms: int = maxi(0, Time.get_ticks_msec() - int(_town_action_presentation.get("started_msec", 0)))
		var progress := clampf(float(elapsed_ms) / float(duration_ms), 0.0, 1.0)
		if not _draw_town_building_complete_imported_vfx(badge_rect, progress):
			_draw_town_building_complete_procedural_frame(badge_rect, progress)
	else:
		_town_action_last_draw = {"mode": "building_badge_added", "texture_path": "", "alpha": 1.0}
	draw_rect(badge_rect, Color(0.10, 0.13, 0.16, 0.94), true)
	draw_rect(badge_rect, FRAME_COLOR, false, 2.0)
	var building_name := String(_town_action_presentation.get("building_name", _town_action_presentation.get("building_id", "Construction")))
	_draw_text("BUILD COMPLETE", badge_rect.position + Vector2(12.0, 21.0), TEXT_COLOR, 16)
	_draw_text(_short_stage_text(building_name, 34), badge_rect.position + Vector2(12.0, 42.0), SUBTEXT_COLOR, 13)

func _draw_town_building_complete_imported_vfx(badge_rect: Rect2, progress: float) -> bool:
	var asset_state := _town_building_complete_vfx_asset_state()
	if not bool(asset_state.get("uses_imported_asset", false)):
		return false
	var texture: Texture2D = _town_vfx_texture_for_path(String(asset_state.get("texture_path", ""))) as Texture2D
	if texture == null:
		return false
	var extent := badge_rect.size.y * 2.4 * float(asset_state.get("scale", 1.0))
	var center := badge_rect.get_center()
	var draw_rect := Rect2(center - Vector2(extent, extent) * 0.5, Vector2(extent, extent))
	var alpha := clampf(1.0 - progress * 0.52, 0.42, 1.0)
	draw_texture_rect(texture, draw_rect, false, Color(1.0, 1.0, 1.0, alpha))
	_town_action_last_draw = {
		"mode": "imported_texture",
		"texture_path": String(asset_state.get("texture_path", "")),
		"rect": {"x": draw_rect.position.x, "y": draw_rect.position.y, "width": draw_rect.size.x, "height": draw_rect.size.y},
		"alpha": alpha,
	}
	return true

func _draw_town_building_complete_procedural_frame(badge_rect: Rect2, progress: float) -> void:
	var frame_rect := badge_rect.grow(4.0 + sin(progress * PI) * 7.0)
	draw_rect(frame_rect, Color(0.92, 0.72, 0.28, 0.78), false, 3.0)
	_town_action_last_draw = {
		"mode": "existing_procedural_build_completion_frame",
		"texture_path": "",
		"rect": {"x": frame_rect.position.x, "y": frame_rect.position.y, "width": frame_rect.size.x, "height": frame_rect.size.y},
		"alpha": 0.78,
	}

func _town_building_complete_vfx_asset_state() -> Dictionary:
	var policy: Dictionary = _town_action_presentation.get("policy", {}) if _town_action_presentation.get("policy", {}) is Dictionary else {}
	var cue_ids: Array = policy.get("selected_vfx_cue_ids", []) if policy.get("selected_vfx_cue_ids", []) is Array else []
	var cue_id := String(cue_ids[0]).strip_edges() if cue_ids.size() == 1 else ""
	var spec := _town_vfx_manifest_cue(cue_id)
	var texture_path := String(spec.get("texture_path", "")).strip_edges()
	var texture_loaded := texture_path != "" and _town_vfx_texture_for_path(texture_path) != null
	var uses_imported_asset := cue_id == "vfx_placeholder_build_complete" \
		and String(_town_action_presentation.get("event_id", "")) == "town_building_built" \
		and String(spec.get("event_id", "")) == "town_building_built" \
		and String(spec.get("render_mode", "")) == "town_building_complete" \
		and texture_loaded
	return {
		"cue_id": cue_id,
		"texture_path": texture_path,
		"scale": float(spec.get("scale", 1.0)),
		"texture_loaded": texture_loaded,
		"uses_imported_asset": uses_imported_asset,
		"uses_procedural_fallback": not uses_imported_asset,
		"fallback_mode": "existing_procedural_build_completion_frame",
	}

func _town_recruitment_vfx_asset_state() -> Dictionary:
	var policy: Dictionary = _town_action_presentation.get("policy", {}) if _town_action_presentation.get("policy", {}) is Dictionary else {}
	var cue_ids: Array = policy.get("selected_vfx_cue_ids", []) if policy.get("selected_vfx_cue_ids", []) is Array else []
	var cue_id := String(cue_ids[0]).strip_edges() if cue_ids.size() == 1 else ""
	var spec := _town_vfx_manifest_cue(cue_id)
	var texture_path := String(spec.get("texture_path", "")).strip_edges()
	var texture_loaded := texture_path != "" and _town_vfx_texture_for_path(texture_path) != null
	var uses_imported_asset := cue_id == "vfx_placeholder_recruit_muster" \
		and String(_town_action_presentation.get("event_id", "")) == "town_units_recruited" \
		and String(spec.get("event_id", "")) == "town_units_recruited" \
		and String(spec.get("render_mode", "")) == "town_recruit_muster" \
		and texture_loaded
	return {
		"cue_id": cue_id,
		"texture_path": texture_path,
		"scale": float(spec.get("scale", 1.0)),
		"texture_loaded": texture_loaded,
		"uses_imported_asset": uses_imported_asset,
		"uses_procedural_fallback": not uses_imported_asset,
		"fallback_mode": "existing_procedural_recruit_muster_rings",
	}

func _town_route_response_vfx_asset_state() -> Dictionary:
	var policy: Dictionary = _town_action_presentation.get("policy", {}) if _town_action_presentation.get("policy", {}) is Dictionary else {}
	var cue_ids: Array = policy.get("selected_vfx_cue_ids", []) if policy.get("selected_vfx_cue_ids", []) is Array else []
	var cue_id := String(cue_ids[0]).strip_edges() if cue_ids.size() == 1 else ""
	var spec := _town_vfx_manifest_cue(cue_id)
	var texture_path := String(spec.get("texture_path", "")).strip_edges()
	var texture_loaded := texture_path != "" and _town_vfx_texture_for_path(texture_path) != null
	var uses_imported_asset := cue_id == "vfx_placeholder_town_route_response" \
		and String(_town_action_presentation.get("event_id", "")) == "town_route_response_ordered" \
		and String(spec.get("event_id", "")) == "town_route_response_ordered" \
		and String(spec.get("render_mode", "")) == "town_route_response_dispatch" \
		and texture_loaded
	return {"cue_id": cue_id, "texture_path": texture_path, "scale": float(spec.get("scale", 1.0)), "texture_loaded": texture_loaded, "uses_imported_asset": uses_imported_asset, "uses_procedural_fallback": not uses_imported_asset, "fallback_mode": "procedural_route_dispatch"}

func _town_market_exchange_vfx_asset_state() -> Dictionary:
	var policy: Dictionary = _town_action_presentation.get("policy", {}) if _town_action_presentation.get("policy", {}) is Dictionary else {}
	var cue_ids: Array = policy.get("selected_vfx_cue_ids", []) if policy.get("selected_vfx_cue_ids", []) is Array else []
	var cue_id := String(cue_ids[0]).strip_edges() if cue_ids.size() == 1 else ""
	var spec := _town_vfx_manifest_cue(cue_id)
	var texture_path := String(spec.get("texture_path", "")).strip_edges()
	var texture_loaded := texture_path != "" and _town_vfx_texture_for_path(texture_path) != null
	var uses_imported_asset := cue_id == "vfx_placeholder_town_market_exchange" \
		and String(_town_action_presentation.get("event_id", "")) == "town_market_exchange_completed" \
		and String(spec.get("event_id", "")) == "town_market_exchange_completed" \
		and String(spec.get("render_mode", "")) == "town_market_exchange_completion" \
		and texture_loaded
	return {"cue_id": cue_id, "texture_path": texture_path, "scale": float(spec.get("scale", 1.0)), "texture_loaded": texture_loaded, "uses_imported_asset": uses_imported_asset, "uses_procedural_fallback": not uses_imported_asset, "fallback_mode": "procedural_market_exchange"}

func _town_spell_study_vfx_asset_state() -> Dictionary:
	var policy: Dictionary = _town_action_presentation.get("policy", {}) if _town_action_presentation.get("policy", {}) is Dictionary else {}
	var cue_ids: Array = policy.get("selected_vfx_cue_ids", []) if policy.get("selected_vfx_cue_ids", []) is Array else []
	var cue_id := String(cue_ids[0]).strip_edges() if cue_ids.size() == 1 else ""
	var spec := _town_vfx_manifest_cue(cue_id)
	var texture_path := String(spec.get("texture_path", "")).strip_edges()
	var texture_loaded := texture_path != "" and _town_vfx_texture_for_path(texture_path) != null
	var uses_imported_asset := cue_id == "vfx_placeholder_town_spell_study" \
		and String(_town_action_presentation.get("event_id", "")) == "town_spell_studied" \
		and String(spec.get("event_id", "")) == "town_spell_studied" \
		and String(spec.get("render_mode", "")) == "town_spell_study_completion" \
		and texture_loaded
	return {"cue_id": cue_id, "texture_path": texture_path, "scale": float(spec.get("scale", 1.0)), "texture_loaded": texture_loaded, "uses_imported_asset": uses_imported_asset, "uses_procedural_fallback": not uses_imported_asset, "fallback_mode": "procedural_spell_study"}

func _town_hero_hire_vfx_asset_state() -> Dictionary:
	var policy: Dictionary = _town_action_presentation.get("policy", {}) if _town_action_presentation.get("policy", {}) is Dictionary else {}
	var cue_ids: Array = policy.get("selected_vfx_cue_ids", []) if policy.get("selected_vfx_cue_ids", []) is Array else []
	var cue_id := String(cue_ids[0]).strip_edges() if cue_ids.size() == 1 else ""
	var spec := _town_vfx_manifest_cue(cue_id)
	var texture_path := String(spec.get("texture_path", "")).strip_edges()
	var texture_loaded := texture_path != "" and _town_vfx_texture_for_path(texture_path) != null
	var uses_imported_asset := cue_id == "vfx_placeholder_town_hero_hire" \
		and String(_town_action_presentation.get("event_id", "")) == "town_hero_hired" \
		and String(spec.get("event_id", "")) == "town_hero_hired" \
		and String(spec.get("render_mode", "")) == "town_hero_hire_completion" \
		and texture_loaded
	return {"cue_id": cue_id, "texture_path": texture_path, "scale": float(spec.get("scale", 1.0)), "texture_loaded": texture_loaded, "uses_imported_asset": uses_imported_asset, "uses_procedural_fallback": not uses_imported_asset, "fallback_mode": "procedural_hero_hire"}

func _town_specialty_vfx_asset_state() -> Dictionary:
	var policy: Dictionary = _town_action_presentation.get("policy", {}) if _town_action_presentation.get("policy", {}) is Dictionary else {}
	var cue_ids: Array = policy.get("selected_vfx_cue_ids", []) if policy.get("selected_vfx_cue_ids", []) is Array else []
	var cue_id := String(cue_ids[0]).strip_edges() if cue_ids.size() == 1 else ""
	var reduced_motion := String(policy.get("mode", "normal")) in ["reduced_motion", "reduced_motion_fast"]
	if reduced_motion:
		return {"cue_id": cue_id, "texture_path": "", "scale": 1.0, "texture_loaded": false, "uses_imported_asset": false, "uses_procedural_fallback": cue_id == "specialty_rank_badge", "fallback_mode": "specialty_rank_badge"}
	var spec := _town_vfx_manifest_cue(cue_id)
	var texture_path := String(spec.get("texture_path", "")).strip_edges()
	var texture_loaded := texture_path != "" and _town_vfx_texture_for_path(texture_path) != null
	var uses_imported_asset := cue_id == "vfx_placeholder_town_specialty_rank" \
		and String(_town_action_presentation.get("event_id", "")) == "town_specialty_selected" \
		and String(spec.get("event_id", "")) == "town_specialty_selected" \
		and String(spec.get("render_mode", "")) == "town_specialty_rank_completion" \
		and texture_loaded
	return {"cue_id": cue_id, "texture_path": texture_path, "scale": float(spec.get("scale", 1.0)), "texture_loaded": texture_loaded, "uses_imported_asset": uses_imported_asset, "uses_procedural_fallback": not uses_imported_asset, "fallback_mode": "procedural_specialty_rank"}

func _town_army_transfer_vfx_asset_state() -> Dictionary:
	var policy: Dictionary = _town_action_presentation.get("policy", {}) if _town_action_presentation.get("policy", {}) is Dictionary else {}
	var cue_ids: Array = policy.get("selected_vfx_cue_ids", []) if policy.get("selected_vfx_cue_ids", []) is Array else []
	var cue_id := String(cue_ids[0]).strip_edges() if cue_ids.size() == 1 else ""
	var reduced_motion := String(policy.get("mode", "normal")) in ["reduced_motion", "reduced_motion_fast"]
	if reduced_motion:
		return {"cue_id": cue_id, "texture_path": "", "scale": 1.0, "texture_loaded": false, "uses_imported_asset": false, "uses_procedural_fallback": cue_id == "unit_transfer_badge", "fallback_mode": "unit_transfer_badge"}
	var spec := _town_vfx_manifest_cue(cue_id)
	var texture_path := String(spec.get("texture_path", "")).strip_edges()
	var texture_loaded := texture_path != "" and _town_vfx_texture_for_path(texture_path) != null
	var uses_imported_asset := cue_id == "vfx_placeholder_town_unit_transfer" \
		and String(_town_action_presentation.get("event_id", "")) == "town_army_transferred" \
		and String(spec.get("event_id", "")) == "town_army_transferred" \
		and String(spec.get("render_mode", "")) == "town_unit_transfer_completion" \
		and texture_loaded
	return {"cue_id": cue_id, "texture_path": texture_path, "scale": float(spec.get("scale", 1.0)), "texture_loaded": texture_loaded, "uses_imported_asset": uses_imported_asset, "uses_procedural_fallback": not uses_imported_asset, "fallback_mode": "procedural_unit_transfer"}

func _town_artifact_vfx_asset_state() -> Dictionary:
	var policy: Dictionary = _town_action_presentation.get("policy", {}) if _town_action_presentation.get("policy", {}) is Dictionary else {}
	var cue_ids: Array = policy.get("selected_vfx_cue_ids", []) if policy.get("selected_vfx_cue_ids", []) is Array else []
	var cue_id := String(cue_ids[0]).strip_edges() if cue_ids.size() == 1 else ""
	var event_id := String(_town_action_presentation.get("event_id", ""))
	var expected_cue_id := "vfx_placeholder_artifact_claim" if event_id == "artifact_acquired" else ("vfx_placeholder_slot_equip" if event_id == "artifact_equipped" else ("vfx_placeholder_slot_unequip" if event_id == "artifact_unequipped" else ""))
	var texture_path := String(_town_action_presentation.get("artifact_icon_path", "")).strip_edges()
	var texture_loaded := texture_path.begins_with("res://art/artifacts/runtime/") and _town_vfx_texture_for_path(texture_path) != null
	var uses_imported_asset := cue_id == expected_cue_id and expected_cue_id != "" and texture_loaded
	var fallback_mode := "artifact_badge_added" if event_id == "artifact_acquired" else ("slot_badge_added" if event_id == "artifact_equipped" else "slot_badge_removed")
	return {"cue_id": cue_id, "texture_path": texture_path, "scale": 1.0, "texture_loaded": texture_loaded, "uses_imported_asset": uses_imported_asset, "uses_procedural_fallback": not uses_imported_asset, "fallback_mode": fallback_mode}

func _town_action_vfx_asset_state() -> Dictionary:
	if String(_town_action_presentation.get("event_id", "")) in ["artifact_acquired", "artifact_equipped", "artifact_unequipped"]:
		return _town_artifact_vfx_asset_state()
	if String(_town_action_presentation.get("event_id", "")) == "town_specialty_selected":
		return _town_specialty_vfx_asset_state()
	if String(_town_action_presentation.get("event_id", "")) == "town_army_transferred":
		return _town_army_transfer_vfx_asset_state()
	if String(_town_action_presentation.get("event_id", "")) == "town_hero_hired":
		return _town_hero_hire_vfx_asset_state()
	if String(_town_action_presentation.get("event_id", "")) == "town_spell_studied":
		return _town_spell_study_vfx_asset_state()
	if String(_town_action_presentation.get("event_id", "")) == "town_market_exchange_completed":
		return _town_market_exchange_vfx_asset_state()
	if String(_town_action_presentation.get("event_id", "")) == "town_route_response_ordered":
		return _town_route_response_vfx_asset_state()
	if String(_town_action_presentation.get("event_id", "")) == "town_units_recruited":
		return _town_recruitment_vfx_asset_state()
	return _town_building_complete_vfx_asset_state()

func _town_vfx_manifest_cue(cue_id: String) -> Dictionary:
	_load_town_vfx_manifest()
	var cues: Dictionary = _town_vfx_manifest.get("cues", {}) if _town_vfx_manifest.get("cues", {}) is Dictionary else {}
	var cue: Dictionary = cues.get(cue_id, {}) if cues.get(cue_id, {}) is Dictionary else {}
	return cue.duplicate(true)

func _load_town_vfx_manifest() -> void:
	if _town_vfx_manifest_loaded:
		return
	_town_vfx_manifest_loaded = true
	_town_vfx_manifest = {}
	_town_vfx_textures.clear()
	_town_vfx_texture_missing.clear()
	if not FileAccess.file_exists(TOWN_VFX_MANIFEST_PATH):
		return
	var parsed = JSON.parse_string(FileAccess.get_file_as_string(TOWN_VFX_MANIFEST_PATH))
	if parsed is Dictionary:
		_town_vfx_manifest = parsed

func _town_vfx_texture_for_path(texture_path: String):
	if texture_path == "" or _town_vfx_texture_missing.has(texture_path):
		return null
	if _town_vfx_textures.has(texture_path):
		return _town_vfx_textures.get(texture_path)
	if not ResourceLoader.exists(texture_path):
		_town_vfx_texture_missing[texture_path] = true
		return null
	var loaded = load(texture_path)
	if loaded is Texture2D:
		_town_vfx_textures[texture_path] = loaded
		return loaded
	_town_vfx_texture_missing[texture_path] = true
	return null

func _draw_procedural_stage(scene_rect: Rect2) -> void:
	var horizon_y := scene_rect.position.y + scene_rect.size.y * 0.58
	var sky_rect := Rect2(scene_rect.position, Vector2(scene_rect.size.x, horizon_y - scene_rect.position.y))
	var ground_rect := Rect2(Vector2(scene_rect.position.x, horizon_y), Vector2(scene_rect.size.x, scene_rect.end.y - horizon_y))
	draw_rect(sky_rect, SKY_COLOR, true)
	draw_rect(ground_rect, GROUND_COLOR, true)
	_draw_haze(scene_rect)
	_draw_roads(ground_rect)
	_draw_city(scene_rect, ground_rect)

func _draw_scenic_backdrop(scene_rect: Rect2) -> bool:
	var texture := _scenic_backdrop_texture()
	if texture == null or scene_rect.size.x <= 0.0 or scene_rect.size.y <= 0.0:
		return false
	var source_rect := _cover_source_rect(texture.get_size(), scene_rect.size)
	if source_rect.size.x <= 0.0 or source_rect.size.y <= 0.0:
		return false
	draw_texture_rect_region(texture, scene_rect, source_rect)
	return true

func _scenic_backdrop_texture() -> Texture2D:
	var value: Variant = FACTION_BACKDROP_TEXTURES.get(_town_faction_id(), null)
	return value as Texture2D if value is Texture2D else null

func _town_faction_id() -> String:
	var faction_id := String(_town_template.get("faction_id", ""))
	if faction_id == "":
		faction_id = String(_faction.get("id", ""))
	return faction_id

func _cover_source_rect(texture_size: Vector2, destination_size: Vector2) -> Rect2:
	if texture_size.x <= 0.0 or texture_size.y <= 0.0 or destination_size.x <= 0.0 or destination_size.y <= 0.0:
		return Rect2()
	var cover_scale := maxf(destination_size.x / texture_size.x, destination_size.y / texture_size.y)
	var source_size := destination_size / cover_scale
	return Rect2((texture_size - source_size) * 0.5, source_size)

func validation_scenic_backdrop_summary() -> Dictionary:
	var faction_id := _town_faction_id()
	var texture := _scenic_backdrop_texture()
	var scene_rect := Rect2(Vector2(26.0, 26.0), size - Vector2(52.0, 52.0))
	var texture_size := texture.get_size() if texture != null else Vector2.ZERO
	var source_rect := _cover_source_rect(texture_size, scene_rect.size) if texture != null else Rect2()
	return {
		"faction_id": faction_id,
		"mapped_path": String(FACTION_BACKDROP_PATHS.get(faction_id, "")),
		"texture_loaded": texture != null,
		"texture_size": texture_size,
		"destination_rect": scene_rect,
		"source_rect": source_rect,
		"source_within_texture": texture != null \
			and source_rect.position.x >= 0.0 \
			and source_rect.position.y >= 0.0 \
			and source_rect.end.x <= texture_size.x \
			and source_rect.end.y <= texture_size.y,
		"destination_contained": scene_rect.position.x >= 0.0 \
			and scene_rect.position.y >= 0.0 \
			and scene_rect.end.x <= size.x \
			and scene_rect.end.y <= size.y,
		"rendering_mode": "cover_crop_scenic_backdrop" if texture != null else "procedural_geometry_fallback",
		"procedural_fallback": texture == null,
		"overlay_order": ["scenic_or_procedural_stage", "status_plaques", "district_strip", "command_markers", "header"],
	}

func validation_status_plaques_summary() -> Dictionary:
	var scene_size := Vector2(maxf(0.0, size.x - 52.0), maxf(0.0, size.y - 52.0))
	var scene_rect := Rect2(Vector2(26.0, 26.0), scene_size)
	var plaques := _status_plaque_payloads()
	var rects := _status_plaque_rects(scene_rect, plaques.size())
	var contained := rects.size() == plaques.size()
	for rect_value in rects:
		if not (rect_value is Rect2) or not scene_rect.encloses(rect_value):
			contained = false
	return {
		"plaques": plaques.duplicate(true),
		"rects": rects.duplicate(true),
		"plaque_count": plaques.size(),
		"front_plaque": plaques[2].duplicate(true) if plaques.size() > 2 else {},
		"occupation": _occupation.duplicate(true),
		"front": _front.duplicate(true),
		"contained": contained,
		"scene_rect": scene_rect,
	}

func validation_scenic_overlay_summary() -> Dictionary:
	var scene_size := Vector2(maxf(0.0, size.x - 52.0), maxf(0.0, size.y - 52.0))
	var scene_rect := Rect2(Vector2(26.0, 26.0), scene_size)
	var status_payloads := _status_plaque_payloads()
	var status_rects := _status_plaque_rects(scene_rect, status_payloads.size())
	var district_payloads := _district_strip_payloads()
	var district_strip_rect := _district_strip_rect(scene_rect)
	var district_rects := _district_card_rects(district_strip_rect, district_payloads.size())
	var contained := scene_rect.encloses(district_strip_rect)
	var status_district_nonoverlap := true
	for rect_value in status_rects:
		if not (rect_value is Rect2) or not scene_rect.encloses(rect_value):
			contained = false
		elif district_strip_rect.intersects(rect_value):
			status_district_nonoverlap = false
	for rect_value in district_rects:
		if not (rect_value is Rect2) or not district_strip_rect.encloses(rect_value):
			contained = false
	var scene_area := maxf(1.0, scene_rect.size.x * scene_rect.size.y)
	var overlay_area := district_strip_rect.size.x * district_strip_rect.size.y
	for rect_value in status_rects:
		if rect_value is Rect2:
			overlay_area += rect_value.size.x * rect_value.size.y
	return {
		"model": SCENIC_OVERLAY_MODEL,
		"compact": _scenic_overlay_compact(scene_rect),
		"scene_rect": scene_rect,
		"status_payloads": status_payloads.duplicate(true),
		"status_rects": status_rects.duplicate(true),
		"status_count": status_payloads.size(),
		"district_payloads": district_payloads.duplicate(true),
		"district_strip_rect": district_strip_rect,
		"district_rects": district_rects.duplicate(true),
		"district_count": district_payloads.size(),
		"contained": contained,
		"status_district_nonoverlap": status_district_nonoverlap,
		"glass_fill_alpha": SCENIC_GLASS_FILL.a,
		"glass_card_fill_alpha": SCENIC_GLASS_CARD_FILL.a,
		"status_accent_width": STATUS_ACCENT_WIDTH,
		"district_accent_height": DISTRICT_ACCENT_HEIGHT,
		"overlay_area_ratio": overlay_area / scene_area,
		"payload_authority": "existing_status_and_district_builders",
	}

func validation_header_action_count_summary() -> Dictionary:
	var scene_rect := Rect2(Vector2(26.0, 26.0), Vector2(maxf(0.0, size.x - 52.0), maxf(0.0, size.y - 52.0)))
	var max_width := maxf(0.0, scene_rect.size.x - 36.0)
	var title_full_text := _header_title_text()
	var full_text := _header_action_count_text()
	var title_rendered_text := _fit_stage_header_text(title_full_text, max_width, 20)
	var rendered_text := _fit_stage_header_text(full_text, max_width, 13)
	var font = get_theme_default_font()
	return {
		"title_full_text": title_full_text,
		"title_rendered_text": title_rendered_text,
		"title_full_width": font.get_string_size(title_full_text, HORIZONTAL_ALIGNMENT_LEFT, -1.0, 20).x if font != null else 0.0,
		"title_rendered_width": font.get_string_size(title_rendered_text, HORIZONTAL_ALIGNMENT_LEFT, -1.0, 20).x if font != null else 0.0,
		"full_text": full_text,
		"rendered_text": rendered_text,
		"full_width": font.get_string_size(full_text, HORIZONTAL_ALIGNMENT_LEFT, -1.0, 13).x if font != null else 0.0,
		"rendered_width": font.get_string_size(rendered_text, HORIZONTAL_ALIGNMENT_LEFT, -1.0, 13).x if font != null else 0.0,
		"study_action_count": _study_actions.size(),
		"market_action_count": _market_actions.size(),
		"garrison_company_count": _garrison_company_count(),
		"garrison_headcount": _garrison_headcount(),
		"max_width": max_width,
		"scene_rect": scene_rect,
	}

func _draw_haze(scene_rect: Rect2) -> void:
	for index in range(4):
		var radius := scene_rect.size.x * (0.20 + float(index) * 0.08)
		var center := scene_rect.position + Vector2(scene_rect.size.x * (0.20 + float(index) * 0.20), scene_rect.size.y * 0.22)
		draw_circle(center, radius, HAZE_COLOR)

func _draw_roads(ground_rect: Rect2) -> void:
	var center := ground_rect.position + Vector2(ground_rect.size.x * 0.50, ground_rect.size.y * 0.12)
	var left := Vector2(ground_rect.position.x + ground_rect.size.x * 0.20, ground_rect.end.y)
	var right := Vector2(ground_rect.position.x + ground_rect.size.x * 0.80, ground_rect.end.y)
	draw_polyline(PackedVector2Array([left, center, right]), ROAD_COLOR, 10.0)
	draw_polyline(
		PackedVector2Array([left + Vector2(0.0, 5.0), center + Vector2(0.0, 3.0), right + Vector2(0.0, 5.0)]),
		Color(0.73, 0.64, 0.48, 0.55),
		2.0
	)

func _draw_city(scene_rect: Rect2, ground_rect: Rect2) -> void:
	var accent := _accent_color()
	var wall_top := ground_rect.position.y - scene_rect.size.y * 0.16
	var wall_rect := Rect2(
		Vector2(scene_rect.position.x + scene_rect.size.x * 0.18, wall_top),
		Vector2(scene_rect.size.x * 0.64, scene_rect.size.y * 0.12)
	)
	draw_rect(wall_rect, STONE_COLOR, true)
	draw_rect(wall_rect, STONE_SHADOW, false, 2.0)

	var tower_count := 3 if OverworldRulesScript.town_strategic_role(_town) == "capital" else 2
	for index in range(tower_count + 1):
		var x := wall_rect.position.x + float(index) * (wall_rect.size.x / float(max(1, tower_count))) - 12.0
		var tower_rect := Rect2(Vector2(x, wall_rect.position.y - 44.0), Vector2(28.0, 88.0))
		draw_rect(tower_rect, STONE_COLOR.darkened(0.06), true)
		draw_rect(tower_rect, STONE_SHADOW, false, 2.0)
		var roof = PackedVector2Array([
			tower_rect.position + Vector2(-4.0, 0.0),
			tower_rect.position + Vector2(tower_rect.size.x * 0.5, -24.0),
			tower_rect.position + Vector2(tower_rect.size.x + 4.0, 0.0),
		])
		draw_colored_polygon(roof, accent.darkened(0.14))
		_draw_window_strip(tower_rect, 3)

	var gate_rect := Rect2(
		Vector2(wall_rect.position.x + wall_rect.size.x * 0.42, wall_rect.end.y - 30.0),
		Vector2(wall_rect.size.x * 0.16, 30.0)
	)
	draw_rect(gate_rect, Color(0.17, 0.11, 0.08, 0.96), true)
	draw_rect(gate_rect, accent, false, 2.0)

	var keep_rect := Rect2(
		Vector2(scene_rect.position.x + scene_rect.size.x * 0.40, wall_rect.position.y - 82.0),
		Vector2(scene_rect.size.x * 0.20, 84.0)
	)
	draw_rect(keep_rect, STONE_COLOR.lightened(0.06), true)
	draw_rect(keep_rect, STONE_SHADOW, false, 2.0)
	var keep_roof = PackedVector2Array([
		keep_rect.position + Vector2(-12.0, 0.0),
		keep_rect.position + Vector2(keep_rect.size.x * 0.5, -34.0),
		keep_rect.position + Vector2(keep_rect.size.x + 12.0, 0.0),
	])
	draw_colored_polygon(keep_roof, accent)
	_draw_window_strip(keep_rect, 4)

	var banner_xs := [keep_rect.position.x + 18.0, keep_rect.end.x - 18.0]
	for banner_x in banner_xs:
		draw_line(Vector2(banner_x, keep_rect.position.y + 8.0), Vector2(banner_x, keep_rect.position.y - 30.0), Color(0.93, 0.91, 0.84, 0.92), 2.0)
		var banner = PackedVector2Array([
			Vector2(banner_x, keep_rect.position.y - 28.0),
			Vector2(banner_x + 22.0, keep_rect.position.y - 22.0),
			Vector2(banner_x, keep_rect.position.y - 14.0),
		])
		draw_colored_polygon(banner, accent.lightened(0.08))

	var district_counts := _district_counts()
	var district_positions := [
		Vector2(scene_rect.position.x + scene_rect.size.x * 0.24, ground_rect.position.y - 36.0),
		Vector2(scene_rect.position.x + scene_rect.size.x * 0.33, ground_rect.position.y - 18.0),
		Vector2(scene_rect.position.x + scene_rect.size.x * 0.66, ground_rect.position.y - 20.0),
		Vector2(scene_rect.position.x + scene_rect.size.x * 0.74, ground_rect.position.y - 40.0),
	]
	for index in range(district_positions.size()):
		var district_key: String = String(DISTRICT_ORDER[index])
		var building_count := int(district_counts.get(district_key, 0))
		_draw_district_cluster(district_positions[index], building_count, DISTRICT_COLORS.get(district_key, accent))

	var guard_count := clampi(_garrison_company_count(), 0, 5)
	for index in range(guard_count):
		var guard_center := Vector2(
			wall_rect.position.x + 36.0 + float(index) * 20.0,
			wall_rect.end.y + 10.0
		)
		draw_circle(guard_center, 7.0, Color(0.92, 0.88, 0.72, 0.92))
		draw_circle(guard_center, 7.0, Color(0.11, 0.14, 0.18, 0.85), false, 2.0)

func _draw_window_strip(rect: Rect2, count: int) -> void:
	for index in range(count):
		var window_rect := Rect2(
			Vector2(rect.position.x + 8.0 + float(index % 2) * 10.0, rect.position.y + 18.0 + float(index / 2) * 18.0),
			Vector2(6.0, 10.0)
		)
		draw_rect(window_rect, WINDOW_GLOW, true)

func _draw_district_cluster(position: Vector2, strength: int, color: Color) -> void:
	var visible_houses := clampi(max(1, strength), 1, 4)
	for index in range(visible_houses):
		var offset := Vector2(float(index) * 18.0, -float(index % 2) * 12.0)
		var house_rect := Rect2(position + offset, Vector2(18.0, 14.0))
		draw_rect(house_rect, color.darkened(0.18), true)
		draw_rect(house_rect, Color(0.12, 0.14, 0.18, 0.82), false, 1.5)
		var roof = PackedVector2Array([
			house_rect.position + Vector2(-2.0, 0.0),
			house_rect.position + Vector2(house_rect.size.x * 0.5, -9.0),
			house_rect.position + Vector2(house_rect.size.x + 2.0, 0.0),
		])
		draw_colored_polygon(roof, color)
		draw_rect(Rect2(house_rect.position + Vector2(5.0, 5.0), Vector2(4.0, 5.0)), WINDOW_GLOW, true)

func _draw_status_plaques(scene_rect: Rect2) -> void:
	var plaques := _status_plaque_payloads()
	var plaque_rects := _status_plaque_rects(scene_rect, plaques.size())
	for index in range(plaques.size()):
		_draw_plaque(plaque_rects[index], plaques[index])

func _status_plaque_payloads() -> Array:
	var readiness := OverworldRulesScript.town_battle_readiness(_town, _session)
	var spell_tier := TownRulesScript.current_spell_tier(_town)
	var pressure := OverworldRulesScript.town_pressure_output(_town, _session)
	var disrupted := int(_logistics.get("disrupted_count", 0))
	return [
		{
			"title": "Guard",
			"value": "%d" % readiness,
			"color": Color(0.33, 0.60, 0.64, 0.95),
			"kind": "guard",
		},
		{
			"title": "Spell",
			"value": "Tier %d" % spell_tier,
			"color": Color(0.41, 0.54, 0.83, 0.95),
			"kind": "spell",
		},
		_contextual_front_plaque(pressure),
		{
			"title": "Routes",
			"value": "%d blocked" % disrupted,
			"color": Color(0.36, 0.66, 0.58, 0.95),
			"kind": "routes",
		},
	]

func _contextual_front_plaque(pressure: int) -> Dictionary:
	var occupation_active := bool(_occupation.get("active", false))
	var retake_active := bool(_front.get("active", false)) and String(_front.get("mode", "")) == "retake"
	var faction_label := _front_faction_label(_front)
	if occupation_active:
		var days_to_clear: int = max(1, int(_occupation.get("days_to_clear", 0)))
		return {
			"title": "Occupation",
			"value": "%dd | Retake" % days_to_clear if retake_active else "%dd pacify" % days_to_clear,
			"color": Color(0.78, 0.39, 0.27, 0.97),
			"kind": "occupation_retake" if retake_active else "occupation",
			"occupation_days_to_clear": days_to_clear,
			"retake_faction_id": String(_front.get("faction_id", "")) if retake_active else "",
		}
	if retake_active:
		return {
			"title": "Retake",
			"value": "%s +%d" % [faction_label, max(0, int(_front.get("pressure_bonus", 0)))],
			"color": Color(0.78, 0.39, 0.27, 0.97),
			"kind": "retake",
			"occupation_days_to_clear": 0,
			"retake_faction_id": String(_front.get("faction_id", "")),
		}
	return {
		"title": "Front",
		"value": "%d pressure" % pressure,
		"color": Color(0.75, 0.43, 0.30, 0.95),
		"kind": "pressure",
		"occupation_days_to_clear": 0,
		"retake_faction_id": "",
	}

func _front_faction_label(front: Dictionary) -> String:
	var faction_id := String(front.get("faction_id", ""))
	var faction_name := String(ContentService.get_faction(faction_id).get("name", "")).strip_edges()
	if faction_name != "":
		return faction_name.get_slice(" ", 0)
	var fallback := faction_id.trim_prefix("faction_").replace("_", " ").strip_edges()
	return fallback.capitalize() if fallback != "" else "Enemy"

func _status_plaque_rects(scene_rect: Rect2, plaque_count: int) -> Array:
	var rects := []
	if plaque_count <= 0:
		return rects
	var compact := _scenic_overlay_compact(scene_rect)
	var gap := 8.0 if compact else 10.0
	var side_margin := 12.0
	var preferred_width := 118.0 if compact else 132.0
	var plaque_width: float = min(preferred_width, (scene_rect.size.x - side_margin * 2.0 - gap * float(plaque_count - 1)) / float(plaque_count))
	var plaque_height := 40.0 if compact else 44.0
	for index in range(plaque_count):
		rects.append(Rect2(
			Vector2(scene_rect.position.x + side_margin + float(index) * (plaque_width + gap), scene_rect.position.y + 12.0),
			Vector2(plaque_width, plaque_height)
		))
	return rects

func _draw_plaque(rect: Rect2, data: Dictionary) -> void:
	var accent: Color = data.get("color", FRAME_COLOR)
	draw_rect(Rect2(rect.position + Vector2(2.0, 2.0), rect.size), SCENIC_GLASS_SHADOW, true)
	draw_rect(rect, SCENIC_GLASS_FILL, true)
	draw_rect(rect, SCENIC_GLASS_BORDER, false, 1.5)
	draw_rect(Rect2(rect.position, Vector2(STATUS_ACCENT_WIDTH, rect.size.y)), Color(accent.r, accent.g, accent.b, 0.92), true)
	_draw_text(String(data.get("title", "")), rect.position + Vector2(12.0, 16.0), Color(accent.r, accent.g, accent.b, 1.0).lightened(0.24), 11)
	_draw_text(String(data.get("value", "")), rect.position + Vector2(12.0, rect.size.y - 7.0), TEXT_COLOR, 14)

func _draw_district_strip(scene_rect: Rect2) -> void:
	var strip_rect := _district_strip_rect(scene_rect)
	var payloads := _district_strip_payloads()
	var card_rects := _district_card_rects(strip_rect, payloads.size())
	draw_rect(Rect2(strip_rect.position + Vector2(2.0, 2.0), strip_rect.size), SCENIC_GLASS_SHADOW, true)
	draw_rect(strip_rect, SCENIC_GLASS_FILL, true)
	draw_rect(strip_rect, SCENIC_GLASS_BORDER, false, 1.5)
	for index in range(payloads.size()):
		var payload: Dictionary = payloads[index] if payloads[index] is Dictionary else {}
		var card_rect: Rect2 = card_rects[index]
		var accent: Color = payload.get("color", FRAME_COLOR)
		draw_rect(card_rect, SCENIC_GLASS_CARD_FILL, true)
		draw_rect(card_rect, Color(accent.r, accent.g, accent.b, 0.50), false, 1.0)
		draw_rect(Rect2(card_rect.position, Vector2(card_rect.size.x, DISTRICT_ACCENT_HEIGHT)), Color(accent.r, accent.g, accent.b, 0.92), true)
		_draw_text(String(payload.get("label", "")), card_rect.position + Vector2(8.0, 16.0), Color(accent.r, accent.g, accent.b, 1.0).lightened(0.26), 10)
		_draw_text("%d" % int(payload.get("value", 0)), card_rect.position + Vector2(8.0, card_rect.size.y - 5.0), TEXT_COLOR, 15)

func _district_strip_payloads() -> Array:
	var payloads: Array = []
	var district_counts := _district_counts()
	for key_value in DISTRICT_ORDER:
		var key := String(key_value)
		payloads.append({
			"id": key,
			"label": String(DISTRICT_LABELS.get(key, key.to_upper())),
			"value": int(district_counts.get(key, 0)),
			"color": DISTRICT_COLORS.get(key, FRAME_COLOR),
		})
	return payloads

func _district_strip_rect(scene_rect: Rect2) -> Rect2:
	var compact := _scenic_overlay_compact(scene_rect)
	var height := 40.0 if compact else 44.0
	return Rect2(
		Vector2(scene_rect.position.x + 16.0, scene_rect.end.y - height - 14.0),
		Vector2(scene_rect.size.x - 32.0, height)
	)

func _district_card_rects(strip_rect: Rect2, card_count: int) -> Array:
	var rects: Array = []
	if card_count <= 0:
		return rects
	var gap := 6.0
	var inset := 7.0
	var card_width := (strip_rect.size.x - inset * 2.0 - gap * float(card_count - 1)) / float(card_count)
	for index in range(card_count):
		rects.append(Rect2(
			strip_rect.position + Vector2(inset + float(index) * (card_width + gap), 6.0),
			Vector2(card_width, strip_rect.size.y - 12.0)
		))
	return rects

func _scenic_overlay_compact(scene_rect: Rect2) -> bool:
	return scene_rect.size.x < 1000.0 or scene_rect.size.y < 520.0

func _draw_command_markers(scene_rect: Rect2) -> void:
	var rect := Rect2(
		Vector2(scene_rect.end.x - 174.0, scene_rect.position.y + 72.0),
		Vector2(156.0, 114.0)
	)
	draw_rect(rect, Color(0.15, 0.17, 0.20, 0.90), true)
	draw_rect(rect, FRAME_COLOR, false, 2.0)
	var lines := [
		"HEROES %d" % _stationed.size(),
		"BUILD %d" % _build_actions.size(),
		"RECRUIT %d" % _available_recruit_total(),
		"RESPONSE %d" % _response_actions.size(),
		"THREAT %d" % (int(_threat.get("visible_marching", 0)) + int(_threat.get("visible_pressuring", 0))),
	]
	for index in range(lines.size()):
		var y := rect.position.y + 18.0 + float(index) * 18.0
		draw_circle(Vector2(rect.position.x + 10.0, y - 4.0), 3.0, FRAME_COLOR)
		_draw_text(lines[index], Vector2(rect.position.x + 20.0, y), SUBTEXT_COLOR, 12)

func _draw_header(scene_rect: Rect2) -> void:
	var max_width := maxf(0.0, scene_rect.size.x - 36.0)
	var line := _fit_stage_header_text(_header_title_text(), max_width, 20)
	var label_y: float = minf(scene_rect.end.y - 104.0, scene_rect.position.y + scene_rect.size.y * 0.66)
	_draw_text(line, scene_rect.position + Vector2(18.0, label_y), TEXT_COLOR, 20)
	var subline := _fit_stage_header_text(_header_action_count_text(), max_width, 13)
	_draw_text(subline, scene_rect.position + Vector2(18.0, label_y + 22.0), SUBTEXT_COLOR, 13)

func _header_title_text() -> String:
	var title := String(_town_template.get("name", _town.get("town_id", "Town")))
	var role := OverworldRulesScript.town_strategic_role(_town).capitalize()
	return "%s | %s | %s" % [
		title,
		String(_faction.get("name", _town_template.get("faction_id", "Faction"))),
		role if role != "" else "Outpost",
	]

func _header_action_count_text() -> String:
	return "Garrison %d companies | %d troops | Study options %d | Market options %d" % [
		_garrison_company_count(),
		_garrison_headcount(),
		_study_actions.size(),
		_market_actions.size(),
	]

func _short_stage_text(text: String, max_chars: int) -> String:
	if text.length() <= max_chars:
		return text
	return "%s..." % text.left(max(0, max_chars - 3)).strip_edges()

func _fit_stage_header_text(text: String, max_width: float, font_size: int) -> String:
	var normalized := text.strip_edges()
	if normalized == "" or max_width <= 0.0:
		return ""
	var font = get_theme_default_font()
	if font == null or font_size <= 0:
		return normalized
	if font.get_string_size(normalized, HORIZONTAL_ALIGNMENT_LEFT, -1.0, font_size).x <= max_width:
		return normalized
	var ellipsis := "…"
	if font.get_string_size(ellipsis, HORIZONTAL_ALIGNMENT_LEFT, -1.0, font_size).x > max_width:
		return ""
	var prefix := ""
	for word_value in normalized.split(" ", false):
		var word := String(word_value)
		var candidate := word if prefix == "" else "%s %s" % [prefix, word]
		var candidate_with_ellipsis := "%s%s" % [candidate, ellipsis]
		if font.get_string_size(candidate_with_ellipsis, HORIZONTAL_ALIGNMENT_LEFT, -1.0, font_size).x > max_width:
			break
		prefix = candidate
	return "%s%s" % [prefix, ellipsis] if prefix != "" else ellipsis

func _accent_color() -> Color:
	return FACTION_COLORS.get(String(_town_template.get("faction_id", "")), Color(0.84, 0.67, 0.35, 1.0))

func _district_counts() -> Dictionary:
	var counts := {
		"military": 0,
		"economy": 0,
		"spellcraft": 0,
		"logistics": 0,
		"defense": 0,
	}
	for building_id_value in _town.get("built_buildings", []):
		var building := ContentService.get_building(String(building_id_value))
		var category := String(building.get("category", ""))
		if category == "":
			continue
		if not counts.has(category):
			counts[category] = 0
		counts[category] = int(counts.get(category, 0)) + 1
	return counts

func _garrison_company_count() -> int:
	var companies := 0
	for stack in _town.get("garrison", []):
		if stack is Dictionary and int(stack.get("count", 0)) > 0:
			companies += 1
	return companies

func _garrison_headcount() -> int:
	var total := 0
	for stack in _town.get("garrison", []):
		if stack is Dictionary:
			total += max(0, int(stack.get("count", 0)))
	return total

func _available_recruit_total() -> int:
	var total := 0
	for value in _town.get("available_recruits", {}).values():
		total += max(0, int(value))
	return total

func _draw_text(text: String, position: Vector2, color: Color, font_size: int) -> void:
	var font = get_theme_default_font()
	if font == null:
		return
	draw_string(font, position, text, HORIZONTAL_ALIGNMENT_LEFT, -1.0, font_size, color)
