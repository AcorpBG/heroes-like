// OverworldRules for the human seat's overworld spells (Phase 7, slice 7.4):
// casting a spell, the spell actions and the fog a scouting spell reveals.
// ArtifactRules.spell_effect_amount_delta is here too.

#include "aurelion_rules/port/overworld_rules_spells.hpp"

#include "aurelion_rules/port/ai_port.hpp"
#include "aurelion_rules/port/artifact_rules.hpp"
#include "aurelion_rules/port/overworld_rules.hpp"
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

} // namespace

namespace overworld_rules {

DictRef cast_overworld_spell(State &state, DictRef session, Atom spell_id) {
	normalize_overworld_state(state, session);
	const DictRef overworld = session_view::overworld(state, session);
	const Value hero = field_or_new_dict(state, overworld, key::hero);
	const Value movement = field_or_new_dict(state, overworld, key::movement);
	const DictRef result = spell_rules::cast_overworld_spell(state, gd::as_dict(hero), gd::as_dict(movement), spell_id, ai::session_int(state, session, key::day));
	if (!gd::bool_field(state, result, key::ok, false)) {
		const DictRef refusal = state.new_dict();
		state.set(refusal, str(key::ok), bool_value(false));
		state.set(refusal, str(key::message), str(string_of(state, state.get(result, str(key::message), str(key::spell_casting_failed_text)))));
		return refusal;
	}

	state.set(overworld, str(key::hero), state.get(result, str(key::hero), hero));
	state.set(overworld, str(key::movement), state.get(result, str(key::movement), movement));
	const int64_t revealed_tiles = _reveal_spell_fog(state, session, gd::int_field(state, result, key::fog_reveal_radius, 0));
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
	return spell_rules::get_overworld_actions(state, gd::as_dict(hero), gd::as_dict(movement), ai::session_int(state, session, key::day));
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
