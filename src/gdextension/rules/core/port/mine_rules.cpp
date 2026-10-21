// MineRules: a mine's resource, the common ones and the rare ones.

#include "aurelion_rules/port/mine_rules.hpp"

#include "aurelion_rules/port/common_mine_rules.hpp"

namespace aurelion::rules::port::mine_rules {

namespace {

using gd::str;
using state::ContentTable;
namespace key = state::key;

// String(d.get(key, "")).
Atom string_or_empty(State &state, DictRef dict, Atom field) {
	return gd::to_string(state.get(dict, str(field), str(key::empty)));
}

} // namespace

Atom resource(State &state, DictRef node) {
	const Atom common = common_mine_rules::resource(state, node);
	if (common != key::empty) {
		return common;
	}
	if (string_or_empty(state, node, key::kind) == key::reward_reference) {
		return key::empty;
	}
	const DictRef site = gd::content_row(state, ContentTable::ResourceSite, string_or_empty(state, node, key::site_id));
	return string_or_empty(state, site, key::rare_mine_resource);
}

Vector2i origin(State &state, DictRef node) {
	return common_mine_rules::origin(state, node);
}

Tiles block_tiles(State &state, DictRef node) {
	return common_mine_rules::block_tiles(state, node);
}

} // namespace aurelion::rules::port::mine_rules
