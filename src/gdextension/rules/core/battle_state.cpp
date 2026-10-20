#include "aurelion_rules/battle_state.hpp"

namespace aurelion::rules::state {

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

void State::clear() {
	atoms_.clear();
	atom_ids_.clear();
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

bool State::lookup(std::string_view text, uint32_t &atom) const {
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

const Value *State::find(uint32_t dict_node, const Value &key) const {
	const DictNode &node = dicts_[dict_node];
	for (size_t index = 0; index < node.keys.size(); ++index) {
		if (same_key(node.keys[index], key)) {
			return &node.values[index];
		}
	}
	return nullptr;
}

Value *State::find(uint32_t dict_node, const Value &key) {
	DictNode &node = dicts_[dict_node];
	for (size_t index = 0; index < node.keys.size(); ++index) {
		if (same_key(node.keys[index], key)) {
			return &node.values[index];
		}
	}
	return nullptr;
}

Value State::get(uint32_t dict_node, const Value &key, const Value &fallback) const {
	const Value *found = find(dict_node, key);
	return found != nullptr ? *found : fallback;
}

void State::set(uint32_t dict_node, const Value &key, const Value &value) {
	Value *found = find(dict_node, key);
	if (found != nullptr) {
		*found = value;
		return;
	}
	DictNode &node = dicts_[dict_node];
	node.keys.push_back(key);
	node.values.push_back(value);
}

bool State::erase(uint32_t dict_node, const Value &key) {
	DictNode &node = dicts_[dict_node];
	for (size_t index = 0; index < node.keys.size(); ++index) {
		if (same_key(node.keys[index], key)) {
			node.keys.erase(node.keys.begin() + static_cast<std::ptrdiff_t>(index));
			node.values.erase(node.values.begin() + static_cast<std::ptrdiff_t>(index));
			return true;
		}
	}
	return false;
}

} // namespace aurelion::rules::state
