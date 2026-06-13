#include <algorithm>
#include <cctype>
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

std::string manifest_json(const Options &options, const std::filesystem::path &absolute_output_dir) {
	std::ostringstream out;
	out << "{\n";
	out << "  \"schema_id\": \"rmg_native_batch_export_cli_v1\",\n";
	out << "  \"status\": \"blocked\",\n";
	out << "  \"blocked_reason\": \"native_rmg_core_still_godot_variant_bound\",\n";
	out << "  \"runner\": \"standalone_native_cli_no_godot\",\n";
	out << "  \"godot_process_started\": false,\n";
	out << "  \"output_dir\": \"" << json_escape(options.output_dir.string()) << "\",\n";
	out << "  \"absolute_output_dir\": \"" << json_escape(absolute_output_dir.string()) << "\",\n";
	out << "  \"case_scope\": \"no_godot_cli_boundary_only_until_core_split\",\n";
	out << "  \"case_filter\": \"" << json_escape(options.case_filter) << "\",\n";
	out << "  \"case_limit\": " << options.limit << ",\n";
	out << "  \"include_unsupported\": " << (options.include_unsupported ? "true" : "false") << ",\n";
	out << "  \"emit_phase_snapshot\": " << (options.emit_phase_snapshot ? "true" : "false") << ",\n";
	out << "  \"controlled_case_count\": " << options.controlled_cases.size() << ",\n";
	out << "  \"controlled_cases\": ";
	append_json_string_array(out, options.controlled_cases);
	out << ",\n";
	out << "  \"case_count\": 0,\n";
	out << "  \"exported_count\": 0,\n";
	out << "  \"failed_count\": 0,\n";
	out << "  \"required_next_slice\": \"split_h3maped_rmg_generation_core_from_godot_variant_refcounted_fileaccess_api_before_running_native_exports_on_memory_constrained_hosts\",\n";
	out << "  \"message\": \"This executable is the no-Godot boundary. It intentionally refuses map generation until the native RMG core is available through plain C++ data structures instead of Godot engine APIs.\"\n";
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

	const std::string manifest = manifest_json(options, absolute_output_dir);
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
			  << " reason=native_rmg_core_still_godot_variant_bound\n";
	return 2;
}
