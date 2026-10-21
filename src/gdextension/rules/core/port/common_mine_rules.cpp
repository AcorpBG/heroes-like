// CommonMineRules: a mine's resource and its three-by-two body.

#include "aurelion_rules/port/common_mine_rules.hpp"

namespace aurelion::rules::port::common_mine_rules {

namespace {

using gd::dict_value;
using gd::int_value;
using gd::str;
using state::ContentTable;
using state::Value;
namespace key = state::key;

// String(d.get(key, "")).
Atom string_or_empty(State &state, DictRef dict, Atom field) {
	return gd::to_string(state.get(dict, str(field), str(key::empty)));
}

} // namespace

Atom resource(State &state, DictRef node) {
	if (string_or_empty(state, node, key::kind) == key::reward_reference) {
		return key::empty;
	}
	const DictRef site = gd::content_row(state, ContentTable::ResourceSite, string_or_empty(state, node, key::site_id));
	Atom common = string_or_empty(state, site, key::common_mine_resource);
	if (common == key::empty) {
		// A mine's state variant (the claimed quarry head) keeps its base mine's
		// shape and art; its own site still owns rewards and objectives.
		const Value contract_value = state.get(site, str(key::state_variant_contract), dict_value(state.new_dict()));
		const DictRef contract = gd::is_dict(contract_value) ? contract_value.ref : state.new_dict();
		if (string_or_empty(state, contract, key::base_object_family) == key::mine) {
			const DictRef base = gd::content_row(state, ContentTable::MapObject, string_or_empty(state, contract, key::base_object_id));
			const DictRef base_site = gd::content_row(state, ContentTable::ResourceSite, string_or_empty(state, base, key::resource_site_id));
			common = string_or_empty(state, base_site, key::common_mine_resource);
		}
	}
	return common;
}

Vector2i entry_tile(State &state, DictRef node) {
	const Value visit_value = state.get(node, str(key::visit_tile), dict_value(state.new_dict()));
	const DictRef visit = gd::is_dict(visit_value) ? visit_value.ref : state.new_dict();
	const Value x = state.get(visit, str(key::x), state.get(node, str(key::x), int_value(0)));
	const Value y = state.get(visit, str(key::y), state.get(node, str(key::y), int_value(0)));
	const int64_t x_int = gd::to_int(state, x);
	return Vector2i::of(x_int, gd::to_int(state, y));
}

Vector2i origin(State &state, DictRef node) {
	return entry_tile(state, node) - Vector2i{1, 1};
}

Tiles body_tiles(State &state, DictRef node) {
	Tiles result;
	const Vector2i start = origin(state, node);
	for (int32_t y = 0; y < 2; ++y) {
		for (int32_t x = 0; x < 3; ++x) {
			result.push_back(start + Vector2i{x, y});
		}
	}
	return result;
}

Tiles block_tiles(State &state, DictRef node) {
	Tiles result = body_tiles(state, node);
	// Five solid cells and the south-middle visit cell comprise all six tiles.
	const Vector2i entry = entry_tile(state, node);
	for (auto it = result.begin(); it != result.end(); ++it) {
		if (*it == entry) {
			result.erase(it);
			break;
		}
	}
	return result;
}

} // namespace aurelion::rules::port::common_mine_rules
