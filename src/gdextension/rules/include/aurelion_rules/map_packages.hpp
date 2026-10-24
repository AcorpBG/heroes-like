#pragma once

// The map library's package loads and documents (Phase 8, P8-7 and the fold;
// docs/native-rules-engine-transition.md): MapPackageService.load_map_package
// and load_scenario_package, which the map library's MapPackageService
// (src/gdextension/src/map_package_service.cpp) is a thin wrapper over, and
// the methods of the MapDocument and ScenarioDocument they make, for a host
// without Godot (match_sim_cli). A host keeps each document behind an opaque
// value of its own and answers the document's methods with its call(). The map
// library's MapDocument and ScenarioDocument (map_document.cpp,
// scenario_document.cpp) keep their own methods: a change to one goes into both
// copies in the same commit.

#include "aurelion_rules/battle_state.hpp"
#include "aurelion_rules/content_store.hpp"

#include <cstdint>
#include <string>
#include <string_view>

namespace aurelion::rules::map_packages {

// A MapDocument's state, as configure() keeps it: the texts as Strings, the
// containers its own copies (metadata the package's).
struct MapDocument {
	state::Value map_id;
	state::Value map_hash;
	state::Value source_kind;
	int32_t width = 0;
	int32_t height = 0;
	int32_t level_count = 1;
	state::Value metadata;
	state::Value terrain_layers;
	state::Value route_graph;
	state::Value objects;
};

// A ScenarioDocument's state, as configure() keeps it.
struct ScenarioDocument {
	state::Value scenario_id;
	state::Value scenario_hash;
	state::Value map_ref;
	state::Value selection;
	state::Value player_slots;
	state::Value objectives;
	state::Value script_hooks;
	state::Value enemy_factions;
	state::Value start_contract;
};

// The map library's package_failure(operation, path, code, message) and
// package_success(operation, path, payload) results; the payload, built for
// the result alone, becomes it.
state::Value package_failure(state::State &state, const char *operation, const std::string &path, const char *code, const char *message);
state::Value package_success(state::State &state, const char *operation, const std::string &path, const state::Value &payload);

// MapDocument.configure(initial) (copy_containers) and the map library's
// configure_owned (not), and ScenarioDocument.configure(initial).
void configure_map_document(state::State &state, MapDocument &document, const state::Value &initial, bool copy_containers);
void configure_scenario_document(state::State &state, ScenarioDocument &document, const state::Value &initial);

// The map library's read_package_dictionary(operation, path): true with the
// parsed package, or false with the failure result. The file comes from files.
bool read_package_dictionary(state::State &state, content::Files &files, const char *operation, const std::string &path, state::Value &package,
		state::Value &failure);

// MapPackageService.load_map_package(path) and load_scenario_package(path):
// the result Dictionary. The file comes from files (FileAccess in the game).
// On success the document is configured from the package and the result's
// map_document or scenario_document is document_object, the host's value for
// it.
state::Value load_map_package(state::State &state, content::Files &files, const std::string &path, MapDocument &document,
		const state::Value &document_object);
state::Value load_scenario_package(state::State &state, content::Files &files, const std::string &path, ScenarioDocument &document,
		const state::Value &document_object);

// Whether the class binds the method, and the method's answer. A method it
// binds that this port leaves out (get_objects_in_rect) is NotPorted, one it
// does not bind a ScriptError.
bool map_document_has_method(std::string_view method);
state::Value map_document_call(state::State &state, MapDocument &document, std::string_view method, const state::Value *args, size_t count);
bool scenario_document_has_method(std::string_view method);
state::Value scenario_document_call(state::State &state, ScenarioDocument &document, std::string_view method, const state::Value *args,
		size_t count);

} // namespace aurelion::rules::map_packages
