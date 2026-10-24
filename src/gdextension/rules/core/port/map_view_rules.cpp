// The map views' rules reads (Phase 7, slice 7.8): mines, free boats, a town's
// biome art and the gain feed's snapshot.

#include "aurelion_rules/port/overworld_rules_panels.hpp"

#include "aurelion_rules/port/ai_port.hpp"
#include "aurelion_rules/port/artifact_rules.hpp"
#include "aurelion_rules/port/common_mine_rules.hpp"
#include "aurelion_rules/port/mine_rules.hpp"
#include "aurelion_rules/port/session_view.hpp"
#include "aurelion_rules/port/water_travel_rules_ai.hpp"

namespace aurelion::rules::port {

namespace {

using gd::array_value;
using gd::ArrayRef;
using gd::Atom;
using gd::bool_value;
using gd::dict_value;
using gd::DictRef;
using gd::int_value;
using gd::str;
using state::ContentTable;
using state::Kind;
using state::State;
using state::Value;
namespace key = state::key;

// OverworldRules.LIVE_STOCKPILE_RESOURCE_KEYS.
constexpr Atom kLiveStockpileResourceKeys[] = {
	key::gold,
	key::wood,
	key::ore,
	key::aetherglass,
	key::embergrain,
	key::peatwax,
	key::verdant_grafts,
	key::brass_scrip,
	key::memory_salt,
};

// OverworldGainFeed.STAT_NAMES and BOOST_NAMES, in their order.
struct Named {
	Atom id;
	Atom label;
};
constexpr Named kStatNames[] = {
	{key::attack, key::Attack},
	{key::defense, key::Defense},
	{key::power, key::spell_power},
	{key::knowledge, key::Knowledge},
};
constexpr Named kBoostNames[] = {
	{key::cohesion, key::Cohesion},
	{key::momentum, key::Momentum},
};
// [["experience", "Experience"], ["mana", "Mana"], ["movement", "Movement"]].
constexpr Named kCountedEntries[] = {
	{key::experience, key::Experience},
	{key::mana, key::Mana},
	{key::movement, key::Movement},
};

// String(x) of any value: the engine's text for a float, a vector or a container.
Atom string_of(State &state, const Value &value) {
	switch (value.kind) {
		case Kind::Nil:
		case Kind::Bool:
		case Kind::Int:
		case Kind::String:
		case Kind::StringName:
			return gd::stringify(state, value);
		default:
			return gd::engine_str(state, value);
	}
}

// String(d.get(field, fallback)).
Atom text_or(State &state, DictRef dict, Atom field, const Value &fallback) {
	return string_of(state, state.get(dict, str(field), fallback));
}

// var x: Dictionary = d.get(field, {}): the field as a Dictionary (another
// type is GDScript's typed-assignment error), or a new one when it is missing.
DictRef typed_dict_field(State &state, DictRef dict, const Value &field) {
	Value found;
	if (state.lookup(dict, field, found)) {
		return gd::as_dict(found);
	}
	return state.new_dict();
}

// d.get(field, {}) if d.get(field, {}) is Dictionary else {}: the field when it
// is a Dictionary, else false.
bool dict_field(State &state, DictRef dict, Atom field, DictRef &out) {
	Value found;
	if (state.lookup(dict, str(field), found) && gd::is_dict(found)) {
		out = found.ref;
		return true;
	}
	return false;
}

// int(d.get(outer, {}).get(inner, 0)): a missing outer is the empty
// Dictionary's 0; an outer that is no Dictionary has no get() (a ScriptError).
int64_t nested_int(State &state, DictRef dict, Atom outer, Atom inner) {
	Value found;
	if (!state.lookup(dict, str(outer), found)) {
		return 0;
	}
	return gd::to_int(state, ai::vget(state, found, inner, int_value(0)));
}

// value in d.get(field, []) read only: a missing field is the empty Array.
bool in_field(State &state, DictRef dict, Atom field, const Value &value) {
	Value found;
	if (!state.lookup(dict, str(field), found)) {
		return false;
	}
	return gd::in(state, value, found);
}

// {"text": text, "icon": icon, "tone": tone}.
DictRef feed_line(State &state, Atom text, Atom icon, Atom tone) {
	const DictRef line = state.new_dict();
	state.set(line, str(key::text), str(text));
	state.set(line, str(key::icon), str(icon));
	state.set(line, str(key::tone), str(tone));
	return line;
}

} // namespace

namespace mine_rules {

Atom asset_id(State &state, DictRef node) {
	const Atom common = common_mine_rules::resource(state, node);
	if (common != key::empty) {
		return gd::format(state, key::mapobj_common_s_mine, {str(common)});
	}
	const Atom rare = resource(state, node);
	return rare != key::empty ? gd::format(state, key::mapobj_rare_s_mine, {str(rare)}) : static_cast<Atom>(key::empty);
}

ArrayRef body_tiles(State &state, DictRef node) {
	const ArrayRef result = state.new_array();
	for (const Vector2i tile : common_mine_rules::body_tiles(state, node)) {
		state.append(result, Value::of_vector2i(tile.x, tile.y));
	}
	return result;
}

} // namespace mine_rules

namespace water_travel_rules {

ArrayRef free_boats(State &state, const Value &session, int64_t level) {
	const ArrayRef result = state.new_array();
	for (const Value &boat : gd::items(state, array_value(boats(state, session)))) {
		if (gd::is_dict(boat) && text_or(state, boat.ref, key::hero_id, str(key::empty)) == key::empty &&
				gd::int_field(state, boat.ref, key::level, 0) == level) {
			state.append(result, boat);
		}
	}
	return result;
}

} // namespace water_travel_rules

namespace town_biome_art_rules {

DictRef resolve(State &state, Atom base_asset_id, Atom terrain, DictRef skins) {
	const DictRef aliases = typed_dict_field(state, skins, str(key::terrain_aliases));
	const Atom biome = text_or(state, aliases, terrain, str(key::empty));
	const DictRef entries = typed_dict_field(state, skins, str(key::appearances));
	const DictRef entry = typed_dict_field(state, entries, str(base_asset_id));
	const DictRef variants = typed_dict_field(state, entry, str(key::biome_asset_ids));
	const Atom selected = text_or(state, variants, biome, str(base_asset_id));
	const DictRef result = state.new_dict();
	state.set(result, str(key::base_asset_id), str(base_asset_id));
	state.set(result, str(key::render_asset_id), str(selected));
	state.set(result, str(key::terrain), str(terrain));
	state.set(result, str(key::biome_id), str(biome));
	state.set(result, str(key::uses_biome_variant), bool_value(selected != base_asset_id));
	return result;
}

} // namespace town_biome_art_rules

namespace overworld_gain_feed {

DictRef snapshot(State &state, const Value &session) {
	if (session.kind == Kind::Nil) {
		return state.new_dict();
	}
	const DictRef overworld = session_view::overworld(state, gd::as_dict(session));
	DictRef hero;
	if (!dict_field(state, overworld, key::hero, hero)) {
		hero = state.new_dict();
	}
	const DictRef army = state.new_dict();
	DictRef hero_army;
	if (dict_field(state, hero, key::army, hero_army)) {
		Value stacks;
		if (state.lookup(hero_army, str(key::stacks), stacks) && gd::is_array(stacks)) {
			for (const Value &stack : gd::items(state, stacks)) {
				if (!gd::is_dict(stack)) {
					continue;
				}
				const Atom unit_id = text_or(state, stack.ref, key::unit_id, str(key::empty));
				const int64_t held = gd::to_int(state, state.get(army, str(unit_id), int_value(0)));
				const int64_t count = gd::to_int(state, state.get(stack.ref, str(key::count), int_value(0)));
				state.set(army, str(unit_id), int_value(gd::add(held, count)));
			}
		}
	}
	const DictRef owned = state.new_dict();
	for (const Value &node : gd::field_items(state, overworld, str(key::resource_nodes))) {
		if (gd::is_dict(node) && text_or(state, node.ref, key::collected_by_faction_id, str(key::empty)) == key::player) {
			const Atom placement_id = text_or(state, node.ref, key::placement_id, str(key::empty));
			state.set(owned, str(placement_id), str(text_or(state, node.ref, key::site_id, str(key::empty))));
		}
	}
	DictRef spellbook = 0;
	const bool has_spellbook = dict_field(state, hero, key::spellbook, spellbook);
	DictRef mana = 0;
	const bool has_mana = has_spellbook && dict_field(state, spellbook, key::mana, mana);
	DictRef movement = 0;
	const bool has_movement = dict_field(state, hero, key::movement, movement);
	Value boosts;
	const bool has_boosts = state.lookup(hero, str(key::battle_boosts), boosts) && gd::is_dict(boosts);

	DictRef resources = 0;
	const Value resources_copy = dict_field(state, overworld, key::resources, resources)
			? gd::engine_duplicate(state, dict_value(resources), true)
			: dict_value(state.new_dict());
	const Atom hero_id = text_or(state, hero, key::id, str(key::empty));
	const int64_t experience = gd::int_field(state, hero, key::experience, 0);
	DictRef command = 0;
	const Value command_copy = dict_field(state, hero, key::command, command)
			? gd::engine_duplicate(state, dict_value(command), true)
			: dict_value(state.new_dict());
	const ArrayRef artifacts = artifact_rules::owned_artifact_ids(state, hero);
	Value known_spell_ids;
	const ArrayRef spells = has_spellbook && state.lookup(spellbook, str(key::known_spell_ids), known_spell_ids) && gd::is_array(known_spell_ids)
			? gd::duplicate_array(state, known_spell_ids.ref)
			: state.new_array();
	const int64_t mana_current = has_mana ? gd::int_field(state, mana, key::current, 0) : 0;
	const int64_t movement_current = has_movement ? gd::int_field(state, movement, key::current, 0) : 0;
	const Value boosts_copy = has_boosts ? gd::engine_duplicate(state, boosts, true) : dict_value(state.new_dict());

	const DictRef result = state.new_dict();
	state.set(result, str(key::resources), resources_copy);
	state.set(result, str(key::hero_id), str(hero_id));
	state.set(result, str(key::experience), int_value(experience));
	state.set(result, str(key::command), command_copy);
	state.set(result, str(key::artifacts), array_value(artifacts));
	state.set(result, str(key::spells), array_value(spells));
	state.set(result, str(key::mana), int_value(mana_current));
	state.set(result, str(key::movement), int_value(movement_current));
	state.set(result, str(key::army), dict_value(army));
	state.set(result, str(key::boosts), boosts_copy);
	state.set(result, str(key::owned_sites), dict_value(owned));
	return result;
}

ArrayRef gains(State &state, DictRef before, DictRef after, int64_t movement_walked) {
	const ArrayRef lines = state.new_array();
	if (gd::is_empty(state, before) || gd::is_empty(state, after)) {
		return lines;
	}
	const DictRef owned_before = typed_dict_field(state, before, str(key::owned_sites));
	for (const Value &placement_id : gd::field_items(state, after, str(key::owned_sites))) {
		if (!state.has(owned_before, placement_id)) {
			const Value site_id = ai::vindex(state, gd::index(state, after, str(key::owned_sites)), placement_id);
			const DictRef site = gd::content_row(state, ContentTable::ResourceSite, string_of(state, site_id));
			// Collected pickups are marked too; only sites the player keeps
			// (mines, dwellings, outposts) are claimed.
			if (gd::to_bool(state.get(site, str(key::persistent_control), bool_value(false)))) {
				const Atom text = gd::format(state, key::s_claimed, {str(text_or(state, site, key::name, str(key::Site)))});
				state.append(lines, dict_value(feed_line(state, text, key::empty, key::claim)));
			}
		}
	}
	const Atom before_hero_id = text_or(state, before, key::hero_id, str(key::empty));
	const bool same_hero = before_hero_id != key::empty && before_hero_id == text_or(state, after, key::hero_id, str(key::empty));
	if (same_hero) {
		for (const Value &artifact_id : gd::field_items(state, after, str(key::artifacts))) {
			if (!in_field(state, before, key::artifacts, artifact_id)) {
				const Atom id = string_of(state, artifact_id);
				const DictRef artifact = gd::content_row(state, ContentTable::Artifact, id);
				const Atom name = string_of(state, state.get(artifact, str(key::name), artifact_id));
				const Atom icon = artifact_rules::artifact_icon_path(state, id);
				state.append(lines, dict_value(feed_line(state, name, icon, key::artifact)));
			}
		}
	}
	const ArrayRef spent = state.new_array();
	const DictRef before_resources = typed_dict_field(state, before, str(key::resources));
	const DictRef after_resources = typed_dict_field(state, after, str(key::resources));
	const ArrayRef order = _resource_order(state, before_resources, after_resources);
	for (const Value &resource_value : gd::items(state, array_value(order))) {
		const Atom resource_id = gd::to_string(resource_value);
		const int64_t delta = gd::sub(gd::to_int(state, state.get(after_resources, resource_value, int_value(0))), gd::to_int(state, state.get(before_resources, resource_value, int_value(0))));
		if (delta == 0) {
			continue;
		}
		const Atom sign = delta > 0 ? static_cast<Atom>(key::plus) : static_cast<Atom>(key::dash);
		const Atom text = gd::format(state, key::s_d_s_5, {str(sign), int_value(compat::absi(delta)), str(overworld_rules::_resource_display_name(state, resource_id))});
		const Atom icon = overworld_rules::resource_icon_path(state, resource_id);
		const DictRef line = feed_line(state, text, icon, delta > 0 ? static_cast<Atom>(key::gain) : static_cast<Atom>(key::cost));
		if (delta > 0) {
			state.append(lines, dict_value(line));
		} else {
			state.append(spent, dict_value(line));
		}
	}
	if (same_hero) {
		const DictRef army_before = typed_dict_field(state, before, str(key::army));
		for (const Value &unit_id : gd::field_items(state, after, str(key::army))) {
			const Value after_count = ai::vindex(state, gd::index(state, after, str(key::army)), unit_id);
			const int64_t joined = gd::sub(gd::to_int(state, after_count), gd::to_int(state, state.get(army_before, unit_id, int_value(0))));
			if (joined > 0) {
				const DictRef unit = gd::content_row(state, ContentTable::Unit, string_of(state, unit_id));
				const Atom text = gd::format(state, key::d_s_2, {int_value(joined), str(string_of(state, state.get(unit, str(key::name), unit_id)))});
				const DictRef unit_art = gd::content_row(state, ContentTable::UnitArt, string_of(state, unit_id));
				const Atom icon = text_or(state, unit_art, key::portrait, str(key::empty));
				state.append(lines, dict_value(feed_line(state, text, icon, key::gain)));
			}
		}
		for (const Named &stat : kStatNames) {
			const int64_t raised = gd::sub(nested_int(state, after, key::command, stat.id), nested_int(state, before, key::command, stat.id));
			if (raised > 0) {
				const Atom text = gd::format(state, key::d_s_2, {int_value(raised), str(stat.label)});
				state.append(lines, dict_value(feed_line(state, text, key::empty, key::gain)));
			}
		}
		for (const Value &spell_id : gd::field_items(state, after, str(key::spells))) {
			if (!in_field(state, before, key::spells, spell_id)) {
				const DictRef spell = gd::content_row(state, ContentTable::Spell, string_of(state, spell_id));
				const Atom text = gd::format(state, key::learned_s, {str(string_of(state, state.get(spell, str(key::name), spell_id)))});
				const Atom icon = spell_rules::spell_icon_path(state, string_of(state, spell_id));
				state.append(lines, dict_value(feed_line(state, text, icon, key::artifact)));
			}
		}
		for (const Named &entry : kCountedEntries) {
			int64_t raised = gd::sub(gd::int_field(state, after, entry.id, 0), gd::int_field(state, before, entry.id, 0));
			if (entry.id == key::movement) {
				raised = gd::add(raised, compat::engine_max<int64_t>(0, movement_walked));
			}
			if (raised > 0) {
				const Atom text = gd::format(state, key::d_s_2, {int_value(raised), str(entry.label)});
				state.append(lines, dict_value(feed_line(state, text, key::empty, key::gain)));
			}
		}
		for (const Named &boost : kBoostNames) {
			const int64_t raised = gd::sub(nested_int(state, after, key::boosts, boost.id), nested_int(state, before, key::boosts, boost.id));
			if (raised > 0) {
				const Atom text = gd::format(state, key::d_s_next_battle, {int_value(raised), str(boost.label)});
				state.append(lines, dict_value(feed_line(state, text, key::empty, key::gain)));
			}
		}
	}
	ai::append_array(state, lines, spent);
	return lines;
}

ArrayRef _resource_order(State &state, DictRef before, DictRef after) {
	const ArrayRef order = state.new_array();
	for (const Atom resource_id : kLiveStockpileResourceKeys) {
		state.append(order, str(resource_id));
	}
	for (const DictRef source : {before, after}) {
		for (const Value &resource_id : gd::items(state, dict_value(source))) {
			const Atom id = string_of(state, resource_id);
			if (!gd::array_has(state, order, str(id)) && id != key::experience) {
				state.append(order, str(id));
			}
		}
	}
	return order;
}

} // namespace overworld_gain_feed

} // namespace aurelion::rules::port
