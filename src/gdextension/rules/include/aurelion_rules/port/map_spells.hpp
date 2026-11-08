#pragma once

// The map spells (docs/magic-system-spells.md, Map; spell_map.cpp): effect type "map_effect", one mechanic each.
// Their terms at the caster's spell power, what keeps one from being cast where its hero stands, what a cast leaves
// on the map, and the terms a hero keeps until its next day starts. Today's overworld spells (restore_movement,
// reveal_radius) stay in spell_rules_overworld.cpp. The human seat casts through overworld_rules_spells.cpp, a
// computer hero through ai_hero_rules_turn_day.cpp; each reveals in its own fog.

#include "aurelion_rules/port/gd.hpp"
#include "aurelion_rules/port/overworld_rules.hpp"

#include <cstdint>

namespace aurelion::rules::port::map_spells {

using gd::ArrayRef;
using gd::Atom;
using gd::DictRef;
using overworld_rules::Vector2i;
using state::State;
using state::Value;

// Who casts: the hero's state (a human hero or a computer commander), its player (the human seat is "player", as
// its sites and towns name it), and where it stands.
struct Caster {
	DictRef hero = 0;
	Atom controller = 0;
	Vector2i tile;
	int64_t level = 0;
};

// A spell of effect type map_effect, its mechanic (the effect's "map": map_sight, map_move, ...), and its terms at
// the hero's spell power: each number plus <name>_power_scale x power plus power / <name>_power_divisor.
bool is_map_spell(State &state, DictRef spell);
Atom mechanic(State &state, DictRef spell);
DictRef terms(State &state, DictRef hero, DictRef spell);

// The spell's effect at the hero's power, without a full stop ("Sees 5 tiles farther ..."), as the spellbook, the
// action list and the cast show it. Harvest Bloom names its mine when one is given.
Atom effect_text(State &state, DictRef hero, DictRef spell, DictRef mine);
// Which spellbook group a map spell belongs to: field_route, field_survey or field_utility.
Atom category(State &state, DictRef spell);

// What a cast does to the hero alone (Far Sight's sight, Stride's movement, Read Tracks' reach): the hero's state
// and movement are changed in place. The fog a cast opens around the hero: the radius on its level, and whether
// every level opens too.
void apply_to_hero(State &state, DictRef hero, DictRef movement, DictRef spell);
int64_t reveal_radius(State &state, DictRef hero, DictRef spell);
bool reveals_every_level(State &state, DictRef spell);

// The held mine beside the caster that Harvest Bloom would take ({} when none): a persistent site with an income,
// held by the caster's player, on the caster's tile or one next to it, the first in the map's order.
DictRef harvest_mine(State &state, DictRef session, const Caster &caster);
// Why the spell cannot be cast where the caster stands (empty when it can).
Atom refusal(State &state, DictRef session, const Caster &caster, DictRef spell);
// What a cast leaves on the map once its mana is spent (Harvest Bloom's mine): the mine it took, or {}.
DictRef apply_to_map(State &state, DictRef session, const Caster &caster, DictRef spell, int64_t day);

// The day's terms a hero keeps until its next day starts, cleared there before its movement is counted.
void clear_day_terms(State &state, DictRef hero);
// A blooming mine's income counts this many times on a day (1, or 2 on Harvest Bloom's days).
int64_t harvest_factor(State &state, DictRef node, int64_t day);

// Read Tracks: whether one of the human seat's heroes reads the ground at a tile today, and the garrison of a town
// not its own whose entrance is there ({town_name, stacks}, or {} when none shows).
bool tracks_read(State &state, DictRef session, Vector2i tile, int64_t level);
DictRef read_tracks_garrison(State &state, DictRef session, Vector2i tile, int64_t level);

} // namespace aurelion::rules::port::map_spells
