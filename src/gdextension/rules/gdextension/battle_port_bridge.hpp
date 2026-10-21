#pragma once

// One call of a ported battle function from GDScript (BattleEngine.gd).
//
// load() turns the arguments into Values without converting them: an Array or
// Dictionary becomes a backed node that reads its source container one value
// at a time, and is filled from it only when the native code needs it whole.
// A container reached twice is one node.
//
// export_value() turns the result into a Variant: a node loaded from a
// container is that container, so is_same() holds as it would in GDScript; a
// node the native code made becomes a new container. write_back() writes the
// loaded containers the native code changed back into themselves.
//
// The host services: an opaque object's properties are read with Object::get,
// a RandomNumberGenerator's seed and state through its methods, and content
// rows from the ContentService autoload, loaded as the containers they are.
// A row or document is asked for once per call: within a call no GDScript
// runs, so ContentService would return the same object again. Its empty
// results (an unknown id, a missing file) and a scenario's terrain layers are
// new objects each time, so they are asked for again.
//
// diff() compares the native result with GDScript's: the same types (int and
// float, String and StringName apart), the same key order, typing and
// read-only flags, and the same container identities: a loaded container
// must be GDScript's very object, a new one must not be a loaded one, and a
// node reached twice must be one object there too.

#include "aurelion_rules/battle_state.hpp"

#include <godot_cpp/variant/array.hpp>
#include <godot_cpp/variant/dictionary.hpp>
#include <godot_cpp/variant/string_name.hpp>
#include <godot_cpp/variant/variant.hpp>

#include <cstdint>
#include <optional>
#include <string>
#include <unordered_map>
#include <vector>

namespace aurelion::rules::bridge {

// Shadow, for a function that writes into its arguments: a copy of them as the
// GDScript call finds them, for the native run (BattleEngine.before_writing).
// Unlike args.duplicate(true), a container reached twice is one copy, as the
// original is one object; a RandomNumberGenerator is a new one with the same
// seed and state; an object with a script (the session) is a new instance of
// its script with every script variable copied the same way. A Dictionary's
// keys and any other object are shared.
godot::Array copy_for_shadow(const godot::Array &args);

class PortBridge : public state::Backing {
public:
	PortBridge();

	// Starts a call: drops the last call's nodes and sources.
	void begin();
	state::State &state() { return state_; }

	state::Value load(const godot::Variant &value);
	godot::Variant export_value(const state::Value &value);
	void write_back();
	// A loaded container the native code wrote into.
	bool changed_a_source() const;
	// "" when the native value is GDScript's.
	std::string diff(const state::Value &native, const godot::Variant &gdscript);

	void fill_array(state::State &state, uint32_t node) override;
	void fill_dict(state::State &state, uint32_t node) override;
	int64_t array_size(uint32_t node) override;
	state::Value array_at(state::State &state, uint32_t node, int64_t index) override;
	int64_t dict_size(uint32_t node) override;
	bool dict_lookup(state::State &state, uint32_t node, const state::Value &key, state::Value &out) override;

	state::Value object_get(state::State &state, uint32_t slot, uint32_t property) override;
	bool rng_get(uint32_t slot, uint64_t &seed, uint64_t &state) override;
	void rng_set_state(uint32_t slot, uint64_t state) override;
	uint32_t rng_new(uint64_t seed, uint64_t state) override;
	state::Value content_row(state::State &state, state::ContentTable table, uint32_t id) override;
	state::Value content_file(state::State &state, uint32_t path) override;
	void print_error(const std::string &text) override;
	void print_warning(const std::string &text) override;

private:
	struct TypeInfo {
		uint32_t builtin = 0;
		godot::StringName class_name;
		godot::Variant script;
	};

	state::Value load_string(const godot::String &text, state::Kind kind);
	state::TypeRef register_type(int64_t builtin, const godot::StringName &class_name, const godot::Variant &script);
	godot::Object *object_at(uint32_t slot) const;
	godot::Object *content_service();
	const godot::Variant &string_variant(uint32_t atom, bool name);
	godot::Variant key_variant(const state::Value &key);
	godot::Array fresh_array(const state::ArrayNode &node) const;
	godot::Dictionary fresh_dict(const state::DictNode &node) const;
	bool same_type(state::TypeRef type, int64_t builtin, const godot::StringName &class_name, const godot::Variant &script) const;
	void diff_value(const state::Value &native, const godot::Variant &gdscript, std::string &path, std::string &out);

	state::State state_;
	// The container each loaded node reads, by node; none for the native's own.
	std::vector<std::optional<godot::Array>> array_sources_;
	std::vector<std::optional<godot::Dictionary>> dict_sources_;
	std::unordered_map<uint64_t, uint32_t> array_nodes_;
	std::unordered_map<uint64_t, uint32_t> dict_nodes_;
	std::vector<godot::Variant> opaque_;
	godot::ObjectID content_service_;
	// Per call: the content rows and documents loaded, by table and id atom.
	std::unordered_map<uint64_t, state::Value> content_;
	std::vector<TypeInfo> types_; // TypeRef n is types_[n - 1]; kept across calls
	std::vector<godot::Variant> string_cache_;
	std::vector<godot::Variant> name_cache_;
	// Per export: the Variant each new node became, so a node is one object.
	std::unordered_map<uint32_t, godot::Variant> exported_arrays_;
	std::unordered_map<uint32_t, godot::Variant> exported_dicts_;
	// Per diff: the GDScript object each new node was matched with.
	std::unordered_map<uint32_t, uint64_t> matched_arrays_;
	std::unordered_map<uint32_t, uint64_t> matched_dicts_;
};

} // namespace aurelion::rules::bridge
