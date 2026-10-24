#pragma once

// The map library's way into the rules core's package code (Phase 8, the fold;
// docs/native-rules-engine-transition.md): MapPackageService's package loads,
// projection, writes and checks are the core's (aurelion_rules/map_packages.hpp
// and map_generation.hpp), which match_sim_cli runs too. A CoreCall is one
// service call: Godot values go into its State, the core works there, and its
// answer comes back as Godot values. A container the core left unchanged comes
// back as the Godot one it came from, and one it changed is refilled in place,
// so the answer shares what the core's shares; a document comes back as the
// MapDocument or ScenarioDocument it stands for, a new one for each document
// the core made.

#include "map_document.hpp"
#include "scenario_document.hpp"

#include "aurelion_rules/battle_state.hpp"
#include "aurelion_rules/content_store.hpp"
#include "aurelion_rules/map_generation.hpp"
#include "aurelion_rules/map_packages.hpp"

#include <godot_cpp/variant/dictionary.hpp>
#include <godot_cpp/variant/packed_byte_array.hpp>
#include <godot_cpp/variant/string.hpp>
#include <godot_cpp/variant/variant.hpp>

#include <cstdint>
#include <deque>
#include <string>
#include <unordered_map>
#include <vector>

namespace aurelion::map_bridge {

namespace st = aurelion::rules::state;
namespace mp = aurelion::rules::map_packages;

std::string utf8(const godot::String &text);

// The directory path is in, made when missing (true when it exists after).
bool ensure_parent_dir(const godot::String &path);
// bytes written beside path and renamed over it only after a checked write, so
// a crash or a full disk never truncates the previous file: nullptr, or the
// failure's code (open_failed, write_failed, replace_failed).
const char *replace_file(const godot::String &path, const godot::PackedByteArray &bytes);

// res:// and user:// files through FileAccess and ResourceLoader, as the map
// library read them.
class GodotFiles final : public rules::content::Files {
public:
	bool exists(const std::string &path) override;
	bool read(const std::string &path, std::string &bytes) override;
	bool resource_exists(const std::string &path) override;
	bool editor() override;
};

class CoreCall final : public st::Backing, public rules::map_generation::Documents {
public:
	CoreCall();
	CoreCall(const CoreCall &) = delete;
	CoreCall &operator=(const CoreCall &) = delete;

	st::State &state() { return state_; }
	GodotFiles &files() { return files_; }

	// A Godot value into the State (a null object is Nil), and a State value
	// back out.
	st::Value in(const godot::Variant &value);
	godot::Variant out(const st::Value &value);
	godot::Dictionary out_dict(const st::Value &value) { return out(value); }
	st::Value text(const godot::String &value);

	// map_generation::Documents: a MapDocument or ScenarioDocument that came in
	// is read into the core's document the first time the core asks for it.
	st::Value new_map_document(mp::MapDocument *&document) override;
	st::Value new_scenario_document(mp::ScenarioDocument *&document) override;
	mp::MapDocument *map_document(const st::Value &value) override;
	mp::ScenarioDocument *scenario_document(const st::Value &value) override;
	// write_package_dictionary's checked write beside the target, renamed over
	// it, and the package browser cache it fills.
	const char *write_package(rules::content::Files &files, const std::string &path, const std::string &json) override;
	st::Value package_written(st::State &state, const std::string &path, const st::Value &package, bool cache_profile) override;

	// Backing: the State holds no backed nodes.
	void fill_array(st::State &state, uint32_t node) override;
	void fill_dict(st::State &state, uint32_t node) override;
	int64_t array_size(uint32_t node) override;
	st::Value array_at(st::State &state, uint32_t node, int64_t index) override;
	int64_t dict_size(uint32_t node) override;
	bool dict_lookup(st::State &state, uint32_t node, const st::Value &key, st::Value &found) override;
	void print_error(const std::string &text) override;
	void print_warning(const std::string &text) override;

private:
	// An opaque value: an object or a Variant the State does not model, which
	// goes back out as it came in, or a document the core made, whose object is
	// made when it goes out.
	struct Opaque {
		godot::Variant object;
		mp::MapDocument *map = nullptr;
		mp::ScenarioDocument *scenario = nullptr;
	};

	st::Value in_object(const godot::Variant &value);
	st::Value in_array(const godot::Array &array);
	st::Value in_dict(const godot::Dictionary &dict);
	st::Value in_packed(const godot::Variant &packed, st::Kind kind);
	godot::Variant out_string(uint32_t atom);
	godot::Variant out_array(uint32_t node);
	godot::Variant out_dict_node(uint32_t node);
	godot::Variant out_packed(const st::Value &value);
	godot::Variant out_opaque(uint32_t slot);

	st::State state_;
	GodotFiles files_;
	std::deque<mp::MapDocument> maps_;
	std::deque<mp::ScenarioDocument> scenarios_;
	std::vector<Opaque> opaques_;
	// The node or slot each Godot container, packed array and object went in
	// as, by its identity.
	std::unordered_map<uint64_t, uint32_t> in_arrays_;
	std::unordered_map<uint64_t, uint32_t> in_dicts_;
	std::unordered_map<uint64_t, uint32_t> in_packeds_;
	std::unordered_map<uint64_t, uint32_t> in_objects_;
	// The Godot value each node came from or went out as; it stands for the
	// node while the node is clean.
	std::unordered_map<uint32_t, godot::Variant> out_arrays_;
	std::unordered_map<uint32_t, godot::Variant> out_dicts_;
	std::unordered_map<uint32_t, godot::Variant> out_packeds_;
	std::vector<godot::Variant> strings_;
};

// The browser manifest cache the map library keeps beside each package it
// writes or inspects (map_package_service.cpp), filled after a package is
// written: its browser_manifest_cache_profile.
godot::Dictionary write_package_browser_manifest_cache(const godot::String &path, const godot::Dictionary &package);

} // namespace aurelion::map_bridge
