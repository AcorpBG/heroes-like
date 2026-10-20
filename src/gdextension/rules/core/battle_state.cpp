#include "aurelion_rules/battle_state.hpp"

namespace aurelion::rules::state {

namespace {

constexpr std::string_view kKnownKeys[] = {
#define AURELION_KEY(name, text) text,
#include "aurelion_rules/battle_keys.inc"
#undef AURELION_KEY
};

int64_t find_index(const DictNode &node, const Value &key) {
	for (size_t index = 0; index < node.keys.size(); ++index) {
		if (same_key(node.keys[index], key)) {
			return static_cast<int64_t>(index);
		}
	}
	return -1;
}

} // namespace

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
		case Kind::Float:
			// Variant::hash_compare: == (so 0.0 and -0.0 match), with every NaN equal.
			return a.f == b.f || (a.f != a.f && b.f != b.f);
		default:
			// Container and opaque keys compare by identity here; Godot compares by
			// content. The adapter rebuilds a Dictionary that has such keys.
			return a.ref == b.ref;
	}
}

State::State() {
	clear();
}

void State::clear() {
	atoms_.clear();
	atom_ids_.clear();
	for (std::string_view text : kKnownKeys) {
		intern(text);
	}
	clear_nodes();
}

void State::clear_nodes() {
	arrays_.clear();
	dicts_.clear();
	root = Value();
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

uint32_t State::new_array() {
	arrays_.emplace_back();
	return static_cast<uint32_t>(arrays_.size() - 1);
}

uint32_t State::new_dict() {
	dicts_.emplace_back();
	return static_cast<uint32_t>(dicts_.size() - 1);
}

ArrayNode &State::array(uint32_t node) const {
	if (arrays_[node].backed) {
		backing_->fill_array(const_cast<State &>(*this), node);
		arrays_[node].backed = false;
	}
	return arrays_[node];
}

DictNode &State::dict(uint32_t node) const {
	if (dicts_[node].backed) {
		backing_->fill_dict(const_cast<State &>(*this), node);
		dicts_[node].backed = false;
	}
	return dicts_[node];
}

bool State::lookup(uint32_t dict_node, const Value &key, Value &out) const {
	const DictNode &node = dicts_[dict_node];
	if (node.backed) {
		return backing_->dict_lookup(const_cast<State &>(*this), dict_node, key, out);
	}
	const int64_t index = find_index(node, key);
	if (index < 0) {
		return false;
	}
	out = node.values[static_cast<size_t>(index)];
	return true;
}

bool State::has(uint32_t dict_node, const Value &key) const {
	Value ignored;
	return lookup(dict_node, key, ignored);
}

Value State::get(uint32_t dict_node, const Value &key, const Value &fallback) const {
	Value found;
	return lookup(dict_node, key, found) ? found : fallback;
}

int64_t State::dict_size(uint32_t dict_node) const {
	const DictNode &node = dicts_[dict_node];
	if (node.backed) {
		return backing_->dict_size(dict_node);
	}
	return static_cast<int64_t>(node.keys.size());
}

void State::set(uint32_t dict_node, const Value &key, const Value &value) {
	DictNode &node = dict(dict_node);
	const int64_t index = find_index(node, key);
	if (index >= 0) {
		node.values[static_cast<size_t>(index)] = value;
		node.dirty = true;
		return;
	}
	node.keys.push_back(key);
	node.values.push_back(value);
	node.dirty = true;
}

bool State::erase(uint32_t dict_node, const Value &key) {
	DictNode &node = dict(dict_node);
	const int64_t index = find_index(node, key);
	if (index < 0) {
		return false;
	}
	node.keys.erase(node.keys.begin() + static_cast<std::ptrdiff_t>(index));
	node.values.erase(node.values.begin() + static_cast<std::ptrdiff_t>(index));
	node.dirty = true;
	return true;
}

int64_t State::array_size(uint32_t array_node) const {
	const ArrayNode &node = arrays_[array_node];
	if (node.backed) {
		return backing_->array_size(array_node);
	}
	return static_cast<int64_t>(node.items.size());
}

Value State::at(uint32_t array_node, int64_t index) const {
	const int64_t size = array_size(array_node);
	const int64_t position = index < 0 ? index + size : index;
	if (position < 0 || position >= size) {
		throw ScriptError("Out of bounds get index '" + std::to_string(index) + "' (on base: 'Array')");
	}
	const ArrayNode &node = arrays_[array_node];
	if (node.backed) {
		return backing_->array_at(const_cast<State &>(*this), array_node, position);
	}
	return node.items[static_cast<size_t>(position)];
}

void State::append(uint32_t array_node, const Value &value) {
	ArrayNode &node = array(array_node);
	node.items.push_back(value);
	node.dirty = true;
}

} // namespace aurelion::rules::state
