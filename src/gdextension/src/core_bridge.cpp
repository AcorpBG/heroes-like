#include "core_bridge.hpp"

#include "battle_state_bridge.hpp"

#include "aurelion_rules/port/registry.hpp"

#include <godot_cpp/classes/dir_access.hpp>
#include <godot_cpp/classes/file_access.hpp>
#include <godot_cpp/classes/os.hpp>
#include <godot_cpp/classes/resource_loader.hpp>
#include <godot_cpp/variant/packed_byte_array.hpp>
#include <godot_cpp/variant/string_name.hpp>
#include <godot_cpp/variant/utility_functions.hpp>
#include <godot_cpp/variant/vector2i.hpp>
#include <godot_cpp/variant/vector3i.hpp>

#include <cstring>
#include <string_view>

namespace aurelion::map_bridge {

using godot::Array;
using godot::Dictionary;
using godot::Ref;
using godot::String;
using godot::Variant;
using st::Kind;
using st::Value;

namespace bridge = aurelion::rules::bridge;

namespace {

String godot_text(const std::string &text) {
	return String::utf8(text.data(), static_cast<int64_t>(text.size()));
}

[[noreturn]] void no_backed_nodes() {
	throw st::ScriptError("the map package core holds no backed nodes");
}

} // namespace

std::string utf8(const String &text) {
	const godot::CharString bytes = text.utf8();
	return std::string(bytes.get_data(), static_cast<size_t>(bytes.length()));
}

bool ensure_parent_dir(const String &path) {
	const String base_dir = path.get_base_dir();
	if (base_dir.is_empty()) {
		return true;
	}
	return godot::DirAccess::make_dir_recursive_absolute(base_dir) == godot::OK;
}

const char *replace_file(const String &path, const godot::PackedByteArray &bytes) {
	const String temporary_path = path + String(".tmp");
	Ref<godot::FileAccess> file = godot::FileAccess::open(temporary_path, godot::FileAccess::WRITE);
	if (file.is_null() || !file->is_open()) {
		return "open_failed";
	}
	const bool stored = file->store_buffer(bytes);
	file->flush();
	const godot::Error write_error = file->get_error();
	file->close();
	if (!stored || write_error != godot::OK) {
		godot::DirAccess::remove_absolute(temporary_path);
		return "write_failed";
	}
	if (godot::DirAccess::rename_absolute(temporary_path, path) != godot::OK) {
		godot::DirAccess::remove_absolute(temporary_path);
		return "replace_failed";
	}
	return nullptr;
}

bool GodotFiles::exists(const std::string &path) {
	return godot::FileAccess::file_exists(godot_text(path));
}

bool GodotFiles::read(const std::string &path, std::string &bytes) {
	Ref<godot::FileAccess> file = godot::FileAccess::open(godot_text(path), godot::FileAccess::READ);
	if (file.is_null() || !file->is_open()) {
		return false;
	}
	const godot::PackedByteArray buffer = file->get_buffer(static_cast<int64_t>(file->get_length()));
	bytes.assign(reinterpret_cast<const char *>(buffer.ptr()), static_cast<size_t>(buffer.size()));
	return true;
}

bool GodotFiles::resource_exists(const std::string &path) {
	return godot::ResourceLoader::get_singleton()->exists(godot_text(path));
}

bool GodotFiles::editor() {
	return godot::OS::get_singleton()->has_feature("editor");
}

CoreCall::CoreCall() {
	state_.set_backing(this);
}

Value CoreCall::text(const String &value) {
	return state_.string(utf8(value));
}

// ---------------------------------------------------------------- into the State

Value CoreCall::in(const Variant &value) {
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
			return text(static_cast<String>(value));
		case Variant::STRING_NAME:
			return Value::of_ref(Kind::StringName, state_.intern(utf8(static_cast<String>(value))));
		case Variant::VECTOR2I: {
			const godot::Vector2i vector = value;
			return Value::of_vector2i(vector.x, vector.y);
		}
		case Variant::VECTOR3I: {
			const godot::Vector3i vector = value;
			return Value::of_vector3i(vector.x, vector.y, vector.z);
		}
		case Variant::ARRAY:
			return in_array(static_cast<Array>(value));
		case Variant::DICTIONARY:
			return in_dict(static_cast<Dictionary>(value));
		case Variant::PACKED_BYTE_ARRAY:
			return in_packed(value, Kind::PackedByte);
		case Variant::PACKED_INT32_ARRAY:
			return in_packed(value, Kind::PackedInt32);
		case Variant::PACKED_STRING_ARRAY:
			return in_packed(value, Kind::PackedString);
		default:
			return in_object(value);
	}
}

Value CoreCall::in_object(const Variant &value) {
	uint64_t id = 0;
	if (value.get_type() == Variant::OBJECT) {
		const godot::Object *object = value;
		if (object == nullptr) {
			return Value();
		}
		id = object->get_instance_id();
		const auto found = in_objects_.find(id);
		if (found != in_objects_.end()) {
			return Value::of_ref(Kind::Opaque, found->second);
		}
	}
	const uint32_t slot = static_cast<uint32_t>(opaques_.size());
	opaques_.push_back(Opaque{ value, nullptr, nullptr });
	if (id != 0) {
		in_objects_.emplace(id, slot);
	}
	return Value::of_ref(Kind::Opaque, slot);
}

Value CoreCall::in_array(const Array &array) {
	const uint64_t id = bridge::identity_of(array);
	const auto found = in_arrays_.find(id);
	if (found != in_arrays_.end()) {
		return Value::of_ref(Kind::Array, found->second);
	}
	const uint32_t node = state_.new_array();
	in_arrays_.emplace(id, node);
	out_arrays_.emplace(node, array);
	const int64_t size = array.size();
	state_.array_node(node).items.reserve(static_cast<size_t>(size));
	for (int64_t index = 0; index < size; ++index) {
		const Value item = in(array[index]);
		state_.array_node(node).items.push_back(item);
	}
	state_.array_node(node).read_only = array.is_read_only();
	return Value::of_ref(Kind::Array, node);
}

Value CoreCall::in_dict(const Dictionary &dict) {
	const uint64_t id = bridge::identity_of(dict);
	const auto found = in_dicts_.find(id);
	if (found != in_dicts_.end()) {
		return Value::of_ref(Kind::Dict, found->second);
	}
	const uint32_t node = state_.new_dict();
	in_dicts_.emplace(id, node);
	out_dicts_.emplace(node, dict);
	const Array keys = dict.keys();
	const Array values = dict.values();
	const int64_t size = keys.size();
	state_.dict_node(node).keys.reserve(static_cast<size_t>(size));
	state_.dict_node(node).values.reserve(static_cast<size_t>(size));
	for (int64_t index = 0; index < size; ++index) {
		const Value key = in(keys[index]);
		const Value item = in(values[index]);
		state_.dict_node(node).keys.push_back(key);
		state_.dict_node(node).values.push_back(item);
	}
	state_.dict_node(node).read_only = dict.is_read_only();
	return Value::of_ref(Kind::Dict, node);
}

Value CoreCall::in_packed(const Variant &packed, Kind kind) {
	const uint64_t id = bridge::identity_of_packed(packed);
	const auto found = in_packeds_.find(id);
	if (found != in_packeds_.end()) {
		return Value::of_ref(kind, found->second);
	}
	const uint32_t node = state_.new_packed(kind);
	in_packeds_.emplace(id, node);
	out_packeds_.emplace(node, packed);
	bridge::fill_packed_node(state_, state_.packed_node(node), packed);
	return Value::of_ref(kind, node);
}

// ---------------------------------------------------------------- out of the State

Variant CoreCall::out(const Value &value) {
	switch (value.kind) {
		case Kind::Nil:
			return Variant();
		case Kind::Bool:
			return value.b;
		case Kind::Int:
			return value.i;
		case Kind::Float:
			return value.f;
		case Kind::String:
			return out_string(value.ref);
		case Kind::StringName:
			return godot::StringName(static_cast<String>(out_string(value.ref)));
		case Kind::Vector2i:
			return godot::Vector2i(value.vx(), value.vy());
		case Kind::Vector3i:
			return godot::Vector3i(value.vx(), value.vy(), value.vz());
		case Kind::Array:
			return out_array(value.ref);
		case Kind::Dict:
			return out_dict_node(value.ref);
		case Kind::Opaque:
			return out_opaque(value.ref);
		case Kind::PackedByte:
		case Kind::PackedInt32:
		case Kind::PackedString:
			return out_packed(value);
	}
	return Variant();
}

Variant CoreCall::out_string(uint32_t atom) {
	if (atom >= strings_.size()) {
		strings_.resize(static_cast<size_t>(atom) + 1);
	}
	if (strings_[atom].get_type() == Variant::NIL) {
		strings_[atom] = godot_text(state_.text(atom));
	}
	return strings_[atom];
}

Variant CoreCall::out_array(uint32_t node) {
	Array array;
	const auto found = out_arrays_.find(node);
	if (found != out_arrays_.end()) {
		if (!state_.array_node(node).dirty) {
			return found->second;
		}
		// Written by the core: the same Array, refilled.
		array = found->second;
	} else {
		out_arrays_.emplace(node, array);
	}
	state_.array_node(node).dirty = false;
	const size_t size = state_.array_node(node).items.size();
	array.resize(static_cast<int64_t>(size));
	for (size_t index = 0; index < size; ++index) {
		array.set(static_cast<int64_t>(index), out(state_.array_node(node).items[index]));
	}
	if (state_.array_node(node).read_only) {
		array.make_read_only();
	}
	return array;
}

Variant CoreCall::out_dict_node(uint32_t node) {
	Dictionary dict;
	const auto found = out_dicts_.find(node);
	if (found != out_dicts_.end()) {
		if (!state_.dict_node(node).dirty) {
			return found->second;
		}
		dict = found->second;
		dict.clear();
	} else {
		out_dicts_.emplace(node, dict);
	}
	state_.dict_node(node).dirty = false;
	const size_t size = state_.dict_node(node).keys.size();
	for (size_t index = 0; index < size; ++index) {
		const Variant key = out(state_.dict_node(node).keys[index]);
		dict[key] = out(state_.dict_node(node).values[index]);
	}
	if (state_.dict_node(node).read_only) {
		dict.make_read_only();
	}
	return dict;
}

Variant CoreCall::out_packed(const Value &value) {
	const auto found = out_packeds_.find(value.ref);
	if (found != out_packeds_.end() && !state_.packed_node(value.ref).dirty) {
		return found->second;
	}
	state_.packed_node(value.ref).dirty = false;
	const Variant packed = bridge::packed_variant(state_, state_.packed_node(value.ref));
	out_packeds_[value.ref] = packed;
	return packed;
}

Variant CoreCall::out_opaque(uint32_t slot) {
	if (opaques_.at(slot).object.get_type() != Variant::NIL) {
		return opaques_[slot].object;
	}
	if (const mp::MapDocument *map = opaques_[slot].map) {
		Dictionary initial;
		initial["map_id"] = out(map->map_id);
		initial["map_hash"] = out(map->map_hash);
		initial["source_kind"] = out(map->source_kind);
		initial["width"] = map->width;
		initial["height"] = map->height;
		initial["level_count"] = map->level_count;
		initial["metadata"] = out(map->metadata);
		initial["terrain_layers"] = out(map->terrain_layers);
		initial["route_graph"] = out(map->route_graph);
		initial["objects"] = out(map->objects);
		Ref<godot::MapDocument> document;
		document.instantiate();
		document->configure_owned(initial);
		opaques_[slot].object = document;
	} else if (const mp::ScenarioDocument *scenario = opaques_[slot].scenario) {
		Dictionary initial;
		initial["scenario_id"] = out(scenario->scenario_id);
		initial["scenario_hash"] = out(scenario->scenario_hash);
		initial["map_ref"] = out(scenario->map_ref);
		initial["selection"] = out(scenario->selection);
		initial["player_slots"] = out(scenario->player_slots);
		initial["objectives"] = out(scenario->objectives);
		initial["script_hooks"] = out(scenario->script_hooks);
		initial["enemy_factions"] = out(scenario->enemy_factions);
		initial["start_contract"] = out(scenario->start_contract);
		Ref<godot::ScenarioDocument> document;
		document.instantiate();
		document->configure(initial);
		opaques_[slot].object = document;
	}
	return opaques_[slot].object;
}

// ---------------------------------------------------------------- documents

Value CoreCall::new_map_document(mp::MapDocument *&document) {
	document = &maps_.emplace_back();
	opaques_.push_back(Opaque{ Variant(), document, nullptr });
	return Value::of_ref(Kind::Opaque, static_cast<uint32_t>(opaques_.size() - 1));
}

Value CoreCall::new_scenario_document(mp::ScenarioDocument *&document) {
	document = &scenarios_.emplace_back();
	opaques_.push_back(Opaque{ Variant(), nullptr, document });
	return Value::of_ref(Kind::Opaque, static_cast<uint32_t>(opaques_.size() - 1));
}

mp::MapDocument *CoreCall::map_document(const Value &value) {
	if (value.kind != Kind::Opaque || value.ref >= opaques_.size()) {
		return nullptr;
	}
	if (opaques_[value.ref].map != nullptr) {
		return opaques_[value.ref].map;
	}
	const Ref<godot::MapDocument> object = opaques_[value.ref].object;
	if (object.is_null()) {
		return nullptr;
	}
	// The stored containers, uncopied, as the map library's package writers
	// and checks read them.
	mp::MapDocument document;
	document.map_id = text(object->get_map_id());
	document.map_hash = text(object->get_map_hash());
	document.source_kind = text(object->get_source_kind());
	document.width = object->get_width();
	document.height = object->get_height();
	document.level_count = object->get_level_count();
	document.metadata = in(object->metadata_view());
	document.terrain_layers = in(object->terrain_layers_view());
	document.route_graph = in(object->route_graph_view());
	document.objects = in(object->objects_view());
	maps_.push_back(document);
	opaques_[value.ref].map = &maps_.back();
	return &maps_.back();
}

mp::ScenarioDocument *CoreCall::scenario_document(const Value &value) {
	if (value.kind != Kind::Opaque || value.ref >= opaques_.size()) {
		return nullptr;
	}
	if (opaques_[value.ref].scenario != nullptr) {
		return opaques_[value.ref].scenario;
	}
	const Ref<godot::ScenarioDocument> object = opaques_[value.ref].object;
	if (object.is_null()) {
		return nullptr;
	}
	// The getters' copies, as scenario_document_payload read them.
	mp::ScenarioDocument document;
	document.scenario_id = text(object->get_scenario_id());
	document.scenario_hash = text(object->get_scenario_hash());
	document.map_ref = in(object->get_map_ref());
	document.selection = in(object->get_selection());
	document.player_slots = in(object->get_player_slots());
	document.objectives = in(object->get_objectives());
	document.script_hooks = in(object->get_script_hooks());
	document.enemy_factions = in(object->get_enemy_factions());
	document.start_contract = in(object->get_start_contract());
	scenarios_.push_back(document);
	opaques_[value.ref].scenario = &scenarios_.back();
	return &scenarios_.back();
}

const char *CoreCall::write_package(rules::content::Files &, const std::string &path, const std::string &json) {
	const String target = godot_text(path);
	if (!ensure_parent_dir(target)) {
		return "create_directory_failed";
	}
	// The manifest cache is filled only once the package file is closed and in
	// place (package_written).
	godot::PackedByteArray bytes;
	bytes.resize(static_cast<int64_t>(json.size()));
	if (!json.empty()) {
		std::memcpy(bytes.ptrw(), json.data(), json.size());
	}
	return replace_file(target, bytes);
}

Value CoreCall::package_written(st::State &, const std::string &path, const Value &package, bool cache_profile) {
	const Dictionary profile = write_package_browser_manifest_cache(godot_text(path), out(package));
	return cache_profile ? in(profile) : Value();
}

// ---------------------------------------------------------------- Backing

void CoreCall::fill_array(st::State &, uint32_t) {
	no_backed_nodes();
}

void CoreCall::fill_dict(st::State &, uint32_t) {
	no_backed_nodes();
}

int64_t CoreCall::array_size(uint32_t) {
	no_backed_nodes();
}

Value CoreCall::array_at(st::State &, uint32_t, int64_t) {
	no_backed_nodes();
}

int64_t CoreCall::dict_size(uint32_t) {
	no_backed_nodes();
}

bool CoreCall::dict_lookup(st::State &, uint32_t, const Value &, Value &) {
	no_backed_nodes();
}

void CoreCall::print_error(const std::string &text) {
	godot::UtilityFunctions::push_error(godot_text(text));
}

void CoreCall::print_warning(const std::string &text) {
	godot::UtilityFunctions::push_warning(godot_text(text));
}

} // namespace aurelion::map_bridge

// The port's registry (core/port/registry_tables.cpp) is the rules library's:
// the map library carries no port table, so a host call reached from the
// package code fails as one no table lists.
namespace aurelion::rules::port {

const Table *tables(size_t &count) {
	count = 0;
	return nullptr;
}

} // namespace aurelion::rules::port
