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

	// The ported battle functions (aurelion_rules/port/registry.hpp), for the
	// switch in BattleEngine.gd. battle_port_call runs one on args and returns
	// its result, writing what it changed back into args when write_back is set;
	// a native script error is reported and answered with null.
	// battle_port_check runs it and compares the result with GDScript's: "" when
	// they match, else the first difference. battle_port_report counts a check
	// BattleEngine.gd made itself (mismatch "" when it matched).
	Variant battle_port_call(const StringName &name, const Array &args, bool write_back);
	String battle_port_check(const StringName &name, const Array &args, const Variant &gdscript_result);
	void battle_port_report(const StringName &name, const String &mismatch);
	// {name: {calls, checks, mismatches, errors}}. With HEROES_NATIVE_BATTLE_LOG
	// set to a folder, the same goes to shadow_<pid>.json there, with the first
	// mismatches, every 65,536 uses, on each mismatch and at exit.
	Dictionary battle_port_stats() const;

private:
	struct PortStats {
		int64_t calls = 0;
		int64_t checks = 0;
		int64_t mismatches = 0;
		int64_t errors = 0;
		std::vector<std::string> first;
	};

	const aurelion::rules::port::Function *port_function(const StringName &name);
	PortStats &stats_of(const aurelion::rules::port::Function *function);
	void record_mismatch(PortStats &stats, const std::string &text);
	void count_port_use();
	void write_port_stats() const;

	Dictionary last_state_stats_;
	std::unique_ptr<aurelion::rules::bridge::PortBridge> port_;
	// Keyed by the StringName's engine data, which the held StringName keeps.
	std::unordered_map<uint64_t, std::pair<StringName, const aurelion::rules::port::Function *>> port_names_;
	std::vector<PortStats> port_stats_;
	std::string port_log_path_;
	int64_t port_uses_ = 0;
};

} // namespace godot
