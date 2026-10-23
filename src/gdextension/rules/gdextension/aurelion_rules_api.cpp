#include "aurelion_rules_api.hpp"

#include "battle_port_bridge.hpp"
#include "battle_state_bridge.hpp"
#include "snapshot_encoder.hpp"

#include "aurelion_rules/ai_search.hpp"
#include "aurelion_rules/battle_hex.hpp"
#include "aurelion_rules/build_info.hpp"
#include "aurelion_rules/port/registry.hpp"

#include <godot_cpp/classes/os.hpp>
#include <godot_cpp/core/class_db.hpp>
#include <godot_cpp/core/gdextension_interface_loader.hpp>
#include <godot_cpp/variant/utility_functions.hpp>

#include <algorithm>
#include <chrono>
#include <cstdint>
#include <cstdio>
#include <cstring>
#include <exception>
#include <filesystem>
#include <stdexcept>
#include <fstream>
#include <vector>

#ifndef AURELION_RULES_FLAVOUR
#define AURELION_RULES_FLAVOUR "unknown"
#endif

namespace godot {
namespace {

namespace hex = aurelion::rules::battle_hex;
namespace search = aurelion::rules::ai_search;

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

// A failed port call is a SCRIPT ERROR, as the GDScript it replaces would
// print, so rules_parity runs and the core suite's tests fail on it. Never throws.
void report_port_failure(const char *method, const std::string &text) noexcept {
	try {
		const std::string message = std::string("AurelionRules.") + method + ": " + text;
		::godot::gdextension_interface::print_script_error(message.c_str(), method, __FILE__, __LINE__, false);
	} catch (...) {
		::godot::gdextension_interface::print_script_error("AurelionRules: port failure (no memory for the message)", method, __FILE__, __LINE__, false);
	}
}

// A path the port leaves to GDScript (state::NotPorted) in a subsystem whose
// switches have no GDScript fallback (port::Table::fallback): a failure.
std::string not_ported_failure(const char *what) {
	return std::string("reached a path the port leaves to GDScript (") + what + "), and its subsystem has no GDScript fallback";
}

std::string not_ported_after_host_calls(const char *what, size_t host_calls) {
	return std::string("reached a path the port leaves to GDScript (") + what + ") after " + std::to_string(host_calls) + " full host calls, which ran GDScript on what the call had changed, so the GDScript fallback cannot run";
}

std::string not_ported_after_view_write(const char *what) {
	return std::string("reached a path the port leaves to GDScript (") + what + ") after a pure host call wrote back an object's properties, which cannot be undone, so the GDScript fallback cannot run";
}

// A call its subsystem's GDScript ran instead (port::Table::fallback): one line
// each, which AI match batches count. Never throws.
void report_fallback(const char *function, const char *reason) noexcept {
	try {
		UtilityFunctions::print(String("NATIVE FALLBACK: ") + String::utf8(function) + " ran in GDScript, not ported: " + String::utf8(reason));
	} catch (...) {
	}
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

int64_t usec_since(std::chrono::steady_clock::time_point start) {
	return std::chrono::duration_cast<std::chrono::microseconds>(std::chrono::steady_clock::now() - start).count();
}

Dictionary state_stats(const aurelion::rules::bridge::StateBridge &bridge, const aurelion::rules::state::State &state, bool ok, int64_t load_usec, int64_t store_usec) {
	const aurelion::rules::bridge::LoadCounts &counts = bridge.counts();
	Dictionary types;
	for (int type = 0; type < Variant::VARIANT_MAX; ++type) {
		if (counts.by_type[type] != 0) {
			types[Variant::get_type_name(static_cast<Variant::Type>(type))] = counts.by_type[type];
		}
	}
	Dictionary stats;
	stats["ok"] = ok;
	stats["error"] = String::utf8(bridge.error().c_str());
	stats["values"] = counts.values;
	stats["shared_refs"] = counts.shared_refs;
	stats["arrays"] = static_cast<int64_t>(state.array_count());
	stats["dicts"] = static_cast<int64_t>(state.dict_count());
	stats["atoms"] = static_cast<int64_t>(state.atom_count());
	stats["types"] = types;
	stats["load_usec"] = load_usec;
	stats["store_usec"] = store_usec;
	stats["reused_arrays"] = bridge.reused_arrays();
	stats["reused_dicts"] = bridge.reused_dicts();
	stats["rebuilt_dicts"] = bridge.rebuilt_dicts();
	return stats;
}

search::Span span_of(const PackedInt32Array &items) {
	return search::Span{ items.ptr(), items.size() };
}

search::Bytes bytes_of(const PackedByteArray &items) {
	return search::Bytes{ items.ptr(), items.size() };
}

// Offsets (count + 1, or empty for none) and items as one list of lists.
bool lists_of(const PackedInt32Array &offsets, const PackedInt32Array &items, search::Lists &lists, const char *method, const char *what) {
	if (offsets.is_empty()) {
		if (!items.is_empty()) {
			UtilityFunctions::push_error(String("AurelionRules.") + method + ": " + what + " has items and no offsets");
			return false;
		}
		lists = search::Lists{};
		return true;
	}
	lists = search::Lists{ offsets.ptr(), offsets.size() - 1, items.ptr(), items.size() };
	return true;
}

bool valid_tile_mask(const PackedByteArray &mask, int64_t count, bool may_be_empty, const char *method, const char *what) {
	if (mask.size() == count || (may_be_empty && mask.is_empty())) {
		return true;
	}
	UtilityFunctions::push_error(String("AurelionRules.") + method + ": " + what + " has " + String::num_int64(mask.size()) + " bytes, expected " + String::num_int64(count));
	return false;
}

bool valid_map(int64_t width, int64_t height, const char *method) {
	if (width > 0 && height > 0 && width <= 1 << 20 && height <= 1 << 20 && width * height <= INT32_MAX) {
		return true;
	}
	UtilityFunctions::push_error(String("AurelionRules.") + method + ": bad map size " + String::num_int64(width) + "x" + String::num_int64(height));
	return false;
}

PackedInt32Array to_packed(const std::vector<int32_t> &items) {
	PackedInt32Array packed;
	packed.resize(static_cast<int64_t>(items.size()));
	int32_t *out = packed.ptrw();
	for (int32_t item : items) {
		*out++ = item;
	}
	return packed;
}

} // namespace

void AurelionRules::_bind_methods() {
	ClassDB::bind_method(D_METHOD("get_build_info"), &AurelionRules::get_build_info);
	ClassDB::bind_method(D_METHOD("battle_hex_reachable", "open", "body_width", "tail_step", "start_id", "max_steps"), &AurelionRules::battle_hex_reachable);
	ClassDB::bind_method(D_METHOD("battle_hex_walk_steps", "open", "body_width", "tail_step", "target_q", "target_r", "target_tail_q", "gap"), &AurelionRules::battle_hex_walk_steps);
	ClassDB::bind_method(D_METHOD("battle_hex_field_stays_open", "open"), &AurelionRules::battle_hex_field_stays_open);
	ClassDB::bind_method(D_METHOD("state_round_trip", "value", "mode"), &AurelionRules::state_round_trip);
	ClassDB::bind_method(D_METHOD("state_overwrite", "target", "source"), &AurelionRules::state_overwrite);
	ClassDB::bind_method(D_METHOD("state_last_stats"), &AurelionRules::state_last_stats);
	ClassDB::bind_method(D_METHOD("state_conversion_timing", "start", "end", "made_arrays", "made_dicts", "rounds"), &AurelionRules::state_conversion_timing);
	ClassDB::bind_method(D_METHOD("port_call", "name", "args", "write_back"), &AurelionRules::port_call);
	ClassDB::bind_method(D_METHOD("port_not_ported"), &AurelionRules::port_not_ported);
	ClassDB::bind_method(D_METHOD("port_session_call", "name", "args"), &AurelionRules::port_session_call);
	ClassDB::bind_method(D_METHOD("port_session_reread", "container"), &AurelionRules::port_session_reread);
	ClassDB::bind_method(D_METHOD("port_session_close"), &AurelionRules::port_session_close);
	ClassDB::bind_method(D_METHOD("port_check", "name", "args", "gdscript_result"), &AurelionRules::port_check);
	ClassDB::bind_method(D_METHOD("port_report", "name", "mismatch"), &AurelionRules::port_report);
	ClassDB::bind_method(D_METHOD("port_copy", "args"), &AurelionRules::port_copy);
	ClassDB::bind_method(D_METHOD("port_validate_begin", "name", "args"), &AurelionRules::port_validate_begin);
	ClassDB::bind_method(D_METHOD("port_validate_end", "handle", "gdscript_result", "args"), &AurelionRules::port_validate_end);
	ClassDB::bind_method(D_METHOD("port_validate_point", "name", "args"), &AurelionRules::port_validate_point);
	ClassDB::bind_method(D_METHOD("port_stats"), &AurelionRules::port_stats);
	ClassDB::bind_method(D_METHOD("ai_search_masks", "width", "height", "surface_blocked", "surface_stops", "water", "sea", "body_offsets", "body_tiles", "zone_offsets", "zone_tiles", "neutral_open", "unit_blocked", "unit_stops", "hero_tiles", "guard_offsets", "guard_tiles", "site_tiles", "site_open"), &AurelionRules::ai_search_masks);
	ClassDB::bind_method(D_METHOD("ai_search_walk", "width", "height", "start", "start_phase", "radius", "native_corners", "blocked", "stop_mask", "pass_mask", "hero_zone", "portals", "seen", "water", "sea_open", "boats", "docks", "shore_cost", "dock_cost"), &AurelionRules::ai_search_walk);
	ClassDB::bind_method(D_METHOD("snapshot_encode", "value"), &AurelionRules::snapshot_encode);
}

// One open port_validate check: the native run's result and arguments, kept in
// its bridge's State until the GDScript call has run.
struct AurelionRules::Validation {
	aurelion::rules::bridge::PortBridge bridge;
	const aurelion::rules::port::Function *function = nullptr;
	aurelion::rules::state::Value result;
	std::vector<aurelion::rules::state::Value> args;
	// A native failure, reported when the check ends.
	std::string error;
	bool not_ported = false;
	// The native run reached a host call (state::Suspend) and ended there:
	// the host and its arguments, in the bridge's State, and the check's
	// argument Array, which port_validate_point compares as `after`.
	bool suspended = false;
	uint32_t host_script = 0;
	uint32_t host_function = 0;
	std::vector<aurelion::rules::state::Value> host_args;
	Array arguments;
	// port_validate_point closed it: GDScript reached the host call (or one
	// the native run did not make, a mismatch reported there). The end
	// compares nothing more.
	bool at_point = false;
};

AurelionRules::AurelionRules() {
	try {
		ports_.push_back(std::make_unique<aurelion::rules::bridge::PortBridge>());
		size_t count = 0;
		aurelion::rules::port::functions(count);
		port_stats_.resize(count);
		size_t table_count = 0;
		const aurelion::rules::port::Table *tables = aurelion::rules::port::tables(table_count);
		// The functions array holds the tables' functions in table order.
		size_t first = 0;
		for (size_t index = 0; index < table_count; ++index) {
			for (size_t slot = 0; slot < tables[index].count && first + slot < port_stats_.size(); ++slot) {
				port_stats_[first + slot].fallback = tables[index].fallback;
			}
			first += tables[index].count;
		}
		OS *os = OS::get_singleton();
		for (size_t index = 0; os != nullptr && index < table_count; ++index) {
			const String folder = os->get_environment(tables[index].log_variable);
			if (!folder.is_empty()) {
				const CharString utf8 = folder.path_join("shadow_" + String::num_int64(os->get_process_id()) + ".json").utf8();
				const std::string path(utf8.get_data(), static_cast<size_t>(utf8.length()));
				if (std::find(port_log_paths_.begin(), port_log_paths_.end(), path) == port_log_paths_.end()) {
					port_log_paths_.push_back(path);
				}
				// At once, so a folder that cannot take the file fails the run.
				write_port_stats();
			}
		}
	} catch (const std::exception &error) {
		report_port_failure("AurelionRules", std::string("native exception while starting: ") + error.what());
	} catch (...) {
		report_port_failure("AurelionRules", "unknown native exception while starting");
	}
}

AurelionRules::~AurelionRules() {
	try {
		write_port_stats();
	} catch (...) {
		report_port_failure("AurelionRules", "the port stats could not be written at exit");
	}
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

Variant AurelionRules::state_round_trip(const Variant &value, int64_t mode) {
	if (mode != 0 && mode != 1) {
		UtilityFunctions::push_error(String("AurelionRules.state_round_trip: bad mode ") + String::num_int64(mode));
		return Variant();
	}
	try {
		aurelion::rules::state::State state;
		aurelion::rules::bridge::StateBridge bridge;
		const auto load_start = std::chrono::steady_clock::now();
		const bool ok = bridge.load(value, state);
		const int64_t load_usec = usec_since(load_start);
		if (!ok) {
			last_state_stats_ = state_stats(bridge, state, false, load_usec, 0);
			UtilityFunctions::push_error(String("AurelionRules.state_round_trip: ") + String::utf8(bridge.error().c_str()));
			return Variant();
		}
		const auto store_start = std::chrono::steady_clock::now();
		Variant result = mode == 1 ? bridge.store_in_place(state) : bridge.export_copy(state);
		last_state_stats_ = state_stats(bridge, state, true, load_usec, usec_since(store_start));
		return result;
	} catch (const std::exception &error) {
		report_exception("state_round_trip", error.what());
	} catch (...) {
		report_exception("state_round_trip", "unknown");
	}
	return Variant();
}

Variant AurelionRules::state_overwrite(const Variant &target, const Variant &source) {
	try {
		aurelion::rules::state::State state;
		aurelion::rules::bridge::StateBridge bridge;
		const auto load_start = std::chrono::steady_clock::now();
		const bool ok = bridge.load(target, state) && bridge.overwrite(source, state);
		const int64_t load_usec = usec_since(load_start);
		if (!ok) {
			last_state_stats_ = state_stats(bridge, state, false, load_usec, 0);
			UtilityFunctions::push_error(String("AurelionRules.state_overwrite: ") + String::utf8(bridge.error().c_str()));
			return Variant();
		}
		const auto store_start = std::chrono::steady_clock::now();
		Variant result = bridge.store_in_place(state);
		last_state_stats_ = state_stats(bridge, state, true, load_usec, usec_since(store_start));
		return result;
	} catch (const std::exception &error) {
		report_exception("state_overwrite", error.what());
	} catch (...) {
		report_exception("state_overwrite", "unknown");
	}
	return Variant();
}

Dictionary AurelionRules::state_last_stats() const {
	return last_state_stats_;
}

Dictionary AurelionRules::state_conversion_timing(const Variant &start, const Variant &end, int64_t made_arrays, int64_t made_dicts, int64_t rounds) {
	Dictionary result;
	try {
		using Clock = std::chrono::steady_clock;
		std::vector<double> loads;
		std::vector<double> stores;
		Array load_rounds;
		Array store_rounds;
		for (int64_t round = 0; round < std::max<int64_t>(1, rounds); ++round) {
			const Variant copy = start.duplicate(true);
			aurelion::rules::state::State state;
			aurelion::rules::bridge::StateBridge bridge;
			const Clock::time_point load_start = Clock::now();
			const bool loaded = bridge.load(copy, state);
			const Clock::time_point load_stop = Clock::now();
			if (!loaded || !bridge.overwrite(end, state)) {
				UtilityFunctions::push_error(String("AurelionRules.state_conversion_timing: ") + String::utf8(bridge.error().c_str()));
				return Dictionary();
			}
			const size_t loaded_arrays = state.array_count();
			const size_t loaded_dicts = state.dict_count();
			for (int64_t index = 0; index < made_arrays; ++index) {
				state.new_array();
			}
			for (int64_t index = 0; index < made_dicts; ++index) {
				state.new_dict();
			}
			const Clock::time_point store_start = Clock::now();
			bridge.store_in_place(state);
			const Clock::time_point store_stop = Clock::now();
			loads.push_back(std::chrono::duration<double, std::micro>(load_stop - load_start).count());
			stores.push_back(std::chrono::duration<double, std::micro>(store_stop - store_start).count());
			load_rounds.push_back(loads.back());
			store_rounds.push_back(stores.back());
			result["loaded_arrays"] = static_cast<int64_t>(loaded_arrays);
			result["loaded_dicts"] = static_cast<int64_t>(loaded_dicts);
			result["pool_arrays"] = static_cast<int64_t>(state.array_count());
			result["pool_dicts"] = static_cast<int64_t>(state.dict_count());
			result["rebuilt_dicts"] = bridge.rebuilt_dicts();
		}
		std::sort(loads.begin(), loads.end());
		std::sort(stores.begin(), stores.end());
		result["load_us"] = loads[loads.size() / 2];
		result["store_us"] = stores[stores.size() / 2];
		result["load_rounds"] = load_rounds;
		result["store_rounds"] = store_rounds;
		return result;
	} catch (const std::exception &error) {
		report_exception("state_conversion_timing", error.what());
	} catch (...) {
		report_exception("state_conversion_timing", "unknown");
	}
	return Dictionary();
}

namespace {

std::string utf8_text(const String &text) {
	const CharString utf8 = text.utf8();
	return std::string(utf8.get_data(), static_cast<size_t>(utf8.length()));
}

void append_json_string(std::string &out, const std::string &text) {
	out += '"';
	for (const char c : text) {
		switch (c) {
			case '"':
				out += "\\\"";
				break;
			case '\\':
				out += "\\\\";
				break;
			case '\n':
				out += "\\n";
				break;
			default:
				if (static_cast<unsigned char>(c) < 0x20) {
					char escaped[8];
					std::snprintf(escaped, sizeof(escaped), "\\u%04x", static_cast<unsigned>(static_cast<unsigned char>(c)));
					out += escaped;
				} else {
					out += c;
				}
		}
	}
	out += '"';
}

// The most arguments a ported function may take (AiHeroRules._route_through
// takes 11).
constexpr int kMaxPortArgs = 16;

// Why a call cannot go to the function: "" when it can.
std::string arity_problem(const aurelion::rules::port::Function &function, int64_t given) {
	if (function.arity > kMaxPortArgs) {
		return "takes " + std::to_string(function.arity) + " arguments, more than the adapter's " + std::to_string(kMaxPortArgs);
	}
	if (given != function.arity) {
		return "takes " + std::to_string(function.arity) + " arguments, got " + std::to_string(given);
	}
	return std::string();
}

// One level of port_call or port_check nesting, left on every exit.
class Nesting {
public:
	explicit Nesting(size_t &depth) :
			depth_(depth), level_(depth++) {}
	~Nesting() { --depth_; }
	Nesting(const Nesting &) = delete;
	Nesting &operator=(const Nesting &) = delete;
	size_t level() const { return level_; }

private:
	size_t &depth_;
	size_t level_;
};

// "BattleRules._finalize_victory" of a host call the native run reached.
std::string host_text(const aurelion::rules::state::State &state, uint32_t script, uint32_t function) {
	return aurelion::rules::port::host_name(state.text(script), state.text(function));
}

// A host call (state::Suspend) in a call where no GDScript may run.
std::string suspended_failure(const aurelion::rules::state::State &state, const aurelion::rules::state::Suspend &host) {
	return "reached a host call to " + host_text(state, host.script, host.function) + " in a call that writes nothing back";
}

constexpr size_t kKeptMismatches = 20;
constexpr int64_t kStatsEvery = 65536;

} // namespace

const aurelion::rules::port::Function *AurelionRules::port_function(const StringName &name) {
	uint64_t id = 0;
	std::memcpy(&id, name._native_ptr(), sizeof(id));
	const auto found = port_names_.find(id);
	if (found != port_names_.end()) {
		return found->second.second;
	}
	const aurelion::rules::port::Function *function = aurelion::rules::port::find_function(utf8_text(String(name)));
	port_names_.emplace(id, std::make_pair(name, function));
	return function;
}

void AurelionRules::record_unknown(const StringName &name, const char *method) {
	// Every call reports: a registry entry renamed or removed under a switch
	// would otherwise make the switched function a silent no-op.
	const std::string text = utf8_text(String(name));
	++unknown_calls_;
	if (unknown_names_.size() < kKeptMismatches && std::find(unknown_names_.begin(), unknown_names_.end(), text) == unknown_names_.end()) {
		unknown_names_.push_back(text);
	}
	write_port_stats();
	report_port_failure(method, "not a ported function: " + text);
}

AurelionRules::PortStats &AurelionRules::stats_of(const aurelion::rules::port::Function *function) {
	size_t count = 0;
	return port_stats_[static_cast<size_t>(function - aurelion::rules::port::functions(count))];
}

void AurelionRules::record_mismatch(PortStats &stats, const char *name, const std::string &text, bool error) {
	++(error ? stats.errors : stats.mismatches);
	if (stats.first.size() < kKeptMismatches) {
		stats.first.push_back(text);
	}
	write_port_stats();
	// Shadow is the proof of the port: a mismatch fails the run like a failed call.
	if (reported_mismatches_ < kKeptMismatches) {
		++reported_mismatches_;
		report_port_failure("port shadow", std::string(error ? "native failure in " : "mismatch in ") + name + ": " + text);
	}
}

// A path the port leaves out, in a subsystem that falls back to GDScript: no
// failure, but the stats name the first ones, as they do mismatches.
void AurelionRules::keep_not_ported(PortStats &stats, const char *reason) {
	if (stats.first.size() < kKeptMismatches) {
		stats.first.push_back(std::string("not ported: ") + reason);
	}
}

void AurelionRules::count_host_calls(PortStats &stats, const aurelion::rules::bridge::PortBridge &port) {
	const auto &made = port.host_calls_made();
	if (made.empty()) {
		return;
	}
	stats.host_calls += static_cast<int64_t>(made.size());
	stats.max_host_calls = std::max(stats.max_host_calls, static_cast<int64_t>(made.size()));
	for (const auto &call : made) {
		const std::string name = aurelion::rules::port::host_name(port.state().text(call.first), port.state().text(call.second));
		auto found = std::find_if(host_call_counts_.begin(), host_call_counts_.end(), [&](const auto &entry) { return entry.first == name; });
		if (found == host_call_counts_.end()) {
			host_call_counts_.emplace_back(name, 1);
		} else {
			++found->second;
		}
	}
}

void AurelionRules::count_port_use() {
	if (++port_uses_ % kStatsEvery == 0) {
		write_port_stats();
	}
}

void AurelionRules::write_port_stats() const {
	if (port_log_paths_.empty()) {
		return;
	}
	size_t count = 0;
	const aurelion::rules::port::Function *table = aurelion::rules::port::functions(count);
	std::string out = "{\"functions\": {";
	bool first_entry = true;
	for (size_t index = 0; index < count && index < port_stats_.size(); ++index) {
		const PortStats &stats = port_stats_[index];
		if (stats.calls == 0 && stats.checks == 0 && stats.not_ported == 0) {
			continue;
		}
		if (!first_entry) {
			out += ", ";
		}
		first_entry = false;
		append_json_string(out, table[index].name);
		out += ": {\"calls\": " + std::to_string(stats.calls) + ", \"checks\": " + std::to_string(stats.checks) + ", \"mismatches\": " + std::to_string(stats.mismatches) + ", \"errors\": " + std::to_string(stats.errors) + ", \"not_ported\": " + std::to_string(stats.not_ported);
		if (stats.host_points != 0) {
			out += ", \"host_points\": " + std::to_string(stats.host_points);
		}
		if (stats.host_calls != 0) {
			out += ", \"host_calls\": " + std::to_string(stats.host_calls) + ", \"max_host_calls\": " + std::to_string(stats.max_host_calls);
		}
		out += ", \"first\": [";
		for (size_t line = 0; line < stats.first.size(); ++line) {
			if (line != 0) {
				out += ", ";
			}
			append_json_string(out, stats.first[line]);
		}
		out += "]}";
	}
	out += "}, \"hosts\": {";
	for (size_t index = 0; index < host_call_counts_.size(); ++index) {
		if (index != 0) {
			out += ", ";
		}
		append_json_string(out, host_call_counts_[index].first);
		out += ": " + std::to_string(host_call_counts_[index].second);
	}
	out += "}, \"unknown_calls\": " + std::to_string(unknown_calls_) + ", \"unknown_names\": [";
	for (size_t index = 0; index < unknown_names_.size(); ++index) {
		if (index != 0) {
			out += ", ";
		}
		append_json_string(out, unknown_names_[index]);
	}
	out += "]}\n";
	for (const std::string &path : port_log_paths_) {
		std::ofstream file(std::filesystem::u8path(path), std::ios::binary | std::ios::trunc);
		file << out;
		file.flush();
		if (!file && !port_log_failed_) {
			port_log_failed_ = true;
			report_port_failure("port stats", "cannot write " + path + " (the subsystem's log variable must name an existing folder)");
		}
	}
}

aurelion::rules::bridge::PortBridge &AurelionRules::port_bridge(size_t depth) {
	while (ports_.size() <= depth) {
		ports_.push_back(std::make_unique<aurelion::rules::bridge::PortBridge>());
	}
	return *ports_[depth];
}

Variant AurelionRules::port_call(const StringName &name, const Array &args, bool write_back) {
	return port_call_on(name, args, write_back, false);
}

Variant AurelionRules::port_session_call(const StringName &name, const Array &args) {
	return port_call_on(name, args, true, port_depth_ == 0);
}

void AurelionRules::port_session_reread(const Variant &container) {
	if (session_port_) {
		session_port_->reread(container);
	}
}

void AurelionRules::port_session_close() {
	session_port_.reset();
}

Variant AurelionRules::port_call_on(const StringName &name, const Array &args, bool write_back, bool session) {
	std::string problem;
	last_not_ported_ = false;
	try {
		const aurelion::rules::port::Function *function = port_function(name);
		if (function == nullptr) {
			record_unknown(name, "port_call");
			return Variant();
		}
		PortStats &stats = stats_of(function);
		++stats.calls;
		count_port_use();
		const Nesting nesting(port_depth_);
		aurelion::rules::bridge::PortBridge *bridge = nullptr;
		try {
			if (session && !session_port_) {
				session_port_ = std::make_unique<aurelion::rules::bridge::PortBridge>();
			}
			aurelion::rules::bridge::PortBridge &port = session ? *session_port_ : port_bridge(nesting.level());
			bridge = &port;
			const std::string arity = arity_problem(*function, args.size());
			if (!arity.empty()) {
				problem = std::string(function->name) + " " + arity;
			} else {
				if (session) {
					port.begin_kept();
				} else {
					// A host call writes back what the call changed so far:
					// only in a call that writes back.
					port.begin(false, write_back);
				}
				aurelion::rules::state::Value values[kMaxPortArgs];
				for (int index = 0; index < function->arity; ++index) {
					values[index] = port.load(args[index]);
				}
				const aurelion::rules::state::Value result = function->call(port.state(), values);
				// A call inside a host call may have set it.
				last_not_ported_ = false;
				count_host_calls(stats, port);
				if (session) {
					return port.keep(result, values, static_cast<size_t>(function->arity));
				}
				// What the session kept may hold a container this call wrote
				// into, or GDScript wrote into at a host call.
				if (write_back && nesting.level() == 0 && session_port_ && (port.full_host_calls() != 0 || port.changed_a_source())) {
					session_port_->drop_kept();
				}
				if (write_back) {
					port.write_back();
				} else if (port.changed_a_source()) {
					problem = std::string(function->name) + ": native wrote into an argument";
				}
				if (problem.empty()) {
					return port.export_value(result);
				}
			}
		} catch (const aurelion::rules::state::NotPorted &reason) {
			++stats.not_ported;
			last_not_ported_ = true;
			// What pure host calls wrote back is undone, so the GDScript
			// fallback starts from the state the call started from. A full
			// host call ran GDScript on it, and an object's view written back
			// is not undone: the fallback would start again from a changed
			// state.
			const size_t full_calls = bridge == nullptr ? 0 : bridge->full_host_calls();
			const bool undo_lost = bridge != nullptr && bridge->undo_lost();
			if (stats.fallback && full_calls == 0 && !undo_lost) {
				if (bridge != nullptr) {
					bridge->undo_write_backs();
				}
				keep_not_ported(stats, reason.what());
				report_fallback(function->name, reason.what());
				return Variant();
			}
			last_not_ported_ = false;
			problem = std::string(function->name) + ": " + (full_calls != 0 ? not_ported_after_host_calls(reason.what(), full_calls) : undo_lost ? not_ported_after_view_write(reason.what()) : not_ported_failure(reason.what()));
		} catch (const aurelion::rules::state::Suspend &host) {
			problem = std::string(function->name) + ": " + suspended_failure(bridge->state(), host);
		} catch (const aurelion::rules::state::ScriptError &error) {
			problem = std::string(function->name) + ": native script error: " + error.what();
		} catch (const std::exception &error) {
			problem = std::string(function->name) + ": native exception: " + error.what();
		} catch (...) {
			problem = std::string(function->name) + ": unknown native exception";
		}
		++stats.errors;
		write_port_stats();
	} catch (const std::exception &error) {
		problem = std::string("native exception outside the port: ") + error.what();
	} catch (...) {
		problem = "unknown native exception outside the port";
	}
	report_port_failure("port_call", problem);
	return Variant();
}

String AurelionRules::port_check(const StringName &name, const Array &args, const Variant &gdscript_result) {
	try {
		const aurelion::rules::port::Function *function = port_function(name);
		if (function == nullptr) {
			record_unknown(name, "port_check");
			return String("not a ported function");
		}
		PortStats &stats = stats_of(function);
		++stats.checks;
		count_port_use();
		std::string mismatch;
		bool error = false;
		const Nesting nesting(port_depth_);
		aurelion::rules::bridge::PortBridge *bridge = nullptr;
		try {
			aurelion::rules::bridge::PortBridge &port = port_bridge(nesting.level());
			bridge = &port;
			const std::string arity = arity_problem(*function, args.size());
			if (!arity.empty()) {
				error = true;
				mismatch = arity;
			} else {
				port.begin();
				aurelion::rules::state::Value values[kMaxPortArgs];
				for (int index = 0; index < function->arity; ++index) {
					values[index] = port.load(args[index]);
				}
				const aurelion::rules::state::Value result = function->call(port.state(), values);
				if (port.changed_a_source()) {
					mismatch = "native wrote into an argument";
				} else {
					mismatch = port.diff(result, gdscript_result);
				}
			}
		} catch (const aurelion::rules::state::NotPorted &reason) {
			++stats.not_ported;
			if (stats.fallback) {
				--stats.checks;
				keep_not_ported(stats, reason.what());
				return String();
			}
			error = true;
			mismatch = not_ported_failure(reason.what());
		} catch (const aurelion::rules::state::Suspend &host) {
			error = true;
			mismatch = suspended_failure(bridge->state(), host);
		} catch (const aurelion::rules::state::ScriptError &failure) {
			error = true;
			mismatch = std::string("native script error: ") + failure.what();
		} catch (const std::exception &failure) {
			error = true;
			mismatch = std::string("native exception: ") + failure.what();
		} catch (...) {
			error = true;
			mismatch = "unknown native exception";
		}
		if (mismatch.empty()) {
			return String();
		}
		record_mismatch(stats, function->name, mismatch, error);
		return String::utf8(mismatch.c_str());
	} catch (const std::exception &error) {
		report_port_failure("port_check", std::string("native exception outside the port: ") + error.what());
	} catch (...) {
		report_port_failure("port_check", "unknown native exception outside the port");
	}
	return String("native exception outside the port");
}

void AurelionRules::port_report(const StringName &name, const String &mismatch) {
	try {
		const aurelion::rules::port::Function *function = port_function(name);
		if (function == nullptr) {
			record_unknown(name, "port_report");
			return;
		}
		PortStats &stats = stats_of(function);
		++stats.checks;
		count_port_use();
		if (!mismatch.is_empty()) {
			record_mismatch(stats, function->name, utf8_text(mismatch), false);
		}
	} catch (const std::exception &error) {
		report_port_failure("port_report", std::string("native exception: ") + error.what());
	} catch (...) {
		report_port_failure("port_report", "unknown native exception");
	}
}

Array AurelionRules::port_copy(const Array &args) {
	try {
		return aurelion::rules::bridge::copy_for_shadow(args);
	} catch (const std::exception &error) {
		report_port_failure("port_copy", std::string("native exception: ") + error.what());
	} catch (...) {
		report_port_failure("port_copy", "unknown native exception");
	}
	// The GDScript copy, so the shadow run goes on; the failure is reported.
	return args.duplicate(true);
}

int64_t AurelionRules::port_validate_begin(const StringName &name, const Array &args) {
	try {
		const aurelion::rules::port::Function *function = port_function(name);
		if (function == nullptr) {
			record_unknown(name, "port_validate_begin");
			return -1;
		}
		if (open_validations_ == validations_.size()) {
			validations_.push_back(std::make_unique<Validation>());
		}
		const size_t handle = open_validations_++;
		Validation &check = *validations_[handle];
		check.function = function;
		check.result = aurelion::rules::state::Value();
		check.args.clear();
		check.error.clear();
		check.not_ported = false;
		check.suspended = false;
		check.host_script = 0;
		check.host_function = 0;
		check.host_args.clear();
		check.arguments = Array();
		check.at_point = false;
		PortStats &stats = stats_of(function);
		++stats.checks;
		count_port_use();
		try {
			const std::string arity = arity_problem(*function, args.size());
			if (!arity.empty()) {
				check.error = arity;
			} else {
				check.bridge.begin(true);
				for (int index = 0; index < function->arity; ++index) {
					check.args.push_back(check.bridge.load(args[index]));
				}
				try {
					check.result = function->call(check.bridge.state(), check.args.data());
				} catch (aurelion::rules::state::Suspend &host) {
					// Checked where GDScript's call reaches the host call
					// (port_validate_point), on the state as it is then.
					check.suspended = true;
					check.host_script = host.script;
					check.host_function = host.function;
					check.host_args = std::move(host.args);
					check.arguments = args;
				}
				check.bridge.keep_memo_shapes();
			}
		} catch (const aurelion::rules::state::NotPorted &reason) {
			++stats.not_ported;
			if (stats.fallback) {
				--stats.checks;
				check.not_ported = true;
				keep_not_ported(stats, reason.what());
			} else {
				check.error = not_ported_failure(reason.what());
			}
		} catch (const aurelion::rules::state::ScriptError &failure) {
			check.error = std::string("native script error: ") + failure.what();
		} catch (const std::exception &failure) {
			check.error = std::string("native exception: ") + failure.what();
		} catch (...) {
			check.error = "unknown native exception";
		}
		return static_cast<int64_t>(handle);
	} catch (const std::exception &error) {
		report_port_failure("port_validate_begin", std::string("native exception outside the port: ") + error.what());
	} catch (...) {
		report_port_failure("port_validate_begin", "unknown native exception outside the port");
	}
	return -1;
}

String AurelionRules::port_validate_end(int64_t handle, const Variant &gdscript_result, const Array &args) {
	try {
		if (handle < 0) {
			// begin failed, and said so.
			return String();
		}
		if (static_cast<size_t>(handle) >= open_validations_) {
			report_port_failure("port_validate_end", "no open check " + std::to_string(handle));
			return String("no open check");
		}
		// Checks opened inside this one and never ended (their GDScript call
		// stopped on an error) end with it, unchecked.
		open_validations_ = static_cast<size_t>(handle);
		Validation &check = *validations_[static_cast<size_t>(handle)];
		std::string mismatch;
		bool error = false;
		if (!check.not_ported) {
			if (!check.error.empty()) {
				mismatch = check.error;
				error = true;
			} else if (check.at_point) {
				// Checked at the host point: GDScript went on past the host
				// call, the native run did not.
			} else if (check.suspended) {
				mismatch = "the native port calls " + host_text(check.bridge.state(), check.host_script, check.host_function) + " and GDScript returned without calling it";
			} else {
				try {
					mismatch = check.bridge.verify(check.result, gdscript_result, check.args.data(), check.args.size(), args);
				} catch (const std::exception &failure) {
					mismatch = std::string("native exception in the check: ") + failure.what();
					error = true;
				}
			}
		}
		// Lets go of the arguments.
		check.bridge.begin();
		check.args.clear();
		check.host_args.clear();
		check.arguments = Array();
		if (mismatch.empty()) {
			return String();
		}
		record_mismatch(stats_of(check.function), check.function->name, mismatch, error);
		return String::utf8(mismatch.c_str());
	} catch (const std::exception &error) {
		report_port_failure("port_validate_end", std::string("native exception outside the port: ") + error.what());
	} catch (...) {
		report_port_failure("port_validate_end", "unknown native exception outside the port");
	}
	return String("native exception outside the port");
}

String AurelionRules::port_validate_point(const StringName &name, const Array &args) {
	try {
		const std::string text = utf8_text(String(name));
		if (aurelion::rules::port::find_host(text) == nullptr) {
			record_unknown(name, "port_validate_point");
			return String("not a host function");
		}
		std::string first;
		// Every open check's GDScript call is running, so each one calls this
		// host function now.
		for (size_t handle = 0; handle < open_validations_; ++handle) {
			Validation &check = *validations_[handle];
			// A native failure or a path left to GDScript is the end's to report.
			if (check.at_point || check.not_ported || !check.error.empty()) {
				continue;
			}
			check.at_point = true;
			std::string mismatch;
			bool error = false;
			if (!check.suspended) {
				mismatch = "GDScript calls " + text + " here and the native port does not";
			} else {
				++stats_of(check.function).host_points;
				const std::string host = host_text(check.bridge.state(), check.host_script, check.host_function);
				if (host != text) {
					mismatch = "GDScript calls " + text + " here, the native port " + host;
				} else {
					try {
						const std::string found = check.bridge.verify_host_call(check.host_args, args, check.args.data(), check.args.size(), check.arguments);
						if (!found.empty()) {
							mismatch = "at the host call " + text + ": " + found;
						}
					} catch (const std::exception &failure) {
						mismatch = "at the host call " + text + ": native exception in the check: " + failure.what();
						error = true;
					}
				}
			}
			if (mismatch.empty()) {
				continue;
			}
			record_mismatch(stats_of(check.function), check.function->name, mismatch, error);
			if (first.empty()) {
				first = mismatch;
			}
		}
		return String::utf8(first.c_str());
	} catch (const std::exception &error) {
		report_port_failure("port_validate_point", std::string("native exception outside the port: ") + error.what());
	} catch (...) {
		report_port_failure("port_validate_point", "unknown native exception outside the port");
	}
	return String("native exception outside the port");
}

PackedByteArray AurelionRules::snapshot_encode(const Variant &value) const {
	try {
		return aurelion::rules::bridge::encode_snapshot(value);
	} catch (const std::exception &error) {
		report_exception("snapshot_encode", error.what());
	} catch (...) {
		report_exception("snapshot_encode", "unknown");
	}
	return PackedByteArray();
}

Dictionary AurelionRules::port_stats() const {
	Dictionary result;
	try {
		size_t count = 0;
		const aurelion::rules::port::Function *table = aurelion::rules::port::functions(count);
		for (size_t index = 0; index < count && index < port_stats_.size(); ++index) {
			const PortStats &stats = port_stats_[index];
			if (stats.calls == 0 && stats.checks == 0 && stats.not_ported == 0) {
				continue;
			}
			Dictionary entry;
			entry["calls"] = stats.calls;
			entry["checks"] = stats.checks;
			entry["mismatches"] = stats.mismatches;
			entry["errors"] = stats.errors;
			entry["not_ported"] = stats.not_ported;
			if (stats.host_points != 0) {
				entry["host_points"] = stats.host_points;
			}
			if (stats.host_calls != 0) {
				entry["host_calls"] = stats.host_calls;
				entry["max_host_calls"] = stats.max_host_calls;
			}
			result[String(table[index].name)] = entry;
		}
		if (!host_call_counts_.empty()) {
			Dictionary hosts;
			for (const auto &host : host_call_counts_) {
				hosts[String::utf8(host.first.c_str())] = host.second;
			}
			result["hosts"] = hosts;
		}
		if (unknown_calls_ != 0) {
			result["unknown_calls"] = unknown_calls_;
		}
	} catch (const std::exception &error) {
		report_port_failure("port_stats", std::string("native exception: ") + error.what());
	} catch (...) {
		report_port_failure("port_stats", "unknown native exception");
	}
	return result;
}

Array AurelionRules::ai_search_masks(int64_t width, int64_t height, const PackedByteArray &surface_blocked, const PackedByteArray &surface_stops, const PackedByteArray &water, const PackedByteArray &sea, const PackedInt32Array &body_offsets, const PackedInt32Array &body_tiles, const PackedInt32Array &zone_offsets, const PackedInt32Array &zone_tiles, const PackedByteArray &neutral_open, const PackedInt32Array &unit_blocked, const PackedInt32Array &unit_stops, const PackedInt32Array &hero_tiles, const PackedInt32Array &guard_offsets, const PackedInt32Array &guard_tiles, const PackedInt32Array &site_tiles, const PackedByteArray &site_open) const {
	const char *method = "ai_search_masks";
	if (!valid_map(width, height, method)) {
		return Array();
	}
	const int64_t count = width * height;
	if (!valid_tile_mask(surface_blocked, count, false, method, "surface_blocked") || !valid_tile_mask(surface_stops, count, false, method, "surface_stops") || !valid_tile_mask(sea, count, true, method, "sea")) {
		return Array();
	}
	search::PrepareInput in;
	in.width = width;
	in.height = height;
	if (!lists_of(body_offsets, body_tiles, in.bodies, method, "bodies") || !lists_of(zone_offsets, zone_tiles, in.zones, method, "zones") || !lists_of(guard_offsets, guard_tiles, in.guard_zones, method, "guard zones")) {
		return Array();
	}
	if (neutral_open.size() != in.bodies.count) {
		UtilityFunctions::push_error(String("AurelionRules.ai_search_masks: neutral_open has ") + String::num_int64(neutral_open.size()) + " entries for " + String::num_int64(in.bodies.count) + " armies");
		return Array();
	}
	in.surface_blocked = surface_blocked.ptr();
	in.surface_stops = surface_stops.ptr();
	in.water = bytes_of(water);
	in.sea = sea.is_empty() ? nullptr : sea.ptr();
	in.neutral_open = neutral_open.ptr();
	in.unit_blocked = span_of(unit_blocked);
	in.unit_stops = span_of(unit_stops);
	in.hero_tiles = span_of(hero_tiles);
	in.site_tiles = span_of(site_tiles);
	in.site_open = bytes_of(site_open);
	PackedByteArray blocked;
	PackedByteArray stop_mask;
	PackedByteArray guard_mask;
	PackedByteArray hero_zone;
	PackedByteArray pass_mask;
	PackedByteArray sea_open;
	blocked.resize(count);
	stop_mask.resize(count);
	guard_mask.resize(count);
	hero_zone.resize(count);
	pass_mask.resize(count);
	if (!sea.is_empty()) {
		sea_open.resize(count);
	}
	search::PrepareOutput out;
	out.blocked = blocked.ptrw();
	out.stop_mask = stop_mask.ptrw();
	out.guard_mask = guard_mask.ptrw();
	out.hero_zone = hero_zone.ptrw();
	out.pass_mask = pass_mask.ptrw();
	out.sea_open = sea.is_empty() ? nullptr : sea_open.ptrw();
	try {
		search::prepare(in, out);
	} catch (const std::exception &error) {
		report_exception(method, error.what());
		return Array();
	} catch (...) {
		report_exception(method, "unknown");
		return Array();
	}
	Array result;
	result.append(blocked);
	result.append(stop_mask);
	result.append(guard_mask);
	result.append(hero_zone);
	result.append(pass_mask);
	result.append(sea_open);
	result.append(to_packed(out.zone_stops));
	result.append(to_packed(out.pending_sites));
	return result;
}

Array AurelionRules::ai_search_walk(int64_t width, int64_t height, int64_t start, int64_t start_phase, int64_t radius, bool native_corners, const PackedByteArray &blocked, const PackedByteArray &stop_mask, const PackedByteArray &pass_mask, const PackedByteArray &hero_zone, const PackedInt32Array &portals, const PackedByteArray &seen, const PackedByteArray &water, const PackedByteArray &sea_open, const PackedByteArray &boats, const PackedInt32Array &docks, int64_t shore_cost, int64_t dock_cost) const {
	const char *method = "ai_search_walk";
	if (!valid_map(width, height, method)) {
		return Array();
	}
	const int64_t count = width * height;
	const bool has_water = !water.is_empty();
	if (!valid_tile_mask(blocked, count, false, method, "blocked") || !valid_tile_mask(stop_mask, count, false, method, "stop_mask") || !valid_tile_mask(pass_mask, count, false, method, "pass_mask") || !valid_tile_mask(hero_zone, count, false, method, "hero_zone") || !valid_tile_mask(water, count, true, method, "water")) {
		return Array();
	}
	if (has_water && (!valid_tile_mask(sea_open, count, false, method, "sea_open") || !valid_tile_mask(boats, count, false, method, "boats"))) {
		return Array();
	}
	search::Board board;
	board.width = width;
	board.height = height;
	board.blocked = blocked.ptr();
	board.stop_mask = stop_mask.ptr();
	board.pass_mask = pass_mask.ptr();
	board.hero_zone = hero_zone.ptr();
	board.native_corners = native_corners;
	board.portals = span_of(portals);
	board.seen = bytes_of(seen);
	if (has_water) {
		board.water = water.ptr();
		board.sea_open = sea_open.ptr();
		board.boats = boats.ptr();
		board.docks = span_of(docks);
	}
	board.shore_cost = shore_cost;
	board.dock_cost = dock_cost;
	PackedInt32Array dist;
	PackedInt32Array parent;
	PackedInt32Array order;
	PackedByteArray phase;
	dist.resize(count);
	parent.resize(count);
	order.resize(count);
	if (has_water) {
		phase.resize(count);
	}
	search::Output out;
	out.dist = dist.ptrw();
	out.parent = parent.ptrw();
	out.order = order.ptrw();
	out.phase = has_water ? phase.ptrw() : nullptr;
	try {
		search::search(board, start, start_phase, radius, out);
	} catch (const std::exception &error) {
		report_exception(method, error.what());
		return Array();
	} catch (...) {
		report_exception(method, "unknown");
		return Array();
	}
	Array result;
	result.append(dist);
	result.append(parent);
	result.append(order);
	result.append(out.order_count);
	result.append(out.capped);
	result.append(phase);
	result.append(to_packed(out.reached));
	return result;
}

} // namespace godot
