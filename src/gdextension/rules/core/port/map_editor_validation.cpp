// MapEditorShell's rules (Phase 7, slice 7.13): the authoring validation and its memo, guard links,
// labels, role flags, density and the fallback
// classifications.

#include "aurelion_rules/port/map_editor.hpp"

#include "aurelion_rules/port/ai_port.hpp"
#include "aurelion_rules/port/overworld_rules_move.hpp"
#include "aurelion_rules/port/session_view.hpp"

#include <string>
#include <vector>

namespace aurelion::rules::port::map_editor {

namespace {

using gd::array_value;
using gd::bool_value;
using gd::dict_value;
using gd::int_value;
using gd::str;
using state::ContentTable;
using state::Kind;
namespace key = state::key;

// MapEditorShell.EDITOR_DENSITY_REGION_SIZE.
constexpr int64_t kEditorDensityRegionSize = 16;

// [OBJECT_FAMILY_TOWN, OBJECT_FAMILY_RESOURCE, OBJECT_FAMILY_ARTIFACT, OBJECT_FAMILY_ENCOUNTER].
constexpr Atom kPlacementFamilies[] = {key::town, key::resource, key::artifact, key::encounter};

// String(x): stringify(), and the engine's for a float, a container or an object.
Atom string_of(State &state, const Value &value) {
	switch (value.kind) {
		case Kind::Nil:
		case Kind::Bool:
		case Kind::Int:
		case Kind::String:
		case Kind::StringName:
			return gd::stringify(state, value);
		default:
			return gd::engine_str(state, value);
	}
}

// String(d.get(name, fallback)).
Atom text_of(State &state, DictRef dict, Atom name, Atom fallback = key::empty) {
	return string_of(state, state.get(dict, str(name), str(fallback)));
}

// String(d.get(name, "")).strip_edges().
Atom stripped(State &state, DictRef dict, Atom name) {
	return gd::strip_edges(state, text_of(state, dict, name));
}

// What `for x in value` visits, copied: the loop bodies make calls that add
// nodes or reach the engine.
std::vector<Value> listed(State &state, const Value &value) {
	const gd::Items items = gd::items(state, value);
	return std::vector<Value>(items.begin(), items.end());
}

// d.get(name, {}) or d.get(name, []) passed on: the value, or the new container
// GDScript makes when the key is missing.
Value field_or_new_dict(State &state, DictRef dict, Atom name) {
	Value found;
	if (state.lookup(dict, str(name), found)) {
		return found;
	}
	return dict_value(state.new_dict());
}
Value field_or_new_array(State &state, DictRef dict, Atom name) {
	Value found;
	if (state.lookup(dict, str(name), found)) {
		return found;
	}
	return array_value(state.new_array());
}

// separator.join(strings) of an Array of Strings.
Atom join_array(State &state, Atom separator, ArrayRef strings) {
	std::string joined;
	const int64_t count = state.array_size(strings);
	for (int64_t index = 0; index < count; ++index) {
		if (index > 0) {
			joined += state.text(separator);
		}
		joined += state.text(gd::to_string(state.at(strings, index)));
	}
	return state.intern(joined);
}

// _session.overworld.
DictRef session_overworld(State &state, const Value &editor) {
	return port::session_view::overworld(state, session_view(state, session(state, editor)));
}

// The guard_link a neutral_encounter metadata value holds, as
// _guard_link_for_editor reads it: `if metadata is Dictionary: guard =
// metadata.get("guard_link", {}); if guard is Dictionary: return guard`.
// metadata: the value, or none when the key is missing (GDScript's {} then).
bool metadata_guard_link(State &state, bool present, const Value &metadata, DictRef &guard) {
	if (!present) {
		guard = state.new_dict();
		return true;
	}
	if (!gd::is_dict(metadata)) {
		return false;
	}
	Value found;
	if (!state.lookup(metadata.ref, str(key::guard_link), found)) {
		guard = state.new_dict();
		return true;
	}
	if (gd::is_dict(found)) {
		guard = found.ref;
		return true;
	}
	return false;
}

// {"group": group, "band": band, "target": target, "note": note}.
DictRef density_guidance(State &state, Atom group, Atom band, Atom target, Atom note) {
	const DictRef guidance = state.new_dict();
	state.set(guidance, str(key::group), str(group));
	state.set(guidance, str(key::band), str(band));
	state.set(guidance, str(key::target), str(target));
	state.set(guidance, str(key::note), str(note));
	return guidance;
}

// An Array literal of Strings.
ArrayRef string_array(State &state, std::initializer_list<Atom> texts) {
	const ArrayRef array = state.new_array();
	for (const Atom text : texts) {
		state.append(array, str(text));
	}
	return array;
}

} // namespace

DictRef _scenario_authoring_validation_payload(State &state, const Value &editor) {
	// Returns a memoised payload shared by every caller in the same edit revision;
	// callers must not mutate it.
	if (session(state, editor).kind == Kind::Nil) {
		return state.new_dict();
	}
	const Value memo = _editor_validation_memo_lookup(state, editor, key::scenario_authoring_validation);
	if (gd::is_dict(memo)) {
		return memo.ref;
	}
	const DictRef payload = _build_scenario_authoring_validation_payload(state, editor);
	const DictRef validation_memo = gd::as_dict(gd::member(state, editor, key::_editor_validation_memo));
	state.set(validation_memo, str(key::scenario_authoring_validation), dict_value(payload));
	return payload;
}

DictRef _build_scenario_authoring_validation_payload(State &state, const Value &editor) {
	const DictRef placement_ids = _all_current_placement_ids(state, editor);
	const ArrayRef objective_anchors = state.new_array();
	const ArrayRef missing_objective_anchors = state.new_array();
	const ArrayRef covered_objective_anchors = state.new_array();
	const DictRef objectives = _editor_scenario_objectives(state, editor);
	if (!gd::is_empty(state, objectives)) {
		for (const Atom bucket : {key::victory, key::defeat}) {
			Value objective_bucket;
			if (!state.lookup(objectives, str(bucket), objective_bucket)) {
				continue;
			}
			if (!gd::is_array(objective_bucket)) {
				continue;
			}
			for (const Value &objective : listed(state, objective_bucket)) {
				if (!gd::is_dict(objective)) {
					continue;
				}
				const Atom placement_id = text_of(state, objective.ref, key::placement_id);
				if (placement_id == key::empty) {
					continue;
				}
				const DictRef entry = state.new_dict();
				state.set(entry, str(key::id), str(text_of(state, objective.ref, key::id)));
				state.set(entry, str(key::bucket), str(bucket));
				state.set(entry, str(key::type), str(text_of(state, objective.ref, key::type)));
				state.set(entry, str(key::placement_id), str(placement_id));
				const Value label_fallback = state.get(objective.ref, str(key::id), str(key::Objective));
				state.set(entry, str(key::label), str(string_of(state, state.get(objective.ref, str(key::label), label_fallback))));
				state.set(entry, str(key::covered), bool_value(state.has(placement_ids, str(placement_id))));
				state.append(objective_anchors, dict_value(entry));
				if (gd::bool_field(state, entry, key::covered, false)) {
					state.append(covered_objective_anchors, dict_value(entry));
				} else {
					state.append(missing_objective_anchors, dict_value(entry));
				}
			}
		}
	}
	const ArrayRef guard_warnings = state.new_array();
	const DictRef overworld = session_overworld(state, editor);
	Value encounters;
	if (state.lookup(overworld, str(key::encounters), encounters)) {
		for (const Value &encounter : listed(state, encounters)) {
			if (!gd::is_dict(encounter)) {
				continue;
			}
			const DictRef guard = _guard_link_for_editor(state, editor, encounter.ref);
			if (gd::is_empty(state, guard)) {
				continue;
			}
			const Atom guard_role = text_of(state, guard, key::guard_role);
			if (guard_role == key::empty || guard_role == key::none) {
				continue;
			}
			if (!_guard_target_present_for_editor(state, editor, guard)) {
				const DictRef warning = state.new_dict();
				state.set(warning, str(key::placement_id), str(text_of(state, encounter.ref, key::placement_id)));
				state.set(warning, str(key::warning), str(gd::format(state, key::guard_target_is_missing_s, {str(_guard_target_label_for_editor(state, editor, guard))})));
				state.append(guard_warnings, dict_value(warning));
			}
		}
	}
	const ArrayRef warning_lines = state.new_array();
	for (const Value &missing : listed(state, array_value(missing_objective_anchors))) {
		if (gd::is_dict(missing)) {
			state.append(warning_lines, str(gd::format(state, key::missing_objective_anchor_s, {str(text_of(state, missing.ref, key::placement_id))})));
		}
	}
	for (const Value &warning : listed(state, array_value(guard_warnings))) {
		if (gd::is_dict(warning)) {
			state.append(warning_lines, str(text_of(state, warning.ref, key::warning)));
		}
	}
	const int64_t covered_count = state.array_size(covered_objective_anchors);
	const int64_t missing_count = state.array_size(missing_objective_anchors);
	const int64_t anchor_count = state.array_size(objective_anchors);
	const int64_t warning_count = state.array_size(warning_lines);
	const DictRef payload = state.new_dict();
	state.set(payload, str(key::objective_anchors), array_value(objective_anchors));
	state.set(payload, str(key::covered_objective_anchors), array_value(covered_objective_anchors));
	state.set(payload, str(key::missing_objective_anchors), array_value(missing_objective_anchors));
	state.set(payload, str(key::covered_objective_anchor_count), int_value(covered_count));
	state.set(payload, str(key::missing_objective_anchor_count), int_value(missing_count));
	state.set(payload, str(key::guard_warnings), array_value(guard_warnings));
	state.set(payload, str(key::warning_count), int_value(warning_count));
	state.set(payload, str(key::warnings), array_value(warning_lines));
	state.set(payload, str(key::summary), str(gd::format(state, key::objectives_d_d_covered_warnings_d, {int_value(covered_count), int_value(anchor_count), int_value(warning_count)})));
	return payload;
}

DictRef _all_current_placement_ids(State &state, const Value &editor) {
	const DictRef ids = state.new_dict();
	if (session(state, editor).kind == Kind::Nil) {
		return ids;
	}
	for (const Atom family : kPlacementFamilies) {
		const DictRef overworld = session_overworld(state, editor);
		Value placements;
		if (!state.lookup(overworld, str(_placement_array_key(state, editor, family)), placements)) {
			continue;
		}
		if (!gd::is_array(placements)) {
			continue;
		}
		for (const Value &placement : listed(state, placements)) {
			if (gd::is_dict(placement)) {
				const Atom placement_id = text_of(state, placement.ref, key::placement_id);
				if (placement_id != key::empty) {
					state.set(ids, str(placement_id), bool_value(true));
				}
			}
		}
	}
	return ids;
}

DictRef _guard_link_for_detail(State &state, const Value &editor, DictRef detail) {
	if (text_of(state, detail, key::kind) != key::encounter) {
		return state.new_dict();
	}
	const Atom placement_id = text_of(state, detail, key::placement_id);
	const DictRef overworld = session_overworld(state, editor);
	Value encounters;
	if (state.lookup(overworld, str(key::encounters), encounters)) {
		for (const Value &encounter : listed(state, encounters)) {
			if (gd::is_dict(encounter) && text_of(state, encounter.ref, key::placement_id) == placement_id) {
				return _guard_link_for_editor(state, editor, encounter.ref);
			}
		}
	}
	return state.new_dict();
}

DictRef _guard_link_for_editor(State &state, const Value &editor, DictRef encounter) {
	(void)editor;
	Value guard;
	if (state.lookup(encounter, str(key::guard_link), guard) && gd::is_dict(guard) && !gd::is_empty(state, guard.ref)) {
		return guard.ref;
	}
	DictRef found = 0;
	Value metadata;
	bool present = state.lookup(encounter, str(key::neutral_encounter), metadata);
	if (metadata_guard_link(state, present, metadata, found)) {
		return found;
	}
	const DictRef map_object = gd::content_row(state, ContentTable::MapObject, text_of(state, encounter, key::object_id));
	present = state.lookup(map_object, str(key::neutral_encounter), metadata);
	if (metadata_guard_link(state, present, metadata, found)) {
		return found;
	}
	return state.new_dict();
}

bool _guard_target_present_for_editor(State &state, const Value &editor, DictRef guard) {
	const Atom target_kind = text_of(state, guard, key::target_kind);
	if (target_kind == key::route) {
		return text_of(state, guard, key::target_id) != key::empty;
	}
	const Atom target_placement_id = text_of(state, guard, key::target_placement_id);
	if (target_placement_id != key::empty) {
		return _placement_id_exists(state, editor, target_placement_id);
	}
	const Atom target_id = text_of(state, guard, key::target_id);
	if (target_id == key::empty) {
		return false;
	}
	for (const Atom family : kPlacementFamilies) {
		const DictRef overworld = session_overworld(state, editor);
		Value placements;
		if (!state.lookup(overworld, str(_placement_array_key(state, editor, family)), placements)) {
			continue;
		}
		if (!gd::is_array(placements)) {
			continue;
		}
		const Atom content_key = _placement_content_key(state, editor, family);
		for (const Value &placement : listed(state, placements)) {
			if (!gd::is_dict(placement)) {
				continue;
			}
			if (text_of(state, placement.ref, key::placement_id) == target_id || (content_key != key::empty && text_of(state, placement.ref, content_key) == target_id)) {
				return true;
			}
		}
	}
	return false;
}

Atom _guard_target_label_for_editor(State &state, const Value &editor, DictRef guard) {
	const Atom target_placement_id = text_of(state, guard, key::target_placement_id);
	if (target_placement_id != key::empty) {
		return _placement_label_for_editor(state, editor, target_placement_id);
	}
	const Atom target_id = text_of(state, guard, key::target_id);
	if (target_id == key::empty) {
		return _humanize_editor_id(state, editor, text_of(state, guard, key::target_kind, key::target));
	}
	if (text_of(state, guard, key::target_kind) == key::route) {
		return gd::format(state, key::route_s_2, {str(target_id)});
	}
	const Atom placement_label = _placement_label_for_editor(state, editor, target_id);
	return placement_label != key::empty ? placement_label : target_id;
}

Atom _placement_label_for_editor(State &state, const Value &editor, Atom placement_id) {
	if (placement_id == key::empty) {
		return key::empty;
	}
	for (const Atom family : kPlacementFamilies) {
		// _session.overworld.get(_placement_array_key(family), []) if _session != null else []
		if (session(state, editor).kind == Kind::Nil) {
			continue;
		}
		const DictRef overworld = session_overworld(state, editor);
		Value placements;
		if (!state.lookup(overworld, str(_placement_array_key(state, editor, family)), placements)) {
			continue;
		}
		if (!gd::is_array(placements)) {
			continue;
		}
		for (const Value &placement : listed(state, placements)) {
			if (gd::is_dict(placement) && text_of(state, placement.ref, key::placement_id) == placement_id) {
				const DictRef detail = _object_detail_for_placement(state, editor, family, placement.ref);
				const Atom name = text_of(state, detail, key::name);
				return name != key::empty ? gd::format(state, key::phrase_with_steps_text, {str(name), str(placement_id)}) : placement_id;
			}
		}
	}
	return _humanize_editor_id(state, editor, placement_id);
}

Atom _effect_label_for_editor(State &state, const Value &editor, DictRef effect) {
	const Atom effect_type = text_of(state, effect, key::type);
	if (effect_type == key::spawn_resource_node) {
		const Value placement = field_or_new_dict(state, effect, key::placement);
		if (gd::is_dict(placement)) {
			const DictRef site = gd::content_row(state, ContentTable::ResourceSite, text_of(state, placement.ref, key::site_id));
			const Value name_fallback = state.get(placement.ref, str(key::placement_id), str(key::resource));
			return gd::format(state, key::spawns_s, {str(string_of(state, state.get(site, str(key::name), name_fallback)))});
		}
	} else if (effect_type == key::spawn_encounter) {
		const Value encounter_placement = field_or_new_dict(state, effect, key::placement);
		if (gd::is_dict(encounter_placement)) {
			const DictRef encounter = gd::content_row(state, ContentTable::Encounter, text_of(state, encounter_placement.ref, key::encounter_id));
			const Value name_fallback = state.get(encounter_placement.ref, str(key::placement_id), str(key::encounter));
			return gd::format(state, key::spawns_s, {str(string_of(state, state.get(encounter, str(key::name), name_fallback)))});
		}
	} else if (effect_type == key::add_resources) {
		const Value resources = field_or_new_dict(state, effect, key::resources);
		return gd::is_dict(resources) ? gd::format(state, key::grants_s, {str(_resource_delta_text(state, editor, resources.ref))}) : Atom(key::grants_resources);
	} else if (effect_type == key::award_experience) {
		return gd::format(state, key::grants_d_experience, {int_value(gd::int_field(state, effect, key::amount, 0))});
	} else if (effect_type == key::town_add_recruits) {
		return gd::format(state, key::adds_recruits_to_s, {str(_placement_label_for_editor(state, editor, text_of(state, effect, key::placement_id)))});
	}
	return _humanize_editor_id(state, editor, effect_type);
}

DictRef _placement_role_flags(State &state, const Value &editor, DictRef payload) {
	const Atom primary_class = stripped(state, payload, key::primary_class);
	const Atom object_family = stripped(state, payload, key::object_family);
	const Atom site_family = stripped(state, payload, key::site_family);
	const ArrayRef tags = _string_array_for_editor(state, editor, field_or_new_array(state, payload, key::secondary_tags));
	const auto has_tag = [&](Atom tag) { return gd::array_has(state, tags, str(tag)); };
	bool economy = primary_class == key::persistent_economy_site_2 || primary_class == key::mine || primary_class == key::resource_front;
	economy = economy || site_family == key::mine || has_tag(key::resource_front) || has_tag(key::income) || has_tag(key::build_resource);
	bool reward = primary_class == key::pickup || primary_class == key::artifact_reward || primary_class == key::guarded_reward_site;
	reward = reward || has_tag(key::small_reward) || has_tag(key::guarded_reward) || has_tag(key::hero_progression);
	bool transit = primary_class == key::transit_route_object || primary_class == key::transit_object;
	transit = transit || site_family == key::transit_object || has_tag(key::road_control) || has_tag(key::conditional_route) || has_tag(key::water_route_control);
	bool neutral = primary_class == key::neutral_dwelling || primary_class == key::neutral_encounter;
	neutral = neutral || object_family == key::neutral_dwelling || object_family == key::neutral_encounter || site_family == key::neutral_dwelling || has_tag(key::neutral_recruit_source);
	bool faction_landmark = primary_class == key::faction_landmark;
	faction_landmark = faction_landmark || site_family == key::faction_outpost || has_tag(key::faction_pressure) || has_tag(key::faction_presence);
	const DictRef flags = state.new_dict();
	state.set(flags, str(key::economy), bool_value(economy));
	state.set(flags, str(key::reward), bool_value(reward));
	state.set(flags, str(key::transit), bool_value(transit));
	state.set(flags, str(key::neutral), bool_value(neutral));
	state.set(flags, str(key::faction_landmark), bool_value(faction_landmark));
	return flags;
}

Atom _role_flags_text(State &state, const Value &editor, DictRef flags) {
	(void)editor;
	const ArrayRef labels = state.new_array();
	if (gd::bool_field(state, flags, key::economy, false)) {
		state.append(labels, str(key::economy));
	}
	if (gd::bool_field(state, flags, key::reward, false)) {
		state.append(labels, str(key::reward));
	}
	if (gd::bool_field(state, flags, key::transit, false)) {
		state.append(labels, str(key::transit));
	}
	if (gd::bool_field(state, flags, key::neutral, false)) {
		state.append(labels, str(key::neutral));
	}
	if (gd::bool_field(state, flags, key::faction_landmark, false)) {
		state.append(labels, str(key::faction_landmark_2));
	}
	return state.array_size(labels) != 0 ? join_array(state, key::comma_space, labels) : Atom(key::general);
}

Atom _placement_role_label(State &state, const Value &editor, DictRef payload, DictRef flags) {
	const Atom primary_class = stripped(state, payload, key::primary_class);
	if (primary_class == key::town) {
		return key::town_anchor_2;
	}
	if (primary_class == key::neutral_dwelling) {
		return key::neutral_recruit_source_2;
	}
	if (primary_class == key::neutral_encounter) {
		return key::guard_or_route_threat;
	}
	if (gd::bool_field(state, flags, key::transit, false) && gd::bool_field(state, flags, key::economy, false)) {
		return key::route_economy_control;
	}
	if (gd::bool_field(state, flags, key::transit, false)) {
		return key::route_control;
	}
	if (gd::bool_field(state, flags, key::faction_landmark, false)) {
		return key::faction_landmark_3;
	}
	if (gd::bool_field(state, flags, key::economy, false) && gd::bool_field(state, flags, key::reward, false)) {
		return key::resource_reward_pacing;
	}
	if (gd::bool_field(state, flags, key::economy, false)) {
		return key::economy_pressure;
	}
	if (gd::bool_field(state, flags, key::reward, false)) {
		return key::reward_pacing;
	}
	return _humanize_editor_id(state, editor, primary_class);
}

DictRef _density_guidance_for_payload(State &state, const Value &editor, DictRef payload, DictRef flags) {
	(void)editor;
	const Atom primary_class = stripped(state, payload, key::primary_class);
	const Atom site_family = stripped(state, payload, key::site_family);
	if (primary_class == key::town) {
		return density_guidance(state, key::town_anchor, key::town_influence, key::leave_town_breathing_room, key::keep_nearby_lanes_and_approach_tiles);
	}
	if (primary_class == key::neutral_encounter) {
		return density_guidance(state, key::guard_encounter, key::standard_adventure, key::n2_4_guards_encounters_per_16x16, key::use_to_guard_lanes_rewards_or);
	}
	if (primary_class == key::guarded_reward_site) {
		return density_guidance(state, key::guarded_reward, key::ruin_reward_pocket, key::n2_4_guarded_sites_per_16x16, key::pair_with_visible_danger_and_clear);
	}
	if (primary_class == key::neutral_dwelling || site_family == key::neutral_dwelling) {
		return density_guidance(state, key::interactable, key::standard_adventure, key::n3_5_interactables_per_16x16, key::leave_gate_approach_space_and_show);
	}
	if (gd::bool_field(state, flags, key::transit, false) || site_family == key::transit_object) {
		return density_guidance(state, key::economy_transit, key::contested_economy, key::n4_7_economy_transit_sites_per, key::place_on_junctions_chokepoints_or_route);
	}
	if (gd::bool_field(state, flags, key::faction_landmark, false)) {
		return density_guidance(state, key::faction_landmark, key::town_influence, key::n1_3_landmarks_per_16x16, key::use_near_faction_fronts_or_territory);
	}
	if (gd::bool_field(state, flags, key::economy, false) && !gd::bool_field(state, flags, key::reward, false)) {
		return density_guidance(state, key::economy_transit, key::contested_economy, key::n4_7_economy_transit_sites_per, key::make_resource_fronts_contestable_and_route);
	}
	if (gd::bool_field(state, flags, key::reward, false)) {
		return density_guidance(state, key::pickup_reward, key::standard_adventure, key::n4_7_pickups_rewards_per_16x16, key::use_on_side_routes_and_reward);
	}
	return density_guidance(state, key::interactable, key::standard_adventure, key::n3_5_interactables_per_16x16, key::mix_with_scenery_and_negative_space);
}

int64_t _local_density_count(State &state, const Value &editor, Vector2i tile, Atom density_group) {
	if (density_group == key::empty || session(state, editor).kind == Kind::Nil) {
		return 0;
	}
	const DictRef bounds = _density_region_bounds(state, editor, tile);
	int64_t count = 0;
	for (const Atom family : kPlacementFamilies) {
		const DictRef overworld = session_overworld(state, editor);
		Value placements;
		if (!state.lookup(overworld, str(_placement_array_key(state, editor, family)), placements)) {
			continue;
		}
		if (!gd::is_array(placements)) {
			continue;
		}
		for (const Value &placement : listed(state, placements)) {
			if (!gd::is_dict(placement)) {
				continue;
			}
			const Vector2i object_tile = Vector2i::of(gd::int_field(state, placement.ref, key::x, -999), gd::int_field(state, placement.ref, key::y, -999));
			if (object_tile.x < gd::int_field(state, bounds, key::min_x, 0) || object_tile.x > gd::int_field(state, bounds, key::max_x, 0)) {
				continue;
			}
			if (object_tile.y < gd::int_field(state, bounds, key::min_y, 0) || object_tile.y > gd::int_field(state, bounds, key::max_y, 0)) {
				continue;
			}
			if (_density_group_for_placement(state, editor, family, placement.ref) == density_group) {
				count += 1;
			}
		}
	}
	return count;
}

DictRef _density_region_bounds(State &state, const Value &editor, Vector2i tile) {
	const Value current = session(state, editor);
	const Vector2i map_size = current.kind != Kind::Nil ? overworld_rules::derive_map_size(state, session_view(state, current)) : Vector2i{};
	const int64_t min_x = compat::float_to_int(compat::godot_floor(static_cast<double>(tile.x) / static_cast<double>(kEditorDensityRegionSize))) * kEditorDensityRegionSize;
	const int64_t min_y = compat::float_to_int(compat::godot_floor(static_cast<double>(tile.y) / static_cast<double>(kEditorDensityRegionSize))) * kEditorDensityRegionSize;
	const DictRef bounds = state.new_dict();
	state.set(bounds, str(key::min_x), int_value(min_x));
	state.set(bounds, str(key::min_y), int_value(min_y));
	state.set(bounds, str(key::max_x), int_value(compat::engine_min<int64_t>(static_cast<int64_t>(map_size.x) - 1, min_x + kEditorDensityRegionSize - 1)));
	state.set(bounds, str(key::max_y), int_value(compat::engine_min<int64_t>(static_cast<int64_t>(map_size.y) - 1, min_y + kEditorDensityRegionSize - 1)));
	state.set(bounds, str(key::size), int_value(kEditorDensityRegionSize));
	return bounds;
}

Atom _density_group_for_placement(State &state, const Value &editor, Atom family, DictRef placement) {
	if (family == key::town) {
		return key::town_anchor;
	}
	if (family == key::artifact) {
		return key::pickup_reward;
	}
	if (family == key::resource) {
		const DictRef site = gd::content_row(state, ContentTable::ResourceSite, text_of(state, placement, key::site_id));
		const Value site_id_fallback = state.get(placement, str(key::site_id), str(key::empty));
		const Atom site_id = string_of(state, state.get(site, str(key::id), site_id_fallback));
		const DictRef map_object = gd::content_row(state, ContentTable::MapObjectForResourceSite, site_id);
		Atom primary_class = stripped(state, map_object, key::primary_class);
		if (primary_class == key::empty) {
			primary_class = _fallback_resource_primary_class(state, editor, site);
		}
		ArrayRef secondary_tags = _string_array_for_editor(state, editor, field_or_new_array(state, map_object, key::secondary_tags));
		if (state.array_size(secondary_tags) == 0) {
			secondary_tags = _string_array_for_editor(state, editor, field_or_new_array(state, map_object, key::map_roles));
		}
		if (state.array_size(secondary_tags) == 0) {
			secondary_tags = _fallback_resource_tags(state, editor, site);
		}
		const DictRef payload = state.new_dict();
		state.set(payload, str(key::primary_class), str(primary_class));
		state.set(payload, str(key::secondary_tags), array_value(secondary_tags));
		const Value family_fallback = state.get(site, str(key::family), str(key::empty));
		state.set(payload, str(key::object_family), str(string_of(state, state.get(map_object, str(key::family), family_fallback))));
		state.set(payload, str(key::site_family), str(text_of(state, site, key::family)));
		return text_of(state, _density_guidance_for_payload(state, editor, payload, _placement_role_flags(state, editor, payload)), key::group);
	}
	if (family == key::encounter) {
		const DictRef map_object = gd::content_row(state, ContentTable::MapObject, text_of(state, placement, key::object_id));
		Value neutral_metadata = field_or_new_dict(state, placement, key::neutral_encounter);
		if (!gd::is_dict(neutral_metadata) || gd::is_empty(state, neutral_metadata.ref)) {
			neutral_metadata = field_or_new_dict(state, map_object, key::neutral_encounter);
		}
		if (!gd::is_dict(neutral_metadata)) {
			neutral_metadata = dict_value(state.new_dict());
		}
		const Value primary_class_fallback = state.get(placement, str(key::primary_class), str(key::empty));
		Atom primary_class = gd::strip_edges(state, string_of(state, state.get(map_object, str(key::primary_class), primary_class_fallback)));
		if (primary_class == key::empty) {
			primary_class = gd::strip_edges(state, text_of(state, neutral_metadata.ref, key::primary_class, key::neutral_encounter));
		}
		ArrayRef tags = _string_array_for_editor(state, editor, field_or_new_array(state, map_object, key::secondary_tags));
		if (state.array_size(tags) == 0) {
			tags = _string_array_for_editor(state, editor, field_or_new_array(state, neutral_metadata.ref, key::secondary_tags));
		}
		const DictRef payload = state.new_dict();
		state.set(payload, str(key::primary_class), str(primary_class));
		state.set(payload, str(key::secondary_tags), array_value(tags));
		state.set(payload, str(key::object_family), str(text_of(state, map_object, key::family, key::neutral_encounter)));
		return text_of(state, _density_guidance_for_payload(state, editor, payload, _placement_role_flags(state, editor, payload)), key::group);
	}
	return key::empty;
}

Atom _fallback_resource_primary_class(State &state, const Value &editor, DictRef site) {
	(void)editor;
	if (gd::bool_field(state, site, key::persistent_control, false)) {
		const Atom family = text_of(state, site, key::family);
		if (family == key::neutral_dwelling) {
			return key::neutral_dwelling;
		}
		if (family == key::transit_object) {
			return key::transit_route_object;
		}
		if (family == key::guarded_reward_site) {
			return key::guarded_reward_site;
		}
		return key::persistent_economy_site_2;
	}
	if (gd::bool_field(state, site, key::repeatable, false)) {
		return key::interactable_site;
	}
	const Atom family = text_of(state, site, key::family);
	if (family == key::guarded_reward_site) {
		return key::guarded_reward_site;
	}
	if (family == key::transit_object) {
		return key::transit_route_object;
	}
	return key::pickup;
}

ArrayRef _fallback_resource_tags(State &state, const Value &editor, DictRef site) {
	(void)editor;
	const Atom family = text_of(state, site, key::family);
	if (family == key::mine) {
		return string_array(state, {key::resource_front, key::income});
	}
	if (family == key::neutral_dwelling) {
		return string_array(state, {key::neutral_recruit_source, key::weekly_muster_3});
	}
	if (family == key::faction_outpost) {
		return string_array(state, {key::faction_pressure, key::road_control});
	}
	if (family == key::frontier_shrine) {
		return string_array(state, {key::spell_access, key::recovery});
	}
	if (family == key::scouting_structure) {
		return string_array(state, {key::sightline, key::scouting});
	}
	if (family == key::transit_object) {
		return string_array(state, {key::conditional_route, key::road_control});
	}
	if (family == key::guarded_reward_site) {
		return string_array(state, {key::guarded_reward});
	}
	if (family == key::repeatable_service) {
		return string_array(state, {key::recovery, key::market});
	}
	return string_array(state, {key::small_reward, key::route_pacing_2});
}

Atom _fallback_resource_cadence(State &state, const Value &editor, DictRef site) {
	(void)editor;
	if (gd::bool_field(state, site, key::persistent_control, false)) {
		return key::persistent_control;
	}
	if (gd::bool_field(state, site, key::repeatable, false)) {
		return key::repeatable;
	}
	return key::one_time;
}

Atom _fallback_passability_class(State &state, const Value &editor, DictRef map_object, Atom family) {
	(void)editor;
	if (gd::is_empty(state, map_object)) {
		if (family == key::empty || family == key::one_shot_pickup || family == key::pickup) {
			return key::passable_visit_on_enter;
		}
		if (family == key::transit_object) {
			return key::conditional_pass;
		}
		if (family == key::blocker) {
			return key::blocking_non_visitable;
		}
		return key::blocking_visitable;
	}
	if (gd::bool_field(state, map_object, key::passable, false) && gd::bool_field(state, map_object, key::visitable, false)) {
		return key::passable_visit_on_enter;
	}
	if (gd::bool_field(state, map_object, key::passable, false)) {
		return key::passable_scenic;
	}
	if (gd::bool_field(state, map_object, key::visitable, false)) {
		return family == key::transit_object ? Atom(key::conditional_pass) : Atom(key::blocking_visitable);
	}
	return key::blocking_non_visitable;
}

Atom _fallback_encounter_role(State &state, const Value &editor, ArrayRef tags) {
	(void)editor;
	if (gd::array_has(state, tags, str(key::guarded_reward))) {
		return key::guard_linked_stack;
	}
	if (gd::array_has(state, tags, str(key::route_block)) || gd::array_has(state, tags, str(key::route_pacing_2))) {
		return key::visible_stack_2;
	}
	if (gd::array_has(state, tags, str(key::camp_anchor))) {
		return key::camp_anchor;
	}
	return key::visible_stack_2;
}

Atom _risk_from_difficulty(State &state, const Value &editor, Atom difficulty) {
	(void)state;
	(void)editor;
	if (difficulty == key::low) {
		return key::light;
	}
	if (difficulty == key::high) {
		return key::heavy;
	}
	if (difficulty == key::pressure || difficulty == key::scripted) {
		return difficulty;
	}
	return key::standard;
}

Atom _encounter_detail_summary(State &state, const Value &editor, DictRef encounter, DictRef placement, Atom risk, Atom role, DictRef guard) {
	const ArrayRef parts = state.new_array();
	state.append(parts, str(gd::format(state, key::role_s_3, {str(_humanize_editor_id(state, editor, role))})));
	state.append(parts, str(gd::format(state, key::risk_s, {str(_humanize_editor_id(state, editor, risk))})));
	const Atom difficulty = stripped(state, placement, key::difficulty);
	if (difficulty != key::empty) {
		state.append(parts, str(gd::format(state, key::difficulty_s, {str(_humanize_editor_id(state, editor, difficulty))})));
	}
	Value rewards;
	if (state.lookup(encounter, str(key::rewards), rewards) && gd::is_dict(rewards) && !gd::is_empty(state, rewards.ref)) {
		state.append(parts, str(gd::format(state, key::reward_s, {str(_resource_delta_text(state, editor, rewards.ref))})));
	}
	const Atom guard_role = stripped(state, guard, key::guard_role);
	if (guard_role != key::empty) {
		const Value target_fallback = state.get(guard, str(key::target_id), str(key::empty));
		const Atom target = gd::strip_edges(state, string_of(state, state.get(guard, str(key::target_placement_id), target_fallback)));
		const Atom humanized = _humanize_editor_id(state, editor, guard_role);
		const Atom suffix = target != key::empty ? gd::format(state, key::s_9, {str(target)}) : Atom(key::empty);
		state.append(parts, str(gd::format(state, key::guard_s_s_2, {str(humanized), str(suffix)})));
	}
	return join_array(state, key::space_bar_space, parts);
}

Atom _footprint_summary(State &state, const Value &editor, const Value &value) {
	if (!gd::is_dict(value)) {
		return key::empty;
	}
	const DictRef footprint = value.ref;
	const int64_t width = compat::engine_max<int64_t>(1, gd::int_field(state, footprint, key::width, 1));
	const int64_t height = compat::engine_max<int64_t>(1, gd::int_field(state, footprint, key::height, 1));
	const Atom tier = stripped(state, footprint, key::tier);
	if (tier != key::empty) {
		return gd::format(state, key::dx_d_s, {int_value(width), int_value(height), str(_humanize_editor_id(state, editor, tier))});
	}
	return gd::format(state, key::dx_d, {int_value(width), int_value(height)});
}

Atom _tag_summary_for_editor(State &state, const Value &editor, const Value &value, int64_t limit) {
	const ArrayRef tags = _string_array_for_editor(state, editor, value);
	const ArrayRef labels = state.new_array();
	for (const Value &tag : listed(state, array_value(tags))) {
		state.append(labels, str(_humanize_editor_id(state, editor, gd::to_string(tag))));
		if (state.array_size(labels) >= limit) {
			break;
		}
	}
	if (state.array_size(tags) > state.array_size(labels)) {
		state.append(labels, str(gd::format(state, key::plus_d_text, {int_value(state.array_size(tags) - state.array_size(labels))})));
	}
	return join_array(state, key::comma_space, labels);
}

ArrayRef _string_array_for_editor(State &state, const Value &editor, const Value &value) {
	(void)editor;
	const ArrayRef strings = state.new_array();
	if (gd::is_array(value)) {
		for (const Value &item : listed(state, value)) {
			const Atom text = gd::strip_edges(state, string_of(state, item));
			if (text != key::empty && !gd::array_has(state, strings, str(text))) {
				state.append(strings, str(text));
			}
		}
	}
	return strings;
}

Atom _humanize_editor_id(State &state, const Value &editor, Atom value) {
	(void)editor;
	// The same body as OverworldRules._humanize_id.
	return overworld_rules::_humanize_id(state, value);
}

Atom _resource_delta_text(State &state, const Value &editor, DictRef resources) {
	const ArrayRef parts = state.new_array();
	const ArrayRef resource_keys = gd::keys(state, resources);
	for (const Value &resource_key : listed(state, array_value(resource_keys))) {
		const int64_t amount = gd::to_int(state, gd::index(state, resources, resource_key));
		if (amount == 0) {
			continue;
		}
		const Atom label = _humanize_editor_id(state, editor, string_of(state, resource_key));
		// "%+d %s": the sign flag is the engine's format.
		state.append(parts, str(gd::engine_format(state, key::d_s_4, {int_value(amount), str(label)})));
	}
	return join_array(state, key::comma_space, parts);
}

} // namespace aurelion::rules::port::map_editor
