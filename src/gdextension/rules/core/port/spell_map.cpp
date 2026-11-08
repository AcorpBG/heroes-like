// The map spells (docs/magic-system-spells.md, Map): effect type "map_effect", one mechanic each, its numbers growing
// with the caster's spell power. Far Sight widens the hero's sight until its next day starts and opens it at once;
// Stride adds movement today, past the day's full movement; Read Tracks shows the garrisons of the towns that are
// not the seat's within reach of its heroes until their next day; Watchtower Lens opens every tile within reach of
// the hero on every level; Harvest Bloom doubles the income of a held mine beside the hero for some days. What a
// step costs is its ground's (docs/overworld-terrain-movement.md), a road step's a point: Forge Road halves road steps
// for some days, Green Path and Mire Stride make their ground cost no more than grass for some days, Scorched Earth
// doubles enemy steps near where it was cast, and a wardwood stops enemy armies that come near it (StepCosts). A
// Firebreak's mark closes its tile to every army. The spells aimed at a tile find their tiles in spell_map_tiles.cpp.
#include "aurelion_rules/port/map_spells.hpp"

#include "aurelion_rules/compat/godot_math.hpp"
#include "aurelion_rules/port/ai_port.hpp"
#include "aurelion_rules/port/content_service_ai.hpp"
#include "aurelion_rules/port/hero_command_rules.hpp"
#include "aurelion_rules/port/hero_command_rules_ai.hpp"
#include "aurelion_rules/port/overworld_level_rules.hpp"
#include "aurelion_rules/port/overworld_level_rules_ai.hpp"
#include "aurelion_rules/port/overworld_rules_ai.hpp"
#include "aurelion_rules/port/player_identity_rules_ai.hpp"
#include "aurelion_rules/port/session_view.hpp"
#include "aurelion_rules/port/spell_rules.hpp"

#include <algorithm>
#include <string>

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

// The ground a Green Path or Mire Stride covers, as its text names it: "Forest and rough", "Swamp, mire and sand".
Atom ground_names(State &state, DictRef spell) {
	std::vector<Atom> names;
	for (const Value &terrain : gd::field_items(state, effect_of(state, spell), str(key::terrains))) {
		names.push_back(gd::stringify(state, terrain));
	}
	std::string text;
	for (size_t at = 0; at < names.size(); ++at) {
		if (at > 0) {
			text += state.text(at + 1 == names.size() ? key::and_ : key::comma_space);
		}
		text += state.text(at == 0 ? gd::capitalize(state, names[at]) : names[at]);
	}
	return state.intern(text);
}

uint64_t tile_key(Vector2i tile) {
	return (static_cast<uint64_t>(static_cast<uint32_t>(tile.x)) << 32) | static_cast<uint32_t>(tile.y);
}

// The marks still standing today (their last day not past).
bool mark_stands(State &state, const Value &mark, int64_t day) {
	return gd::is_dict(mark) && gd::int_field(state, mark.ref, key::until_day, 0) >= day;
}

// Scorched Earth or a wardwood on the caster's tile; the marks whose days are over go as one is added.
void add_mark(State &state, DictRef session, const Caster &caster, DictRef spell, int64_t day) {
	const DictRef overworld = session_view::overworld(state, session);
	const ArrayRef marks = state.new_array();
	for (const Value &mark : gd::field_items(state, overworld, str(key::map_spell_marks))) {
		if (mark_stands(state, mark, day)) {
			state.append(marks, mark);
		}
	}
	const DictRef mark = state.new_dict();
	state.set(mark, str(key::map), str(mechanic(state, spell)));
	state.set(mark, str(key::spell_id), str(gd::string_field(state, spell, key::id, key::empty)));
	state.set(mark, str(key::x), int_value(caster.tile.x));
	state.set(mark, str(key::y), int_value(caster.tile.y));
	state.set(mark, str(key::level), int_value(caster.level));
	state.set(mark, str(key::radius), int_value(term(state, caster.hero, spell, key::radius)));
	// It stands for its days of enemy turns. The computer players move after a new day opens and the human seat last
	// in it: a mark the human seat casts first meets an enemy the next day, a computer player's the same day.
	const int64_t days = engine_max<int64_t>(1, term(state, caster.hero, spell, key::days));
	state.set(mark, str(key::until_day), int_value(gd::add(day, caster.controller == key::player ? days : gd::sub(days, 1))));
	state.set(mark, str(key::controller), str(caster.controller));
	state.append(marks, dict_value(mark));
	state.set(overworld, str(key::map_spell_marks), array_value(marks));
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
	if (kind == key::map_road) {
		const int64_t days = term(state, hero, spell, key::days);
		return days <= 1 ? key::map_road_today_text : gd::format(state, key::map_road_text, {int_value(days)});
	}
	if (kind == key::map_forest_ways || kind == key::map_mire_ways) {
		const int64_t days = term(state, hero, spell, key::days);
		const Atom names = ground_names(state, spell);
		return days <= 1 ? gd::format(state, key::map_ground_ways_today_text, {str(names)}) : gd::format(state, key::map_ground_ways_text, {str(names), int_value(days)});
	}
	if (kind == key::map_slow_zone) {
		return gd::format(state, key::map_slow_zone_text, {int_value(term(state, hero, spell, key::days)), int_value(term(state, hero, spell, key::radius))});
	}
	if (kind == key::map_watch) {
		return gd::format(state, key::map_watch_text, {int_value(term(state, hero, spell, key::days)), int_value(term(state, hero, spell, key::radius))});
	}
	if (kind == key::map_flare) {
		return gd::format(state, key::map_flare_text, {int_value(term(state, hero, spell, key::radius)), int_value(term(state, hero, spell, key::range))});
	}
	if (kind == key::map_block) {
		const int64_t days = term(state, hero, spell, key::days);
		return days <= 1 ? key::map_block_day_text : gd::format(state, key::map_block_text, {int_value(days)});
	}
	if (kind == key::map_jump_forest) {
		return gd::format(state, key::map_jump_forest_text, {int_value(term(state, hero, spell, key::range))});
	}
	if (kind == key::map_town) {
		return gd::format(state, key::map_town_text, {int_value(term(state, hero, spell, key::range))});
	}
	if (kind == key::map_ferry) {
		return gd::format(state, key::map_ferry_text, {int_value(term(state, hero, spell, key::range))});
	}
	if (kind == key::map_jump) {
		return gd::format(state, key::map_jump_text, {int_value(term(state, hero, spell, key::range))});
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

void apply_to_hero(State &state, DictRef hero, DictRef movement, DictRef spell, int64_t day) {
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
	} else if (kind == key::map_road) {
		// Today is the first of its days; a second Forge Road runs to the later end.
		const int64_t until = gd::add(day, gd::sub(engine_max<int64_t>(1, term(state, hero, spell, key::days)), 1));
		state.set(hero, str(key::map_road_until_day), int_value(engine_max<int64_t>(until, gd::int_field(state, hero, key::map_road_until_day, 0))));
	} else if (kind == key::map_forest_ways || kind == key::map_mire_ways) {
		// Green Path and Mire Stride: map_ground_ways {terrain: last day}, from today for its days; a second cast runs
		// each terrain to the later end. The ground whose days are over goes.
		const int64_t until = gd::add(day, gd::sub(engine_max<int64_t>(1, term(state, hero, spell, key::days)), 1));
		const DictRef ways = state.new_dict();
		const Value before = gd::field(state, hero, key::map_ground_ways);
		if (gd::is_dict(before)) {
			for (const Value &terrain : gd::items(state, before)) {
				const Value last = state.get(before.ref, terrain, int_value(0));
				if (gd::to_int(state, last) >= day) {
					state.set(ways, terrain, last);
				}
			}
		}
		for (const Value &terrain : gd::field_items(state, effect_of(state, spell), str(key::terrains))) {
			const Value normalized = str(content_service::normalize_terrain_id(state, gd::stringify(state, terrain)));
			state.set(ways, normalized, int_value(engine_max<int64_t>(until, gd::to_int(state, state.get(ways, normalized, int_value(0))))));
		}
		state.set(hero, str(key::map_ground_ways), dict_value(ways));
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
	const Atom kind = mechanic(state, spell);
	if (kind == key::map_slow_zone || kind == key::map_watch || kind == key::map_block) {
		add_mark(state, session, caster, spell, day);
		return state.new_dict();
	}
	if (kind != key::map_mine) {
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
	for (const Atom field : {key::map_sight_tiles, key::map_move_tiles, key::map_scout_radius, key::map_road_half}) {
		if (state.has(hero, str(field))) {
			state.erase(hero, str(field));
		}
	}
}

void add_blocked_tiles(State &state, DictRef session, int64_t level, DictRef index) {
	const int64_t day = ai::session_int(state, session, key::day);
	for (const Value &mark : gd::field_items(state, session_view::overworld(state, session), str(key::map_spell_marks))) {
		if (mark_stands(state, mark, day) && gd::string_field(state, mark.ref, key::map, key::empty) == key::map_block &&
				gd::int_field(state, mark.ref, key::level, 0) == level) {
			state.set(index, str(overworld_rules::_tile_key(state, tile_of(state, mark.ref))), gd::bool_value(true));
		}
	}
}

void open_day(State &state, DictRef session, int64_t day) {
	const DictRef overworld = session_view::overworld(state, session);
	Value found;
	if (!state.lookup(overworld, str(key::map_spell_marks), found) || !gd::is_array(found)) {
		return;
	}
	const ArrayRef kept = state.new_array();
	bool block_gone = false;
	for (const Value &mark : gd::items(state, found)) {
		if (mark_stands(state, mark, day)) {
			state.append(kept, mark);
		} else if (gd::is_dict(mark) && gd::string_field(state, mark.ref, key::map, key::empty) == key::map_block) {
			block_gone = true;
		}
	}
	if (state.array_size(kept) != state.array_size(found.ref)) {
		state.set(overworld, str(key::map_spell_marks), array_value(kept));
	}
	if (block_gone) {
		overworld_rules::_refresh_blocked_tile_index(state, session);
	}
}

int64_t harvest_factor(State &state, DictRef node, int64_t day) {
	const int64_t from = gd::int_field(state, node, key::harvest_from_day, 0);
	return from > 0 && day >= from && day <= gd::int_field(state, node, key::harvest_until_day, 0) ? 2 : 1;
}

int64_t terrain_halves(State &state, Atom terrain_id) {
	const Atom normalized = content_service::normalize_terrain_id(state, terrain_id);
	for (const Value &terrain_class : gd::field_items(state, gd::content_file(state, key::terrain_grammar_path), str(key::terrain_classes))) {
		if (!gd::is_dict(terrain_class) || gd::string_field(state, terrain_class.ref, key::id, key::empty) != normalized) {
			continue;
		}
		const Value cost = gd::field(state, terrain_class.ref, key::movement_cost);
		if (cost.kind != state::Kind::Int && cost.kind != state::Kind::Float) {
			return 2;
		}
		return compat::engine_clamp<int64_t>(compat::float_to_int(compat::godot_round(gd::to_float(cost) * 2.0)), 1, 200);
	}
	return 2;
}

std::vector<Vector2i> road_tiles(State &state, DictRef session, int64_t level) {
	// terrain_layers.roads: [{level, tiles: [{x, y, level}]}].
	std::vector<Vector2i> tiles;
	const Value layers = gd::field(state, session_view::overworld(state, session), key::terrain_layers);
	if (!gd::is_dict(layers)) {
		return tiles;
	}
	for (const Value &road : gd::field_items(state, layers.ref, str(key::roads))) {
		if (!gd::is_dict(road)) {
			continue;
		}
		const int64_t road_level = gd::int_field(state, road.ref, key::level, 0);
		for (const Value &tile : gd::field_items(state, road.ref, str(key::tiles))) {
			if (gd::is_dict(tile) && gd::int_field(state, tile.ref, key::level, road_level) == level) {
				tiles.push_back(tile_of(state, tile.ref));
			}
		}
	}
	return tiles;
}

StepCosts::StepCosts(State &state, DictRef session, const Mover &mover) : state_(&state), session_(session), level_(mover.level) {
	const DictRef overworld = session_view::overworld(state, session);
	for (const Value &mark : gd::field_items(state, overworld, str(key::map_spell_marks))) {
		if (!mark_stands(state, mark, mover.day) || gd::int_field(state, mark.ref, key::level, 0) != mover.level ||
				player_identity_rules::allied(state, dict_value(session), gd::string_field(state, mark.ref, key::controller, key::empty), mover.controller)) {
			continue;
		}
		const Zone zone{tile_of(state, mark.ref), engine_max<int64_t>(0, gd::int_field(state, mark.ref, key::radius, 0))};
		const Atom kind = gd::string_field(state, mark.ref, key::map, key::empty);
		if (kind == key::map_slow_zone) {
			slow_.push_back(zone);
		} else if (kind == key::map_watch) {
			watch_.push_back(zone);
		}
	}
	rows_ = levels::terrain_rows(state, dict_value(session), mover.level);
	grass_halves_ = terrain_halves(state, key::grass);
	if (mover.hero != 0) {
		road_halves_ = gd::int_field(state, mover.hero, key::map_road_until_day, 0) >= mover.day ? 1 : 2;
		// Green Path and Mire Stride: the ground the mover walks like grass, by terrain until its last day.
		const Value ways = gd::field(state, mover.hero, key::map_ground_ways);
		if (gd::is_dict(ways)) {
			for (const Value &terrain : gd::items(state, ways)) {
				if (gd::to_int(state, state.get(ways.ref, terrain, int_value(0))) >= mover.day) {
					easy_.insert(content_service::normalize_terrain_id(state, gd::stringify(state, terrain)));
				}
			}
		}
	}
}

bool StepCosts::inside(const Zone &zone, Vector2i tile) const {
	return hero_command_rules::within_scout_radius(*state_, static_cast<int64_t>(tile.x) - zone.tile.x, static_cast<int64_t>(tile.y) - zone.tile.y, zone.radius);
}

bool StepCosts::on_road(Vector2i tile) const {
	if (!roads_read_) {
		roads_read_ = true;
		for (const Vector2i road : road_tiles(*state_, session_, level_)) {
			road_tiles_.insert(tile_key(road));
		}
	}
	return road_tiles_.count(tile_key(tile)) != 0;
}

Atom StepCosts::terrain_at(Vector2i tile) const {
	if (tile.y < 0 || tile.y >= state_->array_size(rows_)) {
		return key::rock;
	}
	const Value row = state_->at(rows_, tile.y);
	if (!gd::is_array(row) || tile.x < 0 || tile.x >= state_->array_size(row.ref)) {
		return key::rock;
	}
	return gd::stringify(*state_, state_->at(row.ref, tile.x));
}

int64_t StepCosts::ground_halves(Atom terrain_id) const {
	const auto found = ground_.find(terrain_id);
	if (found != ground_.end()) {
		return found->second;
	}
	int64_t cost = terrain_halves(*state_, terrain_id);
	if (!easy_.empty() && easy_.count(content_service::normalize_terrain_id(*state_, terrain_id)) != 0) {
		cost = std::min(cost, grass_halves_);
	}
	ground_.emplace(terrain_id, cost);
	return cost;
}

int64_t StepCosts::halves(Vector2i from, Vector2i to) const {
	int64_t cost = 2;
	if (chebyshev(from, to) == 1) {
		cost = on_road(from) && on_road(to) ? road_halves_ : ground_halves(terrain_at(to));
	}
	for (const Zone &zone : slow_) {
		if (inside(zone, to)) {
			return cost * 2;
		}
	}
	return cost;
}

bool StepCosts::stops(Vector2i from, Vector2i to) const {
	for (const Zone &zone : watch_) {
		if (inside(zone, to) && !inside(zone, from)) {
			return true;
		}
	}
	return false;
}

void StepCosts::fill(int64_t width, int64_t height, const uint8_t *kinds, const std::vector<Atom> &terrains, const uint8_t *roads, uint8_t *enter, uint8_t *road) const {
	std::vector<uint8_t> by_kind(terrains.size(), 2);
	for (size_t kind = 0; kind < terrains.size(); ++kind) {
		by_kind[kind] = static_cast<uint8_t>(compat::engine_clamp<int64_t>(ground_halves(terrains[kind]), 1, 255));
	}
	const uint8_t road_cost = static_cast<uint8_t>(road_halves_);
	const int64_t count = width * height;
	for (int64_t tile = 0; tile < count; ++tile) {
		enter[tile] = kinds[tile] < by_kind.size() ? by_kind[kinds[tile]] : 2;
		road[tile] = roads[tile] != 0 ? road_cost : 0;
	}
	// Scorched Earth doubles both within its reach, once where several reach.
	if (slow_.empty()) {
		return;
	}
	std::vector<uint8_t> slowed(static_cast<size_t>(count), 0);
	for (const Zone &zone : slow_) {
		for (int64_t y = engine_max<int64_t>(0, zone.tile.y - zone.radius); y <= std::min<int64_t>(height - 1, zone.tile.y + zone.radius); ++y) {
			for (int64_t x = engine_max<int64_t>(0, zone.tile.x - zone.radius); x <= std::min<int64_t>(width - 1, zone.tile.x + zone.radius); ++x) {
				if (inside(zone, Vector2i::of(x, y))) {
					slowed[static_cast<size_t>(y * width + x)] = 1;
				}
			}
		}
	}
	for (int64_t tile = 0; tile < count; ++tile) {
		if (slowed[static_cast<size_t>(tile)] != 0) {
			enter[tile] = static_cast<uint8_t>(std::min<int64_t>(255, int64_t(enter[tile]) * 2));
			road[tile] = static_cast<uint8_t>(std::min<int64_t>(255, int64_t(road[tile]) * 2));
		}
	}
}

int64_t banked_half(State &state, DictRef hero) {
	return hero != 0 && gd::int_field(state, hero, key::map_road_half, 0) > 0 ? 1 : 0;
}

void set_banked_half(State &state, DictRef hero, int64_t half) {
	if (half > 0) {
		state.set(hero, str(key::map_road_half), int_value(1));
	} else if (state.has(hero, str(key::map_road_half))) {
		state.erase(hero, str(key::map_road_half));
	}
}

void stop_at_wardwood(State &state, DictRef hero) {
	state.set(hero, str(key::map_watch_slowed), gd::bool_value(true));
}

int64_t morning_movement(State &state, DictRef hero, int64_t movement_max) {
	if (!state.has(hero, str(key::map_watch_slowed))) {
		return movement_max;
	}
	state.erase(hero, str(key::map_watch_slowed));
	return movement_max / 2;
}

bool mark_stands_at(State &state, DictRef session, Atom kind, Atom controller, Vector2i tile, int64_t level, int64_t day) {
	for (const Value &mark : gd::field_items(state, session_view::overworld(state, session), str(key::map_spell_marks))) {
		if (!mark_stands(state, mark, day) || gd::int_field(state, mark.ref, key::level, 0) != level || gd::string_field(state, mark.ref, key::map, key::empty) != kind ||
				!player_identity_rules::allied(state, dict_value(session), gd::string_field(state, mark.ref, key::controller, key::empty), controller)) {
			continue;
		}
		const Vector2i at = tile_of(state, mark.ref);
		if (hero_command_rules::within_scout_radius(state, static_cast<int64_t>(tile.x) - at.x, static_cast<int64_t>(tile.y) - at.y, gd::int_field(state, mark.ref, key::radius, 0))) {
			return true;
		}
	}
	return false;
}

ArrayRef marks_at(State &state, DictRef session, Vector2i tile, int64_t level, int64_t day) {
	const ArrayRef lines = state.new_array();
	if (level < 0) {
		level = levels::hero_level(state, session);
	}
	if (day < 0) {
		day = ai::session_int(state, session, key::day);
	}
	for (const Value &mark : gd::field_items(state, session_view::overworld(state, session), str(key::map_spell_marks))) {
		if (!mark_stands(state, mark, day) || gd::int_field(state, mark.ref, key::level, 0) != level) {
			continue;
		}
		const Vector2i at = tile_of(state, mark.ref);
		if (!hero_command_rules::within_scout_radius(state, static_cast<int64_t>(tile.x) - at.x, static_cast<int64_t>(tile.y) - at.y, gd::int_field(state, mark.ref, key::radius, 0))) {
			continue;
		}
		const Atom spell_id = gd::string_field(state, mark.ref, key::spell_id, key::empty);
		const Atom name = gd::string_field(state, gd::content_row(state, ContentTable::Spell, spell_id), key::name, spell_id);
		const bool own = player_identity_rules::allied(state, dict_value(session), gd::string_field(state, mark.ref, key::controller, key::empty), key::player);
		const Atom kind = gd::string_field(state, mark.ref, key::map, key::empty);
		Atom line = key::empty;
		if (kind == key::map_slow_zone) {
			line = own ? key::map_mark_slow_own_text : key::map_mark_slow_rival_text;
		} else if (kind == key::map_watch) {
			line = own ? key::map_mark_watch_own_text : key::map_mark_watch_rival_text;
		} else if (kind == key::map_block) {
			line = own ? key::map_mark_block_own_text : key::map_mark_block_rival_text;
		} else {
			continue;
		}
		state.append(lines, str(gd::format(state, line, {str(name), int_value(gd::int_field(state, mark.ref, key::until_day, 0))})));
	}
	return lines;
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
