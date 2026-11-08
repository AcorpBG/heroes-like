#pragma once

// The map spells (docs/magic-system-spells.md, Map; spell_map.cpp, spell_map_tiles.cpp): effect type "map_effect",
// one mechanic each. Their terms at the caster's spell power, what keeps one from being cast where its hero stands,
// what a cast leaves on the map, the terms a hero keeps until its next day starts, what the steps of a walk cost once
// Forge Road, Scorched Earth and wardwoods count, and the tiles the spells aimed at a tile reach. Today's overworld
// spells (restore_movement, reveal_radius) stay in spell_rules_overworld.cpp. The human seat casts through
// overworld_rules_spells.cpp and walks through overworld_rules_move.cpp, a computer hero does both in
// ai_hero_rules_turn_day.cpp; each reveals in its own fog.

#include "aurelion_rules/port/gd.hpp"
#include "aurelion_rules/port/overworld_rules.hpp"

#include <cstdint>
#include <unordered_set>
#include <vector>

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

// What a cast on the given day does to the hero alone (Far Sight's sight, Stride's movement, Read Tracks' reach,
// Forge Road's days): the hero's state and movement are changed in place. The fog a cast opens around the hero: the
// radius on its level, and whether every level opens too.
void apply_to_hero(State &state, DictRef hero, DictRef movement, DictRef spell, int64_t day);
int64_t reveal_radius(State &state, DictRef hero, DictRef spell);
bool reveals_every_level(State &state, DictRef spell);

// The held mine beside the caster that Harvest Bloom would take ({} when none): a persistent site with an income,
// held by the caster's player, on the caster's tile or one next to it, the first in the map's order.
DictRef harvest_mine(State &state, DictRef session, const Caster &caster);
// Why the spell cannot be cast where the caster stands (empty when it can).
Atom refusal(State &state, DictRef session, const Caster &caster, DictRef spell);
// What a cast leaves on the map once its mana is spent: Harvest Bloom's mine, which it returns ({} for every other
// spell), or the mark of Scorched Earth, a wardwood or a Firebreak on the caster's tile (overworld.map_spell_marks:
// {map, spell_id, x, y, level, radius, until_day, controller}, kept until the end of its last day).
DictRef apply_to_map(State &state, DictRef session, const Caster &caster, DictRef spell, int64_t day);

// The spells aimed at a tile the player picks (target_mode tile_selected): Flare, Firebreak, Rootway, Relay, Ferry
// Call and Mist Jump.
bool needs_tile(State &state, DictRef spell);
// The tiles the spell reaches from where the caster stands, by rows, by the map alone (what the player has scouted is
// the caller's): Flare any tile within its range; Firebreak a free tile next to the hero; Rootway a free tile beside
// trees within range; Relay the gate of a town of the caster's within range with no hero at it; Ferry Call, straight
// out in each of the eight directions, the first free land across at most its range of water; Mist Jump any free tile
// within range. A free tile is land an army can stand on with nothing on it and no guard watching it.
std::vector<Vector2i> target_tiles(State &state, DictRef session, const Caster &caster, DictRef spell);
// What to pick for the spell, at the hero's power ("Choose a free tile up to 5 tiles away."): the prompt, and the
// refusal of a tile it does not reach.
Atom aim_text(State &state, DictRef hero, DictRef spell);
// What a cast at a tile it reaches does once its mana is spent: Firebreak's mark goes on the tile and the map's
// blocked tiles are counted again ({}); Flare returns {reveal_radius}; Rootway, Relay, Ferry Call and Mist Jump
// return {move_to, ends_movement}, the caller moving the army (Relay and Ferry Call end its day's movement).
DictRef apply_at(State &state, DictRef session, const Caster &caster, DictRef spell, Vector2i tile, int64_t day);
// The tiles Firebreaks close on a level today, set in a blocked tile index (OverworldRules._build_blocked_tile_index).
void add_blocked_tiles(State &state, DictRef session, int64_t level, DictRef index);
// A new day opens: the marks whose last day is over go, and once a Firebreak goes the map's blocked tiles are counted
// again.
void open_day(State &state, DictRef session, int64_t day);

// The day's terms a hero keeps until its next day starts, cleared there before its movement is counted.
void clear_day_terms(State &state, DictRef hero);

// An army walking the map: the hero's state (a human hero or a computer commander), its player (as a Caster's), its
// level and the day.
struct Mover {
	DictRef hero = 0;
	Atom controller = 0;
	int64_t level = 0;
	int64_t day = 0;
};

// What the steps of one walk cost once the map spells count, in half points of movement (a point walks a tile): 2 a
// step, 1 from a road tile to a road tile while the mover's Forge Road lasts, and twice that into an enemy's Scorched
// Earth. A step from outside into the reach of an enemy's wardwood stops the army there. Without a Forge Road on the
// mover or an enemy's mark on its level, active() is false: every step costs a point and the walk is the plain one.
class StepCosts {
public:
	StepCosts(State &state, DictRef session, const Mover &mover);
	bool active() const { return active_; }
	int64_t halves(Vector2i from, Vector2i to) const;
	bool stops(Vector2i from, Vector2i to) const;

private:
	struct Zone {
		Vector2i tile;
		int64_t radius = 0;
	};
	bool inside(const Zone &zone, Vector2i tile) const;
	State *state_ = nullptr;
	bool active_ = false;
	bool roads_ = false;
	std::unordered_set<uint64_t> road_tiles_;
	std::vector<Zone> slow_;
	std::vector<Zone> watch_;
};

// The half point a hero saved on a road today (0 or 1; the walk spends it before a new point), and setting it.
int64_t banked_half(State &state, DictRef hero);
void set_banked_half(State &state, DictRef hero, int64_t half);
// A wardwood stopped the hero's army: it starts its next day with half its movement.
void stop_at_wardwood(State &state, DictRef hero);
// The movement a hero starts its day with: the day's full movement, or half of it after a wardwood stopped its army
// (the stop ends there).
int64_t morning_movement(State &state, DictRef hero, int64_t movement_max);

// Whether a mark of this mechanic (map_slow_zone, map_watch) cast by the player or an ally stands over the tile today.
bool mark_stands_at(State &state, DictRef session, Atom kind, Atom controller, Vector2i tile, int64_t level, int64_t day);
// The marks of Scorched Earth and wardwoods that cover a tile on a day, one line each as the inspection shows them to
// the human seat ("Your Scorched Earth, until day 9: ..."); a level below 0 is the active hero's, a day below 0 today.
ArrayRef marks_at(State &state, DictRef session, Vector2i tile, int64_t level, int64_t day);

// A blooming mine's income counts this many times on a day (1, or 2 on Harvest Bloom's days).
int64_t harvest_factor(State &state, DictRef node, int64_t day);

// Read Tracks: whether one of the human seat's heroes reads the ground at a tile today, and the garrison of a town
// not its own whose entrance is there ({town_name, stacks}, or {} when none shows).
bool tracks_read(State &state, DictRef session, Vector2i tile, int64_t level);
DictRef read_tracks_garrison(State &state, DictRef session, Vector2i tile, int64_t level);

} // namespace aurelion::rules::port::map_spells
