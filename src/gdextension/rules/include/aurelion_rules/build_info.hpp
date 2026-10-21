#pragma once

// What a rules build was made from, so match and tuner records can name it.

#include <string>

namespace aurelion::rules {

// Raised by every change to the native API the game calls.
constexpr int kRulesApiVersion = 2;

struct BuildInfo {
	std::string source_tree; // git tree id of src/gdextension/rules
	std::string godot_cpp; // godot-cpp commit
	std::string compiler; // e.g. "msvc 194435217", "gcc 13.3.0"
};

BuildInfo build_info();

} // namespace aurelion::rules
