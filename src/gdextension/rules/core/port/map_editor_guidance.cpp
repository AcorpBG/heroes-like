// MapEditorShell's rules (Phase 7, slice 7.13): placement availability, its context lines, guidance,
// dependencies, links and warnings.

#include "aurelion_rules/port/map_editor.hpp"

#include "aurelion_rules/port/overworld_rules_ai.hpp"
#include "aurelion_rules/port/session_view.hpp"

#include <algorithm>
#include <string>
#include <vector>

namespace aurelion::rules::port::map_editor {

namespace {

using gd::array_value;
using gd::dict_value;
using gd::int_value;
using gd::str;
using state::ContentTable;
using state::Kind;
namespace key = state::key;

// [OBJECT_FAMILY_TOWN, OBJECT_FAMILY_RESOURCE, OBJECT_FAMILY_ARTIFACT, OBJECT_FAMILY_ENCOUNTER].
constexpr Atom kFamilies[] = {key::town, key::resource, key::artifact, key::encounter};

// String(x) of any value: the engine's text for a float, a vector or a container.
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

// String(d.get(field, fallback)).
Atom text_or(State &state, DictRef dict, Atom field, const Value &fallback) {
	return string_of(state, state.get(dict, str(field), fallback));
}
Atom text_field(State &state, DictRef dict, Atom field, Atom fallback) {
	return text_or(state, dict, field, str(fallback));
}

// self.<member> of a String member.
Atom member_text(State &state, const Value &editor, Atom member) {
	return gd::to_string(gd::member(state, editor, member));
}

// self.<member> of a Vector2i member.
Vector2i member_tile(State &state, const Value &editor, Atom member) {
	const Value value = gd::member(state, editor, member);
	if (value.kind != Kind::Vector2i) {
		throw state::ScriptError("A Vector2i member of the map editor is not a Vector2i");
	}
	return Vector2i{value.vx(), value.vy()};
}

bool no_session(State &state, const Value &editor) {
	return session(state, editor).kind == Kind::Nil;
}

// _session.overworld (a ScriptError when there is no session, as null.overworld is).
DictRef editor_overworld(State &state, const Value &editor) {
	return ::aurelion::rules::port::session_view::overworld(state, session_view(state, session(state, editor)));
}

// _session.scenario_id.
Atom editor_scenario_id(State &state, const Value &editor) {
	return gd::to_string(gd::index(state, session_view(state, session(state, editor)), str(key::scenario_id)));
}

// for item in value: an Array by index, its size read at every step as GDScript's loop reads it, any
// other value as gd::items visits it. body answers false to break.
template <typename Body>
void for_items(State &state, const Value &value, Body body) {
	if (value.kind == Kind::Array) {
		for (int64_t index = 0; index < state.array_size(value.ref); ++index) {
			if (!body(state.at(value.ref, index))) {
				return;
			}
		}
		return;
	}
	const gd::Items listed = gd::items(state, value);
	const std::vector<Value> copied(listed.begin(), listed.end());
	for (const Value &item : copied) {
		if (!body(item)) {
			return;
		}
	}
}

// for item in d.get(field, []): nothing when the field is missing.
template <typename Body>
void for_field_items(State &state, DictRef dict, Atom field, Body body) {
	Value found;
	if (state.lookup(dict, str(field), found)) {
		for_items(state, found, body);
	}
}

// d.clear() (Dictionary::clear): a read-only Dictionary prints an error and stays.
void dict_clear(State &state, DictRef dict) {
	if (state.dict(dict).read_only) {
		state.print_error("Dictionary is in read-only state.");
		return;
	}
	const ArrayRef keys = gd::keys(state, dict);
	for (const Value &entry_key : gd::items(state, array_value(keys))) {
		state.erase(dict, entry_key);
	}
}

// separator.join(parts) of Strings.
Atom join_atoms(State &state, Atom separator, const std::vector<Atom> &parts) {
	std::string joined;
	for (size_t index = 0; index < parts.size(); ++index) {
		if (index > 0) {
			joined += state.text(separator);
		}
		joined += state.text(parts[index]);
	}
	return state.intern(joined);
}

// separator.join(array): each item as String(item), as the Array's conversion to a PackedStringArray
// converts it.
Atom join_array(State &state, Atom separator, ArrayRef parts) {
	std::vector<Atom> atoms;
	for (int64_t index = 0; index < state.array_size(parts); ++index) {
		atoms.push_back(string_of(state, state.at(parts, index)));
	}
	return join_atoms(state, separator, atoms);
}

// text.to_lower() of ASCII text. The role labels are the editor's own English texts and humanized
// content ids; other text would need the engine's Unicode case tables.
Atom to_lower(State &state, Atom text) {
	std::string lowered = state.text(text);
	for (char &c : lowered) {
		const unsigned char byte = static_cast<unsigned char>(c);
		if (byte >= 0x80) {
			throw state::NotPorted("MapEditorShell._placement_authoring_consequence: to_lower() of non-ASCII text");
		}
		if (byte >= 'A' && byte <= 'Z') {
			c = static_cast<char>(byte - 'A' + 'a');
		}
	}
	return state.intern(lowered);
}

// text.split(delimiter)[index] (allow_empty): the index-th piece, or "" past the last one.
Atom split_piece(State &state, Atom text, char delimiter, size_t index) {
	const std::string &source = state.text(text);
	size_t begin = 0;
	for (size_t piece = 0; piece < index; ++piece) {
		const size_t found = source.find(delimiter, begin);
		if (found == std::string::npos) {
			return key::empty;
		}
		begin = found + 1;
	}
	const size_t end = source.find(delimiter, begin);
	return state.intern(source.substr(begin, end == std::string::npos ? std::string::npos : end - begin));
}

// {"can_place": can_place, "blocked_reason": reason}.
DictRef availability(State &state, bool can_place, Atom reason) {
	const DictRef result = state.new_dict();
	state.set(result, str(key::can_place), gd::bool_value(can_place));
	state.set(result, str(key::blocked_reason), str(reason));
	return result;
}

// Whether a Dictionary value is a non-empty Dictionary (x is Dictionary and not x.is_empty()).
bool filled_dict(State &state, const Value &value) {
	return gd::is_dict(value) && !gd::is_empty(state, value.ref);
}

// x is Dictionary and not x.is_empty() of d.get(field, {}): a missing field is an empty Dictionary.
bool field_filled_dict(State &state, DictRef dict, Atom field, Value &out) {
	return state.lookup(dict, str(field), out) && filled_dict(state, out);
}

} // namespace

DictRef _placement_availability_for_selected_object(State &state, const Value &editor, Vector2i tile) {
	if (!_tile_in_bounds(state, editor, tile)) {
		return availability(state, false, key::target_tile_is_outside_the_map);
	}
	const Atom family = member_text(state, editor, key::_selected_object_family);
	const Atom content_id = member_text(state, editor, key::_selected_object_content_id);
	if (family == key::empty || content_id == key::empty) {
		return availability(state, false, key::choose_an_object_before_placing);
	}
	if (gd::is_empty(state, _object_content_lookup(state, editor, family, content_id))) {
		const Atom family_label = _object_family_label(state, editor, family);
		return availability(state, false, gd::format(state, key::unknown_s_content_id_s, {str(family_label), str(content_id)}));
	}
	if (family == key::artifact && _artifact_content_id_exists(state, editor, content_id)) {
		return availability(state, false, key::artifact_is_already_placed_in_this);
	}
	const Atom terrain_id = _terrain_at(state, editor, tile);
	if (!overworld_rules::terrain_id_is_passable(state, terrain_id)) {
		return availability(state, false, gd::format(state, key::impassable_terrain_blocks_placement_s, {str(terrain_id)}));
	}
	const Atom occupied_label = _first_placement_label_at_tile(state, editor, tile);
	if (occupied_label != key::empty) {
		return availability(state, false, gd::format(state, key::tile_already_has_s, {str(occupied_label)}));
	}
	return availability(state, true, key::empty);
}

Atom _first_placement_label_at_tile(State &state, const Value &editor, Vector2i tile) {
	if (no_session(state, editor) || !_tile_in_bounds(state, editor, tile)) {
		return key::empty;
	}
	for (const Atom family : kFamilies) {
		const DictRef overworld = editor_overworld(state, editor);
		Value placements;
		if (!state.lookup(overworld, str(_placement_array_key(state, editor, family)), placements)) {
			continue;
		}
		if (!gd::is_array(placements)) {
			continue;
		}
		for (int64_t index = 0; index < state.array_size(placements.ref); ++index) {
			const Value placement = state.at(placements.ref, index);
			if (gd::is_dict(placement) && _placement_at_tile(state, editor, placement.ref, tile)) {
				const Atom placement_id = text_field(state, placement.ref, key::placement_id, key::empty);
				return placement_id != key::empty ? placement_id : family;
			}
		}
	}
	return key::empty;
}

ArrayRef _placement_context_lines(State &state, const Value &editor, Atom family, Atom content_id, DictRef payload, Vector2i tile) {
	const ArrayRef lines = state.new_array();
	const Atom terrain_context = _placement_terrain_context_line(state, editor, tile);
	if (terrain_context != key::empty) {
		state.append(lines, str(terrain_context));
	}
	const Atom faction_context = _placement_faction_context_line(state, editor, family, content_id, tile);
	if (faction_context != key::empty) {
		state.append(lines, str(faction_context));
	}
	const Atom economy_context = _placement_economy_context_line(state, editor, family, content_id);
	if (economy_context != key::empty) {
		state.append(lines, str(economy_context));
	}
	const Atom route_context = _placement_route_context_line(state, editor, tile);
	if (route_context != key::empty) {
		state.append(lines, str(route_context));
	}
	const Atom dependency_context = _placement_dependency_context_line(state, editor, payload, tile);
	if (dependency_context != key::empty) {
		state.append(lines, str(dependency_context));
	}
	return lines;
}

Atom _placement_terrain_context_line(State &state, const Value &editor, Vector2i tile) {
	if (!_tile_in_bounds(state, editor, tile)) {
		return key::empty;
	}
	const Atom terrain_id = _terrain_at(state, editor, tile);
	const DictRef biome = gd::content_row(state, ContentTable::BiomeForTerrain, terrain_id);
	const Atom biome_name = text_field(state, biome, key::name, key::unknown_biome);
	const bool passable = overworld_rules::terrain_id_is_passable(state, terrain_id);
	return gd::format(state, key::terrain_s_s_passable_s, {str(terrain_id), str(biome_name), str(passable ? key::yes : key::no)});
}

Atom _placement_faction_context_line(State &state, const Value &editor, Atom family, Atom content_id, Vector2i tile) {
	if (family == key::town) {
		const DictRef town = gd::content_row(state, ContentTable::Town, content_id);
		const Atom faction_id = text_field(state, town, key::faction_id, key::empty);
		const DictRef faction = gd::content_row(state, ContentTable::Faction, faction_id);
		const Atom faction_name = text_field(state, faction, key::name, faction_id);
		if (faction_name == key::empty) {
			return key::empty;
		}
		const Atom role = gd::capitalize(state, text_field(state, town, key::strategic_role, key::frontier));
		return gd::format(state, key::faction_s_s, {str(faction_name), str(role)});
	}
	const DictRef nearest = _nearest_town_context(state, editor, tile);
	if (gd::is_empty(state, nearest)) {
		return key::empty;
	}
	const Atom name = text_field(state, nearest, key::name, key::town);
	const Atom owner = text_field(state, nearest, key::owner, key::neutral);
	const Atom faction_name = text_field(state, nearest, key::faction_name, key::empty);
	const int64_t distance = gd::int_field(state, nearest, key::distance, 0);
	return gd::format(state, key::faction_nearest_s_s_s_d, {str(name), str(owner), str(faction_name), int_value(distance)});
}

DictRef _nearest_town_context(State &state, const Value &editor, Vector2i tile) {
	if (no_session(state, editor)) {
		return state.new_dict();
	}
	DictRef best = state.new_dict();
	int64_t best_distance = 999999;
	for_field_items(state, editor_overworld(state, editor), key::towns, [&](const Value &town_placement) {
		if (!gd::is_dict(town_placement)) {
			return true;
		}
		const Vector2i town_tile = Vector2i::of(gd::int_field(state, town_placement.ref, key::x, 0), gd::int_field(state, town_placement.ref, key::y, 0));
		const int64_t dx = static_cast<int64_t>(town_tile.x) - static_cast<int64_t>(tile.x);
		const int64_t dy = static_cast<int64_t>(town_tile.y) - static_cast<int64_t>(tile.y);
		const int64_t distance = (dx < 0 ? -dx : dx) + (dy < 0 ? -dy : dy);
		if (distance >= best_distance) {
			return true;
		}
		const DictRef town = gd::content_row(state, ContentTable::Town, text_field(state, town_placement.ref, key::town_id, key::empty));
		const Atom faction_id = text_field(state, town, key::faction_id, key::empty);
		const DictRef faction = gd::content_row(state, ContentTable::Faction, faction_id);
		best_distance = distance;
		const Atom name = text_or(state, town, key::name, state.get(town_placement.ref, str(key::town_id), str(key::town)));
		const Atom owner = text_field(state, town_placement.ref, key::owner, key::neutral);
		const Atom faction_name = text_field(state, faction, key::name, faction_id);
		best = state.new_dict();
		state.set(best, str(key::name), str(name));
		state.set(best, str(key::owner), str(owner));
		state.set(best, str(key::faction_name), str(faction_name));
		state.set(best, str(key::distance), int_value(distance));
		return true;
	});
	return best;
}

Atom _placement_economy_context_line(State &state, const Value &editor, Atom family, Atom content_id) {
	if (family == key::resource) {
		const DictRef site = gd::content_row(state, ContentTable::ResourceSite, content_id);
		std::vector<Atom> parts;
		Value rewards;
		if (field_filled_dict(state, site, key::rewards, rewards)) {
			parts.push_back(gd::format(state, key::one_time_s, {str(_resource_delta_text(state, editor, rewards.ref))}));
		}
		Value claim_rewards;
		if (field_filled_dict(state, site, key::claim_rewards, claim_rewards)) {
			parts.push_back(gd::format(state, key::claim_s, {str(_resource_delta_text(state, editor, claim_rewards.ref))}));
		}
		Value control_income;
		if (field_filled_dict(state, site, key::control_income, control_income)) {
			parts.push_back(gd::format(state, key::income_s_day, {str(_resource_delta_text(state, editor, control_income.ref))}));
		}
		Value weekly_recruits;
		if (field_filled_dict(state, site, key::weekly_recruits, weekly_recruits)) {
			parts.push_back(gd::format(state, key::weekly_recruits_s, {str(_resource_delta_text(state, editor, weekly_recruits.ref))}));
		}
		if (parts.empty()) {
			return key::empty;
		}
		return gd::format(state, key::economy_s_2, {str(join_atoms(state, key::semicolon_space, parts))});
	}
	if (family == key::town) {
		const DictRef town = gd::content_row(state, ContentTable::Town, content_id);
		Value economy;
		// economy = town.get("economy", {}): a missing field is an empty Dictionary, without base_income.
		if (state.lookup(town, str(key::economy), economy) && gd::is_dict(economy)) {
			Value base_income;
			if (field_filled_dict(state, economy.ref, key::base_income, base_income)) {
				return gd::format(state, key::economy_town_base_s_day, {str(_resource_delta_text(state, editor, base_income.ref))});
			}
		}
	} else if (family == key::encounter) {
		const DictRef encounter = gd::content_row(state, ContentTable::Encounter, content_id);
		Value rewards;
		if (field_filled_dict(state, encounter, key::rewards, rewards)) {
			return gd::format(state, key::economy_battle_reward_s, {str(_resource_delta_text(state, editor, rewards.ref))});
		}
	} else if (family == key::artifact) {
		const DictRef artifact = gd::content_row(state, ContentTable::Artifact, content_id);
		const Atom slot = gd::strip_edges(state, text_field(state, artifact, key::slot, key::empty));
		const Atom slot_text = slot != key::empty ? gd::format(state, key::slot_s, {str(_humanize_editor_id(state, editor, slot))}) : key::empty;
		return gd::format(state, key::economy_hero_progression_reward_s, {str(slot_text)});
	}
	return key::empty;
}

Atom _placement_route_context_line(State &state, const Value &editor, Vector2i tile) {
	if (!_tile_in_bounds(state, editor, tile)) {
		return key::empty;
	}
	if (_has_road_at(state, editor, tile)) {
		return gd::format(state, key::route_on_road_s, {str(join_array(state, key::comma_space, _road_layer_ids_at(state, editor, tile)))});
	}
	int64_t adjacent_roads = 0;
	const Vector2i offsets[] = {Vector2i{1, 0}, Vector2i{-1, 0}, Vector2i{0, 1}, Vector2i{0, -1}};
	for (const Vector2i offset : offsets) {
		if (_tile_in_bounds(state, editor, tile + offset) && _has_road_at(state, editor, tile + offset)) {
			adjacent_roads += 1;
		}
	}
	if (adjacent_roads > 0) {
		return gd::format(state, key::route_adjacent_to_d_road_tile, {int_value(adjacent_roads), str(adjacent_roads == 1 ? key::empty : key::s)});
	}
	return key::route_no_immediate_road_contact;
}

Atom _placement_dependency_context_line(State &state, const Value &editor, DictRef payload, Vector2i tile) {
	if (_first_placement_label_at_tile(state, editor, tile) != key::empty) {
		return key::dependency_inspect_existing_placement_links_before;
	}
	const Atom primary_class = text_field(state, payload, key::primary_class, key::empty);
	const DictRef flags = _placement_role_flags(state, editor, payload);
	if (primary_class == key::town || primary_class == key::neutral_encounter || primary_class == key::neutral_dwelling
			|| gd::bool_field(state, flags, key::transit, false) || gd::bool_field(state, flags, key::faction_landmark, false)) {
		return key::dependency_new_editor_id_starts_unlinked;
	}
	return key::dependency_no_authored_objective_guard_link;
}

Atom _placement_dependency_warning(State &state, const Value &editor, DictRef payload) {
	const Atom primary_class = text_field(state, payload, key::primary_class, key::empty);
	const DictRef flags = _placement_role_flags(state, editor, payload);
	if (primary_class == key::town || primary_class == key::neutral_encounter
			|| gd::bool_field(state, flags, key::transit, false) || gd::bool_field(state, flags, key::faction_landmark, false)) {
		return key::stable_placement_id_needed_before_linking;
	}
	return key::empty;
}

Atom _density_warning_for_guidance(State &state, const Value &editor, DictRef guidance, bool can_place) {
	if (gd::is_empty(state, guidance) || !can_place) {
		return key::empty;
	}
	const Atom target = text_field(state, guidance, key::density_target, key::empty);
	const int64_t upper_bound = _density_target_upper_bound(state, editor, target);
	if (upper_bound <= 0) {
		return key::empty;
	}
	const int64_t projected_count = gd::add(gd::int_field(state, guidance, key::local_density_count, 0), 1);
	if (projected_count > upper_bound) {
		return gd::format(state, key::density_after_placement_is_d_above, {int_value(projected_count), str(target)});
	}
	if (projected_count == upper_bound) {
		return gd::format(state, key::density_after_placement_reaches_target_cap, {str(target)});
	}
	return key::empty;
}

int64_t _density_target_upper_bound(State &state, const Value &editor, Atom target) {
	(void)editor;
	const Atom stripped = gd::strip_edges(state, target);
	const Atom first_token = stripped != key::empty ? split_piece(state, stripped, ' ', 0) : key::empty;
	if (state.text(first_token).find('-') == std::string::npos) {
		return -1;
	}
	// first_token.split("-") has at least two pieces once it holds a dash.
	return gd::to_int(state, str(split_piece(state, first_token, '-', 1)));
}

Atom _placement_authoring_consequence(State &state, const Value &editor, Atom family, Atom content_id, DictRef payload, DictRef guidance) {
	// The fallback is an argument: GDScript works it out whether or not guidance has the role.
	const DictRef flags = _placement_role_flags(state, editor, payload);
	const Atom fallback_role = _placement_role_label(state, editor, payload, flags);
	const Atom role = text_field(state, guidance, key::placement_role, fallback_role);
	if (family == key::town) {
		return gd::format(state, key::creates_a_persistent_town_anchor_for, {str(content_id)});
	}
	if (family == key::resource) {
		return gd::format(state, key::creates_a_s_site_for_s, {str(to_lower(state, role)), str(content_id)});
	}
	if (family == key::artifact) {
		return gd::format(state, key::creates_a_one_time_hero_progression, {str(content_id)});
	}
	if (family == key::encounter) {
		return gd::format(state, key::creates_a_blocking_battle_threat_for, {str(content_id)});
	}
	return gd::format(state, key::creates_a_s_placement_for_s, {str(to_lower(state, role)), str(content_id)});
}

DictRef _placement_guidance_payload(State &state, const Value &editor, DictRef payload, Vector2i tile) {
	if (gd::is_empty(state, payload)) {
		return state.new_dict();
	}
	const DictRef flags = _placement_role_flags(state, editor, payload);
	const DictRef density = _density_guidance_for_payload(state, editor, payload, flags);
	const Atom density_group = text_field(state, density, key::group, key::empty);
	int64_t local_count = 0;
	DictRef region = state.new_dict();
	if (!no_session(state, editor) && _tile_in_bounds(state, editor, tile)) {
		local_count = _local_density_count(state, editor, tile, density_group);
		region = _density_region_bounds(state, editor, tile);
	}
	const Atom link_line = _taxonomy_link_line(state, editor, payload);
	const Atom placement_role = _placement_role_label(state, editor, payload, flags);
	const Atom role_flags_text = _role_flags_text(state, editor, flags);
	const Atom density_band = text_field(state, density, key::band, key::empty);
	const Atom density_target = text_field(state, density, key::target, key::empty);
	const Atom density_note = text_field(state, density, key::note, key::empty);
	const DictRef result = state.new_dict();
	state.set(result, str(key::placement_role), str(placement_role));
	state.set(result, str(key::role_flags), dict_value(flags));
	state.set(result, str(key::role_flags_text), str(role_flags_text));
	state.set(result, str(key::density_group), str(density_group));
	state.set(result, str(key::density_band), str(density_band));
	state.set(result, str(key::density_target), str(density_target));
	state.set(result, str(key::density_note), str(density_note));
	state.set(result, str(key::local_density_count), int_value(local_count));
	state.set(result, str(key::local_density_region), dict_value(region));
	state.set(result, str(key::content_link), str(link_line));
	return result;
}

Atom _selected_tile_authoring_dependency_text(State &state, const Value &editor) {
	if (no_session(state, editor) || !_tile_in_bounds(state, editor, member_tile(state, editor, key::_selected_tile))) {
		return key::empty;
	}
	std::vector<Atom> summaries;
	const ArrayRef details = _object_details_at(state, editor, member_tile(state, editor, key::_selected_tile), false);
	for (int64_t index = 0; index < state.array_size(details); ++index) {
		const Value detail = state.at(details, index);
		if (!gd::is_dict(detail)) {
			continue;
		}
		// var dependencies: Dictionary = detail.get("authoring_dependencies", {}).
		Value dependencies;
		Atom summary = key::empty;
		if (state.lookup(detail.ref, str(key::authoring_dependencies), dependencies)) {
			summary = gd::strip_edges(state, text_field(state, gd::as_dict(dependencies), key::summary, key::empty));
		}
		if (summary != key::empty && std::find(summaries.begin(), summaries.end(), summary) == summaries.end()) {
			summaries.push_back(summary);
		}
		if (summaries.size() >= 2) {
			break;
		}
	}
	if (summaries.empty()) {
		const DictRef scenario_validation = _scenario_authoring_validation_payload(state, editor);
		const int64_t missing_count = gd::int_field(state, scenario_validation, key::missing_objective_anchor_count, 0);
		if (missing_count > 0) {
			return gd::format(state, key::scenario_warnings_d_missing_objective_anchor, {int_value(missing_count), str(missing_count == 1 ? key::empty : key::s)});
		}
		return key::empty;
	}
	return gd::format(state, key::tile_links_s, {str(join_atoms(state, key::space_bar_space, summaries))});
}

DictRef _authoring_dependencies_for_detail(State &state, const Value &editor, DictRef detail) {
	if (no_session(state, editor) || gd::is_empty(state, detail)) {
		return state.new_dict();
	}
	const Atom placement_id = text_field(state, detail, key::placement_id, key::empty);
	if (placement_id == key::empty) {
		return state.new_dict();
	}
	const Atom kind = text_field(state, detail, key::kind, key::empty);
	const Atom content_id = text_field(state, detail, key::content_id, key::empty);
	const ArrayRef objective_links = _objective_links_for_placement(state, editor, placement_id);
	const ArrayRef guard_links = _guard_links_for_placement(state, editor, kind, placement_id, content_id);
	const ArrayRef route_links = _route_links_for_placement(state, editor, kind, placement_id, content_id, guard_links);
	const ArrayRef reward_links = _reward_links_for_placement(state, editor, placement_id, objective_links);
	const ArrayRef enemy_focus_links = _enemy_focus_links_for_placement(state, editor, placement_id);
	const ArrayRef warnings = _authoring_warnings_for_detail(state, editor, detail, objective_links, guard_links, reward_links, enemy_focus_links);
	std::vector<Atom> summary_parts;
	const auto count_part = [&](ArrayRef links, Atom pattern) {
		if (state.array_size(links) != 0) {
			summary_parts.push_back(gd::format(state, pattern, {int_value(state.array_size(links))}));
		}
	};
	count_part(objective_links, key::objectives_d);
	count_part(guard_links, key::guards_d);
	count_part(route_links, key::routes_d);
	count_part(reward_links, key::rewards_d);
	count_part(enemy_focus_links, key::enemy_focus_d);
	count_part(warnings, key::warnings_d);
	const DictRef result = state.new_dict();
	state.set(result, str(key::placement_id), str(placement_id));
	state.set(result, str(key::kind), str(kind));
	state.set(result, str(key::objective_links), array_value(objective_links));
	state.set(result, str(key::guard_links), array_value(guard_links));
	state.set(result, str(key::route_links), array_value(route_links));
	state.set(result, str(key::reward_links), array_value(reward_links));
	state.set(result, str(key::enemy_focus_links), array_value(enemy_focus_links));
	state.set(result, str(key::warnings), array_value(warnings));
	state.set(result, str(key::summary), str(join_atoms(state, key::space_bar_space, summary_parts)));
	return result;
}

ArrayRef _objective_links_for_placement(State &state, const Value &editor, Atom placement_id) {
	const ArrayRef links = state.new_array();
	const DictRef objectives = _editor_scenario_objectives(state, editor);
	if (gd::is_empty(state, objectives)) {
		return links;
	}
	for (const Atom bucket : {key::victory, key::defeat}) {
		Value objective_bucket;
		// objectives.get(bucket, []): a missing bucket has no objectives.
		if (!state.lookup(objectives, str(bucket), objective_bucket) || !gd::is_array(objective_bucket)) {
			continue;
		}
		for (int64_t index = 0; index < state.array_size(objective_bucket.ref); ++index) {
			const Value objective = state.at(objective_bucket.ref, index);
			if (!gd::is_dict(objective)) {
				continue;
			}
			if (text_field(state, objective.ref, key::placement_id, key::empty) != placement_id) {
				continue;
			}
			const Atom id = text_field(state, objective.ref, key::id, key::empty);
			const Atom type = text_field(state, objective.ref, key::type, key::empty);
			const Atom label = text_or(state, objective.ref, key::label, state.get(objective.ref, str(key::id), str(key::Objective)));
			const bool covered = _placement_id_exists(state, editor, placement_id);
			const DictRef link = state.new_dict();
			state.set(link, str(key::id), str(id));
			state.set(link, str(key::bucket), str(bucket));
			state.set(link, str(key::type), str(type));
			state.set(link, str(key::label), str(label));
			state.set(link, str(key::covered), gd::bool_value(covered));
			state.append(links, dict_value(link));
		}
	}
	return links;
}

ArrayRef _guard_links_for_placement(State &state, const Value &editor, Atom kind, Atom placement_id, Atom content_id) {
	const ArrayRef links = state.new_array();
	for_field_items(state, editor_overworld(state, editor), key::encounters, [&](const Value &encounter) {
		if (!gd::is_dict(encounter)) {
			return true;
		}
		const DictRef guard = _guard_link_for_editor(state, editor, encounter.ref);
		if (gd::is_empty(state, guard)) {
			return true;
		}
		const Atom source_placement_id = text_field(state, encounter.ref, key::placement_id, key::empty);
		const Atom target_placement_id = text_field(state, guard, key::target_placement_id, key::empty);
		const Atom target_id = text_field(state, guard, key::target_id, key::empty);
		const Atom target_kind = text_field(state, guard, key::target_kind, key::empty);
		const bool is_source = kind == key::encounter && source_placement_id == placement_id;
		const bool is_target = target_placement_id == placement_id
				|| (target_placement_id == key::empty && (target_id == placement_id || target_id == content_id));
		if (!is_source && !is_target) {
			return true;
		}
		const Atom guard_role = text_field(state, guard, key::guard_role, key::empty);
		const Atom source_label = _placement_label_for_editor(state, editor, source_placement_id);
		const Atom target_label = _guard_target_label_for_editor(state, editor, guard);
		const bool clear_required = gd::bool_field(state, guard, key::clear_required_for_target, false);
		const bool blocks_approach = gd::bool_field(state, guard, key::blocks_approach, false);
		const bool target_present = _guard_target_present_for_editor(state, editor, guard);
		const DictRef link = state.new_dict();
		state.set(link, str(key::role), str(is_source ? key::guards : key::guarded_by));
		state.set(link, str(key::guard_role), str(guard_role));
		state.set(link, str(key::source_placement_id), str(source_placement_id));
		state.set(link, str(key::source_label), str(source_label));
		state.set(link, str(key::target_kind), str(target_kind));
		state.set(link, str(key::target_id), str(target_id));
		state.set(link, str(key::target_placement_id), str(target_placement_id));
		state.set(link, str(key::target_label), str(target_label));
		state.set(link, str(key::clear_required_2), gd::bool_value(clear_required));
		state.set(link, str(key::blocks_approach), gd::bool_value(blocks_approach));
		state.set(link, str(key::target_present), gd::bool_value(target_present));
		state.append(links, dict_value(link));
		return true;
	});
	return links;
}

ArrayRef _route_links_for_placement(State &state, const Value &editor, Atom kind, Atom placement_id, Atom content_id, ArrayRef guard_links) {
	(void)editor;
	const ArrayRef links = state.new_array();
	for (int64_t index = 0; index < state.array_size(guard_links); ++index) {
		const Value link = state.at(guard_links, index);
		if (!gd::is_dict(link)) {
			continue;
		}
		if (text_field(state, link.ref, key::target_kind, key::empty) == key::route
				|| state.text(text_field(state, link.ref, key::guard_role, key::empty)).find(state.text(key::route)) != std::string::npos) {
			const Atom route_id = text_field(state, link.ref, key::target_id, key::empty);
			const Atom source_placement_id = text_field(state, link.ref, key::source_placement_id, key::empty);
			const Atom role = text_field(state, link.ref, key::role, key::empty);
			const bool blocks_approach = gd::bool_field(state, link.ref, key::blocks_approach, false);
			const DictRef route_link = state.new_dict();
			state.set(route_link, str(key::route_id), str(route_id));
			state.set(route_link, str(key::source_placement_id), str(source_placement_id));
			state.set(route_link, str(key::role), str(role));
			state.set(route_link, str(key::blocks_approach), gd::bool_value(blocks_approach));
			state.append(links, dict_value(route_link));
		}
	}
	if (kind == key::resource) {
		const DictRef site = gd::content_row(state, ContentTable::ResourceSite, content_id);
		// route_effect = site.get("transit_profile", {}), else site.get("route_effect", {}): a missing field
		// is an empty Dictionary.
		Value route_effect;
		bool found = state.lookup(site, str(key::transit_profile), route_effect);
		if (!found || !filled_dict(state, route_effect)) {
			found = state.lookup(site, str(key::route_effect), route_effect);
		}
		if (found && filled_dict(state, route_effect)) {
			const DictRef effect = route_effect.ref;
			const Atom route_id = text_or(state, effect, key::route_id, state.get(effect, str(key::route_role), str(key::empty)));
			const Atom role = text_field(state, effect, key::route_role, key::route_effect_2);
			const DictRef route_link = state.new_dict();
			state.set(route_link, str(key::route_id), str(route_id));
			state.set(route_link, str(key::source_placement_id), str(placement_id));
			state.set(route_link, str(key::role), str(role));
			state.set(route_link, str(key::blocks_approach), gd::bool_value(false));
			state.append(links, dict_value(route_link));
		}
	}
	return links;
}

ArrayRef _reward_links_for_placement(State &state, const Value &editor, Atom placement_id, ArrayRef objective_links) {
	const ArrayRef links = state.new_array();
	std::vector<Atom> objective_ids;
	for (int64_t index = 0; index < state.array_size(objective_links); ++index) {
		const Value objective_link = state.at(objective_links, index);
		if (gd::is_dict(objective_link)) {
			const Atom objective_id = text_field(state, objective_link.ref, key::id, key::empty);
			if (objective_id != key::empty) {
				objective_ids.push_back(objective_id);
			}
		}
	}
	const DictRef scenario = gd::content_row(state, ContentTable::Scenario, editor_scenario_id(state, editor));
	for_field_items(state, scenario, key::script_hooks, [&](const Value &hook) {
		if (!gd::is_dict(hook)) {
			return true;
		}
		const Atom hook_id = text_field(state, hook.ref, key::id, key::empty);
		bool gated_by_selected_objective = false;
		for_field_items(state, hook.ref, key::conditions, [&](const Value &condition) {
			if (gd::is_dict(condition)) {
				const Atom objective_id = text_field(state, condition.ref, key::objective_id, key::empty);
				if (std::find(objective_ids.begin(), objective_ids.end(), objective_id) != objective_ids.end()) {
					gated_by_selected_objective = true;
					return false;
				}
			}
			return true;
		});
		for_field_items(state, hook.ref, key::effects, [&](const Value &effect) {
			if (!gd::is_dict(effect)) {
				return true;
			}
			const Atom effect_type = text_field(state, effect.ref, key::type, key::empty);
			Atom spawned_placement_id = key::empty;
			// spawned = effect.get("placement", {}): a missing field is an empty Dictionary.
			Value spawned;
			if (state.lookup(effect.ref, str(key::placement), spawned) && gd::is_dict(spawned)) {
				spawned_placement_id = text_field(state, spawned.ref, key::placement_id, key::empty);
			}
			const bool gated_type = effect_type == key::spawn_resource_node || effect_type == key::spawn_encounter
					|| effect_type == key::add_resources || effect_type == key::award_experience || effect_type == key::town_add_recruits;
			if (spawned_placement_id == placement_id || (gated_by_selected_objective && gated_type)) {
				const Atom label = _effect_label_for_editor(state, editor, effect.ref);
				const DictRef link = state.new_dict();
				state.set(link, str(key::hook_id), str(hook_id));
				state.set(link, str(key::effect_type), str(effect_type));
				state.set(link, str(key::placement_id), str(spawned_placement_id));
				state.set(link, str(key::label), str(label));
				state.set(link, str(key::gated_by_selected_objective), gd::bool_value(gated_by_selected_objective));
				state.append(links, dict_value(link));
			}
			return true;
		});
		return true;
	});
	return links;
}

ArrayRef _enemy_focus_links_for_placement(State &state, const Value &editor, Atom placement_id) {
	const ArrayRef links = state.new_array();
	const DictRef scenario = gd::content_row(state, ContentTable::Scenario, editor_scenario_id(state, editor));
	for_field_items(state, scenario, key::enemy_factions, [&](const Value &config) {
		if (!gd::is_dict(config)) {
			return true;
		}
		const Atom faction_id = text_field(state, config.ref, key::faction_id, key::empty);
		const DictRef faction = gd::content_row(state, ContentTable::Faction, faction_id);
		const Atom label = text_or(state, config.ref, key::label, state.get(faction, str(key::name), str(faction_id)));
		const auto append_link = [&](Atom role) {
			const DictRef link = state.new_dict();
			state.set(link, str(key::faction_id), str(faction_id));
			state.set(link, str(key::label), str(label));
			state.set(link, str(key::role), str(role));
			state.append(links, dict_value(link));
		};
		if (text_field(state, config.ref, key::siege_target_placement_id, key::empty) == placement_id) {
			append_link(key::siege_target);
		}
		Value targets;
		// targets = config.get("priority_target_placement_ids", []): a missing field holds no target.
		if (state.lookup(config.ref, str(key::priority_target_placement_ids), targets) && gd::is_array(targets)
				&& gd::array_has(state, targets.ref, str(placement_id))) {
			append_link(key::priority_target);
		}
		return true;
	});
	return links;
}

ArrayRef _authoring_warnings_for_detail(State &state, const Value &editor, DictRef detail, ArrayRef objective_links, ArrayRef guard_links, ArrayRef reward_links, ArrayRef enemy_focus_links) {
	const ArrayRef warnings = state.new_array();
	const Atom placement_id = text_field(state, detail, key::placement_id, key::empty);
	for (int64_t index = 0; index < state.array_size(guard_links); ++index) {
		const Value link = state.at(guard_links, index);
		if (!gd::is_dict(link)) {
			continue;
		}
		if (text_field(state, link.ref, key::role, key::empty) == key::guards && !gd::bool_field(state, link.ref, key::target_present, false)) {
			const Atom target_label = text_field(state, link.ref, key::target_label, key::target);
			state.append(warnings, str(gd::format(state, key::guard_target_is_missing_s, {str(target_label)})));
		}
	}
	const Atom kind = text_field(state, detail, key::kind, key::empty);
	// taxonomy = detail.get("taxonomy", {}): a missing field is an empty Dictionary, without a class.
	Value taxonomy;
	Atom primary_class = key::empty;
	if (state.lookup(detail, str(key::taxonomy), taxonomy) && gd::is_dict(taxonomy)) {
		primary_class = text_field(state, taxonomy.ref, key::primary_class, key::empty);
	}
	if (kind == key::town && state.array_size(objective_links) == 0 && state.array_size(enemy_focus_links) != 0) {
		state.append(warnings, str(key::enemy_focus_has_no_matching_scenario));
	}
	if (kind == key::encounter && primary_class == key::neutral_encounter && state.array_size(objective_links) == 0
			&& state.array_size(reward_links) == 0 && !gd::is_empty(state, _guard_link_for_detail(state, editor, detail))) {
		state.append(warnings, str(key::guard_has_no_objective_or_reward));
	}
	if (gd::begins_with(state, placement_id, key::editor_)
			&& (state.array_size(objective_links) != 0 || state.array_size(guard_links) != 0 || state.array_size(enemy_focus_links) != 0)) {
		state.append(warnings, str(key::editor_placement_id_is_linked_keep));
	}
	return warnings;
}

Value _editor_validation_memo_lookup(State &state, const Value &editor, Atom memo_key) {
	const int64_t memo_revision = gd::to_int(state, gd::member(state, editor, key::_editor_validation_memo_revision));
	const int64_t edit_revision = gd::to_int(state, gd::member(state, editor, key::_editor_edit_revision));
	if (memo_revision != edit_revision) {
		dict_clear(state, gd::as_dict(gd::member(state, editor, key::_editor_validation_memo)));
		gd::set_member(state, editor, key::_editor_validation_memo_revision, int_value(edit_revision));
	}
	return state.get(gd::as_dict(gd::member(state, editor, key::_editor_validation_memo)), str(memo_key), Value());
}

} // namespace aurelion::rules::port::map_editor
