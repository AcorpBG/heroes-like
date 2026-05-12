#include "h3maped_small_rmg.hpp"

#include <godot_cpp/classes/file_access.hpp>
#include <godot_cpp/classes/json.hpp>
#include <godot_cpp/variant/array.hpp>
#include <godot_cpp/variant/string.hpp>
#include <godot_cpp/variant/variant.hpp>

#include <algorithm>
#include <array>
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
constexpr const char *ADAPTED_CATALOG_PATH = "res://content/random_map_template_catalog.json";
constexpr const char *LEGACY_LEDGER_PATH = "src/gdextension/src/legacy_h3maped_small_rmg_inspection_ledger.cpp";

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
	int32_t border_guard_edge_count;
	const char *adapted_template_id;
	int32_t player_start_zone_count;
	int32_t treasure_zone_count;
	int32_t minimum_player_castles;
	uint8_t human_capable_source_owner_mask;
	uint8_t player_capable_source_owner_mask;
};

const TemplateEvidence SMALL_LAND_TEMPLATES[] = {
	{ "h3maped_template_000", 0, 1, 2, 1, 8, 2, 8, 8, 12, 0, "", 0, 0, 0, 0, 0 },
	{ "h3maped_template_010", 10, 1, 2, 1, 2, 2, 2, 4, 4, 0, "", 0, 0, 0, 0, 0 },
	{ "h3maped_template_011", 11, 1, 8, 1, 2, 2, 2, 6, 6, 0, "", 0, 0, 0, 0, 0 },
	{ "h3maped_template_012", 12, 1, 8, 1, 4, 2, 4, 6, 6, 0, "", 0, 0, 0, 0, 0 },
	{ "h3maped_template_013", 13, 1, 2, 1, 2, 2, 2, 6, 10, 0, "", 0, 0, 0, 0, 0 },
	{ "h3maped_template_014", 14, 1, 18, 1, 2, 2, 2, 10, 15, 0, "", 0, 0, 0, 0, 0 },
	{ "h3maped_template_017", 17, 1, 9, 1, 2, 2, 2, 6, 5, 0, "", 0, 0, 0, 0, 0 },
	{ "h3maped_template_018", 18, 1, 9, 1, 4, 2, 4, 6, 5, 0, "translated_rmg_template_019_v1", 4, 2, 4, 0x0f, 0x0f },
	{ "h3maped_template_019", 19, 1, 8, 1, 2, 2, 2, 5, 8, 0, "", 0, 0, 0, 0, 0 },
	{ "h3maped_template_020", 20, 1, 8, 1, 4, 2, 4, 5, 8, 0, "", 0, 0, 0, 0, 0 },
	{ "h3maped_template_021", 21, 1, 8, 1, 2, 2, 2, 5, 6, 0, "", 0, 0, 0, 0, 0 },
	{ "h3maped_template_022", 22, 1, 8, 1, 4, 2, 4, 5, 6, 0, "", 0, 0, 0, 0, 0 },
	{ "h3maped_template_023", 23, 1, 8, 1, 2, 2, 2, 8, 8, 0, "", 0, 0, 0, 0, 0 },
	{ "h3maped_template_024", 24, 1, 18, 1, 4, 2, 4, 9, 12, 0, "", 0, 0, 0, 0, 0 },
	{ "h3maped_template_027", 27, 1, 4, 1, 4, 2, 4, 8, 8, 0, "", 0, 0, 0, 0, 0 },
	{ "h3maped_template_028", 28, 1, 4, 1, 4, 2, 4, 8, 11, 0, "", 0, 0, 0, 0, 0 },
	{ "h3maped_template_031", 31, 1, 8, 1, 6, 2, 6, 6, 7, 0, "", 0, 0, 0, 0, 0 },
	{ "h3maped_template_044", 44, 1, 8, 1, 2, 2, 3, 8, 8, 0, "", 0, 0, 0, 0, 0 },
	{ "h3maped_template_046", 46, 1, 8, 1, 3, 2, 5, 9, 12, 0, "", 0, 0, 0, 0, 0 },
	{ "h3maped_template_047", 47, 1, 8, 1, 3, 2, 5, 7, 8, 0, "", 0, 0, 0, 0, 0 },
	{ "h3maped_template_048", 48, 1, 9, 1, 6, 2, 7, 7, 12, 0, "", 0, 0, 0, 0, 0 },
};

int32_t water_mode_code(const Dictionary &normalized) {
	const String water_mode = String(normalized.get("water_mode", "land"));
	if (water_mode == "normal_water") {
		return 1;
	}
	if (water_mode == "islands") {
		return 2;
	}
	return 0;
}

int32_t size_score(const Dictionary &normalized) {
	const int32_t width = std::max(1, int32_t(normalized.get("width", 36)));
	const int32_t height = std::max(1, int32_t(normalized.get("height", 36)));
	const int32_t level_count = std::max(1, int32_t(normalized.get("level_count", 1)));
	int32_t score = int32_t((int64_t(width) * int64_t(height) * int64_t(level_count)) / 0x510);
	if (water_mode_code(normalized) == 2) {
		score = std::max(1, score / 2);
	}
	return score;
}

bool parse_explicit_seed(const String &seed_text, uint32_t &seed_value) {
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
	report["verification_policy"] = "local_file_size_and_mz_header_checked; expected SHA-256 is the recorded reset anchor";
	if (!FileAccess::file_exists(BINARY_PATH)) {
		report["status"] = "missing";
		report["ok"] = false;
		return report;
	}
	Ref<FileAccess> file = FileAccess::open(BINARY_PATH, FileAccess::READ);
	if (file.is_null() || !file->is_open()) {
		report["status"] = "unreadable";
		report["ok"] = false;
		return report;
	}
	const int64_t size = file->get_length();
	const int32_t byte_0 = file->get_8();
	const int32_t byte_1 = file->get_8();
	const bool mz = byte_0 == 'M' && byte_1 == 'Z';
	report["actual_size_bytes"] = size;
	report["mz_header_present"] = mz;
	report["ok"] = size == BINARY_SIZE_BYTES && mz;
	report["status"] = bool(report["ok"]) ? String("verified_reset_anchor") : String("mismatch");
	return report;
}

Dictionary load_json_dictionary(const String &path) {
	if (!FileAccess::file_exists(path)) {
		return Dictionary();
	}
	Ref<FileAccess> file = FileAccess::open(path, FileAccess::READ);
	if (file.is_null() || !file->is_open()) {
		return Dictionary();
	}
	Ref<JSON> parser;
	parser.instantiate();
	if (parser->parse(file->get_as_text()) != OK || parser->get_data().get_type() != Variant::DICTIONARY) {
		return Dictionary();
	}
	return Dictionary(parser->get_data());
}

Dictionary adapted_template_for_id(const String &adapted_template_id) {
	if (adapted_template_id.is_empty()) {
		return Dictionary();
	}
	Dictionary catalog = load_json_dictionary(ADAPTED_CATALOG_PATH);
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
	return Dictionary();
}

bool player_filter_accepts(const Dictionary &filter, int32_t human_count, int32_t total_count) {
	return human_count >= int32_t(filter.get("min_human", 1))
			&& human_count <= int32_t(filter.get("max_human", 8))
			&& total_count >= int32_t(filter.get("min_total", 2))
			&& total_count <= int32_t(filter.get("max_total", 8));
}

Dictionary template_to_dictionary(const TemplateEvidence &candidate) {
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
	item["border_guard_edge_count"] = candidate.border_guard_edge_count;
	return item;
}

Array bool_bitmap_report(const std::array<bool, 8> &bitmap) {
	Array result;
	for (bool enabled : bitmap) {
		result.append(enabled);
	}
	return result;
}

Array source_owner_indices_from_mask(uint8_t mask) {
	Array result;
	for (int32_t index = 0; index < 8; ++index) {
		if ((mask & (1U << index)) != 0) {
			result.append(index);
		}
	}
	return result;
}

std::array<bool, 8> bitmap_from_mask(uint8_t mask) {
	std::array<bool, 8> bitmap = {};
	for (int32_t index = 0; index < 8; ++index) {
		bitmap[size_t(index)] = (mask & (1U << index)) != 0;
	}
	return bitmap;
}

std::array<bool, 8> selected_color_bitmap_from_normalized(const Dictionary &normalized_config) {
	std::array<bool, 8> bitmap = {};
	Dictionary constraints = normalized_config.get("player_constraints", Dictionary());
	Array selected = constraints.get("selected_color_bitmap", Array());
	for (int32_t index = 0; index < 8 && index < selected.size(); ++index) {
		bitmap[size_t(index)] = bool(selected[index]);
	}
	return bitmap;
}

Dictionary player_slot_assignment_report(uint8_t human_capable_mask, uint8_t player_capable_mask, const std::array<bool, 8> &selected_color_bitmap, int32_t human_count, int32_t computer_count) {
	Dictionary report;
	std::array<int32_t, 9> raw_mapping = {};
	raw_mapping.fill(-1);
	std::array<bool, 8> human_capable = bitmap_from_mask(human_capable_mask);
	std::array<bool, 8> player_capable = bitmap_from_mask(player_capable_mask);
	std::array<int32_t, 8> color_order = {};
	int32_t order_index = 0;
	for (int32_t color = 0; color < 8; ++color) {
		if (selected_color_bitmap[size_t(color)]) {
			color_order[size_t(order_index++)] = color;
		}
	}
	for (int32_t color = 0; color < 8; ++color) {
		if (!selected_color_bitmap[size_t(color)]) {
			color_order[size_t(order_index++)] = color;
		}
	}

	Array color_order_report;
	for (int32_t color : color_order) {
		color_order_report.append(color);
	}

	Array assignments;
	int32_t assigned_count = 0;
	int32_t source_owner_scan = 0;
	bool complete = true;
	for (; assigned_count < human_count; ++assigned_count) {
		while (source_owner_scan < 8 && !human_capable[size_t(source_owner_scan)]) {
			++source_owner_scan;
		}
		if (source_owner_scan >= 8) {
			complete = false;
			break;
		}
		player_capable[size_t(source_owner_scan)] = false;
		const int32_t actual_color = color_order[size_t(assigned_count)];
		raw_mapping[size_t(source_owner_scan + 1)] = actual_color;
		Dictionary assignment;
		assignment["source_owner_index"] = source_owner_scan;
		assignment["actual_player_color"] = actual_color;
		assignment["player_type"] = "human";
		assignments.append(assignment);
		++source_owner_scan;
	}

	const int32_t desired_total = human_count + computer_count;
	source_owner_scan = 0;
	for (; assigned_count < desired_total; ++assigned_count) {
		while (source_owner_scan < 8 && !player_capable[size_t(source_owner_scan)]) {
			++source_owner_scan;
		}
		if (source_owner_scan >= 8) {
			complete = false;
			break;
		}
		const int32_t actual_color = color_order[size_t(assigned_count)];
		raw_mapping[size_t(source_owner_scan + 1)] = actual_color;
		Dictionary assignment;
		assignment["source_owner_index"] = source_owner_scan;
		assignment["actual_player_color"] = actual_color;
		assignment["player_type"] = "computer";
		assignments.append(assignment);
		++source_owner_scan;
	}

	Array raw_slots;
	for (int32_t value : raw_mapping) {
		raw_slots.append(value);
	}
	Array colors_by_source_owner;
	for (int32_t source_owner = 0; source_owner < 8; ++source_owner) {
		colors_by_source_owner.append(raw_mapping[size_t(source_owner + 1)]);
	}

	report["status"] = complete ? String("0x4ac62a_player_slot_assignment_ported") : String("0x4ac62a_player_slot_assignment_incomplete");
	report["source"] = "h3maped 0x4ac62a..0x4ac6ec using generator+0xed8 selected-color bitmap and source zone +0x04/+0x1c capability bitmaps";
	report["selected_color_bitmap_offset"] = "generator+0xed8";
	report["assignment_slots_offset"] = "generator+0xee0";
	report["mapped_slots_offset"] = "generator+0xee4";
	report["human_capable_source_owner_indices"] = source_owner_indices_from_mask(human_capable_mask);
	report["player_capable_source_owner_indices"] = source_owner_indices_from_mask(player_capable_mask);
	report["selected_color_bitmap"] = bool_bitmap_report(selected_color_bitmap);
	report["selected_color_order"] = color_order_report;
	report["raw_ee0_slots"] = raw_slots;
	report["actual_colors_by_source_owner"] = colors_by_source_owner;
	report["assignments"] = assignments;
	report["assigned_count"] = assignments.size();
	report["desired_human_count"] = human_count;
	report["desired_computer_count"] = computer_count;
	report["materializes_runtime_players"] = false;
	return report;
}

int32_t owner_color_for_source_owner(const Array &colors_by_source_owner, int32_t source_owner_index) {
	if (source_owner_index < 0 || source_owner_index >= colors_by_source_owner.size()) {
		return -1;
	}
	return int32_t(colors_by_source_owner[source_owner_index]);
}

Dictionary early_link_placement_schedule_report(const Dictionary &template_record, const Array &runtime_zone_records, int32_t human_count, int32_t player_count) {
	Dictionary report;
	report["status"] = "0x4a1f3b_endpoint_control_flow_ported";
	report["source"] = "h3maped 0x4a1f3b walks source zone link endpoint records and calls 0x4a17f5; Value/Wide/Border Guard payloads are preserved for later 0x4a79a3";
	report["link_endpoint_consumer_address"] = "0x4a1f3b";
	report["candidate_generator_address"] = "0x4a17f5";
	report["distance_validation_address"] = "0x4a1701";
	report["payload_policy"] = "early endpoint schedule consumes only link endpoints; guard Value, Wide, and Border Guard are not consumed before late connection geometry";
	report["materializes_coordinates"] = false;
	report["materializes_connection_guards"] = false;

	Dictionary runtime_index_by_zone_id;
	for (int64_t runtime_index = 0; runtime_index < runtime_zone_records.size(); ++runtime_index) {
		if (Variant(runtime_zone_records[runtime_index]).get_type() != Variant::DICTIONARY) {
			continue;
		}
		Dictionary runtime = runtime_zone_records[runtime_index];
		runtime_index_by_zone_id[String(runtime.get("source_zone_key", ""))] = runtime_index;
	}

	Array adjacency;
	for (int64_t index = 0; index < runtime_zone_records.size(); ++index) {
		adjacency.append(Array());
	}

	Array link_seeds;
	Array links = template_record.get("links", Array());
	for (int64_t index = 0; index < links.size(); ++index) {
		if (Variant(links[index]).get_type() != Variant::DICTIONARY) {
			continue;
		}
		Dictionary link = links[index];
		if (!player_filter_accepts(link.get("player_filter", Dictionary()), human_count, player_count)) {
			continue;
		}
		const String from_id = String(link.get("from", ""));
		const String to_id = String(link.get("to", ""));
		const int32_t runtime_a = int32_t(runtime_index_by_zone_id.get(from_id, -1));
		const int32_t runtime_b = int32_t(runtime_index_by_zone_id.get(to_id, -1));
		Dictionary endpoints = link.get("source_endpoints", Dictionary());
		Dictionary guard = link.get("guard", Dictionary());

		Dictionary seed;
		seed["link_index"] = link_seeds.size();
		seed["source_from_zone_key"] = from_id;
		seed["source_to_zone_key"] = to_id;
		seed["source_endpoint_a"] = endpoints.get("zone1", -1);
		seed["source_endpoint_b"] = endpoints.get("zone2", -1);
		seed["runtime_zone_a"] = runtime_a;
		seed["runtime_zone_b"] = runtime_b;
		seed["guard_value"] = link.get("guard_value", guard.get("value", 0));
		seed["wide"] = bool(link.get("wide", false));
		seed["border_guard"] = bool(link.get("border_guard", false));
		seed["early_consumer"] = "0x4a1f3b_endpoint_only";
		seed["late_payload_consumer"] = "0x4a79a3";
		link_seeds.append(seed);

		if (runtime_a >= 0 && runtime_a < adjacency.size() && runtime_b >= 0 && runtime_b < adjacency.size()) {
			Array a = adjacency[runtime_a];
			a.append(runtime_b);
			adjacency[runtime_a] = a;
			Array b = adjacency[runtime_b];
			b.append(runtime_a);
			adjacency[runtime_b] = b;
		}
	}

	Array placement_calls;
	int32_t explicit_endpoint_attempts = 0;
	int32_t fallback_attempts_if_no_valid_endpoint = 0;
	for (int64_t runtime_index = 0; runtime_index < runtime_zone_records.size(); ++runtime_index) {
		Array available_links;
		Array linked = runtime_index < adjacency.size() ? Array(adjacency[runtime_index]) : Array();
		for (int64_t link_index = 0; link_index < linked.size(); ++link_index) {
			const int32_t linked_runtime = int32_t(linked[link_index]);
			if (linked_runtime >= 0 && linked_runtime < runtime_index) {
				available_links.append(linked_runtime);
			}
		}
		explicit_endpoint_attempts += available_links.size();
		if (available_links.is_empty()) {
			fallback_attempts_if_no_valid_endpoint += int32_t(runtime_index);
		}
		Dictionary call;
		call["pass"] = "creation";
		call["runtime_zone_index"] = runtime_index;
		call["runtime_vector_count_before_call"] = runtime_index;
		call["available_endpoint_runtime_zones"] = available_links;
		call["fallback_candidate_count_if_no_valid_endpoint"] = available_links.is_empty() ? runtime_index : 0;
		call["coordinate_status"] = "pending_0x4a17f5_candidate_math_and_0x4a1701_validation";
		placement_calls.append(call);
	}
	for (int32_t repeat = 0; repeat < 2; ++repeat) {
		for (int64_t runtime_index = 0; runtime_index < runtime_zone_records.size(); ++runtime_index) {
			Array available_links;
			Array linked = runtime_index < adjacency.size() ? Array(adjacency[runtime_index]) : Array();
			for (int64_t link_index = 0; link_index < linked.size(); ++link_index) {
				const int32_t linked_runtime = int32_t(linked[link_index]);
				if (linked_runtime >= 0 && linked_runtime < runtime_zone_records.size()) {
					available_links.append(linked_runtime);
				}
			}
			explicit_endpoint_attempts += available_links.size();
			if (available_links.is_empty()) {
				fallback_attempts_if_no_valid_endpoint += int32_t(runtime_zone_records.size());
			}
			Dictionary call;
			call["pass"] = repeat == 0 ? String("stabilization_1") : String("stabilization_2");
			call["runtime_zone_index"] = runtime_index;
			call["runtime_vector_count_before_call"] = runtime_zone_records.size();
			call["available_endpoint_runtime_zones"] = available_links;
			call["fallback_candidate_count_if_no_valid_endpoint"] = available_links.is_empty() ? runtime_zone_records.size() : 0;
			call["coordinate_status"] = "pending_0x4a17f5_candidate_math_and_0x4a1701_validation";
			placement_calls.append(call);
		}
	}

	report["creation_pass_count"] = runtime_zone_records.size();
	report["stabilization_pass_count"] = 2;
	report["link_seed_count"] = link_seeds.size();
	report["link_seeds"] = link_seeds;
	report["call_count"] = placement_calls.size();
	report["explicit_endpoint_attempt_count"] = explicit_endpoint_attempts;
	report["fallback_attempt_count_if_no_valid_endpoint"] = fallback_attempts_if_no_valid_endpoint;
	report["calls"] = placement_calls;
	return report;
}

Dictionary runtime_zone_record_setup_report(const Dictionary &template_record, const Dictionary &assignment, int32_t human_count, int32_t player_count) {
	Dictionary report;
	report["status"] = "0x4a218c_runtime_zone_record_setup_and_0x4a1f3b_endpoint_schedule_ported";
	report["source"] = "h3maped 0x4a218c consumes 0x4ac62a generator+0xee4 owner-color mapping, then schedules 0x4a1f3b endpoint placement before coordinate, terrain, footprint, and object materialization";
	report["runtime_zone_vector_source"] = "selected adapted-template active zones";
	report["owner_color_mapping_source"] = "generator+0xee4";
	report["materializes_runtime_zone_coordinates"] = false;
	report["materializes_terrain"] = false;
	report["materializes_map_cells"] = false;

	if (template_record.is_empty()) {
		report["status"] = "0x4a218c_runtime_zone_record_setup_template_missing";
		report["runtime_zone_records"] = Array();
		report["runtime_zone_count"] = 0;
		return report;
	}

	Array colors_by_source_owner = assignment.get("actual_colors_by_source_owner", Array());
	Array records;
	Array owner_colors;
	int32_t assigned_start_zone_count = 0;
	int32_t unassigned_start_zone_count = 0;
	int32_t treasure_zone_count = 0;
	int32_t minimum_player_castles = 0;
	Array zones = template_record.get("zones", Array());
	for (int64_t index = 0; index < zones.size(); ++index) {
		if (Variant(zones[index]).get_type() != Variant::DICTIONARY) {
			continue;
		}
		Dictionary zone = zones[index];
		if (!player_filter_accepts(zone.get("player_filter", Dictionary()), human_count, player_count)) {
			continue;
		}
		Dictionary ownership = zone.get("ownership", Dictionary());
		Dictionary grammar_source = zone.get("grammar_source", Dictionary());
		Dictionary player_towns = zone.get("player_towns", Dictionary());
		const int32_t source_owner_index = int32_t(ownership.get("source_owner_index", -1));
		const int32_t actual_owner_color = owner_color_for_source_owner(colors_by_source_owner, source_owner_index);
		const String role = String(zone.get("role", zone.get("type", "")));
		const int32_t min_castles = int32_t(player_towns.get("min_castles", 0));
		minimum_player_castles += min_castles;
		if (role == "human_start" || role == "computer_start") {
			if (actual_owner_color >= 0) {
				assigned_start_zone_count += 1;
			} else {
				unassigned_start_zone_count += 1;
			}
		} else if (role == "treasure") {
			treasure_zone_count += 1;
		}

		Dictionary record;
		record["runtime_zone_index"] = records.size();
		record["source_zone_key"] = zone.get("id", "");
		record["role"] = role;
		record["source_owner_index"] = source_owner_index;
		record["actual_owner_color"] = actual_owner_color;
		record["source_row"] = grammar_source.get("source_row", -1);
		record["source_bucket"] = grammar_source.get("source_bucket", -1);
		record["minimum_player_castles"] = min_castles;
		record["coordinate_status"] = "pending_0x4a1f3b_0x4a17f5_0x4a1701";
		record["terrain_status"] = "pending_0x49b53d";
		record["footprint_status"] = "pending_0x4a3a03";
		records.append(record);
		owner_colors.append(actual_owner_color);
	}

	report["runtime_zone_count"] = records.size();
	report["assigned_start_zone_count"] = assigned_start_zone_count;
	report["unassigned_start_zone_count"] = unassigned_start_zone_count;
	report["treasure_zone_count"] = treasure_zone_count;
	report["minimum_player_castles"] = minimum_player_castles;
	report["actual_owner_colors_by_runtime_zone"] = owner_colors;
	report["runtime_zone_records"] = records;
	Dictionary endpoint_schedule = early_link_placement_schedule_report(template_record, records, human_count, player_count);
	report["early_link_placement_status"] = endpoint_schedule.get("status", "");
	report["early_link_placement"] = endpoint_schedule;
	return report;
}

Dictionary selected_template_payload(const Dictionary &selected_template, const TemplateEvidence &candidate, const Dictionary &normalized_config, int32_t human_count, int32_t computer_count) {
	Dictionary payload;
	payload["source"] = "adapted project catalog resolved by import_provenance.source_template_index";
	payload["source_catalog_index_zero_based"] = selected_template.get("source_catalog_index", candidate.catalog_index);
	payload["imported_source_template_index_one_based"] = candidate.catalog_index + 1;
	payload["status"] = String(candidate.adapted_template_id).is_empty() ? String("adapted_template_not_loaded_in_clean_restart") : String("adapted_template_found");
	payload["adapted_template_id"] = candidate.adapted_template_id;
	payload["zone_count"] = selected_template.get("zone_count", candidate.zone_count);
	payload["link_count"] = selected_template.get("connection_count", candidate.connection_count);
	payload["player_start_zone_count"] = candidate.player_start_zone_count;
	payload["treasure_zone_count"] = candidate.treasure_zone_count;
	payload["minimum_player_castles_before_assignment"] = candidate.minimum_player_castles;
	payload["human_capable_source_owner_indices"] = source_owner_indices_from_mask(candidate.human_capable_source_owner_mask);
	payload["player_capable_source_owner_indices"] = source_owner_indices_from_mask(candidate.player_capable_source_owner_mask);
	Dictionary assignment = player_slot_assignment_report(candidate.human_capable_source_owner_mask, candidate.player_capable_source_owner_mask, selected_color_bitmap_from_normalized(normalized_config), human_count, computer_count);
	payload["assignment_status"] = assignment.get("status", "");
	payload["player_slot_assignment"] = assignment;
	Dictionary template_record = adapted_template_for_id(String(candidate.adapted_template_id));
	Dictionary runtime_zones = runtime_zone_record_setup_report(template_record, assignment, human_count, human_count + computer_count);
	payload["runtime_zone_build_status"] = runtime_zones.get("status", "");
	payload["runtime_zone_build"] = runtime_zones;
	payload["materialization_status"] = "blocked_until_0x4a17f5_coordinate_candidate_port";
	payload["runtime_generation_allowed"] = false;
	return payload;
}

Array clean_phase_ledger() {
	Array phases;
	struct Phase {
		const char *id;
		const char *address;
		const char *status;
	};
	const Phase PHASES[] = {
		{ "template_selection", "0x49f0cd, 0x4ac597..0x4ac5a4, 0x4e7276", "active_clean_port" },
		{ "player_slot_assignment", "0x4ac62a..0x4ac6ec", "active_clean_port" },
		{ "runtime_zone_build", "0x4a218c, 0x4a1f3b", "active_record_setup_and_endpoint_schedule_only" },
		{ "zone_footprint_placement", "0x4a3a03", "pending" },
		{ "town_and_object_placement", "0x4a8d2c, 0x4a93a2, 0x49aa93", "pending" },
		{ "roads", "0x4ab52a, 0x4aae7b, 0x4ab37f, 0x4b4243", "pending" },
		{ "connection_guards_blockers", "0x4a79a3, 0x4a61bc, 0x4a696b, 0x4a7605", "pending" },
		{ "final_writeout", "0x49b2b6", "pending" },
	};
	for (const Phase &phase : PHASES) {
		Dictionary record;
		record["phase_id"] = phase.id;
		record["h3maped_address"] = phase.address;
		record["status"] = phase.status;
		phases.append(record);
	}
	return phases;
}

} // namespace

bool supports_scope(const Dictionary &normalized_config) {
	return int32_t(normalized_config.get("width", 0)) == 36
			&& int32_t(normalized_config.get("height", 0)) == 36
			&& int32_t(normalized_config.get("level_count", 1)) == 1
			&& String(normalized_config.get("water_mode", "land")) == "land";
}

Dictionary inspect_port(const Dictionary &normalized_config) {
	Dictionary constraints = normalized_config.get("player_constraints", Dictionary());
	const int32_t human_count = int32_t(constraints.get("human_count", 1));
	const int32_t player_count = int32_t(constraints.get("player_count", 2));
	const int32_t computer_count = int32_t(constraints.get("computer_count", std::max(0, player_count - human_count)));
	const int32_t score = size_score(normalized_config);
	const bool supported = supports_scope(normalized_config);

	Array accepted_templates;
	const TemplateEvidence *selected_candidate = nullptr;
	if (supported) {
		for (const TemplateEvidence &candidate : SMALL_LAND_TEMPLATES) {
			if (score < candidate.min_size_score || score > candidate.max_size_score) {
				continue;
			}
			if (human_count < candidate.min_humans || human_count > candidate.max_humans
					|| player_count < candidate.min_total_players || player_count > candidate.max_total_players
					|| player_count < human_count) {
				continue;
			}
			accepted_templates.append(template_to_dictionary(candidate));
		}
	}

	Dictionary report;
	report["ok"] = supported && !accepted_templates.is_empty();
	report["schema_id"] = "aurelion_native_rmg_small_h3maped_clean_restart_v2";
	report["schema_version"] = 2;
	report["status"] = supported ? (accepted_templates.is_empty() ? String("h3maped_small_no_accepted_templates") : String("h3maped_small_clean_restart_template_selection_ready")) : String("unsupported_scope");
	report["scope"] = "small_36x36_surface_land_only";
	report["archive_status"] = "previous_native_catalog_auto_generator_archived_debug_only";
	report["legacy_inspection_ledger_path"] = LEGACY_LEDGER_PATH;
	report["implementation_policy"] = "strict_h3maped_exe_port_no_hash_selection_no_sample_count_fitting_no_fallback_maps";
	report["h3maped_binary"] = binary_verification();
	report["h3maped_binary_path"] = BINARY_PATH;
	report["h3maped_binary_sha256"] = BINARY_SHA256;
	report["spec_path"] = SPEC_PATH;
	report["catalog_path"] = CATALOG_SOURCE_PATH;
	report["adapted_catalog_path"] = ADAPTED_CATALOG_PATH;
	report["template_loader_address"] = "0x49f0cd";
	report["main_phase_runner_address"] = "0x4ac552";
	report["rng_function_address"] = "0x4e7276";
	report["size_score_formula"] = "width * height * levels / 0x510; islands halves with minimum 1";
	report["size_score"] = score;
	report["h3maped_water_mode_code"] = water_mode_code(normalized_config);
	report["human_count"] = human_count;
	report["computer_count"] = computer_count;
	report["player_count"] = player_count;
	report["accepted_template_count"] = accepted_templates.size();
	report["accepted_templates"] = accepted_templates;
	report["phase_ledger"] = clean_phase_ledger();
	report["generation_phase_status"] = "blocked_until_clean_h3maped_phase_ports_materialize_map_cells";
	report["runtime_generation_allowed"] = false;
	report["partial_materialized_payload_public_api"] = false;
	report["partial_materialized_payload_status"] = "archived_inspection_blocked_not_exported";
	report["normalized_config"] = normalized_config;

	uint32_t seed_value = 0;
	const String seed_text = String(normalized_config.get("normalized_seed", normalized_config.get("seed", "0")));
	if (supported && !accepted_templates.is_empty() && parse_explicit_seed(seed_text, seed_value)) {
		const uint32_t next_state = seed_value * 0x343fdu + 0x269ec3u;
		const int32_t rng_value = int32_t((next_state >> 16U) & 0x7fffu);
		const int32_t selected_index = rng_value % int32_t(accepted_templates.size());
		Dictionary selected_template = accepted_templates[selected_index];
		const int32_t source_catalog_index = int32_t(selected_template.get("source_catalog_index", -1));
		for (const TemplateEvidence &candidate : SMALL_LAND_TEMPLATES) {
			if (candidate.catalog_index == source_catalog_index) {
				selected_candidate = &candidate;
				break;
			}
		}

		Dictionary rng;
		rng["function_address"] = "0x4e7276";
		rng["seed_setter_address"] = "0x4e7269";
		rng["algorithm"] = "state = state * 0x343fd + 0x269ec3; return (state >> 16) & 0x7fff";
		rng["seed_text"] = seed_text;
		rng["seed_value_uint32"] = int64_t(seed_value);
		rng["first_state_uint32"] = int64_t(next_state);
		rng["first_value"] = rng_value;
		rng["selected_vector_index"] = selected_index;
		report["selected_template_status"] = "h3maped_rng_selected";
		report["selected_template_vector_index"] = selected_index;
		report["selected_template"] = selected_template;
		report["h3maped_rng"] = rng;
		if (selected_candidate != nullptr) {
			report["selected_template_payload"] = selected_template_payload(selected_template, *selected_candidate, normalized_config, human_count, computer_count);
		}
	} else if (supported && !accepted_templates.is_empty()) {
		Dictionary rng;
		rng["function_address"] = "0x4e7276";
		rng["seed_setter_address"] = "0x4e7269";
		rng["blocked_reason"] = "h3maped seed must be numeric; no replacement hash is allowed";
		report["selected_template_status"] = "blocked_until_numeric_h3maped_seed";
		report["h3maped_rng"] = rng;
	} else {
		report["selected_template_status"] = "none";
	}
	return report;
}

Dictionary generation_not_ready_result(const Dictionary &normalized_config, const Dictionary &extension_profile) {
	Dictionary result;
	result["ok"] = false;
	result["status"] = "h3maped_small_clean_restart_generation_not_ready";
	result["generation_status"] = "h3maped_small_clean_restart_generation_not_ready";
	result["full_generation_status"] = "h3maped_small_clean_restart_waiting_for_executable_phase_ports";
	result["error_code"] = "h3maped_phase_port_incomplete";
	result["message"] = "The archived native catalog-auto generator is disabled. The replacement is a clean small-map h3maped-derived path; it will not emit fallback maps until the executable phase ports can materialize terrain, towns, roads, blockers, guards, mines, and rewards.";
	result["normalized_config"] = normalized_config;
	result["h3maped_small_port"] = inspect_port(normalized_config);
	result["replacement_slice_id"] = "native-rmg-small-h3maped-port-10184";
	result["extension_profile"] = extension_profile;
	return result;
}

Dictionary archived_legacy_disabled_result(const Dictionary &normalized_config, const Dictionary &extension_profile, const Dictionary &runtime_policy_classification) {
	Dictionary result;
	result["ok"] = false;
	result["status"] = "archived_legacy_native_rmg_disabled";
	result["generation_status"] = "archived_legacy_native_rmg_disabled";
	result["full_generation_status"] = "archived_current_native_rmg_replaced_by_small_h3maped_port";
	result["error_code"] = "archived_legacy_native_rmg_disabled";
	result["message"] = "The previous native RMG implementation is archived as debug-only evidence. Production RMG work must use the small h3maped-derived port; out-of-scope map sizes and modes do not emit fallback maps.";
	result["normalized_config"] = normalized_config;
	result["runtime_policy_classification"] = runtime_policy_classification;
	result["native_rmg_archive_status"] = "archived_legacy_native_rmg_debug_only";
	result["legacy_inspection_ledger_path"] = LEGACY_LEDGER_PATH;
	result["replacement_slice_id"] = "native-rmg-small-h3maped-port-10184";
	result["h3maped_binary_path"] = BINARY_PATH;
	result["h3maped_binary_sha256"] = BINARY_SHA256;
	result["extension_profile"] = extension_profile;
	return result;
}

} // namespace godot::h3maped_small_rmg
