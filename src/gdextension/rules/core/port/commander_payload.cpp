// Layer 2: the commander payload: a side's hero payload, its specialty bonuses and difficulty terms.

#include "aurelion_rules/port/battle_ai_rules.hpp"
#include "aurelion_rules/port/battle_rules.hpp"
#include "aurelion_rules/port/difficulty_rules.hpp"
#include "aurelion_rules/port/hero_progression_rules.hpp"
#include "aurelion_rules/port/spell_rules.hpp"

#include <string>

namespace aurelion::rules::port {

namespace {

using gd::array_value;
using gd::ArrayRef;
using gd::Atom;
using gd::dict_value;
using gd::DictRef;
using gd::int_value;
using gd::str;
using state::State;
using state::Value;
namespace key = state::key;

// SpellRules.MAX_SPELL_RESISTANCE_PCT and MAX_CONTROL_RESISTANCE_PCT.
constexpr int64_t kMaxSpellResistancePct = 75;
constexpr int64_t kMaxControlResistancePct = 80;

// SpellRules.SPELL_SCHOOL_IDS.
constexpr Atom kSpellSchoolIds[] = {
	key::beacon,
	key::mire,
	key::lens,
	key::root,
	key::furnace,
	key::veil,
	key::old_measure,
};

// BattleDamageRules.HERO_SPECIALTY_BATTLE_KEYS.
constexpr Atom kHeroSpecialtyBattleKeys[] = {
	key::melee_damage_pct,
	key::ranged_damage_pct,
	key::damage_taken_pct,
	key::retaliation_damage_pct,
	key::siege_damage_pct,
	key::defend_defense_bonus,
	key::battle_cohesion,
	key::battle_momentum,
	key::creature_health_pct,
	key::victory_recovery_pct,
	key::mana_after_victory,
	key::reward_bonus_pct,
};

// The identity keys BattleRules._enemy_hero_payload_from_state and
// BattleAiRules._merged_commander_ai_payload copy.
constexpr Atom kCommanderIdentityKeys[] = {
	key::id,
	key::roster_hero_id,
	key::hero_id,
	key::name,
	key::faction_id,
	key::archetype,
	key::command_path,
};

// The id keys of _commander_identity_tokens and _resolve_bonus_key.
constexpr Atom kHeroIdKeys[] = {
	key::id,
	key::roster_hero_id,
	key::hero_id,
};

// The command stats _merged_commander_ai_payload fills from the secondary payload.
constexpr Atom kCommandMergeKeys[] = {
	key::attack,
	key::defense,
	key::power,
	key::knowledge,
	key::initiative,
};

// The payload keys _side_payload_with_commander_fallback copies before the
// specialty battle keys.
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

// The untyped max(a, b), min(a, b) and clamp(x, lo, hi) of ints: the result is an int.
int64_t variant_max_int(int64_t a, int64_t b) {
	return compat::variant_max({ compat::Number::of_int(a), compat::Number::of_int(b) }).i;
}

int64_t variant_min_int(int64_t a, int64_t b) {
	return compat::variant_min({ compat::Number::of_int(a), compat::Number::of_int(b) }).i;
}

int64_t variant_clamp_int(int64_t x, int64_t lo, int64_t hi) {
	return compat::variant_clamp(compat::Number::of_int(x), compat::Number::of_int(lo), compat::Number::of_int(hi)).i;
}

// x.get(key, fallback) on an untyped value: only a Dictionary has a two-argument
// get (Array.get and Object.get take one), so anything else stops the script.
[[noreturn]] void no_two_argument_get(const Value &target) {
	throw state::ScriptError(std::string("Invalid call. Nonexistent function 'get' with two arguments in base '") + gd::type_name(target) + "'.");
}

Value variant_get(const State &state, const Value &target, Atom field, const Value &fallback) {
	if (!gd::is_dict(target)) {
		no_two_argument_get(target);
	}
	return state.get(target.ref, str(field), fallback);
}

// x.get(key, {}) on an untyped value: the default is a new Dictionary.
Value variant_get_or_new_dict(State &state, const Value &target, Atom field) {
	if (!gd::is_dict(target)) {
		no_two_argument_get(target);
	}
	Value found;
	if (state.lookup(target.ref, str(field), found)) {
		return found;
	}
	return dict_value(state.new_dict());
}

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

// `value if value is Dictionary else {}`.
DictRef dict_or_new(State &state, const Value &value) {
	return gd::is_dict(value) ? value.ref : state.new_dict();
}

// `d.get(key, {}) if d.get(key, {}) is Dictionary else {}`.
DictRef dict_field_or_new(State &state, DictRef dict, Atom field) {
	Value found;
	if (state.lookup(dict, str(field), found) && gd::is_dict(found)) {
		return found.ref;
	}
	return state.new_dict();
}

// String(d.get(key, "")).strip_edges().
Atom stripped_string_field(State &state, DictRef dict, Atom field) {
	return gd::strip_edges(state, gd::string_field(state, dict, field, key::empty));
}

// text.ends_with(":%s" % suffix).
bool ends_with_colon_token(const std::string &text, const std::string &suffix) {
	const size_t length = suffix.size() + 1;
	if (text.size() < length) {
		return false;
	}
	const size_t start = text.size() - length;
	return text[start] == ':' && text.compare(start + 1, suffix.size(), suffix) == 0;
}

// The profile of DifficultyRules.DIFFICULTY_PROFILES[id].duplicate(true): a new
// Dictionary in the const's key order and types.
DictRef difficulty_profile(State &state, Atom id) {
	struct Profile {
		int64_t movement_bonus;
		double income_multiplier;
		double reward_multiplier;
		int64_t enemy_pressure_bonus;
		int64_t raid_threshold_offset;
		double raid_pillage_multiplier;
		double player_damage_multiplier;
		double enemy_damage_multiplier;
		int64_t player_initiative_bonus;
		int64_t enemy_initiative_bonus;
	};
	static constexpr Profile kStory{ 2, 1.25, 1.25, -1, 1, 0.75, 1.1, 0.9, 1, 0 };
	static constexpr Profile kNormal{ 0, 1.0, 1.0, 0, 0, 1.0, 1.0, 1.0, 0, 0 };
	static constexpr Profile kHard{ -1, 0.85, 0.85, 1, -1, 1.25, 0.95, 1.05, 0, 1 };
	const Profile &profile = id == key::story ? kStory : (id == key::hard ? kHard : kNormal);
	const DictRef result = state.new_dict();
	state.set(result, str(key::movement_bonus), int_value(profile.movement_bonus));
	state.set(result, str(key::income_multiplier), gd::float_value(profile.income_multiplier));
	state.set(result, str(key::reward_multiplier), gd::float_value(profile.reward_multiplier));
	state.set(result, str(key::enemy_pressure_bonus), int_value(profile.enemy_pressure_bonus));
	state.set(result, str(key::raid_threshold_offset), int_value(profile.raid_threshold_offset));
	state.set(result, str(key::raid_pillage_multiplier), gd::float_value(profile.raid_pillage_multiplier));
	state.set(result, str(key::player_damage_multiplier), gd::float_value(profile.player_damage_multiplier));
	state.set(result, str(key::enemy_damage_multiplier), gd::float_value(profile.enemy_damage_multiplier));
	state.set(result, str(key::player_initiative_bonus), int_value(profile.player_initiative_bonus));
	state.set(result, str(key::enemy_initiative_bonus), int_value(profile.enemy_initiative_bonus));
	return result;
}

// `for trait_value in source: var trait_id = String(trait_value); if trait_id != ""
// and trait_id not in normalized: normalized.append(trait_id)`.
void append_new_trait_ids(State &state, ArrayRef normalized, const Value &source) {
	for (const Value &trait_value : gd::items(state, source)) {
		const Atom trait_id = gd::to_string(trait_value);
		if (trait_id != key::empty && !gd::array_has(state, normalized, str(trait_id))) {
			state.append(normalized, str(trait_id));
		}
	}
}

} // namespace

namespace battle_rules {

bool _hero_has_trait(State &state, DictRef battle, Atom side, Atom trait_id) {
	if (trait_id == key::empty) {
		return false;
	}
	const DictRef payload = _hero_payload_for_side(state, battle, side);
	for (const Value &value : gd::field_items(state, payload, str(key::battle_traits))) {
		if (gd::to_string(value) == trait_id) {
			return true;
		}
	}
	return false;
}

Value _hero_battle_traits(State &state, DictRef battle, Atom side) {
	return get_or_new_array(state, _hero_payload_for_side(state, battle, side), key::battle_traits);
}

DictRef _hero_payload_for_side(State &state, DictRef battle, Atom side) {
	const Atom cache_side = side == key::player ? key::player : key::enemy;
	const Value payload_value = get_or_new_dict(state, battle, cache_side == key::player ? key::player_hero : key::enemy_hero_payload);
	const Value commander_value = get_or_new_dict(state, battle, cache_side == key::player ? key::player_commander_state : key::enemy_hero);
	const DictRef payload_source = dict_or_new(state, payload_value);
	const DictRef commander_source = dict_or_new(state, commander_value);
	// The payload memo, _hero_payload_cache: the side's last payload, while its
	// sources compare equal to the copies kept with it.
	const DictRef cache = gd::as_dict(gd::static_var(state, key::battle_rules_script, key::_hero_payload_cache));
	Value cached_value;
	if (!state.lookup(cache, str(cache_side), cached_value)) {
		cached_value = dict_value(state.new_dict());
	}
	const DictRef cached = gd::as_dict(cached_value);
	if (!gd::is_empty(state, cached)
			&& gd::equal(state, gd::index(state, cached, str(key::payload_source)), dict_value(payload_source))
			&& gd::equal(state, gd::index(state, cached, str(key::commander_source)), dict_value(commander_source))) {
		return gd::as_dict(gd::index(state, cached, str(key::payload)));
	}
	const DictRef payload = gd::deep_duplicate_dict(state, _side_payload_with_commander_fallback(state, dict_value(payload_source), dict_value(commander_source), cache_side));
	const DictRef entry = state.new_dict();
	state.set(entry, str(key::payload_source), dict_value(gd::deep_duplicate_dict(state, payload_source)));
	state.set(entry, str(key::commander_source), dict_value(gd::deep_duplicate_dict(state, commander_source)));
	state.set(entry, str(key::payload), dict_value(payload));
	state.set(cache, str(cache_side), dict_value(entry));
	return payload;
}

DictRef _side_payload_with_commander_fallback(State &state, const Value &existing_payload_value, const Value &commander_state_value, Atom side) {
	const DictRef existing_payload = dict_or_new(state, existing_payload_value);
	const DictRef commander_state = dict_or_new(state, commander_state_value);
	if (gd::is_empty(state, commander_state)) {
		return existing_payload;
	}
	const DictRef fallback_payload = side == key::player
			? _hero_payload_from_state(state, commander_state, state.new_dict(), Value(), key::player)
			: _enemy_hero_payload_from_state(state, commander_state, dict_value(state.new_dict()), Value());
	if (gd::is_empty(state, existing_payload)) {
		return fallback_payload;
	}
	const DictRef merged = battle_ai_rules::_merged_commander_ai_payload(state, existing_payload, fallback_payload);
	const auto copy_missing = [&](Atom field) {
		if (!state.has(merged, str(field)) && state.has(fallback_payload, str(field))) {
			state.set(merged, str(field), gd::field(state, fallback_payload, field));
		}
	};
	for (const Atom field : kFallbackPayloadKeys) {
		copy_missing(field);
	}
	for (const Atom field : kHeroSpecialtyBattleKeys) {
		copy_missing(field);
	}
	return merged;
}

bool _has_battle_trait(State &state, const Value &traits, Atom trait_id) {
	if (trait_id == key::empty) {
		return false;
	}
	for (const Value &value : gd::items(state, traits)) {
		if (gd::to_string(value) == trait_id) {
			return true;
		}
	}
	return false;
}

DictRef _enemy_hero_payload_from_state(State &state, DictRef hero_state, const Value &existing_payload, const Value &session) {
	const DictRef payload = _hero_payload_from_state(state, hero_state, state.new_dict(), session, key::enemy);
	for (const Atom field : kCommanderIdentityKeys) {
		const Atom value = stripped_string_field(state, hero_state, field);
		if (value != key::empty) {
			state.set(payload, str(field), str(value));
		}
	}
	const DictRef command = dict_field_or_new(state, hero_state, key::command);
	if (!gd::is_empty(state, command)) {
		state.set(payload, str(key::command), dict_value(gd::deep_duplicate_dict(state, command)));
	}
	const DictRef spellbook = dict_field_or_new(state, hero_state, key::spellbook);
	// var known_spell_ids: Array = spellbook.get("known_spell_ids", []) if ... is Array else []
	Value known_spell_ids_value;
	const bool has_known_spell_ids = state.lookup(spellbook, str(key::known_spell_ids), known_spell_ids_value) && gd::is_array(known_spell_ids_value);
	if (has_known_spell_ids && state.array_size(known_spell_ids_value.ref) != 0) {
		state.set(payload, str(key::spellbook), dict_value(gd::deep_duplicate_dict(state, spellbook)));
	}
	const DictRef existing = dict_or_new(state, existing_payload);
	if (gd::is_empty(state, existing)) {
		return payload;
	}
	return battle_ai_rules::_merged_commander_ai_payload(state, payload, existing);
}

DictRef _hero_payload_from_state(State &state, DictRef hero_state, DictRef bonuses, const Value &session, Atom side) {
	const Value command = get_or_new_dict(state, hero_state, key::command);
	// bonuses is a typed Dictionary, so `bonuses.duplicate(true) if bonuses is Dictionary else {}`
	// is always the deep copy.
	const DictRef resolved_bonuses = gd::deep_duplicate_dict(state, bonuses);
	const DictRef specialty_bonuses = hero_progression_rules::aggregate_bonuses(state, hero_state);
	const ArrayRef battle_traits = _normalized_battle_traits(state, dict_value(hero_state));
	const int64_t knowledge = variant_max_int(0, gd::to_int(state, variant_get(state, command, key::knowledge, int_value(0))));
	const auto add_specialty = [&](Atom field) {
		const int64_t resolved = gd::int_field(state, resolved_bonuses, field, 0);
		const int64_t specialty = gd::int_field(state, specialty_bonuses, field, 0);
		state.set(resolved_bonuses, str(field), int_value(gd::add(resolved, specialty)));
	};
	add_specialty(key::battle_attack);
	add_specialty(key::battle_defense);
	add_specialty(key::battle_initiative);
	add_specialty(key::battle_spell_resistance_pct);
	add_specialty(key::battle_control_resistance_pct);
	{
		const Value left = get_or_new_dict(state, resolved_bonuses, key::battle_school_resistance_pct);
		const Value right = get_or_new_dict(state, specialty_bonuses, key::battle_school_resistance_pct);
		state.set(resolved_bonuses, str(key::battle_school_resistance_pct), dict_value(_merge_spell_school_resistance(state, left, right)));
	}
	const Value spellbook = get_or_new_dict(state, hero_state, key::spellbook);
	const Value mana = variant_get_or_new_dict(state, spellbook, key::mana);

	const int64_t attack = gd::add(gd::to_int(state, variant_get(state, command, key::attack, int_value(0))), gd::int_field(state, resolved_bonuses, key::battle_attack, 0));
	const int64_t defense = gd::add(gd::to_int(state, variant_get(state, command, key::defense, int_value(0))), gd::int_field(state, resolved_bonuses, key::battle_defense, 0));
	const int64_t initiative_bonus = gd::int_field(state, resolved_bonuses, key::battle_initiative, 0);
	const int64_t initiative = gd::add(initiative_bonus, difficulty_rules::initiative_bonus_for_side(state, session, side));
	const double damage_multiplier = difficulty_rules::damage_multiplier_for_side(state, session, side);
	const int64_t spell_resistance = variant_clamp_int(
			gd::add(gd::int_field(state, resolved_bonuses, key::battle_spell_resistance_pct, 0), variant_min_int(20, gd::mul(knowledge, 2))),
			0,
			kMaxSpellResistancePct);
	const int64_t control_resistance = variant_clamp_int(
			gd::add(gd::int_field(state, resolved_bonuses, key::battle_control_resistance_pct, 0), variant_min_int(15, knowledge)),
			0,
			kMaxControlResistancePct);
	const DictRef school_resistance = spell_rules::normalize_school_resistance(state, get_or_new_dict(state, resolved_bonuses, key::battle_school_resistance_pct));
	const int64_t mana_current = gd::to_int(state, variant_get(state, mana, key::current, int_value(0)));
	const int64_t mana_max = gd::to_int(state, variant_get(state, mana, key::max, int_value(0)));

	const DictRef payload = state.new_dict();
	state.set(payload, str(key::attack), int_value(attack));
	state.set(payload, str(key::defense), int_value(defense));
	state.set(payload, str(key::initiative), int_value(initiative));
	state.set(payload, str(key::damage_multiplier), gd::float_value(damage_multiplier));
	state.set(payload, str(key::battle_spell_resistance_pct), int_value(spell_resistance));
	state.set(payload, str(key::battle_control_resistance_pct), int_value(control_resistance));
	state.set(payload, str(key::battle_school_resistance_pct), dict_value(school_resistance));
	state.set(payload, str(key::mana_current), int_value(mana_current));
	state.set(payload, str(key::mana_max), int_value(mana_max));
	state.set(payload, str(key::battle_traits), array_value(battle_traits));
	for (const Atom field : kHeroSpecialtyBattleKeys) {
		state.set(payload, str(field), int_value(gd::int_field(state, specialty_bonuses, field, 0)));
	}
	return payload;
}

DictRef _merge_spell_school_resistance(State &state, const Value &left, const Value &right) {
	const DictRef merged = spell_rules::normalize_school_resistance(state, left);
	const DictRef right_normalized = spell_rules::normalize_school_resistance(state, right);
	const ArrayRef school_ids = gd::keys(state, right_normalized);
	for (const Value &school_id : gd::items(state, array_value(school_ids))) {
		const int64_t current = gd::to_int(state, state.get(merged, school_id, int_value(0)));
		const int64_t added = gd::to_int(state, gd::index(state, right_normalized, school_id));
		state.set(merged, school_id, int_value(variant_clamp_int(gd::add(current, added), 0, kMaxSpellResistancePct)));
	}
	return merged;
}

ArrayRef _normalized_battle_traits(State &state, const Value &value) {
	// var source = []: only an Array source is walked; any other source becomes [].
	Value source;
	bool source_is_array = false;
	if (gd::is_dict(value)) {
		Value found;
		if (state.lookup(value.ref, str(key::battle_traits), found)) {
			source = found;
			source_is_array = gd::is_array(found);
		}
	} else if (gd::is_array(value)) {
		source = value;
		source_is_array = true;
	}
	const ArrayRef normalized = state.new_array();
	if (source_is_array) {
		append_new_trait_ids(state, normalized, source);
	}
	if (state.array_size(normalized) == 0 && gd::is_dict(value)) {
		const Atom hero_id = gd::string_field(state, value.ref, key::id, key::empty);
		if (hero_id != key::empty) {
			const DictRef hero = gd::content_row(state, state::ContentTable::Hero, hero_id);
			Value hero_traits;
			if (state.lookup(hero, str(key::battle_traits), hero_traits)) {
				append_new_trait_ids(state, normalized, hero_traits);
			}
		}
	}
	return normalized;
}

} // namespace battle_rules

namespace battle_ai_rules {

DictRef _merged_commander_ai_payload(State &state, DictRef primary_payload, DictRef secondary_payload) {
	if (gd::is_empty(state, primary_payload)) {
		return gd::deep_duplicate_dict(state, secondary_payload);
	}
	if (gd::is_empty(state, secondary_payload)) {
		return gd::deep_duplicate_dict(state, primary_payload);
	}
	DictRef merged = gd::deep_duplicate_dict(state, primary_payload);
	if (!_commander_payloads_can_merge(state, primary_payload, secondary_payload)) {
		return merged;
	}

	for (const Atom field : kCommanderIdentityKeys) {
		if (stripped_string_field(state, merged, field) == key::empty && stripped_string_field(state, secondary_payload, field) != key::empty) {
			state.set(merged, str(field), gd::field(state, secondary_payload, field));
		}
	}

	DictRef command = dict_field_or_new(state, merged, key::command);
	const DictRef secondary_command = dict_field_or_new(state, secondary_payload, key::command);
	if (gd::is_empty(state, command) && !gd::is_empty(state, secondary_command)) {
		command = gd::deep_duplicate_dict(state, secondary_command);
	} else if (!gd::is_empty(state, secondary_command)) {
		for (const Atom field : kCommandMergeKeys) {
			if (!state.has(secondary_command, str(field))) {
				continue;
			}
			const int64_t secondary_value = gd::int_field(state, secondary_command, field, 0);
			if (!state.has(command, str(field)) || (gd::int_field(state, command, field, 0) == 0 && secondary_value > 0)) {
				state.set(command, str(field), int_value(secondary_value));
			}
		}
	}
	if (!gd::is_empty(state, command)) {
		state.set(merged, str(key::command), dict_value(command));
	}

	const ArrayRef traits = _normalize_string_array(state, get_or_new_array(state, merged, key::battle_traits));
	const ArrayRef secondary_traits = _normalize_string_array(state, get_or_new_array(state, secondary_payload, key::battle_traits));
	for (const Value &trait_id : gd::items(state, array_value(secondary_traits))) {
		if (!gd::array_has(state, traits, trait_id)) {
			state.append(traits, trait_id);
		}
	}
	if (state.array_size(traits) != 0) {
		state.set(merged, str(key::battle_traits), array_value(traits));
	}

	merged = _merge_commander_spellbooks_for_ai(state, merged, secondary_payload);
	return merged;
}

bool _commander_payloads_can_merge(State &state, DictRef primary_payload, DictRef secondary_payload) {
	const ArrayRef primary_tokens = _commander_identity_tokens(state, primary_payload);
	const ArrayRef secondary_tokens = _commander_identity_tokens(state, secondary_payload);
	if (state.array_size(primary_tokens) == 0 || state.array_size(secondary_tokens) == 0) {
		return true;
	}
	for (const Value &primary_token : gd::items(state, array_value(primary_tokens))) {
		for (const Value &secondary_token : gd::items(state, array_value(secondary_tokens))) {
			if (_commander_identity_tokens_match(state, gd::to_string(primary_token), gd::to_string(secondary_token))) {
				return true;
			}
		}
	}
	return false;
}

DictRef _merge_commander_spellbooks_for_ai(State &state, DictRef merged, DictRef secondary_payload) {
	const DictRef spellbook = dict_field_or_new(state, merged, key::spellbook);
	const DictRef secondary_spellbook = dict_field_or_new(state, secondary_payload, key::spellbook);
	if (gd::is_empty(state, secondary_spellbook)) {
		return merged;
	}
	if (gd::is_empty(state, spellbook)) {
		state.set(merged, str(key::spellbook), dict_value(gd::deep_duplicate_dict(state, secondary_spellbook)));
		return merged;
	}

	const ArrayRef primary_known_spell_ids = _normalize_string_array(state, get_or_new_array(state, spellbook, key::known_spell_ids));
	const ArrayRef secondary_known_spell_ids = _normalize_string_array(state, get_or_new_array(state, secondary_spellbook, key::known_spell_ids));
	const ArrayRef known_spell_ids = gd::duplicate_array(state, primary_known_spell_ids);
	for (const Value &spell_id : gd::items(state, array_value(secondary_known_spell_ids))) {
		if (!gd::array_has(state, known_spell_ids, spell_id)) {
			state.append(known_spell_ids, spell_id);
		}
	}
	if (state.array_size(known_spell_ids) != 0) {
		state.set(spellbook, str(key::known_spell_ids), array_value(known_spell_ids));
	}

	const DictRef mana = dict_field_or_new(state, spellbook, key::mana);
	const DictRef secondary_mana = dict_field_or_new(state, secondary_spellbook, key::mana);
	if (state.array_size(primary_known_spell_ids) == 0 && state.array_size(secondary_known_spell_ids) != 0 && !gd::is_empty(state, secondary_mana)) {
		state.set(spellbook, str(key::mana), dict_value(gd::deep_duplicate_dict(state, secondary_mana)));
	} else if (gd::is_empty(state, mana) && !gd::is_empty(state, secondary_mana)) {
		state.set(spellbook, str(key::mana), dict_value(gd::deep_duplicate_dict(state, secondary_mana)));
	} else if (!gd::is_empty(state, mana) && !gd::is_empty(state, secondary_mana)) {
		const DictRef merged_mana = gd::deep_duplicate_dict(state, mana);
		if (!state.has(merged_mana, str(key::current)) && state.has(secondary_mana, str(key::current))) {
			state.set(merged_mana, str(key::current), gd::field(state, secondary_mana, key::current));
		}
		if (!state.has(merged_mana, str(key::max)) && state.has(secondary_mana, str(key::max))) {
			state.set(merged_mana, str(key::max), gd::field(state, secondary_mana, key::max));
		}
		state.set(spellbook, str(key::mana), dict_value(merged_mana));
	}

	state.set(merged, str(key::spellbook), dict_value(spellbook));
	return merged;
}

ArrayRef _normalize_string_array(State &state, const Value &value) {
	const ArrayRef results = state.new_array();
	if (gd::is_array(value)) {
		for (const Value &item : gd::items(state, value)) {
			const Atom text = gd::to_string(item);
			if (text != key::empty) {
				state.append(results, str(text));
			}
		}
	}
	return results;
}

ArrayRef _commander_identity_tokens(State &state, DictRef payload) {
	const ArrayRef tokens = state.new_array();
	for (const Atom field : kHeroIdKeys) {
		const Atom token = stripped_string_field(state, payload, field);
		if (token != key::empty && !gd::array_has(state, tokens, str(token))) {
			state.append(tokens, str(token));
		}
	}
	return tokens;
}

bool _commander_identity_tokens_match(State &state, Atom left_token, Atom right_token) {
	if (left_token == key::empty || right_token == key::empty) {
		return false;
	}
	if (left_token == right_token) {
		return true;
	}
	const std::string &left = state.text(left_token);
	const std::string &right = state.text(right_token);
	return ends_with_colon_token(left, right) || ends_with_colon_token(right, left);
}

} // namespace battle_ai_rules

namespace difficulty_rules {

double damage_multiplier_for_side(State &state, const Value &session, Atom side) {
	const DictRef profile = profile_for_session(state, session);
	const Atom field = side == key::player ? key::player_damage_multiplier : key::enemy_damage_multiplier;
	return gd::float_field(state, profile, field, 1.0);
}

int64_t initiative_bonus_for_side(State &state, const Value &session, Atom side) {
	const DictRef profile = profile_for_session(state, session);
	const Atom field = side == key::player ? key::player_initiative_bonus : key::enemy_initiative_bonus;
	return gd::int_field(state, profile, field, 0);
}

DictRef profile_for_session(State &state, const Value &session) {
	if (session.kind == state::Kind::Nil) {
		return profile_for_difficulty(state, str(_default_difficulty_id(state)));
	}
	return profile_for_difficulty(state, gd::member(state, session, key::difficulty));
}

Atom _default_difficulty_id(State &) {
	// ScenarioSelectRules.default_difficulty_id().
	return key::normal;
}

DictRef profile_for_difficulty(State &state, const Value &difficulty_id) {
	const Atom normalized_id = normalize_difficulty(state, difficulty_id);
	// DIFFICULTY_PROFILES.get(normalized_id, DIFFICULTY_PROFILES[_default_difficulty_id()]).duplicate(true):
	// normalize_difficulty only answers the profiles' own ids.
	const Atom fallback_id = _default_difficulty_id(state);
	const bool known = normalized_id == key::story || normalized_id == key::normal || normalized_id == key::hard;
	return difficulty_profile(state, known ? normalized_id : fallback_id);
}

Atom normalize_difficulty(State &state, const Value &value) {
	// ScenarioSelectRules.normalize_difficulty(value): the ids of DIFFICULTY_OPTIONS.
	const Atom difficulty_id = gd::to_string(value);
	for (const Atom option_id : { key::story, key::normal, key::hard }) {
		if (option_id == difficulty_id) {
			return difficulty_id;
		}
	}
	return _default_difficulty_id(state);
}

} // namespace difficulty_rules

namespace spell_rules {

DictRef normalize_school_resistance(State &state, const Value &value) {
	const DictRef result = state.new_dict();
	if (gd::is_dict(value)) {
		// value.keys(): a copy.
		const state::ValueList school_keys = state.dict(value.ref).keys.list();
		for (const Value &school_id_value : school_keys) {
			const Atom school_id = gd::to_string(school_id_value);
			bool known = false;
			for (const Atom known_id : kSpellSchoolIds) {
				if (known_id == school_id) {
					known = true;
					break;
				}
			}
			if (!known) {
				continue;
			}
			const int64_t amount = variant_clamp_int(gd::to_int(state, gd::index(state, value.ref, school_id_value)), 0, kMaxSpellResistancePct);
			if (amount > 0) {
				state.set(result, str(school_id), int_value(amount));
			}
		}
	}
	return result;
}

} // namespace spell_rules

} // namespace aurelion::rules::port
