#include "aurelion_rules/port/ai_port.hpp"

#include <string>

namespace aurelion::rules::port::ai {

namespace {

using state::Kind;
namespace key = state::key;

[[noreturn]] void fail(const std::string &text) {
	throw state::ScriptError(text);
}

// The characters of UTF-8 text (String.length()).
int64_t code_points(const std::string &text) {
	int64_t count = 0;
	for (const char byte : text) {
		if ((static_cast<unsigned char>(byte) & 0xC0) != 0x80) {
			++count;
		}
	}
	return count;
}

// Array's read-only and element type checks before a write: false (with
// Godot's error printed) when the write does not happen.
bool writable(State &state, ArrayRef array) {
	if (state.array(array).read_only) {
		state.print_error("Array is in read-only state.");
		return false;
	}
	return true;
}

} // namespace

Value vget(const State &state, const Value &object, const Value &key, const Value &fallback) {
	if (!gd::is_dict(object)) {
		fail(std::string("Invalid call. Nonexistent function 'get' in base '") + gd::type_name(object) + "'.");
	}
	return state.get(object.ref, key, fallback);
}

Value vmember(State &state, const Value &object, Atom name) {
	switch (object.kind) {
		case Kind::Dict: {
			Value found;
			if (!state.lookup(object.ref, gd::str(name), found)) {
				fail("Invalid access to property or key '" + state.text(name) + "' on a base object of type 'Dictionary'.");
			}
			return found;
		}
		case Kind::Vector2i:
		case Kind::Vector3i:
			if (name == key::x) {
				return gd::int_value(object.vx());
			}
			if (name == key::y) {
				return gd::int_value(object.vy());
			}
			if (name == key::z && object.kind == Kind::Vector3i) {
				return gd::int_value(object.vz());
			}
			break;
		case Kind::Opaque:
			return gd::member(state, object, name);
		default:
			break;
	}
	fail("Invalid access to property or key '" + state.text(name) + "' on a base object of type '" + gd::type_name(object) + "'.");
}

Value vindex(const State &state, const Value &container, const Value &index) {
	if (gd::is_dict(container)) {
		Value found;
		if (!state.lookup(container.ref, index, found)) {
			fail(std::string("Invalid access to property or key on a base object of type 'Dictionary'."));
		}
		return found;
	}
	if (!gd::is_int(index)) {
		fail(std::string("Invalid access of index '") + gd::type_name(index) + "' on a base object of type '" + gd::type_name(container) + "'.");
	}
	if (gd::is_array(container)) {
		return state.at(container.ref, index.i);
	}
	if (container.is_packed()) {
		return gd::packed_get(state, container, index.i);
	}
	fail(std::string("Invalid access of index on a base object of type '") + gd::type_name(container) + "'.");
}

int64_t vsize(const State &state, const Value &value) {
	switch (value.kind) {
		case Kind::Array:
			return state.array_size(value.ref);
		case Kind::Dict:
			return state.dict_size(value.ref);
		case Kind::String:
		case Kind::StringName:
			return code_points(state.text(value.ref));
		default:
			if (value.is_packed()) {
				return gd::packed_size(state, value.ref);
			}
			fail(std::string("Invalid call. Nonexistent function 'size' in base '") + gd::type_name(value) + "'.");
	}
}

bool vempty(const State &state, const Value &value) {
	return vsize(state, value) == 0;
}

bool vhas(const State &state, const Value &container, const Value &value) {
	if (gd::is_dict(container)) {
		return state.has(container.ref, value);
	}
	if (gd::is_array(container)) {
		return gd::array_has(state, container.ref, value);
	}
	if (container.is_packed()) {
		return gd::packed_find(state, container, value) >= 0;
	}
	fail(std::string("Invalid call. Nonexistent function 'has' in base '") + gd::type_name(container) + "'.");
}

Atom string_or_empty(State &state, DictRef dict, Atom field) {
	return gd::stringify(state, state.get(dict, gd::str(field), gd::str(key::empty)));
}

Value meta_get(const State &state, DictRef session, Atom name, const Value &fallback) {
	return state.get(session_view::meta(state, session), gd::name_value(name), fallback);
}

bool meta_has(const State &state, DictRef session, Atom name) {
	return state.has(session_view::meta(state, session), gd::name_value(name));
}

void meta_set(State &state, DictRef session, Atom name, const Value &value) {
	// Object::set_meta with null removes the entry.
	if (value.kind == Kind::Nil) {
		meta_remove(state, session, name);
		return;
	}
	state.set(session_view::meta(state, session), gd::name_value(name), value);
}

void meta_remove(State &state, DictRef session, Atom name) {
	state.erase(session_view::meta(state, session), gd::name_value(name));
}

int64_t session_int(const State &state, DictRef session, Atom field) {
	return gd::to_int(state, gd::index(state, session, gd::str(field)));
}

void array_erase(State &state, ArrayRef array, const Value &value) {
	if (!writable(state, array)) {
		return;
	}
	if (state.array(array).element_type != 0) {
		throw state::NotPorted("Array.erase on a typed Array");
	}
	// Vector::erase: the first item Variant::operator== (hash_compare) matches.
	const state::ValueList &items = state.array(array).items;
	for (size_t index = 0; index < items.size(); ++index) {
		if (gd::hash_compare(state, items[index], value)) {
			state.remove_at(array, static_cast<int64_t>(index));
			return;
		}
	}
}

void array_clear(State &state, ArrayRef array) {
	if (!writable(state, array)) {
		return;
	}
	state::ArrayNode &node = state.array_node(array);
	node.items.clear();
	node.dirty = true;
}

void array_resize(State &state, ArrayRef array, int64_t size) {
	if (!writable(state, array)) {
		return;
	}
	if (state.array(array).element_type != 0) {
		throw state::NotPorted("Array.resize on a typed Array");
	}
	if (size < 0) {
		state.print_error("Size of the Array cannot be negative.");
		return;
	}
	state::ArrayNode &node = state.array_node(array);
	node.items.resize(static_cast<size_t>(size));
	node.dirty = true;
}

void array_fill(State &state, ArrayRef array, const Value &value) {
	if (!writable(state, array)) {
		return;
	}
	if (state.array(array).element_type != 0) {
		throw state::NotPorted("Array.fill on a typed Array");
	}
	state::ArrayNode &node = state.array_node(array);
	for (size_t index = 0; index < node.items.size(); ++index) {
		node.items[index] = value;
	}
	node.dirty = true;
}

void append_array(State &state, ArrayRef array, ArrayRef other) {
	if (!writable(state, array)) {
		return;
	}
	const state::ValueList items = state.array(other).items;
	for (const Value &item : items) {
		state.append(array, item);
	}
}

Value array_back(const State &state, ArrayRef array) {
	const state::ValueList &items = state.array(array).items;
	if (items.empty()) {
		state.print_error("Can't take value from empty array.");
		return Value();
	}
	return items.back();
}

Value array_front(const State &state, ArrayRef array) {
	const state::ValueList &items = state.array(array).items;
	if (items.empty()) {
		state.print_error("Can't take value from empty array.");
		return Value();
	}
	return items[0];
}

ArrayRef typed_array(const Value &value, const char *where) {
	if (value.is_packed()) {
		throw state::NotPorted(std::string(where) + ": a packed array converted to Array");
	}
	return gd::as_array(value);
}

DictRef duplicate_field(State &state, DictRef dict, Atom field) {
	Value value;
	if (state.lookup(dict, gd::str(field), value) && gd::is_dict(value)) {
		return gd::deep_duplicate_dict(state, value.ref);
	}
	return state.new_dict();
}

void assign_float(State &state, Atom script, Atom name, DictRef weights, Atom field) {
	gd::set_static_var(state, script, name, gd::float_value(gd::to_float(gd::index(state, weights, gd::str(field)))));
}

void assign_int(State &state, Atom script, Atom name, DictRef weights, Atom field) {
	gd::set_static_var(state, script, name, gd::int_value(gd::to_int(state, gd::index(state, weights, gd::str(field)))));
}

} // namespace aurelion::rules::port::ai
