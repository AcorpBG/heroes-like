#include "aurelion_rules/battle_state.hpp"

#include "aurelion_rules/compat/godot_math.hpp"
#include "aurelion_rules/compat/godot_string.hpp"

#include <cstdio>

namespace aurelion::rules::state {

namespace {

constexpr std::string_view kKnownKeys[] = {
#define AURELION_KEY(name, text) text,
#include "aurelion_rules/battle_keys.inc"
#include "aurelion_rules/day_keys.inc"
#include "aurelion_rules/ai_keys.inc"
#undef AURELION_KEY
};

int64_t find_index(const DictNode &node, const Value &key) {
	return node.keys.find(key);
}

std::string pair_text(int64_t q, int64_t r) {
	return compat::itos(q) + "," + compat::itos(r);
}

// The Variant::Type of a value; 255 for an opaque one, whose type the State
// does not know.
uint8_t builtin_of(const Value &value) {
	switch (value.kind) {
		case Kind::Nil:
			return variant_type::NIL;
		case Kind::Bool:
			return variant_type::BOOL;
		case Kind::Int:
			return variant_type::INT;
		case Kind::Float:
			return variant_type::FLOAT;
		case Kind::String:
			return variant_type::STRING;
		case Kind::StringName:
			return variant_type::STRING_NAME;
		case Kind::Vector2i:
			return variant_type::VECTOR2I;
		case Kind::Array:
			return variant_type::ARRAY;
		case Kind::Dict:
			return variant_type::DICTIONARY;
		case Kind::Vector3i:
			return variant_type::VECTOR3I;
		case Kind::PackedByte:
			return variant_type::PACKED_BYTE_ARRAY;
		case Kind::PackedInt32:
			return variant_type::PACKED_INT32_ARRAY;
		case Kind::PackedString:
			return variant_type::PACKED_STRING_ARRAY;
		case Kind::Opaque:
			break;
	}
	return 255;
}

const char *builtin_name(uint8_t builtin) {
	switch (builtin) {
		case variant_type::NIL:
			return "Nil";
		case variant_type::BOOL:
			return "bool";
		case variant_type::INT:
			return "int";
		case variant_type::FLOAT:
			return "float";
		case variant_type::STRING:
			return "String";
		case variant_type::STRING_NAME:
			return "StringName";
		case variant_type::VECTOR2I:
			return "Vector2i";
		case variant_type::VECTOR3I:
			return "Vector3i";
		case variant_type::PACKED_BYTE_ARRAY:
			return "PackedByteArray";
		case variant_type::PACKED_INT32_ARRAY:
			return "PackedInt32Array";
		case variant_type::PACKED_STRING_ARRAY:
			return "PackedStringArray";
		case variant_type::OBJECT:
			return "Object";
		case variant_type::DICTIONARY:
			return "Dictionary";
		case variant_type::ARRAY:
			return "Array";
		default:
			return "Variant";
	}
}

[[noreturn]] void no_host(const char *what) {
	throw ScriptError(std::string(what) + " needs the Godot host, which this State does not have");
}

} // namespace

void Backing::fill_packed(State &, uint32_t) {
	no_host("A loaded packed array");
}

Value Backing::object_get(State &, uint32_t, uint32_t) {
	no_host("Reading an object's property");
}

bool Backing::rng_get(uint32_t, uint64_t &, uint64_t &) {
	no_host("A RandomNumberGenerator");
}

void Backing::rng_set_state(uint32_t, uint64_t) {
	no_host("A RandomNumberGenerator");
}

uint32_t Backing::rng_new(uint64_t, uint64_t) {
	no_host("RandomNumberGenerator.new()");
}

Value Backing::content_row(State &, ContentTable, uint32_t) {
	no_host("Content");
}

Value Backing::content_file(State &, uint32_t) {
	no_host("Content");
}

int64_t Backing::content_revision(State &) {
	no_host("Content");
}

Value Backing::static_get(State &, uint32_t, uint32_t) {
	no_host("A static var");
}

void Backing::static_set(State &, uint32_t, uint32_t, const Value &) {
	no_host("A static var");
}

void Backing::print_error(const std::string &text) {
	std::fprintf(stderr, "ERROR: %s\n", text.c_str());
}

void Backing::print_warning(const std::string &text) {
	std::fprintf(stderr, "WARNING: %s\n", text.c_str());
}

bool same_key(const Value &a, const Value &b) {
	if (a.is_string_like() && b.is_string_like()) {
		return a.ref == b.ref;
	}
	if (a.kind != b.kind) {
		return false;
	}
	switch (a.kind) {
		case Kind::Nil:
			return true;
		case Kind::Bool:
			return a.b == b.b;
		case Kind::Int:
		case Kind::Vector2i:
			return a.i == b.i;
		case Kind::Vector3i:
			return a.i == b.i && a.z == b.z;
		case Kind::Float:
			// Variant::hash_compare: == (so 0.0 and -0.0 match), with every NaN equal.
			return a.f == b.f || (a.f != a.f && b.f != b.f);
		default:
			// Container, packed and opaque keys compare by identity here; Godot
			// compares by content. The adapter rebuilds a Dictionary that has such
			// keys.
			return a.ref == b.ref;
	}
}

State::State() {
	clear();
}

void State::clear() {
	atoms_.clear();
	atom_ids_.clear();
	joined_.clear();
	for (std::string_view text : kKnownKeys) {
		const size_t next = atoms_.size();
		if (intern(text) != next) {
			throw std::logic_error("a known key is in two key lists: " + std::string(text));
		}
	}
	for (int64_t q = 0; q < battle_hex::kColumns; ++q) {
		for (int64_t r = 0; r < battle_hex::kRows; ++r) {
			if (intern(pair_text(q, r)) != kBoardAtoms + static_cast<uint32_t>(q * battle_hex::kRows + r)) {
				throw std::logic_error("a known key is also a board cell key");
			}
		}
	}
	clear_nodes();
}

void State::clear_nodes() {
	arrays_.clear();
	dicts_.clear();
	packeds_.clear();
	root = Value();
	memo_.clear();
	memo_epoch_ = watched_writes_;
}

bool State::memo_find(const MemoKey &key, std::initializer_list<Value> roots, Value &answer, uint64_t &since) {
	for (const Value &from : roots) {
		watch(from);
	}
	if (memo_epoch_ != watched_writes_) {
		memo_.clear();
		memo_epoch_ = watched_writes_;
	}
	since = watched_writes_;
	const auto found = memo_.find(key);
	if (found == memo_.end()) {
		return false;
	}
	answer = found->second;
	return true;
}

void State::memo_keep(const MemoKey &key, const Value &answer, uint64_t since) {
	// Its reading wrote into what it read: a new reading may differ.
	if (watched_writes_ != since) {
		return;
	}
	freeze(answer);
	memo_[key] = answer;
}

void State::watch_loaded(const Value &value) {
	switch (value.kind) {
		case Kind::Array:
			arrays_[value.ref].guard |= kWatched;
			break;
		case Kind::Dict:
			dicts_[value.ref].guard |= kWatched;
			break;
		case Kind::PackedByte:
		case Kind::PackedInt32:
		case Kind::PackedString:
			packeds_[value.ref].guard |= kWatched;
			break;
		default:
			break;
	}
}

void State::replace_items(uint32_t array_node, ValueList items) {
	ArrayNode &node = arrays_[array_node];
	if (node.guard != 0) {
		guarded_write(node.guard);
	}
	node.items = std::move(items);
	node.dirty = true;
}

void State::guarded_write(uint8_t guard, const Value &key, const Value &value) {
	if ((guard & kFrozen) != 0) {
		throw ScriptError("a write into an answer the native memo keeps: every later hit hands out the same node (State::memo_keep)");
	}
	++watched_writes_;
	watch(key);
	watch(value);
}

// Every container the value holds, down to the nodes already watched (what
// they hold is watched with them) and the backed ones (the host watches what
// it loads into them, watch_loaded).
void State::watch(const Value &value) {
	if (!value.is_container() && !value.is_packed()) {
		return;
	}
	marking_.clear();
	marking_.push_back(value);
	while (!marking_.empty()) {
		const Value next = marking_.back();
		marking_.pop_back();
		if (next.is_packed()) {
			packeds_[next.ref].guard |= kWatched;
		} else if (next.kind == Kind::Array) {
			ArrayNode &node = arrays_[next.ref];
			if ((node.guard & kWatched) != 0) {
				continue;
			}
			node.guard |= kWatched;
			if (node.backed) {
				continue;
			}
			for (const Value &item : node.items) {
				if (item.is_container() || item.is_packed()) {
					marking_.push_back(item);
				}
			}
		} else if (next.kind == Kind::Dict) {
			DictNode &node = dicts_[next.ref];
			if ((node.guard & kWatched) != 0) {
				continue;
			}
			node.guard |= kWatched;
			if (node.backed) {
				continue;
			}
			for (const Value &item : node.keys) {
				if (item.is_container() || item.is_packed()) {
					marking_.push_back(item);
				}
			}
			for (const Value &item : node.values) {
				if (item.is_container() || item.is_packed()) {
					marking_.push_back(item);
				}
			}
		}
	}
}

// The answer and every container it holds. A watched node in it is part of
// the state the answer was read from: freezing it would stop the game's own
// writes, so it is a logic error of the memo's caller.
void State::freeze(const Value &value) {
	if (!value.is_container() && !value.is_packed()) {
		return;
	}
	marking_.clear();
	marking_.push_back(value);
	while (!marking_.empty()) {
		const Value next = marking_.back();
		marking_.pop_back();
		uint8_t *guard = nullptr;
		const ValueList *first = nullptr;
		const ValueList *second = nullptr;
		if (next.is_packed()) {
			guard = &packeds_[next.ref].guard;
		} else if (next.kind == Kind::Array) {
			ArrayNode &node = arrays_[next.ref];
			guard = &node.guard;
			first = &node.items;
		} else {
			DictNode &node = dicts_[next.ref];
			guard = &node.guard;
			first = &node.keys.list();
			second = &node.values;
		}
		if ((*guard & kFrozen) != 0) {
			continue;
		}
		if ((*guard & kWatched) != 0) {
			throw std::logic_error("a memo answer holds a node of the state it was read from");
		}
		*guard |= kFrozen;
		for (const ValueList *items : { first, second }) {
			if (items == nullptr) {
				continue;
			}
			for (const Value &item : *items) {
				if (item.is_container() || item.is_packed()) {
					marking_.push_back(item);
				}
			}
		}
	}
}

uint32_t State::intern(std::string_view text) {
	auto found = atom_ids_.find(text);
	if (found != atom_ids_.end()) {
		return found->second;
	}
	const uint32_t atom = static_cast<uint32_t>(atoms_.size());
	atoms_.emplace_back(text);
	atom_ids_.emplace(std::string_view(atoms_.back()), atom);
	return atom;
}

bool State::find_atom(std::string_view text, uint32_t &atom) const {
	auto found = atom_ids_.find(text);
	if (found == atom_ids_.end()) {
		return false;
	}
	atom = found->second;
	return true;
}

uint32_t State::joined_atom(uint32_t prefix, uint32_t atom) {
	const uint64_t pair = (static_cast<uint64_t>(prefix) << 32) | atom;
	const auto found = joined_.find(pair);
	if (found != joined_.end()) {
		return found->second;
	}
	const uint32_t joined = intern(atoms_[prefix] + atoms_[atom]);
	joined_.emplace(pair, joined);
	return joined;
}

uint32_t State::pair_atom(int64_t q, int64_t r) {
	if (q >= 0 && q < battle_hex::kColumns && r >= 0 && r < battle_hex::kRows) {
		return kBoardAtoms + static_cast<uint32_t>(q * battle_hex::kRows + r);
	}
	return intern(pair_text(q, r));
}

void State::fill_array(uint32_t node) const {
	backing_->fill_array(const_cast<State &>(*this), node);
	arrays_[node].backed = false;
}

void State::fill_dict(uint32_t node) const {
	backing_->fill_dict(const_cast<State &>(*this), node);
	dicts_[node].backed = false;
}

void State::fill_packed(uint32_t node) const {
	host().fill_packed(const_cast<State &>(*this), node);
	packeds_[node].backed = false;
}

bool State::backed_lookup(uint32_t dict_node, const Value &key, Value &out) const {
	return backing_->dict_lookup(const_cast<State &>(*this), dict_node, key, out);
}

Backing &State::host() const {
	if (backing_ == nullptr) {
		no_host("This call");
	}
	return *backing_;
}

void State::set_type_builtin(TypeRef type, uint8_t builtin) {
	if (type >= type_builtins_.size()) {
		type_builtins_.resize(static_cast<size_t>(type) + 1, variant_type::NIL);
	}
	type_builtins_[type] = builtin;
}

bool State::validate_type(TypeRef type, Value &value) const {
	const uint8_t want = type == 0 ? variant_type::NIL : type_builtin(type);
	if (want == variant_type::NIL) {
		return true;
	}
	if (value.kind == Kind::Opaque) {
		// Its class is the adapter's to check.
		throw ScriptError(std::string("A typed container of ") + builtin_name(want) + " holding an object is not ported");
	}
	const uint8_t have = builtin_of(value);
	if (have == want) {
		return true;
	}
	if (have == variant_type::NIL) {
		return want == variant_type::OBJECT;
	}
	// Variant::can_convert_strict, then the constructor, for the modeled types.
	switch (want) {
		case variant_type::BOOL:
			if (value.kind == Kind::Int) {
				value = Value::of_bool(value.i != 0);
				return true;
			}
			if (value.kind == Kind::Float) {
				value = Value::of_bool(value.f != 0.0);
				return true;
			}
			return false;
		case variant_type::INT:
			if (value.kind == Kind::Bool) {
				value = Value::of_int(value.b ? 1 : 0);
				return true;
			}
			if (value.kind == Kind::Float) {
				value = Value::of_int(compat::float_to_int(value.f));
				return true;
			}
			return false;
		case variant_type::FLOAT:
			if (value.kind == Kind::Bool) {
				value = Value::of_float(value.b ? 1.0 : 0.0);
				return true;
			}
			if (value.kind == Kind::Int) {
				value = Value::of_float(static_cast<double>(value.i));
				return true;
			}
			return false;
		case variant_type::STRING:
			if (value.kind == Kind::StringName) {
				value = Value::str(value.ref);
				return true;
			}
			return false;
		case variant_type::STRING_NAME:
			if (value.kind == Kind::String) {
				value = Value::of_ref(Kind::StringName, value.ref);
				return true;
			}
			return false;
		default:
			return false;
	}
}

void State::checked_set(DictNode &node, Value key, Value value) {
	if (node.read_only) {
		throw ScriptError("Invalid assignment of a key on a base object of type 'Dictionary': it is in read-only state");
	}
	const uint8_t key_had = builtin_of(key);
	if (!validate_type(node.key_type, key)) {
		throw ScriptError(std::string("Invalid assignment: a key of type '") + builtin_name(key_had) + "' into a Dictionary keyed by '" + builtin_name(type_builtin(node.key_type)) + "'");
	}
	const uint8_t value_had = builtin_of(value);
	if (!validate_type(node.value_type, value)) {
		throw ScriptError(std::string("Invalid assignment: a value of type '") + builtin_name(value_had) + "' into a Dictionary of '" + builtin_name(type_builtin(node.value_type)) + "'");
	}
	const int64_t index = node.keys.find(key);
	if (index >= 0) {
		node.values[static_cast<size_t>(index)] = value;
	} else {
		node.keys.push_back(key);
		node.values.push_back(value);
	}
	node.dirty = true;
}

void State::checked_append(ArrayNode &node, Value value) {
	if (node.read_only) {
		host_or_default().print_error("Array is in read-only state.");
		return;
	}
	const uint8_t had = builtin_of(value);
	if (!validate_type(node.element_type, value)) {
		host_or_default().print_error(std::string("Attempted to push_back a variable of type '") + builtin_name(had) + "' into a TypedArray of type '" + builtin_name(type_builtin(node.element_type)) + "'.");
		return;
	}
	node.items.push_back(value);
	node.dirty = true;
}

void State::set_at(uint32_t array_node, int64_t index, const Value &value) {
	Value checked = value;
	array(array_node);
	ArrayNode &node = arrays_[array_node];
	const int64_t size = static_cast<int64_t>(node.items.size());
	const int64_t position = index < 0 ? index + size : index;
	if (position < 0 || position >= size) {
		throw ScriptError("Out of bounds set index '" + std::to_string(index) + "' (on base: 'Array')");
	}
	if (node.guard != 0) {
		guarded_write(node.guard, Value(), checked);
	}
	if (node.read_only) {
		throw ScriptError("Invalid assignment of an index on a base object of type 'Array': it is in read-only state");
	}
	const uint8_t had = builtin_of(checked);
	if (!validate_type(node.element_type, checked)) {
		throw ScriptError(std::string("Invalid assignment: a value of type '") + builtin_name(had) + "' into an Array of '" + builtin_name(type_builtin(node.element_type)) + "'");
	}
	node.items[static_cast<size_t>(position)] = checked;
	node.dirty = true;
}

void State::insert_at(uint32_t array_node, int64_t position, const Value &value) {
	Value checked = value;
	array(array_node);
	ArrayNode &node = arrays_[array_node];
	if (node.guard != 0) {
		guarded_write(node.guard, Value(), checked);
	}
	// Array::insert checks read-only, then the type, then the position.
	if (node.read_only) {
		print_error("Array is in read-only state.");
		return;
	}
	const uint8_t had = builtin_of(checked);
	if (!validate_type(node.element_type, checked)) {
		print_error(std::string("Attempted to insert a variable of type '") + builtin_name(had) + "' into a TypedArray of type '" + builtin_name(type_builtin(node.element_type)) + "'.");
		return;
	}
	const int64_t size = static_cast<int64_t>(node.items.size());
	const int64_t at = position < 0 ? position + size : position;
	if (at < 0 || at > size) {
		print_error("The calculated index " + std::to_string(at) + " is out of bounds (the array has " + std::to_string(size) + " elements). Leaving the array untouched.");
		return;
	}
	node.items.push_back(checked);
	for (int64_t index = size; index > at; --index) {
		node.items[static_cast<size_t>(index)] = node.items[static_cast<size_t>(index - 1)];
	}
	node.items[static_cast<size_t>(at)] = checked;
	node.dirty = true;
}

void State::remove_at(uint32_t array_node, int64_t position) {
	array(array_node);
	ArrayNode &node = arrays_[array_node];
	if (node.guard != 0) {
		guarded_write(node.guard);
	}
	if (node.read_only) {
		print_error("Array is in read-only state.");
		return;
	}
	const int64_t size = static_cast<int64_t>(node.items.size());
	const int64_t at = position < 0 ? position + size : position;
	if (at < 0 || at >= size) {
		print_error("The calculated index " + std::to_string(at) + " is out of bounds (the array has " + std::to_string(size) + " elements). Leaving the array untouched.");
		return;
	}
	node.items.erase_at(static_cast<size_t>(at));
	node.dirty = true;
}

Value State::pop_at(uint32_t array_node, bool front) {
	array(array_node);
	ArrayNode &node = arrays_[array_node];
	if (node.guard != 0) {
		guarded_write(node.guard);
	}
	if (node.read_only) {
		print_error("Array is in read-only state.");
		return Value();
	}
	if (node.items.empty()) {
		return Value();
	}
	const size_t at = front ? 0 : node.items.size() - 1;
	const Value popped = node.items[at];
	node.items.erase_at(at);
	node.dirty = true;
	return popped;
}

void State::print_error(const std::string &text) const {
	host_or_default().print_error(text);
}

void State::print_warning(const std::string &text) const {
	host_or_default().print_warning(text);
}

bool State::erase(uint32_t dict_node, const Value &key) {
	Value checked = key;
	dict(dict_node);
	DictNode &node = dicts_[dict_node];
	if (node.guard != 0) {
		guarded_write(node.guard);
	}
	// Dictionary::erase checks the key's type, then the read-only flag.
	const uint8_t had = builtin_of(checked);
	if (!validate_type(node.key_type, checked)) {
		host_or_default().print_error(std::string("Attempted to erase a variable of type '") + builtin_name(had) + "' into a TypedDictionary.Key of type '" + builtin_name(type_builtin(node.key_type)) + "'.");
		return false;
	}
	if (node.read_only) {
		host_or_default().print_error("Dictionary is in read-only state.");
		return false;
	}
	const int64_t index = find_index(node, checked);
	if (index < 0) {
		return false;
	}
	node.keys.erase_at(static_cast<size_t>(index));
	node.values.erase_at(static_cast<size_t>(index));
	node.dirty = true;
	return true;
}

Backing &State::host_or_default() const {
	static struct : Backing {
		void fill_array(State &, uint32_t) override {}
		void fill_dict(State &, uint32_t) override {}
		int64_t array_size(uint32_t) override { return 0; }
		Value array_at(State &, uint32_t, int64_t) override { return Value(); }
		int64_t dict_size(uint32_t) override { return 0; }
		bool dict_lookup(State &, uint32_t, const Value &, Value &) override { return false; }
	} fallback;
	return backing_ != nullptr ? *backing_ : fallback;
}

void State::out_of_bounds(int64_t index) {
	throw ScriptError("Out of bounds get index '" + std::to_string(index) + "' (on base: 'Array')");
}

} // namespace aurelion::rules::state
