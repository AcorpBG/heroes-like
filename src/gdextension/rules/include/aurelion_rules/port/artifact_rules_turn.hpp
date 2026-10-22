#pragma once

// scripts/core/ArtifactRules.gd: the functions the computer players' day runs
// (docs/native-rules-engine-transition.md, Phase 4), ported function by
// function under the GDScript names. A session is its view (session_view.hpp).

#include "aurelion_rules/port/gd.hpp"
#include "aurelion_rules/port/session_view.hpp"
#include "aurelion_rules/port/artifact_rules.hpp"
#include "aurelion_rules/port/overworld_rules.hpp"

#include <cstdint>

namespace aurelion::rules::port::artifact_rules {

using gd::ArrayRef;
using gd::Atom;
using gd::DictRef;
using gd::PackedRef;
using overworld_rules::Vector2i;
using state::State;
using state::Value;

// Ported in artifact_rules_turn.cpp.
Atom _artifact_set_id(State &state, DictRef artifact);
DictRef _artifact_taxonomy_payload(State &state, DictRef artifact);
Atom _artifact_ui_summary(State &state, DictRef artifact);
DictRef artifact_taxonomy(State &state, Atom artifact_id);
Atom artifact_taxonomy_summary(State &state, Atom artifact_id);
Atom describe_artifact(State &state, Atom artifact_id);
Atom live_source_reward_tag(State &state, DictRef source_record);
ArrayRef select_live_source_rewards(State &state, Atom source_tag, DictRef source_record, Atom source_key, Atom faction_id, ArrayRef excluded_artifact_ids);

// Not run by the six seeds: each throws state::NotPorted (turn_not_ported.cpp).
ArrayRef artifact_set_runtime_state(State &state, DictRef hero_state);
bool has_artifact(State &state, DictRef hero_state, Atom artifact_id);
DictRef remove_owned_artifact(State &state, DictRef hero_state, Atom artifact_id);

} // namespace aurelion::rules::port::artifact_rules
