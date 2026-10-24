#pragma once

// The map library's generation, package writes and document checks (Phase 8,
// P8-8 and the fold; docs/native-rules-engine-transition.md):
// MapPackageService's normalize_random_map_config, random_map_config_identity,
// generate_random_map, convert_generated_payload, validate_map_document,
// validate_scenario_document, save_map_package, save_scenario_package and
// compute_document_hash, over the H3MapEd generator core
// (src/gdextension/src/h3maped_rmg_*.cpp). The map library's MapPackageService
// (src/gdextension/src/map_package_service.cpp) is a thin wrapper over these,
// converting at the Godot boundary, and match_sim_cli calls them without Godot:
// this is their one copy.
//
// The content catalogs the projection reads (map objects, resource sites,
// artifacts, the reward proxy catalog, the object eligibility registry) come
// from files, through the engine's JSON parse, as FileAccess and JSON give them.
// The packages are written as JSON.stringify(package, "\t", true) writes them,
// through the host's Documents::write_package; what the host keeps beside a
// package (the map library's package browser cache) is its
// Documents::package_written.

#include "aurelion_rules/battle_state.hpp"
#include "aurelion_rules/content_store.hpp"
#include "aurelion_rules/map_packages.hpp"

#include <memory>
#include <string>
#include <string_view>

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
	// The package's JSON text written to path: nullptr, or the failure's code
	// (create_directory_failed, open_failed, write_failed, replace_failed).
	// By default files.write, which fails as open_failed.
	virtual const char *write_package(content::Files &files, const std::string &path, const std::string &json);
	// After the package at path is written: what the host keeps beside it, and
	// the payload's browser_manifest_cache_profile when cache_profile is asked
	// (Nil for none). By default nothing is kept, and a profile is NotPorted.
	virtual state::Value package_written(state::State &state, const std::string &path, const state::Value &package, bool cache_profile);
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

// MapPackageService.random_map_config_identity(config).
state::Value random_map_config_identity(state::State &state, const state::Value &config);

// MapPackageService.generate_random_map(config, options). The documents of a
// complete result are new ones of documents.
state::Value generate_random_map(state::State &state, content::Files &files, Documents &documents, GeneratorCache &cache,
		const state::Value &config, const state::Value &options);

// MapPackageService.convert_generated_payload(generated_map, options).
state::Value convert_generated_payload(state::State &state, const state::Value &generated_map, const state::Value &options);

// MapPackageService.validate_map_document(map_document) and
// validate_scenario_document(scenario_document, map_document): the structural
// reports. A null document (nullptr) is the report's failure.
state::Value validate_map_document(state::State &state, const map_packages::MapDocument *document);
state::Value validate_scenario_document(state::State &state, const map_packages::ScenarioDocument *scenario,
		const map_packages::MapDocument *map);

// MapPackageService.compute_document_hash(document): plain data only, so an
// opaque value in it (an object) fails.
state::Value compute_document_hash(state::State &state, const state::Value &document);

// "fnv1a32:" and the FNV-1a hash of value's canonical text, as the documents'
// and packages' hashes are made.
std::string document_hash(state::State &state, const state::Value &value);
// The FNV-1a hash of a text's code points, as eight hex digits (hash32_hex).
std::string text_hash(std::string_view text);

// MapPackageService.save_map_package(map_document, path, options) and
// save_scenario_package(scenario_document, path, options): the package written
// to path (Documents::write_package).
state::Value save_map_package(state::State &state, content::Files &files, Documents &documents, const state::Value &map_document,
		const std::string &path, const state::Value &options);
state::Value save_scenario_package(state::State &state, content::Files &files, Documents &documents,
		const state::Value &scenario_document, const std::string &path, const state::Value &options);

} // namespace aurelion::rules::map_generation
