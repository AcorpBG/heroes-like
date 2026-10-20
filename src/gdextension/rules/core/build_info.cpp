#include "aurelion_rules/build_info.hpp"

#include "aurelion_rules_source_tree.hpp"

#ifndef AURELION_GODOT_CPP_COMMIT
#define AURELION_GODOT_CPP_COMMIT "unknown"
#endif

#define AURELION_STRINGIFY_INNER(value) #value
#define AURELION_STRINGIFY(value) AURELION_STRINGIFY_INNER(value)

namespace aurelion::rules {

BuildInfo build_info() {
	BuildInfo info;
	info.source_tree = AURELION_RULES_SOURCE_TREE;
	info.godot_cpp = AURELION_GODOT_CPP_COMMIT;
#if defined(_MSC_VER) && !defined(__clang__)
	info.compiler = "msvc " AURELION_STRINGIFY(_MSC_FULL_VER);
#elif defined(__clang__)
	info.compiler = "clang " __clang_version__;
#elif defined(__MINGW64__)
	info.compiler = "mingw-gcc " __VERSION__;
#elif defined(__GNUC__)
	info.compiler = "gcc " __VERSION__;
#else
	info.compiler = "unknown";
#endif
	return info;
}

} // namespace aurelion::rules
