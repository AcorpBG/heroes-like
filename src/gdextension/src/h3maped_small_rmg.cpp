#include "h3maped_small_rmg.hpp"

#include <godot_cpp/classes/file_access.hpp>
#include <godot_cpp/variant/array.hpp>
#include <godot_cpp/variant/dictionary.hpp>
#include <godot_cpp/variant/string.hpp>

#include <algorithm>
#include <cerrno>
#include <cstdint>
#include <cstdlib>
#include <iterator>

namespace godot::h3maped_small_rmg {
namespace {

constexpr const char *BINARY_PATH = "/root/Downloads/h3maped.exe";
constexpr const char *BINARY_SHA256 = "4480fba145c9f885942cc668d4bce430fe39c0fa482d1a6e58f96318ab857a37";
constexpr int64_t BINARY_SIZE_BYTES = 2134016;
constexpr const char *SPEC_PATH = "/root/.openclaw/workspace/tasks/10184/artifacts/homm3-re/random-map-generation-h3maped-full-spec.md";
constexpr const char *CATALOG_SOURCE_PATH = "/root/.openclaw/workspace/tasks/10184/artifacts/homm3-re/rmg-template-catalog.json";
constexpr const char *ARCHIVED_PHASE_LEDGER_PATH = "src/gdextension/src/archived_h3maped_small_rmg_phase_ledger_20260513.cpp";
constexpr const char *ARCHIVED_ACTIVE_BOUNDARY_PATH = "src/gdextension/src/archived_h3maped_small_rmg_active_boundary_20260513.cpp";
constexpr const char *ARCHIVED_LEDGER_PATH = "src/gdextension/src/archived_h3maped_small_rmg_inspection_ledger_20260513.cpp";
constexpr const char *OLDER_LEGACY_LEDGER_PATH = "src/gdextension/src/legacy_h3maped_small_rmg_inspection_ledger.cpp";

struct TemplateEvidence {
	const char *id;
	int32_t catalog_index;
	int32_t min_size_score;
	int32_t max_size_score;
	int32_t min_humans;
	int32_t max_humans;
	int32_t min_total_players;
	int32_t max_total_players;
	int32_t zone_count;
	int32_t connection_count;
	const char *adapted_template_id;
	uint8_t human_capable_source_owner_mask;
	uint8_t player_capable_source_owner_mask;
};

struct SourceZoneEvidence {
	int32_t template_catalog_index;
	int32_t source_zone_id;
	const char *role;
	int32_t source_bucket;
	int32_t source_owner_index;
	int32_t base_size;
	int32_t min_player_castles;
	bool terrain_match_to_town;
	const char *terrain_policy;
	const char *monster_strength;
	int32_t allowed_town_count;
	int32_t allowed_terrain_count;
	int32_t minimum_ore_mines;
	int32_t minimum_wood_mines;
	int32_t minimum_rare_mines;
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

const SourceZoneEvidence TEMPLATE_018_SOURCE_ZONES[] = {
	{ 18, 1, "human_start", 0, 0, 11, 1, true, "match_to_player_town", "average", 9, 0, 1, 1, 0 },
	{ 18, 2, "human_start", 0, 1, 11, 1, true, "match_to_player_town", "average", 9, 0, 1, 1, 0 },
	{ 18, 3, "treasure", 2, -2, 11, 0, false, "all_land_h3", "strong", 0, 8, 0, 0, 5 },
	{ 18, 4, "human_start", 0, 2, 11, 1, true, "match_to_player_town", "average", 9, 0, 1, 1, 0 },
	{ 18, 5, "human_start", 0, 3, 11, 1, true, "match_to_player_town", "average", 9, 0, 1, 1, 0 },
	{ 18, 6, "treasure", 2, -2, 11, 0, false, "all_land_h3", "strong", 0, 8, 0, 0, 5 },
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
	record["source"] = "recovered h3maped template catalog parsed from /root/Downloads/h3maped.exe";
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

Dictionary player_slot_assignment_context(const TemplateEvidence &selected_template, const Dictionary &normalized_config) {
	Dictionary constraints = normalized_config.get("player_constraints", Dictionary());
	const int32_t human_count = std::max(0, int32_t(constraints.get("human_count", 1)));
	const int32_t player_count = std::max(human_count, int32_t(constraints.get("player_count", 2)));
	Dictionary context;
	context["phase_id"] = "player_slot_assignment";
	context["h3maped_anchor"] = "0x4ac62a..0x4ac6ec";
	context["status"] = "private_context_ready";
	context["selected_color_bitmap_offset"] = "generator+0xed8";
	context["assignment_slots_offset"] = "generator+0xee0";
	context["mapped_slots_offset"] = "generator+0xee4";
	context["human_capable_source_owner_mask"] = selected_template.human_capable_source_owner_mask;
	context["player_capable_source_owner_mask"] = selected_template.player_capable_source_owner_mask;
	context["human_capable_source_owner_indices"] = source_owner_indices_from_mask(selected_template.human_capable_source_owner_mask);
	context["player_capable_source_owner_indices"] = source_owner_indices_from_mask(selected_template.player_capable_source_owner_mask);

	Array selected_color_order;
	Array assignment_slots;
	Array mapped_slots;
	for (int32_t index = 0; index < 8; ++index) {
		selected_color_order.append(index);
		assignment_slots.append(-1);
		mapped_slots.append(-1);
	}

	Array assignments;
	Array human_indices = context["human_capable_source_owner_indices"];
	Array player_indices = context["player_capable_source_owner_indices"];
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

	context["selected_color_order"] = selected_color_order;
	context["raw_ee0_slots"] = assignment_slots;
	context["mapped_ee4_slots"] = mapped_slots;
	context["assignment_records"] = assignments;
	context["assigned_player_count"] = assigned_players;
	context["requested_human_count"] = human_count;
	context["requested_player_count"] = player_count;
	context["materializes_runtime_players"] = false;
	context["materializes_public_output"] = false;
	context["blocked_next"] = "runtime_zone_records_0x4a218c";
	return context;
}

Dictionary runtime_zone_records_context(const TemplateEvidence &selected_template, const Dictionary &player_context) {
	Dictionary context;
	context["phase_id"] = "runtime_zone_records";
	context["h3maped_anchor"] = "0x4a218c";
	context["initializer_anchor"] = "0x49b452";
	context["status"] = "pending_source_zone_evidence_for_selected_template";
	context["runtime_zone_vector_begin_offset"] = "generator+0x10e0";
	context["runtime_zone_vector_end_offset"] = "generator+0x10e4";
	context["runtime_zone_vector_capacity_offset"] = "generator+0x10e8";
	context["runtime_zone_record_size_bytes"] = 0x414;
	context["source_zone_pointer_offset"] = "runtime_zone+0x00";
	context["chosen_town_offset"] = "runtime_zone+0x04";
	context["chosen_terrain_offset"] = "runtime_zone+0x0c";
	context["owner_mapping_source_offset"] = "generator+0xee4";
	context["materializes_runtime_zone_coordinates"] = false;
	context["materializes_terrain"] = false;
	context["materializes_map_cells"] = false;
	context["materializes_runtime_players"] = false;
	context["materializes_public_output"] = false;
	context["blocked_next"] = "coordinate_replay_and_zone_footprints_0x4a1f3b";

	if (selected_template.catalog_index != 18) {
		return context;
	}

	const Array mapped_slots = player_context.get("mapped_ee4_slots", Array());
	Array records;
	Array actual_owner_colors_by_runtime_zone;
	int32_t assigned_start_zone_count = 0;
	int32_t unassigned_start_zone_count = 0;
	int32_t treasure_zone_count = 0;
	int32_t minimum_player_castles = 0;
	int32_t minimum_source_base_size = 0;
	for (int32_t index = 0; index < int32_t(std::size(TEMPLATE_018_SOURCE_ZONES)); ++index) {
		const SourceZoneEvidence &source_zone = TEMPLATE_018_SOURCE_ZONES[index];
		int32_t actual_owner_color = -1;
		if (source_zone.source_owner_index >= 0 && source_zone.source_owner_index < mapped_slots.size()) {
			actual_owner_color = int32_t(mapped_slots[source_zone.source_owner_index]);
		}

		Dictionary record;
		record["runtime_zone_index"] = index;
		record["source_template_catalog_index"] = source_zone.template_catalog_index;
		record["source_zone_id"] = source_zone.source_zone_id;
		record["role"] = source_zone.role;
		record["source_bucket"] = source_zone.source_bucket;
		record["source_owner_index"] = source_zone.source_owner_index;
		record["actual_owner_color"] = actual_owner_color;
		record["level"] = 0;
		record["source_base_size"] = source_zone.base_size;
		record["min_player_castles"] = source_zone.min_player_castles;
		record["terrain_match_to_town"] = source_zone.terrain_match_to_town;
		record["terrain_policy"] = source_zone.terrain_policy;
		record["monster_strength"] = source_zone.monster_strength;
		record["allowed_town_count"] = source_zone.allowed_town_count;
		record["allowed_terrain_count"] = source_zone.allowed_terrain_count;
		record["minimum_ore_mines"] = source_zone.minimum_ore_mines;
		record["minimum_wood_mines"] = source_zone.minimum_wood_mines;
		record["minimum_rare_mines"] = source_zone.minimum_rare_mines;
		records.append(record);

		actual_owner_colors_by_runtime_zone.append(actual_owner_color);
		minimum_player_castles += source_zone.min_player_castles;
		if (minimum_source_base_size == 0 || source_zone.base_size < minimum_source_base_size) {
			minimum_source_base_size = source_zone.base_size;
		}
		if (source_zone.source_owner_index >= 0) {
			if (actual_owner_color >= 0) {
				assigned_start_zone_count += 1;
			} else {
				unassigned_start_zone_count += 1;
			}
		} else {
			treasure_zone_count += 1;
		}
	}

	context["status"] = "private_context_ready";
	context["source"] = "recovered h3maped template catalog plus 0x4a218c runtime-zone record setup";
	context["selected_template_source_catalog_index"] = selected_template.catalog_index;
	context["runtime_zone_records"] = records;
	context["runtime_zone_count"] = records.size();
	context["assigned_start_zone_count"] = assigned_start_zone_count;
	context["unassigned_start_zone_count"] = unassigned_start_zone_count;
	context["treasure_zone_count"] = treasure_zone_count;
	context["minimum_player_castles"] = minimum_player_castles;
	context["minimum_source_base_size"] = minimum_source_base_size;
	context["actual_owner_colors_by_runtime_zone"] = actual_owner_colors_by_runtime_zone;
	return context;
}

Dictionary private_generation_context(const Dictionary &normalized_config) {
	Dictionary context;
	context["schema_id"] = "aurelion_h3maped_small_private_generation_context_v1";
	context["schema_version"] = 1;
	context["status"] = "template_selection_only";
	context["runtime_generation_allowed"] = false;
	context["partial_materialized_payload_public_api"] = false;
	Dictionary selection = selection_identity(normalized_config);
	context["selection_identity"] = selection;
	Array completed_phases;
	if (!bool(selection.get("ok", false))) {
		context["completed_phase_ids"] = completed_phases;
		context["blocked_next"] = "template_selection";
		return context;
	}
	completed_phases.append("template_selection");
	const TemplateEvidence *selected_template = template_for_catalog_index(int32_t(selection.get("source_catalog_index", -1)));
	if (selected_template != nullptr) {
		const Dictionary player_context = player_slot_assignment_context(*selected_template, normalized_config);
		const Dictionary runtime_zone_context = runtime_zone_records_context(*selected_template, player_context);
		context["player_context"] = player_context;
		completed_phases.append("player_slot_assignment");
		context["runtime_zone_context"] = runtime_zone_context;
		if (String(runtime_zone_context.get("status", "")) == "private_context_ready") {
			completed_phases.append("runtime_zone_records");
			context["status"] = "runtime_zone_records_private_context_ready";
			context["blocked_next"] = "coordinate_replay_and_zone_footprints_0x4a1f3b";
		} else {
			context["status"] = "player_slot_assignment_private_context_ready";
			context["blocked_next"] = "runtime_zone_records_0x4a218c";
		}
	} else {
		context["status"] = "selected_template_record_missing";
		context["blocked_next"] = "player_slot_assignment";
	}
	context["completed_phase_ids"] = completed_phases;
	context["completed_phase_count"] = completed_phases.size();
	return context;
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
		"0x4a1f3b/0x4a17f5/0x4a1701/0x4a1ad8/0x4a19ed/0x4a3a03/0x4a2777/0x4a325d",
		"0x4a3f27/0x4bcff5/0x4bb74b/0x4bc5f0/0x49acf6",
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
		phase["status"] = index == 0 ? String("active_boundary_only") : (index == 1 || index == 2 ? String("private_context_ready") : String("pending_strict_port"));
		phase["materializes_public_output"] = false;
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
	report["schema_id"] = "aurelion_native_rmg_small_h3maped_fresh_boundary_v1";
	report["schema_version"] = 1;
	report["status"] = bool(report["ok"]) ? String("h3maped_small_fresh_boundary_ready") : String("unsupported_scope_or_no_template");
	report["implementation_policy"] = "fresh_small_only_h3maped_exe_boundary_no_catalog_auto_no_hash_selection_no_per_case_materialization_no_runtime_fallback";
	report["scope"] = "small_36x36_surface_land_only";
	report["runtime_generation_allowed"] = false;
	report["partial_materialized_payload_public_api"] = false;
	report["archive_status"] = "previous_phase_ledger_archived_out_of_build";
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
	report["private_generation_context"] = private_generation_context(normalized_config);
	report["restart_phase_backlog"] = restart_backlog();
	report["materialized_phase_status"] = "none_after_fresh_restart";
	report["blocked_before_materialization"] = "waiting_for_strict_h3maped_small_phase_ports_from_0x4ac552";
	report["explicitly_absent_reports"] = "player slots, runtime zones, coordinates, terrain, towns, roads, blockers, guards, mines, rewards, and final writeout are not exposed until implemented as generator phases";
	report["normalized_config"] = normalized_config;
	return report;
}

Dictionary generation_not_ready_result(const Dictionary &normalized_config, const Dictionary &extension_profile) {
	Dictionary result;
	result["ok"] = false;
	result["status"] = "h3maped_small_fresh_generation_not_ready";
	result["generation_status"] = "h3maped_small_clean_restart_generation_not_ready";
	result["full_generation_status"] = "h3maped_small_clean_restart_waiting_for_executable_phase_ports";
	result["error_code"] = "h3maped_phase_port_incomplete";
	result["message"] = "Small h3maped-derived RMG is a fresh executable-anchored boundary. Runtime package generation is blocked until the h3maped small-map phase sequence is ported without catalog-auto or per-case fallback logic.";
	result["runtime_generation_allowed"] = false;
	result["partial_materialized_payload_public_api"] = false;
	result["normalized_config"] = normalized_config;
	result["h3maped_small_port"] = inspect_port(normalized_config);
	result["private_generation_context"] = private_generation_context(normalized_config);
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
