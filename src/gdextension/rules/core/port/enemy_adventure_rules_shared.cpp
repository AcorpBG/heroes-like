// EnemyAdventureRules ports shared by the computer players' day (Phase 4) and the
// ends of a battle (Phase 5): a commander's record, name, memory and roster entry,
// and the end of a computer hero's live task.

#include "aurelion_rules/port/enemy_adventure_rules.hpp"

#include "aurelion_rules/port/ai_port.hpp"
#include "aurelion_rules/port/hero_progression_rules.hpp"
#include "aurelion_rules/port/player_identity_rules.hpp"
#include "aurelion_rules/port/spell_rules.hpp"

namespace aurelion::rules::port {

// Defined in Phase 5's files without a header.
namespace enemy_adventure_rules {
ArrayRef normalize_commander_roster(State &state, DictRef session, Atom faction_id, const Value &roster_value);
DictRef build_roster_commander_state(State &state, Atom roster_hero_id, Atom faction_id, DictRef existing_state, const Value &record_source);
DictRef _normalized_commander_record(State &state, const Value &entry_value, const Value &commander_state_value);
DictRef _normalized_commander_memory(State &state, const Value &entry_value, const Value &commander_state_value);
DictRef _normalized_commander_role_state(State &state, const Value &source, const Value &fallback_source);
DictRef _normalized_commander_target_kind_counts(State &state, const Value &value);
DictRef _apply_commander_army_metadata(State &state, DictRef commander_state, const Value &army_source);
DictRef _apply_commander_memory_metadata(State &state, DictRef commander_state, const Value &memory_source);
DictRef _apply_commander_record_metadata(State &state, DictRef commander_state, const Value &record_source);
Atom commander_veterancy_label(State &state, const Value &source);
DictRef commander_army_continuity(State &state, const Value &source);
DictRef _normalize_enemy_progression(State &state, DictRef commander_state);
Atom _normalize_commander_status(State &state, const Value &value);
ArrayRef _merge_unique_strings(State &state, const Value &primary, const Value &secondary);
} // namespace enemy_adventure_rules

namespace {

using gd::array_value;
using gd::ArrayRef;
using gd::Atom;
using gd::dict_value;
using gd::DictRef;
using gd::int_value;
using gd::str;
using state::ContentTable;
using state::State;
using state::Value;
namespace key = state::key;

// d.get(key, {}) and d.get(key, []): a new container when the key is missing.
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

// String(d.get(key, fallback)).
Atom text(State &state, DictRef dict, Atom field, Atom fallback) {
	return gd::stringify(state, state.get(dict, str(field), str(fallback)));
}

// String(d.get(key, fallback)) with an untyped fallback.
Atom text_or(State &state, DictRef dict, Atom field, const Value &fallback) {
	return gd::stringify(state, state.get(dict, str(field), fallback));
}

// max(a, b) of ints.
int64_t imax(int64_t a, int64_t b) {
	return compat::engine_max<int64_t>(a, b);
}

// max(0, int(d.get(key, 0))).
int64_t count_field(State &state, DictRef dict, Atom field) {
	return imax(0, gd::int_field(state, dict, field, 0));
}

// value is Dictionary and not value.is_empty().
bool filled_dict(const State &state, const Value &value) {
	return gd::is_dict(value) && !gd::is_empty(state, value.ref);
}

} // namespace

namespace enemy_adventure_rules {

Atom commander_display_name(State &state, const Value &source, bool include_veterancy) {
	const Atom commander_name = _commander_name_from_source(state, source);
	if (commander_name == key::empty) {
		return key::empty;
	}
	const Atom veterancy = commander_veterancy_label(state, source);
	if (include_veterancy && veterancy != key::empty) {
		return gd::format(state, key::s_s, {str(veterancy), str(commander_name)});
	}
	return commander_name;
}

DictRef commander_target_memory(State &state, const Value &source) {
	return _normalized_commander_memory(state, source, dict_value(state.new_dict()));
}

DictRef _with_runtime_spellbook_state(State &state, DictRef base_state, const Value &runtime_state) {
	if (!gd::is_dict(runtime_state)) {
		return base_state;
	}
	const Value runtime_spellbook = get_or_new_dict(state, runtime_state.ref, key::spellbook);
	if (!gd::is_dict(runtime_spellbook)) {
		return base_state;
	}
	const DictRef updated = gd::deep_duplicate_dict(state, base_state);
	Value spellbook = get_or_new_dict(state, updated, key::spellbook);
	if (!gd::is_dict(spellbook)) {
		spellbook = dict_value(state.new_dict());
	}
	const Value runtime_known = get_or_new_array(state, runtime_spellbook.ref, key::known_spell_ids);
	if (gd::is_array(runtime_known)) {
		const Value known = get_or_new_array(state, spellbook.ref, key::known_spell_ids);
		state.set(spellbook.ref, str(key::known_spell_ids), array_value(_merge_unique_strings(state, known, runtime_known)));
	}
	const Value runtime_mana = get_or_new_dict(state, runtime_spellbook.ref, key::mana);
	if (filled_dict(state, runtime_mana)) {
		const Value existing_mana = get_or_new_dict(state, spellbook.ref, key::mana);
		int64_t max_mana = gd::int_field(state, runtime_mana.ref, key::max, 0);
		if (gd::is_dict(existing_mana)) {
			max_mana = imax(max_mana, gd::int_field(state, existing_mana.ref, key::max, max_mana));
		}
		const int64_t current = compat::engine_clamp<int64_t>(gd::int_field(state, runtime_mana.ref, key::current, max_mana), 0, max_mana);
		const DictRef mana = state.new_dict();
		state.set(mana, str(key::current), int_value(current));
		state.set(mana, str(key::max), int_value(max_mana));
		state.set(spellbook.ref, str(key::mana), dict_value(mana));
	}
	state.set(updated, str(key::spellbook), spellbook);
	return updated;
}

DictRef advance_commander_record(State &state, DictRef commander_state, Atom outcome_id) {
	if (gd::is_empty(state, commander_state)) {
		return state.new_dict();
	}
	DictRef updated = gd::deep_duplicate_dict(state, commander_state);
	const DictRef pre_outcome_memory = _normalized_commander_memory(state, dict_value(updated), dict_value(state.new_dict()));
	const DictRef record = _normalized_commander_record(state, dict_value(state.new_dict()), dict_value(updated));
	state.set(record, str(key::last_outcome), str(outcome_id));
	// record[field] = int(record.get(field, 0)) + 1
	auto count_up = [&](Atom field) {
		state.set(record, str(field), int_value(gd::add(gd::int_field(state, record, field, 0), 1)));
	};
	if (outcome_id == key::deployed) {
		count_up(key::deployments);
		updated = _award_enemy_commander_experience(state, updated, 90);
	} else if (outcome_id == key::field_victory) {
		count_up(key::battle_wins);
		updated = _award_enemy_commander_experience(state, updated, 180);
	} else if (outcome_id == key::pursuit_victory) {
		count_up(key::battle_wins);
		updated = _award_enemy_commander_experience(state, updated, 205);
	} else if (outcome_id == key::capitulation) {
		count_up(key::battle_wins);
		updated = _award_enemy_commander_experience(state, updated, 150);
	} else if (outcome_id == key::rout_victory) {
		count_up(key::battle_wins);
		updated = _award_enemy_commander_experience(state, updated, 230);
	} else if (outcome_id == key::assault_victory) {
		count_up(key::battle_wins);
		updated = _award_enemy_commander_experience(state, updated, 210);
	} else if (outcome_id == key::defeated) {
		count_up(key::times_defeated);
		updated = _award_enemy_commander_experience(state, updated, 45);
	} else if (outcome_id == key::stalemate) {
		updated = _award_enemy_commander_experience(state, updated, 30);
	} else if (outcome_id == key::resource_secured) {
		count_up(key::strategic_successes);
		updated = _award_enemy_commander_experience(state, updated, 70);
	} else if (outcome_id == key::artifact_secured) {
		count_up(key::strategic_successes);
		updated = _award_enemy_commander_experience(state, updated, 100);
	} else if (outcome_id == key::objective_secured) {
		count_up(key::strategic_successes);
		updated = _award_enemy_commander_experience(state, updated, 90);
	} else if (outcome_id == key::town_captured) {
		count_up(key::strategic_successes);
		updated = _award_enemy_commander_experience(state, updated, 90);
	} else if (outcome_id == key::site_defended) {
		count_up(key::strategic_successes);
		updated = _award_enemy_commander_experience(state, updated, 45);
	} else if (outcome_id == key::town_defended) {
		count_up(key::strategic_successes);
		updated = _award_enemy_commander_experience(state, updated, 65);
	} else {
		updated = _normalize_enemy_progression(state, updated);
	}
	if (!gd::is_empty(state, pre_outcome_memory)) {
		state.set(updated, str(key::target_memory), dict_value(pre_outcome_memory));
	}
	state.set(updated, str(key::last_outcome), str(outcome_id));
	updated = _record_commander_adaptive_task_memory(state, updated, outcome_id);
	const DictRef updated_memory = _normalized_commander_memory(state, dict_value(updated), dict_value(state.new_dict()));
	Value spellbook = get_or_new_dict(state, updated, key::spellbook);
	if (!gd::is_dict(spellbook)) {
		spellbook = dict_value(state.new_dict());
	}
	const DictRef hero_template = state.new_dict();
	state.set(hero_template, str(key::command), get_or_new_dict(state, updated, key::command));
	state.set(hero_template, str(key::starting_spell_ids), get_or_new_array(state, spellbook.ref, key::known_spell_ids));
	const DictRef with_spellbook = spell_rules::ensure_hero_spellbook(state, updated, hero_template);
	const DictRef with_memory = _apply_commander_memory_metadata(state, with_spellbook, dict_value(updated_memory));
	const DictRef with_record = _apply_commander_record_metadata(state, with_memory, dict_value(record));
	return _apply_commander_army_metadata(state, with_record, dict_value(updated));
}

void sync_commander_state_to_roster(State &state, DictRef session, Atom faction_id, const Value &commander_state, Atom status_override, Atom active_placement_id, int64_t recovery_day, Atom last_outcome) {
	if (faction_id == key::empty || !gd::is_dict(commander_state)) {
		return;
	}
	const Atom roster_hero_id = text(state, commander_state.ref, key::roster_hero_id, key::empty);
	if (roster_hero_id == key::empty) {
		return;
	}
	const Value states = get_or_new_array(state, session_view::overworld(state, session), key::enemy_states);
	if (!gd::is_array(states)) {
		return;
	}
	const int64_t state_count = state.array_size(states.ref);
	for (int64_t state_index = 0; state_index < state_count; ++state_index) {
		const Value enemy_state = state.at(states.ref, state_index);
		if (!gd::is_dict(enemy_state) || player_identity_rules::controller_id(state, enemy_state.ref, key::empty) != faction_id) {
			continue;
		}
		const ArrayRef roster = normalize_commander_roster(state, session, faction_id, get_or_new_array(state, enemy_state.ref, key::commander_roster));
		const int64_t roster_count = state.array_size(roster);
		for (int64_t roster_index = 0; roster_index < roster_count; ++roster_index) {
			const Value entry_value = state.at(roster, roster_index);
			if (!gd::is_dict(entry_value) || text(state, entry_value.ref, key::roster_hero_id, key::empty) != roster_hero_id) {
				continue;
			}
			const DictRef entry = entry_value.ref;
			const DictRef record = _normalized_commander_record(state, entry_value, commander_state);
			state.set(entry, str(key::deployments), int_value(count_field(state, record, key::deployments)));
			state.set(entry, str(key::battle_wins), int_value(count_field(state, record, key::battle_wins)));
			state.set(entry, str(key::times_defeated), int_value(count_field(state, record, key::times_defeated)));
			state.set(entry, str(key::strategic_successes), int_value(count_field(state, record, key::strategic_successes)));
			state.set(entry, str(key::renown), int_value(count_field(state, record, key::renown)));
			if (status_override != key::empty) {
				state.set(entry, str(key::status), str(_normalize_commander_status(state, str(status_override))));
			}
			if (active_placement_id != key::empty) {
				state.set(entry, str(key::active_placement_id), str(active_placement_id));
			} else if (status_override == key::available || status_override == key::recovering) {
				state.set(entry, str(key::active_placement_id), str(key::empty));
			}
			if (status_override == key::active && recovery_day < 0) {
				state.set(entry, str(key::recovery_day), int_value(0));
			}
			if (recovery_day >= 0) {
				state.set(entry, str(key::recovery_day), int_value(recovery_day));
			}
			if (last_outcome != key::empty) {
				state.set(entry, str(key::last_outcome), str(last_outcome));
			}
			const DictRef synced_commander_state = build_roster_commander_state(state, roster_hero_id, faction_id, commander_state.ref, entry_value);
			state.set(entry, str(key::commander_state), dict_value(_with_runtime_spellbook_state(state, synced_commander_state, commander_state)));
			state.set(entry, str(key::target_memory), dict_value(commander_target_memory(state, get_or_new_dict(state, entry, key::commander_state))));
			state.set(entry, str(key::commander_role_state), dict_value(commander_live_role_state(state, get_or_new_dict(state, entry, key::commander_state))));
			state.set(entry, str(key::army_continuity), dict_value(commander_army_continuity(state, get_or_new_dict(state, entry, key::commander_state))));
			state.set_at(roster, roster_index, entry_value);
			state.set(enemy_state.ref, str(key::commander_roster), array_value(roster));
			state.set_at(states.ref, state_index, enemy_state);
			state.set(session_view::overworld(state, session), str(key::enemy_states), states);
			return;
		}
	}
}

Atom _commander_name_from_source(State &state, const Value &source) {
	if (gd::is_dict(source)) {
		const DictRef record = source.ref;
		const Value commander_state = get_or_new_dict(state, record, key::commander_state);
		if (gd::is_dict(commander_state) && text(state, commander_state.ref, key::name, key::empty) != key::empty) {
			return text(state, commander_state.ref, key::name, key::empty);
		}
		if (text(state, record, key::name, key::empty) != key::empty) {
			return text(state, record, key::name, key::empty);
		}
		if (text(state, record, key::roster_hero_id, key::empty) != key::empty) {
			const DictRef hero = gd::content_row(state, ContentTable::Hero, text(state, record, key::roster_hero_id, key::empty));
			return text(state, hero, key::name, key::empty);
		}
	}
	return key::empty;
}

DictRef _record_commander_adaptive_task_memory(State &state, DictRef commander_state, Atom outcome_id) {
	if (gd::is_empty(state, commander_state) || outcome_id == key::empty) {
		return commander_state;
	}
	const DictRef memory = _normalized_commander_memory(state, dict_value(commander_state), dict_value(state.new_dict()));
	const Atom target_kind = _commander_memory_target_kind_for_outcome(state, outcome_id, memory);
	if (target_kind == key::empty) {
		return _apply_commander_memory_metadata(state, commander_state, dict_value(memory));
	}
	const DictRef updated = gd::deep_duplicate_dict(state, commander_state);
	const DictRef success_counts = _normalized_commander_target_kind_counts(state, get_or_new_dict(state, memory, key::target_success_counts));
	const DictRef failure_counts = _normalized_commander_target_kind_counts(state, get_or_new_dict(state, memory, key::target_failure_counts));
	if (outcome_id == key::defeated) {
		state.set(failure_counts, str(target_kind), int_value(compat::engine_clamp<int64_t>(gd::add(gd::int_field(state, failure_counts, target_kind, 0), 1), 1, 9)));
		state.set(memory, str(key::last_failure_target_kind), str(target_kind));
		state.set(memory, str(key::last_failure_outcome), str(outcome_id));
	} else if (outcome_id == key::deployed || outcome_id == key::stalemate) {
		return _apply_commander_memory_metadata(state, updated, dict_value(memory));
	} else {
		state.set(success_counts, str(target_kind), int_value(compat::engine_clamp<int64_t>(gd::add(gd::int_field(state, success_counts, target_kind, 0), 1), 1, 9)));
		state.set(memory, str(key::last_success_target_kind), str(target_kind));
		state.set(memory, str(key::last_success_outcome), str(outcome_id));
	}
	state.set(memory, str(key::target_success_counts), dict_value(success_counts));
	state.set(memory, str(key::target_failure_counts), dict_value(failure_counts));
	return _apply_commander_memory_metadata(state, updated, dict_value(memory));
}

Atom _commander_memory_target_kind_for_outcome(State &state, Atom outcome_id, DictRef memory) {
	Atom remembered_kind = text(state, memory, key::last_target_kind, key::empty);
	if (remembered_kind == key::empty) {
		remembered_kind = text(state, memory, key::focus_target_kind, key::empty);
	}
	if (remembered_kind == key::resource || remembered_kind == key::town || remembered_kind == key::artifact || remembered_kind == key::encounter || remembered_kind == key::hero) {
		return remembered_kind;
	}
	if (outcome_id == key::resource_secured || outcome_id == key::site_defended) {
		return key::resource;
	}
	if (outcome_id == key::artifact_secured) {
		return key::artifact;
	}
	if (outcome_id == key::town_captured || outcome_id == key::town_defended || outcome_id == key::assault_victory) {
		return key::town;
	}
	if (outcome_id == key::objective_secured) {
		return key::encounter;
	}
	return key::empty;
}

DictRef commander_live_role_state(State &state, const Value &source) {
	return _normalized_commander_role_state(state, source, dict_value(state.new_dict()));
}

DictRef _award_enemy_commander_experience(State &state, DictRef commander_state, int64_t amount) {
	if (amount <= 0) {
		return _normalize_enemy_progression(state, commander_state);
	}
	const DictRef result = hero_progression_rules::add_experience(state, commander_state, amount);
	return _normalize_enemy_progression(state, gd::as_dict(state.get(result, str(key::hero), dict_value(commander_state))));
}

Atom _ai_hero_task_actor_id_from_raid(State &state, DictRef raid) {
	const Value commander_state = get_or_new_dict(state, raid, key::enemy_commander_state);
	if (gd::is_dict(commander_state)) {
		const Atom roster_hero_id = text(state, commander_state.ref, key::roster_hero_id, key::empty);
		if (roster_hero_id != key::empty) {
			return roster_hero_id;
		}
	}
	return text_or(state, raid, key::commander_hero_id, state.get(raid, str(key::placement_id), str(key::empty)));
}

void _ai_hero_task_finish_live_assignment(State &state, DictRef session, Atom faction_id, DictRef raid, Atom task_status, Atom validation) {
	if (faction_id == key::empty || gd::is_empty(state, raid)) {
		return;
	}
	const Atom actor_id = _ai_hero_task_actor_id_from_raid(state, raid);
	const Atom target_kind = text(state, raid, key::target_kind, key::empty);
	const Atom target_id = text(state, raid, key::target_placement_id, key::empty);
	if (actor_id == key::empty || target_kind == key::empty || target_id == key::empty) {
		return;
	}
	const Value listed_states = get_or_new_array(state, session_view::overworld(state, session), key::enemy_states);
	const ArrayRef states = gd::is_array(listed_states) ? listed_states.ref : state.new_array();
	const bool cancelled_finishable = validation == key::invalid_stale_hero_sighting;
	const int64_t state_count = state.array_size(states);
	for (int64_t state_index = 0; state_index < state_count; ++state_index) {
		const Value enemy_state = state.at(states, state_index);
		if (!gd::is_dict(enemy_state) || player_identity_rules::controller_id(state, enemy_state.ref, key::empty) != faction_id) {
			continue;
		}
		const Value task_state_value = get_or_new_dict(state, enemy_state.ref, key::hero_task_state);
		const DictRef task_state = gd::is_dict(task_state_value) ? task_state_value.ref : state.new_dict();
		const Value tasks_value = get_or_new_array(state, task_state, key::tasks);
		const ArrayRef tasks = gd::is_array(tasks_value) ? tasks_value.ref : state.new_array();
		bool changed = false;
		const ArrayRef next_tasks = state.new_array();
		for (const Value &task_value : gd::items(state, array_value(tasks))) {
			if (!gd::is_dict(task_value)) {
				continue;
			}
			DictRef task = task_value.ref;
			bool finishable = text(state, task, key::actor_id, key::empty) == actor_id
					&& text(state, task, key::target_kind, key::empty) == target_kind
					&& text(state, task, key::target_id, key::empty) == target_id;
			if (finishable) {
				const Atom status = text(state, task, key::task_status, key::empty);
				finishable = status == key::planned || status == key::reserved || status == key::active || (cancelled_finishable && status == key::cancelled);
			}
			if (finishable) {
				task = gd::deep_duplicate_dict(state, task);
				state.set(task, str(key::task_status), str(task_status));
				state.set(task, str(key::last_validation), str(validation));
				if (task_status == key::completed && gd::is_dict(get_or_new_dict(state, task, key::reservation))) {
					const DictRef reservation = gd::deep_duplicate_dict(state, gd::as_dict(get_or_new_dict(state, task, key::reservation)));
					if (text(state, reservation, key::reservation_scope, key::empty) == key::exclusive_target) {
						state.set(reservation, str(key::reservation_status), str(key::released));
						state.set(task, str(key::reservation), dict_value(reservation));
					}
				}
				changed = true;
			}
			state.append(next_tasks, dict_value(task));
		}
		if (!changed) {
			return;
		}
		const DictRef next_task_state = state.new_dict();
		state.set(next_task_state, str(key::schema_version), int_value(1));
		state.set(next_task_state, str(key::planner_epoch), int_value(gd::add(count_field(state, task_state, key::planner_epoch), 1)));
		state.set(next_task_state, str(key::tasks), array_value(_ai_hero_task_prune_live_tasks(state, next_tasks, ai::session_int(state, session, key::day))));
		state.set(enemy_state.ref, str(key::hero_task_state), dict_value(next_task_state));
		state.set_at(states, state_index, enemy_state);
		state.set(session_view::overworld(state, session), str(key::enemy_states), array_value(states));
		return;
	}
}

} // namespace enemy_adventure_rules

} // namespace aurelion::rules::port
