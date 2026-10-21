// ContentService: the functions the AI targets reach (Phase 3), ported under
// their GDScript names.

#include "aurelion_rules/port/content_service_ai.hpp"

namespace aurelion::rules::port {

namespace {

using gd::Atom;
using gd::DictRef;
using gd::str;
using state::State;
namespace key = state::key;
using state::Value;

} // namespace

namespace content_service {

Atom normalize_terrain_id(State &state, Atom terrain_id) {
	const Atom normalized = gd::strip_edges(state, terrain_id);
	if (normalized == key::highland || normalized == key::hills || normalized == key::ridge) {
		return key::rough;
	}
	if (normalized == key::badlands) {
		return key::dirt;
	}
	if (normalized == key::wastes) {
		return key::sand;
	}
	if (normalized == key::cavern || normalized == key::underway) {
		return key::underground;
	}
	if (normalized == key::coast || normalized == key::shore) {
		return key::water;
	}
	return normalized;
}

DictRef default_ai_hero_weights(State &state) {
	// load_json(AI_HERO_WEIGHTS_PATH).get("sets", {}).get("default", {})
	const Value sets = gd::field_or(state, gd::content_file(state, key::ai_hero_weights_path), key::sets, gd::dict_value(state.new_dict()));
	return gd::as_dict(state.get(gd::as_dict(sets), str(key::default_set), gd::dict_value(state.new_dict())));
}

} // namespace content_service

} // namespace aurelion::rules::port
