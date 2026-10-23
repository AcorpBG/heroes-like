#pragma once

// scripts/persistence/NativeRandomMapPackageSessionBridge.gd: a new game's
// session from the generated map's documents (docs/native-rules-engine-
// transition.md, Phase 7, 7.11; native_random_map_package_session_bridge.cpp),
// ported function by function under the GDScript names. A map or scenario
// document is a MapDocument or ScenarioDocument object (an opaque Value) or
// null: the rules call its methods (gd::call_method). A session the bridge
// builds is a SessionData object (session_state_store::new_session_data).

#include "aurelion_rules/port/gd.hpp"
#include "aurelion_rules/port/overworld_rules.hpp"

#include <cstdint>

namespace aurelion::rules::port::native_random_map_package_session_bridge {

using gd::ArrayRef;
using gd::Atom;
using gd::DictRef;
using overworld_rules::Vector2i;
using state::State;
using state::Value;

Value build_session_from_adoption(State &state, DictRef adoption, Atom difficulty, DictRef options);
Value build_session_from_loaded_packages(State &state, DictRef map_load, DictRef scenario_load, DictRef boundary, Atom difficulty, DictRef options);
DictRef _primary_start(State &state, DictRef adoption);
Atom _primary_hero_id(State &state, const Value &scenario_document, Atom fallback);
DictRef _hero_state(State &state, Atom hero_id, DictRef start, Atom difficulty);
DictRef _army_state(State &state, DictRef army_template);
ArrayRef _opening_enemy_states(State &state, ArrayRef players);
DictRef _opening_resource_stockpile(State &state);
DictRef _map_size_from_document(State &state, const Value &map_document, DictRef metrics);
DictRef _terrain_layers_from_document(State &state, const Value &map_document);
ArrayRef _map_rows_from_document(State &state, const Value &map_document);
Atom _terrain_id_for_code(State &state, const Value &ids_by_code, int64_t code);
ArrayRef _document_objects(State &state, const Value &map_document);
ArrayRef _town_states_from_objects(State &state, ArrayRef objects);
DictRef _project_town_identity_from_h3m_record(State &state, DictRef object);
DictRef _project_town_identity_for_h3m_token(State &state, Atom token);
Atom _project_town_id_for_faction(State &state, Atom faction_id);
int64_t _int_or_default(State &state, const Value &value, int64_t default_value);
bool _bool_or_default(State &state, const Value &value, bool default_value);
ArrayRef _resource_nodes_from_objects(State &state, ArrayRef objects, ArrayRef towns, ArrayRef map_rows);
ArrayRef boats_from_objects(State &state, ArrayRef objects);
ArrayRef _artifact_nodes_from_objects(State &state, ArrayRef objects);
ArrayRef _encounters_from_objects(State &state, ArrayRef objects);
ArrayRef _ensure_generated_rare_source_guards(State &state, ArrayRef resource_nodes, ArrayRef encounters);
ArrayRef _ensure_generated_guarded_reward_site_guards(State &state, ArrayRef resource_nodes, ArrayRef encounters, const Value &map_size);
bool _generated_guarded_reward_site_contract_is_live(State &state, DictRef site);
DictRef _supplemental_guarded_reward_site_guard(State &state, DictRef node, DictRef site, const Value &map_size);
ArrayRef _generated_guarded_reward_engagement_tiles(State &state, DictRef visit_tile, const Value &map_size);
bool _generated_resource_node_is_rare_source(State &state, DictRef node);
bool _resource_node_has_linked_guard(State &state, ArrayRef encounters, DictRef node);
DictRef _supplemental_rare_source_guard(State &state, DictRef node);
bool _generated_source_in_bounds(State &state, Vector2i tile, const Value &map_size);
ArrayRef _map_objects_from_objects(State &state, ArrayRef source_objects);
Atom _resource_site_id_for_object(State &state, DictRef object);
Atom _live_rare_site_id_for_h3m_mine(State &state, DictRef object);
DictRef _runtime_scenario_record_from_documents(State &state, Atom scenario_id, const Value &map_document, const Value &scenario_document, DictRef overworld_state, Atom hero_id, DictRef start);
Atom _player_faction_from_document(State &state, const Value &scenario_document, DictRef overworld_state);

} // namespace aurelion::rules::port::native_random_map_package_session_bridge
