#pragma once

// GDScript's semantics over the native state, for the battle port: the
// conversions, comparisons and container operations the ported functions use,
// as Godot 4.6.2 runs them (core/variant/variant_construct.*, variant_op.h,
// variant_utility.cpp, dictionary.cpp, array.cpp). A case GDScript stops on
// with a runtime error throws state::ScriptError.

#include "aurelion_rules/battle_state.hpp"
#include "aurelion_rules/compat/godot_math.hpp"

#include <cstdint>
#include <string>
#include <vector>

namespace aurelion::rules::gd {

using state::Kind;
using state::State;
using state::Value;
namespace key = state::key;

// A Dictionary, an Array or a String by node index or atom, where the GDScript
// parameter or return type says which.
using DictRef = uint32_t;
using ArrayRef = uint32_t;
using Atom = uint32_t;

inline Value dict_value(DictRef dict) { return Value::of_ref(Kind::Dict, dict); }
inline Value array_value(ArrayRef array) { return Value::of_ref(Kind::Array, array); }
inline Value str(Atom atom) { return Value::str(atom); }
inline Value int_value(int64_t value) { return Value::of_int(value); }
inline Value float_value(double value) { return Value::of_float(value); }
inline Value bool_value(bool value) { return Value::of_bool(value); }

// Godot's type name of a value (Variant::get_type_name).
const char *type_name(const Value &value);

inline bool is_dict(const Value &value) { return value.kind == Kind::Dict; }
inline bool is_array(const Value &value) { return value.kind == Kind::Array; }
inline bool is_vector2i(const Value &value) { return value.kind == Kind::Vector2i; }

// The cases the inline helpers below leave to gd.cpp: the errors, and int() of
// anything but an int.
[[noreturn]] void not_a_dict(const Value &value);
[[noreturn]] void not_an_array(const Value &value);
[[noreturn]] void not_a_string(const Value &value);
int64_t to_int_other(const State &state, const Value &value);

// A value passed where GDScript's static type is Dictionary or Array.
inline DictRef as_dict(const Value &value) {
	if (value.kind != Kind::Dict) {
		not_a_dict(value);
	}
	return value.ref;
}
inline ArrayRef as_array(const Value &value) {
	if (value.kind != Kind::Array) {
		not_an_array(value);
	}
	return value.ref;
}

// The constructors: int(x), float(x), bool(x), String(x).
inline int64_t to_int(const State &state, const Value &value) {
	return value.kind == Kind::Int ? value.i : to_int_other(state, value);
}
double to_float(const Value &value);
bool to_bool(const Value &value);
inline Atom to_string(const Value &value) {
	if (!value.is_string_like()) {
		not_a_string(value);
	}
	return value.ref;
}

// x == y (Variant OP_EQUAL) and Variant::hash_compare, which containers use
// for their values: hash_compare wants the same type, so 1 and 1.0 differ.
bool equal(const State &state, const Value &a, const Value &b);
bool hash_compare(const State &state, const Value &a, const Value &b);

// An int or float value as a compat::Number, and back. Anything else is a
// ScriptError (max(), min() and clamp() of non-numbers).
compat::Number number(const Value &value);
Value number_value(const compat::Number &number);

// ceil(x) of the untyped utility: an int stays an int.
Value ceil(const Value &value);

// What `for x in value` visits: an Array's items or a Dictionary's keys. The
// loop body must not resize the container it walks.
const state::ValueList &items(const State &state, const Value &value);
// `for x in d.get(key, [])`: the field's items, none when the key is missing.
const state::ValueList &field_items(const State &state, DictRef dict, const Value &key);

// d[key] for reading: a missing key is a ScriptError.
Value index(const State &state, DictRef dict, const Value &key);
// d.merge(other, overwrite).
void merge(State &state, DictRef dict, DictRef other, bool overwrite);
// d.duplicate() / a.duplicate(): shallow, typing kept, never read-only.
DictRef duplicate_dict(State &state, DictRef dict);
ArrayRef duplicate_array(State &state, ArrayRef array);
inline bool is_empty(const State &state, DictRef dict) { return state.dict_size(dict) == 0; }

// "%d,%d" % [a, b] for ints.
std::string format_pair(int64_t a, int64_t b);

} // namespace aurelion::rules::gd
