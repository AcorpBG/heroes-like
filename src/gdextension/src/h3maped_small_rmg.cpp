#include "h3maped_small_rmg.hpp"

#include <godot_cpp/classes/file_access.hpp>
#include <godot_cpp/classes/json.hpp>
#include <godot_cpp/variant/array.hpp>
#include <godot_cpp/variant/dictionary.hpp>
#include <godot_cpp/variant/string.hpp>
#include <godot_cpp/variant/variant.hpp>

#include <algorithm>
#include <cerrno>
#include <cstdint>
#include <cstdlib>

namespace godot::h3maped_small_rmg {
namespace {

constexpr const char *BINARY_PATH = "/root/Downloads/h3maped.exe";
constexpr const char *BINARY_SHA256 = "4480fba145c9f885942cc668d4bce430fe39c0fa482d1a6e58f96318ab857a37";
constexpr int64_t BINARY_SIZE_BYTES = 2134016;
constexpr const char *SPEC_PATH = "/root/.openclaw/workspace/tasks/10184/artifacts/homm3-re/random-map-generation-h3maped-full-spec.md";
constexpr const char *PROJECT_TEMPLATE_CATALOG_PATH = "res://content/random_map_template_catalog.json";
constexpr const char *ARCHIVED_REPORT_TREADMILL_PATH = "src/gdextension/src/archived_h3maped_small_rmg_report_treadmill_20260513.cpp";
constexpr const char *ARCHIVED_OVERGROWN_ACTIVE_PATH = "src/gdextension/src/archived_h3maped_small_rmg_overgrown_active_20260513.cpp";
constexpr const char *ARCHIVED_PHASE_LEDGER_PATH = "src/gdextension/src/archived_h3maped_small_rmg_phase_ledger_20260513.cpp";
constexpr const char *ARCHIVED_ACTIVE_BOUNDARY_PATH = "src/gdextension/src/archived_h3maped_small_rmg_active_boundary_20260513.cpp";
constexpr const char *ARCHIVED_LEDGER_PATH = "src/gdextension/src/archived_h3maped_small_rmg_inspection_ledger_20260513.cpp";
constexpr const char *OLDER_LEGACY_LEDGER_PATH = "src/gdextension/src/legacy_h3maped_small_rmg_inspection_ledger.cpp";

struct TemplateEvidence {
	const char *id = "";
	int32_t catalog_index = -1;
	int32_t min_size_score = 0;
	int32_t max_size_score = 0;
	int32_t min_humans = 0;
	int32_t max_humans = 0;
	int32_t min_total_players = 0;
	int32_t max_total_players = 0;
	int32_t zone_count = 0;
	int32_t connection_count = 0;
	const char *adapted_template_id = "";
	uint8_t human_capable_source_owner_mask = 0;
	uint8_t player_capable_source_owner_mask = 0;
};

constexpr TemplateEvidence SMALL_LAND_TEMPLATES[] = {
	{ "h3maped_template_000", 0, 1, 2, 1, 8, 2, 8, 8, 12, "", 0xff, 0xff },
	{ "h3maped_template_012", 12, 1, 8, 1, 4, 2, 4, 6, 6, "", 0x0f, 0x0f },
	{ "h3maped_template_018", 18, 1, 9, 1, 4, 2, 4, 6, 5, "translated_rmg_template_019_v1", 0x0f, 0x0f },
	{ "h3maped_template_020", 20, 1, 8, 1, 4, 2, 4, 5, 8, "", 0x0f, 0x0f },
	{ "h3maped_template_022", 22, 1, 8, 1, 4, 2, 4, 5, 6, "", 0x03, 0x03 },
	{ "h3maped_template_024", 24, 1, 18, 1, 4, 2, 4, 9, 12, "", 0x0f, 0x0f },
	{ "h3maped_template_027", 27, 1, 4, 1, 4, 2, 4, 8, 8, "", 0x0f, 0x0f },
	{ "h3maped_template_028", 28, 1, 4, 1, 4, 2, 4, 8, 11, "", 0x0f, 0x0f },
	{ "h3maped_template_031", 31, 1, 8, 1, 6, 2, 6, 6, 7, "", 0x3f, 0x3f },
	{ "h3maped_template_044", 44, 1, 8, 1, 2, 2, 3, 8, 8, "", 0x03, 0x07 },
	{ "h3maped_template_046", 46, 1, 8, 1, 3, 2, 5, 9, 12, "", 0x07, 0x1f },
	{ "h3maped_template_047", 47, 1, 8, 1, 3, 2, 5, 7, 8, "", 0x07, 0x1f },
	{ "h3maped_template_048", 48, 1, 9, 1, 6, 2, 7, 7, 12, "", 0x3f, 0x7f },
};

constexpr const char *H3MAPED_ALLOWED_MAIN_TOWNS[] = {
	"castle",
	"rampart",
	"tower",
	"inferno",
	"necropolis",
	"dungeon",
	"stronghold",
	"fortress",
	"elemental",
};

int32_t nested_or_flat_i32(const Dictionary &dict, const char *nested_key, const char *flat_key, int32_t fallback) {
	Dictionary nested = dict.get(nested_key, Dictionary());
	if (nested.has(flat_key)) {
		return int32_t(nested.get(flat_key, fallback));
	}
	return int32_t(dict.get(flat_key, fallback));
}

String normalized_seed_text(const Dictionary &normalized_config) {
	return String(normalized_config.get("normalized_seed", normalized_config.get("seed", "0")));
}

int32_t player_count(const Dictionary &normalized_config) {
	Dictionary constraints = normalized_config.get("player_constraints", Dictionary());
	return int32_t(constraints.get("player_count", normalized_config.get("player_count", 2)));
}

int32_t human_count(const Dictionary &normalized_config) {
	Dictionary constraints = normalized_config.get("player_constraints", Dictionary());
	return int32_t(constraints.get("human_count", normalized_config.get("human_count", 1)));
}

String water_mode(const Dictionary &normalized_config) {
	Dictionary size = normalized_config.get("size", Dictionary());
	return String(size.get("water_mode", normalized_config.get("water_mode", "land")));
}

String size_class_id(const Dictionary &normalized_config) {
	Dictionary size = normalized_config.get("size", Dictionary());
	return String(size.get("size_class_id", normalized_config.get("size_class_id", "homm3_small")));
}

int32_t width(const Dictionary &normalized_config) {
	return nested_or_flat_i32(normalized_config, "size", "width", 36);
}

int32_t height(const Dictionary &normalized_config) {
	return nested_or_flat_i32(normalized_config, "size", "height", 36);
}

int32_t level_count(const Dictionary &normalized_config) {
	return nested_or_flat_i32(normalized_config, "size", "level_count", 1);
}

int32_t water_mode_code(const Dictionary &normalized_config) {
	const String mode = water_mode(normalized_config);
	if (mode == "normal_water") {
		return 1;
	}
	if (mode == "islands") {
		return 2;
	}
	return 0;
}

int32_t size_score(const Dictionary &normalized_config) {
	int32_t score = int32_t((int64_t(std::max(1, width(normalized_config))) * int64_t(std::max(1, height(normalized_config))) * int64_t(std::max(1, level_count(normalized_config)))) / 0x510);
	if (water_mode_code(normalized_config) == 2) {
		score = std::max(1, score / 2);
	}
	return score;
}

bool parse_numeric_seed(const String &seed_text, uint32_t &seed_value) {
	const String stripped = seed_text.strip_edges();
	if (stripped.is_empty()) {
		return false;
	}
	const CharString utf8 = stripped.utf8();
	char *end = nullptr;
	errno = 0;
	const long long parsed = std::strtoll(utf8.get_data(), &end, 10);
	if (errno != 0 || end == utf8.get_data() || *end != '\0') {
		return false;
	}
	seed_value = uint32_t(parsed);
	return true;
}

Dictionary template_record(const TemplateEvidence &candidate) {
	Dictionary item;
	item["id"] = candidate.id;
	item["source_catalog_index"] = candidate.catalog_index;
	item["min_size_score"] = candidate.min_size_score;
	item["max_size_score"] = candidate.max_size_score;
	item["min_humans"] = candidate.min_humans;
	item["max_humans"] = candidate.max_humans;
	item["min_total_players"] = candidate.min_total_players;
	item["max_total_players"] = candidate.max_total_players;
	item["zone_count"] = candidate.zone_count;
	item["connection_count"] = candidate.connection_count;
	item["adapted_template_id"] = candidate.adapted_template_id;
	item["human_capable_source_owner_mask"] = int32_t(candidate.human_capable_source_owner_mask);
	item["player_capable_source_owner_mask"] = int32_t(candidate.player_capable_source_owner_mask);
	return item;
}

Array source_owner_indices_from_mask(uint8_t mask) {
	Array indices;
	for (int32_t index = 0; index < 8; ++index) {
		if ((mask & (1U << index)) != 0) {
			indices.append(index);
		}
	}
	return indices;
}

Dictionary load_json_dictionary(const String &path) {
	Dictionary result;
	result["ok"] = false;
	result["path"] = path;
	if (!FileAccess::file_exists(path)) {
		result["status"] = "missing_json_file";
		return result;
	}
	Ref<FileAccess> file = FileAccess::open(path, FileAccess::READ);
	if (file.is_null() || !file->is_open()) {
		result["status"] = "unreadable_json_file";
		return result;
	}
	Ref<JSON> parser;
	parser.instantiate();
	if (parser->parse(file->get_as_text()) != OK || parser->get_data().get_type() != Variant::DICTIONARY) {
		result["status"] = "invalid_json_dictionary";
		return result;
	}
	result["ok"] = true;
	result["status"] = "loaded";
	result["data"] = Dictionary(parser->get_data());
	return result;
}

Dictionary find_project_template_record(const String &adapted_template_id, Dictionary &load_status) {
	load_status = load_json_dictionary(PROJECT_TEMPLATE_CATALOG_PATH);
	if (!bool(load_status.get("ok", false))) {
		return Dictionary();
	}
	Dictionary catalog = load_status.get("data", Dictionary());
	if (Variant(catalog.get("templates", Variant())).get_type() != Variant::ARRAY) {
		load_status["ok"] = false;
		load_status["status"] = "missing_templates_array";
		return Dictionary();
	}
	Array templates = catalog.get("templates", Array());
	for (int64_t index = 0; index < templates.size(); ++index) {
		if (Variant(templates[index]).get_type() != Variant::DICTIONARY) {
			continue;
		}
		Dictionary candidate = templates[index];
		if (String(candidate.get("id", "")) == adapted_template_id) {
			return candidate;
		}
	}
	load_status["ok"] = false;
	load_status["status"] = "adapted_template_not_found";
	load_status["adapted_template_id"] = adapted_template_id;
	return Dictionary();
}

Array accepted_templates(const Dictionary &normalized_config) {
	Array accepted;
	const int32_t score = size_score(normalized_config);
	const int32_t humans = human_count(normalized_config);
	const int32_t players = player_count(normalized_config);
	if (!supports_scope(normalized_config)) {
		return accepted;
	}
	for (const TemplateEvidence &candidate : SMALL_LAND_TEMPLATES) {
		if (score < candidate.min_size_score || score > candidate.max_size_score) {
			continue;
		}
		if (humans < candidate.min_humans || humans > candidate.max_humans || players < candidate.min_total_players || players > candidate.max_total_players || players < humans) {
			continue;
		}
		accepted.append(template_record(candidate));
	}
	return accepted;
}

Dictionary binary_verification() {
	Dictionary report;
	report["path"] = BINARY_PATH;
	report["expected_sha256"] = BINARY_SHA256;
	report["expected_size_bytes"] = BINARY_SIZE_BYTES;
	report["format"] = "PE32 GUI Intel 80386 Windows executable";
	if (!FileAccess::file_exists(BINARY_PATH)) {
		report["ok"] = false;
		report["status"] = "missing";
		return report;
	}
	Ref<FileAccess> file = FileAccess::open(BINARY_PATH, FileAccess::READ);
	if (file.is_null() || !file->is_open()) {
		report["ok"] = false;
		report["status"] = "unreadable";
		return report;
	}
	const int64_t actual_size = file->get_length();
	const int32_t byte_0 = file->get_8();
	const int32_t byte_1 = file->get_8();
	const String actual_sha256 = FileAccess::get_sha256(BINARY_PATH);
	const bool mz = byte_0 == 'M' && byte_1 == 'Z';
	const bool sha_ok = actual_sha256 == String(BINARY_SHA256);
	report["actual_size_bytes"] = actual_size;
	report["actual_sha256"] = actual_sha256;
	report["mz_header_present"] = mz;
	report["sha256_matches"] = sha_ok;
	report["ok"] = actual_size == BINARY_SIZE_BYTES && mz && sha_ok;
	report["status"] = bool(report["ok"]) ? String("verified_reset_anchor") : String("mismatch");
	return report;
}

Dictionary phase_record(const String &id, const String &source, const String &status) {
	Dictionary phase;
	phase["id"] = id;
	phase["h3maped_source"] = source;
	phase["status"] = status;
	phase["materializes_public_output"] = false;
	return phase;
}

Array fresh_phase_backlog() {
	Array backlog;
	backlog.append(phase_record("template_selection", "0x49f0cd, 0x4ac597, 0x4e7276", "active_boundary"));
	backlog.append(phase_record("player_slot_assignment", "0x4ac62a..0x4ac6ec", "active_internal_state"));
	backlog.append(phase_record("runtime_zone_records", "0x4a218c, 0x49b452", "active_internal_state"));
	backlog.append(phase_record("link_seed_setup", "0x4a1f3b", "active_internal_state"));
	backlog.append(phase_record("coordinate_replay_and_zone_footprints", "0x4a17f5, 0x4a1701, 0x4a1ad8, 0x4a19ed, 0x4a3a03", "pending_runtime_port"));
	backlog.append(phase_record("terrain_and_terrainplacement", "0x4a3f27, 0x4bb74b, 0x4bc5f0, 0x49b2b6", "pending_runtime_port"));
	backlog.append(phase_record("town_object_placement", "0x4a8d2c, 0x4a8db2, 0x4a93a2", "pending_runtime_port"));
	backlog.append(phase_record("mines_rewards_and_object_vector", "0x4a9d6a, 0x4a9911, 0x4aa354, 0x4a9f1c, 0x4aa9b7", "pending_runtime_port"));
	backlog.append(phase_record("roads_and_rivers", "0x4ab52a, 0x4aae7b, 0x4ab37f, 0x4b4243, 0x458a2f, 0x458893", "pending_runtime_port"));
	backlog.append(phase_record("connections_blockers_and_guards", "0x4a79a3, 0x4a61bc, 0x4a696b, 0x4a6cf2, 0x4a7605", "pending_runtime_port"));
	backlog.append(phase_record("final_h3m_writeout", "0x49b2b6 plus final object/tile serialization", "pending_runtime_port"));
	return backlog;
}

Array current_gap_summary() {
	Array gaps;
	gaps.append("active code contains h3maped binary verification, small scope gate, template RNG selection, player-slot assignment, runtime-zone records, and link-seed setup");
	gaps.append("coordinate replay, physical zone fills, terrain, towns, roads, blockers, guards, mines, rewards, and writeout are not implemented in the fresh active module");
	gaps.append("all earlier private phase ledgers were archived because they were report growth, not usable map generation");
	gaps.append("small maps remain blocked from runtime package output until executable-derived phases are ported as actual generation state");
	return gaps;
}

Dictionary player_slot_assignment_phase(const Dictionary &normalized_config, const Dictionary &selection) {
	Dictionary selected_template = selection.get("selected_template", Dictionary());
	const uint8_t human_mask = uint8_t(int32_t(selected_template.get("human_capable_source_owner_mask", 0)));
	const uint8_t player_mask = uint8_t(int32_t(selected_template.get("player_capable_source_owner_mask", 0)));
	const int32_t humans = std::max(0, human_count(normalized_config));
	const int32_t players = std::max(humans, player_count(normalized_config));

	Dictionary phase;
	phase["phase_id"] = "player_slot_assignment";
	phase["status"] = bool(selection.get("ok", false)) ? String("active_internal_state") : String("blocked_until_template_selection");
	phase["h3maped_anchor"] = "0x4ac62a..0x4ac6ec";
	phase["selected_color_bitmap_offset"] = "generator+0xed8";
	phase["assignment_slots_offset"] = "generator+0xee0";
	phase["mapped_slots_offset"] = "generator+0xee4";
	phase["human_capable_source_owner_mask"] = int32_t(human_mask);
	phase["player_capable_source_owner_mask"] = int32_t(player_mask);
	phase["human_capable_source_owner_indices"] = source_owner_indices_from_mask(human_mask);
	phase["player_capable_source_owner_indices"] = source_owner_indices_from_mask(player_mask);

	Array selected_color_order;
	Array assignment_slots;
	Array mapped_slots;
	for (int32_t index = 0; index < 8; ++index) {
		selected_color_order.append(index);
		assignment_slots.append(-1);
		mapped_slots.append(-1);
	}

	Array assignments;
	Array human_indices = phase["human_capable_source_owner_indices"];
	Array player_indices = phase["player_capable_source_owner_indices"];
	int32_t assigned_players = 0;
	for (int32_t human = 0; human < humans && human < human_indices.size(); ++human) {
		const int32_t source_owner = int32_t(human_indices[human]);
		assignment_slots[source_owner] = assigned_players;
		mapped_slots[source_owner] = assigned_players;
		Dictionary record;
		record["player_slot"] = assigned_players + 1;
		record["player_type"] = "human";
		record["source_owner_index"] = source_owner;
		record["actual_player_color"] = assigned_players;
		assignments.append(record);
		assigned_players += 1;
	}
	for (int32_t source_index = 0; assigned_players < players && source_index < player_indices.size(); ++source_index) {
		const int32_t source_owner = int32_t(player_indices[source_index]);
		if (int32_t(mapped_slots[source_owner]) != -1) {
			continue;
		}
		assignment_slots[source_owner] = assigned_players;
		mapped_slots[source_owner] = assigned_players;
		Dictionary record;
		record["player_slot"] = assigned_players + 1;
		record["player_type"] = "computer";
		record["source_owner_index"] = source_owner;
		record["actual_player_color"] = assigned_players;
		assignments.append(record);
		assigned_players += 1;
	}

	phase["selected_color_order_ed8"] = selected_color_order;
	phase["raw_ee0_slots"] = assignment_slots;
	phase["mapped_ee4_slots"] = mapped_slots;
	phase["assignment_records"] = assignments;
	phase["assigned_player_count"] = assigned_players;
	phase["requested_human_count"] = humans;
	phase["requested_player_count"] = players;
	phase["materializes_runtime_players"] = false;
	phase["materializes_public_output"] = false;
	phase["blocked_next"] = "runtime_zone_records_0x4a218c";
	return phase;
}

Dictionary runtime_zone_records_phase(const Dictionary &selection, const Dictionary &player_phase) {
	Dictionary phase;
	phase["phase_id"] = "runtime_zone_records";
	phase["status"] = "blocked_missing_project_template_catalog";
	phase["h3maped_anchor"] = "0x4a218c";
	phase["initializer_anchor"] = "0x49b452";
	phase["runtime_zone_vector_begin_offset"] = "generator+0x10e0";
	phase["runtime_zone_vector_end_offset"] = "generator+0x10e4";
	phase["runtime_zone_vector_capacity_offset"] = "generator+0x10e8";
	phase["runtime_zone_record_size_bytes"] = 0x414;
	phase["materializes_runtime_zone_coordinates"] = false;
	phase["materializes_terrain"] = false;
	phase["materializes_map_cells"] = false;
	phase["materializes_runtime_players"] = false;
	phase["materializes_public_output"] = false;
	phase["blocked_next"] = "coordinate_replay_and_zone_footprints_0x4a1f3b";

	Dictionary catalog_load;
	const String adapted_template_id = String(selection.get("adapted_template_id", ""));
	Dictionary adapted_template = find_project_template_record(adapted_template_id, catalog_load);
	phase["project_catalog_load"] = catalog_load;
	phase["project_template_id"] = adapted_template_id;
	if (adapted_template.is_empty() || Variant(adapted_template.get("zones", Variant())).get_type() != Variant::ARRAY) {
		return phase;
	}

	Array mapped_slots = player_phase.get("mapped_ee4_slots", Array());
	Array zones = adapted_template.get("zones", Array());
	Array runtime_records;
	Array actual_owner_colors;
	int32_t assigned_start_zone_count = 0;
	int32_t unassigned_start_zone_count = 0;
	int32_t treasure_zone_count = 0;
	int32_t minimum_player_castles = 0;
	int32_t minimum_source_base_size = 0x7fffffff;

	for (int64_t index = 0; index < zones.size(); ++index) {
		if (Variant(zones[index]).get_type() != Variant::DICTIONARY) {
			continue;
		}
		Dictionary zone = zones[index];
		Dictionary ownership = zone.get("ownership", Dictionary());
		Dictionary grammar_source = zone.get("grammar_source", Dictionary());
		Dictionary player_towns = zone.get("player_towns", Dictionary());
		Dictionary neutral_towns = zone.get("neutral_towns", Dictionary());
		Dictionary town_policy = zone.get("town_policy", Dictionary());
		Dictionary mine_requirements = zone.get("mine_requirements", Dictionary());
		Dictionary minimum_by_category = mine_requirements.get("minimum_by_category", Dictionary());
		Dictionary density_by_category = mine_requirements.get("density_by_category", Dictionary());
		Dictionary terrain = zone.get("terrain", Dictionary());

		const int32_t source_owner = int32_t(ownership.get("source_owner_index", -2));
		int32_t actual_owner = -1;
		if (source_owner >= 0 && source_owner < mapped_slots.size()) {
			actual_owner = int32_t(mapped_slots[source_owner]);
		}
		const String role = String(zone.get("role", zone.get("type", "")));
		if (role == "human_start") {
			if (actual_owner >= 0) {
				assigned_start_zone_count += 1;
			} else {
				unassigned_start_zone_count += 1;
			}
		} else if (role == "treasure") {
			treasure_zone_count += 1;
		}
		const int32_t min_castles = int32_t(player_towns.get("min_castles", 0));
		minimum_player_castles += min_castles;
		const int32_t base_size = int32_t(zone.get("base_size", 0));
		if (base_size > 0) {
			minimum_source_base_size = std::min(minimum_source_base_size, base_size);
		}

		Dictionary record;
		record["runtime_index"] = runtime_records.size();
		record["source_zone_id"] = zone.get("source_zone_id", zone.get("id", int32_t(index + 1)));
		record["role"] = role;
		record["source_bucket"] = grammar_source.get("source_bucket", -1);
		record["source_owner_index"] = source_owner;
		record["actual_owner_color"] = actual_owner;
		record["source_base_size"] = base_size;
		record["player_min_towns"] = player_towns.get("min_towns", 0);
		record["min_player_castles"] = min_castles;
		record["player_min_castles"] = min_castles;
		record["player_town_density"] = player_towns.get("town_density", 0);
		record["player_castle_density"] = player_towns.get("castle_density", 0);
		record["neutral_min_towns"] = neutral_towns.get("min_towns", 0);
		record["neutral_min_castles"] = neutral_towns.get("min_castles", 0);
		record["neutral_town_density"] = neutral_towns.get("town_density", 0);
		record["neutral_castle_density"] = neutral_towns.get("castle_density", 0);
		record["terrain_match_to_town"] = bool(terrain.get("match_to_faction", false));
		record["terrain_policy"] = Array(terrain.get("allowed", Array())).is_empty() ? String("match_to_player_town") : String("all_land_h3");
		record["project_allowed_faction_ids"] = town_policy.get("allowed_faction_ids", Array());
		if (!Array(town_policy.get("allowed_faction_ids", Array())).is_empty()) {
			Array allowed_h3_towns;
			for (int32_t town_index = 0; town_index < int32_t(sizeof(H3MAPED_ALLOWED_MAIN_TOWNS) / sizeof(H3MAPED_ALLOWED_MAIN_TOWNS[0])); ++town_index) {
				allowed_h3_towns.append(H3MAPED_ALLOWED_MAIN_TOWNS[town_index]);
			}
			record["allowed_faction_ids_for_49b3c1"] = allowed_h3_towns;
		} else {
			record["allowed_faction_ids_for_49b3c1"] = Array();
		}
		if (String(record["terrain_policy"]) == "all_land_h3") {
			Array allowed_terrain_ids;
			for (int32_t terrain_id = 0; terrain_id <= 7; ++terrain_id) {
				allowed_terrain_ids.append(terrain_id);
			}
			record["allowed_h3maped_terrain_ids_for_49b53d"] = allowed_terrain_ids;
		}
		record["monster_strength"] = Dictionary(zone.get("monster_policy", Dictionary())).get("strength", "");
		record["minimum_wood_mines"] = minimum_by_category.get("timber", 0);
		record["minimum_mercury_mines"] = minimum_by_category.get("quicksilver", 0);
		record["minimum_ore_mines"] = minimum_by_category.get("ore", 0);
		record["minimum_sulfur_mines"] = minimum_by_category.get("ember_salt", 0);
		record["minimum_crystal_mines"] = minimum_by_category.get("lens_crystal", 0);
		record["minimum_gems_mines"] = minimum_by_category.get("cut_gems", 0);
		record["minimum_gold_mines"] = minimum_by_category.get("gold", 0);
		record["minimum_rare_mines"] = int32_t(minimum_by_category.get("gold", 0)) + int32_t(minimum_by_category.get("quicksilver", 0)) + int32_t(minimum_by_category.get("ember_salt", 0)) + int32_t(minimum_by_category.get("lens_crystal", 0)) + int32_t(minimum_by_category.get("cut_gems", 0));
		record["mine_density_wood"] = density_by_category.get("timber", 0);
		record["mine_density_mercury"] = density_by_category.get("quicksilver", 0);
		record["mine_density_ore"] = density_by_category.get("ore", 0);
		record["mine_density_sulfur"] = density_by_category.get("ember_salt", 0);
		record["mine_density_crystal"] = density_by_category.get("lens_crystal", 0);
		record["mine_density_gems"] = density_by_category.get("cut_gems", 0);
		record["mine_density_gold"] = density_by_category.get("gold", 0);
		record["treasure_bands"] = zone.get("treasure_bands", Array());
		runtime_records.append(record);
		actual_owner_colors.append(actual_owner);
	}

	if (minimum_source_base_size == 0x7fffffff) {
		minimum_source_base_size = 0;
	}
	phase["status"] = "active_internal_state";
	phase["source"] = "res://content/random_map_template_catalog.json imported from recovered h3maped template catalog";
	phase["runtime_zone_count"] = runtime_records.size();
	phase["runtime_zone_records"] = runtime_records;
	phase["actual_owner_colors_by_runtime_zone"] = actual_owner_colors;
	phase["assigned_start_zone_count"] = assigned_start_zone_count;
	phase["unassigned_start_zone_count"] = unassigned_start_zone_count;
	phase["treasure_zone_count"] = treasure_zone_count;
	phase["minimum_player_castles"] = minimum_player_castles;
	phase["minimum_source_base_size"] = minimum_source_base_size;
	return phase;
}

bool player_filter_allows(const Dictionary &filter, int32_t humans, int32_t players) {
	return humans >= int32_t(filter.get("min_human", 0))
			&& humans <= int32_t(filter.get("max_human", 8))
			&& players >= int32_t(filter.get("min_total", 0))
			&& players <= int32_t(filter.get("max_total", 8));
}

Dictionary link_seed_phase(const Dictionary &normalized_config, const Dictionary &selection, const Dictionary &runtime_zone_phase) {
	Dictionary phase;
	phase["phase_id"] = "link_seed_setup";
	phase["status"] = "blocked_until_runtime_zone_records";
	phase["h3maped_anchor"] = "0x4a1f3b";
	phase["candidate_generator_anchor"] = "0x4a17f5";
	phase["distance_validation_anchor"] = "0x4a1701";
	phase["late_payload_consumer_anchor"] = "0x4a79a3";
	phase["materializes_coordinates"] = false;
	phase["materializes_connection_guards"] = false;
	phase["materializes_roads"] = false;
	phase["materializes_blockers"] = false;
	phase["materializes_public_output"] = false;
	phase["blocked_next"] = "coordinate_replay_0x4a17f5_0x4a1701";
	if (String(runtime_zone_phase.get("status", "")) != "active_internal_state") {
		return phase;
	}

	Dictionary catalog_load;
	Dictionary adapted_template = find_project_template_record(String(selection.get("adapted_template_id", "")), catalog_load);
	phase["project_catalog_load"] = catalog_load;
	if (adapted_template.is_empty() || Variant(adapted_template.get("links", Variant())).get_type() != Variant::ARRAY) {
		phase["status"] = "blocked_missing_project_template_links";
		return phase;
	}

	const int32_t humans = human_count(normalized_config);
	const int32_t players = player_count(normalized_config);
	Array links = adapted_template.get("links", Array());
	Array seeds;
	for (int64_t index = 0; index < links.size(); ++index) {
		if (Variant(links[index]).get_type() != Variant::DICTIONARY) {
			continue;
		}
		Dictionary link = links[index];
		if (!player_filter_allows(link.get("player_filter", Dictionary()), humans, players)) {
			continue;
		}
		Dictionary endpoints = link.get("source_endpoints", Dictionary());
		const int32_t source_zone_a = int32_t(endpoints.get("zone1", 0));
		const int32_t source_zone_b = int32_t(endpoints.get("zone2", 0));
		if (source_zone_a <= 0 || source_zone_b <= 0) {
			continue;
		}
		Dictionary seed;
		seed["link_index"] = seeds.size();
		seed["source_row"] = Dictionary(link.get("grammar_source", Dictionary())).get("source_row", -1);
		seed["source_zone_a"] = source_zone_a;
		seed["source_zone_b"] = source_zone_b;
		seed["runtime_zone_a"] = source_zone_a - 1;
		seed["runtime_zone_b"] = source_zone_b - 1;
		seed["guard_value"] = link.get("guard_value", Dictionary(link.get("guard", Dictionary())).get("value", 0));
		seed["wide"] = bool(link.get("wide", false));
		seed["border_guard"] = bool(link.get("border_guard", false));
		seed["early_consumer"] = "0x4a1f3b_endpoint_only";
		seed["late_payload_consumer"] = "0x4a79a3";
		seeds.append(seed);
	}

	phase["status"] = "active_internal_state";
	phase["source"] = "res://content/random_map_template_catalog.json recovered link rows consumed through h3maped 0x4a1f3b";
	phase["link_seed_count"] = seeds.size();
	phase["link_seeds"] = seeds;
	return phase;
}

Dictionary active_generation_state(const Dictionary &normalized_config) {
	Dictionary selection = selection_identity(normalized_config);
	Dictionary player_phase = player_slot_assignment_phase(normalized_config, selection);
	Dictionary runtime_zone_phase = runtime_zone_records_phase(selection, player_phase);
	Dictionary link_phase = link_seed_phase(normalized_config, selection, runtime_zone_phase);
	Array completed;
	completed.append("template_selection");
	if (String(player_phase.get("status", "")) == "active_internal_state") {
		completed.append("player_slot_assignment");
	}
	if (String(runtime_zone_phase.get("status", "")) == "active_internal_state") {
		completed.append("runtime_zone_records");
	}
	if (String(link_phase.get("status", "")) == "active_internal_state") {
		completed.append("link_seed_setup");
	}
	Dictionary state;
	state["schema_id"] = "aurelion_h3maped_small_active_generation_state_v1";
	state["status"] = completed.size() >= 4 ? String("link_seed_setup_active_internal_state") : String("blocked_before_link_seed_setup");
	state["completed_phase_ids"] = completed;
	state["completed_phase_count"] = completed.size();
	state["runtime_generation_allowed"] = false;
	state["materializes_public_output"] = false;
	state["materializes_runtime_players"] = false;
	state["materializes_map_cells"] = false;
	state["selection_identity"] = selection;
	state["player_slot_assignment"] = player_phase;
	state["runtime_zone_records"] = runtime_zone_phase;
	state["link_seed_setup"] = link_phase;
	state["blocked_next"] = "coordinate_replay_and_zone_footprints_0x4a1f3b";
	return state;
}

} // namespace

bool supports_scope(const Dictionary &normalized_config) {
	return width(normalized_config) == 36
			&& height(normalized_config) == 36
			&& level_count(normalized_config) == 1
			&& water_mode(normalized_config) == "land"
			&& size_class_id(normalized_config) == "homm3_small";
}

Dictionary selection_identity(const Dictionary &normalized_config) {
	Dictionary result;
	result["schema_id"] = "aurelion_native_rmg_small_h3maped_selection_identity_v2";
	result["template_selection_mode"] = "h3maped_exe_rng";
	result["rng_seed_setter_address"] = "0x4e7269";
	result["rng_function_address"] = "0x4e7276";
	result["rng_algorithm"] = "state = state * 0x343fd + 0x269ec3; return (state >> 16) & 0x7fff";
	result["runtime_generation_allowed"] = false;
	const Array accepted = accepted_templates(normalized_config);
	result["accepted_template_count"] = accepted.size();
	if (!supports_scope(normalized_config)) {
		result["ok"] = false;
		result["status"] = "unsupported_scope";
		return result;
	}
	if (accepted.is_empty()) {
		result["ok"] = false;
		result["status"] = "no_accepted_templates";
		return result;
	}
	const String seed_text = normalized_seed_text(normalized_config);
	uint32_t seed_value = 0;
	if (!parse_numeric_seed(seed_text, seed_value)) {
		result["ok"] = false;
		result["status"] = "blocked_until_numeric_h3maped_seed";
		result["seed_text"] = seed_text;
		return result;
	}
	const uint32_t next_state = seed_value * 0x343fdu + 0x269ec3u;
	const int32_t first_value = int32_t((next_state >> 16U) & 0x7fffu);
	const int32_t selected_index = first_value % int32_t(accepted.size());
	Dictionary selected = accepted[selected_index];
	result["ok"] = true;
	result["status"] = "h3maped_rng_selected";
	result["seed_text"] = seed_text;
	result["seed_uint32"] = int64_t(seed_value);
	result["rng_first_value"] = first_value;
	result["rng_state_after_selection_uint32"] = int64_t(next_state);
	result["selected_vector_index"] = selected_index;
	result["source_template_id"] = selected.get("id", "");
	result["source_catalog_index"] = selected.get("source_catalog_index", -1);
	result["adapted_template_id"] = selected.get("adapted_template_id", "");
	result["selected_template"] = selected;
	return result;
}

Dictionary inspect_port(const Dictionary &normalized_config) {
	const Array accepted = accepted_templates(normalized_config);
	Dictionary report;
	report["ok"] = supports_scope(normalized_config) && !accepted.is_empty();
	report["schema_id"] = "aurelion_native_rmg_small_h3maped_fresh_start_boundary_v1";
	report["schema_version"] = 1;
	report["status"] = bool(report["ok"]) ? String("h3maped_small_fresh_start_boundary_ready") : String("unsupported_scope_or_no_template");
	report["implementation_policy"] = "fresh_small_only_h3maped_exe_boundary_no_catalog_auto_no_hash_selection_no_report_treadmill_no_runtime_fallback";
	report["scope"] = "small_36x36_surface_land_only";
	report["runtime_generation_allowed"] = false;
	report["partial_materialized_payload_public_api"] = false;
	report["active_module_role"] = "thin_boundary_and_generation_gate";
	report["archived_report_treadmill_path"] = ARCHIVED_REPORT_TREADMILL_PATH;
	report["archived_overgrown_active_path"] = ARCHIVED_OVERGROWN_ACTIVE_PATH;
	report["archived_phase_ledger_path"] = ARCHIVED_PHASE_LEDGER_PATH;
	report["archived_active_boundary_path"] = ARCHIVED_ACTIVE_BOUNDARY_PATH;
	report["archived_ledger_path"] = ARCHIVED_LEDGER_PATH;
	report["older_legacy_ledger_path"] = OLDER_LEGACY_LEDGER_PATH;
	report["h3maped_binary"] = binary_verification();
	report["h3maped_binary_path"] = BINARY_PATH;
	report["h3maped_binary_sha256"] = BINARY_SHA256;
	report["spec_path"] = SPEC_PATH;
	report["template_loader_address"] = "0x49f0cd";
	report["main_phase_runner_address"] = "0x4ac552";
	report["rng_function_address"] = "0x4e7276";
	report["size_score_formula"] = "width * height * levels / 0x510; islands halves with minimum 1";
	report["size_score"] = size_score(normalized_config);
	report["h3maped_water_mode_code"] = water_mode_code(normalized_config);
	report["accepted_template_count"] = accepted.size();
	report["accepted_templates"] = accepted;
	report["selection_identity"] = selection_identity(normalized_config);
	report["active_generation_state"] = active_generation_state(normalized_config);
	report["fresh_phase_backlog"] = fresh_phase_backlog();
	report["current_gap_summary"] = current_gap_summary();
	report["normalized_config"] = normalized_config;
	return report;
}

Dictionary generation_not_ready_result(const Dictionary &normalized_config, const Dictionary &extension_profile) {
	Dictionary result;
	result["ok"] = false;
	result["status"] = "h3maped_small_fresh_start_generation_not_ready";
	result["generation_status"] = "h3maped_small_clean_restart_generation_not_ready";
	result["full_generation_status"] = "h3maped_small_clean_restart_waiting_for_executable_phase_ports";
	result["error_code"] = "h3maped_phase_port_incomplete";
	result["message"] = "The old native RMG and overgrown h3maped report path are archived. The active small-map path only verifies h3maped.exe and performs h3maped RNG template selection; runtime package output is blocked until real generator phases are ported.";
	result["runtime_generation_allowed"] = false;
	result["partial_materialized_payload_public_api"] = false;
	result["normalized_config"] = normalized_config;
	result["h3maped_small_port"] = inspect_port(normalized_config);
	result["active_generation_state"] = active_generation_state(normalized_config);
	result["replacement_slice_id"] = "native-rmg-small-h3maped-port-10184";
	result["extension_profile"] = extension_profile;
	return result;
}

Dictionary archived_legacy_disabled_result(const Dictionary &normalized_config, const Dictionary &extension_profile, const Dictionary &runtime_policy_classification) {
	Dictionary result;
	result["ok"] = false;
	result["status"] = "archived_legacy_native_rmg_disabled";
	result["generation_status"] = "archived_legacy_native_rmg_disabled";
	result["full_generation_status"] = "disabled_by_h3maped_small_reset";
	result["error_code"] = "archived_legacy_native_rmg_disabled";
	result["message"] = "The previous native RMG path is archived and cannot be used as a fallback during the small h3maped restart.";
	result["runtime_generation_allowed"] = false;
	result["partial_materialized_payload_public_api"] = false;
	result["normalized_config"] = normalized_config;
	result["runtime_policy_classification"] = runtime_policy_classification;
	result["replacement_slice_id"] = "native-rmg-small-h3maped-port-10184";
	result["extension_profile"] = extension_profile;
	return result;
}

} // namespace godot::h3maped_small_rmg
