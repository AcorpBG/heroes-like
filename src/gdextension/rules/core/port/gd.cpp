#include "aurelion_rules/port/gd.hpp"

#include "aurelion_rules/compat/godot_string.hpp"

#include <cmath>

namespace aurelion::rules::gd {

namespace {

[[noreturn]] void fail(const std::string &message) {
	throw state::ScriptError(message);
}

bool is_number(const Value &value) {
	return value.kind == Kind::Int || value.kind == Kind::Float;
}

bool dict_equal(const State &state, DictRef a, DictRef b) {
	if (a == b) {
		return true;
	}
	if (state.dict_size(a) != state.dict_size(b)) {
		return false;
	}
	const state::DictNode &left = state.dict(a);
	for (size_t index = 0; index < left.keys.size(); ++index) {
		Value other;
		if (!state.lookup(b, left.keys[index], other) || !hash_compare(state, left.values[index], other)) {
			return false;
		}
	}
	return true;
}

bool array_equal(const State &state, ArrayRef a, ArrayRef b) {
	if (a == b) {
		return true;
	}
	const int64_t size = state.array_size(a);
	if (size != state.array_size(b)) {
		return false;
	}
	for (int64_t index = 0; index < size; ++index) {
		if (!hash_compare(state, state.at(a, index), state.at(b, index))) {
			return false;
		}
	}
	return true;
}

} // namespace

const char *type_name(const Value &value) {
	switch (value.kind) {
		case Kind::Nil:
			return "Nil";
		case Kind::Bool:
			return "bool";
		case Kind::Int:
			return "int";
		case Kind::Float:
			return "float";
		case Kind::String:
			return "String";
		case Kind::StringName:
			return "StringName";
		case Kind::Vector2i:
			return "Vector2i";
		case Kind::Array:
			return "Array";
		case Kind::Dict:
			return "Dictionary";
		case Kind::Opaque:
			return "Variant";
	}
	return "Variant";
}

DictRef as_dict(const Value &value) {
	if (value.kind != Kind::Dict) {
		fail(std::string("Invalid type: expected Dictionary, got ") + type_name(value));
	}
	return value.ref;
}

ArrayRef as_array(const Value &value) {
	if (value.kind != Kind::Array) {
		fail(std::string("Invalid type: expected Array, got ") + type_name(value));
	}
	return value.ref;
}

int64_t to_int(const State &state, const Value &value) {
	switch (value.kind) {
		case Kind::Int:
			return value.i;
		case Kind::Float:
			return compat::float_to_int(value.f);
		case Kind::Bool:
			return value.b ? 1 : 0;
		case Kind::String:
		case Kind::StringName:
			return compat::to_int(state.text(value.ref));
		default:
			fail(std::string("Invalid argument for 'int' constructor: ") + type_name(value));
	}
}

double to_float(const Value &value) {
	switch (value.kind) {
		case Kind::Float:
			return value.f;
		case Kind::Int:
			return static_cast<double>(value.i);
		case Kind::Bool:
			return value.b ? 1.0 : 0.0;
		default:
			// float(String) (String::to_float) is not ported yet.
			fail(std::string("Invalid argument for 'float' constructor: ") + type_name(value));
	}
}

bool to_bool(const Value &value) {
	switch (value.kind) {
		case Kind::Bool:
			return value.b;
		case Kind::Int:
			return value.i != 0;
		case Kind::Float:
			return value.f != 0.0;
		default:
			fail(std::string("Invalid argument for 'bool' constructor: ") + type_name(value));
	}
}

Atom to_string(const Value &value) {
	if (value.is_string_like()) {
		return value.ref;
	}
	fail(std::string("Invalid argument for 'String' constructor: ") + type_name(value));
}

bool equal(const State &state, const Value &a, const Value &b) {
	if (is_number(a) && is_number(b)) {
		if (a.kind == Kind::Int && b.kind == Kind::Int) {
			return a.i == b.i;
		}
		return number(a).as_double() == number(b).as_double();
	}
	if (a.is_string_like() && b.is_string_like()) {
		return a.ref == b.ref;
	}
	if (a.kind == Kind::Nil || b.kind == Kind::Nil) {
		return a.kind == b.kind;
	}
	if (a.kind != b.kind) {
		fail(std::string("Invalid operands '") + type_name(a) + "' and '" + type_name(b) + "' in operator '=='");
	}
	switch (a.kind) {
		case Kind::Bool:
			return a.b == b.b;
		case Kind::Vector2i:
			return a.i == b.i;
		case Kind::Dict:
			return dict_equal(state, a.ref, b.ref);
		case Kind::Array:
			return array_equal(state, a.ref, b.ref);
		default:
			fail(std::string("operator '==' on ") + type_name(a) + " is not ported");
	}
}

bool hash_compare(const State &state, const Value &a, const Value &b) {
	if (a.kind != b.kind) {
		return false;
	}
	switch (a.kind) {
		case Kind::Nil:
			return true;
		case Kind::Bool:
			return a.b == b.b;
		case Kind::Int:
		case Kind::Vector2i:
			return a.i == b.i;
		case Kind::Float:
			return a.f == b.f || (std::isnan(a.f) && std::isnan(b.f));
		case Kind::String:
		case Kind::StringName:
			return a.ref == b.ref;
		case Kind::Dict:
			return dict_equal(state, a.ref, b.ref);
		case Kind::Array:
			return array_equal(state, a.ref, b.ref);
		case Kind::Opaque:
			fail("hash_compare of an opaque value is not ported");
	}
	return false;
}

compat::Number number(const Value &value) {
	if (value.kind == Kind::Int) {
		return compat::Number::of_int(value.i);
	}
	if (value.kind == Kind::Float) {
		return compat::Number::of_float(value.f);
	}
	fail(std::string("A number is required, got ") + type_name(value));
}

Value number_value(const compat::Number &number) {
	return number.is_float ? Value::of_float(number.f) : Value::of_int(number.i);
}

Value ceil(const Value &value) {
	if (value.kind == Kind::Int) {
		return value;
	}
	if (value.kind == Kind::Float) {
		return Value::of_float(compat::godot_ceil(value.f));
	}
	fail(std::string("ceil() of ") + type_name(value) + " is not ported");
}

const std::vector<Value> &items(const State &state, const Value &value) {
	if (value.kind == Kind::Array) {
		return state.array(value.ref).items;
	}
	if (value.kind == Kind::Dict) {
		return state.dict(value.ref).keys;
	}
	fail(std::string("Iterating over ") + type_name(value) + " is not ported");
}

const std::vector<Value> &field_items(const State &state, DictRef dict, const Value &key) {
	static const std::vector<Value> kNone;
	Value field;
	if (!state.lookup(dict, key, field)) {
		return kNone;
	}
	return items(state, field);
}

Value index(const State &state, DictRef dict, const Value &key) {
	Value found;
	if (!state.lookup(dict, key, found)) {
		fail("Invalid access to property or key on a base object of type 'Dictionary'");
	}
	return found;
}

void merge(State &state, DictRef dict, DictRef other, bool overwrite) {
	const state::DictNode &source = state.dict(other);
	// Copied first: dict and other may be the same node.
	const std::vector<Value> keys = source.keys;
	const std::vector<Value> values = source.values;
	for (size_t index = 0; index < keys.size(); ++index) {
		if (overwrite || !state.has(dict, keys[index])) {
			state.set(dict, keys[index], values[index]);
		}
	}
}

DictRef duplicate_dict(State &state, DictRef dict) {
	const DictRef copy = state.new_dict();
	const state::DictNode &source = state.dict(dict);
	state::DictNode &target = state.dict(copy);
	target.keys = source.keys;
	target.values = source.values;
	target.key_type = source.key_type;
	target.value_type = source.value_type;
	return copy;
}

ArrayRef duplicate_array(State &state, ArrayRef array) {
	const ArrayRef copy = state.new_array();
	const state::ArrayNode &source = state.array(array);
	state::ArrayNode &target = state.array(copy);
	target.items = source.items;
	target.element_type = source.element_type;
	return copy;
}

std::string format_pair(int64_t a, int64_t b) {
	return compat::itos(a) + "," + compat::itos(b);
}

} // namespace aurelion::rules::gd
