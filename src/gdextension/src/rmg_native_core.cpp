#include "rmg_native_core.hpp"

#include <algorithm>
#include <cctype>
#include <cerrno>
#include <cstdlib>
#include <limits>
#include <sstream>

namespace aurelion::rmg_native_core {
namespace {

std::string trim(const std::string &value) {
	size_t begin = 0;
	while (begin < value.size() && std::isspace(static_cast<unsigned char>(value[begin])) != 0) {
		++begin;
	}
	size_t end = value.size();
	while (end > begin && std::isspace(static_cast<unsigned char>(value[end - 1])) != 0) {
		--end;
	}
	return value.substr(begin, end - begin);
}

std::string lower_ascii(std::string value) {
	for (char &ch : value) {
		ch = static_cast<char>(std::tolower(static_cast<unsigned char>(ch)));
	}
	return value;
}

std::vector<std::string> split(const std::string &value, char delimiter) {
	std::vector<std::string> parts;
	std::string current;
	std::istringstream stream(value);
	while (std::getline(stream, current, delimiter)) {
		parts.push_back(trim(current));
	}
	if (!value.empty() && value.back() == delimiter) {
		parts.emplace_back();
	}
	return parts;
}

bool parse_i32(const std::string &raw, int32_t &out_value) {
	char *end = nullptr;
	errno = 0;
	const long parsed = std::strtol(raw.c_str(), &end, 10);
	if (errno != 0 || end == raw.c_str() || *end != '\0') {
		return false;
	}
	if (parsed < std::numeric_limits<int32_t>::min() || parsed > std::numeric_limits<int32_t>::max()) {
		return false;
	}
	out_value = static_cast<int32_t>(parsed);
	return true;
}

bool parse_u32(const std::string &raw, uint32_t &out_value) {
	char *end = nullptr;
	errno = 0;
	const unsigned long parsed = std::strtoul(raw.c_str(), &end, 10);
	if (errno != 0 || end == raw.c_str() || *end != '\0') {
		return false;
	}
	if (parsed > std::numeric_limits<uint32_t>::max()) {
		return false;
	}
	out_value = static_cast<uint32_t>(parsed);
	return true;
}

std::string normalize_size_class(const std::string &raw) {
	const std::string value = lower_ascii(trim(raw));
	if (value == "s" || value == "small" || value == "homm3_small") {
		return "small";
	}
	if (value == "m" || value == "medium" || value == "homm3_medium") {
		return "medium";
	}
	return value;
}

std::string normalize_water_mode(const std::string &raw) {
	const std::string value = lower_ascii(trim(raw));
	if (value == "none" || value == "no_water" || value == "nowater" || value == "land") {
		return "land";
	}
	if (value == "normal" || value == "normal_water" || value == "mixed") {
		return "normal_water";
	}
	if (value == "water" || value == "islands") {
		return "islands";
	}
	return value;
}

std::string json_escape(const std::string &value) {
	std::string out;
	out.reserve(value.size() + 8);
	for (const unsigned char ch : value) {
		switch (ch) {
			case '\\':
				out += "\\\\";
				break;
			case '"':
				out += "\\\"";
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
			default:
				if (ch < 0x20) {
					static constexpr char HEX[] = "0123456789abcdef";
					out += "\\u00";
					out.push_back(HEX[(ch >> 4) & 0x0f]);
					out.push_back(HEX[ch & 0x0f]);
				} else {
					out.push_back(static_cast<char>(ch));
				}
				break;
		}
	}
	return out;
}

int32_t i8_from_u32_byte(uint32_t value, uint32_t shift) {
	return int32_t(int8_t((value >> shift) & 0xffU));
}

int32_t map_width_for_size(const std::string &size_class) {
	if (size_class == "medium") {
		return 72;
	}
	if (size_class == "small") {
		return 36;
	}
	return 0;
}

bool supported_one_level_land_scope(const ControlledCase &controlled_case) {
	return controlled_case.parse_ok
			&& (controlled_case.size_class == "small" || controlled_case.size_class == "medium")
			&& controlled_case.water_mode == "land"
			&& controlled_case.level_count == 1;
}

void append_initialized_generated_cell_checkpoint_json(std::ostream &out, const ControlledCase &controlled_case) {
	constexpr uint32_t WORD_0X20_DEFAULT = 0xffff7fbcU;
	constexpr uint32_t WORD_0X24_DEFAULT = 0x00000548U;
	constexpr uint32_t WORD_0X28_DEFAULT = (1U << 25U) | (1U << 27U);
	constexpr int32_t TERRAIN_CODE_DEFAULT = 8;
	const int32_t map_width = map_width_for_size(controlled_case.size_class);
	const int32_t map_height = map_width;
	const int32_t map_level_count = controlled_case.level_count;
	const int64_t cell_count = int64_t(map_width) * int64_t(map_height) * int64_t(map_level_count);
	const bool supported = supported_one_level_land_scope(controlled_case) && map_width > 0 && cell_count >= 0;
	out << "{\n";
	out << "    \"schema_id\": \"h3maped_private_state_checkpoint_0x4a4c8e_generated_cells_v1\",\n";
	out << "    \"checkpoint_id\": \"plain_cpp_initial_generated_cell_defaults\",\n";
	out << "    \"checkpoint_scope\": \"native_generated_cell_private_grid\",\n";
	out << "    \"h3maped_entry_anchor\": \"0x49ecf2_constructor_defaults_before_0x4a325d_owner_write\",\n";
	out << "    \"plain_cpp_stage\": \"constructor_default_words_only_before_runtime_zone_owner_materialization\",\n";
	out << "    \"h3maped_cell_base_pointer\": \"generator+0x14\",\n";
	out << "    \"h3maped_cell_stride_bytes\": 48,\n";
	out << "    \"h3maped_words_per_cell\": 12,\n";
	out << "    \"cell_count\": " << (supported ? cell_count : 0) << ",\n";
	out << "    \"width\": " << (supported ? map_width : 0) << ",\n";
	out << "    \"height\": " << (supported ? map_height : 0) << ",\n";
	out << "    \"level_count\": " << (supported ? map_level_count : 0) << ",\n";
	out << "    \"word_0x20_source\": \"cell_dword_index_8\",\n";
	out << "    \"word_0x24_source\": \"cell_dword_index_9\",\n";
	out << "    \"word_0x28_source\": \"cell_dword_index_10\",\n";
	out << "    \"word_0x2c_source\": \"cell_dword_index_11\",\n";
	out << "    \"owner_byte2_source\": \"0x4a4ccc sign-extends cell +0x20 byte 2\",\n";
	out << "    \"status\": \"" << (supported ? "available_constructor_defaults_only" : "blocked_unsupported_or_invalid_scope") << "\",\n";
	out << "    \"word_0x2c_available\": false,\n";
	out << "    \"default_word_0x20\": " << WORD_0X20_DEFAULT << ",\n";
	out << "    \"default_word_0x24\": " << WORD_0X24_DEFAULT << ",\n";
	out << "    \"default_word_0x28\": " << WORD_0X28_DEFAULT << ",\n";
	out << "    \"default_terrain_code\": " << TERRAIN_CODE_DEFAULT << ",\n";
	out << "    \"word_0x28_bit22_count\": 0,\n";
	out << "    \"word_0x28_bit25_count\": " << (supported ? cell_count : 0) << ",\n";
	out << "    \"word_0x28_bit26_count\": 0,\n";
	out << "    \"word_0x28_bit27_count\": " << (supported ? cell_count : 0) << ",\n";
	out << "    \"word_0x28_bit28_count\": 0,\n";
	out << "    \"word_0x2c_bit0_count\": 0,\n";
	out << "    \"owner_byte2_signed_histogram\": {\"-1\": " << (supported ? cell_count : 0) << "},\n";
	out << "    \"owner_byte3_signed_histogram\": {\"-1\": " << (supported ? cell_count : 0) << "},\n";
	out << "    \"word_0x24_terrain_histogram\": {\"8\": " << (supported ? cell_count : 0) << "},\n";
	out << "    \"word_0x24_art_histogram\": {\"21\": " << (supported ? cell_count : 0) << "},\n";
	out << "    \"word_0x28_top_byte_histogram\": {\"10\": " << (supported ? cell_count : 0) << "},\n";
	out << "    \"records\": [";
	if (supported) {
		for (int64_t flat = 0; flat < cell_count; ++flat) {
			if (flat != 0) {
				out << ",";
			}
			const int32_t level_tile_count = map_width * map_height;
			const int32_t level = int32_t(flat / level_tile_count);
			const int32_t remainder = int32_t(flat % level_tile_count);
			out << "{";
			out << "\"flat\":" << flat << ",";
			out << "\"x\":" << (remainder % map_width) << ",";
			out << "\"y\":" << (remainder / map_width) << ",";
			out << "\"level\":" << level << ",";
			out << "\"word_0x20\":" << WORD_0X20_DEFAULT << ",";
			out << "\"word_0x24\":" << WORD_0X24_DEFAULT << ",";
			out << "\"word_0x28\":" << WORD_0X28_DEFAULT << ",";
			out << "\"owner_byte2_signed\":" << i8_from_u32_byte(WORD_0X20_DEFAULT, 16U) << ",";
			out << "\"owner_byte3_signed\":" << i8_from_u32_byte(WORD_0X20_DEFAULT, 24U) << ",";
			out << "\"terrain_code\":" << TERRAIN_CODE_DEFAULT;
			out << "}";
		}
	}
	out << "]\n";
	out << "  }";
}

} // namespace

ControlledCase parse_controlled_case(const std::string &raw) {
	ControlledCase controlled_case;
	controlled_case.raw = raw;
	const std::vector<std::string> parts = split(raw, ':');
	if (parts.size() < 6) {
		controlled_case.parse_error = "expected id:size_class:players:seed:water_mode:level_count[:human_count[:computer_count[:setup_object_0x44]]]";
		return controlled_case;
	}
	controlled_case.id = parts[0];
	controlled_case.size_class = normalize_size_class(parts[1]);
	controlled_case.water_mode = normalize_water_mode(parts[4]);
	if (controlled_case.id.empty()) {
		controlled_case.parse_error = "missing case id";
		return controlled_case;
	}
	if (!parse_i32(parts[2], controlled_case.players) || controlled_case.players < 1) {
		controlled_case.parse_error = "invalid players";
		return controlled_case;
	}
	if (!parse_u32(parts[3], controlled_case.seed)) {
		controlled_case.parse_error = "invalid seed";
		return controlled_case;
	}
	if (!parse_i32(parts[5], controlled_case.level_count) || controlled_case.level_count < 1) {
		controlled_case.parse_error = "invalid level_count";
		return controlled_case;
	}
	controlled_case.human_count = 1;
	controlled_case.computer_count = std::max(0, controlled_case.players - 1);
	if (parts.size() >= 7 && !parts[6].empty() && !parse_i32(parts[6], controlled_case.human_count)) {
		controlled_case.parse_error = "invalid human_count";
		return controlled_case;
	}
	if (parts.size() >= 8 && !parts[7].empty() && !parse_i32(parts[7], controlled_case.computer_count)) {
		controlled_case.parse_error = "invalid computer_count";
		return controlled_case;
	}
	if (controlled_case.human_count < 0 || controlled_case.computer_count < 0) {
		controlled_case.parse_error = "invalid negative player split";
		return controlled_case;
	}
	if (parts.size() >= 9 && !parts[8].empty()) {
		controlled_case.setup_object_0x44_known = parse_i32(parts[8], controlled_case.setup_object_0x44);
		if (!controlled_case.setup_object_0x44_known) {
			controlled_case.parse_error = "invalid setup_object_0x44";
			return controlled_case;
		}
	}
	controlled_case.parse_ok = true;
	return controlled_case;
}

std::vector<std::string> split_case_filter(const std::string &case_filter) {
	std::vector<std::string> filters;
	for (const std::string &part : split(case_filter, ',')) {
		if (!part.empty()) {
			filters.push_back(lower_ascii(part));
		}
	}
	return filters;
}

bool case_matches_filter(const ControlledCase &controlled_case, const std::vector<std::string> &filters) {
	if (filters.empty()) {
		return true;
	}
	const std::string id = lower_ascii(controlled_case.id);
	const std::string raw = lower_ascii(controlled_case.raw);
	for (const std::string &filter : filters) {
		if (id == filter || raw.find(filter) != std::string::npos) {
			return true;
		}
	}
	return false;
}

std::string safe_case_filename(const std::string &case_id) {
	std::string out;
	out.reserve(case_id.size());
	for (const unsigned char ch : case_id) {
		if (std::isalnum(ch) != 0 || ch == '-' || ch == '_') {
			out.push_back(static_cast<char>(ch));
		} else {
			out.push_back('_');
		}
	}
	return out.empty() ? "case" : out;
}

std::string case_phase_snapshot_json(const ControlledCase &controlled_case, const std::string &status, const std::string &blocked_reason) {
	const bool supported = supported_one_level_land_scope(controlled_case);
	const int32_t width = map_width_for_size(controlled_case.size_class);
	const bool generator_mode_known = controlled_case.setup_object_0x44_known && controlled_case.setup_object_0x44 != 3;
	const bool generator_mode_randomized = controlled_case.setup_object_0x44_known && controlled_case.setup_object_0x44 == 3;
	const bool synthetic_branch_allowed = generator_mode_known && controlled_case.setup_object_0x44 != 0;
	std::ostringstream out;
	out << "{\n";
	out << "  \"schema_id\": \"rmg_native_batch_export_cli_phase_snapshot_v2\",\n";
	out << "  \"runner\": \"standalone_native_cli_no_godot\",\n";
	out << "  \"godot_process_started\": false,\n";
	out << "  \"status\": \"" << json_escape(status) << "\",\n";
	out << "  \"blocked_reason\": \"" << json_escape(blocked_reason) << "\",\n";
	out << "  \"case_id\": \"" << json_escape(controlled_case.id) << "\",\n";
	out << "  \"raw_controlled_case\": \"" << json_escape(controlled_case.raw) << "\",\n";
	out << "  \"parse_ok\": " << (controlled_case.parse_ok ? "true" : "false") << ",\n";
	out << "  \"parse_error\": \"" << json_escape(controlled_case.parse_error) << "\",\n";
	out << "  \"normalized_config\": {\n";
	out << "    \"size_class\": \"" << json_escape(controlled_case.size_class) << "\",\n";
	out << "    \"width\": " << width << ",\n";
	out << "    \"height\": " << width << ",\n";
	out << "    \"players\": " << controlled_case.players << ",\n";
	out << "    \"seed\": " << controlled_case.seed << ",\n";
	out << "    \"water_mode\": \"" << json_escape(controlled_case.water_mode) << "\",\n";
	out << "    \"level_count\": " << controlled_case.level_count << ",\n";
	out << "    \"human_count\": " << controlled_case.human_count << ",\n";
	out << "    \"computer_count\": " << controlled_case.computer_count << "\n";
	out << "  },\n";
	out << "  \"supported_one_level_land_scope\": " << (supported ? "true" : "false") << ",\n";
	out << "  \"generation_output_written\": false,\n";
	out << "  \"amap_written\": false,\n";
	out << "  \"phase_checkpoint\": \"native-rmg-private-generated-cell-grid-alignment-10184\",\n";
	out << "  \"plain_cpp_generated_cell_grid_stage\": \"constructor_defaults_before_runtime_zone_owner_materialization\",\n";
	out << "  \"generator_mode_0x10b8_source\": \"0x49ecf2 writes generator+0x10b8 from constructor arg8 ([EBP+0x24]); 0x4adfe1 supplies that arg from RMG setup object+0x44; 0x4adf88 initializes setup+0x44 to 3, then 0x4602c1 overwrites stack setup [EBP-0x80]+0x44 from [EDI+0xac]+0x10 before calling 0x4adfe1; 0x4a3a9d tests level_index == 1 || generator+0x10b8 != 0\",\n";
	out << "  \"rmg_setup_object_0x44_known\": " << (controlled_case.setup_object_0x44_known ? "true" : "false") << ",\n";
	if (controlled_case.setup_object_0x44_known) {
		out << "  \"rmg_setup_object_0x44\": " << controlled_case.setup_object_0x44 << ",\n";
	} else {
		out << "  \"rmg_setup_object_0x44\": \"unknown_missing_same_run_rmg_setup_object_0x44_capture\",\n";
	}
	out << "  \"generator_mode_0x10b8_known\": " << (generator_mode_known ? "true" : "false") << ",\n";
	if (generator_mode_known) {
		out << "  \"generator_mode_0x10b8\": " << controlled_case.setup_object_0x44 << ",\n";
	} else if (generator_mode_randomized) {
		out << "  \"generator_mode_0x10b8\": \"pending_0x49ecf2_rng_percent_3_replay_for_setup_value_3\",\n";
	} else {
		out << "  \"generator_mode_0x10b8\": \"unknown_missing_same_run_rmg_setup_object_0x44_capture\",\n";
	}
	out << "  \"synthetic_branch_condition_0x4a3a9d\": \"level_index == 1 || generator+0x10b8 != 0\",\n";
	if (generator_mode_known) {
		out << "  \"synthetic_branch_allowed_by_0x4a3a9d\": " << (synthetic_branch_allowed ? "true" : "false") << ",\n";
	} else {
		out << "  \"synthetic_branch_allowed_by_0x4a3a9d\": \"unknown_until_generator_0x10b8_rmg_setup_object_0x44_is_captured\",\n";
	}
	out << "  \"private_state_checkpoint_initial_generated_cells\": ";
	append_initialized_generated_cell_checkpoint_json(out, controlled_case);
	out << ",\n";
	out << "  \"next_required_native_core_slice\": \"port_runtime_zone_owner_materialization_and_generated_cell_mutation_steps_after_constructor_defaults\",\n";
	out << "  \"next_required_alignment_slice\": \"capture_rmg_setup_object_0x44_then_port_0x4a3b48_direction_scan_and_0x49b452_runtime_zone_append\"\n";
	out << "}\n";
	return out.str();
}

} // namespace aurelion::rmg_native_core
