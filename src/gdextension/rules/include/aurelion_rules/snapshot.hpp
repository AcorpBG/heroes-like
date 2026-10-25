#pragma once

// A snapshot: GDScript data the game writes (AurelionRules.snapshot_encode, the
// AI match runner scene) or a rules tool writes (encode: the battle AI arena's
// native setup), and the tools outside Godot read (battle_sim_cli, Phase 2c;
// match_sim_cli), keeping what the State models of it: key order, int and
// float, String and StringName, typed and read-only containers, and identity
// (a container reached from two places is one node). A Variant the State does
// not model (a Vector2, an Object, a PackedFloat32Array) is kept by its type
// name, as an opaque value that is an error where it is read.
//
// Little-endian: the magic, then one value. A value is a tag byte and, by tag:
//   kNil, kFalse, kTrue: nothing
//   kInt: i64; kFloat: the f64's bits
//   kString, kStringName: a text
//   kVector2i: i32 x, y; kVector3i: i32 x, y, z
//   kArray: u8 flags (kReadOnly), u32 element type, u32 count, the items
//   kDict: u8 flags, u32 key type, u32 value type, u32 count, then key, value
//     pairs in insertion order
//   kContainer: u32 id, a container met before (arrays and dicts in the order
//     their kArray or kDict began, from 0)
//   kPackedByte: u32 count, the bytes; kPackedInt32: u32 count, i32s;
//     kPackedString: u32 count, texts
//   kPacked: u32 id, a packed array met before (from 0)
//   kType: u32 id, u8 Variant type, text class name, text script path; then
//     the value it comes before. A container type is 0 (untyped) or an id
//     defined so before it.
//   kUnsupported: u8 Variant type, a text describing it
// A text is a u32: an id met before, or kNewText and then u32 size and UTF-8
// bytes, which takes the next id (from 0).

#include "aurelion_rules/battle_state.hpp"

#include <cstddef>
#include <cstdint>
#include <functional>
#include <string>
#include <utility>
#include <vector>

namespace aurelion::rules::snapshot {

inline constexpr char kMagic[8] = { 'A', 'R', 'S', 'N', 'A', 'P', '0', '1' };
inline constexpr uint32_t kNewText = 0xFFFFFFFFu;
inline constexpr uint8_t kReadOnly = 1;

enum Tag : uint8_t {
	kNil = 0,
	kFalse = 1,
	kTrue = 2,
	kInt = 3,
	kFloat = 4,
	kString = 5,
	kStringName = 6,
	kVector2i = 7,
	kVector3i = 8,
	kArray = 9,
	kDict = 10,
	kContainer = 11,
	kPackedByte = 12,
	kPackedInt32 = 13,
	kPackedString = 14,
	kPacked = 15,
	kType = 16,
	kUnsupported = 17,
};

// A typed container's element (or key, or value) type, as Godot's
// Array.get_typed_builtin(), get_typed_class_name() and get_typed_script()
// give it (the script by its res:// path).
struct TypeInfo {
	uint8_t builtin = 0;
	std::string class_name;
	std::string script;
	bool operator==(const TypeInfo &other) const { return builtin == other.builtin && class_name == other.class_name && script == other.script; }
};

struct Decoded {
	state::Value root;
	// The snapshot's types by id; the decoded nodes' TypeRefs are these ids
	// (0 is untyped), registered in the State with their Variant types.
	std::vector<TypeInfo> types;
	// The opaque values' descriptions: an Opaque Value's ref is its index.
	std::vector<std::string> unsupported;
};

// Decodes a snapshot into state's nodes, adding to what it holds. Every
// Dictionary's lookup table is built (KeyList::prepare_index), so threads may
// read the nodes at once while nothing writes them. Bad input throws
// std::runtime_error.
Decoded decode(state::State &state, const uint8_t *data, size_t size);

// What encode asks of the caller: a typed container's type by its TypeRef, and
// an opaque value's Variant type and type name (written as kUnsupported).
struct EncodeHooks {
	std::function<TypeInfo(state::TypeRef)> type;
	std::function<std::pair<uint8_t, std::string>(uint32_t)> opaque;
};

// A value of state as a snapshot, as the Godot adapter's encoder
// (gdextension/snapshot_encoder.cpp) writes the same data: a container or
// packed node reached twice is written once, and a backed node is filled
// first. For the rules tools outside Godot (the battle AI arena's native
// setup, cli/match_sim_cli.cpp).
std::vector<uint8_t> encode(const state::State &state, const state::Value &value, const EncodeHooks &hooks);

} // namespace aurelion::rules::snapshot
