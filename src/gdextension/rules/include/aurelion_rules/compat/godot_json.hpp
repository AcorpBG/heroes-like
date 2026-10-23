#pragma once

// Godot 4.6.2's JSON.parse, bit for bit (core/io/json.cpp and
// core/string/ustring.cpp of the 4.6.2-stable tag, MIT): the text as
// FileAccess.get_as_text() decodes a file's bytes, every number a float through
// the engine's own strtod (not correctly rounded), Dictionaries in the text's
// order with a repeated key overwriting the first in its place, and the
// engine's error line and message. Fuzzed against the engine by
// tools/rules_compat/capture_vectors.gd and rules_selftest.

#include "aurelion_rules/battle_state.hpp"

#include <string>
#include <string_view>

namespace aurelion::rules::compat {

// JSON.new().parse(text): error is the engine's Error (0 OK, 6 when the text
// nests deeper than Variant::MAX_RECURSION_DEPTH, 43 for any other failure),
// error_line and error_message are get_error_line() and get_error_message()
// (the line counts from 0 and is 0 after a success), and data is get_data():
// Nil after a failure.
struct JsonParse {
	int error = 0;
	int error_line = 0;
	std::string error_message;
	state::Value data;
};

// The file's bytes as get_as_text() makes them a String (String::append_utf8):
// a leading byte order mark skipped and the text cut at the first NUL byte. Text
// the engine would decode with replacement characters (malformed UTF-8) is not
// ported: NotPorted.
JsonParse json_parse(state::State &state, std::string_view utf8);

// String::to_float(const char32_t *, const char32_t **), the engine's
// built_in_strtod: the number at text and, in end, where it stops.
double to_float(const char32_t *text, const char32_t **end);

} // namespace aurelion::rules::compat
