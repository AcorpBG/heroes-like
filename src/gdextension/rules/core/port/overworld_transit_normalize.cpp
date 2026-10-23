// The transit part of OverworldRules.normalize_overworld_state (Phase 5, slice
// 06b): the generated map's runtime materialization record, the one-time
// translation of a random map's transit objects by meaning (through
// GeneratedRewardRules, generated_reward_rules.cpp), the boats and the heroes
// aboard them (WaterTravelRules.normalize), native transit links rebuilt for
// old packages and validated (NativeTransitRules.normalize_legacy_session), and
// the portal networks' colour slots. Also
// OverworldLevelRules.canonical_spatial_records.
//
// Left to GDScript (state::NotPorted): a packed array where the scripts type an
// Array, duplicate() or size() of a value that has none (GDScript's own error),
// "%06d" of the smallest int, and String() of a float or a container.

#include "aurelion_rules/port/overworld_rules.hpp"

#include "aurelion_rules/port/gd.hpp"
#include "aurelion_rules/port/generated_reward_rules.hpp"
#include "aurelion_rules/port/native_transit_rules.hpp"
#include "aurelion_rules/port/native_transit_rules_ai.hpp"
#include "aurelion_rules/port/overworld_level_rules.hpp"
#include "aurelion_rules/port/session_view.hpp"
#include "aurelion_rules/port/water_travel_rules.hpp"
#include "aurelion_rules/port/water_travel_rules_ai.hpp"

#include "aurelion_rules/compat/godot_math.hpp"
#include "aurelion_rules/compat/godot_string.hpp"

#include <algorithm>
#include <cstdint>
#include <initializer_list>
#include <string>
#include <unordered_map>
#include <unordered_set>
#include <vector>

namespace aurelion::rules::port {

namespace {

using gd::array_value;
using gd::ArrayRef;
using gd::Atom;
using gd::bool_value;
using gd::dict_value;
using gd::DictRef;
using gd::int_value;
using gd::str;
using state::State;
using state::Value;
namespace key = state::key;

} // namespace

namespace {

[[noreturn]] void not_ported(const std::string &path) {
	throw state::NotPorted("left to GDScript: " + path);
}

// String(d.get(key, fallback)).
Atom text(State &state, DictRef dict, Atom field, Atom fallback) {
	return gd::stringify_or_fallback(state, state.get(dict, str(field), str(fallback)));
}

// String(d.get(key, fallback)) with an untyped fallback.
Atom text_or(State &state, DictRef dict, Atom field, const Value &fallback) {
	return gd::stringify_or_fallback(state, state.get(dict, str(field), fallback));
}

// var x: Dictionary = d.get(key, {}): a value that is no Dictionary is
// GDScript's assignment error.
DictRef typed_dict_get(State &state, DictRef dict, const Value &field) {
	Value found;
	return state.lookup(dict, field, found) ? gd::as_dict(found) : state.new_dict();
}

// var x: Array = d.get(key, []): Godot would turn a packed array into a new
// Array (not ported); any other value that is no Array is its assignment error.
ArrayRef typed_array_get(State &state, DictRef dict, Atom field, const char *where) {
	Value found;
	if (!state.lookup(dict, str(field), found)) {
		return state.new_array();
	}
	if (found.is_packed()) {
		not_ported(std::string(where) + ": a packed array assigned to an Array");
	}
	return gd::as_array(found);
}

// `d.get(key, {}) if d.get(key, {}) is Dictionary else {}`.
DictRef dict_field_or_new(State &state, DictRef dict, Atom field) {
	Value found;
	if (state.lookup(dict, str(field), found) && gd::is_dict(found)) {
		return found.ref;
	}
	return state.new_dict();
}

// `d.get(key, []) if d.get(key, []) is Array else []`.
ArrayRef array_field_or_new(State &state, DictRef dict, Atom field) {
	Value found;
	if (state.lookup(dict, str(field), found) && gd::is_array(found)) {
		return found.ref;
	}
	return state.new_array();
}

// d.get(key, {}): the field, or a new Dictionary when it is missing.
Value field_or_new_dict(State &state, DictRef dict, Atom field) {
	Value found;
	return state.lookup(dict, str(field), found) ? found : dict_value(state.new_dict());
}

// x.duplicate(true) of an untyped value. Only containers have duplicate();
// anything else is GDScript's runtime error, left to it.
Value duplicate_deep(State &state, const Value &value, const char *where) {
	if (value.is_container() || value.is_packed()) {
		return gd::duplicate_value(state, value, true);
	}
	not_ported(std::string(where) + ": duplicate() of a " + gd::type_name(value));
}

// x.size() of an untyped value.
int64_t variant_size(State &state, const Value &value, const char *where) {
	if (gd::is_array(value)) {
		return state.array_size(value.ref);
	}
	if (gd::is_dict(value)) {
		return state.dict_size(value.ref);
	}
	if (value.is_packed()) {
		return gd::packed_size(state, value.ref);
	}
	not_ported(std::string(where) + ": size() of a " + gd::type_name(value));
}

// x[0] of an untyped value that is an Array.
Value first_item(State &state, const Value &value, const char *where) {
	if (!gd::is_array(value)) {
		not_ported(std::string(where) + ": [0] of a " + gd::type_name(value));
	}
	return state.at(value.ref, 0);
}

// A Vector3i of NativeTransitRules.point().
struct Point {
	int32_t x = -1;
	int32_t y = -1;
	int32_t z = -1;
	bool operator==(const Point &other) const { return x == other.x && y == other.y && z == other.z; }
	bool operator!=(const Point &other) const { return !(*this == other); }
};

Point point_of(State &state, const Value &value) {
	const Value point = native_transit_rules::point(state, value);
	return {point.vx(), point.vy(), point.vz()};
}

// z in [0, 1].
bool is_level_index(int32_t z) {
	return z == 0 || z == 1;
}

bool one_of(int64_t value, std::initializer_list<int64_t> ids) {
	for (const int64_t id : ids) {
		if (id == value) {
			return true;
		}
	}
	return false;
}

// "%06d" % value (String::sprintf: the digits padded with zeros to six, or to
// five after a minus sign).
std::string zero_padded6(int64_t value) {
	if (value == INT64_MIN) {
		not_ported("NativeTransitRules._network_colour_key: \"%06d\" of the smallest int");
	}
	const bool negative = value < 0;
	std::string digits = compat::itos(negative ? -value : value);
	const size_t width = negative ? 5 : 6;
	if (digits.size() < width) {
		digits.insert(0, width - digits.size(), '0');
	}
	return negative ? "-" + digits : digits;
}

// NativeTransitRules.PORTAL_KIND_BY_TYPE.
bool is_portal_type(int64_t type_id) {
	return type_id == 43 || type_id == 44 || type_id == 45;
}
Atom portal_kind_of_type(int64_t type_id) {
	return type_id == 43 ? key::one_way_entrance : (type_id == 44 ? key::one_way_exit : key::two_way_portal);
}

// OverworldRules.GENERATED_TRANSIT_TRANSLATION_VERSION.
constexpr int64_t kGeneratedTransitTranslationVersion = 2;

// GeneratedRewardRules.GATE_TYPES, PORTAL_TYPES and TRANSIT_MEANING_TYPES.
constexpr int64_t kGateTypes[] = {9, 33, 212, 215, 219};
constexpr int64_t kPortalTypes[] = {43, 44, 45};
constexpr int64_t kTransitMeaningTypes[] = {8, 9, 10, 33, 43, 44, 45, 87, 103, 111, 212, 215, 219};

// value in TYPES (Array.has of ints).
template <size_t N>
bool in_types(int64_t value, const int64_t (&ids)[N]) {
	for (const int64_t id : ids) {
		if (id == value) {
			return true;
		}
	}
	return false;
}

} // namespace

// OverworldLevelRules.

namespace overworld_level_rules {

ArrayRef canonical_spatial_records(State &state, ArrayRef owned_records) {
	// Only detached spatial records, never hero/commander progression records.
	// Surface keeps the legacy representation; nonzero layers remain explicit.
	for (const Value &record : gd::items(state, array_value(owned_records))) {
		if (!gd::is_dict(record)) {
			continue;
		}
		Value level;
		if (state.lookup(record.ref, str(key::level), level) && gd::to_int(state, level) == 0) {
			state.erase(record.ref, str(key::level));
		}
	}
	return owned_records;
}

} // namespace overworld_level_rules

// NativeTransitRules.

namespace native_transit_rules {

int64_t network_index(State &state, DictRef node) {
	const DictRef link = link_of(state, node);
	const Value fallback = gd::field_or(state, node, key::h3m_subtype, int_value(0));
	return gd::to_int(state, state.get(link, str(key::network_index), fallback));
}

void assign_network_colours(State &state, ArrayRef nodes) {
	// slots: the networks' keys in the order first met (a Dictionary's keys).
	std::vector<Atom> slots;
	for (const Value &node : gd::items(state, array_value(nodes))) {
		if (gd::is_dict(node) && portal_kind(state, node.ref) != key::empty) {
			const Atom slot_key = _network_colour_key(state, node.ref);
			if (std::find(slots.begin(), slots.end(), slot_key) == slots.end()) {
				slots.push_back(slot_key);
			}
		}
	}
	// ordered.sort(): distinct Strings, by code points (their UTF-8 bytes).
	std::vector<Atom> ordered = slots;
	std::sort(ordered.begin(), ordered.end(), [&state](Atom a, Atom b) { return state.text(a) < state.text(b); });
	std::unordered_map<Atom, int64_t> slot_index;
	for (size_t index = 0; index < ordered.size(); ++index) {
		slot_index[ordered[index]] = static_cast<int64_t>(index);
	}
	for (const Value &node : gd::items(state, array_value(nodes))) {
		if (gd::is_dict(node) && portal_kind(state, node.ref) != key::empty) {
			state.set(node.ref, str(key::portal_colour), int_value(slot_index.at(_network_colour_key(state, node.ref))));
		}
	}
}

Atom _network_colour_key(State &state, DictRef node) {
	// "%d:%06d" % [0 if two-way else 1, network_index(node)]
	const int64_t kind_rank = portal_kind(state, node) == key::two_way_portal ? 0 : 1;
	return state.intern(compat::itos(kind_rank) + ":" + zero_padded6(network_index(state, node)));
}

bool is_dead_end(State &state, DictRef object) {
	if (!is_portal_type(gd::int_field(state, object, key::h3m_type_id, -1))) {
		return false;
	}
	return gd::bool_field(state, link_of(state, object), key::same_zone, false);
}

Atom contract_error(State &state, DictRef node, DictRef indexed) {
	const Value link_value = gd::field(state, node, key::native_transit);
	if (!gd::is_dict(link_value) || gd::int_field(state, link_value.ref, key::schema_version, 0) != 1) {
		return key::missing_native_transit_contract;
	}
	const DictRef link = link_value.ref;
	if (text(state, link, key::kind, key::empty) != key::paired_cave) {
		return _portal_contract_error(state, node, indexed);
	}
	const Atom id = text(state, node, key::placement_id, key::empty);
	const DictRef peer = typed_dict_get(state, indexed, str(text(state, link, key::target_placement_id, key::empty)));
	if (id == key::empty || text(state, link, key::source_placement_id, key::empty) != id || gd::is_empty(state, peer)) {
		return key::missing_native_transit_peer;
	}
	const Value reverse_value = gd::field(state, peer, key::native_transit);
	if (!gd::is_dict(reverse_value)) {
		return key::missing_native_transit_reverse_contract;
	}
	const DictRef reverse = reverse_value.ref;
	if (gd::int_field(state, reverse, key::schema_version, 0) != 1 ||
			text(state, reverse, key::kind, key::empty) != key::paired_cave ||
			text(state, reverse, key::source_function, key::empty) != key::k_0x4a6cf2 ||
			gd::bool_field(state, reverse, key::one_way, true)) {
		return key::invalid_native_cave_reverse_contract;
	}
	if (text(state, link, key::kind, key::empty) != key::paired_cave ||
			text(state, link, key::source_function, key::empty) != key::k_0x4a6cf2 ||
			gd::bool_field(state, link, key::one_way, true)) {
		return key::invalid_native_cave_contract;
	}
	if (text(state, reverse, key::target_placement_id, key::empty) != id ||
			text(state, link, key::group_id, key::empty) == key::empty ||
			!gd::equal(state, gd::field(state, link, key::group_id), gd::field(state, reverse, key::group_id))) {
		return key::nonreciprocal_native_cave_pair;
	}
	const Point entry_tile = point_of(state, gd::field(state, link, key::entry));
	const Point exit_tile = point_of(state, gd::field(state, link, key::exit));
	const ArrayRef visits = typed_array_get(state, node, key::package_visit_tiles, "NativeTransitRules.contract_error");
	const ArrayRef peer_visits = typed_array_get(state, peer, key::package_visit_tiles, "NativeTransitRules.contract_error");
	if (state.array_size(visits) != 1 || state.array_size(peer_visits) != 1 ||
			entry_tile != point_of(state, state.at(visits, 0)) || exit_tile != point_of(state, state.at(peer_visits, 0))) {
		return key::native_transit_action_tile_mismatch;
	}
	if (entry_tile.x < 0 || entry_tile.y < 0 || !is_level_index(entry_tile.z) || !is_level_index(exit_tile.z) || entry_tile.z == exit_tile.z ||
			entry_tile.x != exit_tile.x || entry_tile.y != exit_tile.y) {
		return key::invalid_native_cave_levels;
	}
	if (point_of(state, gd::field(state, reverse, key::entry)) != exit_tile || point_of(state, gd::field(state, reverse, key::exit)) != entry_tile) {
		return key::native_transit_reverse_tile_mismatch;
	}
	return key::empty;
}

Atom _portal_contract_error(State &state, DictRef node, DictRef indexed) {
	const DictRef link = link_of(state, node);
	const int64_t type_id = gd::int_field(state, node, key::h3m_type_id, -1);
	const Atom id = text(state, node, key::placement_id, key::empty);
	// link.get("kind") != kinds[type_id]: a missing kind (null) differs.
	if (!is_portal_type(type_id) ||
			!gd::equal(state, gd::field(state, link, key::kind), str(portal_kind_of_type(type_id))) ||
			text(state, link, key::source_function, key::empty) != key::k_0x4a7605 ||
			gd::bool_field(state, link, key::one_way, false) != (type_id != 45)) {
		return key::invalid_native_portal_source_role;
	}
	if (id == key::empty || text(state, link, key::source_placement_id, key::empty) != id || text(state, link, key::group_id, key::empty) == key::empty) {
		return key::invalid_native_portal_identity;
	}
	const ArrayRef visits = typed_array_get(state, node, key::package_visit_tiles, "NativeTransitRules._portal_contract_error");
	if (state.array_size(visits) != 1 || point_of(state, state.at(visits, 0)) != point_of(state, gd::field(state, link, key::entry))) {
		return key::native_transit_action_tile_mismatch;
	}
	const Point entry = point_of(state, gd::field(state, link, key::entry));
	const Value destination_list = gd::field(state, link, key::destinations);
	if (entry.x < 0 || entry.y < 0 || !is_level_index(entry.z) || !gd::is_array(destination_list)) {
		return key::invalid_native_portal_entry_or_destinations;
	}
	std::unordered_map<Atom, Point> expected;
	// String(link.group_id): the group id is there (checked above).
	const Atom group_id = gd::stringify_or_fallback(state, gd::index(state, link, str(key::group_id)));
	const state::ValueList peers = state.dict(indexed).values;
	for (const Value &peer_value : peers) {
		const DictRef peer = gd::as_dict(peer_value);
		const DictRef peer_link = link_of(state, peer);
		const int64_t peer_type = gd::int_field(state, peer, key::h3m_type_id, -1);
		// A network is one placed connection, or one source colour in packages
		// without connection bookkeeping. Every record in it must agree.
		if (!is_portal_type(peer_type) || text(state, peer_link, key::group_id, key::empty) != group_id) {
			continue;
		}
		if ((peer_type == 45) != (type_id == 45) ||
				gd::int_field(state, peer, key::h3m_subtype, -2) != gd::int_field(state, node, key::h3m_subtype, -1) ||
				gd::int_field(state, peer_link, key::schema_version, 0) != 1 ||
				!gd::equal(state, state.get(peer_link, str(key::source_function), str(key::empty)), str(key::k_0x4a7605)) ||
				!gd::equal(state, gd::field(state, peer_link, key::kind), str(portal_kind_of_type(peer_type))) ||
				gd::bool_field(state, peer_link, key::one_way, false) != (peer_type != 45) ||
				text(state, peer_link, key::source_placement_id, key::empty) != text(state, peer, key::placement_id, key::empty)) {
			return key::native_portal_source_group_mismatch;
		}
		const Atom peer_id = text(state, peer, key::placement_id, key::empty);
		if (peer_id != id && ((type_id == 45 && peer_type == 45) || (type_id == 43 && peer_type == 44))) {
			const ArrayRef peer_visits = typed_array_get(state, peer, key::package_visit_tiles, "NativeTransitRules._portal_contract_error");
			if (state.array_size(peer_visits) != 1 || point_of(state, gd::field(state, peer_link, key::entry)) != point_of(state, state.at(peer_visits, 0))) {
				return key::native_transit_action_tile_mismatch;
			}
			expected[peer_id] = point_of(state, state.at(peer_visits, 0));
		}
	}
	std::unordered_set<Atom> seen;
	for (const Value &destination : gd::items(state, destination_list)) {
		if (!gd::is_dict(destination)) {
			return key::invalid_native_portal_destination;
		}
		const Atom peer_id = text(state, destination.ref, key::target_placement_id, key::empty);
		if (seen.count(peer_id) != 0) {
			return key::native_portal_destination_set_mismatch;
		}
		const auto found = expected.find(peer_id);
		if (found == expected.end() || point_of(state, gd::field(state, destination.ref, key::exit)) != found->second) {
			return key::native_portal_destination_set_mismatch;
		}
		seen.insert(peer_id);
	}
	if (seen.size() != expected.size()) {
		return key::native_portal_destination_set_incomplete;
	}
	return key::empty;
}

DictRef nodes_by_id(State &state, ArrayRef nodes) {
	const DictRef result = state.new_dict();
	for (const Value &node : gd::items(state, array_value(nodes))) {
		if (gd::is_dict(node)) {
			state.set(result, str(text(state, node.ref, key::placement_id, key::empty)), node);
		}
	}
	return result;
}

ArrayRef validate(State &state, ArrayRef nodes) {
	const ArrayRef errors = state.new_array();
	const DictRef indexed = nodes_by_id(state, nodes);
	std::unordered_set<Atom> seen;
	for (const Value &node : gd::items(state, array_value(nodes))) {
		if (!gd::is_dict(node) || !is_native(state, node.ref)) {
			continue;
		}
		const Atom id = text(state, node.ref, key::placement_id, key::empty);
		if (seen.count(id) != 0) {
			const DictRef duplicate = state.new_dict();
			state.set(duplicate, str(key::placement_id), str(id));
			state.set(duplicate, str(key::error), str(key::duplicate_native_transit_identity));
			state.append(errors, dict_value(duplicate));
		}
		seen.insert(id);
		const Atom error = contract_error(state, node.ref, indexed);
		if (error != key::empty) {
			const DictRef entry = state.new_dict();
			state.set(entry, str(key::placement_id), str(text(state, node.ref, key::placement_id, key::empty)));
			state.set(entry, str(key::error), str(error));
			state.append(errors, dict_value(entry));
		}
	}
	return errors;
}

void normalize_legacy_session(State &state, DictRef session) {
	const DictRef overworld = session_view::overworld(state, session);
	// A missing record reads as {}: version 0.
	Value compatibility;
	if (state.lookup(overworld, str(key::native_transit_compatibility), compatibility) && gd::is_dict(compatibility) &&
			gd::int_field(state, compatibility.ref, key::version, 0) == 2) {
		return;
	}
	const DictRef sources = typed_dict_get(state, overworld, str(key::package_source_objects_by_id));
	if (gd::is_empty(state, sources)) {
		return;
	}
	// sources.values(): nothing below writes into sources itself.
	const state::ValueList source_values = state.dict(sources).values;
	std::vector<DictRef> caves;
	for (const Value &record : source_values) {
		if (gd::is_dict(record) && gd::int_field(state, record.ref, key::h3m_type_id, -1) == 103) {
			caves.push_back(record.ref);
		}
	}
	int64_t reconstructed = 0;
	int64_t reconstructed_portals = 0;
	for (const Value &node_value : gd::field_items(state, overworld, str(key::resource_nodes))) {
		if (!gd::is_dict(node_value)) {
			continue;
		}
		const DictRef node = node_value.ref;
		const DictRef source = typed_dict_get(state, sources, str(text(state, node, key::placement_id, key::empty)));
		const int64_t source_type = gd::int_field(state, source, key::h3m_type_id, -1);
		if (!one_of(source_type, {43, 44, 45, 103})) {
			continue;
		}
		state.set(node, str(key::h3m_type_id), int_value(source_type));
		state.set(node, str(key::h3m_subtype), int_value(gd::int_field(state, source, key::h3m_subtype, -1)));
		if (state.has(node, str(key::native_transit))) {
			continue;
		}
		const Value source_link = gd::field(state, source, key::native_transit);
		if (gd::is_dict(source_link)) {
			state.set(node, str(key::native_transit), dict_value(gd::deep_duplicate_dict(state, source_link.ref)));
			continue;
		}
		if (source_type != 103) {
			const ArrayRef visits = typed_array_get(state, source, key::package_visit_tiles, "NativeTransitRules.normalize_legacy_session");
			if (state.array_size(visits) != 1) {
				continue;
			}
			const ArrayRef options = state.new_array();
			for (const Value &peer : source_values) {
				if (!gd::is_dict(peer) ||
						text(state, peer.ref, key::placement_id, key::empty) == text(state, source, key::placement_id, key::empty) ||
						gd::int_field(state, peer.ref, key::h3m_subtype, -2) != gd::int_field(state, source, key::h3m_subtype, -1)) {
					continue;
				}
				const bool two_way = source_type == 45 && gd::int_field(state, peer.ref, key::h3m_type_id, -1) == 45;
				if (!(two_way || (source_type == 43 && gd::int_field(state, peer.ref, key::h3m_type_id, -1) == 44))) {
					continue;
				}
				const ArrayRef peer_visits = typed_array_get(state, peer.ref, key::package_visit_tiles, "NativeTransitRules.normalize_legacy_session");
				if (state.array_size(peer_visits) == 1) {
					const DictRef option = state.new_dict();
					state.set(option, str(key::target_placement_id), str(text(state, peer.ref, key::placement_id, key::empty)));
					state.set(option, str(key::exit), duplicate_deep(state, state.at(peer_visits, 0), "NativeTransitRules.normalize_legacy_session"));
					state.append(options, dict_value(option));
				}
			}
			gd::sort_custom(state, options, [&state](const Value &a, const Value &b) {
				const Value a_id = gd::index(state, gd::as_dict(a), str(key::target_placement_id));
				const Value b_id = gd::index(state, gd::as_dict(b), str(key::target_placement_id));
				return gd::text(state, a_id) < gd::text(state, b_id);
			});
			// Placement IDs have a final serialized ordinal; the preceding map
			// identity is retained verbatim by old package source records.
			const Atom id = text(state, source, key::placement_id, key::empty);
			const std::string id_text = state.text(id);
			// rfind's and left()'s character index cut where the byte index does.
			const size_t ordinal_separator = id_text.rfind("_object_");
			if (ordinal_separator == std::string::npos || ordinal_separator < 1) {
				continue;
			}
			const std::string map_id = id_text.substr(0, ordinal_separator);
			const DictRef link = state.new_dict();
			state.set(link, str(key::schema_version), int_value(1));
			state.set(link, str(key::kind), str(source_type == 45 ? key::two_way_portal : (source_type == 43 ? key::one_way_entrance : key::one_way_exit)));
			state.set(link, str(key::source_function), str(key::k_0x4a7605));
			state.set(link, str(key::source_placement_id), str(id));
			const std::string group_id = "native_portal_" + map_id + (source_type == 45 ? "_two_way_" : "_one_way_") +
					compat::itos(gd::int_field(state, source, key::h3m_subtype, -1));
			state.set(link, str(key::group_id), str(state.intern(group_id)));
			state.set(link, str(key::entry), duplicate_deep(state, state.at(visits, 0), "NativeTransitRules.normalize_legacy_session"));
			state.set(link, str(key::one_way), bool_value(source_type != 45));
			state.set(link, str(key::destinations), array_value(options));
			state.set(node, str(key::native_transit), dict_value(link));
			reconstructed_portals += 1;
			continue;
		}
		// Old packages did not store commit-sidecar links. The recovered cave
		// owner copies XY and replaces only the level (0x4a6fbf..0x4a700f).
		// Accept exactly one exact opposite-level source anchor, never nearest
		// objects or artwork offsets. Ambiguity stays invalid and observable.
		std::vector<DictRef> peers;
		for (const DictRef peer : caves) {
			if (gd::int_field(state, peer, key::h3m_anchor_x, -2) == gd::int_field(state, source, key::h3m_anchor_x, -1) &&
					gd::int_field(state, peer, key::h3m_anchor_y, -2) == gd::int_field(state, source, key::h3m_anchor_y, -1) &&
					gd::int_field(state, peer, key::h3m_anchor_level, -2) == gd::sub(1, gd::int_field(state, source, key::h3m_anchor_level, -1))) {
				peers.push_back(peer);
			}
		}
		const ArrayRef visits = typed_array_get(state, source, key::package_visit_tiles, "NativeTransitRules.normalize_legacy_session");
		if (peers.size() != 1 || state.array_size(visits) != 1 ||
				variant_size(state, state.get(peers[0], str(key::package_visit_tiles), array_value(state.new_array())), "NativeTransitRules.normalize_legacy_session") != 1) {
			continue;
		}
		const DictRef peer = peers[0];
		const Atom id = text(state, source, key::placement_id, key::empty);
		const Atom peer_id = text(state, peer, key::placement_id, key::empty);
		const DictRef link = state.new_dict();
		state.set(link, str(key::schema_version), int_value(1));
		state.set(link, str(key::kind), str(key::paired_cave));
		state.set(link, str(key::source_function), str(key::k_0x4a6cf2));
		const Atom group_end = state.text(id) < state.text(peer_id) ? id : peer_id;
		state.set(link, str(key::group_id), str(state.intern("native_cave_" + state.text(group_end))));
		state.set(link, str(key::source_placement_id), str(id));
		state.set(link, str(key::target_placement_id), str(peer_id));
		state.set(link, str(key::entry), duplicate_deep(state, state.at(visits, 0), "NativeTransitRules.normalize_legacy_session"));
		const Value peer_exit = first_item(state, gd::index(state, peer, str(key::package_visit_tiles)), "NativeTransitRules.normalize_legacy_session");
		state.set(link, str(key::exit), duplicate_deep(state, peer_exit, "NativeTransitRules.normalize_legacy_session"));
		state.set(link, str(key::one_way), bool_value(false));
		state.set(node, str(key::native_transit), dict_value(link));
		reconstructed += 1;
	}
	const ArrayRef errors = validate(state, typed_array_get(state, overworld, key::resource_nodes, "NativeTransitRules.normalize_legacy_session"));
	const DictRef record = state.new_dict();
	state.set(record, str(key::version), int_value(2));
	state.set(record, str(key::reconstructed_legacy_cave_ends), int_value(reconstructed));
	state.set(record, str(key::reconstructed_legacy_portal_ends), int_value(reconstructed_portals));
	state.set(record, str(key::errors), array_value(errors));
	state.set(overworld, str(key::native_transit_compatibility), dict_value(record));
}

} // namespace native_transit_rules

// WaterTravelRules.

namespace water_travel_rules {

void normalize(State &state, DictRef session) {
	const DictRef overworld = session_view::overworld(state, session);
	const ArrayRef cleaned = state.new_array();
	std::unordered_set<Atom> known;
	for (const Value &boat_value : gd::items(state, array_value(boats(state, dict_value(session))))) {
		if (!gd::is_dict(boat_value)) {
			continue;
		}
		const Atom boat_id = gd::strip_edges(state, text(state, boat_value.ref, key::id, key::empty));
		if (boat_id == key::empty || known.count(boat_id) != 0) {
			continue;
		}
		known.insert(boat_id);
		const int64_t x = gd::int_field(state, boat_value.ref, key::x, 0);
		const int64_t y = gd::int_field(state, boat_value.ref, key::y, 0);
		const int64_t level = gd::int_field(state, boat_value.ref, key::level, 0);
		const DictRef boat = state.new_dict();
		state.set(boat, str(key::id), str(boat_id));
		state.set(boat, str(key::x), int_value(x));
		state.set(boat, str(key::y), int_value(y));
		state.set(boat, str(key::level), int_value(level));
		state.set(boat, str(key::hero_id), str(key::empty));
		state.append(cleaned, dict_value(boat));
	}
	const ArrayRef heroes = array_field_or_new(state, overworld, key::player_heroes);
	const Value active = gd::field(state, overworld, key::hero);
	// aboard: boat id -> the hero Dictionary aboard it, the first one met.
	std::unordered_map<Atom, Value> aboard;
	const auto board = [&](const Value &hero_value) {
		if (!gd::is_dict(hero_value)) {
			return;
		}
		const Atom boat_id = hero_boat_id(state, hero_value);
		if (boat_id == key::empty) {
			return;
		}
		if (known.count(boat_id) == 0) {
			state.erase(hero_value.ref, str(key::boat_id));
			return;
		}
		if (aboard.count(boat_id) == 0) {
			aboard.emplace(boat_id, hero_value);
		}
	};
	// for hero_value in heroes + [active]: erasing a hero's boat_id leaves the
	// roster Array as it is.
	for (const Value &hero_value : gd::items(state, array_value(heroes))) {
		board(hero_value);
	}
	// A missing or non-Dictionary hero is {}: no boat.
	board(active);
	// A computer player's hero aboard a boat; a defeated one leaves its boat
	// empty where it lies.
	std::unordered_set<Atom> resolved;
	for (const Value &value : gd::field_items(state, overworld, str(key::resolved_encounters))) {
		resolved.insert(gd::stringify_or_fallback(state, value));
	}
	for (const Value &encounter : gd::field_items(state, overworld, str(key::encounters))) {
		if (!gd::is_dict(encounter) || !gd::is_dict(gd::field(state, encounter.ref, key::ai_hero))) {
			continue;
		}
		const Atom boat_id = hero_boat_id(state, encounter);
		if (boat_id == key::empty) {
			continue;
		}
		const Atom placement_id = text(state, encounter.ref, key::placement_id, key::empty);
		if (known.count(boat_id) == 0 || resolved.count(placement_id) != 0 || aboard.count(boat_id) != 0) {
			state.erase(encounter.ref, str(key::boat_id));
			continue;
		}
		const int64_t x = gd::int_field(state, encounter.ref, key::x, 0);
		const int64_t y = gd::int_field(state, encounter.ref, key::y, 0);
		const int64_t level = overworld_level_rules::level_of(state, encounter);
		const DictRef position = state.new_dict();
		state.set(position, str(key::x), int_value(x));
		state.set(position, str(key::y), int_value(y));
		state.set(position, str(key::level), int_value(level));
		const DictRef carrier = state.new_dict();
		state.set(carrier, str(key::id), str(placement_id));
		state.set(carrier, str(key::position), dict_value(position));
		aboard.emplace(boat_id, dict_value(carrier));
	}
	for (const Value &boat_value : gd::items(state, array_value(cleaned))) {
		const DictRef boat = boat_value.ref;
		const auto found = aboard.find(gd::to_string(gd::index(state, boat, str(key::id))));
		if (found == aboard.end() || !gd::is_dict(found->second)) {
			continue;
		}
		const DictRef hero = found->second.ref;
		const DictRef position = dict_field_or_new(state, hero, key::position);
		state.set(boat, str(key::hero_id), str(text(state, hero, key::id, key::empty)));
		const Value boat_x = gd::index(state, boat, str(key::x));
		state.set(boat, str(key::x), int_value(gd::to_int(state, state.get(position, str(key::x), boat_x))));
		const Value boat_y = gd::index(state, boat, str(key::y));
		state.set(boat, str(key::y), int_value(gd::to_int(state, state.get(position, str(key::y), boat_y))));
		state.set(boat, str(key::level), int_value(overworld_level_rules::level_of(state, dict_value(position))));
	}
	state.set(overworld, str(key::boats), array_value(cleaned));
}

} // namespace water_travel_rules

// OverworldRules.

namespace overworld_rules {

void _normalize_generated_runtime_materialization(State &state, DictRef session, DictRef scenario) {
	if (!gd::bool_field(state, scenario, key::generated, false) &&
			!gd::bool_field(state, gd::as_dict(gd::field(state, session, key::flags)), key::generated_random_map, false) &&
			!gd::bool_field(state, gd::as_dict(gd::field(state, session, key::flags)), key::generated_random_map_draft, false)) {
		return;
	}
	const DictRef overworld = session_view::overworld(state, session);
	DictRef materialization = dict_field_or_new(state, overworld, key::generated_map_runtime_materialization);
	DictRef identity = dict_field_or_new(state, overworld, key::generated_random_map_materialization);
	if (gd::is_empty(state, materialization)) {
		const DictRef scenario_materialization = dict_field_or_new(state, scenario, key::generated_runtime_materialization);
		if (!gd::is_empty(state, scenario_materialization)) {
			materialization = gd::deep_duplicate_dict(state, scenario_materialization);
		}
	}
	if (gd::is_empty(state, identity) && !gd::is_empty(state, materialization)) {
		identity = state.new_dict();
		state.set(identity, str(key::schema_id), str(text(state, materialization, key::schema_id, key::empty)));
		state.set(identity, str(key::scenario_id), str(text_or(state, materialization, key::scenario_id, gd::field(state, session, key::scenario_id))));
		state.set(identity, str(key::materialized_map_signature), str(text(state, materialization, key::materialized_map_signature, key::empty)));
		state.set(identity, str(key::generator_version), str(text(state, materialization, key::generator_version, key::empty)));
		state.set(identity, str(key::template_id), str(text(state, materialization, key::template_id, key::empty)));
		state.set(identity, str(key::profile_id), str(text(state, materialization, key::profile_id, key::empty)));
		state.set(identity, str(key::normalized_seed), str(text(state, materialization, key::normalized_seed, key::empty)));
		state.set(identity, str(key::content_manifest_fingerprint), str(text(state, materialization, key::content_manifest_fingerprint, key::empty)));
		// The record's own summary and boundary Dictionaries, shared with it.
		state.set(identity, str(key::summary), field_or_new_dict(state, materialization, key::summary));
		state.set(identity, str(key::boundary), field_or_new_dict(state, materialization, key::boundary));
	}
	if (!gd::is_empty(state, materialization)) {
		state.set(overworld, str(key::generated_map_runtime_materialization), dict_value(materialization));
	}
	if (!gd::is_empty(state, identity)) {
		state.set(overworld, str(key::generated_random_map_materialization), dict_value(identity));
		const DictRef flags = gd::as_dict(gd::field(state, session, key::flags));
		state.set(flags, str(key::generated_random_map_materialization), dict_value(gd::deep_duplicate_dict(state, identity)));
	}
}

void _migrate_generated_transit_meanings(State &state, DictRef session) {
	const DictRef overworld = session_view::overworld(state, session);
	const int64_t migrated_version = gd::int_field(state, overworld, key::generated_transit_translation_version, 0);
	state.erase(overworld, str(key::native_transit_pending_arrival));
	if (migrated_version >= kGeneratedTransitTranslationVersion) {
		return;
	}
	// sources = get(..., {}) and nodes = get(..., []): a missing sources record
	// is empty, a missing node list an empty Array.
	Value sources;
	const bool has_sources = state.lookup(overworld, str(key::package_source_objects_by_id), sources);
	Value nodes;
	const bool has_nodes = state.lookup(overworld, str(key::resource_nodes), nodes);
	if (!has_sources || !gd::is_dict(sources) || gd::is_empty(state, sources.ref) || (has_nodes && !gd::is_array(nodes))) {
		state.set(overworld, str(key::generated_transit_translation_version), int_value(kGeneratedTransitTranslationVersion));
		return;
	}
	if (!has_nodes) {
		nodes = array_value(state.new_array());
	}
	const ArrayRef towns = array_field_or_new(state, overworld, key::towns);
	const ArrayRef rows = array_field_or_new(state, overworld, key::map);
	const ArrayRef boat_list = gd::deep_duplicate_array(state, water_travel_rules::boats(state, dict_value(session)));
	const ArrayRef kept = state.new_array();
	for (const Value &node_value : gd::items(state, nodes)) {
		if (!gd::is_dict(node_value) || !in_types(gd::int_field(state, node_value.ref, key::h3m_type_id, -1), kTransitMeaningTypes)) {
			state.append(kept, node_value);
			continue;
		}
		if (migrated_version >= 1 && !in_types(gd::int_field(state, node_value.ref, key::h3m_type_id, -1), kPortalTypes)) {
			state.append(kept, node_value);
			continue;
		}
		const DictRef node = node_value.ref;
		// sources.get(id, node) if it is a Dictionary else node.
		const Value source_value = state.get(sources.ref, str(text(state, node, key::placement_id, key::empty)), node_value);
		const DictRef source = gd::is_dict(source_value) ? source_value.ref : node;
		if (generated_reward_rules::is_skipped(state, source)) {
			const DictRef tile = generated_reward_rules::boat_tile(state, source);
			if (!gd::is_empty(state, tile)) {
				// {"id": "boat_%s" % String(...), "x": int(tile.x), ...}
				const Atom boat_id = state.intern("boat_" + state.text(text(state, node, key::placement_id, key::empty)));
				const int64_t x = gd::to_int(state, gd::index(state, tile, str(key::x)));
				const int64_t y = gd::to_int(state, gd::index(state, tile, str(key::y)));
				const int64_t level = gd::to_int(state, gd::index(state, tile, str(key::level)));
				const DictRef boat = state.new_dict();
				state.set(boat, str(key::id), str(boat_id));
				state.set(boat, str(key::x), int_value(x));
				state.set(boat, str(key::y), int_value(y));
				state.set(boat, str(key::level), int_value(level));
				state.set(boat, str(key::hero_id), str(key::empty));
				state.append(boat_list, dict_value(boat));
			}
			continue;
		}
		if (in_types(gd::int_field(state, node, key::h3m_type_id, -1), kGateTypes) && gd::bool_field(state, node, key::collected, false)) {
			state.append(kept, node_value);
			continue;
		}
		const DictRef translated = generated_reward_rules::resolve(state, source, towns, rows);
		if (gd::is_empty(state, translated)) {
			state.append(kept, node_value);
			continue;
		}
		if (native_transit_rules::is_native(state, node)) {
			const DictRef reskinned = gd::deep_duplicate_dict(state, node);
			const Value node_site = state.get(node, str(key::site_id), str(key::empty));
			state.set(reskinned, str(key::site_id), state.get(translated, str(key::site_id), node_site));
			const Value node_object = state.get(node, str(key::object_id), str(key::empty));
			state.set(reskinned, str(key::object_id), state.get(translated, str(key::object_id), node_object));
			state.append(kept, dict_value(reskinned));
			continue;
		}
		state.set(translated, str(key::collected), bool_value(false));
		state.append(kept, dict_value(translated));
	}
	state.set(overworld, str(key::resource_nodes), array_value(kept));
	state.set(overworld, str(key::boats), array_value(boat_list));
	state.set(overworld, str(key::generated_transit_translation_version), int_value(kGeneratedTransitTranslationVersion));
}

} // namespace overworld_rules

} // namespace aurelion::rules::port
