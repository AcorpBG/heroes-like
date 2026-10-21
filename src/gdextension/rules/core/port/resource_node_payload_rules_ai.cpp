// ResourceNodePayloadRules: the functions the AI targets reach (Phase 3), ported under
// their GDScript names.

#include "aurelion_rules/port/resource_node_payload_rules_ai.hpp"

#include "aurelion_rules/port/ai_port.hpp"

namespace aurelion::rules::port {

namespace {

using gd::array_value;
using gd::Atom;
using gd::dict_value;
using gd::DictRef;
using gd::int_value;
using gd::str;
using state::ContentTable;
using state::State;
using state::Value;
namespace key = state::key;

} // namespace

namespace resource_node_payload_rules {

DictRef site_for_node(State &state, DictRef node, DictRef site) {
	if (gd::is_empty(state, site)) {
		site = gd::content_row(state, ContentTable::ResourceSite, ai::string_or_empty(state, node, key::site_id));
	}
	if (gd::is_empty(state, site) || !_has_node_payload(state, node, site)) {
		return site;
	}
	const DictRef effective = gd::deep_duplicate_dict(state, site);
	const Value rewards = gd::field(state, node, key::payload_rewards);
	if (gd::is_dict(rewards)) {
		state.set(effective, str(key::claim_rewards), dict_value(gd::deep_duplicate_dict(state, rewards.ref)));
		state.erase(effective, str(key::rewards));
	}
	const Value choices = gd::field(state, node, key::payload_reward_choices);
	if (gd::is_array(choices)) {
		state.set(effective, str(key::reward_choices), array_value(gd::deep_duplicate_array(state, choices.ref)));
	}
	const Value spell_ids = gd::field(state, node, key::payload_spell_ids);
	if (gd::is_array(spell_ids)) {
		state.erase(effective, str(key::learn_spell_id));
		state.set(effective, str(key::learn_spell_ids), array_value(gd::duplicate_array(state, spell_ids.ref)));
	}
	const Value visit_override = gd::field(state, node, key::payload_visit);
	if (gd::is_dict(visit_override)) {
		// effective.get("visit", {}): a missing visit reads as a new {}.
		Value current;
		const bool has_visit = state.lookup(effective, str(key::visit), current);
		if (!has_visit || gd::is_dict(current)) {
			const DictRef visit = has_visit ? gd::deep_duplicate_dict(state, current.ref) : state.new_dict();
			for (const Value &entry_key : gd::items(state, visit_override)) {
				const Value entry = gd::index(state, visit_override.ref, entry_key);
				state.set(visit, entry_key, gd::is_dict(entry) || gd::is_array(entry) ? gd::duplicate_value(state, entry, true) : entry);
			}
			state.set(effective, str(key::visit), dict_value(visit));
		}
	}
	const Value recruits = gd::field(state, node, key::payload_recruits);
	if (gd::is_dict(recruits)) {
		_erase_claim_recruits(state, effective);
		if (!gd::is_empty(state, recruits.ref)) {
			state.set(effective, str(key::claim_recruits), dict_value(gd::deep_duplicate_dict(state, recruits.ref)));
		}
	}
	if (state.has(node, str(key::payload_vision_radius))) {
		state.set(effective, str(key::vision_radius), int_value(compat::engine_max<int64_t>(0, gd::int_field(state, node, key::payload_vision_radius, 0))));
	}
	const Value artifact_classes = gd::field(state, node, key::payload_artifact_classes);
	if (gd::is_array(artifact_classes)) {
		state.set(effective, str(key::claim_artifact_classes), array_value(gd::duplicate_array(state, artifact_classes.ref)));
	}
	const Value artifact_rarity = gd::field(state, node, key::payload_artifact_rarity);
	if (gd::is_string(artifact_rarity)) {
		state.set(effective, str(key::claim_artifact_rarity), artifact_rarity);
	}
	if (claim_payload_spent(state, node, site)) {
		for (const Atom erased : {key::claim_rewards, key::rewards, key::reward_choices, key::learn_spell_id, key::learn_spell_ids}) {
			state.erase(effective, str(erased));
		}
		_erase_claim_recruits(state, effective);
	}
	return effective;
}

void _erase_claim_recruits(State &state, DictRef effective) {
	state.erase(effective, str(key::claim_recruits));
	Value roster;
	if (state.lookup(effective, str(key::neutral_roster), roster) && gd::is_dict(roster) && state.has(roster.ref, str(key::claim_recruits))) {
		state.erase(roster.ref, str(key::claim_recruits));
		state.set(effective, str(key::neutral_roster), roster);
	}
}

bool claim_payload_spent(State &state, DictRef node, DictRef site) {
	return gd::bool_field(state, site, key::persistent_control, false) && gd::bool_field(state, node, key::claim_payload_spent, false);
}

bool _has_node_payload(State &state, DictRef node, DictRef site) {
	// PAYLOAD_KEYS, in order.
	for (const Atom payload_key : {key::payload_rewards, key::payload_reward_choices, key::payload_spell_ids, key::payload_visit, key::payload_recruits, key::payload_vision_radius, key::payload_artifact_classes, key::payload_artifact_rarity}) {
		if (state.has(node, str(payload_key))) {
			return true;
		}
	}
	return claim_payload_spent(state, node, site);
}

} // namespace resource_node_payload_rules

} // namespace aurelion::rules::port
