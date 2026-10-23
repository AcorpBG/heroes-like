#pragma once

// The map library's generation without Godot (Phase 8, P8-8;
// docs/native-rules-engine-transition.md): MapPackageService's
// normalize_random_map_config, generate_random_map, convert_generated_payload,
// save_map_package and save_scenario_package and what they call
// (src/gdextension/src/map_package_service.cpp), over the H3MapEd generator
// core (src/gdextension/src/h3maped_rmg_*.cpp, its own library here), for a
// host without Godot (match_sim_cli). The map library keeps its copy for the
// game, the editor and the tools: a change to the projection, the package
// writes or their checks goes into both copies in the same commit.
//
// The content catalogs the projection reads (map objects, resource sites,
// artifacts, the reward proxy catalog, the object eligibility registry) come
// from files, through the engine's JSON parse, as FileAccess and JSON give them
// to the map library. The packages go to files (content::Files::write) as
// JSON.stringify(package, "\t", true) writes them; the map library's package
// browser cache (user://package_browser_manifest_cache_v1) is not written.

#include "aurelion_rules/battle_state.hpp"
#include "aurelion_rules/content_store.hpp"
#include "aurelion_rules/map_packages.hpp"

#include <memory>
#include <string>

namespace aurelion::rules::map_generation {

// The host's documents: the opaque values it keeps a MapDocument or a
// ScenarioDocument behind, as for the package loads (map_packages.hpp).
class Documents {
public:
	virtual ~Documents() = default;
	// A new document: the host's value for it, with the document in out.
	virtual state::Value new_map_document(map_packages::MapDocument *&out) = 0;
	virtual state::Value new_scenario_document(map_packages::ScenarioDocument *&out) = 0;
	// The document value stands for, or nullptr.
	virtual map_packages::MapDocument *map_document(const state::Value &value) = 0;
	virtual map_packages::ScenarioDocument *scenario_document(const state::Value &value) = 0;
};

// What the generator's last run gave: the map library keeps one per process
// (GeneratedCore), so the next generation with the same generator inputs and
// other factions skips the workflow and says generator_core_reused. A host
// keeps one per thread of matches.
class GeneratorCache {
public:
	GeneratorCache();
	~GeneratorCache();
	GeneratorCache(const GeneratorCache &) = delete;
	GeneratorCache &operator=(const GeneratorCache &) = delete;

	struct Core;
	std::shared_ptr<const Core> last;
};

// MapPackageService.normalize_random_map_config(config).
state::Value normalize_random_map_config(state::State &state, const state::Value &config);

// MapPackageService.generate_random_map(config, options). The documents of a
// complete result are new ones of documents.
state::Value generate_random_map(state::State &state, content::Files &files, Documents &documents, GeneratorCache &cache,
		const state::Value &config, const state::Value &options);

// MapPackageService.convert_generated_payload(generated_map, options).
state::Value convert_generated_payload(state::State &state, const state::Value &generated_map, const state::Value &options);

// MapPackageService.save_map_package(map_document, path, options) and
// save_scenario_package(scenario_document, path, options): the package written
// to files at path.
state::Value save_map_package(state::State &state, content::Files &files, Documents &documents, const state::Value &map_document,
		const std::string &path, const state::Value &options);
state::Value save_scenario_package(state::State &state, content::Files &files, Documents &documents,
		const state::Value &scenario_document, const std::string &path, const state::Value &options);

} // namespace aurelion::rules::map_generation
