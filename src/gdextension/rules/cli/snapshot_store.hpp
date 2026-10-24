#pragma once

// What the rules tools outside Godot share (battle_sim_cli, match_sim_cli): a
// decoded snapshot (aurelion_rules/snapshot.hpp), the type registry their
// workers' States share, and the content snapshot the game writes for them
// (tools/rules_snapshot/rules_snapshot.gd).

#include "aurelion_rules/battle_state.hpp"
#include "aurelion_rules/snapshot.hpp"

#include <cstddef>
#include <cstdint>
#include <filesystem>
#include <fstream>
#include <iterator>
#include <memory>
#include <mutex>
#include <stdexcept>
#include <string>
#include <string_view>
#include <vector>

namespace aurelion::rules::cli {

namespace snap = aurelion::rules::snapshot;
namespace st = aurelion::rules::state;

[[noreturn]] inline void fail(const std::string &text) {
	throw std::runtime_error(text);
}

inline std::vector<uint8_t> read_file(const std::filesystem::path &path) {
	std::ifstream in(path, std::ios::binary);
	if (!in) {
		fail("cannot read " + path.string());
	}
	return std::vector<uint8_t>(std::istreambuf_iterator<char>(in), std::istreambuf_iterator<char>());
}

// Every type the stores and the ported code name, one TypeRef each, shared by
// the workers' States.
class Types {
public:
	st::TypeRef ref(const snap::TypeInfo &info) {
		const std::lock_guard<std::mutex> lock(mutex_);
		for (size_t index = 0; index < types_.size(); ++index) {
			if (types_[index] == info) {
				return static_cast<st::TypeRef>(index + 1);
			}
		}
		types_.push_back(info);
		return static_cast<st::TypeRef>(types_.size());
	}
	// Registers in state the types it does not know yet (known: how many it does).
	void sync(st::State &state, size_t &known) const {
		const std::lock_guard<std::mutex> lock(mutex_);
		for (; known < types_.size(); ++known) {
			state.set_type_builtin(static_cast<st::TypeRef>(known + 1), types_[known].builtin);
		}
	}

private:
	mutable std::mutex mutex_;
	std::vector<snap::TypeInfo> types_;
};

// A decoded snapshot: read by every worker, written by none.
struct Store {
	st::State state;
	snap::Decoded decoded;
	// The snapshot's type ids (0 untyped) as the tool's TypeRefs.
	std::vector<st::TypeRef> types;

	st::Value get(const st::Value &dict, std::string_view name) const {
		uint32_t atom = 0;
		st::Value found;
		if (dict.kind == st::Kind::Dict && state.find_atom(name, atom) && state.lookup(dict.ref, st::Value::str(atom), found)) {
			return found;
		}
		return st::Value();
	}
	std::string text(const st::Value &value) const {
		return value.is_string_like() ? state.text(value.ref) : std::string();
	}
};

inline std::unique_ptr<Store> load_store(const std::filesystem::path &path, Types &types) {
	auto store = std::make_unique<Store>();
	const std::vector<uint8_t> bytes = read_file(path);
	store->decoded = snap::decode(store->state, bytes.data(), bytes.size());
	store->types.push_back(0);
	for (const snap::TypeInfo &info : store->decoded.types) {
		store->types.push_back(types.ref(info));
	}
	return store;
}

// The ContentService getters' tables, as the content snapshot names them
// (tools/rules_snapshot/rules_snapshot.gd, CONTENT_TABLES), in ContentTable's order.
inline constexpr const char *kTableNames[] = {
	"Unit",
	"Hero",
	"Faction",
	"Spell",
	"Artifact",
	"ResourceSite",
	"Building",
	"Town",
	"MapObject",
	"Encounter",
	"ArmyGroup",
	"Scenario",
	"Resource",
	"MapObjectForResourceSite",
	"BiomeForTerrain",
	"TerrainLayersForScenario",
	"UnitArt",
	"NeutralDwelling",
	"HeroArt",
	"UnitAnimation",
	"BuildingArt",
	"SpellIcon",
	"SpellSchoolIcon",
	"BuildingCategoryIcon",
	"FactionCrest",
	"Biome",
	"Campaign",
};
inline constexpr size_t kTableCount = sizeof(kTableNames) / sizeof(kTableNames[0]);
static_assert(static_cast<size_t>(st::ContentTable::Campaign) + 1 == kTableCount, "a name per content table");

// The content snapshot: {files: {path: data}, tables: {name: {id: row}},
// statics: {script path: {name: value}}, revision}.
struct Content {
	std::unique_ptr<Store> store;
	st::Value files;
	st::Value tables[kTableCount];
	st::Value statics;
};

inline Content load_content(const std::filesystem::path &path, Types &types) {
	Content content;
	content.store = load_store(path, types);
	const Store &store = *content.store;
	const st::Value root = store.decoded.root;
	content.files = store.get(root, "files");
	content.statics = store.get(root, "statics");
	const st::Value tables = store.get(root, "tables");
	if (content.files.kind != st::Kind::Dict || content.statics.kind != st::Kind::Dict || tables.kind != st::Kind::Dict) {
		fail(path.string() + " is no content snapshot: it needs files, tables and statics");
	}
	for (size_t index = 0; index < kTableCount; ++index) {
		content.tables[index] = store.get(tables, kTableNames[index]);
	}
	return content;
}

} // namespace aurelion::rules::cli
