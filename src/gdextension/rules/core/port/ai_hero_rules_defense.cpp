// AiHeroRules: the main army and the field armies, what the main army lacks,
// the threats to a player's towns and the troops left behind to hold them.

#include "aurelion_rules/port/ai_hero_rules_ai.hpp"

#include "aurelion_rules/port/ai_port.hpp"
#include "aurelion_rules/port/enemy_turn_rules.hpp"
#include "aurelion_rules/port/overworld_level_rules_ai.hpp"
#include "aurelion_rules/port/overworld_rules_ai.hpp"
#include "aurelion_rules/port/player_identity_rules_ai.hpp"
#include "aurelion_rules/port/session_view.hpp"

#include <cmath>
#include <limits>
#include <string>
#include <unordered_map>
#include <unordered_set>
#include <utility>

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

// Tiles from (x, y) on `level` to a town's doorway: the straight distance on one
// level; across levels the shortest way through a gate or monolith of that level
// whose exit lies on the doorway's level, one tile for the crossing. -1 when no
// gate leads there. A hostile hero threatens towns on either level.
int64_t steps_to_door(State &state, DictRef session, DictRef context, int64_t x, int64_t y, int64_t level, DictRef entrance) {
	const int64_t door_x = gd::int_field(state, entrance, key::x, 0);
	const int64_t door_y = gd::int_field(state, entrance, key::y, 0);
	const int64_t door_level = level_rules::level_of(state, dict_value(entrance));
	if (level == door_level) {
		return tile_distance(x, door_x, y, door_y);
	}
	const int64_t width = context_map_size(state, context).x;
	const Value gates = state.get(ai_hero_rules::_level_surface(state, session, context, level), str(key::gates), dict_value(state.new_dict()));
	if (width <= 0 || !gd::is_dict(gates)) {
		return -1;
	}
	int64_t best = -1;
	for (const Value &gate_tile : gd::items(state, gates)) {
		const int64_t tile = gd::to_int(state, gate_tile);
		const Value gate = gd::index(state, gates.ref, gate_tile);
		// A portal with several exits may let it out at any of them.
		const Value far_exits = ai::vget(state, gate, key::far_exits, Value());
		const ArrayRef exits = gd::is_array(far_exits) ? far_exits.ref : state.new_array();
		if (!gd::is_array(far_exits)) {
			state.append(exits, ai::vmember(state, gate, key::exit));
		}
		for (const Value &exit : gd::items(state, array_value(exits))) {
			if (!gd::is_vector3i(exit) || exit.vz() != door_level) {
				continue;
			}
			const int64_t to_gate = tile_distance(x, compat::int_mod(tile, width), y, tile / width);
			const int64_t steps = gd::add(gd::add(to_gate, 1), tile_distance(exit.vx(), door_x, exit.vy(), door_y));
			if (best < 0 || steps < best) {
				best = steps;
			}
		}
	}
	return best;
}

// The way from a hostile hero of _hostile_heroes (threat.x, threat.y,
// threat.level) to a town's doorway, -1 when there is none.
int64_t threat_distance(State &state, DictRef session, DictRef context, const Value &threat, DictRef entrance) {
	const int64_t threat_x = gd::to_int(state, ai::vmember(state, threat, key::x));
	const int64_t threat_y = gd::to_int(state, ai::vmember(state, threat, key::y));
	const int64_t threat_level = gd::to_int(state, ai::vget(state, threat, key::level, int_value(0)));
	return steps_to_door(state, session, context, threat_x, threat_y, threat_level, entrance);
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
		state.set(cache, str(key::hostile), array_value(_hostile_heroes(state, session, controller)));
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

double _last_stand_share(State &state, DictRef session, Atom owner, Atom controller) {
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
	Value known;
	if (!state.lookup(spellbook.ref, str(key::known_spell_ids), known) || !gd::is_array(known) || state.array_size(known.ref) == 0) {
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
	for (const Value &spell_id : gd::items(state, known)) {
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

bool _town_threatened(State &state, DictRef session, DictRef context, DictRef town) {
	const DictRef cache = dict_or_new(state, context, key::decision);
	const Atom threat_key = gd::format(state, key::threat_s, {str(ai::string_or_empty(state, town, key::placement_id))});
	Value cached;
	if (state.lookup(cache, str(threat_key), cached)) {
		return gd::to_bool(cached);
	}
	if (!state.has(cache, str(key::hostile))) {
		state.set(cache, str(key::hostile), array_value(_hostile_heroes(state, session, context_controller(state, context))));
	}
	state.set(context, str(key::decision), dict_value(cache));
	const double defense = power_of(state, field_or_new_array(state, town, key::garrison));
	const DictRef entrance = level_rules::town_entrance(state, town);
	bool threatened = false;
	double strongest = 0.0;
	// In sight, or seen out there in the last few days.
	state::ValueList threats = gd::items(state, gd::index(state, cache, str(key::hostile))).list();
	for (const Value &threat : gd::items(state, array_value(_recent_hostiles(state, session, context))).list()) {
		threats.push_back(threat);
	}
	for (const Value &threat : threats) {
		const int64_t distance = threat_distance(state, session, context, threat, entrance);
		const int64_t reach = gd::to_int(state, ai::vget(state, threat, key::reach, int_value(10)));
		if (distance >= 0 && distance <= gd::add(reach, tunable_int(state, key::THREAT_REACH_MARGIN)) &&gd::to_float(ai::vmember(state, threat, key::power)) > defense * tunable_float(state, key::THREAT_RATIO)) {
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

bool _would_hold_gate(State &state, DictRef session, DictRef context, DictRef entry, DictRef town, bool is_main) {
	const DictRef threat = _strongest_threat(state, session, context, town);
	if (gd::is_empty(state, threat)) {
		return true;
	}
	const double required = gd::to_float(gd::index(state, threat, str(key::power))) * tunable_float(state, key::HERO_ATTACK_RATIO);
	if (required <= hero_power(state, entry)) {
		return true;
	}
	if (!is_main) {
		return false;
	}
	const double threat_power = gd::to_float(gd::index(state, threat, str(key::power)));
	const double hero = hero_power(state, entry);
	const double garrison = power_of(state, field_or_new_array(state, town, key::garrison));
	return threat_power < (hero + garrison) * tunable_float(state, key::TOWN_ATTACK_RATIO);
}

DictRef _leave_defense(State &state, DictRef session, DictRef context, DictRef town, ArrayRef stacks, ArrayRef garrison, bool is_main) {
	const DictRef unchanged = state.new_dict();
	state.set(unchanged, str(key::stacks), array_value(stacks));
	state.set(unchanged, str(key::garrison), array_value(garrison));
	const double need = _town_defense_need(state, session, context, town);
	double missing = need - power_of(state, array_value(garrison));
	if (missing <= 0.0) {
		return unchanged;
	}
	const double total = power_of(state, array_value(stacks));
	const double troops_share = total * (is_main ? tunable_float(state, key::DEFENSE_SHARE_MAX_MAIN) : tunable_float(state, key::DEFENSE_SHARE_MAX));
	const double worth = _town_worth(state, session, context, town);
	const double budget = compat::engine_min(troops_share, worth / tunable_float(state, key::TROOP_VALUE_PER_POWER));
	if (missing > budget) {
		return unchanged;
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
		state.set(cache, str(key::hostile), array_value(_hostile_heroes(state, session, context_controller(state, context))));
		state.set(context, str(key::decision), dict_value(cache));
	}
	// Only a hostile hero that is seen or remembered calls for troops left
	// behind, on either level; a town no one threatens is held by the heroes,
	// which carry its troops where they are used.
	const DictRef entrance = level_rules::town_entrance(state, town);
	double strongest = 0.0;
	state::ValueList threats = gd::items(state, gd::index(state, cache, str(key::hostile))).list();
	for (const Value &threat : gd::items(state, array_value(_recent_hostiles(state, session, context))).list()) {
		threats.push_back(threat);
	}
	for (const Value &threat : threats) {
		const int64_t distance = threat_distance(state, session, context, threat, entrance);
		const int64_t reach = gd::to_int(state, ai::vget(state, threat, key::reach, int_value(10)));
		if (distance >= 0 && distance <= gd::add(gd::mul(reach, tunable_int(state, key::DEFENSE_HORIZON_DAYS)), 1)) {
			strongest = compat::engine_max(strongest, gd::to_float(ai::vmember(state, threat, key::power)));
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

// What killing a hostile hero saves: a share of every town of ours it could take
// within the defence horizon, on either level. A game is won by taking a
// player's towns and killing its heroes, and a raider loose among our towns
// costs all of them, not only the best one.
double _threatened_town_share(State &state, DictRef session, DictRef context, DictRef other) {
	double total = 0.0;
	const double power = hero_power(state, other);
	const int64_t reach = compat::engine_max<int64_t>(tunable_int(state, key::THREAT_MIN_REACH), _movement_max(state, other));
	const int64_t horizon = gd::add(gd::mul(reach, tunable_int(state, key::DEFENSE_HORIZON_DAYS)), tunable_int(state, key::THREAT_REACH_MARGIN));
	const int64_t other_x = gd::int_field(state, other, key::x, 0);
	const int64_t other_y = gd::int_field(state, other, key::y, 0);
	const int64_t other_level = level_rules::level_of(state, dict_value(other));
	for (const Value &town : gd::field_items(state, session_view::overworld(state, session), str(key::towns))) {
		if (!gd::is_dict(town) || ai::string_or_empty(state, town.ref, key::owner) != key::enemy) {
			continue;
		}
		const Atom town_controller = player_rules::town_controller_id(state, town.ref);
		if (town_controller != context_controller(state, context)) {
			continue;
		}
		const DictRef entrance = level_rules::town_entrance(state, town.ref);
		const int64_t distance = steps_to_door(state, session, context, other_x, other_y, other_level, entrance);
		if (distance >= 0 && distance <= horizon && power > power_of(state, field_or_new_array(state, town.ref, key::garrison)) * tunable_float(state, key::THREAT_RATIO)) {
			total += _town_worth(state, session, context, town.ref) * tunable_float(state, key::THREAT_KILL_SHARE);
		}
	}
	return total;
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
