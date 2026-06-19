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
		"0x4a5767_0x49a318_relation_reset_caller_order",
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

int32_t generated_cell_record_known_count(const std::vector<SharedGeneratedCellRecord0x30> &records, bool SharedGeneratedCellRecord0x30::*member) {
	return int32_t(std::count_if(records.begin(), records.end(), [member](const SharedGeneratedCellRecord0x30 &record) {
		return record.*member;
	}));
}

void populate_generated_cell_record_surface_0x30(RecoveredOwnerGridPayload &payload) {
	payload.generated_cell_record_shape_0x30_present = false;
	payload.generated_cell_record_stride_bytes = h3maped_rmg_core::GENERATED_CELL_RECORD_STRIDE_BYTES;
	payload.generated_cell_record_surface_status = "not_built";
	payload.generated_cell_records_0x30.clear();
	if (payload.width <= 0 || payload.height <= 0 || payload.level_count <= 0) {
		return;
	}
	const h3maped_rmg_core::GeneratedCellRecordGrid0x30 source =
			h3maped_rmg_core::generated_cell_record_grid_reset_0x49a072(payload.width, payload.height, payload.level_count);
	if (source.records.empty()) {
		return;
	}
	payload.generated_cell_record_shape_0x30_present = true;
	payload.generated_cell_record_stride_bytes = source.stride_bytes;
	payload.generated_cell_record_surface_status = "partial_stride_0x30_record_shape_from_0x49a072_0x499ea3_with_owner_terrain_word_overlays_not_pre_0x4a4c8e_checkpoint";
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
		input.subtype_0x20,
		input.group_0x24,
		input.last_flag_0x28,
		input.pass_count,
		input.action_count,
		input.terrain_mask_a_0x14,
		input.terrain_mask_b_0x18,
		input.terrain_a_names,
		input.terrain_b_names,
		input.rand_trn_backed,
	};
}

bool same_source_object_record_sample(const SharedSourceObjectRecord0x4c &left, const SharedSourceObjectRecord0x4c &right) {
	return left.source_row == right.source_row
			&& left.source == right.source
			&& left.def_name == right.def_name
			&& left.type_id_0x1c == right.type_id_0x1c
			&& left.subtype_0x20 == right.subtype_0x20;
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

void populate_source_object_catalog_0x49da08(RecoveredOwnerGridPayload &payload) {
	const h3maped_rmg_core::SourceObjectCatalogSummary0x49da08 summary =
			h3maped_rmg_core::source_object_catalog_summary_0x49da08();
	payload.source_object_catalog_0x49da08_present = summary.record_count > 0;
	payload.source_object_catalog_0x49da08_record_count = summary.record_count;
	payload.source_object_catalog_0x4c_copy_size_bytes = summary.source_record_copy_size_bytes;
	payload.source_object_catalog_objects_txt_record_count = summary.objects_txt_record_count;
	payload.source_object_catalog_rand_trn_backed_record_count = summary.rand_trn_backed_record_count;
	payload.source_object_catalog_type53_record_count = summary.mine_type53_record_count;
	payload.source_object_catalog_type53_ambiguous_subtype_count = summary.mine_type53_ambiguous_subtype_count;
	payload.source_object_catalog_descriptor_only_mine_identity_ambiguous = summary.descriptor_only_mine_identity_ambiguous;
	payload.source_object_catalog_samples.clear();

	const std::vector<h3maped_rmg_core::SourceObjectRecord0x4c> &catalog =
			h3maped_rmg_core::source_object_catalog_0x49da08();
	add_first_source_object_sample(payload, catalog);
	add_first_source_object_sample(payload, h3maped_rmg_core::source_object_records_by_type_0x49da08(45));
	add_first_source_object_sample(payload, h3maped_rmg_core::source_object_records_by_type_subtype_0x49da08(53, 4));
	add_first_source_object_sample(payload, h3maped_rmg_core::source_object_records_by_type_0x49da08(54));
	add_first_source_object_sample(payload, h3maped_rmg_core::source_object_records_by_type_0x49da08(79));
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
		<< ",\"subtype_0x20\":" << record.subtype_0x20
		<< ",\"group_0x24\":" << record.group_0x24
		<< ",\"last_flag_0x28\":" << record.last_flag_0x28
		<< ",\"pass_count\":" << record.pass_count
		<< ",\"action_count\":" << record.action_count
		<< ",\"terrain_mask_a_0x14\":" << record.terrain_mask_a_0x14
		<< ",\"terrain_mask_b_0x18\":" << record.terrain_mask_b_0x18
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

void append_source_object_record_catalog_json(std::ostream &out, const RecoveredOwnerGridPayload &payload) {
	out << "{"
		<< "\"schema_id\":\"rmg_native_source_object_record_catalog_0x49da08_v1\","
		<< "\"status\":\"source_record_catalog_identity_preserved_selection_descriptor_join_and_materialization_pending\","
		<< "\"h3maped_entry_anchor\":\"0x49da08_objects_txt_loader_0x49db76_wrapper_init_0x49dc9e_rand_trn_loader\","
		<< "\"present\":" << (payload.source_object_catalog_0x49da08_present ? "true" : "false") << ","
		<< "\"source_record_copy_size_bytes\":" << payload.source_object_catalog_0x4c_copy_size_bytes << ","
		<< "\"record_count\":" << payload.source_object_catalog_0x49da08_record_count << ","
		<< "\"objects_txt_record_count\":" << payload.source_object_catalog_objects_txt_record_count << ","
		<< "\"rand_trn_backed_record_count\":" << payload.source_object_catalog_rand_trn_backed_record_count << ","
		<< "\"type53_record_count\":" << payload.source_object_catalog_type53_record_count << ","
		<< "\"type53_ambiguous_subtype_count\":" << payload.source_object_catalog_type53_ambiguous_subtype_count << ","
		<< "\"descriptor_only_mine_identity_ambiguous\":" << (payload.source_object_catalog_descriptor_only_mine_identity_ambiguous ? "true" : "false") << ","
		<< "\"identity_rule\":\"copied_0x4c_source_record_is_identity_authority_descriptor_plus_0x00_not_universal_row_id\","
		<< "\"remaining_blockers\":[\"0xe8_wrapper_bucket_selection\", \"0x4903e8_descriptor_source_join\", \"source_record_through_object_materialization\", \"relation_object_caller_order\"],"
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
			out.push_back(h3maped_rmg_core::RuntimeZoneSeedInput4a218c {
				input.runtime_zone_index,
				input.source_zone_id,
				input.source_index,
				input.h3maped_zone_word_id,
				input.source_bucket,
				input.actual_player_color,
				input.source_base_size,
				input.allowed_town_mask_0x41_0x49,
				input.selected_town_choice_index_0x49b3c1,
				input.terrain_match_to_town_0x84,
				input.allowed_terrain_mask_0x85_0x8c,
				to_h3maped_source_zone_payload(input.source_payload),
			});
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
		});
	}
	return out;
}

std::vector<SharedRuntimeZoneSeedInput> from_h3maped_runtime_zone_seeds(const std::vector<h3maped_rmg_core::RuntimeZoneSeedInput4a218c> &inputs) {
	std::vector<SharedRuntimeZoneSeedInput> out;
	out.reserve(inputs.size());
	for (const h3maped_rmg_core::RuntimeZoneSeedInput4a218c &input : inputs) {
			out.push_back(SharedRuntimeZoneSeedInput {
				input.runtime_zone_index,
				input.source_zone_id,
				input.source_index,
				input.h3maped_zone_word_id,
				input.source_bucket,
				input.actual_player_color,
				input.source_base_size,
				input.allowed_town_mask_0x41_0x49,
				input.selected_town_choice_index_0x49b3c1,
				input.terrain_match_to_town_0x84,
				input.allowed_terrain_mask_0x85_0x8c,
				from_h3maped_source_zone_payload(input.source_payload),
			});
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
	out << "      \"word_0x14_0x18_source\": \"not_native_owned_until_0x4a5767_0x4a606b_projection_chain_is_ported\",\n";
	out << "      \"byte_0x2b_source\": \"not_native_owned_until_validity_private_byte_mutations_0x49a1d8_0x49abd6_0x4a5a23_are_ported\",\n";
	out << "      \"word_0x10_0x1c_partial_source\": \"generated_cell_grid_reset_0x49a072_0x499ea3_before_downstream_consumers_not_pre_0x4a4c8e_checkpoint\",\n";
	out << "      \"word_0x20_source\": \"shared_recovered_owner_grid_materialization\",\n";
	out << "      \"word_0x24_0x28_source\": \"0x49b3c1_0x49b53d_0x4a3f27_terrain_repaint_0x4bb74b_0x4bad0f_0x4bcfc3_0x4bce6d_visual_rows\",\n";
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
	populate_generated_cell_record_surface_0x30(payload);
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
