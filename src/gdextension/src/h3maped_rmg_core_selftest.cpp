#include "h3maped_rmg_core.hpp"

#include <algorithm>
#include <iostream>
#include <string>
#include <vector>

namespace {

using aurelion::h3maped_rmg_core::BoundaryMaterialization4a2777;
using aurelion::h3maped_rmg_core::BoundaryOwnerGridResult4a3a03;
using aurelion::h3maped_rmg_core::BoundarySourceCycleHandoff4a2777;
using aurelion::h3maped_rmg_core::CoordinateOwnerGridResult4a218c;
using aurelion::h3maped_rmg_core::EndpointMaterializationResult4a5e73;
using aurelion::h3maped_rmg_core::EndpointMaterializationState4a5e73;
using aurelion::h3maped_rmg_core::EndpointPointerRecord4a5e73;
using aurelion::h3maped_rmg_core::GeneratorCoordinateCandidateVectorState4a1f3b;
using aurelion::h3maped_rmg_core::GeneratorObjectPrivateState;
using aurelion::h3maped_rmg_core::GeneratorSourceEndpointRecordState4a1f3b;
using aurelion::h3maped_rmg_core::GeneratorSetupModeResult49ecf2;
using aurelion::h3maped_rmg_core::GeneratedCellRecord0x30;
using aurelion::h3maped_rmg_core::GeneratedCellRecordGrid0x30;
using aurelion::h3maped_rmg_core::GeneratedCellWordGrid;
using aurelion::h3maped_rmg_core::RuntimeZoneBoundaryInput4a3a03;
using aurelion::h3maped_rmg_core::RuntimeZoneFootprintInput4a3a03;
using aurelion::h3maped_rmg_core::RuntimeLinkSeedInput4a218c;
using aurelion::h3maped_rmg_core::RuntimeTerrainSelectionResult49b53d;
using aurelion::h3maped_rmg_core::RuntimeZoneSeedInput4a218c;
using aurelion::h3maped_rmg_core::RuntimeSeedBuildResult4a218c;
using aurelion::h3maped_rmg_core::SourceObjectCatalogSummary0x49da08;
using aurelion::h3maped_rmg_core::SourceObjectMaskLaneResult4af89f;
using aurelion::h3maped_rmg_core::SourceObjectRecord0x4c;
using aurelion::h3maped_rmg_core::SourceObjectResolverResult4af785;
using aurelion::h3maped_rmg_core::SourceObjectResolverState4af785;
using aurelion::h3maped_rmg_core::SourceObjectSelectorResult4a9e40;
using aurelion::h3maped_rmg_core::SourceObjectWrapperBucket0xe8;
using aurelion::h3maped_rmg_core::SourceObjectWrapperBucketSummary0xe8;
using aurelion::h3maped_rmg_core::SourceNodeFootprintResult4a3a03;
using aurelion::h3maped_rmg_core::SourceNodeCyclePoint4a2777;
using aurelion::h3maped_rmg_core::SpanRecord;
using aurelion::h3maped_rmg_core::TerrainRepaintResult4a3f27;
using aurelion::h3maped_rmg_core::TemplateSelectionRuntimeResult4ac552;
using aurelion::h3maped_rmg_core::TemplateLinkRecord4a1f3b;
using aurelion::h3maped_rmg_core::TemplateZoneRecord4a218c;

SourceNodeCyclePoint4a2777 source_node(int32_t x, int32_t y, int32_t model_node_index) {
	SourceNodeCyclePoint4a2777 node;
	node.model_node_index = model_node_index;
	node.pair_index = model_node_index ^ 1;
	node.next_index = (model_node_index + 1) % 4;
	node.previous_index = (model_node_index + 3) % 4;
	node.next_pair_index = (model_node_index + 2) % 4;
	node.raw_x_0x00 = x - 1;
	node.raw_y_0x04 = y - 1;
	node.finalized_x_0x1c = x;
	node.finalized_y_0x20 = y;
	node.finalized = true;
	return node;
}

BoundarySourceCycleHandoff4a2777 square_handoff(bool gate_first_edge) {
	BoundarySourceCycleHandoff4a2777 handoff;
	handoff.runtime_zone_index = 0;
	handoff.zone_word = 1;
	handoff.level = 0;
	handoff.random_span_limit = 1;
	handoff.source_record_vector_index_4a3e9c = 0;
	handoff.has_source_record_seed_0x10 = true;
	handoff.source_record_seed_0x10 = SpanRecord { 3, 3, 0 };
	handoff.source_nodes = {
		source_node(1, 1, 0),
		source_node(6, 1, 1),
		source_node(6, 6, 2),
		source_node(1, 6, 3),
	};
	if (gate_first_edge) {
		handoff.source_nodes[0].next_pair_has_payload = true;
		handoff.source_nodes[0].next_pair_payload = 1;
	}
	return handoff;
}

bool require(bool condition, const std::string &message) {
	if (!condition) {
		std::cerr << "h3maped_rmg_core_selftest: " << message << "\n";
		return false;
	}
	return true;
}

} // namespace

int main() {
	{
		const SourceObjectCatalogSummary0x49da08 source_object_summary =
				aurelion::h3maped_rmg_core::source_object_catalog_summary_0x49da08();
		if (!require(source_object_summary.record_count == 1328, "0x49da08 source object catalog did not preserve recovered row count")) {
			return 1;
		}
		if (!require(source_object_summary.source_record_copy_size_bytes == aurelion::h3maped_rmg_core::SOURCE_OBJECT_RECORD_COPY_SIZE_BYTES_0X4C, "0x49da08 source record copy size must remain 0x4c")) {
			return 1;
		}
		if (!require(source_object_summary.objects_txt_record_count == 1326, "0x49da08 source object catalog lost objects.txt row identity")) {
			return 1;
		}
		if (!require(source_object_summary.rand_trn_backed_record_count == 543, "0x49da08 source object catalog lost rand_trn-backed identity")) {
			return 1;
		}
		if (!require(source_object_summary.mine_type53_record_count == 46, "0x49da08 source object catalog lost type-53 mine rows")) {
			return 1;
		}
		if (!require(source_object_summary.descriptor_only_mine_identity_ambiguous, "type-53 mine source identity must remain descriptor-ambiguous without copied records")) {
			return 1;
		}
		const std::vector<SourceObjectRecord0x4c> type45_records =
				aurelion::h3maped_rmg_core::source_object_records_by_type_0x49da08(45);
		if (!require(!type45_records.empty() && !type45_records[0].def_name.empty(), "0x49da08 type-45 source record lookup did not preserve DEF identity")) {
			return 1;
		}
		if (!require(type45_records[0].metadata_bucket_index_0x08 == 0, "0x49da08 type-45 source record lost metadata +0x08 bucket lane")) {
			return 1;
		}
		const std::vector<SourceObjectRecord0x4c> type199_records =
				aurelion::h3maped_rmg_core::source_object_records_by_type_0x49da08(199);
		if (!require(!type199_records.empty() && type199_records[0].metadata_bucket_index_0x08 == 155, "0x49da08 type-199 source record did not map to recovered metadata bucket 155")) {
			return 1;
		}
		const std::vector<SourceObjectRecord0x4c> mine_subtype_records =
				aurelion::h3maped_rmg_core::source_object_records_by_type_subtype_0x49da08(53, 4);
		if (!require(mine_subtype_records.size() > 1, "0x49da08 mine subtype 4 must remain ambiguous across copied source records")) {
			return 1;
		}
		if (!require(mine_subtype_records[0].source_row > 0 && !mine_subtype_records[0].def_name.empty(), "0x49da08 mine source record lookup lost source row/DEF identity")) {
			return 1;
		}
		const SourceObjectWrapperBucketSummary0xe8 wrapper_summary =
				aurelion::h3maped_rmg_core::source_object_wrapper_bucket_summary_0x49db76();
		if (!require(wrapper_summary.bucket_count == aurelion::h3maped_rmg_core::SOURCE_OBJECT_WRAPPER_BUCKET_COUNT_0XE8, "0x49db76 wrapper bucket table did not preserve 0xe8 bucket count")) {
			return 1;
		}
		if (!require(wrapper_summary.initialized_bucket_count == 0xe8, "0x49db76 wrapper initialization did not initialize every metadata bucket")) {
			return 1;
		}
		if (!require(wrapper_summary.non_empty_bucket_count == 8, "0x49db76 wrapper bucket table must use metadata +0x08 lanes, not raw type groups")) {
			return 1;
		}
		if (!require(wrapper_summary.total_source_record_references == source_object_summary.record_count, "0x49db76 wrapper bucket table did not account for every source record")) {
			return 1;
		}
		if (!require(wrapper_summary.out_of_range_source_record_count == 0, "0x49db76 wrapper bucket table found out-of-range metadata buckets despite recovered 0xe8 bound")) {
			return 1;
		}
		if (!require(wrapper_summary.max_bucket_index_0x08 == 0 && wrapper_summary.max_bucket_record_count == 1252, "0x49db76 wrapper max bucket drifted from recovered metadata bucket 0")) {
			return 1;
		}
		SourceObjectWrapperBucket0xe8 default_bucket;
		if (!require(aurelion::h3maped_rmg_core::source_object_wrapper_bucket_by_index_0x49db76(0, default_bucket), "0x49db76 wrapper lookup rejected metadata bucket 0")) {
			return 1;
		}
		if (!require(default_bucket.initialized_by_0x49db76 && default_bucket.record_count == 1252 && default_bucket.source_record_indices.size() == 1252, "0x49db76 metadata bucket 0 lost source records")) {
			return 1;
		}
		SourceObjectWrapperBucket0xe8 tree_bucket;
		if (!require(aurelion::h3maped_rmg_core::source_object_wrapper_bucket_by_index_0x49db76(155, tree_bucket), "0x49db76 wrapper lookup rejected metadata bucket 155")) {
			return 1;
		}
		if (!require(tree_bucket.initialized_by_0x49db76 && tree_bucket.record_count == 51 && tree_bucket.first_type_id_0x1c == 199, "0x49db76 metadata bucket 155 lost type-199 source records")) {
			return 1;
		}
		SourceObjectWrapperBucket0xe8 mine_bucket;
		if (!require(aurelion::h3maped_rmg_core::source_object_wrapper_bucket_by_index_0x49db76(53, mine_bucket), "0x49db76 wrapper lookup rejected metadata bucket 53")) {
			return 1;
		}
		if (!require(mine_bucket.initialized_by_0x49db76 && mine_bucket.record_count == 7 && mine_bucket.first_type_id_0x1c == 220, "0x49db76 metadata bucket 53 lost type-220 source records")) {
			return 1;
		}
		SourceObjectWrapperBucket0xe8 empty_bucket;
		if (!require(aurelion::h3maped_rmg_core::source_object_wrapper_bucket_by_index_0x49db76(1, empty_bucket) && empty_bucket.initialized_by_0x49db76 && empty_bucket.record_count == 0, "0x49db76 empty wrapper bucket was not preserved")) {
			return 1;
		}
		const SourceObjectMaskLaneResult4af89f type199_lane =
				aurelion::h3maped_rmg_core::source_object_mask_lane_selector_0x4af89f(type199_records[0]);
		if (!require(type199_lane.scanned_lane_count >= 1 && type199_lane.selected_lane >= 0 && type199_lane.selected_lane <= 9, "0x4af89f source mask lane selector returned an invalid lane")) {
			return 1;
		}
		const SourceObjectSelectorResult4a9e40 type199_selection =
				aurelion::h3maped_rmg_core::source_object_wrapper_selector_0x4a9e40(10U, type199_lane.selected_lane, type199_records[0].metadata_bucket_index_0x08, type199_records[0].subtype_0x20);
		if (!require(type199_selection.bucket_found && type199_selection.scanned_record_count == 51 && type199_selection.accepted_count > 0, "0x4a9e40 source wrapper selector did not scan metadata bucket 155 candidates")) {
			return 1;
		}
		if (!require(type199_selection.selected && type199_selection.rng_consumed && type199_selection.rng_value == 71 && type199_selection.rng_state_after == 0x004746a5U, "0x4a9e40 source wrapper selector did not consume the recovered RNG path")) {
			return 1;
		}
		if (!require(std::find(type199_selection.accepted_source_record_indices.begin(), type199_selection.accepted_source_record_indices.end(), type199_selection.selected_source_record_index) != type199_selection.accepted_source_record_indices.end(), "0x4a9e40 selected record was not part of the accepted candidate vector")) {
			return 1;
		}
		const SourceObjectSelectorResult4a9e40 impossible_selection =
				aurelion::h3maped_rmg_core::source_object_wrapper_selector_0x4a9e40(10U, type199_lane.selected_lane, type199_records[0].metadata_bucket_index_0x08, -999);
		if (!require(impossible_selection.bucket_found && impossible_selection.accepted_count == 0 && !impossible_selection.rng_consumed && impossible_selection.rng_state_after == 10U, "0x4a9e40 selector consumed RNG despite having no accepted candidates")) {
			return 1;
		}
		SourceObjectResolverState4af785 resolver_state;
		const SourceObjectResolverResult4af785 first_resolve =
				aurelion::h3maped_rmg_core::source_object_descriptor_resolver_0x4af785(resolver_state, type199_records[0]);
		if (!require(first_resolve.created_new_wrapper && !first_resolve.reused_existing_wrapper && first_resolve.selected_wrapper_index == 0, "0x4af785 did not create the first resolved wrapper")) {
			return 1;
		}
		if (!require(first_resolve.metadata_bucket_index_0x08 == 155 && first_resolve.resolver_lane_0x04 == type199_lane.selected_lane, "0x4af785 first wrapper did not preserve metadata bucket/lane")) {
			return 1;
		}
		if (!require(first_resolve.copied_source_record && first_resolve.appended_source_pair_0xedc && first_resolve.appended_wrapper_to_bucket, "0x4af785 first wrapper did not copy source record and append wrapper/source pair")) {
			return 1;
		}
		if (!require(resolver_state.wrappers.size() == 1 && resolver_state.source_pairs_0xedc.size() == 1, "0x4af785 resolver state did not record first wrapper/source pair")) {
			return 1;
		}
		const SourceObjectResolverResult4af785 reuse_resolve =
				aurelion::h3maped_rmg_core::source_object_descriptor_resolver_0x4af785(resolver_state, type199_records[0]);
		if (!require(reuse_resolve.reused_existing_wrapper && !reuse_resolve.created_new_wrapper && reuse_resolve.selected_wrapper_index == first_resolve.selected_wrapper_index, "0x4af785 did not reuse an identical copied source record")) {
			return 1;
		}
		if (!require(resolver_state.wrappers.size() == 1 && resolver_state.source_pairs_0xedc.size() == 1 && reuse_resolve.source_pair_count_after == 1, "0x4af785 reuse should not append wrapper/source-pair state")) {
			return 1;
		}
		for (const SourceObjectRecord0x4c &candidate : type199_records) {
			const SourceObjectMaskLaneResult4af89f candidate_lane =
					aurelion::h3maped_rmg_core::source_object_mask_lane_selector_0x4af89f(candidate);
			if (candidate.metadata_bucket_index_0x08 == type199_records[0].metadata_bucket_index_0x08
					&& candidate.subtype_0x20 == type199_records[0].subtype_0x20
					&& candidate_lane.selected_lane == type199_lane.selected_lane
					&& !aurelion::h3maped_rmg_core::same_source_object_record_0x4c(candidate, type199_records[0])) {
				const SourceObjectResolverResult4af785 mismatch_resolve =
						aurelion::h3maped_rmg_core::source_object_descriptor_resolver_0x4af785(resolver_state, candidate);
				if (!require(mismatch_resolve.created_new_wrapper && mismatch_resolve.source_copy_mismatch_count > 0, "0x4af785 same lane/source-field mismatch did not create a new copied wrapper")) {
					return 1;
				}
				if (!require(resolver_state.wrappers.size() == 2 && resolver_state.source_pairs_0xedc.size() == 2, "0x4af785 mismatch create did not append second wrapper/source pair")) {
					return 1;
				}
				break;
			}
		}
		SourceObjectRecord0x4c blank_record;
		const SourceObjectMaskLaneResult4af89f blank_lane =
				aurelion::h3maped_rmg_core::source_object_mask_lane_selector_0x4af89f(blank_record);
		if (!require(blank_lane.selected_lane == 9 && !blank_lane.selected_by_mask && blank_lane.scanned_lane_count == 9, "0x4af89f zero-mask record did not return sentinel lane 9")) {
			return 1;
		}
	}

	{
		GeneratedCellRecordGrid0x30 record_grid = aurelion::h3maped_rmg_core::generated_cell_record_grid_reset_0x49a072(2, 2, 1);
		if (!require(record_grid.stride_bytes == aurelion::h3maped_rmg_core::GENERATED_CELL_RECORD_STRIDE_BYTES, "generated-cell record grid did not preserve stride 0x30")) {
			return 1;
		}
		if (!require(record_grid.records.size() == 4, "generated-cell record grid reset did not create four records")) {
			return 1;
		}
		const auto &record = record_grid.records[0];
		if (!require(record.object_reference_vector_fields_0x04_0x08_present, "generated-cell record did not expose object-reference vector fields")) {
			return 1;
		}
		if (!require(!record.object_reference_vector_contents_known, "0x49a072/0x499ea3 reset must not claim object-reference vector contents")) {
			return 1;
		}
		if (!require(record.word_0x10_known && record.word_0x10 == aurelion::h3maped_rmg_core::GENERATED_CELL_INITIAL_WORD_0X10, "generated-cell +0x10 reset word mismatch")) {
			return 1;
		}
		if (!require(!record.word_0x14_known && !record.word_0x18_known, "generated-cell projection words +0x14/+0x18 must stay unknown until 0x4a5767 is ported")) {
			return 1;
		}
		if (!require(record.word_0x1c_known && record.word_0x1c == aurelion::h3maped_rmg_core::GENERATED_CELL_INITIAL_WORD_0X1C, "generated-cell +0x1c reset word mismatch")) {
			return 1;
		}
		if (!require(record.word_0x20_known && record.word_0x20 == aurelion::h3maped_rmg_core::GENERATED_CELL_INITIAL_WORD_0X20, "generated-cell +0x20 reset word mismatch")) {
			return 1;
		}
		if (!require(record.word_0x24_known && record.word_0x24 == aurelion::h3maped_rmg_core::GENERATED_CELL_INITIAL_WORD_0X24_VALUE, "generated-cell +0x24 reset word mismatch")) {
			return 1;
		}
		if (!require(record.word_0x28_known && record.word_0x28 == aurelion::h3maped_rmg_core::GENERATED_CELL_INITIAL_WORD_0X28_VALUE, "generated-cell +0x28 reset word mismatch")) {
			return 1;
		}
		if (!require(!record.byte_0x2b_known, "generated-cell validity byte +0x2b must stay unknown until its mutators are ported")) {
			return 1;
		}
		auto projection_record = record;
		projection_record.word_0x20 = 0x00123456U;
		projection_record.word_0x28 |= aurelion::h3maped_rmg_core::RELATION_WORD_0X28_BITS_12_14_MASK;
		if (!require(aurelion::h3maped_rmg_core::generated_cell_4a5767_reset_projection(projection_record), "record 0x4a5767 reset projection did not mutate the generated-cell record")) {
			return 1;
		}
		if (!require(projection_record.word_0x10_known && projection_record.word_0x10 == aurelion::h3maped_rmg_core::RELATION_RESET_COORD_MINUS_ONE
					&& projection_record.word_0x14_known && projection_record.word_0x14 == aurelion::h3maped_rmg_core::RELATION_RESET_COORD_MINUS_ONE
					&& projection_record.word_0x18_known && projection_record.word_0x18 == aurelion::h3maped_rmg_core::RELATION_RESET_COORD_MINUS_ONE,
					"record 0x4a5767 reset projection did not write +0x10/+0x14/+0x18 to -1")) {
			return 1;
		}
		if (!require(projection_record.word_0x1c_known && projection_record.word_0x1c == aurelion::h3maped_rmg_core::RELATION_RESET_WORD_0X1C, "record 0x4a5767 reset projection did not write +0x1c reset word")) {
			return 1;
		}
		if (!require(projection_record.word_0x20_known && projection_record.word_0x20 == 0xff123456U, "record 0x4a5767 reset projection did not pack +0x20 byte3")) {
			return 1;
		}
		if (!require(projection_record.word_0x28_known && (projection_record.word_0x28 & aurelion::h3maped_rmg_core::RELATION_WORD_0X28_BITS_12_14_MASK) == 0U, "record 0x4a5767 reset projection did not clear +0x28 bits 12..14")) {
			return 1;
		}
		projection_record.word_0x10 = 0x00000011U;
		projection_record.word_0x14 = 0x00000022U;
		projection_record.word_0x18 = 0x00000033U;
		projection_record.word_0x1c = 0x7d001234U;
		if (!require(aurelion::h3maped_rmg_core::generated_cell_49a318_clear_source_projection(projection_record), "record 0x49a318 source clear did not mutate the generated-cell record")) {
			return 1;
		}
		if (!require(projection_record.word_0x1c == 0x7d000000U, "record 0x49a318 source clear did not clear +0x1c low word")) {
			return 1;
		}
		if (!require(projection_record.word_0x10 == aurelion::h3maped_rmg_core::RELATION_RESET_COORD_MINUS_ONE
					&& projection_record.word_0x14 == aurelion::h3maped_rmg_core::RELATION_RESET_COORD_MINUS_ONE
					&& projection_record.word_0x18 == aurelion::h3maped_rmg_core::RELATION_RESET_COORD_MINUS_ONE,
					"record 0x49a318 source clear did not reset +0x10/+0x14/+0x18 to -1")) {
			return 1;
		}
		const GeneratedCellWordGrid word_grid = aurelion::h3maped_rmg_core::generated_cell_grid_reset_0x49a072(2, 2, 1);
		if (!require(word_grid.word_0x20.size() == record_grid.records.size() && word_grid.word_0x20[0] == record.word_0x20, "legacy generated-cell word grid no longer projects from record grid")) {
			return 1;
		}
		auto mutable_record = record;
		if (!require(aurelion::h3maped_rmg_core::generated_cell_49aa63(mutable_record, true), "record 0x49aa63(true) did not set bit26")) {
			return 1;
		}
		if (!require((mutable_record.word_0x28 & aurelion::h3maped_rmg_core::CELL_DECOR_CANDIDATE_BIT_26) != 0U && (mutable_record.word_0x28 & aurelion::h3maped_rmg_core::CELL_OCCUPIED_BLOCKED_BIT_27) == 0U, "record 0x49aa63(true) did not set bit26 and clear bit27")) {
			return 1;
		}
		if (!require(aurelion::h3maped_rmg_core::generated_cell_49a932(mutable_record, true), "record 0x49a932(true) did not set bit27")) {
			return 1;
		}
		if (!require((mutable_record.word_0x28 & aurelion::h3maped_rmg_core::CELL_OCCUPIED_BLOCKED_BIT_27) != 0U && (mutable_record.word_0x28 & aurelion::h3maped_rmg_core::CELL_DECOR_CANDIDATE_BIT_26) == 0U, "record 0x49a932(true) did not set bit27 and clear bit26")) {
			return 1;
		}
		if (!require(aurelion::h3maped_rmg_core::generated_cell_49abd6_action_stamp(mutable_record), "record 0x49abd6 action stamp did not mutate bit22/bit27")) {
			return 1;
		}
		if (!require((mutable_record.word_0x28 & aurelion::h3maped_rmg_core::CELL_ACTION_CONTROL_BIT_22) != 0U && (mutable_record.word_0x28 & aurelion::h3maped_rmg_core::CELL_OCCUPIED_BLOCKED_BIT_27) != 0U, "record 0x49abd6 action stamp did not leave bit22 and bit27 set")) {
			return 1;
		}
		mutable_record.byte_0x2b = 0x02U;
		mutable_record.byte_0x2b_known_mask = 0x02U;
		if (!require(aurelion::h3maped_rmg_core::generated_cell_49a1d8_valid_record(mutable_record), "record 0x49a1d8 did not accept known +0x2b bit0x02 with non-rock terrain")) {
			return 1;
		}
		if (!require(aurelion::h3maped_rmg_core::generated_cell_49abd6_body_reject_stamp(mutable_record), "record 0x49abd6 body reject did not clear bit25")) {
			return 1;
		}
		if (!require((mutable_record.byte_0x2b_known_mask & 0x02U) != 0U && (mutable_record.byte_0x2b & 0x02U) == 0U, "record 0x49abd6 body reject did not mark +0x2b bit0x02 known-clear")) {
			return 1;
		}
		if (!require((mutable_record.word_0x28 & aurelion::h3maped_rmg_core::CELL_DECOR_READY_BIT_25) == 0U, "record 0x49abd6 body reject did not clear bit25")) {
			return 1;
		}
		if (!require(!aurelion::h3maped_rmg_core::generated_cell_49a1d8_valid_record(mutable_record), "record 0x49a1d8 accepted after +0x2b bit0x02 was cleared")) {
			return 1;
		}

		GeneratedCellRecordGrid0x30 region_grid = aurelion::h3maped_rmg_core::generated_cell_record_grid_reset_0x49a072(4, 4, 1);
		for (GeneratedCellRecord0x30 &region_record : region_grid.records) {
			region_record.object_reference_vector_contents_known = true;
			region_record.object_reference_count = 0;
		}
		GeneratedCellRecord0x30 &region_source = region_grid.records[size_t(aurelion::h3maped_rmg_core::cell_index(4, 4, 1, 1, 0))];
		region_source.word_0x10_known = true;
		region_source.word_0x10 = 2U;
		region_source.word_0x14_known = true;
		region_source.word_0x14 = 2U;
		region_source.word_0x18_known = true;
		region_source.word_0x18 = 0U;
		const auto region_result = aurelion::h3maped_rmg_core::connection_region_writer_4a606b(region_grid, 1, 1, 0, 0x0a);
		if (!require(region_result.rectangle_scan_count == 9 && region_result.packed_stamp_count == 9 && region_result.candidate_bit_set_count == 9, "0x4a606b did not stamp the clipped 3x3 empty-object-reference rectangle")) {
			return 1;
		}
		if (!require(region_result.source_projection_target_in_bounds && region_result.projected_target_low_bits_cleared_count == 1 && region_result.projected_target_occupied_set_count == 1, "0x4a606b did not clear/stamp the projected target cell")) {
			return 1;
		}
		const GeneratedCellRecord0x30 &region_target = region_grid.records[size_t(aurelion::h3maped_rmg_core::cell_index(4, 4, 2, 2, 0))];
		if (!require((region_target.word_0x2c & 0x1fU) == 0U && (region_target.word_0x28 & aurelion::h3maped_rmg_core::CELL_OCCUPIED_BLOCKED_BIT_27) != 0U, "0x4a606b projected target did not clear low +0x2c bits and set bit27")) {
			return 1;
		}

		GeneratedCellRecordGrid0x30 chain_grid = aurelion::h3maped_rmg_core::generated_cell_record_grid_reset_0x49a072(4, 4, 1);
		for (GeneratedCellRecord0x30 &chain_record : chain_grid.records) {
			chain_record.byte_0x2b_known_mask = 0x04U;
			chain_record.byte_0x2b = 0x04U;
		}
		GeneratedCellRecord0x30 &chain_start = chain_grid.records[size_t(aurelion::h3maped_rmg_core::cell_index(4, 4, 1, 1, 0))];
		chain_start.word_0x1c = 0x00000002U;
		chain_start.word_0x10_known = true;
		chain_start.word_0x10 = 2U;
		chain_start.word_0x14_known = true;
		chain_start.word_0x14 = 1U;
		chain_start.word_0x18_known = true;
		chain_start.word_0x18 = 0U;
		chain_start.word_0x28 |= aurelion::h3maped_rmg_core::CELL_DECOR_CANDIDATE_BIT_26;
		GeneratedCellRecord0x30 &chain_stop = chain_grid.records[size_t(aurelion::h3maped_rmg_core::cell_index(4, 4, 2, 1, 0))];
		chain_stop.word_0x1c = 0U;
		const auto chain_result = aurelion::h3maped_rmg_core::projected_cell_chain_no_object_4a5a23(chain_grid, 1, 1, 0, false);
		if (!require(chain_result.start_cell_in_bounds && chain_result.visited_cell_count == 1 && chain_result.occupied_stamp_count == 1 && chain_result.stopped_on_low_word_zero, "0x4a5a23 no-object projection chain did not stamp the start cell then stop on low-word zero")) {
			return 1;
		}
		if (!require(chain_result.cleanup_scan_count == 9 && chain_result.cleanup_owner_match_count == 9 && chain_result.cleanup_bit_0x04_clear_count == 9, "0x4a5a23 cleanup did not clear nearby same-owner +0x2b bit0x04")) {
			return 1;
		}
		if (!require((chain_start.word_0x28 & aurelion::h3maped_rmg_core::CELL_OCCUPIED_BLOCKED_BIT_27) != 0U && (chain_start.word_0x28 & aurelion::h3maped_rmg_core::CELL_DECOR_CANDIDATE_BIT_26) == 0U, "0x4a5a23 no-object branch did not set bit27 and clear bit26")) {
			return 1;
		}

		GeneratedCellRecordGrid0x30 chain_object_grid = aurelion::h3maped_rmg_core::generated_cell_record_grid_reset_0x49a072(2, 2, 1);
		GeneratedCellRecord0x30 &chain_object_start = chain_object_grid.records[0];
		chain_object_start.word_0x1c = 0x00000002U;
		chain_object_start.word_0x2c = 0x01U;
		const auto chain_object_result = aurelion::h3maped_rmg_core::projected_cell_chain_no_object_4a5a23(chain_object_grid, 0, 0, 0, false);
		if (!require(chain_object_result.stopped_on_object_materialization_required && chain_object_result.occupied_stamp_count == 0, "0x4a5a23 must stop instead of guessing the +0x2c bit0 object-materialization branch")) {
			return 1;
		}

		EndpointMaterializationState4a5e73 endpoint_state;
		endpoint_state.endpoint_vector_d8_dc = { EndpointPointerRecord4a5e73 { 2 }, EndpointPointerRecord4a5e73 { 4 } };
		endpoint_state.byte_state_vector_1104_1108 = { 1U, 1U, 0U, 1U, 0U };
		endpoint_state.cursor_0xf5c = 7;
		EndpointMaterializationResult4a5e73 endpoint_result =
				aurelion::h3maped_rmg_core::endpoint_materialization_4a5e73(record_grid, endpoint_state, 0, 0, 0, 1);
		if (!require(endpoint_result.return_value == -1 && !endpoint_result.d8_match_found, "0x4a5e73 did not reject stale +0xf5c without a +0xd8 key match")) {
			return 1;
		}
		endpoint_state.cursor_0xf5c = 2;
		endpoint_result = aurelion::h3maped_rmg_core::endpoint_materialization_4a5e73(record_grid, endpoint_state, 0, 0, 0, 1);
		if (!require(endpoint_result.return_value == 0 && endpoint_result.d8_match_found && !endpoint_result.c8_match_found, "0x4a5e73 did not return 0 for a +0xd8 match without a +0xc8 key match")) {
			return 1;
		}
		endpoint_state.endpoint_vector_c8_cc = { EndpointPointerRecord4a5e73 { 2 } };
		endpoint_state.cursor_0xf5c = 2;
		record_grid.records[0].word_0x28 |= aurelion::h3maped_rmg_core::CELL_DECOR_CANDIDATE_BIT_26;
		record_grid.records[0].word_0x2c = 0x3fU;
		record_grid.records[1].word_0x28 |= aurelion::h3maped_rmg_core::CELL_DECOR_CANDIDATE_BIT_26;
		record_grid.records[1].word_0x2c = 0x3fU;
		endpoint_result = aurelion::h3maped_rmg_core::endpoint_materialization_4a5e73(record_grid, endpoint_state, 0, 0, 0, 2);
		if (!require(endpoint_result.return_value == 2 && endpoint_result.c8_match_found && endpoint_result.byte_state_marked, "0x4a5e73 success path did not return the original +0xf5c key and mark byte state")) {
			return 1;
		}
		if (!require(endpoint_result.mutated_cell_count == 2 && (record_grid.records[0].word_0x2c & 0x1fU) == 0U && (record_grid.records[1].word_0x2c & 0x1fU) == 0U, "0x4a5e73 success path did not clear low five +0x2c bits for repeated cells")) {
			return 1;
		}
		if (!require((record_grid.records[0].word_0x28 & aurelion::h3maped_rmg_core::CELL_OCCUPIED_BLOCKED_BIT_27) != 0U
					&& (record_grid.records[0].word_0x28 & aurelion::h3maped_rmg_core::CELL_DECOR_CANDIDATE_BIT_26) == 0U
					&& (record_grid.records[1].word_0x28 & aurelion::h3maped_rmg_core::CELL_OCCUPIED_BLOCKED_BIT_27) != 0U
					&& (record_grid.records[1].word_0x28 & aurelion::h3maped_rmg_core::CELL_DECOR_CANDIDATE_BIT_26) == 0U,
				"0x4a5e73 success path did not set +0x28 bit27 and clear bit26")) {
			return 1;
		}
		if (!require(endpoint_state.byte_state_vector_1104_1108[2] == 1U && endpoint_state.cursor_0xf5c == 4 && endpoint_result.cursor_advanced_count == 4, "0x4a5e73 success path did not advance +0xf5c through marked byte-state entries")) {
			return 1;
		}
	}

	{
		const std::vector<BoundarySourceCycleHandoff4a2777> handoffs { square_handoff(true) };
		const auto cycles = aurelion::h3maped_rmg_core::boundary_cycles_from_source_handoffs_4a2777(handoffs);
		if (!require(cycles.size() == 1, "expected one converted boundary cycle")) {
			return 1;
		}
		if (!require(cycles[0].cycle_nodes.size() == 4, "expected four converted cycle nodes")) {
			return 1;
		}
		if (!require(cycles[0].cycle_nodes[0].next_pair_has_payload, "source next-pair payload flag was not preserved")) {
			return 1;
		}
		if (!require(cycles[0].cycle_nodes[0].next_pair_payload == 1, "source next-pair payload value was not preserved")) {
			return 1;
		}
		if (!require(cycles[0].cycle_nodes[0].model_node_index == handoffs[0].source_nodes[0].model_node_index, "source descriptor model index was not preserved")) {
			return 1;
		}
		if (!require(cycles[0].cycle_nodes[0].pair_index == handoffs[0].source_nodes[0].pair_index, "source descriptor pair index was not preserved")) {
			return 1;
		}
		if (!require(cycles[0].cycle_nodes[0].next_index == handoffs[0].source_nodes[0].next_index, "source descriptor next index was not preserved")) {
			return 1;
		}
		if (!require(cycles[0].cycle_nodes[0].previous_index == handoffs[0].source_nodes[0].previous_index, "source descriptor previous index was not preserved")) {
			return 1;
		}
		if (!require(cycles[0].cycle_nodes[0].next_pair_index == handoffs[0].source_nodes[0].next_pair_index, "source descriptor next-pair index was not preserved")) {
			return 1;
		}
		if (!require(cycles[0].cycle_nodes[0].raw_x_0x00 == handoffs[0].source_nodes[0].raw_x_0x00 && cycles[0].cycle_nodes[0].raw_y_0x04 == handoffs[0].source_nodes[0].raw_y_0x04, "source raw coordinates were not preserved")) {
			return 1;
		}
		if (!require(cycles[0].cycle_nodes[0].finalized_x_0x1c == handoffs[0].source_nodes[0].finalized_x_0x1c && cycles[0].cycle_nodes[0].finalized_y_0x20 == handoffs[0].source_nodes[0].finalized_y_0x20, "source finalized coordinates were not preserved")) {
			return 1;
		}
		if (!require(cycles[0].has_span_seed_4a325d, "source-record +0x10 seed was not converted into the 0x4a325d span seed")) {
			return 1;
		}
		if (!require(cycles[0].source_record_vector_index_4a3e9c == 0, "source-record vector index was not preserved into the boundary cycle")) {
			return 1;
		}
	}

	const BoundaryMaterialization4a2777 ungated = aurelion::h3maped_rmg_core::materialize_boundary_source_handoffs_4a2777_4a325d(
			8,
			8,
			1,
			0,
			1234U,
			{ square_handoff(false) });
	const BoundaryMaterialization4a2777 gated = aurelion::h3maped_rmg_core::materialize_boundary_source_handoffs_4a2777_4a325d(
			8,
			8,
			1,
			0,
			1234U,
			{ square_handoff(true) });

	if (!require(ungated.owner_gate_skipped_segment_count == 0, "ungated handoff unexpectedly skipped owner-gated segments")) {
		return 1;
	}
	if (!require(gated.owner_gate_skipped_segment_count > 0, "gated handoff did not skip any owner-gated segment")) {
		return 1;
	}
	if (!require(gated.connector_segment_count < ungated.connector_segment_count, "owner gate did not reduce connector segment writes")) {
		return 1;
	}
	if (!require(gated.source_handoff_count == 1 && gated.source_handoff_point_count == 4, "source handoff counters were not preserved")) {
		return 1;
	}
	if (!require(gated.source_handoff_descriptor_indexed_point_count == 4, "source handoff descriptor index counters were not preserved")) {
		return 1;
	}
	if (!require(gated.source_handoff_raw_coordinate_point_count == 4, "source handoff raw-coordinate counters were not preserved")) {
		return 1;
	}
	if (!require(gated.source_handoff_source_record_seed_count == 1 && gated.source_handoff_missing_source_record_seed_count == 0, "source-record seed counters were not preserved")) {
		return 1;
	}
	if (!require(gated.span_fill_zone_count == 1, "gated handoff should still execute span fill from source-record +0x10 seed")) {
		return 1;
	}
	BoundarySourceCycleHandoff4a2777 missing_seed = square_handoff(false);
	missing_seed.has_source_record_seed_0x10 = false;
	const BoundaryMaterialization4a2777 missing_seed_result = aurelion::h3maped_rmg_core::materialize_boundary_source_handoffs_4a2777_4a325d(
			8,
			8,
			1,
			0,
			1234U,
			{ missing_seed });
	if (!require(missing_seed_result.source_handoff_missing_source_record_seed_count == 1, "missing source-record seed was not reported")) {
		return 1;
	}
	if (!require(missing_seed_result.span_fill_zone_count == 0, "missing source-record seed must not be replaced by a reconstructed span seed")) {
		return 1;
	}

	const std::vector<RuntimeZoneFootprintInput4a3a03> runtime_zones = {
		RuntimeZoneFootprintInput4a3a03 { 0, 1, 8, 8, 0 },
		RuntimeZoneFootprintInput4a3a03 { 1, 2, 20, 8, 0 },
		RuntimeZoneFootprintInput4a3a03 { 2, 3, 20, 20, 0 },
		RuntimeZoneFootprintInput4a3a03 { 3, 4, 8, 20, 0 },
	};
	const SourceNodeFootprintResult4a3a03 footprint = aurelion::h3maped_rmg_core::build_source_node_footprints_4a3a03_4ccb64_4cca55(runtime_zones);
	if (!require(!footprint.blocked, "source-node footprint producer unexpectedly blocked")) {
		return 1;
	}
	if (!require(footprint.executed_split_count == 4, "source-node footprint producer did not split all surface runtime zones")) {
		return 1;
	}
	if (!require(footprint.source_descriptor_node_count > 0 && footprint.source_descriptor_finalized_node_count > 0, "source descriptor table was not materialized")) {
		return 1;
	}
	if (!require(footprint.walks.size() == 4, "source-node footprint producer did not emit one walk per surface runtime zone")) {
		return 1;
	}
	if (!require(footprint.walks[0].locator_node_index >= 0 && !footprint.walks[0].source_nodes.empty(), "source descriptor walk was not materialized")) {
		return 1;
	}
	if (!require(footprint.walks[0].source_nodes[0].model_node_index >= 0 && footprint.walks[0].source_nodes[0].next_pair_index >= 0, "source walk lost descriptor link indexes")) {
		return 1;
	}

	BoundarySourceCycleHandoff4a2777 produced_handoff;
	produced_handoff.runtime_zone_index = footprint.walks[0].runtime_zone_index;
	produced_handoff.zone_word = 0;
	produced_handoff.level = 0;
	produced_handoff.random_span_limit = 1;
	produced_handoff.source_record_vector_index_4a3e9c = 0;
	produced_handoff.has_source_record_seed_0x10 = true;
	produced_handoff.source_record_seed_0x10 = SpanRecord { runtime_zones[0].x_after_bbox_rescale, runtime_zones[0].y_after_bbox_rescale, 0 };
	produced_handoff.source_nodes = footprint.walks[0].source_nodes;
	const BoundaryMaterialization4a2777 produced = aurelion::h3maped_rmg_core::materialize_boundary_source_handoffs_4a2777_4a325d(
			36,
			36,
			1,
			0,
			1234U,
			{ produced_handoff });
	if (!require(produced.source_handoff_count == 1, "producer handoff was not consumed by boundary materializer")) {
		return 1;
	}
	if (!require(produced.source_handoff_point_count == int32_t(footprint.walks[0].source_nodes.size()), "producer handoff point count changed during materialization")) {
		return 1;
	}
	if (!require(produced.source_handoff_descriptor_indexed_point_count > 0, "producer handoff descriptor indexes were not preserved into materialization")) {
		return 1;
	}
	if (!require(produced.span_fill_zone_count == 1, "producer handoff did not preserve span fill seed")) {
		return 1;
	}

	const std::vector<RuntimeZoneBoundaryInput4a3a03> boundary_inputs = {
		RuntimeZoneBoundaryInput4a3a03 { runtime_zones[0], 0, 1, 0, true, SpanRecord { 8, 8, 0 } },
		RuntimeZoneBoundaryInput4a3a03 { runtime_zones[1], 1, 1, 1, true, SpanRecord { 20, 8, 0 } },
		RuntimeZoneBoundaryInput4a3a03 { runtime_zones[2], 2, 1, 2, true, SpanRecord { 20, 20, 0 } },
		RuntimeZoneBoundaryInput4a3a03 { runtime_zones[3], 3, 1, 3, true, SpanRecord { 8, 20, 0 } },
	};
	const BoundaryOwnerGridResult4a3a03 owner_grid = aurelion::h3maped_rmg_core::materialize_boundary_owner_grid_from_runtime_zone_footprints_4a3a03_4cca55_4a2777_4a325d_4a3710(
			36,
			36,
			1,
			aurelion::h3maped_rmg_core::water_mode_code("land"),
			0,
			1234U,
			boundary_inputs);
	if (!require(!owner_grid.source_blocked, "composed owner-grid chain blocked in source-node producer")) {
		return 1;
	}
	if (!require(owner_grid.materialization_executed, "composed owner-grid chain did not execute boundary materialization")) {
		return 1;
	}
	if (!require(owner_grid.footprint_finalizer_executed && !owner_grid.footprint_finalizer.blocked, "composed owner-grid chain did not execute the one-level land 0x4a3710 finalizer")) {
		return 1;
	}
	if (!require(owner_grid.handoffs.size() == 4, "composed owner-grid chain did not build one handoff per source walk")) {
		return 1;
	}
	if (!require(owner_grid.missing_boundary_input_count == 0 && owner_grid.missing_source_walk_count == 0, "composed owner-grid chain lost source/boundary handoff inputs")) {
		return 1;
	}
	if (!require(owner_grid.materialization.source_handoff_count == 4, "composed owner-grid materializer did not consume all source handoffs")) {
		return 1;
	}
	if (!require(owner_grid.materialization.source_handoff_source_record_seed_count == 4 && owner_grid.materialization.source_handoff_missing_source_record_seed_count == 0, "composed owner-grid materializer did not consume source-record seeds")) {
		return 1;
	}
	if (!require(owner_grid.materialization.span_fill_zone_count == 4, "composed owner-grid materializer did not span-fill all seeded zones")) {
		return 1;
	}
	if (!require(!owner_grid.materialization.generated_cell_word_0x20.empty(), "composed owner-grid materializer did not produce generated-cell owner words")) {
		return 1;
	}
	std::vector<RuntimeZoneBoundaryInput4a3a03> terrain_inputs = boundary_inputs;
	terrain_inputs[0].terrain_match_to_town_0x84 = true;
	terrain_inputs[0].selected_town_choice_index_0x49b3c1 = 2;
	terrain_inputs[1].allowed_terrain_mask_0x85_0x8c = uint16_t(1U << 5U);
	terrain_inputs[2].allowed_terrain_mask_0x85_0x8c = 0U;
	terrain_inputs[3].allowed_terrain_mask_0x85_0x8c = uint16_t(1U << 6U);
	RuntimeTerrainSelectionResult49b53d terrain_selection = aurelion::h3maped_rmg_core::runtime_terrain_selection_49b53d(1234U, terrain_inputs);
	if (!require(terrain_selection.records.size() == terrain_inputs.size(), "0x49b53d did not emit one terrain record per runtime zone")) {
		return 1;
	}
	if (!require(terrain_selection.records[0].selected_terrain_id_0x49b53d == 3, "0x49b53d match-to-town table did not select tower snow terrain")) {
		return 1;
	}
	if (!require(terrain_selection.records[1].selected_terrain_id_0x49b53d == 5, "0x49b53d allowed terrain mask did not select the only eligible rough terrain")) {
		return 1;
	}
	if (!require(terrain_selection.records[2].selected_terrain_id_0x49b53d == 0 && terrain_selection.no_eligible_default_zero_count == 2, "0x49b53d no-eligible terrain path did not default to zero")) {
		return 1;
	}
	if (!require(terrain_selection.records[3].selected_terrain_id_0x49b53d == 0, "0x49b53d cave terrain must not be eligible on level 0")) {
		return 1;
	}
	if (!require(terrain_selection.match_to_town_count == 1 && terrain_selection.allowed_flag_choice_count == 1 && terrain_selection.rng_call_count == 1, "0x49b53d terrain source/RNG counters mismatch")) {
		return 1;
	}
	TerrainRepaintResult4a3f27 terrain_repaint = aurelion::h3maped_rmg_core::terrain_repaint_4a3f27(
			36,
			36,
			1,
			owner_grid.materialization,
			terrain_selection);
	if (!require(terrain_repaint.executed, "0x4a3f27 terrain repaint did not execute")) {
		return 1;
	}
	if (!require(terrain_repaint.full_map_water_repaint_count_0x4a4025 == 36 * 36, "0x4a3f27 did not apply full-map water repaint")) {
		return 1;
	}
	if (!require(terrain_repaint.zone_repaint_write_count_0x4a4163 > 0, "0x4a3f27 did not repaint any owner/member-gated terrain cells")) {
		return 1;
	}
	if (!require(!terrain_repaint.generated_cell_word_0x24.empty() && !terrain_repaint.generated_cell_word_0x28.empty(), "0x4a3f27 did not produce terrain generated-cell words")) {
		return 1;
	}
	if (!require(terrain_repaint.terrain_visual_initial_water_write_count_0x4a4025 == 36 * 36, "TerrainPlacement did not write visual rows for the full-map water prefill")) {
		return 1;
	}
	if (!require(terrain_repaint.terrain_visual_write_count_0x4bb74b > terrain_repaint.full_map_water_repaint_count_0x4a4025, "TerrainPlacement did not write post-water visual feedback")) {
		return 1;
	}
	if (!require(terrain_repaint.terrain_visual_final_sweep_cell_count_0x4bbfcc == 36 * 36, "TerrainPlacement final sweep did not revisit the full grid")) {
		return 1;
	}
	if (!require(terrain_repaint.terrain_visual_missing_bucket_count_0x4bcfc3 == 0, "TerrainPlacement visual selector hit a missing recovered row bucket")) {
		return 1;
	}
	if (!require(terrain_repaint.terrain_visual_roundtrip_mismatch_count == 0 && terrain_repaint.terrain_visual_terrain_mismatch_count == 0, "TerrainPlacement scratch/generated-cell roundtrip mismatch")) {
		return 1;
	}
	if (!require(terrain_repaint.terrain_visual_art_nonzero_cell_count > 0, "TerrainPlacement left all art rows at zero")) {
		return 1;
	}
	if (!require(terrain_repaint.terrain_visual_rng_state_after_0x4bb74b != terrain_repaint.terrain_visual_rng_state_before_0x4bb74b, "TerrainPlacement visual selector did not consume RNG")) {
		return 1;
	}

	const auto player_assignment = aurelion::h3maped_rmg_core::player_slot_assignment_4ac62a_4ac6ec(
			1,
			3,
			0b00000001U,
			0b00000111U,
			0xffU);
	if (!require(player_assignment.complete, "player slot assignment did not satisfy requested players")) {
		return 1;
	}
	if (!require(player_assignment.assigned_player_count == 3, "player slot assignment count mismatch")) {
		return 1;
	}
	if (!require(player_assignment.mapped_ee4_slots[0] == 0 && player_assignment.mapped_ee4_slots[1] == 1 && player_assignment.mapped_ee4_slots[2] == 2, "player slot assignment did not map source owners to colors")) {
		return 1;
	}

	std::vector<TemplateZoneRecord4a218c> template_zones = {
		TemplateZoneRecord4a218c { 1, 0, 0, 0, 0, 8 },
		TemplateZoneRecord4a218c { 2, 1, 1, 1, 1, 7 },
		TemplateZoneRecord4a218c { 3, 2, 2, 2, 2, 7 },
		TemplateZoneRecord4a218c { 4, 3, 3, 2, -1, 6 },
		TemplateZoneRecord4a218c { 5, 4, 4, 3, -1, 5, 4, 8, 4, 8 },
	};
	template_zones[0].source_payload.source_row = 700;
	template_zones[0].source_payload.source_type_code = 1;
	template_zones[0].source_payload.player_towns.min_castles = 2;
	template_zones[0].source_payload.mines.minimum_wood = 1;
	template_zones[0].source_payload.treasure_band_0 = aurelion::h3maped_rmg_core::SourceTreasureBand4a218c { 9, 500, 3000 };
	const std::vector<TemplateLinkRecord4a1f3b> template_links = {
		TemplateLinkRecord4a1f3b { 1, 2, 1200, false, false, 0, 8, 0, 8, 101, 102 },
		TemplateLinkRecord4a1f3b { 2, 3, 2400, true, false, 0, 8, 0, 8, 201, 202 },
		TemplateLinkRecord4a1f3b { 3, 4, 3600, false, true, 0, 8, 0, 8, 301, 302 },
		TemplateLinkRecord4a1f3b { 4, 5, 4800, true, true },
		TemplateLinkRecord4a1f3b { 1, 5, 0, false, false, 4, 8, 4, 8 },
	};
	const RuntimeSeedBuildResult4a218c template_seed_result = aurelion::h3maped_rmg_core::runtime_seed_inputs_from_template_records_4a218c_4a1f3b(
			template_zones,
			template_links,
			player_assignment,
			1,
			3);
	if (!require(!template_seed_result.blocked, "template seed producer blocked despite complete player assignment")) {
		return 1;
	}
	if (!require(template_seed_result.runtime_zone_seeds.size() == 4, "template seed producer did not filter zones into runtime seeds")) {
		return 1;
	}
	if (!require(template_seed_result.runtime_links.size() == 3, "template seed producer did not emit expected endpoint links")) {
		return 1;
	}
	if (!require(template_seed_result.runtime_links[0].guard_value == 1200
				&& !template_seed_result.runtime_links[0].wide
				&& !template_seed_result.runtime_links[0].border_guard
				&& template_seed_result.runtime_links[0].source_zone_a == 1
				&& template_seed_result.runtime_links[0].source_zone_b == 2
				&& template_seed_result.runtime_links[0].source_endpoint_a == 101
				&& template_seed_result.runtime_links[0].source_endpoint_b == 102
				&& template_seed_result.runtime_links[1].guard_value == 2400
				&& template_seed_result.runtime_links[1].wide
				&& !template_seed_result.runtime_links[1].border_guard
				&& template_seed_result.runtime_links[1].source_endpoint_a == 201
				&& template_seed_result.runtime_links[1].source_endpoint_b == 202
				&& template_seed_result.runtime_links[2].guard_value == 3600
				&& !template_seed_result.runtime_links[2].wide
				&& template_seed_result.runtime_links[2].border_guard
				&& template_seed_result.runtime_links[2].source_endpoint_a == 301
				&& template_seed_result.runtime_links[2].source_endpoint_b == 302,
				"template seed producer did not preserve link guard/wide/border-guard/source-endpoint payloads")) {
		return 1;
	}
	if (!require(template_seed_result.skipped_zone_filter_count == 1 && template_seed_result.skipped_link_filter_count == 1, "template seed producer did not report player-filter exclusions")) {
		return 1;
	}
	if (!require(template_seed_result.missing_link_endpoint_count == 1, "template seed producer did not report missing filtered endpoint")) {
		return 1;
	}
	if (!require(template_seed_result.runtime_zone_seeds[0].actual_player_color == 0 && template_seed_result.runtime_zone_seeds[3].actual_player_color == -1, "template seed producer lost owner-color mapping")) {
		return 1;
	}
	if (!require(template_seed_result.runtime_zone_seeds[3].source_index == 3, "filtered template seed producer lost original source-record index")) {
		return 1;
	}
	if (!require(template_seed_result.runtime_zone_seeds[0].source_payload.source_row == 700
				&& template_seed_result.runtime_zone_seeds[0].source_payload.player_towns.min_castles == 2
				&& template_seed_result.runtime_zone_seeds[0].source_payload.mines.minimum_wood == 1
				&& template_seed_result.runtime_zone_seeds[0].source_payload.treasure_band_0.high == 3000,
				"template seed producer did not preserve source-zone payload fields")) {
		return 1;
	}

	struct ExpectedSmallSelection {
		uint32_t seed;
		int32_t rng_value;
		int32_t selected_vector_index;
		int32_t source_catalog_index;
		const char *template_name;
	};
	const std::vector<ExpectedSmallSelection> expected_small_selections = {
		ExpectedSmallSelection { 3U, 48, 6, 17, "2SM2f" },
		ExpectedSmallSelection { 11U, 74, 11, 22, "2SM2i(2)" },
		ExpectedSmallSelection { 28U, 130, 4, 13, "2SM2c" },
		ExpectedSmallSelection { 73U, 277, 4, 13, "2SM2c" },
	};
	for (const ExpectedSmallSelection &expected : expected_small_selections) {
		const TemplateSelectionRuntimeResult4ac552 selected = aurelion::h3maped_rmg_core::template_selection_and_runtime_seed_inputs_4ac552_4a218c_4a1f3b(
				expected.seed,
				1,
				2,
				2);
		if (!require(!selected.blocked, "recovered Small template catalog selection unexpectedly blocked")) {
			return 1;
		}
		if (!require(selected.accepted_template_count == 21, "recovered Small template catalog accepted count mismatch")) {
			return 1;
		}
		if (!require(selected.rng_value == expected.rng_value, "recovered Small template catalog RNG value mismatch")) {
			return 1;
		}
		if (!require(selected.selected_vector_index == expected.selected_vector_index, "recovered Small template catalog selected vector index mismatch")) {
			return 1;
		}
		if (!require(selected.selected_source_catalog_index == expected.source_catalog_index, "recovered Small template catalog source index mismatch")) {
			return 1;
		}
		if (!require(selected.selected_template_name == expected.template_name, "recovered Small template catalog name mismatch")) {
			return 1;
		}
		if (!require(selected.player_assignment.complete && !selected.runtime_seed.runtime_zone_seeds.empty(), "recovered Small template catalog did not feed runtime seed inputs")) {
			return 1;
		}
		if (!require(selected.runtime_seed.runtime_zone_seeds[0].source_payload.source_row > 0, "recovered Small template catalog did not preserve source-zone row payload")) {
			return 1;
		}
	}

	const GeneratorSetupModeResult49ecf2 setup0 = aurelion::h3maped_rmg_core::generator_setup_mode_49ecf2(10U, 0);
	if (!require(!setup0.randomized_setup_sentinel_3 && setup0.generator_mode_0x10b8 == 0 && setup0.rng_state_before_template_selection == 10U, "0x49ecf2 setup mode 0 must not consume RNG before template selection")) {
		return 1;
	}
	const GeneratorSetupModeResult49ecf2 setup3 = aurelion::h3maped_rmg_core::generator_setup_mode_49ecf2(10U, 3);
	if (!require(setup3.randomized_setup_sentinel_3 && setup3.setup_rng_value == 71 && setup3.generator_mode_0x10b8 == 2 && setup3.setup_rng_call_count == 1, "0x49ecf2 setup sentinel 3 must randomize generator mode with rand % 3")) {
		return 1;
	}
	if (!require(setup3.rng_state_before_template_selection == 0x004746a5U, "0x49ecf2 setup sentinel 3 did not hand off post-setup RNG state")) {
		return 1;
	}
	const TemplateSelectionRuntimeResult4ac552 selected_after_setup3 = aurelion::h3maped_rmg_core::template_selection_and_runtime_seed_inputs_4ac552_4a218c_4a1f3b(
			setup3.rng_state_before_template_selection,
			1,
			2,
			2);
	if (!require(selected_after_setup3.rng_value == 16899, "template selection must consume RNG after setup sentinel randomization")) {
		return 1;
	}

	const int32_t medium_size_score = aurelion::h3maped_rmg_core::size_score(72, 72, 1, aurelion::h3maped_rmg_core::water_mode_code("land"));
	const TemplateSelectionRuntimeResult4ac552 medium_selection = aurelion::h3maped_rmg_core::template_selection_and_runtime_seed_inputs_4ac552_4a218c_4a1f3b(
			10U,
			medium_size_score,
			1,
			2);
	if (!require(medium_size_score == 4, "Medium one-level land size score changed unexpectedly")) {
		return 1;
	}
	if (!require(!medium_selection.blocked, "recovered Medium template catalog selection unexpectedly blocked")) {
		return 1;
	}
	if (!require(medium_selection.accepted_template_count > 0 && !medium_selection.runtime_seed.runtime_zone_seeds.empty(), "recovered Medium template catalog did not feed runtime seed inputs")) {
		return 1;
	}
	const TemplateSelectionRuntimeResult4ac552 medium_hc4_setup0_selection = aurelion::h3maped_rmg_core::template_selection_and_runtime_seed_inputs_4ac552_4a218c_4a1f3b(
			10U,
			medium_size_score,
			4,
			4);
	if (!require(medium_hc4_setup0_selection.accepted_template_count == 23, "recovered Medium seed-10 hc4 accepted count mismatch")) {
		return 1;
	}
	if (!require(medium_hc4_setup0_selection.rng_value == 71, "recovered Medium seed-10 hc4 RNG value mismatch")) {
		return 1;
	}
	if (!require(medium_hc4_setup0_selection.selected_vector_index == 2, "recovered Medium seed-10 hc4 selected vector index mismatch")) {
		return 1;
	}
	if (!require(medium_hc4_setup0_selection.selected_source_catalog_index == 15, "recovered Medium seed-10 hc4 source catalog index mismatch")) {
		return 1;
	}
	if (!require(medium_hc4_setup0_selection.selected_template_name == "2SM4d(2)", "recovered Medium seed-10 hc4 template name mismatch")) {
		return 1;
	}
		if (!require(medium_hc4_setup0_selection.player_assignment.complete && medium_hc4_setup0_selection.runtime_seed.runtime_zone_seeds.size() == 10, "recovered Medium seed-10 hc4 did not feed ten runtime zones")) {
			return 1;
		}

		const std::vector<RuntimeZoneSeedInput4a218c> &seed_inputs = template_seed_result.runtime_zone_seeds;
	const std::vector<RuntimeLinkSeedInput4a218c> &links = template_seed_result.runtime_links;
	int32_t minimum_source_base_size = 0x7fffffff;
	for (const RuntimeZoneSeedInput4a218c &seed_input : seed_inputs) {
		if (seed_input.source_base_size > 0) {
			minimum_source_base_size = std::min(minimum_source_base_size, seed_input.source_base_size);
		}
	}
	if (!require(minimum_source_base_size != 0x7fffffff, "template-record seed inputs lost source base sizes")) {
		return 1;
	}
	const CoordinateOwnerGridResult4a218c composed = aurelion::h3maped_rmg_core::coordinate_seed_and_materialize_owner_grid_4a218c_4a1f3b_4a19ed_4a3a03_4cca55_4a2777_4a325d_4a3710(
			36,
			36,
			1,
			aurelion::h3maped_rmg_core::water_mode_code("land"),
			0,
			1234U,
			seed_inputs,
			links);
	if (!require(!composed.coordinate_seed_blocked, "coordinate seed blocked in recovered-order composed chain")) {
		return 1;
	}
	if (!require(composed.coordinate_seed.generator_mode_0x10b8 == 0, "coordinate seed did not preserve generator mode 0x10b8")) {
		return 1;
	}
	if (!require(composed.coordinate_seed.minimum_source_base_size == minimum_source_base_size, "coordinate seed did not preserve minimum source base size for 0x4a218c pruning")) {
		return 1;
	}
	if (!require(composed.coordinate_seed.coordinate_prune_divisor_4a218c == 5, "0x4a218c generator mode 0 must use coordinate prune divisor 5")) {
		return 1;
	}
	if (!require(composed.coordinate_seed.coordinate_prune_span_budget_4a218c == (minimum_source_base_size * 36) / 5, "0x4a218c mode 0 coordinate prune span budget mismatch")) {
		return 1;
	}
	if (!require(composed.coordinate_seed.boundary_inputs.size() == seed_inputs.size(), "coordinate seed did not emit one boundary input per runtime-zone seed")) {
		return 1;
	}
	if (!require(composed.coordinate_seed.boundary_inputs[3].source_record_vector_index_4a3e9c == seed_inputs[3].source_index, "coordinate seed rewrote source-record vector index to compacted runtime position")) {
		return 1;
	}
	if (!require(composed.coordinate_seed.rng_state_after != composed.coordinate_seed.rng_state_before, "coordinate seed did not advance recovered RNG state")) {
		return 1;
	}
	if (!require(composed.owner_grid_executed, "coordinate-to-owner-grid chain did not execute owner-grid materialization")) {
		return 1;
	}
	if (!require(composed.owner_grid.handoffs.size() == seed_inputs.size(), "coordinate-to-owner-grid chain did not materialize one source handoff per zone")) {
		return 1;
	}
	if (!require(composed.owner_grid.materialization.rng_state_before == composed.coordinate_seed.rng_state_after, "owner-grid phase did not consume coordinate seed output RNG state")) {
		return 1;
	}
	if (!require(composed.terrain_selection_executed && composed.terrain_repaint_executed, "composed chain did not execute 0x49b53d terrain selection and 0x4a3f27 terrain repaint")) {
		return 1;
	}
	if (!require(composed.terrain_repaint.full_map_water_repaint_count_0x4a4025 == 36 * 36, "composed chain did not apply terrain full-map repaint")) {
		return 1;
	}
	const CoordinateOwnerGridResult4a218c selected_composed = aurelion::h3maped_rmg_core::coordinate_seed_and_materialize_owner_grid_4a218c_4a1f3b_4a19ed_4a3a03_4cca55_4a2777_4a325d_4a3710(
			36,
			36,
			1,
			aurelion::h3maped_rmg_core::water_mode_code("land"),
			setup3.generator_mode_0x10b8,
			selected_after_setup3.rng_state_after_template_selection,
			selected_after_setup3.runtime_seed.runtime_zone_seeds,
			selected_after_setup3.runtime_seed.runtime_links);
	if (!require(!selected_composed.coordinate_seed_blocked, "selected-template coordinate chain blocked before generator private-state handoff")) {
		return 1;
	}
	const GeneratorObjectPrivateState generator_state =
			aurelion::h3maped_rmg_core::generator_object_private_state_from_recovered_partial_chain(
					36,
					36,
					1,
					selected_after_setup3,
					selected_composed);
	if (!require(generator_state.generated_cell_buffer_owned && generator_state.generated_cell_buffer.records.size() == 36U * 36U, "generator object private state did not own the generated-cell buffer at +0x14")) {
		return 1;
	}
	if (!require(generator_state.width == 36 && generator_state.height == 36 && generator_state.level_count == 1, "generator object private state did not preserve +0x18/+0x1c/+0x20 dimensions")) {
		return 1;
	}
	if (!require(generator_state.candidate_container_vector_10d4_10d8.count_known && generator_state.candidate_container_vector_10d4_10d8.count == selected_after_setup3.accepted_template_count, "generator object private state did not preserve accepted candidate vector count")) {
		return 1;
	}
	if (!require(generator_state.source_owner_player_slots_ed8_ee0_ee4_present && generator_state.selected_color_order_ed8_count == int32_t(selected_after_setup3.player_assignment.selected_color_order_ed8.size()), "generator object private state did not preserve source-owner/player-slot buffers")) {
		return 1;
	}
	if (!require(generator_state.object_record_vector_ec4_ecc.present && !generator_state.object_record_vector_ec4_ecc.contents_known, "generator object private state must keep object-vector contents unclaimed until materialization is ported")) {
		return 1;
	}
	if (!require(generator_state.relation_vector_10e4_10e8.present && !generator_state.relation_vector_10e4_10e8.contents_known && !generator_state.remaining_private_state_blockers.empty(), "generator object private state must keep relation/object blockers explicit")) {
		return 1;
	}
	if (!require(generator_state.relation_vector_10e4_10e8.count_known && generator_state.relation_vector_10e4_10e8.count == int32_t(selected_after_setup3.runtime_seed.runtime_zone_seeds.size()), "generator object private state did not preserve adopted relation-vector count")) {
		return 1;
	}
	if (!require(generator_state.relation_owner_records_10e4_10e8_partial_known, "generator object private state did not carry recovered 0x4a218c/0x49f7c4 relation owner records")) {
		return 1;
	}
	if (!require(generator_state.relation_owner_vector_count_10e4_10e8 == int32_t(selected_after_setup3.runtime_seed.runtime_zone_seeds.size()), "generator relation owner vector count does not match selected runtime zones")) {
		return 1;
	}
	if (!require(generator_state.relation_record_missing_endpoint_count_10e4_10e8 == 0, "generator relation owner records lost a selected runtime-link endpoint")) {
		return 1;
	}
	const int32_t expected_relation_record_count = int32_t(selected_after_setup3.runtime_seed.runtime_links.size()) * 2;
	if (!require(generator_state.relation_record_count_10e4_10e8 == expected_relation_record_count, "generator relation records did not mirror 0x49f7c4 reciprocal link append count")) {
		return 1;
	}
	int32_t summed_relation_record_count = 0;
	int32_t relation_owner_source_slot_known_count = 0;
	int32_t relation_owner_town_choice_known_count = 0;
	for (const aurelion::h3maped_rmg_core::GeneratorRelationOwnerState4a218c &owner : generator_state.relation_owner_vectors_10e4_10e8) {
		summed_relation_record_count += owner.relation_record_count;
		if (!require(owner.constructor_0x49b452_known, "generator relation owner did not carry recovered 0x49b452 constructor state")) {
			return 1;
		}
		if (!require(owner.source_pointer_0x00_known && owner.source_pointer_source_index_0x00 == owner.source_index, "0x49b452 relation owner source pointer/source index was not preserved")) {
			return 1;
		}
		if (!require(owner.scan_bounds_0x20_0x2c_known
						&& owner.scan_bound_low_x_0x20 == aurelion::h3maped_rmg_core::RELATION_OWNER_SCAN_BOUND_LOW_SENTINEL_0X49B452
						&& owner.scan_bound_low_y_0x24 == aurelion::h3maped_rmg_core::RELATION_OWNER_SCAN_BOUND_LOW_SENTINEL_0X49B452
						&& owner.scan_bound_high_x_0x28 == aurelion::h3maped_rmg_core::RELATION_OWNER_SCAN_BOUND_HIGH_SENTINEL_0X49B452
						&& owner.scan_bound_high_y_0x2c == aurelion::h3maped_rmg_core::RELATION_OWNER_SCAN_BOUND_HIGH_SENTINEL_0X49B452,
					"0x49b452 relation owner default scan bounds were not preserved")) {
			return 1;
		}
		if (!require(owner.byte_0x3c_known && owner.byte_0x3c == 0U, "0x49b452 relation owner byte +0x3c was not zeroed")) {
			return 1;
		}
		if (!require(owner.descriptor_type_counter_table_0x44_known
						&& owner.descriptor_type_counter_table_0x44_byte_size == aurelion::h3maped_rmg_core::RELATION_OWNER_DESCRIPTOR_TABLE_0X44_BYTE_SIZE
						&& owner.descriptor_type_counter_table_0x44_zero_count == aurelion::h3maped_rmg_core::RELATION_OWNER_DESCRIPTOR_TABLE_0X44_DWORD_COUNT,
					"0x49b452 relation owner descriptor table +0x44 was not zero-initialized")) {
			return 1;
		}
		if (!require(owner.owner_local_vectors_0x3e4_0x3f4_0x404_known
						&& owner.owner_local_vector_0x3e4_count == 0
						&& owner.owner_local_vector_0x3f4_count == 0
						&& owner.owner_local_vector_0x404_count == 0,
					"0x49b452 relation owner local vectors were not initialized empty")) {
			return 1;
		}
		const auto boundary_input = std::find_if(selected_composed.coordinate_seed.boundary_inputs.begin(), selected_composed.coordinate_seed.boundary_inputs.end(), [&](const RuntimeZoneBoundaryInput4a3a03 &input) {
			return input.footprint.runtime_zone_index == owner.runtime_zone_index;
		});
		if (!require(boundary_input != selected_composed.coordinate_seed.boundary_inputs.end(), "0x4a1f3b/0x4a19ed relation owner coordinate source was not found")) {
			return 1;
		}
		if (!require(owner.coordinate_triple_0x10_0x18_known
						&& owner.coordinate_x_0x10 == boundary_input->footprint.x_after_bbox_rescale
						&& owner.coordinate_y_0x14 == boundary_input->footprint.y_after_bbox_rescale
						&& owner.coordinate_level_0x18 == boundary_input->footprint.level,
					"0x4a1f3b/0x4a19ed relation owner coordinate triple +0x10..+0x18 was not preserved")) {
			return 1;
		}
		int32_t expected_source_endpoint_count = 0;
		for (const RuntimeLinkSeedInput4a218c &link : selected_after_setup3.runtime_seed.runtime_links) {
			if (link.from_index == owner.runtime_zone_index || link.to_index == owner.runtime_zone_index) {
				expected_source_endpoint_count += 1;
			}
		}
		if (!require(owner.source_endpoint_vector_0xc8_0xcc_present
						&& owner.source_endpoint_vector_0xc8_0xcc_contents_known
						&& owner.source_endpoint_vector_0xc8_0xcc_count_known
						&& owner.source_endpoint_vector_0xc8_0xcc_count == expected_source_endpoint_count
						&& int32_t(owner.source_endpoint_records_0xc8_0xcc.size()) == expected_source_endpoint_count
						&& owner.source_endpoint_vector_0xc8_0xcc_stride_bytes == 0x1c,
					"0x4a1f3b source-zone endpoint vector +0xc8/+0xcc contents were not preserved")) {
			return 1;
		}
		for (const GeneratorSourceEndpointRecordState4a1f3b &endpoint_record : owner.source_endpoint_records_0xc8_0xcc) {
			if (!require(endpoint_record.owner_runtime_zone_index == owner.runtime_zone_index
							&& endpoint_record.owner_source_zone_id == owner.source_zone_id
							&& endpoint_record.source_link_index >= 0
							&& endpoint_record.source_link_index < int32_t(selected_after_setup3.runtime_seed.runtime_links.size()),
						"0x4a1f3b source endpoint record did not preserve owner/link identity")) {
				return 1;
			}
			const RuntimeLinkSeedInput4a218c &runtime_link = selected_after_setup3.runtime_seed.runtime_links[size_t(endpoint_record.source_link_index)];
			if (!require(endpoint_record.guard_value == runtime_link.guard_value
							&& endpoint_record.wide == runtime_link.wide
							&& endpoint_record.border_guard == runtime_link.border_guard,
						"0x4a1f3b source endpoint record did not preserve selected link payload")) {
				return 1;
			}
		}
		int32_t expected_candidate_vector_step_count = 0;
		int32_t expected_candidate_after_prune_total_count = 0;
		for (const auto &step : selected_composed.coordinate_seed.placement_steps) {
			if (step.runtime_zone_index != owner.runtime_zone_index) {
				continue;
			}
			expected_candidate_vector_step_count += 1;
			expected_candidate_after_prune_total_count += int32_t(step.candidates_after_prune_4a1ad8.size());
		}
		if (!require(owner.coordinate_candidate_vectors_0x4a1f3b_known
						&& owner.coordinate_candidate_vector_step_count == expected_candidate_vector_step_count
						&& int32_t(owner.coordinate_candidate_vectors_0x4a1f3b.size()) == expected_candidate_vector_step_count
						&& owner.coordinate_candidate_after_prune_total_count == expected_candidate_after_prune_total_count,
					"0x4a1f3b relation owner coordinate candidate vectors were not preserved")) {
			return 1;
		}
		for (const GeneratorCoordinateCandidateVectorState4a1f3b &candidate_vector : owner.coordinate_candidate_vectors_0x4a1f3b) {
			if (!require(candidate_vector.runtime_zone_index == owner.runtime_zone_index
							&& candidate_vector.candidate_count_before_prune == int32_t(candidate_vector.candidates_before_prune_4a17f5.size())
							&& candidate_vector.candidate_count_after_prune == int32_t(candidate_vector.candidates_after_prune_4a1ad8.size()),
						"0x4a1f3b candidate vector count did not match preserved candidate contents")) {
				return 1;
			}
			if (!candidate_vector.blocked) {
				if (!require(candidate_vector.selected_candidate_known
								&& candidate_vector.selected_candidate_index >= 0
								&& candidate_vector.selected_candidate_index < int32_t(candidate_vector.candidates_after_prune_4a1ad8.size()),
							"0x4a1f3b candidate vector did not preserve selected candidate metadata")) {
					return 1;
				}
				const auto &selected = candidate_vector.candidates_after_prune_4a1ad8[size_t(candidate_vector.selected_candidate_index)];
				if (!require(candidate_vector.selected_candidate.x == selected.x
								&& candidate_vector.selected_candidate.y == selected.y
								&& candidate_vector.selected_candidate.level == selected.level,
							"0x4a1f3b selected candidate does not match preserved pruned candidate vector")) {
					return 1;
				}
			}
		}
		if (owner.source_owner_slot_0x1c_known) {
			relation_owner_source_slot_known_count += 1;
		}
		if (owner.town_choice_0x04_known) {
			relation_owner_town_choice_known_count += 1;
		}
		if (!require(owner.relation_record_count == int32_t(owner.relation_records.size()), "generator relation owner record count does not match owned record vector")) {
			return 1;
		}
	}
	if (!require(relation_owner_source_slot_known_count > 0, "0x49b452 relation owner source +0x08 to owner +0x1c slot was not carried for any owner")) {
		return 1;
	}
	if (!require(relation_owner_town_choice_known_count > 0, "0x49b452 relation owner town choice +0x04 was not carried from post-0x49b3c1 seed state")) {
		return 1;
	}
	if (!require(summed_relation_record_count == generator_state.relation_record_count_10e4_10e8, "generator relation record total does not equal sum of owner vectors")) {
		return 1;
	}
	if (!require(generator_state.relation_normalization_4a5767_full_grid_reset_applied, "generator object private state did not apply recovered 0x4a5767 full-grid reset")) {
		return 1;
	}
	if (!require(generator_state.relation_normalization_4a5767_full_grid_reset_visited_count == int32_t(generator_state.generated_cell_buffer.records.size()), "0x4a5767 full-grid reset did not visit every generated-cell record")) {
		return 1;
	}
	if (!require(generator_state.relation_normalization_4a5767_full_grid_reset_skipped_count == 0, "0x4a5767 full-grid reset skipped records with known word inputs")) {
		return 1;
	}
	if (!require(generator_state.relation_normalization_4a5767_full_grid_reset_changed_count == int32_t(generator_state.generated_cell_buffer.records.size()), "0x4a5767 full-grid reset did not mutate every generated-cell record from reset/terrain state")) {
		return 1;
	}
	if (!require(std::all_of(generator_state.generated_cell_buffer.records.begin(), generator_state.generated_cell_buffer.records.end(), [](const aurelion::h3maped_rmg_core::GeneratedCellRecord0x30 &record) {
			return record.word_0x10_known
					&& record.word_0x14_known
					&& record.word_0x18_known
					&& record.word_0x1c_known
					&& record.word_0x20_known
					&& record.word_0x28_known;
		}), "0x4a5767 full-grid reset did not claim the recovered projection word fields")) {
		return 1;
	}
	if (!require(generator_state.endpoint_cursor_0xf58_present && generator_state.endpoint_cursor_0xf58_known && generator_state.endpoint_cursor_0xf58 == 0, "generator object private state did not preserve recovered 0x49ecf2 zeroed 0xf58 cursor field")) {
		return 1;
	}
	if (!require(generator_state.endpoint_vector_d8_dc.present && !generator_state.endpoint_vector_d8_dc.count_known, "generator object private state must keep endpoint vector +0xd8/+0xdc unclaimed until source endpoint records are ported")) {
		return 1;
	}
	if (!require(generator_state.endpoint_byte_state_vector_1104_1108.present
					&& generator_state.endpoint_byte_state_vector_1104_1108.count_sourced_from_vector
					&& generator_state.endpoint_byte_state_vector_1104_1108.count_source_vector_label == generator_state.endpoint_vector_d8_dc.label
					&& generator_state.endpoint_byte_state_vector_1104_1108.zero_initialized_contents_known_when_count_known
					&& generator_state.endpoint_byte_state_vector_1104_1108.element_size_bytes == 1
					&& !generator_state.endpoint_byte_state_vector_1104_1108.count_known
					&& !generator_state.endpoint_byte_state_vector_1104_1108.contents_known,
				"generator object private state did not preserve recovered 0x49f95a byte-state vector initialization from +0xd8/+0xdc count")) {
		return 1;
	}
	if (!require(generator_state.endpoint_cursor_0xf5c_present && !generator_state.endpoint_cursor_0xf5c_known, "generator object private state must not claim recovered 0xf5c cursor seed")) {
		return 1;
	}
	if (!require(generator_state.descriptor_counter_table_0x1110_present && generator_state.descriptor_counter_table_0x1110_contents_known, "generator object private state did not expose recovered 0x49ecf2 descriptor counter table init")) {
		return 1;
	}
	if (!require(generator_state.descriptor_counter_table_0x1110_known_count == aurelion::h3maped_rmg_core::DESCRIPTOR_COUNTER_TABLE_0X1110_DWORD_COUNT, "generator object private state descriptor counter table count mismatch")) {
		return 1;
	}
	if (!require(generator_state.descriptor_counter_table_0x1110.size() == size_t(aurelion::h3maped_rmg_core::DESCRIPTOR_COUNTER_TABLE_0X1110_DWORD_COUNT), "generator object private state descriptor counter table vector size mismatch")) {
		return 1;
	}
	if (!require(std::all_of(generator_state.descriptor_counter_table_0x1110.begin(), generator_state.descriptor_counter_table_0x1110.end(), [](uint32_t value) { return value == 0U; }), "generator object private state descriptor counter table was not zero-initialized")) {
		return 1;
	}
	if (!require(composed.owner_grid.missing_boundary_input_count == 0 && composed.owner_grid.missing_source_walk_count == 0, "coordinate-to-owner-grid chain lost boundary/source inputs")) {
		return 1;
	}
	if (!require(composed.owner_grid.materialization.source_handoff_count == int32_t(seed_inputs.size()), "coordinate-to-owner-grid materializer did not consume every source handoff")) {
		return 1;
	}
	if (!require(composed.owner_grid.materialization.source_handoff_point_count > int32_t(seed_inputs.size()), "coordinate-to-owner-grid materializer lost source-node cycle points")) {
		return 1;
	}
	if (!require(composed.owner_grid.materialization.span_fill_zone_count > 0, "coordinate-to-owner-grid chain did not span-fill any seeded zone")) {
		return 1;
	}
	if (!require(composed.owner_grid.footprint_finalizer_executed, "coordinate-to-owner-grid chain did not execute recovered 0x4a3710 finalizer order")) {
		return 1;
	}
	if (!require(!composed.owner_grid.footprint_finalizer.blocked, "one-level land 0x4a3710 finalizer should not take the blocked appended-zone branch")) {
		return 1;
	}
	if (!require(composed.owner_grid.footprint_finalizer.appended_runtime_zone_count == 0, "one-level land 0x4a3710 finalizer should have no appended runtime zones")) {
		return 1;
	}
	if (!require(composed.owner_grid.footprint_finalizer.zone_order_reset_call_count == int32_t(seed_inputs.size()), "0x4a3710 finalizer did not reset one ordering vector per runtime zone")) {
		return 1;
	}
	if (!require(composed.owner_grid.footprint_finalizer.per_zone_order_helper_call_count == int32_t(seed_inputs.size()), "0x4a3710 finalizer did not rebuild one ordering vector per original runtime zone")) {
		return 1;
	}
	if (!require(!composed.owner_grid.materialization.generated_cell_word_0x20.empty(), "coordinate-to-owner-grid chain produced no generated-cell owner words")) {
		return 1;
	}
	const CoordinateOwnerGridResult4a218c composed_mode2 = aurelion::h3maped_rmg_core::coordinate_seed_and_materialize_owner_grid_4a218c_4a1f3b_4a19ed_4a3a03_4cca55_4a2777_4a325d_4a3710(
			36,
			36,
			1,
			aurelion::h3maped_rmg_core::water_mode_code("land"),
			2,
			1234U,
			seed_inputs,
			links);
	if (!require(!composed_mode2.coordinate_seed_blocked, "coordinate seed blocked in recovered-order mode-2 composed chain")) {
		return 1;
	}
	if (!require(composed_mode2.coordinate_seed.generator_mode_0x10b8 == 2, "coordinate seed did not preserve generator mode 2")) {
		return 1;
	}
	if (!require(composed_mode2.coordinate_seed.coordinate_prune_divisor_4a218c == 7, "0x4a218c generator modes outside 0/1 must use coordinate prune divisor 7")) {
		return 1;
	}
	if (!require(composed_mode2.coordinate_seed.coordinate_prune_span_budget_4a218c == (minimum_source_base_size * 36) / 7, "0x4a218c mode 2 coordinate prune span budget mismatch")) {
		return 1;
	}

	std::cout << "h3maped_rmg_core_selftest: ok\n";
	return 0;
}
