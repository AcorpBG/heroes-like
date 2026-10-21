// NativeTransitRules: which resource nodes are the generated maps' native
// transit objects.

#include "aurelion_rules/port/native_transit_rules.hpp"

namespace aurelion::rules::port::native_transit_rules {

namespace {

using gd::str;
namespace key = state::key;

// The h3m type ids is_native counts as native transit.
constexpr int64_t kNativeTypeIds[] = {43, 44, 45, 103};

} // namespace

bool is_native(State &state, DictRef node) {
	if (state.has(node, str(key::native_transit))) {
		return true;
	}
	const int64_t type_id = gd::int_field(state, node, key::h3m_type_id, -1);
	for (int64_t native_id : kNativeTypeIds) {
		if (type_id == native_id) {
			return true;
		}
	}
	return false;
}

} // namespace aurelion::rules::port::native_transit_rules
