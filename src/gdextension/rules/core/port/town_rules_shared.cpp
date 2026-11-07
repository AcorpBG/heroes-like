// TownRules ports shared by the computer players' day (Phase 4) and the ends of a
// battle (Phase 5): the spells a town's mage guild teaches. Phase 4's ports
// (branch native-phase4-faction-turn), moved by Phase 5's slice 09. Since
// magic-guild-draws-20261107 each town teaches the guild it drew
// (docs/magic-system.md, "Guilds and learning").

#include "aurelion_rules/port/town_rules.hpp"

#include "aurelion_rules/port/hero_command_rules_turn.hpp"
#include "aurelion_rules/port/session_view.hpp"

#include "aurelion_rules/compat/godot_math.hpp"

#include <map>
#include <vector>

namespace aurelion::rules::port {

namespace {

using gd::array_value;
using gd::ArrayRef;
using gd::Atom;
using gd::DictRef;
using gd::str;
using state::ContentTable;
using state::State;
using state::Value;
namespace key = state::key;

// Each spell of the town faction's preferred school is this many times as
// likely to be drawn as any other spell of its tier.
constexpr int64_t kPreferredSchoolWeight = 2;

// maxi and max() of ints.
int64_t imax(int64_t a, int64_t b) {
	return compat::engine_max<int64_t>(a, b);
}

// String(d.get(field, fallback)).
Atom text_field(State &state, DictRef dict, Atom field, Atom fallback) {
	return gd::stringify(state, state.get(dict, str(field), str(fallback)));
}

// A spell a guild level can draw, with its weight.
struct GuildCandidate {
	Atom spell_id;
	int64_t weight;
};

// A guild level offers a third of its tier's spells, to the nearest spell.
int64_t drawn_per_level(int64_t candidates) {
	return compat::int_div(candidates + 1, 3);
}

// The faction whose preferred school the town's draw favours: its type's.
Atom town_faction_id(State &state, DictRef town) {
	const DictRef town_template = gd::content_row(state, ContentTable::Town, text_field(state, town, key::town_id, key::empty));
	const Atom faction_id = text_field(state, town_template, key::faction_id, key::empty);
	return faction_id != key::empty ? faction_id : text_field(state, town, key::faction_id, key::empty);
}

} // namespace

namespace town_rules {

int64_t current_spell_tier(State &state, DictRef town) {
	int64_t highest_tier = 0;
	for (const Value &building_id_value : gd::field_items(state, town, str(key::built_buildings))) {
		const DictRef building = gd::content_row(state, ContentTable::Building, gd::stringify(state, building_id_value));
		highest_tier = imax(highest_tier, gd::int_field(state, building, key::spell_tier, 0));
	}
	return highest_tier;
}

ArrayRef accessible_spell_ids(State &state, DictRef town) {
	return spell_ids_through_tier(state, town, current_spell_tier(state, town));
}

ArrayRef spell_ids_through_tier(State &state, DictRef town, int64_t tier) {
	const ArrayRef spell_ids = state.new_array();
	if (tier <= 0) {
		return spell_ids;
	}
	for (const Value &spell_id_value : gd::field_items(state, town, str(key::guild_spell_ids))) {
		const Atom spell_id = gd::stringify(state, spell_id_value);
		const DictRef spell = gd::content_row(state, ContentTable::Spell, spell_id);
		if (gd::is_empty(state, spell) || gd::int_field(state, spell, key::tier, 0) > tier) {
			continue;
		}
		if (!gd::array_has(state, spell_ids, str(spell_id))) {
			state.append(spell_ids, str(spell_id));
		}
	}
	return spell_ids;
}

ArrayRef draw_guild_spell_ids(State &state, DictRef session, DictRef town) {
	const DictRef faction = gd::content_row(state, ContentTable::Faction, town_faction_id(state, town));
	const Atom preferred_school = text_field(state, faction, key::preferred_spell_school_id, key::empty);
	// Each tier's spells in content order; a scroll-only spell never enters a
	// guild (docs/magic-system.md, Scrolls).
	std::map<int64_t, std::vector<GuildCandidate>> tiers;
	Value spells;
	if (state.lookup(gd::content_file(state, key::spells_path), str(key::items), spells) && gd::is_array(spells)) {
		for (const Value &spell_value : gd::items(state, spells)) {
			if (!gd::is_dict(spell_value)) {
				continue;
			}
			const Atom spell_id = text_field(state, spell_value.ref, key::id, key::empty);
			const int64_t tier = gd::int_field(state, spell_value.ref, key::tier, 0);
			if (spell_id == key::empty || tier <= 0 || gd::bool_field(state, spell_value.ref, key::scroll_only, false)) {
				continue;
			}
			const bool preferred = preferred_school != key::empty && text_field(state, spell_value.ref, key::school_id, key::empty) == preferred_school;
			tiers[tier].push_back({ spell_id, preferred ? kPreferredSchoolWeight : 1 });
		}
	}
	// One stream per game and town: the same seed draws the same guilds, and an
	// AI match with fixed rolls draws them from its roll seed.
	const Atom fixed_seed = hero_command_rules::fixed_match_roll_seed(state, session);
	const Atom game_seed = fixed_seed != key::empty ? fixed_seed : text_field(state, session, key::session_id, key::empty);
	const Value rng = hero_command_rules::_seeded_rng(state, gd::format(state, key::s_guild_s, { str(game_seed), str(text_field(state, town, key::placement_id, key::empty)) }));
	const ArrayRef drawn = state.new_array();
	for (const auto &tier_entry : tiers) {
		const std::vector<GuildCandidate> &candidates = tier_entry.second;
		std::vector<bool> taken(candidates.size(), false);
		int64_t total = 0;
		for (const GuildCandidate &candidate : candidates) {
			total += candidate.weight;
		}
		// A plain weighted draw without replacement, with no guarantee.
		const int64_t count = drawn_per_level(static_cast<int64_t>(candidates.size()));
		for (int64_t pick = 0; pick < count && total > 0; ++pick) {
			int64_t roll = gd::rng_randi_range(state, rng, 0, total - 1);
			for (size_t index = 0; index < candidates.size(); ++index) {
				if (taken[index]) {
					continue;
				}
				if (roll < candidates[index].weight) {
					taken[index] = true;
					total -= candidates[index].weight;
					break;
				}
				roll -= candidates[index].weight;
			}
		}
		for (size_t index = 0; index < candidates.size(); ++index) {
			if (taken[index]) {
				state.append(drawn, str(candidates[index].spell_id));
			}
		}
	}
	return drawn;
}

void ensure_guild_draws(State &state, DictRef session) {
	const Value towns = gd::field(state, session_view::overworld(state, session), key::towns);
	if (!gd::is_array(towns)) {
		return;
	}
	for (const Value &town_value : gd::items(state, towns)) {
		if (!gd::is_dict(town_value)) {
			continue;
		}
		Value drawn;
		if (state.lookup(town_value.ref, str(key::guild_spell_ids), drawn) && gd::is_array(drawn)) {
			continue;
		}
		state.set(town_value.ref, str(key::guild_spell_ids), array_value(draw_guild_spell_ids(state, session, town_value.ref)));
	}
}

} // namespace town_rules

} // namespace aurelion::rules::port
