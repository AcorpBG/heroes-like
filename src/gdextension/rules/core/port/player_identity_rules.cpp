// PlayerIdentityRules: who controls a record, a raid or a town, a player's
// record and identity, and the computer players' enemy configs.

#include "aurelion_rules/port/player_identity_rules.hpp"

#include "aurelion_rules/port/session_view.hpp"

namespace aurelion::rules::port::player_identity_rules {

namespace {

using gd::bool_value;
using gd::dict_value;
using gd::int_value;
using gd::str;
namespace key = state::key;

// String(d.get(key, fallback)).
Atom text(State &state, DictRef dict, Atom field, Atom fallback) {
	return gd::stringify_or_fallback(state, state.get(dict, str(field), str(fallback)));
}

} // namespace

Atom controller_id(State &state, DictRef record, Atom fallback) {
	const Atom player_id = text(state, record, key::player_id, key::empty);
	return player_id != key::empty ? player_id : text(state, record, key::faction_id, fallback);
}

Atom raid_controller_id(State &state, DictRef raid) {
	const Atom player_id = text(state, raid, key::spawned_by_player_id, key::empty);
	return player_id != key::empty ? player_id : text(state, raid, key::spawned_by_faction_id, key::empty);
}

Atom town_controller_id(State &state, DictRef town) {
	const Atom player_id = text(state, town, key::controlling_player_id, key::empty);
	if (player_id != key::empty) {
		return player_id;
	}
	const Atom faction = text(state, town, key::controlling_faction_id, key::empty);
	if (faction != key::empty) {
		return faction;
	}
	// town.get("faction_id", ContentService.get_town(...).get("faction_id", "")):
	// the default is looked up first.
	const DictRef town_row = gd::content_row(state, state::ContentTable::Town, text(state, town, key::town_id, key::empty));
	const Value fallback = state.get(town_row, str(key::faction_id), str(key::empty));
	return gd::stringify_or_fallback(state, state.get(town, str(key::faction_id), fallback));
}

DictRef player(State &state, DictRef session, Atom player_id) {
	if (player_id == key::empty) {
		return state.new_dict();
	}
	const DictRef overworld = session_view::overworld(state, session);
	for (const Value &record : gd::field_items(state, overworld, str(key::players))) {
		if (gd::is_dict(record) && text(state, record.ref, key::player_id, key::empty) == player_id) {
			return record.ref;
		}
	}
	return state.new_dict();
}

Atom faction_id(State &state, DictRef session, Atom controller) {
	const DictRef record = player(state, session, controller);
	return text(state, record, key::faction_id, controller);
}

DictRef identity_fields(State &state, DictRef session, Atom controller) {
	const DictRef record = player(state, session, controller);
	const DictRef result = state.new_dict();
	state.set(result, str(key::faction_id), str(faction_id(state, session, controller)));
	if (!gd::is_empty(state, record)) {
		state.set(result, str(key::player_id), str(controller));
		state.set(result, str(key::team_id), str(text(state, record, key::team_id, key::empty)));
	}
	return result;
}

ArrayRef enemy_configs(State &state, ArrayRef players) {
	const ArrayRef result = state.new_array();
	for (const Value &record : gd::items(state, gd::array_value(players))) {
		if (!gd::is_dict(record) || !gd::bool_field(state, record.ref, key::computer, false) || gd::bool_field(state, record.ref, key::human, false)) {
			continue;
		}
		const DictRef config = state.new_dict();
		state.set(config, str(key::player_id), str(text(state, record.ref, key::player_id, key::empty)));
		state.set(config, str(key::player_slot), int_value(gd::int_field(state, record.ref, key::slot, 0)));
		state.set(config, str(key::team_id), str(text(state, record.ref, key::team_id, key::empty)));
		state.set(config, str(key::faction_id), str(text(state, record.ref, key::faction_id, key::empty)));
		state.set(config, str(key::generated_package_town_config), bool_value(true));
		state.append(result, dict_value(config));
	}
	return result;
}

} // namespace aurelion::rules::port::player_identity_rules
