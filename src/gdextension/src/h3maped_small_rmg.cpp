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
constexpr const char *CATALOG_SOURCE_PATH = "/root/.openclaw/workspace/tasks/10184/artifacts/homm3-re/rmg-template-catalog.json";
constexpr const char *PROJECT_TEMPLATE_CATALOG_PATH = "res://content/random_map_template_catalog.json";
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

struct H3MapedRng {
	uint32_t state = 0;

	int32_t next() {
		state = state * 0x343fdu + 0x269ec3u;
		return int32_t((state >> 16U) & 0x7fffu);
	}
};

const TemplateEvidence SMALL_LAND_TEMPLATES[] = {
	{ "h3maped_template_000", 0, 1, 2, 1, 8, 2, 8, 8, 12, "", 0xff, 0xff },
	{ "h3maped_template_010", 10, 1, 2, 1, 2, 2, 2, 4, 4, "", 0x03, 0x03 },
	{ "h3maped_template_011", 11, 1, 8, 1, 2, 2, 2, 6, 6, "", 0x03, 0x03 },
	{ "h3maped_template_012", 12, 1, 8, 1, 4, 2, 4, 6, 6, "", 0x0f, 0x0f },
	{ "h3maped_template_013", 13, 1, 2, 1, 2, 2, 2, 6, 10, "", 0x03, 0x03 },
	{ "h3maped_template_014", 14, 1, 18, 1, 2, 2, 2, 10, 15, "", 0x03, 0x03 },
	{ "h3maped_template_017", 17, 1, 9, 1, 2, 2, 2, 6, 5, "", 0x03, 0x03 },
	{ "h3maped_template_018", 18, 1, 9, 1, 4, 2, 4, 6, 5, "translated_rmg_template_019_v1", 0x0f, 0x0f },
	{ "h3maped_template_019", 19, 1, 8, 1, 2, 2, 2, 5, 8, "", 0x03, 0x03 },
	{ "h3maped_template_020", 20, 1, 8, 1, 4, 2, 4, 5, 8, "", 0x0f, 0x0f },
	{ "h3maped_template_021", 21, 1, 8, 1, 2, 2, 2, 5, 6, "", 0x03, 0x03 },
	{ "h3maped_template_022", 22, 1, 8, 1, 4, 2, 4, 5, 6, "", 0x03, 0x03 },
	{ "h3maped_template_023", 23, 1, 8, 1, 2, 2, 2, 8, 8, "", 0x03, 0x03 },
	{ "h3maped_template_024", 24, 1, 18, 1, 4, 2, 4, 9, 12, "", 0x0f, 0x0f },
	{ "h3maped_template_027", 27, 1, 4, 1, 4, 2, 4, 8, 8, "", 0x0f, 0x0f },
	{ "h3maped_template_028", 28, 1, 4, 1, 4, 2, 4, 8, 11, "", 0x0f, 0x0f },
	{ "h3maped_template_031", 31, 1, 8, 1, 6, 2, 6, 6, 7, "", 0x3f, 0x3f },
	{ "h3maped_template_044", 44, 1, 8, 1, 2, 2, 3, 8, 8, "", 0x03, 0x07 },
	{ "h3maped_template_046", 46, 1, 8, 1, 3, 2, 5, 9, 12, "", 0x07, 0x1f },
	{ "h3maped_template_047", 47, 1, 8, 1, 3, 2, 5, 7, 8, "", 0x07, 0x1f },
	{ "h3maped_template_048", 48, 1, 9, 1, 6, 2, 7, 7, 12, "", 0x3f, 0x7f },
};

int32_t water_mode_code(const Dictionary &normalized_config) {
	const String water_mode = String(normalized_config.get("water_mode", "land"));
	if (water_mode == "normal_water") {
		return 1;
	}
	if (water_mode == "islands") {
		return 2;
	}
	return 0;
}

int32_t size_score(const Dictionary &normalized_config) {
	const int32_t width = std::max(1, int32_t(normalized_config.get("width", 36)));
	const int32_t height = std::max(1, int32_t(normalized_config.get("height", 36)));
	const int32_t levels = std::max(1, int32_t(normalized_config.get("level_count", 1)));
	int32_t score = int32_t((int64_t(width) * int64_t(height) * int64_t(levels)) / 0x510);
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

Dictionary template_to_dictionary(const TemplateEvidence &template_evidence) {
	Dictionary record;
	record["id"] = template_evidence.id;
	record["source_catalog_index"] = template_evidence.catalog_index;
	record["min_size_score"] = template_evidence.min_size_score;
	record["max_size_score"] = template_evidence.max_size_score;
	record["min_humans"] = template_evidence.min_humans;
	record["max_humans"] = template_evidence.max_humans;
	record["min_total_players"] = template_evidence.min_total_players;
	record["max_total_players"] = template_evidence.max_total_players;
	record["zone_count"] = template_evidence.zone_count;
	record["connection_count"] = template_evidence.connection_count;
	record["adapted_template_id"] = template_evidence.adapted_template_id;
	record["human_capable_source_owner_mask"] = template_evidence.human_capable_source_owner_mask;
	record["player_capable_source_owner_mask"] = template_evidence.player_capable_source_owner_mask;
	record["source"] = "recovered h3maped template catalog anchored to /root/Downloads/h3maped.exe";
	return record;
}

const TemplateEvidence *template_for_catalog_index(int32_t catalog_index) {
	for (const TemplateEvidence &candidate : SMALL_LAND_TEMPLATES) {
		if (candidate.catalog_index == catalog_index) {
			return &candidate;
		}
	}
	return nullptr;
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
	Array records;
	if (!supports_scope(normalized_config)) {
		return records;
	}
	const int32_t score = size_score(normalized_config);
	Dictionary constraints = normalized_config.get("player_constraints", Dictionary());
	const int32_t human_count = int32_t(constraints.get("human_count", 1));
	const int32_t player_count = int32_t(constraints.get("player_count", 2));
	for (const TemplateEvidence &candidate : SMALL_LAND_TEMPLATES) {
		if (score < candidate.min_size_score || score > candidate.max_size_score) {
			continue;
		}
		if (human_count < candidate.min_humans || human_count > candidate.max_humans) {
			continue;
		}
		if (player_count < candidate.min_total_players || player_count > candidate.max_total_players) {
			continue;
		}
		records.append(template_to_dictionary(candidate));
	}
	return records;
}

Dictionary player_slot_assignment_phase(const TemplateEvidence &selected_template, const Dictionary &normalized_config) {
	Dictionary constraints = normalized_config.get("player_constraints", Dictionary());
	const int32_t human_count = std::max(0, int32_t(constraints.get("human_count", 1)));
	const int32_t player_count = std::max(human_count, int32_t(constraints.get("player_count", 2)));

	Dictionary phase;
	phase["phase_id"] = "player_slot_assignment";
	phase["status"] = "active_runtime_state_ready";
	phase["h3maped_anchor"] = "0x4ac62a..0x4ac6ec";
	phase["selected_color_bitmap_offset"] = "generator+0xed8";
	phase["assignment_slots_offset"] = "generator+0xee0";
	phase["mapped_slots_offset"] = "generator+0xee4";
	phase["human_capable_source_owner_mask"] = selected_template.human_capable_source_owner_mask;
	phase["player_capable_source_owner_mask"] = selected_template.player_capable_source_owner_mask;
	phase["human_capable_source_owner_indices"] = source_owner_indices_from_mask(selected_template.human_capable_source_owner_mask);
	phase["player_capable_source_owner_indices"] = source_owner_indices_from_mask(selected_template.player_capable_source_owner_mask);

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
	for (int32_t human = 0; human < human_count && human < human_indices.size(); ++human) {
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
	for (int32_t source_index = 0; assigned_players < player_count && source_index < player_indices.size(); ++source_index) {
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
	phase["requested_human_count"] = human_count;
	phase["requested_player_count"] = player_count;
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
	Dictionary template_record = find_project_template_record(adapted_template_id, catalog_load);
	phase["project_catalog_load"] = catalog_load;
	phase["project_template_id"] = adapted_template_id;
	if (template_record.is_empty() || Variant(template_record.get("zones", Variant())).get_type() != Variant::ARRAY) {
		return phase;
	}

	Array mapped_slots = player_phase.get("mapped_ee4_slots", Array());
	Array zones = template_record.get("zones", Array());
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
		Dictionary mine_requirements = zone.get("mine_requirements", Dictionary());
		Dictionary minimum_by_category = mine_requirements.get("minimum_by_category", Dictionary());
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
		record["min_player_castles"] = min_castles;
		record["terrain_match_to_town"] = bool(Dictionary(zone.get("terrain", Dictionary())).get("match_to_faction", false));
		record["terrain_policy"] = Array(Dictionary(zone.get("terrain", Dictionary())).get("allowed", Array())).is_empty() ? String("match_to_player_town") : String("all_land_h3");
		record["monster_strength"] = Dictionary(zone.get("monster_policy", Dictionary())).get("strength", "");
		record["minimum_ore_mines"] = minimum_by_category.get("ore", 0);
		record["minimum_wood_mines"] = minimum_by_category.get("timber", 0);
		record["minimum_rare_mines"] = int32_t(minimum_by_category.get("gold", 0)) + int32_t(minimum_by_category.get("quicksilver", 0)) + int32_t(minimum_by_category.get("ember_salt", 0)) + int32_t(minimum_by_category.get("lens_crystal", 0)) + int32_t(minimum_by_category.get("cut_gems", 0));
		runtime_records.append(record);
		actual_owner_colors.append(actual_owner);
	}
	if (minimum_source_base_size == 0x7fffffff) {
		minimum_source_base_size = 0;
	}

	phase["status"] = "active_runtime_state_ready";
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

Dictionary small_pipeline_state(const Dictionary &normalized_config) {
	Dictionary state;
	state["schema_id"] = "aurelion_h3maped_small_generation_state_v1";
	state["runtime_generation_allowed"] = false;
	state["partial_materialized_payload_public_api"] = false;
	state["materializes_runtime_players"] = false;
	state["materializes_map_cells"] = false;
	state["materializes_public_output"] = false;

	Dictionary selection = selection_identity(normalized_config);
	state["selection_identity"] = selection;
	if (!bool(selection.get("ok", false))) {
		state["status"] = "blocked_before_template_selection";
		state["completed_phase_ids"] = Array();
		state["completed_phase_count"] = 0;
		state["blocked_next"] = "template_selection";
		return state;
	}

	const TemplateEvidence *selected_template = template_for_catalog_index(int32_t(selection.get("source_catalog_index", -1)));
	if (selected_template == nullptr) {
		state["status"] = "blocked_missing_selected_template";
		state["completed_phase_ids"] = Array();
		state["completed_phase_count"] = 0;
		state["blocked_next"] = "template_selection";
		return state;
	}

	Array completed_phases;
	completed_phases.append("template_selection");
	Dictionary player_phase = player_slot_assignment_phase(*selected_template, normalized_config);
	completed_phases.append("player_slot_assignment");
	Dictionary runtime_zone_phase = runtime_zone_records_phase(selection, player_phase);
	if (String(runtime_zone_phase.get("status", "")) == "active_runtime_state_ready") {
		completed_phases.append("runtime_zone_records");
	}
	state["status"] = completed_phases.size() >= 3 ? String("runtime_zone_records_active_runtime_state_ready") : String("player_slot_assignment_active_runtime_state_ready");
	state["completed_phase_ids"] = completed_phases;
	state["completed_phase_count"] = completed_phases.size();
	state["player_slot_assignment"] = player_phase;
	state["runtime_zone_records"] = runtime_zone_phase;
	state["blocked_next"] = completed_phases.size() >= 3 ? String("coordinate_replay_and_zone_footprints_0x4a1f3b") : String("runtime_zone_records_0x4a218c");
	return state;
}

Array restart_backlog() {
	Array phases;
	const char *ids[] = {
		"template_selection",
		"player_slot_assignment",
		"runtime_zone_records",
		"coordinate_replay_and_zone_footprints",
		"terrain_writeout_and_visuals",
		"town_object_placement",
		"roads_and_rivers",
		"connections_blockers_and_guards",
		"mines_rewards_and_objects",
		"final_h3m_writeout",
	};
	const char *anchors[] = {
		"0x49f0cd/0x4ac597/0x4e7276",
		"0x4ac62a..0x4ac6ec",
		"0x4a218c/0x49b3c1/0x49b53d",
		"0x4a1f3b/0x4a17f5/0x4a1701/0x4a1ad8/0x4a19ed/0x4a3a03/0x4ccb64/0x4ccdfc/0x4a2777/0x4a325d/0x4a3710",
		"0x4a3f27/0x4bcff5/0x4bb74b/0x4bc5f0/0x49acf6/0x49b2b6",
		"0x4a8d2c/0x4a8db2/0x4a93a2/0x49aa93/0x49a09c/0x49ba89",
		"0x4ab52a/0x4aae7b/0x4ab37f/0x4b4243",
		"0x4a79a3/0x4a61bc/0x4a696b/0x4a6cf2/0x4a7605/0x4a65a5/0x4a5e03",
		"0x49aa93 object placement family",
		"0x49b2b6",
	};
	for (int32_t index = 0; index < 10; ++index) {
		Dictionary phase;
		phase["id"] = ids[index];
		phase["h3maped_anchors"] = anchors[index];
		phase["status"] = index == 0 ? String("active_boundary_only") : (index <= 2 ? String("active_runtime_state_ready") : String("pending_strict_port"));
		phase["materializes_public_output"] = false;
		phase["requires_exe_derived_implementation_before_runtime"] = index > 2;
		phases.append(phase);
	}
	return phases;
}

} // namespace

bool supports_scope(const Dictionary &normalized_config) {
	return int32_t(normalized_config.get("width", 36)) == 36
			&& int32_t(normalized_config.get("height", 36)) == 36
			&& int32_t(normalized_config.get("level_count", 1)) == 1
			&& String(normalized_config.get("water_mode", "land")) == "land";
}

Dictionary selection_identity(const Dictionary &normalized_config) {
	Dictionary result;
	result["ok"] = false;
	result["status"] = "unsupported_scope";
	result["template_selection_mode"] = "h3maped_exe_rng";
	result["rng_function_address"] = "0x4e7276";
	result["seed_setter_address"] = "0x4e7269";
	result["algorithm"] = "state = state * 0x343fd + 0x269ec3; return (state >> 16) & 0x7fff";
	result["supported_scope"] = supports_scope(normalized_config);
	if (!supports_scope(normalized_config)) {
		return result;
	}

	const Array accepted = accepted_templates(normalized_config);
	result["accepted_template_count"] = accepted.size();
	if (accepted.is_empty()) {
		result["status"] = "no_accepted_templates";
		return result;
	}

	const String seed_text = String(normalized_config.get("normalized_seed", normalized_config.get("seed", "0")));
	uint32_t seed_value = 0;
	if (!parse_numeric_seed(seed_text, seed_value)) {
		result["status"] = "blocked_until_numeric_h3maped_seed";
		result["seed_text"] = seed_text;
		return result;
	}

	H3MapedRng rng;
	rng.state = seed_value;
	const int32_t first_value = rng.next();
	const int32_t selected_index = first_value % int32_t(accepted.size());
	Dictionary selected_template = accepted[selected_index];
	result["ok"] = true;
	result["status"] = "h3maped_rng_selected";
	result["seed_text"] = seed_text;
	result["seed_uint32"] = int64_t(seed_value);
	result["rng_first_value"] = first_value;
	result["rng_state_after_selection_uint32"] = int64_t(rng.state);
	result["selected_vector_index"] = selected_index;
	result["source_template_id"] = selected_template.get("id", "");
	result["source_catalog_index"] = selected_template.get("source_catalog_index", -1);
	result["adapted_template_id"] = selected_template.get("adapted_template_id", "");
	result["selected_template"] = selected_template;
	return result;
}

Dictionary inspect_port(const Dictionary &normalized_config) {
	const Array accepted = accepted_templates(normalized_config);

	Dictionary report;
	report["ok"] = supports_scope(normalized_config) && !accepted.is_empty();
	report["schema_id"] = "aurelion_native_rmg_small_h3maped_restart_boundary_v2";
	report["schema_version"] = 2;
	report["status"] = bool(report["ok"]) ? String("h3maped_small_restart_boundary_ready") : String("unsupported_scope_or_no_template");
	report["implementation_policy"] = "small_only_h3maped_exe_restart_no_catalog_auto_no_hash_selection_no_private_phase_ledger_no_runtime_fallback";
	report["scope"] = "small_36x36_surface_land_only";
	report["runtime_generation_allowed"] = false;
	report["partial_materialized_payload_public_api"] = false;
	report["archive_status"] = "overgrown_active_port_archived_out_of_build";
	report["archived_overgrown_active_path"] = ARCHIVED_OVERGROWN_ACTIVE_PATH;
	report["archived_phase_ledger_path"] = ARCHIVED_PHASE_LEDGER_PATH;
	report["archived_active_boundary_path"] = ARCHIVED_ACTIVE_BOUNDARY_PATH;
	report["archived_ledger_path"] = ARCHIVED_LEDGER_PATH;
	report["older_legacy_ledger_path"] = OLDER_LEGACY_LEDGER_PATH;
	report["h3maped_binary"] = binary_verification();
	report["spec_path"] = SPEC_PATH;
	report["catalog_path"] = CATALOG_SOURCE_PATH;
	report["template_loader_address"] = "0x49f0cd";
	report["main_phase_runner_address"] = "0x4ac552";
	report["rng_function_address"] = "0x4e7276";
	report["size_score_formula"] = "width * height * levels / 0x510; islands halves with minimum 1";
	report["size_score"] = size_score(normalized_config);
	report["h3maped_water_mode_code"] = water_mode_code(normalized_config);
	report["accepted_template_count"] = accepted.size();
	report["accepted_templates"] = accepted;
	report["selection_identity"] = selection_identity(normalized_config);
	report["small_generation_state"] = small_pipeline_state(normalized_config);
	report["restart_phase_backlog"] = restart_backlog();
	report["materialized_phase_status"] = "player_slot_assignment_state_only";
	report["blocked_before_materialization"] = "waiting_for_strict_h3maped_small_phase_ports_from_0x4ac552";
	report["explicitly_absent_reports"] = "runtime zones, coordinates, terrain, towns, roads, blockers, guards, mines, rewards, and final writeout are absent until implemented as runtime generator phases";
	report["normalized_config"] = normalized_config;
	return report;
}

Dictionary generation_not_ready_result(const Dictionary &normalized_config, const Dictionary &extension_profile) {
	Dictionary result;
	result["ok"] = false;
	result["status"] = "h3maped_small_restart_generation_not_ready";
	result["generation_status"] = "h3maped_small_clean_restart_generation_not_ready";
	result["full_generation_status"] = "h3maped_small_clean_restart_waiting_for_executable_phase_ports";
	result["error_code"] = "h3maped_phase_port_incomplete";
	result["message"] = "Small h3maped-derived RMG has been restarted from a compact executable-anchored boundary. Runtime package generation is blocked until the h3maped small-map phase sequence is ported without catalog-auto or per-case fallback logic.";
	result["runtime_generation_allowed"] = false;
	result["partial_materialized_payload_public_api"] = false;
	result["normalized_config"] = normalized_config;
	result["h3maped_small_port"] = inspect_port(normalized_config);
	result["small_generation_state"] = small_pipeline_state(normalized_config);
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
