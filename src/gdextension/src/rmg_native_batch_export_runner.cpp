#include "rmg_native_batch_export_runner.hpp"

#include "map_document.hpp"
#include "map_package_service.hpp"

#include <godot_cpp/classes/dir_access.hpp>
#include <godot_cpp/classes/file_access.hpp>
#include <godot_cpp/classes/json.hpp>
#include <godot_cpp/classes/os.hpp>
#include <godot_cpp/classes/project_settings.hpp>
#include <godot_cpp/classes/scene_tree.hpp>
#include <godot_cpp/core/class_db.hpp>
#include <godot_cpp/variant/array.hpp>
#include <godot_cpp/variant/dictionary.hpp>
#include <godot_cpp/variant/packed_string_array.hpp>
#include <godot_cpp/variant/string.hpp>

#include <algorithm>
#include <vector>

using namespace godot;

namespace {

constexpr const char *OWNER_H3M_DIR = "res://maps/h3m-maps";
constexpr const char *DEFAULT_OUTPUT_DIR = ".artifacts/rmg_native_batch_export_native";
constexpr const char *REPORT_SCHEMA_ID = "rmg_native_batch_export_native_v1";

String arg_value(const String &name, const String &fallback) {
	OS *os = OS::get_singleton();
	if (os == nullptr) {
		return fallback;
	}
	const PackedStringArray args = os->get_cmdline_user_args();
	for (int32_t index = 0; index + 1 < args.size(); ++index) {
		if (args[index] == name) {
			return args[index + 1];
		}
	}
	return fallback;
}

int32_t limit_from_args() {
	const String raw = arg_value("--limit", "0");
	return raw.to_int();
}

Array arg_values(const String &name) {
	Array result;
	OS *os = OS::get_singleton();
	if (os == nullptr) {
		return result;
	}
	const PackedStringArray args = os->get_cmdline_user_args();
	for (int32_t index = 0; index + 1 < args.size(); ++index) {
		if (args[index] == name) {
			result.append(args[index + 1]);
			index += 1;
		}
	}
	return result;
}

Array case_filter_from_args() {
	Array result;
	const String raw = arg_value("--case", "");
	if (raw.strip_edges().is_empty()) {
		return result;
	}
	const PackedStringArray values = raw.split(",", false);
	for (int32_t index = 0; index < values.size(); ++index) {
		const String value = values[index].strip_edges();
		if (!value.is_empty()) {
			result.append(value);
		}
	}
	return result;
}

bool array_has_string(const Array &values, const String &needle) {
	for (int64_t index = 0; index < values.size(); ++index) {
		if (String(values[index]) == needle) {
			return true;
		}
	}
	return false;
}

bool arg_present(const String &name) {
	OS *os = OS::get_singleton();
	if (os == nullptr) {
		return false;
	}
	const PackedStringArray args = os->get_cmdline_user_args();
	for (int32_t index = 0; index < args.size(); ++index) {
		if (args[index] == name) {
			return true;
		}
	}
	return false;
}

String size_class_for_file(const String &lower_name) {
	if (lower_name.begins_with("s-")) {
		return "homm3_small";
	}
	if (lower_name.begins_with("l-")) {
		return "homm3_large";
	}
	if (lower_name.begins_with("xl-")) {
		return "homm3_extra_large";
	}
	return "homm3_medium";
}

int32_t dimension_for_size_class(const String &size_class_id) {
	if (size_class_id == "homm3_medium") {
		return 72;
	}
	if (size_class_id == "homm3_large") {
		return 108;
	}
	if (size_class_id == "homm3_extra_large") {
		return 144;
	}
	return 36;
}

String water_mode_for_file(const String &lower_name) {
	if (lower_name.contains("island")) {
		return "islands";
	}
	if ((lower_name.contains("normalw") || lower_name.contains("normalwater") || lower_name.contains("water"))
			&& !lower_name.contains("nowater") && !lower_name.contains("no-water")) {
		return "normal_water";
	}
	return "land";
}

bool supported_strict_land_case(const String &file_name) {
	const String lower_name = file_name.to_lower();
	const String size_class_id = size_class_for_file(lower_name);
	const String water_mode = water_mode_for_file(lower_name);
	const int32_t level_count = lower_name.contains("2level") ? 2 : 1;
	return (size_class_id == "homm3_small" || size_class_id == "homm3_medium") && water_mode == "land" && level_count == 1;
}

int32_t player_count_for_file(const String &lower_name, const String &size_class_id) {
	if (lower_name.contains("2players")) {
		return 2;
	}
	if (lower_name.contains("4players")) {
		return 4;
	}
	if (size_class_id == "homm3_small") {
		return 3;
	}
	if (size_class_id == "homm3_medium") {
		return 4;
	}
	return 5;
}

String case_id_from_file_name(const String &file_name) {
	String id = file_name.get_basename().to_lower();
	const char *replace_chars[] = { " ", "-", ".", "(", ")", "[", "]" };
	for (const char *character : replace_chars) {
		id = id.replace(character, "_");
	}
	while (id.contains("__")) {
		id = id.replace("__", "_");
	}
	return id.strip_edges();
}

Dictionary build_native_random_map_config(const String &seed, int32_t player_count, const String &water_mode, int32_t level_count, const String &size_class_id, int32_t human_count = 1, int32_t computer_count = -1) {
	const int32_t dimension = dimension_for_size_class(size_class_id);
	Dictionary size;
	size["preset"] = "native_batch_export";
	size["size_class_id"] = size_class_id;
	size["source_width"] = dimension;
	size["source_height"] = dimension;
	size["requested_width"] = dimension;
	size["requested_height"] = dimension;
	size["width"] = dimension;
	size["height"] = dimension;
	size["water_mode"] = water_mode == "normal_water" ? String("normal_water") : (water_mode == "islands" ? String("islands") : String("land"));
	size["level_count"] = std::max<int32_t>(1, level_count);

	Dictionary player_constraints;
	int32_t clamped_player_count = std::max<int32_t>(2, std::min<int32_t>(8, player_count));
	const int32_t clamped_human_count = std::max<int32_t>(1, std::min<int32_t>(8, human_count));
	const int32_t clamped_computer_count = computer_count >= 0 ? std::max<int32_t>(0, std::min<int32_t>(8 - clamped_human_count, computer_count)) : std::max<int32_t>(0, clamped_player_count - clamped_human_count);
	clamped_player_count = std::max<int32_t>(2, std::min<int32_t>(8, computer_count >= 0 ? clamped_human_count + clamped_computer_count : clamped_player_count));
	player_constraints["human_count"] = clamped_human_count;
	player_constraints["player_count"] = clamped_player_count;
	player_constraints["computer_count"] = clamped_computer_count;
	player_constraints["team_mode"] = "free_for_all";

	Dictionary profile;
	profile["id"] = "";
	profile["template_id"] = "";
	profile["guard_strength_profile"] = "normal";
	profile["faction_ids"] = Array();

	Dictionary template_selection;
	template_selection["mode"] = "native_catalog_auto";
	template_selection["selection_deferred_to_native"] = true;
	template_selection["fallback_template_id"] = "";
	template_selection["fallback_profile_id"] = "";

	Dictionary config;
	config["generator_version"] = "native_rmg_batch_export_runner";
	config["seed"] = seed;
	config["size"] = size;
	config["player_constraints"] = player_constraints;
	config["profile"] = profile;
	config["template_selection"] = template_selection;
	return config;
}

String controlled_size_class(const String &raw) {
	const String value = raw.to_lower();
	if (value == "small" || value == "s" || value == "homm3_small") {
		return "homm3_small";
	}
	if (value == "medium" || value == "m" || value == "homm3_medium") {
		return "homm3_medium";
	}
	if (value == "large" || value == "l" || value == "homm3_large") {
		return "homm3_large";
	}
	if (value == "extra_large" || value == "xl" || value == "homm3_extra_large") {
		return "homm3_extra_large";
	}
	return "homm3_small";
}

Dictionary config_for_owner_file(const String &file_name, const String &case_id) {
	const String lower_name = file_name.to_lower();
	const String size_class_id = size_class_for_file(lower_name);
	const String water_mode = water_mode_for_file(lower_name);
	const int32_t level_count = lower_name.contains("2level") ? 2 : 1;
	const int32_t player_count = player_count_for_file(lower_name, size_class_id);
	return build_native_random_map_config("0", player_count, water_mode, level_count, size_class_id);
}

Array controlled_cases_from_args() {
	Array result;
	Array raw_cases = arg_values("--controlled-case");
	for (int64_t index = 0; index < raw_cases.size(); ++index) {
		const String raw = String(raw_cases[index]).strip_edges();
		if (raw.is_empty()) {
			continue;
		}
		const PackedStringArray fields = raw.split(":", false);
		if (fields.size() < 6) {
			Dictionary invalid;
			invalid["id"] = String("invalid_controlled_case_") + String::num_int64(index + 1);
			invalid["owner_path"] = "";
			invalid["parse_error"] = "expected id:size_class:players:seed:water_mode:level_count[:human_count[:computer_count]]";
			invalid["raw"] = raw;
			invalid["config"] = build_native_random_map_config("0", 2, "land", 1, "homm3_small");
			result.append(invalid);
			continue;
		}
		const String case_id = fields[0].strip_edges();
		const String size_class_id = controlled_size_class(fields[1].strip_edges());
		const int32_t player_count = std::max<int32_t>(2, std::min<int32_t>(8, fields[2].strip_edges().to_int()));
		const String seed = fields[3].strip_edges();
		const String water_mode = fields[4].strip_edges();
		const int32_t level_count = std::max<int32_t>(1, fields[5].strip_edges().to_int());
		const int32_t human_count = fields.size() >= 7 ? std::max<int32_t>(1, fields[6].strip_edges().to_int()) : player_count;
		const int32_t computer_count = fields.size() >= 8 ? std::max<int32_t>(0, fields[7].strip_edges().to_int()) : -1;
		Dictionary record;
		record["id"] = case_id.is_empty() ? String("controlled_case_") + String::num_int64(index + 1) : case_id;
		record["owner_path"] = "";
		record["file_name"] = "";
		record["controlled_case_spec"] = raw;
		record["config"] = build_native_random_map_config(seed, player_count, water_mode, level_count, size_class_id, human_count, computer_count);
		result.append(record);
	}
	return result;
}

Dictionary profile_brief(const Dictionary &profile) {
	if (profile.is_empty()) {
		return Dictionary();
	}
	Dictionary result;
	result["schema_id"] = String(profile.get("schema_id", ""));
	result["total_elapsed_msec"] = double(profile.get("total_elapsed_msec", 0.0));
	result["top_phase_id"] = String(profile.get("top_phase_id", ""));
	result["top_phase_elapsed_msec"] = double(profile.get("top_phase_elapsed_msec", 0.0));
	result["microseconds_per_tile"] = double(profile.get("microseconds_per_tile", 0.0));
	return result;
}

Dictionary pick_fields(const Dictionary &source, const std::vector<String> &fields) {
	Dictionary result;
	for (const String &field : fields) {
		if (source.has(field)) {
			result[field] = source.get(field, Variant());
		}
	}
	return result;
}

Dictionary h3maped_phase_counter_summary(const Dictionary &generated) {
	if (generated.has("h3maped_phase_counter_summary")) {
		return generated.get("h3maped_phase_counter_summary", Dictionary());
	}
	Dictionary report = generated.get("h3maped_small_port", Dictionary());
	Dictionary result;
	result["schema_id"] = "rmg_native_batch_export_phase_counter_summary_v1";
	if (report.is_empty()) {
		result["status"] = "missing_h3maped_phase_report";
		return result;
	}
	result["status"] = "available";
	result["coordinate_replay"] = pick_fields(Dictionary(report.get("coordinate_replay", Dictionary())), {
			"status",
			"placement_step_count",
			"blanket_refinement_pass_count",
			"coordinate_prune_span_budget_4a218c",
			"coordinate_prune_divisor_4a218c",
			"coordinate_rng_calls_during_0x4a1f3b",
			"town_choice_rng_calls_during_0x4a218c",
			"total_interleaved_rng_calls_during_0x4a218c",
			"bounding_box_rescale",
			"scaled_zone_coordinates",
	});
	result["town_castle"] = pick_fields(Dictionary(report.get("town_castle_phase", Dictionary())), {
			"status",
			"source_player_min_town_count",
			"source_player_min_castle_count",
			"source_neutral_min_town_count",
			"source_neutral_min_castle_count",
			"density_schedule_count",
			"project_town_record_candidate_count",
			"project_player_start_candidate_count",
			"project_neutral_town_candidate_count",
			"direct_record_projection_count",
			"direct_footprint_missing_count",
			"weighted_continuation_density_retired_count",
	});
	result["object_vector"] = pick_fields(Dictionary(report.get("mines_rewards_and_object_vector", Dictionary())), {
			"status",
			"materialized_private_mine_coordinate_record_count",
			"materialized_private_mine_guard_record_count",
			"materialized_private_adjacent_resource_record_count",
			"primary_category_selected_count",
			"primary_category_guard_coordinate_record_count",
			"reward_scheduler_preview_attempt_count",
			"reward_scheduler_density_loop_attempt_capacity_total",
			"reward_scheduler_retired_band_total",
			"reward_scheduler_budget_argument_total",
			"reward_object_lookup_count",
			"reward_object_lookup_selected_count",
			"reward_coordinate_selected_count",
			"reward_guard_coordinate_record_count",
			"partial_coordinate_record_count",
	});
	result["roads_and_rivers"] = pick_fields(Dictionary(report.get("roads_and_rivers", Dictionary())), {
			"status",
			"generator_coordinate_record_count",
			"road_template_link_seed_count",
				"road_template_link_pair_count",
				"restrict_medium_roads_to_template_links",
				"unlinked_route_pair_count",
				"rejected_unlinked_route_pair_count",
			"pair_candidate_iteration_count",
			"candidate_accepted_by_threshold_count",
			"accepted_predecessor_chain_count",
			"road_overlay_cell_count",
			"road_overlay_art_nonzero_count",
	});
	result["generated_cell_decoration_bit_state"] = pick_fields(Dictionary(report.get("generated_cell_decoration_bit_state", Dictionary())), {
			"status",
			"decor_candidate_set_count",
			"final_decor_candidate_bit_26_count",
			"final_occupied_blocked_bit_27_count",
			"cleanup_decor_candidate_write_count",
			"water_edge_decor_candidate_write_count",
			"junction_decor_candidate_write_count",
	});
	result["decorative_obstacle_filler"] = pick_fields(Dictionary(report.get("decorative_obstacle_filler", Dictionary())), {
			"status",
			"decor_candidate_bit_26_count_before_filler",
			"occupied_blocked_bit_27_count_before_filler",
			"generated_flagged_cell_count",
			"generated_valid_flagged_cell_count",
			"invalid_flagged_progress_only_count",
			"raw_budget_argument_to_0x49e700",
			"budget_argument_to_0x49e700",
			"cell_call_count",
			"rejected_no_candidates_count",
			"rejected_footprint_count",
			"rejected_49e1bf_score_count",
			"rejected_town_connectivity_count",
			"expanded_anchor_candidate_count",
			"duplicate_expanded_anchor_candidate_count",
			"private_decorative_obstacle_record_count",
			"private_decorative_object_placement_count",
			"private_decorative_marked_body_cell_count",
			"private_remaining_candidate_0x49a932_lock_count",
			"post_stamp_rectangle_cell_scan_count",
			"post_stamp_rectangle_bit26_cleared_count",
			"post_stamp_rectangle_bit26_clear_skipped_count",
			"rng_call_count",
	});
	result["public_package_adoption"] = pick_fields(Dictionary(report.get("public_package_adoption", Dictionary())), {
			"status",
			"package_object_count",
			"town_package_object_count",
			"neutral_town_package_object_count",
			"road_package_tile_count",
			"road_package_segment_count",
			"decorative_obstacle_package_object_count",
			"reward_package_object_count",
			"mine_package_object_count",
			"primary_category_package_object_count",
	});
	return result;
}

Dictionary export_case(const Ref<MapPackageService> &service, Dictionary case_record, const String &output_dir, const String &absolute_output_dir, int64_t case_index, bool emit_phase_snapshot) {
	Dictionary config = case_record.get("config", Dictionary());
	if (!case_record.has("controlled_case_spec")) {
		config["seed"] = String::num_int64(case_index + 1);
	}
	case_record["config"] = config;
	const String case_id = String(case_record.get("id", "case"));

	Dictionary generation_options;
	generation_options["include_h3maped_small_port"] = emit_phase_snapshot;
	Dictionary generated = service->generate_random_map(config, generation_options);
	Dictionary normalized = generated.get("normalized_config", Dictionary());
	Dictionary object_summary = generated.get("object_placement_pipeline_summary", Dictionary());
	Dictionary town_guard_summary = generated.get("town_guard_placement", Dictionary());

	Dictionary record;
	record["id"] = case_id;
	record["owner_path"] = String(case_record.get("owner_path", ""));
	record["config"] = config;
	record["template_id"] = String(normalized.get("template_id", ""));
	record["profile_id"] = String(normalized.get("profile_id", ""));
	record["size_class_id"] = String(normalized.get("size_class_id", ""));
	record["water_mode"] = String(normalized.get("water_mode", ""));
	record["level_count"] = int32_t(normalized.get("level_count", 0));
	record["generation_ok"] = bool(generated.get("ok", false));
	record["generation_status"] = String(generated.get("full_generation_status", ""));
	record["validation_status"] = String(generated.get("validation_status", ""));
	record["h3maped_template_selection"] = generated.get("h3maped_template_selection", Dictionary());
	record["h3maped_phase_counters"] = h3maped_phase_counter_summary(generated);
	record["extension_profile"] = profile_brief(Dictionary(generated.get("extension_profile", Dictionary())));
	record["object_runtime_profile"] = profile_brief(Dictionary(object_summary.get("runtime_phase_profile", Dictionary())));
	record["town_guard_runtime_profile"] = profile_brief(Dictionary(town_guard_summary.get("runtime_phase_profile", Dictionary())));
	if (emit_phase_snapshot) {
		const String phase_file_name = case_id + String(".phase_snapshot.json");
		const String phase_path = absolute_output_dir.path_join(phase_file_name);
		Ref<FileAccess> phase_file = FileAccess::open(phase_path, FileAccess::WRITE);
		if (phase_file.is_null()) {
			record["phase_snapshot_status"] = "write_failed";
			record["phase_snapshot_path"] = phase_path;
		} else {
			Dictionary snapshot;
			snapshot["schema_id"] = "rmg_native_batch_export_phase_snapshot_v1";
			snapshot["case_id"] = case_id;
			snapshot["config"] = config;
			snapshot["h3maped_template_selection"] = generated.get("h3maped_template_selection", Dictionary());
			snapshot["h3maped_small_port"] = generated.get("h3maped_small_port", Dictionary());
			phase_file->store_string(JSON::stringify(snapshot, "\t", true, false));
			phase_file->close();
			record["phase_snapshot_status"] = "written";
			record["phase_snapshot_path"] = phase_path;
			record["phase_snapshot_project_relative_path"] = output_dir.path_join(phase_file_name);
		}
	}

	if (!bool(generated.get("ok", false))) {
		record["status"] = "generation_failed";
		record["error"] = generated.get("validation_report", generated);
		return record;
	}

	Dictionary adoption_options;
	adoption_options["feature_gate"] = "rmg_native_batch_export_native";
	adoption_options["session_save_version"] = 9;
	adoption_options["scenario_id"] = "rmg_native_batch_export_" + case_id;
	Dictionary adoption = service->convert_generated_payload(generated, adoption_options);
	record["conversion_profile"] = profile_brief(Dictionary(adoption.get("conversion_profile", Dictionary())));
	if (!bool(adoption.get("ok", false))) {
		record["status"] = "conversion_failed";
		record["error"] = adoption;
		record["generated_validation_report"] = generated.get("validation_report", Dictionary());
		return record;
	}

	Variant map_document_value = adoption.get("map_document", Variant());
	if (map_document_value.get_type() != Variant::OBJECT) {
		record["status"] = "conversion_failed";
		record["error"] = "missing_map_document";
		return record;
	}
	Object *map_document_object = Object::cast_to<Object>(map_document_value);
	Ref<MapDocument> map_document(Object::cast_to<MapDocument>(map_document_object));
	if (map_document.is_null()) {
		record["status"] = "conversion_failed";
		record["error"] = "missing_map_document";
		return record;
	}

	const String native_file_name = case_id + String(".amap");
	const String native_path = absolute_output_dir.path_join(native_file_name);
	Dictionary save_options;
	save_options["path_policy"] = "artifact_rmg_native_batch_export_native";
	save_options["return_package"] = false;
	Dictionary save_result = service->save_map_package(map_document, native_path, save_options);
	Dictionary save_report = save_result.get("report", Dictionary());
	Dictionary save_summary;
	save_summary["ok"] = bool(save_result.get("ok", false));
	save_summary["status"] = String(save_report.get("status", ""));
	save_summary["package_hash"] = String(save_result.get("package_hash", ""));
	save_summary["path"] = String(save_result.get("path", native_path));
	record["native_path"] = native_path;
	record["native_project_relative_path"] = output_dir.path_join(native_file_name);
	record["save"] = save_summary;
	record["status"] = bool(save_result.get("ok", false)) ? String("exported") : String("save_failed");
	return record;
}

Array owner_cases(bool include_unsupported) {
	std::vector<Dictionary> records;
	ProjectSettings *settings = ProjectSettings::get_singleton();
	const String absolute_owner_dir = settings != nullptr ? settings->globalize_path(OWNER_H3M_DIR) : String(OWNER_H3M_DIR);
	Ref<DirAccess> dir = DirAccess::open(absolute_owner_dir);
	if (dir.is_null()) {
		return Array();
	}
	PackedStringArray files = dir->get_files();
	for (int32_t index = 0; index < files.size(); ++index) {
		const String file_name = files[index];
		if (!file_name.to_lower().ends_with(".h3m")) {
			continue;
		}
		if (!include_unsupported && !supported_strict_land_case(file_name)) {
			continue;
		}
		const String case_id = case_id_from_file_name(file_name);
		Dictionary record;
		record["id"] = case_id;
		record["owner_path"] = String(OWNER_H3M_DIR).path_join(file_name);
		record["file_name"] = file_name;
		record["config"] = config_for_owner_file(file_name, case_id);
		records.push_back(record);
	}
	std::sort(records.begin(), records.end(), [](const Dictionary &left, const Dictionary &right) {
		return String(left.get("id", "")) < String(right.get("id", ""));
	});
	Array result;
	for (const Dictionary &record : records) {
		result.append(record);
	}
	return result;
}

void write_manifest_and_quit(Node *node, Dictionary manifest, int32_t exit_code) {
	const String manifest_path = String(manifest.get("absolute_output_dir", "")).path_join("manifest.json");
	Ref<FileAccess> file = FileAccess::open(manifest_path, FileAccess::WRITE);
	if (file.is_null()) {
		manifest["status"] = "partial";
		manifest["manifest_write_error"] = "failed_to_open_manifest";
		manifest["manifest_path"] = manifest_path;
	} else {
		file->store_string(JSON::stringify(manifest, "\t", true, false));
		file->close();
		manifest["manifest_path"] = manifest_path;
	}
	print_line("RMG_NATIVE_BATCH_EXPORT " + JSON::stringify(manifest));
	SceneTree *tree = node->get_tree();
	if (tree != nullptr) {
		tree->quit(exit_code);
	}
}

} // namespace

void RmgNativeBatchExportRunner::_bind_methods() {}

void RmgNativeBatchExportRunner::_ready() {
	const String output_dir = arg_value("--out", DEFAULT_OUTPUT_DIR);
	const int32_t limit = limit_from_args();
	const Array case_filter = case_filter_from_args();
	ProjectSettings *settings = ProjectSettings::get_singleton();
	const String absolute_output_dir = settings != nullptr ? settings->globalize_path(output_dir) : output_dir;

	Dictionary manifest;
	manifest["schema_id"] = REPORT_SCHEMA_ID;
	manifest["status"] = "exported";
	manifest["owner_h3m_dir"] = OWNER_H3M_DIR;
	manifest["output_dir"] = output_dir;
	manifest["absolute_output_dir"] = absolute_output_dir;
	manifest["case_limit"] = limit;
	manifest["case_filter"] = case_filter;
	manifest["case_count"] = 0;
	manifest["exported_count"] = 0;
	manifest["failed_count"] = 0;
	manifest["export_runner"] = "native_gdextension_node_invoked_by_python_no_gdscript";
	manifest["case_scope"] = arg_present("--include-unsupported") ? String("all_owner_cases_including_unsupported") : String("strict_small_medium_one_level_land_only");
	manifest["cases"] = Array();

	if (DirAccess::make_dir_recursive_absolute(absolute_output_dir) != OK) {
		manifest["status"] = "failed";
		manifest["error"] = "output_dir_create_failed";
		write_manifest_and_quit(this, manifest, 1);
		return;
	}

	Array controlled_cases = controlled_cases_from_args();
	Array cases = controlled_cases.is_empty() ? owner_cases(arg_present("--include-unsupported")) : controlled_cases;
	if (!controlled_cases.is_empty()) {
		manifest["case_scope"] = "explicit_controlled_cases";
		manifest["controlled_case_count"] = controlled_cases.size();
	}
	Array filtered_cases;
	for (int64_t index = 0; index < cases.size(); ++index) {
		Dictionary record = cases[index];
		if (!case_filter.is_empty() && !array_has_string(case_filter, String(record.get("id", "")))) {
			continue;
		}
		filtered_cases.append(record);
		if (limit > 0 && filtered_cases.size() >= limit) {
			break;
		}
	}
	manifest["case_count"] = filtered_cases.size();

	Ref<MapPackageService> service;
	service.instantiate();
	if (service.is_null()) {
		manifest["status"] = "failed";
		manifest["error"] = "map_package_service_instantiate_failed";
		write_manifest_and_quit(this, manifest, 1);
		return;
	}
	Array records;
	const bool emit_phase_snapshot = arg_present("--emit-phase-snapshot");
	manifest["emit_phase_snapshot"] = emit_phase_snapshot;
	for (int64_t index = 0; index < filtered_cases.size(); ++index) {
		Dictionary record = export_case(service, filtered_cases[index], output_dir, absolute_output_dir, index, emit_phase_snapshot);
		records.append(record);
		if (String(record.get("status", "")) == "exported") {
			manifest["exported_count"] = int32_t(manifest.get("exported_count", 0)) + 1;
		} else {
			manifest["failed_count"] = int32_t(manifest.get("failed_count", 0)) + 1;
		}
	}
	manifest["cases"] = records;
	if (int32_t(manifest.get("failed_count", 0)) > 0) {
		manifest["status"] = "partial";
	}
	write_manifest_and_quit(this, manifest, int32_t(manifest.get("failed_count", 0)) == 0 ? 0 : 1);
}
