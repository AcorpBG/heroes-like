class_name AnimationCueCatalog
extends RefCounted

const CATALOG_PATH := "res://content/animation_event_cues.json"
const SCHEMA_ID := "animation_event_cue_catalog_v1"
const PREFERENCE_POLICY_SCHEMA_ID := "animation_playback_preference_policy_v1"
const MODE_NORMAL := "normal"
const MODE_REDUCED_MOTION := "reduced_motion"
const MODE_FAST := "fast"
const MODE_REDUCED_MOTION_FAST := "reduced_motion_fast"
const REQUIRED_SURFACES := ["battle", "overworld", "town", "spell", "artifact", "ui"]
const BATTLE_TROOP_STATE_CONTRACT_SCHEMA_ID := "battle_troop_sprite_state_contract_v1"
const OVERWORLD_OBJECT_STATE_CONTRACT_SCHEMA_ID := "overworld_object_state_contract_v1"
const BATTLE_TROOP_REQUIRED_STATE_FAMILIES := [
	"idle",
	"ready",
	"move",
	"attack",
	"hit",
	"death",
	"cast",
	"status",
	"defend",
	"retreat",
]
const OVERWORLD_OBJECT_REQUIRED_STATE_FAMILIES := [
	"idle",
	"active",
	"visited",
	"depleted",
	"captured",
	"blocked",
	"guarded",
	"route-open",
	"route-closed",
	"ambient-loop",
]
const BATTLE_TROOP_REPRESENTATIVE_EVENTS := {
	"idle": "battle_stack_idle",
	"ready": "battle_stack_ready",
	"move": "battle_unit_move",
	"attack": "battle_unit_melee_attack",
	"hit": "battle_unit_hit",
	"death": "battle_unit_death",
	"cast": "battle_unit_cast",
	"status": "battle_status_applied",
	"defend": "battle_unit_defend",
	"retreat": "battle_unit_retreat",
}
const OVERWORLD_OBJECT_REPRESENTATIVE_EVENTS := {
	"idle": "overworld_object_idle",
	"active": "overworld_object_active",
	"visited": "overworld_object_visited",
	"depleted": "overworld_object_depleted",
	"captured": "overworld_object_captured",
	"blocked": "overworld_object_blocked",
	"guarded": "overworld_object_guarded",
	"route-open": "overworld_route_open",
	"route-closed": "overworld_route_closed",
	"ambient-loop": "overworld_object_ambient",
}
const REQUIRED_FIELDS := [
	"event_id",
	"cue_id",
	"surface",
	"subject_kind",
	"animation_state_family",
	"animation_state",
	"playback_policy",
	"blocking_policy",
	"vfx_cue_ids",
	"audio_cue_ids",
	"fallbacks",
	"validation_tags",
	"producer_refs",
]
const FALLBACK_FIELDS := ["reduced_motion_tag", "fast_mode_tag"]
const REPRESENTATIVE_POLICY_EVENTS := [
	"battle_unit_move",
	"battle_unit_melee_attack",
	"battle_unit_hit",
	"battle_unit_death",
	"overworld_object_visited",
	"overworld_object_captured",
	"overworld_object_depleted",
	"overworld_route_blocked",
	"overworld_object_ambient",
	"town_building_built",
	"spell_cast_battle",
	"artifact_equipped",
	"ui_invalid_action",
]

static func load_catalog() -> Dictionary:
	return ContentService.load_json(CATALOG_PATH)

static func event_cue_catalog_report(catalog: Dictionary = {}) -> Dictionary:
	var source := catalog if not catalog.is_empty() else load_catalog()
	var entries := _entries(source)
	var errors := []
	var warnings := []
	var event_ids := []
	var cue_ids := []
	var surface_counts := {}
	var state_family_counts := {}
	var playback_policy_counts := {}
	var blocking_policy_counts := {}
	var validation_tag_counts := {}
	var fallback_counts := {"reduced_motion": 0, "fast_mode": 0}
	var placeholder_counts := {"vfx": 0, "audio": 0}
	var producer_ref_count := 0

	if String(source.get("schema_id", "")) != SCHEMA_ID:
		errors.append("Catalog schema_id must be %s." % SCHEMA_ID)

	var runtime_policy: Dictionary = source.get("runtime_policy", {}) if source.get("runtime_policy", {}) is Dictionary else {}
	for blocked_policy in ["save_version_bump", "final_sprite_import", "final_vfx_import", "final_audio_import", "renderer_asset_pipeline", "playback_runtime", "broad_ui_polish"]:
		if bool(runtime_policy.get(blocked_policy, true)):
			errors.append("Runtime policy must keep %s disabled for this slice." % blocked_policy)

	for entry_value in entries:
		if not (entry_value is Dictionary):
			errors.append("Catalog contains a non-dictionary entry.")
			continue
		var entry: Dictionary = entry_value
		var event_id := String(entry.get("event_id", "")).strip_edges()
		var cue_id := String(entry.get("cue_id", "")).strip_edges()
		var surface := String(entry.get("surface", "")).strip_edges()
		var state_family := String(entry.get("animation_state_family", "")).strip_edges()
		var playback_policy := String(entry.get("playback_policy", "")).strip_edges()
		var blocking_policy := String(entry.get("blocking_policy", "")).strip_edges()

		for field in REQUIRED_FIELDS:
			if not entry.has(field):
				errors.append("%s is missing required field %s." % [event_id if event_id != "" else "<entry>", field])
		if event_id == "":
			errors.append("Catalog entry has an empty event_id.")
		elif event_id in event_ids:
			errors.append("Catalog repeats event_id %s." % event_id)
		else:
			event_ids.append(event_id)
		if cue_id == "":
			errors.append("%s has an empty cue_id." % event_id)
		elif cue_id in cue_ids:
			errors.append("Catalog repeats cue_id %s." % cue_id)
		else:
			cue_ids.append(cue_id)
		if surface not in REQUIRED_SURFACES:
			errors.append("%s uses unsupported surface %s." % [event_id, surface])
		_increment(surface_counts, surface)
		_increment(state_family_counts, state_family)
		_increment(playback_policy_counts, playback_policy)
		_increment(blocking_policy_counts, blocking_policy)

		var fallbacks: Dictionary = entry.get("fallbacks", {}) if entry.get("fallbacks", {}) is Dictionary else {}
		for fallback_field in FALLBACK_FIELDS:
			var fallback_value := String(fallbacks.get(fallback_field, "")).strip_edges()
			if fallback_value == "":
				errors.append("%s missing fallback %s." % [event_id, fallback_field])
		if String(fallbacks.get("reduced_motion_tag", "")).strip_edges() != "":
			fallback_counts["reduced_motion"] = int(fallback_counts.get("reduced_motion", 0)) + 1
		if String(fallbacks.get("fast_mode_tag", "")).strip_edges() != "":
			fallback_counts["fast_mode"] = int(fallback_counts.get("fast_mode", 0)) + 1

		var vfx_ids := _string_array(entry.get("vfx_cue_ids", []))
		var audio_ids := _string_array(entry.get("audio_cue_ids", []))
		if vfx_ids.is_empty():
			errors.append("%s must define at least one VFX cue id or placeholder." % event_id)
		if audio_ids.is_empty():
			errors.append("%s must define at least one audio cue id or placeholder." % event_id)
		for vfx_id in vfx_ids:
			if String(vfx_id).begins_with("vfx_placeholder_"):
				placeholder_counts["vfx"] = int(placeholder_counts.get("vfx", 0)) + 1
		for audio_id in audio_ids:
			if String(audio_id).begins_with("audio_placeholder_"):
				placeholder_counts["audio"] = int(placeholder_counts.get("audio", 0)) + 1

		var validation_tags := _string_array(entry.get("validation_tags", []))
		if validation_tags.is_empty():
			errors.append("%s must define validation_tags." % event_id)
		for tag in validation_tags:
			_increment(validation_tag_counts, tag)
		var producer_refs := _string_array(entry.get("producer_refs", []))
		if producer_refs.is_empty():
			errors.append("%s must define producer_refs." % event_id)
		producer_ref_count += producer_refs.size()
		if not bool(entry.get("skippable", false)):
			warnings.append("%s is not skippable; confirm this before playback runtime adoption." % event_id)

	for surface in REQUIRED_SURFACES:
		if int(surface_counts.get(surface, 0)) <= 0:
			errors.append("Catalog has no entries for required surface %s." % surface)
	for required_event in _required_representative_events():
		if required_event not in event_ids:
			errors.append("Catalog is missing representative event %s." % required_event)
	for required_tag in ["battle", "overworld", "town", "spell", "artifact", "ui", "resolved_event"]:
		if int(validation_tag_counts.get(required_tag, 0)) <= 0:
			errors.append("Catalog is missing validation tag %s." % required_tag)
	if int(state_family_counts.get("move", 0)) <= 0 or int(state_family_counts.get("captured", 0)) <= 0:
		errors.append("Catalog must include battle move and overworld capture state families.")
	if int(fallback_counts.get("reduced_motion", 0)) != entries.size() or int(fallback_counts.get("fast_mode", 0)) != entries.size():
		errors.append("Every catalog entry must define reduced-motion and fast-mode fallback tags.")

	var public_payload := {
		"schema_id": String(source.get("schema_id", "")),
		"schema_status": String(source.get("schema_status", "")),
		"entry_count": entries.size(),
		"surface_counts": surface_counts,
		"state_family_counts": state_family_counts,
		"playback_policy_counts": playback_policy_counts,
		"blocking_policy_counts": blocking_policy_counts,
		"fallback_counts": fallback_counts,
		"placeholder_counts": placeholder_counts,
		"producer_ref_count": producer_ref_count,
		"runtime_policy": runtime_policy,
		"warnings": warnings,
		"errors": errors,
	}
	return {
		"ok": errors.is_empty(),
		"schema_id": SCHEMA_ID,
		"schema_status": "animation_event_cue_catalog_contract_validated",
		"entry_count": entries.size(),
		"event_ids": event_ids,
		"surface_counts": surface_counts,
		"state_family_counts": state_family_counts,
		"playback_policy_counts": playback_policy_counts,
		"blocking_policy_counts": blocking_policy_counts,
		"validation_tag_counts": validation_tag_counts,
		"fallback_counts": fallback_counts,
		"placeholder_counts": placeholder_counts,
		"producer_ref_count": producer_ref_count,
		"runtime_policy": runtime_policy,
		"warnings": warnings,
		"errors": errors,
		"public_payload": public_payload,
	}

static func cue_for_event(event_id: String, mode: String = "normal", catalog: Dictionary = {}) -> Dictionary:
	var normalized_event_id := String(event_id).strip_edges()
	if normalized_event_id == "":
		return {}
	var source := catalog if not catalog.is_empty() else load_catalog()
	for entry_value in _entries(source):
		if entry_value is Dictionary and String(entry_value.get("event_id", "")) == normalized_event_id:
			var result: Dictionary = entry_value.duplicate(true)
			var policy := cue_playback_policy_for_event(normalized_event_id, _preferences_from_mode(mode), source)
			result["selected_fallback_tag"] = String(policy.get("selected_fallback_tag", ""))
			result["selected_mode"] = String(policy.get("mode", MODE_NORMAL))
			result["selected_animation_state"] = String(policy.get("selected_animation_state", result.get("animation_state", "")))
			result["selected_playback_policy"] = String(policy.get("selected_playback_policy", result.get("playback_policy", "")))
			result["selected_blocking_policy"] = String(policy.get("selected_blocking_policy", result.get("blocking_policy", "")))
			return result
	return {}

static func normalize_animation_preferences(preferences: Dictionary = {}) -> Dictionary:
	var accessibility: Dictionary = preferences.get("accessibility", {}) if preferences.get("accessibility", {}) is Dictionary else {}
	var gameplay: Dictionary = preferences.get("gameplay", {}) if preferences.get("gameplay", {}) is Dictionary else {}
	var animation: Dictionary = preferences.get("animation", {}) if preferences.get("animation", {}) is Dictionary else {}
	var reduced_motion := bool(preferences.get("reduced_motion", preferences.get("reduce_motion", accessibility.get("reduce_motion", accessibility.get("reduced_motion", false)))))
	var fast_mode := bool(preferences.get("fast_mode", preferences.get("fast_resolution", gameplay.get("fast_mode", animation.get("fast_mode", false)))))
	var mode_hint := String(preferences.get("mode", preferences.get("speed_mode", ""))).strip_edges()
	match mode_hint:
		MODE_REDUCED_MOTION:
			reduced_motion = true
			fast_mode = false
		MODE_FAST, "fast_mode":
			fast_mode = true
			reduced_motion = false
		MODE_REDUCED_MOTION_FAST, "combined":
			reduced_motion = true
			fast_mode = true
		MODE_NORMAL:
			reduced_motion = false
			fast_mode = false

	var mode := MODE_NORMAL
	if reduced_motion and fast_mode:
		mode = MODE_REDUCED_MOTION_FAST
	elif reduced_motion:
		mode = MODE_REDUCED_MOTION
	elif fast_mode:
		mode = MODE_FAST

	return {
		"schema_id": PREFERENCE_POLICY_SCHEMA_ID,
		"mode": mode,
		"reduced_motion": reduced_motion,
		"fast_mode": fast_mode,
		"visual_fallback_preference": "reduced_motion_tag" if reduced_motion else ("fast_mode_tag" if fast_mode else "animation_state"),
		"timing_preference": MODE_FAST if fast_mode else MODE_NORMAL,
		"combined_policy": "reduced_motion_visual_fast_timing" if reduced_motion and fast_mode else "single_preference",
		"duration_scale": 0.35 if fast_mode else 1.0,
		"max_duration_ms": 180 if fast_mode else (260 if reduced_motion else 700),
		"allows_large_motion": not reduced_motion,
		"allows_camera_motion": not reduced_motion,
		"allows_loop_motion": not reduced_motion,
		"allows_strong_flash": not reduced_motion,
		"audio_policy": "placeholder_cues_allowed_no_final_import",
	}

static func cue_playback_policy_for_event(event_id: String, preferences: Dictionary = {}, catalog: Dictionary = {}) -> Dictionary:
	var entry := _entry_for_event(event_id, catalog if not catalog.is_empty() else load_catalog())
	if entry.is_empty():
		return {}
	return _cue_playback_policy_for_entry(entry, normalize_animation_preferences(preferences))

static func animation_preference_policy_report(catalog: Dictionary = {}) -> Dictionary:
	var source := catalog if not catalog.is_empty() else load_catalog()
	var catalog_report := event_cue_catalog_report(source)
	var errors := []
	if not bool(catalog_report.get("ok", false)):
		errors.append_array(catalog_report.get("errors", []))

	var preference_cases := {
		MODE_NORMAL: {},
		MODE_REDUCED_MOTION: {"reduced_motion": true},
		MODE_FAST: {"fast_mode": true},
		MODE_REDUCED_MOTION_FAST: {"reduced_motion": true, "fast_mode": true},
	}
	var selected_cases := {}
	var covered_surfaces := {}
	var covered_subjects := {}
	var reduced_motion_policy_count := 0
	var fast_mode_policy_count := 0
	var combined_policy_count := 0
	var troop_policy_count := 0
	var object_policy_count := 0

	for event_id in REPRESENTATIVE_POLICY_EVENTS:
		var entry := _entry_for_event(event_id, source)
		if entry.is_empty():
			errors.append("Policy report missing representative event %s." % event_id)
			continue
		var event_cases := {}
		for mode in preference_cases.keys():
			var selected := _cue_playback_policy_for_entry(entry, normalize_animation_preferences(preference_cases[mode]))
			event_cases[mode] = _public_policy_case(selected)
			if String(mode) == MODE_REDUCED_MOTION and String(selected.get("selected_fallback_tag", "")) == String(entry.get("fallbacks", {}).get("reduced_motion_tag", "")):
				reduced_motion_policy_count += 1
			if String(mode) == MODE_FAST and String(selected.get("selected_fallback_tag", "")) == String(entry.get("fallbacks", {}).get("fast_mode_tag", "")):
				fast_mode_policy_count += 1
			if String(mode) == MODE_REDUCED_MOTION_FAST and String(selected.get("selected_fallback_tag", "")) == String(entry.get("fallbacks", {}).get("reduced_motion_tag", "")) and String(selected.get("timing_preference", "")) == MODE_FAST:
				combined_policy_count += 1
		selected_cases[event_id] = event_cases
		_increment(covered_surfaces, String(entry.get("surface", "")))
		_increment(covered_subjects, String(entry.get("subject_kind", "")))
		if String(entry.get("subject_kind", "")) == "troop_stack":
			troop_policy_count += 1
		if String(entry.get("subject_kind", "")) == "map_object":
			object_policy_count += 1

	if troop_policy_count < 4:
		errors.append("Policy report must cover multiple battle troop cues.")
	if object_policy_count < 4:
		errors.append("Policy report must cover multiple overworld map object cues.")
	for surface in REQUIRED_SURFACES:
		if int(covered_surfaces.get(surface, 0)) <= 0:
			errors.append("Policy report must cover surface %s." % surface)
	var representative_count := REPRESENTATIVE_POLICY_EVENTS.size()
	if reduced_motion_policy_count != representative_count:
		errors.append("Reduced-motion policy did not select reduced fallbacks for every representative cue.")
	if fast_mode_policy_count != representative_count:
		errors.append("Fast-mode policy did not select fast fallbacks for every representative cue.")
	if combined_policy_count != representative_count:
		errors.append("Combined reduced-motion/fast policy must use reduced visual fallback with fast timing.")

	var runtime_policy: Dictionary = source.get("runtime_policy", {}) if source.get("runtime_policy", {}) is Dictionary else {}
	var public_payload := {
		"schema_id": PREFERENCE_POLICY_SCHEMA_ID,
		"schema_status": "animation_preference_policy_validated",
		"representative_event_count": representative_count,
		"covered_surfaces": covered_surfaces,
		"covered_subjects": covered_subjects,
		"reduced_motion_policy_count": reduced_motion_policy_count,
		"fast_mode_policy_count": fast_mode_policy_count,
		"combined_policy_count": combined_policy_count,
		"runtime_policy": runtime_policy,
		"selected_cases": selected_cases,
		"errors": errors,
	}
	return {
		"ok": errors.is_empty(),
		"schema_id": PREFERENCE_POLICY_SCHEMA_ID,
		"schema_status": "animation_preference_policy_validated",
		"representative_event_count": representative_count,
		"covered_surfaces": covered_surfaces,
		"covered_subjects": covered_subjects,
		"troop_policy_count": troop_policy_count,
		"object_policy_count": object_policy_count,
		"reduced_motion_policy_count": reduced_motion_policy_count,
		"fast_mode_policy_count": fast_mode_policy_count,
		"combined_policy_count": combined_policy_count,
		"runtime_policy": runtime_policy,
		"selected_cases": selected_cases,
		"errors": errors,
		"public_payload": public_payload,
	}

static func battle_troop_sprite_state_contract_report(catalog: Dictionary = {}) -> Dictionary:
	var source := catalog if not catalog.is_empty() else load_catalog()
	var catalog_report := event_cue_catalog_report(source)
	var errors := []
	if not bool(catalog_report.get("ok", false)):
		errors.append_array(catalog_report.get("errors", []))

	var battle_entries := []
	var family_counts := {}
	var representative_events := {}
	var representative_policy_cases := {}
	var producer_ref_count := 0
	var fallback_counts := {"reduced_motion": 0, "fast_mode": 0}

	for entry_value in _entries(source):
		if not (entry_value is Dictionary):
			continue
		var entry: Dictionary = entry_value
		if String(entry.get("surface", "")) != "battle" or String(entry.get("subject_kind", "")) != "troop_stack":
			continue
		battle_entries.append(entry)
		var state_family := String(entry.get("animation_state_family", ""))
		_increment(family_counts, state_family)
		var producer_refs := _string_array(entry.get("producer_refs", []))
		producer_ref_count += producer_refs.size()
		var fallbacks: Dictionary = entry.get("fallbacks", {}) if entry.get("fallbacks", {}) is Dictionary else {}
		if String(fallbacks.get("reduced_motion_tag", "")).strip_edges() != "":
			fallback_counts["reduced_motion"] = int(fallback_counts.get("reduced_motion", 0)) + 1
		if String(fallbacks.get("fast_mode_tag", "")).strip_edges() != "":
			fallback_counts["fast_mode"] = int(fallback_counts.get("fast_mode", 0)) + 1

	for family in BATTLE_TROOP_REQUIRED_STATE_FAMILIES:
		var event_id := String(BATTLE_TROOP_REPRESENTATIVE_EVENTS.get(family, ""))
		var entry := _entry_for_event(event_id, source)
		if entry.is_empty():
			errors.append("Battle troop state family %s missing representative event %s." % [family, event_id])
			continue
		if String(entry.get("surface", "")) != "battle":
			errors.append("%s must use battle surface." % event_id)
		if String(entry.get("subject_kind", "")) != "troop_stack":
			errors.append("%s must use troop_stack subject_kind." % event_id)
		if String(entry.get("animation_state_family", "")) != family:
			errors.append("%s must map to state family %s." % [event_id, family])
		var tags := _string_array(entry.get("validation_tags", []))
		for required_tag in ["battle", "troop_state", "resolved_event"]:
			if required_tag not in tags:
				errors.append("%s missing validation tag %s." % [event_id, required_tag])
		if _string_array(entry.get("producer_refs", [])).is_empty():
			errors.append("%s must define battle producer_refs." % event_id)
		var fallbacks: Dictionary = entry.get("fallbacks", {}) if entry.get("fallbacks", {}) is Dictionary else {}
		if String(fallbacks.get("reduced_motion_tag", "")).strip_edges() == "":
			errors.append("%s missing reduced-motion fallback tag." % event_id)
		if String(fallbacks.get("fast_mode_tag", "")).strip_edges() == "":
			errors.append("%s missing fast-mode fallback tag." % event_id)
		if not bool(entry.get("skippable", false)):
			errors.append("%s must stay skippable until playback runtime adoption." % event_id)
		representative_events[family] = event_id

		var policy_cases := {}
		for mode in [MODE_NORMAL, MODE_REDUCED_MOTION, MODE_FAST, MODE_REDUCED_MOTION_FAST]:
			var policy := _cue_playback_policy_for_entry(entry, normalize_animation_preferences(_preferences_from_mode(mode)))
			policy_cases[mode] = _public_policy_case(policy)
			if String(policy.get("selected_animation_state", "")).strip_edges() == "":
				errors.append("%s produced an empty selected animation state for %s mode." % [event_id, mode])
		var reduced_policy: Dictionary = policy_cases.get(MODE_REDUCED_MOTION, {})
		var fast_policy: Dictionary = policy_cases.get(MODE_FAST, {})
		var combined_policy: Dictionary = policy_cases.get(MODE_REDUCED_MOTION_FAST, {})
		if String(reduced_policy.get("selected_fallback_tag", "")) != String(fallbacks.get("reduced_motion_tag", "")):
			errors.append("%s reduced-motion policy did not select the reduced fallback." % event_id)
		if String(fast_policy.get("selected_fallback_tag", "")) != String(fallbacks.get("fast_mode_tag", "")):
			errors.append("%s fast-mode policy did not select the fast fallback." % event_id)
		if String(combined_policy.get("selected_fallback_tag", "")) != String(fallbacks.get("reduced_motion_tag", "")) or String(combined_policy.get("timing_preference", "")) != MODE_FAST:
			errors.append("%s combined policy must use reduced visuals with fast timing." % event_id)
		representative_policy_cases[event_id] = policy_cases

	for family in BATTLE_TROOP_REQUIRED_STATE_FAMILIES:
		if int(family_counts.get(family, 0)) <= 0:
			errors.append("Battle troop catalog has no entries for required state family %s." % family)

	var public_payload := {
		"schema_id": BATTLE_TROOP_STATE_CONTRACT_SCHEMA_ID,
		"schema_status": "battle_troop_sprite_state_contract_validated",
		"required_state_families": BATTLE_TROOP_REQUIRED_STATE_FAMILIES,
		"representative_events": representative_events,
		"battle_troop_entry_count": battle_entries.size(),
		"state_family_counts": family_counts,
		"fallback_counts": fallback_counts,
		"producer_ref_count": producer_ref_count,
		"policy_cases": representative_policy_cases,
		"runtime_policy": source.get("runtime_policy", {}) if source.get("runtime_policy", {}) is Dictionary else {},
		"errors": errors,
	}
	return {
		"ok": errors.is_empty(),
		"schema_id": BATTLE_TROOP_STATE_CONTRACT_SCHEMA_ID,
		"schema_status": "battle_troop_sprite_state_contract_validated",
		"required_state_families": BATTLE_TROOP_REQUIRED_STATE_FAMILIES,
		"representative_events": representative_events,
		"battle_troop_entry_count": battle_entries.size(),
		"state_family_counts": family_counts,
		"fallback_counts": fallback_counts,
		"producer_ref_count": producer_ref_count,
		"policy_cases": representative_policy_cases,
		"runtime_policy": source.get("runtime_policy", {}) if source.get("runtime_policy", {}) is Dictionary else {},
		"errors": errors,
		"public_payload": public_payload,
	}

static func overworld_object_state_contract_report(catalog: Dictionary = {}) -> Dictionary:
	var source := catalog if not catalog.is_empty() else load_catalog()
	var catalog_report := event_cue_catalog_report(source)
	var errors := []
	if not bool(catalog_report.get("ok", false)):
		errors.append_array(catalog_report.get("errors", []))

	var object_entries := []
	var town_shared_entries := []
	var family_counts := {}
	var subject_counts := {}
	var representative_events := {}
	var representative_policy_cases := {}
	var producer_ref_count := 0
	var fallback_counts := {"reduced_motion": 0, "fast_mode": 0}

	for entry_value in _entries(source):
		if not (entry_value is Dictionary):
			continue
		var entry: Dictionary = entry_value
		var surface := String(entry.get("surface", ""))
		var subject := String(entry.get("subject_kind", ""))
		var family := String(entry.get("animation_state_family", ""))
		if surface == "overworld" and subject in ["map_object", "resource_site", "route"]:
			object_entries.append(entry)
			_increment(family_counts, family)
			_increment(subject_counts, subject)
			var producer_refs := _string_array(entry.get("producer_refs", []))
			producer_ref_count += producer_refs.size()
			var fallbacks: Dictionary = entry.get("fallbacks", {}) if entry.get("fallbacks", {}) is Dictionary else {}
			if String(fallbacks.get("reduced_motion_tag", "")).strip_edges() != "":
				fallback_counts["reduced_motion"] = int(fallback_counts.get("reduced_motion", 0)) + 1
			if String(fallbacks.get("fast_mode_tag", "")).strip_edges() != "":
				fallback_counts["fast_mode"] = int(fallback_counts.get("fast_mode", 0)) + 1
		elif surface == "town" and subject == "town" and family in ["captured", "visited"]:
			town_shared_entries.append(entry)

	for family in OVERWORLD_OBJECT_REQUIRED_STATE_FAMILIES:
		var event_id := String(OVERWORLD_OBJECT_REPRESENTATIVE_EVENTS.get(family, ""))
		var entry := _entry_for_event(event_id, source)
		if entry.is_empty():
			errors.append("Overworld object state family %s missing representative event %s." % [family, event_id])
			continue
		if String(entry.get("surface", "")) != "overworld":
			errors.append("%s must use overworld surface." % event_id)
		var subject_kind := String(entry.get("subject_kind", ""))
		if subject_kind not in ["map_object", "resource_site", "route"]:
			errors.append("%s must use map_object, resource_site, or route subject_kind." % event_id)
		if String(entry.get("animation_state_family", "")) != family:
			errors.append("%s must map to state family %s." % [event_id, family])
		var tags := _string_array(entry.get("validation_tags", []))
		for required_tag in _overworld_object_required_tags_for_family(family):
			if required_tag not in tags:
				errors.append("%s missing validation tag %s." % [event_id, required_tag])
		if _string_array(entry.get("producer_refs", [])).is_empty():
			errors.append("%s must define overworld producer_refs." % event_id)
		var fallbacks: Dictionary = entry.get("fallbacks", {}) if entry.get("fallbacks", {}) is Dictionary else {}
		if String(fallbacks.get("reduced_motion_tag", "")).strip_edges() == "":
			errors.append("%s missing reduced-motion fallback tag." % event_id)
		if String(fallbacks.get("fast_mode_tag", "")).strip_edges() == "":
			errors.append("%s missing fast-mode fallback tag." % event_id)
		if not bool(entry.get("skippable", false)):
			errors.append("%s must stay skippable until playback runtime adoption." % event_id)
		representative_events[family] = event_id

		var policy_cases := {}
		for mode in [MODE_NORMAL, MODE_REDUCED_MOTION, MODE_FAST, MODE_REDUCED_MOTION_FAST]:
			var policy := _cue_playback_policy_for_entry(entry, normalize_animation_preferences(_preferences_from_mode(mode)))
			policy_cases[mode] = _public_policy_case(policy)
			if String(policy.get("selected_animation_state", "")).strip_edges() == "":
				errors.append("%s produced an empty selected animation state for %s mode." % [event_id, mode])
		var reduced_policy: Dictionary = policy_cases.get(MODE_REDUCED_MOTION, {})
		var fast_policy: Dictionary = policy_cases.get(MODE_FAST, {})
		var combined_policy: Dictionary = policy_cases.get(MODE_REDUCED_MOTION_FAST, {})
		if String(reduced_policy.get("selected_fallback_tag", "")) != String(fallbacks.get("reduced_motion_tag", "")):
			errors.append("%s reduced-motion policy did not select the reduced fallback." % event_id)
		if String(fast_policy.get("selected_fallback_tag", "")) != String(fallbacks.get("fast_mode_tag", "")):
			errors.append("%s fast-mode policy did not select the fast fallback." % event_id)
		if String(combined_policy.get("selected_fallback_tag", "")) != String(fallbacks.get("reduced_motion_tag", "")) or String(combined_policy.get("timing_preference", "")) != MODE_FAST:
			errors.append("%s combined policy must use reduced visuals with fast timing." % event_id)
		representative_policy_cases[event_id] = policy_cases

	for family in OVERWORLD_OBJECT_REQUIRED_STATE_FAMILIES:
		if int(family_counts.get(family, 0)) <= 0:
			errors.append("Overworld object catalog has no entries for required state family %s." % family)
	for subject in ["map_object", "resource_site"]:
		if int(subject_counts.get(subject, 0)) <= 0:
			errors.append("Overworld object contract must include subject_kind %s." % subject)
	if town_shared_entries.is_empty():
		errors.append("Overworld object contract must include a shared town object-state hook.")
	if fallback_counts["reduced_motion"] != object_entries.size() or fallback_counts["fast_mode"] != object_entries.size():
		errors.append("Overworld object entries must all define reduced-motion and fast-mode fallbacks.")

	var content_context := _overworld_object_content_context_report()
	var content_classes: Dictionary = content_context.get("object_class_counts", {})
	for required_class in ["pickup", "mine", "neutral_dwelling", "guarded_reward_site", "transit_object", "blocker", "faction_landmark"]:
		if int(content_classes.get(required_class, 0)) <= 0:
			errors.append("Overworld object content is missing representative class %s." % required_class)

	var public_payload := {
		"schema_id": OVERWORLD_OBJECT_STATE_CONTRACT_SCHEMA_ID,
		"schema_status": "overworld_object_state_contract_validated",
		"required_state_families": OVERWORLD_OBJECT_REQUIRED_STATE_FAMILIES,
		"representative_events": representative_events,
		"overworld_object_entry_count": object_entries.size(),
		"town_shared_entry_count": town_shared_entries.size(),
		"state_family_counts": family_counts,
		"subject_counts": subject_counts,
		"fallback_counts": fallback_counts,
		"producer_ref_count": producer_ref_count,
		"content_context": content_context,
		"policy_cases": representative_policy_cases,
		"runtime_policy": source.get("runtime_policy", {}) if source.get("runtime_policy", {}) is Dictionary else {},
		"errors": errors,
	}
	return {
		"ok": errors.is_empty(),
		"schema_id": OVERWORLD_OBJECT_STATE_CONTRACT_SCHEMA_ID,
		"schema_status": "overworld_object_state_contract_validated",
		"required_state_families": OVERWORLD_OBJECT_REQUIRED_STATE_FAMILIES,
		"representative_events": representative_events,
		"overworld_object_entry_count": object_entries.size(),
		"town_shared_entry_count": town_shared_entries.size(),
		"state_family_counts": family_counts,
		"subject_counts": subject_counts,
		"fallback_counts": fallback_counts,
		"producer_ref_count": producer_ref_count,
		"content_context": content_context,
		"policy_cases": representative_policy_cases,
		"runtime_policy": source.get("runtime_policy", {}) if source.get("runtime_policy", {}) is Dictionary else {},
		"errors": errors,
		"public_payload": public_payload,
	}

static func _entries(catalog: Dictionary) -> Array:
	var entries = catalog.get("entries", [])
	return entries if entries is Array else []

static func _entry_for_event(event_id: String, catalog: Dictionary) -> Dictionary:
	var normalized_event_id := String(event_id).strip_edges()
	if normalized_event_id == "":
		return {}
	for entry_value in _entries(catalog):
		if entry_value is Dictionary and String(entry_value.get("event_id", "")) == normalized_event_id:
			return entry_value
	return {}

static func _cue_playback_policy_for_entry(entry: Dictionary, preferences: Dictionary) -> Dictionary:
	var fallbacks: Dictionary = entry.get("fallbacks", {}) if entry.get("fallbacks", {}) is Dictionary else {}
	var reduced_motion := bool(preferences.get("reduced_motion", false))
	var fast_mode := bool(preferences.get("fast_mode", false))
	var selected_fallback_tag := ""
	var selected_animation_state := String(entry.get("animation_state", ""))
	var visual_policy := "authored_animation_state"
	if reduced_motion:
		selected_fallback_tag = String(fallbacks.get("reduced_motion_tag", ""))
		selected_animation_state = selected_fallback_tag
		visual_policy = "reduced_motion_fallback"
	elif fast_mode:
		selected_fallback_tag = String(fallbacks.get("fast_mode_tag", ""))
		selected_animation_state = selected_fallback_tag
		visual_policy = "fast_mode_fallback"

	var selected_blocking_policy := String(entry.get("blocking_policy", ""))
	if fast_mode and selected_blocking_policy in ["input_blocking_timeout", "inherits_source"]:
		selected_blocking_policy = "nonblocking_fast_resolve"
	elif reduced_motion and selected_blocking_policy == "input_blocking_timeout":
		selected_blocking_policy = "nonblocking_reduced_motion"

	var selected_vfx_ids := _string_array(entry.get("vfx_cue_ids", []))
	var selected_audio_ids := _string_array(entry.get("audio_cue_ids", []))
	if reduced_motion:
		selected_vfx_ids = [selected_fallback_tag] if selected_fallback_tag != "" else []
	elif fast_mode:
		selected_vfx_ids = [selected_fallback_tag] if selected_fallback_tag != "" else []

	return {
		"schema_id": PREFERENCE_POLICY_SCHEMA_ID,
		"mode": String(preferences.get("mode", MODE_NORMAL)),
		"event_id": String(entry.get("event_id", "")),
		"cue_id": String(entry.get("cue_id", "")),
		"surface": String(entry.get("surface", "")),
		"subject_kind": String(entry.get("subject_kind", "")),
		"animation_state_family": String(entry.get("animation_state_family", "")),
		"base_animation_state": String(entry.get("animation_state", "")),
		"selected_animation_state": selected_animation_state,
		"selected_fallback_tag": selected_fallback_tag,
		"selected_visual_policy": visual_policy,
		"selected_playback_policy": "fast_resolve" if fast_mode else String(entry.get("playback_policy", "")),
		"selected_blocking_policy": selected_blocking_policy,
		"skippable": true if fast_mode else bool(entry.get("skippable", false)),
		"duration_scale": float(preferences.get("duration_scale", 1.0)),
		"max_duration_ms": int(preferences.get("max_duration_ms", 700)),
		"allows_large_motion": bool(preferences.get("allows_large_motion", true)),
		"allows_camera_motion": bool(preferences.get("allows_camera_motion", true)),
		"allows_loop_motion": bool(preferences.get("allows_loop_motion", true)),
		"allows_strong_flash": bool(preferences.get("allows_strong_flash", true)),
		"audio_policy": String(preferences.get("audio_policy", "")),
		"timing_preference": String(preferences.get("timing_preference", MODE_NORMAL)),
		"combined_policy": String(preferences.get("combined_policy", "single_preference")),
		"selected_vfx_cue_ids": selected_vfx_ids,
		"selected_audio_cue_ids": selected_audio_ids,
		"validation_tags": _string_array(entry.get("validation_tags", [])),
	}

static func _public_policy_case(policy: Dictionary) -> Dictionary:
	return {
		"event_id": String(policy.get("event_id", "")),
		"surface": String(policy.get("surface", "")),
		"subject_kind": String(policy.get("subject_kind", "")),
		"mode": String(policy.get("mode", MODE_NORMAL)),
		"selected_animation_state": String(policy.get("selected_animation_state", "")),
		"selected_fallback_tag": String(policy.get("selected_fallback_tag", "")),
		"selected_visual_policy": String(policy.get("selected_visual_policy", "")),
		"selected_playback_policy": String(policy.get("selected_playback_policy", "")),
		"selected_blocking_policy": String(policy.get("selected_blocking_policy", "")),
		"timing_preference": String(policy.get("timing_preference", MODE_NORMAL)),
		"combined_policy": String(policy.get("combined_policy", "")),
		"max_duration_ms": int(policy.get("max_duration_ms", 0)),
	}

static func _preferences_from_mode(mode: String) -> Dictionary:
	match String(mode).strip_edges():
		MODE_REDUCED_MOTION:
			return {"reduced_motion": true}
		MODE_FAST, "fast_mode":
			return {"fast_mode": true}
		MODE_REDUCED_MOTION_FAST, "combined":
			return {"reduced_motion": true, "fast_mode": true}
		_:
			return {}

static func _required_representative_events() -> Array:
	return [
		"battle_stack_idle",
		"battle_stack_ready",
		"battle_unit_move",
		"battle_unit_melee_attack",
		"battle_unit_hit",
		"battle_unit_death",
		"battle_unit_cast",
		"battle_status_applied",
		"battle_unit_defend",
		"battle_unit_retreat",
		"overworld_object_visited",
		"overworld_object_captured",
		"overworld_object_depleted",
		"overworld_object_blocked",
		"overworld_object_guarded",
		"overworld_route_blocked",
		"overworld_route_open",
		"overworld_route_closed",
		"overworld_object_ambient",
		"town_captured",
		"town_building_built",
		"town_units_recruited",
		"spell_cast_battle",
		"spell_effect_damage",
		"artifact_acquired",
		"artifact_equipped",
		"ui_invalid_action",
	]

static func _overworld_object_required_tags_for_family(family: String) -> Array:
	var tags := ["overworld", "object_state", String(family)]
	if family != "idle" and family != "active" and family != "ambient-loop":
		tags.append("resolved_event")
	if family == "ambient-loop":
		tags.append("reduced_motion_loop")
	return tags

static func _overworld_object_content_context_report() -> Dictionary:
	var map_objects := ContentService.load_json("res://content/map_objects.json")
	var resource_sites := ContentService.load_json("res://content/resource_sites.json")
	var object_class_counts := {}
	var linked_resource_site_count := 0
	var guarded_site_count := 0
	var persistent_site_count := 0
	var repeatable_site_count := 0
	for object_value in _items_from_content(map_objects):
		if not (object_value is Dictionary):
			continue
		var object: Dictionary = object_value
		var family := String(object.get("family", "")).strip_edges()
		_increment(object_class_counts, family)
		if String(object.get("resource_site_id", "")).strip_edges() != "":
			linked_resource_site_count += 1
	for site_value in _items_from_content(resource_sites):
		if not (site_value is Dictionary):
			continue
		var site: Dictionary = site_value
		var control_income: Dictionary = site.get("control_income", {}) if site.get("control_income", {}) is Dictionary else {}
		if bool(site.get("guarded", false)):
			guarded_site_count += 1
		if bool(site.get("persistent", false)) or not control_income.is_empty():
			persistent_site_count += 1
		if bool(site.get("repeatable", false)) or int(site.get("refresh_days", 0)) > 0:
			repeatable_site_count += 1
	return {
		"object_class_counts": object_class_counts,
		"linked_resource_site_count": linked_resource_site_count,
		"guarded_site_count": guarded_site_count,
		"persistent_site_count": persistent_site_count,
		"repeatable_site_count": repeatable_site_count,
	}

static func _items_from_content(content: Variant) -> Array:
	if content is Array:
		return content
	if content is Dictionary:
		var items = content.get("items", [])
		return items if items is Array else []
	return []

static func _string_array(value: Variant) -> Array:
	var result := []
	if not (value is Array):
		return result
	for item in value:
		var text := String(item).strip_edges()
		if text != "" and text not in result:
			result.append(text)
	return result

static func _increment(counts: Dictionary, key: String) -> void:
	var normalized := String(key).strip_edges()
	if normalized == "":
		normalized = "<empty>"
	counts[normalized] = int(counts.get(normalized, 0)) + 1
