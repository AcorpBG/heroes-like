#include "aurelion_rules/battle_state.hpp"

#include "aurelion_rules/compat/godot_string.hpp"

namespace aurelion::rules::state {

namespace {

constexpr std::string_view kKnownKeys[] = {
#define AURELION_KEY(name, text) text,
#include "aurelion_rules/battle_keys.inc"
#undef AURELION_KEY
};

int64_t find_index(const DictNode &node, const Value &key) {
	return node.keys.find(key);
}

std::string pair_text(int64_t q, int64_t r) {
	return compat::itos(q) + "," + compat::itos(r);
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
	joined_.clear();
	for (std::string_view text : kKnownKeys) {
		intern(text);
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

bool State::backed_lookup(uint32_t dict_node, const Value &key, Value &out) const {
	return backing_->dict_lookup(const_cast<State &>(*this), dict_node, key, out);
}

bool State::erase(uint32_t dict_node, const Value &key) {
	DictNode &node = dict(dict_node);
	const int64_t index = find_index(node, key);
	if (index < 0) {
		return false;
	}
	node.keys.erase_at(static_cast<size_t>(index));
	node.values.erase_at(static_cast<size_t>(index));
	node.dirty = true;
	return true;
}

void State::out_of_bounds(int64_t index) {
	throw ScriptError("Out of bounds get index '" + std::to_string(index) + "' (on base: 'Array')");
}

} // namespace aurelion::rules::state
