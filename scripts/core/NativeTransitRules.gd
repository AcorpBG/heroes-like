extends RefCounted

const Levels = preload("res://scripts/core/OverworldLevelRules.gd")
const HumanEngine = preload("res://scripts/core/HumanEngine.gd")
const NAVIGATION_DELTAS := [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1), Vector2i(1, 1), Vector2i(1, -1), Vector2i(-1, 1), Vector2i(-1, -1)]

# Package connectivity is separate from the original artwork's authored local
# route effect. Never infer a generated exit from that artwork's offsets.
static func is_native(node: Dictionary) -> bool:
	return HumanEngine.native(&"NativeTransitRules.is_native", [node])

static func destinations(node: Dictionary) -> Array:
	return HumanEngine.native_writing(&"NativeTransitRules.destinations", [node])

const PORTAL_KIND_BY_TYPE := {43: "one_way_entrance", 44: "one_way_exit", 45: "two_way_portal"}
# Network colours (docs/portal-networks.md), ordered so the first networks on
# a map get the most different hues. They tint the painted light, so they are
# bright but not flat. Each network gets
# its own slot (assign_network_colours); past the palette colours repeat and
# the portal's shape still tells the kinds apart.
const NETWORK_COLOURS := [
	{"name": "Emerald", "color": Color(0.22, 0.86, 0.42)},
	{"name": "Crimson", "color": Color(0.96, 0.24, 0.28)},
	{"name": "Azure", "color": Color(0.25, 0.58, 1.0)},
	{"name": "Gold", "color": Color(1.0, 0.85, 0.3)},
	{"name": "Violet", "color": Color(0.66, 0.42, 1.0)},
	{"name": "Teal", "color": Color(0.18, 0.85, 0.8)},
	{"name": "Flame", "color": Color(1.0, 0.5, 0.18)},
	{"name": "Magenta", "color": Color(1.0, 0.34, 0.88)},
	{"name": "Lime", "color": Color(0.68, 1.0, 0.28)},
	{"name": "Indigo", "color": Color(0.45, 0.42, 1.0)},
	{"name": "Sky", "color": Color(0.55, 0.84, 1.0)},
	{"name": "Rose", "color": Color(1.0, 0.52, 0.74)},
	{"name": "Mint", "color": Color(0.55, 1.0, 0.76)},
	{"name": "Orchid", "color": Color(0.86, 0.6, 1.0)},
	{"name": "Amber", "color": Color(1.0, 0.68, 0.24)},
	{"name": "Silver", "color": Color(0.86, 0.89, 0.96)},
]

## two_way_portal, one_way_entrance or one_way_exit for a native monolith;
## "" for subterranean gates and everything else.
static func portal_kind(node: Dictionary) -> String:
	return HumanEngine.native_writing(&"NativeTransitRules.portal_kind", [node])

static func network_colour(node: Dictionary) -> Dictionary:
	return HumanEngine.native(&"NativeTransitRules.network_colour", [node])

static func point(value: Variant) -> Vector3i:
	return HumanEngine.native(&"NativeTransitRules.point", [value])
