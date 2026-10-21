// OverworldRules for the AI targets: town recruits seeding, economy income,
// building categories and the read-scope caches.

#include "aurelion_rules/port/overworld_rules_ai.hpp"

#include "aurelion_rules/port/ai_port.hpp"
#include "aurelion_rules/port/scenario_factory_ai.hpp"
#include "aurelion_rules/compat/godot_string.hpp"

#include <algorithm>
#include <cstddef>
#include <string>
#include <vector>

namespace aurelion::rules::port {

namespace {

using gd::array_value;
using gd::ArrayRef;
using gd::Atom;
using gd::dict_value;
using gd::DictRef;
using gd::int_value;
using gd::str;
using state::ContentTable;
using state::Kind;
using state::State;
using state::Value;
namespace key = state::key;
// OverworldRules.BUILDING_CATEGORIES.
constexpr Atom kBuildingCategories[] = {
	key::civic,
	key::dwelling,
	key::economy,
	key::support,
	key::magic,
};
// OverworldRules.LIVE_STOCKPILE_RESOURCE_KEYS.
constexpr Atom kLiveStockpileResourceKeys[] = {
	key::gold,
	key::wood,
	key::ore,
	key::aetherglass,
	key::embergrain,
	key::peatwax,
	key::verdant_grafts,
	key::brass_scrip,
	key::memory_salt,
};
bool is_building_category(Atom category) {
	for (const Atom listed : kBuildingCategories) {
		if (listed == category) {
			return true;
		}
	}
	return false;
}
bool is_live_stockpile_resource(Atom resource_id) {
	for (const Atom listed : kLiveStockpileResourceKeys) {
		if (listed == resource_id) {
			return true;
		}
	}
	return false;
}
[[noreturn]] void json_not_ported(const std::string &what) {
	throw state::NotPorted("OverworldRules._read_scope_town_digest: JSON.stringify of " + what);
}
// String::json_escape(): the backslash, \b \f \n \r \t \v and the quote. Any
// other control character is left to GDScript.
void append_json_escaped(const std::string &text, std::string &out) {
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
					json_not_ported("a control character");
				}
				out += c;
				break;
		}
	}
}
void append_json_string(const std::string &text, std::string &out) {
	out += '"';
	append_json_escaped(text, out);
	out += '"';
}
bool json_open(const std::vector<Value> &open, const Value &value) {
	for (const Value &container : open) {
		if (container.kind == value.kind && container.ref == value.ref) {
			return true;
		}
	}
	return false;
}
// JSON._stringify with no indent and sorted keys (JSON.stringify(value)): null,
// bools, ints, Strings, StringNames, Vector2i, Vector3i, Arrays and
// Dictionaries whose keys are all Strings or all ints. Floats (String::num),
// packed arrays, other key sets and circular structures are left to GDScript.
void append_json(const State &state, const Value &value, int depth, std::vector<Value> &open, std::string &out) {
	if (depth > 1024) {
		json_not_ported("a structure nested too deep");
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
		case Kind::Vector2i:
			append_json_string("(" + compat::itos(value.vx()) + ", " + compat::itos(value.vy()) + ")", out);
			return;
		case Kind::Vector3i:
			append_json_string("(" + compat::itos(value.vx()) + ", " + compat::itos(value.vy()) + ", " + compat::itos(value.vz()) + ")", out);
			return;
		case Kind::Array: {
			if (json_open(open, value)) {
				json_not_ported("a circular Array");
			}
			open.push_back(value);
			out += '[';
			const int64_t size = state.array_size(value.ref);
			for (int64_t index = 0; index < size; ++index) {
				if (index > 0) {
					out += ',';
				}
				append_json(state, state.at(value.ref, index), depth + 1, open, out);
			}
			out += ']';
			open.pop_back();
			return;
		}
		case Kind::Dict: {
			if (json_open(open, value)) {
				json_not_ported("a circular Dictionary");
			}
			const state::DictNode &node = state.dict(value.ref);
			const state::ValueList keys = node.keys.list();
			const state::ValueList values = node.values;
			bool string_keys = true;
			bool int_keys = true;
			for (const Value &entry_key : keys) {
				string_keys = string_keys && entry_key.kind == Kind::String;
				int_keys = int_keys && entry_key.kind == Kind::Int;
			}
			if (!string_keys && !int_keys) {
				json_not_ported("a Dictionary with keys other than all Strings or all ints");
			}
			// Keys are distinct, so any sort gives Godot's order.
			std::vector<size_t> order(keys.size());
			for (size_t index = 0; index < order.size(); ++index) {
				order[index] = index;
			}
			if (string_keys) {
				std::sort(order.begin(), order.end(), [&](size_t a, size_t b) { return state.text(keys.begin()[a].ref) < state.text(keys.begin()[b].ref); });
			} else {
				std::sort(order.begin(), order.end(), [&](size_t a, size_t b) { return keys.begin()[a].i < keys.begin()[b].i; });
			}
			open.push_back(value);
			out += '{';
			for (size_t position = 0; position < order.size(); ++position) {
				if (position > 0) {
					out += ',';
				}
				const Value &entry_key = keys.begin()[order[position]];
				append_json_string(string_keys ? state.text(entry_key.ref) : compat::itos(entry_key.i), out);
				out += ':';
				append_json(state, values.begin()[order[position]], depth + 1, open, out);
			}
			out += '}';
			open.pop_back();
			return;
		}
		default:
			json_not_ported(gd::type_name(value));
	}
}
// JSON.stringify(town).sha256_text().
Atom town_json_digest(State &state, DictRef town) {
	std::string json;
	std::vector<Value> open;
	append_json(state, dict_value(town), 0, open, json);
	return state.intern(compat::sha256_text(json));
}
// town.hash(), which never fails in GDScript: a value gd::hash does not cover
// is left to GDScript.
int64_t town_hash(State &state, DictRef town) {
	try {
		return gd::hash(state, dict_value(town));
	} catch (const state::ScriptError &) {
		throw state::NotPorted("OverworldRules._read_scope_town_digest: town.hash() of a value the port does not hash");
	}
}
// entry[index] = value of a digest entry (an Array the digest function made).
void set_digest_entry(State &state, const Value &entry, int64_t index, const Value &value) {
	if (!gd::is_array(entry)) {
		throw state::NotPorted("OverworldRules._read_scope_town_digest: a digest entry that is not an Array");
	}
	state.set_at(entry.ref, index, value);
}

} // namespace

namespace overworld_rules {

DictRef _seed_scenario_recruits_for_town_state(State &state, DictRef town) {
	return scenario_factory::_seed_recruits_for_town_state(state, town);
}

Atom _town_read_scope_cache_key(State &state, DictRef session, Atom kind, DictRef town, Atom extra) {
	// session == null cannot happen: a session is its view.
	if (ai::static_int(state, key::overworld_rules_script, key::_normalized_read_scope_depth) <= 0 ||
			gd::stringify(state, gd::index(state, session, str(key::session_id))) != gd::to_string(gd::static_var(state, key::overworld_rules_script, key::_normalized_read_scope_session_id))) {
		return key::empty;
	}
	(void)kind;
	(void)town;
	(void)extra;
	throw state::NotPorted("OverworldRules._town_read_scope_cache_key: session.get_instance_id()");
}

Atom _read_scope_town_digest(State &state, DictRef town) {
	const int64_t content_hash = town_hash(state, town);
	const ArrayRef digests = ai::static_array(state, key::overworld_rules_script, key::_normalized_read_scope_town_digests);
	for (const Value &entry : gd::items(state, array_value(digests))) {
		if (gd::is_same(state, ai::vindex(state, entry, int_value(0)), dict_value(town))) {
			if (gd::to_int(state, ai::vindex(state, entry, int_value(1))) == content_hash) {
				return gd::stringify(state, ai::vindex(state, entry, int_value(2)));
			}
			const Atom refreshed = town_json_digest(state, town);
			set_digest_entry(state, entry, 1, int_value(content_hash));
			set_digest_entry(state, entry, 2, str(refreshed));
			return refreshed;
		}
	}
	const Atom digest = town_json_digest(state, town);
	if (state.array_size(digests) < 64) {
		const ArrayRef entry = state.new_array();
		state.append(entry, dict_value(town));
		state.append(entry, int_value(content_hash));
		state.append(entry, str(digest));
		state.append(digests, array_value(entry));
	}
	return digest;
}

Value _town_read_scope_cache_get(State &state, Atom cache_key) {
	const DictRef cache = ai::static_dict(state, key::overworld_rules_script, key::_normalized_read_scope_cache);
	const Value value = state.get(cache, str(cache_key), Value());
	if (gd::is_dict(value) || gd::is_array(value)) {
		return gd::duplicate_value(state, value, true);
	}
	return value;
}

void _town_read_scope_cache_store(State &state, Atom cache_key, const Value &value) {
	if (cache_key == key::empty) {
		return;
	}
	const DictRef cache = ai::static_dict(state, key::overworld_rules_script, key::_normalized_read_scope_cache);
	state.set(cache, str(cache_key), gd::is_dict(value) || gd::is_array(value) ? gd::duplicate_value(state, value, true) : value);
	const int64_t entries = state.dict_size(ai::static_dict(state, key::overworld_rules_script, key::_normalized_read_scope_cache));
	state.set(ai::static_dict(state, key::overworld_rules_script, key::_last_normalized_read_scope_cache_profile), str(key::entries), int_value(entries));
}

DictRef _build_status_copy(State &state, DictRef status) {
	const DictRef copy = gd::duplicate_dict(state, status);
	const Value blockers = state.get(copy, str(key::blockers), Value());
	if (gd::is_array(blockers)) {
		state.set(copy, str(key::blockers), array_value(gd::duplicate_array(state, blockers.ref)));
	}
	return copy;
}

DictRef _seed_recruits_for_town(State &state, DictRef town) {
	const DictRef normalized_town = gd::deep_duplicate_dict(state, town);
	const ArrayRef built_buildings = _normalize_built_buildings_for_town_state(state, normalized_town);
	state.set(normalized_town, str(key::built_buildings), array_value(built_buildings));
	return _seed_scenario_recruits_for_town_state(state, normalized_town);
}

void _append_building_with_requirements(State &state, ArrayRef target, Atom building_id, ArrayRef trail) {
	if (building_id == key::empty || gd::array_has(state, target, str(building_id)) || gd::array_has(state, trail, str(building_id))) {
		return;
	}
	const ArrayRef next_trail = gd::deep_duplicate_array(state, trail);
	state.append(next_trail, str(building_id));
	const DictRef building = gd::content_row(state, ContentTable::Building, building_id);
	const Atom upgrade_from = ai::string_or_empty(state, building, key::upgrade_from);
	if (upgrade_from != key::empty) {
		_append_building_with_requirements(state, target, upgrade_from, next_trail);
	}
	for (const Value &requirement_value : gd::field_items(state, building, str(key::requires_))) {
		_append_building_with_requirements(state, target, gd::stringify(state, requirement_value), next_trail);
	}
	state.append(target, str(building_id));
}

DictRef _economy_profile_income(State &state, const Value &profile, ArrayRef built_buildings) {
	DictRef income = state.new_dict();
	state.set(income, str(key::gold), int_value(0));
	state.set(income, str(key::wood), int_value(0));
	state.set(income, str(key::ore), int_value(0));
	if (!gd::is_dict(profile)) {
		return income;
	}
	// A missing base income reads as {}, which adds nothing, as null does.
	income = _add_resource_sets(state, dict_value(income), gd::field(state, profile.ref, key::base_income));
	Value per_category_income;
	const bool has_per_category = state.lookup(profile.ref, str(key::per_category_income), per_category_income);
	if (has_per_category && !gd::is_dict(per_category_income)) {
		return income;
	}
	const DictRef category_counts = _building_category_counts(state, built_buildings);
	if (!has_per_category) {
		return income;
	}
	const ArrayRef categories = gd::keys(state, per_category_income.ref);
	for (const Value &category_value : gd::items(state, array_value(categories))) {
		const Atom category = gd::stringify(state, category_value);
		const Value cost = gd::index(state, per_category_income.ref, str(category));
		const int64_t count = gd::int_field(state, category_counts, category, 0);
		const DictRef scaled = _multiply_cost(state, cost, count);
		income = _add_resource_sets(state, dict_value(income), dict_value(scaled));
	}
	return income;
}

DictRef _building_category_counts(State &state, ArrayRef built_buildings) {
	const DictRef counts = state.new_dict();
	for (const Atom category : kBuildingCategories) {
		state.set(counts, str(category), int_value(0));
	}
	for (const Value &building_id_value : gd::items(state, array_value(built_buildings))) {
		const Atom category = _building_category(state, gd::stringify(state, building_id_value));
		state.set(counts, str(category), int_value(gd::add(gd::int_field(state, counts, category, 0), 1)));
	}
	return counts;
}

Atom _building_category(State &state, Atom building_id) {
	const DictRef building = gd::content_row(state, ContentTable::Building, building_id);
	const Atom category = gd::stringify(state, state.get(building, str(key::category), str(key::support)));
	return is_building_category(category) ? category : key::support;
}

DictRef _multiply_cost(State &state, const Value &cost, int64_t multiplier) {
	const DictRef scaled = state.new_dict();
	if (gd::is_dict(cost)) {
		const ArrayRef cost_keys = gd::keys(state, cost.ref);
		for (const Value &cost_key : gd::items(state, array_value(cost_keys))) {
			const Atom resource_key = gd::stringify(state, cost_key);
			const int64_t amount = gd::to_int(state, gd::index(state, cost.ref, cost_key));
			state.set(scaled, str(resource_key), int_value(gd::mul(amount, multiplier)));
		}
	}
	return scaled;
}

DictRef resource_definition(State &state, Atom resource_id) {
	const Atom normalized_id = gd::strip_edges(state, resource_id);
	if (!is_live_stockpile_resource(normalized_id)) {
		return state.new_dict();
	}
	const DictRef resource = gd::content_row(state, ContentTable::Resource, normalized_id);
	if (ai::string_or_empty(state, resource, key::id) == normalized_id && gd::bool_field(state, resource, key::stockpile, false)) {
		return gd::deep_duplicate_dict(state, resource);
	}
	return state.new_dict();
}

} // namespace overworld_rules

} // namespace aurelion::rules::port
