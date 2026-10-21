#include "aurelion_rules_api.hpp"

#include "battle_port_bridge.hpp"
#include "battle_state_bridge.hpp"

#include "aurelion_rules/battle_hex.hpp"
#include "aurelion_rules/build_info.hpp"
#include "aurelion_rules/port/registry.hpp"

#include <godot_cpp/classes/os.hpp>
#include <godot_cpp/core/class_db.hpp>
#include <godot_cpp/core/gdextension_interface_loader.hpp>
#include <godot_cpp/variant/utility_functions.hpp>

#include <algorithm>
#include <chrono>
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
	ClassDB::bind_method(D_METHOD("port_check", "name", "args", "gdscript_result"), &AurelionRules::port_check);
	ClassDB::bind_method(D_METHOD("port_report", "name", "mismatch"), &AurelionRules::port_report);
	ClassDB::bind_method(D_METHOD("port_stats"), &AurelionRules::port_stats);
}

AurelionRules::AurelionRules() {
	try {
		port_ = std::make_unique<aurelion::rules::bridge::PortBridge>();
		size_t count = 0;
		aurelion::rules::port::functions(count);
		port_stats_.resize(count);
		OS *os = OS::get_singleton();
		size_t table_count = 0;
		const aurelion::rules::port::Table *tables = aurelion::rules::port::tables(table_count);
		for (size_t index = 0; os != nullptr && index < table_count; ++index) {
			const String folder = os->get_environment(tables[index].log_variable);
			if (!folder.is_empty()) {
				const CharString utf8 = folder.path_join("shadow_" + String::num_int64(os->get_process_id()) + ".json").utf8();
				const std::string path(utf8.get_data(), static_cast<size_t>(utf8.length()));
				if (std::find(port_log_paths_.begin(), port_log_paths_.end(), path) == port_log_paths_.end()) {
					port_log_paths_.push_back(path);
				}
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

constexpr int kMaxPortArgs = 8;
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

void AurelionRules::record_mismatch(PortStats &stats, const std::string &text) {
	++stats.mismatches;
	if (stats.first.size() < kKeptMismatches) {
		stats.first.push_back(text);
	}
	write_port_stats();
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
		if (stats.calls == 0 && stats.checks == 0) {
			continue;
		}
		if (!first_entry) {
			out += ", ";
		}
		first_entry = false;
		append_json_string(out, table[index].name);
		out += ": {\"calls\": " + std::to_string(stats.calls) + ", \"checks\": " + std::to_string(stats.checks) + ", \"mismatches\": " + std::to_string(stats.mismatches) + ", \"errors\": " + std::to_string(stats.errors) + ", \"first\": [";
		for (size_t line = 0; line < stats.first.size(); ++line) {
			if (line != 0) {
				out += ", ";
			}
			append_json_string(out, stats.first[line]);
		}
		out += "]}";
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
	}
}

Variant AurelionRules::port_call(const StringName &name, const Array &args, bool write_back) {
	std::string problem;
	try {
		const aurelion::rules::port::Function *function = port_function(name);
		if (function == nullptr) {
			record_unknown(name, "port_call");
			return Variant();
		}
		PortStats &stats = stats_of(function);
		++stats.calls;
		count_port_use();
		try {
			if (port_ == nullptr) {
				throw std::runtime_error("the port did not start");
			}
			if (args.size() != function->arity || function->arity > kMaxPortArgs) {
				problem = std::string(function->name) + " takes " + std::to_string(function->arity) + " arguments, got " + std::to_string(args.size());
			} else {
				port_->begin();
				aurelion::rules::state::Value values[kMaxPortArgs];
				for (int index = 0; index < function->arity; ++index) {
					values[index] = port_->load(args[index]);
				}
				const aurelion::rules::state::Value result = function->call(port_->state(), values);
				if (write_back) {
					port_->write_back();
				} else if (port_->changed_a_source()) {
					problem = std::string(function->name) + ": native wrote into an argument";
				}
				if (problem.empty()) {
					return port_->export_value(result);
				}
			}
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
		try {
			if (port_ == nullptr) {
				throw std::runtime_error("the port did not start");
			}
			if (args.size() != function->arity || function->arity > kMaxPortArgs) {
				mismatch = std::string("takes ") + std::to_string(function->arity) + " arguments, got " + std::to_string(args.size());
			} else {
				port_->begin();
				aurelion::rules::state::Value values[kMaxPortArgs];
				for (int index = 0; index < function->arity; ++index) {
					values[index] = port_->load(args[index]);
				}
				const aurelion::rules::state::Value result = function->call(port_->state(), values);
				if (port_->changed_a_source()) {
					mismatch = "native wrote into an argument";
				} else {
					mismatch = port_->diff(result, gdscript_result);
				}
			}
		} catch (const aurelion::rules::state::ScriptError &error) {
			mismatch = std::string("native script error: ") + error.what();
		} catch (const std::exception &error) {
			mismatch = std::string("native exception: ") + error.what();
		} catch (...) {
			mismatch = "unknown native exception";
		}
		if (mismatch.empty()) {
			return String();
		}
		record_mismatch(stats, mismatch);
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
			record_mismatch(stats, utf8_text(mismatch));
		}
	} catch (const std::exception &error) {
		report_port_failure("port_report", std::string("native exception: ") + error.what());
	} catch (...) {
		report_port_failure("port_report", "unknown native exception");
	}
}

Dictionary AurelionRules::port_stats() const {
	Dictionary result;
	try {
		size_t count = 0;
		const aurelion::rules::port::Function *table = aurelion::rules::port::functions(count);
		for (size_t index = 0; index < count && index < port_stats_.size(); ++index) {
			const PortStats &stats = port_stats_[index];
			if (stats.calls == 0 && stats.checks == 0) {
				continue;
			}
			Dictionary entry;
			entry["calls"] = stats.calls;
			entry["checks"] = stats.checks;
			entry["mismatches"] = stats.mismatches;
			entry["errors"] = stats.errors;
			result[String(table[index].name)] = entry;
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

} // namespace godot
