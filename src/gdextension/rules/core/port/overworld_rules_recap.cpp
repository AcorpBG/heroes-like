// OverworldRules for the human seat's actions (Phase 7, slice 7.2): the
// post-action recap.

#include "aurelion_rules/port/overworld_rules_move.hpp"

#include "aurelion_rules/port/ai_port.hpp"
#include "aurelion_rules/port/artifact_rules.hpp"
#include "aurelion_rules/port/battle_ends.hpp"
#include "aurelion_rules/port/session_view.hpp"

#include <string>
#include <vector>

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
using overworld_rules::Vector2i;
using state::ContentTable;
using state::Kind;
using state::State;
using state::Value;
namespace key = state::key;

// d.get(field, {}) stored or returned: the value, or a new Dictionary.
Value field_or_new_dict(State &state, DictRef dict, Atom field) {
	Value found;
	if (state.lookup(dict, str(field), found)) {
		return found;
	}
	return dict_value(state.new_dict());
}

// int(movement.get(field, 0)) of var movement = session.overworld.get("movement", {}).
int64_t movement_int(State &state, DictRef session, Atom field) {
	Value movement;
	if (!state.lookup(session_view::overworld(state, session), str(key::movement), movement)) {
		return 0;
	}
	return gd::to_int(state, ai::vget(state, movement, field, int_value(0)));
}

// String(d.get(field, {}).get("public_text", fallback)) of
// var part: Dictionary = d.get(field, {}) if d.get(field, {}) is Dictionary else {}.
Atom public_text_of(State &state, DictRef dict, Atom field, Atom fallback) {
	Value part;
	if (state.lookup(dict, str(field), part) && gd::is_dict(part)) {
		return gd::stringify(state, state.get(part.ref, str(key::public_text), str(fallback)));
	}
	return fallback;
}

// separator.join(items) of an Array of Strings (converted to a PackedStringArray).
Atom join_array(State &state, Atom separator, ArrayRef items) {
	std::string joined;
	bool first = true;
	for (const Value &item : gd::items(state, array_value(items))) {
		if (!first) {
			joined += state.text(separator);
		}
		joined += gd::text(state, item);
		first = false;
	}
	return state.intern(joined);
}

Atom join_atoms(State &state, Atom separator, const std::vector<Atom> &parts) {
	std::string joined;
	for (size_t index = 0; index < parts.size(); ++index) {
		if (index > 0) {
			joined += state.text(separator);
		}
		joined += state.text(parts[index]);
	}
	return state.intern(joined);
}

// s.to_lower() of ASCII text (the cadence label is "Weekly" or "Daily").
Atom ascii_lower(State &state, Atom text) {
	std::string lowered = state.text(text);
	for (char &c : lowered) {
		const unsigned char byte = static_cast<unsigned char>(c);
		if (byte >= 0x80) {
			throw state::NotPorted("OverworldRules._resource_site_post_action_why: to_lower() of non-ASCII text");
		}
		if (c >= 'A' && c <= 'Z') {
			c = static_cast<char>(c - 'A' + 'a');
		}
	}
	return state.intern(lowered);
}

// text.split(delimiter, false): the pieces between delimiters, empty ones left out.
std::vector<std::string> split_without_empty(const std::string &text, const std::string &delimiter) {
	std::vector<std::string> pieces;
	if (text.empty()) {
		return pieces;
	}
	size_t from = 0;
	while (true) {
		size_t end = text.find(delimiter, from);
		if (end == std::string::npos) {
			end = text.size();
		}
		if (end > from) {
			pieces.push_back(text.substr(from, end - from));
		}
		if (end == text.size()) {
			break;
		}
		from = end + delimiter.size();
	}
	return pieces;
}

// "%d,%d" % [x, y].
Atom tile_text(State &state, int64_t x, int64_t y) {
	return state.intern(gd::format_pair(x, y));
}

} // namespace

namespace overworld_rules {

DictRef _attach_post_action_recap(State &state, DictRef result, DictRef session, Atom action_kind, DictRef context) {
	if (!gd::bool_field(state, result, key::ok, false)) {
		return result;
	}
	const int64_t recap_started_usec = _rules_profile_timer(state);
	_rules_profile_set(state, key::post_action_recap, key::mode, str(key::compact));
	_rules_profile_set(state, key::post_action_recap, key::action_kind, str(action_kind));
	_rules_profile_set(state, key::post_action_recap, key::rich_surface_skipped, bool_value(true));
	_rules_profile_set(state, key::post_action_recap, key::objective_feed_used, bool_value(false));
	_rules_profile_set(state, key::post_action_recap, key::objective_stakes_surface_used, bool_value(false));
	const DictRef recap = _build_post_action_recap(state, session, action_kind, context, ai::string_or_empty(state, result, key::message));
	if (!gd::is_empty(state, recap)) {
		state.set(result, str(key::post_action_recap), dict_value(recap));
	} else {
		_rules_profile_set(state, key::post_action_recap, key::mode, str(key::skipped_compact));
	}
	_rules_profile_add_ms(state, key::post_action_recap_total_ms, recap_started_usec);
	return result;
}

DictRef _build_post_action_recap(State &state, DictRef session, Atom action_kind, DictRef context, Atom message) {
	if (action_kind == key::move_) {
		return _movement_post_action_recap(state, session, context, message);
	}
	if (action_kind == key::resource_site) {
		return _resource_site_post_action_recap(state, session, context, message);
	}
	if (action_kind == key::artifact) {
		return _artifact_post_action_recap(state, session, context, message);
	}
	if (action_kind == key::site_response) {
		return _site_response_post_action_recap(state, session, context, message);
	}
	if (action_kind == key::spell) {
		return _spell_post_action_recap(state, session, context, message);
	}
	if (action_kind == key::town_capture) {
		return _town_capture_post_action_recap(state, session, context, message);
	}
	return _generic_post_action_recap(state, session, action_kind, context, message);
}

DictRef _movement_post_action_recap(State &state, DictRef session, DictRef context, Atom message) {
	// var target_context: Dictionary = context.get("target_context", {}), {} unless a Dictionary.
	const Value target_value = state.get(context, str(key::target_context), Value());
	const DictRef target_context = gd::is_dict(target_value) ? target_value.ref : state.new_dict();
	const Atom target_type = ai::string_or_empty(state, target_context, key::type);
	if (target_type == key::resource || target_type == key::artifact) {
		const DictRef moved_context = gd::as_dict(gd::engine_duplicate(state, dict_value(target_context), true));
		const Atom moved_from = tile_text(state, gd::int_field(state, context, key::from_x, 0), gd::int_field(state, context, key::from_y, 0));
		state.set(moved_context, str(key::moved_from), str(moved_from));
		if (target_type == key::resource) {
			return _resource_site_post_action_recap(state, session, moved_context, message);
		}
		return _artifact_post_action_recap(state, session, moved_context, message);
	}
	if (target_type == key::encounter) {
		return _battle_post_action_recap(state, session, target_context, message);
	}
	if (target_type == key::town && ai::string_or_empty(state, context, key::route) == key::town) {
		return _town_visit_post_action_recap(state, session, target_context, message);
	}

	const int64_t to_x = gd::int_field(state, context, key::to_x, 0);
	const int64_t to_y = gd::int_field(state, context, key::to_y, 0);
	// var route_steps: Array = context.get("route_steps", []), [] unless an Array: only its size is read.
	const Value route_value = state.get(context, str(key::route_steps), Value());
	const int64_t route_step_count = gd::is_array(route_value) ? state.array_size(route_value.ref) : 0;
	const int64_t from_x = gd::int_field(state, context, key::from_x, 0);
	const int64_t from_y = gd::int_field(state, context, key::from_y, 0);
	const int64_t current = movement_int(state, session, key::current);
	const int64_t max_movement = movement_int(state, session, key::max);
	const Atom happened = gd::format(state, key::moved_from_d_d_to_d, {int_value(from_x), int_value(from_y), int_value(to_x), int_value(to_y), int_value(current), int_value(max_movement)});
	const Atom affected = gd::format(state, key::tile_d_d_route_spent_d, {int_value(to_x), int_value(to_y), int_value(route_step_count), str(route_step_count == 1 ? key::empty : key::s)});
	const Atom next_step = _post_action_next_step(state, session);
	const Atom cue_text = gd::format(state, key::d_d_move_d_d_scout, {int_value(to_x), int_value(to_y), int_value(current), int_value(max_movement)});
	return _post_action_recap_payload(state, key::move_, happened, affected, key::movement_spends_route_tempo_updates_scouting, next_step, cue_text);
}

DictRef _resource_site_post_action_recap(State &state, DictRef session, DictRef context, Atom message) {
	const int64_t recap_started_usec = _rules_profile_timer(state);
	const Atom site_id = ai::string_or_empty(state, context, key::site_id);
	const DictRef site = gd::content_row(state, ContentTable::ResourceSite, site_id);
	const Atom site_name = gd::stringify(state, state.get(site, str(key::name), str(key::the_site)));
	const Atom tile = _post_action_tile_label(state, context, state.new_dict());
	// context.get("rewards", _resource_site_claim_rewards(site)): the fallback is evaluated either way.
	const Value claim_rewards = dict_value(_resource_site_claim_rewards(state, site));
	const Atom reward = _describe_reward_delta(state, state.get(context, str(key::rewards), claim_rewards));
	const Atom happened = _sentence_with_keyword_or_default(state, message, site_name, gd::format(state, key::secured_s, {str(site_name)}));
	const ArrayRef affected_parts = state.new_array();
	state.append(affected_parts, str(site_name));
	state.append(affected_parts, str(tile));
	if (reward != key::empty) {
		state.append(affected_parts, str(gd::format(state, key::reward_s, {str(reward)})));
	}
	const Atom affected = join_array(state, key::space_bar_space, _non_empty_strings(state, affected_parts));
	const Atom why = _resource_site_post_action_why(state, site);
	const Atom next_step = _post_action_next_step(state, session);
	const Atom reward_cue = reward != key::empty ? gd::format(state, key::space_bar_space_s, {str(_short_player_text(state, reward, 46))}) : key::empty;
	const Atom cue_text = gd::format(state, key::s_secured_s, {str(site_name), str(reward_cue)});
	const DictRef recap = _post_action_recap_payload(state, key::resource_site, happened, affected, why, next_step, cue_text);
	_rules_profile_add_ms(state, key::post_action_recap_resource_ms, recap_started_usec);
	return recap;
}

DictRef _artifact_post_action_recap(State &state, DictRef session, DictRef context, Atom message) {
	const int64_t recap_started_usec = _rules_profile_timer(state);
	const Atom artifact_id = ai::string_or_empty(state, context, key::artifact_id);
	const Atom artifact_name = artifact_rules::artifact_name(state, artifact_id);
	const Atom happened = _sentence_with_keyword_or_default(state, message, artifact_name, gd::format(state, key::recovered_s, {str(artifact_name)}));
	const Atom tile = _post_action_tile_label(state, context, state.new_dict());
	const Atom reward_role = artifact_rules::artifact_reward_role(state, artifact_id);
	const Atom effect_summary = artifact_rules::artifact_effect_summary(state, artifact_id);
	const Atom affected = gd::format(state, key::s_at_s_s_s, {str(artifact_name), str(tile), str(reward_role), str(effect_summary)});
	const Atom next_step = _post_action_next_step(state, session);
	const Atom cue_effect = _short_player_text(state, artifact_rules::artifact_effect_summary(state, artifact_id), 46);
	const Atom cue_text = gd::format(state, key::s_recovered_s, {str(artifact_name), str(cue_effect)});
	const DictRef recap = _post_action_recap_payload(state, key::artifact, happened, affected, key::artifacts_change_the_hero_s_field, next_step, cue_text);
	_rules_profile_add_ms(state, key::post_action_recap_artifact_ms, recap_started_usec);
	return recap;
}

DictRef _site_response_post_action_recap(State &state, DictRef session, DictRef context, Atom message) {
	const DictRef node = _post_action_resource_node(state, session, context);
	const Value node_site_id = state.get(node, str(key::site_id), str(key::empty));
	const DictRef site = gd::content_row(state, ContentTable::ResourceSite, gd::stringify(state, state.get(context, str(key::site_id), node_site_id)));
	const Atom site_name = gd::stringify(state, state.get(site, str(key::name), str(key::the_site)));
	const Atom tile = _post_action_tile_label(state, context, node);
	const Atom affected = gd::format(state, key::s_at_s_s, {str(site_name), str(tile), str(key::response_order_updated)});
	Atom impact_summary = key::route_response_active;
	const Atom happened = _first_sentence_or_default(state, message, gd::format(state, key::s_response_order_issued, {str(site_name)}));
	const Atom impact_clause = impact_summary == key::empty ? static_cast<Atom>(key::empty) : gd::format(state, key::and_s, {str(impact_summary)});
	const Atom why = gd::format(state, key::response_orders_turn_site_control_into, {str(impact_clause)});
	const Atom next_step = _post_action_next_step(state, session);
	const Atom cue_text = gd::format(state, key::s_response_active_s, {str(site_name), str(_short_player_text(state, impact_summary, 46))});
	return _post_action_recap_payload(state, key::site_response, happened, affected, why, next_step, cue_text);
}

DictRef _spell_post_action_recap(State &state, DictRef session, DictRef context, Atom message) {
	const Atom spell_name = gd::stringify(state, state.get(context, str(key::spell_name), str(key::field_spell)));
	const Atom happened = _first_sentence_or_default(state, message, gd::format(state, key::s_resolved, {str(spell_name)}));
	const Atom target_text = public_text_of(state, context, key::target_contract, key::active_hero_was_the_target);
	const Atom consequence_text = public_text_of(state, context, key::consequence_preview, key::field_state_changed);
	const int64_t current = movement_int(state, session, key::current);
	const int64_t max_movement = movement_int(state, session, key::max);
	const Atom affected = gd::format(state, key::s_s_move_d_d, {str(target_text), str(consequence_text), int_value(current), int_value(max_movement)});
	const Atom next_step = _post_action_next_step(state, session);
	const Atom cue_text = gd::format(state, key::s_cast_move_d_d, {str(spell_name), int_value(current), int_value(max_movement)});
	return _post_action_recap_payload(state, key::spell, happened, affected, key::field_magic_converts_mana_into_bounded, next_step, cue_text);
}

DictRef _town_capture_post_action_recap(State &state, DictRef session, DictRef context, Atom message) {
	const DictRef town_result = _find_town_by_placement(state, session, ai::string_or_empty(state, context, key::placement_id));
	const DictRef town = gd::as_dict(field_or_new_dict(state, town_result, key::town));
	const Atom town_name = !gd::is_empty(state, town) ? _town_name(state, town) : static_cast<Atom>(key::the_town_2);
	const Atom happened = _first_sentence_or_default(state, message, gd::format(state, key::captured_s, {str(town_name)}));
	const Atom tile = _post_action_tile_label(state, context, town);
	const Atom affected = gd::format(state, key::s_at_s_control_changed, {str(town_name), str(tile)});
	const Atom next_step = _post_action_next_step(state, session);
	const Atom cue_text = gd::format(state, key::s_captured_check_town_orders, {str(town_name)});
	return _post_action_recap_payload(state, key::town_capture, happened, affected, key::town_control_changes_recruitment_economy_defense, next_step, cue_text);
}

DictRef _town_visit_post_action_recap(State &state, DictRef session, DictRef context, Atom message) {
	const DictRef town_result = _find_town_by_placement(state, session, ai::string_or_empty(state, context, key::placement_id));
	const DictRef town = gd::as_dict(field_or_new_dict(state, town_result, key::town));
	const Atom town_name = !gd::is_empty(state, town) ? _town_name(state, town) : gd::stringify(state, state.get(context, str(key::label), str(key::the_town_2)));
	const Atom happened = _first_sentence_or_default(state, message, gd::format(state, key::s_opens_its_gates, {str(town_name)}));
	const Atom tile = _post_action_tile_label(state, context, town);
	const Atom affected = gd::format(state, key::s_at_s, {str(town_name), str(tile)});
	const Atom cue_text = gd::format(state, key::s_opened_choose_town_orders, {str(town_name)});
	return _post_action_recap_payload(state, key::town_visit, happened, affected, key::entering_town_converts_field_position_into, key::review_build_or_recruit_orders_then, cue_text);
}

DictRef _battle_post_action_recap(State &state, DictRef session, DictRef context, Atom message) {
	const Atom placement_id = ai::string_or_empty(state, context, key::placement_id);
	const DictRef encounter_result = _find_encounter_by_placement(state, session, placement_id);
	const DictRef encounter = gd::as_dict(state.get(encounter_result, str(key::encounter), dict_value(context)));
	const Atom label = encounter_display_name(state, encounter);
	const Atom happened = _sentence_with_keyword_or_default(state, message, label, gd::format(state, key::battle_is_joined_against_s, {str(label)}));
	const Atom tile = _post_action_tile_label(state, context, encounter);
	const Atom readability = describe_encounter_compact_readability(state, session, encounter);
	const Atom affected = gd::format(state, key::s_at_s_s, {str(label), str(tile), str(readability)});
	const Atom cue_text = gd::format(state, key::s_engaged_resolve_battle, {str(label)});
	return _post_action_recap_payload(state, key::battle, happened, affected, key::clearing_the_guard_can_open_routes, key::resolve_the_battle_then_check_the, cue_text);
}

DictRef _generic_post_action_recap(State &state, DictRef session, Atom action_kind, DictRef context, Atom message) {
	(void)context;
	const Vector2i pos = hero_position(state, session);
	const Atom happened = _first_sentence_or_default(state, message, key::order_resolved);
	const Atom affected = gd::format(state, key::active_hero_at_d_d, {int_value(pos.x), int_value(pos.y)});
	const Atom next_step = _post_action_next_step(state, session);
	const Atom cue_head = _short_player_text(state, _first_sentence_or_default(state, message, key::order_resolved), 52);
	const Atom cue_text = gd::format(state, key::s_d_d_2, {str(cue_head), int_value(pos.x), int_value(pos.y)});
	return _post_action_recap_payload(state, action_kind, happened, affected, key::resolved_orders_change_the_live_route, next_step, cue_text);
}

DictRef _post_action_recap_payload(State &state, Atom kind, Atom happened, Atom affected, Atom why_it_matters, Atom next_step, Atom cue_text) {
	const DictRef recap = state.new_dict();
	state.set(recap, str(key::mode), str(key::compact));
	state.set(recap, str(key::kind), str(kind));
	state.set(recap, str(key::happened), str(_short_player_text(state, gd::strip_edges(state, happened), 180)));
	state.set(recap, str(key::affected), str(_short_player_text(state, gd::strip_edges(state, affected), 180)));
	state.set(recap, str(key::why_it_matters), str(_short_player_text(state, gd::strip_edges(state, why_it_matters), 180)));
	state.set(recap, str(key::next_step_2), str(_short_player_text(state, gd::strip_edges(state, next_step), 140)));
	state.set(recap, str(key::cue_text), str(_short_player_text(state, gd::strip_edges(state, cue_text), 96)));
	const Atom tooltip_text = gd::format(state, key::action_recap_happened_s_affected_s, {
			str(ai::string_or_empty(state, recap, key::happened)),
			str(ai::string_or_empty(state, recap, key::affected)),
			str(ai::string_or_empty(state, recap, key::why_it_matters)),
			str(ai::string_or_empty(state, recap, key::next_step_2)),
	});
	state.set(recap, str(key::tooltip_text), str(tooltip_text));
	return _normalize_post_action_recap(state, dict_value(recap));
}

DictRef _normalize_post_action_recap(State &state, const Value &value) {
	if (!gd::is_dict(value)) {
		return state.new_dict();
	}
	const DictRef recap = value.ref;
	const Atom happened = gd::strip_edges(state, ai::string_or_empty(state, recap, key::happened));
	const Atom affected = gd::strip_edges(state, ai::string_or_empty(state, recap, key::affected));
	const Atom why = gd::strip_edges(state, ai::string_or_empty(state, recap, key::why_it_matters));
	const Atom next_step = gd::strip_edges(state, ai::string_or_empty(state, recap, key::next_step_2));
	if (happened == key::empty || affected == key::empty || why == key::empty || next_step == key::empty) {
		return state.new_dict();
	}
	const Atom cue_text = gd::strip_edges(state, gd::stringify(state, state.get(recap, str(key::cue_text), str(happened))));
	Atom tooltip_text = gd::strip_edges(state, ai::string_or_empty(state, recap, key::tooltip_text));
	if (tooltip_text == key::empty) {
		tooltip_text = gd::format(state, key::action_recap_happened_s_affected_s, {str(happened), str(affected), str(why), str(next_step)});
	}
	const DictRef normalized = state.new_dict();
	state.set(normalized, str(key::mode), str(gd::stringify(state, state.get(recap, str(key::mode), str(key::compact)))));
	state.set(normalized, str(key::kind), str(gd::stringify(state, state.get(recap, str(key::kind), str(key::action)))));
	state.set(normalized, str(key::happened), str(happened));
	state.set(normalized, str(key::affected), str(affected));
	state.set(normalized, str(key::why_it_matters), str(why));
	state.set(normalized, str(key::next_step_2), str(next_step));
	state.set(normalized, str(key::cue_text), str(cue_text));
	state.set(normalized, str(key::tooltip_text), str(tooltip_text));
	return normalized;
}

DictRef _post_action_tile_context(State &state, DictRef session, Vector2i tile) {
	const DictRef profile = ai::static_dict(state, key::overworld_rules_script, key::_pathing_debug_profile);
	if (gd::bool_field(state, profile, key::capture_enabled, false)) {
		state.set(profile, str(key::post_action_tile_context_scan_count), int_value(gd::add(gd::int_field(state, profile, key::post_action_tile_context_scan_count, 0), 1)));
	}
	for (const Value &node_value : gd::field_items(state, session_view::overworld(state, session), str(key::resource_nodes))) {
		if (!gd::is_dict(node_value)) {
			continue;
		}
		const DictRef node = node_value.ref;
		if (gd::int_field(state, node, key::x, -1) == tile.x && gd::int_field(state, node, key::y, -1) == tile.y) {
			const DictRef context = state.new_dict();
			state.set(context, str(key::type), str(key::resource));
			state.set(context, str(key::placement_id), str(ai::string_or_empty(state, node, key::placement_id)));
			state.set(context, str(key::site_id), str(ai::string_or_empty(state, node, key::site_id)));
			state.set(context, str(key::x), int_value(tile.x));
			state.set(context, str(key::y), int_value(tile.y));
			return context;
		}
	}
	for (const Value &node_value : gd::field_items(state, session_view::overworld(state, session), str(key::artifact_nodes))) {
		if (!gd::is_dict(node_value)) {
			continue;
		}
		const DictRef node = node_value.ref;
		if (gd::int_field(state, node, key::x, -1) == tile.x && gd::int_field(state, node, key::y, -1) == tile.y) {
			const DictRef context = state.new_dict();
			state.set(context, str(key::type), str(key::artifact));
			state.set(context, str(key::artifact_id), str(ai::string_or_empty(state, node, key::artifact_id)));
			state.set(context, str(key::x), int_value(tile.x));
			state.set(context, str(key::y), int_value(tile.y));
			return context;
		}
	}
	for (const Value &encounter_value : gd::field_items(state, session_view::overworld(state, session), str(key::encounters))) {
		if (!gd::is_dict(encounter_value)) {
			continue;
		}
		const DictRef encounter = encounter_value.ref;
		if (gd::int_field(state, encounter, key::x, -1) == tile.x && gd::int_field(state, encounter, key::y, -1) == tile.y) {
			const Value id_fallback = state.get(encounter, str(key::id), str(key::empty));
			const Atom placement_id = gd::stringify(state, state.get(encounter, str(key::placement_id), id_fallback));
			const Atom encounter_id = gd::stringify(state, state.get(encounter, str(key::encounter_id), id_fallback));
			const Atom label = encounter_display_name(state, encounter);
			const DictRef context = state.new_dict();
			state.set(context, str(key::type), str(key::encounter));
			state.set(context, str(key::placement_id), str(placement_id));
			state.set(context, str(key::encounter_id), str(encounter_id));
			state.set(context, str(key::label), str(label));
			state.set(context, str(key::x), int_value(tile.x));
			state.set(context, str(key::y), int_value(tile.y));
			return context;
		}
	}
	for (const Value &town_value : gd::field_items(state, session_view::overworld(state, session), str(key::towns))) {
		if (!gd::is_dict(town_value)) {
			continue;
		}
		const DictRef town = town_value.ref;
		if (gd::int_field(state, town, key::x, -1) == tile.x && gd::int_field(state, town, key::y, -1) == tile.y) {
			const Atom placement_id = ai::string_or_empty(state, town, key::placement_id);
			const Atom label = _town_name(state, town);
			const DictRef context = state.new_dict();
			state.set(context, str(key::type), str(key::town));
			state.set(context, str(key::placement_id), str(placement_id));
			state.set(context, str(key::label), str(label));
			state.set(context, str(key::x), int_value(tile.x));
			state.set(context, str(key::y), int_value(tile.y));
			return context;
		}
	}
	const DictRef context = state.new_dict();
	state.set(context, str(key::type), str(key::open));
	state.set(context, str(key::x), int_value(tile.x));
	state.set(context, str(key::y), int_value(tile.y));
	return context;
}

DictRef _post_action_resource_node(State &state, DictRef session, DictRef context) {
	const Atom placement_id = ai::string_or_empty(state, context, key::placement_id);
	const DictRef node_result = _find_resource_node_by_placement(state, session, placement_id);
	if (gd::int_field(state, node_result, key::index, -1) >= 0) {
		return gd::as_dict(field_or_new_dict(state, node_result, key::node));
	}
	const DictRef node = state.new_dict();
	state.set(node, str(key::placement_id), str(placement_id));
	state.set(node, str(key::site_id), str(ai::string_or_empty(state, context, key::site_id)));
	state.set(node, str(key::x), int_value(gd::int_field(state, context, key::x, 0)));
	state.set(node, str(key::y), int_value(gd::int_field(state, context, key::y, 0)));
	return node;
}

Atom _post_action_tile_label(State &state, DictRef context, DictRef fallback) {
	const int64_t x = gd::to_int(state, state.get(context, str(key::x), state.get(fallback, str(key::x), int_value(0))));
	const int64_t y = gd::to_int(state, state.get(context, str(key::y), state.get(fallback, str(key::y), int_value(0))));
	return tile_text(state, x, y);
}

Atom _post_action_next_step(State &state, DictRef session) {
	const int64_t next_step_started_usec = _rules_profile_timer(state);
	_rules_profile_set(state, key::post_action_recap, key::next_step_mode, str(key::compact));
	_rules_profile_set(state, key::post_action_recap, key::objective_feed_used, bool_value(false));
	if (movement_int(state, session, key::current) <= 0) {
		_rules_profile_add_ms(state, key::post_action_next_step_ms, next_step_started_usec);
		return key::end_the_turn_after_checking_exposed;
	}
	_rules_profile_add_ms(state, key::post_action_next_step_ms, next_step_started_usec);
	return key::choose_the_next_route_step_site;
}

Atom _resource_site_post_action_why(State &state, DictRef site) {
	std::vector<Atom> reasons;
	if (_resource_site_is_persistent(state, site)) {
		const Atom income_summary = _describe_resource_delta(state, field_or_new_dict(state, site, key::control_income));
		if (income_summary != key::empty) {
			const Atom cadence = ascii_lower(state, _resource_site_income_cadence_label(state, site));
			reasons.push_back(gd::format(state, key::adds_s_s, {str(cadence), str(income_summary)}));
		}
		if (!gd::is_empty(state, _resource_site_weekly_recruits(state, site))) {
			reasons.push_back(key::feeds_weekly_recruits);
		}
		if (gd::int_field(state, site, key::vision_radius, 0) > 0) {
			reasons.push_back(key::widens_scouting);
		}
		if (state.has(site, str(key::response_profile))) {
			reasons.push_back(key::opens_route_response);
		}
	} else {
		const Atom reward_summary = _resource_site_reward_summary(state, site);
		if (reward_summary != key::empty) {
			reasons.push_back(gd::format(state, key::adds_s_now, {str(reward_summary)}));
		}
	}
	if (reasons.empty()) {
		return key::site_actions_change_economy_map_control;
	}
	return gd::format(state, key::this_site_s, {str(join_atoms(state, key::comma_space, reasons))});
}

Atom _first_sentence_or_default(State &state, Atom text, Atom fallback) {
	const Atom cleaned = _enemy_activity_public_text(state, text);
	if (cleaned == key::empty) {
		return fallback;
	}
	// cleaned.find(". ") and cleaned.left(sentence_end + 1): ". " is ASCII, so the
	// byte offset ends the same characters.
	const std::string cleaned_text = state.text(cleaned);
	const size_t sentence_end = cleaned_text.find(". ");
	if (sentence_end != std::string::npos) {
		return state.intern(cleaned_text.substr(0, sentence_end + 1));
	}
	return cleaned;
}

Atom _sentence_with_keyword_or_default(State &state, Atom text, Atom keyword, Atom fallback) {
	const Atom cleaned = _enemy_activity_public_text(state, text);
	const Atom needle = gd::strip_edges(state, keyword);
	if (cleaned == key::empty || needle == key::empty) {
		return _first_sentence_or_default(state, text, fallback);
	}
	const std::string needle_text = state.text(needle);
	for (const std::string &piece : split_without_empty(state.text(cleaned), state.text(key::period_space_text))) {
		const Atom sentence = gd::strip_edges(state, state.intern(piece));
		if (sentence == key::empty) {
			continue;
		}
		if (state.text(sentence).find(needle_text) != std::string::npos) {
			return gd::ends_with(state, sentence, key::period) ? sentence : gd::format(state, key::s_4, {str(sentence)});
		}
	}
	return _first_sentence_or_default(state, text, fallback);
}

} // namespace overworld_rules

} // namespace aurelion::rules::port
