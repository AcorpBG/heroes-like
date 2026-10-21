// Layer 8: the battle side of a spell. The commander's cast of the round, the casting hero, the commit of a
// resistance roll, and the cast's animation states and presentation events.

#include "aurelion_rules/port/battle_rules.hpp"

#include "aurelion_rules/compat/godot_string.hpp"

#include <algorithm>
#include <string>
#include <vector>

namespace aurelion::rules::port::battle_rules {

using compat::engine_max;
using gd::bool_value;
using gd::dict_value;
using gd::int_value;
using gd::str;
using state::Kind;
namespace key = state::key;

namespace {

// d.get(key, {}): a new Dictionary when the key is missing.
Value get_or_new_dict(State &state, DictRef dict, Atom field) {
	Value found;
	if (state.lookup(dict, str(field), found)) {
		return found;
	}
	return dict_value(state.new_dict());
}

// String(d.get(field, "")).
Atom string_or_empty(const State &state, DictRef dict, Atom field) {
	return gd::string_field(state, dict, field, key::empty);
}

// session.battle and session.overworld: SessionData types both Dictionary.
DictRef session_battle(State &state, const Value &session) {
	return gd::as_dict(gd::member(state, session, key::battle));
}

DictRef session_overworld(State &state, const Value &session) {
	return gd::as_dict(gd::member(state, session, key::overworld));
}

// s.to_lower() of ASCII text (other text throws: the Unicode case tables are not ported).
Atom to_lower(State &state, Atom text) {
	std::string lowered = state.text(text);
	for (char &c : lowered) {
		if (static_cast<unsigned char>(c) >= 0x80) {
			throw state::ScriptError("to_lower() of non-ASCII text is not ported");
		}
		if (c >= 'A' && c <= 'Z') {
			c = static_cast<char>(c - 'A' + 'a');
		}
	}
	return state.intern(lowered);
}

// JSON.stringify(value) (no indent, sorted keys) of what a battle effect payload holds: null, bools, ints, Strings,
// StringNames, Arrays and Dictionaries with String keys. Anything else (a float needs String::num, other keys
// StringLikeVariantOrder, a control character other than json_escape's) is a ScriptError.
void append_json_string(const std::string &text, std::string &out) {
	out += '"';
	for (const char c : text) {
		switch (c) {
			case '\\':
				out += "\\\\";
				break;
			case '\b':
				out += "\\b";
				break;
			case '\f':
				out += "\\f";
				break;
			case '\n':
				out += "\\n";
				break;
			case '\r':
				out += "\\r";
				break;
			case '\t':
				out += "\\t";
				break;
			case '\v':
				out += "\\v";
				break;
			case '"':
				out += "\\\"";
				break;
			default:
				if (static_cast<unsigned char>(c) < 0x20) {
					throw state::ScriptError("JSON.stringify of a control character is not ported");
				}
				out += c;
				break;
		}
	}
	out += '"';
}

void append_json(const State &state, const Value &value, int depth, std::string &out) {
	if (depth > 128) {
		throw state::ScriptError("JSON.stringify of a structure this deep is not ported");
	}
	switch (value.kind) {
		case Kind::Nil:
			out += "null";
			return;
		case Kind::Bool:
			out += value.b ? "true" : "false";
			return;
		case Kind::Int:
			out += compat::itos(value.i);
			return;
		case Kind::String:
		case Kind::StringName:
			append_json_string(state.text(value.ref), out);
			return;
		case Kind::Array: {
			out += '[';
			const int64_t size = state.array_size(value.ref);
			for (int64_t index = 0; index < size; ++index) {
				if (index > 0) {
					out += ',';
				}
				append_json(state, state.at(value.ref, index), depth + 1, out);
			}
			out += ']';
			return;
		}
		case Kind::Dict: {
			const state::DictNode &node = state.dict(value.ref);
			const state::ValueList keys = node.keys.list();
			const state::ValueList values = node.values;
			for (const Value &entry_key : keys) {
				if (entry_key.kind != Kind::String) {
					throw state::ScriptError("JSON.stringify of a Dictionary with a key other than a String is not ported");
				}
			}
			// Distinct String keys: UTF-8 byte order is String's code point order.
			std::vector<size_t> order(keys.size());
			for (size_t index = 0; index < order.size(); ++index) {
				order[index] = index;
			}
			std::sort(order.begin(), order.end(), [&](size_t a, size_t b) { return state.text(keys.begin()[a].ref) < state.text(keys.begin()[b].ref); });
			out += '{';
			for (size_t position = 0; position < order.size(); ++position) {
				if (position > 0) {
					out += ',';
				}
				append_json_string(state.text(keys.begin()[order[position]].ref), out);
				out += ':';
				append_json(state, values.begin()[order[position]], depth + 1, out);
			}
			out += '}';
			return;
		}
		default:
			throw state::ScriptError(std::string("JSON.stringify of a ") + gd::type_name(value) + " is not ported");
	}
}

Atom json_stringify(State &state, const Value &value) {
	std::string out;
	append_json(state, value, 0, out);
	return state.intern(out);
}

} // namespace

DictRef _player_commander_state(State &state, const Value &session) {
	if (session.kind == Kind::Nil) {
		return state.new_dict();
	}
	if (gd::is_empty(state, session_battle(state, session))) {
		return gd::as_dict(get_or_new_dict(state, session_overworld(state, session), key::hero));
	}
	const Value commander = get_or_new_dict(state, session_battle(state, session), key::player_commander_state);
	return gd::is_dict(commander) ? commander.ref : gd::as_dict(get_or_new_dict(state, session_overworld(state, session), key::hero));
}

DictRef _normalize_commander_spell_cast_rounds(State &state, const Value &value) {
	const DictRef normalized = state.new_dict();
	if (!gd::is_dict(value)) {
		return normalized;
	}
	// value.keys(): a copy of the keys.
	const state::ValueList keys = state.dict(value.ref).keys.list();
	for (const Value &side_value : keys) {
		const Atom side = gd::to_string(side_value);
		if (side != key::player && side != key::enemy) {
			continue;
		}
		state.set(normalized, str(side), int_value(engine_max<int64_t>(0, gd::to_int(state, state.get(value.ref, side_value, int_value(0))))));
	}
	return normalized;
}

bool _commander_spell_cast_this_round(State &state, DictRef battle, Atom side) {
	if (gd::is_empty(state, battle) || side == key::empty) {
		return false;
	}
	const DictRef cast_rounds = _normalize_commander_spell_cast_rounds(state, get_or_new_dict(state, battle, key::commander_spell_cast_rounds));
	return gd::int_field(state, cast_rounds, side, 0) >= gd::int_field(state, battle, key::round, 1);
}

void _mark_commander_spell_cast(State &state, DictRef battle, Atom side) {
	if (gd::is_empty(state, battle) || side == key::empty) {
		return;
	}
	const DictRef cast_rounds = _normalize_commander_spell_cast_rounds(state, get_or_new_dict(state, battle, key::commander_spell_cast_rounds));
	state.set(cast_rounds, str(side), int_value(gd::int_field(state, battle, key::round, 1)));
	state.set(battle, str(key::commander_spell_cast_rounds), dict_value(cast_rounds));
}

Atom hero_actor_id(State &state, Atom side) {
	return state.intern(state.text(key::hero_actor_prefix) + state.text(side));
}

Atom commander_name(State &state, DictRef battle, Atom side) {
	const bool player = side == key::player;
	const Atom fields[] = { player ? key::player_commander_state : key::enemy_hero, player ? key::player_hero : key::enemy_hero_payload };
	for (const Atom field : fields) {
		const Value payload = get_or_new_dict(state, battle, field);
		if (gd::is_dict(payload) && gd::strip_edges(state, string_or_empty(state, payload.ref, key::name)) != key::empty) {
			return gd::strip_edges(state, string_or_empty(state, payload.ref, key::name));
		}
	}
	return key::empty;
}

DictRef _hero_caster(State &state, DictRef battle, Atom side) {
	Atom name = commander_name(state, battle, side);
	if (name == key::empty) {
		name = side == key::player ? key::your_hero_text : key::the_enemy_hero_text;
	}
	const DictRef caster = state.new_dict();
	state.set(caster, str(key::battle_id), str(hero_actor_id(state, side)));
	state.set(caster, str(key::side), str(side));
	state.set(caster, str(key::name), str(name));
	return caster;
}

void _commit_spell_resistance_roll(State &state, DictRef battle, DictRef resolution) {
	const Atom state_text = gd::strip_edges(state, string_or_empty(state, resolution, key::resistance_rng_state));
	if (!gd::is_valid_int(state, state_text)) {
		return;
	}
	// RandomNumberGenerator.new() with its state set: _commit_damage_rng_roll reads only the state, so the seed
	// (random in GDScript) is any value.
	const Value rng = gd::rng_new(state, 0, compat::to_int(state.text(state_text)));
	_commit_damage_rng_roll(state, battle, rng);
}

void _mark_spell_animation_states(State &state, DictRef battle, DictRef caster_stack, DictRef resolution) {
	const Atom target_id = gd::strip_edges(state, string_or_empty(state, resolution, key::target_battle_id));
	const DictRef spell_context = state.new_dict();
	state.set(spell_context, str(key::spell_id), str(gd::strip_edges(state, string_or_empty(state, resolution, key::spell_id))));
	state.set(spell_context, str(key::resolution_type), str(gd::strip_edges(state, string_or_empty(state, resolution, key::resolution_type))));
	if (target_id != key::empty) {
		state.set(spell_context, str(key::target_battle_id), str(target_id));
	}
	_mark_stack_animation_event(state, battle, string_or_empty(state, caster_stack, key::battle_id), key::battle_unit_cast, spell_context);
	if (target_id == key::empty) {
		return;
	}
	const DictRef target_context = gd::deep_duplicate_dict(state, spell_context);
	state.set(target_context, str(key::source_battle_id), str(string_or_empty(state, caster_stack, key::battle_id)));
	const Atom resolution_type = string_or_empty(state, resolution, key::resolution_type);
	if (resolution_type == key::damage) {
		const Value post_damage_effect = get_or_new_dict(state, resolution, key::post_damage_effect);
		const Value before = get_or_new_dict(state, resolution, key::playback_target_before);
		const DictRef target_before = gd::is_dict(before) ? before.ref : state.new_dict();
		const bool had_status_effect = gd::is_dict(post_damage_effect) && !gd::is_empty(state, post_damage_effect.ref);
		_mark_damage_target_animation(state, battle, target_id, had_status_effect, string_or_empty(state, caster_stack, key::battle_id), target_context, target_before);
	} else if (resolution_type == key::effect || resolution_type == key::recover_effect) {
		_mark_stack_animation_event(state, battle, target_id, key::battle_status_applied, target_context);
	} else if (resolution_type == key::cleanse_effect) {
		const Atom event_id = gd::int_field(state, resolution, key::cleansed_effect_count, 0) > 0 ? key::battle_status_expired : key::battle_status_applied;
		_mark_stack_animation_event(state, battle, target_id, event_id, target_context);
	}
}

void _append_spell_presentation_events(State &state, DictRef battle, DictRef caster_stack, DictRef resolution, DictRef target_before, DictRef target_after, int64_t recovered_amount, int64_t cleansed_count, Atom action_id) {
	const Atom spell_id = gd::strip_edges(state, string_or_empty(state, resolution, key::spell_id));
	const Atom spell_name = spell_id != key::empty
			? gd::string_field(state, gd::content_row(state, state::ContentTable::Spell, spell_id), key::name, spell_id)
			: static_cast<Atom>(key::spell_word);
	const DictRef target_stack = !gd::is_empty(state, target_after) ? target_after : target_before;
	const Atom target_name = !gd::is_empty(state, target_stack) ? _stack_label(state, target_stack) : static_cast<Atom>(key::the_target_text);
	// The literal's values in its order.
	const Atom actor_battle_id = string_or_empty(state, caster_stack, key::battle_id);
	const Atom actor_name = _stack_label(state, caster_stack);
	const Atom side = string_or_empty(state, caster_stack, key::side);
	const Atom target_battle_id = string_or_empty(state, target_stack, key::battle_id);
	const DictRef base_context = state.new_dict();
	state.set(base_context, str(key::action_id), str(action_id));
	state.set(base_context, str(key::actor_battle_id), str(actor_battle_id));
	state.set(base_context, str(key::actor_name), str(actor_name));
	state.set(base_context, str(key::side), str(side));
	state.set(base_context, str(key::target_battle_id), str(target_battle_id));
	state.set(base_context, str(key::spell_id), str(spell_id));
	state.set(base_context, str(key::spell_name), str(spell_name));
	_append_presentation_event(state, battle, key::cast, gd::format(state, key::casts_on_format, { str(_stack_label(state, caster_stack)), str(spell_name), str(target_name) }), base_context);
	const Atom resolution_type = string_or_empty(state, resolution, key::resolution_type);
	if (resolution_type == key::damage) {
		_append_damage_presentation_event(state, battle, key::spell_damage, caster_stack, target_before, target_after, gd::int_field(state, resolution, key::damage, 0), action_id, base_context);
		if (gd::int_field(state, resolution, key::prevented_damage, 0) > 0) {
			const DictRef resist_context = gd::deep_duplicate_dict(state, base_context);
			state.set(resist_context, str(key::prevented_damage), int_value(gd::int_field(state, resolution, key::prevented_damage, 0)));
			state.set(resist_context, str(key::resisted), bool_value(true));
			const Atom text = gd::format(state, key::resists_damage_from_format, { str(target_name), int_value(gd::int_field(state, resolution, key::prevented_damage, 0)), str(spell_name) });
			_append_presentation_event(state, battle, key::resist, text, resist_context);
		}
		_append_spell_status_resolution_event(state, battle, resolution, base_context, target_name, key::post_damage);
	} else if (resolution_type == key::effect) {
		_append_spell_status_resolution_event(state, battle, resolution, base_context, target_name, key::empty);
	} else if (resolution_type == key::recover_effect) {
		if (recovered_amount > 0) {
			const DictRef heal_context = gd::deep_duplicate_dict(state, base_context);
			state.set(heal_context, str(key::healing), int_value(recovered_amount));
			const Atom text = gd::format(state, key::recovers_health_from_format, { str(target_name), int_value(recovered_amount), str(spell_name) });
			_append_presentation_event(state, battle, key::heal, text, heal_context);
		}
		_append_spell_effect_event(state, battle, key::buff, get_or_new_dict(state, resolution, key::effect), base_context, target_name);
	} else if (resolution_type == key::cleanse_effect) {
		if (cleansed_count > 0) {
			const Atom plural = cleansed_count == 1 ? static_cast<Atom>(key::empty) : static_cast<Atom>(key::s);
			const Atom text = gd::format(state, key::sheds_pressure_effects_format, { str(target_name), int_value(cleansed_count), str(plural) });
			_append_presentation_event(state, battle, key::cleanse, text, base_context);
		}
		_append_spell_effect_event(state, battle, key::buff, get_or_new_dict(state, resolution, key::effect), base_context, target_name);
	}
}

void _append_spell_status_resolution_event(State &state, DictRef battle, DictRef resolution, DictRef base_context, Atom target_name, Atom prefix) {
	const Atom resisted_key = prefix != key::empty ? gd::format(state, key::resisted_key_format, { str(prefix) }) : static_cast<Atom>(key::resisted);
	const Atom immune_key = prefix != key::empty ? gd::format(state, key::immune_key_format, { str(prefix) }) : static_cast<Atom>(key::immune);
	const Atom effect_key = prefix != key::empty ? gd::format(state, key::effect_key_format, { str(prefix) }) : static_cast<Atom>(key::effect);
	if (gd::bool_field(state, resolution, immune_key, false)) {
		const DictRef immune_context = gd::deep_duplicate_dict(state, base_context);
		state.set(immune_context, str(key::immune), bool_value(true));
		const Atom text = gd::format(state, key::is_immune_to_format, { str(target_name), str(_spell_effect_label(state, get_or_new_dict(state, resolution, effect_key))) });
		_append_presentation_event(state, battle, key::immune, text, immune_context);
		return;
	}
	if (gd::bool_field(state, resolution, resisted_key, false)) {
		const DictRef resist_context = gd::deep_duplicate_dict(state, base_context);
		state.set(resist_context, str(key::resisted), bool_value(true));
		const Atom text = gd::format(state, key::resists_format, { str(target_name), str(_spell_effect_label(state, get_or_new_dict(state, resolution, effect_key))) });
		_append_presentation_event(state, battle, key::resist, text, resist_context);
		return;
	}
	_append_spell_effect_event(state, battle, key::debuff, get_or_new_dict(state, resolution, effect_key), base_context, target_name);
}

void _append_spell_effect_event(State &state, DictRef battle, Atom event_type, const Value &effect_payload, DictRef base_context, Atom target_name) {
	if (!gd::is_dict(effect_payload) || gd::is_empty(state, effect_payload.ref)) {
		return;
	}
	const Atom label = _spell_effect_label(state, effect_payload);
	const Atom text = gd::format(state, key::gains_format, { str(target_name), str(label) });
	// base_context.merged({"detail_text": ...}, true): a shallow copy with the key set.
	const DictRef context = gd::duplicate_dict(state, base_context);
	state.set(context, str(key::detail_text), str(json_stringify(state, effect_payload)));
	_append_presentation_event(state, battle, event_type, text, context);
}

Atom _spell_effect_label(State &state, const Value &effect_payload) {
	if (!gd::is_dict(effect_payload) || gd::is_empty(state, effect_payload.ref)) {
		return key::the_effect_text;
	}
	const DictRef payload = effect_payload.ref;
	const Value kind_fallback = state.get(payload, str(key::kind), str(key::the_effect_text));
	const Value id_fallback = state.get(payload, str(key::effect_id), kind_fallback);
	return to_lower(state, gd::to_string(state.get(payload, str(key::label), id_fallback)));
}

} // namespace aurelion::rules::port::battle_rules
