// battle_port_replay: the G1 replay of the battle port (tools/battle_port_g1/g1.py,
// docs/native-rules-engine-transition.md, Phase 1, "Checkpoint G1"). Native only:
// no Godot, no bridge.
//
// A capture holds one resolve's outermost entries into the ported set, as the
// GDScript at the branch point made them: each entry's function, its arguments
// and its result, as var_to_bytes blobs. The replay runs every entry in ONE
// State, never cleared, so the pool grows as it would in a native loop, and
// times only the calls. Every result, and every written argument afterwards,
// must encode to the bytes GDScript gave.
//
// t_nat_us decodes the whole resolve first and times all the calls in a row
// under one clock. That is tens of MB of battle copies, so each call starts
// with its battle out of cache, which the native loop never does:
// t_nat_warm_us decodes each entry's arguments just before its call, outside
// the clock, and times each call alone, less the clock's own cost. The split by
// function comes from the warm pass.
//
// Each pass runs the resolve --repeat times on its own State, each round cleared
// first as StateBridge::load clears it, which keeps the node buffers. The first
// round (t_nat_first_us, t_nat_warm_first_us) finds a new State, or with
// --prime one that last held another resolve, run untimed before it: the State
// an engine that keeps its State between resolves hands the next one. The later
// rounds find the buffers of the same resolve. t_nat_us and t_nat_warm_us are
// the median round, and the split by function is the median warm round's.
//
// The host is the capture's: its content (the unit, hero, faction and spell rows
// and the files the port reads, decoded into the State before each round, as an
// engine keeps its content resident) and its objects. g1_probe.gd writes a
// RandomNumberGenerator as its seed and state and the session as the blobs of
// the properties the port reads, so a property that is also an argument is the
// same container.
//
// The memos the port shares with GDScript (its table's shared_memos) are the capture's
// too: a writing entry holds them as they were before it, decoded with its
// arguments and its own, and the host hands the port that entry's. A memo
// container that is one of the entry's arguments, or held in one, is that
// argument's node; the specialty catalog is the resident content's. After the
// calls, each writing entry's memos must give the signature GDScript's left
// (the scoring memos' entries). GDScript's own board-read memo
// (the table's gdscript_only), which the capture still holds, is neither
// decoded nor compared: the native board reads keep theirs in the State.
//
// A writing entry that left its arguments as it found them reads them as a
// reading entry does, from the nodes shared by blob, so that the State's memo
// finds them from call to call as the native loop finds its battle;
// --fresh-writers decodes them per entry, as every other writing entry.
//
//     battle_port_replay [--repeat N] [--prime OTHER.bin] [--fresh-writers] CAPTURE.bin
//
// prints one JSON line. Exit 0, or 1 with the problem.

#include "aurelion_rules/battle_state.hpp"
#include "aurelion_rules/port/registry.hpp"

#include <algorithm>
#include <chrono>
#include <cstdint>
#include <cstdio>
#include <cstring>
#include <fstream>
#include <functional>
#include <map>
#include <stdexcept>
#include <string>
#include <vector>

namespace {

using aurelion::rules::port::Function;
using aurelion::rules::state::Kind;
using aurelion::rules::state::State;
using aurelion::rules::state::TypeRef;
using aurelion::rules::state::Value;
using aurelion::rules::state::ValueList;
using Clock = std::chrono::steady_clock;

// Godot's Variant::Type numbers and the header bits of its binary serialization
// (core/io/marshalls.cpp).
enum VariantType : uint32_t {
	NIL = 0,
	BOOL = 1,
	INT = 2,
	FLOAT = 3,
	STRING = 4,
	VECTOR2 = 5,
	VECTOR2I = 6,
	RECT2 = 7,
	RECT2I = 8,
	VECTOR3 = 9,
	VECTOR3I = 10,
	VECTOR4 = 12,
	VECTOR4I = 13,
	COLOR = 20,
	STRING_NAME = 21,
	DICTIONARY = 27,
	ARRAY = 28,
	PACKED_BYTE_ARRAY = 29,
	PACKED_INT32_ARRAY = 30,
	PACKED_INT64_ARRAY = 31,
	PACKED_FLOAT32_ARRAY = 32,
	PACKED_FLOAT64_ARRAY = 33,
	PACKED_STRING_ARRAY = 34,
	PACKED_VECTOR2_ARRAY = 35,
	PACKED_VECTOR3_ARRAY = 36,
	PACKED_COLOR_ARRAY = 37,
	PACKED_VECTOR4_ARRAY = 38,
};
constexpr uint32_t kTypeMask = 0xFF;
constexpr uint32_t kFlag64 = 1u << 16;

[[noreturn]] void fail(const std::string &message) {
	throw std::runtime_error(message);
}

struct Reader {
	const uint8_t *at;
	const uint8_t *end;

	void need(size_t bytes) const {
		if (static_cast<size_t>(end - at) < bytes) {
			fail("a blob ends early");
		}
	}
	uint32_t u32() {
		need(4);
		uint32_t value = 0;
		std::memcpy(&value, at, 4);
		at += 4;
		return value;
	}
	uint64_t u64() {
		need(8);
		uint64_t value = 0;
		std::memcpy(&value, at, 8);
		at += 8;
		return value;
	}
	std::string text() {
		const uint32_t length = u32();
		need(length);
		std::string value(reinterpret_cast<const char *>(at), length);
		at += length;
		const uint32_t pad = (4 - length % 4) % 4;
		need(pad);
		at += pad;
		return value;
	}
	void skip(size_t bytes) {
		need(bytes);
		at += bytes;
	}
};

void put_u32(std::string &out, uint32_t value) {
	out.append(reinterpret_cast<const char *>(&value), 4);
}

void put_u64(std::string &out, uint64_t value) {
	out.append(reinterpret_cast<const char *>(&value), 8);
}

void put_text(std::string &out, const std::string &text) {
	put_u32(out, static_cast<uint32_t>(text.size()));
	out += text;
	out.append((4 - text.size() % 4) % 4, '\0');
}

// The markers g1_probe.gd writes for objects: {"__g1_rng__": [seed, state]} and
// {"__g1_object__": {property: blob id}}.
constexpr const char *kRngMarker = "__g1_rng__";
constexpr const char *kObjectMarker = "__g1_object__";
// And for a memo: {"__g1_arg__": path} (an argument, or a container in one),
// {"__g1_content__": [file, field]} and {"__g1_catalog_index__": file}.
constexpr const char *kArgMarker = "__g1_arg__";
constexpr const char *kContentMarker = "__g1_content__";
constexpr const char *kCatalogIndexMarker = "__g1_catalog_index__";

// The memos, in the order of g1_probe.gd's _STATICS.
constexpr const char *kStatics[][2] = {
	{ "res://scripts/core/BattleRules.gd", "_presentation_queue_written" },
	{ "res://scripts/core/BattleRules.gd", "_board_read_scope_depth" },
	{ "res://scripts/core/BattleRules.gd", "_board_read_scope_battle" },
	{ "res://scripts/core/BattleRules.gd", "_validation_board_read_cache_disabled" },
	{ "res://scripts/core/BattleRules.gd", "_board_read_cache_hits" },
	{ "res://scripts/core/BattleRules.gd", "_board_read_scope_cache" },
	{ "res://scripts/core/BattleRules.gd", "_hero_payload_cache" },
	{ "res://scripts/core/BattleAiRules.gd", "_scoring_scope_depth" },
	{ "res://scripts/core/BattleAiRules.gd", "_scoring_living" },
	{ "res://scripts/core/BattleAiRules.gd", "_scoring_stack_terms" },
	{ "res://scripts/core/HeroProgressionRules.gd", "_catalog_source" },
	{ "res://scripts/core/HeroProgressionRules.gd", "_catalog_index" },
};
constexpr size_t kStaticCount = sizeof(kStatics) / sizeof(kStatics[0]);
// GDScript's own board-read memo: kStatics[1] to [5].
constexpr size_t kGdscriptOnlyFirst = 1;
constexpr size_t kGdscriptOnlyEnd = 6;
constexpr size_t kScoringLiving = 8;
constexpr size_t kScoringTerms = 9;
// g1_probe.gd's _memo_signature: board-read hits, board-read cache keys (both
// GDScript's own, not compared), term entries, complete term entries, living entries.
constexpr size_t kSignatureSize = 5;
constexpr size_t kSignatureCompared = 2;

// --fresh-writers: every writing entry decodes its own arguments.
bool fresh_writers = false;

// An object of a capture: a RandomNumberGenerator, or the session as the
// properties the port reads.
struct ReplayObject {
	bool rng = false;
	uint64_t seed = 0;
	uint64_t state = 0;
	std::vector<std::pair<std::string, int64_t>> ids; // property, blob id, in the marker's order
	std::vector<uint32_t> atoms; // the properties' atoms
	std::vector<Value> values;
};

// Decodes var_to_bytes blobs into a State and encodes State values back the same
// way. Types the battle state does not model are kept as their raw bytes; the
// object markers become opaque objects, whose property blobs `resolve` decodes.
class Codec {
public:
	explicit Codec(State &state) :
			state_(state) {}

	std::function<Value(int64_t)> resolve;
	// A memo's marker (kArgMarker, ...) with its decoded payload: the value it
	// stands for. Without it a marker is the Dictionary it is.
	std::function<Value(const std::string &, const Value &)> alias;

	ReplayObject *object(uint32_t ref) {
		return ref < object_of_.size() && object_of_[ref] >= 0 ? &objects_[static_cast<size_t>(object_of_[ref])] : nullptr;
	}

	Value new_object(ReplayObject object) {
		objects_.push_back(std::move(object));
		object_of_.push_back(static_cast<int64_t>(objects_.size() - 1));
		opaque_.emplace_back();
		return Value::of_ref(Kind::Opaque, static_cast<uint32_t>(opaque_.size() - 1));
	}

	Value decode(const std::string &blob) {
		Reader reader{ reinterpret_cast<const uint8_t *>(blob.data()), reinterpret_cast<const uint8_t *>(blob.data()) + blob.size() };
		const Value value = decode(reader);
		if (reader.at != reader.end) {
			fail("a blob has bytes after its value");
		}
		return value;
	}

	std::string encode(const Value &value) const {
		std::string out;
		encode(value, out);
		return out;
	}

	// The payload of a PackedByteArray value.
	std::string bytes_of(const Value &value) const {
		if (value.kind != Kind::PackedByte) {
			fail("expected a PackedByteArray");
		}
		const std::vector<uint8_t> &bytes = state_.packed(value.ref).bytes;
		return std::string(reinterpret_cast<const char *>(bytes.data()), bytes.size());
	}

private:
	struct ContainerType {
		uint32_t kind = 0; // 1 builtin, 2 class name, 3 script path
		uint32_t builtin = 0;
		std::string name;
	};

	TypeRef read_type(Reader &reader, uint32_t kind) {
		if (kind == 0) {
			return 0;
		}
		ContainerType type;
		type.kind = kind;
		if (kind == 1) {
			type.builtin = reader.u32();
		} else {
			type.name = reader.text();
		}
		for (size_t index = 0; index < types_.size(); ++index) {
			if (types_[index].kind == type.kind && types_[index].builtin == type.builtin && types_[index].name == type.name) {
				return static_cast<TypeRef>(index + 1);
			}
		}
		types_.push_back(type);
		return static_cast<TypeRef>(types_.size());
	}

	void write_type(std::string &out, TypeRef ref) const {
		if (ref == 0) {
			return;
		}
		const ContainerType &type = types_[ref - 1];
		if (type.kind == 1) {
			put_u32(out, type.builtin);
		} else {
			put_text(out, type.name);
		}
	}

	uint32_t type_kind(TypeRef ref) const {
		return ref == 0 ? 0 : types_[ref - 1].kind;
	}

	Value opaque(const uint8_t *start, const uint8_t *end) {
		opaque_.emplace_back(reinterpret_cast<const char *>(start), static_cast<size_t>(end - start));
		return Value::of_ref(Kind::Opaque, static_cast<uint32_t>(opaque_.size() - 1));
	}

	Value decode(Reader &reader) {
		const uint8_t *start = reader.at;
		const uint32_t header = reader.u32();
		const uint32_t type = header & kTypeMask;
		const bool wide = (header & kFlag64) != 0;
		switch (type) {
			case NIL:
				return Value();
			case BOOL:
				return Value::of_bool(reader.u32() != 0);
			case INT:
				if (wide) {
					return Value::of_int(static_cast<int64_t>(reader.u64()));
				}
				return Value::of_int(static_cast<int32_t>(reader.u32()));
			case FLOAT: {
				if (wide) {
					const uint64_t bits = reader.u64();
					double value = 0;
					std::memcpy(&value, &bits, 8);
					return Value::of_float(value);
				}
				const uint32_t bits = reader.u32();
				float value = 0;
				std::memcpy(&value, &bits, 4);
				return Value::of_float(static_cast<double>(value));
			}
			case STRING:
			case STRING_NAME: {
				const std::string text = reader.text();
				return Value::of_ref(type == STRING ? Kind::String : Kind::StringName, state_.intern(text));
			}
			case VECTOR2I: {
				const int32_t x = static_cast<int32_t>(reader.u32());
				const int32_t y = static_cast<int32_t>(reader.u32());
				return Value::of_vector2i(x, y);
			}
			case ARRAY: {
				const TypeRef element = read_type(reader, (header >> 16) & 3);
				const uint32_t count = reader.u32() & 0x7FFFFFFF;
				const uint32_t node = state_.new_array();
				state_.array_node(node).element_type = element;
				ValueList items;
				items.reserve(count);
				for (uint32_t index = 0; index < count; ++index) {
					items.push_back(decode(reader));
				}
				state_.array_node(node).items = std::move(items);
				return Value::of_ref(Kind::Array, node);
			}
			case DICTIONARY: {
				const TypeRef key_type = read_type(reader, (header >> 16) & 3);
				const TypeRef value_type = read_type(reader, (header >> 18) & 3);
				const uint32_t count = reader.u32() & 0x7FFFFFFF;
				if (count == 1 && key_type == 0 && value_type == 0) {
					const uint8_t *mark = reader.at;
					if (reader.u32() == STRING) {
						const std::string marker = reader.text();
						if (marker == kRngMarker || marker == kObjectMarker) {
							return decode_object(reader, marker == kRngMarker);
						}
						if (alias && (marker == kArgMarker || marker == kContentMarker || marker == kCatalogIndexMarker)) {
							return alias(marker, decode(reader));
						}
					}
					reader.at = mark;
				}
				const uint32_t node = state_.new_dict();
				state_.dict_node(node).key_type = key_type;
				state_.dict_node(node).value_type = value_type;
				ValueList keys;
				ValueList values;
				keys.reserve(count);
				values.reserve(count);
				for (uint32_t index = 0; index < count; ++index) {
					keys.push_back(decode(reader));
					values.push_back(decode(reader));
				}
				state_.dict_node(node).keys = std::move(keys);
				state_.dict_node(node).values = std::move(values);
				return Value::of_ref(Kind::Dict, node);
			}
			case VECTOR2:
				reader.skip(wide ? 16 : 8);
				return opaque(start, reader.at);
			case RECT2:
			case VECTOR4:
				reader.skip(wide ? 32 : 16);
				return opaque(start, reader.at);
			case VECTOR3:
				reader.skip(wide ? 24 : 12);
				return opaque(start, reader.at);
			case RECT2I:
			case VECTOR4I:
			case COLOR:
				reader.skip(16);
				return opaque(start, reader.at);
			case VECTOR3I:
				reader.skip(12);
				return opaque(start, reader.at);
			case PACKED_BYTE_ARRAY: {
				const uint32_t length = reader.u32();
				reader.need(length);
				const uint32_t node = state_.new_packed(Kind::PackedByte);
				state_.packed_node(node).bytes.assign(reader.at, reader.at + length);
				reader.skip(length + (4 - length % 4) % 4);
				return Value::of_ref(Kind::PackedByte, node);
			}
			case PACKED_INT32_ARRAY:
			case PACKED_FLOAT32_ARRAY:
				reader.skip(static_cast<size_t>(reader.u32()) * 4);
				return opaque(start, reader.at);
			case PACKED_INT64_ARRAY:
			case PACKED_FLOAT64_ARRAY:
				reader.skip(static_cast<size_t>(reader.u32()) * 8);
				return opaque(start, reader.at);
			case PACKED_VECTOR2_ARRAY:
				reader.skip(static_cast<size_t>(reader.u32()) * (wide ? 16 : 8));
				return opaque(start, reader.at);
			case PACKED_VECTOR3_ARRAY:
				reader.skip(static_cast<size_t>(reader.u32()) * (wide ? 24 : 12));
				return opaque(start, reader.at);
			case PACKED_COLOR_ARRAY:
			case PACKED_VECTOR4_ARRAY:
				reader.skip(static_cast<size_t>(reader.u32()) * (type == PACKED_VECTOR4_ARRAY && wide ? 32 : 16));
				return opaque(start, reader.at);
			case PACKED_STRING_ARRAY: {
				const uint32_t count = reader.u32();
				for (uint32_t index = 0; index < count; ++index) {
					reader.text();
				}
				return opaque(start, reader.at);
			}
			default:
				fail("Variant type " + std::to_string(type) + " in a capture is not replayed");
		}
	}

	// The value of a marker: [seed, state], or {property: blob id}.
	Value decode_object(Reader &reader, bool rng) {
		const auto bad = [] { fail("an object marker is not shaped as g1_probe.gd writes it"); };
		ReplayObject object;
		object.rng = rng;
		const uint32_t header = reader.u32();
		const uint32_t count = reader.u32() & 0x7FFFFFFF;
		if (header != (rng ? ARRAY : DICTIONARY) || (rng && count != 2)) {
			bad();
		}
		for (uint32_t index = 0; index < count; ++index) {
			std::string name;
			if (!rng) {
				if (reader.u32() != STRING) {
					bad();
				}
				name = reader.text();
			}
			const Value number = decode(reader);
			if (number.kind != Kind::Int) {
				bad();
			}
			if (rng) {
				(index == 0 ? object.seed : object.state) = static_cast<uint64_t>(number.i);
			} else {
				object.ids.emplace_back(std::move(name), number.i);
			}
		}
		for (const auto &item : object.ids) {
			object.atoms.push_back(state_.intern(item.first));
			object.values.push_back(resolve ? resolve(item.second) : Value());
		}
		return new_object(std::move(object));
	}

	void encode_object(const ReplayObject &object, std::string &out) const {
		put_u32(out, DICTIONARY);
		put_u32(out, 1);
		put_u32(out, STRING);
		put_text(out, object.rng ? kRngMarker : kObjectMarker);
		put_u32(out, object.rng ? ARRAY : DICTIONARY);
		if (object.rng) {
			put_u32(out, 2);
			encode(Value::of_int(static_cast<int64_t>(object.seed)), out);
			encode(Value::of_int(static_cast<int64_t>(object.state)), out);
			return;
		}
		put_u32(out, static_cast<uint32_t>(object.ids.size()));
		for (const auto &item : object.ids) {
			put_u32(out, STRING);
			put_text(out, item.first);
			encode(Value::of_int(item.second), out);
		}
	}

	void encode(const Value &value, std::string &out) const {
		switch (value.kind) {
			case Kind::Nil:
				put_u32(out, NIL);
				return;
			case Kind::Bool:
				put_u32(out, BOOL);
				put_u32(out, value.b ? 1 : 0);
				return;
			case Kind::Int:
				if (value.i > INT32_MAX || value.i < INT32_MIN) {
					put_u32(out, INT | kFlag64);
					put_u64(out, static_cast<uint64_t>(value.i));
				} else {
					put_u32(out, INT);
					put_u32(out, static_cast<uint32_t>(static_cast<int32_t>(value.i)));
				}
				return;
			case Kind::Float: {
				const float narrow = static_cast<float>(value.f);
				if (static_cast<double>(narrow) != value.f) {
					put_u32(out, FLOAT | kFlag64);
					uint64_t bits = 0;
					std::memcpy(&bits, &value.f, 8);
					put_u64(out, bits);
				} else {
					put_u32(out, FLOAT);
					uint32_t bits = 0;
					std::memcpy(&bits, &narrow, 4);
					put_u32(out, bits);
				}
				return;
			}
			case Kind::String:
			case Kind::StringName:
				put_u32(out, value.kind == Kind::String ? STRING : STRING_NAME);
				put_text(out, state_.text(value.ref));
				return;
			case Kind::Vector2i:
				put_u32(out, VECTOR2I);
				put_u32(out, static_cast<uint32_t>(value.vx()));
				put_u32(out, static_cast<uint32_t>(value.vy()));
				return;
			case Kind::Array: {
				const auto &node = state_.array(value.ref);
				put_u32(out, ARRAY | (type_kind(node.element_type) << 16));
				write_type(out, node.element_type);
				put_u32(out, static_cast<uint32_t>(node.items.size()));
				for (const Value &item : node.items) {
					encode(item, out);
				}
				return;
			}
			case Kind::Dict: {
				const auto &node = state_.dict(value.ref);
				put_u32(out, DICTIONARY | (type_kind(node.key_type) << 16) | (type_kind(node.value_type) << 18));
				write_type(out, node.key_type);
				write_type(out, node.value_type);
				put_u32(out, static_cast<uint32_t>(node.keys.size()));
				for (size_t index = 0; index < node.keys.size(); ++index) {
					encode(node.keys[index], out);
					encode(node.values[index], out);
				}
				return;
			}
			case Kind::Opaque:
				if (value.ref < object_of_.size() && object_of_[value.ref] >= 0) {
					encode_object(objects_[static_cast<size_t>(object_of_[value.ref])], out);
					return;
				}
				out += opaque_[value.ref];
				return;
			case Kind::PackedByte: {
				const std::vector<uint8_t> &bytes = state_.packed(value.ref).bytes;
				put_u32(out, PACKED_BYTE_ARRAY);
				put_u32(out, static_cast<uint32_t>(bytes.size()));
				out.append(reinterpret_cast<const char *>(bytes.data()), bytes.size());
				out.append((4 - bytes.size() % 4) % 4, '\0');
				return;
			}
			default:
				// A kind the replay does not encode: never GDScript's bytes.
				put_u32(out, 0xFFFFFFFFu);
				return;
		}
	}

	State &state_;
	std::vector<ContainerType> types_;
	std::vector<std::string> opaque_;
	std::vector<ReplayObject> objects_;
	std::vector<int64_t> object_of_; // per opaque slot: its object, or -1
};

// Whether a blob is an object marker (decoded per entry, never shared: a call
// may roll an RNG it does not otherwise write).
bool is_object_blob(const std::string &blob) {
	if (blob.size() < 16) {
		return false;
	}
	uint32_t word[3] = {};
	std::memcpy(word, blob.data(), 12);
	if (word[0] != DICTIONARY || word[1] != 1 || word[2] != STRING) {
		return false;
	}
	Reader reader{ reinterpret_cast<const uint8_t *>(blob.data()) + 12, reinterpret_cast<const uint8_t *>(blob.data()) + blob.size() };
	const std::string marker = reader.text();
	return marker == kRngMarker || marker == kObjectMarker;
}

// The capture's host: its objects and its content. Containers are never backed.
class ReplayHost : public aurelion::rules::state::Backing {
public:
	Codec *codec = nullptr;
	std::map<std::pair<int, uint32_t>, Value> rows; // (table, id atom)
	std::map<uint32_t, Value> files; // path atom
	// The memos' (script, name) atoms in kStatics order, and the memos of the
	// entry being called, or none for an entry that reads only.
	std::pair<uint32_t, uint32_t> static_atoms[kStaticCount];
	std::vector<Value> *statics = nullptr;

	void fill_array(State &, uint32_t) override { fail("the replay has no backed Arrays"); }
	void fill_dict(State &, uint32_t) override { fail("the replay has no backed Dictionaries"); }
	int64_t array_size(uint32_t) override { fail("the replay has no backed Arrays"); }
	Value array_at(State &, uint32_t, int64_t) override { fail("the replay has no backed Arrays"); }
	int64_t dict_size(uint32_t) override { fail("the replay has no backed Dictionaries"); }
	bool dict_lookup(State &, uint32_t, const Value &, Value &) override { fail("the replay has no backed Dictionaries"); }

	Value object_get(State &state, uint32_t slot, uint32_t property) override {
		const ReplayObject *object = codec->object(slot);
		if (object != nullptr && !object->rng) {
			for (size_t index = 0; index < object->atoms.size(); ++index) {
				if (object->atoms[index] == property) {
					return object->values[index];
				}
			}
		}
		throw aurelion::rules::state::ScriptError("the capture has no property " + state.text(property) + " of this object");
	}
	bool rng_get(uint32_t slot, uint64_t &seed, uint64_t &state) override {
		const ReplayObject *object = codec->object(slot);
		if (object == nullptr || !object->rng) {
			return false;
		}
		seed = object->seed;
		state = object->state;
		return true;
	}
	void rng_set_state(uint32_t slot, uint64_t state) override {
		ReplayObject *object = codec->object(slot);
		if (object == nullptr || !object->rng) {
			fail("rng_set_state on a slot that is not a RandomNumberGenerator");
		}
		object->state = state;
	}
	uint32_t rng_new(uint64_t seed, uint64_t state) override {
		ReplayObject object;
		object.rng = true;
		object.seed = seed;
		object.state = state;
		return codec->new_object(std::move(object)).ref;
	}
	Value content_row(State &state, aurelion::rules::state::ContentTable table, uint32_t id) override {
		using aurelion::rules::state::ContentTable;
		if (table != ContentTable::Unit && table != ContentTable::Hero && table != ContentTable::Faction && table != ContentTable::Spell) {
			fail("content table " + std::to_string(static_cast<int>(table)) + " is not in the capture (asked for " + state.text(id) + ")");
		}
		const auto found = rows.find({ static_cast<int>(table), id });
		return found == rows.end() ? Value() : found->second;
	}
	Value content_file(State &state, uint32_t path) override {
		const auto found = files.find(path);
		if (found == files.end()) {
			fail("content file " + state.text(path) + " is not in the capture");
		}
		return found->second;
	}
	Value static_get(State &state, uint32_t script, uint32_t name) override {
		return static_slot(state, script, name);
	}
	void static_set(State &state, uint32_t script, uint32_t name, const Value &value) override {
		static_slot(state, script, name) = value;
	}

private:
	Value &static_slot(State &state, uint32_t script, uint32_t name) {
		for (size_t index = 0; index < kStaticCount; ++index) {
			if (static_atoms[index].first == script && static_atoms[index].second == name) {
				if (statics == nullptr || statics->size() != kStaticCount) {
					fail("an entry the registry marks as reading only reached " + state.text(script) + "." + state.text(name));
				}
				return (*statics)[index];
			}
		}
		fail("the capture has no static var " + state.text(script) + "." + state.text(name));
	}
};

std::string read_file(const char *path) {
	std::ifstream file(path, std::ios::binary);
	if (!file) {
		fail(std::string("cannot read ") + path);
	}
	return std::string((std::istreambuf_iterator<char>(file)), std::istreambuf_iterator<char>());
}

Value field(const State &state, const Value &dict, const char *name) {
	uint32_t atom = 0;
	Value out;
	if (dict.kind != Kind::Dict || !state.find_atom(name, atom) || !state.lookup(dict.ref, Value::str(atom), out)) {
		fail(std::string("the capture has no ") + name);
	}
	return out;
}

const ValueList &items(const State &state, const Value &array) {
	if (array.kind != Kind::Array) {
		fail("the capture is not shaped as g1_probe.gd writes it");
	}
	return state.array(array.ref).items;
}

int64_t integer(const Value &value) {
	if (value.kind != Kind::Int) {
		fail("the capture is not shaped as g1_probe.gd writes it");
	}
	return value.i;
}

struct Entry {
	const Function *function = nullptr;
	std::vector<int64_t> args;
	int64_t result = 0;
	std::vector<int64_t> after;
	// A writing entry: the memos' blob ids before it (kStatics order) and their
	// signature afterwards; both empty for an entry that reads only.
	std::vector<int64_t> statics;
	std::vector<int64_t> signature;
};

struct Capture {
	std::string key;
	std::string content; // var_to_bytes of {"unit"|"hero"|"faction"|"spell": {id: row}, "files": {path: data}}
	std::vector<std::string> blobs;
	std::vector<bool> object_blob;
	std::vector<Entry> entries;
};

// The property blob ids of a session marker, or false.
bool object_ids(const std::string &blob, std::vector<std::pair<std::string, int64_t>> &ids) {
	if (!is_object_blob(blob)) {
		return false;
	}
	Reader reader{ reinterpret_cast<const uint8_t *>(blob.data()) + 12, reinterpret_cast<const uint8_t *>(blob.data()) + blob.size() };
	if (reader.text() != kObjectMarker || reader.u32() != DICTIONARY) {
		return false;
	}
	const uint32_t count = reader.u32() & 0x7FFFFFFF;
	for (uint32_t index = 0; index < count; ++index) {
		if (reader.u32() != STRING) {
			return false;
		}
		std::string name = reader.text();
		const uint32_t header = reader.u32();
		if ((header & kTypeMask) != INT) {
			return false;
		}
		const int64_t id = (header & kFlag64) != 0 ? static_cast<int64_t>(reader.u64()) : static_cast<int32_t>(reader.u32());
		ids.emplace_back(std::move(name), id);
	}
	return true;
}

Capture read_capture(const char *path) {
	State meta;
	Codec codec(meta);
	const Value root = codec.decode(read_file(path));
	Capture capture;
	const Value key = field(meta, root, "key");
	capture.key = meta.text(key.ref);
	capture.content = codec.bytes_of(field(meta, root, "content"));
	const Value blobs = field(meta, root, "blobs");
	for (const Value &blob : items(meta, blobs)) {
		capture.blobs.push_back(codec.bytes_of(blob));
		capture.object_blob.push_back(is_object_blob(capture.blobs.back()));
	}
	std::map<std::string, const Function *> functions;
	const Value rows = field(meta, root, "entries");
	for (const Value &row : items(meta, rows)) {
		const ValueList &parts = items(meta, row);
		if ((parts.size() != 4 && parts.size() != 6) || !parts[0].is_string_like()) {
			fail("the capture is not shaped as g1_probe.gd writes it");
		}
		Entry entry;
		const std::string &name = meta.text(parts[0].ref);
		auto found = functions.find(name);
		if (found == functions.end()) {
			found = functions.emplace(name, aurelion::rules::port::find_function(name)).first;
		}
		if (found->second == nullptr) {
			fail("not a ported function: " + name);
		}
		entry.function = found->second;
		for (const Value &id : items(meta, parts[1])) {
			entry.args.push_back(integer(id));
		}
		entry.result = integer(parts[2]);
		for (const Value &id : items(meta, parts[3])) {
			entry.after.push_back(integer(id));
		}
		if (static_cast<int>(entry.args.size()) != entry.function->arity) {
			fail(name + ": the capture has " + std::to_string(entry.args.size()) + " arguments");
		}
		// The memos' blob ids and the signature, each a blob of an Array of ints.
		const auto ints_of = [&](const Value &id, std::vector<int64_t> &out, size_t size) {
			const int64_t blob = integer(id);
			if (blob < 0) {
				return;
			}
			if (static_cast<size_t>(blob) >= capture.blobs.size()) {
				fail("a blob id out of range");
			}
			for (const Value &value : items(meta, codec.decode(capture.blobs[static_cast<size_t>(blob)]))) {
				out.push_back(integer(value));
			}
			if (out.size() != size) {
				fail(name + ": the capture's memos are not shaped as g1_probe.gd writes them");
			}
		};
		if (parts.size() == 6) {
			ints_of(parts[4], entry.statics, kStaticCount);
			ints_of(parts[5], entry.signature, kSignatureSize);
			for (int64_t id : entry.statics) {
				if (id < 0 || static_cast<size_t>(id) >= capture.blobs.size()) {
					fail("a blob id out of range");
				}
			}
		}
		capture.entries.push_back(std::move(entry));
	}
	for (const Entry &entry : capture.entries) {
		for (int64_t id : entry.args) {
			if (id < 0 || static_cast<size_t>(id) >= capture.blobs.size()) {
				fail("a blob id out of range");
			}
		}
	}
	return capture;
}

// One round of a resolve: every entry's arguments are decoded into the State and
// every call runs in it, never cleared between calls. A blob that entries of
// functions which only read their arguments share is decoded once, and so is
// one that a writing entry left as it found it; any other writing entry gets
// its own copy of its arguments. An object is its
// entry's own, and its properties are the entry's arguments of the same blob.
// The rounds share one State, cleared between them, as the native engine keeps
// one State and its memory from resolve to resolve.
struct Loaded {
	Loaded(const Capture &capture, State &state) :
			capture(capture), state(state), offsets(capture.entries.size() + 1), shared(capture.blobs.size()), decoded(capture.blobs.size(), false), statics(capture.entries.size()) {
		// As StateBridge::load starts a resolve: atoms and nodes cleared, node buffers kept.
		state.clear();
		host.codec = &codec;
		state.set_backing(&host);
		for (size_t index = 0; index < kStaticCount; ++index) {
			host.static_atoms[index] = { state.intern(kStatics[index][0]), state.intern(kStatics[index][1]) };
		}
		// The content, resident as the engine keeps it.
		using aurelion::rules::state::ContentTable;
		const Value content = codec.decode(capture.content);
		const std::pair<const char *, ContentTable> tables[] = {
			{ "unit", ContentTable::Unit },
			{ "hero", ContentTable::Hero },
			{ "faction", ContentTable::Faction },
			{ "spell", ContentTable::Spell },
		};
		for (const auto &table : tables) {
			const auto &rows = state.dict(field(state, content, table.first).ref);
			for (size_t index = 0; index < rows.keys.size(); ++index) {
				host.rows[{ static_cast<int>(table.second), rows.keys[index].ref }] = rows.values[index];
			}
		}
		const auto &files = state.dict(field(state, content, "files").ref);
		for (size_t index = 0; index < files.keys.size(); ++index) {
			host.files[files.keys[index].ref] = files.values[index];
		}
		decoded_arrays = state.array_count();
		decoded_dicts = state.dict_count();
	}

	Value shared_value(size_t blob) {
		if (!decoded[blob]) {
			shared[blob] = codec.decode(capture.blobs[blob]);
			decoded[blob] = true;
		}
		return shared[blob];
	}

	// Entry `index`'s arguments, decoded now if they were not yet.
	const Value *prepare(size_t index) {
		while (prepared <= index) {
			const size_t arrays = state.array_count();
			const size_t dicts = state.dict_count();
			const Entry &entry = capture.entries[prepared];
			const bool writer = entry.function->mutates && (fresh_writers || wrote_an_argument(entry));
			offsets[prepared] = args.size();
			args.resize(args.size() + entry.args.size());
			Value *slots = args.data() + offsets[prepared];
			// A writer's copies by blob, for the object properties that are also its arguments.
			std::map<int64_t, Value> own;
			codec.resolve = [&](int64_t id) -> Value {
				if (id < 0 || static_cast<size_t>(id) >= capture.blobs.size()) {
					fail("an object property's blob id out of range");
				}
				if (!writer) {
					return shared_value(static_cast<size_t>(id));
				}
				const auto found = own.find(id);
				if (found != own.end()) {
					return found->second;
				}
				const Value value = codec.decode(capture.blobs[static_cast<size_t>(id)]);
				own.emplace(id, value);
				return value;
			};
			// Objects last, so that their properties find the arguments they share.
			for (int pass = 0; pass < 2; ++pass) {
				for (size_t arg = 0; arg < entry.args.size(); ++arg) {
					const size_t blob = static_cast<size_t>(entry.args[arg]);
					const bool object = capture.object_blob[blob];
					if (object != (pass == 1)) {
						continue;
					}
					if (object || writer) {
						slots[arg] = codec.decode(capture.blobs[blob]);
						own.emplace(entry.args[arg], slots[arg]);
					} else {
						slots[arg] = shared_value(blob);
					}
				}
			}
			codec.resolve = nullptr;
			if (!entry.statics.empty()) {
				prepare_statics(entry, slots, statics[prepared]);
			}
			decoded_arrays += state.array_count() - arrays;
			decoded_dicts += state.dict_count() - dicts;
			++prepared;
		}
		return args.data() + offsets[index];
	}

	// GDScript's bytes of an argument afterwards are not its bytes before.
	static bool wrote_an_argument(const Entry &entry) {
		if (entry.after.size() != entry.args.size()) {
			return true;
		}
		for (size_t arg = 0; arg < entry.args.size(); ++arg) {
			if (entry.after[arg] != entry.args[arg]) {
				return true;
			}
		}
		return false;
	}

	// The host hands entry `index`'s memos to the call about to run.
	void enter(size_t index) {
		host.statics = statics[index].empty() ? nullptr : &statics[index];
	}

	// Entry `index`'s memos now give `want`'s compared part (g1_probe.gd's _memo_signature).
	bool same_signature(size_t index, const std::vector<int64_t> &want) const {
		const std::vector<int64_t> now = signature(index);
		return want.size() == kSignatureSize && std::equal(now.begin() + kSignatureCompared, now.end(), want.begin() + kSignatureCompared);
	}
	std::vector<int64_t> signature(size_t index) const {
		const std::vector<Value> &memo = statics[index];
		std::vector<int64_t> out(kSignatureSize, -1);
		if (memo.size() != kStaticCount) {
			return out;
		}
		if (memo[kScoringTerms].kind == Kind::Dict) {
			out[2] = 0;
			out[3] = 0;
			for (const Value &entries : state.dict(memo[kScoringTerms].ref).values) {
				for (const Value &entry : items(state, entries)) {
					++out[2];
					if (items(state, entry).size() == 3) {
						++out[3];
					}
				}
			}
		}
		if (memo[kScoringLiving].kind == Kind::Dict) {
			out[4] = 0;
			for (const Value &entries : state.dict(memo[kScoringLiving].ref).values) {
				out[4] += static_cast<int64_t>(items(state, entries).size());
			}
		}
		return out;
	}
	// The nodes the calls made, not the decoding.
	size_t made_arrays() const { return state.array_count() - decoded_arrays; }
	size_t made_dicts() const { return state.dict_count() - decoded_dicts; }

	const Capture &capture;
	State &state;
	Codec codec{ state };
	ReplayHost host;
	std::vector<Value> args; // per entry, arity values each
	std::vector<size_t> offsets;
	std::vector<Value> shared;
	std::vector<bool> decoded;
	std::vector<std::vector<Value>> statics; // per entry, kStaticCount values each, or none
	size_t prepared = 0;
	size_t decoded_arrays = 0;
	size_t decoded_dicts = 0;

private:
	// A writing entry's memos, decoded after its arguments, which their markers name.
	void prepare_statics(const Entry &entry, const Value *slots, std::vector<Value> &memo) {
		codec.alias = [&](const std::string &marker, const Value &payload) -> Value {
			if (marker == kArgMarker) {
				return argument_at(slots, entry, payload);
			}
			if (marker == kContentMarker) {
				const ValueList &path = items(state, payload);
				if (path.size() != 2 || !path[0].is_string_like() || !path[1].is_string_like()) {
					fail("a content marker is not shaped as g1_probe.gd writes it");
				}
				return lookup(content_file(path[0]), path[1]);
			}
			return catalog_index(payload);
		};
		memo.resize(kStaticCount);
		for (size_t index = 0; index < kStaticCount; ++index) {
			if (index >= kGdscriptOnlyFirst && index < kGdscriptOnlyEnd) {
				continue;
			}
			memo[index] = codec.decode(capture.blobs[static_cast<size_t>(entry.statics[index])]);
		}
		codec.alias = nullptr;
	}

	// {"__g1_arg__": [argument, step...]}: the argument, then a session's
	// property, a Dictionary's key or an Array's index per step.
	Value argument_at(const Value *slots, const Entry &entry, const Value &payload) {
		const ValueList &path = items(state, payload);
		if (path.empty() || path[0].kind != Kind::Int || path[0].i < 0 || static_cast<size_t>(path[0].i) >= entry.args.size()) {
			fail("an argument marker is not shaped as g1_probe.gd writes it");
		}
		Value at = slots[path[0].i];
		for (size_t step = 1; step < path.size(); ++step) {
			const Value &part = path[step];
			if (at.kind == Kind::Opaque && part.is_string_like()) {
				const ReplayObject *object = codec.object(at.ref);
				bool found = false;
				for (size_t index = 0; object != nullptr && !found && index < object->atoms.size(); ++index) {
					if (object->atoms[index] == part.ref) {
						at = object->values[index];
						found = true;
					}
				}
				if (!found) {
					fail("an argument marker names a property the capture does not hold");
				}
			} else if (at.kind == Kind::Dict && part.is_string_like()) {
				at = lookup(at, part);
			} else if (at.kind == Kind::Array && part.kind == Kind::Int && part.i >= 0 && static_cast<size_t>(part.i) < state.array(at.ref).items.size()) {
				at = state.array(at.ref).items[static_cast<size_t>(part.i)];
			} else {
				fail("an argument marker's path does not lead into the entry's arguments");
			}
		}
		return at;
	}

	Value lookup(const Value &dict, const Value &key) const {
		Value out;
		if (dict.kind != Kind::Dict || !state.lookup(dict.ref, Value::str(key.ref), out)) {
			fail("a memo marker names a key the capture does not hold: " + state.text(key.ref));
		}
		return out;
	}

	Value content_file(const Value &path) {
		const auto found = host.files.find(path.ref);
		if (found == host.files.end()) {
			fail("content file " + state.text(path.ref) + " is not in the capture");
		}
		return found->second;
	}

	// HeroProgressionRules._specialty_catalog's index of the resident content's
	// "items", built once: each Dictionary row by String(row.get("id", "")).
	Value catalog_index(const Value &path) {
		if (catalog.kind == Kind::Nil) {
			if (!path.is_string_like()) {
				fail("a catalog marker is not shaped as g1_probe.gd writes it");
			}
			const Value rows = lookup(content_file(path), state.string("items"));
			const uint32_t index = state.new_dict();
			for (const Value &row : items(state, rows)) {
				if (row.kind != Kind::Dict) {
					continue;
				}
				Value id;
				if (!state.lookup(row.ref, state.string("id"), id)) {
					id = state.string("");
				}
				if (!id.is_string_like()) {
					fail("a specialty id that is not a string is not replayed");
				}
				state.set(index, Value::str(id.ref), row);
			}
			catalog = Value::of_ref(Kind::Dict, index);
		}
		return catalog;
	}

	Value catalog;
};

double clock_overhead_ns() {
	constexpr int kRounds = 1000000;
	Clock::duration total{};
	for (int index = 0; index < kRounds; ++index) {
		const Clock::time_point start = Clock::now();
		total += Clock::now() - start;
	}
	return std::chrono::duration<double, std::nano>(total).count() / kRounds;
}

void append_json_string(std::string &out, const std::string &text) {
	out += '"';
	for (char c : text) {
		if (c == '"' || c == '\\') {
			out += '\\';
			out += c;
		} else if (static_cast<unsigned char>(c) < 0x20) {
			char escaped[8];
			std::snprintf(escaped, sizeof(escaped), "\\u%04x", c);
			out += escaped;
		} else {
			out += c;
		}
	}
	out += '"';
}

int run(int argc, char **argv) {
	int repeat = 3;
	const char *path = nullptr;
	const char *prime_path = nullptr;
	for (int index = 1; index < argc; ++index) {
		const std::string arg = argv[index];
		if (arg == "--repeat" && index + 1 < argc) {
			repeat = std::max(1, std::atoi(argv[++index]));
		} else if (arg == "--prime" && index + 1 < argc) {
			prime_path = argv[++index];
		} else if (arg == "--fresh-writers") {
			fresh_writers = true;
		} else {
			path = argv[index];
		}
	}
	if (path == nullptr) {
		std::fprintf(stderr, "usage: battle_port_replay [--repeat N] [--prime OTHER.bin] [--fresh-writers] CAPTURE.bin\n");
		return 1;
	}
	const Capture capture = read_capture(path);
	Capture primer;
	if (prime_path != nullptr) {
		primer = read_capture(prime_path);
	}
	// --prime: the other resolve's calls on the State, untimed and unchecked.
	auto prime = [&](State &state) {
		if (prime_path == nullptr || primer.entries.empty()) {
			return;
		}
		Loaded loaded(primer, state);
		loaded.prepare(primer.entries.size() - 1);
		try {
			for (size_t index = 0; index < primer.entries.size(); ++index) {
				loaded.enter(index);
				primer.entries[index].function->call(loaded.state, loaded.args.data() + loaded.offsets[index]);
			}
		} catch (const std::exception &error) {
			fail(std::string("the --prime capture failed: ") + error.what());
		}
	};

	// The codec reproduces every blob byte for byte, or the check below means nothing.
	int64_t codec_failures = 0;
	{
		State scratch;
		Codec codec(scratch);
		for (const std::string &blob : capture.blobs) {
			if (codec.encode(codec.decode(blob)) != blob) {
				++codec_failures;
			}
			scratch.clear_nodes();
		}
	}

	// Each round runs every call in a fresh Loaded. In every round the result and
	// every written argument afterwards must encode to GDScript's bytes.
	int64_t mismatches = 0;
	std::vector<std::string> first;
	auto check = [&](Loaded &loaded, const std::vector<Value> &results) {
		for (size_t index = 0; index < capture.entries.size(); ++index) {
			const Entry &entry = capture.entries[index];
			std::string problem;
			if (loaded.codec.encode(results[index]) != capture.blobs[static_cast<size_t>(entry.result)]) {
				problem = "result";
			}
			for (size_t arg = 0; arg < entry.after.size() && problem.empty(); ++arg) {
				const Value &value = loaded.args[loaded.offsets[index] + arg];
				const std::string &want = capture.blobs[static_cast<size_t>(entry.after[arg])];
				const ReplayObject *object = value.kind == Kind::Opaque ? loaded.codec.object(value.ref) : nullptr;
				bool same = true;
				if (object != nullptr && !object->rng) {
					// The session: each property against its blob afterwards.
					std::vector<std::pair<std::string, int64_t>> then;
					same = object_ids(want, then) && then.size() == object->ids.size();
					for (size_t k = 0; same && k < then.size(); ++k) {
						same = then[k].first == object->ids[k].first && then[k].second >= 0 && static_cast<size_t>(then[k].second) < capture.blobs.size() &&
								loaded.codec.encode(object->values[k]) == capture.blobs[static_cast<size_t>(then[k].second)];
					}
				} else {
					same = loaded.codec.encode(value) == want;
				}
				if (!same) {
					problem = "argument " + std::to_string(arg) + " afterwards";
				}
			}
			if (problem.empty() && !entry.signature.empty() && !loaded.same_signature(index, entry.signature)) {
				problem = "memos afterwards";
			}
			if (!problem.empty()) {
				++mismatches;
				if (first.size() < 10) {
					first.push_back(std::string(entry.function->name) + " entry " + std::to_string(index) + ": " + problem);
				}
			}
		}
	};
	auto failed = [&](size_t index, const std::exception &error) {
		fail(std::string(capture.entries[index].function->name) + " entry " + std::to_string(index) + " failed natively where GDScript did not: " + error.what());
	};

	// Warm (t_nat_warm_us): each entry's arguments are decoded just before it, outside
	// the clock, so a call finds its battle in cache, as the native loop finds the
	// battle it keeps updating. Each call is timed alone, less the clock's own cost.
	const double overhead_ns = clock_overhead_ns();
	using ByFunction = std::map<const Function *, std::pair<int64_t, double>>;
	State warm_state;
	prime(warm_state);
	std::vector<double> warm;
	std::vector<ByFunction> warm_by_function;
	size_t made_arrays = 0;
	size_t made_dicts = 0;
	size_t pool_arrays = 0;
	size_t pool_dicts = 0;
	for (int round = 0; round < repeat; ++round) {
		Loaded loaded(capture, warm_state);
		std::vector<Value> results(capture.entries.size());
		ByFunction &by_function = warm_by_function.emplace_back();
		double total_ns = 0.0;
		size_t index = 0;
		try {
			for (; index < capture.entries.size(); ++index) {
				const Value *args = loaded.prepare(index);
				loaded.enter(index);
				const Clock::time_point start = Clock::now();
				results[index] = capture.entries[index].function->call(loaded.state, args);
				const Clock::time_point stop = Clock::now();
				const double ns = std::chrono::duration<double, std::nano>(stop - start).count() - overhead_ns;
				total_ns += ns;
				auto &slot = by_function[capture.entries[index].function];
				slot.first += 1;
				slot.second += ns;
			}
		} catch (const std::exception &error) {
			failed(index, error);
		}
		warm.push_back(total_ns / 1000.0);
		if (round == 0) {
			made_arrays = loaded.made_arrays();
			made_dicts = loaded.made_dicts();
			pool_arrays = loaded.state.array_count();
			pool_dicts = loaded.state.dict_count();
		}
		check(loaded, results);
	}
	// The median round, and its split by function.
	auto median_round = [](const std::vector<double> &rounds) {
		std::vector<size_t> order(rounds.size());
		for (size_t index = 0; index < order.size(); ++index) {
			order[index] = index;
		}
		std::sort(order.begin(), order.end(), [&](size_t a, size_t b) { return rounds[a] < rounds[b]; });
		return order[order.size() / 2];
	};
	const size_t warm_median = median_round(warm);
	std::map<std::string, std::pair<int64_t, double>> per_function;
	for (const auto &item : warm_by_function[warm_median]) {
		per_function[item.first->name] = item.second;
	}

	// Cold (t_nat_us): every argument of the resolve decoded before the clock
	// starts, then all the calls in a row under one clock. A resolve decodes tens
	// of MB of battle copies this way, so each call starts with its battle out of
	// cache, which the native loop never does.
	State cold_state;
	prime(cold_state);
	std::vector<double> totals;
	for (int round = 0; round < repeat; ++round) {
		Loaded loaded(capture, cold_state);
		if (!capture.entries.empty()) {
			loaded.prepare(capture.entries.size() - 1);
		}
		std::vector<Value> results(capture.entries.size());
		size_t index = 0;
		Clock::time_point start;
		Clock::time_point stop;
		try {
			start = Clock::now();
			for (; index < capture.entries.size(); ++index) {
				loaded.enter(index);
				results[index] = capture.entries[index].function->call(loaded.state, loaded.args.data() + loaded.offsets[index]);
			}
			stop = Clock::now();
		} catch (const std::exception &error) {
			failed(index, error);
		}
		totals.push_back(std::chrono::duration<double, std::micro>(stop - start).count());
		check(loaded, results);
	}

	std::string out = "{\"key\": ";
	append_json_string(out, capture.key);
	char number[64];
	auto add = [&](const char *name, double value) {
		std::snprintf(number, sizeof(number), ", \"%s\": %.3f", name, value);
		out += number;
	};
	add("entries", static_cast<double>(capture.entries.size()));
	add("blobs", static_cast<double>(capture.blobs.size()));
	add("t_nat_us", totals[median_round(totals)]);
	add("t_nat_min_us", *std::min_element(totals.begin(), totals.end()));
	add("t_nat_first_us", totals.front());
	add("t_nat_warm_us", warm[warm_median]);
	add("t_nat_warm_first_us", warm.front());
	add("primed", prime_path != nullptr ? 1.0 : 0.0);
	add("made_arrays", static_cast<double>(made_arrays));
	add("made_dicts", static_cast<double>(made_dicts));
	add("pool_arrays", static_cast<double>(pool_arrays));
	add("pool_dicts", static_cast<double>(pool_dicts));
	add("clock_overhead_ns", overhead_ns);
	add("codec_failures", static_cast<double>(codec_failures));
	add("mismatches", static_cast<double>(mismatches));
	out += ", \"first_mismatches\": [";
	for (size_t index = 0; index < first.size(); ++index) {
		if (index != 0) {
			out += ", ";
		}
		append_json_string(out, first[index]);
	}
	out += "], \"per_fn_calls\": {";
	bool first_entry = true;
	for (const auto &item : per_function) {
		if (!first_entry) {
			out += ", ";
		}
		first_entry = false;
		append_json_string(out, item.first);
		std::snprintf(number, sizeof(number), ": %lld", static_cast<long long>(item.second.first));
		out += number;
	}
	out += "}, \"per_fn_us\": {";
	first_entry = true;
	for (const auto &item : per_function) {
		if (!first_entry) {
			out += ", ";
		}
		first_entry = false;
		append_json_string(out, item.first);
		std::snprintf(number, sizeof(number), ": %.3f", item.second.second / 1000.0);
		out += number;
	}
	out += "}}";
	std::printf("%s\n", out.c_str());
	return codec_failures == 0 && mismatches == 0 ? 0 : 1;
}

} // namespace

int main(int argc, char **argv) {
	try {
		return run(argc, argv);
	} catch (const std::exception &error) {
		std::fprintf(stderr, "battle_port_replay: %s\n", error.what());
		return 1;
	}
}
