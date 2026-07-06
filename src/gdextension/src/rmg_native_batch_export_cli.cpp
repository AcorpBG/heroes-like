#include "rmg_native_core.hpp"

#include <algorithm>
#include <cerrno>
#include <cstdint>
#include <cstdlib>
#include <cstring>
#include <filesystem>
#include <fstream>
#include <iostream>
#include <limits>
#include <sstream>
#include <string>
#include <utility>
#include <vector>

namespace {

using aurelion::rmg_native_core::CaseReport;
using aurelion::rmg_native_core::ControlledCase;
using aurelion::rmg_native_core::SharedRuntimeChainInput;
using aurelion::rmg_native_core::SharedRuntimeLinkInput;
using aurelion::rmg_native_core::SharedRuntimeZoneSeedInput;

struct Options {
	std::filesystem::path output_dir = ".artifacts/rmg_native_batch_export_cli";
	std::filesystem::path same_run_tile_payload_authority_path =
			".artifacts/rmg_recovery/same_run_final_tile_payload_bytes_20260610.bin";
	std::filesystem::path same_run_object_payload_authority_path =
			".artifacts/rmg_recovery/same_run_final_object_payload_replay_bytes_20260610.bin";
	std::filesystem::path same_run_payload_summary_path =
			".artifacts/rmg_recovery/same_run_final_payload_summary_20260610.json";
	std::vector<std::string> controlled_cases;
	std::string case_filter;
	SharedRuntimeChainInput shared_runtime_chain_input;
	int limit = 0;
	bool include_unsupported = false;
	bool emit_phase_snapshot = false;
	bool phase_snapshot_only = false;
	bool emit_native_map_json = false;
	bool native_map_json_only = false;
	bool print_manifest = false;
};

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

void append_json_string_array(std::ostream &out, const std::vector<std::string> &values) {
	out << "[";
	for (size_t index = 0; index < values.size(); ++index) {
		if (index != 0) {
			out << ", ";
		}
		out << "\"" << json_escape(values[index]) << "\"";
	}
	out << "]";
}

bool write_binary_file(const std::filesystem::path &path, const std::vector<uint8_t> &bytes) {
	std::ofstream file(path, std::ios::binary);
	if (!file) {
		return false;
	}
	if (!bytes.empty()) {
		file.write(reinterpret_cast<const char *>(bytes.data()), std::streamsize(bytes.size()));
	}
	return bool(file);
}

bool read_binary_file(const std::filesystem::path &path, std::vector<uint8_t> &bytes) {
	std::ifstream file(path, std::ios::binary);
	if (!file) {
		return false;
	}
	file.seekg(0, std::ios::end);
	const std::streamoff size = file.tellg();
	if (size < 0) {
		return false;
	}
	file.seekg(0, std::ios::beg);
	std::vector<uint8_t> loaded(static_cast<size_t>(size));
	if (!loaded.empty()) {
		file.read(reinterpret_cast<char *>(loaded.data()), std::streamsize(loaded.size()));
		if (!file) {
			return false;
		}
	}
	bytes = std::move(loaded);
	return true;
}

bool read_text_file(const std::filesystem::path &path, std::string &text) {
	std::ifstream file(path, std::ios::binary);
	if (!file) {
		return false;
	}
	std::ostringstream out;
	out << file.rdbuf();
	text = out.str();
	return bool(file) || file.eof();
}

bool write_final_payload_sections_json(
		const std::filesystem::path &path,
		const std::vector<aurelion::h3maped_rmg_core::FinalPayloadWriteoutSection4ad1e3> &sections) {
	std::ofstream file(path, std::ios::binary);
	if (!file) {
		return false;
	}
	file << "{\n";
	file << "  \"schema_id\": \"rmg_native_final_payload_sections_v1\",\n";
	file << "  \"section_count\": " << sections.size() << ",\n";
	file << "  \"sections\": [";
	for (size_t index = 0; index < sections.size(); ++index) {
		if (index != 0) {
			file << ", ";
		}
		const aurelion::h3maped_rmg_core::FinalPayloadWriteoutSection4ad1e3 &section = sections[index];
		file << "{\"section_id\":\"" << json_escape(section.section_id) << "\""
			 << ",\"h3maped_anchor\":\"" << json_escape(section.h3maped_anchor) << "\""
			 << ",\"offset\":" << section.offset
			 << ",\"byte_count\":" << section.byte_count
			 << "}";
	}
	file << "]\n";
	file << "}\n";
	return bool(file);
}

void append_case_report_array(std::ostream &out, const std::vector<CaseReport> &reports) {
	out << "[";
	for (size_t index = 0; index < reports.size(); ++index) {
		if (index != 0) {
			out << ", ";
		}
		const CaseReport &report = reports[index];
		out << "{";
		out << "\"case_id\":\"" << json_escape(report.input.id) << "\",";
		out << "\"raw_controlled_case\":\"" << json_escape(report.input.raw) << "\",";
		out << "\"status\":\"" << json_escape(report.status) << "\",";
		out << "\"blocked_reason\":\"" << json_escape(report.blocked_reason) << "\",";
		out << "\"supported_scope\":" << (report.supported_scope ? "true" : "false") << ",";
		out << "\"shared_chain_input_status\":\"" << json_escape(report.shared_chain_input_status) << "\",";
		out << "\"shared_chain_executed\":" << (report.shared_chain_executed ? "true" : "false") << ",";
		out << "\"native_workflow_executed\":" << (report.native_workflow_executed ? "true" : "false") << ",";
		out << "\"native_workflow_final_writeout_complete\":" << (report.native_workflow_final_writeout_complete ? "true" : "false") << ",";
		out << "\"native_workflow_final_header_writeout_applied\":" << (report.native_workflow_final_header_writeout_applied ? "true" : "false") << ",";
		out << "\"native_workflow_final_header_byte_count\":" << report.native_workflow_final_header_byte_count << ",";
		out << "\"native_workflow_post_header_initial_zero_written\":" << (report.native_workflow_post_header_initial_zero_written ? "true" : "false") << ",";
		out << "\"native_workflow_final_tile_writeout_applied\":" << (report.native_workflow_final_tile_writeout_applied ? "true" : "false") << ",";
		out << "\"native_workflow_final_tile_cell_count\":" << report.native_workflow_final_tile_cell_count << ",";
		out << "\"native_workflow_final_tile_byte_count\":" << report.native_workflow_final_tile_byte_count << ",";
		out << "\"native_workflow_final_object_count_header_written\":" << (report.native_workflow_final_object_count_header_written ? "true" : "false") << ",";
		out << "\"native_workflow_final_object_count\":" << report.native_workflow_final_object_count << ",";
		out << "\"native_workflow_final_payload_assembly_applied\":" << (report.native_workflow_final_payload_assembly_applied ? "true" : "false") << ",";
		out << "\"native_workflow_final_payload_byte_count\":" << report.native_workflow_final_payload_byte_count << ",";
		out << "\"native_workflow_status\":\"" << json_escape(report.native_workflow_status) << "\",";
		out << "\"native_workflow_current_phase\":\"" << json_escape(report.native_workflow_current_phase) << "\",";
		out << "\"phase_snapshot_written\":" << (report.phase_snapshot_written ? "true" : "false") << ",";
		out << "\"phase_snapshot_path\":\"" << json_escape(report.phase_snapshot_path.string()) << "\",";
		out << "\"final_payload_binary_written\":" << (report.final_payload_binary_written ? "true" : "false") << ",";
		out << "\"final_payload_binary_path\":\"" << json_escape(report.final_payload_binary_path.string()) << "\",";
		out << "\"final_payload_sections_written\":" << (report.final_payload_sections_written ? "true" : "false") << ",";
		out << "\"final_payload_sections_path\":\"" << json_escape(report.final_payload_sections_path.string()) << "\",";
		out << "\"native_map_json_written\":" << (report.native_map_json_written ? "true" : "false") << ",";
		out << "\"native_map_json_path\":\"" << json_escape(report.native_map_json_path.string()) << "\"";
		out << "}";
	}
	out << "]";
}

bool parse_int(const std::string &raw, int &out_value) {
	char *end = nullptr;
	errno = 0;
	const long parsed = std::strtol(raw.c_str(), &end, 10);
	if (errno != 0 || end == raw.c_str() || *end != '\0') {
		return false;
	}
	out_value = static_cast<int>(std::max<long>(0, parsed));
	return true;
}

bool parse_i32_strict(const std::string &raw, int32_t &out_value) {
	char *end = nullptr;
	errno = 0;
	const long parsed = std::strtol(raw.c_str(), &end, 10);
	if (errno != 0 || end == raw.c_str() || *end != '\0' || parsed < std::numeric_limits<int32_t>::min() || parsed > std::numeric_limits<int32_t>::max()) {
		return false;
	}
	out_value = static_cast<int32_t>(parsed);
	return true;
}

bool parse_u32_strict(const std::string &raw, uint32_t &out_value) {
	char *end = nullptr;
	errno = 0;
	const unsigned long parsed = std::strtoul(raw.c_str(), &end, 10);
	if (errno != 0 || end == raw.c_str() || *end != '\0' || parsed > std::numeric_limits<uint32_t>::max()) {
		return false;
	}
	out_value = static_cast<uint32_t>(parsed);
	return true;
}

std::vector<std::string> split_csv(const std::string &raw) {
	std::vector<std::string> parts;
	std::string current;
	for (const char ch : raw) {
		if (ch == ',') {
			parts.push_back(current);
			current.clear();
		} else {
			current.push_back(ch);
		}
	}
	parts.push_back(current);
	return parts;
}

bool parse_i32_csv(const std::string &raw, size_t expected_count, std::vector<int32_t> &out_values) {
	const std::vector<std::string> parts = split_csv(raw);
	if (parts.size() != expected_count) {
		return false;
	}
	std::vector<int32_t> parsed;
	parsed.reserve(parts.size());
	for (const std::string &part : parts) {
		int32_t value = 0;
		if (!parse_i32_strict(part, value)) {
			return false;
		}
		parsed.push_back(value);
	}
	out_values = parsed;
	return true;
}

Options parse_options(int argc, char **argv) {
	Options options;
	for (int index = 1; index < argc; ++index) {
		const std::string arg = argv[index] != nullptr ? argv[index] : "";
		auto take_value = [&](std::string &out_value) {
			if (index + 1 < argc && argv[index + 1] != nullptr) {
				out_value = argv[++index];
			}
		};
		if (arg == "--out") {
			std::string raw;
			take_value(raw);
			if (!raw.empty()) {
				options.output_dir = raw;
			}
		} else if (arg == "--same-run-tile-payload-authority") {
			std::string raw;
			take_value(raw);
			if (!raw.empty()) {
				options.same_run_tile_payload_authority_path = raw;
			}
		} else if (arg == "--same-run-object-payload-authority") {
			std::string raw;
			take_value(raw);
			if (!raw.empty()) {
				options.same_run_object_payload_authority_path = raw;
			}
		} else if (arg == "--same-run-payload-summary") {
			std::string raw;
			take_value(raw);
			if (!raw.empty()) {
				options.same_run_payload_summary_path = raw;
			}
		} else if (arg == "--controlled-case") {
			std::string raw;
			take_value(raw);
			if (!raw.empty()) {
				options.controlled_cases.push_back(raw);
			}
		} else if (arg == "--shared-input-source") {
			take_value(options.shared_runtime_chain_input.input_source);
		} else if (arg == "--shared-rng-state-after-template-selection") {
			std::string raw;
			take_value(raw);
			uint32_t parsed = 0;
			if (parse_u32_strict(raw, parsed)) {
				options.shared_runtime_chain_input.rng_state_after_template_selection = parsed;
				options.shared_runtime_chain_input.rng_state_after_template_selection_known = true;
			}
		} else if (arg == "--shared-generator-mode-0x10b8") {
			std::string raw;
			take_value(raw);
			int32_t parsed = 0;
			if (parse_i32_strict(raw, parsed)) {
				options.shared_runtime_chain_input.generator_mode_0x10b8 = parsed;
				options.shared_runtime_chain_input.generator_mode_0x10b8_known = true;
			}
		} else if (arg == "--shared-runtime-zone-seed") {
			std::string raw;
			take_value(raw);
			std::vector<int32_t> fields;
			if (parse_i32_csv(raw, 13, fields) || parse_i32_csv(raw, 12, fields) || parse_i32_csv(raw, 11, fields) || parse_i32_csv(raw, 8, fields) || parse_i32_csv(raw, 7, fields)) {
				SharedRuntimeZoneSeedInput input;
				input.runtime_zone_index = fields[0];
				input.source_zone_id = fields[1];
				input.source_index = fields[2];
				input.h3maped_zone_word_id = fields[3];
				input.source_bucket = fields[4];
				input.actual_player_color = fields[5];
				input.source_base_size = fields[6];
				if (fields.size() == 8) {
					input.source_owner_index = fields[7];
				}
				if (fields.size() >= 11) {
					input.allowed_town_mask_0x41_0x49 = uint16_t(fields[7]);
					input.selected_town_choice_index_0x49b3c1 = fields[8];
					input.terrain_match_to_town_0x84 = fields[9] != 0;
					input.allowed_terrain_mask_0x85_0x8c = uint16_t(fields[10]);
				}
				if (fields.size() >= 12) {
					input.source_owner_index = fields[11];
				}
				if (fields.size() >= 13) {
					input.fixed_player_town_choice_index_0xf24 = fields[12];
				}
				options.shared_runtime_chain_input.runtime_zone_seeds.push_back(input);
			}
		} else if (arg == "--shared-runtime-link") {
			std::string raw;
			take_value(raw);
			std::vector<int32_t> fields;
			if (parse_i32_csv(raw, 9, fields) || parse_i32_csv(raw, 7, fields) || parse_i32_csv(raw, 5, fields) || parse_i32_csv(raw, 2, fields)) {
				SharedRuntimeLinkInput input;
				input.from_index = fields[0];
				input.to_index = fields[1];
				if (fields.size() >= 5) {
					input.guard_value = fields[2];
					input.wide = fields[3] != 0;
					input.border_guard = fields[4] != 0;
				}
				if (fields.size() >= 7) {
					input.source_zone_a = fields[5];
					input.source_zone_b = fields[6];
				}
				if (fields.size() >= 9) {
					input.source_endpoint_a = fields[7];
					input.source_endpoint_b = fields[8];
				}
				options.shared_runtime_chain_input.runtime_links.push_back(input);
			}
		} else if (arg == "--case") {
			take_value(options.case_filter);
		} else if (arg == "--limit") {
			std::string raw;
			take_value(raw);
			int parsed = 0;
			if (parse_int(raw, parsed)) {
				options.limit = parsed;
			}
		} else if (arg == "--include-unsupported") {
			options.include_unsupported = true;
		} else if (arg == "--emit-phase-snapshot") {
			options.emit_phase_snapshot = true;
		} else if (arg == "--phase-snapshot-only") {
			options.phase_snapshot_only = true;
			options.emit_phase_snapshot = true;
		} else if (arg == "--emit-native-map-json") {
			options.emit_native_map_json = true;
		} else if (arg == "--native-map-json-only") {
			options.native_map_json_only = true;
			options.emit_native_map_json = true;
		} else if (arg == "--print-manifest") {
			options.print_manifest = true;
		}
	}
	return options;
}

void hydrate_same_run_authority_payloads(Options &options) {
	std::vector<uint8_t> tile_payload;
	if (read_binary_file(options.same_run_tile_payload_authority_path, tile_payload)) {
		options.shared_runtime_chain_input.same_run_final_tile_payload_authority_known = true;
		options.shared_runtime_chain_input.same_run_final_tile_payload_authority_0x49b2b6 =
				std::move(tile_payload);
	}
	std::vector<uint8_t> object_payload;
	if (read_binary_file(options.same_run_object_payload_authority_path, object_payload)) {
		options.shared_runtime_chain_input.same_run_generated_object_payload_authority_known = true;
		options.shared_runtime_chain_input.same_run_generated_object_payload_authority_0x4ad1e3 =
				std::move(object_payload);
	}
	std::string payload_summary;
	static const char *EXPECTED_PROFILE =
			"H3MapEd Medium one-level no-water seed 10, human/computer down 1, computer-only down 0";
	if (read_text_file(options.same_run_payload_summary_path, payload_summary)
			&& payload_summary.find(EXPECTED_PROFILE) != std::string::npos
			&& payload_summary.find("\"tile_payload_byte_count\": 36288") != std::string::npos
			&& payload_summary.find("\"object_payload_byte_count\": 17057") != std::string::npos) {
		options.shared_runtime_chain_input.same_run_payload_authority_profile_known = true;
		options.shared_runtime_chain_input.same_run_payload_authority_profile = EXPECTED_PROFILE;
		options.shared_runtime_chain_input.same_run_payload_authority_tile_byte_count = 36288;
		options.shared_runtime_chain_input.same_run_payload_authority_object_byte_count = 17057;
	}
}

bool supported_case_scope(const ControlledCase &controlled_case) {
	return controlled_case.parse_ok
			&& (controlled_case.size_class == "small" || controlled_case.size_class == "medium")
			&& controlled_case.water_mode == "land"
			&& controlled_case.level_count == 1;
}

std::vector<CaseReport> build_case_reports(const Options &options, const std::filesystem::path &absolute_output_dir, int &skipped_count) {
	std::vector<CaseReport> reports;
	const std::vector<std::string> filters = aurelion::rmg_native_core::split_case_filter(options.case_filter);
	skipped_count = 0;
	for (const std::string &raw_case : options.controlled_cases) {
		ControlledCase controlled_case = aurelion::rmg_native_core::parse_controlled_case(raw_case);
		if (!aurelion::rmg_native_core::case_matches_filter(controlled_case, filters)) {
			++skipped_count;
			continue;
		}
		const bool supported = supported_case_scope(controlled_case);
		if (!supported && !options.include_unsupported) {
			++skipped_count;
			continue;
		}
		CaseReport report;
		report.input = controlled_case;
		report.supported_scope = supported;
		const aurelion::rmg_native_core::NativeH3MapedWorkflowResult workflow =
				aurelion::rmg_native_core::run_native_h3maped_workflow(controlled_case, options.shared_runtime_chain_input);
		report.shared_chain_input_status = workflow.payload.executable ? "native_workflow_inputs_ready" : "missing_exact_runtime_zone_seed_link_inputs";
		report.shared_chain_executed = workflow.executed;
		report.native_workflow_executed = workflow.executed;
		report.native_workflow_final_writeout_complete = workflow.final_writeout_complete;
		report.native_workflow_final_header_writeout_applied = workflow.final_header_writeout_0x4ac857_0x4ad206.applied;
		report.native_workflow_final_header_byte_count = workflow.final_header_writeout_0x4ac857_0x4ad206.header_payload_byte_count;
		report.native_workflow_post_header_initial_zero_written = workflow.final_header_writeout_0x4ac857_0x4ad206.post_header_initial_zero_written_0x4ad206;
		report.native_workflow_final_tile_writeout_applied = workflow.final_tile_writeout_0x49b2b6.applied;
		report.native_workflow_final_tile_cell_count = workflow.final_tile_writeout_0x49b2b6.cell_count;
		report.native_workflow_final_tile_byte_count = workflow.final_tile_writeout_0x49b2b6.byte_count;
		report.native_workflow_final_object_count_header_written = workflow.final_object_writeout_0x4ad309_0x4ad3eb.object_count_header_written;
		report.native_workflow_final_object_count = workflow.final_object_writeout_0x4ad309_0x4ad3eb.generated_object_count;
		report.native_workflow_final_payload_assembly_applied = workflow.final_payload_writeout_0x4ad1e3.applied;
		report.native_workflow_final_payload_byte_count = workflow.final_payload_writeout_0x4ad1e3.total_payload_byte_count;
		report.native_workflow_status = workflow.status;
		report.native_workflow_current_phase = workflow.current_phase_id;
		report.status = workflow.status;
		report.blocked_reason = workflow.blocked_reason;
		if (options.emit_phase_snapshot) {
			const std::string safe_case_id = aurelion::rmg_native_core::safe_case_filename(controlled_case.id);
			const std::filesystem::path snapshot_path = absolute_output_dir / (safe_case_id + ".phase_snapshot.json");
			std::ofstream snapshot(snapshot_path, std::ios::binary);
			if (snapshot) {
				snapshot << aurelion::rmg_native_core::case_native_h3maped_workflow_json(controlled_case, report.status, report.blocked_reason, options.shared_runtime_chain_input);
				report.phase_snapshot_written = true;
				report.phase_snapshot_path = snapshot_path;
			}
			if (workflow.final_payload_writeout_0x4ad1e3.applied) {
				const std::filesystem::path payload_path = absolute_output_dir / (safe_case_id + ".final_payload.bin");
				if (write_binary_file(payload_path, workflow.final_payload_writeout_0x4ad1e3.payload_bytes)) {
					report.final_payload_binary_written = true;
					report.final_payload_binary_path = payload_path;
				}
				const std::filesystem::path sections_path = absolute_output_dir / (safe_case_id + ".final_payload_sections.json");
				if (write_final_payload_sections_json(sections_path, workflow.final_payload_writeout_0x4ad1e3.sections)) {
					report.final_payload_sections_written = true;
					report.final_payload_sections_path = sections_path;
				}
			}
		}
		reports.push_back(report);
		if (options.limit > 0 && int(reports.size()) >= options.limit) {
			break;
		}
	}
	return reports;
}

std::string manifest_json(const Options &options, const std::filesystem::path &absolute_output_dir, const std::vector<CaseReport> &case_reports, int skipped_count) {
	int failed_count = 0;
	int unsupported_count = 0;
	int native_map_json_exported_count = 0;
	int native_map_json_failed_count = 0;
	int phase_snapshot_written_count = 0;
	int phase_snapshot_failed_count = 0;
	int shared_chain_executed_count = 0;
	int native_workflow_executed_count = 0;
	int native_workflow_final_writeout_complete_count = 0;
	int native_workflow_final_header_writeout_applied_count = 0;
	int native_workflow_post_header_initial_zero_written_count = 0;
	int native_workflow_final_tile_writeout_applied_count = 0;
	int native_workflow_final_object_count_header_written_count = 0;
	int native_workflow_final_payload_assembly_applied_count = 0;
	int final_payload_binary_written_count = 0;
	int final_payload_sections_written_count = 0;
	for (const CaseReport &report : case_reports) {
		if (report.status == "failed") {
			++failed_count;
		} else if (report.status == "unsupported_scope") {
			++unsupported_count;
		} else if (report.status == "native_map_json_exported") {
			++native_map_json_exported_count;
			if (!report.native_map_json_written) {
				++native_map_json_failed_count;
			}
		}
		if (report.phase_snapshot_written) {
			++phase_snapshot_written_count;
		} else if (options.emit_phase_snapshot && report.supported_scope) {
			if (!report.phase_snapshot_written) {
				++phase_snapshot_failed_count;
			}
		}
		if (report.shared_chain_executed) {
			++shared_chain_executed_count;
		}
		if (report.native_workflow_executed) {
			++native_workflow_executed_count;
		}
		if (report.native_workflow_final_writeout_complete) {
			++native_workflow_final_writeout_complete_count;
		}
		if (report.native_workflow_final_header_writeout_applied) {
			++native_workflow_final_header_writeout_applied_count;
		}
		if (report.native_workflow_post_header_initial_zero_written) {
			++native_workflow_post_header_initial_zero_written_count;
		}
		if (report.native_workflow_final_tile_writeout_applied) {
			++native_workflow_final_tile_writeout_applied_count;
		}
		if (report.native_workflow_final_object_count_header_written) {
			++native_workflow_final_object_count_header_written_count;
		}
		if (report.native_workflow_final_payload_assembly_applied) {
			++native_workflow_final_payload_assembly_applied_count;
		}
		if (report.final_payload_binary_written) {
			++final_payload_binary_written_count;
		}
		if (report.final_payload_sections_written) {
			++final_payload_sections_written_count;
		}
	}
	const int blocked_count = int(case_reports.size()) - failed_count - unsupported_count - native_map_json_exported_count;
	const bool native_map_output_complete =
			!case_reports.empty()
			&& native_map_json_exported_count == int(case_reports.size())
			&& native_map_json_failed_count == 0;
	const std::string status = native_map_output_complete ? "complete" : "blocked";
	const bool final_payload_compare_reached =
			native_workflow_final_payload_assembly_applied_count > 0;
	const std::string blocked_reason = status == "complete"
			? ""
			: (final_payload_compare_reached
							? "native_h3maped_workflow_reaches_ordered_final_payload_compare_but_same_run_payload_parity_is_not_owned"
							: "native_h3maped_workflow_blocked_before_ordered_final_payload_compare");
	std::ostringstream out;
	out << "{\n";
	out << "  \"schema_id\": \"rmg_native_batch_export_cli_v4\",\n";
	out << "  \"status\": \"" << status << "\",\n";
	out << "  \"blocked_reason\": \"" << blocked_reason << "\",\n";
	out << "  \"runner\": \"standalone_native_cli_no_godot\",\n";
	out << "  \"godot_process_started\": false,\n";
	out << "  \"output_dir\": \"" << json_escape(options.output_dir.string()) << "\",\n";
	out << "  \"absolute_output_dir\": \"" << json_escape(absolute_output_dir.string()) << "\",\n";
	out << "  \"case_scope\": \"no_godot_cli_single_native_h3maped_workflow\",\n";
	out << "  \"case_filter\": \"" << json_escape(options.case_filter) << "\",\n";
	out << "  \"case_limit\": " << options.limit << ",\n";
	out << "  \"include_unsupported\": " << (options.include_unsupported ? "true" : "false") << ",\n";
	out << "  \"emit_phase_snapshot\": " << (options.emit_phase_snapshot ? "true" : "false") << ",\n";
	out << "  \"phase_snapshot_only\": " << (options.phase_snapshot_only ? "true" : "false") << ",\n";
	out << "  \"emit_native_map_json\": " << (options.emit_native_map_json ? "true" : "false") << ",\n";
	out << "  \"native_map_json_only\": " << (options.native_map_json_only ? "true" : "false") << ",\n";
	out << "  \"controlled_case_count\": " << options.controlled_cases.size() << ",\n";
	out << "  \"controlled_cases\": ";
	append_json_string_array(out, options.controlled_cases);
	out << ",\n";
	out << "  \"shared_input_source\": \"" << json_escape(options.shared_runtime_chain_input.input_source.empty() ? "explicit_cli_runtime_inputs" : options.shared_runtime_chain_input.input_source) << "\",\n";
	out << "  \"same_run_tile_payload_authority_path\": \"" << json_escape(options.same_run_tile_payload_authority_path.string()) << "\",\n";
	out << "  \"same_run_tile_payload_authority_known\": " << (options.shared_runtime_chain_input.same_run_final_tile_payload_authority_known ? "true" : "false") << ",\n";
	out << "  \"same_run_tile_payload_authority_byte_count\": " << options.shared_runtime_chain_input.same_run_final_tile_payload_authority_0x49b2b6.size() << ",\n";
	out << "  \"same_run_object_payload_authority_path\": \"" << json_escape(options.same_run_object_payload_authority_path.string()) << "\",\n";
	out << "  \"same_run_object_payload_authority_known\": " << (options.shared_runtime_chain_input.same_run_generated_object_payload_authority_known ? "true" : "false") << ",\n";
	out << "  \"same_run_object_payload_authority_byte_count\": " << options.shared_runtime_chain_input.same_run_generated_object_payload_authority_0x4ad1e3.size() << ",\n";
	out << "  \"same_run_payload_summary_path\": \"" << json_escape(options.same_run_payload_summary_path.string()) << "\",\n";
	out << "  \"same_run_payload_authority_profile_known\": " << (options.shared_runtime_chain_input.same_run_payload_authority_profile_known ? "true" : "false") << ",\n";
	out << "  \"same_run_payload_authority_profile\": \"" << json_escape(options.shared_runtime_chain_input.same_run_payload_authority_profile) << "\",\n";
	out << "  \"same_run_payload_authority_setup_stack_join_known\": " << (options.shared_runtime_chain_input.same_run_payload_authority_setup_stack_join_known ? "true" : "false") << ",\n";
	out << "  \"shared_runtime_zone_seed_count\": " << options.shared_runtime_chain_input.runtime_zone_seeds.size() << ",\n";
	int64_t shared_runtime_link_guard_value_sum = 0;
	int32_t shared_runtime_link_wide_count = 0;
	int32_t shared_runtime_link_border_guard_count = 0;
	for (const SharedRuntimeLinkInput &link : options.shared_runtime_chain_input.runtime_links) {
		shared_runtime_link_guard_value_sum += link.guard_value;
		if (link.wide) {
			shared_runtime_link_wide_count += 1;
		}
		if (link.border_guard) {
			shared_runtime_link_border_guard_count += 1;
		}
	}
	out << "  \"shared_runtime_link_count\": " << options.shared_runtime_chain_input.runtime_links.size() << ",\n";
	out << "  \"shared_runtime_link_guard_value_sum\": " << shared_runtime_link_guard_value_sum << ",\n";
	out << "  \"shared_runtime_link_wide_count\": " << shared_runtime_link_wide_count << ",\n";
	out << "  \"shared_runtime_link_border_guard_count\": " << shared_runtime_link_border_guard_count << ",\n";
	out << "  \"shared_rng_state_after_template_selection_known\": " << (options.shared_runtime_chain_input.rng_state_after_template_selection_known ? "true" : "false") << ",\n";
	out << "  \"shared_generator_mode_0x10b8_known\": " << (options.shared_runtime_chain_input.generator_mode_0x10b8_known ? "true" : "false") << ",\n";
	out << "  \"shared_coordinate_owner_grid_chain_executed_count\": " << shared_chain_executed_count << ",\n";
	out << "  \"native_h3maped_workflow_executed_count\": " << native_workflow_executed_count << ",\n";
	out << "  \"native_h3maped_workflow_final_header_writeout_applied_count\": " << native_workflow_final_header_writeout_applied_count << ",\n";
	out << "  \"native_h3maped_workflow_post_header_initial_zero_written_count\": " << native_workflow_post_header_initial_zero_written_count << ",\n";
	out << "  \"native_h3maped_workflow_final_tile_writeout_applied_count\": " << native_workflow_final_tile_writeout_applied_count << ",\n";
	out << "  \"native_h3maped_workflow_final_object_count_header_written_count\": " << native_workflow_final_object_count_header_written_count << ",\n";
	out << "  \"native_h3maped_workflow_final_payload_assembly_applied_count\": " << native_workflow_final_payload_assembly_applied_count << ",\n";
	out << "  \"native_h3maped_workflow_final_writeout_complete_count\": " << native_workflow_final_writeout_complete_count << ",\n";
	out << "  \"case_count\": " << case_reports.size() << ",\n";
	out << "  \"blocked_count\": " << blocked_count << ",\n";
	out << "  \"unsupported_count\": " << unsupported_count << ",\n";
	out << "  \"skipped_count\": " << skipped_count << ",\n";
	out << "  \"exported_count\": " << native_map_json_exported_count << ",\n";
	out << "  \"native_map_json_exported_count\": " << native_map_json_exported_count << ",\n";
	out << "  \"native_map_json_failed_count\": " << native_map_json_failed_count << ",\n";
	out << "  \"native_map_json_public_api_removed\": true,\n";
	out << "  \"legacy_native_generation_surface_removed\": true,\n";
	out << "  \"phase_snapshot_exported_count\": 0,\n";
	out << "  \"phase_snapshot_written_count\": " << phase_snapshot_written_count << ",\n";
	out << "  \"phase_snapshot_failed_count\": " << phase_snapshot_failed_count << ",\n";
	out << "  \"final_payload_binary_written_count\": " << final_payload_binary_written_count << ",\n";
	out << "  \"final_payload_sections_written_count\": " << final_payload_sections_written_count << ",\n";
	out << "  \"failed_count\": " << failed_count << ",\n";
	out << "  \"generation_core_stage\": \"native_h3maped_workflow_reaches_ordered_final_payload_assembly_and_blocks_on_same_run_payload_compare\",\n";
	out << "  \"phase_snapshot_schema_id\": \"rmg_native_batch_export_cli_native_h3maped_workflow_v1\",\n";
	out << "  \"native_map_json_schema_id\": \"disabled_until_full_recovered_h3maped_entrypoint_to_writeout_chain_owns_payload\",\n";
	out << "  \"required_next_slice\": \"align_final_tile_stream_0x49b2b6_and_generated_object_payload_against_same_run_h3maped_payload\",\n";
	out << "  \"message\": \"This executable is the no-Godot boundary for the single native H3MapEd workflow. It executes ordered phases through relation scan, mine/resource, reward/guard, connection/road, final header, final tile, and generated-object payload assembly, then exits blocked before native map output until same-run 0x49b2b6 tile and generated-object payload parity are owned.\",\n";
	out << "  \"cases\": ";
	append_case_report_array(out, case_reports);
	out << "\n";
	out << "}\n";
	return out.str();
}

} // namespace

int main(int argc, char **argv) {
	Options options = parse_options(argc, argv);
	hydrate_same_run_authority_payloads(options);
	const std::filesystem::path absolute_output_dir = std::filesystem::absolute(options.output_dir);
	std::error_code error;
	std::filesystem::create_directories(absolute_output_dir, error);
	if (error) {
		std::cerr << "RMG_NATIVE_BATCH_EXPORT_CLI status=fail error=output_dir_create_failed detail=" << error.message() << "\n";
		return 1;
	}

	int skipped_count = 0;
	const std::vector<CaseReport> case_reports = build_case_reports(options, absolute_output_dir, skipped_count);
	const std::string manifest = manifest_json(options, absolute_output_dir, case_reports, skipped_count);
	const std::filesystem::path manifest_path = absolute_output_dir / "manifest.json";
	std::ofstream file(manifest_path, std::ios::binary);
	if (!file) {
		std::cerr << "RMG_NATIVE_BATCH_EXPORT_CLI status=fail error=manifest_open_failed path=" << manifest_path << "\n";
		return 1;
	}
	file << manifest;
	file.close();

	if (options.print_manifest) {
		std::cout << manifest;
	}
	int failed_count = 0;
	int unsupported_count = 0;
	int blocked_count = 0;
	int native_map_json_exported_count = 0;
	int native_map_json_failed_count = 0;
	int phase_snapshot_written_count = 0;
	int phase_snapshot_failed_count = 0;
	int final_payload_binary_written_count = 0;
	for (const CaseReport &report : case_reports) {
		if (report.status == "failed") {
			++failed_count;
		} else if (report.status == "unsupported_scope") {
			++unsupported_count;
		} else if (report.status == "native_map_json_exported") {
			++native_map_json_exported_count;
			if (!report.native_map_json_written) {
				++native_map_json_failed_count;
			}
		} else if (report.status == "blocked") {
			++blocked_count;
		}
		if (report.phase_snapshot_written) {
			++phase_snapshot_written_count;
		} else if (options.emit_phase_snapshot && report.supported_scope) {
			if (!report.phase_snapshot_written) {
				++phase_snapshot_failed_count;
			}
		}
		if (report.final_payload_binary_written) {
			++final_payload_binary_written_count;
		}
	}
	std::cout << "RMG_NATIVE_BATCH_EXPORT_CLI status=blocked output_dir=" << absolute_output_dir.string()
			  << " cases=" << case_reports.size()
			  << " phase_snapshots_written=" << phase_snapshot_written_count
			  << " final_payload_binaries_written=" << final_payload_binary_written_count
			  << " reason=native_h3maped_workflow_header_0x4ac857_post_zero_0x4ad206_tile_object_payloads_and_0x4ad3db_sentinel_owned_blocked_before_or_at_full_payload_compare\n";
	return failed_count > 0 ? 1 : 2;
}
