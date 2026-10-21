// NativeTransitRules: the functions the AI targets reach (Phase 3), ported under
// their GDScript names.

#include "aurelion_rules/port/native_transit_rules_ai.hpp"

#include "aurelion_rules/port/ai_port.hpp"
#include "aurelion_rules/port/overworld_level_rules_ai.hpp"

namespace aurelion::rules::port {

namespace {

using gd::ArrayRef;
using gd::Atom;
using gd::bool_value;
using gd::dict_value;
using gd::DictRef;
using gd::str;
using state::Kind;
using state::State;
using state::Value;
namespace key = state::key;

} // namespace

namespace native_transit_rules {

bool uses_native_adjacency(State &state, const Value &session) {
	if (session.kind == Kind::Nil) {
		return false;
	}
	const Value flags = ai::vmember(state, session, key::flags);
	return gd::to_bool(ai::vget(state, flags, key::native_random_map_package_session_adoption, bool_value(false)));
}

DictRef link_of(State &state, DictRef node) {
	const Value link = gd::field(state, node, key::native_transit);
	return gd::is_dict(link) ? link.ref : state.new_dict();
}

ArrayRef destinations(State &state, DictRef node) {
	const DictRef link = link_of(state, node);
	if (ai::string_or_empty(state, link, key::kind) == key::paired_cave) {
		const DictRef destination = state.new_dict();
		state.set(destination, str(key::target_placement_id), state.get(link, str(key::target_placement_id), str(key::empty)));
		Value exit;
		if (!state.lookup(link, str(key::exit), exit)) {
			exit = dict_value(state.new_dict());
		}
		state.set(destination, str(key::exit), exit);
		const ArrayRef result = state.new_array();
		state.append(result, dict_value(destination));
		return result;
	}
	Value values;
	if (state.lookup(link, str(key::destinations), values) && gd::is_array(values)) {
		return values.ref;
	}
	return state.new_array();
}

Atom portal_kind(State &state, DictRef node) {
	// String(link_of(node).get("kind", "")): no link reads as "".
	const Value link = gd::field(state, node, key::native_transit);
	const Atom kind = gd::is_dict(link) ? ai::string_or_empty(state, link.ref, key::kind) : key::empty;
	// kind in PORTAL_KIND_BY_TYPE.values()
	if (kind == key::one_way_entrance || kind == key::one_way_exit || kind == key::two_way_portal) {
		return kind;
	}
	switch (gd::int_field(state, node, key::h3m_type_id, -1)) {
		case 43:
			return key::one_way_entrance;
		case 44:
			return key::one_way_exit;
		case 45:
			return key::two_way_portal;
		default:
			return key::empty;
	}
}

Value point(State &state, const Value &value) {
	if (gd::is_dict(value)) {
		const int64_t x = gd::int_field(state, value.ref, key::x, -1);
		const int64_t y = gd::int_field(state, value.ref, key::y, -1);
		const int64_t level = overworld_level_rules::level_of(state, value);
		return gd::vector3i(static_cast<int32_t>(x), static_cast<int32_t>(y), static_cast<int32_t>(level));
	}
	return gd::vector3i(-1, -1, -1);
}

} // namespace native_transit_rules

} // namespace aurelion::rules::port
