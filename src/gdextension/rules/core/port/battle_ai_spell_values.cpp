// BattleAiRules' spell values: what a cast is worth, in one unit for every kind of spell, the share of the two
// armies' fighting power it moves. A stack's power is the fitted strength formula (content/ai_hero_weights.json,
// army_power) on its creatures, linear in their number, so health a spell takes or gives counts at its stack's power
// per point of health. A cast is worth the power it takes from the other side as a share of that side's power, plus
// the power it gives its own side as a share of its own. A lasting effect counts for the turns it holds of the rounds
// the battle still has (min(turns, R) / R, with R the rounds until one side's blows would destroy the other, about
// half of each stack's hardest blow landing each round, 1 to 5):
// a curse or a boost as the share of its stack's power its numbers move, a lost turn as that share of a stun, a ward
// as the health it keeps, a summon as its power. _best_spell_action (battle_ai_spell_choice.cpp) casts by it.

#include "aurelion_rules/port/battle_ai_rules.hpp"
#include "aurelion_rules/battle_hex.hpp"
#include "aurelion_rules/port/battle_damage_rules_ai.hpp"
#include "aurelion_rules/port/battle_footprint.hpp"
#include "aurelion_rules/port/spell_rules.hpp"

#include <algorithm>
#include <cmath>
#include <initializer_list>
#include <vector>

namespace aurelion::rules::port::battle_ai_rules {

using gd::array_value;
using gd::dict_value;
using gd::str;
namespace key = state::key;

namespace {

// A lasting effect's end round when it lasts the battle (SpellRules' TURN_EFFECT_ROUND_SENTINEL).
constexpr int64_t kBattleLongRound = 1000000;
// The most rounds a battle is counted ahead.
constexpr double kMostRounds = 5.0;
// What acting first is worth, as a share of one of the stack's blows.
constexpr double kFirstPlace = 0.2;
// The share of the stacks' hardest blows that land in a round, for the battle's length.
constexpr double kBlowsLanded = 0.5;

bool empty(const State &state, DictRef dict) {
	return gd::is_empty(state, dict);
}

Atom side_of(const State &state, DictRef stack) {
	return gd::string_field(state, stack, key::side, key::empty);
}

Atom battle_id_of(const State &state, DictRef stack) {
	return gd::string_field(state, stack, key::battle_id, key::empty);
}

bool one_of(Atom value, std::initializer_list<Atom> atoms) {
	for (const Atom atom : atoms) {
		if (value == atom) {
			return true;
		}
	}
	return false;
}

// holder.get(name) when it is a Dictionary, else {}.
DictRef dict_field(State &state, DictRef holder, Atom name) {
	Value found;
	return state.lookup(holder, str(name), found) && gd::is_dict(found) ? found.ref : state.new_dict();
}

double number(const State &state, DictRef holder, Atom name) {
	return static_cast<double>(gd::int_field(state, holder, name, 0));
}

// The fitted strength formula's terms. The scale is left out: every value is a share.
struct PowerTerms {
	double health = 0.3;
	double damage = 0.6;
	double per_defense = 0.075;
	double per_speed = 0.06;
	double per_initiative = 0.045;
	double ranged = 1.65;
};

// Read from the content once per content revision.
const PowerTerms &power_terms(State &state) {
	thread_local const State *read_for = nullptr;
	thread_local int64_t read_at = -1;
	thread_local PowerTerms terms;
	const int64_t revision = gd::content_revision(state);
	if (read_for != &state || read_at != revision) {
		terms = PowerTerms();
		const DictRef fitted = dict_field(state, gd::content_file(state, key::ai_hero_weights_path), key::army_power);
		terms.health = gd::float_field(state, fitted, key::power_health, terms.health);
		terms.damage = gd::float_field(state, fitted, key::power_damage, terms.damage);
		terms.per_defense = gd::float_field(state, fitted, key::power_per_defense, terms.per_defense);
		terms.per_speed = gd::float_field(state, fitted, key::power_per_speed, terms.per_speed);
		terms.per_initiative = gd::float_field(state, fitted, key::power_per_initiative, terms.per_initiative);
		terms.ranged = gd::float_field(state, fitted, key::ranged_power, terms.ranged);
		read_for = &state;
		read_at = revision;
	}
	return terms;
}

bool shoots(const State &state, DictRef stack) {
	return gd::bool_field(state, stack, key::ranged, false) && gd::int_field(state, stack, key::shots_remaining, 0) > 0;
}

// One creature's power by the formula, on the stack's own numbers.
double creature_power(State &state, const PowerTerms &terms, DictRef stack) {
	const double low = number(state, stack, key::min_damage);
	const double high = std::max(low, number(state, stack, key::max_damage));
	const double hp = std::max(1.0, number(state, stack, key::unit_hp));
	double per = gd::math_pow(state, hp, terms.health) * gd::math_pow(state, std::max(0.5, (low + high) * 0.5), terms.damage);
	per *= gd::math_exp(state, terms.per_defense * number(state, stack, key::defense) + terms.per_speed * number(state, stack, key::speed)
			+ terms.per_initiative * number(state, stack, key::initiative));
	return shoots(state, stack) ? per * terms.ranged : per;
}

// A living stack's numbers on the field.
struct Figures {
	DictRef stack = 0;
	Atom id = key::empty;
	Atom side = key::empty;
	double health = 0.0;
	double unit_hp = 1.0;
	double per = 0.0; // one creature's power
	double power = 0.0; // the stack's
	double out = 0.0; // its hardest blow on the other side
	DictRef mark = 0; // that blow's target
	double mark_rho = 0.0; // the target's power per point of health
	bool marked = false;
	double in = 0.0; // the other side's blows on it in a round, each stack striking one of its side's stacks
	double in_shots = 0.0; // the shots among them
	double hardest = 0.0; // the hardest blow on it
	bool shoots = false;
	bool melee = false;
	bool engaged = false;
	int64_t attack = 0;

	double rho() const {
		return per / unit_hp;
	}
};

// Both sides' figures for one cast decision. Index 0 is the caster's side.
struct Field {
	DictRef battle = 0;
	Atom side = key::empty;
	PowerTerms terms;
	std::vector<Figures> stacks;
	double power[2] = { 0.0, 0.0 };
	double health[2] = { 0.0, 0.0 };
	double output[2] = { 0.0, 0.0 };
	double count[2] = { 0.0, 0.0 };
	double defense[2] = { 0.0, 0.0 };
	double melee[2] = { 0.0, 0.0 };
	double rounds = 3.0;
	int64_t round = 1;
	bool spells_read[2] = { false, false };
	double spell_hit[2] = { 0.0, 0.0 };

	int at(Atom of) const {
		return of == side ? 0 : 1;
	}
	const Figures *find(Atom id) const {
		for (const Figures &figures : stacks) {
			if (figures.id == id) {
				return &figures;
			}
		}
		return nullptr;
	}
	double rho_of(int index) const {
		return power[index] / std::max(1.0, health[index]);
	}
	double side_count(Atom of) const {
		return std::max(1.0, count[at(of)]);
	}
	// The share of the battle's rounds an effect of these turns holds.
	double lasting(double turns) const {
		return std::clamp(turns, 0.0, rounds) / rounds;
	}
};

Field build_field(State &state, DictRef battle, Atom side) {
	Field field;
	field.battle = battle;
	field.side = side;
	field.terms = power_terms(state);
	field.round = gd::int_field(state, battle, key::round, 1);
	for (const Atom of : { side, _opposing_side(side) }) {
		for (const Value &stack : gd::items(state, array_value(_alive_stacks_for_side(state, battle, of)))) {
			if (!gd::is_dict(stack)) {
				continue;
			}
			Figures figures;
			figures.stack = stack.ref;
			figures.id = battle_id_of(state, stack.ref);
			figures.side = of;
			figures.health = std::max(0.0, number(state, stack.ref, key::total_health));
			figures.unit_hp = std::max(1.0, number(state, stack.ref, key::unit_hp));
			figures.per = creature_power(state, field.terms, stack.ref);
			figures.power = figures.per * figures.health / figures.unit_hp;
			figures.shoots = shoots(state, stack.ref);
			figures.melee = _fights_in_melee(state, stack.ref);
			figures.engaged = _stack_is_engaged(state, stack.ref, battle);
			figures.attack = gd::int_field(state, stack.ref, key::attack, 0);
			const int index = field.at(of);
			field.power[index] += figures.power;
			field.health[index] += figures.health;
			field.count[index] += 1.0;
			field.defense[index] += number(state, stack.ref, key::defense);
			field.melee[index] += figures.melee && !figures.shoots ? 1.0 : 0.0;
			field.stacks.push_back(figures);
		}
	}
	for (int index = 0; index < 2; ++index) {
		field.defense[index] /= std::max(1.0, field.count[index]);
	}
	// Each blow at most the health it strikes; a stack's own blow goes where it takes the most power.
	for (Figures &striker : field.stacks) {
		double best_taken = -1.0;
		for (Figures &struck : field.stacks) {
			if (striker.side == struck.side) {
				continue;
			}
			const int64_t distance = _attack_distance_for_action(state, striker.stack, struck.stack, battle, striker.shoots);
			const double estimate = static_cast<double>(std::max<int64_t>(0, _estimate_damage(state, striker.stack, struck.stack, battle, striker.shoots, false, distance)));
			const double blow = std::min(estimate, struck.health);
			if (blow * struck.rho() > best_taken) {
				best_taken = blow * struck.rho();
				striker.out = blow;
				striker.mark = struck.stack;
				striker.mark_rho = struck.rho();
				striker.marked = true;
			}
			struck.hardest = std::max(struck.hardest, blow);
			struck.in += blow;
			struck.in_shots += striker.shoots ? blow : 0.0;
		}
	}
	// Each stack of the other side strikes one of the stack's side.
	for (Figures &figures : field.stacks) {
		const double side_count = std::max(1.0, field.count[field.at(figures.side)]);
		figures.in /= side_count;
		figures.in_shots /= side_count;
		field.output[field.at(figures.side)] += figures.out;
	}
	// Not every stack lands its hardest blow every round (walks, waits, strike-backs): about half of them do.
	const double ours = field.health[1] / std::max(1.0, field.output[0] * kBlowsLanded);
	const double theirs = field.health[0] / std::max(1.0, field.output[1] * kBlowsLanded);
	field.rounds = std::clamp(std::min(ours, theirs), 1.0, kMostRounds);
	return field;
}

// What a cast moves, as power: what the caster's side keeps or gains (a loss negative) and what the other side loses.
struct Swing {
	double kept = 0.0;
	double taken = 0.0;

	void add(const Swing &other, double times) {
		kept += other.kept * times;
		taken += other.taken * times;
	}
};

// Power a stack's side gains (negative: loses).
void credit(const Field &field, Swing &swing, Atom side, double power) {
	if (side == field.side) {
		swing.kept += power;
	} else {
		swing.taken -= power;
	}
}

// Health a stack loses, at its power per point of health.
void hurt(const Field &field, Swing &swing, const Figures *figures, double damage) {
	if (figures != nullptr && damage > 0.0) {
		credit(field, swing, figures->side, -std::min(damage, figures->health) * figures->rho());
	}
}

// Health a stack gets back.
void heal(const Field &field, Swing &swing, const Figures *figures, double health) {
	if (figures != nullptr && health > 0.0) {
		credit(field, swing, figures->side, health * figures->rho());
	}
}

double share_of(const Field &field, const Swing &swing) {
	return swing.kept / std::max(1e-9, field.power[0]) + swing.taken / std::max(1e-9, field.power[1]);
}

// The turns an effect holds: its turns left, the battle when it lasts the battle, else to its end round.
double effect_turns(State &state, const Field &field, DictRef effect) {
	if (state.has(effect, str(key::turns_left))) {
		return std::max(1.0, number(state, effect, key::turns_left));
	}
	const int64_t expires = gd::int_field(state, effect, key::expires_after_round, 0);
	if (expires >= kBattleLongRound) {
		return field.rounds;
	}
	return expires > 0 ? std::max(1.0, static_cast<double>(expires - field.round + 1)) : 1.0;
}

// The damage a blow deals against a defense, as a multiple of the same blow with no attack edge.
double damage_scale(State &state, int64_t attack, int64_t defense) {
	return battle_damage_rules::attack_defense_multiplier(state, attack, defense);
}

// The share of a stack's power more attack gives it, against the other side's average defense.
double attack_gain(State &state, const Field &field, const Figures &stack, double attack) {
	const int64_t defense = static_cast<int64_t>(std::lround(field.defense[1 - field.at(stack.side)]));
	const int64_t more = static_cast<int64_t>(std::lround(attack));
	return gd::math_pow(state, damage_scale(state, stack.attack + more, defense) / damage_scale(state, stack.attack, defense), field.terms.damage) - 1.0;
}

double cohesion_out(int64_t cohesion) {
	return cohesion >= 8 ? 1.05 : (cohesion <= 3 ? 0.9 : 1.0);
}

double cohesion_in(int64_t cohesion) {
	return cohesion <= 3 ? 1.08 : (cohesion <= 5 ? 1.03 : 1.0);
}

// The share of a stack's power a set of stat changes moves (negative for a curse's): attack through the damage it
// deals, defense, speed and initiative by the formula's own terms (speed most for a melee stack that must still
// walk), cohesion through the damage it deals and takes at its thresholds, momentum at 4% damage a point.
double modifier_gain(State &state, const Field &field, const Figures &stack, DictRef modifiers) {
	if (empty(state, modifiers)) {
		return 0.0;
	}
	const PowerTerms &terms = field.terms;
	double log_gain = 0.0;
	const double attack = number(state, modifiers, key::attack);
	if (attack != 0.0) {
		log_gain += gd::math_log(state, std::max(0.05, 1.0 + attack_gain(state, field, stack, attack)));
	}
	log_gain += terms.per_defense * number(state, modifiers, key::defense);
	log_gain += terms.per_speed * number(state, modifiers, key::speed) * (stack.melee && !stack.shoots && !stack.engaged ? 1.0 : 0.25);
	log_gain += terms.per_initiative * number(state, modifiers, key::initiative);
	const int64_t cohesion = gd::int_field(state, modifiers, key::cohesion, 0);
	if (cohesion != 0) {
		const int64_t now = _stack_cohesion_total(state, stack.stack, field.battle);
		const int64_t then = std::clamp<int64_t>(now + cohesion, 0, 10);
		log_gain += terms.damage * gd::math_log(state, cohesion_out(then) / cohesion_out(now)) - 1.5 * gd::math_log(state, cohesion_in(then) / cohesion_in(now));
	}
	const double momentum = number(state, modifiers, key::momentum);
	if (momentum != 0.0) {
		log_gain += terms.damage * gd::math_log(state, std::max(0.1, 1.0 + 0.04 * momentum));
	}
	return gd::math_exp(state, log_gain) - 1.0;
}

// The share of each of its turns a status takes from a stack, by what the status does: a stun or a flight takes the
// turn, sleep about half of it (a blow wakes the stack), blindness a shooter's shots or 30% of a blow, confusion
// about half its blows; Rooted and Afraid stop a melee stack that must still walk but not one in the fight or a
// shooter; Slowed costs a walker some reach; acting last, no strike-back and Harried a little; Censure a gifted
// stack's abilities. The statuses that hurt or open the stack to more harm count by their numbers instead.
double status_turn_share(State &state, const Figures &stack, Atom status_id) {
	const bool walker = stack.melee && !stack.shoots;
	const bool closing = walker && !stack.engaged;
	if (status_id == key::status_stunned || status_id == key::status_fleeing) {
		return 1.0;
	}
	if (status_id == key::status_asleep) {
		return 0.5;
	}
	if (status_id == key::status_blinded) {
		return stack.shoots ? 0.9 : 0.3;
	}
	if (status_id == key::status_confused) {
		return walker ? 0.5 : 0.3;
	}
	if (status_id == key::status_rooted || status_id == key::status_afraid) {
		return closing ? 0.6 : (status_id == key::status_afraid && walker ? 0.1 : 0.05);
	}
	if (status_id == key::status_slowed) {
		return closing ? 0.15 : 0.0;
	}
	if (status_id == key::status_dazed || status_id == key::status_staggered) {
		return 0.15;
	}
	if (status_id == key::status_harried) {
		return 0.1;
	}
	if (status_id == key::status_censured) {
		bool gifted = false;
		for (const Value &ability : gd::field_items(state, stack.stack, str(key::abilities))) {
			gifted = gifted || gd::is_dict(ability);
		}
		return gifted ? 0.2 : 0.05;
	}
	return 0.0;
}

// The power a harmful effect takes from its stack over the turns it holds: its lost turns, its stat changes and its
// hurt.
double harm_power(State &state, const Field &field, const Figures &stack, DictRef effect) {
	if (empty(state, effect)) {
		return 0.0;
	}
	const Atom status_id = gd::string_field(state, effect, key::effect_id, key::empty);
	const double turns = effect_turns(state, field, effect);
	const double held = field.lasting(turns);
	const double turns_held = std::min(turns, field.rounds);
	const double by_turns = status_turn_share(state, stack, status_id) * stack.power * held;
	const double by_stats = -modifier_gain(state, field, stack, dict_field(state, effect, key::modifiers)) * stack.power * held;
	// Slowed's value is its speed loss.
	double taken = status_id == key::status_slowed ? std::max(by_turns, by_stats) : by_turns + by_stats;
	const DictRef mechanic = dict_field(state, effect, key::mechanic);
	const double hurt_each_turn = number(state, mechanic, key::curse_damage) + number(state, mechanic, key::poison_damage)
			+ number(state, mechanic, key::burning_damage) + number(state, mechanic, key::fever_damage);
	if (hurt_each_turn > 0.0) {
		taken += std::min(hurt_each_turn * turns_held, stack.health) * stack.rho();
	}
	const double more_taken = number(state, mechanic, key::damage_taken_pct);
	if (more_taken > 0.0) {
		taken += std::min(stack.in * turns_held * more_taken / 100.0, stack.health) * stack.rho();
	}
	const double melt = number(state, mechanic, key::defense_melt);
	if (melt > 0.0) {
		taken += stack.power * (1.0 - gd::math_exp(state, -field.terms.per_defense * melt)) * held;
	}
	return std::max(0.0, taken);
}

// The hardest damage spell the side's commander knows, at its power (0 with no commander or none).
double commander_spell_hit(State &state, Field &field, int index) {
	if (field.spells_read[index]) {
		return field.spell_hit[index];
	}
	field.spells_read[index] = true;
	const Atom of = index == 0 ? field.side : _opposing_side(field.side);
	const Value commander = gd::field(state, field.battle, of == key::enemy ? key::enemy_hero : key::player_commander_state);
	if (!gd::is_dict(commander) || empty(state, commander.ref)) {
		return 0.0;
	}
	const DictRef hero = gd::deep_duplicate_dict(state, commander.ref);
	double best = 0.0;
	for (const Value &spell : gd::items(state, array_value(spell_rules::known_spells(state, hero, key::battle)))) {
		if (!gd::is_dict(spell)) {
			continue;
		}
		const DictRef effect = dict_field(state, spell.ref, key::effect);
		if (gd::string_field(state, effect, key::type, key::empty) == key::damage_enemy) {
			best = std::max(best, number(state, effect, key::base_damage) + number(state, effect, key::power_scale) * static_cast<double>(spell_rules::spell_power(state, hero, spell.ref)));
		}
	}
	field.spell_hit[index] = best;
	return best;
}

// A helpful effect on a stack: the power its side keeps or gains, and the power it takes from the other side.
void help_value(State &state, Field &field, const Figures &stack, DictRef effect, Swing &swing) {
	if (empty(state, effect)) {
		return;
	}
	const double turns = effect_turns(state, field, effect);
	const double held = field.lasting(turns);
	const double n = std::min(turns, field.rounds);
	const int other = 1 - field.at(stack.side);
	const double side_count = field.side_count(stack.side);
	const double missing = static_cast<double>(_stack_missing_health(state, stack.stack));
	const double rho = stack.rho();
	const double mark_rho = stack.marked ? stack.mark_rho : field.rho_of(other);
	double kept = stack.power * modifier_gain(state, field, stack, dict_field(state, effect, key::modifiers)) * held;
	double dealt = 0.0;
	Value immunities;
	if (state.lookup(effect, str(key::status_immunity_ids), immunities) && gd::is_array(immunities) && state.array_size(immunities.ref) > 0) {
		kept += stack.power * 0.02 * held;
	}
	const DictRef mechanic = dict_field(state, effect, key::mechanic);
	const auto amount = [&](Atom name) { return number(state, mechanic, name); };
	if (amount(key::plate) > 0.0) {
		kept += std::min(amount(key::plate), stack.in * n) * rho;
	}
	if (amount(key::regrowth) > 0.0) {
		// Without a raise it mends only the top creature's wound.
		const bool raises = amount(key::regrowth_raise) > 0.0;
		const double room = raises ? std::max(0.0, number(state, stack.stack, key::base_count) * stack.unit_hp - stack.health) : missing;
		const double later = raises ? stack.in : std::min(stack.in, stack.unit_hp * 0.5);
		kept += (std::min(amount(key::regrowth), room) + std::min(amount(key::regrowth), later) * std::max(0.0, n - 1.0)) * rho;
	}
	if (amount(key::thorns) > 0.0) {
		dealt += amount(key::thorns) * field.melee[other] / side_count * n * field.rho_of(other);
	}
	if (amount(key::lifesteal_pct) > 0.0) {
		kept += std::min(amount(key::lifesteal_pct) / 100.0 * stack.out * n, missing + stack.in * std::max(0.0, n - 1.0)) * rho;
	}
	if (amount(key::momentum_per_blow) > 0.0 && stack.out > 0.0) {
		// Each blow it lands builds momentum for the next.
		const double cap = amount(key::momentum_cap) > 0.0 ? amount(key::momentum_cap) : 4.0;
		double bonus = 0.0;
		for (int blow = 1; blow < static_cast<int>(n); ++blow) {
			bonus += std::min(cap, amount(key::momentum_per_blow) * blow) * 0.04;
		}
		kept += stack.power * (gd::math_pow(state, 1.0 + bonus / std::max(1.0, n), field.terms.damage) - 1.0) * held;
	}
	if (amount(key::stationary_attack) > 0.0 && stack.out > 0.0) {
		kept += stack.power * attack_gain(state, field, stack, amount(key::stationary_attack)) * held * (stack.shoots || stack.engaged ? 1.0 : 0.3);
	}
	if (amount(key::shot_shield) > 0.0) {
		kept += std::min(stack.in_shots * n, stack.health) * rho;
	}
	const bool spells_matter = amount(key::reflect_spell) > 0.0 || amount(key::spell_shield) > 0.0 || amount(key::half_ranged) > 0.0;
	const double spell_hit = spells_matter ? commander_spell_hit(state, field, other) : 0.0;
	if (amount(key::reflect_spell) > 0.0 || amount(key::spell_shield) > 0.0) {
		// The other side's hero aims a spell at it about once in as many rounds as its side has stacks.
		const double aimed = std::min(1.0, n / side_count);
		kept += aimed * std::min(spell_hit, stack.health) * rho;
		if (amount(key::reflect_spell) > 0.0) {
			dealt += aimed * spell_hit * field.rho_of(other);
		}
	}
	if (amount(key::on_hit_burning) > 0.0 && stack.out > 0.0) {
		const double burning = std::min(amount(key::burning_turns) > 0.0 ? amount(key::burning_turns) : 2.0, field.rounds);
		const double hits = amount(key::on_hit_once) > 0.0 ? 1.0 : std::min(n, 2.0);
		dealt += hits * amount(key::on_hit_burning) * burning * mark_rho;
	}
	if (amount(key::damage_cap_pct) > 0.0) {
		const double over = std::max(0.0, stack.hardest - amount(key::damage_cap_pct) / 100.0 * stack.health);
		kept += std::min(over * field.count[other] / side_count * 0.5 * n, stack.health) * rho;
	}
	if (amount(key::death_save_pct) > 0.0) {
		const double falls = std::min(1.0, stack.in * n / std::max(1.0, stack.health));
		kept += falls * std::max(1.0, number(state, stack.stack, key::base_count) * amount(key::death_save_pct) / 100.0) * stack.per * 0.5;
	}
	if (amount(key::deathless) > 0.0) {
		const double hurt_by = stack.in * n;
		const double mended = amount(key::deathless_heal);
		kept += (hurt_by >= stack.health ? mended + (hurt_by - stack.health) * 0.5 : std::min(mended, missing + hurt_by)) * rho;
	}
	if (amount(key::cohesion_lock) > 0.0) {
		kept += stack.power * (stack.engaged ? 0.02 : 0.005) * held;
	}
	if (amount(key::absorb_one) > 0.0) {
		const double struck = std::min(1.0, stack.in * n / std::max(1.0, stack.hardest));
		kept += struck * std::min(stack.hardest * 0.7, stack.health) * rho;
		if (amount(key::absorb_attack) > 0.0) {
			kept += stack.power * attack_gain(state, field, stack, amount(key::absorb_attack)) / field.rounds;
		}
	}
	if (amount(key::invulnerable) > 0.0) {
		// Nothing hurts it, and it strikes nothing.
		kept += std::min(stack.in * n, stack.health) * rho;
		dealt -= stack.out * n * mark_rho;
	}
	if (amount(key::half_ranged) > 0.0) {
		kept += std::min(0.5 * (stack.in_shots + spell_hit / side_count) * n, stack.health) * rho;
	}
	if (amount(key::act_first_next) > 0.0) {
		dealt += kFirstPlace * stack.out * mark_rho;
	}
	if (amount(key::pierce_blows) > 0.0 && stack.marked) {
		const int64_t defense = gd::int_field(state, stack.mark, key::defense, 0);
		const double gain = damage_scale(state, stack.attack, 0) / damage_scale(state, stack.attack, defense) - 1.0;
		dealt += std::min(amount(key::pierce_blows), field.rounds) * stack.out * std::max(0.0, gain) * mark_rho;
	}
	const bool walker = stack.melee && !stack.shoots;
	if (amount(key::phase) > 0.0 && walker && !stack.engaged) {
		dealt += kFirstPlace * stack.out * mark_rho;
	}
	if (amount(key::no_strike_back) > 0.0 && walker && stack.marked) {
		const double back = static_cast<double>(std::max<int64_t>(0, _estimate_damage(state, stack.mark, stack.stack, field.battle, false, true, 1)));
		kept += std::min(back, stack.health) * rho;
	}
	if (amount(key::act_next) > 0.0) {
		// Its turn comes sooner, not twice.
		dealt += 1.5 * kFirstPlace * stack.out * mark_rho;
	}
	if (amount(key::double_strike) > 0.0 && walker) {
		dealt += (stack.engaged ? 1.0 : 0.5) * stack.out * mark_rho;
		if (amount(key::staggered_after) > 0.0) {
			kept -= status_turn_share(state, stack, key::status_staggered) * stack.power * field.lasting(amount(key::staggered_after));
		}
	}
	if (amount(key::extra_turn) > 0.0) {
		dealt += stack.out * mark_rho;
	}
	if (amount(key::loss_return_pct) > 0.0) {
		kept += amount(key::loss_return_pct) / 100.0 * std::min(stack.in * n, stack.health) * rho;
	}
	if (amount(key::backlash_pct) > 0.0) {
		kept -= std::min(amount(key::backlash_pct) / 100.0 * stack.health * n, stack.health) * rho;
	}
	credit(field, swing, stack.side, kept);
	credit(field, swing, other == 0 ? field.side : _opposing_side(field.side), -dealt);
}

// Lifting harmful effects from a stack gives back what they would still take.
void lift_value(State &state, Field &field, const Figures &stack, const Value &effect_ids, Swing &swing) {
	if (!gd::is_array(effect_ids)) {
		return;
	}
	for (const Value &id : gd::items(state, effect_ids)) {
		const DictRef effect = spell_rules::stack_status_effect(state, stack.stack, field.battle, gd::to_string(id));
		credit(field, swing, stack.side, harm_power(state, field, stack, effect));
	}
}

// A harmful status on an enemy stack, at the odds it holds.
void curse_value(State &state, Field &field, const Figures *stack, DictRef battle, DictRef spell, DictRef payload, Swing &swing) {
	if (stack == nullptr || empty(state, payload)) {
		return;
	}
	const Atom status_id = gd::string_field(state, payload, key::effect_id, key::empty);
	if (spell_rules::target_is_immune_to_status(state, stack->stack, battle, status_id) || spell_rules::has_effect_id(state, stack->stack, battle, status_id)) {
		return;
	}
	const double holds = static_cast<double>(std::max<int64_t>(0, 100 - spell_rules::control_resistance_pct(state, battle, stack->stack, spell))) / 100.0;
	credit(field, swing, stack->side, -harm_power(state, field, *stack, payload) * holds);
}

// The spell's status at its power against the stack.
DictRef status_at(State &state, DictRef hero, DictRef battle, DictRef stack, DictRef spell) {
	return spell_rules::_status_effect_from_spell_effect_at(state, spell, battle, hero, spell_rules::spell_power_against(state, hero, battle, stack, spell));
}

// What the stacks a cast reaches beyond its target add: hits (on its own stacks too), heals and effects. A harmful
// effect on a reached enemy stack counts at the odds it holds, not the draw the cast will make.
void reach_value(State &state, Field &field, DictRef hero, DictRef battle, DictRef target, DictRef spell, int64_t main_damage, Swing &swing) {
	if (empty(state, target)) {
		return;
	}
	const DictRef result = state.new_dict();
	state.set(result, str(key::ok), gd::bool_value(true));
	state.set(result, str(key::damage), gd::int_value(main_damage));
	spell_rules::add_reach_resolutions(state, hero, battle, target, spell, result, Value());
	for (const Value &sub : gd::field_items(state, result, str(key::extra_resolutions))) {
		if (!gd::is_dict(sub)) {
			continue;
		}
		const Figures *reached = field.find(gd::string_field(state, sub.ref, key::target_battle_id, key::empty));
		if (reached == nullptr) {
			continue;
		}
		const Atom type = gd::string_field(state, sub.ref, key::resolution_type, key::empty);
		if (type == key::damage) {
			hurt(field, swing, reached, number(state, sub.ref, key::damage));
		} else if (type == key::recover_effect) {
			heal(field, swing, reached, std::min(number(state, sub.ref, key::recovery_amount), static_cast<double>(_recovery_room(state, reached->stack, spell))));
			help_value(state, field, *reached, dict_field(state, sub.ref, key::effect), swing);
			lift_value(state, field, *reached, gd::field(state, sub.ref, key::cleanse_status_ids), swing);
		} else if (type == key::effect) {
			if (reached->side == field.side) {
				help_value(state, field, *reached, dict_field(state, sub.ref, key::effect), swing);
			} else {
				DictRef payload = dict_field(state, sub.ref, key::effect);
				if (empty(state, payload)) {
					payload = status_at(state, hero, battle, reached->stack, spell);
				}
				curse_value(state, field, reached, battle, spell, payload, swing);
				curse_value(state, field, reached, battle, spell, dict_field(state, sub.ref, key::follow_effect), swing);
			}
		}
	}
}

// A conjured stack: its power for the rounds it stands.
void summon_value(State &state, Field &field, DictRef summon, Swing &swing) {
	if (empty(state, summon)) {
		return;
	}
	const double unit_hp = std::max(1.0, number(state, summon, key::unit_hp));
	double power = creature_power(state, field.terms, summon) * std::max(0.0, number(state, summon, key::total_health)) / unit_hp;
	const int64_t until = gd::int_field(state, summon, key::conjured_until_round, field.round + static_cast<int64_t>(field.rounds));
	power *= field.lasting(static_cast<double>(std::max<int64_t>(1, until - field.round)));
	// One that cannot move strikes only what comes beside it.
	if (gd::bool_field(state, summon, key::immobile, false)) {
		power *= 0.5;
	}
	credit(field, swing, field.side, power);
}

// The candidate's destination hex or stack ({} when it has none).
DictRef destination_of(State &state, DictRef candidate) {
	return dict_field(state, candidate, key::destination);
}

namespace hex = battle_hex;

hex::PlacedBody placed_of(const State &state, DictRef stack) {
	hex::PlacedBody placed;
	battle_footprint::placed_columns(state, stack, placed.q, placed.r, placed.tail_q);
	return placed;
}

// Hexes from a one-hex spot to a stack's body.
int64_t spot_distance(const State &state, int64_t id, DictRef stack) {
	return hex::body_distance(id, hex::Body{ 1, -1 }, placed_of(state, stack));
}

bool body_on(const State &state, DictRef stack, const std::vector<int64_t> &cells) {
	for (const int64_t id : cells) {
		if (spot_distance(state, id, stack) == 0) {
			return true;
		}
	}
	return false;
}

// The hexes of the pick a ground cast names.
std::vector<int64_t> picked_cells(State &state, DictRef battle, DictRef spell, DictRef hero, DictRef destination) {
	std::vector<int64_t> cells;
	const int64_t q = gd::int_field(state, destination, key::q, -1);
	const int64_t r = gd::int_field(state, destination, key::r, -1);
	for (const Value &pick : gd::items(state, array_value(spell_rules::ground_pick_shapes(state, battle, spell, hero)))) {
		if (!gd::is_dict(pick) || gd::int_field(state, pick.ref, key::q, -2) != q || gd::int_field(state, pick.ref, key::r, -2) != r) {
			continue;
		}
		for (const Value &cell : gd::field_items(state, pick.ref, str(key::cells))) {
			const int64_t cell_q = gd::is_dict(cell) ? gd::int_field(state, cell.ref, key::q, -1) : -1;
			const int64_t cell_r = gd::is_dict(cell) ? gd::int_field(state, cell.ref, key::r, -1) : -1;
			if (_hex_in_bounds(cell_q, cell_r)) {
				cells.push_back(cell_q * hex::kRows + cell_r);
			}
		}
		break;
	}
	return cells;
}

// Prism Array's firings: one after each later damage spell of the side, at most once a round, while the mana left
// pays for the cheapest of them (at most four).
double prism_firings(State &state, DictRef hero, DictRef spell, DictRef sample) {
	int64_t cheapest = 0;
	for (const Value &known : gd::items(state, array_value(spell_rules::known_spells(state, hero, key::battle)))) {
		const Value categories = gd::is_dict(known) ? gd::field(state, known.ref, key::role_categories) : Value();
		if (gd::is_dict(known) && gd::string_field(state, known.ref, key::id, key::empty) != gd::string_field(state, spell, key::id, key::empty)
				&& gd::is_array(categories) && gd::array_has(state, categories.ref, str(key::damage))) {
			const int64_t cost = std::max<int64_t>(1, spell_rules::adjusted_spell_mana_cost(state, hero, known));
			cheapest = cheapest == 0 ? cost : std::min(cheapest, cost);
		}
	}
	if (cheapest == 0) {
		return 0.0;
	}
	const int64_t own_cost = spell_rules::adjusted_spell_mana_cost(state, hero, dict_value(spell));
	const int64_t later_rounds = std::min<int64_t>(4, gd::int_field(state, sample, key::rounds, 1) - 1);
	int64_t paid = 0;
	while (paid < later_rounds && spell_rules::_has_mana(state, hero, own_cost + (paid + 1) * cheapest)) {
		paid += 1;
	}
	return static_cast<double>(paid);
}

// A hex spell on its picked hexes: Thicket Snare's Rooted on the enemy stacks it catches, murk's silenced shooters
// and stacks kept from shots, mire's lost speed, a dome's stacks kept from shots and spells, a grove's heal and
// defense, Prism Array's later firings. False for the ground still weighed by its plan's score (fire, brambles,
// seeds, pillars, walls and lines, which act on the walks they meet).
bool ground_swing(State &state, Field &field, DictRef battle, DictRef active_stack, DictRef hero, DictRef spell, DictRef candidate, Swing &swing) {
	const Atom ground = gd::string_field(state, dict_field(state, spell, key::effect), key::ground, key::empty);
	if (!one_of(ground, { key::snare, key::murk, key::mire, key::dome, key::grove, key::prism })) {
		return false;
	}
	const std::vector<int64_t> cells = picked_cells(state, battle, spell, hero, destination_of(state, candidate));
	if (cells.empty()) {
		return true;
	}
	const DictRef sample = spell_rules::ground_entry_for_cast(state, hero, battle, spell, side_of(state, active_stack), state.new_array());
	const double turns = std::max(1.0, number(state, sample, key::rounds));
	const double held = field.lasting(turns);
	const double n = std::min(turns, field.rounds);
	if (ground == key::prism) {
		const double firings = prism_firings(state, hero, spell, sample);
		const Figures *nearest = nullptr;
		int64_t nearest_distance = 0;
		for (const Figures &figures : field.stacks) {
			const int64_t distance = spot_distance(state, cells.front(), figures.stack);
			if (figures.side != field.side && (nearest == nullptr || distance < nearest_distance)) {
				nearest = &figures;
				nearest_distance = distance;
			}
		}
		if (nearest != nullptr && firings > 0.0) {
			// Each firing comes a round later than the one before.
			double later = 0.0;
			for (int firing = 1; firing <= static_cast<int>(firings); ++firing) {
				later += std::max(0.0, field.rounds - firing) / field.rounds;
			}
			hurt(field, swing, nearest, static_cast<double>(spell_rules::ground_damage_against(state, battle, sample, nearest->stack)) * later);
		}
		return true;
	}
	const int other = 1;
	const double spell_hit = ground == key::dome ? commander_spell_hit(state, field, other) : 0.0;
	for (const Figures &figures : field.stacks) {
		if (!body_on(state, figures.stack, cells)) {
			continue;
		}
		const bool own = figures.side == field.side;
		if (ground == key::snare) {
			if (!own) {
				curse_value(state, field, &figures, battle, spell, status_at(state, hero, battle, figures.stack, spell), swing);
			}
		} else if (ground == key::murk) {
			if (spell_rules::in_murk(state, battle, figures.stack)) {
				continue;
			}
			// Shooters in it do not shoot (most of them while they stay), and nothing in it is shot.
			if (figures.shoots) {
				credit(field, swing, figures.side, -0.6 * figures.power * held);
			}
			credit(field, swing, figures.side, std::min(figures.in_shots * n, figures.health) * figures.rho());
		} else if (ground == key::mire) {
			if (spell_rules::in_mire(state, battle, figures.stack)) {
				continue;
			}
			const double speed = number(state, figures.stack, key::speed);
			const double walks = figures.melee && !figures.shoots && !figures.engaged ? 1.0 : 0.25;
			credit(field, swing, figures.side, figures.power * (gd::math_exp(state, -field.terms.per_speed * speed * 0.5 * walks) - 1.0) * held);
		} else if (ground == key::dome) {
			if (spell_rules::in_dome(state, battle, figures.stack)) {
				continue;
			}
			// Kept from shots and spells from outside it; the other side's stacks under it count against.
			const double kept_from = own ? figures.in_shots + spell_hit / field.side_count(figures.side) : figures.in_shots;
			credit(field, swing, figures.side, std::min(kept_from * n, figures.health) * figures.rho());
		} else if (ground == key::grove && own) {
			const double defense = number(state, sample, key::defense);
			if (static_cast<double>(spell_rules::grove_defense(state, battle, figures.stack)) >= defense) {
				continue;
			}
			const double mended = number(state, sample, key::heal);
			const double missing = static_cast<double>(_stack_missing_health(state, figures.stack));
			heal(field, swing, &figures, std::min(mended, missing) + std::min(mended, figures.in) * std::max(0.0, n - 1.0));
			credit(field, swing, figures.side, figures.power * (gd::math_exp(state, field.terms.per_defense * defense) - 1.0) * held);
		}
	}
	return true;
}

// The swing of one cast; false for a kind still weighed by its plan's score.
bool cast_swing(State &state, Field &field, DictRef battle, DictRef active_stack, DictRef hero, DictRef spell, DictRef candidate, Swing &swing, int depth) {
	const DictRef behavior = spell_rules::battle_spell_behavior(state, spell);
	const Atom type = gd::string_field(state, behavior, key::effect_type, key::empty);
	const DictRef effect = dict_field(state, spell, key::effect);
	const DictRef target = _stack_by_battle_id(state, battle, gd::string_field(state, candidate, key::target_battle_id, key::empty));
	const Figures *aimed = empty(state, target) ? nullptr : field.find(battle_id_of(state, target));
	if (type == key::damage_enemy) {
		if (aimed == nullptr) {
			return true;
		}
		const int64_t damage = gd::int_field(state, spell_rules::battle_spell_damage_projection(state, hero, battle, target, spell), key::final_damage, 0);
		hurt(field, swing, aimed, static_cast<double>(damage));
		curse_value(state, field, aimed, battle, spell, status_at(state, hero, battle, target, spell), swing);
		// Heat: the burst when the stack reaches three.
		const int64_t heat = gd::int_field(state, effect, key::heat, 0);
		if (heat > 0 && gd::int_field(state, target, key::spell_heat, 0) + heat >= 3) {
			hurt(field, swing, aimed, static_cast<double>(spell_rules::heat_burst_damage(spell_rules::spell_power_against(state, hero, battle, target, spell))));
		}
		reach_value(state, field, hero, battle, target, spell, damage, swing);
		return true;
	}
	if (type == key::control_enemy) {
		if (aimed == nullptr) {
			return true;
		}
		const int64_t power = spell_rules::spell_power_against(state, hero, battle, target, spell);
		DictRef payload = spell_rules::_status_effect_from_spell_effect_at(state, spell, battle, hero, power);
		// Grasp of the Deep stuns a stack that is already Rooted.
		Value stun;
		if (state.lookup(effect, str(key::rooted_stun_status), stun) && gd::is_dict(stun) && spell_rules::has_effect_id(state, target, battle, key::status_rooted)) {
			payload = spell_rules::_status_payload(state, spell, stun, battle, hero, power, 0);
		}
		curse_value(state, field, aimed, battle, spell, payload, swing);
		Value follow;
		if (state.lookup(effect, str(key::follow_status_effect), follow) && gd::is_dict(follow)) {
			curse_value(state, field, aimed, battle, spell, spell_rules::_status_payload(state, spell, follow, battle, hero, power, gd::int_field(state, payload, key::turns_left, 1)), swing);
		}
		reach_value(state, field, hero, battle, target, spell, 0, swing);
		return true;
	}
	if (type == key::doom_enemy) {
		if (aimed == nullptr) {
			return true;
		}
		// It lands after the stack's turns, so it takes their power only for the rounds after.
		const double turns = std::max(1.0, number(state, effect, key::duration_rounds));
		const double later = std::max(0.0, field.rounds - turns) / field.rounds;
		Swing doom;
		if (state.has(effect, str(key::doom_pct))) {
			const int64_t pct = spell_rules::deaths_door_pct(state, hero, battle, spell, target);
			const int64_t lost = std::max<int64_t>(1, (_alive_count(state, target) * pct + 50) / 100);
			hurt(field, doom, aimed, static_cast<double>(lost) * aimed->unit_hp);
		} else {
			hurt(field, doom, aimed, number(state, spell_rules::battle_spell_damage_projection(state, hero, battle, target, spell), key::final_damage));
		}
		swing.add(doom, later);
		return true;
	}
	if (type == key::free_volley) {
		const int64_t pct = gd::int_field(state, effect, key::volley_pct, 0) + gd::int_field(state, effect, key::volley_pct_power_scale, 0) * spell_rules::spell_power(state, hero, spell);
		double dealt = 0.0;
		for (const Value &id : gd::items(state, array_value(spell_rules::volley_shooters(state, battle, side_of(state, active_stack), target)))) {
			const DictRef shooter = _stack_by_battle_id(state, battle, gd::to_string(id));
			if (!empty(state, shooter)) {
				dealt += static_cast<double>(spell_rules::volley_shot_damage(state, battle, shooter, target, pct));
			}
		}
		hurt(field, swing, aimed, dealt);
		return true;
	}
	if (type == key::damage_around) {
		if (aimed == nullptr) {
			return true;
		}
		double total = 0.0;
		for (const Value &enemy : gd::items(state, array_value(spell_rules::enemies_beside(state, battle, target)))) {
			const Figures *beside = gd::is_dict(enemy) ? field.find(battle_id_of(state, enemy.ref)) : nullptr;
			if (beside == nullptr) {
				continue;
			}
			const double damage = std::min(number(state, spell_rules::battle_spell_damage_projection(state, hero, battle, enemy.ref, spell), key::final_damage), beside->health);
			hurt(field, swing, beside, damage);
			total += damage;
		}
		const double drawn = total * static_cast<double>(gd::int_field(state, effect, key::heal_pct, 100)) / 100.0;
		heal(field, swing, aimed, std::min(drawn, static_cast<double>(spell_rules::battle_spell_recoverable_health(state, target))));
		return true;
	}
	if (one_of(type, { key::defense_buff, key::initiative_buff, key::attack_buff, key::ally_effect })) {
		if (aimed == nullptr) {
			return true;
		}
		help_value(state, field, *aimed, spell_rules::_effect_payload_for(state, spell, effect, battle, hero, target), swing);
		reach_value(state, field, hero, battle, target, spell, 0, swing);
		return true;
	}
	if (type == key::recover_ally) {
		if (aimed == nullptr) {
			return true;
		}
		heal(field, swing, aimed, static_cast<double>(std::min(_battle_recovery_amount(state, hero, spell), _recovery_room(state, target, spell))));
		if (!empty(state, spell_rules::battle_spell_modifiers(state, spell)) || state.has(effect, str(key::mechanic))) {
			help_value(state, field, *aimed, spell_rules::_effect_payload(state, spell, effect, battle, hero), swing);
		}
		const int64_t statuses = gd::int_field(state, effect, key::cleanse_statuses, 0);
		if (statuses > 0) {
			lift_value(state, field, *aimed, array_value(spell_rules::newest_status_ids(state, target, battle, statuses)), swing);
		}
		reach_value(state, field, hero, battle, target, spell, 0, swing);
		return true;
	}
	if (type == key::cleanse_ally) {
		if (aimed == nullptr) {
			return true;
		}
		if (spell_rules::cleanse_takes_any_harm(state, effect)) {
			const int64_t count = spell_rules::spell_effect_count(state, spell, spell_rules::spell_power(state, hero, spell));
			lift_value(state, field, *aimed, array_value(spell_rules::newest_effect_ids(state, target, battle, false, count)), swing);
		} else {
			lift_value(state, field, *aimed, array_value(_normalize_string_array(state, gd::field(state, effect, key::cleanse_effect_ids))), swing);
		}
		return true;
	}
	if (type == key::dispel_enemy) {
		if (aimed == nullptr) {
			return true;
		}
		// Taking the target's helpful effects off undoes what they would still give it.
		const int64_t count = spell_rules::spell_effect_count(state, spell, spell_rules::spell_power_against(state, hero, battle, target, spell));
		Swing undone;
		for (const Value &id : gd::items(state, array_value(spell_rules::newest_effect_ids(state, target, battle, true, count)))) {
			help_value(state, field, *aimed, spell_rules::stack_status_effect(state, target, battle, gd::to_string(id)), undone);
		}
		swing.add(undone, -1.0);
		return true;
	}
	if (type == key::temp_creatures) {
		// Budding's creatures stand for the battle.
		heal(field, swing, aimed, static_cast<double>(_battle_recovery_amount(state, hero, spell)));
		return true;
	}
	if (type == key::conjure) {
		const Atom side = side_of(state, active_stack);
		const Atom kind = gd::string_field(state, effect, key::conjure, key::empty);
		if (spell_rules::conjures_on_hex(state, spell)) {
			summon_value(state, field, spell_rules::conjured_stack_for_cast(state, hero, battle, spell, side, destination_of(state, candidate), state.new_dict()), swing);
		} else if (kind == key::clone) {
			if (!empty(state, target)) {
				summon_value(state, field, spell_rules::conjured_stack_for_cast(state, hero, battle, spell, side, spell_rules::decoy_cell(state, battle, target), target), swing);
			}
		} else if (kind == key::elder) {
			summon_value(state, field, spell_rules::conjured_stack_for_cast(state, hero, battle, spell, side, spell_rules::elder_cell(state, battle, spell, side), state.new_dict()), swing);
		} else if (kind == key::risen_all) {
			for (const Value &risen : gd::items(state, array_value(spell_rules::risen_host_for_cast(state, hero, battle, spell, side)))) {
				if (gd::is_dict(risen)) {
					summon_value(state, field, risen.ref, swing);
				}
			}
		} else if (aimed != nullptr) {
			// A decoy draws about half of the hardest blow meant for its stack.
			heal(field, swing, aimed, std::min(aimed->hardest * 0.5, aimed->health));
		}
		return true;
	}
	if (type == key::battle_aura) {
		const Atom aura = gd::string_field(state, effect, key::aura, key::empty);
		const int64_t power = spell_rules::spell_power(state, hero, spell);
		const double turns = static_cast<double>(spell_rules::spell_effect_turns(state, hero, effect, spell, key::buff, power));
		if (aura == key::sun) {
			// Second Sun: every enemy stack burns at the end of each round, for the rest of the battle.
			const Atom side = side_of(state, active_stack);
			const int64_t against = std::max<int64_t>(0, power - spell_rules::opposing_side_knowledge(state, battle, side));
			const double raw = static_cast<double>(spell_rules::_battle_spell_damage_at(state, hero, spell, state.new_dict(), against));
			for (const Figures &figures : field.stacks) {
				if (figures.side != field.side) {
					const double resisted = static_cast<double>(100 - spell_rules::spell_damage_resistance_pct(state, battle, figures.stack, spell)) / 100.0;
					hurt(field, swing, &figures, raw * resisted * field.rounds);
				}
			}
		} else if (aura == key::noon) {
			// Eternal Noon: first place for each of the side's stacks, each round it holds.
			for (const Figures &figures : field.stacks) {
				if (figures.side == field.side) {
					swing.taken += kFirstPlace * figures.out * figures.mark_rho * std::min(turns, field.rounds);
					swing.kept += figures.power * 0.02 * field.lasting(turns);
				}
			}
		} else if (aura == key::green_return) {
			// Green Return: each fallen stack of the side grows back with its share of its starting creatures.
			const Atom side = side_of(state, active_stack);
			const int64_t pct = spell_rules::green_return_pct(state, hero, spell);
			for (const Value &stack : gd::field_items(state, battle, str(key::stacks))) {
				if (!gd::is_dict(stack) || side_of(state, stack.ref) != side || _alive_count(state, stack.ref) > 0 || spell_rules::is_conjured(state, stack.ref)
						|| gd::bool_field(state, stack.ref, key::green_returned, false)) {
					continue;
				}
				const int64_t base_count = gd::int_field(state, stack.ref, key::base_count, 0);
				if (base_count > 0) {
					swing.kept += static_cast<double>(std::max<int64_t>(1, base_count * pct / 100)) * creature_power(state, field.terms, stack.ref);
				}
			}
		} else if (aura == key::hollow_crown) {
			return false;
		} else {
			// Watchful Light: each round the side's most wounded stack heals.
			const double mended = static_cast<double>(_battle_recovery_amount(state, hero, spell));
			double most_missing = 0.0;
			double wounds = 0.0;
			for (const Figures &figures : field.stacks) {
				if (figures.side == field.side) {
					most_missing = std::max(most_missing, static_cast<double>(spell_rules::battle_spell_recoverable_health(state, figures.stack)));
					wounds += figures.in;
				}
			}
			const double later = std::min(mended, wounds / field.side_count(field.side)) * std::max(0.0, std::min(turns, field.rounds) - 1.0);
			swing.kept += (std::min(mended, most_missing) + later) * field.rho_of(0);
		}
		return true;
	}
	if (type == key::charm_enemy) {
		const Figures *victim = field.find(gd::string_field(state, destination_of(state, candidate), key::battle_id, key::empty));
		if (victim != nullptr && !empty(state, target)) {
			const int64_t pct = spell_rules::charm_damage_pct(state, hero, battle, spell, target);
			hurt(field, swing, victim, static_cast<double>(spell_rules::charm_blow_damage(state, battle, target, victim->stack, pct)));
		}
		return true;
	}
	if (type == key::rewind) {
		if (aimed == nullptr) {
			return true;
		}
		// Hour Ledger: the health of the round it steps back to.
		double gain = 0.0;
		for (const Value &cell : gd::items(state, array_value(spell_rules::rewind_destinations(state, battle, target, spell_rules::rewind_reach(state, hero, spell))))) {
			if (gd::is_dict(cell)) {
				gain = std::max(gain, number(state, cell.ref, key::total_health) - aimed->health);
			}
		}
		heal(field, swing, aimed, gain);
		return true;
	}
	if (type == key::recast && depth == 0) {
		// Echo: the side's last spell again, at the echo's power, on what it named.
		const DictRef last = spell_rules::last_cast_of(state, battle, side_of(state, active_stack));
		const Atom inner_id = gd::string_field(state, last, key::spell_id, key::empty);
		const DictRef inner = gd::content_row(state, state::ContentTable::Spell, inner_id);
		if (empty(state, inner) || !spell_rules::echo_scores_inner(state, inner)) {
			return true;
		}
		const DictRef inner_target = spell_rules::echo_target(state, battle, active_stack, inner, last);
		if (empty(state, inner_target)) {
			return true;
		}
		const DictRef inner_candidate = state.new_dict();
		state.set(inner_candidate, str(key::spell_id), str(inner_id));
		state.set(inner_candidate, str(key::target_battle_id), str(battle_id_of(state, inner_target)));
		return cast_swing(state, field, battle, active_stack, spell_rules::echo_caster(state, hero, spell, inner_id), inner, inner_candidate, swing, depth + 1);
	}
	if (type == key::ground_effect) {
		return ground_swing(state, field, battle, active_stack, hero, spell, candidate, swing);
	}
	// The moves, swaps and pairs, Uproot and Goad: their plan's score.
	return false;
}

// The share of the armies' power a cast moves.
double cast_share(State &state, Field &field, DictRef battle, DictRef active_stack, DictRef enemy_hero, DictRef candidate) {
	const DictRef spell = gd::content_row(state, state::ContentTable::Spell, gd::string_field(state, candidate, key::spell_id, key::empty));
	if (empty(state, spell)) {
		return 0.0;
	}
	Swing swing;
	if (cast_swing(state, field, battle, active_stack, enemy_hero, spell, candidate, swing, 0)) {
		return share_of(field, swing);
	}
	// A plan's score in the damage spells' points, where a whole stack's health is spell_damage_share of them.
	const double stacks = std::max(1.0, (field.count[0] + field.count[1]) * 0.5);
	return std::max(0.0, gd::float_field(state, candidate, key::score, 0.0)) / (std::max(1.0, _w(state, key::spell_damage_share)) * stacks) * _w(state, key::spell_value_plan);
}

} // namespace

DictRef _most_valuable_cast(State &state, DictRef battle, DictRef active_stack, DictRef enemy_hero, ArrayRef candidates) {
	DictRef best = state.new_dict();
	if (state.array_size(candidates) == 0) {
		return best;
	}
	Field field = build_field(state, battle, side_of(state, active_stack));
	if (field.power[0] <= 0.0 || field.power[1] <= 0.0) {
		return best;
	}
	double best_share = 0.0;
	for (const Value &candidate : gd::items(state, array_value(candidates))) {
		if (!gd::is_dict(candidate)) {
			continue;
		}
		const double cast = cast_share(state, field, battle, active_stack, enemy_hero, candidate.ref);
		// Only a cast that moves the battle its way; of equal ones the first stays.
		if (cast > best_share && !gd::is_equal_approx(cast, best_share)) {
			best = candidate.ref;
			best_share = cast;
		}
	}
	return best;
}

} // namespace aurelion::rules::port::battle_ai_rules
