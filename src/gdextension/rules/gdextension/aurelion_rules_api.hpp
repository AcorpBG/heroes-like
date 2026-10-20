#pragma once

#include <godot_cpp/classes/ref_counted.hpp>
#include <godot_cpp/variant/dictionary.hpp>
#include <godot_cpp/variant/packed_byte_array.hpp>
#include <godot_cpp/variant/packed_int32_array.hpp>

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
};

} // namespace godot
