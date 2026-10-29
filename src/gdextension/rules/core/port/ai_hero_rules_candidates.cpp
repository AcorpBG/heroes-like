// AiHeroRules: the best stop a hero's search reaches and what each kind of stop
// (a site, an artifact, a town, a guard, a hero, a frontier tile) is worth.

#include "aurelion_rules/port/ai_hero_rules_ai.hpp"
#include "aurelion_rules/port/ai_port.hpp"
#include "aurelion_rules/port/overworld_level_rules.hpp"
#include "aurelion_rules/port/player_identity_rules_ai.hpp"
#include "aurelion_rules/port/session_view.hpp"

#include <cstdint>
#include <limits>
#include <string>

namespace aurelion::rules::port {

namespace {

using gd::array_value;
using gd::ArrayRef;
using gd::Atom;
using gd::bool_value;
using gd::dict_value;
using gd::DictRef;
using gd::float_value;
using gd::int_value;
using gd::PackedRef;
using gd::str;
using overworld_rules::Vector2i;
using state::Kind;
using state::State;
using state::Value;
namespace key = state::key;
namespace level_rules = overworld_level_rules;
namespace player_rules = player_identity_rules;

constexpr int64_t kStopArtifact = 2;
constexpr int64_t kStopResource = 1;
constexpr int64_t kStopTown = 3;
constexpr int64_t kStopEncounter = 4;
constexpr int64_t kStopHero = 5;
constexpr int64_t kStopAiHero = 6;
constexpr int64_t kBoughtBoat = 4;
constexpr int64_t kNeighborDx[8] = {1, -1, 0, 0, 1, 1, -1, -1};
constexpr int64_t kNeighborDy[8] = {0, 0, 1, -1, 1, -1, 1, -1};

double tunable(State &state, Atom name) {
	return ai::static_float(state, key::ai_hero_rules_script, name);
}

// var size: Vector2i = context.map_size
Vector2i context_size(const State &state, DictRef context) {
	const Value size = gd::index(state, context, str(key::map_size));
	if (!gd::is_vector2i(size)) {
		throw state::ScriptError(std::string("Trying to assign value of type '") + gd::type_name(size) + "' to a variable of type 'Vector2i'.");
	}
	return {size.vx(), size.vy()};
}

// a % b and a / b of ints: by 0 a script error.
int64_t checked_mod(int64_t a, int64_t b) {
	if (b == 0) {
		throw state::ScriptError("Division by zero error in operator '%'.");
	}
	return compat::int_mod(a, b);
}

int64_t checked_div(int64_t a, int64_t b) {
	if (b == 0) {
		throw state::ScriptError("Division by zero error in operator '/'.");
	}
	return compat::int_div(a, b);
}

[[noreturn]] void no_get(const Value &value) {
	throw state::ScriptError(std::string("Invalid call. Nonexistent function 'get' in base '") + gd::type_name(value) + "'.");
}

// d.get(outer, {}).get(inner, ...) without making the {}: false when either key
// is missing.
bool nested_lookup(const State &state, DictRef dict, Atom outer, Atom inner, Value &out) {
	Value found;
	if (!state.lookup(dict, str(outer), found)) {
		return false;
	}
	if (!gd::is_dict(found)) {
		no_get(found);
	}
	return state.lookup(found.ref, str(inner), out);
}

// d.get(outer, {}).get(inner, []) passed on to a call: a missing list is a new
// empty Array.
Value nested_list(State &state, DictRef dict, Atom outer, Atom inner) {
	Value found;
	return nested_lookup(state, dict, outer, inner, found) ? found : array_value(state.new_array());
}

// var list: Array = d.get(field, []) that the code only indexes: a missing
// field is the empty Array (made only then, for its out-of-bounds error).
ArrayRef indexed_array(State &state, DictRef dict, Atom field) {
	Value found;
	return state.lookup(dict, str(field), found) ? gd::as_array(found) : state.new_array();
}

// session.overworld.towns[index] passed as a Dictionary.
DictRef overworld_town(State &state, DictRef session, int64_t index) {
	const Value towns = gd::index(state, session_view::overworld(state, session), str(key::towns));
	return gd::as_dict(ai::vindex(state, towns, int_value(index)));
}

// int(search.dist[tile_index])
int64_t search_distance(const State &state, DictRef search, int64_t tile_index) {
	return gd::to_int(state, ai::vindex(state, gd::index(state, search, str(key::dist)), int_value(tile_index)));
}

// A typed PackedByteArray or PackedInt32Array local read in a loop: its
// elements in place, refreshed after a call that could change them. Without a
// node it is the empty PackedX() fallback the code read.
class PackedReader {
public:
	PackedReader(const State &state, PackedRef ref, bool present, Kind kind) :
			state_(&state), ref_(ref), present_(present), kind_(kind) {
		refresh();
	}

	void refresh() {
		if (!present_) {
			return;
		}
		size_ = gd::packed_size(*state_, ref_);
		if (kind_ == Kind::PackedByte) {
			bytes_ = gd::packed_bytes(*state_, ref_);
		} else {
			ints_ = gd::packed_ints(*state_, ref_);
		}
	}

	int64_t size() const { return size_; }

	// p[index]: negative from the end, out of range a script error.
	int64_t at(int64_t index) const {
		if (index >= 0 && index < size_) {
			return kind_ == Kind::PackedByte ? static_cast<int64_t>(bytes_[index]) : static_cast<int64_t>(ints_[index]);
		}
		if (!present_) {
			throw state::ScriptError("Out of bounds get index '" + std::to_string(index) + "' (on base: '" + (kind_ == Kind::PackedByte ? "PackedByteArray" : "PackedInt32Array") + "')");
		}
		return gd::packed_int(*state_, ref_, index);
	}

private:
	const State *state_;
	PackedRef ref_;
	bool present_;
	Kind kind_;
	int64_t size_ = 0;
	const uint8_t *bytes_ = nullptr;
	const int32_t *ints_ = nullptr;
};

// var p: PackedX = d.get(field, PackedX()), read only.
PackedReader packed_field(const State &state, DictRef dict, Atom field, Kind kind) {
	Value found;
	if (!state.lookup(dict, str(field), found)) {
		return PackedReader(state, 0, false, kind);
	}
	return PackedReader(state, gd::as_packed(found, kind), true, kind);
}

// {"kind": "explore", "id": "explore:%d" % tile, "index": tile, "value": value,
// "tile_index": tile, "distance": int(search.dist[tile])}
DictRef explore_stop(State &state, DictRef search, int64_t tile_index, double value) {
	const Atom id = gd::format(state, key::explore_d, {int_value(tile_index)});
	const int64_t distance = search_distance(state, search, tile_index);
	const DictRef result = state.new_dict();
	state.set(result, str(key::kind), str(key::explore));
	state.set(result, str(key::id), str(id));
	state.set(result, str(key::index), int_value(tile_index));
	state.set(result, str(key::value), float_value(value));
	state.set(result, str(key::tile_index), int_value(tile_index));
	state.set(result, str(key::distance), int_value(distance));
	return result;
}

} // namespace

namespace ai_hero_rules {

void _profile_add(State &state, DictRef context, Atom profile_key, int64_t started) {
	Value found;
	const DictRef profile = state.lookup(context, str(key::profile), found) ? gd::as_dict(found) : state.new_dict();
	const double before = gd::to_float(state.get(profile, str(profile_key), float_value(0.0)));
	const double elapsed = static_cast<double>(gd::sub(gd::ticks_usec(), started)) / 1000.0;
	state.set(profile, str(profile_key), float_value(before + elapsed));
	state.set(context, str(key::profile), dict_value(profile));
}

DictRef _best_candidate(State &state, DictRef session, DictRef context, DictRef entry, DictRef search, int64_t movement_max, int64_t reach, bool far_kinds) {
	Value found;
	Value ai_entry;
	const bool has_ai_entry = state.lookup(entry, str(key::ai_hero), ai_entry);
	if (has_ai_entry && !gd::is_dict(ai_entry)) {
		no_get(ai_entry);
	}
	bool has_goal = false;
	DictRef goal = 0;
	if (has_ai_entry && state.lookup(ai_entry.ref, str(key::goal), found)) {
		goal = gd::as_dict(found);
		has_goal = true;
	}
	bool has_avoid = false;
	DictRef avoid = 0;
	if (has_ai_entry && state.lookup(ai_entry.ref, str(key::avoid), found) && gd::is_dict(found)) {
		avoid = found.ref;
		has_avoid = true;
	}
	// On the way to hand troops over or pick them up (`_on_the_way`): only
	// what doing first adds to the errand's value per day of travel counts.
	const Value errand = state.get(context, str(key::on_the_way), Value());
	const bool on_the_way = gd::is_dict(errand);
	const double errand_value = on_the_way ? gd::float_field(state, errand.ref, key::value, 0.0) : 0.0;
	const int64_t errand_distance = on_the_way ? gd::int_field(state, errand.ref, key::distance, 0) : 0;
	const ArrayRef way = on_the_way ? gd::as_array(gd::index(state, errand.ref, str(key::way))) : 0;
	const DictRef seen = state.new_dict();
	DictRef best = state.new_dict();
	double best_score = 0.0;
	const double power = hero_power(state, entry);
	const DictRef needs = _resource_needs(state, session, context);
	const PackedRef known = _explored(state, session, context, level_rules::level_of(state, dict_value(entry)));
	Value stops;
	const bool has_stops = state.lookup(search, str(key::stops), stops);
	if (has_stops) {
		gd::as_dict(stops);
	}
	const ArrayRef dangers = _dangers(state, session, context, entry);
	const Vector2i size = context_size(state, context);
	if (has_stops) {
		for (const Value &tile_key : gd::items(state, stops)) {
			const int64_t tile_index = gd::to_int(state, tile_key);
			const int64_t distance = search_distance(state, search, tile_index);
			// A much stronger hostile hero could reach it: the hero keeps away,
			// except to hold its own town where that stops the attack.
			bool in_danger = false;
			if (state.array_size(dangers) != 0) {
				const int64_t x = checked_mod(tile_index, size.x);
				const int64_t y = checked_div(tile_index, size.x);
				in_danger = _in_danger(state, dangers, x, y, level_rules::level_of(state, dict_value(entry)));
			}
			// Stepping into a guard's or a hostile hero's zone means fighting it
			// first: whatever else lies there is reached through that fight.
			const Value refs = gd::index(state, stops.ref, tile_key);
			const bool guarded = _zone_guarded(state, gd::as_array(refs));
			for (const Value &ref : gd::items(state, refs)) {
				if (guarded && !_guards_tile(state, gd::as_dict(ref))) {
					continue;
				}
				// Map objects count once explored; armies and heroes once in sight.
				const int64_t kind = gd::to_int(state, ai::vmember(state, ref, key::kind));
				if (kind == kStopTown) {
					const int64_t town_index = gd::to_int(state, ai::vmember(state, ref, key::index));
					if (!_town_seen(state, known, overworld_town(state, session, town_index), size)) {
						continue;
					}
				} else if (kind != kStopHero && kind != kStopAiHero && gd::packed_int(state, known, tile_index) == 0) {
					continue;
				}
				const int64_t ref_index = gd::to_int(state, ai::vmember(state, ref, key::index));
				const Value seen_key = str(gd::format(state, key::d_d, {int_value(kind), int_value(ref_index)}));
				Value prior;
				if (state.lookup(seen, seen_key, prior) && gd::to_int(state, prior) <= distance) {
					continue;
				}
				state.set(seen, seen_key, int_value(distance));
				if (in_danger && kind != kStopTown) {
					continue;
				}
				const DictRef candidate = _candidate(state, session, context, entry, gd::as_dict(ref), power, needs, search, tile_index);
				if (gd::is_empty(state, candidate)) {
					continue;
				}
				const Atom candidate_id = ai::string_or_empty(state, candidate, key::id);
				const int64_t avoided_until = has_avoid ? gd::to_int(state, state.get(avoid, str(candidate_id), int_value(-1))) : -1;
				if (avoided_until >= ai::session_int(state, session, key::day)) {
					continue;
				}
				if (reach >= 0 && distance > reach) {
					bool far_kind = false;
					if (far_kinds) {
						// Troops count however far: an own town holding them, the
						// main army to hand them to. Main and field armies also go
						// for towns and heroes.
						const Atom candidate_kind = ai::string_or_empty(state, candidate, key::kind);
						far_kind = candidate_kind == key::town_own || candidate_kind == key::meet;
						if (!far_kind && _plans_far(state, session, context, entry)) {
							far_kind = candidate_kind == key::town_hostile || candidate_kind == key::town_neutral || candidate_kind == key::hero || candidate_kind == key::ai_hero;
						}
					}
					if (!far_kind) {
						continue;
					}
				}
				if (in_danger) {
					bool keeps_away = ai::string_or_empty(state, candidate, key::kind) != key::town_own;
					if (!keeps_away) {
						const int64_t town_index = gd::to_int(state, gd::index(state, candidate, str(key::index)));
						keeps_away = !_deters(state, session, entry, overworld_town(state, session, town_index), dangers);
					}
					if (keeps_away) {
						continue;
					}
				}
				const double candidate_value = gd::float_field(state, candidate, key::value, 0.0);
				const double value = candidate_value - _boat_price(state, session, context, search, tile_index);
				if (value <= 0.0) {
					continue;
				}
				double score = value / (1.0 + static_cast<double>(distance) / static_cast<double>(movement_max));
				if (on_the_way) {
					const Atom candidate_kind = ai::string_or_empty(state, candidate, key::kind);
					if ((candidate_kind != key::resource && candidate_kind != key::artifact && candidate_kind != key::encounter) || distance >= errand_distance) {
						continue;
					}
					// The detour: there, then to the nearest tile of the way, then
					// on along the way.
					int64_t extra = std::numeric_limits<int64_t>::max();
					const int64_t x = checked_mod(tile_index, size.x);
					const int64_t y = checked_div(tile_index, size.x);
					const int64_t way_size = state.array_size(way);
					for (int64_t at = 0; at + 2 < way_size; at += 3) {
						const int64_t step = compat::engine_max<int64_t>(compat::absi(gd::sub(x, gd::to_int(state, state.at(way, at)))), compat::absi(gd::sub(y, gd::to_int(state, state.at(way, at + 1)))));
						extra = compat::engine_min<int64_t>(extra, gd::sub(gd::add(distance, step), gd::to_int(state, state.at(way, at + 2))));
					}
					const int64_t total = gd::add(errand_distance, compat::engine_max<int64_t>(0, extra));
					const double moves = static_cast<double>(movement_max);
					score = (value + errand_value) / (1.0 + static_cast<double>(total) / moves) - errand_value / (1.0 + static_cast<double>(errand_distance) / moves);
					if (score <= 0.0) {
						continue;
					}
				} else if (has_goal && ai::string_or_empty(state, goal, key::id) != key::empty) {
					const Atom goal_id = ai::string_or_empty(state, goal, key::id);
					if (goal_id == ai::string_or_empty(state, candidate, key::id)) {
						score *= tunable(state, key::GOAL_CONTINUITY_BONUS);
					}
				}
				if (state.has(context, str(key::decision_alternatives))) {
					_note_alternative(state, context, candidate, score, distance);
				}
				if (score > best_score) {
					best_score = score;
					state.set(candidate, str(key::tile_index), int_value(tile_index));
					state.set(candidate, str(key::distance), int_value(distance));
					state.set(candidate, str(key::score), float_value(score));
					best = candidate;
				}
			}
		}
	}
	if (on_the_way) {
		return best;
	}
	const DictRef explore = _exploration_candidate(state, session, context, entry, search);
	bool has_explore = !gd::is_empty(state, explore);
	if (has_explore && state.array_size(dangers) != 0) {
		const int64_t x = checked_mod(gd::to_int(state, gd::index(state, explore, str(key::tile_index))), size.x);
		const int64_t y = checked_div(gd::to_int(state, gd::index(state, explore, str(key::tile_index))), size.x);
		if (_in_danger(state, dangers, x, y, level_rules::level_of(state, dict_value(entry)))) {
			has_explore = false;
		}
	}
	if (has_explore && reach >= 0 && gd::to_int(state, gd::index(state, explore, str(key::distance))) > reach && !(far_kinds && _rival_towns_unknown(state, session, context))) {
		has_explore = false;
	}
	if (has_explore) {
		const double explore_value = gd::to_float(gd::index(state, explore, str(key::value)));
		const double explore_distance = gd::to_float(gd::index(state, explore, str(key::distance)));
		double explore_score = explore_value / (1.0 + explore_distance / static_cast<double>(movement_max));
		if ((has_goal ? ai::string_or_empty(state, goal, key::kind) : key::empty) == key::explore) {
			explore_score *= tunable(state, key::GOAL_CONTINUITY_BONUS);
		}
		if (explore_score > best_score) {
			state.set(explore, str(key::score), float_value(explore_score));
			best = explore;
		}
	}
	return best;
}

bool _zone_guarded(State &state, ArrayRef refs) {
	for (const Value &ref : gd::items(state, array_value(refs))) {
		if (_guards_tile(state, gd::as_dict(ref))) {
			return true;
		}
	}
	return false;
}

bool _guards_tile(State &state, DictRef ref) {
	return gd::to_int(state, gd::index(state, ref, str(key::kind))) == kStopEncounter || gd::bool_field(state, ref, key::zone, false);
}

bool _in_hero_zone(State &state, DictRef search, int64_t tile_index) {
	Value found;
	if (!state.lookup(search, str(key::hero_zone), found)) {
		return false;
	}
	const PackedRef zone = gd::as_bytes(found);
	return tile_index >= 0 && tile_index < gd::packed_size(state, zone) && gd::packed_int(state, zone, tile_index) != 0;
}

DictRef _exploration_candidate(State &state, DictRef session, DictRef context, DictRef entry, DictRef search) {
	const PackedRef known = _explored(state, session, context, level_rules::level_of(state, dict_value(entry)));
	Value found;
	const bool has_order = state.lookup(search, str(key::order), found);
	const PackedRef order = has_order ? gd::as_ints(found) : 0;
	const Vector2i size = context_size(state, context);
	const DictRef surface = _level_surface(state, session, context, level_rules::level_of(state, dict_value(entry)));
	Value portals;
	const bool has_portals = state.lookup(surface, str(key::portals), portals);
	if (has_portals) {
		gd::as_dict(portals);
	}
	// Ground reached only by buying a boat must be worth the boat's price.
	const double explore_value = _explore_value(state, session, context);
	int64_t portal_frontier = -1;
	if (has_portals) {
		for (const Value &portal_tile : gd::items(state, portals)) {
			const int64_t portal_index = gd::to_int(state, portal_tile);
			const Value dist_value = gd::index(state, search, str(key::dist));
			const int64_t portal_distance = portal_index < ai::vsize(state, dist_value) ? gd::to_int(state, ai::vindex(state, dist_value, int_value(portal_index))) : -1;
			if (portal_distance > 0 && !_in_hero_zone(state, search, portal_index) && _portal_leads_unseen(state, gd::as_dict(gd::index(state, portals.ref, portal_tile)), known)
					&& (portal_frontier < 0 || portal_distance < search_distance(state, search, portal_frontier))
					&& _boat_price(state, session, context, search, portal_index) < explore_value) {
				portal_frontier = portal_index;
			}
		}
	}
	const double portal_value = explore_value - _boat_price(state, session, context, search, portal_frontier);
	PackedReader dist = packed_field(state, search, key::dist, Kind::PackedInt32);
	PackedReader phase = packed_field(state, search, key::phase, Kind::PackedByte);
	const int64_t width = size.x;
	const int64_t height = size.y;
	const PackedRef step_offset = _step_offsets(state, width);
	const int64_t order_count = gd::int_field(state, search, key::order_count, 0);
	PackedReader order_tiles(state, order, has_order, Kind::PackedInt32);
	PackedReader known_tiles(state, known, true, Kind::PackedByte);
	PackedReader steps(state, step_offset, true, Kind::PackedInt32);
	for (int64_t position = 1; position < order_count; ++position) {
		const int64_t tile_index = order_tiles.at(position);
		if (portal_frontier >= 0 && dist.at(portal_frontier) <= dist.at(tile_index)) {
			return explore_stop(state, search, portal_frontier, portal_value);
		}
		const int64_t x = checked_mod(tile_index, width);
		const int64_t y = checked_div(tile_index, width);
		// Only a tile reached by buying a boat has a price (`_boat_price`).
		double price = 0.0;
		if (tile_index < phase.size() && (phase.at(tile_index) & kBoughtBoat) != 0) {
			price = _boat_price(state, session, context, search, tile_index);
			dist.refresh();
			phase.refresh();
			order_tiles.refresh();
			known_tiles.refresh();
			steps.refresh();
		}
		if (price >= explore_value) {
			continue;
		}
		const bool on_edge = x == 0 || y == 0 || x == width - 1 || y == height - 1;
		for (int64_t direction = 0; direction < 8; ++direction) {
			if (on_edge) {
				const int64_t nx = x + kNeighborDx[direction];
				const int64_t ny = y + kNeighborDy[direction];
				if (nx < 0 || ny < 0 || nx >= width || ny >= height) {
					continue;
				}
			}
			if (known_tiles.at(tile_index + steps.at(direction)) == 0) {
				return explore_stop(state, search, tile_index, explore_value - price);
			}
		}
	}
	if (portal_frontier >= 0) {
		return explore_stop(state, search, portal_frontier, portal_value);
	}
	return state.new_dict();
}

DictRef _candidate(State &state, DictRef session, DictRef context, DictRef entry, DictRef ref, double power, DictRef needs, DictRef search, int64_t tile_index) {
	const Atom controller = gd::stringify(state, gd::index(state, context, str(key::controller)));
	const auto ref_index = [&]() { return gd::to_int(state, gd::index(state, ref, str(key::index))); };
	switch (gd::to_int(state, gd::index(state, ref, str(key::kind)))) {
		case kStopResource: {
			const double opens = !gd::is_empty(state, search) ? _site_door_value(state, session, context, entry, search, tile_index, needs) : 0.0;
			const int64_t index = ref_index();
			const DictRef treasury = gd::as_dict(ai::vmember(state, gd::index(state, context, str(key::state)), key::treasury));
			return _resource_candidate(state, session, controller, entry, index, power, needs, treasury, opens);
		}
		case kStopArtifact: {
			const ArrayRef nodes = indexed_array(state, session_view::overworld(state, session), key::artifact_nodes);
			const DictRef node = gd::as_dict(state.at(nodes, ref_index()));
			if (gd::bool_field(state, node, key::collected, false)) {
				return state.new_dict();
			}
			if (!gd::is_empty(state, _artifact_guard(state, session, node))) {
				return state.new_dict();
			}
			const double opens = !gd::is_empty(state, search) ? _site_door_value(state, session, context, entry, search, tile_index, needs) : 0.0;
			const Atom id = ai::string_or_empty(state, node, key::placement_id);
			const int64_t index = ref_index();
			const double value = tunable(state, key::ARTIFACT_VALUE) + opens;
			const DictRef result = state.new_dict();
			state.set(result, str(key::kind), str(key::artifact));
			state.set(result, str(key::id), str(id));
			state.set(result, str(key::index), int_value(index));
			state.set(result, str(key::value), float_value(value));
			return result;
		}
		case kStopTown:
			return _town_candidate(state, session, context, entry, ref_index(), power);
		case kStopEncounter:
			return _encounter_candidate(state, session, context, entry, ref_index(), power, needs, search);
		case kStopHero: {
			const ArrayRef heroes = indexed_array(state, session_view::overworld(state, session), key::player_heroes);
			const DictRef hero = gd::as_dict(state.at(heroes, ref_index()));
			const bool in_sight = _player_hero_seen(state, session, context, hero);
			// On its own town's entry it fights with the garrison: the town's candidate
			// weighs both.
			if (_entry_town_index(state, session, key::hero, ref_index()) >= 0) {
				return state.new_dict();
			}
			const Value stacks = nested_list(state, hero, key::army, key::stacks);
			const double hero_power_value = army_power(state, stacks, dict_value(hero));
			const double burst = _burst_share(state, entry, dict_value(hero));
			const double strength = power * (1.0 - burst);
			if (strength < hero_power_value * tunable(state, key::HERO_ATTACK_RATIO)) {
				return state.new_dict();
			}
			// Out of sight, a hero is fought only where its zone stands first on the
			// way to a town this player knows (`_war_paths`).
			const double war_value = _hero_war_value(state, session, context, entry, search, needs, key::hero, ref_index());
			if (!in_sight && war_value <= 0.0) {
				return state.new_dict();
			}
			const Atom id = ai::string_or_empty(state, hero, key::id);
			const int64_t index = ref_index();
			const double kill_value = tunable(state, key::PLAYER_HERO_KILL_VALUE);
			const double troop_value = tunable(state, key::TROOP_VALUE_PER_POWER);
			const double troop_share = tunable(state, key::HERO_KILL_TROOP_SHARE);
			double value = kill_value + hero_power_value * troop_value * troop_share;
			value = value + _last_stand_share(state, session, key::player, key::player);
			value = value + war_value;
			const DictRef result = state.new_dict();
			state.set(result, str(key::kind), str(key::hero));
			state.set(result, str(key::id), str(id));
			state.set(result, str(key::index), int_value(index));
			state.set(result, str(key::value), float_value(value));
			return result;
		}
		case kStopAiHero: {
			const ArrayRef encounters = indexed_array(state, session_view::overworld(state, session), key::encounters);
			const DictRef other = gd::as_dict(state.at(encounters, ref_index()));
			if (player_rules::raid_controller_id(state, other) == controller) {
				return _meet_candidate(state, session, context, entry, ref_index());
			}
			const Atom their_controller = player_rules::raid_controller_id(state, other);
			if (player_rules::allied(state, dict_value(session), controller, their_controller)) {
				return state.new_dict();
			}
			const DictRef position = level_rules::position(state, other);
			const bool in_sight = _position_seen(state, session, context, position);
			if (_entry_town_index(state, session, key::ai_hero, ref_index()) >= 0) {
				return state.new_dict();
			}
			const double other_power = hero_power(state, other);
			Value commander;
			if (!state.lookup(other, str(key::enemy_commander_state), commander)) {
				commander = dict_value(state.new_dict());
			}
			const double burst = _burst_share(state, entry, commander);
			const double strength = power * (1.0 - burst);
			if (strength < other_power * tunable(state, key::HERO_ATTACK_RATIO)) {
				return state.new_dict();
			}
			const double war_value = _hero_war_value(state, session, context, entry, search, needs, key::ai_hero, ref_index());
			if (!in_sight && war_value <= 0.0) {
				return state.new_dict();
			}
			const Atom other_controller = player_rules::raid_controller_id(state, other);
			const Atom id = ai::string_or_empty(state, other, key::placement_id);
			const int64_t index = ref_index();
			const double kill_value = tunable(state, key::AI_HERO_KILL_VALUE);
			const double troop_value = tunable(state, key::TROOP_VALUE_PER_POWER);
			const double troop_share = tunable(state, key::HERO_KILL_TROOP_SHARE);
			double value = kill_value + other_power * troop_value * troop_share;
			value = value + _threatened_town_share(state, session, context, other);
			value = value + _last_stand_share(state, session, key::enemy, other_controller);
			value = value + war_value;
			const DictRef result = state.new_dict();
			state.set(result, str(key::kind), str(key::ai_hero));
			state.set(result, str(key::id), str(id));
			state.set(result, str(key::index), int_value(index));
			state.set(result, str(key::value), float_value(value));
			state.set(result, str(key::fight_power), float_value(other_power));
			return result;
		}
		default:
			break;
	}
	return state.new_dict();
}

double _hero_war_value(State &state, DictRef session, DictRef context, DictRef entry, DictRef search, DictRef needs, Atom ref_kind, int64_t index) {
	if (gd::is_empty(state, search)) {
		return 0.0;
	}
	const DictRef paths = _war_paths(state, session, context, entry, search, needs);
	const int64_t war_key = _hero_war_key(state, ref_kind, index);
	const double share = gd::to_float(state.get(paths, int_value(war_key), float_value(0.0)));
	return share * tunable(state, key::PASSAGE_KNOWN_SITE_SHARE);
}

DictRef _meet_candidate(State &state, DictRef session, DictRef context, DictRef entry, int64_t other_index) {
	const ArrayRef encounters = indexed_array(state, session_view::overworld(state, session), key::encounters);
	const DictRef other = gd::as_dict(state.at(encounters, other_index));
	const Atom main_id = _decision_main_id(state, session, context);
	const Atom other_id = ai::string_or_empty(state, other, key::placement_id);
	if (main_id == key::empty || main_id == ai::string_or_empty(state, entry, key::placement_id)) {
		return state.new_dict();
	}
	const ArrayRef field_ids = _decision_field_ids(state, session, context);
	if (gd::array_has(state, field_ids, str(ai::string_or_empty(state, entry, key::placement_id)))) {
		if (main_id != other_id) {
			return state.new_dict();
		}
		// A field army joins the main army only when something it has to beat
		// is beyond the main army alone: the main hero takes the stronger
		// stacks. Otherwise it keeps its army and works on its own; seven stacks
		// are what limit an army, not its share of the main army's strength.
		if (_main_shortfall(state, session, context, other) <= 0.0) {
			return state.new_dict();
		}
		Value found;
		const ArrayRef main_stacks = nested_lookup(state, other, key::enemy_army, key::stacks, found) ? gd::as_array(gd::duplicate_value(state, found, true)) : state.new_array();
		const ArrayRef own_stacks = nested_lookup(state, entry, key::enemy_army, key::stacks, found) ? gd::as_array(gd::duplicate_value(state, found, true)) : state.new_array();
		const DictRef swap = _garrison_pickup(state, main_stacks, own_stacks);
		if (gd::to_float(gd::index(state, swap, str(key::gain))) <= 0.0) {
			return state.new_dict();
		}
		const Atom id = ai::string_or_empty(state, other, key::placement_id);
		const double base = tunable(state, key::JOIN_BASE_VALUE);
		const double gain = gd::to_float(gd::index(state, swap, str(key::gain)));
		const double value = base + gain * tunable(state, key::TROOP_VALUE_PER_POWER) * tunable(state, key::HANDOVER_TROOP_SHARE);
		const DictRef result = state.new_dict();
		state.set(result, str(key::kind), str(key::meet));
		state.set(result, str(key::id), str(id));
		state.set(result, str(key::index), int_value(other_index));
		state.set(result, str(key::value), float_value(value));
		return result;
	}
	// A courier hands its troops to the main army or to a field army, the one
	// that gains most: the armies are pooled and the receiver keeps the
	// strongest seven stacks, so troops go where their kind already stands or a
	// slot is free, and a full army of another faction takes them only in place
	// of weaker stacks. A hand-over is worth what the receiver gains, however
	// much: a courier with a rear town's garrison brings it before small errands.
	if (other_id != main_id && !gd::array_has(state, field_ids, str(other_id))) {
		return state.new_dict();
	}
	Value found;
	const ArrayRef their_stacks = nested_lookup(state, other, key::enemy_army, key::stacks, found) ? gd::as_array(gd::duplicate_value(state, found, true)) : state.new_array();
	const ArrayRef own_stacks = nested_lookup(state, entry, key::enemy_army, key::stacks, found) ? gd::as_array(gd::duplicate_value(state, found, true)) : state.new_array();
	if (state.array_size(own_stacks) == 0) {
		return state.new_dict();
	}
	const DictRef pooled = _garrison_pickup(state, their_stacks, own_stacks);
	const double gain = gd::to_float(gd::index(state, pooled, str(key::gain)));
	const double value = gain * tunable(state, key::TROOP_VALUE_PER_POWER) * tunable(state, key::HANDOVER_TROOP_SHARE);
	if (value <= tunable(state, key::MIN_TROOP_ERRAND_VALUE)) {
		return state.new_dict();
	}
	const DictRef result = state.new_dict();
	state.set(result, str(key::kind), str(key::meet));
	state.set(result, str(key::id), str(other_id));
	state.set(result, str(key::index), int_value(other_index));
	state.set(result, str(key::value), float_value(value));
	return result;
}

} // namespace ai_hero_rules

} // namespace aurelion::rules::port
