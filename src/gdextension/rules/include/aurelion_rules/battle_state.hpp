#pragma once

// The battle state as GDScript holds it (docs/native-rules-engine-transition.md,
// section 4 "State"): a tree of Dictionaries, Arrays, bools, ints, floats and
// strings, kept with GDScript's key order, int/float types, unknown keys and
// shared containers. The Godot adapter converts a battle Dictionary into a
// State and writes it back into the same containers (or into new ones).
//
// Containers live in the State's pools and Values refer to them by index, so a
// container reached from two places is one node, as it is one object in Godot.
// Strings are interned: equal texts have one atom. Pool references stay valid
// while nodes are added (std::deque).

#include <cstdint>
#include <deque>
#include <string>
#include <string_view>
#include <unordered_map>
#include <vector>

namespace aurelion::rules::state {

enum class Kind : uint8_t {
	Nil,
	Bool,
	Int,
	Float,
	String,
	StringName,
	Array,
	Dict,
	// A Variant the State does not model (a Vector2i, an Object, ...): the
	// adapter keeps it and writes it back unchanged. ref is its slot there.
	Opaque,
};

struct Value {
	Kind kind = Kind::Nil;
	union {
		int64_t i;
		double f;
		uint32_t ref; // string atom, array node or dict node
		bool b;
	};

	Value() :
			i(0) {}
	static Value nil() { return Value(); }
	static Value of_bool(bool value) {
		Value v;
		v.kind = Kind::Bool;
		v.i = 0;
		v.b = value;
		return v;
	}
	static Value of_int(int64_t value) {
		Value v;
		v.kind = Kind::Int;
		v.i = value;
		return v;
	}
	static Value of_float(double value) {
		Value v;
		v.kind = Kind::Float;
		v.f = value;
		return v;
	}
	static Value of_ref(Kind kind, uint32_t ref) {
		Value v;
		v.kind = kind;
		v.i = 0;
		v.ref = ref;
		return v;
	}

	bool is_string_like() const { return kind == Kind::String || kind == Kind::StringName; }
	bool is_container() const { return kind == Kind::Array || kind == Kind::Dict; }
};

// A typed Array's or Dictionary's element type, as the adapter registered it.
// 0 means untyped; the State does not interpret other values.
using TypeRef = uint32_t;

struct ArrayNode {
	std::vector<Value> items;
	TypeRef element_type = 0;
	bool read_only = false;
};

struct DictNode {
	// Insertion order, as Dictionary.keys() returns it.
	std::vector<Value> keys;
	std::vector<Value> values;
	TypeRef key_type = 0;
	TypeRef value_type = 0;
	bool read_only = false;
};

class State {
public:
	State() = default;
	State(const State &) = delete;
	State &operator=(const State &) = delete;

	void clear();

	uint32_t intern(std::string_view text);
	// The atom of a text already interned, or false.
	bool lookup(std::string_view text, uint32_t &atom) const;
	const std::string &text(uint32_t atom) const { return atoms_[atom]; }
	size_t atom_count() const { return atoms_.size(); }

	uint32_t new_array();
	uint32_t new_dict();
	ArrayNode &array(uint32_t node) { return arrays_[node]; }
	const ArrayNode &array(uint32_t node) const { return arrays_[node]; }
	DictNode &dict(uint32_t node) { return dicts_[node]; }
	const DictNode &dict(uint32_t node) const { return dicts_[node]; }
	size_t array_count() const { return arrays_.size(); }
	size_t dict_count() const { return dicts_.size(); }

	Value string(std::string_view text) { return Value::of_ref(Kind::String, intern(text)); }

	// Dictionary semantics. A String and a StringName with the same text are one
	// key, as in Godot's Dictionary; ints match ints and floats floats.
	const Value *find(uint32_t dict_node, const Value &key) const;
	Value *find(uint32_t dict_node, const Value &key);
	Value get(uint32_t dict_node, const Value &key, const Value &fallback) const;
	// An existing key keeps its place; a new one goes last.
	void set(uint32_t dict_node, const Value &key, const Value &value);
	bool erase(uint32_t dict_node, const Value &key);

	Value root;

private:
	// A deque, so the views atom_ids_ holds stay valid.
	std::deque<std::string> atoms_;
	std::unordered_map<std::string_view, uint32_t> atom_ids_;
	std::deque<ArrayNode> arrays_;
	std::deque<DictNode> dicts_;
};

bool same_key(const Value &a, const Value &b);

} // namespace aurelion::rules::state
