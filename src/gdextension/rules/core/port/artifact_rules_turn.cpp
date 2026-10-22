// ArtifactRules for the computer players' day beyond the shared ports
// (artifact_rules_shared.cpp): artifact taxonomy and descriptions, set ids, and
// the live source rewards of a site.

#include "aurelion_rules/port/artifact_rules_turn.hpp"
#include "aurelion_rules/port/ai_port.hpp"

#include <algorithm>
#include <initializer_list>
#include <iterator>
#include <string>
#include <unordered_set>
#include <vector>

namespace aurelion::rules::port::artifact_rules {

namespace {

using gd::array_value;
using gd::bool_value;
using gd::dict_value;
using gd::int_value;
using gd::str;
using state::ContentTable;
namespace key = state::key;

// String(d.get(field, fallback)).
Atom string_of_field(State &state, DictRef dict, Atom field, Atom fallback) {
	return gd::stringify(state, state.get(dict, str(field), str(fallback)));
}

// sep.join(parts) of an Array of Strings.
Atom join_array(State &state, Atom separator, ArrayRef parts) {
	std::string joined;
	const int64_t size = state.array_size(parts);
	for (int64_t index = 0; index < size; ++index) {
		if (index > 0) {
			joined += state.text(separator);
		}
		joined += state.text(gd::stringify(state, state.at(parts, index)));
	}
	return state.intern(joined);
}

} // namespace

DictRef artifact_taxonomy(State &state, Atom artifact_id) {
	const DictRef artifact = gd::content_row(state, ContentTable::Artifact, artifact_id);
	if (gd::is_empty(state, artifact)) {
		return state.new_dict();
	}
	return _artifact_taxonomy_payload(state, artifact);
}

Atom artifact_taxonomy_summary(State &state, Atom artifact_id) {
	const DictRef taxonomy = artifact_taxonomy(state, artifact_id);
	if (gd::is_empty(state, taxonomy)) {
		return key::taxonomy_unknown;
	}
	const Atom rarity = _title_label(state, string_of_field(state, taxonomy, key::rarity, key::empty));
	const Atom family = _title_label(state, string_of_field(state, taxonomy, key::family, key::empty));
	const ArrayRef role_labels = state.new_array();
	Value roles;
	if (state.lookup(taxonomy, str(key::roles), roles) && gd::is_array(roles)) {
		for (const Value &role_value : gd::items(state, roles)) {
			const Atom role = gd::strip_edges(state, gd::stringify(state, role_value));
			if (role == key::empty) {
				continue;
			}
			state.append(role_labels, str(_title_label(state, role)));
		}
	}
	const Atom roles_text = state.array_size(role_labels) != 0 ? join_array(state, key::comma_space, role_labels) : static_cast<Atom>(key::role_pending);
	return gd::format(state, key::s_s_s_2, {str(rarity), str(family), str(roles_text)});
}

ArrayRef select_live_source_rewards(State &state, Atom source_tag, DictRef source_record, Atom source_key, Atom faction_id, ArrayRef excluded_artifact_ids) {
	if (!state.has(source_record, str(key::claim_artifact_classes))) {
		const DictRef single = select_live_source_reward(state, source_tag, source_record, source_key, faction_id, excluded_artifact_ids);
		const ArrayRef result = state.new_array();
		if (gd::bool_field(state, single, key::ok, false)) {
			state.append(result, dict_value(single));
		}
		return result;
	}
	const ArrayRef selections = state.new_array();
	const ArrayRef held = gd::duplicate_array(state, excluded_artifact_ids);
	const Value classes = gd::field(state, source_record, key::claim_artifact_classes);
	const int64_t class_count = gd::is_array(classes) ? state.array_size(classes.ref) : 0;
	for (int64_t index = 0; index < class_count; ++index) {
		const Atom class_key = index == 0 ? source_key : gd::format(state, key::s_d_3, {str(source_key), int_value(index)});
		const DictRef selection = _select_class_source_reward(state, source_tag, gd::stringify(state, state.at(classes.ref, index)), class_key, held);
		if (gd::bool_field(state, selection, key::ok, false)) {
			state.append(held, str(string_of_field(state, selection, key::artifact_id, key::empty)));
			state.append(selections, dict_value(selection));
		}
	}
	return selections;
}

Atom live_source_reward_tag(State &state, DictRef source_record) {
	const DictRef contract = _artifact_source_contract(state, source_record);
	const Atom explicit_tag = gd::strip_edges(state, string_of_field(state, contract, key::source_tag, key::empty));
	if (explicit_tag != key::empty) {
		return explicit_tag;
	}
	const Atom family = string_of_field(state, source_record, key::family, key::empty);
	if (family == key::guarded_reward_site) {
		return key::guarded_site;
	}
	if (family == key::shrine || family == key::frontier_shrine) {
		return key::shrine;
	}
	if (family == key::neutral_dwelling) {
		return key::dwelling;
	}
	return key::empty;
}

Atom describe_artifact(State &state, Atom artifact_id) {
	const DictRef artifact = gd::content_row(state, ContentTable::Artifact, artifact_id);
	if (gd::is_empty(state, artifact)) {
		return key::artifact_cache;
	}
	const Atom name = artifact_name(state, artifact_id);
	const Atom taxonomy = artifact_taxonomy_summary(state, artifact_id);
	const Atom description = string_of_field(state, artifact, key::description, key::recovered_equipment);
	const Atom effect = _artifact_effect_summary(state, artifact);
	return gd::format(state, key::s_s_s_s_2, {str(name), str(taxonomy), str(description), str(effect)});
}

Atom _artifact_set_id(State &state, DictRef artifact) {
	for (const Atom field : {key::set_id, key::artifact_set_id, key::set}) {
		const Value value = state.get(artifact, str(field), str(key::empty));
		if (gd::is_dict(value)) {
			const Atom nested_id = gd::strip_edges(state, string_of_field(state, value.ref, key::id, key::empty));
			if (nested_id != key::empty) {
				return nested_id;
			}
		}
		// String() of a float or a container is not ported: NotPorted.
		const Atom label = gd::strip_edges(state, gd::stringify_or_fallback(state, value));
		if (label != key::empty) {
			return label;
		}
	}
	// A missing validation_tags is the {} fallback, which has no set id.
	Value validation_tags;
	if (state.lookup(artifact, str(key::validation_tags), validation_tags) && gd::is_dict(validation_tags)) {
		return gd::strip_edges(state, string_of_field(state, validation_tags.ref, key::set_id, key::empty));
	}
	return key::empty;
}

DictRef _artifact_taxonomy_payload(State &state, DictRef artifact) {
	const DictRef payload = state.new_dict();
	state.set(payload, str(key::artifact_id), str(string_of_field(state, artifact, key::id, key::empty)));
	state.set(payload, str(key::artifact_class), str(string_of_field(state, artifact, key::artifact_class, key::empty)));
	state.set(payload, str(key::rarity), str(string_of_field(state, artifact, key::rarity, key::empty)));
	state.set(payload, str(key::slot), str(string_of_field(state, artifact, key::slot, key::empty)));
	state.set(payload, str(key::family), str(string_of_field(state, artifact, key::family, key::empty)));
	// _string_array(null) is _string_array([]).
	state.set(payload, str(key::roles), array_value(_string_array(state, gd::field(state, artifact, key::roles))));
	state.set(payload, str(key::accord_affinity), str(string_of_field(state, artifact, key::accord_affinity, key::empty)));
	state.set(payload, str(key::faction_affinity), array_value(_string_array(state, gd::field(state, artifact, key::faction_affinity))));
	state.set(payload, str(key::source_tags), array_value(_string_array(state, gd::field(state, artifact, key::source_tags))));
	state.set(payload, str(key::set_id), str(_artifact_set_id(state, artifact)));
	// risk if it is a Dictionary, else {}: no flags.
	Value risk;
	const bool has_risk = state.lookup(artifact, str(key::risk), risk) && gd::is_dict(risk);
	state.set(payload, str(key::cursed), bool_value(has_risk && gd::bool_field(state, risk.ref, key::cursed, false)));
	state.set(payload, str(key::tradeoff), bool_value(has_risk && gd::bool_field(state, risk.ref, key::tradeoff, false)));
	state.set(payload, str(key::ui_summary), str(_artifact_ui_summary(state, artifact)));
	return payload;
}

Atom _artifact_ui_summary(State &state, DictRef artifact) {
	// A missing ui is the {} fallback, whose summary is "".
	Value ui;
	if (state.lookup(artifact, str(key::ui), ui) && gd::is_dict(ui)) {
		return gd::strip_edges(state, string_of_field(state, ui.ref, key::summary, key::empty));
	}
	return key::empty;
}

} // namespace aurelion::rules::port::artifact_rules
