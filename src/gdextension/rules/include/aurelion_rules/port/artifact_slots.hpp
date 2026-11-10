#pragma once

// The slots a hero wears artifacts in (docs/hero-screen.md, Artifact slots): the
// kinds an artifact's "slot" field can name, and the hero's slots of each kind.
// One copy for every rule that walks a hero's equipment. The five slots older
// saves hold come first, so their artifacts are read in the order they always
// were.

#include "aurelion_rules/port/gd.hpp"

namespace aurelion::rules::port::artifact_slots {

using gd::Atom;

// What an artifact's "slot" can be.
inline constexpr Atom kKinds[] = {
	state::key::boots, state::key::banner, state::key::armor, state::key::trinket,
	state::key::head, state::key::neck, state::key::cloak, state::key::hand, state::key::ring,
};

// Every slot of a hero.
inline constexpr Atom kEquipment[] = {
	state::key::boots, state::key::banner, state::key::armor, state::key::trinket, state::key::trinket_2,
	state::key::head, state::key::neck, state::key::cloak, state::key::hand, state::key::hand_2,
	state::key::ring, state::key::ring_2, state::key::trinket_3, state::key::trinket_4,
};

struct KindSlots {
	Atom kind;
	Atom slots[4];
	int count;
};

// A kind's slots, in the order an artifact tries them.
inline constexpr KindSlots kSlotsByKind[] = {
	{state::key::boots, {state::key::boots}, 1},
	{state::key::banner, {state::key::banner}, 1},
	{state::key::armor, {state::key::armor}, 1},
	{state::key::trinket, {state::key::trinket, state::key::trinket_2, state::key::trinket_3, state::key::trinket_4}, 4},
	{state::key::head, {state::key::head}, 1},
	{state::key::neck, {state::key::neck}, 1},
	{state::key::cloak, {state::key::cloak}, 1},
	{state::key::hand, {state::key::hand, state::key::hand_2}, 2},
	{state::key::ring, {state::key::ring, state::key::ring_2}, 2},
};

struct SlotRun {
	const Atom *first;
	int count;
	const Atom *begin() const { return first; }
	const Atom *end() const { return first + count; }
};

inline bool is_kind(Atom kind) {
	for (const Atom known : kKinds) {
		if (known == kind) {
			return true;
		}
	}
	return false;
}

inline bool is_equipment_slot(Atom slot) {
	for (const Atom known : kEquipment) {
		if (known == slot) {
			return true;
		}
	}
	return false;
}

// Empty for anything that is not a kind.
inline SlotRun slots_of_kind(Atom kind) {
	for (const KindSlots &entry : kSlotsByKind) {
		if (entry.kind == kind) {
			return {entry.slots, entry.count};
		}
	}
	return {nullptr, 0};
}

} // namespace aurelion::rules::port::artifact_slots
