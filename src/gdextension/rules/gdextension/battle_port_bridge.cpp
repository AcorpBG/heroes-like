#include "battle_port_bridge.hpp"

#include "battle_state_bridge.hpp"
#include "content_host.hpp"

#include "aurelion_rules/compat/godot_string.hpp"
#include "aurelion_rules/port/gd.hpp"
#include "aurelion_rules/port/registry.hpp"

#include <godot_cpp/classes/class_db_singleton.hpp>
#include <godot_cpp/classes/dir_access.hpp>
#include <godot_cpp/classes/engine.hpp>
#include <godot_cpp/classes/file_access.hpp>
#include <godot_cpp/classes/global_constants.hpp>
#include <godot_cpp/classes/json.hpp>
#include <godot_cpp/classes/node.hpp>
#include <godot_cpp/classes/os.hpp>
#include <godot_cpp/classes/project_settings.hpp>
#include <godot_cpp/classes/random_number_generator.hpp>
#include <godot_cpp/classes/ref_counted.hpp>
#include <godot_cpp/classes/resource.hpp>
#include <godot_cpp/classes/resource_loader.hpp>
#include <godot_cpp/classes/scene_tree.hpp>
#include <godot_cpp/classes/time.hpp>
#include <godot_cpp/classes/window.hpp>
#include <godot_cpp/core/object.hpp>
#include <godot_cpp/variant/node_path.hpp>
#include <godot_cpp/variant/typed_array.hpp>
#include <godot_cpp/variant/utility_functions.hpp>
#include <godot_cpp/variant/vector2i.hpp>
#include <godot_cpp/variant/vector3i.hpp>

#include <algorithm>
#include <cmath>
#include <cstdio>
#include <cstring>
#include <deque>
#include <string_view>
#include <unordered_map>
#include <utility>

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
using godot::Vector3i;
using state::Kind;
using state::Value;

namespace {

// Strings a long run interns past this are dropped with the atoms at the next
// call's start.
constexpr size_t kAtomLimit = size_t(1) << 20;
// And past this many bytes of text: a save's JSON text is one atom of
// megabytes, which no later save interns again.
constexpr size_t kAtomBytesLimit = size_t(64) << 20;

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

Kind packed_kind(Variant::Type type) {
	switch (type) {
		case Variant::PACKED_BYTE_ARRAY:
			return Kind::PackedByte;
		case Variant::PACKED_STRING_ARRAY:
			return Kind::PackedString;
		default:
			return Kind::PackedInt32;
	}
}

Variant::Type packed_type(Kind kind) {
	switch (kind) {
		case Kind::PackedByte:
			return Variant::PACKED_BYTE_ARRAY;
		case Kind::PackedString:
			return Variant::PACKED_STRING_ARRAY;
		default:
			return Variant::PACKED_INT32_ARRAY;
	}
}

// The elements of a packed Variant and a node of the same kind are equal.
bool same_elements(const state::State &state, const state::PackedNode &node, const Variant &packed) {
	switch (node.kind) {
		case Kind::PackedByte: {
			const godot::PackedByteArray bytes = packed;
			return static_cast<size_t>(bytes.size()) == node.bytes.size() && (node.bytes.empty() || std::memcmp(bytes.ptr(), node.bytes.data(), node.bytes.size()) == 0);
		}
		case Kind::PackedString: {
			const godot::PackedStringArray strings = packed;
			if (static_cast<size_t>(strings.size()) != node.atoms.size()) {
				return false;
			}
			for (size_t index = 0; index < node.atoms.size(); ++index) {
				if (utf8_of(strings[static_cast<int64_t>(index)]) != state.text(node.atoms[index])) {
					return false;
				}
			}
			return true;
		}
		default: {
			const godot::PackedInt32Array ints = packed;
			return static_cast<size_t>(ints.size()) == node.ints.size() && (node.ints.empty() || std::memcmp(ints.ptr(), node.ints.data(), node.ints.size() * sizeof(int32_t)) == 0);
		}
	}
}

// Two values of a container as it was loaded and as it is now: the same type
// and value, a container or object the very same one.
bool same_variant(const Variant &a, const Variant &b) {
	const Variant::Type type = a.get_type();
	if (type != b.get_type()) {
		return false;
	}
	switch (type) {
		case Variant::ARRAY:
			return identity_of(Array(a)) == identity_of(Array(b));
		case Variant::DICTIONARY:
			return identity_of(Dictionary(a)) == identity_of(Dictionary(b));
		case Variant::PACKED_BYTE_ARRAY:
		case Variant::PACKED_INT32_ARRAY:
		case Variant::PACKED_STRING_ARRAY:
			return identity_of_packed(a) == identity_of_packed(b);
		case Variant::FLOAT:
			return same_float(static_cast<double>(a), static_cast<double>(b));
		default:
			return a == b;
	}
}

// The items of an Array as it was loaded and as it is now.
bool same_items(const Array &before, const Array &now) {
	const int64_t size = before.size();
	if (size != now.size()) {
		return false;
	}
	for (int64_t index = 0; index < size; ++index) {
		if (!same_variant(before[index], now[index])) {
			return false;
		}
	}
	return true;
}

// The keys, in order, and values of a Dictionary as it was loaded and as it is now.
bool same_entries(const Dictionary &before, const Dictionary &now) {
	if (before.size() != now.size()) {
		return false;
	}
	const Array before_keys = before.keys();
	const Array now_keys = now.keys();
	if (!same_items(before_keys, now_keys)) {
		return false;
	}
	return same_items(before.values(), now.values());
}

} // namespace

PortBridge::PortBridge() {
	state_.set_backing(this);
}

void PortBridge::begin(bool validating, bool host_calls) {
	if (state_.atom_count() > kAtomLimit || state_.atom_bytes() > kAtomBytesLimit) {
		state_.clear();
		string_cache_.clear();
		name_cache_.clear();
	}
	end();
	validating_ = validating;
	host_calls_ = host_calls && !validating;
	host_calls_made_.clear();
	full_host_calls_ = 0;
	undo_lost_ = false;
}

void PortBridge::end() {
	state_.clear_nodes();
	array_sources_.clear();
	dict_sources_.clear();
	array_nodes_.clear();
	dict_nodes_.clear();
	packed_sources_.clear();
	packed_nodes_.clear();
	opaque_.clear();
	views_.clear();
	content_.clear();
	content_revision_ = -1;
	exported_arrays_.clear();
	exported_dicts_.clear();
	exported_packed_.clear();
	statics_.clear();
	static_slots_.clear();
	memo_shapes_.clear();
	undo_arrays_.clear();
	undo_dicts_.clear();
	undo_packed_.clear();
	undo_statics_.clear();
	undo_array_kept_.clear();
	undo_dict_kept_.clear();
	undo_packed_kept_.clear();
	array_snapshots_.clear();
	dict_snapshots_.clear();
	packed_snapshots_.clear();
	rng_states_.clear();
	made_rngs_.clear();
}

void PortBridge::begin_kept() {
	const bool keeps = kept_ && state_.atom_count() <= kAtomLimit && state_.atom_bytes() <= kAtomBytesLimit
			&& content_host()->revision() == kept_revision_;
	// Until this call ends in keep().
	kept_ = false;
	if (!keeps) {
		begin(false, true);
		return;
	}
	// As begin(false, true), but the nodes, their containers, the content rows
	// and the opaque values stay.
	views_.clear();
	content_revision_ = -1;
	exported_arrays_.clear();
	exported_dicts_.clear();
	exported_packed_.clear();
	statics_.clear();
	static_slots_.clear();
	memo_shapes_.clear();
	validating_ = false;
	host_calls_ = true;
	host_calls_made_.clear();
	full_host_calls_ = 0;
	undo_lost_ = false;
	undo_arrays_.clear();
	undo_dicts_.clear();
	undo_packed_.clear();
	undo_statics_.clear();
	undo_array_kept_.clear();
	undo_dict_kept_.clear();
	undo_packed_kept_.clear();
	array_snapshots_.clear();
	dict_snapshots_.clear();
	packed_snapshots_.clear();
	rng_states_.clear();
	made_rngs_.clear();
}

namespace {

// A compaction's new numbers (State::compact) for the nodes' sources, moved
// down in place as the nodes were, and for the identities that find them.
template <typename Source>
void renumber_sources(std::vector<std::optional<Source>> &sources, const std::vector<uint32_t> &map, size_t kept) {
	const size_t end = std::min(sources.size(), map.size());
	for (size_t node = 0; node < end; ++node) {
		const uint32_t to = map[node];
		if (to == state::State::kDropped) {
			sources[node].reset();
		} else if (to != node) {
			sources[to] = std::move(sources[node]);
			sources[node].reset();
		}
	}
	sources.resize(kept);
}

void renumber_identities(std::unordered_map<uint64_t, uint32_t> &nodes, const std::vector<uint32_t> &map) {
	for (auto entry = nodes.begin(); entry != nodes.end();) {
		const uint32_t to = entry->second < map.size() ? map[entry->second] : state::State::kDropped;
		if (to == state::State::kDropped) {
			entry = nodes.erase(entry);
		} else {
			entry->second = to;
			++entry;
		}
	}
}

} // namespace

Variant PortBridge::keep(const Value &result, const Value *args, size_t count) {
	write_back();
	const Variant exported = export_value(result);
	adopt_exported();
	std::vector<Value> roots(args, args + count);
	for (const ObjectView &view : views_) {
		roots.push_back(Value::of_ref(Kind::Dict, view.node));
	}
	for (const auto &row : content_) {
		roots.push_back(row.second);
	}
	views_.clear();
	const state::State::Compaction maps = state_.compact(roots, opaque_.size());
	renumber_sources(array_sources_, maps.arrays, state_.array_count());
	renumber_sources(dict_sources_, maps.dicts, state_.dict_count());
	renumber_sources(packed_sources_, maps.packeds, state_.packed_count());
	renumber_identities(array_nodes_, maps.arrays);
	renumber_identities(dict_nodes_, maps.dicts);
	renumber_identities(packed_nodes_, maps.packeds);
	size_t kept_slots = 0;
	for (size_t slot = 0; slot < maps.opaques.size(); ++slot) {
		if (maps.opaques[slot] != state::State::kDropped) {
			if (kept_slots != slot) {
				opaque_[kept_slots] = std::move(opaque_[slot]);
			}
			++kept_slots;
		}
	}
	opaque_.resize(kept_slots);
	for (auto &row : content_) {
		row.second.ref = maps.dicts[row.second.ref];
	}
	kept_revision_ = content_host()->revision();
	kept_ = true;
	return exported;
}

void PortBridge::reread(const Variant &container) {
	if (!kept_) {
		return;
	}
	switch (container.get_type()) {
		case Variant::ARRAY: {
			const Array array = container;
			const auto found = array_nodes_.find(identity_of(array));
			if (found != array_nodes_.end()) {
				state_.array_node(found->second).reset();
				back_array(found->second, array);
			}
			break;
		}
		case Variant::DICTIONARY: {
			const Dictionary dict = container;
			const auto found = dict_nodes_.find(identity_of(dict));
			if (found != dict_nodes_.end()) {
				state_.dict_node(found->second).reset();
				back_dict(found->second, dict);
			}
			break;
		}
		case Variant::PACKED_BYTE_ARRAY:
		case Variant::PACKED_INT32_ARRAY:
		case Variant::PACKED_STRING_ARRAY: {
			const auto found = packed_nodes_.find(identity_of_packed(container));
			if (found != packed_nodes_.end()) {
				state_.packed_node(found->second).reset();
				back_packed(found->second, container);
			}
			break;
		}
		default:
			break;
	}
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
			case Variant::PACKED_BYTE_ARRAY:
			case Variant::PACKED_INT32_ARRAY:
			case Variant::PACKED_STRING_ARRAY: {
				// One array however many Variants hold it: one copy.
				const uint64_t id = identity_of_packed(value);
				const auto found = packeds_.find(id);
				if (found != packeds_.end()) {
					return found->second;
				}
				const Variant made = value.duplicate();
				packeds_.emplace(id, made);
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
	std::unordered_map<uint64_t, Variant> packeds_;
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
	if (const ObjectView *view = view_of(slot)) {
		Value found;
		if (std::find(view->fields.begin(), view->fields.end(), property) != view->fields.end() && state.lookup(view->node, Value::str(property), found)) {
			return found;
		}
	}
	Object *object = object_at(slot);
	if (object == nullptr) {
		throw state::ScriptError("Invalid access to property '" + state.text(property) + "' on a value that is not an object");
	}
	const std::string &name = state.text(property);
	const Variant found = object->get(StringName(String::utf8(name.data(), static_cast<int64_t>(name.size()))));
	return load(found);
}

const PortBridge::ObjectView *PortBridge::view_of(uint32_t slot) const {
	for (const ObjectView &view : views_) {
		if (view.slot == slot) {
			return &view;
		}
	}
	return nullptr;
}

Value PortBridge::object_view(state::State &state, uint32_t slot) {
	if (const ObjectView *known = view_of(slot)) {
		return Value::of_ref(Kind::Dict, known->node);
	}
	Object *object = object_at(slot);
	if (object == nullptr) {
		throw state::ScriptError("A view of a value that is not an object");
	}
	ObjectView view;
	view.slot = slot;
	view.node = state.new_dict();
	view.meta = state.new_dict();
	const godot::TypedArray<Dictionary> properties = object->get_property_list();
	for (int64_t index = 0; index < properties.size(); ++index) {
		const Dictionary property = properties[index];
		if ((static_cast<int64_t>(property["usage"]) & godot::PROPERTY_USAGE_SCRIPT_VARIABLE) != 0) {
			view.fields.push_back(state.intern(utf8_of(String(property["name"]))));
		}
	}
	views_.push_back(std::move(view));
	fill_view(views_.back());
	return Value::of_ref(Kind::Dict, views_.back().node);
}

void PortBridge::object_set(state::State &state, uint32_t slot, uint32_t property, const Value &value) {
	const Value view = object_view(state, slot);
	const std::vector<uint32_t> &fields = view_of(slot)->fields;
	if (std::find(fields.begin(), fields.end(), property) == fields.end()) {
		throw state::ScriptError("Invalid assignment of property '" + state.text(property) + "': not a script variable of the object");
	}
	state.set(view.ref, Value::str(property), value);
}

Value PortBridge::view_object(state::State &, uint32_t node) {
	for (const ObjectView &view : views_) {
		if (view.node == node) {
			return Value::of_ref(Kind::Opaque, view.slot);
		}
	}
	return adopt_view(node);
}

Value PortBridge::adopt_view(uint32_t node) {
	if (!host_calls_ || node >= dict_sources_.size() || !dict_sources_[node]) {
		return Value();
	}
	Value id;
	Value meta;
	if (!state_.lookup(node, state_.string("instance_id"), id) || id.kind != Kind::Int
			|| !state_.lookup(node, state_.string("meta"), meta) || meta.kind != Kind::Dict) {
		return Value();
	}
	Object *object = godot::ObjectDB::get_instance(static_cast<uint64_t>(id.i));
	if (object == nullptr) {
		return Value();
	}
	opaque_.push_back(Variant(object));
	ObjectView view;
	view.slot = static_cast<uint32_t>(opaque_.size() - 1);
	view.node = node;
	view.meta = meta.ref;
	view.adopted = true;
	const godot::TypedArray<Dictionary> properties = object->get_property_list();
	for (int64_t index = 0; index < properties.size(); ++index) {
		const Dictionary property = properties[index];
		if ((static_cast<int64_t>(property["usage"]) & godot::PROPERTY_USAGE_SCRIPT_VARIABLE) != 0) {
			view.fields.push_back(state_.intern(utf8_of(String(property["name"]))));
		}
	}
	views_.push_back(std::move(view));
	// The object takes what the native call changed in the view so far; each
	// write-back from here on writes the view's changes into it.
	write_view(views_.back());
	return Value::of_ref(Kind::Opaque, views_.back().slot);
}

// The nodes are built in place, so they start clean: write_back() writes a
// view that set() has changed since.
void PortBridge::fill_view(const ObjectView &view) {
	Object *object = object_at(view.slot);
	state::ValueList keys;
	state::ValueList values;
	for (const uint32_t field : view.fields) {
		keys.push_back(Value::str(field));
		values.push_back(load(object->get(static_name(field))));
	}
	state::ValueList meta_keys;
	state::ValueList meta_values;
	const godot::TypedArray<StringName> names = object->get_meta_list();
	for (int64_t index = 0; index < names.size(); ++index) {
		const StringName name = names[index];
		meta_keys.push_back(load(Variant(name)));
		meta_values.push_back(load(object->get_meta(name)));
	}
	keys.push_back(state_.string("meta"));
	values.push_back(Value::of_ref(Kind::Dict, view.meta));
	// As DayEngine's views: the read scopes key their caches by it.
	keys.push_back(state_.string("instance_id"));
	values.push_back(Value::of_int(static_cast<int64_t>(object->get_instance_id())));
	state::DictNode &meta = state_.dict_node(view.meta);
	meta.reset();
	meta.keys = std::move(meta_keys);
	meta.values = std::move(meta_values);
	state::DictNode &node = state_.dict_node(view.node);
	node.reset();
	node.keys = std::move(keys);
	node.values = std::move(values);
	if (view.adopted) {
		// The DayEngine view in GDScript still holds what it held before the
		// host call: the next write-back gives it the object's values, which
		// DayEngine._take_views then finds unchanged.
		node.dirty = true;
		meta.dirty = true;
	}
}

bool PortBridge::view_changed(const ObjectView &view) const {
	return state_.dict_node(view.node).dirty || state_.dict_node(view.meta).dirty;
}

// As DayEngine._take_views: each property the view holds another value for,
// then the metadata the view's "meta" drops, adds or changes.
void PortBridge::write_view(const ObjectView &view) {
	Object *object = object_at(view.slot);
	for (const uint32_t field : view.fields) {
		Value value;
		if (!state_.lookup(view.node, Value::str(field), value)) {
			continue;
		}
		const StringName name = static_name(field);
		const Variant exported = export_value(value);
		if (!same_variant(object->get(name), exported)) {
			object->set(name, exported);
		}
	}
	Value meta;
	if (!state_.lookup(view.node, state_.string("meta"), meta) || meta.kind != Kind::Dict) {
		throw state::ScriptError("an object's view lost its \"meta\" Dictionary");
	}
	// Copies: exporting may fill a backed node, which may move the node lists.
	const state::DictNode &entries = state_.dict(meta.ref);
	const state::ValueList keys = entries.keys.list();
	const state::ValueList values = entries.values;
	const godot::TypedArray<StringName> names = object->get_meta_list();
	for (int64_t index = 0; index < names.size(); ++index) {
		const StringName name = names[index];
		if (!state_.has(meta.ref, load(Variant(name)))) {
			object->remove_meta(name);
		}
	}
	for (size_t index = 0; index < keys.size(); ++index) {
		const StringName name = export_value(keys[index]);
		const Variant exported = export_value(values[index]);
		if (!object->has_meta(name) || !same_variant(object->get_meta(name), exported)) {
			object->set_meta(name, exported);
		}
	}
}

bool PortBridge::rng_get(uint32_t slot, uint64_t &seed, uint64_t &state) {
	RandomNumberGenerator *rng = Object::cast_to<RandomNumberGenerator>(object_at(slot));
	if (rng == nullptr) {
		return false;
	}
	seed = rng->get_seed();
	state = rng->get_state();
	if (uint64_t *kept = validating_state(rng)) {
		state = *kept;
	}
	return true;
}

void PortBridge::rng_set_state(uint32_t slot, uint64_t state) {
	RandomNumberGenerator *rng = Object::cast_to<RandomNumberGenerator>(object_at(slot));
	if (rng == nullptr) {
		throw state::ScriptError("Invalid call: set_state on a value that is not a RandomNumberGenerator");
	}
	if (uint64_t *kept = validating_state(rng)) {
		*kept = state;
		return;
	}
	rng->set_state(state);
}

uint64_t *PortBridge::validating_state(RandomNumberGenerator *rng) {
	if (!validating_) {
		return nullptr;
	}
	const uint64_t id = static_cast<uint64_t>(rng->get_instance_id());
	if (std::find(made_rngs_.begin(), made_rngs_.end(), id) != made_rngs_.end()) {
		return nullptr;
	}
	for (auto &kept : rng_states_) {
		if (kept.first == id) {
			return &kept.second;
		}
	}
	rng_states_.emplace_back(id, rng->get_state());
	return &rng_states_.back().second;
}

uint32_t PortBridge::rng_new(uint64_t seed, uint64_t state) {
	Ref<RandomNumberGenerator> rng;
	rng.instantiate();
	rng->set_seed(seed);
	rng->set_state(state);
	if (validating_) {
		made_rngs_.push_back(static_cast<uint64_t>(rng->get_instance_id()));
	}
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

godot::AurelionContent *PortBridge::content_host() {
	Object *known = godot::ObjectDB::get_instance(content_host_);
	if (known != nullptr) {
		return static_cast<godot::AurelionContent *>(known);
	}
	godot::AurelionContent *host = Object::cast_to<godot::AurelionContent>(static_cast<Object *>(content_service()->get(StringName("_native"))));
	if (host == nullptr) {
		throw state::ScriptError("ContentService holds no native content tables (its _native is no AurelionContent)");
	}
	content_host_ = host->get_instance_id();
	return host;
}

Value PortBridge::content_row(state::State &state, state::ContentTable table, uint32_t id) {
	namespace content = aurelion::rules::content;
	const uint64_t memo = (static_cast<uint64_t>(table) + 1) << 32 | id;
	const auto found = content_.find(memo);
	if (found != content_.end()) {
		return found->second;
	}
	const std::string &text = state.text(id);
	Variant row;
	if (table == state::ContentTable::Scenario || table == state::ContentTable::TerrainLayersForScenario) {
		const char *method = table == state::ContentTable::Scenario ? "get_scenario_readonly" : "get_terrain_layers_for_scenario";
		row = content_service()->call(StringName(method), String::utf8(text.data(), static_cast<int64_t>(text.size())));
	} else {
		godot::AurelionContent *host = content_host();
		content::Store &store = host->store();
		std::vector<content::Message> messages;
		Value native;
		const auto by_id = [&](const char *path) {
			return store.content_by_id(path, text, "items", messages);
		};
		switch (table) {
			case state::ContentTable::Unit:
				native = by_id(content::kUnitsPath);
				break;
			case state::ContentTable::Hero:
				native = by_id(content::kHeroesPath);
				break;
			case state::ContentTable::Faction:
				native = by_id(content::kFactionsPath);
				break;
			case state::ContentTable::Spell:
				native = by_id(content::kSpellsPath);
				break;
			case state::ContentTable::Artifact:
				native = by_id(content::kArtifactsPath);
				break;
			case state::ContentTable::ResourceSite:
				native = by_id(content::kResourceSitesPath);
				break;
			case state::ContentTable::Building:
				native = by_id(content::kBuildingsPath);
				break;
			case state::ContentTable::Town:
				native = by_id(content::kTownsPath);
				break;
			case state::ContentTable::MapObject:
				native = by_id(content::kMapObjectsPath);
				break;
			case state::ContentTable::Encounter:
				native = store.encounter(text, messages);
				break;
			case state::ContentTable::ArmyGroup:
				native = by_id(content::kArmyGroupsPath);
				break;
			case state::ContentTable::Resource:
				native = by_id(content::kResourcesPath);
				break;
			case state::ContentTable::MapObjectForResourceSite:
				native = store.map_object_for_resource_site(text, messages);
				break;
			case state::ContentTable::BiomeForTerrain:
				native = store.biome_for_terrain(text, messages);
				break;
			case state::ContentTable::Scenario:
			case state::ContentTable::TerrainLayersForScenario:
				break;
		}
		godot::AurelionContent::report(messages);
		row = native.kind == Kind::Nil ? Variant(Dictionary()) : host->content_variant(native);
	}
	const Value loaded = load(row);
	// Terrain layers are a new copy on every call, so they are asked for again,
	// and the port gets a new Dictionary of its own, as GDScript does: a
	// shadow check then compares it by its entries.
	if (table == state::ContentTable::TerrainLayersForScenario) {
		return loaded.kind == Kind::Dict ? Value::of_ref(Kind::Dict, gd::deep_duplicate_dict(state, loaded.ref)) : loaded;
	}
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
	godot::AurelionContent *host = content_host();
	std::vector<aurelion::rules::content::Message> messages;
	const Value native = host->store().load_json(state.text(path), messages);
	godot::AurelionContent::report(messages);
	const Value loaded = load(native.kind == Kind::Nil ? Variant(Dictionary()) : host->content_variant(native));
	if (loaded.kind == Kind::Dict && state.dict_size(loaded.ref) != 0) {
		content_.emplace(memo, loaded);
	}
	return loaded;
}

Object *PortBridge::script_object(uint32_t script) {
	const std::string &path = state_.text(script);
	auto found = scripts_.find(path);
	if (found == scripts_.end()) {
		const Ref<godot::Resource> loaded = godot::ResourceLoader::get_singleton()->load(String::utf8(path.data(), static_cast<int64_t>(path.size())));
		if (loaded.is_null()) {
			throw state::ScriptError("cannot load " + path + " for its static vars");
		}
		found = scripts_.emplace(path, Variant(loaded)).first;
	}
	return static_cast<Object *>(found->second);
}

StringName PortBridge::static_name(uint32_t name) const {
	const std::string &text = state_.text(name);
	return StringName(String::utf8(text.data(), static_cast<int64_t>(text.size())));
}

Value PortBridge::static_get(state::State &, uint32_t script, uint32_t name) {
	const uint64_t slot = static_cast<uint64_t>(script) << 32 | name;
	const auto found = static_slots_.find(slot);
	if (found != static_slots_.end()) {
		return statics_[found->second].value;
	}
	const Variant value = script_object(script)->get(static_name(name));
	const Value loaded = load(value);
	statics_.push_back(StaticVar{ script, name, loaded, false });
	static_slots_.emplace(slot, statics_.size() - 1);
	return loaded;
}

void PortBridge::static_set(state::State &, uint32_t script, uint32_t name, const Value &value) {
	const uint64_t slot = static_cast<uint64_t>(script) << 32 | name;
	const auto found = static_slots_.find(slot);
	if (found != static_slots_.end()) {
		statics_[found->second].value = value;
		statics_[found->second].assigned = true;
		return;
	}
	script_object(script);
	statics_.push_back(StaticVar{ script, name, value, true });
	static_slots_.emplace(slot, statics_.size() - 1);
}

Value PortBridge::call_static(state::State &, uint32_t script, uint32_t function, const Value *args, size_t count) {
	if (!host_calls_) {
		state::Suspend suspend;
		suspend.script = script;
		suspend.function = function;
		suspend.args.assign(args, args + count);
		throw suspend;
	}
	// GDScript finds every container and static var as the native code left
	// them, and the containers export made stay those nodes' objects: a second
	// write-back writes into them, not into stale copies. GDScript may change
	// them in place, so nothing written back before can be undone.
	host_calls_made_.emplace_back(script, function);
	++full_host_calls_;
	undo_arrays_.clear();
	undo_dicts_.clear();
	undo_packed_.clear();
	undo_statics_.clear();
	write_back();
	Array call_args;
	for (size_t index = 0; index < count; ++index) {
		call_args.push_back(export_value(args[index]));
	}
	adopt_exported();
	for (StaticVar &var : statics_) {
		var.assigned = false;
	}
	// GDScript::callp runs a static func of the script with no instance. It
	// may call switched functions, which run on another bridge.
	const Variant result = script_object(script)->callv(static_name(function), call_args);
	reback();
	return load(result);
}

Value PortBridge::call_pure(state::State &state, uint32_t script, uint32_t function, const Value *args, size_t count) {
	if (!host_calls_) {
		return call_static(state, script, function, args, count);
	}
	host_calls_made_.emplace_back(script, function);
	const Array call_args = begin_pure_call(args, count);
	const Variant result = script_object(script)->callv(static_name(function), call_args);
	return load(result);
}

Array PortBridge::begin_pure_call(const Value *args, size_t count) {
	write_back(full_host_calls_ == 0);
	Array call_args;
	for (size_t index = 0; index < count; ++index) {
		call_args.push_back(export_value(args[index]));
	}
	adopt_exported();
	// Godot holds what each node holds now: the next write-back writes only
	// what changes from here on.
	for (uint32_t node = 0; node < array_sources_.size(); ++node) {
		if (array_sources_[node]) {
			state_.array_node(node).dirty = false;
		}
	}
	for (uint32_t node = 0; node < dict_sources_.size(); ++node) {
		if (dict_sources_[node]) {
			state_.dict_node(node).dirty = false;
		}
	}
	for (uint32_t node = 0; node < packed_sources_.size(); ++node) {
		if (packed_sources_[node]) {
			state_.packed_node(node).dirty = false;
		}
	}
	for (StaticVar &var : statics_) {
		var.assigned = false;
	}
	return call_args;
}

void PortBridge::adopt_exported() {
	for (const auto &made : exported_arrays_) {
		const Array array = made.second;
		if (array_sources_.size() <= made.first) {
			array_sources_.resize(made.first + 1);
		}
		array_sources_[made.first] = array;
		array_nodes_.emplace(identity_of(array), made.first);
	}
	for (const auto &made : exported_dicts_) {
		const Dictionary dict = made.second;
		if (dict_sources_.size() <= made.first) {
			dict_sources_.resize(made.first + 1);
		}
		dict_sources_[made.first] = dict;
		dict_nodes_.emplace(identity_of(dict), made.first);
	}
	for (const auto &made : exported_packed_) {
		if (packed_sources_.size() <= made.first) {
			packed_sources_.resize(made.first + 1);
		}
		packed_sources_[made.first] = made.second;
		packed_nodes_.emplace(identity_of_packed(made.second), made.first);
	}
	exported_arrays_.clear();
	exported_dicts_.clear();
	exported_packed_.clear();
}

// GDScript may have changed any container: each loaded node reads its
// container again, from scratch. The sources keep every container alive, so
// no identity in the maps goes to another container meanwhile.
void PortBridge::reback() {
	for (uint32_t node = 0; node < array_sources_.size(); ++node) {
		if (array_sources_[node]) {
			state_.array_node(node).reset();
			back_array(node, *array_sources_[node]);
		}
	}
	for (uint32_t node = 0; node < dict_sources_.size(); ++node) {
		if (dict_sources_[node]) {
			state_.dict_node(node).reset();
			back_dict(node, *dict_sources_[node]);
		}
	}
	for (uint32_t node = 0; node < packed_sources_.size(); ++node) {
		if (packed_sources_[node]) {
			state_.packed_node(node).reset();
			back_packed(node, *packed_sources_[node]);
		}
	}
	state_.drop_memo();
	statics_.clear();
	static_slots_.clear();
	content_.clear();
	content_revision_ = -1;
	// The views' nodes stay the same nodes, so the DictRefs held across the
	// call see GDScript's changes.
	for (const ObjectView &view : views_) {
		fill_view(view);
	}
}

state::TypeRef PortBridge::builtin_type(uint8_t builtin) {
	// A builtin type has no class name and no script: a null Object, as
	// Array.get_typed_script() gives it (a Nil script would be another type).
	return register_type(builtin, StringName(), Variant(static_cast<Object *>(nullptr)));
}

int64_t PortBridge::content_revision(state::State &) {
	if (content_revision_ < 0) {
		content_revision_ = content_host()->revision();
	}
	return content_revision_;
}

void PortBridge::print_error(const std::string &text) {
	godot::UtilityFunctions::push_error(String::utf8(text.data(), static_cast<int64_t>(text.size())));
}

void PortBridge::print_warning(const std::string &text) {
	godot::UtilityFunctions::push_warning(String::utf8(text.data(), static_cast<int64_t>(text.size())));
}

String PortBridge::path_text(uint32_t path) const {
	const std::string &text = state_.text(path);
	return String::utf8(text.data(), static_cast<int64_t>(text.size()));
}

Value PortBridge::object_call(state::State &state, uint32_t slot, uint32_t method, const Value *args, size_t count) {
	return load_answer(call_opaque(state, slot, method, args, count));
}

Value PortBridge::object_call_engine(state::State &state, uint32_t slot, uint32_t method, const Value *args, size_t count) {
	return keep_opaque(call_opaque(state, slot, method, args, count));
}

Variant PortBridge::call_opaque(state::State &state, uint32_t slot, uint32_t method, const Value *args, size_t count) {
	if (slot >= opaque_.size() || opaque_[slot].get_type() == Variant::NIL) {
		throw state::ScriptError("Cannot call method '" + state.text(method) + "' on a value that is not an object.");
	}
	if (!host_calls_) {
		throw state::ScriptError("Calling the method " + state.text(method) + " of an object runs the engine, which this call may not do (a shadow check or a call that writes nothing back)");
	}
	const Array call_args = begin_pure_call(args, count);
	if (Object *object = object_at(slot)) {
		return object->callv(static_name(method), call_args);
	}
	// A kept engine value (a String): its builtin method, on a copy.
	Variant receiver = opaque_[slot];
	std::vector<const Variant *> pointers;
	for (int64_t index = 0; index < call_args.size(); ++index) {
		pointers.push_back(&call_args[index]);
	}
	Variant result;
	GDExtensionCallError error;
	receiver.callp(static_name(method), pointers.data(), static_cast<int>(pointers.size()), result, error);
	if (error.error != GDEXTENSION_CALL_OK) {
		throw state::ScriptError("Invalid call. Nonexistent function '" + state.text(method) + "' in base '" + utf8_of(Variant::get_type_name(receiver.get_type())) + "'.");
	}
	return result;
}

Value PortBridge::keep_opaque(const Variant &value) {
	if (value.get_type() == Variant::NIL || (value.get_type() == Variant::OBJECT && static_cast<Object *>(value) == nullptr)) {
		return Value();
	}
	opaque_.push_back(value);
	return Value::of_ref(Kind::Opaque, static_cast<uint32_t>(opaque_.size() - 1));
}

Value PortBridge::load_answer(const Variant &value) {
	if (value.get_type() == Variant::OBJECT && static_cast<Object *>(value) == nullptr) {
		return Value();
	}
	return load(value);
}

bool PortBridge::object_has_method(state::State &, uint32_t slot, uint32_t method) {
	Object *object = object_at(slot);
	if (object == nullptr) {
		throw state::ScriptError("Cannot call method 'has_method' on a value that is not an object.");
	}
	return object->has_method(static_name(method));
}

Value PortBridge::class_instantiate(state::State &, uint32_t name) {
	godot::ClassDBSingleton *classes = godot::ClassDBSingleton::get_singleton();
	const StringName class_name = static_name(name);
	if (!classes->class_exists(class_name)) {
		return Value();
	}
	return load(classes->instantiate(class_name));
}

Value PortBridge::autoload(state::State &, uint32_t name) {
	godot::SceneTree *tree = Object::cast_to<godot::SceneTree>(godot::Engine::get_singleton()->get_main_loop());
	godot::Node *node = tree != nullptr && tree->get_root() != nullptr ? tree->get_root()->get_node_or_null(godot::NodePath(path_text(name))) : nullptr;
	return node == nullptr ? Value() : load(Variant(node));
}

bool PortBridge::file_exists(state::State &, uint32_t path) {
	return godot::FileAccess::file_exists(path_text(path));
}

int64_t PortBridge::file_length(state::State &, uint32_t path) {
	const Ref<godot::FileAccess> file = godot::FileAccess::open(path_text(path), godot::FileAccess::READ);
	if (file.is_null()) {
		return -1;
	}
	const int64_t length = static_cast<int64_t>(file->get_length());
	file->close();
	return length;
}

int64_t PortBridge::file_modified_time(state::State &, uint32_t path) {
	return static_cast<int64_t>(godot::FileAccess::get_modified_time(path_text(path)));
}

bool PortBridge::dir_entries(state::State &state, uint32_t path, std::vector<std::pair<uint32_t, bool>> &out) {
	const Ref<godot::DirAccess> dir = godot::DirAccess::open(path_text(path));
	if (dir.is_null()) {
		return false;
	}
	dir->list_dir_begin();
	for (String name = dir->get_next(); !name.is_empty(); name = dir->get_next()) {
		out.emplace_back(state.intern(utf8_of(name)), dir->current_is_dir());
	}
	dir->list_dir_end();
	return true;
}

bool PortBridge::resource_exists(state::State &, uint32_t path) {
	return godot::ResourceLoader::get_singleton()->exists(path_text(path));
}

uint32_t PortBridge::os_environment(state::State &state, uint32_t name) {
	return state.intern(utf8_of(godot::OS::get_singleton()->get_environment(path_text(name))));
}

bool PortBridge::os_has_feature(state::State &, uint32_t name) {
	return godot::OS::get_singleton()->has_feature(path_text(name));
}

int64_t PortBridge::ticks_msec() {
	return static_cast<int64_t>(godot::Time::get_singleton()->get_ticks_msec());
}

int64_t PortBridge::ticks_usec() {
	return static_cast<int64_t>(godot::Time::get_singleton()->get_ticks_usec());
}

double PortBridge::unix_time() {
	return godot::Time::get_singleton()->get_unix_time_from_system();
}

Array PortBridge::engine_args(const Value *args, size_t count, const char *what) {
	for (size_t index = 0; index < count; ++index) {
		const Kind kind = args[index].kind;
		if (kind == Kind::Array || kind == Kind::Dict || kind == Kind::Opaque || args[index].is_packed()) {
			if (!host_calls_) {
				throw state::ScriptError(std::string(what) + " runs the engine, which this call may not do (a shadow check or a call that writes nothing back)");
			}
			return begin_pure_call(args, count);
		}
	}
	Array exported;
	for (size_t index = 0; index < count; ++index) {
		exported.push_back(export_value(args[index]));
	}
	return exported;
}

Value PortBridge::class_call_static(state::State &state, uint32_t class_name, uint32_t method, const Value *args, size_t count) {
	if (!host_calls_) {
		throw state::ScriptError("ClassDB.class_call_static(" + state.text(class_name) + ", " + state.text(method) + ") runs the engine, which this call may not do (a shadow check or a call that writes nothing back)");
	}
	Array call_args;
	call_args.push_back(static_name(class_name));
	call_args.push_back(static_name(method));
	call_args.append_array(engine_args(args, count, "ClassDB.class_call_static"));
	return load_answer(godot::ClassDBSingleton::get_singleton()->callv(StringName("class_call_static"), call_args));
}

Value PortBridge::class_call_static_engine(state::State &state, uint32_t class_name, uint32_t method, const Value *args, size_t count) {
	if (!host_calls_) {
		throw state::ScriptError("ClassDB.class_call_static(" + state.text(class_name) + ", " + state.text(method) + ") runs the engine, which this call may not do (a shadow check or a call that writes nothing back)");
	}
	Array call_args;
	call_args.push_back(static_name(class_name));
	call_args.push_back(static_name(method));
	call_args.append_array(engine_args(args, count, "ClassDB.class_call_static"));
	return keep_opaque(godot::ClassDBSingleton::get_singleton()->callv(StringName("class_call_static"), call_args));
}

bool PortBridge::engine_equal(state::State &, const Value &a, const Value &b) {
	const Value pair[] = { a, b };
	const Array exported = engine_args(pair, 2, "==");
	return exported[0] == exported[1];
}

Value PortBridge::engine_equal_loaded(state::State &state, const Value &a, const Value &b) {
	// Loaded containers export as themselves, so the engine compares them
	// without the native walk that would load every value first.
	const auto loaded = [this](const Value &value) {
		return value.kind == Kind::Array ? value.ref < array_sources_.size() && array_sources_[value.ref]
										 : value.kind == Kind::Dict && value.ref < dict_sources_.size() && dict_sources_[value.ref];
	};
	if (!host_calls_ || !loaded(a) || !loaded(b)) {
		return Value();
	}
	return Value::of_bool(engine_equal(state, a, b));
}

Value PortBridge::engine_singleton(state::State &, uint32_t name) {
	// Each singleton through its own get_singleton(): godot-cpp frees those
	// instance bindings when the library goes. Engine::get_singleton(name)
	// makes one it never frees, and the engine frees the singleton after the
	// library is gone, through the binding's callback (a crash at exit).
	const StringName singleton = static_name(name);
	Object *object = nullptr;
	if (singleton == StringName("Time")) {
		object = godot::Time::get_singleton();
	} else if (singleton == StringName("ProjectSettings")) {
		object = godot::ProjectSettings::get_singleton();
	} else {
		throw state::ScriptError("PortBridge::engine_singleton does not reach the singleton " + utf8_of(String(singleton)) + ".");
	}
	return load(Variant(object));
}

uint32_t PortBridge::engine_format(state::State &state, uint32_t pattern, const Value *args, size_t count, bool &ok) {
	const Array values = engine_args(args, count, "String formatting");
	Variant result;
	bool valid = false;
	Variant::evaluate(Variant::OP_MODULE, Variant(path_text(pattern)), Variant(values), result, valid);
	ok = valid;
	return state.intern(utf8_of(String(result)));
}

uint32_t PortBridge::engine_str(state::State &state, const Value &value) {
	const Array exported = engine_args(&value, 1, "str()");
	return state.intern(utf8_of(exported[0].stringify()));
}

bool PortBridge::holds_loaded(const Value &root) const {
	std::vector<Value> pending{ root };
	std::vector<bool> seen_arrays(state_.array_count());
	std::vector<bool> seen_dicts(state_.dict_count());
	while (!pending.empty()) {
		const Value value = pending.back();
		pending.pop_back();
		if (value.kind == Kind::Array) {
			if (value.ref < array_sources_.size() && array_sources_[value.ref]) {
				return true;
			}
			if (seen_arrays[value.ref]) {
				continue;
			}
			seen_arrays[value.ref] = true;
			const state::ArrayNode &node = state_.array_node(value.ref);
			pending.insert(pending.end(), node.items.begin(), node.items.end());
		} else if (value.kind == Kind::Dict) {
			if (value.ref < dict_sources_.size() && dict_sources_[value.ref]) {
				return true;
			}
			if (seen_dicts[value.ref]) {
				continue;
			}
			seen_dicts[value.ref] = true;
			const state::DictNode &node = state_.dict_node(value.ref);
			pending.insert(pending.end(), node.values.begin(), node.values.end());
		}
	}
	return false;
}

Value PortBridge::engine_duplicate(state::State &, const Value &value, bool deep) {
	// A container loaded from GDScript, or a native-built one holding one: the
	// copy is then GDScript's too, so no later host call exports it, and a
	// loaded part is not filled to be copied. A wholly native-built one copies
	// as fast natively, without being exported first.
	if (!host_calls_ || (value.kind != Kind::Array && value.kind != Kind::Dict)
			|| !(deep ? holds_loaded(value)
						: value.kind == Kind::Array ? value.ref < array_sources_.size() && array_sources_[value.ref]
													: value.ref < dict_sources_.size() && dict_sources_[value.ref])) {
		return Value();
	}
	const Array exported = begin_pure_call(&value, 1);
	if (value.kind == Kind::Array) {
		return load(Array(exported[0]).duplicate(deep));
	}
	return load(Dictionary(exported[0]).duplicate(deep));
}

uint32_t PortBridge::json_stringify(state::State &state, const Value &value) {
	if (!host_calls_) {
		throw state::ScriptError("JSON.stringify runs the engine, which this call may not do (a shadow check or a call that writes nothing back)");
	}
	// Written back first: a loaded container exports as itself.
	const Array exported = begin_pure_call(&value, 1);
	return state.intern(utf8_of(godot::JSON::stringify(exported[0])));
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

void PortBridge::back_array(uint32_t node, const Array &array) {
	state::ArrayNode &target = state_.array_node(node);
	target.backed = true;
	if (array.is_typed()) {
		target.element_type = register_type(array.get_typed_builtin(), array.get_typed_class_name(), array.get_typed_script());
	}
	target.read_only = array.is_read_only();
	// What GDScript holds: the native memo's answers read from it stay only
	// while the port writes nothing into it (State::memo_find).
	state_.watch_loaded(Value::of_ref(Kind::Array, node));
}

void PortBridge::back_dict(uint32_t node, const Dictionary &dict) {
	state::DictNode &target = state_.dict_node(node);
	target.backed = true;
	if (dict.is_typed_key()) {
		target.key_type = register_type(dict.get_typed_key_builtin(), dict.get_typed_key_class_name(), dict.get_typed_key_script());
	}
	if (dict.is_typed_value()) {
		target.value_type = register_type(dict.get_typed_value_builtin(), dict.get_typed_value_class_name(), dict.get_typed_value_script());
	}
	target.read_only = dict.is_read_only();
	state_.watch_loaded(Value::of_ref(Kind::Dict, node));
}

void PortBridge::back_packed(uint32_t node, const Variant &packed) {
	state::PackedNode &target = state_.packed_node(node);
	target.kind = packed_kind(packed.get_type());
	target.backed = true;
	state_.watch_loaded(Value::of_ref(target.kind, node));
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
		case Variant::VECTOR3I: {
			const Vector3i vector = value;
			return Value::of_vector3i(vector.x, vector.y, vector.z);
		}
		case Variant::PACKED_BYTE_ARRAY:
		case Variant::PACKED_INT32_ARRAY:
		case Variant::PACKED_STRING_ARRAY: {
			const Kind kind = packed_kind(value.get_type());
			const uint64_t id = identity_of_packed(value);
			const auto found = packed_nodes_.find(id);
			if (found != packed_nodes_.end()) {
				return Value::of_ref(kind, found->second);
			}
			const uint32_t node = state_.new_packed(kind);
			packed_nodes_.emplace(id, node);
			if (packed_sources_.size() <= node) {
				packed_sources_.resize(node + 1);
			}
			packed_sources_[node] = value;
			back_packed(node, value);
			if (validating_) {
				if (packed_snapshots_.size() <= node) {
					packed_snapshots_.resize(node + 1);
				}
				packed_snapshots_[node] = value.duplicate();
			}
			return Value::of_ref(kind, node);
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
			back_array(node, array);
			if (validating_) {
				if (array_snapshots_.size() <= node) {
					array_snapshots_.resize(node + 1);
				}
				array_snapshots_[node] = array.duplicate(false);
			}
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
			back_dict(node, dict);
			if (validating_) {
				if (dict_snapshots_.size() <= node) {
					dict_snapshots_.resize(node + 1);
				}
				dict_snapshots_[node] = dict.duplicate(false);
			}
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

void PortBridge::fill_packed(state::State &state, uint32_t node) {
	fill_packed_node(state, state.packed_node(node), *packed_sources_[node]);
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
		case Kind::Vector3i:
			return Variant(Vector3i(value.vx(), value.vy(), value.vz()));
		case Kind::PackedByte:
		case Kind::PackedInt32:
		case Kind::PackedString: {
			const uint32_t node = value.ref;
			if (node < packed_sources_.size() && packed_sources_[node]) {
				return *packed_sources_[node];
			}
			const auto done = exported_packed_.find(node);
			if (done != exported_packed_.end()) {
				return done->second;
			}
			const Variant made = packed_variant(state_, state_.packed(node));
			exported_packed_.emplace(node, made);
			return made;
		}
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

namespace {

// Whether an undoable write-back meets this node first: its flag, set now.
bool first_undo(std::vector<uint8_t> &kept, uint32_t node) {
	if (kept.size() <= node) {
		kept.resize(node + 1, 0);
	}
	if (kept[node] != 0) {
		return false;
	}
	kept[node] = 1;
	return true;
}

} // namespace

void PortBridge::write_back(bool undoable) {
	for (uint32_t node = 0; node < array_sources_.size(); ++node) {
		if (!array_sources_[node] || !state_.array_node(node).dirty) {
			continue;
		}
		Array target = *array_sources_[node];
		if (target.is_read_only()) {
			// set() and append() refuse a read-only node, so nothing should get here.
			throw state::ScriptError("native wrote into a read-only Array");
		}
		if (undoable && first_undo(undo_array_kept_, node)) {
			undo_arrays_.emplace_back(target, target.duplicate(false));
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
		if (undoable && first_undo(undo_dict_kept_, node)) {
			undo_dicts_.emplace_back(target, target.duplicate(false));
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
	for (uint32_t node = 0; node < packed_sources_.size(); ++node) {
		if (!packed_sources_[node] || !state_.packed_node(node).dirty) {
			continue;
		}
		// Through the Variant, so the change reaches every holder of the array.
		Variant target = *packed_sources_[node];
		if (undoable && first_undo(undo_packed_kept_, node)) {
			undo_packed_.emplace_back(target, target.duplicate());
		}
		const Variant elements = packed_variant(state_, state_.packed_node(node));
		target.call(StringName("clear"));
		target.call(StringName("append_array"), elements);
	}
	for (StaticVar &var : statics_) {
		if (var.assigned) {
			Object *holder = script_object(var.script);
			if (undoable && !var.undo_kept) {
				var.undo_kept = true;
				undo_statics_.push_back(UndoStatic{ var.script, var.name, holder->get(static_name(var.name)) });
			}
			holder->set(static_name(var.name), export_value(var.value));
		}
	}
	for (const ObjectView &view : views_) {
		if (view_changed(view)) {
			undo_lost_ = undo_lost_ || undoable;
			write_view(view);
		}
	}
}

void PortBridge::undo_write_backs() {
	for (const auto &undo : undo_arrays_) {
		Array target = undo.first;
		const Array &before = undo.second;
		target.resize(before.size());
		for (int64_t index = 0; index < before.size(); ++index) {
			target.set(index, before[index]);
		}
	}
	for (const auto &undo : undo_dicts_) {
		Dictionary target = undo.first;
		const Array keys = undo.second.keys();
		const Array values = undo.second.values();
		target.clear();
		for (int64_t index = 0; index < keys.size(); ++index) {
			target[keys[index]] = values[index];
		}
	}
	for (const auto &undo : undo_packed_) {
		Variant target = undo.first;
		target.call(StringName("clear"));
		target.call(StringName("append_array"), undo.second);
	}
	for (const UndoStatic &undo : undo_statics_) {
		script_object(undo.script)->set(static_name(undo.name), undo.value);
	}
	undo_arrays_.clear();
	undo_dicts_.clear();
	undo_packed_.clear();
	undo_statics_.clear();
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
	for (uint32_t node = 0; node < packed_sources_.size(); ++node) {
		if (packed_sources_[node] && state_.packed_node(node).dirty) {
			return true;
		}
	}
	for (const StaticVar &var : statics_) {
		if (var.assigned) {
			return true;
		}
	}
	for (const ObjectView &view : views_) {
		if (view_changed(view)) {
			return true;
		}
	}
	return false;
}

std::string PortBridge::diff(const Value &native, const Variant &gdscript) {
	matched_arrays_.clear();
	matched_dicts_.clear();
	matched_packed_.clear();
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
		case Kind::Vector3i: {
			if (type != Variant::VECTOR3I) {
				mismatch("Vector3i");
				return;
			}
			const Vector3i vector = gdscript;
			if (vector.x != native.vx() || vector.y != native.vy() || vector.z != native.vz()) {
				mismatch("Vector3i (" + compat::itos(native.vx()) + ", " + compat::itos(native.vy()) + ", " + compat::itos(native.vz()) + ")");
			}
			return;
		}
		case Kind::PackedByte:
		case Kind::PackedInt32:
		case Kind::PackedString: {
			const Variant::Type want = packed_type(native.kind);
			if (type != want) {
				mismatch(utf8_of(Variant::get_type_name(want)));
				return;
			}
			const uint64_t id = identity_of_packed(gdscript);
			const uint32_t node = native.ref;
			if (node < packed_sources_.size() && packed_sources_[node]) {
				if (identity_of_packed(*packed_sources_[node]) != id) {
					mismatch("a " + utf8_of(Variant::get_type_name(want)) + " it was given");
				}
				return;
			}
			const auto seen = matched_packed_.find(node);
			if (seen != matched_packed_.end()) {
				if (seen->second != id) {
					mismatch("the packed array it returned before here");
				}
				return;
			}
			for (const auto &pair : matched_packed_) {
				if (pair.second == id) {
					mismatch("another new packed array where GDScript repeats one");
					return;
				}
			}
			matched_packed_.emplace(node, id);
			if (packed_nodes_.count(id) != 0) {
				mismatch("a new packed array where GDScript returns one it was given");
				return;
			}
			const state::PackedNode &elements = state_.packed(node);
			if (!same_elements(state_, elements, gdscript)) {
				mismatch("a " + utf8_of(Variant::get_type_name(want)) + " of " + compat::itos(static_cast<int64_t>(elements.size())) + " other elements");
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
			diff_array_items(source, array, path, out);
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
			diff_dict_items(source, dict, path, out);
			return;
		}
		case Kind::Opaque:
			if (opaque_[native.ref] != gdscript && !same_made_rng(opaque_[native.ref], gdscript)) {
				mismatch(describe(opaque_[native.ref]));
			}
			return;
	}
}

bool PortBridge::same_made_rng(const Variant &made, const Variant &gdscript) const {
	// A validating call's RandomNumberGenerator.new(): GDScript's call made its
	// own, a new one too, with the same seed and state.
	if (!validating_) {
		return false;
	}
	RandomNumberGenerator *native = Object::cast_to<RandomNumberGenerator>(static_cast<Object *>(made));
	RandomNumberGenerator *other = Object::cast_to<RandomNumberGenerator>(static_cast<Object *>(gdscript));
	if (native == nullptr || other == nullptr) {
		return false;
	}
	if (std::find(made_rngs_.begin(), made_rngs_.end(), static_cast<uint64_t>(native->get_instance_id())) == made_rngs_.end()) {
		return false;
	}
	for (const Variant &loaded : opaque_) {
		if (loaded == gdscript) {
			return false;
		}
	}
	return native->get_seed() == other->get_seed() && native->get_state() == other->get_state();
}


namespace {

// A timing: a Dictionary key ending in "_ms" ("surface_ms").
bool is_timing(const state::State &state, const Value &key) {
	if (!key.is_string_like()) {
		return false;
	}
	const std::string &text = state.text(key.ref);
	return text.size() > 3 && text.compare(text.size() - 3, 3, "_ms") == 0;
}

} // namespace

void PortBridge::diff_array_items(const state::ArrayNode &node, const Array &array, std::string &path, std::string &out) {
	if (static_cast<int64_t>(node.items.size()) != array.size()) {
		out = path + ": native an Array of " + compat::itos(static_cast<int64_t>(node.items.size())) + ", GDScript " + describe(array);
		return;
	}
	const size_t length = path.size();
	for (size_t index = 0; index < node.items.size() && out.empty(); ++index) {
		path += "[" + compat::itos(static_cast<int64_t>(index)) + "]";
		const Variant item = array[static_cast<int64_t>(index)];
		diff_value(node.items[index], item, path, out);
		path.resize(length);
	}
}

void PortBridge::diff_dict_items(const state::DictNode &node, const Dictionary &dict, std::string &path, std::string &out) {
	if (static_cast<int64_t>(node.keys.size()) != dict.size()) {
		out = path + ": native a Dictionary of " + compat::itos(static_cast<int64_t>(node.keys.size())) + " keys, GDScript " + describe(dict);
		return;
	}
	const Array keys = dict.keys();
	const Array values = dict.values();
	const size_t length = path.size();
	for (size_t index = 0; index < node.keys.size() && out.empty(); ++index) {
		const Variant key = keys[static_cast<int64_t>(index)];
		path += ".keys()[" + compat::itos(static_cast<int64_t>(index)) + "]";
		diff_value(node.keys[index], key, path, out);
		path.resize(length);
		if (!out.empty()) {
			break;
		}
		path += node.keys[index].is_string_like() ? "." + state_.text(node.keys[index].ref) : "[" + compat::itos(static_cast<int64_t>(index)) + "]";
		const Variant value = values[static_cast<int64_t>(index)];
		if (!(is_timing(state_, node.keys[index]) && ((node.values[index].kind == Kind::Float && value.get_type() == Variant::FLOAT) || (node.values[index].kind == Kind::Int && value.get_type() == Variant::INT)))) {
			diff_value(node.values[index], value, path, out);
		}
		path.resize(length);
	}
}

namespace {

constexpr const char *kViewMeta = "meta";

uint64_t container_identity(const Variant &value) {
	switch (value.get_type()) {
		case Variant::ARRAY:
			return identity_of(Array(value));
		case Variant::DICTIONARY:
			return identity_of(Dictionary(value));
		case Variant::PACKED_BYTE_ARRAY:
		case Variant::PACKED_INT32_ARRAY:
		case Variant::PACKED_STRING_ARRAY:
			return identity_of_packed(value);
		default:
			return 0;
	}
}

// A memo's shape: each value's type, and for a container its identity and
// size, `depth` levels further down; a value of another type by its hash. It
// shows that a call replaced or filled the memo without comparing what it holds.
void memo_shape(const Variant &value, int depth, std::vector<uint64_t> &out) {
	out.push_back(static_cast<uint64_t>(value.get_type()));
	const uint64_t id = container_identity(value);
	if (id == 0) {
		out.push_back(static_cast<uint64_t>(value.hash()));
		return;
	}
	out.push_back(id);
	if (value.get_type() == Variant::ARRAY) {
		const Array array = value;
		out.push_back(static_cast<uint64_t>(array.size()));
		for (int64_t index = 0; depth > 0 && index < array.size(); ++index) {
			memo_shape(array[index], depth - 1, out);
		}
	} else if (value.get_type() == Variant::DICTIONARY) {
		const Dictionary dict = value;
		out.push_back(static_cast<uint64_t>(dict.size()));
		if (depth > 0) {
			const Array values = dict.values();
			for (int64_t index = 0; index < values.size(); ++index) {
				memo_shape(values[index], depth - 1, out);
			}
		}
	} else {
		Variant packed = value;
		out.push_back(static_cast<uint64_t>(static_cast<int64_t>(packed.call(StringName("size")))));
	}
}

constexpr int kMemoShapeDepth = 2;

bool is_meta_key(const Variant &key) {
	const Variant::Type type = key.get_type();
	return (type == Variant::STRING || type == Variant::STRING_NAME) && static_cast<String>(key) == String(kViewMeta);
}

} // namespace

void PortBridge::keep_memo_shapes() {
	memo_shapes_.clear();
	size_t count = 0;
	const port::Table *tables = port::tables(count);
	for (size_t table = 0; table < count; ++table) {
		for (size_t index = 0; index < tables[table].shared_memo_count; ++index) {
			const port::ScriptStatic &var = tables[table].shared_memos[index];
			if (static_slots_.count(static_cast<uint64_t>(var.script) << 32 | var.name) != 0) {
				continue;
			}
			MemoShape &kept = memo_shapes_.emplace_back();
			kept.script = var.script;
			kept.name = var.name;
			memo_shape(script_object(var.script)->get(static_name(var.name)), kMemoShapeDepth, kept.shape);
		}
	}
}

std::string PortBridge::verify(const Value &result, const Variant &gdscript_result, const Value *args, size_t count, const Array &after) {
	matched_arrays_.clear();
	matched_dicts_.clear();
	matched_packed_.clear();
	std::string out;
	std::string path = "result";
	diff_value(result, gdscript_result, path, out);
	if (!out.empty()) {
		return out;
	}
	return verify_after(args, count, after);
}

std::string PortBridge::verify_state(const Value *args, size_t count, const Array &after) {
	matched_arrays_.clear();
	matched_dicts_.clear();
	matched_packed_.clear();
	return verify_after(args, count, after);
}

std::string PortBridge::verify_host_call(const std::vector<Value> &host_args, const Array &gdscript_host_args, const Value *args, size_t count, const Array &after) {
	matched_arrays_.clear();
	matched_dicts_.clear();
	matched_packed_.clear();
	if (static_cast<int64_t>(host_args.size()) != gdscript_host_args.size()) {
		return "native passes " + std::to_string(host_args.size()) + " arguments, GDScript " + std::to_string(gdscript_host_args.size());
	}
	std::string out;
	std::string path;
	for (size_t index = 0; index < host_args.size(); ++index) {
		path = "args[" + compat::itos(static_cast<int64_t>(index)) + "]";
		const Variant gdscript = gdscript_host_args[static_cast<int64_t>(index)];
		diff_value(host_args[index], gdscript, path, out);
		if (!out.empty()) {
			return "its " + out;
		}
	}
	return verify_after(args, count, after);
}

// verify's state half: the result, if any, was matched first.
std::string PortBridge::verify_after(const Value *args, size_t count, const Array &after) {
	std::string out;
	std::string path;
	// The arguments the engine script made again: a session's view, and in it
	// the session's metadata.
	std::vector<bool> views(dict_sources_.size(), false);
	for (size_t index = 0; index < count && static_cast<int64_t>(index) < after.size(); ++index) {
		const Value &arg = args[index];
		const Variant now = after[static_cast<int64_t>(index)];
		if (arg.kind != Kind::Dict || arg.ref >= dict_sources_.size() || !dict_sources_[arg.ref] || now.get_type() != Variant::DICTIONARY) {
			continue;
		}
		const Dictionary now_dict = now;
		if (identity_of(*dict_sources_[arg.ref]) == identity_of(now_dict)) {
			continue;
		}
		path = "args[" + compat::itos(static_cast<int64_t>(index)) + "]";
		verify_view(arg.ref, now_dict, path, views, 1, out);
		if (!out.empty()) {
			return "arguments afterwards: " + out;
		}
	}
	verify_loaded(after, views, out);
	if (!out.empty()) {
		return "arguments afterwards: " + out;
	}
	for (const ObjectView &view : views_) {
		verify_object_view(view, out);
		if (!out.empty()) {
			return "an object afterwards: " + out;
		}
	}
	// The static vars the native call read or set. It cannot reach GDScript's
	// own memos (port::Table::gdscript_only), which GDScript fills for its
	// GDScript callers: they are never compared.
	for (const StaticVar &var : statics_) {
		path = state_.text(var.script) + "." + state_.text(var.name);
		const Variant now = script_object(var.script)->get(static_name(var.name));
		diff_value(var.value, now, path, out);
		if (!out.empty()) {
			return "static vars afterwards: " + out;
		}
	}
	// The shared memos it left alone, as GDScript's call left them.
	for (const MemoShape &kept : memo_shapes_) {
		std::vector<uint64_t> now;
		memo_shape(script_object(kept.script)->get(static_name(kept.name)), kMemoShapeDepth, now);
		if (now != kept.shape) {
			return "static vars afterwards: GDScript's call changed " + state_.text(kept.script) + "." + state_.text(kept.name) + ", which the native port left alone";
		}
	}
	for (const auto &kept : rng_states_) {
		const RandomNumberGenerator *rng = Object::cast_to<RandomNumberGenerator>(godot::ObjectDB::get_instance(godot::ObjectID(kept.first)));
		if (rng != nullptr && rng->get_state() != kept.second) {
			return "a RandomNumberGenerator afterwards: native state " + std::to_string(kept.second) + ", GDScript " + std::to_string(rng->get_state());
		}
	}
	return out;
}

void PortBridge::verify_view(uint32_t node, const Dictionary &now, std::string &path, std::vector<bool> &views, int depth, std::string &out) {
	views[node] = true;
	const state::DictNode &view = state_.dict_node(node);
	const size_t length = path.size();
	if (!view.backed) {
		if (static_cast<int64_t>(view.keys.size()) != now.size()) {
			out = path + ": native a Dictionary of " + compat::itos(static_cast<int64_t>(view.keys.size())) + " keys, GDScript " + describe(now);
			return;
		}
		const Array keys = now.keys();
		const Array values = now.values();
		for (size_t index = 0; index < view.keys.size() && out.empty(); ++index) {
			const Variant key = keys[static_cast<int64_t>(index)];
			path += ".keys()[" + compat::itos(static_cast<int64_t>(index)) + "]";
			diff_value(view.keys[index], key, path, out);
			path.resize(length);
			if (!out.empty()) {
				return;
			}
			path += view.keys[index].is_string_like() ? "." + state_.text(view.keys[index].ref) : "[" + compat::itos(static_cast<int64_t>(index)) + "]";
			const Value &value = view.values[index];
			const Variant now_value = values[static_cast<int64_t>(index)];
			if (depth > 0 && is_meta_key(key) && value.kind == Kind::Dict && value.ref < dict_sources_.size() && dict_sources_[value.ref] && now_value.get_type() == Variant::DICTIONARY && identity_of(*dict_sources_[value.ref]) != identity_of(Dictionary(now_value))) {
				verify_view(value.ref, now_value, path, views, depth - 1, out);
			} else {
				diff_value(value, now_value, path, out);
			}
			path.resize(length);
		}
		return;
	}
	// Read in part: the native code changed nothing in it.
	const Dictionary before = dict_snapshots_[node];
	if (before.size() != now.size() || !same_items(before.keys(), now.keys())) {
		out = path + ": native kept the keys " + describe(before.keys()) + ", GDScript " + describe(now.keys());
		return;
	}
	const Array keys = before.keys();
	for (int64_t index = 0; index < keys.size() && out.empty(); ++index) {
		const Variant key = keys[index];
		const Variant was = before[key];
		const Variant is = now[key];
		path += "." + utf8_of(key.stringify());
		if (depth > 0 && is_meta_key(key) && was.get_type() == Variant::DICTIONARY && is.get_type() == Variant::DICTIONARY && identity_of(Dictionary(was)) != identity_of(Dictionary(is))) {
			const auto loaded = dict_nodes_.find(identity_of(Dictionary(was)));
			if (loaded != dict_nodes_.end()) {
				verify_view(loaded->second, is, path, views, depth - 1, out);
			} else if (!same_entries(was, is)) {
				out = path + ": native kept " + describe(was) + ", GDScript " + describe(is);
			}
		} else if (!same_variant(was, is)) {
			out = path + ": native kept " + describe(was) + ", GDScript " + describe(is);
		}
		path.resize(length);
	}
}

// A validating call writes no view back: each property as GDScript's call left
// it, and the metadata as a Dictionary in get_meta_list()'s order.
void PortBridge::verify_object_view(const ObjectView &view, std::string &out) {
	Object *object = object_at(view.slot);
	std::string path;
	for (const uint32_t field : view.fields) {
		Value value;
		path = "." + state_.text(field);
		if (!state_.lookup(view.node, Value::str(field), value)) {
			out = path + ": the native view dropped it";
			return;
		}
		diff_value(value, object->get(static_name(field)), path, out);
		if (!out.empty()) {
			return;
		}
	}
	Value meta;
	if (!state_.lookup(view.node, state_.string("meta"), meta)) {
		out = ".meta: the native view dropped it";
		return;
	}
	Dictionary now;
	const godot::TypedArray<StringName> names = object->get_meta_list();
	for (int64_t index = 0; index < names.size(); ++index) {
		const StringName name = names[index];
		now[name] = object->get_meta(name);
	}
	path = ".meta";
	diff_value(meta, now, path, out);
}

void PortBridge::verify_loaded(const Array &after, const std::vector<bool> &views, std::string &out) {
	std::string path;
	for (uint32_t node = 0; node < array_sources_.size() && out.empty(); ++node) {
		if (!array_sources_[node]) {
			continue;
		}
		const Array now = *array_sources_[node];
		const state::ArrayNode &array = state_.array_node(node);
		if (array.backed) {
			if (!same_items(array_snapshots_[node], now)) {
				out = where(now, after) + ": GDScript changed an Array the native code only read, now " + describe(now);
			}
			continue;
		}
		path.clear();
		diff_array_items(array, now, path, out);
		if (!out.empty()) {
			out = where(now, after) + out;
		}
	}
	for (uint32_t node = 0; node < dict_sources_.size() && out.empty(); ++node) {
		if (!dict_sources_[node] || (node < views.size() && views[node])) {
			continue;
		}
		const Dictionary now = *dict_sources_[node];
		const state::DictNode &dict = state_.dict_node(node);
		if (dict.backed) {
			if (!same_entries(dict_snapshots_[node], now)) {
				out = where(now, after) + ": GDScript changed a Dictionary the native code only read, now " + describe(now);
			}
			continue;
		}
		path.clear();
		diff_dict_items(dict, now, path, out);
		if (!out.empty()) {
			out = where(now, after) + out;
		}
	}
	for (uint32_t node = 0; node < packed_sources_.size() && out.empty(); ++node) {
		if (!packed_sources_[node]) {
			continue;
		}
		const Variant now = *packed_sources_[node];
		const state::PackedNode &packed = state_.packed_node(node);
		const bool same = packed.backed ? packed_snapshots_[node] == now : same_elements(state_, packed, now);
		if (!same) {
			out = where(now, after) + ": native " + (packed.dirty ? "wrote" : "kept") + " a " + utf8_of(Variant::get_type_name(now.get_type())) + " of " + compat::itos(static_cast<int64_t>(packed.backed ? 0 : packed.size())) + " elements, GDScript " + describe(now);
		}
	}
}

std::string PortBridge::where(const Variant &container, const Array &after) {
	const Variant::Type type = container.get_type();
	const uint64_t target = container_identity(container);
	std::deque<std::pair<Variant, std::string>> queue;
	for (int64_t index = 0; index < after.size(); ++index) {
		queue.emplace_back(after[index], "args[" + compat::itos(index) + "]");
	}
	for (const StaticVar &var : statics_) {
		queue.emplace_back(script_object(var.script)->get(static_name(var.name)), state_.text(var.script) + "." + state_.text(var.name));
	}
	std::unordered_map<uint64_t, bool> seen;
	size_t pushed = queue.size();
	while (!queue.empty()) {
		const Variant value = queue.front().first;
		const std::string path = std::move(queue.front().second);
		queue.pop_front();
		const uint64_t id = container_identity(value);
		if (id == 0) {
			continue;
		}
		if (id == target && value.get_type() == type) {
			return path;
		}
		if (!seen.emplace(id, true).second || pushed > 4000000) {
			continue;
		}
		if (value.get_type() == Variant::ARRAY) {
			const Array array = value;
			for (int64_t index = 0; index < array.size(); ++index) {
				const Variant item = array[index];
				if (container_identity(item) != 0) {
					queue.emplace_back(item, path + "[" + compat::itos(index) + "]");
					++pushed;
				}
			}
		} else if (value.get_type() == Variant::DICTIONARY) {
			const Dictionary dict = value;
			const Array keys = dict.keys();
			const Array values = dict.values();
			for (int64_t index = 0; index < keys.size(); ++index) {
				const Variant item = values[index];
				if (container_identity(item) == 0) {
					continue;
				}
				const Variant key = keys[index];
				const bool text = key.get_type() == Variant::STRING || key.get_type() == Variant::STRING_NAME;
				queue.emplace_back(item, path + (text ? "." + utf8_of(key) : "[" + utf8_of(key.stringify()) + "]"));
				++pushed;
			}
		}
	}
	return "a loaded " + utf8_of(Variant::get_type_name(type)) + " the arguments no longer reach";
}

} // namespace aurelion::rules::bridge
