#include "map_package_service.hpp"

#include <godot_cpp/core/class_db.hpp>
#include <godot_cpp/variant/array.hpp>
#include <godot_cpp/variant/packed_int32_array.hpp>

#include <algorithm>
#include <cmath>
#include <cstdint>
#include <limits>
#include <map>
#include <vector>

using namespace godot;

namespace {

constexpr const char *API_ID = "aurelion_map_package_api";
constexpr const char *API_VERSION = "0.1.0";
constexpr const char *MAP_SCHEMA_ID = "aurelion_map_document";
constexpr const char *SCENARIO_SCHEMA_ID = "aurelion_scenario_document";
constexpr const char *NATIVE_RMG_SCHEMA_ID = "aurelion_native_random_map_foundation";
constexpr const char *NATIVE_RMG_VERSION = "native_rmg_foundation_v1";
constexpr const char *NATIVE_RMG_TERRAIN_GRID_SCHEMA_ID = "aurelion_native_rmg_terrain_grid_v1";
constexpr const char *NATIVE_RMG_ZONE_LAYOUT_SCHEMA_ID = "aurelion_native_rmg_zone_layout_v1";
constexpr const char *NATIVE_RMG_PLAYER_STARTS_SCHEMA_ID = "aurelion_native_rmg_player_starts_v1";
constexpr const char *NATIVE_RMG_ROUTE_GRAPH_SCHEMA_ID = "aurelion_native_rmg_route_graph_v1";
constexpr const char *NATIVE_RMG_ROAD_NETWORK_SCHEMA_ID = "aurelion_native_rmg_road_network_v1";
constexpr const char *NATIVE_RMG_RIVER_NETWORK_SCHEMA_ID = "aurelion_native_rmg_river_network_v1";
constexpr uint64_t HASH_MODULUS = 4294967296ULL;
constexpr double TAU = 6.28318530717958647692;

PackedStringArray capabilities() {
	PackedStringArray result;
	result.append("api_metadata");
	result.append("typed_map_document_stub");
	result.append("typed_scenario_document_stub");
	result.append("stable_not_implemented_errors");
	result.append("native_random_map_config_identity");
	result.append("native_random_map_foundation_stub");
	result.append("native_random_map_terrain_grid_foundation");
	result.append("native_random_map_zone_player_starts_foundation");
	result.append("native_random_map_road_river_network_foundation");
	result.append("headless_binding_smoke");
	return result;
}

String escaped_atom(const String &value) {
	String escaped = value;
	escaped = escaped.replace("\\", "\\\\");
	escaped = escaped.replace("|", "\\|");
	escaped = escaped.replace("[", "\\[");
	escaped = escaped.replace("]", "\\]");
	escaped = escaped.replace("{", "\\{");
	escaped = escaped.replace("}", "\\}");
	escaped = escaped.replace(":", "\\:");
	escaped = escaped.replace(",", "\\,");
	return escaped;
}

String canonical_variant(const Variant &value) {
	switch (value.get_type()) {
		case Variant::NIL:
			return "null";
		case Variant::BOOL:
			return bool(value) ? "bool:true" : "bool:false";
		case Variant::INT:
			return "int:" + String::num_int64(int64_t(value));
		case Variant::FLOAT:
			return "float:" + String::num_real(double(value));
		case Variant::STRING:
		case Variant::STRING_NAME:
			return "string:" + escaped_atom(String(value));
		case Variant::DICTIONARY: {
			Dictionary dictionary = value;
			Array keys = dictionary.keys();
			std::vector<String> sorted_keys;
			sorted_keys.reserve(keys.size());
			for (int64_t index = 0; index < keys.size(); ++index) {
				sorted_keys.push_back(String(keys[index]));
			}
			std::sort(sorted_keys.begin(), sorted_keys.end(), [](const String &left, const String &right) {
				return left < right;
			});

			String result = "{";
			for (size_t index = 0; index < sorted_keys.size(); ++index) {
				if (index > 0) {
					result += ",";
				}
				const String &key = sorted_keys[index];
				result += escaped_atom(key) + ":" + canonical_variant(dictionary[key]);
			}
			result += "}";
			return result;
		}
		case Variant::ARRAY: {
			Array array = value;
			String result = "[";
			for (int64_t index = 0; index < array.size(); ++index) {
				if (index > 0) {
					result += ",";
				}
				result += canonical_variant(array[index]);
			}
			result += "]";
			return result;
		}
		default:
			return String("variant:") + escaped_atom(String(value));
	}
}

uint32_t hash32_int(const String &text) {
	uint64_t value = 2166136261ULL;
	for (int64_t index = 0; index < text.length(); ++index) {
		value = (value ^ uint64_t(text.unicode_at(index))) % HASH_MODULUS;
		value = (value * 16777619ULL) % HASH_MODULUS;
	}
	return uint32_t(value);
}

String hash32_hex(const String &text) {
	static constexpr const char *HEX_DIGITS = "0123456789abcdef";
	uint32_t value = hash32_int(text);
	String result;
	for (int index = 7; index >= 0; --index) {
		const uint32_t nibble = (value >> (index * 4)) & 0xFU;
		result += String::chr(HEX_DIGITS[nibble]);
	}
	return result;
}

String normalized_text(const Dictionary &dictionary, const String &key, const String &fallback = "") {
	String value = String(dictionary.get(key, fallback)).strip_edges();
	if (value.is_empty()) {
		return fallback;
	}
	return value;
}

int32_t normalized_int(const Dictionary &dictionary, const String &key, int32_t fallback) {
	if (!dictionary.has(key)) {
		return fallback;
	}
	return int32_t(dictionary.get(key, fallback));
}

int32_t clamp_dimension(int32_t value, int32_t fallback) {
	if (value <= 0) {
		return fallback;
	}
	return std::max(8, std::min(144, value));
}

int32_t nested_size_int(const Dictionary &root, const Dictionary &size, const String &key, const String &alternate_key, int32_t fallback) {
	int32_t value = normalized_int(size, key, 0);
	if (value <= 0 && !alternate_key.is_empty()) {
		value = normalized_int(size, alternate_key, 0);
	}
	if (value <= 0) {
		value = normalized_int(root, key, fallback);
	}
	return clamp_dimension(value, fallback);
}

Dictionary not_implemented(const String &operation, const String &path = "", const Dictionary &options = Dictionary()) {
	Dictionary failure;
	failure["code"] = "not_implemented";
	failure["severity"] = "fail";
	failure["path"] = operation;
	failure["message"] = "Package conversion/read/write is intentionally unavailable in Slice 1.";
	Dictionary context;
	context["options_keys"] = options.keys();
	failure["context"] = context;

	Array failures;
	failures.append(failure);

	Dictionary report;
	report["schema_id"] = "aurelion_package_operation_report";
	report["schema_version"] = 1;
	report["status"] = "fail";
	report["failures"] = failures;
	report["warnings"] = Array();

	Dictionary result;
	result["ok"] = false;
	result["status"] = "fail";
	result["error_code"] = "not_implemented";
	result["message"] = operation + String(" is not implemented in the Slice 1 native package API skeleton.");
	result["operation"] = operation;
	result["path"] = path;
	result["report"] = report;
	result["recoverable"] = true;
	return result;
}

Array default_terrain_pool() {
	Array result;
	result.append("grass");
	result.append("snow");
	result.append("sand");
	result.append("dirt");
	result.append("rough");
	result.append("lava");
	result.append("underground");
	return result;
}

Array default_faction_pool() {
	Array result;
	result.append("faction_embercourt");
	result.append("faction_mireclaw");
	result.append("faction_sunvault");
	result.append("faction_thornwake");
	return result;
}

String town_for_faction(const String &faction_id) {
	if (faction_id == "faction_mireclaw") {
		return "town_mirewatch";
	}
	if (faction_id == "faction_sunvault") {
		return "town_sunspire";
	}
	if (faction_id == "faction_thornwake") {
		return "town_thornhold";
	}
	return "town_riverwatch";
}

bool array_has_string(const Array &array, const String &needle) {
	for (int64_t index = 0; index < array.size(); ++index) {
		if (String(array[index]) == needle) {
			return true;
		}
	}
	return false;
}

Array normalized_string_array(const Variant &value, const Array &fallback) {
	Array result;
	if (value.get_type() == Variant::ARRAY) {
		Array source = value;
		for (int64_t index = 0; index < source.size(); ++index) {
			String text = String(source[index]).strip_edges();
			if (!text.is_empty() && !array_has_string(result, text)) {
				result.append(text);
			}
		}
	}
	if (result.is_empty()) {
		return fallback.duplicate();
	}
	return result;
}

Array ensure_repeated_to_count(const Array &source, const Array &fallback, int32_t count) {
	Array base = source.is_empty() ? fallback.duplicate() : source.duplicate();
	Array result;
	if (base.is_empty()) {
		return result;
	}
	for (int32_t index = 0; index < count; ++index) {
		result.append(base[index % base.size()]);
	}
	return result;
}

bool is_supported_terrain_id(const String &terrain_id) {
	return terrain_id == "grass" || terrain_id == "snow" || terrain_id == "sand" || terrain_id == "dirt" || terrain_id == "rough" || terrain_id == "lava" || terrain_id == "underground" || terrain_id == "water";
}

bool is_passable_terrain_id(const String &terrain_id) {
	return is_supported_terrain_id(terrain_id) && terrain_id != "water";
}

String biome_for_terrain(const String &terrain_id) {
	if (terrain_id == "snow") {
		return "biome_snow_frost_marches";
	}
	if (terrain_id == "sand" || terrain_id == "dirt") {
		return "biome_rough_badlands";
	}
	if (terrain_id == "rough") {
		return "biome_highland_ridge";
	}
	if (terrain_id == "lava") {
		return "biome_ash_lava_wastes";
	}
	if (terrain_id == "underground") {
		return "biome_subterranean_underways";
	}
	if (terrain_id == "water") {
		return "biome_coast_archipelago";
	}
	return "biome_grasslands";
}

String terrain_for_faction(const String &faction_id) {
	if (faction_id == "faction_mireclaw") {
		return "dirt";
	}
	if (faction_id == "faction_thornwake" || faction_id == "faction_brasshollow") {
		return "rough";
	}
	if (faction_id == "faction_veilmourn") {
		return "water";
	}
	return "grass";
}

Array normalized_terrain_pool(const Array &requested) {
	Array result;
	for (int64_t index = 0; index < requested.size(); ++index) {
		String terrain_id = String(requested[index]);
		if (is_passable_terrain_id(terrain_id) && !array_has_string(result, terrain_id)) {
			result.append(terrain_id);
		}
	}
	if (result.is_empty()) {
		return default_terrain_pool();
	}
	return result;
}

int32_t terrain_code_for_id(const String &terrain_id) {
	if (terrain_id == "grass") {
		return 0;
	}
	if (terrain_id == "snow") {
		return 1;
	}
	if (terrain_id == "sand") {
		return 2;
	}
	if (terrain_id == "dirt") {
		return 3;
	}
	if (terrain_id == "rough") {
		return 4;
	}
	if (terrain_id == "lava") {
		return 5;
	}
	if (terrain_id == "underground") {
		return 6;
	}
	return 7;
}

PackedStringArray terrain_id_by_code() {
	PackedStringArray result;
	result.append("grass");
	result.append("snow");
	result.append("sand");
	result.append("dirt");
	result.append("rough");
	result.append("lava");
	result.append("underground");
	result.append("water");
	return result;
}

Array terrain_seed_records(const Dictionary &normalized, const Array &terrain_pool) {
	Array seeds;
	const int32_t width = int32_t(normalized.get("width", 36));
	const int32_t height = int32_t(normalized.get("height", 36));
	const String seed = String(normalized.get("normalized_seed", "0"));
	const int32_t inner_width = std::max(1, width - 2);
	const int32_t inner_height = std::max(1, height - 2);
	for (int64_t index = 0; index < terrain_pool.size(); ++index) {
		const String terrain_id = String(terrain_pool[index]);
		const String seed_key = seed + String(":terrain_seed:") + terrain_id + String(":") + String::num_int64(index);
		Dictionary record;
		record["terrain_id"] = terrain_id;
		record["biome_id"] = biome_for_terrain(terrain_id);
		record["x"] = 1 + int32_t(hash32_int(seed_key + String(":x")) % uint32_t(inner_width));
		record["y"] = 1 + int32_t(hash32_int(seed_key + String(":y")) % uint32_t(inner_height));
		record["selection_source"] = "profile_palette_deterministic_seed";
		seeds.append(record);
	}
	return seeds;
}

String choose_terrain_for_cell(int32_t x, int32_t y, int32_t level, const Array &terrain_pool, const Array &seeds, const Dictionary &normalized) {
	const int32_t width = int32_t(normalized.get("width", 36));
	const int32_t height = int32_t(normalized.get("height", 36));
	const String water_mode = String(normalized.get("water_mode", "land"));
	if (level == 0 && water_mode == "islands" && (x == 0 || y == 0 || x == width - 1 || y == height - 1)) {
		return "water";
	}
	if (level > 0 && array_has_string(terrain_pool, "underground")) {
		return "underground";
	}
	String best_terrain = String(terrain_pool[0]);
	int64_t best_score = std::numeric_limits<int64_t>::max();
	const String seed = String(normalized.get("normalized_seed", "0"));
	for (int64_t index = 0; index < seeds.size(); ++index) {
		Dictionary record = seeds[index];
		const int64_t dx = int64_t(x) - int64_t(record.get("x", 0));
		const int64_t dy = int64_t(y) - int64_t(record.get("y", 0));
		const String jitter_key = seed + String(":terrain_cell:") + String::num_int64(level) + String(":") + String::num_int64(x) + String(":") + String::num_int64(y) + String(":") + String(record.get("terrain_id", ""));
		const uint32_t jitter = hash32_int(jitter_key);
		const int64_t score = dx * dx * 100 + dy * dy * 126 - int64_t(jitter % 97U);
		if (score < best_score) {
			best_score = score;
			best_terrain = String(record.get("terrain_id", best_terrain));
		}
	}
	return best_terrain;
}

String point_key(int32_t x, int32_t y) {
	return String::num_int64(x) + String(",") + String::num_int64(y);
}

Dictionary point_record(int32_t x, int32_t y) {
	Dictionary point;
	point["x"] = x;
	point["y"] = y;
	return point;
}

Dictionary cell_record(int32_t x, int32_t y, int32_t level) {
	Dictionary point;
	point["x"] = x;
	point["y"] = y;
	point["level"] = level;
	return point;
}

String slot_id_2(int32_t slot) {
	return slot < 10 ? "0" + String::num_int64(slot) : String::num_int64(slot);
}

int32_t deterministic_signed_jitter(const String &seed_key, int32_t amplitude) {
	if (amplitude <= 0) {
		return 0;
	}
	const int32_t span = amplitude * 2 + 1;
	return int32_t(hash32_int(seed_key) % uint32_t(span)) - amplitude;
}

Dictionary normalized_player_constraints(const Dictionary &config) {
	Variant constraints_value = config.get("player_constraints", config.get("players", Variant()));
	Dictionary constraints = constraints_value.get_type() == Variant::DICTIONARY ? Dictionary(constraints_value) : Dictionary();
	int32_t human_count = std::max(1, std::min(8, normalized_int(constraints, "human_count", normalized_int(constraints, "humans", 1))));
	int32_t computer_count = 1;
	int32_t player_count = 2;
	if (constraints.has("player_count") || constraints.has("total_count") || constraints.has("total")) {
		player_count = std::max(1, std::min(8, normalized_int(constraints, "player_count", normalized_int(constraints, "total_count", normalized_int(constraints, "total", player_count)))));
		player_count = std::max(player_count, human_count);
		computer_count = std::max(0, player_count - human_count);
	} else {
		computer_count = std::max(0, std::min(7, normalized_int(constraints, "computer_count", normalized_int(constraints, "computers", computer_count))));
		player_count = std::max(1, std::min(8, human_count + computer_count));
	}
	String team_mode = normalized_text(constraints, "team_mode", "free_for_all").to_lower();
	if (team_mode.is_empty()) {
		team_mode = "free_for_all";
	}

	Dictionary result;
	result["human_count"] = human_count;
	result["computer_count"] = computer_count;
	result["player_count"] = player_count;
	result["team_mode"] = team_mode;
	return result;
}

Array town_ids_for_factions(const Variant &value, const Array &faction_ids, int32_t player_count) {
	Array requested;
	if (value.get_type() == Variant::ARRAY) {
		requested = normalized_string_array(value, Array());
	}
	Array result;
	for (int32_t index = 0; index < player_count; ++index) {
		if (!requested.is_empty()) {
			result.append(requested[index % requested.size()]);
		} else if (!faction_ids.is_empty()) {
			result.append(town_for_faction(String(faction_ids[index % faction_ids.size()])));
		} else {
			result.append("town_riverwatch");
		}
	}
	return result;
}

Dictionary player_assignment_for_config(const Dictionary &normalized) {
	Dictionary constraints = normalized.get("player_constraints", Dictionary());
	const int32_t player_count = int32_t(constraints.get("player_count", 2));
	const int32_t human_count = int32_t(constraints.get("human_count", 1));
	const int32_t computer_count = int32_t(constraints.get("computer_count", std::max(0, player_count - human_count)));
	const String team_mode = String(constraints.get("team_mode", "free_for_all"));
	Array faction_ids = normalized.get("faction_ids", default_faction_pool());
	Array town_ids = normalized.get("town_ids", Array());

	Array player_slots;
	Dictionary by_owner_slot;
	Array active_owner_slots;
	Array assigned_faction_ids;
	Array assigned_town_ids;
	Array teams;
	for (int32_t index = 0; index < player_count; ++index) {
		const int32_t player_slot = index + 1;
		const int32_t owner_slot = index + 1;
		const String player_type = player_slot <= human_count ? "human" : "computer";
		const String faction_id = faction_ids.is_empty() ? String("faction_embercourt") : String(faction_ids[index % faction_ids.size()]);
		const String town_id = town_ids.is_empty() ? town_for_faction(faction_id) : String(town_ids[index % town_ids.size()]);
		const String team_id = "team_" + slot_id_2(player_slot);

		Dictionary slot;
		slot["player_slot"] = player_slot;
		slot["owner_slot"] = owner_slot;
		slot["player_type"] = player_type;
		slot["faction_id"] = faction_id;
		slot["town_id"] = town_id;
		slot["team_id"] = team_id;
		slot["team_mode"] = team_mode;
		slot["ai_controlled"] = player_type != "human";
		slot["assignment_source"] = "native_foundation_fixed_owner_slot_profile_order";
		player_slots.append(slot);
		by_owner_slot[String::num_int64(owner_slot)] = slot;
		active_owner_slots.append(owner_slot);
		assigned_faction_ids.append(faction_id);
		assigned_town_ids.append(town_id);

		Dictionary team;
		team["team_id"] = team_id;
		Array team_slots;
		team_slots.append(player_slot);
		team["player_slots"] = team_slots;
		team["mode"] = "free_for_all";
		teams.append(team);
	}

	Dictionary capacity;
	capacity["human_start_capacity"] = std::max(1, human_count);
	capacity["total_start_capacity"] = player_count;
	capacity["fixed_owner_slots"] = active_owner_slots;
	Array human_owner_slots;
	for (int32_t index = 0; index < human_count; ++index) {
		human_owner_slots.append(index + 1);
	}
	capacity["human_owner_slots"] = human_owner_slots;

	Dictionary team_metadata;
	team_metadata["mode"] = "free_for_all";
	team_metadata["supported_now"] = team_mode == "free_for_all";
	team_metadata["requested_mode"] = team_mode;
	team_metadata["teams"] = teams;

	Dictionary assignment;
	assignment["schema_id"] = "random_map_player_assignment_v1";
	assignment["assignment_policy"] = "native_foundation_fixed_owner_slots_first_n_players_profile_order";
	assignment["team_mode"] = team_mode;
	assignment["team_metadata"] = team_metadata;
	assignment["human_count"] = human_count;
	assignment["computer_count"] = computer_count;
	assignment["player_count"] = player_count;
	assignment["capacity"] = capacity;
	assignment["active_owner_slots"] = active_owner_slots;
	assignment["inactive_owner_slots"] = Array();
	assignment["player_slots"] = player_slots;
	assignment["player_slot_by_owner_slot"] = by_owner_slot;
	assignment["assigned_faction_ids"] = assigned_faction_ids;
	assignment["assigned_town_ids"] = assigned_town_ids;
	assignment["faction_pool"] = faction_ids;
	return assignment;
}

Dictionary terrain_palette_for_zone(const String &zone_id, const String &faction_id, bool match_to_faction, const Array &terrain_pool, int32_t index) {
	String selected = terrain_pool.is_empty() ? String("grass") : String(terrain_pool[index % terrain_pool.size()]);
	String source = "profile_palette_foundation_order";
	const String faction_terrain = terrain_for_faction(faction_id);
	if (match_to_faction && array_has_string(terrain_pool, faction_terrain)) {
		selected = faction_terrain;
		source = "faction_match_profile_palette";
	}
	Dictionary palette;
	palette["zone_id"] = zone_id;
	palette["faction_id"] = faction_id;
	palette["terrain_match_to_faction"] = match_to_faction;
	palette["profile_terrain_ids"] = terrain_pool;
	palette["catalog_allowed_terrain_ids"] = Array();
	palette["faction_terrain_id"] = faction_terrain;
	palette["selected_terrain_id"] = selected;
	palette["normalized_terrain_id"] = selected;
	palette["original_terrain_id"] = selected;
	palette["biome_id"] = biome_for_terrain(selected);
	palette["passable"] = is_passable_terrain_id(selected);
	palette["selection_source"] = source;
	palette["fallback_used"] = false;
	palette["unsupported_terrain_ids"] = Array();
	palette["deferred_terrain_ids"] = Array();
	palette["deferred_reason"] = "";
	return palette;
}

Array build_foundation_zones(const Dictionary &normalized, const Dictionary &player_assignment) {
	Dictionary constraints = normalized.get("player_constraints", Dictionary());
	const int32_t player_count = int32_t(constraints.get("player_count", 2));
	Array terrain_pool = normalized_terrain_pool(normalized.get("terrain_ids", default_terrain_pool()));
	Dictionary by_owner_slot = player_assignment.get("player_slot_by_owner_slot", Dictionary());
	Array zones;
	for (int32_t index = 0; index < player_count; ++index) {
		const int32_t owner_slot = index + 1;
		Dictionary assignment = by_owner_slot.get(String::num_int64(owner_slot), Dictionary());
		const String zone_id = "start_" + String::num_int64(owner_slot);
		const String faction_id = String(assignment.get("faction_id", ""));
		Dictionary palette = terrain_palette_for_zone(zone_id, faction_id, true, terrain_pool, index);
		Dictionary zone;
		zone["id"] = zone_id;
		zone["source_id"] = zone_id;
		zone["role"] = owner_slot == 1 ? "human_start" : "computer_start";
		zone["owner_slot"] = owner_slot;
		zone["player_slot"] = assignment.get("player_slot", owner_slot);
		zone["player_type"] = assignment.get("player_type", owner_slot == 1 ? String("human") : String("computer"));
		zone["team_id"] = assignment.get("team_id", "team_" + slot_id_2(owner_slot));
		zone["faction_id"] = faction_id;
		zone["terrain_id"] = palette.get("normalized_terrain_id", "grass");
		zone["terrain_palette"] = palette;
		zone["base_size"] = 18;
		zone["anchor"] = Dictionary();
		zone["bounds"] = Dictionary();
		zone["cell_count"] = 0;
		Dictionary catalog_metadata;
		catalog_metadata["start_contract"] = "primary_town_anchor_deferred_to_later_native_slice";
		catalog_metadata["native_foundation_source"] = "fallback_runtime_template";
		zone["catalog_metadata"] = catalog_metadata;
		zones.append(zone);
	}

	Dictionary junction_palette = terrain_palette_for_zone("junction_1", "", false, terrain_pool, player_count);
	Dictionary junction;
	junction["id"] = "junction_1";
	junction["source_id"] = "junction_1";
	junction["role"] = "junction";
	junction["owner_slot"] = Variant();
	junction["player_slot"] = Variant();
	junction["player_type"] = "neutral";
	junction["team_id"] = "";
	junction["faction_id"] = "";
	junction["terrain_id"] = junction_palette.get("normalized_terrain_id", "grass");
	junction["terrain_palette"] = junction_palette;
	junction["base_size"] = 10;
	junction["anchor"] = Dictionary();
	junction["bounds"] = Dictionary();
	junction["cell_count"] = 0;
	junction["catalog_metadata"] = Dictionary();
	zones.append(junction);

	const int32_t reward_count = std::max(2, player_count);
	for (int32_t index = 0; index < reward_count; ++index) {
		const String zone_id = "reward_" + String::num_int64(index + 1);
		Dictionary palette = terrain_palette_for_zone(zone_id, "", false, terrain_pool, player_count + index + 1);
		Dictionary reward;
		reward["id"] = zone_id;
		reward["source_id"] = zone_id;
		reward["role"] = "treasure";
		reward["owner_slot"] = Variant();
		reward["player_slot"] = Variant();
		reward["player_type"] = "neutral";
		reward["team_id"] = "";
		reward["faction_id"] = "";
		reward["terrain_id"] = palette.get("normalized_terrain_id", "grass");
		reward["terrain_palette"] = palette;
		reward["base_size"] = 8;
		reward["anchor"] = Dictionary();
		reward["bounds"] = Dictionary();
		reward["cell_count"] = 0;
		reward["catalog_metadata"] = Dictionary();
		zones.append(reward);
	}
	return zones;
}

Dictionary resolve_seed_collisions(const Dictionary &seeds, int32_t width, int32_t height) {
	Dictionary resolved;
	Dictionary occupied;
	Array keys = seeds.keys();
	std::vector<String> sorted_keys;
	for (int64_t index = 0; index < keys.size(); ++index) {
		sorted_keys.push_back(String(keys[index]));
	}
	std::sort(sorted_keys.begin(), sorted_keys.end(), [](const String &left, const String &right) { return left < right; });
	for (const String &zone_id : sorted_keys) {
		Dictionary point = seeds[zone_id];
		int32_t x = int32_t(point.get("x", 0));
		int32_t y = int32_t(point.get("y", 0));
		int32_t guard = std::max(1, width * height);
		while (occupied.has(point_key(x, y)) && guard > 0) {
			x = std::max(1, std::min(std::max(1, width - 2), x + 1));
			if (occupied.has(point_key(x, y))) {
				y = std::max(1, std::min(std::max(1, height - 2), y + 1));
			}
			--guard;
		}
		occupied[point_key(x, y)] = true;
		resolved[zone_id] = point_record(x, y);
	}
	return resolved;
}

Dictionary place_zone_seeds(const Array &zones, const Dictionary &normalized) {
	const int32_t width = int32_t(normalized.get("width", 36));
	const int32_t height = int32_t(normalized.get("height", 36));
	const String seed = String(normalized.get("normalized_seed", "0"));
	const double center_x = (double(width) - 1.0) * 0.5;
	const double center_y = (double(height) - 1.0) * 0.5;
	const double radius_x = std::max(3.0, double(width) * 0.36);
	const double radius_y = std::max(2.0, double(height) * 0.32);
	const double angle_offset = (double(hash32_int(seed + String(":zone_angle_offset")) % 10000U) / 10000.0) * TAU;

	Array starts;
	Array others;
	for (int64_t index = 0; index < zones.size(); ++index) {
		Dictionary zone = zones[index];
		if (zone.get("player_slot", Variant()).get_type() == Variant::NIL) {
			others.append(zone);
		} else {
			starts.append(zone);
		}
	}

	Dictionary seeds;
	for (int64_t index = 0; index < starts.size(); ++index) {
		Dictionary zone = starts[index];
		const String zone_id = String(zone.get("id", ""));
		const double angle = angle_offset + TAU * double(index) / double(std::max<int64_t>(1, starts.size()));
		int32_t x = int32_t(std::llround(center_x + std::cos(angle) * radius_x)) + deterministic_signed_jitter(seed + String(":") + zone_id + String(":x"), 1);
		int32_t y = int32_t(std::llround(center_y + std::sin(angle) * radius_y)) + deterministic_signed_jitter(seed + String(":") + zone_id + String(":y"), 1);
		x = std::max(1, std::min(std::max(1, width - 2), x));
		y = std::max(1, std::min(std::max(1, height - 2), y));
		seeds[zone_id] = point_record(x, y);
	}
	for (int64_t index = 0; index < others.size(); ++index) {
		Dictionary zone = others[index];
		const String zone_id = String(zone.get("id", ""));
		const String role = String(zone.get("role", "treasure"));
		const double angle = angle_offset + TAU * (double(index) + 0.5) / double(std::max<int64_t>(1, others.size()));
		const double radius_scale = role == "junction" ? 0.18 : 0.58;
		int32_t x = int32_t(std::llround(center_x + std::cos(angle) * radius_x * radius_scale)) + deterministic_signed_jitter(seed + String(":") + zone_id + String(":x"), 1);
		int32_t y = int32_t(std::llround(center_y + std::sin(angle) * radius_y * radius_scale)) + deterministic_signed_jitter(seed + String(":") + zone_id + String(":y"), 1);
		x = std::max(1, std::min(std::max(1, width - 2), x));
		y = std::max(1, std::min(std::max(1, height - 2), y));
		seeds[zone_id] = point_record(x, y);
	}
	return resolve_seed_collisions(seeds, width, height);
}

String nearest_zone_id(int32_t x, int32_t y, const Array &zones, const Dictionary &seeds) {
	String best_id = zones.is_empty() ? String("") : String(Dictionary(zones[0]).get("id", ""));
	double best_score = std::numeric_limits<double>::max();
	for (int64_t index = 0; index < zones.size(); ++index) {
		Dictionary zone = zones[index];
		const String zone_id = String(zone.get("id", ""));
		Dictionary seed = seeds.get(zone_id, Dictionary());
		const double dx = double(x) - double(int32_t(seed.get("x", 0)));
		const double dy = double(y) - double(int32_t(seed.get("y", 0)));
		const double weight = std::sqrt(double(std::max(1, int32_t(zone.get("base_size", 1)))));
		const double score = (dx * dx + dy * dy) / weight;
		if (score < best_score) {
			best_score = score;
			best_id = zone_id;
		}
	}
	return best_id;
}

Array zones_with_geometry(Array zones, const Dictionary &seeds, const Array &owner_grid) {
	Dictionary counts;
	Dictionary bounds_by_zone;
	for (int64_t index = 0; index < zones.size(); ++index) {
		Dictionary zone = zones[index];
		const String zone_id = String(zone.get("id", ""));
		counts[zone_id] = 0;
		Dictionary bounds;
		bounds["min_x"] = 999999;
		bounds["min_y"] = 999999;
		bounds["max_x"] = -1;
		bounds["max_y"] = -1;
		bounds_by_zone[zone_id] = bounds;
	}
	for (int64_t y = 0; y < owner_grid.size(); ++y) {
		Array row = owner_grid[y];
		for (int64_t x = 0; x < row.size(); ++x) {
			const String zone_id = String(row[x]);
			counts[zone_id] = int32_t(counts.get(zone_id, 0)) + 1;
			Dictionary bounds = bounds_by_zone.get(zone_id, Dictionary());
			bounds["min_x"] = std::min(int32_t(bounds.get("min_x", int32_t(x))), int32_t(x));
			bounds["min_y"] = std::min(int32_t(bounds.get("min_y", int32_t(y))), int32_t(y));
			bounds["max_x"] = std::max(int32_t(bounds.get("max_x", int32_t(x))), int32_t(x));
			bounds["max_y"] = std::max(int32_t(bounds.get("max_y", int32_t(y))), int32_t(y));
			bounds_by_zone[zone_id] = bounds;
		}
	}

	Array result;
	for (int64_t index = 0; index < zones.size(); ++index) {
		Dictionary zone = zones[index];
		const String zone_id = String(zone.get("id", ""));
		Dictionary anchor = seeds.get(zone_id, Dictionary());
		Dictionary bounds = bounds_by_zone.get(zone_id, Dictionary());
		zone["anchor"] = anchor;
		zone["center"] = point_record(int32_t(anchor.get("x", 0)), int32_t(anchor.get("y", 0)));
		zone["bounds"] = bounds;
		zone["cell_count"] = int32_t(counts.get(zone_id, 0));
		result.append(zone);
	}
	return result;
}

Dictionary generate_zone_layout(const Dictionary &normalized, const Dictionary &player_assignment) {
	const int32_t width = int32_t(normalized.get("width", 36));
	const int32_t height = int32_t(normalized.get("height", 36));
	const int32_t level_count = int32_t(normalized.get("level_count", 1));
	Array zones = build_foundation_zones(normalized, player_assignment);
	Dictionary seeds = place_zone_seeds(zones, normalized);
	Array owner_grid;
	for (int32_t y = 0; y < height; ++y) {
		Array row;
		for (int32_t x = 0; x < width; ++x) {
			row.append(nearest_zone_id(x, y, zones, seeds));
		}
		owner_grid.append(row);
	}
	zones = zones_with_geometry(zones, seeds, owner_grid);

	Dictionary level;
	level["level_index"] = 0;
	level["kind"] = "surface";
	level["owner_grid"] = owner_grid;
	level["anchor_points"] = seeds;
	level["allocation_model"] = "native_foundation_nearest_seed_weighted_owner_grid";
	Array levels;
	levels.append(level);

	Dictionary dimensions;
	dimensions["width"] = width;
	dimensions["height"] = height;
	dimensions["level_count"] = level_count;

	Dictionary policy;
	policy["zone_area_model"] = "native_foundation_weighted_nearest_seed";
	policy["water_mode"] = normalized.get("water_mode", "land");
	policy["template_model"] = "fallback_runtime_template_until_catalog_parity_slice";

	Dictionary layout;
	layout["schema_id"] = NATIVE_RMG_ZONE_LAYOUT_SCHEMA_ID;
	layout["schema_version"] = 1;
	layout["generation_status"] = "zones_generated_foundation";
	layout["full_generation_status"] = "not_implemented";
	layout["template_id"] = normalized.get("template_id", "");
	layout["template_source"] = "native_foundation_fallback_runtime_template";
	layout["dimensions"] = dimensions;
	layout["policy"] = policy;
	layout["zone_count"] = zones.size();
	layout["zones"] = zones;
	layout["zone_seed_records"] = seeds;
	layout["levels"] = levels;
	layout["surface_owner_grid"] = owner_grid;
	layout["surface_water_cells"] = Array();
	layout["unsupported_runtime_features"] = Array();
	layout["signature"] = hash32_hex(canonical_variant(layout));
	return layout;
}

bool point_far_enough(const Array &starts, int32_t x, int32_t y, int32_t min_spacing) {
	const int32_t min_distance_sq = min_spacing * min_spacing;
	for (int64_t index = 0; index < starts.size(); ++index) {
		Dictionary start = starts[index];
		const int32_t dx = x - int32_t(start.get("x", 0));
		const int32_t dy = y - int32_t(start.get("y", 0));
		if (dx * dx + dy * dy < min_distance_sq) {
			return false;
		}
	}
	return true;
}

Dictionary find_start_point(const Dictionary &zone, const Array &owner_grid, const Array &existing_starts, int32_t min_spacing) {
	Dictionary anchor = zone.get("anchor", Dictionary());
	int32_t best_x = int32_t(anchor.get("x", 0));
	int32_t best_y = int32_t(anchor.get("y", 0));
	if (point_far_enough(existing_starts, best_x, best_y, min_spacing)) {
		return point_record(best_x, best_y);
	}
	const String zone_id = String(zone.get("id", ""));
	int64_t best_score = std::numeric_limits<int64_t>::max();
	Dictionary best;
	for (int64_t y = 0; y < owner_grid.size(); ++y) {
		Array row = owner_grid[y];
		for (int64_t x = 0; x < row.size(); ++x) {
			if (String(row[x]) != zone_id) {
				continue;
			}
			if (!point_far_enough(existing_starts, int32_t(x), int32_t(y), min_spacing)) {
				continue;
			}
			const int64_t dx = int64_t(x) - int64_t(best_x);
			const int64_t dy = int64_t(y) - int64_t(best_y);
			const int64_t score = dx * dx + dy * dy;
			if (score < best_score) {
				best_score = score;
				best = point_record(int32_t(x), int32_t(y));
			}
		}
	}
	if (!best.is_empty()) {
		return best;
	}
	return point_record(best_x, best_y);
}

Dictionary generate_player_starts(const Dictionary &normalized, const Dictionary &zone_layout, const Dictionary &player_assignment) {
	const int32_t width = int32_t(normalized.get("width", 36));
	const int32_t height = int32_t(normalized.get("height", 36));
	Dictionary constraints = normalized.get("player_constraints", Dictionary());
	const int32_t player_count = int32_t(constraints.get("player_count", 2));
	const int32_t min_spacing = std::max(3, std::min(width, height) / std::max(3, player_count + 2));
	Array zones = zone_layout.get("zones", Array());
	Array owner_grid = zone_layout.get("surface_owner_grid", Array());
	Array starts;
	for (int64_t index = 0; index < zones.size(); ++index) {
		Dictionary zone = zones[index];
		if (zone.get("player_slot", Variant()).get_type() == Variant::NIL) {
			continue;
		}
		Dictionary point = find_start_point(zone, owner_grid, starts, min_spacing);
		const int32_t player_slot = int32_t(zone.get("player_slot", 0));
		Dictionary start;
		start["start_id"] = "player_start_" + String::num_int64(player_slot);
		start["player_slot"] = player_slot;
		start["owner_slot"] = zone.get("owner_slot", player_slot);
		start["player_type"] = zone.get("player_type", "computer");
		start["team_id"] = zone.get("team_id", "");
		start["faction_id"] = zone.get("faction_id", "");
		Dictionary assignment_by_owner = player_assignment.get("player_slot_by_owner_slot", Dictionary());
		Dictionary assignment = assignment_by_owner.get(String::num_int64(int32_t(zone.get("owner_slot", player_slot))), Dictionary());
		start["town_id"] = assignment.get("town_id", town_for_faction(String(zone.get("faction_id", ""))));
		start["zone_id"] = zone.get("id", "");
		start["zone_role"] = zone.get("role", "");
		start["x"] = int32_t(point.get("x", 0));
		start["y"] = int32_t(point.get("y", 0));
		start["level"] = 0;
		start["bounds_status"] = int32_t(point.get("x", 0)) >= 0 && int32_t(point.get("x", 0)) < width && int32_t(point.get("y", 0)) >= 0 && int32_t(point.get("y", 0)) < height ? "in_bounds" : "out_of_bounds";
		start["spacing_model"] = "native_foundation_minimum_euclidean_tile_spacing";
		start["primary_town_anchor_status"] = "reserved_not_materialized";
		starts.append(start);
	}

	Dictionary payload;
	payload["schema_id"] = NATIVE_RMG_PLAYER_STARTS_SCHEMA_ID;
	payload["schema_version"] = 1;
	payload["generation_status"] = "player_starts_generated_foundation";
	payload["full_generation_status"] = "not_implemented";
	payload["start_count"] = starts.size();
	payload["expected_player_count"] = player_count;
	payload["minimum_spacing_tiles"] = min_spacing;
	payload["starts"] = starts;
	payload["signature"] = hash32_hex(canonical_variant(payload));
	return payload;
}

Array foundation_route_links(const Dictionary &normalized) {
	Dictionary constraints = normalized.get("player_constraints", Dictionary());
	const int32_t player_count = int32_t(constraints.get("player_count", 2));
	Array links;
	for (int32_t index = 0; index < player_count; ++index) {
		const String start_id = "start_" + String::num_int64(index + 1);
		const String reward_id = "reward_" + String::num_int64((index % std::max(2, player_count)) + 1);

		Dictionary contest;
		contest["from"] = start_id;
		contest["to"] = "junction_1";
		contest["role"] = "contest_route";
		contest["guard_value"] = 600;
		contest["wide"] = false;
		contest["border_guard"] = false;
		links.append(contest);

		Dictionary reward;
		reward["from"] = start_id;
		reward["to"] = reward_id;
		reward["role"] = "early_reward_route";
		reward["guard_value"] = 150;
		reward["wide"] = false;
		reward["border_guard"] = false;
		links.append(reward);
	}
	for (int32_t index = 0; index < std::max(2, player_count); ++index) {
		Dictionary link;
		link["from"] = "reward_" + String::num_int64(index + 1);
		link["to"] = "junction_1";
		link["role"] = "reward_to_junction";
		link["guard_value"] = 300;
		link["wide"] = index == 0;
		link["border_guard"] = false;
		links.append(link);
	}
	return links;
}

String route_edge_id(int32_t index, const String &from_zone, const String &to_zone) {
	return "edge_" + slot_id_2(index) + "_" + from_zone + "_" + to_zone;
}

String route_classification(const Dictionary &link, bool path_found) {
	if (!path_found) {
		return "blocked_connectivity";
	}
	if (bool(link.get("border_guard", false))) {
		return "guarded_connectivity_border_guard";
	}
	if (bool(link.get("wide", false))) {
		return "full_connectivity_wide_unguarded";
	}
	if (int32_t(link.get("guard_value", 0)) > 0) {
		return "guarded_connectivity";
	}
	return "full_connectivity";
}

Array straight_route_cells(const Dictionary &from_point, const Dictionary &to_point, int32_t width, int32_t height, int32_t level) {
	Array cells;
	if (from_point.is_empty() || to_point.is_empty()) {
		return cells;
	}
	int32_t x = std::max(0, std::min(width - 1, int32_t(from_point.get("x", 0))));
	int32_t y = std::max(0, std::min(height - 1, int32_t(from_point.get("y", 0))));
	const int32_t goal_x = std::max(0, std::min(width - 1, int32_t(to_point.get("x", 0))));
	const int32_t goal_y = std::max(0, std::min(height - 1, int32_t(to_point.get("y", 0))));
	const int32_t step_x = goal_x >= x ? 1 : -1;
	while (x != goal_x) {
		cells.append(cell_record(x, y, level));
		x += step_x;
	}
	const int32_t step_y = goal_y >= y ? 1 : -1;
	while (y != goal_y) {
		cells.append(cell_record(x, y, level));
		y += step_y;
	}
	cells.append(cell_record(goal_x, goal_y, level));
	return cells;
}

Dictionary route_anchor_candidate(const Array &path, const Dictionary &from_anchor, const Dictionary &to_anchor, int32_t level) {
	if (!path.is_empty()) {
		Dictionary midpoint = path[int64_t(std::floor(double(path.size() - 1) * 0.5))];
		Dictionary result = cell_record(int32_t(midpoint.get("x", 0)), int32_t(midpoint.get("y", 0)), level);
		result["source"] = "route_path_midpoint";
		return result;
	}
	if (!from_anchor.is_empty() && !to_anchor.is_empty()) {
		Dictionary result = cell_record(
				int32_t(std::llround(double(int32_t(from_anchor.get("x", 0)) + int32_t(to_anchor.get("x", 0))) * 0.5)),
				int32_t(std::llround(double(int32_t(from_anchor.get("y", 0)) + int32_t(to_anchor.get("y", 0))) * 0.5)),
				level);
		result["source"] = "anchor_midpoint_fallback";
		return result;
	}
	return Dictionary();
}

Dictionary zone_anchor_lookup(const Dictionary &zone_layout) {
	Dictionary result;
	Array zones = zone_layout.get("zones", Array());
	for (int64_t index = 0; index < zones.size(); ++index) {
		Dictionary zone = zones[index];
		const String zone_id = String(zone.get("id", ""));
		if (!zone_id.is_empty()) {
			result[zone_id] = zone.get("anchor", zone.get("center", Dictionary()));
		}
	}
	return result;
}

Dictionary start_lookup_by_zone(const Dictionary &player_starts) {
	Dictionary result;
	Array starts = player_starts.get("starts", Array());
	for (int64_t index = 0; index < starts.size(); ++index) {
		Dictionary start = starts[index];
		const String zone_id = String(start.get("zone_id", ""));
		if (!zone_id.is_empty()) {
			result[zone_id] = start;
		}
	}
	return result;
}

Dictionary build_route_nodes(const Dictionary &zone_layout, const Dictionary &player_starts) {
	Dictionary nodes;
	Array zones = zone_layout.get("zones", Array());
	for (int64_t index = 0; index < zones.size(); ++index) {
		Dictionary zone = zones[index];
		const String zone_id = String(zone.get("id", ""));
		Dictionary anchor = zone.get("anchor", zone.get("center", Dictionary()));
		Dictionary node;
		node["id"] = "node_zone_" + zone_id;
		node["kind"] = "zone_anchor";
		node["zone_id"] = zone_id;
		node["zone_role"] = zone.get("role", "");
		node["point"] = cell_record(int32_t(anchor.get("x", 0)), int32_t(anchor.get("y", 0)), 0);
		node["required"] = false;
		node["connectable_state"] = "foundation_zone_anchor";
		nodes[node["id"]] = node;
	}
	Array starts = player_starts.get("starts", Array());
	for (int64_t index = 0; index < starts.size(); ++index) {
		Dictionary start = starts[index];
		const int32_t player_slot = int32_t(start.get("player_slot", 0));
		Dictionary node;
		node["id"] = "node_player_start_" + String::num_int64(player_slot);
		node["kind"] = "player_start_anchor";
		node["start_id"] = start.get("start_id", "");
		node["zone_id"] = start.get("zone_id", "");
		node["player_slot"] = player_slot;
		node["owner_slot"] = start.get("owner_slot", player_slot);
		node["point"] = cell_record(int32_t(start.get("x", 0)), int32_t(start.get("y", 0)), int32_t(start.get("level", 0)));
		node["required"] = true;
		node["connectable_state"] = "foundation_player_start_anchor";
		nodes[node["id"]] = node;
	}
	return nodes;
}

String preferred_node_id_for_zone(const String &zone_id, const Dictionary &start_by_zone) {
	if (start_by_zone.has(zone_id)) {
		Dictionary start = start_by_zone.get(zone_id, Dictionary());
		return "node_player_start_" + String::num_int64(int32_t(start.get("player_slot", 0)));
	}
	return "node_zone_" + zone_id;
}

Dictionary route_reachability_proof(const Dictionary &nodes, const Array &edges, const Dictionary &adjacency) {
	Array required_nodes;
	Array keys = nodes.keys();
	std::vector<String> sorted_keys;
	for (int64_t index = 0; index < keys.size(); ++index) {
		sorted_keys.push_back(String(keys[index]));
	}
	std::sort(sorted_keys.begin(), sorted_keys.end(), [](const String &left, const String &right) { return left < right; });
	for (const String &node_id : sorted_keys) {
		Dictionary node = nodes.get(node_id, Dictionary());
		if (bool(node.get("required", false))) {
			required_nodes.append(node_id);
		}
	}
	if (required_nodes.is_empty()) {
		Dictionary failed;
		failed["status"] = "fail";
		failed["reason"] = "no_required_nodes";
		failed["required_nodes"] = required_nodes;
		return failed;
	}

	const String start_node = String(required_nodes[0]);
	Dictionary visited;
	Array queue;
	visited[start_node] = true;
	queue.append(start_node);
	int64_t cursor = 0;
	while (cursor < queue.size()) {
		const String current = String(queue[cursor]);
		++cursor;
		Array neighbors = adjacency.get(current, Array());
		for (int64_t index = 0; index < neighbors.size(); ++index) {
			const String next = String(neighbors[index]);
			if (visited.has(next)) {
				continue;
			}
			visited[next] = true;
			queue.append(next);
		}
	}

	Array unreachable;
	for (int64_t index = 0; index < required_nodes.size(); ++index) {
		const String node_id = String(required_nodes[index]);
		if (!visited.has(node_id)) {
			unreachable.append(node_id);
		}
	}
	Array blocked_edges;
	for (int64_t index = 0; index < edges.size(); ++index) {
		Dictionary edge = edges[index];
		if (bool(edge.get("required", false)) && !bool(edge.get("path_found", false))) {
			blocked_edges.append(edge.get("id", ""));
		}
	}

	Dictionary proof;
	proof["status"] = unreachable.is_empty() && blocked_edges.is_empty() ? "pass" : "fail";
	proof["model"] = "required_player_start_nodes_connected_by_staged_native_road_paths";
	proof["required_nodes"] = required_nodes;
	proof["reachable_required_nodes"] = required_nodes.size() - unreachable.size();
	proof["unreachable_required_nodes"] = unreachable;
	proof["blocked_required_edges"] = blocked_edges;
	return proof;
}

void connect_adjacency(Dictionary &adjacency, const String &a, const String &b) {
	Array a_neighbors = adjacency.get(a, Array());
	Array b_neighbors = adjacency.get(b, Array());
	if (!array_has_string(a_neighbors, b)) {
		a_neighbors.append(b);
	}
	if (!array_has_string(b_neighbors, a)) {
		b_neighbors.append(a);
	}
	adjacency[a] = a_neighbors;
	adjacency[b] = b_neighbors;
}

Dictionary generate_road_network(const Dictionary &normalized, const Dictionary &zone_layout, const Dictionary &player_starts) {
	const int32_t width = int32_t(normalized.get("width", 36));
	const int32_t height = int32_t(normalized.get("height", 36));
	Array links = foundation_route_links(normalized);
	Dictionary nodes = build_route_nodes(zone_layout, player_starts);
	Dictionary zone_anchors = zone_anchor_lookup(zone_layout);
	Dictionary start_by_zone = start_lookup_by_zone(player_starts);
	Array edges;
	Array road_segments;
	Dictionary adjacency;
	Array covered_start_ids;
	Array covered_zone_ids;

	for (int64_t index = 0; index < links.size(); ++index) {
		Dictionary link = links[index];
		const String from_zone = String(link.get("from", ""));
		const String to_zone = String(link.get("to", ""));
		const String from_node_id = preferred_node_id_for_zone(from_zone, start_by_zone);
		const String to_node_id = preferred_node_id_for_zone(to_zone, start_by_zone);
		Dictionary from_node = nodes.get(from_node_id, Dictionary());
		Dictionary to_node = nodes.get(to_node_id, Dictionary());
		Dictionary from_point = from_node.get("point", zone_anchors.get(from_zone, Dictionary()));
		Dictionary to_point = to_node.get("point", zone_anchors.get(to_zone, Dictionary()));
		Array cells = straight_route_cells(from_point, to_point, width, height, 0);
		const bool path_found = !cells.is_empty();
		const String edge_id = route_edge_id(int32_t(index + 1), from_zone, to_zone);
		const String classification = route_classification(link, path_found);

		Dictionary edge;
		edge["id"] = edge_id;
		edge["from"] = from_zone;
		edge["to"] = to_zone;
		edge["from_node_id"] = from_node_id;
		edge["to_node_id"] = to_node_id;
		edge["role"] = link.get("role", "route");
		edge["guard_value"] = link.get("guard_value", 0);
		edge["wide"] = link.get("wide", false);
		edge["border_guard"] = link.get("border_guard", false);
		edge["required"] = true;
		edge["path_found"] = path_found;
		edge["cell_count"] = cells.size();
		edge["from_point"] = from_point;
		edge["to_point"] = to_point;
		edge["route_cell_anchor_candidate"] = route_anchor_candidate(cells, from_point, to_point, 0);
		edge["connectivity_classification"] = classification;
		edge["transit_semantics"] = Dictionary();
		edges.append(edge);

		if (path_found) {
			connect_adjacency(adjacency, from_node_id, to_node_id);
		}
		if (start_by_zone.has(from_zone)) {
			Dictionary start = start_by_zone.get(from_zone, Dictionary());
			const String start_id = String(start.get("start_id", ""));
			if (!array_has_string(covered_start_ids, start_id)) {
				covered_start_ids.append(start_id);
			}
		}
		if (!array_has_string(covered_zone_ids, from_zone)) {
			covered_zone_ids.append(from_zone);
		}
		if (!array_has_string(covered_zone_ids, to_zone)) {
			covered_zone_ids.append(to_zone);
		}

		Dictionary segment;
		segment["id"] = "road_" + edge_id;
		segment["route_edge_id"] = edge_id;
		segment["overlay_id"] = "generated_dirt_road";
		segment["cells"] = cells;
		segment["cell_count"] = cells.size();
		segment["connectivity_classification"] = classification;
		segment["role"] = link.get("role", "route");
		segment["writeout_state"] = "staged_overlay_no_tile_bytes_written";
		segment["bounds_status"] = "in_bounds";
		road_segments.append(segment);
	}

	Dictionary reachability = route_reachability_proof(nodes, edges, adjacency);

	Dictionary route_graph;
	route_graph["schema_id"] = NATIVE_RMG_ROUTE_GRAPH_SCHEMA_ID;
	route_graph["schema_version"] = 1;
	route_graph["generation_status"] = "route_graph_generated_foundation";
	route_graph["full_generation_status"] = "not_implemented";
	route_graph["nodes"] = nodes;
	route_graph["edges"] = edges;
	route_graph["adjacency"] = adjacency;
	route_graph["required_reachability"] = reachability;
	route_graph["route_edge_count"] = edges.size();
	route_graph["route_node_count"] = nodes.size();
	route_graph["signature"] = hash32_hex(canonical_variant(route_graph));

	Dictionary coverage;
	coverage["expected_player_start_count"] = player_starts.get("start_count", 0);
	coverage["covered_player_start_count"] = covered_start_ids.size();
	coverage["covered_player_start_ids"] = covered_start_ids;
	coverage["covered_zone_ids"] = covered_zone_ids;
	coverage["status"] = covered_start_ids.size() == int32_t(player_starts.get("start_count", 0)) ? "pass" : "partial";

	Dictionary road_network;
	road_network["schema_id"] = NATIVE_RMG_ROAD_NETWORK_SCHEMA_ID;
	road_network["schema_version"] = 1;
	road_network["generation_status"] = "roads_generated_foundation";
	road_network["full_generation_status"] = "not_implemented";
	road_network["writeout_policy"] = "final_generated_tile_stream_no_authored_tile_write";
	road_network["materialization_state"] = "staged_overlay_records_only_no_gameplay_adoption";
	road_network["overlay_id"] = "generated_dirt_road";
	road_network["route_graph"] = route_graph;
	road_network["road_segments"] = road_segments;
	road_network["road_segment_count"] = road_segments.size();
	road_network["road_cell_count"] = [&road_segments]() {
		int32_t total = 0;
		for (int64_t index = 0; index < road_segments.size(); ++index) {
			Dictionary segment = road_segments[index];
			total += int32_t(segment.get("cell_count", 0));
		}
		return total;
	}();
	road_network["required_start_coverage"] = coverage;
	road_network["route_reachability_proof"] = reachability;
	road_network["signature"] = hash32_hex(canonical_variant(road_network));
	return road_network;
}

Array bounded_river_cells(const Dictionary &normalized) {
	const int32_t width = int32_t(normalized.get("width", 36));
	const int32_t height = int32_t(normalized.get("height", 36));
	const String seed = String(normalized.get("normalized_seed", "0"));
	Array cells;
	const int32_t min_y = height <= 2 ? 0 : 1;
	const int32_t max_y = height <= 2 ? height - 1 : height - 2;
	const int32_t base_x = std::max(1, std::min(std::max(1, width - 2), 1 + int32_t(hash32_int(seed + String(":river_base_x")) % uint32_t(std::max(1, width - 2)))));
	for (int32_t y = min_y; y <= max_y; ++y) {
		const int32_t jitter = deterministic_signed_jitter(seed + String(":river_y:") + String::num_int64(y), 1);
		const int32_t x = std::max(0, std::min(width - 1, base_x + jitter));
		cells.append(cell_record(x, y, 0));
	}
	return cells;
}

Array island_waterline_cells(const Dictionary &normalized) {
	const int32_t width = int32_t(normalized.get("width", 36));
	const int32_t height = int32_t(normalized.get("height", 36));
	Array cells;
	if (width <= 1 || height <= 1) {
		return cells;
	}
	for (int32_t x = 0; x < width; x += 2) {
		cells.append(cell_record(x, 0, 0));
	}
	for (int32_t y = 2; y < height; y += 2) {
		cells.append(cell_record(width - 1, y, 0));
	}
	return cells;
}

Dictionary bounds_for_cells(const Array &cells) {
	Dictionary bounds;
	if (cells.is_empty()) {
		return bounds;
	}
	int32_t min_x = std::numeric_limits<int32_t>::max();
	int32_t min_y = std::numeric_limits<int32_t>::max();
	int32_t max_x = -1;
	int32_t max_y = -1;
	for (int64_t index = 0; index < cells.size(); ++index) {
		Dictionary cell = cells[index];
		const int32_t x = int32_t(cell.get("x", 0));
		const int32_t y = int32_t(cell.get("y", 0));
		min_x = std::min(min_x, x);
		min_y = std::min(min_y, y);
		max_x = std::max(max_x, x);
		max_y = std::max(max_y, y);
	}
	bounds["min_x"] = min_x;
	bounds["min_y"] = min_y;
	bounds["max_x"] = max_x;
	bounds["max_y"] = max_y;
	return bounds;
}

Dictionary generate_river_network(const Dictionary &normalized, const Dictionary &road_network) {
	Array segments;
	Array river_cells = bounded_river_cells(normalized);
	Dictionary river_segment;
	river_segment["id"] = "river_foundation_01";
	river_segment["kind"] = "river";
	river_segment["route_feature_class"] = "bounded_waterline_feature";
	river_segment["cells"] = river_cells;
	river_segment["cell_count"] = river_cells.size();
	river_segment["bounds"] = bounds_for_cells(river_cells);
	river_segment["materialization_state"] = "bounded_route_feature_metadata_only_no_terrain_mutation";
	segments.append(river_segment);

	if (String(normalized.get("water_mode", "land")) == "islands") {
		Array waterline = island_waterline_cells(normalized);
		Dictionary waterline_segment;
		waterline_segment["id"] = "waterline_foundation_01";
		waterline_segment["kind"] = "shore_waterline";
		waterline_segment["route_feature_class"] = "island_border_waterline";
		waterline_segment["cells"] = waterline;
		waterline_segment["cell_count"] = waterline.size();
		waterline_segment["bounds"] = bounds_for_cells(waterline);
		waterline_segment["materialization_state"] = "waterline_metadata_only_existing_terrain_grid_unchanged";
		segments.append(waterline_segment);
	}

	int32_t cell_count = 0;
	for (int64_t index = 0; index < segments.size(); ++index) {
		Dictionary segment = segments[index];
		cell_count += int32_t(segment.get("cell_count", 0));
	}

	Dictionary policy;
	policy["water_mode"] = normalized.get("water_mode", "land");
	policy["enabled"] = true;
	policy["route_feature_boundary"] = "foundation_records_only_no_passability_or_tile_mutation";
	policy["road_crossing_policy"] = "crossing_metadata_deferred_to_later_parity_slice";

	Dictionary network;
	network["schema_id"] = NATIVE_RMG_RIVER_NETWORK_SCHEMA_ID;
	network["schema_version"] = 1;
	network["generation_status"] = "rivers_generated_foundation";
	network["full_generation_status"] = "not_implemented";
	network["policy"] = policy;
	network["river_segments"] = segments;
	network["river_segment_count"] = segments.size();
	network["river_cell_count"] = cell_count;
	network["related_road_network_signature"] = road_network.get("signature", "");
	network["materialization_state"] = "staged_route_feature_records_only_no_gameplay_adoption";
	network["signature"] = hash32_hex(canonical_variant(network));
	return network;
}

Dictionary generate_terrain_grid(const Dictionary &normalized) {
	const int32_t width = int32_t(normalized.get("width", 36));
	const int32_t height = int32_t(normalized.get("height", 36));
	const int32_t level_count = int32_t(normalized.get("level_count", 1));
	Array terrain_pool = normalized_terrain_pool(normalized.get("terrain_ids", default_terrain_pool()));
	Array seeds = terrain_seed_records(normalized, terrain_pool);
	Array levels;
	Dictionary aggregate_counts;
	const PackedStringArray ids_by_code = terrain_id_by_code();
	for (int32_t level = 0; level < level_count; ++level) {
		PackedInt32Array terrain_codes;
		terrain_codes.resize(width * height);
		Dictionary counts;
		Dictionary biome_counts;
		for (int32_t y = 0; y < height; ++y) {
			for (int32_t x = 0; x < width; ++x) {
				const String terrain_id = choose_terrain_for_cell(x, y, level, terrain_pool, seeds, normalized);
				const String biome_id = biome_for_terrain(terrain_id);
				const int32_t terrain_code = terrain_code_for_id(terrain_id);
				const int32_t flat_index = y * width + x;
				terrain_codes.set(flat_index, terrain_code);
				counts[terrain_id] = int32_t(counts.get(terrain_id, 0)) + 1;
				biome_counts[biome_id] = int32_t(biome_counts.get(biome_id, 0)) + 1;
				aggregate_counts[terrain_id] = int32_t(aggregate_counts.get(terrain_id, 0)) + 1;
			}
		}
		Dictionary level_record;
		level_record["level_index"] = level;
		level_record["level_kind"] = level == 0 ? "surface" : "underground";
		level_record["width"] = width;
		level_record["height"] = height;
		level_record["tile_count"] = width * height;
		level_record["terrain_code_u16"] = terrain_codes;
		level_record["terrain_counts"] = counts;
		level_record["biome_counts"] = biome_counts;
		level_record["signature"] = hash32_hex(canonical_variant(level_record));
		levels.append(level_record);
	}

	Dictionary biome_by_terrain;
	for (int64_t index = 0; index < ids_by_code.size(); ++index) {
		const String terrain_id = String(ids_by_code[index]);
		biome_by_terrain[terrain_id] = biome_for_terrain(terrain_id);
	}

	Dictionary grid;
	grid["schema_id"] = NATIVE_RMG_TERRAIN_GRID_SCHEMA_ID;
	grid["schema_version"] = 1;
	grid["generation_status"] = "terrain_grid_generated";
	grid["full_generation_status"] = "not_implemented";
	grid["width"] = width;
	grid["height"] = height;
	grid["level_count"] = level_count;
	grid["tile_count"] = width * height * level_count;
	grid["terrain_id_by_code"] = ids_by_code;
	grid["biome_id_by_terrain_id"] = biome_by_terrain;
	grid["terrain_palette_ids"] = terrain_pool;
	grid["zone_seed_model"] = "deterministic_terrain_palette_voronoi_seed_grid";
	grid["terrain_seed_records"] = seeds;
	grid["terrain_counts"] = aggregate_counts;
	grid["levels"] = levels;
	grid["signature"] = hash32_hex(canonical_variant(grid));
	return grid;
}

Dictionary validation_not_implemented(const String &operation, const String &report_schema_id) {
	Dictionary failure;
	failure["code"] = "not_implemented";
	failure["severity"] = "fail";
	failure["path"] = operation;
	failure["message"] = String("Validation is stubbed in the native package API skeleton.");
	failure["context"] = Dictionary();

	Array failures;
	failures.append(failure);

	Dictionary report;
	report["schema_id"] = report_schema_id;
	report["schema_version"] = 1;
	report["status"] = "fail";
	report["failure_count"] = 1;
	report["warning_count"] = 0;
	report["failures"] = failures;
	report["warnings"] = Array();
	report["metrics"] = Dictionary();

	Dictionary result;
	result["ok"] = false;
	result["status"] = "fail";
	result["error_code"] = "not_implemented";
	result["message"] = operation + String(" is not implemented in the Slice 1 native package API skeleton.");
	result["operation"] = operation;
	result["report"] = report;
	result["recoverable"] = true;
	return result;
}

} // namespace

void MapPackageService::_bind_methods() {
	ClassDB::bind_method(D_METHOD("get_api_version"), &MapPackageService::get_api_version);
	ClassDB::bind_method(D_METHOD("get_api_metadata"), &MapPackageService::get_api_metadata);
	ClassDB::bind_method(D_METHOD("get_capabilities"), &MapPackageService::get_capabilities);
	ClassDB::bind_method(D_METHOD("get_schema_ids"), &MapPackageService::get_schema_ids);
	ClassDB::bind_method(D_METHOD("create_map_document_stub", "initial_state"), &MapPackageService::create_map_document_stub, DEFVAL(Dictionary()));
	ClassDB::bind_method(D_METHOD("create_scenario_document_stub", "initial_state"), &MapPackageService::create_scenario_document_stub, DEFVAL(Dictionary()));
	ClassDB::bind_method(D_METHOD("load_map_package", "path", "options"), &MapPackageService::load_map_package, DEFVAL(Dictionary()));
	ClassDB::bind_method(D_METHOD("load_scenario_package", "path", "options"), &MapPackageService::load_scenario_package, DEFVAL(Dictionary()));
	ClassDB::bind_method(D_METHOD("validate_map_document", "map_document", "options"), &MapPackageService::validate_map_document, DEFVAL(Dictionary()));
	ClassDB::bind_method(D_METHOD("validate_scenario_document", "scenario_document", "map_document", "options"), &MapPackageService::validate_scenario_document, DEFVAL(Dictionary()));
	ClassDB::bind_method(D_METHOD("save_map_package", "map_document", "path", "options"), &MapPackageService::save_map_package, DEFVAL(Dictionary()));
	ClassDB::bind_method(D_METHOD("save_scenario_package", "scenario_document", "path", "options"), &MapPackageService::save_scenario_package, DEFVAL(Dictionary()));
	ClassDB::bind_method(D_METHOD("migrate_map_package", "source_path", "target_path", "target_version", "options"), &MapPackageService::migrate_map_package, DEFVAL(Dictionary()));
	ClassDB::bind_method(D_METHOD("migrate_scenario_package", "source_path", "target_path", "target_version", "options"), &MapPackageService::migrate_scenario_package, DEFVAL(Dictionary()));
	ClassDB::bind_method(D_METHOD("convert_legacy_scenario_record", "scenario_record", "terrain_layers_record", "options"), &MapPackageService::convert_legacy_scenario_record, DEFVAL(Dictionary()));
	ClassDB::bind_method(D_METHOD("convert_generated_payload", "generated_map", "options"), &MapPackageService::convert_generated_payload, DEFVAL(Dictionary()));
	ClassDB::bind_method(D_METHOD("compute_document_hash", "document", "options"), &MapPackageService::compute_document_hash, DEFVAL(Dictionary()));
	ClassDB::bind_method(D_METHOD("inspect_package", "path", "options"), &MapPackageService::inspect_package, DEFVAL(Dictionary()));
	ClassDB::bind_method(D_METHOD("normalize_random_map_config", "config"), &MapPackageService::normalize_random_map_config);
	ClassDB::bind_method(D_METHOD("random_map_config_identity", "config"), &MapPackageService::random_map_config_identity);
	ClassDB::bind_method(D_METHOD("generate_random_map", "config", "options"), &MapPackageService::generate_random_map, DEFVAL(Dictionary()));
}

String MapPackageService::get_api_version() const { return API_VERSION; }

Dictionary MapPackageService::get_api_metadata() const {
	Dictionary result;
	result["ok"] = true;
	result["api_id"] = API_ID;
	result["api_version"] = API_VERSION;
	result["binding_kind"] = "native_gdextension";
	result["native_extension_loaded"] = true;
	result["map_schema_id"] = MAP_SCHEMA_ID;
	result["scenario_schema_id"] = SCENARIO_SCHEMA_ID;
	result["package_schema_version"] = 1;
	result["map_package_extension"] = ".amap";
	result["scenario_package_extension"] = ".ascenario";
	result["capabilities"] = capabilities();
	result["status"] = "skeleton";
	return result;
}

PackedStringArray MapPackageService::get_capabilities() const { return capabilities(); }

Dictionary MapPackageService::get_schema_ids() const {
	Dictionary result;
	result["map_document"] = MAP_SCHEMA_ID;
	result["scenario_document"] = SCENARIO_SCHEMA_ID;
	result["map_validation_report"] = "aurelion_map_validation_report";
	result["scenario_validation_report"] = "aurelion_scenario_validation_report";
	return result;
}

Ref<MapDocument> MapPackageService::create_map_document_stub(Dictionary initial_state) const {
	Ref<MapDocument> document;
	document.instantiate();
	document->configure(initial_state);
	return document;
}

Ref<ScenarioDocument> MapPackageService::create_scenario_document_stub(Dictionary initial_state) const {
	Ref<ScenarioDocument> document;
	document.instantiate();
	document->configure(initial_state);
	return document;
}

Dictionary MapPackageService::load_map_package(String path, Dictionary options) const { return not_implemented("load_map_package", path, options); }
Dictionary MapPackageService::load_scenario_package(String path, Dictionary options) const { return not_implemented("load_scenario_package", path, options); }
Dictionary MapPackageService::validate_map_document(Ref<MapDocument> map_document, Dictionary options) const { return validation_not_implemented("validate_map_document", "aurelion_map_validation_report"); }
Dictionary MapPackageService::validate_scenario_document(Ref<ScenarioDocument> scenario_document, Ref<MapDocument> map_document, Dictionary options) const { return validation_not_implemented("validate_scenario_document", "aurelion_scenario_validation_report"); }
Dictionary MapPackageService::save_map_package(Ref<MapDocument> map_document, String path, Dictionary options) const { return not_implemented("save_map_package", path, options); }
Dictionary MapPackageService::save_scenario_package(Ref<ScenarioDocument> scenario_document, String path, Dictionary options) const { return not_implemented("save_scenario_package", path, options); }
Dictionary MapPackageService::migrate_map_package(String source_path, String target_path, int32_t target_version, Dictionary options) const { return not_implemented("migrate_map_package", source_path, options); }
Dictionary MapPackageService::migrate_scenario_package(String source_path, String target_path, int32_t target_version, Dictionary options) const { return not_implemented("migrate_scenario_package", source_path, options); }
Dictionary MapPackageService::convert_legacy_scenario_record(Dictionary scenario_record, Dictionary terrain_layers_record, Dictionary options) const { return not_implemented("convert_legacy_scenario_record", "", options); }
Dictionary MapPackageService::convert_generated_payload(Dictionary generated_map, Dictionary options) const { return not_implemented("convert_generated_payload", "", options); }
Dictionary MapPackageService::compute_document_hash(Variant document, Dictionary options) const { return not_implemented("compute_document_hash", "", options); }
Dictionary MapPackageService::inspect_package(String path, Dictionary options) const { return not_implemented("inspect_package", path, options); }

Dictionary MapPackageService::normalize_random_map_config(Dictionary config) const {
	Variant size_value = config.get("size", Variant());
	Dictionary size = size_value.get_type() == Variant::DICTIONARY ? Dictionary(size_value) : Dictionary();
	Variant profile_value = config.get("profile", Variant());
	Dictionary profile = profile_value.get_type() == Variant::DICTIONARY ? Dictionary(profile_value) : Dictionary();

	String seed = normalized_text(config, "seed", "0");
	String template_id = normalized_text(config, "template_id", "");
	if (template_id.is_empty()) {
		template_id = normalized_text(profile, "template_id", "");
	}
	String profile_id = normalized_text(profile, "id", normalized_text(config, "profile_id", ""));
	String water_mode = normalized_text(size, "water_mode", normalized_text(config, "water_mode", "land"));
	if (water_mode != "islands") {
		water_mode = "land";
	}
	Dictionary player_constraints = normalized_player_constraints(config);
	const int32_t player_count = int32_t(player_constraints.get("player_count", 2));
	Array terrain_ids = normalized_terrain_pool(normalized_string_array(profile.get("terrain_ids", Variant()), default_terrain_pool()));
	Array faction_ids = ensure_repeated_to_count(normalized_string_array(profile.get("faction_ids", Variant()), default_faction_pool()), default_faction_pool(), player_count);
	if (terrain_ids.is_empty()) {
		for (int64_t index = 0; index < faction_ids.size(); ++index) {
			const String faction_terrain = terrain_for_faction(String(faction_ids[index]));
			if (is_passable_terrain_id(faction_terrain) && !array_has_string(terrain_ids, faction_terrain)) {
				terrain_ids.append(faction_terrain);
			}
		}
	}
	Array town_ids = town_ids_for_factions(profile.get("town_ids", Variant()), faction_ids, player_count);

	Dictionary result;
	result["schema_id"] = NATIVE_RMG_SCHEMA_ID;
	result["schema_version"] = 1;
	result["generator_version"] = NATIVE_RMG_VERSION;
	result["seed"] = seed;
	result["normalized_seed"] = seed;
	result["width"] = nested_size_int(config, size, "width", "requested_width", 36);
	result["height"] = nested_size_int(config, size, "height", "requested_height", 36);
	result["level_count"] = std::max(1, std::min(2, normalized_int(size, "level_count", normalized_int(config, "level_count", 1))));
	result["template_id"] = template_id;
	result["profile_id"] = profile_id;
	result["size_class_id"] = normalized_text(size, "size_class_id", normalized_text(config, "size_class_id", ""));
	result["water_mode"] = water_mode;
	result["player_constraints"] = player_constraints;
	result["terrain_ids"] = terrain_ids;
	result["faction_ids"] = faction_ids;
	result["town_ids"] = town_ids;
	result["full_generation_status"] = "not_implemented";
	result["foundation_scope"] = "deterministic_config_identity_native_terrain_grid_zones_player_starts_and_road_river_networks_only";
	return result;
}

Dictionary MapPackageService::random_map_config_identity(Dictionary config) const {
	Dictionary normalized = normalize_random_map_config(config);
	String canonical = canonical_variant(normalized);
	String signature = hash32_hex(canonical);

	Dictionary result;
	result["ok"] = true;
	result["schema_id"] = "aurelion_native_random_map_identity";
	result["schema_version"] = 1;
	result["algorithm"] = "canonical_variant_fnv1a32_foundation";
	result["signature"] = signature;
	result["config_hash"] = "fnv1a32:" + signature;
	result["map_id"] = "native_rmg_" + signature;
	result["normalized_seed"] = String(normalized.get("normalized_seed", ""));
	result["width"] = int32_t(normalized.get("width", 0));
	result["height"] = int32_t(normalized.get("height", 0));
	result["level_count"] = int32_t(normalized.get("level_count", 1));
	result["template_id"] = String(normalized.get("template_id", ""));
	result["profile_id"] = String(normalized.get("profile_id", ""));
	result["canonical_config"] = canonical;
	result["normalized_config"] = normalized;
	result["full_generation_status"] = "not_implemented";
	return result;
}

Dictionary MapPackageService::generate_random_map(Dictionary config, Dictionary options) const {
	Dictionary normalized = normalize_random_map_config(config);
	Dictionary identity = random_map_config_identity(config);
	Dictionary terrain_grid = generate_terrain_grid(normalized);
	Dictionary player_assignment = player_assignment_for_config(normalized);
	Dictionary zone_layout = generate_zone_layout(normalized, player_assignment);
	Dictionary player_starts = generate_player_starts(normalized, zone_layout, player_assignment);
	Dictionary road_network = generate_road_network(normalized, zone_layout, player_starts);
	Dictionary river_network = generate_river_network(normalized, road_network);

	Dictionary metadata;
	metadata["schema_id"] = NATIVE_RMG_SCHEMA_ID;
	metadata["schema_version"] = 1;
	metadata["generated"] = true;
	metadata["generator_version"] = NATIVE_RMG_VERSION;
	metadata["generation_status"] = "partial_foundation";
	metadata["full_generation_status"] = "not_implemented";
	metadata["terrain_generation_status"] = "terrain_grid_generated";
	metadata["zone_generation_status"] = "zones_generated_foundation";
	metadata["player_start_generation_status"] = "player_starts_generated_foundation";
	metadata["road_generation_status"] = "roads_generated_foundation";
	metadata["river_generation_status"] = "rivers_generated_foundation";
	metadata["normalized_config"] = normalized;
	metadata["deterministic_identity"] = identity;
	metadata["terrain_grid_signature"] = terrain_grid.get("signature", "");
	metadata["zone_layout_signature"] = zone_layout.get("signature", "");
	metadata["player_start_signature"] = player_starts.get("signature", "");
	metadata["road_network_signature"] = road_network.get("signature", "");
	metadata["route_graph_signature"] = Dictionary(road_network.get("route_graph", Dictionary())).get("signature", "");
	metadata["river_network_signature"] = river_network.get("signature", "");
	metadata["options_keys"] = options.keys();

	Dictionary map_state;
	map_state["map_id"] = identity.get("map_id", "");
	map_state["map_hash"] = identity.get("config_hash", "");
	map_state["source_kind"] = "generated";
	map_state["width"] = int32_t(normalized.get("width", 36));
	map_state["height"] = int32_t(normalized.get("height", 36));
	map_state["level_count"] = int32_t(normalized.get("level_count", 1));
	map_state["metadata"] = metadata;

	Ref<MapDocument> document;
	document.instantiate();
	document->configure(map_state);

	Dictionary warning;
	warning["code"] = "full_generation_not_implemented";
	warning["severity"] = "warning";
	warning["path"] = "generate_random_map";
	warning["message"] = "Native RMG currently creates deterministic identity metadata, a terrain grid, foundation zones, player start anchors, and foundation road/river network records only; objects, towns, guards, validation parity, and package/session adoption are not implemented.";
	warning["context"] = Dictionary();

	Array warnings;
	warnings.append(warning);

	Dictionary metrics;
	metrics["width"] = int32_t(normalized.get("width", 36));
	metrics["height"] = int32_t(normalized.get("height", 36));
	metrics["level_count"] = int32_t(normalized.get("level_count", 1));
	metrics["tile_count"] = document->get_tile_count();
	metrics["terrain_grid_tile_count"] = terrain_grid.get("tile_count", 0);
	metrics["terrain_palette_count"] = Array(terrain_grid.get("terrain_palette_ids", Array())).size();
	metrics["zone_count"] = zone_layout.get("zone_count", 0);
	metrics["player_start_count"] = player_starts.get("start_count", 0);
	metrics["road_segment_count"] = road_network.get("road_segment_count", 0);
	metrics["road_cell_count"] = road_network.get("road_cell_count", 0);
	metrics["river_segment_count"] = river_network.get("river_segment_count", 0);
	metrics["river_cell_count"] = river_network.get("river_cell_count", 0);
	metrics["object_count"] = document->get_object_count();

	Dictionary report;
	report["schema_id"] = "aurelion_native_random_map_foundation_report";
	report["schema_version"] = 1;
	report["status"] = "partial_foundation";
	report["failure_count"] = 0;
	report["warning_count"] = warnings.size();
	report["failures"] = Array();
	report["warnings"] = warnings;
	report["metrics"] = metrics;
	report["deterministic_identity"] = identity;
	report["terrain_grid_status"] = terrain_grid.get("generation_status", "");
	report["terrain_grid_signature"] = terrain_grid.get("signature", "");
	report["zone_generation_status"] = zone_layout.get("generation_status", "");
	report["zone_layout_signature"] = zone_layout.get("signature", "");
	report["player_start_generation_status"] = player_starts.get("generation_status", "");
	report["player_start_signature"] = player_starts.get("signature", "");
	report["road_generation_status"] = road_network.get("generation_status", "");
	report["road_network_signature"] = road_network.get("signature", "");
	report["route_graph_signature"] = Dictionary(road_network.get("route_graph", Dictionary())).get("signature", "");
	report["route_reachability_status"] = Dictionary(road_network.get("route_reachability_proof", Dictionary())).get("status", "");
	report["river_generation_status"] = river_network.get("generation_status", "");
	report["river_network_signature"] = river_network.get("signature", "");
	Array remaining_parity_slices;
	remaining_parity_slices.append("native-rmg-road-river-network-10184");
	remaining_parity_slices.append("native-rmg-object-placement-foundation-10184");
	remaining_parity_slices.append("native-rmg-town-guard-placement-10184");
	remaining_parity_slices.append("native-rmg-validation-provenance-parity-10184");
	remaining_parity_slices.append("native-rmg-package-session-adoption-10184");
	report["remaining_parity_slices"] = remaining_parity_slices;

	Dictionary result;
	result["ok"] = true;
	result["status"] = "partial_foundation";
	result["generation_status"] = "partial_foundation";
	result["terrain_generation_status"] = "terrain_grid_generated";
	result["terrain_grid_status"] = "generated";
	result["zone_generation_status"] = "zones_generated_foundation";
	result["player_start_generation_status"] = "player_starts_generated_foundation";
	result["road_generation_status"] = "roads_generated_foundation";
	result["river_generation_status"] = "rivers_generated_foundation";
	result["full_generation_status"] = "not_implemented";
	result["normalized_config"] = normalized;
	result["deterministic_identity"] = identity;
	result["terrain_grid"] = terrain_grid;
	result["player_assignment"] = player_assignment;
	result["zone_layout"] = zone_layout;
	result["player_starts"] = player_starts;
	result["route_graph"] = road_network.get("route_graph", Dictionary());
	result["road_network"] = road_network;
	result["river_network"] = river_network;
	result["route_reachability_proof"] = road_network.get("route_reachability_proof", Dictionary());
	result["map_document"] = document;
	result["map_metadata"] = metadata;
	result["report"] = report;
	result["adoption_status"] = "not_authoritative_no_runtime_call_site_adoption";
	return result;
}
