#pragma once

#include <cstdint>
#include <filesystem>
#include <string>
#include <vector>

namespace aurelion::rmg_native_core {

struct ControlledCase {
	std::string raw;
	std::string id;
	std::string size_class;
	int32_t players = 0;
	uint32_t seed = 0;
	std::string water_mode;
	int32_t level_count = 0;
	int32_t human_count = 0;
	int32_t computer_count = 0;
	bool setup_object_0x44_known = false;
	bool setup_object_0x44_supplied = false;
	int32_t setup_object_0x44 = 0;
	bool parse_ok = false;
	std::string parse_error;
};

struct CaseReport {
	ControlledCase input;
	std::string status;
	std::string blocked_reason;
	bool supported_scope = false;
	bool phase_snapshot_written = false;
	std::filesystem::path phase_snapshot_path;
	bool native_map_json_written = false;
	std::filesystem::path native_map_json_path;
};

ControlledCase parse_controlled_case(const std::string &raw);
std::vector<std::string> split_case_filter(const std::string &case_filter);
bool case_matches_filter(const ControlledCase &controlled_case, const std::vector<std::string> &filters);
std::string case_phase_snapshot_json(const ControlledCase &controlled_case, const std::string &status, const std::string &blocked_reason);
std::string case_native_map_json(const ControlledCase &controlled_case, const std::string &status, const std::string &blocked_reason);
std::string safe_case_filename(const std::string &case_id);

} // namespace aurelion::rmg_native_core
