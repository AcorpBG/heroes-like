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
//     battle_port_replay [--repeat N] [--prime OTHER.bin] CAPTURE.bin
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

// Decodes var_to_bytes blobs into a State and encodes State values back the same
// way. Types the battle state does not model are kept as their raw bytes.
class Codec {
public:
	explicit Codec(State &state) :
			state_(state) {}

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
		if (value.kind != Kind::Opaque) {
			fail("expected a PackedByteArray");
		}
		const std::string &raw = opaque_[value.ref];
		uint32_t header = 0;
		uint32_t length = 0;
		std::memcpy(&header, raw.data(), 4);
		std::memcpy(&length, raw.data() + 4, 4);
		if ((header & kTypeMask) != PACKED_BYTE_ARRAY) {
			fail("expected a PackedByteArray");
		}
		return raw.substr(8, length);
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
				state_.array(node).element_type = element;
				ValueList items;
				items.reserve(count);
				for (uint32_t index = 0; index < count; ++index) {
					items.push_back(decode(reader));
				}
				state_.array(node).items = std::move(items);
				return Value::of_ref(Kind::Array, node);
			}
			case DICTIONARY: {
				const TypeRef key_type = read_type(reader, (header >> 16) & 3);
				const TypeRef value_type = read_type(reader, (header >> 18) & 3);
				const uint32_t count = reader.u32() & 0x7FFFFFFF;
				const uint32_t node = state_.new_dict();
				state_.dict(node).key_type = key_type;
				state_.dict(node).value_type = value_type;
				ValueList keys;
				ValueList values;
				keys.reserve(count);
				values.reserve(count);
				for (uint32_t index = 0; index < count; ++index) {
					keys.push_back(decode(reader));
					values.push_back(decode(reader));
				}
				state_.dict(node).keys = std::move(keys);
				state_.dict(node).values = std::move(values);
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
				reader.skip(length + (4 - length % 4) % 4);
				return opaque(start, reader.at);
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
				out += opaque_[value.ref];
				return;
		}
	}

	State &state_;
	std::vector<ContainerType> types_;
	std::vector<std::string> opaque_;
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
};

struct Capture {
	std::string key;
	std::vector<std::string> blobs;
	std::vector<Entry> entries;
};

Capture read_capture(const char *path) {
	State meta;
	Codec codec(meta);
	const Value root = codec.decode(read_file(path));
	Capture capture;
	const Value key = field(meta, root, "key");
	capture.key = meta.text(key.ref);
	const Value blobs = field(meta, root, "blobs");
	for (const Value &blob : items(meta, blobs)) {
		capture.blobs.push_back(codec.bytes_of(blob));
	}
	std::map<std::string, const Function *> functions;
	const Value rows = field(meta, root, "entries");
	for (const Value &row : items(meta, rows)) {
		const ValueList &parts = items(meta, row);
		if (parts.size() != 4 || !parts[0].is_string_like()) {
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
// functions which only read their arguments share is decoded once; a function
// that writes into its arguments gets its own copy per entry. The rounds share
// one State, cleared between them, as the native engine keeps one State and its
// memory from resolve to resolve.
struct Loaded {
	Loaded(const Capture &capture, State &state) :
			capture(capture), state(state), offsets(capture.entries.size() + 1), shared(capture.blobs.size()), decoded(capture.blobs.size(), false) {
		// As StateBridge::load starts a resolve: atoms and nodes cleared, node buffers kept.
		state.clear();
	}

	// Entry `index`'s arguments, decoded now if they were not yet.
	const Value *prepare(size_t index) {
		while (prepared <= index) {
			const size_t arrays = state.array_count();
			const size_t dicts = state.dict_count();
			const Entry &entry = capture.entries[prepared];
			offsets[prepared] = args.size();
			for (int64_t id : entry.args) {
				const size_t blob = static_cast<size_t>(id);
				if (entry.function->mutates) {
					args.push_back(codec.decode(capture.blobs[blob]));
					continue;
				}
				if (!decoded[blob]) {
					shared[blob] = codec.decode(capture.blobs[blob]);
					decoded[blob] = true;
				}
				args.push_back(shared[blob]);
			}
			decoded_arrays += state.array_count() - arrays;
			decoded_dicts += state.dict_count() - dicts;
			++prepared;
		}
		return args.data() + offsets[index];
	}
	// The nodes the calls made, not the decoding.
	size_t made_arrays() const { return state.array_count() - decoded_arrays; }
	size_t made_dicts() const { return state.dict_count() - decoded_dicts; }

	const Capture &capture;
	State &state;
	Codec codec{ state };
	std::vector<Value> args; // per entry, arity values each
	std::vector<size_t> offsets;
	std::vector<Value> shared;
	std::vector<bool> decoded;
	size_t prepared = 0;
	size_t decoded_arrays = 0;
	size_t decoded_dicts = 0;
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
		} else {
			path = argv[index];
		}
	}
	if (path == nullptr) {
		std::fprintf(stderr, "usage: battle_port_replay [--repeat N] [--prime OTHER.bin] CAPTURE.bin\n");
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
				if (loaded.codec.encode(loaded.args[loaded.offsets[index] + arg]) != capture.blobs[static_cast<size_t>(entry.after[arg])]) {
					problem = "argument " + std::to_string(arg) + " afterwards";
				}
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
