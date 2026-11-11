// Layer 8: the battle side of a spell. The commander's cast of the round, the casting hero, the commit of a
// resistance roll, and the cast's animation states and presentation events; the player's cast resolved against its
// target.

#include "aurelion_rules/port/artifact_rules.hpp"
#include "aurelion_rules/port/battle_rules.hpp"

#include "aurelion_rules/compat/godot_string.hpp"
#include "aurelion_rules/port/spell_rules.hpp"

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

// d.get(key, []): a new Array when the key is missing.
Value get_or_new_array(State &state, DictRef dict, Atom field) {
	Value found;
	if (state.lookup(dict, str(field), found)) {
		return found;
	}
	return gd::array_value(state.new_array());
}

// effect is Dictionary and not effect.is_empty() of d.get(field, {}).
bool nonempty_dict_field(State &state, DictRef dict, Atom field, Value &out) {
	return state.lookup(dict, str(field), out) && gd::is_dict(out) && !gd::is_empty(state, out.ref);
}

// a + b of Strings.
Atom concat(State &state, Atom a, Atom b) {
	std::string joined = state.text(a);
	joined += state.text(b);
	return state.intern(joined);
}

// "" for one, "s" for more.
Atom plural_s(int64_t count) {
	return count == 1 ? static_cast<Atom>(key::empty) : static_cast<Atom>(key::s);
}

// {"ok": false, "message": message}.
DictRef refusal(State &state, Atom message) {
	const DictRef result = state.new_dict();
	state.set(result, str(key::ok), bool_value(false));
	state.set(result, str(key::message), str(message));
	return result;
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
		case Kind::Float:
			out += compat::json_float(value.f);
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
	// Twofold Diadem: its wearer's first cast of the first round leaves it a second one.
	if (gd::int_field(state, battle, key::round, 1) == 1 && _hero_has_special(state, battle, side, key::special_second_spell)) {
		Value granted;
		if (!state.lookup(battle, str(key::second_casts_granted), granted) || !gd::is_dict(granted)) {
			granted = dict_value(state.new_dict());
			state.set(battle, str(key::second_casts_granted), granted);
		}
		if (!gd::bool_field(state, granted.ref, side, false)) {
			state.set(granted.ref, str(side), gd::bool_value(true));
			return;
		}
	}
	const DictRef cast_rounds = _normalize_commander_spell_cast_rounds(state, get_or_new_dict(state, battle, key::commander_spell_cast_rounds));
	state.set(cast_rounds, str(side), int_value(gd::int_field(state, battle, key::round, 1)));
	state.set(battle, str(key::commander_spell_cast_rounds), dict_value(cast_rounds));
}

int64_t _side_mana_current(State &state, DictRef battle, Atom side) {
	Value commander;
	Value spellbook;
	Value mana;
	if (!state.lookup(battle, str(side == key::player ? key::player_commander_state : key::enemy_hero), commander) || !gd::is_dict(commander)
			|| !state.lookup(commander.ref, str(key::spellbook), spellbook) || !gd::is_dict(spellbook)
			|| !state.lookup(spellbook.ref, str(key::mana), mana) || !gd::is_dict(mana)) {
		return 0;
	}
	return gd::int_field(state, mana.ref, key::current, 0);
}

// Lens and Flame: a spell that destroys a stack returns half its mana.
void _refund_spell_for_kill(State &state, const Value &session, Atom side, int64_t living_before, int64_t mana_before) {
	const DictRef battle = session_battle(state, session);
	if (gd::is_empty(state, battle) || !_hero_has_special(state, battle, side, key::special_kill_refund)) {
		return;
	}
	if (state.array_size(_alive_stacks_for_side(state, battle, side == key::player ? key::enemy : key::player)) >= living_before) {
		return;
	}
	Value commander;
	Value spellbook;
	Value mana;
	if (!state.lookup(battle, str(side == key::player ? key::player_commander_state : key::enemy_hero), commander) || !gd::is_dict(commander)
			|| !state.lookup(commander.ref, str(key::spellbook), spellbook) || !gd::is_dict(spellbook)
			|| !state.lookup(spellbook.ref, str(key::mana), mana) || !gd::is_dict(mana)) {
		return;
	}
	const int64_t current = gd::int_field(state, mana.ref, key::current, 0);
	const int64_t refund = gd::sub(mana_before, current) / 2;
	if (refund <= 0) {
		return;
	}
	const int64_t most = gd::int_field(state, mana.ref, key::max, current);
	const int64_t after = gd::add(current, refund);
	state.set(mana.ref, str(key::current), int_value(after > most && most >= current ? most : after));
	if (side == key::player) {
		const DictRef bonuses = artifact_rules::aggregate_bonuses(state, commander.ref);
		state.set(battle, str(key::player_hero), dict_value(_hero_payload_from_state(state, commander.ref, bonuses, session, key::player)));
	} else {
		const Value existing = get_or_new_dict(state, battle, key::enemy_hero_payload);
		state.set(battle, str(key::enemy_hero_payload), dict_value(_enemy_hero_payload_from_state(state, commander.ref, existing, session)));
	}
	_record_event(state, battle, gd::format(state, state.intern("The Lens returns %d mana from The Flame."), { int_value(refund) }));
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

// The stacks a conjure put on the field, by the ids _apply_spell_resolution_on_target wrote into the board's copy.
ArrayRef _conjured_battle_ids(State &state, DictRef resolution) {
	const ArrayRef ids = state.new_array();
	Value one;
	if (nonempty_dict_field(state, resolution, key::conjured_stack, one)) {
		const Atom id = gd::strip_edges(state, string_or_empty(state, one.ref, key::battle_id));
		if (id != key::empty) {
			state.append(ids, str(id));
		}
	}
	for (const Value &each : gd::field_items(state, resolution, str(key::conjured_stacks))) {
		if (!gd::is_dict(each)) {
			continue;
		}
		const Atom id = gd::strip_edges(state, string_or_empty(state, each.ref, key::battle_id));
		if (id != key::empty) {
			state.append(ids, str(id));
		}
	}
	return ids;
}

// One stack's share of a cast on the board: the reaction its resolution plays there, with the spell's cue.
void _mark_spell_target_animation(State &state, DictRef battle, DictRef caster_stack, DictRef resolution, DictRef spell_context, Atom target_id) {
	const DictRef target_context = gd::deep_duplicate_dict(state, spell_context);
	state.set(target_context, str(key::target_battle_id), str(target_id));
	state.set(target_context, str(key::resolution_type), str(gd::strip_edges(state, string_or_empty(state, resolution, key::resolution_type))));
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
	} else if (resolution_type == key::cleanse_effect || resolution_type == key::dispel_effect) {
		const Atom event_id = gd::int_field(state, resolution, key::cleansed_effect_count, 0) > 0 ? key::battle_status_expired : key::battle_status_applied;
		_mark_stack_animation_event(state, battle, target_id, event_id, target_context);
	} else if (resolution_type == key::move_effect) {
		// The moved stack walks its way, as a move order's stack does.
		const DictRef move_context = gd::deep_duplicate_dict(state, target_context);
		for (const Atom field : { key::from_q, key::from_r, key::to_q, key::to_r }) {
			state.set(move_context, str(field), int_value(gd::int_field(state, resolution, field, -1)));
		}
		_mark_stack_animation_event(state, battle, target_id, key::battle_unit_move, move_context);
	}
}

// The board plays a cast's cue where the cast lands: on its target; a summon on the stacks it conjured; a hex spell
// on the first hex of its ground; and every stack a mass or mastery spell reaches beyond its target on that stack.
void _mark_spell_animation_states(State &state, DictRef battle, DictRef caster_stack, DictRef resolution) {
	Atom target_id = gd::strip_edges(state, string_or_empty(state, resolution, key::target_battle_id));
	const ArrayRef conjured_ids = _conjured_battle_ids(state, resolution);
	if (target_id == key::empty && state.array_size(conjured_ids) > 0) {
		target_id = gd::strip_edges(state, gd::to_string(state.at(conjured_ids, 0)));
	}
	const DictRef spell_context = state.new_dict();
	state.set(spell_context, str(key::spell_id), str(gd::strip_edges(state, string_or_empty(state, resolution, key::spell_id))));
	state.set(spell_context, str(key::resolution_type), str(gd::strip_edges(state, string_or_empty(state, resolution, key::resolution_type))));
	if (target_id != key::empty) {
		state.set(spell_context, str(key::target_battle_id), str(target_id));
	} else {
		Value entry;
		if (nonempty_dict_field(state, resolution, key::ground_entry, entry)) {
			for (const Value &cell : gd::field_items(state, entry.ref, str(key::cells))) {
				if (!gd::is_dict(cell)) {
					continue;
				}
				const int64_t q = gd::int_field(state, cell.ref, key::q, -1);
				const int64_t r = gd::int_field(state, cell.ref, key::r, -1);
				state.set(spell_context, str(key::from_q), int_value(q));
				state.set(spell_context, str(key::from_r), int_value(r));
				state.set(spell_context, str(key::to_q), int_value(q));
				state.set(spell_context, str(key::to_r), int_value(r));
				break;
			}
		}
	}
	_mark_stack_animation_event(state, battle, string_or_empty(state, caster_stack, key::battle_id), key::battle_unit_cast, spell_context);
	if (target_id != key::empty) {
		_mark_spell_target_animation(state, battle, caster_stack, resolution, spell_context, target_id);
	}
	for (const Value &id : gd::items(state, gd::array_value(conjured_ids))) {
		const DictRef conjured_context = gd::deep_duplicate_dict(state, spell_context);
		state.set(conjured_context, str(key::target_battle_id), id);
		state.set(conjured_context, str(key::source_battle_id), str(string_or_empty(state, caster_stack, key::battle_id)));
		_mark_stack_animation_event(state, battle, gd::to_string(id), key::battle_status_applied, conjured_context);
	}
	for (const Value &extra : gd::field_items(state, resolution, str(key::extra_resolutions))) {
		if (!gd::is_dict(extra)) {
			continue;
		}
		const Atom extra_target = gd::strip_edges(state, string_or_empty(state, extra.ref, key::target_battle_id));
		if (extra_target != key::empty && extra_target != target_id) {
			_mark_spell_target_animation(state, battle, caster_stack, extra.ref, spell_context, extra_target);
		}
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
	const Atom resolution_type = string_or_empty(state, resolution, key::resolution_type);
	// A hex spell names no stack.
	const Atom cast_text = resolution_type == key::ground_effect
			? gd::format(state, key::s_casts_s, { str(_stack_label(state, caster_stack)), str(spell_name) })
			: gd::format(state, key::casts_on_format, { str(_stack_label(state, caster_stack)), str(spell_name), str(target_name) });
	_append_presentation_event(state, battle, key::cast, cast_text, base_context);
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
	} else if (resolution_type == key::dispel_effect) {
		if (cleansed_count > 0) {
			const Atom text = gd::format(state, key::loses_spell_effects_format, { str(target_name), int_value(cleansed_count), str(plural_s(cleansed_count)) });
			_append_presentation_event(state, battle, key::cleanse, text, base_context);
		}
	} else if (resolution_type == key::move_effect) {
		const DictRef to_hex = _hex_cell(state, gd::int_field(state, resolution, key::to_q, -1), gd::int_field(state, resolution, key::to_r, -1));
		const Atom text = gd::format(state, key::moves_to_format, { str(target_name), str(_hex_label(state, to_hex)) });
		_append_presentation_event(state, battle, key::move_, text, base_context);
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

DictRef _player_spell_resolution(State &state, const Value &session, Atom spell_id, Atom target_id) {
	return _player_spell_resolution(state, session, spell_id, target_id, Value());
}

DictRef _player_spell_resolution(State &state, const Value &session, Atom spell_id, Atom target_id, const Value &destination) {
	const DictRef battle = session_battle(state, session);
	const DictRef active = get_active_stack(state, battle);
	const DictRef target = target_id == key::empty ? get_selected_target(state, battle) : _get_stack_by_id(state, battle, target_id);
	if (target_id != key::empty && (gd::is_empty(state, target) || _alive_count(state, target) <= 0)) {
		return refusal(state, key::spell_target_not_alive_text);
	}
	const DictRef resolution = spell_rules::resolve_battle_spell(state, _player_commander_state(state, session), battle, active, target, spell_id, key::player, destination);
	// Explicit orders must never inherit the legacy support-spell fallback to the active stack.
	// (A cast Prism Ward turned aside lands elsewhere by design.)
	// (An echo names the stack its spell named.)
	if (target_id != key::empty && gd::bool_field(state, resolution, key::ok, false) && string_or_empty(state, resolution, key::target_battle_id) != target_id
			&& string_or_empty(state, resolution, key::reflected_from_battle_id) != target_id && string_or_empty(state, resolution, key::echo_of) == key::empty) {
		return refusal(state, key::stack_not_valid_spell_target_text);
	}
	return resolution;
}

// One stack's share of a cast: the target's, or a stack it reaches beyond (spell_reach.cpp).
bool _apply_spell_resolution_on_target(State &state, DictRef battle, DictRef resolution, DictRef animation_resolution, Atom &message, int64_t &recovered_amount, int64_t &cleansed_count);

bool _apply_spell_resolution(State &state, DictRef battle, DictRef resolution, DictRef animation_resolution, Atom &message, int64_t &recovered_amount, int64_t &cleansed_count) {
	if (!_apply_spell_resolution_on_target(state, battle, resolution, animation_resolution, message, recovered_amount, cleansed_count)) {
		return false;
	}
	// Each reached stack's board copy is its entry in the animation resolution's extra_resolutions (a copy of the
	// cast's), which _mark_spell_animation_states plays the spell on.
	const Value animation_extras = gd::field(state, animation_resolution, key::extra_resolutions);
	int64_t index = -1;
	for (const Value &extra : gd::field_items(state, resolution, str(key::extra_resolutions))) {
		index += 1;
		if (!gd::is_dict(extra)) {
			continue;
		}
		message = concat(state, message, gd::string_field(state, extra.ref, key::message, key::empty));
		int64_t extra_recovered = 0;
		int64_t extra_cleansed = 0;
		DictRef extra_animation = state.new_dict();
		if (gd::is_array(animation_extras) && index < state.array_size(animation_extras.ref) && gd::is_dict(state.at(animation_extras.ref, index))) {
			extra_animation = state.at(animation_extras.ref, index).ref;
		}
		_apply_spell_resolution_on_target(state, battle, extra.ref, extra_animation, message, extra_recovered, extra_cleansed);
	}
	return true;
}

bool _apply_spell_resolution_on_target(State &state, DictRef battle, DictRef resolution, DictRef animation_resolution, Atom &message, int64_t &recovered_amount, int64_t &cleansed_count) {
	const Atom target_battle_id = string_or_empty(state, resolution, key::target_battle_id);
	const Atom resolution_type = string_or_empty(state, resolution, key::resolution_type);
	const Atom reflected_from = string_or_empty(state, resolution, key::reflected_from_battle_id);
	if (reflected_from != key::empty) {
		spell_rules::spend_reflect_ward(state, battle, reflected_from);
	}
	if (resolution_type == key::damage) {
		const DictRef before_copy = gd::duplicate_dict(state, _get_stack_by_id(state, battle, target_battle_id));
		state.set(animation_resolution, str(key::playback_target_before), dict_value(before_copy));
		_apply_damage_to_stack(state, battle, target_battle_id, gd::int_field(state, resolution, key::damage, 0));
		// Heat (Ember Lash): it builds on the stack and bursts at the third.
		const int64_t heat = gd::int_field(state, resolution, key::heat, 0);
		if (heat > 0) {
			// Molten Deluge's Heat stops short of a burst.
			const Atom heat_message = gd::bool_field(state, resolution, key::heat_short_of_burst, false)
					? spell_rules::heat_short_of_burst(state, battle, target_battle_id, heat)
					: spell_rules::add_heat(state, battle, target_battle_id, heat, gd::int_field(state, resolution, key::heat_burst_damage, 0));
			if (heat_message != key::empty) {
				message = concat(state, message, heat_message);
			}
		}
		const DictRef target_after = _get_stack_by_id(state, battle, target_battle_id);
		if (!gd::is_empty(state, target_after) && _alive_count(state, target_after) <= 0) {
			message = concat(state, message, gd::format(state, key::stack_destroyed_suffix_text, { str(_stack_label(state, target_after)) }));
			return true;
		}
		// Flashpoint spends the Heat it set off, or kindles one.
		if (gd::bool_field(state, resolution, key::heat_burst, false)) {
			message = concat(state, message, spell_rules::spend_or_kindle_heat(state, battle, target_battle_id));
		}
		// Earthsplit knocks the stack back, when that hex is still free.
		Value push_to;
		if (nonempty_dict_field(state, resolution, key::push_to, push_to) && !gd::is_empty(state, target_after)) {
			const DictRef cell = spell_rules::push_cell(state, battle, target_after, 1);
			if (!gd::is_empty(state, cell) && gd::int_field(state, cell, key::q, -1) == gd::int_field(state, push_to.ref, key::q, -2)
					&& gd::int_field(state, cell, key::r, -1) == gd::int_field(state, push_to.ref, key::r, -2)) {
				_set_stack_hex(state, battle, target_battle_id, cell);
				_sync_distance_from_hexes(state, battle);
				message = concat(state, message, gd::format(state, key::knocked_back_suffix_text, { str(_stack_label(state, target_after)) }));
			}
		}
		return true;
	}
	if (resolution_type == key::effect) {
		Value effect_payload;
		if (nonempty_dict_field(state, resolution, key::effect, effect_payload)) {
			// A new graft replaces the stack's old one at both ends.
			if (state.has(spell_rules::effect_mechanic(state, effect_payload.ref), str(key::graft_partner))) {
				spell_rules::clear_graft(state, battle, target_battle_id);
			}
			_apply_stack_effect(state, battle, target_battle_id, effect_payload);
			// Call to Arms: the stack acts next.
			if (gd::int_field(state, spell_rules::effect_mechanic(state, effect_payload.ref), key::act_next, 0) > 0) {
				spell_rules::act_next(state, battle, target_battle_id);
			}
			// Daybreak Charge: the stack acts before any enemy stack next round.
			if (gd::int_field(state, spell_rules::effect_mechanic(state, effect_payload.ref), key::act_first_next, 0) > 0) {
				spell_rules::act_first_next_round(state, battle, target_battle_id);
			}
			// Clarion Call: another full turn right after its next one.
			if (gd::int_field(state, spell_rules::effect_mechanic(state, effect_payload.ref), key::extra_turn, 0) > 0) {
				spell_rules::grant_extra_turn(state, battle, target_battle_id);
			}
		}
		Value follow_payload;
		if (nonempty_dict_field(state, resolution, key::follow_effect, follow_payload)) {
			_apply_stack_effect(state, battle, target_battle_id, follow_payload);
		}
		return true;
	}
	if (resolution_type == key::recover_effect) {
		const int64_t cleared = _cleanse_stack_effects(state, battle, target_battle_id, get_or_new_array(state, resolution, key::cleanse_status_ids));
		if (cleared > 0) {
			cleansed_count = cleared;
			const Atom label = _stack_label(state, _get_stack_by_id(state, battle, target_battle_id));
			message = concat(state, message, gd::format(state, key::sheds_pressure_suffix_text, { str(label), int_value(cleared), str(plural_s(cleared)) }));
		}
		// Rekindle raises fallen creatures; other healing mends the wounded one.
		const int64_t amount = gd::int_field(state, resolution, key::recovery_amount, 0);
		const int64_t recovered = gd::bool_field(state, resolution, key::raise, false)
				? spell_rules::raise_stack_health(state, battle, target_battle_id, amount)
				: _restore_stack_health(state, battle, target_battle_id, amount);
		recovered_amount = recovered;
		if (recovered > 0) {
			const Atom label = _stack_label(state, _get_stack_by_id(state, battle, target_battle_id));
			message = concat(state, message, gd::format(state, key::recovers_health_suffix_text, { str(label), int_value(recovered) }));
		}
		Value recovery_effect;
		if (nonempty_dict_field(state, resolution, key::effect, recovery_effect)) {
			_apply_stack_effect(state, battle, target_battle_id, recovery_effect);
		}
		// Hot Iron seals the wound after its own heal.
		Value heal_block_effect;
		if (nonempty_dict_field(state, resolution, key::heal_block_effect, heal_block_effect)) {
			_apply_stack_effect(state, battle, target_battle_id, heal_block_effect);
		}
		return true;
	}
	if (resolution_type == key::cleanse_effect) {
		const int64_t cleansed = _cleanse_stack_effects(state, battle, target_battle_id, get_or_new_array(state, resolution, key::cleanse_effect_ids));
		cleansed_count = cleansed;
		state.set(animation_resolution, str(key::cleansed_effect_count), int_value(cleansed));
		if (cleansed > 0) {
			const Atom label = _stack_label(state, _get_stack_by_id(state, battle, target_battle_id));
			const Atom plural = cleansed == 1 ? static_cast<Atom>(key::empty) : static_cast<Atom>(key::s);
			message = concat(state, message, gd::format(state, key::sheds_pressure_suffix_text, { str(label), int_value(cleansed), str(plural) }));
		}
		Value cleanse_effect;
		if (nonempty_dict_field(state, resolution, key::effect, cleanse_effect)) {
			_apply_stack_effect(state, battle, target_battle_id, cleanse_effect);
		}
		return true;
	}
	if (resolution_type == key::dispel_effect) {
		const int64_t removed = _cleanse_stack_effects(state, battle, target_battle_id, get_or_new_array(state, resolution, key::cleanse_effect_ids));
		cleansed_count = removed;
		state.set(animation_resolution, str(key::cleansed_effect_count), int_value(removed));
		if (removed > 0) {
			const Atom label = _stack_label(state, _get_stack_by_id(state, battle, target_battle_id));
			message = concat(state, message, gd::format(state, key::loses_spell_effects_suffix_text, { str(label), int_value(removed), str(plural_s(removed)) }));
		}
		return true;
	}
	if (resolution_type == key::move_effect) {
		const DictRef from_hex = gd::deep_duplicate_dict(state, _stack_hex(state, _get_stack_by_id(state, battle, target_battle_id)));
		const DictRef destination = gd::as_dict(get_or_new_dict(state, resolution, key::destination));
		_set_stack_hex(state, battle, target_battle_id, destination);
		_sync_distance_from_hexes(state, battle);
		const DictRef to_hex = _stack_hex(state, _get_stack_by_id(state, battle, target_battle_id));
		state.set(animation_resolution, str(key::from_q), int_value(gd::int_field(state, from_hex, key::q, -1)));
		state.set(animation_resolution, str(key::from_r), int_value(gd::int_field(state, from_hex, key::r, -1)));
		state.set(animation_resolution, str(key::to_q), int_value(gd::int_field(state, to_hex, key::q, -1)));
		state.set(animation_resolution, str(key::to_r), int_value(gd::int_field(state, to_hex, key::r, -1)));
		const Atom label = _stack_label(state, _get_stack_by_id(state, battle, target_battle_id));
		message = concat(state, message, gd::format(state, key::moves_to_suffix_text, { str(label), str(_hex_label(state, to_hex)) }));
		return true;
	}
	// Uproot: the stack is dragged to its hex, then staggered.
	if (resolution_type == key::pull_effect) {
		const DictRef from_hex = gd::deep_duplicate_dict(state, _stack_hex(state, _get_stack_by_id(state, battle, target_battle_id)));
		const DictRef destination = gd::as_dict(get_or_new_dict(state, resolution, key::destination));
		_set_stack_hex(state, battle, target_battle_id, destination);
		_sync_distance_from_hexes(state, battle);
		const DictRef to_hex = _stack_hex(state, _get_stack_by_id(state, battle, target_battle_id));
		state.set(animation_resolution, str(key::from_q), int_value(gd::int_field(state, from_hex, key::q, -1)));
		state.set(animation_resolution, str(key::from_r), int_value(gd::int_field(state, from_hex, key::r, -1)));
		state.set(animation_resolution, str(key::to_q), int_value(gd::int_field(state, to_hex, key::q, -1)));
		state.set(animation_resolution, str(key::to_r), int_value(gd::int_field(state, to_hex, key::r, -1)));
		const Atom label = _stack_label(state, _get_stack_by_id(state, battle, target_battle_id));
		message = concat(state, message, gd::format(state, key::dragged_to_suffix_text, { str(label), str(_hex_label(state, to_hex)) }));
		Value stagger;
		if (nonempty_dict_field(state, resolution, key::effect, stagger)) {
			_apply_stack_effect(state, battle, target_battle_id, stagger);
		}
		return true;
	}
	if (resolution_type == key::transfer_effect) {
		// Blood Tithe: health from the second stack into the target, fallen creatures too.
		const Atom donor_id = string_or_empty(state, resolution, key::source_battle_id);
		const int64_t moved = spell_rules::move_stack_health(state, battle, donor_id, target_battle_id, gd::int_field(state, resolution, key::transfer_amount, 0));
		recovered_amount = moved;
		if (moved > 0) {
			message = concat(state, message, gd::format(state, key::gives_health_suffix_text, {
				str(_stack_label(state, _get_stack_by_id(state, battle, donor_id))),
				int_value(moved),
				str(_stack_label(state, _get_stack_by_id(state, battle, target_battle_id))),
			}));
		}
		return true;
	}
	if (resolution_type == key::swap_effect) {
		const Atom other_id = string_or_empty(state, resolution, key::source_battle_id);
		const DictRef from_hex = gd::deep_duplicate_dict(state, _stack_hex(state, _get_stack_by_id(state, battle, target_battle_id)));
		spell_rules::swap_stack_places(state, battle, target_battle_id, other_id);
		const DictRef to_hex = _stack_hex(state, _get_stack_by_id(state, battle, target_battle_id));
		state.set(animation_resolution, str(key::from_q), int_value(gd::int_field(state, from_hex, key::q, -1)));
		state.set(animation_resolution, str(key::from_r), int_value(gd::int_field(state, from_hex, key::r, -1)));
		state.set(animation_resolution, str(key::to_q), int_value(gd::int_field(state, to_hex, key::q, -1)));
		state.set(animation_resolution, str(key::to_r), int_value(gd::int_field(state, to_hex, key::r, -1)));
		message = concat(state, message, gd::format(state, key::trade_places_suffix_text, {
			str(_stack_label(state, _get_stack_by_id(state, battle, target_battle_id))),
			str(_stack_label(state, _get_stack_by_id(state, battle, other_id))),
		}));
		return true;
	}
	// Budding: creatures for this battle only.
	if (resolution_type == key::bud_effect) {
		const int64_t added = spell_rules::bud_stack(state, battle, target_battle_id, gd::int_field(state, resolution, key::amount, 0));
		if (added > 0) {
			message = concat(state, message, gd::format(state, key::buds_creatures_suffix_text, { str(_stack_label(state, _get_stack_by_id(state, battle, target_battle_id))), int_value(added) }));
		}
		return true;
	}
	// Volley Signal: the caster's shooters fire at the target and keep their turns.
	if (resolution_type == key::volley_effect) {
		const Atom shots = spell_rules::fire_volley(state, battle, string_or_empty(state, resolution, key::side), target_battle_id, gd::int_field(state, resolution, key::volley_pct, 0));
		message = concat(state, message, shots);
		const DictRef target_after = _get_stack_by_id(state, battle, target_battle_id);
		if (!gd::is_empty(state, target_after) && _alive_count(state, target_after) <= 0) {
			message = concat(state, message, gd::format(state, key::stack_destroyed_suffix_text, { str(_stack_label(state, target_after)) }));
		}
		return true;
	}
	// Watchful Light keeps watch from the next round.
	if (resolution_type == key::aura_effect) {
		Value entry;
		if (nonempty_dict_field(state, resolution, key::aura_entry, entry)) {
			spell_rules::add_battle_aura(state, battle, gd::deep_duplicate_dict(state, entry.ref));
		}
		return true;
	}
	// Smelter's Bargain: the paying stack loses its share, never its last point.
	if (resolution_type == key::pay_health) {
		const DictRef payer = _get_stack_by_id(state, battle, target_battle_id);
		if (!gd::is_empty(state, payer) && _alive_count(state, payer) > 0) {
			const int64_t health = gd::int_field(state, payer, key::total_health, 0);
			state.set(payer, str(key::total_health), int_value(engine_max<int64_t>(1, gd::sub(health, gd::int_field(state, resolution, key::amount, 0)))));
			_sync_occupied_hexes(state, battle);
		}
		return true;
	}
	// Tier 3: a conjured stack takes the field, a decoy the other side aimed at vanishes, Hour Ledger turns a stack
	// back and Puppet Strings makes a stack attack one of its own side (spell_tier3_conjure.cpp).
	if (resolution_type == key::conjure_effect) {
		// The board's copy of each conjured stack learns the id it took (_mark_spell_animation_states).
		Value conjured;
		if (nonempty_dict_field(state, resolution, key::conjured_stack, conjured)) {
			const Atom id = spell_rules::add_conjured_stack(state, battle, gd::deep_duplicate_dict(state, conjured.ref));
			Value board_copy;
			if (nonempty_dict_field(state, animation_resolution, key::conjured_stack, board_copy)) {
				state.set(board_copy.ref, str(key::battle_id), str(id));
			}
			const DictRef stack = _get_stack_by_id(state, battle, id);
			if (!gd::is_empty(state, stack)) {
				message = concat(state, message, gd::format(state, key::conjured_stands_suffix_text, { str(_stack_label(state, stack)), str(_hex_label(state, _stack_hex(state, stack))) }));
			}
		}
		// Wraith Host's two stacks and Drowned Host's Risen, in turn (spell_tier45_summons.cpp).
		const Value more = gd::field(state, resolution, key::conjured_stacks);
		const Value board_more = gd::field(state, animation_resolution, key::conjured_stacks);
		if (gd::is_array(more)) {
			int64_t index = -1;
			for (const Value &each : gd::items(state, more)) {
				index += 1;
				if (!gd::is_dict(each) || gd::is_empty(state, each.ref)) {
					continue;
				}
				const Atom id = spell_rules::add_conjured_stack(state, battle, gd::deep_duplicate_dict(state, each.ref));
				if (gd::is_array(board_more) && index < state.array_size(board_more.ref) && gd::is_dict(state.at(board_more.ref, index))) {
					state.set(state.at(board_more.ref, index).ref, str(key::battle_id), str(id));
				}
				const DictRef stack = _get_stack_by_id(state, battle, id);
				if (!gd::is_empty(state, stack)) {
					message = concat(state, message, gd::format(state, key::conjured_stands_suffix_text, { str(_stack_label(state, stack)), str(_hex_label(state, _stack_hex(state, stack))) }));
				}
			}
		}
		// Waking Forest's trees.
		const Value trees = gd::field(state, resolution, key::tree_cells);
		if (gd::is_array(trees) && state.array_size(trees.ref) > 0) {
			spell_rules::grow_trees(state, battle, trees.ref);
			const int64_t grown = state.array_size(trees.ref);
			message = concat(state, message, grown == 1 ? static_cast<Atom>(key::tree_grows_suffix_text) : gd::format(state, key::trees_grow_suffix_text, { int_value(grown) }));
		}
		return true;
	}
	if (resolution_type == key::vanish_effect) {
		const Atom gone = spell_rules::vanish_conjured(state, battle, target_battle_id);
		if (gone != key::empty) {
			message = state.intern(state.text(message) + " " + state.text(gone));
		}
		return true;
	}
	if (resolution_type == key::rewind_effect) {
		Value entry;
		if (nonempty_dict_field(state, resolution, key::rewind_entry, entry)) {
			spell_rules::rewind_stack(state, battle, target_battle_id, entry.ref);
			const DictRef stack = _get_stack_by_id(state, battle, target_battle_id);
			message = concat(state, message, gd::format(state, key::turned_back_suffix_text, { str(_stack_label(state, stack)), int_value(gd::int_field(state, entry.ref, key::round, 1)) }));
		}
		return true;
	}
	if (resolution_type == key::charm_effect) {
		message = concat(state, message, spell_rules::charm_attack(state, battle, target_battle_id, string_or_empty(state, resolution, key::source_battle_id), gd::int_field(state, resolution, key::damage_pct, 0)));
		return true;
	}
	// A hex spell lays its ground; the board reads it from then on.
	if (resolution_type == key::ground_effect) {
		Value entry;
		if (nonempty_dict_field(state, resolution, key::ground_entry, entry)) {
			spell_rules::add_ground(state, battle, gd::deep_duplicate_dict(state, entry.ref));
		}
		return true;
	}
	return false;
}

} // namespace aurelion::rules::port::battle_rules
