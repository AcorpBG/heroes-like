// HeroCommandRules for the human seat's field exchange (Phase 7, slice 7.5):
// troops, artifacts and spells between two heroes on the map.

#include "aurelion_rules/port/overworld_rules_heroes.hpp"

#include "aurelion_rules/port/ai_port.hpp"
#include "aurelion_rules/port/artifact_rules.hpp"
#include "aurelion_rules/port/artifact_rules_turn.hpp"
#include "aurelion_rules/port/battle_ends.hpp"
#include "aurelion_rules/port/hero_command_rules.hpp"
#include "aurelion_rules/port/hero_command_rules_ai.hpp"
#include "aurelion_rules/port/hero_command_rules_turn.hpp"
#include "aurelion_rules/port/hero_commit.hpp"
#include "aurelion_rules/port/hero_progression_rules.hpp"
#include "aurelion_rules/port/session_view.hpp"
#include "aurelion_rules/port/spell_rules.hpp"
#include "aurelion_rules/port/spell_rules_ai.hpp"

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

// d.get(field, {}) of a value that may be stored: the field, or a new {}.
Value field_or_new_dict(State &state, DictRef dict, Atom field) {
	Value found;
	if (state.lookup(dict, str(field), found)) {
		return found;
	}
	return dict_value(state.new_dict());
}

// d.get(field, []) of a value that may be stored: the field, or a new [].
Value field_or_new_array(State &state, DictRef dict, Atom field) {
	Value found;
	if (state.lookup(dict, str(field), found)) {
		return found;
	}
	return array_value(state.new_array());
}

// {"ok": false, "message": message}.
DictRef refusal(State &state, Atom message) {
	const DictRef result = state.new_dict();
	state.set(result, str(key::ok), bool_value(false));
	state.set(result, str(key::message), str(message));
	return result;
}

// a + b of Strings.
Atom concat(State &state, Atom a, Atom b) {
	return state.intern(state.text(a) + state.text(b));
}

// slot in ArtifactRules.EQUIPMENT_SLOTS.
bool is_equipment_slot(Atom slot) {
	return slot == key::boots || slot == key::banner || slot == key::armor || slot == key::trinket || slot == key::trinket_2;
}

// session.overworld.get("player_heroes", []) if it is an Array, else [].
ArrayRef player_heroes_or_new(State &state, DictRef session) {
	Value heroes;
	if (state.lookup(session_view::overworld(state, session), str(key::player_heroes), heroes) && gd::is_array(heroes)) {
		return heroes.ref;
	}
	return state.new_array();
}

// The checks transfer_field_stack, transfer_field_artifact and teach_field_spell
// open with: the refusal's message (each has its own for the active
// commander), or "" with both heroes found.
Atom field_pair_refusal(State &state, DictRef session, Atom source_hero_id, Atom target_hero_id, Atom active_message, DictRef &source, DictRef &target) {
	if (source_hero_id == key::empty || target_hero_id == key::empty || source_hero_id == target_hero_id) {
		return key::choose_two_different_controlled_commanders;
	}
	source = hero_command_rules::hero_by_id(state, session, source_hero_id);
	target = hero_command_rules::hero_by_id(state, session, target_hero_id);
	if (gd::is_empty(state, source) || gd::is_empty(state, target)) {
		return key::both_commanders_must_remain_under_player;
	}
	const Atom active_id = text_or(state, session_view::overworld(state, session), key::active_hero_id, key::empty);
	if (source_hero_id != active_id && target_hero_id != active_id) {
		return active_message;
	}
	const DictRef source_position = hero_command_rules::_normalize_position(state, field_or_new_dict(state, source, key::position));
	const DictRef target_position = hero_command_rules::_normalize_position(state, field_or_new_dict(state, target, key::position));
	if (!gd::equal(state, dict_value(source_position), dict_value(target_position))) {
		return key::the_commanders_must_occupy_the_same;
	}
	return key::empty;
}

// (plan.get("remaining", []) as Array).is_empty().
bool remaining_is_empty(State &state, DictRef plan) {
	Value remaining;
	if (!state.lookup(plan, str(key::remaining), remaining)) {
		return true;
	}
	return state.array_size(gd::as_array(remaining)) == 0;
}

} // namespace

namespace hero_command_rules {

DictRef transfer_field_stack(State &state, DictRef session, Atom source_hero_id, Atom target_hero_id, Atom unit_id, Atom amount_token) {
	normalize_session(state, session, key::empty, state.new_dict(), state.new_dict());
	// session == null: a view is never null.
	DictRef source = 0;
	DictRef target = 0;
	const Atom refused = field_pair_refusal(state, session, source_hero_id, target_hero_id, key::field_transfers_must_include_the_active, source, target);
	if (refused != key::empty) {
		return refusal(state, refused);
	}
	if (unit_id == key::empty) {
		return refusal(state, key::that_transfer_order_is_missing_a);
	}

	const ArrayRef source_stacks = _holder_stacks(state, session, state.new_dict(), source_hero_id);
	const int64_t source_index = _stack_index_by_unit(state, source_stacks, unit_id);
	if (source_index < 0) {
		return refusal(state, key::that_stack_is_no_longer_available);
	}
	const DictRef source_stack = gd::as_dict(state.at(source_stacks, source_index));
	const int64_t available = gd::int_field(state, source_stack, key::count, 0);
	const int64_t transfer_count = _resolve_transfer_amount(state, amount_token, available);
	if (transfer_count <= 0) {
		return refusal(state, key::no_troops_are_available_for_transfer);
	}
	if (_transfer_empties_hero_army(state, source_hero_id, array_value(source_stacks), transfer_count, available)) {
		return refusal(state, _last_stack_message(state, session, state.new_dict(), source_hero_id));
	}

	const ArrayRef target_holder_stacks = _holder_stacks(state, session, state.new_dict(), target_hero_id);
	const DictRef additions = state.new_dict();
	state.set(additions, str(unit_id), int_value(transfer_count));
	const DictRef admission = army_addition_plan(state, array_value(target_holder_stacks), additions);
	if (!gd::bool_field(state, admission, key::ok, false)) {
		return admission;
	}
	state.set(source_stack, str(key::count), int_value(gd::sub(available, transfer_count)));
	if (gd::int_field(state, source_stack, key::count, 0) > 0) {
		state.set_at(source_stacks, source_index, dict_value(source_stack));
	} else {
		gd::remove_at(state, source_stacks, source_index);
	}
	const ArrayRef target_stacks = gd::as_array(field_or_new_array(state, admission, key::stacks));

	_set_holder_stacks(state, session, state.new_dict(), source_hero_id, source_stacks);
	_set_holder_stacks(state, session, state.new_dict(), target_hero_id, target_stacks);
	const Atom unit_name = text_or(state, gd::content_row(state, ContentTable::Unit, unit_id), key::name, unit_id);
	const DictRef result = state.new_dict();
	state.set(result, str(key::ok), bool_value(true));
	state.set(result, str(key::message), str(gd::format(state, key::moved_d_s_from_s_to, {
			int_value(transfer_count),
			str(unit_name),
			str(text_or(state, source, key::name, source_hero_id)),
			str(text_or(state, target, key::name, target_hero_id)),
	})));
	state.set(result, str(key::source_hero_id), str(source_hero_id));
	state.set(result, str(key::target_hero_id), str(target_hero_id));
	state.set(result, str(key::unit_id), str(unit_id));
	state.set(result, str(key::transferred_count), int_value(transfer_count));
	return result;
}

DictRef transfer_field_artifact(State &state, DictRef session, Atom source_hero_id, Atom target_hero_id, Atom artifact_id) {
	normalize_session(state, session, key::empty, state.new_dict(), state.new_dict());
	// session == null: a view is never null.
	DictRef source = 0;
	DictRef target = 0;
	const Atom refused = field_pair_refusal(state, session, source_hero_id, target_hero_id, key::field_handoffs_must_include_the_active, source, target);
	if (refused != key::empty) {
		return refusal(state, refused);
	}
	if (artifact_id == key::empty || gd::is_empty(state, gd::content_row(state, ContentTable::Artifact, artifact_id))) {
		return refusal(state, key::that_artifact_handoff_is_invalid);
	}
	if (!artifact_rules::has_artifact(state, source, artifact_id)) {
		return refusal(state, gd::format(state, key::that_artifact_is_no_longer_owned_2, {str(text_or(state, source, key::name, source_hero_id))}));
	}
	if (artifact_rules::has_artifact(state, target, artifact_id)) {
		return refusal(state, gd::format(state, key::s_already_owns_s, {
				str(text_or(state, target, key::name, target_hero_id)),
				str(artifact_rules::artifact_name(state, artifact_id)),
		}));
	}

	const int64_t source_previous_max = movement_max_for_hero(state, source, dict_value(session));
	const int64_t target_previous_max = movement_max_for_hero(state, target, dict_value(session));
	const DictRef removal = artifact_rules::remove_owned_artifact(state, source, artifact_id);
	if (!gd::bool_field(state, removal, key::ok, false)) {
		return refusal(state, text_or(state, removal, key::message, key::artifact_handoff_failed));
	}
	const DictRef claim = artifact_rules::claim_artifact(state, target, artifact_id, key::Received, true);
	if (!gd::bool_field(state, claim, key::ok, false) || gd::bool_field(state, claim, key::duplicate, false)) {
		return refusal(state, text_or(state, claim, key::message, key::artifact_handoff_failed));
	}
	DictRef source_updated = gd::as_dict(state.get(removal, str(key::hero), dict_value(source)));
	DictRef target_updated = gd::as_dict(state.get(claim, str(key::hero), dict_value(target)));
	source_updated = _preserve_movement_deficit_after_artifact_change(state, source_updated, source_previous_max, session);
	target_updated = _preserve_movement_deficit_after_artifact_change(state, target_updated, target_previous_max, session);
	const ArrayRef heroes = player_heroes_or_new(state, session);
	_replace_hero_in_array(state, heroes, source_updated);
	_replace_hero_in_array(state, heroes, target_updated);
	state.set(session_view::overworld(state, session), str(key::player_heroes), array_value(heroes));
	_sync_active_hero_mirror(state, session);
	const DictRef target_location = artifact_rules::locate_artifact(state, target_updated, artifact_id);
	const DictRef result = state.new_dict();
	state.set(result, str(key::ok), bool_value(true));
	state.set(result, str(key::message), str(gd::format(state, key::passed_s_from_s_to_s, {
			str(artifact_rules::artifact_name(state, artifact_id)),
			str(text_or(state, source, key::name, source_hero_id)),
			str(text_or(state, target, key::name, target_hero_id)),
			str(artifact_rules::artifact_collection_state(state, target_updated, artifact_id, false, key::empty)),
	})));
	state.set(result, str(key::source_hero_id), str(source_hero_id));
	state.set(result, str(key::target_hero_id), str(target_hero_id));
	state.set(result, str(key::artifact_id), str(artifact_id));
	state.set(result, str(key::source_previous_location), str(text_or(state, removal, key::previous_location, key::empty)));
	state.set(result, str(key::source_previous_slot), str(text_or(state, removal, key::previous_slot, key::empty)));
	state.set(result, str(key::target_location), str(text_or(state, target_location, key::location, key::empty)));
	state.set(result, str(key::target_slot), str(text_or(state, target_location, key::slot, key::empty)));
	state.set(result, str(key::auto_equipped), bool_value(gd::bool_field(state, claim, key::auto_equipped, false)));
	return result;
}

DictRef teach_field_spell(State &state, DictRef session, Atom source_hero_id, Atom target_hero_id, Atom spell_id) {
	normalize_session(state, session, key::empty, state.new_dict(), state.new_dict());
	// session == null: a view is never null.
	DictRef source = 0;
	DictRef target = 0;
	const Atom refused = field_pair_refusal(state, session, source_hero_id, target_hero_id, key::field_teaching_must_include_the_active, source, target);
	if (refused != key::empty) {
		return refusal(state, refused);
	}
	const DictRef spell = gd::content_row(state, ContentTable::Spell, spell_id);
	if (spell_id == key::empty || gd::is_empty(state, spell)) {
		return refusal(state, key::that_spell_teaching_order_is_invalid);
	}
	if (!spell_rules::knows_spell(state, source, spell_id)) {
		return refusal(state, gd::format(state, key::s_no_longer_knows_s, {
				str(text_or(state, source, key::name, source_hero_id)),
				str(text_or(state, spell, key::name, spell_id)),
		}));
	}
	if (spell_rules::knows_spell(state, target, spell_id)) {
		return refusal(state, gd::format(state, key::s_already_knows_s, {
				str(text_or(state, target, key::name, target_hero_id)),
				str(text_or(state, spell, key::name, spell_id)),
		}));
	}

	const DictRef learning = spell_rules::learn_spell(state, target, spell_id);
	if (!gd::bool_field(state, learning, key::ok, false)) {
		return refusal(state, text_or(state, learning, key::message, key::spell_teaching_failed));
	}
	const DictRef target_updated = gd::as_dict(state.get(learning, str(key::hero), dict_value(target)));
	const ArrayRef heroes = player_heroes_or_new(state, session);
	_replace_hero_in_array(state, heroes, target_updated);
	state.set(session_view::overworld(state, session), str(key::player_heroes), array_value(heroes));
	_sync_active_hero_mirror(state, session);
	const DictRef result = state.new_dict();
	state.set(result, str(key::ok), bool_value(true));
	state.set(result, str(key::message), str(gd::format(state, key::s_teaches_s_to_s, {
			str(text_or(state, source, key::name, source_hero_id)),
			str(text_or(state, spell, key::name, spell_id)),
			str(text_or(state, target, key::name, target_hero_id)),
	})));
	state.set(result, str(key::source_hero_id), str(source_hero_id));
	state.set(result, str(key::target_hero_id), str(target_hero_id));
	state.set(result, str(key::spell_id), str(spell_id));
	return result;
}

Atom field_slot_action_id(State &state, Atom source_hero_id, int64_t source_slot_index, Atom target_hero_id, int64_t target_slot_index, Atom amount_token) {
	return gd::format(state, key::field_slot_s_d_s_d, {
			str(source_hero_id),
			int_value(source_slot_index),
			str(target_hero_id),
			int_value(target_slot_index),
			str(amount_token),
	});
}

Atom field_troops_all_action_id(State &state, Atom source_hero_id, Atom target_hero_id) {
	return gd::format(state, key::field_troops_all_s_s, {str(source_hero_id), str(target_hero_id)});
}

Atom field_artifact_place_action_id(State &state, Atom source_hero_id, Atom target_hero_id, Atom artifact_id, Atom target_slot) {
	return gd::format(state, key::field_artifact_place_s_s_s, {str(source_hero_id), str(target_hero_id), str(artifact_id), str(target_slot)});
}

Atom field_artifacts_all_action_id(State &state, Atom source_hero_id, Atom target_hero_id) {
	return gd::format(state, key::field_artifacts_all_s_s, {str(source_hero_id), str(target_hero_id)});
}

Atom field_spell_share_action_id(State &state, Atom source_hero_id, Atom target_hero_id, Atom spell_id) {
	return gd::format(state, key::field_spell_share_s_s_s, {str(source_hero_id), str(target_hero_id), str(spell_id)});
}

DictRef field_exchange_state(State &state, DictRef session, Atom partner_hero_id) {
	// The active commander faces one partner on its tile (the first one when
	// the requested partner is not there). Empty when nobody shares the tile.
	const ArrayRef partners = state.new_array();
	const ArrayRef partner_ids = state.new_array();
	const ArrayRef rendezvous = field_rendezvous_heroes(state, session);
	for (const Value &hero_value : gd::items(state, array_value(rendezvous))) {
		if (!gd::is_dict(hero_value)) {
			continue;
		}
		const Atom hero_id = text_or(state, hero_value.ref, key::id, key::empty);
		state.append(partner_ids, str(hero_id));
		const DictRef partner = state.new_dict();
		state.set(partner, str(key::hero_id), str(hero_id));
		state.set(partner, str(key::name), str(text_or(state, hero_value.ref, key::name, hero_id)));
		state.set(partner, str(key::portrait), str(text_or(state, gd::content_row(state, ContentTable::HeroArt, hero_id), key::portrait, key::empty)));
		state.append(partners, dict_value(partner));
	}
	if (state.array_size(partner_ids) == 0) {
		return state.new_dict();
	}
	const Atom partner_id = gd::array_has(state, partner_ids, str(partner_hero_id))
			? partner_hero_id
			: string_of(state, state.at(partner_ids, 0));
	const DictRef left = field_exchange_snapshot(state, session, text_or(state, session_view::overworld(state, session), key::active_hero_id, key::empty));
	const DictRef right = field_exchange_snapshot(state, session, partner_id);
	if (gd::is_empty(state, left) || gd::is_empty(state, right)) {
		return state.new_dict();
	}
	const DictRef exchange = state.new_dict();
	state.set(exchange, str(key::left), dict_value(left));
	state.set(exchange, str(key::right), dict_value(right));
	state.set(exchange, str(key::partners), array_value(partners));
	state.set(exchange, str(key::partner_id), str(partner_id));
	return exchange;
}

DictRef field_exchange_snapshot(State &state, DictRef session, Atom hero_id) {
	// Read model for one side of the hero meeting screen: identity, primary
	// stats, the seven army slots, worn and carried artifacts, known spells.
	const DictRef army = army_slot_snapshot(state, session, state.new_dict(), hero_id);
	if (gd::is_empty(state, army)) {
		return state.new_dict();
	}
	const DictRef hero = hero_inspection_snapshot(state, session, hero_id);
	if (gd::is_empty(state, hero)) {
		return state.new_dict();
	}
	const DictRef artifact_bonuses = artifact_rules::aggregate_bonuses(state, gd::as_dict(gd::engine_duplicate(state, dict_value(hero), true)));
	const DictRef specialty_bonuses = hero_progression_rules::aggregate_bonuses(state, hero);
	const ArrayRef stats = state.new_array();
	for (const Atom stat : {key::attack, key::defense, key::power, key::knowledge}) {
		// int(hero.get("command", {}).get(stat, 0)): a missing command reads 0.
		Value command;
		const int64_t base = state.lookup(hero, str(key::command), command) ? gd::to_int(state, ai::vget(state, command, stat, int_value(0))) : 0;
		int64_t bonus = 0;
		if (stat == key::attack || stat == key::defense) {
			const Atom bonus_key = stat == key::attack ? static_cast<Atom>(key::battle_attack) : static_cast<Atom>(key::battle_defense);
			bonus = gd::add(gd::int_field(state, artifact_bonuses, bonus_key, 0), gd::int_field(state, specialty_bonuses, bonus_key, 0));
		}
		const DictRef entry = state.new_dict();
		state.set(entry, str(key::id), str(stat));
		state.set(entry, str(key::label), str(gd::capitalize(state, stat)));
		state.set(entry, str(key::base), int_value(base));
		state.set(entry, str(key::bonus), int_value(bonus));
		state.set(entry, str(key::value), int_value(gd::add(base, bonus)));
		state.append(stats, dict_value(entry));
	}
	// normalize_hero_artifacts({}) is normalize_hero_artifacts(null).
	const DictRef artifacts = artifact_rules::normalize_hero_artifacts(state, gd::field(state, hero, key::artifacts));
	const ArrayRef spell_ids = state.new_array();
	const ArrayRef known = spell_rules::known_spells(state, hero, key::empty);
	for (const Value &spell_value : gd::items(state, array_value(known))) {
		if (gd::is_dict(spell_value) && text_or(state, spell_value.ref, key::id, key::empty) != key::empty) {
			state.append(spell_ids, str(text_or(state, spell_value.ref, key::id, key::empty)));
		}
	}
	// var mana: Dictionary = hero.get("spellbook", {}).get("mana", {}), {} unless a
	// Dictionary; read only, so a missing one reads as empty.
	Value spellbook;
	const Value mana = state.lookup(hero, str(key::spellbook), spellbook) ? ai::vget(state, spellbook, key::mana) : Value();
	const bool has_mana = gd::is_dict(mana);
	Value movement;
	const bool has_movement = state.lookup(hero, str(key::movement), movement) && gd::is_dict(movement);

	const DictRef snapshot = state.new_dict();
	state.set(snapshot, str(key::hero_id), str(hero_id));
	state.set(snapshot, str(key::name), str(text_or(state, hero, key::name, hero_id)));
	state.set(snapshot, str(key::level), int_value(gd::int_field(state, hero, key::level, 1)));
	state.set(snapshot, str(key::archetype), str(hero_archetype_label(state, hero)));
	state.set(snapshot, str(key::portrait), str(text_or(state, gd::content_row(state, ContentTable::HeroArt, hero_id), key::portrait, key::empty)));
	state.set(snapshot, str(key::active), bool_value(hero_id == text_or(state, session_view::overworld(state, session), key::active_hero_id, key::empty)));
	state.set(snapshot, str(key::stats), array_value(stats));
	const DictRef mana_entry = state.new_dict();
	state.set(mana_entry, str(key::current), int_value(has_mana ? gd::int_field(state, mana.ref, key::current, 0) : 0));
	state.set(mana_entry, str(key::max), int_value(has_mana ? gd::int_field(state, mana.ref, key::max, 0) : 0));
	state.set(snapshot, str(key::mana), dict_value(mana_entry));
	const DictRef movement_entry = state.new_dict();
	state.set(movement_entry, str(key::current), int_value(has_movement ? gd::int_field(state, movement.ref, key::current, 0) : 0));
	state.set(movement_entry, str(key::max), int_value(has_movement ? gd::int_field(state, movement.ref, key::max, 0) : 0));
	state.set(snapshot, str(key::movement), dict_value(movement_entry));
	state.set(snapshot, str(key::army), dict_value(army));
	state.set(snapshot, str(key::equipped), field_or_new_dict(state, artifacts, key::equipped));
	state.set(snapshot, str(key::inventory), field_or_new_array(state, artifacts, key::inventory));
	state.set(snapshot, str(key::spell_ids), array_value(spell_ids));
	return snapshot;
}

DictRef move_all_field_troops(State &state, DictRef session, Atom source_hero_id, Atom target_hero_id) {
	// HoMM-style "move all": every stack that fits merges into a matching
	// target stack or takes a free slot (its own index when open). When that
	// would empty the source, its lowest-tier stack leaves one creature behind.
	normalize_session(state, session, key::empty, state.new_dict(), state.new_dict());
	const Atom pair_error = _field_exchange_pair_error(state, session, source_hero_id, target_hero_id);
	if (pair_error != key::empty) {
		return refusal(state, pair_error);
	}
	const ArrayRef source_raw = _holder_stacks(state, session, state.new_dict(), source_hero_id);
	const ArrayRef target_raw = _holder_stacks(state, session, state.new_dict(), target_hero_id);
	if (_valid_stack_count(state, array_value(source_raw)) > kArmySlotCount || _valid_stack_count(state, array_value(target_raw)) > kArmySlotCount) {
		return refusal(state, key::army_management_is_blocked_because_a);
	}
	const ArrayRef source_stacks = _slotted_stacks(state, array_value(source_raw));
	const ArrayRef target_stacks = _slotted_stacks(state, array_value(target_raw));
	const Atom source_name = _holder_label(state, session, state.new_dict(), source_hero_id);
	const Atom target_name = _holder_label(state, session, state.new_dict(), target_hero_id);
	if (state.array_size(source_stacks) == 0) {
		return refusal(state, gd::format(state, key::s_has_no_troops_to_hand, {str(source_name)}));
	}
	int64_t keeper_index = -1;
	DictRef plan = _plan_move_all_troops(state, source_stacks, target_stacks, keeper_index);
	if (remaining_is_empty(state, plan)) {
		keeper_index = _move_all_keeper_index(state, source_stacks);
		plan = _plan_move_all_troops(state, source_stacks, target_stacks, keeper_index);
	}
	const int64_t moved_count = gd::int_field(state, plan, key::moved_count, 0);
	if (moved_count <= 0) {
		if (keeper_index >= 0) {
			return refusal(state, _last_stack_message(state, session, state.new_dict(), source_hero_id));
		}
		return refusal(state, gd::format(state, key::s_has_no_free_army_slot, {str(target_name)}));
	}
	_set_holder_stacks(state, session, state.new_dict(), source_hero_id, _slotted_stacks(state, field_or_new_array(state, plan, key::remaining)));
	_set_holder_stacks(state, session, state.new_dict(), target_hero_id, _slotted_stacks(state, field_or_new_array(state, plan, key::target)));
	commit_active_hero(state, session);
	Atom message = gd::format(state, key::moved_d_troops_from_s_to, {int_value(moved_count), str(source_name), str(target_name)});
	Atom kept_unit_id = key::empty;
	if (keeper_index >= 0) {
		kept_unit_id = string_of(state, ai::vget(state, state.at(source_stacks, keeper_index), key::unit_id, str(key::empty)));
		const Atom kept_name = text_or(state, gd::content_row(state, ContentTable::Unit, kept_unit_id), key::name, kept_unit_id);
		message = concat(state, message, gd::format(state, key::s_keeps_one_s, {str(source_name), str(kept_name)}));
	} else if (!remaining_is_empty(state, plan)) {
		message = concat(state, message, gd::format(state, key::s_has_no_free_slot_for, {str(target_name)}));
	}
	const DictRef result = state.new_dict();
	state.set(result, str(key::ok), bool_value(true));
	state.set(result, str(key::message), str(message));
	state.set(result, str(key::source_hero_id), str(source_hero_id));
	state.set(result, str(key::target_hero_id), str(target_hero_id));
	state.set(result, str(key::moved_count), int_value(moved_count));
	state.set(result, str(key::kept_unit_id), str(kept_unit_id));
	return result;
}

DictRef place_field_artifact(State &state, DictRef session, Atom source_hero_id, Atom target_hero_id, Atom artifact_id, Atom target_slot) {
	// Slot-precise artifact orders for the meeting screen. An empty target slot
	// keeps the classic handoff (matching empty slot, otherwise backpack);
	// FIELD_ARTIFACT_PACK_SLOT stows it; an equipment slot must accept it and
	// pushes any artifact already worn there into that commander's backpack.
	normalize_session(state, session, key::empty, state.new_dict(), state.new_dict());
	// session == null: a view is never null.
	if (target_slot != key::empty && target_slot != key::pack && !is_equipment_slot(target_slot)) {
		return refusal(state, key::that_artifact_slot_does_not_exist);
	}
	if (artifact_id == key::empty || gd::is_empty(state, gd::content_row(state, ContentTable::Artifact, artifact_id))) {
		return refusal(state, key::that_artifact_handoff_is_invalid);
	}
	if (target_slot != key::empty && target_slot != key::pack && !artifact_rules::equipment_slot_accepts(state, target_slot, artifact_id)) {
		const Atom fits = artifact_rules::artifact_slot(state, artifact_id);
		const Atom name = artifact_rules::artifact_name(state, artifact_id);
		const Atom where = fits == key::empty
				? static_cast<Atom>(key::is_carried_in_the_backpack_not)
				: gd::format(state, key::is_worn_in_the_s_slot, {str(fits)});
		return refusal(state, gd::format(state, key::s_s_2, {str(name), str(where)}));
	}
	if (source_hero_id == target_hero_id) {
		return _rearrange_field_artifact(state, session, source_hero_id, artifact_id, target_slot);
	}
	if (target_slot == key::empty) {
		return transfer_field_artifact(state, session, source_hero_id, target_hero_id, artifact_id);
	}
	const Atom pair_error = _field_exchange_pair_error(state, session, source_hero_id, target_hero_id);
	if (pair_error != key::empty) {
		return refusal(state, pair_error);
	}
	const DictRef source = hero_by_id(state, session, source_hero_id);
	const DictRef target = hero_by_id(state, session, target_hero_id);
	if (!artifact_rules::has_artifact(state, source, artifact_id)) {
		return refusal(state, gd::format(state, key::that_artifact_is_no_longer_owned_2, {str(text_or(state, source, key::name, source_hero_id))}));
	}
	if (artifact_rules::has_artifact(state, target, artifact_id)) {
		return refusal(state, gd::format(state, key::s_already_owns_s, {
				str(text_or(state, target, key::name, target_hero_id)),
				str(artifact_rules::artifact_name(state, artifact_id)),
		}));
	}
	const int64_t source_previous_max = movement_max_for_hero(state, source, dict_value(session));
	const int64_t target_previous_max = movement_max_for_hero(state, target, dict_value(session));
	const DictRef removal = artifact_rules::remove_owned_artifact(state, source, artifact_id);
	if (!gd::bool_field(state, removal, key::ok, false)) {
		return refusal(state, text_or(state, removal, key::message, key::artifact_handoff_failed));
	}
	const DictRef claim = artifact_rules::claim_artifact(state, target, artifact_id, key::Received, false);
	if (!gd::bool_field(state, claim, key::ok, false) || gd::bool_field(state, claim, key::duplicate, false)) {
		return refusal(state, text_or(state, claim, key::message, key::artifact_handoff_failed));
	}
	DictRef target_updated = gd::as_dict(state.get(claim, str(key::hero), dict_value(target)));
	Atom displaced_id = key::empty;
	if (target_slot != key::pack) {
		const DictRef equip = artifact_rules::equip_artifact_in_slot(state, target_updated, artifact_id, target_slot);
		if (!gd::bool_field(state, equip, key::ok, false)) {
			return refusal(state, text_or(state, equip, key::message, key::artifact_handoff_failed));
		}
		target_updated = gd::as_dict(state.get(equip, str(key::hero), dict_value(target_updated)));
		displaced_id = text_or(state, equip, key::swapped_out_artifact_id, key::empty);
	}
	const DictRef removed_hero = gd::as_dict(state.get(removal, str(key::hero), dict_value(source)));
	const DictRef source_updated = _preserve_movement_deficit_after_artifact_change(state, removed_hero, source_previous_max, session);
	target_updated = _preserve_movement_deficit_after_artifact_change(state, target_updated, target_previous_max, session);
	const ArrayRef updated_heroes = state.new_array();
	state.append(updated_heroes, dict_value(source_updated));
	state.append(updated_heroes, dict_value(target_updated));
	_store_field_heroes(state, session, updated_heroes);
	const DictRef target_location = artifact_rules::locate_artifact(state, target_updated, artifact_id);
	Atom message = gd::format(state, key::passed_s_from_s_to_s_2, {
			str(artifact_rules::artifact_name(state, artifact_id)),
			str(text_or(state, source, key::name, source_hero_id)),
			str(text_or(state, target, key::name, target_hero_id)),
			str(target_slot == key::pack ? static_cast<Atom>(key::s_backpack) : static_cast<Atom>(key::empty)),
	});
	if (displaced_id != key::empty) {
		message = concat(state, message, gd::format(state, key::s_goes_to_the_backpack, {str(artifact_rules::artifact_name(state, displaced_id))}));
	}
	const DictRef result = state.new_dict();
	state.set(result, str(key::ok), bool_value(true));
	state.set(result, str(key::message), str(message));
	state.set(result, str(key::source_hero_id), str(source_hero_id));
	state.set(result, str(key::target_hero_id), str(target_hero_id));
	state.set(result, str(key::artifact_id), str(artifact_id));
	state.set(result, str(key::source_previous_location), str(text_or(state, removal, key::previous_location, key::empty)));
	state.set(result, str(key::source_previous_slot), str(text_or(state, removal, key::previous_slot, key::empty)));
	state.set(result, str(key::target_location), str(text_or(state, target_location, key::location, key::empty)));
	state.set(result, str(key::target_slot), str(text_or(state, target_location, key::slot, key::empty)));
	state.set(result, str(key::displaced_artifact_id), str(displaced_id));
	return result;
}

DictRef move_all_field_artifacts(State &state, DictRef session, Atom source_hero_id, Atom target_hero_id) {
	// Hands over every artifact the target does not already own, each through
	// the classic handoff (matching empty slot, otherwise backpack).
	normalize_session(state, session, key::empty, state.new_dict(), state.new_dict());
	const Atom pair_error = _field_exchange_pair_error(state, session, source_hero_id, target_hero_id);
	if (pair_error != key::empty) {
		return refusal(state, pair_error);
	}
	const Atom source_name = _holder_label(state, session, state.new_dict(), source_hero_id);
	const Atom target_name = _holder_label(state, session, state.new_dict(), target_hero_id);
	const ArrayRef owned = artifact_rules::owned_artifact_ids(state, hero_by_id(state, session, source_hero_id));
	const int64_t owned_count = state.array_size(owned);
	if (owned_count == 0) {
		return refusal(state, gd::format(state, key::s_carries_no_artifacts, {str(source_name)}));
	}
	const ArrayRef moved = state.new_array();
	const ArrayRef kept = state.new_array();
	// The loop does not change `owned`.
	for (int64_t index = 0; index < owned_count; ++index) {
		const Atom artifact_id = string_of(state, state.at(owned, index));
		if (artifact_rules::has_artifact(state, hero_by_id(state, session, target_hero_id), artifact_id)) {
			state.append(kept, str(artifact_id));
			continue;
		}
		const DictRef result = transfer_field_artifact(state, session, source_hero_id, target_hero_id, artifact_id);
		if (gd::bool_field(state, result, key::ok, false)) {
			state.append(moved, str(artifact_id));
		} else {
			state.append(kept, str(artifact_id));
		}
	}
	const int64_t moved_size = state.array_size(moved);
	if (moved_size == 0) {
		return refusal(state, gd::format(state, key::s_already_owns_every_artifact_s, {str(target_name), str(source_name)}));
	}
	Atom message = gd::format(state, key::passed_d_artifact_s_from_s, {
			int_value(moved_size),
			str(moved_size == 1 ? static_cast<Atom>(key::empty) : static_cast<Atom>(key::s)),
			str(source_name),
			str(target_name),
	});
	const int64_t kept_size = state.array_size(kept);
	if (kept_size != 0) {
		message = concat(state, message, gd::format(state, key::d_already_owned_stay_s_with, {
				int_value(kept_size),
				str(kept_size == 1 ? static_cast<Atom>(key::s) : static_cast<Atom>(key::empty)),
				str(source_name),
		}));
	}
	const DictRef result = state.new_dict();
	state.set(result, str(key::ok), bool_value(true));
	state.set(result, str(key::message), str(message));
	state.set(result, str(key::source_hero_id), str(source_hero_id));
	state.set(result, str(key::target_hero_id), str(target_hero_id));
	state.set(result, str(key::moved_artifact_ids), array_value(moved));
	state.set(result, str(key::kept_artifact_ids), array_value(kept));
	return result;
}

DictRef _rearrange_field_artifact(State &state, DictRef session, Atom hero_id, Atom artifact_id, Atom target_slot) {
	if (!_army_slot_holder_is_available(state, session, state.new_dict(), hero_id)) {
		return refusal(state, key::only_commanders_at_the_meeting_can);
	}
	const DictRef hero = hero_by_id(state, session, hero_id);
	const DictRef location = artifact_rules::locate_artifact(state, hero, artifact_id);
	if (text_or(state, location, key::location, key::missing) == key::missing) {
		return refusal(state, gd::format(state, key::that_artifact_is_no_longer_owned_2, {str(text_or(state, hero, key::name, hero_id))}));
	}
	const bool to_pack = target_slot == key::pack || target_slot == key::empty;
	if (to_pack && text_or(state, location, key::location, key::empty) != key::equipped) {
		return refusal(state, gd::format(state, key::s_is_already_in_the_backpack, {str(artifact_rules::artifact_name(state, artifact_id))}));
	}
	const DictRef change = to_pack
			? artifact_rules::unequip_artifact(state, hero, text_or(state, location, key::slot, key::empty))
			: artifact_rules::equip_artifact_in_slot(state, hero, artifact_id, target_slot);
	if (!gd::bool_field(state, change, key::ok, false)) {
		return refusal(state, text_or(state, change, key::message, key::the_gear_did_not_change));
	}
	const DictRef changed_hero = gd::as_dict(state.get(change, str(key::hero), dict_value(hero)));
	const int64_t previous_max = movement_max_for_hero(state, hero, dict_value(session));
	const DictRef updated = _preserve_movement_deficit_after_artifact_change(state, changed_hero, previous_max, session);
	const ArrayRef updated_heroes = state.new_array();
	state.append(updated_heroes, dict_value(updated));
	_store_field_heroes(state, session, updated_heroes);
	const DictRef new_location = artifact_rules::locate_artifact(state, updated, artifact_id);
	const DictRef result = state.new_dict();
	state.set(result, str(key::ok), bool_value(true));
	state.set(result, str(key::message), str(text_or(state, change, key::message, key::empty)));
	state.set(result, str(key::source_hero_id), str(hero_id));
	state.set(result, str(key::target_hero_id), str(hero_id));
	state.set(result, str(key::artifact_id), str(artifact_id));
	state.set(result, str(key::target_location), str(text_or(state, new_location, key::location, key::empty)));
	state.set(result, str(key::target_slot), str(text_or(state, new_location, key::slot, key::empty)));
	state.set(result, str(key::displaced_artifact_id), str(text_or(state, change, key::swapped_out_artifact_id, key::empty)));
	return result;
}

void _store_field_heroes(State &state, DictRef session, ArrayRef updated_heroes) {
	const ArrayRef heroes = player_heroes_or_new(state, session);
	for (const Value &hero_value : gd::items(state, array_value(updated_heroes))) {
		if (gd::is_dict(hero_value)) {
			_replace_hero_in_array(state, heroes, hero_value.ref);
		}
	}
	state.set(session_view::overworld(state, session), str(key::player_heroes), array_value(heroes));
	_sync_active_hero_mirror(state, session);
}

DictRef _plan_move_all_troops(State &state, ArrayRef source_stacks, ArrayRef target_stacks, int64_t keeper_index) {
	const ArrayRef remaining = state.new_array();
	const ArrayRef target = gd::as_array(gd::engine_duplicate(state, array_value(target_stacks), true));
	int64_t moved_count = 0;
	const int64_t source_count = state.array_size(source_stacks);
	for (int64_t index = 0; index < source_count; ++index) {
		const DictRef stack = gd::as_dict(gd::engine_duplicate(state, state.at(source_stacks, index), true));
		const int64_t count = gd::int_field(state, stack, key::count, 0);
		const int64_t amount = index == keeper_index ? gd::sub(count, 1) : count;
		if (amount <= 0) {
			state.append(remaining, dict_value(stack));
			continue;
		}
		const Atom unit_id = text_or(state, stack, key::unit_id, key::empty);
		int64_t matching = -1;
		const DictRef claimed = state.new_dict();
		const int64_t target_count = state.array_size(target);
		for (int64_t target_index = 0; target_index < target_count; ++target_index) {
			const Value entry = state.at(target, target_index);
			state.set(claimed, int_value(gd::to_int(state, ai::vget(state, entry, key::slot_index, int_value(-1)))), bool_value(true));
			if (matching < 0 && string_of(state, ai::vget(state, entry, key::unit_id, str(key::empty))) == unit_id) {
				matching = target_index;
			}
		}
		if (matching >= 0) {
			// target[matching]["count"] = int(target[matching].get("count", 0)) + amount
			const Value entry = state.at(target, matching);
			const int64_t total = gd::add(gd::to_int(state, ai::vget(state, entry, key::count, int_value(0))), amount);
			state.set(gd::as_dict(entry), str(key::count), int_value(total));
		} else {
			int64_t open_slot = gd::int_field(state, stack, key::slot_index, -1);
			if (open_slot < 0 || open_slot >= kArmySlotCount || state.has(claimed, int_value(open_slot))) {
				open_slot = _first_open_army_slot(state, claimed);
			}
			if (open_slot < 0) {
				state.append(remaining, dict_value(stack));
				continue;
			}
			const DictRef moved_stack = gd::as_dict(gd::engine_duplicate(state, dict_value(stack), true));
			state.set(moved_stack, str(key::count), int_value(amount));
			state.set(moved_stack, str(key::slot_index), int_value(open_slot));
			state.append(target, dict_value(moved_stack));
		}
		moved_count = gd::add(moved_count, amount);
		if (amount < count) {
			state.set(stack, str(key::count), int_value(gd::sub(count, amount)));
			state.append(remaining, dict_value(stack));
		}
	}
	const DictRef plan = state.new_dict();
	state.set(plan, str(key::remaining), array_value(remaining));
	state.set(plan, str(key::target), array_value(target));
	state.set(plan, str(key::moved_count), int_value(moved_count));
	return plan;
}

int64_t _move_all_keeper_index(State &state, ArrayRef source_stacks) {
	// The creature left behind comes from the lowest-tier stack (first slot on ties).
	int64_t keeper = -1;
	int64_t keeper_tier = 99;
	const int64_t count = state.array_size(source_stacks);
	for (int64_t index = 0; index < count; ++index) {
		const Atom unit_id = string_of(state, ai::vget(state, state.at(source_stacks, index), key::unit_id, str(key::empty)));
		const int64_t tier = gd::int_field(state, gd::content_row(state, ContentTable::Unit, unit_id), key::tier, 1);
		if (keeper < 0 || tier < keeper_tier) {
			keeper = index;
			keeper_tier = tier;
		}
	}
	return keeper;
}

Atom _field_exchange_pair_error(State &state, DictRef session, Atom source_hero_id, Atom target_hero_id) {
	// session == null: a view is never null.
	if (source_hero_id == key::empty || target_hero_id == key::empty || source_hero_id == target_hero_id) {
		return key::choose_two_different_controlled_commanders;
	}
	if (!_army_slot_holder_is_available(state, session, state.new_dict(), source_hero_id)
			|| !_army_slot_holder_is_available(state, session, state.new_dict(), target_hero_id)) {
		return key::both_commanders_must_stand_together_on;
	}
	const Atom active_id = text_or(state, session_view::overworld(state, session), key::active_hero_id, key::empty);
	if (active_id != source_hero_id && active_id != target_hero_id) {
		return key::field_transfers_must_include_the_active;
	}
	return key::empty;
}

} // namespace hero_command_rules

} // namespace aurelion::rules::port
