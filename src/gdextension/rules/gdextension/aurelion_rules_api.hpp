#pragma once

#include <godot_cpp/classes/ref_counted.hpp>
#include <godot_cpp/variant/array.hpp>
#include <godot_cpp/variant/dictionary.hpp>
#include <godot_cpp/variant/packed_byte_array.hpp>
#include <godot_cpp/variant/packed_int32_array.hpp>
#include <godot_cpp/variant/string.hpp>
#include <godot_cpp/variant/string_name.hpp>
#include <godot_cpp/variant/variant.hpp>

#include <cstdint>
#include <memory>
#include <string>
#include <unordered_map>
#include <utility>
#include <vector>

namespace aurelion::rules::bridge {
class PortBridge;
}
namespace aurelion::rules::port {
struct Function;
}

namespace godot {

// The game's door to the native rules core. GDScript holds one instance
// (ClassDB.instantiate("AurelionRules")) and calls it with packed arrays. Bad
// input or an exception in the core is reported with push_error and answered
// with an empty result; it never reaches Godot.
class AurelionRules : public RefCounted {
	GDCLASS(AurelionRules, RefCounted)

protected:
	static void _bind_methods();

public:
	AurelionRules();
	~AurelionRules() override;

	// {api, source_tree, godot_cpp, compiler, flavour}
	Dictionary get_build_info() const;

	// BattleRules._reachable_empty_hexes: [id, steps, id, steps, ...] in the
	// walk's order. open is BattleRules._hex_open_mask (99 bytes).
	PackedInt32Array battle_hex_reachable(const PackedByteArray &open, int64_t body_width, int64_t tail_step, int64_t start_id, int64_t max_steps) const;

	// BattleRules._walk_steps_to_target: [id, steps, ...] in the walk's order.
	// target_q < 0 is a target with no hex.
	PackedInt32Array battle_hex_walk_steps(const PackedByteArray &open, int64_t body_width, int64_t tail_step, int64_t target_q, int64_t target_r, int64_t target_tail_q, int64_t gap) const;

	// BattleRules._obstacle_field_stays_open over an open mask of the obstacles.
	bool battle_hex_field_stays_open(const PackedByteArray &open) const;

	// The native battle state's conversion (battle_state_bridge.hpp), for the
	// round-trip proof. Mode 0 loads value and returns new containers written
	// from the state; mode 1 writes the state back into value's own containers
	// and returns value.
	Variant state_round_trip(const Variant &value, int64_t mode);
	// Loads target, replaces the state with source matched by path, and writes
	// it back into target's containers. Returns target.
	Variant state_overwrite(const Variant &target, const Variant &source);
	// The last state call: {ok, error, values, shared_refs, arrays, dicts,
	// atoms, opaque, types, load_usec, store_usec, reused_arrays, reused_dicts,
	// rebuilt_dicts}.
	Dictionary state_last_stats() const;
	// One state's whole conversion, timed (the battle port's G1 times a
	// resolve's). Each round loads a deep copy of start (timed), turns the state
	// into end (untimed: StateBridge::overwrite stands in for the native code's
	// changes), adds the nodes the ported calls made, unreachable, and writes the
	// state back into the copy's containers (timed). {load_us, store_us} are
	// medians; also every round and the pool sizes.
	Dictionary state_conversion_timing(const Variant &start, const Variant &end, int64_t made_arrays, int64_t made_dicts, int64_t rounds);

	// The ported functions of every subsystem (aurelion_rules/port/registry.hpp),
	// for the switches in BattleEngine.gd and the other engines. port_call runs
	// one on args and returns its result, writing what it changed back into args
	// when write_back is set; a native script error is reported and answered
	// with null. port_check runs it and compares the result with GDScript's: ""
	// when they match, else the first difference. port_report counts a check the
	// engine script made itself (mismatch "" when it matched). A call that
	// reached a path the port leaves to GDScript (state::NotPorted) changes
	// nothing and returns null, and port_not_ported() is true until the next
	// port_call; such a check is counted as not ported and matches.
	Variant port_call(const StringName &name, const Array &args, bool write_back);
	bool port_not_ported() const { return last_not_ported_; }
	String port_check(const StringName &name, const Array &args, const Variant &gdscript_result);
	void port_report(const StringName &name, const String &mismatch);
	// Shadow: the arguments of a function that writes into them, copied for its
	// native run before GDScript runs (bridge::copy_for_shadow).
	Array port_copy(const Array &args);
	// {name: {calls, checks, mismatches, errors, not_ported}}, plus "unknown_calls" when a
	// name was not in the registry. With a subsystem's log variable set to a
	// folder (HEROES_NATIVE_BATTLE_LOG), the same goes to shadow_<pid>.json
	// there, with the first mismatches and unknown names, every 65,536 uses, on
	// each mismatch or failure and at exit. A native call that fails or names no
	// ported function, a shadow mismatch (the first 20) and a stats file that
	// cannot be written print a SCRIPT ERROR, which fails rules_parity runs and
	// the core suite's tests.
	Dictionary port_stats() const;

	// AiHeroRules._search, its masks (ai_search::prepare): [blocked, stop_mask,
	// guard_mask, hero_zone, pass_mask, sea_open, zone_stops, pending_sites].
	// Masks are one byte per tile; a list of lists is offsets (count + 1) and
	// tiles. sea is empty when the level has no water, and sea_open then too.
	Array ai_search_masks(int64_t width, int64_t height, const PackedByteArray &surface_blocked, const PackedByteArray &surface_stops, const PackedByteArray &water, const PackedByteArray &sea, const PackedInt32Array &body_offsets, const PackedInt32Array &body_tiles, const PackedInt32Array &zone_offsets, const PackedInt32Array &zone_tiles, const PackedByteArray &neutral_open, const PackedInt32Array &unit_blocked, const PackedInt32Array &unit_stops, const PackedInt32Array &hero_tiles, const PackedInt32Array &guard_offsets, const PackedInt32Array &guard_tiles, const PackedInt32Array &site_tiles, const PackedByteArray &site_open) const;

	// AiHeroRules._search, its walk (ai_search::search): [dist, parent, order,
	// order_count, capped, phase, reached]. water is empty when the level has
	// none, and phase then too.
	Array ai_search_walk(int64_t width, int64_t height, int64_t start, int64_t start_phase, int64_t radius, bool native_corners, const PackedByteArray &blocked, const PackedByteArray &stop_mask, const PackedByteArray &pass_mask, const PackedByteArray &hero_zone, const PackedInt32Array &portals, const PackedByteArray &seen, const PackedByteArray &water, const PackedByteArray &sea_open, const PackedByteArray &boats, const PackedInt32Array &docks, int64_t shore_cost, int64_t dock_cost) const;

private:
	struct PortStats {
		int64_t calls = 0;
		int64_t checks = 0;
		int64_t mismatches = 0;
		int64_t errors = 0;
		int64_t not_ported = 0;
		std::vector<std::string> first;
	};

	const aurelion::rules::port::Function *port_function(const StringName &name);
	PortStats &stats_of(const aurelion::rules::port::Function *function);
	void record_mismatch(PortStats &stats, const char *name, const std::string &text, bool error);
	void count_port_use();
	void write_port_stats() const;
	void record_unknown(const StringName &name, const char *method);

	Dictionary last_state_stats_;
	std::unique_ptr<aurelion::rules::bridge::PortBridge> port_;
	// Keyed by the StringName's engine data, which the held StringName keeps.
	std::unordered_map<uint64_t, std::pair<StringName, const aurelion::rules::port::Function *>> port_names_;
	std::vector<PortStats> port_stats_;
	// One file per distinct folder the subsystems' log variables name.
	std::vector<std::string> port_log_paths_;
	int64_t port_uses_ = 0;
	bool last_not_ported_ = false;
	int64_t unknown_calls_ = 0;
	std::vector<std::string> unknown_names_;
	size_t reported_mismatches_ = 0;
	mutable bool port_log_failed_ = false;
};

} // namespace godot
