#include "rmg_native_core.hpp"
#include "h3maped_rmg_core.hpp"

#include <algorithm>
#include <cerrno>
#include <cctype>
#include <cstdint>
#include <cstdlib>
#include <limits>
#include <sstream>

namespace aurelion::rmg_native_core {
namespace {

std::vector<h3maped_rmg_core::RuntimeZoneSeedInput4a218c> to_h3maped_runtime_zone_seeds(const std::vector<SharedRuntimeZoneSeedInput> &inputs);
std::vector<h3maped_rmg_core::RuntimeLinkSeedInput4a218c> to_h3maped_runtime_links(const std::vector<SharedRuntimeLinkInput> &inputs);
SharedSourceObjectRecord0x4c from_h3maped_source_object_record(const h3maped_rmg_core::SourceObjectRecord0x4c &input);
SharedSourceObjectResolverSourcePair4af785 from_h3maped_source_object_resolver_source_pair(const h3maped_rmg_core::SourceObjectResolverSourcePair4af785 &input);

std::string lower_ascii(const std::string &value) {
	std::string out = value;
	std::transform(out.begin(), out.end(), out.begin(), [](unsigned char ch) {
		return static_cast<char>(std::tolower(ch));
	});
	return out;
}

std::string normalize_size_class(const std::string &raw) {
	const std::string lowered = lower_ascii(raw);
	if (lowered == "small" || lowered == "homm3_small") {
		return "small";
	}
	if (lowered == "medium" || lowered == "homm3_medium") {
		return "medium";
	}
	return lowered;
}

std::string normalize_water_mode(const std::string &raw) {
	const std::string lowered = lower_ascii(raw);
	if (lowered == "none" || lowered == "no_water" || lowered == "land_only") {
		return "land";
	}
	return lowered;
}

std::vector<std::string> split(const std::string &raw, char delimiter) {
	std::vector<std::string> parts;
	std::string current;
	for (const char ch : raw) {
		if (ch == delimiter) {
			parts.push_back(current);
			current.clear();
		} else {
			current.push_back(ch);
		}
	}
	parts.push_back(current);
	return parts;
}

bool parse_i32(const std::string &raw, int32_t &out_value) {
	char *end = nullptr;
	errno = 0;
	const long parsed = std::strtol(raw.c_str(), &end, 10);
	if (errno != 0 || end == raw.c_str() || *end != '\0' || parsed < std::numeric_limits<int32_t>::min() || parsed > std::numeric_limits<int32_t>::max()) {
		return false;
	}
	out_value = static_cast<int32_t>(parsed);
	return true;
}

bool parse_u32(const std::string &raw, uint32_t &out_value) {
	char *end = nullptr;
	errno = 0;
	const unsigned long parsed = std::strtoul(raw.c_str(), &end, 10);
	if (errno != 0 || end == raw.c_str() || *end != '\0' || parsed > std::numeric_limits<uint32_t>::max()) {
		return false;
	}
	out_value = static_cast<uint32_t>(parsed);
	return true;
}

std::string json_escape(const std::string &value) {
	std::string out;
	out.reserve(value.size() + 8);
	for (const unsigned char ch : value) {
		switch (ch) {
			case '\\':
				out += "\\\\";
				break;
			case '"':
				out += "\\\"";
				break;
			case '\b':
				out += "\\b";
				break;
			case '\f':
				out += "\\f";
				break;
			case '\n':
				out += "\\n";
				break;
			case '\r':
				out += "\\r";
				break;
			case '\t':
				out += "\\t";
				break;
			default:
				if (ch < 0x20) {
					static constexpr char HEX[] = "0123456789abcdef";
					out += "\\u00";
					out.push_back(HEX[(ch >> 4U) & 0x0fU]);
					out.push_back(HEX[ch & 0x0fU]);
				} else {
					out.push_back(static_cast<char>(ch));
				}
				break;
		}
	}
	return out;
}

int32_t signed_byte(uint32_t value) {
	value &= 0xffU;
	return value >= 0x80U ? int32_t(value) - 0x100 : int32_t(value);
}

uint64_t fnv1a64_words(const std::vector<uint32_t> &words) {
	uint64_t hash = 1469598103934665603ULL;
	for (const uint32_t word : words) {
		for (int shift = 0; shift < 32; shift += 8) {
			hash ^= uint64_t((word >> shift) & 0xffU);
			hash *= 1099511628211ULL;
		}
	}
	return hash;
}

bool supported_one_level_land_scope(const ControlledCase &controlled_case) {
	if (!controlled_case.parse_ok) {
		return false;
	}
	const int32_t width = h3maped_rmg_core::map_width_for_size_class(controlled_case.size_class);
	return h3maped_rmg_core::supports_one_level_land_scope(width, width, controlled_case.level_count, controlled_case.water_mode, controlled_case.size_class);
}

std::vector<std::string> generated_cell_mutation_phase_blockers() {
	return {
		"0x4a1f3b_relation_scan_bound_producer_or_scan_consumer_order_unported",
		"0x49a318_recovered_callsite_order_private_state_compare_pending_after_bit22_policy_port",
		"0x49aa63_0x49a932_0x49abd6_0x49a85d_0x49a962_candidate_occupied_action_caller_order",
		"0x49cf34_0x4aa3e9_relation_reward_attachment_caller_order"
	};
}

std::vector<std::string> terrain_selection_parity_blockers() {
	return {
		"terrain_selection_executes_on_partial_coordinate_owner_grid_surface_only",
		"upstream_source_records_descriptor_identity_and_full_generated_cell_state_not_native_owned",
		"same_run_h3maped_private_state_comparison_not_passed"
	};
}

std::vector<std::string> terrain_repaint_parity_blockers() {
	return {
		"terrain_repaint_executes_on_partial_coordinate_owner_grid_surface_only",
		"upstream_source_records_descriptor_identity_and_full_generated_cell_state_not_native_owned",
		"downstream_relation_object_route_and_writeout_consumers_not_native_owned"
	};
}

void append_json_string_array(std::ostream &out, const std::vector<std::string> &values) {
	out << "[";
	for (size_t index = 0; index < values.size(); ++index) {
		if (index != 0) {
			out << ", ";
		}
		out << "\"" << json_escape(values[index]) << "\"";
	}
	out << "]";
}

void append_json_i32_array(std::ostream &out, const std::vector<int32_t> &values) {
	out << "[";
	for (size_t index = 0; index < values.size(); ++index) {
		if (index != 0) {
			out << ", ";
		}
		out << values[index];
	}
	out << "]";
}

void append_json_u32_array(std::ostream &out, const std::vector<uint32_t> &values) {
	out << "[";
	for (size_t index = 0; index < values.size(); ++index) {
		if (index != 0) {
			out << ", ";
		}
		out << values[index];
	}
	out << "]";
}

int32_t generated_cell_record_known_count(const std::vector<SharedGeneratedCellRecord0x30> &records, bool SharedGeneratedCellRecord0x30::*member) {
	return int32_t(std::count_if(records.begin(), records.end(), [member](const SharedGeneratedCellRecord0x30 &record) {
		return record.*member;
	}));
}

void populate_generated_cell_record_surface_0x30(RecoveredOwnerGridPayload &payload, const h3maped_rmg_core::GeneratedCellRecordGrid0x30 &source) {
	payload.generated_cell_record_shape_0x30_present = false;
	payload.generated_cell_record_stride_bytes = h3maped_rmg_core::GENERATED_CELL_RECORD_STRIDE_BYTES;
	payload.generated_cell_record_surface_status = "not_built";
	payload.generated_cell_records_0x30.clear();
	if (source.records.empty()) {
		return;
	}
	payload.generated_cell_record_shape_0x30_present = true;
	payload.generated_cell_record_stride_bytes = source.stride_bytes;
	payload.generated_cell_record_surface_status = "partial_stride_0x30_generator_object_buffer_0x14_from_0x49a072_0x499ea3_with_owner_terrain_word_overlays_and_0x4a5767_full_grid_reset_not_pre_0x4a4c8e_checkpoint";
	payload.generated_cell_records_0x30.reserve(source.records.size());
	const int32_t level_size = std::max<int32_t>(1, payload.width * payload.height);
	for (int32_t flat = 0; flat < int32_t(source.records.size()); ++flat) {
		const h3maped_rmg_core::GeneratedCellRecord0x30 &record = source.records[size_t(flat)];
		SharedGeneratedCellRecord0x30 out;
		out.flat = flat;
		out.level = flat / level_size;
		const int32_t remainder = flat % level_size;
		out.x = payload.width > 0 ? remainder % payload.width : -1;
		out.y = payload.width > 0 ? remainder / payload.width : -1;
		out.stride_bytes = record.stride_bytes;
		out.object_reference_vector_fields_0x04_0x08_present = record.object_reference_vector_fields_0x04_0x08_present;
		out.object_reference_vector_contents_known = record.object_reference_vector_contents_known;
		out.object_reference_count = record.object_reference_count;
		out.object_references_0x04_0x08 = record.object_references_0x04_0x08;
		out.word_0x10_known = record.word_0x10_known;
		out.word_0x10 = flat < int32_t(payload.generated_cell_word_0x10.size()) ? payload.generated_cell_word_0x10[size_t(flat)] : record.word_0x10;
		out.word_0x14_known = record.word_0x14_known;
		out.word_0x14 = record.word_0x14;
		out.word_0x18_known = record.word_0x18_known;
		out.word_0x18 = record.word_0x18;
		out.word_0x1c_known = record.word_0x1c_known;
		out.word_0x1c = flat < int32_t(payload.generated_cell_word_0x1c.size()) ? payload.generated_cell_word_0x1c[size_t(flat)] : record.word_0x1c;
		out.word_0x20_known = record.word_0x20_known || flat < int32_t(payload.generated_cell_word_0x20.size());
		out.word_0x20 = flat < int32_t(payload.generated_cell_word_0x20.size()) ? payload.generated_cell_word_0x20[size_t(flat)] : record.word_0x20;
		out.word_0x24_known = record.word_0x24_known || flat < int32_t(payload.generated_cell_word_0x24.size());
		out.word_0x24 = flat < int32_t(payload.generated_cell_word_0x24.size()) ? payload.generated_cell_word_0x24[size_t(flat)] : record.word_0x24;
		out.word_0x28_known = record.word_0x28_known || flat < int32_t(payload.generated_cell_word_0x28.size());
		out.word_0x28 = flat < int32_t(payload.generated_cell_word_0x28.size()) ? payload.generated_cell_word_0x28[size_t(flat)] : record.word_0x28;
		out.byte_0x2b_known = record.byte_0x2b_known;
		out.byte_0x2b_known_mask = record.byte_0x2b_known_mask;
		out.byte_0x2b = record.byte_0x2b;
		out.word_0x2c_known = record.word_0x2c_known;
		out.word_0x2c = flat < int32_t(payload.generated_cell_word_0x2c.size()) ? payload.generated_cell_word_0x2c[size_t(flat)] : record.word_0x2c;
		payload.generated_cell_records_0x30.push_back(out);
	}
}

void populate_generated_cell_word_arrays_from_record_grid(RecoveredOwnerGridPayload &payload, const h3maped_rmg_core::GeneratedCellRecordGrid0x30 &source) {
	payload.generated_cell_word_0x10.clear();
	payload.generated_cell_word_0x1c.clear();
	payload.generated_cell_word_0x20.clear();
	payload.generated_cell_word_0x24.clear();
	payload.generated_cell_word_0x28.clear();
	payload.generated_cell_word_0x2c.clear();
	payload.generated_cell_word_0x10.reserve(source.records.size());
	payload.generated_cell_word_0x1c.reserve(source.records.size());
	payload.generated_cell_word_0x20.reserve(source.records.size());
	payload.generated_cell_word_0x24.reserve(source.records.size());
	payload.generated_cell_word_0x28.reserve(source.records.size());
	payload.generated_cell_word_0x2c.reserve(source.records.size());
	for (const h3maped_rmg_core::GeneratedCellRecord0x30 &record : source.records) {
		payload.generated_cell_word_0x10.push_back(record.word_0x10);
		payload.generated_cell_word_0x1c.push_back(record.word_0x1c);
		payload.generated_cell_word_0x20.push_back(record.word_0x20);
		payload.generated_cell_word_0x24.push_back(record.word_0x24);
		payload.generated_cell_word_0x28.push_back(record.word_0x28);
		payload.generated_cell_word_0x2c.push_back(record.word_0x2c);
	}
}

SharedGeneratorObjectVectorState from_h3maped_generator_object_vector_state(const h3maped_rmg_core::GeneratorObjectVectorState &input) {
	SharedGeneratorObjectVectorState out;
	out.label = input.label;
	out.begin_offset = input.begin_offset;
	out.end_offset = input.end_offset;
	out.capacity_offset = input.capacity_offset;
	out.present = input.present;
	out.contents_known = input.contents_known;
	out.count_known = input.count_known;
	out.count = input.count;
	out.count_sourced_from_vector = input.count_sourced_from_vector;
	out.count_source_vector_label = input.count_source_vector_label;
	out.zero_initialized_contents_known_when_count_known = input.zero_initialized_contents_known_when_count_known;
	out.element_size_bytes = input.element_size_bytes;
	return out;
}

SharedGeneratorRelationRecordState from_h3maped_generator_relation_record_state(const h3maped_rmg_core::GeneratorRelationRecordState4a218c &input) {
	SharedGeneratorRelationRecordState out;
	out.source_link_index = input.source_link_index;
	out.owner_runtime_zone_index = input.owner_runtime_zone_index;
	out.owner_source_zone_id = input.owner_source_zone_id;
	out.target_runtime_zone_index = input.target_runtime_zone_index;
	out.target_source_zone_id = input.target_source_zone_id;
	out.guard_value = input.guard_value;
	out.wide = input.wide;
	out.border_guard = input.border_guard;
	out.reciprocal = input.reciprocal;
	out.control_dword_0x08 = input.control_dword_0x08;
	return out;
}

SharedGeneratorSourceEndpointRecordState from_h3maped_generator_source_endpoint_record_state(const h3maped_rmg_core::GeneratorSourceEndpointRecordState4a1f3b &input) {
	SharedGeneratorSourceEndpointRecordState out;
	out.source_link_index = input.source_link_index;
	out.owner_runtime_zone_index = input.owner_runtime_zone_index;
	out.owner_source_zone_id = input.owner_source_zone_id;
	out.target_runtime_zone_index = input.target_runtime_zone_index;
	out.target_source_zone_id = input.target_source_zone_id;
	out.source_endpoint = input.source_endpoint;
	out.target_source_endpoint = input.target_source_endpoint;
	out.guard_value = input.guard_value;
	out.wide = input.wide;
	out.border_guard = input.border_guard;
	out.reciprocal = input.reciprocal;
	return out;
}

SharedCoordinateCandidate4a17f5 from_h3maped_coordinate_candidate_4a17f5(const h3maped_rmg_core::CoordinateCandidate4a17f5 &input) {
	SharedCoordinateCandidate4a17f5 out;
	out.x = input.x;
	out.y = input.y;
	out.level = input.level;
	return out;
}

std::vector<SharedCoordinateCandidate4a17f5> from_h3maped_coordinate_candidates_4a17f5(const std::vector<h3maped_rmg_core::CoordinateCandidate4a17f5> &inputs) {
	std::vector<SharedCoordinateCandidate4a17f5> out;
	out.reserve(inputs.size());
	for (const h3maped_rmg_core::CoordinateCandidate4a17f5 &input : inputs) {
		out.push_back(from_h3maped_coordinate_candidate_4a17f5(input));
	}
	return out;
}

SharedGeneratorCoordinateCandidateVectorState4a1f3b from_h3maped_generator_coordinate_candidate_vector_state(const h3maped_rmg_core::GeneratorCoordinateCandidateVectorState4a1f3b &input) {
	SharedGeneratorCoordinateCandidateVectorState4a1f3b out;
	out.runtime_zone_index = input.runtime_zone_index;
	out.pass_id = input.pass_id;
	out.candidate_source = input.candidate_source;
	out.candidate_count_before_prune = input.candidate_count_before_prune;
	out.candidate_count_after_prune = input.candidate_count_after_prune;
	out.explicit_link_base_count = input.explicit_link_base_count;
	out.selected_candidate_index = input.selected_candidate_index;
	out.rng_value = input.rng_value;
	out.blocked = input.blocked;
	out.selected_candidate_known = input.selected_candidate_known;
	out.selected_candidate = from_h3maped_coordinate_candidate_4a17f5(input.selected_candidate);
	out.candidates_before_prune_4a17f5 = from_h3maped_coordinate_candidates_4a17f5(input.candidates_before_prune_4a17f5);
	out.candidates_after_prune_4a1ad8 = from_h3maped_coordinate_candidates_4a17f5(input.candidates_after_prune_4a1ad8);
	return out;
}

SharedGeneratorRelationOwnerState from_h3maped_generator_relation_owner_state(const h3maped_rmg_core::GeneratorRelationOwnerState4a218c &input) {
	SharedGeneratorRelationOwnerState out;
	out.owner_vector_index = input.owner_vector_index;
	out.runtime_zone_index = input.runtime_zone_index;
	out.source_zone_id = input.source_zone_id;
	out.source_index = input.source_index;
	out.constructor_0x49b452_known = input.constructor_0x49b452_known;
	out.source_pointer_0x00_known = input.source_pointer_0x00_known;
	out.source_pointer_source_index_0x00 = input.source_pointer_source_index_0x00;
	out.town_choice_0x04_known = input.town_choice_0x04_known;
	out.town_choice_0x04 = input.town_choice_0x04;
	out.source_owner_slot_0x1c_known = input.source_owner_slot_0x1c_known;
	out.source_owner_slot_0x1c = input.source_owner_slot_0x1c;
	out.coordinate_triple_0x10_0x18_known = input.coordinate_triple_0x10_0x18_known;
	out.coordinate_x_0x10 = input.coordinate_x_0x10;
	out.coordinate_y_0x14 = input.coordinate_y_0x14;
	out.coordinate_level_0x18 = input.coordinate_level_0x18;
	out.source_endpoint_vector_0xc8_0xcc_present = input.source_endpoint_vector_0xc8_0xcc_present;
	out.source_endpoint_vector_0xc8_0xcc_contents_known = input.source_endpoint_vector_0xc8_0xcc_contents_known;
	out.source_endpoint_vector_0xc8_0xcc_count_known = input.source_endpoint_vector_0xc8_0xcc_count_known;
	out.source_endpoint_vector_0xc8_0xcc_count = input.source_endpoint_vector_0xc8_0xcc_count;
	out.source_endpoint_vector_0xc8_0xcc_stride_bytes = input.source_endpoint_vector_0xc8_0xcc_stride_bytes;
	out.scan_bounds_0x20_0x2c_known = input.scan_bounds_0x20_0x2c_known;
	out.scan_bound_low_x_0x20 = input.scan_bound_low_x_0x20;
	out.scan_bound_low_y_0x24 = input.scan_bound_low_y_0x24;
	out.scan_bound_high_x_0x28 = input.scan_bound_high_x_0x28;
	out.scan_bound_high_y_0x2c = input.scan_bound_high_y_0x2c;
	out.byte_0x3c_known = input.byte_0x3c_known;
	out.byte_0x3c = input.byte_0x3c;
	out.descriptor_type_counter_table_0x44_known = input.descriptor_type_counter_table_0x44_known;
	out.descriptor_type_counter_table_0x44_byte_size = input.descriptor_type_counter_table_0x44_byte_size;
	out.descriptor_type_counter_table_0x44_zero_count = input.descriptor_type_counter_table_0x44_zero_count;
	out.descriptor_type_counters_0x44 = input.descriptor_type_counters_0x44;
	out.owner_local_vectors_0x3e4_0x3f4_0x404_known = input.owner_local_vectors_0x3e4_0x3f4_0x404_known;
	out.owner_local_vector_0x3e4_count = input.owner_local_vector_0x3e4_count;
	out.owner_local_vector_0x3f4_count = input.owner_local_vector_0x3f4_count;
	out.owner_local_vector_0x404_count = input.owner_local_vector_0x404_count;
	out.coordinate_candidate_vectors_0x4a1f3b_known = input.coordinate_candidate_vectors_0x4a1f3b_known;
	out.coordinate_candidate_vector_step_count = input.coordinate_candidate_vector_step_count;
	out.coordinate_candidate_after_prune_total_count = input.coordinate_candidate_after_prune_total_count;
	out.relation_record_count = input.relation_record_count;
	out.source_endpoint_records_0xc8_0xcc.reserve(input.source_endpoint_records_0xc8_0xcc.size());
	for (const h3maped_rmg_core::GeneratorSourceEndpointRecordState4a1f3b &record : input.source_endpoint_records_0xc8_0xcc) {
		out.source_endpoint_records_0xc8_0xcc.push_back(from_h3maped_generator_source_endpoint_record_state(record));
	}
	out.coordinate_candidate_vectors_0x4a1f3b.reserve(input.coordinate_candidate_vectors_0x4a1f3b.size());
	for (const h3maped_rmg_core::GeneratorCoordinateCandidateVectorState4a1f3b &vector : input.coordinate_candidate_vectors_0x4a1f3b) {
		out.coordinate_candidate_vectors_0x4a1f3b.push_back(from_h3maped_generator_coordinate_candidate_vector_state(vector));
	}
	out.relation_records.reserve(input.relation_records.size());
	for (const h3maped_rmg_core::GeneratorRelationRecordState4a218c &record : input.relation_records) {
		out.relation_records.push_back(from_h3maped_generator_relation_record_state(record));
	}
	return out;
}

SharedObjectRecordReference4a54a7 from_h3maped_object_record_reference_4a54a7(const h3maped_rmg_core::ObjectRecordReference4a54a7 &input) {
	SharedObjectRecordReference4a54a7 out;
	out.object_record_key = input.object_record_key;
	out.descriptor_type_0x1c = input.descriptor_type_0x1c;
	out.x = input.x;
	out.y = input.y;
	out.level = input.level;
	out.connection_fallback_record_0x4a7605_0x4a5e03_known = input.connection_fallback_record_0x4a7605_0x4a5e03_known;
	out.connection_fallback_arg0_0x4a5e03 = input.connection_fallback_arg0_0x4a5e03;
	out.connection_fallback_descriptor_pointer = input.connection_fallback_descriptor_pointer;
	out.connection_fallback_expected_owner_byte2 = input.connection_fallback_expected_owner_byte2;
	out.object_record_key_allocated_by_0x4a93a2 = input.object_record_key_allocated_by_0x4a93a2;
	out.source_order_direct_record_0x4a8d2c_0x4a93a2_known = input.source_order_direct_record_0x4a8d2c_0x4a93a2_known;
	out.weighted_record_0x4a93a2_known = input.weighted_record_0x4a93a2_known;
	out.object_record_vtable_0x00 = input.object_record_vtable_0x00;
	out.object_record_sequence_0x1c = input.object_record_sequence_0x1c;
	out.object_record_selected_index_0x20 = input.object_record_selected_index_0x20;
	out.object_record_enabled_word_0x24 = input.object_record_enabled_word_0x24;
	out.object_record_enabled_low_byte_0x24 = input.object_record_enabled_low_byte_0x24;
	out.source_descriptor_join_0x4903e8_known = input.source_descriptor_join_0x4903e8_known;
	out.weighted_type98_descriptor_bridge_0x4a93a2_known = input.weighted_type98_descriptor_bridge_0x4a93a2_known;
	out.descriptor_source_key_0x00 = input.descriptor_source_key_0x00;
	out.selected_wrapper_index_0x4af785 = input.selected_wrapper_index_0x4af785;
	out.source_catalog_index_0x49da08 = input.source_catalog_index_0x49da08;
	out.copied_source_record_carried = input.copied_source_record_carried;
	if (input.copied_source_record_carried) {
		out.source_record_copy = from_h3maped_source_object_record(input.source_record_copy);
	}
	return out;
}

SharedWeightedObjectCandidate4a901a from_h3maped_weighted_object_candidate_4a901a(const h3maped_rmg_core::WeightedObjectCandidate4a901a &input) {
	SharedWeightedObjectCandidate4a901a out;
	out.x = input.x;
	out.y = input.y;
	out.level = input.level;
	out.low_word_score_0x20 = input.low_word_score_0x20;
	return out;
}

SharedWeightedObjectCandidateVectorState4a901a from_h3maped_weighted_object_candidate_vector_4a901a(const h3maped_rmg_core::WeightedObjectCandidateVectorState4a901a &input) {
	SharedWeightedObjectCandidateVectorState4a901a out;
	out.descriptor_source_bridge_known = input.descriptor_source_bridge_known;
	out.copied_source_record_carried = input.copied_source_record_carried;
	out.scan_bounds_known = input.scan_bounds_known;
	out.scan_bounds_non_empty = input.scan_bounds_non_empty;
	out.relation_owner_byte_known = input.relation_owner_byte_known;
	out.threshold_arg_0x18_known = input.threshold_arg_0x18_known;
	out.relation_owner_byte2 = input.relation_owner_byte2;
	out.scan_bound_low_x = input.scan_bound_low_x;
	out.scan_bound_low_y = input.scan_bound_low_y;
	out.scan_bound_high_x = input.scan_bound_high_x;
	out.scan_bound_high_y = input.scan_bound_high_y;
	out.level = input.level;
	out.threshold_arg_0x18_initial = input.threshold_arg_0x18_initial;
	out.threshold_arg_0x18_after_scan = input.threshold_arg_0x18_after_scan;
	out.scanned_cell_count = input.scanned_cell_count;
	out.out_of_bounds_cell_count = input.out_of_bounds_cell_count;
	out.unknown_cell_word_count = input.unknown_cell_word_count;
	out.owner_byte_reject_count = input.owner_byte_reject_count;
	out.value_floor_reject_count = input.value_floor_reject_count;
	out.eligibility_reject_count_0x49aa93 = input.eligibility_reject_count_0x49aa93;
	out.local_vector_clear_count_0x4ae52a = input.local_vector_clear_count_0x4ae52a;
	out.local_vector_append_count_0x4ae1fd = input.local_vector_append_count_0x4ae1fd;
	out.accepted_candidate_count = input.accepted_candidate_count;
	out.rng_value_0x4e7276 = input.rng_value_0x4e7276;
	out.selected_candidate_index = input.selected_candidate_index;
	out.selected_candidate_known = input.selected_candidate_known;
	out.selected_candidate = from_h3maped_weighted_object_candidate_4a901a(input.selected_candidate);
	out.accepted_candidates_0x4ae1fd.reserve(input.accepted_candidates_0x4ae1fd.size());
	for (const h3maped_rmg_core::WeightedObjectCandidate4a901a &candidate : input.accepted_candidates_0x4ae1fd) {
		out.accepted_candidates_0x4ae1fd.push_back(from_h3maped_weighted_object_candidate_4a901a(candidate));
	}
	out.allocated_record_0x4a93a2 = input.allocated_record_0x4a93a2;
	out.committed_through_0x4a54a7 = input.committed_through_0x4a54a7;
	out.object_record_key = input.object_record_key;
	out.object_record_key_known = input.object_record_key_known;
	out.object_vector_count_after = input.object_vector_count_after;
	out.blocked_reason = input.blocked_reason;
	return out;
}

SharedGeneratorObjectPrivateState from_h3maped_generator_object_private_state(const h3maped_rmg_core::GeneratorObjectPrivateState &input) {
	SharedGeneratorObjectPrivateState out;
	out.present = input.generated_cell_buffer_owned;
	out.generated_cell_buffer_offset_0x14 = input.generated_cell_buffer_offset_0x14;
	out.width_offset_0x18 = input.width_offset_0x18;
	out.height_offset_0x1c = input.height_offset_0x1c;
	out.level_count_offset_0x20 = input.level_count_offset_0x20;
	out.generated_cell_buffer_owned = input.generated_cell_buffer_owned;
	out.generated_cell_buffer_record_count = int32_t(input.generated_cell_buffer.records.size());
	out.width = input.width;
	out.height = input.height;
	out.level_count = input.level_count;
	out.endpoint_vector_c8_cc = from_h3maped_generator_object_vector_state(input.endpoint_vector_c8_cc);
	out.endpoint_vector_d8_dc = from_h3maped_generator_object_vector_state(input.endpoint_vector_d8_dc);
	out.object_record_vector_ec4_ecc = from_h3maped_generator_object_vector_state(input.object_record_vector_ec4_ecc);
	out.source_pair_vector_edc = from_h3maped_generator_object_vector_state(input.source_pair_vector_edc);
	out.source_pair_records_edc.reserve(input.source_pair_records_edc.size());
	for (const h3maped_rmg_core::SourceObjectResolverSourcePair4af785 &source_pair : input.source_pair_records_edc) {
		out.source_pair_records_edc.push_back(from_h3maped_source_object_resolver_source_pair(source_pair));
	}
	out.pending_entry_vector_eec_ef0_ef4 = from_h3maped_generator_object_vector_state(input.pending_entry_vector_eec_ef0_ef4);
	out.candidate_container_vector_10d4_10d8 = from_h3maped_generator_object_vector_state(input.candidate_container_vector_10d4_10d8);
	out.relation_vector_10e4_10e8 = from_h3maped_generator_object_vector_state(input.relation_vector_10e4_10e8);
	out.endpoint_byte_state_vector_1104_1108 = from_h3maped_generator_object_vector_state(input.endpoint_byte_state_vector_1104_1108);
	out.endpoint_cursor_0xf58_present = input.endpoint_cursor_0xf58_present;
	out.endpoint_cursor_0xf58_known = input.endpoint_cursor_0xf58_known;
	out.endpoint_cursor_0xf58 = input.endpoint_cursor_0xf58;
	out.endpoint_cursor_0xf5c_present = input.endpoint_cursor_0xf5c_present;
	out.endpoint_cursor_0xf5c_known = input.endpoint_cursor_0xf5c_known;
	out.endpoint_cursor_0xf5c = input.endpoint_cursor_0xf5c;
	out.endpoint_projection_vector_c8_cc_source_owned_0x4a1f3b = input.endpoint_projection_vector_c8_cc_source_owned_0x4a1f3b;
	out.endpoint_projection_vector_c8_cc_record_count = input.endpoint_projection_vector_c8_cc_record_count;
	out.endpoint_projection_records_c8_cc.reserve(input.endpoint_projection_records_c8_cc.size());
	for (const h3maped_rmg_core::GeneratorSourceEndpointRecordState4a1f3b &record : input.endpoint_projection_records_c8_cc) {
		out.endpoint_projection_records_c8_cc.push_back(from_h3maped_generator_source_endpoint_record_state(record));
	}
	out.endpoint_cursor_vector_d8_dc_source_owned = input.endpoint_cursor_vector_d8_dc_source_owned;
	out.endpoint_cursor_vector_d8_dc_supported_land_exclusion_known = input.endpoint_cursor_vector_d8_dc_supported_land_exclusion_known;
	out.endpoint_cursor_producer_d014.recovered_supported_land_exclusion_known = input.endpoint_cursor_producer_d014.recovered_supported_land_exclusion_known;
	out.endpoint_cursor_producer_d014.supported_land_endpoint_cursor_key_range_known = input.endpoint_cursor_producer_d014.supported_land_endpoint_cursor_key_range_known;
	out.endpoint_cursor_producer_d014.supported_land_endpoint_cursor_key_count = input.endpoint_cursor_producer_d014.supported_land_endpoint_cursor_key_count;
	out.endpoint_cursor_producer_d014.supported_land_observed_stale_cursor_0xf5c_known = input.endpoint_cursor_producer_d014.supported_land_observed_stale_cursor_0xf5c_known;
	out.endpoint_cursor_producer_d014.supported_land_observed_stale_cursor_0xf5c = input.endpoint_cursor_producer_d014.supported_land_observed_stale_cursor_0xf5c;
	out.endpoint_cursor_producer_d014.setup_zeroed_cursor_0xf58_0x49ecf2_known = input.endpoint_cursor_producer_d014.setup_zeroed_cursor_0xf58_0x49ecf2_known;
	out.endpoint_cursor_producer_d014.endpoint_byte_state_zero_init_from_d8_count_0x49f95a_known = input.endpoint_cursor_producer_d014.endpoint_byte_state_zero_init_from_d8_count_0x49f95a_known;
	out.endpoint_cursor_producer_d014.direct_cursor_writer_surface_bounded = input.endpoint_cursor_producer_d014.direct_cursor_writer_surface_bounded;
	out.endpoint_cursor_producer_d014.setup_seeds_cursor_0xf5c = input.endpoint_cursor_producer_d014.setup_seeds_cursor_0xf5c;
	out.endpoint_cursor_producer_d014.successful_cursor_0xf5c_seed_source_known = input.endpoint_cursor_producer_d014.successful_cursor_0xf5c_seed_source_known;
	out.endpoint_cursor_producer_d014.supported_land_success_path_reached = input.endpoint_cursor_producer_d014.supported_land_success_path_reached;
	out.endpoint_cursor_producer_d014.supported_land_live_0x4a606b_reached = input.endpoint_cursor_producer_d014.supported_land_live_0x4a606b_reached;
	out.endpoint_cursor_producer_d014.supported_land_live_0x4a696b_relation_match_reached = input.endpoint_cursor_producer_d014.supported_land_live_0x4a696b_relation_match_reached;
	out.endpoint_cursor_producer_d014.direct_cursor_writer_entry_count = input.endpoint_cursor_producer_d014.direct_cursor_writer_entry_count;
	out.endpoint_cursor_producer_d014.direct_cursor_writer_entries = input.endpoint_cursor_producer_d014.direct_cursor_writer_entries;
	out.endpoint_cursor_producer_d014.missing_cursor_seed_source = input.endpoint_cursor_producer_d014.missing_cursor_seed_source;
	out.connection_materialization_caller_prep_d014.recovered_helper_contract_0x4a5e73_known = input.connection_materialization_caller_prep_d014.recovered_helper_contract_0x4a5e73_known;
	out.connection_materialization_caller_prep_d014.recovered_explicit_input_0x4a606b_known = input.connection_materialization_caller_prep_d014.recovered_explicit_input_0x4a606b_known;
	out.connection_materialization_caller_prep_d014.recovered_no_object_projection_chain_0x4a5a23_known = input.connection_materialization_caller_prep_d014.recovered_no_object_projection_chain_0x4a5a23_known;
	out.connection_materialization_caller_prep_d014.live_0x4a5e73_to_0x4a606b_target_mode_excluded = input.connection_materialization_caller_prep_d014.live_0x4a5e73_to_0x4a606b_target_mode_excluded;
	out.connection_materialization_caller_prep_d014.live_0x4a696b_target_mode_excluded = input.connection_materialization_caller_prep_d014.live_0x4a696b_target_mode_excluded;
	out.connection_materialization_caller_prep_d014.fallback_0x4a7605_to_0x4a5e03_source_backed = input.connection_materialization_caller_prep_d014.fallback_0x4a7605_to_0x4a5e03_source_backed;
	out.connection_materialization_caller_prep_d014.live_endpoint_materialization_allowed = input.connection_materialization_caller_prep_d014.live_endpoint_materialization_allowed;
	out.connection_materialization_caller_prep_d014.remaining_live_materialization_blocker = input.connection_materialization_caller_prep_d014.remaining_live_materialization_blocker;
	out.connection_fallback_materialization_0x4a7605_0x4a5e03_known = input.connection_fallback_materialization_0x4a7605_0x4a5e03_known;
	out.connection_fallback_materialization_record_count = input.connection_fallback_materialization_record_count;
	out.connection_fallback_materialization_commit_count = input.connection_fallback_materialization_commit_count;
	out.connection_fallback_materialization_blocked_count = input.connection_fallback_materialization_blocked_count;
	out.descriptor_counter_table_0x1110_present = input.descriptor_counter_table_0x1110_present;
	out.descriptor_counter_table_0x1110_contents_known = input.descriptor_counter_table_0x1110_contents_known;
	out.descriptor_counter_table_0x1110_known_count = input.descriptor_counter_table_0x1110_known_count;
	out.descriptor_counter_table_0x1110_zero_count = int32_t(std::count(input.descriptor_counter_table_0x1110.begin(), input.descriptor_counter_table_0x1110.end(), 0U));
	out.object_record_sequence_allocator_0xf44_present = input.object_record_sequence_allocator_0xf44_present;
	out.object_record_sequence_allocator_0xf44_known = input.object_record_sequence_allocator_0xf44_known;
	out.object_record_sequence_allocator_0xf44 = input.object_record_sequence_allocator_0xf44;
	out.native_object_record_key_allocator_0x4a93a2_known = input.native_object_record_key_allocator_0x4a93a2_known;
	out.next_native_object_record_key_0x4a93a2 = input.next_native_object_record_key_0x4a93a2;
	out.object_record_allocation_count_0x4a93a2 = input.object_record_allocation_count_0x4a93a2;
	out.weighted_scheduler_thresholds_0x4a8db2_known = input.weighted_scheduler_thresholds_0x4a8db2_known;
	out.weighted_scheduler_threshold_count_0x4a8db2 = input.weighted_scheduler_threshold_count_0x4a8db2;
	out.weighted_scheduler_thresholds_0x4a8db2.reserve(input.weighted_scheduler_thresholds_0x4a8db2.size());
	for (const h3maped_rmg_core::WeightedSchedulerThreshold4a8db2 &threshold : input.weighted_scheduler_thresholds_0x4a8db2) {
		SharedWeightedSchedulerThreshold4a8db2 shared_threshold;
		shared_threshold.source_density_fields_known = threshold.source_density_fields_known;
		shared_threshold.player_castle_density_0x2c = threshold.player_castle_density_0x2c;
		shared_threshold.player_town_density_0x28 = threshold.player_town_density_0x28;
		shared_threshold.neutral_castle_density_0x3c = threshold.neutral_castle_density_0x3c;
		shared_threshold.neutral_town_density_0x38 = threshold.neutral_town_density_0x38;
		shared_threshold.positive_density_sum = threshold.positive_density_sum;
		shared_threshold.threshold_arg_0x18_known = threshold.threshold_arg_0x18_known;
		shared_threshold.threshold_arg_0x18 = threshold.threshold_arg_0x18;
		shared_threshold.blocked_reason = threshold.blocked_reason;
		out.weighted_scheduler_thresholds_0x4a8db2.push_back(shared_threshold);
	}
	out.weighted_candidate_vectors_0x4a901a_known = input.weighted_candidate_vectors_0x4a901a_known;
	out.weighted_candidate_vector_count_0x4a901a = input.weighted_candidate_vector_count_0x4a901a;
	out.weighted_candidate_total_count_0x4a901a = input.weighted_candidate_total_count_0x4a901a;
	out.weighted_candidate_selected_count_0x4a901a = input.weighted_candidate_selected_count_0x4a901a;
	out.weighted_candidate_commit_count_0x4a901a = input.weighted_candidate_commit_count_0x4a901a;
	out.weighted_candidate_vectors_0x4a901a.reserve(input.weighted_candidate_vectors_0x4a901a.size());
	for (const h3maped_rmg_core::WeightedObjectCandidateVectorState4a901a &vector_state : input.weighted_candidate_vectors_0x4a901a) {
		out.weighted_candidate_vectors_0x4a901a.push_back(from_h3maped_weighted_object_candidate_vector_4a901a(vector_state));
	}
	out.source_order_direct_candidates_0x4a93a2_known = input.source_order_direct_candidates_0x4a93a2_known;
	out.source_order_direct_candidate_vector_count_0x4a93a2 = input.source_order_direct_candidate_vector_count_0x4a93a2;
	out.source_order_direct_candidate_total_count_0x4a93a2 = input.source_order_direct_candidate_total_count_0x4a93a2;
	out.source_order_direct_selected_count_0x4a93a2 = input.source_order_direct_selected_count_0x4a93a2;
	out.source_order_direct_commit_count_0x4a93a2 = input.source_order_direct_commit_count_0x4a93a2;
	out.object_records_0xec4_ecc.reserve(input.object_records_0xec4_ecc.size());
	for (const h3maped_rmg_core::ObjectRecordReference4a54a7 &record : input.object_records_0xec4_ecc) {
		out.object_records_0xec4_ecc.push_back(from_h3maped_object_record_reference_4a54a7(record));
	}
	out.object_record_vector_append_count_0x4a54a7 = input.object_record_vector_append_count_0x4a54a7;
	out.generated_cell_object_reference_append_count_0x4a54a7 = input.generated_cell_object_reference_append_count_0x4a54a7;
	out.descriptor_counter_increment_count_0x4a54a7 = input.descriptor_counter_increment_count_0x4a54a7;
	out.relation_descriptor_counter_increment_count_0x4a54a7 = input.relation_descriptor_counter_increment_count_0x4a54a7;
	out.target_cell_word_mutation_count_0x4a54a7 = input.target_cell_word_mutation_count_0x4a54a7;
	out.projection_score_depletion_count_0x4a54a7 = input.projection_score_depletion_count_0x4a54a7;
	out.source_owner_player_slots_ed8_ee0_ee4_present = input.source_owner_player_slots_ed8_ee0_ee4_present;
	out.selected_color_order_ed8_count = input.selected_color_order_ed8_count;
	out.raw_source_owner_slots_ee0_count = input.raw_source_owner_slots_ee0_count;
	out.mapped_source_owner_slots_ee4_count = input.mapped_source_owner_slots_ee4_count;
	out.relation_owner_records_10e4_10e8_partial_known = input.relation_owner_records_10e4_10e8_partial_known;
	out.relation_owner_vector_count_10e4_10e8 = input.relation_owner_vector_count_10e4_10e8;
	out.relation_record_count_10e4_10e8 = input.relation_record_count_10e4_10e8;
	out.relation_record_missing_endpoint_count_10e4_10e8 = input.relation_record_missing_endpoint_count_10e4_10e8;
	out.relation_owner_vectors_10e4_10e8.reserve(input.relation_owner_vectors_10e4_10e8.size());
	for (const h3maped_rmg_core::GeneratorRelationOwnerState4a218c &owner : input.relation_owner_vectors_10e4_10e8) {
		out.relation_owner_vectors_10e4_10e8.push_back(from_h3maped_generator_relation_owner_state(owner));
	}
	out.relation_owner_scan_bounds_0x4a1f3b_applied = input.relation_owner_scan_bounds_0x4a1f3b_applied;
	out.relation_owner_scan_bounds_known_count_0x4a1f3b = input.relation_owner_scan_bounds_known_count_0x4a1f3b;
	out.relation_owner_scan_bounds_blocked_count_0x4a1f3b = input.relation_owner_scan_bounds_blocked_count_0x4a1f3b;
	out.relation_normalization_4a5767_full_grid_reset_applied = input.relation_normalization_4a5767_full_grid_reset_applied;
	out.relation_normalization_4a5767_full_grid_reset_visited_count = input.relation_normalization_4a5767_full_grid_reset_visited_count;
	out.relation_normalization_4a5767_full_grid_reset_changed_count = input.relation_normalization_4a5767_full_grid_reset_changed_count;
	out.relation_normalization_4a5767_full_grid_reset_skipped_count = input.relation_normalization_4a5767_full_grid_reset_skipped_count;
	out.relation_scan_consumers_4a5767_applied = input.relation_scan_consumers_4a5767_applied;
	out.relation_scan_consumers_4a5767_no_object_projection_chain_complete = input.relation_scan_consumers_4a5767_no_object_projection_chain_complete;
	out.relation_scan_consumer_owner_scan_count_4a5767 = input.relation_scan_consumer_owner_scan_count_4a5767;
	out.relation_scan_consumer_owner_bounds_blocked_count_4a5767 = input.relation_scan_consumer_owner_bounds_blocked_count_4a5767;
	out.relation_scan_consumer_scanned_cell_count_4a5767 = input.relation_scan_consumer_scanned_cell_count_4a5767;
	out.relation_scan_consumer_object_branch_blocked_count_4a5767 = input.relation_scan_consumer_object_branch_blocked_count_4a5767;
	out.relation_scan_consumer_projected_chain_call_count_4a5767 = input.relation_scan_consumer_projected_chain_call_count_4a5767;
	out.relation_scan_consumer_projected_chain_occupied_stamp_count_4a5767 = input.relation_scan_consumer_projected_chain_occupied_stamp_count_4a5767;
	out.relation_scan_consumer_projected_chain_cleanup_clear_count_4a5767 = input.relation_scan_consumer_projected_chain_cleanup_clear_count_4a5767;
	out.relation_scan_consumer_object_branch_attempt_count_4a5767 = input.relation_scan_consumer_object_branch_attempt_count_4a5767;
	out.relation_scan_consumer_object_branch_commit_count_4a5767 = input.relation_scan_consumer_object_branch_commit_count_4a5767;
	out.relation_high_owner_propagation_49a318_applied = input.relation_high_owner_propagation_49a318_applied;
	out.relation_high_owner_propagation_49a318_grid_available = input.relation_high_owner_propagation_49a318_grid_available;
	out.relation_high_owner_propagation_49a318_object_metadata_gate_complete = input.relation_high_owner_propagation_49a318_object_metadata_gate_complete;
	out.relation_high_owner_seed_attempt_count_49a318 = input.relation_high_owner_seed_attempt_count_49a318;
	out.relation_high_owner_seed_blocked_count_49a318 = input.relation_high_owner_seed_blocked_count_49a318;
	out.relation_high_owner_popped_cell_count_49a318 = input.relation_high_owner_popped_cell_count_49a318;
	out.relation_high_owner_same_owner_relax_count_49a318 = input.relation_high_owner_same_owner_relax_count_49a318;
	out.relation_high_owner_cross_owner_high_byte_write_count_49a318 = input.relation_high_owner_cross_owner_high_byte_write_count_49a318;
	out.relation_high_owner_max_queue_size_49a318 = input.relation_high_owner_max_queue_size_49a318;
	out.relation_high_owner_materialized_count_49a318 = input.relation_high_owner_materialized_count_49a318;
	out.relation_high_owner_sentinel_count_49a318 = input.relation_high_owner_sentinel_count_49a318;
	out.remaining_private_state_blockers = input.remaining_private_state_blockers;
	return out;
}

h3maped_rmg_core::SourceTownRules4a218c to_h3maped_source_town_rules(const SharedSourceTownRules &input) {
	return h3maped_rmg_core::SourceTownRules4a218c {
		input.min_towns,
		input.min_castles,
		input.town_density,
		input.castle_density,
	};
}

SharedSourceTownRules from_h3maped_source_town_rules(const h3maped_rmg_core::SourceTownRules4a218c &input) {
	return SharedSourceTownRules {
		input.min_towns,
		input.min_castles,
		input.town_density,
		input.castle_density,
	};
}

h3maped_rmg_core::SourceMineRules4a218c to_h3maped_source_mine_rules(const SharedSourceMineRules &input) {
	return h3maped_rmg_core::SourceMineRules4a218c {
		input.minimum_wood,
		input.minimum_mercury,
		input.minimum_ore,
		input.minimum_sulfur,
		input.minimum_crystal,
		input.minimum_gems,
		input.minimum_gold,
		input.density_wood,
		input.density_mercury,
		input.density_ore,
		input.density_sulfur,
		input.density_crystal,
		input.density_gems,
		input.density_gold,
	};
}

SharedSourceMineRules from_h3maped_source_mine_rules(const h3maped_rmg_core::SourceMineRules4a218c &input) {
	return SharedSourceMineRules {
		input.minimum_wood,
		input.minimum_mercury,
		input.minimum_ore,
		input.minimum_sulfur,
		input.minimum_crystal,
		input.minimum_gems,
		input.minimum_gold,
		input.density_wood,
		input.density_mercury,
		input.density_ore,
		input.density_sulfur,
		input.density_crystal,
		input.density_gems,
		input.density_gold,
	};
}

h3maped_rmg_core::SourceTreasureBand4a218c to_h3maped_source_treasure_band(const SharedSourceTreasureBand &input) {
	return h3maped_rmg_core::SourceTreasureBand4a218c {
		input.density,
		input.low,
		input.high,
	};
}

SharedSourceTreasureBand from_h3maped_source_treasure_band(const h3maped_rmg_core::SourceTreasureBand4a218c &input) {
	return SharedSourceTreasureBand {
		input.density,
		input.low,
		input.high,
	};
}

h3maped_rmg_core::SourceZonePayload4a218c to_h3maped_source_zone_payload(const SharedSourceZonePayload &input) {
	return h3maped_rmg_core::SourceZonePayload4a218c {
		input.source_row,
		input.source_type_code,
		input.source_ownership,
		input.same_town_type,
		input.monster_match_to_town,
		input.monster_strength_mode,
		input.allowed_monster_town_mask,
		to_h3maped_source_town_rules(input.player_towns),
		to_h3maped_source_town_rules(input.neutral_towns),
		to_h3maped_source_mine_rules(input.mines),
		to_h3maped_source_treasure_band(input.treasure_band_0),
		to_h3maped_source_treasure_band(input.treasure_band_1),
		to_h3maped_source_treasure_band(input.treasure_band_2),
	};
}

SharedSourceZonePayload from_h3maped_source_zone_payload(const h3maped_rmg_core::SourceZonePayload4a218c &input) {
	return SharedSourceZonePayload {
		input.source_row,
		input.source_type_code,
		input.source_ownership,
		input.same_town_type,
		input.monster_match_to_town,
		input.monster_strength_mode,
		input.allowed_monster_town_mask,
		from_h3maped_source_town_rules(input.player_towns),
		from_h3maped_source_town_rules(input.neutral_towns),
		from_h3maped_source_mine_rules(input.mines),
		from_h3maped_source_treasure_band(input.treasure_band_0),
		from_h3maped_source_treasure_band(input.treasure_band_1),
		from_h3maped_source_treasure_band(input.treasure_band_2),
	};
}

SharedSourceObjectRecord0x4c from_h3maped_source_object_record(const h3maped_rmg_core::SourceObjectRecord0x4c &input) {
	return SharedSourceObjectRecord0x4c {
		input.source_row,
		input.source,
		input.def_name,
		input.type_id_0x1c,
		input.type_name,
		input.metadata_bucket_index_0x08,
		input.subtype_0x20,
		input.group_0x24,
		input.last_flag_0x28,
		input.raw_field_0x20_known,
		input.raw_field_0x20,
		input.raw_field_0x24_known,
		input.raw_field_0x24,
		input.raw_field_0x28_known,
		input.raw_field_0x28,
		input.raw_field_0x2c_known,
		input.raw_field_0x2c,
		input.raw_field_0x30_known,
		input.raw_field_0x30,
		input.raw_field_0x34_known,
		input.raw_field_0x34,
		input.raw_field_0x38_known,
		input.raw_field_0x38,
		input.pass_count,
		input.action_count,
		input.passability_mask,
		input.action_mask,
		input.terrain_mask_a_0x14,
		input.terrain_mask_b_0x18,
		input.descriptor_mask_fields_0x34_0x48_known,
		input.descriptor_mask_fields_exact_def_msk,
		input.descriptor_width_0x34,
		input.descriptor_height_0x38,
		input.descriptor_mask_a_0x3c_0x40,
		input.descriptor_mask_b_0x44_0x48,
		input.terrain_a_names,
		input.terrain_b_names,
		input.rand_trn_backed,
	};
}

SharedSourceObjectResolvedWrapper4af785 from_h3maped_source_object_resolved_wrapper(const h3maped_rmg_core::SourceObjectResolvedWrapper4af785 &input) {
	SharedSourceObjectResolvedWrapper4af785 out;
	out.wrapper_index = input.wrapper_index;
	out.source_catalog_index = input.source_catalog_index;
	out.source_record_copy = from_h3maped_source_object_record(input.source_record_copy);
	out.metadata_bucket_index_0x08 = input.metadata_bucket_index_0x08;
	out.resolver_lane_0x04 = input.resolver_lane_0x04;
	out.wrapper_0x04 = input.wrapper_0x04;
	out.wrapper_0x10_known = input.wrapper_0x10_known;
	out.wrapper_0x10 = input.wrapper_0x10;
	out.initialized_by_0x49db76 = input.initialized_by_0x49db76;
	out.copied_source_record = input.copied_source_record;
	return out;
}

SharedSourceObjectResolverSourcePair4af785 from_h3maped_source_object_resolver_source_pair(const h3maped_rmg_core::SourceObjectResolverSourcePair4af785 &input) {
	SharedSourceObjectResolverSourcePair4af785 out;
	out.copied_source_catalog_index = input.copied_source_catalog_index;
	out.wrapper_index = input.wrapper_index;
	out.source_record_pointer_0x00_carried = input.source_record_pointer_0x00_carried;
	out.source_record_copy = from_h3maped_source_object_record(input.source_record_copy);
	out.source_lane_0x1c = input.source_lane_0x1c;
	out.context_pointer_0x04_carried = input.context_pointer_0x04_carried;
	out.context_wrapper_copy = from_h3maped_source_object_resolved_wrapper(input.context_wrapper_copy);
	out.context_wrapper_index_0x04 = input.context_wrapper_index_0x04;
	out.context_wrapper_lane_0x04 = input.context_wrapper_lane_0x04;
	out.context_wrapper_0x10_known = input.context_wrapper_0x10_known;
	out.context_wrapper_0x10 = input.context_wrapper_0x10;
	return out;
}

bool same_source_object_record_sample(const SharedSourceObjectRecord0x4c &left, const SharedSourceObjectRecord0x4c &right) {
	return left.source_row == right.source_row
			&& left.source == right.source
			&& left.def_name == right.def_name
			&& left.type_id_0x1c == right.type_id_0x1c
			&& left.metadata_bucket_index_0x08 == right.metadata_bucket_index_0x08
			&& left.subtype_0x20 == right.subtype_0x20
			&& left.raw_field_0x20_known == right.raw_field_0x20_known
			&& left.raw_field_0x20 == right.raw_field_0x20
			&& left.raw_field_0x24_known == right.raw_field_0x24_known
			&& left.raw_field_0x24 == right.raw_field_0x24
			&& left.raw_field_0x28_known == right.raw_field_0x28_known
			&& left.raw_field_0x28 == right.raw_field_0x28
			&& left.raw_field_0x2c_known == right.raw_field_0x2c_known
			&& left.raw_field_0x2c == right.raw_field_0x2c
			&& left.raw_field_0x30_known == right.raw_field_0x30_known
			&& left.raw_field_0x30 == right.raw_field_0x30
			&& left.raw_field_0x34_known == right.raw_field_0x34_known
			&& left.raw_field_0x34 == right.raw_field_0x34
			&& left.raw_field_0x38_known == right.raw_field_0x38_known
			&& left.raw_field_0x38 == right.raw_field_0x38;
}

void add_source_object_sample(RecoveredOwnerGridPayload &payload, const h3maped_rmg_core::SourceObjectRecord0x4c &input) {
	const SharedSourceObjectRecord0x4c sample = from_h3maped_source_object_record(input);
	const auto duplicate = std::find_if(payload.source_object_catalog_samples.begin(), payload.source_object_catalog_samples.end(), [&sample](const SharedSourceObjectRecord0x4c &existing) {
		return same_source_object_record_sample(existing, sample);
	});
	if (duplicate == payload.source_object_catalog_samples.end()) {
		payload.source_object_catalog_samples.push_back(sample);
	}
}

void add_first_source_object_sample(RecoveredOwnerGridPayload &payload, const std::vector<h3maped_rmg_core::SourceObjectRecord0x4c> &records) {
	if (!records.empty()) {
		add_source_object_sample(payload, records.front());
	}
}

SharedSourceObjectWrapperBucket0xe8 from_h3maped_source_object_wrapper_bucket(const h3maped_rmg_core::SourceObjectWrapperBucket0xe8 &input) {
	SharedSourceObjectWrapperBucket0xe8 out;
	out.bucket_index_0x08 = input.bucket_index_0x08;
	out.first_type_id_0x1c = input.first_type_id_0x1c;
	out.first_type_name = input.first_type_name;
	out.initialized_by_0x49db76 = input.initialized_by_0x49db76;
	out.record_count = input.record_count;
	out.first_source_record_index = input.first_source_record_index;
	out.last_source_record_index = input.last_source_record_index;
	const int32_t sample_count = std::min<int32_t>(12, int32_t(input.source_record_indices.size()));
	out.source_record_index_sample.reserve(size_t(sample_count));
	for (int32_t index = 0; index < sample_count; ++index) {
		out.source_record_index_sample.push_back(input.source_record_indices[size_t(index)]);
	}
	return out;
}

bool same_source_object_wrapper_bucket_sample(const SharedSourceObjectWrapperBucket0xe8 &left, const SharedSourceObjectWrapperBucket0xe8 &right) {
	return left.bucket_index_0x08 == right.bucket_index_0x08;
}

void add_source_object_wrapper_bucket_sample(RecoveredOwnerGridPayload &payload, const h3maped_rmg_core::SourceObjectWrapperBucket0xe8 &input) {
	const SharedSourceObjectWrapperBucket0xe8 sample = from_h3maped_source_object_wrapper_bucket(input);
	const auto duplicate = std::find_if(payload.source_object_wrapper_bucket_samples.begin(), payload.source_object_wrapper_bucket_samples.end(), [&sample](const SharedSourceObjectWrapperBucket0xe8 &existing) {
		return same_source_object_wrapper_bucket_sample(existing, sample);
	});
	if (duplicate == payload.source_object_wrapper_bucket_samples.end()) {
		payload.source_object_wrapper_bucket_samples.push_back(sample);
	}
}

void add_source_object_wrapper_bucket_sample_by_index(RecoveredOwnerGridPayload &payload, int32_t bucket_index) {
	h3maped_rmg_core::SourceObjectWrapperBucket0xe8 bucket;
	if (h3maped_rmg_core::source_object_wrapper_bucket_by_index_0x49db76(bucket_index, bucket)) {
		add_source_object_wrapper_bucket_sample(payload, bucket);
	}
}

SharedSourceObjectSelectorResult4a9e40 from_h3maped_source_object_selector_result(const h3maped_rmg_core::SourceObjectSelectorResult4a9e40 &input) {
	SharedSourceObjectSelectorResult4a9e40 out;
	out.requested_lane = input.requested_lane;
	out.requested_bucket_index_0x08 = input.requested_bucket_index_0x08;
	out.requested_source_field_0x20 = input.requested_source_field_0x20;
	out.bucket_found = input.bucket_found;
	out.scanned_record_count = input.scanned_record_count;
	out.source_0x20_reject_count = input.source_0x20_reject_count;
	out.group_lane8_reject_count = input.group_lane8_reject_count;
	out.mask_reject_count = input.mask_reject_count;
	out.accepted_count = input.accepted_count;
	const int32_t sample_count = std::min<int32_t>(12, int32_t(input.accepted_source_record_indices.size()));
	out.accepted_source_record_index_sample.reserve(size_t(sample_count));
	for (int32_t index = 0; index < sample_count; ++index) {
		out.accepted_source_record_index_sample.push_back(input.accepted_source_record_indices[size_t(index)]);
	}
	out.selected = input.selected;
	out.selected_candidate_index = input.selected_candidate_index;
	out.selected_source_record_index = input.selected_source_record_index;
	out.selected_type_id_0x1c = input.selected_type_id_0x1c;
	out.selected_subtype_0x20 = input.selected_subtype_0x20;
	out.selected_group_0x24 = input.selected_group_0x24;
	out.selected_def_name = input.selected_def_name;
	out.rng_state_before = input.rng_state_before;
	out.rng_state_after = input.rng_state_after;
	out.rng_consumed = input.rng_consumed;
	out.rng_value = input.rng_value;
	return out;
}

SharedSourceObjectResolverResult4af785 from_h3maped_source_object_resolver_result(const h3maped_rmg_core::SourceObjectResolverResult4af785 &input) {
	SharedSourceObjectResolverResult4af785 out;
	out.input_source_catalog_index = input.input_source_catalog_index;
	out.input_source_row = input.input_source_row;
	out.input_def_name = input.input_def_name;
	out.input_type_id_0x1c = input.input_type_id_0x1c;
	out.input_subtype_0x20 = input.input_subtype_0x20;
	out.metadata_bucket_index_0x08 = input.metadata_bucket_index_0x08;
	out.resolver_lane_0x04 = input.resolver_lane_0x04;
	out.reused_existing_wrapper = input.reused_existing_wrapper;
	out.created_new_wrapper = input.created_new_wrapper;
	out.selected_wrapper_index = input.selected_wrapper_index;
	out.scanned_bucket_wrapper_count = input.scanned_bucket_wrapper_count;
	out.lane_reject_count = input.lane_reject_count;
	out.source_0x20_reject_count = input.source_0x20_reject_count;
	out.source_copy_mismatch_count = input.source_copy_mismatch_count;
	out.bucket_size_before = input.bucket_size_before;
	out.bucket_size_after = input.bucket_size_after;
	out.source_pair_count_before = input.source_pair_count_before;
	out.source_pair_count_after = input.source_pair_count_after;
	out.appended_source_pair_0xedc = input.appended_source_pair_0xedc;
	out.appended_wrapper_to_bucket = input.appended_wrapper_to_bucket;
	out.copied_source_record = input.copied_source_record;
	out.wrapper_0x10_known = input.wrapper_0x10_known;
	out.wrapper_0x10 = input.wrapper_0x10;
	return out;
}

void add_source_object_selector_sample(RecoveredOwnerGridPayload &payload, const h3maped_rmg_core::SourceObjectSelectorResult4a9e40 &input) {
	payload.source_object_selector_samples_0x4a9e40.push_back(from_h3maped_source_object_selector_result(input));
}

void add_first_source_object_selector_sample(RecoveredOwnerGridPayload &payload, const std::vector<h3maped_rmg_core::SourceObjectRecord0x4c> &records) {
	if (records.empty()) {
		return;
	}
	const h3maped_rmg_core::SourceObjectRecord0x4c &record = records.front();
	const h3maped_rmg_core::SourceObjectMaskLaneResult4af89f lane =
			h3maped_rmg_core::source_object_mask_lane_selector_0x4af89f(record);
	add_source_object_selector_sample(payload,
			h3maped_rmg_core::source_object_wrapper_selector_0x4a9e40(10U, lane.selected_lane, record.metadata_bucket_index_0x08, record.subtype_0x20));
}

void populate_source_object_selector_samples_0x4a9e40(RecoveredOwnerGridPayload &payload) {
	payload.source_object_selector_samples_0x4a9e40.clear();
	add_first_source_object_selector_sample(payload, h3maped_rmg_core::source_object_records_by_type_0x49da08(199));
	add_first_source_object_selector_sample(payload, h3maped_rmg_core::source_object_records_by_type_0x49da08(45));
	const std::vector<h3maped_rmg_core::SourceObjectRecord0x4c> type199_records =
			h3maped_rmg_core::source_object_records_by_type_0x49da08(199);
	if (!type199_records.empty()) {
		const h3maped_rmg_core::SourceObjectRecord0x4c &record = type199_records.front();
		const h3maped_rmg_core::SourceObjectMaskLaneResult4af89f lane =
				h3maped_rmg_core::source_object_mask_lane_selector_0x4af89f(record);
		add_source_object_selector_sample(payload,
				h3maped_rmg_core::source_object_wrapper_selector_0x4a9e40(10U, lane.selected_lane, record.metadata_bucket_index_0x08, -999));
	}
}

void add_source_object_resolver_sample(RecoveredOwnerGridPayload &payload, const h3maped_rmg_core::SourceObjectResolverResult4af785 &input) {
	payload.source_object_resolver_samples_0x4af785.push_back(from_h3maped_source_object_resolver_result(input));
}

void populate_source_object_resolver_samples_0x4af785(RecoveredOwnerGridPayload &payload) {
	payload.source_object_resolver_samples_0x4af785.clear();
	h3maped_rmg_core::SourceObjectResolverState4af785 state;
	const std::vector<h3maped_rmg_core::SourceObjectRecord0x4c> type199_records =
			h3maped_rmg_core::source_object_records_by_type_0x49da08(199);
	if (type199_records.empty()) {
		return;
	}
	const h3maped_rmg_core::SourceObjectRecord0x4c &first = type199_records.front();
	const h3maped_rmg_core::SourceObjectMaskLaneResult4af89f first_lane =
			h3maped_rmg_core::source_object_mask_lane_selector_0x4af89f(first);
	add_source_object_resolver_sample(payload, h3maped_rmg_core::source_object_descriptor_resolver_0x4af785(state, first));
	add_source_object_resolver_sample(payload, h3maped_rmg_core::source_object_descriptor_resolver_0x4af785(state, first));
	for (const h3maped_rmg_core::SourceObjectRecord0x4c &candidate : type199_records) {
		const h3maped_rmg_core::SourceObjectMaskLaneResult4af89f candidate_lane =
				h3maped_rmg_core::source_object_mask_lane_selector_0x4af89f(candidate);
		if (candidate.metadata_bucket_index_0x08 == first.metadata_bucket_index_0x08
				&& candidate.subtype_0x20 == first.subtype_0x20
				&& candidate_lane.selected_lane == first_lane.selected_lane
				&& !h3maped_rmg_core::same_source_object_record_0x4c(candidate, first)) {
			add_source_object_resolver_sample(payload, h3maped_rmg_core::source_object_descriptor_resolver_0x4af785(state, candidate));
			return;
		}
	}
}

void populate_source_object_catalog_0x49da08(RecoveredOwnerGridPayload &payload) {
	const h3maped_rmg_core::SourceObjectCatalogSummary0x49da08 summary =
			h3maped_rmg_core::source_object_catalog_summary_0x49da08();
	const h3maped_rmg_core::SourceObjectWrapperBucketSummary0xe8 wrapper_summary =
			h3maped_rmg_core::source_object_wrapper_bucket_summary_0x49db76();
	payload.source_object_catalog_0x49da08_present = summary.record_count > 0;
	payload.source_object_catalog_0x49da08_record_count = summary.record_count;
	payload.source_object_catalog_0x4c_copy_size_bytes = summary.source_record_copy_size_bytes;
	payload.source_object_catalog_objects_txt_record_count = summary.objects_txt_record_count;
	payload.source_object_catalog_rand_trn_backed_record_count = summary.rand_trn_backed_record_count;
	payload.source_object_catalog_passability_mask_record_count = summary.passability_mask_record_count;
	payload.source_object_catalog_action_mask_record_count = summary.action_mask_record_count;
	payload.source_object_catalog_descriptor_mask_field_record_count = summary.descriptor_mask_field_record_count;
	payload.source_object_catalog_descriptor_mask_exact_def_msk_count = summary.descriptor_mask_exact_def_msk_count;
	payload.source_object_catalog_descriptor_mask_default_msk_fallback_count = summary.descriptor_mask_default_msk_fallback_count;
	payload.source_object_catalog_type53_record_count = summary.mine_type53_record_count;
	payload.source_object_catalog_type53_ambiguous_subtype_count = summary.mine_type53_ambiguous_subtype_count;
	payload.source_object_catalog_descriptor_only_mine_identity_ambiguous = summary.descriptor_only_mine_identity_ambiguous;
	payload.source_object_catalog_samples.clear();
	payload.source_object_wrapper_buckets_0x49db76_present = wrapper_summary.bucket_count == h3maped_rmg_core::SOURCE_OBJECT_WRAPPER_BUCKET_COUNT_0XE8;
	payload.source_object_wrapper_bucket_count_0xe8 = wrapper_summary.bucket_count;
	payload.source_object_wrapper_initialized_bucket_count = wrapper_summary.initialized_bucket_count;
	payload.source_object_wrapper_non_empty_bucket_count = wrapper_summary.non_empty_bucket_count;
	payload.source_object_wrapper_total_source_record_references = wrapper_summary.total_source_record_references;
	payload.source_object_wrapper_out_of_range_source_record_count = wrapper_summary.out_of_range_source_record_count;
	payload.source_object_wrapper_max_bucket_record_count = wrapper_summary.max_bucket_record_count;
	payload.source_object_wrapper_max_bucket_index_0x08 = wrapper_summary.max_bucket_index_0x08;
	payload.source_object_wrapper_bucket_samples.clear();

	const std::vector<h3maped_rmg_core::SourceObjectRecord0x4c> &catalog =
			h3maped_rmg_core::source_object_catalog_0x49da08();
	add_first_source_object_sample(payload, catalog);
	add_first_source_object_sample(payload, h3maped_rmg_core::source_object_records_by_type_0x49da08(45));
	add_first_source_object_sample(payload, h3maped_rmg_core::source_object_records_by_type_subtype_0x49da08(53, 4));
	add_first_source_object_sample(payload, h3maped_rmg_core::source_object_records_by_type_0x49da08(54));
	add_first_source_object_sample(payload, h3maped_rmg_core::source_object_records_by_type_0x49da08(79));
	add_source_object_wrapper_bucket_sample_by_index(payload, 0);
	add_source_object_wrapper_bucket_sample_by_index(payload, 155);
	add_source_object_wrapper_bucket_sample_by_index(payload, 53);
	add_source_object_wrapper_bucket_sample_by_index(payload, 21);
	add_source_object_wrapper_bucket_sample_by_index(payload, 46);
	add_source_object_wrapper_bucket_sample_by_index(payload, 33);
	add_source_object_wrapper_bucket_sample_by_index(payload, 99);
	add_source_object_wrapper_bucket_sample_by_index(payload, 126);
	add_source_object_wrapper_bucket_sample_by_index(payload, 1);
	populate_source_object_selector_samples_0x4a9e40(payload);
	populate_source_object_resolver_samples_0x4af785(payload);
}

std::vector<SharedPlayerSlotAssignmentRecord> from_h3maped_player_slot_assignments(const std::vector<h3maped_rmg_core::PlayerSlotAssignmentRecord4ac62a> &inputs) {
	std::vector<SharedPlayerSlotAssignmentRecord> out;
	out.reserve(inputs.size());
	for (const h3maped_rmg_core::PlayerSlotAssignmentRecord4ac62a &input : inputs) {
		out.push_back(SharedPlayerSlotAssignmentRecord {
			input.source_owner_index,
			input.actual_player_color,
			input.human,
		});
	}
	return out;
}

std::vector<SharedTemplateCandidateContainerRecord> from_h3maped_candidate_containers(const std::vector<h3maped_rmg_core::TemplateCandidateContainerRecord4ac552> &inputs) {
	std::vector<SharedTemplateCandidateContainerRecord> out;
	out.reserve(inputs.size());
	for (const h3maped_rmg_core::TemplateCandidateContainerRecord4ac552 &input : inputs) {
		out.push_back(SharedTemplateCandidateContainerRecord {
			input.vector_index,
			input.source_catalog_index,
			input.template_name,
			input.zone_count,
			input.link_count,
		});
	}
	return out;
}

h3maped_rmg_core::TemplateSelectionRuntimeResult4ac552 to_h3maped_template_selection_snapshot(const SharedRuntimeChainInput &input) {
	h3maped_rmg_core::TemplateSelectionRuntimeResult4ac552 out;
	out.blocked = input.recovered_template_selection_blocked;
	out.size_score = input.recovered_template_size_score;
	out.accepted_template_count = input.recovered_template_accepted_count;
	out.selected_vector_index = input.recovered_template_selected_vector_index;
	out.selected_source_catalog_index = input.recovered_template_source_catalog_index;
	out.selected_template_name = input.recovered_template_name;
	out.rng_state_before_template_selection = input.recovered_template_rng_state_before;
	out.rng_state_after_template_selection = input.rng_state_after_template_selection;
	out.rng_value = input.recovered_template_rng_value;
	out.source_zone_record_count = input.recovered_template_source_zone_record_count;
	out.source_link_record_count = input.recovered_template_source_link_record_count;
	out.player_assignment.complete = input.recovered_template_player_assignment_complete || input.recovered_player_slot_assignment_known;
	out.player_assignment.requested_human_count = input.recovered_player_slot_requested_human_count;
	out.player_assignment.requested_player_count = input.recovered_player_slot_requested_player_count;
	out.player_assignment.assigned_player_count = input.recovered_player_slot_assigned_player_count;
	out.player_assignment.selected_color_order_ed8 = input.recovered_selected_color_order_ed8;
	out.player_assignment.raw_ee0_slots = input.recovered_raw_source_owner_slots_ee0;
	out.player_assignment.mapped_ee4_slots = input.recovered_mapped_source_owner_slots_ee4;
	out.player_assignment.assignments.reserve(input.recovered_player_slot_assignments.size());
	for (const SharedPlayerSlotAssignmentRecord &assignment : input.recovered_player_slot_assignments) {
		out.player_assignment.assignments.push_back(h3maped_rmg_core::PlayerSlotAssignmentRecord4ac62a {
			assignment.source_owner_index,
			assignment.actual_player_color,
			assignment.human,
		});
	}
	out.accepted_candidate_containers_10d4_10d8.reserve(input.recovered_candidate_containers_10d4_10d8.size());
	for (const SharedTemplateCandidateContainerRecord &record : input.recovered_candidate_containers_10d4_10d8) {
		out.accepted_candidate_containers_10d4_10d8.push_back(h3maped_rmg_core::TemplateCandidateContainerRecord4ac552 {
			record.vector_index,
			record.source_catalog_index,
			record.template_name,
			record.zone_count,
			record.link_count,
		});
	}
	out.runtime_seed.blocked = input.recovered_template_selection_blocked;
	out.runtime_seed.skipped_zone_filter_count = input.recovered_template_skipped_zone_filter_count;
	out.runtime_seed.skipped_link_filter_count = input.recovered_template_skipped_link_filter_count;
	out.runtime_seed.missing_link_endpoint_count = input.recovered_template_missing_link_endpoint_count;
	out.runtime_seed.runtime_zone_seeds = to_h3maped_runtime_zone_seeds(input.runtime_zone_seeds);
	out.runtime_seed.runtime_links = to_h3maped_runtime_links(input.runtime_links);
	return out;
}

void append_template_candidate_container_record_json(std::ostream &out, const SharedTemplateCandidateContainerRecord &record) {
	out << "{\"vector_index\":" << record.vector_index
		<< ",\"source_catalog_index\":" << record.source_catalog_index
		<< ",\"template_name\":\"" << json_escape(record.template_name) << "\""
		<< ",\"zone_count\":" << record.zone_count
		<< ",\"link_count\":" << record.link_count
		<< "}";
}

void append_template_candidate_container_records_json(std::ostream &out, const std::vector<SharedTemplateCandidateContainerRecord> &records) {
	out << "[";
	for (size_t index = 0; index < records.size(); ++index) {
		if (index != 0) {
			out << ", ";
		}
		append_template_candidate_container_record_json(out, records[index]);
	}
	out << "]";
}

void append_source_town_rules_json(std::ostream &out, const SharedSourceTownRules &rules) {
	out << "{\"min_towns\":" << rules.min_towns
		<< ",\"min_castles\":" << rules.min_castles
		<< ",\"town_density\":" << rules.town_density
		<< ",\"castle_density\":" << rules.castle_density
		<< "}";
}

void append_source_mine_rules_json(std::ostream &out, const SharedSourceMineRules &rules) {
	out << "{\"minimum_wood\":" << rules.minimum_wood
		<< ",\"minimum_mercury\":" << rules.minimum_mercury
		<< ",\"minimum_ore\":" << rules.minimum_ore
		<< ",\"minimum_sulfur\":" << rules.minimum_sulfur
		<< ",\"minimum_crystal\":" << rules.minimum_crystal
		<< ",\"minimum_gems\":" << rules.minimum_gems
		<< ",\"minimum_gold\":" << rules.minimum_gold
		<< ",\"density_wood\":" << rules.density_wood
		<< ",\"density_mercury\":" << rules.density_mercury
		<< ",\"density_ore\":" << rules.density_ore
		<< ",\"density_sulfur\":" << rules.density_sulfur
		<< ",\"density_crystal\":" << rules.density_crystal
		<< ",\"density_gems\":" << rules.density_gems
		<< ",\"density_gold\":" << rules.density_gold
		<< "}";
}

void append_source_treasure_band_json(std::ostream &out, const SharedSourceTreasureBand &band) {
	out << "{\"density\":" << band.density
		<< ",\"low\":" << band.low
		<< ",\"high\":" << band.high
		<< "}";
}

void append_source_zone_payload_json(std::ostream &out, const SharedSourceZonePayload &payload) {
	out << "{\"source_row\":" << payload.source_row
		<< ",\"source_type_code\":" << payload.source_type_code
		<< ",\"source_ownership\":" << payload.source_ownership
		<< ",\"same_town_type\":" << (payload.same_town_type ? "true" : "false")
		<< ",\"monster_match_to_town\":" << (payload.monster_match_to_town ? "true" : "false")
		<< ",\"monster_strength_mode\":" << payload.monster_strength_mode
		<< ",\"allowed_monster_town_mask\":" << payload.allowed_monster_town_mask
		<< ",\"player_towns\":";
	append_source_town_rules_json(out, payload.player_towns);
	out << ",\"neutral_towns\":";
	append_source_town_rules_json(out, payload.neutral_towns);
	out << ",\"mines\":";
	append_source_mine_rules_json(out, payload.mines);
	out << ",\"treasure_bands\":[";
	append_source_treasure_band_json(out, payload.treasure_band_0);
	out << ",";
	append_source_treasure_band_json(out, payload.treasure_band_1);
	out << ",";
	append_source_treasure_band_json(out, payload.treasure_band_2);
	out << "]}";
}

void append_runtime_zone_source_payload_records_json(std::ostream &out, const std::vector<SharedRuntimeZoneSeedInput> &records) {
	out << "[";
	for (size_t index = 0; index < records.size(); ++index) {
		if (index != 0) {
			out << ", ";
		}
		const SharedRuntimeZoneSeedInput &record = records[index];
		out << "{\"runtime_zone_index\":" << record.runtime_zone_index
			<< ",\"source_zone_id\":" << record.source_zone_id
			<< ",\"source_index\":" << record.source_index
			<< ",\"h3maped_zone_word_id\":" << record.h3maped_zone_word_id
			<< ",\"source_bucket\":" << record.source_bucket
			<< ",\"source_owner_index\":" << record.source_owner_index
			<< ",\"actual_player_color\":" << record.actual_player_color
			<< ",\"source_payload\":";
		append_source_zone_payload_json(out, record.source_payload);
		out << "}";
	}
	out << "]";
}

void append_source_object_record_sample_json(std::ostream &out, const SharedSourceObjectRecord0x4c &record) {
	out << "{\"source_row\":" << record.source_row
		<< ",\"source\":\"" << json_escape(record.source) << "\""
		<< ",\"def_name\":\"" << json_escape(record.def_name) << "\""
		<< ",\"type_id_0x1c\":" << record.type_id_0x1c
		<< ",\"type_name\":\"" << json_escape(record.type_name) << "\""
		<< ",\"metadata_bucket_index_0x08\":" << record.metadata_bucket_index_0x08
		<< ",\"subtype_0x20\":" << record.subtype_0x20
		<< ",\"group_0x24\":" << record.group_0x24
		<< ",\"last_flag_0x28\":" << record.last_flag_0x28
		<< ",\"raw_field_0x20_known\":" << (record.raw_field_0x20_known ? "true" : "false")
		<< ",\"raw_field_0x20\":" << record.raw_field_0x20
		<< ",\"raw_field_0x24_known\":" << (record.raw_field_0x24_known ? "true" : "false")
		<< ",\"raw_field_0x24\":" << record.raw_field_0x24
		<< ",\"raw_field_0x28_known\":" << (record.raw_field_0x28_known ? "true" : "false")
		<< ",\"raw_field_0x28\":" << record.raw_field_0x28
		<< ",\"raw_field_0x2c_known\":" << (record.raw_field_0x2c_known ? "true" : "false")
		<< ",\"raw_field_0x2c\":" << record.raw_field_0x2c
		<< ",\"raw_field_0x30_known\":" << (record.raw_field_0x30_known ? "true" : "false")
		<< ",\"raw_field_0x30\":" << record.raw_field_0x30
		<< ",\"raw_field_0x34_known\":" << (record.raw_field_0x34_known ? "true" : "false")
		<< ",\"raw_field_0x34\":" << record.raw_field_0x34
		<< ",\"raw_field_0x38_known\":" << (record.raw_field_0x38_known ? "true" : "false")
		<< ",\"raw_field_0x38\":" << record.raw_field_0x38
		<< ",\"pass_count\":" << record.pass_count
		<< ",\"action_count\":" << record.action_count
		<< ",\"passability_mask\":\"" << json_escape(record.passability_mask) << "\""
		<< ",\"action_mask\":\"" << json_escape(record.action_mask) << "\""
		<< ",\"terrain_mask_a_0x14\":" << record.terrain_mask_a_0x14
		<< ",\"terrain_mask_b_0x18\":" << record.terrain_mask_b_0x18
		<< ",\"descriptor_mask_fields_0x34_0x48_known\":" << (record.descriptor_mask_fields_0x34_0x48_known ? "true" : "false")
		<< ",\"descriptor_mask_fields_exact_def_msk\":" << (record.descriptor_mask_fields_exact_def_msk ? "true" : "false")
		<< ",\"descriptor_width_0x34\":" << record.descriptor_width_0x34
		<< ",\"descriptor_height_0x38\":" << record.descriptor_height_0x38
		<< ",\"descriptor_mask_a_0x3c_0x40\":" << record.descriptor_mask_a_0x3c_0x40
		<< ",\"descriptor_mask_b_0x44_0x48\":" << record.descriptor_mask_b_0x44_0x48
		<< ",\"terrain_a_names\":\"" << json_escape(record.terrain_a_names) << "\""
		<< ",\"terrain_b_names\":\"" << json_escape(record.terrain_b_names) << "\""
		<< ",\"rand_trn_backed\":" << (record.rand_trn_backed ? "true" : "false")
		<< "}";
}

void append_source_object_record_samples_json(std::ostream &out, const std::vector<SharedSourceObjectRecord0x4c> &records) {
	out << "[";
	for (size_t index = 0; index < records.size(); ++index) {
		if (index != 0) {
			out << ", ";
		}
		append_source_object_record_sample_json(out, records[index]);
	}
	out << "]";
}

void append_source_object_wrapper_bucket_sample_json(std::ostream &out, const SharedSourceObjectWrapperBucket0xe8 &bucket) {
	out << "{\"bucket_index_0x08\":" << bucket.bucket_index_0x08
		<< ",\"first_type_id_0x1c\":" << bucket.first_type_id_0x1c
		<< ",\"first_type_name\":\"" << json_escape(bucket.first_type_name) << "\""
		<< ",\"initialized_by_0x49db76\":" << (bucket.initialized_by_0x49db76 ? "true" : "false")
		<< ",\"record_count\":" << bucket.record_count
		<< ",\"first_source_record_index\":" << bucket.first_source_record_index
		<< ",\"last_source_record_index\":" << bucket.last_source_record_index
		<< ",\"source_record_index_sample\":";
	append_json_i32_array(out, bucket.source_record_index_sample);
	out << "}";
}

void append_source_object_wrapper_bucket_samples_json(std::ostream &out, const std::vector<SharedSourceObjectWrapperBucket0xe8> &buckets) {
	out << "[";
	for (size_t index = 0; index < buckets.size(); ++index) {
		if (index != 0) {
			out << ", ";
		}
		append_source_object_wrapper_bucket_sample_json(out, buckets[index]);
	}
	out << "]";
}

void append_source_object_selector_sample_json(std::ostream &out, const SharedSourceObjectSelectorResult4a9e40 &sample) {
	out << "{\"requested_lane\":" << sample.requested_lane
		<< ",\"requested_bucket_index_0x08\":" << sample.requested_bucket_index_0x08
		<< ",\"requested_source_field_0x20\":" << sample.requested_source_field_0x20
		<< ",\"bucket_found\":" << (sample.bucket_found ? "true" : "false")
		<< ",\"scanned_record_count\":" << sample.scanned_record_count
		<< ",\"source_0x20_reject_count\":" << sample.source_0x20_reject_count
		<< ",\"group_lane8_reject_count\":" << sample.group_lane8_reject_count
		<< ",\"mask_reject_count\":" << sample.mask_reject_count
		<< ",\"accepted_count\":" << sample.accepted_count
		<< ",\"accepted_source_record_index_sample\":";
	append_json_i32_array(out, sample.accepted_source_record_index_sample);
	out << ",\"selected\":" << (sample.selected ? "true" : "false")
		<< ",\"selected_candidate_index\":" << sample.selected_candidate_index
		<< ",\"selected_source_record_index\":" << sample.selected_source_record_index
		<< ",\"selected_type_id_0x1c\":" << sample.selected_type_id_0x1c
		<< ",\"selected_subtype_0x20\":" << sample.selected_subtype_0x20
		<< ",\"selected_group_0x24\":" << sample.selected_group_0x24
		<< ",\"selected_def_name\":\"" << json_escape(sample.selected_def_name) << "\""
		<< ",\"rng_state_before\":" << sample.rng_state_before
		<< ",\"rng_state_after\":" << sample.rng_state_after
		<< ",\"rng_consumed\":" << (sample.rng_consumed ? "true" : "false")
		<< ",\"rng_value\":" << sample.rng_value
		<< "}";
}

void append_source_object_selector_samples_json(std::ostream &out, const std::vector<SharedSourceObjectSelectorResult4a9e40> &samples) {
	out << "[";
	for (size_t index = 0; index < samples.size(); ++index) {
		if (index != 0) {
			out << ", ";
		}
		append_source_object_selector_sample_json(out, samples[index]);
	}
	out << "]";
}

void append_source_object_resolver_sample_json(std::ostream &out, const SharedSourceObjectResolverResult4af785 &sample) {
	out << "{\"input_source_catalog_index\":" << sample.input_source_catalog_index
		<< ",\"input_source_row\":" << sample.input_source_row
		<< ",\"input_def_name\":\"" << json_escape(sample.input_def_name) << "\""
		<< ",\"input_type_id_0x1c\":" << sample.input_type_id_0x1c
		<< ",\"input_subtype_0x20\":" << sample.input_subtype_0x20
		<< ",\"metadata_bucket_index_0x08\":" << sample.metadata_bucket_index_0x08
		<< ",\"resolver_lane_0x04\":" << sample.resolver_lane_0x04
		<< ",\"reused_existing_wrapper\":" << (sample.reused_existing_wrapper ? "true" : "false")
		<< ",\"created_new_wrapper\":" << (sample.created_new_wrapper ? "true" : "false")
		<< ",\"selected_wrapper_index\":" << sample.selected_wrapper_index
		<< ",\"scanned_bucket_wrapper_count\":" << sample.scanned_bucket_wrapper_count
		<< ",\"lane_reject_count\":" << sample.lane_reject_count
		<< ",\"source_0x20_reject_count\":" << sample.source_0x20_reject_count
		<< ",\"source_copy_mismatch_count\":" << sample.source_copy_mismatch_count
		<< ",\"bucket_size_before\":" << sample.bucket_size_before
		<< ",\"bucket_size_after\":" << sample.bucket_size_after
		<< ",\"source_pair_count_before\":" << sample.source_pair_count_before
		<< ",\"source_pair_count_after\":" << sample.source_pair_count_after
		<< ",\"appended_source_pair_0xedc\":" << (sample.appended_source_pair_0xedc ? "true" : "false")
		<< ",\"appended_wrapper_to_bucket\":" << (sample.appended_wrapper_to_bucket ? "true" : "false")
		<< ",\"copied_source_record\":" << (sample.copied_source_record ? "true" : "false")
		<< ",\"wrapper_0x10_known\":" << (sample.wrapper_0x10_known ? "true" : "false")
		<< ",\"wrapper_0x10\":" << sample.wrapper_0x10
		<< "}";
}

void append_source_object_resolver_samples_json(std::ostream &out, const std::vector<SharedSourceObjectResolverResult4af785> &samples) {
	out << "[";
	for (size_t index = 0; index < samples.size(); ++index) {
		if (index != 0) {
			out << ", ";
		}
		append_source_object_resolver_sample_json(out, samples[index]);
	}
	out << "]";
}

void append_source_object_resolved_wrapper_json(std::ostream &out, const SharedSourceObjectResolvedWrapper4af785 &wrapper) {
	out << "{"
		<< "\"wrapper_index\":" << wrapper.wrapper_index
		<< ",\"source_catalog_index\":" << wrapper.source_catalog_index
		<< ",\"metadata_bucket_index_0x08\":" << wrapper.metadata_bucket_index_0x08
		<< ",\"resolver_lane_0x04\":" << wrapper.resolver_lane_0x04
		<< ",\"wrapper_0x04\":" << wrapper.wrapper_0x04
		<< ",\"wrapper_0x10_known\":" << (wrapper.wrapper_0x10_known ? "true" : "false")
		<< ",\"wrapper_0x10\":" << wrapper.wrapper_0x10
		<< ",\"initialized_by_0x49db76\":" << (wrapper.initialized_by_0x49db76 ? "true" : "false")
		<< ",\"copied_source_record\":" << (wrapper.copied_source_record ? "true" : "false")
		<< ",\"source_record_copy\":";
	append_source_object_record_sample_json(out, wrapper.source_record_copy);
	out << "}";
}

void append_source_object_resolver_source_pair_json(std::ostream &out, const SharedSourceObjectResolverSourcePair4af785 &source_pair) {
	out << "{"
		<< "\"copied_source_catalog_index\":" << source_pair.copied_source_catalog_index
		<< ",\"wrapper_index\":" << source_pair.wrapper_index
		<< ",\"source_record_pointer_0x00_carried\":" << (source_pair.source_record_pointer_0x00_carried ? "true" : "false")
		<< ",\"source_lane_0x1c\":" << source_pair.source_lane_0x1c
		<< ",\"context_pointer_0x04_carried\":" << (source_pair.context_pointer_0x04_carried ? "true" : "false")
		<< ",\"context_wrapper_index_0x04\":" << source_pair.context_wrapper_index_0x04
		<< ",\"context_wrapper_lane_0x04\":" << source_pair.context_wrapper_lane_0x04
		<< ",\"context_wrapper_0x10_known\":" << (source_pair.context_wrapper_0x10_known ? "true" : "false")
		<< ",\"context_wrapper_0x10\":" << source_pair.context_wrapper_0x10
		<< ",\"source_record_copy\":";
	append_source_object_record_sample_json(out, source_pair.source_record_copy);
	out << ",\"context_wrapper_copy\":";
	append_source_object_resolved_wrapper_json(out, source_pair.context_wrapper_copy);
	out << "}";
}

void append_source_object_resolver_source_pairs_json(std::ostream &out, const std::vector<SharedSourceObjectResolverSourcePair4af785> &source_pairs) {
	out << "[";
	for (size_t index = 0; index < source_pairs.size(); ++index) {
		if (index != 0) {
			out << ", ";
		}
		append_source_object_resolver_source_pair_json(out, source_pairs[index]);
	}
	out << "]";
}

void append_source_object_record_catalog_json(std::ostream &out, const RecoveredOwnerGridPayload &payload) {
	out << "{"
		<< "\"schema_id\":\"rmg_native_source_object_record_catalog_0x49da08_v1\","
		<< "\"status\":\"source_record_catalog_metadata_0x08_wrapper_bucket_lanes_0x4af785_resolver_and_0x4af89f_0x4a9e40_selector_samples_preserved_descriptor_join_and_materialization_pending\","
		<< "\"h3maped_entry_anchor\":\"0x49da08_objects_txt_loader_0x49db76_wrapper_init_0x49dc9e_rand_trn_loader\","
		<< "\"present\":" << (payload.source_object_catalog_0x49da08_present ? "true" : "false") << ","
		<< "\"source_record_copy_size_bytes\":" << payload.source_object_catalog_0x4c_copy_size_bytes << ","
		<< "\"record_count\":" << payload.source_object_catalog_0x49da08_record_count << ","
		<< "\"objects_txt_record_count\":" << payload.source_object_catalog_objects_txt_record_count << ","
		<< "\"rand_trn_backed_record_count\":" << payload.source_object_catalog_rand_trn_backed_record_count << ","
		<< "\"passability_mask_record_count\":" << payload.source_object_catalog_passability_mask_record_count << ","
		<< "\"action_mask_record_count\":" << payload.source_object_catalog_action_mask_record_count << ","
		<< "\"descriptor_mask_field_record_count\":" << payload.source_object_catalog_descriptor_mask_field_record_count << ","
		<< "\"descriptor_mask_exact_def_msk_count\":" << payload.source_object_catalog_descriptor_mask_exact_def_msk_count << ","
		<< "\"descriptor_mask_default_msk_fallback_count\":" << payload.source_object_catalog_descriptor_mask_default_msk_fallback_count << ","
		<< "\"type53_record_count\":" << payload.source_object_catalog_type53_record_count << ","
		<< "\"type53_ambiguous_subtype_count\":" << payload.source_object_catalog_type53_ambiguous_subtype_count << ","
		<< "\"descriptor_only_mine_identity_ambiguous\":" << (payload.source_object_catalog_descriptor_only_mine_identity_ambiguous ? "true" : "false") << ","
		<< "\"identity_rule\":\"copied_0x4c_source_record_is_identity_authority_descriptor_plus_0x00_not_universal_row_id\","
		<< "\"wrapper_bucket_schema\":\"metadata_entry_plus_0x08_bucket_index_bounded_by_0xe8_and_initialized_by_0x49db76\","
		<< "\"resolver_schema\":\"0x4af785_stateful_source_record_copy_reuse_or_create_wrapper_bucket_append_and_generator_0xedc_pair_append\","
		<< "\"selector_schema\":\"0x4af89f_source_0x18_lane_scan_then_0x4a9e40_bucket_0x08_source_0x20_group_0x24_mask_0x18_rng_selection\","
		<< "\"wrapper_buckets_present\":" << (payload.source_object_wrapper_buckets_0x49db76_present ? "true" : "false") << ","
		<< "\"wrapper_bucket_count_0xe8\":" << payload.source_object_wrapper_bucket_count_0xe8 << ","
		<< "\"wrapper_initialized_bucket_count\":" << payload.source_object_wrapper_initialized_bucket_count << ","
		<< "\"wrapper_non_empty_bucket_count\":" << payload.source_object_wrapper_non_empty_bucket_count << ","
		<< "\"wrapper_total_source_record_references\":" << payload.source_object_wrapper_total_source_record_references << ","
		<< "\"wrapper_out_of_range_source_record_count\":" << payload.source_object_wrapper_out_of_range_source_record_count << ","
		<< "\"wrapper_max_bucket_index_0x08\":" << payload.source_object_wrapper_max_bucket_index_0x08 << ","
		<< "\"wrapper_max_bucket_record_count\":" << payload.source_object_wrapper_max_bucket_record_count << ","
		<< "\"wrapper_bucket_samples\":";
	append_source_object_wrapper_bucket_samples_json(out, payload.source_object_wrapper_bucket_samples);
	out << ","
		<< "\"selector_samples_0x4a9e40\":";
	append_source_object_selector_samples_json(out, payload.source_object_selector_samples_0x4a9e40);
	out << ","
		<< "\"resolver_samples_0x4af785\":";
	append_source_object_resolver_samples_json(out, payload.source_object_resolver_samples_0x4af785);
	out << ","
		<< "\"remaining_blockers\":[\"0x4af785_resolver_not_wired_to_live_descriptor_object_materialization\", \"0x4903e8_descriptor_source_join\", \"selected_copied_source_record_through_object_materialization\", \"relation_object_caller_order\"],"
		<< "\"samples\":";
	append_source_object_record_samples_json(out, payload.source_object_catalog_samples);
	out << "}";
}

void append_player_slot_assignment_records_json(std::ostream &out, const std::vector<SharedPlayerSlotAssignmentRecord> &records) {
	out << "[";
	for (size_t index = 0; index < records.size(); ++index) {
		if (index != 0) {
			out << ", ";
		}
		const SharedPlayerSlotAssignmentRecord &record = records[index];
		out << "{\"source_owner_index\":" << record.source_owner_index
			<< ",\"actual_player_color\":" << record.actual_player_color
			<< ",\"human\":" << (record.human ? "true" : "false")
			<< "}";
	}
	out << "]";
}

void append_terrain_visual_missing_bucket_samples_json(std::ostream &out, const std::vector<TerrainVisualMissingBucketSample> &samples) {
	out << "[";
	for (size_t index = 0; index < samples.size(); ++index) {
		if (index != 0) {
			out << ", ";
		}
		const TerrainVisualMissingBucketSample &sample = samples[index];
		out << "{\"level\":" << sample.level
			<< ",\"x\":" << sample.x
			<< ",\"y\":" << sample.y
			<< ",\"terrain_id\":" << sample.terrain_id
			<< ",\"shape_class\":" << sample.shape_class
			<< ",\"flag_a\":" << sample.flag_a
			<< ",\"flag_b\":" << sample.flag_b
			<< ",\"neighbor_mask\":" << sample.neighbor_mask
			<< ",\"row_table_count\":" << sample.row_table_count
			<< ",\"final_sweep\":" << (sample.final_sweep ? "true" : "false")
			<< "}";
	}
	out << "]";
}

void append_generator_object_vector_state_json(std::ostream &out, const SharedGeneratorObjectVectorState &state) {
	out << "{\"label\":\"" << json_escape(state.label) << "\""
		<< ",\"begin_offset\":" << state.begin_offset
		<< ",\"end_offset\":" << state.end_offset
		<< ",\"capacity_offset\":" << state.capacity_offset
		<< ",\"present\":" << (state.present ? "true" : "false")
		<< ",\"contents_known\":" << (state.contents_known ? "true" : "false")
		<< ",\"count_known\":" << (state.count_known ? "true" : "false")
		<< ",\"count\":" << state.count
		<< ",\"count_sourced_from_vector\":" << (state.count_sourced_from_vector ? "true" : "false")
		<< ",\"count_source_vector_label\":\"" << json_escape(state.count_source_vector_label) << "\""
		<< ",\"zero_initialized_contents_known_when_count_known\":" << (state.zero_initialized_contents_known_when_count_known ? "true" : "false")
		<< ",\"element_size_bytes\":" << state.element_size_bytes
		<< "}";
}

void append_object_record_references_4a54a7_json(std::ostream &out, const std::vector<SharedObjectRecordReference4a54a7> &records) {
	out << "[";
	for (size_t index = 0; index < records.size(); ++index) {
		if (index != 0) {
			out << ",";
		}
		const SharedObjectRecordReference4a54a7 &record = records[index];
		out << "{\"object_record_key\":" << record.object_record_key
			<< ",\"descriptor_type_0x1c\":" << record.descriptor_type_0x1c
			<< ",\"x\":" << record.x
			<< ",\"y\":" << record.y
			<< ",\"level\":" << record.level
			<< ",\"connection_fallback_record_0x4a7605_0x4a5e03_known\":" << (record.connection_fallback_record_0x4a7605_0x4a5e03_known ? "true" : "false")
			<< ",\"connection_fallback_arg0_0x4a5e03\":" << record.connection_fallback_arg0_0x4a5e03
			<< ",\"connection_fallback_descriptor_pointer\":" << record.connection_fallback_descriptor_pointer
			<< ",\"connection_fallback_expected_owner_byte2\":" << record.connection_fallback_expected_owner_byte2
			<< ",\"object_record_key_allocated_by_0x4a93a2\":" << (record.object_record_key_allocated_by_0x4a93a2 ? "true" : "false")
			<< ",\"source_order_direct_record_0x4a8d2c_0x4a93a2_known\":" << (record.source_order_direct_record_0x4a8d2c_0x4a93a2_known ? "true" : "false")
			<< ",\"weighted_record_0x4a93a2_known\":" << (record.weighted_record_0x4a93a2_known ? "true" : "false")
			<< ",\"object_record_vtable_0x00\":" << record.object_record_vtable_0x00
			<< ",\"object_record_sequence_0x1c\":" << record.object_record_sequence_0x1c
			<< ",\"object_record_selected_index_0x20\":" << record.object_record_selected_index_0x20
			<< ",\"object_record_enabled_word_0x24\":" << record.object_record_enabled_word_0x24
			<< ",\"object_record_enabled_low_byte_0x24\":" << (record.object_record_enabled_low_byte_0x24 ? "true" : "false")
			<< ",\"source_descriptor_join_0x4903e8_known\":" << (record.source_descriptor_join_0x4903e8_known ? "true" : "false")
			<< ",\"weighted_type98_descriptor_bridge_0x4a93a2_known\":" << (record.weighted_type98_descriptor_bridge_0x4a93a2_known ? "true" : "false")
			<< ",\"descriptor_source_key_0x00\":" << record.descriptor_source_key_0x00
			<< ",\"selected_wrapper_index_0x4af785\":" << record.selected_wrapper_index_0x4af785
			<< ",\"source_catalog_index_0x49da08\":" << record.source_catalog_index_0x49da08
			<< ",\"copied_source_record_carried\":" << (record.copied_source_record_carried ? "true" : "false")
			<< ",\"source_record_copy\":";
		if (record.copied_source_record_carried) {
			append_source_object_record_sample_json(out, record.source_record_copy);
		} else {
			out << "{}";
		}
		out << "}";
	}
	out << "]";
}

void append_generator_relation_records_json(std::ostream &out, const std::vector<SharedGeneratorRelationRecordState> &records) {
	out << "[";
	for (size_t index = 0; index < records.size(); ++index) {
		if (index != 0) {
			out << ",";
		}
		const SharedGeneratorRelationRecordState &record = records[index];
		out << "{\"source_link_index\":" << record.source_link_index
			<< ",\"owner_runtime_zone_index\":" << record.owner_runtime_zone_index
			<< ",\"owner_source_zone_id\":" << record.owner_source_zone_id
			<< ",\"target_runtime_zone_index\":" << record.target_runtime_zone_index
			<< ",\"target_source_zone_id\":" << record.target_source_zone_id
			<< ",\"guard_value\":" << record.guard_value
			<< ",\"wide\":" << (record.wide ? "true" : "false")
			<< ",\"border_guard\":" << (record.border_guard ? "true" : "false")
			<< ",\"reciprocal\":" << (record.reciprocal ? "true" : "false")
			<< ",\"control_dword_0x08\":" << record.control_dword_0x08
			<< "}";
	}
	out << "]";
}

void append_generator_source_endpoint_records_json(std::ostream &out, const std::vector<SharedGeneratorSourceEndpointRecordState> &records) {
	out << "[";
	for (size_t index = 0; index < records.size(); ++index) {
		if (index != 0) {
			out << ",";
		}
		const SharedGeneratorSourceEndpointRecordState &record = records[index];
		out << "{\"source_link_index\":" << record.source_link_index
			<< ",\"owner_runtime_zone_index\":" << record.owner_runtime_zone_index
			<< ",\"owner_source_zone_id\":" << record.owner_source_zone_id
			<< ",\"target_runtime_zone_index\":" << record.target_runtime_zone_index
			<< ",\"target_source_zone_id\":" << record.target_source_zone_id
			<< ",\"source_endpoint\":" << record.source_endpoint
			<< ",\"target_source_endpoint\":" << record.target_source_endpoint
			<< ",\"guard_value\":" << record.guard_value
			<< ",\"wide\":" << (record.wide ? "true" : "false")
			<< ",\"border_guard\":" << (record.border_guard ? "true" : "false")
			<< ",\"reciprocal\":" << (record.reciprocal ? "true" : "false")
			<< "}";
	}
	out << "]";
}

void append_coordinate_candidates_json(std::ostream &out, const std::vector<SharedCoordinateCandidate4a17f5> &candidates) {
	out << "[";
	for (size_t index = 0; index < candidates.size(); ++index) {
		if (index != 0) {
			out << ",";
		}
		const SharedCoordinateCandidate4a17f5 &candidate = candidates[index];
		out << "{\"x\":" << candidate.x
			<< ",\"y\":" << candidate.y
			<< ",\"level\":" << candidate.level
			<< "}";
	}
	out << "]";
}

void append_generator_coordinate_candidate_vectors_json(std::ostream &out, const std::vector<SharedGeneratorCoordinateCandidateVectorState4a1f3b> &vectors) {
	out << "[";
	for (size_t index = 0; index < vectors.size(); ++index) {
		if (index != 0) {
			out << ",";
		}
		const SharedGeneratorCoordinateCandidateVectorState4a1f3b &vector = vectors[index];
		out << "{\"runtime_zone_index\":" << vector.runtime_zone_index
			<< ",\"pass_id\":\"" << json_escape(vector.pass_id) << "\""
			<< ",\"candidate_source\":\"" << json_escape(vector.candidate_source) << "\""
			<< ",\"candidate_count_before_prune\":" << vector.candidate_count_before_prune
			<< ",\"candidate_count_after_prune\":" << vector.candidate_count_after_prune
			<< ",\"explicit_link_base_count\":" << vector.explicit_link_base_count
			<< ",\"selected_candidate_index\":" << vector.selected_candidate_index
			<< ",\"rng_value\":" << vector.rng_value
			<< ",\"blocked\":" << (vector.blocked ? "true" : "false")
			<< ",\"selected_candidate_known\":" << (vector.selected_candidate_known ? "true" : "false")
			<< ",\"selected_candidate\":";
		if (vector.selected_candidate_known) {
			std::vector<SharedCoordinateCandidate4a17f5> selected = { vector.selected_candidate };
			append_coordinate_candidates_json(out, selected);
		} else {
			out << "[]";
		}
		out << ",\"candidates_before_prune_4a17f5\":";
		append_coordinate_candidates_json(out, vector.candidates_before_prune_4a17f5);
		out << ",\"candidates_after_prune_4a1ad8\":";
		append_coordinate_candidates_json(out, vector.candidates_after_prune_4a1ad8);
		out << "}";
	}
	out << "]";
}

void append_generator_relation_owner_vectors_json(std::ostream &out, const std::vector<SharedGeneratorRelationOwnerState> &owners) {
	out << "[";
	for (size_t index = 0; index < owners.size(); ++index) {
		if (index != 0) {
			out << ",";
		}
		const SharedGeneratorRelationOwnerState &owner = owners[index];
		out << "{\"owner_vector_index\":" << owner.owner_vector_index
			<< ",\"runtime_zone_index\":" << owner.runtime_zone_index
			<< ",\"source_zone_id\":" << owner.source_zone_id
			<< ",\"source_index\":" << owner.source_index
			<< ",\"constructor_0x49b452_known\":" << (owner.constructor_0x49b452_known ? "true" : "false")
			<< ",\"source_pointer_0x00_known\":" << (owner.source_pointer_0x00_known ? "true" : "false")
			<< ",\"source_pointer_source_index_0x00\":" << owner.source_pointer_source_index_0x00
			<< ",\"town_choice_0x04_known\":" << (owner.town_choice_0x04_known ? "true" : "false")
			<< ",\"town_choice_0x04\":" << owner.town_choice_0x04
			<< ",\"source_owner_slot_0x1c_known\":" << (owner.source_owner_slot_0x1c_known ? "true" : "false")
			<< ",\"source_owner_slot_0x1c\":" << owner.source_owner_slot_0x1c
			<< ",\"coordinate_triple_0x10_0x18_known\":" << (owner.coordinate_triple_0x10_0x18_known ? "true" : "false")
			<< ",\"coordinate_x_0x10\":" << owner.coordinate_x_0x10
			<< ",\"coordinate_y_0x14\":" << owner.coordinate_y_0x14
			<< ",\"coordinate_level_0x18\":" << owner.coordinate_level_0x18
			<< ",\"source_endpoint_vector_0xc8_0xcc_present\":" << (owner.source_endpoint_vector_0xc8_0xcc_present ? "true" : "false")
			<< ",\"source_endpoint_vector_0xc8_0xcc_contents_known\":" << (owner.source_endpoint_vector_0xc8_0xcc_contents_known ? "true" : "false")
			<< ",\"source_endpoint_vector_0xc8_0xcc_count_known\":" << (owner.source_endpoint_vector_0xc8_0xcc_count_known ? "true" : "false")
			<< ",\"source_endpoint_vector_0xc8_0xcc_count\":" << owner.source_endpoint_vector_0xc8_0xcc_count
			<< ",\"source_endpoint_vector_0xc8_0xcc_stride_bytes\":" << owner.source_endpoint_vector_0xc8_0xcc_stride_bytes
			<< ",\"source_endpoint_records_0xc8_0xcc\":";
		append_generator_source_endpoint_records_json(out, owner.source_endpoint_records_0xc8_0xcc);
		out << ",\"scan_bounds_0x20_0x2c_known\":" << (owner.scan_bounds_0x20_0x2c_known ? "true" : "false")
			<< ",\"scan_bound_low_x_0x20\":" << owner.scan_bound_low_x_0x20
			<< ",\"scan_bound_low_y_0x24\":" << owner.scan_bound_low_y_0x24
			<< ",\"scan_bound_high_x_0x28\":" << owner.scan_bound_high_x_0x28
			<< ",\"scan_bound_high_y_0x2c\":" << owner.scan_bound_high_y_0x2c
			<< ",\"byte_0x3c_known\":" << (owner.byte_0x3c_known ? "true" : "false")
			<< ",\"byte_0x3c\":" << int32_t(owner.byte_0x3c)
			<< ",\"descriptor_type_counter_table_0x44_known\":" << (owner.descriptor_type_counter_table_0x44_known ? "true" : "false")
			<< ",\"descriptor_type_counter_table_0x44_byte_size\":" << owner.descriptor_type_counter_table_0x44_byte_size
			<< ",\"descriptor_type_counter_table_0x44_zero_count\":" << owner.descriptor_type_counter_table_0x44_zero_count
			<< ",\"descriptor_type_counters_0x44\":";
		append_json_u32_array(out, owner.descriptor_type_counters_0x44);
		out << ",\"owner_local_vectors_0x3e4_0x3f4_0x404_known\":" << (owner.owner_local_vectors_0x3e4_0x3f4_0x404_known ? "true" : "false")
			<< ",\"owner_local_vector_0x3e4_count\":" << owner.owner_local_vector_0x3e4_count
			<< ",\"owner_local_vector_0x3f4_count\":" << owner.owner_local_vector_0x3f4_count
			<< ",\"owner_local_vector_0x404_count\":" << owner.owner_local_vector_0x404_count
			<< ",\"coordinate_candidate_vectors_0x4a1f3b_known\":" << (owner.coordinate_candidate_vectors_0x4a1f3b_known ? "true" : "false")
			<< ",\"coordinate_candidate_vector_step_count\":" << owner.coordinate_candidate_vector_step_count
			<< ",\"coordinate_candidate_after_prune_total_count\":" << owner.coordinate_candidate_after_prune_total_count
			<< ",\"coordinate_candidate_vectors_0x4a1f3b\":";
		append_generator_coordinate_candidate_vectors_json(out, owner.coordinate_candidate_vectors_0x4a1f3b);
		out << ",\"relation_record_count\":" << owner.relation_record_count
			<< ",\"relation_records\":";
		append_generator_relation_records_json(out, owner.relation_records);
		out << "}";
	}
	out << "]";
}

void append_weighted_scheduler_thresholds_4a8db2_json(std::ostream &out, const std::vector<SharedWeightedSchedulerThreshold4a8db2> &thresholds) {
	out << "[";
	for (size_t index = 0; index < thresholds.size(); ++index) {
		if (index != 0) {
			out << ",";
		}
		const SharedWeightedSchedulerThreshold4a8db2 &threshold = thresholds[index];
		out << "{\"source_density_fields_known\":" << (threshold.source_density_fields_known ? "true" : "false")
			<< ",\"player_castle_density_0x2c\":" << threshold.player_castle_density_0x2c
			<< ",\"player_town_density_0x28\":" << threshold.player_town_density_0x28
			<< ",\"neutral_castle_density_0x3c\":" << threshold.neutral_castle_density_0x3c
			<< ",\"neutral_town_density_0x38\":" << threshold.neutral_town_density_0x38
			<< ",\"positive_density_sum\":" << threshold.positive_density_sum
			<< ",\"threshold_arg_0x18_known\":" << (threshold.threshold_arg_0x18_known ? "true" : "false")
			<< ",\"threshold_arg_0x18\":" << threshold.threshold_arg_0x18
			<< ",\"blocked_reason\":\"" << json_escape(threshold.blocked_reason) << "\""
			<< "}";
	}
	out << "]";
}

void append_weighted_object_candidate_4a901a_json(std::ostream &out, const SharedWeightedObjectCandidate4a901a &candidate) {
	out << "{\"x\":" << candidate.x
		<< ",\"y\":" << candidate.y
		<< ",\"level\":" << candidate.level
		<< ",\"low_word_score_0x20\":" << candidate.low_word_score_0x20
		<< "}";
}

void append_weighted_object_candidate_vector_4a901a_json(std::ostream &out, const std::vector<SharedWeightedObjectCandidate4a901a> &candidates) {
	out << "[";
	for (size_t index = 0; index < candidates.size(); ++index) {
		if (index != 0) {
			out << ",";
		}
		append_weighted_object_candidate_4a901a_json(out, candidates[index]);
	}
	out << "]";
}

void append_weighted_object_candidate_vectors_4a901a_json(std::ostream &out, const std::vector<SharedWeightedObjectCandidateVectorState4a901a> &vectors) {
	out << "[";
	for (size_t index = 0; index < vectors.size(); ++index) {
		if (index != 0) {
			out << ",";
		}
		const SharedWeightedObjectCandidateVectorState4a901a &vector = vectors[index];
		out << "{\"descriptor_source_bridge_known\":" << (vector.descriptor_source_bridge_known ? "true" : "false")
			<< ",\"copied_source_record_carried\":" << (vector.copied_source_record_carried ? "true" : "false")
			<< ",\"scan_bounds_known\":" << (vector.scan_bounds_known ? "true" : "false")
			<< ",\"scan_bounds_non_empty\":" << (vector.scan_bounds_non_empty ? "true" : "false")
			<< ",\"relation_owner_byte_known\":" << (vector.relation_owner_byte_known ? "true" : "false")
			<< ",\"threshold_arg_0x18_known\":" << (vector.threshold_arg_0x18_known ? "true" : "false")
			<< ",\"relation_owner_byte2\":" << vector.relation_owner_byte2
			<< ",\"scan_bound_low_x\":" << vector.scan_bound_low_x
			<< ",\"scan_bound_low_y\":" << vector.scan_bound_low_y
			<< ",\"scan_bound_high_x\":" << vector.scan_bound_high_x
			<< ",\"scan_bound_high_y\":" << vector.scan_bound_high_y
			<< ",\"level\":" << vector.level
			<< ",\"threshold_arg_0x18_initial\":" << vector.threshold_arg_0x18_initial
			<< ",\"threshold_arg_0x18_after_scan\":" << vector.threshold_arg_0x18_after_scan
			<< ",\"scanned_cell_count\":" << vector.scanned_cell_count
			<< ",\"out_of_bounds_cell_count\":" << vector.out_of_bounds_cell_count
			<< ",\"unknown_cell_word_count\":" << vector.unknown_cell_word_count
			<< ",\"owner_byte_reject_count\":" << vector.owner_byte_reject_count
			<< ",\"value_floor_reject_count\":" << vector.value_floor_reject_count
			<< ",\"eligibility_reject_count_0x49aa93\":" << vector.eligibility_reject_count_0x49aa93
			<< ",\"local_vector_clear_count_0x4ae52a\":" << vector.local_vector_clear_count_0x4ae52a
			<< ",\"local_vector_append_count_0x4ae1fd\":" << vector.local_vector_append_count_0x4ae1fd
			<< ",\"accepted_candidate_count\":" << vector.accepted_candidate_count
			<< ",\"rng_value_0x4e7276\":" << vector.rng_value_0x4e7276
			<< ",\"selected_candidate_index\":" << vector.selected_candidate_index
			<< ",\"selected_candidate_known\":" << (vector.selected_candidate_known ? "true" : "false")
			<< ",\"selected_candidate\":";
		append_weighted_object_candidate_4a901a_json(out, vector.selected_candidate);
		out << ",\"accepted_candidates_0x4ae1fd\":";
		append_weighted_object_candidate_vector_4a901a_json(out, vector.accepted_candidates_0x4ae1fd);
		out << ",\"allocated_record_0x4a93a2\":" << (vector.allocated_record_0x4a93a2 ? "true" : "false")
			<< ",\"committed_through_0x4a54a7\":" << (vector.committed_through_0x4a54a7 ? "true" : "false")
			<< ",\"object_record_key\":" << vector.object_record_key
			<< ",\"object_record_key_known\":" << (vector.object_record_key_known ? "true" : "false")
			<< ",\"object_vector_count_after\":" << vector.object_vector_count_after
			<< ",\"blocked_reason\":\"" << json_escape(vector.blocked_reason) << "\""
			<< "}";
	}
	out << "]";
}

void append_generator_object_private_state_json(std::ostream &out, const SharedGeneratorObjectPrivateState &state) {
	out << "{"
		<< "\"schema_id\":\"rmg_native_generator_object_private_state_v1\","
		<< "\"status\":\"partial_recovered_generator_object_layout_owned_until_relation_object_scan_consumers_are_ported\","
		<< "\"present\":" << (state.present ? "true" : "false") << ","
		<< "\"generated_cell_buffer_offset_0x14\":" << state.generated_cell_buffer_offset_0x14 << ","
		<< "\"width_offset_0x18\":" << state.width_offset_0x18 << ","
		<< "\"height_offset_0x1c\":" << state.height_offset_0x1c << ","
		<< "\"level_count_offset_0x20\":" << state.level_count_offset_0x20 << ","
		<< "\"generated_cell_buffer_owned\":" << (state.generated_cell_buffer_owned ? "true" : "false") << ","
		<< "\"generated_cell_buffer_record_count\":" << state.generated_cell_buffer_record_count << ","
		<< "\"width\":" << state.width << ","
		<< "\"height\":" << state.height << ","
		<< "\"level_count\":" << state.level_count << ","
		<< "\"source_owner_player_slots_ed8_ee0_ee4_present\":" << (state.source_owner_player_slots_ed8_ee0_ee4_present ? "true" : "false") << ","
		<< "\"selected_color_order_ed8_count\":" << state.selected_color_order_ed8_count << ","
		<< "\"raw_source_owner_slots_ee0_count\":" << state.raw_source_owner_slots_ee0_count << ","
		<< "\"mapped_source_owner_slots_ee4_count\":" << state.mapped_source_owner_slots_ee4_count << ","
		<< "\"endpoint_cursor_0xf58_present\":" << (state.endpoint_cursor_0xf58_present ? "true" : "false") << ","
		<< "\"endpoint_cursor_0xf58_known\":" << (state.endpoint_cursor_0xf58_known ? "true" : "false") << ","
		<< "\"endpoint_cursor_0xf58\":" << state.endpoint_cursor_0xf58 << ","
		<< "\"endpoint_cursor_0xf58_source\":\"0x49ecf2_zeroes_generator_plus_0xf58_before_endpoint_cursor_plus_0xf5c_remains_unseeded\","
		<< "\"endpoint_cursor_0xf5c_present\":" << (state.endpoint_cursor_0xf5c_present ? "true" : "false") << ","
		<< "\"endpoint_cursor_0xf5c_known\":" << (state.endpoint_cursor_0xf5c_known ? "true" : "false") << ","
		<< "\"endpoint_cursor_0xf5c\":" << state.endpoint_cursor_0xf5c << ","
		<< "\"endpoint_projection_vector_c8_cc_source_owned_0x4a1f3b\":" << (state.endpoint_projection_vector_c8_cc_source_owned_0x4a1f3b ? "true" : "false") << ","
		<< "\"endpoint_projection_vector_c8_cc_record_count\":" << state.endpoint_projection_vector_c8_cc_record_count << ","
		<< "\"endpoint_projection_records_c8_cc\":";
	append_generator_source_endpoint_records_json(out, state.endpoint_projection_records_c8_cc);
	out << ","
		<< "\"endpoint_cursor_vector_d8_dc_source_owned\":" << (state.endpoint_cursor_vector_d8_dc_source_owned ? "true" : "false") << ","
		<< "\"endpoint_cursor_vector_d8_dc_supported_land_exclusion_known\":" << (state.endpoint_cursor_vector_d8_dc_supported_land_exclusion_known ? "true" : "false") << ","
		<< "\"endpoint_cursor_producer_d014\":{"
		<< "\"recovered_supported_land_exclusion_known\":" << (state.endpoint_cursor_producer_d014.recovered_supported_land_exclusion_known ? "true" : "false") << ","
		<< "\"supported_land_endpoint_cursor_key_range_known\":" << (state.endpoint_cursor_producer_d014.supported_land_endpoint_cursor_key_range_known ? "true" : "false") << ","
		<< "\"supported_land_endpoint_cursor_key_count\":" << state.endpoint_cursor_producer_d014.supported_land_endpoint_cursor_key_count << ","
		<< "\"supported_land_observed_stale_cursor_0xf5c_known\":" << (state.endpoint_cursor_producer_d014.supported_land_observed_stale_cursor_0xf5c_known ? "true" : "false") << ","
		<< "\"supported_land_observed_stale_cursor_0xf5c\":" << state.endpoint_cursor_producer_d014.supported_land_observed_stale_cursor_0xf5c << ","
		<< "\"setup_zeroed_cursor_0xf58_0x49ecf2_known\":" << (state.endpoint_cursor_producer_d014.setup_zeroed_cursor_0xf58_0x49ecf2_known ? "true" : "false") << ","
		<< "\"endpoint_byte_state_zero_init_from_d8_count_0x49f95a_known\":" << (state.endpoint_cursor_producer_d014.endpoint_byte_state_zero_init_from_d8_count_0x49f95a_known ? "true" : "false") << ","
		<< "\"direct_cursor_writer_surface_bounded\":" << (state.endpoint_cursor_producer_d014.direct_cursor_writer_surface_bounded ? "true" : "false") << ","
		<< "\"setup_seeds_cursor_0xf5c\":" << (state.endpoint_cursor_producer_d014.setup_seeds_cursor_0xf5c ? "true" : "false") << ","
		<< "\"successful_cursor_0xf5c_seed_source_known\":" << (state.endpoint_cursor_producer_d014.successful_cursor_0xf5c_seed_source_known ? "true" : "false") << ","
		<< "\"supported_land_success_path_reached\":" << (state.endpoint_cursor_producer_d014.supported_land_success_path_reached ? "true" : "false") << ","
		<< "\"supported_land_live_0x4a606b_reached\":" << (state.endpoint_cursor_producer_d014.supported_land_live_0x4a606b_reached ? "true" : "false") << ","
		<< "\"supported_land_live_0x4a696b_relation_match_reached\":" << (state.endpoint_cursor_producer_d014.supported_land_live_0x4a696b_relation_match_reached ? "true" : "false") << ","
		<< "\"direct_cursor_writer_entry_count\":" << state.endpoint_cursor_producer_d014.direct_cursor_writer_entry_count << ","
		<< "\"direct_cursor_writer_entries\":";
	append_json_string_array(out, state.endpoint_cursor_producer_d014.direct_cursor_writer_entries);
	out << ",\"missing_cursor_seed_source\":\"" << json_escape(state.endpoint_cursor_producer_d014.missing_cursor_seed_source) << "\""
		<< "},"
		<< "\"connection_materialization_caller_prep_d014\":{"
		<< "\"recovered_helper_contract_0x4a5e73_known\":" << (state.connection_materialization_caller_prep_d014.recovered_helper_contract_0x4a5e73_known ? "true" : "false") << ","
		<< "\"recovered_explicit_input_0x4a606b_known\":" << (state.connection_materialization_caller_prep_d014.recovered_explicit_input_0x4a606b_known ? "true" : "false") << ","
		<< "\"recovered_no_object_projection_chain_0x4a5a23_known\":" << (state.connection_materialization_caller_prep_d014.recovered_no_object_projection_chain_0x4a5a23_known ? "true" : "false") << ","
		<< "\"live_0x4a5e73_to_0x4a606b_target_mode_excluded\":" << (state.connection_materialization_caller_prep_d014.live_0x4a5e73_to_0x4a606b_target_mode_excluded ? "true" : "false") << ","
		<< "\"live_0x4a696b_target_mode_excluded\":" << (state.connection_materialization_caller_prep_d014.live_0x4a696b_target_mode_excluded ? "true" : "false") << ","
		<< "\"fallback_0x4a7605_to_0x4a5e03_source_backed\":" << (state.connection_materialization_caller_prep_d014.fallback_0x4a7605_to_0x4a5e03_source_backed ? "true" : "false") << ","
		<< "\"live_endpoint_materialization_allowed\":" << (state.connection_materialization_caller_prep_d014.live_endpoint_materialization_allowed ? "true" : "false") << ","
		<< "\"remaining_live_materialization_blocker\":\"" << json_escape(state.connection_materialization_caller_prep_d014.remaining_live_materialization_blocker) << "\""
		<< "},"
		<< "\"descriptor_counter_table_0x1110_present\":" << (state.descriptor_counter_table_0x1110_present ? "true" : "false") << ","
		<< "\"descriptor_counter_table_0x1110_contents_known\":" << (state.descriptor_counter_table_0x1110_contents_known ? "true" : "false") << ","
		<< "\"descriptor_counter_table_0x1110_known_count\":" << state.descriptor_counter_table_0x1110_known_count << ","
		<< "\"descriptor_counter_table_0x1110_byte_size\":" << h3maped_rmg_core::DESCRIPTOR_COUNTER_TABLE_0X1110_BYTE_SIZE << ","
		<< "\"descriptor_counter_table_0x1110_zero_count\":" << state.descriptor_counter_table_0x1110_zero_count << ","
		<< "\"descriptor_counter_table_0x1110_source\":\"0x49ecf2_zeroes_generator_plus_0x1110_over_0x3a0_bytes_before_relation_object_commits\","
		<< "\"object_record_sequence_allocator_0xf44_present\":" << (state.object_record_sequence_allocator_0xf44_present ? "true" : "false") << ","
		<< "\"object_record_sequence_allocator_0xf44_known\":" << (state.object_record_sequence_allocator_0xf44_known ? "true" : "false") << ","
		<< "\"object_record_sequence_allocator_0xf44\":" << state.object_record_sequence_allocator_0xf44 << ","
		<< "\"object_record_sequence_allocator_0xf44_source\":\"0x49ecf2_initializes_generator_plus_0xf44_to_1_and_0x4a93a2_increments_before_record_plus_0x1c_store\","
		<< "\"native_object_record_key_allocator_0x4a93a2_known\":" << (state.native_object_record_key_allocator_0x4a93a2_known ? "true" : "false") << ","
		<< "\"next_native_object_record_key_0x4a93a2\":" << state.next_native_object_record_key_0x4a93a2 << ","
		<< "\"object_record_allocation_count_0x4a93a2\":" << state.object_record_allocation_count_0x4a93a2 << ","
		<< "\"weighted_scheduler_thresholds_0x4a8db2_known\":" << (state.weighted_scheduler_thresholds_0x4a8db2_known ? "true" : "false") << ","
		<< "\"weighted_scheduler_threshold_count_0x4a8db2\":" << state.weighted_scheduler_threshold_count_0x4a8db2 << ","
		<< "\"weighted_scheduler_thresholds_0x4a8db2\":";
	append_weighted_scheduler_thresholds_4a8db2_json(out, state.weighted_scheduler_thresholds_0x4a8db2);
	out << ","
		<< "\"weighted_candidate_vectors_0x4a901a_known\":" << (state.weighted_candidate_vectors_0x4a901a_known ? "true" : "false") << ","
		<< "\"weighted_candidate_vector_count_0x4a901a\":" << state.weighted_candidate_vector_count_0x4a901a << ","
		<< "\"weighted_candidate_total_count_0x4a901a\":" << state.weighted_candidate_total_count_0x4a901a << ","
		<< "\"weighted_candidate_selected_count_0x4a901a\":" << state.weighted_candidate_selected_count_0x4a901a << ","
		<< "\"weighted_candidate_commit_count_0x4a901a\":" << state.weighted_candidate_commit_count_0x4a901a << ","
		<< "\"weighted_candidate_vectors_0x4a901a\":";
	append_weighted_object_candidate_vectors_4a901a_json(out, state.weighted_candidate_vectors_0x4a901a);
	out << ","
		<< "\"source_order_direct_candidates_0x4a93a2_known\":" << (state.source_order_direct_candidates_0x4a93a2_known ? "true" : "false") << ","
		<< "\"source_order_direct_candidate_vector_count_0x4a93a2\":" << state.source_order_direct_candidate_vector_count_0x4a93a2 << ","
		<< "\"source_order_direct_candidate_total_count_0x4a93a2\":" << state.source_order_direct_candidate_total_count_0x4a93a2 << ","
		<< "\"source_order_direct_selected_count_0x4a93a2\":" << state.source_order_direct_selected_count_0x4a93a2 << ","
		<< "\"source_order_direct_commit_count_0x4a93a2\":" << state.source_order_direct_commit_count_0x4a93a2 << ","
		<< "\"source_pair_records_edc_count\":" << state.source_pair_records_edc.size() << ","
		<< "\"source_pair_records_edc\":";
	append_source_object_resolver_source_pairs_json(out, state.source_pair_records_edc);
	out << ","
		<< "\"connection_fallback_materialization_0x4a7605_0x4a5e03_known\":" << (state.connection_fallback_materialization_0x4a7605_0x4a5e03_known ? "true" : "false") << ","
		<< "\"connection_fallback_materialization_record_count\":" << state.connection_fallback_materialization_record_count << ","
		<< "\"connection_fallback_materialization_commit_count\":" << state.connection_fallback_materialization_commit_count << ","
		<< "\"connection_fallback_materialization_blocked_count\":" << state.connection_fallback_materialization_blocked_count << ","
		<< "\"object_record_vector_append_count_0x4a54a7\":" << state.object_record_vector_append_count_0x4a54a7 << ","
		<< "\"generated_cell_object_reference_append_count_0x4a54a7\":" << state.generated_cell_object_reference_append_count_0x4a54a7 << ","
		<< "\"descriptor_counter_increment_count_0x4a54a7\":" << state.descriptor_counter_increment_count_0x4a54a7 << ","
		<< "\"relation_descriptor_counter_increment_count_0x4a54a7\":" << state.relation_descriptor_counter_increment_count_0x4a54a7 << ","
		<< "\"target_cell_word_mutation_count_0x4a54a7\":" << state.target_cell_word_mutation_count_0x4a54a7 << ","
		<< "\"projection_score_depletion_count_0x4a54a7\":" << state.projection_score_depletion_count_0x4a54a7 << ","
		<< "\"object_records_0xec4_ecc\":";
	append_object_record_references_4a54a7_json(out, state.object_records_0xec4_ecc);
	out << ","
		<< "\"relation_owner_records_10e4_10e8_partial_known\":" << (state.relation_owner_records_10e4_10e8_partial_known ? "true" : "false") << ","
		<< "\"relation_owner_vector_count_10e4_10e8\":" << state.relation_owner_vector_count_10e4_10e8 << ","
		<< "\"relation_record_count_10e4_10e8\":" << state.relation_record_count_10e4_10e8 << ","
		<< "\"relation_record_missing_endpoint_count_10e4_10e8\":" << state.relation_record_missing_endpoint_count_10e4_10e8 << ","
		<< "\"relation_record_source\":\"0x49b452_constructs_relation_owner_source_pointer_town_choice_default_scan_bounds_local_vectors_then_0x4a1f3b_materializes_non_sentinel_scan_bounds_and_0x4a218c_clones_selected_relation_owners_and_0x49f7c4_appends_reciprocal_7_dword_relation_records_guard_wide_border_guard_fields\","
		<< "\"relation_owner_vectors_10e4_10e8\":";
	append_generator_relation_owner_vectors_json(out, state.relation_owner_vectors_10e4_10e8);
	out << ","
		<< "\"relation_owner_scan_bounds_0x4a1f3b_applied\":" << (state.relation_owner_scan_bounds_0x4a1f3b_applied ? "true" : "false") << ","
		<< "\"relation_owner_scan_bounds_known_count_0x4a1f3b\":" << state.relation_owner_scan_bounds_known_count_0x4a1f3b << ","
		<< "\"relation_owner_scan_bounds_blocked_count_0x4a1f3b\":" << state.relation_owner_scan_bounds_blocked_count_0x4a1f3b << ","
		<< "\"relation_owner_scan_bounds_source\":\"0x4a1f3b_relation_owner_scan_bounds_from_generated_cell_owner_byte_rectangles_after_0x4a2777_0x4a325d_owner_grid_and_0x4a5767_reset\","
		<< "\"relation_normalization_4a5767_full_grid_reset_applied\":" << (state.relation_normalization_4a5767_full_grid_reset_applied ? "true" : "false") << ","
		<< "\"relation_normalization_4a5767_full_grid_reset_visited_count\":" << state.relation_normalization_4a5767_full_grid_reset_visited_count << ","
		<< "\"relation_normalization_4a5767_full_grid_reset_changed_count\":" << state.relation_normalization_4a5767_full_grid_reset_changed_count << ","
		<< "\"relation_normalization_4a5767_full_grid_reset_skipped_count\":" << state.relation_normalization_4a5767_full_grid_reset_skipped_count << ","
		<< "\"relation_normalization_4a5767_source\":\"0x4a5767_full_grid_generated_cell_projection_reset_applied_before_relation_scan_0x49a318_replay\","
		<< "\"relation_scan_consumers_4a5767_applied\":" << (state.relation_scan_consumers_4a5767_applied ? "true" : "false") << ","
		<< "\"relation_scan_consumers_4a5767_no_object_projection_chain_complete\":" << (state.relation_scan_consumers_4a5767_no_object_projection_chain_complete ? "true" : "false") << ","
		<< "\"relation_scan_consumer_owner_scan_count_4a5767\":" << state.relation_scan_consumer_owner_scan_count_4a5767 << ","
		<< "\"relation_scan_consumer_owner_bounds_blocked_count_4a5767\":" << state.relation_scan_consumer_owner_bounds_blocked_count_4a5767 << ","
		<< "\"relation_scan_consumer_scanned_cell_count_4a5767\":" << state.relation_scan_consumer_scanned_cell_count_4a5767 << ","
		<< "\"relation_scan_consumer_object_branch_blocked_count_4a5767\":" << state.relation_scan_consumer_object_branch_blocked_count_4a5767 << ","
		<< "\"relation_scan_consumer_projected_chain_call_count_4a5767\":" << state.relation_scan_consumer_projected_chain_call_count_4a5767 << ","
		<< "\"relation_scan_consumer_projected_chain_occupied_stamp_count_4a5767\":" << state.relation_scan_consumer_projected_chain_occupied_stamp_count_4a5767 << ","
		<< "\"relation_scan_consumer_projected_chain_cleanup_clear_count_4a5767\":" << state.relation_scan_consumer_projected_chain_cleanup_clear_count_4a5767 << ","
		<< "\"relation_scan_consumer_object_branch_attempt_count_4a5767\":" << state.relation_scan_consumer_object_branch_attempt_count_4a5767 << ","
		<< "\"relation_scan_consumer_object_branch_commit_count_4a5767\":" << state.relation_scan_consumer_object_branch_commit_count_4a5767 << ","
		<< "\"relation_scan_consumers_4a5767_source\":\"source_backed_scan_consumer_over_0x4a1f3b_relation_scan_bounds_with_0x4a5a23_no_object_and_object_branch_materialization\","
		<< "\"relation_high_owner_propagation_49a318_applied\":" << (state.relation_high_owner_propagation_49a318_applied ? "true" : "false") << ","
		<< "\"relation_high_owner_propagation_49a318_grid_available\":" << (state.relation_high_owner_propagation_49a318_grid_available ? "true" : "false") << ","
		<< "\"relation_high_owner_propagation_49a318_object_metadata_gate_complete\":" << (state.relation_high_owner_propagation_49a318_object_metadata_gate_complete ? "true" : "false") << ","
		<< "\"relation_high_owner_seed_attempt_count_49a318\":" << state.relation_high_owner_seed_attempt_count_49a318 << ","
		<< "\"relation_high_owner_seed_blocked_count_49a318\":" << state.relation_high_owner_seed_blocked_count_49a318 << ","
		<< "\"relation_high_owner_popped_cell_count_49a318\":" << state.relation_high_owner_popped_cell_count_49a318 << ","
		<< "\"relation_high_owner_same_owner_relax_count_49a318\":" << state.relation_high_owner_same_owner_relax_count_49a318 << ","
		<< "\"relation_high_owner_cross_owner_high_byte_write_count_49a318\":" << state.relation_high_owner_cross_owner_high_byte_write_count_49a318 << ","
		<< "\"relation_high_owner_max_queue_size_49a318\":" << state.relation_high_owner_max_queue_size_49a318 << ","
		<< "\"relation_high_owner_materialized_count_49a318\":" << state.relation_high_owner_materialized_count_49a318 << ","
		<< "\"relation_high_owner_sentinel_count_49a318\":" << state.relation_high_owner_sentinel_count_49a318 << ","
		<< "\"relation_high_owner_propagation_49a318_source\":\"source_backed_0x49a318_relation_owner_coordinate_seed_flood_writes_source_projection_clear_same_owner_projection_0x10_0x14_0x18_word_0x1c_low_cross_owner_word_0x1c_high_word_0x28_direction_word_0x20_owner_high_byte_and_0x598300_bit22_object_metadata_policy_after_0x4a5767_reset\","
		<< "\"vectors\":[";
	append_generator_object_vector_state_json(out, state.endpoint_vector_c8_cc);
	out << ",";
	append_generator_object_vector_state_json(out, state.endpoint_vector_d8_dc);
	out << ",";
	append_generator_object_vector_state_json(out, state.object_record_vector_ec4_ecc);
	out << ",";
	append_generator_object_vector_state_json(out, state.source_pair_vector_edc);
	out << ",";
	append_generator_object_vector_state_json(out, state.pending_entry_vector_eec_ef0_ef4);
	out << ",";
	append_generator_object_vector_state_json(out, state.candidate_container_vector_10d4_10d8);
	out << ",";
	append_generator_object_vector_state_json(out, state.relation_vector_10e4_10e8);
	out << ",";
	append_generator_object_vector_state_json(out, state.endpoint_byte_state_vector_1104_1108);
	out << "],\"remaining_private_state_blockers\":";
	append_json_string_array(out, state.remaining_private_state_blockers);
	out << "}";
}

std::vector<std::string> shared_runtime_chain_missing_reasons(const ControlledCase &controlled_case, const SharedRuntimeChainInput &input) {
	std::vector<std::string> missing;
	if (!controlled_case.parse_ok) {
		missing.push_back("valid_controlled_case");
		return missing;
	}
	if (!supported_one_level_land_scope(controlled_case)) {
		missing.push_back("supported_small_medium_one_level_land_scope");
	}
	if (!input.rng_state_after_template_selection_known) {
		missing.push_back("rng_state_after_template_selection");
	}
	if (!input.recovered_setup_mode_known && (!input.rng_state_after_template_selection_known || input.runtime_zone_seeds.empty())) {
		missing.push_back("rmg_setup_object_0x44_before_0x49ecf2_template_selection");
	}
	if (!input.generator_mode_0x10b8_known) {
		missing.push_back("generator_mode_0x10b8");
	}
	if (input.runtime_zone_seeds.empty()) {
		missing.push_back("runtime_zone_seed_inputs");
	}
	if (input.runtime_zone_seeds.size() > 1 && input.runtime_links.empty()) {
		missing.push_back("runtime_link_inputs");
	}
	return missing;
}

std::vector<h3maped_rmg_core::RuntimeZoneSeedInput4a218c> to_h3maped_runtime_zone_seeds(const std::vector<SharedRuntimeZoneSeedInput> &inputs) {
	std::vector<h3maped_rmg_core::RuntimeZoneSeedInput4a218c> out;
	out.reserve(inputs.size());
	for (const SharedRuntimeZoneSeedInput &input : inputs) {
		h3maped_rmg_core::RuntimeZoneSeedInput4a218c zone;
		zone.runtime_zone_index = input.runtime_zone_index;
		zone.source_zone_id = input.source_zone_id;
		zone.source_index = input.source_index;
		zone.h3maped_zone_word_id = input.h3maped_zone_word_id;
		zone.source_bucket = input.source_bucket;
		zone.source_owner_index = input.source_owner_index;
		zone.actual_player_color = input.actual_player_color;
		zone.source_base_size = input.source_base_size;
		zone.allowed_town_mask_0x41_0x49 = input.allowed_town_mask_0x41_0x49;
		zone.selected_town_choice_index_0x49b3c1 = input.selected_town_choice_index_0x49b3c1;
		zone.terrain_match_to_town_0x84 = input.terrain_match_to_town_0x84;
		zone.allowed_terrain_mask_0x85_0x8c = input.allowed_terrain_mask_0x85_0x8c;
		zone.source_payload = to_h3maped_source_zone_payload(input.source_payload);
		out.push_back(zone);
	}
	return out;
}

std::vector<h3maped_rmg_core::RuntimeLinkSeedInput4a218c> to_h3maped_runtime_links(const std::vector<SharedRuntimeLinkInput> &inputs) {
	std::vector<h3maped_rmg_core::RuntimeLinkSeedInput4a218c> out;
	out.reserve(inputs.size());
	for (const SharedRuntimeLinkInput &input : inputs) {
		out.push_back(h3maped_rmg_core::RuntimeLinkSeedInput4a218c {
			input.from_index,
			input.to_index,
			input.guard_value,
			input.wide,
			input.border_guard,
			input.source_zone_a,
			input.source_zone_b,
			input.source_endpoint_a,
			input.source_endpoint_b,
		});
	}
	return out;
}

std::vector<SharedRuntimeZoneSeedInput> from_h3maped_runtime_zone_seeds(const std::vector<h3maped_rmg_core::RuntimeZoneSeedInput4a218c> &inputs) {
	std::vector<SharedRuntimeZoneSeedInput> out;
	out.reserve(inputs.size());
	for (const h3maped_rmg_core::RuntimeZoneSeedInput4a218c &input : inputs) {
		SharedRuntimeZoneSeedInput zone;
		zone.runtime_zone_index = input.runtime_zone_index;
		zone.source_zone_id = input.source_zone_id;
		zone.source_index = input.source_index;
		zone.h3maped_zone_word_id = input.h3maped_zone_word_id;
		zone.source_bucket = input.source_bucket;
		zone.source_owner_index = input.source_owner_index;
		zone.actual_player_color = input.actual_player_color;
		zone.source_base_size = input.source_base_size;
		zone.allowed_town_mask_0x41_0x49 = input.allowed_town_mask_0x41_0x49;
		zone.selected_town_choice_index_0x49b3c1 = input.selected_town_choice_index_0x49b3c1;
		zone.terrain_match_to_town_0x84 = input.terrain_match_to_town_0x84;
		zone.allowed_terrain_mask_0x85_0x8c = input.allowed_terrain_mask_0x85_0x8c;
		zone.source_payload = from_h3maped_source_zone_payload(input.source_payload);
		out.push_back(zone);
	}
	return out;
}

std::vector<SharedRuntimeLinkInput> from_h3maped_runtime_links(const std::vector<h3maped_rmg_core::RuntimeLinkSeedInput4a218c> &inputs) {
	std::vector<SharedRuntimeLinkInput> out;
	out.reserve(inputs.size());
	for (const h3maped_rmg_core::RuntimeLinkSeedInput4a218c &input : inputs) {
		out.push_back(SharedRuntimeLinkInput {
			input.from_index,
			input.to_index,
			input.guard_value,
			input.wide,
			input.border_guard,
			input.source_zone_a,
			input.source_zone_b,
			input.source_endpoint_a,
			input.source_endpoint_b,
		});
	}
	return out;
}

void append_partial_generated_cell_word_surface_json(std::ostream &out, const RecoveredOwnerGridPayload &payload) {
	const int32_t cell_count = int32_t(payload.generated_cell_word_0x20.size());
	out << "    \"partial_generated_cell_word_surface\": {\n";
	out << "      \"schema_id\": \"rmg_native_partial_generated_cell_word_surface_v1\",\n";
	out << "      \"checkpoint_id\": \"none_partial_owner_grid_terrainplacement_surface_not_pre_0x4a4c8e\",\n";
	out << "      \"status\": \"partial_support_state_not_comparable_pre_0x4a4c8e_checkpoint\",\n";
	out << "      \"h3maped_entry_anchor\": \"0x4a218c_to_0x4a1f3b_to_0x4a19ed_to_0x4a3a03_to_0x4cca55_to_0x4a2777_to_0x4a325d_to_0x4a3710_before_0x4a4c8e_consumers\",\n";
	out << "      \"width\": " << payload.width << ",\n";
	out << "      \"height\": " << payload.height << ",\n";
	out << "      \"level_count\": " << payload.level_count << ",\n";
	out << "      \"cell_count\": " << cell_count << ",\n";
	out << "      \"record_shape_0x30_present\": " << (payload.generated_cell_record_shape_0x30_present ? "true" : "false") << ",\n";
	out << "      \"record_stride_bytes\": " << payload.generated_cell_record_stride_bytes << ",\n";
	out << "      \"record_surface_status\": \"" << json_escape(payload.generated_cell_record_surface_status) << "\",\n";
	out << "      \"record_shape_source\": \"GeneratedCell_stride_0x30_from_h3maped_private_state_layout_0x49a072_0x499ea3_reset_record_shape_only\",\n";
	out << "      \"record_count\": " << payload.generated_cell_records_0x30.size() << ",\n";
	out << "      \"object_reference_vector_fields_0x04_0x08_present_count\": " << generated_cell_record_known_count(payload.generated_cell_records_0x30, &SharedGeneratedCellRecord0x30::object_reference_vector_fields_0x04_0x08_present) << ",\n";
	out << "      \"object_reference_vector_contents_known_count\": " << generated_cell_record_known_count(payload.generated_cell_records_0x30, &SharedGeneratedCellRecord0x30::object_reference_vector_contents_known) << ",\n";
	out << "      \"word_0x14_known_count\": " << generated_cell_record_known_count(payload.generated_cell_records_0x30, &SharedGeneratedCellRecord0x30::word_0x14_known) << ",\n";
	out << "      \"word_0x18_known_count\": " << generated_cell_record_known_count(payload.generated_cell_records_0x30, &SharedGeneratedCellRecord0x30::word_0x18_known) << ",\n";
	out << "      \"byte_0x2b_known_count\": " << generated_cell_record_known_count(payload.generated_cell_records_0x30, &SharedGeneratedCellRecord0x30::byte_0x2b_known) << ",\n";
	int32_t byte_0x2b_bit_0x02_known_count = 0;
	for (const SharedGeneratedCellRecord0x30 &record : payload.generated_cell_records_0x30) {
		if ((record.byte_0x2b_known_mask & 0x02U) != 0U) {
			byte_0x2b_bit_0x02_known_count += 1;
		}
	}
	out << "      \"byte_0x2b_bit_0x02_known_count\": " << byte_0x2b_bit_0x02_known_count << ",\n";
	out << "      \"word_0x14_0x18_source\": \"0x4a5767_full_grid_projection_reset_owned_before_relation_scan_0x49a318_and_0x4a606b_projection_consumers\",\n";
	out << "      \"byte_0x2b_source\": \"not_native_owned_until_validity_private_byte_mutations_0x49a1d8_0x49abd6_0x4a5a23_are_ported\",\n";
	out << "      \"word_0x10_0x1c_partial_source\": \"generated_cell_grid_reset_0x49a072_0x499ea3_plus_0x4a5767_full_grid_projection_reset_before_relation_scan_not_pre_0x4a4c8e_checkpoint\",\n";
	out << "      \"word_0x20_source\": \"shared_recovered_owner_grid_materialization_plus_0x4a5767_byte3_projection_reset_plus_source_backed_0x49a318_owner_high_byte_propagation_when_relation_seeds_are_available\",\n";
	out << "      \"word_0x24_0x28_source\": \"0x49b3c1_0x49b53d_0x4a3f27_terrain_repaint_0x4bb74b_0x4bad0f_0x4bcfc3_0x4bce6d_visual_rows_plus_0x4a5767_direction_bits_reset\",\n";
	out << "      \"word_0x2c_partial_source\": \"generated_cell_grid_reset_0x49a072_0x499ea3_before_downstream_consumers_not_pre_0x4a4c8e_checkpoint\",\n";
	out << "      \"word_0x10_hash_fnv1a64\": " << fnv1a64_words(payload.generated_cell_word_0x10) << ",\n";
	out << "      \"word_0x1c_hash_fnv1a64\": " << fnv1a64_words(payload.generated_cell_word_0x1c) << ",\n";
	out << "      \"word_0x20_hash_fnv1a64\": " << fnv1a64_words(payload.generated_cell_word_0x20) << ",\n";
	out << "      \"word_0x24_hash_fnv1a64\": " << fnv1a64_words(payload.generated_cell_word_0x24) << ",\n";
	out << "      \"word_0x28_hash_fnv1a64\": " << fnv1a64_words(payload.generated_cell_word_0x28) << ",\n";
	out << "      \"records\": [";
	for (int32_t flat = 0; flat < cell_count; ++flat) {
		if (flat != 0) {
			out << ", ";
		}
		const uint32_t word_0x10 = flat < int32_t(payload.generated_cell_word_0x10.size()) ? payload.generated_cell_word_0x10[size_t(flat)] : 0U;
		const uint32_t word_0x1c = flat < int32_t(payload.generated_cell_word_0x1c.size()) ? payload.generated_cell_word_0x1c[size_t(flat)] : 0U;
		const uint32_t word_0x20 = payload.generated_cell_word_0x20[size_t(flat)];
		const uint32_t word_0x24 = flat < int32_t(payload.generated_cell_word_0x24.size()) ? payload.generated_cell_word_0x24[size_t(flat)] : 0U;
		const uint32_t word_0x28 = flat < int32_t(payload.generated_cell_word_0x28.size()) ? payload.generated_cell_word_0x28[size_t(flat)] : 0U;
		const uint32_t word_0x2c = flat < int32_t(payload.generated_cell_word_0x2c.size()) ? payload.generated_cell_word_0x2c[size_t(flat)] : 0U;
		const SharedGeneratedCellRecord0x30 *record = flat < int32_t(payload.generated_cell_records_0x30.size()) ? &payload.generated_cell_records_0x30[size_t(flat)] : nullptr;
		const int32_t level_size = std::max<int32_t>(1, payload.width * payload.height);
		const int32_t level = flat / level_size;
		const int32_t remainder = flat % level_size;
		const int32_t x = payload.width > 0 ? remainder % payload.width : -1;
		const int32_t y = payload.width > 0 ? remainder / payload.width : -1;
		out << "{";
		out << "\"flat\":" << flat << ",";
		out << "\"x\":" << x << ",";
		out << "\"y\":" << y << ",";
		out << "\"level\":" << level << ",";
		out << "\"stride_bytes\":" << (record != nullptr ? record->stride_bytes : payload.generated_cell_record_stride_bytes) << ",";
		out << "\"object_reference_vector_fields_0x04_0x08_present\":" << (record != nullptr && record->object_reference_vector_fields_0x04_0x08_present ? "true" : "false") << ",";
		out << "\"object_reference_vector_contents_known\":" << (record != nullptr && record->object_reference_vector_contents_known ? "true" : "false") << ",";
		out << "\"object_reference_count\":" << (record != nullptr ? record->object_reference_count : 0) << ",";
		out << "\"object_references_0x04_0x08\":";
		if (record != nullptr) {
			append_json_u32_array(out, record->object_references_0x04_0x08);
		} else {
			out << "[]";
		}
		out << ",";
		out << "\"word_0x10_known\":" << (record != nullptr && record->word_0x10_known ? "true" : "false") << ",";
		out << "\"word_0x10\":" << word_0x10 << ",";
		out << "\"word_0x14_known\":" << (record != nullptr && record->word_0x14_known ? "true" : "false") << ",";
		out << "\"word_0x14\":" << (record != nullptr ? record->word_0x14 : 0U) << ",";
		out << "\"word_0x18_known\":" << (record != nullptr && record->word_0x18_known ? "true" : "false") << ",";
		out << "\"word_0x18\":" << (record != nullptr ? record->word_0x18 : 0U) << ",";
		out << "\"word_0x1c_known\":" << (record != nullptr && record->word_0x1c_known ? "true" : "false") << ",";
		out << "\"word_0x1c\":" << word_0x1c << ",";
		out << "\"word_0x20_known\":" << (record != nullptr && record->word_0x20_known ? "true" : "false") << ",";
		out << "\"word_0x20\":" << word_0x20 << ",";
		out << "\"word_0x24_known\":" << (record != nullptr && record->word_0x24_known ? "true" : "false") << ",";
		out << "\"word_0x24\":" << word_0x24 << ",";
		out << "\"word_0x28_known\":" << (record != nullptr && record->word_0x28_known ? "true" : "false") << ",";
		out << "\"word_0x28\":" << word_0x28 << ",";
		out << "\"byte_0x2b_known\":" << (record != nullptr && record->byte_0x2b_known ? "true" : "false") << ",";
		out << "\"byte_0x2b_known_mask\":" << (record != nullptr ? int32_t(record->byte_0x2b_known_mask) : 0) << ",";
		out << "\"byte_0x2b\":" << (record != nullptr ? int32_t(record->byte_0x2b) : 0) << ",";
		out << "\"word_0x2c_known\":" << (record != nullptr && record->word_0x2c_known ? "true" : "false") << ",";
		out << "\"word_0x2c\":" << word_0x2c << ",";
		out << "\"owner_byte2_signed\":" << signed_byte(word_0x20 >> 16U) << ",";
		out << "\"owner_byte3_signed\":" << signed_byte(word_0x20 >> 24U) << ",";
		out << "\"terrain_code\":" << int32_t(word_0x24 & 0x3fU);
		out << "}";
	}
	out << "]\n";
	out << "    }";
}

void append_shared_chain_json(std::ostream &out, const ControlledCase &controlled_case, int32_t width, const SharedRuntimeChainInput &raw_input) {
	const RecoveredOwnerGridPayload payload = build_recovered_owner_grid_payload(controlled_case, raw_input);
	const SharedRuntimeChainInput &input = payload.input;
	const std::vector<std::string> &missing = payload.missing_inputs;
	const bool executable = payload.executable;
	const std::string input_source = input.input_source.empty() ? "explicit_cli_runtime_inputs" : input.input_source;
	out << "  \"shared_coordinate_owner_grid_chain\": {\n";
	out << "    \"input_source\": \"" << json_escape(input_source) << "\",\n";
	out << "    \"input_status\": \"" << (executable ? "shared_inputs_ready" : "missing_exact_runtime_zone_seed_link_inputs") << "\",\n";
	out << "    \"missing_inputs\": ";
	append_json_string_array(out, missing);
	out << ",\n";
	out << "    \"same_run_recovered_template_catalog_selection_known\": " << (input.recovered_template_selection_known ? "true" : "false") << ",\n";
	out << "    \"same_run_recovered_template_catalog_selection_blocked\": " << (input.recovered_template_selection_blocked ? "true" : "false") << ",\n";
	out << "    \"same_run_recovered_setup_mode_known\": " << (input.recovered_setup_mode_known ? "true" : "false") << ",\n";
	out << "    \"same_run_recovered_setup_object_0x44\": " << input.recovered_setup_object_0x44 << ",\n";
	out << "    \"same_run_recovered_setup_randomized_sentinel_3\": " << (input.recovered_setup_mode_randomized_sentinel_3 ? "true" : "false") << ",\n";
	out << "    \"same_run_recovered_setup_rng_value\": " << input.recovered_setup_rng_value << ",\n";
	out << "    \"same_run_recovered_setup_rng_call_count\": " << input.recovered_setup_rng_call_count << ",\n";
	out << "    \"same_run_recovered_setup_rng_state_before\": " << input.recovered_setup_rng_state_before << ",\n";
	out << "    \"same_run_recovered_template_rng_state_before\": " << input.recovered_template_rng_state_before << ",\n";
	out << "    \"same_run_recovered_generator_mode_0x10b8\": " << input.recovered_generator_mode_0x10b8 << ",\n";
	out << "    \"same_run_recovered_template_size_score\": " << input.recovered_template_size_score << ",\n";
	out << "    \"same_run_recovered_template_accepted_count\": " << input.recovered_template_accepted_count << ",\n";
	out << "    \"same_run_recovered_template_selected_vector_index\": " << input.recovered_template_selected_vector_index << ",\n";
	out << "    \"same_run_recovered_template_source_catalog_index\": " << input.recovered_template_source_catalog_index << ",\n";
	out << "    \"same_run_recovered_template_name\": \"" << json_escape(input.recovered_template_name) << "\",\n";
	out << "    \"same_run_recovered_candidate_container_source\": \"0x49f0cd_generator_0x10d4_0x10d8_consumed_by_0x4ac552\",\n";
	out << "    \"same_run_recovered_candidate_container_count\": " << input.recovered_candidate_containers_10d4_10d8.size() << ",\n";
	out << "    \"same_run_recovered_candidate_containers_10d4_10d8\": ";
	append_template_candidate_container_records_json(out, input.recovered_candidate_containers_10d4_10d8);
	out << ",\n";
	out << "    \"same_run_recovered_selected_candidate_container\": ";
	if (input.recovered_template_selected_vector_index >= 0
			&& input.recovered_template_selected_vector_index < int32_t(input.recovered_candidate_containers_10d4_10d8.size())) {
		append_template_candidate_container_record_json(out, input.recovered_candidate_containers_10d4_10d8[size_t(input.recovered_template_selected_vector_index)]);
	} else {
		out << "null";
	}
	out << ",\n";
	out << "    \"same_run_recovered_template_rng_value\": " << input.recovered_template_rng_value << ",\n";
	out << "    \"same_run_recovered_template_source_zone_record_count\": " << input.recovered_template_source_zone_record_count << ",\n";
	out << "    \"same_run_recovered_template_source_link_record_count\": " << input.recovered_template_source_link_record_count << ",\n";
	out << "    \"same_run_recovered_template_player_assignment_complete\": " << (input.recovered_template_player_assignment_complete ? "true" : "false") << ",\n";
	out << "    \"same_run_recovered_player_slot_assignment_known\": " << (input.recovered_player_slot_assignment_known ? "true" : "false") << ",\n";
	out << "    \"same_run_recovered_player_slot_assignment_source\": \"0x4ac62a_0x4ac6ec_generator_ed8_ee0_ee4\",\n";
	out << "    \"same_run_recovered_player_slot_requested_human_count\": " << input.recovered_player_slot_requested_human_count << ",\n";
	out << "    \"same_run_recovered_player_slot_requested_player_count\": " << input.recovered_player_slot_requested_player_count << ",\n";
	out << "    \"same_run_recovered_player_slot_assigned_player_count\": " << input.recovered_player_slot_assigned_player_count << ",\n";
	out << "    \"same_run_recovered_selected_color_order_ed8\": ";
	append_json_i32_array(out, input.recovered_selected_color_order_ed8);
	out << ",\n";
	out << "    \"same_run_recovered_raw_source_owner_slots_ee0\": ";
	append_json_i32_array(out, input.recovered_raw_source_owner_slots_ee0);
	out << ",\n";
	out << "    \"same_run_recovered_mapped_source_owner_slots_ee4\": ";
	append_json_i32_array(out, input.recovered_mapped_source_owner_slots_ee4);
	out << ",\n";
	out << "    \"same_run_recovered_player_slot_assignments\": ";
	append_player_slot_assignment_records_json(out, input.recovered_player_slot_assignments);
	out << ",\n";
	out << "    \"same_run_recovered_template_runtime_zone_seed_count\": " << input.recovered_template_runtime_zone_seed_count << ",\n";
	out << "    \"same_run_recovered_template_runtime_link_count\": " << input.recovered_template_runtime_link_count << ",\n";
	out << "    \"same_run_recovered_template_skipped_zone_filter_count\": " << input.recovered_template_skipped_zone_filter_count << ",\n";
	out << "    \"same_run_recovered_template_skipped_link_filter_count\": " << input.recovered_template_skipped_link_filter_count << ",\n";
	out << "    \"same_run_recovered_template_missing_link_endpoint_count\": " << input.recovered_template_missing_link_endpoint_count << ",\n";
	out << "    \"rng_state_after_template_selection_known\": " << (input.rng_state_after_template_selection_known ? "true" : "false") << ",\n";
	out << "    \"rng_state_after_template_selection\": " << input.rng_state_after_template_selection << ",\n";
	out << "    \"rmg_setup_object_0x44_known\": " << (controlled_case.setup_object_0x44_known ? "true" : "false") << ",\n";
	out << "    \"rmg_setup_object_0x44_supplied_by_controlled_case\": " << (controlled_case.setup_object_0x44_supplied ? "true" : "false") << ",\n";
	out << "    \"rmg_setup_object_0x44\": " << controlled_case.setup_object_0x44 << ",\n";
	const std::string generator_mode_source = !input.generator_mode_0x10b8_known
			? "missing_same_run_rmg_setup_object_0x44_or_explicit_cli"
			: (input.recovered_setup_mode_randomized_sentinel_3
							? "0x49ecf2_arg8_setup_object_0x44_sentinel_3_randomized_with_0x4e7276_mod_3"
							: (input.recovered_setup_mode_known
											? "0x49ecf2_arg8_from_rmg_setup_object_0x44"
											: "explicit_cli_shared_generator_mode_0x10b8"));
	out << "    \"generator_mode_0x10b8_source\": \"" << generator_mode_source << "\",\n";
	out << "    \"generator_mode_0x10b8_known\": " << (input.generator_mode_0x10b8_known ? "true" : "false") << ",\n";
	out << "    \"generator_mode_0x10b8\": " << input.generator_mode_0x10b8 << ",\n";
	out << "    \"runtime_zone_seed_count\": " << input.runtime_zone_seeds.size() << ",\n";
	out << "    \"same_run_recovered_source_zone_payload_source\": \"selected_h3maped_template_catalog_zone_semantics_from_0x4ac552_feed\",\n";
	out << "    \"same_run_recovered_source_zone_payload_count\": " << input.runtime_zone_seeds.size() << ",\n";
	out << "    \"same_run_recovered_source_zone_payloads\": ";
	append_runtime_zone_source_payload_records_json(out, input.runtime_zone_seeds);
	out << ",\n";
	out << "    \"source_object_record_catalog_0x49da08\": ";
	append_source_object_record_catalog_json(out, payload);
	out << ",\n";
	out << "    \"generator_object_private_state\": ";
	append_generator_object_private_state_json(out, payload.generator_object_private_state);
	out << ",\n";
	int64_t runtime_link_guard_value_sum = 0;
	int32_t runtime_link_wide_count = 0;
	int32_t runtime_link_border_guard_count = 0;
	for (const SharedRuntimeLinkInput &link : input.runtime_links) {
		runtime_link_guard_value_sum += link.guard_value;
		if (link.wide) {
			runtime_link_wide_count += 1;
		}
		if (link.border_guard) {
			runtime_link_border_guard_count += 1;
		}
	}
	out << "    \"runtime_link_count\": " << input.runtime_links.size() << ",\n";
	out << "    \"runtime_link_guard_value_sum\": " << runtime_link_guard_value_sum << ",\n";
	out << "    \"runtime_link_wide_count\": " << runtime_link_wide_count << ",\n";
	out << "    \"runtime_link_border_guard_count\": " << runtime_link_border_guard_count << ",\n";
	out << "    \"executed\": " << (executable ? "true" : "false");
	if (executable) {
		out << ",\n";
		out << "    \"coordinate_seed_blocked\": " << (payload.coordinate_seed_blocked ? "true" : "false") << ",\n";
		out << "    \"coordinate_generator_mode_0x10b8\": " << payload.coordinate_generator_mode_0x10b8 << ",\n";
		out << "    \"coordinate_minimum_source_base_size\": " << payload.coordinate_minimum_source_base_size << ",\n";
		out << "    \"coordinate_prune_divisor_4a218c\": " << payload.coordinate_prune_divisor_4a218c << ",\n";
		out << "    \"coordinate_prune_span_budget_4a218c\": " << payload.coordinate_prune_span_budget_4a218c << ",\n";
			out << "    \"coordinate_rng_state_before\": " << payload.coordinate_rng_state_before << ",\n";
			out << "    \"coordinate_rng_state_after\": " << payload.coordinate_rng_state_after << ",\n";
			out << "    \"coordinate_rng_call_count\": " << payload.coordinate_rng_call_count << ",\n";
			out << "    \"coordinate_placement_step_count\": " << payload.coordinate_placement_step_count << ",\n";
		out << "    \"coordinate_boundary_input_count\": " << payload.coordinate_boundary_input_count << ",\n";
		out << "    \"owner_grid_executed\": " << (payload.owner_grid_executed ? "true" : "false") << ",\n";
		out << "    \"source_blocked\": " << (payload.source_blocked ? "true" : "false") << ",\n";
		out << "    \"source_descriptor_node_count\": " << payload.source_descriptor_node_count << ",\n";
		out << "    \"source_descriptor_active_node_count\": " << payload.source_descriptor_active_node_count << ",\n";
		out << "    \"source_node_walk_count\": " << payload.source_node_walk_count << ",\n";
		out << "    \"source_handoff_count\": " << payload.source_handoff_count << ",\n";
			out << "    \"missing_boundary_input_count\": " << payload.missing_boundary_input_count << ",\n";
			out << "    \"missing_source_walk_count\": " << payload.missing_source_walk_count << ",\n";
			out << "    \"materialization_source_handoff_count\": " << payload.materialization_source_handoff_count << ",\n";
			out << "    \"materialization_source_handoff_descriptor_indexed_point_count\": " << payload.materialization_source_handoff_descriptor_indexed_point_count << ",\n";
			out << "    \"materialization_source_handoff_raw_coordinate_point_count\": " << payload.materialization_source_handoff_raw_coordinate_point_count << ",\n";
			out << "    \"materialization_source_record_seed_count\": " << payload.materialization_source_record_seed_count << ",\n";
			out << "    \"materialization_missing_source_record_seed_count\": " << payload.materialization_missing_source_record_seed_count << ",\n";
		out << "    \"materialization_runtime_zone_walk_count\": " << payload.materialization_runtime_zone_walk_count << ",\n";
		out << "    \"materialization_appended_vertex_count\": " << payload.materialization_appended_vertex_count << ",\n";
		out << "    \"materialization_span_fill_zone_count\": " << payload.materialization_span_fill_zone_count << ",\n";
		out << "    \"footprint_finalizer_4a3710_executed\": " << (payload.footprint_finalizer_executed ? "true" : "false") << ",\n";
		out << "    \"footprint_finalizer_4a3710_blocked\": " << (payload.footprint_finalizer_blocked ? "true" : "false") << ",\n";
		out << "    \"footprint_finalizer_4a3710_status\": \"" << json_escape(payload.footprint_finalizer_status) << "\",\n";
		out << "    \"footprint_finalizer_4a3710_original_same_level_runtime_zone_count\": " << payload.footprint_finalizer_original_same_level_runtime_zone_count << ",\n";
		out << "    \"footprint_finalizer_4a3710_final_runtime_zone_count\": " << payload.footprint_finalizer_final_runtime_zone_count << ",\n";
		out << "    \"footprint_finalizer_4a3710_appended_runtime_zone_count\": " << payload.footprint_finalizer_appended_runtime_zone_count << ",\n";
		out << "    \"footprint_finalizer_4a3710_zone_order_reset_call_count\": " << payload.footprint_finalizer_zone_order_reset_call_count << ",\n";
		out << "    \"footprint_finalizer_4a3710_per_zone_order_helper_call_count\": " << payload.footprint_finalizer_per_zone_order_helper_call_count << ",\n";
		out << "    \"materialization_generated_cell_word_0x20_count\": " << payload.generated_cell_word_0x20.size() << ",\n";
		out << "    \"town_choice_rng_call_count_0x49b3c1\": " << payload.town_choice_rng_call_count_0x49b3c1 << ",\n";
		out << "    \"terrain_selection_rng_call_count_0x49b53d\": " << payload.terrain_selection_rng_call_count_0x49b53d << ",\n";
		out << "    \"terrain_selection_match_to_town_count\": " << payload.terrain_selection_match_to_town_count << ",\n";
		out << "    \"terrain_selection_allowed_flag_choice_count\": " << payload.terrain_selection_allowed_flag_choice_count << ",\n";
		out << "    \"terrain_selection_no_eligible_default_zero_count\": " << payload.terrain_selection_no_eligible_default_zero_count << ",\n";
		out << "    \"terrain_repaint_write_count_0x4a4163\": " << payload.terrain_repaint_write_count_0x4a4163 << ",\n";
		out << "    \"terrain_visual_write_count_0x4bb74b\": " << payload.terrain_visual_write_count_0x4bb74b << ",\n";
		out << "    \"terrain_visual_missing_bucket_count_0x4bcfc3\": " << payload.terrain_visual_missing_bucket_count_0x4bcfc3 << ",\n";
		out << "    \"terrain_visual_missing_bucket_samples_0x4bcfc3\": ";
		append_terrain_visual_missing_bucket_samples_json(out, payload.terrain_visual_missing_bucket_samples_0x4bcfc3);
		out << ",\n";
		out << "    \"terrain_visual_art_nonzero_cell_count\": " << payload.terrain_visual_art_nonzero_cell_count << ",\n";
		out << "    \"terrain_visual_flag_cell_count\": " << payload.terrain_visual_flag_cell_count << ",\n";
		out << "    \"terrain_visual_final_sweep_cell_count_0x4bbfcc\": " << payload.terrain_visual_final_sweep_cell_count_0x4bbfcc << ",\n";
		out << "    \"terrain_visual_preserved_current_record_count_0x4bc5a3\": " << payload.terrain_visual_preserved_current_record_count_0x4bc5a3 << ",\n";
		out << "    \"terrain_visual_roundtrip_mismatch_count\": " << payload.terrain_visual_roundtrip_mismatch_count << ",\n";
		out << "    \"terrain_visual_rng_state_after_0x4bb74b\": " << payload.terrain_visual_rng_state_after_0x4bb74b << ",\n";
		out << "    \"generated_cell_private_state_comparable\": " << (payload.generated_cell_private_state_comparable ? "true" : "false") << ",\n";
		out << "    \"generated_cell_private_state_status\": \"" << json_escape(payload.generated_cell_private_state_status) << "\",\n";
		out << "    \"missing_generated_cell_mutation_phases\": ";
		append_json_string_array(out, payload.missing_generated_cell_mutation_phases);
		out << ",\n";
		out << "    \"terrain_selection_repaint_status\": \"" << json_escape(payload.terrain_selection_repaint_status) << "\",\n";
		out << "    \"terrain_selection_parity_blockers\": ";
		append_json_string_array(out, payload.terrain_selection_parity_blockers);
		out << ",\n";
		out << "    \"terrain_repaint_parity_blockers\": ";
		append_json_string_array(out, payload.terrain_repaint_parity_blockers);
		if (payload.built) {
			out << ",\n";
			append_partial_generated_cell_word_surface_json(out, payload);
		}
	}
	out << "\n";
	out << "  }";
}

} // namespace

ControlledCase parse_controlled_case(const std::string &raw) {
	ControlledCase controlled_case;
	controlled_case.raw = raw;
	const std::vector<std::string> parts = split(raw, ':');
	if (parts.size() < 6) {
		controlled_case.parse_error = "expected id:size_class:players:seed:water_mode:level_count[:human_count[:computer_count[:setup_object_0x44]]]";
		return controlled_case;
	}

	controlled_case.id = parts[0];
	controlled_case.size_class = normalize_size_class(parts[1]);
	controlled_case.water_mode = normalize_water_mode(parts[4]);
	if (controlled_case.id.empty()) {
		controlled_case.parse_error = "missing case id";
		return controlled_case;
	}
	if (!parse_i32(parts[2], controlled_case.players) || controlled_case.players < 1) {
		controlled_case.parse_error = "invalid players";
		return controlled_case;
	}
	if (!parse_u32(parts[3], controlled_case.seed)) {
		controlled_case.parse_error = "invalid seed";
		return controlled_case;
	}
	if (!parse_i32(parts[5], controlled_case.level_count) || controlled_case.level_count < 1) {
		controlled_case.parse_error = "invalid level_count";
		return controlled_case;
	}

	controlled_case.human_count = 1;
	controlled_case.computer_count = std::max<int32_t>(0, controlled_case.players - 1);
	if (parts.size() >= 7 && !parts[6].empty() && !parse_i32(parts[6], controlled_case.human_count)) {
		controlled_case.parse_error = "invalid human_count";
		return controlled_case;
	}
	if (parts.size() >= 8 && !parts[7].empty() && !parse_i32(parts[7], controlled_case.computer_count)) {
		controlled_case.parse_error = "invalid computer_count";
		return controlled_case;
	}
	if (controlled_case.human_count < 0 || controlled_case.computer_count < 0) {
		controlled_case.parse_error = "invalid negative player split";
		return controlled_case;
	}
	if (parts.size() >= 9 && !parts[8].empty()) {
		controlled_case.setup_object_0x44_known = parse_i32(parts[8], controlled_case.setup_object_0x44);
		if (!controlled_case.setup_object_0x44_known) {
			controlled_case.parse_error = "invalid setup_object_0x44";
			return controlled_case;
		}
		controlled_case.setup_object_0x44_supplied = true;
	}

	controlled_case.parse_ok = true;
	return controlled_case;
}

std::vector<std::string> split_case_filter(const std::string &case_filter) {
	std::vector<std::string> filters;
	for (const std::string &part : split(case_filter, ',')) {
		if (!part.empty()) {
			filters.push_back(lower_ascii(part));
		}
	}
	return filters;
}

bool case_matches_filter(const ControlledCase &controlled_case, const std::vector<std::string> &filters) {
	if (filters.empty()) {
		return true;
	}
	const std::string id = lower_ascii(controlled_case.id);
	const std::string raw = lower_ascii(controlled_case.raw);
	for (const std::string &filter : filters) {
		if (id == filter || raw.find(filter) != std::string::npos) {
			return true;
		}
	}
	return false;
}

SharedRuntimeChainInput resolved_shared_runtime_chain_input(const ControlledCase &controlled_case, const SharedRuntimeChainInput &input) {
	SharedRuntimeChainInput resolved = input;
	if (!controlled_case.parse_ok || !supported_one_level_land_scope(controlled_case)) {
		return resolved;
	}

	const int32_t width = h3maped_rmg_core::map_width_for_size_class(controlled_case.size_class);
	const int32_t score = h3maped_rmg_core::size_score(
			width,
			width,
			controlled_case.level_count,
			h3maped_rmg_core::water_mode_code(controlled_case.water_mode));

	bool used_setup_object = false;
	uint32_t rng_state_before_template_selection = controlled_case.seed;
	if (controlled_case.setup_object_0x44_known) {
		const h3maped_rmg_core::GeneratorSetupModeResult49ecf2 setup =
				h3maped_rmg_core::generator_setup_mode_49ecf2(controlled_case.seed, controlled_case.setup_object_0x44);
		resolved.recovered_setup_mode_known = true;
		resolved.recovered_setup_object_0x44 = setup.setup_object_0x44;
		resolved.recovered_setup_mode_randomized_sentinel_3 = setup.randomized_setup_sentinel_3;
		resolved.recovered_setup_rng_value = setup.setup_rng_value;
		resolved.recovered_setup_rng_call_count = setup.setup_rng_call_count;
		resolved.recovered_setup_rng_state_before = setup.rng_state_before_setup;
		resolved.recovered_template_rng_state_before = setup.rng_state_before_template_selection;
		resolved.recovered_generator_mode_0x10b8 = setup.generator_mode_0x10b8;
		rng_state_before_template_selection = setup.rng_state_before_template_selection;
		if (!resolved.generator_mode_0x10b8_known) {
			resolved.generator_mode_0x10b8 = setup.generator_mode_0x10b8;
			resolved.generator_mode_0x10b8_known = true;
		}
		used_setup_object = true;
	}

	bool used_same_run_catalog = false;
	if (resolved.recovered_setup_mode_known) {
		const h3maped_rmg_core::TemplateSelectionRuntimeResult4ac552 selection =
				h3maped_rmg_core::template_selection_and_runtime_seed_inputs_4ac552_4a218c_4a1f3b(
						rng_state_before_template_selection,
						score,
						controlled_case.human_count,
						controlled_case.players);

		resolved.recovered_template_selection_known = true;
		resolved.recovered_template_selection_blocked = selection.blocked;
		resolved.recovered_template_size_score = selection.size_score;
		resolved.recovered_template_accepted_count = selection.accepted_template_count;
		resolved.recovered_template_selected_vector_index = selection.selected_vector_index;
		resolved.recovered_template_source_catalog_index = selection.selected_source_catalog_index;
		resolved.recovered_template_name = selection.selected_template_name;
		resolved.recovered_candidate_containers_10d4_10d8 = from_h3maped_candidate_containers(selection.accepted_candidate_containers_10d4_10d8);
		resolved.recovered_template_rng_value = selection.rng_value;
		resolved.recovered_template_source_zone_record_count = selection.source_zone_record_count;
		resolved.recovered_template_source_link_record_count = selection.source_link_record_count;
		resolved.recovered_template_player_assignment_complete = selection.player_assignment.complete;
		resolved.recovered_player_slot_assignment_known = true;
		resolved.recovered_player_slot_requested_human_count = selection.player_assignment.requested_human_count;
		resolved.recovered_player_slot_requested_player_count = selection.player_assignment.requested_player_count;
		resolved.recovered_player_slot_assigned_player_count = selection.player_assignment.assigned_player_count;
		resolved.recovered_selected_color_order_ed8 = selection.player_assignment.selected_color_order_ed8;
		resolved.recovered_raw_source_owner_slots_ee0 = selection.player_assignment.raw_ee0_slots;
		resolved.recovered_mapped_source_owner_slots_ee4 = selection.player_assignment.mapped_ee4_slots;
		resolved.recovered_player_slot_assignments = from_h3maped_player_slot_assignments(selection.player_assignment.assignments);
		resolved.recovered_template_runtime_zone_seed_count = int32_t(selection.runtime_seed.runtime_zone_seeds.size());
		resolved.recovered_template_runtime_link_count = int32_t(selection.runtime_seed.runtime_links.size());
		resolved.recovered_template_skipped_zone_filter_count = selection.runtime_seed.skipped_zone_filter_count;
		resolved.recovered_template_skipped_link_filter_count = selection.runtime_seed.skipped_link_filter_count;
		resolved.recovered_template_missing_link_endpoint_count = selection.runtime_seed.missing_link_endpoint_count;

		if (!selection.blocked) {
			if (!resolved.rng_state_after_template_selection_known) {
				resolved.rng_state_after_template_selection = selection.rng_state_after_template_selection;
				resolved.rng_state_after_template_selection_known = true;
				used_same_run_catalog = true;
			}
			if (resolved.runtime_zone_seeds.empty()) {
				resolved.runtime_zone_seeds = from_h3maped_runtime_zone_seeds(selection.runtime_seed.runtime_zone_seeds);
				used_same_run_catalog = true;
			}
			if (resolved.runtime_links.empty()) {
				resolved.runtime_links = from_h3maped_runtime_links(selection.runtime_seed.runtime_links);
				used_same_run_catalog = true;
			}
		}
	} else {
		resolved.recovered_template_selection_blocked = true;
		resolved.recovered_template_size_score = score;
	}

	if (resolved.input_source.empty()) {
		if (used_same_run_catalog && used_setup_object) {
			resolved.input_source = "same_run_recovered_h3maped_template_catalog_4ac552_plus_setup_object_0x44";
		} else if (used_same_run_catalog) {
			resolved.input_source = "same_run_recovered_h3maped_template_catalog_4ac552";
		} else if (used_setup_object) {
			resolved.input_source = "explicit_cli_runtime_inputs_plus_setup_object_0x44";
		}
	} else if (used_same_run_catalog || used_setup_object) {
		resolved.input_source += used_setup_object
				? "+same_run_recovered_h3maped_template_catalog_4ac552_or_setup_object_0x44"
				: "+same_run_recovered_h3maped_template_catalog_4ac552";
	}

	return resolved;
}

RecoveredOwnerGridPayload build_recovered_owner_grid_payload(const ControlledCase &controlled_case, const SharedRuntimeChainInput &input) {
	RecoveredOwnerGridPayload payload;
	payload.input = resolved_shared_runtime_chain_input(controlled_case, input);
	populate_source_object_catalog_0x49da08(payload);
	payload.generated_cell_private_state_comparable = false;
	payload.generated_cell_private_state_status = "partial_owner_grid_terrainplacement_surface_not_comparable_until_source_records_full_generated_cell_state_relation_object_endpoint_road_writeout_and_same_run_comparison_are_native_owned";
	payload.terrain_selection_repaint_status = "pending_execution";
	payload.missing_generated_cell_mutation_phases = generated_cell_mutation_phase_blockers();
	payload.terrain_selection_parity_blockers = terrain_selection_parity_blockers();
	payload.terrain_repaint_parity_blockers = terrain_repaint_parity_blockers();
	payload.missing_inputs = shared_runtime_chain_missing_reasons(controlled_case, payload.input);
	payload.executable = payload.missing_inputs.empty();
	if (!controlled_case.parse_ok) {
		return payload;
	}
	const int32_t width = h3maped_rmg_core::map_width_for_size_class(controlled_case.size_class);
	payload.width = width;
	payload.height = width;
	payload.level_count = controlled_case.level_count;
	if (!payload.executable) {
		return payload;
	}

	const std::vector<h3maped_rmg_core::RuntimeZoneSeedInput4a218c> runtime_zone_seeds = to_h3maped_runtime_zone_seeds(payload.input.runtime_zone_seeds);
	const std::vector<h3maped_rmg_core::RuntimeLinkSeedInput4a218c> runtime_links = to_h3maped_runtime_links(payload.input.runtime_links);
	const h3maped_rmg_core::CoordinateOwnerGridResult4a218c result =
			h3maped_rmg_core::coordinate_seed_and_materialize_owner_grid_4a218c_4a1f3b_4a19ed_4a3a03_4cca55_4a2777_4a325d_4a3710(
					width,
					width,
					controlled_case.level_count,
					h3maped_rmg_core::water_mode_code(controlled_case.water_mode),
					payload.input.generator_mode_0x10b8,
					payload.input.rng_state_after_template_selection,
					runtime_zone_seeds,
					runtime_links);
	const h3maped_rmg_core::TemplateSelectionRuntimeResult4ac552 template_selection =
			to_h3maped_template_selection_snapshot(payload.input);
	const h3maped_rmg_core::GeneratorObjectPrivateState generator_private_state =
			h3maped_rmg_core::generator_object_private_state_from_recovered_partial_chain(
					width,
					width,
					controlled_case.level_count,
					template_selection,
					result);
	payload.generator_object_private_state = from_h3maped_generator_object_private_state(generator_private_state);

	payload.coordinate_seed_blocked = result.coordinate_seed_blocked;
	payload.coordinate_generator_mode_0x10b8 = result.coordinate_seed.generator_mode_0x10b8;
	payload.coordinate_minimum_source_base_size = result.coordinate_seed.minimum_source_base_size;
	payload.coordinate_prune_divisor_4a218c = result.coordinate_seed.coordinate_prune_divisor_4a218c;
	payload.coordinate_prune_span_budget_4a218c = result.coordinate_seed.coordinate_prune_span_budget_4a218c;
		payload.coordinate_rng_state_before = result.coordinate_seed.rng_state_before;
		payload.coordinate_rng_state_after = result.coordinate_seed.rng_state_after;
		payload.coordinate_rng_call_count = result.coordinate_seed.rng_call_count;
		payload.town_choice_rng_call_count_0x49b3c1 = result.coordinate_seed.town_choice_rng_call_count_0x49b3c1;
		payload.coordinate_placement_step_count = int32_t(result.coordinate_seed.placement_steps.size());
	payload.coordinate_boundary_input_count = int32_t(result.coordinate_seed.boundary_inputs.size());
	payload.terrain_selection_rng_call_count_0x49b53d = result.terrain_selection.rng_call_count;
	payload.terrain_selection_match_to_town_count = result.terrain_selection.match_to_town_count;
	payload.terrain_selection_allowed_flag_choice_count = result.terrain_selection.allowed_flag_choice_count;
	payload.terrain_selection_no_eligible_default_zero_count = result.terrain_selection.no_eligible_default_zero_count;
	payload.terrain_selection_rng_state_after = result.terrain_selection.rng_state_after;
	payload.terrain_repaint_write_count_0x4a4163 = result.terrain_repaint.zone_repaint_write_count_0x4a4163;
	payload.terrain_visual_write_count_0x4bb74b = result.terrain_repaint.terrain_visual_write_count_0x4bb74b;
	payload.terrain_visual_missing_bucket_count_0x4bcfc3 = result.terrain_repaint.terrain_visual_missing_bucket_count_0x4bcfc3;
	for (const h3maped_rmg_core::TerrainVisualMissingBucketSample4bcfc3 &source : result.terrain_repaint.terrain_visual_missing_bucket_samples_0x4bcfc3) {
		TerrainVisualMissingBucketSample sample;
		sample.level = source.level;
		sample.x = source.x;
		sample.y = source.y;
		sample.terrain_id = source.terrain_id;
		sample.shape_class = source.shape_class;
		sample.flag_a = source.flag_a;
		sample.flag_b = source.flag_b;
		sample.neighbor_mask = source.neighbor_mask;
		sample.row_table_count = source.row_table_count;
		sample.final_sweep = source.final_sweep;
		payload.terrain_visual_missing_bucket_samples_0x4bcfc3.push_back(sample);
	}
	payload.terrain_visual_art_nonzero_cell_count = result.terrain_repaint.terrain_visual_art_nonzero_cell_count;
	payload.terrain_visual_flag_cell_count = result.terrain_repaint.terrain_visual_flag_cell_count;
	payload.terrain_visual_final_sweep_cell_count_0x4bbfcc = result.terrain_repaint.terrain_visual_final_sweep_cell_count_0x4bbfcc;
	payload.terrain_visual_preserved_current_record_count_0x4bc5a3 = result.terrain_repaint.terrain_visual_preserved_current_record_count_0x4bc5a3;
	payload.terrain_visual_roundtrip_mismatch_count = result.terrain_repaint.terrain_visual_roundtrip_mismatch_count;
	payload.terrain_visual_rng_state_after_0x4bb74b = result.terrain_repaint.terrain_visual_rng_state_after_0x4bb74b;
	payload.owner_grid_executed = result.owner_grid_executed;
	payload.source_blocked = result.owner_grid.source_blocked;
	payload.source_descriptor_node_count = result.owner_grid.source_footprints.source_descriptor_node_count;
	payload.source_descriptor_active_node_count = result.owner_grid.source_footprints.source_descriptor_active_node_count;
	payload.source_node_walk_count = result.owner_grid.source_footprints.source_node_walk_count;
	payload.source_handoff_count = int32_t(result.owner_grid.handoffs.size());
	payload.missing_boundary_input_count = result.owner_grid.missing_boundary_input_count;
	payload.missing_source_walk_count = result.owner_grid.missing_source_walk_count;
	payload.materialization_source_handoff_count = result.owner_grid.materialization.source_handoff_count;
	payload.materialization_source_handoff_descriptor_indexed_point_count = result.owner_grid.materialization.source_handoff_descriptor_indexed_point_count;
	payload.materialization_source_handoff_raw_coordinate_point_count = result.owner_grid.materialization.source_handoff_raw_coordinate_point_count;
	payload.materialization_source_record_seed_count = result.owner_grid.materialization.source_handoff_source_record_seed_count;
	payload.materialization_missing_source_record_seed_count = result.owner_grid.materialization.source_handoff_missing_source_record_seed_count;
	payload.materialization_runtime_zone_walk_count = result.owner_grid.materialization.runtime_zone_walk_count;
	payload.materialization_appended_vertex_count = result.owner_grid.materialization.appended_vertex_count;
	payload.materialization_span_fill_zone_count = result.owner_grid.materialization.span_fill_zone_count;
	payload.footprint_finalizer_executed = result.owner_grid.footprint_finalizer_executed;
	payload.footprint_finalizer_blocked = result.owner_grid.footprint_finalizer.blocked;
	payload.footprint_finalizer_status = result.owner_grid.footprint_finalizer.status;
	payload.footprint_finalizer_original_same_level_runtime_zone_count = result.owner_grid.footprint_finalizer.original_same_level_runtime_zone_count;
	payload.footprint_finalizer_final_runtime_zone_count = result.owner_grid.footprint_finalizer.final_runtime_zone_count;
	payload.footprint_finalizer_appended_runtime_zone_count = result.owner_grid.footprint_finalizer.appended_runtime_zone_count;
	payload.footprint_finalizer_zone_order_reset_call_count = result.owner_grid.footprint_finalizer.zone_order_reset_call_count;
	payload.footprint_finalizer_per_zone_order_helper_call_count = result.owner_grid.footprint_finalizer.per_zone_order_helper_call_count;
	payload.terrain_selection_repaint_status = result.terrain_repaint.status;
	if (result.terrain_repaint_executed && !result.terrain_repaint.generated_cell_word_0x20.empty()) {
		payload.generated_cell_word_0x10 = result.terrain_repaint.generated_cell_word_0x10;
		payload.generated_cell_word_0x1c = result.terrain_repaint.generated_cell_word_0x1c;
		payload.generated_cell_word_0x20 = result.terrain_repaint.generated_cell_word_0x20;
		payload.generated_cell_word_0x24 = result.terrain_repaint.generated_cell_word_0x24;
		payload.generated_cell_word_0x28 = result.terrain_repaint.generated_cell_word_0x28;
		payload.generated_cell_word_0x2c = result.terrain_repaint.generated_cell_word_0x2c;
		payload.built = true;
	} else if (result.owner_grid_executed && !result.owner_grid.materialization.generated_cell_word_0x20.empty()) {
		payload.generated_cell_word_0x20 = result.owner_grid.materialization.generated_cell_word_0x20;
		payload.built = false;
	}
	populate_generated_cell_word_arrays_from_record_grid(payload, generator_private_state.generated_cell_buffer);
	populate_generated_cell_record_surface_0x30(payload, generator_private_state.generated_cell_buffer);
	return payload;
}

std::string shared_runtime_chain_input_status(const ControlledCase &controlled_case, const SharedRuntimeChainInput &input) {
	const SharedRuntimeChainInput resolved = resolved_shared_runtime_chain_input(controlled_case, input);
	const std::vector<std::string> missing = shared_runtime_chain_missing_reasons(controlled_case, resolved);
	return missing.empty() ? "shared_inputs_ready" : "missing_exact_runtime_zone_seed_link_inputs";
}

bool shared_runtime_chain_input_executable(const ControlledCase &controlled_case, const SharedRuntimeChainInput &input) {
	const SharedRuntimeChainInput resolved = resolved_shared_runtime_chain_input(controlled_case, input);
	return shared_runtime_chain_missing_reasons(controlled_case, resolved).empty();
}

std::string case_shared_h3maped_state_chain_blocked_json(const ControlledCase &controlled_case, const std::string &status, const std::string &blocked_reason, const SharedRuntimeChainInput &shared_input) {
	const int32_t width = h3maped_rmg_core::map_width_for_size_class(controlled_case.size_class);
	const bool supported = supported_one_level_land_scope(controlled_case);
	std::ostringstream out;
	out << "{\n";
	out << "  \"schema_id\": \"rmg_native_batch_export_cli_shared_h3maped_state_chain_blocked_v1\",\n";
	out << "  \"runner\": \"standalone_native_cli_no_godot\",\n";
	out << "  \"godot_process_started\": false,\n";
	out << "  \"status\": \"" << json_escape(status) << "\",\n";
	out << "  \"blocked_reason\": \"" << json_escape(blocked_reason) << "\",\n";
	out << "  \"case_id\": \"" << json_escape(controlled_case.id) << "\",\n";
	out << "  \"raw_controlled_case\": \"" << json_escape(controlled_case.raw) << "\",\n";
	out << "  \"parse_ok\": " << (controlled_case.parse_ok ? "true" : "false") << ",\n";
	out << "  \"parse_error\": \"" << json_escape(controlled_case.parse_error) << "\",\n";
	out << "  \"supported_one_level_land_scope\": " << (supported ? "true" : "false") << ",\n";
	out << "  \"generation_output_written\": false,\n";
	out << "  \"amap_written\": false,\n";
	out << "  \"live_generation_surface_present\": false,\n";
	out << "  \"runtime_generation_allowed\": false,\n";
	out << "  \"native_rmg_end_to_end_parity_complete\": false,\n";
	out << "  \"normalized_config\": {\n";
	out << "    \"size_class\": \"" << json_escape(controlled_case.size_class) << "\",\n";
	out << "    \"width\": " << width << ",\n";
	out << "    \"height\": " << width << ",\n";
	out << "    \"players\": " << controlled_case.players << ",\n";
	out << "    \"seed\": " << controlled_case.seed << ",\n";
	out << "    \"water_mode\": \"" << json_escape(controlled_case.water_mode) << "\",\n";
	out << "    \"level_count\": " << controlled_case.level_count << ",\n";
	out << "    \"human_count\": " << controlled_case.human_count << ",\n";
	out << "    \"computer_count\": " << controlled_case.computer_count << "\n";
	out << "  },\n";
	out << "  \"blocked_chain\": {\n";
	out << "    \"required_source\": \"full_recovered_h3maped_entrypoint_to_writeout_private_state_chain\",\n";
	out << "    \"current_blocker\": \"native owns only partial coordinate owner-grid and TerrainPlacement support; source records, descriptor identity, full generated-cell records, relation/object callers, endpoint/connection, roads/rivers, writeout, and same-run private-state comparison remain unported\",\n";
	out << "    \"required_refactor\": \"port the remaining drift-audit phases D-001 through D-003 and D-005 onward from docs/native-rmg-core-h3maped-drift-audit.md before emitting a comparable pre-0x4a4c8e checkpoint or native map output\",\n";
	out << "    \"forbidden_substitutes\": [\"parallel native state substitute\", \"density scalars\", \"final-map delta tuning\", \"validator-gated package draft adoption\", \"brute-force retries\"]\n";
	out << "  },\n";
	append_shared_chain_json(out, controlled_case, width, shared_input);
	out << ",\n";
	out << "  \"next_required_native_core_slice\": \"port_full_source_records_descriptor_identity_and_generated_cell_state_before_relation_object_consumers\",\n";
	out << "  \"next_required_alignment_slice\": \"do_not_compare_pre_0x4a4c8e_generated_cells_until_full_mutation_chain_is_source_owned\"\n";
	out << "}\n";
	return out.str();
}

std::string safe_case_filename(const std::string &case_id) {
	std::string out;
	out.reserve(case_id.size());
	for (const unsigned char ch : case_id) {
		if (std::isalnum(ch) != 0 || ch == '-' || ch == '_') {
			out.push_back(static_cast<char>(ch));
		} else {
			out.push_back('_');
		}
	}
	return out.empty() ? "case" : out;
}

} // namespace aurelion::rmg_native_core
