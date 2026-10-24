// HeroCommandRules for the human seat's heroes (Phase 7, slice 7.5): the hero's
// identity and inspection texts, the switch actions and the army slots.

#include "aurelion_rules/port/overworld_rules_heroes.hpp"

#include "aurelion_rules/port/ai_port.hpp"
#include "aurelion_rules/port/artifact_rules.hpp"
#include "aurelion_rules/port/battle_ends.hpp"
#include "aurelion_rules/port/enemy_states.hpp"
#include "aurelion_rules/port/hero_command_rules.hpp"
#include "aurelion_rules/port/hero_command_rules_ai.hpp"
#include "aurelion_rules/port/hero_command_rules_turn.hpp"
#include "aurelion_rules/port/hero_commit.hpp"
#include "aurelion_rules/port/hero_progression_rules.hpp"
#include "aurelion_rules/port/overworld_rules_context.hpp"
#include "aurelion_rules/port/session_view.hpp"

#include "aurelion_rules/compat/godot_math.hpp"

#include <string>

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

// HeroCommandRules.ARMY_SLOT_COUNT.
constexpr int64_t kArmySlotCount = 7;

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

// String(d.get(field, fallback)).
Atom text_or(State &state, DictRef dict, Atom field, Atom fallback) {
	return string_of(state, state.get(dict, str(field), str(fallback)));
}

// d.get(field, {}) and d.get(field, []) of a value that may be kept: the field,
// or a new container.
Value field_or_new_dict(State &state, DictRef dict, Atom field) {
	Value found;
	return state.lookup(dict, str(field), found) ? found : dict_value(state.new_dict());
}
Value field_or_new_array(State &state, DictRef dict, Atom field) {
	Value found;
	return state.lookup(dict, str(field), found) ? found : array_value(state.new_array());
}

// x.duplicate(true) of a Dictionary value, kept as a Dictionary.
DictRef duplicate_deep(State &state, const Value &value) {
	return gd::as_dict(gd::engine_duplicate(state, value, true));
}

// {"ok": false, "message": message}.
DictRef refusal(State &state, Atom message) {
	const DictRef result = state.new_dict();
	state.set(result, str(key::ok), bool_value(false));
	state.set(result, str(key::message), str(message));
	return result;
}

// clamp(x, lo, hi) of ints, the untyped utility.
int64_t variant_clamp_int(int64_t value, int64_t lo, int64_t hi) {
	const compat::Number clamped = compat::variant_clamp(compat::Number::of_int(value), compat::Number::of_int(lo), compat::Number::of_int(hi));
	return clamped.i;
}

} // namespace

namespace hero_command_rules {

DictRef hero_inspection_snapshot(State &state, DictRef session, Atom hero_id) {
	// Inspection must not normalize/commit the live session. The active mirrors
	// are authoritative until commit_active_hero synchronizes the roster.
	DictRef hero = duplicate_deep(state, dict_value(hero_by_id(state, session, hero_id)));
	if (gd::is_empty(state, hero)) {
		return state.new_dict();
	}
	const DictRef overworld = session_view::overworld(state, session);
	if (hero_id == text_or(state, overworld, key::active_hero_id, key::empty)) {
		hero = duplicate_deep(state, state.get(overworld, str(key::hero), dict_value(hero)));
		const Atom pairs[3][2] = {{key::army, key::army}, {key::movement, key::movement}, {key::position, key::hero_position}};
		for (const auto &pair : pairs) {
			// session.overworld.get(pair[1], hero.get(pair[0], {})).duplicate(true)
			Value found;
			if (!state.lookup(overworld, str(pair[1]), found)) {
				found = field_or_new_dict(state, hero, pair[0]);
			}
			state.set(hero, str(pair[0]), gd::engine_duplicate(state, found, true));
		}
	}
	hero = hero_progression_rules::ensure_hero_progression(state, hero);
	hero = artifact_rules::ensure_hero_artifacts(state, hero);
	state.set(hero, str(key::army), dict_value(_normalize_army(state, field_or_new_dict(state, hero, key::army), hero_id)));
	{
		const Value army = gd::index(state, hero, str(key::army));
		Value stacks;
		if (!state.lookup(gd::as_dict(army), str(key::stacks), stacks)) {
			stacks = array_value(state.new_array());
		}
		state.set(hero, str(key::inspection_army_slots), array_value(_slotted_stacks(state, stacks)));
	}
	{
		const Value army = gd::index(state, hero, str(key::army));
		const Value stacks = field_or_new_array(state, gd::as_dict(army), key::stacks);
		state.set(hero, str(key::inspection_overflow_stacks), array_value(gd::slice(state, gd::as_array(stacks), kArmySlotCount)));
	}
	return hero;
}

DictRef hero_template(State &state, DictRef payload) {
	if (gd::is_empty(state, payload)) {
		return state.new_dict();
	}
	if (state.has(payload, str(key::starting_spell_ids)) && state.has(payload, str(key::faction_id))) {
		return payload;
	}
	return gd::content_row(state, ContentTable::Hero, text_or(state, payload, key::id, key::empty));
}

Atom hero_archetype_label(State &state, DictRef payload) {
	const DictRef template_row = hero_template(state, payload);
	const Value fallback = state.get(payload, str(key::archetype), str(key::field_captain));
	const Atom archetype = string_of(state, state.get(template_row, str(key::archetype), fallback));
	return gd::capitalize(state, archetype);
}

Atom hero_faction_label(State &state, DictRef payload, Atom fallback_faction_id) {
	const DictRef template_row = hero_template(state, payload);
	const Value fallback = state.get(template_row, str(key::faction_id), str(fallback_faction_id));
	const Atom faction_id = string_of(state, state.get(payload, str(key::faction_id), fallback));
	if (faction_id == key::empty) {
		return key::free_banner;
	}
	const DictRef faction = gd::content_row(state, ContentTable::Faction, faction_id);
	return text_or(state, faction, key::name, faction_id);
}

Atom hero_role_label(State &state, DictRef payload) {
	const DictRef template_row = hero_template(state, payload);
	const Value fallback = state.get(payload, str(key::roster_summary), str(key::empty));
	const Atom roster_summary = string_of(state, state.get(template_row, str(key::roster_summary), fallback));
	if (roster_summary != key::empty) {
		return roster_summary;
	}
	return hero_archetype_label(state, payload);
}

Atom hero_identity_context_line(State &state, DictRef payload, Atom fallback_faction_id) {
	const DictRef template_row = hero_template(state, payload);
	const Value fallback = state.get(template_row, str(key::name), str(key::field_commander));
	const Atom name = string_of(state, state.get(payload, str(key::name), fallback));
	const Atom faction_label = hero_faction_label(state, payload, fallback_faction_id);
	const Atom role_label = hero_role_label(state, payload);
	return gd::format(state, key::s_s_s_6, {str(name), str(faction_label), str(role_label)});
}

Atom hero_progress_context_line(State &state, DictRef hero_state) {
	const DictRef hero = hero_progression_rules::ensure_hero_progression(state, duplicate_deep(state, dict_value(hero_state)));
	Atom summary = hero_progression_rules::brief_summary(state, hero);
	if (summary == key::empty) {
		summary = key::no_specialty;
	}
	const int64_t level = gd::int_field(state, hero, key::level, 1);
	const int64_t experience = gd::int_field(state, hero, key::experience, 0);
	const int64_t next_level_experience = gd::int_field(state, hero, key::next_level_experience, 250);
	return gd::format(state, key::lv_d_xp_d_d_s, {int_value(level), int_value(experience), int_value(next_level_experience), str(summary)});
}

Atom hero_readiness_context_line(State &state, DictRef hero_state, bool include_position) {
	std::string joined;
	bool first = true;
	const auto append_part = [&](Atom part) {
		if (!first) {
			joined += state.text(key::space_bar_space);
		}
		joined += state.text(part);
		first = false;
	};
	if (include_position) {
		const DictRef position = _normalize_position(state, field_or_new_dict(state, hero_state, key::position));
		append_part(gd::format(state, key::pos_d_d, {int_value(gd::int_field(state, position, key::x, 0)), int_value(gd::int_field(state, position, key::y, 0))}));
	}
	Value movement;
	if (state.lookup(hero_state, str(key::movement), movement) && gd::is_dict(movement) && !gd::is_empty(state, movement.ref)) {
		append_part(gd::format(state, key::move_d_d_2, {int_value(gd::int_field(state, movement.ref, key::current, 0)), int_value(gd::int_field(state, movement.ref, key::max, 0))}));
	}
	// hero_state.get("spellbook", {}).get("mana", {}): a missing spellbook or
	// mana reads as {}, whose max is 0.
	Value spellbook;
	if (state.lookup(hero_state, str(key::spellbook), spellbook)) {
		const Value mana = ai::vget(state, spellbook, key::mana, Value());
		if (gd::is_dict(mana) && gd::int_field(state, mana.ref, key::max, 0) > 0) {
			append_part(gd::format(state, key::mana_d_d, {int_value(gd::int_field(state, mana.ref, key::current, 0)), int_value(gd::int_field(state, mana.ref, key::max, 0))}));
		}
	}
	const DictRef army_totals = _army_count_summary(state, field_or_new_dict(state, hero_state, key::army));
	const int64_t scouting_radius = scouting_radius_for_hero(state, hero_state);
	const Atom army_text = gd::format(state, key::army_d_d, {int_value(gd::int_field(state, army_totals, key::troops, 0)), int_value(gd::int_field(state, army_totals, key::groups, 0))});
	append_part(gd::format(state, key::scout_d_s, {int_value(scouting_radius), str(army_text)}));
	// hero_state.get("command", {}): a missing command reads as {}.
	Value command;
	const bool has_command = state.lookup(hero_state, str(key::command), command);
	const auto command_stat = [&](Atom stat) {
		return has_command ? gd::to_int(state, ai::vget(state, command, stat, int_value(0))) : int64_t(0);
	};
	const int64_t attack = command_stat(key::attack);
	const int64_t defense = command_stat(key::defense);
	const int64_t power = command_stat(key::power);
	const int64_t knowledge = command_stat(key::knowledge);
	append_part(gd::format(state, key::a_d_d_d_p_d, {int_value(attack), int_value(defense), int_value(power), int_value(knowledge)}));
	return state.intern(joined);
}

ArrayRef get_overworld_switch_actions(State &state, DictRef session) {
	normalize_session(state, session, key::empty, state.new_dict(), state.new_dict());
	const ArrayRef actions = state.new_array();
	const DictRef overworld = session_view::overworld(state, session);
	const Atom active_hero_id = text_or(state, overworld, key::active_hero_id, key::empty);
	for (const Value &hero : gd::field_items(state, overworld, str(key::player_heroes))) {
		if (!gd::is_dict(hero)) {
			continue;
		}
		const Atom hero_id = text_or(state, hero.ref, key::id, key::empty);
		const DictRef action = state.new_dict();
		state.set(action, str(key::id), str(gd::format(state, key::switch_hero_s, {str(hero_id)})));
		state.set(action, str(key::label), str(gd::format(state, key::command_s, {str(text_or(state, hero.ref, key::name, hero_id))})));
		state.set(action, str(key::summary), str(_hero_roster_line(state, hero.ref, active_hero_id)));
		state.set(action, str(key::disabled), bool_value(hero_id == active_hero_id));
		state.append(actions, dict_value(action));
	}
	return actions;
}

DictRef manage_army_slots(State &state, DictRef session, DictRef town, Atom source_holder_id, int64_t source_slot_index, Atom target_holder_id, int64_t target_slot_index, Atom amount_token) {
	normalize_session(state, session, key::empty, state.new_dict(), state.new_dict());
	// session == null: a view is never null.
	if (!_army_slot_holder_is_available(state, session, town, source_holder_id) || !_army_slot_holder_is_available(state, session, town, target_holder_id)) {
		return refusal(state, key::army_management_is_limited_to_the);
	}
	if (gd::is_empty(state, town) && source_holder_id != target_holder_id) {
		const Atom active_hero_id = text_or(state, session_view::overworld(state, session), key::active_hero_id, key::empty);
		if (active_hero_id != source_holder_id && active_hero_id != target_holder_id) {
			return refusal(state, key::field_transfers_must_include_the_active);
		}
	}
	if (source_slot_index < 0 || source_slot_index >= kArmySlotCount || target_slot_index < 0 || target_slot_index >= kArmySlotCount) {
		return refusal(state, key::choose_two_valid_army_slots);
	}
	if (source_holder_id == target_holder_id && source_slot_index == target_slot_index) {
		return refusal(state, key::choose_a_different_destination_slot);
	}
	if (_valid_stack_count(state, array_value(_holder_stacks(state, session, town, source_holder_id))) > kArmySlotCount
			|| _valid_stack_count(state, array_value(_holder_stacks(state, session, town, target_holder_id))) > kArmySlotCount) {
		return refusal(state, key::army_management_is_blocked_because_a);
	}

	const bool same_holder = source_holder_id == target_holder_id;
	ArrayRef source_stacks = _slotted_stacks(state, array_value(_holder_stacks(state, session, town, source_holder_id)));
	ArrayRef target_stacks = same_holder
			? gd::as_array(gd::engine_duplicate(state, array_value(source_stacks), true))
			: _slotted_stacks(state, array_value(_holder_stacks(state, session, town, target_holder_id)));
	const int64_t source_array_index = _stack_index_by_slot(state, source_stacks, source_slot_index);
	if (source_array_index < 0) {
		return refusal(state, key::select_an_occupied_source_slot_first);
	}
	const int64_t target_array_index = _stack_index_by_slot(state, target_stacks, target_slot_index);
	const DictRef source_stack = duplicate_deep(state, state.at(source_stacks, source_array_index));
	const int64_t available = gd::int_field(state, source_stack, key::count, 0);
	const int64_t transfer_count = _resolve_transfer_amount(state, amount_token, available);
	if (transfer_count <= 0) {
		return refusal(state, key::that_split_amount_leaves_no_troops);
	}
	const DictRef target_stack = target_array_index >= 0 ? duplicate_deep(state, state.at(target_stacks, target_array_index)) : state.new_dict();
	// target_stack.is_empty(): it changes only in the branches below.
	const bool target_empty = gd::is_empty(state, target_stack);
	const bool same_unit = !target_empty && text_or(state, target_stack, key::unit_id, key::empty) == text_or(state, source_stack, key::unit_id, key::empty);
	if (!target_empty && !same_unit && transfer_count != available) {
		return refusal(state, key::split_stacks_can_move_only_into);
	}

	if (!same_holder && _transfer_empties_hero_army(state, source_holder_id, array_value(source_stacks), transfer_count, available, target_empty || same_unit)) {
		return refusal(state, _last_stack_message(state, session, town, source_holder_id));
	}

	Atom operation = key::move_;
	if (same_holder) {
		if (target_empty) {
			if (transfer_count == available) {
				state.set(source_stack, str(key::slot_index), int_value(target_slot_index));
				state.set_at(source_stacks, source_array_index, dict_value(source_stack));
			} else {
				state.set(source_stack, str(key::count), int_value(gd::sub(available, transfer_count)));
				state.set_at(source_stacks, source_array_index, dict_value(source_stack));
				const DictRef split_stack = duplicate_deep(state, dict_value(source_stack));
				state.set(split_stack, str(key::count), int_value(transfer_count));
				state.set(split_stack, str(key::slot_index), int_value(target_slot_index));
				state.append(source_stacks, dict_value(split_stack));
				operation = key::split;
			}
		} else if (same_unit) {
			state.set(target_stack, str(key::count), int_value(gd::add(gd::int_field(state, target_stack, key::count, 0), transfer_count)));
			state.set_at(source_stacks, target_array_index, dict_value(target_stack));
			if (transfer_count == available) {
				gd::remove_at(state, source_stacks, source_array_index);
			} else {
				state.set(source_stack, str(key::count), int_value(gd::sub(available, transfer_count)));
				state.set_at(source_stacks, source_array_index, dict_value(source_stack));
			}
			operation = key::merge;
		} else {
			const int64_t source_slot = gd::int_field(state, source_stack, key::slot_index, source_slot_index);
			state.set(source_stack, str(key::slot_index), int_value(target_slot_index));
			state.set(target_stack, str(key::slot_index), int_value(source_slot));
			state.set_at(source_stacks, source_array_index, dict_value(source_stack));
			state.set_at(source_stacks, target_array_index, dict_value(target_stack));
			operation = key::swap;
		}
		target_stacks = source_stacks;
	} else {
		if (target_empty) {
			const DictRef moved_stack = duplicate_deep(state, dict_value(source_stack));
			state.set(moved_stack, str(key::count), int_value(transfer_count));
			state.set(moved_stack, str(key::slot_index), int_value(target_slot_index));
			state.append(target_stacks, dict_value(moved_stack));
			operation = transfer_count == available ? static_cast<Atom>(key::move_) : static_cast<Atom>(key::split);
		} else if (same_unit) {
			state.set(target_stack, str(key::count), int_value(gd::add(gd::int_field(state, target_stack, key::count, 0), transfer_count)));
			state.set_at(target_stacks, target_array_index, dict_value(target_stack));
			operation = key::merge;
		} else {
			const int64_t target_slot = gd::int_field(state, target_stack, key::slot_index, target_slot_index);
			state.set(target_stack, str(key::slot_index), int_value(source_slot_index));
			state.set(source_stack, str(key::slot_index), int_value(target_slot));
			state.set_at(target_stacks, target_array_index, dict_value(source_stack));
			state.set_at(source_stacks, source_array_index, dict_value(target_stack));
			operation = key::swap;
		}
		if (operation != key::swap) {
			if (transfer_count == available) {
				gd::remove_at(state, source_stacks, source_array_index);
			} else {
				state.set(source_stack, str(key::count), int_value(gd::sub(available, transfer_count)));
				state.set_at(source_stacks, source_array_index, dict_value(source_stack));
			}
		}
	}

	source_stacks = _slotted_stacks(state, array_value(source_stacks));
	target_stacks = same_holder ? source_stacks : _slotted_stacks(state, array_value(target_stacks));
	_set_holder_stacks(state, session, town, source_holder_id, source_stacks);
	if (!same_holder) {
		_set_holder_stacks(state, session, town, target_holder_id, target_stacks);
	}
	commit_active_hero(state, session);
	const Atom unit_id = text_or(state, source_stack, key::unit_id, key::empty);
	const Atom unit_name = text_or(state, gd::content_row(state, ContentTable::Unit, unit_id), key::name, unit_id);
	const DictRef result = state.new_dict();
	state.set(result, str(key::ok), bool_value(true));
	state.set(result, str(key::operation), str(operation));
	const Atom operation_label = gd::capitalize(state, operation);
	const Atom source_label = _holder_label(state, session, town, source_holder_id);
	const Atom target_label = _holder_label(state, session, town, target_holder_id);
	state.set(result, str(key::message), str(gd::format(state, key::s_d_s_s_slot_d, {
			str(operation_label), int_value(transfer_count), str(unit_name),
			str(source_label), int_value(gd::add(source_slot_index, 1)),
			str(target_label), int_value(gd::add(target_slot_index, 1)),
	})));
	state.set(result, str(key::source_holder_id), str(source_holder_id));
	state.set(result, str(key::source_slot_index), int_value(source_slot_index));
	state.set(result, str(key::target_holder_id), str(target_holder_id));
	state.set(result, str(key::target_slot_index), int_value(target_slot_index));
	state.set(result, str(key::unit_id), str(unit_id));
	state.set(result, str(key::moved_count), int_value(transfer_count));
	state.set(result, str(key::source), dict_value(army_slot_snapshot(state, session, town, source_holder_id)));
	state.set(result, str(key::target), dict_value(army_slot_snapshot(state, session, town, target_holder_id)));
	return result;
}

Atom _hero_roster_line(State &state, DictRef hero, Atom active_hero_id) {
	std::string tags;
	bool has_tags = false;
	if (gd::bool_field(state, hero, key::is_primary, false)) {
		tags += state.text(key::Primary);
		has_tags = true;
	}
	if (text_or(state, hero, key::id, key::empty) == active_hero_id) {
		if (has_tags) {
			tags += state.text(key::comma_space);
		}
		tags += state.text(key::Active);
		has_tags = true;
	}
	const Atom identity = hero_identity_context_line(state, hero, key::empty);
	const Atom tag_text = has_tags ? state.intern(tags + state.text(key::space_bar_space)) : static_cast<Atom>(key::empty);
	const Atom progress = hero_progress_context_line(state, hero);
	const Atom readiness = hero_readiness_context_line(state, hero, true);
	return gd::format(state, key::s_s_s_s_4, {str(identity), str(tag_text), str(progress), str(readiness)});
}

DictRef _army_count_summary(State &state, const Value &army) {
	int64_t troops = 0;
	int64_t groups = 0;
	// army.get("stacks", []) if army is Dictionary else []: [] has no stacks.
	Value stacks;
	if (gd::is_dict(army) && state.lookup(army.ref, str(key::stacks), stacks) && gd::is_array(stacks)) {
		for (const Value &stack : gd::items(state, stacks)) {
			if (!gd::is_dict(stack)) {
				continue;
			}
			const int64_t count = gd::int_field(state, stack.ref, key::count, 0);
			if (count <= 0) {
				continue;
			}
			troops = gd::add(troops, count);
			groups = gd::add(groups, 1);
		}
	}
	const DictRef summary = state.new_dict();
	state.set(summary, str(key::troops), int_value(troops));
	state.set(summary, str(key::groups), int_value(groups));
	return summary;
}

DictRef _preserve_movement_deficit_after_artifact_change(State &state, DictRef hero, int64_t previous_max, DictRef session) {
	const DictRef updated = duplicate_deep(state, dict_value(hero));
	// var movement: Dictionary = updated.get("movement", {}) if updated.get("movement", {}) is Dictionary else {}
	Value movement_value;
	const DictRef movement = state.lookup(updated, str(key::movement), movement_value) && gd::is_dict(movement_value)
			? movement_value.ref
			: state.new_dict();
	const int64_t new_max = movement_max_for_hero(state, updated, dict_value(session));
	const int64_t current = gd::int_field(state, movement, key::current, previous_max);
	state.set(movement, str(key::current), int_value(variant_clamp_int(gd::add(current, gd::sub(new_max, previous_max)), 0, new_max)));
	state.set(movement, str(key::max), int_value(new_max));
	state.set(updated, str(key::movement), dict_value(movement));
	return updated;
}

bool _transfer_empties_hero_army(State &state, Atom holder_id, const Value &stacks, int64_t transfer_count, int64_t available, bool stack_leaves) {
	// A commander may not hand away its last troops and walk the map empty.
	// The garrison may be emptied; a swap never leaves the source empty.
	if (holder_id == key::garrison || !stack_leaves || transfer_count < available) {
		return false;
	}
	return _valid_stack_count(state, stacks) <= 1;
}

Atom _last_stack_message(State &state, DictRef session, DictRef town, Atom holder_id) {
	return gd::format(state, key::s_must_keep_at_least_one, {str(_holder_label(state, session, town, holder_id))});
}

int64_t _stack_index_by_unit(State &state, ArrayRef stacks, Atom unit_id) {
	const int64_t size = state.array_size(stacks);
	for (int64_t index = 0; index < size; ++index) {
		const Value stack = state.at(stacks, index);
		if (gd::is_dict(stack) && text_or(state, stack.ref, key::unit_id, key::empty) == unit_id) {
			return index;
		}
	}
	return -1;
}

int64_t _stack_index_by_slot(State &state, ArrayRef stacks, int64_t slot_index) {
	const int64_t size = state.array_size(stacks);
	for (int64_t index = 0; index < size; ++index) {
		const Value stack = state.at(stacks, index);
		if (gd::is_dict(stack) && gd::int_field(state, stack.ref, key::slot_index, -1) == slot_index) {
			return index;
		}
	}
	return -1;
}

int64_t _resolve_transfer_amount(State &state, Atom amount_token, int64_t available) {
	if (available <= 0) {
		return 0;
	}
	if (amount_token == key::all) {
		return available;
	}
	if (amount_token == key::half) {
		// max(1, int(floor(float(available) / 2.0)))
		return compat::engine_max<int64_t>(1, compat::float_to_int(compat::godot_floor(static_cast<double>(available) / 2.0)));
	}
	return variant_clamp_int(gd::to_int(state, str(amount_token)), 0, available);
}

} // namespace hero_command_rules

} // namespace aurelion::rules::port
