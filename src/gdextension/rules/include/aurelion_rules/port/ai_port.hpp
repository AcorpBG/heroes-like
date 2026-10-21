#pragma once

// What the AI targets port's files share (Phase 3): GDScript's operations on
// untyped values (x.get(), x.name, x[i], x.size()), the session's metadata, the
// scripts' static vars and the Array methods gd.hpp lacks, as Godot 4.6.2 runs
// them. A case GDScript stops on with a runtime error throws state::ScriptError.

#include "aurelion_rules/port/gd.hpp"
#include "aurelion_rules/port/session_view.hpp"

#include <cstdint>

namespace aurelion::rules::port::ai {

using gd::ArrayRef;
using gd::Atom;
using gd::DictRef;
using state::State;
using state::Value;

// x.get(key, fallback) of an untyped value: a Dictionary's; nothing else the
// AI meets has get() (a ScriptError).
Value vget(const State &state, const Value &object, const Value &key, const Value &fallback = Value());
inline Value vget(const State &state, const Value &object, Atom key, const Value &fallback = Value()) {
	return vget(state, object, gd::str(key), fallback);
}

// x.name of an untyped value: a Dictionary's key (missing: a ScriptError), a
// Vector2i's or Vector3i's x, y or z, an object's property (gd::member).
Value vmember(State &state, const Value &object, Atom name);

// x[index] of an untyped value: an Array's or a packed array's item (negative
// from the end, out of range a ScriptError) or a Dictionary's key (missing: a
// ScriptError).
Value vindex(const State &state, const Value &container, const Value &index);

// x.size(), x.is_empty() and x.has(value) of an untyped Array, Dictionary,
// packed array or String.
int64_t vsize(const State &state, const Value &value);
bool vempty(const State &state, const Value &value);
bool vhas(const State &state, const Value &container, const Value &value);

// String(d.get(key, "")), as the scripts read ids.
Atom string_or_empty(State &state, DictRef dict, Atom key);

// session.get_meta(name, fallback), has_meta(name), set_meta(name, value) and
// remove_meta(name): the view's "meta" Dictionary, keyed by StringName.
Value meta_get(const State &state, DictRef session, Atom name, const Value &fallback = Value());
bool meta_has(const State &state, DictRef session, Atom name);
void meta_set(State &state, DictRef session, Atom name, const Value &value);
void meta_remove(State &state, DictRef session, Atom name);

// session.day and the session's other int fields.
int64_t session_int(const State &state, DictRef session, Atom field);

// A static var as its declared type (script: key::<script>_script).
inline int64_t static_int(State &state, Atom script, Atom name) {
	return gd::to_int(state, gd::static_var(state, script, name));
}
inline double static_float(State &state, Atom script, Atom name) {
	return gd::to_float(gd::static_var(state, script, name));
}
inline bool static_bool(State &state, Atom script, Atom name) {
	return gd::to_bool(gd::static_var(state, script, name));
}
inline DictRef static_dict(State &state, Atom script, Atom name) {
	return gd::as_dict(gd::static_var(state, script, name));
}
inline ArrayRef static_array(State &state, Atom script, Atom name) {
	return gd::as_array(gd::static_var(state, script, name));
}

// a.erase(value) (the first item equal to it, as a.find() finds it), a.clear(),
// a.resize(size) (new items null), a.fill(value), a.append_array(other), a.back()
// and a.front() (an empty Array prints an error and answers null), a.has(value).
void array_erase(State &state, ArrayRef array, const Value &value);
void array_clear(State &state, ArrayRef array);
void array_resize(State &state, ArrayRef array, int64_t size);
void array_fill(State &state, ArrayRef array, const Value &value);
void append_array(State &state, ArrayRef array, ArrayRef other);
Value array_back(const State &state, ArrayRef array);
Value array_front(const State &state, ArrayRef array);
inline bool array_has(const State &state, ArrayRef array, const Value &value) {
	return gd::array_has(state, array, value);
}

// Time.get_ticks_msec().
inline int64_t ticks_msec() {
	return gd::ticks_usec() / 1000;
}

// var x: Array = value, or value returned as Array: Godot converts a packed
// array into a new Array (not ported); anything else is a ScriptError.
ArrayRef typed_array(const Value &value, const char *where);

// var value = dict.get(field, {}); value.duplicate(true) if value is
// Dictionary else {}.
DictRef duplicate_field(State &state, DictRef dict, Atom field);

// apply_ai_weights: Script.NAME = float(weights[field]) and
// Script.NAME = int(weights[field]).
void assign_float(State &state, Atom script, Atom name, DictRef weights, Atom field);
void assign_int(State &state, Atom script, Atom name, DictRef weights, Atom field);

} // namespace aurelion::rules::port::ai
