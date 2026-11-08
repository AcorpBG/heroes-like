// OverworldRules for the human seat's overworld spells (Phase 7, slice 7.4):
// casting a spell, the spell actions and the fog a scouting spell reveals.
// ArtifactRules.spell_effect_amount_delta is here too.

#include "aurelion_rules/port/overworld_rules_spells.hpp"

#include "aurelion_rules/port/ai_port.hpp"
#include "aurelion_rules/port/artifact_rules.hpp"
#include "aurelion_rules/port/map_spells.hpp"
#include "aurelion_rules/port/overworld_level_rules.hpp"
#include "aurelion_rules/port/overworld_rules.hpp"
#include "aurelion_rules/port/overworld_rules_move.hpp"
#include "aurelion_rules/port/session_view.hpp"

namespace aurelion::rules::port {

namespace {

using gd::array_value;
using gd::ArrayRef;
using gd::Atom;
using gd::bool_value;
using gd::dict_value;
using gd::DictRef;
using gd::int_value;
using gd::str;
using state::ContentTable;
using state::Kind;
using state::State;
using state::Value;
namespace key = state::key;

// String(x) of any value: the engine's text for a float, a vector or a container.
Atom string_of(State &state, const Value &value) {
	switch (value.kind) {
		case Kind::Nil:
		case Kind::Bool:
		case Kind::Int:
		case Kind::String:
		case Kind::StringName:
			return gd::stringify(state, value);
		default:
			return gd::engine_str(state, value);
	}
}

// d.get(field, {}) of a value that may be stored: the field, or a new {}.
Value field_or_new_dict(State &state, DictRef dict, Atom field) {
	Value found;
	if (state.lookup(dict, str(field), found)) {
		return found;
	}
	return dict_value(state.new_dict());
}

DictRef refusal_result(State &state, Atom message) {
	const DictRef refusal = state.new_dict();
	state.set(refusal, str(key::ok), bool_value(false));
	state.set(refusal, str(key::message), str(message));
	return refusal;
}

} // namespace

namespace overworld_rules {

// The human seat's active hero as the caster of a map spell (map_spells.hpp).
static map_spells::Caster _map_caster(State &state, DictRef session) {
	map_spells::Caster caster;
	caster.hero = gd::as_dict(field_or_new_dict(state, session_view::overworld(state, session), key::hero));
	caster.controller = key::player;
	caster.tile = hero_position(state, session);
	caster.level = overworld_level_rules::hero_level(state, session);
	return caster;
}

// A scouting reveal on another level of the map than the hero's (Watchtower Lens): the tiles it newly opens.
static int64_t _reveal_spell_fog_at(State &state, DictRef session, Vector2i tile, int64_t level, int64_t radius) {
	if (radius <= 0) {
		return 0;
	}
	if (!_fog_state_ready(state, session)) {
		_normalize_fog_of_war(state, session);
	}
	const Vector2i map_size = derive_map_size(state, session);
	const DictRef fog = fog_for_level(state, session, level);
	const int64_t before_count = gd::int_field(state, fog, key::explored_count, 0);
	Value explored_value;
	if (!state.lookup(fog, str(key::explored_tiles), explored_value)) {
		explored_value = array_value(state.new_array());
	}
	const ArrayRef explored_tiles = _normalize_visibility_grid(state, explored_value, map_size);
	const DictRef site = state.new_dict();
	state.set(site, str(key::x), int_value(tile.x));
	state.set(site, str(key::y), int_value(tile.y));
	_apply_site_reveal(state, explored_tiles, site, radius, map_size);
	_reveal_all_current_fog_sources(state, session, explored_tiles, map_size, level);
	const DictRef payload = _build_fog_payload(state, _duplicate_visibility_grid(state, explored_tiles), explored_tiles, map_size);
	_store_level_fog(state, session, payload, level);
	return compat::engine_max<int64_t>(0, gd::sub(gd::int_field(state, payload, key::explored_count, before_count), before_count));
}

DictRef cast_overworld_spell(State &state, DictRef session, Atom spell_id) {
	normalize_overworld_state(state, session);
	const DictRef overworld = session_view::overworld(state, session);
	const Value hero = field_or_new_dict(state, overworld, key::hero);
	const Value movement = field_or_new_dict(state, overworld, key::movement);
	const int64_t day = ai::session_int(state, session, key::day);
	// A map spell asks of the ground where the hero stands once the spell itself may be cast.
	const DictRef spell_row = gd::content_row(state, ContentTable::Spell, spell_id);
	const bool map_spell = map_spells::is_map_spell(state, spell_row);
	if (map_spell && gd::bool_field(state, spell_rules::validate_overworld_spell(state, gd::as_dict(hero), gd::as_dict(movement), dict_value(spell_row), day), key::ok, false)) {
		const Atom refused = map_spells::refusal(state, session, _map_caster(state, session), spell_row);
		if (refused != key::empty) {
			return refusal_result(state, refused);
		}
	}
	const DictRef result = spell_rules::cast_overworld_spell(state, gd::as_dict(hero), gd::as_dict(movement), spell_id, day);
	if (!gd::bool_field(state, result, key::ok, false)) {
		return refusal_result(state, string_of(state, state.get(result, str(key::message), str(key::spell_casting_failed_text))));
	}

	state.set(overworld, str(key::hero), state.get(result, str(key::hero), hero));
	state.set(overworld, str(key::movement), state.get(result, str(key::movement), movement));
	int64_t revealed_tiles = _reveal_spell_fog(state, session, gd::int_field(state, result, key::fog_reveal_radius, 0));
	if (map_spell) {
		const map_spells::Caster caster = _map_caster(state, session);
		const DictRef mine = map_spells::apply_to_map(state, session, caster, spell_row, day);
		if (!gd::is_empty(state, mine)) {
			state.set(result, str(key::message), str(gd::format(state, key::map_spell_cast_text, {
					str(gd::string_field(state, spell_row, key::name, spell_id)),
					str(map_spells::effect_text(state, caster.hero, spell_row, mine)),
					int_value(gd::int_field(state, result, key::mana_cost, 0)),
			})));
		}
		if (gd::bool_field(state, result, key::reveals_every_level, false)) {
			const int64_t level_count = overworld_level_rules::level_count(state, session);
			for (int64_t level = 0; level < level_count; ++level) {
				if (level != caster.level) {
					revealed_tiles = gd::add(revealed_tiles, _reveal_spell_fog_at(state, session, caster.tile, level, gd::int_field(state, result, key::fog_reveal_radius, 0)));
				}
			}
		}
	}
	// result.get("consequence_preview", {}) if it is a Dictionary, else a new {}.
	Value preview_value;
	const DictRef consequence_preview = state.lookup(result, str(key::consequence_preview), preview_value) && gd::is_dict(preview_value)
			? preview_value.ref
			: state.new_dict();
	if (revealed_tiles > 0) {
		state.set(consequence_preview, str(key::revealed_tiles), int_value(revealed_tiles));
	}
	const DictRef finalized = _finalize_action_result(state, session, true, string_of(state, state.get(result, str(key::message), str(key::empty))), true, false, state.new_dict());
	const DictRef context = state.new_dict();
	state.set(context, str(key::spell_id), str(string_of(state, state.get(result, str(key::spell_id), str(spell_id)))));
	state.set(context, str(key::spell_name), str(string_of(state, state.get(result, str(key::spell_name), str(spell_id)))));
	state.set(context, str(key::target_contract), field_or_new_dict(state, result, key::target_contract));
	state.set(context, str(key::consequence_preview), dict_value(consequence_preview));
	return _attach_post_action_recap(state, finalized, session, key::spell, context);
}

ArrayRef get_spell_actions(State &state, DictRef session) {
	normalize_overworld_state_for_runtime(state, session);
	const DictRef overworld = session_view::overworld(state, session);
	const Value hero = field_or_new_dict(state, overworld, key::hero);
	const Value movement = field_or_new_dict(state, overworld, key::movement);
	const ArrayRef actions = spell_rules::get_overworld_actions(state, gd::as_dict(hero), gd::as_dict(movement), ai::session_int(state, session, key::day));
	// A map spell the ground refuses where the hero stands shows why (map_spells.hpp).
	for (const Value &action : gd::items(state, array_value(actions))) {
		if (!gd::is_dict(action) || gd::bool_field(state, action.ref, key::disabled, false)) {
			continue;
		}
		const Value contract = gd::field(state, action.ref, key::target_contract);
		if (!gd::is_dict(contract)) {
			continue;
		}
		const DictRef spell = gd::content_row(state, ContentTable::Spell, gd::string_field(state, contract.ref, key::spell_id, key::empty));
		if (!map_spells::is_map_spell(state, spell)) {
			continue;
		}
		const Atom refused = map_spells::refusal(state, session, _map_caster(state, session), spell);
		if (refused == key::empty) {
			continue;
		}
		state.set(action.ref, str(key::disabled), bool_value(true));
		state.set(action.ref, str(key::readiness), str(gd::format(state, key::blocked_s, {str(refused)})));
		state.set(action.ref, str(key::availability), str(key::blocked));
		state.set(action.ref, str(key::invalid_reason), str(refused));
		state.set(contract.ref, str(key::ok), bool_value(false));
		state.set(contract.ref, str(key::selectable), bool_value(false));
		state.set(contract.ref, str(key::blocked_reason), str(refused));
	}
	return actions;
}

int64_t _reveal_spell_fog(State &state, DictRef session, int64_t radius) {
	// session == null: a view is never null.
	if (radius <= 0) {
		return 0;
	}
	if (!_fog_state_ready(state, session)) {
		_normalize_fog_of_war(state, session);
	}
	const Vector2i map_size = derive_map_size(state, session);
	// var fog: Dictionary = session.overworld.get(FOG_KEY, {}), only read.
	Value fog_value;
	const bool has_fog = state.lookup(session_view::overworld(state, session), str(key::fog), fog_value);
	const DictRef fog = has_fog ? gd::as_dict(fog_value) : state.new_dict();
	const int64_t before_count = gd::int_field(state, fog, key::explored_count, 0);
	Value explored_value;
	if (!state.lookup(fog, str(key::explored_tiles), explored_value)) {
		explored_value = array_value(state.new_array());
	}
	const ArrayRef explored_tiles = _normalize_visibility_grid(state, explored_value, map_size);
	// var hero: Dictionary = session.overworld.get("hero", {}) if it is a Dictionary else {}
	Value hero_value;
	const bool has_hero = state.lookup(session_view::overworld(state, session), str(key::hero), hero_value) && gd::is_dict(hero_value);
	int64_t x = 0;
	int64_t y = 0;
	if (has_hero) {
		Value position;
		if (state.lookup(hero_value.ref, str(key::position), position) && gd::is_dict(position)) {
			x = gd::int_field(state, position.ref, key::x, 0);
			y = gd::int_field(state, position.ref, key::y, 0);
		}
	}
	const DictRef site = state.new_dict();
	state.set(site, str(key::x), int_value(x));
	state.set(site, str(key::y), int_value(y));
	_apply_site_reveal(state, explored_tiles, site, radius, map_size);
	_reveal_all_current_fog_sources(state, session, explored_tiles, map_size, -1);
	const DictRef payload = _build_fog_payload(state, _duplicate_visibility_grid(state, explored_tiles), explored_tiles, map_size);
	_store_level_fog(state, session, payload);
	return compat::engine_max<int64_t>(0, gd::sub(gd::int_field(state, payload, key::explored_count, before_count), before_count));
}

} // namespace overworld_rules

namespace artifact_rules {

int64_t spell_effect_amount_delta(State &state, DictRef hero_state, DictRef spell) {
	int64_t delta = 0;
	for (const Value &modifier : gd::items(state, array_value(spell_affinity_records(state, hero_state, spell)))) {
		delta = gd::add(delta, gd::to_int(state, ai::vget(state, modifier, key::effect_amount_delta, int_value(0))));
	}
	return delta;
}

} // namespace artifact_rules

} // namespace aurelion::rules::port
