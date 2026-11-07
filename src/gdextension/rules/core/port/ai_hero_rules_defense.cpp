// AiHeroRules: the main army and the field armies, what the main army lacks,
// the threats to a player's towns and the troops left behind to hold them.

#include "aurelion_rules/port/ai_hero_rules_ai.hpp"

#include "aurelion_rules/port/ai_port.hpp"
#include "aurelion_rules/port/enemy_turn_rules.hpp"
#include "aurelion_rules/port/native_transit_rules_ai.hpp"
#include "aurelion_rules/port/overworld_level_rules.hpp"
#include "aurelion_rules/port/overworld_level_rules_ai.hpp"
#include "aurelion_rules/port/overworld_rules_ai.hpp"
#include "aurelion_rules/port/player_identity_rules_ai.hpp"
#include "aurelion_rules/port/scenario_evaluation.hpp"
#include "aurelion_rules/port/session_view.hpp"
#include "aurelion_rules/port/spell_rules.hpp"
#include "aurelion_rules/port/water_travel_rules_ai.hpp"

#include <algorithm>
#include <cmath>
#include <cstdint>
#include <limits>
#include <string>
#include <unordered_map>
#include <unordered_set>
#include <utility>
#include <vector>

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
using state::ContentTable;
using state::State;
using state::Value;
namespace key = state::key;
namespace level_rules = overworld_level_rules;
namespace player_rules = player_identity_rules;

constexpr double kInf = std::numeric_limits<double>::infinity();

double tunable_float(State &state, Atom name) {
	return ai::static_float(state, key::ai_hero_rules_script, name);
}

int64_t tunable_int(State &state, Atom name) {
	return ai::static_int(state, key::ai_hero_rules_script, name);
}

// var x: Dictionary = d.get(field, {}) where x may be stored: the Dictionary,
// or a new one when the field is missing.
DictRef dict_or_new(State &state, DictRef dict, Atom field) {
	Value found;
	return state.lookup(dict, str(field), found) ? gd::as_dict(found) : state.new_dict();
}

// d.get(field, []) passed on: the value, or a new empty Array.
Value field_or_new_array(State &state, DictRef dict, Atom field) {
	Value found;
	return state.lookup(dict, str(field), found) ? found : array_value(state.new_array());
}

// army_power(stacks) with its default commander {}.
double power_of(State &state, const Value &stacks) {
	return ai_hero_rules::army_power(state, stacks, dict_value(state.new_dict()));
}

// String(d.get(field, fallback)).
Atom string_or(State &state, DictRef dict, Atom field, Atom fallback) {
	return gd::stringify(state, state.get(dict, str(field), str(fallback)));
}

// String(context.controller).
Atom context_controller(State &state, DictRef context) {
	return gd::stringify(state, gd::index(state, context, str(key::controller)));
}

// var size: Vector2i = context.map_size.
Vector2i context_map_size(State &state, DictRef context) {
	const Value size = gd::index(state, context, str(key::map_size));
	if (!gd::is_vector2i(size)) {
		throw state::ScriptError(std::string("Trying to assign value of type '") + gd::type_name(size) + "' to a variable of type 'Vector2i'.");
	}
	return Vector2i::of(size.vx(), size.vy());
}

// int(hero.get("enemy_commander_state", {}).get("experience", 0)).
int64_t experience_of(State &state, DictRef hero) {
	Value commander;
	if (!state.lookup(hero, str(key::enemy_commander_state), commander)) {
		return 0;
	}
	return gd::to_int(state, ai::vget(state, commander, key::experience, int_value(0)));
}

// maxi(absi(ax - bx), absi(ay - by)).
int64_t tile_distance(int64_t ax, int64_t bx, int64_t ay, int64_t by) {
	return compat::engine_max<int64_t>(compat::absi(gd::sub(ax, bx)), compat::absi(gd::sub(ay, by)));
}

// A way off a tile of one level: a gate or monolith to another level, or a
// portal to a tile of the same level.
struct Crossing {
	int64_t tile;
	int64_t exit_x;
	int64_t exit_y;
	int64_t exit_level;
};

// A hostile hero as the threat checks walk it: the ground it gets to beating
// any guard it can beat (`_level_stretches`, which lets it pass its own side's
// heroes, its allies' and those this player has not seen), within the tiles the
// caller counts. A caller looking two days ahead also lets it take to the water.
struct Walker {
	Atom id;
	double power;
	int64_t reach;
	int64_t limit;
	bool two_days;
	DictRef entry;
	// The crossings of each level, looked up once for all the towns it is
	// walked to.
	mutable std::unordered_map<int64_t, std::vector<Crossing>> crossings;
};

// A threat fights any guard it can beat on its way: the loss is its own choice.
constexpr double kAnyLoss = 1.0e15;

Walker threat_walker(State &state, Atom id, Atom side, double power, int64_t reach, int64_t limit, bool two_days) {
	const DictRef entry = state.new_dict();
	state.set(entry, str(key::placement_id), str(id));
	state.set(entry, str(key::walker_side), str(side));
	return Walker{id, power, reach, limit, two_days, entry, {}};
}

// Whether the walker could put to sea by tomorrow: it is aboard already, or a
// free boat lies beside its ground or a shipyard on it within a day's walk.
bool takes_ship(State &state, DictRef session, DictRef context, const Walker &walker, int64_t x, int64_t y, int64_t level, const std::vector<int64_t> &homes) {
	if (homes.empty()) {
		return true;
	}
	const Vector2i size = context_map_size(state, context);
	const auto near_home = [&](int64_t tile_x, int64_t tile_y) {
		return tile_distance(x, tile_x, y, tile_y) <= gd::add(walker.reach, 1);
	};
	const auto on_home = [&](int64_t tile_x, int64_t tile_y) {
		if (tile_x < 0 || tile_y < 0 || tile_x >= size.x || tile_y >= size.y) {
			return false;
		}
		const int64_t there = ai_hero_rules::_tile_stretch(state, session, context, level, gd::add(gd::mul(tile_y, size.x), tile_x), walker.power, kAnyLoss, walker.entry);
		return std::find(homes.begin(), homes.end(), there) != homes.end();
	};
	for (const Value &boat : gd::items(state, array_value(water_travel_rules::boats(state, dict_value(session))))) {
		if (!gd::is_dict(boat) || gd::int_field(state, boat.ref, key::level, 0) != level || ai::string_or_empty(state, boat.ref, key::hero_id) != key::empty) {
			continue;
		}
		const int64_t boat_x = gd::int_field(state, boat.ref, key::x, -1);
		const int64_t boat_y = gd::int_field(state, boat.ref, key::y, -1);
		if (!near_home(boat_x, boat_y)) {
			continue;
		}
		for (int64_t dx = -1; dx <= 1; ++dx) {
			for (int64_t dy = -1; dy <= 1; ++dy) {
				if ((dx != 0 || dy != 0) && on_home(boat_x + dx, boat_y + dy)) {
					return true;
				}
			}
		}
	}
	const Value shipyards = state.get(ai_hero_rules::_level_surface(state, session, context, level), str(key::shipyards), Value());
	if (gd::is_dict(shipyards) && size.x > 0) {
		for (const Value &visit : gd::items(state, shipyards)) {
			const int64_t tile = gd::to_int(state, visit);
			if (near_home(compat::int_mod(tile, size.x), tile / size.x) && on_home(compat::int_mod(tile, size.x), tile / size.x)) {
				return true;
			}
		}
	}
	return false;
}

// The crossings that start on `level`. A portal with several exits may let a
// hero out at any of them. The walker's map keeps its entries in place as it
// grows.
const std::vector<Crossing> &level_crossings(State &state, DictRef session, DictRef context, const Walker &walker, int64_t level, int64_t width) {
	const auto cached = walker.crossings.find(level);
	if (cached != walker.crossings.end()) {
		return cached->second;
	}
	std::vector<Crossing> &crossings = walker.crossings[level];
	const DictRef surface = ai_hero_rules::_level_surface(state, session, context, level);
	const Value gates = state.get(surface, str(key::gates), Value());
	if (gd::is_dict(gates)) {
		for (const Value &gate_tile : gd::items(state, gates)) {
			const Value gate = gd::index(state, gates.ref, gate_tile);
			const Value far_exits = ai::vget(state, gate, key::far_exits, Value());
			const ArrayRef exits = gd::is_array(far_exits) ? far_exits.ref : state.new_array();
			if (!gd::is_array(far_exits)) {
				state.append(exits, ai::vmember(state, gate, key::exit));
			}
			for (const Value &exit : gd::items(state, array_value(exits))) {
				if (gd::is_vector3i(exit)) {
					crossings.push_back(Crossing{gd::to_int(state, gate_tile), exit.vx(), exit.vy(), exit.vz()});
				}
			}
		}
	}
	const Value portals = state.get(surface, str(key::portals), Value());
	if (gd::is_dict(portals)) {
		for (const Value &portal_tile : gd::items(state, portals)) {
			for (const Value &exit : gd::items(state, ai::vmember(state, gd::index(state, portals.ref, portal_tile), key::exits))) {
				const int64_t exit_tile = gd::to_int(state, exit);
				crossings.push_back(Crossing{gd::to_int(state, portal_tile), compat::int_mod(exit_tile, width), exit_tile / width, level});
			}
		}
	}
	return crossings;
}

void copy_ints(const State &state, PackedRef packed, std::vector<int32_t> &out) {
	const int32_t *items = gd::packed_ints(state, packed);
	const int64_t size = gd::packed_size(state, packed);
	out.assign(items, items + size);
}

void copy_bytes(const State &state, PackedRef packed, std::vector<uint8_t> &out) {
	const uint8_t *items = gd::packed_bytes(state, packed);
	const int64_t size = gd::packed_size(state, packed);
	out.assign(items, items + size);
}

// The steps from (x, y) on `level` to each tile the walker gets to, on every
// level, walked as a route: eight ways over the ground it gets to (the guards it
// beats fought on the way, `_level_stretches`) and through gates, portals and
// monoliths at one step for each crossing, onto the ground beyond it. -1 where
// it does not get within the days the threat checks look ahead. `homes` is the
// ground it stands on. One walk for each hostile hero where it stands, kept for
// the turn as the danger zones are. Until 2026-11-06 the threat checks drew
// straight lines between up to two crossings, over the walls and water a walk
// goes round: in m005 of that day's batch (ai-match-2718070196) Veilmourn's main
// hero counted as a day from 11 of Thornwake's 13 towns, 32 to 57 tiles away,
// that its own route search put 70 to 121 tiles away.
ArrayRef threat_steps(State &state, DictRef session, DictRef context, const Walker &walker, int64_t x, int64_t y, int64_t level, const std::vector<int64_t> &homes) {
	const int64_t days = compat::engine_max<int64_t>(tunable_int(state, key::DEFENSE_HORIZON_DAYS), 1);
	const int64_t margin = compat::engine_max<int64_t>(tunable_int(state, key::THREAT_REACH_MARGIN), 1);
	const int64_t horizon = compat::engine_max<int64_t>(walker.limit, gd::add(gd::mul(walker.reach, days), margin));
	// Each guard beaten during the turn opens ground (`_level_stretches`).
	Value resolved;
	const bool listed = state.lookup(session_view::overworld(state, session), str(key::resolved_encounters), resolved) && gd::is_array(resolved);
	std::string text = gd::text(state, str(walker.id));
	for (const int64_t part : {x, y, level, horizon, compat::float_to_int(walker.power), listed ? state.array_size(resolved.ref) : int64_t(0)}) {
		text += ' ';
		text += std::to_string(part);
	}
	text += ' ';
	text += gd::text(state, str(ai::string_or_empty(state, walker.entry, key::walker_side)));
	const Atom steps_key = state.intern(text);
	Value found;
	const DictRef cache = state.lookup(context, str(key::threat_steps), found) ? gd::as_dict(found) : state.new_dict();
	if (state.lookup(cache, str(steps_key), found)) {
		return gd::as_array(found);
	}
	const Vector2i size = context_map_size(state, context);
	const int64_t width = size.x;
	const int64_t height = size.y;
	const int64_t count = width > 0 && height > 0 ? gd::mul(width, height) : 0;
	const int64_t levels = count > 0 ? compat::engine_max<int64_t>(level_rules::level_count(state, session), 0) : 0;
	const size_t level_slots = static_cast<size_t>(levels);
	// Each level's ground as the walker gets to it: a tile's patch, a patch's
	// stretch, the rock for corner steps and the crossings by the tile they
	// start on.
	std::vector<std::vector<int32_t>> patches(level_slots);
	std::vector<std::vector<int32_t>> stretches(level_slots);
	std::vector<std::vector<uint8_t>> blocked(level_slots);
	std::vector<std::unordered_map<int64_t, std::vector<Crossing>>> crossings(level_slots);
	for (int64_t on = 0; on < levels; ++on) {
		const size_t slot = static_cast<size_t>(on);
		copy_ints(state, gd::as_ints(gd::index(state, ai_hero_rules::_level_regions(state, session, context, on), str(key::patches))), patches[slot]);
		copy_ints(state, ai_hero_rules::_level_stretches(state, session, context, on, walker.power, kAnyLoss, walker.entry), stretches[slot]);
		copy_bytes(state, gd::as_bytes(gd::index(state, ai_hero_rules::_level_surface(state, session, context, on), str(key::blocked))), blocked[slot]);
		for (const Crossing &crossing : level_crossings(state, session, context, walker, on, width)) {
			crossings[slot][crossing.tile].push_back(crossing);
		}
	}
	const bool native_corners = native_transit_rules::uses_native_adjacency(state, dict_value(session));
	// The stretch of a tile, by the name `_level_stretches` gives it (the lowest
	// tile it starts on), -1 on a tile no patch takes.
	const auto ground_of = [&](int64_t on, int64_t tile) -> int64_t {
		const std::vector<int32_t> &level_patches = patches[static_cast<size_t>(on)];
		if (tile < 0 || tile >= static_cast<int64_t>(level_patches.size())) {
			return -1;
		}
		const int32_t patch = level_patches[static_cast<size_t>(tile)];
		const std::vector<int32_t> &level_stretches = stretches[static_cast<size_t>(on)];
		if (patch < 0 || static_cast<size_t>(patch) >= level_stretches.size()) {
			return -1;
		}
		const int64_t name = level_stretches[static_cast<size_t>(patch)];
		return name >= 0 && name < count ? name : -1;
	};
	const auto rock = [&](int64_t on, int64_t tile) {
		const std::vector<uint8_t> &level_blocked = blocked[static_cast<size_t>(on)];
		return tile >= 0 && static_cast<size_t>(tile) < level_blocked.size() && level_blocked[static_cast<size_t>(tile)] != 0;
	};
	static constexpr int64_t kDx[8] = {1, -1, 0, 0, 1, 1, -1, -1};
	static constexpr int64_t kDy[8] = {0, 0, 1, -1, 1, -1, 1, -1};
	std::vector<std::vector<int32_t>> steps(level_slots, std::vector<int32_t>(static_cast<size_t>(count), -1));
	// The stretches it walks on each level: its own, and each one a crossing
	// brings it onto.
	std::vector<std::vector<uint8_t>> walks(level_slots, std::vector<uint8_t>(static_cast<size_t>(count), 0));
	std::vector<int64_t> queue;
	if (level >= 0 && level < levels && x >= 0 && y >= 0 && x < width && y < height) {
		const int64_t start = gd::add(gd::mul(y, width), x);
		steps[static_cast<size_t>(level)][static_cast<size_t>(start)] = 0;
		queue.push_back(gd::add(gd::mul(level, count), start));
		for (const int64_t home : homes) {
			if (home >= 0 && home < count) {
				walks[static_cast<size_t>(level)][static_cast<size_t>(home)] = 1;
			}
		}
	}
	for (size_t head = 0; head < queue.size(); ++head) {
		const int64_t on = queue[head] / count;
		const int64_t tile = queue[head] % count;
		std::vector<int32_t> &level_steps = steps[static_cast<size_t>(on)];
		const int32_t walked = level_steps[static_cast<size_t>(tile)];
		if (walked >= horizon) {
			continue;
		}
		const auto starting = crossings[static_cast<size_t>(on)].find(tile);
		if (starting != crossings[static_cast<size_t>(on)].end()) {
			for (const Crossing &crossing : starting->second) {
				if (crossing.exit_level < 0 || crossing.exit_level >= levels || crossing.exit_x < 0 || crossing.exit_y < 0 || crossing.exit_x >= width || crossing.exit_y >= height) {
					continue;
				}
				const int64_t exit = crossing.exit_y * width + crossing.exit_x;
				std::vector<int32_t> &exit_steps = steps[static_cast<size_t>(crossing.exit_level)];
				if (exit_steps[static_cast<size_t>(exit)] >= 0) {
					continue;
				}
				exit_steps[static_cast<size_t>(exit)] = walked + 1;
				const int64_t beyond = ground_of(crossing.exit_level, exit);
				if (beyond >= 0) {
					walks[static_cast<size_t>(crossing.exit_level)][static_cast<size_t>(beyond)] = 1;
				}
				queue.push_back(crossing.exit_level * count + exit);
			}
		}
		const int64_t cx = tile % width;
		const int64_t cy = tile / width;
		for (int direction = 0; direction < 8; ++direction) {
			const int64_t nx = cx + kDx[direction];
			const int64_t ny = cy + kDy[direction];
			if (nx < 0 || ny < 0 || nx >= width || ny >= height) {
				continue;
			}
			const int64_t next = ny * width + nx;
			if (level_steps[static_cast<size_t>(next)] >= 0) {
				continue;
			}
			const int64_t there = ground_of(on, next);
			if (there < 0 || walks[static_cast<size_t>(on)][static_cast<size_t>(there)] == 0) {
				continue;
			}
			if (nx != cx && ny != cy && !native_corners && rock(on, cy * width + nx) && rock(on, ny * width + cx)) {
				continue;
			}
			level_steps[static_cast<size_t>(next)] = walked + 1;
			queue.push_back(on * count + next);
		}
	}
	const ArrayRef result = state.new_array();
	for (int64_t on = 0; on < levels; ++on) {
		const PackedRef level_steps = gd::new_ints(state);
		state.packed_write(level_steps).ints = std::move(steps[static_cast<size_t>(on)]);
		state.append(result, gd::ints_value(level_steps));
	}
	state.set(cache, str(steps_key), array_value(result));
	state.set(context, str(key::threat_steps), dict_value(cache));
	return result;
}

// The walk's steps to `tile` on `level`, -1 where it does not get.
int64_t step_at(State &state, ArrayRef steps, int64_t level, int64_t tile) {
	if (level < 0 || level >= state.array_size(steps)) {
		return -1;
	}
	const PackedRef level_steps = gd::as_ints(state.at(steps, level));
	if (tile < 0 || tile >= gd::packed_size(state, level_steps)) {
		return -1;
	}
	return gd::packed_int(state, level_steps, tile);
}

// Tiles from (x, y) on `level` to a town's doorway as a hostile hero walks there
// (`Walker`): on foot the route it walks (`threat_steps`), at sea or once it can
// sail a straight line over the ground it gets to, or the shortest way through
// one or two gates, portals or monoliths, one tile for each crossing and each leg
// a straight line over the ground it gets to there. -1 when no such way lies
// within the walker's limit. A hostile hero threatens towns on either level, but
// behind a guard it cannot beat a doorway a few tiles off is out of its reach. A
// doorway on its level beyond the limit, with no crossing within the limit of
// the walker to shorten the way, is counted in a straight line.
int64_t steps_to_door(State &state, DictRef session, DictRef context, int64_t x, int64_t y, int64_t level, DictRef entrance, const Walker &walker) {
	const int64_t door_x = gd::int_field(state, entrance, key::x, 0);
	const int64_t door_y = gd::int_field(state, entrance, key::y, 0);
	const int64_t door_level = level_rules::level_of(state, dict_value(entrance));
	const int64_t straight = tile_distance(x, door_x, y, door_y);
	const int64_t width = context_map_size(state, context).x;
	if (width <= 0) {
		return level == door_level ? straight : -1;
	}
	const auto to_crossing = [&](const Crossing &crossing) {
		return gd::add(tile_distance(x, compat::int_mod(crossing.tile, width), y, crossing.tile / width), 1);
	};
	const bool far = level == door_level && straight > walker.limit;
	if (far) {
		const std::vector<Crossing> &near = level_crossings(state, session, context, walker, level, width);
		if (std::none_of(near.begin(), near.end(), [&](const Crossing &crossing) { return to_crossing(crossing) <= walker.limit; })) {
			return straight;
		}
	}
	// The ground the walker stands on. At sea, or once it can sail, it may land
	// anywhere on its level; past a crossing it walks.
	const std::vector<int64_t> homes = ai_hero_rules::_home_stretches(state, session, context, level, gd::add(gd::mul(y, width), x), walker.id, walker.power, kAnyLoss, walker.entry);
	const bool afloat = walker.two_days ? takes_ship(state, session, context, walker, x, y, level, homes) : homes.empty();
	if (!afloat) {
		const int64_t walked = step_at(state, threat_steps(state, session, context, walker, x, y, level, homes), door_level, gd::add(gd::mul(door_y, width), door_x));
		return walked >= 0 && walked <= walker.limit ? walked : -1;
	}
	const auto stretch = [&](int64_t on_level, int64_t tile) {
		return ai_hero_rules::_tile_stretch(state, session, context, on_level, tile, walker.power, kAnyLoss, walker.entry);
	};
	const auto from_home = [&](int64_t tile) {
		const int64_t there = stretch(level, tile);
		return afloat || there < 0 || std::find(homes.begin(), homes.end(), there) != homes.end();
	};
	const auto same_ground = [&](int64_t on_level, int64_t from, int64_t to) {
		const int64_t start = stretch(on_level, from);
		const int64_t there = stretch(on_level, to);
		return start < 0 || there < 0 || start == there;
	};
	const int64_t door_tile = gd::add(gd::mul(door_y, width), door_x);
	if (level == door_level && !far && from_home(door_tile)) {
		return straight;
	}
	int64_t best = -1;
	const auto shorter = [&](int64_t steps) {
		return steps <= walker.limit && (best < 0 || steps < best);
	};
	for (const Crossing &first : level_crossings(state, session, context, walker, level, width)) {
		const int64_t to_exit = to_crossing(first);
		if (!shorter(to_exit) || !from_home(first.tile)) {
			continue;
		}
		const int64_t exit_tile = gd::add(gd::mul(first.exit_y, width), first.exit_x);
		if (first.exit_level == door_level) {
			const int64_t steps = gd::add(to_exit, tile_distance(first.exit_x, door_x, first.exit_y, door_y));
			if (shorter(steps) && same_ground(door_level, exit_tile, door_tile)) {
				best = steps;
			}
		}
		for (const Crossing &second : level_crossings(state, session, context, walker, first.exit_level, width)) {
			if (second.exit_level != door_level) {
				continue;
			}
			const int64_t steps = gd::add(gd::add(gd::add(to_exit, tile_distance(first.exit_x, compat::int_mod(second.tile, width), first.exit_y, second.tile / width)), 1), tile_distance(second.exit_x, door_x, second.exit_y, door_y));
			if (shorter(steps) && same_ground(first.exit_level, exit_tile, second.tile) && same_ground(door_level, gd::add(gd::mul(second.exit_y, width), second.exit_x), door_tile)) {
				best = steps;
			}
		}
	}
	return best >= 0 || !far ? best : straight;
}

// The way from a hostile hero of _hostile_heroes (threat.x, threat.y,
// threat.level) to a town's doorway within `limit` tiles, -1 when there is none.
int64_t threat_distance(State &state, DictRef session, DictRef context, const Value &threat, DictRef town, int64_t limit, bool two_days) {
	const int64_t threat_x = gd::to_int(state, ai::vmember(state, threat, key::x));
	const int64_t threat_y = gd::to_int(state, ai::vmember(state, threat, key::y));
	const int64_t threat_level = gd::to_int(state, ai::vget(state, threat, key::level, int_value(0)));
	const int64_t reach = gd::to_int(state, ai::vget(state, threat, key::reach, int_value(10)));
	const Walker walker = threat_walker(state, gd::stringify(state, ai::vmember(state, threat, key::id)), gd::stringify(state, ai::vget(state, threat, key::owner, str(key::empty))), gd::to_float(ai::vmember(state, threat, key::power)), reach, limit, two_days);
	return steps_to_door(state, session, context, threat_x, threat_y, threat_level, level_rules::town_entrance(state, town), walker);
}

// A hero keeps the field role this long after the towns that called for it
// are lost: towns change hands often, and a role changed every day sent heroes
// back and forth between a field army's errands and a courier's.
constexpr int64_t kFieldRoleDays = 7;

// The day a hero's field role lapses (`_assign_field_heroes`), -1 when it has none.
int64_t field_until(State &state, const Value &hero) {
	const Value block = ai::vget(state, hero, key::ai_hero, dict_value(state.new_dict()));
	return gd::to_int(state, ai::vget(state, block, key::field_until, int_value(-1)));
}

// The heroes other than the main hero in the order the field roles go out:
// the most experienced first, then the strongest.
ArrayRef ranked_lesser_heroes(State &state, DictRef session, Atom controller) {
	const Atom main_id = ai_hero_rules::_main_hero_id(state, session, controller);
	const ArrayRef others = state.new_array();
	for (const Value &hero : gd::items(state, array_value(ai_hero_rules::active_hero_entries(state, session, controller)))) {
		if (gd::stringify(state, ai::vget(state, hero, key::placement_id, str(key::empty))) != main_id) {
			state.append(others, hero);
		}
	}
	gd::sort_custom(state, others, [&state](const Value &x, const Value &y) {
		const DictRef a = gd::as_dict(x);
		const DictRef b = gd::as_dict(y);
		const int64_t xp_a = experience_of(state, a);
		const int64_t xp_b = experience_of(state, b);
		if (xp_a != xp_b) {
			return xp_a > xp_b;
		}
		const double power_a = ai_hero_rules::hero_power(state, a);
		const double power_b = ai_hero_rules::hero_power(state, b);
		if (!gd::is_equal_approx(power_a, power_b)) {
			return power_a > power_b;
		}
		const Atom id_a = ai::string_or_empty(state, a, key::placement_id);
		const Atom id_b = ai::string_or_empty(state, b, key::placement_id);
		return state.text(id_a) < state.text(id_b);
	});
	return others;
}

} // namespace

namespace ai_hero_rules {

ArrayRef _field_hero_ids(State &state, DictRef session, Atom controller) {
	const int64_t day = ai::session_int(state, session, key::day);
	const ArrayRef ids = state.new_array();
	for (const Value &hero : gd::items(state, array_value(ranked_lesser_heroes(state, session, controller)))) {
		if (field_until(state, hero) >= day) {
			state.append(ids, str(gd::stringify(state, ai::vget(state, hero, key::placement_id, str(key::empty)))));
		}
	}
	return ids;
}

void _assign_field_heroes(State &state, DictRef session, Atom controller) {
	const int64_t towns = state.array_size(enemy_turn_rules::_owned_town_entries(state, session, controller));
	const int64_t slots = gd::sub(towns, 1);
	const int64_t day = ai::session_int(state, session, key::day);
	// The field armies keep their places; the most experienced of the others
	// take the places left.
	const ArrayRef ranked = ranked_lesser_heroes(state, session, controller);
	const ArrayRef ordered = state.new_array();
	for (const Value &hero : gd::items(state, array_value(ranked))) {
		if (field_until(state, hero) >= day) {
			state.append(ordered, hero);
		}
	}
	for (const Value &hero : gd::items(state, array_value(ranked))) {
		if (field_until(state, hero) < day) {
			state.append(ordered, hero);
		}
	}
	const int64_t count = compat::engine_min<int64_t>(slots, state.array_size(ordered));
	for (int64_t at = 0; at < count; ++at) {
		const DictRef block = dict_or_new(state, state.at(ordered, at).ref, key::ai_hero);
		state.set(block, str(key::field_until), int_value(gd::add(day, kFieldRoleDays)));
	}
}

ArrayRef _decision_field_ids(State &state, DictRef session, DictRef context) {
	const DictRef cache = dict_or_new(state, context, key::decision);
	if (!state.has(cache, str(key::field))) {
		state.set(cache, str(key::field), array_value(_field_hero_ids(state, session, context_controller(state, context))));
		state.set(context, str(key::decision), dict_value(cache));
	}
	return gd::as_array(gd::index(state, cache, str(key::field)));
}

// The least experienced RAIDER_FIELD_SHARE of the field armies, at least one
// when the share is above zero, raid: they go after rivals' sites and do not
// join the main army.
bool _is_raider(State &state, DictRef session, DictRef context, DictRef entry) {
	const double share = tunable_float(state, key::RAIDER_FIELD_SHARE);
	if (share <= 0.0) {
		return false;
	}
	const ArrayRef ids = _decision_field_ids(state, session, context);
	const int64_t count = state.array_size(ids);
	const int64_t raiders = static_cast<int64_t>(std::ceil(static_cast<double>(count) * share));
	const Atom id = ai::string_or_empty(state, entry, key::placement_id);
	for (int64_t at = count - raiders; at < count; ++at) {
		if (gd::stringify(state, state.at(ids, at)) == id) {
			return true;
		}
	}
	return false;
}

double _main_shortfall(State &state, DictRef session, DictRef context, DictRef main) {
	const DictRef cache = dict_or_new(state, context, key::decision);
	Value cached;
	if (state.lookup(cache, str(key::shortfall), cached)) {
		return gd::to_float(cached);
	}
	const Atom controller = context_controller(state, context);
	const double power = hero_power(state, main);
	double need = kInf;
	if (!state.has(cache, str(key::hostile))) {
		state.set(cache, str(key::hostile), array_value(_hostile_heroes(state, session, context)));
	}
	state.set(context, str(key::decision), dict_value(cache));
	Value ai_hero;
	const bool has_block = state.lookup(main, str(key::ai_hero), ai_hero);
	// A rival hero the main army's preview lost to needs what the preview found,
	// however beatable the estimate rates it (_note_vetoed_need).
	Value vetoed;
	const bool has_vetoed = has_block && gd::is_dict(ai_hero) && state.lookup(ai_hero.ref, str(key::vetoed_needs), vetoed) && gd::is_dict(vetoed);
	// In sight, or seen out there in the last few days.
	state::ValueList threats = gd::items(state, gd::index(state, cache, str(key::hostile))).list();
	for (const Value &threat : gd::items(state, array_value(_recent_hostiles(state, session, context))).list()) {
		threats.push_back(threat);
	}
	for (const Value &threat : threats) {
		const double threat_power = gd::to_float(ai::vmember(state, threat, key::power));
		double required = threat_power * tunable_float(state, key::HERO_ATTACK_RATIO);
		if (has_vetoed) {
			required = compat::engine_max(required, gd::to_float(state.get(vetoed.ref, ai::vmember(state, threat, key::id), float_value(0.0))));
		}
		if (required > power) {
			need = compat::engine_min(need, required);
		}
	}
	for (const Value &town : gd::field_items(state, session_view::overworld(state, session), str(key::towns))) {
		if (!gd::is_dict(town)) {
			continue;
		}
		const Atom owner = string_or(state, town.ref, key::owner, key::neutral);
		if (owner == key::neutral || (owner == key::enemy && player_rules::allied(state, dict_value(session), controller, player_rules::town_controller_id(state, town.ref)))) {
			continue;
		}
		if (owner == key::player && player_rules::allied(state, dict_value(session), controller, key::player)) {
			continue;
		}
		double defense = power_of(state, field_or_new_array(state, town.ref, key::garrison));
		const int64_t defender_index = _town_hero_defender_index(state, session, town.ref, controller);
		if (defender_index >= 0) {
			const Value encounters = gd::index(state, session_view::overworld(state, session), str(key::encounters));
			defense += hero_power(state, gd::as_dict(ai::vindex(state, encounters, int_value(defender_index))));
		}
		const double required = defense * tunable_float(state, key::TOWN_ATTACK_RATIO);
		if (required > power) {
			need = compat::engine_min(need, required);
		}
	}
	// A guard the main army found in its way to a rival town and could not beat.
	double blocked = 0.0;
	if (has_block) {
		blocked = gd::to_float(ai::vget(state, ai_hero, key::blocked_need, float_value(0.0)));
	}
	if (blocked > power) {
		need = compat::engine_min(need, blocked);
	}
	const double shortfall = need == kInf ? 0.0 : need - power;
	state.set(cache, str(key::shortfall), float_value(shortfall));
	state.set(context, str(key::decision), dict_value(cache));
	return shortfall;
}

int64_t _towns_held_by(State &state, DictRef session, Atom owner, Atom controller) {
	int64_t count = 0;
	for (const Value &town : gd::field_items(state, session_view::overworld(state, session), str(key::towns))) {
		if (!gd::is_dict(town) || ai::string_or_empty(state, town.ref, key::owner) != owner) {
			continue;
		}
		if (owner == key::player || player_rules::town_controller_id(state, town.ref) == controller) {
			count = gd::add(count, 1);
		}
	}
	return count;
}

double _knockout_value(State &state, DictRef session, Atom owner, Atom controller, double garrison_power) {
	double power = garrison_power;
	if (owner == key::player) {
		Value heroes;
		if (state.lookup(session_view::overworld(state, session), str(key::player_heroes), heroes) && gd::is_array(heroes)) {
			for (const Value &hero : gd::items(state, heroes)) {
				if (!gd::is_dict(hero)) {
					continue;
				}
				const Value army = state.get(hero.ref, str(key::army), dict_value(state.new_dict()));
				const Value stacks = gd::is_dict(army) ? state.get(army.ref, str(key::stacks), array_value(state.new_array())) : array_value(state.new_array());
				power += army_power(state, stacks, hero);
			}
		}
	} else {
		for (const Value &entry : gd::items(state, array_value(active_hero_entries(state, session, controller)))) {
			power += hero_power(state, gd::as_dict(entry));
		}
	}
	return power * tunable_float(state, key::TROOP_VALUE_PER_POWER);
}

bool _knockout_wins(State &state, DictRef session, DictRef context, Atom owner, Atom controller) {
	if (!player_elimination_rules::applies(state, session)) {
		return false;
	}
	const DictRef overworld = session_view::overworld(state, session);
	const Atom self = context_controller(state, context);
	const Atom rival = owner == key::player ? key::player : controller;
	bool listed = false;
	for (const Value &player : gd::field_items(state, overworld, str(key::players))) {
		if (!gd::is_dict(player)) {
			continue;
		}
		// The human's towns and heroes are the player's (`_towns_held_by`).
		const bool human = gd::bool_field(state, player.ref, key::human, false);
		const Atom other = human ? key::player : ai::string_or_empty(state, player.ref, key::player_id);
		if (other == rival) {
			listed = true;
			continue;
		}
		if (other == self || player_rules::allied(state, dict_value(session), self, other)) {
			continue;
		}
		// Still in the game: it holds a town or a hero (PlayerEliminationRules).
		if (_towns_held_by(state, session, human ? key::player : key::enemy, other) > 0) {
			return false;
		}
		int64_t heroes = 0;
		if (human) {
			Value player_heroes;
			if (state.lookup(overworld, str(key::player_heroes), player_heroes)) {
				heroes = ai::vsize(state, player_heroes);
			}
		} else {
			heroes = active_hero_count(state, session, other);
		}
		if (heroes > 0) {
			return false;
		}
	}
	return listed;
}

double _last_stand_share(State &state, DictRef session, DictRef context, Atom owner, Atom controller) {
	if (_towns_held_by(state, session, owner, controller) > 0) {
		return 0.0;
	}
	int64_t heroes = 0;
	if (owner == key::player) {
		Value player_heroes;
		if (state.lookup(session_view::overworld(state, session), str(key::player_heroes), player_heroes)) {
			heroes = ai::vsize(state, player_heroes);
		}
	} else {
		heroes = state.array_size(active_hero_entries(state, session, controller));
	}
	// Its last hero knocks it out: worth everything it still has, the game when
	// it is the last rival.
	if (heroes == 1) {
		double value = _knockout_value(state, session, owner, controller, 0.0);
		if (_knockout_wins(state, session, context, owner, controller)) {
			value += kVictoryValue;
		}
		return value;
	}
	return tunable_float(state, key::ELIMINATION_VALUE) / static_cast<double>(compat::engine_max<int64_t>(1, heroes));
}

double _burst_share(State &state, DictRef entry, const Value &commander) {
	if (!gd::is_dict(commander) || gd::is_empty(state, commander.ref)) {
		return 0.0;
	}
	double health = 0.0;
	Value army;
	if (state.lookup(entry, str(key::enemy_army), army) && gd::is_dict(army)) {
		for (const Value &stack : gd::field_items(state, army.ref, str(key::stacks))) {
			if (gd::is_dict(stack)) {
				const DictRef unit = gd::content_row(state, ContentTable::Unit, ai::string_or_empty(state, stack.ref, key::unit_id));
				const double hp = gd::to_float(state.get(unit, str(key::hp), int_value(1)));
				const double count = static_cast<double>(gd::int_field(state, stack.ref, key::count, 0));
				health += hp * count;
			}
		}
	}
	if (health <= 0.0) {
		return 0.0;
	}
	return compat::engine_min(1.0, _spell_burst(state, commander.ref) / health);
}

double _spell_burst(State &state, DictRef commander) {
	Value spellbook;
	if (!state.lookup(commander, str(key::spellbook), spellbook) || !gd::is_dict(spellbook)) {
		return 0.0;
	}
	// Its known spells and those its worn scrolls lend.
	const ArrayRef known = spell_rules::castable_spell_ids(state, commander);
	if (state.array_size(known) == 0) {
		return 0.0;
	}
	int64_t mana = 0;
	Value mana_state;
	if (state.lookup(spellbook.ref, str(key::mana), mana_state) && gd::is_dict(mana_state)) {
		const Value max_mana = state.get(mana_state.ref, str(key::max), int_value(0));
		mana = gd::to_int(state, state.get(mana_state.ref, str(key::current), max_mana));
	}
	int64_t command_power = 0;
	Value command;
	if (state.lookup(commander, str(key::command), command) && gd::is_dict(command)) {
		command_power = gd::int_field(state, command.ref, key::power, 0);
	}
	const int64_t power = compat::engine_max<int64_t>(0, command_power);
	double best = 0.0;
	for (const Value &spell_id : gd::items(state, array_value(known))) {
		const DictRef spell = gd::content_row(state, ContentTable::Spell, gd::stringify(state, spell_id));
		Value effect;
		const bool has_effect = state.lookup(spell, str(key::effect), effect) && gd::is_dict(effect);
		if (ai::string_or_empty(state, spell, key::context) != key::battle || (has_effect ? ai::string_or_empty(state, effect.ref, key::type) : key::empty) != key::damage_enemy) {
			continue;
		}
		if (gd::int_field(state, spell, key::mana_cost, 1) > mana) {
			continue;
		}
		const int64_t base_damage = gd::int_field(state, effect.ref, key::base_damage, 0);
		const int64_t power_scale = gd::int_field(state, effect.ref, key::power_scale, 0);
		best = compat::engine_max(best, static_cast<double>(gd::add(base_damage, gd::mul(power, power_scale))));
	}
	return best;
}

Atom _main_hero_id(State &state, DictRef session, Atom controller) {
	// The most experienced hero leads, among those still holding a real army.
	const ArrayRef heroes = active_hero_entries(state, session, controller);
	double strongest = 0.0;
	for (const Value &hero : gd::items(state, array_value(heroes))) {
		strongest = compat::engine_max(strongest, hero_power(state, gd::as_dict(hero)));
	}
	Atom best_id = key::empty;
	int64_t best_experience = -1;
	double best_power = -1.0;
	for (const Value &hero_value : gd::items(state, array_value(heroes))) {
		const DictRef hero = gd::as_dict(hero_value);
		const double power = hero_power(state, hero);
		if (power < strongest * tunable_float(state, key::MAIN_ARMY_SHARE)) {
			continue;
		}
		const int64_t experience = experience_of(state, hero);
		bool better = experience > best_experience;
		if (experience == best_experience) {
			better = power > best_power;
			if (!better && gd::is_equal_approx(power, best_power)) {
				const Atom id = ai::string_or_empty(state, hero, key::placement_id);
				better = state.text(id) < state.text(best_id);
			}
		}
		if (better) {
			best_experience = experience;
			best_power = power;
			best_id = ai::string_or_empty(state, hero, key::placement_id);
		}
	}
	return best_id;
}

int64_t _weakest_stack_index(State &state, ArrayRef stacks) {
	int64_t best = 0;
	double best_power = kInf;
	const int64_t size = state.array_size(stacks);
	for (int64_t index = 0; index < size; ++index) {
		const ArrayRef one = state.new_array();
		state.append(one, state.at(stacks, index));
		const double power = power_of(state, array_value(one));
		if (power < best_power) {
			best_power = power;
			best = index;
		}
	}
	return best;
}

PackedRef _danger_zone(State &state, DictRef session, DictRef context, const Value &threat, int64_t level) {
	const Atom id = gd::stringify(state, ai::vmember(state, threat, key::id));
	const Atom side = gd::stringify(state, ai::vget(state, threat, key::owner, str(key::empty)));
	const int64_t threat_x = gd::to_int(state, ai::vmember(state, threat, key::x));
	const int64_t threat_y = gd::to_int(state, ai::vmember(state, threat, key::y));
	const int64_t threat_level = gd::to_int(state, ai::vget(state, threat, key::level, int_value(0)));
	const int64_t reach = gd::to_int(state, ai::vget(state, threat, key::reach, int_value(10)));
	const double power = gd::to_float(ai::vmember(state, threat, key::power));
	// Each guard beaten during the turn opens ground (`_level_stretches`).
	Value resolved;
	const bool listed = state.lookup(session_view::overworld(state, session), str(key::resolved_encounters), resolved) && gd::is_array(resolved);
	std::string text = gd::text(state, str(id));
	for (const int64_t part : {threat_x, threat_y, threat_level, level, reach, compat::float_to_int(power), listed ? state.array_size(resolved.ref) : int64_t(0)}) {
		text += ' ';
		text += std::to_string(part);
	}
	text += ' ';
	text += gd::text(state, str(side));
	const Atom zone_key = state.intern(text);
	Value found;
	const DictRef cache = state.lookup(context, str(key::danger_zones), found) ? gd::as_dict(found) : state.new_dict();
	if (state.lookup(cache, str(zone_key), found)) {
		return gd::as_bytes(found);
	}
	const Vector2i size = context_map_size(state, context);
	const int64_t width = size.x;
	const PackedRef zone = gd::new_bytes(state);
	gd::packed_resize(state, zone, compat::engine_max<int64_t>(0, gd::mul(width, size.y)));
	if (width > 0 && size.y > 0) {
		const int64_t limit = gd::add(reach, 1);
		const Walker walker = threat_walker(state, id, side, power, reach, limit, false);
		// A level's ground as the walker gets to it: a tile's stretch, -1 on a
		// tile no patch takes (`_tile_stretch`).
		struct Ground {
			PackedRef patches;
			PackedRef stretches;
			int64_t count;
		};
		const auto ground = [&](int64_t on_level) {
			const PackedRef patches = gd::as_ints(gd::index(state, ai_hero_rules::_level_regions(state, session, context, on_level), str(key::patches)));
			return Ground{patches, ai_hero_rules::_level_stretches(state, session, context, on_level, power, kAnyLoss, walker.entry), gd::packed_size(state, patches)};
		};
		const auto stretch = [&](const Ground &on, int64_t tile) -> int64_t {
			if (tile < 0 || tile >= on.count) {
				return -1;
			}
			const int64_t patch = gd::packed_int(state, on.patches, tile);
			return patch < 0 ? -1 : gd::packed_int(state, on.stretches, patch);
		};
		const Ground start = ground(threat_level);
		const std::vector<int64_t> homes = ai_hero_rules::_home_stretches(state, session, context, threat_level, gd::add(gd::mul(threat_y, width), threat_x), id, power, kAnyLoss, walker.entry);
		const bool afloat = homes.empty();
		// On foot: the tiles its walk gets to (`threat_steps`).
		if (!afloat) {
			const ArrayRef steps = threat_steps(state, session, context, walker, threat_x, threat_y, threat_level, homes);
			if (level >= 0 && level < state.array_size(steps)) {
				const PackedRef level_steps = gd::as_ints(state.at(steps, level));
				const int64_t tiles = compat::engine_min<int64_t>(gd::packed_size(state, level_steps), gd::packed_size(state, zone));
				for (int64_t tile = 0; tile < tiles; ++tile) {
					const int64_t walked = gd::packed_int(state, level_steps, tile);
					if (walked >= 0 && walked <= limit) {
						gd::packed_set(state, zone, tile, 1);
					}
				}
			}
			state.set(cache, str(zone_key), gd::bytes_value(zone));
			state.set(context, str(key::danger_zones), dict_value(cache));
			return zone;
		}
		const auto from_home = [&](int64_t tile) {
			const int64_t there = stretch(start, tile);
			return afloat || there < 0 || std::find(homes.begin(), homes.end(), there) != homes.end();
		};
		// The tiles `steps` or fewer from (x, y) on the walker's own ground, or
		// past a crossing on the ground of the tile `from` there.
		const auto spread = [&](const Ground &on, int64_t x, int64_t y, int64_t steps, int64_t from, bool home) {
			const int64_t own = home ? -1 : stretch(on, from);
			for (int64_t ty = compat::engine_max<int64_t>(0, gd::sub(y, steps)); ty <= compat::engine_min<int64_t>(size.y - 1, gd::add(y, steps)); ++ty) {
				for (int64_t tx = compat::engine_max<int64_t>(0, gd::sub(x, steps)); tx <= compat::engine_min<int64_t>(width - 1, gd::add(x, steps)); ++tx) {
					const int64_t tile = gd::add(gd::mul(ty, width), tx);
					const int64_t there = home ? 0 : stretch(on, tile);
					if (home ? from_home(tile) : (own < 0 || there < 0 || there == own)) {
						gd::packed_set(state, zone, tile, 1);
					}
				}
			}
		};
		if (threat_level == level) {
			spread(start, threat_x, threat_y, limit, -1, true);
		}
		const Ground target = threat_level == level ? start : ground(level);
		for (const Crossing &first : level_crossings(state, session, context, walker, threat_level, width)) {
			const int64_t to_exit = gd::add(tile_distance(threat_x, compat::int_mod(first.tile, width), threat_y, first.tile / width), 1);
			if (to_exit > limit || !from_home(first.tile)) {
				continue;
			}
			const int64_t exit_tile = gd::add(gd::mul(first.exit_y, width), first.exit_x);
			if (first.exit_level == level) {
				spread(target, first.exit_x, first.exit_y, gd::sub(limit, to_exit), exit_tile, false);
			}
			const Ground between = ground(first.exit_level);
			for (const Crossing &second : level_crossings(state, session, context, walker, first.exit_level, width)) {
				if (second.exit_level != level) {
					continue;
				}
				const int64_t steps = gd::add(gd::add(to_exit, tile_distance(first.exit_x, compat::int_mod(second.tile, width), first.exit_y, second.tile / width)), 1);
				const int64_t landed = stretch(between, exit_tile);
				const int64_t onward = stretch(between, second.tile);
				if (steps > limit || !(landed < 0 || onward < 0 || landed == onward)) {
					continue;
				}
				spread(target, second.exit_x, second.exit_y, gd::sub(limit, steps), gd::add(gd::mul(second.exit_y, width), second.exit_x), false);
			}
		}
	}
	state.set(cache, str(zone_key), gd::bytes_value(zone));
	state.set(context, str(key::danger_zones), dict_value(cache));
	return zone;
}

bool _town_threatened(State &state, DictRef session, DictRef context, DictRef town) {
	const DictRef cache = dict_or_new(state, context, key::decision);
	const Atom threat_key = gd::format(state, key::threat_s, {str(ai::string_or_empty(state, town, key::placement_id))});
	Value cached;
	if (state.lookup(cache, str(threat_key), cached)) {
		return gd::to_bool(cached);
	}
	if (!state.has(cache, str(key::hostile))) {
		state.set(cache, str(key::hostile), array_value(_hostile_heroes(state, session, context)));
	}
	state.set(context, str(key::decision), dict_value(cache));
	const double defense = power_of(state, field_or_new_array(state, town, key::garrison));
	bool threatened = false;
	double strongest = 0.0;
	// In sight, or seen out there in the last few days.
	state::ValueList threats = gd::items(state, gd::index(state, cache, str(key::hostile))).list();
	for (const Value &threat : gd::items(state, array_value(_recent_hostiles(state, session, context))).list()) {
		threats.push_back(threat);
	}
	for (const Value &threat : threats) {
		if (gd::to_float(ai::vmember(state, threat, key::power)) <= defense * tunable_float(state, key::THREAT_RATIO)) {
			continue;
		}
		const int64_t reach = gd::add(gd::to_int(state, ai::vget(state, threat, key::reach, int_value(10))), tunable_int(state, key::THREAT_REACH_MARGIN));
		const int64_t distance = threat_distance(state, session, context, threat, town, reach, false);
		if (distance >= 0 && distance <= reach) {
			threatened = true;
			const double threat_power = gd::to_float(ai::vmember(state, threat, key::power));
			if (threat_power > strongest) {
				strongest = threat_power;
				const Atom hero_key = gd::format(state, key::threat_hero_s, {str(ai::string_or_empty(state, town, key::placement_id))});
				state.set(cache, str(hero_key), threat);
			}
		}
	}
	state.set(cache, str(threat_key), bool_value(threatened));
	state.set(context, str(key::decision), dict_value(cache));
	return threatened;
}

DictRef _strongest_threat(State &state, DictRef session, DictRef context, DictRef town) {
	if (!_town_threatened(state, session, context, town)) {
		return state.new_dict();
	}
	Value decision;
	const bool has_decision = state.lookup(context, str(key::decision), decision);
	const Atom hero_key = gd::format(state, key::threat_hero_s, {str(ai::string_or_empty(state, town, key::placement_id))});
	if (!has_decision) {
		return state.new_dict();
	}
	if (!gd::is_dict(decision)) {
		(void)ai::vget(state, decision, hero_key);
	}
	Value found;
	if (state.lookup(decision.ref, str(hero_key), found)) {
		return gd::as_dict(found);
	}
	return state.new_dict();
}

// Whether this hero's being in the town is what keeps it safe: the strongest
// threat could storm it without the hero and not with it. One hero defends with
// the garrison, so another standing there may already cover it.
bool _keeps_town_safe(State &state, DictRef session, DictRef context, DictRef entry, DictRef town) {
	const DictRef threat = _strongest_threat(state, session, context, town);
	if (gd::is_empty(state, threat)) {
		return false;
	}
	const double threat_power = gd::to_float(gd::index(state, threat, str(key::power)));
	const double garrison = power_of(state, field_or_new_array(state, town, key::garrison));
	const double attack_ratio = tunable_float(state, key::TOWN_ATTACK_RATIO);
	const DictRef entrance = level_rules::town_entrance(state, town);
	const Atom own_id = ai::string_or_empty(state, entry, key::placement_id);
	double others = 0.0;
	for (const Value &other : gd::items(state, array_value(active_hero_entries(state, session, context_controller(state, context))))) {
		const DictRef hero = gd::as_dict(other);
		if (ai::string_or_empty(state, hero, key::placement_id) != own_id && level_rules::same_level(state, other, dict_value(town)) && gd::int_field(state, hero, key::x, -1) == gd::int_field(state, entrance, key::x, -2) && gd::int_field(state, hero, key::y, -1) == gd::int_field(state, entrance, key::y, -2)) {
			others = compat::engine_max(others, hero_power(state, hero));
		}
	}
	return threat_power >= (garrison + others) * attack_ratio && threat_power < (garrison + compat::engine_max(others, hero_power(state, entry))) * attack_ratio;
}

DictRef _leave_defense(State &state, DictRef session, DictRef context, DictRef town, ArrayRef stacks, ArrayRef garrison, bool is_main, double brought) {
	const DictRef unchanged = state.new_dict();
	state.set(unchanged, str(key::stacks), array_value(stacks));
	state.set(unchanged, str(key::garrison), array_value(garrison));
	const double need = _town_defense_need(state, session, context, town);
	double missing = need - power_of(state, array_value(garrison));
	const double ward_per_week = tunable_float(state, key::TOWN_WARD_PER_WEEK);
	if (missing <= 0.0 && ward_per_week <= 0.0) {
		return unchanged;
	}
	const double total = power_of(state, array_value(stacks));
	const double troops_share = total * (is_main ? tunable_float(state, key::DEFENSE_SHARE_MAX_MAIN) : tunable_float(state, key::DEFENSE_SHARE_MAX));
	const double worth = _town_worth(state, session, context, town);
	const double budget = compat::engine_min(troops_share, worth / tunable_float(state, key::TROOP_VALUE_PER_POWER));
	if (missing > budget) {
		return unchanged;
	}
	// A ward stays whether or not a threat is known, growing with the weeks of
	// the game: first what the town held, then a share of the hero's own army.
	if (ward_per_week > 0.0) {
		const double ward = ward_per_week * static_cast<double>(ai::session_int(state, session, key::day)) / 7.0;
		const double from_army = compat::engine_max(0.0, brought) * tunable_float(state, key::TOWN_WARD_ARMY_SHARE);
		const double from_town = compat::engine_max(0.0, total - brought);
		missing = compat::engine_max(missing, compat::engine_min(ward, from_town + from_army) - power_of(state, array_value(garrison)));
		if (missing <= 0.0) {
			return unchanged;
		}
	}
	const ArrayRef kept = gd::deep_duplicate_array(state, stacks);
	ArrayRef left = gd::deep_duplicate_array(state, garrison);
	const int64_t kept_size = state.array_size(kept);
	const ArrayRef order = state.new_array();
	for (int64_t index = 0; index < kept_size; ++index) {
		state.append(order, int_value(index));
	}
	gd::sort_custom(state, order, [&state, kept](const Value &a, const Value &b) {
		const double power_a = _unit_power(state, gd::as_dict(state.at(kept, gd::to_int(state, a))));
		const double power_b = _unit_power(state, gd::as_dict(state.at(kept, gd::to_int(state, b))));
		return power_a < power_b;
	});
	int64_t creatures = 0;
	for (const Value &stack : gd::items(state, array_value(kept))) {
		creatures = gd::add(creatures, gd::to_int(state, ai::vget(state, stack, key::count, int_value(0))));
	}
	for (const Value &stack_index : gd::items(state, array_value(order))) {
		if (missing <= 0.0) {
			break;
		}
		const DictRef stack = gd::as_dict(state.at(kept, gd::to_int(state, stack_index)));
		const double unit = _unit_power(state, stack);
		if (unit <= 0.0) {
			continue;
		}
		const int64_t wanted = compat::float_to_int(compat::godot_ceil(missing / unit));
		const int64_t count = gd::int_field(state, stack, key::count, 0);
		const int64_t take = compat::engine_min<int64_t>(wanted, compat::engine_min<int64_t>(count, gd::sub(creatures, 1)));
		if (take <= 0) {
			continue;
		}
		const DictRef addition = state.new_dict();
		state.set(addition, str(key::unit_id), str(ai::string_or_empty(state, stack, key::unit_id)));
		state.set(addition, str(key::count), int_value(take));
		const ArrayRef additions = state.new_array();
		state.append(additions, dict_value(addition));
		const DictRef placed = _merge_stacks_into(state, array_value(left), array_value(additions));
		Value placed_left;
		if (state.lookup(placed, str(key::left), placed_left) && !ai::vempty(state, placed_left)) {
			continue;
		}
		left = gd::as_array(gd::index(state, placed, str(key::stacks)));
		state.set(stack, str(key::count), int_value(gd::sub(gd::int_field(state, stack, key::count, 0), take)));
		creatures = gd::sub(creatures, take);
		missing -= unit * static_cast<double>(take);
	}
	if (missing > 0.0) {
		return unchanged;
	}
	const ArrayRef remaining = state.new_array();
	for (const Value &stack : gd::items(state, array_value(kept))) {
		if (gd::to_int(state, ai::vget(state, stack, key::count, int_value(0))) > 0) {
			state.append(remaining, stack);
		}
	}
	const DictRef result = state.new_dict();
	state.set(result, str(key::stacks), array_value(remaining));
	state.set(result, str(key::garrison), array_value(left));
	return result;
}

double _unit_power(State &state, DictRef stack) {
	const DictRef one = state.new_dict();
	state.set(one, str(key::unit_id), str(ai::string_or_empty(state, stack, key::unit_id)));
	state.set(one, str(key::count), int_value(1));
	const ArrayRef stacks = state.new_array();
	state.append(stacks, dict_value(one));
	return power_of(state, array_value(stacks));
}

double _town_defense_need(State &state, DictRef session, DictRef context, DictRef town) {
	const DictRef cache = dict_or_new(state, context, key::decision);
	if (!state.has(cache, str(key::hostile))) {
		state.set(cache, str(key::hostile), array_value(_hostile_heroes(state, session, context)));
		state.set(context, str(key::decision), dict_value(cache));
	}
	// Only a hostile hero that is seen or remembered calls for troops left
	// behind, on either level; a town no one threatens is held by the heroes,
	// which carry its troops where they are used.
	double strongest = 0.0;
	state::ValueList threats = gd::items(state, gd::index(state, cache, str(key::hostile))).list();
	for (const Value &threat : gd::items(state, array_value(_recent_hostiles(state, session, context))).list()) {
		threats.push_back(threat);
	}
	for (const Value &threat : threats) {
		const double power = gd::to_float(ai::vmember(state, threat, key::power));
		if (power <= strongest) {
			continue;
		}
		const int64_t reach = gd::add(gd::mul(gd::to_int(state, ai::vget(state, threat, key::reach, int_value(10))), tunable_int(state, key::DEFENSE_HORIZON_DAYS)), 1);
		const int64_t distance = threat_distance(state, session, context, threat, town, reach, true);
		if (distance >= 0 && distance <= reach) {
			strongest = power;
		}
	}
	double need = strongest * tunable_float(state, key::DEFENSE_MARGIN);
	need = need / tunable_float(state, key::TOWN_ATTACK_RATIO);
	const double raider = _townless_raider(state, session, context);
	double raider_need = raider * tunable_float(state, key::DEFENSE_MARGIN);
	raider_need = raider_need / tunable_float(state, key::TOWN_ATTACK_RATIO);
	return compat::engine_max(need, raider_need);
}

double _townless_raider(State &state, DictRef session, DictRef context) {
	const DictRef cache = dict_or_new(state, context, key::decision);
	Value cached;
	if (state.lookup(cache, str(key::townless_raider), cached)) {
		return gd::to_float(cached);
	}
	double strongest = 0.0;
	// A missing memory is GDScript's {}: nothing to walk either way.
	const Value memory = ai::vget(state, gd::index(state, context, str(key::state)), key::ai_sightings, Value());
	if (gd::is_dict(memory)) {
		std::unordered_map<Atom, std::unordered_set<Atom>> townless;
		const ArrayRef ids = gd::keys(state, memory.ref);
		for (const Value &id : gd::items(state, array_value(ids))) {
			const Value seen = gd::index(state, memory.ref, id);
			if (!gd::is_dict(seen)) {
				continue;
			}
			const Atom owner = ai::string_or_empty(state, seen.ref, key::owner);
			auto found = townless.find(owner);
			if (found == townless.end()) {
				std::unordered_set<Atom> heroes;
				if (_towns_held_by(state, session, owner == key::player ? key::player : key::enemy, owner) <= 0) {
					if (owner == key::player) {
						for (const Value &hero : gd::field_items(state, session_view::overworld(state, session), str(key::player_heroes))) {
							if (gd::is_dict(hero)) {
								heroes.insert(ai::string_or_empty(state, hero.ref, key::id));
							}
						}
					} else {
						for (const Value &entry : gd::items(state, array_value(active_hero_entries(state, session, owner)))) {
							heroes.insert(gd::stringify(state, ai::vget(state, entry, key::placement_id, str(key::empty))));
						}
					}
				}
				found = townless.emplace(owner, std::move(heroes)).first;
			}
			if (found->second.count(gd::stringify(state, id)) != 0) {
				strongest = compat::engine_max(strongest, gd::to_float(state.get(seen.ref, str(key::power), float_value(0.0))));
			}
		}
	}
	state.set(cache, str(key::townless_raider), float_value(strongest));
	state.set(context, str(key::decision), dict_value(cache));
	return strongest;
}

double _town_worth(State &state, DictRef session, DictRef context, DictRef town) {
	const DictRef cache = dict_or_new(state, context, key::town_worth);
	const Atom id = ai::string_or_empty(state, town, key::placement_id);
	Value cached;
	if (state.lookup(cache, str(id), cached)) {
		return gd::to_float(cached);
	}
	const double income_value = _build_value(state, overworld_rules::town_income(state, town, dict_value(session)));
	const double income = income_value * 7.0 * tunable_float(state, key::TOWN_HORIZON_WEEKS);
	const double troops_value = _recruit_set_value(state, _trial_growth(state, town));
	const double troops = troops_value * tunable_float(state, key::TOWN_HORIZON_WEEKS);
	const double worth = tunable_float(state, key::TOWN_BASE_VALUE) + income + troops;
	state.set(cache, str(id), float_value(worth));
	state.set(context, str(key::town_worth), dict_value(cache));
	return worth;
}

namespace {

// The share for a hostile hero of `side` at (x, y, level), `power` strong and
// going `movement_max` tiles a day.
double threatened_town_share_at(State &state, DictRef session, DictRef context, Atom id, Atom side, int64_t other_x, int64_t other_y, int64_t other_level, double power, int64_t movement_max) {
	double total = 0.0;
	const int64_t reach = compat::engine_max<int64_t>(tunable_int(state, key::THREAT_MIN_REACH), movement_max);
	const int64_t horizon = gd::add(gd::mul(reach, tunable_int(state, key::DEFENSE_HORIZON_DAYS)), tunable_int(state, key::THREAT_REACH_MARGIN));
	const Walker walker = threat_walker(state, id, side, power, reach, horizon, true);
	for (const Value &town : gd::field_items(state, session_view::overworld(state, session), str(key::towns))) {
		if (!gd::is_dict(town) || ai::string_or_empty(state, town.ref, key::owner) != key::enemy) {
			continue;
		}
		const Atom town_controller = player_rules::town_controller_id(state, town.ref);
		if (town_controller != context_controller(state, context)) {
			continue;
		}
		if (power <= power_of(state, field_or_new_array(state, town.ref, key::garrison)) * tunable_float(state, key::THREAT_RATIO)) {
			continue;
		}
		const int64_t distance = steps_to_door(state, session, context, other_x, other_y, other_level, level_rules::town_entrance(state, town.ref), walker);
		if (distance >= 0 && distance <= horizon) {
			total += _town_worth(state, session, context, town.ref) * tunable_float(state, key::THREAT_KILL_SHARE);
		}
	}
	return total;
}

} // namespace

// What killing a hostile hero saves: a share of every town of ours it could take
// within the defence horizon, on either level. A game is won by taking a
// player's towns and killing its heroes, and a raider loose among our towns
// costs all of them, not only the best one.
double _threatened_town_share(State &state, DictRef session, DictRef context, DictRef other) {
	const double power = hero_power(state, other);
	return threatened_town_share_at(state, session, context, ai::string_or_empty(state, other, key::placement_id), player_rules::raid_controller_id(state, other), gd::int_field(state, other, key::x, 0), gd::int_field(state, other, key::y, 0), level_rules::level_of(state, dict_value(other)), power, _movement_max(state, other));
}

// The same for the human's hero, `power` strong, as the threat checks walk it
// (_hostile_heroes).
double _player_hero_threatened_town_share(State &state, DictRef session, DictRef context, DictRef hero, double power) {
	Value found;
	const DictRef position = state.lookup(hero, str(key::position), found) && gd::is_dict(found) ? found.ref : state.new_dict();
	const DictRef movement = state.lookup(hero, str(key::movement), found) && gd::is_dict(found) ? found.ref : state.new_dict();
	return threatened_town_share_at(state, session, context, ai::string_or_empty(state, hero, key::id), key::player, gd::int_field(state, position, key::x, 0), gd::int_field(state, position, key::y, 0), level_rules::level_of(state, dict_value(position)), power, gd::int_field(state, movement, key::max, 10));
}

Atom _decision_main_id(State &state, DictRef session, DictRef context) {
	const DictRef cache = dict_or_new(state, context, key::decision);
	if (!state.has(cache, str(key::main))) {
		state.set(cache, str(key::main), str(_main_hero_id(state, session, context_controller(state, context))));
		state.set(context, str(key::decision), dict_value(cache));
	}
	return gd::stringify(state, gd::index(state, cache, str(key::main)));
}

} // namespace ai_hero_rules

} // namespace aurelion::rules::port
