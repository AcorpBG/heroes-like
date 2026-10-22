// BattleAiRules' scoring payload of a side: the commander payload made ready for
// tactical scoring, its memos (_hero_payload_cache, and _scoring_payloads inside
// a scoring scope), the traits and bonuses read from it, and the enemy's
// withdrawal decision that weighs its commander.

#include "aurelion_rules/port/battle_ai_rules.hpp"
#include "aurelion_rules/port/spell_rules.hpp"

#include "aurelion_rules/compat/godot_math.hpp"

#include <initializer_list>
#include <string>

namespace aurelion::rules::port::battle_ai_rules {

using compat::engine_max;
using gd::array_value;
using gd::bool_value;
using gd::dict_value;
using gd::float_value;
using gd::int_value;
using gd::str;
namespace key = state::key;

namespace {

// The identity keys _commander_payload_for_tactical_scoring fills from the template.
constexpr Atom kTemplateIdentityKeys[] = {
	key::name,
	key::faction_id,
	key::archetype,
	key::command_path,
};

// The command stats it fills from the template's command.
constexpr Atom kCommandKeys[] = {
	key::attack,
	key::defense,
	key::power,
	key::knowledge,
	key::initiative,
};

// The command stats it copies to the payload itself.
constexpr Atom kPayloadStatKeys[] = {
	key::attack,
	key::defense,
	key::initiative,
};

// The payload keys _side_payload_with_commander_fallback copies from the fallback.
constexpr Atom kFallbackPayloadKeys[] = {
	key::attack,
	key::defense,
	key::initiative,
	key::damage_multiplier,
	key::battle_spell_resistance_pct,
	key::battle_control_resistance_pct,
	key::battle_school_resistance_pct,
	key::mana_current,
	key::mana_max,
};

// The archetype tokens of _enemy_withdrawal_urgency_scale, in its order.
constexpr Atom kAggressiveTokens[] = {
	key::raider,
	key::marshal,
	key::vanguard,
	key::outrider,
	key::warrenhunter,
	key::packlord,
	key::chainbreaker,
	key::batterycaptain,
	key::duelline,
	key::siegecaptain,
	key::pitmarshal,
	key::admiral,
	key::harpoon,
	key::backline,
};

constexpr Atom kCautiousTokens[] = {
	key::warden,
	key::castellan,
	key::governor,
	key::scribe,
	key::scholar,
	key::physician,
	key::keeper,
	key::defender,
	key::recovery,
	key::oracle,
	key::doctor,
	key::memory,
	key::diviner,
};

bool empty(const State &state, DictRef dict) {
	return gd::is_empty(state, dict);
}

Atom side_of(const State &state, DictRef stack) {
	return gd::string_field(state, stack, key::side, key::empty);
}

bool one_of(Atom value, std::initializer_list<Atom> atoms) {
	for (const Atom atom : atoms) {
		if (value == atom) {
			return true;
		}
	}
	return false;
}

// d.get(key, []): the field, or a new empty Array.
Value field_or_array(State &state, DictRef dict, Atom field) {
	Value out;
	if (state.lookup(dict, str(field), out)) {
		return out;
	}
	return array_value(state.new_array());
}

// d.get(key, {}): the field, or a new empty Dictionary.
Value get_or_new_dict(State &state, DictRef dict, Atom field) {
	Value out;
	if (state.lookup(dict, str(field), out)) {
		return out;
	}
	return dict_value(state.new_dict());
}

// `value if value is Dictionary else {}`.
DictRef dict_or_new(State &state, const Value &value) {
	return gd::is_dict(value) ? value.ref : state.new_dict();
}

// `d.get(key, {}) if d.get(key, {}) is Dictionary else {}`.
DictRef dict_field_or_new(State &state, DictRef dict, Atom field) {
	Value out;
	if (state.lookup(dict, str(field), out) && gd::is_dict(out)) {
		return out.ref;
	}
	return state.new_dict();
}

// String(d.get(key, "")).strip_edges().
Atom stripped_string_field(State &state, DictRef dict, Atom field) {
	return gd::strip_edges(state, gd::string_field(state, dict, field, key::empty));
}

// s.to_lower() of ASCII text. Other text is left to GDScript: the Unicode case
// tables are not ported.
Atom lower_text(State &state, Atom text) {
	std::string lowered = state.text(text);
	bool changed = false;
	for (char &c : lowered) {
		if (static_cast<unsigned char>(c) >= 0x80) {
			throw state::NotPorted("BattleAiRules._enemy_withdrawal_urgency_scale: to_lower() of non-ASCII text");
		}
		if (c >= 'A' && c <= 'Z') {
			c = static_cast<char>(c - 'A' + 'a');
			changed = true;
		}
	}
	return changed ? state.intern(lowered) : text;
}

bool scoring_scope_open(State &state) {
	return gd::to_int(state, gd::static_var(state, key::battle_ai_rules_script, key::_scoring_scope_depth)) > 0;
}

// The untyped max(a, b) and clamp(x, lo, hi) of floats.
double variant_max_float(double a, double b) {
	return compat::variant_max({ compat::Number::of_float(a), compat::Number::of_float(b) }).f;
}

double variant_clamp_float(double x, double lo, double hi) {
	return compat::variant_clamp(compat::Number::of_float(x), compat::Number::of_float(lo), compat::Number::of_float(hi)).f;
}

} // namespace

DictRef _battle_with_enemy_hero_payload(State &state, DictRef battle, DictRef enemy_hero) {
	return _battle_with_side_hero_payload(state, battle, key::enemy, enemy_hero);
}

DictRef _battle_with_side_hero_payload(State &state, DictRef battle, Atom side, DictRef commander_payload) {
	if (empty(state, battle)) {
		return battle;
	}
	const Atom payload_key = side == key::player ? key::player_hero : key::enemy_hero_payload;
	const DictRef existing_payload = dict_field_or_new(state, battle, payload_key);
	const DictRef source_payload = !empty(state, commander_payload) ? _merged_commander_ai_payload(state, commander_payload, existing_payload) : existing_payload;
	if (empty(state, source_payload)) {
		return battle;
	}
	const DictRef normalized_payload = _commander_payload_for_tactical_scoring(state, source_payload);
	if (empty(state, normalized_payload)) {
		return battle;
	}
	// Scoring only reads the battle and the one swapped payload key, so the
	// stacks and other nested state are shared, not deep-copied per decision.
	const DictRef scored = gd::duplicate_dict(state, battle);
	state.set(scored, str(payload_key), dict_value(normalized_payload));
	return scored;
}

DictRef _commander_payload_for_tactical_scoring(State &state, DictRef commander_payload) {
	if (empty(state, commander_payload)) {
		return state.new_dict();
	}
	const DictRef payload = gd::deep_duplicate_dict(state, commander_payload);
	const DictRef hero_template = _commander_template_for_ai_payload(state, payload);
	for (const Atom field : kTemplateIdentityKeys) {
		if (stripped_string_field(state, payload, field) == key::empty && stripped_string_field(state, hero_template, field) != key::empty) {
			state.set(payload, str(field), str(gd::string_field(state, hero_template, field, key::empty)));
		}
	}
	const ArrayRef template_traits = _normalize_string_array(state, field_or_array(state, hero_template, key::battle_traits));
	const ArrayRef payload_traits = _normalize_string_array(state, field_or_array(state, payload, key::battle_traits));
	if (!state.has(payload, str(key::battle_traits)) && state.array_size(template_traits) != 0) {
		state.set(payload, str(key::battle_traits), array_value(template_traits));
	} else {
		state.set(payload, str(key::battle_traits), array_value(payload_traits));
	}
	// The template is the content row: read, or copied, never written.
	DictRef command = dict_field_or_new(state, payload, key::command);
	const DictRef template_command = dict_field_or_new(state, hero_template, key::command);
	if (empty(state, command) && !empty(state, template_command)) {
		command = gd::deep_duplicate_dict(state, template_command);
	} else if (!empty(state, template_command)) {
		for (const Atom field : kCommandKeys) {
			if (!state.has(command, str(field))) {
				state.set(command, str(field), int_value(gd::int_field(state, template_command, field, 0)));
			}
		}
	}
	if (!empty(state, command)) {
		state.set(payload, str(key::command), dict_value(command));
	}
	if (!empty(state, command)) {
		for (const Atom field : kPayloadStatKeys) {
			if (!state.has(payload, str(field))) {
				state.set(payload, str(field), int_value(gd::int_field(state, command, field, 0)));
			}
		}
	}
	if (!state.has(payload, str(key::damage_multiplier))) {
		state.set(payload, str(key::damage_multiplier), float_value(1.0));
	}
	return spell_rules::ensure_hero_spellbook(state, payload, hero_template);
}

DictRef _enemy_withdrawal_action(State &state, DictRef battle, DictRef active_stack, ArrayRef targets, DictRef current_best) {
	(void)targets;
	if (empty(state, battle) || empty(state, active_stack) || _alive_count(state, active_stack) <= 0) {
		return state.new_dict();
	}
	// Neutral guards and town battles fight to the end (BattleRules._enemy_withdrawal_allowed).
	if (!gd::bool_field(state, battle, key::enemy_withdrawal_allowed, false)) {
		return state.new_dict();
	}
	const bool retreat_allowed = gd::bool_field(state, battle, key::retreat_allowed, true);
	const bool surrender_allowed = gd::bool_field(state, battle, key::surrender_allowed, true);
	if (!retreat_allowed && !surrender_allowed) {
		return state.new_dict();
	}
	if (gd::int_field(state, battle, key::round, 1) < 4) {
		return state.new_dict();
	}
	const int64_t enemy_health = _side_current_health(state, battle, key::enemy);
	const int64_t player_health = _side_current_health(state, battle, key::player);
	if (enemy_health <= 0 || player_health <= 0) {
		return state.new_dict();
	}
	const double enemy_ratio = _side_health_ratio(state, battle, key::enemy);
	const double player_ratio = _side_health_ratio(state, battle, key::player);
	const double active_ratio = _health_ratio(state, active_stack);
	const double pressure_ratio = static_cast<double>(player_health) / static_cast<double>(engine_max<int64_t>(1, enemy_health));
	const double urgency_scale = _enemy_withdrawal_urgency_scale(state, battle);
	const double cautious_pressure = engine_max<double>(0.0, urgency_scale - 1.0);
	const double aggressive_resolve = engine_max<double>(0.0, 1.0 - urgency_scale);
	const double safe_enemy_ratio_gate = 0.34 + cautious_pressure * 0.35 - aggressive_resolve * 0.20;
	const double safe_active_ratio_gate = 0.35 + cautious_pressure * 0.35 - aggressive_resolve * 0.20;
	const double safe_pressure_gate = 2.2 - cautious_pressure * 1.4 + aggressive_resolve * 0.8;
	if (enemy_ratio > safe_enemy_ratio_gate && active_ratio > safe_active_ratio_gate && pressure_ratio < safe_pressure_gate) {
		return state.new_dict();
	}
	const double minimum_pressure_gate = 1.55 - cautious_pressure * 0.65 + aggressive_resolve * 0.45;
	const double minimum_enemy_ratio_gate = 0.22 + cautious_pressure * 0.18 - aggressive_resolve * 0.12;
	if (pressure_ratio < minimum_pressure_gate && enemy_ratio > minimum_enemy_ratio_gate) {
		return state.new_dict();
	}
	const double best_score = !empty(state, current_best) ? gd::float_field(state, current_best, key::score, 0.0) : 0.0;
	const double preservation_best_score = _preservation_comparison_score(state, battle, active_stack, current_best, best_score);
	double score = 5.0;
	score += (1.0 - enemy_ratio) * 10.0;
	score += engine_max<double>(0.0, player_ratio - enemy_ratio) * 6.0;
	score += engine_max<double>(0.0, pressure_ratio - 1.5) * 2.0;
	score += engine_max<double>(0.0, 0.25 - active_ratio) * 5.0;
	const int64_t player_stacks = state.array_size(_alive_stacks_for_side(state, battle, key::player));
	const int64_t enemy_stacks = state.array_size(_alive_stacks_for_side(state, battle, key::enemy));
	score += engine_max<double>(0.0, static_cast<double>(gd::sub(player_stacks, enemy_stacks))) * 0.75;
	if (gd::int_field(state, battle, key::round, 1) >= 4) {
		score += 1.5;
	}
	score *= urgency_scale;
	if (preservation_best_score >= 9.0) {
		score -= (preservation_best_score - 8.5) * 0.8;
	}
	if (score < preservation_best_score + 0.35) {
		return state.new_dict();
	}
	Atom action_id = key::empty;
	if (surrender_allowed && (enemy_ratio <= 0.14 || active_ratio <= 0.12 || pressure_ratio >= 4.0)) {
		action_id = key::surrender;
	} else if (retreat_allowed) {
		action_id = key::retreat;
	} else if (surrender_allowed) {
		action_id = key::surrender;
	}
	if (action_id == key::empty) {
		return state.new_dict();
	}
	if (score < best_score + 0.35) {
		score = best_score + 0.35;
	}
	const DictRef result = state.new_dict();
	state.set(result, str(key::action), str(action_id));
	state.set(result, str(key::score), float_value(score));
	state.set(result, str(key::scoring_policy), str(key::battle_ai_enemy_withdrawal_decision_v1));
	state.set(result, str(key::reason), str(key::enemy_force_preservation));
	state.set(result, str(key::enemy_health_ratio), float_value(enemy_ratio));
	state.set(result, str(key::player_health_ratio), float_value(player_ratio));
	state.set(result, str(key::active_health_ratio), float_value(active_ratio));
	state.set(result, str(key::pressure_ratio), float_value(pressure_ratio));
	state.set(result, str(key::commander_withdrawal_urgency_scale), float_value(urgency_scale));
	state.set(result, str(key::current_best_action), str(gd::string_field(state, current_best, key::action, key::empty)));
	state.set(result, str(key::current_best_score), float_value(best_score));
	state.set(result, str(key::preservation_comparison_score), float_value(preservation_best_score));
	return result;
}

double _preservation_comparison_score(State &state, DictRef battle, DictRef active_stack, DictRef current_best, double best_score) {
	const Atom action = gd::string_field(state, current_best, key::action, key::empty);
	if (!one_of(action, { key::shoot, key::strike, key::cast_spell })) {
		return best_score;
	}
	const DictRef target = _stack_by_battle_id(state, battle, gd::string_field(state, current_best, key::target_battle_id, key::empty));
	if (empty(state, target) || side_of(state, target) == side_of(state, active_stack)) {
		return best_score;
	}
	const double immediate_threat = _target_immediate_threat_score(state, active_stack, target, battle);
	if (immediate_threat <= 0.0) {
		return best_score;
	}
	return variant_max_float(0.0, best_score - immediate_threat);
}

double _enemy_withdrawal_urgency_scale(State &state, DictRef battle) {
	const DictRef commander = _hero_payload_for_side(state, battle, key::enemy);
	if (empty(state, commander)) {
		return 1.0;
	}
	double scale = 1.0;
	const Atom archetype = lower_text(state, gd::string_field(state, commander, key::archetype, key::empty));
	const Atom command_path = lower_text(state, gd::string_field(state, commander, key::command_path, key::empty));
	const ArrayRef battle_traits = _normalize_string_array(state, field_or_array(state, commander, key::battle_traits));
	const DictRef command = dict_field_or_new(state, commander, key::command);
	const int64_t attack = gd::int_field(state, command, key::attack, 0);
	const int64_t defense = gd::int_field(state, command, key::defense, 0);
	const int64_t power = gd::int_field(state, command, key::power, 0);
	const int64_t knowledge = gd::int_field(state, command, key::knowledge, 0);
	// archetype.contains(token): the tokens are not empty, so a byte search of
	// the (ASCII) text answers as String::find does.
	const std::string archetype_text = state.text(archetype);
	for (const Atom token : kAggressiveTokens) {
		if (archetype_text.find(state.text(token)) != std::string::npos) {
			scale -= 0.07;
			break;
		}
	}
	for (const Atom token : kCautiousTokens) {
		if (archetype_text.find(state.text(token)) != std::string::npos) {
			scale += 0.07;
			break;
		}
	}
	if (command_path == key::might) {
		scale -= 0.02;
	} else if (command_path == key::magic) {
		scale += 0.02;
	}
	scale -= variant_clamp_float(static_cast<double>(gd::sub(attack, defense)) * 0.02, -0.06, 0.06);
	if (gd::add(power, knowledge) > gd::add(gd::add(attack, defense), 1)) {
		scale += 0.03;
	}
	for (const Value &trait_value : gd::items(state, array_value(battle_traits))) {
		const Atom trait_id = lower_text(state, gd::to_string(trait_value));
		if (one_of(trait_id, { key::vanguard, key::ambusher, key::artillerist, key::pursuit, key::linebreaker })) {
			scale -= 0.025;
		} else if (one_of(trait_id, { key::linekeeper, key::bogwise, key::ward, key::support, key::defensive })) {
			scale += 0.025;
		}
	}
	const Atom last_outcome = lower_text(state, gd::string_field(state, commander, key::last_outcome, key::empty));
	if (one_of(last_outcome, { key::defeated, key::routed, key::assault_failed, key::pursuit_failed })) {
		scale += 0.05;
	} else if (one_of(last_outcome, { key::field_victory, key::assault_victory, key::pursuit_victory, key::rout_victory, key::town_captured, key::resource_secured, key::artifact_secured })) {
		scale -= 0.03;
	}
	return variant_clamp_float(scale, 0.86, 1.18);
}

int64_t _hero_bonus_for_side(State &state, DictRef battle, Atom side, Atom kind) {
	return gd::int_field(state, _hero_payload_for_side(state, battle, side), kind, 0);
}

double _damage_multiplier_for_side(State &state, DictRef battle, Atom side) {
	return gd::float_field(state, _hero_payload_for_side(state, battle, side), key::damage_multiplier, 1.0);
}

DictRef _hero_payload_for_side(State &state, DictRef battle, Atom side) {
	if (scoring_scope_open(state)) {
		return gd::as_dict(state.at(_scoring_payload_entry(state, battle, side), 2));
	}
	return _side_hero_payload(state, battle, side);
}

ArrayRef _scoring_payload_entry(State &state, DictRef battle, Atom side) {
	const Atom cache_side = side == key::player ? key::player : key::enemy;
	// battle.get(key) with no default: null when missing.
	const Value payload_value = gd::field(state, battle, cache_side == key::player ? key::player_hero : key::enemy_hero_payload);
	const Value commander_value = gd::field(state, battle, cache_side == key::player ? key::player_commander_state : key::enemy_hero);
	const DictRef payloads = gd::as_dict(gd::static_var(state, key::battle_ai_rules_script, key::_scoring_payloads));
	Value held;
	if (state.lookup(payloads, str(cache_side), held)) {
		const ArrayRef entry = gd::as_array(held);
		if (state.array_size(entry) != 0 && gd::is_same(state, state.at(entry, 0), payload_value) && gd::is_same(state, state.at(entry, 1), commander_value)) {
			return entry;
		}
	}
	const DictRef payload = _side_hero_payload(state, battle, side);
	const ArrayRef entry = state.new_array();
	state.append(entry, payload_value);
	state.append(entry, commander_value);
	state.append(entry, dict_value(payload));
	state.append(entry, Value());
	state.set(payloads, str(cache_side), array_value(entry));
	return entry;
}

DictRef _side_hero_payload(State &state, DictRef battle, Atom side) {
	const Atom cache_side = side == key::player ? key::player : key::enemy;
	const Value payload_value = get_or_new_dict(state, battle, cache_side == key::player ? key::player_hero : key::enemy_hero_payload);
	const Value commander_value = get_or_new_dict(state, battle, cache_side == key::player ? key::player_commander_state : key::enemy_hero);
	const DictRef payload_source = dict_or_new(state, payload_value);
	const DictRef commander_source = dict_or_new(state, commander_value);
	// BattleAiRules' own _hero_payload_cache: the side's last payload, while its
	// sources compare equal to the copies kept with it.
	const DictRef cache = gd::as_dict(gd::static_var(state, key::battle_ai_rules_script, key::_hero_payload_cache));
	Value cached_value;
	if (!state.lookup(cache, str(cache_side), cached_value)) {
		cached_value = dict_value(state.new_dict());
	}
	const DictRef cached = gd::as_dict(cached_value);
	if (!empty(state, cached)
			&& gd::equal(state, gd::index(state, cached, str(key::payload_source)), dict_value(payload_source))
			&& gd::equal(state, gd::index(state, cached, str(key::commander_source)), dict_value(commander_source))) {
		return gd::as_dict(gd::index(state, cached, str(key::payload)));
	}
	// Without a commander the fallback returns the live payload itself; keep a
	// private copy so later in-place edits cannot leak into a cache hit.
	const DictRef payload = gd::deep_duplicate_dict(state, _side_payload_with_commander_fallback(state, dict_value(payload_source), dict_value(commander_source)));
	const DictRef entry = state.new_dict();
	state.set(entry, str(key::payload_source), dict_value(gd::deep_duplicate_dict(state, payload_source)));
	state.set(entry, str(key::commander_source), dict_value(gd::deep_duplicate_dict(state, commander_source)));
	state.set(entry, str(key::payload), dict_value(payload));
	state.set(cache, str(cache_side), dict_value(entry));
	return payload;
}

DictRef _side_payload_with_commander_fallback(State &state, const Value &existing_payload_value, const Value &commander_state_value) {
	const DictRef existing_payload = dict_or_new(state, existing_payload_value);
	const DictRef commander_state = dict_or_new(state, commander_state_value);
	if (empty(state, commander_state)) {
		return existing_payload;
	}
	const DictRef fallback_payload = _commander_payload_for_tactical_scoring(state, commander_state);
	if (empty(state, existing_payload)) {
		return fallback_payload;
	}
	const DictRef merged = _commander_payload_for_tactical_scoring(state, _merged_commander_ai_payload(state, existing_payload, fallback_payload));
	for (const Atom field : kFallbackPayloadKeys) {
		if (!state.has(merged, str(field)) && state.has(fallback_payload, str(field))) {
			state.set(merged, str(field), gd::field(state, fallback_payload, field));
		}
	}
	return merged;
}

bool _hero_has_trait(State &state, DictRef battle, Atom side, Atom trait_id) {
	if (trait_id == key::empty) {
		return false;
	}
	if (scoring_scope_open(state)) {
		// The payload's traits as a set, kept in the scope's entry (its null
		// fourth slot until the first trait check).
		const ArrayRef entry = _scoring_payload_entry(state, battle, side);
		if (!gd::is_dict(state.at(entry, 3))) {
			const DictRef traits = state.new_dict();
			for (const Value &value : gd::field_items(state, gd::as_dict(state.at(entry, 2)), str(key::battle_traits))) {
				state.set(traits, str(gd::to_string(value)), bool_value(true));
			}
			state.set_at(entry, 3, dict_value(traits));
		}
		return state.has(gd::as_dict(state.at(entry, 3)), str(trait_id));
	}
	for (const Value &value : gd::field_items(state, _hero_payload_for_side(state, battle, side), str(key::battle_traits))) {
		if (gd::to_string(value) == trait_id) {
			return true;
		}
	}
	return false;
}

} // namespace aurelion::rules::port::battle_ai_rules
