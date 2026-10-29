// MapPackageService's generation, adoption and package writes
// (src/gdextension/src/map_package_service.cpp), ported under their names for
// a host without Godot; see aurelion_rules/map_generation.hpp. Each function
// builds the Dictionaries the map library's does, key by key in its order.

#include "aurelion_rules/map_generation.hpp"

#include "aurelion_rules/compat/godot_json.hpp"
#include "aurelion_rules/compat/godot_string.hpp"
#include "aurelion_rules/compat/json_writer.hpp"
#include "aurelion_rules/port/gd.hpp"

#include "h3maped_rmg_core.hpp"
#include "runtime_object_classification.hpp"

#include <algorithm>
#include <chrono>
#include <cmath>
#include <cstdint>
#include <initializer_list>
#include <string_view>
#include <unordered_map>
#include <unordered_set>
#include <utility>
#include <vector>

namespace aurelion::rules::map_generation {

namespace h3 = aurelion::h3maped_rmg_core;
using state::Kind;
using state::State;
using state::Value;

// The map library's GeneratedCore.
struct GeneratorCache::Core {
	std::string key;
	h3::RuntimeMapPayloadProjection projection;
	std::string workflow_status;
	std::string workflow_phase;
	std::string workflow_blocked_reason;
	std::string payload_token;
	int32_t final_payload_byte_count = 0;
	int32_t selected_template_catalog_index = -1;
	int32_t runtime_zone_count = 0;
	bool cut_off_town_repair_applied = false;
	int32_t cut_off_towns_before_repair = 0;
	int32_t cut_off_towns_after_repair = 0;
	std::string split_template_repicked_from;
};

GeneratorCache::GeneratorCache() = default;
GeneratorCache::~GeneratorCache() = default;

namespace {

constexpr const char *kMapSchemaId = "aurelion_map_document";
constexpr const char *kScenarioSchemaId = "aurelion_scenario_document";
constexpr const char *kMapPackageSchemaId = "aurelion_map_package";
constexpr const char *kScenarioPackageSchemaId = "aurelion_scenario_package";
constexpr const char *kNativeRmgSchemaId = "aurelion_native_random_map_config_normalization";
constexpr const char *kNativeRmgVersion = "native_rmg_exact_h3maped_state_chain_v1";
constexpr const char *kProxyCatalogPath = "res://content/homm3_re_reward_object_proxy_catalog.json";
constexpr const char *kProxyCatalogSchema = "homm3_re_reward_object_proxy_catalog_v1";
constexpr const char *kEligibilityPath = "res://content/random_map_object_eligibility.json";
constexpr const char *kEligibilitySchema = "aurelion_random_map_object_eligibility_v1";
constexpr const char *kMapObjectCatalogPath = "res://content/map_objects.json";
constexpr const char *kResourceSiteCatalogPath = "res://content/resource_sites.json";
constexpr const char *kArtifactCatalogPath = "res://content/artifacts.json";
constexpr uint64_t kHashModulus = 4294967296ULL;
// map_document.hpp's SCHEMA_VERSION, MAX_DIMENSION and MAX_LEVEL_COUNT.
constexpr int32_t kSchemaVersion = 1;
constexpr int32_t kMaxDimension = 256;
constexpr int32_t kMaxLevelCount = 2;

using SteadyClock = std::chrono::steady_clock;

double elapsed_milliseconds(const SteadyClock::time_point &started_at) {
	return std::chrono::duration<double, std::milli>(SteadyClock::now() - started_at).count();
}

// ------------------------------------------------------------ values

Value new_dict(State &state) {
	return Value::of_ref(Kind::Dict, state.new_dict());
}

Value new_array(State &state) {
	return Value::of_ref(Kind::Array, state.new_array());
}

Value text(State &state, std::string_view value) {
	return state.string(value);
}

Value integer(int64_t value) {
	return Value::of_int(value);
}

Value boolean(bool value) {
	return Value::of_bool(value);
}

void put(State &state, const Value &dict, const char *key, const Value &value) {
	state.set(dict.ref, state.string(key), value);
}

// dict.get(key, fallback); a value that is no Dictionary has no keys.
Value get(const State &state, const Value &dict, const char *key, const Value &fallback = Value()) {
	uint32_t atom = 0;
	if (dict.kind != Kind::Dict || !state.find_atom(key, atom)) {
		return fallback;
	}
	return state.get(dict.ref, Value::str(atom), fallback);
}

bool has(const State &state, const Value &dict, const char *key) {
	uint32_t atom = 0;
	return dict.kind == Kind::Dict && state.find_atom(key, atom) && state.has(dict.ref, Value::str(atom));
}

void append(State &state, const Value &array, const Value &value) {
	state.append(array.ref, value);
}

int64_t size_of(const State &state, const Value &container) {
	if (container.kind == Kind::Array) {
		return state.array_size(container.ref);
	}
	if (container.kind == Kind::Dict) {
		return state.dict_size(container.ref);
	}
	return 0;
}

bool is_empty(const State &state, const Value &container) {
	return size_of(state, container) == 0;
}

// Dictionary(value) and Array(value) of a Variant: the container, or a new
// empty one.
Value dict_or_new(State &state, const Value &value) {
	return value.kind == Kind::Dict ? value : new_dict(state);
}

Value array_or_new(State &state, const Value &value) {
	return value.kind == Kind::Array ? value : new_array(state);
}

Value deep_copy(State &state, const Value &value) {
	return gd::duplicate_value(state, value, true);
}

Value shallow_copy(State &state, const Value &value) {
	return gd::duplicate_value(state, value, false);
}

// String(value).
std::string string_of(State &state, const Value &value) {
	if (value.is_string_like()) {
		return state.text(value.ref);
	}
	return state.text(gd::stringify(state, value));
}

std::string string_field(State &state, const Value &dict, const char *key, const char *fallback = "") {
	return has(state, dict, key) ? string_of(state, get(state, dict, key)) : std::string(fallback);
}

// int32_t(value) of a Variant: 0 for a value no number converts from.
int32_t int32_of(const State &state, const Value &value) {
	switch (value.kind) {
		case Kind::Int:
		case Kind::Float:
		case Kind::Bool:
		case Kind::String:
		case Kind::StringName:
			return static_cast<int32_t>(gd::to_int(state, value));
		default:
			return 0;
	}
}

int32_t int32_field(const State &state, const Value &dict, const char *key, int32_t fallback) {
	return has(state, dict, key) ? int32_of(state, get(state, dict, key)) : fallback;
}

bool bool_field(const State &state, const Value &dict, const char *key, bool fallback) {
	return has(state, dict, key) ? gd::to_bool(get(state, dict, key)) : fallback;
}

// String::strip_edges: every character up to a space off both ends.
std::string strip(const std::string &value) {
	size_t begin = 0;
	size_t end = value.size();
	while (begin < end && static_cast<unsigned char>(value[begin]) <= 32) {
		++begin;
	}
	while (end > begin && static_cast<unsigned char>(value[end - 1]) <= 32) {
		--end;
	}
	return value.substr(begin, end - begin);
}

// String::to_lower of the ASCII texts the settings hold.
std::string lower(std::string value) {
	for (char &c : value) {
		if (c >= 'A' && c <= 'Z') {
			c = static_cast<char>(c - 'A' + 'a');
		}
	}
	return value;
}

bool begins_with(const std::string &value, const char *prefix) {
	return value.rfind(prefix, 0) == 0;
}

// String::pad_zeros(digits).
std::string pad_zeros(const std::string &value, int digits) {
	size_t end = value.find('.');
	if (end == std::string::npos) {
		end = value.size();
	}
	if (end == 0) {
		return value;
	}
	size_t begin = 0;
	while (begin < end && !(value[begin] >= '0' && value[begin] <= '9')) {
		++begin;
	}
	const int zeros = digits - static_cast<int>(end - begin);
	if (zeros <= 0) {
		return value;
	}
	return value.substr(0, begin) + std::string(static_cast<size_t>(zeros), '0') + value.substr(begin);
}

// String::get_file.
std::string get_file(const std::string &path) {
	const size_t separator = path.find_last_of("/\\");
	return separator == std::string::npos ? path : path.substr(separator + 1);
}

// Array.has(text) of an Array of texts.
bool texts_contain(State &state, const Value &values, const std::string &needle) {
	if (values.kind != Kind::Array) {
		return false;
	}
	const int64_t count = state.array_size(values.ref);
	for (int64_t index = 0; index < count; ++index) {
		if (string_of(state, state.at(values.ref, index)) == needle) {
			return true;
		}
	}
	return false;
}

Value string_array(State &state, std::initializer_list<const char *> values) {
	const Value result = new_array(state);
	for (const char *value : values) {
		append(state, result, text(state, value));
	}
	return result;
}

// ------------------------------------------------------- canonical text

void append_escaped_atom(std::string &out, std::string_view value) {
	for (const char c : value) {
		switch (c) {
			case '\\':
			case '|':
			case '[':
			case ']':
			case '{':
			case '}':
			case ':':
			case ',':
				out += '\\';
				break;
			default:
				break;
		}
		out += c;
	}
}

// canonical_variant(value), into out. A Dictionary's keys sort by their text;
// skip names top-level keys left out (generated_core_key).
void canonical_variant(State &state, const Value &value, std::string &out, const std::unordered_set<std::string> *skip = nullptr) {
	switch (value.kind) {
		case Kind::Nil:
			out += "null";
			return;
		case Kind::Bool:
			out += value.b ? "bool:true" : "bool:false";
			return;
		case Kind::Int:
			out += "int:";
			out += compat::itos(value.i);
			return;
		case Kind::Float:
			out += "float:";
			out += compat::num_real(value.f);
			return;
		case Kind::String:
		case Kind::StringName:
			out += "string:";
			append_escaped_atom(out, state.text(value.ref));
			return;
		case Kind::Dict: {
			const state::ValueList keys = state.dict(value.ref).keys.list();
			std::vector<std::pair<std::string, Value>> sorted;
			sorted.reserve(keys.size());
			for (const Value &key : keys) {
				std::string name = string_of(state, key);
				if (skip != nullptr && skip->count(name) != 0) {
					continue;
				}
				sorted.emplace_back(std::move(name), key);
			}
			std::sort(sorted.begin(), sorted.end(), [](const auto &left, const auto &right) { return left.first < right.first; });
			out += '{';
			for (size_t index = 0; index < sorted.size(); ++index) {
				if (index > 0) {
					out += ',';
				}
				append_escaped_atom(out, sorted[index].first);
				out += ':';
				canonical_variant(state, state.get(value.ref, sorted[index].second, Value()), out);
			}
			out += '}';
			return;
		}
		case Kind::Array: {
			const int64_t count = state.array_size(value.ref);
			out += '[';
			for (int64_t index = 0; index < count; ++index) {
				if (index > 0) {
					out += ',';
				}
				canonical_variant(state, state.at(value.ref, index), out);
			}
			out += ']';
			return;
		}
		case Kind::PackedInt32: {
			const std::vector<int32_t> &ints = state.packed(value.ref).ints;
			out += '[';
			for (size_t index = 0; index < ints.size(); ++index) {
				if (index > 0) {
					out += ',';
				}
				out += "int:";
				out += compat::itos(ints[index]);
			}
			out += ']';
			return;
		}
		case Kind::Opaque:
			out += "object:unsupported";
			return;
		default:
			out += "variant:";
			append_escaped_atom(out, string_of(state, value));
			return;
	}
}

std::string canonical(State &state, const Value &value) {
	std::string out;
	canonical_variant(state, value, out);
	return out;
}

// hash32_int: FNV-1a over the text's code points, mod 2^32.
uint32_t hash32_int(std::string_view utf8) {
	uint64_t value = 2166136261ULL;
	size_t index = 0;
	while (index < utf8.size()) {
		const unsigned char lead = static_cast<unsigned char>(utf8[index]);
		uint32_t code = lead;
		size_t extra = 0;
		if (lead >= 0xF0) {
			code = lead & 0x07U;
			extra = 3;
		} else if (lead >= 0xE0) {
			code = lead & 0x0FU;
			extra = 2;
		} else if (lead >= 0xC0) {
			code = lead & 0x1FU;
			extra = 1;
		}
		++index;
		for (size_t more = 0; more < extra && index < utf8.size(); ++more, ++index) {
			code = (code << 6) | (static_cast<unsigned char>(utf8[index]) & 0x3FU);
		}
		value = (value ^ uint64_t(code)) % kHashModulus;
		value = (value * 16777619ULL) % kHashModulus;
	}
	return uint32_t(value);
}

std::string hex8(uint32_t value) {
	static constexpr const char *kDigits = "0123456789abcdef";
	std::string result;
	for (int index = 7; index >= 0; --index) {
		result += kDigits[(value >> (index * 4)) & 0xFU];
	}
	return result;
}

std::string hash32_hex(std::string_view utf8) {
	return hex8(hash32_int(utf8));
}

std::string hash32_hex_bytes(const std::vector<uint8_t> &bytes) {
	uint32_t value = 2166136261U;
	for (const uint8_t byte : bytes) {
		value = (value ^ uint32_t(byte)) * 16777619U;
	}
	return hex8(value);
}

// ------------------------------------------------- config normalization

std::string normalized_text(State &state, const Value &dict, const char *key, const std::string &fallback) {
	const std::string value = strip(has(state, dict, key) ? string_of(state, get(state, dict, key)) : fallback);
	return value.empty() ? fallback : value;
}

int32_t normalized_int(const State &state, const Value &dict, const char *key, int32_t fallback) {
	return has(state, dict, key) ? int32_of(state, get(state, dict, key)) : fallback;
}

int32_t dimension_for_size_class(const std::string &size_class_id, int32_t fallback) {
	const std::string normalized = lower(strip(size_class_id));
	if (normalized == "small" || normalized == "homm3_small" || normalized == "s") {
		return 36;
	}
	if (normalized == "medium" || normalized == "homm3_medium" || normalized == "m") {
		return 72;
	}
	if (normalized == "large" || normalized == "homm3_large" || normalized == "l") {
		return 108;
	}
	if (normalized == "extra_large" || normalized == "homm3_extra_large" || normalized == "xl") {
		return 144;
	}
	return fallback;
}

std::string normalized_size_class_id(State &state, const Value &config, const Value &size) {
	std::string value = normalized_text(state, size, "size_class_id", normalized_text(state, config, "size_class_id", ""));
	if (value.empty()) {
		value = normalized_text(state, size, "size", normalized_text(state, config, "size", ""));
	}
	value = lower(strip(value));
	if (value == "s") {
		return "small";
	}
	if (value == "m") {
		return "medium";
	}
	if (value == "l") {
		return "large";
	}
	if (value == "xl") {
		return "extra_large";
	}
	if (begins_with(value, "homm3_")) {
		return value.substr(6);
	}
	return value;
}

int32_t nested_size_int(const State &state, const Value &root, const Value &size, const char *key, const char *alternate_key, int32_t fallback) {
	int32_t value = int32_field(state, size, key, 0);
	if (value <= 0) {
		value = int32_field(state, size, alternate_key, 0);
	}
	if (value <= 0) {
		value = int32_field(state, root, key, fallback);
	}
	return std::max<int32_t>(8, std::min<int32_t>(144, value));
}

Value normalized_string_array(State &state, const Value &value, const Value &fallback) {
	const Value result = new_array(state);
	std::vector<std::string> seen;
	if (value.kind == Kind::Array) {
		const int64_t count = state.array_size(value.ref);
		for (int64_t index = 0; index < count; ++index) {
			const std::string item = strip(string_of(state, state.at(value.ref, index)));
			if (!item.empty() && std::find(seen.begin(), seen.end(), item) == seen.end()) {
				seen.push_back(item);
				append(state, result, text(state, item));
			}
		}
	}
	return seen.empty() ? deep_copy(state, fallback) : result;
}

Value default_terrain_pool(State &state) {
	return string_array(state, { "grass", "snow", "sand", "dirt", "rough", "lava", "underground" });
}

Value default_faction_pool(State &state) {
	return string_array(state, { "faction_embercourt", "faction_mireclaw", "faction_sunvault", "faction_thornwake" });
}

Value ensure_repeated_to_count(State &state, const Value &source, const Value &fallback, int32_t count) {
	const Value base = is_empty(state, source) ? fallback : source;
	const Value result = new_array(state);
	const int64_t base_size = size_of(state, base);
	if (base_size == 0) {
		return result;
	}
	for (int32_t index = 0; index < count; ++index) {
		append(state, result, state.at(base.ref, index % base_size));
	}
	return result;
}

std::string town_for_faction(const std::string &faction_id) {
	if (faction_id == "faction_mireclaw") {
		return "town_duskfen";
	}
	if (faction_id == "faction_sunvault") {
		return "town_prismhearth";
	}
	if (faction_id == "faction_thornwake") {
		return "town_thornwake_graftroot_caravan";
	}
	if (faction_id == "faction_brasshollow") {
		return "town_brasshollow_orevein_gantry";
	}
	if (faction_id == "faction_veilmourn") {
		return "town_veilmourn_bellwake_harbor";
	}
	return "town_riverwatch";
}

Value town_ids_for_factions(State &state, const Value &requested_value, const Value &faction_ids, int32_t count) {
	const Value requested = normalized_string_array(state, requested_value, new_array(state));
	const Value result = new_array(state);
	const int64_t requested_size = size_of(state, requested);
	if (requested_size != 0) {
		for (int32_t index = 0; index < count; ++index) {
			append(state, result, state.at(requested.ref, index % requested_size));
		}
		return result;
	}
	const int64_t faction_count = size_of(state, faction_ids);
	for (int32_t index = 0; faction_count != 0 && index < count; ++index) {
		append(state, result, text(state, town_for_faction(string_of(state, state.at(faction_ids.ref, index % faction_count)))));
	}
	return result;
}

// A setup's faction for every player colour, kept as it is; empty when the
// setup gives none or leaves an entry blank.
Value seat_faction_list(State &state, const Value &value, int32_t count) {
	const Value result = new_array(state);
	if (value.kind != Kind::Array) {
		return result;
	}
	const int64_t source_size = state.array_size(value.ref);
	for (int64_t index = 0; index < source_size; ++index) {
		const std::string item = strip(string_of(state, state.at(value.ref, index)));
		if (item.empty()) {
			return new_array(state);
		}
		append(state, result, text(state, item));
	}
	return ensure_repeated_to_count(state, result, new_array(state), count);
}

Value normalized_player_constraints(State &state, const Value &config) {
	const Value value = has(state, config, "player_constraints") ? get(state, config, "player_constraints") : get(state, config, "players");
	const Value source = dict_or_new(state, value);
	const auto nested = [&](const char *first, const char *second, int32_t fallback) {
		return has(state, source, first) ? int32_of(state, get(state, source, first)) : int32_field(state, source, second, fallback);
	};
	const int32_t human_count = std::max<int32_t>(1, std::min<int32_t>(8, nested("human_count", "humans", 1)));
	int32_t player_count = 2;
	int32_t computer_count = 1;
	if (has(state, source, "player_count") || has(state, source, "total_count") || has(state, source, "total")) {
		const int32_t total = has(state, source, "player_count") ? int32_of(state, get(state, source, "player_count")) : nested("total_count", "total", 2);
		player_count = std::max<int32_t>(1, std::min<int32_t>(8, total));
		player_count = std::max(player_count, human_count);
		computer_count = std::max<int32_t>(0, player_count - human_count);
	} else {
		computer_count = std::max<int32_t>(0, std::min<int32_t>(7, nested("computer_count", "computers", 1)));
		player_count = std::max<int32_t>(1, std::min<int32_t>(8, human_count + computer_count));
	}
	const Value result = new_dict(state);
	put(state, result, "human_count", integer(human_count));
	put(state, result, "computer_count", integer(computer_count));
	put(state, result, "player_count", integer(player_count));
	put(state, result, "team_mode", text(state, normalized_text(state, source, "team_mode", "free_for_all")));
	const int32_t human_team_count = std::max<int32_t>(1, std::min<int32_t>(human_count, nested("human_team_count", "human_teams", human_count)));
	const int32_t computer_team_count = computer_count == 0
			? 0
			: std::max<int32_t>(0, std::min<int32_t>(computer_count, nested("computer_team_count", "computer_teams", 0)));
	put(state, result, "human_team_count", integer(human_team_count));
	put(state, result, "computer_team_count", integer(computer_team_count));
	return result;
}

std::string normalized_water_mode(State &state, const Value &config, const Value &size) {
	const std::string water_mode = lower(strip(normalized_text(state, size, "water_mode", normalized_text(state, config, "water_mode", "land"))));
	if (water_mode == "none" || water_mode == "no_water" || water_mode == "land_only" || water_mode == "nowater") {
		return "land";
	}
	if (water_mode == "normalwater" || water_mode == "normal-water" || water_mode == "normal water" || water_mode == "mixed") {
		return "normal_water";
	}
	if (water_mode == "water") {
		return "islands";
	}
	if (water_mode != "islands" && water_mode != "normal_water") {
		return "land";
	}
	return water_mode;
}

bool known_monster_strength(const std::string &strength) {
	return strength == "random" || strength == "weak" || strength == "normal" || strength == "strong";
}

int32_t monster_strength_raw_0x48(const std::string &strength) {
	if (strength == "normal") {
		return 0;
	}
	if (strength == "strong") {
		return 1;
	}
	return -1;
}

struct Scope {
	int32_t width = 0;
	int32_t height = 0;
	int32_t level_count = 1;
	std::string water_mode;
	std::string size_class;
};

Scope scope_of(State &state, const Value &normalized) {
	Scope scope;
	scope.width = int32_field(state, normalized, "width", 0);
	scope.height = int32_field(state, normalized, "height", 0);
	scope.level_count = int32_field(state, normalized, "level_count", 1);
	scope.water_mode = string_field(state, normalized, "water_mode", "land");
	scope.size_class = string_field(state, normalized, "size_class_id", "");
	return scope;
}

bool supports_land_scope(State &state, const Value &normalized) {
	const Scope scope = scope_of(state, normalized);
	return h3::supports_recovered_workflow_execution_scope(scope.width, scope.height, scope.level_count, scope.water_mode, scope.size_class);
}

std::string strict_scope_id(State &state, const Value &normalized) {
	const Scope scope = scope_of(state, normalized);
	return h3::strict_scope_id(scope.width, scope.height, scope.level_count, scope.water_mode, scope.size_class);
}

Value runtime_policy_classification(State &state, const Value &normalized) {
	const std::string monster_strength = string_field(state, normalized, "monster_strength", "random");
	const bool supported_scope = supports_land_scope(state, normalized);
	const bool supported_strength = known_monster_strength(monster_strength);
	const bool supported = supported_scope && supported_strength;
	const Value result = new_dict(state);
	put(state, result, "schema_id", text(state, "aurelion_native_rmg_runtime_policy_classification_v1"));
	put(state, result, "schema_version", integer(1));
	put(state, result, "supported_h3maped_scope", boolean(supported));
	put(state, result, "h3maped_strict_scope", text(state, strict_scope_id(state, normalized)));
	put(state, result, "runtime_generation_allowed", boolean(supported));
	put(state, result, "native_runtime_authoritative", boolean(supported));
	put(state, result, "full_parity_claim", boolean(supported));
	put(state, result, "blocked_reason", text(state, supported ? "" : (supported_scope ? "unsupported_h3maped_monster_strength" : "outside_supported_h3maped_parity_matrix")));
	return result;
}

Value extension_profile_stub(State &state, const Value &normalized) {
	const Value result = new_dict(state);
	put(state, result, "schema_id", text(state, "aurelion_native_rmg_extension_profile_v1"));
	put(state, result, "schema_version", integer(1));
	put(state, result, "measurement", text(state, "not_measured_generation_blocked_before_payload"));
	put(state, result, "phase_count", integer(1));
	const Value phases = new_array(state);
	const Value phase = new_dict(state);
	put(state, phase, "phase_id", text(state, "normalize_config"));
	put(state, phase, "elapsed_usec", integer(0));
	put(state, phase, "elapsed_msec", Value::of_float(0.0));
	append(state, phases, phase);
	put(state, result, "phases", phases);
	put(state, result, "width", get(state, normalized, "width", integer(0)));
	put(state, result, "height", get(state, normalized, "height", integer(0)));
	put(state, result, "level_count", get(state, normalized, "level_count", integer(1)));
	put(state, result, "object_count", integer(0));
	put(state, result, "road_segment_count", integer(0));
	put(state, result, "town_count", integer(0));
	put(state, result, "guard_count", integer(0));
	return result;
}

Value exact_chain_unimplemented_blocked_result(State &state, const Value &normalized) {
	const Value result = new_dict(state);
	put(state, result, "ok", boolean(false));
	put(state, result, "status", text(state, "native_rmg_exact_state_chain_runtime_blocked"));
	put(state, result, "generation_status", text(state, "native_rmg_exact_state_chain_runtime_blocked"));
	put(state, result, "full_generation_status", text(state, "waiting_for_exact_h3maped_executable_state_chain"));
	put(state, result, "error_code", text(state, "native_rmg_exact_state_chain_not_ported"));
	put(state, result, "message", text(state, "Runtime RMG is blocked for this scope. Add source-backed H3MapEd private-state support before enabling map output."));
	put(state, result, "normalized_config", deep_copy(state, normalized));
	put(state, result, "extension_profile", extension_profile_stub(state, normalized));
	put(state, result, "runtime_policy_classification", runtime_policy_classification(state, normalized));
	put(state, result, "runtime_generation_allowed", boolean(false));
	put(state, result, "native_runtime_authoritative", boolean(false));
	put(state, result, "public_runtime_authoritative", boolean(false));
	put(state, result, "full_parity_claim", boolean(false));
	put(state, result, "live_generation_surface_present", boolean(false));
	put(state, result, "native_rmg_generation_authority", text(state, "blocked_until_exact_h3maped_private_state_chain"));
	put(state, result, "native_rmg_unsupported_mode_policy", text(state, "explicit_blocked_no_fallback"));
	return result;
}

// Everything the normalized config holds but the setup's factions and player
// setup, which only the stamping reads.
std::string generated_core_key(State &state, const Value &normalized) {
	static const std::unordered_set<std::string> kStamped = { "faction_ids", "town_ids", "seat_faction_ids", "player_setup" };
	std::string out;
	canonical_variant(state, normalized, out, &kStamped);
	return out;
}

// --------------------------------------------------- content catalogs

// The file's JSON object, {} when it is missing or holds another root.
Value runtime_json_dictionary(State &state, content::Files &files, const char *path) {
	std::string bytes;
	if (!files.exists(path) || !files.read(path, bytes)) {
		return new_dict(state);
	}
	const compat::JsonParse parsed = compat::json_parse(state, bytes);
	return parsed.error == 0 && parsed.data.kind == Kind::Dict ? parsed.data : new_dict(state);
}

Value runtime_object_eligibility(State &state, content::Files &files) {
	const Value registry = runtime_json_dictionary(state, files, kEligibilityPath);
	if (string_field(state, registry, "schema_id") != kEligibilitySchema
			|| string_field(state, registry, "native_generation_boundary")
					!= "classification_and_runtime_proxy_selection_only_no_phase_placement_topology_footprint_mask_rng_or_final_payload_changes") {
		return new_dict(state);
	}
	return registry;
}

Value runtime_authored_pool_definition(State &state, const Value &registry, const std::string &pool_id) {
	const Value pools = get(state, registry, "authored_pools");
	if (pools.kind != Kind::Array) {
		return new_dict(state);
	}
	const int64_t count = state.array_size(pools.ref);
	for (int64_t index = 0; index < count; ++index) {
		const Value pool = state.at(pools.ref, index);
		if (pool.kind == Kind::Dict && string_field(state, pool, "id") == pool_id) {
			return pool;
		}
	}
	return new_dict(state);
}

bool runtime_map_object_matches_pool(State &state, const Value &item, const Value &pool, const std::unordered_set<std::string> &resource_site_ids,
		const std::unordered_map<std::string, Value> &sites_by_id) {
	const std::string item_id = string_field(state, item, "id");
	const std::string primary_class = string_field(state, item, "primary_class");
	const bool explicit_match = texts_contain(state, get(state, pool, "explicit_object_ids"), item_id);
	const Value primary_classes = get(state, pool, "primary_classes");
	if (primary_classes.kind == Kind::Array && !texts_contain(state, primary_classes, primary_class) && !explicit_match) {
		return false;
	}
	const Value families = get(state, pool, "families");
	if (families.kind == Kind::Array && !texts_contain(state, families, string_field(state, item, "family"))) {
		return false;
	}
	const Value runtime_boundary = dict_or_new(state, get(state, item, "runtime_boundary"));
	if (texts_contain(state, get(state, pool, "exclude_runtime_statuses"), string_field(state, runtime_boundary, "status"))) {
		return false;
	}
	if (bool_field(state, pool, "require_resource_site", false)) {
		const std::string site_id = string_field(state, item, "resource_site_id");
		if (site_id.empty() || resource_site_ids.count(site_id) == 0) {
			return false;
		}
	}
	if (bool_field(state, pool, "require_live_guard_contract", false)) {
		// Site contracts own executable rewards/defenders. Older map-object
		// metadata can still say metadata_only after its site was implemented.
		const std::string site_id = string_field(state, item, "resource_site_id");
		const auto found = sites_by_id.find(site_id);
		const Value site = found == sites_by_id.end() ? new_dict(state) : dict_or_new(state, found->second);
		const Value boundary = dict_or_new(state, get(state, site, "runtime_boundary"));
		const Value contract = dict_or_new(state, get(state, site, "guarded_reward_contract"));
		if (!bool_field(state, boundary, "guard_resolution_runtime_adopted", false)
				|| bool_field(state, contract, "metadata_only_guard_contract", true)
				|| string_field(state, contract, "resource_site_id") != site_id
				|| string_field(state, contract, "guard_encounter_id").empty()
				|| string_field(state, contract, "guard_army_group_id").empty()) {
			return false;
		}
	}
	return !item_id.empty();
}

// Each pool's candidates by its id, sorted by id (stable). The catalogs are
// parsed for this generation alone, so the candidates are not copied.
std::unordered_map<std::string, Value> runtime_authored_pool_candidates(State &state, content::Files &files, const Value &registry) {
	std::unordered_map<std::string, Value> result;
	const Value map_items = array_or_new(state, get(state, runtime_json_dictionary(state, files, kMapObjectCatalogPath), "items"));
	const Value site_items = array_or_new(state, get(state, runtime_json_dictionary(state, files, kResourceSiteCatalogPath), "items"));
	const Value artifact_items = array_or_new(state, get(state, runtime_json_dictionary(state, files, kArtifactCatalogPath), "items"));
	std::unordered_set<std::string> resource_site_ids;
	std::unordered_map<std::string, Value> sites_by_id;
	const int64_t site_count = state.array_size(site_items.ref);
	for (int64_t index = 0; index < site_count; ++index) {
		const Value site = state.at(site_items.ref, index);
		if (site.kind != Kind::Dict) {
			continue;
		}
		const std::string site_id = string_field(state, site, "id");
		if (!site_id.empty()) {
			resource_site_ids.insert(site_id);
			sites_by_id[site_id] = site;
		}
	}
	const Value pools = array_or_new(state, get(state, registry, "authored_pools"));
	const int64_t pool_count = state.array_size(pools.ref);
	for (int64_t pool_index = 0; pool_index < pool_count; ++pool_index) {
		const Value pool = state.at(pools.ref, pool_index);
		if (pool.kind != Kind::Dict) {
			continue;
		}
		const std::string pool_id = string_field(state, pool, "id");
		const std::string domain = string_field(state, pool, "content_domain");
		std::vector<std::pair<std::string, Value>> candidates;
		if (domain == "map_object") {
			const int64_t count = state.array_size(map_items.ref);
			for (int64_t index = 0; index < count; ++index) {
				const Value item = state.at(map_items.ref, index);
				if (item.kind == Kind::Dict && runtime_map_object_matches_pool(state, item, pool, resource_site_ids, sites_by_id)) {
					candidates.emplace_back(string_field(state, item, "id"), item);
				}
			}
		} else if (domain == "artifact") {
			const int64_t count = state.array_size(artifact_items.ref);
			for (int64_t index = 0; index < count; ++index) {
				const Value item = state.at(artifact_items.ref, index);
				if (item.kind == Kind::Dict && !string_field(state, item, "id").empty()) {
					candidates.emplace_back(string_field(state, item, "id"), item);
				}
			}
		}
		std::stable_sort(candidates.begin(), candidates.end(), [](const auto &left, const auto &right) { return left.first < right.first; });
		const Value list = new_array(state);
		for (const auto &candidate : candidates) {
			append(state, list, candidate.second);
		}
		result[pool_id] = list;
	}
	return result;
}

// A live proxy catalog entry, with what the per-object search reads of it.
struct ProxyEntry {
	Value entry;
	int32_t type_id = 0;
	int32_t subtype = -1;
	bool site_surface = false;
	bool artifact_surface = false;
	std::string generated_kind;
};

bool proxy_has_live_site_surface(State &state, const Value &entry) {
	if (string_field(state, entry, "runtime_projection_status", "live") != "live") {
		return false;
	}
	const std::string kind = string_field(state, entry, "generated_kind");
	if (kind == "mine" || kind == "neutral_dwelling") {
		return !string_field(state, entry, "native_proxy_object_id").empty();
	}
	if (kind == "reward_reference" || kind == "resource_site") {
		return !string_field(state, entry, "native_proxy_object_id").empty() && !string_field(state, entry, "native_proxy_site_id").empty();
	}
	return false;
}

bool proxy_has_live_artifact_surface(State &state, const Value &entry) {
	const std::string artifact_id = string_field(state, entry, "native_artifact_id");
	return string_field(state, entry, "generated_kind") == "reward_reference"
			&& string_field(state, entry, "semantic_category") == "artifact"
			&& !artifact_id.empty()
			&& string_field(state, entry, "native_proxy_object_id") == artifact_id
			&& string_field(state, entry, "native_proxy_site_id").empty();
}

std::vector<ProxyEntry> runtime_live_proxy_catalog_entries(State &state, content::Files &files) {
	const Value catalog = runtime_json_dictionary(state, files, kProxyCatalogPath);
	if (is_empty(state, catalog)) {
		return {};
	}
	if (string_field(state, catalog, "schema_id") != kProxyCatalogSchema
			|| string_field(state, catalog, "asset_policy") != "provenance_only_original_proxy_art") {
		return {};
	}
	const Value entries = get(state, catalog, "entries");
	if (entries.kind != Kind::Array) {
		return {};
	}
	std::vector<ProxyEntry> detached;
	const int64_t count = state.array_size(entries.ref);
	for (int64_t index = 0; index < count; ++index) {
		const Value entry = state.at(entries.ref, index);
		if (entry.kind != Kind::Dict) {
			return {};
		}
		ProxyEntry proxy;
		proxy.entry = entry;
		proxy.type_id = int32_field(state, entry, "homm3_re_object_type_id", 0);
		proxy.subtype = int32_field(state, entry, "homm3_re_object_subtype", -1);
		proxy.generated_kind = string_field(state, entry, "generated_kind");
		if (string_field(state, entry, "id").empty() || proxy.type_id <= 0 || proxy.subtype < 0 || proxy.generated_kind.empty()
				|| string_field(state, entry, "native_proxy_object_id").empty()) {
			return {};
		}
		proxy.site_surface = proxy_has_live_site_surface(state, entry);
		proxy.artifact_surface = proxy_has_live_artifact_surface(state, entry);
		detached.push_back(std::move(proxy));
	}
	return detached;
}

// The catalog's one live entry for the record, a copy; {} for none or more.
Value runtime_live_proxy_entry(State &state, const std::vector<ProxyEntry> &entries, int32_t type_id, int32_t subtype, const std::string &base_kind) {
	const ProxyEntry *exact = nullptr;
	size_t exact_count = 0;
	const ProxyEntry *kind = nullptr;
	size_t kind_count = 0;
	for (const ProxyEntry &entry : entries) {
		if (entry.type_id != type_id || entry.subtype != subtype || (!entry.site_surface && !entry.artifact_surface)) {
			continue;
		}
		exact = exact_count == 0 ? &entry : exact;
		++exact_count;
		if (entry.generated_kind == base_kind) {
			kind = kind_count == 0 ? &entry : kind;
			++kind_count;
		}
	}
	if (kind_count == 1) {
		return deep_copy(state, kind->entry);
	}
	if (kind_count == 0 && exact_count == 1) {
		return deep_copy(state, exact->entry);
	}
	return new_dict(state);
}

Value runtime_authored_pool_proxy_entry(State &state, const Value &registry, const std::unordered_map<std::string, Value> &candidates_by_pool,
		const Value &catalog_entry, const h3::RuntimeMapObjectProjection &source, const std::string &map_id) {
	const Value source_type_pools = dict_or_new(state, get(state, registry, "source_type_pools"));
	const std::string source_type_key = compat::itos(source.type_id);
	const std::string pool_id = string_field(state, source_type_pools, source_type_key.c_str());
	if (pool_id.empty()) {
		return deep_copy(state, catalog_entry);
	}
	const Value pool = runtime_authored_pool_definition(state, registry, pool_id);
	const auto found = candidates_by_pool.find(pool_id);
	if (is_empty(state, pool) || found == candidates_by_pool.end()) {
		return new_dict(state);
	}
	Value candidates = found->second;
	const std::string domain = string_field(state, pool, "content_domain");
	const Value artifact_rarities = dict_or_new(state, get(state, registry, "artifact_rarities_by_source_type"));
	const std::string rarity = string_field(state, artifact_rarities, source_type_key.c_str());
	if (domain == "artifact" && !rarity.empty()) {
		const Value filtered = new_array(state);
		const int64_t count = state.array_size(candidates.ref);
		for (int64_t index = 0; index < count; ++index) {
			const Value candidate = state.at(candidates.ref, index);
			if (string_field(state, dict_or_new(state, candidate), "rarity") == rarity) {
				append(state, filtered, candidate);
			}
		}
		candidates = filtered;
	}
	const int64_t candidate_count = state.array_size(candidates.ref);
	if (candidate_count == 0) {
		return new_dict(state);
	}
	// A random artifact class is a rarity band, not one fixed legacy proxy.
	// Likewise a creature bank must remain a guarded site, not a free artifact.
	bool catalog_domain_matches = domain == "artifact" ? proxy_has_live_artifact_surface(state, catalog_entry)
														 : !proxy_has_live_artifact_surface(state, catalog_entry);
	Value fixed_site_candidate = new_dict(state);
	if (bool_field(state, pool, "require_live_guard_contract", false)) {
		catalog_domain_matches = false;
		const std::string proxy_object_id = string_field(state, catalog_entry, "native_proxy_object_id");
		for (int64_t index = 0; index < candidate_count; ++index) {
			const Value candidate = dict_or_new(state, state.at(candidates.ref, index));
			if (string_field(state, candidate, "id") == proxy_object_id) {
				fixed_site_candidate = candidate;
				catalog_domain_matches = true;
				break;
			}
		}
	}
	if (!is_empty(state, catalog_entry) && catalog_domain_matches && rarity.empty()) {
		const Value entry = deep_copy(state, catalog_entry);
		if (!is_empty(state, fixed_site_candidate)) {
			// Keep the established original object identity but not its obsolete
			// free-cache proxy. The same site's real contract owns art and combat.
			put(state, entry, "generated_kind", get(state, pool, "generated_kind", text(state, "resource_site")));
			put(state, entry, "semantic_category", get(state, pool, "semantic_category", text(state, "guarded_reward")));
			put(state, entry, "native_proxy_site_id", get(state, fixed_site_candidate, "resource_site_id", text(state, "")));
			put(state, entry, "native_proxy_family", get(state, fixed_site_candidate, "family", text(state, "")));
			put(state, entry, "native_proxy_category", get(state, fixed_site_candidate, "primary_class", text(state, "")));
		}
		put(state, entry, "native_authored_pool_id", text(state, pool_id));
		put(state, entry, "native_authored_pool_candidate_count", integer(candidate_count));
		put(state, entry, "native_authored_pool_candidate_id", get(state, entry, "native_proxy_object_id", text(state, "")));
		put(state, entry, "native_authored_pool_selection_token", text(state, "exact_catalog:" + string_field(state, entry, "id")));
		put(state, entry, "native_authored_pool_selection_mode", text(state, "existing_exact_catalog_identity"));
		put(state, entry, "native_authored_pool_registry_path", text(state, kEligibilityPath));
		put(state, entry, "native_authored_pool_registry_schema", text(state, kEligibilitySchema));
		put(state, entry, "native_authored_pool_source_placement_unchanged", boolean(true));
		put(state, entry, "native_authored_pool_final_payload_unchanged", boolean(true));
		return entry;
	}
	const std::string selection_token = hash32_hex(map_id + ":" + compat::itos(source.serialized_index) + ":" + source_type_key + ":"
			+ compat::itos(source.subtype) + ":" + pool_id);
	const int64_t candidate_index = int64_t(hash32_int(selection_token)) % candidate_count;
	const Value candidate = dict_or_new(state, state.at(candidates.ref, candidate_index));
	const Value entry = deep_copy(state, catalog_entry);
	const std::string candidate_id = string_field(state, candidate, "id");
	for (const char *field : { "native_proxy_site_id", "native_resource_id", "native_artifact_id" }) {
		state.erase(entry.ref, text(state, field));
	}
	put(state, entry, "id", text(state, "authored_pool_proxy_" + source_type_key + "_" + compat::itos(source.subtype) + "_" + pool_id));
	put(state, entry, "generated_kind", get(state, pool, "generated_kind", text(state, "")));
	put(state, entry, "source_kind", text(state, "homm3_re_final_payload_post_projection_original_content_pool"));
	put(state, entry, "semantic_category", get(state, pool, "semantic_category", text(state, pool_id)));
	put(state, entry, "native_proxy_object_id", text(state, candidate_id));
	if (domain == "artifact") {
		put(state, entry, "native_artifact_id", text(state, candidate_id));
		put(state, entry, "native_proxy_family", get(state, candidate, "family", text(state, "artifact")));
		put(state, entry, "native_proxy_category", get(state, candidate, "artifact_class", text(state, "artifact")));
	} else {
		const std::string site_id = string_field(state, candidate, "resource_site_id");
		if (!site_id.empty()) {
			put(state, entry, "native_proxy_site_id", text(state, site_id));
		}
		put(state, entry, "native_proxy_family", get(state, candidate, "family", text(state, "")));
		put(state, entry, "native_proxy_category", get(state, candidate, "primary_class", text(state, "")));
	}
	put(state, entry, "homm3_re_object_type_id", integer(source.type_id));
	put(state, entry, "homm3_re_object_type_name", text(state, source.def_name));
	put(state, entry, "homm3_re_object_subtype", integer(source.subtype));
	put(state, entry, "homm3_re_object_def_ref", text(state, source.def_name));
	put(state, entry, "native_authored_pool_id", text(state, pool_id));
	put(state, entry, "native_authored_pool_candidate_count", integer(candidate_count));
	put(state, entry, "native_authored_pool_candidate_id", text(state, candidate_id));
	put(state, entry, "native_authored_pool_selection_token", text(state, selection_token));
	put(state, entry, "native_authored_pool_selection_mode", text(state, "stable_source_ordinal_pool_index"));
	put(state, entry, "native_authored_pool_registry_path", text(state, kEligibilityPath));
	put(state, entry, "native_authored_pool_registry_schema", text(state, kEligibilitySchema));
	put(state, entry, "native_authored_pool_source_placement_unchanged", boolean(true));
	put(state, entry, "native_authored_pool_final_payload_unchanged", boolean(true));
	return entry;
}

void apply_runtime_live_proxy_entry(State &state, const Value &object, const Value &entry) {
	if (is_empty(state, entry)) {
		return;
	}
	put(state, object, "kind", get(state, entry, "generated_kind", text(state, "")));
	put(state, object, "native_record_kind", get(state, entry, "generated_kind", text(state, "")));
	put(state, object, "object_id", get(state, entry, "native_proxy_object_id", text(state, "")));
	put(state, object, "native_proxy_object_id", get(state, entry, "native_proxy_object_id", text(state, "")));
	const std::string site_id = string_field(state, entry, "native_proxy_site_id");
	if (!site_id.empty()) {
		put(state, object, "site_id", text(state, site_id));
	}
	const std::string resource_id = string_field(state, entry, "native_resource_id");
	if (!resource_id.empty()) {
		put(state, object, "resource_id", text(state, resource_id));
	}
	const std::string artifact_id = string_field(state, entry, "native_artifact_id");
	if (!artifact_id.empty()) {
		put(state, object, "artifact_id", text(state, artifact_id));
	}
	for (const char *field : { "native_proxy_family", "native_proxy_category", "semantic_category", "homm3_re_reward_table_bucket" }) {
		const std::string value = string_field(state, entry, field);
		if (!value.empty()) {
			put(state, object, field, text(state, value));
		}
	}
	put(state, object, "homm3_re_reward_object_catalog_id", get(state, entry, "id", text(state, "")));
	if (!string_field(state, entry, "native_authored_pool_id").empty()) {
		put(state, object, "native_authored_pool_resolution_status", text(state, "mapped"));
		for (const char *field : {
					 "native_authored_pool_id",
					 "native_authored_pool_candidate_id",
					 "native_authored_pool_selection_token",
					 "native_authored_pool_selection_mode",
					 "native_authored_pool_registry_path",
					 "native_authored_pool_registry_schema" }) {
			put(state, object, field, get(state, entry, field, text(state, "")));
		}
		put(state, object, "native_authored_pool_candidate_count", get(state, entry, "native_authored_pool_candidate_count", integer(0)));
		put(state, object, "native_authored_pool_source_placement_unchanged", boolean(true));
		put(state, object, "native_authored_pool_final_payload_unchanged", boolean(true));
		if (string_field(state, entry, "native_authored_pool_selection_mode") == "existing_exact_catalog_identity") {
			put(state, object, "homm3_re_reward_object_catalog_path", text(state, kProxyCatalogPath));
			put(state, object, "homm3_re_reward_object_catalog_schema", text(state, kProxyCatalogSchema));
		}
	} else {
		put(state, object, "homm3_re_reward_object_catalog_path", text(state, kProxyCatalogPath));
		put(state, object, "homm3_re_reward_object_catalog_schema", text(state, kProxyCatalogSchema));
	}
	put(state, object, "homm3_re_reward_object_source_kind", get(state, entry, "source_kind", text(state, "")));
	put(state, object, "homm3_re_object_type_id", get(state, entry, "homm3_re_object_type_id", integer(0)));
	put(state, object, "homm3_re_object_type_name", get(state, entry, "homm3_re_object_type_name", text(state, "")));
	put(state, object, "homm3_re_object_subtype", get(state, entry, "homm3_re_object_subtype", integer(0)));
	put(state, object, "homm3_re_object_source_row", get(state, entry, "homm3_re_object_source_row", integer(0)));
	put(state, object, "homm3_re_object_def_ref", get(state, entry, "homm3_re_object_def_ref", text(state, "")));
	put(state, object, "homm3_re_art_asset_policy", text(state, "provenance_only_original_proxy_art"));
}

// ------------------------------------------------ factions and places

std::string runtime_faction_id(const h3::FinalHeaderPlayerSlot4ac857 *slot) {
	if (slot == nullptr || slot->human) {
		return "faction_embercourt";
	}
	return (slot->color % 2 == 0) ? "faction_sunvault" : "faction_mireclaw";
}

std::string runtime_town_id(const h3::FinalHeaderPlayerSlot4ac857 *slot) {
	if (slot == nullptr || slot->human) {
		return "town_riverwatch";
	}
	return (slot->color % 2 == 0) ? "town_prismhearth" : "town_duskfen";
}

std::string configured_runtime_faction_id(State &state, const h3::FinalHeaderPlayerSlot4ac857 *slot, const Value &normalized_config) {
	if (slot != nullptr) {
		const Value player_setup = dict_or_new(state, get(state, normalized_config, "player_setup"));
		if (slot->human) {
			const std::string selected_faction_id = strip(string_field(state, player_setup, "faction_id"));
			if (!selected_faction_id.empty()) {
				return selected_faction_id;
			}
		}
		const Value faction_ids = array_or_new(state, get(state, normalized_config, "faction_ids"));
		if (slot->color >= 0 && slot->color < state.array_size(faction_ids.ref)) {
			const std::string faction_id = strip(string_of(state, state.at(faction_ids.ref, slot->color)));
			if (!faction_id.empty()) {
				return faction_id;
			}
		}
	}
	return runtime_faction_id(slot);
}

std::string configured_runtime_town_id(State &state, const h3::FinalHeaderPlayerSlot4ac857 *slot, const Value &normalized_config) {
	if (slot != nullptr) {
		const Value player_setup = dict_or_new(state, get(state, normalized_config, "player_setup"));
		if (slot->human) {
			const std::string selected_faction_id = strip(string_field(state, player_setup, "faction_id"));
			if (!selected_faction_id.empty()) {
				return town_for_faction(selected_faction_id);
			}
		}
		const Value town_ids = array_or_new(state, get(state, normalized_config, "town_ids"));
		if (slot->color >= 0 && slot->color < state.array_size(town_ids.ref)) {
			const std::string town_id = strip(string_of(state, state.at(town_ids.ref, slot->color)));
			if (!town_id.empty()) {
				return town_id;
			}
		}
	}
	return runtime_town_id(slot);
}

Value runtime_tile_point(State &state, const h3::RuntimeMapTilePoint &point) {
	const Value result = new_dict(state);
	put(state, result, "x", integer(point.x));
	put(state, result, "y", integer(point.y));
	put(state, result, "level", integer(point.level));
	return result;
}

Value runtime_tile_points(State &state, const std::vector<h3::RuntimeMapTilePoint> &points) {
	const Value result = new_array(state);
	for (const auto &point : points) {
		append(state, result, runtime_tile_point(state, point));
	}
	return result;
}

int64_t runtime_tile_flat(const h3::RuntimeMapPayloadProjection &projection, int32_t x, int32_t y, int32_t level) {
	if (x < 0 || y < 0 || level < 0 || x >= projection.width || y >= projection.height || level >= projection.level_count) {
		return -1;
	}
	return int64_t(level) * projection.width * projection.height + int64_t(y) * projection.width + x;
}

Value runtime_guard_control_tiles(State &state, const h3::RuntimeMapObjectProjection &source, const h3::RuntimeMapPayloadProjection &projection) {
	const Value result = new_array(state);
	std::unordered_set<int64_t> seen;
	std::vector<h3::RuntimeMapTilePoint> fallback_origins;
	const std::vector<h3::RuntimeMapTilePoint> *origins = &source.action_tiles;
	if (origins->empty()) {
		fallback_origins.push_back({
				std::clamp(source.x, 0, projection.width - 1),
				std::clamp(source.y, 0, projection.height - 1),
				std::clamp(source.level, 0, projection.level_count - 1),
		});
		origins = &fallback_origins;
	}
	for (const auto &origin : *origins) {
		for (int32_t dy = -1; dy <= 1; ++dy) {
			for (int32_t dx = -1; dx <= 1; ++dx) {
				const int32_t x = origin.x + dx;
				const int32_t y = origin.y + dy;
				const int32_t level = origin.level;
				const int64_t flat = runtime_tile_flat(projection, x, y, level);
				if (flat < 0 || !seen.insert(flat).second) {
					continue;
				}
				append(state, result, runtime_tile_point(state, { x, y, level }));
			}
		}
	}
	return result;
}

// Product start policy: the recovered main-town entrance exactly; {} when it
// does not resolve.
Value runtime_start_tile_for_slot(State &state, const h3::FinalHeaderPlayerSlot4ac857 &slot, const h3::RuntimeMapPayloadProjection &projection) {
	if (!slot.has_main_town || runtime_tile_flat(projection, slot.town_x, slot.town_y, slot.town_level) < 0) {
		return new_dict(state);
	}
	for (const auto &object : projection.objects) {
		if (object.type_id != 98) {
			continue;
		}
		for (const auto &point : object.action_tiles) {
			if (point.x != slot.town_x || point.y != slot.town_y || point.level != slot.town_level) {
				continue;
			}
			const Value selected = runtime_tile_point(state, point);
			put(state, selected, "selection_radius_from_town_coordinate", integer(0));
			put(state, selected, "selection_removed_removable_start_block_mask", boolean(false));
			put(state, selected, "selection_source", text(state, "h3maped_main_town_entrance_runtime_start"));
			return selected;
		}
	}
	return new_dict(state);
}

Value runtime_layer(State &state, const std::vector<uint8_t> &codes, int32_t width, int32_t height, int32_t level_count) {
	const Value result = new_dict(state);
	const Value levels = new_array(state);
	const int32_t level_size = width * height;
	for (int32_t level = 0; level < level_count; ++level) {
		const uint32_t node = state.new_packed(Kind::PackedInt32);
		std::vector<int32_t> &values = state.packed_write(node).ints;
		values.resize(size_t(level_size));
		for (int32_t index = 0; index < level_size; ++index) {
			values[size_t(index)] = int32_t(codes[size_t(level * level_size + index)]);
		}
		append(state, levels, Value::of_ref(Kind::PackedInt32, node));
	}
	put(state, result, "levels", levels);
	return result;
}

// The game's seats: the map's player slots, of which every active one was
// generated as human or computer. The first human_count in colour order are
// the game's human seats, as the setup's slot records number them; the others
// are computer seats.
std::vector<h3::FinalHeaderPlayerSlot4ac857> runtime_seats(const h3::RuntimeMapPayloadProjection &projection, int32_t human_count) {
	std::vector<h3::FinalHeaderPlayerSlot4ac857> seats = projection.player_slots;
	int32_t humans = 0;
	for (auto &seat : seats) {
		if (!seat.active || !seat.human) {
			continue;
		}
		if (humans < human_count) {
			humans += 1;
		} else {
			seat.human = false;
			seat.computer = true;
		}
	}
	return seats;
}

const h3::FinalHeaderPlayerSlot4ac857 *runtime_slot_for_town(const h3::RuntimeMapObjectProjection &object, const std::vector<h3::FinalHeaderPlayerSlot4ac857> &seats) {
	for (const auto &slot : seats) {
		if (!slot.active || !slot.has_main_town) {
			continue;
		}
		for (const auto &point : object.action_tiles) {
			if (slot.town_x == point.x && slot.town_y == point.y && slot.town_level == point.level) {
				return &slot;
			}
		}
	}
	return nullptr;
}

// The project faction of each H3 town type, which a type-98 town record carries
// as its subtype (0 castle, 1 rampart, 2 tower, 3 inferno, 4 necropolis,
// 5 dungeon, 6 stronghold, 7 fortress, 8 conflux); the map library's
// H3M_TOWN_TYPE_FACTION_IDS.
constexpr int32_t kTownTypeCount = 9;
const char *const kTownTypeFactionIds[kTownTypeCount] = {
	"faction_embercourt",
	"faction_thornwake",
	"faction_sunvault",
	"faction_brasshollow",
	"faction_veilmourn",
	"faction_veilmourn",
	"faction_brasshollow",
	"faction_mireclaw",
	"faction_sunvault",
};

// Player factions come from the setup; a neutral town of a player's town type
// takes that player's faction unless players of different factions share it.
std::vector<std::string> runtime_town_type_faction_ids(State &state, const h3::RuntimeMapPayloadProjection &projection, const std::vector<h3::FinalHeaderPlayerSlot4ac857> &seats, const Value &normalized_config) {
	std::vector<std::string> result(kTownTypeCount);
	std::vector<std::string> player_factions(kTownTypeCount);
	std::vector<bool> shared_by_factions(kTownTypeCount, false);
	for (const auto &object : projection.objects) {
		if (object.type_id != 98 || object.subtype < 0 || object.subtype >= kTownTypeCount) {
			continue;
		}
		const auto *slot = runtime_slot_for_town(object, seats);
		if (slot == nullptr) {
			continue;
		}
		const std::string faction_id = configured_runtime_faction_id(state, slot, normalized_config);
		std::string &claimed = player_factions[size_t(object.subtype)];
		if (claimed.empty()) {
			claimed = faction_id;
		} else if (claimed != faction_id) {
			shared_by_factions[size_t(object.subtype)] = true;
		}
	}
	for (int32_t type = 0; type < kTownTypeCount; ++type) {
		const bool player_type = !player_factions[size_t(type)].empty() && !shared_by_factions[size_t(type)];
		result[size_t(type)] = player_type ? player_factions[size_t(type)] : std::string(kTownTypeFactionIds[type]);
	}
	return result;
}

std::string runtime_neutral_town_faction_id(const h3::RuntimeMapObjectProjection &town, const std::vector<std::string> &town_type_faction_ids) {
	// The generator writes every town as type 98; a type-77 random town has no
	// town type in its record.
	if (town.type_id == 98 && town.subtype >= 0 && size_t(town.subtype) < town_type_faction_ids.size()) {
		return town_type_faction_ids[size_t(town.subtype)];
	}
	return runtime_faction_id(nullptr);
}

std::string runtime_placement_id(const std::string &map_id, int32_t index) {
	return map_id + "_object_" + pad_zeros(compat::itos(index), 4);
}

std::string runtime_town_placement_id(const std::string &map_id, const h3::FinalHeaderPlayerSlot4ac857 &slot, const h3::RuntimeMapPayloadProjection &projection) {
	for (const auto &object : projection.objects) {
		if (object.type_id != 98) {
			continue;
		}
		for (const auto &point : object.action_tiles) {
			if (point.x == slot.town_x && point.y == slot.town_y && point.level == slot.town_level) {
				return runtime_placement_id(map_id, object.serialized_index);
			}
		}
	}
	return "";
}

Value runtime_terrain_layers(State &state, const h3::RuntimeMapPayloadProjection &projection) {
	const Value layers = new_dict(state);
	put(state, layers, "schema_id", text(state, "aurelion_terrain_layers"));
	put(state, layers, "schema_version", integer(1));
	put(state, layers, "terrain_id_by_code", string_array(state, { "dirt", "sand", "grass", "snow", "swamp", "rough", "underground", "lava", "water", "rock" }));
	const int32_t width = projection.width;
	const int32_t height = projection.height;
	const int32_t levels = projection.level_count;
	put(state, layers, "terrain", runtime_layer(state, projection.terrain_type_codes, width, height, levels));
	put(state, layers, "terrain_art", runtime_layer(state, projection.terrain_art_codes, width, height, levels));
	put(state, layers, "river_type", runtime_layer(state, projection.river_type_codes, width, height, levels));
	put(state, layers, "river_art", runtime_layer(state, projection.river_art_codes, width, height, levels));
	put(state, layers, "road_type", runtime_layer(state, projection.road_type_codes, width, height, levels));
	put(state, layers, "road_art", runtime_layer(state, projection.road_art_codes, width, height, levels));
	put(state, layers, "flags", runtime_layer(state, projection.tile_flags, width, height, levels));
	put(state, layers, "road_unique_tile_count", integer(int32_t(projection.road_tiles.size())));
	const Value roads = new_array(state);
	if (!projection.road_tiles.empty()) {
		const Value road = new_dict(state);
		put(state, road, "id", text(state, "h3maped_native_roads"));
		put(state, road, "tiles", runtime_tile_points(state, projection.road_tiles));
		append(state, roads, road);
	}
	put(state, layers, "roads", roads);
	return layers;
}

Value failure_record(State &state, const char *code, int32_t serialized_index) {
	const Value failure = new_dict(state);
	put(state, failure, "code", text(state, code));
	put(state, failure, "serialized_index", integer(serialized_index));
	return failure;
}

Value first_tile_point(State &state, const std::vector<h3::RuntimeMapTilePoint> &points) {
	return state.at(runtime_tile_points(state, points).ref, 0);
}

Value runtime_objects(State &state, content::Files &files, const std::string &map_id, const h3::RuntimeMapPayloadProjection &projection,
		const std::vector<h3::FinalHeaderPlayerSlot4ac857> &seats, const Value &normalized_config) {
	const Value result = new_array(state);
	const Value failures = new_array(state);
	const std::vector<ProxyEntry> live_proxy_catalog = runtime_live_proxy_catalog_entries(state, files);
	const Value eligibility = runtime_object_eligibility(state, files);
	const std::unordered_map<std::string, Value> candidates_by_pool = runtime_authored_pool_candidates(state, files, eligibility);
	const Value source_type_pools = dict_or_new(state, get(state, eligibility, "source_type_pools"));
	const Value source_kind_passthrough = dict_or_new(state, get(state, eligibility, "source_kind_passthrough"));
	const Value source_type_exclusions = dict_or_new(state, get(state, eligibility, "source_type_exclusions"));
	const std::vector<std::string> town_type_faction_ids = runtime_town_type_faction_ids(state, projection, seats, normalized_config);
	const Value resolution_counts = new_dict(state);
	for (const auto &source : projection.objects) {
		const Value object = new_dict(state);
		const std::string base_kind = aurelion::runtime_object_kind(source.type_id);
		const Value catalog_proxy = runtime_live_proxy_entry(state, live_proxy_catalog, source.type_id, source.subtype, base_kind);
		const Value live_proxy = runtime_authored_pool_proxy_entry(state, eligibility, candidates_by_pool, catalog_proxy, source, map_id);
		const std::string kind = is_empty(state, live_proxy) ? base_kind : string_field(state, live_proxy, "generated_kind", base_kind.c_str());
		const int32_t x = std::clamp(source.x, 0, projection.width - 1);
		const int32_t y = std::clamp(source.y, 0, projection.height - 1);
		const int32_t level = std::clamp(source.level, 0, projection.level_count - 1);
		put(state, object, "placement_id", text(state, runtime_placement_id(map_id, source.serialized_index)));
		put(state, object, "kind", text(state, kind));
		put(state, object, "native_record_kind", text(state, kind));
		put(state, object, "source_kind", text(state, "h3maped_final_payload"));
		put(state, object, "h3m_type_id", integer(source.type_id));
		put(state, object, "h3m_subtype", integer(source.subtype));
		put(state, object, "h3m_group", integer(source.group));
		put(state, object, "h3m_definition_index", integer(source.definition_index));
		put(state, object, "h3m_def_name", text(state, source.def_name));
		put(state, object, "h3m_serialization_pass", integer(source.serialization_pass));
		put(state, object, "h3m_payload_offset", integer(source.payload_offset));
		put(state, object, "h3m_payload_byte_count", integer(source.payload_byte_count));
		if (source.pandora_contents_known) {
			// H3M resource order: wood, mercury, ore, sulfur, crystal, gems, gold.
			const Value contents = new_dict(state);
			put(state, contents, "experience", integer(source.pandora_experience));
			const Value resources = new_array(state);
			for (const int32_t amount : source.pandora_resources) {
				append(state, resources, integer(amount));
			}
			put(state, contents, "resources", resources);
			const Value spell_ids = new_array(state);
			const Value spell_levels = new_array(state);
			// Bits of the four HoMM3 schools: 1 air, 2 fire, 4 water, 8 earth.
			const Value spell_school_masks = new_array(state);
			for (size_t index = 0; index < source.pandora_spell_ids.size(); ++index) {
				append(state, spell_ids, integer(source.pandora_spell_ids[index]));
				append(state, spell_levels, integer(source.pandora_spell_levels[index]));
				append(state, spell_school_masks, integer(source.pandora_spell_school_masks[index]));
			}
			put(state, contents, "spell_ids", spell_ids);
			put(state, contents, "spell_levels", spell_levels);
			put(state, contents, "spell_school_masks", spell_school_masks);
			const Value creatures = new_array(state);
			for (const auto &creature : source.pandora_creatures) {
				const Value entry = new_dict(state);
				put(state, entry, "creature_id", integer(creature.creature_id));
				put(state, entry, "quantity", integer(creature.quantity));
				put(state, entry, "level", integer(creature.level));
				put(state, entry, "ai_value", integer(creature.ai_value));
				append(state, creatures, entry);
			}
			put(state, contents, "creatures", creatures);
			put(state, object, "h3m_pandora_contents", contents);
		}
		put(state, object, "h3m_anchor_x", integer(source.x));
		put(state, object, "h3m_anchor_y", integer(source.y));
		put(state, object, "h3m_anchor_level", integer(source.level));
		put(state, object, "x", integer(x));
		put(state, object, "y", integer(y));
		put(state, object, "level", integer(level));
		const Value primary = new_dict(state);
		put(state, primary, "x", integer(x));
		put(state, primary, "y", integer(y));
		put(state, primary, "level", integer(level));
		put(state, object, "primary_tile", primary);
		const Value body_tiles = runtime_tile_points(state, source.body_tiles);
		if (is_empty(state, body_tiles)) {
			append(state, body_tiles, deep_copy(state, primary));
		}
		const Value visit_tiles = runtime_tile_points(state, source.action_tiles);
		if (is_empty(state, visit_tiles) && (kind == "town" || kind == "mine" || kind == "artifact" || kind == "reward_reference")) {
			append(state, visit_tiles, deep_copy(state, primary));
		}
		put(state, object, "body_tiles", body_tiles);
		put(state, object, "package_body_tiles", body_tiles);
		put(state, object, "package_block_tiles", runtime_tile_points(state, source.body_tiles));
		put(state, object, "package_visit_tiles", visit_tiles);
		if (!is_empty(state, visit_tiles)) {
			put(state, object, "visit_tile", state.at(visit_tiles.ref, 0));
		}
		put(state, object, "blocking_body", boolean(!source.body_tiles.empty()));
		apply_runtime_live_proxy_entry(state, object, live_proxy);
		const int32_t peer_index = source.cross_level_peer_serialized_index_0x4a6cf2;
		if (peer_index >= 0 && size_t(peer_index) >= projection.objects.size()) {
			const Value failure = failure_record(state, "native_cave_pair_peer_index_out_of_range", source.serialized_index);
			put(state, failure, "peer_serialized_index", integer(peer_index));
			append(state, failures, failure);
		} else if (peer_index >= 0) {
			const auto &peer = projection.objects[size_t(peer_index)];
			if (source.action_tiles.size() != 1U || peer.action_tiles.size() != 1U) {
				append(state, failures, failure_record(state, "native_cave_pair_action_tile_shape_invalid", source.serialized_index));
			} else {
				const Value transit = new_dict(state);
				put(state, transit, "schema_version", integer(1));
				put(state, transit, "kind", text(state, "paired_cave"));
				put(state, transit, "source_function", text(state, "0x4a6cf2"));
				put(state, transit, "group_id", text(state, "native_cave_" + runtime_placement_id(map_id, std::min(source.serialized_index, peer.serialized_index))));
				put(state, transit, "source_placement_id", text(state, runtime_placement_id(map_id, source.serialized_index)));
				put(state, transit, "target_placement_id", text(state, runtime_placement_id(map_id, peer.serialized_index)));
				put(state, transit, "entry", first_tile_point(state, source.action_tiles));
				put(state, transit, "exit", first_tile_point(state, peer.action_tiles));
				put(state, transit, "one_way", boolean(false));
				put(state, object, "native_transit", transit);
			}
		}
		if (source.monolith_source_group_0x4a7605_known) {
			if (source.action_tiles.size() != 1U) {
				append(state, failures, failure_record(state, "native_portal_action_tile_shape_invalid", source.serialized_index));
			} else {
				const Value transit = new_dict(state);
				put(state, transit, "schema_version", integer(1));
				put(state, transit, "kind", text(state, source.type_id == 45 ? "two_way_portal" : (source.type_id == 43 ? "one_way_entrance" : "one_way_exit")));
				put(state, transit, "source_function", text(state, "0x4a7605"));
				put(state, transit, "network_index", integer(source.monolith_network_index_0x4a7605));
				if (source.monolith_connection_ordinal_0x4a7605 >= 0) {
					// One network per placed connection; see the map library's
					// attach_owned_monolith_transit_groups for why colours repeat.
					put(state, transit, "group_id", text(state, "native_portal_" + map_id + "_connection_" + compat::itos(source.monolith_connection_ordinal_0x4a7605)));
					put(state, transit, "connection_index", integer(source.monolith_connection_ordinal_0x4a7605));
					put(state, transit, "zone", integer(source.monolith_zone_0x4a7605));
					const Value connection_zones = new_array(state);
					append(state, connection_zones, integer(source.monolith_connection_source_zone_0x4a7605));
					append(state, connection_zones, integer(source.monolith_connection_target_zone_0x4a7605));
					put(state, transit, "connection_zones", connection_zones);
					put(state, transit, "same_zone", boolean(source.monolith_connection_source_zone_0x4a7605 == source.monolith_connection_target_zone_0x4a7605));
				} else {
					put(state, transit, "group_id", text(state, "native_portal_" + map_id + (source.type_id == 45 ? "_two_way_" : "_one_way_") + compat::itos(source.subtype)));
				}
				put(state, transit, "source_placement_id", text(state, runtime_placement_id(map_id, source.serialized_index)));
				put(state, transit, "entry", first_tile_point(state, source.action_tiles));
				put(state, transit, "one_way", boolean(source.type_id != 45));
				const Value destinations = new_array(state);
				for (const int32_t destination_index : source.monolith_destination_serialized_indices_0x4a7605) {
					if (destination_index < 0 || size_t(destination_index) >= projection.objects.size()) {
						const Value failure = failure_record(state, "native_portal_destination_index_out_of_range", source.serialized_index);
						put(state, failure, "peer_serialized_index", integer(destination_index));
						append(state, failures, failure);
						continue;
					}
					const auto &peer = projection.objects[size_t(destination_index)];
					if (peer.action_tiles.size() != 1U) {
						append(state, failures, failure_record(state, "native_portal_destination_action_tile_shape_invalid", peer.serialized_index));
						continue;
					}
					const Value destination = new_dict(state);
					put(state, destination, "target_placement_id", text(state, runtime_placement_id(map_id, peer.serialized_index)));
					put(state, destination, "exit", first_tile_point(state, peer.action_tiles));
					append(state, destinations, destination);
				}
				put(state, transit, "destinations", destinations);
				put(state, object, "native_transit", transit);
			}
		}
		const std::string source_type_key = compat::itos(source.type_id);
		std::string resolution_status = string_field(state, object, "native_authored_pool_resolution_status");
		if (resolution_status.empty()) {
			if (has(state, source_kind_passthrough, source_type_key.c_str())) {
				resolution_status = "native_runtime_passthrough";
			} else if (has(state, source_type_exclusions, source_type_key.c_str())) {
				resolution_status = "unsupported_source_type";
				put(state, object, "native_authored_pool_exclusion_reason", get(state, source_type_exclusions, source_type_key.c_str(), text(state, "")));
			} else if (kind == "decorative_obstacle") {
				resolution_status = "renderer_managed_nonvisitable_body";
			} else if (has(state, source_type_pools, source_type_key.c_str())) {
				resolution_status = "mapped_pool_resolution_failed";
			} else {
				resolution_status = is_empty(state, visit_tiles) ? "unclassified_nonvisitable_source_type" : "unclassified_visitable_source_type";
			}
			put(state, object, "native_authored_pool_resolution_status", text(state, resolution_status));
		}
		const Value status_key = text(state, resolution_status);
		state.set(resolution_counts.ref, status_key, integer(gd::to_int(state, state.get(resolution_counts.ref, status_key, integer(0))) + 1));
		const bool visitable = !is_empty(state, visit_tiles);
		if (resolution_status == "unclassified_nonvisitable_source_type"
				|| (visitable && (resolution_status == "unsupported_source_type" || resolution_status == "mapped_pool_resolution_failed"
										 || resolution_status == "unclassified_visitable_source_type"))) {
			const Value failure = new_dict(state);
			put(state, failure, "code", text(state, resolution_status));
			put(state, failure, "type_id", integer(source.type_id));
			put(state, failure, "subtype", integer(source.subtype));
			put(state, failure, "definition_name", text(state, source.def_name));
			put(state, failure, "serialized_index", integer(source.serialized_index));
			put(state, failure, "visit_tile_count", integer(size_of(state, visit_tiles)));
			put(state, failure, "reason", get(state, object, "native_authored_pool_exclusion_reason", text(state, "")));
			append(state, failures, failure);
		}
		if (kind == "town") {
			const auto *slot = runtime_slot_for_town(source, seats);
			if (slot != nullptr && projection.team_count > 0 && (slot->color < 0 || size_t(slot->color) >= projection.player_team_assignments.size())) {
				const Value failure = failure_record(state, "native_town_owner_color_out_of_range", source.serialized_index);
				put(state, failure, "color", integer(slot->color));
				append(state, failures, failure);
				slot = nullptr;
			}
			const std::string player_id = slot == nullptr ? std::string() : "player_" + compat::itos(slot->color + 1);
			put(state, object, "owner", text(state, slot == nullptr ? "neutral" : (slot->human ? "player" : "enemy")));
			put(state, object, "owner_slot", integer(slot == nullptr ? 0 : slot->color + 1));
			put(state, object, "player_slot", integer(slot == nullptr ? 0 : slot->color + 1));
			put(state, object, "controlling_player_id", text(state, player_id));
			put(state, object, "team_id", text(state, slot == nullptr ? std::string() : (projection.team_count > 0
							? "team_" + compat::itos(projection.player_team_assignments[size_t(slot->color)])
							: player_id)));
			put(state, object, "player_type", text(state, slot == nullptr ? "neutral" : (slot->human ? "human" : "computer")));
			put(state, object, "is_start_town", boolean(slot != nullptr));
			put(state, object, "start_anchor", boolean(slot != nullptr));
			if (slot == nullptr) {
				const std::string faction_id = runtime_neutral_town_faction_id(source, town_type_faction_ids);
				put(state, object, "town_id", text(state, town_for_faction(faction_id)));
				put(state, object, "faction_id", text(state, faction_id));
			} else {
				put(state, object, "town_id", text(state, configured_runtime_town_id(state, slot, normalized_config)));
				put(state, object, "faction_id", text(state, configured_runtime_faction_id(state, slot, normalized_config)));
			}
		} else if (kind == "guard") {
			put(state, object, "native_guard_quantity", integer(source.guard_quantity));
			put(state, object, "native_guard_creature_subtype", integer(source.subtype));
			put(state, object, "native_guard_level", integer(source.guard_level));
			put(state, object, "native_guard_ai_value", integer(source.guard_ai_value));
			put(state, object, "encounter_id", text(state, "encounter_mire_raid"));
			put(state, object, "object_id", text(state, "encounter_mire_raid"));
			const Value control_tiles = runtime_guard_control_tiles(state, source, projection);
			put(state, object, "package_guard_control_zone_tiles", control_tiles);
			put(state, object, "package_guard_control_zone_tile_count", integer(size_of(state, control_tiles)));
			put(state, object, "package_guard_engagement_tiles", control_tiles);
			put(state, object, "package_guard_engagement_tile_count", integer(size_of(state, control_tiles)));
			put(state, object, "package_guard_control_zone_pathing_policy", text(state, "h3m_guard_control_forces_engagement_guard_body_remains_blocking_surface"));
			put(state, object, "package_guard_engagement_policy", text(state, "h3m_guard_control_forces_engagement"));
		} else if (kind == "mine") {
			if (is_empty(state, live_proxy)) {
				put(state, object, "site_id", text(state, source.subtype == 2 ? "site_ridge_quarry" : "site_brightwood_sawmill"));
			}
			put(state, object, "owner", text(state, "neutral"));
		} else if (kind == "reward_reference") {
			if (is_empty(state, live_proxy)) {
				put(state, object, "site_id", text(state, "site_generated_town_required_source_cache"));
			}
		}
		append(state, result, object);
	}
	const Value report = new_dict(state);
	put(state, report, "ok", boolean(is_empty(state, failures) && !is_empty(state, eligibility)));
	put(state, report, "objects", result);
	put(state, report, "failures", failures);
	put(state, report, "failure_count", integer(size_of(state, failures)));
	put(state, report, "resolution_counts", resolution_counts);
	put(state, report, "registry_path", text(state, kEligibilityPath));
	put(state, report, "registry_schema", text(state, kEligibilitySchema));
	put(state, report, "registry_loaded", boolean(!is_empty(state, eligibility)));
	return report;
}

// ------------------------------------------------ document validation

void append_issue(State &state, const Value &issues, const char *code, const std::string &path, const char *message, const Value &context) {
	const Value issue = new_dict(state);
	put(state, issue, "code", text(state, code));
	put(state, issue, "severity", text(state, "fail"));
	put(state, issue, "path", text(state, path));
	put(state, issue, "message", text(state, message));
	put(state, issue, "context", context);
	append(state, issues, issue);
}

void append_issue(State &state, const Value &issues, const char *code, const std::string &path, const char *message) {
	append_issue(state, issues, code, path, message, new_dict(state));
}

Value validation_report_result(State &state, const char *operation, const char *schema_id, const Value &document_id, const Value &document_hash,
		const Value &failures, const Value &warnings, const Value &metrics) {
	const bool ok = is_empty(state, failures);
	const Value report = new_dict(state);
	put(state, report, "schema_id", text(state, schema_id));
	put(state, report, "schema_version", integer(1));
	put(state, report, "document_id", document_id);
	put(state, report, "document_hash", document_hash);
	put(state, report, "status", text(state, ok ? "pass" : "fail"));
	put(state, report, "failure_count", integer(size_of(state, failures)));
	put(state, report, "warning_count", integer(size_of(state, warnings)));
	put(state, report, "failures", failures);
	put(state, report, "warnings", warnings);
	put(state, report, "metrics", metrics);

	const Value result = new_dict(state);
	put(state, result, "ok", boolean(ok));
	put(state, result, "status", text(state, ok ? "pass" : "fail"));
	put(state, result, "operation", text(state, operation));
	put(state, result, "report", report);
	put(state, result, "recoverable", boolean(false));
	if (!ok) {
		put(state, result, "error_code", text(state, "validation_failed"));
		put(state, result, "message", text(state, std::string(operation) + " failed structural document validation."));
	}
	return result;
}

// MapDocument.get_terrain_layer_ids().
std::vector<Value> terrain_layer_ids(State &state, const map_packages::MapDocument &document) {
	std::vector<Value> ids;
	const state::ValueList keys = state.dict(document.terrain_layers.ref).keys.list();
	for (const Value &key : keys) {
		const Value name = key.is_string_like() ? Value::str(key.ref) : Value::str(gd::stringify(state, key));
		const std::string &id = state.text(name.ref);
		if (id == "schema_id" || id == "schema_version" || id == "terrain_id_by_code") {
			continue;
		}
		if (state.get(document.terrain_layers.ref, name, Value()).kind == Kind::Dict) {
			ids.push_back(name);
		}
	}
	return ids;
}

// The size of MapDocument.get_tile_layer_u16(layer_id, level).
int64_t tile_layer_size(State &state, const map_packages::MapDocument &document, const Value &layer_id, int32_t level) {
	const Value layer = state.get(document.terrain_layers.ref, layer_id, Value());
	const Value levels = get(state, layer, "levels");
	if (levels.kind != Kind::Array || level < 0 || level >= state.array_size(levels.ref)) {
		return 0;
	}
	const Value codes = state.at(levels.ref, level);
	if (codes.kind == Kind::PackedInt32) {
		return int64_t(state.packed(codes.ref).ints.size());
	}
	return codes.kind == Kind::Array ? state.array_size(codes.ref) : 0;
}

// validate_map_document_structural_report of a document.
Value map_document_report(State &state, const map_packages::MapDocument &document) {
	const Value failures = new_array(state);
	const Value warnings = new_array(state);
	const Value metrics = new_dict(state);
	const int32_t width = document.width;
	const int32_t height = document.height;
	const int32_t level_count = document.level_count;
	// 64-bit so oversized dimensions cannot wrap to a small or zero count.
	const int64_t tile_count = int64_t(width) * int64_t(height) * int64_t(level_count);
	const int64_t expected_level_tile_count = int64_t(width) * int64_t(height);
	const bool dimensions_in_range = width <= kMaxDimension && height <= kMaxDimension && level_count <= kMaxLevelCount;
	put(state, metrics, "width", integer(width));
	put(state, metrics, "height", integer(height));
	put(state, metrics, "level_count", integer(level_count));
	put(state, metrics, "tile_count", integer(tile_count));
	put(state, metrics, "object_count", integer(int32_t(state.array_size(document.objects.ref))));
	if (strip(state.text(document.map_id.ref)).empty()) {
		append_issue(state, failures, "missing_map_id", "map_id", "Map document id is required.");
	}
	if (strip(state.text(document.map_hash.ref)).empty()) {
		append_issue(state, failures, "missing_map_hash", "map_hash", "Map document hash is required.");
	}
	if (width <= 0 || height <= 0 || level_count <= 0 || !dimensions_in_range || tile_count != expected_level_tile_count * int64_t(level_count)) {
		const Value context = new_dict(state);
		put(state, context, "width", integer(width));
		put(state, context, "height", integer(height));
		put(state, context, "level_count", integer(level_count));
		put(state, context, "tile_count", integer(tile_count));
		put(state, context, "max_dimension", integer(kMaxDimension));
		put(state, context, "max_level_count", integer(kMaxLevelCount));
		append_issue(state, failures, "invalid_map_dimensions", "dimensions",
				"Map dimensions, levels, and tile count must be positive, within supported limits, and internally consistent.", context);
	}
	if (!dimensions_in_range) {
		return validation_report_result(state, "validate_map_document", "aurelion_map_validation_report", document.map_id, document.map_hash, failures,
				warnings, metrics);
	}

	const std::vector<Value> layer_ids = terrain_layer_ids(state, document);
	put(state, metrics, "terrain_layer_count", integer(int64_t(layer_ids.size())));
	if (layer_ids.empty()) {
		append_issue(state, failures, "missing_terrain_layers", "terrain_layers", "Map document must contain at least one terrain tile layer.");
	}
	for (const Value &layer_id : layer_ids) {
		for (int32_t level = 0; level < level_count; ++level) {
			const int64_t actual = tile_layer_size(state, document, layer_id, level);
			if (actual != expected_level_tile_count) {
				const Value context = new_dict(state);
				put(state, context, "layer_id", layer_id);
				put(state, context, "level", integer(level));
				put(state, context, "actual", integer(actual));
				put(state, context, "expected", integer(expected_level_tile_count));
				append_issue(state, failures, "terrain_layer_tile_count_mismatch", "terrain_layers." + state.text(layer_id.ref),
						"Terrain layer level tile count must match width * height.", context);
			}
		}
	}
	const Value roads = get(state, document.terrain_layers, "roads");
	if (roads.kind == Kind::Array) {
		const int64_t road_count = state.array_size(roads.ref);
		for (int64_t road_index = 0; road_index < road_count; ++road_index) {
			const Value road = state.at(roads.ref, road_index);
			if (road.kind != Kind::Dict) {
				const Value context = new_dict(state);
				put(state, context, "index", integer(road_index));
				append_issue(state, failures, "invalid_road_record", "terrain_layers.roads", "Road overlay records must be dictionaries.", context);
				continue;
			}
			const Value tiles = get(state, road, "tiles");
			const int32_t road_tile_count = tiles.kind == Kind::Array ? int32_t(state.array_size(tiles.ref)) : int32_field(state, road, "tile_count", 0);
			if (road_tile_count <= 0) {
				const Value context = new_dict(state);
				put(state, context, "index", integer(road_index));
				put(state, context, "tile_count", integer(road_tile_count));
				append_issue(state, failures, "invalid_road_tile_count", "terrain_layers.roads", "Road overlays must contain at least one tile.", context);
			}
			if (tiles.kind != Kind::Array) {
				continue;
			}
			const int64_t count = state.array_size(tiles.ref);
			for (int64_t tile_index = 0; tile_index < count; ++tile_index) {
				const Value tile = state.at(tiles.ref, tile_index);
				if (tile.kind != Kind::Dict) {
					const Value context = new_dict(state);
					put(state, context, "road_index", integer(road_index));
					put(state, context, "tile_index", integer(tile_index));
					append_issue(state, failures, "invalid_road_tile", "terrain_layers.roads", "Road overlay tiles must be dictionaries.", context);
					continue;
				}
				const int32_t x = int32_field(state, tile, "x", -1);
				const int32_t y = int32_field(state, tile, "y", -1);
				const int32_t level = int32_field(state, tile, "level", 0);
				if (x < 0 || y < 0 || x >= width || y >= height || level < 0 || level >= level_count) {
					const Value context = new_dict(state);
					put(state, context, "road_index", integer(road_index));
					put(state, context, "tile_index", integer(tile_index));
					put(state, context, "x", integer(x));
					put(state, context, "y", integer(y));
					put(state, context, "level", integer(level));
					append_issue(state, failures, "road_tile_out_of_bounds", "terrain_layers.roads",
							"Road overlay tiles must be inside map bounds and level range.", context);
				}
			}
		}
	}

	std::unordered_set<std::string> placement_ids;
	const int32_t object_count = int32_t(state.array_size(document.objects.ref));
	for (int32_t index = 0; index < object_count; ++index) {
		const Value object = state.at(document.objects.ref, index);
		if (object.kind != Kind::Dict || is_empty(state, object)) {
			const Value context = new_dict(state);
			put(state, context, "index", integer(index));
			append_issue(state, failures, "invalid_object_record", "objects", "Map object records must be dictionaries.", context);
			continue;
		}
		const int32_t x = int32_field(state, object, "x", -1);
		const int32_t y = int32_field(state, object, "y", -1);
		const int32_t level = int32_field(state, object, "level", 0);
		const std::string placement_id = strip(string_field(state, object, "placement_id"));
		if (placement_id.empty()) {
			const Value context = new_dict(state);
			put(state, context, "index", integer(index));
			append_issue(state, failures, "missing_object_placement_id", "objects", "Map object placement ids are required.", context);
		} else if (!placement_ids.insert(placement_id).second) {
			const Value context = new_dict(state);
			put(state, context, "index", integer(index));
			put(state, context, "placement_id", text(state, placement_id));
			append_issue(state, failures, "duplicate_object_placement_id", "objects", "Map object placement ids must be unique.", context);
		}
		if (x < 0 || y < 0 || x >= width || y >= height || level < 0 || level >= level_count) {
			const Value context = new_dict(state);
			put(state, context, "index", integer(index));
			put(state, context, "x", integer(x));
			put(state, context, "y", integer(y));
			put(state, context, "level", integer(level));
			append_issue(state, failures, "object_out_of_bounds", "objects", "Map object placement must be inside map bounds and level range.", context);
		}
	}
	return validation_report_result(state, "validate_map_document", "aurelion_map_validation_report", document.map_id, document.map_hash, failures,
			warnings, metrics);
}

// validate_scenario_document_structural_report of a document, with the map's
// report already made when map_validation is one.
Value scenario_document_report(State &state, const map_packages::ScenarioDocument &scenario, const map_packages::MapDocument *map,
		const Value &map_validation) {
	const Value failures = new_array(state);
	const Value warnings = new_array(state);
	const Value metrics = new_dict(state);
	const Value map_ref = scenario.map_ref;
	put(state, metrics, "player_slot_count", integer(size_of(state, scenario.player_slots)));
	put(state, metrics, "objective_key_count", integer(size_of(state, scenario.objectives)));
	put(state, metrics, "map_ref_present", boolean(!is_empty(state, map_ref)));
	if (strip(state.text(scenario.scenario_id.ref)).empty()) {
		append_issue(state, failures, "missing_scenario_id", "scenario_id", "Scenario document id is required.");
	}
	if (strip(state.text(scenario.scenario_hash.ref)).empty()) {
		append_issue(state, failures, "missing_scenario_hash", "scenario_hash", "Scenario document hash is required.");
	}
	if (is_empty(state, map_ref)) {
		append_issue(state, failures, "missing_map_ref", "map_ref", "Scenario document must reference a map document.");
	}
	if (is_empty(state, scenario.player_slots)) {
		append_issue(state, failures, "missing_player_slots", "player_slots", "Scenario document must include player slot records.");
	}
	if (map == nullptr) {
		append_issue(state, failures, "missing_map_document", "map_document", "Scenario validation requires the referenced MapDocument.");
	} else {
		// Callers that already validated this map pass the report in, so the
		// map is not walked a second time.
		const Value report_of_map = is_empty(state, map_validation) ? map_document_report(state, *map) : map_validation;
		const Value map_report = dict_or_new(state, get(state, report_of_map, "report"));
		if (string_field(state, map_report, "status") != "pass") {
			append_issue(state, failures, "referenced_map_invalid", "map_document", "Referenced map document did not pass structural validation.",
					map_report);
		}
		if (string_field(state, map_ref, "map_id") != state.text(map->map_id.ref)) {
			append_issue(state, failures, "map_ref_id_mismatch", "map_ref.map_id", "Scenario map reference id must match the referenced MapDocument.");
		}
		if (string_field(state, map_ref, "map_hash") != state.text(map->map_hash.ref)) {
			append_issue(state, failures, "map_ref_hash_mismatch", "map_ref.map_hash", "Scenario map reference hash must match the referenced MapDocument.");
		}
	}
	return validation_report_result(state, "validate_scenario_document", "aurelion_scenario_validation_report", scenario.scenario_id,
			scenario.scenario_hash, failures, warnings, metrics);
}

// ------------------------------------------------------- adoption

Value native_conversion_fail(State &state, const char *code, const char *message) {
	const Value failure = new_dict(state);
	put(state, failure, "code", text(state, code));
	put(state, failure, "severity", text(state, "fail"));
	put(state, failure, "path", text(state, "convert_generated_payload"));
	put(state, failure, "message", text(state, message));
	put(state, failure, "context", new_dict(state));
	const Value failures = new_array(state);
	append(state, failures, failure);

	const Value report = new_dict(state);
	put(state, report, "schema_id", text(state, "aurelion_native_random_map_package_session_adoption_report_v1"));
	put(state, report, "schema_version", integer(1));
	put(state, report, "status", text(state, "fail"));
	put(state, report, "failure_count", integer(1));
	put(state, report, "warning_count", integer(0));
	put(state, report, "failures", failures);
	put(state, report, "warnings", new_array(state));
	put(state, report, "metrics", new_dict(state));
	put(state, report, "package_session_adoption_ready", boolean(false));
	put(state, report, "native_runtime_authoritative", boolean(false));
	put(state, report, "full_parity_claim", boolean(false));

	const Value result = new_dict(state);
	put(state, result, "ok", boolean(false));
	put(state, result, "status", text(state, "fail"));
	put(state, result, "error_code", text(state, code));
	put(state, result, "message", text(state, message));
	put(state, result, "report", report);
	put(state, result, "adoption_status", text(state, "blocked"));
	return result;
}

Value blocked(State &state, const char *code, const char *message) {
	const Value result = new_dict(state);
	put(state, result, "ok", boolean(false));
	put(state, result, "status", text(state, "blocked"));
	put(state, result, "error_code", text(state, code));
	put(state, result, "message", text(state, message));
	return result;
}

Value map_ref_of(State &state, const Value &map_id, const Value &map_hash) {
	const Value map_ref = new_dict(state);
	put(state, map_ref, "schema_id", text(state, kMapSchemaId));
	put(state, map_ref, "schema_version", integer(kSchemaVersion));
	put(state, map_ref, "map_id", map_id);
	put(state, map_ref, "map_hash", map_hash);
	put(state, map_ref, "source_kind", text(state, "generated_h3maped_native_parity"));
	return map_ref;
}

// variant_contains_object: an opaque value anywhere in the containers.
bool holds_opaque(State &state, const Value &value) {
	switch (value.kind) {
		case Kind::Opaque:
			return true;
		case Kind::Dict: {
			const state::DictNode &node = state.dict(value.ref);
			for (size_t index = 0; index < node.keys.size(); ++index) {
				if (holds_opaque(state, node.keys[index]) || holds_opaque(state, node.values[index])) {
					return true;
				}
			}
			return false;
		}
		case Kind::Array: {
			const int64_t count = state.array_size(value.ref);
			for (int64_t index = 0; index < count; ++index) {
				if (holds_opaque(state, state.at(value.ref, index))) {
					return true;
				}
			}
			return false;
		}
		default:
			return false;
	}
}

// write_package_dictionary's failures.
const char *write_failure_message(const std::string &code) {
	if (code == "create_directory_failed") {
		return "Package parent directory could not be created.";
	}
	if (code == "write_failed") {
		return "Package file could not be written completely.";
	}
	if (code == "replace_failed") {
		return "Written package could not replace the previous file.";
	}
	return "Package file could not be opened for writing.";
}

} // namespace

const char *Documents::write_package(content::Files &files, const std::string &path, const std::string &json) {
	return files.write(path, json) ? nullptr : "open_failed";
}

Value Documents::package_written(State &, const std::string &, const Value &, bool cache_profile) {
	if (cache_profile) {
		throw state::NotPorted("left out of the map generation port: the package browser cache profile");
	}
	return Value();
}

Value validate_map_document(State &state, const map_packages::MapDocument *document) {
	if (document == nullptr) {
		const Value failures = new_array(state);
		append_issue(state, failures, "missing_map_document", "map_document", "Map validation requires a MapDocument.");
		return validation_report_result(state, "validate_map_document", "aurelion_map_validation_report", text(state, ""), text(state, ""), failures,
				new_array(state), new_dict(state));
	}
	return map_document_report(state, *document);
}

Value validate_scenario_document(State &state, const map_packages::ScenarioDocument *scenario, const map_packages::MapDocument *map) {
	if (scenario == nullptr) {
		const Value failures = new_array(state);
		append_issue(state, failures, "missing_scenario_document", "scenario_document", "Scenario validation requires a ScenarioDocument.");
		return validation_report_result(state, "validate_scenario_document", "aurelion_scenario_validation_report", text(state, ""), text(state, ""),
				failures, new_array(state), new_dict(state));
	}
	return scenario_document_report(state, *scenario, map, Value());
}

Value compute_document_hash(State &state, const Value &document) {
	const Value result = new_dict(state);
	if (holds_opaque(state, document)) {
		put(state, result, "ok", boolean(false));
		put(state, result, "status", text(state, "fail"));
		put(state, result, "error_code", text(state, "unhashable_object_value"));
		put(state, result, "message", text(state, "Document hashes cover plain data only; object values have no stable identity."));
		put(state, result, "algorithm", text(state, "canonical_variant_fnv1a32"));
		return result;
	}
	put(state, result, "ok", boolean(true));
	put(state, result, "status", text(state, "pass"));
	put(state, result, "algorithm", text(state, "canonical_variant_fnv1a32"));
	put(state, result, "hash", text(state, document_hash(state, document)));
	return result;
}

std::string document_hash(State &state, const Value &value) {
	return "fnv1a32:" + hash32_hex(canonical(state, value));
}

std::string text_hash(std::string_view text) {
	return hash32_hex(text);
}

Value normalize_random_map_config(State &state, const Value &config) {
	const Value size = dict_or_new(state, get(state, config, "size"));
	const Value profile = dict_or_new(state, get(state, config, "profile"));
	const Value player_setup = dict_or_new(state, get(state, config, "player_setup"));

	const std::string size_class_id = normalized_size_class_id(state, config, size);
	const int32_t default_dimension = dimension_for_size_class(size_class_id, 36);
	const int32_t width = nested_size_int(state, config, size, "width", "requested_width", default_dimension);
	const int32_t height = nested_size_int(state, config, size, "height", "requested_height", default_dimension);
	const Value player_constraints = normalized_player_constraints(state, config);
	const int32_t player_count = int32_field(state, player_constraints, "player_count", 2);
	const Value terrain_ids = normalized_string_array(state, get(state, profile, "terrain_ids"), default_terrain_pool(state));
	const Value seat_faction_ids = seat_faction_list(state, get(state, config, "seat_faction_ids"), player_count);
	const Value faction_ids = !is_empty(state, seat_faction_ids)
			? seat_faction_ids
			: ensure_repeated_to_count(state, normalized_string_array(state, get(state, profile, "faction_ids"), default_faction_pool(state)),
					  default_faction_pool(state), player_count);
	const Value town_ids = town_ids_for_factions(state, get(state, profile, "town_ids"), faction_ids, player_count);

	const Value result = new_dict(state);
	put(state, result, "schema_id", text(state, kNativeRmgSchemaId));
	put(state, result, "schema_version", integer(1));
	put(state, result, "normalizer_version", text(state, kNativeRmgVersion));
	const Value seed = text(state, normalized_text(state, config, "seed", "0"));
	put(state, result, "seed", seed);
	put(state, result, "normalized_seed", seed);
	put(state, result, "width", integer(width));
	put(state, result, "height", integer(height));
	put(state, result, "level_count", integer(std::max<int32_t>(1, std::min<int32_t>(2, normalized_int(state, size, "level_count", normalized_int(state, config, "level_count", 1))))));
	put(state, result, "template_id", text(state, normalized_text(state, config, "template_id", normalized_text(state, profile, "template_id", ""))));
	put(state, result, "profile_id", text(state, normalized_text(state, profile, "id", normalized_text(state, config, "profile_id", ""))));
	put(state, result, "size_class_id", text(state, size_class_id));
	put(state, result, "water_mode", text(state, normalized_water_mode(state, config, size)));
	put(state, result, "monster_strength", text(state, lower(strip(normalized_text(state, config, "monster_strength", "random")))));
	put(state, result, "player_constraints", player_constraints);
	put(state, result, "terrain_ids", terrain_ids);
	put(state, result, "faction_ids", faction_ids);
	put(state, result, "town_ids", town_ids);
	if (!is_empty(state, seat_faction_ids)) {
		put(state, result, "seat_faction_ids", seat_faction_ids);
	}
	if (!is_empty(state, player_setup)) {
		const Value normalized_player_setup = new_dict(state);
		put(state, normalized_player_setup, "faction_id", text(state, strip(string_field(state, player_setup, "faction_id"))));
		put(state, normalized_player_setup, "hero_id", text(state, strip(string_field(state, player_setup, "hero_id"))));
		put(state, normalized_player_setup, "selection_mode", text(state, strip(string_field(state, player_setup, "selection_mode", "player_selected"))));
		put(state, result, "player_setup", normalized_player_setup);
	}
	put(state, result, "template_selection_mode", text(state, "recovered_h3maped_exe_rng_exact_state_chain"));
	put(state, result, "template_selection_authority", text(state, "recovered_h3maped_exe_source_order"));
	put(state, result, "template_selection_runtime_generation_allowed", boolean(true));
	put(state, result, "translated_template_authority_used", boolean(false));
	const bool supported_parity_config = bool_field(state, runtime_policy_classification(state, result), "runtime_generation_allowed", false);
	put(state, result, "full_generation_status",
			text(state, supported_parity_config ? "native_runtime_ready_for_supported_scope" : "native_runtime_blocked_outside_supported_scope"));
	put(state, result, "supported_parity_config", boolean(supported_parity_config));
	put(state, result, "h3maped_strict_scope", text(state, strict_scope_id(state, result)));
	put(state, result, "normalization_scope",
			text(state, supported_parity_config ? "native_runtime_generation_supported_scope" : "native_runtime_generation_unsupported_scope"));
	return result;
}

Value random_map_config_identity(State &state, const Value &config) {
	const Value normalized = normalize_random_map_config(state, config);
	const std::string canonical_config = canonical(state, normalized);
	const std::string signature = hash32_hex(canonical_config);

	const Value result = new_dict(state);
	put(state, result, "ok", boolean(true));
	put(state, result, "schema_id", text(state, "aurelion_native_random_map_identity"));
	put(state, result, "schema_version", integer(1));
	put(state, result, "algorithm", text(state, "canonical_variant_fnv1a32_config_normalization"));
	put(state, result, "signature", text(state, signature));
	put(state, result, "config_hash", text(state, "fnv1a32:" + signature));
	put(state, result, "map_id", text(state, "native_rmg_" + signature));
	put(state, result, "normalized_seed", text(state, string_field(state, normalized, "normalized_seed")));
	put(state, result, "width", integer(int32_field(state, normalized, "width", 0)));
	put(state, result, "height", integer(int32_field(state, normalized, "height", 0)));
	put(state, result, "level_count", integer(int32_field(state, normalized, "level_count", 1)));
	put(state, result, "template_id", text(state, string_field(state, normalized, "template_id")));
	put(state, result, "profile_id", text(state, string_field(state, normalized, "profile_id")));
	put(state, result, "canonical_config", text(state, canonical_config));
	put(state, result, "normalized_config", normalized);
	const Value runtime_policy = runtime_policy_classification(state, normalized);
	const bool supported = bool_field(state, runtime_policy, "runtime_generation_allowed", false);
	put(state, result, "full_generation_status",
			text(state, supported ? "native_runtime_ready_for_supported_scope" : "native_runtime_blocked_outside_supported_scope"));
	put(state, result, "supported_parity_config", boolean(supported));
	put(state, result, "runtime_policy_classification", runtime_policy);
	return result;
}

Value generate_random_map(State &state, content::Files &files, Documents &documents, GeneratorCache &cache, const Value &config, const Value &options) {
	const bool include_performance_profile = bool_field(state, options, "include_performance_profile", false);
	const auto total_started_at = SteadyClock::now();
	const Value performance_profile = new_dict(state);
	put(state, performance_profile, "schema_id", text(state, "aurelion_native_rmg_generation_performance_profile_v1"));
	put(state, performance_profile, "size_class_id", text(state, string_field(state, config, "size_class_id")));
	put(state, performance_profile, "buckets_ms", new_dict(state));
	const auto record_bucket = [&](const char *bucket, const SteadyClock::time_point &started_at) {
		if (include_performance_profile) {
			put(state, get(state, performance_profile, "buckets_ms"), bucket, Value::of_float(elapsed_milliseconds(started_at)));
		}
	};
	const auto normalize_started_at = SteadyClock::now();
	const Value normalized = normalize_random_map_config(state, config);
	record_bucket("normalize_config", normalize_started_at);
	if (!supports_land_scope(state, normalized)) {
		return exact_chain_unimplemented_blocked_result(state, normalized);
	}
	const std::string monster_strength = string_field(state, normalized, "monster_strength", "random");
	if (!known_monster_strength(monster_strength)) {
		const Value result = exact_chain_unimplemented_blocked_result(state, normalized);
		put(state, result, "error_code", text(state, "native_rmg_monster_strength_unsupported"));
		put(state, result, "message", text(state, "Monster strength must be random, weak, normal, or strong."));
		return result;
	}

	const Value players = dict_or_new(state, get(state, normalized, "player_constraints"));
	h3::H3MapedRmgWorkflowConfig workflow_config;
	const std::string size_class = string_field(state, normalized, "size_class_id");
	const std::string water_mode = string_field(state, normalized, "water_mode", "land");
	workflow_config.size_class = size_class;
	workflow_config.water_mode = water_mode;
	workflow_config.width = int32_field(state, normalized, "width", 0);
	workflow_config.height = int32_field(state, normalized, "height", 0);
	workflow_config.level_count = int32_field(state, normalized, "level_count", 1);
	// Every seat is generated as H3MapEd's "human or computer", each on its own
	// team (owner decision, 2026-10-29): with one human, the template pick also
	// offers single-human challenge templates such as Gauntlet. runtime_seats
	// picks the game's human seats afterwards.
	workflow_config.player_count = int32_field(state, players, "player_count", 2);
	workflow_config.human_count = workflow_config.player_count;
	const std::string seed_text = string_field(state, normalized, "normalized_seed", "0");
	workflow_config.seed = uint32_t(uint64_t(compat::to_int(seed_text)) & 0xffffffffULL);
	workflow_config.setup_object_0x34_known = true;
	workflow_config.setup_object_0x34 = workflow_config.human_count;
	workflow_config.setup_object_0x38_known = true;
	workflow_config.setup_object_0x38 = workflow_config.human_count;
	workflow_config.setup_object_0x3c_known = true;
	workflow_config.setup_object_0x3c = 0;
	workflow_config.setup_object_0x40_known = true;
	workflow_config.setup_object_0x40 = 0;
	workflow_config.setup_object_0x44_known = true;
	workflow_config.setup_object_0x44 = h3::water_mode_code(water_mode);
	workflow_config.setup_object_raw_0x48_known = true;
	workflow_config.setup_object_raw_0x48 = monster_strength_raw_0x48(monster_strength);
	workflow_config.setup_object_0x48_known = false;
	workflow_config.setup_object_0x4c_known = true;
	workflow_config.setup_object_0x4c = 2;
	workflow_config.setup_caller_arg_0x0c_known = true;
	workflow_config.setup_caller_arg_0x0c = h3::DIRECT_ENTRY_OPTIONAL_HANDLER_SENTINEL_0X4602C1;

	const auto workflow_started_at = SteadyClock::now();
	const std::string core_key = generated_core_key(state, normalized);
	std::shared_ptr<const GeneratorCache::Core> core;
	if (cache.last != nullptr && cache.last->key == core_key) {
		core = cache.last;
	}
	const bool core_reused = core != nullptr;
	if (!core_reused) {
		auto fresh = std::make_shared<GeneratorCache::Core>();
		fresh->key = core_key;
		// The workflow result holds every private generator buffer (hundreds of
		// MB on Large and XL maps): only the fields read after projection are
		// kept.
		auto workflow = std::make_unique<h3::H3MapedRmgWorkflowResult>(h3::run_h3maped_rmg_entry_to_writeout_workflow(workflow_config, &fresh->projection));
		fresh->workflow_status = workflow->status;
		fresh->workflow_phase = workflow->current_phase_id;
		fresh->workflow_blocked_reason = workflow->blocked_reason;
		fresh->payload_token = hash32_hex_bytes(workflow->final_payload_writeout_0x4ad1e3.payload_bytes);
		fresh->final_payload_byte_count = workflow->final_payload_writeout_0x4ad1e3.total_payload_byte_count;
		fresh->selected_template_catalog_index = workflow->template_selection_0x4ac552.selected_source_catalog_index;
		fresh->runtime_zone_count = int32_t(workflow->template_selection_0x4ac552.runtime_seed.runtime_zone_seeds.size());
		fresh->cut_off_town_repair_applied = workflow->cut_off_town_repair_applied;
		fresh->cut_off_towns_before_repair = workflow->cut_off_towns_before_repair;
		fresh->cut_off_towns_after_repair = workflow->cut_off_towns_after_repair;
		if (workflow->template_selection_0x4ac552.split_link_graph_repicked) {
			fresh->split_template_repicked_from = workflow->template_selection_0x4ac552.split_link_graph_rolled_template_name;
		}
		workflow.reset();
		core = fresh;
		if (fresh->projection.applied) {
			cache.last = core;
		}
	}
	record_bucket("recovered_workflow", workflow_started_at);
	const h3::RuntimeMapPayloadProjection &projection = core->projection;
	const std::string &payload_token = core->payload_token;
	const Value cut_off_town_repair = new_dict(state);
	put(state, cut_off_town_repair, "applied", boolean(core->cut_off_town_repair_applied));
	put(state, cut_off_town_repair, "towns_cut_off_before", integer(core->cut_off_towns_before_repair));
	put(state, cut_off_town_repair, "towns_cut_off_after", integer(core->cut_off_towns_after_repair));
	put(state, cut_off_town_repair, "split_template_repicked_from", text(state, core->split_template_repicked_from));
	if (!projection.applied) {
		const Value result = new_dict(state);
		put(state, result, "ok", boolean(false));
		put(state, result, "status", text(state, "blocked"));
		put(state, result, "generation_status", text(state, "native_rmg_workflow_blocked"));
		put(state, result, "error_code", text(state, "native_rmg_final_payload_projection_blocked"));
		put(state, result, "message", text(state, projection.blocked_reason));
		put(state, result, "workflow_status", text(state, core->workflow_status));
		put(state, result, "workflow_phase", text(state, core->workflow_phase));
		put(state, result, "workflow_blocked_reason", text(state, core->workflow_blocked_reason));
		put(state, result, "normalized_config", deep_copy(state, normalized));
		put(state, result, "runtime_generation_allowed", boolean(false));
		put(state, result, "native_runtime_authoritative", boolean(false));
		return result;
	}

	const Value player_setup = dict_or_new(state, get(state, normalized, "player_setup"));
	const std::string player_faction_id = strip(string_field(state, player_setup, "faction_id"));
	const std::string player_hero_id = strip(string_field(state, player_setup, "hero_id"));
	// A setup that names every seat's faction puts them all in the identity,
	// so two line-ups on one map never share a package.
	const Value seat_faction_ids = array_or_new(state, get(state, normalized, "seat_faction_ids"));
	std::string identity_factions = player_faction_id;
	if (!is_empty(state, seat_faction_ids)) {
		identity_factions.clear();
		const int64_t count = state.array_size(seat_faction_ids.ref);
		for (int64_t index = 0; index < count; ++index) {
			if (index > 0) {
				identity_factions += ',';
			}
			identity_factions += string_of(state, state.at(seat_faction_ids.ref, index));
		}
	}
	const std::string runtime_identity_token = is_empty(state, player_setup) && is_empty(state, seat_faction_ids)
			? payload_token
			: hash32_hex(payload_token + ":" + identity_factions + ":" + player_hero_id);
	const std::string map_id = "native_h3maped_" + runtime_identity_token;
	const std::string map_hash = "fnv1a32:" + runtime_identity_token;
	// The placement ids seed each object's content. A setup that names every
	// seat gets the map of its generator inputs alone, so its line-ups share
	// one map; a setup that names only the player's faction keeps its ids.
	const std::string placement_seed_id = is_empty(state, seat_faction_ids) ? map_id : "native_h3maped_" + payload_token;
	const std::string scenario_id = map_id + "_skirmish";
	const std::string scenario_hash = "fnv1a32:" + hash32_hex(map_hash + ":scenario");
	const Value map_id_value = text(state, map_id);
	const Value map_hash_value = text(state, map_hash);

	const Value map_state = new_dict(state);
	put(state, map_state, "map_id", map_id_value);
	put(state, map_state, "map_hash", map_hash_value);
	put(state, map_state, "source_kind", text(state, "generated_h3maped_native_parity"));
	put(state, map_state, "width", integer(projection.width));
	put(state, map_state, "height", integer(projection.height));
	put(state, map_state, "level_count", integer(projection.level_count));
	const Value metadata = new_dict(state);
	put(state, metadata, "generated", boolean(true));
	put(state, metadata, "source_kind", text(state, "generated_h3maped_native_parity"));
	put(state, metadata, "source_template_authority", text(state, "h3maped_exe_rng"));
	put(state, metadata, "source_order_authority", text(state, "recovered_h3maped_exe_source_order"));
	const std::string source_template_id = "h3maped_template_" + pad_zeros(compat::itos(core->selected_template_catalog_index), 3);
	put(state, metadata, "source_template_id", text(state, source_template_id));
	put(state, metadata, "template_id", text(state, source_template_id));
	put(state, metadata, "full_generation_status", text(state, "native_runtime_ready"));
	put(state, metadata, "cut_off_town_repair", cut_off_town_repair);
	put(state, metadata, "validation_status", text(state, "pass"));
	put(state, metadata, "native_runtime_authoritative", boolean(true));
	put(state, metadata, "full_parity_claim", boolean(true));
	put(state, metadata, "native_h3m_final_payload_parity", boolean(true));
	put(state, metadata, "runtime_payload_projection_complete", boolean(true));
	put(state, metadata, "production_ready", boolean(true));
	const Value package_normalized_config = deep_copy(state, normalized);
	put(state, package_normalized_config, "template_id", text(state, source_template_id));
	put(state, package_normalized_config, "source_template_id", text(state, source_template_id));
	put(state, package_normalized_config, "full_generation_status", text(state, "native_runtime_ready"));
	put(state, metadata, "normalized_config", package_normalized_config);
	put(state, metadata, "final_payload_byte_count", integer(core->final_payload_byte_count));
	put(state, metadata, "final_payload_fnv1a32", text(state, payload_token));
	put(state, metadata, "runtime_player_setup", deep_copy(state, player_setup));
	const Value component_counts = new_dict(state);
	put(state, component_counts, "tile_count", integer(projection.tile_count));
	put(state, component_counts, "object_count", integer(projection.object_count));
	put(state, component_counts, "object_definition_count", integer(projection.object_definition_count));
	put(state, component_counts, "road_cell_count", integer(int32_t(projection.road_tiles.size())));
	put(state, component_counts, "zone_count", integer(core->runtime_zone_count));
	int32_t town_count = 0;
	for (const auto &object : projection.objects) {
		if (object.type_id == 98) {
			++town_count;
		}
	}
	put(state, component_counts, "town_count", integer(town_count));
	put(state, metadata, "component_counts", component_counts);
	put(state, map_state, "metadata", metadata);
	const auto terrain_started_at = SteadyClock::now();
	put(state, map_state, "terrain_layers", runtime_terrain_layers(state, projection));
	record_bucket("terrain_variant_projection", terrain_started_at);
	const Value route_graph = new_dict(state);
	put(state, route_graph, "schema_id", text(state, "aurelion_route_graph"));
	put(state, route_graph, "nodes", new_array(state));
	put(state, route_graph, "edges", new_array(state));
	put(state, map_state, "route_graph", route_graph);
	const auto objects_started_at = SteadyClock::now();
	const std::vector<h3::FinalHeaderPlayerSlot4ac857> seats = runtime_seats(projection, int32_field(state, players, "human_count", 1));
	const Value object_projection = runtime_objects(state, files, placement_seed_id, projection, seats, normalized);
	record_bucket("object_variant_projection", objects_started_at);
	if (!bool_field(state, object_projection, "ok", false)) {
		const Value result = blocked(state, "native_rmg_authored_object_pool_resolution_failed",
				"Native final-payload objects did not all resolve through an original-content pool or an explicit nonvisitable/passthrough owner.");
		put(state, result, "object_pool_resolution", object_projection);
		put(state, result, "final_payload_fnv1a32", text(state, payload_token));
		put(state, result, "final_payload_byte_count", integer(core->final_payload_byte_count));
		return result;
	}
	const Value pool_resolution = new_dict(state);
	for (const char *field : { "failure_count", "resolution_counts", "registry_path", "registry_schema", "registry_loaded" }) {
		put(state, pool_resolution, field, get(state, object_projection, field));
	}
	put(state, pool_resolution, "ok", boolean(true));
	put(state, metadata, "native_authored_object_pool_resolution", pool_resolution);
	put(state, map_state, "metadata", metadata);
	put(state, map_state, "objects", get(state, object_projection, "objects", new_array(state)));
	map_packages::MapDocument *map_document = nullptr;
	const Value map_document_value = documents.new_map_document(map_document);
	// Everything in map_state was built above for this document alone.
	map_packages::configure_map_document(state, *map_document, map_state, false);

	const Value player_slots = new_array(state);
	const Value enemy_factions = new_array(state);
	const Value player_starts = new_array(state);
	const Value player_start_towns = new_array(state);
	for (const auto &slot : seats) {
		if (!slot.active) {
			continue;
		}
		if (slot.color < 0 || size_t(slot.color) >= projection.player_team_assignments.size()) {
			const Value result = blocked(state, "native_rmg_player_color_out_of_range", "Native player slot color is outside the recovered eight-player team table.");
			put(state, result, "player_color", integer(slot.color));
			return result;
		}
		const std::string player_id = "player_" + compat::itos(slot.color + 1);
		// A zero team count is the recovered header's free-for-all form.
		const std::string team_id = projection.team_count > 0 ? "team_" + compat::itos(projection.player_team_assignments[size_t(slot.color)]) : player_id;
		const Value player_slot = new_dict(state);
		put(state, player_slot, "slot", integer(slot.color + 1));
		put(state, player_slot, "color", integer(slot.color));
		put(state, player_slot, "player_id", text(state, player_id));
		put(state, player_slot, "team_id", text(state, team_id));
		put(state, player_slot, "source_team_index", integer(projection.team_count > 0 ? int32_t(projection.player_team_assignments[size_t(slot.color)]) : -1));
		put(state, player_slot, "human", boolean(slot.human));
		put(state, player_slot, "computer", boolean(slot.computer));
		put(state, player_slot, "owner", text(state, slot.human ? "player" : "enemy"));
		put(state, player_slot, "faction_id", text(state, configured_runtime_faction_id(state, &slot, normalized)));
		append(state, player_slots, player_slot);
		if (slot.computer) {
			append(state, enemy_factions, text(state, configured_runtime_faction_id(state, &slot, normalized)));
		}
		if (slot.has_main_town) {
			const Value start = new_dict(state);
			put(state, start, "start_id", text(state, "player_start_" + compat::itos(slot.color + 1)));
			put(state, start, "owner", text(state, slot.human ? "player" : "enemy"));
			put(state, start, "owner_slot", integer(slot.color + 1));
			put(state, start, "player_slot", integer(slot.color + 1));
			put(state, start, "player_id", text(state, player_id));
			put(state, start, "team_id", text(state, team_id));
			put(state, start, "player_type", text(state, slot.human ? "human" : "computer"));
			put(state, start, "faction_id", text(state, configured_runtime_faction_id(state, &slot, normalized)));
			put(state, start, "town_id", text(state, configured_runtime_town_id(state, &slot, normalized)));
			put(state, start, "town_placement_id", text(state, runtime_town_placement_id(placement_seed_id, slot, projection)));
			put(state, start, "x", integer(slot.town_x));
			put(state, start, "y", integer(slot.town_y));
			put(state, start, "level", integer(slot.town_level));
			const Value runtime_start_tile = runtime_start_tile_for_slot(state, slot, projection);
			if (is_empty(state, runtime_start_tile)) {
				const Value result = blocked(state, "native_rmg_main_town_entrance_missing", "Native main-town coordinates do not resolve to a projected town entrance.");
				put(state, result, "player_slot", integer(slot.color + 1));
				put(state, result, "town_x", integer(slot.town_x));
				put(state, result, "town_y", integer(slot.town_y));
				put(state, result, "town_level", integer(slot.town_level));
				return result;
			}
			put(state, start, "hero_start_tile", runtime_start_tile);
			put(state, start, "runtime_start_tile", deep_copy(state, runtime_start_tile));
			append(state, player_starts, start);
			append(state, player_start_towns, deep_copy(state, start));
		}
	}

	const Value scenario_state = new_dict(state);
	put(state, scenario_state, "scenario_id", text(state, scenario_id));
	put(state, scenario_state, "scenario_hash", text(state, scenario_hash));
	put(state, scenario_state, "map_ref", map_ref_of(state, map_id_value, map_hash_value));
	const Value selection = new_dict(state);
	put(state, selection, "template_id", get(state, normalized, "template_id", text(state, "")));
	put(state, selection, "seed", text(state, seed_text));
	put(state, selection, "water_mode", text(state, water_mode));
	put(state, selection, "player_faction_id", text(state, player_faction_id));
	put(state, selection, "player_hero_id", text(state, player_hero_id));
	put(state, scenario_state, "selection", selection);
	put(state, scenario_state, "player_slots", player_slots);
	const Value objectives = new_dict(state);
	put(state, objectives, "kind", text(state, "defeat_generated_rivals"));
	put(state, objectives, "description", text(state, "Defeat every rival commander."));
	put(state, scenario_state, "objectives", objectives);
	put(state, scenario_state, "script_hooks", new_array(state));
	put(state, scenario_state, "enemy_factions", enemy_factions);
	const Value start_contract = new_dict(state);
	put(state, start_contract, "schema_id", text(state, "aurelion_native_rmg_start_contract_v1"));
	put(state, start_contract, "primary_hero_id", text(state, player_hero_id.empty() ? std::string("hero_lyra") : player_hero_id));
	put(state, start_contract, "player_faction_id", text(state, player_faction_id));
	put(state, start_contract, "player_starts", player_starts);
	put(state, start_contract, "player_start_towns", player_start_towns);
	put(state, start_contract, "start_count", integer(size_of(state, player_starts)));
	put(state, start_contract, "start_town_count", integer(size_of(state, player_start_towns)));
	put(state, scenario_state, "start_contract", start_contract);
	map_packages::ScenarioDocument *scenario_document = nullptr;
	const Value scenario_document_value = documents.new_scenario_document(scenario_document);
	map_packages::configure_scenario_document(state, *scenario_document, scenario_state);

	const auto validation_started_at = SteadyClock::now();
	const Value map_validation = map_document_report(state, *map_document);
	const Value scenario_validation = scenario_document_report(state, *scenario_document, map_document, map_validation);
	record_bucket("document_validation", validation_started_at);
	if (!bool_field(state, map_validation, "ok", false) || !bool_field(state, scenario_validation, "ok", false)) {
		const Value result = blocked(state, "native_rmg_runtime_document_validation_failed",
				"Native payload projection did not produce structurally valid runtime documents.");
		put(state, result, "map_validation", map_validation);
		put(state, result, "scenario_validation", scenario_validation);
		return result;
	}

	const Value result = new_dict(state);
	put(state, result, "ok", boolean(true));
	put(state, result, "status", text(state, "complete"));
	put(state, result, "generation_status", text(state, "native_rmg_complete"));
	put(state, result, "full_generation_status", text(state, "native_runtime_ready"));
	put(state, result, "normalized_config", deep_copy(state, normalized));
	put(state, result, "map_id", map_id_value);
	put(state, result, "map_hash", map_hash_value);
	put(state, result, "scenario_id", text(state, scenario_id));
	put(state, result, "scenario_hash", text(state, scenario_hash));
	put(state, result, "map_document", map_document_value);
	put(state, result, "scenario_document", scenario_document_value);
	put(state, result, "map_validation", map_validation);
	put(state, result, "scenario_validation", scenario_validation);
	if (include_performance_profile) {
		put(state, performance_profile, "total_ms", Value::of_float(elapsed_milliseconds(total_started_at)));
		put(state, result, "performance_profile", performance_profile);
	}
	put(state, result, "final_payload_byte_count", integer(core->final_payload_byte_count));
	put(state, result, "final_payload_fnv1a32", text(state, payload_token));
	// True when the workflow's result came from the generation before this one.
	put(state, result, "generator_core_reused", boolean(core_reused));
	put(state, result, "runtime_tile_count", integer(projection.tile_count));
	put(state, result, "runtime_object_count", integer(projection.object_count));
	put(state, result, "runtime_road_cell_count", integer(int32_t(projection.road_tiles.size())));
	put(state, result, "runtime_payload_projection_complete", boolean(true));
	put(state, result, "supported_parity_config", boolean(true));
	put(state, result, "runtime_generation_allowed", boolean(true));
	put(state, result, "native_runtime_authoritative", boolean(true));
	put(state, result, "public_runtime_authoritative", boolean(true));
	put(state, result, "package_session_adoption_ready", boolean(true));
	put(state, result, "full_parity_claim", boolean(true));
	return result;
}

Value convert_generated_payload(State &state, const Value &generated_map, const Value &options) {
	if (!bool_field(state, generated_map, "ok", false) || !bool_field(state, generated_map, "native_runtime_authoritative", false)
			|| !bool_field(state, generated_map, "runtime_payload_projection_complete", false)) {
		return native_conversion_fail(state, "native_rmg_generated_payload_not_authoritative",
				"Package/session adoption requires a structurally validated native-owned final payload.");
	}
	const Value map_value = get(state, generated_map, "map_document");
	const Value scenario_value = get(state, generated_map, "scenario_document");
	if (map_value.kind != Kind::Opaque || scenario_value.kind != Kind::Opaque) {
		return native_conversion_fail(state, "native_rmg_generated_documents_missing",
				"Package/session adoption requires generated MapDocument and ScenarioDocument objects.");
	}
	const Value report = new_dict(state);
	put(state, report, "schema_id", text(state, "aurelion_native_random_map_package_session_adoption_report_v1"));
	put(state, report, "schema_version", integer(1));
	put(state, report, "status", text(state, "pass"));
	put(state, report, "failure_count", integer(0));
	put(state, report, "warning_count", integer(0));
	put(state, report, "failures", new_array(state));
	put(state, report, "warnings", new_array(state));
	put(state, report, "package_session_adoption_ready", boolean(true));
	put(state, report, "native_runtime_authoritative", boolean(true));
	put(state, report, "runtime_call_site_adoption", boolean(true));
	put(state, report, "full_parity_claim", boolean(bool_field(state, generated_map, "full_parity_claim", false)));
	put(state, report, "adoption_status", text(state, "runtime_authoritative_source_parity_complete"));

	const Value map_id = text(state, string_field(state, generated_map, "map_id"));
	const Value map_hash = text(state, string_field(state, generated_map, "map_hash"));
	const Value scenario_id = text(state, string_field(state, generated_map, "scenario_id"));
	const Value scenario_hash = text(state, string_field(state, generated_map, "scenario_hash"));
	const Value map_ref = map_ref_of(state, map_id, map_hash);
	const Value scenario_ref = new_dict(state);
	put(state, scenario_ref, "schema_id", text(state, kScenarioSchemaId));
	put(state, scenario_ref, "schema_version", integer(kSchemaVersion));
	put(state, scenario_ref, "scenario_id", scenario_id);
	put(state, scenario_ref, "scenario_hash", scenario_hash);
	put(state, scenario_ref, "map_ref", map_ref);

	const std::string feature_gate = string_field(state, options, "feature_gate", "native_rmg_runtime");
	const int32_t save_version = int32_field(state, options, "session_save_version", 0);
	const Value normalized_config = dict_or_new(state, get(state, generated_map, "normalized_config"));
	const Value player_setup = dict_or_new(state, get(state, normalized_config, "player_setup"));
	const std::string player_hero_id = strip(string_field(state, player_setup, "hero_id", "hero_lyra"));
	const Value boundary = new_dict(state);
	put(state, boundary, "schema_id", text(state, "aurelion_native_rmg_package_session_boundary_v1"));
	put(state, boundary, "session_id", text(state, "native_rmg_session_" + state.text(map_id.ref)));
	put(state, boundary, "scenario_id", scenario_id);
	put(state, boundary, "map_id", map_id);
	put(state, boundary, "hero_id", text(state, player_hero_id.empty() ? std::string("hero_lyra") : player_hero_id));
	put(state, boundary, "player_faction_id", text(state, string_field(state, player_setup, "faction_id")));
	put(state, boundary, "player_setup", deep_copy(state, player_setup));
	put(state, boundary, "feature_gate", text(state, feature_gate));
	put(state, boundary, "save_version", integer(save_version));
	put(state, boundary, "save_version_bump", boolean(false));
	put(state, boundary, "authored_content_writeback", boolean(false));
	put(state, boundary, "campaign_adoption", boolean(false));
	put(state, boundary, "runtime_call_site_adoption", boolean(true));
	put(state, boundary, "native_runtime_authoritative", boolean(true));
	put(state, boundary, "full_parity_claim", boolean(bool_field(state, generated_map, "full_parity_claim", false)));
	put(state, boundary, "map_package_ref", map_ref);
	put(state, boundary, "scenario_package_ref", scenario_ref);

	const Value generated_identity = new_dict(state);
	put(state, generated_identity, "map_id", map_id);
	put(state, generated_identity, "map_hash", map_hash);
	put(state, generated_identity, "scenario_id", scenario_id);
	put(state, generated_identity, "scenario_hash", scenario_hash);
	put(state, generated_identity, "normalized_config", get(state, generated_map, "normalized_config", new_dict(state)));
	const Value result = new_dict(state);
	put(state, result, "ok", boolean(true));
	put(state, result, "status", text(state, "complete"));
	put(state, result, "adoption_status", text(state, "ready"));
	put(state, result, "package_session_adoption_ready", boolean(true));
	put(state, result, "native_runtime_authoritative", boolean(true));
	put(state, result, "map_document", map_value);
	put(state, result, "scenario_document", scenario_value);
	put(state, result, "map_ref", map_ref);
	put(state, result, "scenario_ref", scenario_ref);
	put(state, result, "session_boundary_record", boundary);
	put(state, result, "generated_identity", generated_identity);
	put(state, result, "validation_report", report);
	put(state, result, "report", report);
	return result;
}

namespace {

// write_package_dictionary: the package's JSON written to path, what the host
// keeps beside it, then the result.
Value write_package(State &state, content::Files &files, Documents &documents, const char *operation, const std::string &path, const Value &package,
		const Value &options) {
	const std::string json = compat::JsonWriter{ state, "\t", true, false }.text(package);
	if (const char *code = documents.write_package(files, path, json)) {
		return map_packages::package_failure(state, operation, path, code, write_failure_message(code));
	}
	const Value profile = documents.package_written(state, path, package, bool_field(state, options, "include_browser_manifest_cache_profile", false));
	const Value payload = new_dict(state);
	if (bool_field(state, options, "return_package", true)) {
		// A copy: the package holds the document's own containers.
		put(state, payload, "package", deep_copy(state, package));
	}
	put(state, payload, "package_hash", get(state, package, "package_hash", text(state, "")));
	if (profile.kind != Kind::Nil) {
		put(state, payload, "browser_manifest_cache_profile", profile);
	}
	return map_packages::package_success(state, operation, path, payload);
}

Value package_hash_of(State &state, const Value &package) {
	return text(state, document_hash(state, package));
}

} // namespace

Value save_map_package(State &state, content::Files &files, Documents &documents, const Value &map_document, const std::string &path, const Value &options) {
	const char *operation = "save_map_package";
	map_packages::MapDocument *document = documents.map_document(map_document);
	if (document == nullptr) {
		return map_packages::package_failure(state, operation, path, "missing_map_document", "Map package save requires a MapDocument.");
	}
	// map_document_payload: the stored containers, uncopied, but for the
	// metadata's schema keys.
	const Value payload = new_dict(state);
	put(state, payload, "schema_id", text(state, kMapSchemaId));
	put(state, payload, "schema_version", integer(kSchemaVersion));
	put(state, payload, "map_id", document->map_id);
	put(state, payload, "map_hash", document->map_hash);
	put(state, payload, "source_kind", document->source_kind);
	put(state, payload, "width", integer(document->width));
	put(state, payload, "height", integer(document->height));
	put(state, payload, "level_count", integer(document->level_count));
	const Value metadata = shallow_copy(state, document->metadata);
	put(state, metadata, "schema_id", text(state, kMapSchemaId));
	put(state, metadata, "schema_version", integer(kSchemaVersion));
	put(state, payload, "metadata", metadata);
	put(state, payload, "terrain_layers", document->terrain_layers);
	put(state, payload, "route_graph", document->route_graph);
	put(state, payload, "objects", document->objects);

	const std::string package_id = get_file(path);
	const Value map_ref = new_dict(state);
	put(state, map_ref, "schema_id", text(state, kMapSchemaId));
	put(state, map_ref, "schema_version", integer(kSchemaVersion));
	put(state, map_ref, "map_id", document->map_id);
	put(state, map_ref, "map_hash", document->map_hash);
	put(state, map_ref, "source_kind", document->source_kind);
	put(state, map_ref, "package_path", text(state, path));
	put(state, map_ref, "package_id", text(state, package_id));
	put(state, map_ref, "storage_policy", text(state, "project_maps_generated_package"));

	const Value package = new_dict(state);
	put(state, package, "schema_id", text(state, kMapPackageSchemaId));
	put(state, package, "schema_version", integer(1));
	put(state, package, "package_kind", text(state, "generated_map_package"));
	put(state, package, "package_id", text(state, package_id));
	put(state, package, "document_kind", text(state, "map"));
	put(state, package, "map_id", document->map_id);
	put(state, package, "map_hash", document->map_hash);
	put(state, package, "map_ref", map_ref);
	put(state, package, "source_kind", document->source_kind);
	put(state, package, "storage_policy", text(state, "project_maps_generated_package"));
	put(state, package, "path_policy", text(state, string_field(state, options, "path_policy", "dev_res_maps_export_user_maps")));
	put(state, package, "authored_content_writeback", boolean(false));
	put(state, package, "legacy_json_scenario_record", boolean(false));
	put(state, package, "document", payload);
	put(state, package, "package_hash", package_hash_of(state, package));
	const Value final_map_ref = deep_copy(state, map_ref);
	put(state, final_map_ref, "package_hash", get(state, package, "package_hash", text(state, "")));
	put(state, package, "map_ref", final_map_ref);
	return write_package(state, files, documents, operation, path, package, options);
}

Value save_scenario_package(State &state, content::Files &files, Documents &documents, const Value &scenario_document, const std::string &path,
		const Value &options) {
	const char *operation = "save_scenario_package";
	map_packages::ScenarioDocument *document = documents.scenario_document(scenario_document);
	if (document == nullptr) {
		return map_packages::package_failure(state, operation, path, "missing_scenario_document", "Scenario package save requires a ScenarioDocument.");
	}
	// scenario_document_payload: the getters' copies, which nothing here
	// changes, so the stored containers themselves.
	const Value payload = new_dict(state);
	put(state, payload, "schema_id", text(state, kScenarioSchemaId));
	put(state, payload, "schema_version", integer(kSchemaVersion));
	put(state, payload, "scenario_id", document->scenario_id);
	put(state, payload, "scenario_hash", document->scenario_hash);
	put(state, payload, "map_ref", document->map_ref);
	put(state, payload, "selection", document->selection);
	put(state, payload, "player_slots", document->player_slots);
	put(state, payload, "objectives", document->objectives);
	put(state, payload, "script_hooks", document->script_hooks);
	put(state, payload, "enemy_factions", document->enemy_factions);
	put(state, payload, "start_contract", document->start_contract);

	const std::string package_id = get_file(path);
	const Value scenario_ref = new_dict(state);
	put(state, scenario_ref, "schema_id", text(state, kScenarioSchemaId));
	put(state, scenario_ref, "schema_version", integer(kSchemaVersion));
	put(state, scenario_ref, "scenario_id", document->scenario_id);
	put(state, scenario_ref, "scenario_hash", document->scenario_hash);
	put(state, scenario_ref, "map_ref", document->map_ref);
	put(state, scenario_ref, "package_path", text(state, path));
	put(state, scenario_ref, "package_id", text(state, package_id));
	put(state, scenario_ref, "storage_policy", text(state, "project_maps_generated_package"));

	const Value package = new_dict(state);
	put(state, package, "schema_id", text(state, kScenarioPackageSchemaId));
	put(state, package, "schema_version", integer(1));
	put(state, package, "package_kind", text(state, "generated_scenario_package"));
	put(state, package, "package_id", text(state, package_id));
	put(state, package, "document_kind", text(state, "scenario"));
	put(state, package, "scenario_id", document->scenario_id);
	put(state, package, "scenario_hash", document->scenario_hash);
	put(state, package, "scenario_ref", scenario_ref);
	put(state, package, "map_ref", document->map_ref);
	put(state, package, "source_kind", text(state, "generated"));
	put(state, package, "storage_policy", text(state, "project_maps_generated_package"));
	put(state, package, "path_policy", text(state, string_field(state, options, "path_policy", "dev_res_maps_export_user_maps")));
	put(state, package, "authored_content_writeback", boolean(false));
	put(state, package, "legacy_json_scenario_record", boolean(false));
	put(state, package, "document", payload);
	put(state, package, "package_hash", package_hash_of(state, package));
	const Value final_scenario_ref = deep_copy(state, scenario_ref);
	put(state, final_scenario_ref, "package_hash", get(state, package, "package_hash", text(state, "")));
	put(state, package, "scenario_ref", final_scenario_ref);
	return write_package(state, files, documents, operation, path, package, options);
}

} // namespace aurelion::rules::map_generation
