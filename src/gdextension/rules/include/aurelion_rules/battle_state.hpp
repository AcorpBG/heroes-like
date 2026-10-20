#pragma once

// The battle state as GDScript holds it (docs/native-rules-engine-transition.md,
// section 4 "State"): a tree of Dictionaries, Arrays, bools, ints, floats and
// strings, kept with GDScript's key order, int/float types, unknown keys and
// shared containers. The Godot adapter converts a battle Dictionary into a
// State and writes it back into the same containers (or into new ones).
//
// Containers live in the State's pools and Values refer to them by index, so a
// container reached from two places is one node, as it is one object in Godot.
// Strings are interned: equal texts have one atom, and the texts the port
// names in code (battle_keys.inc) have fixed atoms. Pool references stay valid
// while nodes are added (std::deque).
//
// A node can be backed: its contents still live in the adapter's container and
// are read from there one value at a time, until something needs the whole
// node (a write, an iteration, raw access), which fills it first. Per-call
// checks of the port read the game's Dictionaries this way without converting
// the battle.

#include <cstdint>
#include <deque>
#include <stdexcept>
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
	Vector2i,
	Array,
	Dict,
	// A Variant the State does not model (an Object, a Vector2, ...): the
	// adapter keeps it and writes it back unchanged. ref is its slot there.
	Opaque,
};

struct Value {
	Kind kind = Kind::Nil;
	union {
		int64_t i;
		double f;
		uint32_t ref; // string atom, array node, dict node or opaque slot
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
	static Value str(uint32_t atom) { return of_ref(Kind::String, atom); }
	static Value of_vector2i(int32_t x, int32_t y) {
		Value v;
		v.kind = Kind::Vector2i;
		v.i = static_cast<int64_t>(static_cast<uint64_t>(static_cast<uint32_t>(x)) | (static_cast<uint64_t>(static_cast<uint32_t>(y)) << 32));
		return v;
	}
	int32_t vx() const { return static_cast<int32_t>(static_cast<uint32_t>(static_cast<uint64_t>(i))); }
	int32_t vy() const { return static_cast<int32_t>(static_cast<uint32_t>(static_cast<uint64_t>(i) >> 32)); }

	bool is_string_like() const { return kind == Kind::String || kind == Kind::StringName; }
	bool is_container() const { return kind == Kind::Array || kind == Kind::Dict; }
};

// The fixed atoms of battle_keys.inc: key::hex is the atom of "hex".
namespace key {
enum : uint32_t {
#define AURELION_KEY(name, text) name,
#include "aurelion_rules/battle_keys.inc"
#undef AURELION_KEY
	known_count,
};
} // namespace key

// Where GDScript would stop with a runtime error (a bad conversion, an index
// out of range): the port throws it and the caller reports it.
class ScriptError : public std::runtime_error {
public:
	using std::runtime_error::runtime_error;
};

// A typed Array's or Dictionary's element type, as the adapter registered it.
// 0 means untyped; the State does not interpret other values.
using TypeRef = uint32_t;

struct ArrayNode {
	std::vector<Value> items;
	TypeRef element_type = 0;
	bool read_only = false;
	bool backed = false;
	// Written since it was made or loaded: set(), erase(), append().
	bool dirty = false;
};

struct DictNode {
	// Insertion order, as Dictionary.keys() returns it.
	std::vector<Value> keys;
	std::vector<Value> values;
	TypeRef key_type = 0;
	TypeRef value_type = 0;
	bool read_only = false;
	bool backed = false;
	bool dirty = false;
};

class State;

// The contents of backed nodes (the Godot adapter's containers).
class Backing {
public:
	virtual ~Backing() = default;
	// Fill the node from its container; the State clears the backed flag.
	virtual void fill_array(State &state, uint32_t node) = 0;
	virtual void fill_dict(State &state, uint32_t node) = 0;
	virtual int64_t array_size(uint32_t node) = 0;
	virtual Value array_at(State &state, uint32_t node, int64_t index) = 0;
	virtual int64_t dict_size(uint32_t node) = 0;
	virtual bool dict_lookup(State &state, uint32_t node, const Value &key, Value &out) = 0;
};

class State {
public:
	State();
	State(const State &) = delete;
	State &operator=(const State &) = delete;

	// Drops everything; the known keys keep their atoms.
	void clear();
	// Drops the nodes and the root, keeps the atoms.
	void clear_nodes();

	uint32_t intern(std::string_view text);
	// The atom of a text already interned, or false.
	bool find_atom(std::string_view text, uint32_t &atom) const;
	const std::string &text(uint32_t atom) const { return atoms_[atom]; }
	size_t atom_count() const { return atoms_.size(); }
	Value string(std::string_view text) { return Value::str(intern(text)); }

	uint32_t new_array();
	uint32_t new_dict();
	size_t array_count() const { return arrays_.size(); }
	size_t dict_count() const { return dicts_.size(); }

	// The whole node; a backed node is filled first.
	ArrayNode &array(uint32_t node) const;
	DictNode &dict(uint32_t node) const;
	// The node as it is, backed or not (for the adapter).
	ArrayNode &array_node(uint32_t node) const { return arrays_[node]; }
	DictNode &dict_node(uint32_t node) const { return dicts_[node]; }

	void set_backing(Backing *backing) { backing_ = backing; }

	// Dictionary semantics. A String and a StringName with the same text are one
	// key, as in Godot's Dictionary; ints match ints and floats floats.
	bool lookup(uint32_t dict_node, const Value &key, Value &out) const;
	bool has(uint32_t dict_node, const Value &key) const;
	Value get(uint32_t dict_node, const Value &key, const Value &fallback) const;
	int64_t dict_size(uint32_t dict_node) const;
	// An existing key keeps its place; a new one goes last.
	void set(uint32_t dict_node, const Value &key, const Value &value);
	bool erase(uint32_t dict_node, const Value &key);

	// Array semantics. at() takes GDScript's negative indices; out of range is a
	// ScriptError.
	int64_t array_size(uint32_t array_node) const;
	Value at(uint32_t array_node, int64_t index) const;
	void append(uint32_t array_node, const Value &value);

	Value root;

private:
	// Deques, so references and the views atom_ids_ holds stay valid.
	std::deque<std::string> atoms_;
	std::unordered_map<std::string_view, uint32_t> atom_ids_;
	mutable std::deque<ArrayNode> arrays_;
	mutable std::deque<DictNode> dicts_;
	Backing *backing_ = nullptr;
};

bool same_key(const Value &a, const Value &b);

} // namespace aurelion::rules::state
