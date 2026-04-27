class_name AnimationCueCatalog
extends RefCounted

const CATALOG_PATH := "res://content/animation_event_cues.json"
const SCHEMA_ID := "animation_event_cue_catalog_v1"
const REQUIRED_SURFACES := ["battle", "overworld", "town", "spell", "artifact", "ui"]
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
			var fallbacks: Dictionary = result.get("fallbacks", {}) if result.get("fallbacks", {}) is Dictionary else {}
			match mode:
				"reduced_motion":
					result["selected_fallback_tag"] = String(fallbacks.get("reduced_motion_tag", ""))
				"fast":
					result["selected_fallback_tag"] = String(fallbacks.get("fast_mode_tag", ""))
				_:
					result["selected_fallback_tag"] = ""
			return result
	return {}

static func _entries(catalog: Dictionary) -> Array:
	var entries = catalog.get("entries", [])
	return entries if entries is Array else []

static func _required_representative_events() -> Array:
	return [
		"battle_unit_move",
		"battle_unit_melee_attack",
		"battle_unit_hit",
		"battle_unit_death",
		"battle_unit_cast",
		"battle_status_applied",
		"battle_unit_defend",
		"overworld_object_visited",
		"overworld_object_captured",
		"overworld_object_depleted",
		"overworld_route_blocked",
		"overworld_route_open",
		"overworld_route_closed",
		"overworld_object_ambient",
		"town_building_built",
		"town_units_recruited",
		"spell_cast_battle",
		"spell_effect_damage",
		"artifact_acquired",
		"artifact_equipped",
		"ui_invalid_action",
	]

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
