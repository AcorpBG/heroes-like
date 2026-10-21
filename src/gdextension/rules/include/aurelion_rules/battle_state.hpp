#pragma once

// The battle state as GDScript holds it (docs/native-rules-engine-transition.md,
// section 4 "State"): a tree of Dictionaries, Arrays, bools, ints, floats and
// strings, kept with GDScript's key order, int/float types, unknown keys and
// shared containers. The Godot adapter converts a battle Dictionary into a
// State and writes it back into the same containers (or into new ones).
//
// Containers live in the State's pools and Values refer to them by index, so a
// container reached from two places is one node, as it is one object in Godot.
// Strings are interned: equal texts have one atom, and the texts the port
// names in code (battle_keys.inc, day_keys.inc, ai_keys.inc) have fixed atoms. Pool references stay valid
// while nodes are added (NodePool).
//
// A node can be backed: its contents still live in the adapter's container and
// are read from there one value at a time, until something needs the whole
// node (a write, an iteration, raw access), which fills it first. Per-call
// checks of the port read the game's Dictionaries this way without converting
// the battle.

#include "aurelion_rules/battle_hex.hpp"

#include <cstdint>
#include <deque>
#include <initializer_list>
#include <memory>
#include <stdexcept>
#include <string>
#include <string_view>
#include <unordered_map>
#include <vector>

namespace aurelion::rules::state {

enum class Kind : uint8_t {
	Nil,
	Bool,
	Int,
	Float,
	String,
	StringName,
	Vector2i,
	Array,
	Dict,
	// A Variant the State does not model (an Object, a Vector2, ...): the
	// adapter keeps it and writes it back unchanged. ref is its slot there.
	Opaque,
	// x and y in i, as a Vector2i's, and z in z.
	Vector3i,
	// PackedByteArray, PackedInt32Array and PackedStringArray: ref is a packed
	// node. Godot shares one packed array between the Variants that hold it, so
	// a node is that one array.
	PackedByte,
	PackedInt32,
	PackedString,
};

struct Value {
	Kind kind = Kind::Nil;
	// A Vector3i's z (in the padding after kind).
	int32_t z = 0;
	union {
		int64_t i;
		double f;
		uint32_t ref; // string atom, array node, dict node or opaque slot
		bool b;
	};

	Value() :
			i(0) {}
	static Value nil() { return Value(); }
	static Value of_bool(bool value) {
		Value v;
		v.kind = Kind::Bool;
		v.i = 0;
		v.b = value;
		return v;
	}
	static Value of_int(int64_t value) {
		Value v;
		v.kind = Kind::Int;
		v.i = value;
		return v;
	}
	static Value of_float(double value) {
		Value v;
		v.kind = Kind::Float;
		v.f = value;
		return v;
	}
	static Value of_ref(Kind kind, uint32_t ref) {
		Value v;
		v.kind = kind;
		v.i = 0;
		v.ref = ref;
		return v;
	}
	static Value str(uint32_t atom) { return of_ref(Kind::String, atom); }
	static Value of_vector2i(int32_t x, int32_t y) {
		Value v;
		v.kind = Kind::Vector2i;
		v.i = static_cast<int64_t>(static_cast<uint64_t>(static_cast<uint32_t>(x)) | (static_cast<uint64_t>(static_cast<uint32_t>(y)) << 32));
		return v;
	}
	static Value of_vector3i(int32_t x, int32_t y, int32_t z) {
		Value v = of_vector2i(x, y);
		v.kind = Kind::Vector3i;
		v.z = z;
		return v;
	}
	int32_t vx() const { return static_cast<int32_t>(static_cast<uint32_t>(static_cast<uint64_t>(i))); }
	int32_t vy() const { return static_cast<int32_t>(static_cast<uint32_t>(static_cast<uint64_t>(i) >> 32)); }
	int32_t vz() const { return z; }

	bool is_string_like() const { return kind == Kind::String || kind == Kind::StringName; }
	bool is_container() const { return kind == Kind::Array || kind == Kind::Dict; }
	bool is_packed() const { return kind == Kind::PackedByte || kind == Kind::PackedInt32 || kind == Kind::PackedString; }
};

// The fixed atoms of the subsystems' key lists: key::hex is the atom of "hex".
// A text is in one list only.
namespace key {
enum : uint32_t {
#define AURELION_KEY(name, text) name,
#include "aurelion_rules/battle_keys.inc"
#include "aurelion_rules/day_keys.inc"
#include "aurelion_rules/ai_keys.inc"
#undef AURELION_KEY
	known_count,
};
} // namespace key

// Where GDScript would stop with a runtime error (a bad conversion, an index
// out of range): the port throws it and the caller reports it.
class ScriptError : public std::runtime_error {
public:
	using std::runtime_error::runtime_error;
};

// A path a subsystem's port leaves to GDScript on purpose (Phase 5 ports what
// AI matches run): the native call writes nothing back and its switch runs the
// GDScript body instead. Thrown before any host side effect of the call (a
// RandomNumberGenerator's state). A value a port cannot handle is a
// ScriptError instead, reported as an error.
class NotPorted : public std::runtime_error {
public:
	using std::runtime_error::runtime_error;
};

// A typed Array's or Dictionary's element type, as the adapter registered it.
// 0 means untyped. The State checks writes against the type's Variant::Type,
// which the adapter registers with set_type_builtin.
using TypeRef = uint32_t;

// Godot's Variant::Type numbers of the types the State models.
namespace variant_type {
enum : uint8_t {
	NIL = 0,
	BOOL = 1,
	INT = 2,
	FLOAT = 3,
	STRING = 4,
	VECTOR2I = 6,
	VECTOR3I = 10,
	STRING_NAME = 21,
	OBJECT = 24,
	DICTIONARY = 27,
	ARRAY = 28,
	PACKED_BYTE_ARRAY = 29,
	PACKED_INT32_ARRAY = 30,
	PACKED_STRING_ARRAY = 34,
};
} // namespace variant_type

// The content tables the port reads (ContentService.get_unit and the like).
enum class ContentTable : uint8_t {
	Unit,
	Hero,
	Faction,
	Spell,
	Artifact,
	ResourceSite,
	Building,
	Town,
	MapObject,
	Encounter,
	ArmyGroup,
	// get_scenario_readonly: the authored row, else the generated draft.
	Scenario,
	Resource,
	// get_map_object_for_resource_site: the site's object with the largest
	// footprint.
	MapObjectForResourceSite,
	// get_biome_for_terrain, by the terrain id as given.
	BiomeForTerrain,
	// get_terrain_layers_for_scenario: a new deep copy on every call.
	TerrainLayersForScenario,
};

bool same_key(const Value &a, const Value &b);

// A list of Values that keeps up to kInline of them in place: most battle
// containers are small (a cell's q and r, a cube's x, y and z), so they cost no
// allocation.
class ValueList {
public:
	static constexpr uint32_t kInline = 4;
	// The first heap buffer: a list past kInline (a side's stacks, a map of
	// cells) grows once, not 8, 16, 32.
	static constexpr uint32_t kFirstHeap = 16;

	ValueList() = default;
	ValueList(const ValueList &other) { assign(other.begin(), other.end()); }
	ValueList(ValueList &&other) noexcept { take(other); }
	ValueList(const std::vector<Value> &values) { assign(values.data(), values.data() + values.size()); }
	ValueList &operator=(const ValueList &other) {
		if (this != &other) {
			assign(other.begin(), other.end());
		}
		return *this;
	}
	ValueList &operator=(ValueList &&other) noexcept {
		if (this != &other) {
			release();
			take(other);
		}
		return *this;
	}
	ValueList &operator=(const std::vector<Value> &values) {
		assign(values.data(), values.data() + values.size());
		return *this;
	}
	~ValueList() { release(); }

	size_t size() const { return size_; }
	bool empty() const { return size_ == 0; }
	const Value *begin() const { return data_; }
	const Value *end() const { return data_ + size_; }
	Value *begin() { return data_; }
	Value *end() { return data_ + size_; }
	const Value *data() const { return data_; }
	const Value &operator[](size_t index) const { return data_[index]; }
	Value &operator[](size_t index) { return data_[index]; }
	const Value &back() const { return data_[size_ - 1]; }

	void push_back(const Value &value) {
		if (size_ == capacity_) {
			// value may be an item of this list: copy it before grow() frees them.
			const Value copy = value;
			grow(static_cast<size_t>(size_) + 1);
			data_[size_++] = copy;
			return;
		}
		data_[size_++] = value;
	}
	void reserve(size_t count) {
		if (count > capacity_) {
			grow(count);
		}
	}
	void resize(size_t count) {
		reserve(count);
		for (size_t index = size_; index < count; ++index) {
			data_[index] = Value();
		}
		size_ = static_cast<uint32_t>(count);
	}
	void clear() { size_ = 0; }
	void erase_at(size_t index) {
		for (size_t next = index + 1; next < size_; ++next) {
			data_[next - 1] = data_[next];
		}
		--size_;
	}
	void assign(const Value *first, const Value *last) {
		const size_t count = static_cast<size_t>(last - first);
		if (count > capacity_) {
			// first may point into this list: copy before freeing.
			Value *grown = new Value[count];
			for (size_t index = 0; index < count; ++index) {
				grown[index] = first[index];
			}
			release();
			data_ = grown;
			capacity_ = static_cast<uint32_t>(count);
		} else {
			for (size_t index = 0; index < count; ++index) {
				data_[index] = first[index];
			}
		}
		size_ = static_cast<uint32_t>(count);
	}

private:
	void grow(size_t count) {
		size_t capacity = static_cast<size_t>(capacity_) * 2;
		capacity = capacity < kFirstHeap ? kFirstHeap : capacity;
		capacity = count > capacity ? count : capacity;
		Value *grown = new Value[capacity];
		for (size_t index = 0; index < size_; ++index) {
			grown[index] = data_[index];
		}
		release();
		data_ = grown;
		capacity_ = static_cast<uint32_t>(capacity);
	}
	void release() {
		if (data_ != inline_) {
			delete[] data_;
			data_ = inline_;
			capacity_ = kInline;
		}
	}
	void take(ValueList &other) {
		if (other.data_ == other.inline_) {
			for (size_t index = 0; index < other.size_; ++index) {
				inline_[index] = other.inline_[index];
			}
			data_ = inline_;
			capacity_ = kInline;
		} else {
			data_ = other.data_;
			capacity_ = other.capacity_;
			other.data_ = other.inline_;
			other.capacity_ = kInline;
		}
		size_ = other.size_;
		other.size_ = 0;
	}

	Value *data_ = inline_;
	uint32_t size_ = 0;
	uint32_t capacity_ = kInline;
	Value inline_[kInline];
};

// A Dictionary's keys in insertion order. A lookup of a string key scans them
// until, above kIndexAbove keys, the scans have read kScansPerKey times as many
// keys as there are: from then on it goes through a table of slots by atom (a
// battle stack has 40 keys and is read in every loop). A Dictionary read a few
// times never pays for the table, which costs about as much as eight scans to
// build. The table follows push_back and is dropped by any other change, and
// keeps its buffer for the next one. The keys are read-only in place, so
// nothing can change one behind the table.
class KeyList {
public:
	static constexpr size_t kIndexAbove = 8;
	static constexpr size_t kScansPerKey = 8;

	KeyList() = default;
	KeyList(const KeyList &other) :
			keys_(other.keys_) {}
	KeyList(KeyList &&other) noexcept :
			keys_(std::move(other.keys_)) { other.drop_index(); }
	KeyList &operator=(const KeyList &other) {
		if (this != &other) {
			keys_ = other.keys_;
			drop_index();
		}
		return *this;
	}
	KeyList &operator=(KeyList &&other) noexcept {
		if (this != &other) {
			keys_ = std::move(other.keys_);
			drop_index();
			other.drop_index();
		}
		return *this;
	}
	KeyList &operator=(const ValueList &keys) {
		keys_ = keys;
		drop_index();
		return *this;
	}
	KeyList &operator=(ValueList &&keys) {
		keys_ = std::move(keys);
		drop_index();
		return *this;
	}
	KeyList &operator=(const std::vector<Value> &keys) {
		keys_ = keys;
		drop_index();
		return *this;
	}

	size_t size() const { return keys_.size(); }
	bool empty() const { return keys_.empty(); }
	const Value *begin() const { return keys_.begin(); }
	const Value *end() const { return keys_.end(); }
	const Value *data() const { return keys_.data(); }
	const Value &operator[](size_t index) const { return keys_[index]; }
	const Value &back() const { return keys_.back(); }
	const ValueList &list() const { return keys_; }

	void push_back(const Value &key) {
		// key may be one of these keys: read it before the push can free them.
		const Value copy = key;
		keys_.push_back(copy);
		if (indexed_) {
			if (keys_.size() * 2 > table_.size() || keys_.size() >= kIndexBelow) {
				drop_index();
			} else if (copy.is_string_like()) {
				insert(copy.ref, keys_.size() - 1);
			}
		}
	}
	void reserve(size_t count) { keys_.reserve(count); }
	void erase_at(size_t index) {
		keys_.erase_at(index);
		drop_index();
	}
	void clear() {
		keys_.clear();
		drop_index();
	}

	// The first slot whose key is the same key (same_key), or -1.
	int64_t find(const Value &key) const {
		if (key.is_string_like()) {
			if (indexed_) {
				const size_t mask = table_.size() - 1;
				for (size_t probe = hash(key.ref) & mask;; probe = (probe + 1) & mask) {
					const uint16_t entry = table_[probe];
					if (entry == 0) {
						return -1;
					}
					if (keys_[entry - 1u].ref == key.ref) {
						return static_cast<int64_t>(entry - 1u);
					}
				}
			}
			// same_key of two string keys: the same atom.
			const size_t count = keys_.size();
			for (size_t index = 0; index < count; ++index) {
				if (keys_[index].is_string_like() && keys_[index].ref == key.ref) {
					scanned(index + 1);
					return static_cast<int64_t>(index);
				}
			}
			scanned(count);
			return -1;
		}
		for (size_t index = 0; index < keys_.size(); ++index) {
			if (same_key(keys_[index], key)) {
				return static_cast<int64_t>(index);
			}
		}
		return -1;
	}

private:
	// A table entry is its key's slot + 1, 0 when empty; so at most this many keys.
	static constexpr size_t kIndexBelow = 0xFFFF;

	static size_t hash(uint32_t atom) { return static_cast<size_t>((static_cast<uint64_t>(atom) * 0x9E3779B97F4A7C15ULL) >> 32); }

	void drop_index() const {
		indexed_ = false;
		scanned_ = 0;
	}
	void scanned(size_t keys) const {
		if (keys_.size() > kIndexAbove && keys_.size() < kIndexBelow) {
			scanned_ += keys;
			if (scanned_ >= kScansPerKey * keys_.size()) {
				build_index();
			}
		}
	}
	// The first string key of each atom keeps its slot, as the linear scan finds it.
	void insert(uint32_t atom, size_t slot) const {
		const size_t mask = table_.size() - 1;
		for (size_t probe = hash(atom) & mask;; probe = (probe + 1) & mask) {
			const uint16_t entry = table_[probe];
			if (entry == 0) {
				table_[probe] = static_cast<uint16_t>(slot + 1);
				return;
			}
			if (keys_[entry - 1u].ref == atom) {
				return;
			}
		}
	}
	// Half full at most.
	void build_index() const {
		size_t capacity = 32;
		while (capacity < keys_.size() * 2) {
			capacity *= 2;
		}
		table_.assign(capacity, 0);
		for (size_t index = 0; index < keys_.size(); ++index) {
			if (keys_[index].is_string_like()) {
				insert(keys_[index].ref, index);
			}
		}
		indexed_ = true;
	}

	ValueList keys_;
	mutable std::vector<uint16_t> table_;
	mutable size_t scanned_ = 0;
	mutable bool indexed_ = false;
};

struct ArrayNode {
	ValueList items;
	TypeRef element_type = 0;
	bool read_only = false;
	bool backed = false;
	// Written since it was made or loaded: set(), erase(), append(), set_at().
	bool dirty = false;
	// The memo's marks (State::memo_find): kWatched, kFrozen.
	uint8_t guard = 0;

	// As new, keeping the buffer.
	void reset() {
		items.clear();
		element_type = 0;
		read_only = false;
		backed = false;
		dirty = false;
		guard = 0;
	}
};

struct DictNode {
	// Insertion order, as Dictionary.keys() returns it.
	KeyList keys;
	ValueList values;
	TypeRef key_type = 0;
	TypeRef value_type = 0;
	bool read_only = false;
	bool backed = false;
	bool dirty = false;
	uint8_t guard = 0;

	// As new, keeping the buffers.
	void reset() {
		keys.clear();
		values.clear();
		key_type = 0;
		value_type = 0;
		read_only = false;
		backed = false;
		dirty = false;
		guard = 0;
	}
};

// A packed array: its kind says which of the element lists it uses. A loaded
// one is backed until something reads it, which copies its source's elements.
struct PackedNode {
	Kind kind = Kind::PackedInt32;
	std::vector<uint8_t> bytes;
	std::vector<int32_t> ints;
	// PackedStringArray: the strings' atoms.
	std::vector<uint32_t> atoms;
	bool backed = false;
	// Written since it was made or loaded.
	bool dirty = false;
	uint8_t guard = 0;

	void reset() {
		kind = Kind::PackedInt32;
		bytes.clear();
		ints.clear();
		atoms.clear();
		backed = false;
		dirty = false;
		guard = 0;
	}
	size_t size() const {
		switch (kind) {
			case Kind::PackedByte:
				return bytes.size();
			case Kind::PackedString:
				return atoms.size();
			default:
				return ints.size();
		}
	}
};

// Nodes in blocks of kBlock: making one rarely allocates, and references stay
// valid while nodes are added. (std::deque holds one node per block on MSVC.)
// clear() keeps the blocks, and the nodes their buffers, for the next nodes: a
// node used before is reset when it is made again.
template <typename Node>
class NodePool {
public:
	static constexpr size_t kBlockBits = 8;
	static constexpr size_t kBlock = size_t(1) << kBlockBits;

	size_t size() const { return size_; }
	Node &operator[](size_t index) const { return blocks_[index >> kBlockBits][index & (kBlock - 1)]; }
	void emplace_back() {
		if (size_ < used_) {
			(*this)[size_].reset();
		} else {
			if (used_ == blocks_.size() * kBlock) {
				blocks_.push_back(std::make_unique<Node[]>(kBlock));
			}
			++used_;
		}
		++size_;
	}
	void clear() { size_ = 0; }

private:
	std::vector<std::unique_ptr<Node[]>> blocks_;
	size_t size_ = 0;
	// Nodes made at least once since the blocks were allocated.
	size_t used_ = 0;
};

class State;

// The contents of backed nodes (the Godot adapter's containers), and what else
// the port asks of its host: objects, content and error output. A host without
// objects or content (the defaults) makes those a ScriptError.
class Backing {
public:
	virtual ~Backing() = default;
	// Fill the node from its container; the State clears the backed flag.
	virtual void fill_array(State &state, uint32_t node) = 0;
	virtual void fill_dict(State &state, uint32_t node) = 0;
	virtual int64_t array_size(uint32_t node) = 0;
	virtual Value array_at(State &state, uint32_t node, int64_t index) = 0;
	virtual int64_t dict_size(uint32_t node) = 0;
	virtual bool dict_lookup(State &state, uint32_t node, const Value &key, Value &out) = 0;
	// Fill a backed packed node's elements; the State clears the flag.
	virtual void fill_packed(State &state, uint32_t node);

	// object.property of an opaque value (the session's battle, day, ...).
	virtual Value object_get(State &state, uint32_t slot, uint32_t property);
	// A RandomNumberGenerator: its seed and state, false for another object.
	virtual bool rng_get(uint32_t slot, uint64_t &seed, uint64_t &state);
	virtual void rng_set_state(uint32_t slot, uint64_t state);
	// RandomNumberGenerator.new() with seed, then state, set: its opaque slot.
	virtual uint32_t rng_new(uint64_t seed, uint64_t state);
	// The content row with this id, the same node on every call (Nil when there
	// is none; terrain layers are a new node each time), and
	// ContentService.load_json(path).
	virtual Value content_row(State &state, ContentTable table, uint32_t id);
	virtual Value content_file(State &state, uint32_t path);
	// ContentService.get_content_revision(): it moves on each content reload.
	virtual int64_t content_revision(State &state);
	// A GDScript static var, by its script's res:// path and its name: its
	// value, the same node on every read of the call, and an assignment, which
	// the host applies with the call's write-back (so a call that writes
	// nothing back changes no static var).
	virtual Value static_get(State &state, uint32_t script, uint32_t name);
	virtual void static_set(State &state, uint32_t script, uint32_t name, const Value &value);
	// Godot's ERR_PRINT, for the container methods that fail without stopping
	// the script (append to a read-only Array), and a script's push_warning.
	// The defaults write to stderr.
	virtual void print_error(const std::string &text);
	virtual void print_warning(const std::string &text);
	// GDScript's pow(), exp() and log(): the engine's own, because the C
	// runtime that answers them differs between builds (the official Windows
	// build is MinGW's, this library's MSVC's) and may round differently in
	// the last bit. The defaults are this library's C runtime.
	virtual double math_pow(double base, double exponent);
	virtual double math_exp(double x);
	virtual double math_log(double x);
};

class State {
public:
	State();
	State(const State &) = delete;
	State &operator=(const State &) = delete;

	// Drops everything; the known keys keep their atoms.
	void clear();
	// Drops the nodes and the root, keeps the atoms.
	void clear_nodes();

	uint32_t intern(std::string_view text);
	// The atom of a text already interned, or false.
	bool find_atom(std::string_view text, uint32_t &atom) const;
	const std::string &text(uint32_t atom) const { return atoms_[atom]; }
	size_t atom_count() const { return atoms_.size(); }
	Value string(std::string_view text) { return Value::str(intern(text)); }

	uint32_t new_array();
	uint32_t new_dict();
	size_t array_count() const { return arrays_.size(); }
	size_t dict_count() const { return dicts_.size(); }

	// The whole node, to read; a backed node is filled first. Writes go through
	// set(), erase(), append() and set_at(), which honour read-only and typed
	// containers and mark the node dirty for the adapter's write-back.
	const ArrayNode &array(uint32_t node) const;
	const DictNode &dict(uint32_t node) const;
	// The node as it is, backed or not, to build or load (for the adapter and
	// for new nodes): writes here are not checked and do not mark it dirty.
	ArrayNode &array_node(uint32_t node) const { return arrays_[node]; }
	DictNode &dict_node(uint32_t node) const { return dicts_[node]; }

	// Packed arrays (PackedNode): PackedByteArray, PackedInt32Array and
	// PackedStringArray, a new one empty. Their operations are gd's packed_*.
	uint32_t new_packed(Kind kind);
	size_t packed_count() const { return packeds_.size(); }
	// The whole node, to read; a backed node is filled first.
	const PackedNode &packed(uint32_t node) const;
	// The whole node, to write: filled first and marked dirty.
	PackedNode &packed_write(uint32_t node);
	// The node as it is, to build or load: not filled, not marked dirty.
	PackedNode &packed_node(uint32_t node) const { return packeds_[node]; }

	void set_backing(Backing *backing) { backing_ = backing; }
	Backing *backing() const { return backing_; }
	// The host's services (Backing): a ScriptError when there is no host.
	Backing &host() const;

	// The Variant::Type of a registered TypeRef (variant_type::NIL if unknown).
	void set_type_builtin(TypeRef type, uint8_t builtin);
	uint8_t type_builtin(TypeRef type) const { return type < type_builtins_.size() ? type_builtins_[type] : variant_type::NIL; }

	// Dictionary semantics. A String and a StringName with the same text are one
	// key, as in Godot's Dictionary; ints match ints and floats floats.
	bool lookup(uint32_t dict_node, const Value &key, Value &out) const;
	bool has(uint32_t dict_node, const Value &key) const;
	Value get(uint32_t dict_node, const Value &key, const Value &fallback) const;
	int64_t dict_size(uint32_t dict_node) const;
	// d[key] = value: an existing key keeps its place, a new one goes last. A
	// read-only Dictionary, or a key or value its types refuse, is a ScriptError
	// (GDScript's failed keyed set); a value the type converts (1 into float) is
	// stored converted.
	void set(uint32_t dict_node, const Value &key, const Value &value);
	// d.erase(key): on a read-only Dictionary, or with a key its type refuses,
	// Godot prints an error and erases nothing.
	bool erase(uint32_t dict_node, const Value &key);

	// Array semantics. at() takes GDScript's negative indices; out of range is a
	// ScriptError.
	int64_t array_size(uint32_t array_node) const;
	Value at(uint32_t array_node, int64_t index) const;
	// a.append(value): on a read-only Array, or with a value its type refuses,
	// Godot prints an error and appends nothing.
	void append(uint32_t array_node, const Value &value);
	// a[index] = value, negative indices from the end: out of range, read-only
	// or a refused value is a ScriptError.
	void set_at(uint32_t array_node, int64_t index, const Value &value);
	// a.insert(position, value) (push_front is position 0), a.remove_at(position),
	// a.pop_back() and a.pop_front() (front): negative positions from the end.
	// Read-only, a refused value or a position out of range prints an error and
	// leaves the Array as it was; pop of an empty Array is Nil.
	void insert_at(uint32_t array_node, int64_t position, const Value &value);
	void remove_at(uint32_t array_node, int64_t position);
	Value pop_at(uint32_t array_node, bool front);

	// Error and warning output through the host (stderr without one).
	void print_error(const std::string &text) const;
	void print_warning(const std::string &text) const;

	// Godot's ContainerTypeValidate::validate against a container's element
	// type: true, with value converted where Variant::can_convert_strict allows.
	bool validate_type(TypeRef type, Value &value) const;

	// The atom of text(prefix) + text(atom), kept per State: the same atom as
	// interning the joined text, without building it again.
	uint32_t joined_atom(uint32_t prefix, uint32_t atom);

	// The atom of "q,r" ("%d,%d" % [q, r], BattleRules._hex_key_from_coords).
	// The board's cells have fixed atoms, made with the known keys, so they need
	// no formatting or hashing; any other pair is interned.
	uint32_t pair_atom(int64_t q, int64_t r);

	// The memo: native answers kept by what they were asked (slice 04c, the
	// board reads), the same node handed out on every hit, with no hashing of
	// the state and no copies. An answer stays while nothing it read changes:
	// memo_find watches the roots the answer is read from and everything they
	// hold; a write into a watched node counts (watched_writes) and drops the
	// whole memo, and a container stored into one is watched too. The answer is
	// frozen when kept: a write into it is a ScriptError, since every later hit
	// hands out the same node. An answer whose reading wrote into a watched node
	// is not kept.
	struct MemoKey {
		uint64_t a = 0;
		uint64_t b = 0;
		uint64_t c = 0;
		bool operator==(const MemoKey &other) const { return a == other.a && b == other.b && c == other.c; }
	};
	static constexpr uint8_t kWatched = 1;
	static constexpr uint8_t kFrozen = 2;
	// Watches the roots, then looks the key up; since goes to memo_keep.
	bool memo_find(const MemoKey &key, std::initializer_list<Value> roots, Value &answer, uint64_t &since);
	void memo_keep(const MemoKey &key, const Value &answer, uint64_t since);
	// A node the host loads from its container, watched from the start, so that
	// what the host fills into it later is watched as well.
	void watch_loaded(const Value &value);
	uint64_t watched_writes() const { return watched_writes_; }
	// a.sort_custom()'s new order of an Array's own items, as a write.
	void replace_items(uint32_t array_node, ValueList items);
	// The cell id (q * rows + r) whose "q,r" key is this atom, or -1: the
	// board's own keys only, so "01,2" or "3,-1" are not cells.
	int64_t board_cell_of_atom(uint32_t atom) const {
		return atom >= kBoardAtoms && atom < kBoardAtoms + kBoardCells ? static_cast<int64_t>(atom - kBoardAtoms) : -1;
	}

	Value root;

private:
	// The board's cell keys follow the known keys, in cell id order.
	static constexpr uint32_t kBoardCells = static_cast<uint32_t>(battle_hex::kCellCount);
	static constexpr uint32_t kBoardAtoms = key::known_count;

	// The backed paths of the inline operations below.
	void fill_array(uint32_t node) const;
	void fill_dict(uint32_t node) const;
	void fill_packed(uint32_t node) const;
	bool backed_lookup(uint32_t dict_node, const Value &key, Value &out) const;
	[[noreturn]] static void out_of_bounds(int64_t index);
	// The typed or read-only paths of set() and append().
	void checked_set(DictNode &node, Value key, Value value);
	void checked_append(ArrayNode &node, Value value);
	// The host, or one that only prints errors.
	Backing &host_or_default() const;
	// Before a write into a marked node: a frozen one stops it with a
	// ScriptError; a watched one counts, and the containers it stores, the
	// key and the value, are watched.
	void guarded_write(uint8_t guard, const Value &key = Value(), const Value &value = Value());
	void watch(const Value &value);
	void freeze(const Value &value);

	struct MemoKeyHash {
		size_t operator()(const MemoKey &key) const {
			uint64_t h = key.a * 0x9E3779B97F4A7C15ull;
			h ^= key.b + 0x9E3779B97F4A7C15ull + (h << 6) + (h >> 2);
			h ^= key.c + 0x9E3779B97F4A7C15ull + (h << 6) + (h >> 2);
			return static_cast<size_t>(h);
		}
	};
	std::unordered_map<MemoKey, Value, MemoKeyHash> memo_;
	// watched_writes_ when memo_ was last current.
	uint64_t memo_epoch_ = 0;
	uint64_t watched_writes_ = 0;
	std::vector<Value> marking_;

	// A deque, so the views atom_ids_ holds stay valid.
	std::deque<std::string> atoms_;
	std::unordered_map<std::string_view, uint32_t> atom_ids_;
	// joined_atom's atoms: (prefix << 32 | atom) -> atom of the joined text.
	std::unordered_map<uint64_t, uint32_t> joined_;
	NodePool<ArrayNode> arrays_;
	NodePool<DictNode> dicts_;
	NodePool<PackedNode> packeds_;
	Backing *backing_ = nullptr;
	std::vector<uint8_t> type_builtins_;
};

// The operations the port runs most, inline: the backed paths are out of line.

inline uint32_t State::new_array() {
	arrays_.emplace_back();
	return static_cast<uint32_t>(arrays_.size() - 1);
}

inline uint32_t State::new_dict() {
	dicts_.emplace_back();
	return static_cast<uint32_t>(dicts_.size() - 1);
}

inline const ArrayNode &State::array(uint32_t node) const {
	const ArrayNode &found = arrays_[node];
	if (found.backed) {
		fill_array(node);
	}
	return found;
}

inline uint32_t State::new_packed(Kind kind) {
	packeds_.emplace_back();
	const uint32_t node = static_cast<uint32_t>(packeds_.size() - 1);
	packeds_[node].kind = kind;
	return node;
}

inline const PackedNode &State::packed(uint32_t node) const {
	const PackedNode &found = packeds_[node];
	if (found.backed) {
		fill_packed(node);
	}
	return found;
}

inline PackedNode &State::packed_write(uint32_t node) {
	PackedNode &found = packeds_[node];
	if (found.backed) {
		fill_packed(node);
	}
	if (found.guard != 0) {
		guarded_write(found.guard);
	}
	found.dirty = true;
	return found;
}

inline const DictNode &State::dict(uint32_t node) const {
	const DictNode &found = dicts_[node];
	if (found.backed) {
		fill_dict(node);
	}
	return found;
}

inline bool State::lookup(uint32_t dict_node, const Value &key, Value &out) const {
	const DictNode &node = dicts_[dict_node];
	if (node.backed) {
		return backed_lookup(dict_node, key, out);
	}
	const int64_t index = node.keys.find(key);
	if (index < 0) {
		return false;
	}
	out = node.values[static_cast<size_t>(index)];
	return true;
}

inline bool State::has(uint32_t dict_node, const Value &key) const {
	Value ignored;
	return lookup(dict_node, key, ignored);
}

inline Value State::get(uint32_t dict_node, const Value &key, const Value &fallback) const {
	Value found;
	return lookup(dict_node, key, found) ? found : fallback;
}

inline int64_t State::dict_size(uint32_t dict_node) const {
	const DictNode &node = dicts_[dict_node];
	if (node.backed) {
		return backing_->dict_size(dict_node);
	}
	return static_cast<int64_t>(node.keys.size());
}

inline void State::set(uint32_t dict_node, const Value &key, const Value &value) {
	// key or value may be an entry of this node: copy both before a push frees it.
	const Value key_copy = key;
	const Value value_copy = value;
	dict(dict_node);
	DictNode &node = dicts_[dict_node];
	if (node.guard != 0) {
		guarded_write(node.guard, key_copy, value_copy);
	}
	if (node.read_only || node.key_type != 0 || node.value_type != 0) {
		checked_set(node, key_copy, value_copy);
		return;
	}
	const int64_t index = node.keys.find(key_copy);
	if (index >= 0) {
		node.values[static_cast<size_t>(index)] = value_copy;
	} else {
		node.keys.push_back(key_copy);
		node.values.push_back(value_copy);
	}
	node.dirty = true;
}

inline int64_t State::array_size(uint32_t array_node) const {
	const ArrayNode &node = arrays_[array_node];
	if (node.backed) {
		return backing_->array_size(array_node);
	}
	return static_cast<int64_t>(node.items.size());
}

inline Value State::at(uint32_t array_node, int64_t index) const {
	const int64_t size = array_size(array_node);
	const int64_t position = index < 0 ? index + size : index;
	if (position < 0 || position >= size) {
		out_of_bounds(index);
	}
	const ArrayNode &node = arrays_[array_node];
	if (node.backed) {
		return backing_->array_at(const_cast<State &>(*this), array_node, position);
	}
	return node.items[static_cast<size_t>(position)];
}

inline void State::append(uint32_t array_node, const Value &value) {
	array(array_node);
	ArrayNode &node = arrays_[array_node];
	if (node.guard != 0) {
		guarded_write(node.guard, Value(), value);
	}
	if (node.read_only || node.element_type != 0) {
		checked_append(node, value);
		return;
	}
	node.items.push_back(value);
	node.dirty = true;
}

} // namespace aurelion::rules::state
