#pragma once

// scripts/core/SpellRules.gd, ported function by function under the GDScript
// names (docs/native-rules-engine-transition.md). Phase 1, layer 2: the effect
// reads of a battle stack, the normalizers they use and
// normalize_school_resistance. Layer 4: status immunity and normalizing and
// purging a stack's effects. Layer 8: the battle spells. _normalize_spell_ids
// and the spell helpers shared with the battle port are on main
// (spell_rules.cpp).

#include "aurelion_rules/port/gd.hpp"

#include <cstdint>
#include <vector>

namespace aurelion::rules::port::spell_rules {

using gd::ArrayRef;
using gd::Atom;
using gd::DictRef;
using state::State;
using state::Value;

// The commander payload: a side's hero payload, its specialty bonuses and
// difficulty terms (commander_payload.cpp).
DictRef normalize_school_resistance(State &state, const Value &value);

// The effect reads of a stack, the town assault effects and the damage rules'
// multipliers (spell_effects.cpp).
int64_t battle_spell_recoverable_health(State &state, DictRef stack);
int64_t effect_bonus_for_kind(State &state, DictRef stack, DictRef battle, Atom kind);
bool has_effect_id(State &state, DictRef stack, DictRef battle, Atom effect_id);
bool has_any_effect_ids(State &state, DictRef stack, DictRef battle, const Value &effect_ids);
ArrayRef active_effects_for_round(State &state, DictRef stack, int64_t round_number);
ArrayRef _normalize_effects(State &state, const Value &value);
DictRef _normalize_effect_modifiers(State &state, const Value &value);
ArrayRef normalize_blocked_status_ids(State &state, const Value &value);
ArrayRef normalize_status_immunity_ids(State &state, const Value &value);

// Layers 3 and 4.

// Stack effects: applying, spending, expiring and cleansing effects, defending
// and the readiness writ (stack_effects.cpp).
ArrayRef stack_status_immunity_ids(State &state, DictRef stack, DictRef battle);
bool target_is_immune_to_status(State &state, DictRef target_stack, DictRef battle, Atom status_id);
DictRef normalize_stack_effects(State &state, DictRef stack);
DictRef purge_expired_stack_effects(State &state, DictRef stack, int64_t round_number);

// A list of spell ids, the empty ones dropped (spell_rules.cpp).
ArrayRef _normalize_spell_ids(State &state, const Value &value);

// Shared with the battle port: a spell's school, tier and roles, its mana cost
// for a hero, and the hero's mana and known spells (spell_rules.cpp).
int64_t adjusted_spell_mana_cost(State &state, DictRef hero_state, const Value &spell);
Atom spell_school_id(State &state, DictRef spell);
int64_t spell_tier(State &state, DictRef spell);
Atom spell_primary_role(State &state, DictRef spell);
ArrayRef spell_role_categories(State &state, DictRef spell);
ArrayRef _normalize_string_array(State &state, const Value &value);
bool _has_mana(State &state, DictRef hero_state, int64_t cost);
bool _knows_spell(State &state, DictRef hero_state, Atom spell_id);
// Worn scrolls (docs/magic-system.md, Scrolls): the spells the scrolls in a
// hero's trinket slots lend, once each; whether the hero can cast a spell (it
// knows it, or a worn scroll lends it); and the ids it can cast, its known
// spells first. Learning reads only the known spells.
ArrayRef worn_scroll_spell_ids(State &state, DictRef hero_state);
bool can_cast_spell(State &state, DictRef hero_state, Atom spell_id);
ArrayRef castable_spell_ids(State &state, DictRef hero_state);
// The spells the hero casts without knowing them: its worn scrolls' and the ones its artifacts grant
// (docs/artifact-system.md, Special effects).
ArrayRef lent_spell_ids(State &state, DictRef hero_state);
// The Flame: the first spell of a battle costs its wearer no mana. The battle's copy of the hero carries the mark
// from the battle's start until its first cast; the hero that returns to the map does not.
void mark_battle_start(State &state, DictRef hero_state);
void clear_battle_marks(State &state, DictRef hero_state);

// Layer 5: a battle effect built from an ability (attack_effects.cpp).
DictRef build_battle_effect(State &state, Atom effect_id, Atom label, const Value &modifiers, int64_t duration_rounds, DictRef battle, Atom source_type, Atom source_id, const Value &status_immunity_ids);

// Layer 8: the battle spells. A spell's battle behavior, the cast and target
// checks, spell and control resistance, the damage, recovery and duration of
// a cast, the effect payloads and the status resistance roll
// (spell_battle.cpp). _battle_stream_rng answers a RandomNumberGenerator, or
// Nil for a battle without a seed.
DictRef battle_spell_behavior(State &state, DictRef spell);
DictRef _battle_spell_ally_target(State &state, DictRef active_stack, DictRef target_stack, Atom acting_side);
DictRef battle_spell_cast_check(State &state, DictRef hero, DictRef spell_dict, DictRef active_stack, Atom acting_side);
DictRef battle_spell_target_check(State &state, DictRef battle, DictRef active_stack, DictRef target_stack, DictRef spell_dict, Atom acting_side);
int64_t spell_damage_resistance_pct(State &state, DictRef battle, DictRef target_stack, DictRef spell);
int64_t control_resistance_pct(State &state, DictRef battle, DictRef target_stack, DictRef spell);
DictRef battle_spell_damage_projection(State &state, DictRef hero_state, DictRef battle, DictRef target_stack, DictRef spell);
DictRef battle_spell_status_resolution(State &state, DictRef battle, DictRef active_stack, DictRef target_stack, DictRef spell, DictRef effect_payload);
int64_t spell_duration_bonus(State &state, DictRef hero_state);
int64_t spell_duration_rounds(State &state, DictRef hero_state, const Value &base_rounds, DictRef spell, Atom kind);
// The rounds at a given spell power: spell_power_against for harmful spells.
int64_t _spell_duration_rounds_at(State &state, DictRef hero_state, const Value &base_rounds, DictRef spell, Atom kind, int64_t power);
// The hero's spell power for a spell: Power and its bonuses, and 1 more for
// its faction's preferred school (preferred_school_power). Without a spell
// (an empty Dictionary), the power alone.
int64_t spell_power(State &state, DictRef hero_state, DictRef spell);
// 1 when the spell is of the preferred school of the hero's own faction,
// whoever hires it; a neutral commander has no faction (docs/magic-system.md,
// Faction preference).
int64_t preferred_school_power(State &state, DictRef hero_state, DictRef spell);
// The row of the hero's own faction, whoever hires it: {} for a neutral
// commander or a hero without a row. A commander payload names the hero's
// row as roster_hero_id or hero_id, a hero state as id.
DictRef hero_faction(State &state, DictRef hero_state);
// The Knowledge of the hero leading the target's side, and the caster's power
// less all of it, never below 0 (docs/magic-system.md).
int64_t target_side_knowledge(State &state, DictRef battle, DictRef target_stack);
int64_t spell_power_against(State &state, DictRef hero_state, DictRef battle, DictRef target_stack, DictRef spell);
int64_t _school_bonus(State &state, DictRef bonuses, Atom field, DictRef spell);
DictRef _counted_in_turns(State &state, DictRef effect, int64_t turns);
DictRef battle_spell_modifiers(State &state, DictRef spell);
DictRef _effect_payload(State &state, DictRef spell, DictRef effect, DictRef battle, DictRef hero_state);
// The tier-2 payload terms: modifiers that grow with power
// (modifiers_power_scale, modifiers_power_divisor), an effect's turns (fixed
// with fixed_duration), its resolved mechanic, the payload on a target (a
// mechanic with uses_enemy_power grows with power less the other side's
// Knowledge), a sealed wound's payload, and a status payload from any status
// Dictionary, extra_turns longer (a follow-up status starts as the first ends).
int64_t heat_burst_damage(int64_t power_against);
DictRef scaled_spell_modifiers(State &state, DictRef effect, DictRef modifiers, int64_t power);
int64_t spell_effect_turns(State &state, DictRef hero_state, DictRef effect, DictRef spell, Atom kind, int64_t power);
void set_effect_mechanic(State &state, DictRef built, DictRef holder, int64_t power);
DictRef _effect_payload_for(State &state, DictRef spell, DictRef effect, DictRef battle, DictRef hero_state, DictRef target_stack);
DictRef heal_block_payload(State &state, DictRef spell, DictRef battle, int64_t turns);
DictRef _status_payload(State &state, DictRef spell, const Value &status_effect, DictRef battle, DictRef hero_state, int64_t power, int64_t extra_turns);
DictRef _hero_payload_for_target_side(State &state, DictRef battle, DictRef target_stack);
DictRef _status_resistance_roll(State &state, DictRef battle, DictRef active_stack, DictRef target_stack, DictRef spell, Atom status_id);
Value _battle_stream_rng(State &state, DictRef battle);
int64_t _stable_percent(State &state, ArrayRef parts);
Atom _append_status_resolution_message(State &state, Atom message, DictRef target_stack, DictRef effect_payload, DictRef status_resolution);
DictRef _spell_effect_modifiers(State &state, DictRef effect, Atom default_kind, int64_t default_amount);
DictRef _status_effect_from_spell_effect(State &state, DictRef spell, DictRef battle, DictRef hero_state);
DictRef _status_effect_from_spell_effect_at(State &state, DictRef spell, DictRef battle, DictRef hero_state, int64_t power);
int64_t _battle_spell_damage(State &state, DictRef hero_state, DictRef spell, DictRef target_stack);
int64_t _battle_spell_damage_at(State &state, DictRef hero_state, DictRef spell, DictRef target_stack, int64_t power);
bool _wounded_bonus_applies(State &state, DictRef effect, DictRef target_stack);
int64_t _battle_spell_recovery_amount(State &state, DictRef hero_state, DictRef spell);
int64_t _alive_count(State &state, DictRef stack);
double _health_ratio(State &state, DictRef stack);

// The basic spells' mechanics (spell_mechanics.cpp, docs/magic-system.md):
// a spell that supports its own side's stacks; whether an effect on a stack
// helps it (a supporting spell put it there) or harms it (a harmful status, an
// enemy spell, or modifiers that only lower), and the ids of the newest such
// effects, up to limit; a count or a reach that grows by one per divisor of
// spell power, and those of a spell (count for a dispel or a cleanse, range for
// a move); a cleanse that takes any harmful effect (it names none); the empty
// hexes a moved stack can reach, and the one of them a destination names, or {}.
bool spell_supports_allies(State &state, DictRef spell);
bool effect_helps_stack(State &state, DictRef effect);
bool effect_harms_stack(State &state, DictRef effect);
ArrayRef newest_effect_ids(State &state, DictRef stack, DictRef battle, bool helpful, int64_t limit);
int64_t power_count(State &state, DictRef effect, Atom base_field, Atom divisor_field, int64_t power);
int64_t spell_effect_count(State &state, DictRef spell, int64_t power);
int64_t spell_move_reach(State &state, DictRef spell, int64_t power);
bool cleanse_takes_any_harm(State &state, DictRef effect);
ArrayRef move_destinations(State &state, DictRef battle, DictRef stack, int64_t reach);
DictRef move_destination_in_reach(State &state, ArrayRef destinations, const Value &destination);
// The statuses that harm the stack they are on, whoever put them there.
bool is_harmful_status(Atom effect_id);

// The tier-2 spells' lasting mechanics (spell_stack_mechanics.cpp,
// docs/magic-system-spells.md). An effect's mechanic (its "mechanic"
// Dictionary, kept through normalization) and a content mechanic resolved at a
// spell power (<name> + <name>_power_scale x power + power / <name>_power_divisor);
// the newest active effect on a stack whose mechanic names a field, its value,
// the newest active effect with an id, removing one effect, the newest harmful
// statuses, and the Knowledge of the side facing side.
DictRef effect_mechanic(State &state, DictRef effect);
DictRef resolve_mechanic(State &state, const Value &raw, int64_t power);
DictRef stack_mechanic_effect(State &state, DictRef stack, DictRef battle, Atom field);
int64_t stack_mechanic_int(State &state, DictRef stack, DictRef battle, Atom field);
DictRef stack_status_effect(State &state, DictRef stack, DictRef battle, Atom effect_id);
void remove_stack_effect(State &state, DictRef stack, DictRef effect);
ArrayRef newest_status_ids(State &state, DictRef stack, DictRef battle, int64_t limit);
int64_t opposing_side_knowledge(State &state, DictRef battle, Atom side);
// Damage a plate takes first (the rest is answered); a hit's aftermath (a
// sleeper wakes, a curse jumps from a fallen stack); a sealed wound.
int64_t plate_absorb(State &state, DictRef battle, DictRef stack, int64_t damage);
void after_stack_damaged(State &state, DictRef battle, Atom battle_id, int64_t taken, bool killed);
bool heal_blocked(State &state, DictRef stack, DictRef battle);
// A stable draw in [0, count) named by parts (the battle's random streams
// stay as they are).
int64_t stable_draw(State &state, DictRef battle, std::initializer_list<Value> parts, int64_t count);
// The stacks a cast reaches beyond its target (spell_reach.cpp): a mastery's
// shape, every stack, splash, beam, sparks and drain, as extra_resolutions;
// second_pick names a drain's drinker ({battle_id}). The hero's mastery rank
// in the spell's school.
void add_reach_resolutions(State &state, DictRef hero, DictRef battle, DictRef target, DictRef spell, DictRef result, const Value &second_pick);
int64_t spell_mastery_rank(State &state, DictRef hero_state, DictRef spell);
// Prism Ward: the stack of the caster's side a harmful spell cast on a warded
// stack lands on instead (empty without a ward), and the ward spent.
DictRef reflected_spell_target(State &state, DictRef battle, DictRef target, Atom spell_id);
void spend_reflect_ward(State &state, DictRef battle, Atom battle_id);
// The spells that take a second stack (spell_pairs.cpp): Graft, Blood Tithe and
// the two swaps need one, and a drain's drinker can be one. The stacks that can
// be the second for a first one, the stack a pick ({battle_id}) names, a stack's
// health with every creature it started with, a swap's reach, whether two
// stacks fit in each other's places, Blood Tithe's amount, the health it moves,
// the swap itself, the living stack grafted to one (empty without a graft), and
// a stack's grafts removed from both ends.
bool takes_second_stack(State &state, DictRef spell);
bool offers_second_stack(State &state, DictRef spell);
ArrayRef second_stack_ids(State &state, DictRef hero, DictRef battle, DictRef first, DictRef spell, Atom acting_side);
DictRef second_stack_pick(State &state, DictRef battle, const Value &pick);
int64_t stack_full_health(State &state, DictRef stack);
int64_t spell_swap_range(State &state, DictRef hero, DictRef battle, DictRef spell, DictRef first);
bool swap_fits(State &state, DictRef battle, DictRef a, DictRef b);
int64_t transfer_amount(State &state, DictRef hero, DictRef spell, DictRef receiver, DictRef donor);
int64_t move_stack_health(State &state, DictRef battle, Atom donor_id, Atom receiver_id, int64_t amount);
void swap_stack_places(State &state, DictRef battle, Atom a_id, Atom b_id);
Atom graft_partner(State &state, DictRef battle, Atom battle_id);
void clear_graft(State &state, DictRef battle, Atom battle_id);
// The spells that take a hex (spell_ground.cpp): Flame Furrow's burning ground,
// Bramble Patch, Crystal Pillar, Murk and Thorn Seed lay an entry on
// battle.spell_ground with their numbers fixed at the cast. Whether a spell
// takes a hex, the hexes a cast can pick, the hexes a pick covers (empty when
// it cannot take the spell), the entry a cast lays and laying it, and whether
// an entry of a kind holds. What the board reads from them: pillars as
// blockers, the anchors a walk stops in (brambles; false without any), a
// pillar's defense for its side's stacks next to it, murk over a stack, the
// walk a stack takes (the fewest burning hexes, then the fewest steps), what a
// walk met (noted on the battle), and its price at the end of the stack's
// turn, with burning ground under a stack that did not walk.
bool takes_hex(State &state, DictRef spell);
ArrayRef ground_pick_cells(State &state, DictRef battle, DictRef spell);
// Every hex a hex spell can be cast on, each with the hexes it covers ({q, r, cells}); a blob's size is the
// hero's (Bog Pool).
ArrayRef ground_pick_shapes(State &state, DictRef battle, DictRef spell, DictRef hero);
ArrayRef ground_shape_cells(State &state, DictRef battle, DictRef spell, DictRef center, DictRef hero);
DictRef ground_entry_for_cast(State &state, DictRef hero, DictRef battle, DictRef spell, Atom side, ArrayRef cells);
void add_ground(State &state, DictRef battle, DictRef entry);
// A ground entry's damage to a stack, after its resistance (0 when the entry does no damage).
int64_t ground_damage_against(State &state, DictRef battle, DictRef entry, DictRef stack);
bool has_ground(State &state, DictRef battle, Atom ground);
void add_pillar_blockers(State &state, DictRef battle, DictRef blocked);
bool bramble_stop_mask(State &state, DictRef battle, DictRef stack, uint8_t *stop);
int64_t pillar_defense(State &state, DictRef battle, DictRef stack);
bool in_murk(State &state, DictRef battle, DictRef stack);
// Tier 4 and 5's ground: Elder Grove's defense and heal for its side's stacks in it (the heal at the start of the
// stack's turn), and Glass Dome: a stack under one, and a shot or spell kept off a stack under a dome by coming from
// outside it (a spell has no shooter).
int64_t grove_defense(State &state, DictRef battle, DictRef stack);
void grove_heal(State &state, DictRef battle, Atom battle_id);
bool in_dome(State &state, DictRef battle, DictRef stack);
bool dome_keeps_off(State &state, DictRef battle, DictRef shooter, DictRef target);
// Tier 3's ground: Boundary Line closes its hexes to the other side's walks (in an open mask), Fogwalk's walk
// passes everything else (its pass mask; false when the stack does not phase), a stack in Bog Pool's mire, a shot
// whose line crosses Living Wall, and Prism Array's crystals firing after a damage spell of their side's hero (the
// message suffix, empty when none fires).
void close_barrier_cells(State &state, DictRef battle, DictRef stack, uint8_t *open);
bool phase_pass_mask(State &state, DictRef battle, DictRef stack, uint8_t *pass);
bool in_mire(State &state, DictRef battle, DictRef stack);
bool shot_crosses_wall(State &state, DictRef battle, DictRef shooter, DictRef target);
// The hex ids a straight shot between two hexes (ids q * rows + r) passes over, the two ends left out.
std::vector<int64_t> shot_line_cells(int64_t from_id, int64_t to_id);
Atom fire_prisms(State &state, DictRef battle, Atom side, DictRef spell);
ArrayRef ground_walk_path(State &state, DictRef battle, DictRef stack, DictRef start, DictRef destination, int64_t max_steps);
void after_ground_walk(State &state, DictRef battle, Atom battle_id, DictRef start);
void end_of_turn_ground(State &state, DictRef battle, Atom battle_id);
// What the ground would cost a stack's walk this turn, read for the battle AI: for each hex it can end on, the damage
// of one burn of the burning ground its walk crosses or ends in (on its own hex, staying: the ground it stands in), of
// the brambles it ends in and of the other side's seeds beside the end, each after the stack's resistance, with the
// statuses those seeds would set where it is not immune. Empty when no fire, brambles or seed of the other side
// holds, so a board without that ground reads nothing more.
struct WalkToll {
	int64_t damage = 0;
	std::vector<Atom> statuses;
};
class GroundTolls {
public:
	GroundTolls(State &state, DictRef battle, DictRef stack);
	bool empty() const { return tolls_.empty(); }
	// The toll of ending on a hex ({q, r}); nothing off the board or without ground.
	const WalkToll &at(State &state, const Value &cell) const;

private:
	std::vector<WalkToll> tolls_;
	WalkToll none_;
};
// A turn's end (backlash, tightening roots, curse) and start (regrowth; true
// when the stack sleeps through it); begin_active_turn runs the start for the
// active stack and passes the turns of sleepers on.
void end_of_turn_mechanics(State &state, DictRef battle, Atom battle_id);
bool start_of_turn_mechanics(State &state, DictRef battle, Atom battle_id);
void begin_active_turn(State &state, DictRef battle);
// Blows: stand fast's attack, the marked and blinded share, a landed blow's
// thorns, lifesteal and momentum (messages), the stack a confused attacker
// hits, shots the spells refuse, and moves fear refuses.
int64_t stationary_attack_bonus(State &state, DictRef battle, DictRef attacker, bool is_retaliation);
double blow_damage_multiplier(State &state, DictRef battle, DictRef attacker, DictRef defender, bool is_ranged);
ArrayRef after_blow_mechanics(State &state, DictRef battle, Atom attacker_id, Atom defender_id, bool is_ranged, int64_t dealt);
DictRef confused_blow_target(State &state, DictRef battle, DictRef attacker, DictRef target, bool is_ranged);
bool shot_refused_by_spells(State &state, DictRef battle, DictRef shooter, DictRef target);
bool move_refused_by_fear(State &state, DictRef battle, DictRef stack, DictRef cell);
// Heat on a stack (the message suffix of the Heat it holds or its burst);
// Call to Arms (it acts next, or first next round) and the order it makes.
Atom add_heat(State &state, DictRef battle, Atom battle_id, int64_t heat, int64_t burst_damage);
void act_next(State &state, DictRef battle, Atom battle_id);
ArrayRef acts_next_first(State &state, DictRef battle, ArrayRef battle_ids);

// The tier-3 spells' lasting mechanics (spell_tier3.cpp, docs/magic-system-spells.md). Burning (its status, a
// burning blow's message suffix, empty when none lands) and a turn's end: Burning, Tolling Doom, Last Breath's heal.
DictRef burning_payload(State &state, DictRef battle, Atom source_id, int64_t damage, int64_t turns);
Atom burning_blow(State &state, DictRef battle, DictRef striker, Atom defender_id);
void end_of_turn_tier3(State &state, DictRef battle, Atom battle_id);
// A hit's health after Tempering's cap, Last Breath's last creature and Seed of Return's regrowth, with Budding's
// creatures falling first; the creatures a stack keeps when the battle ends (its budded ones wither); Budding.
int64_t health_after_hit(State &state, DictRef battle, DictRef stack, int64_t health, int64_t taken);
int64_t kept_alive_count(State &state, DictRef stack);
int64_t bud_stack(State &state, DictRef battle, Atom battle_id, int64_t amount);
// Blight turns healing on its stack into harm (true when the stack is blighted); Rekindle raises fallen creatures
// up to the stack's starting count; Glass Aegis refuses enemy spells; Steadfast Halo holds cohesion.
bool blight_turns_heal(State &state, DictRef battle, DictRef stack, int64_t amount);
int64_t raise_stack_health(State &state, DictRef battle, Atom battle_id, int64_t amount);
bool spell_shielded(State &state, DictRef battle, DictRef stack);
bool cohesion_locked(State &state, DictRef battle, DictRef stack);
// Flashpoint spends a stack's Heat or kindles one on a cold stack (the message suffix); Earthsplit's hex toward the
// stack's own edge (empty when it cannot move); Volley Signal's shooters, one shot's damage and the volley (its
// messages); Hollowing's enemy stacks next to a stack.
Atom spend_or_kindle_heat(State &state, DictRef battle, Atom battle_id);
DictRef push_cell(State &state, DictRef battle, DictRef stack, int64_t steps);
ArrayRef volley_shooters(State &state, DictRef battle, Atom side, DictRef target);
int64_t volley_shot_damage(State &state, DictRef battle, DictRef shooter, DictRef target, int64_t pct);
Atom fire_volley(State &state, DictRef battle, Atom side, Atom target_id, int64_t pct);
ArrayRef enemies_beside(State &state, DictRef battle, DictRef stack);
// Tier 3's control spells and Fogwalk (spell_tier3_control.cpp): Goad's named stack (empty when the stack is not
// goaded or the named one has fallen) and the stack it must attack now (empty when it cannot reach it); strike-backs
// refused for a Fleeing defender or the active stack's unanswered blow (the reason, empty when none) and the blow
// that spends Fogwalk's; Night Terror's run at the start of the stack's turn (true when the turn went to it);
// Uproot's reach and the hexes it can drag a stack to.
DictRef goad_target(State &state, DictRef battle, DictRef stack);
DictRef goad_forced_target(State &state, DictRef battle, DictRef stack);
Atom strike_back_refused_reason(State &state, DictRef battle, DictRef defender);
bool strike_back_refused(State &state, DictRef battle, DictRef defender);
void note_blow_for_strike_back(State &state, DictRef battle, Atom attacker_id, bool is_ranged);
bool flee_turn(State &state, DictRef battle, Atom battle_id);
int64_t spell_pull_reach(State &state, DictRef hero, DictRef battle, DictRef spell, DictRef target);
ArrayRef pull_destinations(State &state, DictRef battle, DictRef stack, int64_t reach);
// Tier 3's conjured stacks, rewind and charm (spell_tier3_conjure.cpp). A conjured stack and a decoy; whether a side
// still holds the field (a living stack that was not conjured); whether a spell conjures on a hex it takes (a summon
// or a raise), the hexes a cast can take and the cells a pick covers; a decoy's hex beside its stack (empty when
// none); the stack a cast conjures (not yet on the field; empty when the hex or stack cannot take it), putting it on
// the field (its battle id), its vanishing (the message, empty when nothing vanished), a hit on a decoy (true when
// the decoy vanished instead) and the conjured stacks whose rounds ended. Hour Ledger: the snapshots each round's
// start takes while a commander knows a rewind spell, its reach in rounds, the hexes a stack can go back to (each
// {q, r, round, total_health, budded_health}), the one a pick names and the rewind. Puppet Strings: its damage share
// against the stack, whether the stack shoots the victim, whether it reaches it (and the hex it walks to first,
// empty when it does not walk), the stacks of its side it can attack, a blow's damage and the attack (a message
// suffix).
bool is_conjured(const State &state, DictRef stack);
bool is_decoy(const State &state, DictRef stack);
bool holds_field(State &state, DictRef battle, Atom side);
bool conjures_on_hex(State &state, DictRef spell);
ArrayRef conjure_pick_cells(State &state, DictRef battle, DictRef spell, Atom side);
ArrayRef conjure_shape_cells(State &state, DictRef battle, DictRef spell, DictRef center, Atom side);
DictRef decoy_cell(State &state, DictRef battle, DictRef target);
DictRef conjured_stack_for_cast(State &state, DictRef hero, DictRef battle, DictRef spell, Atom side, DictRef cell, DictRef target);
Atom add_conjured_stack(State &state, DictRef battle, DictRef stack);
Atom vanish_conjured(State &state, DictRef battle, Atom battle_id);
bool decoy_takes_hit(State &state, DictRef battle, Atom battle_id);
void expire_conjured(State &state, DictRef battle, int64_t round);
void record_round_ledger(State &state, DictRef battle, int64_t round);
int64_t rewind_reach(State &state, DictRef hero, DictRef spell);
ArrayRef rewind_destinations(State &state, DictRef battle, DictRef stack, int64_t reach);
DictRef rewind_snapshot_at(State &state, DictRef battle, DictRef stack, int64_t reach, const Value &destination);
void rewind_stack(State &state, DictRef battle, Atom battle_id, DictRef snapshot);
int64_t charm_damage_pct(State &state, DictRef hero, DictRef battle, DictRef spell, DictRef puppet);
bool charm_shoots(State &state, DictRef battle, DictRef puppet, DictRef victim);
bool charm_reach(State &state, DictRef battle, DictRef puppet, DictRef victim, DictRef &approach);
ArrayRef charm_victim_ids(State &state, DictRef battle, DictRef puppet);
int64_t charm_blow_damage(State &state, DictRef battle, DictRef puppet, DictRef victim, int64_t pct);
Atom charm_attack(State &state, DictRef battle, Atom puppet_id, Atom victim_id, int64_t pct);
// Tier 4 and 5, one stack (spell_tier45.cpp): Sanctuary and Ironbark, read by the damage of blows and spells; a hurt
// meets the stack's wards first (Sanctuary keeps it off, Crucible Ward takes it and lends attack) and what gets
// through comes back; Molten Brand melts at each hurt; Grave Edge's blows ignore defense and are spent one by one;
// Poison halves healing; a Censured stack has no abilities and takes no help from its own hero's spells; a Stunned
// stack loses its turn; Poison and Death's Door at a turn's end; Death's Door's share at the cast.
bool in_sanctuary(State &state, DictRef battle, DictRef stack);
bool halves_shots_and_spells(State &state, DictRef battle, DictRef stack);
int64_t hit_after_wards(State &state, DictRef battle, DictRef stack, int64_t damage);
void brand_melts(State &state, DictRef battle, DictRef stack);
bool pierces_defense(State &state, DictRef battle, DictRef attacker);
void spend_pierce(State &state, DictRef battle, Atom attacker_id);
int64_t poisoned_healing(State &state, DictRef battle, DictRef stack, int64_t amount);
bool censured(State &state, DictRef stack);
bool stunned_turn(State &state, DictRef battle, Atom battle_id);
void end_of_turn_tier45(State &state, DictRef battle, Atom battle_id);
int64_t deaths_door_pct(State &state, DictRef hero, DictRef battle, DictRef spell, DictRef target);
// Tier 4 and 5, every stack and the whole battle (spell_tier45.cpp): Grasp of the Deep's stun for a stack already
// Rooted; Heat that stops short of a burst; Daybreak Charge's first place next round; Eternal Noon's first place and the
// statuses an aura keeps off; Second Sun's burn as a round ends; Black Tide's share of the creatures, never the last.
DictRef grasp_status(State &state, DictRef spell, DictRef battle, DictRef hero, DictRef stack, DictRef payload, int64_t power_against);
Atom heat_short_of_burst(State &state, DictRef battle, Atom battle_id, int64_t heat);
void act_first_next_round(State &state, DictRef battle, Atom battle_id);
bool side_acts_first(State &state, DictRef battle, Atom side, int64_t round);
void aura_status_immunity_ids(State &state, DictRef battle, DictRef stack, ArrayRef ids);
void second_sun_burns(State &state, DictRef battle, DictRef aura);
int64_t creature_share_pct(State &state, DictRef spell, int64_t power);
int64_t creature_share_damage(State &state, DictRef spell, DictRef stack, int64_t power);
int64_t spare_last_creature(State &state, DictRef spell, DictRef stack, int64_t damage);
// Tier 4 and 5, turns and losses (spell_tier45_turns.cpp). Redline: a melee attack's blows (2 while it holds), the
// double blow spent, and its price as the turn ends (Staggered). Clarion Call: the extra turn promised at the cast,
// taken as the stack's turn ends (true when the stack acts again at once), and whether the active stack is in one.
// Shadow Ranks: the creatures a warded stack loses, and their share back as the round ends. Green Return: once a
// battle for a side (used, marked), its fallen grow back as the next round starts. Echo: the side's last spell of
// the battle (its id, the target it named and its hex or second stack), recorded after each cast but an echo; the
// stack it names again (empty when gone); the hero that casts it again, stronger and with the mana for it; the
// echo's power bonus; and whether the computer weighs a spell again (one that needs no hex or second pick).
int64_t melee_blows(State &state, DictRef battle, DictRef attacker);
void spend_double_strike(State &state, DictRef battle, Atom attacker_id);
void redline_turn_end(State &state, DictRef battle, Atom battle_id);
void grant_extra_turn(State &state, DictRef battle, Atom battle_id);
bool take_extra_turn(State &state, DictRef battle, Atom ending_id);
bool in_extra_turn(State &state, DictRef battle, Atom battle_id);
void count_shadow_losses(State &state, DictRef battle, Atom battle_id, int64_t taken, bool killed);
void shadows_return(State &state, DictRef battle);
bool green_return_used(State &state, DictRef battle, Atom side);
void mark_green_return(State &state, DictRef battle, Atom side);
void green_return_rises(State &state, DictRef battle, DictRef aura);
DictRef last_cast_of(State &state, DictRef battle, Atom side);
void record_last_cast(State &state, DictRef battle, Atom side, Atom spell_id, DictRef resolution, const Value &destination);
bool echo_names_stack(State &state, DictRef inner_spell);
DictRef echo_target(State &state, DictRef battle, DictRef active_stack, DictRef inner_spell, DictRef last);
DictRef echo_caster(State &state, DictRef hero, DictRef echo_spell, Atom inner_id);
int64_t echo_power_bonus(State &state, DictRef hero, DictRef echo_spell);
bool echo_scores_inner(State &state, DictRef inner_spell);
// Tier 4 and 5, summons (spell_tier45_summons.cpp). Waking Forest and Drowned Host conjure over the whole battle; a
// share at the hero's power (Clockwork Twin's copy, Drowned Host's and Hollow Crown's Risen); Waking Forest's treant's
// hex (beside one of the side's stacks, nearest the closest enemy stack; empty when none), the hexes its trees take
// (beside it, where the field stays open) and the trees grown; Wraith Host's second stack beside the first, the
// health shared out; Drowned Host's Risen; why a spell over the battle cannot be cast (empty when it can); Hollow
// Crown held by a side, the other side's fallen it passes over at the cast, and its Risen as a round starts.
bool conjures_over_battle(State &state, DictRef spell);
int64_t conjure_share_pct(State &state, DictRef hero, DictRef spell);
DictRef elder_cell(State &state, DictRef battle, DictRef spell, Atom side);
ArrayRef forest_tree_cells(State &state, DictRef battle, DictRef treant, int64_t count);
void grow_trees(State &state, DictRef battle, ArrayRef cells);
ArrayRef conjured_host(State &state, DictRef battle, DictRef first, DictRef spell, Atom side);
ArrayRef risen_host_for_cast(State &state, DictRef hero, DictRef battle, DictRef spell, Atom side);
Atom battle_conjure_refusal(State &state, DictRef battle, DictRef spell, Atom side);
bool hollow_crown_held(State &state, DictRef battle, Atom side);
void crown_marks(State &state, DictRef battle, Atom side);
void crown_rises(State &state, DictRef battle, DictRef aura);
// Thicket Snare (spell_ground.cpp, spell_reach.cpp): a hex spell that lays no ground; the enemy stacks its area
// catches, and their statuses, each on its own resistance draw.
bool snare_ground(State &state, DictRef spell);
ArrayRef snared_stacks(State &state, DictRef battle, ArrayRef cells, Atom caster_side);
ArrayRef snare_resolutions(State &state, DictRef hero, DictRef battle, DictRef spell, ArrayRef cells, Atom caster_side);
// Watchful Light: auras on battle.spell_auras (a newer one of a kind replaces its side's older one), the stack it
// heals and the round start that heals it.
void add_battle_aura(State &state, DictRef battle, DictRef entry);
DictRef most_wounded_stack(State &state, DictRef battle, Atom side);
void round_start_auras(State &state, DictRef battle, int64_t round);

// Layer 8, 07b: the cast checked, resolved and paid for, and the hero's
// known spells (spell_battle.cpp): those it can cast, the learned ones first
// and then those its worn scrolls lend; learned_spells, the learned ones only.
// A spell that moves a stack takes its destination hex ({q, r}); without one
// the cast resolves with needs_destination set and moves nothing.
ArrayRef known_spells(State &state, DictRef hero_state, Atom context_filter);
ArrayRef learned_spells(State &state, DictRef hero_state, Atom context_filter);
DictRef resolve_battle_spell(State &state, DictRef hero_state, DictRef battle, DictRef active_stack, DictRef target_stack, Atom spell_id, Atom acting_side);
DictRef resolve_battle_spell(State &state, DictRef hero_state, DictRef battle, DictRef active_stack, DictRef target_stack, Atom spell_id, Atom acting_side, const Value &destination);
DictRef validate_battle_spell(State &state, DictRef hero_state, DictRef battle, DictRef active_stack, DictRef target_stack, const Value &spell, Atom acting_side);
DictRef _consume_mana(State &state, DictRef hero_state, int64_t cost);

// Shared with the battle port: a hero's spellbook (known spells, mana)
// normalized in place, the template's starting spells for one that knows none,
// returning the hero; its maximum mana (spell_rules.cpp).
DictRef ensure_hero_spellbook(State &state, DictRef hero_state, DictRef hero_template);
int64_t mana_max_from_hero(State &state, DictRef hero_state);
int64_t mana_max_from_command(State &state, const Value &command);

// Slice 10b: the text a battle spell's effect prints on the battle screen
// (spell_summaries.cpp).
Atom _battle_spell_effect_summary(State &state, DictRef hero_state, DictRef spell, DictRef battle, DictRef active_stack, DictRef target_stack);
// The new spells' words: an effect's mechanic at the numbers it holds; a
// helpful spell's modifiers and mechanic at the caster's power and its turns;
// a harmful status's terms and turns at power less Knowledge; a cast's extra
// clauses (Heat, a bonus, a sealed wound, a cleanse, a status that follows),
// joined as "; a; b" or as the sentence " A; b.".
Atom mechanic_terms(State &state, DictRef mechanic);
// Green Return's share of the starting creatures at the hero's power.
int64_t green_return_pct(State &state, DictRef hero_state, DictRef spell);
Atom helpful_effect_terms(State &state, DictRef hero_state, DictRef spell, DictRef battle, Atom caster_side);
int64_t helpful_effect_turns(State &state, DictRef hero_state, DictRef spell);
// A helpful spell's lasting mechanic at the caster's power (empty without one), and its turns: "the rest of the
// battle" for one that lasts until spent.
Atom lasting_mechanic_terms(State &state, DictRef hero_state, DictRef spell);
Atom helpful_effect_turns_label(State &state, DictRef hero_state, DictRef spell);
Atom harmful_status_terms(State &state, DictRef status_effect, int64_t power_against);
int64_t harmful_status_turns(State &state, DictRef hero_state, DictRef spell, DictRef status_effect, int64_t power_against);
ArrayRef spell_extra_clauses(State &state, DictRef hero_state, DictRef spell, DictRef battle, DictRef target_stack);
Atom clauses_as_phrase(State &state, ArrayRef clauses);
Atom clauses_as_sentence(State &state, ArrayRef clauses);
Atom status_rules_text(State &state, Atom status_id);
// A hex spell's words at the caster's numbers: a spellbook phrase, or the
// battle screen's sentence.
Atom ground_spell_summary(State &state, DictRef hero_state, DictRef spell, DictRef battle, DictRef target_stack, bool sentence);
Atom _turns_label(State &state, int64_t turns);
ArrayRef _cleanse_labels(State &state, DictRef effect);
// Readable labels for status ids ("status_harried" -> "Harried").
ArrayRef status_id_labels(State &state, const Value &ids);
Atom _status_terms(State &state, DictRef status_effect);
Atom _modifier_summary(State &state, DictRef modifiers);
Atom _signed_modifier_label(State &state, int64_t amount);

// Phase 4's port shared with Phase 5's battle ends (spell_rules_shared.cpp): a
// hero learning a spell.
DictRef learn_spell(State &state, DictRef hero_state, Atom spell_id);

// A hero's mana at the start of a day (day_economy.cpp): refresh_daily_mana fills
// it; regain_daily_mana gives back a fifth of the maximum, or all of it on a day
// that starts in an own town with a mage guild (docs/magic-system.md).
gd::DictRef refresh_daily_mana(State &state, gd::DictRef hero_state);
gd::DictRef regain_daily_mana(State &state, gd::DictRef hero_state, bool full);

} // namespace aurelion::rules::port::spell_rules
