#include "aurelion_rules/port/adventure_services.hpp"
// AiHeroRules: what a computer player knows of the map (the explored tiles)
// and the site-pass memo its searches read for every site stop.

#include "aurelion_rules/port/ai_hero_rules_ai.hpp"

#include "aurelion_rules/port/overworld_rules.hpp"

#include <algorithm>

namespace aurelion::rules::port {

namespace {

using gd::array_value;
using gd::Atom;
using gd::bool_value;
using gd::dict_value;
using gd::int_value;
using gd::str;
using state::ContentTable;
using state::Kind;
namespace key = state::key;

// The site families that stand after a visit and can be walked across.
bool walk_across(Atom family) {
	return family == key::visit_building || family == key::shrine || family == key::frontier_shrine || family == key::support_producer || family == key::sign_waypoint || family == key::scouting_structure;
}

} // namespace

namespace ai_hero_rules {

PackedRef _explored(State &state, DictRef session, DictRef context, int64_t level) {
	(void)session;
	Value found;
	const DictRef maps = state.lookup(context, str(key::explored), found) ? gd::as_dict(found) : state.new_dict();
	if (state.lookup(maps, int_value(level), found)) {
		auto known = gd::as_bytes(found);
		adventure_services::apply_intelligence(state, context, known, level);
		return known;
	}
	const Value size = gd::index(state, context, str(key::map_size));
	if (!gd::is_vector2i(size)) {
		throw state::ScriptError(std::string("Trying to assign value of type '") + gd::type_name(size) + "' to a variable of type 'Vector2i'.");
	}
	const int64_t count = gd::mul(size.vx(), size.vy());
	const PackedRef tiles = gd::new_bytes(state);
	gd::packed_resize(state, tiles, count);
	const Value enemy_state = gd::index(state, context, str(key::state));
	if (!gd::is_dict(enemy_state)) {
		throw state::ScriptError(std::string("Invalid call. Nonexistent function 'get' in base '") + gd::type_name(enemy_state) + "'.");
	}
	const Value stored = state.lookup(enemy_state.ref, str(key::ai_explored), found) ? found : dict_value(state.new_dict());
	const Atom encoded = gd::is_dict(stored) ? gd::stringify(state, state.get(stored.ref, str(gd::stringify(state, int_value(level))), str(key::empty))) : key::empty;
	if (encoded != key::empty) {
		const PackedRef bits = gd::base64_to_raw(state, encoded);
		const int64_t bit_count = std::min(count, gd::mul(gd::packed_size(state, bits), 8));
		for (int64_t index = 0; index < bit_count; ++index) {
			if ((gd::packed_int(state, bits, index >> 3) >> (index & 7)) & 1) {
				gd::packed_set(state, tiles, index, 1);
			}
		}
	}
	adventure_services::apply_intelligence(state, context, tiles, level);
	state.set(maps, int_value(level), gd::bytes_value(tiles));
	state.set(context, str(key::explored), dict_value(maps));
	return tiles;
}

void _sync_site_pass_memo(State &state) {
	const ArrayRef sources = state.new_array();
	state.append(sources, int_value(gd::content_revision(state)));
	state.append(sources, dict_value(gd::content_file(state, key::resource_sites_path)));
	const ArrayRef kept = gd::as_array(gd::static_var(state, key::ai_hero_rules_script, key::_site_pass_sources));
	if (state.array_size(kept) != state.array_size(sources) || !gd::equal(state, state.at(kept, 0), state.at(sources, 0)) || !gd::is_same(state, state.at(kept, 1), state.at(sources, 1))) {
		gd::set_static_var(state, key::ai_hero_rules_script, key::_site_pass_memo, dict_value(state.new_dict()));
		gd::set_static_var(state, key::ai_hero_rules_script, key::_site_pass_sources, array_value(sources));
	}
}

ArrayRef _site_pass_class(State &state, Atom site_id) {
	const DictRef memo = gd::as_dict(gd::static_var(state, key::ai_hero_rules_script, key::_site_pass_memo));
	const Value site_class = state.get(memo, str(site_id), Value());
	if (site_class.kind != Kind::Nil) {
		return gd::as_array(site_class);
	}
	const DictRef site = gd::content_row(state, ContentTable::ResourceSite, site_id);
	const ArrayRef made = state.new_array();
	state.append(made, bool_value(!gd::is_empty(state, site)));
	state.append(made, bool_value(walk_across(gd::stringify(state, state.get(site, str(key::family), str(key::empty))))));
	state.append(made, bool_value(overworld_rules::_resource_site_is_persistent(state, site) || overworld_rules::_resource_site_is_repeatable(state, site)));
	state.set(memo, str(site_id), array_value(made));
	return made;
}

} // namespace ai_hero_rules

} // namespace aurelion::rules::port
