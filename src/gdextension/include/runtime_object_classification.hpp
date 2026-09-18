#pragma once

#include <cstdint>

// Runtime translation only: recovered final records, RNG and masks are untouched.
// Shared by the Godot adapter and standalone package inspector. Group-zero
// scenery families come from the recovered object-template inventory; unknown
// records must not be silently treated as already renderer-managed.
namespace aurelion {
inline const char *runtime_object_kind(int32_t type_id) {
	switch (type_id) {
		case 5: return "artifact";
		case 53: return "mine";
		case 54: case 71: case 72: case 73: case 74: case 75:
		case 162: case 163: case 164: return "guard";
		case 77: case 98: return "town";
		case 66: case 67: case 68: case 69: case 76: case 79:
		case 83: case 88: case 89: case 90: case 93: case 101:
			return "reward_reference";
		case 116: case 117: case 118: case 119: case 120: case 121:
		case 124: case 125: case 126: case 127: case 128: case 129:
		case 130: case 131: case 132: case 133: case 134: case 135:
		case 136: case 137: case 143: case 147: case 148: case 149:
		case 150: case 151: case 153: case 155: case 158: case 161:
		case 177: case 199: case 206: case 207: case 208: case 209:
		case 210: case 211:
			return "decorative_obstacle";
		default: return "h3m_object";
	}
}
} // namespace aurelion
