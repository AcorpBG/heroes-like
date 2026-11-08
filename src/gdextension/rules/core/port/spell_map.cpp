// The map spells (docs/magic-system-spells.md, Map): effect type "map_effect", one mechanic each, its numbers growing
// with the caster's spell power. Far Sight widens the hero's sight until its next day starts and opens it at once;
// Stride adds movement today, past the day's full movement; Read Tracks shows the garrisons of the towns that are
// not the seat's within reach of its heroes until their next day; Watchtower Lens opens every tile within reach of
// the hero on every level; Harvest Bloom doubles the income of a held mine beside the hero for some days.
#include "aurelion_rules/port/map_spells.hpp"

#include "aurelion_rules/compat/godot_math.hpp"
#include "aurelion_rules/port/hero_command_rules.hpp"
#include "aurelion_rules/port/hero_command_rules_ai.hpp"
#include "aurelion_rules/port/overworld_level_rules.hpp"
#include "aurelion_rules/port/overworld_rules_ai.hpp"
#include "aurelion_rules/port/player_identity_rules_ai.hpp"
#include "aurelion_rules/port/session_view.hpp"
#include "aurelion_rules/port/spell_rules.hpp"

namespace aurelion::rules::port::map_spells {

using compat::engine_max;
using gd::array_value;
using gd::dict_value;
using gd::int_value;
using gd::str;
using state::ContentTable;
namespace key = state::key;
namespace levels = overworld_level_rules;

namespace {

DictRef effect_of(State &state, DictRef spell) {
	const Value effect = gd::is_empty(state, spell) ? Value() : gd::field(state, spell, key::effect);
	return gd::is_dict(effect) ? effect.ref : state.new_dict();
}

int64_t term(State &state, DictRef hero, DictRef spell, Atom name) {
	return engine_max<int64_t>(0, gd::int_field(state, terms(state, hero, spell), name, 0));
}

int64_t chebyshev(Vector2i a, Vector2i b) {
	const int64_t dx = static_cast<int64_t>(a.x) - b.x;
	const int64_t dy = static_cast<int64_t>(a.y) - b.y;
	return engine_max<int64_t>(dx < 0 ? -dx : dx, dy < 0 ? -dy : dy);
}

Vector2i tile_of(State &state, DictRef record) {
	return Vector2i::of(gd::int_field(state, record, key::x, 0), gd::int_field(state, record, key::y, 0));
}

bool site_has_income(State &state, DictRef site) {
	const Value income = gd::field(state, site, key::control_income);
	return gd::is_dict(income) && !gd::is_empty(state, income.ref);
}

Atom mine_name(State &state, DictRef node) {
	const DictRef site = gd::content_row(state, ContentTable::ResourceSite, gd::string_field(state, node, key::site_id, key::empty));
	return gd::string_field(state, site, key::name, key::resource_cache);
}

} // namespace

bool is_map_spell(State &state, DictRef spell) {
	return gd::string_field(state, effect_of(state, spell), key::type, key::empty) == key::map_effect;
}

Atom mechanic(State &state, DictRef spell) {
	return gd::string_field(state, effect_of(state, spell), key::map, key::empty);
}

DictRef terms(State &state, DictRef hero, DictRef spell) {
	return spell_rules::resolve_mechanic(state, dict_value(effect_of(state, spell)), spell_rules::spell_power(state, hero));
}

Atom effect_text(State &state, DictRef hero, DictRef spell, DictRef mine) {
	const Atom kind = mechanic(state, spell);
	if (kind == key::map_sight) {
		return gd::format(state, key::map_sight_text, {int_value(term(state, hero, spell, key::tiles))});
	}
	if (kind == key::map_move) {
		return gd::format(state, key::map_move_text, {int_value(term(state, hero, spell, key::tiles))});
	}
	if (kind == key::map_scout) {
		return gd::format(state, key::map_scout_text, {int_value(term(state, hero, spell, key::radius))});
	}
	if (kind == key::map_lens) {
		return gd::format(state, key::map_lens_text, {int_value(term(state, hero, spell, key::radius))});
	}
	if (kind == key::map_mine) {
		const int64_t days = term(state, hero, spell, key::days);
		return gd::is_empty(state, mine) ? gd::format(state, key::map_mine_text, {int_value(days)})
										 : gd::format(state, key::map_mine_named_text, {str(mine_name(state, mine)), int_value(days)});
	}
	return key::no_supported_overworld_effect;
}

Atom category(State &state, DictRef spell) {
	const Atom kind = mechanic(state, spell);
	if (kind == key::map_sight || kind == key::map_scout || kind == key::map_lens || kind == key::map_flare) {
		return key::field_survey;
	}
	if (kind == key::map_move || kind == key::map_road || kind == key::map_forest_ways || kind == key::map_mire_ways ||
			kind == key::map_jump_forest || kind == key::map_town || kind == key::map_ferry || kind == key::map_jump) {
		return key::field_route;
	}
	return key::field_utility;
}

void apply_to_hero(State &state, DictRef hero, DictRef movement, DictRef spell) {
	const Atom kind = mechanic(state, spell);
	if (kind == key::map_sight) {
		state.set(hero, str(key::map_sight_tiles), int_value(term(state, hero, spell, key::tiles)));
	} else if (kind == key::map_move) {
		const int64_t tiles = term(state, hero, spell, key::tiles);
		state.set(hero, str(key::map_move_tiles), int_value(gd::add(engine_max<int64_t>(0, gd::int_field(state, hero, key::map_move_tiles, 0)), tiles)));
		state.set(movement, str(key::current), int_value(gd::add(gd::int_field(state, movement, key::current, 0), tiles)));
		state.set(movement, str(key::max), int_value(gd::add(gd::int_field(state, movement, key::max, 0), tiles)));
	} else if (kind == key::map_scout) {
		state.set(hero, str(key::map_scout_radius), int_value(term(state, hero, spell, key::radius)));
	}
}

int64_t reveal_radius(State &state, DictRef hero, DictRef spell) {
	const Atom kind = mechanic(state, spell);
	if (kind == key::map_sight) {
		// The sight without a Far Sight already on the hero, and this one's tiles.
		const int64_t sight = gd::sub(hero_command_rules::scouting_radius_for_hero(state, hero), engine_max<int64_t>(0, gd::int_field(state, hero, key::map_sight_tiles, 0)));
		return gd::add(sight, term(state, hero, spell, key::tiles));
	}
	if (kind == key::map_lens) {
		return term(state, hero, spell, key::radius);
	}
	return 0;
}

bool reveals_every_level(State &state, DictRef spell) {
	return mechanic(state, spell) == key::map_lens;
}

DictRef harvest_mine(State &state, DictRef session, const Caster &caster) {
	for (const Value &node : gd::field_items(state, session_view::overworld(state, session), str(key::resource_nodes))) {
		if (!gd::is_dict(node) || player_identity_rules::resource_controller_id(state, node.ref) != caster.controller ||
				levels::level_of(state, node) != caster.level || chebyshev(tile_of(state, node.ref), caster.tile) > 1) {
			continue;
		}
		const DictRef site = gd::content_row(state, ContentTable::ResourceSite, gd::string_field(state, node.ref, key::site_id, key::empty));
		if (overworld_rules::_resource_site_is_persistent(state, site) && site_has_income(state, site)) {
			return node.ref;
		}
	}
	return state.new_dict();
}

Atom refusal(State &state, DictRef session, const Caster &caster, DictRef spell) {
	if (mechanic(state, spell) == key::map_mine && gd::is_empty(state, harvest_mine(state, session, caster))) {
		return key::no_mine_beside_text;
	}
	return key::empty;
}

DictRef apply_to_map(State &state, DictRef session, const Caster &caster, DictRef spell, int64_t day) {
	if (mechanic(state, spell) != key::map_mine) {
		return state.new_dict();
	}
	const DictRef node = harvest_mine(state, session, caster);
	if (gd::is_empty(state, node)) {
		return node;
	}
	// Today's income came in at dawn: the bloom doubles the next days'.
	const int64_t until = gd::add(day, term(state, caster.hero, spell, key::days));
	state.set(node, str(key::harvest_from_day), int_value(gd::add(day, 1)));
	state.set(node, str(key::harvest_until_day), int_value(engine_max<int64_t>(until, gd::int_field(state, node, key::harvest_until_day, 0))));
	return node;
}

void clear_day_terms(State &state, DictRef hero) {
	for (const Atom field : {key::map_sight_tiles, key::map_move_tiles, key::map_scout_radius}) {
		if (state.has(hero, str(field))) {
			state.erase(hero, str(field));
		}
	}
}

int64_t harvest_factor(State &state, DictRef node, int64_t day) {
	const int64_t from = gd::int_field(state, node, key::harvest_from_day, 0);
	return from > 0 && day >= from && day <= gd::int_field(state, node, key::harvest_until_day, 0) ? 2 : 1;
}

bool tracks_read(State &state, DictRef session, Vector2i tile, int64_t level) {
	for (const Value &hero : gd::field_items(state, session_view::overworld(state, session), str(key::player_heroes))) {
		if (!gd::is_dict(hero)) {
			continue;
		}
		const int64_t radius = gd::int_field(state, hero.ref, key::map_scout_radius, 0);
		if (radius <= 0 || !levels::on_level(state, hero, level)) {
			continue;
		}
		// A hero keeps its tile in its position, as the fog reads it.
		const Value position_value = gd::field(state, hero.ref, key::position);
		const DictRef position = gd::is_dict(position_value) ? position_value.ref : state.new_dict();
		const int64_t dx = gd::sub(static_cast<int64_t>(tile.x), gd::int_field(state, position, key::x, 0));
		const int64_t dy = gd::sub(static_cast<int64_t>(tile.y), gd::int_field(state, position, key::y, 0));
		if (hero_command_rules::within_scout_radius(state, dx, dy, radius)) {
			return true;
		}
	}
	return false;
}

DictRef read_tracks_garrison(State &state, DictRef session, Vector2i tile, int64_t level) {
	for (const Value &town : gd::field_items(state, session_view::overworld(state, session), str(key::towns))) {
		if (!gd::is_dict(town) || gd::string_field(state, town.ref, key::owner, key::neutral) == key::player || !levels::on_level(state, town, level)) {
			continue;
		}
		const DictRef entrance = levels::town_entrance(state, town.ref);
		if (!(tile_of(state, entrance) == tile) && !(tile_of(state, town.ref) == tile)) {
			continue;
		}
		if (!tracks_read(state, session, tile_of(state, entrance), level)) {
			return state.new_dict();
		}
		const DictRef result = state.new_dict();
		state.set(result, str(key::town_name), str(overworld_rules::_town_name(state, town.ref)));
		state.set(result, str(key::placement_id), str(gd::string_field(state, town.ref, key::placement_id, key::empty)));
		const Value garrison = gd::field(state, town.ref, key::garrison);
		state.set(result, str(key::stacks), gd::is_array(garrison) ? gd::duplicate_value(state, garrison, true) : array_value(state.new_array()));
		return result;
	}
	return state.new_dict();
}

} // namespace aurelion::rules::port::map_spells
