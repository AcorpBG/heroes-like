#include "aurelion_rules/port/gd.hpp"

#include "aurelion_rules/compat/godot_pcg.hpp"
#include "aurelion_rules/compat/godot_string.hpp"

#include <algorithm>
#include <chrono>
#include <cmath>
#include <cstring>

namespace aurelion::rules::gd {

namespace {

[[noreturn]] void fail(const std::string &message) {
	throw state::ScriptError(message);
}

bool is_number(const Value &value) {
	return value.kind == Kind::Int || value.kind == Kind::Float;
}

// Dictionary::recursive_equal and Array::recursive_equal: the items compare
// with hash_compare without semantic, so NaN items differ.
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
		if (!state.lookup(b, left.keys[index], other) || !hash_compare(state, left.values[index], other, false)) {
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
		if (!hash_compare(state, state.at(a, index), state.at(b, index), false)) {
			return false;
		}
	}
	return true;
}

// Vector == Vector of two packed arrays, and Variant::hash_compare's packed
// cases: the same size and elements.
bool packed_equal(const State &state, uint32_t a, uint32_t b) {
	if (a == b) {
		return true;
	}
	const state::PackedNode &left = state.packed(a);
	const state::PackedNode &right = state.packed(b);
	switch (left.kind) {
		case Kind::PackedByte:
			return left.bytes == right.bytes;
		case Kind::PackedString:
			return left.atoms == right.atoms;
		default:
			return left.ints == right.ints;
	}
}

// hashfuncs.h of 4.6.2.
constexpr uint32_t kMurmurSeed = 0x7F07C65;

uint32_t murmur3_one_32(uint32_t value, uint32_t seed = kMurmurSeed) {
	value *= 0xcc9e2d51;
	value = (value << 15) | (value >> 17);
	value *= 0x1b873593;
	seed ^= value;
	seed = (seed << 13) | (seed >> 19);
	return seed * 5 + 0xe6546b64;
}

uint32_t murmur3_one_64(uint64_t value, uint32_t seed = kMurmurSeed) {
	seed = murmur3_one_32(static_cast<uint32_t>(value & 0xFFFFFFFF), seed);
	return murmur3_one_32(static_cast<uint32_t>(value >> 32), seed);
}

uint32_t fmix32(uint32_t h) {
	h ^= h >> 16;
	h *= 0x85ebca6b;
	h ^= h >> 13;
	h *= 0xc2b2ae35;
	h ^= h >> 16;
	return h;
}

uint32_t one_uint64(uint64_t v) {
	v = (~v) + (v << 18);
	v = v ^ (v >> 31);
	v = v * 21;
	v = v ^ (v >> 11);
	v = v + (v << 6);
	v = v ^ (v >> 22);
	return static_cast<uint32_t>(v);
}

uint32_t murmur3_one_double(double value) {
	uint64_t bits = 0;
	// +0.0 and -0.0 hash alike, and every NaN as Math::NaN.
	const double normalized = value == 0.0 ? 0.0 : (std::isnan(value) ? std::numeric_limits<double>::quiet_NaN() : value);
	std::memcpy(&bits, &normalized, sizeof(bits));
	return murmur3_one_64(bits);
}

constexpr int kMaxRecursion = 100;

uint32_t recursive_hash(const State &state, const Value &value, int depth) {
	switch (value.kind) {
		case Kind::Nil:
			return 0;
		case Kind::Bool:
			return value.b ? 1 : 0;
		case Kind::Int:
			return one_uint64(static_cast<uint64_t>(value.i));
		case Kind::Float:
			return murmur3_one_double(value.f);
		case Kind::String:
		case Kind::StringName:
			// A StringName hashes as its String (the empty one too).
			return compat::string_hash(state.text(value.ref));
		case Kind::Array: {
			if (depth > kMaxRecursion) {
				return 0;
			}
			uint32_t h = murmur3_one_32(state::variant_type::ARRAY);
			const int64_t size = state.array_size(value.ref);
			for (int64_t index = 0; index < size; ++index) {
				h = murmur3_one_32(recursive_hash(state, state.at(value.ref, index), depth + 1), h);
			}
			return fmix32(h);
		}
		case Kind::Dict: {
			if (depth > kMaxRecursion) {
				return 0;
			}
			uint32_t h = murmur3_one_32(state::variant_type::DICTIONARY);
			const state::DictNode &node = state.dict(value.ref);
			for (size_t index = 0; index < node.keys.size(); ++index) {
				h = murmur3_one_32(recursive_hash(state, node.keys[index], depth + 1), h);
				h = murmur3_one_32(recursive_hash(state, node.values[index], depth + 1), h);
			}
			return fmix32(h);
		}
		default:
			fail(std::string("hash() of ") + type_name(value) + " is not ported");
	}
}

[[noreturn]] void not_numbers(const char *op, const Value &a, const Value &b) {
	fail(std::string("Invalid operands '") + type_name(a) + "' and '" + type_name(b) + "' in operator '" + op + "'");
}

// UTF-8 sequences: the length of the one starting with this byte.
size_t utf8_length(unsigned char lead) {
	if (lead < 0x80) {
		return 1;
	}
	if ((lead >> 5) == 0x6) {
		return 2;
	}
	if ((lead >> 4) == 0xE) {
		return 3;
	}
	if ((lead >> 3) == 0x1E) {
		return 4;
	}
	return 1;
}

DictRef deep_dict(State &state, DictRef dict);
ArrayRef deep_array(State &state, ArrayRef array);

Value deep_value(State &state, const Value &value) {
	if (value.kind == Kind::Dict) {
		return dict_value(deep_dict(state, value.ref));
	}
	if (value.kind == Kind::Array) {
		return array_value(deep_array(state, value.ref));
	}
	// Variant::recursive_duplicate copies a packed array.
	if (value.is_packed()) {
		return Value::of_ref(value.kind, packed_duplicate(state, value.ref));
	}
	return value;
}

DictRef deep_dict(State &state, DictRef dict) {
	const state::ValueList keys = state.dict(dict).keys.list();
	const state::ValueList values = state.dict(dict).values;
	const state::TypeRef key_type = state.dict(dict).key_type;
	const state::TypeRef value_type = state.dict(dict).value_type;
	const DictRef copy = state.new_dict();
	state::ValueList copied_keys;
	state::ValueList copied_values;
	copied_keys.reserve(keys.size());
	copied_values.reserve(values.size());
	for (size_t index = 0; index < keys.size(); ++index) {
		// Dictionary::recursive_duplicate copies the keys too.
		copied_keys.push_back(deep_value(state, keys[index]));
		copied_values.push_back(deep_value(state, values[index]));
	}
	state::DictNode &target = state.dict_node(copy);
	target.keys = copied_keys;
	target.values = copied_values;
	target.key_type = key_type;
	target.value_type = value_type;
	return copy;
}

ArrayRef deep_array(State &state, ArrayRef array) {
	const state::ValueList items = state.array(array).items;
	const state::TypeRef element_type = state.array(array).element_type;
	const ArrayRef copy = state.new_array();
	state::ValueList copied;
	copied.reserve(items.size());
	for (const Value &item : items) {
		copied.push_back(deep_value(state, item));
	}
	state::ArrayNode &target = state.array_node(copy);
	target.items = std::move(copied);
	target.element_type = element_type;
	return copy;
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
		case Kind::Vector3i:
			return "Vector3i";
		case Kind::PackedByte:
			return "PackedByteArray";
		case Kind::PackedInt32:
			return "PackedInt32Array";
		case Kind::PackedString:
			return "PackedStringArray";
		case Kind::Opaque:
			return "Variant";
	}
	return "Variant";
}

int64_t type_of(const Value &value) {
	switch (value.kind) {
		case Kind::Nil:
			return state::variant_type::NIL;
		case Kind::Bool:
			return state::variant_type::BOOL;
		case Kind::Int:
			return state::variant_type::INT;
		case Kind::Float:
			return state::variant_type::FLOAT;
		case Kind::String:
			return state::variant_type::STRING;
		case Kind::StringName:
			return state::variant_type::STRING_NAME;
		case Kind::Vector2i:
			return state::variant_type::VECTOR2I;
		case Kind::Array:
			return state::variant_type::ARRAY;
		case Kind::Dict:
			return state::variant_type::DICTIONARY;
		case Kind::Vector3i:
			return state::variant_type::VECTOR3I;
		case Kind::PackedByte:
			return state::variant_type::PACKED_BYTE_ARRAY;
		case Kind::PackedInt32:
			return state::variant_type::PACKED_INT32_ARRAY;
		case Kind::PackedString:
			return state::variant_type::PACKED_STRING_ARRAY;
		case Kind::Opaque:
			break;
	}
	fail("typeof() of an opaque value is not ported");
}

void not_a_dict(const Value &value) {
	fail(std::string("Invalid type: expected Dictionary, got ") + type_name(value));
}

void not_an_array(const Value &value) {
	fail(std::string("Invalid type: expected Array, got ") + type_name(value));
}

int64_t to_int_other(const State &state, const Value &value) {
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

void not_a_string(const Value &value) {
	fail(std::string("Invalid argument for 'String' constructor: ") + type_name(value));
}

void not_packed(const Value &value, Kind kind) {
	fail(std::string("Invalid type: expected ") + type_name(Value::of_ref(kind, 0)) + ", got " + type_name(value));
}

namespace {

int64_t packed_position(int64_t index, int64_t size, const char *base, bool set) {
	const int64_t position = index < 0 ? index + size : index;
	if (position < 0 || position >= size) {
		fail(std::string("Out of bounds ") + (set ? "set" : "get") + " index '" + std::to_string(index) + "' (on base: '" + base + "')");
	}
	return position;
}

const char *packed_base(Kind kind) {
	switch (kind) {
		case Kind::PackedByte:
			return "PackedByteArray";
		case Kind::PackedString:
			return "PackedStringArray";
		default:
			return "PackedInt32Array";
	}
}

void not_numeric(const state::PackedNode &node, const char *what) {
	if (node.kind == Kind::PackedString) {
		fail(std::string(what) + " of a PackedStringArray is not ported");
	}
}

int base64_digit(unsigned char c) {
	if (c >= 'A' && c <= 'Z') {
		return c - 'A';
	}
	if (c >= 'a' && c <= 'z') {
		return c - 'a' + 26;
	}
	if (c >= '0' && c <= '9') {
		return c - '0' + 52;
	}
	if (c == '+') {
		return 62;
	}
	if (c == '/') {
		return 63;
	}
	return -1;
}

[[noreturn]] void not_encoder_base64() {
	fail("Marshalls.base64_to_raw of text the encoder did not make is not ported");
}

} // namespace

PackedRef new_bytes(State &state) {
	return state.new_packed(Kind::PackedByte);
}

PackedRef new_ints(State &state) {
	return state.new_packed(Kind::PackedInt32);
}

PackedRef new_strings(State &state) {
	return state.new_packed(Kind::PackedString);
}

int64_t packed_size(const State &state, PackedRef packed) {
	return static_cast<int64_t>(state.packed(packed).size());
}

int64_t packed_int(const State &state, PackedRef packed, int64_t index) {
	const state::PackedNode &node = state.packed(packed);
	not_numeric(node, "An int element");
	const int64_t at = packed_position(index, static_cast<int64_t>(node.size()), packed_base(node.kind), false);
	return node.kind == Kind::PackedByte ? static_cast<int64_t>(node.bytes[static_cast<size_t>(at)]) : static_cast<int64_t>(node.ints[static_cast<size_t>(at)]);
}

Atom packed_string(const State &state, PackedRef packed, int64_t index) {
	const state::PackedNode &node = state.packed(packed);
	if (node.kind != Kind::PackedString) {
		fail("A String element of a numeric packed array");
	}
	const int64_t at = packed_position(index, static_cast<int64_t>(node.size()), packed_base(node.kind), false);
	return node.atoms[static_cast<size_t>(at)];
}

Value packed_get(const State &state, const Value &packed, int64_t index) {
	if (packed.kind == Kind::PackedString) {
		return Value::str(packed_string(state, packed.ref, index));
	}
	if (!packed.is_packed()) {
		fail(std::string("Indexing ") + type_name(packed) + " as a packed array");
	}
	return Value::of_int(packed_int(state, packed.ref, index));
}

void packed_set(State &state, PackedRef packed, int64_t index, int64_t value) {
	state::PackedNode &node = state.packed_write(packed);
	not_numeric(node, "Setting an int");
	const int64_t at = packed_position(index, static_cast<int64_t>(node.size()), packed_base(node.kind), true);
	if (node.kind == Kind::PackedByte) {
		node.bytes[static_cast<size_t>(at)] = static_cast<uint8_t>(value);
	} else {
		node.ints[static_cast<size_t>(at)] = static_cast<int32_t>(value);
	}
}

void packed_set_string(State &state, PackedRef packed, int64_t index, Atom value) {
	state::PackedNode &node = state.packed_write(packed);
	if (node.kind != Kind::PackedString) {
		fail("Setting a String into a numeric packed array");
	}
	const int64_t at = packed_position(index, static_cast<int64_t>(node.size()), packed_base(node.kind), true);
	node.atoms[static_cast<size_t>(at)] = value;
}

void packed_append(State &state, PackedRef packed, int64_t value) {
	state::PackedNode &node = state.packed_write(packed);
	not_numeric(node, "Appending an int");
	if (node.kind == Kind::PackedByte) {
		node.bytes.push_back(static_cast<uint8_t>(value));
	} else {
		node.ints.push_back(static_cast<int32_t>(value));
	}
}

void packed_append_string(State &state, PackedRef packed, Atom value) {
	state::PackedNode &node = state.packed_write(packed);
	if (node.kind != Kind::PackedString) {
		fail("Appending a String to a numeric packed array");
	}
	node.atoms.push_back(value);
}

void packed_append_array(State &state, PackedRef packed, PackedRef other) {
	// Copied first: packed and other may be the same array.
	const state::PackedNode source = state.packed(other);
	state::PackedNode &node = state.packed_write(packed);
	if (node.kind != source.kind) {
		fail(std::string("append_array of a ") + packed_base(source.kind) + " to a " + packed_base(node.kind));
	}
	node.bytes.insert(node.bytes.end(), source.bytes.begin(), source.bytes.end());
	node.ints.insert(node.ints.end(), source.ints.begin(), source.ints.end());
	node.atoms.insert(node.atoms.end(), source.atoms.begin(), source.atoms.end());
}

void packed_resize(State &state, PackedRef packed, int64_t size) {
	if (size < 0) {
		state.print_error("Condition \"p_size < 0\" is true. Returning: ERR_INVALID_PARAMETER");
		return;
	}
	const uint32_t empty = state.intern("");
	state::PackedNode &node = state.packed_write(packed);
	switch (node.kind) {
		case Kind::PackedByte:
			node.bytes.resize(static_cast<size_t>(size), 0);
			break;
		case Kind::PackedString:
			node.atoms.resize(static_cast<size_t>(size), empty);
			break;
		default:
			node.ints.resize(static_cast<size_t>(size), 0);
			break;
	}
}

void packed_fill(State &state, PackedRef packed, int64_t value) {
	state::PackedNode &node = state.packed_write(packed);
	not_numeric(node, "fill()");
	if (node.kind == Kind::PackedByte) {
		std::fill(node.bytes.begin(), node.bytes.end(), static_cast<uint8_t>(value));
	} else {
		std::fill(node.ints.begin(), node.ints.end(), static_cast<int32_t>(value));
	}
}

PackedRef packed_duplicate(State &state, PackedRef packed) {
	const Kind kind = state.packed(packed).kind;
	const PackedRef copy = state.new_packed(kind);
	// Both references stay valid: NodePool keeps its nodes in place.
	const state::PackedNode &source = state.packed_node(packed);
	state::PackedNode &target = state.packed_node(copy);
	target.bytes = source.bytes;
	target.ints = source.ints;
	target.atoms = source.atoms;
	return copy;
}

PackedRef packed_slice(State &state, PackedRef packed, int64_t begin_in, int64_t end_in) {
	const Kind kind = state.packed(packed).kind;
	const PackedRef result = state.new_packed(kind);
	const state::PackedNode &source = state.packed_node(packed);
	const int64_t s = static_cast<int64_t>(source.size());
	int64_t begin = begin_in < -s ? -s : (begin_in > s ? s : begin_in);
	if (begin < 0) {
		begin += s;
	}
	int64_t end = end_in < -s ? -s : (end_in > s ? s : end_in);
	if (end < 0) {
		end += s;
	}
	if (begin > end) {
		state.print_error("Condition \"begin > end\" is true. Returning: result");
		return result;
	}
	state::PackedNode &target = state.packed_node(result);
	switch (kind) {
		case Kind::PackedByte:
			target.bytes.assign(source.bytes.begin() + begin, source.bytes.begin() + end);
			break;
		case Kind::PackedString:
			target.atoms.assign(source.atoms.begin() + begin, source.atoms.begin() + end);
			break;
		default:
			target.ints.assign(source.ints.begin() + begin, source.ints.begin() + end);
			break;
	}
	return result;
}

void packed_sort(State &state, PackedRef packed) {
	state::PackedNode &node = state.packed_write(packed);
	not_numeric(node, "sort()");
	// Equal numbers cannot be told apart, so any correct sort is Godot's.
	std::sort(node.bytes.begin(), node.bytes.end());
	std::sort(node.ints.begin(), node.ints.end());
}

int64_t packed_find(const State &state, const Value &packed, const Value &value) {
	if (!packed.is_packed()) {
		fail(std::string("find() in ") + type_name(packed) + " as a packed array");
	}
	const state::PackedNode &node = state.packed(packed.ref);
	if (node.kind == Kind::PackedString) {
		if (!value.is_string_like()) {
			fail(std::string("find() of ") + type_name(value) + " in a PackedStringArray is not ported");
		}
		for (size_t index = 0; index < node.atoms.size(); ++index) {
			if (node.atoms[index] == value.ref) {
				return static_cast<int64_t>(index);
			}
		}
		return -1;
	}
	if (value.kind != Kind::Int) {
		fail(std::string("find() of ") + type_name(value) + " in a " + packed_base(node.kind) + " is not ported");
	}
	for (size_t index = 0; index < node.size(); ++index) {
		const int64_t element = node.kind == Kind::PackedByte ? static_cast<int64_t>(node.bytes[index]) : static_cast<int64_t>(node.ints[index]);
		if (element == value.i) {
			return static_cast<int64_t>(index);
		}
	}
	return -1;
}

const uint8_t *packed_bytes(const State &state, PackedRef packed) {
	const state::PackedNode &node = state.packed(packed);
	if (node.kind != Kind::PackedByte) {
		fail("packed_bytes of another packed array");
	}
	return node.bytes.data();
}

const int32_t *packed_ints(const State &state, PackedRef packed) {
	const state::PackedNode &node = state.packed(packed);
	if (node.kind != Kind::PackedInt32) {
		fail("packed_ints of another packed array");
	}
	return node.ints.data();
}

PackedRef utf8_buffer(State &state, Atom text) {
	const PackedRef bytes = state.new_packed(Kind::PackedByte);
	const std::string &source = state.text(text);
	state.packed_node(bytes).bytes.assign(source.begin(), source.end());
	return bytes;
}

PackedRef base64_to_raw(State &state, Atom text) {
	const std::string &source = state.text(text);
	if (source.size() % 4 != 0) {
		not_encoder_base64();
	}
	std::vector<uint8_t> decoded;
	decoded.reserve(source.size() / 4 * 3);
	for (size_t at = 0; at < source.size(); at += 4) {
		uint32_t group = 0;
		int padding = 0;
		for (int index = 0; index < 4; ++index) {
			const unsigned char c = static_cast<unsigned char>(source[at + static_cast<size_t>(index)]);
			// The encoder pads only the last group, with one or two '='.
			if (c == '=' && at + 4 == source.size() && index >= 2) {
				++padding;
				group <<= 6;
				continue;
			}
			const int digit = base64_digit(c);
			if (digit < 0 || padding > 0) {
				not_encoder_base64();
			}
			group = (group << 6) | static_cast<uint32_t>(digit);
		}
		decoded.push_back(static_cast<uint8_t>(group >> 16));
		if (padding < 2) {
			decoded.push_back(static_cast<uint8_t>(group >> 8));
		}
		if (padding < 1) {
			decoded.push_back(static_cast<uint8_t>(group));
		}
	}
	const PackedRef bytes = state.new_packed(Kind::PackedByte);
	state.packed_node(bytes).bytes = std::move(decoded);
	return bytes;
}

Atom join_strings(State &state, Atom separator, PackedRef strings) {
	const state::PackedNode &node = state.packed(strings);
	if (node.kind != Kind::PackedString) {
		fail("join() of a numeric packed array");
	}
	std::string joined;
	for (size_t index = 0; index < node.atoms.size(); ++index) {
		if (index != 0) {
			joined += state.text(separator);
		}
		joined += state.text(node.atoms[index]);
	}
	return state.intern(joined);
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
		case Kind::Vector3i:
			return a.i == b.i && a.z == b.z;
		case Kind::Dict:
			return dict_equal(state, a.ref, b.ref);
		case Kind::Array:
			return array_equal(state, a.ref, b.ref);
		case Kind::PackedByte:
		case Kind::PackedInt32:
		case Kind::PackedString:
			return packed_equal(state, a.ref, b.ref);
		default:
			fail(std::string("operator '==' on ") + type_name(a) + " is not ported");
	}
}

bool is_same(const State &state, const Value &a, const Value &b) {
	if (a.is_container() || b.is_container() || a.is_packed() || b.is_packed()) {
		return a.kind == b.kind && a.ref == b.ref;
	}
	return hash_compare(state, a, b);
}

int64_t ticks_usec() {
	return std::chrono::duration_cast<std::chrono::microseconds>(std::chrono::steady_clock::now().time_since_epoch()).count();
}

bool hash_compare(const State &state, const Value &a, const Value &b, bool semantic) {
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
		case Kind::Vector3i:
			return a.i == b.i && a.z == b.z;
		case Kind::Float:
			return a.f == b.f || (semantic && std::isnan(a.f) && std::isnan(b.f));
		case Kind::String:
		case Kind::StringName:
			return a.ref == b.ref;
		case Kind::Dict:
			return dict_equal(state, a.ref, b.ref);
		case Kind::Array:
			return array_equal(state, a.ref, b.ref);
		case Kind::PackedByte:
		case Kind::PackedInt32:
		case Kind::PackedString:
			return packed_equal(state, a.ref, b.ref);
		case Kind::Opaque:
			fail("hash_compare of an opaque value is not ported");
	}
	return false;
}

bool truthy(const State &state, const Value &value) {
	switch (value.kind) {
		case Kind::Nil:
			return false;
		case Kind::Bool:
			return value.b;
		case Kind::Int:
		case Kind::Vector2i:
			return value.i != 0;
		case Kind::Vector3i:
			return value.i != 0 || value.z != 0;
		case Kind::Float:
			return value.f != 0.0;
		case Kind::String:
		case Kind::StringName:
			return !state.text(value.ref).empty();
		case Kind::Array:
			return state.array_size(value.ref) != 0;
		case Kind::Dict:
			return state.dict_size(value.ref) != 0;
		case Kind::PackedByte:
		case Kind::PackedInt32:
		case Kind::PackedString:
			return state.packed(value.ref).size() != 0;
		case Kind::Opaque:
			return true;
	}
	return false;
}

bool is_equal_approx(double a, double b) {
	// Check for exact equality first, required to handle "infinity" values.
	if (a == b) {
		return true;
	}
	constexpr double kCmpEpsilon = 0.00001;
	double tolerance = kCmpEpsilon * std::abs(a);
	if (tolerance < kCmpEpsilon) {
		tolerance = kCmpEpsilon;
	}
	return std::abs(a - b) < tolerance;
}

int64_t int_field(const State &state, DictRef dict, Atom key, int64_t fallback) {
	return to_int(state, state.get(dict, Value::str(key), Value::of_int(fallback)));
}

double float_field(const State &state, DictRef dict, Atom key, double fallback) {
	return to_float(state.get(dict, Value::str(key), Value::of_float(fallback)));
}

bool bool_field(const State &state, DictRef dict, Atom key, bool fallback) {
	return to_bool(state.get(dict, Value::str(key), Value::of_bool(fallback)));
}

Atom string_field(const State &state, DictRef dict, Atom key, Atom fallback) {
	return to_string(state.get(dict, Value::str(key), Value::str(fallback)));
}

bool string_like_equal(const State &state, const Value &a, const Value &b) {
	if (a.is_string_like() && b.is_string_like()) {
		return a.ref == b.ref;
	}
	return hash_compare(state, a, b, true);
}

Value op_add(const Value &a, const Value &b) {
	if (a.kind == Kind::Int && b.kind == Kind::Int) {
		return Value::of_int(add(a.i, b.i));
	}
	if ((a.kind == Kind::Int || a.kind == Kind::Float) && (b.kind == Kind::Int || b.kind == Kind::Float)) {
		return Value::of_float(number(a).as_double() + number(b).as_double());
	}
	not_numbers("+", a, b);
}

Value op_sub(const Value &a, const Value &b) {
	if (a.kind == Kind::Int && b.kind == Kind::Int) {
		return Value::of_int(sub(a.i, b.i));
	}
	if ((a.kind == Kind::Int || a.kind == Kind::Float) && (b.kind == Kind::Int || b.kind == Kind::Float)) {
		return Value::of_float(number(a).as_double() - number(b).as_double());
	}
	not_numbers("-", a, b);
}

Value op_mul(const Value &a, const Value &b) {
	if (a.kind == Kind::Int && b.kind == Kind::Int) {
		return Value::of_int(mul(a.i, b.i));
	}
	if ((a.kind == Kind::Int || a.kind == Kind::Float) && (b.kind == Kind::Int || b.kind == Kind::Float)) {
		return Value::of_float(number(a).as_double() * number(b).as_double());
	}
	not_numbers("*", a, b);
}

Value op_div(const Value &a, const Value &b) {
	if (a.kind == Kind::Int && b.kind == Kind::Int) {
		if (b.i == 0) {
			fail("Division by zero error in operator '/'.");
		}
		if (b.i == -1 && a.i == INT64_MIN) {
			return Value::of_int(INT64_MIN);
		}
		return Value::of_int(a.i / b.i);
	}
	if ((a.kind == Kind::Int || a.kind == Kind::Float) && (b.kind == Kind::Int || b.kind == Kind::Float)) {
		return Value::of_float(number(a).as_double() / number(b).as_double());
	}
	not_numbers("/", a, b);
}

bool op_less(const Value &a, const Value &b) {
	if (a.kind == Kind::Int && b.kind == Kind::Int) {
		return a.i < b.i;
	}
	return compat::number_less(number(a), number(b));
}

bool op_greater(const Value &a, const Value &b) {
	if (a.kind == Kind::Int && b.kind == Kind::Int) {
		return a.i > b.i;
	}
	return compat::number_greater(number(a), number(b));
}

int64_t hash(const State &state, const Value &value) {
	return static_cast<int64_t>(recursive_hash(state, value, 0));
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

Items items(const State &state, const Value &value) {
	if (value.kind == Kind::Array) {
		return Items(state.array(value.ref).items);
	}
	if (value.kind == Kind::Dict) {
		return Items(state.dict(value.ref).keys.list());
	}
	if (value.kind == Kind::Int) {
		state::ValueList counted;
		for (int64_t index = 0; index < value.i; ++index) {
			counted.push_back(Value::of_int(index));
		}
		return Items(std::move(counted));
	}
	if (value.is_packed()) {
		const int64_t size = packed_size(state, value.ref);
		state::ValueList elements;
		elements.reserve(static_cast<size_t>(size));
		for (int64_t index = 0; index < size; ++index) {
			elements.push_back(packed_get(state, value, index));
		}
		return Items(std::move(elements));
	}
	fail(std::string("Iterating over ") + type_name(value) + " is not ported");
}

Items items(State &state, const Value &value) {
	if (value.kind == Kind::String) {
		const std::string text = state.text(value.ref);
		state::ValueList characters;
		for (size_t at = 0; at < text.size();) {
			const size_t length = std::min(utf8_length(static_cast<unsigned char>(text[at])), text.size() - at);
			characters.push_back(Value::str(state.intern(std::string_view(text).substr(at, length))));
			at += length;
		}
		return Items(std::move(characters));
	}
	return items(static_cast<const State &>(state), value);
}

Items field_items(const State &state, DictRef dict, const Value &key) {
	static const state::ValueList kNone;
	Value field;
	if (!state.lookup(dict, key, field)) {
		return Items(kNone);
	}
	return items(state, field);
}

Items field_items(State &state, DictRef dict, const Value &key) {
	static const state::ValueList kNone;
	Value field;
	if (!state.lookup(dict, key, field)) {
		return Items(kNone);
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

ArrayRef keys(State &state, DictRef dict) {
	const state::ValueList list = state.dict(dict).keys.list();
	const ArrayRef result = state.new_array();
	state.array_node(result).items = list;
	return result;
}

ArrayRef values(State &state, DictRef dict) {
	const state::ValueList list = state.dict(dict).values;
	const ArrayRef result = state.new_array();
	state.array_node(result).items = list;
	return result;
}

bool array_has(const State &state, ArrayRef array, const Value &value) {
	return array_find(state, array, value) >= 0;
}

int64_t array_find(const State &state, ArrayRef array, const Value &value) {
	const state::ValueList &list = state.array(array).items;
	for (size_t index = 0; index < list.size(); ++index) {
		if (string_like_equal(state, list[index], value)) {
			return static_cast<int64_t>(index);
		}
	}
	return -1;
}

bool in(const State &state, const Value &value, const Value &container) {
	if (container.kind == Kind::Dict) {
		return state.has(container.ref, value);
	}
	if (container.kind == Kind::Array) {
		return array_has(state, container.ref, value);
	}
	if (container.is_packed()) {
		return packed_find(state, container, value) >= 0;
	}
	fail(std::string("Invalid operands '") + type_name(value) + "' and '" + type_name(container) + "' in operator 'in'");
}

void insert(State &state, ArrayRef array, int64_t position, const Value &value) {
	state.insert_at(array, position, value);
}

void push_front(State &state, ArrayRef array, const Value &value) {
	state.insert_at(array, 0, value);
}

void remove_at(State &state, ArrayRef array, int64_t position) {
	state.remove_at(array, position);
}

Value pop_back(State &state, ArrayRef array) {
	return state.pop_at(array, false);
}

Value pop_front(State &state, ArrayRef array) {
	return state.pop_at(array, true);
}

ArrayRef concat(State &state, ArrayRef a, ArrayRef b) {
	state::ValueList joined = state.array(a).items;
	for (const Value &item : state.array(b).items) {
		joined.push_back(item);
	}
	const ArrayRef result = state.new_array();
	state.array_node(result).items = std::move(joined);
	return result;
}

void merge(State &state, DictRef dict, DictRef other, bool overwrite) {
	const state::DictNode &source = state.dict(other);
	// Copied first: dict and other may be the same node.
	const state::ValueList keys = source.keys.list();
	const state::ValueList values = source.values;
	for (size_t index = 0; index < keys.size(); ++index) {
		if (overwrite || !state.has(dict, keys[index])) {
			state.set(dict, keys[index], values[index]);
		}
	}
}

DictRef duplicate_dict(State &state, DictRef dict) {
	const DictRef copy = state.new_dict();
	const state::DictNode &source = state.dict(dict);
	state::DictNode &target = state.dict_node(copy);
	target.keys = source.keys;
	target.values = source.values;
	target.key_type = source.key_type;
	target.value_type = source.value_type;
	return copy;
}

ArrayRef duplicate_array(State &state, ArrayRef array) {
	const ArrayRef copy = state.new_array();
	const state::ArrayNode &source = state.array(array);
	state::ArrayNode &target = state.array_node(copy);
	target.items = source.items;
	target.element_type = source.element_type;
	return copy;
}

ArrayRef new_typed_array(State &state, uint8_t builtin) {
	const ArrayRef array = state.new_array();
	state.array_node(array).element_type = state.host().builtin_type(builtin);
	return array;
}

ArrayRef slice(State &state, ArrayRef array, int64_t begin64, int64_t end64) {
	// Array::slice takes ints: GDScript's int64 arrives truncated to 32 bits.
	const int begin_in = static_cast<int>(begin64);
	const int end_in = static_cast<int>(end64);
	const ArrayRef result = state.new_array();
	const state::ArrayNode &source = state.array(array);
	state.array_node(result).element_type = source.element_type;
	const int s = static_cast<int>(source.items.size());
	if (s == 0 || begin_in >= s) {
		return result;
	}
	int begin = begin_in < -s ? -s : (begin_in > s - 1 ? s - 1 : begin_in);
	if (begin < 0) {
		begin += s;
	}
	int end = end_in < -s - 1 ? -s - 1 : (end_in > s ? s : end_in);
	if (end < 0) {
		end += s;
	}
	if (begin > end) {
		state.print_error("Slice step is positive, but bounds are decreasing.");
		return result;
	}
	state::ValueList items;
	for (int index = begin; index < end; ++index) {
		items.push_back(source.items[static_cast<size_t>(index)]);
	}
	state.array_node(result).items = std::move(items);
	return result;
}

DictRef deep_duplicate_dict(State &state, DictRef dict) {
	return deep_dict(state, dict);
}

ArrayRef deep_duplicate_array(State &state, ArrayRef array) {
	return deep_array(state, array);
}

Value duplicate_value(State &state, const Value &value, bool deep) {
	if (value.kind == Kind::Dict) {
		return dict_value(deep ? deep_dict(state, value.ref) : duplicate_dict(state, value.ref));
	}
	if (value.kind == Kind::Array) {
		return array_value(deep ? deep_array(state, value.ref) : duplicate_array(state, value.ref));
	}
	if (value.is_packed()) {
		return Value::of_ref(value.kind, packed_duplicate(state, value.ref));
	}
	return value;
}

std::string format_pair(int64_t a, int64_t b) {
	return compat::itos(a) + "," + compat::itos(b);
}

const std::string &text(const State &state, const Value &value) {
	if (!value.is_string_like()) {
		not_a_string(value);
	}
	return state.text(value.ref);
}

Atom strip_edges(State &state, Atom atom) {
	const std::string &source = state.text(atom);
	size_t begin = 0;
	size_t end = source.size();
	// Code points up to 32 are single bytes in UTF-8.
	while (begin < end && static_cast<unsigned char>(source[begin]) <= 32) {
		++begin;
	}
	while (end > begin && static_cast<unsigned char>(source[end - 1]) <= 32) {
		--end;
	}
	if (begin == 0 && end == source.size()) {
		return atom;
	}
	return state.intern(std::string_view(source).substr(begin, end - begin));
}

bool begins_with(const State &state, Atom atom, Atom prefix) {
	const std::string &source = state.text(atom);
	const std::string &start = state.text(prefix);
	return source.size() >= start.size() && std::memcmp(source.data(), start.data(), start.size()) == 0;
}

bool ends_with(const State &state, Atom atom, Atom suffix) {
	const std::string &source = state.text(atom);
	const std::string &end = state.text(suffix);
	return source.size() >= end.size() && std::memcmp(source.data() + source.size() - end.size(), end.data(), end.size()) == 0;
}

Atom stringify(State &state, const Value &value) {
	switch (value.kind) {
		case Kind::Nil:
			return state.intern("<null>");
		case Kind::Bool:
			return state.intern(value.b ? "true" : "false");
		case Kind::Int:
			return state.intern(compat::itos(value.i));
		case Kind::String:
		case Kind::StringName:
			return value.ref;
		default:
			fail(std::string("String(") + type_name(value) + ") is not ported");
	}
}

Atom stringify_or_fallback(State &state, const Value &value) {
	switch (value.kind) {
		case Kind::Nil:
		case Kind::Bool:
		case Kind::Int:
		case Kind::String:
		case Kind::StringName:
			return stringify(state, value);
		default:
			throw state::NotPorted(std::string("left to GDScript: String(") + type_name(value) + ")");
	}
}

bool is_valid_int(const State &state, Atom atom) {
	return compat::is_valid_int(state.text(atom));
}

Atom format(State &state, Atom pattern, std::initializer_list<Value> values) {
	const std::string &source = state.text(pattern);
	std::string formatted;
	const char *problem = nullptr;
	size_t value_index = 0;
	bool in_format = false;
	for (const char c : source) {
		if (!in_format) {
			if (c == '%') {
				in_format = true;
			} else {
				formatted += c;
			}
			continue;
		}
		in_format = false;
		if (c == '%') {
			formatted += '%';
		} else if (c == 'd') {
			if (value_index >= values.size()) {
				problem = "not enough arguments for format string";
				break;
			}
			const Value &value = values.begin()[value_index];
			if (value.kind == Kind::Int) {
				formatted += compat::itos(value.i);
			} else if (value.kind == Kind::Float) {
				formatted += compat::itos(compat::float_to_int(value.f));
			} else {
				problem = "a number is required";
				break;
			}
			++value_index;
		} else if (c == 's') {
			if (value_index >= values.size()) {
				problem = "not enough arguments for format string";
				break;
			}
			formatted += state.text(stringify(state, values.begin()[value_index]));
			++value_index;
		} else {
			fail(std::string("String format %") + c + " is not ported");
		}
	}
	if (problem == nullptr && in_format) {
		problem = "incomplete format";
	}
	if (problem == nullptr && value_index != values.size()) {
		problem = "not all arguments converted during string formatting";
	}
	if (problem != nullptr) {
		state.print_error(std::string("String formatting error: ") + problem + ".");
		return pattern;
	}
	return state.intern(formatted);
}

Atom capitalize(State &state, Atom atom) {
	const std::string &source = state.text(atom);
	for (const char c : source) {
		if (static_cast<unsigned char>(c) >= 0x80) {
			fail("capitalize() of non-ASCII text is not ported");
		}
	}
	const auto is_upper = [](char c) { return c >= 'A' && c <= 'Z'; };
	const auto is_lower = [](char c) { return c >= 'a' && c <= 'z'; };
	const auto is_digit = [](char c) { return c >= '0' && c <= '9'; };
	// String::_separate_compound_words.
	std::string words;
	if (!source.empty()) {
		size_t start = 0;
		bool prev_upper = is_upper(source[0]);
		bool prev_lower = is_lower(source[0]);
		bool prev_digit = is_digit(source[0]);
		for (size_t i = 1; i < source.size(); ++i) {
			const bool upper = is_upper(source[i]);
			const bool lower = is_lower(source[i]);
			const bool digit = is_digit(source[i]);
			const bool next_lower = i + 1 < source.size() && is_lower(source[i + 1]);
			if ((prev_lower && upper) || ((prev_upper || prev_digit) && upper && next_lower) || (prev_digit && lower && next_lower) || ((prev_upper || prev_lower) && digit)) {
				words += source.substr(start, i - start) + " ";
				start = i;
			}
			prev_upper = upper;
			prev_lower = lower;
			prev_digit = digit;
		}
		words += source.substr(start);
		for (char &c : words) {
			if (c == ' ' || (c >= 0x09 && c <= 0x0d) || c == '_' || c == '-') {
				c = ' ';
			} else if (is_upper(c)) {
				c = static_cast<char>(c - 'A' + 'a');
			}
		}
	}
	words = state.text(strip_edges(state, state.intern(words)));
	// Each word with its first letter upper, joined by single spaces.
	std::string result;
	size_t index = 0;
	size_t begin = 0;
	while (begin <= words.size()) {
		size_t end = words.find(' ', begin);
		if (end == std::string::npos) {
			end = words.size();
		}
		std::string word = words.substr(begin, end - begin);
		if (!word.empty()) {
			if (is_lower(word[0])) {
				word[0] = static_cast<char>(word[0] - 'a' + 'A');
			}
			if (index > 0) {
				result += ' ';
			}
			result += word;
		}
		++index;
		begin = end + 1;
	}
	return state.intern(result);
}

Atom replace(State &state, Atom atom, Atom key, Atom with) {
	const std::string &source = state.text(atom);
	const std::string &find = state.text(key);
	if (find.empty() || source.empty()) {
		return atom;
	}
	// Byte search finds what Godot's code point search finds in valid UTF-8.
	std::string result;
	size_t from = 0;
	size_t found = source.find(find, from);
	if (found == std::string::npos) {
		return atom;
	}
	const std::string &replacement = state.text(with);
	while (found != std::string::npos) {
		result.append(source, from, found - from);
		result += replacement;
		from = found + find.size();
		found = source.find(find, from);
	}
	result.append(source, from, std::string::npos);
	return state.intern(result);
}

Atom trim_prefix(State &state, Atom atom, Atom prefix) {
	if (!begins_with(state, atom, prefix)) {
		return atom;
	}
	return state.intern(std::string_view(state.text(atom)).substr(state.text(prefix).size()));
}

// A Dictionary stands for the object it is a view of (a session the rules
// built, such as the AI's battle preview): its fields are the members, and a
// member it lacks is one the object lacks.
Value member(State &state, const Value &object, Atom property) {
	if (object.kind == Kind::Dict) {
		Value found;
		if (!state.lookup(object.ref, str(property), found)) {
			fail("Invalid access to property or key '" + state.text(property) + "' on a base object of type 'Object'.");
		}
		return found;
	}
	if (object.kind != Kind::Opaque) {
		fail("Invalid access to property or key '" + state.text(property) + "' on a base object of type '" + type_name(object) + "'.");
	}
	return state.host().object_get(state, object.ref, property);
}

void set_member(State &state, const Value &object, Atom property, const Value &value) {
	if (object.kind == Kind::Dict) {
		if (!state.has(object.ref, str(property))) {
			fail("Invalid assignment of property or key '" + state.text(property) + "' on a base object of type 'Object'.");
		}
		state.set(object.ref, str(property), value);
		return;
	}
	if (object.kind != Kind::Opaque) {
		fail("Invalid assignment of property or key '" + state.text(property) + "' on a base object of type '" + type_name(object) + "'.");
	}
	state.host().object_set(state, object.ref, property, value);
}

DictRef object_view(State &state, const Value &object) {
	if (object.kind == Kind::Dict) {
		return object.ref;
	}
	if (object.kind != Kind::Opaque) {
		fail(std::string("A view of a value of type '") + type_name(object) + "', which is not an object.");
	}
	return as_dict(state.host().object_view(state, object.ref));
}

Value view_object(State &state, DictRef view) {
	const Value object = state.host().view_object(state, view);
	if (object.kind != Kind::Opaque) {
		fail("A Dictionary that is no object's view stands for no object.");
	}
	return object;
}

namespace {

compat::GodotPcg rng_of(State &state, const Value &rng, uint64_t &seed) {
	uint64_t current = 0;
	if (rng.kind != Kind::Opaque || !state.host().rng_get(rng.ref, seed, current)) {
		fail(std::string("A RandomNumberGenerator is required, got ") + type_name(rng));
	}
	compat::GodotPcg pcg;
	pcg.set_state(current);
	return pcg;
}

} // namespace

int64_t rng_seed(State &state, const Value &rng) {
	uint64_t seed = 0;
	rng_of(state, rng, seed);
	return static_cast<int64_t>(seed);
}

int64_t rng_state(State &state, const Value &rng) {
	uint64_t seed = 0;
	return static_cast<int64_t>(rng_of(state, rng, seed).state());
}

int64_t rng_randi_range(State &state, const Value &rng, int64_t from, int64_t to) {
	uint64_t seed = 0;
	compat::GodotPcg pcg = rng_of(state, rng, seed);
	const int64_t rolled = pcg.randi_range(from, to);
	state.host().rng_set_state(rng.ref, pcg.state());
	return rolled;
}

Value rng_new(State &state, int64_t seed, int64_t rng_state) {
	return Value::of_ref(Kind::Opaque, state.host().rng_new(static_cast<uint64_t>(seed), static_cast<uint64_t>(rng_state)));
}

DictRef content_row(State &state, state::ContentTable table, Atom id) {
	const Value row = state.host().content_row(state, table, id);
	return row.kind == Kind::Dict ? row.ref : state.new_dict();
}

DictRef content_file(State &state, Atom path) {
	const Value data = state.host().content_file(state, path);
	return data.kind == Kind::Dict ? data.ref : state.new_dict();
}

namespace {

[[noreturn]] void json_not_ported(const std::string &what) {
	throw state::NotPorted("left to GDScript: JSON.stringify of " + what);
}

// "\"" + text.json_escape() + "\"": the backslash, \b \f \n \r \t \v and the
// quote.
void append_json_string(const std::string &source, std::string &out) {
	out += '"';
	for (const char c : source) {
		switch (c) {
			case '\\':
				out += "\\\\";
				break;
			case '\b':
				out += "\\b";
				break;
			case '\f':
				out += "\\f";
				break;
			case '\n':
				out += "\\n";
				break;
			case '\r':
				out += "\\r";
				break;
			case '\t':
				out += "\\t";
				break;
			case '\v':
				out += "\\v";
				break;
			case '"':
				out += "\\\"";
				break;
			default:
				if (static_cast<unsigned char>(c) < 0x20) {
					json_not_ported("a control character");
				}
				out += c;
				break;
		}
	}
	out += '"';
}

void append_json(const State &state, const Value &value, int depth, std::vector<Value> &open, std::string &out) {
	if (depth > 1024) {
		json_not_ported("a structure nested too deep");
	}
	switch (value.kind) {
		case Kind::Nil:
			out += "null";
			return;
		case Kind::Bool:
			out += value.b ? "true" : "false";
			return;
		case Kind::Int:
			out += compat::itos(value.i);
			return;
		case Kind::Float:
			out += compat::json_float(value.f);
			return;
		case Kind::String:
		case Kind::StringName:
			append_json_string(state.text(value.ref), out);
			return;
		case Kind::Vector2i:
			append_json_string("(" + compat::itos(value.vx()) + ", " + compat::itos(value.vy()) + ")", out);
			return;
		case Kind::Vector3i:
			append_json_string("(" + compat::itos(value.vx()) + ", " + compat::itos(value.vy()) + ", " + compat::itos(value.vz()) + ")", out);
			return;
		case Kind::Array: {
			for (const Value &container : open) {
				if (container.kind == value.kind && container.ref == value.ref) {
					json_not_ported("a circular Array");
				}
			}
			open.push_back(value);
			out += '[';
			const int64_t size = state.array_size(value.ref);
			for (int64_t index = 0; index < size; ++index) {
				if (index > 0) {
					out += ',';
				}
				append_json(state, state.at(value.ref, index), depth + 1, open, out);
			}
			out += ']';
			open.pop_back();
			return;
		}
		case Kind::Dict: {
			for (const Value &container : open) {
				if (container.kind == value.kind && container.ref == value.ref) {
					json_not_ported("a circular Dictionary");
				}
			}
			const state::DictNode &node = state.dict(value.ref);
			const state::ValueList keys = node.keys.list();
			const state::ValueList values = node.values;
			bool string_keys = true;
			bool int_keys = true;
			for (const Value &entry_key : keys) {
				string_keys = string_keys && entry_key.kind == Kind::String;
				int_keys = int_keys && entry_key.kind == Kind::Int;
			}
			if (!string_keys && !int_keys) {
				json_not_ported("a Dictionary with keys other than all Strings or all ints");
			}
			// Keys are distinct, so any sort gives Godot's order.
			std::vector<size_t> order(keys.size());
			for (size_t index = 0; index < order.size(); ++index) {
				order[index] = index;
			}
			if (string_keys) {
				std::sort(order.begin(), order.end(), [&](size_t a, size_t b) { return state.text(keys.begin()[a].ref) < state.text(keys.begin()[b].ref); });
			} else {
				std::sort(order.begin(), order.end(), [&](size_t a, size_t b) { return keys.begin()[a].i < keys.begin()[b].i; });
			}
			open.push_back(value);
			out += '{';
			for (size_t position = 0; position < order.size(); ++position) {
				if (position > 0) {
					out += ',';
				}
				const Value &entry_key = keys.begin()[order[position]];
				append_json_string(string_keys ? state.text(entry_key.ref) : compat::itos(entry_key.i), out);
				out += ':';
				append_json(state, values.begin()[order[position]], depth + 1, open, out);
			}
			out += '}';
			open.pop_back();
			return;
		}
		default:
			json_not_ported(type_name(value));
	}
}

} // namespace

std::string json_stringify(const State &state, const Value &value) {
	std::string json;
	std::vector<Value> open;
	append_json(state, value, 0, open, json);
	return json;
}

void push_warning(State &state, const std::string &text) {
	state.print_warning(text);
}

namespace {

uint32_t object_slot(State &state, const Value &object, Atom method) {
	if (object.kind == Kind::Dict) {
		return view_object(state, object.ref).ref;
	}
	if (object.kind == Kind::Nil) {
		fail("Cannot call method '" + state.text(method) + "' on a null value.");
	}
	if (object.kind != Kind::Opaque) {
		fail("Calling the method '" + state.text(method) + "' of a value of type '" + type_name(object) + "' is not ported.");
	}
	return object.ref;
}

} // namespace

Value call_method(State &state, const Value &object, Atom method, std::initializer_list<Value> args) {
	const uint32_t slot = object_slot(state, object, method);
	return state.host().object_call(state, slot, method, args.begin(), args.size());
}

bool has_method(State &state, const Value &object, Atom method) {
	return state.host().object_has_method(state, object_slot(state, object, state.intern("has_method")), method);
}

void set_property(State &state, const Value &object, Atom property, const Value &value) {
	const Atom set = state.intern("set");
	const Value args[] = { name_value(property), value };
	state.host().object_call(state, object_slot(state, object, set), set, args, 2);
}

Value class_instantiate(State &state, Atom name) {
	return state.host().class_instantiate(state, name);
}

Value autoload(State &state, Atom name) {
	const Value node = state.host().autoload(state, name);
	if (node.kind != Kind::Opaque) {
		fail("Identifier \"" + state.text(name) + "\" not declared: the autoload is not in the scene tree.");
	}
	return node;
}

bool file_exists(State &state, Atom path) {
	return state.host().file_exists(state, path);
}

int64_t file_length(State &state, Atom path) {
	return state.host().file_length(state, path);
}

int64_t file_modified_time(State &state, Atom path) {
	return state.host().file_modified_time(state, path);
}

bool dir_entries(State &state, Atom path, std::vector<std::pair<Atom, bool>> &out) {
	return state.host().dir_entries(state, path, out);
}

bool resource_exists(State &state, Atom path) {
	return state.host().resource_exists(state, path);
}

Atom os_environment(State &state, Atom name) {
	return state.host().os_environment(state, name);
}

bool os_has_feature(State &state, Atom name) {
	return state.host().os_has_feature(state, name);
}

Atom engine_json_stringify(State &state, const Value &value) {
	return state.host().json_stringify(state, value);
}

void refuse_gdscript_only_static(const State &state, Atom script, Atom name) {
	fail(state.text(script) + "." + state.text(name) + " is GDScript's own memo: a native port neither reads nor fills it (its table's gdscript_only)");
}

Value call_static(State &state, Atom script, Atom function, std::initializer_list<Value> args) {
	const std::string name = port::host_name(state.text(script), state.text(function));
	const port::Host *host = port::find_host(name);
	if (host == nullptr) {
		fail(name + ": a host call to a function no table lists as a host (port::Table::hosts)");
	}
	if (static_cast<size_t>(host->arity) != args.size()) {
		fail(name + ": a host call with " + std::to_string(args.size()) + " arguments, its table says " + std::to_string(host->arity));
	}
	if (host->pure) {
		return state.host().call_pure(state, script, function, args.begin(), args.size());
	}
	return state.host().call_static(state, script, function, args.begin(), args.size());
}

} // namespace aurelion::rules::gd
