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

private:
	struct TypeInfo {
		uint32_t builtin = 0;
		godot::StringName class_name;
		godot::Variant script;
	};

	state::Value load_string(const godot::String &text, state::Kind kind);
	state::TypeRef register_type(int64_t builtin, const godot::StringName &class_name, const godot::Variant &script);
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
