#include "snapshot_encoder.hpp"

#include "battle_state_bridge.hpp"

#include "aurelion_rules/snapshot.hpp"

#include <godot_cpp/classes/script.hpp>
#include <godot_cpp/variant/array.hpp>
#include <godot_cpp/variant/dictionary.hpp>
#include <godot_cpp/variant/packed_int32_array.hpp>
#include <godot_cpp/variant/packed_string_array.hpp>
#include <godot_cpp/variant/string.hpp>
#include <godot_cpp/variant/string_name.hpp>
#include <godot_cpp/variant/vector2i.hpp>
#include <godot_cpp/variant/vector3i.hpp>

#include <cstring>
#include <stdexcept>
#include <string>
#include <unordered_map>
#include <vector>

namespace aurelion::rules::bridge {

using godot::Array;
using godot::Dictionary;
using godot::String;
using godot::StringName;
using godot::Variant;

namespace {

constexpr int kMaxDepth = 4096;

std::string utf8(const String &text) {
	const godot::CharString bytes = text.utf8();
	return std::string(bytes.get_data(), static_cast<size_t>(bytes.length()));
}

class Encoder {
public:
	godot::PackedByteArray encode(const Variant &value) {
		out_.insert(out_.end(), snapshot::kMagic, snapshot::kMagic + sizeof(snapshot::kMagic));
		write(value, 0);
		godot::PackedByteArray bytes;
		bytes.resize(static_cast<int64_t>(out_.size()));
		std::memcpy(bytes.ptrw(), out_.data(), out_.size());
		return bytes;
	}

private:
	void u8(uint8_t value) { out_.push_back(value); }
	void u32(uint32_t value) {
		for (int shift = 0; shift < 32; shift += 8) {
			out_.push_back(static_cast<uint8_t>(value >> shift));
		}
	}
	void u64(uint64_t value) {
		for (int shift = 0; shift < 64; shift += 8) {
			out_.push_back(static_cast<uint8_t>(value >> shift));
		}
	}

	void text(const std::string &value) {
		const auto found = texts_.find(value);
		if (found != texts_.end()) {
			u32(found->second);
			return;
		}
		texts_.emplace(value, static_cast<uint32_t>(texts_.size()));
		u32(snapshot::kNewText);
		u32(static_cast<uint32_t>(value.size()));
		out_.insert(out_.end(), value.begin(), value.end());
	}

	// The type's id, defined first (a kType) when it is new.
	uint32_t type_of(int64_t builtin, const StringName &class_name, const Variant &script) {
		snapshot::TypeInfo info;
		info.builtin = static_cast<uint8_t>(builtin);
		info.class_name = utf8(String(class_name));
		const godot::Object *object = script;
		const godot::Script *as_script = godot::Object::cast_to<godot::Script>(object);
		info.script = as_script != nullptr ? utf8(as_script->get_path()) : std::string();
		for (size_t index = 0; index < types_.size(); ++index) {
			if (types_[index] == info) {
				return static_cast<uint32_t>(index + 1);
			}
		}
		types_.push_back(info);
		const uint32_t id = static_cast<uint32_t>(types_.size());
		u8(snapshot::kType);
		u32(id);
		u8(info.builtin);
		text(info.class_name);
		text(info.script);
		return id;
	}

	void write(const Variant &value, int depth) {
		if (depth > kMaxDepth) {
			throw std::runtime_error("snapshot_encode: data nested deeper than " + std::to_string(kMaxDepth));
		}
		switch (value.get_type()) {
			case Variant::NIL:
				u8(snapshot::kNil);
				return;
			case Variant::BOOL:
				u8(static_cast<bool>(value) ? snapshot::kTrue : snapshot::kFalse);
				return;
			case Variant::INT:
				u8(snapshot::kInt);
				u64(static_cast<uint64_t>(static_cast<int64_t>(value)));
				return;
			case Variant::FLOAT: {
				const double number = value;
				uint64_t bits = 0;
				std::memcpy(&bits, &number, sizeof(bits));
				u8(snapshot::kFloat);
				u64(bits);
				return;
			}
			case Variant::STRING:
				u8(snapshot::kString);
				text(utf8(String(value)));
				return;
			case Variant::STRING_NAME:
				u8(snapshot::kStringName);
				text(utf8(String(StringName(value))));
				return;
			case Variant::VECTOR2I: {
				const godot::Vector2i vector = value;
				u8(snapshot::kVector2i);
				u32(static_cast<uint32_t>(vector.x));
				u32(static_cast<uint32_t>(vector.y));
				return;
			}
			case Variant::VECTOR3I: {
				const godot::Vector3i vector = value;
				u8(snapshot::kVector3i);
				u32(static_cast<uint32_t>(vector.x));
				u32(static_cast<uint32_t>(vector.y));
				u32(static_cast<uint32_t>(vector.z));
				return;
			}
			case Variant::ARRAY:
				array(value, depth);
				return;
			case Variant::DICTIONARY:
				dict(value, depth);
				return;
			case Variant::PACKED_BYTE_ARRAY:
			case Variant::PACKED_INT32_ARRAY:
			case Variant::PACKED_STRING_ARRAY:
				packed(value);
				return;
			default:
				u8(snapshot::kUnsupported);
				u8(static_cast<uint8_t>(value.get_type()));
				text(utf8(Variant::get_type_name(value.get_type())));
				return;
		}
	}

	void array(const Array &array, int depth) {
		const uint64_t identity = identity_of(array);
		const auto found = containers_.find(identity);
		if (found != containers_.end()) {
			u8(snapshot::kContainer);
			u32(found->second);
			return;
		}
		const uint32_t type = array.is_typed() ? type_of(array.get_typed_builtin(), array.get_typed_class_name(), array.get_typed_script()) : 0;
		containers_.emplace(identity, next_container_++);
		const int64_t size = array.size();
		u8(snapshot::kArray);
		u8(array.is_read_only() ? snapshot::kReadOnly : 0);
		u32(type);
		u32(static_cast<uint32_t>(size));
		for (int64_t index = 0; index < size; ++index) {
			write(array[index], depth + 1);
		}
	}

	void dict(const Dictionary &dict, int depth) {
		const uint64_t identity = identity_of(dict);
		const auto found = containers_.find(identity);
		if (found != containers_.end()) {
			u8(snapshot::kContainer);
			u32(found->second);
			return;
		}
		const uint32_t key_type = dict.is_typed_key() ? type_of(dict.get_typed_key_builtin(), dict.get_typed_key_class_name(), dict.get_typed_key_script()) : 0;
		const uint32_t value_type = dict.is_typed_value() ? type_of(dict.get_typed_value_builtin(), dict.get_typed_value_class_name(), dict.get_typed_value_script()) : 0;
		containers_.emplace(identity, next_container_++);
		const Array keys = dict.keys();
		const Array values = dict.values();
		const int64_t size = keys.size();
		u8(snapshot::kDict);
		u8(dict.is_read_only() ? snapshot::kReadOnly : 0);
		u32(key_type);
		u32(value_type);
		u32(static_cast<uint32_t>(size));
		for (int64_t index = 0; index < size; ++index) {
			write(keys[index], depth + 1);
			write(values[index], depth + 1);
		}
	}

	void packed(const Variant &value) {
		const uint64_t identity = identity_of_packed(value);
		const auto found = packeds_.find(identity);
		if (found != packeds_.end()) {
			u8(snapshot::kPacked);
			u32(found->second);
			return;
		}
		packeds_.emplace(identity, next_packed_++);
		switch (value.get_type()) {
			case Variant::PACKED_BYTE_ARRAY: {
				const godot::PackedByteArray bytes = value;
				u8(snapshot::kPackedByte);
				u32(static_cast<uint32_t>(bytes.size()));
				out_.insert(out_.end(), bytes.ptr(), bytes.ptr() + bytes.size());
				return;
			}
			case Variant::PACKED_INT32_ARRAY: {
				const godot::PackedInt32Array ints = value;
				u8(snapshot::kPackedInt32);
				u32(static_cast<uint32_t>(ints.size()));
				for (int64_t index = 0; index < ints.size(); ++index) {
					u32(static_cast<uint32_t>(ints[index]));
				}
				return;
			}
			default: {
				const godot::PackedStringArray strings = value;
				u8(snapshot::kPackedString);
				u32(static_cast<uint32_t>(strings.size()));
				for (int64_t index = 0; index < strings.size(); ++index) {
					text(utf8(strings[index]));
				}
				return;
			}
		}
	}

	std::vector<uint8_t> out_;
	std::unordered_map<std::string, uint32_t> texts_;
	std::vector<snapshot::TypeInfo> types_;
	std::unordered_map<uint64_t, uint32_t> containers_;
	std::unordered_map<uint64_t, uint32_t> packeds_;
	uint32_t next_container_ = 0;
	uint32_t next_packed_ = 0;
};

} // namespace

godot::PackedByteArray encode_snapshot(const Variant &value) {
	Encoder encoder;
	return encoder.encode(value);
}

} // namespace aurelion::rules::bridge
