#pragma once

// Converts GDScript's battle Dictionaries into the native state
// (aurelion_rules/battle_state.hpp) and back.
//
// load() reads a Variant tree. A container reached twice (the same Array or
// Dictionary object) becomes one node; typed and read-only containers keep
// their typing; a Variant type the state does not model is kept as an opaque
// slot and written back unchanged.
//
// store_in_place() writes the state back into the containers load() read, so
// GDScript's references to them stay valid, and makes new containers only for
// nodes the native side added. A Dictionary ends with the state's key order:
// when the keys it keeps are already in that order, the dropped keys are erased
// and the new ones appended; otherwise it is cleared and refilled.
//
// export_copy() writes the state into new containers with the same sharing.

#include "aurelion_rules/battle_state.hpp"

#include <godot_cpp/variant/array.hpp>
#include <godot_cpp/variant/dictionary.hpp>
#include <godot_cpp/variant/string.hpp>
#include <godot_cpp/variant/string_name.hpp>
#include <godot_cpp/variant/variant.hpp>

#include <cstdint>
#include <string>
#include <unordered_map>
#include <vector>

namespace aurelion::rules::bridge {

// The engine object an Array or Dictionary holds: two Variants hold the same
// container when these match (is_same in GDScript).
uint64_t identity_of(const godot::Array &array);
uint64_t identity_of(const godot::Dictionary &dict);
// The same for a Variant holding a packed array: the engine's PackedArrayRef,
// which every Variant holding that array shares.
uint64_t identity_of_packed(const godot::Variant &packed);
// The packed Variant of a node's elements: a new packed array.
godot::Variant packed_variant(const state::State &state, const state::PackedNode &node);
// A packed array's elements into a node (one of the State's packed kinds).
void fill_packed_node(state::State &state, state::PackedNode &node, const godot::Variant &packed);

// Writes node into dict, which ends with node's keys in node's order, as the
// exported keys and values. When the keys dict keeps are already in that
// order, the dropped ones are erased and the new ones appended; otherwise dict
// is cleared and refilled, and the answer is true.
bool fill_dict_in_place(godot::Dictionary &dict, const state::DictNode &node, const state::State &state, const std::vector<godot::Variant> &keys, const std::vector<godot::Variant> &values);

struct LoadCounts {
	int64_t values = 0;
	int64_t shared_refs = 0; // container references that reached an existing node
	int64_t by_type[godot::Variant::VARIANT_MAX] = {};
};

class StateBridge {
public:
	// Replaces the state's contents with root. False, with error(), on bad input.
	bool load(const godot::Variant &root, state::State &state);

	// Replaces the state's contents with source, matched by path against what
	// state holds now: a container in source takes over the node at its path
	// (so store_in_place writes it into the object load() read there), unless
	// that node is already taken or typed differently. The sharing follows
	// source. This is how a test plays the native side changing the state.
	bool overwrite(const godot::Variant &source, state::State &state);

	godot::Variant store_in_place(const state::State &state);
	godot::Variant export_copy(const state::State &state);

	const std::string &error() const { return error_; }
	const LoadCounts &counts() const { return counts_; }
	int64_t reused_arrays() const { return reused_arrays_; }
	int64_t reused_dicts() const { return reused_dicts_; }
	int64_t rebuilt_dicts() const { return rebuilt_dicts_; }

private:
	struct TypeInfo {
		uint32_t builtin = 0;
		godot::StringName class_name;
		godot::Variant script;
	};

	state::Value load_value(const godot::Variant &value, state::State &state);
	state::Value load_array(const godot::Array &array, state::State &state);
	state::Value load_dict(const godot::Dictionary &dict, state::State &state);
	state::Value load_string(const godot::String &text, state::Kind kind, state::State &state);
	state::TypeRef register_type(int64_t builtin, const godot::StringName &class_name, const godot::Variant &script);

	state::Value merge_value(const godot::Variant &source, const state::Value &existing, state::State &state);

	void begin_write(const state::State &state);
	const godot::Variant &string_variant(uint32_t atom, bool name, const state::State &state);
	godot::Variant write_value(const state::Value &value, const state::State &state, bool in_place);
	godot::Variant write_array(uint32_t node, const state::State &state, bool in_place);
	godot::Variant write_dict(uint32_t node, const state::State &state, bool in_place);
	godot::Array fresh_array(const state::ArrayNode &node) const;
	godot::Dictionary fresh_dict(const state::DictNode &node) const;
	bool fail(const std::string &message);

	// The containers load() read, by node; nodes added later have none.
	std::vector<godot::Array> source_arrays_;
	std::vector<godot::Dictionary> source_dicts_;
	std::unordered_map<uint64_t, uint32_t> array_nodes_;
	std::unordered_map<uint64_t, uint32_t> dict_nodes_;
	std::vector<godot::Variant> opaque_;
	std::vector<TypeInfo> types_; // TypeRef n is types_[n - 1]
	// The String and StringName of each atom, made on first write.
	std::vector<godot::Variant> string_cache_;
	std::vector<godot::Variant> name_cache_;

	// Per write: the Variant each node became, so a shared node is one object.
	std::vector<godot::Variant> written_arrays_;
	std::vector<godot::Variant> written_dicts_;
	std::vector<bool> array_written_;
	std::vector<bool> dict_written_;

	// Per overwrite: source container -> node, and the nodes already taken.
	std::unordered_map<uint64_t, uint32_t> merge_arrays_;
	std::unordered_map<uint64_t, uint32_t> merge_dicts_;
	std::vector<bool> array_taken_;
	std::vector<bool> dict_taken_;

	LoadCounts counts_;
	int64_t reused_arrays_ = 0;
	int64_t reused_dicts_ = 0;
	int64_t rebuilt_dicts_ = 0;
	std::string error_;
};

} // namespace aurelion::rules::bridge
