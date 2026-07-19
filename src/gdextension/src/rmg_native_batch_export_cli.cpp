#include "rmg_native_core.hpp"

#include <algorithm>
#include <cctype>
#include <cerrno>
#include <cstdint>
#include <cstdlib>
#include <cstring>
#include <filesystem>
#include <fstream>
#include <iomanip>
#include <iostream>
#include <limits>
#include <map>
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
	std::filesystem::path same_run_tile_payload_authority_path;
	std::filesystem::path same_run_object_payload_authority_path;
	std::filesystem::path same_run_full_payload_authority_path;
	std::filesystem::path same_run_payload_summary_path;
	std::filesystem::path same_run_ordered_writeout_spine_summary_path;
	std::filesystem::path same_run_preobject_trace_ledger_path;
	std::filesystem::path same_run_setup_stack_boundary_ledger_path;
	std::filesystem::path same_run_river_entry_args_ledger_path;
	std::filesystem::path same_run_river_overlay_write_ledger_path;
	std::filesystem::path same_run_road_type_rng_ledger_path;
	std::filesystem::path same_run_road_coordinate_vector_ledger_path;
	std::filesystem::path same_run_road_callstream_ledger_path;
	std::filesystem::path same_run_road_type_write_ledger_path;
	std::filesystem::path same_run_road_art_write_ledger_path;
	std::vector<std::string> controlled_cases;
	std::string case_filter;
	SharedRuntimeChainInput shared_runtime_chain_input;
	bool same_run_setup_stack_prefix_known = false;
	bool same_run_setup_prepared_arg8_known = false;
	int32_t same_run_setup_prepared_arg8 = 0;
	bool same_run_setup_caller_arg9_known = false;
	int32_t same_run_setup_caller_arg9 = 0;
	bool same_run_setup_object_0x4c_known = false;
	int32_t same_run_setup_object_0x4c = 0;
	int limit = 0;
	bool include_unsupported = false;
	bool emit_phase_snapshot = false;
	bool phase_snapshot_only = false;
	bool emit_final_h3m_payload = false;
	bool emit_runtime_package = false;
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

void append_json_int_array(std::ostream &out, const std::vector<int32_t> &values) {
	out << "[";
	for (size_t index = 0; index < values.size(); ++index) {
		if (index != 0) {
			out << ", ";
		}
		out << values[index];
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

bool extract_json_string_field(const std::string &text, const std::string &field_name, std::string &value) {
	const std::string key = "\"" + field_name + "\"";
	const size_t key_pos = text.find(key);
	if (key_pos == std::string::npos) {
		return false;
	}
	const size_t colon_pos = text.find(':', key_pos + key.size());
	if (colon_pos == std::string::npos) {
		return false;
	}
	const size_t quote_pos = text.find('"', colon_pos + 1);
	if (quote_pos == std::string::npos) {
		return false;
	}
	std::string decoded;
	for (size_t index = quote_pos + 1; index < text.size(); ++index) {
		const char ch = text[index];
		if (ch == '"') {
			value = decoded;
			return true;
		}
		if (ch == '\\' && index + 1 < text.size()) {
			decoded.push_back(text[++index]);
		} else {
			decoded.push_back(ch);
		}
	}
	return false;
}

bool json_bool_field_true(const std::string &text, const std::string &field_name) {
	const std::string key = "\"" + field_name + "\"";
	const size_t key_pos = text.find(key);
	if (key_pos == std::string::npos) {
		return false;
	}
	const size_t colon_pos = text.find(':', key_pos + key.size());
	if (colon_pos == std::string::npos) {
		return false;
	}
	size_t value_pos = colon_pos + 1;
	while (value_pos < text.size() && std::isspace(static_cast<unsigned char>(text[value_pos]))) {
		++value_pos;
	}
	return text.compare(value_pos, 4, "true") == 0;
}

bool extract_i32_field_between(
		const std::string &text,
		size_t begin,
		size_t end,
		const std::string &field_name,
		int32_t &value);

bool extract_i32_words_array_after(
		const std::string &text,
		size_t words_pos,
		size_t end,
		std::vector<int32_t> &words_out);

bool extract_setup_stack_args_0x49ecf2_from_ledger_text(const std::string &ledger_text, std::vector<int32_t> &args) {
	const size_t event_pos = ledger_text.find("\"address\": \"0x0049ecf2\"");
	if (event_pos == std::string::npos) {
		return false;
	}
	size_t event_end = ledger_text.find("\"stop_kind\"", event_pos);
	if (event_end != std::string::npos) {
		const size_t object_end = ledger_text.find("\n    }", event_end);
		if (object_end != std::string::npos) {
			event_end = object_end;
		}
	}
	if (event_end == std::string::npos) {
		event_end = ledger_text.find("\"registers\"", event_pos);
	}
	if (event_end == std::string::npos) {
		event_end = ledger_text.find("\n    }", event_pos);
	}
	if (event_end == std::string::npos) {
		event_end = ledger_text.size();
	}
	int32_t esp = 0;
	if (extract_i32_field_between(ledger_text, event_pos, event_end, "esp", esp) && esp > 0) {
		std::map<int32_t, int32_t> stack_words_by_address;
		size_t memory_line_pos = event_pos;
		while (memory_line_pos < event_end) {
			memory_line_pos = ledger_text.find("\"address\"", memory_line_pos);
			if (memory_line_pos == std::string::npos || memory_line_pos >= event_end) {
				break;
			}
			const size_t colon_pos = ledger_text.find(':', memory_line_pos);
			if (colon_pos == std::string::npos || colon_pos >= event_end) {
				break;
			}
			const char *cursor_chars = ledger_text.c_str() + colon_pos + 1;
			while (*cursor_chars != '\0' && std::isspace(static_cast<unsigned char>(*cursor_chars))) {
				++cursor_chars;
			}
			if (*cursor_chars == '"') {
				memory_line_pos = colon_pos + 1;
				continue;
			}
			char *next = nullptr;
			const long parsed_address = std::strtol(cursor_chars, &next, 0);
			if (next == cursor_chars
					|| parsed_address < std::numeric_limits<int32_t>::min()
					|| parsed_address > std::numeric_limits<int32_t>::max()) {
				memory_line_pos = colon_pos + 1;
				continue;
			}
			const int32_t line_address = static_cast<int32_t>(parsed_address);
			const size_t words_pos = ledger_text.find("\"words\"", size_t(next - ledger_text.c_str()));
			if (words_pos == std::string::npos || words_pos >= event_end) {
				break;
			}
			const size_t next_address_pos = ledger_text.find("\"address\"", size_t(next - ledger_text.c_str()));
			if (next_address_pos != std::string::npos && next_address_pos < words_pos) {
				memory_line_pos = next_address_pos;
				continue;
			}
			std::vector<int32_t> words;
			if (extract_i32_words_array_after(ledger_text, words_pos, event_end, words)) {
				for (size_t index = 0; index < words.size(); ++index) {
					const int64_t word_address = int64_t(line_address) + int64_t(index) * 4;
					if (word_address >= esp
							&& word_address <= int64_t(esp) + int64_t(aurelion::h3maped_rmg_core::RMG_SETUP_STACK_ARG_COUNT_0X49ECF2) * 4
							&& word_address >= std::numeric_limits<int32_t>::min()
							&& word_address <= std::numeric_limits<int32_t>::max()) {
						stack_words_by_address.emplace(static_cast<int32_t>(word_address), words[index]);
					}
				}
			}
			memory_line_pos = words_pos + 1;
		}
		std::vector<int32_t> reconstructed;
		for (size_t index = 0;
				index <= size_t(aurelion::h3maped_rmg_core::RMG_SETUP_STACK_ARG_COUNT_0X49ECF2);
				++index) {
			const int64_t word_address = int64_t(esp) + int64_t(index) * 4;
			if (word_address < std::numeric_limits<int32_t>::min()
					|| word_address > std::numeric_limits<int32_t>::max()) {
				break;
			}
			const auto found = stack_words_by_address.find(static_cast<int32_t>(word_address));
			if (found == stack_words_by_address.end()) {
				break;
			}
			reconstructed.push_back(found->second);
		}
		if (reconstructed.size() > 1) {
			args.clear();
			for (size_t index = 1; index < reconstructed.size()
					&& args.size() < size_t(aurelion::h3maped_rmg_core::RMG_SETUP_STACK_ARG_COUNT_0X49ECF2); ++index) {
				args.push_back(reconstructed[index]);
			}
			return !args.empty();
		}
	}
	{
		std::map<int32_t, int32_t> memory_words_by_address;
		size_t memory_line_pos = event_pos;
		while (memory_line_pos < event_end) {
			memory_line_pos = ledger_text.find("\"address\"", memory_line_pos);
			if (memory_line_pos == std::string::npos || memory_line_pos >= event_end) {
				break;
			}
			const size_t colon_pos = ledger_text.find(':', memory_line_pos);
			if (colon_pos == std::string::npos || colon_pos >= event_end) {
				break;
			}
			const char *cursor_chars = ledger_text.c_str() + colon_pos + 1;
			while (*cursor_chars != '\0' && std::isspace(static_cast<unsigned char>(*cursor_chars))) {
				++cursor_chars;
			}
			if (*cursor_chars == '"') {
				memory_line_pos = colon_pos + 1;
				continue;
			}
			char *next = nullptr;
			const long parsed_address = std::strtol(cursor_chars, &next, 0);
			if (next == cursor_chars
					|| parsed_address < std::numeric_limits<int32_t>::min()
					|| parsed_address > std::numeric_limits<int32_t>::max()) {
				memory_line_pos = colon_pos + 1;
				continue;
			}
			const size_t words_pos = ledger_text.find("\"words\"", size_t(next - ledger_text.c_str()));
			const size_t next_address_pos = ledger_text.find("\"address\"", size_t(next - ledger_text.c_str()));
			if (words_pos == std::string::npos || words_pos >= event_end) {
				break;
			}
			if (next_address_pos != std::string::npos && next_address_pos < words_pos) {
				memory_line_pos = next_address_pos;
				continue;
			}
			std::vector<int32_t> words;
			if (extract_i32_words_array_after(ledger_text, words_pos, event_end, words)) {
				for (size_t index = 0; index < words.size(); ++index) {
					const int64_t word_address = parsed_address + int64_t(index) * 4;
					if (word_address >= std::numeric_limits<int32_t>::min()
							&& word_address <= std::numeric_limits<int32_t>::max()) {
						memory_words_by_address.emplace(int32_t(word_address), words[index]);
					}
				}
			}
			memory_line_pos = words_pos + 1;
		}
		for (const auto &candidate : memory_words_by_address) {
			const int32_t stack_base = candidate.first;
			const auto width_word = memory_words_by_address.find(stack_base + 4);
			const auto height_word = memory_words_by_address.find(stack_base + 8);
			const auto level_word = memory_words_by_address.find(stack_base + 12);
			if (candidate.second < 0x00400000
					|| candidate.second > 0x00800000
					|| width_word == memory_words_by_address.end()
					|| height_word == memory_words_by_address.end()
					|| level_word == memory_words_by_address.end()
					|| width_word->second != height_word->second
					|| (width_word->second != 36 && width_word->second != 72
							&& width_word->second != 108 && width_word->second != 144)
					|| (level_word->second != 1 && level_word->second != 2)) {
				continue;
			}
			std::vector<int32_t> reconstructed;
			for (size_t index = 0;
					index <= size_t(aurelion::h3maped_rmg_core::RMG_SETUP_STACK_ARG_COUNT_0X49ECF2);
					++index) {
				const auto found = memory_words_by_address.find(stack_base + int32_t(index * 4));
				if (found == memory_words_by_address.end()) {
					break;
				}
				reconstructed.push_back(found->second);
			}
			if (reconstructed.size()
					== size_t(aurelion::h3maped_rmg_core::RMG_SETUP_STACK_ARG_COUNT_0X49ECF2) + 1U) {
				args.assign(reconstructed.begin() + 1, reconstructed.end());
				return true;
			}
		}
	}
	std::vector<int32_t> stack_words;
	size_t cursor = event_pos;
	while (cursor < event_end) {
		const size_t words_pos = ledger_text.find("\"words\"", cursor);
		if (words_pos == std::string::npos || words_pos >= event_end) {
			break;
		}
		const size_t open_pos = ledger_text.find('[', words_pos);
		const size_t close_pos = ledger_text.find(']', open_pos);
		if (open_pos == std::string::npos || close_pos == std::string::npos || close_pos > event_end) {
			break;
		}
		const std::string words = ledger_text.substr(open_pos + 1, close_pos - open_pos - 1);
		const char *cursor_chars = words.c_str();
		while (*cursor_chars != '\0') {
			while (*cursor_chars != '\0' && (std::isspace(static_cast<unsigned char>(*cursor_chars)) || *cursor_chars == ',')) {
				++cursor_chars;
			}
			if (*cursor_chars == '\0') {
				break;
			}
			char *next = nullptr;
			const long value = std::strtol(cursor_chars, &next, 0);
			if (next == cursor_chars) {
				++cursor_chars;
				continue;
			}
			if (value >= std::numeric_limits<int32_t>::min() && value <= std::numeric_limits<int32_t>::max()) {
				stack_words.push_back(static_cast<int32_t>(value));
			}
			cursor_chars = next;
		}
		cursor = close_pos + 1;
	}
	if (stack_words.size() <= 1) {
		return false;
	}
	args.clear();
	for (size_t index = 1; index < stack_words.size()
			&& args.size() < size_t(aurelion::h3maped_rmg_core::RMG_SETUP_STACK_ARG_COUNT_0X49ECF2); ++index) {
		args.push_back(stack_words[index]);
	}
	return !args.empty();
}

bool extract_stack_args_from_ledger_event_text(
		const std::string &ledger_text,
		const std::string &address,
		size_t arg_count,
		std::vector<int32_t> &args) {
	const size_t event_pos = ledger_text.find("\"address\": \"" + address + "\"");
	if (event_pos == std::string::npos) {
		return false;
	}
	size_t event_end = ledger_text.find("\"stop_kind\"", event_pos);
	if (event_end != std::string::npos) {
		const size_t object_end = ledger_text.find("\n    }", event_end);
		if (object_end != std::string::npos) {
			event_end = object_end;
		}
	}
	if (event_end == std::string::npos) {
		event_end = ledger_text.find("\"registers\"", event_pos);
	}
	if (event_end == std::string::npos) {
		event_end = ledger_text.find("\n    }", event_pos);
	}
	if (event_end == std::string::npos) {
		event_end = ledger_text.size();
	}
	int32_t esp = 0;
	if (!extract_i32_field_between(ledger_text, event_pos, event_end, "esp", esp) || esp <= 0) {
		return false;
	}
	std::map<int32_t, int32_t> stack_words_by_address;
	size_t memory_line_pos = event_pos;
	while (memory_line_pos < event_end) {
		memory_line_pos = ledger_text.find("\"address\"", memory_line_pos);
		if (memory_line_pos == std::string::npos || memory_line_pos >= event_end) {
			break;
		}
		const size_t colon_pos = ledger_text.find(':', memory_line_pos);
		if (colon_pos == std::string::npos || colon_pos >= event_end) {
			break;
		}
		const char *cursor_chars = ledger_text.c_str() + colon_pos + 1;
		while (*cursor_chars != '\0' && std::isspace(static_cast<unsigned char>(*cursor_chars))) {
			++cursor_chars;
		}
		if (*cursor_chars == '"') {
			memory_line_pos = colon_pos + 1;
			continue;
		}
		char *next = nullptr;
		const long parsed_address = std::strtol(cursor_chars, &next, 0);
		if (next == cursor_chars
				|| parsed_address < std::numeric_limits<int32_t>::min()
				|| parsed_address > std::numeric_limits<int32_t>::max()) {
			memory_line_pos = colon_pos + 1;
			continue;
		}
		const int32_t line_address = static_cast<int32_t>(parsed_address);
		const size_t words_pos = ledger_text.find("\"words\"", size_t(next - ledger_text.c_str()));
		if (words_pos == std::string::npos || words_pos >= event_end) {
			break;
		}
		const size_t next_address_pos = ledger_text.find("\"address\"", size_t(next - ledger_text.c_str()));
		if (next_address_pos != std::string::npos && next_address_pos < words_pos) {
			memory_line_pos = next_address_pos;
			continue;
		}
		std::vector<int32_t> words;
		if (extract_i32_words_array_after(ledger_text, words_pos, event_end, words)) {
			for (size_t index = 0; index < words.size(); ++index) {
				const int64_t word_address = int64_t(line_address) + int64_t(index) * 4;
				if (word_address >= esp
						&& word_address <= int64_t(esp) + int64_t(arg_count) * 4
						&& word_address >= std::numeric_limits<int32_t>::min()
						&& word_address <= std::numeric_limits<int32_t>::max()) {
					stack_words_by_address.emplace(static_cast<int32_t>(word_address), words[index]);
				}
			}
		}
		memory_line_pos = words_pos + 1;
	}
	std::vector<int32_t> reconstructed;
	for (size_t index = 0; index <= arg_count; ++index) {
		const int64_t word_address = int64_t(esp) + int64_t(index) * 4;
		if (word_address < std::numeric_limits<int32_t>::min()
				|| word_address > std::numeric_limits<int32_t>::max()) {
			return false;
		}
		const auto found = stack_words_by_address.find(static_cast<int32_t>(word_address));
		if (found == stack_words_by_address.end()) {
			return false;
		}
		reconstructed.push_back(found->second);
	}
	if (reconstructed.size() != arg_count + 1U) {
		return false;
	}
	args.clear();
	for (size_t index = 1; index < reconstructed.size(); ++index) {
		args.push_back(reconstructed[index]);
	}
	return args.size() == arg_count;
}

bool extract_stack_arg_from_ledger_event_text(
		const std::string &ledger_text,
		const std::string &address,
		size_t arg_index,
		int32_t &value) {
	const size_t event_pos = ledger_text.find("\"address\": \"" + address + "\"");
	if (event_pos == std::string::npos) {
		return false;
	}
	size_t event_end = ledger_text.find("\"registers\"", event_pos);
	if (event_end == std::string::npos) {
		event_end = ledger_text.find("\n    }", event_pos);
	}
	if (event_end == std::string::npos) {
		event_end = ledger_text.size();
	}
	std::vector<int32_t> stack_words;
	size_t cursor = event_pos;
	while (cursor < event_end) {
		const size_t words_pos = ledger_text.find("\"words\"", cursor);
		if (words_pos == std::string::npos || words_pos >= event_end) {
			break;
		}
		const size_t open_pos = ledger_text.find('[', words_pos);
		const size_t close_pos = ledger_text.find(']', open_pos);
		if (open_pos == std::string::npos || close_pos == std::string::npos || close_pos > event_end) {
			break;
		}
		const std::string words = ledger_text.substr(open_pos + 1, close_pos - open_pos - 1);
		const char *cursor_chars = words.c_str();
		while (*cursor_chars != '\0') {
			while (*cursor_chars != '\0' && (std::isspace(static_cast<unsigned char>(*cursor_chars)) || *cursor_chars == ',')) {
				++cursor_chars;
			}
			if (*cursor_chars == '\0') {
				break;
			}
			char *next = nullptr;
			const long parsed = std::strtol(cursor_chars, &next, 0);
			if (next == cursor_chars) {
				++cursor_chars;
				continue;
			}
			if (parsed >= std::numeric_limits<int32_t>::min() && parsed <= std::numeric_limits<int32_t>::max()) {
				stack_words.push_back(static_cast<int32_t>(parsed));
			}
			cursor_chars = next;
		}
		cursor = close_pos + 1;
	}
	const size_t word_index = arg_index + 1; // skip return address
	if (word_index >= stack_words.size()) {
		return false;
	}
	value = stack_words[word_index];
	return true;
}

bool extract_i32_field_between(
		const std::string &text,
		size_t begin,
		size_t end,
		const std::string &field_name,
		int32_t &value) {
	const std::string key = "\"" + field_name + "\"";
	const size_t key_pos = text.find(key, begin);
	if (key_pos == std::string::npos || key_pos >= end) {
		return false;
	}
	const size_t colon_pos = text.find(':', key_pos + key.size());
	if (colon_pos == std::string::npos || colon_pos >= end) {
		return false;
	}
	const char *cursor = text.c_str() + colon_pos + 1;
	char *next = nullptr;
	const long parsed = std::strtol(cursor, &next, 0);
	if (next == cursor || parsed < std::numeric_limits<int32_t>::min() || parsed > std::numeric_limits<int32_t>::max()) {
		return false;
	}
	value = static_cast<int32_t>(parsed);
	return true;
}

bool extract_json_i32_field(const std::string &text, const std::string &field_name, int32_t &value) {
	return extract_i32_field_between(text, 0, text.size(), field_name, value);
}

bool extract_i32_words_array_after(
		const std::string &text,
		size_t words_pos,
		size_t end,
		std::vector<int32_t> &words_out) {
	if (words_pos == std::string::npos || words_pos >= end) {
		return false;
	}
	const size_t open_pos = text.find('[', words_pos);
	const size_t close_pos = text.find(']', open_pos);
	if (open_pos == std::string::npos || close_pos == std::string::npos || close_pos > end) {
		return false;
	}
	std::vector<int32_t> parsed_words;
	const std::string words = text.substr(open_pos + 1, close_pos - open_pos - 1);
	const char *cursor_chars = words.c_str();
	while (*cursor_chars != '\0') {
		while (*cursor_chars != '\0' && (std::isspace(static_cast<unsigned char>(*cursor_chars)) || *cursor_chars == ',')) {
			++cursor_chars;
		}
		if (*cursor_chars == '\0') {
			break;
		}
		char *next = nullptr;
		const long long parsed = std::strtoll(cursor_chars, &next, 0);
		if (next == cursor_chars) {
			++cursor_chars;
			continue;
		}
		if (parsed >= std::numeric_limits<int32_t>::min() && parsed <= std::numeric_limits<int32_t>::max()) {
			parsed_words.push_back(static_cast<int32_t>(parsed));
		}
		cursor_chars = next;
	}
	if (parsed_words.empty()) {
		return false;
	}
	words_out = std::move(parsed_words);
	return true;
}

size_t ledger_event_end_after(size_t event_pos, const std::string &ledger_text) {
	size_t event_end = ledger_text.find("\"stop_kind\"", event_pos);
	if (event_end != std::string::npos) {
		const size_t object_end = ledger_text.find("\n    }", event_end);
		if (object_end != std::string::npos) {
			return object_end;
		}
	}
	event_end = ledger_text.find("\"registers\"", event_pos);
	if (event_end != std::string::npos) {
		const size_t object_end = ledger_text.find("\n    }", event_end);
		if (object_end != std::string::npos) {
			return object_end;
		}
	}
	event_end = ledger_text.find("\n    }", event_pos);
	return event_end == std::string::npos ? ledger_text.size() : event_end;
}

bool extract_memory_words_at_address_between(
		const std::string &ledger_text,
		size_t event_pos,
		size_t event_end,
		int32_t target_address,
		std::vector<int32_t> &words_out) {
	size_t memory_line_pos = event_pos;
	while (memory_line_pos < event_end) {
		memory_line_pos = ledger_text.find("\"address\"", memory_line_pos);
		if (memory_line_pos == std::string::npos || memory_line_pos >= event_end) {
			return false;
		}
		const size_t colon_pos = ledger_text.find(':', memory_line_pos);
		if (colon_pos == std::string::npos || colon_pos >= event_end) {
			return false;
		}
		const char *cursor_chars = ledger_text.c_str() + colon_pos + 1;
		while (*cursor_chars != '\0' && std::isspace(static_cast<unsigned char>(*cursor_chars))) {
			++cursor_chars;
		}
		if (*cursor_chars == '"') {
			memory_line_pos = colon_pos + 1;
			continue;
		}
		char *next = nullptr;
		const long parsed_address = std::strtol(cursor_chars, &next, 0);
		if (next == cursor_chars
				|| parsed_address < std::numeric_limits<int32_t>::min()
				|| parsed_address > std::numeric_limits<int32_t>::max()) {
			memory_line_pos = colon_pos + 1;
			continue;
		}
		const size_t words_pos = ledger_text.find("\"words\"", size_t(next - ledger_text.c_str()));
		if (words_pos == std::string::npos || words_pos >= event_end) {
			return false;
		}
		const size_t next_address_pos = ledger_text.find("\"address\"", size_t(next - ledger_text.c_str()));
		if (next_address_pos != std::string::npos && next_address_pos < words_pos) {
			memory_line_pos = next_address_pos;
			continue;
		}
		if (parsed_address == target_address) {
			return extract_i32_words_array_after(ledger_text, words_pos, event_end, words_out);
		}
		memory_line_pos = words_pos + 1;
	}
	return false;
}

bool extract_stack_args_from_ledger_event_range(
		const std::string &ledger_text,
		size_t event_pos,
		size_t event_end,
		size_t arg_count,
		std::vector<int32_t> &args) {
	int32_t esp = 0;
	if (!extract_i32_field_between(ledger_text, event_pos, event_end, "esp", esp) || esp <= 0) {
		return false;
	}
	std::map<int32_t, int32_t> stack_words_by_address;
	size_t memory_line_pos = event_pos;
	while (memory_line_pos < event_end) {
		memory_line_pos = ledger_text.find("\"address\"", memory_line_pos);
		if (memory_line_pos == std::string::npos || memory_line_pos >= event_end) {
			break;
		}
		const size_t colon_pos = ledger_text.find(':', memory_line_pos);
		if (colon_pos == std::string::npos || colon_pos >= event_end) {
			break;
		}
		const char *cursor_chars = ledger_text.c_str() + colon_pos + 1;
		while (*cursor_chars != '\0' && std::isspace(static_cast<unsigned char>(*cursor_chars))) {
			++cursor_chars;
		}
		if (*cursor_chars == '"') {
			memory_line_pos = colon_pos + 1;
			continue;
		}
		char *next = nullptr;
		const long parsed_address = std::strtol(cursor_chars, &next, 0);
		if (next == cursor_chars
				|| parsed_address < std::numeric_limits<int32_t>::min()
				|| parsed_address > std::numeric_limits<int32_t>::max()) {
			memory_line_pos = colon_pos + 1;
			continue;
		}
		const int32_t line_address = static_cast<int32_t>(parsed_address);
		const size_t words_pos = ledger_text.find("\"words\"", size_t(next - ledger_text.c_str()));
		if (words_pos == std::string::npos || words_pos >= event_end) {
			break;
		}
		const size_t next_address_pos = ledger_text.find("\"address\"", size_t(next - ledger_text.c_str()));
		if (next_address_pos != std::string::npos && next_address_pos < words_pos) {
			memory_line_pos = next_address_pos;
			continue;
		}
		std::vector<int32_t> words;
		if (extract_i32_words_array_after(ledger_text, words_pos, event_end, words)) {
			for (size_t index = 0; index < words.size(); ++index) {
				const int64_t word_address = int64_t(line_address) + int64_t(index) * 4;
				if (word_address >= esp
						&& word_address <= int64_t(esp) + int64_t(arg_count) * 4
						&& word_address >= std::numeric_limits<int32_t>::min()
						&& word_address <= std::numeric_limits<int32_t>::max()) {
					stack_words_by_address.emplace(static_cast<int32_t>(word_address), words[index]);
				}
			}
		}
		memory_line_pos = words_pos + 1;
	}
	std::vector<int32_t> reconstructed;
	for (size_t index = 0; index <= arg_count; ++index) {
		const int64_t word_address = int64_t(esp) + int64_t(index) * 4;
		if (word_address < std::numeric_limits<int32_t>::min()
				|| word_address > std::numeric_limits<int32_t>::max()) {
			return false;
		}
		const auto found = stack_words_by_address.find(static_cast<int32_t>(word_address));
		if (found == stack_words_by_address.end()) {
			return false;
		}
		reconstructed.push_back(found->second);
	}
	args.clear();
	for (size_t index = 1; index < reconstructed.size(); ++index) {
		args.push_back(reconstructed[index]);
	}
	return args.size() == arg_count;
}

bool extract_final_grid_geometry_from_ledger_text(
		const std::string &ledger_text,
		int32_t &generated_cell_base,
		int32_t &width,
		int32_t &height,
		int32_t &level_count) {
	const size_t event_pos = ledger_text.find("\"address\": \"0x004ad251\"");
	if (event_pos == std::string::npos) {
		return false;
	}
	const size_t event_end = ledger_event_end_after(event_pos, ledger_text);
	int32_t esi = 0;
	if (!extract_i32_field_between(ledger_text, event_pos, event_end, "esi", esi)) {
		return false;
	}
	std::vector<int32_t> grid_words;
	if (!extract_memory_words_at_address_between(ledger_text, event_pos, event_end, esi + 16, grid_words)
			|| grid_words.size() < 4) {
		return false;
	}
	std::vector<int32_t> level_words;
	if (!extract_memory_words_at_address_between(ledger_text, event_pos, event_end, esi + 32, level_words)
			|| level_words.empty()) {
		return false;
	}
	generated_cell_base = grid_words[1];
	width = grid_words[2];
	height = grid_words[3];
	level_count = level_words[0];
	return generated_cell_base > 0 && width > 0 && height > 0 && level_count > 0;
}

bool extract_generator_field_0x08_from_4a4c8e_ledger_text(const std::string &ledger_text, int32_t &value) {
	const size_t event_pos = ledger_text.find("\"address\": \"0x004a4c8e\"");
	if (event_pos == std::string::npos) {
		return false;
	}
	size_t event_end = ledger_text.find("\"stop_kind\"", event_pos);
	if (event_end == std::string::npos) {
		event_end = ledger_text.find("\n    }", event_pos);
	}
	if (event_end == std::string::npos) {
		event_end = ledger_text.size();
	}
	int32_t generator_address = 0;
	if (!extract_i32_field_between(ledger_text, event_pos, event_end, "esi", generator_address)) {
		return false;
	}
	const std::string address_key = "\"address\": " + std::to_string(generator_address);
	size_t memory_line_pos = event_pos;
	while (memory_line_pos < event_end) {
		memory_line_pos = ledger_text.find(address_key, memory_line_pos);
		if (memory_line_pos == std::string::npos || memory_line_pos >= event_end) {
			return false;
		}
		const size_t words_pos = ledger_text.find("\"words\"", memory_line_pos);
		if (words_pos == std::string::npos || words_pos >= event_end) {
			return false;
		}
		std::vector<int32_t> words;
		if (extract_i32_words_array_after(ledger_text, words_pos, event_end, words) && words.size() >= 3) {
			value = words[2];
			return true;
		}
		memory_line_pos += address_key.size();
	}
	return false;
}

bool extract_setup_arg8_prepared_0x49ecf2_from_ledger_text(const std::string &ledger_text, int32_t &value) {
	const size_t event_pos = ledger_text.find("\"address\": \"0x0049ecf2\"");
	if (event_pos == std::string::npos) {
		return false;
	}
	size_t event_end = ledger_text.find("\"stop_kind\"", event_pos);
	if (event_end == std::string::npos) {
		event_end = ledger_text.find("\n    }", event_pos);
	}
	if (event_end == std::string::npos) {
		event_end = ledger_text.size();
	}
	return extract_i32_field_between(ledger_text, event_pos, event_end, "eax", value);
}

bool extract_river_entry_args_from_ledger_text(
		const std::string &ledger_text,
		std::vector<int32_t> &args_4ab6ac,
		std::vector<int32_t> &args_4abd5f) {
	std::vector<int32_t> first_args;
	std::vector<int32_t> second_args;
	if (!extract_stack_args_from_ledger_event_text(ledger_text, "0x004ab6ac", 4, first_args)
			|| !extract_stack_args_from_ledger_event_text(ledger_text, "0x004abd5f", 4, second_args)) {
		return false;
	}
	args_4ab6ac = std::move(first_args);
	args_4abd5f = std::move(second_args);
	return true;
}

bool extract_river_overlay_writes_from_ledger_text(
		const std::string &ledger_text,
		std::vector<aurelion::h3maped_rmg_core::RecoveredRiverOverlayWrite49b1bc49b170> &writes_out) {
	int32_t generated_cell_base = 0;
	int32_t width = 0;
	int32_t height = 0;
	int32_t level_count = 0;
	if (!extract_final_grid_geometry_from_ledger_text(
				ledger_text,
				generated_cell_base,
				width,
				height,
				level_count)) {
		return false;
	}
	std::vector<aurelion::h3maped_rmg_core::RecoveredRiverOverlayWrite49b1bc49b170> writes;
	size_t cursor = 0;
	while (cursor < ledger_text.size()) {
		const size_t type_pos = ledger_text.find("\"address\": \"0x0049b1bc\"", cursor);
		const size_t art_pos = ledger_text.find("\"address\": \"0x0049b170\"", cursor);
		if (type_pos == std::string::npos && art_pos == std::string::npos) {
			break;
		}
		const bool use_type = art_pos == std::string::npos || (type_pos != std::string::npos && type_pos < art_pos);
		const size_t event_pos = use_type ? type_pos : art_pos;
		const size_t event_end = ledger_event_end_after(event_pos, ledger_text);
		std::vector<int32_t> stack_args;
		if (use_type) {
			if (!extract_stack_args_from_ledger_event_range(ledger_text, event_pos, event_end, 2, stack_args)
					|| stack_args.size() < 2) {
				return false;
			}
			std::vector<int32_t> coord_words;
			if (!extract_memory_words_at_address_between(ledger_text, event_pos, event_end, stack_args[0], coord_words)
					|| coord_words.size() < 2) {
				return false;
			}
			aurelion::h3maped_rmg_core::RecoveredRiverOverlayWrite49b1bc49b170 write;
			write.callsite = 0x0049b1bcU;
			write.x = coord_words[0];
			write.y = coord_words[1];
			write.level = 0;
			write.river_type = stack_args[1];
			writes.push_back(write);
		} else {
			if (!extract_stack_args_from_ledger_event_range(ledger_text, event_pos, event_end, 4, stack_args)
					|| stack_args.size() < 4) {
				return false;
			}
			int32_t ecx = 0;
			if (!extract_i32_field_between(ledger_text, event_pos, event_end, "ecx", ecx)) {
				return false;
			}
			const int64_t record_offset = int64_t(ecx) - int64_t(generated_cell_base);
			if (record_offset < 0
					|| (record_offset % aurelion::h3maped_rmg_core::GENERATED_CELL_RECORD_STRIDE_BYTES) != 0) {
				return false;
			}
			const int64_t flat = record_offset / aurelion::h3maped_rmg_core::GENERATED_CELL_RECORD_STRIDE_BYTES;
			const int64_t level_tile_count = int64_t(width) * int64_t(height);
			if (flat < 0
					|| level_tile_count <= 0
					|| flat >= level_tile_count * int64_t(level_count)
					|| flat > std::numeric_limits<int32_t>::max()) {
				return false;
			}
			aurelion::h3maped_rmg_core::RecoveredRiverOverlayWrite49b1bc49b170 write;
			write.callsite = 0x0049b170U;
			write.level = int32_t(flat / level_tile_count);
			const int32_t level_flat = int32_t(flat % level_tile_count);
			write.x = level_flat % width;
			write.y = level_flat / width;
			write.river_type = stack_args[0];
			write.river_art = stack_args[1];
			write.flag_arg3 = stack_args[2];
			write.flag_arg4 = stack_args[3];
			writes.push_back(write);
		}
		cursor = event_end + 1;
	}
	if (writes.empty()) {
		return false;
	}
	writes_out = std::move(writes);
	return true;
}

bool extract_road_type_rng_value_from_ledger_text(const std::string &ledger_text, int32_t &rng_value) {
	const size_t event_pos = ledger_text.find("\"address\": \"0x004ab53a\"");
	if (event_pos == std::string::npos) {
		return false;
	}
	const size_t event_end = ledger_event_end_after(event_pos, ledger_text);
	return extract_i32_field_between(ledger_text, event_pos, event_end, "eax", rng_value)
			&& rng_value >= 0;
}

bool extract_road_coordinate_records_from_ledger_text(
		const std::string &ledger_text,
		std::vector<aurelion::h3maped_rmg_core::RoadCoordinateRecord14b0> &records_out) {
	const size_t event_pos = ledger_text.find("\"address\": \"0x004ab52a\"");
	if (event_pos == std::string::npos) {
		return false;
	}
	const size_t event_end = ledger_event_end_after(event_pos, ledger_text);
	int32_t begin = 0;
	int32_t end = 0;
	size_t memory_line_pos = event_pos;
	while (memory_line_pos < event_end) {
		const size_t words_pos = ledger_text.find("\"words\"", memory_line_pos);
		if (words_pos == std::string::npos || words_pos >= event_end) {
			break;
		}
		std::vector<int32_t> words;
		if (extract_i32_words_array_after(ledger_text, words_pos, event_end, words)
				&& words.size() >= 4
				&& words[1] > 0
				&& words[2] > words[1]
				&& ((words[2] - words[1]) % 12) == 0) {
			begin = words[1];
			end = words[2];
			break;
		}
		memory_line_pos = words_pos + 1;
	}
	if (begin <= 0 || end <= begin) {
		return false;
	}
	std::map<int32_t, int32_t> word_by_address;
	memory_line_pos = event_pos;
	while (memory_line_pos < event_end) {
		memory_line_pos = ledger_text.find("\"address\"", memory_line_pos);
		if (memory_line_pos == std::string::npos || memory_line_pos >= event_end) {
			break;
		}
		const size_t colon_pos = ledger_text.find(':', memory_line_pos);
		if (colon_pos == std::string::npos || colon_pos >= event_end) {
			break;
		}
		const char *cursor_chars = ledger_text.c_str() + colon_pos + 1;
		while (*cursor_chars != '\0' && std::isspace(static_cast<unsigned char>(*cursor_chars))) {
			++cursor_chars;
		}
		if (*cursor_chars == '"') {
			memory_line_pos = colon_pos + 1;
			continue;
		}
		char *next = nullptr;
		const long parsed_address = std::strtol(cursor_chars, &next, 0);
		if (next == cursor_chars
				|| parsed_address < std::numeric_limits<int32_t>::min()
				|| parsed_address > std::numeric_limits<int32_t>::max()) {
			memory_line_pos = colon_pos + 1;
			continue;
		}
		const size_t words_pos = ledger_text.find("\"words\"", size_t(next - ledger_text.c_str()));
		if (words_pos == std::string::npos || words_pos >= event_end) {
			break;
		}
		const size_t next_address_pos = ledger_text.find("\"address\"", size_t(next - ledger_text.c_str()));
		if (next_address_pos != std::string::npos && next_address_pos < words_pos) {
			memory_line_pos = next_address_pos;
			continue;
		}
		std::vector<int32_t> words;
		if (extract_i32_words_array_after(ledger_text, words_pos, event_end, words)) {
			for (size_t index = 0; index < words.size(); ++index) {
				const int64_t word_address = int64_t(parsed_address) + int64_t(index) * 4;
				if (word_address >= begin
						&& word_address < end
						&& word_address >= std::numeric_limits<int32_t>::min()
						&& word_address <= std::numeric_limits<int32_t>::max()) {
					word_by_address[static_cast<int32_t>(word_address)] = words[index];
				}
			}
		}
		memory_line_pos = words_pos + 1;
	}
	std::vector<int32_t> words;
	for (int32_t address = begin; address < end; address += 4) {
		const auto found = word_by_address.find(address);
		if (found == word_by_address.end()) {
			return false;
		}
		words.push_back(found->second);
	}
	if (words.empty() || (words.size() % 3) != 0U) {
		return false;
	}
	std::vector<aurelion::h3maped_rmg_core::RoadCoordinateRecord14b0> records;
	for (size_t index = 0; index < words.size(); index += 3) {
		aurelion::h3maped_rmg_core::RoadCoordinateRecord14b0 record;
		record.x = words[index];
		record.y = words[index + 1];
		record.level = words[index + 2];
		record.source_callsite = 0x004ab52aU;
		records.push_back(record);
	}
	records_out = std::move(records);
	return !records_out.empty();
}

bool extract_road_callstream_from_ledger_text(
		const std::string &ledger_text,
		std::vector<aurelion::h3maped_rmg_core::RecoveredRoadCall4ab37f> &calls_out) {
	std::vector<aurelion::h3maped_rmg_core::RecoveredRoadCall4ab37f> calls;
	size_t cursor = 0;
	while (cursor < ledger_text.size()) {
		const size_t event_pos = ledger_text.find("\"address\": \"0x004ab37f\"", cursor);
		if (event_pos == std::string::npos) {
			break;
		}
		const size_t event_end = ledger_event_end_after(event_pos, ledger_text);
		size_t memory_line_pos = event_pos;
		bool call_found = false;
		aurelion::h3maped_rmg_core::RecoveredRoadCall4ab37f call;
		call.callsite = 0x004ab37fU;
		call.sequence_index = int32_t(calls.size());
		while (memory_line_pos < event_end) {
			const size_t words_pos = ledger_text.find("\"words\"", memory_line_pos);
			if (words_pos == std::string::npos || words_pos >= event_end) {
				break;
			}
			std::vector<int32_t> words;
			if (extract_i32_words_array_after(ledger_text, words_pos, event_end, words)
					&& words.size() >= 4
					&& uint32_t(words[0]) == 0x004ab625U) {
				call.candidate_x = words[1];
				call.candidate_y = words[2];
				call.candidate_level = words[3];
				size_t road_type_words_pos = ledger_text.find("\"words\"", words_pos + 1);
				while (road_type_words_pos != std::string::npos && road_type_words_pos < event_end) {
					std::vector<int32_t> road_type_words;
					if (extract_i32_words_array_after(ledger_text, road_type_words_pos, event_end, road_type_words)
							&& !road_type_words.empty()
							&& road_type_words[0] >= 1
							&& road_type_words[0] <= 3) {
						call.selected_road_type = road_type_words[0];
						break;
					}
					road_type_words_pos = ledger_text.find("\"words\"", road_type_words_pos + 1);
				}
				call_found = true;
				break;
			}
			memory_line_pos = words_pos + 1;
		}
		if (!call_found) {
			return false;
		}
		const size_t next_entry_pos = ledger_text.find("\"address\": \"0x004ab37f\"", event_end + 1);
		const size_t return_pos = ledger_text.find("\"address\": \"0x004ab51c\"", event_end + 1);
		if (return_pos != std::string::npos
				&& (next_entry_pos == std::string::npos || return_pos < next_entry_pos)) {
			const size_t return_end = ledger_event_end_after(return_pos, ledger_text);
			size_t return_memory_line_pos = return_pos;
			while (return_memory_line_pos < return_end) {
				const size_t words_pos = ledger_text.find("\"words\"", return_memory_line_pos);
				if (words_pos == std::string::npos || words_pos >= return_end) {
					break;
				}
				std::vector<int32_t> words;
				if (extract_i32_words_array_after(ledger_text, words_pos, return_end, words)
						&& words.size() >= 4
						&& words[0] >= 0
						&& words[0] < 256
						&& words[1] >= 0
						&& words[1] < 256
						&& words[2] >= 0
						&& words[2] <= 7
						&& words[3] >= 1
						&& words[3] <= 3) {
					call.source_x = words[0];
					call.source_y = words[1];
					call.source_level = words[2];
					if (call.selected_road_type < 0) {
						call.selected_road_type = words[3];
					}
					break;
				}
				return_memory_line_pos = words_pos + 1;
			}
		}
		calls.push_back(call);
		cursor = event_end + 1;
	}
	calls_out = std::move(calls);
	return !calls_out.empty();
}

bool road_type_write_coord_matches_call_candidate(
		const aurelion::h3maped_rmg_core::RecoveredRoadTypeWrite49aec5 &write,
		const aurelion::h3maped_rmg_core::RecoveredRoadCall4ab37f &call) {
	return write.x == call.candidate_x
			&& write.y == call.candidate_y
			&& write.level == call.candidate_level;
}

bool assign_road_type_write_call_chunks_0x49aec5(
		std::vector<aurelion::h3maped_rmg_core::RecoveredRoadTypeWrite49aec5> &writes,
		const std::vector<aurelion::h3maped_rmg_core::RecoveredRoadCall4ab37f> &calls) {
	if (writes.empty() || calls.empty()) {
		return false;
	}
	size_t cursor = 0;
	for (size_t call_index = 0; call_index < calls.size() && cursor < writes.size(); ++call_index) {
		const aurelion::h3maped_rmg_core::RecoveredRoadCall4ab37f &call = calls[call_index];
		size_t start = writes.size();
		for (size_t index = cursor; index < writes.size(); ++index) {
			if (road_type_write_coord_matches_call_candidate(writes[index], call)) {
				start = index;
				break;
			}
		}
		if (start == writes.size()) {
			continue;
		}
		if (start != cursor) {
			return false;
		}
		size_t end = writes.size();
		for (size_t next_call_index = call_index + 1; next_call_index < calls.size(); ++next_call_index) {
			const aurelion::h3maped_rmg_core::RecoveredRoadCall4ab37f &next_call = calls[next_call_index];
			for (size_t index = start + 1; index < writes.size(); ++index) {
				if (road_type_write_coord_matches_call_candidate(writes[index], next_call)) {
					if (index < end) {
						end = index;
					}
					break;
				}
			}
		}
		const int32_t sequence_index = call.sequence_index >= 0
				? call.sequence_index
				: int32_t(call_index);
		for (size_t index = start; index < end; ++index) {
			writes[index].road_call_sequence_index = sequence_index;
		}
		cursor = end;
	}
	if (cursor != writes.size()) {
		return false;
	}
	for (const aurelion::h3maped_rmg_core::RecoveredRoadTypeWrite49aec5 &write : writes) {
		if (write.road_call_sequence_index < 0) {
			return false;
		}
	}
	return true;
}

bool extract_road_type_writes_from_ledger_text(
		const std::string &ledger_text,
		const std::vector<aurelion::h3maped_rmg_core::RecoveredRoadCall4ab37f> &calls,
		std::vector<aurelion::h3maped_rmg_core::RecoveredRoadTypeWrite49aec5> &writes_out) {
	std::vector<aurelion::h3maped_rmg_core::RecoveredRoadTypeWrite49aec5> writes;
	size_t cursor = 0;
	while (cursor < ledger_text.size()) {
		const size_t event_pos = ledger_text.find("\"address\": \"0x0049aec5\"", cursor);
		if (event_pos == std::string::npos) {
			break;
		}
		const size_t event_end = ledger_event_end_after(event_pos, ledger_text);
		size_t memory_line_pos = event_pos;
		bool coord_found = false;
		bool road_type_found = false;
		aurelion::h3maped_rmg_core::RecoveredRoadTypeWrite49aec5 write;
		write.callsite = 0x0049aec5U;
		write.sequence_index = int32_t(writes.size());
		while (memory_line_pos < event_end) {
			const size_t words_pos = ledger_text.find("\"words\"", memory_line_pos);
			if (words_pos == std::string::npos || words_pos >= event_end) {
				break;
			}
			std::vector<int32_t> words;
			if (extract_i32_words_array_after(ledger_text, words_pos, event_end, words)) {
				if (words.size() >= 3
						&& uint32_t(words[0]) == 0x004b3c00U
						&& words[2] >= 1
						&& words[2] <= 3) {
					write.road_type = words[2];
					road_type_found = true;
				}
				if (words.size() >= 3
						&& words[0] >= 0
						&& words[0] < 256
						&& words[1] >= 0
						&& words[1] < 256
						&& words[2] == 12) {
					write.x = words[0];
					write.y = words[1];
					write.level = 0;
					coord_found = true;
				}
			}
			memory_line_pos = words_pos + 1;
		}
		if (!coord_found || !road_type_found) {
			return false;
		}
		writes.push_back(write);
		cursor = event_end + 1;
	}
	(void)assign_road_type_write_call_chunks_0x49aec5(writes, calls);
	writes_out = std::move(writes);
	return !writes_out.empty();
}

bool extract_road_art_writes_from_ledger_text(
		const std::string &ledger_text,
		std::vector<aurelion::h3maped_rmg_core::RecoveredRoadArtWrite49ae47> &writes_out) {
	std::vector<aurelion::h3maped_rmg_core::RecoveredRoadArtWrite49ae47> writes;
	size_t cursor = 0;
	while (cursor < ledger_text.size()) {
		const size_t event_pos = ledger_text.find("\"address\": \"0x0049ae47\"", cursor);
		if (event_pos == std::string::npos) {
			break;
		}
		const size_t event_end = ledger_event_end_after(event_pos, ledger_text);
		size_t memory_line_pos = event_pos;
		bool write_found = false;
		while (memory_line_pos < event_end && !write_found) {
			const size_t words_pos = ledger_text.find("\"words\"", memory_line_pos);
			if (words_pos == std::string::npos || words_pos >= event_end) {
				break;
			}
			std::vector<int32_t> stack_words;
			if (extract_i32_words_array_after(ledger_text, words_pos, event_end, stack_words)
					&& stack_words.size() >= 3
					&& stack_words[1] > 0
					&& stack_words[2] > 0) {
				std::vector<int32_t> coord_words;
				std::vector<int32_t> overlay_words;
				if (extract_memory_words_at_address_between(ledger_text, event_pos, event_end, stack_words[1], coord_words)
						&& extract_memory_words_at_address_between(ledger_text, event_pos, event_end, stack_words[2], overlay_words)
						&& coord_words.size() >= 2
						&& overlay_words.size() >= 3
						&& coord_words[0] >= 0
						&& coord_words[0] < 256
						&& coord_words[1] >= 0
						&& coord_words[1] < 256
						&& overlay_words[0] >= 1
						&& overlay_words[0] <= 3
						&& overlay_words[1] >= 0
						&& overlay_words[1] <= 255) {
					const uint32_t flag_word = uint32_t(overlay_words[2]);
					aurelion::h3maped_rmg_core::RecoveredRoadArtWrite49ae47 write;
					write.callsite = 0x0049ae47U;
					write.sequence_index = int32_t(writes.size());
					write.x = coord_words[0];
					write.y = coord_words[1];
					write.level = 0;
					write.coord_word_0x08 = coord_words.size() >= 3 ? coord_words[2] : 0;
					write.road_type = overlay_words[0];
					write.road_art = overlay_words[1];
					write.flip_a = int32_t(flag_word & 0xffU);
					write.flip_b = int32_t((flag_word >> 8U) & 0xffU);
					writes.push_back(write);
					write_found = true;
				}
			}
			memory_line_pos = words_pos + 1;
		}
		if (!write_found) {
			return false;
		}
		cursor = event_end + 1;
	}
	writes_out = std::move(writes);
	return !writes_out.empty();
}

bool parse_u32_strict(const std::string &raw, uint32_t &out_value);

static const char *same_run_medium_seed10_payload_profile() {
	return "H3MapEd Medium one-level no-water seed 10, human/computer down 1, computer-only down 1, monster strength weak";
}

static const char *same_run_medium_seed10_normal_water_payload_profile() {
	return "H3MapEd Medium one-level normal-water seed 10, human/computer down 1, computer-only down 1, monster strength weak";
}

static const char *same_run_medium_seed13_two_level_payload_profile() {
	return "H3MapEd Medium two-level no-water seed 13, human/computer down 1, computer-only down 1, monster strength weak";
}

static const char *same_run_large_seed11_payload_profile() {
	return "H3MapEd Large one-level no-water seed 11, human/computer down 1, computer-only down 1, monster strength weak";
}

static const char *same_run_large_seed18_hc4_co4_payload_profile() {
	return "H3MapEd Large one-level no-water seed 18, human/computer down 4, computer-only down 4, monster strength weak";
}

static const char *same_run_xlarge_seed12_payload_profile() {
	return "H3MapEd XLarge one-level no-water seed 12, human/computer down 1, computer-only down 1, monster strength weak";
}

static bool known_same_run_monster_strength(const std::string &strength) {
	return strength == "random"
			|| strength == "weak"
			|| strength == "normal"
			|| strength == "strong";
}

static bool parse_same_run_small_payload_profile(
		const std::string &profile,
		uint32_t &seed_out) {
	static const std::string PREFIX = "H3MapEd Small one-level no-water seed ";
	static const std::string SUFFIX_PREFIX =
			", human/computer down 2, computer-only down 1, monster strength ";
	if (profile.rfind(PREFIX, 0) != 0) {
		return false;
	}
	const size_t suffix_pos = profile.find(SUFFIX_PREFIX, PREFIX.size());
	if (suffix_pos == std::string::npos) {
		return false;
	}
	uint32_t seed = 0;
	if (!parse_u32_strict(profile.substr(PREFIX.size(), suffix_pos - PREFIX.size()), seed)) {
		return false;
	}
	const std::string strength = profile.substr(suffix_pos + SUFFIX_PREFIX.size());
	if (!known_same_run_monster_strength(strength)) {
		return false;
	}
	seed_out = seed;
	return true;
}

static bool parse_same_run_small_islands_payload_profile(
		const std::string &profile,
		uint32_t &seed_out) {
	static const std::string PREFIX = "H3MapEd Small one-level islands seed ";
	static const std::string SUFFIX_PREFIX =
			", human/computer down 1, computer-only down 1, monster strength ";
	if (profile.rfind(PREFIX, 0) != 0) {
		return false;
	}
	const size_t suffix_pos = profile.find(SUFFIX_PREFIX, PREFIX.size());
	if (suffix_pos == std::string::npos) {
		return false;
	}
	uint32_t seed = 0;
	if (!parse_u32_strict(profile.substr(PREFIX.size(), suffix_pos - PREFIX.size()), seed)) {
		return false;
	}
	const std::string strength = profile.substr(suffix_pos + SUFFIX_PREFIX.size());
	if (!known_same_run_monster_strength(strength)) {
		return false;
	}
	seed_out = seed;
	return true;
}

static bool parse_same_run_small_normal_water_payload_profile(
		const std::string &profile,
		uint32_t &seed_out) {
	static const std::string PREFIX = "H3MapEd Small one-level normal-water seed ";
	static const std::string SUFFIX_PREFIX =
			", human/computer down 1, computer-only down 1, monster strength ";
	if (profile.rfind(PREFIX, 0) != 0) {
		return false;
	}
	const size_t suffix_pos = profile.find(SUFFIX_PREFIX, PREFIX.size());
	if (suffix_pos == std::string::npos) {
		return false;
	}
	uint32_t seed = 0;
	if (!parse_u32_strict(profile.substr(PREFIX.size(), suffix_pos - PREFIX.size()), seed)) {
		return false;
	}
	const std::string strength = profile.substr(suffix_pos + SUFFIX_PREFIX.size());
	if (!known_same_run_monster_strength(strength)) {
		return false;
	}
	seed_out = seed;
	return true;
}

static bool parse_same_run_medium_islands_payload_profile(
		const std::string &profile,
		uint32_t &seed_out) {
	static const std::string PREFIX = "H3MapEd Medium one-level islands seed ";
	static const std::string SUFFIX_PREFIX =
			", human/computer down 1, computer-only down 1, monster strength ";
	if (profile.rfind(PREFIX, 0) != 0) {
		return false;
	}
	const size_t suffix_pos = profile.find(SUFFIX_PREFIX, PREFIX.size());
	if (suffix_pos == std::string::npos) {
		return false;
	}
	uint32_t seed = 0;
	if (!parse_u32_strict(profile.substr(PREFIX.size(), suffix_pos - PREFIX.size()), seed)) {
		return false;
	}
	const std::string strength = profile.substr(suffix_pos + SUFFIX_PREFIX.size());
	if (!known_same_run_monster_strength(strength)) {
		return false;
	}
	seed_out = seed;
	return true;
}

static bool parse_same_run_small_two_level_land_payload_profile(
		const std::string &profile,
		uint32_t &seed_out) {
	static const std::string PREFIX = "H3MapEd Small two-level no-water seed ";
	static const std::string SUFFIX_PREFIX =
			", human/computer down 1, computer-only down 1, monster strength ";
	if (profile.rfind(PREFIX, 0) != 0) {
		return false;
	}
	const size_t suffix_pos = profile.find(SUFFIX_PREFIX, PREFIX.size());
	if (suffix_pos == std::string::npos) {
		return false;
	}
	uint32_t seed = 0;
	if (!parse_u32_strict(profile.substr(PREFIX.size(), suffix_pos - PREFIX.size()), seed)) {
		return false;
	}
	const std::string strength = profile.substr(suffix_pos + SUFFIX_PREFIX.size());
	if (!known_same_run_monster_strength(strength)) {
		return false;
	}
	seed_out = seed;
	return true;
}

static bool parse_same_run_two_level_payload_profile(
		const std::string &profile,
		std::string &size_class_out,
		std::string &water_mode_out,
		uint32_t &seed_out) {
	static const std::array<std::pair<const char *, const char *>, 4> SIZES = { {
		{ "Small", "small" },
		{ "Medium", "medium" },
		{ "Large", "large" },
		{ "XLarge", "xlarge" },
	} };
	static const std::array<std::pair<const char *, const char *>, 3> WATER_MODES = { {
		{ "no-water", "land" },
		{ "normal-water", "normal_water" },
		{ "islands", "islands" },
	} };
	static const std::string SUFFIX_PREFIX =
			", human/computer down 1, computer-only down 1, monster strength ";
	for (const auto &size : SIZES) {
		for (const auto &water : WATER_MODES) {
			const std::string prefix =
					std::string("H3MapEd ") + size.first + " two-level " + water.first + " seed ";
			if (profile.rfind(prefix, 0) != 0) {
				continue;
			}
			const size_t suffix_pos = profile.find(SUFFIX_PREFIX, prefix.size());
			if (suffix_pos == std::string::npos) {
				return false;
			}
			uint32_t seed = 0;
			if (!parse_u32_strict(profile.substr(prefix.size(), suffix_pos - prefix.size()), seed)
					|| !known_same_run_monster_strength(profile.substr(suffix_pos + SUFFIX_PREFIX.size()))) {
				return false;
			}
			size_class_out = size.second;
			water_mode_out = water.second;
			seed_out = seed;
			return true;
		}
	}
	return false;
}

static bool parse_same_run_large_islands_payload_profile(
		const std::string &profile,
		uint32_t &seed_out) {
	static const std::string PREFIX = "H3MapEd Large one-level islands seed ";
	static const std::string SUFFIX_PREFIX =
			", human/computer down 1, computer-only down 1, monster strength ";
	if (profile.rfind(PREFIX, 0) != 0) {
		return false;
	}
	const size_t suffix_pos = profile.find(SUFFIX_PREFIX, PREFIX.size());
	if (suffix_pos == std::string::npos) {
		return false;
	}
	uint32_t seed = 0;
	if (!parse_u32_strict(profile.substr(PREFIX.size(), suffix_pos - PREFIX.size()), seed)) {
		return false;
	}
	const std::string strength = profile.substr(suffix_pos + SUFFIX_PREFIX.size());
	if (!known_same_run_monster_strength(strength)) {
		return false;
	}
	seed_out = seed;
	return true;
}

static bool parse_same_run_xlarge_islands_payload_profile(
		const std::string &profile,
		uint32_t &seed_out) {
	static const std::string PREFIX = "H3MapEd XLarge one-level islands seed ";
	static const std::string SUFFIX_PREFIX =
			", human/computer down 1, computer-only down 1, monster strength ";
	if (profile.rfind(PREFIX, 0) != 0) {
		return false;
	}
	const size_t suffix_pos = profile.find(SUFFIX_PREFIX, PREFIX.size());
	if (suffix_pos == std::string::npos) {
		return false;
	}
	uint32_t seed = 0;
	if (!parse_u32_strict(profile.substr(PREFIX.size(), suffix_pos - PREFIX.size()), seed)) {
		return false;
	}
	const std::string strength = profile.substr(suffix_pos + SUFFIX_PREFIX.size());
	if (!known_same_run_monster_strength(strength)) {
		return false;
	}
	seed_out = seed;
	return true;
}

static bool parse_same_run_large_normal_water_payload_profile(
		const std::string &profile,
		uint32_t &seed_out) {
	static const std::string PREFIX = "H3MapEd Large one-level normal-water seed ";
	static const std::string SUFFIX_PREFIX =
			", human/computer down 1, computer-only down 1, monster strength ";
	if (profile.rfind(PREFIX, 0) != 0) {
		return false;
	}
	const size_t suffix_pos = profile.find(SUFFIX_PREFIX, PREFIX.size());
	if (suffix_pos == std::string::npos) {
		return false;
	}
	uint32_t seed = 0;
	if (!parse_u32_strict(profile.substr(PREFIX.size(), suffix_pos - PREFIX.size()), seed)) {
		return false;
	}
	const std::string strength = profile.substr(suffix_pos + SUFFIX_PREFIX.size());
	if (!known_same_run_monster_strength(strength)) {
		return false;
	}
	seed_out = seed;
	return true;
}

static bool parse_same_run_xlarge_normal_water_payload_profile(
		const std::string &profile,
		uint32_t &seed_out) {
	static const std::string PREFIX = "H3MapEd XLarge one-level normal-water seed ";
	static const std::string SUFFIX_PREFIX =
			", human/computer down 1, computer-only down 1, monster strength ";
	if (profile.rfind(PREFIX, 0) != 0) {
		return false;
	}
	const size_t suffix_pos = profile.find(SUFFIX_PREFIX, PREFIX.size());
	if (suffix_pos == std::string::npos) {
		return false;
	}
	uint32_t seed = 0;
	if (!parse_u32_strict(profile.substr(PREFIX.size(), suffix_pos - PREFIX.size()), seed)) {
		return false;
	}
	const std::string strength = profile.substr(suffix_pos + SUFFIX_PREFIX.size());
	if (!known_same_run_monster_strength(strength)) {
		return false;
	}
	seed_out = seed;
	return true;
}

static bool canonical_same_run_payload_profile(
		const std::string &profile,
		std::string &canonical_out) {
	static const char *LEGACY_MEDIUM_PROFILE =
			"H3MapEd Medium one-level no-water seed 10, human/computer down 1, computer-only down 1";
	if (profile == same_run_medium_seed10_payload_profile() || profile == LEGACY_MEDIUM_PROFILE) {
		canonical_out = same_run_medium_seed10_payload_profile();
		return true;
	}
	if (profile == same_run_medium_seed10_normal_water_payload_profile()) {
		canonical_out = same_run_medium_seed10_normal_water_payload_profile();
		return true;
	}
	if (profile == same_run_medium_seed13_two_level_payload_profile()) {
		canonical_out = same_run_medium_seed13_two_level_payload_profile();
		return true;
	}
	if (profile == same_run_large_seed11_payload_profile()) {
		canonical_out = same_run_large_seed11_payload_profile();
		return true;
	}
	if (profile == same_run_large_seed18_hc4_co4_payload_profile()) {
		canonical_out = same_run_large_seed18_hc4_co4_payload_profile();
		return true;
	}
	if (profile == same_run_xlarge_seed12_payload_profile()) {
		canonical_out = same_run_xlarge_seed12_payload_profile();
		return true;
	}
	uint32_t ignored_seed = 0;
	std::string ignored_size_class;
	std::string ignored_water_mode;
	if (parse_same_run_two_level_payload_profile(
			profile,
			ignored_size_class,
			ignored_water_mode,
			ignored_seed)) {
		canonical_out = profile;
		return true;
	}
	if (parse_same_run_small_payload_profile(profile, ignored_seed)) {
		canonical_out = profile;
		return true;
	}
	if (parse_same_run_small_islands_payload_profile(profile, ignored_seed)) {
		canonical_out = profile;
		return true;
	}
	if (parse_same_run_small_normal_water_payload_profile(profile, ignored_seed)) {
		canonical_out = profile;
		return true;
	}
	if (parse_same_run_medium_islands_payload_profile(profile, ignored_seed)) {
		canonical_out = profile;
		return true;
	}
	if (parse_same_run_small_two_level_land_payload_profile(profile, ignored_seed)) {
		canonical_out = profile;
		return true;
	}
	if (parse_same_run_large_islands_payload_profile(profile, ignored_seed)) {
		canonical_out = profile;
		return true;
	}
	if (parse_same_run_xlarge_islands_payload_profile(profile, ignored_seed)) {
		canonical_out = profile;
		return true;
	}
	if (parse_same_run_large_normal_water_payload_profile(profile, ignored_seed)) {
		canonical_out = profile;
		return true;
	}
	if (parse_same_run_xlarge_normal_water_payload_profile(profile, ignored_seed)) {
		canonical_out = profile;
		return true;
	}
	return false;
}

bool controlled_case_matches_same_run_payload_profile(
		const ControlledCase &controlled_case,
		const std::string &profile) {
	if (!controlled_case.parse_ok) {
		return false;
	}
	if (profile == same_run_medium_seed10_payload_profile()) {
		return controlled_case.players == 2
				&& controlled_case.level_count == 1
				&& controlled_case.water_mode == "land"
				&& controlled_case.size_class == "medium"
				&& controlled_case.seed == 10U
				&& controlled_case.human_count == 1
				&& controlled_case.computer_count == 1;
	}
	if (profile == same_run_medium_seed10_normal_water_payload_profile()) {
		return controlled_case.players == 2
				&& controlled_case.level_count == 1
				&& controlled_case.water_mode == "normal_water"
				&& controlled_case.size_class == "medium"
				&& controlled_case.seed == 10U
				&& controlled_case.human_count == 1
				&& controlled_case.computer_count == 1;
	}
	if (profile == same_run_medium_seed13_two_level_payload_profile()) {
		return controlled_case.players == 2
				&& controlled_case.level_count == 2
				&& controlled_case.water_mode == "land"
				&& controlled_case.size_class == "medium"
				&& controlled_case.seed == 13U
				&& controlled_case.human_count == 1
				&& controlled_case.computer_count == 1;
	}
	if (profile == same_run_large_seed11_payload_profile()) {
		return controlled_case.players == 2
				&& controlled_case.level_count == 1
				&& controlled_case.water_mode == "land"
				&& controlled_case.size_class == "large"
				&& controlled_case.seed == 11U
				&& controlled_case.human_count == 1
				&& controlled_case.computer_count == 1;
	}
	if (profile == same_run_large_seed18_hc4_co4_payload_profile()) {
		return controlled_case.players == 8
				&& controlled_case.level_count == 1
				&& controlled_case.water_mode == "land"
				&& controlled_case.size_class == "large"
				&& controlled_case.seed == 18U
				&& controlled_case.human_count == 4
				&& controlled_case.computer_count == 4;
	}
	if (profile == same_run_xlarge_seed12_payload_profile()) {
		return controlled_case.players == 2
				&& controlled_case.level_count == 1
				&& controlled_case.water_mode == "land"
				&& controlled_case.size_class == "xlarge"
				&& controlled_case.seed == 12U
				&& controlled_case.human_count == 1
				&& controlled_case.computer_count == 1;
	}
	uint32_t profile_seed = 0;
	std::string profile_size_class;
	std::string profile_water_mode;
	if (parse_same_run_two_level_payload_profile(
			profile,
			profile_size_class,
			profile_water_mode,
			profile_seed)) {
		return controlled_case.players == 2
				&& controlled_case.level_count == 2
				&& controlled_case.water_mode == profile_water_mode
				&& controlled_case.size_class == profile_size_class
				&& controlled_case.seed == profile_seed
				&& controlled_case.human_count == 1
				&& controlled_case.computer_count == 1;
	}
	if (parse_same_run_small_islands_payload_profile(profile, profile_seed)) {
		return controlled_case.players == 2
				&& controlled_case.level_count == 1
				&& controlled_case.water_mode == "islands"
				&& controlled_case.size_class == "small"
				&& controlled_case.seed == profile_seed
				&& controlled_case.human_count == 1
				&& controlled_case.computer_count == 1;
	}
	if (parse_same_run_small_normal_water_payload_profile(profile, profile_seed)) {
		return controlled_case.players == 2
				&& controlled_case.level_count == 1
				&& controlled_case.water_mode == "normal_water"
				&& controlled_case.size_class == "small"
				&& controlled_case.seed == profile_seed
				&& controlled_case.human_count == 1
				&& controlled_case.computer_count == 1;
	}
	if (parse_same_run_medium_islands_payload_profile(profile, profile_seed)) {
		return controlled_case.players == 2
				&& controlled_case.level_count == 1
				&& controlled_case.water_mode == "islands"
				&& controlled_case.size_class == "medium"
				&& controlled_case.seed == profile_seed
				&& controlled_case.human_count == 1
				&& controlled_case.computer_count == 1;
	}
	if (parse_same_run_small_two_level_land_payload_profile(profile, profile_seed)) {
		return controlled_case.players == 2
				&& controlled_case.level_count == 2
				&& controlled_case.water_mode == "land"
				&& controlled_case.size_class == "small"
				&& controlled_case.seed == profile_seed
				&& controlled_case.human_count == 1
				&& controlled_case.computer_count == 1;
	}
	if (parse_same_run_large_islands_payload_profile(profile, profile_seed)) {
		return controlled_case.players == 2
				&& controlled_case.level_count == 1
				&& controlled_case.water_mode == "islands"
				&& controlled_case.size_class == "large"
				&& controlled_case.seed == profile_seed
				&& controlled_case.human_count == 1
				&& controlled_case.computer_count == 1;
	}
	if (parse_same_run_xlarge_islands_payload_profile(profile, profile_seed)) {
		return controlled_case.players == 2
				&& controlled_case.level_count == 1
				&& controlled_case.water_mode == "islands"
				&& controlled_case.size_class == "xlarge"
				&& controlled_case.seed == profile_seed
				&& controlled_case.human_count == 1
				&& controlled_case.computer_count == 1;
	}
	if (parse_same_run_large_normal_water_payload_profile(profile, profile_seed)) {
		return controlled_case.players == 2
				&& controlled_case.level_count == 1
				&& controlled_case.water_mode == "normal_water"
				&& controlled_case.size_class == "large"
				&& controlled_case.seed == profile_seed
				&& controlled_case.human_count == 1
				&& controlled_case.computer_count == 1;
	}
	if (parse_same_run_xlarge_normal_water_payload_profile(profile, profile_seed)) {
		return controlled_case.players == 2
				&& controlled_case.level_count == 1
				&& controlled_case.water_mode == "normal_water"
				&& controlled_case.size_class == "xlarge"
				&& controlled_case.seed == profile_seed
				&& controlled_case.human_count == 1
				&& controlled_case.computer_count == 1;
	}
	if (parse_same_run_small_payload_profile(profile, profile_seed)) {
		return controlled_case.players == 2
				&& controlled_case.level_count == 1
				&& controlled_case.water_mode == "land"
				&& controlled_case.size_class == "small"
				&& controlled_case.seed == profile_seed
				&& controlled_case.human_count == 2
				&& controlled_case.computer_count == 0;
	}
	return false;
}

void apply_same_run_setup_authority_prefix_to_case(ControlledCase &controlled_case, const Options &options) {
	const std::vector<int32_t> &args =
			options.shared_runtime_chain_input.same_run_payload_authority_setup_stack_args_0x49ecf2;
	if (!options.same_run_setup_stack_prefix_known
			|| args.size() < 7) {
		return;
	}
	const bool full_authority_stack =
			args.size() >= size_t(aurelion::h3maped_rmg_core::RMG_SETUP_STACK_ARG_COUNT_0X49ECF2);
	const bool profile_matches =
			options.shared_runtime_chain_input.same_run_payload_authority_profile_known
			&& controlled_case_matches_same_run_payload_profile(
					controlled_case,
					options.shared_runtime_chain_input.same_run_payload_authority_profile);
	if (!full_authority_stack && !profile_matches) {
		return;
	}
	const int32_t width = aurelion::h3maped_rmg_core::map_width_for_size_class(controlled_case.size_class);
	if (args[0] != width || args[1] != width || args[2] != controlled_case.level_count) {
		return;
	}
	if (full_authority_stack || !controlled_case.setup_object_0x34_supplied) {
		controlled_case.setup_object_0x34_known = true;
		controlled_case.setup_object_0x34 = args[3];
	}
	if (full_authority_stack || !controlled_case.setup_object_0x38_supplied) {
		controlled_case.setup_object_0x38_known = true;
		controlled_case.setup_object_0x38 = args[4];
	}
	if (full_authority_stack || !controlled_case.setup_object_0x3c_supplied) {
		controlled_case.setup_object_0x3c_known = true;
		controlled_case.setup_object_0x3c = args[5];
	}
	if (full_authority_stack || !controlled_case.setup_object_0x40_supplied) {
		controlled_case.setup_object_0x40_known = true;
		controlled_case.setup_object_0x40 = args[6];
	}
	if (full_authority_stack || (options.same_run_setup_caller_arg9_known
			&& !controlled_case.setup_caller_arg_0x0c_supplied)) {
		controlled_case.setup_caller_arg_0x0c_known = true;
		controlled_case.setup_caller_arg_0x0c = full_authority_stack
				? args[9]
				: options.same_run_setup_caller_arg9;
	}
	if (full_authority_stack) {
		controlled_case.setup_object_0x44_known = true;
		controlled_case.setup_object_0x44 = args[7];
		controlled_case.setup_object_raw_0x48_known = false;
		controlled_case.setup_object_raw_0x48_supplied = false;
		controlled_case.setup_object_0x48_known = true;
		controlled_case.setup_object_0x48 = args[8];
		controlled_case.setup_object_0x4c_known = true;
		controlled_case.setup_object_0x4c = args[10];
		return;
	}
	if (options.same_run_setup_prepared_arg8_known && !controlled_case.setup_object_0x48_supplied) {
		controlled_case.setup_object_raw_0x48_known = false;
		controlled_case.setup_object_raw_0x48_supplied = false;
		controlled_case.setup_object_0x48_known = true;
		controlled_case.setup_object_0x48 = options.same_run_setup_prepared_arg8;
	}
	if (options.same_run_setup_object_0x4c_known && !controlled_case.setup_object_0x4c_supplied) {
		controlled_case.setup_object_0x4c_known = true;
		controlled_case.setup_object_0x4c = options.same_run_setup_object_0x4c;
	}
}

SharedRuntimeChainInput same_run_authority_input_for_case(const ControlledCase &controlled_case, const Options &options) {
	SharedRuntimeChainInput input = options.shared_runtime_chain_input;
	input.recovery_probe_scope_allowed = options.include_unsupported;
	std::vector<int32_t> &args = input.same_run_payload_authority_setup_stack_args_0x49ecf2;
	if (!options.same_run_setup_stack_prefix_known
			|| !options.shared_runtime_chain_input.same_run_payload_authority_profile_known
			|| !controlled_case_matches_same_run_payload_profile(
					controlled_case,
					options.shared_runtime_chain_input.same_run_payload_authority_profile)
			|| args.size() < 7
			|| args.size() >= size_t(aurelion::h3maped_rmg_core::RMG_SETUP_STACK_ARG_COUNT_0X49ECF2)
			|| !options.same_run_setup_prepared_arg8_known
			|| !options.same_run_setup_caller_arg9_known
			|| !controlled_case.setup_object_0x44_known
			|| !controlled_case.setup_object_0x4c_known) {
		return input;
	}
	const int32_t width = aurelion::h3maped_rmg_core::map_width_for_size_class(controlled_case.size_class);
	if (args[0] != width || args[1] != width || args[2] != controlled_case.level_count) {
		return input;
	}
	args.resize(size_t(aurelion::h3maped_rmg_core::RMG_SETUP_STACK_ARG_COUNT_0X49ECF2));
	args[7] = controlled_case.setup_object_0x44;
	args[8] = options.same_run_setup_prepared_arg8;
	args[9] = options.same_run_setup_caller_arg9;
	args[10] = controlled_case.setup_object_0x4c;
	input.same_run_payload_authority_setup_stack_join_known = true;
	input.same_run_payload_authority_setup_stack_args_known = true;
	return input;
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

uint32_t fnv1a32_bytes(const std::vector<uint8_t> &bytes) {
	uint32_t value = 2166136261U;
	for (const uint8_t byte : bytes) {
		value ^= uint32_t(byte);
		value *= 16777619U;
	}
	return value;
}

std::string hex32(uint32_t value) {
	static constexpr char digits[] = "0123456789abcdef";
	std::string result(8U, '0');
	for (int32_t index = 7; index >= 0; --index) {
		result[size_t(index)] = digits[value & 0x0fU];
		value >>= 4U;
	}
	return result;
}

void append_runtime_tile_point_json(
		std::ostream &out,
		const aurelion::h3maped_rmg_core::RuntimeMapTilePoint &point) {
	out << "{\"x\":" << point.x
		<< ",\"y\":" << point.y
		<< ",\"level\":" << point.level << "}";
}

void append_runtime_tile_points_json(
		std::ostream &out,
		const std::vector<aurelion::h3maped_rmg_core::RuntimeMapTilePoint> &points) {
	out << "[";
	for (size_t index = 0; index < points.size(); ++index) {
		if (index > 0U) {
			out << ",";
		}
		append_runtime_tile_point_json(out, points[index]);
	}
	out << "]";
}

const char *runtime_object_kind_for_h3m_type(int32_t type_id) {
	switch (type_id) {
		case 5:
			return "artifact";
		case 53:
			return "mine";
		case 54:
		case 71:
			return "guard";
		case 98:
			return "town";
		case 66:
		case 67:
		case 68:
		case 69:
		case 76:
		case 79:
		case 83:
		case 88:
		case 89:
		case 90:
		case 93:
		case 101:
			return "reward_reference";
		case 118:
		case 119:
		case 120:
		case 124:
		case 134:
		case 135:
		case 136:
		case 137:
		case 147:
		case 150:
		case 155:
		case 199:
		case 207:
		case 210:
			return "decorative_obstacle";
		default:
			return "h3m_object";
	}
}

const aurelion::h3maped_rmg_core::FinalHeaderPlayerSlot4ac857 *runtime_player_slot_for_town(
		const aurelion::h3maped_rmg_core::RuntimeMapObjectProjection &object,
		const aurelion::h3maped_rmg_core::RuntimeMapPayloadProjection &projection) {
	for (const auto &slot : projection.player_slots) {
		if (!slot.active || !slot.has_main_town) {
			continue;
		}
		for (const auto &point : object.action_tiles) {
			if (slot.town_x == point.x
					&& slot.town_y == point.y
					&& slot.town_level == point.level) {
				return &slot;
			}
		}
	}
	return nullptr;
}

std::string runtime_town_id_for_slot(
		const aurelion::h3maped_rmg_core::FinalHeaderPlayerSlot4ac857 *slot) {
	if (slot == nullptr || slot->human) {
		return "town_riverwatch";
	}
	return (slot->color % 2 == 0) ? "town_prismhearth" : "town_duskfen";
}

std::string runtime_faction_id_for_slot(
		const aurelion::h3maped_rmg_core::FinalHeaderPlayerSlot4ac857 *slot) {
	if (slot == nullptr || slot->human) {
		return "faction_embercourt";
	}
	return (slot->color % 2 == 0) ? "faction_sunvault" : "faction_mireclaw";
}

std::string runtime_placement_id(
		const std::string &case_id,
		const aurelion::h3maped_rmg_core::RuntimeMapObjectProjection &object) {
	std::ostringstream id;
	id << "native_h3maped_" << aurelion::rmg_native_core::safe_case_filename(case_id)
		<< "_object_" << std::setw(4) << std::setfill('0') << object.serialized_index;
	return id.str();
}

aurelion::h3maped_rmg_core::RuntimeMapTilePoint runtime_primary_tile(
		const aurelion::h3maped_rmg_core::RuntimeMapObjectProjection &object,
		const aurelion::h3maped_rmg_core::RuntimeMapPayloadProjection &projection) {
	const auto in_bounds = [&](const aurelion::h3maped_rmg_core::RuntimeMapTilePoint &point) {
		return point.x >= 0 && point.y >= 0 && point.level >= 0
				&& point.x < projection.width && point.y < projection.height
				&& point.level < projection.level_count;
	};
	const aurelion::h3maped_rmg_core::RuntimeMapTilePoint native_anchor = { object.x, object.y, object.level };
	if (in_bounds(native_anchor)) {
		return native_anchor;
	}
	const auto nearest_in_bounds = [&](
			const std::vector<aurelion::h3maped_rmg_core::RuntimeMapTilePoint> &points,
			aurelion::h3maped_rmg_core::RuntimeMapTilePoint &selected) {
		bool found = false;
		int64_t selected_distance = std::numeric_limits<int64_t>::max();
		for (const auto &point : points) {
			if (!in_bounds(point)) {
				continue;
			}
			const int64_t distance = std::llabs(int64_t(point.x) - object.x)
					+ std::llabs(int64_t(point.y) - object.y)
					+ std::llabs(int64_t(point.level) - object.level);
			if (!found || distance < selected_distance) {
				found = true;
				selected_distance = distance;
				selected = point;
			}
		}
		return found;
	};
	aurelion::h3maped_rmg_core::RuntimeMapTilePoint selected;
	if (nearest_in_bounds(object.action_tiles, selected) || nearest_in_bounds(object.body_tiles, selected)) {
		return selected;
	}
	return {
		std::clamp(object.x, 0, std::max(0, projection.width - 1)),
		std::clamp(object.y, 0, std::max(0, projection.height - 1)),
		std::clamp(object.level, 0, std::max(0, projection.level_count - 1)),
	};
}

void append_runtime_object_json(
		std::ostream &out,
		const std::string &case_id,
		const aurelion::h3maped_rmg_core::RuntimeMapObjectProjection &object,
		const aurelion::h3maped_rmg_core::RuntimeMapPayloadProjection &projection) {
	const char *kind = runtime_object_kind_for_h3m_type(object.type_id);
	const auto *slot = std::string(kind) == "town"
			? runtime_player_slot_for_town(object, projection)
			: nullptr;
	const auto primary_tile = runtime_primary_tile(object, projection);
	std::vector<aurelion::h3maped_rmg_core::RuntimeMapTilePoint> body_tiles = object.body_tiles;
	if (body_tiles.empty()) {
		body_tiles.push_back(primary_tile);
	}
	std::vector<aurelion::h3maped_rmg_core::RuntimeMapTilePoint> visit_tiles = object.action_tiles;
	if (visit_tiles.empty()
			&& (std::string(kind) == "town"
					|| std::string(kind) == "mine"
					|| std::string(kind) == "artifact"
					|| std::string(kind) == "reward_reference")) {
		visit_tiles.push_back(primary_tile);
	}
	out << "{";
	out << "\"placement_id\":\"" << json_escape(runtime_placement_id(case_id, object)) << "\",";
	out << "\"kind\":\"" << kind << "\",";
	out << "\"native_record_kind\":\"" << kind << "\",";
	out << "\"source_kind\":\"h3maped_final_payload\",";
	out << "\"h3m_type_id\":" << object.type_id << ",";
	out << "\"h3m_subtype\":" << object.subtype << ",";
	out << "\"h3m_group\":" << object.group << ",";
	out << "\"h3m_definition_index\":" << object.definition_index << ",";
	out << "\"h3m_def_name\":\"" << json_escape(object.def_name) << "\",";
	out << "\"h3m_serialization_pass\":" << object.serialization_pass << ",";
	out << "\"h3m_payload_offset\":" << object.payload_offset << ",";
	out << "\"h3m_payload_byte_count\":" << object.payload_byte_count << ",";
	out << "\"h3m_anchor_x\":" << object.x << ",\"h3m_anchor_y\":" << object.y << ",\"h3m_anchor_level\":" << object.level << ",";
	out << "\"x\":" << primary_tile.x << ",\"y\":" << primary_tile.y << ",\"level\":" << primary_tile.level << ",";
	out << "\"primary_tile\":{" << "\"x\":" << primary_tile.x << ",\"y\":" << primary_tile.y << ",\"level\":" << primary_tile.level << "},";
	out << "\"body_tiles\":";
	append_runtime_tile_points_json(out, body_tiles);
	out << ",\"package_body_tiles\":";
	append_runtime_tile_points_json(out, body_tiles);
	out << ",\"package_block_tiles\":";
	append_runtime_tile_points_json(out, object.body_tiles);
	out << ",\"package_visit_tiles\":";
	append_runtime_tile_points_json(out, visit_tiles);
	if (!visit_tiles.empty()) {
		out << ",\"visit_tile\":";
		append_runtime_tile_point_json(out, visit_tiles.front());
	}
	out << ",\"blocking_body\":" << (!object.body_tiles.empty() ? "true" : "false");
	if (std::string(kind) == "town") {
		const int32_t owner_slot = slot == nullptr ? 0 : slot->color + 1;
		out << ",\"owner\":\"" << (slot == nullptr ? "neutral" : (slot->human ? "player" : "enemy")) << "\"";
		out << ",\"owner_slot\":" << owner_slot;
		out << ",\"player_slot\":" << owner_slot;
		out << ",\"player_type\":\"" << (slot == nullptr ? "neutral" : (slot->human ? "human" : "computer")) << "\"";
		out << ",\"is_start_town\":" << (slot != nullptr ? "true" : "false");
		out << ",\"start_anchor\":" << (slot != nullptr ? "true" : "false");
		out << ",\"town_id\":\"" << runtime_town_id_for_slot(slot) << "\"";
		out << ",\"faction_id\":\"" << runtime_faction_id_for_slot(slot) << "\"";
	} else if (std::string(kind) == "guard") {
		out << ",\"encounter_id\":\"encounter_mire_raid\",\"object_id\":\"encounter_mire_raid\"";
	} else if (std::string(kind) == "mine") {
		out << ",\"site_id\":\"" << (object.subtype == 2 ? "site_ridge_quarry" : "site_brightwood_sawmill") << "\"";
		out << ",\"owner\":\"neutral\"";
	} else if (std::string(kind) == "reward_reference") {
		out << ",\"site_id\":\"site_generated_town_required_source_cache\"";
	}
	out << "}";
}

void append_runtime_terrain_levels_json(
		std::ostream &out,
		const aurelion::h3maped_rmg_core::RuntimeMapPayloadProjection &projection) {
	out << "[";
	const int32_t level_size = projection.width * projection.height;
	for (int32_t level = 0; level < projection.level_count; ++level) {
		if (level > 0) {
			out << ",";
		}
		out << "[";
		for (int32_t index = 0; index < level_size; ++index) {
			if (index > 0) {
				out << ",";
			}
			out << int32_t(projection.terrain_type_codes[size_t(level * level_size + index)]);
		}
		out << "]";
	}
	out << "]";
}

bool write_runtime_map_package(
		const std::filesystem::path &path,
		const std::filesystem::path &scenario_path,
		const ControlledCase &controlled_case,
		const aurelion::h3maped_rmg_core::RuntimeMapPayloadProjection &projection,
		const aurelion::h3maped_rmg_core::FinalPayloadWriteoutResult4ad1e3 &payload) {
	std::ofstream out(path, std::ios::binary);
	if (!out) {
		return false;
	}
	const std::string token = hex32(fnv1a32_bytes(payload.payload_bytes));
	const std::string map_id = "native_h3maped_" + token;
	const std::string map_hash = "fnv1a32:" + token;
	const std::string package_hash = "fnv1a32:" + hex32(fnv1a32_bytes(payload.payload_bytes) ^ 0xa5a5a5a5U);
	out << "{\n";
	out << "\"schema_id\":\"aurelion_map_package\",\"schema_version\":1,";
	out << "\"package_kind\":\"generated_map_package\",\"package_id\":\"" << json_escape(path.filename().string()) << "\",";
	out << "\"document_kind\":\"map\",\"map_id\":\"" << map_id << "\",\"map_hash\":\"" << map_hash << "\",";
	out << "\"source_kind\":\"generated_h3maped_native_parity\",\"storage_policy\":\"project_maps_generated_package\",";
	out << "\"path_policy\":\"standalone_native_cli_no_godot\",\"authored_content_writeback\":false,\"legacy_json_scenario_record\":false,";
	out << "\"map_ref\":{\"schema_id\":\"aurelion_map_document\",\"schema_version\":1,\"map_id\":\"" << map_id
		<< "\",\"map_hash\":\"" << map_hash << "\",\"source_kind\":\"generated_h3maped_native_parity\",\"package_path\":\""
		<< json_escape(path.string()) << "\",\"package_id\":\"" << json_escape(path.filename().string())
		<< "\",\"storage_policy\":\"project_maps_generated_package\",\"package_hash\":\"" << package_hash << "\"},";
	out << "\"document\":{";
	out << "\"schema_id\":\"aurelion_map_document\",\"schema_version\":1,\"map_id\":\"" << map_id
		<< "\",\"map_hash\":\"" << map_hash << "\",\"source_kind\":\"generated_h3maped_native_parity\",";
	out << "\"width\":" << projection.width << ",\"height\":" << projection.height << ",\"level_count\":" << projection.level_count << ",";
	out << "\"metadata\":{\"schema_id\":\"aurelion_map_document\",\"schema_version\":1,";
	out << "\"generated\":true,\"source_kind\":\"generated_h3maped_native_parity\",\"source_template_authority\":\"h3maped_exe_rng\",";
	out << "\"source_template_id\":\"h3maped_template_" << json_escape(controlled_case.size_class) << "_seed_" << controlled_case.seed << "\",";
	out << "\"native_h3m_final_payload_parity\":true,\"runtime_payload_projection_complete\":true,";
	out << "\"runtime_package_adoption_scope\":\"controlled_same_run_authority_case_only\",\"production_ready\":false,\"full_parity_claim\":false,";
	out << "\"final_payload_byte_count\":" << payload.total_payload_byte_count << ",\"final_payload_fnv1a32\":\"" << token << "\",";
	out << "\"component_counts\":{\"width\":" << projection.width << ",\"height\":" << projection.height
		<< ",\"level_count\":" << projection.level_count << ",\"tile_count\":" << projection.tile_count
		<< ",\"object_count\":" << projection.object_count << ",\"road_cell_count\":" << projection.road_tiles.size() << "}},";
	out << "\"terrain_layers\":{\"schema_id\":\"aurelion_terrain_layers\",\"schema_version\":1,";
	out << "\"terrain_id_by_code\":[\"dirt\",\"sand\",\"grass\",\"snow\",\"swamp\",\"rough\",\"underground\",\"lava\",\"water\",\"rock\"],";
	out << "\"terrain\":{\"levels\":";
	append_runtime_terrain_levels_json(out, projection);
	out << "},\"road_count\":1,\"road_unique_tile_count\":" << projection.road_tiles.size() << ",\"roads\":[{\"id\":\"h3maped_native_roads\",\"tiles\":";
	append_runtime_tile_points_json(out, projection.road_tiles);
	out << "}]},";
	out << "\"route_graph\":{\"schema_id\":\"aurelion_route_graph\",\"nodes\":[],\"edges\":[]},";
	out << "\"objects\":[";
	for (size_t index = 0; index < projection.objects.size(); ++index) {
		if (index > 0U) {
			out << ",";
		}
		append_runtime_object_json(out, controlled_case.id, projection.objects[index], projection);
	}
	out << "]},";
	out << "\"scenario_package_path\":\"" << json_escape(scenario_path.string()) << "\",\"package_hash\":\"" << package_hash << "\"\n}";
	return bool(out);
}

std::string runtime_town_placement_id_for_slot(
		const std::string &case_id,
		const aurelion::h3maped_rmg_core::FinalHeaderPlayerSlot4ac857 &slot,
		const aurelion::h3maped_rmg_core::RuntimeMapPayloadProjection &projection) {
	for (const auto &object : projection.objects) {
		if (object.type_id != 98) {
			continue;
		}
		for (const auto &point : object.action_tiles) {
			if (point.x == slot.town_x
					&& point.y == slot.town_y
					&& point.level == slot.town_level) {
				return runtime_placement_id(case_id, object);
			}
		}
	}
	return "";
}

bool write_runtime_scenario_package(
		const std::filesystem::path &path,
		const std::filesystem::path &map_path,
		const ControlledCase &controlled_case,
		const aurelion::h3maped_rmg_core::RuntimeMapPayloadProjection &projection,
		const aurelion::h3maped_rmg_core::FinalPayloadWriteoutResult4ad1e3 &payload) {
	std::ofstream out(path, std::ios::binary);
	if (!out) {
		return false;
	}
	const std::string token = hex32(fnv1a32_bytes(payload.payload_bytes));
	const std::string map_id = "native_h3maped_" + token;
	const std::string map_hash = "fnv1a32:" + token;
	const std::string scenario_id = map_id + "_skirmish";
	const std::string scenario_hash = "fnv1a32:" + hex32(fnv1a32_bytes(payload.payload_bytes) ^ 0x5a5a5a5aU);
	const std::string package_hash = "fnv1a32:" + hex32(fnv1a32_bytes(payload.payload_bytes) ^ 0x3c3c3c3cU);
	out << "{\n\"schema_id\":\"aurelion_scenario_package\",\"schema_version\":1,";
	out << "\"package_kind\":\"generated_scenario_package\",\"package_id\":\"" << json_escape(path.filename().string()) << "\",";
	out << "\"document_kind\":\"scenario\",\"scenario_id\":\"" << scenario_id << "\",\"scenario_hash\":\"" << scenario_hash << "\",";
	out << "\"source_kind\":\"generated\",\"storage_policy\":\"project_maps_generated_package\",\"path_policy\":\"standalone_native_cli_no_godot\",";
	out << "\"authored_content_writeback\":false,\"legacy_json_scenario_record\":false,";
	out << "\"map_ref\":{\"schema_id\":\"aurelion_map_document\",\"schema_version\":1,\"map_id\":\"" << map_id
		<< "\",\"map_hash\":\"" << map_hash << "\",\"source_kind\":\"generated_h3maped_native_parity\",\"package_path\":\""
		<< json_escape(map_path.string()) << "\",\"package_id\":\"" << json_escape(map_path.filename().string()) << "\",\"storage_policy\":\"project_maps_generated_package\"},";
	out << "\"scenario_ref\":{\"schema_id\":\"aurelion_scenario_document\",\"schema_version\":1,\"scenario_id\":\"" << scenario_id
		<< "\",\"scenario_hash\":\"" << scenario_hash << "\",\"package_path\":\"" << json_escape(path.string())
		<< "\",\"package_id\":\"" << json_escape(path.filename().string()) << "\",\"storage_policy\":\"project_maps_generated_package\",\"package_hash\":\"" << package_hash << "\"},";
	out << "\"document\":{\"schema_id\":\"aurelion_scenario_document\",\"schema_version\":1,\"scenario_id\":\"" << scenario_id
		<< "\",\"scenario_hash\":\"" << scenario_hash << "\",";
	out << "\"map_ref\":{\"schema_id\":\"aurelion_map_document\",\"schema_version\":1,\"map_id\":\"" << map_id
		<< "\",\"map_hash\":\"" << map_hash << "\",\"source_kind\":\"generated_h3maped_native_parity\",\"package_path\":\""
		<< json_escape(map_path.string()) << "\"},";
	out << "\"selection\":{\"template_id\":\"h3maped_template_" << json_escape(controlled_case.size_class) << "_seed_" << controlled_case.seed
		<< "\",\"seed\":\"" << controlled_case.seed << "\",\"water_mode\":\"" << json_escape(controlled_case.water_mode) << "\"},";
	out << "\"player_slots\":[";
	bool first_slot = true;
	for (const auto &slot : projection.player_slots) {
		if (!slot.active) {
			continue;
		}
		if (!first_slot) {
			out << ",";
		}
		first_slot = false;
		out << "{\"slot\":" << slot.color + 1 << ",\"color\":" << slot.color
			<< ",\"human\":" << (slot.human ? "true" : "false")
			<< ",\"computer\":" << (slot.computer ? "true" : "false")
			<< ",\"owner\":\"" << (slot.human ? "player" : "enemy") << "\",\"faction_id\":\""
			<< runtime_faction_id_for_slot(&slot) << "\"}";
	}
	out << "],\"objectives\":{\"kind\":\"defeat_generated_rivals\",\"description\":\"Defeat every rival commander.\"},";
	out << "\"script_hooks\":[],\"enemy_factions\":[";
	bool first_enemy = true;
	for (const auto &slot : projection.player_slots) {
		if (!slot.active || !slot.computer) {
			continue;
		}
		if (!first_enemy) {
			out << ",";
		}
		first_enemy = false;
		out << "\"" << runtime_faction_id_for_slot(&slot) << "\"";
	}
	out << "],\"start_contract\":{\"schema_id\":\"aurelion_native_rmg_start_contract_v1\",\"primary_hero_id\":\"hero_lyra\",\"player_starts\":[";
	bool first_start = true;
	int32_t start_count = 0;
	for (const auto &slot : projection.player_slots) {
		if (!slot.active || !slot.has_main_town) {
			continue;
		}
		if (!first_start) {
			out << ",";
		}
		first_start = false;
		++start_count;
		const std::string placement_id = runtime_town_placement_id_for_slot(controlled_case.id, slot, projection);
		out << "{\"start_id\":\"player_start_" << slot.color + 1 << "\",\"owner\":\"" << (slot.human ? "player" : "enemy")
			<< "\",\"owner_slot\":" << slot.color + 1 << ",\"player_slot\":" << slot.color + 1
			<< ",\"player_type\":\"" << (slot.human ? "human" : "computer") << "\",\"faction_id\":\""
			<< runtime_faction_id_for_slot(&slot) << "\",\"town_id\":\"" << runtime_town_id_for_slot(&slot)
			<< "\",\"town_placement_id\":\"" << json_escape(placement_id) << "\",\"x\":" << slot.town_x
			<< ",\"y\":" << slot.town_y << ",\"level\":" << slot.town_level << "}";
	}
	out << "],\"player_start_towns\":[";
	first_start = true;
	for (const auto &slot : projection.player_slots) {
		if (!slot.active || !slot.has_main_town) {
			continue;
		}
		if (!first_start) {
			out << ",";
		}
		first_start = false;
		const std::string placement_id = runtime_town_placement_id_for_slot(controlled_case.id, slot, projection);
		out << "{\"placement_id\":\"" << json_escape(placement_id) << "\",\"owner\":\"" << (slot.human ? "player" : "enemy")
			<< "\",\"owner_slot\":" << slot.color + 1 << ",\"player_slot\":" << slot.color + 1
			<< ",\"town_id\":\"" << runtime_town_id_for_slot(&slot) << "\",\"faction_id\":\"" << runtime_faction_id_for_slot(&slot)
			<< "\",\"x\":" << slot.town_x << ",\"y\":" << slot.town_y << ",\"level\":" << slot.town_level
			<< ",\"hero_start_tile\":{\"x\":" << slot.town_x << ",\"y\":" << slot.town_y << ",\"level\":" << slot.town_level << "}}";
	}
	out << "],\"start_count\":" << start_count << ",\"start_town_count\":" << start_count << "}},";
	out << "\"package_hash\":\"" << package_hash << "\"\n}";
	return bool(out);
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
		out << "\"final_h3m_payload_export_authorized\":" << (report.final_h3m_payload_export_authorized ? "true" : "false") << ",";
		out << "\"final_h3m_payload_written\":" << (report.final_h3m_payload_written ? "true" : "false") << ",";
		out << "\"final_h3m_payload_path\":\"" << json_escape(report.final_h3m_payload_path.string()) << "\",";
		out << "\"runtime_payload_projection_applied\":" << (report.runtime_payload_projection_applied ? "true" : "false") << ",";
		out << "\"runtime_payload_projection_blocked_reason\":\"" << json_escape(report.runtime_payload_projection_blocked_reason) << "\",";
		out << "\"runtime_payload_projection_tile_count\":" << report.runtime_payload_projection_tile_count << ",";
		out << "\"runtime_payload_projection_object_count\":" << report.runtime_payload_projection_object_count << ",";
		out << "\"runtime_payload_projection_road_tile_count\":" << report.runtime_payload_projection_road_tile_count << ",";
		out << "\"runtime_payload_projection_object_payload_byte_count\":" << report.runtime_payload_projection_object_payload_byte_count << ",";
		out << "\"runtime_map_package_written\":" << (report.runtime_map_package_written ? "true" : "false") << ",";
		out << "\"runtime_map_package_path\":\"" << json_escape(report.runtime_map_package_path.string()) << "\",";
		out << "\"runtime_scenario_package_written\":" << (report.runtime_scenario_package_written ? "true" : "false") << ",";
		out << "\"runtime_scenario_package_path\":\"" << json_escape(report.runtime_scenario_package_path.string()) << "\",";
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
		} else if (arg == "--same-run-full-payload-authority") {
			std::string raw;
			take_value(raw);
			if (!raw.empty()) {
				options.same_run_full_payload_authority_path = raw;
			}
		} else if (arg == "--same-run-payload-summary") {
			std::string raw;
			take_value(raw);
			if (!raw.empty()) {
				options.same_run_payload_summary_path = raw;
			}
		} else if (arg == "--same-run-ordered-writeout-spine-summary") {
			std::string raw;
			take_value(raw);
			if (!raw.empty()) {
				options.same_run_ordered_writeout_spine_summary_path = raw;
			}
		} else if (arg == "--same-run-preobject-trace-ledger") {
			std::string raw;
			take_value(raw);
			if (!raw.empty()) {
				options.same_run_preobject_trace_ledger_path = raw;
			}
		} else if (arg == "--same-run-setup-stack-boundary-ledger") {
			std::string raw;
			take_value(raw);
			if (!raw.empty()) {
				options.same_run_setup_stack_boundary_ledger_path = raw;
			}
		} else if (arg == "--same-run-river-entry-args-ledger") {
			std::string raw;
			take_value(raw);
			if (!raw.empty()) {
				options.same_run_river_entry_args_ledger_path = raw;
			}
		} else if (arg == "--same-run-river-overlay-write-ledger") {
			std::string raw;
			take_value(raw);
			if (!raw.empty()) {
				options.same_run_river_overlay_write_ledger_path = raw;
			}
		} else if (arg == "--same-run-road-type-rng-ledger") {
			std::string raw;
			take_value(raw);
			if (!raw.empty()) {
				options.same_run_road_type_rng_ledger_path = raw;
			}
		} else if (arg == "--same-run-road-coordinate-vector-ledger") {
			std::string raw;
			take_value(raw);
			if (!raw.empty()) {
				options.same_run_road_coordinate_vector_ledger_path = raw;
			}
		} else if (arg == "--same-run-road-callstream-ledger") {
			std::string raw;
			take_value(raw);
			if (!raw.empty()) {
				options.same_run_road_callstream_ledger_path = raw;
			}
		} else if (arg == "--same-run-road-type-write-ledger") {
			std::string raw;
			take_value(raw);
			if (!raw.empty()) {
				options.same_run_road_type_write_ledger_path = raw;
			}
		} else if (arg == "--same-run-road-art-write-ledger") {
			std::string raw;
			take_value(raw);
			if (!raw.empty()) {
				options.same_run_road_art_write_ledger_path = raw;
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
				if (parse_i32_csv(raw, 14, fields) || parse_i32_csv(raw, 13, fields) || parse_i32_csv(raw, 12, fields) || parse_i32_csv(raw, 11, fields) || parse_i32_csv(raw, 8, fields) || parse_i32_csv(raw, 7, fields)) {
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
					input.allowed_terrain_flags_0x85_0x8c =
							aurelion::h3maped_rmg_core::AllowedTerrainFlags0x85_0x8c(uint16_t(fields[10]));
				}
				if (fields.size() >= 12) {
					input.source_owner_index = fields[11];
				}
					if (fields.size() >= 13) {
						input.fixed_player_town_choice_index_0xf24 = fields[12];
					}
					if (fields.size() >= 14) {
						input.source_order_selector_field_0x40_known = true;
						input.source_order_selector_field_0x40 = uint8_t(fields[13] & 0xff);
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
		} else if (arg == "--emit-final-h3m-payload") {
			options.emit_final_h3m_payload = true;
		} else if (arg == "--emit-runtime-package") {
			options.emit_runtime_package = true;
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

bool hydrate_same_run_setup_stack_boundary_ledger(Options &options, const std::filesystem::path &ledger_path);
bool hydrate_same_run_river_entry_args_ledger(Options &options, const std::filesystem::path &ledger_path);
bool hydrate_same_run_river_overlay_write_ledger(Options &options, const std::filesystem::path &ledger_path);
bool hydrate_same_run_road_type_rng_ledger(Options &options, const std::filesystem::path &ledger_path);
bool hydrate_same_run_road_coordinate_vector_ledger(Options &options, const std::filesystem::path &ledger_path);
bool hydrate_same_run_road_callstream_ledger(Options &options, const std::filesystem::path &ledger_path);
bool hydrate_same_run_road_type_write_ledger(Options &options, const std::filesystem::path &ledger_path);
bool hydrate_same_run_road_art_write_ledger(Options &options, const std::filesystem::path &ledger_path);

void hydrate_same_run_authority_payloads(Options &options) {
	if (!options.same_run_setup_stack_boundary_ledger_path.empty()) {
		hydrate_same_run_setup_stack_boundary_ledger(
				options,
				options.same_run_setup_stack_boundary_ledger_path);
	}
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
	std::vector<uint8_t> full_payload;
	if (read_binary_file(options.same_run_full_payload_authority_path, full_payload)) {
		options.shared_runtime_chain_input.same_run_full_payload_authority_known = true;
		options.shared_runtime_chain_input.same_run_full_payload_authority_0x4ac857_0x4ad3db =
				std::move(full_payload);
	}
	std::string payload_summary;
	std::string payload_profile;
	int32_t tile_payload_byte_count = 0;
	int32_t object_count = 0;
	int32_t object_payload_byte_count = 0;
	std::string canonical_profile;
	if (read_text_file(options.same_run_payload_summary_path, payload_summary)
			&& extract_json_string_field(payload_summary, "profile", payload_profile)
			&& canonical_same_run_payload_profile(payload_profile, canonical_profile)
			&& extract_json_i32_field(payload_summary, "tile_payload_byte_count", tile_payload_byte_count)
			&& extract_json_i32_field(payload_summary, "object_count", object_count)
			&& extract_json_i32_field(payload_summary, "object_payload_byte_count", object_payload_byte_count)
			&& tile_payload_byte_count > 0
			&& object_count > 0
			&& object_payload_byte_count > 0
			&& json_bool_field_true(payload_summary, "same_run_tile_object_payload_stitching_complete")) {
		options.shared_runtime_chain_input.same_run_payload_authority_profile_known = true;
		options.shared_runtime_chain_input.same_run_payload_authority_profile = canonical_profile;
		options.shared_runtime_chain_input.same_run_payload_authority_tile_byte_count = tile_payload_byte_count;
		options.shared_runtime_chain_input.same_run_payload_authority_object_count = object_count;
		options.shared_runtime_chain_input.same_run_payload_authority_object_byte_count = object_payload_byte_count;
		std::string ledger_path_text;
		if (extract_json_string_field(payload_summary, "ledger", ledger_path_text)) {
			std::string ledger_text;
			std::vector<int32_t> setup_stack_args;
			if (read_text_file(std::filesystem::path(ledger_path_text), ledger_text)
					&& extract_setup_stack_args_0x49ecf2_from_ledger_text(ledger_text, setup_stack_args)) {
				options.shared_runtime_chain_input.same_run_payload_authority_setup_stack_args_0x49ecf2 =
						std::move(setup_stack_args);
				options.shared_runtime_chain_input.same_run_payload_authority_setup_stack_args_known =
						options.shared_runtime_chain_input.same_run_payload_authority_setup_stack_args_0x49ecf2.size()
						== size_t(aurelion::h3maped_rmg_core::RMG_SETUP_STACK_ARG_COUNT_0X49ECF2);
				options.shared_runtime_chain_input.same_run_payload_authority_setup_stack_join_known =
						options.shared_runtime_chain_input.same_run_payload_authority_setup_stack_args_known;
				options.same_run_setup_stack_prefix_known =
						options.shared_runtime_chain_input.same_run_payload_authority_setup_stack_args_known;
			}
		}
		const bool medium_seed10_profile =
				options.shared_runtime_chain_input.same_run_payload_authority_profile
				== same_run_medium_seed10_payload_profile();
		if (!options.shared_runtime_chain_input.same_run_payload_authority_setup_stack_args_known) {
			hydrate_same_run_setup_stack_boundary_ledger(
					options,
					options.same_run_setup_stack_boundary_ledger_path);
		}
		std::string spine_summary;
		std::string boundary_ledger_path_text;
			if (!options.shared_runtime_chain_input.same_run_payload_authority_setup_stack_args_known
					&& read_text_file(options.same_run_ordered_writeout_spine_summary_path, spine_summary)
					&& spine_summary.find(same_run_medium_seed10_payload_profile()) != std::string::npos
					&& extract_json_string_field(spine_summary, "boundary_ledger", boundary_ledger_path_text)) {
			std::string boundary_ledger_text;
			std::vector<int32_t> setup_stack_args;
			if (read_text_file(std::filesystem::path(boundary_ledger_path_text), boundary_ledger_text)
					&& extract_setup_stack_args_0x49ecf2_from_ledger_text(boundary_ledger_text, setup_stack_args)
					&& setup_stack_args.size() >= 7
					&& setup_stack_args[0] == 72
					&& setup_stack_args[1] == 72
					&& setup_stack_args[2] == 1) {
				options.same_run_setup_stack_boundary_ledger_path = boundary_ledger_path_text;
				options.same_run_setup_stack_prefix_known = true;
				options.shared_runtime_chain_input.same_run_payload_authority_setup_stack_args_0x49ecf2 =
						std::move(setup_stack_args);
				options.shared_runtime_chain_input.same_run_payload_authority_setup_stack_args_known =
						options.shared_runtime_chain_input.same_run_payload_authority_setup_stack_args_0x49ecf2.size()
						== size_t(aurelion::h3maped_rmg_core::RMG_SETUP_STACK_ARG_COUNT_0X49ECF2);
				options.shared_runtime_chain_input.same_run_payload_authority_setup_stack_join_known = true;
				int32_t prepared_arg8 = 0;
				if (extract_setup_arg8_prepared_0x49ecf2_from_ledger_text(boundary_ledger_text, prepared_arg8)) {
					options.same_run_setup_prepared_arg8_known = true;
					options.same_run_setup_prepared_arg8 = prepared_arg8;
				}
				int32_t caller_arg9 = 0;
				if (extract_stack_arg_from_ledger_event_text(boundary_ledger_text, "0x004adfe1", 1, caller_arg9)
						&& caller_arg9 != 0) {
					options.same_run_setup_caller_arg9_known = true;
					options.same_run_setup_caller_arg9 = caller_arg9;
				}
			}
		}
		std::string preobject_ledger_text;
		int32_t setup_object_0x4c = 0;
		if (medium_seed10_profile
				&& read_text_file(options.same_run_preobject_trace_ledger_path, preobject_ledger_text)
				&& extract_generator_field_0x08_from_4a4c8e_ledger_text(preobject_ledger_text, setup_object_0x4c)) {
			options.same_run_setup_object_0x4c_known = true;
			options.same_run_setup_object_0x4c = setup_object_0x4c;
			options.shared_runtime_chain_input.same_run_payload_authority_setup_object_0x4c = setup_object_0x4c;
		}
		if (options.shared_runtime_chain_input.same_run_payload_authority_setup_stack_args_known
				&& options.shared_runtime_chain_input.same_run_payload_authority_setup_stack_args_0x49ecf2.size()
				>= size_t(aurelion::h3maped_rmg_core::RMG_SETUP_STACK_ARG_COUNT_0X49ECF2)) {
			const std::vector<int32_t> &args =
					options.shared_runtime_chain_input.same_run_payload_authority_setup_stack_args_0x49ecf2;
			options.same_run_setup_prepared_arg8_known = true;
			options.same_run_setup_prepared_arg8 = args[8];
			options.same_run_setup_object_0x4c_known = true;
			options.same_run_setup_object_0x4c = args[10];
			options.shared_runtime_chain_input.same_run_payload_authority_setup_object_0x44 = args[7];
			options.shared_runtime_chain_input.same_run_payload_authority_setup_object_0x48 = args[8];
			options.shared_runtime_chain_input.same_run_payload_authority_setup_object_0x4c = args[10];
		}
		if (medium_seed10_profile) {
			hydrate_same_run_river_entry_args_ledger(
					options,
					options.same_run_river_entry_args_ledger_path);
			hydrate_same_run_river_overlay_write_ledger(
					options,
					options.same_run_river_overlay_write_ledger_path);
			hydrate_same_run_road_type_rng_ledger(
					options,
					options.same_run_road_type_rng_ledger_path);
			hydrate_same_run_road_coordinate_vector_ledger(
					options,
					options.same_run_road_coordinate_vector_ledger_path);
			hydrate_same_run_road_callstream_ledger(
					options,
					options.same_run_road_callstream_ledger_path);
			hydrate_same_run_road_type_write_ledger(
					options,
					options.same_run_road_type_write_ledger_path);
			hydrate_same_run_road_art_write_ledger(
					options,
					options.same_run_road_art_write_ledger_path);
		}
	}
}

bool supported_case_scope(const ControlledCase &controlled_case) {
	if (!controlled_case.parse_ok) {
		return false;
	}
	const int32_t width =
			aurelion::h3maped_rmg_core::map_width_for_size_class(controlled_case.size_class);
	return aurelion::h3maped_rmg_core::supports_recovered_workflow_execution_scope(
			width,
			width,
			controlled_case.level_count,
			controlled_case.water_mode,
			controlled_case.size_class);
}

bool hydrate_same_run_setup_stack_boundary_ledger(Options &options, const std::filesystem::path &ledger_path) {
	if (ledger_path.empty()) {
		return false;
	}
	std::string boundary_ledger_text;
	std::vector<int32_t> setup_stack_args;
	const auto supported_setup_dimensions = [](const std::vector<int32_t> &args) {
		return args.size() >= 3
				&& args[0] == args[1]
				&& (args[0] == 36 || args[0] == 72 || args[0] == 108 || args[0] == 144)
				&& (args[2] == 1 || args[2] == 2);
	};
	if (!read_text_file(ledger_path, boundary_ledger_text)
			|| !extract_setup_stack_args_0x49ecf2_from_ledger_text(boundary_ledger_text, setup_stack_args)
			|| setup_stack_args.size() < 7
			|| !supported_setup_dimensions(setup_stack_args)) {
		return false;
	}
	options.same_run_setup_stack_boundary_ledger_path = ledger_path;
	options.same_run_setup_stack_prefix_known = true;
	options.shared_runtime_chain_input.same_run_payload_authority_setup_stack_args_0x49ecf2 =
			std::move(setup_stack_args);
	options.shared_runtime_chain_input.same_run_payload_authority_setup_stack_args_known =
			options.shared_runtime_chain_input.same_run_payload_authority_setup_stack_args_0x49ecf2.size()
			== size_t(aurelion::h3maped_rmg_core::RMG_SETUP_STACK_ARG_COUNT_0X49ECF2);
	options.shared_runtime_chain_input.same_run_payload_authority_setup_stack_join_known =
			options.shared_runtime_chain_input.same_run_payload_authority_setup_stack_args_known;
	int32_t prepared_arg8 = 0;
	if (extract_setup_arg8_prepared_0x49ecf2_from_ledger_text(boundary_ledger_text, prepared_arg8)) {
		options.same_run_setup_prepared_arg8_known = true;
		options.same_run_setup_prepared_arg8 = prepared_arg8;
	}
	int32_t caller_arg9 = 0;
	if (extract_stack_arg_from_ledger_event_text(boundary_ledger_text, "0x004adfe1", 1, caller_arg9)
			&& caller_arg9 != 0) {
		options.same_run_setup_caller_arg9_known = true;
		options.same_run_setup_caller_arg9 = caller_arg9;
	}
	return true;
}

bool hydrate_same_run_river_entry_args_ledger(Options &options, const std::filesystem::path &ledger_path) {
	if (ledger_path.empty()) {
		return false;
	}
	std::string ledger_text;
	std::vector<int32_t> args_4ab6ac;
	std::vector<int32_t> args_4abd5f;
	if (!read_text_file(ledger_path, ledger_text)
			|| !extract_river_entry_args_from_ledger_text(ledger_text, args_4ab6ac, args_4abd5f)
			|| args_4ab6ac.size() < 4
			|| args_4abd5f.size() < 4) {
		return false;
	}
	options.same_run_river_entry_args_ledger_path = ledger_path;
	options.shared_runtime_chain_input.same_run_payload_authority_river_4ab6ac_args =
			std::move(args_4ab6ac);
	options.shared_runtime_chain_input.same_run_payload_authority_river_4abd5f_args =
			std::move(args_4abd5f);
	options.shared_runtime_chain_input.same_run_payload_authority_river_entry_args_known =
			options.shared_runtime_chain_input.same_run_payload_authority_river_4ab6ac_args.size() >= 4
			&& options.shared_runtime_chain_input.same_run_payload_authority_river_4abd5f_args.size() >= 4;
	return options.shared_runtime_chain_input.same_run_payload_authority_river_entry_args_known;
}

bool hydrate_same_run_river_overlay_write_ledger(Options &options, const std::filesystem::path &ledger_path) {
	if (ledger_path.empty()) {
		return false;
	}
	std::string ledger_text;
	std::vector<aurelion::h3maped_rmg_core::RecoveredRiverOverlayWrite49b1bc49b170> writes;
	if (!read_text_file(ledger_path, ledger_text)
			|| !extract_river_overlay_writes_from_ledger_text(ledger_text, writes)
			|| writes.empty()) {
		return false;
	}
	options.same_run_river_overlay_write_ledger_path = ledger_path;
	options.shared_runtime_chain_input.same_run_payload_authority_river_overlay_writes_0x49b1bc_0x49b170 =
			std::move(writes);
	options.shared_runtime_chain_input.same_run_payload_authority_river_overlay_writes_known =
			!options.shared_runtime_chain_input.same_run_payload_authority_river_overlay_writes_0x49b1bc_0x49b170.empty();
	return options.shared_runtime_chain_input.same_run_payload_authority_river_overlay_writes_known;
}

bool hydrate_same_run_road_type_rng_ledger(Options &options, const std::filesystem::path &ledger_path) {
	if (ledger_path.empty()) {
		return false;
	}
	std::string ledger_text;
	int32_t rng_value = -1;
	if (!read_text_file(ledger_path, ledger_text)
			|| !extract_road_type_rng_value_from_ledger_text(ledger_text, rng_value)) {
		return false;
	}
	options.same_run_road_type_rng_ledger_path = ledger_path;
	options.shared_runtime_chain_input.same_run_payload_authority_road_type_rng_known = true;
	options.shared_runtime_chain_input.same_run_payload_authority_road_type_rng_value_0x4e7276 = rng_value;
	return true;
}

bool hydrate_same_run_road_coordinate_vector_ledger(Options &options, const std::filesystem::path &ledger_path) {
	if (ledger_path.empty()) {
		return false;
	}
	std::string ledger_text;
	std::vector<aurelion::h3maped_rmg_core::RoadCoordinateRecord14b0> records;
	if (!read_text_file(ledger_path, ledger_text)
			|| !extract_road_coordinate_records_from_ledger_text(ledger_text, records)) {
		return false;
	}
	options.same_run_road_coordinate_vector_ledger_path = ledger_path;
	options.shared_runtime_chain_input.same_run_payload_authority_road_coordinate_records_0x14b0 =
			std::move(records);
	options.shared_runtime_chain_input.same_run_payload_authority_road_coordinate_records_known =
			!options.shared_runtime_chain_input.same_run_payload_authority_road_coordinate_records_0x14b0.empty();
	return options.shared_runtime_chain_input.same_run_payload_authority_road_coordinate_records_known;
}

bool hydrate_same_run_road_callstream_ledger(Options &options, const std::filesystem::path &ledger_path) {
	if (ledger_path.empty()) {
		return false;
	}
	std::string ledger_text;
	std::vector<aurelion::h3maped_rmg_core::RecoveredRoadCall4ab37f> calls;
	if (!read_text_file(ledger_path, ledger_text)
			|| !extract_road_callstream_from_ledger_text(ledger_text, calls)) {
		return false;
	}
	options.same_run_road_callstream_ledger_path = ledger_path;
	options.shared_runtime_chain_input.same_run_payload_authority_road_calls_0x4ab37f =
			std::move(calls);
	options.shared_runtime_chain_input.same_run_payload_authority_road_callstream_known =
			!options.shared_runtime_chain_input.same_run_payload_authority_road_calls_0x4ab37f.empty();
	return options.shared_runtime_chain_input.same_run_payload_authority_road_callstream_known;
}

bool hydrate_same_run_road_type_write_ledger(Options &options, const std::filesystem::path &ledger_path) {
	if (ledger_path.empty()
			|| !options.shared_runtime_chain_input.same_run_payload_authority_road_callstream_known) {
		return false;
	}
	std::string ledger_text;
	std::vector<aurelion::h3maped_rmg_core::RecoveredRoadTypeWrite49aec5> writes;
	if (!read_text_file(ledger_path, ledger_text)
			|| !extract_road_type_writes_from_ledger_text(
					ledger_text,
					options.shared_runtime_chain_input.same_run_payload_authority_road_calls_0x4ab37f,
					writes)) {
		return false;
	}
	options.same_run_road_type_write_ledger_path = ledger_path;
	options.shared_runtime_chain_input.same_run_payload_authority_road_type_writes_0x49aec5 =
			std::move(writes);
	options.shared_runtime_chain_input.same_run_payload_authority_road_type_writes_known =
			!options.shared_runtime_chain_input.same_run_payload_authority_road_type_writes_0x49aec5.empty();
	return options.shared_runtime_chain_input.same_run_payload_authority_road_type_writes_known;
}

bool hydrate_same_run_road_art_write_ledger(Options &options, const std::filesystem::path &ledger_path) {
	if (ledger_path.empty()) {
		return false;
	}
	std::string ledger_text;
	std::vector<aurelion::h3maped_rmg_core::RecoveredRoadArtWrite49ae47> writes;
	if (!read_text_file(ledger_path, ledger_text)
			|| !extract_road_art_writes_from_ledger_text(ledger_text, writes)) {
		return false;
	}
	options.same_run_road_art_write_ledger_path = ledger_path;
	options.shared_runtime_chain_input.same_run_payload_authority_road_art_writes_0x49ae47 =
			std::move(writes);
	options.shared_runtime_chain_input.same_run_payload_authority_road_art_writes_known =
			!options.shared_runtime_chain_input.same_run_payload_authority_road_art_writes_0x49ae47.empty();
	return options.shared_runtime_chain_input.same_run_payload_authority_road_art_writes_known;
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
		const bool authority_backed_one_level_extended_scope =
				((controlled_case.size_class == "xlarge"
						&& (controlled_case.water_mode == "normal_water"
								|| controlled_case.water_mode == "islands"))
						|| (controlled_case.size_class == "large"
								&& controlled_case.water_mode == "islands"))
				&& controlled_case.level_count == 1;
		const bool authority_backed_extended_scope =
				(controlled_case.level_count == 2 || authority_backed_one_level_extended_scope)
				&& options.shared_runtime_chain_input.same_run_payload_authority_profile_known
				&& controlled_case_matches_same_run_payload_profile(
						controlled_case,
						options.shared_runtime_chain_input.same_run_payload_authority_profile);
		const bool supported =
				supported_case_scope(controlled_case) || authority_backed_extended_scope;
		if (!supported && !options.include_unsupported) {
			++skipped_count;
			continue;
		}
		apply_same_run_setup_authority_prefix_to_case(controlled_case, options);
		const SharedRuntimeChainInput case_shared_input =
				same_run_authority_input_for_case(controlled_case, options);
		CaseReport report;
		report.input = controlled_case;
		report.supported_scope = supported;
		const aurelion::rmg_native_core::NativeH3MapedWorkflowResult workflow =
				aurelion::rmg_native_core::run_native_h3maped_workflow(controlled_case, case_shared_input);
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
		const aurelion::h3maped_rmg_core::RuntimeMapPayloadProjection runtime_projection =
				aurelion::h3maped_rmg_core::project_runtime_map_from_parity_owned_final_payload(
						workflow.status == "complete",
						workflow.final_payload_owned,
						workflow.final_writeout_complete,
						workflow.final_header_writeout_0x4ac857_0x4ad206,
						workflow.final_tile_writeout_0x49b2b6,
						workflow.final_object_writeout_0x4ad309_0x4ad3eb,
						workflow.final_payload_writeout_0x4ad1e3);
		report.runtime_payload_projection_applied = runtime_projection.applied;
		report.runtime_payload_projection_blocked_reason = runtime_projection.blocked_reason;
		report.runtime_payload_projection_tile_count = runtime_projection.tile_count;
		report.runtime_payload_projection_object_count = runtime_projection.object_count;
		report.runtime_payload_projection_road_tile_count = int32_t(runtime_projection.road_tiles.size());
		report.runtime_payload_projection_object_payload_byte_count =
				runtime_projection.consumed_object_payload_byte_count;
		report.final_h3m_payload_export_authorized =
				workflow.final_payload_owned
				&& workflow.final_writeout_complete
				&& workflow.final_payload_writeout_0x4ad1e3.same_run_h3maped_compare_complete
				&& workflow.final_payload_writeout_0x4ad1e3.same_run_generated_object_payload_native_serialization_match
				&& !workflow.final_payload_writeout_0x4ad1e3.generated_object_count_replayed_from_same_run_authority_0x4ad330
				&& !workflow.final_payload_writeout_0x4ad1e3.generated_object_payload_replayed_from_same_run_authority_0x4ad1e3;
		const std::string safe_case_id = aurelion::rmg_native_core::safe_case_filename(controlled_case.id);
		if (options.emit_phase_snapshot) {
			const std::filesystem::path snapshot_path = absolute_output_dir / (safe_case_id + ".phase_snapshot.json");
			std::ofstream snapshot(snapshot_path, std::ios::binary);
			if (snapshot) {
				snapshot << aurelion::rmg_native_core::case_native_h3maped_workflow_json(controlled_case, report.status, report.blocked_reason, case_shared_input);
				report.phase_snapshot_written = true;
				report.phase_snapshot_path = snapshot_path;
			}
		}
		const bool write_final_payload_diagnostic =
				workflow.final_payload_writeout_0x4ad1e3.applied
				&& (options.emit_phase_snapshot || options.emit_final_h3m_payload);
		const bool write_final_payload_authorized_output =
				options.emit_final_h3m_payload && report.final_h3m_payload_export_authorized;
		if (write_final_payload_diagnostic || write_final_payload_authorized_output) {
				const std::filesystem::path payload_path = absolute_output_dir / (safe_case_id + ".final_payload.bin");
				if (write_binary_file(payload_path, workflow.final_payload_writeout_0x4ad1e3.payload_bytes)) {
					report.final_payload_binary_written = true;
					report.final_payload_binary_path = payload_path;
					if (report.final_h3m_payload_export_authorized) {
						report.final_h3m_payload_written = true;
						report.final_h3m_payload_path = payload_path;
					}
				}
				const std::filesystem::path sections_path = absolute_output_dir / (safe_case_id + ".final_payload_sections.json");
				if (write_final_payload_sections_json(sections_path, workflow.final_payload_writeout_0x4ad1e3.sections)) {
					report.final_payload_sections_written = true;
					report.final_payload_sections_path = sections_path;
				}
		}
		if (options.emit_runtime_package) {
			if (!report.final_h3m_payload_export_authorized || !runtime_projection.applied) {
				report.status = "blocked";
				report.blocked_reason = runtime_projection.blocked_reason.empty()
						? "runtime_package_requires_parity_proven_native_owned_payload_projection"
						: runtime_projection.blocked_reason;
			} else {
				const std::filesystem::path map_path = absolute_output_dir / (safe_case_id + ".amap");
				const std::filesystem::path scenario_path = absolute_output_dir / (safe_case_id + ".ascenario");
				report.runtime_map_package_written = write_runtime_map_package(
						map_path,
						scenario_path,
						controlled_case,
						runtime_projection,
						workflow.final_payload_writeout_0x4ad1e3);
				report.runtime_scenario_package_written = write_runtime_scenario_package(
						scenario_path,
						map_path,
						controlled_case,
						runtime_projection,
						workflow.final_payload_writeout_0x4ad1e3);
				if (report.runtime_map_package_written && report.runtime_scenario_package_written) {
					report.runtime_map_package_path = map_path;
					report.runtime_scenario_package_path = scenario_path;
					report.status = "runtime_package_exported";
					report.blocked_reason.clear();
				} else {
					report.status = "failed";
					report.blocked_reason = "runtime_package_write_failed";
				}
			}
		}
		if (report.final_h3m_payload_export_authorized) {
			if (report.status == "runtime_package_exported") {
				// Keep the stronger package status when both output modes are requested.
			} else if (report.final_h3m_payload_written && report.final_payload_sections_written) {
				report.status = "native_h3m_payload_exported";
				report.blocked_reason.clear();
			} else if (options.emit_final_h3m_payload) {
				report.status = "failed";
				report.blocked_reason = "native_h3m_payload_export_write_failed";
			} else if (options.emit_phase_snapshot) {
				report.status = report.final_h3m_payload_written
						? "native_h3m_payload_exported"
						: "native_h3m_payload_ready";
				if (report.status == "native_h3m_payload_exported") {
					report.blocked_reason.clear();
				}
			} else {
				report.status = "native_h3m_payload_ready";
				report.blocked_reason.clear();
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
	int native_h3m_payload_exported_count = 0;
	int native_h3m_payload_ready_count = 0;
	int native_h3m_payload_failed_count = 0;
	int runtime_package_exported_count = 0;
	int runtime_package_failed_count = 0;
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
	int runtime_payload_projection_applied_count = 0;
	int final_payload_binary_written_count = 0;
	int final_payload_sections_written_count = 0;
	std::string first_blocked_reason;
	for (const CaseReport &report : case_reports) {
		if (report.final_h3m_payload_written) {
			++native_h3m_payload_exported_count;
			if (!report.final_payload_sections_written) {
				++native_h3m_payload_failed_count;
			}
		} else if (options.emit_final_h3m_payload && report.final_h3m_payload_export_authorized) {
			++native_h3m_payload_failed_count;
		}
		if (report.status == "failed") {
			++failed_count;
		} else if (report.status == "unsupported_scope") {
			++unsupported_count;
		} else if (report.status == "native_map_json_exported") {
			++native_map_json_exported_count;
			if (!report.native_map_json_written) {
				++native_map_json_failed_count;
			}
		} else if (report.status == "native_h3m_payload_ready") {
			++native_h3m_payload_ready_count;
		} else if (report.status == "runtime_package_exported") {
			++runtime_package_exported_count;
			if (!report.runtime_map_package_written || !report.runtime_scenario_package_written) {
				++runtime_package_failed_count;
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
		if (report.runtime_payload_projection_applied) {
			++runtime_payload_projection_applied_count;
		}
		if (report.final_payload_binary_written) {
			++final_payload_binary_written_count;
		}
		if (report.final_payload_sections_written) {
			++final_payload_sections_written_count;
		}
		if (first_blocked_reason.empty()
				&& report.status == "blocked"
				&& !report.blocked_reason.empty()) {
			first_blocked_reason = report.blocked_reason;
		}
	}
	const int blocked_count = int(case_reports.size())
			- failed_count
			- unsupported_count
			- native_map_json_exported_count
			- native_h3m_payload_exported_count
			- native_h3m_payload_ready_count
			- runtime_package_exported_count;
	const bool native_map_output_complete =
			!case_reports.empty()
			&& native_map_json_exported_count == int(case_reports.size())
			&& native_map_json_failed_count == 0;
	const bool native_h3m_payload_output_complete =
			!case_reports.empty()
			&& native_h3m_payload_exported_count == int(case_reports.size())
			&& native_h3m_payload_failed_count == 0;
	const bool runtime_package_output_complete =
			!case_reports.empty()
			&& runtime_package_exported_count == int(case_reports.size())
			&& runtime_package_failed_count == 0;
	const std::string status =
			(native_map_output_complete || native_h3m_payload_output_complete || runtime_package_output_complete)
			? "complete"
			: "blocked";
	const bool final_payload_compare_reached =
			native_workflow_final_payload_assembly_applied_count > 0;
	const std::string blocked_reason = status == "complete"
			? ""
			: (!first_blocked_reason.empty()
							? first_blocked_reason
							: (final_payload_compare_reached
							? "native_h3maped_workflow_reaches_ordered_final_payload_compare_but_same_run_payload_parity_is_not_owned"
							: "native_h3maped_workflow_blocked_before_ordered_final_payload_compare"));
		const bool setup_stack_authority_missing =
				blocked_reason == "same_run_payload_authority_0x49ecf2_stack_join_missing"
				|| blocked_reason.rfind("same_run_payload_authority_0x49ecf2_stack_words_incomplete_captured_", 0) == 0;
			const bool same_run_authority_profile_mismatch =
					blocked_reason == "same_run_payload_authority_profile_mismatch_expected_hc1_co1_fixed_2p"
					|| blocked_reason == "same_run_payload_authority_setup_object_0x44_missing_for_hc1_co1_profile"
					|| blocked_reason == "same_run_payload_authority_profile_requires_recovered_0x49ecf2_setup_stack_arg7"
					|| blocked_reason == "same_run_payload_authority_profile_requires_legacy_setup_object_0x44_1_without_full_stack"
					|| blocked_reason == "same_run_payload_authority_unrecognized_recovered_profile";
			const bool type98_source_pair_feed_missing =
					blocked_reason == "0x4ac552_live_type98_source_pair_feed_0xedc_missing_before_0x4a8d2c_0x4a8db2";
			const bool final_payload_matched_private_state_unowned =
					blocked_reason == "runtime_map_output_disabled_after_same_run_final_payload_compare_matched_until_native_object_record_private_state_parity";
			const std::string generation_core_stage = runtime_package_output_complete
					? "native_h3maped_workflow_runtime_package_projection_exported_for_controlled_parity_case"
					: native_h3m_payload_output_complete
						? "native_h3maped_workflow_final_payload_parity_owned_and_h3m_payload_exported"
					: (setup_stack_authority_missing
						? "native_h3maped_workflow_reaches_ordered_final_payload_assembly_but_same_run_setup_stack_authority_incomplete"
						: (same_run_authority_profile_mismatch
								? "native_h3maped_workflow_reaches_ordered_final_payload_assembly_but_same_run_payload_authority_profile_mismatches_recovered_0x49ecf2_stack"
					: (final_payload_matched_private_state_unowned
							? "native_h3maped_workflow_reaches_ordered_final_payload_assembly_and_blocks_on_native_object_record_private_state_parity"
					: (final_payload_compare_reached
							? "native_h3maped_workflow_reaches_ordered_final_payload_assembly_and_blocks_on_same_run_payload_compare"
							: "native_h3maped_workflow_blocks_before_ordered_final_payload_assembly"))));
			const std::string required_next_slice = runtime_package_output_complete
					? "connect_public_runtime_generation_to_parity_proven_native_workflow_without_external_authority_replay"
					: native_h3m_payload_output_complete
						? "implement_runtime_package_session_adoption_from_owned_h3m_payload_without_reintroducing_legacy_proxy"
					: (setup_stack_authority_missing
						? "recover_or_supply_uncaptured_same_run_0x49ecf2_setup_stack_tail_before_final_payload_compare"
						: (same_run_authority_profile_mismatch
								? "recover_or_select_same_profile_h3maped_payload_authority_for_recovered_0x49ecf2_stack_before_final_payload_compare"
					: (type98_source_pair_feed_missing
							? "recover_or_port_live_type98_0xedc_source_pair_feed_before_0x4a8d2c_0x4a8db2"
					: (final_payload_matched_private_state_unowned
							? "align_native_object_record_private_state_with_same_run_h3maped_before_runtime_output"
							: (final_payload_compare_reached
									? "align_final_tile_stream_0x49b2b6_and_generated_object_payload_against_same_run_h3maped_payload"
									: "resolve_current_native_h3maped_workflow_phase_blocker_before_final_payload_compare")))));
			const std::string message = runtime_package_output_complete
					? "The standalone native workflow proved final payload parity, projected every owned tile and object byte without authority replay, and exported paired runtime-loadable map/scenario packages for the controlled case. Public arbitrary-config runtime generation remains fail-closed until the native workflow no longer depends on supplied same-run authority inputs."
					: native_h3m_payload_output_complete
						? "This executable is the no-Godot boundary for the single native H3MapEd workflow. It executed ordered phases through final writeout, proved same-run tile/generated-object/native object serialization parity for the supplied authority case, and exported the owned final H3M payload bytes. Native map JSON and runtime .amap package/session adoption remain disabled until a real H3M-payload-to-package converter is implemented."
					: (setup_stack_authority_missing
						? "This executable is the no-Godot boundary for the single native H3MapEd workflow. It executes ordered phases through final payload assembly and hydrates the recovered same-run 0x49ecf2 setup prefix, but refuses same-run tile/object byte comparison until the uncaptured setup-stack tail words are recovered or supplied; final-byte deltas are not actionable before that setup identity is owned."
						: (same_run_authority_profile_mismatch
								? "This executable is the no-Godot boundary for the single native H3MapEd workflow. It executes ordered phases through final payload assembly but refuses tile/object byte comparison unless the stitched H3MapEd payload authority and controlled native setup share the recovered Medium seed-10 HC1/CO1 0x49ecf2 stack."
					: (type98_source_pair_feed_missing
							? "This executable is the no-Godot boundary for the single native H3MapEd workflow. It now refuses to manufacture type-98 town/castle materialization from runtime-zone template fields; the recovered live +0xedc source-pair feed into 0x4a8d2c/0x4a8db2 must be owned before route, connection, road, or final payload phases can run."
					: (final_payload_matched_private_state_unowned
							? "This executable is the no-Godot boundary for the single native H3MapEd workflow. It executes ordered phases through final writeout and can assemble a same-run-matching payload only by consuming recovered authority streams; it exits blocked before native map output until the native object-record private state itself matches H3MapEd."
							: (final_payload_compare_reached
									? "This executable is the no-Godot boundary for the single native H3MapEd workflow. It executes ordered phases through relation scan, mine/resource, reward/guard, connection/road, final header, final tile, and generated-object payload assembly, then exits blocked before native map output until same-run 0x49b2b6 tile and generated-object payload parity are owned."
									: "This executable is the no-Godot boundary for the single native H3MapEd workflow. It exits at the current source-order phase blocker before final payload assembly; native map output remains disabled until that phase is source-owned.")))));
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
	out << "  \"emit_final_h3m_payload\": " << (options.emit_final_h3m_payload ? "true" : "false") << ",\n";
	out << "  \"emit_runtime_package\": " << (options.emit_runtime_package ? "true" : "false") << ",\n";
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
	out << "  \"same_run_object_payload_authority_object_count\": " << options.shared_runtime_chain_input.same_run_payload_authority_object_count << ",\n";
	out << "  \"same_run_object_payload_authority_byte_count\": " << options.shared_runtime_chain_input.same_run_generated_object_payload_authority_0x4ad1e3.size() << ",\n";
	out << "  \"same_run_full_payload_authority_path\": \"" << json_escape(options.same_run_full_payload_authority_path.string()) << "\",\n";
	out << "  \"same_run_full_payload_authority_known\": " << (options.shared_runtime_chain_input.same_run_full_payload_authority_known ? "true" : "false") << ",\n";
	out << "  \"same_run_full_payload_authority_byte_count\": " << options.shared_runtime_chain_input.same_run_full_payload_authority_0x4ac857_0x4ad3db.size() << ",\n";
	out << "  \"same_run_payload_summary_path\": \"" << json_escape(options.same_run_payload_summary_path.string()) << "\",\n";
	out << "  \"same_run_ordered_writeout_spine_summary_path\": \"" << json_escape(options.same_run_ordered_writeout_spine_summary_path.string()) << "\",\n";
	out << "  \"same_run_preobject_trace_ledger_path\": \"" << json_escape(options.same_run_preobject_trace_ledger_path.string()) << "\",\n";
	out << "  \"same_run_setup_stack_boundary_ledger_path\": \"" << json_escape(options.same_run_setup_stack_boundary_ledger_path.string()) << "\",\n";
	out << "  \"same_run_river_entry_args_ledger_path\": \"" << json_escape(options.same_run_river_entry_args_ledger_path.string()) << "\",\n";
	out << "  \"same_run_river_overlay_write_ledger_path\": \"" << json_escape(options.same_run_river_overlay_write_ledger_path.string()) << "\",\n";
	out << "  \"same_run_road_type_rng_ledger_path\": \"" << json_escape(options.same_run_road_type_rng_ledger_path.string()) << "\",\n";
	out << "  \"same_run_road_coordinate_vector_ledger_path\": \"" << json_escape(options.same_run_road_coordinate_vector_ledger_path.string()) << "\",\n";
	out << "  \"same_run_road_callstream_ledger_path\": \"" << json_escape(options.same_run_road_callstream_ledger_path.string()) << "\",\n";
	out << "  \"same_run_road_type_write_ledger_path\": \"" << json_escape(options.same_run_road_type_write_ledger_path.string()) << "\",\n";
	out << "  \"same_run_road_art_write_ledger_path\": \"" << json_escape(options.same_run_road_art_write_ledger_path.string()) << "\",\n";
	out << "  \"same_run_payload_authority_profile_known\": " << (options.shared_runtime_chain_input.same_run_payload_authority_profile_known ? "true" : "false") << ",\n";
	out << "  \"same_run_payload_authority_profile\": \"" << json_escape(options.shared_runtime_chain_input.same_run_payload_authority_profile) << "\",\n";
	out << "  \"same_run_setup_stack_prefix_known\": " << (options.same_run_setup_stack_prefix_known ? "true" : "false") << ",\n";
	out << "  \"same_run_setup_prepared_arg8_known\": " << (options.same_run_setup_prepared_arg8_known ? "true" : "false") << ",\n";
	out << "  \"same_run_setup_prepared_arg8\": " << options.same_run_setup_prepared_arg8 << ",\n";
	out << "  \"same_run_setup_caller_arg9_known\": " << (options.same_run_setup_caller_arg9_known ? "true" : "false") << ",\n";
	out << "  \"same_run_setup_caller_arg9\": " << options.same_run_setup_caller_arg9 << ",\n";
	out << "  \"same_run_setup_object_0x4c_known\": " << (options.same_run_setup_object_0x4c_known ? "true" : "false") << ",\n";
	out << "  \"same_run_setup_object_0x4c\": " << options.same_run_setup_object_0x4c << ",\n";
	out << "  \"same_run_payload_authority_setup_stack_join_known\": " << (options.shared_runtime_chain_input.same_run_payload_authority_setup_stack_join_known ? "true" : "false") << ",\n";
	out << "  \"same_run_payload_authority_setup_stack_args_known\": " << (options.shared_runtime_chain_input.same_run_payload_authority_setup_stack_args_known ? "true" : "false") << ",\n";
	out << "  \"same_run_payload_authority_setup_stack_arg_count\": " << options.shared_runtime_chain_input.same_run_payload_authority_setup_stack_args_0x49ecf2.size() << ",\n";
	out << "  \"same_run_payload_authority_setup_stack_expected_arg_count\": " << aurelion::h3maped_rmg_core::RMG_SETUP_STACK_ARG_COUNT_0X49ECF2 << ",\n";
	out << "  \"same_run_payload_authority_setup_stack_args_0x49ecf2\": ";
	append_json_int_array(out, options.shared_runtime_chain_input.same_run_payload_authority_setup_stack_args_0x49ecf2);
	out << ",\n";
	out << "  \"same_run_payload_authority_river_entry_args_known\": " << (options.shared_runtime_chain_input.same_run_payload_authority_river_entry_args_known ? "true" : "false") << ",\n";
	out << "  \"same_run_payload_authority_river_4ab6ac_args\": ";
	append_json_int_array(out, options.shared_runtime_chain_input.same_run_payload_authority_river_4ab6ac_args);
	out << ",\n";
	out << "  \"same_run_payload_authority_river_4abd5f_args\": ";
	append_json_int_array(out, options.shared_runtime_chain_input.same_run_payload_authority_river_4abd5f_args);
	out << ",\n";
	out << "  \"same_run_payload_authority_river_overlay_writes_known\": " << (options.shared_runtime_chain_input.same_run_payload_authority_river_overlay_writes_known ? "true" : "false") << ",\n";
	out << "  \"same_run_payload_authority_river_overlay_write_count\": " << options.shared_runtime_chain_input.same_run_payload_authority_river_overlay_writes_0x49b1bc_0x49b170.size() << ",\n";
	out << "  \"same_run_payload_authority_road_type_rng_known\": " << (options.shared_runtime_chain_input.same_run_payload_authority_road_type_rng_known ? "true" : "false") << ",\n";
	out << "  \"same_run_payload_authority_road_type_rng_value_0x4e7276\": " << options.shared_runtime_chain_input.same_run_payload_authority_road_type_rng_value_0x4e7276 << ",\n";
	out << "  \"same_run_payload_authority_road_coordinate_records_known\": " << (options.shared_runtime_chain_input.same_run_payload_authority_road_coordinate_records_known ? "true" : "false") << ",\n";
	out << "  \"same_run_payload_authority_road_coordinate_record_count_0x14b0\": " << options.shared_runtime_chain_input.same_run_payload_authority_road_coordinate_records_0x14b0.size() << ",\n";
	out << "  \"same_run_payload_authority_road_callstream_known\": " << (options.shared_runtime_chain_input.same_run_payload_authority_road_callstream_known ? "true" : "false") << ",\n";
	out << "  \"same_run_payload_authority_road_call_count_0x4ab37f\": " << options.shared_runtime_chain_input.same_run_payload_authority_road_calls_0x4ab37f.size() << ",\n";
	out << "  \"same_run_payload_authority_road_type_writes_known\": " << (options.shared_runtime_chain_input.same_run_payload_authority_road_type_writes_known ? "true" : "false") << ",\n";
	out << "  \"same_run_payload_authority_road_type_write_count_0x49aec5\": " << options.shared_runtime_chain_input.same_run_payload_authority_road_type_writes_0x49aec5.size() << ",\n";
	out << "  \"same_run_payload_authority_road_art_writes_known\": " << (options.shared_runtime_chain_input.same_run_payload_authority_road_art_writes_known ? "true" : "false") << ",\n";
	out << "  \"same_run_payload_authority_road_art_write_count_0x49ae47\": " << options.shared_runtime_chain_input.same_run_payload_authority_road_art_writes_0x49ae47.size() << ",\n";
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
	out << "  \"runtime_payload_projection_applied_count\": " << runtime_payload_projection_applied_count << ",\n";
	out << "  \"case_count\": " << case_reports.size() << ",\n";
	out << "  \"blocked_count\": " << blocked_count << ",\n";
	out << "  \"unsupported_count\": " << unsupported_count << ",\n";
	out << "  \"skipped_count\": " << skipped_count << ",\n";
	out << "  \"exported_count\": " << (native_map_json_exported_count + native_h3m_payload_exported_count + runtime_package_exported_count) << ",\n";
	out << "  \"native_map_json_exported_count\": " << native_map_json_exported_count << ",\n";
	out << "  \"native_map_json_failed_count\": " << native_map_json_failed_count << ",\n";
	out << "  \"native_h3m_payload_exported_count\": " << native_h3m_payload_exported_count << ",\n";
	out << "  \"native_h3m_payload_ready_count\": " << native_h3m_payload_ready_count << ",\n";
	out << "  \"native_h3m_payload_failed_count\": " << native_h3m_payload_failed_count << ",\n";
	out << "  \"runtime_package_exported_count\": " << runtime_package_exported_count << ",\n";
	out << "  \"runtime_package_failed_count\": " << runtime_package_failed_count << ",\n";
	out << "  \"native_map_json_public_api_removed\": true,\n";
	out << "  \"legacy_native_generation_surface_removed\": true,\n";
	out << "  \"phase_snapshot_exported_count\": 0,\n";
	out << "  \"phase_snapshot_written_count\": " << phase_snapshot_written_count << ",\n";
	out << "  \"phase_snapshot_failed_count\": " << phase_snapshot_failed_count << ",\n";
	out << "  \"final_payload_binary_written_count\": " << final_payload_binary_written_count << ",\n";
	out << "  \"final_payload_sections_written_count\": " << final_payload_sections_written_count << ",\n";
	out << "  \"failed_count\": " << failed_count << ",\n";
	out << "  \"generation_core_stage\": \"" << json_escape(generation_core_stage) << "\",\n";
	out << "  \"phase_snapshot_schema_id\": \"rmg_native_batch_export_cli_native_h3maped_workflow_v1\",\n";
	out << "  \"native_map_json_schema_id\": \"disabled_until_full_recovered_h3maped_entrypoint_to_writeout_chain_owns_payload\",\n";
	out << "  \"native_h3m_payload_schema_id\": \"h3m_final_payload_stream_0x4ad1e3_v1\",\n";
	out << "  \"runtime_package_schema_id\": \"aurelion_native_h3maped_runtime_package_projection_v1\",\n";
	out << "  \"runtime_map_package_schema_id\": \"aurelion_map_package\",\n";
	out << "  \"runtime_scenario_package_schema_id\": \"aurelion_scenario_package\",\n";
	out << "  \"required_next_slice\": \"" << json_escape(required_next_slice) << "\",\n";
	out << "  \"message\": \"" << json_escape(message) << "\",\n";
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
	int native_h3m_payload_exported_count = 0;
	int native_h3m_payload_failed_count = 0;
	int runtime_package_exported_count = 0;
	int runtime_package_failed_count = 0;
	int phase_snapshot_written_count = 0;
	int phase_snapshot_failed_count = 0;
	int final_payload_binary_written_count = 0;
	for (const CaseReport &report : case_reports) {
		if (report.final_h3m_payload_written) {
			++native_h3m_payload_exported_count;
			if (!report.final_payload_sections_written) {
				++native_h3m_payload_failed_count;
			}
		} else if (options.emit_final_h3m_payload && report.final_h3m_payload_export_authorized) {
			++native_h3m_payload_failed_count;
		}
		if (report.status == "failed") {
			++failed_count;
		} else if (report.status == "unsupported_scope") {
			++unsupported_count;
		} else if (report.status == "native_map_json_exported") {
			++native_map_json_exported_count;
			if (!report.native_map_json_written) {
				++native_map_json_failed_count;
			}
		} else if (report.status == "runtime_package_exported") {
			++runtime_package_exported_count;
			if (!report.runtime_map_package_written || !report.runtime_scenario_package_written) {
				++runtime_package_failed_count;
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
	const bool native_h3m_payload_output_complete =
			!case_reports.empty()
			&& native_h3m_payload_exported_count == int(case_reports.size())
			&& native_h3m_payload_failed_count == 0;
	const bool runtime_package_output_complete =
			!case_reports.empty()
			&& runtime_package_exported_count == int(case_reports.size())
			&& runtime_package_failed_count == 0;
	const bool output_complete = native_h3m_payload_output_complete || runtime_package_output_complete;
	const char *summary_status = output_complete ? "complete" : "blocked";
	std::cout << "RMG_NATIVE_BATCH_EXPORT_CLI status=" << summary_status << " output_dir=" << absolute_output_dir.string()
			  << " cases=" << case_reports.size()
			  << " phase_snapshots_written=" << phase_snapshot_written_count
			  << " final_payload_binaries_written=" << final_payload_binary_written_count
			  << " native_h3m_payload_exported=" << native_h3m_payload_exported_count
			  << " runtime_package_exported=" << runtime_package_exported_count
			  << " reason=" << (runtime_package_output_complete
					  ? "native_h3maped_workflow_parity_owned_runtime_packages_exported"
					  : native_h3m_payload_output_complete
					  ? "native_h3maped_workflow_final_payload_parity_owned_h3m_payload_exported"
					  : "native_h3maped_workflow_header_0x4ac857_post_zero_0x4ad206_tile_object_payloads_and_0x4ad3db_sentinel_owned_blocked_before_or_at_full_payload_compare")
			  << "\n";
	return failed_count > 0 ? 1 : (output_complete ? 0 : 2);
}
