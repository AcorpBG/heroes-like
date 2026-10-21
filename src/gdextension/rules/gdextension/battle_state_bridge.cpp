#include "battle_state_bridge.hpp"

#include <cstring>

#include <godot_cpp/variant/vector2i.hpp>
#include <string_view>

namespace aurelion::rules::bridge {

using godot::Array;
using godot::CharString;
using godot::Dictionary;
using godot::String;
using godot::StringName;
using godot::Variant;
using state::Kind;
using state::Value;

namespace {

enum class Probe {
	Known,
	Absent,
	Unknown,
};

// The state's Value for a key Dictionary.keys() returned, without adding atoms.
// Absent: certainly not a key of the state. Unknown: the key cannot be matched
// here (a container or opaque key), so the caller rebuilds the Dictionary.
Probe probe_key(const Variant &key, const state::State &state, Value &out) {
	switch (key.get_type()) {
		case Variant::NIL:
			out = Value();
			return Probe::Known;
		case Variant::BOOL:
			out = Value::of_bool(static_cast<bool>(key));
			return Probe::Known;
		case Variant::INT:
			out = Value::of_int(static_cast<int64_t>(key));
			return Probe::Known;
		case Variant::FLOAT:
			out = Value::of_float(static_cast<double>(key));
			return Probe::Known;
		case Variant::STRING:
		case Variant::STRING_NAME: {
			const CharString utf8 = static_cast<String>(key).utf8();
			uint32_t atom = 0;
			if (!state.find_atom(std::string_view(utf8.get_data(), static_cast<size_t>(utf8.length())), atom)) {
				return Probe::Absent;
			}
			out = Value::of_ref(key.get_type() == Variant::STRING ? Kind::String : Kind::StringName, atom);
			return Probe::Known;
		}
		default:
			return Probe::Unknown;
	}
}

int64_t find_key(const Value &key, const state::DictNode &node) {
	return node.keys.find(key);
}

} // namespace

// An Array or Dictionary is a pointer to the engine's shared data.
static_assert(sizeof(Array) == sizeof(uint64_t), "Array is one pointer");
static_assert(sizeof(Dictionary) == sizeof(uint64_t), "Dictionary is one pointer");

uint64_t identity_of(const Array &array) {
	uint64_t id = 0;
	std::memcpy(&id, array._native_ptr(), sizeof(id));
	return id;
}

uint64_t identity_of(const Dictionary &dict) {
	uint64_t id = 0;
	std::memcpy(&id, dict._native_ptr(), sizeof(id));
	return id;
}

// A Variant is its type, then its data aligned to 8 bytes; a packed array's
// data is the pointer to its PackedArrayRef.
static_assert(sizeof(Variant) >= 16, "Variant holds a type and an 8-byte aligned data block");

uint64_t identity_of_packed(const Variant &packed) {
	uint64_t id = 0;
	std::memcpy(&id, reinterpret_cast<const uint8_t *>(packed._native_ptr()) + 8, sizeof(id));
	return id;
}

Variant packed_variant(const state::State &state, const state::PackedNode &node) {
	switch (node.kind) {
		case Kind::PackedByte: {
			godot::PackedByteArray bytes;
			bytes.resize(static_cast<int64_t>(node.bytes.size()));
			if (!node.bytes.empty()) {
				std::memcpy(bytes.ptrw(), node.bytes.data(), node.bytes.size());
			}
			return bytes;
		}
		case Kind::PackedString: {
			godot::PackedStringArray strings;
			strings.resize(static_cast<int64_t>(node.atoms.size()));
			for (size_t index = 0; index < node.atoms.size(); ++index) {
				const std::string &text = state.text(node.atoms[index]);
				strings.set(static_cast<int64_t>(index), String::utf8(text.data(), static_cast<int64_t>(text.size())));
			}
			return strings;
		}
		default: {
			godot::PackedInt32Array ints;
			ints.resize(static_cast<int64_t>(node.ints.size()));
			if (!node.ints.empty()) {
				std::memcpy(ints.ptrw(), node.ints.data(), node.ints.size() * sizeof(int32_t));
			}
			return ints;
		}
	}
}

void fill_packed_node(state::State &state, state::PackedNode &node, const Variant &packed) {
	switch (node.kind) {
		case Kind::PackedByte: {
			const godot::PackedByteArray bytes = packed;
			node.bytes.assign(bytes.ptr(), bytes.ptr() + bytes.size());
			break;
		}
		case Kind::PackedString: {
			const godot::PackedStringArray strings = packed;
			node.atoms.resize(static_cast<size_t>(strings.size()));
			for (int64_t index = 0; index < strings.size(); ++index) {
				const CharString utf8 = strings[index].utf8();
				node.atoms[static_cast<size_t>(index)] = state.intern(std::string_view(utf8.get_data(), static_cast<size_t>(utf8.length())));
			}
			break;
		}
		default: {
			const godot::PackedInt32Array ints = packed;
			node.ints.assign(ints.ptr(), ints.ptr() + ints.size());
			break;
		}
	}
}

bool StateBridge::fail(const std::string &message) {
	if (error_.empty()) {
		error_ = message;
	}
	return false;
}

bool StateBridge::load(const Variant &root, state::State &state) {
	state.clear();
	source_arrays_.clear();
	source_dicts_.clear();
	array_nodes_.clear();
	dict_nodes_.clear();
	opaque_.clear();
	types_.clear();
	string_cache_.clear();
	name_cache_.clear();
	counts_ = LoadCounts();
	error_.clear();
	state.root = load_value(root, state);
	return error_.empty();
}

Value StateBridge::load_value(const Variant &value, state::State &state) {
	const Variant::Type type = value.get_type();
	++counts_.values;
	++counts_.by_type[type];
	switch (type) {
		case Variant::NIL:
			return Value();
		case Variant::BOOL:
			return Value::of_bool(static_cast<bool>(value));
		case Variant::INT:
			return Value::of_int(static_cast<int64_t>(value));
		case Variant::FLOAT:
			return Value::of_float(static_cast<double>(value));
		case Variant::STRING:
			return load_string(static_cast<String>(value), Kind::String, state);
		case Variant::STRING_NAME:
			return load_string(static_cast<String>(value), Kind::StringName, state);
		case Variant::VECTOR2I: {
			const godot::Vector2i vector = value;
			return Value::of_vector2i(vector.x, vector.y);
		}
		case Variant::VECTOR3I: {
			const godot::Vector3i vector = value;
			return Value::of_vector3i(vector.x, vector.y, vector.z);
		}
		case Variant::ARRAY:
			return load_array(static_cast<Array>(value), state);
		case Variant::DICTIONARY:
			return load_dict(static_cast<Dictionary>(value), state);
		default:
			opaque_.push_back(value);
			return Value::of_ref(Kind::Opaque, static_cast<uint32_t>(opaque_.size() - 1));
	}
}

Value StateBridge::load_string(const String &text, Kind kind, state::State &state) {
	const CharString utf8 = text.utf8();
	return Value::of_ref(kind, state.intern(std::string_view(utf8.get_data(), static_cast<size_t>(utf8.length()))));
}

state::TypeRef StateBridge::register_type(int64_t builtin, const StringName &class_name, const Variant &script) {
	for (size_t index = 0; index < types_.size(); ++index) {
		const TypeInfo &known = types_[index];
		if (known.builtin == builtin && known.class_name == class_name && known.script == script) {
			return static_cast<state::TypeRef>(index + 1);
		}
	}
	types_.push_back(TypeInfo{ static_cast<uint32_t>(builtin), class_name, script });
	return static_cast<state::TypeRef>(types_.size());
}

Value StateBridge::load_array(const Array &array, state::State &state) {
	const uint64_t id = identity_of(array);
	const auto found = array_nodes_.find(id);
	if (found != array_nodes_.end()) {
		++counts_.shared_refs;
		return Value::of_ref(Kind::Array, found->second);
	}
	const uint32_t node = state.new_array();
	array_nodes_.emplace(id, node);
	source_arrays_.push_back(array);
	state::ArrayNode &target = state.array_node(node);
	if (array.is_typed()) {
		target.element_type = register_type(array.get_typed_builtin(), array.get_typed_class_name(), array.get_typed_script());
		state.set_type_builtin(target.element_type, static_cast<uint8_t>(array.get_typed_builtin()));
	}
	target.read_only = array.is_read_only();
	const int64_t size = array.size();
	target.items.resize(static_cast<size_t>(size));
	for (int64_t index = 0; index < size; ++index) {
		const Value item = load_value(array[index], state);
		state.array_node(node).items[static_cast<size_t>(index)] = item;
	}
	return Value::of_ref(Kind::Array, node);
}

Value StateBridge::load_dict(const Dictionary &dict, state::State &state) {
	const uint64_t id = identity_of(dict);
	const auto found = dict_nodes_.find(id);
	if (found != dict_nodes_.end()) {
		++counts_.shared_refs;
		return Value::of_ref(Kind::Dict, found->second);
	}
	const uint32_t node = state.new_dict();
	dict_nodes_.emplace(id, node);
	source_dicts_.push_back(dict);
	state::DictNode &target = state.dict_node(node);
	if (dict.is_typed_key()) {
		target.key_type = register_type(dict.get_typed_key_builtin(), dict.get_typed_key_class_name(), dict.get_typed_key_script());
		state.set_type_builtin(target.key_type, static_cast<uint8_t>(dict.get_typed_key_builtin()));
	}
	if (dict.is_typed_value()) {
		target.value_type = register_type(dict.get_typed_value_builtin(), dict.get_typed_value_class_name(), dict.get_typed_value_script());
		state.set_type_builtin(target.value_type, static_cast<uint8_t>(dict.get_typed_value_builtin()));
	}
	target.read_only = dict.is_read_only();
	const Array keys = dict.keys();
	const Array values = dict.values();
	const int64_t size = keys.size();
	target.keys.reserve(static_cast<size_t>(size));
	target.values.reserve(static_cast<size_t>(size));
	for (int64_t index = 0; index < size; ++index) {
		const Value key = load_value(keys[index], state);
		const Value value = load_value(values[index], state);
		state.dict_node(node).keys.push_back(key);
		state.dict_node(node).values.push_back(value);
	}
	return Value::of_ref(Kind::Dict, node);
}

bool StateBridge::overwrite(const Variant &source, state::State &state) {
	error_.clear();
	counts_ = LoadCounts();
	merge_arrays_.clear();
	merge_dicts_.clear();
	array_taken_.assign(state.array_count(), false);
	dict_taken_.assign(state.dict_count(), false);
	state.root = merge_value(source, state.root, state);
	return error_.empty();
}

Value StateBridge::merge_value(const Variant &source, const Value &existing, state::State &state) {
	const Variant::Type type = source.get_type();
	if (type == Variant::ARRAY) {
		++counts_.values;
		++counts_.by_type[type];
		const Array array = static_cast<Array>(source);
		const uint64_t id = identity_of(array);
		const auto found = merge_arrays_.find(id);
		if (found != merge_arrays_.end()) {
			++counts_.shared_refs;
			return Value::of_ref(Kind::Array, found->second);
		}
		const state::TypeRef element_type = array.is_typed() ? register_type(array.get_typed_builtin(), array.get_typed_class_name(), array.get_typed_script()) : 0;
		uint32_t node = 0;
		state::ValueList old_items;
		if (existing.kind == Kind::Array && existing.ref < array_taken_.size() && !array_taken_[existing.ref] && state.array(existing.ref).element_type == element_type) {
			node = existing.ref;
			old_items = state.array(node).items;
		} else {
			node = state.new_array();
			state.array_node(node).element_type = element_type;
		}
		if (node >= array_taken_.size()) {
			array_taken_.resize(node + 1, false);
		}
		array_taken_[node] = true;
		merge_arrays_.emplace(id, node);
		const int64_t size = array.size();
		state::ValueList items;
		items.resize(static_cast<size_t>(size));
		for (int64_t index = 0; index < size; ++index) {
			const Value old_item = static_cast<size_t>(index) < old_items.size() ? old_items[static_cast<size_t>(index)] : Value();
			items[static_cast<size_t>(index)] = merge_value(array[index], old_item, state);
		}
		state.array_node(node).items = std::move(items);
		state.array_node(node).read_only = array.is_read_only();
		return Value::of_ref(Kind::Array, node);
	}
	if (type == Variant::DICTIONARY) {
		++counts_.values;
		++counts_.by_type[type];
		const Dictionary dict = static_cast<Dictionary>(source);
		const uint64_t id = identity_of(dict);
		const auto found = merge_dicts_.find(id);
		if (found != merge_dicts_.end()) {
			++counts_.shared_refs;
			return Value::of_ref(Kind::Dict, found->second);
		}
		const state::TypeRef key_type = dict.is_typed_key() ? register_type(dict.get_typed_key_builtin(), dict.get_typed_key_class_name(), dict.get_typed_key_script()) : 0;
		const state::TypeRef value_type = dict.is_typed_value() ? register_type(dict.get_typed_value_builtin(), dict.get_typed_value_class_name(), dict.get_typed_value_script()) : 0;
		uint32_t node = 0;
		state::DictNode old;
		if (existing.kind == Kind::Dict && existing.ref < dict_taken_.size() && !dict_taken_[existing.ref] && state.dict(existing.ref).key_type == key_type && state.dict(existing.ref).value_type == value_type) {
			node = existing.ref;
			old.keys = state.dict(node).keys;
			old.values = state.dict(node).values;
		} else {
			node = state.new_dict();
			state.dict_node(node).key_type = key_type;
			state.dict_node(node).value_type = value_type;
		}
		if (node >= dict_taken_.size()) {
			dict_taken_.resize(node + 1, false);
		}
		dict_taken_[node] = true;
		merge_dicts_.emplace(id, node);
		const Array keys = dict.keys();
		const Array values = dict.values();
		const int64_t size = keys.size();
		state::ValueList new_keys;
		new_keys.resize(static_cast<size_t>(size));
		state::ValueList new_values;
		new_values.resize(static_cast<size_t>(size));
		for (int64_t index = 0; index < size; ++index) {
			const Value key = merge_value(keys[index], Value(), state);
			const int64_t old_index = find_key(key, old);
			const Value old_value = old_index >= 0 ? old.values[static_cast<size_t>(old_index)] : Value();
			new_keys[static_cast<size_t>(index)] = key;
			new_values[static_cast<size_t>(index)] = merge_value(values[index], old_value, state);
		}
		state.dict_node(node).keys = std::move(new_keys);
		state.dict_node(node).values = std::move(new_values);
		state.dict_node(node).read_only = dict.is_read_only();
		return Value::of_ref(Kind::Dict, node);
	}
	return load_value(source, state);
}

void StateBridge::begin_write(const state::State &state) {
	written_arrays_.assign(state.array_count(), Variant());
	written_dicts_.assign(state.dict_count(), Variant());
	array_written_.assign(state.array_count(), false);
	dict_written_.assign(state.dict_count(), false);
	if (string_cache_.size() < state.atom_count()) {
		string_cache_.resize(state.atom_count());
		name_cache_.resize(state.atom_count());
	}
	reused_arrays_ = 0;
	reused_dicts_ = 0;
	rebuilt_dicts_ = 0;
}

Variant StateBridge::store_in_place(const state::State &state) {
	begin_write(state);
	return write_value(state.root, state, true);
}

Variant StateBridge::export_copy(const state::State &state) {
	begin_write(state);
	return write_value(state.root, state, false);
}

const Variant &StateBridge::string_variant(uint32_t atom, bool name, const state::State &state) {
	std::vector<Variant> &cache = name ? name_cache_ : string_cache_;
	Variant &slot = cache[atom];
	if (slot.get_type() == Variant::NIL) {
		const std::string &text = state.text(atom);
		const String value = String::utf8(text.data(), static_cast<int64_t>(text.size()));
		slot = name ? Variant(StringName(value)) : Variant(value);
	}
	return slot;
}

Variant StateBridge::write_value(const Value &value, const state::State &state, bool in_place) {
	switch (value.kind) {
		case Kind::Nil:
			return Variant();
		case Kind::Bool:
			return Variant(value.b);
		case Kind::Int:
			return Variant(value.i);
		case Kind::Float:
			return Variant(value.f);
		case Kind::String:
			return string_variant(value.ref, false, state);
		case Kind::StringName:
			return string_variant(value.ref, true, state);
		case Kind::Vector2i:
			return Variant(godot::Vector2i(value.vx(), value.vy()));
		case Kind::Vector3i:
			return Variant(godot::Vector3i(value.vx(), value.vy(), value.vz()));
		case Kind::Array:
			return write_array(value.ref, state, in_place);
		case Kind::Dict:
			return write_dict(value.ref, state, in_place);
		case Kind::PackedByte:
		case Kind::PackedInt32:
		case Kind::PackedString:
			// The battle state holds no packed arrays: load() keeps any as opaque.
			return packed_variant(state, state.packed(value.ref));
		case Kind::Opaque:
			return opaque_[value.ref];
	}
	return Variant();
}

Array StateBridge::fresh_array(const state::ArrayNode &node) const {
	Array array;
	if (node.element_type != 0) {
		const TypeInfo &type = types_[node.element_type - 1];
		array.set_typed(type.builtin, type.class_name, type.script);
	}
	return array;
}

Dictionary StateBridge::fresh_dict(const state::DictNode &node) const {
	if (node.key_type == 0 && node.value_type == 0) {
		return Dictionary();
	}
	// The typed constructor: godot-cpp declares set_typed only when version.hpp
	// came first.
	const TypeInfo untyped;
	const TypeInfo &key = node.key_type != 0 ? types_[node.key_type - 1] : untyped;
	const TypeInfo &value = node.value_type != 0 ? types_[node.value_type - 1] : untyped;
	return Dictionary(Dictionary(), key.builtin, key.class_name, key.script, value.builtin, value.class_name, value.script);
}

Variant StateBridge::write_array(uint32_t node, const state::State &state, bool in_place) {
	if (array_written_[node]) {
		return written_arrays_[node];
	}
	const state::ArrayNode &source = state.array(node);
	const bool reuse = in_place && node < source_arrays_.size();
	Array target = reuse ? source_arrays_[node] : fresh_array(source);
	written_arrays_[node] = target;
	array_written_[node] = true;
	const size_t size = source.items.size();
	std::vector<Variant> items(size);
	for (size_t index = 0; index < size; ++index) {
		items[index] = write_value(source.items[index], state, in_place);
	}
	if (reuse) {
		++reused_arrays_;
		if (target.is_read_only()) {
			return target;
		}
	}
	if (target.size() != static_cast<int64_t>(size)) {
		target.resize(static_cast<int64_t>(size));
	}
	for (size_t index = 0; index < size; ++index) {
		target.set(static_cast<int64_t>(index), items[index]);
	}
	if (!reuse && source.read_only) {
		target.make_read_only();
	}
	return target;
}

Variant StateBridge::write_dict(uint32_t node, const state::State &state, bool in_place) {
	if (dict_written_[node]) {
		return written_dicts_[node];
	}
	const state::DictNode &source = state.dict(node);
	const bool reuse = in_place && node < source_dicts_.size();
	Dictionary target = reuse ? source_dicts_[node] : fresh_dict(source);
	written_dicts_[node] = target;
	dict_written_[node] = true;
	const size_t size = source.keys.size();
	std::vector<Variant> keys(size);
	std::vector<Variant> values(size);
	for (size_t index = 0; index < size; ++index) {
		keys[index] = write_value(source.keys[index], state, in_place);
		values[index] = write_value(source.values[index], state, in_place);
	}
	if (reuse) {
		++reused_dicts_;
		if (!target.is_read_only() && fill_dict_in_place(target, source, state, keys, values)) {
			++rebuilt_dicts_;
		}
		return target;
	}
	for (size_t index = 0; index < size; ++index) {
		target[keys[index]] = values[index];
	}
	if (source.read_only) {
		target.make_read_only();
	}
	return target;
}

bool fill_dict_in_place(Dictionary &dict, const state::DictNode &node, const state::State &state, const std::vector<Variant> &keys, const std::vector<Variant> &values) {
	const size_t count = node.keys.size();
	const Array current = dict.keys();
	const int64_t current_size = current.size();
	// Where each present key sits in the state's order (-1: dropped).
	std::vector<int64_t> positions(static_cast<size_t>(current_size), -1);
	bool same_order = current_size == static_cast<int64_t>(count);
	bool rebuild = false;
	for (int64_t index = 0; index < current_size && !rebuild; ++index) {
		Value probe;
		switch (probe_key(current[index], state, probe)) {
			case Probe::Absent:
				same_order = false;
				continue;
			case Probe::Unknown:
				rebuild = true;
				continue;
			case Probe::Known:
				break;
		}
		if (same_order && state::same_key(probe, node.keys[static_cast<size_t>(index)])) {
			positions[static_cast<size_t>(index)] = index;
			continue;
		}
		same_order = false;
		positions[static_cast<size_t>(index)] = find_key(probe, node);
	}
	if (!rebuild && !same_order) {
		// The kept keys must already be the state's first keys, in its order.
		int64_t next = 0;
		for (int64_t index = 0; index < current_size; ++index) {
			const int64_t position = positions[static_cast<size_t>(index)];
			if (position < 0) {
				continue;
			}
			if (position != next) {
				rebuild = true;
				break;
			}
			++next;
		}
	}
	if (rebuild) {
		dict.clear();
	} else if (!same_order) {
		for (int64_t index = 0; index < current_size; ++index) {
			if (positions[static_cast<size_t>(index)] < 0) {
				dict.erase(current[index]);
			}
		}
	}
	for (size_t index = 0; index < count; ++index) {
		dict[keys[index]] = values[index];
	}
	return rebuild;
}

} // namespace aurelion::rules::bridge
