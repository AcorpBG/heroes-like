#include "rmg_data_model.hpp"

#include <godot_cpp/classes/file_access.hpp>
#include <godot_cpp/classes/json.hpp>
#include <godot_cpp/variant/array.hpp>
#include <godot_cpp/variant/string.hpp>
#include <godot_cpp/variant/variant.hpp>

namespace godot::rmg_data_model {
namespace {

constexpr const char *DATA_MODEL_PATH = "res://content/random_map_generator_data_model.json";
constexpr const char *TEMPLATE_CATALOG_PATH = "res://content/random_map_template_catalog.json";
constexpr const char *MAP_OBJECTS_PATH = "res://content/map_objects.json";
constexpr const char *REPORT_SCHEMA_ID = "native_rmg_homm3_generator_data_model_report_v1";

Dictionary failure_record(const String &code, const String &path, const String &message) {
	Dictionary failure;
	failure["code"] = code;
	failure["path"] = path;
	failure["message"] = message;
	return failure;
}

bool has_nonempty_string(const Dictionary &record, const String &key) {
	return record.has(key) && !String(record.get(key, "")).is_empty();
}

bool has_nonempty_array(const Dictionary &record, const String &key) {
	if (!record.has(key) || Variant(record.get(key, Variant())).get_type() != Variant::ARRAY) {
		return false;
	}
	return !Array(record.get(key, Array())).is_empty();
}

bool has_dictionary(const Dictionary &record, const String &key) {
	return record.has(key) && Variant(record.get(key, Variant())).get_type() == Variant::DICTIONARY;
}

Dictionary load_json_dictionary(const String &path, Array &failures) {
	if (!FileAccess::file_exists(path)) {
		failures.append(failure_record("missing_json_file", path, "Required JSON file is missing."));
		return Dictionary();
	}
	Ref<FileAccess> file = FileAccess::open(path, FileAccess::READ);
	if (file.is_null() || !file->is_open()) {
		failures.append(failure_record("unreadable_json_file", path, "Required JSON file could not be opened."));
		return Dictionary();
	}
	Ref<JSON> parser;
	parser.instantiate();
	if (parser->parse(file->get_as_text()) != OK || parser->get_data().get_type() != Variant::DICTIONARY) {
		failures.append(failure_record("invalid_json_dictionary", path, "Required JSON file did not parse as a dictionary."));
		return Dictionary();
	}
	return Dictionary(parser->get_data());
}

Dictionary map_object_index(const Dictionary &map_objects, Array &failures) {
	Dictionary index;
	if (!has_nonempty_array(map_objects, "items")) {
		failures.append(failure_record("invalid_map_objects_catalog", MAP_OBJECTS_PATH, "map_objects.json must expose a non-empty items array."));
		return index;
	}
	Array items = map_objects.get("items", Array());
	for (int64_t item_index = 0; item_index < items.size(); ++item_index) {
		if (Variant(items[item_index]).get_type() != Variant::DICTIONARY) {
			continue;
		}
		Dictionary item = items[item_index];
		const String id = String(item.get("id", ""));
		if (!id.is_empty()) {
			index[id] = item;
		}
	}
	return index;
}

void increment_count(Dictionary &counts, const String &key) {
	counts[key] = int32_t(counts.get(key, 0)) + 1;
}

void append_missing_field_failures(const Dictionary &record, const String &path, const Array &required_keys, Array &failures) {
	for (int64_t index = 0; index < required_keys.size(); ++index) {
		const String key = String(required_keys[index]);
		if (!record.has(key)) {
			failures.append(failure_record("missing_required_field", path + String(".") + key, "Generator data-model record is missing a required field."));
		}
	}
}

bool footprint_valid(const Dictionary &footprint) {
	return int32_t(footprint.get("width", 0)) > 0 && int32_t(footprint.get("height", 0)) > 0 && has_nonempty_string(footprint, "anchor");
}

Dictionary validate_object_definitions(const Dictionary &model, const Dictionary &objects_by_id, Array &failures, Array &warnings) {
	Dictionary metrics;
	Dictionary category_counts;
	Dictionary kind_counts;
	Dictionary definition_keys;
	Array sample_definitions;
	Array required_fields;
	required_fields.append("id");
	required_fields.append("generated_kind");
	required_fields.append("stable_original_object_id");
	required_fields.append("category");
	required_fields.append("footprint");
	required_fields.append("passability");
	required_fields.append("action");
	required_fields.append("terrain_constraints");
	required_fields.append("limits");
	required_fields.append("value_density");
	required_fields.append("writeout");

	if (!has_nonempty_array(model, "object_definitions")) {
		failures.append(failure_record("missing_object_definitions", DATA_MODEL_PATH, "Generator data model must expose object_definitions."));
		metrics["object_definition_count"] = 0;
		return metrics;
	}

	Array definitions = model.get("object_definitions", Array());
	for (int64_t index = 0; index < definitions.size(); ++index) {
		if (Variant(definitions[index]).get_type() != Variant::DICTIONARY) {
			failures.append(failure_record("invalid_object_definition", "object_definitions[" + String::num_int64(index) + "]", "Object definition must be a dictionary."));
			continue;
		}
		Dictionary definition = definitions[index];
		const String path = "object_definitions[" + String::num_int64(index) + "]";
		append_missing_field_failures(definition, path, required_fields, failures);
		const String id = String(definition.get("id", ""));
		const String kind = String(definition.get("generated_kind", ""));
		const String object_id = String(definition.get("stable_original_object_id", ""));
		const String category = String(definition.get("category", ""));
		if (!id.is_empty()) {
			definition_keys[id] = true;
		}
		if (!kind.is_empty() && !object_id.is_empty()) {
			definition_keys[kind + String(":") + object_id] = true;
		}
		if (!kind.is_empty()) {
			increment_count(kind_counts, kind);
		}
		if (!category.is_empty()) {
			increment_count(category_counts, category);
		}
		if (has_dictionary(definition, "footprint") && !footprint_valid(Dictionary(definition.get("footprint", Dictionary())))) {
			failures.append(failure_record("invalid_footprint", path + String(".footprint"), "Footprint must include positive width/height and an anchor."));
		}
		if (has_dictionary(definition, "passability") && !has_nonempty_string(Dictionary(definition.get("passability", Dictionary())), "class")) {
			failures.append(failure_record("invalid_passability", path + String(".passability"), "Passability metadata must include a class."));
		}
		if (has_dictionary(definition, "action") && !has_nonempty_string(Dictionary(definition.get("action", Dictionary())), "class")) {
			failures.append(failure_record("invalid_action", path + String(".action"), "Action metadata must include a class."));
		}
		if (has_dictionary(definition, "writeout") && !has_nonempty_string(Dictionary(definition.get("writeout", Dictionary())), "record_kind")) {
			failures.append(failure_record("invalid_writeout", path + String(".writeout"), "Writeout metadata must include record_kind."));
		}
		if (String(definition.get("content_domain", "map_object")) == "map_object" && !objects_by_id.has(object_id)) {
			failures.append(failure_record("missing_original_map_object", path + String(".stable_original_object_id"), String("Definition references an unknown authored map object id: ") + object_id));
		}
		Array aliases = definition.get("supported_runtime_object_ids", Array());
		for (int64_t alias_index = 0; alias_index < aliases.size(); ++alias_index) {
			const String alias = String(aliases[alias_index]);
			if (!alias.is_empty()) {
				definition_keys[kind + String(":") + alias] = true;
			}
		}
		if (sample_definitions.size() < 8) {
			Dictionary sample;
			sample["id"] = id;
			sample["generated_kind"] = kind;
			sample["stable_original_object_id"] = object_id;
			sample["category"] = category;
			sample_definitions.append(sample);
		}
	}

	static constexpr const char *REQUIRED_KINDS[] = {
		"resource_site",
		"mine",
		"neutral_dwelling",
		"reward_reference",
		"decorative_obstacle",
		"town",
		"guard",
		"special_guard_gate",
	};
	for (const char *required_kind : REQUIRED_KINDS) {
		if (!kind_counts.has(required_kind)) {
			failures.append(failure_record("missing_generated_kind_definition", String("object_definitions.") + required_kind, "Object definitions do not cover a supported generated object kind."));
		}
	}

	metrics["object_definition_count"] = definitions.size();
	metrics["object_definition_category_counts"] = category_counts;
	metrics["object_definition_kind_counts"] = kind_counts;
	metrics["definition_key_count"] = definition_keys.size();
	metrics["definition_keys"] = definition_keys;
	metrics["sample_definitions"] = sample_definitions;
	metrics["warning_count"] = warnings.size();
	return metrics;
}

Dictionary validate_type_metadata(const Dictionary &model, Array &failures) {
	Dictionary metrics;
	Dictionary type_counts;
	if (!has_nonempty_array(model, "object_type_metadata")) {
		failures.append(failure_record("missing_object_type_metadata", DATA_MODEL_PATH, "Generator data model must expose object_type_metadata."));
		metrics["object_type_metadata_count"] = 0;
		return metrics;
	}
	Array types = model.get("object_type_metadata", Array());
	for (int64_t index = 0; index < types.size(); ++index) {
		if (Variant(types[index]).get_type() != Variant::DICTIONARY) {
			failures.append(failure_record("invalid_object_type_metadata", "object_type_metadata[" + String::num_int64(index) + "]", "Object type metadata must be a dictionary."));
			continue;
		}
		Dictionary type_record = types[index];
		const String type_id = String(type_record.get("type_id", ""));
		if (type_id.is_empty()) {
			failures.append(failure_record("missing_type_id", "object_type_metadata[" + String::num_int64(index) + "]", "Object type metadata is missing type_id."));
		} else {
			increment_count(type_counts, type_id);
		}
		if (!has_dictionary(type_record, "operational_flags")) {
			failures.append(failure_record("missing_operational_flags", "object_type_metadata[" + String::num_int64(index) + "]", "Object type metadata must expose operational_flags."));
		}
		if (!has_dictionary(type_record, "limits")) {
			failures.append(failure_record("missing_type_limits", "object_type_metadata[" + String::num_int64(index) + "]", "Object type metadata must expose limits."));
		}
	}
	metrics["object_type_metadata_count"] = types.size();
	metrics["type_id_counts"] = type_counts;
	return metrics;
}

Dictionary validate_template_catalog(const Dictionary &catalog, Array &failures) {
	Dictionary metrics;
	if (!has_nonempty_array(catalog, "templates")) {
		failures.append(failure_record("missing_template_catalog", TEMPLATE_CATALOG_PATH, "Template catalog must expose templates."));
		return metrics;
	}
	Array templates = catalog.get("templates", Array());
	int32_t zone_count = 0;
	int32_t link_count = 0;
	int32_t wide_link_count = 0;
	int32_t border_guard_link_count = 0;
	for (int64_t template_index = 0; template_index < templates.size(); ++template_index) {
		if (Variant(templates[template_index]).get_type() != Variant::DICTIONARY) {
			continue;
		}
		Dictionary template_record = templates[template_index];
		Array zones = template_record.get("zones", Array());
		Array links = template_record.get("links", Array());
		zone_count += int32_t(zones.size());
		link_count += int32_t(links.size());
		for (int64_t link_index = 0; link_index < links.size(); ++link_index) {
			if (Variant(links[link_index]).get_type() != Variant::DICTIONARY) {
				continue;
			}
			Dictionary link = links[link_index];
			if (bool(link.get("wide", false))) {
				wide_link_count += 1;
			}
			if (bool(link.get("border_guard", false))) {
				border_guard_link_count += 1;
			}
		}
	}
	metrics["template_count"] = templates.size();
	metrics["template_zone_count"] = zone_count;
	metrics["template_link_count"] = link_count;
	metrics["wide_link_count"] = wide_link_count;
	metrics["border_guard_link_count"] = border_guard_link_count;
	return metrics;
}

void validate_model_surfaces(const Dictionary &model, Array &failures) {
	static constexpr const char *REQUIRED_SURFACES[] = {
		"template_record_model",
		"runtime_zone_record_model",
		"runtime_link_record_model",
		"generated_cell_model",
		"terrain_water_road_connection_placeholders",
		"validation_result_model",
		"compatibility_gates",
		"unsupported_parity_boundaries",
	};
	for (const char *surface : REQUIRED_SURFACES) {
		const String key = surface;
		if (!model.has(key)) {
			failures.append(failure_record("missing_model_surface", String(DATA_MODEL_PATH) + "." + key, "Generator data model is missing a required model surface."));
		}
	}
	if (model.has("unsupported_parity_boundaries") && Variant(model.get("unsupported_parity_boundaries", Variant())).get_type() == Variant::ARRAY && Array(model.get("unsupported_parity_boundaries", Array())).is_empty()) {
		failures.append(failure_record("missing_unsupported_boundaries", String(DATA_MODEL_PATH) + ".unsupported_parity_boundaries", "Unsupported parity boundaries must be explicit."));
	}
}

} // namespace

Dictionary inspect_generator_data_model(Dictionary options) {
	Array failures;
	Array warnings;
	Dictionary model = load_json_dictionary(DATA_MODEL_PATH, failures);
	Dictionary template_catalog = load_json_dictionary(TEMPLATE_CATALOG_PATH, failures);
	Dictionary map_objects = load_json_dictionary(MAP_OBJECTS_PATH, failures);
	Dictionary objects_by_id = map_object_index(map_objects, failures);

	Dictionary model_metrics;
	if (!model.is_empty()) {
		validate_model_surfaces(model, failures);
		model_metrics = validate_object_definitions(model, objects_by_id, failures, warnings);
		model_metrics["type_metadata"] = validate_type_metadata(model, failures);
	}
	Dictionary template_metrics;
	if (!template_catalog.is_empty()) {
		template_metrics = validate_template_catalog(template_catalog, failures);
	}

	Array unsupported = model.get("unsupported_parity_boundaries", Array());
	Dictionary diagnostics;
	diagnostics["failures"] = failures;
	diagnostics["warnings"] = warnings;
	diagnostics["unsupported_parity_boundaries"] = unsupported;
	diagnostics["unsupported_parity_boundary_count"] = unsupported.size();

	Dictionary compatibility = model.get("compatibility_gates", Dictionary());
	Dictionary metrics;
	metrics["map_object_catalog_count"] = objects_by_id.size();
	metrics["data_model"] = model_metrics;
	metrics["template_catalog"] = template_metrics;
	metrics["unsupported_parity_boundary_count"] = unsupported.size();

	Dictionary report;
	report["schema_id"] = REPORT_SCHEMA_ID;
	report["ok"] = failures.is_empty();
	report["validation_status"] = failures.is_empty() ? "pass" : "fail";
	report["content_path"] = DATA_MODEL_PATH;
	report["data_model_schema_id"] = model.get("schema_id", "");
	report["runtime_adoption_state"] = model.get("runtime_adoption_state", "");
	report["compatibility_gates"] = compatibility;
	report["diagnostics"] = diagnostics;
	report["metrics"] = metrics;
	report["source_artifacts"] = model.get("source_artifacts", Array());
	if (bool(options.get("include_model", false))) {
		report["data_model"] = model;
	}
	return report;
}

} // namespace godot::rmg_data_model
