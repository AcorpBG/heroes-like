#include "h3maped_rmg_core.hpp"

#include <algorithm>
#include <iostream>
#include <string>
#include <vector>

namespace {

using aurelion::h3maped_rmg_core::BoundaryMaterialization4a2777;
using aurelion::h3maped_rmg_core::BoundaryOwnerGridResult4a3a03;
using aurelion::h3maped_rmg_core::BoundarySourceCycleHandoff4a2777;
using aurelion::h3maped_rmg_core::ConnectionFallbackMaterializationRecord4a7605_4a5e03;
using aurelion::h3maped_rmg_core::ConnectionFallbackMaterializationResult4a7605_4a5e03;
using aurelion::h3maped_rmg_core::CoordinateOwnerGridResult4a218c;
using aurelion::h3maped_rmg_core::EndpointMaterializationResult4a5e73;
using aurelion::h3maped_rmg_core::EndpointMaterializationState4a5e73;
using aurelion::h3maped_rmg_core::EndpointPointerRecord4a5e73;
using aurelion::h3maped_rmg_core::FootprintFinalizerResult4a3710;
using aurelion::h3maped_rmg_core::GeneratorCoordinateCandidateVectorState4a1f3b;
using aurelion::h3maped_rmg_core::GeneratorObjectPrivateState;
using aurelion::h3maped_rmg_core::GeneratorRelationOwnerAdjacencyRecord4a3710;
using aurelion::h3maped_rmg_core::GeneratorRelationOwnerState4a218c;
using aurelion::h3maped_rmg_core::GeneratorRelationRecordState4a218c;
using aurelion::h3maped_rmg_core::GeneratorSourceEndpointRecordState4a1f3b;
using aurelion::h3maped_rmg_core::GeneratorSetupModeResult49ecf2;
using aurelion::h3maped_rmg_core::GeneratedCellRecord0x30;
using aurelion::h3maped_rmg_core::GeneratedCellRecordGrid0x30;
using aurelion::h3maped_rmg_core::GeneratedCellWordGrid;
using aurelion::h3maped_rmg_core::H3MapedRng;
using aurelion::h3maped_rmg_core::H3MapedRmgWorkflowConfig;
using aurelion::h3maped_rmg_core::H3MapedRmgWorkflowResult;
using aurelion::h3maped_rmg_core::MineResourceMaterializationResult4a9d6a;
using aurelion::h3maped_rmg_core::ObjectRecordReference4a54a7;
using aurelion::h3maped_rmg_core::RelationHighOwnerPropagationResult49a318;
using aurelion::h3maped_rmg_core::RewardGuardCoordinateScanResult4aa9b7;
using aurelion::h3maped_rmg_core::RewardGuardAttachResult49cf34;
using aurelion::h3maped_rmg_core::RewardGuardMaterializationDriverResult4aa354;
using aurelion::h3maped_rmg_core::RewardGuardSourceStreamAttempt4aab7e;
using aurelion::h3maped_rmg_core::RewardGuardSourceStreamResult4aab7e;
using aurelion::h3maped_rmg_core::RewardGuardWrapperConstructResult49ce04;
using aurelion::h3maped_rmg_core::RewardGuardWrapperFinalMarkResult49cefb;
using aurelion::h3maped_rmg_core::RewardGuardWrapperMember4aa3e9;
using aurelion::h3maped_rmg_core::RewardGuardWrapperState4aa3e9;
using aurelion::h3maped_rmg_core::RewardGuardRelationPriorityResult4ad7f7;
using aurelion::h3maped_rmg_core::RewardGuardProjectionChainResult49c0a6;
using aurelion::h3maped_rmg_core::RuntimeZoneBoundaryInput4a3a03;
using aurelion::h3maped_rmg_core::RuntimeZoneFootprintInput4a3a03;
using aurelion::h3maped_rmg_core::RuntimeLinkSeedInput4a218c;
using aurelion::h3maped_rmg_core::RuntimeTerrainSelectionRecord49b53d;
using aurelion::h3maped_rmg_core::RuntimeTerrainSelectionResult49b53d;
using aurelion::h3maped_rmg_core::RuntimeZoneSeedInput4a218c;
using aurelion::h3maped_rmg_core::RuntimeSeedBuildResult4a218c;
using aurelion::h3maped_rmg_core::SourceObjectCatalogSummary0x49da08;
using aurelion::h3maped_rmg_core::SourceObjectDescriptor4903e8;
using aurelion::h3maped_rmg_core::SourceObjectDescriptorJoinResult4903e8;
using aurelion::h3maped_rmg_core::SourceObjectMaskLaneResult4af89f;
using aurelion::h3maped_rmg_core::ObjectMaterializationPrep4a8db2_4a901a;
using aurelion::h3maped_rmg_core::SourceObjectRecord0x4c;
using aurelion::h3maped_rmg_core::SourceObjectResolvedWrapper4af785;
using aurelion::h3maped_rmg_core::SourceObjectResolverResult4af785;
using aurelion::h3maped_rmg_core::SourceObjectResolverSourcePair4af785;
using aurelion::h3maped_rmg_core::SourceObjectResolverState4af785;
using aurelion::h3maped_rmg_core::SourceObjectSelectorResult4a9e40;
using aurelion::h3maped_rmg_core::SourceOrderSchedulerSourceRecord4a8db2;
using aurelion::h3maped_rmg_core::SourceOrderSchedulerResult4a8db2;
using aurelion::h3maped_rmg_core::SourceZonePayload4a218c;
using aurelion::h3maped_rmg_core::SourceObjectWrapperBucket0xe8;
using aurelion::h3maped_rmg_core::SourceObjectWrapperBucketSummary0xe8;
using aurelion::h3maped_rmg_core::SourceNodeFootprintResult4a3a03;
using aurelion::h3maped_rmg_core::SourceNodeCyclePoint4a2777;
using aurelion::h3maped_rmg_core::SpanRecord;
using aurelion::h3maped_rmg_core::TerrainRepaintResult4a3f27;
using aurelion::h3maped_rmg_core::TemplateSelectionRuntimeResult4ac552;
using aurelion::h3maped_rmg_core::TemplateLinkRecord4a1f3b;
using aurelion::h3maped_rmg_core::TemplateZoneRecord4a218c;
using aurelion::h3maped_rmg_core::WeightedObjectRecord4a93a2;

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

SourceNodeCyclePoint4a2777 descriptor_source_node(int32_t x, int32_t y, int32_t model_node_index, int32_t pair_index, int32_t next_index, int32_t previous_index, int32_t next_pair_index) {
	SourceNodeCyclePoint4a2777 node = source_node(x, y, model_node_index);
	node.pair_index = pair_index;
	node.next_index = next_index;
	node.previous_index = previous_index;
	node.next_pair_index = next_pair_index;
	return node;
}

BoundarySourceCycleHandoff4a2777 square_handoff(bool gate_first_edge) {
	BoundarySourceCycleHandoff4a2777 handoff;
	handoff.runtime_zone_index = 0;
	handoff.zone_word = 1;
	handoff.span_fill_owner_word_0x4a325d = handoff.zone_word;
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
		handoff.source_nodes[0].next_pair_payload_owner_word_0x00 = 1;
	}
	return handoff;
}

int32_t owner_byte2_signed(uint32_t word_0x20) {
	const uint32_t value = (word_0x20 >> 16U) & 0xffU;
	return value >= 0x80U ? int32_t(value) - 0x100 : int32_t(value);
}

bool expected_recenter_coordinate_0x4a2ffa(const GeneratedCellRecordGrid0x30 &grid, const GeneratorRelationOwnerState4a218c &owner, int32_t &expected_x, int32_t &expected_y, int32_t &expected_level, int32_t &matched_count) {
	expected_x = owner.coordinate_x_0x10;
	expected_y = owner.coordinate_y_0x14;
	expected_level = owner.coordinate_level_0x18;
	matched_count = 0;
	const int32_t relation_owner_byte2 = owner.relation_owner_byte2_0x4aa9b7_known && owner.relation_owner_byte2_0x4aa9b7 >= 0
			? owner.relation_owner_byte2_0x4aa9b7
			: owner.runtime_zone_index;
	if (!owner.scan_bounds_0x20_0x2c_known || relation_owner_byte2 < 0 || !owner.coordinate_triple_0x10_0x18_known) {
		return false;
	}
	int64_t sum_x = 0;
	int64_t sum_y = 0;
	for (int32_t y = owner.scan_bound_low_y_0x24; y < owner.scan_bound_high_y_0x2c; ++y) {
		for (int32_t x = owner.scan_bound_low_x_0x20; x < owner.scan_bound_high_x_0x28; ++x) {
			const int64_t flat = aurelion::h3maped_rmg_core::cell_index(grid.width, grid.height, x, y, owner.coordinate_level_0x18);
			if (flat < 0 || flat >= int64_t(grid.records.size())) {
				continue;
			}
			const GeneratedCellRecord0x30 &record = grid.records[size_t(flat)];
			if (!record.word_0x20_known || owner_byte2_signed(record.word_0x20) != relation_owner_byte2) {
				continue;
			}
			matched_count += 1;
			sum_x += x;
			sum_y += y;
		}
	}
	if (matched_count == 0) {
		return false;
	}
	expected_x = int32_t(sum_x / matched_count);
	expected_y = int32_t(sum_y / matched_count);
	return true;
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
		const aurelion::h3maped_rmg_core::ClipBounds bounds { 0, 0, 10, 10 };
		auto require_clip = [&](const std::string &label, int32_t x1, int32_t y1, int32_t x2, int32_t y2, int32_t expected_x, int32_t expected_y) {
			const auto clipped = aurelion::h3maped_rmg_core::clip_point_4a2b33(x1, y1, x2, y2, bounds);
			return require(clipped.x == expected_x && clipped.y == expected_y,
					"0x4a2b33 " + label + " expected (" + std::to_string(expected_x) + "," + std::to_string(expected_y)
							+ ") got (" + std::to_string(clipped.x) + "," + std::to_string(clipped.y) + ")");
		};
		if (!require_clip("inside endpoint", 3, 4, 7, 8, 3, 4)) {
			return 1;
		}
		if (!require_clip("left edge 0x4a2bb5 returns original endpoint", -5, 5, 5, -15, -5, 5)) {
			return 1;
		}
		if (!require_clip("min-y 0x4a2bb5 returns original endpoint", 5, -5, -15, 5, 5, -5)) {
			return 1;
		}
		if (!require_clip("max-x 0x4a2bb5 returns original endpoint", 15, 5, 5, -15, 15, 5)) {
			return 1;
		}
		if (!require_clip("max-y 0x4a2ccf returns original endpoint", 5, 15, -15, 5, 5, 15)) {
			return 1;
		}
		if (!require_clip("ordinary edge projection returns current clipped endpoint", -5, -5, 5, 5, 0, 0)) {
			return 1;
		}
	}

	{
		const auto level_one_line = aurelion::h3maped_rmg_core::boundary_line_writer_4a261a(5, 5, 2, 2, 0, 0, 3, 0, 7, 1);
		if (!require(!level_one_line.trace.empty(), "0x4a261a level-1 deterministic line did not emit trace writes")) {
			return 1;
		}
		if (!require(std::all_of(level_one_line.trace.begin(), level_one_line.trace.end() - 1, [](const auto &write) {
					return write.reserved;
				}) && !level_one_line.trace.back().reserved,
					"0x4a261a must reserve generator mode 2 level 1 writes except the terminal endpoint")) {
			return 1;
		}

		const auto level_zero_line = aurelion::h3maped_rmg_core::boundary_line_writer_4a261a(5, 5, 2, 2, 0, 0, 3, 0, 7, 0);
		if (!require(level_zero_line.trace.size() >= 2, "0x4a261a level-0 deterministic line emitted too few writes")) {
			return 1;
		}
		if (!require(std::none_of(level_zero_line.trace.begin(), level_zero_line.trace.end(), [](const auto &write) {
					return write.reserved;
				}),
					"0x4a261a must suppress reserved flags for generator mode 2 level 0")) {
			return 1;
		}

		const int32_t width = 5;
		const int32_t height = 5;
		const int32_t level_count = 2;
		const int32_t cell_count = width * height * level_count;
		{
			std::vector<uint32_t> zone_words(size_t(cell_count), aurelion::h3maped_rmg_core::UNASSIGNED_ZONE_WORD);
			std::vector<uint32_t> generated_words(size_t(cell_count), aurelion::h3maped_rmg_core::GENERATED_CELL_INITIAL_WORD_0X20);
			std::vector<uint32_t> generated_word_0x28(size_t(cell_count), 0U);
			std::vector<uint8_t> cell_flags(size_t(cell_count), 0U);
			const auto fill = aurelion::h3maped_rmg_core::span_fill_4a325d(zone_words, generated_words, generated_word_0x28, cell_flags, width, height, level_count, 2, 3, 3, SpanRecord { 1, 1, 1 });
			if (!require(!fill.trace.empty(), "0x4a325d level-1 span fill did not emit trace writes")) {
				return 1;
			}
			if (!require(std::all_of(fill.trace.begin(), fill.trace.end(), [](const auto &write) {
						return write.reserved;
					}),
					"0x4a325d must reserve generator mode 2 level 1 writes")) {
				return 1;
			}
			if (!require(std::any_of(generated_word_0x28.begin(), generated_word_0x28.end(), [](uint32_t word) {
						return (word & aurelion::h3maped_rmg_core::CELL_TERRAIN_RELATION_ELIGIBLE_BIT_28) != 0U;
					}),
					"0x4a325d reserved writes must set generated-cell +0x2b bit 0x10 / word +0x28 bit 28")) {
				return 1;
			}
		}
		{
			std::vector<uint32_t> zone_words(size_t(cell_count), aurelion::h3maped_rmg_core::UNASSIGNED_ZONE_WORD);
			std::vector<uint32_t> generated_words(size_t(cell_count), aurelion::h3maped_rmg_core::GENERATED_CELL_INITIAL_WORD_0X20);
			std::vector<uint32_t> generated_word_0x28(size_t(cell_count), 0U);
			std::vector<uint8_t> cell_flags(size_t(cell_count), 0U);
			const auto fill = aurelion::h3maped_rmg_core::span_fill_4a325d(zone_words, generated_words, generated_word_0x28, cell_flags, width, height, level_count, 2, 3, 3, SpanRecord { 1, 1, 0 });
			if (!require(!fill.trace.empty(), "0x4a325d level-0 span fill did not emit trace writes")) {
				return 1;
			}
			if (!require(std::none_of(fill.trace.begin(), fill.trace.end(), [](const auto &write) {
						return write.reserved;
					}),
					"0x4a325d must suppress reserved flags for generator mode 2 level 0")) {
				return 1;
			}
			if (!require(std::none_of(generated_word_0x28.begin(), generated_word_0x28.end(), [](uint32_t word) {
						return (word & aurelion::h3maped_rmg_core::CELL_TERRAIN_RELATION_ELIGIBLE_BIT_28) != 0U;
					}),
					"0x4a325d unreserved writes must not set generated-cell +0x2b bit 0x10 / word +0x28 bit 28")) {
				return 1;
			}
		}
	}

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
		if (!require(source_object_summary.rand_trn_score_record_count == 109, "0x49dc9e rand_trn score record table lost recovered row count")) {
			return 1;
		}
		if (!require(source_object_summary.rand_trn_score_variant_count == 2425, "0x49dc9e rand_trn score variants no longer match recovered object-template cross-reference")) {
			return 1;
		}
		if (!require(source_object_summary.passability_mask_record_count == source_object_summary.record_count,
					"0x49da08 source object catalog did not preserve recovered passability mask coverage")) {
			return 1;
		}
		if (!require(source_object_summary.action_mask_record_count == source_object_summary.record_count,
					"0x49da08 source object catalog did not preserve recovered action mask coverage")) {
			return 1;
		}
		if (!require(source_object_summary.descriptor_mask_field_record_count == source_object_summary.record_count,
					"0x49da08 source object catalog did not preserve recovered descriptor .msk field coverage")) {
			return 1;
		}
		if (!require(source_object_summary.descriptor_mask_exact_def_msk_count == source_object_summary.record_count,
					"0x49da08 source object catalog fell back from exact DEF .msk data")) {
			return 1;
		}
		if (!require(source_object_summary.descriptor_mask_default_msk_fallback_count == 0,
					"0x49da08 source object catalog unexpectedly used default.msk fallbacks")) {
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
		if (!require(type45_records[0].metadata_bucket_index_0x08 == 45, "0x49da08 type-45 source record lost recovered identity-default metadata +0x08 bucket lane")) {
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
		if (!require(wrapper_summary.non_empty_bucket_count == 160, "0x49db76 wrapper bucket table must use recovered metadata +0x08 identity defaults plus alias lanes")) {
			return 1;
		}
		if (!require(wrapper_summary.total_source_record_references == source_object_summary.record_count, "0x49db76 wrapper bucket table did not account for every source record")) {
			return 1;
		}
		if (!require(wrapper_summary.out_of_range_source_record_count == 0, "0x49db76 wrapper bucket table found out-of-range metadata buckets despite recovered 0xe8 bound")) {
			return 1;
		}
		if (!require(wrapper_summary.max_bucket_index_0x08 == 54 && wrapper_summary.max_bucket_record_count == 141, "0x49db76 wrapper max bucket drifted from recovered metadata +0x08 identity-default table")) {
			return 1;
		}
		SourceObjectWrapperBucket0xe8 default_bucket;
		if (!require(aurelion::h3maped_rmg_core::source_object_wrapper_bucket_by_index_0x49db76(0, default_bucket), "0x49db76 wrapper lookup rejected metadata bucket 0")) {
			return 1;
		}
		if (!require(default_bucket.initialized_by_0x49db76 && default_bucket.record_count == 1 && default_bucket.source_record_indices.size() == 1 && default_bucket.first_type_id_0x1c == 0, "0x49db76 metadata bucket 0 should only keep the default source record after recovered identity-default routing")) {
			return 1;
		}
		SourceObjectWrapperBucket0xe8 tree_bucket;
		if (!require(aurelion::h3maped_rmg_core::source_object_wrapper_bucket_by_index_0x49db76(155, tree_bucket), "0x49db76 wrapper lookup rejected metadata bucket 155")) {
			return 1;
		}
		if (!require(tree_bucket.initialized_by_0x49db76 && tree_bucket.record_count == 76 && tree_bucket.first_type_id_0x1c == 155, "0x49db76 metadata bucket 155 lost identity/default plus type-199 alias source records")) {
			return 1;
		}
		SourceObjectWrapperBucket0xe8 mine_bucket;
		if (!require(aurelion::h3maped_rmg_core::source_object_wrapper_bucket_by_index_0x49db76(53, mine_bucket), "0x49db76 wrapper lookup rejected metadata bucket 53")) {
			return 1;
		}
		if (!require(mine_bucket.initialized_by_0x49db76 && mine_bucket.record_count == 53 && mine_bucket.first_type_id_0x1c == 53, "0x49db76 metadata bucket 53 lost identity/default plus type-220 alias source records")) {
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
		if (!require(type199_selection.bucket_found && type199_selection.scanned_record_count == 76 && type199_selection.accepted_count > 0, "0x4a9e40 source wrapper selector did not scan metadata bucket 155 candidates")) {
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
		if (!require(resolver_state.wrapper_bucket_indices_0xe8[size_t(type199_records[0].metadata_bucket_index_0x08)].size() == 1
						&& resolver_state.wrapper_bucket_indices_0xe8[size_t(type199_records[0].metadata_bucket_index_0x08)][0] == 0,
					"0x4af785 did not append the created wrapper into the runtime 0xe8 metadata bucket")) {
			return 1;
		}
		const SourceObjectSelectorResult4a9e40 resolver_bucket_selection =
				aurelion::h3maped_rmg_core::source_object_wrapper_selector_0x4a9e40(resolver_state, 10U, type199_lane.selected_lane, type199_records[0].metadata_bucket_index_0x08, type199_records[0].subtype_0x20);
		if (!require(resolver_bucket_selection.bucket_found
						&& resolver_bucket_selection.scanned_record_count == 1
						&& resolver_bucket_selection.accepted_count == 1
						&& resolver_bucket_selection.selected
						&& resolver_bucket_selection.selected_from_resolver_state
						&& resolver_bucket_selection.selected_wrapper_index == first_resolve.selected_wrapper_index
						&& resolver_bucket_selection.selected_source_record_copy_known
						&& aurelion::h3maped_rmg_core::same_source_object_record_0x4c(resolver_bucket_selection.selected_source_record_copy, type199_records[0]),
					"0x4a9e40 resolver-backed selector did not consume the runtime wrapper bucket populated by 0x4af785")) {
			return 1;
		}
		const auto &first_source_pair = resolver_state.source_pairs_0xedc[0];
		if (!require(first_source_pair.source_record_pointer_0x00_carried
						&& first_source_pair.context_pointer_0x04_carried
						&& first_source_pair.copied_source_catalog_index == first_resolve.input_source_catalog_index
						&& first_source_pair.wrapper_index == first_resolve.selected_wrapper_index
						&& first_source_pair.context_wrapper_index_0x04 == first_resolve.selected_wrapper_index
						&& first_source_pair.context_wrapper_lane_0x04 == type199_lane.selected_lane
						&& first_source_pair.source_lane_0x1c == type199_records[0].type_id_0x1c
						&& aurelion::h3maped_rmg_core::same_source_object_record_0x4c(first_source_pair.source_record_copy, type199_records[0])
						&& aurelion::h3maped_rmg_core::same_source_object_record_0x4c(first_source_pair.context_wrapper_copy.source_record_copy, type199_records[0]),
					"0x4af785 first +0xedc pair did not preserve source-record pointer and context wrapper payload")) {
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
				const auto &second_source_pair = resolver_state.source_pairs_0xedc[1];
				if (!require(second_source_pair.source_record_pointer_0x00_carried
								&& second_source_pair.context_pointer_0x04_carried
								&& second_source_pair.copied_source_catalog_index == mismatch_resolve.input_source_catalog_index
								&& second_source_pair.wrapper_index == mismatch_resolve.selected_wrapper_index
								&& aurelion::h3maped_rmg_core::same_source_object_record_0x4c(second_source_pair.source_record_copy, candidate),
							"0x4af785 mismatch +0xedc pair did not carry the second copied source record")) {
					return 1;
				}
				break;
			}
		}
		SourceObjectResolverState4af785 descriptor_join_state;
		SourceObjectDescriptor4903e8 type45_descriptor;
		type45_descriptor.target_context_0x4903e8 = 45;
		type45_descriptor.source_key_0x00 = 0x491eed;
		type45_descriptor.descriptor_type_0x1c = type45_records[0].type_id_0x1c;
		type45_descriptor.subtype_0x20 = type45_records[0].subtype_0x20;
		type45_descriptor.group_0x24 = type45_records[0].group_0x24;
		type45_descriptor.projection_enabled_0x29 = true;
		type45_descriptor.source_cell_x_0x2c = 1;
		type45_descriptor.source_cell_y_0x30 = 2;
		const SourceObjectDescriptorJoinResult4903e8 type45_join =
				aurelion::h3maped_rmg_core::source_object_descriptor_join_0x4903e8(descriptor_join_state, type45_descriptor, type45_records[0]);
		if (!require(type45_join.joined
						&& type45_join.recovered_target_context
						&& type45_join.resolver_invoked_0x4af785
						&& type45_join.resolver_0x4af785.created_new_wrapper,
					"0x4903e8 descriptor/source join did not invoke 0x4af785 for recovered target context 45")) {
			return 1;
		}
		if (!require(type45_join.copied_source_record_is_identity_authority
						&& type45_join.descriptor_source_key_is_not_source_row_id
						&& type45_join.source_record_copy.source_row == type45_records[0].source_row
						&& type45_join.source_record_copy.def_name == type45_records[0].def_name,
					"0x4903e8 descriptor/source join did not carry the copied 0x4c source record as identity authority")) {
			return 1;
		}
		if (!require(descriptor_join_state.source_pairs_0xedc.size() == 1
						&& descriptor_join_state.source_pairs_0xedc[0].descriptor_join_0x4903e8_known
						&& descriptor_join_state.source_pairs_0xedc[0].descriptor_joined_0x4903e8
					&& descriptor_join_state.source_pairs_0xedc[0].descriptor_join_source_pair_index_0xedc == 0
					&& descriptor_join_state.source_pairs_0xedc[0].descriptor_join_descriptor_0x4903e8.target_context_0x4903e8 == 45
					&& descriptor_join_state.source_pairs_0xedc[0].descriptor_join_descriptor_0x4903e8.source_key_0x00 == type45_descriptor.source_key_0x00
					&& descriptor_join_state.source_pairs_0xedc[0].descriptor_join_descriptor_0x4903e8.descriptor_type_0x1c == type45_descriptor.descriptor_type_0x1c
					&& descriptor_join_state.source_pairs_0xedc[0].descriptor_join_descriptor_0x4903e8.source_cell_x_0x2c == 1
					&& descriptor_join_state.source_pairs_0xedc[0].descriptor_join_descriptor_0x4903e8.source_cell_y_0x30 == 2,
					"0x4903e8-created +0xedc source pair did not retain descriptor join context for live source-order replay")) {
			return 1;
		}
		SourceObjectRecord0x4c generic_record = type45_records[0];
		generic_record.raw_field_0x20_known = true;
		generic_record.raw_field_0x20 = 0;
		generic_record.raw_field_0x24_known = true;
		generic_record.raw_field_0x24 = 1;
		generic_record.raw_field_0x28_known = true;
		generic_record.raw_field_0x28 = 0;
		generic_record.raw_field_0x2c_known = true;
		generic_record.raw_field_0x2c = 0;
		generic_record.raw_field_0x30_known = true;
		generic_record.raw_field_0x30 = 0;
		generic_record.raw_field_0x34_known = true;
		generic_record.raw_field_0x34 = 0;
		generic_record.raw_field_0x38_known = true;
		generic_record.raw_field_0x38 = 0;
		generic_record.raw_field_0x3c_known = true;
		generic_record.raw_field_0x3c = 0;
		SourceObjectDescriptor4903e8 generic_descriptor = type45_descriptor;
		generic_descriptor.source_cell_x_0x2c = 0;
		generic_descriptor.source_cell_y_0x30 = 0;
		SourceObjectResolverState4af785 generic_replay_join_state;
		const SourceObjectDescriptorJoinResult4903e8 generic_join =
				aurelion::h3maped_rmg_core::source_object_descriptor_join_0x4903e8(generic_replay_join_state, generic_descriptor, type45_records[0]);
		if (!require(generic_join.joined
						&& generic_replay_join_state.source_pairs_0xedc.size() == 1,
					"generic non-type98 replay fixture failed to build a descriptor-joined +0xedc source pair")) {
			return 1;
		}
		GeneratorObjectPrivateState generic_replay_state;
		generic_replay_state.width = 16;
		generic_replay_state.height = 16;
		generic_replay_state.level_count = 1;
		generic_replay_state.generated_cell_buffer = aurelion::h3maped_rmg_core::generated_cell_record_grid_reset_0x49a072(16, 16, 1);
		generic_replay_state.generated_cell_buffer_owned = true;
		generic_replay_state.descriptor_counter_table_0x1110_present = true;
		generic_replay_state.descriptor_counter_table_0x1110_contents_known = true;
		generic_replay_state.descriptor_counter_table_0x1110_known_count = aurelion::h3maped_rmg_core::DESCRIPTOR_COUNTER_TABLE_0X1110_DWORD_COUNT;
		generic_replay_state.descriptor_counter_table_0x1110.assign(size_t(aurelion::h3maped_rmg_core::DESCRIPTOR_COUNTER_TABLE_0X1110_DWORD_COUNT), 0U);
		generic_replay_state.object_record_sequence_allocator_0xf44_present = true;
		generic_replay_state.object_record_sequence_allocator_0xf44_known = true;
		generic_replay_state.object_record_sequence_allocator_0xf44 = 1;
		generic_replay_state.native_object_record_key_allocator_0x4a93a2_known = true;
		generic_replay_state.next_native_object_record_key_0x4a93a2 = 0x036b7000U;
		for (GeneratedCellRecord0x30 &record : generic_replay_state.generated_cell_buffer.records) {
			record.object_reference_vector_contents_known = true;
			record.object_reference_count = 0;
			record.object_references_0x04_0x08.clear();
			record.word_0x20_known = true;
			record.word_0x20 = 0xff000064U;
			record.word_0x24_known = true;
			record.word_0x24 = 0x00000540U;
			record.word_0x28_known = true;
			record.word_0x28 = aurelion::h3maped_rmg_core::CELL_DECOR_READY_BIT_25;
			record.word_0x2c_known = true;
			record.word_0x2c = 0U;
		}
		GeneratorRelationOwnerState4a218c generic_owner;
		generic_owner.runtime_zone_index = 0;
		generic_owner.owner_vector_index = 0;
		generic_owner.coordinate_triple_0x10_0x18_known = true;
		generic_owner.coordinate_x_0x10 = 6;
		generic_owner.coordinate_y_0x14 = 6;
		generic_owner.coordinate_level_0x18 = 0;
		generic_owner.scan_bounds_0x20_0x2c_known = true;
		generic_owner.scan_bound_low_x_0x20 = 6;
		generic_owner.scan_bound_low_y_0x24 = 6;
		generic_owner.scan_bound_high_x_0x28 = 7;
		generic_owner.scan_bound_high_y_0x2c = 7;
		generic_owner.terrain_policy_0x0c_known = true;
		generic_owner.terrain_policy_0x0c = 0;
		generic_owner.descriptor_type_counter_table_0x44_known = true;
		generic_owner.descriptor_type_counter_table_0x44_zero_count = aurelion::h3maped_rmg_core::RELATION_OWNER_DESCRIPTOR_TABLE_0X44_DWORD_COUNT;
		generic_owner.descriptor_type_counters_0x44.assign(size_t(aurelion::h3maped_rmg_core::RELATION_OWNER_DESCRIPTOR_TABLE_0X44_DWORD_COUNT), 0U);
		generic_replay_state.relation_owner_vectors_10e4_10e8.push_back(generic_owner);
		generic_replay_state.relation_owner_vector_count_10e4_10e8 = 1;
		SourceObjectResolverSourcePair4af785 generic_pair = generic_replay_join_state.source_pairs_0xedc[0];
		generic_pair.source_record_copy = generic_record;
		generic_pair.source_order_relation_context_known = true;
		generic_pair.source_order_relation_owner_byte2 = 0;
		generic_pair.source_order_source_pair_key_0x0c_known = true;
		generic_pair.source_order_source_pair_key_0x0c = 5;
		generic_pair.source_order_anchor_known = true;
		generic_pair.source_order_anchor_x_0x10 = 6;
		generic_pair.source_order_anchor_y_0x14 = 6;
		generic_pair.source_order_anchor_level_0x18 = 0;
		generic_pair.source_order_lane_state_0xee4_known = true;
		generic_pair.source_order_lane_state_0xee4 = 2;
		generic_replay_state.source_pair_records_edc.push_back(generic_pair);
		aurelion::h3maped_rmg_core::H3MapedRng generic_replay_rng;
		generic_replay_rng.state = 10U;
		aurelion::h3maped_rmg_core::replay_generic_non_type98_source_order_pairs_0x4a8d2c_0x4a8db2(generic_replay_state, generic_replay_rng);
		const int64_t generic_target_flat = aurelion::h3maped_rmg_core::cell_index(16, 16, 6, 6, 0);
		const GeneratedCellRecord0x30 &generic_target = generic_replay_state.generated_cell_buffer.records[size_t(generic_target_flat)];
		if (!require(generic_replay_state.generic_source_order_pair_replay_applied_0x4a8d2c_0x4a8db2
						&& generic_replay_state.generic_source_order_pair_scan_count_0xedc == 1
						&& generic_replay_state.generic_source_order_pair_direct_dispatch_count_0x4a8d2c == 1
						&& generic_replay_state.generic_source_order_pair_direct_commit_count_0x4a8d2c == 1
						&& generic_replay_state.generic_source_order_pair_weighted_replay_count_0x4a8db2 == 1
						&& generic_replay_state.generic_source_order_pair_weighted_commit_count_0x4a8db2 == 0
						&& generic_replay_state.source_pair_records_edc[0].source_pair_success_byte_0x3c_known
						&& generic_replay_state.source_pair_records_edc[0].source_pair_success_byte_0x3c == 1
						&& generic_replay_state.object_records_0xec4_ecc.size() == 1
						&& generic_replay_state.object_records_0xec4_ecc.back().source_order_direct_record_0x4a8d2c_0x4a93a2_known
						&& generic_replay_state.object_records_0xec4_ecc.back().object_record_key == 0x036b7000U
						&& generic_replay_state.object_records_0xec4_ecc.back().object_record_selected_index_0x20 == 2
						&& generic_replay_state.descriptor_counter_table_0x1110[size_t(generic_record.type_id_0x1c)] == 1U
						&& generic_replay_state.relation_owner_vectors_10e4_10e8[0].descriptor_type_counters_0x44[size_t(generic_record.type_id_0x1c)] == 1U
						&& generic_target.object_reference_count == 1
						&& generic_target.object_references_0x04_0x08[0] == 0x036b7000U,
					"generic non-type98 +0xedc source-pair replay did not commit through 0x4a8d2c -> 0x4a93a2 -> 0x4a54a7")) {
			return 1;
		}
		const SourceObjectDescriptorJoinResult4903e8 type45_reuse_join =
				aurelion::h3maped_rmg_core::source_object_descriptor_join_0x4903e8(descriptor_join_state, type45_descriptor, type45_records[0]);
		if (!require(type45_reuse_join.joined
						&& type45_reuse_join.resolver_0x4af785.reused_existing_wrapper
						&& descriptor_join_state.wrappers.size() == 1
						&& descriptor_join_state.source_pairs_0xedc.size() == 1,
					"0x4903e8 descriptor/source join did not reuse the existing 0x4af785 copied wrapper")) {
			return 1;
		}
		SourceObjectDescriptor4903e8 mine_descriptor;
		mine_descriptor.target_context_0x4903e8 = 53;
		mine_descriptor.source_key_0x00 = 53;
		mine_descriptor.descriptor_type_0x1c = mine_subtype_records[0].type_id_0x1c;
		mine_descriptor.subtype_0x20 = mine_subtype_records[0].subtype_0x20;
		mine_descriptor.group_0x24 = mine_subtype_records[0].group_0x24;
		const SourceObjectDescriptorJoinResult4903e8 mine_join =
				aurelion::h3maped_rmg_core::source_object_descriptor_join_0x4903e8(descriptor_join_state, mine_descriptor, mine_subtype_records[0]);
		if (!require(mine_join.joined
						&& mine_join.descriptor_only_identity_ambiguous
						&& mine_join.copied_source_record_is_identity_authority
						&& mine_join.source_record_copy.def_name == mine_subtype_records[0].def_name,
					"0x4903e8 type-53 mine join did not preserve copied source record identity over descriptor-only ambiguity")) {
			return 1;
		}
		SourceObjectDescriptor4903e8 unsupported_descriptor = type45_descriptor;
		unsupported_descriptor.target_context_0x4903e8 = 199;
		const size_t wrapper_count_before_unsupported = descriptor_join_state.wrappers.size();
		const SourceObjectDescriptorJoinResult4903e8 unsupported_join =
				aurelion::h3maped_rmg_core::source_object_descriptor_join_0x4903e8(descriptor_join_state, unsupported_descriptor, type45_records[0]);
		if (!require(!unsupported_join.joined
						&& !unsupported_join.resolver_invoked_0x4af785
						&& unsupported_join.blocked_reason == "0x4903e8_target_context_unrecovered_for_descriptor_source_join"
						&& descriptor_join_state.wrappers.size() == wrapper_count_before_unsupported,
					"0x4903e8 unsupported descriptor context mutated resolver state instead of blocking")) {
			return 1;
		}
		SourceObjectRecord0x4c blank_record;
		const SourceObjectMaskLaneResult4af89f blank_lane =
				aurelion::h3maped_rmg_core::source_object_mask_lane_selector_0x4af89f(blank_record);
		if (!require(blank_lane.selected_lane == 9 && !blank_lane.selected_by_mask && blank_lane.scanned_lane_count == 9, "0x4af89f zero-mask record did not return sentinel lane 9")) {
			return 1;
		}
	}

	{
		std::vector<GeneratorRelationOwnerState4a218c> owners(3);
		for (int32_t index = 0; index < 3; ++index) {
			owners[size_t(index)].owner_vector_index = index;
			owners[size_t(index)].runtime_zone_index = index;
		}
		GeneratorRelationRecordState4a218c edge_0_to_1;
		edge_0_to_1.target_runtime_zone_index = 1;
		owners[0].relation_records.push_back(edge_0_to_1);
		owners[0].relation_record_count = int32_t(owners[0].relation_records.size());
		GeneratorRelationRecordState4a218c edge_1_to_2;
		edge_1_to_2.target_runtime_zone_index = 2;
		owners[1].relation_records.push_back(edge_1_to_2);
		owners[1].relation_record_count = int32_t(owners[1].relation_records.size());
		H3MapedRng priority_rng;
		priority_rng.state = 1U;
		const RewardGuardRelationPriorityResult4ad7f7 priority_result =
				aurelion::h3maped_rmg_core::reward_guard_relation_priority_ordering_0x4ad7f7(owners, 0, priority_rng, true);
		if (!require(priority_result.applied
						&& priority_result.distance_prepass_0x4ad6a8_applied
						&& priority_result.randomized_priority_pass_0x4ad7f7_applied
						&& priority_result.ordered_vector_ready_for_0x4aa9b7,
					"0x4ad7f7 relation priority ordering did not complete for explicit source-backed inputs")) {
			return 1;
		}
		if (!require(priority_result.distance_prepass_relax_count == 2
						&& priority_result.rng_call_count == 3
						&& priority_result.rng_state_after == 0x18be873aU,
					"0x4ad6a8/0x4ad7f7 relation priority pass did not preserve recovered RNG and graph walk counts")) {
			return 1;
		}
		if (!require(owners[0].reward_guard_priority_before_randomization_0x4ad7f7 == 0
						&& owners[0].reward_guard_priority_rng_value_0x4e7276 == 41
						&& owners[0].reward_guard_priority_0x40 == 1
						&& owners[0].reward_guard_priority_source_relation_0x4ad6a8,
					"0x4ad7f7 source relation priority did not use old*10 plus rng%10")) {
			return 1;
		}
		if (!require(owners[1].reward_guard_priority_before_randomization_0x4ad7f7 == 1
						&& owners[1].reward_guard_priority_rng_value_0x4e7276 == 18467
						&& owners[1].reward_guard_priority_0x40 == 1007,
					"0x4ad7f7 direct-neighbor relation priority did not use the recovered old==1 special path")) {
			return 1;
		}
		if (!require(owners[2].reward_guard_priority_before_randomization_0x4ad7f7 == 2
						&& owners[2].reward_guard_priority_rng_value_0x4e7276 == 6334
						&& owners[2].reward_guard_priority_0x40 == 24,
					"0x4ad7f7 second-hop relation priority did not use old*10 plus rng%10")) {
			return 1;
		}
		if (!require(priority_result.ordered_owner_vector_indexes_0x4ccecb.size() == 2
						&& priority_result.ordered_owner_vector_indexes_0x4ccecb[0] == 2
						&& priority_result.ordered_owner_vector_indexes_0x4ccecb[1] == 1,
					"0x4ad7f7 ordered relation vector did not sort non-source relations by recovered priority")) {
			return 1;
		}
	}

	{
		std::vector<GeneratorRelationOwnerState4a218c> owners(4);
		for (int32_t index = 0; index < 4; ++index) {
			owners[size_t(index)].owner_vector_index = index;
			owners[size_t(index)].runtime_zone_index = index;
			owners[size_t(index)].source_pointer_type_0x04_known = true;
			owners[size_t(index)].source_pointer_type_0x04 = 0;
			owners[size_t(index)].terrain_policy_0x0c_known = true;
			owners[size_t(index)].terrain_policy_0x0c = 0;
		}
		GeneratorRelationRecordState4a218c edge_0_to_1;
		edge_0_to_1.target_runtime_zone_index = 1;
		owners[0].relation_records.push_back(edge_0_to_1);
		owners[0].relation_record_count = int32_t(owners[0].relation_records.size());
		GeneratorRelationRecordState4a218c edge_1_to_2;
		edge_1_to_2.target_runtime_zone_index = 2;
		owners[1].relation_records.push_back(edge_1_to_2);
		owners[1].relation_record_count = int32_t(owners[1].relation_records.size());
		GeneratorRelationRecordState4a218c edge_2_to_3;
		edge_2_to_3.target_runtime_zone_index = 3;
		owners[2].relation_records.push_back(edge_2_to_3);
		owners[2].relation_record_count = int32_t(owners[2].relation_records.size());
		owners[1].source_pointer_type_0x04 = 3;
		owners[2].terrain_policy_0x0c = 8;
		H3MapedRng priority_rng;
		priority_rng.state = 1U;
		const RewardGuardRelationPriorityResult4ad7f7 priority_result =
				aurelion::h3maped_rmg_core::reward_guard_relation_priority_ordering_0x4ad7f7(owners, 0, priority_rng, false);
		if (!require(priority_result.applied
						&& priority_result.ordered_vector_0x4ccecb_built
						&& priority_result.ordered_vector_ready_for_0x4aa9b7
						&& priority_result.descriptor_filter_unknown_count == 0,
					"0x4ad7f7 recovered field filters did not build an ordered vector from known relation owner fields")) {
			return 1;
		}
		if (!require(priority_result.source_pointer_type_0x04_reject_count == 1
						&& priority_result.terrain_policy_0x0c_reject_count == 1,
					"0x4ad7f7 recovered source-type and terrain-policy rejects were not applied")) {
			return 1;
		}
		if (!require(priority_result.ordered_owner_vector_indexes_0x4ccecb.size() == 1
						&& priority_result.ordered_owner_vector_indexes_0x4ccecb[0] == 3,
					"0x4ad7f7 recovered filters did not leave only the source-backed passing relation")) {
			return 1;
		}
	}

	{
		std::vector<aurelion::h3maped_rmg_core::RewardGuardProjectionGlobalEntry4ad947> global_entries(0x90);
		std::vector<uint8_t> used_flags(0x90, 0U);
		for (int32_t index = 0; index < 0x90; ++index) {
			global_entries[size_t(index)].entry_index = index;
			global_entries[size_t(index)].flag_byte_0x00_known = true;
			global_entries[size_t(index)].flag_byte_0x00 = 0U;
			global_entries[size_t(index)].disabled_byte_0x10_known = true;
			global_entries[size_t(index)].disabled_byte_0x10 = 0U;
		}
		global_entries[5].flag_byte_0x00 = 0x02U;
		global_entries[7].flag_byte_0x00 = 0x02U;
		global_entries[9].flag_byte_0x00 = 0x02U;
		global_entries[11].flag_byte_0x00 = 0x02U;
		global_entries[11].disabled_byte_0x10 = 1U;
		used_flags[7] = 1U;
		H3MapedRng projection_driver_rng;
		projection_driver_rng.state = 1U;
		const auto projection_driver =
				aurelion::h3maped_rmg_core::reward_guard_projection_driver_select_global_entry_0x4ad947(global_entries, used_flags, projection_driver_rng);
		if (!require(projection_driver.applied
						&& projection_driver.scanned_entry_count == 0x90
						&& projection_driver.eligible_count == 2
						&& projection_driver.disabled_reject_count == 1
						&& projection_driver.used_flag_reject_count == 1
						&& projection_driver.flag_bit_reject_count == 0x90 - 4
						&& projection_driver.generator_0x10b4_written
						&& projection_driver.generator_0x10b4_value
						&& projection_driver.rng_value_0x4e7276 == 41
						&& projection_driver.selected_eligible_ordinal == 1
						&& projection_driver.selected_global_entry_index == 9
						&& projection_driver.projection_record_selected_global_index_0x1c_written
						&& projection_driver_rng.state == 0x0029e2c0U,
					"0x4ad947 projection driver did not scan/select global entry using recovered 0x1024/0x10b4/RNG rules")) {
			return 1;
		}
		for (aurelion::h3maped_rmg_core::RewardGuardProjectionGlobalEntry4ad947 &entry : global_entries) {
			entry.flag_byte_0x00 = 0U;
			entry.disabled_byte_0x10 = 0U;
		}
		H3MapedRng no_entry_rng;
		no_entry_rng.state = 1U;
		const auto no_entry_projection_driver =
				aurelion::h3maped_rmg_core::reward_guard_projection_driver_select_global_entry_0x4ad947(global_entries, used_flags, no_entry_rng);
		if (!require(!no_entry_projection_driver.applied
						&& no_entry_projection_driver.eligible_count == 0
						&& no_entry_projection_driver.generator_0x10b4_written
						&& no_entry_projection_driver.blocked_reason == "0x4ad947_projection_global_table_no_eligible_entries"
						&& no_entry_rng.state == 1U,
					"0x4ad947 projection driver did not fail closed without eligible global entries before consuming RNG")) {
			return 1;
		}
		global_entries[3].flag_byte_0x00_known = false;
		const auto unknown_projection_driver =
				aurelion::h3maped_rmg_core::reward_guard_projection_driver_select_global_entry_0x4ad947(global_entries, used_flags, no_entry_rng);
		if (!require(!unknown_projection_driver.applied
						&& unknown_projection_driver.field_unknown_count == 1
						&& unknown_projection_driver.blocked_reason == "0x4ad947_projection_global_table_entry_fields_missing",
					"0x4ad947 projection driver did not fail closed on unknown global-table fields")) {
			return 1;
		}
	}

	{
		GeneratorObjectPrivateState selected_create_state;
		selected_create_state.reward_guard_candidate_vector_10f4_10f8.present = true;
		selected_create_state.reward_guard_candidate_vector_10f4_10f8.contents_known = true;
		selected_create_state.reward_guard_candidate_records_10f4_10f8_contents_known = true;
		selected_create_state.descriptor_counter_table_0x1110_present = true;
		selected_create_state.descriptor_counter_table_0x1110_contents_known = true;
		selected_create_state.descriptor_counter_table_0x1110.assign(
				size_t(aurelion::h3maped_rmg_core::DESCRIPTOR_COUNTER_TABLE_0X1110_DWORD_COUNT),
				0U);
		selected_create_state.endpoint_cursor_0xf58_known = true;
		selected_create_state.endpoint_cursor_0xf58 = 0;
		selected_create_state.reward_guard_projection_generator_0x10b4_known = true;
		selected_create_state.reward_guard_projection_generator_0x10b4 = false;
		selected_create_state.generator_field_0x08_known = true;
		selected_create_state.generator_field_0x08 = 0;
		selected_create_state.reward_guard_slot_bytes_0xf88_known = true;
		selected_create_state.reward_guard_slot_bytes_0xf88.fill(0U);
		selected_create_state.native_object_record_key_allocator_0x4a93a2_known = true;
		selected_create_state.next_native_object_record_key_0x4a93a2 = 1U;
		selected_create_state.object_record_sequence_allocator_0xf44_known = true;
		selected_create_state.object_record_sequence_allocator_0xf44 = 1;
		selected_create_state.descriptor_vector_398_39c.present = true;
		selected_create_state.descriptor_vector_398_39c.contents_known = true;
		selected_create_state.descriptor_vector_398_39c.count_known = true;
		selected_create_state.descriptor_vector_398_39c.element_size_bytes = 4;
		selected_create_state.descriptor_vector_398_39c_source_owned = true;
		const std::vector<SourceObjectRecord0x4c> &selected_create_source_catalog =
				aurelion::h3maped_rmg_core::source_object_catalog_0x49da08();
		for (int32_t source_index = 0; source_index < int32_t(selected_create_source_catalog.size()); ++source_index) {
			const SourceObjectRecord0x4c &source_record = selected_create_source_catalog[size_t(source_index)];
			aurelion::h3maped_rmg_core::GeneratorDescriptorVectorEntry0x398 descriptor_entry;
			descriptor_entry.vector_index = source_index;
			descriptor_entry.source_catalog_index_0x49da08 = source_index;
			descriptor_entry.descriptor_type_0x1c = source_record.type_id_0x1c;
			descriptor_entry.descriptor_source_field_0x20 = source_record.subtype_0x20;
			descriptor_entry.descriptor_group_0x24 = source_record.group_0x24;
			descriptor_entry.descriptor_last_flag_0x28 = source_record.last_flag_0x28;
			descriptor_entry.descriptor_source_cell_offsets_0x2c_0x30_known = true;
			descriptor_entry.descriptor_source_cell_x_0x2c = 0;
			descriptor_entry.descriptor_source_cell_y_0x30 = 0;
			descriptor_entry.descriptor_projection_enabled_0x29 = source_record.action_count > 0;
			descriptor_entry.descriptor_dimensions_known = source_record.descriptor_mask_fields_0x34_0x48_known;
			descriptor_entry.descriptor_width_0x34 = source_record.descriptor_width_0x34;
			descriptor_entry.descriptor_height_0x38 = source_record.descriptor_height_0x38;
			descriptor_entry.descriptor_mask_a_0x3c_0x40 = source_record.descriptor_mask_a_0x3c_0x40;
			descriptor_entry.descriptor_mask_b_0x44_0x48 = source_record.descriptor_mask_b_0x44_0x48;
			descriptor_entry.source_record_copy = source_record;
			selected_create_state.descriptor_vector_entries_398_39c.push_back(descriptor_entry);
		}
		selected_create_state.descriptor_vector_entry_count_398_39c =
				int32_t(selected_create_state.descriptor_vector_entries_398_39c.size());
		selected_create_state.descriptor_vector_398_39c.count =
				selected_create_state.descriptor_vector_entry_count_398_39c;

		aurelion::h3maped_rmg_core::RewardGuardCandidateRecord4a9f1c ordinary_candidate;
		ordinary_candidate.candidate_vtable_0x00_known = true;
		ordinary_candidate.candidate_vtable_0x00 = 0x00540ba0U;
		ordinary_candidate.descriptor_type_0x04_known = true;
		ordinary_candidate.descriptor_type_0x04 = 2;
		ordinary_candidate.cursor_source_0x08_known = true;
		ordinary_candidate.cursor_source_0x08 = 0;
		ordinary_candidate.direct_value_0x0c_known = true;
		ordinary_candidate.direct_value_0x0c = 100;
		ordinary_candidate.selection_weight_0x10_known = true;
		ordinary_candidate.selection_weight_0x10 = 5;
		aurelion::h3maped_rmg_core::RewardGuardCandidateRecord4a9f1c projection_candidate;
		projection_candidate.candidate_vtable_0x00_known = true;
		projection_candidate.candidate_vtable_0x00 =
				aurelion::h3maped_rmg_core::REWARD_GUARD_CANDIDATE_VTABLE_PROJECTION_C_0X540C80;
		projection_candidate.descriptor_type_0x04_known = true;
		projection_candidate.descriptor_type_0x04 = 83;
		projection_candidate.cursor_source_0x08_known = true;
		projection_candidate.cursor_source_0x08 = 0;
		projection_candidate.direct_value_0x0c_known = true;
		projection_candidate.direct_value_0x0c = 2000;
		projection_candidate.selection_weight_0x10_known = true;
		projection_candidate.selection_weight_0x10 = 100;
		selected_create_state.reward_guard_candidate_records_10f4_10f8 = {
			ordinary_candidate,
			projection_candidate,
		};
		selected_create_state.reward_guard_candidate_record_count_10f4_10f8 = 2;
		selected_create_state.reward_guard_candidate_vector_10f4_10f8.count_known = true;
		selected_create_state.reward_guard_candidate_vector_10f4_10f8.count = 2;
		selected_create_state.source_object_resolver_state_4af785 =
				aurelion::h3maped_rmg_core::source_object_resolver_state_from_catalog_0x49db76();
		selected_create_state.source_object_resolver_state_4af785_known = true;
		const GeneratorObjectPrivateState selected_create_base_state = selected_create_state;

		GeneratorRelationOwnerState4a218c selector;
		selector.descriptor_type_counter_table_0x44_known = true;
		selector.descriptor_type_counters_0x44.assign(
				size_t(aurelion::h3maped_rmg_core::RELATION_OWNER_DESCRIPTOR_TABLE_0X44_DWORD_COUNT),
				0U);
		selector.terrain_policy_0x0c_known = true;
		selector.terrain_policy_0x0c = 1;
		H3MapedRng selected_create_rng;
		selected_create_rng.state = 1U;
		const auto selected_create =
				aurelion::h3maped_rmg_core::reward_guard_selected_create_dispatch_0x4a9f1c(
						selected_create_state,
						&selector,
						0,
						aurelion::h3maped_rmg_core::REWARD_GUARD_DESCRIPTOR_TYPE_LIMIT_DEFAULT_0X7D00,
						selected_create_rng,
						aurelion::h3maped_rmg_core::RewardGuardSelectorCallsiteArgs4a9f1c(),
						&selected_create_state.source_object_resolver_state_4af785);
		if (!require(selected_create.applied
						&& selected_create.blocked_reason.empty()
						&& selected_create.candidate_scan_count == 2
						&& selected_create.accepted_count == 2
						&& selected_create.accepted_weight_total_0x14 == 105
						&& selected_create.rng_consumed_0x4aa110
						&& selected_create.selected_candidate_index == 1
						&& selected_create.selected_candidate_vtable_known
						&& selected_create.selected_candidate_vtable_0x00 == aurelion::h3maped_rmg_core::REWARD_GUARD_CANDIDATE_VTABLE_PROJECTION_C_0X540C80
						&& selected_create.selected_object_vtable_0x00_known
						&& selected_create.selected_object_vtable_0x00 == aurelion::h3maped_rmg_core::PROJECTION_OBJECT_VTABLE_0X540B14
						&& selected_create.selected_source_record_known_0x4a9e40
						&& selected_create.candidate_decisions.size() > 1
						&& selected_create.candidate_decisions[1].descriptor_selector_0x4a9e40.selected_from_resolver_state
						&& selected_create.selected_wrapper_index_0x4af785 >= 0
						&& selected_create.selected_descriptor_vector_index_0x398 >= 0
						&& selected_create.selected_object_record_allocated_0x4aa166
						&& selected_create.selected_object_record_key_known_0x4aa166
						&& selected_create.selected_object_record_key_0x4aa166 == 1U
						&& selected_create.selected_object_sequence_0x1c_0x4aa166 == 1
						&& selected_create.selected_object_selected_value_0x20_0x4aa166 == 2000
						&& selected_create.selected_object_enabled_word_0x24_0x4aa166 == 3U
						&& selected_create.selected_score_dispatch_replayed_0x4aa151
						&& selected_create.selected_create_dispatched_0x4aa166
						&& selected_create.selected_projection_object_0x540b14_known
						&& selected_create.selected_projection_object_0x540b14.live_input_known
						&& selected_create.selected_projection_object_0x540b14.vtable_0x00_known
						&& selected_create.selected_projection_object_0x540b14.vtable_0x00 == aurelion::h3maped_rmg_core::PROJECTION_OBJECT_VTABLE_0X540B14
						&& selected_create.selected_projection_object_0x540b14.generator_context_plus_0x1c_known
						&& selected_create.selected_projection_object_0x540b14.owned_object_record_pointer_plus_0x20_known
						&& selected_create.selected_projection_object_0x540b14.owned_object_record_key_known
						&& selected_create.selected_projection_object_0x540b14.owned_object_record_key == 1U
						&& selected_create.selected_projection_object_0x540b14.owned_object_record_value_0x1c_known
						&& selected_create.selected_projection_object_0x540b14.owned_object_record_value_0x1c == 1
						&& selected_create.selected_projection_object_0x540b14.owned_object_record_value_0x20_known
						&& selected_create.selected_projection_object_0x540b14.owned_object_record_value_0x20 == 2000
						&& selected_create.selected_projection_object_0x540b14.selected_wrapper_index_0x4af785_known
						&& selected_create.selected_projection_object_0x540b14.selected_wrapper_index_0x4af785 == selected_create.selected_wrapper_index_0x4af785
						&& selected_create.selected_projection_object_0x540b14.selected_source_subtype_0x20_known
						&& selected_create.selected_projection_object_0x540b14.selected_source_subtype_0x20 == selected_create.selected_source_record_copy.subtype_0x20
						&& selected_create_state.next_native_object_record_key_0x4a93a2 == 2U
						&& selected_create_state.object_record_sequence_allocator_0xf44 == 2
						&& selected_create_state.object_record_allocation_count_0x4a93a2 == 1
						&& selected_create_rng.state == selected_create.rng_state_after_0x4aa110,
					"0x4a9f1c selected-create dispatch did not use source-owned descriptor selection, weighted RNG, and recovered 0x540c80 -> 0x49cc22 -> 0x540b14/0x4aa166 constructor behavior")) {
			return 1;
		}

		GeneratorObjectPrivateState slot_constructor_state = selected_create_base_state;
		slot_constructor_state.next_native_object_record_key_0x4a93a2 = 7U;
		slot_constructor_state.object_record_sequence_allocator_0xf44 = 11;
		slot_constructor_state.object_record_allocation_count_0x4a93a2 = 0;
		aurelion::h3maped_rmg_core::RewardGuardCandidateRecord4a9f1c slot_candidate;
		slot_candidate.candidate_vtable_0x00_known = true;
		slot_candidate.candidate_vtable_0x00 = 0x00540c20U;
		slot_candidate.descriptor_type_0x04_known = true;
		slot_candidate.descriptor_type_0x04 = 62;
		slot_candidate.cursor_source_0x08_known = true;
		slot_candidate.cursor_source_0x08 = 0;
		slot_candidate.direct_value_0x0c_known = true;
		slot_candidate.direct_value_0x0c = 10000;
		slot_candidate.selection_weight_0x10_known = true;
		slot_candidate.selection_weight_0x10 = 30;
		slot_candidate.direct_payload_field_0x14_known = true;
		slot_candidate.direct_payload_field_0x14 = 15000U;
		slot_constructor_state.reward_guard_candidate_records_10f4_10f8 = { slot_candidate };
		slot_constructor_state.reward_guard_candidate_record_count_10f4_10f8 = 1;
		slot_constructor_state.reward_guard_candidate_vector_10f4_10f8.count = 1;
		H3MapedRng slot_constructor_rng;
		slot_constructor_rng.state = 3U;
		const auto slot_constructor =
				aurelion::h3maped_rmg_core::reward_guard_selected_create_dispatch_0x4a9f1c(
						slot_constructor_state,
						&selector,
						0,
						aurelion::h3maped_rmg_core::REWARD_GUARD_DESCRIPTOR_TYPE_LIMIT_DEFAULT_0X7D00,
						slot_constructor_rng,
						aurelion::h3maped_rmg_core::RewardGuardSelectorCallsiteArgs4a9f1c(),
						&slot_constructor_state.source_object_resolver_state_4af785);
		const uint32_t selected_slot =
				slot_constructor.selected_object_record_field_0x24_known_0x4aa166
						? slot_constructor.selected_object_record_field_0x24_0x4aa166
						: uint32_t(slot_constructor_state.reward_guard_slot_bytes_0xf88.size());
		if (!require(slot_constructor.applied
						&& slot_constructor.blocked_reason.empty()
						&& slot_constructor.accepted_count == 1
						&& slot_constructor.selected_candidate_vtable_known
						&& slot_constructor.selected_candidate_vtable_0x00 == 0x00540c20U
						&& slot_constructor.selected_object_vtable_0x00_known
						&& slot_constructor.selected_object_vtable_0x00 == aurelion::h3maped_rmg_core::OBJECT_RECORD_VTABLE_0X540B3C
						&& slot_constructor.selected_object_record_key_known_0x4aa166
						&& slot_constructor.selected_object_record_key_0x4aa166 == 7U
						&& slot_constructor.selected_object_sequence_0x1c_0x4aa166 == 11
						&& slot_constructor.selected_object_record_field_0x20_known_0x4aa166
						&& slot_constructor.selected_object_record_field_0x20_0x4aa166 == 11U
						&& slot_constructor.selected_object_record_field_0x24_known_0x4aa166
						&& selected_slot < slot_constructor_state.reward_guard_slot_bytes_0xf88.size()
						&& slot_constructor_state.reward_guard_slot_bytes_0xf88[size_t(selected_slot)] == 1U
						&& slot_constructor.selected_object_record_field_0x28_known_0x4aa166
						&& slot_constructor.selected_object_record_field_0x28_0x4aa166 == 15000U
						&& slot_constructor_state.reward_guard_slot_0x4ad640_allocation_count == 1
						&& slot_constructor_state.next_native_object_record_key_0x4a93a2 == 8U
						&& slot_constructor_state.object_record_sequence_allocator_0xf44 == 12
						&& slot_constructor_state.object_record_allocation_count_0x4a93a2 == 1
						&& slot_constructor_rng.state != slot_constructor.rng_state_after_0x4aa110,
					"0x49c8f3 0x540c20 constructor did not allocate 0x4ad640 slot state and carry exact record +0x20/+0x24/+0x28 fields")) {
			return 1;
		}

		GeneratorObjectPrivateState selected_object_state = selected_create_state;
		selected_object_state.next_native_object_record_key_0x4a93a2 = 1U;
		selected_object_state.object_record_sequence_allocator_0xf44 = 1;
		selected_object_state.object_record_allocation_count_0x4a93a2 = 0;
		H3MapedRng selected_object_rng;
		selected_object_rng.state = 1U;
		auto selected_object_wrapper_construct =
				aurelion::h3maped_rmg_core::reward_guard_wrapper_construct_0x49ce04();
		if (!require(selected_object_wrapper_construct.applied,
					"0x49ce04 wrapper construct failed before selected-object callsite replay")) {
			return 1;
		}
		auto selected_object =
				aurelion::h3maped_rmg_core::reward_guard_selected_object_create_shell_0x4aa1db(
						selected_object_state,
						selected_object_wrapper_construct.wrapper,
						&selector,
						0,
						2000,
						selected_object_rng);
		const std::string selected_object_callsite_detail =
				"applied=" + std::to_string(selected_object.applied ? 1 : 0)
				+ " blocker=" + selected_object.blocked_reason
				+ " policy20=" + std::to_string(int(selected_object.selector_0x4a9f1c.callsite_args.policy_extent_byte_0x20))
				+ " gate=" + std::to_string(selected_object.selector_0x4a9f1c.policy_extent_gate_invoked_0x20 ? 1 : 0)
				+ " accepted=" + std::to_string(selected_object.selector_0x4a9f1c.accepted_count)
				+ " key_known=" + std::to_string(selected_object.selector_0x4a9f1c.selected_object_record_key_known_0x4aa166 ? 1 : 0)
				+ " key=" + std::to_string(selected_object.selector_0x4a9f1c.selected_object_record_key_0x4aa166)
				+ " stamp=" + std::to_string(selected_object.initial_body_stamp_count_0x49abd6);
		if (!require(selected_object.selector_0x4a9f1c.callsite_args.policy_extent_byte_0x20 == 0U
						&& !selected_object.selector_0x4a9f1c.policy_extent_gate_invoked_0x20
						&& selected_object.selector_0x4a9f1c.accepted_count >= 1
						&& selected_object.selector_0x4a9f1c.selected_object_record_key_known_0x4aa166
						&& selected_object.selector_0x4a9f1c.selected_object_record_key_0x4aa166 == 1U,
					"0x4aa1db selected-object helper did not pass policy word into 0x4a9f1c stack +0x20: " + selected_object_callsite_detail)) {
			return 1;
		}
		const auto &selected_object_members =
				selected_object_wrapper_construct.wrapper.selected_members_0x2c_0x30;
		const std::string selected_object_projection_detail =
				"applied=" + std::to_string(selected_object.applied ? 1 : 0)
				+ " blocker=" + selected_object.blocked_reason
				+ " selected_projection=" + std::to_string(selected_object.selected_projection_object_0x540b14_known ? 1 : 0)
				+ " member_count=" + std::to_string(selected_object_members.size())
				+ " selected_vtable_known=" + std::to_string(selected_object.selected_object_vtable_0x00_known ? 1 : 0)
				+ " selected_vtable=" + std::to_string(selected_object.selected_object_vtable_0x00);
		if (!require(selected_object.applied
						&& selected_object.selected_projection_object_0x540b14_known
						&& selected_object_members.size() == 1
						&& selected_object_members[0].projection_object_0x540b14_known
						&& selected_object_members[0].projection_object_0x540b14.live_input_known
						&& selected_object_members[0].projection_object_0x540b14.vtable_0x00_known
						&& selected_object_members[0].projection_object_0x540b14.vtable_0x00 == aurelion::h3maped_rmg_core::PROJECTION_OBJECT_VTABLE_0X540B14
						&& selected_object_members[0].projection_object_0x540b14.owned_object_record_pointer_plus_0x20_known
						&& selected_object_members[0].projection_object_0x540b14.owned_object_record_key_known
						&& selected_object_members[0].projection_object_0x540b14.owned_object_record_key == selected_object_members[0].object_record_key
						&& selected_object_members[0].projection_object_0x540b14.owned_object_record_value_0x1c_known
						&& selected_object_members[0].projection_object_0x540b14.owned_object_record_value_0x1c == selected_object_members[0].object_record_sequence_0x1c
						&& selected_object_members[0].projection_object_0x540b14.owned_object_record_value_0x20_known
						&& selected_object_members[0].projection_object_0x540b14.owned_object_record_value_0x20 == selected_object_members[0].object_record_selected_index_0x20
						&& selected_object_members[0].selected_wrapper_index_0x4af785 >= 0
						&& selected_object_members[0].projection_object_0x540b14.selected_wrapper_index_0x4af785_known
						&& selected_object_members[0].projection_object_0x540b14.selected_wrapper_index_0x4af785 == selected_object_members[0].selected_wrapper_index_0x4af785,
					"0x4aa1db/0x4aa166 did not preserve recovered 0x540b14 projection object through wrapper member creation: " + selected_object_projection_detail)) {
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
		if (!require(record.object_reference_vector_contents_known
						&& record.object_reference_count == 0
						&& record.object_references_0x04_0x08.empty(),
					"0x499e65/0x499ea3 reset did not expose a known-empty object-reference vector")) {
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
		if (!require(record.byte_0x2b_known && record.byte_0x2b_known_mask == 0xffU
						&& record.byte_0x2b == uint8_t((aurelion::h3maped_rmg_core::GENERATED_CELL_INITIAL_WORD_0X28_VALUE >> 24U) & 0xffU),
					"generated-cell validity byte +0x2b reset must mirror high byte of +0x28")) {
			return 1;
		}
		const uint32_t terrain_word_0x24 =
				aurelion::h3maped_rmg_core::generated_cell_49acf6_word24(0x1234abcdU, 5, 7);
		if (!require(terrain_word_0x24 == 0x123481c5U,
					"0x49acf6 must preserve generated-cell +0x24 bits 14..31 while writing terrain/art bits")) {
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
		GeneratedCellRecordGrid0x30 high_owner_grid = aurelion::h3maped_rmg_core::generated_cell_record_grid_reset_0x49a072(3, 2, 1);
		for (int32_t y = 0; y < 2; ++y) {
			for (int32_t x = 0; x < 3; ++x) {
				GeneratedCellRecord0x30 &cell = high_owner_grid.records[size_t(y * 3 + x)];
				const bool source_channel_cell = x == 1;
				cell.word_0x20 = aurelion::h3maped_rmg_core::generated_cell_zone_word_4a325d(cell.word_0x20, source_channel_cell ? 0 : 1);
				cell.word_0x24 = aurelion::h3maped_rmg_core::generated_cell_49acf6_word24(cell.word_0x24, 0, 0);
				cell.word_0x28 |= aurelion::h3maped_rmg_core::CELL_DECOR_READY_BIT_25;
				if (!require(aurelion::h3maped_rmg_core::generated_cell_4a5767_reset_projection(cell), "test setup 0x4a5767 reset failed before 0x49a318 high-owner propagation")) {
					return 1;
				}
			}
		}
		GeneratorRelationOwnerState4a218c high_owner_seed;
		high_owner_seed.owner_vector_index = 0;
		high_owner_seed.runtime_zone_index = 0;
		high_owner_seed.coordinate_triple_0x10_0x18_known = true;
		high_owner_seed.coordinate_x_0x10 = 1;
		high_owner_seed.coordinate_y_0x14 = 0;
		high_owner_seed.coordinate_level_0x18 = 0;
		const RelationHighOwnerPropagationResult49a318 high_owner_result =
				aurelion::h3maped_rmg_core::relation_high_owner_propagation_49a318(high_owner_grid, { high_owner_seed });
		if (!require(high_owner_result.applied && high_owner_result.grid_available, "0x49a318 high-owner propagation did not run on a valid generated-cell grid")) {
			return 1;
		}
		if (!require(high_owner_result.seed_attempt_count == 1 && high_owner_result.seed_blocked_count == 0, "0x49a318 high-owner propagation did not accept the source relation seed")) {
			return 1;
		}
		if (!require(high_owner_result.cross_owner_high_byte_write_count >= 4 && high_owner_result.owner_high_byte_materialized_count >= 4, "0x49a318 high-owner propagation did not write cross-owner high bytes")) {
			return 1;
		}
		if (!require((high_owner_grid.records[1].word_0x1c & 0x0000ffffU) == 0U
					&& high_owner_grid.records[1].word_0x10 == aurelion::h3maped_rmg_core::RELATION_RESET_COORD_MINUS_ONE
					&& high_owner_grid.records[1].word_0x14 == aurelion::h3maped_rmg_core::RELATION_RESET_COORD_MINUS_ONE
					&& high_owner_grid.records[1].word_0x18 == aurelion::h3maped_rmg_core::RELATION_RESET_COORD_MINUS_ONE,
					"0x49a318 high-owner propagation did not clear the source projection fields")) {
			return 1;
		}
		if (!require((high_owner_grid.records[4].word_0x1c & 0x0000ffffU) == 0U
					&& high_owner_grid.records[4].word_0x10 == 1U
					&& high_owner_grid.records[4].word_0x14 == 0U
					&& high_owner_grid.records[4].word_0x18 == 0U,
					"0x49a318 high-owner propagation did not apply recovered same-owner zero-score projection fields")) {
			return 1;
		}
		if (!require(((high_owner_grid.records[0].word_0x1c >> 16U) & 0xffffU) == 10U
					&& ((high_owner_grid.records[0].word_0x28 >> 12U) & 0x7U) == 0U,
					"0x49a318 high-owner propagation did not write cross-owner score and reverse direction fields")) {
			return 1;
		}
		if (!require(((high_owner_grid.records[0].word_0x20 >> 24U) & 0xffU) == 0U
					&& ((high_owner_grid.records[2].word_0x20 >> 24U) & 0xffU) == 0U,
					"0x49a318 high-owner propagation did not materialize source owner in +0x20 byte3")) {
			return 1;
		}
		if (!require(aurelion::h3maped_rmg_core::object_metadata_flag_0x598300(3, 0)
					&& !aurelion::h3maped_rmg_core::object_metadata_flag_0x598300(3, 2)
					&& !aurelion::h3maped_rmg_core::object_metadata_flag_0x598300(0, 1)
					&& aurelion::h3maped_rmg_core::object_metadata_flag_0x598300(5, 2),
					"0x598300 recovered metadata policy flags are not exposed with the expected +0/+1/+2 bytes")) {
			return 1;
		}
		auto prepare_high_owner_cell = [](GeneratedCellRecordGrid0x30 &grid, int32_t x, int32_t y, int32_t owner, int32_t terrain) {
			GeneratedCellRecord0x30 &cell = grid.records[size_t(y * grid.width + x)];
			cell.word_0x20 = aurelion::h3maped_rmg_core::generated_cell_zone_word_4a325d(cell.word_0x20, owner);
			cell.word_0x24 = (cell.word_0x24 & ~uint32_t(0x3fU)) | (uint32_t(terrain) & 0x3fU);
			cell.word_0x28 |= aurelion::h3maped_rmg_core::CELL_DECOR_READY_BIT_25;
			return aurelion::h3maped_rmg_core::generated_cell_4a5767_reset_projection(cell);
		};
		auto add_bit22_object_reference = [](GeneratedCellRecordGrid0x30 &grid, int32_t x, int32_t y, uint32_t object_record_key) {
			GeneratedCellRecord0x30 &cell = grid.records[size_t(y * grid.width + x)];
			cell.word_0x28 |= aurelion::h3maped_rmg_core::CELL_ACTION_CONTROL_BIT_22;
			cell.object_reference_vector_contents_known = true;
			cell.object_references_0x04_0x08 = { object_record_key };
			cell.object_reference_count = 1;
		};
		auto object_record = [](uint32_t object_record_key, int32_t descriptor_type) {
			ObjectRecordReference4a54a7 record;
			record.object_record_key = object_record_key;
			record.descriptor_type_0x1c = descriptor_type;
			return record;
		};
		{
			GeneratedCellRecordGrid0x30 repeated_grid = aurelion::h3maped_rmg_core::generated_cell_record_grid_reset_0x49a072(3, 1, 1);
			if (!require(prepare_high_owner_cell(repeated_grid, 0, 0, 0, 0)
						&& prepare_high_owner_cell(repeated_grid, 1, 0, 1, 0)
						&& prepare_high_owner_cell(repeated_grid, 2, 0, 2, 0),
						"test setup for repeated 0x49a318 persisted-score case failed")) {
				return 1;
			}
			GeneratorRelationOwnerState4a218c first_seed;
			first_seed.owner_vector_index = 0;
			first_seed.runtime_zone_index = 0;
			first_seed.coordinate_triple_0x10_0x18_known = true;
			first_seed.coordinate_x_0x10 = 0;
			first_seed.coordinate_y_0x14 = 0;
			first_seed.coordinate_level_0x18 = 0;
			const RelationHighOwnerPropagationResult49a318 first_result =
					aurelion::h3maped_rmg_core::relation_high_owner_propagation_49a318(repeated_grid, { first_seed });
			if (!require(first_result.cross_owner_high_byte_write_count >= 1
						&& ((repeated_grid.records[1].word_0x20 >> 24U) & 0xffU) == 0U
						&& ((repeated_grid.records[1].word_0x1c >> 16U) & 0xffffU) == 10U,
						"0x49a318 first repeated-score setup did not write the expected high-owner score")) {
				return 1;
			}
			GeneratorRelationOwnerState4a218c second_seed;
			second_seed.owner_vector_index = 2;
			second_seed.runtime_zone_index = 2;
			second_seed.coordinate_triple_0x10_0x18_known = true;
			second_seed.coordinate_x_0x10 = 2;
			second_seed.coordinate_y_0x14 = 0;
			second_seed.coordinate_level_0x18 = 0;
			const RelationHighOwnerPropagationResult49a318 second_result =
					aurelion::h3maped_rmg_core::relation_high_owner_propagation_49a318(repeated_grid, { second_seed });
			if (!require(second_result.seed_attempt_count == 1 && second_result.seed_blocked_count == 0,
						"0x49a318 repeated-score second source seed was not accepted")) {
				return 1;
			}
			if (!require(((repeated_grid.records[1].word_0x20 >> 24U) & 0xffU) == 0U
						&& ((repeated_grid.records[1].word_0x1c >> 16U) & 0xffffU) == 10U,
						"0x49a318 must compare against persisted +0x1c high score and not overwrite an equal prior high-owner projection")) {
				return 1;
			}
		}
		{
			GeneratedCellRecordGrid0x30 metadata_grid = aurelion::h3maped_rmg_core::generated_cell_record_grid_reset_0x49a072(2, 2, 1);
			if (!require(prepare_high_owner_cell(metadata_grid, 0, 1, 0, 0)
						&& prepare_high_owner_cell(metadata_grid, 1, 0, 1, 0)
						&& prepare_high_owner_cell(metadata_grid, 1, 1, 1, 9),
						"test setup for 0x49a318 source metadata reduced-direction case failed")) {
				return 1;
			}
			add_bit22_object_reference(metadata_grid, 0, 1, 100U);
			GeneratorRelationOwnerState4a218c metadata_seed;
			metadata_seed.owner_vector_index = 0;
			metadata_seed.runtime_zone_index = 0;
			metadata_seed.coordinate_triple_0x10_0x18_known = true;
			metadata_seed.coordinate_x_0x10 = 0;
			metadata_seed.coordinate_y_0x14 = 1;
			metadata_seed.coordinate_level_0x18 = 0;
			const std::vector<ObjectRecordReference4a54a7> records = { object_record(100U, 0) };
			const RelationHighOwnerPropagationResult49a318 metadata_result =
					aurelion::h3maped_rmg_core::relation_high_owner_propagation_49a318(metadata_grid, { metadata_seed }, &records);
			if (!require(metadata_result.object_metadata_gate_complete
						&& metadata_result.object_metadata_source_reduced_direction_count == 1
						&& metadata_result.cross_owner_high_byte_write_count == 0,
						"0x49a318 did not apply the recovered source bit22 metadata +1 reduced five-direction policy")) {
				return 1;
			}
		}
		{
			GeneratedCellRecordGrid0x30 metadata_grid = aurelion::h3maped_rmg_core::generated_cell_record_grid_reset_0x49a072(2, 1, 1);
			if (!require(prepare_high_owner_cell(metadata_grid, 0, 0, 0, 0)
						&& prepare_high_owner_cell(metadata_grid, 1, 0, 1, 0),
						"test setup for 0x49a318 candidate metadata +0/+2 reject case failed")) {
				return 1;
			}
			add_bit22_object_reference(metadata_grid, 1, 0, 101U);
			GeneratorRelationOwnerState4a218c metadata_seed;
			metadata_seed.owner_vector_index = 0;
			metadata_seed.runtime_zone_index = 0;
			metadata_seed.coordinate_triple_0x10_0x18_known = true;
			metadata_seed.coordinate_x_0x10 = 0;
			metadata_seed.coordinate_y_0x14 = 0;
			metadata_seed.coordinate_level_0x18 = 0;
			const std::vector<ObjectRecordReference4a54a7> records = { object_record(101U, 3) };
			const RelationHighOwnerPropagationResult49a318 metadata_result =
					aurelion::h3maped_rmg_core::relation_high_owner_propagation_49a318(metadata_grid, { metadata_seed }, &records);
			if (!require(metadata_result.object_metadata_gate_complete
						&& metadata_result.object_metadata_candidate_scan_count == 1
						&& metadata_result.object_metadata_candidate_reject_count == 1
						&& metadata_result.cross_owner_high_byte_write_count == 0,
						"0x49a318 did not reject candidate bit22 metadata where +0 is set and +2 is clear")) {
				return 1;
			}
		}
		{
			GeneratedCellRecordGrid0x30 metadata_grid = aurelion::h3maped_rmg_core::generated_cell_record_grid_reset_0x49a072(2, 2, 1);
			if (!require(prepare_high_owner_cell(metadata_grid, 0, 0, 0, 0)
						&& prepare_high_owner_cell(metadata_grid, 1, 0, 1, 9)
						&& prepare_high_owner_cell(metadata_grid, 0, 1, 1, 9)
						&& prepare_high_owner_cell(metadata_grid, 1, 1, 1, 0),
						"test setup for 0x49a318 candidate metadata direction reject case failed")) {
				return 1;
			}
			add_bit22_object_reference(metadata_grid, 1, 1, 102U);
			GeneratorRelationOwnerState4a218c metadata_seed;
			metadata_seed.owner_vector_index = 0;
			metadata_seed.runtime_zone_index = 0;
			metadata_seed.coordinate_triple_0x10_0x18_known = true;
			metadata_seed.coordinate_x_0x10 = 0;
			metadata_seed.coordinate_y_0x14 = 0;
			metadata_seed.coordinate_level_0x18 = 0;
			const std::vector<ObjectRecordReference4a54a7> records = { object_record(102U, 0) };
			const RelationHighOwnerPropagationResult49a318 metadata_result =
					aurelion::h3maped_rmg_core::relation_high_owner_propagation_49a318(metadata_grid, { metadata_seed }, &records);
			if (!require(metadata_result.object_metadata_gate_complete
						&& metadata_result.object_metadata_candidate_scan_count == 1
						&& metadata_result.object_metadata_candidate_reject_count == 1
						&& metadata_result.cross_owner_high_byte_write_count == 0,
						"0x49a318 did not reject candidate bit22 metadata directions 1..3 when +1 is clear")) {
				return 1;
			}
		}
		{
			GeneratedCellRecordGrid0x30 metadata_grid = aurelion::h3maped_rmg_core::generated_cell_record_grid_reset_0x49a072(2, 1, 1);
			if (!require(prepare_high_owner_cell(metadata_grid, 0, 0, 0, 0)
						&& prepare_high_owner_cell(metadata_grid, 1, 0, 1, 0),
						"test setup for 0x49a318 candidate metadata pass case failed")) {
				return 1;
			}
			add_bit22_object_reference(metadata_grid, 1, 0, 103U);
			GeneratorRelationOwnerState4a218c metadata_seed;
			metadata_seed.owner_vector_index = 0;
			metadata_seed.runtime_zone_index = 0;
			metadata_seed.coordinate_triple_0x10_0x18_known = true;
			metadata_seed.coordinate_x_0x10 = 0;
			metadata_seed.coordinate_y_0x14 = 0;
			metadata_seed.coordinate_level_0x18 = 0;
			const std::vector<ObjectRecordReference4a54a7> records = { object_record(103U, 5) };
			const RelationHighOwnerPropagationResult49a318 metadata_result =
					aurelion::h3maped_rmg_core::relation_high_owner_propagation_49a318(metadata_grid, { metadata_seed }, &records);
			if (!require(metadata_result.object_metadata_gate_complete
						&& metadata_result.object_metadata_candidate_scan_count == 1
						&& metadata_result.object_metadata_candidate_reject_count == 0
						&& metadata_result.cross_owner_high_byte_write_count == 1
						&& ((metadata_grid.records[1].word_0x20 >> 24U) & 0xffU) == 0U
						&& ((metadata_grid.records[1].word_0x1c >> 16U) & 0xffffU) == 10U,
						"0x49a318 did not allow passing candidate bit22 metadata through normal cross-owner writes")) {
				return 1;
			}
		}
		GeneratedCellRecordGrid0x30 scan_consumer_grid = aurelion::h3maped_rmg_core::generated_cell_record_grid_reset_0x49a072(3, 1, 1);
		for (int32_t x = 0; x < 3; ++x) {
			GeneratedCellRecord0x30 &cell = scan_consumer_grid.records[size_t(x)];
			cell.word_0x20 = aurelion::h3maped_rmg_core::generated_cell_zone_word_4a325d(cell.word_0x20, 0);
			cell.word_0x24 = aurelion::h3maped_rmg_core::generated_cell_49acf6_word24(cell.word_0x24, 0, 0);
			cell.word_0x28 |= aurelion::h3maped_rmg_core::CELL_DECOR_READY_BIT_25;
			if (!require(aurelion::h3maped_rmg_core::generated_cell_4a5767_reset_projection(cell), "test setup 0x4a5767 reset failed before relation scan-consumer pass")) {
				return 1;
			}
			cell.word_0x1c = (cell.word_0x1c & 0xffff0000U) | 1U;
			cell.word_0x10 = aurelion::h3maped_rmg_core::RELATION_RESET_COORD_MINUS_ONE;
			cell.word_0x14 = 0U;
			cell.word_0x18 = 0U;
			aurelion::h3maped_rmg_core::generated_cell_49a932(cell, true);
		}
		scan_consumer_grid.records[1].word_0x2c |= 0x01U;
		GeneratorRelationOwnerState4a218c scan_consumer_owner;
		scan_consumer_owner.owner_vector_index = 0;
		scan_consumer_owner.runtime_zone_index = 0;
		scan_consumer_owner.coordinate_triple_0x10_0x18_known = true;
		scan_consumer_owner.coordinate_level_0x18 = 0;
		scan_consumer_owner.scan_bounds_0x20_0x2c_known = true;
		scan_consumer_owner.scan_bound_low_x_0x20 = 0;
		scan_consumer_owner.scan_bound_low_y_0x24 = 0;
		scan_consumer_owner.scan_bound_high_x_0x28 = 2;
		scan_consumer_owner.scan_bound_high_y_0x2c = 1;
		const auto scan_consumer_result =
				aurelion::h3maped_rmg_core::relation_scan_consumers_after_0x4a1f3b_bounds_4a5767(scan_consumer_grid, { scan_consumer_owner });
		if (!require(scan_consumer_result.applied
					&& scan_consumer_result.grid_available
					&& scan_consumer_result.owner_scan_count == 1
					&& scan_consumer_result.scanned_cell_count == 2
					&& scan_consumer_result.projected_chain_call_count == 0
					&& scan_consumer_result.projected_chain_occupied_stamp_count == 0
					&& scan_consumer_result.projected_chain_object_branch_blocked_count == 0
					&& scan_consumer_result.no_object_projection_chain_complete,
				"relation scan consumer did not apply recovered 0x49a318 zero-score low-word skip before projection chain")) {
			return 1;
		}
		if (!require((scan_consumer_grid.records[0].word_0x28 & aurelion::h3maped_rmg_core::CELL_OCCUPIED_BLOCKED_BIT_27) != 0U
						&& (scan_consumer_grid.records[0].word_0x28 & aurelion::h3maped_rmg_core::CELL_DECOR_CANDIDATE_BIT_26) == 0U,
					"relation scan consumer did not stamp occupied bit27 and clear bit26 through 0x4a5a23")) {
			return 1;
		}
		{
			GeneratedCellRecordGrid0x30 single_ref_seed_grid =
					aurelion::h3maped_rmg_core::generated_cell_record_grid_reset_0x49a072(2, 1, 1);
			for (int32_t x = 0; x < 2; ++x) {
				GeneratedCellRecord0x30 &cell = single_ref_seed_grid.records[size_t(x)];
				cell.word_0x20 = aurelion::h3maped_rmg_core::generated_cell_zone_word_4a325d(cell.word_0x20, 0);
				cell.word_0x24 = aurelion::h3maped_rmg_core::generated_cell_49acf6_word24(cell.word_0x24, x == 0 ? 9 : 0, 0);
				cell.word_0x28 |= aurelion::h3maped_rmg_core::CELL_DECOR_READY_BIT_25;
				cell.object_reference_vector_contents_known = true;
				if (!require(aurelion::h3maped_rmg_core::generated_cell_4a5767_reset_projection(cell),
							"single-ref relation seed setup 0x4a5767 reset failed")) {
					return 1;
				}
			}
			GeneratedCellRecord0x30 &single_ref_seed = single_ref_seed_grid.records[1];
			single_ref_seed.word_0x28 |= aurelion::h3maped_rmg_core::CELL_OCCUPIED_BLOCKED_BIT_27;
			single_ref_seed.object_references_0x04_0x08 = { 0x1200U };
			single_ref_seed.object_reference_count = 1;
			GeneratorRelationOwnerState4a218c single_ref_owner;
			single_ref_owner.owner_vector_index = 0;
			single_ref_owner.runtime_zone_index = 0;
			single_ref_owner.coordinate_triple_0x10_0x18_known = true;
			single_ref_owner.coordinate_x_0x10 = 0;
			single_ref_owner.coordinate_y_0x14 = 0;
			single_ref_owner.coordinate_level_0x18 = 0;
			single_ref_owner.scan_bounds_0x20_0x2c_known = true;
			single_ref_owner.scan_bound_low_x_0x20 = 0;
			single_ref_owner.scan_bound_low_y_0x24 = 0;
			single_ref_owner.scan_bound_high_x_0x28 = 2;
			single_ref_owner.scan_bound_high_y_0x2c = 1;
			const auto single_ref_seed_result =
					aurelion::h3maped_rmg_core::relation_scan_consumers_after_0x4a1f3b_bounds_4a5767(
							single_ref_seed_grid,
							{ single_ref_owner });
			if (!require(single_ref_seed_result.applied
						&& single_ref_seed_result.projected_chain_call_count == 0
						&& (single_ref_seed_grid.records[1].word_0x1c & 0x0000ffffU) == 0U,
					"relation scan consumer did not accept recovered single-entry object-reference span as 0x49a318 seed")) {
				return 1;
			}
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
		if (!require(!aurelion::h3maped_rmg_core::relation_boundary_triggers_candidate_0x4a4c8e(true, 0, true)
						&& aurelion::h3maped_rmg_core::relation_boundary_triggers_candidate_0x4a4c8e(true, 1, true)
						&& aurelion::h3maped_rmg_core::relation_boundary_triggers_candidate_0x4a4c8e(true, 1, false)
						&& aurelion::h3maped_rmg_core::relation_boundary_triggers_candidate_0x4a4c8e(false, 1, true),
					"0x4a4c8e relation boundary trigger must follow recovered level-one branch")) {
			return 1;
		}
		if (!require(aurelion::h3maped_rmg_core::generated_cell_49abd6_action_stamp(mutable_record), "record 0x49abd6 action stamp did not mutate bit22/bit27")) {
			return 1;
		}
		if (!require((mutable_record.word_0x28 & aurelion::h3maped_rmg_core::CELL_ACTION_CONTROL_BIT_22) != 0U && (mutable_record.word_0x28 & aurelion::h3maped_rmg_core::CELL_OCCUPIED_BLOCKED_BIT_27) != 0U, "record 0x49abd6 action stamp did not leave bit22 and bit27 set")) {
			return 1;
		}
		if (!require(aurelion::h3maped_rmg_core::generated_cell_49a1d8_valid_record(mutable_record), "record 0x49a1d8 did not accept +0x28 bit25 with non-rock terrain")) {
			return 1;
		}
		if (!require(aurelion::h3maped_rmg_core::generated_cell_49abd6_body_reject_stamp(mutable_record), "record 0x49abd6 body reject did not clear bit25")) {
			return 1;
		}
		if (!require(mutable_record.byte_0x2b_known && mutable_record.byte_0x2b_known_mask == 0xffU && (mutable_record.byte_0x2b & 0x02U) == 0U, "record 0x49abd6 body reject did not mirror cleared +0x28 bit25 into +0x2b")) {
			return 1;
		}
		if (!require((mutable_record.word_0x28 & aurelion::h3maped_rmg_core::CELL_DECOR_READY_BIT_25) == 0U, "record 0x49abd6 body reject did not clear bit25")) {
			return 1;
		}
		if (!require(!aurelion::h3maped_rmg_core::generated_cell_49a1d8_valid_record(mutable_record), "record 0x49a1d8 accepted after +0x2b bit0x02 was cleared")) {
			return 1;
		}

		GeneratedCellRecord0x30 reference_record = record;
		reference_record.object_reference_vector_contents_known = true;
		reference_record.object_references_0x04_0x08 = { 0x11111111U, 0x22222222U };
		reference_record.object_reference_count = 2;
		reference_record.word_0x20 = 0x12340005U;
		reference_record.word_0x28 |= aurelion::h3maped_rmg_core::CELL_ACTION_CONTROL_BIT_22;
		const auto first_reference_removal =
				aurelion::h3maped_rmg_core::generated_cell_object_reference_removal_0x499ee8(reference_record, 0x11111111U);
		if (!require(first_reference_removal.object_reference_vector_known
					&& first_reference_removal.object_record_found
					&& first_reference_removal.object_record_removed
					&& !first_reference_removal.object_reference_vector_empty_after
					&& !first_reference_removal.word_mutations_applied,
					"0x499ee8 first object-reference removal did not remove only the selected non-final reference")) {
			return 1;
		}
		if (!require(reference_record.object_reference_count == 1
					&& reference_record.object_references_0x04_0x08.size() == 1
					&& reference_record.object_references_0x04_0x08[0] == 0x22222222U,
					"0x499ee8 first object-reference removal left the vector/count in the wrong state")) {
			return 1;
		}
		if (!require(reference_record.word_0x20 == 0x12340005U
					&& (reference_record.word_0x28 & aurelion::h3maped_rmg_core::CELL_ACTION_CONTROL_BIT_22) != 0U,
					"0x499ee8 non-final removal mutated generated-cell words")) {
			return 1;
		}
		const auto final_reference_removal =
				aurelion::h3maped_rmg_core::generated_cell_object_reference_removal_0x499ee8(reference_record, 0x22222222U);
		if (!require(final_reference_removal.object_record_found
					&& final_reference_removal.object_record_removed
					&& final_reference_removal.object_reference_vector_empty_after
					&& final_reference_removal.word_mutations_applied,
					"0x499ee8 final object-reference removal did not report empty-vector word mutation")) {
			return 1;
		}
		if (!require(reference_record.object_reference_count == 0
					&& reference_record.object_references_0x04_0x08.empty(),
					"0x499ee8 final object-reference removal did not empty the vector/count")) {
			return 1;
		}
		if (!require(reference_record.word_0x20 == 0x12347fbcU
					&& (reference_record.word_0x28 & aurelion::h3maped_rmg_core::CELL_ACTION_CONTROL_BIT_22) == 0U
					&& (reference_record.word_0x28 & aurelion::h3maped_rmg_core::CELL_DECOR_READY_BIT_25) != 0U,
					"0x499ee8 final object-reference removal did not clear bit22, set bit25, and reset +0x20 low word")) {
			return 1;
		}
		GeneratedCellRecord0x30 unknown_reference_record = reference_record;
		unknown_reference_record.object_reference_vector_contents_known = false;
		unknown_reference_record.object_reference_count = 1;
		unknown_reference_record.object_references_0x04_0x08 = { 0x33333333U };
		const auto unknown_reference_removal =
				aurelion::h3maped_rmg_core::generated_cell_object_reference_removal_0x499ee8(unknown_reference_record, 0x33333333U);
		if (!require(!unknown_reference_removal.object_reference_vector_known
					&& !unknown_reference_removal.object_record_removed
					&& unknown_reference_record.object_reference_count == 1
					&& unknown_reference_record.object_references_0x04_0x08.size() == 1,
					"0x499ee8 mutated an unknown object-reference vector")) {
			return 1;
		}
		GeneratedCellRecord0x30 missing_reference_record = reference_record;
		missing_reference_record.object_reference_vector_contents_known = true;
		missing_reference_record.object_reference_count = 1;
		missing_reference_record.object_references_0x04_0x08 = { 0x44444444U };
		const auto missing_reference_removal =
				aurelion::h3maped_rmg_core::generated_cell_object_reference_removal_0x499ee8(missing_reference_record, 0x55555555U);
		if (!require(missing_reference_removal.object_reference_vector_known
					&& !missing_reference_removal.object_record_found
					&& !missing_reference_removal.object_record_removed
					&& missing_reference_record.object_reference_count == 1
					&& missing_reference_record.object_references_0x04_0x08[0] == 0x44444444U,
					"0x499ee8 missing-key path changed the object-reference vector")) {
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
			aurelion::h3maped_rmg_core::generated_cell_49aa63(chain_record, true);
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
		if (!require(chain_result.cleanup_scan_count == 9 && chain_result.cleanup_owner_match_count == 9 && chain_result.cleanup_bit_0x04_clear_count == 8, "0x4a5a23 cleanup did not clear nearby same-owner +0x2b bit0x04 mirrors")) {
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
		int32_t object_branch_source_nibble = -1;
		SourceObjectSelectorResult4a9e40 object_branch_selector;
		const std::vector<SourceObjectRecord0x4c> &source_catalog = aurelion::h3maped_rmg_core::source_object_catalog_0x49da08();
		for (int32_t source_nibble = 0; source_nibble < 16; ++source_nibble) {
			object_branch_selector = aurelion::h3maped_rmg_core::source_object_wrapper_selector_0x4a9e40(
					10U,
					0,
					9,
					source_nibble);
			if (object_branch_selector.selected) {
				object_branch_source_nibble = source_nibble;
				break;
			}
		}
		if (!require(object_branch_source_nibble >= 0, "test setup could not find recovered 0x4a9e40 selector input for 0x4a5a23 object branch")) {
			return 1;
		}
		if (!require(object_branch_selector.selected_source_record_index >= 0
						&& object_branch_selector.selected_source_record_index < int32_t(source_catalog.size()),
					"0x4a5a23 object branch selected source record index outside recovered source catalog")) {
			return 1;
		}
		const SourceObjectRecord0x4c &object_branch_selected_record = source_catalog[size_t(object_branch_selector.selected_source_record_index)];
		GeneratorObjectPrivateState chain_object_state;
		chain_object_state.width = 2;
		chain_object_state.height = 2;
		chain_object_state.level_count = 1;
		chain_object_state.generated_cell_buffer = aurelion::h3maped_rmg_core::generated_cell_record_grid_reset_0x49a072(2, 2, 1);
		chain_object_state.generated_cell_buffer_owned = true;
		chain_object_state.descriptor_counter_table_0x1110_present = true;
		chain_object_state.descriptor_counter_table_0x1110_contents_known = true;
		chain_object_state.descriptor_counter_table_0x1110_known_count = aurelion::h3maped_rmg_core::DESCRIPTOR_COUNTER_TABLE_0X1110_DWORD_COUNT;
		chain_object_state.descriptor_counter_table_0x1110.assign(size_t(aurelion::h3maped_rmg_core::DESCRIPTOR_COUNTER_TABLE_0X1110_DWORD_COUNT), 0U);
		chain_object_state.native_object_record_key_allocator_0x4a93a2_known = true;
		chain_object_state.next_native_object_record_key_0x4a93a2 = 0x03625000U;
		GeneratedCellRecord0x30 &chain_materialize_cell = chain_object_state.generated_cell_buffer.records[0];
		chain_materialize_cell.object_reference_vector_contents_known = true;
		chain_materialize_cell.object_reference_count = 0;
		chain_materialize_cell.object_references_0x04_0x08.clear();
		chain_materialize_cell.word_0x1c = 0x00000002U;
		chain_materialize_cell.word_0x10_known = true;
		chain_materialize_cell.word_0x10 = aurelion::h3maped_rmg_core::RELATION_RESET_COORD_MINUS_ONE;
		chain_materialize_cell.word_0x14_known = true;
		chain_materialize_cell.word_0x14 = 0U;
		chain_materialize_cell.word_0x18_known = true;
		chain_materialize_cell.word_0x18 = 0U;
		chain_materialize_cell.word_0x28 |= aurelion::h3maped_rmg_core::CELL_DECOR_CANDIDATE_BIT_26;
		chain_materialize_cell.word_0x2c = (uint32_t(object_branch_source_nibble) << 1U) | 0x01U;
		SourceObjectResolverState4af785 chain_object_resolver;
		const SourceObjectResolverResult4af785 chain_object_seed_resolve =
				aurelion::h3maped_rmg_core::source_object_descriptor_resolver_0x4af785(chain_object_resolver, object_branch_selected_record);
		if (!require(chain_object_seed_resolve.created_new_wrapper && chain_object_seed_resolve.appended_wrapper_to_bucket, "0x4a5a23 object branch fixture did not seed resolver runtime bucket through 0x4af785")) {
			return 1;
		}
		aurelion::h3maped_rmg_core::H3MapedRng chain_object_rng;
		chain_object_rng.state = 10U;
		const auto chain_materialize_result =
				aurelion::h3maped_rmg_core::projected_cell_chain_with_object_branch_4a5a23(chain_object_state, chain_object_resolver, chain_object_rng, 0, 0, 0, false);
		if (!require(chain_materialize_result.object_branch_attempt_count == 1
						&& chain_materialize_result.object_branch_selector_selected_count == 1
						&& chain_materialize_result.object_branch_allocated_record_count == 1
						&& chain_materialize_result.object_branch_low_bits_cleared_count == 1
						&& chain_materialize_result.object_branch_commit_count == 1
						&& chain_materialize_result.stopped_on_out_of_bounds,
					"0x4a5a23 object branch did not select, allocate, clear low +0x2c bits, and commit before following projection")) {
			return 1;
		}
		if (!require((chain_materialize_cell.word_0x2c & 0x1fU) == 0U
						&& (chain_materialize_cell.word_0x28 & aurelion::h3maped_rmg_core::CELL_OCCUPIED_BLOCKED_BIT_27) != 0U
						&& (chain_materialize_cell.word_0x28 & aurelion::h3maped_rmg_core::CELL_DECOR_CANDIDATE_BIT_26) == 0U
						&& chain_materialize_cell.object_reference_count == 1
						&& chain_materialize_cell.object_references_0x04_0x08[0] == 0x03625000U,
					"0x4a5a23 object branch did not mutate target cell/object reference through vtable slot +0x04")) {
			return 1;
		}
		if (!require(!chain_object_state.object_records_0xec4_ecc.empty()
						&& chain_object_state.object_records_0xec4_ecc.back().object_record_vtable_0x00 == aurelion::h3maped_rmg_core::OBJECT_RECORD_VTABLE_0X540A74
						&& chain_object_state.object_records_0xec4_ecc.back().copied_source_record_carried
						&& chain_object_state.object_records_0xec4_ecc.back().source_catalog_index_0x49da08 == object_branch_selector.selected_source_record_index,
					"0x4a5a23 object branch did not preserve recovered 0x49ba89/0x4a9e40 source identity")) {
			return 1;
		}
		if (!require(chain_object_state.source_pair_vector_edc.contents_known && chain_object_state.source_pair_vector_edc.count == 1, "0x4a5a23 object branch did not materialize generator +0xedc source-pair vector count")) {
			return 1;
		}
		if (!require(chain_object_state.source_pair_records_edc.size() == 1
						&& chain_object_state.source_pair_records_edc[0].source_record_pointer_0x00_carried
						&& chain_object_state.source_pair_records_edc[0].context_pointer_0x04_carried
						&& !chain_object_state.source_pair_records_edc[0].descriptor_join_0x4903e8_known
						&& chain_object_state.source_pair_records_edc[0].copied_source_catalog_index == object_branch_selector.selected_source_record_index
						&& aurelion::h3maped_rmg_core::same_source_object_record_0x4c(chain_object_state.source_pair_records_edc[0].source_record_copy, object_branch_selected_record),
					"0x4a5a23 object branch did not preserve generator +0xedc source-pair payload")) {
			return 1;
		}
		GeneratorObjectPrivateState scan_object_state;
		scan_object_state.width = 3;
		scan_object_state.height = 1;
		scan_object_state.level_count = 1;
		scan_object_state.generated_cell_buffer = aurelion::h3maped_rmg_core::generated_cell_record_grid_reset_0x49a072(3, 1, 1);
		scan_object_state.generated_cell_buffer_owned = true;
		scan_object_state.descriptor_counter_table_0x1110_present = true;
		scan_object_state.descriptor_counter_table_0x1110_contents_known = true;
		scan_object_state.descriptor_counter_table_0x1110_known_count = aurelion::h3maped_rmg_core::DESCRIPTOR_COUNTER_TABLE_0X1110_DWORD_COUNT;
		scan_object_state.descriptor_counter_table_0x1110.assign(size_t(aurelion::h3maped_rmg_core::DESCRIPTOR_COUNTER_TABLE_0X1110_DWORD_COUNT), 0U);
		scan_object_state.native_object_record_key_allocator_0x4a93a2_known = true;
		scan_object_state.next_native_object_record_key_0x4a93a2 = 0x03626000U;
		for (int32_t x = 0; x < 3; ++x) {
			GeneratedCellRecord0x30 &scan_object_cell = scan_object_state.generated_cell_buffer.records[size_t(x)];
			scan_object_cell.object_reference_vector_contents_known = true;
			scan_object_cell.object_reference_count = 0;
			scan_object_cell.word_0x20 = aurelion::h3maped_rmg_core::generated_cell_zone_word_4a325d(scan_object_cell.word_0x20, 0);
			scan_object_cell.word_0x24 = aurelion::h3maped_rmg_core::generated_cell_49acf6_word24(scan_object_cell.word_0x24, 0, 0);
			scan_object_cell.word_0x28 |= aurelion::h3maped_rmg_core::CELL_DECOR_READY_BIT_25;
			if (!require(aurelion::h3maped_rmg_core::generated_cell_4a5767_reset_projection(scan_object_cell), "test setup 0x4a5767 reset failed before live object-branch scan-consumer pass")) {
				return 1;
			}
			scan_object_cell.word_0x1c = 0x00000002U;
			scan_object_cell.word_0x10_known = true;
			scan_object_cell.word_0x10 = aurelion::h3maped_rmg_core::RELATION_RESET_COORD_MINUS_ONE;
			scan_object_cell.word_0x14_known = true;
			scan_object_cell.word_0x14 = 0U;
			scan_object_cell.word_0x18_known = true;
			scan_object_cell.word_0x18 = 0U;
			aurelion::h3maped_rmg_core::generated_cell_49a932(scan_object_cell, true);
		}
		scan_object_state.generated_cell_buffer.records[1].word_0x2c = (uint32_t(object_branch_source_nibble) << 1U) | 0x01U;
		GeneratorRelationOwnerState4a218c scan_object_owner;
		scan_object_owner.owner_vector_index = 0;
		scan_object_owner.runtime_zone_index = 0;
		scan_object_owner.coordinate_triple_0x10_0x18_known = true;
		scan_object_owner.coordinate_x_0x10 = 0;
		scan_object_owner.coordinate_y_0x14 = 0;
		scan_object_owner.coordinate_level_0x18 = 0;
		scan_object_owner.scan_bounds_0x20_0x2c_known = true;
		scan_object_owner.scan_bound_low_x_0x20 = 0;
		scan_object_owner.scan_bound_low_y_0x24 = 0;
		scan_object_owner.scan_bound_high_x_0x28 = 2;
		scan_object_owner.scan_bound_high_y_0x2c = 1;
		SourceObjectResolverState4af785 scan_object_resolver;
		const SourceObjectResolverResult4af785 scan_object_seed_resolve =
				aurelion::h3maped_rmg_core::source_object_descriptor_resolver_0x4af785(scan_object_resolver, object_branch_selected_record);
		if (!require(scan_object_seed_resolve.created_new_wrapper && scan_object_seed_resolve.appended_wrapper_to_bucket, "relation scan object-branch fixture did not seed resolver runtime bucket through 0x4af785")) {
			return 1;
		}
		aurelion::h3maped_rmg_core::H3MapedRng scan_object_rng;
		scan_object_rng.state = 10U;
		const auto scan_object_result = aurelion::h3maped_rmg_core::relation_scan_consumers_after_0x4a1f3b_bounds_4a5767(scan_object_state, scan_object_resolver, scan_object_rng, { scan_object_owner });
		if (!require(scan_object_result.applied
						&& scan_object_result.projected_chain_call_count == 0
						&& scan_object_result.projected_chain_object_branch_attempt_count == 0
						&& scan_object_result.projected_chain_object_branch_commit_count == 0
						&& scan_object_result.projected_chain_object_branch_blocked_count == 0
						&& scan_object_state.object_record_vector_append_count_0x4a54a7 == 0
						&& scan_object_state.source_pair_records_edc.empty(),
					"relation scan consumer live-state overload did not apply recovered 0x49a318 zero-score skip before object branch")) {
			return 1;
		}
		if (!require(scan_object_state.source_pair_vector_edc.count == 0,
					"relation scan consumer live-state overload unexpectedly materialized generator +0xedc source-pair payload")) {
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
		EndpointMaterializationState4a5e73 supported_land_endpoint_state;
		supported_land_endpoint_state.endpoint_vector_d8_dc = {
			EndpointPointerRecord4a5e73 { 0 },
			EndpointPointerRecord4a5e73 { 1 },
			EndpointPointerRecord4a5e73 { 2 },
			EndpointPointerRecord4a5e73 { 3 },
			EndpointPointerRecord4a5e73 { 4 },
			EndpointPointerRecord4a5e73 { 5 },
			EndpointPointerRecord4a5e73 { 6 },
			EndpointPointerRecord4a5e73 { 7 },
		};
		supported_land_endpoint_state.byte_state_vector_1104_1108.assign(8, 0U);
		supported_land_endpoint_state.cursor_0xf5c = 0x7a1befdf;
		const EndpointMaterializationResult4a5e73 supported_land_endpoint_result =
				aurelion::h3maped_rmg_core::endpoint_materialization_4a5e73(record_grid, supported_land_endpoint_state, 0, 0, 0, 1);
		if (!require(supported_land_endpoint_result.return_value == -1
						&& !supported_land_endpoint_result.d8_match_found
						&& supported_land_endpoint_state.cursor_0xf5c == 0x7a1befdf,
					"0x4a5e73 did not preserve the recovered supported-land stale +0xf5c rejection against compact +0xd8 keys 0..7")) {
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
		aurelion::h3maped_rmg_core::SourceBoundedCandidatePickerResult4a7312 accepted_projection_result;
		accepted_projection_result.committed_through_vtable_slot_0x04 = true;
		endpoint_result = aurelion::h3maped_rmg_core::endpoint_materialization_4a5e73(record_grid, endpoint_state, 0, 0, 0, 2, &accepted_projection_result);
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
		if (!require(cycles[0].cycle_nodes[0].next_pair_payload_owner_word_0x00 == 1, "source next-pair owner word was not preserved")) {
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
		if (!require(cycles[0].span_fill_owner_word_0x4a325d == handoffs[0].zone_word, "0x4a325d span-fill owner did not preserve the source-record owner word")) {
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
			1,
			0,
			1234U,
			{ square_handoff(false) });
	const BoundaryMaterialization4a2777 gated = aurelion::h3maped_rmg_core::materialize_boundary_source_handoffs_4a2777_4a325d(
			8,
			8,
			1,
			1,
			0,
			1234U,
			{ square_handoff(true) });
	const BoundaryMaterialization4a2777 land_setup_mode_two = aurelion::h3maped_rmg_core::materialize_boundary_source_handoffs_4a2777_4a325d(
			8,
			8,
			1,
			1,
			2,
			1234U,
			{ square_handoff(false) });

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
	int32_t ungated_connector_count = 0;
	int32_t ungated_randomized_connector_count = 0;
	for (const auto &segment : ungated.zones[0].segments) {
		if (segment.id != "connector") {
			continue;
		}
		ungated_connector_count += 1;
		if (segment.randomized && segment.writer == "0x4a2413") {
			ungated_randomized_connector_count += 1;
		}
	}
	if (!require(ungated_connector_count > 1
					&& ungated_randomized_connector_count == ungated_connector_count,
				"0x4a2777 source-cycle connectors must all use the recovered 0x4a29c4 randomized branch when active")) {
		return 1;
	}
	BoundarySourceCycleHandoff4a2777 relation_owner_split_handoff = square_handoff(false);
	relation_owner_split_handoff.generated_cell_owner_byte2 = 7;
	const BoundaryMaterialization4a2777 relation_owner_split =
			aurelion::h3maped_rmg_core::materialize_boundary_source_handoffs_4a2777_4a325d(
					8,
					8,
					1,
					1,
					2,
					1234U,
					{ relation_owner_split_handoff });
	const int64_t span_fill_center_key = aurelion::h3maped_rmg_core::cell_index(8, 8, 3, 3, 0);
	const int64_t boundary_key = aurelion::h3maped_rmg_core::cell_index(8, 8, 1, 1, 0);
	if (!require(span_fill_center_key >= 0
					&& span_fill_center_key < int64_t(relation_owner_split.generated_cell_word_0x20.size())
					&& owner_byte2_signed(relation_owner_split.generated_cell_word_0x20[size_t(span_fill_center_key)]) == relation_owner_split_handoff.generated_cell_owner_byte2,
				"0x4a325d span fill must write the recovered generated-cell owner byte separately from the private span owner word")) {
		return 1;
	}
	if (!require(relation_owner_split.private_zone_words[size_t(span_fill_center_key)] == (uint32_t(relation_owner_split_handoff.zone_word) << 16U),
				"0x4a325d span fill must preserve the private source-record owner word separately from generated-cell byte2")) {
		return 1;
	}
	if (!require(boundary_key >= 0
					&& boundary_key < int64_t(relation_owner_split.generated_cell_word_0x20.size())
					&& owner_byte2_signed(relation_owner_split.generated_cell_word_0x20[size_t(boundary_key)]) == relation_owner_split_handoff.generated_cell_owner_byte2,
				"0x4a2777 boundary line writes should keep using the recovered generated-cell owner byte")) {
		return 1;
	}
	int32_t land_setup_mode_two_member_flags = 0;
	for (const uint8_t flags : land_setup_mode_two.cell_flags) {
		if ((flags & 0x10U) != 0U) {
			land_setup_mode_two_member_flags += 1;
		}
	}
	if (!require(land_setup_mode_two_member_flags == 0, "one-level land water mode must suppress level-0 0x4a325d member flags when setup mode is 2")) {
		return 1;
	}
	BoundarySourceCycleHandoff4a2777 per_source_owner_handoff = square_handoff(false);
	per_source_owner_handoff.source_nodes[0].has_payload = true;
	per_source_owner_handoff.source_nodes[0].payload_owner_word_0x00 = 2;
	per_source_owner_handoff.source_nodes[0].finalized = false;
	per_source_owner_handoff.source_nodes[1].has_payload = true;
	per_source_owner_handoff.source_nodes[1].payload_owner_word_0x00 = 6;
	per_source_owner_handoff.source_nodes[2].has_payload = true;
	per_source_owner_handoff.source_nodes[2].payload_owner_word_0x00 = 7;
	per_source_owner_handoff.source_nodes[3].has_payload = true;
	per_source_owner_handoff.source_nodes[3].payload_owner_word_0x00 = 8;
	const BoundaryMaterialization4a2777 per_source_owner =
			aurelion::h3maped_rmg_core::materialize_boundary_source_handoffs_4a2777_4a325d(
					8,
					8,
					1,
					1,
					2,
					1234U,
					{ per_source_owner_handoff });
	const int64_t per_source_owner_key = aurelion::h3maped_rmg_core::cell_index(8, 8, 6, 1, 0);
	if (!require(!per_source_owner.zones.empty()
					&& per_source_owner.zones[0].selected_segment_index == 1
					&& per_source_owner_key >= 0
					&& per_source_owner_key < int64_t(per_source_owner.private_zone_words.size())
					&& owner_byte2_signed(per_source_owner.private_zone_words[size_t(per_source_owner_key)]) == 6,
				"0x4a2777 must write the current selected source-node owner word, not the first cycle node owner")) {
		return 1;
	}
	BoundarySourceCycleHandoff4a2777 descriptor_link_handoff = square_handoff(false);
	descriptor_link_handoff.source_nodes = {
		descriptor_source_node(1, 1, 10, 30, 20, 40, 40),
		descriptor_source_node(6, 6, 30, 10, 40, 20, 20),
		descriptor_source_node(6, 1, 20, 40, 30, 10, 10),
		descriptor_source_node(1, 6, 40, 20, 10, 30, 30),
	};
	const BoundaryMaterialization4a2777 descriptor_linked = aurelion::h3maped_rmg_core::materialize_boundary_source_handoffs_4a2777_4a325d(
			8,
			8,
			1,
			1,
			2,
			1234U,
			{ descriptor_link_handoff });
	if (!require(!descriptor_linked.zones.empty() && !descriptor_linked.zones[0].segments.empty(), "descriptor-linked handoff did not materialize a boundary segment")) {
		return 1;
	}
	const auto &descriptor_first_segment = descriptor_linked.zones[0].segments[0];
	if (!require(descriptor_first_segment.from_x == 1 && descriptor_first_segment.from_y == 1
				&& descriptor_first_segment.to_x == 6 && descriptor_first_segment.to_y == 1,
			"0x4a2777 boundary traversal must follow descriptor next links, not vector position order")) {
		return 1;
	}
	BoundarySourceCycleHandoff4a2777 relocated_seed_handoff = square_handoff(false);
	relocated_seed_handoff.source_record_seed_0x10 = SpanRecord { 20, 20, 0 };
	relocated_seed_handoff.source_nodes = {
		descriptor_source_node(5, 2, 10, 40, 20, 40, 40),
		descriptor_source_node(8, 5, 20, 10, 30, 10, 10),
		descriptor_source_node(5, 8, 30, 20, 40, 20, 20),
		descriptor_source_node(2, 5, 40, 30, 10, 30, 30),
	};
	for (SourceNodeCyclePoint4a2777 &node : relocated_seed_handoff.source_nodes) {
		node.raw_x_0x00 = 1;
		node.raw_y_0x04 = 1;
	}
	const BoundaryMaterialization4a2777 relocated_seed = aurelion::h3maped_rmg_core::materialize_boundary_source_handoffs_4a2777_4a325d(
			10,
			10,
			1,
			1,
			2,
			1234U,
			{ relocated_seed_handoff });
	if (!require(!relocated_seed.zones.empty()
					&& relocated_seed.zones[0].span_seed_relocated_4a325d
					&& relocated_seed.zones[0].effective_span_seed_4a325d.x == 9
					&& relocated_seed.zones[0].effective_span_seed_4a325d.y < 9,
				"0x4a325d out-of-bounds seed relocation must scan appended 0x4a2777 boundary vector points, not source-pair raw coordinates")) {
		return 1;
	}
	BoundarySourceCycleHandoff4a2777 missing_seed = square_handoff(false);
	missing_seed.has_source_record_seed_0x10 = false;
	const BoundaryMaterialization4a2777 missing_seed_result = aurelion::h3maped_rmg_core::materialize_boundary_source_handoffs_4a2777_4a325d(
			8,
			8,
			1,
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
		RuntimeZoneFootprintInput4a3a03 { 0, 1, 8, 8, 0, 1, 0, 1 },
		RuntimeZoneFootprintInput4a3a03 { 1, 2, 20, 8, 0, 2, 1, 1 },
		RuntimeZoneFootprintInput4a3a03 { 2, 3, 20, 20, 0, 3, 2, 1 },
		RuntimeZoneFootprintInput4a3a03 { 3, 4, 8, 20, 0, 4, 3, 1 },
	};
	const SourceNodeFootprintResult4a3a03 footprint = aurelion::h3maped_rmg_core::build_source_node_footprints_4a3a03_4ccb64_4cca55(runtime_zones, 36, 36);
	if (!require(!footprint.blocked, "source-node footprint producer unexpectedly blocked")) {
		return 1;
	}
	if (!require(footprint.executed_split_count >= 4, "source-node footprint producer did not split all surface runtime zones")) {
		return 1;
	}
	if (!require(footprint.synthetic_source_candidate_count_0x4a3b48 > 0, "source-node footprint producer did not evaluate recovered synthetic source candidates")) {
		return 1;
	}
	if (!require(footprint.synthetic_source_record_count_0x4a3dbc > 0, "source-node footprint producer did not append recovered synthetic source records")) {
		return 1;
	}
	if (!require(footprint.source_record_count_after_0x4a3dbc > int32_t(runtime_zones.size()), "source-node footprint producer did not preserve appended source records")) {
		return 1;
	}
	const SourceNodeFootprintResult4a3a03 mode0_footprint = aurelion::h3maped_rmg_core::build_source_node_footprints_4a3a03_4ccb64_4cca55(
			runtime_zones,
			36,
			36,
			0,
			0);
	if (!require(!mode0_footprint.blocked
					&& mode0_footprint.synthetic_source_candidate_count_0x4a3b48 == 0
					&& mode0_footprint.synthetic_source_record_count_0x4a3dbc == 0
					&& mode0_footprint.source_record_count_after_0x4a3dbc == int32_t(runtime_zones.size()),
				"0x4a3a9d mode-0 caller-level-0 gate must skip synthetic source candidate insertion")) {
		return 1;
	}
	const std::vector<RuntimeZoneFootprintInput4a3a03> mixed_level_runtime_zones = {
		RuntimeZoneFootprintInput4a3a03 { 0, 101, 8, 8, 0, 1, 0, 1 },
		RuntimeZoneFootprintInput4a3a03 { 1, 201, 20, 8, 1, 2, 1, 1 },
		RuntimeZoneFootprintInput4a3a03 { 2, 202, 20, 20, 1, 3, 2, 1 },
	};
	const SourceNodeFootprintResult4a3a03 level_one_footprint =
			aurelion::h3maped_rmg_core::build_source_node_footprints_4a3a03_4ccb64_4cca55(
					mixed_level_runtime_zones,
					36,
					36,
					0,
					1);
	if (!require(!level_one_footprint.blocked
					&& level_one_footprint.executed_split_count >= 2
					&& level_one_footprint.source_record_count_after_0x4a3dbc >= 2
					&& !level_one_footprint.walks.empty()
					&& level_one_footprint.walks[0].source_zone_id != 101,
				"0x4a3a03 explicit caller level must consume same-level source records instead of hardcoded level 0")) {
		return 1;
	}
	if (!require(footprint.source_descriptor_node_count > 0 && footprint.source_descriptor_finalized_node_count > 0, "source descriptor table was not materialized")) {
		return 1;
	}
	if (!require(footprint.walks.size() >= runtime_zones.size(), "source-node footprint producer did not emit one walk per surface runtime zone")) {
		return 1;
	}
	if (!require(footprint.walks[0].locator_node_index >= 0 && !footprint.walks[0].source_nodes.empty(), "source descriptor walk was not materialized")) {
		return 1;
	}
	if (!require(footprint.walks[0].source_nodes[0].model_node_index >= 0 && footprint.walks[0].source_nodes[0].next_pair_index >= 0, "source walk lost descriptor link indexes")) {
		return 1;
	}
	bool zero_owner_payload_preserved = false;
	for (const SourceNodeCyclePoint4a2777 &node : footprint.walks[0].source_nodes) {
		if ((node.has_payload && node.payload_owner_word_0x00 == 0)
				|| (node.next_pair_has_payload && node.next_pair_payload_owner_word_0x00 == 0)) {
			zero_owner_payload_preserved = true;
			break;
		}
	}
	if (!require(zero_owner_payload_preserved, "source-node footprint producer did not preserve source payload owner word zero")) {
		return 1;
	}
	bool appended_owner_payload_uses_source_vector_index = false;
	for (int32_t walk_index = int32_t(runtime_zones.size()); walk_index < int32_t(footprint.walks.size()); ++walk_index) {
		const auto &walk = footprint.walks[size_t(walk_index)];
		for (const SourceNodeCyclePoint4a2777 &node : walk.source_nodes) {
			if ((node.has_payload && node.payload_owner_word_0x00 == walk.runtime_zone_index)
					|| (node.next_pair_has_payload && node.next_pair_payload_owner_word_0x00 == walk.runtime_zone_index)) {
				appended_owner_payload_uses_source_vector_index = true;
				break;
			}
		}
		if (appended_owner_payload_uses_source_vector_index) {
			break;
		}
	}
	if (!require(appended_owner_payload_uses_source_vector_index, "0x4a3dbc appended source record must use source-vector count as source pointer +0x00 owner word")) {
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
	if (!require(produced.zones.size() == 1, "producer handoff did not preserve a materialized zone")) {
		return 1;
	}

	const std::vector<RuntimeZoneBoundaryInput4a3a03> boundary_inputs = {
		RuntimeZoneBoundaryInput4a3a03 { runtime_zones[0], 0, 0, 0, 1, 30, true, SpanRecord { 9, 9, 0 } },
		RuntimeZoneBoundaryInput4a3a03 { runtime_zones[1], 1, 1, 0, 1, 1, true, SpanRecord { 20, 8, 0 } },
		RuntimeZoneBoundaryInput4a3a03 { runtime_zones[2], 2, 2, 0, 1, 2, true, SpanRecord { 20, 20, 0 } },
		RuntimeZoneBoundaryInput4a3a03 { runtime_zones[3], 3, 3, 0, 1, 3, true, SpanRecord { 8, 20, 0 } },
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
	if (!require(owner_grid.footprint_finalizer.generator_mode_0x10b8 == 0
					&& owner_grid.footprint_finalizer.caller_level_argument_0x0c == 0
					&& !owner_grid.footprint_finalizer.synthetic_branch_allowed_by_0x4a3a9d,
				"one-level mode-0 0x4a3710 finalizer incorrectly entered the recovered synthetic append branch")) {
		return 1;
	}
	std::vector<GeneratorRelationOwnerState4a218c> relation_owner_inputs(4);
	for (int32_t index = 0; index < 4; ++index) {
		GeneratorRelationOwnerState4a218c &owner = relation_owner_inputs[size_t(index)];
		owner.owner_vector_index = index;
		owner.runtime_zone_index = index;
		owner.source_zone_id = runtime_zones[size_t(index)].source_zone_id;
		owner.source_index = index;
		owner.source_pointer_0x00_known = true;
		owner.source_pointer_source_index_0x00 = index;
		owner.relation_owner_byte2_0x4aa9b7_known = true;
		owner.relation_owner_byte2_0x4aa9b7 = index;
		owner.coordinate_triple_0x10_0x18_known = true;
		owner.coordinate_x_0x10 = runtime_zones[size_t(index)].x_after_bbox_rescale;
		owner.coordinate_y_0x14 = runtime_zones[size_t(index)].y_after_bbox_rescale;
		owner.coordinate_level_0x18 = runtime_zones[size_t(index)].level;
		owner.boundary_payload_span_limit_0x1c_known = true;
		owner.boundary_payload_span_limit_0x1c = 7 + index;
	}
	relation_owner_inputs[0].source_pointer_source_index_0x00 = 9;
	relation_owner_inputs[0].relation_owner_byte2_0x4aa9b7 = 9;
	const BoundaryOwnerGridResult4a3a03 owner_grid_from_relation_owners =
			aurelion::h3maped_rmg_core::materialize_boundary_owner_grid_from_relation_owner_vectors_4a3a03_4cca55_4a2777_4a325d_4a3710(
					36,
					36,
					1,
					aurelion::h3maped_rmg_core::water_mode_code("land"),
					0,
					1234U,
					boundary_inputs,
					relation_owner_inputs);
	if (!require(owner_grid_from_relation_owners.materialization_executed, "relation-owner vector owner-grid chain did not execute boundary materialization")) {
		return 1;
	}
	if (!require(owner_grid_from_relation_owners.handoffs.size() >= relation_owner_inputs.size(), "relation-owner vector owner-grid chain did not emit at least one handoff per original owner")) {
		return 1;
	}
	if (!require(owner_grid_from_relation_owners.missing_boundary_input_count == 0
					&& owner_grid_from_relation_owners.missing_source_walk_count == 0,
				"relation-owner vector owner-grid chain lost appended source handoff inputs")) {
		return 1;
	}
	if (!require(owner_grid_from_relation_owners.handoffs[0].random_span_limit == relation_owner_inputs[0].boundary_payload_span_limit_0x1c,
				"relation-owner vector owner-grid chain did not preserve payload +0x1c span")) {
		return 1;
	}
	if (!require(owner_grid_from_relation_owners.handoffs[0].source_record_vector_index_4a3e9c == boundary_inputs[0].source_record_vector_index_4a3e9c,
				"relation-owner vector owner-grid chain did not preserve the selected source-record vector index into the handoff")) {
		return 1;
	}
	if (!require(owner_grid_from_relation_owners.handoffs[0].zone_word == relation_owner_inputs[0].source_pointer_source_index_0x00,
				"relation-owner vector owner-grid chain did not carry recovered source pointer owner word into the boundary payload")) {
		return 1;
	}
	if (!require(owner_grid_from_relation_owners.handoffs[0].generated_cell_owner_byte2 == relation_owner_inputs[0].source_pointer_source_index_0x00,
				"relation-owner vector owner-grid chain did not carry recovered source pointer owner word into generated-cell owner byte")) {
		return 1;
	}
	if (!require(owner_grid_from_relation_owners.handoffs[0].source_record_seed_0x10.x == boundary_inputs[0].source_record_seed_0x10.x
					&& owner_grid_from_relation_owners.handoffs[0].source_record_seed_0x10.y == boundary_inputs[0].source_record_seed_0x10.y,
				"relation-owner vector owner-grid chain did not use the selected source-record seed as the span seed")) {
		return 1;
	}
	const FootprintFinalizerResult4a3710 synthetic_mode_finalizer =
			aurelion::h3maped_rmg_core::footprint_finalizer_4a3710(
					1,
					aurelion::h3maped_rmg_core::water_mode_code("land"),
					2,
					0,
					4,
					4);
	if (!require(!synthetic_mode_finalizer.blocked
					&& synthetic_mode_finalizer.synthetic_branch_allowed_by_0x4a3a9d
					&& synthetic_mode_finalizer.appended_runtime_zone_count == 0
					&& synthetic_mode_finalizer.status == "0x4a3710_synthetic_runtime_zone_scan_executed_without_append",
				"0x4a3710 should not claim the synthetic append branch is unported when no owner was appended")) {
		return 1;
	}
	const FootprintFinalizerResult4a3710 synthetic_level_finalizer =
			aurelion::h3maped_rmg_core::footprint_finalizer_4a3710(
					2,
					aurelion::h3maped_rmg_core::water_mode_code("land"),
					0,
					1,
					4,
					4);
	if (!require(!synthetic_level_finalizer.blocked
					&& synthetic_level_finalizer.synthetic_branch_allowed_by_0x4a3a9d
					&& synthetic_level_finalizer.appended_runtime_zone_count == 0
					&& synthetic_level_finalizer.status == "0x4a3710_synthetic_runtime_zone_scan_executed_without_append",
				"0x4a3710 should not claim caller [EBP+0x0c] == 1 synthetic append branch is unported when no owner was appended")) {
		return 1;
	}
	const FootprintFinalizerResult4a3710 synthetic_appended_finalizer =
			aurelion::h3maped_rmg_core::footprint_finalizer_4a3710(
					1,
					aurelion::h3maped_rmg_core::water_mode_code("land"),
					2,
					0,
					4,
					5);
	if (!require(synthetic_appended_finalizer.blocked
					&& synthetic_appended_finalizer.synthetic_branch_allowed_by_0x4a3a9d
					&& synthetic_appended_finalizer.appended_runtime_zone_count == 1
					&& synthetic_appended_finalizer.status == "0x4a3710_appended_zone_adjacency_requires_relation_owner_vector_10e4_10e8",
				"0x4a3710 appended synthetic owners without relation-owner state should block on the missing 10e4/10e8 owner vector")) {
		return 1;
	}
	if (!require(owner_grid.handoffs.size() >= 4, "composed owner-grid chain did not build handoffs for all original source walks")) {
		return 1;
	}
	if (!require(owner_grid.missing_boundary_input_count == 0 && owner_grid.missing_source_walk_count == 0, "composed owner-grid chain lost source/boundary handoff inputs")) {
		return 1;
	}
	if (!require(owner_grid.materialization.source_handoff_count == int32_t(owner_grid.handoffs.size()), "composed owner-grid materializer did not consume all source handoffs")) {
		return 1;
	}
	if (!require(owner_grid.materialization.source_handoff_source_record_seed_count == int32_t(owner_grid.handoffs.size())
					&& owner_grid.materialization.source_handoff_missing_source_record_seed_count == 0,
				"composed owner-grid materializer did not consume source-record seeds")) {
		return 1;
	}
	const int32_t fillable_owner_grid_zone_count = int32_t(std::count_if(
			owner_grid.materialization.zones.begin(),
			owner_grid.materialization.zones.end(),
			[](const auto &zone) {
				return zone.has_span_seed_4a325d && !zone.segments.empty();
			}));
	if (!require(owner_grid.materialization.span_fill_zone_count + owner_grid.materialization.span_fill_seed_blocked_count >= fillable_owner_grid_zone_count,
				"composed owner-grid materializer did not account for all source-edge materialized seeded zones: span_fill_zone_count="
						+ std::to_string(owner_grid.materialization.span_fill_zone_count)
						+ " fillable_zone_count="
						+ std::to_string(fillable_owner_grid_zone_count)
						+ " span_fill_seed_blocked_count="
						+ std::to_string(owner_grid.materialization.span_fill_seed_blocked_count))) {
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
	{
		std::vector<GeneratorRelationOwnerState4a218c> interleaved_owners(2);
		for (int32_t index = 0; index < 2; ++index) {
			GeneratorRelationOwnerState4a218c &owner = interleaved_owners[size_t(index)];
			owner.runtime_zone_index = index;
			owner.owner_vector_index = index;
			owner.relation_owner_byte2_0x4aa9b7_known = true;
			owner.relation_owner_byte2_0x4aa9b7 = index;
			owner.coordinate_triple_0x10_0x18_known = true;
			owner.coordinate_x_0x10 = index;
			owner.coordinate_y_0x14 = index;
			owner.coordinate_level_0x18 = 0;
			owner.source_pointer_terrain_match_to_town_0x84_known = true;
			owner.source_pointer_terrain_match_to_town_0x84 = false;
			owner.source_pointer_allowed_terrain_mask_0x85_0x8c_known = true;
		}
		interleaved_owners[0].source_pointer_allowed_terrain_mask_0x85_0x8c = uint16_t(1U << 0U);
		interleaved_owners[1].source_pointer_allowed_terrain_mask_0x85_0x8c = uint16_t((1U << 0U) | (1U << 1U));
		H3MapedRng expected_rng;
		expected_rng.state = 1234U;
		const int32_t owner0_terrain_rng = expected_rng.next();
		const int32_t owner0_monster_rng = expected_rng.next();
		const int32_t owner1_terrain_rng = expected_rng.next();
		const int32_t owner1_monster_rng = expected_rng.next();
		RuntimeTerrainSelectionResult49b53d interleaved_selection =
				aurelion::h3maped_rmg_core::runtime_terrain_selection_49b53d(1234U, interleaved_owners);
		if (!require(interleaved_selection.records.size() == 2, "interleaved 0x49b53d/0x49b4e1 test did not emit two terrain records")) {
			return 1;
		}
		if (!require(interleaved_selection.records[0].rng_value == owner0_terrain_rng
						&& interleaved_selection.records[0].monster_town_choice_rng_value_0x49b4e1 == owner0_monster_rng,
					"0x49b4e1 must immediately consume RNG after owner 0 terrain selection")) {
			return 1;
		}
		if (!require(interleaved_selection.records[1].rng_value == owner1_terrain_rng
						&& interleaved_selection.records[1].monster_town_choice_rng_value_0x49b4e1 == owner1_monster_rng,
					"0x49b53d/0x49b4e1 RNG calls must interleave per relation owner")) {
			return 1;
		}
		if (!require(interleaved_selection.records[1].selected_terrain_id_0x49b53d == (owner1_terrain_rng % 2),
					"owner 1 terrain selection did not use the RNG state after owner 0 monster-town replay")) {
			return 1;
		}
		if (!require(interleaved_owners[0].monster_town_choice_rng_0x49b4e1_known
						&& interleaved_owners[1].monster_town_choice_rng_0x49b4e1_known,
					"interleaved 0x49b4e1 result was not applied back to relation owners")) {
			return 1;
		}
	}
	{
		auto make_owner_for_terrain5 = []() {
			std::vector<GeneratorRelationOwnerState4a218c> owners(1);
			GeneratorRelationOwnerState4a218c &owner = owners[0];
			owner.runtime_zone_index = 0;
			owner.owner_vector_index = 0;
			owner.relation_owner_byte2_0x4aa9b7_known = true;
			owner.relation_owner_byte2_0x4aa9b7 = 0;
			owner.coordinate_triple_0x10_0x18_known = true;
			owner.coordinate_x_0x10 = 0;
			owner.coordinate_y_0x14 = 0;
			owner.coordinate_level_0x18 = 0;
			owner.source_pointer_terrain_match_to_town_0x84_known = true;
			owner.source_pointer_terrain_match_to_town_0x84 = false;
			owner.source_pointer_allowed_terrain_mask_0x85_0x8c_known = true;
			owner.source_pointer_allowed_terrain_mask_0x85_0x8c = uint16_t(1U << 5U);
			return owners;
		};
		H3MapedRng expected_rng;
		expected_rng.state = 4321U;
		const int32_t terrain_rng = expected_rng.next();
		const int32_t monster_rng = expected_rng.next();
		std::vector<GeneratorRelationOwnerState4a218c> non_negative_owners = make_owner_for_terrain5();
		RuntimeTerrainSelectionResult49b53d non_negative_selection =
				aurelion::h3maped_rmg_core::runtime_terrain_selection_49b53d(4321U, non_negative_owners, true, 0);
		std::vector<GeneratorRelationOwnerState4a218c> negative_owners = make_owner_for_terrain5();
		RuntimeTerrainSelectionResult49b53d negative_selection =
				aurelion::h3maped_rmg_core::runtime_terrain_selection_49b53d(4321U, negative_owners, true, -1);
		if (!require(non_negative_selection.records.size() == 1 && negative_selection.records.size() == 1,
					"0x49b4e1 generator+0x08 sign test did not emit one terrain record per relation owner")) {
			return 1;
		}
		if (!require(non_negative_selection.records[0].rng_value == terrain_rng
						&& non_negative_selection.records[0].monster_town_choice_rng_value_0x49b4e1 == monster_rng,
					"0x49b4e1 generator+0x08 non-negative path did not consume expected RNG values")) {
			return 1;
		}
		if (!require(non_negative_selection.records[0].monster_town_choice_rng_modulus_0x49b4e1 == 3
						&& non_negative_selection.records[0].monster_town_choice_0x08 == 8,
					"0x49b4e1 non-negative generator+0x08 path did not keep town candidate 8")) {
			return 1;
		}
		if (!require(negative_selection.records[0].monster_town_choice_rng_modulus_0x49b4e1 == 2
						&& negative_selection.records[0].monster_town_choice_0x08 == 0,
					"0x49b4e1 negative generator+0x08 path did not remove town candidate 8")) {
			return 1;
		}
		if (!require(negative_selection.generator_field_0x08_known
						&& !negative_selection.generator_field_0x08_non_negative
						&& negative_owners[0].monster_town_choice_0x08 == 0,
					"0x49b4e1 generator+0x08 metadata/result was not applied back to relation owners")) {
			return 1;
		}
	}
	TerrainRepaintResult4a3f27 terrain_repaint = aurelion::h3maped_rmg_core::terrain_repaint_4a3f27(
			36,
			36,
			1,
			owner_grid_from_relation_owners.materialization,
			terrain_selection,
			&relation_owner_inputs);
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
	if (!require(terrain_repaint.terrain_visual_final_sweep_cell_count_0x4bbfcc >= 36 * 36, "TerrainPlacement scope cleanup did not revisit the full grid after the one-level full-map scope")) {
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
	{
		BoundaryMaterialization4a2777 same_terrain_materialization;
		RuntimeTerrainSelectionResult49b53d same_terrain_selection;
		same_terrain_selection.rng_state_after = 1234U;
		const TerrainRepaintResult4a3f27 same_terrain_repaint =
				aurelion::h3maped_rmg_core::terrain_repaint_4a3f27(
						2,
						2,
						1,
						same_terrain_materialization,
						same_terrain_selection,
						nullptr);
		if (!require(same_terrain_repaint.executed
						&& same_terrain_repaint.full_map_water_repaint_count_0x4a4025 == 4
						&& same_terrain_repaint.terrain_visual_initial_water_write_count_0x4a4025 == 4,
					"0x4bd099 same-terrain water scope did not write the expected direct visual cells")) {
			return 1;
		}
		if (!require(same_terrain_repaint.terrain_visual_queue_write_count_0x4bb74b == 0,
					"0x4bb681 same-terrain branch must not enter 0x4bb74b feedback")) {
			return 1;
		}
	}
	{
		BoundaryMaterialization4a2777 relation_gate_materialization;
		relation_gate_materialization.generator_mode_0x10b8 = 0;
		relation_gate_materialization.generated_cell_word_0x20.assign(4, aurelion::h3maped_rmg_core::GENERATED_CELL_INITIAL_WORD_0X20);
		relation_gate_materialization.generated_cell_word_0x20[0] = uint32_t(1U << 16U);
		relation_gate_materialization.generated_cell_word_0x20[1] = uint32_t(1U << 16U);
		relation_gate_materialization.generated_cell_word_0x28.assign(4, 0U);
		relation_gate_materialization.generated_cell_word_0x28[0] = aurelion::h3maped_rmg_core::CELL_TERRAIN_RELATION_ELIGIBLE_BIT_28;
		relation_gate_materialization.cell_flags.assign(4, 0U);
		relation_gate_materialization.cell_flags[3] = 0x10U;
		RuntimeTerrainSelectionResult49b53d relation_gate_selection;
		relation_gate_selection.rng_state_after = 1234U;
		RuntimeTerrainSelectionRecord49b53d stale_zone_word_record;
		stale_zone_word_record.runtime_zone_index = 10;
		stale_zone_word_record.zone_word_0x4a2777 = 1;
		stale_zone_word_record.level = 0;
		stale_zone_word_record.selected_terrain_id_0x49b53d = 4;
		RuntimeTerrainSelectionRecord49b53d owner_index_record;
		owner_index_record.runtime_zone_index = 20;
		owner_index_record.zone_word_0x4a2777 = 99;
		owner_index_record.level = 0;
		owner_index_record.selected_terrain_id_0x49b53d = 2;
		relation_gate_selection.records = { stale_zone_word_record, owner_index_record };
		std::vector<GeneratorRelationOwnerState4a218c> relation_gate_owners(2);
		for (int32_t index = 0; index < 2; ++index) {
			GeneratorRelationOwnerState4a218c &owner = relation_gate_owners[size_t(index)];
			owner.owner_vector_index = index == 0 ? 0 : 42;
			owner.runtime_zone_index = index == 0 ? 10 : 20;
			owner.source_pointer_0x00_known = true;
			owner.source_pointer_source_index_0x00 = index;
			owner.relation_owner_byte2_0x4aa9b7_known = true;
			owner.relation_owner_byte2_0x4aa9b7 = index == 0 ? 4 : 7;
			owner.coordinate_triple_0x10_0x18_known = true;
			owner.coordinate_x_0x10 = 0;
			owner.coordinate_y_0x14 = 0;
			owner.coordinate_level_0x18 = 0;
			owner.terrain_policy_0x0c_known = true;
			owner.terrain_policy_0x0c = index == 0 ? 4 : 2;
		}
		const TerrainRepaintResult4a3f27 relation_gate_repaint =
				aurelion::h3maped_rmg_core::terrain_repaint_4a3f27(
						2,
						2,
						1,
						relation_gate_materialization,
						relation_gate_selection,
						&relation_gate_owners);
		if (!require(relation_gate_repaint.executed && !relation_gate_repaint.terrain_code.empty(),
					"relation-owner terrain repaint gate did not execute")) {
			return 1;
		}
		if (!require(relation_gate_repaint.terrain_code[0] == 2,
					"0x4a3f27 relation-owner repaint must gate by recovered relation-owner loop index, not source byte, stale terrain zone words, or owner_vector_index field")) {
			return 1;
		}
		if (!require(!relation_gate_repaint.relation_owner_eligibility_marker_0x4a2ec3_applied
						&& relation_gate_repaint.zone_repaint_write_count_0x4a4163 == 1
						&& relation_gate_repaint.member_gate_skip_count_0x4a4150 >= 1
						&& (relation_gate_repaint.generated_cell_word_0x28[3] & aurelion::h3maped_rmg_core::CELL_TERRAIN_RELATION_ELIGIBLE_BIT_28) == 0U,
					"0x4a3f27 mode-0 repaint must consume carried generated-cell +0x28 bit 28 and ignore raw cell_flags")) {
			return 1;
		}
		if (!require(relation_gate_repaint.relation_owner_scan_bounds_0x4a1f3b_applied
						&& relation_gate_repaint.relation_owner_scan_bounds_known_count_0x4a1f3b == 1
						&& relation_gate_repaint.relation_owner_coordinate_recenter_0x4a2ffa_applied
						&& relation_gate_repaint.relation_owner_coordinate_recenter_known_count_0x4a2ffa == 0
						&& relation_gate_repaint.relation_owners_after_scan_bounds_0x4a1f3b_0x4a2ffa.size() == relation_gate_owners.size(),
					"0x4a3f27 did not carry direct relation-owner scan bounds for generated-cell byte2: scan_known="
						+ std::to_string(relation_gate_repaint.relation_owner_scan_bounds_known_count_0x4a1f3b)
						+ " scan_blocked="
						+ std::to_string(relation_gate_repaint.relation_owner_scan_bounds_blocked_count_0x4a1f3b)
						+ " recenter_known="
						+ std::to_string(relation_gate_repaint.relation_owner_coordinate_recenter_known_count_0x4a2ffa)
						+ " recenter_blocked="
						+ std::to_string(relation_gate_repaint.relation_owner_coordinate_recenter_blocked_count_0x4a2ffa))) {
			return 1;
		}
		BoundaryMaterialization4a2777 marker_materialization = relation_gate_materialization;
		marker_materialization.generator_mode_0x10b8 = 2;
		marker_materialization.generated_cell_word_0x28.assign(4, 0U);
		std::vector<GeneratorRelationOwnerState4a218c> marker_owners = relation_gate_owners;
		marker_owners[1].source_pointer_source_index_0x00 = 1;
		marker_owners[1].relation_owner_byte2_0x4aa9b7 = 1;
		const TerrainRepaintResult4a3f27 marker_repaint =
				aurelion::h3maped_rmg_core::terrain_repaint_4a3f27(
						2,
						2,
						1,
						marker_materialization,
						relation_gate_selection,
						&marker_owners);
		if (!require(marker_repaint.relation_owner_eligibility_marker_0x4a2ec3_applied
						&& marker_repaint.relation_owner_eligibility_marker_set_count_0x4a2ec3 == 2
						&& (marker_repaint.generated_cell_word_0x28[0] & aurelion::h3maped_rmg_core::CELL_TERRAIN_RELATION_ELIGIBLE_BIT_28) != 0U
						&& (marker_repaint.generated_cell_word_0x28[1] & aurelion::h3maped_rmg_core::CELL_TERRAIN_RELATION_ELIGIBLE_BIT_28) != 0U
						&& (marker_repaint.generated_cell_word_0x28[3] & aurelion::h3maped_rmg_core::CELL_TERRAIN_RELATION_ELIGIBLE_BIT_28) == 0U,
					"0x4a2ec3 relation-owner eligibility marker did not set exactly the owner-matched cells")) {
			return 1;
		}
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
		ExpectedSmallSelection { 3U, 48, 13, 23, "2SM0k" },
		ExpectedSmallSelection { 11U, 74, 4, 14, "2SM4d" },
		ExpectedSmallSelection { 28U, 130, 25, 35, "3SM3d" },
		ExpectedSmallSelection { 73U, 277, 32, 47, "5SB0b" },
	};
	const int32_t small_size_score = aurelion::h3maped_rmg_core::size_score(36, 36, 1, aurelion::h3maped_rmg_core::water_mode_code("land"));
	if (!require(small_size_score == 4, "Small one-level land size score must feed the recovered 35-candidate H3MapEd selector band")) {
		return 1;
	}
	for (const ExpectedSmallSelection &expected : expected_small_selections) {
		const TemplateSelectionRuntimeResult4ac552 selected = aurelion::h3maped_rmg_core::template_selection_and_runtime_seed_inputs_4ac552_4a218c_4a1f3b(
				expected.seed,
				small_size_score,
				2,
				2);
		if (!require(!selected.blocked, "recovered Small template catalog selection unexpectedly blocked")) {
			return 1;
		}
		if (!require(selected.accepted_template_count == 35, "recovered Small template catalog accepted count mismatch")) {
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
	if (!require(setup0.generator_value_band_0x10bc_known && setup0.generator_value_band_0x10bc == 0, "0x49ecf2 setup object +0x48 default did not copy directly into generator +0x10bc")) {
		return 1;
	}
	const GeneratorSetupModeResult49ecf2 setup0_value_band = aurelion::h3maped_rmg_core::generator_setup_mode_49ecf2(10U, 0, true, 6);
	if (!require(setup0_value_band.generator_value_band_0x10bc_known && setup0_value_band.generator_value_band_0x10bc == 6, "0x49ecf2 setup object +0x48 nonzero value did not copy directly into generator +0x10bc")) {
		return 1;
	}
	if (!require(aurelion::h3maped_rmg_core::setup_value_band_arg_0x4adfe1_to_0x49ecf2(0) == 3
					&& aurelion::h3maped_rmg_core::setup_value_band_arg_0x4adfe1_to_0x49ecf2(-8) == 1
					&& aurelion::h3maped_rmg_core::setup_value_band_arg_0x4adfe1_to_0x49ecf2(9) == 5,
				"0x4adfe1 did not prepare setup object +0x48 as clamp(raw + 3, 1, 5) before 0x49ecf2")) {
		return 1;
	}
	const aurelion::h3maped_rmg_core::GeneratorSetupStackArgs49ecf2 setup_stack = aurelion::h3maped_rmg_core::setup_stack_args_0x4adfe1_to_0x49ecf2(
			72,
			72,
			1,
			true,
			1,
			true,
			aurelion::h3maped_rmg_core::setup_value_band_arg_0x4adfe1_to_0x49ecf2(0),
			true,
			0);
	if (!require(setup_stack.recovered_call_shape_known
					&& !setup_stack.full_args_known
					&& setup_stack.arg_known[0]
					&& setup_stack.args[0] == 72
					&& setup_stack.arg_known[1]
					&& setup_stack.args[1] == 72
					&& setup_stack.arg_known[2]
					&& setup_stack.args[2] == 1
					&& setup_stack.arg_known[7]
					&& setup_stack.args[7] == 1
					&& setup_stack.arg_known[8]
					&& setup_stack.args[8] == 3
					&& setup_stack.arg_known[10]
					&& setup_stack.args[10] == 0
					&& setup_stack.missing_arg_labels.size() == 5,
				"0x4adfe1 -> 0x49ecf2 setup stack model did not preserve known recovered argument order and missing source words")) {
		return 1;
	}
	const aurelion::h3maped_rmg_core::GeneratorSetupStackArgs49ecf2 setup_stack_full = aurelion::h3maped_rmg_core::setup_stack_args_0x4adfe1_to_0x49ecf2(
			72,
			72,
			1,
			true,
			0,
			true,
			aurelion::h3maped_rmg_core::setup_value_band_arg_0x4adfe1_to_0x49ecf2(0),
			true,
			0,
			true,
			1,
			true,
			1,
			true,
			1,
			true,
			0,
			true,
			2);
	if (!require(setup_stack_full.full_args_known
					&& setup_stack_full.missing_arg_labels.empty()
					&& setup_stack_full.args[0] == 72
					&& setup_stack_full.args[1] == 72
					&& setup_stack_full.args[2] == 1
					&& setup_stack_full.args[3] == 1
					&& setup_stack_full.args[4] == 1
					&& setup_stack_full.args[5] == 1
					&& setup_stack_full.args[6] == 0
					&& setup_stack_full.args[7] == 0
					&& setup_stack_full.args[8] == 3
					&& setup_stack_full.args[9] == 2
					&& setup_stack_full.args[10] == 0,
				"0x4adfe1 -> 0x49ecf2 full setup stack model did not preserve all recovered source words")) {
		return 1;
	}
	const aurelion::h3maped_rmg_core::GeneratorBackingStateConstructor49d914 backing_state_missing_arg9 =
			aurelion::h3maped_rmg_core::generator_backing_state_constructor_0x49d914(
					72,
					72,
					1,
					false,
					0,
					true,
					0);
	if (!require(backing_state_missing_arg9.invoked
					&& !backing_state_missing_arg9.applied
					&& backing_state_missing_arg9.allocation_size_arg_0x18_known
					&& backing_state_missing_arg9.allocation_size_arg_0x18 == 72 * 72 + 0x4fcf4
					&& !backing_state_missing_arg9.source_handler_arg_0x14_known
					&& backing_state_missing_arg9.generator_field_0x08_known
					&& backing_state_missing_arg9.generator_field_0x08 == 0
					&& backing_state_missing_arg9.generator_field_0x04_known
					&& backing_state_missing_arg9.generator_field_0x04 == 0x3a
					&& backing_state_missing_arg9.generator_vtable_0x00_known
					&& backing_state_missing_arg9.generator_vtable_0x00 == aurelion::h3maped_rmg_core::GENERATOR_OBJECT_VTABLE_0X540CB0
					&& backing_state_missing_arg9.blocked_reason == "0x49d914_source_handler_arg9_from_0x4adfe1_caller_stack_ebp_0x0c_missing",
				"0x49d914 constructor did not fail closed on missing source-handler arg9 while preserving recovered scalar fields")) {
		return 1;
	}
	const aurelion::h3maped_rmg_core::GeneratorBackingStateConstructor49d914 backing_state_zero_handler =
			aurelion::h3maped_rmg_core::generator_backing_state_constructor_0x49d914(
					72,
					72,
					1,
					true,
					0,
					true,
					-7);
	if (!require(backing_state_zero_handler.applied
					&& backing_state_zero_handler.generator_field_0xed4_known
					&& backing_state_zero_handler.generator_field_0xed4 == 0
					&& backing_state_zero_handler.generator_field_0x08_known
					&& backing_state_zero_handler.generator_field_0x08 == -7
					&& !backing_state_zero_handler.source_handler_virtual_init_invoked
					&& backing_state_zero_handler.object_table_loader_invoked_0x49da08,
				"0x49d914 constructor did not model zero source-handler field writes and object-table loader handoff")) {
		return 1;
	}
	const aurelion::h3maped_rmg_core::GeneratorBackingStateConstructor49d914 backing_state_nonzero_handler =
			aurelion::h3maped_rmg_core::generator_backing_state_constructor_0x49d914(
					72,
					72,
					1,
					true,
					0x1234,
					true,
					0);
	if (!require(backing_state_nonzero_handler.applied
					&& backing_state_nonzero_handler.generator_field_0xed4_known
					&& backing_state_nonzero_handler.generator_field_0xed4 == 0x1234
					&& backing_state_nonzero_handler.source_handler_virtual_init_invoked
					&& backing_state_nonzero_handler.source_handler_virtual_init_offset_known
					&& backing_state_nonzero_handler.source_handler_virtual_init_offset == 72 * 72 + 0x4fcf4 + 0x3bc4
					&& backing_state_nonzero_handler.blocked_reason.empty(),
				"0x49d914 constructor did not model recovered nonzero optional handler path")) {
		return 1;
	}
	const aurelion::h3maped_rmg_core::GeneratorSetupStackArgs49ecf2 setup_stack_normalized = aurelion::h3maped_rmg_core::setup_stack_args_0x4adfe1_to_0x49ecf2(
			72,
			72,
			1,
			true,
			0,
			true,
			3,
			true,
			0,
			true,
			1,
			true,
			2,
			true,
			0,
			true,
			4,
			true,
			2);
	if (!require(setup_stack_normalized.full_args_known
					&& setup_stack_normalized.args[3] == 0
					&& setup_stack_normalized.args[4] == 2
					&& setup_stack_normalized.args[5] == 0
					&& setup_stack_normalized.args[6] == 4,
				"0x4adfe1 did not zero setup +0x34/+0x3c stack args when their recovered sum is below 2")) {
		return 1;
	}
	const GeneratorSetupModeResult49ecf2 setup0_field08 = aurelion::h3maped_rmg_core::generator_setup_mode_49ecf2(10U, 0, true, 0, true, -7);
	if (!require(setup0_field08.setup_object_0x4c_known
					&& setup0_field08.setup_object_0x4c == -7
					&& setup0_field08.generator_field_0x08_known
					&& setup0_field08.generator_field_0x08 == -7,
				"0x49ecf2 setup object +0x4c did not populate generator +0x08")) {
		return 1;
	}
	const GeneratorSetupModeResult49ecf2 setup_fields = aurelion::h3maped_rmg_core::generator_setup_mode_49ecf2(
			10U,
			0,
			true,
			3,
			true,
			0,
			true,
			1,
			true,
			2,
			true,
			1,
			true,
			4,
			true,
			2);
	if (!require(setup_fields.generator_field_0xf48_known
					&& setup_fields.generator_field_0xf48 == 1
					&& setup_fields.generator_field_0xf4c_known
					&& setup_fields.generator_field_0xf4c == 2
					&& setup_fields.generator_field_0xf50_known
					&& setup_fields.generator_field_0xf50 == 1
					&& setup_fields.generator_field_0xf54_known
					&& setup_fields.generator_field_0xf54 == 4
					&& setup_fields.setup_fields_0x4adfe1.setup_caller_arg_0x0c_known
					&& setup_fields.setup_fields_0x4adfe1.setup_caller_arg_0x0c == 2,
				"0x49ecf2 did not copy recovered setup fields into generator +0xf48/+0xf4c/+0xf50/+0xf54")) {
		return 1;
	}
	const GeneratorSetupModeResult49ecf2 setup_fields_zeroed = aurelion::h3maped_rmg_core::generator_setup_mode_49ecf2(
			10U,
			0,
			true,
			3,
			true,
			0,
			true,
			1,
			true,
			2,
			true,
			0,
			true,
			4,
			true,
			2);
	if (!require(setup_fields_zeroed.setup_fields_0x4adfe1.normalized_pair_0x34_0x3c_known
					&& setup_fields_zeroed.setup_fields_0x4adfe1.normalized_pair_0x34_0x3c_zeroed
					&& setup_fields_zeroed.generator_field_0xf48 == 0
					&& setup_fields_zeroed.generator_field_0xf50 == 0,
				"0x49ecf2 setup field normalization did not zero generator +0xf48/+0xf50 for a below-two +0x34/+0x3c pair")) {
		return 1;
	}
	const GeneratorSetupModeResult49ecf2 setup3 = aurelion::h3maped_rmg_core::generator_setup_mode_49ecf2(10U, 3, true, 3);
	if (!require(setup3.randomized_setup_sentinel_3 && setup3.setup_rng_value == 71 && setup3.generator_mode_0x10b8 == 2 && setup3.setup_rng_call_count == 1, "0x49ecf2 setup sentinel 3 must randomize generator mode with rand % 3")) {
		return 1;
	}
	if (!require(setup3.rng_state_before_template_selection == 0x004746a5U, "0x49ecf2 setup sentinel 3 did not hand off post-setup RNG state")) {
		return 1;
	}
	const TemplateSelectionRuntimeResult4ac552 selected_after_setup3 = aurelion::h3maped_rmg_core::template_selection_and_runtime_seed_inputs_4ac552_4a218c_4a1f3b(
			setup3.rng_state_before_template_selection,
			small_size_score,
			2,
			2);
	if (!require(selected_after_setup3.rng_value == 16899, "template selection must consume RNG after setup sentinel randomization")) {
		return 1;
	}
	const GeneratorSetupModeResult49ecf2 setup3_seed58 = aurelion::h3maped_rmg_core::generator_setup_mode_49ecf2(58U, 3, true, 3);
	const TemplateSelectionRuntimeResult4ac552 selected_after_setup3_seed58 =
			aurelion::h3maped_rmg_core::template_selection_and_runtime_seed_inputs_4ac552_4a218c_4a1f3b(
					setup3_seed58.rng_state_before_template_selection,
					small_size_score,
					2,
					2);

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
	for (const RuntimeZoneBoundaryInput4a3a03 &boundary_input : composed.coordinate_seed.boundary_inputs) {
		const auto owner_it = std::find_if(
				composed.coordinate_seed.relation_owner_vectors_10e4_10e8.begin(),
				composed.coordinate_seed.relation_owner_vectors_10e4_10e8.end(),
				[&](const GeneratorRelationOwnerState4a218c &owner) {
					return owner.runtime_zone_index == boundary_input.footprint.runtime_zone_index;
				});
		if (!require(owner_it != composed.coordinate_seed.relation_owner_vectors_10e4_10e8.end(), "coordinate seed boundary input lost its generator+0x10e4 relation owner")) {
			return 1;
		}
		if (!require(boundary_input.has_source_record_seed_0x10 && owner_it->coordinate_triple_0x10_0x18_known,
					"coordinate seed did not expose selected relation-owner +0x10 source-record seed")) {
			return 1;
		}
		if (!require(boundary_input.source_record_seed_0x10.x == owner_it->coordinate_x_0x10
						&& boundary_input.source_record_seed_0x10.y == owner_it->coordinate_y_0x14
						&& boundary_input.source_record_seed_0x10.level == owner_it->coordinate_level_0x18,
					"coordinate seed boundary input used synthetic coordinates instead of relation-owner +0x10 seed")) {
			return 1;
		}
	}
	{
		std::vector<RuntimeZoneSeedInput4a218c> fixed_town_zones(1);
		fixed_town_zones[0].runtime_zone_index = 0;
		fixed_town_zones[0].source_zone_id = 7;
		fixed_town_zones[0].source_index = 0;
		fixed_town_zones[0].source_owner_index = 0;
		fixed_town_zones[0].actual_player_color = 0;
		fixed_town_zones[0].source_base_size = 12;
		fixed_town_zones[0].allowed_town_mask_0x41_0x49 = 0x01ffU;
		fixed_town_zones[0].source_payload.player_towns.min_towns = 1;
		fixed_town_zones[0].fixed_player_town_choice_index_0xf24 = 5;
		const auto fixed_town_coordinate =
				aurelion::h3maped_rmg_core::coordinate_seed_runtime_zone_boundary_inputs_4a218c_4a1f3b_4a19ed(
						36,
						36,
						1,
						0,
						1234U,
						fixed_town_zones,
						{});
		if (!require(!fixed_town_coordinate.blocked
						&& fixed_town_coordinate.town_choice_rng_call_count_0x49b3c1 == 1
						&& fixed_town_coordinate.runtime_zone_records_after_0x49b3c1.size() == 1
						&& fixed_town_coordinate.runtime_zone_records_after_0x49b3c1[0].fixed_player_town_choice_index_0xf24 == 5
						&& fixed_town_coordinate.relation_owner_vectors_10e4_10e8.size() == 1
						&& fixed_town_coordinate.relation_owner_vectors_10e4_10e8[0].town_choice_0x04_known
						&& fixed_town_coordinate.relation_owner_vectors_10e4_10e8[0].town_choice_0x04 == 5,
					"0x4a218c did not apply generator+0xf24 fixed player town override after 0x49b3c1 RNG")) {
			return 1;
		}
	}
	const CoordinateOwnerGridResult4a218c rectangular_composed = aurelion::h3maped_rmg_core::coordinate_seed_and_materialize_owner_grid_4a218c_4a1f3b_4a19ed_4a3a03_4cca55_4a2777_4a325d_4a3710(
			72,
			36,
			1,
			aurelion::h3maped_rmg_core::water_mode_code("land"),
			0,
			1234U,
			seed_inputs,
			links);
	if (!require(!rectangular_composed.coordinate_seed_blocked, "rectangular coordinate seed blocked before 0x4a19ed map-span check")) {
		return 1;
	}
	if (!require(rectangular_composed.coordinate_seed.map_span == 72, "0x4a19ed rescale must use the larger map dimension")) {
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
	if (!require(composed.owner_grid.handoffs.size() >= seed_inputs.size(), "coordinate-to-owner-grid chain did not materialize handoffs for all original zones")) {
		return 1;
	}
	if (!require(composed.terrain_selection_executed, "coordinate-to-owner-grid chain did not execute 0x49b53d before owner-grid materialization")) {
		return 1;
	}
	if (!require(composed.terrain_selection.rng_state_before == composed.coordinate_seed.rng_state_after, "0x49b53d did not consume coordinate seed output RNG state")) {
		return 1;
	}
	if (!require(composed.owner_grid.materialization.rng_state_before == composed.terrain_selection.rng_state_after_monster_town_0x49b4e1, "owner-grid phase did not consume post-0x4a218c terrain/monster RNG state")) {
		return 1;
	}
	if (!require(composed.terrain_repaint.terrain_visual_rng_state_before_0x4bb74b == composed.owner_grid.materialization.rng_state_after, "0x4a3f27 did not consume post-owner-grid RNG state")) {
		return 1;
	}
	if (!require(composed.terrain_selection_executed && composed.terrain_repaint_executed, "composed chain did not execute 0x49b53d terrain selection and 0x4a3f27 terrain repaint")) {
		return 1;
	}
	if (!require(composed.terrain_repaint.full_map_water_repaint_count_0x4a4025 == 36 * 36, "composed chain did not apply terrain full-map repaint")) {
		return 1;
	}
	if (!require(composed.terrain_repaint.relation_owner_scan_bounds_0x4a1f3b_applied
					&& composed.terrain_repaint.relation_owner_coordinate_recenter_0x4a2ffa_applied
					&& composed.terrain_repaint.relation_owners_after_scan_bounds_0x4a1f3b_0x4a2ffa.size() == seed_inputs.size(),
				"composed chain did not expose source-order relation-owner state after 0x4a3f27")) {
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
	const CoordinateOwnerGridResult4a218c selected_composed_seed58 = aurelion::h3maped_rmg_core::coordinate_seed_and_materialize_owner_grid_4a218c_4a1f3b_4a19ed_4a3a03_4cca55_4a2777_4a325d_4a3710(
			36,
			36,
			1,
			aurelion::h3maped_rmg_core::water_mode_code("land"),
			setup3_seed58.generator_mode_0x10b8,
			selected_after_setup3_seed58.rng_state_after_template_selection,
			selected_after_setup3_seed58.runtime_seed.runtime_zone_seeds,
			selected_after_setup3_seed58.runtime_seed.runtime_links);
	if (!require(!selected_composed_seed58.coordinate_seed_blocked, "seed-58 selected-template coordinate chain blocked before generator private-state handoff")) {
		return 1;
	}
	H3MapedRmgWorkflowConfig generator_state_workflow_config;
	generator_state_workflow_config.size_class = "small";
	generator_state_workflow_config.water_mode = "land";
	generator_state_workflow_config.width = 36;
	generator_state_workflow_config.height = 36;
	generator_state_workflow_config.level_count = 1;
	generator_state_workflow_config.human_count = 1;
	generator_state_workflow_config.player_count = 2;
	generator_state_workflow_config.seed = 58U;
	generator_state_workflow_config.setup_object_0x44_known = true;
	generator_state_workflow_config.setup_object_0x44 = 3;
	generator_state_workflow_config.setup_object_raw_0x48_known = true;
	generator_state_workflow_config.setup_object_raw_0x48 = 0;
	generator_state_workflow_config.setup_object_0x48_known = false;
	generator_state_workflow_config.setup_object_0x48 = 0;
		const H3MapedRmgWorkflowResult generator_state_workflow =
				aurelion::h3maped_rmg_core::run_h3maped_rmg_entry_to_writeout_workflow(generator_state_workflow_config);
		const GeneratorObjectPrivateState &generator_state = generator_state_workflow.generator_object_private_state;
		const std::string final_payload_compare_blocker =
				"same_run_payload_authority_missing_recovered_profile_metadata";
		if (!require(generator_state_workflow.executed
						&& generator_state_workflow.current_phase_id == "final_payload_compare"
						&& generator_state_workflow.blocked_reason == final_payload_compare_blocker
						&& generator_state_workflow.final_payload_writeout_0x4ad1e3.applied
						&& generator_state_workflow.final_payload_owned
						&& generator_state_workflow.final_writeout_complete,
					"workflow-owned generator state did not continue past zero reward/guard commits to final payload compare")) {
			return 1;
		}
	if (!require(generator_state.generated_cell_buffer_owned && generator_state.generated_cell_buffer.records.size() == 36U * 36U, "generator object private state did not own the generated-cell buffer at +0x14")) {
		return 1;
	}
	if (!require(generator_state_workflow.setup_mode_0x49ecf2.generator_value_band_0x10bc_known
					&& generator_state_workflow.setup_mode_0x49ecf2.generator_value_band_0x10bc == 3,
				"entry-to-writeout workflow did not feed recovered 0x4adfe1 prepared raw +0x48 into 0x49ecf2")) {
		return 1;
	}
	if (!require(generator_state.width == 36 && generator_state.height == 36 && generator_state.level_count == 1, "generator object private state did not preserve +0x18/+0x1c/+0x20 dimensions")) {
		return 1;
	}
	if (!require(generator_state.generator_value_band_0x10bc_known && generator_state.generator_value_band_0x10bc == setup3_seed58.generator_value_band_0x10bc, "generator object private state did not preserve setup-derived generator +0x10bc value band")) {
		return 1;
	}
	if (!require(generator_state.generator_field_0x08_known && generator_state.generator_field_0x08 == setup3_seed58.generator_field_0x08, "generator object private state did not preserve setup-derived generator +0x08 field")) {
		return 1;
	}
	if (!require(generator_state.candidate_container_vector_10d4_10d8.count_known && generator_state.candidate_container_vector_10d4_10d8.count == selected_after_setup3_seed58.accepted_template_count, "generator object private state did not preserve accepted candidate vector count")) {
		return 1;
	}
	if (!require(generator_state.source_owner_player_slots_ed8_ee0_ee4_present && generator_state.selected_color_order_ed8_count == int32_t(selected_after_setup3_seed58.player_assignment.selected_color_order_ed8.size()), "generator object private state did not preserve source-owner/player-slot buffers")) {
		return 1;
	}
	if (!require(generator_state.selected_color_order_ed8 == selected_after_setup3_seed58.player_assignment.selected_color_order_ed8
					&& generator_state.raw_source_owner_slots_ee0 == selected_after_setup3_seed58.player_assignment.raw_ee0_slots
					&& generator_state.mapped_source_owner_slots_ee4 == selected_after_setup3_seed58.player_assignment.mapped_ee4_slots,
					"generator object private state preserved source-owner/player-slot counts without preserving the actual ed8/ee0/ee4 lane contents")) {
		return 1;
	}
	const auto blocker_prefix_matches = [](const std::string &value, const std::string &prefix) {
		return value.rfind(prefix, 0) == 0;
	};
	if (!require(generator_state.source_order_relation_pointer_loop_0x4ac552_ported
					&& generator_state.source_order_relation_pointer_loop_0x4ac552_input_known
					&& generator_state.source_order_relation_pointer_loop_0x4ac552_applied
					&& generator_state.relation_owner_vector_produced_by_0x4ac552_0x4a218c
					&& generator_state.relation_owner_vector_selected_candidate_input_known
					&& generator_state.source_order_relation_pointer_loop_relation_count_0x10e4 == generator_state.relation_owner_vector_count_10e4_10e8
					&& generator_state.source_order_relation_pointer_loop_source_record_field_0x04_known_count > 0
					&& generator_state.source_order_relation_pointer_loop_direct_replay_count_0x4a8d2c > 0
					&& generator_state.source_order_relation_pointer_loop_scheduler_replay_count_0x4a8db2 > 0
					&& generator_state_workflow.current_phase_id == "final_payload_compare",
				"generator object private state did not preserve the recovered 0x4ac552 relation-pointer source-record loop through final compare")) {
		return 1;
	}
	if (!require(generator_state.route_container_free_cell_sweep_0x4a8260_applied
					&& generator_state.materialization_bridge_post_4a4c8e_cleanup_0x4a8c15_ported
					&& generator_state.materialization_bridge_post_4a4c8e_cleanup_0x4a8c15_input_known
					&& generator_state.materialization_bridge_post_4a4c8e_cleanup_0x4a8c15_applied
					&& generator_state.materialization_bridge_post_4a4c8e_cleanup_scan_count_0x4a8c15 == 36 * 36
					&& generator_state.materialization_bridge_relation_loop_0x4a4913_ported
					&& generator_state.materialization_bridge_relation_loop_0x4a4913_input_known
					&& generator_state.materialization_bridge_relation_loop_0x4a4913_applied
						&& generator_state.materialization_bridge_relation_loop_relation_count_0x4a4913 == int32_t(generator_state.relation_owner_vectors_10e4_10e8.size())
						&& generator_state.relation_normalization_4a5767_full_grid_reset_applied
						&& generator_state.relation_scan_consumers_4a5767_applied
						&& generator_state.relation_high_owner_propagation_49a318_applied
						&& generator_state.materialization_bridge_water_edge_writer_0x4a4fc5_ported
						&& generator_state.materialization_bridge_water_edge_writer_0x4a4fc5_input_known
						&& generator_state.materialization_bridge_water_edge_writer_0x4a4fc5_applied
						&& generator_state.materialization_bridge_water_edge_writer_0x4a4fc5_source_backed_land_scope
						&& generator_state.materialization_bridge_water_edge_writer_scan_count_0x4a4fc5 == 36 * 36
						&& generator_state.materialization_bridge_water_edge_writer_bit26_candidate_count_0x4a4fc5 == 0
						&& generator_state.relation_source_order_scan_0x4a89da_ported
						&& generator_state.relation_source_order_scan_0x4a89da_prefix_applied
						&& generator_state.relation_source_order_scan_0x4a89da_helper_chain_complete
						&& generator_state.relation_source_order_scan_0x4a89da.invoked
						&& generator_state.relation_source_order_scan_0x4a89da.blocked_reason.empty()
						&& generator_state.mine_resource_materialization_0x4a9d6a.invoked
						&& generator_state.reward_guard_source_stream_0x4aab7e.invoked
						&& generator_state.reward_guard_source_stream_0x4aab7e.applied
						&& generator_state.reward_guard_source_stream_0x4aab7e.blocked_reason.empty()
						&& generator_state.reward_guard_source_stream_0x4aab7e.materialization_attempt_count > 0
						&& generator_state.reward_guard_source_stream_0x4aab7e.successful_coordinate_scan_count > 0
						&& generator_state.decorative_flagged_cell_dispatch_0x49eb8d.invoked
						&& generator_state.decorative_flagged_cell_dispatch_0x49eb8d.applied
						&& generator_state.connection_tail_replay_0x4a79a3.invoked
						&& generator_state.connection_tail_replay_0x4a79a3.applied
						&& generator_state.road_river_object_adjacency_0x4ab52a.invoked
						&& generator_state.road_river_object_adjacency_0x4ab52a.applied,
							"generator object private state did not carry source-backed reward/guard materialization into downstream source-order phases")) {
		return 1;
	}
	if (!require(generator_state.relation_vector_10e4_10e8.present && generator_state.relation_vector_10e4_10e8.contents_known, "generator object private state must keep relation/object state explicit")) {
		return 1;
	}
	if (!require(generator_state.relation_vector_10e4_10e8.count_known && generator_state.relation_vector_10e4_10e8.count == generator_state.relation_owner_vector_count_10e4_10e8, "generator object private state did not preserve selected-candidate relation-vector count")) {
		return 1;
	}
	if (!require(generator_state.relation_owner_records_10e4_10e8_partial_known
					&& generator_state.relation_owner_vector_produced_by_0x4ac552_0x4a218c
					&& generator_state.relation_owner_vector_selected_candidate_source_catalog_index == selected_after_setup3_seed58.selected_source_catalog_index
					&& generator_state.relation_owner_vector_selected_candidate_template_name == selected_after_setup3_seed58.selected_template_name,
				"generator object private state did not carry recovered selected-candidate 0x4ac552 -> 0x4a218c/0x49f7c4 relation owner records")) {
		return 1;
	}
	if (!require(generator_state.relation_owner_vector_count_10e4_10e8 > 0, "generator selected-candidate relation owner vector is empty")) {
		return 1;
	}
	if (!require(generator_state.relation_record_missing_endpoint_count_10e4_10e8 == 0, "generator relation owner records lost a selected runtime-link endpoint")) {
		return 1;
	}
	const int32_t expected_relation_record_count = int32_t(selected_after_setup3_seed58.runtime_seed.runtime_links.size()) * 2;
	if (!require(generator_state.relation_record_count_10e4_10e8 == expected_relation_record_count, "generator relation records did not mirror 0x49f7c4 reciprocal link append count")) {
		return 1;
	}
	int32_t summed_relation_record_count = 0;
	int32_t summed_source_endpoint_record_count = 0;
	int32_t summed_owner_local_vector_0x404_count = 0;
	int32_t relation_owner_source_slot_known_count = 0;
	int32_t relation_owner_town_choice_known_count = 0;
	int32_t relation_owner_success_byte_0x3c_set_count = 0;
	int32_t relation_owner_missing_scan_bounds_count = 0;
	const int32_t expected_relation_order_word_count_0x49b61b =
			generator_state.relation_owner_vector_count_10e4_10e8;
	auto relation_owner_vector_index_for_runtime_zone = [&](int32_t runtime_zone_index) {
		for (int32_t index = 0; index < int32_t(generator_state.relation_owner_vectors_10e4_10e8.size()); ++index) {
			if (generator_state.relation_owner_vectors_10e4_10e8[size_t(index)].runtime_zone_index == runtime_zone_index) {
				return index;
			}
		}
		return -1;
	};
	for (const aurelion::h3maped_rmg_core::GeneratorRelationOwnerState4a218c &owner : generator_state.relation_owner_vectors_10e4_10e8) {
		summed_relation_record_count += owner.relation_record_count;
		if (!require(owner.constructor_0x49b452_known, "generator relation owner did not carry recovered 0x49b452 constructor state")) {
			return 1;
		}
		if (!require(owner.source_pointer_0x00_known && owner.source_pointer_source_index_0x00 == owner.source_index, "0x49b452 relation owner source pointer/source index was not preserved")) {
			return 1;
		}
		if (!require(owner.relation_owner_byte2_0x4aa9b7_known && owner.relation_owner_byte2_0x4aa9b7 == owner.source_pointer_source_index_0x00, "0x49b452 relation owner byte for reward/guard and bridge scans did not use the recovered source-record owner id")) {
			return 1;
		}
		const bool owner_scan_bounds_materialized =
				owner.scan_bounds_0x20_0x2c_known
				&& owner.scan_bound_low_x_0x20 < owner.scan_bound_high_x_0x28
				&& owner.scan_bound_low_y_0x24 < owner.scan_bound_high_y_0x2c;
		if (!owner_scan_bounds_materialized) {
			relation_owner_missing_scan_bounds_count += 1;
		}
		const bool owner_type8_branch_reads_scan_bounds =
				owner.terrain_policy_0x0c_known && owner.terrain_policy_0x0c == 8;
		if (owner_type8_branch_reads_scan_bounds) {
			if (!require(owner_scan_bounds_materialized,
						"0x4a4913 type8 relation owner scan bounds were not materialized before relation scan consumers ran")) {
				return 1;
			}
		}
		if (!require(owner.byte_0x3c_known, "relation owner source-order success byte +0x3c was not carried")) {
			return 1;
		}
		if (owner.byte_0x3c != 0U) {
			relation_owner_success_byte_0x3c_set_count += 1;
		}
		if (!require(owner.descriptor_type_counter_table_0x44_known
						&& owner.descriptor_type_counter_table_0x44_byte_size == aurelion::h3maped_rmg_core::RELATION_OWNER_DESCRIPTOR_TABLE_0X44_BYTE_SIZE
						&& owner.descriptor_type_counter_table_0x44_zero_count <= aurelion::h3maped_rmg_core::RELATION_OWNER_DESCRIPTOR_TABLE_0X44_DWORD_COUNT,
					"0x49b452 relation owner descriptor table +0x44 was not initialized")) {
			return 1;
		}
		if (!require(owner.descriptor_type_counters_0x44.size() == size_t(aurelion::h3maped_rmg_core::RELATION_OWNER_DESCRIPTOR_TABLE_0X44_DWORD_COUNT),
					"0x49b452 relation owner descriptor table +0x44 does not carry concrete dwords")) {
			return 1;
		}
		if (!require(owner.owner_local_vectors_0x3e4_0x3f4_0x404_known
						&& owner.owner_local_vector_0x3e4_count == expected_relation_order_word_count_0x49b61b
						&& owner.owner_local_vector_0x3f4_count == 0
						&& owner.owner_local_vector_0x404_count >= 0,
					"0x49b452/0x49b61b relation owner local vectors did not preserve order-vector and connection-tail state")) {
			return 1;
		}
		if (!require(owner.relation_order_words_0x3e8_known
						&& int32_t(owner.relation_order_words_0x3e8.size()) == expected_relation_order_word_count_0x49b61b,
					"0x49b61b relation order word vector +0x3e8 was not materialized per source relation owner")) {
			return 1;
		}
		const int32_t source_order_slot_0x49b61b = owner.source_pointer_0x00_known
				? owner.source_pointer_source_index_0x00
				: owner.source_index;
		if (!require(source_order_slot_0x49b61b >= 0
						&& source_order_slot_0x49b61b < expected_relation_order_word_count_0x49b61b
						&& owner.relation_order_words_0x3e8[size_t(source_order_slot_0x49b61b)] == 0,
					"0x49b61b relation order vector did not zero the owner source slot")) {
			return 1;
		}
		summed_owner_local_vector_0x404_count += owner.owner_local_vector_0x404_count;
		int32_t expected_recenter_x = 0;
		int32_t expected_recenter_y = 0;
		int32_t expected_recenter_level = 0;
		int32_t expected_recenter_match_count = 0;
		const bool recenter_coordinate_known =
				expected_recenter_coordinate_0x4a2ffa(
						generator_state.generated_cell_buffer,
						owner,
						expected_recenter_x,
						expected_recenter_y,
						expected_recenter_level,
						expected_recenter_match_count);
		if (!recenter_coordinate_known) {
			if (!require(!owner_scan_bounds_materialized,
						"0x4a2ffa relation owner coordinate recenter did not find recovered-owner-byte generated cells")) {
				return 1;
			}
		} else {
			if (!require(owner.coordinate_triple_0x10_0x18_known
							&& owner.coordinate_x_0x10 == expected_recenter_x
							&& owner.coordinate_y_0x14 == expected_recenter_y
							&& owner.coordinate_level_0x18 == expected_recenter_level
							&& expected_recenter_match_count > 0,
						"0x4a2ffa relation owner coordinate triple +0x10..+0x18 was not recentered from generated-cell owner bytes")) {
				return 1;
			}
		}
		int32_t expected_source_endpoint_count = 0;
		for (const RuntimeLinkSeedInput4a218c &link : selected_after_setup3_seed58.runtime_seed.runtime_links) {
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
			summed_source_endpoint_record_count += 1;
			if (!require(endpoint_record.owner_runtime_zone_index == owner.runtime_zone_index
							&& endpoint_record.owner_source_zone_id == owner.source_zone_id
							&& endpoint_record.source_link_index >= 0
							&& endpoint_record.source_link_index < int32_t(selected_after_setup3_seed58.runtime_seed.runtime_links.size()),
						"0x4a1f3b source endpoint record did not preserve owner/link identity")) {
				return 1;
			}
			const RuntimeLinkSeedInput4a218c &runtime_link = selected_after_setup3_seed58.runtime_seed.runtime_links[size_t(endpoint_record.source_link_index)];
			const int32_t expected_target_runtime_zone = runtime_link.from_index == owner.runtime_zone_index ? runtime_link.to_index : runtime_link.from_index;
			const int32_t expected_target_owner_vector_index = relation_owner_vector_index_for_runtime_zone(expected_target_runtime_zone);
			if (!require(expected_target_owner_vector_index >= 0
							&& endpoint_record.target_relation_owner_vector_index_0x00 == expected_target_owner_vector_index
							&& endpoint_record.target_runtime_zone_index == expected_target_runtime_zone,
						"0x4a1f3b source endpoint record first dword did not preserve target relation-owner vector index")) {
				return 1;
			}
			if (!require(endpoint_record.guard_value == runtime_link.guard_value
							&& endpoint_record.wide == runtime_link.wide
							&& endpoint_record.border_guard == runtime_link.border_guard,
						"0x4a1f3b source endpoint record did not preserve selected link payload")) {
				return 1;
			}
		}
		int32_t expected_candidate_vector_step_count = 0;
		int32_t expected_candidate_after_prune_total_count = 0;
		for (const auto &step : selected_composed_seed58.coordinate_seed.placement_steps) {
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
		if (!require(owner.adjacency_vector_0xc4_present
						&& owner.adjacency_vector_0xc4_contents_known
						&& owner.adjacency_vector_0xc4_count_known
						&& owner.adjacency_record_count_0xc4 == int32_t(owner.adjacency_records_0xc4.size()),
					"generator relation owner +0xc4 adjacency vector was not materialized with a trusted count")) {
			return 1;
		}
		if (!require(owner.adjacency_record_count_0xc4 >= owner.relation_record_count,
					"generator relation owner +0xc4 adjacency vector lost source-backed 0x49f7c4 relation records")) {
			return 1;
		}
	}
	if (!require(relation_owner_source_slot_known_count > 0, "0x49b452 relation owner source +0x08 to owner +0x1c slot was not carried for any owner")) {
		return 1;
	}
	if (!require(generator_state.source_order_relation_pointer_loop_direct_commit_count_0x4a8d2c
						+ generator_state.source_order_relation_pointer_loop_scheduler_commit_count_0x4a8db2 == 0
					|| relation_owner_success_byte_0x3c_set_count > 0,
				"0x4a8d2c/0x4a8db2 relation-pointer commits did not mark any relation owner +0x3c success byte")) {
		return 1;
	}
	if (!require(summed_owner_local_vector_0x404_count >= 0,
				"relation-owner 0x404 vectors were not preserved before the 0x4a89da helper-chain boundary")) {
		return 1;
	}
	if (!require(relation_owner_town_choice_known_count > 0, "0x49b452 relation owner town choice +0x04 was not carried from post-0x49b3c1 seed state")) {
		return 1;
	}
	if (!require(generator_state.relation_owner_scan_bounds_0x4a1f3b_applied
					&& generator_state.relation_owner_scan_bounds_known_count_0x4a1f3b > 0
					&& generator_state.relation_owner_scan_bounds_known_count_0x4a1f3b
							+ generator_state.relation_owner_scan_bounds_blocked_count_0x4a1f3b
							>= generator_state.relation_owner_vector_count_10e4_10e8,
				"0x4a1f3b relation-owner scan-bound pass did not run before relation scan consumers")) {
		return 1;
	}
	if (!require(generator_state.relation_owner_coordinate_recenter_0x4a2ffa_applied
					&& generator_state.relation_owner_coordinate_recenter_known_count_0x4a2ffa > 0
					&& generator_state.relation_owner_coordinate_recenter_known_count_0x4a2ffa
							+ generator_state.relation_owner_coordinate_recenter_blocked_count_0x4a2ffa
							>= generator_state.relation_owner_vector_count_10e4_10e8
					&& generator_state.relation_owner_coordinate_recenter_matched_cell_count_0x4a2ffa > 0,
				"0x4a2ffa relation-owner coordinate recenter pass did not run before route/object consumers")) {
		return 1;
	}
	if (!require(summed_relation_record_count == generator_state.relation_record_count_10e4_10e8, "generator relation record total does not equal sum of owner vectors")) {
		return 1;
	}
	if (!require(summed_source_endpoint_record_count > 0, "generator relation owners did not preserve source endpoint records before reward/guard")) {
		return 1;
	}
	if (!require(generator_state.relation_source_order_scan_0x4a89da.invoked
					&& generator_state.relation_source_order_scan_0x4a89da.prefix_applied
					&& generator_state.relation_source_order_scan_0x4a89da.helper_chain_complete
					&& generator_state_workflow.current_phase_id == "final_payload_compare"
					&& generator_state.mine_resource_materialization_0x4a9d6a.invoked
					&& generator_state.reward_guard_source_stream_0x4aab7e.invoked
					&& generator_state.reward_guard_source_stream_0x4aab7e.blocked_reason.empty()
					&& generator_state.reward_guard_source_stream_0x4aab7e.successful_coordinate_scan_count > 0
					&& generator_state.decorative_flagged_cell_dispatch_0x49eb8d.invoked
					&& generator_state.connection_tail_replay_0x4a79a3.invoked
					&& generator_state.road_river_object_adjacency_0x4ab52a.invoked,
				"generator object private state did not continue after source-backed reward/guard materialization into final compare")) {
		return 1;
	}
	if (!require(generator_state.relation_normalization_4a5767_full_grid_reset_applied, "generator object private state did not apply 0x4a5767 after the 0x4a4913 materialization bridge relation loop")) {
		return 1;
	}
	if (!require(generator_state.relation_normalization_4a5767_full_grid_reset_visited_count >= int32_t(generator_state.generated_cell_buffer.records.size()), "0x4a5767 full-grid reset did not visit every generated-cell record across recovered bridge/relation passes")) {
		return 1;
	}
	if (!require(generator_state.relation_normalization_4a5767_full_grid_reset_skipped_count == 0, "0x4a5767 full-grid reset skipped known generated-cell records")) {
		return 1;
	}
	if (!require(generator_state.relation_normalization_4a5767_full_grid_reset_changed_count > 0, "0x4a5767 full-grid reset did not mutate any generated-cell records")) {
		return 1;
	}
	if (!require(generator_state.relation_scan_consumers_4a5767_applied
					&& generator_state.relation_scan_consumer_owner_scan_count_4a5767 == generator_state.relation_owner_vector_count_10e4_10e8
					&& generator_state.relation_scan_consumer_owner_bounds_blocked_count_4a5767 == relation_owner_missing_scan_bounds_count,
				"generator object private state did not run the 0x4a5767 relation scan-consumer pass after the bridge reset")) {
		return 1;
	}
	if (!require(generator_state.relation_high_owner_propagation_49a318_applied,
				"generator object private state did not apply 0x49a318 owner/projection propagation after 0x4a5767")) {
		return 1;
	}
	if (!require(std::all_of(generator_state.generated_cell_buffer.records.begin(), generator_state.generated_cell_buffer.records.end(), [](const aurelion::h3maped_rmg_core::GeneratedCellRecord0x30 &record) {
			return record.word_0x10_known
					&& record.word_0x20_known
					&& record.word_0x24_known
					&& record.word_0x28_known
					&& record.word_0x2c_known;
		}), "generator object private state lost reset/terrain generated-cell word fields before the route/free-cell blocker")) {
		return 1;
	}
	if (!require(generator_state.endpoint_cursor_0xf58_present && generator_state.endpoint_cursor_0xf58_known && generator_state.endpoint_cursor_0xf58 == 0, "generator object private state did not preserve recovered 0x49ecf2 zeroed 0xf58 cursor field")) {
		return 1;
	}
	if (!require(generator_state.reward_guard_projection_generator_0x10b4_known
					&& !generator_state.reward_guard_projection_generator_0x10b4,
				"generator object private state did not preserve recovered 0x49ecf2 zeroed reward/guard projection +0x10b4 byte")) {
		return 1;
	}
	if (!require(generator_state.reward_guard_projection_used_flags_0x1024_known
					&& generator_state.reward_guard_projection_used_flags_0x1024_count == aurelion::h3maped_rmg_core::REWARD_GUARD_PROJECTION_GLOBAL_ENTRY_COUNT_0X4AD947
					&& generator_state.reward_guard_projection_used_flags_0x1024_zero_count == aurelion::h3maped_rmg_core::REWARD_GUARD_PROJECTION_GLOBAL_ENTRY_COUNT_0X4AD947
					&& generator_state.reward_guard_projection_used_flags_0x1024.size() == size_t(aurelion::h3maped_rmg_core::REWARD_GUARD_PROJECTION_GLOBAL_ENTRY_COUNT_0X4AD947)
					&& std::all_of(generator_state.reward_guard_projection_used_flags_0x1024.begin(), generator_state.reward_guard_projection_used_flags_0x1024.end(), [](uint8_t value) { return value == 0U; }),
				"generator object private state did not preserve recovered 0x49ecf2 zeroed 0x90-byte reward/guard projection +0x1024 used-slot array")) {
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
	if (!require(generator_state.descriptor_counter_increment_count_0x4a54a7 > 0
					&& std::any_of(generator_state.descriptor_counter_table_0x1110.begin(), generator_state.descriptor_counter_table_0x1110.end(), [](uint32_t value) { return value > 0U; }),
				"generator object private state did not mutate descriptor counter table during owned source-order object materialization")) {
		return 1;
	}
	GeneratorObjectPrivateState commit_state;
	commit_state.width = 3;
	commit_state.height = 3;
	commit_state.level_count = 1;
	commit_state.generated_cell_buffer = aurelion::h3maped_rmg_core::generated_cell_record_grid_reset_0x49a072(3, 3, 1);
	commit_state.generated_cell_buffer_owned = true;
	commit_state.descriptor_counter_table_0x1110_present = true;
	commit_state.descriptor_counter_table_0x1110_contents_known = true;
	commit_state.descriptor_counter_table_0x1110_known_count = aurelion::h3maped_rmg_core::DESCRIPTOR_COUNTER_TABLE_0X1110_DWORD_COUNT;
	commit_state.descriptor_counter_table_0x1110.assign(size_t(aurelion::h3maped_rmg_core::DESCRIPTOR_COUNTER_TABLE_0X1110_DWORD_COUNT), 0U);
	GeneratorRelationOwnerState4a218c commit_relation_owner;
	commit_relation_owner.runtime_zone_index = 1;
	commit_relation_owner.descriptor_type_counter_table_0x44_known = true;
	commit_relation_owner.descriptor_type_counter_table_0x44_byte_size = aurelion::h3maped_rmg_core::RELATION_OWNER_DESCRIPTOR_TABLE_0X44_BYTE_SIZE;
	commit_relation_owner.descriptor_type_counter_table_0x44_zero_count = aurelion::h3maped_rmg_core::RELATION_OWNER_DESCRIPTOR_TABLE_0X44_DWORD_COUNT;
	commit_relation_owner.descriptor_type_counters_0x44.assign(size_t(aurelion::h3maped_rmg_core::RELATION_OWNER_DESCRIPTOR_TABLE_0X44_DWORD_COUNT), 0U);
	commit_state.relation_owner_vectors_10e4_10e8.push_back(commit_relation_owner);
	for (GeneratedCellRecord0x30 &record : commit_state.generated_cell_buffer.records) {
		record.object_reference_vector_contents_known = true;
		record.object_reference_count = 0;
		record.object_references_0x04_0x08.clear();
		record.word_0x20_known = true;
		record.word_0x20 = 0x00010008U;
		record.word_0x28_known = true;
		record.word_0x28 = 0x12005000U;
	}
	const std::vector<SourceObjectRecord0x4c> commit_type54_records =
			aurelion::h3maped_rmg_core::source_object_records_by_type_subtype_0x49da08(54, 48);
	if (!require(!commit_type54_records.empty(), "0x49da08 type-54 subtype-48 source record missing for 0x4a54a7 source-backed commit")) {
		return 1;
	}
	commit_state.source_object_resolver_state_4af785_known = true;
	const SourceObjectResolverResult4af785 commit_source_resolve =
			aurelion::h3maped_rmg_core::source_object_descriptor_resolver_0x4af785(
					commit_state.source_object_resolver_state_4af785,
					commit_type54_records[0]);
	if (!require(commit_source_resolve.created_new_wrapper
					&& commit_source_resolve.selected_wrapper_index >= 0,
				"0x4af785 did not create a source wrapper before 0x4a54a7 reference-count commit")) {
		return 1;
	}
	const auto commit_result = aurelion::h3maped_rmg_core::object_footprint_commit_4a54a7(
			commit_state,
			0x036260c0U,
			54,
			1,
			1,
			0,
			true,
			0,
			0,
			&commit_type54_records[0],
			true,
			0,
			commit_source_resolve.selected_wrapper_index);
	const GeneratedCellRecord0x30 &commit_target = commit_state.generated_cell_buffer.records[size_t(aurelion::h3maped_rmg_core::cell_index(3, 3, 1, 1, 0))];
	if (!require(commit_result.object_vector_appended
					&& commit_state.object_records_0xec4_ecc.size() == 1
					&& commit_state.object_record_vector_ec4_ecc.contents_known
					&& commit_state.object_record_vector_ec4_ecc.count == 1,
				"0x4a54a7 did not append the object record to generator +0xec4/+0xecc")) {
		return 1;
	}
	if (!require(commit_result.generated_cell_reference_appended
					&& commit_target.object_reference_vector_contents_known
					&& commit_target.object_reference_count == 1
					&& commit_target.object_references_0x04_0x08[0] == 0x036260c0U,
				"0x4a54a7 did not append the object record to the target cell object-reference vector")) {
		return 1;
	}
	if (!require(commit_result.resolver_wrapper_reference_incremented_0x08
					&& commit_result.resolver_wrapper_reference_count_after_0x08 == 1
					&& commit_state.source_object_resolver_state_4af785.wrappers.size() == 1U
					&& commit_state.source_object_resolver_state_4af785.wrappers[0].reference_count_0x08 == 1
					&& commit_state.object_records_0xec4_ecc[0].selected_wrapper_index_0x4af785
							== commit_source_resolve.selected_wrapper_index,
				"0x4a54a7 did not increment recovered resolver wrapper +0x08 or preserve selected wrapper identity")) {
		return 1;
	}
	if (!require(commit_result.descriptor_counter_incremented
					&& commit_state.descriptor_counter_table_0x1110[size_t(54)] == 1U
					&& commit_state.descriptor_counter_increment_count_0x4a54a7 == 1,
				"0x4a54a7 did not increment generator +0x1110[descriptor+0x1c]")) {
		return 1;
	}
	if (!require(commit_result.relation_descriptor_counter_incremented
					&& commit_result.relation_descriptor_counter_owner_runtime_zone_index == 1
					&& commit_result.relation_descriptor_counter_after == 1
					&& commit_state.relation_descriptor_counter_increment_count_0x4a54a7 == 1
					&& commit_state.relation_owner_vectors_10e4_10e8[0].descriptor_type_counter_table_0x44_zero_count == aurelion::h3maped_rmg_core::RELATION_OWNER_DESCRIPTOR_TABLE_0X44_DWORD_COUNT - 1
					&& commit_state.relation_owner_vectors_10e4_10e8[0].descriptor_type_counters_0x44[size_t(54)] == 1U,
				"0x4a54a7 did not increment relation owner +0x44[descriptor+0x1c] from descriptor-offset source cell owner")) {
		return 1;
	}
	if (!require((commit_target.word_0x20 & 0xffffU) == 0U
					&& (commit_target.word_0x28 & aurelion::h3maped_rmg_core::CELL_ACTION_CONTROL_BIT_22) != 0U
					&& (commit_target.word_0x28 & aurelion::h3maped_rmg_core::CELL_OCCUPIED_BLOCKED_BIT_27) != 0U
					&& commit_result.generator_body_stamp_applied_0x49abd6
					&& commit_result.target_cell_word_mutation_count == 1,
				"0x4a54a7 did not route target action/occupied bits through 0x49abd6 before clearing the projection low score word")) {
		return 1;
	}
	if (!require(commit_result.projection_enabled
					&& commit_result.projection_anchor_in_bounds
					&& commit_result.projection_score_depletion_count > 0
					&& commit_state.projection_score_depletion_count_0x4a54a7 == commit_result.projection_score_depletion_count,
				"0x4a54a7 did not run the descriptor +0x29 projection score-depletion wave")) {
		return 1;
	}
	{
		const std::vector<ConnectionFallbackMaterializationRecord4a7605_4a5e03> fallback_records =
				aurelion::h3maped_rmg_core::recovered_supported_land_connection_fallback_records_4a7605_4a5e03();
		if (!require(fallback_records.size() == 2
						&& fallback_records[0].object_record_key == 0x036260c0U
						&& fallback_records[0].source_scope_known
						&& fallback_records[0].source_size_class == "medium"
						&& fallback_records[0].source_water_mode == "land"
						&& fallback_records[0].source_width == 72
						&& fallback_records[0].source_height == 72
						&& fallback_records[0].source_level_count == 1
						&& fallback_records[0].source_seed == 10U
						&& fallback_records[0].source_player_scope_known
						&& fallback_records[0].source_human_count == 1
						&& fallback_records[0].source_player_count == 2
						&& !fallback_records[0].source_setup_object_0x44_known
						&& fallback_records[0].descriptor_pointer == 0x018dca40U
						&& fallback_records[0].descriptor_type_0x1c == 54
						&& fallback_records[0].descriptor_fields_recovered_0x4a7605
						&& fallback_records[0].descriptor_source_key_0x00 == 973
						&& fallback_records[0].descriptor_subtype_0x20 == 48
						&& fallback_records[0].descriptor_class_0x24 == 2
						&& fallback_records[0].descriptor_mask_width_0x34 == 2
						&& fallback_records[0].descriptor_mask_height_0x38 == 2
						&& fallback_records[0].x == 59
						&& fallback_records[0].y == 47
						&& fallback_records[0].level == 0
						&& fallback_records[0].source_cell_prestate_recovered_0x4a7605
						&& fallback_records[0].source_cell_x == 59
						&& fallback_records[0].source_cell_y == 47
						&& fallback_records[0].source_cell_level == 0
						&& fallback_records[0].expected_source_word_0x20_known
						&& fallback_records[0].expected_source_word_0x20 == 0x00010002U
						&& fallback_records[0].expected_source_word_0x24_known
						&& fallback_records[0].expected_source_word_0x24 == 0x00000d07U
						&& fallback_records[0].expected_source_word_0x28_known
						&& fallback_records[0].expected_source_word_0x28 == 0x12005000U
						&& fallback_records[0].expected_owner_byte2 == 1
						&& fallback_records[0].expected_target_word_0x20_known
						&& fallback_records[0].expected_target_word_0x20 == 0x00010002U
						&& fallback_records[0].expected_target_word_0x24_known
						&& fallback_records[0].expected_target_word_0x24 == 0x00000d07U
						&& fallback_records[0].expected_target_word_0x28_known
						&& fallback_records[0].expected_target_word_0x28 == 0x12005000U
						&& fallback_records[1].object_record_key == 0x03626060U
						&& fallback_records[1].source_scope_known
						&& fallback_records[1].source_size_class == "medium"
						&& fallback_records[1].source_water_mode == "land"
						&& fallback_records[1].source_width == 72
						&& fallback_records[1].source_height == 72
						&& fallback_records[1].source_level_count == 1
						&& fallback_records[1].source_seed == 10U
						&& fallback_records[1].source_player_scope_known
						&& fallback_records[1].source_human_count == 1
						&& fallback_records[1].source_player_count == 2
						&& !fallback_records[1].source_setup_object_0x44_known
						&& fallback_records[1].descriptor_pointer == 0x018dc1a4U
						&& fallback_records[1].descriptor_type_0x1c == 54
						&& fallback_records[1].descriptor_fields_recovered_0x4a7605
						&& fallback_records[1].descriptor_source_key_0x00 == 944
						&& fallback_records[1].descriptor_subtype_0x20 == 19
						&& fallback_records[1].descriptor_class_0x24 == 2
						&& fallback_records[1].descriptor_mask_width_0x34 == 2
						&& fallback_records[1].descriptor_mask_height_0x38 == 2
						&& fallback_records[1].x == 39
						&& fallback_records[1].y == 31
						&& fallback_records[1].level == 0
						&& fallback_records[1].source_cell_prestate_recovered_0x4a7605
						&& fallback_records[1].source_cell_x == 39
						&& fallback_records[1].source_cell_y == 31
						&& fallback_records[1].source_cell_level == 0
						&& fallback_records[1].expected_source_word_0x20_known
						&& fallback_records[1].expected_source_word_0x20 == 0x00040002U
						&& fallback_records[1].expected_source_word_0x24_known
						&& fallback_records[1].expected_source_word_0x24 == 0x00000dc3U
						&& fallback_records[1].expected_source_word_0x28_known
						&& fallback_records[1].expected_source_word_0x28 == 0x1a000000U
						&& fallback_records[1].expected_owner_byte2 == 4
						&& fallback_records[1].expected_target_word_0x20_known
						&& fallback_records[1].expected_target_word_0x20 == 0x00040002U
						&& fallback_records[1].expected_target_word_0x24_known
						&& fallback_records[1].expected_target_word_0x24 == 0x00000dc3U
						&& fallback_records[1].expected_target_word_0x28_known
						&& fallback_records[1].expected_target_word_0x28 == 0x1a000000U,
					"0x4a7605 -> 0x4a5e03 recovered fallback records are not the exact seed-controlled source records")) {
			return 1;
		}
		const std::vector<ConnectionFallbackMaterializationRecord4a7605_4a5e03> scoped_medium_records =
				aurelion::h3maped_rmg_core::recovered_supported_land_connection_fallback_records_4a7605_4a5e03_for_scope("medium", "land", 72, 72, 1, 10U, 1, 2, true, 3);
		const std::vector<ConnectionFallbackMaterializationRecord4a7605_4a5e03> scoped_medium_four_player_records =
				aurelion::h3maped_rmg_core::recovered_supported_land_connection_fallback_records_4a7605_4a5e03_for_scope("medium", "land", 72, 72, 1, 10U, 1, 4, true, 3);
		const std::vector<ConnectionFallbackMaterializationRecord4a7605_4a5e03> scoped_small_records =
				aurelion::h3maped_rmg_core::recovered_supported_land_connection_fallback_records_4a7605_4a5e03_for_scope("small", "land", 36, 36, 1, 11U, 1, 2, true, 3);
		if (!require(scoped_medium_records.size() == 2
						&& scoped_medium_four_player_records.empty()
						&& scoped_small_records.empty(),
					"0x4a7605 -> 0x4a5e03 fallback source records were not constrained to the recovered Medium seed-10 1-human/2-player scope")) {
			return 1;
		}
		GeneratorObjectPrivateState fallback_state;
		fallback_state.width = 72;
		fallback_state.height = 72;
		fallback_state.level_count = 1;
		fallback_state.generated_cell_buffer = aurelion::h3maped_rmg_core::generated_cell_record_grid_reset_0x49a072(72, 72, 1);
		fallback_state.generated_cell_buffer_owned = true;
		fallback_state.descriptor_counter_table_0x1110_present = true;
		fallback_state.descriptor_counter_table_0x1110_contents_known = true;
		fallback_state.descriptor_counter_table_0x1110_known_count = aurelion::h3maped_rmg_core::DESCRIPTOR_COUNTER_TABLE_0X1110_DWORD_COUNT;
		fallback_state.descriptor_counter_table_0x1110.assign(size_t(aurelion::h3maped_rmg_core::DESCRIPTOR_COUNTER_TABLE_0X1110_DWORD_COUNT), 0U);
		GeneratorRelationOwnerState4a218c fallback_owner1;
		fallback_owner1.runtime_zone_index = 1;
		fallback_owner1.descriptor_type_counter_table_0x44_known = true;
		fallback_owner1.descriptor_type_counter_table_0x44_byte_size = aurelion::h3maped_rmg_core::RELATION_OWNER_DESCRIPTOR_TABLE_0X44_BYTE_SIZE;
		fallback_owner1.descriptor_type_counter_table_0x44_zero_count = aurelion::h3maped_rmg_core::RELATION_OWNER_DESCRIPTOR_TABLE_0X44_DWORD_COUNT;
		fallback_owner1.descriptor_type_counters_0x44.assign(size_t(aurelion::h3maped_rmg_core::RELATION_OWNER_DESCRIPTOR_TABLE_0X44_DWORD_COUNT), 0U);
		GeneratorRelationOwnerState4a218c fallback_owner4 = fallback_owner1;
		fallback_owner4.runtime_zone_index = 4;
		fallback_owner4.descriptor_type_counter_table_0x44_zero_count = aurelion::h3maped_rmg_core::RELATION_OWNER_DESCRIPTOR_TABLE_0X44_DWORD_COUNT - 1;
		fallback_owner4.descriptor_type_counters_0x44[size_t(54)] = 1U;
		fallback_state.relation_owner_vectors_10e4_10e8.push_back(fallback_owner1);
		fallback_state.relation_owner_vectors_10e4_10e8.push_back(fallback_owner4);
		for (GeneratedCellRecord0x30 &record : fallback_state.generated_cell_buffer.records) {
			record.object_reference_vector_contents_known = true;
			record.object_reference_count = 0;
			record.object_references_0x04_0x08.clear();
			record.word_0x20_known = true;
			record.word_0x20 = 0x00010002U;
			record.word_0x24_known = true;
			record.word_0x24 = 0x00000d07U;
			record.word_0x28_known = true;
			record.word_0x28 = 0x12005000U;
			record.word_0x2c_known = true;
			record.word_0x2c = 0U;
		}
		GeneratedCellRecord0x30 &fallback_first_cell = fallback_state.generated_cell_buffer.records[size_t(aurelion::h3maped_rmg_core::cell_index(72, 72, 59, 47, 0))];
		fallback_first_cell.word_0x20 = 0x00010002U;
		fallback_first_cell.word_0x24 = 0x00000d07U;
		fallback_first_cell.word_0x28 = 0x12005000U;
		GeneratedCellRecord0x30 &fallback_second_cell = fallback_state.generated_cell_buffer.records[size_t(aurelion::h3maped_rmg_core::cell_index(72, 72, 39, 31, 0))];
		fallback_second_cell.word_0x20 = 0x00040002U;
		fallback_second_cell.word_0x24 = 0x00000dc3U;
		fallback_second_cell.word_0x28 = 0x1a000000U;
		const GeneratorObjectPrivateState fallback_precommit_state = fallback_state;
		const ConnectionFallbackMaterializationResult4a7605_4a5e03 fallback_result =
				aurelion::h3maped_rmg_core::connection_fallback_materialization_4a7605_4a5e03(fallback_state, fallback_records);
		if (!require(fallback_result.source_backed
						&& fallback_result.input_record_count == 2
						&& fallback_result.commit_count == 2
						&& fallback_result.blocked_count == 0
						&& fallback_state.connection_fallback_materialization_0x4a7605_0x4a5e03_known
						&& fallback_state.connection_fallback_materialization_record_count == 2
						&& fallback_state.connection_fallback_materialization_commit_count == 2
						&& fallback_state.connection_fallback_materialization_blocked_count == 0,
					"0x4a7605 -> 0x4a5e03 fallback materialization did not commit the two recovered records")) {
			return 1;
		}
		if (!require(fallback_result.records[0].source_cell_prestate_checked_0x4a7605
						&& fallback_result.records[0].source_cell_in_bounds_0x4a7605
						&& fallback_result.records[0].source_cell_word_0x20_matched_0x4a7605
						&& fallback_result.records[0].source_cell_word_0x24_matched_0x4a7605
						&& fallback_result.records[0].source_cell_word_0x28_matched_0x4a7605
						&& fallback_result.records[1].source_cell_prestate_checked_0x4a7605
						&& fallback_result.records[1].source_cell_in_bounds_0x4a7605
						&& fallback_result.records[1].source_cell_word_0x20_matched_0x4a7605
						&& fallback_result.records[1].source_cell_word_0x24_matched_0x4a7605
						&& fallback_result.records[1].source_cell_word_0x28_matched_0x4a7605,
					"0x4a7605 fallback materialization did not validate recovered descriptor-offset source-cell prestate before 0x4a5e03")) {
			return 1;
		}
		if (!require(fallback_result.records[0].source_record_joined_0x49da08
						&& fallback_result.records[0].source_record_row_0x49da08 == 995
						&& fallback_result.records[0].source_record_def_name_0x49da08 == "AVWdemn0.def"
						&& fallback_result.records[1].source_record_joined_0x49da08
						&& fallback_result.records[1].source_record_row_0x49da08 == 966
						&& fallback_result.records[1].source_record_def_name_0x49da08 == "AVWelfx0.def",
					"0x4a7605 fallback materialization did not join recovered descriptor fields to the exact 0x49da08 source records before 0x4a54a7")) {
			return 1;
		}
		const GeneratedCellRecord0x30 &fallback_first_after = fallback_state.generated_cell_buffer.records[size_t(aurelion::h3maped_rmg_core::cell_index(72, 72, 59, 47, 0))];
		const GeneratedCellRecord0x30 &fallback_second_after = fallback_state.generated_cell_buffer.records[size_t(aurelion::h3maped_rmg_core::cell_index(72, 72, 39, 31, 0))];
		if (!require(fallback_state.object_records_0xec4_ecc.size() == 2
						&& fallback_state.object_records_0xec4_ecc[0].connection_fallback_record_0x4a7605_0x4a5e03_known
						&& fallback_state.object_records_0xec4_ecc[0].object_record_key == 0x036260c0U
						&& fallback_state.object_records_0xec4_ecc[0].connection_fallback_arg0_0x4a5e03 == 0x2422U
						&& fallback_state.object_records_0xec4_ecc[0].connection_fallback_descriptor_pointer == 0x018dca40U
						&& fallback_state.object_records_0xec4_ecc[1].connection_fallback_record_0x4a7605_0x4a5e03_known
						&& fallback_state.object_records_0xec4_ecc[1].object_record_key == 0x03626060U
						&& fallback_state.object_records_0xec4_ecc[1].connection_fallback_arg0_0x4a5e03 == 0x2422U
						&& fallback_state.object_records_0xec4_ecc[1].connection_fallback_descriptor_pointer == 0x018dc1a4U,
					"fallback materialization did not preserve recovered object-record pointer/descriptor provenance")) {
			return 1;
		}
		if (!require(fallback_first_after.object_reference_count == 1
						&& fallback_first_after.object_references_0x04_0x08[0] == 0x036260c0U
						&& fallback_second_after.object_reference_count == 1
						&& fallback_second_after.object_references_0x04_0x08[0] == 0x03626060U,
					"fallback materialization did not append recovered object keys to target generated-cell reference vectors")) {
			return 1;
		}
		if (!require((fallback_first_after.word_0x20 & 0xffffU) == 0U
						&& (fallback_first_after.word_0x20 & 0xffff0000U) == 0x00010000U
						&& fallback_first_after.word_0x28 == 0x1a405000U
						&& (fallback_second_after.word_0x20 & 0xffffU) == 0U
						&& (fallback_second_after.word_0x20 & 0xffff0000U) == 0x00040000U
						&& fallback_second_after.word_0x28 == 0x1a400000U,
					"fallback materialization did not reproduce recovered target-cell low-word clear and occupied/action bits")) {
			return 1;
		}
		if (!require(fallback_state.descriptor_counter_table_0x1110[size_t(54)] == 2U
						&& fallback_state.relation_owner_vectors_10e4_10e8[0].descriptor_type_counters_0x44[size_t(54)] == 1U
						&& fallback_state.relation_owner_vectors_10e4_10e8[1].descriptor_type_counters_0x44[size_t(54)] == 2U
						&& fallback_result.records[0].commit_0x4a54a7.relation_descriptor_counter_owner_runtime_zone_index == 1
						&& fallback_result.records[1].commit_0x4a54a7.relation_descriptor_counter_owner_runtime_zone_index == 4
						&& fallback_result.records[0].commit_0x4a54a7.projection_enabled
						&& fallback_result.records[0].commit_0x4a54a7.projection_anchor_in_bounds
						&& fallback_result.records[0].commit_0x4a54a7.target_cell_word_mutation_count == 1
						&& fallback_result.records[1].commit_0x4a54a7.projection_enabled
						&& fallback_result.records[1].commit_0x4a54a7.projection_anchor_in_bounds
						&& fallback_result.records[1].commit_0x4a54a7.target_cell_word_mutation_count == 1,
					"fallback materialization did not route descriptor counters through recovered owner bytes and projection-enabled commits")) {
			return 1;
		}
		GeneratorObjectPrivateState blocked_fallback_state = fallback_precommit_state;
		blocked_fallback_state.object_records_0xec4_ecc.clear();
		GeneratedCellRecord0x30 &blocked_target = blocked_fallback_state.generated_cell_buffer.records[size_t(aurelion::h3maped_rmg_core::cell_index(72, 72, 59, 47, 0))];
		blocked_target.object_reference_vector_contents_known = true;
		blocked_target.object_references_0x04_0x08 = { 0x12345678U };
		blocked_target.object_reference_count = 1;
		const ConnectionFallbackMaterializationResult4a7605_4a5e03 blocked_fallback_result =
				aurelion::h3maped_rmg_core::connection_fallback_materialization_4a7605_4a5e03(blocked_fallback_state, { fallback_records[0] });
		if (!require(blocked_fallback_result.commit_count == 0
						&& blocked_fallback_result.blocked_count == 1
						&& blocked_fallback_result.records[0].blocked_reason == "0x4a5e03_target_object_reference_vector_not_empty"
						&& blocked_fallback_state.object_records_0xec4_ecc.empty(),
					"0x4a5e03 fallback materialization did not fail closed on non-empty target object-reference vector")) {
			return 1;
		}
		GeneratorObjectPrivateState preword_blocked_state = fallback_precommit_state;
		preword_blocked_state.object_records_0xec4_ecc.clear();
		GeneratedCellRecord0x30 &preword_blocked_target =
				preword_blocked_state.generated_cell_buffer.records[size_t(aurelion::h3maped_rmg_core::cell_index(72, 72, 59, 47, 0))];
		preword_blocked_target.object_reference_vector_contents_known = true;
		preword_blocked_target.object_references_0x04_0x08.clear();
		preword_blocked_target.object_reference_count = 0;
		preword_blocked_target.word_0x20_known = true;
		preword_blocked_target.word_0x20 = 0x00010002U;
		preword_blocked_target.word_0x24_known = true;
		preword_blocked_target.word_0x24 = 0x00000d06U;
		preword_blocked_target.word_0x28_known = true;
		preword_blocked_target.word_0x28 = 0x12005000U;
		const ConnectionFallbackMaterializationResult4a7605_4a5e03 preword_blocked_result =
				aurelion::h3maped_rmg_core::connection_fallback_materialization_4a7605_4a5e03(preword_blocked_state, { fallback_records[0] });
		if (!require(preword_blocked_result.commit_count == 0
						&& preword_blocked_result.blocked_count == 1
						&& preword_blocked_result.records[0].blocked_reason == "0x4a7605_source_cell_word_0x24_mismatch_before_0x4a5e03"
						&& preword_blocked_state.object_records_0xec4_ecc.empty(),
					"0x4a7605 fallback materialization did not fail closed on exact source-cell pre-word mismatch")) {
			return 1;
		}
	}
	GeneratorObjectPrivateState offset_commit_state;
	offset_commit_state.width = 5;
	offset_commit_state.height = 5;
	offset_commit_state.level_count = 1;
	offset_commit_state.generated_cell_buffer = aurelion::h3maped_rmg_core::generated_cell_record_grid_reset_0x49a072(5, 5, 1);
	offset_commit_state.generated_cell_buffer_owned = true;
	offset_commit_state.descriptor_counter_table_0x1110_present = true;
	offset_commit_state.descriptor_counter_table_0x1110_contents_known = true;
	offset_commit_state.descriptor_counter_table_0x1110_known_count = aurelion::h3maped_rmg_core::DESCRIPTOR_COUNTER_TABLE_0X1110_DWORD_COUNT;
	offset_commit_state.descriptor_counter_table_0x1110.assign(size_t(aurelion::h3maped_rmg_core::DESCRIPTOR_COUNTER_TABLE_0X1110_DWORD_COUNT), 0U);
	for (GeneratedCellRecord0x30 &record : offset_commit_state.generated_cell_buffer.records) {
		record.object_reference_vector_contents_known = true;
		record.object_reference_count = 0;
		record.object_references_0x04_0x08.clear();
		record.word_0x20_known = true;
		record.word_0x20 = 0x00010014U;
		record.word_0x28_known = true;
		record.word_0x28 = 0x12005000U;
	}
	const std::vector<SourceObjectRecord0x4c> commit_type98_records =
			aurelion::h3maped_rmg_core::source_object_records_by_type_subtype_0x49da08(98, 0);
	if (!require(!commit_type98_records.empty(), "0x49da08 type-98 source record missing for 0x4a54a7 offset source-backed commit")) {
		return 1;
	}
	const auto offset_commit_result = aurelion::h3maped_rmg_core::object_footprint_commit_4a54a7(
			offset_commit_state,
			0x0362fda0U,
			98,
			1,
			2,
			0,
			true,
			-1,
			0,
			&commit_type98_records[0]);
	const GeneratedCellRecord0x30 &offset_target = offset_commit_state.generated_cell_buffer.records[size_t(aurelion::h3maped_rmg_core::cell_index(5, 5, 1, 2, 0))];
	const GeneratedCellRecord0x30 &offset_source = offset_commit_state.generated_cell_buffer.records[size_t(aurelion::h3maped_rmg_core::cell_index(5, 5, 2, 2, 0))];
	if (!require(offset_commit_result.object_vector_appended
					&& offset_commit_result.generated_cell_reference_appended
					&& offset_commit_state.object_records_0xec4_ecc.size() == 1
					&& offset_target.object_reference_count == 1
					&& offset_target.object_references_0x04_0x08[0] == 0x0362fda0U
					&& offset_commit_state.descriptor_counter_table_0x1110[size_t(98)] == 1U,
				"0x4a54a7 nonzero-offset commit did not preserve object-vector/object-reference/counter mutations")) {
		return 1;
	}
	if (!require((offset_source.word_0x20 & 0xffffU) == 0U
					&& (offset_target.word_0x20 & 0xffffU) == 2U
					&& (offset_target.word_0x20 & 0xffff0000U) == 0x00010000U
					&& offset_commit_result.projection_enabled
					&& offset_commit_result.projection_anchor_in_bounds
					&& offset_commit_result.projection_score_depletion_count > 0,
				"0x4a54a7 nonzero-offset projection must clear the descriptor source cell and lower, not zero, the target cell")) {
		return 1;
	}
	if (!require(offset_commit_result.target_cell_word_mutation_count == 2
					&& offset_commit_state.target_cell_word_mutation_count_0x4a54a7 == 2,
				"0x4a54a7 nonzero-offset target mutations did not count target +0x28 plus projection-lowered +0x20")) {
		return 1;
	}
	const std::vector<SourceObjectRecord0x4c> type54_records =
			aurelion::h3maped_rmg_core::source_object_records_by_type_0x49da08(54);
	if (!require(!type54_records.empty(), "0x49da08 type-54 monster source records missing for materialization prep")) {
		return 1;
	}
	SourceObjectDescriptor4903e8 monster_descriptor;
	monster_descriptor.target_context_0x4903e8 = 54;
	monster_descriptor.source_key_0x00 = 0x491eed;
	monster_descriptor.descriptor_type_0x1c = type54_records[0].type_id_0x1c;
	monster_descriptor.subtype_0x20 = type54_records[0].subtype_0x20;
	monster_descriptor.group_0x24 = type54_records[0].group_0x24;
	monster_descriptor.projection_enabled_0x29 = true;
	monster_descriptor.source_cell_x_0x2c = 0;
	monster_descriptor.source_cell_y_0x30 = 0;
	SourceObjectResolverState4af785 materialization_resolver_state;
	const SourceObjectDescriptorJoinResult4903e8 monster_join =
			aurelion::h3maped_rmg_core::source_object_descriptor_join_0x4903e8(materialization_resolver_state, monster_descriptor, type54_records[0]);
	if (!require(monster_join.joined && monster_join.resolver_invoked_0x4af785 && monster_join.copied_source_record_is_identity_authority, "0x4903e8 type-54 join did not wire 0x4af785 before materialization prep")) {
		return 1;
	}
	const ObjectMaterializationPrep4a8db2_4a901a blocked_prep =
			aurelion::h3maped_rmg_core::object_materialization_prep_from_descriptor_join_0x4a8db2_0x4a901a(monster_join, 0U, false, 2, 2, 0);
	if (!require(!blocked_prep.ready_for_object_vector_commit_0x4a54a7
					&& blocked_prep.blocked_reason == "0x4a8d2c_0x4a8db2_0x4a93a2_0x4a901a_object_record_key_caller_unported",
				"materialization prep did not block when recovered weighted materialization did not supply an object-record key")) {
		return 1;
	}
	const ObjectMaterializationPrep4a8db2_4a901a prepared =
			aurelion::h3maped_rmg_core::object_materialization_prep_from_descriptor_join_0x4a8db2_0x4a901a(monster_join, 0x036260c1U, true, 2, 2, 0);
	if (!require(prepared.ready_for_object_vector_commit_0x4a54a7
					&& prepared.copied_source_record_carried
					&& prepared.source_record_copy.def_name == type54_records[0].def_name
					&& prepared.selected_wrapper_index_0x4af785 == monster_join.resolver_0x4af785.selected_wrapper_index,
				"materialization prep did not carry selected copied 0x4c source record and resolver wrapper identity")) {
		return 1;
	}
	GeneratorObjectPrivateState prep_commit_state;
	prep_commit_state.width = 4;
	prep_commit_state.height = 4;
	prep_commit_state.level_count = 1;
	prep_commit_state.generated_cell_buffer = aurelion::h3maped_rmg_core::generated_cell_record_grid_reset_0x49a072(4, 4, 1);
	prep_commit_state.generated_cell_buffer_owned = true;
	prep_commit_state.descriptor_counter_table_0x1110_present = true;
	prep_commit_state.descriptor_counter_table_0x1110_contents_known = true;
	prep_commit_state.descriptor_counter_table_0x1110_known_count = aurelion::h3maped_rmg_core::DESCRIPTOR_COUNTER_TABLE_0X1110_DWORD_COUNT;
	prep_commit_state.descriptor_counter_table_0x1110.assign(size_t(aurelion::h3maped_rmg_core::DESCRIPTOR_COUNTER_TABLE_0X1110_DWORD_COUNT), 0U);
	for (GeneratedCellRecord0x30 &record : prep_commit_state.generated_cell_buffer.records) {
		record.object_reference_vector_contents_known = true;
		record.object_reference_count = 0;
		record.object_references_0x04_0x08.clear();
		record.word_0x20_known = true;
		record.word_0x20 = 0x00010008U;
		record.word_0x28_known = true;
		record.word_0x28 = 0x12005000U;
	}
	const auto prepared_commit_result = aurelion::h3maped_rmg_core::object_footprint_commit_4a54a7(prep_commit_state, prepared);
	const GeneratedCellRecord0x30 &prepared_target = prep_commit_state.generated_cell_buffer.records[size_t(aurelion::h3maped_rmg_core::cell_index(4, 4, 2, 2, 0))];
	if (!require(prepared_commit_result.object_vector_appended && !prep_commit_state.object_records_0xec4_ecc.empty(), "prepared object-vector commit did not append an object record")) {
		return 1;
	}
	const auto &prepared_object_record = prep_commit_state.object_records_0xec4_ecc.back();
	if (!require(prepared_commit_result.object_vector_appended
					&& prepared_object_record.source_descriptor_join_0x4903e8_known
					&& prepared_object_record.copied_source_record_carried
					&& prepared_object_record.source_catalog_index_0x49da08 == monster_join.source_catalog_index_0x49da08
					&& prepared_object_record.source_record_copy.def_name == type54_records[0].def_name,
				"prepared object-vector commit did not preserve 0x4903e8 copied source record identity")) {
		return 1;
	}
	if (!require(prepared_commit_result.generated_cell_reference_appended
					&& prepared_target.object_reference_count == 1
					&& prepared_target.object_references_0x04_0x08[0] == 0x036260c1U
					&& prep_commit_state.descriptor_counter_table_0x1110[size_t(54)] == 1U,
				"prepared object-vector commit did not feed recovered 0x4a54a7 object-reference/counter mutation")) {
		return 1;
	}
	GeneratorObjectPrivateState scanner_state;
	scanner_state.width = 8;
	scanner_state.height = 8;
	scanner_state.level_count = 1;
	scanner_state.generated_cell_buffer = aurelion::h3maped_rmg_core::generated_cell_record_grid_reset_0x49a072(8, 8, 1);
	scanner_state.generated_cell_buffer_owned = true;
	scanner_state.descriptor_counter_table_0x1110_present = true;
	scanner_state.descriptor_counter_table_0x1110_contents_known = true;
	scanner_state.descriptor_counter_table_0x1110_known_count = aurelion::h3maped_rmg_core::DESCRIPTOR_COUNTER_TABLE_0X1110_DWORD_COUNT;
	scanner_state.descriptor_counter_table_0x1110.assign(size_t(aurelion::h3maped_rmg_core::DESCRIPTOR_COUNTER_TABLE_0X1110_DWORD_COUNT), 0U);
	for (GeneratedCellRecord0x30 &record : scanner_state.generated_cell_buffer.records) {
		record.object_reference_vector_contents_known = true;
		record.object_reference_count = 0;
		record.object_references_0x04_0x08.clear();
		record.word_0x20_known = true;
		record.word_0x20 = 0x03030008U;
		record.word_0x24_known = true;
		record.word_0x24 = 0x00000548U;
		record.word_0x28_known = true;
		record.word_0x28 = aurelion::h3maped_rmg_core::CELL_DECOR_READY_BIT_25;
		record.word_0x2c_known = true;
		record.word_0x2c = 0U;
	}
	GeneratorRelationOwnerState4a218c scanner_relation;
	scanner_relation.runtime_zone_index = 3;
	scanner_relation.coordinate_triple_0x10_0x18_known = true;
	scanner_relation.coordinate_x_0x10 = 2;
	scanner_relation.coordinate_y_0x14 = 5;
	scanner_relation.coordinate_level_0x18 = 0;
	scanner_relation.scan_bounds_0x20_0x2c_known = true;
	scanner_relation.scan_bound_low_x_0x20 = 2;
	scanner_relation.scan_bound_low_y_0x24 = 5;
	scanner_relation.scan_bound_high_x_0x28 = 3;
	scanner_relation.scan_bound_high_y_0x2c = 6;
	aurelion::h3maped_rmg_core::H3MapedRng scanner_rng;
	scanner_rng.state = 10U;
	const auto scanner_result =
			aurelion::h3maped_rmg_core::source_bounded_endpoint_candidate_picker_0x4a7312(scanner_state, monster_join, 0x036260c2U, true, scanner_relation, scanner_rng);
	const GeneratedCellRecord0x30 &scanner_target = scanner_state.generated_cell_buffer.records[size_t(aurelion::h3maped_rmg_core::cell_index(8, 8, 2, 5, 0))];
	if (!require(scanner_result.committed_through_vtable_slot_0x04
					&& scanner_result.scan_bounds_non_sentinel
					&& scanner_result.relation_owner_byte2 == 3
					&& scanner_result.scanned_cell_count == 1
					&& scanner_result.accepted_candidate_count == 1
					&& scanner_result.selected_candidate_known
					&& scanner_result.selected_candidate.x == 2
					&& scanner_result.selected_candidate.y == 5
					&& scanner_result.selected_candidate.level == 0,
				"0x4a7312 source-bounded scanner did not select and commit the accepted source-owned candidate")) {
		return 1;
	}
	GeneratorObjectPrivateState byte3_gate_state = scanner_state;
	byte3_gate_state.object_records_0xec4_ecc.clear();
	byte3_gate_state.descriptor_counter_table_0x1110.assign(size_t(aurelion::h3maped_rmg_core::DESCRIPTOR_COUNTER_TABLE_0X1110_DWORD_COUNT), 0U);
	for (GeneratedCellRecord0x30 &record : byte3_gate_state.generated_cell_buffer.records) {
		record.word_0x20 = 0x00030008U;
		record.object_reference_count = 0;
		record.object_references_0x04_0x08.clear();
	}
	aurelion::h3maped_rmg_core::H3MapedRng byte3_gate_rng;
	byte3_gate_rng.state = 10U;
	const auto byte3_gate_result =
			aurelion::h3maped_rmg_core::source_bounded_endpoint_candidate_picker_0x4a7312(byte3_gate_state, monster_join, 0x036260c4U, true, scanner_relation, byte3_gate_rng);
	if (!require(!byte3_gate_result.committed_through_vtable_slot_0x04
					&& byte3_gate_result.owner_byte_reject_count == 1
					&& byte3_gate_result.accepted_candidate_count == 0
					&& byte3_gate_result.blocked_reason == "0x4a7312_candidate_vector_empty_after_source_relation_and_0x49aa93_filters",
				"0x4a7312 endpoint scanner did not reject byte2-only owner matches when byte3 relation/class mismatched")) {
		return 1;
	}
	if (!require(scanner_result.commit_0x4a54a7.object_vector_appended
					&& scanner_result.commit_0x4a54a7.generated_cell_reference_appended
					&& scanner_target.object_reference_count == 1
					&& scanner_target.object_references_0x04_0x08[0] == 0x036260c2U
					&& scanner_state.descriptor_counter_table_0x1110[size_t(54)] == 1U,
				"0x4a7312 selected candidate did not dispatch through the 0x4a54a7 vtable-slot equivalent")) {
		return 1;
	}
	if (!require(!scanner_state.object_records_0xec4_ecc.empty()
					&& scanner_state.object_records_0xec4_ecc.back().source_descriptor_join_0x4903e8_known
					&& scanner_state.object_records_0xec4_ecc.back().copied_source_record_carried
					&& scanner_state.object_records_0xec4_ecc.back().source_record_copy.def_name == type54_records[0].def_name,
				"0x4a7312 committed object record did not preserve copied source descriptor identity")) {
		return 1;
	}
	scanner_relation.scan_bound_low_x_0x20 = aurelion::h3maped_rmg_core::RELATION_OWNER_SCAN_BOUND_LOW_SENTINEL_0X49B452;
	scanner_relation.scan_bound_high_x_0x28 = aurelion::h3maped_rmg_core::RELATION_OWNER_SCAN_BOUND_HIGH_SENTINEL_0X49B452;
	aurelion::h3maped_rmg_core::H3MapedRng blocked_scanner_rng;
	blocked_scanner_rng.state = 10U;
	const auto blocked_scanner_result =
			aurelion::h3maped_rmg_core::source_bounded_endpoint_candidate_picker_0x4a7312(scanner_state, monster_join, 0x036260c3U, true, scanner_relation, blocked_scanner_rng);
	if (!require(!blocked_scanner_result.committed_through_vtable_slot_0x04
					&& blocked_scanner_result.blocked_reason == "0x4a7312_source_relation_scan_bounds_missing_or_constructor_sentinel",
				"0x4a7312 scanner did not fail closed on unrecovered constructor-sentinel scan bounds")) {
		return 1;
	}
	GeneratorObjectPrivateState reward_guard_state;
	reward_guard_state.width = 6;
	reward_guard_state.height = 6;
	reward_guard_state.level_count = 1;
	reward_guard_state.generated_cell_buffer = aurelion::h3maped_rmg_core::generated_cell_record_grid_reset_0x49a072(6, 6, 1);
	reward_guard_state.generated_cell_buffer_owned = true;
	reward_guard_state.descriptor_counter_table_0x1110_present = true;
	reward_guard_state.descriptor_counter_table_0x1110_contents_known = true;
	reward_guard_state.descriptor_counter_table_0x1110_known_count = aurelion::h3maped_rmg_core::DESCRIPTOR_COUNTER_TABLE_0X1110_DWORD_COUNT;
	reward_guard_state.descriptor_counter_table_0x1110.assign(size_t(aurelion::h3maped_rmg_core::DESCRIPTOR_COUNTER_TABLE_0X1110_DWORD_COUNT), 0U);
	for (GeneratedCellRecord0x30 &record : reward_guard_state.generated_cell_buffer.records) {
		record.object_reference_vector_contents_known = true;
		record.object_reference_count = 0;
		record.object_references_0x04_0x08.clear();
		record.word_0x20_known = true;
		record.word_0x20 = 0x00040004U;
		record.word_0x24_known = true;
		record.word_0x24 = 0U;
		record.word_0x28_known = true;
		record.word_0x28 = aurelion::h3maped_rmg_core::GENERATED_CELL_INITIAL_WORD_0X28_VALUE;
		aurelion::h3maped_rmg_core::generated_cell_49a932(record, true);
		record.word_0x2c_known = true;
		record.word_0x2c = 0U;
	}
	GeneratedCellRecord0x30 &reward_guard_target =
			reward_guard_state.generated_cell_buffer.records[size_t(aurelion::h3maped_rmg_core::cell_index(6, 6, 2, 2, 0))];
	reward_guard_target.word_0x20 = 0x0004000aU;
	aurelion::h3maped_rmg_core::generated_cell_49a932(reward_guard_target, true);
	const bool reward_guard_target_bit27_set_before_scan =
			(reward_guard_target.word_0x28 & aurelion::h3maped_rmg_core::CELL_OCCUPIED_BLOCKED_BIT_27) != 0U;
	GeneratedCellRecord0x30 &reward_guard_contour_cell =
			reward_guard_state.generated_cell_buffer.records[size_t(aurelion::h3maped_rmg_core::cell_index(6, 6, 3, 2, 0))];
	aurelion::h3maped_rmg_core::generated_cell_49a932(reward_guard_contour_cell, true);
	RewardGuardWrapperState4aa3e9 reward_guard_wrapper;
	reward_guard_wrapper.wrapper_bounds_0x18_0x24_known = true;
	reward_guard_wrapper.bound_left_0x18 = 0;
	reward_guard_wrapper.bound_top_0x1c = 0;
	reward_guard_wrapper.bound_right_0x20 = 0;
	reward_guard_wrapper.bound_bottom_0x24 = 0;
	reward_guard_wrapper.selected_member_vector_0x2c_0x30_known = true;
	RewardGuardWrapperMember4aa3e9 reward_guard_member;
	reward_guard_member.object_record_key = 0x0364def0U;
	reward_guard_member.object_record_key_known = true;
	reward_guard_member.object_record_vtable_0x00 = aurelion::h3maped_rmg_core::OBJECT_RECORD_VTABLE_0X540A74;
	reward_guard_member.descriptor_type_0x1c = 45;
	reward_guard_member.descriptor_offset_x_0x2c = 1;
	reward_guard_member.descriptor_offset_y_0x30 = 1;
	reward_guard_member.source_record_copy_known_0x04 = true;
	reward_guard_member.source_record_copy.type_id_0x1c = 45;
	reward_guard_member.source_record_copy.descriptor_width_0x34 = 1;
	reward_guard_member.source_record_copy.descriptor_height_0x38 = 1;
	reward_guard_member.source_record_copy.descriptor_mask_fields_0x34_0x48_known = true;
	reward_guard_member.source_record_copy.descriptor_mask_a_0x3c_0x40 = uint64_t(1) << 47U;
	reward_guard_member.source_record_copy.descriptor_mask_b_0x44_0x48 = uint64_t(1) << 47U;
	reward_guard_wrapper.selected_members_0x2c_0x30.push_back(reward_guard_member);
	reward_guard_wrapper.generated_cell_grid_0x08_0x10_known = true;
	reward_guard_wrapper.generated_cell_grid_0x08_0x10 = aurelion::h3maped_rmg_core::generated_cell_record_grid_reset_0x49a072(3, 3, 1);
	for (GeneratedCellRecord0x30 &wrapper_cell : reward_guard_wrapper.generated_cell_grid_0x08_0x10.records) {
		wrapper_cell.word_0x20_known = true;
		wrapper_cell.word_0x20 = 0x0004000aU;
		wrapper_cell.word_0x24_known = true;
		wrapper_cell.word_0x24 = 0U;
		wrapper_cell.word_0x28_known = true;
		wrapper_cell.word_0x28 = aurelion::h3maped_rmg_core::GENERATED_CELL_INITIAL_WORD_0X28_VALUE;
		aurelion::h3maped_rmg_core::generated_cell_49a932(wrapper_cell, false);
		wrapper_cell.word_0x2c_known = true;
		wrapper_cell.word_0x2c = 0U;
	}
	GeneratedCellRecord0x30 &reward_guard_wrapper_direction_cell =
			reward_guard_wrapper.generated_cell_grid_0x08_0x10.records[0];
	aurelion::h3maped_rmg_core::generated_cell_49aa63(reward_guard_wrapper_direction_cell, true);
	aurelion::h3maped_rmg_core::generated_cell_49a932(reward_guard_wrapper_direction_cell, true);
	reward_guard_wrapper_direction_cell.word_0x28 |= aurelion::h3maped_rmg_core::CELL_REWARD_GUARD_DIRECTION_BIT_23
			| aurelion::h3maped_rmg_core::CELL_DECOR_CANDIDATE_BIT_26;
	reward_guard_wrapper.candidate_coordinate_vector_0x3c_0x40_known = true;
	reward_guard_wrapper.candidate_coordinates_0x3c_0x40.push_back({ 1, 0, 0 });
	GeneratorRelationOwnerState4a218c reward_guard_relation;
	reward_guard_relation.runtime_zone_index = 2;
	reward_guard_relation.source_zone_id = 5;
	reward_guard_relation.source_pointer_0x00_known = true;
	reward_guard_relation.source_pointer_source_index_0x00 = 4;
	reward_guard_relation.relation_owner_byte2_0x4aa9b7_known = true;
	reward_guard_relation.relation_owner_byte2_0x4aa9b7 = 4;
	reward_guard_relation.terrain_policy_0x0c_known = true;
	reward_guard_relation.terrain_policy_0x0c = 0;
	reward_guard_relation.coordinate_triple_0x10_0x18_known = true;
	reward_guard_relation.coordinate_x_0x10 = 2;
	reward_guard_relation.coordinate_y_0x14 = 2;
	reward_guard_relation.coordinate_level_0x18 = 0;
	reward_guard_relation.scan_bounds_0x20_0x2c_known = true;
	reward_guard_relation.scan_bound_low_x_0x20 = 2;
	reward_guard_relation.scan_bound_low_y_0x24 = 2;
	reward_guard_relation.scan_bound_high_x_0x28 = 2;
	reward_guard_relation.scan_bound_high_y_0x2c = 2;
	const GeneratorObjectPrivateState reward_guard_base_state = reward_guard_state;
	const RewardGuardWrapperState4aa3e9 reward_guard_base_wrapper = reward_guard_wrapper;
	{
		GeneratorObjectPrivateState projection_slot_state = reward_guard_state;
		RewardGuardWrapperState4aa3e9 projection_slot_wrapper = reward_guard_wrapper;
		RewardGuardWrapperMember4aa3e9 &projection_slot_member =
				projection_slot_wrapper.selected_members_0x2c_0x30[0];
		projection_slot_member.object_record_vtable_0x00 = aurelion::h3maped_rmg_core::PROJECTION_OBJECT_VTABLE_0X540B14;
		projection_slot_member.projection_object_0x540b14_known = true;
		projection_slot_member.projection_object_0x540b14.live_input_known = true;
		projection_slot_member.projection_object_0x540b14.vtable_0x00_known = true;
		projection_slot_member.projection_object_0x540b14.vtable_0x00 = aurelion::h3maped_rmg_core::PROJECTION_OBJECT_VTABLE_0X540B14;
		projection_slot_member.projection_object_0x540b14.generator_context_plus_0x1c_known = true;
		projection_slot_member.projection_object_0x540b14.owned_object_record_pointer_plus_0x20_known = true;
		projection_slot_member.projection_object_0x540b14.owned_object_record_key_known = true;
		projection_slot_member.projection_object_0x540b14.owned_object_record_key = projection_slot_member.object_record_key;
		projection_slot_member.projection_object_0x540b14.owned_object_record_value_0x1c_known = projection_slot_member.object_record_sequence_known_0x1c;
		projection_slot_member.projection_object_0x540b14.owned_object_record_value_0x1c = projection_slot_member.object_record_sequence_0x1c;
		projection_slot_member.projection_object_0x540b14.owned_object_record_value_0x20_known = projection_slot_member.object_record_selected_index_known_0x20;
		projection_slot_member.projection_object_0x540b14.owned_object_record_value_0x20 = projection_slot_member.object_record_selected_index_0x20;
		projection_slot_member.projection_object_0x540b14.selected_source_subtype_0x20_known = projection_slot_member.source_record_copy_known_0x04;
		projection_slot_member.projection_object_0x540b14.selected_source_subtype_0x20 =
				projection_slot_member.source_record_copy_known_0x04 ? projection_slot_member.source_record_copy.subtype_0x20 : -1;
		H3MapedRng projection_slot_rng;
		projection_slot_rng.state = 58U;
		const RewardGuardCoordinateScanResult4aa9b7 projection_slot_result =
				aurelion::h3maped_rmg_core::reward_guard_coordinate_scan_and_commit_0x4aa9b7(
						projection_slot_state,
						projection_slot_wrapper,
						reward_guard_relation,
						7,
						true,
						projection_slot_rng);
		if (!require(projection_slot_result.applied
						&& !projection_slot_result.committed
						&& projection_slot_result.commit_0x4aa3e9.selected_member_slot8_projection_0x540b14_count == 1
						&& projection_slot_result.commit_0x4aa3e9.selected_member_slot8_projection_blocked_reason == "0x4ad947_projection_global_table_0x57c7cc_plus_0x0c_live_input_pending_before_selected_global_entry"
						&& projection_slot_result.blocked_reason.empty(),
					"0x4aa3e9 projection slot should route through 0x49c0a6/0x4ad947 and fail closed without the recovered 0x57c7cc+0x0c table")) {
			return 1;
		}

		GeneratorObjectPrivateState projection_global_state = reward_guard_state;
		RewardGuardWrapperState4aa3e9 projection_global_wrapper = reward_guard_wrapper;
		RewardGuardWrapperMember4aa3e9 &projection_global_member =
				projection_global_wrapper.selected_members_0x2c_0x30[0];
		projection_global_member.object_record_vtable_0x00 = aurelion::h3maped_rmg_core::PROJECTION_OBJECT_VTABLE_0X540B14;
		projection_global_member.projection_object_0x540b14_known = true;
		projection_global_member.projection_object_0x540b14.live_input_known = true;
		projection_global_member.projection_object_0x540b14.vtable_0x00_known = true;
		projection_global_member.projection_object_0x540b14.vtable_0x00 = aurelion::h3maped_rmg_core::PROJECTION_OBJECT_VTABLE_0X540B14;
		projection_global_member.projection_object_0x540b14.generator_context_plus_0x1c_known = true;
		projection_global_member.projection_object_0x540b14.owned_object_record_pointer_plus_0x20_known = true;
		projection_global_member.projection_object_0x540b14.owned_object_record_key_known = true;
		projection_global_member.projection_object_0x540b14.owned_object_record_key = projection_global_member.object_record_key;
		projection_global_member.projection_object_0x540b14.owned_object_record_value_0x1c_known = projection_global_member.object_record_sequence_known_0x1c;
		projection_global_member.projection_object_0x540b14.owned_object_record_value_0x1c = projection_global_member.object_record_sequence_0x1c;
		projection_global_member.selected_wrapper_index_0x4af785 = 1;
		projection_global_member.projection_object_0x540b14.base_wrapper_pointer_plus_0x04_known = true;
		projection_global_member.projection_object_0x540b14.base_wrapper_index_plus_0x04 = 1;
		projection_global_member.projection_object_0x540b14.selected_wrapper_index_0x4af785_known = true;
		projection_global_member.projection_object_0x540b14.selected_wrapper_index_0x4af785 = 1;
		projection_global_state.source_object_resolver_state_4af785_known = true;
		projection_global_state.source_object_resolver_state_4af785.wrappers.clear();
		projection_global_state.source_object_resolver_state_4af785.wrapper_bucket_indices_0xe8 = {};
		projection_global_state.source_object_resolver_state_4af785.next_wrapper_index = 4;
		SourceObjectResolvedWrapper4af785 previous_projection_wrapper;
		previous_projection_wrapper.wrapper_index = 1;
		previous_projection_wrapper.source_catalog_index = 101;
		previous_projection_wrapper.source_record_copy.type_id_0x1c = 45;
		previous_projection_wrapper.source_record_copy.subtype_0x20 = 45;
		previous_projection_wrapper.reference_count_0x08_known = true;
		previous_projection_wrapper.reference_count_0x08 = 1;
		SourceObjectResolvedWrapper4af785 selected_projection_wrapper;
		selected_projection_wrapper.wrapper_index = 3;
		selected_projection_wrapper.source_catalog_index = 103;
		selected_projection_wrapper.source_record_copy.type_id_0x1c = 45;
		selected_projection_wrapper.source_record_copy.subtype_0x20 = 9;
		selected_projection_wrapper.reference_count_0x08_known = true;
		selected_projection_wrapper.reference_count_0x08 = 0;
		projection_global_state.source_object_resolver_state_4af785.wrappers.push_back(previous_projection_wrapper);
		projection_global_state.source_object_resolver_state_4af785.wrappers.push_back(selected_projection_wrapper);
		projection_global_state.reward_guard_projection_global_table_0x57c7cc_plus_0x0c_known = true;
		projection_global_state.reward_guard_projection_global_table_0x57c7cc_plus_0x0c.assign(
				size_t(aurelion::h3maped_rmg_core::REWARD_GUARD_PROJECTION_GLOBAL_ENTRY_COUNT_0X4AD947),
				aurelion::h3maped_rmg_core::RewardGuardProjectionGlobalEntry4ad947 {});
		for (int32_t index = 0; index < aurelion::h3maped_rmg_core::REWARD_GUARD_PROJECTION_GLOBAL_ENTRY_COUNT_0X4AD947; ++index) {
			auto &entry = projection_global_state.reward_guard_projection_global_table_0x57c7cc_plus_0x0c[size_t(index)];
			entry.entry_index = index;
			entry.flag_byte_0x00_known = true;
			entry.flag_byte_0x00 = 0U;
			entry.disabled_byte_0x10_known = true;
			entry.disabled_byte_0x10 = 0U;
		}
		projection_global_state.reward_guard_projection_global_table_0x57c7cc_plus_0x0c[size_t(9)].flag_byte_0x00 = 0x2U;
		projection_global_state.reward_guard_projection_used_flags_0x1024_known = true;
		projection_global_state.reward_guard_projection_used_flags_0x1024.assign(
				size_t(aurelion::h3maped_rmg_core::REWARD_GUARD_PROJECTION_GLOBAL_ENTRY_COUNT_0X4AD947),
				uint8_t(0));
		GeneratorRelationOwnerState4a218c projection_source_owner;
		projection_source_owner.owner_vector_index = 4;
		projection_source_owner.runtime_zone_index = 4;
		projection_source_owner.source_zone_id = 5;
		projection_source_owner.source_pointer_0x00_known = true;
		projection_source_owner.source_pointer_source_index_0x00 = 4;
		projection_source_owner.relation_owner_byte2_0x4aa9b7_known = true;
		projection_source_owner.relation_owner_byte2_0x4aa9b7 = 4;
		projection_source_owner.terrain_policy_0x0c_known = true;
		projection_source_owner.terrain_policy_0x0c = 0;
		projection_source_owner.adjacency_vector_0xc4_contents_known = true;
		GeneratorRelationOwnerAdjacencyRecord4a3710 projection_edge;
		projection_edge.source_owner_vector_index = 4;
		projection_edge.source_runtime_zone_index = 4;
		projection_edge.source_zone_id = 5;
		projection_edge.target_owner_vector_index = 5;
		projection_edge.target_runtime_zone_index = 5;
		projection_edge.target_source_zone_id = 6;
		projection_source_owner.adjacency_records_0xc4.push_back(projection_edge);
		GeneratorRelationOwnerState4a218c projection_target_owner;
		projection_target_owner.owner_vector_index = 5;
		projection_target_owner.runtime_zone_index = 5;
		projection_target_owner.source_zone_id = 6;
		projection_target_owner.source_pointer_0x00_known = true;
		projection_target_owner.source_pointer_source_index_0x00 = 5;
		projection_target_owner.relation_owner_byte2_0x4aa9b7_known = true;
		projection_target_owner.relation_owner_byte2_0x4aa9b7 = 5;
		projection_target_owner.source_pointer_type_0x04_known = true;
		projection_target_owner.source_pointer_type_0x04 = 0;
		projection_target_owner.terrain_policy_0x0c_known = true;
		projection_target_owner.terrain_policy_0x0c = 0;
		projection_target_owner.coordinate_triple_0x10_0x18_known = true;
		projection_target_owner.coordinate_x_0x10 = 2;
		projection_target_owner.coordinate_y_0x14 = 3;
		projection_target_owner.coordinate_level_0x18 = 0;
		projection_target_owner.scan_bounds_0x20_0x2c_known = true;
		projection_target_owner.scan_bound_low_x_0x20 = 2;
		projection_target_owner.scan_bound_low_y_0x24 = 3;
		projection_target_owner.scan_bound_high_x_0x28 = 2;
		projection_target_owner.scan_bound_high_y_0x2c = 3;
		projection_global_state.relation_owner_vectors_10e4_10e8 = { projection_source_owner, projection_target_owner };
		projection_global_state.relation_owner_vector_count_10e4_10e8 = 2;
		projection_global_state.relation_vector_10e4_10e8.present = true;
		projection_global_state.relation_vector_10e4_10e8.contents_known = true;
		projection_global_state.relation_vector_10e4_10e8.count_known = true;
		projection_global_state.relation_vector_10e4_10e8.count = 2;
		GeneratedCellRecord0x30 &projection_target =
				projection_global_state.generated_cell_buffer.records[size_t(aurelion::h3maped_rmg_core::cell_index(6, 6, 2, 3, 0))];
		projection_target.word_0x20 = 0x0005000aU;
		aurelion::h3maped_rmg_core::generated_cell_49a932(projection_target, true);
		H3MapedRng projection_global_rng;
		projection_global_rng.state = 58U;
		const RewardGuardCoordinateScanResult4aa9b7 projection_global_result =
				aurelion::h3maped_rmg_core::reward_guard_coordinate_scan_and_commit_0x4aa9b7(
						projection_global_state,
						projection_global_wrapper,
						reward_guard_relation,
						7,
						true,
						projection_global_rng);
		const RewardGuardProjectionChainResult49c0a6 &projection_global_chain =
				projection_global_state.reward_guard_projection_chain_0x49c0a6_0x4ad947_0x4ad7f7;
		if (!require(projection_global_result.applied
						&& projection_global_result.commit_0x4aa3e9.selected_member_slot8_projection_0x540b14_count == 1
						&& projection_global_result.commit_0x4aa3e9.selected_member_slot8_projection_blocked_reason != "0x4ad947_generator_wrapper_vector_0x88_0x8c_relation_handoff_pending_after_selected_global_entry"
						&& projection_global_result.commit_0x4aa3e9.selected_member_slot8_projection_ordered_scan_count_0x4ad7f7 == 1
						&& projection_global_chain.projection_record_selected_global_index_0x1c_written
						&& projection_global_chain.projection_record_selected_global_index_0x1c == 9
						&& projection_global_chain.generator_wrapper_vector_join_invoked_0x4ad947
						&& projection_global_chain.generator_wrapper_vector_match_found_0x4ad947
						&& projection_global_chain.selected_wrapper_index_0x4ad947 == 3
						&& projection_global_chain.previous_wrapper_index_0x4ad947 == 1
						&& projection_global_chain.wrapper_reference_switch_applied_0x4ad947
						&& projection_global_chain.projection_coordinate_plus_0x08_0x10_known
						&& projection_global_chain.projection_x_plus_0x08 == 2
						&& projection_global_chain.projection_y_plus_0x0c == 2
						&& projection_global_chain.projection_level_plus_0x10 == 0
						&& projection_global_chain.projection_relation_owner_index_known_0x4ad947
						&& projection_global_chain.projection_relation_owner_index_0x4ad947 == 4
						&& projection_global_chain.relation_priority_invoked_0x4ad7f7
						&& projection_global_chain.relation_priority_0x4ad7f7.ordered_vector_ready_for_0x4aa9b7
						&& !projection_global_chain.relation_priority_0x4ad7f7.ordered_owner_vector_indexes_0x4ccecb.empty()
						&& projection_global_chain.relation_priority_0x4ad7f7.ordered_owner_vector_indexes_0x4ccecb[0] == 5
						&& projection_global_state.source_object_resolver_state_4af785.wrappers[0].reference_count_0x08 == 0
						&& projection_global_state.source_object_resolver_state_4af785.wrappers[1].reference_count_0x08 == 1
						&& projection_global_wrapper.selected_members_0x2c_0x30[0].object_record_sequence_known_0x1c
						&& projection_global_wrapper.selected_members_0x2c_0x30[0].object_record_sequence_0x1c == 9
						&& projection_global_wrapper.selected_members_0x2c_0x30[0].selected_wrapper_index_0x4af785 == 3,
					"0x4aa3e9 projection slot did not complete recovered 0x4ad947 wrapper-vector relation handoff into 0x4ad7f7")) {
			return 1;
		}
	}
	H3MapedRng reward_guard_rng;
	reward_guard_rng.state = 58U;
	const RewardGuardCoordinateScanResult4aa9b7 reward_guard_result =
			aurelion::h3maped_rmg_core::reward_guard_coordinate_scan_and_commit_0x4aa9b7(
					reward_guard_state,
					reward_guard_wrapper,
					reward_guard_relation,
					7,
					true,
					reward_guard_rng);
	const GeneratedCellRecord0x30 &reward_guard_target_after =
			reward_guard_state.generated_cell_buffer.records[size_t(aurelion::h3maped_rmg_core::cell_index(6, 6, 2, 2, 0))];
	const GeneratedCellRecord0x30 &reward_guard_wrapper_cell_after = reward_guard_wrapper.generated_cell_grid_0x08_0x10.records[0];
	if (!require(reward_guard_result.applied
					&& reward_guard_result.committed
					&& reward_guard_target_bit27_set_before_scan
					&& reward_guard_result.relation_owner_byte2 == 4
					&& reward_guard_result.scanned_cell_count == 1
					&& reward_guard_result.accepted_candidate_count == 1
					&& reward_guard_result.feasibility_results_0x4aa603.size() == 1
					&& reward_guard_result.feasibility_results_0x4aa603[0].accepted
					&& reward_guard_result.feasibility_results_0x4aa603[0].footprint_body_cell_scan_count_0x49a6f9 == 1
					&& reward_guard_result.feasibility_results_0x4aa603[0].direction_accept_count == 1
					&& reward_guard_result.feasibility_results_0x4aa603[0].contour_scan_count_0x49a09c == 2
					&& reward_guard_result.local_vector_clear_count_0x4ae52a == 1
					&& reward_guard_result.local_vector_append_count_0x4ae1fd == 1
					&& reward_guard_result.selected_candidate_known
					&& reward_guard_result.selected_candidate.x == 2
					&& reward_guard_result.selected_candidate.y == 2
					&& reward_guard_result.selected_candidate.level == 0
					&& reward_guard_result.threshold_after_scan == 10,
				"0x4aa9b7 did not scan, run recovered 0x4aa603 bit27-set destination gate, append, and select the reward/guard coordinate")) {
		return 1;
	}
	if (!require(reward_guard_wrapper.selected_coordinate_0x54_0x5c_known
					&& reward_guard_wrapper.selected_x_0x54 == 2
					&& reward_guard_wrapper.selected_y_0x58 == 2
					&& reward_guard_wrapper.selected_level_0x5c == 0
					&& reward_guard_result.commit_0x4aa3e9.selected_coordinate_stored_0x54_0x5c
					&& reward_guard_result.commit_0x4aa3e9.selected_member_commit_count_0x4a54a7 == 1,
				"0x4aa3e9 did not store selected coordinate and dispatch selected wrapper member through 0x4a54a7")) {
		return 1;
	}
	if (!require(reward_guard_state.object_records_0xec4_ecc.size() == 1
					&& reward_guard_state.object_records_0xec4_ecc[0].object_record_key == 0x0364def0U
					&& reward_guard_state.object_records_0xec4_ecc[0].object_record_vtable_0x00 == aurelion::h3maped_rmg_core::OBJECT_RECORD_VTABLE_0X540A74
					&& reward_guard_target_after.object_reference_count == 1
					&& reward_guard_target_after.object_references_0x04_0x08[0] == 0x0364def0U
					&& reward_guard_state.descriptor_counter_table_0x1110[size_t(45)] == 1U,
				"0x4aa3e9 wrapper member commit did not append recovered object key/reference/counter state")) {
		return 1;
	}
	{
		GeneratorObjectPrivateState split_owner_state = reward_guard_base_state;
		RewardGuardWrapperState4aa3e9 split_owner_wrapper = reward_guard_base_wrapper;
		GeneratorRelationOwnerState4a218c split_owner_relation = reward_guard_relation;
		split_owner_relation.source_pointer_source_index_0x00 = 9;
		H3MapedRng split_owner_rng;
		split_owner_rng.state = 58U;
		const RewardGuardCoordinateScanResult4aa9b7 split_owner_result =
				aurelion::h3maped_rmg_core::reward_guard_coordinate_scan_and_commit_0x4aa9b7(
						split_owner_state,
						split_owner_wrapper,
						split_owner_relation,
						7,
						true,
						split_owner_rng);
		if (!require(split_owner_result.applied
						&& split_owner_result.committed
						&& split_owner_result.relation_owner_byte2 == 4
						&& split_owner_result.owner_byte_reject_count == 0
						&& split_owner_result.accepted_candidate_count == 1,
					"0x4aa9b7/0x4aa603 owner gate used source-pointer index instead of recovered relation-leading owner byte")) {
			return 1;
		}
	}
	{
		GeneratorObjectPrivateState reduced_direction_state = reward_guard_base_state;
		RewardGuardWrapperState4aa3e9 reduced_direction_wrapper = reward_guard_base_wrapper;
		reduced_direction_wrapper.selected_members_0x2c_0x30[0].descriptor_offset_y_0x30 = 0;
		GeneratedCellRecord0x30 &reduced_direction_cell =
				reduced_direction_wrapper.generated_cell_grid_0x08_0x10.records[size_t(
						aurelion::h3maped_rmg_core::cell_index(3, 3, 0, 1, 0))];
		aurelion::h3maped_rmg_core::generated_cell_49aa63(reduced_direction_cell, true);
		aurelion::h3maped_rmg_core::generated_cell_49a932(reduced_direction_cell, true);
		reduced_direction_cell.word_0x28 |= aurelion::h3maped_rmg_core::CELL_REWARD_GUARD_DIRECTION_BIT_23
				| aurelion::h3maped_rmg_core::CELL_DECOR_CANDIDATE_BIT_26;
		H3MapedRng reduced_direction_rng;
		reduced_direction_rng.state = 58U;
		const RewardGuardCoordinateScanResult4aa9b7 reduced_direction_result =
				aurelion::h3maped_rmg_core::reward_guard_coordinate_scan_and_commit_0x4aa9b7(
						reduced_direction_state,
						reduced_direction_wrapper,
						reward_guard_relation,
						7,
						true,
						reduced_direction_rng);
		if (!require(reduced_direction_result.applied
						&& reduced_direction_result.committed
						&& !aurelion::h3maped_rmg_core::object_metadata_flag_0x598300(45, 1)
						&& reduced_direction_result.feasibility_results_0x4aa603.size() == 1
						&& reduced_direction_result.feasibility_results_0x4aa603[0].accepted
						&& reduced_direction_result.feasibility_results_0x4aa603[0].direction_scan_count == 1
						&& reduced_direction_result.feasibility_results_0x4aa603[0].direction_accept_count == 1,
					"0x4aa603 did not use the recovered metadata +1 reduced direction range starting at direction 1")) {
			return 1;
		}
	}
	const bool reward_guard_mirror_ok =
			(reward_guard_target_after.word_0x28 & aurelion::h3maped_rmg_core::CELL_ACTION_CONTROL_BIT_22) != 0U
			&& (reward_guard_target_after.word_0x28 & aurelion::h3maped_rmg_core::CELL_OCCUPIED_BLOCKED_BIT_27) != 0U
			&& (reward_guard_wrapper_cell_after.word_0x28 & aurelion::h3maped_rmg_core::CELL_DECOR_CANDIDATE_BIT_26) == 0U
			&& (reward_guard_wrapper_cell_after.word_0x28 & aurelion::h3maped_rmg_core::CELL_OCCUPIED_BLOCKED_BIT_27) != 0U
			&& reward_guard_result.commit_0x4aa3e9.destination_bit26_mirror_count == 1
			&& reward_guard_result.commit_0x4aa3e9.destination_bit27_mirror_count >= 1;
	if (!require(reward_guard_mirror_ok,
				"0x4aa3e9 did not mirror captured source bit26/bit27 into the wrapper generated-cell grid after member commit")) {
		return 1;
	}
		{
			GeneratorObjectPrivateState overlap_bit26_state = reward_guard_base_state;
			RewardGuardWrapperState4aa3e9 overlap_bit26_wrapper = reward_guard_base_wrapper;
			GeneratorRelationOwnerState4a218c overlap_bit26_relation = reward_guard_relation;
			overlap_bit26_wrapper.bound_left_0x18 = 2;
			overlap_bit26_wrapper.bound_top_0x1c = 0;
			overlap_bit26_wrapper.bound_right_0x20 = 3;
			overlap_bit26_wrapper.bound_bottom_0x24 = 1;
			overlap_bit26_relation.scan_bound_low_x_0x20 = 4;
			overlap_bit26_relation.scan_bound_low_y_0x24 = 2;
			overlap_bit26_relation.scan_bound_high_x_0x28 = 5;
			overlap_bit26_relation.scan_bound_high_y_0x2c = 3;
			GeneratedCellRecord0x30 &overlap_bit26_destination =
					overlap_bit26_state.generated_cell_buffer.records[size_t(aurelion::h3maped_rmg_core::cell_index(6, 6, 4, 2, 0))];
			overlap_bit26_destination.word_0x20 = 0x0004000aU;
			aurelion::h3maped_rmg_core::generated_cell_49aa63(overlap_bit26_destination, true);
			H3MapedRng overlap_bit26_rng;
			overlap_bit26_rng.state = 58U;
			const RewardGuardCoordinateScanResult4aa9b7 overlap_bit26_result =
					aurelion::h3maped_rmg_core::reward_guard_coordinate_scan_and_commit_0x4aa9b7(
							overlap_bit26_state,
							overlap_bit26_wrapper,
							overlap_bit26_relation,
							7,
							true,
							overlap_bit26_rng);
			if (!require(overlap_bit26_result.applied
							&& overlap_bit26_result.committed
							&& overlap_bit26_result.feasibility_results_0x4aa603.size() == 1
							&& overlap_bit26_result.feasibility_results_0x4aa603[0].accepted
							&& overlap_bit26_result.feasibility_results_0x4aa603[0].overlap_bit26_reject_count == 0
							&& overlap_bit26_result.feasibility_results_0x4aa603[0].overlap_bit22_reject_count == 0,
						"0x4aa603 overlap pass incorrectly rejected a bit26-only generator destination under a wrapper bit27-clear cell")) {
				return 1;
			}
		}
		{
			GeneratorObjectPrivateState overlap_bit22_state = reward_guard_base_state;
			RewardGuardWrapperState4aa3e9 overlap_bit22_wrapper = reward_guard_base_wrapper;
			GeneratorRelationOwnerState4a218c overlap_bit22_relation = reward_guard_relation;
			overlap_bit22_wrapper.bound_left_0x18 = 2;
			overlap_bit22_wrapper.bound_top_0x1c = 0;
			overlap_bit22_wrapper.bound_right_0x20 = 3;
			overlap_bit22_wrapper.bound_bottom_0x24 = 1;
			overlap_bit22_relation.scan_bound_low_x_0x20 = 4;
			overlap_bit22_relation.scan_bound_low_y_0x24 = 2;
			overlap_bit22_relation.scan_bound_high_x_0x28 = 5;
			overlap_bit22_relation.scan_bound_high_y_0x2c = 3;
			GeneratedCellRecord0x30 &overlap_bit22_destination =
					overlap_bit22_state.generated_cell_buffer.records[size_t(aurelion::h3maped_rmg_core::cell_index(6, 6, 4, 2, 0))];
			overlap_bit22_destination.word_0x20 = 0x0004000aU;
			overlap_bit22_destination.word_0x28 |= aurelion::h3maped_rmg_core::CELL_ACTION_CONTROL_BIT_22;
			H3MapedRng overlap_bit22_rng;
			overlap_bit22_rng.state = 58U;
			const RewardGuardCoordinateScanResult4aa9b7 overlap_bit22_result =
					aurelion::h3maped_rmg_core::reward_guard_coordinate_scan_and_commit_0x4aa9b7(
							overlap_bit22_state,
							overlap_bit22_wrapper,
							overlap_bit22_relation,
							7,
							true,
							overlap_bit22_rng);
			if (!require(!overlap_bit22_result.applied
							&& !overlap_bit22_result.committed
							&& overlap_bit22_result.feasibility_results_0x4aa603.size() == 1
							&& overlap_bit22_result.feasibility_results_0x4aa603[0].overlap_bit22_reject_count == 1
							&& overlap_bit22_result.feasibility_results_0x4aa603[0].blocked_reason == "0x4aa603_overlap_existing_bit22_reject"
							&& overlap_bit22_result.blocked_reason == "0x4aa9b7_candidate_vector_empty_after_score_and_0x4aa603_filters",
						"0x4aa603 overlap pass did not reject a bit22-marked generator destination under a wrapper bit27-clear cell")) {
				return 1;
			}
		}
	RewardGuardWrapperState4aa3e9 blocked_reward_guard_wrapper = reward_guard_wrapper;
	blocked_reward_guard_wrapper.selected_members_0x2c_0x30[0].source_record_copy_known_0x04 = false;
	H3MapedRng blocked_reward_guard_rng;
	blocked_reward_guard_rng.state = 58U;
	const RewardGuardCoordinateScanResult4aa9b7 blocked_reward_guard_result =
			aurelion::h3maped_rmg_core::reward_guard_coordinate_scan_and_commit_0x4aa9b7(
					reward_guard_state,
					blocked_reward_guard_wrapper,
					reward_guard_relation,
					7,
					true,
					blocked_reward_guard_rng);
	if (!require(!blocked_reward_guard_result.applied
					&& !blocked_reward_guard_result.committed
					&& blocked_reward_guard_result.blocked_reason == "0x4aa9b7_0x4aa603_feasibility_filter_inputs_missing",
				"0x4aa9b7 did not fail closed when recovered 0x4aa603 feasibility inputs are missing")) {
		return 1;
	}
	{
		GeneratorObjectPrivateState mask_order_state;
		mask_order_state.width = 6;
		mask_order_state.height = 6;
		mask_order_state.level_count = 1;
		mask_order_state.generated_cell_buffer = aurelion::h3maped_rmg_core::generated_cell_record_grid_reset_0x49a072(6, 6, 1);
		mask_order_state.generated_cell_buffer_owned = true;
		for (GeneratedCellRecord0x30 &record : mask_order_state.generated_cell_buffer.records) {
			record.object_reference_vector_contents_known = true;
			record.object_reference_count = 0;
			record.object_references_0x04_0x08.clear();
			record.word_0x20_known = true;
			record.word_0x20 = 0x0004000aU;
			record.word_0x24_known = true;
			record.word_0x24 = 0U;
			record.word_0x28_known = true;
			record.word_0x28 = aurelion::h3maped_rmg_core::GENERATED_CELL_INITIAL_WORD_0X28_VALUE;
			aurelion::h3maped_rmg_core::generated_cell_49a932(record, false);
			record.word_0x2c_known = true;
			record.word_0x2c = 0U;
		}
		auto mask_order_cell = [&](int32_t x, int32_t y) -> GeneratedCellRecord0x30 & {
			return mask_order_state.generated_cell_buffer.records[size_t(aurelion::h3maped_rmg_core::cell_index(6, 6, x, y, 0))];
		};
		aurelion::h3maped_rmg_core::generated_cell_49aa63(mask_order_cell(3, 2), true);

		RewardGuardWrapperMember4aa3e9 mask_order_member;
		mask_order_member.object_record_key = 0x0364df10U;
		mask_order_member.object_record_key_known = true;
		mask_order_member.object_record_vtable_0x00 = aurelion::h3maped_rmg_core::OBJECT_RECORD_VTABLE_0X540A74;
		mask_order_member.descriptor_type_0x1c = 45;
		mask_order_member.relative_x_0x08 = 0;
		mask_order_member.relative_y_0x0c = 0;
		mask_order_member.relative_level_0x10 = 0;
		mask_order_member.descriptor_offset_x_0x2c = 0;
		mask_order_member.descriptor_offset_y_0x30 = 0;
		mask_order_member.source_record_copy_known_0x04 = true;
		mask_order_member.source_record_copy.type_id_0x1c = 45;
		mask_order_member.source_record_copy.descriptor_width_0x34 = 2;
		mask_order_member.source_record_copy.descriptor_height_0x38 = 2;
		mask_order_member.source_record_copy.descriptor_mask_fields_0x34_0x48_known = true;
		mask_order_member.source_record_copy.descriptor_mask_a_0x3c_0x40 =
				(uint64_t(1) << 47U) | (uint64_t(1) << 46U) | (uint64_t(1) << 39U) | (uint64_t(1) << 38U);
		mask_order_member.source_record_copy.descriptor_mask_b_0x44_0x48 = uint64_t(1) << 39U;

		RewardGuardWrapperState4aa3e9 mask_order_wrapper;
		mask_order_wrapper.wrapper_bounds_0x18_0x24_known = true;
		mask_order_wrapper.bound_left_0x18 = 0;
		mask_order_wrapper.bound_top_0x1c = 0;
		mask_order_wrapper.bound_right_0x20 = 0;
		mask_order_wrapper.bound_bottom_0x24 = 0;
		mask_order_wrapper.selected_member_vector_0x2c_0x30_known = true;
		mask_order_wrapper.selected_members_0x2c_0x30.push_back(mask_order_member);
		mask_order_wrapper.candidate_coordinate_vector_0x3c_0x40_known = true;
		mask_order_wrapper.generated_cell_grid_0x08_0x10_known = true;
		mask_order_wrapper.generated_cell_grid_0x08_0x10 = aurelion::h3maped_rmg_core::generated_cell_record_grid_reset_0x49a072(2, 2, 1);

		GeneratorRelationOwnerState4a218c mask_order_relation;
		mask_order_relation.runtime_zone_index = 2;
		mask_order_relation.source_zone_id = 5;
		mask_order_relation.source_pointer_0x00_known = true;
		mask_order_relation.source_pointer_source_index_0x00 = 4;
		mask_order_relation.relation_owner_byte2_0x4aa9b7_known = true;
		mask_order_relation.relation_owner_byte2_0x4aa9b7 = 4;
		mask_order_relation.terrain_policy_0x0c_known = true;
		mask_order_relation.terrain_policy_0x0c = 0;
		mask_order_relation.coordinate_triple_0x10_0x18_known = true;
		mask_order_relation.coordinate_x_0x10 = 3;
		mask_order_relation.coordinate_y_0x14 = 3;
		mask_order_relation.coordinate_level_0x18 = 0;
		mask_order_relation.scan_bounds_0x20_0x2c_known = true;
		mask_order_relation.scan_bound_low_x_0x20 = 3;
		mask_order_relation.scan_bound_low_y_0x24 = 3;
		mask_order_relation.scan_bound_high_x_0x28 = 3;
		mask_order_relation.scan_bound_high_y_0x2c = 3;
		H3MapedRng mask_order_rng;
		mask_order_rng.state = 19U;
		const RewardGuardCoordinateScanResult4aa9b7 mask_order_result =
				aurelion::h3maped_rmg_core::reward_guard_coordinate_scan_and_commit_0x4aa9b7(
						mask_order_state,
						mask_order_wrapper,
						mask_order_relation,
						7,
						true,
						mask_order_rng);
		bool mask_order_trace_ok = false;
		if (mask_order_result.feasibility_results_0x4aa603.size() == 1) {
			const auto &mask_order_trace = mask_order_result.feasibility_results_0x4aa603[0].first_footprint_trace_0x49a6f9;
			mask_order_trace_ok =
					mask_order_trace.known
					&& mask_order_trace.mask_x == 0
					&& mask_order_trace.mask_y == 1
					&& mask_order_trace.cell_x == 3
					&& mask_order_trace.cell_y == 2
					&& mask_order_trace.secondary_mask
					&& mask_order_trace.primary_mask;
		}
		if (!require(!mask_order_result.applied
						&& !mask_order_result.committed
						&& mask_order_result.blocked_reason == "0x4aa9b7_candidate_vector_empty_after_score_and_0x4aa603_filters"
						&& mask_order_result.feasibility_results_0x4aa603.size() == 1
						&& mask_order_result.feasibility_results_0x4aa603[0].blocked_reason == "0x4aa603_0x49a6f9_footprint_existing_bit26_rejected"
						&& mask_order_trace_ok,
					"0x49a6f9 did not use recovered row-major descriptor mask bit order for reward/guard footprint rejection")) {
			return 1;
		}
	}
	const RewardGuardWrapperConstructResult49ce04 attach_construct =
			aurelion::h3maped_rmg_core::reward_guard_wrapper_construct_0x49ce04();
	if (!require(attach_construct.applied
					&& attach_construct.width_0x0c == 16
					&& attach_construct.height_0x10 == 16
					&& attach_construct.level_count_0x14 == 1
					&& attach_construct.reset_cell_count_0x49ce64 == 256
					&& attach_construct.wrapper.generated_cell_grid_0x08_0x10_known
					&& attach_construct.wrapper.selected_member_vector_0x2c_0x30_known
					&& attach_construct.wrapper.selected_members_0x2c_0x30.empty()
					&& attach_construct.wrapper.candidate_coordinate_vector_0x3c_0x40_known
					&& attach_construct.wrapper.candidate_coordinates_0x3c_0x40.empty()
					&& attach_construct.wrapper.attached_flag_0x48_known
					&& !attach_construct.wrapper.attached_flag_0x48
					&& attach_construct.wrapper.final_projection_mark_byte_0x60_known
					&& !attach_construct.wrapper.final_projection_mark_byte_0x60,
				"0x49ce04/0x49ce64 wrapper construct did not initialize the recovered 16x16x1 wrapper fields")) {
		return 1;
	}
	RewardGuardWrapperState4aa3e9 contour_wrapper;
	contour_wrapper.candidate_coordinate_vector_0x3c_0x40_known = true;
	contour_wrapper.generated_cell_grid_0x08_0x10_known = true;
	contour_wrapper.generated_cell_grid_0x08_0x10 = aurelion::h3maped_rmg_core::generated_cell_record_grid_reset_0x49a072(5, 5, 1);
	for (GeneratedCellRecord0x30 &record : contour_wrapper.generated_cell_grid_0x08_0x10.records) {
		record.word_0x24_known = true;
		record.word_0x24 = 0U;
		record.word_0x28_known = true;
		record.word_0x28 = aurelion::h3maped_rmg_core::GENERATED_CELL_INITIAL_WORD_0X28_VALUE;
	}
	GeneratedCellRecord0x30 &contour_boundary =
			contour_wrapper.generated_cell_grid_0x08_0x10.records[size_t(aurelion::h3maped_rmg_core::cell_index(5, 5, 2, 2, 0))];
	aurelion::h3maped_rmg_core::generated_cell_49a932(contour_boundary, false);
	const auto contour_result = aurelion::h3maped_rmg_core::reward_guard_wrapper_rebuild_candidates_0x49d7c3(contour_wrapper);
	const std::vector<aurelion::h3maped_rmg_core::CoordinateCandidate4a17f5> expected_contour = {
		{ 2, 1, 0 },
		{ 3, 1, 0 },
		{ 3, 2, 0 },
		{ 3, 3, 0 },
		{ 2, 3, 0 },
		{ 1, 3, 0 },
		{ 1, 2, 0 },
		{ 1, 1, 0 },
	};
	bool contour_matches_expected = contour_result.appended_coordinates.size() == expected_contour.size()
			&& contour_wrapper.candidate_coordinates_0x3c_0x40.size() == expected_contour.size();
	for (size_t index = 0; contour_matches_expected && index < expected_contour.size(); ++index) {
		contour_matches_expected =
				contour_result.appended_coordinates[index].x == expected_contour[index].x
				&& contour_result.appended_coordinates[index].y == expected_contour[index].y
				&& contour_result.appended_coordinates[index].level == expected_contour[index].level
				&& contour_wrapper.candidate_coordinates_0x3c_0x40[index].x == expected_contour[index].x
				&& contour_wrapper.candidate_coordinates_0x3c_0x40[index].y == expected_contour[index].y
				&& contour_wrapper.candidate_coordinates_0x3c_0x40[index].level == expected_contour[index].level;
	}
	if (!require(contour_result.applied
					&& contour_result.seed_boundary_found
					&& contour_result.seed_boundary_x == 2
					&& contour_result.seed_boundary_y == 2
					&& contour_result.candidate_count_before == 0
					&& contour_result.candidate_count_after == 8
					&& contour_result.contour_append_count == 8
					&& contour_result.contour_forced_step_count == 0
					&& contour_matches_expected,
				"0x49d7c3 did not rebuild the recovered wrapper contour from generated-cell passability")) {
		return 1;
	}
	RewardGuardWrapperState4aa3e9 attach_wrapper = attach_construct.wrapper;
	for (GeneratedCellRecord0x30 &record : attach_wrapper.generated_cell_grid_0x08_0x10.records) {
		record.word_0x20_known = true;
		record.word_0x20 = 0x00ff0000U;
		record.word_0x24_known = true;
		record.word_0x24 = 0U;
		record.word_0x28_known = true;
		record.word_0x28 = aurelion::h3maped_rmg_core::GENERATED_CELL_INITIAL_WORD_0X28_VALUE;
		record.word_0x2c_known = true;
		record.word_0x2c = 0U;
	}
	auto attach_cell = [&](int32_t x, int32_t y) -> GeneratedCellRecord0x30 & {
		return attach_wrapper.generated_cell_grid_0x08_0x10.records[size_t(aurelion::h3maped_rmg_core::cell_index(16, 16, x, y, 0))];
	};
	for (int32_t y = 10; y <= 12; ++y) {
		for (int32_t x = 7; x <= 9; ++x) {
			aurelion::h3maped_rmg_core::generated_cell_49a932(attach_cell(x, y), false);
		}
	}
	aurelion::h3maped_rmg_core::generated_cell_49aa63(attach_cell(8, 11), true);
	aurelion::h3maped_rmg_core::generated_cell_49aa63(attach_cell(7, 11), true);
	aurelion::h3maped_rmg_core::generated_cell_49abd6_body_reject_stamp(attach_cell(7, 11));
	attach_wrapper.candidate_coordinates_0x3c_0x40 = {
		{ 8, 11, 0 },
		{ 7, 11, 0 },
		{ 5, 5, 0 },
	};
	RewardGuardWrapperMember4aa3e9 attach_member;
	attach_member.object_record_key = 0x036225e0U;
	attach_member.object_record_key_known = true;
	attach_member.object_record_vtable_0x00 = aurelion::h3maped_rmg_core::OBJECT_RECORD_VTABLE_0X540A74;
	attach_member.descriptor_type_0x1c = 54;
	attach_member.descriptor_offset_x_0x2c = 1;
	attach_member.descriptor_offset_y_0x30 = 0;
	attach_member.source_record_copy_known_0x04 = true;
	attach_member.source_record_copy.descriptor_width_0x34 = 1;
	attach_member.source_record_copy.descriptor_height_0x38 = 1;
	attach_member.source_record_copy.descriptor_mask_fields_0x34_0x48_known = true;
	attach_member.source_record_copy.descriptor_mask_a_0x3c_0x40 = 0U;
	attach_member.source_record_copy.descriptor_mask_b_0x44_0x48 = uint64_t(1) << 47U;
	attach_member.descriptor_body_offsets_0x49a6f9_known = true;
	attach_member.descriptor_body_offsets_0x49a6f9 = {
		{ 0, 0, 0 },
	};
	H3MapedRng attach_rng;
	attach_rng.state = 11U;
	const RewardGuardAttachResult49cf34 attach_result =
			aurelion::h3maped_rmg_core::reward_guard_attach_member_0x49cf34(attach_wrapper, attach_member, attach_rng);
	const int32_t attach_rebuilt_candidate_count = attach_result.candidate_rebuild_0x49d7c3.candidate_count_after;
	if (!require(attach_result.applied
					&& attach_result.initial_candidate_refresh_0x49d7c3_applied
					&& attach_result.initial_candidate_refresh_returned_existing_vector_0x49d7c3
					&& attach_result.candidate_count_before_filter == 3
					&& attach_result.bit26_clear_candidate_erase_count_0x4afaea == 1
					&& attach_result.filter_reject_count_0x49d2e0 == 1
					&& attach_result.filter_missing_input_count_0x49d2e0 == 0
					&& attach_result.candidate_count_after_filter == 1
					&& attach_result.filter_results_0x49d2e0.size() == 2
					&& !attach_result.filter_results_0x49d2e0[0].accepted
					&& attach_result.filter_results_0x49d2e0[0].footprint_reject_count_0x49a6f9 == 1
					&& attach_result.filter_results_0x49d2e0[1].accepted
					&& attach_result.selected_candidate_known
					&& attach_result.selected_candidate.x == 8
					&& attach_result.selected_candidate.y == 11
					&& attach_result.selected_candidate.level == 0
					&& attach_result.appended_member_0x49d69d
					&& attach_result.selected_member_count_after == 1,
				"0x49cf34 did not refresh, filter, RNG-select, and append the recovered reward/guard attach candidate")) {
		return 1;
	}
	const bool attach_wrapper_fields_ok =
			attach_wrapper.selected_members_0x2c_0x30[0].object_record_key == 0x036225e0U
			&& attach_wrapper.selected_members_0x2c_0x30[0].relative_x_0x08 == 8
			&& attach_wrapper.selected_members_0x2c_0x30[0].relative_y_0x0c == 11
			&& attach_wrapper.selected_members_0x2c_0x30[0].relative_level_0x10 == 0
			&& attach_wrapper.attached_flag_0x48_known
			&& attach_wrapper.attached_flag_0x48
			&& attach_wrapper.attached_relative_coordinate_0x4c_0x50_known
			&& attach_wrapper.attached_relative_x_0x4c == 7
			&& attach_wrapper.attached_relative_y_0x50 == 11
			&& attach_result.stamped_member_0x49abd6
			&& attach_result.body_stamp_count_0x49abd6 == 1
			&& attach_result.primary_bit27_write_count_0x49d1ed == 4
			&& attach_result.neighbor_bit27_write_count_0x49d270 == 3
			&& attach_result.candidate_cleanup_count_0x4ae2d0 == 1
			&& attach_result.bounds_refresh_0x49d6e0.applied
			&& attach_result.candidate_rebuild_0x49d7c3.applied
			&& attach_result.candidate_rebuild_0x49d7c3.seed_boundary_found
			&& attach_rebuilt_candidate_count > 0
			&& attach_rebuilt_candidate_count == attach_result.candidate_rebuild_0x49d7c3.contour_append_count;
	if (!attach_wrapper_fields_ok) {
		std::cerr << "h3maped_rmg_core_selftest: 0x49cf34 state selected=("
				  << attach_wrapper.selected_members_0x2c_0x30[0].relative_x_0x08 << ","
				  << attach_wrapper.selected_members_0x2c_0x30[0].relative_y_0x0c << ") attached=("
				  << attach_wrapper.attached_relative_x_0x4c << ","
				  << attach_wrapper.attached_relative_y_0x50 << ") stamp="
				  << attach_result.body_stamp_count_0x49abd6 << " primary="
				  << attach_result.primary_bit27_write_count_0x49d1ed << " neighbor="
				  << attach_result.neighbor_bit27_write_count_0x49d270 << " cleanup="
				  << attach_result.candidate_cleanup_count_0x4ae2d0 << " rebuilt="
				  << attach_rebuilt_candidate_count << "/"
				  << attach_result.candidate_rebuild_0x49d7c3.contour_append_count << "\n";
	}
	if (!require(attach_wrapper_fields_ok,
				"0x49cf34 did not stamp, block, set wrapper fields, cleanup, and rebuild recovered wrapper candidates")) {
		return 1;
	}
	if (!require(attach_cell(8, 11).byte_0x2a_known
					&& (attach_cell(8, 11).byte_0x2a & 0x40U) != 0U
					&& (attach_cell(8, 11).word_0x28 & aurelion::h3maped_rmg_core::CELL_OCCUPIED_BLOCKED_BIT_27) != 0U
					&& (attach_cell(8, 11).word_0x28 & aurelion::h3maped_rmg_core::CELL_DECOR_CANDIDATE_BIT_26) == 0U,
				"0x49cf34 selected wrapper cell did not end with recovered byte 0x2a/body occupancy state")) {
		return 1;
	}
	if (!require(std::find(
					attach_cell(8, 11).object_references_0x04_0x08.begin(),
					attach_cell(8, 11).object_references_0x04_0x08.end(),
					0x036225e0U) != attach_cell(8, 11).object_references_0x04_0x08.end(),
				"0x49cf34 selected wrapper cell did not receive the recovered 0x49abd6 object reference")) {
		return 1;
	}
	RewardGuardWrapperState4aa3e9 local_lookup_wrapper = attach_construct.wrapper;
	for (GeneratedCellRecord0x30 &record : local_lookup_wrapper.generated_cell_grid_0x08_0x10.records) {
		record.word_0x20_known = true;
		record.word_0x20 = 0x00ff0000U;
		record.word_0x24_known = true;
		record.word_0x24 = 0U;
		record.word_0x28_known = true;
		record.word_0x28 = aurelion::h3maped_rmg_core::GENERATED_CELL_INITIAL_WORD_0X28_VALUE;
		record.word_0x2c_known = true;
		record.word_0x2c = 0U;
	}
	auto local_lookup_cell = [&](int32_t x, int32_t y) -> GeneratedCellRecord0x30 & {
		return local_lookup_wrapper.generated_cell_grid_0x08_0x10.records[size_t(aurelion::h3maped_rmg_core::cell_index(16, 16, x, y, 0))];
	};
	for (int32_t y = 10; y <= 12; ++y) {
		for (int32_t x = 6; x <= 9; ++x) {
			aurelion::h3maped_rmg_core::generated_cell_49a932(local_lookup_cell(x, y), false);
		}
	}
	aurelion::h3maped_rmg_core::generated_cell_49aa63(local_lookup_cell(8, 11), true);
	GeneratedCellRecord0x30 &local_lookup_neighbor = local_lookup_cell(6, 11);
	local_lookup_neighbor.word_0x28 |= aurelion::h3maped_rmg_core::CELL_ACTION_CONTROL_BIT_22;
	local_lookup_neighbor.object_reference_vector_contents_known = true;
	local_lookup_neighbor.object_references_0x04_0x08 = { 0x03620054U };
	local_lookup_neighbor.object_reference_count = 1;
	RewardGuardWrapperMember4aa3e9 local_lookup_existing_member;
	local_lookup_existing_member.object_record_key = 0x03620054U;
	local_lookup_existing_member.object_record_key_known = true;
	local_lookup_existing_member.object_record_vtable_0x00 = aurelion::h3maped_rmg_core::OBJECT_RECORD_VTABLE_0X540A74;
	local_lookup_existing_member.descriptor_type_0x1c = 54;
	local_lookup_existing_member.relative_x_0x08 = 6;
	local_lookup_existing_member.relative_y_0x0c = 11;
	local_lookup_existing_member.relative_level_0x10 = 0;
	local_lookup_existing_member.descriptor_offset_x_0x2c = 0;
	local_lookup_existing_member.descriptor_offset_y_0x30 = 0;
	local_lookup_wrapper.selected_members_0x2c_0x30.push_back(local_lookup_existing_member);
	local_lookup_wrapper.candidate_coordinates_0x3c_0x40 = {
		{ 8, 11, 0 },
	};
	RewardGuardWrapperMember4aa3e9 local_lookup_attach_member = attach_member;
	local_lookup_attach_member.object_record_key = 0x03620055U;
	local_lookup_attach_member.object_record_key_known = true;
	local_lookup_attach_member.descriptor_type_0x1c = 54;
	local_lookup_attach_member.descriptor_offset_x_0x2c = 1;
	local_lookup_attach_member.descriptor_offset_y_0x30 = 0;
	std::vector<ObjectRecordReference4a54a7> conflicting_global_records;
	ObjectRecordReference4a54a7 conflicting_global_record;
	conflicting_global_record.object_record_key = 0x03620054U;
	conflicting_global_record.descriptor_type_0x1c = 0;
	conflicting_global_records.push_back(conflicting_global_record);
	H3MapedRng local_lookup_rng;
	local_lookup_rng.state = 11U;
	const RewardGuardAttachResult49cf34 local_lookup_result =
			aurelion::h3maped_rmg_core::reward_guard_attach_member_0x49cf34(
					local_lookup_wrapper,
					local_lookup_attach_member,
					local_lookup_rng,
					&conflicting_global_records);
	if (!require(local_lookup_result.applied
					&& local_lookup_result.filter_results_0x49d2e0.size() == 1
					&& local_lookup_result.filter_results_0x49d2e0[0].inputs_available
					&& local_lookup_result.filter_results_0x49d2e0[0].accepted
					&& local_lookup_result.filter_results_0x49d2e0[0].neighbor_bit22_policy_check_count == 1
					&& local_lookup_result.filter_results_0x49d2e0[0].neighbor_policy_plus_2_reject_count == 0
					&& local_lookup_result.filter_results_0x49d2e0[0].neighbor_policy_plus_1_reject_count == 0
					&& local_lookup_result.selected_candidate_known
					&& local_lookup_result.selected_candidate.x == 8
					&& local_lookup_result.selected_candidate.y == 11,
				"0x49d2e0 did not resolve bit22 neighbor descriptor through wrapper-local selected members before global object records")) {
		return 1;
	}
	const RewardGuardWrapperFinalMarkResult49cefb final_mark_result =
			aurelion::h3maped_rmg_core::reward_guard_wrapper_mark_candidate_cells_0x49cefb(attach_wrapper);
	int32_t final_marked_grid_cell_count = 0;
	int32_t final_marked_word_mirror_cell_count = 0;
	for (const GeneratedCellRecord0x30 &record : attach_wrapper.generated_cell_grid_0x08_0x10.records) {
		if (record.byte_0x2a_known
				&& (record.byte_0x2a_known_mask & aurelion::h3maped_rmg_core::CELL_REWARD_GUARD_FINAL_MARK_BYTE_0X2A_BIT_7) != 0U
				&& (record.byte_0x2a & aurelion::h3maped_rmg_core::CELL_REWARD_GUARD_FINAL_MARK_BYTE_0X2A_BIT_7) != 0U) {
			final_marked_grid_cell_count += 1;
			if (record.word_0x28_known
					&& (record.word_0x28 & aurelion::h3maped_rmg_core::CELL_REWARD_GUARD_DIRECTION_BIT_23) != 0U) {
				final_marked_word_mirror_cell_count += 1;
			}
		}
	}
	if (!require(final_mark_result.applied
					&& attach_wrapper.final_projection_mark_byte_0x60_known
					&& attach_wrapper.final_projection_mark_byte_0x60
					&& final_mark_result.candidate_count == attach_rebuilt_candidate_count
					&& final_mark_result.marked_candidate_cell_count > 0
					&& final_mark_result.marked_candidate_cell_count <= attach_rebuilt_candidate_count
					&& final_mark_result.out_of_bounds_candidate_count == 0
					&& final_marked_grid_cell_count == final_mark_result.marked_candidate_cell_count
					&& final_marked_word_mirror_cell_count == final_marked_grid_cell_count,
				"0x49cefb did not set wrapper +0x60 and mirror cell+0x2a bit7 into generated-cell +0x28 bit23")) {
		return 1;
	}
	RewardGuardWrapperState4aa3e9 blocked_attach_wrapper = attach_construct.wrapper;
	for (GeneratedCellRecord0x30 &record : blocked_attach_wrapper.generated_cell_grid_0x08_0x10.records) {
		record.word_0x20_known = true;
		record.word_0x20 = 0x00ff0000U;
		record.word_0x24_known = true;
		record.word_0x24 = 0U;
		record.word_0x28_known = true;
		record.word_0x28 = aurelion::h3maped_rmg_core::GENERATED_CELL_INITIAL_WORD_0X28_VALUE;
		record.word_0x2c_known = true;
		record.word_0x2c = 0U;
	}
	auto blocked_attach_cell = [&](int32_t x, int32_t y) -> GeneratedCellRecord0x30 & {
		return blocked_attach_wrapper.generated_cell_grid_0x08_0x10.records[size_t(aurelion::h3maped_rmg_core::cell_index(16, 16, x, y, 0))];
	};
	blocked_attach_wrapper.candidate_coordinates_0x3c_0x40 = {
		{ 8, 11, 0 },
	};
	aurelion::h3maped_rmg_core::generated_cell_49a932(blocked_attach_cell(8, 11), false);
	aurelion::h3maped_rmg_core::generated_cell_49aa63(blocked_attach_cell(8, 11), true);
	RewardGuardWrapperMember4aa3e9 blocked_attach_member = attach_member;
	blocked_attach_member.source_record_copy_known_0x04 = false;
	H3MapedRng blocked_attach_rng;
	blocked_attach_rng.state = 11U;
	const RewardGuardAttachResult49cf34 blocked_attach_result =
			aurelion::h3maped_rmg_core::reward_guard_attach_member_0x49cf34(blocked_attach_wrapper, blocked_attach_member, blocked_attach_rng);
	if (!require(!blocked_attach_result.applied
					&& blocked_attach_result.filter_missing_input_count_0x49d2e0 == 1
					&& blocked_attach_result.blocked_reason == "0x49cf34_0x49d2e0_candidate_filter_inputs_missing",
				"0x49cf34 did not fail closed when recovered 0x49d2e0 filter inputs are missing")) {
		return 1;
	}
	const std::vector<SourceObjectRecord0x4c> type98_records =
			aurelion::h3maped_rmg_core::source_object_records_by_type_0x49da08(98);
	const auto dungeon_town = std::find_if(type98_records.begin(), type98_records.end(), [](const SourceObjectRecord0x4c &record) {
		return record.source_row == 153;
	});
	if (!require(dungeon_town != type98_records.end(), "0x49da08 source row 153 Town record missing for recovered weighted type-98 materialization")) {
		return 1;
	}
	if (!require(dungeon_town->passability_mask == "000001110000011110001111111111111111111111111111"
					&& dungeon_town->action_mask == "001000000000000000000000000000000000000000000000"
					&& dungeon_town->pass_count == 35
					&& dungeon_town->action_count == 1,
			"type-98 town source record did not preserve recovered text passability/action masks")) {
		return 1;
	}
	const auto dungeon_body_points = aurelion::h3maped_rmg_core::source_object_text_mask_points_0x490f3f(dungeon_town->passability_mask, false);
	const auto dungeon_action_points = aurelion::h3maped_rmg_core::source_object_text_mask_points_0x490f3f(dungeon_town->action_mask, true);
	if (!require(dungeon_body_points.size() == size_t(48 - dungeon_town->pass_count)
					&& dungeon_body_points[0].dx == 0
					&& dungeon_body_points[0].dy == -5,
			"type-98 town source record did not decode recovered passability mask body cells")) {
		return 1;
	}
	if (!require(dungeon_action_points.size() == size_t(dungeon_town->action_count)
					&& dungeon_action_points[0].dx == -2
					&& dungeon_action_points[0].dy == -5,
			"type-98 town source record did not decode recovered action mask visit cell")) {
		return 1;
	}
	if (!require(std::any_of(dungeon_body_points.begin(), dungeon_body_points.end(), [](const auto &point) {
				return point.dx == -2 && point.dy == -5;
			}),
			"type-98 town recovered action cell is not part of the non-passable body footprint")) {
		return 1;
	}
	if (!require(dungeon_town->descriptor_mask_fields_0x34_0x48_known
					&& dungeon_town->descriptor_mask_fields_exact_def_msk
					&& dungeon_town->descriptor_width_0x34 == 6
					&& dungeon_town->descriptor_height_0x38 == 6
					&& dungeon_town->descriptor_mask_a_0x3c_0x40 == 0xfcfcfcfcfcfcULL
					&& dungeon_town->descriptor_mask_b_0x44_0x48 == 0xfcfcfcfcfcfcULL,
			"type-98 town source record did not preserve recovered descriptor .msk fields")) {
		return 1;
	}
	if (!require(dungeon_town->raw_field_0x20_known
					&& dungeon_town->raw_field_0x20 == dungeon_town->subtype_0x20
					&& dungeon_town->raw_field_0x24_known
					&& dungeon_town->raw_field_0x24 == dungeon_town->group_0x24
					&& dungeon_town->raw_field_0x28_known
					&& dungeon_town->raw_field_0x28 == dungeon_town->last_flag_0x28
					&& !dungeon_town->raw_field_0x2c_known
					&& !dungeon_town->raw_field_0x30_known
					&& !dungeon_town->raw_field_0x34_known
					&& !dungeon_town->raw_field_0x38_known,
			"copied source-record raw fields were not separated from descriptor .msk fields")) {
		return 1;
	}
	SourceObjectDescriptor4903e8 weighted_descriptor;
	weighted_descriptor.target_context_0x4903e8 = 98;
	weighted_descriptor.source_key_0x00 = 153;
	weighted_descriptor.descriptor_type_0x1c = dungeon_town->type_id_0x1c;
	weighted_descriptor.subtype_0x20 = dungeon_town->subtype_0x20;
	weighted_descriptor.group_0x24 = dungeon_town->group_0x24;
	weighted_descriptor.projection_enabled_0x29 = true;
	weighted_descriptor.source_cell_x_0x2c = 2;
	weighted_descriptor.source_cell_y_0x30 = 0;
	weighted_descriptor.descriptor_mask_fields_0x34_0x48_known = true;
	weighted_descriptor.descriptor_width_0x34 = dungeon_town->descriptor_width_0x34;
	weighted_descriptor.descriptor_height_0x38 = dungeon_town->descriptor_height_0x38;
	weighted_descriptor.descriptor_mask_a_0x3c_0x40 = dungeon_town->descriptor_mask_a_0x3c_0x40;
	weighted_descriptor.descriptor_mask_b_0x44_0x48 = dungeon_town->descriptor_mask_b_0x44_0x48;
	SourceObjectResolverState4af785 weighted_resolver_state;
	const SourceObjectDescriptorJoinResult4903e8 weighted_join =
			aurelion::h3maped_rmg_core::source_object_descriptor_join_0x4903e8(weighted_resolver_state, weighted_descriptor, *dungeon_town);
	if (!require(!weighted_join.joined
					&& !weighted_join.recovered_target_context
					&& weighted_join.resolver_invoked_0x4af785
					&& weighted_join.copied_source_record_is_identity_authority
					&& weighted_join.descriptor_source_fields_match
					&& weighted_join.descriptor_mask_fields_match_source_0x34_0x48
					&& weighted_join.source_catalog_index_0x49da08 >= 0
					&& weighted_join.resolver_0x4af785.selected_wrapper_index >= 0
					&& weighted_join.blocked_reason.empty()
					&& weighted_resolver_state.source_pairs_0xedc.size() == 1U
					&& weighted_resolver_state.source_pairs_0xedc[0].wrapper_index == weighted_join.resolver_0x4af785.selected_wrapper_index
					&& !weighted_resolver_state.source_pairs_0xedc[0].descriptor_join_0x4903e8_known,
				"type-98 weighted materialization did not preserve the recovered 0x4af785 wrapper/source-pair bridge state")) {
		return 1;
	}
	SourceObjectDescriptor4903e8 mismatched_weighted_descriptor = weighted_descriptor;
	mismatched_weighted_descriptor.descriptor_mask_b_0x44_0x48 ^= 1U;
	SourceObjectResolverState4af785 mismatched_weighted_resolver_state;
	const SourceObjectDescriptorJoinResult4903e8 mismatched_weighted_join =
			aurelion::h3maped_rmg_core::source_object_descriptor_join_0x4903e8(mismatched_weighted_resolver_state, mismatched_weighted_descriptor, *dungeon_town);
	if (!require(!mismatched_weighted_join.descriptor_source_fields_match
					&& !mismatched_weighted_join.descriptor_mask_fields_match_source_0x34_0x48
					&& !mismatched_weighted_join.resolver_invoked_0x4af785
					&& mismatched_weighted_resolver_state.source_pairs_0xedc.empty(),
				"0x4903e8 descriptor/source join accepted mismatched recovered .msk fields")) {
		return 1;
	}
	SourceZonePayload4a218c weighted_threshold_payload;
	weighted_threshold_payload.player_towns.town_density = 1;
	weighted_threshold_payload.player_towns.castle_density = 1;
	auto weighted_threshold = aurelion::h3maped_rmg_core::weighted_scheduler_threshold_0x4a8db2(weighted_threshold_payload);
	if (!require(weighted_threshold.source_density_fields_known
					&& weighted_threshold.positive_density_sum == 2
					&& weighted_threshold.threshold_arg_0x18_known
					&& weighted_threshold.threshold_arg_0x18 == 203,
				"0x4a8db2 weighted scheduler threshold did not match recovered density total 2 -> 203")) {
		return 1;
	}
	weighted_threshold_payload.player_towns.town_density = 3;
	weighted_threshold_payload.player_towns.castle_density = 3;
	weighted_threshold_payload.neutral_towns.town_density = 3;
	weighted_threshold_payload.neutral_towns.castle_density = 3;
	weighted_threshold = aurelion::h3maped_rmg_core::weighted_scheduler_threshold_0x4a8db2(weighted_threshold_payload);
	if (!require(weighted_threshold.positive_density_sum == 12
					&& weighted_threshold.threshold_arg_0x18_known
					&& weighted_threshold.threshold_arg_0x18 == 83,
				"0x4a8db2 weighted scheduler threshold did not match recovered density total 12 -> 83")) {
		return 1;
	}
	weighted_threshold_payload.neutral_towns.castle_density = 4;
	weighted_threshold = aurelion::h3maped_rmg_core::weighted_scheduler_threshold_0x4a8db2(weighted_threshold_payload);
	if (!require(weighted_threshold.positive_density_sum == 13
					&& weighted_threshold.threshold_arg_0x18_known
					&& weighted_threshold.threshold_arg_0x18 == 79,
				"0x4a8db2 weighted scheduler threshold did not match recovered density total 13 -> 79")) {
		return 1;
	}
	SourceZonePayload4a218c zero_weighted_threshold_payload;
	weighted_threshold = aurelion::h3maped_rmg_core::weighted_scheduler_threshold_0x4a8db2(zero_weighted_threshold_payload);
	if (!require(weighted_threshold.source_density_fields_known
					&& !weighted_threshold.threshold_arg_0x18_known
					&& weighted_threshold.blocked_reason == "0x4a8db2_weighted_scheduler_no_positive_town_castle_density",
				"0x4a8db2 weighted scheduler threshold did not fail closed on zero density")) {
		return 1;
	}
	RuntimeZoneSeedInput4a218c scheduler_source_zone;
	scheduler_source_zone.source_index = 5;
	scheduler_source_zone.source_owner_index = 2;
	scheduler_source_zone.source_payload.source_ownership = 1;
	scheduler_source_zone.source_payload.player_towns.min_towns = 3;
	scheduler_source_zone.source_payload.player_towns.min_castles = 4;
	scheduler_source_zone.source_payload.player_towns.town_density = 5;
	scheduler_source_zone.source_payload.player_towns.castle_density = 6;
	scheduler_source_zone.source_payload.neutral_towns.min_towns = 7;
	scheduler_source_zone.source_payload.neutral_towns.min_castles = 8;
	scheduler_source_zone.source_payload.neutral_towns.town_density = 9;
	scheduler_source_zone.source_payload.neutral_towns.castle_density = 10;
	const SourceOrderSchedulerSourceRecord4a8db2 scheduler_source_record =
			aurelion::h3maped_rmg_core::source_order_scheduler_source_record_from_runtime_zone_0x4a8db2(scheduler_source_zone);
	if (!require(scheduler_source_record.source_id_0x00 == 5
					&& scheduler_source_record.owner_or_type_0x04 == 1
					&& scheduler_source_record.relation_selector_0x1c == 2
					&& scheduler_source_record.field_0x20_known && scheduler_source_record.field_0x20 == 3
					&& scheduler_source_record.field_0x24_known && scheduler_source_record.field_0x24 == 4
					&& scheduler_source_record.field_0x28_known && scheduler_source_record.field_0x28 == 5
					&& scheduler_source_record.field_0x2c_known && scheduler_source_record.field_0x2c == 6
					&& scheduler_source_record.field_0x30_known && scheduler_source_record.field_0x30 == 7
					&& scheduler_source_record.field_0x34_known && scheduler_source_record.field_0x34 == 8
					&& scheduler_source_record.field_0x38_known && scheduler_source_record.field_0x38 == 9
					&& scheduler_source_record.field_0x3c_known && scheduler_source_record.field_0x3c == 10,
				"0x4a8db2 runtime-zone scheduler source record did not map recovered source town/castle fields")) {
		return 1;
	}
	RuntimeZoneSeedInput4a218c neutral_scheduler_source_zone;
	neutral_scheduler_source_zone.source_index = 2;
	neutral_scheduler_source_zone.source_owner_index = 2;
	neutral_scheduler_source_zone.actual_player_color = -1;
	const SourceOrderSchedulerSourceRecord4a8db2 neutral_scheduler_source_record =
			aurelion::h3maped_rmg_core::source_order_scheduler_source_record_from_runtime_zone_0x4a8db2(neutral_scheduler_source_zone);
	if (!require(neutral_scheduler_source_record.source_id_0x00 == 2
					&& neutral_scheduler_source_record.owner_or_type_0x04 == 2
					&& neutral_scheduler_source_record.relation_selector_0x1c == -1,
				"0x4a8db2 unassigned source owner did not map to recovered neutral source record")) {
		return 1;
	}
	auto make_scheduler_pair = [&](const SourceObjectRecord0x4c &record) {
		SourceObjectResolverSourcePair4af785 pair;
		pair.copied_source_catalog_index = weighted_join.source_catalog_index_0x49da08;
		pair.wrapper_index = 7;
		pair.source_record_pointer_0x00_carried = true;
		pair.source_record_copy = record;
		pair.source_lane_0x1c = 0;
		pair.context_pointer_0x04_carried = true;
		pair.context_wrapper_index_0x04 = 7;
		pair.context_wrapper_lane_0x04 = 0;
		pair.source_pair_success_byte_0x3c_known = true;
		pair.source_pair_success_byte_0x3c = 1;
		return pair;
	};
	SourceObjectRecord0x4c scheduler_direct_record = *dungeon_town;
	scheduler_direct_record.raw_field_0x20_known = true;
	scheduler_direct_record.raw_field_0x20 = 2;
	scheduler_direct_record.raw_field_0x24_known = true;
	scheduler_direct_record.raw_field_0x24 = 3;
	scheduler_direct_record.raw_field_0x2c_known = true;
	scheduler_direct_record.raw_field_0x2c = 0;
	scheduler_direct_record.raw_field_0x28_known = true;
	scheduler_direct_record.raw_field_0x28 = 0;
	scheduler_direct_record.raw_field_0x38_known = true;
	scheduler_direct_record.raw_field_0x38 = 0;
	SourceObjectDescriptorJoinResult4903e8 scheduler_direct_join = weighted_join;
	scheduler_direct_join.source_record_copy = scheduler_direct_record;
	GeneratorObjectPrivateState scheduler_direct_state;
	aurelion::h3maped_rmg_core::H3MapedRng scheduler_direct_rng;
	scheduler_direct_rng.state = 10U;
	const SourceOrderSchedulerResult4a8db2 scheduler_direct =
			aurelion::h3maped_rmg_core::source_order_weighted_scheduler_0x4a8db2(
					scheduler_direct_state,
					scheduler_direct_join,
					make_scheduler_pair(scheduler_direct_record),
					0,
					107,
					6,
					108,
					7,
					0,
					12,
					scheduler_direct_rng,
					true,
					2,
					true,
					2,
					true,
					0);
	if (!require(scheduler_direct.replay_finished
					&& scheduler_direct.blocked_reason == "0x4a8db2_weighted_scheduler_no_positive_density"
					&& scheduler_direct.direct_prepass_call_count == 8
					&& scheduler_direct.weighted_call_count == 0
					&& scheduler_direct.calls.size() == size_t(8)
					&& scheduler_direct.calls[0].callsite == 0x4a8df7U
					&& scheduler_direct.calls[0].loop_index == 1
					&& scheduler_direct.calls[1].callsite == 0x4a8df7U
					&& scheduler_direct.calls[1].loop_index == 2
					&& scheduler_direct.calls[2].callsite == 0x4a8e26U
					&& scheduler_direct.calls[2].loop_index == 0
					&& scheduler_direct.calls[4].callsite == 0x4a8e55U
					&& scheduler_direct.calls[6].callsite == 0x4a8e83U
					&& scheduler_direct_state.source_order_scheduler_replay_count_0x4a8db2 == 1
					&& scheduler_direct_state.source_order_scheduler_direct_call_count_0x4a8db2 == 8
					&& scheduler_direct_state.weighted_candidate_vector_count_0x4a901a == 8,
				"0x4a8db2 scheduler did not replay recovered direct-prepass loop order into 0x4a901a")) {
		return 1;
	}
	SourceObjectRecord0x4c scheduler_weighted_record = *dungeon_town;
	scheduler_weighted_record.raw_field_0x20_known = true;
	scheduler_weighted_record.raw_field_0x20 = 0;
	scheduler_weighted_record.raw_field_0x24_known = true;
	scheduler_weighted_record.raw_field_0x24 = 0;
	scheduler_weighted_record.raw_field_0x2c_known = true;
	scheduler_weighted_record.raw_field_0x2c = 1;
	scheduler_weighted_record.raw_field_0x28_known = true;
	scheduler_weighted_record.raw_field_0x28 = 1;
	scheduler_weighted_record.raw_field_0x38_known = true;
	scheduler_weighted_record.raw_field_0x38 = 1;
	SourceObjectDescriptorJoinResult4903e8 scheduler_weighted_join = weighted_join;
	scheduler_weighted_join.source_record_copy = scheduler_weighted_record;
	GeneratorObjectPrivateState scheduler_weighted_state;
	aurelion::h3maped_rmg_core::H3MapedRng scheduler_weighted_rng;
	scheduler_weighted_rng.state = 10U;
	const SourceOrderSchedulerResult4a8db2 scheduler_weighted =
			aurelion::h3maped_rmg_core::source_order_weighted_scheduler_0x4a8db2(
					scheduler_weighted_state,
					scheduler_weighted_join,
					make_scheduler_pair(scheduler_weighted_record),
					0,
					107,
					6,
					108,
					7,
					0,
					12,
					scheduler_weighted_rng,
					true,
					0,
					true,
					0,
					true,
					1);
	if (!require(scheduler_weighted.replay_finished
					&& scheduler_weighted.threshold_arg_0x18_known
					&& scheduler_weighted.threshold_arg_0x18 == 144
					&& scheduler_weighted.direct_prepass_call_count == 0
					&& scheduler_weighted.weighted_call_count == 4
					&& scheduler_weighted.disabled_lane_count == 4
					&& scheduler_weighted.calls.size() == size_t(4)
					&& scheduler_weighted.calls[0].callsite == 0x4a8ffdU
					&& scheduler_weighted.calls[1].callsite == 0x4a8fd6U
					&& scheduler_weighted.calls[2].callsite == 0x4a8fb4U
					&& scheduler_weighted.calls[3].callsite == 0x4a8f96U
					&& scheduler_weighted.calls[0].disabled_after_false
					&& scheduler_weighted_state.source_order_scheduler_weighted_call_count_0x4a8db2 == 4
					&& scheduler_weighted_state.object_record_allocation_count_0x4a93a2 == 0,
				"0x4a8db2 scheduler did not preserve weighted lane tie order and disable-on-false behavior")) {
		return 1;
	}
	GeneratorObjectPrivateState weighted_scan_state;
	weighted_scan_state.width = 112;
	weighted_scan_state.height = 112;
	weighted_scan_state.level_count = 1;
	weighted_scan_state.generated_cell_buffer = aurelion::h3maped_rmg_core::generated_cell_record_grid_reset_0x49a072(112, 112, 1);
	weighted_scan_state.generated_cell_buffer_owned = true;
	weighted_scan_state.object_records_0xec4_ecc.resize(4);
	weighted_scan_state.descriptor_counter_table_0x1110_present = true;
	weighted_scan_state.descriptor_counter_table_0x1110_contents_known = true;
	weighted_scan_state.descriptor_counter_table_0x1110_known_count = aurelion::h3maped_rmg_core::DESCRIPTOR_COUNTER_TABLE_0X1110_DWORD_COUNT;
	weighted_scan_state.descriptor_counter_table_0x1110.assign(size_t(aurelion::h3maped_rmg_core::DESCRIPTOR_COUNTER_TABLE_0X1110_DWORD_COUNT), 0U);
	weighted_scan_state.descriptor_counter_table_0x1110[size_t(98)] = 4U;
	weighted_scan_state.object_record_sequence_allocator_0xf44_present = true;
	weighted_scan_state.object_record_sequence_allocator_0xf44_known = true;
	weighted_scan_state.object_record_sequence_allocator_0xf44 = 5;
	weighted_scan_state.native_object_record_key_allocator_0x4a93a2_known = true;
	weighted_scan_state.next_native_object_record_key_0x4a93a2 = 0x036b6d40U;
	GeneratorRelationOwnerState4a218c weighted_owner;
	weighted_owner.runtime_zone_index = 0;
	weighted_owner.owner_vector_index = 0;
	weighted_owner.relation_owner_byte2_0x4aa9b7_known = true;
	weighted_owner.relation_owner_byte2_0x4aa9b7 = 0;
	weighted_owner.terrain_policy_0x0c_known = true;
	weighted_owner.terrain_policy_0x0c = 0;
	weighted_owner.descriptor_type_counter_table_0x44_known = true;
	weighted_owner.descriptor_type_counter_table_0x44_zero_count = aurelion::h3maped_rmg_core::RELATION_OWNER_DESCRIPTOR_TABLE_0X44_DWORD_COUNT;
	weighted_owner.descriptor_type_counters_0x44.assign(size_t(aurelion::h3maped_rmg_core::RELATION_OWNER_DESCRIPTOR_TABLE_0X44_DWORD_COUNT), 0U);
	weighted_scan_state.relation_owner_vectors_10e4_10e8.push_back(weighted_owner);
	weighted_scan_state.relation_owner_vector_count_10e4_10e8 = 1;
	for (GeneratedCellRecord0x30 &record : weighted_scan_state.generated_cell_buffer.records) {
		record.object_reference_vector_contents_known = true;
		record.object_reference_count = 0;
		record.object_references_0x04_0x08.clear();
		record.word_0x20_known = true;
		record.word_0x20 = 0xff000064U;
		record.word_0x24_known = true;
		record.word_0x24 = 0x00000540U;
		record.word_0x28_known = true;
		record.word_0x28 = 0x12005000U;
		record.word_0x2c_known = true;
		record.word_0x2c = 0U;
	}
	aurelion::h3maped_rmg_core::H3MapedRng weighted_scan_rng;
	weighted_scan_rng.state = 10U;
	const auto weighted_scan_result =
			aurelion::h3maped_rmg_core::weighted_object_candidate_scan_0x4a901a(weighted_scan_state, weighted_join, 0, 107, 6, 108, 7, 0, 83, weighted_scan_rng);
	const int64_t weighted_scan_target_flat = aurelion::h3maped_rmg_core::cell_index(112, 112, 107, 6, 0);
	const GeneratedCellRecord0x30 &weighted_scan_target = weighted_scan_state.generated_cell_buffer.records[size_t(weighted_scan_target_flat)];
	if (!require(weighted_scan_result.committed
					&& weighted_scan_result.vector_state_0x4a901a.descriptor_source_bridge_known
					&& weighted_scan_result.vector_state_0x4a901a.scanned_cell_count == 1
					&& weighted_scan_result.vector_state_0x4a901a.accepted_candidate_count == 1
					&& weighted_scan_result.vector_state_0x4a901a.threshold_arg_0x18_after_scan == 100
					&& weighted_scan_result.vector_state_0x4a901a.local_vector_clear_count_0x4ae52a == 1
					&& weighted_scan_result.vector_state_0x4a901a.local_vector_append_count_0x4ae1fd == 1
					&& weighted_scan_result.vector_state_0x4a901a.selected_candidate_known
					&& weighted_scan_result.vector_state_0x4a901a.selected_candidate.x == 107
					&& weighted_scan_result.vector_state_0x4a901a.selected_candidate.y == 6
					&& weighted_scan_result.vector_state_0x4a901a.selected_candidate.level == 0
					&& weighted_scan_result.vector_state_0x4a901a.selected_candidate.low_word_score_0x20 == 100U,
				"0x4a901a weighted candidate scan did not reproduce recovered value-floor/local-vector selection")) {
		return 1;
	}
	if (!require(weighted_scan_result.allocated_record_0x4a93a2
					&& weighted_scan_result.weighted_record_0x4a93a2.object_record_key == 0x036b6d40U
					&& weighted_scan_result.weighted_record_0x4a93a2.sequence_0x1c == 5
					&& weighted_scan_state.object_record_sequence_allocator_0xf44 == 6
					&& weighted_scan_state.object_record_allocation_count_0x4a93a2 == 1
					&& weighted_scan_state.weighted_candidate_vector_count_0x4a901a == 1
					&& weighted_scan_state.weighted_candidate_total_count_0x4a901a == 1
					&& weighted_scan_state.weighted_candidate_selected_count_0x4a901a == 1
					&& weighted_scan_state.weighted_candidate_commit_count_0x4a901a == 1,
				"0x4a901a weighted candidate scan did not allocate/track the recovered 0x4a93a2 record path")) {
		return 1;
	}
	if (!require(weighted_scan_result.commit_0x4a93a2_0x4a901a_0x4a54a7.commit_0x4a54a7.object_vector_appended
					&& weighted_scan_result.commit_0x4a93a2_0x4a901a_0x4a54a7.commit_0x4a54a7.object_vector_count_after == 5
					&& weighted_scan_state.descriptor_counter_table_0x1110[size_t(98)] == 5U
					&& weighted_scan_target.object_reference_count == 1
					&& weighted_scan_target.object_references_0x04_0x08[0] == 0x036b6d40U,
				"0x4a901a weighted candidate scan did not dispatch through 0x4a54a7 into object-vector/reference/counter state")) {
		return 1;
	}
	GeneratorObjectPrivateState scheduler_success_state = weighted_scan_state;
	scheduler_success_state.object_records_0xec4_ecc.resize(4);
	scheduler_success_state.object_record_sequence_allocator_0xf44 = 5;
	scheduler_success_state.next_native_object_record_key_0x4a93a2 = 0x036b6d40U;
	scheduler_success_state.object_record_allocation_count_0x4a93a2 = 0;
	scheduler_success_state.weighted_candidate_vectors_0x4a901a.clear();
	scheduler_success_state.weighted_candidate_vector_count_0x4a901a = 0;
	scheduler_success_state.weighted_candidate_total_count_0x4a901a = 0;
	scheduler_success_state.weighted_candidate_selected_count_0x4a901a = 0;
	scheduler_success_state.weighted_candidate_commit_count_0x4a901a = 0;
	scheduler_success_state.source_order_scheduler_replays_0x4a8db2.clear();
	scheduler_success_state.source_order_scheduler_replay_count_0x4a8db2 = 0;
	scheduler_success_state.source_order_scheduler_direct_call_count_0x4a8db2 = 0;
	scheduler_success_state.source_order_scheduler_weighted_call_count_0x4a8db2 = 0;
	scheduler_success_state.source_order_scheduler_commit_count_0x4a8db2 = 0;
	scheduler_success_state.source_order_scheduler_blocked_count_0x4a8db2 = 0;
	scheduler_success_state.descriptor_counter_table_0x1110[size_t(98)] = 4U;
	for (GeneratedCellRecord0x30 &record : scheduler_success_state.generated_cell_buffer.records) {
		record.object_reference_count = 0;
		record.object_references_0x04_0x08.clear();
		record.word_0x20 = 0xff000064U;
		record.word_0x28 = 0x12005000U;
	}
	SourceObjectRecord0x4c scheduler_success_record = *dungeon_town;
	scheduler_success_record.raw_field_0x20_known = true;
	scheduler_success_record.raw_field_0x20 = 0;
	scheduler_success_record.raw_field_0x24_known = true;
	scheduler_success_record.raw_field_0x24 = 0;
	scheduler_success_record.raw_field_0x2c_known = true;
	scheduler_success_record.raw_field_0x2c = 9;
	scheduler_success_record.raw_field_0x28_known = true;
	scheduler_success_record.raw_field_0x28 = 0;
	scheduler_success_record.raw_field_0x38_known = true;
	scheduler_success_record.raw_field_0x38 = 0;
	SourceObjectDescriptorJoinResult4903e8 scheduler_success_join = weighted_join;
	scheduler_success_join.source_record_copy = scheduler_success_record;
	aurelion::h3maped_rmg_core::H3MapedRng scheduler_success_rng;
	scheduler_success_rng.state = 10U;
	const SourceOrderSchedulerResult4a8db2 scheduler_success =
			aurelion::h3maped_rmg_core::source_order_weighted_scheduler_0x4a8db2(
					scheduler_success_state,
					scheduler_success_join,
					make_scheduler_pair(scheduler_success_record),
					0,
					107,
					6,
					108,
					7,
					0,
					12,
					scheduler_success_rng,
					true,
					0,
					true,
					0,
					true,
					0);
	const int64_t scheduler_success_target_flat = aurelion::h3maped_rmg_core::cell_index(112, 112, 107, 6, 0);
	const GeneratedCellRecord0x30 &scheduler_success_target = scheduler_success_state.generated_cell_buffer.records[size_t(scheduler_success_target_flat)];
	if (!require(scheduler_success.replay_finished
					&& scheduler_success.threshold_arg_0x18_known
					&& scheduler_success.threshold_arg_0x18 == 96
					&& scheduler_success.weighted_call_count == 2
					&& scheduler_success.committed_call_count == 1
					&& scheduler_success.calls.size() == size_t(2)
					&& scheduler_success.calls[0].callsite == 0x4a8ffdU
					&& scheduler_success.calls[0].committed
					&& scheduler_success.calls[0].weighted_candidate_vector_index_0x4a901a == 0
					&& scheduler_success.calls[1].disabled_after_false
					&& scheduler_success_state.object_record_allocation_count_0x4a93a2 == 1
					&& scheduler_success_state.weighted_candidate_commit_count_0x4a901a == 1
					&& scheduler_success_state.source_order_scheduler_commit_count_0x4a8db2 == 1
					&& scheduler_success_state.object_records_0xec4_ecc.size() == size_t(5)
					&& scheduler_success_state.descriptor_counter_table_0x1110[size_t(98)] == 5U
					&& scheduler_success_target.object_reference_count == 1
					&& scheduler_success_target.object_references_0x04_0x08[0] == 0x036b6d40U,
				"0x4a8db2 scheduler replay did not drive 0x4a901a through allocation and 0x4a54a7 state mutation")) {
		return 1;
	}
	GeneratorObjectPrivateState scheduler_early_direct_state = scheduler_success_state;
	scheduler_early_direct_state.object_records_0xec4_ecc.resize(4);
	scheduler_early_direct_state.object_record_sequence_allocator_0xf44 = 5;
	scheduler_early_direct_state.next_native_object_record_key_0x4a93a2 = 0x036b6d40U;
	scheduler_early_direct_state.object_record_allocation_count_0x4a93a2 = 0;
	scheduler_early_direct_state.source_order_direct_candidate_vectors_0x4a93a2.clear();
	scheduler_early_direct_state.source_order_direct_candidate_vector_count_0x4a93a2 = 0;
	scheduler_early_direct_state.source_order_direct_candidate_total_count_0x4a93a2 = 0;
	scheduler_early_direct_state.source_order_direct_selected_count_0x4a93a2 = 0;
	scheduler_early_direct_state.source_order_direct_commit_count_0x4a93a2 = 0;
	scheduler_early_direct_state.weighted_candidate_vectors_0x4a901a.clear();
	scheduler_early_direct_state.weighted_candidate_vector_count_0x4a901a = 0;
	scheduler_early_direct_state.weighted_candidate_total_count_0x4a901a = 0;
	scheduler_early_direct_state.weighted_candidate_selected_count_0x4a901a = 0;
	scheduler_early_direct_state.weighted_candidate_commit_count_0x4a901a = 0;
	scheduler_early_direct_state.source_order_scheduler_replays_0x4a8db2.clear();
	scheduler_early_direct_state.source_order_scheduler_replay_count_0x4a8db2 = 0;
	scheduler_early_direct_state.source_order_scheduler_direct_call_count_0x4a8db2 = 0;
	scheduler_early_direct_state.source_order_scheduler_weighted_call_count_0x4a8db2 = 0;
	scheduler_early_direct_state.source_order_scheduler_commit_count_0x4a8db2 = 0;
	scheduler_early_direct_state.source_order_scheduler_blocked_count_0x4a8db2 = 0;
	scheduler_early_direct_state.descriptor_counter_table_0x1110[size_t(98)] = 4U;
	for (GeneratedCellRecord0x30 &record : scheduler_early_direct_state.generated_cell_buffer.records) {
		record.object_reference_count = 0;
		record.object_references_0x04_0x08.clear();
		record.word_0x20 = 0xff000064U;
		record.word_0x28 = 0x12005000U;
	}
	SourceObjectResolverSourcePair4af785 scheduler_early_direct_pair = make_scheduler_pair(scheduler_success_record);
	scheduler_early_direct_pair.source_pair_success_byte_0x3c_known = true;
	scheduler_early_direct_pair.source_pair_success_byte_0x3c = 0;
	scheduler_early_direct_pair.source_order_anchor_known = true;
	scheduler_early_direct_pair.source_order_anchor_x_0x10 = 107;
	scheduler_early_direct_pair.source_order_anchor_y_0x14 = 6;
	scheduler_early_direct_pair.source_order_anchor_level_0x18 = 0;
	aurelion::h3maped_rmg_core::H3MapedRng scheduler_early_direct_rng;
	scheduler_early_direct_rng.state = 10U;
	const SourceOrderSchedulerResult4a8db2 scheduler_early_direct =
			aurelion::h3maped_rmg_core::source_order_weighted_scheduler_0x4a8db2(
					scheduler_early_direct_state,
					scheduler_success_join,
					scheduler_early_direct_pair,
					0,
					107,
					6,
					108,
					7,
					0,
					12,
					scheduler_early_direct_rng,
					true,
					0,
					true,
					0,
					true,
					0);
	const int64_t scheduler_early_direct_target_flat = aurelion::h3maped_rmg_core::cell_index(112, 112, 107, 6, 0);
	const GeneratedCellRecord0x30 &scheduler_early_direct_target =
			scheduler_early_direct_state.generated_cell_buffer.records[size_t(scheduler_early_direct_target_flat)];
	if (!require(!scheduler_early_direct.calls.empty()
					&& scheduler_early_direct.calls[0].early_direct_0x4a901a
					&& scheduler_early_direct.calls[0].committed
					&& scheduler_early_direct.calls[0].source_pair_success_byte_0x3c_before == 0
					&& scheduler_early_direct.calls[0].source_pair_success_byte_0x3c_after == 1
					&& scheduler_early_direct.early_direct_call_count_0x4a901a == 1
					&& scheduler_early_direct.source_pair_success_byte_0x3c_final == 1
					&& scheduler_early_direct_state.source_order_direct_commit_count_0x4a93a2 == 1
					&& scheduler_early_direct_state.weighted_candidate_commit_count_0x4a901a == 0
					&& scheduler_early_direct_state.object_records_0xec4_ecc.size() == size_t(5)
					&& scheduler_early_direct_state.object_records_0xec4_ecc.back().source_order_direct_record_0x4a8d2c_0x4a93a2_known
					&& scheduler_early_direct_state.descriptor_counter_table_0x1110[size_t(98)] == 5U
					&& scheduler_early_direct_target.object_reference_count == 1
					&& scheduler_early_direct_target.object_references_0x04_0x08[0] == 0x036b6d40U,
				"0x4a901a did not take recovered early 0x4a93a2 direct-placement branch while source-pair +0x3c was zero")) {
		return 1;
	}
	GeneratorObjectPrivateState direct_placement_state;
	direct_placement_state.width = 112;
	direct_placement_state.height = 112;
	direct_placement_state.level_count = 1;
	direct_placement_state.generated_cell_buffer = aurelion::h3maped_rmg_core::generated_cell_record_grid_reset_0x49a072(112, 112, 1);
	direct_placement_state.generated_cell_buffer_owned = true;
	direct_placement_state.object_records_0xec4_ecc.resize(8);
	direct_placement_state.descriptor_counter_table_0x1110_present = true;
	direct_placement_state.descriptor_counter_table_0x1110_contents_known = true;
	direct_placement_state.descriptor_counter_table_0x1110_known_count = aurelion::h3maped_rmg_core::DESCRIPTOR_COUNTER_TABLE_0X1110_DWORD_COUNT;
	direct_placement_state.descriptor_counter_table_0x1110.assign(size_t(aurelion::h3maped_rmg_core::DESCRIPTOR_COUNTER_TABLE_0X1110_DWORD_COUNT), 0U);
	direct_placement_state.descriptor_counter_table_0x1110[size_t(98)] = 8U;
	direct_placement_state.object_record_sequence_allocator_0xf44_present = true;
	direct_placement_state.object_record_sequence_allocator_0xf44_known = true;
	direct_placement_state.object_record_sequence_allocator_0xf44 = 9;
	direct_placement_state.native_object_record_key_allocator_0x4a93a2_known = true;
	direct_placement_state.next_native_object_record_key_0x4a93a2 = 0x036b6d50U;
	GeneratorRelationOwnerState4a218c direct_owner;
	direct_owner.runtime_zone_index = 0;
	direct_owner.owner_vector_index = 0;
	direct_owner.relation_owner_byte2_0x4aa9b7_known = true;
	direct_owner.relation_owner_byte2_0x4aa9b7 = 0;
	direct_owner.terrain_policy_0x0c_known = true;
	direct_owner.terrain_policy_0x0c = 0;
	direct_owner.descriptor_type_counter_table_0x44_known = true;
	direct_owner.descriptor_type_counter_table_0x44_zero_count = aurelion::h3maped_rmg_core::RELATION_OWNER_DESCRIPTOR_TABLE_0X44_DWORD_COUNT;
	direct_owner.descriptor_type_counters_0x44.assign(size_t(aurelion::h3maped_rmg_core::RELATION_OWNER_DESCRIPTOR_TABLE_0X44_DWORD_COUNT), 0U);
	direct_placement_state.relation_owner_vectors_10e4_10e8.push_back(direct_owner);
	direct_placement_state.relation_owner_vector_count_10e4_10e8 = 1;
	for (GeneratedCellRecord0x30 &record : direct_placement_state.generated_cell_buffer.records) {
		record.object_reference_vector_contents_known = true;
		record.object_reference_count = 0;
		record.object_references_0x04_0x08.clear();
		record.word_0x20_known = true;
		record.word_0x20 = 0xff000064U;
		record.word_0x24_known = true;
		record.word_0x24 = 0x00000540U;
		record.word_0x28_known = true;
		record.word_0x28 = 0x12005000U;
		record.word_0x2c_known = true;
		record.word_0x2c = 0U;
	}
	aurelion::h3maped_rmg_core::H3MapedRng direct_placement_rng;
	direct_placement_rng.state = 10U;
	const auto direct_placement =
			aurelion::h3maped_rmg_core::source_order_object_placement_0x4a93a2(
					direct_placement_state,
					weighted_join,
					0,
					107,
					6,
					0,
					107,
					6,
					108,
					7,
					77,
					12,
					true,
					direct_placement_rng);
	const int64_t direct_target_flat = aurelion::h3maped_rmg_core::cell_index(112, 112, 107, 6, 0);
	const GeneratedCellRecord0x30 &direct_target = direct_placement_state.generated_cell_buffer.records[size_t(direct_target_flat)];
	if (!require(direct_placement.committed
					&& direct_placement.placement_state_0x4a93a2.scanned_cell_count == 1
					&& direct_placement.placement_state_0x4a93a2.accepted_candidate_count == 1
					&& direct_placement.placement_state_0x4a93a2.best_distance_squared_after_scan == 0
					&& direct_placement.placement_state_0x4a93a2.local_vector_clear_count_0x4ae52a == 1
					&& direct_placement.placement_state_0x4a93a2.local_vector_append_count_0x4ae1fd == 1
					&& direct_placement.placement_state_0x4a93a2.source_pair_success_byte_0x3c_set
					&& direct_placement.object_record_0x4a93a2.object_record_key == 0x036b6d50U
					&& direct_placement.object_record_0x4a93a2.sequence_0x1c == 9
					&& direct_placement.object_record_0x4a93a2.selected_index_0x20 == 12
					&& direct_placement.object_record_0x4a93a2.enabled_low_byte_0x24,
				"0x4a93a2 direct source-order placement did not reproduce nearest-distance allocation metadata")) {
		return 1;
	}
	if (!require(direct_placement_state.source_order_direct_candidate_vector_count_0x4a93a2 == 1
					&& direct_placement_state.source_order_direct_candidate_total_count_0x4a93a2 == 1
					&& direct_placement_state.source_order_direct_selected_count_0x4a93a2 == 1
					&& direct_placement_state.source_order_direct_commit_count_0x4a93a2 == 1
					&& direct_placement_state.object_records_0xec4_ecc.back().source_order_direct_record_0x4a8d2c_0x4a93a2_known
					&& !direct_placement_state.object_records_0xec4_ecc.back().weighted_record_0x4a93a2_known
					&& direct_placement_state.descriptor_counter_table_0x1110[size_t(98)] == 9U
					&& direct_target.object_reference_count == 1
					&& direct_target.object_references_0x04_0x08[0] == 0x036b6d50U,
				"0x4a93a2 direct source-order placement did not feed object-vector/reference/counter state")) {
		return 1;
	}
	GeneratorObjectPrivateState direct_dispatch_state = direct_placement_state;
	direct_dispatch_state.object_records_0xec4_ecc.resize(8);
	direct_dispatch_state.object_record_sequence_allocator_0xf44 = 9;
	direct_dispatch_state.next_native_object_record_key_0x4a93a2 = 0x036b6d50U;
	direct_dispatch_state.object_record_allocation_count_0x4a93a2 = 0;
	direct_dispatch_state.source_order_direct_candidate_vectors_0x4a93a2.clear();
	direct_dispatch_state.source_order_direct_candidate_vector_count_0x4a93a2 = 0;
	direct_dispatch_state.source_order_direct_candidate_total_count_0x4a93a2 = 0;
	direct_dispatch_state.source_order_direct_selected_count_0x4a93a2 = 0;
	direct_dispatch_state.source_order_direct_commit_count_0x4a93a2 = 0;
	direct_dispatch_state.descriptor_counter_table_0x1110[size_t(98)] = 8U;
	for (GeneratedCellRecord0x30 &record : direct_dispatch_state.generated_cell_buffer.records) {
		record.object_reference_count = 0;
		record.object_references_0x04_0x08.clear();
		record.word_0x20 = 0xff000064U;
		record.word_0x28 = 0x12005000U;
	}
	aurelion::h3maped_rmg_core::H3MapedRng direct_dispatch_rng;
	direct_dispatch_rng.state = 10U;
	const auto direct_dispatch =
			aurelion::h3maped_rmg_core::source_order_object_dispatcher_0x4a8d2c(
					direct_dispatch_state,
					weighted_join,
					0,
					107,
					6,
					0,
					107,
					6,
					108,
					7,
					77,
					12,
					direct_dispatch_rng);
	if (!require(direct_dispatch.committed
					&& direct_dispatch.source_field_0x20_known
					&& direct_dispatch.source_field_0x20 == dungeon_town->raw_field_0x20
					&& direct_dispatch.source_field_0x24_known
					&& direct_dispatch.source_field_0x24 == dungeon_town->raw_field_0x24
					&& !direct_dispatch.source_field_0x30_known
					&& !direct_dispatch.source_field_0x34_known
					&& direct_dispatch.selected_branch_index == 0
					&& direct_dispatch.attempted_branch_count == 1
					&& direct_dispatch.branches.size() == size_t(4)
					&& direct_dispatch.branches[0].source_field_offset == 0x24
					&& direct_dispatch.branches[0].branch_gate_positive
					&& direct_dispatch.branches[0].placement_0x4a93a2.committed
					&& direct_dispatch.branches[0].placement_0x4a93a2.object_record_0x4a93a2.selected_index_0x20 == 12
					&& direct_dispatch.branches[0].placement_0x4a93a2.object_record_0x4a93a2.enabled_low_byte_0x24,
				"0x4a8d2c dispatcher did not try recovered +0x24 branch before +0x20/+0x34/+0x30")) {
		return 1;
	}
	SourceObjectDescriptorJoinResult4903e8 descriptor_width_not_raw_join = weighted_join;
	descriptor_width_not_raw_join.source_record_copy.raw_field_0x20_known = true;
	descriptor_width_not_raw_join.source_record_copy.raw_field_0x20 = 0;
	descriptor_width_not_raw_join.source_record_copy.raw_field_0x24_known = true;
	descriptor_width_not_raw_join.source_record_copy.raw_field_0x24 = 0;
	descriptor_width_not_raw_join.source_record_copy.raw_field_0x30_known = false;
	descriptor_width_not_raw_join.source_record_copy.raw_field_0x30 = 0;
	descriptor_width_not_raw_join.source_record_copy.raw_field_0x34_known = false;
	descriptor_width_not_raw_join.source_record_copy.raw_field_0x34 = 0;
	descriptor_width_not_raw_join.source_record_copy.descriptor_width_0x34 = 6;
	GeneratorObjectPrivateState descriptor_width_dispatch_state = direct_dispatch_state;
	descriptor_width_dispatch_state.object_records_0xec4_ecc.resize(8);
	descriptor_width_dispatch_state.object_record_sequence_allocator_0xf44 = 9;
	descriptor_width_dispatch_state.next_native_object_record_key_0x4a93a2 = 0x036b6d50U;
	descriptor_width_dispatch_state.object_record_allocation_count_0x4a93a2 = 0;
	descriptor_width_dispatch_state.source_order_direct_candidate_vectors_0x4a93a2.clear();
	descriptor_width_dispatch_state.source_order_direct_candidate_vector_count_0x4a93a2 = 0;
	descriptor_width_dispatch_state.source_order_direct_candidate_total_count_0x4a93a2 = 0;
	descriptor_width_dispatch_state.source_order_direct_selected_count_0x4a93a2 = 0;
	descriptor_width_dispatch_state.source_order_direct_commit_count_0x4a93a2 = 0;
	aurelion::h3maped_rmg_core::H3MapedRng descriptor_width_dispatch_rng;
	descriptor_width_dispatch_rng.state = 10U;
	const auto descriptor_width_dispatch =
			aurelion::h3maped_rmg_core::source_order_object_dispatcher_0x4a8d2c(
					descriptor_width_dispatch_state,
					descriptor_width_not_raw_join,
					0,
					107,
					6,
					0,
					107,
					6,
					108,
					7,
					77,
					12,
					descriptor_width_dispatch_rng);
	if (!require(!descriptor_width_dispatch.committed
					&& descriptor_width_dispatch.attempted_branch_count == 0
					&& descriptor_width_dispatch.blocked_reason == "0x4a8d2c_no_positive_source_field_branch"
					&& descriptor_width_dispatch.branches.size() == size_t(4)
					&& !descriptor_width_dispatch.branches[2].source_field_known
					&& descriptor_width_dispatch.branches[2].source_field_offset == 0x34
					&& descriptor_width_dispatch.branches[2].blocked_reason == "0x4a8d2c_source_field_unrepresented_in_native_source_record"
					&& descriptor_width_dispatch_state.object_record_allocation_count_0x4a93a2 == 0,
				"0x4a8d2c dispatcher treated descriptor width +0x34 as copied source-record raw +0x34")) {
		return 1;
	}
	GeneratorObjectPrivateState direct_minus_one_state = direct_dispatch_state;
	direct_minus_one_state.object_records_0xec4_ecc.resize(8);
	direct_minus_one_state.object_record_sequence_allocator_0xf44 = 9;
	direct_minus_one_state.next_native_object_record_key_0x4a93a2 = 0x036b6d50U;
	direct_minus_one_state.object_record_allocation_count_0x4a93a2 = 0;
	direct_minus_one_state.source_order_direct_candidate_vectors_0x4a93a2.clear();
	direct_minus_one_state.source_order_direct_candidate_vector_count_0x4a93a2 = 0;
	direct_minus_one_state.source_order_direct_candidate_total_count_0x4a93a2 = 0;
	direct_minus_one_state.source_order_direct_selected_count_0x4a93a2 = 0;
	direct_minus_one_state.source_order_direct_commit_count_0x4a93a2 = 0;
	aurelion::h3maped_rmg_core::H3MapedRng direct_minus_one_rng;
	direct_minus_one_rng.state = 10U;
	const auto direct_minus_one =
			aurelion::h3maped_rmg_core::source_order_object_placement_0x4a93a2(
					direct_minus_one_state,
					weighted_join,
					0,
					107,
					6,
					0,
					107,
					6,
					108,
					7,
					-1,
					12,
					true,
					direct_minus_one_rng);
	if (!require(!direct_minus_one.committed
					&& direct_minus_one.blocked_reason == "0x4a93a2_source_pair_key_arg_0x0c_minus_one"
					&& direct_minus_one_state.object_record_allocation_count_0x4a93a2 == 0,
				"0x4a93a2 direct source-order placement did not fail closed on recovered arg2 -1 gate")) {
		return 1;
	}
	GeneratorObjectPrivateState weighted_scan_reject_state = weighted_scan_state;
	weighted_scan_reject_state.object_records_0xec4_ecc.resize(4);
	weighted_scan_reject_state.object_record_sequence_allocator_0xf44 = 5;
	weighted_scan_reject_state.next_native_object_record_key_0x4a93a2 = 0x036b6d40U;
	weighted_scan_reject_state.object_record_allocation_count_0x4a93a2 = 0;
	weighted_scan_reject_state.weighted_candidate_vectors_0x4a901a.clear();
	weighted_scan_reject_state.weighted_candidate_vector_count_0x4a901a = 0;
	weighted_scan_reject_state.weighted_candidate_total_count_0x4a901a = 0;
	weighted_scan_reject_state.weighted_candidate_selected_count_0x4a901a = 0;
	weighted_scan_reject_state.weighted_candidate_commit_count_0x4a901a = 0;
	weighted_scan_reject_state.descriptor_counter_table_0x1110[size_t(98)] = 4U;
	for (GeneratedCellRecord0x30 &record : weighted_scan_reject_state.generated_cell_buffer.records) {
		record.object_reference_count = 0;
		record.object_references_0x04_0x08.clear();
		record.word_0x20 = 0xff000064U;
		record.word_0x28 = 0x12005000U;
	}
	aurelion::h3maped_rmg_core::H3MapedRng weighted_scan_reject_rng;
	weighted_scan_reject_rng.state = 10U;
	const auto weighted_scan_reject =
			aurelion::h3maped_rmg_core::weighted_object_candidate_scan_0x4a901a(weighted_scan_reject_state, weighted_join, 0, 107, 6, 108, 7, 0, 101, weighted_scan_reject_rng);
	if (!require(!weighted_scan_reject.committed
					&& weighted_scan_reject.blocked_reason == "0x4a901a_weighted_candidate_vector_empty_after_value_floor_and_0x49aa93_filters"
					&& weighted_scan_reject.vector_state_0x4a901a.value_floor_reject_count == 1
					&& weighted_scan_reject_state.object_record_allocation_count_0x4a93a2 == 0
					&& weighted_scan_reject_state.object_records_0xec4_ecc.size() == 4
					&& weighted_scan_reject_state.descriptor_counter_table_0x1110[size_t(98)] == 4U,
				"0x4a901a weighted candidate scan did not fail closed before allocation when value floor rejects all candidates")) {
		return 1;
	}
	GeneratorObjectPrivateState weighted_commit_state;
	weighted_commit_state.width = 112;
	weighted_commit_state.height = 112;
	weighted_commit_state.level_count = 1;
	weighted_commit_state.generated_cell_buffer = aurelion::h3maped_rmg_core::generated_cell_record_grid_reset_0x49a072(112, 112, 1);
	weighted_commit_state.generated_cell_buffer_owned = true;
	weighted_commit_state.object_records_0xec4_ecc.resize(4);
	weighted_commit_state.descriptor_counter_table_0x1110_present = true;
	weighted_commit_state.descriptor_counter_table_0x1110_contents_known = true;
	weighted_commit_state.descriptor_counter_table_0x1110_known_count = aurelion::h3maped_rmg_core::DESCRIPTOR_COUNTER_TABLE_0X1110_DWORD_COUNT;
	weighted_commit_state.descriptor_counter_table_0x1110.assign(size_t(aurelion::h3maped_rmg_core::DESCRIPTOR_COUNTER_TABLE_0X1110_DWORD_COUNT), 0U);
	weighted_commit_state.descriptor_counter_table_0x1110[size_t(98)] = 4U;
	weighted_commit_state.object_record_sequence_allocator_0xf44_present = true;
	weighted_commit_state.object_record_sequence_allocator_0xf44_known = true;
	weighted_commit_state.object_record_sequence_allocator_0xf44 = 5;
	weighted_commit_state.native_object_record_key_allocator_0x4a93a2_known = true;
	weighted_commit_state.next_native_object_record_key_0x4a93a2 = 0x036b6d40U;
	weighted_commit_state.source_object_resolver_state_4af785_known = true;
	weighted_commit_state.source_object_resolver_state_4af785 = weighted_resolver_state;
	weighted_commit_state.source_pair_vector_edc.present = true;
	weighted_commit_state.source_pair_vector_edc.contents_known = true;
	weighted_commit_state.source_pair_vector_edc.count_known = true;
	weighted_commit_state.source_pair_vector_edc.count =
			int32_t(weighted_resolver_state.source_pairs_0xedc.size());
	weighted_commit_state.source_pair_vector_edc.element_size_bytes = 8;
	weighted_commit_state.source_pair_records_edc = weighted_resolver_state.source_pairs_0xedc;
	for (GeneratedCellRecord0x30 &record : weighted_commit_state.generated_cell_buffer.records) {
		record.object_reference_vector_contents_known = true;
		record.object_reference_count = 0;
		record.object_references_0x04_0x08.clear();
		record.word_0x20_known = true;
		record.word_0x20 = 0xff000064U;
		record.word_0x28_known = true;
		record.word_0x28 = 0x12005000U;
	}
	const WeightedObjectRecord4a93a2 weighted_record =
			aurelion::h3maped_rmg_core::allocate_weighted_object_record_0x4a93a2(weighted_commit_state, 107, 6, 0, -1, 0U, false);
	if (!require(weighted_record.object_record_key_known
					&& weighted_record.object_record_key_allocated_by_0x4a93a2
					&& weighted_record.object_record_key == 0x036b6d40U
					&& weighted_record.sequence_0x1c == 5
					&& weighted_commit_state.object_record_sequence_allocator_0xf44 == 6
					&& weighted_commit_state.next_native_object_record_key_0x4a93a2 == 0x036b6d41U
					&& weighted_commit_state.object_record_allocation_count_0x4a93a2 == 1,
				"weighted 0x4a93a2 allocator did not materialize source-order record key and +0xf44 sequence state")) {
		return 1;
	}
	const auto weighted_commit =
			aurelion::h3maped_rmg_core::object_materialization_commit_from_weighted_record_0x4a93a2_0x4a901a_0x4a54a7(weighted_commit_state, weighted_join, weighted_record);
	const int64_t weighted_target_flat = aurelion::h3maped_rmg_core::cell_index(112, 112, 107, 6, 0);
	const int64_t weighted_source_flat = aurelion::h3maped_rmg_core::cell_index(112, 112, 105, 6, 0);
	const GeneratedCellRecord0x30 &weighted_target = weighted_commit_state.generated_cell_buffer.records[size_t(weighted_target_flat)];
	const GeneratedCellRecord0x30 &weighted_source = weighted_commit_state.generated_cell_buffer.records[size_t(weighted_source_flat)];
	if (!require(weighted_commit.committed
					&& weighted_commit.record_vtable_0x540a9c
					&& weighted_commit.record_coordinate_payload_filled
					&& weighted_commit.prep_0x4a901a.weighted_type98_descriptor_bridge_0x4a93a2_known,
				"weighted 0x4a93a2 materialization did not accept the recovered type-98 source-backed bridge")) {
		return 1;
	}
	if (!require(weighted_commit.commit_0x4a54a7.object_vector_appended
					&& weighted_commit.commit_0x4a54a7.object_vector_count_after == 5
					&& weighted_commit.commit_0x4a54a7.resolver_wrapper_reference_incremented_0x08
					&& weighted_commit.commit_0x4a54a7.descriptor_counter_incremented
					&& weighted_commit_state.descriptor_counter_table_0x1110[size_t(98)] == 5U,
				"weighted 0x4a93a2 materialization did not reproduce the recovered object-vector/counter transition")) {
		return 1;
	}
	const auto &weighted_object_record = weighted_commit_state.object_records_0xec4_ecc.back();
	if (!require(weighted_object_record.weighted_record_0x4a93a2_known
					&& weighted_object_record.object_record_key_allocated_by_0x4a93a2
					&& weighted_object_record.weighted_type98_descriptor_bridge_0x4a93a2_known
					&& !weighted_object_record.source_descriptor_join_0x4903e8_known
					&& weighted_object_record.object_record_key == 0x036b6d40U
					&& weighted_object_record.object_record_sequence_0x1c == 5
					&& weighted_object_record.source_catalog_index_0x49da08 == weighted_join.source_catalog_index_0x49da08
					&& weighted_object_record.selected_wrapper_index_0x4af785 == weighted_join.resolver_0x4af785.selected_wrapper_index
					&& weighted_object_record.selected_wrapper_index_0x4af785 >= 0
					&& weighted_object_record.source_record_copy.def_name == dungeon_town->def_name,
				"weighted 0x4a93a2 object record did not carry recovered record metadata and source identity")) {
		return 1;
	}
	const auto weighted_wrapper = std::find_if(
			weighted_commit_state.source_object_resolver_state_4af785.wrappers.begin(),
			weighted_commit_state.source_object_resolver_state_4af785.wrappers.end(),
			[&](const auto &wrapper) {
				return wrapper.wrapper_index == weighted_join.resolver_0x4af785.selected_wrapper_index;
			});
	if (!require(weighted_wrapper != weighted_commit_state.source_object_resolver_state_4af785.wrappers.end()
					&& weighted_wrapper->reference_count_0x08_known
					&& weighted_wrapper->reference_count_0x08 == 1,
				"weighted 0x4a93a2 commit did not increment the carried 0x4af785 wrapper reference count")) {
		return 1;
	}
	if (!require(weighted_commit.commit_0x4a54a7.generated_cell_reference_appended
					&& weighted_target.object_reference_count == 1
					&& weighted_target.object_references_0x04_0x08[0] == 0x036b6d40U
					&& (weighted_source.word_0x20 & 0xffffU) == 0U
					&& (weighted_target.word_0x20 & 0xffffU) < 100U,
				"weighted 0x4a93a2 materialization did not feed target object-reference and descriptor-offset projection mutations")) {
		return 1;
	}
	if (!require(composed.owner_grid.missing_boundary_input_count == 0 && composed.owner_grid.missing_source_walk_count == 0, "coordinate-to-owner-grid chain lost boundary/source inputs")) {
		return 1;
	}
	if (!require(composed.owner_grid.materialization.source_handoff_count == int32_t(composed.owner_grid.handoffs.size()), "coordinate-to-owner-grid materializer did not consume every source handoff")) {
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
	if (!require(composed.owner_grid.footprint_finalizer.generator_mode_0x10b8 == 0
					&& composed.owner_grid.footprint_finalizer.caller_level_argument_0x0c == 0
					&& !composed.owner_grid.footprint_finalizer.synthetic_branch_allowed_by_0x4a3a9d,
				"mode-0 coordinate-to-owner-grid chain should not enter the recovered 0x4a3a9d synthetic append branch")) {
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
	if (!require(composed_mode2.owner_grid.footprint_finalizer_executed
					&& composed_mode2.owner_grid.footprint_finalizer.synthetic_branch_allowed_by_0x4a3a9d,
				"mode-2 coordinate-to-owner-grid chain did not execute the recovered 0x4a3a9d synthetic branch gate")) {
		return 1;
	}
	if (composed_mode2.owner_grid.footprint_finalizer.appended_runtime_zone_count > 0) {
		if (!require(!composed_mode2.owner_grid.footprint_finalizer.blocked
						&& composed_mode2.owner_grid.footprint_finalizer.relation_order_vectors_materialized,
					"mode-2 appended synthetic owners should materialize recovered 0x4a3710 adjacency/order when relation-owner state is available")) {
			return 1;
		}
	} else if (!require(!composed_mode2.owner_grid.footprint_finalizer.blocked
					&& composed_mode2.owner_grid.footprint_finalizer.status == "0x4a3710_synthetic_runtime_zone_scan_executed_without_append",
				"mode-2 synthetic branch with no appended owner should not report an unported append path")) {
		return 1;
	}
	{
		H3MapedRmgWorkflowConfig workflow_config;
		workflow_config.size_class = "small";
		workflow_config.water_mode = "land";
		workflow_config.width = 36;
		workflow_config.height = 36;
		workflow_config.level_count = 1;
		workflow_config.human_count = 1;
		workflow_config.player_count = 2;
		workflow_config.seed = 58U;
		workflow_config.setup_object_0x44_known = true;
		workflow_config.setup_object_0x44 = 3;
		workflow_config.setup_object_raw_0x48_known = true;
		workflow_config.setup_object_raw_0x48 = 0;
		workflow_config.setup_object_0x48_known = false;
		workflow_config.setup_object_0x48 = 0;
		const H3MapedRmgWorkflowResult workflow =
				aurelion::h3maped_rmg_core::run_h3maped_rmg_entry_to_writeout_workflow(workflow_config);
		const std::string workflow_final_payload_compare_blocker =
				"same_run_payload_authority_missing_recovered_profile_metadata";
		if (!require(workflow.supported_scope
						&& workflow.executed
						&& workflow.status == "blocked"
						&& workflow.current_phase_id == "final_payload_compare"
						&& workflow.final_payload_owned
						&& workflow.final_writeout_complete
						&& workflow.final_payload_writeout_0x4ad1e3.applied,
					"entry-to-writeout workflow did not continue through final payload assembly")) {
			return 1;
		}
		if (!require(workflow.blocked_reason == workflow_final_payload_compare_blocker,
					std::string("entry-to-writeout workflow did not fail closed at final payload compare; actual=")
							+ workflow.blocked_reason)) {
			return 1;
		}
			if (!require(workflow.phases.size() >= 22
							&& workflow.phases[0].id == "entry_scope"
							&& workflow.phases[1].id == "setup_template_selection"
							&& workflow.phases[2].id == "coordinate_boundary_terrain"
							&& workflow.phases[3].id == "generator_object_private_state"
							&& workflow.phases[4].id == "generic_non_type98_source_order_pairs"
							&& workflow.phases[4].status == "complete_source_order_prefix"
							&& workflow.phases[5].id == "source_order_object_materialization"
							&& workflow.phases[5].status == "complete_source_order_prefix"
							&& workflow.phases[6].id == "route_free_cell_sweep"
							&& workflow.phases[6].status == "complete_source_order_prefix"
							&& workflow.phases[7].id == "relation_source_order_scan"
							&& workflow.phases[7].status == "complete_source_order_prefix"
							&& workflow.phases[11].id == "reward_guard_materialization"
							&& workflow.phases[11].status == "complete_source_order_prefix"
							&& workflow.phases[12].id == "connection_road_river"
							&& workflow.phases[12].status == "complete_source_order_prefix"
							&& workflow.phases[13].id == "road_river_object_adjacency"
							&& workflow.phases[13].status == "complete_source_order_prefix"
							&& workflow.phases[15].id == "final_writeout"
							&& workflow.phases[15].status == "complete_source_order_prefix"
							&& workflow.phases[21].id == "full_final_payload_same_run_compare"
							&& workflow.phases[21].status == "blocked",
					"entry-to-writeout workflow did not preserve recovered phase order through final payload compare")) {
				return 1;
			}
		if (!require(workflow.setup_mode_0x49ecf2.generator_mode_0x10b8 == 0
						&& workflow.template_selection_0x4ac552.accepted_template_count > 0
						&& !workflow.template_selection_0x4ac552.runtime_seed.runtime_zone_seeds.empty()
						&& workflow.coordinate_owner_grid_0x4a218c.owner_grid_executed
						&& workflow.generator_object_private_state.generated_cell_buffer_owned
						&& workflow.generator_object_private_state.source_order_relation_pointer_loop_0x4ac552_ported
						&& workflow.generator_object_private_state.source_order_relation_pointer_loop_0x4ac552_input_known
						&& workflow.generator_object_private_state.source_order_relation_pointer_loop_0x4ac552_applied
						&& workflow.generator_object_private_state.route_container_free_cell_sweep_0x4a8260_applied
						&& workflow.generator_object_private_state.materialization_bridge_post_4a4c8e_cleanup_0x4a8c15_ported
						&& workflow.generator_object_private_state.materialization_bridge_post_4a4c8e_cleanup_0x4a8c15_input_known
						&& workflow.generator_object_private_state.materialization_bridge_post_4a4c8e_cleanup_0x4a8c15_applied
						&& workflow.generator_object_private_state.materialization_bridge_relation_loop_0x4a4913_ported
						&& workflow.generator_object_private_state.materialization_bridge_relation_loop_0x4a4913_input_known
						&& workflow.generator_object_private_state.materialization_bridge_relation_loop_0x4a4913_applied
							&& workflow.generator_object_private_state.relation_normalization_4a5767_full_grid_reset_applied
							&& workflow.generator_object_private_state.relation_scan_consumers_4a5767_applied
							&& workflow.generator_object_private_state.relation_high_owner_propagation_49a318_applied
							&& workflow.generator_object_private_state.materialization_bridge_water_edge_writer_0x4a4fc5_ported
							&& workflow.generator_object_private_state.materialization_bridge_water_edge_writer_0x4a4fc5_input_known
							&& workflow.generator_object_private_state.materialization_bridge_water_edge_writer_0x4a4fc5_applied
							&& workflow.generator_object_private_state.materialization_bridge_water_edge_writer_0x4a4fc5_source_backed_land_scope
							&& workflow.generator_object_private_state.materialization_bridge_water_edge_writer_scan_count_0x4a4fc5 == 36 * 36
							&& workflow.generator_object_private_state.materialization_bridge_water_edge_writer_bit26_candidate_count_0x4a4fc5 == 0
							&& workflow.generator_object_private_state.relation_source_order_scan_0x4a89da_ported
							&& workflow.generator_object_private_state.relation_source_order_scan_0x4a89da_prefix_applied
							&& workflow.generator_object_private_state.relation_source_order_scan_0x4a89da_helper_chain_complete
							&& workflow.generator_object_private_state.relation_source_order_scan_0x4a89da.invoked
							&& workflow.generator_object_private_state.mine_resource_materialization_0x4a9d6a.invoked
							&& workflow.generator_object_private_state.reward_guard_source_stream_0x4aab7e.invoked
							&& workflow.generator_object_private_state.reward_guard_source_stream_0x4aab7e.applied
							&& workflow.generator_object_private_state.reward_guard_source_stream_0x4aab7e.blocked_reason.empty()
							&& workflow.generator_object_private_state.reward_guard_source_stream_0x4aab7e.materialization_attempt_count > 0
							&& workflow.generator_object_private_state.reward_guard_source_stream_0x4aab7e.successful_coordinate_scan_count > 0
							&& workflow.generator_object_private_state.decorative_flagged_cell_dispatch_0x49eb8d.invoked
							&& workflow.generator_object_private_state.connection_tail_replay_0x4a79a3.invoked
							&& workflow.generator_object_private_state.road_river_object_adjacency_0x4ab52a.invoked,
						"entry-to-writeout workflow did not carry 0x4a89da/0x4a8bfc relation scan through source-backed reward/guard into downstream phases")) {
			return 1;
		}
		const GeneratorObjectPrivateState &workflow_generator_state = workflow.generator_object_private_state;
		if (!require(workflow_generator_state.descriptor_vector_398_39c.present
						&& workflow_generator_state.descriptor_vector_398_39c.contents_known
						&& workflow_generator_state.descriptor_vector_398_39c.count_known
						&& workflow_generator_state.descriptor_vector_398_39c.count == 1328
						&& workflow_generator_state.descriptor_vector_398_39c_source_owned
						&& workflow_generator_state.descriptor_vector_entry_count_398_39c == 1328
						&& workflow_generator_state.descriptor_vector_entries_398_39c.size() == size_t(1328)
						&& workflow_generator_state.descriptor_vector_entries_398_39c.front().vector_index == 0
						&& workflow_generator_state.descriptor_vector_entries_398_39c.back().vector_index == 1327,
					"entry-to-writeout workflow did not materialize recovered generator descriptor vector +0x398/+0x39c before 0x4a5c07")) {
			return 1;
		}
		if (!require(workflow_generator_state.mine_resource_descriptor_vector_388_38c.present
						&& workflow_generator_state.mine_resource_descriptor_vector_388_38c.contents_known
						&& workflow_generator_state.mine_resource_descriptor_vector_388_38c.count_known
						&& workflow_generator_state.mine_resource_descriptor_vector_388_38c.count > 0
						&& workflow_generator_state.mine_resource_descriptor_vector_388_38c_source_owned
						&& workflow_generator_state.mine_resource_descriptor_vector_entry_count_388_38c == int32_t(workflow_generator_state.mine_resource_descriptor_vector_entries_388_38c.size())
						&& workflow_generator_state.mine_resource_descriptor_vector_entries_388_38c.front().vector_index == 0
						&& workflow_generator_state.mine_resource_descriptor_vector_entries_388_38c.back().vector_index == workflow_generator_state.mine_resource_descriptor_vector_entry_count_388_38c - 1,
					"entry-to-writeout workflow did not materialize recovered generator mine/resource descriptor bucket +0x388/+0x38c before 0x4a9911")) {
			return 1;
		}
		if (!require(workflow_generator_state.reward_guard_candidate_vector_10f4_10f8.present
						&& workflow_generator_state.reward_guard_candidate_vector_10f4_10f8.contents_known
						&& workflow_generator_state.reward_guard_candidate_vector_10f4_10f8.count_known
						&& workflow_generator_state.reward_guard_candidate_vector_10f4_10f8.count == 704
						&& workflow_generator_state.reward_guard_candidate_records_10f4_10f8_contents_known
						&& workflow_generator_state.reward_guard_candidate_record_count_10f4_10f8 == 704
						&& workflow_generator_state.reward_guard_candidate_records_10f4_10f8.size() == size_t(704),
					"entry-to-writeout workflow did not materialize the recovered 704-record 0x49f95a reward/guard candidate vector before 0x4a9f1c")) {
			return 1;
		}
		if (!require(workflow_generator_state.source_order_relation_pointer_loop_relation_count_0x10e4 > 0
						&& workflow_generator_state.source_order_relation_pointer_loop_source_record_field_0x04_known_count > 0
						&& workflow_generator_state.source_order_relation_pointer_loop_missing_context_wrapper_0x04_count == 0
						&& workflow_generator_state.source_order_relation_pointer_loop_direct_replay_count_0x4a8d2c > 0
						&& workflow_generator_state.source_order_relation_pointer_loop_scheduler_replay_count_0x4a8db2 > 0
						&& workflow.current_phase_id == "final_payload_compare",
					"entry-to-writeout workflow did not replay 0x4ac552 source records through final payload compare")) {
			return 1;
		}
		bool type98_scheduler_context_replayed_from_source_pair = false;
		for (const SourceOrderSchedulerResult4a8db2 &replay : workflow_generator_state.source_order_scheduler_replays_0x4a8db2) {
			if (!replay.context_pointer_carried
					|| replay.source_pair_copied_source_catalog_index < 0
					|| replay.context_wrapper_index_0x04 < 0) {
				continue;
			}
			for (const SourceObjectResolverSourcePair4af785 &pair : workflow_generator_state.source_pair_records_edc) {
				if (pair.source_record_copy.type_id_0x1c == 98
						&& pair.source_record_pointer_0x00_carried
						&& pair.context_pointer_0x04_carried
						&& pair.copied_source_catalog_index == replay.source_pair_copied_source_catalog_index
						&& pair.context_wrapper_index_0x04 == replay.context_wrapper_index_0x04) {
					type98_scheduler_context_replayed_from_source_pair = true;
					break;
				}
			}
			if (type98_scheduler_context_replayed_from_source_pair) {
				break;
			}
		}
		if (!require(type98_scheduler_context_replayed_from_source_pair,
					"entry-to-writeout workflow did not carry recovered type-98 source-pair +0x04 wrapper context into 0x4a8db2 scheduler replay")) {
			return 1;
		}
		if (!require(workflow.phases.size() > 7
						&& workflow.phases[7].id == "relation_source_order_scan"
						&& workflow.phases[7].status == "complete_source_order_prefix"
						&& workflow_generator_state.relation_source_order_scan_0x4a89da.invoked
						&& workflow_generator_state.relation_source_order_scan_0x4a89da.prefix_applied
						&& workflow_generator_state.relation_source_order_scan_0x4a89da.helper_chain_complete
						&& workflow_generator_state.mine_resource_materialization_0x4a9d6a.invoked
						&& workflow_generator_state.reward_guard_source_stream_0x4aab7e.invoked
						&& workflow_generator_state.reward_guard_source_stream_0x4aab7e.blocked_reason.empty()
						&& workflow_generator_state.reward_guard_source_stream_0x4aab7e.successful_coordinate_scan_count > 0
						&& workflow_generator_state.decorative_flagged_cell_dispatch_0x49eb8d.invoked
						&& workflow_generator_state.connection_tail_replay_0x4a79a3.invoked
						&& workflow_generator_state.road_river_object_adjacency_0x4ab52a.invoked
						&& workflow.final_payload_owned
						&& workflow.final_writeout_complete
						&& workflow.final_payload_writeout_0x4ad1e3.applied,
					"entry-to-writeout workflow did not continue after source-backed reward/guard materialization after 0x4a89da/0x4a8bfc")) {
			return 1;
		}
	}

	std::cout << "h3maped_rmg_core_selftest: ok\n";
	return 0;
}
