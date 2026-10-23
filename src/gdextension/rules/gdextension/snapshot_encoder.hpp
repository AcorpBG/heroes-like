#pragma once

// GDScript data as a snapshot (aurelion_rules/snapshot.hpp), for the battle
// tool (battle_sim_cli): AurelionRules.snapshot_encode.

#include <godot_cpp/variant/packed_byte_array.hpp>
#include <godot_cpp/variant/variant.hpp>

namespace aurelion::rules::bridge {

// Throws std::runtime_error on data nested past the snapshot's depth.
godot::PackedByteArray encode_snapshot(const godot::Variant &value);

} // namespace aurelion::rules::bridge
