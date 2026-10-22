// EnemyAdventureRules: the functions the computer players' day runs (Phase 4): commander records and rosters,
// the AI event records, and what a raid does at a resource site, ported under their GDScript names.

#include "aurelion_rules/port/enemy_adventure_rules_turn.hpp"

#include "aurelion_rules/port/ai_port.hpp"
#include "aurelion_rules/port/artifact_rules_turn.hpp"
#include "aurelion_rules/port/creature_dwelling_rules_turn.hpp"
#include "aurelion_rules/port/hero_command_rules_turn.hpp"
#include "aurelion_rules/port/hero_progression_rules_turn.hpp"
#include "aurelion_rules/port/native_transit_rules.hpp"
#include "aurelion_rules/port/overworld_level_rules.hpp"
#include "aurelion_rules/port/overworld_rules_turn.hpp"
#include "aurelion_rules/port/overworld_turn_playback_turn.hpp"
#include "aurelion_rules/port/player_identity_rules_turn.hpp"
#include "aurelion_rules/port/resource_node_payload_rules_turn.hpp"
#include "aurelion_rules/port/session_view.hpp"
#include "aurelion_rules/port/spell_rules_turn.hpp"
#include "aurelion_rules/port/visit_building_rules_turn.hpp"

#include "aurelion_rules/compat/godot_math.hpp"

#include <string>
#include <vector>

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

// String(record.get("encounter_id", record.get("id", fallback))).
Atom encounter_id_of(State &state, DictRef record, Atom fallback) {
	const Value id = state.get(record, str(key::id), str(fallback));
	return text_or(state, record, key::encounter_id, id);
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

// {"encounter": raid, "state": state, "event_message": ""}.
DictRef unchanged(State &state, DictRef raid, DictRef state_) {
	const DictRef result = state.new_dict();
	state.set(result, str(key::encounter), dict_value(raid));
	state.set(result, str(key::state), dict_value(state_));
	state.set(result, str(key::event_message), str(key::empty));
	return result;
}

// A raid's result with the commander's state synced to the roster:
// sync_commander_state_to_roster(session, faction_id, commander, COMMANDER_STATUS_ACTIVE,
// String(raid.get("placement_id", "")), -1, String(commander.get("last_outcome", COMMANDER_OUTCOME_RESOURCE_SECURED))).
void sync_active_commander(State &state, DictRef session, Atom faction_id, DictRef raid, DictRef commander) {
	const Atom placement_id = text(state, raid, key::placement_id, key::empty);
	const Atom last_outcome = text(state, commander, key::last_outcome, key::resource_secured);
	enemy_adventure_rules::sync_commander_state_to_roster(state, session, faction_id, dict_value(commander), key::active, placement_id, -1, last_outcome);
}

// ", ".join(parts) of Strings.
Atom join_texts(State &state, const std::vector<Atom> &parts) {
	std::string joined;
	for (size_t index = 0; index < parts.size(); ++index) {
		if (index > 0) {
			joined += ", ";
		}
		joined += state.text(parts[index]);
	}
	return state.intern(joined);
}

// text.trim_suffix(suffix).
Atom trim_suffix(State &state, Atom text_atom, Atom suffix) {
	if (!gd::ends_with(state, text_atom, suffix)) {
		return text_atom;
	}
	const std::string &whole = state.text(text_atom);
	const std::string trimmed = whole.substr(0, whole.size() - state.text(suffix).size());
	return state.intern(trimmed);
}

// keys.sort() of an Array of Strings (Godot compares them by code points: UTF-8 byte order).
void sort_texts(State &state, ArrayRef array, const char *where) {
	for (const Value &item : gd::items(state, array_value(array))) {
		if (!gd::is_string(item)) {
			throw state::NotPorted(std::string(where) + ": sort() of keys that are not all Strings");
		}
	}
	gd::sort_custom(state, array, [&state](const Value &a, const Value &b) {
		return gd::text(state, a) < gd::text(state, b);
	});
}

} // namespace

namespace enemy_adventure_rules {

// Defined in enemy_states.cpp (Phase 5) and declared in no header.
ArrayRef normalize_commander_roster(State &state, DictRef session, Atom faction_id, const Value &roster_value);
DictRef build_roster_commander_state(State &state, Atom roster_hero_id, Atom faction_id, DictRef existing_state, const Value &record_source);
DictRef sync_commander_army_continuity(State &state, DictRef commander_state, const Value &army_source, Atom encounter_id);
DictRef _normalized_commander_record(State &state, const Value &entry_value, const Value &commander_state_value);
DictRef _normalized_commander_memory(State &state, const Value &entry_value, const Value &commander_state_value);
DictRef _normalized_commander_role_state(State &state, const Value &source, const Value &fallback_source);
DictRef _normalized_commander_target_kind_counts(State &state, const Value &value);
DictRef _apply_commander_army_metadata(State &state, DictRef commander_state, const Value &army_source);
DictRef _apply_commander_memory_metadata(State &state, DictRef commander_state, const Value &memory_source);
DictRef _apply_commander_record_metadata(State &state, DictRef commander_state, const Value &record_source);
Atom commander_veterancy_label(State &state, const Value &source);
DictRef commander_army_continuity(State &state, const Value &source);
DictRef _base_enemy_army(State &state, Atom encounter_id);
DictRef _normalize_army_payload(State &state, const Value &army);
DictRef _normalize_enemy_progression(State &state, DictRef commander_state);
Atom _normalize_commander_status(State &state, const Value &value);
ArrayRef _merge_unique_strings(State &state, const Value &primary, const Value &secondary);

DictRef _raid_reinforcement_army(State &state, DictRef raid) {
	DictRef army = _normalize_army_payload(state, get_or_new_dict(state, raid, key::enemy_army));
	if (gd::is_empty(state, army) && !gd::bool_field(state, raid, key::commanderless_support_column, false)) {
		// Match ensure_raid_army's restored-commander precedence. Admission must
		// never replace saved troops with the encounter's starter composition.
		const Atom army_id = encounter_id_of(state, raid, key::empty);
		const DictRef continuity = commander_army_continuity(state, get_or_new_dict(state, raid, key::enemy_commander_state));
		const DictRef payload = state.new_dict();
		state.set(payload, str(key::id), str(army_id));
		state.set(payload, str(key::name), str(key::raid_host));
		state.set(payload, str(key::stacks), get_or_new_array(state, continuity, key::stacks));
		army = _normalize_army_payload(state, dict_value(payload));
	}
	if (gd::is_empty(state, army)) {
		army = _base_enemy_army(state, encounter_id_of(state, raid, key::empty));
	}
	return army;
}

DictRef _raid_site_recruit_admission(State &state, DictRef raid, DictRef site) {
	const Value stacks = get_or_new_array(state, _raid_reinforcement_army(state, raid), key::stacks);
	const DictRef additions = _resource_site_claim_recruits(state, site);
	return hero_command_rules::army_addition_split(state, stacks, additions);
}

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

DictRef _record_adventure_objective_success(State &state, DictRef session, Atom faction_id, DictRef raid, Atom outcome_id, Atom active_placement_id) {
	const DictRef updated_raid = gd::deep_duplicate_dict(state, raid);
	const Value commander_state = get_or_new_dict(state, updated_raid, key::enemy_commander_state);
	if (!filled_dict(state, commander_state)) {
		return updated_raid;
	}
	const DictRef updated_commander = advance_commander_record(state, commander_state.ref, outcome_id);
	if (gd::is_dict(state.get(raid, str(key::ai_hero), Value()))) {
		// Heroes earn experience from battles and the rewards they collect, as
		// the human's do, not for the errand itself.
		for (const Atom kept : { key::level, key::experience, key::next_level_experience, key::command, key::specialties, key::pending_specialty_choices, key::specialty_focus_ids, key::spellbook }) {
			if (state.has(commander_state.ref, str(kept))) {
				state.set(updated_commander, str(kept), gd::index(state, commander_state.ref, str(kept)));
			}
		}
	}
	state.set(updated_raid, str(key::enemy_commander_state), dict_value(updated_commander));
	Atom placement_id = active_placement_id;
	if (placement_id == key::empty) {
		placement_id = text(state, updated_raid, key::placement_id, key::empty);
	}
	sync_commander_state_to_roster(state, session, faction_id, dict_value(updated_commander), key::active, placement_id, -1, outcome_id);
	return updated_raid;
}

Atom raid_commander_name(State &state, DictRef encounter) {
	if (gd::is_empty(state, encounter)) {
		return key::empty;
	}
	const Value commander_state = get_or_new_dict(state, encounter, key::enemy_commander_state);
	if (gd::is_dict(commander_state)) {
		const Atom commander_name = text(state, commander_state.ref, key::name, key::empty);
		if (commander_name != key::empty) {
			return commander_name;
		}
	}
	const DictRef encounter_template = gd::content_row(state, ContentTable::Encounter, encounter_id_of(state, encounter, key::empty));
	const Value enemy_commander = get_or_new_dict(state, encounter_template, key::enemy_commander);
	return gd::stringify(state, ai::vget(state, enemy_commander, key::name, str(key::empty)));
}

Atom raid_commander_display_name(State &state, DictRef encounter) {
	if (gd::is_empty(state, encounter)) {
		return key::empty;
	}
	const Value commander_state = get_or_new_dict(state, encounter, key::enemy_commander_state);
	if (filled_dict(state, commander_state)) {
		return commander_display_name(state, commander_state, true);
	}
	return raid_commander_name(state, encounter);
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

int64_t _commander_map_level(State &state, const Value &source) {
	if (gd::is_dict(source) && (state.has(source.ref, str(key::position)) || (state.has(source.ref, str(key::x)) && state.has(source.ref, str(key::y))))) {
		return overworld_level_rules::level_of(state, source);
	}
	return 0;
}

DictRef build_ai_event_record(State &state, DictRef session, DictRef config, Atom event_type, DictRef actor, DictRef target, DictRef options) {
	const Atom raid_controller = player_identity_rules::raid_controller_id(state, actor);
	const Atom config_controller = player_identity_rules::controller_id(state, config, raid_controller);
	const Atom faction_id = player_identity_rules::controller_id(state, options, config_controller);
	const Atom faction_label = text_or(state, options, key::faction_label, state.get(config, str(key::label), str(faction_id)));
	const Value actor_fallback_id = state.get(actor, str(key::placement_id), state.get(actor, str(key::id), str(key::empty)));
	const Atom actor_id = text_or(state, options, key::actor_id, actor_fallback_id);
	const Value actor_fallback_label = state.has(actor, str(key::encounter_id)) ? str(_raid_name(state, actor)) : state.get(actor, str(key::name), str(actor_id));
	const Atom actor_label = text_or(state, options, key::actor_label, actor_fallback_label);
	const Atom target_kind = text_or(state, options, key::target_kind, state.get(target, str(key::target_kind), str(key::empty)));
	const Value target_fallback_id = state.get(target, str(key::target_placement_id), state.get(target, str(key::placement_id), str(key::empty)));
	const Atom target_id = text_or(state, options, key::target_id, target_fallback_id);
	const Value target_fallback_label = state.get(target, str(key::target_label), state.get(target, str(key::name), str(target_id)));
	const Atom target_label = text_or(state, options, key::target_label, target_fallback_label);
	const Value target_fallback_x = state.get(target, str(key::target_x), state.get(target, str(key::x), int_value(0)));
	const int64_t target_x = gd::to_int(state, state.get(options, str(key::target_x), target_fallback_x));
	const Value target_fallback_y = state.get(target, str(key::target_y), state.get(target, str(key::y), int_value(0)));
	const int64_t target_y = gd::to_int(state, state.get(options, str(key::target_y), target_fallback_y));
	ArrayRef reason_codes = _normalize_string_array(state, state.get(options, str(key::reason_codes), get_or_new_array(state, target, key::target_reason_codes)));
	if (state.array_size(reason_codes) == 0) {
		reason_codes = _default_reason_codes_for_target(state, target_kind, target_id, target);
	}
	const Value target_public_reason = state.get(target, str(key::target_public_reason), str(_public_reason_from_codes(state, reason_codes)));
	Atom public_reason = text_or(state, options, key::public_reason, target_public_reason);
	if (public_reason == key::empty) {
		public_reason = _public_reason_from_codes(state, reason_codes);
	}
	const Atom debug_reason = text_or(state, options, key::debug_reason, state.get(target, str(key::target_debug_reason), str(public_reason)));
	const Value target_importance = state.get(target, str(key::target_public_importance), str(_default_public_importance(state, target_kind, reason_codes)));
	const Atom importance = text_or(state, options, key::public_importance, target_importance);
	const int64_t actor_level = _commander_map_level(state, dict_value(actor));
	const int64_t target_level = _target_level(state, session, target_kind, target_id, faction_id, actor_level);
	const Atom default_visibility = _event_visibility(state, session, target_x, target_y, importance, target_level);
	const Atom visibility = text_or(state, options, key::visibility, str(default_visibility));
	Atom summary = text(state, options, key::summary, key::empty);
	if (summary == key::empty) {
		const Atom summary_prefix = text(state, options, key::summary_prefix, key::empty);
		summary = _ai_event_summary(state, event_type, faction_label, actor_label, target_label, public_reason, summary_prefix);
	}
	const int64_t day = ai::session_int(state, session, key::day);
	const Atom event_id = gd::format(state, key::d_s_s_s_s, { int_value(day), str(faction_id), str(event_type), str(actor_id), str(target_id) });
	const DictRef event = state.new_dict();
	state.set(event, str(key::event_id), str(event_id));
	state.set(event, str(key::day), int_value(ai::session_int(state, session, key::day)));
	state.set(event, str(key::sequence), int_value(gd::int_field(state, options, key::sequence, 0)));
	state.set(event, str(key::event_type), str(event_type));
	state.set(event, str(key::faction_id), str(player_identity_rules::faction_id(state, session, faction_id)));
	state.set(event, str(key::player_id), str(text(state, player_identity_rules::player(state, session, faction_id), key::player_id, key::empty)));
	state.set(event, str(key::faction_label), str(faction_label));
	state.set(event, str(key::actor_id), str(actor_id));
	state.set(event, str(key::actor_label), str(actor_label));
	state.set(event, str(key::target_kind), str(target_kind));
	state.set(event, str(key::target_id), str(target_id));
	state.set(event, str(key::target_label), str(target_label));
	state.set(event, str(key::target_x), int_value(target_x));
	state.set(event, str(key::target_y), int_value(target_y));
	state.set(event, str(key::visibility), str(visibility));
	state.set(event, str(key::public_importance), str(importance));
	state.set(event, str(key::summary), str(summary));
	state.set(event, str(key::reason_codes), array_value(reason_codes));
	state.set(event, str(key::public_reason), str(public_reason));
	state.set(event, str(key::debug_reason), str(debug_reason));
	state.set(event, str(key::state_policy), str(text(state, options, key::state_policy, key::ephemeral)));
	if (state.has(options, str(key::goal_distance_before))) {
		state.set(event, str(key::goal_distance_before), int_value(gd::int_field(state, options, key::goal_distance_before, 9999)));
	}
	if (state.has(options, str(key::goal_distance_after))) {
		state.set(event, str(key::goal_distance_after), int_value(gd::int_field(state, options, key::goal_distance_after, 9999)));
	}
	if (state.has(options, str(key::target_controller_before))) {
		state.set(event, str(key::target_controller_before), str(text(state, options, key::target_controller_before, key::empty)));
	}
	if (state.has(options, str(key::target_controller_after))) {
		state.set(event, str(key::target_controller_after), str(text(state, options, key::target_controller_after, key::empty)));
	}
	if (state.has(options, str(key::learned_spell_id)) && text(state, options, key::learned_spell_id, key::empty) != key::empty) {
		state.set(event, str(key::learned_spell_id), str(text(state, options, key::learned_spell_id, key::empty)));
		const Value learned_spell_id = state.get(options, str(key::learned_spell_id), str(key::empty));
		state.set(event, str(key::learned_spell_name), str(text_or(state, options, key::learned_spell_name, learned_spell_id)));
	}
	return event;
}

int64_t _resource_route_pressure_value(State &state, DictRef site) {
	int64_t value = 0;
	value = gd::add(value, gd::mul(count_field(state, site, key::vision_radius), 8));
	value = gd::add(value, gd::mul(count_field(state, site, key::pressure_guard), 12));
	value = gd::add(value, gd::mul(count_field(state, site, key::pressure_bonus), 14));
	const Atom family = text(state, site, key::family, key::empty);
	if (family == key::faction_outpost || family == key::frontier_shrine) {
		value = gd::add(value, 12);
	}
	const double support = static_cast<double>(_resource_site_support_value(state, site)) / 45.0;
	const compat::Number capped = compat::variant_min({ compat::Number::of_float(30.0), compat::Number::of_float(support) });
	value = gd::add(value, compat::float_to_int(capped.as_double()));
	return value;
}

ArrayRef _resource_target_reason_codes(State &state, DictRef site, bool player_controlled, bool persistent, int64_t income_value, int64_t recruit_payload_value, int64_t route_pressure_value, int64_t town_enablement_value, int64_t scarcity_value) {
	const ArrayRef codes = state.new_array();
	if (scarcity_value > 0) {
		state.append(codes, str(key::resource_scarcity));
	}
	if (player_controlled && persistent && income_value > 0) {
		state.append(codes, str(key::persistent_income_denial));
	}
	if (recruit_payload_value > 0) {
		state.append(codes, str(key::recruit_denial));
	}
	if (route_pressure_value > 0) {
		if (count_field(state, site, key::vision_radius) > 0) {
			state.append(codes, str(key::route_vision));
		} else {
			state.append(codes, str(key::route_pressure));
		}
	}
	if (town_enablement_value > 0) {
		state.append(codes, str(key::player_town_support));
	}
	if (state.array_size(codes) == 0) {
		state.append(codes, str(key::route_pressure));
	}
	return codes;
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

Atom _default_public_importance(State &state, Atom target_kind, ArrayRef reason_codes) {
	auto has = [&](Atom code) {
		return gd::array_has(state, reason_codes, str(code));
	};
	if (target_kind == key::town || has(key::town_siege)) {
		return key::critical;
	}
	if (has(key::persistent_income_denial) || has(key::recruit_denial) || has(key::objective_front)) {
		return key::high;
	}
	if (has(key::site_seized) || has(key::site_contested)) {
		return key::medium;
	}
	if (target_kind == key::explore || has(key::frontier_scouting)) {
		return key::medium;
	}
	return key::low;
}

Atom _event_visibility(State &state, DictRef session, int64_t x, int64_t y, Atom public_importance, int64_t level) {
	if (overworld_rules::is_tile_visible(state, session, x, y, level)) {
		return key::visible;
	}
	if (overworld_rules::is_tile_explored(state, session, x, y, level)) {
		return key::scouted;
	}
	if (public_importance == key::critical || public_importance == key::high) {
		return key::rumored;
	}
	return key::hidden_debug;
}

int64_t _linked_player_town_bonus(State &state, DictRef session, DictRef node) {
	DictRef linked_town = 0;
	bool linked = false;
	int64_t best_distance = 9999;
	for (const Value &town : gd::field_items(state, session_view::overworld(state, session), str(key::towns))) {
		if (!gd::is_dict(town) || text(state, town.ref, key::owner, key::neutral) != key::player) {
			continue;
		}
		const int64_t support_radius = overworld_rules::town_logistics_support_radius(state, session, town.ref);
		const int64_t distance = gd::add(compat::absi(gd::sub(gd::int_field(state, node, key::x, 0), gd::int_field(state, town.ref, key::x, 0))), compat::absi(gd::sub(gd::int_field(state, node, key::y, 0), gd::int_field(state, town.ref, key::y, 0))));
		if (distance > support_radius) {
			continue;
		}
		if (distance < best_distance) {
			best_distance = distance;
			linked_town = town.ref;
			linked = true;
		}
	}
	if (!linked || gd::is_empty(state, linked_town)) {
		return 0;
	}
	int64_t bonus = 0;
	const Atom role = overworld_rules::town_strategic_role(state, linked_town);
	if (role == key::capital) {
		bonus = gd::add(bonus, 35);
	} else if (role == key::stronghold) {
		bonus = gd::add(bonus, 18);
	}
	const DictRef recovery = overworld_rules::town_recovery_state(state, session, linked_town);
	bonus = gd::add(bonus, gd::mul(gd::int_field(state, recovery, key::pressure, 0), 8));
	const DictRef capital_project = overworld_rules::town_capital_project_state(state, linked_town, dict_value(session));
	if (gd::bool_field(state, capital_project, key::active, false)) {
		bonus = gd::add(bonus, 18);
	}
	if (gd::bool_field(state, capital_project, key::vulnerable, false)) {
		bonus = gd::add(bonus, 22);
	}
	return bonus;
}

int64_t _target_resource_value(State &state, const Value &rewards) {
	if (!gd::is_dict(rewards)) {
		return 0;
	}
	// AI_RESOURCE_VALUE_BY_ID, in its order.
	struct ResourceValue {
		Atom id;
		int64_t value;
	};
	const ResourceValue values[] = {
		{ key::gold, 1 },
		{ key::wood, 350 },
		{ key::ore, 350 },
		{ key::aetherglass, 700 },
		{ key::embergrain, 700 },
		{ key::peatwax, 700 },
		{ key::verdant_grafts, 700 },
		{ key::brass_scrip, 700 },
		{ key::memory_salt, 700 },
		{ key::experience, 1 },
	};
	int64_t total = 0;
	for (const ResourceValue &entry : values) {
		total = gd::add(total, gd::mul(count_field(state, rewards.ref, entry.id), entry.value));
	}
	return total;
}

DictRef _secure_resource_target(State &state, DictRef session, DictRef raid, DictRef state_, Atom faction_id, DictRef config) {
	const DictRef node_result = _find_resource_by_placement(state, session, text(state, raid, key::target_placement_id, key::empty));
	Value node = get_or_new_dict(state, node_result, key::node);
	const int64_t node_index = gd::int_field(state, node_result, key::index, -1);
	if (node_index < 0) {
		return unchanged(state, raid, state_);
	}
	if (native_transit_rules::is_native(state, gd::as_dict(node))) {
		return _secure_native_passage_target(state, session, raid, state_, faction_id, gd::as_dict(node), false);
	}
	const DictRef site = resource_node_payload_rules::site_for_node(state, gd::as_dict(node), state.new_dict());
	if (!gd::is_empty(state, overworld_rules::resource_site_blocking_guard(state, session, gd::as_dict(node), site))) {
		return unchanged(state, raid, state_);
	}
	if (!_resource_node_contestable_by_faction(state, gd::as_dict(node), site, faction_id, dict_value(session))) {
		if (player_identity_rules::resource_controller_id(state, gd::as_dict(node)) == faction_id) {
			_ai_hero_task_finish_live_assignment(state, session, faction_id, raid, key::completed, key::valid);
		}
		return unchanged(state, raid, state_);
	}
	if (visit_building_rules::is_visit_building(state, site)) {
		return _visit_building_by_raid(state, session, raid, state_, faction_id, node_result, site, config);
	}
	if (creature_dwelling_rules::is_dwelling(state, site)) {
		if (!_break_dwelling_guard_by_raid(state, session, raid, faction_id, node_index, site)) {
			_ai_hero_task_finish_live_assignment(state, session, faction_id, raid, key::failed, key::invalid_dwelling_guard);
			return unchanged(state, raid, state_);
		}
		node = ai::vindex(state, get_or_new_array(state, session_view::overworld(state, session), key::resource_nodes), int_value(node_index));
		if (player_identity_rules::resource_controller_id(state, gd::as_dict(node)) == faction_id) {
			return _hire_at_own_dwelling_by_raid(state, session, raid, state_, faction_id, node_index, site, config);
		}
	}
	const DictRef node_dict = gd::as_dict(node);
	const Value nodes = get_or_new_array(state, session_view::overworld(state, session), key::resource_nodes);
	const DictRef previous_node = gd::deep_duplicate_dict(state, node_dict);
	const Atom previous_controller = player_identity_rules::resource_controller_id(state, node_dict);
	const bool escorted_route = gd::int_field(state, previous_node, key::response_until_day, 0) >= ai::session_int(state, session, key::day);
	const int64_t delivery_value = _recruit_payload_value(state, get_or_new_dict(state, previous_node, key::delivery_manifest));
	Atom delivery_target_label = text(state, previous_node, key::delivery_target_label, key::the_front);
	if (delivery_target_label == key::empty) {
		delivery_target_label = key::the_front;
	}
	state.set(node_dict, str(key::collected), bool_value(true));
	player_identity_rules::set_resource_controller(state, node_dict, dict_value(session), faction_id);
	state.set(node_dict, str(key::collected_day), int_value(ai::session_int(state, session, key::day)));
	resource_node_payload_rules::mark_claimed(state, node_dict, site);
	state.set(node_dict, str(key::response_origin), str(key::empty));
	state.set(node_dict, str(key::response_source_town_id), str(key::empty));
	state.set(node_dict, str(key::response_last_day), int_value(0));
	state.set(node_dict, str(key::response_until_day), int_value(0));
	state.set(node_dict, str(key::response_commander_id), str(key::empty));
	state.set(node_dict, str(key::response_security_rating), int_value(0));
	state.set(node_dict, str(key::delivery_controller_id), str(key::empty));
	state.set(node_dict, str(key::delivery_origin_town_id), str(key::empty));
	state.set(node_dict, str(key::delivery_target_kind), str(key::empty));
	state.set(node_dict, str(key::delivery_target_id), str(key::empty));
	state.set(node_dict, str(key::delivery_target_label), str(key::empty));
	state.set(node_dict, str(key::delivery_arrival_day), int_value(0));
	state.set(node_dict, str(key::delivery_manifest), dict_value(state.new_dict()));
	state.set_at(gd::as_array(nodes), node_index, node);
	state.set(session_view::overworld(state, session), str(key::resource_nodes), nodes);

	const DictRef spoils = _reward_resources_for_empire(state, dict_value(_resource_site_claim_rewards(state, site)));
	state.set(state_, str(key::treasury), dict_value(_merge_resources(state, get_or_new_dict(state, state_, key::treasury), dict_value(spoils))));
	DictRef updated_raid = _record_adventure_objective_success(state, session, faction_id, raid, key::resource_secured, key::empty);
	const DictRef recruit_reward = _apply_resource_site_claim_recruits_to_raid(state, session, faction_id, updated_raid, site);
	updated_raid = gd::as_dict(state.get(recruit_reward, str(key::raid), dict_value(updated_raid)));
	if (creature_dwelling_rules::is_dwelling(state, site)) {
		const DictRef hire = _hire_dwelling_creatures_into_raid(state, session, faction_id, updated_raid, node_index, site, state_);
		updated_raid = gd::as_dict(state.get(hire, str(key::raid), dict_value(updated_raid)));
	}
	const DictRef spell_reward = _apply_resource_site_spell_reward_to_commander(state, session, faction_id, updated_raid, site);
	updated_raid = gd::as_dict(state.get(spell_reward, str(key::raid), dict_value(updated_raid)));
	// Experience in the claim (a Pandora's Box) goes to the hero, as the
	// human's hero gets it.
	const int64_t claim_experience = imax(0, gd::int_field(state, _resource_site_claim_rewards(state, site), key::experience, 0));
	const Value claim_commander = get_or_new_dict(state, updated_raid, key::enemy_commander_state);
	const bool experience_gained = claim_experience > 0 && filled_dict(state, claim_commander);
	if (experience_gained) {
		const DictRef experienced = hero_progression_rules::add_experience(state, claim_commander.ref, claim_experience);
		const DictRef progressed = _normalize_enemy_progression(state, gd::as_dict(state.get(experienced, str(key::hero), claim_commander)));
		state.set(updated_raid, str(key::enemy_commander_state), dict_value(progressed));
	}
	const DictRef artifact_reward = _apply_resource_site_artifact_reward_to_raid(state, session, faction_id, updated_raid, node_dict, site);
	updated_raid = gd::as_dict(state.get(artifact_reward, str(key::raid), dict_value(updated_raid)));
	if (gd::bool_field(state, artifact_reward, key::applied, false)) {
		const Atom artifact_id = text(state, artifact_reward, key::artifact_id, key::empty);
		const ArrayRef captured_artifacts = _normalize_string_array(state, get_or_new_array(state, state_, key::captured_artifact_ids));
		// artifact_reward.get("artifact_ids", [artifact_id])
		Value artifact_ids;
		if (!state.lookup(artifact_reward, str(key::artifact_ids), artifact_ids)) {
			const ArrayRef single = state.new_array();
			state.append(single, str(artifact_id));
			artifact_ids = array_value(single);
		}
		for (const Value &captured_id : gd::items(state, artifact_ids)) {
			const Atom captured = gd::stringify(state, captured_id);
			if (!gd::array_has(state, captured_artifacts, str(captured))) {
				state.append(captured_artifacts, str(gd::stringify(state, captured_id)));
			}
		}
		state.set(state_, str(key::captured_artifact_ids), array_value(captured_artifacts));
		state.set(node_dict, str(key::artifact_reward_id), str(artifact_id));
		Value reward_ids;
		if (!state.lookup(artifact_reward, str(key::artifact_ids), reward_ids)) {
			const ArrayRef single = state.new_array();
			state.append(single, str(artifact_id));
			reward_ids = array_value(single);
		}
		state.set(node_dict, str(key::artifact_reward_ids), gd::duplicate_value(state, reward_ids, false));
		state.set(node_dict, str(key::artifact_reward_table_id), str(text(state, artifact_reward, key::table_id, key::empty)));
		state.set(node_dict, str(key::artifact_reward_source_key), str(text(state, artifact_reward, key::source_key, key::empty)));
		state.set(node_dict, str(key::artifact_reward_claimed_by_faction_id), str(player_identity_rules::faction_id(state, session, faction_id)));
		state.set(node_dict, str(key::artifact_reward_claimed_by_player_id), str(text(state, player_identity_rules::player(state, session, faction_id), key::player_id, key::empty)));
		state.set(node_dict, str(key::artifact_reward_claimed_day), int_value(ai::session_int(state, session, key::day)));
		state.set_at(gd::as_array(nodes), node_index, node);
		state.set(session_view::overworld(state, session), str(key::resource_nodes), nodes);
	}
	Atom message = gd::format(state, key::s_seizes_s, { str(_raid_name(state, updated_raid)), str(text(state, site, key::name, key::the_site)) });
	overworld_turn_playback::action(state, dict_value(session), updated_raid, key::seizes_a_resource_site);
	if (!gd::is_empty(state, spoils)) {
		const Atom raid_name = _raid_name(state, updated_raid);
		const Atom site_name = text(state, site, key::name, key::the_site);
		message = gd::format(state, key::s_claims_s_and_collects_s, { str(raid_name), str(site_name), str(_describe_resource_set(state, spoils)) });
	}
	if (delivery_value > 0) {
		message = gd::format(state, key::s_the_convoy_bound_for_s, { str(trim_suffix(state, message, key::period)), str(delivery_target_label) });
	} else if (escorted_route) {
		const Atom raid_name = _raid_name(state, updated_raid);
		message = gd::format(state, key::s_seizes_s_and_breaks_its, { str(raid_name), str(text(state, site, key::name, key::the_site)) });
	} else if (_resource_site_is_persistent(state, site)) {
		const Atom raid_name = _raid_name(state, updated_raid);
		message = gd::format(state, key::s_seizes_s_and_denies_its, { str(raid_name), str(text(state, site, key::name, key::the_site)) });
	}
	if (gd::bool_field(state, spell_reward, key::learned, false)) {
		const Atom commander_name = raid_commander_display_name(state, updated_raid);
		const Atom spell_name = text_or(state, spell_reward, key::spell_name, state.get(spell_reward, str(key::spell_id), str(key::the_site_spell)));
		message = gd::format(state, key::s_s_learns_s, { str(message), str(commander_name), str(spell_name) });
	}
	if (gd::bool_field(state, recruit_reward, key::applied, false)) {
		const Atom commander_name = raid_commander_display_name(state, updated_raid);
		const Atom recruits = _describe_recruit_set(state, get_or_new_dict(state, recruit_reward, key::recruits));
		message = gd::format(state, key::s_auxiliaries_join_s_s, { str(message), str(commander_name), str(recruits) });
	}
	if (experience_gained) {
		const Atom commander_name = raid_commander_display_name(state, updated_raid);
		message = gd::format(state, key::s_s_gains_d_experience, { str(message), str(commander_name), int_value(claim_experience) });
	}
	if (gd::bool_field(state, artifact_reward, key::applied, false)) {
		std::vector<Atom> artifact_names;
		// artifact_reward.get("artifact_ids", [artifact_reward.get("artifact_id", "")])
		Value artifact_ids;
		if (!state.lookup(artifact_reward, str(key::artifact_ids), artifact_ids)) {
			const ArrayRef single = state.new_array();
			state.append(single, state.get(artifact_reward, str(key::artifact_id), str(key::empty)));
			artifact_ids = array_value(single);
		}
		for (const Value &artifact_id : gd::items(state, artifact_ids)) {
			artifact_names.push_back(artifact_rules::describe_artifact(state, gd::stringify(state, artifact_id)));
		}
		const Atom commander_name = raid_commander_display_name(state, updated_raid);
		message = gd::format(state, key::s_s_secures_and_equips_s, { str(message), str(commander_name), str(join_texts(state, artifact_names)) });
	}
	const Atom disruption_message = overworld_rules::apply_resource_site_disruption(state, session, previous_node, site, previous_controller, faction_id);
	if (disruption_message != key::empty) {
		message = gd::format(state, key::s_s, { str(message), str(disruption_message) });
	}
	const ArrayRef seized_codes = state.new_array();
	state.append(seized_codes, str(key::site_seized));
	if (escorted_route) {
		state.append(seized_codes, str(key::route_closed));
	}
	const bool player_controlled = previous_controller == key::player;
	const bool persistent = _resource_site_is_persistent(state, site);
	const int64_t income_value = _target_resource_value(state, get_or_new_dict(state, site, key::control_income));
	const int64_t claim_recruit_value = _recruit_payload_value(state, get_or_new_dict(state, site, key::claim_recruits));
	const int64_t weekly_recruit_value = _recruit_payload_value(state, get_or_new_dict(state, site, key::weekly_recruits));
	const int64_t route_pressure_value = _resource_route_pressure_value(state, site);
	const int64_t town_enablement_value = _linked_player_town_bonus(state, session, previous_node);
	const ArrayRef reason_codes = _resource_target_reason_codes(state, site, player_controlled, persistent, income_value, gd::add(claim_recruit_value, weekly_recruit_value), route_pressure_value, town_enablement_value, 0);
	ai::append_array(state, seized_codes, reason_codes);
	const DictRef event_config = !gd::is_empty(state, config) ? config : player_identity_rules::config_for_controller(state, dict_value(session), faction_id);
	const DictRef target = state.new_dict();
	state.set(target, str(key::target_kind), str(key::resource));
	state.set(target, str(key::target_placement_id), str(text(state, updated_raid, key::target_placement_id, key::empty)));
	state.set(target, str(key::target_label), str(text(state, site, key::name, key::the_site)));
	state.set(target, str(key::target_x), int_value(gd::int_field(state, node_dict, key::x, 0)));
	state.set(target, str(key::target_y), int_value(gd::int_field(state, node_dict, key::y, 0)));
	state.set(target, str(key::target_reason_codes), array_value(seized_codes));
	state.set(target, str(key::target_public_reason), str(_public_reason_from_codes(state, seized_codes)));
	const bool high_importance = previous_controller == key::player || _resource_site_is_persistent(state, site);
	state.set(target, str(key::target_public_importance), str(high_importance ? key::high : key::medium));
	state.set(target, str(key::target_debug_reason), str(text(state, updated_raid, key::target_debug_reason, key::empty)));
	const DictRef options = state.new_dict();
	state.set(options, str(key::summary), str(message));
	state.set(options, str(key::state_policy), str(key::durable_state_reference));
	state.set(options, str(key::target_controller_before), str(previous_controller));
	state.set(options, str(key::target_controller_after), str(faction_id));
	state.set(options, str(key::learned_spell_id), str(text(state, spell_reward, key::spell_id, key::empty)));
	state.set(options, str(key::learned_spell_name), str(text(state, spell_reward, key::spell_name, key::empty)));
	state.set(options, str(key::artifact_reward_id), str(text(state, artifact_reward, key::artifact_id, key::empty)));
	state.set(options, str(key::artifact_reward_table_id), str(text(state, artifact_reward, key::table_id, key::empty)));
	const DictRef event = build_ai_event_record(state, session, event_config, key::ai_site_seized, updated_raid, target, options);
	_ai_hero_task_finish_live_assignment(state, session, faction_id, updated_raid, key::completed, key::valid);
	// The hero picks its next errand itself (AiHeroRules).
	if (gd::bool_field(state, spell_reward, key::learned, false) || gd::bool_field(state, artifact_reward, key::applied, false) || experience_gained) {
		const Value final_commander = get_or_new_dict(state, updated_raid, key::enemy_commander_state);
		if (filled_dict(state, final_commander)) {
			sync_active_commander(state, session, faction_id, updated_raid, final_commander.ref);
		}
	}
	const ArrayRef ai_events = state.new_array();
	state.append(ai_events, dict_value(event));
	const DictRef result = state.new_dict();
	state.set(result, str(key::encounter), dict_value(updated_raid));
	state.set(result, str(key::state), dict_value(state_));
	state.set(result, str(key::event_message), str(message));
	state.set(result, str(key::ai_events), array_value(ai_events));
	state.set(result, str(key::artifact_reward), dict_value(artifact_reward));
	return result;
}

DictRef _visit_building_by_raid(State &state, DictRef session, DictRef raid, DictRef state_, Atom faction_id, DictRef node_result, DictRef site, DictRef _config) {
	(void)_config;
	const ArrayRef nodes = gd::as_array(get_or_new_array(state, session_view::overworld(state, session), key::resource_nodes));
	const int64_t index = gd::int_field(state, node_result, key::index, -1);
	if (index < 0 || index >= state.array_size(nodes)) {
		return unchanged(state, raid, state_);
	}
	const DictRef node = gd::as_dict(state.at(nodes, index));
	// The human's rule: some buildings serve only seasoned heroes.
	const Value raid_commander = get_or_new_dict(state, raid, key::enemy_commander_state);
	if (gd::to_int(state, ai::vget(state, raid_commander, key::level, int_value(1))) < visit_building_rules::required_level(state, site)) {
		return unchanged(state, raid, state_);
	}
	Atom choice_id = key::empty;
	const ArrayRef options = visit_building_rules::choices(state, site);
	if (state.array_size(options) != 0 && gd::is_dict(state.at(options, 0))) {
		choice_id = gd::stringify(state, ai::vget(state, state.at(options, 0), key::id, str(key::empty)));
	}
	const DictRef price = visit_building_rules::cost(state, site, choice_id);
	const Value treasury_value = get_or_new_dict(state, state_, key::treasury);
	const DictRef treasury = gd::is_dict(treasury_value) ? treasury_value.ref : state.new_dict();
	for (const Value &resource : gd::items(state, dict_value(price))) {
		if (gd::to_int(state, state.get(treasury, resource, int_value(0))) < gd::to_int(state, gd::index(state, price, resource))) {
			_ai_hero_task_finish_live_assignment(state, session, faction_id, raid, key::completed, key::valid);
			return unchanged(state, raid, state_);
		}
	}
	for (const Value &resource : gd::items(state, dict_value(price))) {
		const int64_t left = gd::sub(gd::to_int(state, state.get(treasury, resource, int_value(0))), gd::to_int(state, gd::index(state, price, resource)));
		state.set(treasury, resource, int_value(left));
	}
	state.set(state_, str(key::treasury), dict_value(treasury));
	visit_building_rules::record_visit(state, node, site, _visit_key(state, faction_id), ai::session_int(state, session, key::day), key::empty);
	state.set_at(nodes, index, dict_value(node));
	state.set(session_view::overworld(state, session), str(key::resource_nodes), array_value(nodes));
	const DictRef effect = visit_building_rules::effects(state, site, choice_id);
	DictRef updated_raid = _record_adventure_objective_success(state, session, faction_id, raid, key::resource_secured, key::empty);
	Value commander = get_or_new_dict(state, updated_raid, key::enemy_commander_state);
	bool commander_changed = false;
	if (filled_dict(state, commander)) {
		const Value stats = get_or_new_dict(state, effect, key::stats);
		if (filled_dict(state, stats)) {
			Value command = get_or_new_dict(state, commander.ref, key::command);
			if (!gd::is_dict(command)) {
				command = dict_value(state.new_dict());
			}
			// VisitBuildingRules.STAT_KEYS
			for (const Atom stat : { key::attack, key::defense, key::power, key::knowledge }) {
				if (gd::int_field(state, stats.ref, stat, 0) != 0) {
					const int64_t raised = gd::add(gd::int_field(state, command.ref, stat, 0), gd::int_field(state, stats.ref, stat, 0));
					state.set(command.ref, str(stat), int_value(imax(0, raised)));
				}
			}
			state.set(commander.ref, str(key::command), command);
			commander_changed = true;
		}
		int64_t experience = imax(0, gd::int_field(state, effect, key::experience, 0));
		const int64_t levels = imax(0, gd::int_field(state, effect, key::levels, 0));
		for (int64_t level = 0; level < levels; ++level) {
			const DictRef progression = hero_progression_rules::ensure_hero_progression(state, gd::deep_duplicate_dict(state, commander.ref));
			const int64_t missing = gd::sub(gd::int_field(state, progression, key::next_level_experience, 250), gd::int_field(state, progression, key::experience, 0));
			experience = gd::add(experience, imax(1, missing));
		}
		if (experience > 0) {
			const DictRef experienced = hero_progression_rules::add_experience(state, gd::as_dict(commander), experience);
			commander = state.get(experienced, str(key::hero), commander);
			commander_changed = true;
		}
		state.set(updated_raid, str(key::enemy_commander_state), commander);
	}
	if (gd::int_field(state, effect, key::spell_tier, 0) > 0) {
		const DictRef spell_reward = _apply_resource_site_spell_reward_to_commander(state, session, faction_id, updated_raid, site);
		updated_raid = gd::as_dict(state.get(spell_reward, str(key::raid), dict_value(updated_raid)));
		commander_changed = commander_changed || gd::bool_field(state, spell_reward, key::learned, false);
	}
	const Atom effect_text = visit_building_rules::effect_summary(state, effect);
	const Atom raid_name = _raid_name(state, updated_raid);
	const Atom site_name = text(state, site, key::name, key::a_building);
	const Atom effect_suffix = effect_text != key::empty ? gd::format(state, key::s_3, { str(effect_text) }) : key::empty;
	const Atom message = gd::format(state, key::s_visits_s_s, { str(raid_name), str(site_name), str(effect_suffix) });
	overworld_turn_playback::action(state, dict_value(session), updated_raid, key::visits_a_building);
	_ai_hero_task_finish_live_assignment(state, session, faction_id, updated_raid, key::completed, key::valid);
	if (commander_changed) {
		const Value final_commander = get_or_new_dict(state, updated_raid, key::enemy_commander_state);
		if (filled_dict(state, final_commander)) {
			sync_active_commander(state, session, faction_id, updated_raid, final_commander.ref);
		}
	}
	const DictRef result = state.new_dict();
	state.set(result, str(key::encounter), dict_value(updated_raid));
	state.set(result, str(key::state), dict_value(state_));
	state.set(result, str(key::event_message), str(message));
	state.set(result, str(key::ai_events), array_value(state.new_array()));
	return result;
}

bool _break_dwelling_guard_by_raid(State &state, DictRef session, DictRef raid, Atom faction_id, int64_t index, DictRef site) {
	const ArrayRef nodes = gd::as_array(get_or_new_array(state, session_view::overworld(state, session), key::resource_nodes));
	if (index < 0 || index >= state.array_size(nodes)) {
		return false;
	}
	const DictRef node = gd::as_dict(state.at(nodes, index));
	if (!creature_dwelling_rules::guard_blocks(state, node, site, faction_id, ai::session_int(state, session, key::day))) {
		return true;
	}
	const int64_t guard_strength = _dwelling_guard_strength(state, session, node, site, faction_id);
	const int64_t strength = raid_strength(state, raid);
	const int64_t needed = imax(60, compat::float_to_int(compat::godot_ceil(static_cast<double>(guard_strength) * 0.90)));
	if (strength < needed) {
		return false;
	}
	creature_dwelling_rules::record_guard_result(state, node, faction_id, state.new_array(), true, ai::session_int(state, session, key::day));
	state.set_at(nodes, index, dict_value(node));
	state.set(session_view::overworld(state, session), str(key::resource_nodes), array_value(nodes));
	return true;
}

DictRef _hire_dwelling_creatures_into_raid(State &state, DictRef session, Atom faction_id, DictRef raid, int64_t index, DictRef site, DictRef state_) {
	// {"raid": raid, "hired": hired}
	auto hire_result = [&state](DictRef result_raid, DictRef hired) {
		const DictRef result = state.new_dict();
		state.set(result, str(key::raid), dict_value(result_raid));
		state.set(result, str(key::hired), dict_value(hired));
		return result;
	};
	const ArrayRef nodes = gd::as_array(get_or_new_array(state, session_view::overworld(state, session), key::resource_nodes));
	if (index < 0 || index >= state.array_size(nodes) || gd::is_empty(state, raid)) {
		return hire_result(raid, state.new_dict());
	}
	const DictRef node = gd::as_dict(state.at(nodes, index));
	const DictRef available = creature_dwelling_rules::population(state, node, site, ai::session_int(state, session, key::day));
	const Value treasury_value = get_or_new_dict(state, state_, key::treasury);
	const DictRef treasury = gd::is_dict(treasury_value) ? treasury_value.ref : state.new_dict();
	DictRef army = _raid_reinforcement_army(state, raid);
	if (gd::is_empty(state, army)) {
		const Atom army_id = encounter_id_of(state, raid, key::raid);
		army = state.new_dict();
		state.set(army, str(key::id), str(army_id));
		state.set(army, str(key::name), str(key::raid_host));
		state.set(army, str(key::stacks), array_value(state.new_array()));
	}
	ArrayRef stacks = gd::as_array(get_or_new_array(state, army, key::stacks));
	const ArrayRef unit_ids = gd::keys(state, available);
	gd::sort_custom(state, unit_ids, [&state](const Value &a, const Value &b) {
		return creature_dwelling_rules::unit_tier(state, gd::stringify(state, a)) > creature_dwelling_rules::unit_tier(state, gd::stringify(state, b));
	});
	const DictRef hired = state.new_dict();
	for (const Value &unit_id_value : gd::items(state, array_value(unit_ids))) {
		const Atom unit_id = gd::stringify(state, unit_id_value);
		int64_t count = gd::to_int(state, state.get(available, unit_id_value, int_value(0)));
		const DictRef cost = creature_dwelling_rules::unit_cost(state, unit_id);
		for (const Value &resource : gd::items(state, dict_value(cost))) {
			const int64_t unit_price = gd::to_int(state, gd::index(state, cost, resource));
			if (unit_price > 0) {
				const int64_t affordable = compat::int_div(gd::to_int(state, state.get(treasury, resource, int_value(0))), unit_price);
				count = compat::engine_min<int64_t>(count, affordable);
			}
		}
		if (count <= 0) {
			continue;
		}
		const DictRef additions = state.new_dict();
		state.set(additions, str(unit_id), int_value(count));
		const DictRef plan = hero_command_rules::army_addition_plan(state, array_value(stacks), additions);
		if (!gd::bool_field(state, plan, key::ok, false)) {
			continue;
		}
		stacks = gd::as_array(state.get(plan, str(key::stacks), array_value(stacks)));
		for (const Value &resource : gd::items(state, dict_value(cost))) {
			const int64_t spent = gd::mul(gd::to_int(state, gd::index(state, cost, resource)), count);
			state.set(treasury, resource, int_value(gd::sub(gd::to_int(state, state.get(treasury, resource, int_value(0))), spent)));
		}
		state.set(hired, str(unit_id), int_value(count));
		creature_dwelling_rules::take(state, node, site, unit_id, count, ai::session_int(state, session, key::day));
	}
	if (gd::is_empty(state, hired)) {
		return hire_result(raid, state.new_dict());
	}
	state.set(state_, str(key::treasury), dict_value(treasury));
	state.set_at(nodes, index, dict_value(node));
	state.set(session_view::overworld(state, session), str(key::resource_nodes), array_value(nodes));
	const DictRef updated_raid = gd::deep_duplicate_dict(state, raid);
	state.set(army, str(key::stacks), array_value(stacks));
	state.set(updated_raid, str(key::enemy_army), dict_value(army));
	state.set(updated_raid, str(key::last_dwelling_hires), dict_value(gd::deep_duplicate_dict(state, hired)));
	state.set(updated_raid, str(key::last_dwelling_hires_day), int_value(ai::session_int(state, session, key::day)));
	const Value commander_state = get_or_new_dict(state, updated_raid, key::enemy_commander_state);
	if (filled_dict(state, commander_state)) {
		const DictRef synced_commander = sync_commander_army_continuity(state, commander_state.ref, dict_value(army), encounter_id_of(state, updated_raid, key::empty));
		state.set(updated_raid, str(key::enemy_commander_state), dict_value(synced_commander));
		sync_active_commander(state, session, faction_id, updated_raid, synced_commander);
	}
	return hire_result(updated_raid, hired);
}

DictRef _hire_at_own_dwelling_by_raid(State &state, DictRef session, DictRef raid, DictRef state_, Atom faction_id, int64_t index, DictRef site, DictRef _config) {
	(void)_config;
	const DictRef hire = _hire_dwelling_creatures_into_raid(state, session, faction_id, raid, index, site, state_);
	const DictRef updated_raid = gd::as_dict(state.get(hire, str(key::raid), dict_value(raid)));
	const DictRef hired = gd::as_dict(get_or_new_dict(state, hire, key::hired));
	_ai_hero_task_finish_live_assignment(state, session, faction_id, updated_raid, key::completed, key::valid);
	Atom message = key::empty;
	if (!gd::is_empty(state, hired)) {
		const Atom raid_name = _raid_name(state, updated_raid);
		const Atom recruits = _describe_recruit_set(state, dict_value(hired));
		message = gd::format(state, key::s_hires_s_at_s, { str(raid_name), str(recruits), str(text(state, site, key::name, key::a_dwelling)) });
		overworld_turn_playback::action(state, dict_value(session), updated_raid, key::hires_at_a_dwelling);
	}
	const DictRef result = state.new_dict();
	state.set(result, str(key::encounter), dict_value(updated_raid));
	state.set(result, str(key::state), dict_value(state_));
	state.set(result, str(key::event_message), str(message));
	state.set(result, str(key::ai_events), array_value(state.new_array()));
	return result;
}

DictRef _apply_resource_site_artifact_reward_to_raid(State &state, DictRef session, Atom faction_id, DictRef raid, DictRef node, DictRef site) {
	// {"raid": raid, "applied": false, "reason": reason}
	auto refused = [&state, raid](Atom reason) {
		const DictRef result = state.new_dict();
		state.set(result, str(key::raid), dict_value(raid));
		state.set(result, str(key::applied), bool_value(false));
		state.set(result, str(key::reason), str(reason));
		return result;
	};
	const Atom source_tag = artifact_rules::live_source_reward_tag(state, site);
	if (source_tag == key::empty) {
		return refused(key::source_not_opted_in);
	}
	if (text(state, node, key::artifact_reward_id, key::empty) != key::empty) {
		return refused(key::source_reward_already_claimed);
	}
	Value commander_state = get_or_new_dict(state, raid, key::enemy_commander_state);
	if (!filled_dict(state, commander_state)) {
		return refused(key::commander_unavailable);
	}
	const Value scenario_id = gd::index(state, session, str(key::scenario_id));
	const Atom placement_id = text(state, node, key::placement_id, key::empty);
	const Atom site_id = text(state, node, key::site_id, key::empty);
	const Atom source_key = gd::format(state, key::consequence_cache_key_text, { scenario_id, str(placement_id), str(site_id) });
	const Atom owner_faction_id = player_identity_rules::faction_id(state, session, faction_id);
	const ArrayRef owned_ids = artifact_rules::owned_artifact_ids(state, commander_state.ref);
	const ArrayRef selections = artifact_rules::select_live_source_rewards(state, source_tag, site, source_key, owner_faction_id, owned_ids);
	if (state.array_size(selections) == 0) {
		const Atom failed_faction_id = player_identity_rules::faction_id(state, session, faction_id);
		const ArrayRef failed_owned_ids = artifact_rules::owned_artifact_ids(state, commander_state.ref);
		const DictRef failed = artifact_rules::select_live_source_reward(state, source_tag, site, source_key, failed_faction_id, failed_owned_ids);
		state.set(failed, str(key::raid), dict_value(raid));
		state.set(failed, str(key::applied), bool_value(false));
		return failed;
	}
	const DictRef result = gd::as_dict(gd::duplicate_value(state, state.at(selections, 0), true));
	const DictRef updated_raid = gd::deep_duplicate_dict(state, raid);
	const ArrayRef artifact_ids = state.new_array();
	for (const Value &selection : gd::items(state, array_value(selections))) {
		const Atom artifact_id = gd::stringify(state, ai::vget(state, selection, key::artifact_id, str(key::empty)));
		const Atom source_verb = source_tag == key::shrine
				? gd::format(state, key::s_grants, { str(text(state, site, key::name, key::the_shrine)) })
				: gd::format(state, key::secured_from_s, { str(text(state, site, key::name, key::the_reward_site)) });
		const DictRef claim = artifact_rules::claim_artifact(state, gd::as_dict(commander_state), artifact_id, source_verb, true);
		if (gd::bool_field(state, claim, key::ok, false)) {
			commander_state = state.get(claim, str(key::hero), commander_state);
			if (!gd::bool_field(state, claim, key::duplicate, false)) {
				state.append(artifact_ids, str(gd::stringify(state, ai::vget(state, selection, key::artifact_id, str(key::empty)))));
			}
		}
		if (!state.has(result, str(key::claim))) {
			state.set(result, str(key::claim), dict_value(claim));
		}
	}
	state.set(updated_raid, str(key::enemy_commander_state), commander_state);
	state.set(result, str(key::raid), dict_value(updated_raid));
	state.set(result, str(key::applied), bool_value(state.array_size(artifact_ids) != 0));
	if (state.array_size(artifact_ids) != 0) {
		state.set(result, str(key::artifact_id), str(gd::stringify(state, state.at(artifact_ids, 0))));
	}
	state.set(result, str(key::artifact_ids), array_value(artifact_ids));
	return result;
}

DictRef _apply_resource_site_claim_recruits_to_raid(State &state, DictRef session, Atom faction_id, DictRef raid, DictRef site) {
	// {"raid": raid, "applied": applied, "recruits": recruits}
	auto recruit_result = [&state](DictRef result_raid, bool applied, DictRef recruits) {
		const DictRef result = state.new_dict();
		state.set(result, str(key::raid), dict_value(result_raid));
		state.set(result, str(key::applied), bool_value(applied));
		state.set(result, str(key::recruits), dict_value(recruits));
		return result;
	};
	const DictRef recruits = _resource_site_claim_recruits(state, site);
	if (faction_id == key::empty || gd::is_empty(state, raid) || gd::is_empty(state, recruits)) {
		return recruit_result(raid, false, state.new_dict());
	}
	const DictRef admission = _raid_site_recruit_admission(state, raid, site);
	if (ai::vempty(state, get_or_new_dict(state, admission, key::added))) {
		const DictRef result = recruit_result(raid, false, state.new_dict());
		state.set(result, str(key::reason), str(key::army_capacity));
		return result;
	}
	const DictRef updated_raid = gd::deep_duplicate_dict(state, raid);
	DictRef army = _raid_reinforcement_army(state, updated_raid);
	if (gd::is_empty(state, army)) {
		const Atom army_id = encounter_id_of(state, updated_raid, key::raid);
		army = state.new_dict();
		state.set(army, str(key::id), str(army_id));
		state.set(army, str(key::name), str(key::raid_host));
		state.set(army, str(key::stacks), array_value(state.new_array()));
	}
	const DictRef applied = gd::as_dict(gd::duplicate_value(state, get_or_new_dict(state, admission, key::added), true));
	if (gd::is_empty(state, applied)) {
		return recruit_result(raid, false, state.new_dict());
	}
	state.set(army, str(key::stacks), get_or_new_array(state, admission, key::stacks));
	state.set(updated_raid, str(key::enemy_army), dict_value(army));
	state.set(updated_raid, str(key::last_site_claim_recruits), dict_value(applied));
	state.set(updated_raid, str(key::last_site_claim_recruits_day), int_value(ai::session_int(state, session, key::day)));
	const Value commander_state = get_or_new_dict(state, updated_raid, key::enemy_commander_state);
	if (filled_dict(state, commander_state)) {
		const DictRef synced_commander = sync_commander_army_continuity(state, commander_state.ref, dict_value(army), encounter_id_of(state, updated_raid, key::empty));
		state.set(updated_raid, str(key::enemy_commander_state), dict_value(synced_commander));
		sync_active_commander(state, session, faction_id, updated_raid, synced_commander);
	}
	return recruit_result(updated_raid, true, applied);
}

DictRef _resource_site_claim_recruits(State &state, DictRef site) {
	const Value recruits = get_or_new_dict(state, site, key::claim_recruits);
	if (filled_dict(state, recruits)) {
		return _normalize_recruit_payload(state, recruits);
	}
	const Value roster = get_or_new_dict(state, site, key::neutral_roster);
	if (gd::is_dict(roster)) {
		const Value roster_recruits = get_or_new_dict(state, roster.ref, key::claim_recruits);
		if (gd::is_dict(roster_recruits)) {
			return _normalize_recruit_payload(state, roster_recruits);
		}
	}
	return state.new_dict();
}

DictRef _apply_resource_site_spell_reward_to_commander(State &state, DictRef session, Atom faction_id, DictRef raid, DictRef site) {
	// {"raid": raid, "learned": false, "spell_id": spell_id, "spell_name": spell_name}
	auto unlearned = [&state](DictRef result_raid, Atom spell_id, Atom spell_name) {
		const DictRef result = state.new_dict();
		state.set(result, str(key::raid), dict_value(result_raid));
		state.set(result, str(key::learned), bool_value(false));
		state.set(result, str(key::spell_id), str(spell_id));
		state.set(result, str(key::spell_name), str(spell_name));
		return result;
	};
	// Every spell the site teaches, as the human's hero learns them all.
	const ArrayRef spell_ids = state.new_array();
	if (text(state, site, key::learn_spell_id, key::empty) != key::empty) {
		state.append(spell_ids, str(text(state, site, key::learn_spell_id, key::empty)));
	}
	Value listed;
	if (state.lookup(site, str(key::learn_spell_ids), listed) && gd::is_array(listed)) {
		for (const Value &spell_id_value : gd::items(state, listed)) {
			if (gd::stringify(state, spell_id_value) != key::empty && !gd::array_has(state, spell_ids, str(gd::stringify(state, spell_id_value)))) {
				state.append(spell_ids, str(gd::stringify(state, spell_id_value)));
			}
		}
	}
	const Atom first_id = state.array_size(spell_ids) != 0 ? gd::stringify(state, state.at(spell_ids, 0)) : key::empty;
	const Atom first_name = first_id != key::empty ? text_or(state, gd::content_row(state, ContentTable::Spell, first_id), key::name, str(first_id)) : key::empty;
	if (faction_id == key::empty || gd::is_empty(state, raid) || state.array_size(spell_ids) == 0) {
		return unlearned(raid, first_id, key::empty);
	}
	const Value commander_state = get_or_new_dict(state, raid, key::enemy_commander_state);
	if (!filled_dict(state, commander_state)) {
		return unlearned(raid, first_id, first_name);
	}
	DictRef commander = spell_rules::ensure_hero_spellbook(state, gd::deep_duplicate_dict(state, commander_state.ref), state.new_dict());
	const ArrayRef learned_ids = state.new_array();
	std::vector<Atom> learned_names;
	for (const Value &spell_id : gd::items(state, array_value(spell_ids))) {
		const DictRef spell = gd::content_row(state, ContentTable::Spell, gd::stringify(state, spell_id));
		if (gd::is_empty(state, spell) || spell_rules::knows_spell(state, commander, gd::stringify(state, spell_id))) {
			continue;
		}
		const DictRef learn_result = spell_rules::learn_spell(state, commander, gd::stringify(state, spell_id));
		if (gd::bool_field(state, learn_result, key::ok, false)) {
			commander = gd::as_dict(state.get(learn_result, str(key::hero), dict_value(commander)));
			state.append(learned_ids, str(gd::stringify(state, spell_id)));
			learned_names.push_back(text_or(state, spell, key::name, spell_id));
		}
	}
	const DictRef updated_raid = gd::deep_duplicate_dict(state, raid);
	state.set(updated_raid, str(key::enemy_commander_state), dict_value(commander));
	if (state.array_size(learned_ids) == 0) {
		return unlearned(updated_raid, first_id, first_name);
	}
	sync_active_commander(state, session, faction_id, updated_raid, commander);
	const Atom spell_name = learned_names.size() <= 3
			? join_texts(state, learned_names)
			: gd::format(state, key::d_spells, { int_value(static_cast<int64_t>(learned_names.size())) });
	const DictRef result = state.new_dict();
	state.set(result, str(key::raid), dict_value(updated_raid));
	state.set(result, str(key::learned), bool_value(true));
	state.set(result, str(key::spell_id), str(gd::stringify(state, state.at(learned_ids, 0))));
	state.set(result, str(key::spell_ids), array_value(learned_ids));
	state.set(result, str(key::spell_name), str(spell_name));
	return result;
}

DictRef _reward_resources_for_empire(State &state, const Value &rewards) {
	const DictRef treasury = state.new_dict();
	if (!gd::is_dict(rewards)) {
		return treasury;
	}
	// Every stockpile resource the human would collect from the same reward.
	for (const Atom resource : { key::gold, key::wood, key::ore, key::aetherglass, key::embergrain, key::peatwax, key::verdant_grafts, key::brass_scrip, key::memory_salt }) {
		const int64_t amount = count_field(state, rewards.ref, resource);
		if (amount > 0) {
			state.set(treasury, str(resource), int_value(amount));
		}
	}
	return treasury;
}

Atom _raid_name(State &state, DictRef raid) {
	if (gd::is_dict(state.get(raid, str(key::ai_hero), Value()))) {
		const Atom hero_name = raid_commander_name(state, raid);
		if (hero_name != key::empty) {
			return hero_name;
		}
	}
	const DictRef encounter = gd::content_row(state, ContentTable::Encounter, encounter_id_of(state, raid, key::empty));
	return text(state, encounter, key::name, key::the_enemy_army);
}

int64_t _target_level(State &state, DictRef session, Atom kind, Atom target_id, Atom faction_id, int64_t fallback) {
	if (kind == key::explore) {
		return _exploration_target_level(state, target_id);
	}
	if (kind == key::hero) {
		DictRef hero = _find_player_hero(state, session, target_id);
		if (faction_id != key::empty) {
			hero = _known_player_hero_snapshot_for_ai(state, session, faction_id, hero);
		}
		return gd::is_empty(state, hero) ? fallback : overworld_level_rules::level_of(state, dict_value(hero));
	}
	if (kind == key::town || kind == key::regroup || kind == key::resource || kind == key::artifact || kind == key::encounter) {
		return overworld_rules::placement_level(state, session, target_id, fallback);
	}
	return fallback;
}

int64_t _resource_site_support_value(State &state, DictRef site) {
	const Value support = get_or_new_dict(state, site, key::town_support);
	if (!gd::is_dict(support)) {
		return 0;
	}
	int64_t value = 0;
	value = gd::add(value, gd::mul(count_field(state, support.ref, key::quality_bonus), 85));
	value = gd::add(value, gd::mul(count_field(state, support.ref, key::readiness_bonus), 70));
	value = gd::add(value, gd::mul(count_field(state, support.ref, key::pressure_bonus), 120));
	value = gd::add(value, gd::mul(count_field(state, support.ref, key::growth_bonus_percent), 16));
	value = gd::add(value, gd::mul(count_field(state, support.ref, key::recovery_relief), 120));
	value = gd::add(value, gd::mul(count_field(state, support.ref, key::disruption_pressure), 90));
	return value;
}

int64_t _recruit_payload_value(State &state, const Value &recruits) {
	int64_t value = 0;
	if (!gd::is_dict(recruits)) {
		return value;
	}
	for (const Value &unit_id_value : gd::items(state, recruits)) {
		const Atom unit_id = gd::stringify(state, unit_id_value);
		const int64_t count = imax(0, gd::to_int(state, gd::index(state, recruits.ref, unit_id_value)));
		if (unit_id == key::empty || count <= 0) {
			continue;
		}
		const DictRef unit = gd::content_row(state, ContentTable::Unit, unit_id);
		const int64_t tier = imax(1, gd::int_field(state, unit, key::tier, 1));
		value = gd::add(value, gd::mul(count, gd::add(120, gd::mul(tier, 60))));
		if (gd::bool_field(state, unit, key::ranged, false)) {
			value = gd::add(value, gd::mul(count, 30));
		}
	}
	return value;
}

DictRef _normalize_recruit_payload(State &state, const Value &recruits) {
	const DictRef normalized = state.new_dict();
	if (!gd::is_dict(recruits)) {
		return normalized;
	}
	for (const Value &unit_id_value : gd::items(state, recruits)) {
		const Atom unit_id = gd::stringify(state, unit_id_value);
		const int64_t count = imax(0, gd::to_int(state, state.get(recruits.ref, unit_id_value, int_value(0))));
		if (unit_id == key::empty || count <= 0) {
			continue;
		}
		state.set(normalized, str(unit_id), int_value(gd::add(gd::int_field(state, normalized, unit_id, 0), count)));
	}
	return normalized;
}

DictRef _merge_resources(State &state, const Value &base, const Value &delta) {
	const DictRef merged = state.new_dict();
	if (gd::is_dict(base)) {
		for (const Value &resource : gd::items(state, base)) {
			state.set(merged, str(gd::stringify(state, resource)), int_value(gd::to_int(state, gd::index(state, base.ref, resource))));
		}
	}
	if (gd::is_dict(delta)) {
		for (const Value &resource : gd::items(state, delta)) {
			const Atom resource_key = gd::stringify(state, resource);
			const int64_t added = imax(0, gd::to_int(state, gd::index(state, delta.ref, resource)));
			state.set(merged, str(resource_key), int_value(gd::add(gd::int_field(state, merged, resource_key, 0), added)));
		}
	}
	return merged;
}

Atom _describe_resource_set(State &state, DictRef resources) {
	std::vector<Atom> parts;
	const ArrayRef resource_keys = gd::keys(state, resources);
	sort_texts(state, resource_keys, "EnemyAdventureRules._describe_resource_set");
	for (const Value &resource : gd::items(state, array_value(resource_keys))) {
		const int64_t amount = gd::to_int(state, gd::index(state, resources, resource));
		parts.push_back(gd::format(state, key::_d_s, { int_value(amount), str(gd::stringify(state, resource)) }));
	}
	return join_texts(state, parts);
}

Atom _describe_recruit_set(State &state, const Value &recruits) {
	const DictRef normalized = _normalize_recruit_payload(state, recruits);
	if (gd::is_empty(state, normalized)) {
		return key::empty;
	}
	std::vector<Atom> parts;
	const ArrayRef unit_ids = gd::keys(state, normalized);
	sort_texts(state, unit_ids, "EnemyAdventureRules._describe_recruit_set");
	for (const Value &unit_id_value : gd::items(state, array_value(unit_ids))) {
		const Atom unit_id = gd::stringify(state, unit_id_value);
		const DictRef unit = gd::content_row(state, ContentTable::Unit, unit_id);
		const int64_t count = gd::int_field(state, normalized, unit_id, 0);
		parts.push_back(gd::format(state, key::_d_s, { int_value(count), str(text(state, unit, key::name, unit_id)) }));
	}
	return join_texts(state, parts);
}

} // namespace enemy_adventure_rules

} // namespace aurelion::rules::port
