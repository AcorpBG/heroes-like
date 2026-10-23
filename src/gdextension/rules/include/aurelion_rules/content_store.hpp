#pragma once

// The native content tables (docs/native-rules-engine-transition.md, Phase 7,
// slice 7.10): ContentService's files, parsed by the engine's own JSON.parse
// (compat/godot_json.hpp), and its lookups by id. Every node is read-only, as
// the content GDScript reads is. The host hands in the files' bytes (the
// adapter through FileAccess, a runner from disk). Not thread-safe: files load
// on first use.

#include "aurelion_rules/battle_state.hpp"

#include <cstdint>
#include <memory>
#include <string>
#include <unordered_map>
#include <vector>

namespace aurelion::rules::content {

// res:// paths ContentService names (its constants).
inline constexpr const char *kContentDir = "res://content";
inline constexpr const char *kArchiveDir = "res://archive/authored-scenarios-2026-10-08";
inline constexpr const char *kScenariosPath = "res://archive/authored-scenarios-2026-10-08/scenarios.json";
inline constexpr const char *kEncountersPath = "res://content/encounters.json";
inline constexpr const char *kGeneratedCompaniesPath = "res://content/generated_neutral_companies.json";
inline constexpr const char *kGeneratedCompanyEncounterPrefix = "encounter_company_";
inline constexpr const char *kHeroesPath = "res://content/heroes.json";
inline constexpr const char *kHeroArtPath = "res://content/hero_art_manifest.json";
inline constexpr const char *kFactionsPath = "res://content/factions.json";
inline constexpr const char *kFactionCrestsPath = "res://content/faction_crests.json";
inline constexpr const char *kUnitsPath = "res://content/units.json";
inline constexpr const char *kUnitArtPath = "res://content/unit_art_manifest.json";
inline constexpr const char *kUnitAnimationPath = "res://content/unit_animation_manifest.json";
inline constexpr const char *kArmyGroupsPath = "res://content/army_groups.json";
inline constexpr const char *kTownsPath = "res://content/towns.json";
inline constexpr const char *kBuildingsPath = "res://content/buildings.json";
inline constexpr const char *kBuildingArtPath = "res://content/building_art_manifest.json";
inline constexpr const char *kResourcesPath = "res://content/resources.json";
inline constexpr const char *kResourceSitesPath = "res://content/resource_sites.json";
inline constexpr const char *kBiomesPath = "res://content/biomes.json";
inline constexpr const char *kTerrainGrammarPath = "res://content/terrain_grammar.json";
inline constexpr const char *kTerrainLayersPath = "res://archive/authored-scenarios-2026-10-08/terrain_layers.json";
inline constexpr const char *kMapObjectsPath = "res://content/map_objects.json";
inline constexpr const char *kNeutralDwellingsPath = "res://content/neutral_dwellings.json";
inline constexpr const char *kArtifactsPath = "res://content/artifacts.json";
inline constexpr const char *kSpellsPath = "res://content/spells.json";
inline constexpr const char *kSpellIconsPath = "res://content/spell_icons.json";
inline constexpr const char *kSpellSchoolIconsPath = "res://content/spell_school_icons.json";
inline constexpr const char *kBuildingCategoryIconsPath = "res://content/building_category_icons.json";
inline constexpr const char *kCampaignsPath = "res://archive/authored-scenarios-2026-10-08/campaigns.json";
inline constexpr const char *kAiHeroWeightsPath = "res://content/ai_hero_weights.json";

// The host's files.
class Files {
public:
	virtual ~Files() = default;
	// FileAccess.file_exists(path).
	virtual bool exists(const std::string &path) = 0;
	// The file's bytes; false when it cannot be opened.
	virtual bool read(const std::string &path, std::string &bytes) = 0;
	// ResourceLoader.exists(path), for the art the content names.
	virtual bool resource_exists(const std::string &path) = 0;
	// OS.has_feature("editor").
	virtual bool editor() = 0;
};

// A message ContentService prints: push_error, or push_warning.
struct Message {
	bool error = true;
	std::string text;
};

class Store {
public:
	explicit Store(std::shared_ptr<Files> files);
	Store(const Store &) = delete;
	Store &operator=(const Store &) = delete;

	// Every node of the tables, read-only.
	const state::State &data() const { return data_; }
	// The content revision: it moves with every reload, override and
	// generated draft (get_content_revision).
	int64_t revision() const { return revision_; }
	void bump_revision() { ++revision_; }
	// Moves when data() is rebuilt (clear_cache), which renumbers its nodes.
	uint64_t generation() const { return generation_; }

	// load_json(path): the document (an Array root wrapped as {"items": ...}),
	// or Nil for load_json's {} after a failure, whose push_error goes into
	// messages. A failure is not kept: the next call tries again.
	state::Value load_json(const std::string &path, std::vector<Message> &messages);

	// get_content_by_id(path, id, list_key): the first row of the list with
	// that id (the towns by their canonical id), or Nil.
	state::Value content_by_id(const std::string &path, const std::string &id, const std::string &list_key, std::vector<Message> &messages);
	// _indexed_content_row(path, id, list_key, id_field): the first row whose
	// id_field (else "id") is id as text.
	state::Value indexed_row(const std::string &path, const std::string &id, const std::string &list_key, const std::string &id_field, std::vector<Message> &messages);
	// get_encounter(id): encounters.json, else a generated company's.
	state::Value encounter(const std::string &id, std::vector<Message> &messages);
	// get_content_ids(path, list_key).
	std::vector<std::string> content_ids(const std::string &path, const std::string &list_key, std::vector<Message> &messages);
	// canonical_town_id(id).
	std::string canonical_town_id(const std::string &id, std::vector<Message> &messages);
	// normalize_terrain_id(terrain_id).
	static std::string normalize_terrain_id(const std::string &terrain_id);
	// get_biome_for_terrain(terrain_id), Nil for none.
	state::Value biome_for_terrain(const std::string &terrain_id, std::vector<Message> &messages);
	// get_map_object_for_resource_site(site_id), Nil for none.
	state::Value map_object_for_resource_site(const std::string &site_id, std::vector<Message> &messages);

	// set_content_override(path, data): the document is copied in by the
	// caller (copy_in), checked (the AI weights against the shipped file) and
	// replaces the file for this run; the revision moves. False and the
	// refusals in messages when it is refused.
	bool set_override(const std::string &path, const state::Value &document, std::vector<Message> &messages);
	// clear_content_overrides().
	void clear_overrides();
	// clear_cache(): every file read again on next use.
	void clear_cache();

	// The State the caller builds an override document in before set_override.
	state::State &scratch() { return data_; }

	// _validate_content's checks of the live content (core/content_validate.cpp):
	// what ContentService prints at start-up about the shipped files, into
	// messages. A failure that ends them throws, after what came before it.
	void validate(std::vector<Message> &messages);

	// ai_hero_weights_errors(doc, shipped), on two Dicts of data() (shipped Nil
	// for none).
	std::vector<std::string> ai_hero_weights_errors(const state::Value &doc, const state::Value &shipped);

private:
	struct Index {
		// The items it was built from.
		state::Value items;
		std::unordered_map<uint32_t, state::Value> by_id;
	};

	state::Value parse_file(const std::string &path, std::vector<Message> &messages);
	state::Value items_from_raw(const state::Value &raw, const std::string &list_key);
	const Index &index(const std::string &path, const std::string &list_key, const std::string &id_field, const state::Value &raw);
	std::string id_text(const state::Value &value, const char *what);
	void freeze_from(size_t arrays, size_t dicts);

	std::shared_ptr<Files> files_;
	state::State data_;
	int64_t revision_ = 0;
	uint64_t generation_ = 0;
	// load_json's cache and the overrides, by path.
	std::unordered_map<std::string, state::Value> cache_;
	std::unordered_map<std::string, state::Value> overrides_;
	std::unordered_map<std::string, Index> indexes_;
	bool biome_index_built_ = false;
	bool biome_indexed_ = false;
	state::Value biome_items_;
	std::unordered_map<uint32_t, state::Value> biome_by_terrain_;
	bool site_index_built_ = false;
	std::unordered_map<uint32_t, state::Value> object_by_site_;
};

} // namespace aurelion::rules::content
