#pragma once

// GDScript's semantics over the native state, for the battle port: the
// conversions, comparisons and container operations the ported functions use,
// as Godot 4.6.2 runs them (core/variant/variant_construct.*, variant_op.h,
// variant_utility.cpp, dictionary.cpp, array.cpp). A case GDScript stops on
// with a runtime error throws state::ScriptError.

#include "aurelion_rules/battle_state.hpp"
#include "aurelion_rules/compat/godot_math.hpp"
#include "aurelion_rules/compat/sort_array.hpp"
#include "aurelion_rules/port/registry.hpp"

#include <cstdint>
#include <initializer_list>
#include <string>
#include <utility>
#include <vector>

namespace aurelion::rules::gd {

using state::Kind;
using state::State;
using state::Value;
namespace key = state::key;

// A Dictionary, an Array, a packed array or a String by node index or atom,
// where the GDScript parameter or return type says which.
using DictRef = uint32_t;
using ArrayRef = uint32_t;
using PackedRef = uint32_t;
using Atom = uint32_t;

inline Value dict_value(DictRef dict) { return Value::of_ref(Kind::Dict, dict); }
inline Value array_value(ArrayRef array) { return Value::of_ref(Kind::Array, array); }
inline Value str(Atom atom) { return Value::str(atom); }
inline Value name_value(Atom atom) { return Value::of_ref(Kind::StringName, atom); }
inline Value int_value(int64_t value) { return Value::of_int(value); }
inline Value float_value(double value) { return Value::of_float(value); }
inline Value bool_value(bool value) { return Value::of_bool(value); }
inline Value bytes_value(PackedRef bytes) { return Value::of_ref(Kind::PackedByte, bytes); }
inline Value ints_value(PackedRef ints) { return Value::of_ref(Kind::PackedInt32, ints); }
inline Value strings_value(PackedRef strings) { return Value::of_ref(Kind::PackedString, strings); }
inline Value vector3i(int32_t x, int32_t y, int32_t z) { return Value::of_vector3i(x, y, z); }

// Godot's type name of a value (Variant::get_type_name).
const char *type_name(const Value &value);

inline bool is_dict(const Value &value) { return value.kind == Kind::Dict; }
inline bool is_array(const Value &value) { return value.kind == Kind::Array; }
inline bool is_vector2i(const Value &value) { return value.kind == Kind::Vector2i; }
inline bool is_vector3i(const Value &value) { return value.kind == Kind::Vector3i; }
inline bool is_packed(const Value &value) { return value.is_packed(); }
// x is String: a String only (a StringName is not one, as in GDScript).
inline bool is_string(const Value &value) { return value.kind == Kind::String; }
inline bool is_int(const Value &value) { return value.kind == Kind::Int; }
inline bool is_float(const Value &value) { return value.kind == Kind::Float; }
inline bool is_bool(const Value &value) { return value.kind == Kind::Bool; }

// typeof(x): Godot's Variant::Type number (TYPE_INT is 2, TYPE_FLOAT 3, ...).
// An opaque value's type is the adapter's; it is a ScriptError here.
int64_t type_of(const Value &value);

// int + int, - and *: GDScript's ints wrap around in two's complement.
inline int64_t add(int64_t a, int64_t b) {
	return static_cast<int64_t>(static_cast<uint64_t>(a) + static_cast<uint64_t>(b));
}
inline int64_t sub(int64_t a, int64_t b) {
	return static_cast<int64_t>(static_cast<uint64_t>(a) - static_cast<uint64_t>(b));
}
inline int64_t mul(int64_t a, int64_t b) {
	return static_cast<int64_t>(static_cast<uint64_t>(a) * static_cast<uint64_t>(b));
}
inline int64_t neg(int64_t a) {
	return static_cast<int64_t>(0 - static_cast<uint64_t>(a));
}

// The cases the inline helpers below leave to gd.cpp: the errors, and int() of
// anything but an int.
[[noreturn]] void not_a_dict(const Value &value);
[[noreturn]] void not_an_array(const Value &value);
[[noreturn]] void not_a_string(const Value &value);
[[noreturn]] void not_packed(const Value &value, Kind kind);
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
// The same for PackedByteArray, PackedInt32Array and PackedStringArray.
inline PackedRef as_packed(const Value &value, Kind kind) {
	if (value.kind != kind) {
		not_packed(value, kind);
	}
	return value.ref;
}
inline PackedRef as_bytes(const Value &value) { return as_packed(value, Kind::PackedByte); }
inline PackedRef as_ints(const Value &value) { return as_packed(value, Kind::PackedInt32); }
inline PackedRef as_strings(const Value &value) { return as_packed(value, Kind::PackedString); }

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

// is_same(a, b) (Variant::identity_compare): a container or packed array is
// the same node; anything else compares as hash_compare does, its type first.
bool is_same(const State &state, const Value &a, const Value &b);

// x == y (Variant OP_EQUAL) and Variant::hash_compare: hash_compare wants the
// same type, so 1 and 1.0 differ, and with semantic (the default, as key
// lookups and Array.has use it) every NaN equals every NaN. Container ==
// compares the items without semantic, so a NaN item never matches.
bool equal(const State &state, const Value &a, const Value &b);
bool hash_compare(const State &state, const Value &a, const Value &b, bool semantic = true);
// StringLikeVariantComparator::compare (Array.has, Array.find, `x in array`):
// hash_compare, and a String matches a StringName of the same text.
bool string_like_equal(const State &state, const Value &a, const Value &b);

// The untyped arithmetic of two numbers, as Variant's operators compute it:
// int with int stays int (wrapping; / truncates, and / 0 or % 0 is a
// ScriptError), anything with a float is a float. Not numbers: a ScriptError.
Value op_add(const Value &a, const Value &b);
Value op_sub(const Value &a, const Value &b);
Value op_mul(const Value &a, const Value &b);
Value op_div(const Value &a, const Value &b);
// a < b and a > b of two numbers (an int meets a float as a double).
bool op_less(const Value &a, const Value &b);
bool op_greater(const Value &a, const Value &b);

// hash(x) (Variant::hash): the murmur3 hash of 4.6.2's Variant::recursive_hash
// over Nil, bool, int, float, String, Array and Dictionary, as GDScript's int.
int64_t hash(const State &state, const Value &value);

// if x: / not x / bool(x) of a Variant (Variant::booleanize): false for Nil,
// false, 0, 0.0, "", an empty StringName, Vector2i(0, 0) and an empty Array or
// Dictionary. An opaque value (an object) is true.
bool truthy(const State &state, const Value &value);

// is_equal_approx(a, b) of two floats (Math::is_equal_approx).
bool is_equal_approx(double a, double b);

// d.get(key) (Nil when missing) and d.get(key, fallback), then the
// constructors: int(d.get(key, fallback)) and the like. The fallback goes
// through the constructor too, as in GDScript.
inline Value field(const State &state, DictRef dict, Atom key) {
	return state.get(dict, Value::str(key), Value());
}
inline Value field_or(const State &state, DictRef dict, Atom key, const Value &fallback) {
	return state.get(dict, Value::str(key), fallback);
}
int64_t int_field(const State &state, DictRef dict, Atom key, int64_t fallback);
double float_field(const State &state, DictRef dict, Atom key, double fallback);
bool bool_field(const State &state, DictRef dict, Atom key, bool fallback);
Atom string_field(const State &state, DictRef dict, Atom key, Atom fallback);

// An int or float value as a compat::Number, and back. Anything else is a
// ScriptError (max(), min() and clamp() of non-numbers).
compat::Number number(const Value &value);
Value number_value(const compat::Number &number);

// ceil(x) of the untyped utility: an int stays an int.
Value ceil(const Value &value);

// What `for x in value` visits: an Array's items, a Dictionary's keys, the
// ints 0 to n - 1 of an int n, or each character of a String as a String. The
// loop body must not resize the container it walks.
class Items {
public:
	explicit Items(const state::ValueList &list) :
			list_(&list) {}
	explicit Items(state::ValueList &&owned) :
			owned_(std::move(owned)) {}
	Items(Items &&other) noexcept :
			owned_(std::move(other.owned_)), list_(other.list_) {}
	Items(const Items &) = delete;
	Items &operator=(const Items &) = delete;
	const Value *begin() const { return list().begin(); }
	const Value *end() const { return list().end(); }
	size_t size() const { return list().size(); }
	const state::ValueList &list() const { return list_ != nullptr ? *list_ : owned_; }

private:
	state::ValueList owned_;
	const state::ValueList *list_ = nullptr;
};
// A String's characters are new atoms, so they need a State that can intern.
Items items(const State &state, const Value &value);
Items items(State &state, const Value &value);
// `for x in d.get(key, [])`: the field's items, none when the key is missing.
Items field_items(const State &state, DictRef dict, const Value &key);
Items field_items(State &state, DictRef dict, const Value &key);

// d[key] for reading: a missing key is a ScriptError.
Value index(const State &state, DictRef dict, const Value &key);
// d.keys() and d.values(): new Arrays.
ArrayRef keys(State &state, DictRef dict);
ArrayRef values(State &state, DictRef dict);
// value in array (Array.has): string_like_equal against each item.
bool array_has(const State &state, ArrayRef array, const Value &value);
// value in x for a Dictionary (its keys) or an Array; anything else is a
// ScriptError, as OP_IN without an evaluator.
bool in(const State &state, const Value &value, const Value &container);
// a.find(value): the first index, or -1.
int64_t array_find(const State &state, ArrayRef array, const Value &value);
// a.push_front(value), a.insert(position, value), a.remove_at(position),
// a.pop_back(), a.pop_front(): with Godot's read-only, type and range checks,
// which print an error and leave the Array as it was.
void push_front(State &state, ArrayRef array, const Value &value);
void insert(State &state, ArrayRef array, int64_t position, const Value &value);
void remove_at(State &state, ArrayRef array, int64_t position);
Value pop_back(State &state, ArrayRef array);
Value pop_front(State &state, ArrayRef array);
// a + b of two Arrays: a new untyped Array with a's items, then b's.
ArrayRef concat(State &state, ArrayRef a, ArrayRef b);
// d.merge(other, overwrite).
void merge(State &state, DictRef dict, DictRef other, bool overwrite);
// d.duplicate() / a.duplicate(): shallow, typing kept, never read-only.
DictRef duplicate_dict(State &state, DictRef dict);
ArrayRef duplicate_array(State &state, ArrayRef array);
// d.duplicate(true) / a.duplicate(true): every nested Array and Dictionary is
// copied too, once per place it is reached (Godot keeps no copy table).
DictRef deep_duplicate_dict(State &state, DictRef dict);
ArrayRef deep_duplicate_array(State &state, ArrayRef array);
// x.duplicate(deep) of an untyped value: containers copied, others as they are.
Value duplicate_value(State &state, const Value &value, bool deep);
inline bool is_empty(const State &state, DictRef dict) { return state.dict_size(dict) == 0; }
// A new empty Array typed with a builtin Variant type (state::variant_type),
// as GDScript's `var ids: Array[String] = []` makes it.
ArrayRef new_typed_array(State &state, uint8_t builtin);
// a.slice(begin, end): a new Array with a's element type (Array::slice; the
// bounds are Godot's 32-bit ints, and a step against the bounds prints an
// error and answers an empty Array).
ArrayRef slice(State &state, ArrayRef array, int64_t begin, int64_t end = 2147483647);
// a.sort_custom(func(x, y): return less(x, y)) with Godot's unstable introsort
// (compat/sort_array.hpp). A read-only Array prints an error and stays as it is.
template <typename Less>
void sort_custom(State &state, ArrayRef array, Less less) {
	if (state.array(array).read_only) {
		state.print_error("Array is in read-only state.");
		return;
	}
	state::ValueList items = state.array(array).items;
	compat::sort_custom(items.begin(), static_cast<int64_t>(items.size()), std::move(less));
	state.replace_items(array, std::move(items));
}

// Packed arrays (PackedByteArray, PackedInt32Array, PackedStringArray), as
// Godot's Vector does it. A packed array is one object however many Variants
// hold it, so these change it for every holder. Out of range indices are a
// ScriptError (GDScript's "Out of bounds get index"), negative ones count
// from the end.
// PackedByteArray(), PackedInt32Array(), PackedStringArray().
PackedRef new_bytes(State &state);
PackedRef new_ints(State &state);
PackedRef new_strings(State &state);
int64_t packed_size(const State &state, PackedRef packed);
inline bool packed_is_empty(const State &state, PackedRef packed) { return packed_size(state, packed) == 0; }
// a[index] of a byte or int32 array, and of a string array.
int64_t packed_int(const State &state, PackedRef packed, int64_t index);
Atom packed_string(const State &state, PackedRef packed, int64_t index);
// a[index] of any of them as a Value (an int or a String).
Value packed_get(const State &state, const Value &packed, int64_t index);
// a[index] = value: a byte array keeps the low 8 bits of the int, an int32 one
// the low 32 (Variant's typed setter casts).
void packed_set(State &state, PackedRef packed, int64_t index, int64_t value);
void packed_set_string(State &state, PackedRef packed, int64_t index, Atom value);
// a.append(value) (push_back).
void packed_append(State &state, PackedRef packed, int64_t value);
void packed_append_string(State &state, PackedRef packed, Atom value);
// a.append_array(other) of two arrays of one kind.
void packed_append_array(State &state, PackedRef packed, PackedRef other);
// a.resize(size): new elements 0 or "" (Vector::resize zero-fills); a
// negative size prints an error and leaves the array.
void packed_resize(State &state, PackedRef packed, int64_t size);
// a.fill(value) of a byte or int32 array.
void packed_fill(State &state, PackedRef packed, int64_t value);
// a.duplicate(): a new array with the same elements.
PackedRef packed_duplicate(State &state, PackedRef packed);
// a.slice(begin, end) (Vector::slice: clamped, negative from the end; begin
// past end prints an error and gives an empty array).
PackedRef packed_slice(State &state, PackedRef packed, int64_t begin, int64_t end = INT64_MAX);
// a.sort() of a byte or int32 array: ascending.
void packed_sort(State &state, PackedRef packed);
// a.find(value) (-1 when missing) and a.has(value) / value in a: an int for a
// byte or int32 array, a String or StringName for a string array.
int64_t packed_find(const State &state, const Value &packed, const Value &value);
// The elements in place, to read many: valid until the array changes.
const uint8_t *packed_bytes(const State &state, PackedRef packed);
const int32_t *packed_ints(const State &state, PackedRef packed);
// s.to_utf8_buffer() and Marshalls.base64_to_raw(s) (strict base64: text the
// encoder did not make is a ScriptError, not ported).
PackedRef utf8_buffer(State &state, Atom text);
PackedRef base64_to_raw(State &state, Atom text);
// sep.join(strings) of a PackedStringArray.
Atom join_strings(State &state, Atom separator, PackedRef strings);

// A GDScript memo that a table names as GDScript's own (Table::gdscript_only):
// a ScriptError, for the port that reached it.
[[noreturn]] void refuse_gdscript_only_static(const State &state, Atom script, Atom name);

// Script.NAME of a GDScript static var (script: the script's res:// path),
// and Script.NAME = value, which takes effect with the call's write-back.
inline Value static_var(State &state, Atom script, Atom name) {
	if (port::gdscript_only_static(script, name)) {
		refuse_gdscript_only_static(state, script, name);
	}
	return state.host().static_get(state, script, name);
}
inline void set_static_var(State &state, Atom script, Atom name, const Value &value) {
	if (port::gdscript_only_static(script, name)) {
		refuse_gdscript_only_static(state, script, name);
	}
	state.host().static_set(state, script, name, value);
}

// Script.function(args) of a GDScript static func the phase leaves in
// GDScript, a host call (Backing::call_static; script: the script's res://
// path): gd::call_static(state, key::battle_rules_script, key::_finalize_victory,
// {session}). Its table must list it (port::Table::hosts) with as many
// arguments. Everything the call changed is written back first and read again
// afterwards: an items() range or a const DictNode & held across it is no
// longer valid. In a call where no GDScript may run (a shadow check, a call
// that writes nothing back) the native call ends there (state::Suspend). A
// pure host (port::Host::pure) is written back to, undoably, but not read again.
Value call_static(State &state, Atom script, Atom function, std::initializer_list<Value> args);

// "%d,%d" % [a, b] for ints.
std::string format_pair(int64_t a, int64_t b);

// Strings. text() is the UTF-8 of a String or StringName value.
const std::string &text(const State &state, const Value &value);
// s.strip_edges(): drops the characters up to code 32 at both ends.
Atom strip_edges(State &state, Atom text);
bool begins_with(const State &state, Atom text, Atom prefix);
bool ends_with(const State &state, Atom text, Atom suffix);
// str(x) and String(x) of Nil, bool, int, String and StringName (float and the
// containers are not ported: a ScriptError).
Atom stringify(State &state, const Value &value);
// String(x) in the helpers the subsystems share: stringify(), with a float or a
// container throwing NotPorted, so a switch that falls back to GDScript (the
// day port) converts it in the GDScript body. Elsewhere (battle, AI) the call
// fails, as stringify() would.
Atom stringify_or_fallback(State &state, const Value &value);
// x.is_valid_int() and int(x) of a String.
bool is_valid_int(const State &state, Atom text);
// pattern % values (String::sprintf) with the conversions the ported code
// uses: %s is String(value) as stringify() converts it, %d an int or a float
// truncated, %% a percent sign. Flags, widths and the other conversions throw
// "not ported". A format error (a missing, extra or non-number value) prints
// "String formatting error" and answers the pattern, as Godot's validated
// operator does.
Atom format(State &state, Atom pattern, std::initializer_list<Value> values);
// s.capitalize() of ASCII text (other text throws: the Unicode case tables
// are not ported), s.replace(key, with) and s.trim_prefix(prefix).
Atom capitalize(State &state, Atom text);
Atom replace(State &state, Atom text, Atom key, Atom with);
Atom trim_prefix(State &state, Atom text, Atom prefix);

// object.property of an object value (an opaque Variant): the host reads it.
Value member(State &state, const Value &object, Atom property);
// object.property = value: the host writes it into the object's view, and the
// view into the object with the call's write-back.
void set_member(State &state, const Value &object, Atom property, const Value &value);
// An object value's view (Backing::object_view): a session as the day ports
// take it (session_view.hpp), its metadata under "meta". One Dict for the
// whole call: member() and set_member() of the object read and write it too.
DictRef object_view(State &state, const Value &object);
// The object value a view stands for: a host call (call_static) takes the
// session object, not its view. A Dict that is no view is a ScriptError.
Value view_object(State &state, DictRef view);

// A RandomNumberGenerator value (an opaque Variant): rng.seed, rng.state as
// GDScript's int, rng.randi_range(from, to), which advances the object's
// state, and RandomNumberGenerator.new() with seed, then state, set.
int64_t rng_seed(State &state, const Value &rng);
int64_t rng_state(State &state, const Value &rng);
int64_t rng_randi_range(State &state, const Value &rng, int64_t from, int64_t to);
Value rng_new(State &state, int64_t seed, int64_t rng_state);

// ContentService.get_unit(id) and the like: the row, the same Dictionary on
// every call, or a new empty one when there is none; ContentService.load_json.
DictRef content_row(State &state, state::ContentTable table, Atom id);
DictRef content_file(State &state, Atom path);
// ContentService.get_content_revision().
inline int64_t content_revision(State &state) { return state.host().content_revision(state); }

// GDScript's pow(base, exponent), exp(x) and log(x): the engine's, so the last
// bit matches whatever C runtime the game's build uses (Backing::math_pow).
inline double engine_pow(State &state, double base, double exponent) { return state.host().math_pow(base, exponent); }
inline double engine_exp(State &state, double x) { return state.host().math_exp(x); }
inline double engine_log(State &state, double x) { return state.host().math_log(x); }

// Time.get_ticks_usec(), for the timings scripts keep (a steady clock's
// microseconds: only differences mean anything).
int64_t ticks_usec();

// JSON.stringify(value) with its defaults (no indent, keys sorted): null,
// bools, ints, Strings, StringNames, Vector2i, Vector3i, Arrays and
// Dictionaries whose keys are all Strings or all ints. Floats, other values,
// other key sets, control characters json_escape does not name and circular
// structures throw NotPorted.
std::string json_stringify(const State &state, const Value &value);

// push_warning(text) and push_error(text) of a script.
void push_warning(State &state, const std::string &text);

} // namespace aurelion::rules::gd
