#include "aurelion_rules/snapshot.hpp"

#include <cstring>
#include <stdexcept>
#include <string_view>

namespace aurelion::rules::snapshot {

using state::Kind;
using state::State;
using state::TypeRef;
using state::Value;

namespace {

// Deep enough for any game data; a deeper snapshot is bad input.
constexpr int kMaxDepth = 4096;

[[noreturn]] void bad(const std::string &what) {
	throw std::runtime_error("bad snapshot: " + what);
}

class Reader {
public:
	Reader(const uint8_t *data, size_t size) :
			data_(data), size_(size) {}

	size_t left() const { return size_ - pos_; }
	uint8_t u8() {
		need(1);
		return data_[pos_++];
	}
	uint32_t u32() {
		need(4);
		uint32_t value = 0;
		for (int shift = 0; shift < 32; shift += 8) {
			value |= static_cast<uint32_t>(data_[pos_++]) << shift;
		}
		return value;
	}
	uint64_t u64() {
		need(8);
		uint64_t value = 0;
		for (int shift = 0; shift < 64; shift += 8) {
			value |= static_cast<uint64_t>(data_[pos_++]) << shift;
		}
		return value;
	}
	const uint8_t *bytes(size_t count) {
		need(count);
		const uint8_t *start = data_ + pos_;
		pos_ += count;
		return start;
	}
	// A count of items each at least item_size bytes long.
	uint32_t count(size_t item_size) {
		const uint32_t value = u32();
		if (static_cast<uint64_t>(value) * item_size > left()) {
			bad("a count past the end");
		}
		return value;
	}

private:
	void need(size_t count) const {
		if (count > size_ - pos_) {
			bad("it ends early");
		}
	}

	const uint8_t *data_;
	size_t size_;
	size_t pos_ = 0;
};

class Decoder {
public:
	Decoder(State &state, Reader &reader, Decoded &out) :
			state_(state), reader_(reader), out_(out) {}

	Value value(int depth) {
		if (depth > kMaxDepth) {
			bad("nested too deep");
		}
		uint8_t tag = reader_.u8();
		while (tag == kType) {
			define_type();
			tag = reader_.u8();
		}
		switch (tag) {
			case kNil:
				return Value();
			case kFalse:
				return Value::of_bool(false);
			case kTrue:
				return Value::of_bool(true);
			case kInt:
				return Value::of_int(static_cast<int64_t>(reader_.u64()));
			case kFloat: {
				const uint64_t bits = reader_.u64();
				double number = 0.0;
				std::memcpy(&number, &bits, sizeof(number));
				return Value::of_float(number);
			}
			case kString:
				return Value::str(text());
			case kStringName:
				return Value::of_ref(Kind::StringName, text());
			case kVector2i: {
				const int32_t x = static_cast<int32_t>(reader_.u32());
				const int32_t y = static_cast<int32_t>(reader_.u32());
				return Value::of_vector2i(x, y);
			}
			case kVector3i: {
				const int32_t x = static_cast<int32_t>(reader_.u32());
				const int32_t y = static_cast<int32_t>(reader_.u32());
				const int32_t z = static_cast<int32_t>(reader_.u32());
				return Value::of_vector3i(x, y, z);
			}
			case kArray:
				return array(depth);
			case kDict:
				return dict(depth);
			case kContainer: {
				const uint32_t id = reader_.u32();
				if (id >= containers_.size()) {
					bad("a container reference before its container");
				}
				return containers_[id];
			}
			case kPackedByte: {
				const uint32_t count = reader_.count(1);
				const uint32_t node = state_.new_packed(Kind::PackedByte);
				const uint8_t *bytes = reader_.bytes(count);
				state_.packed_node(node).bytes.assign(bytes, bytes + count);
				return packed(Kind::PackedByte, node);
			}
			case kPackedInt32: {
				const uint32_t count = reader_.count(4);
				const uint32_t node = state_.new_packed(Kind::PackedInt32);
				std::vector<int32_t> &ints = state_.packed_node(node).ints;
				ints.reserve(count);
				for (uint32_t index = 0; index < count; ++index) {
					ints.push_back(static_cast<int32_t>(reader_.u32()));
				}
				return packed(Kind::PackedInt32, node);
			}
			case kPackedString: {
				const uint32_t count = reader_.count(4);
				const uint32_t node = state_.new_packed(Kind::PackedString);
				for (uint32_t index = 0; index < count; ++index) {
					const uint32_t atom = text();
					state_.packed_node(node).atoms.push_back(atom);
				}
				return packed(Kind::PackedString, node);
			}
			case kPacked: {
				const uint32_t id = reader_.u32();
				if (id >= packeds_.size()) {
					bad("a packed array reference before its array");
				}
				return packeds_[id];
			}
			case kUnsupported: {
				const uint8_t type = reader_.u8();
				out_.unsupported.push_back(std::to_string(type) + " " + state_.text(text()));
				return Value::of_ref(Kind::Opaque, static_cast<uint32_t>(out_.unsupported.size() - 1));
			}
			default:
				bad("unknown tag " + std::to_string(tag));
		}
	}

private:
	uint32_t text() {
		const uint32_t id = reader_.u32();
		if (id != kNewText) {
			if (id >= atoms_.size()) {
				bad("a text reference before its text");
			}
			return atoms_[id];
		}
		const uint32_t size = reader_.count(1);
		const uint8_t *bytes = reader_.bytes(size);
		const uint32_t atom = state_.intern(std::string_view(reinterpret_cast<const char *>(bytes), size));
		atoms_.push_back(atom);
		return atom;
	}

	void define_type() {
		const uint32_t id = reader_.u32();
		if (id != out_.types.size() + 1) {
			bad("type ids out of order");
		}
		TypeInfo info;
		info.builtin = reader_.u8();
		info.class_name = state_.text(text());
		info.script = state_.text(text());
		out_.types.push_back(info);
		state_.set_type_builtin(id, info.builtin);
	}

	TypeRef type_ref() {
		const uint32_t type = reader_.u32();
		if (type > out_.types.size()) {
			bad("a type before its definition");
		}
		return type;
	}

	Value array(int depth) {
		const uint8_t flags = reader_.u8();
		const TypeRef type = type_ref();
		const uint32_t count = reader_.count(1);
		const uint32_t node = state_.new_array();
		const Value made = Value::of_ref(Kind::Array, node);
		containers_.push_back(made);
		// Nodes keep their place while others are added (NodePool).
		state::ArrayNode &target = state_.array_node(node);
		target.element_type = type;
		target.items.reserve(count);
		for (uint32_t index = 0; index < count; ++index) {
			const Value item = value(depth + 1);
			target.items.push_back(item);
		}
		target.read_only = (flags & kReadOnly) != 0;
		return made;
	}

	Value dict(int depth) {
		const uint8_t flags = reader_.u8();
		const TypeRef key_type = type_ref();
		const TypeRef value_type = type_ref();
		const uint32_t count = reader_.count(2);
		const uint32_t node = state_.new_dict();
		const Value made = Value::of_ref(Kind::Dict, node);
		containers_.push_back(made);
		state::DictNode &target = state_.dict_node(node);
		target.key_type = key_type;
		target.value_type = value_type;
		target.keys.reserve(count);
		target.values.reserve(count);
		for (uint32_t index = 0; index < count; ++index) {
			const Value key = value(depth + 1);
			const Value item = value(depth + 1);
			target.keys.push_back(key);
			target.values.push_back(item);
		}
		target.read_only = (flags & kReadOnly) != 0;
		return made;
	}

	Value packed(Kind kind, uint32_t node) {
		const Value made = Value::of_ref(kind, node);
		packeds_.push_back(made);
		return made;
	}

	State &state_;
	Reader &reader_;
	Decoded &out_;
	std::vector<uint32_t> atoms_;
	std::vector<Value> containers_;
	std::vector<Value> packeds_;
};

} // namespace

Decoded decode(State &state, const uint8_t *data, size_t size) {
	if (size < sizeof(kMagic) || std::memcmp(data, kMagic, sizeof(kMagic)) != 0) {
		bad("no snapshot magic");
	}
	Reader reader(data + sizeof(kMagic), size - sizeof(kMagic));
	Decoded out;
	const size_t first_dict = state.dict_count();
	Decoder decoder(state, reader, out);
	out.root = decoder.value(0);
	if (reader.left() != 0) {
		bad("bytes after the value");
	}
	for (size_t node = first_dict; node < state.dict_count(); ++node) {
		state.dict_node(static_cast<uint32_t>(node)).keys.prepare_index();
	}
	return out;
}

} // namespace aurelion::rules::snapshot
