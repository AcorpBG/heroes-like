#pragma once

// Godot 4.6.2's JSON.stringify(value, indent, sort_keys, full_precision)
// (core/io/json.cpp, JSON::_stringify, of the 4.6.2-stable tag, MIT) over the
// State's values: the match runner's records and the map packages the core
// writes (Phase 8, P8-7 and P8-8). An opaque value is written as null.

#include "aurelion_rules/battle_state.hpp"

#include <cstddef>
#include <string>
#include <string_view>

namespace aurelion::rules::compat {

// "\"" + text.json_escape() + "\"" (String::json_escape): the backslash,
// \b \f \n \r \t \v and the quote; other characters as they are.
void append_json_string(std::string &out, std::string_view text);

// str() of a Vector2i or Vector3i: "(x, y)", "(x, y, z)".
std::string vector_text(const state::Value &value);

// String(key) of a Dictionary key, as JSON writes it.
std::string key_text(const state::State &state, const state::Value &value);

// JSON.stringify(value, indent, sort_keys, full_precision) at depth levels of
// indent.
struct JsonWriter {
	const state::State &state;
	std::string indent;
	bool sort_keys = true;
	bool full_precision = false;

	void pad(std::string &out, int depth) const {
		for (int level = 0; level < depth; ++level) {
			out += indent;
		}
	}
	const char *newline() const { return indent.empty() ? "" : "\n"; }

	// [items], each item written at depth + 1.
	template <typename Write>
	void list(std::string &out, size_t count, int depth, Write write) const {
		if (count == 0) {
			out += "[]";
			return;
		}
		out += '[';
		out += newline();
		for (size_t index = 0; index < count; ++index) {
			if (index > 0) {
				out += ',';
				out += newline();
			}
			pad(out, depth + 1);
			write(index);
		}
		out += newline();
		pad(out, depth);
		out += ']';
	}

	void write(std::string &out, const state::Value &value, int depth) const;

	std::string text(const state::Value &value, int depth = 0) const {
		std::string out;
		write(out, value, depth);
		return out;
	}
};

} // namespace aurelion::rules::compat
