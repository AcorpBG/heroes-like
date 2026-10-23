#include "content_host.hpp"

#include <godot_cpp/classes/file_access.hpp>
#include <godot_cpp/classes/os.hpp>
#include <godot_cpp/classes/resource_loader.hpp>
#include <godot_cpp/core/class_db.hpp>
#include <godot_cpp/core/gdextension_interface_loader.hpp>
#include <godot_cpp/variant/array.hpp>
#include <godot_cpp/variant/packed_byte_array.hpp>
#include <godot_cpp/variant/string_name.hpp>
#include <godot_cpp/variant/utility_functions.hpp>

#include <exception>
#include <string>

namespace godot {

namespace {

namespace content = aurelion::rules::content;
namespace state = aurelion::rules::state;
using state::Kind;
using state::Value;

std::string utf8(const String &text) {
	const CharString chars = text.utf8();
	return std::string(chars.get_data(), static_cast<size_t>(chars.length()));
}

String from_utf8(const std::string &text) {
	return String::utf8(text.data(), static_cast<int64_t>(text.size()));
}

// The game's files, through FileAccess.
class GodotFiles : public content::Files {
public:
	bool exists(const std::string &path) override {
		return FileAccess::file_exists(from_utf8(path));
	}
	bool read(const std::string &path, std::string &bytes) override {
		const Ref<FileAccess> file = FileAccess::open(from_utf8(path), FileAccess::READ);
		if (file.is_null()) {
			return false;
		}
		const PackedByteArray buffer = file->get_buffer(static_cast<int64_t>(file->get_length()));
		bytes.assign(reinterpret_cast<const char *>(buffer.ptr()), static_cast<size_t>(buffer.size()));
		return true;
	}
	bool resource_exists(const std::string &path) override {
		return ResourceLoader::get_singleton()->exists(from_utf8(path));
	}
	bool editor() override {
		return OS::get_singleton()->has_feature("editor");
	}
};

// A failure of the native code: a SCRIPT ERROR, as a failed port call is.
// Never throws.
void report_failure(const char *method, const char *what) noexcept {
	try {
		const std::string message = std::string("AurelionContent.") + method + ": " + what;
		::godot::gdextension_interface::print_script_error(message.c_str(), method, __FILE__, __LINE__, false);
	} catch (...) {
	}
}

// A Godot value of an override document copied into the tables' State.
Value copy_in(state::State &data, const Variant &value) {
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
			return data.string(utf8(value));
		case Variant::STRING_NAME:
			return Value::of_ref(Kind::StringName, data.intern(utf8(String(static_cast<StringName>(value)))));
		case Variant::ARRAY: {
			const Array array = value;
			const uint32_t made = data.new_array();
			for (int64_t index = 0; index < array.size(); ++index) {
				data.append(made, copy_in(data, array[index]));
			}
			data.array_node(made).read_only = true;
			return Value::of_ref(Kind::Array, made);
		}
		case Variant::DICTIONARY: {
			const Dictionary dict = value;
			const Array keys = dict.keys();
			const uint32_t made = data.new_dict();
			for (int64_t index = 0; index < keys.size(); ++index) {
				const Variant key = keys[index];
				data.set(made, copy_in(data, key), copy_in(data, dict[key]));
			}
			data.dict_node(made).read_only = true;
			return Value::of_ref(Kind::Dict, made);
		}
		default:
			throw state::NotPorted("left to GDScript: a content override holding a value JSON does not make");
	}
}

} // namespace

void AurelionContent::_bind_methods() {
	ClassDB::bind_method(D_METHOD("load_json", "path"), &AurelionContent::load_json);
	ClassDB::bind_method(D_METHOD("content_by_id", "path", "id", "list_key"), &AurelionContent::content_by_id);
	ClassDB::bind_method(D_METHOD("indexed_row", "path", "id", "list_key", "id_field"), &AurelionContent::indexed_row);
	ClassDB::bind_method(D_METHOD("encounter", "id"), &AurelionContent::encounter);
	ClassDB::bind_method(D_METHOD("content_ids", "path", "list_key"), &AurelionContent::content_ids);
	ClassDB::bind_method(D_METHOD("canonical_town_id", "id"), &AurelionContent::canonical_town_id);
	ClassDB::bind_method(D_METHOD("normalize_terrain_id", "terrain_id"), &AurelionContent::normalize_terrain_id);
	ClassDB::bind_method(D_METHOD("biome_for_terrain", "terrain_id"), &AurelionContent::biome_for_terrain);
	ClassDB::bind_method(D_METHOD("map_object_for_resource_site", "site_id"), &AurelionContent::map_object_for_resource_site);
	ClassDB::bind_method(D_METHOD("set_override", "path", "document"), &AurelionContent::set_override);
	ClassDB::bind_method(D_METHOD("clear_overrides"), &AurelionContent::clear_overrides);
	ClassDB::bind_method(D_METHOD("clear_cache"), &AurelionContent::clear_cache);
	ClassDB::bind_method(D_METHOD("revision"), &AurelionContent::revision);
	ClassDB::bind_method(D_METHOD("bump_revision"), &AurelionContent::bump_revision);
	ClassDB::bind_method(D_METHOD("validate"), &AurelionContent::validate);
}

AurelionContent::AurelionContent() :
		store_(std::make_unique<content::Store>(std::make_shared<GodotFiles>())) {}

AurelionContent::~AurelionContent() = default;

void AurelionContent::report(const std::vector<content::Message> &messages) {
	for (const content::Message &message : messages) {
		if (message.error) {
			UtilityFunctions::push_error(from_utf8(message.text));
		} else {
			UtilityFunctions::push_warning(from_utf8(message.text));
		}
	}
}

void AurelionContent::sync() {
	if (store_->generation() != generation_) {
		generation_ = store_->generation();
		arrays_.clear();
		dicts_.clear();
		strings_.clear();
	}
}

const Variant &AurelionContent::string_variant(uint32_t atom) {
	if (atom >= strings_.size()) {
		strings_.resize(atom + 1);
	}
	Variant &made = strings_[atom];
	if (made.get_type() == Variant::NIL) {
		made = from_utf8(store_->data().text(atom));
	}
	return made;
}

Variant AurelionContent::content_variant(const Value &value) {
	sync();
	const state::State &data = store_->data();
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
			return string_variant(value.ref);
		case Kind::StringName:
			return StringName(from_utf8(data.text(value.ref)));
		case Kind::Array: {
			if (value.ref < arrays_.size() && arrays_[value.ref].get_type() != Variant::NIL) {
				return arrays_[value.ref];
			}
			const state::ArrayNode &node = data.array(value.ref);
			Array made;
			made.resize(static_cast<int64_t>(node.items.size()));
			for (size_t index = 0; index < node.items.size(); ++index) {
				made[static_cast<int64_t>(index)] = content_variant(node.items[index]);
			}
			if (node.read_only) {
				made.make_read_only();
			}
			if (value.ref >= arrays_.size()) {
				arrays_.resize(value.ref + 1);
			}
			arrays_[value.ref] = made;
			return made;
		}
		case Kind::Dict: {
			if (value.ref < dicts_.size() && dicts_[value.ref].get_type() != Variant::NIL) {
				return dicts_[value.ref];
			}
			const state::DictNode &node = data.dict(value.ref);
			Dictionary made;
			for (size_t index = 0; index < node.keys.size(); ++index) {
				made[content_variant(node.keys[index])] = content_variant(node.values[index]);
			}
			if (node.read_only) {
				made.make_read_only();
			}
			if (value.ref >= dicts_.size()) {
				dicts_.resize(value.ref + 1);
			}
			dicts_[value.ref] = made;
			return made;
		}
		default:
			throw state::NotPorted("left to GDScript: a content value JSON does not make");
	}
}

// Each query: its messages printed; a native failure reported, and the
// fallback answered then.
template <typename Result, typename Body>
static Result query(const char *method, Result fallback, Body body) {
	try {
		std::vector<content::Message> messages;
		Result result = body(messages);
		AurelionContent::report(messages);
		return result;
	} catch (const std::exception &failure) {
		report_failure(method, failure.what());
	} catch (...) {
		report_failure(method, "native exception");
	}
	return fallback;
}

Variant AurelionContent::load_json(const String &path) {
	return query<Variant>("load_json", Variant(), [&](std::vector<content::Message> &messages) {
		return content_variant(store_->load_json(utf8(path), messages));
	});
}

Variant AurelionContent::content_by_id(const String &path, const String &id, const String &list_key) {
	return query<Variant>("content_by_id", Variant(), [&](std::vector<content::Message> &messages) {
		return content_variant(store_->content_by_id(utf8(path), utf8(id), utf8(list_key), messages));
	});
}

Variant AurelionContent::indexed_row(const String &path, const String &id, const String &list_key, const String &id_field) {
	return query<Variant>("indexed_row", Variant(), [&](std::vector<content::Message> &messages) {
		return content_variant(store_->indexed_row(utf8(path), utf8(id), utf8(list_key), utf8(id_field), messages));
	});
}

Variant AurelionContent::encounter(const String &id) {
	return query<Variant>("encounter", Variant(), [&](std::vector<content::Message> &messages) {
		return content_variant(store_->encounter(utf8(id), messages));
	});
}

PackedStringArray AurelionContent::content_ids(const String &path, const String &list_key) {
	return query<PackedStringArray>("content_ids", PackedStringArray(), [&](std::vector<content::Message> &messages) {
		PackedStringArray ids;
		for (const std::string &id : store_->content_ids(utf8(path), utf8(list_key), messages)) {
			ids.push_back(from_utf8(id));
		}
		return ids;
	});
}

String AurelionContent::canonical_town_id(const String &id) {
	// A typed GDScript function that stops on an error returns its type's default.
	return query<String>("canonical_town_id", String(), [&](std::vector<content::Message> &messages) {
		return from_utf8(store_->canonical_town_id(utf8(id), messages));
	});
}

String AurelionContent::normalize_terrain_id(const String &terrain_id) const {
	return from_utf8(content::Store::normalize_terrain_id(utf8(terrain_id)));
}

Variant AurelionContent::biome_for_terrain(const String &terrain_id) {
	return query<Variant>("biome_for_terrain", Variant(), [&](std::vector<content::Message> &messages) {
		return content_variant(store_->biome_for_terrain(utf8(terrain_id), messages));
	});
}

Variant AurelionContent::map_object_for_resource_site(const String &site_id) {
	return query<Variant>("map_object_for_resource_site", Variant(), [&](std::vector<content::Message> &messages) {
		return content_variant(store_->map_object_for_resource_site(utf8(site_id), messages));
	});
}

bool AurelionContent::set_override(const String &path, const Dictionary &document) {
	return query<bool>("set_override", false, [&](std::vector<content::Message> &messages) {
		return store_->set_override(utf8(path), copy_in(store_->scratch(), document), messages);
	});
}

void AurelionContent::clear_overrides() {
	query<bool>("clear_overrides", false, [&](std::vector<content::Message> &) {
		store_->clear_overrides();
		return true;
	});
}

void AurelionContent::clear_cache() {
	query<bool>("clear_cache", false, [&](std::vector<content::Message> &) {
		store_->clear_cache();
		return true;
	});
}

int64_t AurelionContent::revision() const {
	return store_->revision();
}

void AurelionContent::bump_revision() {
	store_->bump_revision();
}

// The checks' messages, then a failure that ended them.
void AurelionContent::validate() {
	std::vector<content::Message> messages;
	try {
		store_->validate(messages);
		report(messages);
	} catch (const std::exception &failure) {
		report(messages);
		report_failure("validate", failure.what());
	}
}

} // namespace godot
