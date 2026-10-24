#pragma once

// The map editor's rules (docs/native-rules-engine-transition.md, Phase 7,
// slice 7.13), ported function by function under the GDScript names:
// MapEditorShell's methods that are no screen code, which take the screen
// first (editor, an object value whose vars are its members), and
// TerrainPlacementRules. A session is an object value or its view.

#include "aurelion_rules/port/gd.hpp"
#include "aurelion_rules/port/overworld_rules.hpp"

#include <cstdint>

namespace aurelion::rules::port::map_editor {

using gd::ArrayRef;
using gd::Atom;
using gd::DictRef;
using overworld_rules::Vector2i;
using state::State;
using state::Value;

// map_editor_common.cpp: the screen's members the rules share.
// self._session = value and self._dirty = value: their setters bump
// _editor_edit_revision. The session goes in as its object.
void set_session(State &state, const Value &editor, const Value &session);
void set_dirty(State &state, const Value &editor, bool dirty);
// self._session (Nil, or the working copy's object) and a session value's
// view (an object value or a view; a ScriptError for Nil).
Value session(State &state, const Value &editor);
DictRef session_view(State &state, const Value &session);
// A session value as its object, for a member, a result or a host call.
Value session_object(State &state, const Value &session);

// map_editor_palette.cpp.
Vector2i _editor_map_direction_for_action(State &state, const Value &editor, Atom action);
Atom _editor_map_cursor_semantic_context(State &state, const Value &editor);
Atom _editor_map_action_result_semantic_text(State &state, const Value &editor);
Atom _bounded_editor_map_semantic_text(State &state, const Value &editor, Atom value, int64_t maximum_characters);
DictRef _editor_tile_payload(State &state, const Value &editor, Vector2i tile);
Atom _property_summary_text(State &state, const Value &editor, DictRef detail);
DictRef _selected_property_handoff_payload(State &state, const Value &editor, DictRef detail);
ArrayRef _property_object_options_at(State &state, const Value &editor, Vector2i tile);
DictRef _selected_property_object_detail(State &state, const Value &editor);
DictRef _object_detail_by_key(State &state, const Value &editor, Atom property_key);
DictRef _selected_property_object_payload(State &state, const Value &editor);
DictRef _property_object_payload_from_detail(State &state, const Value &editor, DictRef detail);
DictRef _pending_move_object_payload(State &state, const Value &editor);
DictRef _pending_duplicate_object_payload(State &state, const Value &editor);
bool _select_property_object_at_tile(State &state, const Value &editor, Atom family);
DictRef _apply_object_property_value(State &state, const Value &editor, Atom property_name, const Value &value);
Atom _property_object_label(State &state, const Value &editor, DictRef detail);
ArrayRef _terrain_items(State &state, const Value &editor);
DictRef _terrain_class_index(State &state, const Value &editor, DictRef grammar);
Atom _terrain_label_for_id(State &state, const Value &editor, Atom terrain_id);
ArrayRef _terrain_option_payload(State &state, const Value &editor);
ArrayRef _terrain_option_ids(State &state, const Value &editor);
ArrayRef _authored_terrain_ids(State &state, const Value &editor);
ArrayRef _hidden_terrain_ids(State &state, const Value &editor);
ArrayRef _object_content_items(State &state, const Value &editor, Atom family);
Atom _object_content_path(State &state, const Value &editor, Atom family);
Atom _object_content_label(State &state, const Value &editor, DictRef entry);
DictRef _object_content_taxonomy_payload(State &state, const Value &editor, Atom family, Atom content_id);
DictRef _town_taxonomy_payload(State &state, const Value &editor, DictRef town);
DictRef _artifact_taxonomy_payload(State &state, const Value &editor, DictRef artifact);
DictRef _resource_taxonomy_payload(State &state, const Value &editor, DictRef node, DictRef site);
DictRef _encounter_taxonomy_payload(State &state, const Value &editor, DictRef placement, DictRef encounter);
Atom _taxonomy_summary_text(State &state, const Value &editor, DictRef payload);
Atom _taxonomy_inline_text(State &state, const Value &editor, DictRef payload);
Atom _taxonomy_link_line(State &state, const Value &editor, DictRef payload);
Atom _taxonomy_role_line(State &state, const Value &editor, DictRef payload);
ArrayRef _identity_summary_lines_for_editor(State &state, const Value &editor, DictRef payload, int64_t limit);
ArrayRef _recruit_source_summary_lines_for_editor(State &state, const Value &editor, DictRef payload, int64_t limit);
Atom _object_palette_guidance_text(State &state, const Value &editor, DictRef payload, DictRef guidance);
Vector2i _placement_preview_tile(State &state, const Value &editor);
DictRef _selected_object_placement_preview_payload(State &state, const Value &editor, Vector2i tile);
DictRef _build_selected_object_placement_preview_payload(State &state, const Value &editor, Vector2i tile);

// map_editor_checks.cpp.
DictRef _editor_object_preview_check_payload(State &state, const Value &editor);
DictRef _editor_acceptance_cue_payload(State &state, const Value &editor);
DictRef _editor_placement_action_cue_payload(State &state, const Value &editor);
DictRef _editor_terrain_paint_check_payload(State &state, const Value &editor, Atom tool);
DictRef _editor_road_check_payload(State &state, const Value &editor, Atom tool);
Vector2i _terrain_paint_preview_tile(State &state, const Value &editor, Atom tool);
Vector2i _road_check_preview_tile(State &state, const Value &editor);
int64_t _road_check_existing_count(State &state, const Value &editor, ArrayRef path_tiles);
int64_t _terrain_changed_tile_count(State &state, const Value &editor, ArrayRef tiles, Atom terrain_id);
DictRef _set_object_authoring_recap(State &state, const Value &editor, Atom action, bool changed, DictRef before_detail, DictRef after_detail, Vector2i from_tile, Vector2i to_tile, DictRef preview, Atom property_name, const Value &previous_value, const Value &new_value);
DictRef _object_authoring_recap_payload(State &state, const Value &editor, Atom action, bool changed, DictRef before_detail, DictRef after_detail, Vector2i from_tile, Vector2i to_tile, DictRef preview, Atom property_name, const Value &previous_value, const Value &new_value);
Atom _object_action_headline(State &state, const Value &editor, Atom action, bool changed, DictRef before_detail, DictRef after_detail, Vector2i from_tile, Vector2i to_tile, Atom property_name, const Value &previous_value, const Value &new_value);
Atom _object_action_label(State &state, const Value &editor, Atom action, bool changed);
Atom _object_recap_label(State &state, const Value &editor, DictRef detail);
Atom _dependency_recap_line(State &state, const Value &editor, DictRef detail);
Atom _object_action_why_line(State &state, const Value &editor, Atom action, DictRef detail, DictRef preview, Atom property_name);
Atom _object_action_next_check(State &state, const Value &editor, Atom action, DictRef detail, DictRef preview, Atom property_name);
Atom _compact_join_limited(State &state, const Value &editor, ArrayRef lines, int64_t limit);
Atom _editor_variant_text(State &state, const Value &editor, const Value &value);

// map_editor_guidance.cpp.
DictRef _placement_availability_for_selected_object(State &state, const Value &editor, Vector2i tile);
Atom _first_placement_label_at_tile(State &state, const Value &editor, Vector2i tile);
ArrayRef _placement_context_lines(State &state, const Value &editor, Atom family, Atom content_id, DictRef payload, Vector2i tile);
Atom _placement_terrain_context_line(State &state, const Value &editor, Vector2i tile);
Atom _placement_faction_context_line(State &state, const Value &editor, Atom family, Atom content_id, Vector2i tile);
DictRef _nearest_town_context(State &state, const Value &editor, Vector2i tile);
Atom _placement_economy_context_line(State &state, const Value &editor, Atom family, Atom content_id);
Atom _placement_route_context_line(State &state, const Value &editor, Vector2i tile);
Atom _placement_dependency_context_line(State &state, const Value &editor, DictRef payload, Vector2i tile);
Atom _placement_dependency_warning(State &state, const Value &editor, DictRef payload);
Atom _density_warning_for_guidance(State &state, const Value &editor, DictRef guidance, bool can_place);
int64_t _density_target_upper_bound(State &state, const Value &editor, Atom target);
Atom _placement_authoring_consequence(State &state, const Value &editor, Atom family, Atom content_id, DictRef payload, DictRef guidance);
DictRef _placement_guidance_payload(State &state, const Value &editor, DictRef payload, Vector2i tile);
Atom _selected_tile_authoring_dependency_text(State &state, const Value &editor);
DictRef _authoring_dependencies_for_detail(State &state, const Value &editor, DictRef detail);
ArrayRef _objective_links_for_placement(State &state, const Value &editor, Atom placement_id);
ArrayRef _guard_links_for_placement(State &state, const Value &editor, Atom kind, Atom placement_id, Atom content_id);
ArrayRef _route_links_for_placement(State &state, const Value &editor, Atom kind, Atom placement_id, Atom content_id, ArrayRef guard_links);
ArrayRef _reward_links_for_placement(State &state, const Value &editor, Atom placement_id, ArrayRef objective_links);
ArrayRef _enemy_focus_links_for_placement(State &state, const Value &editor, Atom placement_id);
ArrayRef _authoring_warnings_for_detail(State &state, const Value &editor, DictRef detail, ArrayRef objective_links, ArrayRef guard_links, ArrayRef reward_links, ArrayRef enemy_focus_links);
Value _editor_validation_memo_lookup(State &state, const Value &editor, Atom key);

// map_editor_validation.cpp.
DictRef _scenario_authoring_validation_payload(State &state, const Value &editor);
DictRef _build_scenario_authoring_validation_payload(State &state, const Value &editor);
DictRef _all_current_placement_ids(State &state, const Value &editor);
DictRef _guard_link_for_detail(State &state, const Value &editor, DictRef detail);
DictRef _guard_link_for_editor(State &state, const Value &editor, DictRef encounter);
bool _guard_target_present_for_editor(State &state, const Value &editor, DictRef guard);
Atom _guard_target_label_for_editor(State &state, const Value &editor, DictRef guard);
Atom _placement_label_for_editor(State &state, const Value &editor, Atom placement_id);
Atom _effect_label_for_editor(State &state, const Value &editor, DictRef effect);
DictRef _placement_role_flags(State &state, const Value &editor, DictRef payload);
Atom _role_flags_text(State &state, const Value &editor, DictRef flags);
Atom _placement_role_label(State &state, const Value &editor, DictRef payload, DictRef flags);
DictRef _density_guidance_for_payload(State &state, const Value &editor, DictRef payload, DictRef flags);
int64_t _local_density_count(State &state, const Value &editor, Vector2i tile, Atom density_group);
DictRef _density_region_bounds(State &state, const Value &editor, Vector2i tile);
Atom _density_group_for_placement(State &state, const Value &editor, Atom family, DictRef placement);
Atom _fallback_resource_primary_class(State &state, const Value &editor, DictRef site);
ArrayRef _fallback_resource_tags(State &state, const Value &editor, DictRef site);
Atom _fallback_resource_cadence(State &state, const Value &editor, DictRef site);
Atom _fallback_passability_class(State &state, const Value &editor, DictRef map_object, Atom family);
Atom _fallback_encounter_role(State &state, const Value &editor, ArrayRef tags);
Atom _risk_from_difficulty(State &state, const Value &editor, Atom difficulty);
Atom _encounter_detail_summary(State &state, const Value &editor, DictRef encounter, DictRef placement, Atom risk, Atom role, DictRef guard);
Atom _footprint_summary(State &state, const Value &editor, const Value &value);
Atom _tag_summary_for_editor(State &state, const Value &editor, const Value &value, int64_t limit);
ArrayRef _string_array_for_editor(State &state, const Value &editor, const Value &value);
Atom _humanize_editor_id(State &state, const Value &editor, Atom value);
Atom _resource_delta_text(State &state, const Value &editor, DictRef resources);

// map_editor_working_copy.cpp.
bool _open_maps_folder_package_entry(State &state, const Value &editor, DictRef entry);
Atom _editor_level_support_block_message(State &state, const Value &editor, const Value &session, Atom label);
Value _duplicate_session(State &state, const Value &editor, const Value &session);
bool _resume_working_copy_session(State &state, const Value &editor, const Value &session, const Value &baseline_session, DictRef package_identity);
void _make_all_tiles_visible(State &state, const Value &editor, const Value &session);
DictRef _editor_label_texts(State &state, const Value &editor);
Atom _current_scenario_display_name(State &state, const Value &editor);
Atom _selected_map_package_label(State &state, const Value &editor);
Atom _map_package_label_for_id(State &state, const Value &editor, Atom package_id);
Atom _tool_label(State &state, const Value &editor, Atom tool);
void _set_tool(State &state, const Value &editor, Atom tool);
DictRef _write_package_copy(State &state, const Value &editor, Atom target_dir_override, Atom target_stem_override);
DictRef _finish_package_copy(State &state, const Value &editor, DictRef written);
Atom _unique_package_copy_stem(State &state, const Value &editor, Atom target_dir, Atom base_stem);
DictRef _save_copy_failure(State &state, const Value &editor, Atom code, Atom message, ArrayRef cleanup_paths, DictRef details);

// map_editor_terrain.cpp.
void _edit_selected_object_properties(State &state, const Value &editor, Atom owner, Atom difficulty, bool collected);
void _fill_terrain_tool(State &state, const Value &editor);
void _restore_tile_tool(State &state, const Value &editor);
bool _apply_map_tool(State &state, const Value &editor, Vector2i tile);
bool _paint_terrain(State &state, const Value &editor, Vector2i tile, Atom terrain_id);
DictRef _apply_terrain_placement(State &state, const Value &editor, ArrayRef paint_tiles, Atom terrain_id);
DictRef _materialize_last_terrain_final_normalization(State &state, const Value &editor);
DictRef _fill_terrain_from_selected_tile(State &state, const Value &editor);
bool _terrain_line_tool_click(State &state, const Value &editor, Vector2i tile);
DictRef _apply_terrain_line(State &state, const Value &editor, Vector2i start_tile, Vector2i end_tile, Atom terrain_id);
ArrayRef _terrain_line_tiles(State &state, const Value &editor, Vector2i start_tile, Vector2i end_tile);
bool _terrain_rectangle_tool_click(State &state, const Value &editor, Vector2i tile);
DictRef _apply_terrain_rectangle(State &state, const Value &editor, Vector2i corner_tile, Vector2i opposite_tile, Atom terrain_id);
ArrayRef _terrain_rectangle_tiles(State &state, const Value &editor, Vector2i corner_tile, Vector2i opposite_tile);
DictRef _terrain_rectangle_bounds(State &state, const Value &editor, Vector2i corner_tile, Vector2i opposite_tile);
DictRef _fill_terrain_region(State &state, const Value &editor, Vector2i start_tile, Atom terrain_id);
bool _toggle_road(State &state, const Value &editor, Vector2i tile);
bool _road_path_tool_click(State &state, const Value &editor, Vector2i tile);
DictRef _apply_road_path(State &state, const Value &editor, Vector2i start_tile, Vector2i end_tile, Atom requested_action);
ArrayRef _road_path_tiles(State &state, const Value &editor, Vector2i start_tile, Vector2i end_tile);
ArrayRef _manhattan_l_path_tiles(State &state, const Value &editor, Vector2i start_tile, Vector2i end_tile);
bool _all_road_path_tiles_have_roads(State &state, const Value &editor, ArrayRef path_tiles);
ArrayRef _add_road_tiles(State &state, const Value &editor, ArrayRef path_tiles);
ArrayRef _remove_road_tiles(State &state, const Value &editor, ArrayRef path_tiles);
DictRef _road_tile_keys_from_layers(State &state, const Value &editor, ArrayRef roads);
bool _has_pending_terrain_line_start(State &state, const Value &editor);
DictRef _pending_terrain_line_start_payload(State &state, const Value &editor);
bool _has_pending_terrain_rectangle_corner(State &state, const Value &editor);
DictRef _pending_terrain_rectangle_corner_payload(State &state, const Value &editor);
bool _has_pending_road_path_start(State &state, const Value &editor);
DictRef _pending_road_path_start_payload(State &state, const Value &editor);
ArrayRef _tile_array_payload(State &state, const Value &editor, ArrayRef tiles);
int64_t _editor_road_layer_index(State &state, const Value &editor, ArrayRef roads);

// map_editor_objects.cpp.
bool _set_hero_start(State &state, const Value &editor, Vector2i tile);
bool _set_hero_position(State &state, const Value &editor, Vector2i tile);
bool _place_object(State &state, const Value &editor, Vector2i tile);
bool _remove_object(State &state, const Value &editor, Vector2i tile);
bool _move_object_tool_click(State &state, const Value &editor, Vector2i tile);
DictRef _preferred_move_detail_at(State &state, const Value &editor, Vector2i tile);
DictRef _move_object_by_key(State &state, const Value &editor, Atom property_key, Vector2i destination_tile);
bool _duplicate_object_tool_click(State &state, const Value &editor, Vector2i tile);
DictRef _duplicate_object_by_key(State &state, const Value &editor, Atom property_key, Vector2i destination_tile);
bool _retheme_object(State &state, const Value &editor, Vector2i tile);
DictRef _object_detail_for_family_at(State &state, const Value &editor, Vector2i tile, Atom family);
DictRef _retheme_object_by_key(State &state, const Value &editor, Atom property_key, Atom replacement_content_id);
DictRef _first_blocking_object_detail_at(State &state, const Value &editor, Vector2i tile, Atom ignored_property_key);
DictRef _apply_object_properties(State &state, const Value &editor, DictRef detail, Atom owner, Atom difficulty, bool collected);
DictRef _set_town_owner_property(State &state, const Value &editor, Atom placement_id, Atom owner);
DictRef _set_encounter_difficulty_property(State &state, const Value &editor, Atom placement_id, Atom difficulty);
DictRef _set_collected_property(State &state, const Value &editor, Atom family, Atom placement_id, bool collected);
DictRef _build_runtime_placement(State &state, const Value &editor, Atom family, Atom content_id, Atom placement_id, Vector2i tile);
void _remove_resolved_encounter_ids(State &state, const Value &editor, ArrayRef placement_ids);
DictRef _restore_selected_tile_from_authored(State &state, const Value &editor);
Value _authored_baseline_session(State &state, const Value &editor);
DictRef _restore_tile_terrain_from_baseline(State &state, const Value &editor, Vector2i tile, const Value &baseline);
DictRef _restore_tile_roads_from_baseline(State &state, const Value &editor, Vector2i tile, const Value &baseline);
DictRef _restore_tile_hero_start_from_baseline(State &state, const Value &editor, Vector2i tile, const Value &baseline);
DictRef _restore_tile_objects_from_baseline(State &state, const Value &editor, Vector2i tile, const Value &baseline);
ArrayRef _placements_for_family_at_in_session(State &state, const Value &editor, const Value &session, Atom family, Vector2i tile);
ArrayRef _road_layers_at_in_overworld(State &state, const Value &editor, DictRef overworld, Vector2i tile);
DictRef _authored_road_tile_payload(State &state, const Value &editor, DictRef road, Vector2i tile);
DictRef _tile_payload_for_restore(State &state, const Value &editor, const Value &value, Vector2i tile);
bool _tile_payload_matches(State &state, const Value &editor, const Value &value, Vector2i tile);
Atom _terrain_at_in_overworld(State &state, const Value &editor, DictRef overworld, Vector2i tile);
bool _set_tile_terrain(State &state, const Value &editor, Vector2i tile, Atom terrain_id);
void _remove_stale_editor_object_keys(State &state, const Value &editor);

// map_editor_export.cpp.
bool _stage_working_copy_for_play(State &state, const Value &editor);
DictRef _editor_play_readiness_gate_payload(State &state, const Value &editor);
DictRef _editor_scenario_validation_check_payload(State &state, const Value &editor);
DictRef _save_copy_readiness_payload(State &state, const Value &editor);
DictRef _save_copy_draft_payload(State &state, const Value &editor);
Atom _missing_scenario_template_blocker(State &state, const Value &editor);
ArrayRef _save_copy_validation_blockers(State &state, const Value &editor);
DictRef _editor_scenario_objectives(State &state, const Value &editor);
DictRef _editor_scenario_template(State &state, const Value &editor);
DictRef _export_scenario_record_from_working_copy(State &state, const Value &editor, DictRef baseline_scenario);
DictRef _export_scenario_record_from_session(State &state, const Value &editor, DictRef baseline_scenario, const Value &session);
DictRef _export_terrain_layers_record_from_working_copy(State &state, const Value &editor);
DictRef _export_terrain_layers_record_from_layers(State &state, const Value &editor, DictRef layers);
ArrayRef _normalized_export_map(State &state, const Value &editor, const Value &map_value);
ArrayRef _normalized_export_roads(State &state, const Value &editor, const Value &roads_value);
ArrayRef _normalized_export_positions(State &state, const Value &editor, const Value &values);
ArrayRef _normalized_export_placements(State &state, const Value &editor, Atom family, const Value &placements_value);
DictRef _package_source_object_record(State &state, const Value &editor, Atom placement_id);
bool _placement_belongs_in_saved_package(State &state, const Value &editor, DictRef placement);
ArrayRef _normalized_export_map_objects(State &state, const Value &editor, const Value &objects_value);
void _copy_optional_dict(State &state, const Value &editor, DictRef target, DictRef source, Atom key);
void _copy_optional_string(State &state, const Value &editor, DictRef target, DictRef source, Atom key);
void _copy_optional_bool(State &state, const Value &editor, DictRef target, DictRef source, Atom key);
void _copy_optional_positive_int(State &state, const Value &editor, DictRef target, DictRef source, Atom key);
ArrayRef _validate_export_scenario_record(State &state, const Value &editor, DictRef record);
ArrayRef _validate_export_terrain_layers_record(State &state, const Value &editor, DictRef record);

// map_editor_handoffs.cpp.
DictRef _editor_map_load_handoff_payload(State &state, const Value &editor);
DictRef _editor_scenario_switch_handoff_payload(State &state, const Value &editor);
DictRef _editor_selected_validation_focus_payload(State &state, const Value &editor);
DictRef _selected_validation_focus_counts(State &state, const Value &editor, ArrayRef details);
Atom _selected_validation_focus_summary(State &state, const Value &editor, DictRef counts);
DictRef _editor_play_handoff_payload(State &state, const Value &editor);
DictRef _editor_play_return_context_payload(State &state, const Value &editor);
DictRef _editor_restore_tile_cue_payload(State &state, const Value &editor);
DictRef _tile_authoring_signature_for_session(State &state, const Value &editor, const Value &session, Vector2i tile);
ArrayRef _tile_authoring_delta_labels(State &state, const Value &editor, DictRef current_signature, DictRef authored_signature);
Atom _tile_authoring_signature_summary(State &state, const Value &editor, DictRef signature);
DictRef _editor_menu_return_payload(State &state, const Value &editor);

// map_editor_inspection.cpp.
DictRef _editor_active_tool_cue_payload(State &state, const Value &editor, Atom tool);
Atom _selected_object_content_label(State &state, const Value &editor);
void _prepare_working_copy_snapshot_for_return(State &state, const Value &editor);
void _prepare_working_copy_for_play(State &state, const Value &editor, const Value &session);
DictRef consume_safe_close_guard_confirmation(State &state, const Value &editor, Atom source);
Atom _tile_inspection_text(State &state, const Value &editor, Vector2i tile);
ArrayRef _object_lines_at(State &state, const Value &editor, Vector2i tile);
void _append_taxonomy_object_lines(State &state, const Value &editor, ArrayRef lines, DictRef detail);
void _append_authoring_dependency_lines(State &state, const Value &editor, ArrayRef lines, DictRef detail);
void _append_resource_control_lines(State &state, const Value &editor, ArrayRef lines, DictRef detail);
DictRef _object_detail_for_placement(State &state, const Value &editor, Atom family, DictRef placement);
ArrayRef _object_details_at(State &state, const Value &editor, Vector2i tile, bool include_hero);
DictRef _object_detail_with_guidance(State &state, const Value &editor, DictRef detail, Vector2i tile);
bool _placement_at_tile(State &state, const Value &editor, DictRef placement, Vector2i tile);
Atom _placement_array_key(State &state, const Value &editor, Atom family);
Atom _placement_content_key(State &state, const Value &editor, Atom family);
Atom _object_property_key(State &state, const Value &editor, Atom kind, Atom placement_id);
ArrayRef _editable_properties_for_object(State &state, const Value &editor, Atom kind);
Atom _primary_editable_property_for_kind(State &state, const Value &editor, Atom kind);
Atom _object_family_label(State &state, const Value &editor, Atom family);
DictRef _object_content_lookup(State &state, const Value &editor, Atom family, Atom content_id);
Atom _generate_editor_placement_id(State &state, const Value &editor, Atom family, Atom content_id, Vector2i tile);
Atom _generate_duplicate_placement_id(State &state, const Value &editor, Atom family, Atom source_placement_id, Vector2i tile);
Atom _safe_id_segment(State &state, const Value &editor, Atom value);
bool _placement_id_exists(State &state, const Value &editor, Atom placement_id);
bool _artifact_content_id_exists(State &state, const Value &editor, Atom artifact_id);
DictRef _terrain_layers(State &state, const Value &editor);
bool _has_road_at(State &state, const Value &editor, Vector2i tile);
ArrayRef _road_layer_ids_at(State &state, const Value &editor, Vector2i tile);
int64_t _road_tile_count(State &state, const Value &editor);
int64_t _placement_count(State &state, const Value &editor);
Atom _terrain_at(State &state, const Value &editor, Vector2i tile);
bool _terrain_id_in_grammar(State &state, const Value &editor, Atom terrain_id);
bool _tile_in_bounds(State &state, const Value &editor, Vector2i tile);
Atom _tile_key(State &state, const Value &editor, Vector2i tile);
DictRef _public_map_package_index_status(State &state, const Value &editor);
DictRef _tile_inspection_payload(State &state, const Value &editor, Vector2i tile);

} // namespace aurelion::rules::port::map_editor

namespace aurelion::rules::port::terrain_placement_rules {

using gd::ArrayRef;
using gd::Atom;
using gd::DictRef;
using overworld_rules::Tiles;
using overworld_rules::Vector2i;
using state::State;
using state::Value;

// terrain_placement_rules.cpp. The three entries take what the GDScript
// takes; apply_paint writes into map_data (its rows' terrain ids, and
// map_data[y] = row). The other functions run on the file's own types:
// Terrain, the map_data, map_size and terrain_grammar the GDScript passes on,
// with the owner ids read so far (by terrain id, and by cell for the paint and
// the final normalization); Context, apply_paint's context Dictionary (the
// terrain, the brush, the changed tiles, set_a and set_b, OrderedPointSets);
// ChangeList, which of the three changed lists _mark_changed keeps; Ring, a
// cell's 8 same-owner flags; Relations, its 8 relations, both in
// NEIGHBOR_OFFSETS order; Projection, 4 quadrant families; Quadrants, an
// edge's quadrants; ClassInfo, Corrected, FrameSelection, RowEntry and
// FullRows, the Dictionaries of _class_result, _apply_final_corrections,
// _select_*_visual_frame, _normal_row_entry and _full_rows_for_normal_table;
// Rows, a const row list.
struct Terrain;
struct Context;
enum class ChangeList : uint8_t;
struct Ring;
struct Relations;
struct Projection;
struct Quadrants;
struct ClassInfo;
struct Corrected;
struct FrameSelection;
struct RowEntry;
struct FullRows;
struct Rows;

DictRef apply_paint(State &state, ArrayRef map_data, Vector2i map_size, Atom brush_terrain_id, ArrayRef paint_tiles, DictRef terrain_grammar, bool include_final_normalization);
DictRef final_normalization_payload(State &state, ArrayRef map_data, Vector2i map_size, DictRef terrain_grammar);
DictRef visual_selection_payload(State &state, ArrayRef map_data, Vector2i map_size, DictRef terrain_grammar, Vector2i tile);
Atom terrain_family_for_id(State &state, DictRef terrain_grammar, Atom terrain_id);
int64_t terrain_owner_id_for_terrain(State &state, DictRef terrain_grammar, Atom terrain_id);
int64_t terrain_owner_id_for_family(State &state, Atom family_id);
Atom terrain_family_for_id_number(State &state, int64_t owner_id);
Atom tile_key(State &state, Vector2i tile);
DictRef vector2i_payload(State &state, Vector2i tile);
ArrayRef tile_array_payload(State &state, const Tiles &tiles);
Tiles _unique_in_bounds_tiles(State &state, ArrayRef tiles, Vector2i map_size);
bool _in_bounds(State &state, Vector2i tile, Vector2i map_size);
Atom _terrain_at(State &state, ArrayRef map_data, Vector2i tile);
void _set_terrain_at(State &state, Terrain &terrain, Vector2i tile, Atom terrain_id);
int64_t _owner_id_at_raw(State &state, Terrain &terrain, Vector2i tile);
int64_t _owner_id_at(State &state, Terrain &terrain, Vector2i tile);
bool _write_brush_terrain(State &state, Vector2i tile, Context &context, bool direct_write, bool owner_write);
void _mark_changed(State &state, Vector2i tile, Context &context, ChangeList list);
void _drain_terrain_placement_queues(State &state, const Tiles &changed_owner_cells, Context &context);
bool _rewrite_to_current_brush(State &state, Vector2i tile, Context &context, bool already_written = false);
void _maintain_normal_neighbor_frontier(State &state, Vector2i tile, Context &context);
void _maintain_special_neighbor_frontier(State &state, Vector2i tile, Context &context);
void _enqueue_secondary_candidates(State &state, Vector2i tile, Context &context);
void _process_frontier_point(State &state, Vector2i tile, Context &context);
Vector2i _choose_vertical_frontier_target(State &state, Vector2i tile, int64_t brush_owner_id, Context &context);
Vector2i _choose_horizontal_frontier_target(State &state, Vector2i tile, int64_t brush_owner_id, Context &context);
bool _should_rewrite_topology_point(State &state, Vector2i tile, Context &context);
bool _is_horizontally_thin(State &state, Vector2i tile, Context &context);
bool _is_vertically_thin(State &state, Vector2i tile, Context &context);
bool _is_horizontally_thin_for_owner(State &state, Vector2i tile, int64_t owner_id, Context &context);
bool _is_vertically_thin_for_owner(State &state, Vector2i tile, int64_t owner_id, Context &context);
std::vector<int64_t> _minimum_fragmented_gap(State &state, Vector2i tile, int64_t owner_id, Context &context);
bool _fragmented_same_owner_ring(State &state, Vector2i tile, int64_t owner_id, Context &context);
Ring _same_owner_ring(State &state, Vector2i tile, int64_t owner_id, Context &context);
int64_t _ring_component_count(State &state, const Ring &values);
int64_t _gap_weight(State &state, const std::vector<int64_t> &slots);
// The counts row by row (map_size.y rows of map_size.x).
std::vector<int64_t> _compute_boundary_counts(State &state, Terrain &terrain);
int64_t _boundary_count_for_cell(State &state, Terrain &terrain, Vector2i tile);
int64_t _relation_between_ids(State &state, int64_t center_id, int64_t neighbor_id);
Relations _relation_ring_for_cell(State &state, Terrain &terrain, Vector2i tile);
bool _has_direct_water_rock_contact(State &state, Terrain &terrain, Vector2i tile);
Projection _owner_footprint_projection(State &state, Terrain &terrain, Vector2i tile);
Projection _contact_material_projection(State &state, Terrain &terrain, Vector2i tile);
Atom _contact_material_for_relation(State &state, Atom owner_family, Atom neighbor_family, int64_t relation);
Projection _normalized_projection_for_owner(State &state, Atom owner_family, const Projection &projection);
void _apply_edge_projection(State &state, Projection &projection, const Quadrants &quadrants, Atom owner_family, Atom material);
Atom _merge_projected_material(State &state, Atom owner_family, Atom current, Atom incoming);
ClassInfo _classify_relations(State &state, const Relations &relations);
ClassInfo _class_result(State &state, int64_t class_code, int64_t flag_a, int64_t flag_b, Atom reason);
int64_t _relation_at(State &state, const Relations &relations, int64_t flag_a, int64_t flag_b, int64_t slot);
Corrected _apply_final_corrections(State &state, int64_t class_code, Terrain &terrain, Vector2i tile, int64_t flag_a, int64_t flag_b);
bool _diagonal_probe_same_owner(State &state, Terrain &terrain, Vector2i tile, int64_t flag_a, int64_t flag_b);
bool _two_step_probe_same_owner(State &state, Terrain &terrain, Vector2i tile, int64_t flag_a, int64_t flag_b);
bool _row_bucket_exists(State &state, int64_t owner_id, int64_t class_code);
FrameSelection _select_visual_frame(State &state, int64_t owner_id, int64_t shape_class, int64_t flag_a, int64_t flag_b, Vector2i tile);
FrameSelection _select_normal_visual_frame(State &state, int64_t owner_id, int64_t shape_class, int64_t flag_a, int64_t flag_b, Vector2i tile);
FrameSelection _select_rock_visual_frame(State &state, int64_t shape_class, int64_t flag_a, int64_t flag_b, Vector2i tile);
RowEntry _normal_row_entry(State &state, Atom table_name, int64_t shape_class);
bool _row_entry_empty(State &state, const RowEntry &row_entry);
FullRows _full_rows_for_normal_table(State &state, Atom table_name, int64_t owner_id, Vector2i tile);
int64_t _special_tile_frequency(State &state, int64_t owner_id);
// The hashed texts (salts) stay C++ strings: they never reach GDScript.
int64_t _choose_visual_frame(State &state, const Rows &rows, int64_t x, int64_t y, const std::string &salt);
int64_t _positive_visual_hash(State &state, const std::string &text);
int64_t _visual_hash(State &state, const std::string &text);
Atom _bridge_family_from_relations(State &state, const Relations &relations);
Atom _visual_frame_block_for(State &state, Atom owner_family, int64_t frame_number, int64_t shape_class);
Atom relation_grid_string(State &state, const Relations &relations);
Atom compact_ranges(State &state, const Rows &indices);
int64_t _trait_flag4(State &state, int64_t owner_id);
int64_t _trait_flag5(State &state, int64_t owner_id);

} // namespace aurelion::rules::port::terrain_placement_rules
