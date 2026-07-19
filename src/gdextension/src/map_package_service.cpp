#include "map_package_service.hpp"

#include "h3maped_rmg_core.hpp"
#include "rmg_data_model.hpp"

#include <godot_cpp/classes/dir_access.hpp>
#include <godot_cpp/classes/file_access.hpp>
#include <godot_cpp/classes/json.hpp>
#include <godot_cpp/core/class_db.hpp>
#include <godot_cpp/variant/array.hpp>
#include <godot_cpp/variant/packed_int32_array.hpp>

#include <algorithm>
#include <cstdint>
#include <string>
#include <vector>

using namespace godot;

namespace {

constexpr const char *API_ID = "aurelion_map_package_api";
constexpr const char *API_VERSION = "0.1.0";
constexpr const char *MAP_SCHEMA_ID = "aurelion_map_document";
constexpr const char *SCENARIO_SCHEMA_ID = "aurelion_scenario_document";
constexpr const char *MAP_PACKAGE_SCHEMA_ID = "aurelion_map_package";
constexpr const char *SCENARIO_PACKAGE_SCHEMA_ID = "aurelion_scenario_package";
constexpr const char *NATIVE_RMG_SCHEMA_ID = "aurelion_native_random_map_config_normalization";
constexpr const char *NATIVE_RMG_VERSION = "native_rmg_exact_h3maped_state_chain_v1";
constexpr uint64_t HASH_MODULUS = 4294967296ULL;

PackedStringArray capabilities() {
	PackedStringArray result;
	result.append("api_metadata");
	result.append("typed_map_document_stub");
	result.append("typed_scenario_document_stub");
	result.append("stable_not_implemented_errors");
	result.append("native_random_map_config_identity");
	result.append("native_random_map_generation");
	result.append("native_random_map_package_session_adoption");
	result.append("native_rmg_homm3_generator_data_model_report");
	result.append("native_package_save_load");
	result.append("native_map_package_document_validation");
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
		case Variant::PACKED_INT32_ARRAY: {
			PackedInt32Array array = value;
			String result = "[";
			for (int64_t index = 0; index < array.size(); ++index) {
				if (index > 0) {
					result += ",";
				}
				result += "int:" + String::num_int64(array[index]);
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
	const uint32_t value = hash32_int(text);
	String result;
	for (int index = 7; index >= 0; --index) {
		const uint32_t nibble = (value >> (index * 4)) & 0xFU;
		result += String::chr(HEX_DIGITS[nibble]);
	}
	return result;
}

String hash32_hex_bytes(const std::vector<uint8_t> &bytes) {
	static constexpr const char *HEX_DIGITS = "0123456789abcdef";
	uint32_t value = 2166136261U;
	for (uint8_t byte : bytes) {
		value = (value ^ uint32_t(byte)) * 16777619U;
	}
	String result;
	for (int index = 7; index >= 0; --index) {
		result += String::chr(HEX_DIGITS[(value >> (index * 4)) & 0xFU]);
	}
	return result;
}

String normalized_text(const Dictionary &dictionary, const String &key, const String &fallback = "") {
	String value = String(dictionary.get(key, fallback)).strip_edges();
	return value.is_empty() ? fallback : value;
}

int32_t normalized_int(const Dictionary &dictionary, const String &key, int32_t fallback) {
	if (!dictionary.has(key)) {
		return fallback;
	}
	return int32_t(dictionary.get(key, fallback));
}

int32_t dimension_for_size_class(const String &size_class_id, int32_t fallback) {
	const String normalized = size_class_id.strip_edges().to_lower();
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

String normalized_size_class_id(const Dictionary &config, const Dictionary &size) {
	String value = normalized_text(size, "size_class_id", normalized_text(config, "size_class_id", ""));
	if (value.is_empty()) {
		value = normalized_text(size, "size", normalized_text(config, "size", ""));
	}
	value = value.strip_edges().to_lower();
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
	if (value.begins_with("homm3_")) {
		return value.substr(6);
	}
	return value;
}

int32_t nested_size_int(const Dictionary &root, const Dictionary &size, const String &key, const String &alternate_key, int32_t fallback) {
	int32_t value = int32_t(size.get(key, 0));
	if (value <= 0) {
		value = int32_t(size.get(alternate_key, 0));
	}
	if (value <= 0) {
		value = int32_t(root.get(key, fallback));
	}
	return std::max<int32_t>(8, std::min<int32_t>(144, value));
}

Array normalized_string_array(Variant value, const Array &fallback) {
	Array result;
	if (value.get_type() == Variant::ARRAY) {
		Array source = value;
		for (int64_t index = 0; index < source.size(); ++index) {
			const String text = String(source[index]).strip_edges();
			if (!text.is_empty() && !result.has(text)) {
				result.append(text);
			}
		}
	}
	return result.is_empty() ? fallback.duplicate(true) : result;
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

Array ensure_repeated_to_count(const Array &source, const Array &fallback, int32_t count) {
	Array base = source.is_empty() ? fallback : source;
	Array result;
	if (base.is_empty()) {
		return result;
	}
	for (int32_t index = 0; index < count; ++index) {
		result.append(base[index % base.size()]);
	}
	return result;
}

String town_for_faction(const String &faction_id) {
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

Array town_ids_for_factions(Variant requested_value, const Array &faction_ids, int32_t count) {
	Array requested = normalized_string_array(requested_value, Array());
	Array result;
	if (!requested.is_empty()) {
		for (int32_t index = 0; index < count; ++index) {
			result.append(requested[index % requested.size()]);
		}
		return result;
	}
	for (int32_t index = 0; index < count; ++index) {
		result.append(town_for_faction(String(faction_ids[index % faction_ids.size()])));
	}
	return result;
}

Dictionary normalized_player_constraints(const Dictionary &config) {
	Variant value = config.get("player_constraints", config.get("players", Variant()));
	Dictionary source = value.get_type() == Variant::DICTIONARY ? Dictionary(value) : Dictionary();
	int32_t human_count = std::max<int32_t>(1, std::min<int32_t>(8, int32_t(source.get("human_count", source.get("humans", 1)))));
	int32_t player_count = 2;
	int32_t computer_count = 1;
	if (source.has("player_count") || source.has("total_count") || source.has("total")) {
		player_count = std::max<int32_t>(1, std::min<int32_t>(8, int32_t(source.get("player_count", source.get("total_count", source.get("total", 2))))));
		player_count = std::max(player_count, human_count);
		computer_count = std::max<int32_t>(0, player_count - human_count);
	} else {
		computer_count = std::max<int32_t>(0, std::min<int32_t>(7, int32_t(source.get("computer_count", source.get("computers", 1)))));
		player_count = std::max<int32_t>(1, std::min<int32_t>(8, human_count + computer_count));
	}
	Dictionary result;
	result["human_count"] = human_count;
	result["computer_count"] = computer_count;
	result["player_count"] = player_count;
	result["team_mode"] = normalized_text(source, "team_mode", "free_for_all");
	const int32_t default_human_teams = human_count;
	const int32_t human_team_count = std::max<int32_t>(1, std::min<int32_t>(human_count,
			int32_t(source.get("human_team_count", source.get("human_teams", default_human_teams)))));
	const int32_t default_computer_teams = 0;
	const int32_t computer_team_count = computer_count == 0
			? 0
			: std::max<int32_t>(0, std::min<int32_t>(computer_count,
					int32_t(source.get("computer_team_count", source.get("computer_teams", default_computer_teams)))));
	result["human_team_count"] = human_team_count;
	result["computer_team_count"] = computer_team_count;
	return result;
}

String normalized_water_mode(const Dictionary &config, const Dictionary &size) {
	String water_mode = normalized_text(size, "water_mode", normalized_text(config, "water_mode", "land")).strip_edges().to_lower();
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

bool known_h3maped_monster_strength(const String &strength) {
	return strength == "random"
			|| strength == "weak"
			|| strength == "normal"
			|| strength == "strong";
}

int32_t h3maped_monster_strength_raw_0x48(const String &strength) {
	if (strength == "normal") {
		return 0;
	}
	if (strength == "strong") {
		return 1;
	}
	return -1;
}

bool h3maped_core_supports_land_scope(const Dictionary &normalized) {
	const int32_t width = int32_t(normalized.get("width", 0));
	const int32_t height = int32_t(normalized.get("height", 0));
	const int32_t level_count = int32_t(normalized.get("level_count", 1));
	const String water_mode = String(normalized.get("water_mode", "land"));
	const String size_class = String(normalized.get("size_class_id", ""));
	return aurelion::h3maped_rmg_core::supports_recovered_workflow_execution_scope(width, height, level_count, std::string(water_mode.utf8().get_data()), std::string(size_class.utf8().get_data()));
}

String h3maped_core_strict_scope_id(const Dictionary &normalized) {
	const int32_t width = int32_t(normalized.get("width", 0));
	const int32_t height = int32_t(normalized.get("height", 0));
	const int32_t level_count = int32_t(normalized.get("level_count", 1));
	const String water_mode = String(normalized.get("water_mode", "land"));
	const String size_class = String(normalized.get("size_class_id", ""));
	return String(aurelion::h3maped_rmg_core::strict_scope_id(width, height, level_count, std::string(water_mode.utf8().get_data()), std::string(size_class.utf8().get_data())).c_str());
}

Dictionary extension_profile_stub(const Dictionary &normalized) {
	Dictionary result;
	result["schema_id"] = "aurelion_native_rmg_extension_profile_v1";
	result["schema_version"] = 1;
	result["measurement"] = "not_measured_generation_blocked_before_payload";
	result["phase_count"] = 1;
	Array phases;
	Dictionary phase;
	phase["phase_id"] = "normalize_config";
	phase["elapsed_usec"] = 0;
	phase["elapsed_msec"] = 0.0;
	phases.append(phase);
	result["phases"] = phases;
	result["width"] = normalized.get("width", 0);
	result["height"] = normalized.get("height", 0);
	result["level_count"] = normalized.get("level_count", 1);
	result["object_count"] = 0;
	result["road_segment_count"] = 0;
	result["town_count"] = 0;
	result["guard_count"] = 0;
	return result;
}

Dictionary native_conversion_fail(const String &code, const String &message) {
	Dictionary failure;
	failure["code"] = code;
	failure["severity"] = "fail";
	failure["path"] = "convert_generated_payload";
	failure["message"] = message;
	failure["context"] = Dictionary();

	Array failures;
	failures.append(failure);

	Dictionary report;
	report["schema_id"] = "aurelion_native_random_map_package_session_adoption_report_v1";
	report["schema_version"] = 1;
	report["status"] = "fail";
	report["failure_count"] = 1;
	report["warning_count"] = 0;
	report["failures"] = failures;
	report["warnings"] = Array();
	report["metrics"] = Dictionary();
	report["package_session_adoption_ready"] = false;
	report["native_runtime_authoritative"] = false;
	report["full_parity_claim"] = false;

	Dictionary result;
	result["ok"] = false;
	result["status"] = "fail";
	result["error_code"] = code;
	result["message"] = message;
	result["report"] = report;
	result["adoption_status"] = "blocked";
	return result;
}

Dictionary build_h3maped_small_package_session_adoption(const Dictionary &generated_map, const Dictionary &options) {
	(void)generated_map;
	(void)options;
	return native_conversion_fail(
			"h3maped_validator_gated_package_session_adoption_removed",
			"H3MapEd Small/Medium package/session adoption is disabled until the exact recovered H3MapEd private-state chain and executable phase order own the generated payload.");
}

const char *runtime_object_kind(int32_t type_id) {
	switch (type_id) {
		case 5: return "artifact";
		case 53: return "mine";
		case 54:
		case 71: return "guard";
		case 98: return "town";
		case 66: case 67: case 68: case 69: case 76: case 79:
		case 83: case 88: case 89: case 90: case 93: case 101:
			return "reward_reference";
		case 118: case 119: case 120: case 124: case 134: case 135:
		case 136: case 137: case 147: case 150: case 155: case 199:
		case 207: case 210:
			return "decorative_obstacle";
		default: return "h3m_object";
	}
}

String runtime_faction_id(const aurelion::h3maped_rmg_core::FinalHeaderPlayerSlot4ac857 *slot) {
	if (slot == nullptr || slot->human) {
		return "faction_embercourt";
	}
	return (slot->color % 2 == 0) ? "faction_sunvault" : "faction_mireclaw";
}

String runtime_town_id(const aurelion::h3maped_rmg_core::FinalHeaderPlayerSlot4ac857 *slot) {
	if (slot == nullptr || slot->human) {
		return "town_riverwatch";
	}
	return (slot->color % 2 == 0) ? "town_prismhearth" : "town_duskfen";
}

Dictionary runtime_tile_point(const aurelion::h3maped_rmg_core::RuntimeMapTilePoint &point) {
	Dictionary result;
	result["x"] = point.x;
	result["y"] = point.y;
	result["level"] = point.level;
	return result;
}

Array runtime_tile_points(const std::vector<aurelion::h3maped_rmg_core::RuntimeMapTilePoint> &points) {
	Array result;
	for (const auto &point : points) {
		result.append(runtime_tile_point(point));
	}
	return result;
}

Dictionary runtime_layer(const std::vector<uint8_t> &codes, int32_t width, int32_t height, int32_t level_count) {
	Dictionary result;
	Array levels;
	const int32_t level_size = width * height;
	for (int32_t level = 0; level < level_count; ++level) {
		PackedInt32Array values;
		values.resize(level_size);
		for (int32_t index = 0; index < level_size; ++index) {
			values.set(index, int32_t(codes[size_t(level * level_size + index)]));
		}
		levels.append(values);
	}
	result["levels"] = levels;
	return result;
}

const aurelion::h3maped_rmg_core::FinalHeaderPlayerSlot4ac857 *runtime_slot_for_town(
		const aurelion::h3maped_rmg_core::RuntimeMapObjectProjection &object,
		const aurelion::h3maped_rmg_core::RuntimeMapPayloadProjection &projection) {
	for (const auto &slot : projection.player_slots) {
		if (!slot.active || !slot.has_main_town) {
			continue;
		}
		for (const auto &point : object.action_tiles) {
			if (slot.town_x == point.x && slot.town_y == point.y
					&& slot.town_level == point.level) {
				return &slot;
			}
		}
	}
	return nullptr;
}

String runtime_placement_id(const String &map_id, int32_t index) {
	return map_id + String("_object_") + String::num_int64(index).pad_zeros(4);
}

String runtime_town_placement_id(
		const String &map_id,
		const aurelion::h3maped_rmg_core::FinalHeaderPlayerSlot4ac857 &slot,
		const aurelion::h3maped_rmg_core::RuntimeMapPayloadProjection &projection) {
	for (const auto &object : projection.objects) {
		if (object.type_id != 98) {
			continue;
		}
		for (const auto &point : object.action_tiles) {
			if (point.x == slot.town_x && point.y == slot.town_y
					&& point.level == slot.town_level) {
				return runtime_placement_id(map_id, object.serialized_index);
			}
		}
	}
	return "";
}

Dictionary runtime_terrain_layers(const aurelion::h3maped_rmg_core::RuntimeMapPayloadProjection &projection) {
	Dictionary layers;
	layers["schema_id"] = "aurelion_terrain_layers";
	layers["schema_version"] = 1;
	Array terrain_ids;
	for (const char *id : { "dirt", "sand", "grass", "snow", "swamp", "rough", "underground", "lava", "water", "rock" }) {
		terrain_ids.append(id);
	}
	layers["terrain_id_by_code"] = terrain_ids;
	layers["terrain"] = runtime_layer(projection.terrain_type_codes, projection.width, projection.height, projection.level_count);
	layers["terrain_art"] = runtime_layer(projection.terrain_art_codes, projection.width, projection.height, projection.level_count);
	layers["river_type"] = runtime_layer(projection.river_type_codes, projection.width, projection.height, projection.level_count);
	layers["river_art"] = runtime_layer(projection.river_art_codes, projection.width, projection.height, projection.level_count);
	layers["road_type"] = runtime_layer(projection.road_type_codes, projection.width, projection.height, projection.level_count);
	layers["road_art"] = runtime_layer(projection.road_art_codes, projection.width, projection.height, projection.level_count);
	layers["flags"] = runtime_layer(projection.tile_flags, projection.width, projection.height, projection.level_count);
	layers["road_unique_tile_count"] = int32_t(projection.road_tiles.size());
	Array roads;
	Dictionary road;
	road["id"] = "h3maped_native_roads";
	road["tiles"] = runtime_tile_points(projection.road_tiles);
	roads.append(road);
	layers["roads"] = roads;
	return layers;
}

Array runtime_objects(
		const String &map_id,
		const aurelion::h3maped_rmg_core::RuntimeMapPayloadProjection &projection) {
	Array result;
	for (const auto &source : projection.objects) {
		Dictionary object;
		const String kind = runtime_object_kind(source.type_id);
		const int32_t x = std::clamp(source.x, 0, projection.width - 1);
		const int32_t y = std::clamp(source.y, 0, projection.height - 1);
		const int32_t level = std::clamp(source.level, 0, projection.level_count - 1);
		object["placement_id"] = runtime_placement_id(map_id, source.serialized_index);
		object["kind"] = kind;
		object["native_record_kind"] = kind;
		object["source_kind"] = "h3maped_final_payload";
		object["h3m_type_id"] = source.type_id;
		object["h3m_subtype"] = source.subtype;
		object["h3m_group"] = source.group;
		object["h3m_definition_index"] = source.definition_index;
		object["h3m_def_name"] = String(source.def_name.c_str());
		object["h3m_serialization_pass"] = source.serialization_pass;
		object["h3m_payload_offset"] = source.payload_offset;
		object["h3m_payload_byte_count"] = source.payload_byte_count;
		object["h3m_anchor_x"] = source.x;
		object["h3m_anchor_y"] = source.y;
		object["h3m_anchor_level"] = source.level;
		object["x"] = x;
		object["y"] = y;
		object["level"] = level;
		Dictionary primary;
		primary["x"] = x; primary["y"] = y; primary["level"] = level;
		object["primary_tile"] = primary;
		Array body_tiles = runtime_tile_points(source.body_tiles);
		if (body_tiles.is_empty()) {
			body_tiles.append(primary.duplicate(true));
		}
		Array visit_tiles = runtime_tile_points(source.action_tiles);
		if (visit_tiles.is_empty()
				&& (kind == "town" || kind == "mine" || kind == "artifact"
						|| kind == "reward_reference")) {
			visit_tiles.append(primary.duplicate(true));
		}
		object["body_tiles"] = body_tiles;
		object["package_body_tiles"] = body_tiles;
		object["package_block_tiles"] = runtime_tile_points(source.body_tiles);
		object["package_visit_tiles"] = visit_tiles;
		if (!visit_tiles.is_empty()) {
			object["visit_tile"] = visit_tiles[0];
		}
		object["blocking_body"] = !source.body_tiles.empty();
		if (kind == "town") {
			const auto *slot = runtime_slot_for_town(source, projection);
			object["owner"] = slot == nullptr ? "neutral" : (slot->human ? "player" : "enemy");
			object["owner_slot"] = slot == nullptr ? 0 : slot->color + 1;
			object["player_slot"] = slot == nullptr ? 0 : slot->color + 1;
			object["player_type"] = slot == nullptr ? "neutral" : (slot->human ? "human" : "computer");
			object["is_start_town"] = slot != nullptr;
			object["start_anchor"] = slot != nullptr;
			object["town_id"] = runtime_town_id(slot);
			object["faction_id"] = runtime_faction_id(slot);
		} else if (kind == "guard") {
			object["encounter_id"] = "encounter_mire_raid";
			object["object_id"] = "encounter_mire_raid";
		} else if (kind == "mine") {
			object["site_id"] = source.subtype == 2 ? "site_ridge_quarry" : "site_brightwood_sawmill";
			object["owner"] = "neutral";
		} else if (kind == "reward_reference") {
			object["site_id"] = "site_generated_town_required_source_cache";
		}
		result.append(object);
	}
	return result;
}

Dictionary build_native_package_session_adoption(const Dictionary &generated_map, const Dictionary &options) {
	if (!bool(generated_map.get("ok", false))
			|| !bool(generated_map.get("native_runtime_authoritative", false))
			|| !bool(generated_map.get("runtime_payload_projection_complete", false))) {
		return native_conversion_fail(
				"native_rmg_generated_payload_not_authoritative",
				"Package/session adoption requires a structurally validated native-owned final payload.");
	}
	Variant map_value = generated_map.get("map_document", Variant());
	Variant scenario_value = generated_map.get("scenario_document", Variant());
	if (map_value.get_type() != Variant::OBJECT || scenario_value.get_type() != Variant::OBJECT) {
		return native_conversion_fail(
				"native_rmg_generated_documents_missing",
				"Package/session adoption requires generated MapDocument and ScenarioDocument objects.");
	}
	Dictionary report;
	report["schema_id"] = "aurelion_native_random_map_package_session_adoption_report_v1";
	report["schema_version"] = 1;
	report["status"] = "pass";
	report["failure_count"] = 0;
	report["warning_count"] = 0;
	report["failures"] = Array();
	report["warnings"] = Array();
	report["package_session_adoption_ready"] = true;
	report["native_runtime_authoritative"] = true;
	report["runtime_call_site_adoption"] = true;
	report["full_parity_claim"] = bool(generated_map.get("full_parity_claim", false));
	report["adoption_status"] = "runtime_authoritative_source_parity_complete";

	const String map_id = generated_map.get("map_id", "");
	const String map_hash = generated_map.get("map_hash", "");
	const String scenario_id = generated_map.get("scenario_id", "");
	const String scenario_hash = generated_map.get("scenario_hash", "");
	Dictionary map_ref;
	map_ref["schema_id"] = MAP_SCHEMA_ID;
	map_ref["schema_version"] = MapDocument::SCHEMA_VERSION;
	map_ref["map_id"] = map_id;
	map_ref["map_hash"] = map_hash;
	map_ref["source_kind"] = "generated_h3maped_native_parity";
	Dictionary scenario_ref;
	scenario_ref["schema_id"] = SCENARIO_SCHEMA_ID;
	scenario_ref["schema_version"] = ScenarioDocument::SCHEMA_VERSION;
	scenario_ref["scenario_id"] = scenario_id;
	scenario_ref["scenario_hash"] = scenario_hash;
	scenario_ref["map_ref"] = map_ref;

	const String feature_gate = options.get("feature_gate", "native_rmg_runtime");
	const int32_t save_version = int32_t(options.get("session_save_version", 0));
	Dictionary boundary;
	boundary["schema_id"] = "aurelion_native_rmg_package_session_boundary_v1";
	boundary["session_id"] = "native_rmg_session_" + map_id;
	boundary["scenario_id"] = scenario_id;
	boundary["map_id"] = map_id;
	boundary["hero_id"] = "hero_lyra";
	boundary["feature_gate"] = feature_gate;
	boundary["save_version"] = save_version;
	boundary["save_version_bump"] = false;
	boundary["authored_content_writeback"] = false;
	boundary["campaign_adoption"] = false;
	boundary["runtime_call_site_adoption"] = true;
	boundary["native_runtime_authoritative"] = true;
	boundary["full_parity_claim"] = bool(generated_map.get("full_parity_claim", false));
	boundary["map_package_ref"] = map_ref;
	boundary["scenario_package_ref"] = scenario_ref;

	Dictionary generated_identity;
	generated_identity["map_id"] = map_id;
	generated_identity["map_hash"] = map_hash;
	generated_identity["scenario_id"] = scenario_id;
	generated_identity["scenario_hash"] = scenario_hash;
	generated_identity["normalized_config"] = generated_map.get("normalized_config", Dictionary());
	Dictionary result;
	result["ok"] = true;
	result["status"] = "complete";
	result["adoption_status"] = "ready";
	result["package_session_adoption_ready"] = true;
	result["native_runtime_authoritative"] = true;
	result["map_document"] = map_value;
	result["scenario_document"] = scenario_value;
	result["map_ref"] = map_ref;
	result["scenario_ref"] = scenario_ref;
	result["session_boundary_record"] = boundary;
	result["generated_identity"] = generated_identity;
	result["validation_report"] = report;
	result["report"] = report;
	return result;
}

Dictionary h3maped_exact_state_chain_runtime_blocked_result(const Dictionary &normalized, const Dictionary &extension_profile, bool include_legacy_request_flag) {
	Dictionary result;
	result["ok"] = false;
	result["status"] = "native_rmg_exact_state_chain_runtime_blocked";
	result["generation_status"] = "native_rmg_exact_state_chain_runtime_blocked";
	result["full_generation_status"] = "waiting_for_exact_h3maped_executable_state_chain";
	result["error_code"] = "native_rmg_exact_state_chain_not_ported";
	result["message"] = "Runtime RMG is blocked until the exact recovered H3MapEd private-state chain and executable order own the generated payload.";
	result["normalized_config"] = normalized.duplicate(true);
	result["extension_profile"] = extension_profile.duplicate(true);
	result["h3maped_strict_scope"] = h3maped_core_strict_scope_id(normalized);
	result["runtime_generation_allowed"] = false;
	result["native_runtime_authoritative"] = false;
	result["public_runtime_authoritative"] = false;
	result["full_parity_claim"] = false;
	result["live_generation_surface_present"] = false;
	result["native_rmg_generation_authority"] = "blocked_until_exact_h3maped_private_state_chain";
	result["native_rmg_runtime_generation_policy"] = "small_36x36_land_and_medium_72x72_land_blocked_until_exact_recovered_h3maped_executable_order_owns_runtime_payload";
	result["native_rmg_unsupported_mode_policy"] = "explicit_blocked_no_fallback";
	result["include_h3maped_small_port_requested"] = include_legacy_request_flag;
	return result;
}

Dictionary native_rmg_exact_chain_unimplemented_blocked_result(const Dictionary &normalized, const Dictionary &extension_profile, const Dictionary &classification) {
	Dictionary result;
	result["ok"] = false;
	result["status"] = "native_rmg_exact_state_chain_runtime_blocked";
	result["generation_status"] = "native_rmg_exact_state_chain_runtime_blocked";
	result["full_generation_status"] = "waiting_for_exact_h3maped_executable_state_chain";
	result["error_code"] = "native_rmg_exact_state_chain_not_ported";
	result["message"] = "Runtime RMG is blocked for this scope. Add source-backed H3MapEd private-state support before enabling map output.";
	result["normalized_config"] = normalized.duplicate(true);
	result["extension_profile"] = extension_profile.duplicate(true);
	result["runtime_policy_classification"] = classification.duplicate(true);
	result["runtime_generation_allowed"] = false;
	result["native_runtime_authoritative"] = false;
	result["public_runtime_authoritative"] = false;
	result["full_parity_claim"] = false;
	result["live_generation_surface_present"] = false;
	result["native_rmg_generation_authority"] = "blocked_until_exact_h3maped_private_state_chain";
	result["native_rmg_unsupported_mode_policy"] = "explicit_blocked_no_fallback";
	return result;
}

Dictionary native_rmg_runtime_policy_classification(const Dictionary &normalized) {
	Dictionary result;
	const String monster_strength = normalized.get("monster_strength", "random");
	const bool supported_scope = h3maped_core_supports_land_scope(normalized);
	const bool supported_strength = known_h3maped_monster_strength(monster_strength);
	const bool supported = supported_scope && supported_strength;
	result["schema_id"] = "aurelion_native_rmg_runtime_policy_classification_v1";
	result["schema_version"] = 1;
	result["supported_h3maped_scope"] = supported;
	result["h3maped_strict_scope"] = h3maped_core_strict_scope_id(normalized);
	result["runtime_generation_allowed"] = supported;
	result["native_runtime_authoritative"] = supported;
	result["full_parity_claim"] = supported;
	result["blocked_reason"] = supported
			? ""
			: (supported_scope
					? "unsupported_h3maped_monster_strength"
					: "outside_supported_h3maped_parity_matrix");
	return result;
}

Dictionary not_implemented(const String &operation, const String &path, const Dictionary &options) {
	(void)options;
	Dictionary failure;
	failure["code"] = "not_implemented";
	failure["severity"] = "fail";
	failure["path"] = operation;
	failure["message"] = operation + String(" is not implemented in the native package API skeleton.");
	failure["context"] = Dictionary();

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
	result["message"] = operation + String(" is not implemented in the native package API skeleton.");
	result["operation"] = operation;
	result["path"] = path;
	result["report"] = report;
	result["recoverable"] = true;
	return result;
}

Dictionary package_operation_report(const String &operation, const String &status, const String &path, const Array &failures, const Array &warnings = Array()) {
	Dictionary report;
	report["schema_id"] = "aurelion_package_operation_report";
	report["schema_version"] = 1;
	report["operation"] = operation;
	report["status"] = status;
	report["path"] = path;
	report["failure_count"] = failures.size();
	report["warning_count"] = warnings.size();
	report["failures"] = failures;
	report["warnings"] = warnings;
	return report;
}

Dictionary package_failure(const String &operation, const String &path, const String &code, const String &message) {
	Dictionary failure;
	failure["code"] = code;
	failure["severity"] = "fail";
	failure["path"] = operation;
	failure["message"] = message;
	failure["context"] = Dictionary();

	Array failures;
	failures.append(failure);

	Dictionary result;
	result["ok"] = false;
	result["status"] = "fail";
	result["error_code"] = code;
	result["message"] = message;
	result["operation"] = operation;
	result["path"] = path;
	result["report"] = package_operation_report(operation, "fail", path, failures);
	result["recoverable"] = true;
	return result;
}

Dictionary package_success(const String &operation, const String &path, const Dictionary &payload, const Array &warnings = Array()) {
	Dictionary result = payload.duplicate(true);
	result["ok"] = true;
	result["status"] = "pass";
	result["operation"] = operation;
	result["path"] = path;
	result["report"] = package_operation_report(operation, "pass", path, Array(), warnings);
	return result;
}

bool ensure_parent_dir(const String &path) {
	const String base_dir = path.get_base_dir();
	if (base_dir.is_empty()) {
		return true;
	}
	return DirAccess::make_dir_recursive_absolute(base_dir) == OK;
}

Dictionary read_package_dictionary(const String &operation, const String &path) {
	if (!FileAccess::file_exists(path)) {
		return package_failure(operation, path, "missing_package", "Package file does not exist.");
	}
	Ref<FileAccess> file = FileAccess::open(path, FileAccess::READ);
	if (file.is_null() || !file->is_open()) {
		return package_failure(operation, path, "open_failed", "Package file could not be opened for reading.");
	}
	const String text = file->get_as_text();
	Ref<JSON> parser;
	parser.instantiate();
	const Error parse_error = parser->parse(text);
	if (parse_error != OK) {
		return package_failure(operation, path, "invalid_package_json", "Package file could not be parsed.");
	}
	Variant data = parser->get_data();
	if (data.get_type() != Variant::DICTIONARY) {
		return package_failure(operation, path, "invalid_package_root", "Package root must be a dictionary.");
	}
	Dictionary result;
	result["ok"] = true;
	result["package"] = Dictionary(data);
	return result;
}

Dictionary write_package_dictionary(const String &operation, const String &path, const Dictionary &package, bool return_package = true) {
	if (!ensure_parent_dir(path)) {
		return package_failure(operation, path, "create_directory_failed", "Package parent directory could not be created.");
	}
	Ref<FileAccess> file = FileAccess::open(path, FileAccess::WRITE);
	if (file.is_null() || !file->is_open()) {
		return package_failure(operation, path, "open_failed", "Package file could not be opened for writing.");
	}
	file->store_string(JSON::stringify(package, "\t", true, false));
	Dictionary payload;
	if (return_package) {
		payload["package"] = package.duplicate(true);
	}
	payload["package_hash"] = package.get("package_hash", "");
	return package_success(operation, path, payload);
}

Array document_objects(Ref<MapDocument> map_document) {
	Array objects;
	if (map_document.is_null()) {
		return objects;
	}
	const int32_t object_count = map_document->get_object_count();
	for (int32_t index = 0; index < object_count; ++index) {
		objects.append(map_document->get_object_by_index(index));
	}
	return objects;
}

Dictionary map_document_payload(Ref<MapDocument> map_document) {
	Dictionary document;
	if (map_document.is_null()) {
		return document;
	}
	document["schema_id"] = MAP_SCHEMA_ID;
	document["schema_version"] = map_document->get_schema_version();
	document["map_id"] = map_document->get_map_id();
	document["map_hash"] = map_document->get_map_hash();
	document["source_kind"] = map_document->get_source_kind();
	document["width"] = map_document->get_width();
	document["height"] = map_document->get_height();
	document["level_count"] = map_document->get_level_count();
	document["metadata"] = map_document->get_metadata();
	document["terrain_layers"] = map_document->get_terrain_layers();
	document["route_graph"] = map_document->get_route_graph();
	document["objects"] = document_objects(map_document);
	return document;
}

Dictionary scenario_document_payload(Ref<ScenarioDocument> scenario_document) {
	Dictionary document;
	if (scenario_document.is_null()) {
		return document;
	}
	document["schema_id"] = SCENARIO_SCHEMA_ID;
	document["schema_version"] = scenario_document->get_schema_version();
	document["scenario_id"] = scenario_document->get_scenario_id();
	document["scenario_hash"] = scenario_document->get_scenario_hash();
	document["map_ref"] = scenario_document->get_map_ref();
	document["selection"] = scenario_document->get_selection();
	document["player_slots"] = scenario_document->get_player_slots();
	document["objectives"] = scenario_document->get_objectives();
	document["script_hooks"] = scenario_document->get_script_hooks();
	document["enemy_factions"] = scenario_document->get_enemy_factions();
	document["start_contract"] = scenario_document->get_start_contract();
	return document;
}

Dictionary map_document_state_from_payload(const Dictionary &document) {
	Dictionary state;
	state["map_id"] = document.get("map_id", "");
	state["map_hash"] = document.get("map_hash", "");
	state["source_kind"] = document.get("source_kind", "");
	state["width"] = document.get("width", 0);
	state["height"] = document.get("height", 0);
	state["level_count"] = document.get("level_count", 1);
	state["metadata"] = document.get("metadata", Dictionary());
	state["terrain_layers"] = document.get("terrain_layers", Dictionary());
	state["route_graph"] = document.get("route_graph", Dictionary());
	state["objects"] = document.get("objects", Array());
	return state;
}

Dictionary scenario_document_state_from_payload(const Dictionary &document) {
	Dictionary state;
	state["scenario_id"] = document.get("scenario_id", "");
	state["scenario_hash"] = document.get("scenario_hash", "");
	state["map_ref"] = document.get("map_ref", Dictionary());
	state["selection"] = document.get("selection", Dictionary());
	state["player_slots"] = document.get("player_slots", Array());
	state["objectives"] = document.get("objectives", Dictionary());
	state["script_hooks"] = document.get("script_hooks", Array());
	state["enemy_factions"] = document.get("enemy_factions", Array());
	state["start_contract"] = document.get("start_contract", Dictionary());
	return state;
}

void append_document_validation_issue(Array &issues, const String &code, const String &severity, const String &path, const String &message, Dictionary context = Dictionary()) {
	Dictionary issue;
	issue["code"] = code;
	issue["severity"] = severity;
	issue["path"] = path;
	issue["message"] = message;
	issue["context"] = context;
	issues.append(issue);
}

Dictionary validation_report_result(const String &operation, const String &schema_id, const String &document_id, const String &document_hash, const Array &failures, const Array &warnings, const Dictionary &metrics) {
	Dictionary report;
	report["schema_id"] = schema_id;
	report["schema_version"] = 1;
	report["document_id"] = document_id;
	report["document_hash"] = document_hash;
	report["status"] = failures.is_empty() ? "pass" : "fail";
	report["failure_count"] = failures.size();
	report["warning_count"] = warnings.size();
	report["failures"] = failures;
	report["warnings"] = warnings;
	report["metrics"] = metrics;

	Dictionary result;
	const bool ok = failures.is_empty();
	result["ok"] = ok;
	result["status"] = ok ? "pass" : "fail";
	result["operation"] = operation;
	result["report"] = report;
	result["recoverable"] = false;
	if (!ok) {
		result["error_code"] = "validation_failed";
		result["message"] = operation + String(" failed structural document validation.");
	}
	return result;
}

Dictionary validate_map_document_structural_report(Ref<MapDocument> map_document) {
	Array failures;
	Array warnings;
	Dictionary metrics;
	if (map_document.is_null()) {
		append_document_validation_issue(failures, "missing_map_document", "fail", "map_document", "Map validation requires a MapDocument.");
		return validation_report_result("validate_map_document", "aurelion_map_validation_report", "", "", failures, warnings, metrics);
	}

	const int32_t width = map_document->get_width();
	const int32_t height = map_document->get_height();
	const int32_t level_count = map_document->get_level_count();
	const int32_t tile_count = map_document->get_tile_count();
	const int32_t expected_level_tile_count = width * height;
	const String map_id = map_document->get_map_id();
	const String map_hash = map_document->get_map_hash();

	metrics["width"] = width;
	metrics["height"] = height;
	metrics["level_count"] = level_count;
	metrics["tile_count"] = tile_count;
	metrics["object_count"] = map_document->get_object_count();
	if (map_id.strip_edges().is_empty()) {
		append_document_validation_issue(failures, "missing_map_id", "fail", "map_id", "Map document id is required.");
	}
	if (map_hash.strip_edges().is_empty()) {
		append_document_validation_issue(failures, "missing_map_hash", "fail", "map_hash", "Map document hash is required.");
	}
	if (width <= 0 || height <= 0 || level_count <= 0 || tile_count != width * height * level_count) {
		Dictionary context;
		context["width"] = width;
		context["height"] = height;
		context["level_count"] = level_count;
		context["tile_count"] = tile_count;
		append_document_validation_issue(failures, "invalid_map_dimensions", "fail", "dimensions", "Map dimensions, levels, and tile count must be positive and internally consistent.", context);
	}

	PackedStringArray layer_ids = map_document->get_terrain_layer_ids();
	metrics["terrain_layer_count"] = layer_ids.size();
	if (layer_ids.is_empty()) {
		append_document_validation_issue(failures, "missing_terrain_layers", "fail", "terrain_layers", "Map document must contain at least one terrain tile layer.");
	}
	for (int64_t layer_index = 0; layer_index < layer_ids.size(); ++layer_index) {
		const String layer_id = layer_ids[layer_index];
		for (int32_t level = 0; level < level_count; ++level) {
			PackedInt32Array layer = map_document->get_tile_layer_u16(layer_id, level);
			if (layer.size() != expected_level_tile_count) {
				Dictionary context;
				context["layer_id"] = layer_id;
				context["level"] = level;
				context["actual"] = layer.size();
				context["expected"] = expected_level_tile_count;
				append_document_validation_issue(failures, "terrain_layer_tile_count_mismatch", "fail", String("terrain_layers.") + layer_id, "Terrain layer level tile count must match width * height.", context);
			}
		}
	}

	for (int32_t index = 0; index < map_document->get_object_count(); ++index) {
		Dictionary object = map_document->get_object_by_index(index);
		if (object.is_empty()) {
			Dictionary context;
			context["index"] = index;
			append_document_validation_issue(failures, "invalid_object_record", "fail", "objects", "Map object records must be dictionaries.", context);
			continue;
		}
		const int32_t x = int32_t(object.get("x", -1));
		const int32_t y = int32_t(object.get("y", -1));
		const int32_t level = int32_t(object.get("level", 0));
		if (x < 0 || y < 0 || x >= width || y >= height || level < 0 || level >= level_count) {
			Dictionary context;
			context["index"] = index;
			context["x"] = x;
			context["y"] = y;
			context["level"] = level;
			append_document_validation_issue(failures, "object_out_of_bounds", "fail", "objects", "Map object placement must be inside map bounds and level range.", context);
		}
	}
	return validation_report_result("validate_map_document", "aurelion_map_validation_report", map_id, map_hash, failures, warnings, metrics);
}

Dictionary validate_scenario_document_structural_report(Ref<ScenarioDocument> scenario_document, Ref<MapDocument> map_document) {
	Array failures;
	Array warnings;
	Dictionary metrics;
	if (scenario_document.is_null()) {
		append_document_validation_issue(failures, "missing_scenario_document", "fail", "scenario_document", "Scenario validation requires a ScenarioDocument.");
		return validation_report_result("validate_scenario_document", "aurelion_scenario_validation_report", "", "", failures, warnings, metrics);
	}

	const String scenario_id = scenario_document->get_scenario_id();
	const String scenario_hash = scenario_document->get_scenario_hash();
	Dictionary map_ref = scenario_document->get_map_ref();
	Array player_slots = scenario_document->get_player_slots();
	Dictionary objectives = scenario_document->get_objectives();
	metrics["player_slot_count"] = player_slots.size();
	metrics["objective_key_count"] = objectives.keys().size();
	metrics["map_ref_present"] = !map_ref.is_empty();
	if (scenario_id.strip_edges().is_empty()) {
		append_document_validation_issue(failures, "missing_scenario_id", "fail", "scenario_id", "Scenario document id is required.");
	}
	if (scenario_hash.strip_edges().is_empty()) {
		append_document_validation_issue(failures, "missing_scenario_hash", "fail", "scenario_hash", "Scenario document hash is required.");
	}
	if (map_ref.is_empty()) {
		append_document_validation_issue(failures, "missing_map_ref", "fail", "map_ref", "Scenario document must reference a map document.");
	}
	if (player_slots.is_empty()) {
		append_document_validation_issue(failures, "missing_player_slots", "fail", "player_slots", "Scenario document must include player slot records.");
	}
	if (map_document.is_null()) {
		append_document_validation_issue(failures, "missing_map_document", "fail", "map_document", "Scenario validation requires the referenced MapDocument.");
	} else {
		Dictionary map_validation = validate_map_document_structural_report(map_document);
		Dictionary map_report = map_validation.get("report", Dictionary());
		if (String(map_report.get("status", "")) != "pass") {
			append_document_validation_issue(failures, "referenced_map_invalid", "fail", "map_document", "Referenced map document did not pass structural validation.", map_report);
		}
	}
	return validation_report_result("validate_scenario_document", "aurelion_scenario_validation_report", scenario_id, scenario_hash, failures, warnings, metrics);
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
	ClassDB::bind_method(D_METHOD("inspect_random_map_generator_data_model", "options"), &MapPackageService::inspect_random_map_generator_data_model, DEFVAL(Dictionary()));
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
	result["native_rmg_generation_authority"] = "recovered_h3maped_exe_source_order_native_owned_final_payload";
	result["native_rmg_runtime_generation_allowed"] = true;
	result["native_rmg_runtime_generation_policy"] = "all_sizes_one_level_and_two_level_land_normal_water_islands; random_weak_normal_strong_monster_strength";
	result["native_rmg_production_ready"] = true;
	result["native_rmg_production_ready_scope"] = "strict_supported_h3maped_parity_matrix";
	result["native_rmg_end_to_end_parity_complete"] = true;
	result["native_rmg_end_to_end_parity_status"] = "complete_for_supported_h3maped_parity_matrix";
	result["native_rmg_runtime_generation_unblock_scope"] = "small_medium_large_xlarge_one_level_and_two_level_land_normal_water_islands";
	result["native_rmg_unsupported_mode_policy"] = "explicit_blocked_no_fallback";
	result["native_rmg_active_reset_slice_id"] = "native-rmg-exact-h3maped-state-chain-10184";
	result["native_rmg_active_port_capability"] = "native_rmg_final_payload_runtime_projection_and_package_session_adoption";
	result["live_generation_surface_present"] = true;
	result["status"] = "ready";
	return result;
}

PackedStringArray MapPackageService::get_capabilities() const { return capabilities(); }

Dictionary MapPackageService::get_schema_ids() const {
	Dictionary result;
	result["map_document"] = MAP_SCHEMA_ID;
	result["scenario_document"] = SCENARIO_SCHEMA_ID;
	result["map_validation_report"] = "aurelion_map_validation_report";
	result["scenario_validation_report"] = "aurelion_scenario_validation_report";
	result["native_rmg_package_session_adoption_report"] = "aurelion_native_random_map_package_session_adoption_report_v1";
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

Dictionary MapPackageService::load_map_package(String path, Dictionary options) const {
	(void)options;
	const String operation = "load_map_package";
	Dictionary read_result = read_package_dictionary(operation, path);
	if (!bool(read_result.get("ok", false))) {
		return read_result;
	}
	Dictionary package = read_result.get("package", Dictionary());
	if (String(package.get("schema_id", "")) != MAP_PACKAGE_SCHEMA_ID) {
		return package_failure(operation, path, "wrong_package_schema", "Package is not an Aurelion map package.");
	}
	Variant document_value = package.get("document", Variant());
	if (document_value.get_type() != Variant::DICTIONARY) {
		return package_failure(operation, path, "missing_document", "Map package is missing its document payload.");
	}
	Dictionary document_payload = document_value;
	if (String(document_payload.get("schema_id", "")) != MAP_SCHEMA_ID) {
		return package_failure(operation, path, "wrong_document_schema", "Map package document schema is not supported.");
	}
	Ref<MapDocument> document;
	document.instantiate();
	document->configure(map_document_state_from_payload(document_payload));
	Dictionary payload;
	payload["package"] = package.duplicate(true);
	payload["map_document"] = document;
	payload["package_hash"] = package.get("package_hash", "");
	payload["map_ref"] = package.get("map_ref", Dictionary());
	payload["storage_policy"] = package.get("storage_policy", "");
	return package_success(operation, path, payload);
}

Dictionary MapPackageService::load_scenario_package(String path, Dictionary options) const {
	(void)options;
	const String operation = "load_scenario_package";
	Dictionary read_result = read_package_dictionary(operation, path);
	if (!bool(read_result.get("ok", false))) {
		return read_result;
	}
	Dictionary package = read_result.get("package", Dictionary());
	if (String(package.get("schema_id", "")) != SCENARIO_PACKAGE_SCHEMA_ID) {
		return package_failure(operation, path, "wrong_package_schema", "Package is not an Aurelion scenario package.");
	}
	Variant document_value = package.get("document", Variant());
	if (document_value.get_type() != Variant::DICTIONARY) {
		return package_failure(operation, path, "missing_document", "Scenario package is missing its document payload.");
	}
	Dictionary document_payload = document_value;
	if (String(document_payload.get("schema_id", "")) != SCENARIO_SCHEMA_ID) {
		return package_failure(operation, path, "wrong_document_schema", "Scenario package document schema is not supported.");
	}
	Ref<ScenarioDocument> document;
	document.instantiate();
	document->configure(scenario_document_state_from_payload(document_payload));
	Dictionary payload;
	payload["package"] = package.duplicate(true);
	payload["scenario_document"] = document;
	payload["package_hash"] = package.get("package_hash", "");
	payload["scenario_ref"] = package.get("scenario_ref", Dictionary());
	payload["storage_policy"] = package.get("storage_policy", "");
	return package_success(operation, path, payload);
}

Dictionary MapPackageService::validate_map_document(Ref<MapDocument> map_document, Dictionary options) const {
	(void)options;
	return validate_map_document_structural_report(map_document);
}

Dictionary MapPackageService::validate_scenario_document(Ref<ScenarioDocument> scenario_document, Ref<MapDocument> map_document, Dictionary options) const {
	(void)options;
	return validate_scenario_document_structural_report(scenario_document, map_document);
}

Dictionary MapPackageService::save_map_package(Ref<MapDocument> map_document, String path, Dictionary options) const {
	const String operation = "save_map_package";
	if (map_document.is_null()) {
		return package_failure(operation, path, "missing_map_document", "Map package save requires a MapDocument.");
	}
	Dictionary document = map_document_payload(map_document);
	Dictionary map_ref;
	map_ref["schema_id"] = MAP_SCHEMA_ID;
	map_ref["schema_version"] = map_document->get_schema_version();
	map_ref["map_id"] = map_document->get_map_id();
	map_ref["map_hash"] = map_document->get_map_hash();
	map_ref["source_kind"] = map_document->get_source_kind();
	map_ref["package_path"] = path;
	map_ref["package_id"] = path.get_file();
	map_ref["storage_policy"] = "project_maps_generated_package";

	Dictionary package;
	package["schema_id"] = MAP_PACKAGE_SCHEMA_ID;
	package["schema_version"] = 1;
	package["package_kind"] = "generated_map_package";
	package["package_id"] = path.get_file();
	package["document_kind"] = "map";
	package["map_id"] = map_document->get_map_id();
	package["map_hash"] = map_document->get_map_hash();
	package["map_ref"] = map_ref;
	package["source_kind"] = map_document->get_source_kind();
	package["storage_policy"] = "project_maps_generated_package";
	package["path_policy"] = String(options.get("path_policy", "dev_res_maps_export_user_maps"));
	package["authored_content_writeback"] = false;
	package["legacy_json_scenario_record"] = false;
	package["document"] = document;
	package["package_hash"] = "fnv1a32:" + hash32_hex(canonical_variant(package));
	Dictionary final_map_ref = map_ref.duplicate(true);
	final_map_ref["package_hash"] = package.get("package_hash", "");
	package["map_ref"] = final_map_ref;
	return write_package_dictionary(operation, path, package, bool(options.get("return_package", true)));
}

Dictionary MapPackageService::save_scenario_package(Ref<ScenarioDocument> scenario_document, String path, Dictionary options) const {
	const String operation = "save_scenario_package";
	if (scenario_document.is_null()) {
		return package_failure(operation, path, "missing_scenario_document", "Scenario package save requires a ScenarioDocument.");
	}
	Dictionary document = scenario_document_payload(scenario_document);
	Dictionary scenario_ref;
	scenario_ref["schema_id"] = SCENARIO_SCHEMA_ID;
	scenario_ref["schema_version"] = scenario_document->get_schema_version();
	scenario_ref["scenario_id"] = scenario_document->get_scenario_id();
	scenario_ref["scenario_hash"] = scenario_document->get_scenario_hash();
	scenario_ref["map_ref"] = scenario_document->get_map_ref();
	scenario_ref["package_path"] = path;
	scenario_ref["package_id"] = path.get_file();
	scenario_ref["storage_policy"] = "project_maps_generated_package";

	Dictionary package;
	package["schema_id"] = SCENARIO_PACKAGE_SCHEMA_ID;
	package["schema_version"] = 1;
	package["package_kind"] = "generated_scenario_package";
	package["package_id"] = path.get_file();
	package["document_kind"] = "scenario";
	package["scenario_id"] = scenario_document->get_scenario_id();
	package["scenario_hash"] = scenario_document->get_scenario_hash();
	package["scenario_ref"] = scenario_ref;
	package["map_ref"] = scenario_document->get_map_ref();
	package["source_kind"] = "generated";
	package["storage_policy"] = "project_maps_generated_package";
	package["path_policy"] = String(options.get("path_policy", "dev_res_maps_export_user_maps"));
	package["authored_content_writeback"] = false;
	package["legacy_json_scenario_record"] = false;
	package["document"] = document;
	package["package_hash"] = "fnv1a32:" + hash32_hex(canonical_variant(package));
	Dictionary final_scenario_ref = scenario_ref.duplicate(true);
	final_scenario_ref["package_hash"] = package.get("package_hash", "");
	package["scenario_ref"] = final_scenario_ref;
	return write_package_dictionary(operation, path, package, bool(options.get("return_package", true)));
}

Dictionary MapPackageService::migrate_map_package(String source_path, String target_path, int32_t target_version, Dictionary options) const {
	(void)target_path;
	(void)target_version;
	return not_implemented("migrate_map_package", source_path, options);
}

Dictionary MapPackageService::migrate_scenario_package(String source_path, String target_path, int32_t target_version, Dictionary options) const {
	(void)target_path;
	(void)target_version;
	return not_implemented("migrate_scenario_package", source_path, options);
}

Dictionary MapPackageService::convert_legacy_scenario_record(Dictionary scenario_record, Dictionary terrain_layers_record, Dictionary options) const {
	(void)scenario_record;
	(void)terrain_layers_record;
	return not_implemented("convert_legacy_scenario_record", "", options);
}

Dictionary MapPackageService::convert_generated_payload(Dictionary generated_map, Dictionary options) const {
	return build_native_package_session_adoption(generated_map, options);
}

Dictionary MapPackageService::compute_document_hash(Variant document, Dictionary options) const {
	(void)options;
	Dictionary result;
	result["ok"] = true;
	result["status"] = "pass";
	result["algorithm"] = "canonical_variant_fnv1a32";
	result["hash"] = "fnv1a32:" + hash32_hex(canonical_variant(document));
	return result;
}

Dictionary MapPackageService::inspect_package(String path, Dictionary options) const {
	(void)options;
	Dictionary read_result = read_package_dictionary("inspect_package", path);
	if (!bool(read_result.get("ok", false))) {
		return read_result;
	}
	Dictionary package = read_result.get("package", Dictionary());
	Dictionary payload;
	payload["schema_id"] = package.get("schema_id", "");
	payload["schema_version"] = package.get("schema_version", 0);
	payload["package_id"] = package.get("package_id", "");
	payload["package_kind"] = package.get("package_kind", "");
	payload["document_kind"] = package.get("document_kind", "");
	payload["package_hash"] = package.get("package_hash", "");
	payload["storage_policy"] = package.get("storage_policy", "");
	payload["path_policy"] = package.get("path_policy", "");
	payload["authored_content_writeback"] = package.get("authored_content_writeback", false);
	payload["legacy_json_scenario_record"] = package.get("legacy_json_scenario_record", false);
	return package_success("inspect_package", path, payload);
}

Dictionary MapPackageService::inspect_random_map_generator_data_model(Dictionary options) const {
	return rmg_data_model::inspect_generator_data_model(options);
}

Dictionary MapPackageService::normalize_random_map_config(Dictionary config) const {
	Variant size_value = config.get("size", Variant());
	Dictionary size = size_value.get_type() == Variant::DICTIONARY ? Dictionary(size_value) : Dictionary();
	Variant profile_value = config.get("profile", Variant());
	Dictionary profile = profile_value.get_type() == Variant::DICTIONARY ? Dictionary(profile_value) : Dictionary();

	const String size_class_id = normalized_size_class_id(config, size);
	const int32_t default_dimension = dimension_for_size_class(size_class_id, 36);
	const int32_t width = nested_size_int(config, size, "width", "requested_width", default_dimension);
	const int32_t height = nested_size_int(config, size, "height", "requested_height", default_dimension);
	Dictionary player_constraints = normalized_player_constraints(config);
	const int32_t player_count = int32_t(player_constraints.get("player_count", 2));
	Array terrain_ids = normalized_string_array(profile.get("terrain_ids", Variant()), default_terrain_pool());
	Array faction_ids = ensure_repeated_to_count(normalized_string_array(profile.get("faction_ids", Variant()), default_faction_pool()), default_faction_pool(), player_count);
	Array town_ids = town_ids_for_factions(profile.get("town_ids", Variant()), faction_ids, player_count);

	Dictionary result;
	result["schema_id"] = NATIVE_RMG_SCHEMA_ID;
	result["schema_version"] = 1;
	result["normalizer_version"] = NATIVE_RMG_VERSION;
	result["seed"] = normalized_text(config, "seed", "0");
	result["normalized_seed"] = result["seed"];
	result["width"] = width;
	result["height"] = height;
	result["level_count"] = std::max<int32_t>(1, std::min<int32_t>(2, normalized_int(size, "level_count", normalized_int(config, "level_count", 1))));
	result["template_id"] = normalized_text(config, "template_id", normalized_text(profile, "template_id", ""));
	result["profile_id"] = normalized_text(profile, "id", normalized_text(config, "profile_id", ""));
	result["size_class_id"] = size_class_id;
	result["water_mode"] = normalized_water_mode(config, size);
	result["monster_strength"] = normalized_text(config, "monster_strength", "random").strip_edges().to_lower();
	result["player_constraints"] = player_constraints;
	result["terrain_ids"] = terrain_ids;
	result["faction_ids"] = faction_ids;
	result["town_ids"] = town_ids;
	result["template_selection_mode"] = "recovered_h3maped_exe_rng_exact_state_chain";
	result["template_selection_authority"] = "recovered_h3maped_exe_source_order";
	result["template_selection_runtime_generation_allowed"] = true;
	result["translated_template_authority_used"] = false;
	const Dictionary runtime_policy = native_rmg_runtime_policy_classification(result);
	const bool supported_parity_config = bool(runtime_policy.get("runtime_generation_allowed", false));
	result["full_generation_status"] = supported_parity_config
			? "native_runtime_ready_for_supported_scope"
			: "native_runtime_blocked_outside_supported_scope";
	result["supported_parity_config"] = supported_parity_config;
	result["h3maped_strict_scope"] = h3maped_core_strict_scope_id(result);
	result["normalization_scope"] = supported_parity_config
			? "native_runtime_generation_supported_scope"
			: "native_runtime_generation_unsupported_scope";
	return result;
}

Dictionary MapPackageService::random_map_config_identity(Dictionary config) const {
	Dictionary normalized = normalize_random_map_config(config);
	const String canonical = canonical_variant(normalized);
	const String signature = hash32_hex(canonical);

	Dictionary result;
	result["ok"] = true;
	result["schema_id"] = "aurelion_native_random_map_identity";
	result["schema_version"] = 1;
	result["algorithm"] = "canonical_variant_fnv1a32_config_normalization";
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
	const Dictionary runtime_policy = native_rmg_runtime_policy_classification(normalized);
	const bool supported = bool(runtime_policy.get("runtime_generation_allowed", false));
	result["full_generation_status"] = supported
			? "native_runtime_ready_for_supported_scope"
			: "native_runtime_blocked_outside_supported_scope";
	result["supported_parity_config"] = supported;
	result["runtime_policy_classification"] = runtime_policy;
	return result;
}

Dictionary MapPackageService::generate_random_map(Dictionary config, Dictionary options) const {
	(void)options;
	Dictionary normalized = normalize_random_map_config(config);
	if (!h3maped_core_supports_land_scope(normalized)) {
		return native_rmg_exact_chain_unimplemented_blocked_result(
				normalized,
				extension_profile_stub(normalized),
				native_rmg_runtime_policy_classification(normalized));
	}
	const String monster_strength = normalized.get("monster_strength", "random");
	if (!known_h3maped_monster_strength(monster_strength)) {
		Dictionary blocked = native_rmg_exact_chain_unimplemented_blocked_result(
				normalized,
				extension_profile_stub(normalized),
				native_rmg_runtime_policy_classification(normalized));
		blocked["error_code"] = "native_rmg_monster_strength_unsupported";
		blocked["message"] = "Monster strength must be random, weak, normal, or strong.";
		return blocked;
	}

	const Dictionary players = normalized.get("player_constraints", Dictionary());
	aurelion::h3maped_rmg_core::H3MapedRmgWorkflowConfig workflow_config;
	const String size_class = normalized.get("size_class_id", "");
	const String water_mode = normalized.get("water_mode", "land");
	workflow_config.size_class = std::string(size_class.utf8().get_data());
	workflow_config.water_mode = std::string(water_mode.utf8().get_data());
	workflow_config.width = int32_t(normalized.get("width", 0));
	workflow_config.height = int32_t(normalized.get("height", 0));
	workflow_config.level_count = int32_t(normalized.get("level_count", 1));
	workflow_config.human_count = int32_t(players.get("human_count", 1));
	workflow_config.player_count = int32_t(players.get("player_count", 2));
	const String seed_text = normalized.get("normalized_seed", "0");
	workflow_config.seed = uint32_t(uint64_t(seed_text.to_int()) & 0xffffffffULL);
	workflow_config.setup_object_0x34_known = true;
	workflow_config.setup_object_0x34 = workflow_config.human_count;
	workflow_config.setup_object_0x38_known = true;
	workflow_config.setup_object_0x38 = int32_t(players.get("human_team_count", workflow_config.human_count));
	workflow_config.setup_object_0x3c_known = true;
	workflow_config.setup_object_0x3c = int32_t(players.get("computer_count", workflow_config.player_count - workflow_config.human_count));
	workflow_config.setup_object_0x40_known = true;
	workflow_config.setup_object_0x40 = int32_t(players.get("computer_team_count", 0));
	workflow_config.setup_object_0x44_known = true;
	workflow_config.setup_object_0x44 = aurelion::h3maped_rmg_core::water_mode_code(
			std::string(water_mode.utf8().get_data()));
	workflow_config.setup_object_raw_0x48_known = true;
	workflow_config.setup_object_raw_0x48 = h3maped_monster_strength_raw_0x48(monster_strength);
	workflow_config.setup_object_0x48_known = false;
	workflow_config.setup_object_0x4c_known = true;
	workflow_config.setup_object_0x4c = 2;
	workflow_config.setup_caller_arg_0x0c_known = true;
	workflow_config.setup_caller_arg_0x0c =
			aurelion::h3maped_rmg_core::DIRECT_ENTRY_OPTIONAL_HANDLER_SENTINEL_0X4602C1;

	const auto workflow =
			aurelion::h3maped_rmg_core::run_h3maped_rmg_entry_to_writeout_workflow(workflow_config);
	const auto projection =
			aurelion::h3maped_rmg_core::project_runtime_map_from_native_owned_final_payload(workflow);
	if (!projection.applied) {
		Dictionary blocked;
		blocked["ok"] = false;
		blocked["status"] = "blocked";
		blocked["generation_status"] = "native_rmg_workflow_blocked";
		blocked["error_code"] = "native_rmg_final_payload_projection_blocked";
		blocked["message"] = String(projection.blocked_reason.c_str());
		blocked["workflow_status"] = String(workflow.status.c_str());
		blocked["workflow_phase"] = String(workflow.current_phase_id.c_str());
		blocked["workflow_blocked_reason"] = String(workflow.blocked_reason.c_str());
		blocked["normalized_config"] = normalized.duplicate(true);
		blocked["runtime_generation_allowed"] = false;
		blocked["native_runtime_authoritative"] = false;
		return blocked;
	}

	const String payload_token = hash32_hex_bytes(workflow.final_payload_writeout_0x4ad1e3.payload_bytes);
	const String map_id = "native_h3maped_" + payload_token;
	const String map_hash = "fnv1a32:" + payload_token;
	const String scenario_id = map_id + String("_skirmish");
	const String scenario_hash = String("fnv1a32:") + hash32_hex(map_hash + String(":scenario"));

	Dictionary map_state;
	map_state["map_id"] = map_id;
	map_state["map_hash"] = map_hash;
	map_state["source_kind"] = "generated_h3maped_native_parity";
	map_state["width"] = projection.width;
	map_state["height"] = projection.height;
	map_state["level_count"] = projection.level_count;
	Dictionary metadata;
	metadata["generated"] = true;
	metadata["source_kind"] = "generated_h3maped_native_parity";
	metadata["source_template_authority"] = "recovered_h3maped_exe_source_order";
	metadata["native_h3m_final_payload_parity"] = true;
	metadata["runtime_payload_projection_complete"] = true;
	metadata["production_ready"] = true;
	metadata["final_payload_byte_count"] = workflow.final_payload_writeout_0x4ad1e3.total_payload_byte_count;
	metadata["final_payload_fnv1a32"] = payload_token;
	Dictionary component_counts;
	component_counts["tile_count"] = projection.tile_count;
	component_counts["object_count"] = projection.object_count;
	component_counts["object_definition_count"] = projection.object_definition_count;
	component_counts["road_cell_count"] = int32_t(projection.road_tiles.size());
	metadata["component_counts"] = component_counts;
	map_state["metadata"] = metadata;
	map_state["terrain_layers"] = runtime_terrain_layers(projection);
	Dictionary route_graph;
	route_graph["schema_id"] = "aurelion_route_graph";
	route_graph["nodes"] = Array();
	route_graph["edges"] = Array();
	map_state["route_graph"] = route_graph;
	map_state["objects"] = runtime_objects(map_id, projection);
	Ref<MapDocument> map_document;
	map_document.instantiate();
	map_document->configure(map_state);

	Array player_slots;
	Array enemy_factions;
	Array player_starts;
	Array player_start_towns;
	for (const auto &slot : projection.player_slots) {
		if (!slot.active) {
			continue;
		}
		Dictionary player_slot;
		player_slot["slot"] = slot.color + 1;
		player_slot["color"] = slot.color;
		player_slot["human"] = slot.human;
		player_slot["computer"] = slot.computer;
		player_slot["owner"] = slot.human ? "player" : "enemy";
		player_slot["faction_id"] = runtime_faction_id(&slot);
		player_slots.append(player_slot);
		if (slot.computer) {
			enemy_factions.append(runtime_faction_id(&slot));
		}
		if (slot.has_main_town) {
			Dictionary start;
			start["start_id"] = "player_start_" + String::num_int64(slot.color + 1);
			start["owner"] = slot.human ? "player" : "enemy";
			start["owner_slot"] = slot.color + 1;
			start["player_slot"] = slot.color + 1;
			start["player_type"] = slot.human ? "human" : "computer";
			start["faction_id"] = runtime_faction_id(&slot);
			start["town_id"] = runtime_town_id(&slot);
			start["town_placement_id"] = runtime_town_placement_id(map_id, slot, projection);
			start["x"] = slot.town_x;
			start["y"] = slot.town_y;
			start["level"] = slot.town_level;
			player_starts.append(start);
			player_start_towns.append(start.duplicate(true));
		}
	}

	Dictionary scenario_state;
	scenario_state["scenario_id"] = scenario_id;
	scenario_state["scenario_hash"] = scenario_hash;
	Dictionary map_ref;
	map_ref["schema_id"] = MAP_SCHEMA_ID;
	map_ref["schema_version"] = MapDocument::SCHEMA_VERSION;
	map_ref["map_id"] = map_id;
	map_ref["map_hash"] = map_hash;
	map_ref["source_kind"] = "generated_h3maped_native_parity";
	scenario_state["map_ref"] = map_ref;
	Dictionary selection;
	selection["template_id"] = normalized.get("template_id", "");
	selection["seed"] = seed_text;
	selection["water_mode"] = water_mode;
	scenario_state["selection"] = selection;
	scenario_state["player_slots"] = player_slots;
	Dictionary objectives;
	objectives["kind"] = "defeat_generated_rivals";
	objectives["description"] = "Defeat every rival commander.";
	scenario_state["objectives"] = objectives;
	scenario_state["script_hooks"] = Array();
	scenario_state["enemy_factions"] = enemy_factions;
	Dictionary start_contract;
	start_contract["schema_id"] = "aurelion_native_rmg_start_contract_v1";
	start_contract["primary_hero_id"] = "hero_lyra";
	start_contract["player_starts"] = player_starts;
	start_contract["player_start_towns"] = player_start_towns;
	start_contract["start_count"] = player_starts.size();
	start_contract["start_town_count"] = player_start_towns.size();
	scenario_state["start_contract"] = start_contract;
	Ref<ScenarioDocument> scenario_document;
	scenario_document.instantiate();
	scenario_document->configure(scenario_state);

	Dictionary map_validation = validate_map_document_structural_report(map_document);
	Dictionary scenario_validation = validate_scenario_document_structural_report(scenario_document, map_document);
	if (!bool(map_validation.get("ok", false)) || !bool(scenario_validation.get("ok", false))) {
		Dictionary blocked;
		blocked["ok"] = false;
		blocked["status"] = "blocked";
		blocked["error_code"] = "native_rmg_runtime_document_validation_failed";
		blocked["message"] = "Native payload projection did not produce structurally valid runtime documents.";
		blocked["map_validation"] = map_validation;
		blocked["scenario_validation"] = scenario_validation;
		return blocked;
	}

	Dictionary result;
	result["ok"] = true;
	result["status"] = "complete";
	result["generation_status"] = "native_rmg_complete";
	result["full_generation_status"] = "native_runtime_ready";
	result["normalized_config"] = normalized.duplicate(true);
	result["map_id"] = map_id;
	result["map_hash"] = map_hash;
	result["scenario_id"] = scenario_id;
	result["scenario_hash"] = scenario_hash;
	result["map_document"] = map_document;
	result["scenario_document"] = scenario_document;
	result["map_validation"] = map_validation;
	result["scenario_validation"] = scenario_validation;
	result["final_payload_byte_count"] = workflow.final_payload_writeout_0x4ad1e3.total_payload_byte_count;
	result["final_payload_fnv1a32"] = payload_token;
	result["runtime_tile_count"] = projection.tile_count;
	result["runtime_object_count"] = projection.object_count;
	result["runtime_road_cell_count"] = int32_t(projection.road_tiles.size());
	result["runtime_payload_projection_complete"] = true;
	result["supported_parity_config"] = true;
	result["runtime_generation_allowed"] = true;
	result["native_runtime_authoritative"] = true;
	result["public_runtime_authoritative"] = true;
	result["package_session_adoption_ready"] = true;
	result["full_parity_claim"] = true;
	return result;
}
