// GeneratedNeutralEncounterRules: a random map's monster guard as a neutral
// company of the content, with the battle power of the native guard's budget.

#include "aurelion_rules/port/generated_neutral_encounter_rules.hpp"

#include "aurelion_rules/compat/godot_string.hpp"
#include "aurelion_rules/port/ai_hero_rules_ai.hpp"
#include "aurelion_rules/port/ai_port.hpp"

#include <initializer_list>
#include <string>
#include <utility>
#include <vector>

namespace aurelion::rules::port {

namespace {

using gd::array_value;
using gd::ArrayRef;
using gd::Atom;
using gd::bool_value;
using gd::dict_value;
using gd::DictRef;
using gd::float_value;
using gd::int_value;
using gd::str;
using state::ContentTable;
using state::State;
using state::Value;
namespace key = state::key;

constexpr Atom kScript = key::generated_neutral_encounter_rules_script;

// {"a": x, "b": y}: the keys set in the literal's order.
DictRef dict_of(State &state, std::initializer_list<std::pair<Atom, Value>> fields) {
	const DictRef dict = state.new_dict();
	for (const auto &field : fields) {
		state.set(dict, str(field.first), field.second);
	}
	return dict;
}

// a.get(k1, {}).get(k2, {})...: false when a key is missing (the chain then
// answers its new fallback, which the caller only reads); a value on the way
// that is not a Dictionary is GDScript's error.
bool get_chain(const State &state, const Value &start, std::initializer_list<Value> path, Value &found) {
	Value at = start;
	for (const Value &step : path) {
		if (!gd::is_dict(at)) {
			(void)ai::vget(state, at, step);
		}
		Value next;
		if (!state.lookup(at.ref, step, next)) {
			return false;
		}
		at = next;
	}
	found = at;
	return true;
}

// String(x.get(key, "")) of an untyped value.
Atom vstring(State &state, const Value &object, Atom field) {
	return gd::stringify(state, ai::vget(state, object, str(field), str(key::empty)));
}

// prefix + text.
Atom concat_text(State &state, Atom prefix, Atom text) {
	return state.intern(state.text(prefix) + state.text(text));
}

// s.split("_")[0]: the text before the first "_".
Atom first_piece(State &state, Atom text) {
	const std::string &source = state.text(text);
	const size_t at = source.find('_');
	return at == std::string::npos ? text : state.intern(source.substr(0, at));
}

// s.hex_to_int() of lower-case hex digits (a SHA-256 digest's prefix).
int64_t hex_digits_to_int(const std::string &digits) {
	int64_t value = 0;
	for (const char c : digits) {
		value = value * 16 + (c >= 'a' ? c - 'a' + 10 : c - '0');
	}
	return value;
}

// int(round(x)).
int64_t round_to_int(double x) {
	return compat::float_to_int(compat::godot_round(x));
}

} // namespace

namespace generated_neutral_encounter_rules {

DictRef resolve(State &state, DictRef placement) {
	if (!state.has(placement, str(key::native_guard_quantity))) {
		return dict_of(state, { { key::ok, bool_value(true) }, { key::encounter, dict_value(gd::deep_duplicate_dict(state, placement)) }, { key::legacy, bool_value(true) } });
	}
	const int64_t quantity = gd::int_field(state, placement, key::native_guard_quantity, -1);
	const int64_t source_level = gd::int_field(state, placement, key::native_guard_level, -1);
	const int64_t subtype = gd::int_field(state, placement, key::native_guard_creature_subtype, -1);
	const int64_t source_value = gd::int_field(state, placement, key::native_guard_ai_value, -1);
	if (quantity <= 0 || quantity > 65535 || source_level < 0 || source_level > 6 || subtype < 0 || source_value <= 0) {
		return dict_of(state, { { key::ok, bool_value(false) }, { key::error, str(key::native_neutral_quantity_or_species_invalid) }, { key::placement_id, state.get(placement, str(key::placement_id), str(key::empty)) } });
	}
	const DictRef catalog = gd::content_file(state, key::generated_neutral_companies_path);
	const DictRef company = _pick_company(state, catalog, source_level + 1, ai::string_or_empty(state, placement, key::placement_id), quantity);
	if (gd::is_empty(state, company)) {
		return dict_of(state, { { key::ok, bool_value(false) }, { key::error, str(key::native_neutral_tier_has_no_original_profile) } });
	}
	const int64_t budget = gd::mul(quantity, source_value);
	const double rate = gd::float_field(state, catalog, key::power_per_native_value, 0.0);
	const DictRef result = _apply_company(state, placement, company, static_cast<double>(budget) * rate);
	if (gd::bool_field(state, result, key::ok, false)) {
		const DictRef provenance = gd::as_dict(ai::vmember(state, gd::index(state, result, str(key::encounter)), key::generated_neutral_profile));
		state.set(provenance, str(key::source_quantity), int_value(quantity));
		state.set(provenance, str(key::source_subtype), int_value(subtype));
		state.set(provenance, str(key::source_level), int_value(source_level));
		state.set(provenance, str(key::source_value), int_value(source_value));
		state.set(provenance, str(key::native_budget), int_value(budget));
		state.set(provenance, str(key::power_per_native_value), float_value(rate));
		state.set(provenance, str(key::quantity_policy), str(key::native_budget_as_battle_power_v1));
	}
	return result;
}

DictRef _pick_company(State &state, DictRef catalog, int64_t tier, Atom placement_id, int64_t quantity) {
	Value families_value;
	if (!state.lookup(_company_families(state, catalog), int_value(tier), families_value)) {
		return state.new_dict();
	}
	const ArrayRef families = gd::as_array(families_value);
	const int64_t family_count = state.array_size(families);
	if (family_count == 0) {
		return state.new_dict();
	}
	const ArrayRef members = gd::as_array(state.at(families, _stable_key(state, concat_text(state, key::company_family_v1, placement_id)) % family_count));
	std::vector<int64_t> weights;
	int64_t total = 0;
	for (const Value &company : gd::items(state, array_value(members))) {
		const Atom kind = first_piece(state, vstring(state, company, key::kind));
		int64_t weight = 1;
		// LARGE_NATIVE_QUANTITY 50, LARGE_KINDS; SMALL_NATIVE_QUANTITY 20, SMALL_KINDS.
		const bool large_kind = kind == key::elite || kind == key::cadre || kind == key::warband || kind == key::host;
		const bool small_kind = kind == key::levy || kind == key::pack;
		if ((quantity >= 50 && large_kind) || (quantity <= 20 && small_kind)) {
			weight = 3;
		}
		weights.push_back(weight);
		total += weight;
	}
	if (total == 0) {
		throw state::ScriptError("Division by zero error in operator '%'.");
	}
	int64_t roll = _stable_key(state, concat_text(state, key::company_kind_v1, placement_id)) % total;
	const int64_t member_count = state.array_size(members);
	for (int64_t index = 0; index < member_count; ++index) {
		roll -= weights[static_cast<size_t>(index)];
		if (roll < 0) {
			return gd::as_dict(state.at(members, index));
		}
	}
	return gd::as_dict(state.at(members, member_count - 1));
}

DictRef _company_families(State &state, DictRef catalog) {
	if (gd::is_same(state, dict_value(catalog), gd::static_var(state, kScript, key::_families_source))) {
		return ai::static_dict(state, kScript, key::_families_by_tier);
	}
	const DictRef by_tier = state.new_dict();
	const DictRef family_index = state.new_dict();
	for (const Value &company : gd::field_items(state, catalog, str(key::companies))) {
		const int64_t tier = gd::to_int(state, ai::vget(state, company, str(key::tier), int_value(-1)));
		const Value family_key = str(gd::format(state, key::d_s, { int_value(tier), str(vstring(state, company, key::family)) }));
		if (!state.has(family_index, family_key)) {
			state.set(family_index, family_key, array_value(state.new_array()));
			if (!state.has(by_tier, int_value(tier))) {
				state.set(by_tier, int_value(tier), array_value(state.new_array()));
			}
			state.append(gd::as_array(gd::index(state, by_tier, int_value(tier))), gd::index(state, family_index, family_key));
		}
		state.append(gd::as_array(gd::index(state, family_index, family_key)), company);
	}
	gd::set_static_var(state, kScript, key::_families_source, dict_value(catalog));
	gd::set_static_var(state, kScript, key::_families_by_tier, dict_value(by_tier));
	return by_tier;
}

DictRef _apply_company(State &state, DictRef placement, DictRef company, double power) {
	const Atom encounter_id = ai::string_or_empty(state, company, key::encounter_id);
	if (gd::is_empty(state, gd::content_row(state, ContentTable::Encounter, encounter_id))) {
		return dict_of(state, { { key::ok, bool_value(false) }, { key::error, str(key::native_neutral_original_profile_missing) }, { key::company_id, state.get(company, str(key::id), str(key::empty)) } });
	}
	Value slots_value;
	const bool has_slots = state.lookup(company, str(key::slots), slots_value);
	if (has_slots) {
		(void)gd::as_array(slots_value);
	}
	if (!has_slots || state.array_size(slots_value.ref) == 0) {
		return dict_of(state, { { key::ok, bool_value(false) }, { key::error, str(key::native_neutral_original_profile_missing) }, { key::company_id, state.get(company, str(key::id), str(key::empty)) } });
	}
	const ArrayRef slots = slots_value.ref;
	const Atom primary_id = vstring(state, state.at(slots, 0), key::unit_id);
	const Atom asset_id = ai::string_or_empty(state, company, key::asset_id);
	if (!_company_art_ready(state, asset_id, primary_id)) {
		return dict_of(state, { { key::ok, bool_value(false) }, { key::error, str(key::native_neutral_original_art_missing) }, { key::asset_id, str(asset_id) }, { key::unit_id, str(primary_id) } });
	}
	std::vector<int64_t> counts;
	double carried = 0.0;
	const int64_t slot_count = state.array_size(slots);
	for (int64_t index = 0; index < slot_count; ++index) {
		const double unit_power = _unit_power(state, vstring(state, state.at(slots, index), key::unit_id));
		if (unit_power <= 0.0) {
			return dict_of(state, { { key::ok, bool_value(false) }, { key::error, str(key::native_neutral_original_profile_missing) }, { key::unit_id, ai::vget(state, state.at(slots, index), str(key::unit_id), str(key::empty)) } });
		}
		const double share = gd::to_float(ai::vget(state, state.at(slots, index), str(key::share), float_value(0.0)));
		int64_t count = round_to_int(power * share / unit_power);
		if (index > 0 && count < 1) {
			carried += share;
			count = 0;
		}
		counts.push_back(count);
	}
	const double first_share = gd::to_float(ai::vget(state, state.at(slots, 0), str(key::share), float_value(0.0)));
	counts[0] = compat::engine_max<int64_t>(1, round_to_int(power * (first_share + carried) / _unit_power(state, primary_id)));
	const int64_t seed = _stable_key(state, ai::string_or_empty(state, placement, key::placement_id));
	const int64_t primary_groups = compat::engine_min<int64_t>(counts[0], 1 + (seed / 3) % 3);
	const ArrayRef stacks = state.new_array();
	for (int64_t index = 0; index < primary_groups; ++index) {
		const int64_t count = counts[0] / primary_groups + (index < counts[0] % primary_groups ? 1 : 0);
		state.append(stacks, dict_value(dict_of(state, { { key::unit_id, str(primary_id) }, { key::count, int_value(count) } })));
	}
	int64_t total = counts[0];
	for (int64_t index = 1; index < slot_count; ++index) {
		const int64_t count = counts[static_cast<size_t>(index)];
		if (count > 0) {
			state.append(stacks, dict_value(dict_of(state, { { key::unit_id, str(vstring(state, state.at(slots, index), key::unit_id)) }, { key::count, int_value(count) } })));
			total = gd::add(total, count);
		}
	}
	const Atom company_id = ai::string_or_empty(state, company, key::id);
	const DictRef army = dict_of(state, {
		{ key::id, str(concat_text(state, key::army_, company_id)) },
		{ key::name, str(ai::string_or_empty(state, company, key::name)) },
		{ key::affiliation, str(key::neutral) },
		{ key::stacks, array_value(stacks) },
	});
	const DictRef encounter = gd::deep_duplicate_dict(state, placement);
	state.set(encounter, str(key::encounter_id), str(encounter_id));
	state.set(encounter, str(key::object_id), str(encounter_id));
	state.set(encounter, str(key::enemy_army), dict_value(army));
	state.set(encounter, str(key::prefer_identity_landmark), bool_value(true));
	const Atom profile_company_id = ai::string_or_empty(state, company, key::id);
	const Atom kind = ai::string_or_empty(state, company, key::kind);
	const Atom faction_id = ai::string_or_empty(state, company, key::faction_id);
	const int64_t power_target = round_to_int(power);
	const int64_t army_power = round_to_int(_army_power(state, stacks));
	const bool pure = state.array_size(stacks) == primary_groups;
	state.set(encounter, str(key::generated_neutral_profile), dict_value(dict_of(state, {
		{ key::version, int_value(2) },
		{ key::company_id, str(profile_company_id) },
		{ key::encounter_id, str(encounter_id) },
		{ key::asset_id, str(asset_id) },
		{ key::primary_unit_id, str(primary_id) },
		{ key::kind, str(kind) },
		{ key::faction_id, str(faction_id) },
		{ key::power_target, int_value(power_target) },
		{ key::power, int_value(army_power) },
		{ key::total_quantity, int_value(total) },
		{ key::formation, str(pure ? key::pure : key::mixed) },
	})));
	return dict_of(state, { { key::ok, bool_value(true) }, { key::encounter, dict_value(encounter) } });
}

bool _company_art_ready(State &state, Atom asset_id, Atom unit_id) {
	Value found;
	if (asset_id != key::empty) {
		if (!get_chain(state, dict_value(gd::content_file(state, key::res_art_overworld_manifest_json)), { str(key::object_assets), str(asset_id) }, found)) {
			return false;
		}
		const DictRef asset = gd::as_dict(found);
		return !gd::is_empty(state, asset) && gd::resource_exists(state, ai::string_or_empty(state, asset, key::path));
	}
	if (!get_chain(state, dict_value(gd::content_file(state, key::res_art_overworld_creature_idle_json)), { str(key::units), str(unit_id) }, found)) {
		return false;
	}
	const DictRef idle = gd::as_dict(found);
	return !gd::is_empty(state, idle) && gd::resource_exists(state, ai::string_or_empty(state, idle, key::path));
}

ArrayRef stacks_for_native_budget(State &state, ArrayRef native_stacks, ArrayRef unit_ids) {
	const double rate = gd::float_field(state, gd::content_file(state, key::generated_neutral_companies_path), key::power_per_native_value, 0.0);
	const int64_t stack_count = state.array_size(native_stacks);
	if (rate <= 0.0 || stack_count > state.array_size(unit_ids)) {
		return state.new_array();
	}
	std::vector<double> budgets;
	// pooled: unit id -> budget, in insertion order.
	std::vector<std::pair<Atom, double>> pooled;
	for (int64_t index = 0; index < stack_count; ++index) {
		const Atom unit_id = gd::stringify(state, state.at(unit_ids, index));
		if (_unit_power(state, unit_id) <= 0.0) {
			return state.new_array();
		}
		const ArrayRef native = gd::as_array(state.at(native_stacks, index));
		const double budget = compat::engine_max(0.0, gd::to_float(state.at(native, 0)) * gd::to_float(state.at(native, 1)) * rate);
		budgets.push_back(budget);
		bool pooled_before = false;
		for (auto &entry : pooled) {
			if (entry.first == unit_id) {
				entry.second = entry.second + budget;
				pooled_before = true;
				break;
			}
		}
		if (!pooled_before) {
			pooled.emplace_back(unit_id, 0.0 + budget);
		}
	}
	std::vector<int64_t> counts(static_cast<size_t>(stack_count), 0);
	struct Share {
		double remainder;
		int64_t index;
	};
	for (const auto &entry : pooled) {
		const Atom unit_id = entry.first;
		const double pool = entry.second;
		const int64_t total = compat::engine_max<int64_t>(1, round_to_int(pool / _unit_power(state, unit_id)));
		std::vector<Share> shares;
		int64_t given = 0;
		for (int64_t index = 0; index < stack_count; ++index) {
			if (gd::stringify(state, state.at(unit_ids, index)) != unit_id) {
				continue;
			}
			const double exact = pool > 0.0 ? static_cast<double>(total) * budgets[static_cast<size_t>(index)] / pool : static_cast<double>(total);
			counts[static_cast<size_t>(index)] = compat::float_to_int(compat::godot_floor(exact));
			given = gd::add(given, counts[static_cast<size_t>(index)]);
			shares.push_back({ exact - compat::godot_floor(exact), index });
			if (pool <= 0.0) {
				break;
			}
		}
		// The creatures left over go to the stacks with the largest remainders.
		compat::sort_custom(shares.data(), static_cast<int64_t>(shares.size()), [](const Share &a, const Share &b) {
			return a.remainder > b.remainder || (a.remainder == b.remainder && a.index < b.index);
		});
		const int64_t extra = compat::engine_min<int64_t>(gd::sub(total, given), static_cast<int64_t>(shares.size()));
		for (int64_t share_index = 0; share_index < extra; ++share_index) {
			counts[static_cast<size_t>(shares[static_cast<size_t>(share_index)].index)] += 1;
		}
	}
	const ArrayRef stacks = state.new_array();
	for (int64_t index = 0; index < stack_count; ++index) {
		const int64_t count = counts[static_cast<size_t>(index)];
		if (count > 0) {
			state.append(stacks, dict_value(dict_of(state, { { key::unit_id, str(gd::stringify(state, state.at(unit_ids, index))) }, { key::count, int_value(count) } })));
		}
	}
	return stacks;
}

double _unit_power(State &state, Atom unit_id) {
	const ArrayRef stacks = state.new_array();
	state.append(stacks, dict_value(dict_of(state, { { key::unit_id, str(unit_id) }, { key::count, int_value(1) } })));
	return _army_power(state, stacks);
}

double _army_power(State &state, ArrayRef stacks) {
	// AiHeroRules.army_power(stacks) with its default commander {}.
	return ai_hero_rules::army_power(state, array_value(stacks), dict_value(state.new_dict()));
}

DictRef resolve_supplemental(State &state, DictRef placement, Atom site_id) {
	const DictRef catalog = gd::content_file(state, key::generated_neutral_encounter_profiles_path);
	Value encounter_value = str(key::empty);
	Value sites;
	if (state.lookup(catalog, str(key::supplemental_sites), sites)) {
		encounter_value = ai::vget(state, sites, str(site_id), str(key::empty));
	}
	const Atom encounter_id = gd::stringify(state, encounter_value);
	DictRef profile = state.new_dict();
	for (const Value &candidate : gd::field_items(state, catalog, str(key::profiles))) {
		if (vstring(state, candidate, key::encounter_id) == encounter_id) {
			profile = gd::as_dict(candidate);
		}
	}
	if (gd::is_empty(state, profile)) {
		return dict_of(state, { { key::ok, bool_value(false) }, { key::error, str(key::supplemental_neutral_site_profile_missing) }, { key::site_id, str(site_id) } });
	}
	const DictRef previous = gd::content_row(state, ContentTable::Encounter, ai::string_or_empty(state, placement, key::encounter_id));
	const DictRef previous_army = gd::content_row(state, ContentTable::ArmyGroup, ai::string_or_empty(state, previous, key::enemy_group_id));
	const int64_t budget = _army_strength(state, previous_army);
	const DictRef army = gd::content_row(state, ContentTable::ArmyGroup, ai::string_or_empty(state, profile, key::army_group_id));
	int64_t minimum_cost = gd::add(budget, 1);
	for (const Value &stack : gd::field_items(state, army, str(key::stacks))) {
		minimum_cost = compat::engine_min<int64_t>(minimum_cost, _unit_strength(state, vstring(state, stack, key::unit_id)));
	}
	if (budget <= 0 || minimum_cost <= 0) {
		return dict_of(state, { { key::ok, bool_value(false) }, { key::error, str(key::supplemental_neutral_original_army_missing) } });
	}
	// The original-game supplemental guard keeps its army-strength ceiling.
	for (int64_t quantity = budget / minimum_cost; quantity > 0; --quantity) {
		const DictRef result = _apply_profile(state, placement, profile, quantity);
		if (!gd::bool_field(state, result, key::ok, false)) {
			return result;
		}
		const Value encounter = gd::index(state, result, str(key::encounter));
		if (_army_strength(state, gd::as_dict(ai::vmember(state, encounter, key::enemy_army))) <= budget) {
			const DictRef profile_out = gd::as_dict(ai::vmember(state, encounter, key::generated_neutral_profile));
			state.set(profile_out, str(key::quantity_policy), str(key::existing_supplemental_army_strength_ceiling));
			state.set(profile_out, str(key::original_strength_ceiling), int_value(budget));
			state.set(profile_out, str(key::site_id), str(site_id));
			return result;
		}
	}
	return dict_of(state, { { key::ok, bool_value(false) }, { key::error, str(key::supplemental_neutral_budget_cannot_fit_unit) } });
}

int64_t _army_strength(State &state, DictRef army) {
	int64_t total = 0;
	for (const Value &stack : gd::field_items(state, army, str(key::stacks))) {
		const int64_t count = gd::to_int(state, ai::vget(state, stack, str(key::count), int_value(0)));
		total = gd::add(total, gd::mul(count, _unit_strength(state, vstring(state, stack, key::unit_id))));
	}
	return total;
}

DictRef with_authored_guard_art(State &state, DictRef placement) {
	const DictRef result = gd::deep_duplicate_dict(state, placement);
	const Atom encounter_id = ai::string_or_empty(state, result, key::encounter_id);
	for (const Value &profile : gd::field_items(state, gd::content_file(state, key::generated_neutral_encounter_profiles_path), str(key::profiles))) {
		if (vstring(state, profile, key::encounter_id) != encounter_id) {
			continue;
		}
		state.set(result, str(key::prefer_identity_landmark), bool_value(true));
		const Atom asset_id = vstring(state, profile, key::asset_id);
		state.set(result, str(key::generated_neutral_profile), dict_value(dict_of(state, {
			{ key::version, int_value(1) },
			{ key::encounter_id, str(encounter_id) },
			{ key::asset_id, str(asset_id) },
			{ key::quantity_policy, str(key::authored_guard_contract_unchanged) },
		})));
		break;
	}
	return result;
}

DictRef with_lead_unit_art(State &state, DictRef placement, Atom quantity_policy) {
	const DictRef result = gd::deep_duplicate_dict(state, placement);
	// result.get("enemy_army", {}).get("stacks", []) if result.get("enemy_army", {}) is Dictionary else []
	ArrayRef stacks = 0;
	bool have_stacks = false;
	Value army;
	if (state.lookup(result, str(key::enemy_army), army) && gd::is_dict(army)) {
		Value found;
		if (state.lookup(army.ref, str(key::stacks), found)) {
			stacks = gd::as_array(found);
			have_stacks = true;
		}
	}
	if (!have_stacks) {
		stacks = state.new_array();
	}
	Atom lead = key::empty;
	double lead_power = -1.0;
	int64_t total = 0;
	std::vector<Atom> unit_ids;
	for (int64_t index = 0; index < state.array_size(stacks); ++index) {
		const Value stack = state.at(stacks, index);
		if (!gd::is_dict(stack)) {
			continue;
		}
		const ArrayRef single = state.new_array();
		state.append(single, stack);
		const double power = _army_power(state, single);
		total = gd::add(total, gd::int_field(state, stack.ref, key::count, 0));
		const Atom unit_id = ai::string_or_empty(state, stack.ref, key::unit_id);
		bool listed = false;
		for (const Atom listed_id : unit_ids) {
			if (listed_id == unit_id) {
				listed = true;
				break;
			}
		}
		if (!listed) {
			unit_ids.push_back(unit_id);
		}
		if (power > lead_power) {
			lead_power = power;
			lead = unit_id;
		}
	}
	if (lead == key::empty || !_company_art_ready(state, key::empty, lead)) {
		return result;
	}
	state.set(result, str(key::prefer_identity_landmark), bool_value(true));
	const Atom encounter_id = ai::string_or_empty(state, result, key::encounter_id);
	const int64_t power = round_to_int(_army_power(state, stacks));
	state.set(result, str(key::generated_neutral_profile), dict_value(dict_of(state, {
		{ key::version, int_value(2) },
		{ key::encounter_id, str(encounter_id) },
		{ key::asset_id, str(key::empty) },
		{ key::primary_unit_id, str(lead) },
		{ key::quantity_policy, str(quantity_policy) },
		{ key::power, int_value(power) },
		{ key::total_quantity, int_value(total) },
		{ key::formation, str(unit_ids.size() == 1 ? key::pure : key::mixed) },
	})));
	return result;
}

int64_t _unit_strength(State &state, Atom unit_id) {
	const DictRef unit = gd::content_row(state, ContentTable::Unit, unit_id);
	if (gd::is_empty(state, unit)) {
		return 0;
	}
	const int64_t hp = gd::int_field(state, unit, key::hp, 1);
	const int64_t min_damage = gd::int_field(state, unit, key::min_damage, 1);
	const int64_t max_damage = gd::int_field(state, unit, key::max_damage, 1);
	const int64_t ranged = gd::bool_field(state, unit, key::ranged, false) ? 3 : 0;
	return compat::engine_max<int64_t>(6, gd::add(gd::add(gd::add(hp, min_damage), max_damage), ranged));
}

DictRef _apply_profile(State &state, DictRef placement, DictRef profile, int64_t quantity) {
	const Atom encounter_id = ai::string_or_empty(state, profile, key::encounter_id);
	const DictRef definition = gd::content_row(state, ContentTable::Encounter, encounter_id);
	const Atom asset_id = ai::string_or_empty(state, profile, key::asset_id);
	const DictRef art = gd::content_file(state, key::res_art_overworld_manifest_json);
	Value asset;
	const bool has_asset = get_chain(state, dict_value(art), { str(key::object_assets), str(asset_id) }, asset);
	if (has_asset) {
		(void)gd::as_dict(asset);
	}
	if (!has_asset || gd::is_empty(state, asset.ref) || !gd::resource_exists(state, ai::string_or_empty(state, asset.ref, key::path))) {
		return dict_of(state, { { key::ok, bool_value(false) }, { key::error, str(key::native_neutral_original_art_missing) }, { key::asset_id, str(asset_id) } });
	}
	const DictRef army = gd::deep_duplicate_dict(state, gd::content_row(state, ContentTable::ArmyGroup, ai::string_or_empty(state, profile, key::army_group_id)));
	Value base_value;
	const bool has_base = state.lookup(army, str(key::stacks), base_value);
	if (has_base) {
		(void)gd::as_array(base_value);
	}
	if (gd::is_empty(state, definition) || !has_base || state.array_size(base_value.ref) == 0) {
		return dict_of(state, { { key::ok, bool_value(false) }, { key::error, str(key::native_neutral_original_profile_missing) } });
	}
	const ArrayRef base_stacks = base_value.ref;
	const int64_t base_count = state.array_size(base_stacks);
	const int64_t seed = _stable_key(state, ai::string_or_empty(state, placement, key::placement_id));
	const Atom primary_id = vstring(state, state.at(base_stacks, 0), key::unit_id);
	const ArrayRef stacks = state.new_array();
	int64_t support_count = 0;
	if (seed % 3 != 0 && base_count > 1 && quantity >= 4) {
		support_count = quantity / 4;
	}
	const int64_t primary_count = quantity - support_count;
	const int64_t primary_groups = compat::engine_min<int64_t>(primary_count, 1 + (seed / 3) % 3);
	for (int64_t index = 0; index < primary_groups; ++index) {
		const int64_t count = primary_count / primary_groups + (index < primary_count % primary_groups ? 1 : 0);
		state.append(stacks, dict_value(dict_of(state, { { key::unit_id, str(primary_id) }, { key::count, int_value(count) } })));
	}
	if (support_count > 0) {
		const int64_t support_index = 1 + (seed / 9) % (base_count - 1);
		state.append(stacks, dict_value(dict_of(state, { { key::unit_id, str(vstring(state, state.at(base_stacks, support_index), key::unit_id)) }, { key::count, int_value(support_count) } })));
	}
	state.set(army, str(key::stacks), array_value(stacks));
	const DictRef encounter = gd::deep_duplicate_dict(state, placement);
	state.set(encounter, str(key::encounter_id), str(encounter_id));
	state.set(encounter, str(key::object_id), str(encounter_id));
	state.set(encounter, str(key::enemy_army), dict_value(army));
	state.set(encounter, str(key::prefer_identity_landmark), bool_value(true));
	state.set(encounter, str(key::generated_neutral_profile), dict_value(dict_of(state, {
		{ key::version, int_value(1) },
		{ key::encounter_id, str(encounter_id) },
		{ key::asset_id, str(asset_id) },
		{ key::total_quantity, int_value(quantity) },
		{ key::formation, str(support_count == 0 ? key::pure : key::mixed) },
	})));
	return dict_of(state, { { key::ok, bool_value(true) }, { key::encounter, dict_value(encounter) } });
}

int64_t _stable_key(State &state, Atom value) {
	// value.sha256_text().substr(0, 8).hex_to_int()
	return hex_digits_to_int(compat::sha256_text(state.text(value)).substr(0, 8));
}

} // namespace generated_neutral_encounter_rules

} // namespace aurelion::rules::port
