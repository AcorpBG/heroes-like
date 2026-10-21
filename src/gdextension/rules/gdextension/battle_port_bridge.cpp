#include "battle_port_bridge.hpp"

#include "battle_state_bridge.hpp"

#include "aurelion_rules/compat/godot_string.hpp"

#include <godot_cpp/classes/engine.hpp>
#include <godot_cpp/classes/global_constants.hpp>
#include <godot_cpp/classes/node.hpp>
#include <godot_cpp/classes/random_number_generator.hpp>
#include <godot_cpp/classes/ref_counted.hpp>
#include <godot_cpp/classes/scene_tree.hpp>
#include <godot_cpp/classes/window.hpp>
#include <godot_cpp/core/object.hpp>
#include <godot_cpp/variant/node_path.hpp>
#include <godot_cpp/variant/typed_array.hpp>
#include <godot_cpp/variant/utility_functions.hpp>
#include <godot_cpp/variant/vector2i.hpp>

#include <cmath>
#include <cstdio>
#include <cstring>
#include <string_view>
#include <unordered_map>

namespace aurelion::rules::bridge {

using godot::Array;
using godot::CharString;
using godot::Dictionary;
using godot::Object;
using godot::RandomNumberGenerator;
using godot::Ref;
using godot::String;
using godot::StringName;
using godot::Variant;
using godot::Vector2i;
using state::Kind;
using state::Value;

namespace {

// Strings a long run interns past this are dropped with the atoms at the next
// call's start.
constexpr size_t kAtomLimit = size_t(1) << 20;

std::string utf8_of(const String &text) {
	const CharString utf8 = text.utf8();
	return std::string(utf8.get_data(), static_cast<size_t>(utf8.length()));
}

std::string describe(const Variant &value) {
	std::string text = utf8_of(Variant::get_type_name(value.get_type())) + " " + utf8_of(value.stringify());
	if (text.size() > 160) {
		text.resize(157);
		text += "...";
	}
	return text;
}

bool same_float(double a, double b) {
	if (std::isnan(a) && std::isnan(b)) {
		return true;
	}
	return std::memcmp(&a, &b, sizeof(double)) == 0;
}

} // namespace

PortBridge::PortBridge() {
	state_.set_backing(this);
}

void PortBridge::begin() {
	if (state_.atom_count() > kAtomLimit) {
		state_.clear();
		string_cache_.clear();
		name_cache_.clear();
	} else {
		state_.clear_nodes();
	}
	array_sources_.clear();
	dict_sources_.clear();
	array_nodes_.clear();
	dict_nodes_.clear();
	opaque_.clear();
	content_.clear();
	exported_arrays_.clear();
	exported_dicts_.clear();
}

state::TypeRef PortBridge::register_type(int64_t builtin, const StringName &class_name, const Variant &script) {
	for (size_t index = 0; index < types_.size(); ++index) {
		const TypeInfo &known = types_[index];
		if (known.builtin == builtin && known.class_name == class_name && known.script == script) {
			return static_cast<state::TypeRef>(index + 1);
		}
	}
	types_.push_back(TypeInfo{ static_cast<uint32_t>(builtin), class_name, script });
	const state::TypeRef type = static_cast<state::TypeRef>(types_.size());
	state_.set_type_builtin(type, static_cast<uint8_t>(builtin));
	return type;
}

namespace {

class ShadowCopier {
public:
	Variant copy(const Variant &value) {
		switch (value.get_type()) {
			case Variant::ARRAY: {
				const Array source = value;
				const uint64_t id = identity_of(source);
				const auto found = arrays_.find(id);
				if (found != arrays_.end()) {
					return found->second;
				}
				// duplicate() keeps the typing; the items are copied in place.
				Array made = source.duplicate(false);
				arrays_.emplace(id, made);
				const int64_t size = source.size();
				for (int64_t index = 0; index < size; ++index) {
					made[index] = copy(source[index]);
				}
				return made;
			}
			case Variant::DICTIONARY: {
				const Dictionary source = value;
				const uint64_t id = identity_of(source);
				const auto found = dicts_.find(id);
				if (found != dicts_.end()) {
					return found->second;
				}
				Dictionary made = source.duplicate(false);
				dicts_.emplace(id, made);
				const Array keys = source.keys();
				const int64_t size = keys.size();
				for (int64_t index = 0; index < size; ++index) {
					made[keys[index]] = copy(source[keys[index]]);
				}
				return made;
			}
			case Variant::OBJECT:
				return copy_object(value);
			default:
				return value;
		}
	}

private:
	Variant copy_object(const Variant &value) {
		Object *object = value;
		if (object == nullptr) {
			return value;
		}
		const uint64_t id = object->get_instance_id();
		const auto found = objects_.find(id);
		if (found != objects_.end()) {
			return found->second;
		}
		if (RandomNumberGenerator *rng = Object::cast_to<RandomNumberGenerator>(object)) {
			Ref<RandomNumberGenerator> made;
			made.instantiate();
			made->set_seed(rng->get_seed());
			made->set_state(rng->get_state());
			const Variant result = made;
			objects_.emplace(id, result);
			return result;
		}
		const Variant script = object->get_script();
		Object *script_object = script;
		if (script_object == nullptr || Object::cast_to<godot::RefCounted>(object) == nullptr) {
			return value;
		}
		const Variant result = script_object->call(StringName("new"));
		Object *made = result;
		if (made == nullptr) {
			throw state::ScriptError("cannot make a new instance of an argument's script for the shadow copy");
		}
		objects_.emplace(id, result);
		const godot::TypedArray<Dictionary> properties = object->get_property_list();
		for (int64_t index = 0; index < properties.size(); ++index) {
			const Dictionary property = properties[index];
			if ((static_cast<int64_t>(property["usage"]) & godot::PROPERTY_USAGE_SCRIPT_VARIABLE) == 0) {
				continue;
			}
			const StringName name = property["name"];
			made->set(name, copy(object->get(name)));
		}
		return result;
	}

	std::unordered_map<uint64_t, Variant> arrays_;
	std::unordered_map<uint64_t, Variant> dicts_;
	std::unordered_map<uint64_t, Variant> objects_;
};

} // namespace

Array copy_for_shadow(const Array &args) {
	ShadowCopier copier;
	return copier.copy(args);
}

Object *PortBridge::object_at(uint32_t slot) const {
	if (slot >= opaque_.size() || opaque_[slot].get_type() != Variant::OBJECT) {
		return nullptr;
	}
	return static_cast<Object *>(opaque_[slot]);
}

Value PortBridge::object_get(state::State &state, uint32_t slot, uint32_t property) {
	Object *object = object_at(slot);
	if (object == nullptr) {
		throw state::ScriptError("Invalid access to property '" + state.text(property) + "' on a value that is not an object");
	}
	const std::string &name = state.text(property);
	const Variant found = object->get(StringName(String::utf8(name.data(), static_cast<int64_t>(name.size()))));
	return load(found);
}

bool PortBridge::rng_get(uint32_t slot, uint64_t &seed, uint64_t &state) {
	RandomNumberGenerator *rng = Object::cast_to<RandomNumberGenerator>(object_at(slot));
	if (rng == nullptr) {
		return false;
	}
	seed = rng->get_seed();
	state = rng->get_state();
	return true;
}

void PortBridge::rng_set_state(uint32_t slot, uint64_t state) {
	RandomNumberGenerator *rng = Object::cast_to<RandomNumberGenerator>(object_at(slot));
	if (rng == nullptr) {
		throw state::ScriptError("Invalid call: set_state on a value that is not a RandomNumberGenerator");
	}
	rng->set_state(state);
}

uint32_t PortBridge::rng_new(uint64_t seed, uint64_t state) {
	Ref<RandomNumberGenerator> rng;
	rng.instantiate();
	rng->set_seed(seed);
	rng->set_state(state);
	opaque_.push_back(Variant(rng));
	return static_cast<uint32_t>(opaque_.size() - 1);
}

Object *PortBridge::content_service() {
	Object *known = godot::ObjectDB::get_instance(content_service_);
	if (known != nullptr) {
		return known;
	}
	godot::SceneTree *tree = Object::cast_to<godot::SceneTree>(godot::Engine::get_singleton()->get_main_loop());
	godot::Node *node = tree != nullptr && tree->get_root() != nullptr ? tree->get_root()->get_node_or_null(godot::NodePath("ContentService")) : nullptr;
	if (node == nullptr) {
		throw state::ScriptError("Identifier \"ContentService\" not declared: the autoload is not in the scene tree");
	}
	content_service_ = node->get_instance_id();
	return node;
}

Value PortBridge::content_row(state::State &state, state::ContentTable table, uint32_t id) {
	const char *method = "get_unit";
	switch (table) {
		case state::ContentTable::Unit:
			method = "get_unit";
			break;
		case state::ContentTable::Hero:
			method = "get_hero";
			break;
		case state::ContentTable::Faction:
			method = "get_faction";
			break;
		case state::ContentTable::Spell:
			method = "get_spell";
			break;
		case state::ContentTable::Artifact:
			method = "get_artifact";
			break;
		case state::ContentTable::ResourceSite:
			method = "get_resource_site";
			break;
		case state::ContentTable::Building:
			method = "get_building";
			break;
		case state::ContentTable::Town:
			method = "get_town";
			break;
		case state::ContentTable::MapObject:
			method = "get_map_object";
			break;
		case state::ContentTable::Encounter:
			method = "get_encounter";
			break;
		case state::ContentTable::ArmyGroup:
			method = "get_army_group";
			break;
		case state::ContentTable::Scenario:
			method = "get_scenario_readonly";
			break;
	}
	const uint64_t memo = (static_cast<uint64_t>(table) + 1) << 32 | id;
	const auto found = content_.find(memo);
	if (found != content_.end()) {
		return found->second;
	}
	const std::string &text = state.text(id);
	const Variant row = content_service()->call(StringName(method), String::utf8(text.data(), static_cast<int64_t>(text.size())));
	const Value loaded = load(row);
	if (loaded.kind == Kind::Dict && state.dict_size(loaded.ref) != 0) {
		content_.emplace(memo, loaded);
	}
	return loaded;
}

Value PortBridge::content_file(state::State &state, uint32_t path) {
	const uint64_t memo = path;
	const auto found = content_.find(memo);
	if (found != content_.end()) {
		return found->second;
	}
	const std::string &text = state.text(path);
	const Variant data = content_service()->call(StringName("load_json"), String::utf8(text.data(), static_cast<int64_t>(text.size())));
	const Value loaded = load(data);
	if (loaded.kind == Kind::Dict && state.dict_size(loaded.ref) != 0) {
		content_.emplace(memo, loaded);
	}
	return loaded;
}

void PortBridge::print_error(const std::string &text) {
	godot::UtilityFunctions::push_error(String::utf8(text.data(), static_cast<int64_t>(text.size())));
}

void PortBridge::print_warning(const std::string &text) {
	godot::UtilityFunctions::push_warning(String::utf8(text.data(), static_cast<int64_t>(text.size())));
}

bool PortBridge::same_type(state::TypeRef type, int64_t builtin, const StringName &class_name, const Variant &script) const {
	if (type == 0) {
		return false;
	}
	const TypeInfo &known = types_[type - 1];
	return known.builtin == builtin && known.class_name == class_name && known.script == script;
}

Value PortBridge::load_string(const String &text, Kind kind) {
	const CharString utf8 = text.utf8();
	return Value::of_ref(kind, state_.intern(std::string_view(utf8.get_data(), static_cast<size_t>(utf8.length()))));
}

Value PortBridge::load(const Variant &value) {
	switch (value.get_type()) {
		case Variant::NIL:
			return Value();
		case Variant::BOOL:
			return Value::of_bool(static_cast<bool>(value));
		case Variant::INT:
			return Value::of_int(static_cast<int64_t>(value));
		case Variant::FLOAT:
			return Value::of_float(static_cast<double>(value));
		case Variant::STRING:
			return load_string(static_cast<String>(value), Kind::String);
		case Variant::STRING_NAME:
			return load_string(static_cast<String>(value), Kind::StringName);
		case Variant::VECTOR2I: {
			const Vector2i vector = value;
			return Value::of_vector2i(vector.x, vector.y);
		}
		case Variant::ARRAY: {
			const Array array = value;
			const uint64_t id = identity_of(array);
			const auto found = array_nodes_.find(id);
			if (found != array_nodes_.end()) {
				return Value::of_ref(Kind::Array, found->second);
			}
			const uint32_t node = state_.new_array();
			array_nodes_.emplace(id, node);
			if (array_sources_.size() <= node) {
				array_sources_.resize(node + 1);
			}
			array_sources_[node] = array;
			state::ArrayNode &target = state_.array_node(node);
			target.backed = true;
			if (array.is_typed()) {
				target.element_type = register_type(array.get_typed_builtin(), array.get_typed_class_name(), array.get_typed_script());
			}
			target.read_only = array.is_read_only();
			return Value::of_ref(Kind::Array, node);
		}
		case Variant::DICTIONARY: {
			const Dictionary dict = value;
			const uint64_t id = identity_of(dict);
			const auto found = dict_nodes_.find(id);
			if (found != dict_nodes_.end()) {
				return Value::of_ref(Kind::Dict, found->second);
			}
			const uint32_t node = state_.new_dict();
			dict_nodes_.emplace(id, node);
			if (dict_sources_.size() <= node) {
				dict_sources_.resize(node + 1);
			}
			dict_sources_[node] = dict;
			state::DictNode &target = state_.dict_node(node);
			target.backed = true;
			if (dict.is_typed_key()) {
				target.key_type = register_type(dict.get_typed_key_builtin(), dict.get_typed_key_class_name(), dict.get_typed_key_script());
			}
			if (dict.is_typed_value()) {
				target.value_type = register_type(dict.get_typed_value_builtin(), dict.get_typed_value_class_name(), dict.get_typed_value_script());
			}
			target.read_only = dict.is_read_only();
			return Value::of_ref(Kind::Dict, node);
		}
		default:
			opaque_.push_back(value);
			return Value::of_ref(Kind::Opaque, static_cast<uint32_t>(opaque_.size() - 1));
	}
}

void PortBridge::fill_array(state::State &state, uint32_t node) {
	const Array source = *array_sources_[node];
	const int64_t size = source.size();
	state::ValueList items;
	items.resize(static_cast<size_t>(size));
	for (int64_t index = 0; index < size; ++index) {
		const Variant item = source[index];
		items[static_cast<size_t>(index)] = load(item);
	}
	state.array_node(node).items = std::move(items);
}

void PortBridge::fill_dict(state::State &state, uint32_t node) {
	const Dictionary source = *dict_sources_[node];
	const Array keys = source.keys();
	const Array values = source.values();
	const int64_t size = keys.size();
	state::ValueList node_keys;
	node_keys.resize(static_cast<size_t>(size));
	state::ValueList node_values;
	node_values.resize(static_cast<size_t>(size));
	for (int64_t index = 0; index < size; ++index) {
		const Variant key = keys[index];
		const Variant value = values[index];
		node_keys[static_cast<size_t>(index)] = load(key);
		node_values[static_cast<size_t>(index)] = load(value);
	}
	state::DictNode &target = state.dict_node(node);
	target.keys = std::move(node_keys);
	target.values = std::move(node_values);
}

int64_t PortBridge::array_size(uint32_t node) {
	return array_sources_[node]->size();
}

Value PortBridge::array_at(state::State &, uint32_t node, int64_t index) {
	const Array source = *array_sources_[node];
	const Variant item = source[index];
	return load(item);
}

int64_t PortBridge::dict_size(uint32_t node) {
	return dict_sources_[node]->size();
}

bool PortBridge::dict_lookup(state::State &, uint32_t node, const Value &key, Value &out) {
	const Dictionary source = *dict_sources_[node];
	const Variant key_value = export_value(key);
	if (!source.has(key_value)) {
		return false;
	}
	const Variant found = source.get(key_value, Variant());
	out = load(found);
	return true;
}

const Variant &PortBridge::string_variant(uint32_t atom, bool name) {
	std::vector<Variant> &cache = name ? name_cache_ : string_cache_;
	if (cache.size() <= atom) {
		cache.resize(state_.atom_count());
	}
	Variant &slot = cache[atom];
	if (slot.get_type() == Variant::NIL) {
		const std::string &text = state_.text(atom);
		const String value = String::utf8(text.data(), static_cast<int64_t>(text.size()));
		slot = name ? Variant(StringName(value)) : Variant(value);
	}
	return slot;
}

Array PortBridge::fresh_array(const state::ArrayNode &node) const {
	Array array;
	if (node.element_type != 0) {
		const TypeInfo &type = types_[node.element_type - 1];
		array.set_typed(type.builtin, type.class_name, type.script);
	}
	return array;
}

Dictionary PortBridge::fresh_dict(const state::DictNode &node) const {
	if (node.key_type == 0 && node.value_type == 0) {
		return Dictionary();
	}
	const TypeInfo untyped;
	const TypeInfo &key = node.key_type != 0 ? types_[node.key_type - 1] : untyped;
	const TypeInfo &value = node.value_type != 0 ? types_[node.value_type - 1] : untyped;
	return Dictionary(Dictionary(), key.builtin, key.class_name, key.script, value.builtin, value.class_name, value.script);
}

Variant PortBridge::export_value(const Value &value) {
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
			return string_variant(value.ref, false);
		case Kind::StringName:
			return string_variant(value.ref, true);
		case Kind::Vector2i:
			return Variant(Vector2i(value.vx(), value.vy()));
		case Kind::Array: {
			const uint32_t node = value.ref;
			if (node < array_sources_.size() && array_sources_[node]) {
				return *array_sources_[node];
			}
			const auto done = exported_arrays_.find(node);
			if (done != exported_arrays_.end()) {
				return done->second;
			}
			const state::ArrayNode &source = state_.array(node);
			Array target = fresh_array(source);
			exported_arrays_.emplace(node, target);
			for (const Value &item : source.items) {
				target.append(export_value(item));
			}
			if (source.read_only) {
				target.make_read_only();
			}
			return target;
		}
		case Kind::Dict: {
			const uint32_t node = value.ref;
			if (node < dict_sources_.size() && dict_sources_[node]) {
				return *dict_sources_[node];
			}
			const auto done = exported_dicts_.find(node);
			if (done != exported_dicts_.end()) {
				return done->second;
			}
			const state::DictNode &source = state_.dict(node);
			Dictionary target = fresh_dict(source);
			exported_dicts_.emplace(node, target);
			for (size_t index = 0; index < source.keys.size(); ++index) {
				target[export_value(source.keys[index])] = export_value(source.values[index]);
			}
			if (source.read_only) {
				target.make_read_only();
			}
			return target;
		}
		case Kind::Opaque:
			return opaque_[value.ref];
	}
	return Variant();
}

void PortBridge::write_back() {
	for (uint32_t node = 0; node < array_sources_.size(); ++node) {
		if (!array_sources_[node] || !state_.array_node(node).dirty) {
			continue;
		}
		Array target = *array_sources_[node];
		if (target.is_read_only()) {
			// set() and append() refuse a read-only node, so nothing should get here.
			throw state::ScriptError("native wrote into a read-only Array");
		}
		const state::ArrayNode &source = state_.array_node(node);
		std::vector<Variant> items(source.items.size());
		for (size_t index = 0; index < items.size(); ++index) {
			items[index] = export_value(source.items[index]);
		}
		target.resize(static_cast<int64_t>(items.size()));
		for (size_t index = 0; index < items.size(); ++index) {
			target.set(static_cast<int64_t>(index), items[index]);
		}
	}
	for (uint32_t node = 0; node < dict_sources_.size(); ++node) {
		if (!dict_sources_[node] || !state_.dict_node(node).dirty) {
			continue;
		}
		Dictionary target = *dict_sources_[node];
		if (target.is_read_only()) {
			throw state::ScriptError("native wrote into a read-only Dictionary");
		}
		const state::DictNode &source = state_.dict_node(node);
		std::vector<Variant> keys(source.keys.size());
		std::vector<Variant> values(source.keys.size());
		for (size_t index = 0; index < keys.size(); ++index) {
			keys[index] = export_value(source.keys[index]);
			values[index] = export_value(source.values[index]);
		}
		fill_dict_in_place(target, source, state_, keys, values);
	}
}

bool PortBridge::changed_a_source() const {
	for (uint32_t node = 0; node < array_sources_.size(); ++node) {
		if (array_sources_[node] && state_.array_node(node).dirty) {
			return true;
		}
	}
	for (uint32_t node = 0; node < dict_sources_.size(); ++node) {
		if (dict_sources_[node] && state_.dict_node(node).dirty) {
			return true;
		}
	}
	return false;
}

std::string PortBridge::diff(const Value &native, const Variant &gdscript) {
	matched_arrays_.clear();
	matched_dicts_.clear();
	std::string path = "result";
	std::string out;
	diff_value(native, gdscript, path, out);
	return out;
}

void PortBridge::diff_value(const Value &native, const Variant &gdscript, std::string &path, std::string &out) {
	if (!out.empty()) {
		return;
	}
	const Variant::Type type = gdscript.get_type();
	const auto mismatch = [&](const std::string &native_text) {
		out = path + ": native " + native_text + ", GDScript " + describe(gdscript);
	};
	switch (native.kind) {
		case Kind::Nil:
			if (type != Variant::NIL) {
				mismatch("null");
			}
			return;
		case Kind::Bool:
			if (type != Variant::BOOL || static_cast<bool>(gdscript) != native.b) {
				mismatch(native.b ? "bool true" : "bool false");
			}
			return;
		case Kind::Int:
			if (type != Variant::INT || static_cast<int64_t>(gdscript) != native.i) {
				mismatch("int " + compat::itos(native.i));
			}
			return;
		case Kind::Float: {
			if (type != Variant::FLOAT || !same_float(static_cast<double>(gdscript), native.f)) {
				char text[64];
				std::snprintf(text, sizeof(text), "float %.17g", native.f);
				mismatch(text);
			}
			return;
		}
		case Kind::String:
		case Kind::StringName: {
			const bool name = native.kind == Kind::StringName;
			if (type != (name ? Variant::STRING_NAME : Variant::STRING) || utf8_of(static_cast<String>(gdscript)) != state_.text(native.ref)) {
				mismatch(std::string(name ? "StringName " : "String ") + state_.text(native.ref));
			}
			return;
		}
		case Kind::Vector2i: {
			if (type != Variant::VECTOR2I) {
				mismatch("Vector2i");
				return;
			}
			const Vector2i vector = gdscript;
			if (vector.x != native.vx() || vector.y != native.vy()) {
				mismatch("Vector2i (" + compat::itos(native.vx()) + ", " + compat::itos(native.vy()) + ")");
			}
			return;
		}
		case Kind::Array: {
			if (type != Variant::ARRAY) {
				mismatch("Array");
				return;
			}
			const Array array = gdscript;
			const uint64_t id = identity_of(array);
			const uint32_t node = native.ref;
			if (node < array_sources_.size() && array_sources_[node]) {
				if (identity_of(*array_sources_[node]) != id) {
					mismatch("an Array it was given");
				}
				return;
			}
			const auto seen = matched_arrays_.find(node);
			if (seen != matched_arrays_.end()) {
				if (seen->second != id) {
					mismatch("the Array it returned before here");
				}
				return;
			}
			for (const auto &pair : matched_arrays_) {
				if (pair.second == id) {
					mismatch("another new Array where GDScript repeats one");
					return;
				}
			}
			matched_arrays_.emplace(node, id);
			if (array_nodes_.count(id) != 0) {
				mismatch("a new Array where GDScript returns one it was given");
				return;
			}
			const state::ArrayNode &source = state_.array(node);
			const bool typed = source.element_type != 0;
			if (typed != array.is_typed() || (typed && !same_type(source.element_type, array.get_typed_builtin(), array.get_typed_class_name(), array.get_typed_script()))) {
				mismatch(typed ? "a typed Array" : "an untyped Array");
				return;
			}
			if (source.read_only != array.is_read_only()) {
				mismatch(source.read_only ? "a read-only Array" : "a writable Array");
				return;
			}
			if (static_cast<int64_t>(source.items.size()) != array.size()) {
				mismatch("an Array of " + compat::itos(static_cast<int64_t>(source.items.size())));
				return;
			}
			const size_t length = path.size();
			for (size_t index = 0; index < source.items.size() && out.empty(); ++index) {
				path += "[" + compat::itos(static_cast<int64_t>(index)) + "]";
				const Variant item = array[static_cast<int64_t>(index)];
				diff_value(source.items[index], item, path, out);
				path.resize(length);
			}
			return;
		}
		case Kind::Dict: {
			if (type != Variant::DICTIONARY) {
				mismatch("Dictionary");
				return;
			}
			const Dictionary dict = gdscript;
			const uint64_t id = identity_of(dict);
			const uint32_t node = native.ref;
			if (node < dict_sources_.size() && dict_sources_[node]) {
				if (identity_of(*dict_sources_[node]) != id) {
					mismatch("a Dictionary it was given");
				}
				return;
			}
			const auto seen = matched_dicts_.find(node);
			if (seen != matched_dicts_.end()) {
				if (seen->second != id) {
					mismatch("the Dictionary it returned before here");
				}
				return;
			}
			for (const auto &pair : matched_dicts_) {
				if (pair.second == id) {
					mismatch("another new Dictionary where GDScript repeats one");
					return;
				}
			}
			matched_dicts_.emplace(node, id);
			if (dict_nodes_.count(id) != 0) {
				mismatch("a new Dictionary where GDScript returns one it was given");
				return;
			}
			const state::DictNode &source = state_.dict(node);
			const bool key_typed = source.key_type != 0;
			const bool value_typed = source.value_type != 0;
			if (key_typed != dict.is_typed_key() || value_typed != dict.is_typed_value() ||
					(key_typed && !same_type(source.key_type, dict.get_typed_key_builtin(), dict.get_typed_key_class_name(), dict.get_typed_key_script())) ||
					(value_typed && !same_type(source.value_type, dict.get_typed_value_builtin(), dict.get_typed_value_class_name(), dict.get_typed_value_script()))) {
				mismatch("a Dictionary typed otherwise");
				return;
			}
			if (source.read_only != dict.is_read_only()) {
				mismatch(source.read_only ? "a read-only Dictionary" : "a writable Dictionary");
				return;
			}
			if (static_cast<int64_t>(source.keys.size()) != dict.size()) {
				mismatch("a Dictionary of " + compat::itos(static_cast<int64_t>(source.keys.size())) + " keys");
				return;
			}
			const Array keys = dict.keys();
			const Array values = dict.values();
			const size_t length = path.size();
			for (size_t index = 0; index < source.keys.size() && out.empty(); ++index) {
				const Variant key = keys[static_cast<int64_t>(index)];
				path += ".keys()[" + compat::itos(static_cast<int64_t>(index)) + "]";
				diff_value(source.keys[index], key, path, out);
				path.resize(length);
				if (!out.empty()) {
					break;
				}
				path += source.keys[index].is_string_like() ? "." + state_.text(source.keys[index].ref) : "[" + compat::itos(static_cast<int64_t>(index)) + "]";
				const Variant value = values[static_cast<int64_t>(index)];
				diff_value(source.values[index], value, path, out);
				path.resize(length);
			}
			return;
		}
		case Kind::Opaque:
			if (opaque_[native.ref] != gdscript) {
				mismatch(describe(opaque_[native.ref]));
			}
			return;
	}
}

} // namespace aurelion::rules::bridge
