#include "rmg_native_core.hpp"

#include <algorithm>
#include <cerrno>
#include <cstdlib>
#include <cstring>
#include <filesystem>
#include <fstream>
#include <iostream>
#include <sstream>
#include <string>
#include <vector>

namespace {

using aurelion::rmg_native_core::CaseReport;
using aurelion::rmg_native_core::ControlledCase;

struct Options {
	std::filesystem::path output_dir = ".artifacts/rmg_native_batch_export_cli";
	std::vector<std::string> controlled_cases;
	std::string case_filter;
	int limit = 0;
	bool include_unsupported = false;
	bool emit_phase_snapshot = false;
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
		out << "\"phase_snapshot_written\":" << (report.phase_snapshot_written ? "true" : "false") << ",";
		out << "\"phase_snapshot_path\":\"" << json_escape(report.phase_snapshot_path.string()) << "\"";
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
		} else if (arg == "--controlled-case") {
			std::string raw;
			take_value(raw);
			if (!raw.empty()) {
				options.controlled_cases.push_back(raw);
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
		} else if (arg == "--print-manifest") {
			options.print_manifest = true;
		}
	}
	return options;
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
		if (!controlled_case.parse_ok) {
			report.status = "failed";
			report.blocked_reason = controlled_case.parse_error;
		} else if (!supported) {
			report.status = "unsupported_scope";
			report.blocked_reason = "standalone_cli_currently_scopes_only_small_medium_one_level_land";
		} else {
			report.status = "blocked";
			report.blocked_reason = "native_rmg_core_still_godot_variant_bound";
		}
		if (options.emit_phase_snapshot) {
			const std::filesystem::path snapshot_path = absolute_output_dir / (aurelion::rmg_native_core::safe_case_filename(controlled_case.id) + ".phase_snapshot.json");
			std::ofstream snapshot(snapshot_path, std::ios::binary);
			if (snapshot) {
				snapshot << aurelion::rmg_native_core::case_phase_snapshot_json(controlled_case, report.status, report.blocked_reason);
				report.phase_snapshot_written = true;
				report.phase_snapshot_path = snapshot_path;
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
	for (const CaseReport &report : case_reports) {
		if (report.status == "failed") {
			++failed_count;
		} else if (report.status == "unsupported_scope") {
			++unsupported_count;
		}
	}
	const int blocked_count = int(case_reports.size()) - failed_count - unsupported_count;
	std::ostringstream out;
	out << "{\n";
	out << "  \"schema_id\": \"rmg_native_batch_export_cli_v2\",\n";
	out << "  \"status\": \"blocked\",\n";
	out << "  \"blocked_reason\": \"native_rmg_core_still_godot_variant_bound\",\n";
	out << "  \"runner\": \"standalone_native_cli_no_godot\",\n";
	out << "  \"godot_process_started\": false,\n";
	out << "  \"output_dir\": \"" << json_escape(options.output_dir.string()) << "\",\n";
	out << "  \"absolute_output_dir\": \"" << json_escape(absolute_output_dir.string()) << "\",\n";
	out << "  \"case_scope\": \"no_godot_cli_checkpoint2_generated_cell_surface_until_core_split\",\n";
	out << "  \"case_filter\": \"" << json_escape(options.case_filter) << "\",\n";
	out << "  \"case_limit\": " << options.limit << ",\n";
	out << "  \"include_unsupported\": " << (options.include_unsupported ? "true" : "false") << ",\n";
	out << "  \"emit_phase_snapshot\": " << (options.emit_phase_snapshot ? "true" : "false") << ",\n";
	out << "  \"controlled_case_count\": " << options.controlled_cases.size() << ",\n";
	out << "  \"controlled_cases\": ";
	append_json_string_array(out, options.controlled_cases);
	out << ",\n";
	out << "  \"case_count\": " << case_reports.size() << ",\n";
	out << "  \"blocked_count\": " << blocked_count << ",\n";
	out << "  \"unsupported_count\": " << unsupported_count << ",\n";
	out << "  \"skipped_count\": " << skipped_count << ",\n";
	out << "  \"exported_count\": 0,\n";
	out << "  \"failed_count\": " << failed_count << ",\n";
	out << "  \"generation_core_stage\": \"plain_cpp_controlled_case_checkpoint2_runtime_terrain_writeout_surface\",\n";
	out << "  \"phase_snapshot_schema_id\": \"rmg_native_batch_export_cli_phase_snapshot_v2\",\n";
	out << "  \"required_next_slice\": \"split_h3maped_rmg_generation_core_from_godot_variant_refcounted_fileaccess_api_before_running_native_exports_on_memory_constrained_hosts\",\n";
	out << "  \"message\": \"This executable is the no-Godot boundary. It parses and reports controlled Small/Medium one-level land cases, but intentionally refuses .amap generation until recovered RMG generation state is available through plain C++ data structures instead of Godot engine APIs.\",\n";
	out << "  \"cases\": ";
	append_case_report_array(out, case_reports);
	out << "\n";
	out << "}\n";
	return out.str();
}

} // namespace

int main(int argc, char **argv) {
	const Options options = parse_options(argc, argv);
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
	std::cout << "RMG_NATIVE_BATCH_EXPORT_CLI status=blocked output_dir=" << absolute_output_dir.string()
			  << " cases=" << case_reports.size()
			  << " reason=native_rmg_core_still_godot_variant_bound\n";
	return 2;
}
