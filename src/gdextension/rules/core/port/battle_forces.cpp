// Layer 11: the forces and commanders after a battle: the survivors written back to the hero, town, site or
// encounter they came from, the winners' recovery and mana, the battle salvage, the commander's experience, a
// withdrawal's losses, a fallen hero's removal and the enemy commander's memory, record and task.

#include "aurelion_rules/port/battle_rules.hpp"
#include "aurelion_rules/port/overworld_rules.hpp"

#include "aurelion_rules/port/ai_port.hpp"
#include "aurelion_rules/port/artifact_rules.hpp"
#include "aurelion_rules/port/ai_route.hpp"
#include "aurelion_rules/port/battle_ai_rules.hpp"
#include "aurelion_rules/port/battle_ends.hpp"
#include "aurelion_rules/port/hero_command_rules.hpp"
#include "aurelion_rules/port/hero_command_rules_ai.hpp"
#include "aurelion_rules/port/hero_commit.hpp"

#include "aurelion_rules/compat/godot_math.hpp"

#include <algorithm>
#include <string>

namespace aurelion::rules::port::battle_rules {

using gd::array_value;
using gd::bool_value;
using gd::dict_value;
using gd::int_value;
using gd::str;
using state::ContentTable;
using state::Kind;
namespace key = state::key;

namespace {

// session.battle, session.overworld and session.flags: SessionData types them Dictionary, read again at every use as
// GDScript reads them.
DictRef session_battle(State &state, const Value &session) {
	return gd::as_dict(gd::member(state, session, key::battle));
}

DictRef session_overworld(State &state, const Value &session) {
	return gd::as_dict(gd::member(state, session, key::overworld));
}

DictRef session_flags(State &state, const Value &session) {
	return gd::as_dict(gd::member(state, session, key::flags));
}

// session == null or session.battle.is_empty()
bool no_battle(State &state, const Value &session) {
	return session.kind == Kind::Nil || gd::is_empty(state, session_battle(state, session));
}

// d.get(field, {}) and d.get(field, []): a new container when the key is missing.
Value get_or_new_dict(State &state, DictRef dict, Atom field) {
	Value found;
	if (state.lookup(dict, str(field), found)) {
		return found;
	}
	return dict_value(state.new_dict());
}

Value get_or_new_array(State &state, DictRef dict, Atom field) {
	Value found;
	if (state.lookup(dict, str(field), found)) {
		return found;
	}
	return array_value(state.new_array());
}

// value is Dictionary and not value.is_empty() of d.get(field, {}): a missing key's new {} is empty.
bool nonempty_dict_field(State &state, DictRef dict, Atom field, Value &out) {
	return state.lookup(dict, str(field), out) && gd::is_dict(out) && !gd::is_empty(state, out.ref);
}

// String(d.get(field, fallback)).
Atom text_field(State &state, DictRef dict, Atom field, Atom fallback = key::empty) {
	return gd::stringify(state, state.get(dict, str(field), str(fallback)));
}

// String(x.get(field, fallback)) of an untyped value.
Atom vtext(State &state, const Value &object, Atom field, const Value &fallback) {
	return gd::stringify(state, ai::vget(state, object, field, fallback));
}

// d.get(field, {}).get(name, fallback): a missing field's new {} answers the fallback.
Value nested_get(State &state, DictRef dict, Atom field, Atom name, const Value &fallback) {
	Value found;
	if (!state.lookup(dict, str(field), found)) {
		return fallback;
	}
	return ai::vget(state, found, name, fallback);
}

// x[index] = value of an untyped Array or Dictionary.
void set_index(State &state, const Value &container, int64_t index, const Value &value) {
	if (gd::is_array(container)) {
		state.set_at(container.ref, index, value);
		return;
	}
	if (gd::is_dict(container)) {
		state.set(container.ref, int_value(index), value);
		return;
	}
	throw state::ScriptError(std::string("Invalid assignment of index on a base object of type '") + gd::type_name(container) + "'.");
}

// commander_type in ["active_hero", "town_hero"]
bool is_hero_commander(Atom type) {
	return type == key::active_hero || type == key::town_hero;
}

// {"source_type": source_type, field: value}
DictRef survivor_filter(State &state, Atom source_type, Atom field, Atom value) {
	const DictRef filter = state.new_dict();
	state.set(filter, str(key::source_type), str(source_type));
	state.set(filter, str(field), str(value));
	return filter;
}

// {"id": id, "name": name, "stacks": stacks}
DictRef army_payload(State &state, Atom id, Atom name, ArrayRef stacks) {
	const DictRef army = state.new_dict();
	state.set(army, str(key::id), str(id));
	state.set(army, str(key::name), str(name));
	state.set(army, str(key::stacks), array_value(stacks));
	return army;
}

// {"ok": false, "reason": reason}
DictRef refusal(State &state, Atom reason) {
	const DictRef result = state.new_dict();
	state.set(result, str(key::ok), bool_value(false));
	state.set(result, str(key::reason), str(reason));
	return result;
}

// {"kind": kind, "id": id, "label": label}
DictRef rivalry(State &state, Atom kind, Atom id, Atom label) {
	const DictRef result = state.new_dict();
	state.set(result, str(key::kind), str(kind));
	state.set(result, str(key::id), str(id));
	state.set(result, str(key::label), str(label));
	return result;
}

// x.duplicate(true) if x is Dictionary else fallback, of d.get(field, {}): a missing field's {} duplicates to a new {}.
DictRef duplicated_dict_field(State &state, DictRef dict, Atom field) {
	Value found;
	if (!state.lookup(dict, str(field), found)) {
		return state.new_dict();
	}
	return gd::is_dict(found) ? gd::deep_duplicate_dict(state, found.ref) : state.new_dict();
}

// hero_state.get(field, {}).duplicate(true) if hero_state.get(field, {}) is Dictionary else
// session.overworld.get(mirror, {})
Value mirror_or_kept(State &state, DictRef hero_state, Atom field, DictRef overworld, Atom mirror) {
	Value found;
	if (!state.lookup(hero_state, str(field), found)) {
		return dict_value(state.new_dict());
	}
	if (gd::is_dict(found)) {
		return dict_value(gd::deep_duplicate_dict(state, found.ref));
	}
	return get_or_new_dict(state, overworld, mirror);
}

} // namespace

int64_t _apply_victory_recovery(State &state, DictRef battle, Atom side) {
	const int64_t pct = gd::int_field(state, _hero_payload_for_side(state, battle, side), key::victory_recovery_pct, 0);
	if (pct <= 0) {
		return 0;
	}
	int64_t recovered_total = 0;
	const ArrayRef stacks = gd::as_array(get_or_new_array(state, battle, key::stacks));
	const int64_t size = state.array_size(stacks);
	for (int64_t index = 0; index < size; ++index) {
		const Value stack = state.at(stacks, index);
		if (!gd::is_dict(stack) || text_field(state, stack.ref, key::side) != side) {
			continue;
		}
		const int64_t fallen = compat::engine_max<int64_t>(0, gd::sub(gd::int_field(state, stack.ref, key::base_count, 0), _alive_count(state, stack.ref)));
		const int64_t recovered = compat::int_div(gd::add(gd::mul(fallen, pct), 50), 100);
		if (recovered <= 0) {
			continue;
		}
		const int64_t unit_hp = compat::engine_max<int64_t>(1, gd::int_field(state, stack.ref, key::unit_hp, 1));
		state.set(stack.ref, str(key::total_health), int_value(gd::mul(gd::add(_alive_count(state, stack.ref), recovered), unit_hp)));
		state.set_at(stacks, index, stack);
		recovered_total = gd::add(recovered_total, recovered);
	}
	state.set(battle, str(key::stacks), array_value(stacks));
	return recovered_total;
}

int64_t _apply_victory_mana(State &state, DictRef commander_state, DictRef battle, Atom side) {
	const int64_t amount = gd::int_field(state, _hero_payload_for_side(state, battle, side), key::mana_after_victory, 0);
	Value spellbook;
	const bool has_spellbook = state.lookup(commander_state, str(key::spellbook), spellbook);
	if (amount <= 0 || (has_spellbook && !gd::is_dict(spellbook))) {
		return 0;
	}
	if (!has_spellbook) {
		spellbook = dict_value(state.new_dict());
	}
	Value mana_value;
	const DictRef mana = state.lookup(spellbook.ref, str(key::mana), mana_value) && gd::is_dict(mana_value) ? mana_value.ref : state.new_dict();
	const int64_t before = gd::int_field(state, mana, key::current, 0);
	state.set(mana, str(key::current), int_value(compat::engine_min<int64_t>(gd::int_field(state, mana, key::max, before), gd::add(before, amount))));
	state.set(spellbook.ref, str(key::mana), dict_value(mana));
	state.set(commander_state, str(key::spellbook), spellbook);
	return gd::sub(gd::to_int(state, gd::index(state, mana, str(key::current))), before);
}

DictRef _apply_player_battle_salvage_reward(State &state, const Value &session) {
	if (no_battle(state, session)) {
		return refusal(state, key::no_active_battle);
	}
	const Value commander_source = get_or_new_dict(state, session_battle(state, session), key::player_commander_source);
	if (!gd::is_dict(commander_source) || text_field(state, commander_source.ref, key::type) != key::active_hero) {
		return refusal(state, key::ineligible_commander);
	}
	const DictRef encounter = _current_battle_encounter_placement(state, session);
	Value source_record;
	if (!state.lookup(encounter, str(key::artifact_source_context), source_record) || !gd::is_dict(source_record) || gd::is_empty(state, source_record.ref)) {
		return refusal(state, key::source_not_opted_in);
	}
	const Value placement_fallback = state.get(encounter, str(key::placement_id), str(key::empty));
	const Atom encounter_key = gd::strip_edges(state, gd::stringify(state, state.get(session_battle(state, session), str(key::resolved_key), placement_fallback)));
	if (encounter_key == key::empty) {
		return refusal(state, key::missing_source_key);
	}
	const Atom source_key = gd::format(state, key::s_s_battle_salvage, { gd::member(state, session, key::scenario_id), str(encounter_key) });
	Value raw_claims;
	const DictRef claims = state.lookup(session_flags(state, session), str(key::artifact_source_claims), raw_claims) && gd::is_dict(raw_claims) ? raw_claims.ref : state.new_dict();
	if (state.has(claims, str(source_key))) {
		const DictRef result = refusal(state, key::already_claimed);
		state.set(result, str(key::duplicate), bool_value(true));
		state.set(result, str(key::source_key), str(source_key));
		return result;
	}

	const ArrayRef excluded_artifact_ids = artifact_rules::owned_artifact_ids(state, gd::as_dict(get_or_new_dict(state, session_overworld(state, session), key::hero)));
	for (const Value &node_value : gd::field_items(state, session_overworld(state, session), str(key::artifact_nodes))) {
		if (!gd::is_dict(node_value) || gd::bool_field(state, node_value.ref, key::collected, false)) {
			continue;
		}
		const Atom reserved_artifact_id = gd::strip_edges(state, text_field(state, node_value.ref, key::artifact_id));
		if (reserved_artifact_id != key::empty && !gd::array_has(state, excluded_artifact_ids, str(reserved_artifact_id))) {
			state.append(excluded_artifact_ids, str(reserved_artifact_id));
		}
	}
	const DictRef scenario = gd::content_row(state, ContentTable::Scenario, gd::to_string(gd::member(state, session, key::scenario_id)));
	const Atom faction_id = text_field(state, scenario, key::player_faction_id);
	const DictRef selection = artifact_rules::select_live_source_reward(state, key::battle_salvage, source_record.ref, source_key, faction_id, excluded_artifact_ids);
	if (!gd::bool_field(state, selection, key::ok, false)) {
		return selection;
	}
	const Value name_fallback = state.get(encounter, str(key::placement_id), str(key::the_enemy_host));
	const Atom encounter_name = gd::stringify(state, state.get(session_battle(state, session), str(key::encounter_name), name_fallback));
	const Atom artifact_id = text_field(state, selection, key::artifact_id);
	const Atom source_verb = gd::format(state, key::salvaged_after_defeating_s, { str(encounter_name) });
	const DictRef claim = overworld_rules::_apply_artifact_claim(state, gd::object_view(state, session), artifact_id, source_verb, true);
	state.set(selection, str(key::claim), dict_value(claim));
	const bool applied = gd::bool_field(state, claim, key::ok, false) && !gd::bool_field(state, claim, key::duplicate, false);
	state.set(selection, str(key::applied), bool_value(applied));
	state.set(selection, str(key::message), str(text_field(state, claim, key::message)));
	if (!gd::bool_field(state, selection, key::applied, false)) {
		return selection;
	}
	const DictRef record = state.new_dict();
	state.set(record, str(key::artifact_id), str(text_field(state, selection, key::artifact_id)));
	state.set(record, str(key::table_id), str(text_field(state, selection, key::table_id)));
	state.set(record, str(key::source_key), str(source_key));
	const Value battle_encounter_id = state.get(session_battle(state, session), str(key::encounter_id), str(key::empty));
	state.set(record, str(key::encounter_id), str(gd::stringify(state, state.get(encounter, str(key::encounter_id), battle_encounter_id))));
	state.set(record, str(key::placement_id), str(encounter_key));
	state.set(record, str(key::claimed_day), gd::member(state, session, key::day));
	state.set(record, str(key::claimed_by), str(key::player));
	state.set(record, str(key::claimed_by_faction_id), str(faction_id));
	state.set(claims, str(source_key), dict_value(record));
	state.set(session_flags(state, session), str(key::artifact_source_claims), dict_value(claims));
	return selection;
}

Atom _resolve_enemy_commander_aftermath(State &state, const Value &session, Atom outcome_id) {
	if (no_battle(state, session)) {
		return key::empty;
	}
	Value commander;
	if (!nonempty_dict_field(state, session_battle(state, session), key::enemy_hero, commander)) {
		return key::empty;
	}
	DictRef commander_state = _enemy_commander_state_with_payload(state, session, commander.ref);
	commander_state = _apply_enemy_commander_battle_memory(state, session, commander_state);
	state.set(session_battle(state, session), str(key::enemy_hero), dict_value(commander_state));
	const DictRef battle = session_battle(state, session);
	const DictRef payload = _enemy_hero_payload_from_state(state, commander_state, get_or_new_dict(state, session_battle(state, session), key::enemy_hero_payload), session);
	state.set(battle, str(key::enemy_hero_payload), dict_value(payload));
	const DictRef view = gd::object_view(state, session);
	const Atom faction_id = _battle_enemy_faction_id(state, session);
	return enemy_adventure_rules::apply_resolved_commander_aftermath(state, view, faction_id, dict_value(commander_state), outcome_id);
}

void _finish_enemy_battle_task_assignment(State &state, const Value &session, Atom task_status, Atom validation) {
	if (no_battle(state, session)) {
		return;
	}
	const Atom faction_id = _battle_enemy_faction_id(state, session);
	if (faction_id == key::empty) {
		return;
	}
	const DictRef raid = _current_battle_encounter_placement(state, session);
	if (gd::is_empty(state, raid)) {
		return;
	}
	Value context_value;
	const DictRef context = state.lookup(session_battle(state, session), str(key::context), context_value) && gd::is_dict(context_value) ? context_value.ref : state.new_dict();
	if (text_field(state, raid, key::target_kind) == key::empty) {
		if (_is_town_defense_context(state, dict_value(context))) {
			state.set(raid, str(key::target_kind), str(key::town));
			state.set(raid, str(key::target_placement_id), str(text_field(state, context, key::town_placement_id)));
		} else if (_is_resource_assault_context(state, dict_value(context))) {
			state.set(raid, str(key::target_kind), str(key::resource));
			state.set(raid, str(key::target_placement_id), str(text_field(state, context, key::resource_placement_id)));
		} else if (text_field(state, context, key::type) == key::hero_intercept) {
			state.set(raid, str(key::target_kind), str(key::hero));
			state.set(raid, str(key::target_placement_id), str(text_field(state, context, key::target_hero_id)));
		}
	}
	Value raid_commander;
	if (!nonempty_dict_field(state, raid, key::enemy_commander_state, raid_commander)) {
		Value commander;
		if (nonempty_dict_field(state, session_battle(state, session), key::enemy_hero, commander)) {
			state.set(raid, str(key::enemy_commander_state), dict_value(gd::deep_duplicate_dict(state, commander.ref)));
		}
	}
	if (text_field(state, raid, key::target_kind) == key::empty || text_field(state, raid, key::target_placement_id) == key::empty) {
		return;
	}
	enemy_adventure_rules::_ai_hero_task_finish_live_assignment(state, gd::object_view(state, session), faction_id, raid, task_status, validation);
}

void _record_enemy_commander_battle_continuity(State &state, const Value &session, Atom outcome_id) {
	if (no_battle(state, session)) {
		return;
	}
	Value commander;
	if (!nonempty_dict_field(state, session_battle(state, session), key::enemy_hero, commander)) {
		return;
	}
	const DictRef commander_state = _enemy_commander_state_with_payload(state, session, commander.ref);
	const Atom faction_id = _battle_enemy_faction_id(state, session);
	if (faction_id == key::empty) {
		return;
	}
	const DictRef updated_state = enemy_adventure_rules::advance_commander_record(state, _apply_enemy_commander_battle_memory(state, session, commander_state), outcome_id);
	state.set(session_battle(state, session), str(key::enemy_hero), dict_value(updated_state));
	const DictRef battle = session_battle(state, session);
	const DictRef payload = _enemy_hero_payload_from_state(state, updated_state, get_or_new_dict(state, session_battle(state, session), key::enemy_hero_payload), session);
	state.set(battle, str(key::enemy_hero_payload), dict_value(payload));
	const DictRef view = gd::object_view(state, session);
	const Atom resolved_key = text_field(state, session_battle(state, session), key::resolved_key);
	enemy_adventure_rules::sync_commander_state_to_roster(state, view, faction_id, dict_value(updated_state), key::active, resolved_key, -1, outcome_id);
}

DictRef _enemy_commander_state_with_payload(State &state, const Value &session, DictRef commander_state) {
	if (no_battle(state, session)) {
		return commander_state;
	}
	Value payload;
	if (!nonempty_dict_field(state, session_battle(state, session), key::enemy_hero_payload, payload)) {
		return commander_state;
	}
	return ai_route::by_side(state, key::empty, [&] { return battle_ai_rules::_merged_commander_ai_payload(state, commander_state, payload.ref); });
}

DictRef _apply_enemy_commander_battle_memory(State &state, const Value &session, DictRef commander_state) {
	if (no_battle(state, session) || gd::is_empty(state, commander_state)) {
		return commander_state;
	}
	DictRef updated = commander_state;
	const DictRef encounter = _current_battle_encounter_placement(state, session);
	const Atom target_kind = text_field(state, encounter, key::target_kind);
	const Atom target_id = text_field(state, encounter, key::target_placement_id);
	if (target_kind != key::empty && target_id != key::empty) {
		const Atom target_label = text_field(state, encounter, key::target_label);
		// int(encounter.get("target_x", encounter.get("goal_x", encounter.get("x", 0)))), and y.
		const Value x_fallback = state.get(encounter, str(key::goal_x), state.get(encounter, str(key::x), int_value(0)));
		const int64_t target_x = gd::to_int(state, state.get(encounter, str(key::target_x), x_fallback));
		const Value y_fallback = state.get(encounter, str(key::goal_y), state.get(encounter, str(key::y), int_value(0)));
		const int64_t target_y = gd::to_int(state, state.get(encounter, str(key::target_y), y_fallback));
		updated = enemy_adventure_rules::record_target_assignment(state, updated, target_kind, target_id, target_label, target_x, target_y);
	}
	const DictRef rivalry_context = _enemy_commander_rivalry_context(state, session, encounter);
	if (!gd::is_empty(state, rivalry_context)) {
		updated = enemy_adventure_rules::record_rivalry(state, updated, text_field(state, rivalry_context, key::kind), text_field(state, rivalry_context, key::id), text_field(state, rivalry_context, key::label));
	}
	DictRef filter = survivor_filter(state, key::encounter_army, key::encounter_key, text_field(state, session_battle(state, session), key::resolved_key));
	const Value context = get_or_new_dict(state, session_battle(state, session), key::context);
	if (_is_town_assault_context(state, context)) {
		filter = survivor_filter(state, key::town_garrison, key::town_placement_id, vtext(state, context, key::town_placement_id, str(key::empty)));
	} else if (_is_resource_assault_context(state, context)) {
		filter = survivor_filter(state, key::resource_defender, key::resource_placement_id, vtext(state, context, key::resource_placement_id, str(key::empty)));
	}
	const ArrayRef survivor_stacks = _battle_survivor_stacks(state, session, key::enemy, filter);
	const Value id_fallback = state.get(encounter, str(key::id), str(key::empty));
	Atom encounter_id = gd::stringify(state, state.get(encounter, str(key::encounter_id), id_fallback));
	if (encounter_id == key::empty) {
		encounter_id = text_field(state, session_battle(state, session), key::encounter_id);
	}
	const DictRef army_source = state.new_dict();
	state.set(army_source, str(key::stacks), array_value(survivor_stacks));
	updated = enemy_adventure_rules::sync_commander_army_continuity(state, updated, dict_value(army_source), encounter_id);
	return updated;
}

DictRef _enemy_commander_rivalry_context(State &state, const Value &session, DictRef encounter) {
	if (no_battle(state, session)) {
		return state.new_dict();
	}
	const Value context = get_or_new_dict(state, session_battle(state, session), key::context);
	if (_is_town_defense_context(state, context) || _is_town_assault_context(state, context)) {
		const Atom town_id = vtext(state, context, key::town_placement_id, str(key::empty));
		if (town_id != key::empty) {
			return rivalry(state, key::town, town_id, _town_name_from_placement_id(state, session, town_id));
		}
	}
	const Value player_source = get_or_new_dict(state, session_battle(state, session), key::player_commander_source);
	const Atom hero_id = vtext(state, player_source, key::hero_id, str(key::empty));
	if (is_hero_commander(vtext(state, player_source, key::type, str(key::empty))) && hero_id != key::empty) {
		const Value player_state = get_or_new_dict(state, session_battle(state, session), key::player_commander_state);
		Atom hero_label = vtext(state, player_state, key::name, str(key::empty));
		if (hero_label == key::empty) {
			const DictRef hero = hero_command_rules::hero_by_id(state, gd::object_view(state, session), hero_id);
			hero_label = text_field(state, hero, key::name, hero_id);
		}
		return rivalry(state, key::hero, hero_id, hero_label);
	}
	DictRef target = encounter;
	if (gd::is_empty(state, target)) {
		target = _current_battle_encounter_placement(state, session);
	}
	const Atom target_kind = text_field(state, target, key::target_kind);
	if ((target_kind == key::town || target_kind == key::hero) && text_field(state, target, key::target_placement_id) != key::empty) {
		return rivalry(state, text_field(state, target, key::target_kind), text_field(state, target, key::target_placement_id), text_field(state, target, key::target_label));
	}
	return state.new_dict();
}

Atom _apply_active_hero_aftermath_losses(State &state, const Value &session, int64_t unit_losses, Atom outcome) {
	const Value commander_source = get_or_new_dict(state, session_battle(state, session), key::player_commander_source);
	const Value active_hero_id = state.get(session_overworld(state, session), str(key::active_hero_id), str(key::empty));
	const Atom hero_id = vtext(state, commander_source, key::hero_id, active_hero_id);
	if (hero_id == key::empty) {
		return key::empty;
	}
	const DictRef hero = hero_command_rules::hero_by_id(state, gd::object_view(state, session), hero_id);
	if (gd::is_empty(state, hero)) {
		return key::empty;
	}
	const DictRef army = duplicated_dict_field(state, hero, key::army);
	Value stacks_value;
	const ArrayRef stacks = state.lookup(army, str(key::stacks), stacks_value) && gd::is_array(stacks_value) ? gd::deep_duplicate_array(state, stacks_value.ref) : state.new_array();
	const int64_t before_units = _stack_count_total(state, array_value(stacks));
	if (before_units <= 0) {
		return key::empty;
	}
	const int64_t before_companies = state.array_size(stacks);
	const int64_t applied_losses = _remove_units_from_stacks(state, stacks, unit_losses);
	state.set(army, str(key::stacks), array_value(stacks));
	state.set(hero, str(key::army), dict_value(army));
	_set_player_hero_state(state, session, hero, hero_id);
	const int64_t after_companies = state.array_size(stacks);
	if (applied_losses <= 0) {
		return outcome == key::surrender ? key::the_surrender_terms_spare_the_surviving : key::the_surviving_companies_keep_formation_through;
	}
	const int64_t broken_companies = compat::engine_max<int64_t>(0, gd::sub(before_companies, after_companies));
	if (outcome == key::surrender) {
		return gd::format(state, key::disarmament_and_stragglers_cost_d_troop,
				{ int_value(applied_losses), str(applied_losses == 1 ? key::empty : key::s), int_value(after_companies),
						str(after_companies == 1 ? key::y : key::ies) });
	}
	Atom company_clause = key::empty;
	if (broken_companies > 0) {
		company_clause = gd::format(state, key::and_breaks_d_compan_s, { int_value(broken_companies), str(broken_companies == 1 ? key::y : key::ies) });
	}
	return gd::format(state, key::pursuit_scatters_d_troop_s_s, { int_value(applied_losses), str(applied_losses == 1 ? key::empty : key::s), str(company_clause) });
}

// Moves the garrison's share of each merged kind out of the hero's survivors
// (latest stacks first) into returned.
void _return_merged_garrison(State &state, ArrayRef hero_stacks, const Value &merged, ArrayRef returned) {
	if (!gd::is_array(merged)) {
		return;
	}
	for (const Value &entry : gd::items(state, merged)) {
		if (!gd::is_dict(entry)) {
			continue;
		}
		const Atom unit = text_field(state, entry.ref, key::unit_id);
		int64_t survived = 0;
		for (const Value &stack : gd::items(state, array_value(hero_stacks))) {
			if (text_field(state, stack.ref, key::unit_id) == unit) {
				survived = gd::add(survived, gd::int_field(state, stack.ref, key::count, 0));
			}
		}
		int64_t move = survived - hero_command_rules::entry_hero_share(survived, gd::int_field(state, entry.ref, key::hero_count, 0), gd::int_field(state, entry.ref, key::garrison_count, 0));
		if (move <= 0) {
			continue;
		}
		const DictRef back = state.new_dict();
		state.set(back, str(key::unit_id), str(unit));
		state.set(back, str(key::count), int_value(move));
		state.append(returned, dict_value(back));
		for (int64_t at = state.array_size(hero_stacks) - 1; at >= 0 && move > 0; --at) {
			const DictRef stack = gd::as_dict(state.at(hero_stacks, at));
			if (text_field(state, stack, key::unit_id) != unit) {
				continue;
			}
			const int64_t count = gd::int_field(state, stack, key::count, 0);
			const int64_t take = std::min(count, move);
			move -= take;
			if (take == count) {
				gd::remove_at(state, hero_stacks, at);
			} else {
				state.set(stack, str(key::count), int_value(count - take));
			}
		}
	}
}

void _sync_player_force_from_battle(State &state, const Value &session) {
	if (no_battle(state, session)) {
		return;
	}
	const Value context = get_or_new_dict(state, session_battle(state, session), key::context);
	const Value commander_source = get_or_new_dict(state, session_battle(state, session), key::player_commander_source);
	const Atom commander_type = vtext(state, commander_source, key::type, str(key::empty));
	const DictRef commander_state = gd::deep_duplicate_dict(state, _player_commander_state(state, session));
	// Garrison creatures merged into the hero's stacks (town_defense_force): their
	// share of the survivors goes back to the garrison.
	const ArrayRef back_to_garrison = state.new_array();
	if (is_hero_commander(commander_type)) {
		// "%s_army" % String(commander_state.get("id", "")), evaluated before the get that falls back to it.
		const Value id_fallback = str(gd::format(state, key::s_army, { str(text_field(state, commander_state, key::id)) }));
		const Atom army_id = gd::stringify(state, nested_get(state, commander_state, key::army, key::id, id_fallback));
		const Atom army_name = gd::stringify(state, nested_get(state, commander_state, key::army, key::name, str(key::field_army)));
		const DictRef filter = survivor_filter(state, key::hero_army, key::hero_id, vtext(state, commander_source, key::hero_id, str(key::empty)));
		const ArrayRef stacks = _battle_survivor_stacks(state, session, key::player, filter);
		if (_is_town_defense_context(state, context)) {
			_return_merged_garrison(state, stacks, state.get(context.ref, str(key::merged_garrison), Value()), back_to_garrison);
		}
		state.set(commander_state, str(key::army), dict_value(army_payload(state, army_id, army_name, stacks)));
		_set_player_hero_state(state, session, commander_state, vtext(state, commander_source, key::hero_id, str(key::empty)));
	}

	if (_is_town_defense_context(state, context)) {
		const Atom town_placement_id = vtext(state, context, key::town_placement_id, str(key::empty));
		const DictRef town_result = _find_town_by_placement(state, session, town_placement_id);
		if (gd::int_field(state, town_result, key::index, -1) >= 0) {
			const Value towns = get_or_new_array(state, session_overworld(state, session), key::towns);
			const DictRef town = gd::as_dict(get_or_new_dict(state, town_result, key::town));
			const DictRef filter = survivor_filter(state, key::town_garrison, key::town_placement_id, vtext(state, context, key::town_placement_id, str(key::empty)));
			const ArrayRef garrison = _battle_survivor_stacks(state, session, key::player, filter);
			for (const Value &returned : gd::items(state, array_value(back_to_garrison))) {
				bool joined = false;
				for (const Value &stack : gd::items(state, array_value(garrison))) {
					if (text_field(state, stack.ref, key::unit_id) == text_field(state, returned.ref, key::unit_id)) {
						state.set(stack.ref, str(key::count), int_value(gd::add(gd::int_field(state, stack.ref, key::count, 0), gd::int_field(state, returned.ref, key::count, 0))));
						joined = true;
						break;
					}
				}
				if (!joined) {
					state.append(garrison, returned);
				}
			}
			state.set(town, str(key::garrison), array_value(garrison));
			set_index(state, towns, gd::int_field(state, town_result, key::index, -1), dict_value(town));
			state.set(session_overworld(state, session), str(key::towns), towns);
			if (is_hero_commander(commander_type)) {
				hero_command_rules::keep_hero_troop_from_garrison(state, gd::object_view(state, session), town, vtext(state, commander_source, key::hero_id, str(key::empty)));
			}
		}
		return;
	}

	const DictRef army = gd::as_dict(get_or_new_dict(state, session_overworld(state, session), key::army));
	const Value active_hero_id = state.get(session_overworld(state, session), str(key::active_hero_id), str(key::empty));
	const DictRef filter = survivor_filter(state, key::hero_army, key::hero_id, vtext(state, commander_source, key::hero_id, active_hero_id));
	state.set(army, str(key::stacks), array_value(_battle_survivor_stacks(state, session, key::player, filter)));
	state.set(session_overworld(state, session), str(key::army), dict_value(army));
}

// A computer hero on the entry led this assault with the garrison
// (create_entry_defense_assault_payload): the town gets its own commander back,
// and the hero falls with the town or takes its share of the survivors.
void _apply_entry_defense_after_assault(State &state, const Value &session, const Value &context, Atom town_placement_id, DictRef synced_commander, bool encounter_resolved) {
	const Value record = state.get(context.ref, str(key::entry_defense), Value());
	if (!gd::is_dict(record)) {
		return;
	}
	const DictRef town_result = _find_town_by_placement(state, session, town_placement_id);
	if (gd::int_field(state, town_result, key::index, -1) < 0) {
		return;
	}
	const Value towns = get_or_new_array(state, session_overworld(state, session), key::towns);
	const DictRef town = gd::as_dict(get_or_new_dict(state, town_result, key::town));
	if (text_field(state, town, key::owner, key::neutral) == key::enemy) {
		const Value town_commander = state.get(record.ref, str(key::town_commander), Value());
		if (gd::is_dict(town_commander) && !gd::is_empty(state, town_commander.ref)) {
			state.set(town, str(key::ai_defender_commander_state), gd::duplicate_value(state, town_commander, true));
			state.set(town, str(key::ai_defender_roster_hero_id), state.get(record.ref, str(key::town_roster_hero_id), str(key::empty)));
		} else {
			state.erase(town, str(key::ai_defender_commander_state));
			state.erase(town, str(key::ai_defender_roster_hero_id));
		}
	}
	const Atom resolved_key = text_field(state, record.ref, key::resolved_key);
	if (encounter_resolved) {
		_mark_resolved_encounter(state, session, resolved_key);
		set_index(state, towns, gd::int_field(state, town_result, key::index, -1), dict_value(town));
		state.set(session_overworld(state, session), str(key::towns), towns);
		return;
	}
	const DictRef split = hero_command_rules::split_entry_defense(state, state.get(record.ref, str(key::hero_stacks), Value()), state.get(record.ref, str(key::garrison), Value()), state.get(town, str(key::garrison), Value()));
	state.set(town, str(key::garrison), gd::index(state, split, str(key::garrison)));
	set_index(state, towns, gd::int_field(state, town_result, key::index, -1), dict_value(town));
	state.set(session_overworld(state, session), str(key::towns), towns);
	const Atom hero_placement = text_field(state, record.ref, key::placement_id);
	const Value encounters = get_or_new_array(state, session_overworld(state, session), key::encounters);
	for (int64_t at = 0; at < state.array_size(encounters.ref); ++at) {
		const Value encounter = state.at(encounters.ref, at);
		if (!gd::is_dict(encounter) || text_field(state, encounter.ref, key::placement_id) != hero_placement) {
			continue;
		}
		const ArrayRef hero_stacks = gd::as_array(gd::index(state, split, str(key::hero)));
		if (state.array_size(hero_stacks) == 0) {
			_mark_resolved_encounter(state, session, resolved_key);
			break;
		}
		const DictRef army = gd::as_dict(get_or_new_dict(state, encounter.ref, key::enemy_army));
		state.set(army, str(key::stacks), array_value(hero_stacks));
		state.set(encounter.ref, str(key::enemy_army), dict_value(army));
		// The assault's commander lost the hero's identity (its roster id): the
		// hero's own record takes the battle's changes.
		const DictRef commander = gd::deep_duplicate_dict(state, gd::as_dict(get_or_new_dict(state, encounter.ref, key::enemy_commander_state)));
		const Atom roster_hero_id = text_field(state, commander, key::roster_hero_id);
		gd::merge(state, commander, gd::deep_duplicate_dict(state, synced_commander), true);
		if (roster_hero_id != key::empty) {
			state.set(commander, str(key::roster_hero_id), str(roster_hero_id));
		}
		state.set(encounter.ref, str(key::enemy_commander_state), dict_value(enemy_adventure_rules::sync_commander_army_continuity(state, commander, dict_value(army), key::encounter_mire_raid)));
		set_index(state, encounters, at, encounter);
		state.set(session_overworld(state, session), str(key::encounters), encounters);
		break;
	}
}

void _sync_enemy_force_from_battle(State &state, const Value &session, bool encounter_resolved) {
	if (no_battle(state, session)) {
		return;
	}
	const Value context = get_or_new_dict(state, session_battle(state, session), key::context);
	const DictRef synced_enemy_commander_state = _enemy_commander_state_for_force_sync(state, session);
	if (_is_town_assault_context(state, context)) {
		const Atom town_placement_id = vtext(state, context, key::town_placement_id, str(key::empty));
		const DictRef town_result = _find_town_by_placement(state, session, town_placement_id);
		if (gd::int_field(state, town_result, key::index, -1) < 0) {
			return;
		}
		const Value towns = get_or_new_array(state, session_overworld(state, session), key::towns);
		const DictRef town = gd::as_dict(get_or_new_dict(state, town_result, key::town));
		const DictRef filter = survivor_filter(state, key::town_garrison, key::town_placement_id, vtext(state, context, key::town_placement_id, str(key::empty)));
		state.set(town, str(key::garrison), array_value(_battle_survivor_stacks(state, session, key::enemy, filter)));
		if (!gd::is_empty(state, synced_enemy_commander_state)) {
			if (text_field(state, town, key::owner, key::neutral) == key::enemy) {
				state.set(town, str(key::ai_defender_commander_state), dict_value(gd::deep_duplicate_dict(state, synced_enemy_commander_state)));
				state.set(town, str(key::ai_defender_roster_hero_id), str(text_field(state, synced_enemy_commander_state, key::roster_hero_id)));
			} else {
				state.erase(town, str(key::ai_defender_commander_state));
				state.erase(town, str(key::ai_defender_roster_hero_id));
				state.erase(town, str(key::ai_defended_by_faction_id));
				state.erase(town, str(key::ai_defense_until_day));
				state.erase(town, str(key::ai_defense_rating));
			}
		}
		set_index(state, towns, gd::int_field(state, town_result, key::index, -1), dict_value(town));
		state.set(session_overworld(state, session), str(key::towns), towns);
		_apply_entry_defense_after_assault(state, session, context, town_placement_id, synced_enemy_commander_state, encounter_resolved);
		return;
	}
	if (_is_resource_assault_context(state, context)) {
		const DictRef filter = survivor_filter(state, key::resource_defender, key::resource_placement_id, vtext(state, context, key::resource_placement_id, str(key::empty)));
		const ArrayRef survivor_stacks = _battle_survivor_stacks(state, session, key::enemy, filter);
		const DictRef view = gd::object_view(state, session);
		const Atom resource_placement_id = vtext(state, context, key::resource_placement_id, str(key::empty));
		const Atom faction_id = _battle_enemy_faction_id(state, session);
		const Atom summary = overworld_rules::update_resource_defender_after_battle(state, view, resource_placement_id, faction_id, synced_enemy_commander_state, survivor_stacks, encounter_resolved);
		if (summary != key::empty) {
			state.set(session_flags(state, session), str(key::last_resource_defender_sync_summary), str(summary));
		}
		return;
	}
	const Atom dwelling_placement = creature_dwelling_rules::placement_from_guard_key(state, text_field(state, session_battle(state, session), key::resolved_key));
	if (dwelling_placement != key::empty) {
		const DictRef view = gd::object_view(state, session);
		const ArrayRef survivors = _battle_survivor_stacks(state, session, key::enemy, state.new_dict());
		const Atom guard_summary = overworld_rules::update_dwelling_guard_after_battle(state, view, dwelling_placement, survivors, encounter_resolved);
		if (guard_summary != key::empty) {
			state.set(session_flags(state, session), str(key::last_dwelling_guard_summary), str(guard_summary));
		}
		return;
	}
	const DictRef encounter_result = _find_encounter_by_key(state, session, text_field(state, session_battle(state, session), key::resolved_key));
	if (gd::int_field(state, encounter_result, key::index, -1) < 0) {
		return;
	}
	const Value encounters = get_or_new_array(state, session_overworld(state, session), key::encounters);
	const DictRef encounter = gd::as_dict(get_or_new_dict(state, encounter_result, key::encounter));
	const Value id_fallback = state.get(encounter, str(key::encounter_id), str(key::encounter_army));
	const Atom army_id = gd::stringify(state, nested_get(state, encounter, key::enemy_army, key::id, id_fallback));
	const Atom army_name = gd::stringify(state, nested_get(state, encounter, key::enemy_army, key::name, str(key::enemy_army_4)));
	const DictRef filter = survivor_filter(state, key::encounter_army, key::encounter_key, text_field(state, session_battle(state, session), key::resolved_key));
	const ArrayRef stacks = _battle_survivor_stacks(state, session, key::enemy, filter);
	state.set(encounter, str(key::enemy_army), dict_value(army_payload(state, army_id, army_name, stacks)));
	if (!gd::is_empty(state, synced_enemy_commander_state)) {
		state.set(encounter, str(key::enemy_commander_state), dict_value(gd::deep_duplicate_dict(state, synced_enemy_commander_state)));
	}
	set_index(state, encounters, gd::int_field(state, encounter_result, key::index, -1), dict_value(encounter));
	state.set(session_overworld(state, session), str(key::encounters), encounters);
	if (encounter_resolved) {
		_mark_resolved_encounter(state, session, text_field(state, session_battle(state, session), key::resolved_key));
	}
}

DictRef _enemy_commander_state_for_force_sync(State &state, const Value &session) {
	if (no_battle(state, session)) {
		return state.new_dict();
	}
	Value commander;
	if (!nonempty_dict_field(state, session_battle(state, session), key::enemy_hero, commander)) {
		return state.new_dict();
	}
	const DictRef commander_state = _enemy_commander_state_with_payload(state, session, commander.ref);
	state.set(session_battle(state, session), str(key::enemy_hero), dict_value(commander_state));
	const DictRef battle = session_battle(state, session);
	const DictRef payload = _enemy_hero_payload_from_state(state, commander_state, get_or_new_dict(state, session_battle(state, session), key::enemy_hero_payload), session);
	state.set(battle, str(key::enemy_hero_payload), dict_value(payload));
	return commander_state;
}

ArrayRef _battle_survivor_stacks(State &state, const Value &session, Atom side, DictRef filters) {
	const ArrayRef survivors = state.new_array();
	for (const Value &stack : gd::field_items(state, session_battle(state, session), str(key::stacks))) {
		if (!gd::is_dict(stack)) {
			continue;
		}
		if (text_field(state, stack.ref, key::side) != side) {
			continue;
		}
		const int64_t count = _alive_count(state, stack.ref);
		if (count <= 0) {
			continue;
		}
		if (state.has(filters, str(key::source_type)) && text_field(state, stack.ref, key::source_type) != text_field(state, filters, key::source_type)) {
			continue;
		}
		if (state.has(filters, str(key::hero_id)) && text_field(state, stack.ref, key::source_hero_id) != text_field(state, filters, key::hero_id)) {
			continue;
		}
		if (state.has(filters, str(key::town_placement_id)) && text_field(state, stack.ref, key::source_town_placement_id) != text_field(state, filters, key::town_placement_id)) {
			continue;
		}
		if (state.has(filters, str(key::encounter_key)) && text_field(state, stack.ref, key::source_encounter_key) != text_field(state, filters, key::encounter_key)) {
			continue;
		}
		const DictRef survivor = state.new_dict();
		state.set(survivor, str(key::unit_id), str(text_field(state, stack.ref, key::unit_id)));
		state.set(survivor, str(key::count), int_value(count));
		const int64_t army_slot_index = gd::int_field(state, stack.ref, key::army_slot_index, -1);
		if (army_slot_index >= 0 && army_slot_index < 7) {
			state.set(survivor, str(key::slot_index), int_value(army_slot_index));
		}
		state.append(survivors, dict_value(survivor));
	}
	return survivors;
}

ArrayRef _award_commander_experience(State &state, const Value &session, int64_t amount) {
	if (amount <= 0 || no_battle(state, session)) {
		return state.new_array();
	}
	const Value commander_source = get_or_new_dict(state, session_battle(state, session), key::player_commander_source);
	if (!is_hero_commander(vtext(state, commander_source, key::type, str(key::empty)))) {
		return state.new_array();
	}
	const DictRef result = hero_progression_rules::add_experience(state, _player_commander_state(state, session), amount);
	const DictRef battle = session_battle(state, session);
	const DictRef commander_fallback = _player_commander_state(state, session);
	state.set(battle, str(key::player_commander_state), state.get(result, str(key::hero), dict_value(commander_fallback)));
	const DictRef payload_battle = session_battle(state, session);
	const DictRef commander_state = gd::as_dict(get_or_new_dict(state, session_battle(state, session), key::player_commander_state));
	const DictRef bonuses = artifact_rules::aggregate_bonuses(state, gd::as_dict(get_or_new_dict(state, session_battle(state, session), key::player_commander_state)));
	state.set(payload_battle, str(key::player_hero), dict_value(_hero_payload_from_state(state, commander_state, bonuses, session, key::player)));
	return gd::as_array(get_or_new_array(state, result, key::messages));
}

Atom _enemy_commander_exit_reaction(State &state, const Value &session, Atom outcome_id) {
	if (no_battle(state, session)) {
		return key::empty;
	}
	Value commander;
	if (!nonempty_dict_field(state, session_battle(state, session), key::enemy_hero, commander)) {
		return key::empty;
	}
	Atom commander_name = enemy_adventure_rules::commander_display_name(state, commander);
	if (commander_name == key::empty) {
		commander_name = text_field(state, commander.ref, key::name, key::the_hostile_commander);
	}
	if (outcome_id == key::pursuit_victory) {
		return gd::format(state, key::s_orders_a_hard_pursuit_and, { str(commander_name) });
	}
	if (outcome_id == key::capitulation) {
		return gd::format(state, key::s_banks_the_surrender_terms_and, { str(commander_name) });
	}
	if (outcome_id == key::rout_victory) {
		return gd::format(state, key::s_breaks_the_field_and_leaves, { str(commander_name) });
	}
	return key::empty;
}

void _set_player_hero_state(State &state, const Value &session, DictRef hero_state, Atom hero_id) {
	if (session.kind == Kind::Nil || hero_id == key::empty) {
		return;
	}
	const Value heroes = get_or_new_array(state, session_overworld(state, session), key::player_heroes);
	if (!gd::is_array(heroes)) {
		return;
	}
	const int64_t size = state.array_size(heroes.ref);
	for (int64_t index = 0; index < size; ++index) {
		const Value hero = state.at(heroes.ref, index);
		if (gd::is_dict(hero) && text_field(state, hero.ref, key::id) == hero_id) {
			state.set_at(heroes.ref, index, dict_value(gd::deep_duplicate_dict(state, hero_state)));
			break;
		}
	}
	state.set(session_overworld(state, session), str(key::player_heroes), heroes);
	if (text_field(state, session_overworld(state, session), key::active_hero_id) == hero_id) {
		state.set(session_overworld(state, session), str(key::hero), dict_value(gd::deep_duplicate_dict(state, hero_state)));
		state.set(session_overworld(state, session), str(key::army), dict_value(duplicated_dict_field(state, hero_state, key::army)));
		const Value position = mirror_or_kept(state, hero_state, key::position, session_overworld(state, session), key::hero_position);
		state.set(session_overworld(state, session), str(key::hero_position), position);
		const Value movement = mirror_or_kept(state, hero_state, key::movement, session_overworld(state, session), key::movement);
		state.set(session_overworld(state, session), str(key::movement), movement);
	}
}

DictRef _remove_hero_by_id_after_defeat(State &state, const Value &session, Atom hero_id) {
	if (session.kind == Kind::Nil) {
		// normalize_session, commit_active_hero and hero_by_id of a null session do nothing and find no hero.
		const DictRef result = state.new_dict();
		state.set(result, str(key::ok), bool_value(false));
		state.set(result, str(key::message), str(key::empty));
		return result;
	}
	const DictRef view = gd::object_view(state, session);
	hero_command_rules::normalize_session(state, view, key::empty, state.new_dict(), state.new_dict());
	hero_command_rules::commit_active_hero(state, view);
	const DictRef removed_hero = hero_command_rules::hero_by_id(state, view, hero_id);
	if (gd::is_empty(state, removed_hero)) {
		const DictRef result = state.new_dict();
		state.set(result, str(key::ok), bool_value(false));
		state.set(result, str(key::message), str(key::empty));
		return result;
	}
	const ArrayRef remaining = state.new_array();
	for (const Value &hero : gd::field_items(state, session_overworld(state, session), str(key::player_heroes))) {
		if (gd::is_dict(hero) && text_field(state, hero.ref, key::id) != hero_id) {
			state.append(remaining, hero);
		}
	}
	state.set(session_overworld(state, session), str(key::player_heroes), array_value(remaining));
	if (text_field(state, session_overworld(state, session), key::active_hero_id) == hero_id) {
		Atom next_active_id = gd::stringify(state, gd::member(state, session, key::hero_id));
		bool found = false;
		for (const Value &hero : gd::items(state, array_value(remaining))) {
			if (gd::is_dict(hero) && text_field(state, hero.ref, key::id) == next_active_id) {
				found = true;
				break;
			}
		}
		if (!found && state.array_size(remaining) != 0) {
			next_active_id = vtext(state, state.at(remaining, 0), key::id, str(key::empty));
		}
		state.set(session_overworld(state, session), str(key::active_hero_id), str(next_active_id));
		hero_command_rules::_sync_active_hero_mirror(state, view);
	}
	const DictRef result = state.new_dict();
	state.set(result, str(key::ok), bool_value(true));
	const Atom hero_name = text_field(state, removed_hero, key::name, key::the_hero_text);
	state.set(result, str(key::message), str(gd::format(state, key::s_falls_defending_the_town, { str(hero_name) })));
	return result;
}

} // namespace aurelion::rules::port::battle_rules
