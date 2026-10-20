#include "aurelion_rules_api.hpp"

#include "aurelion_rules/battle_hex.hpp"
#include "aurelion_rules/build_info.hpp"

#include <godot_cpp/core/class_db.hpp>
#include <godot_cpp/variant/utility_functions.hpp>

#include <exception>
#include <vector>

#ifndef AURELION_RULES_FLAVOUR
#define AURELION_RULES_FLAVOUR "unknown"
#endif

namespace godot {
namespace {

namespace hex = aurelion::rules::battle_hex;

bool valid_open_mask(const PackedByteArray &open, const char *method) {
	if (open.size() == hex::kCellCount) {
		return true;
	}
	UtilityFunctions::push_error(String("AurelionRules.") + method + ": open mask has " + String::num_int64(open.size()) + " bytes, expected " + String::num_int64(hex::kCellCount));
	return false;
}

bool valid_body(int64_t body_width, int64_t tail_step, const char *method) {
	if ((body_width == 1 || body_width == 2) && (tail_step == 1 || tail_step == -1)) {
		return true;
	}
	UtilityFunctions::push_error(String("AurelionRules.") + method + ": bad body width " + String::num_int64(body_width) + " / tail step " + String::num_int64(tail_step));
	return false;
}

void report_exception(const char *method, const char *what) {
	UtilityFunctions::push_error(String("AurelionRules.") + method + ": native exception: " + String(what));
}

PackedInt32Array to_pairs(const std::vector<hex::CellSteps> &cells) {
	PackedInt32Array pairs;
	pairs.resize(static_cast<int64_t>(cells.size()) * 2);
	int32_t *out = pairs.ptrw();
	for (const hex::CellSteps &cell : cells) {
		*out++ = cell.id;
		*out++ = cell.steps;
	}
	return pairs;
}

} // namespace

void AurelionRules::_bind_methods() {
	ClassDB::bind_method(D_METHOD("get_build_info"), &AurelionRules::get_build_info);
	ClassDB::bind_method(D_METHOD("battle_hex_reachable", "open", "body_width", "tail_step", "start_id", "max_steps"), &AurelionRules::battle_hex_reachable);
	ClassDB::bind_method(D_METHOD("battle_hex_walk_steps", "open", "body_width", "tail_step", "target_q", "target_r", "target_tail_q", "gap"), &AurelionRules::battle_hex_walk_steps);
	ClassDB::bind_method(D_METHOD("battle_hex_field_stays_open", "open"), &AurelionRules::battle_hex_field_stays_open);
}

Dictionary AurelionRules::get_build_info() const {
	const aurelion::rules::BuildInfo info = aurelion::rules::build_info();
	Dictionary result;
	result["api"] = aurelion::rules::kRulesApiVersion;
	result["source_tree"] = String(info.source_tree.c_str());
	result["godot_cpp"] = String(info.godot_cpp.c_str());
	result["compiler"] = String(info.compiler.c_str());
	result["flavour"] = String(AURELION_RULES_FLAVOUR);
	return result;
}

PackedInt32Array AurelionRules::battle_hex_reachable(const PackedByteArray &open, int64_t body_width, int64_t tail_step, int64_t start_id, int64_t max_steps) const {
	if (!valid_open_mask(open, "battle_hex_reachable") || !valid_body(body_width, tail_step, "battle_hex_reachable")) {
		return PackedInt32Array();
	}
	if (start_id < 0 || start_id >= hex::kCellCount) {
		UtilityFunctions::push_error(String("AurelionRules.battle_hex_reachable: start id out of range: ") + String::num_int64(start_id));
		return PackedInt32Array();
	}
	try {
		return to_pairs(hex::reachable(open.ptr(), hex::Body{ body_width, tail_step }, start_id, max_steps));
	} catch (const std::exception &error) {
		report_exception("battle_hex_reachable", error.what());
	} catch (...) {
		report_exception("battle_hex_reachable", "unknown");
	}
	return PackedInt32Array();
}

PackedInt32Array AurelionRules::battle_hex_walk_steps(const PackedByteArray &open, int64_t body_width, int64_t tail_step, int64_t target_q, int64_t target_r, int64_t target_tail_q, int64_t gap) const {
	if (!valid_open_mask(open, "battle_hex_walk_steps") || !valid_body(body_width, tail_step, "battle_hex_walk_steps")) {
		return PackedInt32Array();
	}
	try {
		return to_pairs(hex::walk_steps(open.ptr(), hex::Body{ body_width, tail_step }, hex::PlacedBody{ target_q, target_r, target_tail_q }, gap));
	} catch (const std::exception &error) {
		report_exception("battle_hex_walk_steps", error.what());
	} catch (...) {
		report_exception("battle_hex_walk_steps", "unknown");
	}
	return PackedInt32Array();
}

bool AurelionRules::battle_hex_field_stays_open(const PackedByteArray &open) const {
	if (!valid_open_mask(open, "battle_hex_field_stays_open")) {
		return false;
	}
	try {
		return hex::field_stays_open(open.ptr());
	} catch (const std::exception &error) {
		report_exception("battle_hex_field_stays_open", error.what());
	} catch (...) {
		report_exception("battle_hex_field_stays_open", "unknown");
	}
	return false;
}

} // namespace godot
